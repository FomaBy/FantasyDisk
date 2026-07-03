extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1536, 864),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const PREVIEW_MIN_SIZE := 320.0
const SLOT_MIN_SIZE := 180.0
const SLOT_BASELINE_TOLERANCE := 3.0
const PREVIEW_VISIBLE_MIN_RATIO := 0.68
const SLOT_VISIBLE_HEIGHT_MIN_RATIO := 0.48
const LABEL_MIN_HEIGHT := 24.0


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _assert_layout_at_size(viewport_size)
	await _assert_directional_preview("berserk")
	await _assert_directional_preview("assassin")
	await _assert_directional_preview("chemist")
	await _assert_directional_preview("dark_mage")
	await _assert_directional_preview("biologist")
	await _assert_directional_preview("doctor")
	await _assert_directional_preview("druid")
	await _assert_directional_preview("elementalist")
	await _assert_directional_preview("engineer")
	await _assert_directional_preview("guitarist")
	await _assert_directional_preview("robot")
	await _assert_directional_preview("ranger")
	await _assert_directional_preview("sniper")
	await _assert_directional_preview("soldier")
	await _assert_directional_preview("thief")
	print("Hero Select PixelLab layout smoke test passed.")
	quit(0)


func _assert_layout_at_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.call("_show_character_select")
	await process_frame
	await process_frame

	var bg := main.find_child("HS4BlackBackground", true, false) as ColorRect
	if bg == null or bg.color != Color.BLACK:
		_fail("Expected Hero Select to use a pure black background at %s." % str(viewport_size))
		return
	if main.find_child("HS4Radar", true, false) != null or main.find_child("HS4RadarFrame", true, false) != null:
		_fail("Hero Select must not render the old stat radar/windrose at %s." % str(viewport_size))
		return
	if main.find_child("HS4PixelLabBackground", true, false) != null:
		_fail("Hero Select must not render the old PixelLab background at %s." % str(viewport_size))
		return

	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	var portrait_frame := main.find_child("HS4PortraitFrame", true, false) as Control
	if portrait == null or portrait.texture == null:
		_fail("Expected HS4Portrait texture at %s." % str(viewport_size))
		return
	if portrait_frame == null:
		_fail("Expected HS4PortraitFrame at %s." % str(viewport_size))
		return
	var portrait_frame_rect := portrait_frame.get_global_rect()
	if portrait_frame_rect.size.x < PREVIEW_MIN_SIZE or portrait_frame_rect.size.y < PREVIEW_MIN_SIZE:
		_fail("Expected HS4PortraitFrame to use enlarged footprint at %s, got %s." % [str(viewport_size), str(portrait_frame_rect.size)])
		return
	var portrait_visible_rect := _visible_alpha_global_rect(portrait)
	if portrait_visible_rect.size.y < portrait_frame_rect.size.y * PREVIEW_VISIBLE_MIN_RATIO:
		_fail("Expected selected preview visible silhouette to be enlarged at %s, got visible %s in frame %s." % [str(viewport_size), str(portrait_visible_rect), str(portrait_frame_rect)])
		return
	if not portrait_frame_rect.grow(4.0).encloses(portrait_visible_rect):
		_fail("Expected selected preview visible silhouette to stay inside clipped frame at %s, got visible %s frame %s." % [str(viewport_size), str(portrait_visible_rect), str(portrait_frame_rect)])
		return
	var preview_expected_bottom := portrait_frame_rect.end.y - maxf(6.0, roundf(portrait_frame_rect.size.y * 0.025))
	if absf(portrait_visible_rect.end.y - preview_expected_bottom) > 4.0:
		_fail("Expected selected preview visible bottom alignment at %s; got %.2f vs %.2f." % [str(viewport_size), portrait_visible_rect.end.y, preview_expected_bottom])
		return

	var ascension := main.find_child("HS4AscensionFrame", true, false) as Control
	var choose := main.find_child("HS4ChooseButton", true, false) as Button
	var asc_mods := main.find_child("AscensionModsLabel", true, false) as Label
	if ascension == null or choose == null or asc_mods == null or asc_mods.text.strip_edges() == "":
		_fail("Expected visible ascension chooser with description at %s." % str(viewport_size))
		return

	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		var stat_button := main.find_child("HS4Stat_%s" % stat_id, true, false) as Button
		var stat_bar := main.find_child("HS4StatBarFill_%s" % stat_id, true, false) as ColorRect
		if stat_button == null or stat_bar == null or stat_button.tooltip_text.strip_edges() == "" or not stat_button.tooltip_text.contains(" — ") or stat_button.tooltip_text.contains("Формула:"):
			_fail("Expected line bar + concise hover tooltip for base stat %s at %s." % [stat_id, str(viewport_size)])
			return
	for relevance in ["primary", "secondary", "optional"]:
		var guidance := main.find_child("HS4BuildGuidance_%s" % relevance, true, false) as Label
		if guidance == null or guidance.text.strip_edges() == "":
			_fail("Expected data-driven build guidance section %s at %s." % [relevance, str(viewport_size)])
			return

	var carousel := main.find_child("HS4Carousel", true, false) as Control
	if carousel == null:
		_fail("Expected HS4Carousel at %s." % str(viewport_size))
		return
	var visible_slots := []
	for child in carousel.get_children():
		var slot := child as Button
		if slot == null or not slot.visible or not slot.name.begins_with("HS4CarouselSlot_"):
			continue
		if slot.get_global_rect().size.x < SLOT_MIN_SIZE or slot.get_global_rect().size.y < SLOT_MIN_SIZE:
			_fail("Expected enlarged carousel slot at %s, got %s." % [str(viewport_size), str(slot.get_global_rect().size)])
			return
		var slot_portrait := slot.find_child("HS4CarouselPortrait_*", false, false) as TextureRect
		if slot_portrait == null or slot_portrait.texture == null:
			_fail("Expected carousel portrait child inside %s at %s." % [slot.name, str(viewport_size)])
			return
		var slot_label := slot.find_child("HS4CarouselLabel_*", false, false) as Label
		if slot_label == null or slot_label.text.strip_edges() == "":
			_fail("Expected readable carousel label inside %s at %s." % [slot.name, str(viewport_size)])
			return
		if not slot.clip_contents:
			_fail("Expected carousel slot to clip bottom-aligned portrait overflow at %s." % str(viewport_size))
			return
		var slot_rect := slot.get_global_rect()
		var label_rect := slot_label.get_global_rect()
		if label_rect.size.y < LABEL_MIN_HEIGHT or not slot_rect.grow(2.0).encloses(label_rect):
			_fail("Expected carousel label to stay inside slot at %s, got label %s slot %s." % [str(viewport_size), str(label_rect), str(slot_rect)])
			return
		var visible_rect := _visible_alpha_global_rect(slot_portrait)
		var portrait_area_h := label_rect.position.y - slot_rect.position.y
		if visible_rect.size.y < maxf(slot_rect.size.y * SLOT_VISIBLE_HEIGHT_MIN_RATIO, portrait_area_h * 0.54):
			_fail("Expected carousel visible silhouette to be enlarged/cropped at %s, got visible %s slot %s label %s." % [str(viewport_size), str(visible_rect), str(slot_rect), str(label_rect)])
			return
		if not Rect2(slot_rect.position, Vector2(slot_rect.size.x, portrait_area_h)).grow(4.0).encloses(visible_rect):
			_fail("Expected carousel visible silhouette to stay in portrait area above label at %s, got visible %s slot %s label %s." % [str(viewport_size), str(visible_rect), str(slot_rect), str(label_rect)])
			return
		var expected_bottom := label_rect.position.y - maxf(3.0, roundf(slot_rect.size.y * 0.02))
		if absf(visible_rect.end.y - expected_bottom) > SLOT_BASELINE_TOLERANCE:
			_fail("Expected carousel portrait visible bottoms to align above label at %s; got %.2f vs %.2f." % [str(viewport_size), visible_rect.end.y, expected_bottom])
			return
		visible_slots.append(slot)
	if visible_slots.size() < 3:
		_fail("Expected at least 3 visible enlarged carousel slots at %s, got %d." % [str(viewport_size), visible_slots.size()])
		return

	var portrait_rect := portrait_frame.get_global_rect()
	var dossier_rect := (main.find_child("HS4DossierFrame", true, false) as Control).get_global_rect()
	var asc_rect := ascension.get_global_rect()
	var carousel_rect := carousel.get_global_rect()
	for pair in [[portrait_rect, dossier_rect], [dossier_rect, asc_rect], [portrait_rect, carousel_rect], [asc_rect, carousel_rect]]:
		if (pair[0] as Rect2).grow(-2.0).intersects((pair[1] as Rect2).grow(-2.0)):
			_fail("Expected major Hero Select zones not to overlap at %s." % str(viewport_size))
			return

	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_directional_preview(character_id: String) -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", character_id)
	main.call("_show_character_select")
	await process_frame
	await process_frame

	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	if portrait == null or portrait.texture == null:
		_fail("Expected %s Hero Select preview texture." % character_id)
		return
	var first_texture := portrait.texture
	if first_texture.get_size() != Vector2(512, 512):
		_fail("Expected %s Hero Select preview to use actual 512x512 PixelLab frame, got %s." % [character_id, str(first_texture.get_size())])
		return
	await create_timer(0.24).timeout
	if portrait.texture == null or portrait.texture == first_texture:
		_fail("Expected %s Hero Select preview to rotate through directional frames." % character_id)
		return
	main.queue_free()
	await process_frame


func _size_close(actual: Vector2, expected: Vector2, tolerance: float) -> bool:
	return absf(actual.x - expected.x) <= tolerance and absf(actual.y - expected.y) <= tolerance


func _alpha_bbox(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.02:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(Vector2(float(min_x), float(min_y)), Vector2(float(max_x - min_x + 1), float(max_y - min_y + 1)))


func _visible_alpha_global_rect(texture_rect: TextureRect) -> Rect2:
	if texture_rect == null or texture_rect.texture == null:
		return Rect2()
	var texture := texture_rect.texture
	var texture_size := texture.get_size()
	var control_rect := texture_rect.get_global_rect()
	var draw_scale := minf(control_rect.size.x / texture_size.x, control_rect.size.y / texture_size.y)
	var draw_size := texture_size * draw_scale
	var draw_origin := control_rect.position + (control_rect.size - draw_size) * 0.5
	var bbox := _alpha_bbox(texture)
	return Rect2(draw_origin + bbox.position * draw_scale, bbox.size * draw_scale)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
