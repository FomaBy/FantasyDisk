extends SceneTree

# FAN-3877 independent QA evidence only. This disposable probe instances the
# shipped Main scene and samples Godot's public Performance monitors under a
# real renderer. It deliberately lives outside production and test code.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const WARMUP_SECONDS := 12.0
const SAMPLE_SECONDS := 60.0
const MIB := 1048576.0
const P1_MEMORY_LIMIT_MIB := 400.0
const COMBAT_MEMORY_LIMIT_MIB := 900.0
const P2_OBJECT_LIMIT := 5000
const P3_OBJECT_LIMIT := 4000

var _scenario := ""
var _fatal_reason := ""
var _ultimate_attempts := 0
var _ultimate_activations := 0
var _next_ultimate_usec := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("missing scenario argument (expected P1, P2, or P3)")
		return
	_scenario = String(args[0]).to_upper()
	if _scenario not in ["P1", "P2", "P3"]:
		_fail("unknown scenario %s" % _scenario)
		return

	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var baseline_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var setup := await _configure_scenario(main)
	if not bool(setup.get("ok", false)):
		if is_instance_valid(main):
			main.queue_free()
		await process_frame
		_fail(String(setup.get("reason", "scenario setup failed")))
		return

	await _warm_up(main)
	var result := await _sample(main)
	result["candidate_sha"] = _command_output(["git", "rev-parse", "HEAD"])
	result["candidate_tree"] = _command_output(["git", "rev-parse", "HEAD^{tree}"])
	result["scenario"] = _scenario
	result["scenario_setup"] = setup
	result["warmup_seconds"] = WARMUP_SECONDS
	result["sample_seconds_target"] = SAMPLE_SECONDS
	result["baseline_object_count"] = baseline_objects
	result["baseline_orphan_nodes"] = baseline_orphans
	result["ultimate_attempts"] = _ultimate_attempts
	result["ultimate_activations"] = _ultimate_activations
	result["renderer"] = RenderingServer.get_current_rendering_driver_name()
	result["rendering_method"] = String(ProjectSettings.get_setting("renderer/rendering_method", ""))
	result["logical_viewport_size"] = "%dx%d" % [root.size.x, root.size.y]
	var window_size := DisplayServer.window_get_size()
	result["display_window_size"] = "%dx%d" % [window_size.x, window_size.y]
	result["godot_version"] = Engine.get_version_info()

	main.queue_free()
	await process_frame
	await process_frame
	var post_cleanup_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var post_cleanup_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	result["post_cleanup_orphan_nodes"] = post_cleanup_orphans
	result["post_cleanup_object_count"] = post_cleanup_objects
	result["cleanup_orphan_delta"] = post_cleanup_orphans - baseline_orphans
	result["checks"]["cleanup_orphans"] = post_cleanup_orphans <= baseline_orphans
	result["pass"] = _all_checks_pass(result["checks"] as Dictionary)

	var json_path := "res://evidence/FAN-3877/perf_%s.json" % _scenario.to_lower()
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		_fail("cannot write %s" % json_path)
		return
	json_file.store_string(JSON.stringify(result, "  ") + "\n")
	json_file.close()
	print("FAN3877_PERF_RESULT " + JSON.stringify(result))
	quit(0 if bool(result["pass"]) else 1)


func _configure_scenario(main: Node) -> Dictionary:
	if _scenario == "P1":
		var menu := main.find_child("MainMenuScreen", true, false)
		if menu == null or not (menu as CanvasItem).visible:
			return {"ok": false, "reason": "P1 main menu is not visible"}
		await create_timer(2.0).timeout
		return {
			"ok": true,
			"description": "Main menu idle",
			"commands": [],
			"initial_enemies": 0,
			"initial_bosses": 0,
		}

	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "axe")
	var console = main.get("dev_console")
	if console == null or not console.has_method("execute_command"):
		return {"ok": false, "reason": "developer console is unavailable"}
	var fight_kind := "battle" if _scenario == "P2" else "boss"
	console.call("execute_command", "fight %s" % fight_kind)
	await create_timer(2.0).timeout
	if not bool(main.get("combat_active")):
		return {"ok": false, "reason": "%s combat did not start" % _scenario}
	console.call("execute_command", "godmode")
	console.call("execute_command", "timer 3600")
	main.set("spawn_cooldown", 3600.0)

	var commands: Array[String] = ["fight %s" % fight_kind, "godmode", "timer 3600"]
	if _scenario == "P2":
		for hostile in get_nodes_in_group("enemies"):
			if is_instance_valid(hostile):
				hostile.queue_free()
		await process_frame
		await process_frame
		for command in ["spawn basic 24", "spawn basic 16", "spawn shooter 8"]:
			console.call("execute_command", command)
			commands.append(command)
		# The live player attacks immediately. Raise health in the same frame as
		# the three spawn calls so the verification measures all 48 actors rather
		# than a partially defeated setup.
		_reinforce_runtime(main)
		await create_timer(1.0).timeout

	_reinforce_runtime(main)
	var enemy_count := get_nodes_in_group("enemies").size()
	var boss_count := get_nodes_in_group("bosses").size()
	if _scenario == "P2" and enemy_count != 48:
		return {"ok": false, "reason": "P2 requires exactly 48 enemies, observed %d" % enemy_count}
	if _scenario == "P3" and boss_count < 1:
		return {"ok": false, "reason": "P3 requires a live boss, observed %d" % boss_count}
	return {
		"ok": true,
		"description": "Mass combat with exactly 48 live enemies" if _scenario == "P2" else "Active boss combat with one contract-permitted ultimate activation",
		"commands": commands,
		"initial_enemies": enemy_count,
		"initial_bosses": boss_count,
		"character_id": "berserk",
		"weapon_id": "axe",
	}


func _warm_up(main: Node) -> void:
	var started := Time.get_ticks_usec()
	_next_ultimate_usec = started
	while float(Time.get_ticks_usec() - started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
		_maintain_scenario(main)


func _sample(main: Node) -> Dictionary:
	var frame_ms: Array[float] = []
	var engine_fps: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var memory_mib: Array[float] = []
	var object_counts: Array[int] = []
	var node_counts: Array[int] = []
	var orphan_counts: Array[int] = []
	var draw_calls: Array[int] = []
	var render_objects: Array[int] = []
	var primitives: Array[int] = []
	var physics_objects: Array[int] = []
	var collision_pairs: Array[int] = []
	var second_fps: Array[float] = []
	var second_objects: Array[int] = []
	var second_enemies: Array[int] = []
	var second_bosses: Array[int] = []
	var csv_rows: PackedStringArray = PackedStringArray([
		"elapsed_s,frame_ms,engine_fps,process_ms,physics_ms,memory_mib,objects,nodes,orphans,draw_calls,render_objects,primitives,physics_objects,collision_pairs"
	])

	var started := Time.get_ticks_usec()
	var previous := started
	var bucket_started := started
	var bucket_frames := 0
	var stalls_over_50ms := 0
	var stalls_over_100ms := 0
	while float(Time.get_ticks_usec() - started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed_s := float(now - started) / 1000000.0
		var delta_ms := float(now - previous) / 1000.0
		previous = now
		bucket_frames += 1
		if delta_ms > 50.0:
			stalls_over_50ms += 1
		if delta_ms > 100.0:
			stalls_over_100ms += 1

		var fps := float(Performance.get_monitor(Performance.TIME_FPS))
		var process_time_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		var physics_time_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		var static_memory_mib := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / MIB
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var rendered := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		var rendered_primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var active_physics := int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
		var pairs := int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
		frame_ms.append(delta_ms)
		engine_fps.append(fps)
		process_ms.append(process_time_ms)
		physics_ms.append(physics_time_ms)
		memory_mib.append(static_memory_mib)
		object_counts.append(objects)
		node_counts.append(nodes)
		orphan_counts.append(orphans)
		draw_calls.append(draws)
		render_objects.append(rendered)
		primitives.append(rendered_primitives)
		physics_objects.append(active_physics)
		collision_pairs.append(pairs)
		csv_rows.append("%.6f,%.6f,%.3f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%d,%d,%d" % [
			elapsed_s, delta_ms, fps, process_time_ms, physics_time_ms, static_memory_mib,
			objects, nodes, orphans, draws, rendered, rendered_primitives, active_physics, pairs,
		])

		if now - bucket_started >= 1000000:
			var bucket_seconds := float(now - bucket_started) / 1000000.0
			second_fps.append(float(bucket_frames) / bucket_seconds)
			second_objects.append(objects)
			second_enemies.append(get_nodes_in_group("enemies").size())
			second_bosses.append(get_nodes_in_group("bosses").size())
			bucket_started = now
			bucket_frames = 0
			_maintain_scenario(main)

	var measured_seconds := float(previous - started) / 1000000.0
	var avg_fps := float(frame_ms.size()) / measured_seconds
	var low_1_percent_fps := _minimum_float(second_fps)
	var memory_limit := P1_MEMORY_LIMIT_MIB if _scenario == "P1" else COMBAT_MEMORY_LIMIT_MIB
	var object_limit := 0 if _scenario == "P1" else (P2_OBJECT_LIMIT if _scenario == "P2" else P3_OBJECT_LIMIT)
	var monotonic_object_growth := _strict_net_monotonic_growth(second_objects)
	var checks := {
		"average_fps_at_least_60": avg_fps >= 60.0,
		"one_percent_low_at_least_45": low_1_percent_fps >= 45.0,
		"static_memory_within_limit": _maximum_float(memory_mib) <= memory_limit,
		"objects_within_limit": true if _scenario == "P1" else _maximum_int(object_counts) <= object_limit,
		"no_monotonic_object_growth": not monotonic_object_growth,
		"steady_orphans_do_not_grow": orphan_counts[-1] <= orphan_counts[0],
		"scenario_population_held": true,
	}
	if _scenario == "P2":
		checks["scenario_population_held"] = _minimum_int(second_enemies) >= 48
	elif _scenario == "P3":
		checks["scenario_population_held"] = _minimum_int(second_bosses) >= 1

	var csv_path := "res://evidence/FAN-3877/perf_%s.csv" % _scenario.to_lower()
	var csv_file := FileAccess.open(csv_path, FileAccess.WRITE)
	if csv_file != null:
		csv_file.store_string("\n".join(csv_rows) + "\n")
		csv_file.close()

	return {
		"pass": false,
		"checks": checks,
		"sample_seconds_actual": measured_seconds,
		"frames": frame_ms.size(),
		"fps": {
			"average_wall_clock": avg_fps,
			"one_percent_low_per_second": low_1_percent_fps,
			"engine_monitor_average": _average_float(engine_fps),
			"per_second_samples": second_fps,
		},
		"frame_time_ms": {
			"p50": _percentile(frame_ms, 0.50),
			"p95": _percentile(frame_ms, 0.95),
			"p99": _percentile(frame_ms, 0.99),
			"maximum": _maximum_float(frame_ms),
			"stalls_over_50ms": stalls_over_50ms,
			"stalls_over_100ms": stalls_over_100ms,
		},
		"process_time_ms": {"p95": _percentile(process_ms, 0.95), "maximum": _maximum_float(process_ms)},
		"physics_time_ms": {"p95": _percentile(physics_ms, 0.95), "maximum": _maximum_float(physics_ms)},
		"static_memory_mib": {"peak": _maximum_float(memory_mib), "limit": memory_limit},
		"objects": {
			"start": object_counts[0],
			"end": object_counts[-1],
			"minimum": _minimum_int(object_counts),
			"peak": _maximum_int(object_counts),
			"limit": object_limit,
			"per_second": second_objects,
			"monotonic_positive_growth": monotonic_object_growth,
		},
		"nodes": {"start": node_counts[0], "end": node_counts[-1], "peak": _maximum_int(node_counts)},
		"orphans": {"start": orphan_counts[0], "end": orphan_counts[-1], "peak": _maximum_int(orphan_counts)},
		"population": {
			"enemy_per_second": second_enemies,
			"boss_per_second": second_bosses,
		},
		"render": {
			"draw_calls_peak": _maximum_int(draw_calls),
			"objects_peak": _maximum_int(render_objects),
			"primitives_peak": _maximum_int(primitives),
		},
		"physics": {
			"active_objects_peak": _maximum_int(physics_objects),
			"collision_pairs_peak": _maximum_int(collision_pairs),
		},
		"raw_csv": csv_path,
	}


func _maintain_scenario(main: Node) -> void:
	if _scenario == "P1":
		return
	_reinforce_runtime(main)
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


func _strict_net_monotonic_growth(values: Array[int]) -> bool:
	if values.size() < 2 or values[-1] <= values[0]:
		return false
	for index in range(1, values.size()):
		if values[index] < values[index - 1]:
			return false
	return true


func _all_checks_pass(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _percentile(values: Array[float], fraction: float) -> float:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return 0.0
	var index := clampi(int(ceil(fraction * float(ordered.size()))) - 1, 0, ordered.size() - 1)
	return ordered[index]


func _average_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _minimum_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result := values[0]
	for value in values:
		result = minf(result, value)
	return result


func _maximum_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var result := values[0]
	for value in values:
		result = maxf(result, value)
	return result


func _minimum_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var result := values[0]
	for value in values:
		result = mini(result, value)
	return result


func _maximum_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var result := values[0]
	for value in values:
		result = maxi(result, value)
	return result


func _command_output(command: PackedStringArray) -> String:
	var output: Array = []
	var exit_code := OS.execute(command[0], command.slice(1), output, true)
	if exit_code != 0 or output.is_empty():
		return "unavailable"
	return String(output[0]).strip_edges()


func _fail(reason: String) -> void:
	_fatal_reason = reason
	printerr("FAN3877_PERF_PROBE_ERROR: " + reason)
	quit(1)
