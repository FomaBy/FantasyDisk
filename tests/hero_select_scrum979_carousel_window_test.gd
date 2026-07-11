extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORTS:
		await _exercise_viewport(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	if not errors.is_empty():
		for error in errors:
			push_error("SCRUM-979: %s" % error)
		quit(1)
		return
	print("SCRUM-979 Hero Select carousel window/pointer/gamepad test passed.")
	quit(0)


func _exercise_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	for _frame_index in range(6):
		await process_frame
	var context := str(viewport_size)
	var roster: Array = PROGRESSION_DATA.character_ids()
	var carousel := main.find_child("HS4Carousel", true, false) as Control
	var prev := main.find_child("HS4CarouselPrevButton", true, false) as Button
	var next := main.find_child("HS4CarouselNextButton", true, false) as Button
	var counter := main.find_child("HS4CarouselCounterLabel", true, false) as Label
	var name_label := main.find_child("HS4NameLabel", true, false) as Label
	if carousel == null or prev == null or next == null or counter == null or name_label == null:
		errors.append("%s missing carousel controls." % context)
		await _capture_teardown.release_viewport(self, viewport)
		return
	var slots := _visible_slots(carousel)
	var visible_count := slots.size()
	if visible_count < 3:
		errors.append("%s exposes only %d visible slots." % [context, visible_count])
		await _capture_teardown.release_viewport(self, viewport)
		return
	var max_offset := maxi(0, roster.size() - visible_count)
	_assert_arrow_geometry(carousel, prev, next, slots, viewport_size)
	_assert_window(main, carousel, counter, roster, 0, visible_count, 0, context + " initial")

	# The left edge is a focusable no-op and must never wrap to the roster tail.
	var initial_selection := str(main.get("selected_character_id"))
	await _pointer_click(viewport, prev, context + " left-edge")
	_assert_window(main, carousel, counter, roster, 0, visible_count, 0, context + " left-edge")
	if str(main.get("selected_character_id")) != initial_selection:
		errors.append("%s Previous wrapped selection at the left edge." % context)

	# One physical click must shift exactly one window immediately. No retry loop.
	await _pointer_click(viewport, next, context + " first-next")
	_assert_window(main, carousel, counter, roster, 1, visible_count, 0, context + " first-next")
	if visible_count >= 4:
		var expected_four := ["soldier", "thief", "elementalist", "sniper"]
		var actual_four := _visible_ids(carousel).slice(0, 4)
		if actual_four != expected_four:
			errors.append("%s required Soldier/Thief/Elementalist/Sniper slice mismatch: %s." % [context, str(actual_four)])

	# A direct slot click selects exactly that hero but does not move the window.
	var anchor := mini(2, visible_count - 1)
	var anchor_slot := slots[anchor] as Button
	var direct_id := str(anchor_slot.get_meta("character_id", ""))
	await _pointer_click(viewport, anchor_slot, context + " direct-slot")
	if int(carousel.get_meta("window_offset", -1)) != 1 or str(main.get("selected_character_id")) != direct_id:
		errors.append("%s direct slot click changed the window or selected the wrong hero." % context)
	var expected_title := str(PROGRESSION_DATA.character_config(direct_id).get("title", direct_id))
	if name_label.text != expected_title:
		errors.append("%s direct slot click did not refresh dossier title (%s vs %s)." % [context, name_label.text, expected_title])

	# Window movement preserves the selected visible-slot anchor in both directions.
	await _pointer_click(viewport, next, context + " anchored-next")
	_assert_window(main, carousel, counter, roster, 2, visible_count, anchor, context + " anchored-next")
	await _pointer_click(viewport, prev, context + " anchored-prev")
	_assert_window(main, carousel, counter, roster, 1, visible_count, anchor, context + " anchored-prev")

	# Every subsequent step is exact; at max the next action is a no-op/no-wrap.
	for expected_offset in range(2, max_offset + 1):
		next.pressed.emit()
		await process_frame
		_assert_window(main, carousel, counter, roster, expected_offset, visible_count, anchor, context + " step-right")
	var max_selection := str(main.get("selected_character_id"))
	await _pointer_click(viewport, next, context + " right-edge")
	if int(carousel.get_meta("window_offset", -1)) != max_offset or str(main.get("selected_character_id")) != max_selection:
		errors.append("%s Next wrapped or changed selection at the right edge." % context)

	# D-pad focus order remains Previous <-> slots <-> Next; A activates the
	# focused edge arrow without wrapping.
	slots = _visible_slots(carousel)
	(slots[0] as Button).grab_focus()
	await _push_dpad(viewport, JOY_BUTTON_DPAD_LEFT)
	if viewport.gui_get_focus_owner() != prev:
		errors.append("%s D-pad Left from first slot did not reach Previous." % context)
	await _push_dpad(viewport, JOY_BUTTON_DPAD_LEFT)
	if viewport.gui_get_focus_owner() != prev:
		errors.append("%s D-pad Left wrapped outward from Previous." % context)
	await _push_dpad(viewport, JOY_BUTTON_DPAD_RIGHT)
	if viewport.gui_get_focus_owner() != slots[0]:
		errors.append("%s D-pad Right from Previous did not return to first slot." % context)
	(slots.back() as Button).grab_focus()
	await _push_dpad(viewport, JOY_BUTTON_DPAD_RIGHT)
	if viewport.gui_get_focus_owner() != next:
		errors.append("%s D-pad Right from last slot did not reach Next." % context)
	await _push_dpad(viewport, JOY_BUTTON_DPAD_RIGHT)
	if viewport.gui_get_focus_owner() != next:
		errors.append("%s D-pad Right wrapped outward from Next." % context)
	await _push_joy_accept(viewport)
	if int(carousel.get_meta("window_offset", -1)) != max_offset or str(main.get("selected_character_id")) != max_selection:
		errors.append("%s gamepad A wrapped the focused right-edge arrow." % context)
	await _push_key(viewport, KEY_RIGHT)
	if viewport.gui_get_focus_owner() != next:
		errors.append("%s keyboard Right wrapped outward from Next." % context)
	await _push_key(viewport, KEY_ENTER)
	if int(carousel.get_meta("window_offset", -1)) != max_offset or str(main.get("selected_character_id")) != max_selection:
		errors.append("%s keyboard Enter changed the clamped right-edge window." % context)

	if DisplayServer.get_name() != "headless":
		_save_capture(viewport, viewport_size)
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for teardown_error in teardown_errors:
		errors.append("%s teardown: %s" % [context, teardown_error])


func _assert_window(main: Node, carousel: Control, counter: Label, roster: Array, offset: int, visible_count: int, anchor: int, context: String) -> void:
	var actual_offset := int(carousel.get_meta("window_offset", -1))
	if actual_offset != offset:
		errors.append("%s offset expected %d, got %d." % [context, offset, actual_offset])
		return
	var expected_ids := []
	for index in range(offset, mini(offset + visible_count, roster.size())):
		expected_ids.append(str(roster[index]))
	var actual_ids := _visible_ids(carousel)
	if actual_ids != expected_ids:
		errors.append("%s visible slice expected %s, got %s." % [context, str(expected_ids), str(actual_ids)])
	var expected_counter := "%d–%d из %d" % [offset + 1, offset + expected_ids.size(), roster.size()]
	if counter.text != expected_counter:
		errors.append("%s counter expected '%s', got '%s'." % [context, expected_counter, counter.text])
	var selected_index := roster.find(str(main.get("selected_character_id")))
	if selected_index - offset != anchor:
		errors.append("%s selected anchor expected %d, got %d (selected index %d)." % [context, anchor, selected_index - offset, selected_index])


func _assert_arrow_geometry(carousel: Control, prev: Button, next: Button, slots: Array, viewport_size: Vector2i) -> void:
	var min_width := 60.0 if viewport_size.y <= 720 else (72.0 if viewport_size.y <= 1080 else 90.0)
	var min_height := 80.0 if viewport_size.y <= 720 else (96.0 if viewport_size.y <= 1080 else 120.0)
	for button in [prev, next]:
		var rect := (button as Button).get_global_rect()
		if rect.size.x < min_width or rect.size.y < min_height:
			errors.append("%s arrow %s remains too small: %s." % [str(viewport_size), button.name, str(rect)])
		if not carousel.get_global_rect().grow(1.0).encloses(rect):
			errors.append("%s arrow %s escaped HS4Carousel." % [str(viewport_size), button.name])
		for slot in slots:
			if rect.intersects((slot as Button).get_global_rect(), true):
				errors.append("%s arrow %s overlaps %s." % [str(viewport_size), button.name, slot.name])
		var style := (button as Button).get_theme_stylebox("normal")
		var content_w := rect.size.x - style.content_margin_left - style.content_margin_right
		var content_h := rect.size.y - style.content_margin_top - style.content_margin_bottom
		if content_w < 24.0 or content_h < 36.0:
			errors.append("%s arrow %s has no safe glyph interior (%.1fx%.1f)." % [str(viewport_size), button.name, content_w, content_h])


func _visible_slots(carousel: Control) -> Array:
	var result := []
	for child in carousel.get_children():
		var button := child as Button
		if button != null and button.visible and button.name.begins_with("HS4CarouselSlot_"):
			result.append(button)
	return result


func _visible_ids(carousel: Control) -> Array:
	var result := []
	for slot in _visible_slots(carousel):
		result.append(str((slot as Button).get_meta("character_id", "")))
	return result


func _pointer_click(viewport: SubViewport, control: Control, context: String) -> void:
	var point := control.get_global_rect().get_center()
	var visible_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	if not visible_rect.grow(1.0).encloses(control.get_global_rect()) or not visible_rect.has_point(point):
		errors.append("%s pointer target is outside the physical viewport: %s." % [context, str(control.get_global_rect())])
		return
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		viewport.push_input(event, true)
		await process_frame
	await process_frame


func _push_dpad(viewport: SubViewport, button_index: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button_index
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		viewport.push_input(event)
		await process_frame


func _push_joy_accept(viewport: SubViewport) -> void:
	await _push_dpad(viewport, JOY_BUTTON_A)
	await process_frame


func _push_key(viewport: SubViewport, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		viewport.push_input(event)
		await process_frame


func _save_capture(viewport: SubViewport, viewport_size: Vector2i) -> void:
	var output_dir := ProjectSettings.globalize_path("res://build/qa/scrum979")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/carousel_window_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y])


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--user-data-dir="):
			requested = value.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-979 test requires isolated HOME/XDG and matching --user-data-dir (actual %s, requested %s)." % [actual, requested])
		return false
	return true
