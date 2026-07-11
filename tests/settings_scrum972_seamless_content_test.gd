extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
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
	print("SCRUM-972 Settings seamless-content test passed.")
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

	var panel := main.find_child("SettingsContentPanel", true, false) as PanelContainer
	var content_safe := main.find_child("SettingsContentSafe", true, false) as MarginContainer
	var frame := main.find_child("SettingsFrame", true, false) as Panel
	var safe_area := main.find_child("SettingsSafeArea", true, false) as MarginContainer
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	var switcher := main.find_child("SettingsTabSwitcher", true, false) as Control
	var footer := main.find_child("SettingsBottomActions", true, false) as Control
	if panel == null or content_safe == null or frame == null or safe_area == null or tabs == null or switcher == null or footer == null:
		_fail("Missing Settings shell controls at %s." % str(viewport_size))
		return

	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		_fail("SettingsContentPanel must retain a margin-preserving StyleBoxFlat at %s." % str(viewport_size))
		return
	if style.bg_color.a > 0.01:
		_fail("SettingsContentPanel still paints a visible inset (alpha %.3f) at %s." % [style.bg_color.a, str(viewport_size)])
		return
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if style.get_border_width(side) != 0:
			_fail("SettingsContentPanel still paints border side %d at %s." % [side, str(viewport_size)])
			return
	var smallest_margin := minf(
		minf(style.content_margin_left, style.content_margin_right),
		minf(style.content_margin_top, style.content_margin_bottom)
	)
	if smallest_margin <= 0.0:
		_fail("Transparent SettingsContentPanel lost its protective content margins at %s." % str(viewport_size))
		return
	if not panel.clip_contents:
		_fail("SettingsContentPanel lost clip ownership at %s." % str(viewport_size))
		return
	var tabs_style := tabs.get_theme_stylebox("panel") as StyleBoxFlat
	if tabs_style == null or tabs_style.bg_color.a > 0.01:
		_fail("SettingsTabs still paints a visible inherited panel at %s." % str(viewport_size))
		return
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		if tabs_style.get_border_width(side) != 0:
			_fail("SettingsTabs still paints border side %d at %s." % [side, str(viewport_size)])
			return

	var panel_rect := panel.get_global_rect()
	var safe_rect := safe_area.get_global_rect()
	var content_rect := content_safe.get_global_rect()
	if not safe_rect.grow(1.0).encloses(panel_rect) or not panel_rect.grow(1.0).encloses(content_rect):
		_fail("Settings content escaped the outer safe/frame geometry at %s: safe=%s panel=%s content=%s." % [str(viewport_size), str(safe_rect), str(panel_rect), str(content_rect)])
		return
	if switcher.get_global_rect().intersects(panel_rect, true) or footer.get_global_rect().intersects(panel_rect, true):
		_fail("Settings tabs/footer overlap the seamless content zone at %s." % str(viewport_size))
		return

	if tabs.get_child_count() != 3 or main.find_child("SettingsTabButton_3", true, false) != null:
		_fail("Settings must preserve exactly three tabs at %s." % str(viewport_size))
		return
	for tab_index in range(3):
		var tab_button := main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button
		if tab_button == null or tab_button.focus_mode != Control.FOCUS_ALL:
			_fail("Settings tab %d is missing or not focusable at %s." % [tab_index, str(viewport_size)])
			return
		tab_button.pressed.emit()
		await process_frame
		if tabs.current_tab != tab_index:
			_fail("Settings tab %d no longer switches the native TabContainer at %s." % [tab_index, str(viewport_size)])
			return
		if DisplayServer.get_name() != "headless":
			_save_capture(viewport, viewport_size, tab_index)

	for action_name in ["SettingsBackButton", "SettingsRevertButton", "SettingsApplyButton"]:
		var action := main.find_child(action_name, true, false) as Button
		if action == null or action.focus_mode != Control.FOCUS_ALL or action.pressed.get_connections().is_empty():
			_fail("Settings action %s lost its focus/signal contract at %s." % [action_name, str(viewport_size)])
			return
		if not safe_rect.grow(1.0).encloses(action.get_global_rect()):
			_fail("Settings action %s escaped the frame-safe area at %s." % [action_name, str(viewport_size)])
			return

	var frame_style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if frame_style == null or frame_style.draw_center:
		_fail("Settings outer frame stopped being hollow at %s." % str(viewport_size))
		return

	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_fail("SCRUM-972 viewport teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])


func _save_capture(viewport: SubViewport, viewport_size: Vector2i, tab_index: int) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum972")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/settings_tab%d_%dx%d.png" % [qa_dir, tab_index, viewport_size.x, viewport_size.y])


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/":
		push_error("SCRUM-972 test refuses the default user://; pass -- --user-data-dir=<unique scratch root> and isolate HOME/XDG_DATA_HOME.")
		return false
	if not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-972 scratch mismatch: user:// resolves to %s outside requested %s." % [actual, requested])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
