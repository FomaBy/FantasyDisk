extends Area2D

@export var lifetime := 3.0

const ARENA_SIZE := Vector2(2560, 1440)
const CLEANUP_MARGIN := 180.0
const TRAIL_TEXTURE := preload("res://assets/sprites/effects/beam_strip.png")
const IMPACT_FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const IMPACT_RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")

var damage := 1.0
var direction := Vector2.RIGHT
var speed := 360.0
var _has_hit := false


func setup(start_position: Vector2, target_position: Vector2, projectile_damage: float, projectile_speed: float) -> void:
	global_position = start_position
	damage = projectile_damage
	speed = projectile_speed

	var target_direction := target_position - start_position
	if target_direction.length_squared() > 0.0:
		direction = target_direction.normalized()

	rotation = direction.angle()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemy_projectiles")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_configure_trail()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta

	if lifetime <= 0.0 or _is_outside_arena():
		queue_free()


func _is_outside_arena() -> bool:
	return (
		global_position.x < -CLEANUP_MARGIN
		or global_position.x > ARENA_SIZE.x + CLEANUP_MARGIN
		or global_position.y < -CLEANUP_MARGIN
		or global_position.y > ARENA_SIZE.y + CLEANUP_MARGIN
	)


func _on_body_entered(body: Node) -> void:
	if _has_hit:
		return
	if not body.is_in_group("player"):
		return

	_has_hit = true
	if body.has_method("take_damage"):
		body.take_damage(damage, "projectile")

	_spawn_impact_vfx()
	queue_free()


func _configure_trail() -> void:
	var shape := get_node_or_null("Shape") as Sprite2D
	if shape == null:
		return
	var trail := Sprite2D.new()
	trail.name = "ProjectileTrailVfx"
	trail.texture = TRAIL_TEXTURE
	trail.position = Vector2(-34.0, 0.0)
	trail.scale = Vector2(0.30, 0.26)
	trail.z_index = -1
	trail.modulate = Color(0.72, 0.34, 1.0, 0.46)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trail.material = material
	add_child(trail)

	var tween := trail.create_tween()
	tween.set_loops()
	tween.tween_property(trail, "scale:x", 0.38, 0.16).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(trail, "modulate:a", 0.62, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(trail, "scale:x", 0.26, 0.16).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(trail, "modulate:a", 0.34, 0.16).set_trans(Tween.TRANS_SINE)


func _spawn_impact_vfx() -> void:
	if not is_inside_tree():
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var impact := Node2D.new()
	impact.name = "EnemyProjectileImpactVfx"
	impact.global_position = global_position
	impact.z_index = 13
	parent.add_child(impact)

	var flash := _additive_sprite(IMPACT_FLASH_TEXTURE, Color(0.86, 0.42, 1.0, 0.86))
	flash.scale = Vector2.ONE * 0.42
	impact.add_child(flash)

	var ring := _additive_sprite(IMPACT_RING_TEXTURE, Color(0.72, 0.34, 1.0, 0.72))
	ring.scale = Vector2.ONE * 0.18
	impact.add_child(ring)

	var tween := impact.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 0.82, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.tween_property(ring, "scale", Vector2.ONE * 0.46, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.22).set_delay(0.04)
	tween.chain().tween_callback(impact.queue_free)


func _additive_sprite(texture: Texture2D, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.modulate = color
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	return sprite
