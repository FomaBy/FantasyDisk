extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const UI_BUTTON_FAMILY := preload("res://scripts/ui/ui_button_family.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const EXPECTED_FONTS := [21, 22, 23, 23]
const LABELS := ["Экран", "Звук", "Управление", "Игра"]
const TEXT_RESERVE := 2.0

var _errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_index in range(VIEWPORTS.size()):
		await _check_viewport(VIEWPORTS[viewport_index], EXPECTED_FONTS[viewport_index])
	await _capture_teardown.release_windowed_audio(self)
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1060 Settings tab font/content-zone contract test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i, expected_font: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_settings_menu()
	await _settle()

	var context := "%dx%d" % [viewport_size.x, viewport_size.y]
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	var switcher := main.find_child("SettingsTabSwitcher", true, false) as Control
	var back := main.find_child("SettingsBackButton", true, false) as Button
	if tabs == null or switcher == null or back == null:
		_errors.append("%s: missing Settings font-contract shell." % context)
		await _release(viewport, context)
		return

	var back_font := back.get_theme_font_size("font_size")
	if back_font != expected_font:
		_errors.append("%s: Back effective font %d != target %d." % [context, back_font, expected_font])
	var compact := viewport_size.y <= 760
	var expected_size := Vector2(260.0, 72.0 if compact else (88.0 if viewport_size.y <= 1080 else 104.0))
	var expected_columns := 2 if compact else 4
	var expected_rows := 2 if compact else 1
	if int(switcher.get_meta("settings_tab_columns", -1)) != expected_columns or int(switcher.get_meta("settings_tab_rows", -1)) != expected_rows:
		_errors.append("%s: responsive Settings grid metadata regressed." % context)

	var rects: Array[Rect2] = []
	var buttons: Array[Button] = []
	for tab_index in range(4):
		var button := main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button
		if button == null:
			_errors.append("%s: missing SettingsTabButton_%d." % [context, tab_index])
			continue
		buttons.append(button)
		var rect := button.get_global_rect()
		rects.append(rect)
		if button.text != LABELS[tab_index]:
			_errors.append("%s: tab %d label changed to '%s'." % [context, tab_index, button.text])
		if button.icon != null:
			_errors.append("%s: tab %d retained an icon, so Back-font fit is not guaranteed." % [context, tab_index])
		if button.autowrap_mode != TextServer.AUTOWRAP_OFF or button.clip_text or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			_errors.append("%s: tab %d permits wrap/clip/ellipsis." % [context, tab_index])
		if button.custom_minimum_size.distance_to(expected_size) > 0.5 or rect.size.distance_to(expected_size) > 0.5:
			_errors.append("%s: tab %d plate is %s / min %s, expected %s." % [context, tab_index, str(rect.size), str(button.custom_minimum_size), str(expected_size)])
		var font_size := button.get_theme_font_size("font_size")
		if abs(font_size - back_font) > 1 or font_size != expected_font:
			_errors.append("%s: tab %d effective font %d != Back %d / target %d." % [context, tab_index, font_size, back_font, expected_font])
		if int(button.get_meta("settings_fixed_font_contract", -1)) != expected_font:
			_errors.append("%s: tab %d lost fixed font metadata." % [context, tab_index])
		if button.focus_mode != Control.FOCUS_ALL:
			_errors.append("%s: tab %d is not keyboard/gamepad focusable." % [context, tab_index])
		_assert_state_geometry_and_glyph_bounds(button, context)

	for rect_index in range(rects.size()):
		for other_index in range(rect_index + 1, rects.size()):
			if rects[rect_index].intersects(rects[other_index], true):
				_errors.append("%s: tab plates %d/%d overlap." % [context, rect_index, other_index])
	if rects.size() == 4:
		if compact:
			if absf(rects[0].position.y - rects[1].position.y) > 0.5 or absf(rects[2].position.y - rects[3].position.y) > 0.5 or absf(rects[2].position.y - rects[0].end.y - 12.0) > 0.5:
				_errors.append("%s: exact 2x2 / 12px row-gap geometry regressed." % context)
		else:
			for rect in rects:
				if absf(rect.position.y - rects[0].position.y) > 0.5:
					_errors.append("%s: wide tabs no longer form one row." % context)

	# Mouse/pressed semantics plus active tint: every emitted button press must
	# select exactly its page without changing any plate/text geometry.
	for tab_index in range(buttons.size()):
		var button := buttons[tab_index]
		var before_rect := Rect2(button.position, button.size)
		var before_font := button.get_theme_font_size("font_size")
		button.pressed.emit()
		await process_frame
		if tabs.current_tab != tab_index:
			_errors.append("%s: tab %d press did not select its page." % [context, tab_index])
		if Rect2(button.position, button.size) != before_rect or button.get_theme_font_size("font_size") != before_font:
			_errors.append("%s: selected state changes tab %d geometry/font." % [context, tab_index])
		for state_index in range(buttons.size()):
			var expected_tint := Color(1.0, 0.94, 0.74) if state_index == tab_index else Color(0.74, 0.76, 0.84, 0.92)
			if not buttons[state_index].modulate.is_equal_approx(expected_tint):
				_errors.append("%s: tab %d active/idle tint regressed after selecting %d." % [context, state_index, tab_index])

	# Existing shoulder route must still include all four pages and wrap.
	for expected_tab in [0, 1, 2, 3, 0]:
		if expected_tab == 0 and tabs.current_tab == 3:
			pass
		elif expected_tab == 0:
			tabs.current_tab = 3
		if not main.ui._cycle_settings_tab(1) or tabs.current_tab != expected_tab:
			_errors.append("%s: LB/RB cycle/wrap expected %d, got %d." % [context, expected_tab, tabs.current_tab])
			break

	if DisplayServer.get_name() != "headless":
		await _save_capture(viewport, viewport_size)
	await _release(viewport, context)


func _assert_state_geometry_and_glyph_bounds(button: Button, context: String) -> void:
	var font: Font = button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	if font == null:
		_errors.append("%s: %s has no font." % [context, button.name])
		return
	var glyph_size := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	var baseline_margins := Vector4.ZERO
	for state in UI_BUTTON_FAMILY.STATES:
		var style := button.get_theme_stylebox(state)
		if style == null:
			_errors.append("%s: %s misses %s style." % [context, button.name, state])
			continue
		var margins := Vector4(
			style.get_content_margin(SIDE_LEFT),
			style.get_content_margin(SIDE_TOP),
			style.get_content_margin(SIDE_RIGHT),
			style.get_content_margin(SIDE_BOTTOM))
		if state == "normal":
			baseline_margins = margins
		elif not margins.is_equal_approx(baseline_margins):
			_errors.append("%s: %s %s margins %s != normal %s." % [context, button.name, state, str(margins), str(baseline_margins)])
		if absf(margins.x - 48.0) > 0.5 or absf(margins.z - 48.0) > 0.5:
			_errors.append("%s: %s %s lost the x=48..212 flat field." % [context, button.name, state])
		var content_rect := Rect2(
			Vector2(margins.x, margins.y),
			Vector2(button.size.x - margins.x - margins.z, button.size.y - margins.y - margins.w))
		var glyph_rect := Rect2(content_rect.get_center() - glyph_size * 0.5, glyph_size)
		if glyph_size.x + TEXT_RESERVE > content_rect.size.x or glyph_size.y + TEXT_RESERVE > content_rect.size.y:
			_errors.append("%s: %s '%s' needs %s inside %s %s content %s." % [context, button.name, button.text, str(glyph_size), state, button.name, str(content_rect)])
		if not content_rect.grow(-TEXT_RESERVE * 0.5).encloses(glyph_rect):
			_errors.append("%s: %s rendered glyph bounds %s touch/escape %s ornament-safe field %s." % [context, button.name, str(glyph_rect), state, str(content_rect)])


func _save_capture(viewport: SubViewport, viewport_size: Vector2i) -> void:
	await _settle()
	var path := ProjectSettings.globalize_path("res://build/qa/scrum1060/settings_tabs_%dx%d.png" % [viewport_size.x, viewport_size.y])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(path)


func _release(viewport: SubViewport, context: String) -> void:
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		_errors.append("%s: teardown failed: %s." % [context, "; ".join(teardown_errors)])


func _settle() -> void:
	for _frame in range(8):
		await process_frame


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/":
		push_error("SCRUM-1060 test requires --user-data-dir=<unique scratch root>.")
		return false
	if not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1060 scratch mismatch: user://=%s requested=%s." % [actual, requested])
		return false
	return true
