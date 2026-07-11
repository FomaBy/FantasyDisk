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
const CONSTELLATION_FINAL_MECHANICS := {"drone_excess_repair_shield": "repair"}
const REPAIR_TICK_INTERVAL := 0.25
const REPAIR_PER_SECOND_CAP := 2.0

var _weapon_instance_id := 0
var _owner_instance_id := 0
var _slot_index := 0
var _slot_count := 1
var _angle := 0.0
var _scan_cooldown := 0.0
# per-enemy кулдаун: instance_id -> оставшееся время (сек).
var _hit_cooldowns := {}
var _repair_tick_left := 0.0
var _constellation_owned_shield := 0.0
var _constellation_shield_left := 0.0


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
	if owner_node != null and is_instance_valid(owner_node):
		global_position = owner_node.global_position \
			+ Vector2.RIGHT.rotated(_angle + _phase_offset()) * _orbit_radius()


func set_slot(slot_index: int, slot_count: int) -> void:
	# Перераспределение при росте парка: слот задаёт фазу и радиус витка
	# спирали. Накопленный угол ОБНУЛЯЕТСЯ — эффективные углы всех дронов
	# снова равномерны (TAU×slot/count): иначе дроны разных волн деплоя несут
	# разную угловую историю и пара соседних колец может слипнуться навсегда
	# (одинаковая угловая скорость фиксирует относительные углы). Радиальный
	# пере-сеат при смене слота происходит в любом случае (_orbit_radius от
	# слота), так что разовый угловой пере-сеат в момент присоединения нового
	# дрона — та же читаемая «перестройка звена», а не телепорт в бою.
	_slot_index = maxi(slot_index, 0)
	_slot_count = maxi(slot_count, 1)
	_angle = 0.0


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
	_tick_constellation_shield_expiry(owner_node, delta)
	_repair_tick_left -= delta
	if _repair_tick_left <= 0.0:
		_repair_tick_left = REPAIR_TICK_INTERVAL
		constellation_repair_tick(weapon, owner_node, REPAIR_TICK_INTERVAL)
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


# The repair drone was previously combat-only despite its canonical identity.
# This bounded tether restores at most 2 HP/s. The final converts only actual
# excess repair, never raises the heal-per-second rail, and owns a short shield
# bucket that is removed on expiry.
func constellation_repair_tick(weapon: Node, owner_node: Node2D, delta: float) -> Dictionary:
	var outcome := {"requested": 0.0, "healed": 0.0, "excess": 0.0, "shield_added": 0.0, "triggered": false}
	if weapon == null or owner_node == null or not is_instance_valid(owner_node) or delta <= 0.0:
		return outcome
	if owner_node.get("health") == null or owner_node.get("max_health") == null:
		return outcome
	var requested := REPAIR_PER_SECOND_CAP * delta
	var before := maxf(float(owner_node.get("health")), 0.0)
	var maximum := maxf(float(owner_node.get("max_health")), 1.0)
	var healed := minf(requested, maxf(maximum - before, 0.0))
	owner_node.set("health", minf(before + healed, maximum))
	var excess := maxf(requested - healed, 0.0)
	outcome["requested"] = requested
	outcome["healed"] = healed
	outcome["excess"] = excess
	if excess <= 0.0 or not owner_node.has_method("constellation_weapon_mechanic"):
		return outcome
	var weapon_id := str(weapon.get("weapon_id"))
	var mechanic_raw = owner_node.call("constellation_weapon_mechanic", weapon_id, "drone_excess_repair_shield")
	if not mechanic_raw is Dictionary or (mechanic_raw as Dictionary).is_empty():
		return outcome
	var params: Dictionary = (mechanic_raw as Dictionary).get("params", {})
	var conversion := clampf(float(params.get("conversion_ratio", 0.5)), 0.0, 1.0)
	var cap := clampf(float(params.get("shield_cap", 20.0)), 0.0, 30.0)
	var shield_add := minf(excess * conversion, maxf(cap - _constellation_owned_shield, 0.0))
	if shield_add <= 0.0:
		return outcome
	var previous_bucket := _owner_modifier(owner_node, "constellation_absorb_flat")
	var previous_absorb := _owner_modifier(owner_node, "absorb_flat")
	var result := {"valid": true, "triggered": true}
	if owner_node.has_method("constellation_weapon_event"):
		var raw = owner_node.call("constellation_weapon_event", weapon_id, "repair", {"repair": requested, "healed": healed, "excess": excess}, null)
		if raw is Dictionary:
			result = raw
	if not bool(result.get("triggered", false)):
		return outcome
	# Player's generic side-effect grants the manifest cap. Normalize that generic
	# bucket back to the exact excess*conversion amount owned by this drone.
	var event_bucket := _owner_modifier(owner_node, "constellation_absorb_flat")
	var desired_bucket := minf(previous_bucket + shield_add, cap)
	_set_owner_modifier(owner_node, "constellation_absorb_flat", desired_bucket)
	_set_owner_modifier(owner_node, "absorb_flat", maxf(previous_absorb + desired_bucket - previous_bucket, 0.0))
	_constellation_owned_shield = minf(_constellation_owned_shield + shield_add, cap)
	_constellation_shield_left = maxf(float(params.get("shield_seconds", 3.0)), 0.0)
	outcome["shield_added"] = shield_add
	outcome["triggered"] = true
	# Keep a visible audit fact for tests/debug even when the owner is a minimal mock.
	outcome["generic_event_bucket"] = event_bucket
	return outcome


func _tick_constellation_shield_expiry(owner_node: Node2D, delta: float) -> void:
	if _constellation_owned_shield <= 0.0:
		return
	_constellation_shield_left = maxf(_constellation_shield_left - delta, 0.0)
	if _constellation_shield_left > 0.0:
		return
	var bucket := _owner_modifier(owner_node, "constellation_absorb_flat")
	var absorb := _owner_modifier(owner_node, "absorb_flat")
	var removed := minf(_constellation_owned_shield, bucket)
	_set_owner_modifier(owner_node, "constellation_absorb_flat", maxf(bucket - removed, 0.0))
	_set_owner_modifier(owner_node, "absorb_flat", maxf(absorb - removed, 0.0))
	_constellation_owned_shield = 0.0


func _owner_modifier(owner_node: Node, key: String) -> float:
	var raw = owner_node.get("run_modifiers")
	return float((raw as Dictionary).get(key, 0.0)) if raw is Dictionary else 0.0


func _set_owner_modifier(owner_node: Node, key: String, value: float) -> void:
	var raw = owner_node.get("run_modifiers")
	if raw is Dictionary:
		(raw as Dictionary)[key] = value


func constellation_repair_state() -> Dictionary:
	return {"repair_per_second_cap": REPAIR_PER_SECOND_CAP, "owned_shield": _constellation_owned_shield, "shield_left": _constellation_shield_left}
