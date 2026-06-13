extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const DF_DIR := "res://assets/sprites/ui/frames/dark_fantasy/"


func _initialize() -> void:
	var errors: Array[String] = []
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	var start_button := main.find_child("MainMenuStartButton", true, false) as Button
	var settings_button := main.find_child("MainMenuSettingsButton", true, false) as Button
	var exit_button := main.find_child("MainMenuExitButton", true, false) as Button
	_expect_button_state_paths(start_button, "primary", errors)
	_expect_button_state_paths(settings_button, "secondary", errors)
	_expect_button_state_paths(exit_button, "danger", errors)

	var ui = main.get("ui")
	if ui == null:
		errors.append("Main.ui is missing.")
	else:
		_expect_style_path(ui.call("_panel_style"), "ui_df_panel_frame.png", "panel", errors)
		_expect_style_path(ui.call("_level_up_panel_style"), "ui_df_level_panel_frame.png", "level panel", errors)
		_expect_style_path(ui.call("_character_card_style"), "ui_df_card_frame.png", "card", errors)
		_expect_style_path(ui.call("_hud_panel_style"), "ui_df_hud_panel_frame.png", "HUD panel", errors)
		_expect_style_path(ui.call("_hud_card_style"), "ui_df_hud_card_frame.png", "HUD card", errors)

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("Dark fantasy UI theme test passed.")
	quit(0)


func _expect_button_state_paths(button: Button, role: String, errors: Array[String]) -> void:
	if button == null:
		errors.append("Expected %s button to exist." % role)
		return
	var expected := {
		"normal": "ui_df_button_%s_idle.png" % role,
		"hover": "ui_df_button_%s_hover.png" % role,
		"pressed": "ui_df_button_%s_pressed.png" % role,
		"disabled": "ui_df_button_%s_disabled.png" % role,
	}
	for state in expected.keys():
		_expect_style_path(button.get_theme_stylebox(state), str(expected[state]), "%s %s" % [button.name, state], errors)


func _expect_style_path(style: StyleBox, file_name: String, context: String, errors: Array[String]) -> void:
	var texture_style := style as StyleBoxTexture
	if texture_style == null:
		errors.append("%s should use StyleBoxTexture from dark fantasy kit." % context)
		return
	if texture_style.texture == null:
		errors.append("%s StyleBoxTexture has no texture." % context)
		return
	var expected_path := DF_DIR + file_name
	if texture_style.texture.resource_path != expected_path:
		errors.append("%s texture mismatch: got %s, expected %s." % [context, texture_style.texture.resource_path, expected_path])
