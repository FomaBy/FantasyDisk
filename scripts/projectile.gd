extends Area2D

@export var speed := 600.0
@export var lifetime := 2.0

const ARENA_SIZE := Vector2(2560, 1440)
const CLEANUP_MARGIN := 180.0

var damage := 1.0
var direction := Vector2.RIGHT


func setup(start_position: Vector2, target_position: Vector2, projectile_damage: float) -> void:
	global_position = start_position
	damage = projectile_damage

	var target_direction := target_position - start_position
	if target_direction.length_squared() > 0.0:
		direction = target_direction.normalized()

	rotation = direction.angle()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)


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
	if not body.is_in_group("enemies"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
