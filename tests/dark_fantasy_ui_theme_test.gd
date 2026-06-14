extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")
const DF_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"
const RED_GOLD_DIR := "res://assets/sprites/ui/frames/red_gold/"
const ORNATE_DIR := "res://assets/sprites/ui/frames/ornate/"
const UNIFIED_DIR := "res://assets/sprites/ui/frames/unified/"
const UNIFIED_METADATA_PATH := "res://docs/design/references/unified_master_frame/unified_master_frame_metadata.json"


func _initialize() -> void:
	var errors: Array[String] = []
	var unified_texture_margin := _expected_unified_texture_margin(errors)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	var start_button := main.find_child("MainMenuStartButton", true, false) as Button
	var settings_button := main.find_child("MainMenuSettingsButton", true, false) as Button
	var exit_button := main.find_child("MainMenuExitButton", true, false) as Button
	_expect_button_state_paths(start_button, "main_menu", errors)
	_expect_button_state_paths(settings_button, "main_menu", errors)
	_expect_button_state_paths(exit_button, "main_menu", errors)

	var ui = main.get("ui")
	if ui == null:
		errors.append("Main.ui is missing.")
	else:
		_expect_unified_style(ui.call("_panel_style"), "panel", errors, unified_texture_margin)
		_expect_unified_style(ui.call("_level_up_panel_style"), "level panel", errors, unified_texture_margin)
		_expect_unified_style(ui.call("_character_card_style"), "card", errors, unified_texture_margin)
		_expect_unified_style(ui.call("_hud_panel_style"), "HUD panel", errors, unified_texture_margin)
		_expect_unified_style(ui.call("_hud_card_style"), "HUD card", errors, unified_texture_margin)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	_write_unified_margin_dump(unified_texture_margin)
	print("Dark fantasy UI theme test passed.")
	quit(0)


func _expect_button_state_paths(button: Button, button_type: String, errors: Array[String]) -> void:
	if button == null:
		errors.append("Expected %s button to exist." % button_type)
		return
	var expected := {
		"normal": "ui_btn_red_gold_%s.png" % button_type,
		"hover": "ui_btn_red_gold_%s.png" % button_type,
		"focus": "ui_btn_red_gold_%s.png" % button_type,
		"pressed": "ui_btn_red_gold_%s_pressed.png" % button_type,
		"disabled": "ui_btn_red_gold_%s_disabled.png" % button_type,
	}
	for state in expected.keys():
		_expect_style_path(button.get_theme_stylebox(state), str(expected[state]), "%s %s" % [button.name, state], errors, RED_GOLD_DIR)
	_expect_neutral_button_hover(button, errors)


func _expect_style_path(style: StyleBox, file_name: String, context: String, errors: Array[String], base_dir := DF_DIR) -> void:
	var texture_style := style as StyleBoxTexture
	if texture_style == null:
		errors.append("%s should use StyleBoxTexture from dark fantasy kit." % context)
		return
	if texture_style.texture == null:
		errors.append("%s StyleBoxTexture has no texture." % context)
		return
	var expected_path := base_dir + file_name
	if texture_style.texture.resource_path != expected_path:
		errors.append("%s texture mismatch: got %s, expected %s." % [context, texture_style.texture.resource_path, expected_path])


func _expect_unified_style(style: StyleBox, context: String, errors: Array[String], expected_margin: float) -> void:
	var texture_style := style as StyleBoxTexture
	if texture_style == null:
		errors.append("%s should use StyleBoxTexture from unified master frame kit." % context)
		return
	if texture_style.texture == null:
		errors.append("%s StyleBoxTexture has no texture." % context)
		return
	if not [UNIFIED_DIR + "ui_frame_unified_master.png", UNIFIED_DIR + "ui_frame_unified_master_fill.png"].has(texture_style.texture.resource_path):
		errors.append("%s texture mismatch: got %s, expected unified master/master_fill." % [context, texture_style.texture.resource_path])
	if texture_style.texture_margin_left != expected_margin or texture_style.texture_margin_top != expected_margin or texture_style.texture_margin_right != expected_margin or texture_style.texture_margin_bottom != expected_margin:
		errors.append("%s unified frame should use %dpx 9-slice texture margins from metadata." % [context, int(expected_margin)])
	if texture_style.axis_stretch_horizontal != StyleBoxTexture.AXIS_STRETCH_MODE_TILE or texture_style.axis_stretch_vertical != StyleBoxTexture.AXIS_STRETCH_MODE_TILE:
		errors.append("%s unified frame should tile both axes." % context)


func _expect_neutral_button_hover(button: Button, errors: Array[String]) -> void:
	var hover_style := button.get_theme_stylebox("hover") as StyleBoxTexture
	var focus_style := button.get_theme_stylebox("focus") as StyleBoxTexture
	if hover_style == null or focus_style == null:
		errors.append("%s hover/focus should use StyleBoxTexture." % button.name)
		return
	if hover_style.texture == null or focus_style.texture == null:
		errors.append("%s hover/focus should have textures." % button.name)
		return
	if hover_style.texture.resource_path.contains("_hover") or focus_style.texture.resource_path.contains("_hover"):
		errors.append("%s hover/focus should not use baked glow hover textures." % button.name)
	var hover_tint := hover_style.modulate_color
	var focus_tint := focus_style.modulate_color
	if not _is_neutral_bright_tint(hover_tint) or not _is_neutral_bright_tint(focus_tint):
		errors.append("%s hover/focus tint should be neutral bright, got hover=%s focus=%s." % [button.name, str(hover_tint), str(focus_tint)])
	var hover_font := button.get_theme_color("font_hover_color")
	var focus_font := button.get_theme_color("font_focus_color")
	if not _is_neutral_font_color(hover_font) or not _is_neutral_font_color(focus_font):
		errors.append("%s hover/focus font should be neutral near-white, got hover=%s focus=%s." % [button.name, str(hover_font), str(focus_font)])


func _is_neutral_bright_tint(color: Color) -> bool:
	return color.r >= 1.0 and color.g >= 1.0 and color.b >= 1.0 and absf(color.r - color.g) <= 0.015 and absf(color.g - color.b) <= 0.015


func _is_neutral_font_color(color: Color) -> bool:
	return color.r >= 0.98 and color.g >= 0.98 and color.b >= 0.98 and absf(color.r - color.g) <= 0.015 and absf(color.g - color.b) <= 0.015


func _expected_unified_texture_margin(errors: Array[String]) -> float:
	var metadata := _load_json(UNIFIED_METADATA_PATH, errors)
	var texture_margins: Dictionary = metadata.get("texture_margins", {})
	var expected_texture := Vector4(
		float(texture_margins.get("left", 72.0)),
		float(texture_margins.get("top", 72.0)),
		float(texture_margins.get("right", 72.0)),
		float(texture_margins.get("bottom", 72.0))
	)
	var expected_margin := expected_texture.x
	if expected_texture != Vector4(expected_margin, expected_margin, expected_margin, expected_margin):
		errors.append("Unified frame metadata should keep symmetric texture margins, got %s." % str(expected_texture))
	if UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS != expected_texture:
		errors.append("UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS mismatch: got %s, expected metadata %s." % [str(UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS), str(expected_texture)])
	var safe_rect_values: Array = metadata.get("strict_safe_rect", [])
	if safe_rect_values.size() >= 4:
		var expected_safe := Rect2(float(safe_rect_values[0]), float(safe_rect_values[1]), float(safe_rect_values[2]), float(safe_rect_values[3]))
		if UIThemePaths.UNIFIED_FRAME_SAFE_RECT != expected_safe:
			errors.append("UIThemePaths.UNIFIED_FRAME_SAFE_RECT mismatch: got %s, expected metadata %s." % [str(UIThemePaths.UNIFIED_FRAME_SAFE_RECT), str(expected_safe)])
	else:
		errors.append("Unified frame metadata should define strict_safe_rect.")
	return expected_margin


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not read %s." % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		errors.append("Expected %s to contain a JSON object." % path)
		return {}
	return parsed


func _write_unified_margin_dump(texture_margin: float) -> void:
	var dir := ProjectSettings.globalize_path("res://build/qa/scrum392")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("unified_frame_margins.md"), FileAccess.WRITE)
	if file == null:
		return
	file.store_line("# Unified Frame Runtime Margins")
	file.store_line("")
	file.store_line("- Metadata: `%s`" % UNIFIED_METADATA_PATH)
	file.store_line("- Texture margins: `%dpx`" % int(texture_margin))
	file.store_line("- Runtime `UNIFIED_FRAME_TEXTURE_MARGINS`: `%s`" % str(UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS))
	file.store_line("- Runtime `UNIFIED_FRAME_SAFE_RECT`: `%s`" % str(UIThemePaths.UNIFIED_FRAME_SAFE_RECT))
