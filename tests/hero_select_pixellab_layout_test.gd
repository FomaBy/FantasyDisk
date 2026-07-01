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


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _assert_layout_at_size(viewport_size)
	await _assert_directional_preview("berserk")
	await _assert_directional_preview("chemist")
	await _assert_directional_preview("dark_mage")
	await _assert_directional_preview("doctor")
	await _assert_directional_preview("druid")
	await _assert_directional_preview("engineer")
	await _assert_directional_preview("guitarist")
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
	if portrait == null or portrait.texture == null:
		_fail("Expected HS4Portrait texture at %s." % str(viewport_size))
		return
	if portrait.get_global_rect().size.x < PREVIEW_MIN_SIZE or portrait.get_global_rect().size.y < PREVIEW_MIN_SIZE:
		_fail("Expected HS4Portrait to use enlarged SCRUM-798 footprint at %s, got %s." % [str(viewport_size), str(portrait.get_global_rect().size)])
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
		if stat_button == null or stat_bar == null or stat_button.tooltip_text.strip_edges() == "" or not stat_button.tooltip_text.contains("Формула:") or not stat_button.tooltip_text.contains("Интерпретация класса:"):
			_fail("Expected line bar + rich hover tooltip for base stat %s at %s." % [stat_id, str(viewport_size)])
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
		if not slot.get_global_rect().encloses(slot_portrait.get_global_rect()):
			_fail("Expected carousel portrait to stay inside 150x150 slot at %s." % str(viewport_size))
			return
		visible_slots.append(slot)
	if visible_slots.size() < 3:
		_fail("Expected at least 3 visible enlarged carousel slots at %s, got %d." % [str(viewport_size), visible_slots.size()])
		return

	var portrait_rect := portrait.get_global_rect()
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
