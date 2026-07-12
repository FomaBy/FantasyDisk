class_name BerserkHammerSlamVfx
extends Node2D

## Animator-only SCRUM-895 hammer impact. The caller passes the exact backend
## center/radius/scale contract; this node contains no hit or balance logic.

const EFFECT_ID := "berserk_hammer_pixel_lab_slam"
const PIXELLAB_OBJECT_ID := "b1fed1f3-71b6-47d5-a1eb-e3e4b8db65b5"
const PIXELLAB_ANIMATION_GROUP_ID := "4515832c-5217-444d-a1a4-b25f1090d435"
const FRAME_COUNT := 8
const IMPACT_FRAME := 5

@onready var impact_fill: Polygon2D = $ImpactFill
@onready var shock_ring: Line2D = $ShockRing
@onready var inner_crack: Line2D = $InnerCrack
@onready var hammer_ghost: AnimatedSprite2D = $HammerGhost
@onready var impact_flash: Polygon2D = $ImpactFlash

var _radius := 0.0
var _visual_scale := Vector2.ONE


func _ready() -> void:
	add_to_group("player_weapon_effects")
	set_meta("effect_id", EFFECT_ID)
	set_meta("visual_only", true)
	set_meta("pixellab_object_id", PIXELLAB_OBJECT_ID)
	set_meta("pixellab_animation_group_id", PIXELLAB_ANIMATION_GROUP_ID)


func configure(center: Vector2, radius: float, visual_scale: Vector2, color: Color) -> void:
	_ensure_nodes()
	if hammer_ghost == null:
		return
	global_position = center
	_radius = maxf(radius, 32.0)
	_visual_scale = Vector2(maxf(visual_scale.x, 0.1), maxf(visual_scale.y, 0.1))
	var fill_points := PackedVector2Array()
	var ring_points := PackedVector2Array()
	for index in range(33):
		var angle := TAU * float(index) / 32.0
		var point := Vector2.from_angle(angle) * _radius * _visual_scale
		ring_points.append(point)
		if index < 32: fill_points.append(point)
	impact_fill.polygon = fill_points
	impact_fill.color = Color(color.r, color.g, color.b, 0.085)
	shock_ring.points = ring_points
	shock_ring.default_color = Color(0.86, 0.72, 1.0, 0.62)
	shock_ring.width = 8.0
	var crack_points := PackedVector2Array([Vector2(-_radius * 0.32, 0.0), Vector2(-_radius * 0.12, 5.0), Vector2.ZERO, Vector2(_radius * 0.18, -7.0), Vector2(_radius * 0.36, 3.0)])
	for index in range(crack_points.size()): crack_points[index] *= _visual_scale
	inner_crack.points = crack_points
	inner_crack.default_color = Color(1.0, 0.72, 0.30, 0.72)
	inner_crack.width = 6.0

	hammer_ghost.position = Vector2(0.0, -_radius * 0.30 * _visual_scale.y)
	hammer_ghost.scale = Vector2.ONE * 0.72
	hammer_ghost.modulate = Color(0.96, 0.88, 1.0, 0.96)
	hammer_ghost.play(&"slam")
	hammer_ghost.frame = IMPACT_FRAME
	impact_flash.scale = Vector2.ONE * (_radius / 90.0) * _visual_scale
	impact_flash.color = Color(1.0, 0.76, 0.30, 0.58)

	shock_ring.scale = Vector2.ONE * 0.42
	var impact := create_tween()
	impact.set_parallel(true)
	impact.tween_property(shock_ring, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	impact.tween_property(impact_flash, "modulate:a", 0.0, 0.13)
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
	if impact_fill == null: impact_fill = get_node_or_null("ImpactFill") as Polygon2D
	if shock_ring == null: shock_ring = get_node_or_null("ShockRing") as Line2D
	if inner_crack == null: inner_crack = get_node_or_null("InnerCrack") as Line2D
	if hammer_ghost == null: hammer_ghost = get_node_or_null("HammerGhost") as AnimatedSprite2D
	if impact_flash == null: impact_flash = get_node_or_null("ImpactFlash") as Polygon2D


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
