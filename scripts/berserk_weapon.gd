class_name BerserkWeapon
extends Node2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const EXACT_ZONE_OVERLAY_ALPHA := 0.60
const CONTACT_STUCK_HIT_RADIUS := 40.0

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
@export var max_aoe_radius := 0.0
@export var sweep_degrees := 70.0
@export var circle_full_targets := 0
@export var circle_target_diminish := 0.0
@export var windup_time := 0.06
@export var swing_time := 0.14
@export var recover_time := 0.08
@export var melee_close_bonus_radius := 0.0
@export var melee_close_damage_multiplier := 1.0
@export var melee_execute_threshold := 0.0
@export var melee_execute_multiplier := 1.0
@export var melee_stagger_knockback_multiplier := 0.0
@export var melee_arc_followup_radius := 0.0
@export var melee_arc_followup_multiplier := 0.0
@export var visual_color := Color(0.62, 0.82, 1.0, 0.30)

var _cooldown := 0.0
var _last_direction := Vector2.RIGHT
var _swinging := false
var _hit_targets := []
var _swing_tween: Tween = null
var _swing_timing_tween: Tween = null
var _last_attack_crit := false
# SCRUM-961 «Святая цепь»: раскрутка спирали кистеня (касты подряд, сброс паузой).
var _flail_spiral_casts := 0
var _flail_last_cast_ms := 0


# SCRUM-961: чтение ключа классового артефакта из run_modifiers владельца.
func _owner_mod(key: String, default_value := 0.0) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return default_value
	var mods = owner_node.get("run_modifiers")
	if mods is Dictionary:
		return float((mods as Dictionary).get(key, default_value))
	return default_value


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
	max_aoe_radius = float(config.get("max_aoe_radius", max_aoe_radius))
	sweep_degrees = float(config.get("sweep_degrees", sweep_degrees))
	circle_full_targets = int(config.get("circle_full_targets", circle_full_targets))
	circle_target_diminish = float(config.get("circle_target_diminish", circle_target_diminish))
	windup_time = float(config.get("windup_time", windup_time))
	swing_time = float(config.get("swing_time", swing_time))
	recover_time = float(config.get("recover_time", recover_time))
	melee_close_bonus_radius = float(config.get("melee_close_bonus_radius", melee_close_bonus_radius))
	melee_close_damage_multiplier = float(config.get("melee_close_damage_multiplier", melee_close_damage_multiplier))
	melee_execute_threshold = float(config.get("melee_execute_threshold", melee_execute_threshold))
	melee_execute_multiplier = float(config.get("melee_execute_multiplier", melee_execute_multiplier))
	melee_stagger_knockback_multiplier = float(config.get("melee_stagger_knockback_multiplier", melee_stagger_knockback_multiplier))
	melee_arc_followup_radius = float(config.get("melee_arc_followup_radius", melee_arc_followup_radius))
	melee_arc_followup_multiplier = float(config.get("melee_arc_followup_multiplier", melee_arc_followup_multiplier))
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
	_update_flail_spiral()

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation("attack", _last_direction)

	_animate_weapon(_last_direction)
	if immediate_damage:
		_damage_window(owner_node, _last_direction)
		_finish_swing()
		return

	# Tween на оружии замораживается паузой, чтобы окно урона не тикало в level-up/Escape.
	# SCRUM-551: храним ссылку и гасим прошлый таймер-твин — иначе при force-free оружия
	# (mass-free между замерами в character_balance_csv.gd) висящий swing-таймер дёргал
	# _finish_swing/lambda на уже освобождённом узле → нативный SIGABRT (freed object/lambda),
	# из-за чего balance-CSV падал на berserk-строках и не собирался.
	if _swing_timing_tween != null and _swing_timing_tween.is_valid():
		_swing_timing_tween.kill()
	_swing_timing_tween = create_tween()
	_swing_timing_tween.tween_interval(windup_time)
	_swing_timing_tween.tween_callback(func() -> void:
		if is_instance_valid(owner_node):
			_damage_window(owner_node, _last_direction)
	)
	_swing_timing_tween.tween_interval(swing_time + recover_time)
	_swing_timing_tween.tween_callback(_finish_swing)


func _finish_swing() -> void:
	if is_queued_for_deletion():
		return
	_swinging = false
	_hit_targets.clear()


func _exit_tree() -> void:
	# Оружие покидает дерево (смена оружия ИЛИ каскадный force-free игрока) —
	# гасим оба твина, чтобы их отложенные колбэки не сработали по freed-self.
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	if _swing_timing_tween != null and _swing_timing_tween.is_valid():
		_swing_timing_tween.kill()
	_swing_tween = null
	_swing_timing_tween = null


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
	var candidates: Array = []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node):
			continue
		if not _is_enemy_inside_attack(owner_node, enemy_node, attack_direction):
			continue
		if enemy_node.has_method("take_damage"):
			candidates.append(enemy_node)
	if attack_shape == "circle" and circle_target_diminish > 0.0 and candidates.size() > 1:
		candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return owner_node.global_position.distance_squared_to(a.global_position) < owner_node.global_position.distance_squared_to(b.global_position)
		)
	for index in range(candidates.size()):
		_damage_target(owner_node, candidates[index] as Node2D, attack_direction, _circle_damage_factor(index))
	# SCRUM-961 «Тройной укол»: копьё колет тремя полосами (центр уже отработал).
	if attack_shape == "strip" and _owner_mod("spear_triple_thrust") > 0.0:
		_damage_triple_thrust_sides(owner_node, attack_direction)
	# SCRUM-961 «Призрачный топор»: видимый спектральный повтор взмаха.
	if melee_arc_followup_radius > 0.0 and _owner_mod("spectral_followup_bonus") > 0.0 and not candidates.is_empty():
		_show_spectral_followup(owner_node, attack_direction)


# SCRUM-961 «Тройной укол»: боковые быстрые уколы ±14° (55% урона) закрывают
# слабость узкой полосы копья против веера врагов; дедуп через _hit_targets.
func _damage_triple_thrust_sides(owner_node: Node2D, attack_direction: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	for side in [-1.0, 1.0]:
		var side_direction := attack_direction.rotated(deg_to_rad(14.0) * float(side))
		AttackVfx.beam(scene, owner_node.global_position + side_direction * start_distance, owner_node.global_position + side_direction * attack_range, inner_width * 0.7, Color(visual_color.r, visual_color.g, visual_color.b, 0.22))
		for enemy_node in TARGET_QUERY.enemies(self):
			if not is_instance_valid(enemy_node) or _hit_targets.has(enemy_node):
				continue
			if not _is_enemy_inside_frustum(owner_node, enemy_node, side_direction):
				continue
			if enemy_node.has_method("take_damage"):
				_damage_target(owner_node, enemy_node, side_direction, 0.55)


# SCRUM-961 «Призрачный топор»: полупрозрачный призрачный взмах-афтеримидж
# по той же дуге с короткой задержкой (существующий slash-VFX, без новых ассетов).
func _show_spectral_followup(owner_node: Node2D, attack_direction: Vector2) -> void:
	var owner_id := owner_node.get_instance_id()
	var ghost_tween := create_tween()
	ghost_tween.tween_interval(0.12)
	ghost_tween.tween_callback(func() -> void:
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_owner == null or not is_instance_valid(current_owner):
			return
		var ghost := AttackVfx.slash(current_owner, attack_direction, attack_range, Color(0.55, 0.82, 1.0, 0.30), PI, _sweep_visual_lateral_scale(), _sweep_visual_degrees())
		if ghost != null:
			ghost.add_to_group("player_weapon_effects")
	)


# SCRUM-961 «Святая цепь»: последовательные касты раскручивают спираль кистеня
# (+12% радиуса за каст после первого, кап +36%); пауза 3с сбрасывает раскрутку.
func _update_flail_spiral() -> void:
	if weapon_id != "holy_flail" or _owner_mod("flail_spiral_growth") <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if now - _flail_last_cast_ms > 3000:
		_flail_spiral_casts = 0
	_flail_last_cast_ms = now
	_flail_spiral_casts = mini(_flail_spiral_casts + 1, 4)


func _damage_target(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2, amount_multiplier := 1.0) -> void:
	_hit_targets.append(enemy_node)
	var dealt := _rolled_damage(owner_node) * amount_multiplier
	_call_take_damage(enemy_node, dealt, {"critical": _last_attack_crit, "damage_type": "physical"})
	if owner_node.has_method("on_weapon_hit"):
		owner_node.on_weapon_hit(enemy_node, dealt, _last_attack_crit)  # SCRUM-500: прокидываем крит-флаг
	_apply_unique_melee_hit_effects(owner_node, enemy_node, attack_direction, dealt)


func _circle_damage_factor(target_index: int) -> float:
	if attack_shape != "circle" or circle_target_diminish <= 0.0:
		return 1.0
	var full_targets := maxi(circle_full_targets, 1)
	var diminish := circle_target_diminish
	# SCRUM-961 «Вес молота»: слэм полновесно накрывает больше целей (4→6),
	# хвост толпы гаснет по спеке (0.62→0.78); одиночный DPS не трогается.
	if weapon_id == "hammer" and _owner_mod("hammer_slam_focus") > 0.0:
		full_targets += 2
		diminish += 0.16
	if target_index < full_targets:
		return 1.0
	return 1.0 / (1.0 + float(target_index - full_targets + 1) * diminish)


func _apply_unique_melee_hit_effects(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2, amount: float) -> void:
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	if owner_node == null or not is_instance_valid(owner_node):  # SCRUM-631: owner_node мог быть освобождён между _damage_window и колбэком
		return
	var distance := owner_node.global_position.distance_to(enemy_node.global_position)
	if melee_close_bonus_radius > 0.0 and melee_close_damage_multiplier > 1.0 and distance <= melee_close_bonus_radius:
		enemy_node.take_damage(amount * (melee_close_damage_multiplier - 1.0))
	if melee_execute_threshold > 0.0 and melee_execute_multiplier > 1.0:
		var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
		var health := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
		if max_hp > 0.0 and health / max_hp <= melee_execute_threshold:
			enemy_node.take_damage(amount * (melee_execute_multiplier - 1.0))
	if melee_stagger_knockback_multiplier > 0.0:
		var push_direction := enemy_node.global_position - owner_node.global_position
		if push_direction.length_squared() <= 0.001:
			push_direction = attack_direction
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(push_direction.normalized() * 260.0 * melee_stagger_knockback_multiplier)
	# SCRUM-961 «Призрачный топор»: спектральный повтор усиливает followup-дугу
	# (0.12→0.37 у топора); работает только на оружии с followup-геометрией.
	var followup_multiplier := melee_arc_followup_multiplier
	if melee_arc_followup_radius > 0.0:
		followup_multiplier += _owner_mod("spectral_followup_bonus")
	if melee_arc_followup_radius > 0.0 and followup_multiplier > 0.0:
		var splash_damage := amount * followup_multiplier
		for nearby in TARGET_QUERY.in_radius(self, enemy_node.global_position, melee_arc_followup_radius):
			if nearby == enemy_node:
				continue
			if nearby.has_method("take_damage"):
				nearby.take_damage(splash_damage)


func _target_direction(owner_node: Node2D) -> Vector2:
	if owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor":
		return owner_node.call("attack_aim_direction", _last_direction, attack_range)
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
	var max_distance := attack_range if range_limit < 0.0 else range_limit
	return TARGET_QUERY.nearest(self, owner_node.global_position, max_distance)


func _is_enemy_inside_attack(owner_node: Node2D, enemy_node: Node2D, attack_direction: Vector2) -> bool:
	if owner_node.global_position.distance_squared_to(enemy_node.global_position) <= CONTACT_STUCK_HIT_RADIUS * CONTACT_STUCK_HIT_RADIUS:
		return true
	if attack_shape == "circle":
		var radius := _effective_circle_radius()
		return owner_node.global_position.distance_squared_to(enemy_node.global_position) <= radius * radius
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


func _call_take_damage(enemy: Node, amount: float, feedback := {}) -> void:
	if _take_damage_accepts_feedback(enemy):
		enemy.call("take_damage", amount, feedback)
	else:
		enemy.call("take_damage", amount)


func _take_damage_accepts_feedback(enemy: Node) -> bool:
	for method in enemy.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			var args: Array = method.get("args", [])
			if args.size() < 2:
				return false
			var script: Script = enemy.get_script()
			if script != null and str(script.resource_path) in ["res://scripts/enemy.gd", "res://scripts/boss.gd"]:
				return true
			return enemy.is_in_group("enemies") and enemy.has_method("_show_combat_feedback")
	return false


func _rolled_damage(owner_node: Node2D) -> float:
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage

	var parameters: Dictionary = raw_parameters
	var result := damage
	_last_attack_crit = false
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
		_last_attack_crit = true
	return result


func _show_hit_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	_show_weapon_signature(owner_node, attack_direction)
	if attack_shape == "circle":
		_show_circle_area(owner_node)
	elif attack_shape == "sweep":
		_show_sweep_area(owner_node, attack_direction)
	elif attack_shape == "strip":
		_show_strip_area(owner_node, attack_direction)
	else:
		_show_frustum_area(owner_node, attack_direction)


func _show_weapon_signature(owner_node: Node2D, attack_direction: Vector2) -> void:
	if owner_node == null or attack_direction.length_squared() <= 0.001:
		return
	var direction := attack_direction.normalized()
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	var center := owner_node.global_position + direction * minf(maxf(attack_range * 0.45, 72.0), 260.0)
	var radius := maxf(aoe_radius, inner_width * 1.45)
	if attack_shape == "circle":
		center = owner_node.global_position
		radius = maxf(_effective_circle_radius(), 96.0)
	elif attack_shape == "strip":
		center = owner_node.global_position + direction * ((start_distance + attack_range) * 0.5)
		radius = maxf(inner_width * 2.0, 96.0)
	var weapon_texture: Texture2D = null
	var weapon_rotation := 0.0
	var weapon_scale := 0.58
	var weapon_offset := Vector2.ZERO
	if weapon_id == "axe":
		var weapon_visual := get_node_or_null("WeaponVisual") as Sprite2D
		if weapon_visual != null and weapon_visual.texture != null:
			weapon_texture = weapon_visual.texture
			weapon_scale = 0.62
			weapon_offset = Vector2(10.0, -2.0)
	var signature := AttackVfx.weapon_signature(
		scene,
		center,
		weapon_id,
		radius,
		visual_color,
		direction.angle(),
		weapon_texture,
		weapon_rotation,
		weapon_scale,
		weapon_offset
	)
	if signature != null:
		signature.add_to_group("player_weapon_effects")


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
	overlay.name = "BerserkExactAttackZone"
	overlay.color = Color(visual_color.r, visual_color.g, visual_color.b, EXACT_ZONE_OVERLAY_ALPHA)
	overlay.polygon = points
	overlay.z_index = 9
	owner_node.add_child(overlay)
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.18)
	tween.tween_callback(overlay.queue_free)


func _show_frustum_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	AttackVfx.slash(owner_node, attack_direction, attack_range, visual_color)


func _show_sweep_area(owner_node: Node2D, attack_direction: Vector2) -> void:
	var slash := AttackVfx.slash(
		owner_node,
		attack_direction,
		attack_range,
		visual_color,
		PI,
		_sweep_visual_lateral_scale(),
		_sweep_visual_degrees()
	)
	if slash != null:
		slash.add_to_group("player_weapon_effects")


func _sweep_visual_lateral_scale() -> float:
	if weapon_id != "axe":
		return 1.0
	return clampf(sweep_degrees / 110.0, 1.0, 1.75)


func _sweep_visual_degrees() -> float:
	if weapon_id != "axe":
		return 0.0
	return sweep_degrees


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
	AttackVfx.hammer_slam(scene, owner_node.global_position, _effective_circle_radius(), visual_color)


func _effective_circle_radius() -> float:
	var radius := aoe_radius
	if max_aoe_radius > 0.0:
		radius = minf(aoe_radius, max_aoe_radius)
	# SCRUM-961 «Вес молота»: слэм ложится шире (+12%).
	if weapon_id == "hammer" and _owner_mod("hammer_slam_focus") > 0.0:
		radius *= 1.12
	# SCRUM-961 «Святая цепь»: спираль раскручена от последовательных кастов.
	if weapon_id == "holy_flail" and _owner_mod("flail_spiral_growth") > 0.0:
		radius *= 1.0 + 0.12 * float(maxi(_flail_spiral_casts - 1, 0))
	return radius


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
	if not has_meta("base_max_aoe_radius"):
		set_meta("base_max_aoe_radius", max_aoe_radius)
	if not has_meta("base_inner_width"):
		set_meta("base_inner_width", inner_width)
	if not has_meta("base_outer_width"):
		set_meta("base_outer_width", outer_width)
