extends Node2D

# SCRUM-906: орбитальный боевой дрон инженера («Орбитальный Дрон»).
# Кружит вокруг владельца (радиус спирали растёт со слотом: base × (1 + 0.14 ×
# slot)), фазы слотов равномерно распределены — несколько дронов читаются как
# спираль/кольцо, а не один спрайт. Наносит ФИЗИЧЕСКИЙ контактный урон каждому
# врагу на пути; per-enemy кулдаун (drone_hit_cooldown оружия) защищает от
# every-frame урона. Скорость орбиты = drone_orbit_speed × attack_speed
# (× (1 + drone_orbit_speed_bonus артефакта «Гироскоп дрона»)) — скорость атаки
# буквально раскручивает обороты (AC SCRUM-906). Урон идёт через
# weapon._rolled_damage (крит + summon_role-фактор Лидерства + «Сеть
# мастерской»); бюджет-зеркало — progression_data._budget_orbit_drone_dps.
# Чистка без утечек: узел зарегистрирован weapon._register_effect; при
# исчезновении оружия/владельца самоуничтожается. Без лямбд в твинах (SCRUM-551).

const AttackVfx := preload("res://scripts/attack_vfx.gd")

const CONTACT_SCAN_INTERVAL := 0.08
const CONTACT_TARGET_CAP := 4  # врагов за один скан контакта (защита от спайков)
const SPIRAL_RADIUS_STEP := 0.14
# SCRUM-908 «Сеть мастерской»: вес дрона в стеках сети устройств.
const NETWORK_WEIGHT := 1.0

var _weapon_instance_id := 0
var _owner_instance_id := 0
var _slot_index := 0
var _slot_count := 1
var _angle := 0.0
var _scan_cooldown := 0.0
# per-enemy кулдаун: instance_id -> оставшееся время (сек).
var _hit_cooldowns := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("engineer_devices")
	set_meta("orbit_drone", true)
	set_meta("network_weight", NETWORK_WEIGHT)  # SCRUM-908
	z_index = 7


func setup(weapon: Node, owner_node: Node2D, slot_index: int, slot_count: int) -> void:
	_weapon_instance_id = weapon.get_instance_id() if weapon != null else 0
	_owner_instance_id = owner_node.get_instance_id() if owner_node != null else 0
	set_slot(slot_index, slot_count)
	_angle = _phase_offset()
	if owner_node != null and is_instance_valid(owner_node):
		global_position = owner_node.global_position + Vector2.RIGHT.rotated(_angle) * _orbit_radius()


func set_slot(slot_index: int, slot_count: int) -> void:
	# Перераспределение фаз при изменении числа дронов: слот задаёт фазу и
	# радиус витка спирали; текущий угол сохраняется (без телепорта).
	_slot_index = maxi(slot_index, 0)
	_slot_count = maxi(slot_count, 1)


func slot_index() -> int:
	return _slot_index


func _phase_offset() -> float:
	return TAU * float(_slot_index) / float(maxi(_slot_count, 1))


func _orbit_radius() -> float:
	var weapon := instance_from_id(_weapon_instance_id) as Node
	var base_radius := 78.0
	if weapon != null and is_instance_valid(weapon) and weapon.get("drone_orbit_radius") != null:
		base_radius = maxf(float(weapon.get("drone_orbit_radius")), 24.0)
	return base_radius * (1.0 + SPIRAL_RADIUS_STEP * float(_slot_index))


func _physics_process(delta: float) -> void:
	var weapon := instance_from_id(_weapon_instance_id) as Node
	if weapon == null or not is_instance_valid(weapon):
		# Оружие исчезло (смена/чистка) — дрон не должен жить без хозяина.
		queue_free()
		return
	var owner_node := instance_from_id(_owner_instance_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	_angle = fposmod(_angle + delta * orbit_angular_speed(weapon, owner_node), TAU)
	global_position = owner_node.global_position \
		+ Vector2.RIGHT.rotated(_angle + _phase_offset()) * _orbit_radius()
	_tick_hit_cooldowns(delta)
	_scan_cooldown -= delta
	if _scan_cooldown <= 0.0:
		_scan_cooldown = CONTACT_SCAN_INTERVAL
		_damage_contacts(weapon, owner_node)


func orbit_angular_speed(weapon: Node, owner_node: Node2D) -> float:
	# рад/с: базовая скорость оружия × attack_speed владельца × гироскоп-бонус.
	var base_speed := 3.6
	if weapon.get("drone_orbit_speed") != null:
		base_speed = maxf(float(weapon.get("drone_orbit_speed")), 0.5)
	var attack_speed := 1.0
	var gyro_bonus := 0.0
	if owner_node != null and is_instance_valid(owner_node):
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			attack_speed = maxf(float((params as Dictionary).get("attack_speed", 1.0)), 0.1)
		var mods = owner_node.get("run_modifiers")
		if mods is Dictionary:
			gyro_bonus = maxf(float((mods as Dictionary).get("drone_orbit_speed_bonus", 0.0)), 0.0)
	return base_speed * attack_speed * (1.0 + gyro_bonus)


func _tick_hit_cooldowns(delta: float) -> void:
	if _hit_cooldowns.is_empty():
		return
	var expired: Array = []
	for enemy_id in _hit_cooldowns:
		var left := float(_hit_cooldowns[enemy_id]) - delta
		if left <= 0.0:
			expired.append(enemy_id)
		else:
			_hit_cooldowns[enemy_id] = left
	for enemy_id in expired:
		_hit_cooldowns.erase(enemy_id)


func _damage_contacts(weapon: Node, owner_node: Node2D) -> void:
	var contact_radius := 44.0
	if weapon.get("drone_contact_radius") != null:
		contact_radius = maxf(float(weapon.get("drone_contact_radius")), 8.0)
	var targets: Array = weapon.call("_nearest_enemies_from", global_position, contact_radius, CONTACT_TARGET_CAP)
	if targets.is_empty():
		return
	var hit_cooldown := 0.85
	if weapon.get("drone_hit_cooldown") != null:
		hit_cooldown = maxf(float(weapon.get("drone_hit_cooldown")), 0.1)
	var contact_multiplier := 0.90
	if weapon.get("summon_damage_multiplier") != null:
		contact_multiplier = maxf(float(weapon.get("summon_damage_multiplier")), 0.05)
	for target_raw in targets:
		var target := target_raw as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var enemy_id := target.get_instance_id()
		if _hit_cooldowns.has(enemy_id):
			continue
		_hit_cooldowns[enemy_id] = hit_cooldown
		var contact_damage := float(weapon.call("_rolled_damage", owner_node)) * contact_multiplier
		weapon.call("_damage_enemy", target, contact_damage)
		AttackVfx.ring_pulse(weapon.call("_projectile_parent"), target.global_position, contact_radius * 0.55, weapon.get("visual_color"), false)
