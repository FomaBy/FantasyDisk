extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ProgressionData := preload("res://scripts/progression_data.gd")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var errors := PackedStringArray()
var report := PackedStringArray(["# SCRUM-980 Hero Select ascension layout", ""])


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORTS:
		await _check_viewport(viewport_size)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum980")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report_file := FileAccess.open("%s/ascension_layout_matrix.md" % qa_dir, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report))
		report_file.close()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-980 Hero Select ascension layout test passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	var state: Dictionary = main.get("meta_state")
	state["ascension_levels"] = {"berserk": 2}
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	for _frame_index in range(8):
		await process_frame

	var context := "Hero Select %s" % str(viewport_size)
	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var action_row := main.find_child("HS4AscensionActionRow", true, false) as Control
	var minus := main.find_child("AscensionMinusButton", true, false) as Button
	var value := main.find_child("HS4AscensionValue", true, false) as Label
	var plus := main.find_child("AscensionPlusButton", true, false) as Button
	var description := main.find_child("AscensionModsLabel", true, false) as Label
	var description_scroll := main.find_child("HS4AscensionDescriptionScroll", true, false) as ScrollContainer
	var choose := main.find_child("HS4ChooseButton", true, false) as Button
	if ascension == null or action_row == null or minus == null or value == null or plus == null \
			or description == null or description_scroll == null or choose == null:
		errors.append("%s: missing ascension/description-scroll/Choose controls." % context)
		await _teardown(viewport)
		return

	var asc_rect := ascension.get_global_rect()
	var row_rect := action_row.get_global_rect()
	var minus_rect := minus.get_global_rect()
	var value_rect := value.get_global_rect()
	var plus_rect := plus.get_global_rect()
	var choose_rect := choose.get_global_rect()
	var initial_level := int(main.get("selected_ascension_level"))
	if not asc_rect.grow(1.0).encloses(row_rect) or not asc_rect.grow(1.0).encloses(minus_rect) \
			or not asc_rect.grow(1.0).encloses(value_rect) or not asc_rect.grow(1.0).encloses(plus_rect):
		errors.append("%s: stepper escapes its compact ascension frame." % context)
	if minus_rect.grow(-1.0).intersects(value_rect.grow(-1.0)) \
			or value_rect.grow(-1.0).intersects(plus_rect.grow(-1.0)) \
			or minus_rect.grow(-1.0).intersects(plus_rect.grow(-1.0)):
		errors.append("%s: minus/value/plus controls overlap." % context)
	if asc_rect.grow(-1.0).intersects(choose_rect.grow(-1.0)):
		errors.append("%s: ascension frame overlaps HS4ChooseButton." % context)
	if not ascension.is_ancestor_of(description) or not description_scroll.is_ancestor_of(description):
		errors.append("%s: ascension description is not scroll-safe inside HS4AscensionFrame." % context)
	if not asc_rect.grow(-2.0).encloses(description_scroll.get_global_rect()):
		errors.append("%s: ascension description scroll escapes the frame content zone." % context)
	var expected := ProgressionData.ascension_level_change_line(initial_level)
	if description.text != expected or expected == "":
		errors.append("%s: ascension description is incomplete (got `%s`)." % [context, description.text])
	if description.max_lines_visible >= 0 or description.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		errors.append("%s: ascension description may still be ellipsized instead of scrolling." % context)
	if description_scroll.focus_mode != Control.FOCUS_ALL or plus.focus_neighbor_right != description_scroll.get_path():
		errors.append("%s: ascension description is not reachable from the stepper by keyboard/gamepad." % context)

	# The actual focused ui_down route must expose the overflow on 720p. This is
	# intentionally not a direct scroll_vertical assignment: it verifies the
	# same interaction a keyboard/gamepad-only player receives.
	description_scroll.grab_focus()
	await process_frame
	if viewport.gui_get_focus_owner() != description_scroll:
		errors.append("%s: ascension description could not receive keyboard/gamepad focus." % context)
	var initially_overflows := description.get_global_rect().size.y > description_scroll.get_global_rect().size.y + 0.5
	var scrolled_with_action := false
	for _press_index in range(8):
		if viewport.gui_get_focus_owner() != description_scroll:
			break
		var before_scroll := description_scroll.scroll_vertical
		await _push_action(viewport, "ui_down")
		if description_scroll.scroll_vertical > before_scroll:
			scrolled_with_action = true
	if initially_overflows and not scrolled_with_action:
		errors.append("%s: focused ui_down did not scroll the overflowing ascension description." % context)
	var scrollbar := description_scroll.get_v_scroll_bar()
	var remaining_scroll := scrollbar.max_value - scrollbar.page - float(description_scroll.scroll_vertical)
	if scrolled_with_action and remaining_scroll > 1.0:
		errors.append("%s: keyboard/gamepad scrolling cannot reach the description bottom." % context)
	# At bottom/no-overflow Down must follow the declared Choose neighbor, proving
	# the scroll is not a keyboard/gamepad focus trap.
	if viewport.gui_get_focus_owner() != choose:
		errors.append("%s: Down at the description boundary did not move focus to Choose." % context)

	# Actual +/- interaction must update the description without moving or
	# overlapping the right-panel controls, and must reset the new delta to top.
	minus.pressed.emit()
	for _frame_index in range(4):
		await process_frame
	var expected_after_minus := ProgressionData.ascension_level_change_line(maxi(initial_level - 1, 0))
	if int(main.get("selected_ascension_level")) != maxi(initial_level - 1, 0) or description.text != expected_after_minus:
		errors.append("%s: minus did not update the visible full description." % context)
	if description_scroll.scroll_vertical != 0:
		errors.append("%s: changing ascension level did not reset description scroll to top." % context)
	var scroll_rect := description_scroll.get_global_rect()
	var visible_description := scroll_rect.intersection(description.get_global_rect())
	if visible_description.size.y < 12.0:
		errors.append("%s: updated ascension description was not visible in the ascension scroll." % context)
	if description.get_global_rect().position.y < scroll_rect.position.y - 1.0:
		errors.append("%s: updated ascension description does not restart at its first line." % context)
	if action_row.get_global_rect().grow(-1.0).intersects(description.get_global_rect().grow(-1.0)) \
			or choose.get_global_rect().grow(-1.0).intersects(description.get_global_rect().grow(-1.0)):
		errors.append("%s: description still overlaps stepper or Choose after interaction." % context)

	report.append("## %s" % context)
	report.append("- ascension frame: `%s`; row: `%s`; Choose: `%s`" % [str(asc_rect), str(row_rect), str(choose_rect)])
	report.append("- description scroll: `%s`; description: `%s`; visible: `%s`" % [str(scroll_rect), str(description.get_global_rect()), str(visible_description)])
	report.append("")
	if DisplayServer.get_name() != "headless":
		var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum980")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/hero_select_ascension_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
	await _teardown(viewport)


func _push_action(viewport: SubViewport, action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--user-data-dir="):
			requested = value.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-980 test requires an isolated scratch user:// root; got `%s`, requested `%s`." % [actual, requested])
		return false
	return true


func _teardown(viewport: SubViewport) -> void:
	viewport.queue_free()
	for _frame_index in range(4):
		await process_frame
