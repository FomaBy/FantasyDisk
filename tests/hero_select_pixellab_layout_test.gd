extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FRAME_DIR := "res://assets/sprites/ui/frames/hero_select_pixellab/"
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(2560, 1440),
]


func _initialize() -> void:
	for viewport_size in VIEWPORTS:
		await _assert_layout_at_size(viewport_size)
	await _assert_directional_preview("berserk")
	await _assert_directional_preview("dark_mage")
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

	_assert_texture_rect_path(main, "HS4PixelLabBackground", FRAME_DIR + "background.png")
	_assert_panel_path(main, "HS4TitleFrame", FRAME_DIR + "frame_title.png")
	_assert_panel_path(main, "HS4PortraitFrame", FRAME_DIR + "frame_portrait.png")
	_assert_panel_path(main, "HS4DossierFrame", FRAME_DIR + "frame_dossier.png")
	_assert_panel_path(main, "HS4RadarFrame", FRAME_DIR + "frame_radar.png")
	_assert_panel_path(main, "HS4AscensionFrame", FRAME_DIR + "frame_ascension.png")
	_assert_panel_path(main, "HS4CarouselFrame", FRAME_DIR + "frame_carousel.png")
	_assert_button_path(main, "HS4BackButton", FRAME_DIR + "button_back.png")
	_assert_button_path(main, "HS4ChooseButton", FRAME_DIR + "button_choose.png")
	_assert_button_path(main, "AscensionMinusButton", FRAME_DIR + "button_asc_minus.png")
	_assert_button_path(main, "AscensionPlusButton", FRAME_DIR + "button_asc_plus.png")
	_assert_button_path(main, "HS4CarouselPrevButton", FRAME_DIR + "button_carousel_left.png")
	_assert_button_path(main, "HS4CarouselNextButton", FRAME_DIR + "button_carousel_right.png")

	var carousel := main.find_child("HS4Carousel", true, false) as Control
	if carousel == null:
		_fail("Expected HS4Carousel at %s." % str(viewport_size))
		return
	var visible_slots := []
	for child in carousel.get_children():
		var slot := child as TextureButton
		if slot == null or not slot.visible:
			continue
		if slot.texture_normal == null or slot.texture_normal.resource_path != FRAME_DIR + "frame_hero_slot.png":
			_fail("Expected framed PixelLab hero slot at %s, got %s." % [str(viewport_size), slot.texture_normal.resource_path if slot.texture_normal != null else "<null>"])
			return
		var portrait := slot.find_child("HS4CarouselPortrait_*", false, false) as TextureRect
		if portrait == null or portrait.texture == null:
			_fail("Expected carousel slot portrait child inside %s at %s." % [slot.name, str(viewport_size)])
			return
		if not slot.get_global_rect().encloses(portrait.get_global_rect()):
			_fail("Expected carousel portrait to stay inside slot frame at %s." % str(viewport_size))
			return
		visible_slots.append(slot)
	if visible_slots.size() != 9:
		_fail("Expected 9 visible Hero Select slots at %s, got %d." % [str(viewport_size), visible_slots.size()])
		return

	var portrait_rect := (main.find_child("HS4Portrait", true, false) as Control).get_global_rect()
	var radar_rect := (main.find_child("HS4Radar", true, false) as Control).get_global_rect()
	var asc_rect := (main.find_child("HS4AscensionFrame", true, false) as Control).get_global_rect()
	var carousel_rect := carousel.get_global_rect()
	for pair in [[portrait_rect, radar_rect], [portrait_rect, carousel_rect], [radar_rect, asc_rect], [asc_rect, carousel_rect]]:
		if (pair[0] as Rect2).grow(-2.0).intersects((pair[1] as Rect2).grow(-2.0)):
			_fail("Expected major Hero Select PixelLab zones not to overlap at %s." % str(viewport_size))
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


func _assert_texture_rect_path(main: Node, node_name: String, expected_path: String) -> void:
	var rect := main.find_child(node_name, true, false) as TextureRect
	if rect == null or rect.texture == null or rect.texture.resource_path != expected_path:
		_fail("Expected %s to use %s." % [node_name, expected_path])


func _assert_panel_path(main: Node, node_name: String, expected_path: String) -> void:
	var panel := main.find_child(node_name, true, false) as Panel
	if panel == null:
		_fail("Expected panel %s." % node_name)
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null or style.texture.resource_path != expected_path:
		_fail("Expected %s to use %s." % [node_name, expected_path])


func _assert_button_path(main: Node, node_name: String, expected_path: String) -> void:
	var button := main.find_child(node_name, true, false) as Button
	if button == null:
		_fail("Expected button %s." % node_name)
		return
	var style := button.get_theme_stylebox("normal") as StyleBoxTexture
	if style == null or style.texture == null or style.texture.resource_path != expected_path:
		_fail("Expected %s to use %s." % [node_name, expected_path])


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
