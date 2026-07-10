extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ProgressionData := preload("res://scripts/progression_data.gd")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const FULL_TEXT_VIEWPORT_HEIGHT := 1000

var errors := PackedStringArray()
var report := PackedStringArray(["# SCRUM-980 / SCRUM-1026 Hero Select ascension layout", ""])


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORTS:
		await _check_viewport(viewport_size)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum1026")
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
	print("SCRUM-1026 Hero Select all-level ascension layout test passed.")
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
	var unlocked := {}
	for character_id in ProgressionData.character_ids():
		unlocked[str(character_id)] = 4
	var state: Dictionary = main.get("meta_state")
	state["ascension_levels"] = unlocked
	main.set("meta_state", state)
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	for _frame_index in range(8):
		await process_frame

	var context := "Hero Select %s" % str(viewport_size)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var action_row := main.find_child("HS4AscensionActionRow", true, false) as Control
	var minus := main.find_child("AscensionMinusButton", true, false) as Button
	var value := main.find_child("HS4AscensionValue", true, false) as Label
	var plus := main.find_child("AscensionPlusButton", true, false) as Button
	var description := main.find_child("AscensionModsLabel", true, false) as Label
	var description_scroll := main.find_child("HS4AscensionDescriptionScroll", true, false) as ScrollContainer
	var choose := main.find_child("HS4ChooseButton", true, false) as Button
	var dossier := main.find_child("HS4DossierFrame", true, false) as Control
	var carousel := main.find_child("HS4CarouselFrame", true, false) as Control
	var counter := main.find_child("HS4CarouselCounter", true, false) as Control
	var first_slot := main.find_child("HS4CarouselSlot_00", true, false) as Button
	var second_slot := main.find_child("HS4CarouselSlot_01", true, false) as Button
	if ascension == null or action_row == null or minus == null or value == null or plus == null \
			or description == null or description_scroll == null or choose == null \
			or dossier == null or carousel == null or counter == null \
			or first_slot == null or second_slot == null:
		errors.append("%s: missing ascension/major-zone/carousel controls." % context)
		await _teardown(viewport)
		return

	var asc_rect := ascension.get_global_rect()
	var row_rect := action_row.get_global_rect()
	var minus_rect := minus.get_global_rect()
	var value_rect := value.get_global_rect()
	var plus_rect := plus.get_global_rect()
	var choose_rect := choose.get_global_rect()
	var panel_style := ascension.get_theme_stylebox("panel")
	var frame_content_rect := asc_rect
	if panel_style != null:
		var content_left := panel_style.get_content_margin(SIDE_LEFT)
		var content_top := panel_style.get_content_margin(SIDE_TOP)
		var content_right := panel_style.get_content_margin(SIDE_RIGHT)
		var content_bottom := panel_style.get_content_margin(SIDE_BOTTOM)
		frame_content_rect = Rect2(
			asc_rect.position + Vector2(content_left, content_top),
			asc_rect.size - Vector2(content_left + content_right, content_top + content_bottom))
	for control in [ascension, action_row, minus, value, plus, description_scroll, choose, dossier, carousel, counter, first_slot, second_slot]:
		var rect := (control as Control).get_global_rect()
		if not viewport_rect.grow(1.0).encloses(rect):
			errors.append("%s: %s escapes the physical viewport: %s." % [context, control.name, str(rect)])
	if not asc_rect.grow(1.0).encloses(row_rect) or not asc_rect.grow(1.0).encloses(minus_rect) \
			or not asc_rect.grow(1.0).encloses(value_rect) or not asc_rect.grow(1.0).encloses(plus_rect):
		errors.append("%s: stepper escapes its ascension frame." % context)
	if not frame_content_rect.grow(0.5).encloses(row_rect) \
			or not frame_content_rect.grow(0.5).encloses(description_scroll.get_global_rect()):
		errors.append("%s: stepper/description leaves the real empty frame content zone %s." % [context, str(frame_content_rect)])
	if minus_rect.grow(-1.0).intersects(value_rect.grow(-1.0)) \
			or value_rect.grow(-1.0).intersects(plus_rect.grow(-1.0)) \
			or minus_rect.grow(-1.0).intersects(plus_rect.grow(-1.0)):
		errors.append("%s: minus/value/plus controls overlap." % context)
	for major in [dossier, carousel, counter, choose]:
		if asc_rect.grow(-1.0).intersects((major as Control).get_global_rect().grow(-1.0)):
			errors.append("%s: ascension frame overlaps %s." % [context, major.name])
	if not ascension.is_ancestor_of(description) or not description_scroll.is_ancestor_of(description):
		errors.append("%s: ascension description is not scroll-safe inside HS4AscensionFrame." % context)
	if not asc_rect.grow(-2.0).encloses(description_scroll.get_global_rect()):
		errors.append("%s: ascension description scroll escapes the frame content zone." % context)
	if action_row.get_global_rect().grow(-1.0).intersects(description_scroll.get_global_rect().grow(-1.0)):
		errors.append("%s: stepper overlaps the description content zone." % context)
	if description.max_lines_visible >= 0 or description.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		errors.append("%s: ascension description may still be ellipsized instead of scrolling." % context)
	if description_scroll.focus_mode != Control.FOCUS_ALL or plus.focus_neighbor_right != description_scroll.get_path():
		errors.append("%s: ascension description is not reachable from the stepper by keyboard/gamepad." % context)

	var max_level := ProgressionData.ASCENSION_MODIFIERS.size()
	if int(main.get("selected_ascension_level")) != max_level:
		errors.append("%s: setup did not expose the complete selectable 0..%d range." % [context, max_level])
	var compact_overflow_seen := false
	for level in range(max_level, -1, -1):
		compact_overflow_seen = bool(await _check_level_state(
			main, viewport_size, level, max_level, ascension, value, description_scroll, description, context
		)) or compact_overflow_seen
		if level > 0:
			await _pointer_click(viewport, minus, context)
	for level in range(1, max_level + 1):
		await _pointer_click(viewport, plus, context)
		compact_overflow_seen = bool(await _check_level_state(
			main, viewport_size, level, max_level, ascension, value, description_scroll, description, context
		)) or compact_overflow_seen
	if viewport_size.y < FULL_TEXT_VIEWPORT_HEIGHT and not compact_overflow_seen:
		errors.append("%s: compact matrix never exercised the required internal scroll path." % context)
	var hovered := await _pointer_hover(viewport, description_scroll, context)
	if hovered != description_scroll:
		errors.append("%s: visible delta hover resolves to %s instead of HS4AscensionDescriptionScroll." % [
			context, "<none>" if hovered == null else str(hovered.name)])
	var pre_input_scrollbar := description_scroll.get_v_scroll_bar()
	var pre_input_overflow := maxf(0.0, pre_input_scrollbar.max_value - pre_input_scrollbar.page)
	await _pointer_wheel(viewport, description_scroll, MOUSE_BUTTON_WHEEL_DOWN, context)
	if pre_input_overflow > 1.0 and description_scroll.scroll_vertical <= 0:
		errors.append("%s: physical mouse wheel did not scroll compact ascension copy." % context)
	if pre_input_overflow <= 1.0 and description_scroll.scroll_vertical != 0:
		errors.append("%s: physical mouse wheel moved a non-overflowing full-size description." % context)
	description_scroll.scroll_vertical = 0
	await process_frame

	# Prove the two physical routes independently: an Arrow-Down key event and a
	# D-pad Down joypad event must scroll compact overflow first, then transfer to
	# Choose. On full-size layouts they transfer immediately with scroll == 0.
	await _exercise_physical_down_route(
		viewport, description_scroll, choose, compact_overflow_seen, context, false)
	await _exercise_physical_down_route(
		viewport, description_scroll, choose, compact_overflow_seen, context, true)

	# A real hero-slot pointer click must reset the selected-level description to
	# its first line. At 720p the precondition is a non-zero scroll reached by the
	# actual input route above; at full sizes the content intentionally cannot
	# overflow, but the same refresh path is still verified.
	var previous_character := str(main.get("selected_character_id"))
	await _pointer_click(viewport, second_slot, context)
	if str(main.get("selected_character_id")) == previous_character:
		errors.append("%s: real pointer click did not switch hero." % context)
	if description_scroll.scroll_vertical != 0 or description.get_global_rect().position.y < description_scroll.get_global_rect().position.y - 1.0:
		errors.append("%s: hero switching did not reset the description to its first line." % context)
	await _pointer_click(viewport, first_slot, context)
	if str(main.get("selected_character_id")) != "berserk":
		errors.append("%s: real pointer click did not restore the first hero." % context)

	report.append("## %s" % context)
	report.append("- ascension frame: `%s`; row: `%s`; Choose: `%s`" % [str(asc_rect), str(row_rect), str(choose_rect)])
	report.append("- description scroll: `%s`; all selectable levels: `0..%d`; compact overflow seen: `%s`" % [
		str(description_scroll.get_global_rect()), max_level, str(compact_overflow_seen)])
	report.append("")
	if DisplayServer.get_name() != "headless":
		var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum1026")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/hero_select_ascension_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
	await _teardown(viewport)


func _check_level_state(
	main: Node,
	viewport_size: Vector2i,
	level: int,
	max_level: int,
	ascension: Control,
	value: Label,
	description_scroll: ScrollContainer,
	description: Label,
	context: String
) -> bool:
	for _frame_index in range(4):
		await process_frame
	if int(main.get("selected_ascension_level")) != level:
		errors.append("%s level %d: real stepper input selected %s." % [context, level, str(main.get("selected_ascension_level"))])
	var expected := ProgressionData.ascension_level_change_line(level)
	if description.text != expected or expected == "":
		errors.append("%s level %d: visible selected-level delta is incomplete (got `%s`)." % [context, level, description.text])
	if value.text != "%d / %d" % [level, max_level]:
		errors.append("%s level %d: stepper value is `%s`." % [context, level, value.text])
	var tooltip_lines := PackedStringArray()
	for line in ProgressionData.ascension_modifier_lines(level):
		tooltip_lines.append(str(line))
	var expected_tooltip := "Уровень 0: без усложнений." if tooltip_lines.is_empty() else "\n".join(tooltip_lines)
	if description.tooltip_text != expected_tooltip or ascension.tooltip_text != expected_tooltip:
		errors.append("%s level %d: cumulative tooltip is not exact." % [context, level])
	var expected_scroll_tooltip := "%s\nПрокрутка: ↑/↓, D-pad или колесо мыши." % expected_tooltip
	if description_scroll.tooltip_text != expected_scroll_tooltip:
		errors.append("%s level %d: live hover target does not expose the exact cumulative tooltip." % [context, level])
	if description_scroll.scroll_vertical != 0:
		errors.append("%s level %d: refresh did not reset description scroll to top." % [context, level])
	var scroll_rect := description_scroll.get_global_rect()
	var description_rect := description.get_global_rect()
	if description_rect.position.y < scroll_rect.position.y - 1.0:
		errors.append("%s level %d: description does not restart at its first line." % [context, level])
	var scrollbar := description_scroll.get_v_scroll_bar()
	var overflow := maxf(0.0, scrollbar.max_value - scrollbar.page)
	if viewport_size.y >= FULL_TEXT_VIEWPORT_HEIGHT:
		if description_rect.size.y > scroll_rect.size.y + 1.0 or overflow > 1.0:
			errors.append("%s level %d: full-size description still overflows (label %.2f, viewport %.2f, range %.2f)." % [
				context, level, description_rect.size.y, scroll_rect.size.y, overflow])
	report.append("- %s level %d: label `%.2f`, viewport `%.2f`, overflow `%.2f`" % [
		str(viewport_size), level, description_rect.size.y, scroll_rect.size.y, overflow])
	return overflow > 1.0


func _pointer_click(viewport: Viewport, control: Control, context: String) -> void:
	var point := control.get_global_rect().get_center()
	var visible_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	if not visible_rect.grow(1.0).encloses(control.get_global_rect()) or not visible_rect.has_point(point):
		errors.append("%s: refusing pointer click on %s outside the physical viewport (rect %s)." % [
			context, control.name, str(control.get_global_rect())])
		return
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	release.global_position = point
	release.pressed = false
	release.button_mask = 0
	viewport.push_input(release, true)
	for _frame_index in range(3):
		await process_frame


func _pointer_hover(viewport: Viewport, control: Control, context: String) -> Control:
	var point := control.get_global_rect().get_center()
	var visible_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	if not visible_rect.grow(1.0).encloses(control.get_global_rect()) or not visible_rect.has_point(point):
		errors.append("%s: refusing pointer hover on %s outside the physical viewport." % [context, control.name])
		return null
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	for _frame_index in range(2):
		await process_frame
	return viewport.gui_get_hovered_control()


func _pointer_wheel(viewport: Viewport, control: Control, button_index: MouseButton, context: String) -> void:
	var point := control.get_global_rect().get_center()
	var visible_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	if not visible_rect.grow(1.0).encloses(control.get_global_rect()) or not visible_rect.has_point(point):
		errors.append("%s: refusing pointer wheel on %s outside the physical viewport." % [context, control.name])
		return
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = button_index
	wheel.position = point
	wheel.global_position = point
	wheel.pressed = true
	wheel.factor = 1.0
	viewport.push_input(wheel, true)
	await process_frame
	var wheel_release := InputEventMouseButton.new()
	wheel_release.button_index = button_index
	wheel_release.position = point
	wheel_release.global_position = point
	wheel_release.pressed = false
	wheel_release.factor = 1.0
	viewport.push_input(wheel_release, true)
	for _frame_index in range(3):
		await process_frame


func _exercise_physical_down_route(
	viewport: SubViewport,
	description_scroll: ScrollContainer,
	choose: Button,
	expects_overflow: bool,
	context: String,
	use_dpad: bool
) -> void:
	description_scroll.scroll_vertical = 0
	description_scroll.grab_focus()
	await process_frame
	var route_name := "D-pad Down" if use_dpad else "Arrow Down"
	if viewport.gui_get_focus_owner() != description_scroll:
		errors.append("%s: description could not receive focus before physical %s." % [context, route_name])
		return
	var scrolled := false
	for _press_index in range(10):
		if viewport.gui_get_focus_owner() != description_scroll:
			break
		var before_scroll := description_scroll.scroll_vertical
		if use_dpad:
			await _push_dpad_down(viewport)
		else:
			await _push_arrow_down(viewport)
		if description_scroll.scroll_vertical > before_scroll:
			scrolled = true
	var scrollbar := description_scroll.get_v_scroll_bar()
	var remaining_scroll := maxf(0.0, scrollbar.max_value - scrollbar.page - float(description_scroll.scroll_vertical))
	if expects_overflow and not scrolled:
		errors.append("%s: physical %s did not scroll compact overflow." % [context, route_name])
	if not expects_overflow and description_scroll.scroll_vertical != 0:
		errors.append("%s: physical %s scrolled non-overflowing full-size copy." % [context, route_name])
	if scrolled and remaining_scroll > 1.0:
		errors.append("%s: physical %s cannot reach the description bottom." % [context, route_name])
	if viewport.gui_get_focus_owner() != choose:
		errors.append("%s: physical %s did not transfer to Choose at the boundary." % [context, route_name])


func _push_arrow_down(viewport: SubViewport) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_DOWN
	press.physical_keycode = KEY_DOWN
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_DOWN
	release.physical_keycode = KEY_DOWN
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _push_dpad_down(viewport: SubViewport) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_DPAD_DOWN
	press.pressed = true
	press.pressure = 1.0
	viewport.push_input(press)
	await process_frame
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_DPAD_DOWN
	release.pressed = false
	release.pressure = 0.0
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
		push_error("SCRUM-1026 test requires an isolated scratch user:// root; got `%s`, requested `%s`." % [actual, requested])
		return false
	return true


func _teardown(viewport: SubViewport) -> void:
	viewport.queue_free()
	for _frame_index in range(4):
		await process_frame
