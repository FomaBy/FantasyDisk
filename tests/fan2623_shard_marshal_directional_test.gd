extends SceneTree

## FAN-2623 — focused Shard Marshal directional/runtime contract.
## This test is actor-local: the shared animation smoke remains reserved for its
## own follow-up and is intentionally not changed here.

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const DIRECTIONS := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
const VECTORS := [
	Vector2.RIGHT, Vector2(1.0, 1.0), Vector2.DOWN,
	Vector2(-1.0, 1.0), Vector2.LEFT, Vector2(-1.0, -1.0),
	Vector2.UP, Vector2(1.0, -1.0),
]
const STATE_ROWS := {
	"idle": {"frames": 1, "loop": true},
	"move": {"frames": 8, "loop": true},
	"attack": {"frames": 7, "loop": false},
	"hit": {"frames": 5, "loop": false},
	"death": {"frames": 7, "loop": false},
	"skill_shard_fan": {"frames": 7, "loop": false},
	"skill_command_pulse": {"frames": 7, "loop": false},
}
const ALIASES := {
	"attack_primary": "attack",
	"attack_shard_fan": "skill_shard_fan",
	"attack_command_pulse": "skill_command_pulse",
}

var _failed := false


func _initialize() -> void:
	_test_manifest_contract()
	_test_directional_registry_resolution()
	_test_alias_and_compound_resolution()
	await _test_mini_swarm_sniper_identity()
	_test_fail_closed_negative_control()
	_test_spawn_reentry_and_cleanup()
	if _failed:
		quit(1)
		return
	print("FAN-2623 Shard Marshal directional test passed.")
	quit(0)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)


func _test_manifest_contract() -> void:
	var config := FullFrameAnimationRegistry.registry_config("elite", "shard_marshal")
	if not bool(config.get("explicit_eight_directions", false)):
		_fail("Expected shard_marshal registry entry to declare explicit_eight_directions=true.")
	var frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "shard_marshal")
	if frames == null:
		_fail("Expected shard_marshal SpriteFrames to resolve from the registry.")
		return
	for state_name in STATE_ROWS:
		var state_info: Dictionary = STATE_ROWS[state_name]
		if not FullFrameAnimationRegistry.has_full_directional_rows(frames, state_name):
			_fail("Expected %s to expose all 8 directional rows." % state_name)
		for direction in DIRECTIONS:
			var row := "%s_%s" % [state_name, direction]
			if frames.get_frame_count(row) != int(state_info["frames"]):
				_fail("Expected %s to have %d frames, got %d." % [row, int(state_info["frames"]), frames.get_frame_count(row)])
			if frames.get_animation_loop(row) != bool(state_info["loop"]):
				_fail("Expected %s loop=%s." % [row, str(state_info["loop"])])
			var texture := frames.get_frame_texture(row, 0)
			if texture == null or texture.get_width() != 512 or texture.get_height() != 512:
				_fail("Expected %s first frame to be a 512x512 runtime canvas." % row)
	for alias in ALIASES:
		var target: String = ALIASES[alias]
		for direction in DIRECTIONS:
			var row := "%s_%s" % [alias, direction]
			var target_row := "%s_%s" % [target, direction]
			if not frames.has_animation(row) or frames.get_frame_count(row) != frames.get_frame_count(target_row):
				_fail("Expected %s alias row to match %s." % [row, target_row])


func _test_directional_registry_resolution() -> void:
	var frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "shard_marshal")
	if frames == null:
		return
	var body := _make_body(frames)
	for state_name in STATE_ROWS:
		for index in DIRECTIONS.size():
			var direction := str(DIRECTIONS[index])
			body.flip_h = true
			if not FullFrameAnimationRegistry.play_state(body, state_name, VECTORS[index]):
				_fail("Expected %s/%s to resolve." % [state_name, direction])
			if str(body.animation) != "%s_%s" % [state_name, direction]:
				_fail("Expected %s/%s row, got %s." % [state_name, direction, str(body.animation)])
			if body.flip_h:
				_fail("Expected %s/%s to disable horizontal mirroring." % [state_name, direction])
			if bool(body.get_meta("directional_fallback_used", true)):
				_fail("Expected %s/%s to resolve without directional fallback." % [state_name, direction])
	body.free()


func _test_alias_and_compound_resolution() -> void:
	var frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "shard_marshal")
	if frames == null:
		return
	var body := _make_body(frames)
	for request in ["attack_primary", "shard_marshal:shard_fan:windup", "shard_marshal:shard_fan:strike", "shard_marshal:command_pulse:windup", "shard_marshal:command_pulse:strike"]:
		if not FullFrameAnimationRegistry.play_state(body, request, Vector2.RIGHT):
			_fail("Expected alias/compound request to resolve: %s" % request)
		if body.flip_h:
			_fail("Expected alias/compound request not to mirror: %s" % request)
	var requested_fan := FullFrameAnimationRegistry.play_state(body, "shard_marshal:shard_fan:windup", Vector2.RIGHT)
	if requested_fan and str(body.animation) != "skill_shard_fan_east":
		_fail("Expected shard_fan phase to resolve skill_shard_fan_east, got %s." % str(body.animation))
	body.free()


## FAN-3875: FAN-3627 gave mini_swarm_sniper its own eight-direction pack and
## retired the shard_marshal substitution this suite used to require. The
## neighbour check now certifies that intentional independent identity — the
## mini must resolve its OWN pack, never the base elite's.
func _test_mini_swarm_sniper_identity() -> void:
	if not bool(FullFrameAnimationRegistry.registry_config("elite", "mini_swarm_sniper").get("explicit_eight_directions", false)):
		_fail("Expected mini_swarm_sniper registry entry to declare explicit_eight_directions=true.")
	var mini_frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "mini_swarm_sniper")
	if mini_frames == null:
		_fail("Expected mini_swarm_sniper to expose its own mini-specific SpriteFrames.")
		return
	var marshal_frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "shard_marshal")
	if marshal_frames != null and mini_frames.resource_path == marshal_frames.resource_path:
		_fail("Expected mini_swarm_sniper to own a distinct pack, not the retired shard_marshal fallback.")
	# Same contract states as the base elite, own row lengths: only the
	# directional completeness is shared between the two identities.
	for state_name in STATE_ROWS:
		if not FullFrameAnimationRegistry.has_full_directional_rows(mini_frames, str(state_name)):
			_fail("Expected mini_swarm_sniper pack to expose all 8 directional rows for %s." % str(state_name))
	var scene := load("res://scenes/EliteCommander.tscn") as PackedScene
	var enemy := scene.instantiate()
	enemy.set_meta("mini_elite_kind", "mini_swarm_sniper")
	root.add_child(enemy)
	await process_frame
	enemy.call("refresh_full_frame_visual")
	var body := enemy.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if body == null or not body.visible:
		_fail("Expected mini_swarm_sniper to create a visible FullFrameBody.")
	elif str(body.get_meta("entity_id", "")) != "mini_swarm_sniper":
		_fail("Expected mini_swarm_sniper to resolve its own identity, got %s." % str(body.get_meta("entity_id", "")))
	elif not FullFrameAnimationRegistry.play_state(body, "move", Vector2.RIGHT):
		_fail("Expected mini_swarm_sniper to play its own move row.")
	elif body.flip_h or str(body.animation) != "move_east":
		_fail("Expected mini_swarm_sniper to use move_east without flip_h.")
	enemy.queue_free()
	await process_frame


func _test_fail_closed_negative_control() -> void:
	var partial := SpriteFrames.new()
	partial.remove_animation("default")
	partial.add_animation("attack_east")
	partial.add_frame("attack_east", _make_texture())
	var body := _make_body(partial)
	if FullFrameAnimationRegistry.has_full_directional_rows(partial, "move"):
		_fail("Expected partial negative-control rows to fail the full directional audit.")
	if FullFrameAnimationRegistry.play_state(body, "missing_state", Vector2.RIGHT):
		_fail("Expected a completely unresolvable state to fail closed.")
	body.free()


func _test_spawn_reentry_and_cleanup() -> void:
	var frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "shard_marshal")
	if frames == null:
		return
	var body := _make_body(frames)
	if not FullFrameAnimationRegistry.play_state(body, "move", Vector2.RIGHT):
		_fail("Expected move to start for re-entry check.")
	body.set_frame_and_progress(2, 0.5)
	FullFrameAnimationRegistry.play_state(body, "move", Vector2.RIGHT)
	if body.frame != 2 or not is_equal_approx(body.frame_progress, 0.5):
		_fail("Expected same-row re-entry to preserve animation progress.")
	if not FullFrameAnimationRegistry.play_state(body, "hit", Vector2.RIGHT):
		_fail("Expected hit transition to resolve.")
	if not FullFrameAnimationRegistry.play_state(body, "death", Vector2.RIGHT):
		_fail("Expected death transition to resolve.")
	body.queue_free()
	if not body.is_queued_for_deletion():
		_fail("Expected despawn to queue the visual with its owner.")
	body.free()


func _make_body(frames: SpriteFrames) -> AnimatedSprite2D:
	var body := AnimatedSprite2D.new()
	body.sprite_frames = frames
	body.set_meta("entity_kind", "elite")
	body.set_meta("entity_id", "shard_marshal")
	body.set_meta("source_faces_left", true)
	body.set_meta("explicit_eight_directions", true)
	root.add_child(body)
	return body


func _make_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
