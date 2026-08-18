class_name BerserkAxeCleaveVfx
extends Node2D

## Animator-only SCRUM-895 weapon readability. Damage membership remains in
## BerserkWeapon; this node mirrors its sweep radius/angle without changing it.
## FAN-2981: the sector is expressed only by the shared AttackVfx slash layer
## plus the PixelLab axe ghost — no Line2D/Polygon2D zone markup.

const EFFECT_ID := "berserk_axe_pixel_lab_cleave"
const PIXELLAB_OBJECT_ID := "d5452069-7d6e-4646-8b9d-379f0c332f17"
const PIXELLAB_ANIMATION_GROUP_ID := "7e9c7287-d8f0-4461-844e-c1e0bfc5e817"
const FRAME_COUNT := 8

@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var axe_ghost: AnimatedSprite2D = $WeaponPivot/AxeGhost

var _radius := 0.0
var _sweep_degrees := 0.0


func _ready() -> void:
	add_to_group("player_weapon_effects")
	set_meta("effect_id", EFFECT_ID)
	set_meta("visual_only", true)
	set_meta("pixellab_object_id", PIXELLAB_OBJECT_ID)
	set_meta("pixellab_animation_group_id", PIXELLAB_ANIMATION_GROUP_ID)


func configure(
	center: Vector2,
	direction: Vector2,
	radius: float,
	sweep_degrees: float,
	duration: float,
	_color: Color
) -> void:
	_ensure_nodes()
	if axe_ghost == null:
		return
	global_position = center
	rotation = direction.normalized().angle()
	_radius = maxf(radius, 32.0)
	_sweep_degrees = clampf(sweep_degrees, 20.0, 220.0)
	var half_sweep := deg_to_rad(_sweep_degrees * 0.5)

	weapon_pivot.rotation = -half_sweep
	axe_ghost.position = Vector2(_radius * 0.43, 0.0)
	axe_ghost.rotation = PI * 0.5
	axe_ghost.scale = Vector2.ONE * 0.58
	axe_ghost.modulate = Color(1.0, 0.88, 0.72, 0.94)
	axe_ghost.speed_scale = float(FRAME_COUNT) / maxf(duration, 0.08) / maxf(
		axe_ghost.sprite_frames.get_animation_speed(&"cleave"), 0.001
	)
	axe_ghost.play(&"cleave")
	var swing := create_tween()
	swing.set_parallel(true)
	swing.tween_property(weapon_pivot, "rotation", half_sweep, maxf(duration, 0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.tween_property(self, "modulate:a", 0.0, 0.12).set_delay(maxf(duration - 0.03, 0.05))
	swing.chain().tween_callback(queue_free)
	set_meta("radius_px", _radius)
	set_meta("sweep_degrees", _sweep_degrees)
	set_meta("weapon_ghost_present", true)
	set_meta("sword_changed", false)


func _ensure_nodes() -> void:
	if weapon_pivot == null: weapon_pivot = get_node_or_null("WeaponPivot") as Node2D
	if axe_ghost == null: axe_ghost = get_node_or_null("WeaponPivot/AxeGhost") as AnimatedSprite2D


func geometry_contract() -> Dictionary:
	return {
		"effect_id": EFFECT_ID,
		"radius_px": _radius,
		"sweep_degrees": _sweep_degrees,
		"frame_count": FRAME_COUNT,
		"weapon_ghost_present": axe_ghost != null,
		"visual_only": true,
	}
