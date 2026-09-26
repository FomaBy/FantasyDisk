extends SceneTree

# FAN-3934 read-only diagnostic: exact P3 reproduction (FAN-3877 conditions)
# with a per-second full node census, attributing the transient object spikes
# to concrete node/owner names. No production code is modified.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const WARMUP_SECONDS := 12.0
const SAMPLE_SECONDS := 60.0

var _ultimate_attempts := 0
var _ultimate_activations := 0
var _next_ultimate_usec := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
		printerr("FAN3934_CENSUS_ERROR combat did not start")
		quit(1)
		return
	console.call("execute_command", "godmode")
	console.call("execute_command", "timer 3600")
	main.set("spawn_cooldown", 3600.0)
	_reinforce_runtime(main)

	var warmup_started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - warmup_started) / 1000000.0 < WARMUP_SECONDS:
		await process_frame
		_maintain_scenario(main)

	var samples := []
	var sample_started := Time.get_ticks_usec()
	var bucket_started := sample_started
	var peak_second := {"objects": 0, "census": {}}
	while float(Time.get_ticks_usec() - sample_started) / 1000000.0 < SAMPLE_SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		if now - bucket_started >= 1000000:
			var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var census := _node_census()
			samples.append({
				"second": samples.size() + 1,
				"objects": objects, "nodes": nodes, "non_node": objects - nodes,
				"census": census,
			})
			if objects > int(peak_second["objects"]):
				peak_second = samples[-1]
			bucket_started = now
			_maintain_scenario(main)

	var result := {
		"candidate_sha": _command_output(["git", "rev-parse", "HEAD"]),
		"samples": samples,
		"peak_second": peak_second,
		"ultimate_attempts": _ultimate_attempts,
		"ultimate_activations": _ultimate_activations,
	}
	var peak := 0
	for s in samples:
		peak = maxi(peak, int(s["objects"]))
	result["objects_peak"] = peak
	DirAccess.make_dir_recursive_absolute("res://evidence/p3-object-budget-rework/attribution")
	var f := FileAccess.open("res://evidence/p3-object-budget-rework/attribution/census_full.json", FileAccess.WRITE)
	f = FileAccess.open("res://evidence/p3-object-budget-rework/attribution/census_full.json", FileAccess.WRITE)
	if f == null:
		printerr("FAN3934_CENSUS_ERROR cannot write output")
		quit(1)
		return
	f.store_string(JSON.stringify(result, "  ") + "\n")
	f.close()
	print("FAN3934_CENSUS_RESULT " + JSON.stringify({"peak": peak, "peak_second": peak_second.get("second")}))
	quit(0)

func _node_census() -> Dictionary:
	var counts := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var key := String(node.name)
		var us := key.find("_")
		if us > 0:
			key = key.substr(0, us)
		counts[key] = int(counts.get(key, 0)) + 1
		for child in node.get_children():
			stack.append(child)
	return counts

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

func _command_output(command: PackedStringArray) -> String:
	var output: Array = []
	var exit_code := OS.execute(command[0], command.slice(1), output, true)
	if exit_code != 0 or output.is_empty():
		return "unavailable"
	return String(output[0]).strip_edges()
