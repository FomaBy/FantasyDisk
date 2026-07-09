extends SceneTree

# SCRUM-973: deterministic monitor-selector contract test.
#
# Physical multi-monitor hardware is deliberately not required. The test drives
# the existing pending-video state with virtual screen counts, verifies the
# actual Apply/Revert persistence path in headless mode, and guards the small
# DisplayServer call-site that supplies labels and runtime fallback clamping.
# Existing renderer/UI matrix tests remain responsible for visual geometry.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GameSettings := preload("res://scripts/game_settings.gd")
const DisplayResolution := preload("res://scripts/display_resolution.gd")
const SAVE_PATH := "user://settings.cfg"


func _initialize() -> void:
	var had_original := FileAccess.file_exists(SAVE_PATH)
	var original_bytes := PackedByteArray()
	if had_original:
		var original := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if original != null:
			original_bytes = original.get_buffer(original.get_length())
			original.close()

	var errors: Array[String] = []
	await _run(errors)

	if had_original:
		var restored := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if restored != null:
			restored.store_buffer(original_bytes)
			restored.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	if not errors.is_empty():
		for error in errors:
			push_error("Monitor selector behavior: %s" % error)
		push_error("Monitor selector behavior test: %d errors." % errors.size())
		quit(1)
		return
	print("Monitor selector behavior test passed (visibility/labels/clamp/Apply/Revert/persistence).")
	quit(0)


func _expect(errors: Array[String], condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)


func _run(errors: Array[String]) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_test_virtual_monitor_option_model(errors)

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui = main.ui
	_expect(errors, ui != null, "main.ui was not initialized")
	if ui == null:
		main.queue_free()
		await process_frame
		return

	_test_resolution_contract(main, errors)
	_test_runtime_monitor_adapter(ui, errors)
	_test_virtual_screen_clamping(main, ui, errors)
	await _test_single_screen_visibility(ui, errors)
	await _test_apply_revert_and_restart(main, ui, errors)


func _test_virtual_monitor_option_model(errors: Array[String]) -> void:
	var one_screen: Array[Vector2i] = [Vector2i(1920, 1080)]
	var one_model := DisplayResolution.monitor_options(one_screen, 0)
	_expect(errors, not bool(one_model["visible"]),
		"one-screen monitor selector model should be hidden")
	_expect(errors, int(one_model["selected_index"]) == 0,
		"one-screen model should select screen 0")
	var one_options: Array = one_model["options"]
	_expect(errors, one_options.size() == 1,
		"one-screen model should retain one exact option for runtime geometry")
	if one_options.size() == 1:
		_expect(errors, str(one_options[0]["label"]) == "Экран 1 (1920x1080)",
			"one-screen label is not exact")

	var three_screens: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]
	var three_model := DisplayResolution.monitor_options(three_screens, 1)
	_expect(errors, bool(three_model["visible"]),
		"three-screen monitor selector model should be visible")
	_expect(errors, int(three_model["selected_index"]) == 1,
		"three-screen model did not preserve requested screen 1")
	var options: Array = three_model["options"]
	_expect(errors, options.size() == 3,
		"three-screen model should expose exactly three options")
	var expected_labels := [
		"Экран 1 (1920x1080)",
		"Экран 2 (2560x1440)",
		"Экран 3 (3840x2160)",
	]
	for option_index in range(mini(options.size(), expected_labels.size())):
		var option: Dictionary = options[option_index]
		_expect(errors, int(option["index"]) == option_index,
			"monitor option %d has wrong ordered index" % option_index)
		_expect(errors, option["size"] == three_screens[option_index],
			"monitor option %d has wrong ordered size" % option_index)
		_expect(errors, str(option["label"]) == expected_labels[option_index],
			"monitor option %d has wrong exact label" % option_index)

	var disappeared_model := DisplayResolution.monitor_options(one_screen, 2)
	_expect(errors, int(disappeared_model["selected_index"]) == 0,
		"disappeared screen 2 did not fall back to screen 0")
	_expect(errors, DisplayResolution.sanitize_screen_index(three_screens, -7) == 0,
		"negative virtual monitor index was not clamped to 0")
	_expect(errors, DisplayResolution.sanitize_screen_index(three_screens, 99) == 2,
		"oversized virtual monitor index was not clamped to the last screen")
	var no_screens: Array[Vector2i] = []
	var empty_model := DisplayResolution.monitor_options(no_screens, 4)
	_expect(errors, not bool(empty_model["visible"]),
		"zero-screen defensive model should be hidden")
	_expect(errors, int(empty_model["selected_index"]) == 0,
		"zero-screen defensive model did not return screen 0")
	_expect(errors, (empty_model["options"] as Array).is_empty(),
		"zero-screen defensive model unexpectedly has options")


func _test_runtime_monitor_adapter(ui, errors: Array[String]) -> void:
	var current_sizes: Array[Vector2i] = ui._current_monitor_sizes()
	var screen_count := maxi(DisplayServer.get_screen_count(), 0)
	_expect(errors, current_sizes.size() == screen_count,
		"DisplayServer adapter returned %d sizes for %d screens" % [current_sizes.size(), screen_count])
	for screen_index in range(screen_count):
		_expect(errors, current_sizes[screen_index] == DisplayServer.screen_get_size(screen_index),
			"DisplayServer adapter changed size/order for screen %d" % screen_index)


func _test_resolution_contract(main, errors: Array[String]) -> void:
	var options: Array = main.RESOLUTION_OPTIONS
	_expect(errors, options.size() == 2,
		"monitor selector must not reintroduce removed resolutions (got %d options)" % options.size())
	if options.size() == 2:
		_expect(errors, options[0] == Vector2i(2560, 1440), "first resolution is not 2560x1440")
		_expect(errors, options[1] == Vector2i(1920, 1080), "fallback resolution is not 1920x1080")


func _test_virtual_screen_clamping(main, ui, errors: Array[String]) -> void:
	var one_screen: Array[Vector2i] = [Vector2i(1920, 1080)]
	var three_screens: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]
	main.selected_screen_index = 2
	ui.settings_video_pending.clear()
	_expect(errors, int(ui._settings_monitor_model(one_screen)["selected_index"]) == 0,
		"saved screen 2 did not fall back to screen 0 when only one screen remains")
	_expect(errors, int(ui._settings_monitor_model(three_screens)["selected_index"]) == 2,
		"valid saved screen 2 was not preserved for a three-screen setup")

	ui.settings_video_pending["screen_index"] = -7
	_expect(errors, int(ui._settings_monitor_model(three_screens)["selected_index"]) == 0,
		"negative pending screen index was not clamped to 0")
	ui.settings_video_pending["screen_index"] = 99
	_expect(errors, int(ui._settings_monitor_model(three_screens)["selected_index"]) == 2,
		"oversized pending screen index was not clamped to the last screen")
	var no_screens: Array[Vector2i] = []
	_expect(errors, int(ui._settings_monitor_model(no_screens)["selected_index"]) == 0,
		"zero-screen defensive path did not return screen 0")


func _test_single_screen_visibility(ui, errors: Array[String]) -> void:
	if DisplayServer.get_screen_count() > 1:
		return
	ui.settings_video_pending.clear()
	ui._show_settings_menu()
	await process_frame
	await process_frame
	var selector := root.find_child("SettingsScreenOption", true, false)
	_expect(errors, selector == null,
		"SettingsScreenOption should be absent when only one screen is available")


func _test_apply_revert_and_restart(main, ui, errors: Array[String]) -> void:
	main.selected_screen_index = 0
	main.selected_resolution_index = 0
	main.selected_window_mode_index = 0
	ui.settings_video_pending = ui._current_video_settings()
	_expect(errors, not ui._settings_video_dirty(), "fresh pending video state is unexpectedly dirty")

	ui.settings_video_pending["screen_index"] = 1
	_expect(errors, ui._settings_video_dirty(), "pending monitor change did not enable dirty state")
	ui._revert_pending_video_settings()
	await process_frame
	await process_frame
	_expect(errors, main.selected_screen_index == 0, "Revert changed the applied monitor")
	_expect(errors, int(ui.settings_video_pending.get("screen_index", -1)) == 0,
		"Revert did not restore the applied monitor into pending state")
	_expect(errors, not ui._settings_video_dirty(), "Revert left video state dirty")

	# Virtual three-screen selection: headless cannot move a physical window, but
	# it executes the same pending -> game -> save path used by Apply.
	ui.settings_video_pending = ui._current_video_settings()
	ui.settings_video_pending["screen_index"] = 2
	ui.settings_video_pending["resolution_index"] = 1
	ui.settings_video_pending["window_mode_index"] = 1
	ui._apply_pending_video_settings()
	await process_frame
	await process_frame
	_expect(errors, main.selected_screen_index == 2, "Apply did not commit pending monitor 2")
	_expect(errors, main.selected_resolution_index == 1, "Apply did not commit fallback resolution")
	_expect(errors, main.selected_window_mode_index == 1, "Apply did not commit pending window mode")
	_expect(errors, not ui._settings_video_dirty(), "Apply did not reset pending state to applied values")

	var persisted := GameSettings.load_settings()
	_expect(errors, int(persisted.get("screen_index", -1)) == 2,
		"Apply did not persist selected monitor 2")
	_expect(errors, int(persisted.get("resolution_index", -1)) == 1,
		"Apply did not persist Full HD fallback")
	_expect(errors, int(persisted.get("window_mode_index", -1)) == 1,
		"Apply did not persist window mode")

	main.queue_free()
	await process_frame
	await process_frame
	var restarted := MAIN_SCENE.instantiate()
	root.add_child(restarted)
	await process_frame
	await process_frame
	_expect(errors, restarted.selected_screen_index == 2,
		"restart did not restore persisted monitor 2")
	_expect(errors, restarted.selected_resolution_index == 1,
		"restart did not restore persisted fallback resolution")
	_expect(errors, restarted.selected_window_mode_index == 1,
		"restart did not restore persisted window mode")
	restarted.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
