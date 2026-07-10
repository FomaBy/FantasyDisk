class_name StormLongbowVolleyVfx
extends Node2D

## Animator-owned visual resource for SCRUM-912. It deliberately contains no
## damage, targeting, cooldown, pierce, or hit-query logic. The live gameplay
## contract remains in ClassWeapon._fire_storm_pierce_cone().

const EFFECT_ID := "storm_longbow_piercing_release"
const BEAM_COUNT := 5
const CONE_DEGREES := 34.0
const BEAM_WIDTH_PX := 30.0
const ATTACK_RANGE_PX := 980.0
const ORIGIN_FORWARD_PX := 26.0
const PIERCE_COUNT := 4
const ARROW_OFFSETS_DEGREES := [-17.0, -8.5, 0.0, 8.5, 17.0]

# PixelLab source normalization. Pixel (26, 128) is the release pivot and
# pixel 230 is the authored trail endpoint, leaving >= 13 px transparent gutter.
const SOURCE_CANVAS_PX := 256.0
const SOURCE_ORIGIN := Vector2(26.0, 128.0)
const SOURCE_ENDPOINT_X := 230.0
const SOURCE_TRAVEL_PX := SOURCE_ENDPOINT_X - SOURCE_ORIGIN.x
const RELEASE_FPS := 16.0
const RELEASE_FRAME_COUNT := 8
const RELEASE_DURATION_SECONDS := float(RELEASE_FRAME_COUNT) / RELEASE_FPS

@export var auto_free_on_finish := true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player_weapon_effects")
	set_meta("effect_id", EFFECT_ID)
	set_meta("beam_count", BEAM_COUNT)
	set_meta("cone_degrees", CONE_DEGREES)
	set_meta("beam_width_px", BEAM_WIDTH_PX)
	set_meta("attack_range_px", ATTACK_RANGE_PX)
	set_meta("origin_forward_px", ORIGIN_FORWARD_PX)
	set_meta("pierce_count", PIERCE_COUNT)
	set_meta("arrow_offsets_degrees", ARROW_OFFSETS_DEGREES)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play("release")


func configure(origin: Vector2, direction: Vector2, visual_range := ATTACK_RANGE_PX) -> void:
	var aim := direction.normalized()
	if aim.length_squared() <= 0.001:
		aim = Vector2.RIGHT
	global_position = origin + aim * ORIGIN_FORWARD_PX
	rotation = aim.angle()
	var travel_world := maxf(float(visual_range) - ORIGIN_FORWARD_PX, 1.0)
	var uniform_scale := travel_world / SOURCE_TRAVEL_PX
	scale = Vector2.ONE * uniform_scale


func geometry_contract() -> Dictionary:
	return {
		"effect_id": EFFECT_ID,
		"beam_count": BEAM_COUNT,
		"cone_degrees": CONE_DEGREES,
		"beam_width_px": BEAM_WIDTH_PX,
		"attack_range_px": ATTACK_RANGE_PX,
		"origin_forward_px": ORIGIN_FORWARD_PX,
		"pierce_count": PIERCE_COUNT,
		"arrow_offsets_degrees": ARROW_OFFSETS_DEGREES.duplicate(),
		"release_fps": RELEASE_FPS,
		"release_frame_count": RELEASE_FRAME_COUNT,
		"release_duration_seconds": RELEASE_DURATION_SECONDS,
	}


func _on_animation_finished() -> void:
	if auto_free_on_finish and animated_sprite.animation == &"release":
		queue_free()
