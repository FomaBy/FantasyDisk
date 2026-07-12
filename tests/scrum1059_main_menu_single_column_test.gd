extends "res://tests/runtime_smoke_test.gd"

# Focused SCRUM-1059 gate: exact five-viewport geometry, authored inner-zone
# safety, semantic states, canonical order, live resize and deterministic focus.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const GRATITUDE_ICON_PATH := "res://assets/sprites/ui/icons/credits/ui_icon_gratitude.png"
const TARGETS := [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2048, 1152), Vector2i(2560, 1440),
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
	print("SCRUM-1059/1093 Main Menu test passed at six viewports and live resize.")
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
	var glow := main.find_child("MainMenuGratitudeGlow", true, false) as TextureRect
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	var version := main.find_child("MainMenuVersionLabel", true, false) as Label
	if screen == null or logo == null or actions == null or glow == null or credits == null or version == null:
		_errors.append("%s: incomplete Main Menu nodes." % context)
		return
	var expected := _expected(viewport_size)
	var expected_utility := _expected_utility(viewport_size, version)
	var inner: Rect2 = expected["inner"]
	_assert_rect(logo.get_global_rect(), expected["logo"], "%s logo" % context)
	_assert_rect(actions.get_global_rect(), expected["actions"], "%s actions" % context)
	_assert_rect(glow.get_global_rect(), expected_utility["glow"], "%s gratitude glow" % context)
	_assert_rect(credits.get_global_rect(), expected_utility["credits"], "%s gratitude" % context)
	_assert_rect(version.get_global_rect(), expected_utility["version"], "%s version" % context)
	if actions.columns != 1 or actions.get_child_count() != 6:
		_errors.append("%s: MainMenuActions must be columns=1 with six children." % context)
		return
	if not _near_rect(screen.get_meta("gold_shell_inner_rect", Rect2()) as Rect2, inner):
		_errors.append("%s: published authored inner rect drifted." % context)
	for control in [logo, actions]:
		if not inner.grow(1.0).encloses((control as Control).get_global_rect()):
			_errors.append("%s: %s escapes authored inner %s." % [context, str((control as Control).name), str(inner)])
	var utility_safe: Rect2 = expected_utility["safe"]
	for control in [glow, credits, version]:
		if not utility_safe.grow(1.0).encloses((control as Control).get_global_rect()):
			_errors.append("%s: %s escapes compact frame-safe utility zone %s." % [context, str((control as Control).name), str(utility_safe)])
	for first_index in range(4):
		var first := [logo, actions, glow, version][first_index] as Control
		for second_index in range(first_index + 1, 4):
			var second := [logo, actions, glow, version][second_index] as Control
			if first.get_global_rect().intersects(second.get_global_rect()):
				_errors.append("%s: %s overlaps %s." % [context, str(first.name), str(second.name)])
	if not glow.get_global_rect().grow(1.0).encloses(credits.get_global_rect()):
		_errors.append("%s: gratitude icon escapes its bounded glow." % context)
	if glow.mouse_filter != Control.MOUSE_FILTER_IGNORE or not (glow.texture is GradientTexture2D):
		_errors.append("%s: gratitude glow must be procedural and mouse-ignoring." % context)
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
	var expected_version := "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if version.text != expected_version:
		_errors.append("%s: version '%s' does not match dynamic project version '%s'." % [context, version.text, expected_version])
	if version.horizontal_alignment != HORIZONTAL_ALIGNMENT_RIGHT or version.vertical_alignment != VERTICAL_ALIGNMENT_BOTTOM:
		_errors.append("%s: version must remain bottom-right aligned." % context)
	if version.get_theme_font_size("font_size") != int(expected["version_font_size"]):
		_errors.append("%s: version font tier drifted." % context)
	if absf(float(version.get_meta("scrum1093_measured_text_width", -1.0)) + 6.0 - version.size.x) > 1.1:
		_errors.append("%s: version rect is not compact to the measured glyph width." % context)
	if absf(version.get_global_rect().position.x - glow.get_global_rect().end.x - 4.0) > 1.1:
		_errors.append("%s: gratitude glow is not immediately left of the compact version rect." % context)
	var glyph_start := version.get_global_rect().end.x - float(version.get_meta("scrum1093_measured_text_width", -1.0))
	var visible_icon_to_text_gap := glyph_start - credits.get_global_rect().end.x
	if visible_icon_to_text_gap < 0.0 or visible_icon_to_text_gap > 20.0:
		_errors.append("%s: visible icon-to-version gap %.1f is outside the compact 0..20 px contract." % [context, visible_icon_to_text_gap])
	if version.get_global_rect().end.distance_to((expected_utility["safe"] as Rect2).end) > 1.1:
		_errors.append("%s: version must end exactly 8 px inside the authored frame-safe boundary." % context)
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
		if buttons[index].focus_neighbor_left != buttons[index].get_path() or buttons[index].focus_neighbor_right != credits.get_path():
			_errors.append("%s: gratitude is not reachable from %s via Right." % [context, str(buttons[index].name)])
	if credits.focus_neighbor_left != buttons[5].get_path() or credits.focus_neighbor_right != credits.get_path() or credits.focus_neighbor_bottom != buttons[0].get_path() or credits.focus_neighbor_top != buttons[5].get_path():
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
			return {"inner": Rect2(144, 125, 864, 398), "logo": Rect2(144, 125, 160, 60), "actions": Rect2(144, 189, 320, 334), "glow": Rect2(784, 439, 84, 84), "credits": Rect2(790, 445, 72, 72), "version": Rect2(880, 501, 128, 22), "version_font_size": 14, "button_width": 320.0, "button_height": 54.0}
		Vector2i(1280, 720):
			return {"inner": Rect2(157, 137, 966, 446), "logo": Rect2(157, 137, 192, 72), "actions": Rect2(157, 215, 340, 361), "glow": Rect2(891, 499, 84, 84), "credits": Rect2(897, 505, 72, 72), "version": Rect2(987, 559, 136, 24), "version_font_size": 14, "button_width": 340.0, "button_height": 56.0}
		Vector2i(1600, 900):
			return {"inner": Rect2(191, 165, 1218, 570), "logo": Rect2(191, 165, 267, 100), "actions": Rect2(191, 273, 360, 424), "glow": Rect2(1153, 639, 96, 96), "credits": Rect2(1161, 647, 80, 80), "version": Rect2(1265, 709, 144, 26), "version_font_size": 15, "button_width": 360.0, "button_height": 64.0}
		Vector2i(1920, 1080):
			return {"inner": Rect2(224, 193, 1472, 694), "logo": Rect2(224, 193, 331, 124), "actions": Rect2(224, 329, 380, 506), "version_font_size": 16, "button_width": 380.0, "button_height": 76.0}
		Vector2i(2048, 1152):
			return {"inner": Rect2(237, 204, 1574, 744), "logo": Rect2(237, 204, 331, 124), "actions": Rect2(237, 340, 380, 506), "version_font_size": 16, "button_width": 380.0, "button_height": 76.0}
		_:
			return {"inner": Rect2(299, 257, 1962, 926), "logo": Rect2(299, 257, 480, 180), "actions": Rect2(299, 457, 380, 646), "version_font_size": 18, "button_width": 380.0, "button_height": 96.0}


func _expected_utility(viewport_size: Vector2i, version: Label) -> Dictionary:
	var margins := Vector2(
		roundf(160.0 * float(viewport_size.x) / 1536.0),
		roundf(160.0 * float(viewport_size.y) / 1024.0)
	)
	var safe := Rect2(margins + Vector2.ONE * 8.0, Vector2(viewport_size) - margins * 2.0 - Vector2.ONE * 16.0)
	var anchor := safe.end
	var glow_side := 116.0
	var credits_side := 96.0
	var version_height := 32.0
	if viewport_size.y < 700:
		glow_side = 84.0
		credits_side = 72.0
		version_height = 22.0
	elif viewport_size.y < 800:
		glow_side = 84.0
		credits_side = 72.0
		version_height = 24.0
	elif viewport_size.y < 1000:
		glow_side = 96.0
		credits_side = 80.0
		version_height = 26.0
	elif viewport_size.y < 1200:
		glow_side = 96.0
		credits_side = 80.0
		version_height = 28.0
	var font: Font = version.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var measured_width := ceilf(font.get_string_size(
		version.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		version.get_theme_font_size("font_size")
	).x)
	var version_size := Vector2(measured_width + 6.0, version_height)
	var version_rect := Rect2(anchor - version_size, version_size)
	var glow_rect := Rect2(Vector2(version_rect.position.x - 4.0 - glow_side, anchor.y - glow_side), Vector2.ONE * glow_side)
	var inset := (glow_side - credits_side) * 0.5
	return {
		"safe": safe,
		"version": version_rect,
		"glow": glow_rect,
		"credits": Rect2(glow_rect.position + Vector2.ONE * inset, Vector2.ONE * credits_side),
	}


func _assert_rect(actual: Rect2, expected: Rect2, context: String) -> void:
	if not _near_rect(actual, expected):
		_errors.append("%s rect %s != %s." % [context, str(actual), str(expected)])


func _near_rect(actual: Rect2, expected: Rect2) -> bool:
	return actual.position.distance_to(expected.position) <= 1.1 and actual.size.distance_to(expected.size) <= 1.1


func _settle_frames() -> void:
	for _frame in range(6):
		await process_frame
