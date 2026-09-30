extends SceneTree

## FAN-3991 single-process, multi-class, multi-combat session probe.
##
## The FAN-3985 player-path gate plays every class/weapon pair in a fresh
## process, so it never saw what the native Windows check of 0.3.1.1 found
## (FAN-3990): after combats for another class, Doctor ultimates left a node
## freed while it was still in the tree, and the release build then crashed
## with memory corruption. This probe keeps ONE `scenes/Main.tscn` alive and
## plays combat after combat through the shipped path — `Main._start_combat()`
## -> real Player -> the `ultimate` InputMap action -> executor -> host-owned
## presentation -> natural end of the cast -> `_end_combat(true)` — exactly
## the sequence of the FAN-3990 `qa-mode=ult` driver.
##
## It reports what the session observed; the judge is
## `tests/ultimates/multi_class_session_lifecycle_test.gd`, which runs this
## script in a child Godot process and fails on any engine lifecycle error in
## its output (`Parent node is busy adding/removing children`,
## `Condition "data.parent" is true`, `!data.tree`, `canvas_item is null`, a
## freed-object access), on a crash, or on a non-zero exit.
##
## Run directly:
##   python3 tools/godot_gate.py --headless --path . \
##     --script res://tools/ultimate_session_lifecycle_probe.gd -- \
##     --classes=dark_mage,doctor --report=/abs/path/report.json
##
## User arguments (after `--`):
##   --classes=<a,b,...>   play every weapon of each class, in this order
##   --pairs=<c/w,...>     play exactly these class/weapon pairs, in this order
##   --all                 all 17 classes in registry order (51 pairs)
##   --report=<abs path>   JSON report (optional)
##   --end=<mode>          how each fight ends (default `during_cast`):
##     during_cast  the fight ends through the game's own `_end_combat(true)`
##                  while the cast and its presentation are still live — what
##                  happens when the ultimate kills the last enemy, the round
##                  timer runs out or the player dies mid-cast;
##     natural      wait for the cast to end, one more second, then
##                  `_end_combat(true)` (the FAN-3990 `qa-natural-end` mode);
##     force        free the enemies 2.5 s after the cast started, then
##                  `_end_combat(true)` (the FAN-3990 driver's default mode).
##   --crowd=<n>           FAN-3981/FAN-3990 object-count window instead of a
##                         single cast: keep <n> enemies alive, fire the
##                         `ultimate` action every --cast-every seconds
##                         (default 5) for --window seconds (default 60), and
##                         record the peak `Performance.OBJECT_COUNT`,
##                         alive-enemy range and cast count per pair.

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const HOST_PATH := "res://scripts/ultimates/controller/ultimate_player_host.gd"
const MAX_FINALIZE_FRAMES := 6000
const SETTLE_FRAMES := 20
const MAX_CAST_FRAMES := 6000
const AFTER_CAST_SECONDS := 1.0
const DURING_CAST_SECONDS := 2.5
const END_MODES: Array[String] = ["during_cast", "natural", "force"]
## The FAN-3964/FAN-3990 P2 roster: every enemy kind the crowd window cycles.
const CROWD_SCENES: Array[String] = [
	"res://scenes/Enemy.tscn", "res://scenes/EnemyRunner.tscn", "res://scenes/EnemyBiter.tscn",
	"res://scenes/EnemyBruiser.tscn", "res://scenes/EnemyShield.tscn", "res://scenes/EnemyFlyingRunner.tscn",
	"res://scenes/EnemySummoner.tscn", "res://scenes/EnemyShooter.tscn", "res://scenes/EnemyMage.tscn",
	"res://scenes/EnemySpitter.tscn", "res://scenes/EnemyBoneShaman.tscn",
]
const CROWD_SEED := 3964
const AFTER_END_FRAMES := 20
const PLAYER_HEALTH := 1000000.0

var _report_path := ""
var _sequence: Array[String] = []
var _end_mode := "during_cast"
var _crowd := 0
var _cast_every := 5
var _window_seconds := 60
var _main: Node = null
var _entries: Array = []


func _initialize() -> void:
	_parse_user_args()
	if _sequence.is_empty():
		push_error("ultimate_session_lifecycle_probe: nothing to play (use --classes=, --pairs= or --all)")
		quit(2)
		return
	_run()


func _parse_user_args() -> void:
	var PlayerHost = load(HOST_PATH)
	var registry = PlayerHost.shared_registry()
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--classes="):
			for class_id in arg.trim_prefix("--classes=").split(",", false):
				for weapon_id in registry.weapon_ids(str(class_id)):
					_sequence.append("%s/%s" % [class_id, weapon_id])
		elif arg.begins_with("--pairs="):
			for pair in arg.trim_prefix("--pairs=").split(",", false):
				_sequence.append(str(pair))
		elif arg == "--all":
			for class_id in registry.class_ids():
				for weapon_id in registry.weapon_ids(str(class_id)):
					_sequence.append("%s/%s" % [class_id, weapon_id])
		elif arg.begins_with("--crowd="):
			_crowd = int(arg.trim_prefix("--crowd="))
		elif arg.begins_with("--cast-every="):
			_cast_every = maxi(1, int(arg.trim_prefix("--cast-every=")))
		elif arg.begins_with("--window="):
			_window_seconds = maxi(1, int(arg.trim_prefix("--window=")))
		elif arg.begins_with("--end="):
			_end_mode = arg.trim_prefix("--end=")
			if _end_mode not in END_MODES:
				push_error("ultimate_session_lifecycle_probe: unknown --end=%s" % _end_mode)
				_sequence.clear()
				return


func _run() -> void:
	await process_frame
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	await process_frame
	for key in _sequence:
		var parts := key.split("/")
		if parts.size() != 2:
			_entries.append({"key": key, "pass": false, "failures": ["malformed pair"]})
			continue
		_entries.append(await _play_pair(parts[0], parts[1]))
	var passed := 0
	for entry in _entries:
		if bool((entry as Dictionary).get("pass", false)):
			passed += 1
	var report := {
		"probe": "tools/ultimate_session_lifecycle_probe.gd",
		"engine_version": Engine.get_version_info().get("string", ""),
		"display_server": DisplayServer.get_name(),
		"end_mode": _end_mode,
		"crowd": _crowd,
		"cast_every_seconds": _cast_every,
		"window_seconds": _window_seconds,
		"sequence": _sequence,
		"pairs": _entries,
		"pairs_total": _entries.size(),
		"pairs_passing": passed,
		"pass": passed == _entries.size() and not _entries.is_empty(),
		"peak_object_count": _peak_objects,
	}
	if not _report_path.is_empty():
		var file := FileAccess.open(_report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	# Leave the session the way a player leaves it: the same Main is torn down
	# once, at exit, so a node the session corrupted is freed here too.
	_main.queue_free()
	await process_frame
	await process_frame
	print("ultimate_session_lifecycle_probe: %d/%d pairs pass in one process (peak objects %d)" % [passed, _entries.size(), _peak_objects])
	quit(0 if bool(report["pass"]) else 1)


var _peak_objects := 0


func _sample_objects() -> void:
	_peak_objects = maxi(_peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))


func _play_pair(class_id: String, weapon_id: String) -> Dictionary:
	var PlayerHost = load(HOST_PATH)
	var key := "%s/%s" % [class_id, weapon_id]
	var failures: Array[String] = []
	var entry := {"key": key, "class_id": class_id, "weapon_id": weapon_id}
	paused = false
	Engine.time_scale = 1.0
	_main.set("run_player_snapshot", {})
	_main.set("selected_character_id", class_id)
	_main.set("selected_weapon_id", weapon_id)
	_main.call("_start_combat", false, "battle")
	await process_frame

	var player := _main.get("current_player") as Node2D
	if player != null and player.has_method("battle_prayer_choices") \
			and not (player.call("battle_prayer_choices") as Array).is_empty() \
			and str(player.call("active_battle_prayer_id")) == "":
		var button := _first_prayer_button()
		if button != null:
			button.emit_signal("pressed")
		else:
			failures.append("battle prayer UI has no button")
	entry["combat_finalized"] = await _await_finalized()
	for _i in SETTLE_FRAMES:
		await process_frame

	player = _main.get("current_player") as Node2D
	if player == null or not is_instance_valid(player):
		failures.append("no live player after _start_combat")
		return _close(entry, failures)
	player.set("debug_godmode", true)
	player.set("max_health", PLAYER_HEALTH)
	player.set("health", PLAYER_HEALTH)
	entry["player_character_id"] = str(player.get("character_id"))
	entry["player_weapon_id"] = str(player.get("weapon_id"))
	if entry["player_character_id"] != class_id or entry["player_weapon_id"] != weapon_id:
		failures.append("player runs %s/%s" % [entry["player_character_id"], entry["player_weapon_id"]])

	var host = PlayerHost.for_player(player)
	# Headless display servers make the host presentation a timeline-only
	# no-op; force the authored scene exactly as the headless suites and the
	# FAN-3985 player-path gate do, so the class scenes run on this path too.
	if DisplayServer.get_name() == "headless":
		host.set("_presentation_headless_mode", 0)
	if _crowd > 0:
		await _crowd_window(player, entry)
		if bool(_main.get("combat_active")):
			_main.get("combat").call("_end_combat", true)
		for _i in AFTER_END_FRAMES:
			await process_frame
		_sample_objects()
		return _close(entry, failures)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	await process_frame
	await process_frame
	var charge_before := float(player.get("ultimate_charge"))
	await _press_ultimate_action()
	var activated := bool(player.get("_ultimate_active")) or float(player.get("ultimate_charge")) < charge_before
	entry["activated_by_input_action"] = activated
	entry["activation_failure"] = str(PlayerHost.activation_failure(player))
	var presentation = host.get("_presentation")
	entry["presentation_active"] = presentation != null and bool(presentation.is_active())
	var scene = presentation.get("_scene") if presentation != null else null
	entry["instantiated_scene"] = str(scene.scene_file_path) if scene is Node else ""
	if not activated:
		failures.append("the `ultimate` InputMap action did not activate the ultimate (%s)" % entry["activation_failure"])
	elif not bool(entry["presentation_active"]):
		failures.append("no live host presentation after activation")

	var frames := 0
	if _end_mode == "natural":
		# The gameplay part of the ultimate finishes on its own clock; the
		# presentation may still be draining to its declared cancel.
		while is_instance_valid(player) and bool(player.get("_ultimate_active")) and frames < MAX_CAST_FRAMES:
			await process_frame
			frames += 1
			if frames % 10 == 0:
				_sample_objects()
		if frames >= MAX_CAST_FRAMES:
			failures.append("ultimate still active after %d frames" % frames)
		await create_timer(AFTER_CAST_SECONDS, true, false, true).timeout
	else:
		# The fight ends while the cast is live: the executor chain, the
		# authored presentation and its victim impacts are all still running.
		var elapsed := 0.0
		while elapsed < DURING_CAST_SECONDS and frames < MAX_CAST_FRAMES:
			await process_frame
			frames += 1
			elapsed += root.get_process_delta_time() / maxf(Engine.time_scale, 0.001)
			if frames % 10 == 0:
				_sample_objects()
	entry["cast_frames"] = frames
	_sample_objects()
	entry["ultimate_active_at_end"] = is_instance_valid(player) and bool(player.get("_ultimate_active"))
	entry["presentation_active_at_end"] = host != null and is_instance_valid(host) \
		and host.get("_presentation") != null and bool(host.get("_presentation").is_active())
	if _end_mode == "force":
		for group in ["enemies", "bosses", "elite_enemies"]:
			for node in get_nodes_in_group(group):
				if is_instance_valid(node):
					node.queue_free()
		await process_frame
		await process_frame
	if bool(_main.get("combat_active")):
		_main.get("combat").call("_end_combat", true)
	for _i in AFTER_END_FRAMES:
		await process_frame
	_sample_objects()
	return _close(entry, failures)


## FAN-3981 M3 window as the FAN-3990 Windows check ran it: <crowd> enemies
## kept alive, the ultimate recharged and fired through the InputMap action
## every `_cast_every` seconds, `Performance.OBJECT_COUNT` sampled every second.
func _crowd_window(player: Node2D, entry: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = CROWD_SEED
	var combat = _main.get("combat")
	var spawned := 0
	while _alive_enemies() < _crowd and spawned < _crowd * 4:
		var scene := load(CROWD_SCENES[spawned % CROWD_SCENES.size()]) as PackedScene
		var position: Vector2 = _main.call("_clamp_arena_point",
			player.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(320.0, 460.0))
		combat.call("_spawn_random_enemy", scene, position, true)
		spawned += 1
		if spawned % 6 == 0:
			await process_frame
	var peak_objects := 0
	var alive_min := 1 << 30
	var alive_max := 0
	var casts := 0
	var casts_started := 0
	var samples: Array = []
	for second in _window_seconds:
		_main.set("round_time_left", 120.0)
		if _alive_enemies() < _crowd:
			var scene := load(CROWD_SCENES[spawned % CROWD_SCENES.size()]) as PackedScene
			var position: Vector2 = _main.call("_clamp_arena_point",
				player.global_position + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(320.0, 460.0))
			combat.call("_spawn_random_enemy", scene, position, true)
			spawned += 1
		if second % _cast_every == 1 and is_instance_valid(player):
			player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
			var before := float(player.get("ultimate_charge"))
			casts += 1
			await _press_ultimate_action()
			if is_instance_valid(player) and (bool(player.get("_ultimate_active")) or float(player.get("ultimate_charge")) < before):
				casts_started += 1
		await create_timer(1.0, true, false, true).timeout
		var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var alive := _alive_enemies()
		samples.append(objects)
		peak_objects = maxi(peak_objects, objects)
		alive_min = mini(alive_min, alive)
		alive_max = maxi(alive_max, alive)
		_sample_objects()
	entry["crowd"] = _crowd
	entry["spawned"] = spawned
	entry["peak_objects"] = peak_objects
	entry["object_samples"] = samples
	entry["alive_min"] = alive_min
	entry["alive_max"] = alive_max
	entry["casts"] = casts
	entry["casts_started"] = casts_started
	entry["nodes_at_end"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func _alive_enemies() -> int:
	return get_nodes_in_group("enemies").size() + get_nodes_in_group("bosses").size() \
		+ get_nodes_in_group("elite_enemies").size()


func _close(entry: Dictionary, failures: Array[String]) -> Dictionary:
	paused = false
	Engine.time_scale = 1.0
	entry["failures"] = failures
	entry["pass"] = failures.is_empty()
	if entry.has("peak_objects"):
		print("ultimate_session_lifecycle_probe: %s crowd=%d peak_objects=%d alive=%d..%d casts=%d/%d failures=%s" % [
			entry["key"], entry["crowd"], entry["peak_objects"], entry["alive_min"], entry["alive_max"],
			entry["casts_started"], entry["casts"], failures])
	else:
		print("ultimate_session_lifecycle_probe: %s pass=%s scene=%s cast_frames=%s failures=%s" % [
			entry["key"], entry["pass"], entry.get("instantiated_scene", ""), entry.get("cast_frames", 0), failures])
	return entry


## The shipped input path: the `ultimate` InputMap action, parsed by `Input`,
## read by `Player._physics_process` (`Input.is_action_just_pressed`).
func _press_ultimate_action() -> void:
	var down := InputEventAction.new()
	down.action = "ultimate"
	down.pressed = true
	Input.parse_input_event(down)
	await create_timer(0.15, true, false, true).timeout
	var up := InputEventAction.new()
	up.action = "ultimate"
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _await_finalized() -> bool:
	var combat = _main.get("combat")
	if combat == null:
		return false
	for _frame in MAX_FINALIZE_FRAMES:
		if not is_instance_valid(combat):
			return false
		if bool(combat.get("_combat_start_finalized")):
			return true
		if not bool(_main.get("combat_active")) or not bool(combat.get("_combat_roster_wait_pending")):
			return bool(combat.get("_combat_start_finalized"))
		await process_frame
	return bool(combat.get("_combat_start_finalized"))


func _first_prayer_button() -> BaseButton:
	var ui_layer = _main.get("ui_layer")
	if ui_layer == null:
		return null
	var overlay := (ui_layer as Node).get_node_or_null("LevelUpOverlay")
	if overlay == null:
		return null
	return _find_button(overlay)


func _find_button(node: Node) -> BaseButton:
	for child in node.get_children():
		if child is BaseButton and (child as BaseButton).visible and not (child as BaseButton).disabled:
			return child as BaseButton
		var nested := _find_button(child)
		if nested != null:
			return nested
	return null
