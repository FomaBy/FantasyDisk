extends SceneTree

# FAN-2605: аудит 8-направленного PixelLab-пака героя-робота. Проверяем:
# явные idle/move/walk-строки по всем восьми ракурсам без зеркальных
# суррогатов, единый размер кадра 512x512, стабильную линию ног
# (нижняя граница видимой альфы), отсутствие атак-строк в теле
# (атака принадлежит оружию) и полную провенансную сетку файлов пака.
#
# Запуск: Godot --headless --path . --script res://tests/robot_pixellab_pack_test.gd

const CHARACTER_ID := "robot"
const FRAMES_PATH := "res://assets/sprites/characters/robot_spriteframes.tres"
const RUNTIME_DIR := "res://assets/sprites/characters/full_frame/robot_pixellab"
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
# Диапазон высот силуэта по живому паку (как у остальных PixelLab-героев,
# 244..246 по аудиту, допуск на дизеринг); нижняя граница — стабильная
# линия ног, ±2px на весь пак.
const VISIBLE_HEIGHT_RANGE := Vector2i(243, 248)
const FOOTLINE_RANGE := Vector2i(478, 481)


func _initialize() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null:
		_fail("Expected Robot PixelLab SpriteFrames to load.")
		return
	for attack_name in ["attack", "attack_primary", "attack_south", "attack_east"]:
		if frames.has_animation(attack_name):
			_fail("Robot PixelLab body pack must not expose %s: attack is weapon-owned." % attack_name)
			return
	if frames.get_frame_count("idle") != 1 or frames.get_frame_count("walk") != 6 or frames.get_frame_count("move") != 6:
		_fail("Expected Robot fallback idle/walk/move frame counts to be 1/6/6.")
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
		# walk/move одного ракурса обязаны ссылаться на одну и ту же сетку,
		# иначе рантайм-фолбэк между ними даст скачок позы.
		for index in range(6):
			var walk_texture := frames.get_frame_texture("walk_%s" % direction, index)
			var move_texture := frames.get_frame_texture("move_%s" % direction, index)
			if walk_texture != move_texture:
				_fail("Expected walk_%s and move_%s frame %d to share the same texture." % [direction, direction, index])
				return

	for direction in DIRECTIONS:
		var file_direction := str(FILE_DIRECTIONS[direction])
		if not _assert_runtime_frame("%s/%s_idle_%s.png" % [RUNTIME_DIR, CHARACTER_ID, file_direction]):
			return
		for index in range(6):
			if not _assert_runtime_frame("%s/%s_move_%s_%02d.png" % [RUNTIME_DIR, CHARACTER_ID, file_direction, index]):
				return
	print("Robot PixelLab pack test passed.")
	quit(0)


func _assert_runtime_frame(path: String) -> bool:
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
	if height < VISIBLE_HEIGHT_RANGE.x or height > VISIBLE_HEIGHT_RANGE.y:
		_fail("Expected %s visible height in %d..%d contract range, got %d." % [path, VISIBLE_HEIGHT_RANGE.x, VISIBLE_HEIGHT_RANGE.y, height])
		return false
	var footline := int(bbox[3])
	if footline < FOOTLINE_RANGE.x or footline > FOOTLINE_RANGE.y:
		_fail("Expected %s stable footline in %d..%d, got %d." % [path, FOOTLINE_RANGE.x, FOOTLINE_RANGE.y, footline])
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
