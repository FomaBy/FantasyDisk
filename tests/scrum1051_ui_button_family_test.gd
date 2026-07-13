extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PAUSE_SCENE := preload("res://scenes/PauseStatsMenu.tscn")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const GRATITUDE_ICON_PATH := "res://assets/sprites/ui/icons/credits/ui_icon_gratitude.png"

var errors := PackedStringArray()


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame

	main.ui._show_main_menu()
	await _settle()
	_audit_visible_buttons(main, "Main Menu")
	for node_name in [
		"MainMenuStartButton", "MainMenuSettingsButton", "MainMenuSkillTreeButton",
		"MainMenuPatchNotesButton", "MainMenuCodexButton", "MainMenuExitButton",
	]:
		_expect_family(main.find_child(node_name, true, false) as BaseButton, "text/main_menu_380x104", node_name)
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	_expect_family(credits, "credits_icon", "MainMenuCreditsButton")
	if credits == null or credits.text != "" or credits.icon == null or _gratitude_source_path(credits.icon) != GRATITUDE_ICON_PATH:
		errors.append("MainMenuCreditsButton must be icon-only and use the accepted gratitude asset.")
	elif credits.tooltip_text != "Благодарности" or str(credits.get_meta("accessibility_name", "")) != "Благодарности":
		errors.append("MainMenuCreditsButton must expose gratitude tooltip/accessibility metadata.")
	_expect_neutral_gratitude_focus(credits)
	if credits != null:
		credits.pressed.emit()
		await _settle()
		if main.find_child("CreditsScreen", true, false) == null:
			errors.append("MainMenuCreditsButton no longer opens CreditsScreen.")
		var credits_back := main.find_child("CreditsBackButton", true, false) as Button
		if credits_back == null:
			errors.append("CreditsScreen is missing CreditsBackButton.")
		else:
			credits_back.pressed.emit()
			await _settle()
			if main.find_child("MainMenuScreen", true, false) == null:
				errors.append("CreditsBackButton no longer returns to Main Menu.")

	main.ui._show_codex_screen()
	await _settle()
	_audit_visible_buttons(main, "Codex")
	_expect_family(main.find_child("CodexBackButton", true, false) as BaseButton, "text/back_260x104", "CodexBackButton")
	for section_id in ["characters", "monsters", "artifacts", "characteristics", "attributes", "ascension"]:
		var tab := main.find_child("CodexTab_%s" % section_id, true, false) as Button
		_expect_family(tab, UIButtonFamily.FAMILY_CODEX_TAB, "CodexTab_%s" % section_id)
		_expect_stable_state_geometry(tab, "CodexTab_%s" % section_id)
	var entry := main.find_child("CodexEntryCard", true, false) as BaseButton
	_expect_family(entry, UIButtonFamily.FAMILY_CONTENT_ROW, "CodexEntryCard")

	var pause := PAUSE_SCENE.instantiate()
	viewport.add_child(pause)
	await _settle()
	_audit_visible_buttons(pause, "Pause dossier")
	for node_name in ["PauseResumeButton", "PauseSettingsButton", "PauseEndRunButton", "PauseMainMenuButton"]:
		var pause_button := pause.find_child(node_name, true, false) as Button
		if pause_button == null:
			errors.append("Pause dossier is missing %s." % node_name)
			continue
		var family := str(pause_button.get_meta(UIButtonFamily.META_FAMILY, ""))
		var expected_family := UIButtonFamily.main_menu_action_family(pause_button.custom_minimum_size)
		if family != expected_family or not UIButtonFamily.is_main_menu_visual_family(family):
			errors.append("%s must use size-matched main-menu family '%s', got '%s'." % [node_name, expected_family, family])
		_expect_stable_state_geometry(pause_button, node_name)

	var slim := Button.new()
	slim.name = "SCRUM1051SlimProbe"
	slim.custom_minimum_size = Vector2(420, 72)
	main.ui._apply_slim_action_button_theme(slim)
	_expect_family(slim, UIButtonFamily.FAMILY_SLIM_ACTION, "slim action probe")
	_expect_stable_state_geometry(slim, "slim action probe")
	slim.free()
	main.queue_free()
	viewport.queue_free()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1051 semantic UI button family test passed.")
	quit(0)


func _gratitude_source_path(icon: Texture2D) -> String:
	if icon is AtlasTexture:
		var atlas := (icon as AtlasTexture).atlas
		return atlas.resource_path if atlas != null else ""
	return icon.resource_path if icon != null else ""


func _audit_visible_buttons(scope: Node, context: String) -> void:
	for node in scope.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or not button.is_visible_in_tree() or not (button is Button or button is TextureButton):
			continue
		if not (button as Control).get_global_rect().has_area():
			continue
		var family := str(button.get_meta(UIButtonFamily.META_FAMILY, ""))
		if family == "":
			errors.append("%s: %s has no ui_button_family." % [context, str(button.name)])
		elif not UIButtonFamily.is_registered(family):
			errors.append("%s: %s has unregistered family '%s'." % [context, str(button.name), family])


func _expect_family(button: BaseButton, expected: String, context: String) -> void:
	if button == null:
		errors.append("%s is missing." % context)
		return
	var actual := str(button.get_meta(UIButtonFamily.META_FAMILY, ""))
	if actual != expected:
		errors.append("%s family '%s' != '%s'." % [context, actual, expected])


func _expect_stable_state_geometry(button: Button, context: String) -> void:
	if button == null:
		return
	var baseline := Vector4.ZERO
	for state in UIButtonFamily.STATES:
		var style := button.get_theme_stylebox(state)
		if style == null:
			errors.append("%s is missing %s style." % [context, state])
			continue
		var margins := Vector4(style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom)
		if state == "normal":
			baseline = margins
		elif margins != baseline:
			errors.append("%s changes content geometry in %s (%s != %s)." % [context, state, str(margins), str(baseline)])


func _expect_neutral_gratitude_focus(button: Button) -> void:
	if button == null:
		return
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
	if focus == null:
		errors.append("MainMenuCreditsButton focus must use a visible StyleBoxFlat.")
		return
	var color := focus.border_color
	var high := maxf(color.r, maxf(color.g, color.b))
	var low := minf(color.r, minf(color.g, color.b))
	var saturation := 0.0 if high <= 0.0001 else (high - low) / high
	if saturation > 0.15 or color.b < color.r or color.b < color.g:
		errors.append("MainMenuCreditsButton focus must be neutral low-saturation bright metal, got %s (saturation %.3f)." % [str(color), saturation])
	if hover != null and focus.border_color.is_equal_approx(hover.border_color):
		errors.append("MainMenuCreditsButton focus must remain visually distinct from hover.")


func _settle() -> void:
	for _frame in range(4):
		await process_frame
