extends Area2D

@export var speed := 600.0
@export var lifetime := 2.0

const ARENA_SIZE := Vector2(4096, 2304)  # SCRUM-518: синхронно с main.gd (×1.6)
const CLEANUP_MARGIN := 180.0

const TRAIL_POINTS := 9

var damage := 1.0
var direction := Vector2.RIGHT
var _trail: Line2D = null
var _trail_color := Color(0.62, 0.86, 1.0, 0.7)


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
	_build_trail()


func _build_trail() -> void:
	# Дешёвый трейл-полоса в мировом пространстве (одна нода, без аллокаций нод
	# в кадре): тянется за снарядом и сужается к хвосту.
	_trail = Line2D.new()
	_trail.top_level = true            # игнорировать трансформ снаряда -> мировые координаты
	_trail.z_index = -1
	_trail.width = 9.0
	_trail.width_curve = _trail_taper()
	_trail.default_color = _trail_color
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)
	_trail.add_point(global_position)


func _trail_taper() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.05))   # хвост тонкий
	curve.add_point(Vector2(1.0, 1.0))    # голова широкая
	return curve


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	_update_trail()

	if lifetime <= 0.0 or _is_outside_arena():
		queue_free()


func _update_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)


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
