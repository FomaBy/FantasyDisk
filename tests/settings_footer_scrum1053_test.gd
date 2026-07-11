extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1280, 760),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORT_SIZES:
		await _check_viewport(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-1053 Settings footer frame-safe regression test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_settings_menu()
	for _frame_index in range(8):
		await process_frame

	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	var safe_area := main.find_child("SettingsSafeArea", true, false) as Control
	var frame := main.find_child("SettingsFrame", true, false) as Panel
	var content_panel := main.find_child("SettingsContentPanel", true, false) as PanelContainer
	var footer_safe := main.find_child("SettingsBottomActionsSafe", true, false) as Control
	var footer := main.find_child("SettingsBottomActions", true, false) as HBoxContainer
	var game_scroll := main.find_child("SettingsGameScroll", true, false) as ScrollContainer
	if tabs == null or safe_area == null or frame == null or content_panel == null or footer_safe == null or footer == null or game_scroll == null:
		_fail("Missing Settings footer/shell controls at %s." % str(viewport_size))
		return

	var safe_rect := safe_area.get_global_rect()
	var authored_inner := frame.get_meta("gold_shell_inner_rect", Rect2()) as Rect2
	if not authored_inner.has_area():
		_fail("Settings frame lacks its authored inner content rect at %s." % str(viewport_size))
		return
	var expected_reserve := 24 if viewport_size.y <= 760 else 0
	if int(footer_safe.get_meta("settings_footer_bottom_reserve", -1)) != expected_reserve:
		_fail("Wrong Settings footer reserve at %s." % str(viewport_size))
		return

	for tab_index in range(3):
		var tab_button := main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button
		if tab_button == null:
			_fail("Missing Settings tab %d at %s." % [tab_index, str(viewport_size)])
			return
		tab_button.pressed.emit()
		await process_frame
		if tabs.current_tab != tab_index or not footer_safe.visible or not footer.visible:
			_fail("Screen/Sound/Controls footer visibility regressed on tab %d at %s." % [tab_index, str(viewport_size)])
			return
		for button_name in ["SettingsRevertButton", "SettingsApplyButton"]:
			var button := main.find_child(button_name, true, false) as Button
			if button == null or button.focus_mode != Control.FOCUS_ALL or button.pressed.get_connections().is_empty():
				_fail("Settings footer action %s lost focus/signal wiring at %s." % [button_name, str(viewport_size)])
				return
			var button_rect := button.get_global_rect()
			if not safe_rect.grow(1.0).encloses(button_rect):
				_fail("Settings footer action %s escaped texture-safe area at %s: %s / %s." % [button_name, str(viewport_size), str(button_rect), str(safe_rect)])
				return
			if viewport_size.y <= 760 and not authored_inner.grow(1.0).encloses(button_rect):
				_fail("Settings footer action %s entered the compact Atlas ornament at %s: %s / wrapper %s / inner %s." % [button_name, str(viewport_size), str(button_rect), str(footer_safe.get_global_rect()), str(authored_inner)])
				return
		if viewport_size.y <= 760:
			var footer_rect := footer.get_global_rect()
			if footer_rect.intersects(content_panel.get_global_rect(), true):
				_fail("Compact Settings footer overlaps the seamless content zone on tab %d: footer=%s content=%s." % [tab_index, str(footer_rect), str(content_panel.get_global_rect())])
				return
			if footer_rect.end.y > authored_inner.end.y + 1.0:
				_fail("Compact Settings footer crossed the authored bottom boundary on tab %d: %s / inner %s." % [tab_index, str(footer_rect), str(authored_inner)])
				return
			if safe_rect.end.y - footer_rect.end.y < 23.0:
				_fail("Compact Settings footer lost its 24px ornament reserve on tab %d: footer=%s safe=%s." % [tab_index, str(footer_rect), str(safe_rect)])
				return
		if DisplayServer.get_name() != "headless":
			await _save_capture_stable(viewport, viewport_size, "tab%d" % tab_index)

	var game_tab := main.find_child("SettingsTabButton_3", true, false) as Button
	game_tab.pressed.emit()
	for _frame_index in range(3):
		await process_frame
	if tabs.current_tab != 3 or footer_safe.visible or footer.visible:
		_fail("Game tab must hide the complete Screen footer wrapper at %s." % str(viewport_size))
		return
	var expected_compact_game_h := maxf(160.0, roundf(float(viewport_size.y) * 0.6875 - 253.0))
	if viewport_size.y <= 760 and game_scroll.get_global_rect().size.distance_to(Vector2(892.0, expected_compact_game_h)) > 1.0:
		_fail("SCRUM-1053 changed the accepted compact Game scroll viewport: %s." % str(game_scroll.get_global_rect()))
		return

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_fail("SCRUM-1053 viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _save_capture_stable(viewport: SubViewport, viewport_size: Vector2i, suffix: String) -> void:
	for _frame_index in range(10):
		await process_frame
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum1053")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/settings_%s_%dx%d.png" % [qa_dir, suffix, viewport_size.x, viewport_size.y])


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/":
		push_error("SCRUM-1053 test requires --user-data-dir=<unique scratch root>.")
		return false
	if not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1053 scratch mismatch: user://=%s requested=%s." % [actual, requested])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
