extends SceneTree

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

	for state: String in REQUIRED_STATES.keys():
		if not frames.has_animation(state):
			push_error("Missing animation state: %s" % state)
			quit(1)
			return
		var expected: Dictionary = REQUIRED_STATES[state]
		var count := frames.get_frame_count(state)
		if count != int(expected["frames"]):
			push_error("State %s has %d frames, expected %d" % [state, count, expected["frames"]])
			quit(1)
			return
		if frames.get_animation_loop(state) != bool(expected["loop"]):
			push_error("State %s loop flag mismatch" % state)
			quit(1)
			return
		for index in count:
			if frames.get_frame_texture(state, index) == null:
				push_error("State %s frame %d has null texture" % [state, index])
				quit(1)
				return

	var body := AnimatedSprite2D.new()
	get_root().add_child(body)
	body.sprite_frames = frames
	body.play("move")
	if body.animation != &"move" or not body.is_playing():
		push_error("AnimatedSprite2D failed to play move")
		quit(1)
		return
	body.play("attack_primary")
	if body.animation != &"attack_primary":
		push_error("AnimatedSprite2D failed to switch to attack_primary")
		quit(1)
		return

	print("SCRUM-540 secret boss animation pack smoke passed: %d states checked." % REQUIRED_STATES.size())
	quit(0)
