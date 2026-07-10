class_name RobotHydraulicPressCompressionVfx
extends Node2D

## Animator-owned visual choreography for SCRUM-917. This node contains no
## damage, targeting, compression displacement, cooldown or balance logic.
## The live hit remains in ClassWeapon at the existing 0.20 second delay.

signal crush_frame_reached

const EFFECT_ID := "robot_hydraulic_press_side_to_center_crush"
const PIXELLAB_OBJECT_ID := "99b9c7ec-23d3-4110-a22a-912cf8b455b8"
const PIXELLAB_ANIMATION_GROUP_ID := "659bdae5-22a9-4319-a3ca-57b972e5a9a3"
const SOURCE_CANVAS_PX := 256.0
const FRAME_COUNT := 8
const ACTIVE_FRAME_INDEX := 5
const ACTIVE_DELAY_SECONDS := 0.20
const PLAYBACK_FPS := float(ACTIVE_FRAME_INDEX) / ACTIVE_DELAY_SECONDS
const FINISH_FADE_SECONDS := 0.08

@export var auto_free_on_finish := true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var upper_jaw: Line2D = $UpperJaw
@onready var lower_jaw: Line2D = $LowerJaw
@onready var upper_pressure: Line2D = $UpperPressure
@onready var lower_pressure: Line2D = $LowerPressure
@onready var impact_axis: Line2D = $ImpactAxis

var _configured := false
var _crush_emitted := false
var _corridor_length := 0.0
var _corridor_width := 0.0
var _centre_width := 0.0
var _active_delay := ACTIVE_DELAY_SECONDS


func _ready() -> void:
	add_to_group("player_weapon_effects")
	set_meta("effect_id", EFFECT_ID)
	set_meta("visual_only", true)
	set_meta("pixellab_object_id", PIXELLAB_OBJECT_ID)
	set_meta("pixellab_animation_group_id", PIXELLAB_ANIMATION_GROUP_ID)
	set_meta("frame_count", FRAME_COUNT)
	set_meta("active_frame_index", ACTIVE_FRAME_INDEX)
	set_meta("active_delay_seconds", ACTIVE_DELAY_SECONDS)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)


func configure(
	start: Vector2,
	finish: Vector2,
	full_corridor_width: float,
	centre_beam_width: float,
	hit_delay: float,
	color: Color
) -> void:
	var delta := finish - start
	_corridor_length = maxf(delta.length(), 8.0)
	_corridor_width = maxf(full_corridor_width, centre_beam_width)
	_centre_width = maxf(centre_beam_width, 8.0)
	_active_delay = maxf(hit_delay, 0.08)
	global_position = (start + finish) * 0.5
	rotation = delta.angle()

	# PixelLab authored the jaws left/right on the source canvas. Rotating the
	# sprite by 90 degrees maps that convergence to the gameplay corridor's
	# perpendicular axis. The non-uniform scale then matches exact live length
	# and width without changing the stable centred pivot.
	animated_sprite.rotation = PI * 0.5
	animated_sprite.scale = Vector2(
		_corridor_width / SOURCE_CANVAS_PX,
		_corridor_length / SOURCE_CANVAS_PX
	)
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, minf(color.a + 0.18, 0.62))
	animated_sprite.speed_scale = PLAYBACK_FPS / maxf(
		animated_sprite.sprite_frames.get_animation_speed(&"compress"), 0.001
	)

	var half_length := _corridor_length * 0.5
	var half_width := _corridor_width * 0.5
	var centre_half := minf(_centre_width * 0.5, half_width * 0.72)
	var rail_color := Color(color.r, color.g, color.b, minf(color.a, 0.34))
	var pressure_color := Color(0.28, 0.94, 0.88, 0.30)
	for jaw in [upper_jaw, lower_jaw]:
		jaw.points = PackedVector2Array([Vector2(-half_length, 0.0), Vector2(half_length, 0.0)])
		jaw.default_color = rail_color
		jaw.width = clampf(_corridor_width * 0.055, 10.0, 18.0)
	for pressure in [upper_pressure, lower_pressure]:
		pressure.points = PackedVector2Array([Vector2(-half_length, 0.0), Vector2(half_length, 0.0)])
		pressure.default_color = pressure_color
		pressure.width = clampf(_corridor_width * 0.025, 5.0, 10.0)
	impact_axis.points = PackedVector2Array([Vector2(-half_length, 0.0), Vector2(half_length, 0.0)])
	impact_axis.width = clampf(_centre_width * 0.16, 10.0, 20.0)
	impact_axis.default_color = Color(0.52, 1.0, 0.94, 0.0)

	upper_jaw.position.y = -half_width
	lower_jaw.position.y = half_width
	upper_pressure.position.y = -half_width * 0.72
	lower_pressure.position.y = half_width * 0.72
	impact_axis.modulate.a = 0.0

	set_meta("corridor_start", start)
	set_meta("corridor_finish", finish)
	set_meta("corridor_length_px", _corridor_length)
	set_meta("corridor_width_px", _corridor_width)
	set_meta("centre_width_px", _centre_width)
	set_meta("active_delay_seconds", _active_delay)
	set_meta("jaw_start_offset_px", half_width)
	set_meta("jaw_impact_offset_px", centre_half)
	set_meta("compression_axis", "perpendicular_to_attack")
	set_meta("active_frame_reached", false)

	var squeeze := create_tween()
	squeeze.set_parallel(true)
	squeeze.tween_property(upper_jaw, "position:y", -centre_half, _active_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	squeeze.tween_property(lower_jaw, "position:y", centre_half, _active_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	squeeze.tween_property(upper_pressure, "position:y", -centre_half * 0.25, _active_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	squeeze.tween_property(lower_pressure, "position:y", centre_half * 0.25, _active_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	squeeze.tween_property(impact_axis, "modulate:a", 0.72, 0.035).set_delay(maxf(_active_delay - 0.025, 0.0))
	squeeze.chain().tween_property(impact_axis, "modulate:a", 0.0, FINISH_FADE_SECONDS)

	_configured = true
	animated_sprite.play(&"compress")


func geometry_contract() -> Dictionary:
	return {
		"effect_id": EFFECT_ID,
		"corridor_length_px": _corridor_length,
		"corridor_width_px": _corridor_width,
		"centre_width_px": _centre_width,
		"active_delay_seconds": _active_delay,
		"active_frame_index": ACTIVE_FRAME_INDEX,
		"frame_count": FRAME_COUNT,
		"fps": PLAYBACK_FPS,
		"source_canvas_px": SOURCE_CANVAS_PX,
		"pivot": Vector2(SOURCE_CANVAS_PX * 0.5, SOURCE_CANVAS_PX * 0.5),
		"compression_axis": "perpendicular_to_attack",
	}


func _on_frame_changed() -> void:
	if not _configured or _crush_emitted or animated_sprite.frame < ACTIVE_FRAME_INDEX:
		return
	_crush_emitted = true
	set_meta("active_frame_reached", true)
	crush_frame_reached.emit()


func _on_animation_finished() -> void:
	if auto_free_on_finish and animated_sprite.animation == &"compress":
		queue_free()
