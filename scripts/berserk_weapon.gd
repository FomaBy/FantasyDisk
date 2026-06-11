class_name BerserkWeapon
extends Node2D

@export var weapon_id := "sword"
@export var display_name := "Two-Handed Sword"
@export var attack_shape := "frustum"
@export var fire_interval := 0.75
@export var damage := 12.0
@export var attack_range := 260.0
@export var start_distance := 24.0
@export var inner_width := 54.0
@export var outer_width := 300.0
@export var aoe_radius := 190.0
@export var sweep_degrees := 70.0
@export var windup_time := 0.06
@export var swing_time := 0.14
@export var recover_time := 0.08
@export var visual_color := Color(0.62, 0.82, 1.0, 0.30)

var _cooldown := 0.0
var _last_direction := Vector2.RIGHT
var _swinging := false
var _hit_targets := []
var _swing_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	display_name = str(config.get("title", display_name))
	attack_shape = str(config.get("attack_shape", attack_shape))
	fire_interval = float(config.get("fire_interval", fire_interval))
	damage *= float(config.get("damage_multiplier", 1.0))
	attack_range = float(config.get("attack_range", attack_range))
	start_distance = float(config.get("start_distance", start_distance))
	inner_width = float(config.get("inner_width", inner_width))
	outer_width = float(config.get("outer_width", outer_width))
	aoe_radius = float(config.get("aoe_radius", aoe_radius))
	sweep_degrees = float(config.get("sweep_degrees", sweep_degrees))
	windup_time = float(config.get("windup_time", windup_time))
	swing_time = float(config.get("swing_time", swing_time))
	recover_time = float(config.get("recover_time", recover_time))
	visual_color = config.get("visual_color", visual_color)
	_capture_base_values()


func _process(delta: float) -> void:
	# Направление атаки задает только ближайший враг (см. _target_direction);
	# направление движения влияет лишь на walk-анимацию персонажа.
	_cooldown -= delta
	if _cooldown > 0.0 or _swinging:
		return

	_start_swing(false)


func _attack() -> void:
	_start_swing(true)


func _start_swing(immediate_damage := false) -> void:
	var owner_node := _owner_node()
	if owner_node == null:
		return

	var attack_direction := _target_direction(owner_node)
	if attack_direction.length_squared() == 0.0:
		attack_direction = _last_direction
	_last_direction = attack_direction.normalized()
	_swinging = true
	_hit_targets.clear()
	_cooldown = fire_interval

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("attack", _last_direction)

	_animate_weapon(_last_direction)
	if immediate_damage:
		_damage_window(owner_node, _last_direction)
		_finish_swing()
		return

	# Tween на оружии замораживается паузой, чтобы окно урона не тикало в level-up/Escape.
	var swing_timing_tween := create_tween()
	swing_timing_tween.tween_interval(windup_time)
	swing_timing_tween.tween_callback(func() -> void:
		if is_instance_valid(owner_node):
			_damage_window(owner_node, _last_direction)
	)
	swing_timing_tween.tween_interval(swing_time + recover_time)
	swing_timing_tween.tween_callback(_finish_swing)


func _finish_swing() -> void:
	_swinging = false
	_hit_targets.clear()


func _animate_weapon(direction: Vector2) -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()

	if attack_shape == "circle":
		_animate_hammer_slam(direction)
		return

	if attack_shape == "strip":
		_animate_thrust(direction)
		return

	var half_sweep := deg_to_rad(sweep_degrees * 0.5)
	var base_angle := direction.angle()
	rotation = base_angle - half_sweep
	position = direction.normalized() * 32.0

	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "rotation", base_angle + half_sweep, windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(self, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_thrust(direction: Vector2) -> void:
	# Быстрый колющий выпад вдоль полосы вместо дугового замаха.
	var base_angle := direction.angle()
	rotation = base_angle
	position = -direction.normalized() * 14.0

	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "position", direction.normalized() * 40.0, windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(self, "position", Vector2.ZERO, recover_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_hammer_slam(direction: Vector2) -> void:
	# Замах вверх, затем ускоряющееся падение молота в землю перед героем.
	var base_angle := direction.angle()
	rotation = base_angle - 1.9
	position = Vector2(0.0, -20.0)

	_swing_tween = create_tween()
	_swing_tween.set_parallel(true)
	_swing_tween.tween_property(self, "rotation", base_angle + 0.45, windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(self, "position", direction.normalized() * 30.0 + Vector2(0.0, 10.0), windup_time + swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing_tween.chain().tween_property(self, "rotation", base_angle, recover_time * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.parallel().tween_property(self, "position", Vector2.ZERO, recover_time * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _damage_window(owner_node: Node2D, attack_direction: Vector2) -> void:
	_show_hit_area(owner_node, attack_direction)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node):
			continue
		if not _is_enemy_inside_attack(owner_node, enemy_node, attack_direction):
			continue
		if enemy_node.has_method("take_damage"):
			_hit_targets.append(enemy_node)
			var dealt := _rolled_damage(owner_node)
			enemy_node.take_damage(dealt)
			if owner_node.has_method("on_weapon_hit"):
				owner_node.on_weapon_hit(enemy_node, dealt)


func _target_direction(owner_node: Node2D) -> Vector2:
	var closest_enemy := _find_closest_enemy(owner_node)
	if closest_enemy == null:
		closest_enemy = _find_closest_enemy(owner_node, INF)
	if closest_enemy == null:
		return _last_direction

	var direction := closest_enemy.global_position - owner_node.global_position
	if direction.length_squared() == 0.0:
		return _last_direction
	return direction.normalized()


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance := attack_range * attack_range if range_limit < 0.0 else range_limit
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node
	return closest_enemy


func _is_enemy_inside_attack(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	if attack_shape == "circle":
		return owner_node.global_position.distance_squared_to(enemy_node.global_position) <= aoe_radius * aoe_radius
	if attack_shape == "sweep":
		return _is_enemy_inside_sweep(owner_node, enemy_node, attack_direction)
	# "strip" — прямоугольная полоса: frustum с равными inner/outer width.
	return _is_enemy_inside_frustum(owner_node, enemy_node, attack_direction)


func _is_enemy_inside_sweep(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	var to_enemy := enemy_node.global_position - owner_node.global_position
	if to_enemy.length_squared() > attack_range * attack_range:
		return false
	if to_enemy.length_squared() <= 0.001:
		return true

	var direction := attack_direction.normalized()
	var angle_to_enemy: float = abs(wrapf(direction.angle_to(to_enemy.normalized()), -PI, PI))
	return angle_to_enemy <= deg_to_rad(sweep_degrees * 0.5) + 0.001


func _is_enemy_inside_frustum(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	var direction := attack_direction.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_node.global_position - owner_node.global_position
	var forward_distance := to_enemy.dot(direction)
	if forward_distance < start_distance or forward_distance > attack_range:
		return false

	var usable_length: float = max(attack_range - start_distance, 1.0)
	var distance_ratio: float = clamp((forward_distance - start_distance) / usable_length, 0.0, 1.0)
	var half_width := lerpf(inner_width * 0.5, outer_width * 0.5, distance_ratio)
	var side_distance: float = abs(to_enemy.dot(perpendicular))
	return side_distance <= half_width + 0.001


func _rolled_damage(owner_node: Node2D) -> float:
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage

	var parameters: Dictionary = raw_parameters
	var result := damage
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
	return result


func _show_hit_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	if attack_shape == "circle":
		_show_circle_area(owner_node)
	elif attack_shape == "sweep":
		_show_sweep_area(owner_node, attack_direction)
	elif attack_shape == "strip":
		_show_strip_area(owner_node, attack_direction)
	else:
		_show_frustum_area(owner_node, attack_direction)


func _show_strip_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	# Геометрия зоны урона: прямоугольник start_distance..attack_range шириной inner_width.
	var direction := attack_direction.normalized()
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var start: Vector2 = owner_node.global_position + direction * start_distance
	var finish: Vector2 = owner_node.global_position + direction * attack_range
	AttackVfx.beam(scene, start, finish, inner_width, visual_color)
	_show_exact_zone_overlay(owner_node, _strip_zone_points(direction))


func _strip_zone_points(direction: Vector2) -> PackedVector2Array:
	var perpendicular := Vector2(-direction.y, direction.x) * inner_width * 0.5
	return PackedVector2Array([
		direction * start_distance + perpendicular,
		direction * attack_range + perpendicular,
		direction * attack_range - perpendicular,
		direction * start_distance - perpendicular,
	])


func _show_exact_zone_overlay(owner_node: Node2D, points: PackedVector2Array) -> void:
	# Полупрозрачный контур фактической зоны урона поверх художественного VFX.
	var overlay := Polygon2D.new()
	overlay.color = Color(visual_color.r, visual_color.g, visual_color.b, minf(visual_color.a * 0.55, 0.22))
	overlay.polygon = points
	overlay.z_index = 9
	owner_node.add_child(overlay)
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.18)
	tween.tween_callback(overlay.queue_free)


func _show_frustum_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	AttackVfx.slash(owner_node, attack_direction, attack_range, visual_color)


func _show_sweep_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	AttackVfx.slash(owner_node, attack_direction, attack_range, visual_color)
	_show_exact_zone_overlay(owner_node, _sweep_zone_points(attack_direction.normalized()))


func _sweep_zone_points(direction: Vector2) -> PackedVector2Array:
	var half_sweep := deg_to_rad(sweep_degrees * 0.5)
	var points := PackedVector2Array([Vector2.ZERO])
	for point_index in range(17):
		var angle := lerpf(-half_sweep, half_sweep, float(point_index) / 16.0)
		points.append(direction.rotated(angle) * attack_range)
	return points


func _show_circle_area(owner_node: Node2D) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	AttackVfx.hammer_slam(scene, owner_node.global_position, aoe_radius, visual_color)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _capture_base_values() -> void:
	if not has_meta("base_damage"):
		set_meta("base_damage", damage)
	if not has_meta("base_fire_interval"):
		set_meta("base_fire_interval", fire_interval)
	if not has_meta("base_attack_range"):
		set_meta("base_attack_range", attack_range)
	if not has_meta("base_aoe_radius"):
		set_meta("base_aoe_radius", aoe_radius)
	if not has_meta("base_inner_width"):
		set_meta("base_inner_width", inner_width)
	if not has_meta("base_outer_width"):
		set_meta("base_outer_width", outer_width)
