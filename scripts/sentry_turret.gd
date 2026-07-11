extends Node2D

# SCRUM-888/905: стационарная sentry-турель инженера («Часовая турель»).
# Разворачивается оружием (class_weapon._fire_engineer_sentry_link) по кулдауну.
# SCRUM-905: турель ВСЕГДА несёт боезапас (sentry_shot_magazine оружия, база 15
# выстрелов; «Магазин турели» и «Полевой чертеж» добавляют заряды) и
# сворачивается, расстреляв его; таймера жизни/замены старейшей НЕТ.
# Автострельба: каждый пульс — залп (orb_projectile) по БЛИЖАЙШИМ врагам в
# радиусе оружия; урон идёт через weapon._rolled_damage (крит + summon_role-
# фактор Лидерства), темп = amp_pulse_interval / tempo-lift / attack_speed —
# зеркало бюджет-модели (_budget_sentry_ammo_model): tempo-lift =
# 1 + min(summon_amount*0.014 + leadership*0.006, 0.30), скорость атаки
# ускоряет стрельбу и расход боезапаса (AC SCRUM-905).
# Чистка без утечек: узел зарегистрирован как player_weapon_effects
# (weapon._register_effect) — его освобождают cleanup_effects оружия, смена
# оружия/смерть игрока (player._clear_detached_weapon_effects) и конец боя
# (main.gd чистит группу); при исчезновении оружия турель самоуничтожается.
# ВАЖНО (SCRUM-551): никаких захватов узлов в tween-лямбдах — только
# Callable(obj, "method").bind(значения) и instance_from_id-гарды.

const AttackVfx := preload("res://scripts/attack_vfx.gd")

const PROJECTILE_SPEED := 950.0
const MUZZLE_OFFSET := Vector2(0.0, -14.0)
const IDLE_RETRY_INTERVAL := 0.2
const FIRST_AUTO_SHOT_DELAY := 0.35
# SCRUM-905: fallback боезапаса, если у оружия нет sentry_shot_magazine.
const SENTRY_MAGAZINE_BASE := 15
# SCRUM-908 «Сеть мастерской»: вес турели в стеках сети устройств.
const NETWORK_WEIGHT := 1.0
const CONSTELLATION_FINAL_MECHANICS := {"sentry_marked_target_overclock": "sentry_hit"}

var _weapon_instance_id := 0
var _owner_instance_id := 0
var _fire_cooldown := FIRST_AUTO_SHOT_DELAY
# SCRUM-905: осталось выстрелов; по расстрелу турель деспаунится сама (try_fire).
var _shots_left := SENTRY_MAGAZINE_BASE
var _constellation_marked_target_id := 0
var _constellation_heat := 0
var _constellation_overclock_cooldown := 0.0
var _constellation_attack_speed_bonus := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("engineer_devices")
	set_meta("network_weight", NETWORK_WEIGHT)  # SCRUM-908
	z_index = 7
	_play_deploy_pop()


func setup(weapon: Node, owner_node: Node2D) -> void:
	_weapon_instance_id = weapon.get_instance_id() if weapon != null else 0
	_owner_instance_id = owner_node.get_instance_id() if owner_node != null else 0
	# SCRUM-905: базовый магазин из конфига оружия (15); «Магазин турели»
	# (sentry_magazine_bonus) и «Полевой чертеж» (+2 за каждые 6 Лидерства)
	# добавляют заряды поверх базы.
	var base_magazine := SENTRY_MAGAZINE_BASE
	if weapon != null and weapon.get("sentry_shot_magazine") != null:
		base_magazine = maxi(int(weapon.get("sentry_shot_magazine")), 1)
	var magazine_bonus := 0
	var blueprint_shots := 0
	if owner_node != null:
		var mods = owner_node.get("run_modifiers")
		if mods is Dictionary:
			magazine_bonus = int(float((mods as Dictionary).get("sentry_magazine_bonus", 0.0)))
			if float((mods as Dictionary).get("blueprint_leadership_scaling", 0.0)) > 0.0:
				var stats = owner_node.get("stats")
				if stats is Dictionary:
					blueprint_shots = int(floor(float((stats as Dictionary).get("leadership", 0.0)) / 6.0)) * 2
	_shots_left = base_magazine + magazine_bonus + blueprint_shots


func shots_left() -> int:
	return _shots_left


func _play_deploy_pop() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	visual.scale = Vector2.ONE * 0.55
	var pop := create_tween()
	pop.tween_property(visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_constellation_overclock_cooldown = maxf(_constellation_overclock_cooldown - delta, 0.0)
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0:
		return
	var weapon := instance_from_id(_weapon_instance_id) as Node
	if weapon == null or not is_instance_valid(weapon):
		# Оружие исчезло (смена/чистка) — турель не должна жить без хозяина.
		queue_free()
		return
	if not try_fire(weapon):
		_fire_cooldown = IDLE_RETRY_INTERVAL
		return
	_fire_cooldown = effective_pulse_interval(weapon)


func effective_pulse_interval(weapon: Node) -> float:
	# Темп растёт от Лидерства/summon_amount с капом +30% и от СКОРОСТИ АТАКИ
	# (SCRUM-905: attack_speed ускоряет выстрелы/сек и расход боезапаса) —
	# зеркало progression_data._budget_sentry_ammo_model.
	var pulse := maxf(float(weapon.get("amp_pulse_interval")), 0.18)
	var leadership := 0.0
	var summon_amount := 0.0
	var attack_speed := 1.0
	var owner_node := instance_from_id(_owner_instance_id) as Node2D
	if owner_node != null and is_instance_valid(owner_node):
		var stats = owner_node.get("stats")
		if stats is Dictionary:
			leadership = float((stats as Dictionary).get("leadership", 0.0))
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			summon_amount = float((params as Dictionary).get("summon_amount", 0.0))
			attack_speed = maxf(float((params as Dictionary).get("attack_speed", 1.0)), 0.1)
	var tempo_lift := 1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
	return maxf(pulse / tempo_lift / attack_speed / (1.0 + constellation_overclock_bonus()), 0.10)


func try_fire(weapon: Node) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	var owner_node := instance_from_id(_owner_instance_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return false
	var targeting_range := maxf(float(weapon.get("attack_range")), 80.0)
	# Залп = projectile_count + extra_projectile (апгрейды забега): основной
	# снаряд — в ближайшего врага, дополнительные — по СЛЕДУЮЩИМ ближайшим с
	# damage_falloff^index. Одна цель в радиусе получает только первый снаряд
	# (без дублей) — соло-ось не греется, толпа получает распределение;
	# зеркало бюджет-модели (_budget_hit_model / engineer_sentry_link).
	var volley := maxi(int(weapon.get("projectile_count")), 1) + maxi(int(weapon.call("_extra_projectiles")), 0)
	var targets: Array = weapon.call("_nearest_enemies_from", global_position, targeting_range, volley)
	if targets.is_empty():
		return false
	_select_constellation_durable_mark(weapon, owner_node, targets)
	var falloff := clampf(float(weapon.get("damage_falloff")), 0.05, 1.0)
	var fired := false
	for index in range(targets.size()):
		# SCRUM-961 «Магазин турели»: каждый снаряд тратит боезапас.
		if _shots_left == 0:
			break
		var target := targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var shot_damage := float(weapon.call("_rolled_damage", owner_node)) * pow(falloff, float(index))
		_register_constellation_sentry_hit(weapon, owner_node, target)
		_launch_projectile(weapon, target, shot_damage)
		fired = true
		if _shots_left > 0:
			_shots_left -= 1
	if _shots_left == 0:
		# Боезапас расстрелян: деспаун с мини-VFX + возврат перезарядки владельцу
		# («Ядро утилизации», no-op без ключа).
		AttackVfx.ring_pulse(weapon.call("_projectile_parent"), global_position, 46.0, Color(0.85, 0.75, 0.40, 0.45), false)
		weapon.call("_salvage_device_refund")
		queue_free()
	return fired


func _constellation_mechanic(weapon: Node, owner_node: Node) -> Dictionary:
	if weapon == null or owner_node == null or not owner_node.has_method("constellation_weapon_mechanic"):
		return {}
	var raw = owner_node.call("constellation_weapon_mechanic", str(weapon.get("weapon_id")), "sentry_marked_target_overclock")
	return raw if raw is Dictionary else {}


func _select_constellation_durable_mark(weapon: Node, owner_node: Node, targets: Array) -> void:
	if _constellation_overclock_cooldown > 0.0 or _constellation_mechanic(weapon, owner_node).is_empty():
		return
	if _constellation_marked_target_id != 0:
		var current := instance_from_id(_constellation_marked_target_id)
		if current != null and is_instance_valid(current):
			return
	var durable: Node2D = null
	var durable_hp := -1.0
	for raw_target in targets:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var hp := float(target.get("max_health")) if target.get("max_health") != null else 0.0
		if hp > durable_hp:
			durable = target
			durable_hp = hp
	if durable != null:
		_constellation_marked_target_id = durable.get_instance_id()
		_constellation_heat = 0


func _register_constellation_sentry_hit(weapon: Node, owner_node: Node, target: Node2D) -> Dictionary:
	var mechanic := _constellation_mechanic(weapon, owner_node)
	if mechanic.is_empty() or target == null or target.get_instance_id() != _constellation_marked_target_id:
		return {"triggered": false}
	var params: Dictionary = mechanic.get("params", {})
	var heat_cap := maxi(int(params.get("heat_shots", 5)), 1)
	_constellation_attack_speed_bonus = clampf(float(params.get("attack_speed_bonus", 0.24)), 0.0, 0.30)
	_constellation_heat = mini(_constellation_heat + 1, heat_cap)
	var result := {"valid": true, "triggered": false}
	if owner_node.has_method("constellation_weapon_event"):
		var raw = owner_node.call("constellation_weapon_event", str(weapon.get("weapon_id")), "sentry_hit", {"heat": _constellation_heat, "heat_cap": heat_cap}, target)
		if raw is Dictionary:
			result = raw
	if _constellation_heat >= heat_cap:
		_constellation_overclock_cooldown = maxf(float(params.get("cooldown_seconds", 2.0)), 0.0)
		_constellation_marked_target_id = 0
		_constellation_heat = 0
		_constellation_attack_speed_bonus = 0.0
	return result


func constellation_overclock_bonus() -> float:
	if _constellation_overclock_cooldown > 0.0 or _constellation_marked_target_id == 0:
		return 0.0
	return _constellation_attack_speed_bonus


func constellation_overclock_state() -> Dictionary:
	return {"target_id": _constellation_marked_target_id, "heat": _constellation_heat, "cooldown": _constellation_overclock_cooldown, "attack_speed_bonus": constellation_overclock_bonus()}


func _launch_projectile(weapon: Node, target: Node2D, shot_damage: float) -> void:
	var start := global_position + MUZZLE_OFFSET
	var target_position := target.global_position
	var projectile := AttackVfx.orb_projectile(weapon.call("_projectile_parent"), start, weapon.get("visual_color"))
	if projectile == null:
		return
	weapon.call("_register_effect", projectile)
	var flight_time := clampf(start.distance_to(target_position) / PROJECTILE_SPEED, 0.05, 0.55)
	# Твин живёт на снаряде: если снаряд освобождён чисткой — полёт умирает вместе
	# с ним; колбэки на ОРУЖИИ (переживает турель), цель — по instance id.
	var flight := projectile.create_tween()
	flight.tween_property(projectile, "global_position", target_position, flight_time)
	flight.tween_callback(Callable(weapon, "_engineer_turret_projectile_hit").bind(target.get_instance_id(), shot_damage))
	flight.tween_callback(Callable(weapon, "_release_effect").bind(projectile))
