extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1152, 648),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

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
			push_error("SCRUM-1063: %s" % error)
		quit(1)
		return
	print("SCRUM-1063 Hero Select wide-control/cyclic-wrap test passed.")
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
	var unlocked := {}
	for character_id in PROGRESSION_DATA.character_ids():
		unlocked[str(character_id)] = 4
	var meta_state: Dictionary = main.get("meta_state")
	meta_state["ascension_levels"] = unlocked
	main.set("meta_state", meta_state)
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	for _frame_index in range(8):
		await process_frame

	var context := str(viewport_size)
	var roster: Array = PROGRESSION_DATA.character_ids()
	var carousel := main.find_child("HS4Carousel", true, false) as Control
	var prev := main.find_child("HS4CarouselPrevButton", true, false) as Button
	var next := main.find_child("HS4CarouselNextButton", true, false) as Button
	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var asc_row := main.find_child("HS4AscensionActionRow", true, false) as Control
	var minus := main.find_child("AscensionMinusButton", true, false) as Button
	var value := main.find_child("HS4AscensionValue", true, false) as Label
	var plus := main.find_child("AscensionPlusButton", true, false) as Button
	var description_scroll := main.find_child("HS4AscensionDescriptionScroll", true, false) as ScrollContainer
	var description := main.find_child("AscensionModsLabel", true, false) as Label
	var counter := main.find_child("HS4CarouselCounterLabel", true, false) as Label
	var name_label := main.find_child("HS4NameLabel", true, false) as Label
	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	if carousel == null or prev == null or next == null or ascension == null \
			or asc_row == null or minus == null or value == null or plus == null \
			or description_scroll == null or description == null or counter == null \
			or name_label == null or portrait == null:
		errors.append("%s missing required Hero Select controls." % context)
		await _teardown(viewport)
		return

	var slots := _visible_slots(carousel)
	if slots.size() < 3:
		errors.append("%s exposes only %d visible slots." % [context, slots.size()])
		await _teardown(viewport)
		return
	_assert_geometry(viewport_size, carousel, ascension, asc_row, slots, [prev, next, minus, plus], value)
	_assert_ascension_copy(main, ascension, minus, value, plus, description_scroll, description, context)

	var max_level := int(main.call("ascension_selectable_max", "berserk"))
	for _step in range(max_level):
		minus.pressed.emit()
		await process_frame
	if int(main.get("selected_ascension_level")) != 0 or value.text != "Возвышение 0" or not minus.disabled or plus.disabled:
		errors.append("%s Ascension lower bound/state is incorrect: %s, minus=%s plus=%s." % [context, value.text, minus.disabled, plus.disabled])
	for _step in range(max_level):
		plus.pressed.emit()
		await process_frame
	if int(main.get("selected_ascension_level")) != max_level or value.text != "Возвышение %d" % max_level or minus.disabled or not plus.disabled:
		errors.append("%s Ascension upper bound/state is incorrect: %s, minus=%s plus=%s." % [context, value.text, minus.disabled, plus.disabled])

	# Pointer: first window/hero -> last hero/final window -> first hero/window.
	await _pointer_click(viewport, prev, context + " pointer Previous")
	_assert_wrap_state(main, carousel, counter, name_label, portrait, roster, false, context + " pointer first->last")
	await _pointer_click(viewport, next, context + " pointer Next")
	_assert_wrap_state(main, carousel, counter, name_label, portrait, roster, true, context + " pointer last->first")

	# Preserve SCRUM-979's useful ordinary movement contract between the cyclic
	# edges: selected visible-slot anchor moves one window step in both directions.
	var ordinary_slots := _visible_slots(carousel)
	var ordinary_anchor := mini(1, ordinary_slots.size() - 1)
	await _pointer_click(viewport, ordinary_slots[ordinary_anchor] as Button, context + " ordinary anchor slot")
	var anchored_id := str((ordinary_slots[ordinary_anchor] as Button).get_meta("character_id", ""))
	await _pointer_click(viewport, next, context + " ordinary Next")
	var expected_next_id := str(roster[ordinary_anchor + 1])
	if int(carousel.get_meta("window_offset", -1)) != 1 or str(main.get("selected_character_id")) != expected_next_id:
		errors.append("%s ordinary Next did not preserve anchor %d (%s -> %s)." % [context, ordinary_anchor, anchored_id, expected_next_id])
	await _pointer_click(viewport, prev, context + " ordinary Previous")
	if int(carousel.get_meta("window_offset", -1)) != 0 or str(main.get("selected_character_id")) != anchored_id:
		errors.append("%s ordinary Previous did not restore anchor %d/%s." % [context, ordinary_anchor, anchored_id])
	ordinary_slots = _visible_slots(carousel)
	await _pointer_click(viewport, ordinary_slots[0] as Button, context + " restore first hero")

	# Physical keyboard Enter activates the focused arrows through the same path.
	prev.grab_focus()
	await _push_key(viewport, KEY_ENTER)
	_assert_wrap_state(main, carousel, counter, name_label, portrait, roster, false, context + " keyboard first->last")
	next.grab_focus()
	await _push_key(viewport, KEY_ENTER)
	_assert_wrap_state(main, carousel, counter, name_label, portrait, roster, true, context + " keyboard last->first")

	# Raw gamepad A plus cyclic D-pad focus at both outward row edges.
	prev.grab_focus()
	await _push_joy_button(viewport, JOY_BUTTON_A)
	_assert_wrap_state(main, carousel, counter, name_label, portrait, roster, false, context + " gamepad first->last")
	next.grab_focus()
	await _push_joy_button(viewport, JOY_BUTTON_A)
	_assert_wrap_state(main, carousel, counter, name_label, portrait, roster, true, context + " gamepad last->first")
	prev.grab_focus()
	await _push_joy_button(viewport, JOY_BUTTON_DPAD_LEFT)
	if viewport.gui_get_focus_owner() != next:
		errors.append("%s D-pad Left did not wrap Previous focus to Next." % context)
	await _push_joy_button(viewport, JOY_BUTTON_DPAD_RIGHT)
	if viewport.gui_get_focus_owner() != prev:
		errors.append("%s D-pad Right did not wrap Next focus to Previous." % context)

	# Direct visible choice keeps the window and uses the same detail refresh.
	slots = _visible_slots(carousel)
	var direct_slot := slots[mini(1, slots.size() - 1)] as Button
	var direct_id := str(direct_slot.get_meta("character_id", ""))
	var direct_offset := int(carousel.get_meta("window_offset", -1))
	await _pointer_click(viewport, direct_slot, context + " direct slot")
	if str(main.get("selected_character_id")) != direct_id or int(carousel.get_meta("window_offset", -1)) != direct_offset:
		errors.append("%s direct slot did not preserve its window/exact selection." % context)
	var direct_title := str(PROGRESSION_DATA.character_config(direct_id).get("title", direct_id))
	if name_label.text != direct_title:
		errors.append("%s direct slot did not refresh dossier (%s vs %s)." % [context, name_label.text, direct_title])
	print("SCRUM-1063 wrap %s: pointer/keyboard/gamepad first<->last PASS; direct slot PASS." % context)

	if DisplayServer.get_name() != "headless":
		var output_dir := ProjectSettings.globalize_path("res://build/qa/scrum1063")
		DirAccess.make_dir_recursive_absolute(output_dir)
		var image := viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png("%s/hero_select_wide_controls_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y])
	await _teardown(viewport)


func _assert_geometry(
	viewport_size: Vector2i,
	carousel: Control,
	ascension: Control,
	asc_row: Control,
	slots: Array,
	buttons: Array,
	value: Label
) -> void:
	var context := str(viewport_size)
	var first_size := (buttons[0] as Button).get_global_rect().size
	var expected_size := Vector2.ZERO
	if viewport_size == Vector2i(1152, 648) or viewport_size == Vector2i(1280, 720):
		expected_size = Vector2(142.0, 94.0)
	elif viewport_size == Vector2i(1920, 1080):
		expected_size = Vector2(150.0, 100.0)
	elif viewport_size == Vector2i(2560, 1440):
		expected_size = Vector2(202.0, 134.0)
	if first_size.distance_to(expected_size) > 0.5:
		errors.append("%s wide-control spec size expected %s, got %s." % [context, expected_size, first_size])
	var source_path := str((buttons[0] as Button).get_meta("hero_wide_control_source", ""))
	for button_variant in buttons:
		var button := button_variant as Button
		var rect := button.get_global_rect()
		var former_width := float(button.get_meta("former_responsive_width", 0.0))
		if absf(rect.size.x - former_width * 2.0) > 0.5:
			errors.append("%s %s width %.2f is not exact 2x former %.2f." % [context, button.name, rect.size.x, former_width])
		if rect.size.distance_to(first_size) > 0.5:
			errors.append("%s %s size %s differs from unified %s." % [context, button.name, rect.size, first_size])
		if str(button.get_meta("hero_wide_control_source", "")) != source_path:
			errors.append("%s %s does not use the unified PixelLab source." % [context, button.name])
		var normal_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		if normal_style == null:
			errors.append("%s %s has no normal StyleBoxTexture." % [context, button.name])
			continue
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := button.get_theme_stylebox(state_name) as StyleBoxTexture
			if style == null or style.texture == null or style.texture.resource_path != source_path:
				errors.append("%s %s/%s is not the unified source." % [context, button.name, state_name])
				continue
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				if absf(style.get_content_margin(side) - normal_style.get_content_margin(side)) > 0.1 \
						or absf(style.get_texture_margin(side) - normal_style.get_texture_margin(side)) > 0.1:
					errors.append("%s %s/%s changes safe/texture margins." % [context, button.name, state_name])
		var safe_w := rect.size.x - normal_style.content_margin_left - normal_style.content_margin_right
		var safe_h := rect.size.y - normal_style.content_margin_top - normal_style.content_margin_bottom
		if safe_w < 48.0 or safe_h < 36.0:
			errors.append("%s %s glyph content zone is too small: %.1fx%.1f." % [context, button.name, safe_w, safe_h])
	var carousel_rect := carousel.get_global_rect()
	for button in [buttons[0], buttons[1]]:
		var rect := (button as Button).get_global_rect()
		if not carousel_rect.grow(1.0).encloses(rect):
			errors.append("%s %s escapes the carousel." % [context, (button as Button).name])
		for slot_variant in slots:
			if rect.grow(-1.0).intersects((slot_variant as Button).get_global_rect().grow(-1.0)):
				errors.append("%s %s overlaps %s." % [context, (button as Button).name, (slot_variant as Button).name])
	var asc_rect := ascension.get_global_rect()
	var row_rect := asc_row.get_global_rect()
	if not asc_rect.grow(1.0).encloses(row_rect):
		errors.append("%s Ascension row escapes its frame: %s in %s." % [context, row_rect, asc_rect])
	var minus_rect := (buttons[2] as Button).get_global_rect()
	var plus_rect := (buttons[3] as Button).get_global_rect()
	var value_rect := value.get_global_rect()
	var midpoint := (minus_rect.get_center().x + plus_rect.get_center().x) * 0.5
	print("SCRUM-1063 rect %s: wide=%s former_w=%.0f slots=%d first_slot=%s ascension=%s center_delta=%.2f" % [
		context,
		str(first_size),
		float((buttons[0] as Button).get_meta("former_responsive_width", 0.0)),
		slots.size(),
		str((slots[0] as Button).get_global_rect().size),
		str(asc_rect.size),
		absf(value_rect.get_center().x - midpoint),
	])
	if absf(value_rect.get_center().x - midpoint) > 1.0:
		errors.append("%s Ascension value center %.2f differs from button midpoint %.2f." % [context, value_rect.get_center().x, midpoint])
	if minus_rect.grow(-1.0).intersects(value_rect.grow(-1.0)) or value_rect.grow(-1.0).intersects(plus_rect.grow(-1.0)):
		errors.append("%s Ascension controls overlap." % context)


func _assert_ascension_copy(
	main: Node,
	ascension: Control,
	minus: Button,
	value: Label,
	plus: Button,
	description_scroll: ScrollContainer,
	description: Label,
	context: String
) -> void:
	var level := int(main.get("selected_ascension_level"))
	if value.text != "Возвышение %d" % level or value.text.contains("/"):
		errors.append("%s visible Ascension copy is invalid: `%s`." % [context, value.text])
	if description_scroll.visible or description.visible:
		errors.append("%s long Ascension modifier lane is still visible." % context)
	var tooltip := ascension.tooltip_text
	if tooltip.strip_edges() == "" or value.tooltip_text != tooltip or minus.tooltip_text != tooltip or plus.tooltip_text != tooltip:
		errors.append("%s current cumulative modifiers are not unified in tooltips." % context)


func _assert_wrap_state(
	main: Node,
	carousel: Control,
	counter: Label,
	name_label: Label,
	portrait: TextureRect,
	roster: Array,
	expect_first: bool,
	context: String
) -> void:
	await process_frame
	var visible_count := int(carousel.get_meta("visible_slot_count", 0))
	var max_offset := maxi(0, roster.size() - visible_count)
	var expected_id := str(roster[0] if expect_first else roster.back())
	var expected_offset := 0 if expect_first else max_offset
	if str(main.get("selected_character_id")) != expected_id or int(carousel.get_meta("window_offset", -1)) != expected_offset:
		errors.append("%s expected %s at offset %d, got %s/%d." % [context, expected_id, expected_offset, str(main.get("selected_character_id")), int(carousel.get_meta("window_offset", -1))])
	var expected_title := str(PROGRESSION_DATA.character_config(expected_id).get("title", expected_id))
	var expected_portrait_path := str(PROGRESSION_DATA.character_config(expected_id).get("sprite_path", PROGRESSION_DATA.character_config(expected_id).get("sprite", "")))
	var live_portrait_path := portrait.texture.resource_path if portrait.texture != null else ""
	var portrait_matches := live_portrait_path == expected_portrait_path \
		or live_portrait_path.contains("/%s_" % expected_id) \
		or live_portrait_path.contains("/%s/" % expected_id)
	if name_label.text != expected_title or portrait.texture == null or not portrait_matches:
		errors.append("%s did not synchronize dossier/portrait." % context)
	var ascension_value := main.find_child("HS4AscensionValue", true, false) as Label
	var expected_level := int(main.call("ascension_selectable_max", expected_id))
	if ascension_value == null or ascension_value.text != "Возвышение %d" % expected_level:
		errors.append("%s did not synchronize Ascension value for %s." % [context, expected_id])
	var expected_stats: Dictionary = PROGRESSION_DATA.base_stats(expected_id)
	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		var stat_value := main.find_child("HS4StatValue_%s" % stat_id, true, false) as Label
		if stat_value == null or stat_value.text != str(int(round(float(expected_stats.get(stat_id, 0.0))))):
			errors.append("%s did not synchronize stat %s for %s." % [context, stat_id, expected_id])
	var first := expected_offset + 1
	var last := mini(expected_offset + visible_count, roster.size())
	if counter.text != "%d–%d из %d" % [first, last, roster.size()]:
		errors.append("%s counter mismatch: `%s`." % [context, counter.text])


func _visible_slots(carousel: Control) -> Array:
	var result := []
	for child in carousel.get_children():
		var button := child as Button
		if button != null and button.visible and button.name.begins_with("HS4CarouselSlot_"):
			result.append(button)
	return result


func _pointer_click(viewport: SubViewport, control: Control, context: String) -> void:
	var point := control.get_global_rect().get_center()
	var viewport_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	if not viewport_rect.grow(1.0).encloses(control.get_global_rect()) or not viewport_rect.has_point(point):
		errors.append("%s target is outside the viewport: %s." % [context, control.get_global_rect()])
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


func _push_key(viewport: SubViewport, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		viewport.push_input(event)
		await process_frame


func _push_joy_button(viewport: SubViewport, button_index: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button_index
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		viewport.push_input(event)
		await process_frame


func _teardown(viewport: SubViewport) -> void:
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for teardown_error in teardown_errors:
		errors.append("teardown: %s" % teardown_error)


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--user-data-dir="):
			requested = value.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-1063 test requires isolated HOME/XDG/user-data (actual %s, requested %s)." % [actual, requested])
		return false
	return true
