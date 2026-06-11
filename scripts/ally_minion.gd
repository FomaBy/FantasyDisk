extends CharacterBody2D

@export var move_speed := 230.0
@export var damage := 1.5
@export var attack_range := 24.0
@export var attack_interval := 0.45
@export var lifetime := 12.0

var _attack_cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("allies")


func _physics_process(delta: float) -> void:
	lifetime -= delta
	_attack_cooldown -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var target := _find_closest_enemy()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	if to_target.length() <= attack_range:
		velocity = Vector2.ZERO
		_try_attack(target)
	else:
		velocity = to_target.normalized() * move_speed

	move_and_slide()


func _find_closest_enemy() -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue

		var distance := global_position.distance_squared_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node

	return closest_enemy


func _try_attack(target: Node2D) -> void:
	if _attack_cooldown > 0.0:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)

	_attack_cooldown = attack_interval
