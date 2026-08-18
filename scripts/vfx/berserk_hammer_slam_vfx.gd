class_name BerserkHammerSlamVfx
extends Node2D

## Animator-only SCRUM-895 hammer impact. The caller passes the exact backend
## center/radius/scale contract; this node contains no hit or balance logic.
## FAN-2981: the textured impact ring/flash/dust is drawn by the shared
## AttackVfx.hammer_slam layer spawned by the weapon bridge — this node only
## carries the PixelLab hammer ghost, with no zone markup of its own.

const EFFECT_ID := "berserk_hammer_pixel_lab_slam"
const PIXELLAB_OBJECT_ID := "b1fed1f3-71b6-47d5-a1eb-e3e4b8db65b5"
const PIXELLAB_ANIMATION_GROUP_ID := "4515832c-5217-444d-a1a4-b25f1090d435"
const FRAME_COUNT := 8
const IMPACT_FRAME := 5

@onready var hammer_ghost: AnimatedSprite2D = $HammerGhost

var _radius := 0.0
var _visual_scale := Vector2.ONE


func _ready() -> void:
	add_to_group("player_weapon_effects")
	set_meta("effect_id", EFFECT_ID)
	set_meta("visual_only", true)
	set_meta("pixellab_object_id", PIXELLAB_OBJECT_ID)
	set_meta("pixellab_animation_group_id", PIXELLAB_ANIMATION_GROUP_ID)


func configure(center: Vector2, radius: float, visual_scale: Vector2, _color: Color) -> void:
	_ensure_nodes()
	if hammer_ghost == null:
		return
	global_position = center
	_radius = maxf(radius, 32.0)
	_visual_scale = Vector2(maxf(visual_scale.x, 0.1), maxf(visual_scale.y, 0.1))

	hammer_ghost.position = Vector2(0.0, -_radius * 0.30 * _visual_scale.y)
	hammer_ghost.scale = Vector2.ONE * 0.72
	hammer_ghost.modulate = Color(0.96, 0.88, 1.0, 0.96)
	hammer_ghost.play(&"slam")
	hammer_ghost.frame = IMPACT_FRAME

	var impact := create_tween()
	impact.set_parallel(true)
	impact.tween_property(hammer_ghost, "modulate:a", 0.0, 0.22).set_delay(0.08)
	impact.tween_property(self, "modulate:a", 0.0, 0.16).set_delay(0.12)
	impact.chain().tween_callback(queue_free)
	set_meta("center", center)
	set_meta("radius_px", _radius)
	set_meta("visual_scale", _visual_scale)
	set_meta("impact_frame", IMPACT_FRAME)
	set_meta("weapon_ghost_present", true)
	set_meta("sword_changed", false)


func _ensure_nodes() -> void:
	if hammer_ghost == null: hammer_ghost = get_node_or_null("HammerGhost") as AnimatedSprite2D


func geometry_contract() -> Dictionary:
	return {
		"effect_id": EFFECT_ID,
		"radius_px": _radius,
		"visual_scale": _visual_scale,
		"frame_count": FRAME_COUNT,
		"impact_frame": IMPACT_FRAME,
		"weapon_ghost_present": hammer_ghost != null,
		"visual_only": true,
	}
