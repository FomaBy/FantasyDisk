extends "res://tests/runtime_smoke_test.gd"

# Focused SCRUM-1059 gate: exact five-viewport geometry, authored inner-zone
# safety, semantic states, canonical order, live resize and deterministic focus.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const GRATITUDE_ICON_PATH := "res://assets/sprites/ui/icons/credits/ui_icon_gratitude.png"
const TARGETS := [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]
const BUTTON_NAMES := [
	"MainMenuStartButton", "MainMenuSettingsButton", "MainMenuSkillTreeButton",
	"MainMenuPatchNotesButton", "MainMenuCodexButton", "MainMenuExitButton",
]
const BUTTON_LABEL_PREFIXES := [
	"Начать новую игру", "Настройки", "Атлас героев", "Что нового", "Кодекс", "Выйти из игры",
]

var _errors := PackedStringArray()


func _initialize() -> void:
	for viewport_size in TARGETS:
		await _validate_fresh(viewport_size)
	await _validate_live_resize()
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1059 Main Menu single-column test passed at five viewports and live resize.")
	quit(0)


func _validate_fresh(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle_frames()
	main.ui._show_main_menu()
	await _settle_frames()
	_assert_main_menu(main, viewport_size, "fresh")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _validate_live_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = TARGETS[TARGETS.size() - 1]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle_frames()
	main.ui._show_main_menu()
	await _settle_frames()
	for index in range(TARGETS.size() - 1, -1, -1):
		var viewport_size: Vector2i = TARGETS[index]
		viewport.size = viewport_size
		await _settle_frames()
		_assert_main_menu(main, viewport_size, "live resize")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_main_menu(main: Node, viewport_size: Vector2i, phase: String) -> void:
	var context := "%s %s" % [phase, str(viewport_size)]
	var screen := main.find_child("MainMenuScreen", true, false) as Control
	var logo := main.find_child("MainMenuTitleLabel", true, false) as TextureRect
	var actions := main.find_child("MainMenuActions", true, false) as GridContainer
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	var version := main.find_child("MainMenuVersionLabel", true, false) as Label
	if screen == null or logo == null or actions == null or credits == null or version == null:
		_errors.append("%s: incomplete Main Menu nodes." % context)
		return
	var expected := _expected(viewport_size)
	var inner: Rect2 = expected["inner"]
	_assert_rect(logo.get_global_rect(), expected["logo"], "%s logo" % context)
	_assert_rect(actions.get_global_rect(), expected["actions"], "%s actions" % context)
	_assert_rect(credits.get_global_rect(), expected["credits"], "%s gratitude" % context)
	_assert_rect(version.get_global_rect(), expected["version"], "%s version" % context)
	if actions.columns != 1 or actions.get_child_count() != 6:
		_errors.append("%s: MainMenuActions must be columns=1 with six children." % context)
		return
	if not _near_rect(screen.get_meta("gold_shell_inner_rect", Rect2()) as Rect2, inner):
		_errors.append("%s: published authored inner rect drifted." % context)
	for control in [logo, actions, credits, version]:
		if not inner.grow(1.0).encloses((control as Control).get_global_rect()):
			_errors.append("%s: %s escapes authored inner %s." % [context, str((control as Control).name), str(inner)])
	for first_index in range(4):
		var first := [logo, actions, credits, version][first_index] as Control
		for second_index in range(first_index + 1, 4):
			var second := [logo, actions, credits, version][second_index] as Control
			if first.get_global_rect().intersects(second.get_global_rect()):
				_errors.append("%s: %s overlaps %s." % [context, str(first.name), str(second.name)])
	var buttons: Array[Button] = []
	for index in range(BUTTON_NAMES.size()):
		var button := actions.get_child(index) as Button
		buttons.append(button)
		if button == null or button.name != BUTTON_NAMES[index] or not button.text.begins_with(BUTTON_LABEL_PREFIXES[index]):
			_errors.append("%s: button %d order/label drifted." % [context, index])
			continue
		if not inner.grow(1.0).encloses(button.get_global_rect()):
			_errors.append("%s: %s escapes authored inner." % [context, str(button.name)])
		if absf(button.size.x - float(expected["button_width"])) > 1.1 or absf(button.size.y - float(expected["button_height"])) > 1.1:
			_errors.append("%s: %s size %s drifted from %.0fx%.0f." % [context, str(button.name), str(button.size), float(expected["button_width"]), float(expected["button_height"])])
		if str(button.get_meta(UIButtonFamily.META_FAMILY, "")) != "text/main_menu_380x104":
			_errors.append("%s: %s lost the registered main-menu family." % [context, str(button.name)])
		_assert_stable_states(button, context)
		if button.pressed.get_connections().size() < 2:
			_errors.append("%s: %s must retain callback plus UI SFX connection." % [context, str(button.name)])
		if index > 0 and buttons[index - 1].get_global_rect().intersects(button.get_global_rect()):
			_errors.append("%s: action rows %d/%d overlap." % [context, index - 1, index])
	_assert_focus_graph(buttons, credits, context)
	if credits.text != "" or credits.icon == null or credits.icon.resource_path != GRATITUDE_ICON_PATH:
		_errors.append("%s: gratitude must remain icon-only with the accepted asset." % context)
	if credits.tooltip_text != "Благодарности" or str(credits.get_meta("accessibility_name", "")) != "Благодарности":
		_errors.append("%s: gratitude tooltip/accessibility drifted." % context)
	if screen.find_children("*", "ScrollContainer", true, false).size() > 0:
		_errors.append("%s: Main Menu must not introduce a scrollbar." % context)


func _assert_focus_graph(buttons: Array[Button], credits: Button, context: String) -> void:
	if buttons.size() != 6:
		return
	for index in range(buttons.size()):
		var previous := buttons[(index - 1 + buttons.size()) % buttons.size()]
		var following := buttons[(index + 1) % buttons.size()]
		if buttons[index].focus_neighbor_top != previous.get_path() or buttons[index].focus_neighbor_bottom != following.get_path():
			_errors.append("%s: Up/Down ring drifted at %s." % [context, str(buttons[index].name)])
		if buttons[index].focus_neighbor_right != credits.get_path():
			_errors.append("%s: gratitude is unreachable from %s via Right." % [context, str(buttons[index].name)])
	if credits.focus_neighbor_left != buttons[0].get_path() or credits.focus_neighbor_bottom != buttons[0].get_path() or credits.focus_neighbor_top != buttons[5].get_path():
		_errors.append("%s: gratitude return graph is not deterministic." % context)


func _assert_stable_states(button: Button, context: String) -> void:
	var normal := button.get_theme_stylebox("normal")
	if normal == null:
		_errors.append("%s: %s has no normal style." % [context, str(button.name)])
		return
	var baseline := Vector4(normal.content_margin_left, normal.content_margin_top, normal.content_margin_right, normal.content_margin_bottom)
	for state in ["hover", "focus", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style == null:
			_errors.append("%s: %s has no %s style." % [context, str(button.name), state])
			continue
		var margins := Vector4(style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom)
		if margins != baseline:
			_errors.append("%s: %s changes content margins in %s." % [context, str(button.name), state])


func _expected(viewport_size: Vector2i) -> Dictionary:
	match viewport_size:
		Vector2i(1152, 648):
			return {"inner": Rect2(144, 125, 864, 398), "logo": Rect2(144, 125, 160, 60), "actions": Rect2(144, 189, 320, 334), "credits": Rect2(944, 125, 64, 64), "version": Rect2(320, 146, 112, 18), "button_width": 320.0, "button_height": 54.0}
		Vector2i(1280, 720):
			return {"inner": Rect2(157, 137, 966, 446), "logo": Rect2(157, 137, 192, 72), "actions": Rect2(157, 215, 340, 361), "credits": Rect2(1059, 137, 64, 64), "version": Rect2(365, 164, 112, 18), "button_width": 340.0, "button_height": 56.0}
		Vector2i(1600, 900):
			return {"inner": Rect2(191, 165, 1218, 570), "logo": Rect2(191, 165, 267, 100), "actions": Rect2(191, 273, 360, 424), "credits": Rect2(1337, 165, 72, 72), "version": Rect2(474, 205, 126, 20), "button_width": 360.0, "button_height": 64.0}
		Vector2i(1920, 1080):
			return {"inner": Rect2(224, 193, 1472, 694), "logo": Rect2(224, 193, 331, 124), "actions": Rect2(224, 329, 380, 506), "credits": Rect2(1624, 193, 72, 72), "version": Rect2(571, 245, 126, 20), "button_width": 380.0, "button_height": 76.0}
		_:
			return {"inner": Rect2(299, 257, 1962, 926), "logo": Rect2(299, 257, 480, 180), "actions": Rect2(299, 457, 380, 646), "credits": Rect2(2173, 257, 88, 88), "version": Rect2(795, 335, 124, 24), "button_width": 380.0, "button_height": 96.0}


func _assert_rect(actual: Rect2, expected: Rect2, context: String) -> void:
	if not _near_rect(actual, expected):
		_errors.append("%s rect %s != %s." % [context, str(actual), str(expected)])


func _near_rect(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= 1.1 and actual.size.distance_to(expected.size) <= 1.1


func _settle_frames() -> void:
	for _frame in range(6):
		await process_frame
