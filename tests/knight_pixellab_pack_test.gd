extends SceneTree

# FAN-2602: machine-checkable contract for the Knight pack re-audited after
# FAN-3324 regenerated the west, south-west, north-east and north-west rows.
# Identity and cloak continuity remain visual checks in the committed sheets;
# this gate covers the source provenance, directional mapping and runtime data.

const CHARACTER_ID := "knight"
const FRAMES_PATH := "res://assets/sprites/characters/knight_spriteframes.tres"
const SOURCE_DIR := "res://assets/sprites/characters/pixellab/knight"
const RUNTIME_DIR := "res://assets/sprites/characters/full_frame/knight_pixellab"
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
const CANVAS := 512
const VISIBLE_HEIGHT := 245
const FOOTLINE_Y := 504
const PIVOT_TOLERANCE := 1.0
const REAUDIT_BASE_SHA := "9dbffddbcce43595fa0ffd882c44213e3c4bd7e1"


func _initialize() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		return
	if not _assert_reaudit_marker(manifest):
		return
	if not _assert_fan3324_provenance(manifest):
		return

	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null:
		_fail("Expected Knight PixelLab SpriteFrames to load.")
		return

	var expected_animations := {"idle": true, "move": true, "walk": true}
	for direction in DIRECTIONS:
		expected_animations["idle_%s" % direction] = true
		expected_animations["move_%s" % direction] = true
		expected_animations["walk_%s" % direction] = true
	for animation_name in frames.get_animation_names():
		var name := str(animation_name)
		if not expected_animations.has(name):
			_fail("Unexpected Knight body animation %s; attacks remain weapon-owned." % name)
			return
	for animation_name in expected_animations:
		if not frames.has_animation(animation_name):
			_fail("Expected Knight body animation %s." % animation_name)
			return

	if frames.get_frame_count("idle") != 1 or frames.get_frame_count("move") != 6 or frames.get_frame_count("walk") != 6:
		_fail("Expected Knight fallback idle/move/walk frame counts to be 1/6/6.")
		return
	if not frames.get_animation_loop("idle") or not frames.get_animation_loop("move") or not frames.get_animation_loop("walk"):
		_fail("Expected Knight fallback idle/move/walk animations to loop.")
		return
	if absf(frames.get_animation_speed("move") - 10.0) > 0.01 or absf(frames.get_animation_speed("walk") - 10.0) > 0.01:
		_fail("Expected Knight movement animations to run at 10 fps.")
		return

	var row_textures := {}
	for direction in DIRECTIONS:
		if not _assert_direction(frames, direction, row_textures):
			return

	for pair in [["south_east", "south_west"], ["east", "west"]]:
		var first_direction: String = pair[0]
		var second_direction: String = pair[1]
		var source_names := ["idle"]
		for index in range(6):
			source_names.append("move_%02d" % index)
		for source_name in source_names:
			var first_path := _source_path(first_direction, source_name)
			var second_path := _source_path(second_direction, source_name)
			if not _assert_not_horizontal_mirror(first_path, second_path, "%s vs %s %s" % [first_direction, second_direction, source_name]):
				return

	print("Knight PixelLab pack test passed: FAN-2602 re-audit, 8 directions, 56 unique frames, no mirrored rows.")
	quit(0)


func _source_path(direction: String, source_name: String) -> String:
	var file_direction := str(FILE_DIRECTIONS[direction])
	if source_name == "idle":
		return "%s/knight_idle_%s.png" % [SOURCE_DIR, file_direction]
	return "%s/knight_move_%s_%s.png" % [SOURCE_DIR, file_direction, source_name.trim_prefix("move_")]


func _load_manifest() -> Dictionary:
	var path := "%s/manifest.json" % SOURCE_DIR
	if not FileAccess.file_exists(path):
		_fail("Expected Knight PixelLab manifest: %s." % path)
		return {}
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	if manifest == null:
		_fail("Expected Knight PixelLab manifest JSON to parse.")
		return {}
	return manifest


func _assert_reaudit_marker(manifest: Dictionary) -> bool:
	var marker := manifest.get("fan2602_reaudit", {}) as Dictionary
	if marker == null or marker.is_empty():
		_fail("Expected the manifest to record the fresh FAN-2602 re-audit.")
		return false
	if str(marker.get("task", "")) != "FAN-2602":
		_fail("Expected the re-audit marker to belong to FAN-2602.")
		return false
	if str(marker.get("base_sha", "")) != REAUDIT_BASE_SHA:
		_fail("Expected the re-audit marker to pin the current dev base SHA.")
		return false
	if marker.get("regenerated_directions", []) != ["west", "south-west", "north-east", "north-west"]:
		_fail("Expected the four FAN-3324 regenerated directions in the re-audit marker.")
		return false
	if marker.get("untouched_directions", []) != ["south", "south-east", "east", "north"]:
		_fail("Expected the four accepted untouched directions in the re-audit marker.")
		return false
	return true


func _assert_fan3324_provenance(manifest: Dictionary) -> bool:
	if str(manifest.get("source", "")) != "PixelLab MCP":
		_fail("Expected Knight source provenance to remain PixelLab MCP.")
		return false
	var regeneration := manifest.get("fan3324_regeneration", {}) as Dictionary
	if regeneration == null or regeneration.is_empty():
		_fail("Expected FAN-3324 regeneration provenance in the Knight manifest.")
		return false
	if str(regeneration.get("source", "")) != "PixelLab MCP animate_character":
		_fail("Expected FAN-3324 rows to come from PixelLab animate_character.")
		return false
	if int(regeneration.get("frame_count_per_direction", 0)) != 6:
		_fail("Expected FAN-3324 to provide six frames per regenerated direction.")
		return false
	if bool(regeneration.get("legacy_or_manual_fallback_used", true)):
		_fail("Knight provenance must not record a legacy or manual fallback.")
		return false
	return true


func _assert_direction(frames: SpriteFrames, direction: String, row_textures: Dictionary) -> bool:
	var idle_name := "idle_%s" % direction
	var move_name := "move_%s" % direction
	var walk_name := "walk_%s" % direction
	if frames.get_frame_count(idle_name) != 1 or frames.get_frame_count(move_name) != 6 or frames.get_frame_count(walk_name) != 6:
		_fail("Expected %s to expose 1 idle and 6 move/walk frames." % direction)
		return false
	if not frames.get_animation_loop(idle_name) or not frames.get_animation_loop(move_name) or not frames.get_animation_loop(walk_name):
		_fail("Expected %s idle/move/walk rows to loop." % direction)
		return false
	if absf(frames.get_animation_speed(move_name) - 10.0) > 0.01 or absf(frames.get_animation_speed(walk_name) - 10.0) > 0.01:
		_fail("Expected %s move/walk rows to run at 10 fps." % direction)
		return false

	var file_direction := str(FILE_DIRECTIONS[direction])
	var idle_texture := frames.get_frame_texture(idle_name, 0)
	if not _assert_texture(idle_texture, idle_name, 0, file_direction, row_textures):
		return false
	for index in range(6):
		var move_texture := frames.get_frame_texture(move_name, index)
		if not _assert_texture(move_texture, move_name, index, file_direction, row_textures):
			return false
		if frames.get_frame_texture(walk_name, index) != move_texture:
			_fail("Expected %s frame %d to be shared by move and walk." % [direction, index])
			return false
	return true


func _assert_texture(texture: Texture2D, animation_name: String, index: int, file_direction: String, row_textures: Dictionary) -> bool:
	if texture == null:
		_fail("Expected %s frame %d to carry a texture." % [animation_name, index])
		return false
	var path := texture.resource_path
	if not path.contains("_%s" % file_direction):
		_fail("Expected %s frame %d to use a %s texture, got %s." % [animation_name, index, file_direction, path])
		return false
	if row_textures.has(path):
		_fail("Expected every Knight idle/move texture to be unique; reused %s." % path)
		return false
	row_textures[path] = true
	return _assert_runtime_frame(path, animation_name, index)


func _assert_runtime_frame(path: String, animation_name: String, index: int) -> bool:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		_fail("Expected runtime frame to load: %s." % path)
		return false
	if image.get_size() != Vector2i(CANVAS, CANVAS):
		_fail("Expected %s to be %dx%d, got %s." % [path, CANVAS, CANVAS, str(image.get_size())])
		return false
	if image.get_format() != Image.FORMAT_RGBA8:
		_fail("Expected %s to use RGBA8 alpha data." % path)
		return false
	var data := image.get_data()
	for offset in range(3, data.size(), 4):
		if data[offset] != 0 and data[offset] != 255:
			_fail("Expected binary alpha in %s (%s frame %d)." % [path, animation_name, index])
			return false
	var used := image.get_used_rect()
	if used.size == Vector2i.ZERO:
		_fail("Expected visible alpha in %s." % path)
		return false
	if used.size.y != VISIBLE_HEIGHT or used.position.y + used.size.y != FOOTLINE_Y:
		_fail("Expected %s geometry height/footline %d/%d, got %d/%d." % [path, VISIBLE_HEIGHT, FOOTLINE_Y, used.size.y, used.position.y + used.size.y])
		return false
	var pivot_x := float(used.position.x) + float(used.size.x) / 2.0
	if absf(pivot_x - CANVAS / 2.0) > PIVOT_TOLERANCE:
		_fail("Expected %s pivot near x=%d, got %.1f." % [path, CANVAS / 2, pivot_x])
		return false
	if used.position.x <= 0 or used.position.y <= 0 or used.end.x >= CANVAS or used.end.y >= CANVAS:
		_fail("Expected %s to stay clear of the canvas edge, got %s." % [path, str(used)])
		return false
	return true


func _assert_not_horizontal_mirror(first_path: String, second_path: String, label: String) -> bool:
	var first := Image.new()
	var second := Image.new()
	if first.load(ProjectSettings.globalize_path(first_path)) != OK or second.load(ProjectSettings.globalize_path(second_path)) != OK:
		_fail("Expected source frames for mirror audit: %s." % label)
		return false
	var flipped := first.duplicate()
	flipped.flip_x()
	if flipped.get_data() == second.get_data():
		_fail("Expected %s to be separately authored, not an east-facing mirror." % label)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
