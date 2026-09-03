extends SceneTree

# SCRUM-540 introduced the secret boss pack with bare state names; FAN-3326
# materialised it as an eight-direction pack, so every state now exists only
# as `<state>_<direction>` rows resolved by FullFrameAnimationRegistry.

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const FRAMES_PATH := "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres"
const REQUIRED_STATES := {
	"idle": {"frames": 6, "loop": true},
	"move": {"frames": 6, "loop": true},
	"attack": {"frames": 6, "loop": false},
	"attack_primary": {"frames": 6, "loop": false},
	"attack_primary_windup": {"frames": 6, "loop": false},
	"attack_primary_release": {"frames": 6, "loop": false},
	"attack_ring": {"frames": 6, "loop": false},
	"attack_cone": {"frames": 6, "loop": false},
	"attack_beam": {"frames": 6, "loop": false},
	"attack_rupture": {"frames": 6, "loop": false},
	"skill_ring": {"frames": 6, "loop": false},
	"skill_cone": {"frames": 6, "loop": false},
	"skill_beam": {"frames": 6, "loop": false},
	"skill_rupture": {"frames": 6, "loop": false},
	"hit": {"frames": 6, "loop": false},
	"death": {"frames": 6, "loop": false},
}


func _initialize() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	if frames == null:
		push_error("Failed to load %s" % FRAMES_PATH)
		quit(1)
		return

	var rows_checked := 0
	for state: String in REQUIRED_STATES.keys():
		if not FullFrameAnimationRegistry.has_full_directional_rows(frames, state):
			push_error("Missing eight-direction rows for state: %s" % state)
			quit(1)
			return
		var expected: Dictionary = REQUIRED_STATES[state]
		for suffix: String in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
			var row := "%s_%s" % [state, suffix]
			var count := frames.get_frame_count(row)
			if count != int(expected["frames"]):
				push_error("Row %s has %d frames, expected %d" % [row, count, expected["frames"]])
				quit(1)
				return
			if frames.get_animation_loop(row) != bool(expected["loop"]):
				push_error("Row %s loop flag mismatch" % row)
				quit(1)
				return
			for index in count:
				if frames.get_frame_texture(row, index) == null:
					push_error("Row %s frame %d has null texture" % [row, index])
					quit(1)
					return
			rows_checked += 1

	var body := AnimatedSprite2D.new()
	get_root().add_child(body)
	body.sprite_frames = frames
	body.play("move_south")
	if body.animation != &"move_south" or not body.is_playing():
		push_error("AnimatedSprite2D failed to play move_south")
		quit(1)
		return
	body.play("attack_primary_north_east")
	if body.animation != &"attack_primary_north_east":
		push_error("AnimatedSprite2D failed to switch to attack_primary_north_east")
		quit(1)
		return

	print("FAN-3326 secret boss animation pack smoke passed: %d states, %d directional rows checked." % [REQUIRED_STATES.size(), rows_checked])
	quit(0)
