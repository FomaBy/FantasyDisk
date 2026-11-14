extends SceneTree

## FAN-4003 pickup economy and scan-cost probe.
##
## `--mode=economy` plays one real first-stage normal fight (60 s timer) per
## class with its first weapon. The hero stands still and cannot die, so only
## the weapons decide where enemies die; drops outside pickup radius stay on the
## ground. Reports gold credited to `gold_collected`, lifetime XP gained, kills
## and the peak live pickup node count. Run on the baseline and the candidate
## with the same seeds to compare per-fight rewards.
##
## `--mode=bench` times CombatDirector._update_pickups with 0, 200 and 1000
## unmerged ground pickups out of reach, and with 1000 drops routed through
## _spawn_pickup (merged/capped on the candidate).
##
## Run (isolated profile):
##   python3 tools/godot_gate.py --headless --fixed-fps 60 --path . \
##     --script res://tools/fan4003_pickup_economy_probe.gd -- --mode=economy
## The script makes no assumption about the candidate's new API, so the same
## file runs unchanged against the pre-FAN-4003 baseline.

const ProgressionData := preload("res://scripts/progression_data.gd")
const TreeData := preload("res://scripts/meta_progression_tree_data.gd")
const BENCH_SIZES := [0, 200, 1000]
const BENCH_CALLS := 600
const MAX_FIGHT_FRAMES := 60 * 120
const MAX_START_FRAMES := 60 * 300

var _mode := "economy"
var _classes: Array = []
var _runs := 1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.substr(7)
		elif arg.begins_with("--classes="):
			_classes = Array(arg.substr(10).split(",", false))
		elif arg.begins_with("--runs="):
			_runs = maxi(1, int(arg.substr(7)))
	if _classes.is_empty():
		_classes = (TreeData.CLASS_ORDER as Array).duplicate()
	if _mode == "bench":
		await _bench()
	else:
		await _economy()
	quit(0)


func _new_fight(character_id: String, weapon_id: String, seed_value: int) -> Node:
	seed(seed_value)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.set("selected_character_id", character_id)
	main.set("selected_weapon_id", weapon_id)
	(main.get("rng") as RandomNumberGenerator).seed = seed_value
	main.call("_start_combat", false, "battle")
	await process_frame
	# FAN-3977: the timer starts only once the full-frame roster is resident.
	var start_frames := 0
	while not bool(main.get("combat").call("is_combat_start_finalized")) and start_frames < MAX_START_FRAMES:
		await process_frame
		start_frames += 1
	return main


func _lifetime_xp(level: int, xp: int) -> int:
	var total := xp
	var requirement := 5
	for _level in range(1, level):
		total += requirement
		requirement = ProgressionData.next_xp_requirement(requirement)
	return total


func _economy() -> void:
	print("FAN4003_ECONOMY_HEADER run,class,weapon,kills,gold_collected,xp_gained,level,peak_live_pickups,ground_nodes_last_frame,ground_raw_xp_last_frame,ground_raw_money_last_frame,frames")
	for run_index in range(_runs):
		for class_index in range(_classes.size()):
			await _economy_fight(run_index, class_index)


func _economy_fight(run_index: int, class_index: int) -> void:
	var character_id := str(_classes[class_index])
	var weapon_id := str(ProgressionData.weapon_ids(character_id)[0])
	var main := await _new_fight(character_id, weapon_id, 40030 + class_index + 1000 * run_index)
	var player = main.get("current_player")
	if player == null:
		push_error("FAN-4003 probe: no player for %s" % character_id)
		main.queue_free()
		return
	var start_xp := _lifetime_xp(int(player.get("level")), int(player.get("xp")))
	var peak := 0
	var last := {"nodes": 0, "xp": 0, "money": 0}
	var frames := 0
	while bool(main.get("combat_active")) and frames < MAX_FIGHT_FRAMES:
		var hero = main.get("current_player")
		if hero != null and is_instance_valid(hero):
			hero.set("health", float(hero.get("max_health")))
		# Sample the ground every frame of the last second, else every 30.
		if frames % 30 == 0 or float(main.get("round_time_left")) < 1.2:
			var ground := {"nodes": 0, "xp": 0, "money": 0}
			for pickup in main.get_tree().get_nodes_in_group("pickups"):
				if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
					ground["nodes"] += 1
					ground[str(pickup.get("pickup_type")) if str(pickup.get("pickup_type")) == "money" else "xp"] += int(pickup.get("amount"))
			peak = maxi(peak, int(ground["nodes"]))
			last = ground
		await process_frame
		frames += 1
	var snapshot := main.get("run_player_snapshot") as Dictionary
	var metrics := main.get("run_metrics") as Dictionary
	var xp_gained := _lifetime_xp(int(snapshot.get("level", 1)), int(snapshot.get("xp", 0))) - start_xp
	print("FAN4003_ECONOMY_ROW %d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [run_index, character_id, weapon_id, int(metrics.get("kills", 0)), int(metrics.get("gold_collected", 0)), xp_gained, int(snapshot.get("level", 1)), peak, last["nodes"], last["xp"], last["money"], frames])
	main.queue_free()
	await process_frame
	await process_frame


func _bench() -> void:
	var main := await _new_fight("berserk", "sword", 4003)
	var player = main.get("current_player") as Node2D
	var combat = main.get("combat")
	player.global_position = Vector2(80.0, 80.0)
	player.set("health", 1.0e9)
	main.set("round_time_left", 9999.0)
	var pickup_scene := main.get("pickup_scene") as PackedScene
	print("FAN4003_BENCH_HEADER scenario,live_nodes,mean_us,p95_us")
	for size in BENCH_SIZES:
		_clear_pickups(main)
		await process_frame
		var rng := RandomNumberGenerator.new()
		rng.seed = 4003
		for index in range(size):
			var pickup := pickup_scene.instantiate() as Node2D
			main.add_child(pickup)
			pickup.global_position = Vector2(rng.randf_range(800.0, 4000.0), rng.randf_range(600.0, 2200.0))
			pickup.call("setup", "xp" if index % 2 == 0 else "money", 2)
		_report_bench(main, combat, "unmerged_%d" % size)
	_clear_pickups(main)
	await process_frame
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = 4003
	var spawn_start := Time.get_ticks_usec()
	for index in range(1000):
		main.call("_spawn_pickup", "xp" if index % 2 == 0 else "money", 2, Vector2(spawn_rng.randf_range(800.0, 4000.0), spawn_rng.randf_range(600.0, 2200.0)))
	var spawn_us := float(Time.get_ticks_usec() - spawn_start) / 1000.0
	print("FAN4003_BENCH_SPAWN drops=1000 mean_spawn_us=%.2f" % spawn_us)
	_report_bench(main, combat, "spawned_1000")
	main.queue_free()
	await process_frame


func _clear_pickups(main: Node) -> void:
	for pickup in main.get_tree().get_nodes_in_group("pickups"):
		pickup.remove_from_group("pickups")
		pickup.queue_free()


func _report_bench(main: Node, combat, label: String) -> void:
	var live := main.get_tree().get_nodes_in_group("pickups").size()
	for _warm in range(30):
		combat.call("_update_pickups", 1.0 / 60.0)
	var samples: Array = []
	for _call in range(BENCH_CALLS):
		var start := Time.get_ticks_usec()
		combat.call("_update_pickups", 1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - start)
	samples.sort()
	var total := 0
	for sample in samples:
		total += int(sample)
	print("FAN4003_BENCH_ROW %s,%d,%.2f,%d" % [label, live, float(total) / float(samples.size()), int(samples[int(samples.size() * 0.95)])])
