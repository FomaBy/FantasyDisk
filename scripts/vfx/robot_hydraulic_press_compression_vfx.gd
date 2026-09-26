class_name RobotHydraulicPressCompressionVfx
extends Node2D

## Animator-owned visual choreography for SCRUM-917. This node contains no
## damage, targeting, compression displacement, cooldown or balance logic.
## The live hit remains in ClassWeapon at the existing 0.20 second delay.
## FAN-2981: the corridor is expressed by the authored PixelLab compression
## frames alone — the former Line2D rails/jaws/axis were zone markup.

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

	set_meta("corridor_start", start)
	set_meta("corridor_finish", finish)
	set_meta("corridor_length_px", _corridor_length)
	set_meta("corridor_width_px", _corridor_width)
	set_meta("centre_width_px", _centre_width)
	set_meta("active_delay_seconds", _active_delay)
	set_meta("compression_axis", "perpendicular_to_attack")
	set_meta("active_frame_reached", false)

	var fade := create_tween()
	fade.tween_interval(maxf(_active_delay - 0.025, 0.0))
	fade.tween_property(self, "modulate:a", 0.0, FINISH_FADE_SECONDS).set_delay(0.035)

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
