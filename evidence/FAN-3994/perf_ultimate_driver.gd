extends Node2D

## FAN-3994 performance driver: the FAN-3981 P2 scenario (48 enemies kept
## alive, real `Main._start_combat()` battle) with the player's weapon
## ultimate cast repeatedly, measured INSIDE the installed release app.
##
## Launched the FAN-3985 way: a clone of the installed `FantasyDisk.app` gets
## an `override.cfg` beside its executable whose `run/main_scene` is a
## generated scene carrying this script (official export templates refuse
## `--script`/`--main-pack`), with an isolated user directory so the player's
## saves are never touched. Everything that runs — Main, combat director,
## enemies, `Player.activate_ultimate()`, the ultimate host, resolver and the
## authored presentation scenes — is the PCK's own exported code and data.
##
## Per wall-clock second the FAN-3981 sampler records FPS (average, 1 % low =
## worst 1 % of seconds, worst second), frames over 50/100 ms, longest frame,
## peak RENDER_TEXTURE_MEM_USED, `Performance.OBJECT_COUNT` (peak, minimum,
## per-second series), alive enemies and resident full-frame packs. Every
## `--cast-every` seconds the ultimate charge is filled and the real
## `Player.activate_ultimate()` is called; each cast records whether it
## activated, the resolver source, the instantiated presentation scene and
## the longest frame in the 60 frames after the cast. The shipped charge
## ledger allows ONE activation per encounter (FAN-1460/FAN-2090
## `rare_charge_ledger`), so before every cast the driver calls the ledger's
## own `begin_encounter()` — the same reset a new battle performs — and
## records it; nothing else in the cast path is bypassed.
##
## The 48-enemy population is spawned and settled BEFORE the sample window
## (as the FAN-3981 P2 window starts after the roster is finalized), so the
## window measures the fight with ultimates, not the initial spawn burst.
##
## User arguments after `--`:
##   --report=<absolute path>     JSON report (required to auto-run)
##   --label=<name>               build label in the report
##   --class=<id> --weapon=<id>   hero (default berserk/sword, as FAN-3981)
##   --seconds=<n>                P2 window length (default 60)
##   --cast-every=<n>             seconds between ultimate casts (default 8)
##   --captures=<absolute dir>    save one real game frame after the first cast

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const HOST_PATH := "res://scripts/ultimates/controller/ultimate_player_host.gd"
const RESOLVER_PATH := "res://scripts/ultimates/registry/weapon_ultimate_resolver.gd"
const REGISTRY_SCRIPT := "res://scripts/full_frame_animation_registry.gd"
const P2_TARGET_ALIVE := 48
const SETTLE_FRAMES := 60
const MAX_FINALIZE_FRAMES := 6000
const PLAYER_HEALTH := 1000000.0
const FIRST_CAST_SECOND := 3
const CAPTURE_FRAMES_AFTER_CAST := 24
const RNG_SEED := 3989

var _report_path := ""
var _label := "build"
var _character_id := "berserk"
var _weapon_id := "sword"
var _seconds := 60
var _cast_every := 8
var _capture_dir := ""
var _main: Node = null
var _registry: Script = null
var _casts: Array = []
var _failures: Array[String] = []
var _overlay_label: Label = null
var _capture_countdown := -1
var _capture_path := ""
var _sample_deltas: Array = []


func _ready() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--label="):
			_label = arg.trim_prefix("--label=")
		elif arg.begins_with("--class="):
			_character_id = arg.trim_prefix("--class=")
		elif arg.begins_with("--weapon="):
			_weapon_id = arg.trim_prefix("--weapon=")
		elif arg.begins_with("--seconds="):
			_seconds = int(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--cast-every="):
			_cast_every = maxi(1, int(arg.trim_prefix("--cast-every=")))
		elif arg.begins_with("--captures="):
			_capture_dir = arg.trim_prefix("--captures=")
	if _report_path.is_empty():
		return
	if ResourceLoader.exists(REGISTRY_SCRIPT):
		_registry = load(REGISTRY_SCRIPT)
	_build_overlay()
	await get_tree().process_frame
	await _run()


func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	_overlay_label = Label.new()
	_overlay_label.position = Vector2(24, 20)
	_overlay_label.add_theme_font_size_override("font_size", 20)
	_overlay_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	_overlay_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_overlay_label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(_overlay_label)
	add_child(overlay)


func _texture_mib() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0


func _objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func _resident_packs() -> int:
	if _registry != null and _registry.has_method("prefetched_frames_count"):
		return int(_registry.call("prefetched_frames_count"))
	return -1


func _run() -> void:
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	var report := {
		"driver": "evidence/FAN-3994/perf_ultimate_driver.gd",
		"label": _label,
		"character_id": _character_id,
		"weapon_id": _weapon_id,
		"seconds_requested": _seconds,
		"cast_every": _cast_every,
		"environment": {
			"editor_feature": OS.has_feature("editor"),
			"template_feature": OS.has_feature("template"),
			"executable_path": OS.get_executable_path(),
			"user_data_dir": OS.get_user_data_dir(),
			"engine_version": Engine.get_version_info().get("string", ""),
			"renderer": RenderingServer.get_current_rendering_method(),
			"vsync": DisplayServer.window_get_vsync_mode(),
			"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"project_version": str(ProjectSettings.get_setting("application/config/version", "")),
		},
	}
	print("driver %s: renderer=%s vsync=%s window=%s exe=%s" % [_label, report["environment"]["renderer"], report["environment"]["vsync"], DisplayServer.window_get_size(), OS.get_executable_path()])
	report["menu_objects_before_main"] = _objects()
	report["menu_texture_mib"] = _texture_mib()

	get_tree().paused = false
	Engine.time_scale = 1.0
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await get_tree().process_frame
	await get_tree().process_frame
	_main.set("selected_character_id", _character_id)
	_main.set("selected_weapon_id", _weapon_id)
	var rng = _main.get("rng")
	if rng is RandomNumberGenerator:
		(rng as RandomNumberGenerator).seed = RNG_SEED
	var wait_started := Time.get_ticks_usec()
	_main.call("_start_combat", false, "battle")
	await get_tree().process_frame

	var player := _main.get("current_player") as Node2D
	if player != null and player.has_method("battle_prayer_choices") \
			and not (player.call("battle_prayer_choices") as Array).is_empty() \
			and str(player.call("active_battle_prayer_id")) == "":
		var button := _first_prayer_button(_main)
		report["battle_prayer_button"] = button != null
		if button != null:
			button.emit_signal("pressed")
			report["battle_prayer_selected"] = str(player.call("active_battle_prayer_id"))
		else:
			_failures.append("battle prayer UI has no button")
	report["combat_finalized"] = await _await_finalized()
	report["finalize_wait_ms"] = float(Time.get_ticks_usec() - wait_started) / 1000.0
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame

	player = _main.get("current_player") as Node2D
	if player == null:
		_failures.append("no live player after _start_combat")
		await _finish(report, {})
		return
	player.set("max_health", PLAYER_HEALTH)
	player.set("health", PLAYER_HEALTH)
	player.set("debug_godmode", true)
	_main.set("round_time_left", 600.0)
	report["player_character_id"] = str(player.get("character_id"))
	report["player_weapon_id"] = str(player.get("weapon_id"))
	if report["player_character_id"] != _character_id or report["player_weapon_id"] != _weapon_id:
		_failures.append("player runs %s/%s" % [report["player_character_id"], report["player_weapon_id"]])
	var PlayerHost = load(HOST_PATH)
	var registry = PlayerHost.shared_registry()
	report["resolution_source"] = str(registry.resolution_source(_character_id, _weapon_id))
	report["ultimate_max_charge"] = float(player.get("ultimate_max_charge"))
	_topup()
	for _i in range(SETTLE_FRAMES * 2):
		await get_tree().process_frame
	report["alive_before_window"] = get_tree().get_nodes_in_group("enemies").size()
	report["objects_before_window"] = _objects()

	var phase := await _sample("p2_48_enemies_ultimates", _seconds, Callable(self, "_tick"))
	phase["alive_at_end"] = get_tree().get_nodes_in_group("enemies").size()
	phase["time_scale_at_end"] = Engine.time_scale
	# What the scene tree holds at the end of the window: node classes and
	# instantiated scene files by count (diagnoses what an object-count rise
	# is made of — enemies, drops, VFX, presentation scenes).
	phase["tree_breakdown"] = _tree_breakdown()
	await _finish(report, phase)


func _finish(report: Dictionary, phase: Dictionary) -> void:
	report["phase"] = phase
	report["casts"] = _casts
	var activated := 0
	var scene_paths := {}
	for cast in _casts:
		var entry := cast as Dictionary
		if bool(entry.get("activated", false)):
			activated += 1
		scene_paths[str(entry.get("instantiated_scene", ""))] = true
		var start := int(entry.get("frame_index", -1))
		var longest := 0.0
		if start >= 0:
			for index in range(start, mini(start + 60, _sample_deltas.size())):
				longest = maxf(longest, float(_sample_deltas[index]))
		entry["longest_frame_ms_within_60_frames"] = longest
	report["casts_total"] = _casts.size()
	report["casts_activated"] = activated
	report["instantiated_scenes"] = scene_paths.keys()
	if _casts.is_empty():
		_failures.append("no ultimate cast was attempted")
	if activated < _casts.size():
		_failures.append("%d of %d casts did not activate" % [_casts.size() - activated, _casts.size()])
	if _main != null and is_instance_valid(_main):
		var player := _main.get("current_player") as Node2D
		if player != null and is_instance_valid(player):
			var host := player.get_node_or_null("UltimateHost")
			if host != null:
				host.call("ultimate_host_finish_presentation", "fan3994_perf_driver")
		var combat = _main.get("combat")
		if combat != null and is_instance_valid(combat) and combat.has_method("_end_combat"):
			combat.call("_end_combat", false)
		await get_tree().process_frame
		var ui = _main.get("ui")
		if ui != null and is_instance_valid(ui) and ui.has_method("_show_main_menu"):
			ui.call("_show_main_menu")
		for _i in range(90):
			await get_tree().process_frame
		report["menu_objects_after_run"] = _objects()
		report["menu_texture_after_run_mib"] = _texture_mib()
		report["menu_resident_packs_after_run"] = _resident_packs()
	get_tree().paused = false
	Engine.time_scale = 1.0
	report["failures"] = _failures
	report["pass"] = _failures.is_empty()
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	if not phase.is_empty():
		print("| %s | %s/%s | %d | %.0f | %.0f | %.0f | %d | %d | %.1f | %.0f | %d | %d | %d | %d | %d -> %d | casts %d/%d |" % [_label, _character_id, _weapon_id, phase["seconds"], phase["avg_fps"], phase["low_1pct_fps"], phase["worst_second_fps"], phase["frames_over_50ms"], phase["frames_over_100ms"], phase["longest_frame_ms"], phase["peak_texture_mib"], phase["objects_peak"], phase["objects_min"], phase["objects_first_second"], phase["objects_last_second"], phase["resident_packs_start"], phase["resident_packs_end"], activated, _casts.size()])
	print("perf_ultimate_driver: %s %s/%s pass=%s source=%s casts=%d/%d scenes=%s failures=%s" % [_label, _character_id, _weapon_id, report["pass"], report.get("resolution_source", ""), activated, _casts.size(), scene_paths.keys(), _failures])
	get_tree().quit(0 if bool(report["pass"]) else 1)


# Called once per elapsed second: keep 48 enemies alive and cast the ultimate
# every `_cast_every` seconds starting at FIRST_CAST_SECOND.
func _tick(second: int) -> void:
	_topup()
	if second >= FIRST_CAST_SECOND and (second - FIRST_CAST_SECOND) % _cast_every == 0:
		_cast(second)


func _topup() -> void:
	var combat = _main.get("combat")
	if combat == null or not is_instance_valid(combat):
		return
	var arena_center: Vector2 = _main.get("ARENA_CENTER")
	var rng: RandomNumberGenerator = _main.get("rng")
	var alive := get_tree().get_nodes_in_group("enemies").size()
	while alive < P2_TARGET_ALIVE:
		var scene: PackedScene = combat.call("_random_enemy_scene")
		if scene == null:
			return
		var position := arena_center + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(380.0, 620.0)
		var enemy = combat.call("_spawn_random_enemy", scene, position, true)
		if enemy == null:
			return
		alive += 1


func _cast(second: int) -> void:
	var player := _main.get("current_player") as Node2D
	var entry := {"second": second, "objects_before": _objects(), "alive": get_tree().get_nodes_in_group("enemies").size()}
	if player == null or not is_instance_valid(player):
		entry["activated"] = false
		entry["activation_failure"] = "no live player"
		_casts.append(entry)
		return
	var PlayerHost = load(HOST_PATH)
	var host = PlayerHost.for_player(player)
	var ledger = player.get("_ultimate_charge_ledger")
	entry["ledger_begin_encounter"] = ledger != null and ledger.has_method("begin_encounter")
	if bool(entry["ledger_begin_encounter"]):
		ledger.call("begin_encounter")
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	entry["frame_index"] = _sample_deltas.size()
	var activated := bool(player.call("activate_ultimate"))
	entry["activated"] = activated
	entry["activation_failure"] = str(PlayerHost.activation_failure(player))
	var presentation = host.get("_presentation")
	entry["presentation_active"] = presentation != null and bool(presentation.is_active())
	var scene = presentation.get("_scene") if presentation != null else null
	entry["instantiated_scene"] = str(scene.scene_file_path) if scene is Node else ""
	entry["time_scale"] = Engine.time_scale
	_casts.append(entry)
	print("cast @%ds: activated=%s failure=%s scene=%s alive=%d objects=%d" % [second, activated, entry["activation_failure"], entry["instantiated_scene"], entry["alive"], entry["objects_before"]])
	if activated and not _capture_dir.is_empty() and _capture_path.is_empty() and _capture_countdown < 0:
		_capture_countdown = CAPTURE_FRAMES_AFTER_CAST
		if _overlay_label != null:
			_overlay_label.text = "FAN-3994 installed app, real Player.activate_ultimate() in P2 (48 enemies)  %s/%s\n%s\n%s" % [
				_character_id, _weapon_id, entry["instantiated_scene"], OS.get_executable_path()]


func _capture_if_due() -> void:
	if _capture_countdown < 0:
		return
	_capture_countdown -= 1
	if _capture_countdown > 0:
		return
	_capture_countdown = -1
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s__%s__%s.png" % [_capture_dir, _label, _character_id, _weapon_id]
	if image != null and image.save_png(path) == OK:
		_capture_path = path
	else:
		_failures.append("capture failed")
	if _overlay_label != null:
		_overlay_label.text = ""


# FAN-3981 sampler: main-thread frame deltas for `seconds` wall-clock seconds;
# `tick` is called with the elapsed second index when a second completes.
func _sample(phase_name: String, seconds: int, tick: Callable) -> Dictionary:
	var started := Time.get_ticks_usec()
	var last := started
	var deltas: Array = []
	_sample_deltas = deltas
	var per_second: Array = []
	var objects_per_second: Array = []
	var alive_per_second: Array = []
	var frames_this_second := 0
	var second_index := 0
	var peak_texture := _texture_mib()
	var objects_peak := _objects()
	var objects_min := objects_peak
	var packs_start := _resident_packs()
	if tick.is_valid():
		tick.call(0)
	while true:
		await get_tree().process_frame
		await _capture_if_due()
		var now := Time.get_ticks_usec()
		var delta_ms := float(now - last) / 1000.0
		last = now
		deltas.append(delta_ms)
		frames_this_second += 1
		peak_texture = maxf(peak_texture, _texture_mib())
		var objects := _objects()
		objects_peak = maxi(objects_peak, objects)
		objects_min = mini(objects_min, objects)
		var elapsed_s := int((now - started) / 1000000)
		if elapsed_s > second_index:
			per_second.append(frames_this_second)
			objects_per_second.append(objects)
			alive_per_second.append(get_tree().get_nodes_in_group("enemies").size() + get_tree().get_nodes_in_group("bosses").size())
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
	var stats := {
		"phase": phase_name,
		"seconds": per_second.size(),
		"avg_fps": avg,
		"low_1pct_fps": low_sum / float(low_count),
		"worst_second_fps": float(sorted_seconds[0]) if not sorted_seconds.is_empty() else 0.0,
		"frames_over_50ms": over_50,
		"frames_over_100ms": over_100,
		"longest_frame_ms": longest,
		"frames_total": deltas.size(),
		"peak_texture_mib": peak_texture,
		"objects_peak": objects_peak,
		"objects_min": objects_min,
		"objects_first_second": int(objects_per_second[0]) if not objects_per_second.is_empty() else objects_peak,
		"objects_last_second": int(objects_per_second[-1]) if not objects_per_second.is_empty() else objects_peak,
		"objects_per_second": objects_per_second,
		"alive_per_second": alive_per_second,
		"resident_packs_start": packs_start,
		"resident_packs_end": _resident_packs(),
		"per_second_fps": per_second,
		"capture": _capture_path,
	}
	print("phase %s: %d s, avg %.0f FPS, 1%% low %.0f, worst second %.0f, >50 ms %d, >100 ms %d, longest %.1f ms, peak texture %.0f MiB, objects peak %d min %d (first s %d, last s %d), resident packs %d -> %d, alive first s %d last s %d" % [phase_name, per_second.size(), avg, stats["low_1pct_fps"], stats["worst_second_fps"], over_50, over_100, longest, peak_texture, objects_peak, objects_min, stats["objects_first_second"], stats["objects_last_second"], packs_start, stats["resident_packs_end"], int(alive_per_second[0]) if not alive_per_second.is_empty() else -1, int(alive_per_second[-1]) if not alive_per_second.is_empty() else -1])
	return stats


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
		await get_tree().process_frame
	return bool(combat.get("_combat_start_finalized"))


func _first_prayer_button(main: Node) -> BaseButton:
	var ui_layer = main.get("ui_layer")
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


func _tree_breakdown() -> Dictionary:
	var classes := {}
	var scenes := {}
	var groups := {}
	var total := 0
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		total += 1
		classes[node.get_class()] = int(classes.get(node.get_class(), 0)) + 1
		if not node.scene_file_path.is_empty():
			scenes[node.scene_file_path] = int(scenes.get(node.scene_file_path, 0)) + 1
		for group in node.get_groups():
			groups[str(group)] = int(groups.get(str(group), 0)) + 1
		for child in node.get_children():
			stack.append(child)
	return {
		"nodes_total": total,
		"classes_top": _top(classes, 25),
		"scenes_top": _top(scenes, 20),
		"groups": groups,
		"objects_now": _objects(),
	}


func _top(counts: Dictionary, limit: int) -> Array:
	var rows: Array = []
	for key in counts:
		rows.append([key, counts[key]])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return rows.slice(0, limit)
