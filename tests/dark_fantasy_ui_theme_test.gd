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
		"hover": "ui_btn_red_gold_%s_hover.png" % button_type,
		"pressed": "ui_btn_red_gold_%s_pressed.png" % button_type,
		"disabled": "ui_btn_red_gold_%s_disabled.png" % button_type,
	}
	for state in expected.keys():
		_expect_style_path(button.get_theme_stylebox(state), str(expected[state]), "%s %s" % [button.name, state], errors, RED_GOLD_DIR)


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
