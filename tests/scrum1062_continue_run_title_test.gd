extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const RunAutosave := preload("res://scripts/run_autosave.gd")
const UIButtonFamily := preload("res://scripts/ui/ui_button_family.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const TARGETS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const EXPECTED_TITLE_FONTS := [38, 40, 42, 42]
const TITLE_TEXT := "Продолжить забег?"
const OBSOLETE_WORDMARK := "res://assets/sprites/ui/menu_title/continue_run_title.png"
const OBSOLETE_GENERATOR := "res://tools/build_continue_run_title_logo.py"
const GLYPH_EFFECT_RESERVE := 4.0

var _errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	_assert_source_contract()
	for target_index in range(TARGETS.size()):
		await _check_fresh(TARGETS[target_index], EXPECTED_TITLE_FONTS[target_index])
	await _check_live_resize()
	await _check_escape_preserves_autosave()
	RunAutosave.clear_run()
	await _capture_teardown.release_windowed_audio(self)
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1062 Continue Run live-title typography test passed at four viewports, live resize and Escape preservation.")
	quit(0)


func _check_fresh(viewport_size: Vector2i, expected_font_size: int) -> void:
	_seed_autosave()
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.ui._show_continue_run_dialog()
	await _settle()
	_assert_dialog(main, viewport_size, expected_font_size, "fresh")
	if DisplayServer.get_name() != "headless":
		await _save_capture(viewport, viewport_size, "fresh")
	await _release(viewport, "%dx%d fresh" % [viewport_size.x, viewport_size.y])
	RunAutosave.clear_run()


func _check_live_resize() -> void:
	_seed_autosave()
	var viewport := SubViewport.new()
	viewport.size = TARGETS[TARGETS.size() - 1]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.ui._show_continue_run_dialog()
	await _settle()
	for target_index in range(TARGETS.size() - 1, -1, -1):
		viewport.size = TARGETS[target_index]
		await _settle()
		_assert_dialog(main, TARGETS[target_index], EXPECTED_TITLE_FONTS[target_index], "live resize")
	await _release(viewport, "live resize")
	RunAutosave.clear_run()


func _check_escape_preserves_autosave() -> void:
	_seed_autosave()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.ui._show_continue_run_dialog()
	await _settle()
	if not main.ui_escape_action.is_valid():
		_errors.append("Escape: Continue Run dialog did not publish a valid cancel action.")
	else:
		main.ui_escape_action.call()
		await _settle()
		if main.find_child("ContinueRunDialog", true, false) != null:
			_errors.append("Escape: Continue Run dialog remained open.")
		if not RunAutosave.has_run():
			_errors.append("Escape: cancelling Continue Run unexpectedly cleared autosave.")
	await _release(viewport, "Escape")
	RunAutosave.clear_run()


func _assert_dialog(main: Node, viewport_size: Vector2i, expected_font_size: int, phase: String) -> void:
	var context := "%s %dx%d" % [phase, viewport_size.x, viewport_size.y]
	var panel := main.find_child("ContinueRunPanel", true, false) as PanelContainer
	var title := main.find_child("ContinueRunTitle", true, false) as Label
	var subtitle := main.find_child("ContinueRunSubtitle", true, false) as Label
	var continue_button := main.find_child("ContinueRunButton", true, false) as Button
	var new_game_button := main.find_child("ContinueRunNewGameButton", true, false) as Button
	if panel == null or title == null or subtitle == null or continue_button == null or new_game_button == null:
		_errors.append("%s: incomplete Continue Run hierarchy or title is not a Label." % context)
		return
	if title.text != TITLE_TEXT or title.name != "ContinueRunTitle":
		_errors.append("%s: title identity/text drifted (%s / '%s')." % [context, title.name, title.text])
	if title.autowrap_mode != TextServer.AUTOWRAP_OFF or title.clip_text or title.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		_errors.append("%s: title must be one untrimmed, unclipped line." % context)
	if title.get_theme_font_size("font_size") != expected_font_size:
		_errors.append("%s: effective title font %d != standard tier %d." % [context, title.get_theme_font_size("font_size"), expected_font_size])
	if str(title.get_meta("semantic_typography_role", "")) != "title" or str(title.get_meta("font_family_contract", "")) != "theme_default":
		_errors.append("%s: semantic/default-family metadata is missing." % context)
	if title.has_theme_font_override("font"):
		_errors.append("%s: title must inherit the common theme/default Font resource." % context)
	var initial_focus_ok := main.get_viewport().gui_get_focus_owner() == continue_button

	# Compare against the existing standard modal-title family in the same runtime
	# theme, not a hard-coded platform/system font path.
	main.ui._show_quit_confirmation_dialog()
	var quit_title := main.find_child("QuitConfirmationTitle", true, false) as Label
	if quit_title == null:
		_errors.append("%s: standard QuitConfirmationTitle comparison node is missing." % context)
	elif title.get_theme_font("font") != quit_title.get_theme_font("font"):
		_errors.append("%s: Continue title font resource differs from standard title family." % context)
	main.ui._cancel_quit_confirmation_dialog()
	continue_button.grab_focus()

	var panel_rect := panel.get_global_rect()
	if panel_rect.size.distance_to(Vector2(840.0, 380.0)) > 0.6:
		_errors.append("%s: panel size drifted to %s." % [context, str(panel_rect.size)])
	var expected_panel_position := Vector2(viewport_size) * 0.5 - panel_rect.size * 0.5
	if panel_rect.position.distance_to(expected_panel_position) > 0.6:
		_errors.append("%s: panel is not centered (%s vs %s)." % [context, str(panel_rect.position), str(expected_panel_position)])
	var local_safe := panel.get_meta("continue_run_content_rect", Rect2()) as Rect2
	var global_safe := Rect2(panel_rect.position + local_safe.position, local_safe.size)
	var title_rect := title.get_global_rect()
	if title_rect.size.y < 69.5 or title_rect.size.x < 695.0:
		_errors.append("%s: title slot is too small: %s." % [context, str(title_rect)])
	if not global_safe.grow(0.6).encloses(title_rect):
		_errors.append("%s: title slot %s escapes authored panel safe zone %s." % [context, str(title_rect), str(global_safe)])
	if title_rect.intersects(subtitle.get_global_rect()) or title_rect.intersects(continue_button.get_global_rect()) or title_rect.intersects(new_game_button.get_global_rect()):
		_errors.append("%s: title overlaps subtitle/buttons." % context)
	if subtitle.get_global_rect().intersects(continue_button.get_global_rect()) or subtitle.get_global_rect().intersects(new_game_button.get_global_rect()):
		_errors.append("%s: subtitle overlaps action row." % context)
	for control in [subtitle, continue_button, new_game_button]:
		if not global_safe.grow(0.6).encloses((control as Control).get_global_rect()):
			_errors.append("%s: %s escapes authored panel safe zone." % [context, (control as Control).name])

	var font: Font = title.get_theme_font("font")
	if font == null:
		_errors.append("%s: title has no effective Font." % context)
	else:
		var glyph_size := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, title.get_theme_font_size("font_size"))
		var glyph_rect := Rect2(title_rect.get_center() - glyph_size * 0.5, glyph_size).grow(GLYPH_EFFECT_RESERVE)
		if not title_rect.grow(-1.0).encloses(glyph_rect):
			_errors.append("%s: rendered glyph/effect bounds %s touch or escape title slot %s." % [context, str(glyph_rect), str(title_rect)])
		if not global_safe.grow(-1.0).encloses(glyph_rect):
			_errors.append("%s: rendered glyph/effect bounds escape the empty frame content zone." % context)

	if not initial_focus_ok:
		_errors.append("%s: initial focus must remain ContinueRunButton." % context)
	if continue_button.focus_neighbor_left != new_game_button.get_path() or continue_button.focus_neighbor_right != new_game_button.get_path():
		_errors.append("%s: Continue left/right focus ring drifted." % context)
	if new_game_button.focus_neighbor_left != continue_button.get_path() or new_game_button.focus_neighbor_right != continue_button.get_path():
		_errors.append("%s: New Game left/right focus ring drifted." % context)
	for button in [continue_button, new_game_button]:
		if (button as Button).pressed.get_connections().is_empty():
			_errors.append("%s: %s lost its callback." % [context, (button as Button).name])
		_assert_button_states(button as Button, context)
	if phase == "fresh":
		print("SCRUM-1062 geometry %dx%d: panel=%s title_local=%s safe_local=%s font=%d" % [
			viewport_size.x, viewport_size.y, str(panel_rect),
			str(Rect2(title_rect.position - panel_rect.position, title_rect.size)),
			str(local_safe), title.get_theme_font_size("font_size")])


func _assert_button_states(button: Button, context: String) -> void:
	var baseline := Vector4.ZERO
	for state in UIButtonFamily.STATES:
		var style := button.get_theme_stylebox(state)
		if style == null:
			_errors.append("%s: %s misses %s state." % [context, button.name, state])
			continue
		var margins := Vector4(
			style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_TOP),
			style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_BOTTOM))
		if state == "normal":
			baseline = margins
		elif not margins.is_equal_approx(baseline):
			_errors.append("%s: %s %s changes content geometry." % [context, button.name, state])


func _assert_source_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui_screens.gd")
	if source.contains("continue_run_title.png") or source.contains("TextureRect.new()\n\ttitle_label.name = \"ContinueRunTitle\""):
		_errors.append("Source: Continue Run still references the texture wordmark path/type.")
	if ResourceLoader.exists(OBSOLETE_WORDMARK) or FileAccess.file_exists(OBSOLETE_GENERATOR):
		_errors.append("Source: obsolete Continue Run wordmark/generator still ships despite no remaining consumer.")


func _seed_autosave() -> void:
	RunAutosave.clear_run()
	RunAutosave.save_run({
		"selected_character_id": "berserk",
		"selected_weapon_id": "sword",
		"current_act": 1,
		"route_stage": 2,
		"run_player_snapshot": {
			"character_id": "berserk", "weapon_id": "sword",
			"money": 240, "level": 5,
		},
	})


func _save_capture(viewport: SubViewport, viewport_size: Vector2i, phase: String) -> void:
	await _settle()
	var path := ProjectSettings.globalize_path("res://build/qa/scrum1062/continue_title_%s_%dx%d.png" % [phase, viewport_size.x, viewport_size.y])
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
		push_error("SCRUM-1062 test requires --user-data-dir=<unique scratch root>.")
		return false
	if not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1062 scratch mismatch: user://=%s requested=%s." % [actual, requested])
		return false
	return true
