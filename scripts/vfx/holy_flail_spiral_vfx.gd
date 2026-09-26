class_name HolyFlailSpiralVfx
extends Node2D

## Animator-owned SCRUM-924 choreography. Damage, targeting, hit deduplication,
## radius progression and timing remain owned by BerserkWeapon/SCRUM-923.
## FAN-2981: the spiral is carried by the PixelLab flail ghost alone — the
## former Line2D chain trail and Polygon2D front spark were zone markup.

const EFFECT_ID := "holy_flail_center_out_spiral"
const PIXELLAB_OBJECT_ID := "b1089fd9-a4c7-49ce-aec2-af62fb0317b6"
const PIXELLAB_ANIMATION_GROUP_ID := "50cb9b87-58b3-411e-af3e-caabce8b4cb4"
const STEP_COUNT := 7
const PIXELLAB_FRAME_COUNT := 8
const START_RADIUS_RATIO := 0.22
const STEP_TIME_SECONDS := 0.085

@export var auto_free_on_finish := true

@onready var flail_ghost: AnimatedSprite2D = $FlailGhost

var _finish_tween: Tween = null
var _last_step := -1
var _last_front_radius := 0.0
var _full_radius := 0.0
var _base_angle := 0.0


func _ready() -> void:
	add_to_group("player_weapon_effects")
	set_meta("effect_id", EFFECT_ID)
	set_meta("visual_only", true)
	set_meta("pixellab_object_id", PIXELLAB_OBJECT_ID)
	set_meta("pixellab_animation_group_id", PIXELLAB_ANIMATION_GROUP_ID)
	set_meta("pixel_lab_frame_count", PIXELLAB_FRAME_COUNT)
	set_meta("step_count", STEP_COUNT)
	set_meta("step_time_seconds", STEP_TIME_SECONDS)


func apply_step(
	center: Vector2,
	arm_angle: float,
	front_radius: float,
	full_radius: float,
	step_index: int,
	_color: Color
) -> void:
	_ensure_nodes()
	if flail_ghost == null:
		return
	global_position = center
	_last_step = clampi(step_index, 0, STEP_COUNT - 1)
	_last_front_radius = maxf(front_radius, 1.0)
	_full_radius = maxf(full_radius, _last_front_radius)
	var progress := float(_last_step + 1) / float(STEP_COUNT)
	_base_angle = arm_angle - TAU * progress

	var front := Vector2.from_angle(arm_angle) * _last_front_radius
	flail_ghost.position = front
	flail_ghost.rotation = arm_angle + PI * 0.5
	flail_ghost.frame = mini(_last_step, PIXELLAB_FRAME_COUNT - 1)
	var authored_scale := lerpf(0.25, 0.38, progress)
	flail_ghost.scale = Vector2.ONE * authored_scale
	flail_ghost.modulate = Color(1.0, 0.96, 0.82, lerpf(0.48, 0.72, progress))

	set_meta("step_index", _last_step)
	set_meta("progress", progress)
	set_meta("base_angle", _base_angle)
	set_meta("arm_angle", arm_angle)
	set_meta("front_radius_px", _last_front_radius)
	set_meta("full_radius_px", _full_radius)
	set_meta("front_point", front)
	set_meta("pixel_lab_frame_index", flail_ghost.frame)

	if _finish_tween != null and _finish_tween.is_valid():
		_finish_tween.kill()
	modulate.a = 1.0
	_finish_tween = create_tween()
	_finish_tween.tween_interval(STEP_TIME_SECONDS * 1.45)
	_finish_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	if auto_free_on_finish:
		_finish_tween.tween_callback(queue_free)


func _ensure_nodes() -> void:
	# Runtime attacks add the packed scene to an already-ready tree, but capture
	# and deterministic tests may configure it during SceneTree initialization.
	# Resolve children eagerly so the visual bridge is safe in both paths.
	if flail_ghost == null:
		flail_ghost = get_node_or_null("FlailGhost") as AnimatedSprite2D


func geometry_contract() -> Dictionary:
	return {
		"effect_id": EFFECT_ID,
		"step_count": STEP_COUNT,
		"step_index": _last_step,
		"step_time_seconds": STEP_TIME_SECONDS,
		"start_radius_ratio": START_RADIUS_RATIO,
		"front_radius_px": _last_front_radius,
		"full_radius_px": _full_radius,
		"base_angle": _base_angle,
		"pixel_lab_frame_count": PIXELLAB_FRAME_COUNT,
		"pixel_lab_frame_index": flail_ghost.frame if flail_ghost != null else -1,
		"visual_only": true,
	}
