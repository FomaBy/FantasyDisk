extends SceneTree

# Locks the Berserk PixelLab pack contract re-audited in FAN-2593 after the
# FAN-3324 regeneration of the south/south-east/north-east/north/west rows.
# Identity and empty hands stay a visual verdict; everything machine-checkable
# about the pack lives here.

const PACK_PATH := "res://assets/sprites/characters/berserk_spriteframes.tres"
const DIRECTIONS := [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const CANVAS := 512
const VISIBLE_HEIGHT := 245
const FOOTLINE_Y := 480
const PIVOT_TOLERANCE := 1.0


func _initialize() -> void:
	var frames := load(PACK_PATH) as SpriteFrames
	if frames == null:
		_fail("Expected Berserk PixelLab SpriteFrames to load.")
		return

	for animation_name in frames.get_animation_names():
		if animation_name.begins_with("attack"):
			_fail("Expected attack to stay weapon-owned, found body row %s." % animation_name)
			return

	var row_textures := {}
	for direction in DIRECTIONS:
		if not _check_row(frames, "idle_%s" % direction, 1, direction, row_textures):
			return
		if not _check_row(frames, "move_%s" % direction, 6, direction, row_textures):
			return
		var walk_name := "walk_%s" % direction
		if not frames.has_animation(walk_name):
			_fail("Expected %s to exist as a move alias." % walk_name)
			return
		if frames.get_frame_count(walk_name) != 6:
			_fail("Expected %s to contain 6 frames." % walk_name)
			return
		for index in 6:
			if frames.get_frame_texture(walk_name, index) != frames.get_frame_texture("move_%s" % direction, index):
				_fail("Expected %s frame %d to alias the move row." % [walk_name, index])
				return

	print("Berserk PixelLab pack test passed: 8 directions, 56 unique frames, no mirror substitution.")
	quit()


func _check_row(frames: SpriteFrames, animation_name: String, expected_frames: int,
		direction: String, row_textures: Dictionary) -> bool:
	if not frames.has_animation(animation_name):
		_fail("Expected pack to expose %s." % animation_name)
		return false
	if frames.get_frame_count(animation_name) != expected_frames:
		_fail("Expected %s to contain %d frame(s), got %d." % [
			animation_name, expected_frames, frames.get_frame_count(animation_name)])
		return false

	var file_direction := direction.replace("_", "-")
	for index in expected_frames:
		var texture := frames.get_frame_texture(animation_name, index)
		if texture == null:
			_fail("Expected %s frame %d to carry a texture." % [animation_name, index])
			return false
		var path := texture.resource_path
		if not path.contains("_%s" % file_direction):
			_fail("Expected %s frame %d to use a %s texture, got %s." % [
				animation_name, index, file_direction, path])
			return false
		# A texture reused across two directional rows is a mirror substitution.
		if row_textures.has(path) and row_textures[path] != direction:
			_fail("Expected %s to own %s, already used by the %s row." % [
				direction, path, row_textures[path]])
			return false
		row_textures[path] = direction
		if not _check_geometry(animation_name, index, texture):
			return false
	return true


func _check_geometry(animation_name: String, index: int, texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null:
		_fail("Expected %s frame %d to expose an image." % [animation_name, index])
		return false
	if image.get_width() != CANVAS or image.get_height() != CANVAS:
		_fail("Expected %s frame %d on a %dx%d canvas, got %dx%d." % [
			animation_name, index, CANVAS, CANVAS, image.get_width(), image.get_height()])
		return false

	var used := image.get_used_rect()
	if used.size.y != VISIBLE_HEIGHT:
		_fail("Expected %s frame %d visible height %d, got %d." % [
			animation_name, index, VISIBLE_HEIGHT, used.size.y])
		return false
	if used.position.y + used.size.y != FOOTLINE_Y:
		_fail("Expected %s frame %d to stand on footline y=%d, got %d." % [
			animation_name, index, FOOTLINE_Y, used.position.y + used.size.y])
		return false
	var pivot_x := used.position.x + used.size.x / 2.0
	if absf(pivot_x - CANVAS / 2.0) > PIVOT_TOLERANCE:
		_fail("Expected %s frame %d pivot near x=%d, got %.1f." % [
			animation_name, index, CANVAS / 2, pivot_x])
		return false
	if used.position.x <= 0 or used.position.y <= 0 or used.end.x >= CANVAS:
		_fail("Expected %s frame %d to stay clear of the canvas edge, got %s." % [
			animation_name, index, str(used)])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
