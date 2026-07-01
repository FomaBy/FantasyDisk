extends SceneTree

const SPRITEFRAMES_PATH := "res://assets/sprites/characters/soldier_spriteframes.tres"
const RUNTIME_PREFIX := "res://assets/sprites/characters/full_frame/soldier_pixellab/"
const DIRECTIONS := [
	"south",
	"south-east",
	"east",
	"north-east",
	"north",
	"north-west",
	"west",
	"south-west",
]


func _initialize() -> void:
	var sprite_frames := load(SPRITEFRAMES_PATH) as SpriteFrames
	if sprite_frames == null:
		_fail("Failed to load %s." % SPRITEFRAMES_PATH)
		return

	var expected := {
		"idle": 1,
		"move": 6,
		"walk": 6,
	}
	for direction_variant in DIRECTIONS:
		var direction := str(direction_variant)
		var suffix := direction.replace("-", "_")
		expected["idle_%s" % suffix] = 1
		expected["move_%s" % suffix] = 6
		expected["walk_%s" % suffix] = 6

	for animation_name_variant in sprite_frames.get_animation_names():
		var name := str(animation_name_variant)
		if name.begins_with("attack"):
			_fail("Unexpected attack animation in source-pack phase: %s." % name)
			return

	for animation_name_variant in expected.keys():
		var animation_name := str(animation_name_variant)
		if not sprite_frames.has_animation(animation_name):
			_fail("Missing animation: %s." % animation_name)
			return
		var frame_count := sprite_frames.get_frame_count(animation_name)
		var expected_frame_count := int(expected[animation_name])
		if frame_count != expected_frame_count:
			_fail("Animation %s has %d frames; expected %d." % [animation_name, frame_count, expected_frame_count])
			return
		for frame_index in range(frame_count):
			var texture := sprite_frames.get_frame_texture(animation_name, frame_index)
			if texture == null:
				_fail("Animation %s frame %d has null texture." % [animation_name, frame_index])
				return
			var path := str(texture.resource_path)
			if not path.begins_with(RUNTIME_PREFIX):
				_fail("Animation %s frame %d points outside Soldier runtime pack: %s." % [animation_name, frame_index, path])
				return
			if texture.get_width() != 512 or texture.get_height() != 512:
				_fail("Animation %s frame %d texture is %dx%d; expected 512x512." % [animation_name, frame_index, texture.get_width(), texture.get_height()])
				return
			if _visible_pixel_count(path) <= 0:
				_fail("Animation %s frame %d has empty alpha: %s." % [animation_name, frame_index, path])
				return

	print("SCRUM-434 Soldier SpriteFrames validation passed: %d animations." % expected.size())
	quit()


func _visible_pixel_count(resource_path: String) -> int:
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(resource_path))
	if err != OK:
		_fail("Failed to load image %s: %d." % [resource_path, err])
		return -1
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if int(round(image.get_pixel(x, y).a * 255.0)) > 8:
				count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
