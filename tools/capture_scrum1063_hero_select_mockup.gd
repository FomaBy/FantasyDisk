extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const VIEWPORTS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const OUTPUT_DIR := "res://docs/design/previews/scrum1063_hero_carousel_wide_buttons"

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _capture(viewport_size)
	await _capture_teardown.release_windowed_audio(self)
	print("SCRUM-1063 pre-runtime PixelLab-source mockup matrix captured.")
	quit(0)


func _capture(viewport_size: Vector2i) -> void:
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
	for _frame_index in range(7):
		await process_frame

	var carousel := main.find_child("HS4Carousel", true, false) as Control
	var prev := main.find_child("HS4CarouselPrevButton", true, false) as Button
	var next := main.find_child("HS4CarouselNextButton", true, false) as Button
	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var dossier := main.find_child("HS4DossierFrame", true, false) as Control
	var asc_row := main.find_child("HS4AscensionActionRow", true, false) as HBoxContainer
	var asc_minus := main.find_child("AscensionMinusButton", true, false) as Button
	var asc_value := main.find_child("HS4AscensionValue", true, false) as Label
	var asc_plus := main.find_child("AscensionPlusButton", true, false) as Button
	var asc_description := main.find_child("HS4AscensionDescriptionScroll", true, false) as Control
	if carousel == null or prev == null or next == null or ascension == null \
			or dossier == null or asc_row == null or asc_minus == null \
			or asc_value == null or asc_plus == null or asc_description == null:
		push_error("SCRUM-1063 mockup capture is missing Hero Select controls.")
		quit(1)
		return

	var slots: Array[Button] = []
	for child in carousel.get_children():
		var slot := child as Button
		if slot != null and slot.visible and slot.name.begins_with("HS4CarouselSlot_"):
			slots.append(slot)
	if slots.size() < 3:
		push_error("SCRUM-1063 mockup requires at least three current slots.")
		quit(1)
		return

	var former_width := float(prev.get_meta("former_responsive_width", 0.0))
	var arrow_h := prev.size.y if former_width > 0.0 else clampf(roundf(slots[0].size.y * 0.52), 84.0, 140.0)
	var wide_size := Vector2(former_width * 2.0, arrow_h) if former_width > 0.0 else Vector2(roundf(arrow_h * 1.5), arrow_h)
	# The fixed outer gold shell leaves a narrower right column at the two compact
	# targets. The accepted contract prioritizes three complete slots over the old
	# 180 px floor, so the compact mockup scales the whole square card uniformly.
	var compact_slot_cap := 116.0 if viewport_size.y <= 648 else (132.0 if viewport_size.y <= 720 else slots[0].size.x)
	var display_slot_side := minf(slots[0].size.x, compact_slot_cap)
	var visible_count := clampi(
		int(floor((carousel.size.x - wide_size.x * 2.0 - 6.0) / (display_slot_side + 6.0))),
		3,
		slots.size())
	var slot_gap := maxf(6.0, (
		carousel.size.x - wide_size.x * 2.0 - display_slot_side * float(visible_count)
	) / float(visible_count + 1))
	for index in range(slots.size()):
		var slot := slots[index]
		slot.visible = index < visible_count
		if slot.visible:
			var slot_scale := display_slot_side / maxf(slot.size.x, 1.0)
			slot.scale = Vector2(slot_scale, slot_scale)
			slot.position = Vector2(
				wide_size.x + slot_gap + index * (display_slot_side + slot_gap),
				roundf((carousel.size.y - display_slot_side) * 0.5))
	var arrow_y := roundf((carousel.size.y - wide_size.y) * 0.5)
	prev.position = Vector2.ZERO + Vector2(0.0, arrow_y)
	next.position = Vector2(carousel.size.x - wide_size.x, arrow_y)

	var panel_style := ascension.get_theme_stylebox("panel")
	var top_pad := panel_style.get_content_margin(SIDE_TOP) if panel_style != null else 6.0
	var bottom_pad := panel_style.get_content_margin(SIDE_BOTTOM) if panel_style != null else 6.0
	var old_bottom := ascension.position.y + ascension.size.y
	var required_h := maxf(ascension.size.y, wide_size.y + top_pad + bottom_pad)
	ascension.position.y = old_bottom - required_h
	ascension.size.y = required_h
	dossier.size.y = maxf(0.0, ascension.position.y - dossier.position.y - 2.0)
	asc_description.visible = false
	asc_value.text = "Возвышение 5"
	asc_value.custom_minimum_size = Vector2(maxf(172.0, roundf(220.0 * viewport_size.y / 1080.0)), wide_size.y)
	asc_row.add_theme_constant_override("separation", maxi(10, int(roundf(wide_size.x * 0.10))))

	for entry in [[prev, "‹"], [next, "›"], [asc_minus, "−"], [asc_plus, "+"]]:
		var button := entry[0] as Button
		button.text = str(entry[1])
		button.size = wide_size
		button.custom_minimum_size = wide_size
		button.add_theme_stylebox_override("normal", main.ui.call("_hs4_pixellab_style", "asc_minus", wide_size, Color.WHITE))
		button.add_theme_stylebox_override("hover", main.ui.call("_hs4_pixellab_style", "asc_minus", wide_size, Color(1.08, 1.04, 0.92, 1.0)))
		button.add_theme_stylebox_override("focus", main.ui.call("_hs4_pixellab_style", "asc_minus", wide_size, Color(1.08, 1.04, 0.92, 1.0)))
		button.add_theme_stylebox_override("pressed", main.ui.call("_hs4_pixellab_style", "asc_minus", wide_size, Color(0.82, 0.76, 0.66, 1.0)))
		button.add_theme_stylebox_override("disabled", main.ui.call("_hs4_pixellab_style", "asc_minus", wide_size, Color(0.46, 0.46, 0.50, 0.72)))
		button.add_theme_font_size_override("font_size", clampi(int(roundf(wide_size.y * 0.28)), 20, 38))
	asc_row.size = asc_row.get_combined_minimum_size()
	asc_row.position = Vector2(
		roundf((ascension.size.x - asc_row.size.x) * 0.5),
		roundf((ascension.size.y - asc_row.size.y) * 0.5))

	for _frame_index in range(5):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("SCRUM-1063 mockup capture returned an empty image.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	image.save_png("%s/hero_select_wide_buttons_mockup_%dx%d.png" % [
		ProjectSettings.globalize_path(OUTPUT_DIR), viewport_size.x, viewport_size.y])
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		push_error("SCRUM-1063 mockup teardown failed: %s" % "; ".join(teardown_errors))
		quit(1)
