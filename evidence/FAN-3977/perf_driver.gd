extends SceneTree

# FAN-3977 performance driver (perf checklist M1 P2 / route-map window /
# texture memory), run WINDOWED so texture uploads hit the real GL
# Compatibility renderer:
#
#   Godot --path <project> --script <abs path to this file> -- label=<name> out=<abs dir> [class=berserk weapon=sword]
#
# The same script runs against v0.3.0, v0.3.2 and the candidate (it only uses
# APIs all three share). Real run path: new run -> route map (prefetch window)
# -> first battle node click -> P2 fight (48 enemies alive, every mini-elite
# kind rolled during the fight) -> victory -> route map -> elite fight
# (night_stalker) -> act-1 boss (rift_warden) -> act-2 boss (disk_devourer)
# -> main menu. Per phase: per-second FPS (average and 1% low = worst 1% of
# seconds), frames over 50/100 ms, longest frame, peak
# RENDER_TEXTURE_MEM_USED. Writes <out>/<label>.json and prints a summary.

const P2_TARGET_ALIVE := 48
const P2_SECONDS := 60
const ELITE_SECONDS := 20
const BOSS_SECONDS := 20
const ROUTE_WINDOW_SECONDS := 8
const SETTLE_FRAMES := 60
const MAX_SEED_SEARCH := 4096
const ACT2_BOSS_ID := "disk_devourer"

var _label := "build"
var _out_dir := ""
var _character_id := "berserk"
var _weapon_id := "sword"
var _main: Node = null
var _phases: Array = []
var _act1_peak_texture := 0.0
var _mini_kinds: Array = []
var _next_mini := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("label="):
			_label = text.trim_prefix("label=")
		elif text.begins_with("out="):
			_out_dir = text.trim_prefix("out=")
		elif text.begins_with("class="):
			_character_id = text.trim_prefix("class=")
		elif text.begins_with("weapon="):
			_weapon_id = text.trim_prefix("weapon=")
	if _out_dir != "":
		DirAccess.make_dir_recursive_absolute(_out_dir)
	await _run()


func _texture_mib() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _run() -> void:
	for _i in range(SETTLE_FRAMES):
		await process_frame
	print("driver %s: renderer=%s vsync=%s window=%s" % [_label, RenderingServer.get_current_rendering_method(), DisplayServer.window_get_vsync_mode(), DisplayServer.window_get_size()])
	var menu_texture := _texture_mib()

	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main.set("selected_character_id", _character_id)
	_main.set("selected_weapon_id", _weapon_id)
	_main.rng.seed = 3977
	_main.set("current_act", 1)
	_main.set("route_nodes", _main.route._generate_route())
	_main.set("route_stage", 0)
	_main.set("route_selected_indices", [])
	_mini_kinds = _main.get("PROGRESSION_DATA").mini_elite_kinds()

	# --- route map window (background prefetch, if the build has one) ---
	_main.route._show_battle_map()
	var route_stats := await _sample("route_map_first_show", ROUTE_WINDOW_SECONDS, Callable())
	route_stats["texture_after_mib"] = _texture_mib()

	# --- P2: first battle node of row 0 on the real click path ---
	var row: Array = _main.get("route_nodes")[0]
	var branch := 0
	for index in range(row.size()):
		if str((row[index] as Dictionary).get("type", "")) == "battle":
			branch = index
			break
	var node: Dictionary = row[branch]
	var click_started := Time.get_ticks_usec()
	_main.route._activate_route_node(0, branch, node)
	await process_frame
	var click_ms := float(Time.get_ticks_usec() - click_started) / 1000.0
	var wait_started := Time.get_ticks_usec()
	await _await_finalized()
	var finalize_wait_ms := float(Time.get_ticks_usec() - wait_started) / 1000.0
	_godmode()
	_main.set("round_time_left", 600.0)
	var p2 := await _sample("p2_48_enemies", P2_SECONDS, Callable(self, "_p2_tick"))
	p2["node_click_frame_ms"] = click_ms
	p2["finalize_wait_ms"] = finalize_wait_ms
	p2["alive_at_end"] = get_nodes_in_group("enemies").size()
	_main.combat._end_combat(true)
	await process_frame
	var route2 := await _sample("route_map_after_p2", 3, Callable())

	# --- elite fight: night_stalker ---
	var stalker_seed := _seed_for_scene(_main.elite_stalker_scene)
	_main.set("current_node_seed", stalker_seed)
	_main.set("current_node_type", "elite_battle")
	wait_started = Time.get_ticks_usec()
	_main.combat._start_combat(false, "elite")
	await process_frame
	await _await_finalized()
	var elite_wait_ms := float(Time.get_ticks_usec() - wait_started) / 1000.0
	_godmode()
	_main.set("round_time_left", 600.0)
	var elite := await _sample("elite_night_stalker", ELITE_SECONDS, Callable(self, "_topup_tick"))
	elite["finalize_wait_ms"] = elite_wait_ms
	elite["elite_full_frame"] = _elite_has_full_frame()
	_main.combat._end_combat(true)
	await process_frame
	await _sample("route_map_after_elite", 3, Callable())

	# --- act-1 boss: rift_warden ---
	var boss1 := await _boss_phase("boss_act1_rift_warden", "rift_warden", 1)
	# --- act-2 boss ---
	var boss2 := await _boss_phase("boss_act2_%s" % ACT2_BOSS_ID, ACT2_BOSS_ID, 2)

	# --- back to the main menu: packs released between runs ---
	_main.combat._end_combat(false)
	await process_frame
	_main.ui._show_main_menu()
	for _i in range(90):
		await process_frame
	var menu_after := _texture_mib()

	var report := {
		"label": _label,
		"character_id": _character_id,
		"weapon_id": _weapon_id,
		"renderer": RenderingServer.get_current_rendering_method(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"menu_texture_mib": menu_texture,
		"menu_texture_after_run_mib": menu_after,
		"act1_peak_texture_mib": _act1_peak_texture,
		"phases": _phases,
	}
	if _out_dir != "":
		var file := FileAccess.open(_out_dir.path_join("%s.json" % _label), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("")
	print("| build | phase | seconds | avg FPS | 1%% low FPS | worst second FPS | frames >50 ms | frames >100 ms | longest frame ms | peak texture MiB |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for phase in _phases:
		print("| %s | %s | %d | %.0f | %.0f | %.0f | %d | %d | %.1f | %.0f |" % [_label, phase["phase"], phase["seconds"], phase["avg_fps"], phase["low_1pct_fps"], phase["worst_second_fps"], phase["frames_over_50ms"], phase["frames_over_100ms"], phase["longest_frame_ms"], phase["peak_texture_mib"]])
	print("%s: menu texture %.0f MiB -> after run %.0f MiB; act-1 peak %.0f MiB; P2 click frame %.1f ms, roster wait %.0f ms; elite roster wait %.0f ms" % [_label, menu_texture, menu_after, _act1_peak_texture, click_ms, finalize_wait_ms, elite_wait_ms])
	quit(0)


func _boss_phase(phase_name: String, boss_id: String, act: int) -> Dictionary:
	_main.set("current_act", act)
	_main.set("current_boss_id", boss_id)
	_main.set("current_node_type", "boss")
	_main.set("secret_boss_active", false)
	var wait_started := Time.get_ticks_usec()
	_main.combat._start_combat(true, "boss")
	await process_frame
	await _await_finalized()
	var wait_ms := float(Time.get_ticks_usec() - wait_started) / 1000.0
	_godmode()
	_main.set("round_time_left", 600.0)
	var stats := await _sample(phase_name, BOSS_SECONDS, Callable(self, "_topup_tick"))
	stats["finalize_wait_ms"] = wait_ms
	var boss := get_first_node_in_group("bosses")
	stats["boss_full_frame"] = boss != null and boss.get_node_or_null("FullFrameBody") != null and (boss.get_node("FullFrameBody") as AnimatedSprite2D).visible
	if act == 1:
		_main.combat._end_combat(true)
		await process_frame
		await _sample("route_map_after_boss1", 3, Callable())
	return stats


func _await_finalized() -> void:
	for _frame in range(3000):
		if bool(_main.combat.get("_combat_start_finalized")) or not bool(_main.get("combat_active")):
			return
		await process_frame


func _godmode() -> void:
	var player = _main.get("current_player")
	if player != null:
		player.set("debug_godmode", true)


func _seed_for_scene(target: PackedScene) -> int:
	for node_seed in range(MAX_SEED_SEARCH):
		if _main.node_elite_scene(node_seed) == target:
			return node_seed
	return 0


func _elite_has_full_frame() -> bool:
	for elite in get_nodes_in_group("elite_enemies"):
		var body := elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if body != null and body.visible and body.sprite_frames != null:
			return true
	return false


# Called once per elapsed second during the P2 window: keep 48 enemies alive
# and roll every mini-elite kind at least once (one kind every 5 s).
func _p2_tick(second: int) -> void:
	_topup_tick(second)
	if second % 5 == 0 and _next_mini < _mini_kinds.size():
		var kind: Dictionary = _mini_kinds[_next_mini]
		_next_mini += 1
		var scene: PackedScene = _main.combat._elite_scene_by_key(str(kind.get("scene", "")))
		if scene == null:
			return
		var elite := scene.instantiate() as Node2D
		elite.set_meta("epic_scale_profile", "mini_elite")
		elite.add_to_group("elite_enemies")
		_main.combat._apply_mini_elite_kind(elite, kind)
		_main.add_child(elite)
		elite.global_position = _main.ARENA_CENTER + Vector2.RIGHT.rotated(_main.rng.randf() * TAU) * 420.0


func _topup_tick(_second: int) -> void:
	var alive := get_nodes_in_group("enemies").size()
	while alive < P2_TARGET_ALIVE:
		var scene: PackedScene = _main.combat._random_enemy_scene()
		if scene == null:
			return
		var enemy = _main.combat._spawn_random_enemy(scene, _main.ARENA_CENTER + Vector2.RIGHT.rotated(_main.rng.randf() * TAU) * _main.rng.randf_range(380.0, 620.0), true)
		if enemy == null:
			return
		alive += 1


# Samples main-thread frame deltas for `seconds`; `tick` (optional) is called
# with the elapsed second index each time a wall-clock second completes.
func _sample(phase_name: String, seconds: int, tick: Callable) -> Dictionary:
	var started := Time.get_ticks_usec()
	var last := started
	var deltas: Array = []
	var per_second: Array = []
	var frames_this_second := 0
	var second_index := 0
	var peak_texture := _texture_mib()
	if tick.is_valid():
		tick.call(0)
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var delta_ms := float(now - last) / 1000.0
		last = now
		deltas.append(delta_ms)
		frames_this_second += 1
		peak_texture = maxf(peak_texture, _texture_mib())
		var elapsed_s := int((now - started) / 1000000)
		if elapsed_s > second_index:
			per_second.append(frames_this_second)
			frames_this_second = 0
			second_index = elapsed_s
			if second_index >= seconds:
				break
			if tick.is_valid():
				tick.call(second_index)
	var sorted_seconds := per_second.duplicate()
	sorted_seconds.sort()
	var low_count := maxi(1, int(ceil(float(sorted_seconds.size()) * 0.01)))
	var low_sum := 0.0
	for index in range(low_count):
		low_sum += float(sorted_seconds[index])
	var avg := 0.0
	for fps in per_second:
		avg += float(fps)
	avg /= max(1, per_second.size())
	var over_50 := 0
	var over_100 := 0
	var longest := 0.0
	for delta in deltas:
		if delta > 50.0:
			over_50 += 1
		if delta > 100.0:
			over_100 += 1
		longest = maxf(longest, delta)
	if phase_name.begins_with("route_map") or phase_name.begins_with("p2") or phase_name.begins_with("elite") or phase_name.begins_with("boss_act1"):
		_act1_peak_texture = maxf(_act1_peak_texture, peak_texture)
	var stats := {
		"phase": phase_name,
		"seconds": per_second.size(),
		"avg_fps": avg,
		"low_1pct_fps": low_sum / float(low_count),
		"worst_second_fps": float(sorted_seconds[0]) if not sorted_seconds.is_empty() else 0.0,
		"frames_over_50ms": over_50,
		"frames_over_100ms": over_100,
		"longest_frame_ms": longest,
		"peak_texture_mib": peak_texture,
		"per_second_fps": per_second,
	}
	_phases.append(stats)
	print("phase %s: %d s, avg %.0f FPS, 1%% low %.0f, worst second %.0f, >50 ms %d, >100 ms %d, longest %.1f ms, peak texture %.0f MiB" % [phase_name, per_second.size(), avg, stats["low_1pct_fps"], stats["worst_second_fps"], over_50, over_100, longest, peak_texture])
	return stats
