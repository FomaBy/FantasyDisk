extends SceneTree

const Pack := preload("res://tools/a5/scenarios/ultimate_atlas/ultimate_atlas_pack.gd")
const MainScript := preload("res://scripts/main.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const DamageTable := preload("res://tools/class_damage_table_3variants.gd")
const UltimateHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")

const PLAYER_POSITION := Vector2(1280.0, 720.0)
const DUMMY_HP := 1.0e9
const TARGET_COUNT := 10
const PACK_RADIUS := 42.0

class RuntimeCollector extends RefCounted:
	var frame := 0
	var ultimate_damage := 0.0
	var ultimate_hits := 0
	var sustain_damage := 0.0
	var sustain_hits := 0
	var by_mechanic := {}
	var ultimate_event_ids := {}
	var missing_ultimate_event_id_count := 0
	var duplicate_ultimate_event_id_count := 0
	var invalid_source_count := 0

	func on_damage(_target: Node2D, _attempted: float, applied: float, feedback: Dictionary) -> void:
		if applied <= 0.0:
			return
		var sources := Pack.damage_sources(feedback)
		if sources.size() != 1:
			invalid_source_count += 1
			return
		if sources[0] == "sustain_source":
			sustain_damage += applied
			sustain_hits += 1
			return
		var event_id := str(feedback.get("ultimate_provenance_event_id", ""))
		if event_id.is_empty():
			missing_ultimate_event_id_count += 1
		elif ultimate_event_ids.has(event_id):
			duplicate_ultimate_event_id_count += 1
		else:
			ultimate_event_ids[event_id] = true
		var mechanic := str(feedback.get("ultimate_mechanic", "activation"))
		ultimate_damage += applied
		ultimate_hits += 1
		var row: Dictionary = by_mechanic.get(mechanic, {"damage": 0.0, "hits": 0, "first_frame": frame})
		row["damage"] = snappedf(float(row.get("damage", 0.0)) + applied, 0.0001)
		row["hits"] = int(row.get("hits", 0)) + 1
		by_mechanic[mechanic] = row


var _holder: Node2D
var _errors := PackedStringArray()
var _class_filter := ""
var _merge_only := false


func _initialize() -> void:
	_parse_args()
	if not _errors.is_empty():
		_finish()
		return
	if _merge_only:
		_merge_checkpoints()
		return
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("aim_mode", "nearest")
	await process_frame
	var measurements := {}
	for class_value in Pack.class_ids():
		var class_id := str(class_value)
		if _class_filter != "" and class_id != _class_filter:
			continue
		measurements[class_id] = await _measure_class(class_id)
	await _teardown()
	if _class_filter != "":
		if _errors.is_empty():
			_write_checkpoint(_class_filter, measurements.get(_class_filter, {}))
		_finish()
		return
	_write_fragment(_fragment_from_class_measurements(measurements))
	_finish()


func _parse_args() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--class="):
			_class_filter = arg.trim_prefix("--class=")
		elif arg == "--merge":
			_merge_only = true
		else:
			_errors.append("unsupported argument %s" % arg)
	if _class_filter != "" and not Pack.class_ids().has(_class_filter):
		_errors.append("unknown class %s" % _class_filter)
	if _class_filter != "" and _merge_only:
		_errors.append("--class and --merge cannot be combined")


func _checkpoint_path(class_id: String) -> String:
	return "%s/ultimate_atlas_%s.json" % [Pack.FRAGMENT_DIR, class_id]


func _write_checkpoint(class_id: String, measurements: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Pack.FRAGMENT_DIR))
	var file := FileAccess.open(_checkpoint_path(class_id), FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write checkpoint for %s" % class_id)
		return
	file.store_string(JSON.stringify({"class_id": class_id, "measurements": measurements}, "\t", true, true) + "\n")
	file.close()


func _merge_checkpoints() -> void:
	var by_class := {}
	for class_value in Pack.class_ids():
		var class_id := str(class_value)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_checkpoint_path(class_id)))
		if not parsed is Dictionary or str((parsed as Dictionary).get("class_id", "")) != class_id:
			_errors.append("missing or invalid checkpoint for %s" % class_id)
			continue
		by_class[class_id] = (parsed as Dictionary).get("measurements", {})
	if _errors.is_empty():
		_write_fragment(_fragment_from_class_measurements(by_class))
	_finish()


func _fragment_from_class_measurements(by_class: Dictionary) -> Dictionary:
	var measurements := {}
	for class_id_value in by_class.keys():
		var class_id := str(class_id_value)
		for scenario_value in Pack.PLAYABLE_SCENARIOS:
			var scenario_id := str(scenario_value)
			measurements["%s|%s" % [class_id, scenario_id]] = ((by_class[class_id] as Dictionary).get(scenario_id, {}) as Dictionary)
	return {
		"fragment_schema": Pack.FRAGMENT_SCHEMA,
		"pack_id": Pack.PACK_ID,
		"pack_contract": Pack.PACK_CONTRACT,
		"issue": "FAN-2412",
		"contract": Pack.contract(),
		"scenario_manifest": Pack.scenario_manifest(),
		"per_weapon_sustain": Pack.per_weapon_sustain_rows(),
		"measurements": measurements,
	}


func _measure_class(class_id: String) -> Dictionary:
	var result := {}
	for scenario_value in Pack.PLAYABLE_SCENARIOS:
		var scenario_id := str(scenario_value)
		result[scenario_id] = await _measure_arm(class_id, scenario_id)
		print("FAN-2412 %s %s activations=%d ultimate_damage=%.2f" % [class_id, scenario_id, int((result[scenario_id] as Dictionary).get("activation_count", 0)), float(((result[scenario_id] as Dictionary).get("ultimate_source", {}) as Dictionary).get("damage", 0.0))])
	return result


func _measure_arm(class_id: String, scenario_id: String) -> Dictionary:
	await _teardown()
	seed(Pack.SEED)
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	player.add_to_group("player")
	player.global_position = PLAYER_POSITION
	var weapon_id := Pack.canonical_weapon(class_id)
	player.call("configure_character", class_id, weapon_id)
	player.set("stats", DamageTable.optimized_stats_for_class(class_id, Pack.PD.base_stats(class_id)))
	player.call("_apply_stat_scaling", true)
	var main := MainScript.new()
	main.set("selected_character_id", class_id)
	main.set("selected_ascension_level", 5)
	main.set("selected_start_boon_id", "")
	main.set("meta_state", Pack.scenario_state(class_id, scenario_id))
	main.set("run_sandbox_captured", false)
	main.call("apply_ascension_bonuses", player)
	main.free()
	await process_frame
	var collector := RuntimeCollector.new()
	var dummies := _spawn_dummies(collector)
	var anchors := []
	for dummy_value in dummies:
		anchors.append((dummy_value as Node2D).global_position)
	var initial_charge := float(player.get("ultimate_charge"))
	var timings := []
	var initial_activations := 0
	for frame in range(Pack.PROBE_FRAMES):
		collector.frame = frame
		if bool(player.call("ultimate_ready")) and not bool(player.get("_ultimate_active")) and bool(player.call("activate_ultimate")):
			var seconds := snappedf(float(frame) / float(Pack.FIXED_FPS), 0.0001)
			timings.append(seconds)
			if frame == 0:
				initial_activations += 1
		await process_frame
		for index in range(dummies.size()):
			if is_instance_valid(dummies[index]):
				(dummies[index] as Node2D).global_position = anchors[index]
	var ultimate_source := {
		"damage": snappedf(collector.ultimate_damage, 0.0001),
		"hits": collector.ultimate_hits,
		"by_mechanic": collector.by_mechanic,
	}
	var measurement := {
		"class_id": class_id,
		"scenario": scenario_id,
		"seed": Pack.SEED,
		"frame_count": Pack.PROBE_FRAMES,
		"duration_seconds": Pack.PROBE_SECONDS,
		"initial_charge": snappedf(initial_charge, 0.0001),
		"initial_activation_count": initial_activations,
		"activation_count": timings.size(),
		"activation_timing_seconds": timings,
		"ultimate_source": ultimate_source,
		"sustain_source": {"damage": snappedf(collector.sustain_damage, 0.0001), "hits": collector.sustain_hits},
		"attribution": {
			"ultimate_event_count": collector.ultimate_hits,
			"missing_ultimate_event_id_count": collector.missing_ultimate_event_id_count,
			"duplicate_ultimate_event_id_count": collector.duplicate_ultimate_event_id_count,
			"invalid_source_count": collector.invalid_source_count,
		},
		"formula": Pack.class_formula(class_id, scenario_id),
	}
	var zero_direct := Pack.zero_direct_declaration(
		class_id, scenario_id, timings.size(), ultimate_source
	)
	if not zero_direct.is_empty():
		measurement["zero_direct_damage"] = zero_direct
	return measurement


func _spawn_dummies(collector: RuntimeCollector) -> Array:
	var dummies := []
	var center := PLAYER_POSITION + Vector2.RIGHT * 100.0
	for index in range(TARGET_COUNT):
		var enemy := EnemyScene.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = center + Vector2.RIGHT.rotated(float(index) * 2.3999632) * PACK_RADIUS
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		enemy.connect("damage_applied", collector.on_damage)
		dummies.append(enemy)
	return dummies


func _teardown() -> void:
	if _holder == null:
		return
	# Active effects can lease a target status. Release them while their targets
	# still exist, otherwise a fixture cleanup can race the effect's _exit_tree.
	for player_value in get_nodes_in_group("player"):
		var player := player_value as Node
		if player != null and is_instance_valid(player):
			UltimateHost.reset(player)
	await process_frame
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
	var verdict := Pack.evaluate_fragment(fragment)
	for error_value in verdict.get("errors", []):
		_errors.append(str(error_value))
	if not _errors.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Pack.FRAGMENT_DIR))
	var file := FileAccess.open(Pack.FRAGMENT_PATH, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write %s" % Pack.FRAGMENT_PATH)
		return
	fragment["verdict"] = "green"
	file.store_string(JSON.stringify(fragment, "\t", true, true) + "\n")
	file.close()


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-2412 ultimate/Atlas attribution probe passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
