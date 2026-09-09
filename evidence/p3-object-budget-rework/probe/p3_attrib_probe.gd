extends SceneTree

# FAN-3934 task-owned read-only diagnostic probe (write set evidence/p3-object-budget-rework/**).
# Reproduces the exact FAN-3877 P3 scenario (12 s warm-up + 60 s sample, identical
# setup/maintenance commands) and adds allocation attribution:
#   - per-variant runtime ablations of individual boss attack cadences via the
#     boss script's exported interval properties (no production code changes);
#   - per-second object/node monitors identical to the original probe;
#   - an end-of-sample node census grouped by node name and script.
# Variants: full | no_volley | no_rift | no_summon | no_unique | no_attacks |
#           no_enemies | no_enemies_no_attacks

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const WARMUP_SECONDS := 12.0
const SAMPLE_SECONDS := 60.0
const OFF := 1.0e9

var _variant := ""
var _ultimate_attempts := 0
var _ultimate_activations := 0
var _next_ultimate_usec := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("missing variant argument")
		return
	_variant = String(args[0])
	var known := ["full", "no_volley", "no_rift", "no_summon", "no_unique", "no_attacks", "no_enemies", "no_enemies_no_attacks"]
	if _variant not in known:
		_fail("unknown variant %s" % _variant)
		return

	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var baseline_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "axe")
	var console = main.get("dev_console")
	console.call("execute_command", "fight boss")
	await create_timer(2.0).timeout
	if not bool(main.get("combat_active")):
		_fail("combat did not start")
		return
	console.call("execute_command", "godmode")
	console.call("execute_command", "timer 3600")
	main.set("spawn_cooldown", 3600.0)
	_reinforce_runtime(main)
	var boss := get_first_node_in_group("bosses")
	if boss == null:
		_fail("no live boss after setup")
		return
	_apply_variant(boss)

	var result := await _sample(main)
	result["variant"] = _variant
	result["candidate_sha"] = _command_output(["git", "rev-parse", "HEAD"])
	result["baseline_object_count"] = baseline_objects
	result["baseline_orphan_nodes"] = baseline_orphans
	result["boss_behavior"] = str(boss.get("boss_behavior"))
	result["ultimate_attempts"] = _ultimate_attempts
	result["ultimate_activations"] = _ultimate_activations
	result["node_census"] = _node_census()
	result["renderer"] = RenderingServer.get_current_rendering_driver_name()

	main.queue_free()
	await process_frame
	await process_frame
	result["post_cleanup_orphan_nodes"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	result["post_cleanup_object_count"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))

	var json_path := "res://evidence/p3-object-budget-rework/attribution/%s.json" % _variant
	DirAccess.make_dir_recursive_absolute("res://evidence/p3-object-budget-rework/attribution")
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		_fail("cannot write %s" % json_path)
		return
	json_file.store_string(JSON.stringify(result, "  ") + "\n")
	json_file.close()
	print("FAN3934_ATTRIB_RESULT " + JSON.stringify({"variant": _variant, "objects": result["objects"], "nodes": result["nodes"]}))
	quit(0)


func _apply_variant(boss: Node) -> void:
	# Read-only runtime ablation: the boss script exposes these attack intervals
	# as exported properties; steering them to OFF suppresses one allocation
	# category per variant without touching any production file.
	match _variant:
		"no_volley":
			boss.set("burst_interval", OFF)
			boss.set("_burst_cooldown", OFF)
		"no_rift":
			boss.set("rift_zone_interval", OFF)
			boss.set("_rift_zone_cooldown", OFF)
			boss.set("zone_wave_interval", OFF)
			boss.set("_zone_wave_cooldown", OFF)
		"no_summon":
			boss.set("boss_summon_interval", OFF)
			boss.set("_boss_summon_cooldown", OFF)
		"no_unique":
			boss.set("_boss_unique_cooldown", OFF)
		"no_attacks", "no_enemies_no_attacks":
			boss.set("burst_interval", OFF)
			boss.set("_burst_cooldown", OFF)
			boss.set("rift_zone_interval", OFF)
			boss.set("_rift_zone_cooldown", OFF)
			boss.set("zone_wave_interval", OFF)
			boss.set("_zone_wave_cooldown", OFF)
			boss.set("boss_summon_interval", OFF)
			boss.set("_boss_summon_cooldown", OFF)
			boss.set("_boss_unique_cooldown", OFF)
			boss.set("_slam_cooldown", OFF)
			boss.set("slam_interval", OFF)
			boss.set("_dash_cooldown", OFF)
			boss.set("dash_interval", OFF)


func _sample(main: Node) -> Dictionary:
	var object_counts: Array[int] = []
	var node_counts: Array[int] = []
	var orphan_counts: Array[int] = []
	var second_objects: Array[int] = []
	var second_nodes: Array[int] = []
	var second_enemies: Array[int] = []
	var second_bosses: Array[int] = []
	var csv_rows := PackedStringArray(["elapsed_s,objects,nodes,orphans"])

	var started := Time.get_ticks_usec()
	var bucket_started := started
	var warmup_deadline := started + int(WARMUP_SECONDS * 1000000.0)
	while Time.get_ticks_usec() < warmup_deadline:
		await process_frame
		_maintain_scenario(main)

	var sample_started := Time.get_ticks_usec()
	bucket_started = sample_started
	while float(Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		object_counts.append(objects)
		node_counts.append(nodes)
		orphan_counts.append(orphans)
		if now - bucket_started >= 1000000:
			second_objects.append(objects)
			second_nodes.append(nodes)
			second_enemies.append(get_nodes_in_group("enemies").size())
			second_bosses.append(get_nodes_in_group("bosses").size())
			bucket_started = now
			_maintain_scenario(main)

	var csv_path := "res://evidence/p3-object-budget-rework/attribution/%s.csv" % _variant
	var csv_file := FileAccess.open(csv_path, FileAccess.WRITE)
	if csv_file != null:
		for i in range(object_counts.size()):
			csv_rows.append("%.3f,%d,%d,%d" % [float(i) / 120.0, object_counts[i], node_counts[i], orphan_counts[i]])
		csv_file.store_string("\n".join(csv_rows) + "\n")
		csv_file.close()

	return {
		"pass": false,
		"objects": {
			"start": object_counts[0], "end": object_counts[-1],
			"minimum": _minimum_int(object_counts), "peak": _maximum_int(object_counts),
			"mean": _average_int(object_counts), "per_second": second_objects,
			"limit": 4000,
		},
		"nodes": {"peak": _maximum_int(node_counts), "per_second": second_nodes},
		"orphans": {"start": orphan_counts[0], "end": orphan_counts[-1], "peak": _maximum_int(orphan_counts)},
		"non_node_estimate": {
			# OBJECT_COUNT includes nodes; the remainder is resources/refcounted
			# objects (tweens, tweeners, materials, arrays are not Objects, etc.)
			"peak": _maximum_int(object_counts) - _maximum_int(node_counts),
			"per_second": _diff_per_second(second_objects, second_nodes),
		},
		"population": {"enemy_per_second": second_enemies, "boss_per_second": second_bosses},
		"frames": object_counts.size(),
	}


func _node_census() -> Dictionary:
	var by_name := {}
	var by_script := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var key := String(node.name)
		var underscore := key.find("_")
		if underscore > 0:
			key = key.substr(0, underscore)
		elif key.length() > 2 and key[0] == "@":
			key = key.split("@")[0]
		by_name[key] = int(by_name.get(key, 0)) + 1
		var script: Script = node.get_script()
		var skey := str(script.resource_path) if script != null else node.get_class()
		by_script[skey] = int(by_script.get(skey, 0)) + 1
		for child in node.get_children():
			stack.append(child)
	var names_sorted := by_name.keys()
	names_sorted.sort_custom(func(a, b): return int(by_name[a]) > int(by_name[b]))
	var scripts_sorted := by_script.keys()
	scripts_sorted.sort_custom(func(a, b): return int(by_script[a]) > int(by_script[b]))
	var top_names := {}
	for key in names_sorted.slice(0, 40):
		top_names[key] = by_name[key]
	var top_scripts := {}
	for key in scripts_sorted.slice(0, 25):
		top_scripts[key] = by_script[key]
	return {"total": root.get_tree_string().count("\n"), "by_name_top": top_names, "by_script_top": top_scripts}


func _maintain_scenario(main: Node) -> void:
	_reinforce_runtime(main)
	if _variant in ["no_enemies", "no_enemies_no_attacks"]:
		for hostile in get_nodes_in_group("enemies"):
			if is_instance_valid(hostile):
				hostile.queue_free()
	var now := Time.get_ticks_usec()
	if now < _next_ultimate_usec:
		return
	_next_ultimate_usec = now + 4000000
	var player = main.get("current_player")
	if player == null or not is_instance_valid(player) or not player.has_method("activate_ultimate"):
		return
	_ultimate_attempts += 1
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	if bool(player.call("activate_ultimate")):
		_ultimate_activations += 1


func _reinforce_runtime(main: Node) -> void:
	main.set("round_time_left", 3600.0)
	var player = main.get("current_player")
	if player != null and is_instance_valid(player):
		player.set("debug_godmode", true)
	for group_name in ["enemies", "bosses", "elite_enemies"]:
		for hostile in get_nodes_in_group(group_name):
			if not is_instance_valid(hostile):
				continue
			hostile.set("max_health", 1000000000.0)
			hostile.set("health", 1000000000.0)


func _diff_per_second(objects: Array[int], nodes: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in range(mini(objects.size(), nodes.size())):
		out.append(objects[i] - nodes[i])
	return out


func _minimum_int(values: Array[int]) -> int:
	var result := values[0]
	for value in values:
		result = mini(result, value)
	return result


func _maximum_int(values: Array[int]) -> int:
	var result := values[0]
	for value in values:
		result = maxi(result, value)
	return result


func _average_int(values: Array[int]) -> float:
	var total := 0
	for value in values:
		total += value
	return float(total) / float(values.size())


func _command_output(command: PackedStringArray) -> String:
	var output: Array = []
	var exit_code := OS.execute(command[0], command.slice(1), output, true)
	if exit_code != 0 or output.is_empty():
		return "unavailable"
	return String(output[0]).strip_edges()


func _fail(reason: String) -> void:
	printerr("FAN3934_ATTRIB_PROBE_ERROR: " + reason)
	quit(1)
