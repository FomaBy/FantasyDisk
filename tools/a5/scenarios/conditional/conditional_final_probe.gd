extends SceneTree

# FAN-1513: executable A/B probe for the A5 conditional-final families.
#
# For every matrix pair the probe runs the same seed twice - once with the weapon
# final purchased and once with exactly that one node removed from the otherwise
# identical class constellation - and records what the production runtime did.
# The A/B delta is what isolates the final's contribution; the resolver trigger
# count is what proves the conditional actually fired.
#
# The fixture reuses the FAN-1511 telemetry collector so the recorded sample keeps
# the canonical schema. Targetless resolutions (mine chains, totem and amp pulses)
# never reach that collector by design, so the probe also listens to the raw
# production signal and counts triggered resolutions itself.
#
# Usage:
#   python3 tools/godot_gate.py --headless --path . \
#       --script res://tools/a5/scenarios/conditional/conditional_final_probe.gd
#   ... -- --pair=druid/summon_amulet --seeds=1   # diagnostic, writes nothing

const Pack := preload("res://tools/a5/scenarios/conditional/conditional_final_pack.gd")
const Report := preload("res://tools/a5_balance_report.gd")
const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const MainScript := preload("res://scripts/main.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const ISSUE_ID := "FAN-1513"
const TRACE_PREFIX := "fan1513"
const DETERMINISTIC_MAX_FPS := 60
const DUMMY_HP := 1.0e9
const PLAYER_POSITION := Vector2(1280.0, 720.0)
const SOLO_OFFSET := Vector2(80.0, 0.0)
const PACK_RADIUS := 42.0
const MAX_LIVE_FRAMES := 4800
# Frames between scripted summon kills in the summon_lethal stimulus. Frame based
# rather than time based so the trigger stays identical under any window length.
const SUMMON_LETHAL_INTERVAL_FRAMES := 60

var _holder: Node2D
var _errors := PackedStringArray()
var _pair_filter := ""
var _seed_override := 0
var _window_override := 0.0
var _trigger_hits := 0
var _watch_mechanic := ""
var _watch_event := ""


func _initialize() -> void:
	_parse_args()
	if not _errors.is_empty():
		_fail()
		return
	await process_frame
	Engine.max_fps = DETERMINISTIC_MAX_FPS
	_holder = Node2D.new()
	_holder.name = "FAN1513ConditionalHolder"
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("aim_mode", "nearest")
	await process_frame

	var matrix_check := Pack.verify_matrix()
	if not bool(matrix_check.get("ok", false)):
		for matrix_error in matrix_check.get("errors", []):
			_errors.append("family matrix: %s" % matrix_error)
		_fail()
		return

	var measurements := {}
	for entry_value in Pack.FAMILY_MATRIX:
		var entry: Dictionary = entry_value
		var key := Pack.pair_key(entry)
		if _pair_filter != "" and key != _pair_filter:
			continue
		var measurement: Dictionary = await _converge_pair(entry)
		measurements[key] = measurement
		var result := Pack.evaluate_pair(entry, measurement)
		var enabled_arm: Dictionary = measurement.get("enabled", {})
		print("%s %s [%s] %s triggers=%d/%d events=%d kills=%d/%d final_damage=%.4f delta=%.4f cv=%.4f" % [
			ISSUE_ID, key, entry.get("family", ""), result.get("verdict", "?"),
			int(enabled_arm.get("trigger_resolutions", 0)),
			int((measurement.get("disabled", {}) as Dictionary).get("trigger_resolutions", 0)),
			int(enabled_arm.get("final_event_count", 0)),
			int(enabled_arm.get("kills", 0)),
			int((measurement.get("disabled", {}) as Dictionary).get("kills", 0)),
			float(result.get("final_event_damage", 0.0)), float(result.get("damage_delta", 0.0)),
			float((result.get("convergence", {}) as Dictionary).get("cv", -1.0)),
		])
		for pair_error in result.get("errors", []):
			_errors.append(str(pair_error))
	await _teardown()

	if _pair_filter != "" or _seed_override > 0 or _window_override > 0.0:
		# A filtered or overridden run is a diagnostic, never an accepted artifact.
		print("%s diagnostic run complete; no fragment written." % ISSUE_ID)
		_finish()
		return

	var fragment := {
		"fragment_schema": Pack.FRAGMENT_SCHEMA,
		"pack_id": Pack.PACK_ID,
		"pack_contract": Pack.PACK_CONTRACT,
		"convergence_rule": Pack.CONVERGENCE_RULE,
		"issue": ISSUE_ID,
		"contract": Pack.contract(),
		"matrix": Pack.FAMILY_MATRIX,
		"measurements": measurements,
	}
	var verdict := Pack.evaluate_fragment(fragment)
	fragment["verdict"] = "green" if bool(verdict.get("ok", false)) else "red"
	if not bool(verdict.get("ok", false)):
		for fragment_error in verdict.get("errors", []):
			_errors.append(str(fragment_error))
		_fail()
		return
	_write_fragment(fragment)
	_finish()


func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--pair="):
			_pair_filter = arg.trim_prefix("--pair=")
		elif arg.begins_with("--seeds="):
			_seed_override = int(arg.trim_prefix("--seeds="))
		elif arg.begins_with("--window="):
			_window_override = float(arg.trim_prefix("--window="))
		else:
			_errors.append("unsupported argument %s" % arg)


# Escalate until the per-seed trigger counts are stable under the versioned rule.
# A pair that never stabilises exits the loop unconverged and fails closed in
# Pack.evaluate_pair - it is never promoted to green by exhausting the budget.
func _converge_pair(entry: Dictionary) -> Dictionary:
	var seed_count := _seed_override if _seed_override > 0 else Pack.MIN_SEEDS
	var window_seconds := _window_override if _window_override > 0.0 else Pack.MIN_WINDOW_SECONDS
	var measurement: Dictionary = await _measure_pair(entry, {}, seed_count, window_seconds)
	if _seed_override > 0 or _window_override > 0.0:
		return measurement
	while not bool(Pack.evaluate_convergence(measurement.get("per_seed_triggers", []), seed_count, window_seconds).get("ok", false)):
		var escalation := Pack.next_escalation(seed_count, window_seconds)
		if not bool(escalation.get("ok", false)):
			break
		var next_window := float(escalation["window_seconds"])
		# Extra seeds extend the existing sample; a longer window invalidates it and
		# every seed is re-measured. Without that split a single unstable pair would
		# re-run its whole seed set once per escalation step.
		var carried: Dictionary = measurement if is_equal_approx(next_window, window_seconds) else {}
		seed_count = int(escalation["seed_count"])
		window_seconds = next_window
		print("%s %s escalating to %d seeds / %.1fs window" % [ISSUE_ID, Pack.pair_key(entry), seed_count, window_seconds])
		measurement = await _measure_pair(entry, carried, seed_count, window_seconds)
	return measurement


func _measure_pair(entry: Dictionary, carried: Dictionary, seed_count: int, window_seconds: float) -> Dictionary:
	var enabled: Dictionary = carried.get("enabled", _empty_arm())
	var disabled: Dictionary = carried.get("disabled", _empty_arm())
	var per_seed_triggers: Array = carried.get("per_seed_triggers", [])
	for index in range(per_seed_triggers.size(), seed_count):
		if index >= Pack.SEEDS.size():
			_errors.append("%s asked for %d seeds, the rule pins only %d" % [Pack.pair_key(entry), seed_count, Pack.SEEDS.size()])
			break
		var seed_value := int(Pack.SEEDS[index])
		var enabled_sample: Dictionary = await _measure_arm(entry, seed_value, window_seconds, true)
		var disabled_sample: Dictionary = await _measure_arm(entry, seed_value, window_seconds, false)
		per_seed_triggers.append(int(enabled_sample.get("trigger_resolutions", 0)))
		_accumulate(enabled, enabled_sample)
		_accumulate(disabled, disabled_sample)
		print("%s %s seed %d/%d window %.1fs triggers %d/%d" % [
			ISSUE_ID, Pack.pair_key(entry), index + 1, seed_count, window_seconds,
			int(enabled_sample.get("trigger_resolutions", 0)), int(disabled_sample.get("trigger_resolutions", 0)),
		])
	return {
		"enabled": enabled,
		"disabled": disabled,
		"per_seed_triggers": per_seed_triggers,
		"seed_count": per_seed_triggers.size(),
		"window_seconds": window_seconds,
	}


func _empty_arm() -> Dictionary:
	return {
		"trigger_resolutions": 0,
		"final_event_count": 0,
		"final_event_damage": 0.0,
		"ledger_damage": 0.0,
		"casts": 0,
		"hits": 0,
		"kills": 0,
		"damage_sources": [],
	}


func _accumulate(arm: Dictionary, sample: Dictionary) -> void:
	for key in ["trigger_resolutions", "final_event_count", "casts", "hits", "kills"]:
		arm[key] = int(arm[key]) + int(sample.get(key, 0))
	for key in ["final_event_damage", "ledger_damage"]:
		arm[key] = snappedf(float(arm[key]) + float(sample.get(key, 0.0)), 0.0001)
	var sources: Array = arm["damage_sources"]
	for source_value in sample.get("damage_sources", []):
		if not sources.has(str(source_value)):
			sources.append(str(source_value))
	sources.sort()
	arm["damage_sources"] = sources


func _measure_arm(entry: Dictionary, seed_value: int, window_seconds: float, final_enabled: bool) -> Dictionary:
	await _teardown()
	seed(seed_value)
	var class_id := str(entry.get("class_id", ""))
	var weapon_id := str(entry.get("weapon_id", ""))
	var pair := "%s/%s" % [class_id, weapon_id]
	var sample_key := "%s|%d|%s|%s" % [pair, seed_value, "final_enabled" if final_enabled else "final_disabled", entry.get("fixture", "")]
	var collector := Report.A5TelemetryCollector.new("%s:%s" % [TRACE_PREFIX, sample_key], sample_key)
	_trigger_hits = 0
	_watch_mechanic = str(entry.get("mechanic_id", ""))
	_watch_event = str(entry.get("trigger_event", ""))

	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	if player == null or player.get_script() == null:
		_errors.append("%s live Player failed to instantiate" % pair)
		return _empty_arm()
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", class_id, weapon_id)
	player.set("stats", DamageTable.optimized_stats_for_class(class_id, PD.base_stats(class_id)))
	player.call("_apply_stat_scaling", true)
	# Production composition order, exactly as the canonical A5 harness runs it.
	var main := MainScript.new()
	main.set("selected_character_id", class_id)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", _scenario_state(class_id, weapon_id, final_enabled))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.set("max_health", DUMMY_HP)
	player.set("health", DUMMY_HP)
	player.connect("weapon_cast_observed", collector.on_weapon_cast)
	player.connect("constellation_final_resolved", collector.on_final_resolution)
	player.connect("constellation_final_resolved", _on_final_resolved)
	await process_frame

	var dummies := _spawn_dummies(entry, collector, player)
	var anchors := []
	for dummy_value in dummies:
		anchors.append((dummy_value as Node2D).global_position)

	await _advance(float(entry.get("warmup_seconds", 2.0)), dummies, anchors, collector, "warmup", entry, player)
	var measurement: Dictionary = await _advance(window_seconds, dummies, anchors, collector, "measurement", entry, player)
	if float(measurement.get("duration_seconds", 0.0)) < window_seconds:
		_errors.append("%s advanced %.2f/%.2fs" % [pair, measurement.get("duration_seconds", 0.0), window_seconds])

	var sample := collector.build_sample(pair, seed_value, sample_key, str(entry.get("fixture", "")), dummies.size())
	var counters: Dictionary = sample.get("counters", {})
	var sources := []
	for bucket_value in counters.get("damage_by_source_phase", []):
		var bucket: Dictionary = bucket_value
		sources.append("%s|%s" % [bucket.get("source", ""), bucket.get("phase", "")])
	sources.sort()
	var attribution := _attribute_final_events(sample, str(entry.get("mechanic_id", "")))
	return {
		"trigger_resolutions": _trigger_hits,
		"final_event_count": int(attribution["final_event_count"]),
		"final_event_damage": float(attribution["final_event_damage"]),
		"ledger_damage": snappedf(float((sample.get("hp_ledger", {}) as Dictionary).get("total_applied_damage", 0.0)), 0.0001),
		"casts": int(counters.get("casts", 0)),
		"hits": int(counters.get("hits", 0)),
		"kills": int(attribution["kills"]),
		"damage_sources": sources,
	}


# The canonical collector also books a "kill" final event for every target death,
# which is lifecycle bookkeeping and not a constellation payout. A mortal fixture
# would otherwise report final-event traffic in the disabled arm and inflate the
# enabled arm's final damage. Attribute strictly by the mechanic under test.
func _attribute_final_events(sample: Dictionary, mechanic_id: String) -> Dictionary:
	var event_by_id := {}
	for event_value in sample.get("events", []):
		var event: Dictionary = event_value
		event_by_id[str(event.get("event_id", ""))] = event
	var final_event_count := 0
	var kills := 0
	var tagged_hit_ids := {}
	for event_value in sample.get("events", []):
		var event: Dictionary = event_value
		if str(event.get("kind", "")) != "final_event":
			continue
		if str(event.get("phase", "")) == "target_death":
			kills += 1
			continue
		if str(event.get("mechanic_id", "")) != mechanic_id:
			continue
		final_event_count += 1
		var related_hit_id := str(event.get("related_hit_id", ""))
		if related_hit_id != "" and event_by_id.has(related_hit_id):
			tagged_hit_ids[related_hit_id] = true
	var final_event_damage := 0.0
	for hit_id in tagged_hit_ids:
		final_event_damage += float((event_by_id[hit_id] as Dictionary).get("damage", 0.0))
	return {
		"final_event_count": final_event_count,
		"final_event_damage": snappedf(final_event_damage, 0.0001),
		"kills": kills,
	}


func _on_final_resolved(_weapon_id: String, event: String, _target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
	if not bool(resolution.get("triggered", false)) or event != _watch_event:
		return
	if str(resolution.get("mechanic_id", "")) != _watch_mechanic:
		return
	_trigger_hits += 1


# The disabled arm is the full class constellation minus exactly one node: the
# weapon final under test. Everything else - ascension, hidden reveals, stats,
# seed, fixture and frame schedule - is identical, so the A/B delta cannot be
# attributed to anything but that final.
func _scenario_state(class_id: String, weapon_id: String, final_enabled: bool) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	var final_node_id := _weapon_final_node_id(class_id, weapon_id)
	if final_node_id == "":
		_errors.append("%s/%s has no schema-6 weapon final node" % [class_id, weapon_id])
	var purchased := []
	var hidden_ids := []
	for raw_node in Meta.constellation_nodes(class_id):
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		if str(node.get("role", "")) == "hidden":
			hidden_ids.append(node_id)
		if str(node.get("role", "")) == "core":
			continue
		if not final_enabled and node_id == final_node_id:
			continue
		purchased.append(node_id)
	state["hidden_reveal_facts"] = {class_id: hidden_ids}
	state["skill_nodes"] = purchased
	return state


func _weapon_final_node_id(class_id: String, weapon_id: String) -> String:
	for raw_branch in Schema6.class_entry(class_id).get("weapon_branches", []):
		var branch: Dictionary = raw_branch
		if str(branch.get("weapon_id", "")) != weapon_id:
			continue
		for raw_node in branch.get("nodes", []):
			var node: Dictionary = raw_node
			if str(node.get("role", "")) == "weapon_final":
				return str(node.get("node_id", ""))
	return ""


func _spawn_dummies(entry: Dictionary, collector: RefCounted, player: Node2D) -> Array:
	var target_count := int(entry.get("target_count", 1))
	var ring := str(entry.get("layout", "pack")) == "ring"
	var result := []
	for index in range(target_count):
		var position := PLAYER_POSITION + SOLO_OFFSET
		if ring:
			# Evenly spaced on the deployable's own placement radius, so the whole
			# annulus is covered instead of one narrow arc.
			position = PLAYER_POSITION + Vector2.RIGHT.rotated(TAU * float(index) / float(target_count)) * float(entry.get("layout_radius", 0.0))
		elif target_count > 1:
			var radius := 0.0 if index == 0 else PACK_RADIUS * (0.55 + 0.45 * sqrt(float(index) / float(target_count - 1)))
			var angle := 0.0 if index == 0 else float(index - 1) * 2.3999632
			position += Vector2.RIGHT.rotated(angle) * radius
		result.append(_spawn_dummy(entry, position, collector, index, player))
	return result


func _spawn_dummy(entry: Dictionary, position: Vector2, collector: RefCounted, index: int, player: Node2D) -> Node2D:
	var mortal := str(entry.get("fixture", "")) == "mortal"
	var target_hp := float(entry.get("initial_target_hp", 0.0)) if mortal else DUMMY_HP
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	_holder.add_child(enemy)
	enemy.global_position = position
	enemy.set("max_health", target_hp)
	enemy.set("health", target_hp)
	enemy.set("move_speed", 0.0)
	enemy.set("contact_damage", 0.0)
	collector.bind_target(enemy, "target_%d" % index)
	enemy.connect("damage_applied", collector.on_damage_applied)
	enemy.connect("died", collector.on_target_died)
	if mortal:
		# Production routes kill attribution through combat_director, which calls
		# player.on_enemy_killed on every enemy death. Weapons without direct damage
		# (cursed_skull) never reach the on_weapon_hit dispatch, so without this the
		# kill family is silently untestable. The player-side guard makes the double
		# wiring idempotent exactly as it is in a real run.
		enemy.connect("died", player.on_enemy_killed)
	return enemy


# A kill/execute final only resolves while something is still dying. Ten targets
# at a survivable HP are consumed well inside the warm-up, so the mortal fixture
# refills a slot as soon as it empties and the measurement window keeps producing
# lethal blows for its whole length instead of only in its first frames.
func _refill_mortal_targets(entry: Dictionary, dummies: Array, anchors: Array, collector: RefCounted, player: Node2D) -> void:
	for index in range(dummies.size()):
		var enemy := dummies[index] as Node2D
		if enemy != null and is_instance_valid(enemy) and float(enemy.get("health")) > 0.0:
			continue
		if enemy != null and is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.queue_free()
		dummies[index] = _spawn_dummy(entry, anchors[index], collector, index, player)


func _advance(seconds: float, dummies: Array, anchors: Array, collector: RefCounted, probe_phase: String, entry: Dictionary, player: Node2D) -> Dictionary:
	collector.set_phase(probe_phase)
	var stimulus := str(entry.get("stimulus", "autofire"))
	var elapsed := 0.0
	var frames := 0
	while elapsed < seconds and frames < MAX_LIVE_FRAMES:
		await process_frame
		frames += 1
		elapsed += maxf(_holder.get_process_delta_time(), 0.0)
		collector.advance_frame()
		if stimulus == "summon_lethal" and frames % SUMMON_LETHAL_INTERVAL_FRAMES == 0:
			_kill_one_summon(player)
		if str(entry.get("fixture", "")) == "mortal":
			_refill_mortal_targets(entry, dummies, anchors, collector, player)
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]
	return {"duration_seconds": elapsed, "frame_count": frames}


# Executable trigger for the summon-death family: the fixture's dummies never
# fight back, so the probe applies the lethal hit itself through the production
# take_damage path that emits the death burst.
func _kill_one_summon(player: Node2D) -> void:
	for member in get_nodes_in_group("allies"):
		var ally := member as Node2D
		if ally == null or not is_instance_valid(ally) or not ally.has_method("take_damage"):
			continue
		if int(ally.get("constellation_owner_instance_id")) != player.get_instance_id():
			continue
		if float(ally.get("health")) <= 0.0:
			continue
		ally.call("take_damage", maxf(float(ally.get("max_health")), 1.0) * 4.0, "%s_summon_lethal" % TRACE_PREFIX)
		return


func _teardown() -> void:
	if _holder == null:
		return
	for group_name in ["player_weapons", "allies", "engineer_devices", "player_weapon_effects"]:
		for member in get_nodes_in_group(group_name):
			if is_instance_valid(member):
				var node := member as Node
				node.process_mode = Node.PROCESS_MODE_DISABLED
				if node.has_method("cleanup_effects"):
					node.call("cleanup_effects")
	for child in _holder.get_children():
		if is_instance_valid(child):
			(child as Node).process_mode = Node.PROCESS_MODE_DISABLED
			(child as Node).queue_free()
	await process_frame
	await process_frame
	await process_frame


func _write_fragment(fragment: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Pack.FRAGMENT_DIR))
	var file := FileAccess.open(Pack.FRAGMENT_PATH, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write %s" % Pack.FRAGMENT_PATH)
		return
	file.store_string(JSON.stringify(fragment, "\t", true, true) + "\n")
	file.close()
	print("%s conditional fragment written: %d pairs." % [ISSUE_ID, (fragment.get("measurements", {}) as Dictionary).size()])


func _finish() -> void:
	if _errors.is_empty():
		print("%s conditional final A/B convergence passed." % ISSUE_ID)
		quit(0)
		return
	_fail()


func _fail() -> void:
	for error_value in _errors:
		push_error(error_value)
	quit(1)
