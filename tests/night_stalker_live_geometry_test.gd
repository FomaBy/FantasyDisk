extends SceneTree

# FAN-3104: live geometry contract for the normalized Night Stalker pack.
# This measures the real EliteStalker scene, not the source report: every
# directional row and every frame must keep the normalized silhouette and
# footline inside the accepted gameplay-facing window.

const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const ELITE_STALKER_SCENE := preload("res://scenes/EliteStalker.tscn")

const DIRECTIONS := [

	{"suffix": "east", "vector": Vector2(1.0, 0.0)},
	{"suffix": "south_east", "vector": Vector2(1.0, 1.0)},
	{"suffix": "south", "vector": Vector2(0.0, 1.0)},
	{"suffix": "south_west", "vector": Vector2(-1.0, 1.0)},
	{"suffix": "west", "vector": Vector2(-1.0, 0.0)},
	{"suffix": "north_west", "vector": Vector2(-1.0, -1.0)},
	{"suffix": "north", "vector": Vector2(0.0, -1.0)},
	{"suffix": "north_east", "vector": Vector2(1.0, -1.0)},
]
const STATES := [
	"idle",
	"move",
	"attack",
	"hit",
	"death",
	"skill_shadow_strike",
	"skill_phase_dash",
]
const EXPECTED_ROW_COUNT := 56
const EXPECTED_FRAME_COUNT := 368
const CANVAS_SIZE := 512
const EXPECTED_HEIGHT_MIN := 235.0
const EXPECTED_HEIGHT_MAX := 258.0
const EXPECTED_FEET_MIN := 91.0
const EXPECTED_FEET_MAX := 99.0
const EXPECTED_CONTACT_RANGE := 244.6527
const EXPECTED_COLLISION_RADIUS := 68.0400
const METRIC_TOLERANCE := 0.001


func _initialize() -> void:
	var errors: Array[String] = []
	var stalker := ELITE_STALKER_SCENE.instantiate() as Node2D
	if stalker == null:
		_fail("EliteStalker.tscn did not instantiate as a Node2D.")
		return
	root.add_child(stalker)
	await process_frame

	var body := stalker.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if body == null or body.sprite_frames == null:
		_fail("EliteStalker.tscn did not configure a live FullFrameBody/SpriteFrames.")
		return

	var frames := body.sprite_frames
	var names := frames.get_animation_names()
	if names.size() != EXPECTED_ROW_COUNT:
		errors.append("expected %d directional rows, got %d" % [EXPECTED_ROW_COUNT, names.size()])

	var expected_rows: Array[String] = []
	for state in STATES:
		for direction in DIRECTIONS:
			var suffix := str(direction["suffix"])
			var row_name := "%s_%s" % [state, suffix]
			expected_rows.append(row_name)
			if not frames.has_animation(row_name):
				errors.append("missing live row %s" % row_name)
	for name in names:
		if not expected_rows.has(str(name)):
			errors.append("unexpected non-contract row %s" % str(name))

	var heights: Array[float] = []
	var feetlines: Array[float] = []
	var frame_count := 0
	for state in STATES:
		for direction in DIRECTIONS:
			var suffix := str(direction["suffix"])
			var direction_vector := (direction["vector"] as Vector2).normalized()
			var row_name := "%s_%s" % [state, suffix]
			if not frames.has_animation(row_name):
				continue
			if not FullFrameAnimationRegistry.play_state(body, str(state), direction_vector):
				errors.append("play_state failed for %s" % row_name)
				continue
			if str(body.animation) != row_name:
				errors.append("%s resolved to %s" % [row_name, str(body.animation)])
			if body.flip_h:
				errors.append("%s set flip_h=true" % row_name)
			if bool(body.get_meta("directional_fallback_used", false)):
				errors.append("%s used directional fallback" % row_name)

			var row_frame_count := frames.get_frame_count(row_name)
			for frame_index in range(row_frame_count):
				body.frame = frame_index
				var texture := frames.get_frame_texture(row_name, frame_index)
				var metrics := _live_frame_metrics(stalker, body, texture)
				if metrics.is_empty():
					errors.append("%s[%d] has no measurable alpha bbox" % [row_name, frame_index])
					continue
				frame_count += 1
				heights.append(float(metrics["height"]))
				feetlines.append(float(metrics["feet"]))

	if frame_count != EXPECTED_FRAME_COUNT:
		errors.append("expected %d live frames, measured %d" % [EXPECTED_FRAME_COUNT, frame_count])
	if heights.is_empty() or feetlines.is_empty():
		errors.append("live geometry produced no frame metrics")
	else:
		var height_min := float(heights[0])
		var height_max := height_min
		var feet_min := float(feetlines[0])
		var feet_max := feet_min
		for index in range(1, heights.size()):
			height_min = minf(height_min, float(heights[index]))
			height_max = maxf(height_max, float(heights[index]))
			feet_min = minf(feet_min, float(feetlines[index]))
			feet_max = maxf(feet_max, float(feetlines[index]))
		var height_spread := height_max - height_min
		var feet_spread := feet_max - feet_min
		print("night_stalker live geometry: rows=%d frames=%d height=%.3f..%.3f feet=%.3f..%.3f spreads=(%.3f,%.3f) contact_range=%.4f collision_radius=%.4f" % [
			names.size(),
			frame_count,
			height_min,
			height_max,
			feet_min,
			feet_max,
			height_spread,
			feet_spread,
			float(stalker.get("contact_range")),
			_collision_radius(stalker),
		])
		if height_min < EXPECTED_HEIGHT_MIN - METRIC_TOLERANCE or height_max > EXPECTED_HEIGHT_MAX + METRIC_TOLERANCE:
			errors.append("live height %.3f..%.3f outside %.0f..%.0f" % [height_min, height_max, EXPECTED_HEIGHT_MIN, EXPECTED_HEIGHT_MAX])
		if feet_min < EXPECTED_FEET_MIN - METRIC_TOLERANCE or feet_max > EXPECTED_FEET_MAX + METRIC_TOLERANCE:
			errors.append("live footline %.3f..%.3f outside %.0f..%.0f" % [feet_min, feet_max, EXPECTED_FEET_MIN, EXPECTED_FEET_MAX])
		if height_spread > METRIC_TOLERANCE or feet_spread > METRIC_TOLERANCE:
			errors.append("live geometry spread is height=%.3f feet=%.3f, expected zero" % [height_spread, feet_spread])

	var config := FullFrameAnimationRegistry.registry_config("elite", "night_stalker")
	var configured_scale := config.get("scale", Vector2.ZERO) as Vector2
	if configured_scale.distance_to(Vector2(0.62, 0.62)) > METRIC_TOLERANCE:
		errors.append("registry scale changed to %s, expected (0.62, 0.62)" % str(configured_scale))
	if absf(float(stalker.get("contact_range")) - EXPECTED_CONTACT_RANGE) > METRIC_TOLERANCE:
		errors.append("contact_range %.4f changed from %.4f" % [float(stalker.get("contact_range")), EXPECTED_CONTACT_RANGE])
	if absf(_collision_radius(stalker) - EXPECTED_COLLISION_RADIUS) > METRIC_TOLERANCE:
		errors.append("collision radius %.4f changed from %.4f" % [_collision_radius(stalker), EXPECTED_COLLISION_RADIUS])

	stalker.queue_free()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error("Night Stalker live geometry: %s" % error)
		quit(1)
		return
	print("Night Stalker live geometry test passed: 7 states x 8 directions x 368 frames.")
	quit(0)


func _live_frame_metrics(stalker: Node2D, body: AnimatedSprite2D, texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var image := texture.get_image()
	if image == null or image.is_empty() or image.get_width() != CANVAS_SIZE or image.get_height() != CANVAS_SIZE:
		return {}
	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return {}
	var global_scale := body.global_scale.y
	var visible_height := float(used_rect.size.y) * global_scale
	var local_feet := float(used_rect.position.y + used_rect.size.y) - float(image.get_height()) * 0.5
	var feet := local_feet * global_scale + (body.global_position.y - stalker.global_position.y)
	return {"height": visible_height, "feet": feet}


func _collision_radius(stalker: Node2D) -> float:
	var collision := stalker.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not (collision.shape is CircleShape2D):
		return -1.0
	return (collision.shape as CircleShape2D).radius * stalker.scale.x


func _fail(message: String) -> void:
	push_error("Night Stalker live geometry: %s" % message)
	quit(1)
