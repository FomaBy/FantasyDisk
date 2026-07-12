extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const TARGETS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const BUTTON_SIZE := Vector2(240.0, 72.0)
const BUTTON_FAMILY := "text/continue_240x72"
const TEXT_RESERVE := 4.0

var _errors := PackedStringArray()


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_target(viewport_size)
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1055 End Run confirmation labels fit equal 240x72 buttons at 648p/720p/1080p/2K.")
	quit(0)


func _validate_target(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()

	main.ui._show_pause_menu(true)
	await _settle()
	var pause_end := main.find_child("PauseEndRunButton", true, false) as Button
	if pause_end == null:
		_errors.append("%s: PauseEndRunButton is missing." % str(viewport_size))
	else:
		pause_end.pressed.emit()
		await _settle()
		_assert_dialog(main, viewport_size)

	main.queue_free()
	viewport.queue_free()
	paused = false
	await process_frame


func _assert_dialog(main: Node, viewport_size: Vector2i) -> void:
	var context := "%dx%d" % [viewport_size.x, viewport_size.y]
	var panel := main.find_child("EndRunConfirmationPanel", true, false) as PanelContainer
	var accept := main.find_child("EndRunConfirmAcceptButton", true, false) as Button
	var cancel := main.find_child("EndRunConfirmCancelButton", true, false) as Button
	if panel == null or accept == null or cancel == null:
		_errors.append("%s: incomplete End Run confirmation hierarchy." % context)
		return
	if main.get_viewport().gui_get_focus_owner() != cancel:
		_errors.append("%s: safe Cancel must keep initial focus." % context)

	var panel_style := panel.get_theme_stylebox("panel")
	var panel_rect := panel.get_global_rect()
	if panel_rect.size.distance_to(Vector2(600.0, 340.0)) > 0.6:
		_errors.append("%s: modal panel must remain 600x340, got %s." % [context, str(panel_rect)])
	var inner := Rect2(
		panel_rect.position + Vector2(panel_style.get_content_margin(SIDE_LEFT), panel_style.get_content_margin(SIDE_TOP)),
		panel_rect.size - Vector2(
			panel_style.get_content_margin(SIDE_LEFT) + panel_style.get_content_margin(SIDE_RIGHT),
			panel_style.get_content_margin(SIDE_TOP) + panel_style.get_content_margin(SIDE_BOTTOM)
		)
	)
	var rects: Array[Rect2] = []
	for button in [accept, cancel]:
		var typed_button := button as Button
		var rect: Rect2 = typed_button.get_global_rect()
		rects.append(rect)
		if typed_button.custom_minimum_size != BUTTON_SIZE or rect.size.distance_to(BUTTON_SIZE) > 0.6:
			_errors.append("%s: %s must be an exact 240x72 slot, got min=%s rect=%s." % [context, typed_button.name, str(typed_button.custom_minimum_size), str(rect)])
		if str(typed_button.get_meta(UIButtonFamily.META_FAMILY, "")) != BUTTON_FAMILY:
			_errors.append("%s: %s family must be %s." % [context, typed_button.name, BUTTON_FAMILY])
		if not inner.grow(0.6).encloses(rect):
			_errors.append("%s: %s escapes the empty panel content zone %s." % [context, typed_button.name, str(inner)])
		_assert_button_text_fit(typed_button, context)
		_assert_family_states(typed_button, context)
	if rects.size() == 2 and rects[0].intersects(rects[1]):
		_errors.append("%s: End Run confirmation buttons overlap." % context)
	elif rects.size() == 2:
		if absf(rects[0].position.y - rects[1].position.y) > 0.6:
			_errors.append("%s: buttons must share the same y coordinate." % context)
		var gap: float = rects[1].position.x - rects[0].end.x
		if absf(gap - 18.0) > 0.6:
			_errors.append("%s: button gap %.1f != 18px." % [context, gap])
		var pair_center_x: float = (rects[0].get_center().x + rects[1].get_center().x) * 0.5
		if absf(pair_center_x - inner.get_center().x) > 0.6:
			_errors.append("%s: button pair center %.1f != inner center %.1f." % [context, pair_center_x, inner.get_center().x])
	if accept.text != "Завершить" or cancel.text != "Отмена":
		_errors.append("%s: canonical Russian labels changed (%s / %s)." % [context, accept.text, cancel.text])
	if accept.get_theme_font_size("font_size") != cancel.get_theme_font_size("font_size"):
		_errors.append("%s: accept/cancel font sizes must stay symmetric." % context)


func _assert_button_text_fit(button: Button, context: String) -> void:
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
	for state in UIButtonFamily.STATES:
		var style: StyleBox = button.get_theme_stylebox(state)
		var content_width: float = button.size.x - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
		if text_width + TEXT_RESERVE > content_width + 0.5:
			_errors.append("%s: %s %s text '%s' needs %.1fpx + %.1f reserve, content lane is %.1fpx." % [context, button.name, state, button.text, text_width, TEXT_RESERVE, content_width])


func _assert_family_states(button: Button, context: String) -> void:
	for state in UIButtonFamily.STATES:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		var suffix := "ui_btn_text_unique_continue_240x72_%s.png" % state
		if style == null or style.texture == null or not style.texture.resource_path.ends_with(suffix):
			_errors.append("%s: %s missing native %s state." % [context, button.name, state])


func _settle() -> void:
	for _frame in range(8):
		await process_frame
