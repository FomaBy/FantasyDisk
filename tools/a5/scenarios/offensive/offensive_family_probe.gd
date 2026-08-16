extends SceneTree

# FAN-1512: real-runtime same-seed A/B probe for one representative of every
# offensive family. The complete pair matrix is verified by the companion pack.

const Pack := preload("res://tools/a5/scenarios/offensive/offensive_family_pack.gd")
const Report := preload("res://tools/a5_balance_report.gd")
const PD := preload("res://scripts/progression_data.gd")
const Meta := preload("res://scripts/meta_progression.gd")
const Schema6 := preload("res://scripts/constellation_schema6_data.gd")
const MainScript := preload("res://scripts/main.gd")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PLAYER_POSITION := Vector2(1280.0, 720.0)
const PACK_RADIUS := 42.0
const MAX_LIVE_FRAMES := 2400

var _holder: Node2D
var _errors := PackedStringArray()
var _trigger_hits := 0
var _watch_mechanic := ""
var _watch_event := ""
var _pair_filter := ""
var _merge_only := false


func _initialize() -> void:
	_parse_args()
	if not _errors.is_empty():
		_finish()
		return
	if _merge_only:
		_merge_checkpoints()
		return
	Engine.max_fps = 60
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("aim_mode", "nearest")
	await process_frame
	var matrix_check := Pack.verify_matrix()
	if not bool(matrix_check.get("ok", false)):
		_errors.append_array(matrix_check.get("errors", PackedStringArray()))
		_finish()
		return
	var matrix := Pack.family_matrix()
	var measurements := {}
	for entry_value in Pack.representative_matrix(matrix):
		var entry: Dictionary = entry_value
		if _pair_filter != "" and Pack.pair_key(entry) != _pair_filter:
			continue
		var measurement := await _measure_pair(entry)
		measurements[Pack.pair_key(entry)] = measurement
		var result := Pack.evaluate_pair(entry, measurement)
		print("FAN-1512 %s %s A/B=%s formula=%s delta=%+.2f%% event=%s" % [Pack.pair_key(entry), entry.get("family", ""), result.get("ab_verdict", "?"), result.get("formula_live_verdict", "?"), float(result.get("formula_live_delta_pct", 0.0)), JSON.stringify(result.get("event_contribution", {}))])
		for pair_error in result.get("errors", []):
			_errors.append(str(pair_error))
	await _teardown()
	if _pair_filter != "":
		if not _errors.is_empty():
			_finish()
			return
		_write_checkpoint(_pair_filter, measurements.get(_pair_filter, {}))
		_finish()
		return
	var fragment := {
		"fragment_schema": Pack.FRAGMENT_SCHEMA,
		"pack_id": Pack.PACK_ID,
		"pack_contract": Pack.PACK_CONTRACT,
		"issue": "FAN-1512",
		"contract": Pack.contract(),
		"matrix": matrix,
		"measurements": measurements,
	}
	var verdict := Pack.evaluate_fragment(fragment, matrix)
	fragment["ab_verdict"] = "green" if bool(verdict.get("ok", false)) else "red"
	fragment["verdict"] = "green"
	for result_value in verdict.get("pairs", []):
		if str((result_value as Dictionary).get("formula_live_verdict", "")) == "red":
			fragment["verdict"] = "red"
	for error_value in verdict.get("errors", []):
		_errors.append(str(error_value))
	if _errors.is_empty():
		_write_fragment(fragment)
	_finish()


func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--pair="):
			_pair_filter = arg.trim_prefix("--pair=")
		elif arg == "--merge":
			_merge_only = true
		else:
			_errors.append("unsupported argument %s" % arg)
	if _pair_filter != "" and _merge_only:
		_errors.append("--pair and --merge cannot be combined")


func _checkpoint_path(pair: String) -> String:
	return "%s/offensive_family_ab_%s.json" % [Pack.FRAGMENT_DIR, pair.replace("/", "_")]


func _write_checkpoint(pair: String, measurement: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Pack.FRAGMENT_DIR))
	var file := FileAccess.open(_checkpoint_path(pair), FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write checkpoint for %s" % pair)
		return
	file.store_string(JSON.stringify({"pair": pair, "measurement": measurement}, "\t", true, true) + "\n")
	file.close()


func _merge_checkpoints() -> void:
	var matrix := Pack.family_matrix()
	var measurements := {}
	for entry_value in Pack.representative_matrix(matrix):
		var entry: Dictionary = entry_value
		var pair := Pack.pair_key(entry)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_checkpoint_path(pair)))
		if not parsed is Dictionary or str((parsed as Dictionary).get("pair", "")) != pair:
			_errors.append("missing or invalid checkpoint for %s" % pair)
			continue
		measurements[pair] = (parsed as Dictionary).get("measurement", {})
	var fragment := {"fragment_schema": Pack.FRAGMENT_SCHEMA, "pack_id": Pack.PACK_ID, "pack_contract": Pack.PACK_CONTRACT, "issue": "FAN-1512", "contract": Pack.contract(), "matrix": matrix, "measurements": measurements}
	var verdict := Pack.evaluate_fragment(fragment, matrix)
	fragment["ab_verdict"] = "green" if bool(verdict.get("ok", false)) else "red"
	fragment["verdict"] = "green"
	for result_value in verdict.get("pairs", []):
		if str((result_value as Dictionary).get("formula_live_verdict", "")) == "red":
			fragment["verdict"] = "red"
	for error_value in verdict.get("errors", []):
		_errors.append(str(error_value))
	if _errors.is_empty():
		_write_fragment(fragment)
	_finish()


func _measure_pair(entry: Dictionary) -> Dictionary:
	var enabled := _empty_arm()
	var disabled := _empty_arm()
	for seed_value in Pack.SEEDS:
		_accumulate(enabled, await _measure_arm(entry, int(seed_value), true))
		_accumulate(disabled, await _measure_arm(entry, int(seed_value), false))
	var config: Dictionary = PD.weapon(str(entry.get("class_id", "")), str(entry.get("weapon_id", "")))
	var stats := DamageTable.optimized_stats_for_class(str(entry.get("class_id", "")), PD.base_stats(str(entry.get("class_id", ""))))
	var formula := PD.estimate_weapon_budget_for_stats(str(entry.get("class_id", "")), config, stats, true, {}, false)
	return {"enabled": enabled, "disabled": disabled, "formula_expected_dpm": float(formula.get("solo_dps", 0.0)) * 60.0}


func _empty_arm() -> Dictionary:
	return {"trigger_resolutions": 0, "final_event_count": 0, "final_event_damage": 0.0, "ledger_damage": 0.0, "casts": 0, "hits": 0, "unique_target_count": 0, "damage_sources": [], "dpm": 0.0}


func _accumulate(arm: Dictionary, sample: Dictionary) -> void:
	for key in ["trigger_resolutions", "final_event_count", "casts", "hits", "unique_target_count"]:
		arm[key] = int(arm.get(key, 0)) + int(sample.get(key, 0))
	for key in ["final_event_damage", "ledger_damage"]:
		arm[key] = snappedf(float(arm.get(key, 0.0)) + float(sample.get(key, 0.0)), 0.0001)
	for source_value in sample.get("damage_sources", []):
		if not (arm["damage_sources"] as Array).has(str(source_value)):
			(arm["damage_sources"] as Array).append(str(source_value))
	arm["damage_sources"].sort()
	arm["dpm"] = snappedf(float(arm["ledger_damage"]) / (Pack.WINDOW_SECONDS * Pack.SEEDS.size()) * 60.0, 0.0001)


func _measure_arm(entry: Dictionary, seed_value: int, final_enabled: bool) -> Dictionary:
	await _teardown()
	seed(seed_value)
	var class_id := str(entry.get("class_id", ""))
	var weapon_id := str(entry.get("weapon_id", ""))
	var collector := Report.A5TelemetryCollector.new("fan1512:%s:%d:%s" % [Pack.pair_key(entry), seed_value, "enabled" if final_enabled else "disabled"], Pack.pair_key(entry))
	_trigger_hits = 0
	_watch_mechanic = str(entry.get("mechanic_id", ""))
	_watch_event = str(entry.get("expected_event", ""))
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	player.call("configure_character", class_id, weapon_id)
	player.set("stats", DamageTable.optimized_stats_for_class(class_id, PD.base_stats(class_id)))
	player.call("_apply_stat_scaling", true)
	var main := MainScript.new()
	main.set("selected_character_id", class_id)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", _scenario_state(class_id, weapon_id, final_enabled))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	player.connect("weapon_cast_observed", collector.on_weapon_cast)
	player.connect("constellation_final_resolved", collector.on_final_resolution)
	player.connect("constellation_final_resolved", _on_final_resolved)
	await process_frame
	var dummies := _spawn_dummies(entry, collector)
	var anchors := []
	for dummy_value in dummies:
		anchors.append((dummy_value as Node2D).global_position)
	await _advance(Pack.WARMUP_SECONDS, dummies, anchors, collector, "warmup")
	var measurement := await _advance(Pack.WINDOW_SECONDS, dummies, anchors, collector, "measurement")
	if float(measurement.get("duration_seconds", 0.0)) < Pack.WINDOW_SECONDS:
		_errors.append("%s did not complete the measurement window" % Pack.pair_key(entry))
	var sample := collector.build_sample(Pack.pair_key(entry), seed_value, "offensive_family", "sustain", dummies.size())
	var counters: Dictionary = sample.get("counters", {})
	var sources := []
	for bucket_value in counters.get("damage_by_source_phase", []):
		var bucket: Dictionary = bucket_value
		sources.append("%s|%s" % [bucket.get("source", ""), bucket.get("phase", "")])
	return {
		"trigger_resolutions": _trigger_hits,
		"final_event_count": _final_event_count(sample, _watch_mechanic),
		"final_event_damage": _final_event_damage(sample, _watch_mechanic),
		"ledger_damage": float((sample.get("hp_ledger", {}) as Dictionary).get("total_applied_damage", 0.0)),
		"casts": int(counters.get("casts", 0)), "hits": int(counters.get("hits", 0)),
		"unique_target_count": int(counters.get("unique_target_count", 0)), "damage_sources": sources,
	}


func _scenario_state(class_id: String, weapon_id: String, final_enabled: bool) -> Dictionary:
	var state := Meta.default_state()
	state["ascension_levels"] = {class_id: 5}
	var final_node_id := ""
	for raw_branch in Schema6.class_entry(class_id).get("weapon_branches", []):
		var branch: Dictionary = raw_branch
		if str(branch.get("weapon_id", "")) == weapon_id:
			for raw_node in branch.get("nodes", []):
				var node: Dictionary = raw_node
				if str(node.get("role", "")) == "weapon_final":
					final_node_id = str(node.get("node_id", ""))
	var purchased := []
	var hidden_ids := []
	for raw_node in Meta.constellation_nodes(class_id):
		var node: Dictionary = raw_node
		var node_id := str(node.get("id", ""))
		if str(node.get("role", "")) == "hidden":
			hidden_ids.append(node_id)
		if str(node.get("role", "")) != "core" and (final_enabled or node_id != final_node_id):
			purchased.append(node_id)
	state["hidden_reveal_facts"] = {class_id: hidden_ids}
	state["skill_nodes"] = purchased
	return state


func _spawn_dummies(entry: Dictionary, collector: RefCounted) -> Array:
	var geometry: Dictionary = entry.get("geometry", {})
	var direction := Vector2.RIGHT
	match str(geometry.get("orientation", "forward")):
		"diagonal": direction = Vector2(1.0, 1.0).normalized()
		"reverse": direction = Vector2.LEFT
	var center := PLAYER_POSITION + direction * float(geometry.get("distance", 80.0))
	var result := []
	var count := 1 if str(geometry.get("layout", "")) == "solo" else Pack.TARGET_COUNT
	for index in range(count):
		var position := center
		if index > 0:
			position += Vector2.RIGHT.rotated(float(index - 1) * 2.3999632) * PACK_RADIUS * (0.55 + 0.45 * sqrt(float(index) / float(count - 1)))
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = position
		enemy.set("max_health", Pack.DUMMY_HP)
		enemy.set("health", Pack.DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		collector.bind_target(enemy, "target_%d" % index)
		enemy.connect("damage_applied", collector.on_damage_applied)
		enemy.connect("died", collector.on_target_died)
		result.append(enemy)
	return result


func _advance(seconds: float, dummies: Array, anchors: Array, collector: RefCounted, phase: String) -> Dictionary:
	collector.set_phase(phase)
	var elapsed := 0.0
	var frames := 0
	while elapsed < seconds and frames < MAX_LIVE_FRAMES:
		await process_frame
		frames += 1
		elapsed += maxf(_holder.get_process_delta_time(), 0.0)
		collector.advance_frame()
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]
	return {"duration_seconds": elapsed}


func _on_final_resolved(_weapon_id: String, event: String, _target: Node2D, _context: Dictionary, resolution: Dictionary) -> void:
	if event == _watch_event and bool(resolution.get("triggered", false)) and str(resolution.get("mechanic_id", "")) == _watch_mechanic:
		_trigger_hits += 1


func _final_event_count(sample: Dictionary, mechanic_id: String) -> int:
	var count := 0
	for event_value in sample.get("events", []):
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "final_event" and str(event.get("mechanic_id", "")) == mechanic_id:
			count += 1
	return count


func _final_event_damage(sample: Dictionary, mechanic_id: String) -> float:
	var events := {}
	for event_value in sample.get("events", []):
		var event: Dictionary = event_value
		events[str(event.get("event_id", ""))] = event
	var total := 0.0
	for event_value in events.values():
		var event: Dictionary = event_value
		if str(event.get("kind", "")) == "final_event" and str(event.get("mechanic_id", "")) == mechanic_id:
			total += float((events.get(str(event.get("related_hit_id", "")), {}) as Dictionary).get("damage", 0.0))
	return total


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


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-1512 offensive family A/B probe passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
