extends SceneTree

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


func _initialize() -> void:
	var frames := load("res://assets/sprites/characters/thief_spriteframes.tres") as SpriteFrames
	if frames == null:
		push_error("SCRUM-800: thief SpriteFrames failed to load.")
		quit(1)
		return
	var expected := ["idle", "move", "walk"]
	for direction in DIRECTIONS:
		expected.append("idle_%s" % direction)
	for direction in DIRECTIONS:
		expected.append("move_%s" % direction)
	for direction in DIRECTIONS:
		expected.append("walk_%s" % direction)
	for name in expected:
		if not frames.has_animation(name):
			push_error("SCRUM-800: missing animation %s." % name)
			quit(1)
			return
	if frames.get_frame_count("idle") != 5 or frames.get_frame_count("move") != 5 or frames.get_frame_count("walk") != 5:
		push_error("SCRUM-800: fallback idle/move/walk counts are not legacy-compatible 5/5/5.")
		quit(1)
		return
	for direction in DIRECTIONS:
		if frames.get_frame_count("idle_%s" % direction) != 1:
			push_error("SCRUM-800: idle_%s is not 1 frame." % direction)
			quit(1)
			return
		if frames.get_frame_count("move_%s" % direction) != 6 or frames.get_frame_count("walk_%s" % direction) != 6:
			push_error("SCRUM-800: move/walk_%s are not 6 frames." % direction)
			quit(1)
			return
	print("SCRUM-800 thief SpriteFrames validation passed.")
	quit(0)
