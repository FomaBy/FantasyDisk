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
const SAVE_PATH := "user://settings.cfg"
const UI_SCREENS_PATH := "res://scripts/ui_screens.gd"


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
	_test_runtime_source_contract(errors)

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
	_test_virtual_screen_clamping(main, ui, errors)
	await _test_single_screen_visibility(ui, errors)
	await _test_apply_revert_and_restart(main, ui, errors)


func _test_runtime_source_contract(errors: Array[String]) -> void:
	var source_file := FileAccess.open(UI_SCREENS_PATH, FileAccess.READ)
	_expect(errors, source_file != null, "cannot read %s" % UI_SCREENS_PATH)
	if source_file == null:
		return
	var source := source_file.get_as_text()
	source_file.close()

	# The selector must not consume space on a one-monitor setup.
	_expect(errors, source.contains("if screen_count > 1:"),
		"SettingsScreenOption is not guarded by screen_count > 1")
	# Stable, user-readable labels: one-based number plus physical size hint.
	_expect(errors, source.contains('screen_options.add_item("Экран %d (%dx%d)"'),
		"monitor option label is not the expected 'Экран N (WxH)' contract")
	# A disappeared saved monitor is clamped before any selected-screen geometry
	# is read or the window is moved.
	var clamp_pos := source.find("game.selected_screen_index = clampi(game.selected_screen_index, 0, maxi(screen_count - 1, 0))")
	var geometry_pos := source.find("var usable := DisplayServer.screen_get_usable_rect(screen)", clamp_pos)
	_expect(errors, clamp_pos >= 0, "runtime apply path does not clamp selected_screen_index")
	_expect(errors, geometry_pos > clamp_pos,
		"runtime apply path reads monitor geometry before clamping a stale index")
	_expect(errors, source.contains("DisplayServer.window_set_current_screen(screen)"),
		"runtime apply path does not move the window to the selected screen")


func _test_resolution_contract(main, errors: Array[String]) -> void:
	var options: Array = main.RESOLUTION_OPTIONS
	_expect(errors, options.size() == 2,
		"monitor selector must not reintroduce removed resolutions (got %d options)" % options.size())
	if options.size() == 2:
		_expect(errors, options[0] == Vector2i(2560, 1440), "first resolution is not 2560x1440")
		_expect(errors, options[1] == Vector2i(1920, 1080), "fallback resolution is not 1920x1080")


func _test_virtual_screen_clamping(main, ui, errors: Array[String]) -> void:
	main.selected_screen_index = 2
	ui.settings_video_pending.clear()
	_expect(errors, int(ui._pending_screen_index(1)) == 0,
		"saved screen 2 did not fall back to screen 0 when only one screen remains")
	_expect(errors, int(ui._pending_screen_index(3)) == 2,
		"valid saved screen 2 was not preserved for a three-screen setup")

	ui.settings_video_pending["screen_index"] = -7
	_expect(errors, int(ui._pending_screen_index(3)) == 0,
		"negative pending screen index was not clamped to 0")
	ui.settings_video_pending["screen_index"] = 99
	_expect(errors, int(ui._pending_screen_index(3)) == 2,
		"oversized pending screen index was not clamped to the last screen")
	_expect(errors, int(ui._pending_screen_index(0)) == 0,
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

