extends Node2D

## FAN-3985 player-path probe for the 51 weapon ultimates.
##
## Drives the shipped player path instead of the presentation runtime:
##   res://scenes/Main.tscn -> selected class/weapon -> Main._start_combat()
##   -> (Priest: press the real battle-prayer button) -> real Player
##   -> Player.activate_ultimate() -> UltimatePlayerHost -> controller/executor
##   -> host-owned WeaponUltimatePresentationRuntime -> authored scene,
## then keeps the game running past the declared cancel of the presentation so
## every executor beat, every enemy death and every victim impact runs. A
## release build that touches a freed enemy crashes here (exit by signal); the
## editor prints `... freed ...` script errors, which `tools/godot_gate.py`
## turns into a failure. Adapted from the independent QA probe of the first
## FAN-3985 review (QA Claude), which found the release crashes.
##
## Two entry points share one implementation:
## - Exported build (`tools/ultimate_export_probe.py`, player-path stage): this
##   script is the `override.cfg` main scene of a cloned exported app, one
##   process per pair, user arguments after `--`:
##     --report=<absolute path>   JSON report (required to auto-run)
##     --pair=<class>/<weapon>    one pair (default: every canonical pair)
##     --captures=<absolute dir>  save a real game frame at the active beat
##     --wait-margin=<seconds>    extra game time after the declared cancel
## - Editor gate (`tests/ultimates/player_path_release_safety_test.gd`): the
##   test instantiates this script without arguments and awaits `run_pair`.

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const HOST_PATH := "res://scripts/ultimates/controller/ultimate_player_host.gd"
const MANIFEST_PATH := "res://scripts/ultimates/presentation/weapon_ultimate_presentation_manifest.gd"
const RESOLVER_PATH := "res://scripts/ultimates/registry/weapon_ultimate_resolver.gd"
const DOCS_MANIFEST_PROBE := "res://docs/design/references/weapon_ultimates/knight/manifest.json"
const MAX_FINALIZE_FRAMES := 6000
const SETTLE_FRAMES := 20
const MIN_WAIT_SECONDS := 4.0
const DEFAULT_WAIT_MARGIN := 1.0
const MAX_WAIT_FRAMES := 30000
const PLAYER_HEALTH := 1000000.0

var _report_path := ""
var _pair := ""
var _capture_dir := ""
var _wait_margin := DEFAULT_WAIT_MARGIN
var _label: Label = null


func _ready() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--pair="):
			_pair = arg.trim_prefix("--pair=")
		elif arg.begins_with("--captures="):
			_capture_dir = arg.trim_prefix("--captures=")
		elif arg.begins_with("--wait-margin="):
			_wait_margin = float(arg.trim_prefix("--wait-margin="))
	if _report_path.is_empty():
		# Embedded by the editor gate: it drives run_pair() itself.
		return
	_build_overlay()
	await get_tree().process_frame
	await _run_standalone()


func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	overlay.add_child(_label)
	add_child(overlay)


func _run_standalone() -> void:
	var PlayerHost = load(HOST_PATH)
	var registry = PlayerHost.shared_registry()
	var report := {
		"probe": "tools/ultimate_player_path_probe.gd",
		"environment": {
			"editor_feature": OS.has_feature("editor"),
			"template_feature": OS.has_feature("template"),
			"display_server": DisplayServer.get_name(),
			"executable_path": OS.get_executable_path(),
			"user_data_dir": OS.get_user_data_dir(),
			"engine_version": Engine.get_version_info().get("string", ""),
			"docs_manifest_present": FileAccess.file_exists(DOCS_MANIFEST_PROBE),
			"updates_check_on_startup": ProjectSettings.get_setting("updates/check_on_startup", null),
		},
		"pairs": [],
	}
	var pairs: Array = report["pairs"]
	for raw_class_id in registry.class_ids():
		var class_id := str(raw_class_id)
		for raw_weapon_id in registry.weapon_ids(class_id):
			var weapon_id := str(raw_weapon_id)
			if not _pair.is_empty() and _pair != "%s/%s" % [class_id, weapon_id]:
				continue
			pairs.append(await run_pair(class_id, weapon_id, {
				"capture_dir": _capture_dir,
				"wait_margin": _wait_margin,
			}))
	var passed := 0
	for entry in pairs:
		if bool((entry as Dictionary).get("pass", false)):
			passed += 1
	report["pairs_total"] = pairs.size()
	report["pairs_passing"] = passed
	report["pass"] = passed == pairs.size() and pairs.size() > 0
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("ultimate_player_path_probe: %d/%d pairs pass; report %s" % [passed, pairs.size(), _report_path])
	get_tree().quit(0 if bool(report["pass"]) else 1)


## Runs one pair through the shipped player path and returns its record.
## Options: `capture_dir` (String, windowed only), `wait_margin` (float).
func run_pair(class_id: String, weapon_id: String, options: Dictionary = {}) -> Dictionary:
	var PlayerHost = load(HOST_PATH)
	var Manifest = load(MANIFEST_PATH)
	var Resolver = load(RESOLVER_PATH)
	var registry = PlayerHost.shared_registry()
	var key := "%s/%s" % [class_id, weapon_id]
	var failures: Array[String] = []
	var entry := {"key": key, "class_id": class_id, "weapon_id": weapon_id}
	var capture_dir := str(options.get("capture_dir", ""))
	var wait_margin := float(options.get("wait_margin", DEFAULT_WAIT_MARGIN))
	get_tree().paused = false
	Engine.time_scale = 1.0

	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().process_frame
	await get_tree().process_frame
	main.set("selected_character_id", class_id)
	main.set("selected_weapon_id", weapon_id)
	main.call("_start_combat", false, "battle")
	await get_tree().process_frame

	var player := main.get("current_player") as Node2D
	if player != null and player.has_method("battle_prayer_choices") \
			and not (player.call("battle_prayer_choices") as Array).is_empty() \
			and str(player.call("active_battle_prayer_id")) == "":
		var button := _first_prayer_button(main)
		entry["battle_prayer_button"] = button != null
		if button != null:
			button.emit_signal("pressed")
			entry["battle_prayer_selected"] = str(player.call("active_battle_prayer_id"))
		else:
			failures.append("battle prayer UI has no button")
	entry["combat_finalized"] = await _await_finalized(main)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

	player = main.get("current_player") as Node2D
	if player == null:
		failures.append("no live player after _start_combat")
		return await _close(main, entry, failures)
	player.set("max_health", PLAYER_HEALTH)
	player.set("health", PLAYER_HEALTH)
	entry["player_character_id"] = str(player.get("character_id"))
	entry["player_weapon_id"] = str(player.get("weapon_id"))
	if entry["player_character_id"] != class_id or entry["player_weapon_id"] != weapon_id:
		failures.append("player runs %s/%s" % [entry["player_character_id"], entry["player_weapon_id"]])

	var source := str(registry.resolution_source(class_id, weapon_id))
	entry["resolution_source"] = source
	if source != Resolver.SOURCE_WEAPON_PROFILE:
		failures.append("resolution_source=%s" % source)
	var record: Dictionary = Manifest.class_weapon_record(class_id, weapon_id)
	var expected_scene := str(record.get("scene_path", ""))
	var timing: Dictionary = record.get("timing", {}) as Dictionary
	entry["expected_scene"] = expected_scene

	var host = PlayerHost.for_player(player)
	# Headless display servers make the host presentation a timeline-only
	# no-op; force the authored scene exactly as the headless suites do, so
	# scene drivers and their victim handling run on this path too.
	if DisplayServer.get_name() == "headless":
		host.set("_presentation_headless_mode", 0)
	entry["headless_scene_forced"] = DisplayServer.get_name() == "headless"
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	var activated := bool(player.call("activate_ultimate"))
	entry["activate_ultimate"] = activated
	entry["activation_failure"] = str(PlayerHost.activation_failure(player))
	var presentation = host.get("_presentation")
	entry["presentation_active"] = presentation != null and bool(presentation.is_active())
	var scene = presentation.get("_scene") if presentation != null else null
	entry["instantiated_scene"] = str(scene.scene_file_path) if scene is Node else ""
	if not activated:
		failures.append("Player.activate_ultimate() returned false (%s)" % entry["activation_failure"])
	if not bool(entry["presentation_active"]):
		failures.append("no live host presentation after activation")
	if expected_scene.is_empty() or entry["instantiated_scene"] != expected_scene:
		failures.append("instantiated %s, expected %s" % [entry["instantiated_scene"], expected_scene])
	if not str(entry["instantiated_scene"]).begins_with("res://scenes/vfx/ultimates/%s/" % class_id):
		failures.append("instantiated scene is not class-owned")

	# Game time, not frames: headless runs may be unthrottled, and a cast may
	# change Engine.time_scale (hitstop), so the wait accumulates process
	# deltas until the presentation's declared cancel plus the margin.
	var cancel := float(timing.get("cancel", 0.0))
	var active := float(timing.get("active", 0.0))
	var capture_at := active + maxf(0.2, (float(timing.get("recovery", active + 1.0)) - active) * 0.35)
	var wait_seconds := maxf(MIN_WAIT_SECONDS, cancel + wait_margin)
	var elapsed := 0.0
	var frames := 0
	var captured := false
	var capture_wanted := not capture_dir.is_empty() and DisplayServer.get_name() != "headless" and activated
	if capture_wanted and _label != null:
		_label.text = "FAN-3985 exported build, real Player.activate_ultimate()  %s\n%s\n%s" % [
			key, entry["instantiated_scene"], OS.get_executable_path()]
	while elapsed < wait_seconds and frames < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		frames += 1
		elapsed += get_process_delta_time()
		if capture_wanted and not captured and elapsed >= capture_at:
			captured = true
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var path := "%s/%s__%s.png" % [capture_dir, class_id, weapon_id]
			entry["capture"] = path if image != null and image.save_png(path) == OK else ""
			entry["capture_seconds_after_activation"] = snappedf(elapsed, 0.001)
			if entry["capture"] == "":
				failures.append("capture failed")
	if capture_wanted and not captured:
		failures.append("capture beat %.2fs never reached in %.2fs" % [capture_at, elapsed])
	if _label != null:
		_label.text = ""
	entry["survived_game_seconds"] = snappedf(elapsed, 0.001)
	entry["survived_frames"] = frames
	entry["wait_seconds"] = wait_seconds
	if elapsed < wait_seconds:
		failures.append("game time stalled at %.2fs of %.2fs" % [elapsed, wait_seconds])
	presentation = host.get("_presentation")
	entry["presentation_active_at_end"] = presentation != null and bool(presentation.is_active())
	return await _close(main, entry, failures)


func _close(main: Node, entry: Dictionary, failures: Array[String]) -> Dictionary:
	var player := main.get("current_player") as Node2D
	if player != null and is_instance_valid(player):
		var host := player.get_node_or_null("UltimateHost")
		if host != null:
			host.call("ultimate_host_finish_presentation", "player_path_probe")
	get_tree().paused = false
	Engine.time_scale = 1.0
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	entry["failures"] = failures
	entry["pass"] = failures.is_empty()
	print("ultimate_player_path_probe: %s pass=%s source=%s scene=%s survived=%ss failures=%s" % [
		entry["key"], entry["pass"], entry.get("resolution_source", ""),
		entry.get("instantiated_scene", ""), entry.get("survived_game_seconds", 0.0), failures])
	return entry


func _await_finalized(main: Node) -> bool:
	var combat = main.get("combat")
	if combat == null:
		return false
	for _frame in MAX_FINALIZE_FRAMES:
		if not is_instance_valid(combat):
			return false
		if bool(combat.get("_combat_start_finalized")):
			return true
		if not bool(main.get("combat_active")) or not bool(combat.get("_combat_roster_wait_pending")):
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
