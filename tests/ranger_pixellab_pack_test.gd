extends SceneTree

const CHARACTER_ID := "ranger"
const FRAMES_PATH := "res://assets/sprites/characters/ranger_spriteframes.tres"
const RUNTIME_DIR := "res://assets/sprites/characters/full_frame/ranger_pixellab"
const DIRECTIONS := [
	"south",
	"south_east",
	"east",
	"north_east",
	"north",
	"north_west",
	"west",
	"south_west",
]
const FILE_DIRECTIONS := {
	"south": "south",
	"south_east": "south-east",
	"east": "east",
	"north_east": "north-east",
	"north": "north",
	"north_west": "north-west",
	"west": "west",
	"south_west": "south-west",
}


func _initialize() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null:
		_fail("Expected Ranger PixelLab SpriteFrames to load.")
		return
	if frames.has_animation("attack") or frames.has_animation("attack_primary"):
		_fail("Ranger PixelLab body pack must not expose attack animations by SCRUM-804 scope.")
		return
	if frames.get_frame_count("idle") != 1 or frames.get_frame_count("walk") != 6 or frames.get_frame_count("move") != 6:
		_fail("Expected Ranger fallback idle/walk/move frame counts to be 1/6/6.")
		return
	for direction in DIRECTIONS:
		if not frames.has_animation("idle_%s" % direction):
			_fail("Expected idle_%s." % direction)
			return
		if not frames.has_animation("walk_%s" % direction) or not frames.has_animation("move_%s" % direction):
			_fail("Expected walk/move_%s." % direction)
			return
		if frames.get_frame_count("idle_%s" % direction) != 1:
			_fail("Expected idle_%s to contain one directional pose." % direction)
			return
		if frames.get_frame_count("walk_%s" % direction) != 6 or frames.get_frame_count("move_%s" % direction) != 6:
			_fail("Expected walk/move_%s to contain six PixelLab movement frames." % direction)
			return

	for direction in DIRECTIONS:
		var file_direction := str(FILE_DIRECTIONS[direction])
		if not _assert_runtime_frame_size("%s/%s_idle_%s.png" % [RUNTIME_DIR, CHARACTER_ID, file_direction]):
			return
		for index in range(6):
			if not _assert_runtime_frame_size("%s/%s_move_%s_%02d.png" % [RUNTIME_DIR, CHARACTER_ID, file_direction, index]):
				return
	print("Ranger PixelLab pack smoke test passed.")
	quit(0)


func _assert_runtime_frame_size(path: String) -> bool:
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		_fail("Expected runtime frame to load: %s." % path)
		return false
	if image.get_size() != Vector2i(512, 512):
		_fail("Expected %s to be 512x512, got %s." % [path, str(image.get_size())])
		return false
	var bbox := _visible_bbox(image)
	if bbox.is_empty():
		_fail("Expected visible alpha in %s." % path)
		return false
	var height := int(bbox[3]) - int(bbox[1])
	if height < 240 or height > 250:
		_fail("Expected %s visible height in 240..250 contract range, got %d." % [path, height])
		return false
	return true


func _visible_bbox(image: Image) -> Array:
	var x0 := image.get_width()
	var y0 := image.get_height()
	var x1 := -1
	var y1 := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if int(round(image.get_pixel(x, y).a * 255.0)) <= 8:
				continue
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x + 1)
			y1 = maxi(y1, y + 1)
	if x1 < 0 or y1 < 0:
		return []
	return [x0, y0, x1, y1]


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
