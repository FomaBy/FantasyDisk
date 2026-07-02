extends SceneTree


func _initialize() -> void:
	var frames := load("res://assets/sprites/characters/berserk_spriteframes.tres") as SpriteFrames
	if frames == null:
		_fail("Expected Berserk PixelLab SpriteFrames to load.")
		return
	for direction in ["south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east"]:
		var animation_name := "idle_%s" % direction
		if not frames.has_animation(animation_name):
			_fail("Expected Berserk preview to expose %s." % animation_name)
			return
		if frames.get_frame_count(animation_name) != 1:
			_fail("Expected %s to contain 1 PixelLab rotation frame." % animation_name)
			return

	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.call("_show_character_select")
	await process_frame
	await process_frame

	var portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	if portrait == null or portrait.texture == null:
		_fail("Expected Hero Select to show an animated Berserk portrait texture.")
		return
	var first_texture := portrait.texture
	await create_timer(0.24).timeout
	if portrait.texture == null or portrait.texture == first_texture:
		_fail("Expected Hero Select Berserk preview to advance through PixelLab direction frames.")
		return

	print("Hero Select Berserk preview smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
