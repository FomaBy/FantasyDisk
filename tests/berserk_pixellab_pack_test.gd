extends SceneTree

# FAN-2593: рантайм-контракт 8-направленного body-пака Berserk. Пак принят или
# отклонён визуально (identity/props — см. docs/design/systems/animation.md);
# машинно здесь закреплено то, что регрессия способна сломать молча: полный
# набор восьми ракурсов, счётчики кадров, геометрия канваса/футлайна/пивота,
# отсутствие attack-строк (атака принадлежит оружию) и отсутствие зеркальных
# суррогатов — ни одна пара направлений не делит текстуру.
#
# Запуск: Godot --headless --path . --script res://tests/berserk_pixellab_pack_test.gd

const CHARACTER_ID := "berserk"
const FRAMES_PATH := "res://assets/sprites/characters/berserk_spriteframes.tres"
const RUNTIME_DIR := "res://assets/sprites/characters/full_frame/berserk_pixellab"
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
# SCRUM-703 normalization contract: 245 px of art on a 512 px canvas, bottom
# aligned with 32 px padding, horizontally centred.
const CANVAS := Vector2i(512, 512)
const VISIBLE_HEIGHT := 245
const FOOTLINE_Y := 480
const PIVOT_X_RANGE := Vector2(254.0, 258.0)


func _initialize() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null:
		_fail("Expected Berserk PixelLab SpriteFrames to load.")
		return
	if frames.has_animation("attack") or frames.has_animation("attack_primary"):
		_fail("Berserk body pack must not expose attack animations — attack stays weapon-owned.")
		return
	if frames.get_frame_count("idle") != 1 or frames.get_frame_count("walk") != 6 or frames.get_frame_count("move") != 6:
		_fail("Expected Berserk fallback idle/walk/move frame counts to be 1/6/6.")
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
		# walk_<dir> — документированный алиас move_<dir>: те же текстуры.
		for index in range(6):
			var walk_texture := frames.get_frame_texture("walk_%s" % direction, index)
			var move_texture := frames.get_frame_texture("move_%s" % direction, index)
			if walk_texture != move_texture:
				_fail("Expected walk_%s frame %d to alias move_%s." % [direction, index, direction])
				return

	if not _assert_no_mirror_substitution(frames):
		return

	for direction in DIRECTIONS:
		var file_direction := str(FILE_DIRECTIONS[direction])
		if not _assert_runtime_frame("%s/%s_idle_%s.png" % [RUNTIME_DIR, CHARACTER_ID, file_direction]):
			return
		for index in range(6):
			if not _assert_runtime_frame("%s/%s_move_%s_%02d.png" % [RUNTIME_DIR, CHARACTER_ID, file_direction, index]):
				return
	print("Berserk PixelLab pack smoke test passed.")
	quit(0)


func _assert_no_mirror_substitution(frames: SpriteFrames) -> bool:
	# Каждый ракурс обязан иметь собственные кадры: общая текстура между двумя
	# направлениями означала бы зеркальную/чужую подмену идентичности.
	var owners := {}
	for direction in DIRECTIONS:
		var rows := ["idle_%s" % direction, "move_%s" % direction]
		for row in rows:
			for index in range(frames.get_frame_count(row)):
				var texture := frames.get_frame_texture(row, index)
				if texture == null:
					_fail("Expected %s frame %d to resolve a texture." % [row, index])
					return false
				var path := texture.resource_path
				if owners.has(path) and str(owners[path]) != direction:
					_fail("Expected %s to be unique to one direction, shared by %s and %s." % [
						path, str(owners[path]), direction])
					return false
				owners[path] = direction
	return true


func _assert_runtime_frame(path: String) -> bool:
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		_fail("Expected runtime frame to load: %s." % path)
		return false
	if image.get_size() != CANVAS:
		_fail("Expected %s to be %s, got %s." % [path, str(CANVAS), str(image.get_size())])
		return false
	var bbox := _visible_bbox(image)
	if bbox.is_empty():
		_fail("Expected visible alpha in %s." % path)
		return false
	var height := int(bbox[3]) - int(bbox[1])
	if height != VISIBLE_HEIGHT:
		_fail("Expected %s visible height %d, got %d." % [path, VISIBLE_HEIGHT, height])
		return false
	if int(bbox[3]) != FOOTLINE_Y:
		_fail("Expected %s footline y=%d, got %d." % [path, FOOTLINE_Y, int(bbox[3])])
		return false
	var pivot_x := (float(bbox[0]) + float(bbox[2])) * 0.5
	if pivot_x < PIVOT_X_RANGE.x or pivot_x > PIVOT_X_RANGE.y:
		_fail("Expected %s pivot x in %s, got %.1f." % [path, str(PIVOT_X_RANGE), pivot_x])
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
