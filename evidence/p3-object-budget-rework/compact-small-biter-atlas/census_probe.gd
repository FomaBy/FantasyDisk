extends SceneTree

# FAN-3934 causal diagnostic (06:12 stage): the ORIGINAL FAN-3877 P3 scenario,
# replicated exactly (setup/warmup/reinforcement/duration/boss/ultimate/
# population), with a per-second causal census: enemy-kind counts by canonical
# actor identity, every FullFrameBody consumer (live AND dying — polled from the
# whole tree, not groups), unique frame-resource paths with instance IDs,
# object/node monitors, and feedback-pool occupancy. Diagnostic only: it cannot
# satisfy the decisive acceptance matrix. Census is read-only; observed
# resources are not retained beyond the run (references exist only inside each
# census call scope).

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const WARMUP_SECONDS := 12.0
const SAMPLE_SECONDS := 60.0

var _ultimate_attempts := 0
var _ultimate_activations := 0
var _next_ultimate_usec := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or String(args[0]) != "census":
		printerr("FAN3934_CENSUS_ERROR: expected 'census' arg")
		quit(1)
		return
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
		printerr("FAN3934_CENSUS_ERROR: combat did not start")
		quit(1)
		return
	console.call("execute_command", "godmode")
	console.call("execute_command", "timer 3600")
	main.set("spawn_cooldown", 3600.0)
	_reinforce_runtime(main)
	var boss := get_first_node_in_group("bosses")
	if boss == null:
		printerr("FAN3934_CENSUS_ERROR: no boss")
		quit(1)
		return

	var rows: Array[Dictionary] = []
	var warmup_started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - warmup_started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
		_maintain_scenario(main)
	var sample_started := Time.get_ticks_usec()
	var bucket_started := sample_started
	while float(Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		if now - bucket_started >= 1000000:
			rows.append(_census(rows.size() + 1))
			bucket_started = now
			_maintain_scenario(main)
	main.queue_free()
	await process_frame
	await process_frame
	var report := {
		"kind": "p3-census-diagnostic",
		"candidate_sha": _git("HEAD"),
		"rows": rows,
		"ultimate_attempts": _ultimate_attempts,
		"ultimate_activations": _ultimate_activations,
	}
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/compact-small-biter-atlas/census-%s.json" % String(Time.get_datetime_string_from_system(false)).replace(":", ""), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ") + "\n")
	f.close()
	print("FAN3934_CENSUS_DONE rows=%d" % rows.size())
	quit(0)


func _census(second_index: int) -> Dictionary:
	# Enemy kinds by canonical actor identity: enemy_type_name via the actor's
	# script state (dying actors often leave groups but keep the property).
	var kind_counts := {}
	var consumers := {}
	var frame_paths := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var n_name := String(node.name)
		if n_name == "FullFrameBody":
			var owner_node: Node = node.get_parent()
			var kind := "unknown"
			if owner_node != null and owner_node.get("enemy_type_name") != null:
				kind = str(owner_node.get("enemy_type_name"))
			var frames = node.get("sprite_frames")
			var path := str(frames.resource_path) if frames != null else "<null>"
			consumers[owner_node.get_instance_id() if owner_node != null else 0] = {"kind": kind, "frames": path, "frames_instance": frames.get_instance_id() if frames != null else 0}
			frame_paths[path] = int(frame_paths.get(path, 0)) + 1
		if node.is_in_group("enemies") or node.is_in_group("bosses") or node.is_in_group("summoned_enemies"):
			var type_name = node.get("enemy_type_name")
			if type_name != null:
				var k := str(type_name)
				kind_counts[k] = int(kind_counts.get(k, 0)) + 1
		for child in node.get_children():
			stack.append(child)
	var pool_active := 0
	var pool_idle := 0
	for scene_node in root.get_children():
		var timeline = scene_node.get_node_or_null("CombatFeedbackTimeline") if scene_node is Node else null
		if timeline == null:
			continue
		for child in timeline.get_children():
			if child is Label:
				if child.visible: pool_active += 1
				else: pool_idle += 1
			elif child is Sprite2D:
				if child.visible: pool_active += 1
				else: pool_idle += 1
	return {
		"second": second_index,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"enemy_kind_counts": kind_counts,
		"fullframe_consumers": consumers,
		"unique_frame_paths": frame_paths.keys(),
		"pool_active": pool_active,
		"pool_idle": pool_idle,
	}


func _maintain_scenario(main: Node) -> void:
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


func _git(rev: String) -> String:
	var output: Array = []
	var code := OS.execute("git", ["rev-parse", rev], output, true)
	if code != 0 or output.is_empty():
		return "unavailable"
	return String(output[0]).strip_edges()
