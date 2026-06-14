extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const DF_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"
const RED_GOLD_DIR := "res://assets/sprites/ui/frames/red_gold/"
const ORNATE_DIR := "res://assets/sprites/ui/frames/ornate/"


func _initialize() -> void:
	var errors: Array[String] = []
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
		_expect_style_path(ui.call("_panel_style"), "ui_frame_ornate_global_panel.png", "panel", errors, ORNATE_DIR)
		_expect_style_path(ui.call("_level_up_panel_style"), "ui_frame_ornate_level_panel.png", "level panel", errors, ORNATE_DIR)
		_expect_style_path(ui.call("_character_card_style"), "ui_frame_ornate_card_frame.png", "card", errors, ORNATE_DIR)
		_expect_style_path(ui.call("_hud_panel_style"), "ui_frame_ornate_hud_panel.png", "HUD panel", errors, ORNATE_DIR)
		_expect_style_path(ui.call("_hud_card_style"), "ui_frame_ornate_hud_card.png", "HUD card", errors, ORNATE_DIR)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
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
