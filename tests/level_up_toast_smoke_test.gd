extends SceneTree

const TOAST_SCENE := preload("res://scenes/LevelUpToast.tscn")
const TOAST_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png"
const EXPECTED_SOURCE_SIZE := Vector2(480, 300)
const EXPECTED_TEXTURE_MARGINS := Vector4(58, 48, 58, 48)
const EXPECTED_CONTENT_MARGINS := Vector4(70, 112, 70, 112)


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2560, 1440)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var toast := TOAST_SCENE.instantiate()
	viewport.add_child(toast)
	await process_frame
	await process_frame

	var frame := toast.find_child("LevelUpToastFrame", true, false) as PanelContainer
	if frame == null:
		_fail("Expected LevelUpToastFrame to be created.")
		return
	if str(frame.get_meta("toast_frame_path", "")) != TOAST_FRAME_PATH:
		_fail("Expected LevelUpToastFrame to use %s, got %s." % [TOAST_FRAME_PATH, str(frame.get_meta("toast_frame_path", ""))])
		return
	if Vector2(frame.get_meta("toast_source_size", Vector2.ZERO)) != EXPECTED_SOURCE_SIZE:
		_fail("Unexpected toast source size metadata: %s." % str(frame.get_meta("toast_source_size", Vector2.ZERO)))
		return
	if Vector4(frame.get_meta("toast_texture_margins", Vector4.ZERO)) != EXPECTED_TEXTURE_MARGINS:
		_fail("Unexpected toast texture margins metadata: %s." % str(frame.get_meta("toast_texture_margins", Vector4.ZERO)))
		return
	if Vector4(frame.get_meta("toast_content_margins", Vector4.ZERO)) != EXPECTED_CONTENT_MARGINS:
		_fail("Unexpected toast content margins metadata: %s." % str(frame.get_meta("toast_content_margins", Vector4.ZERO)))
		return

	var style := frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null or style.texture.resource_path != TOAST_FRAME_PATH:
		_fail("Expected toast panel StyleBoxTexture to use the 2K toast frame.")
		return
	if style.content_margin_left < style.texture_margin_left or style.content_margin_top < style.texture_margin_top:
		_fail("Expected toast content margins to be >= texture margins.")
		return

	if not toast.is_in_group("level_up_effects"):
		_fail("Expected LevelUpToast to join level_up_effects for cleanup.")
		return
	if not toast.find_children("*", "Label", true, false).is_empty():
		_fail("LevelUpToast must stay textless; the world-space badge is the only Level Up label.")
		return

	var content_rect := frame.get_meta("toast_content_rect", Rect2()) as Rect2
	for node in toast.get_children():
		var sprite := node as Sprite2D
		if sprite == null:
			continue
		if not content_rect.grow(4.0).has_point(sprite.position):
			_fail("Toast sprite %s starts outside frame safe content rect %s." % [sprite.name, str(content_rect)])
			return

	await create_timer(1.2).timeout
	if is_instance_valid(toast) and toast.is_inside_tree():
		_fail("Expected LevelUpToast to self-clean after its tween lifetime.")
		return

	viewport.queue_free()
	await process_frame
	print("Level-up toast smoke passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
