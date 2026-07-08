extends Node2D

# SCRUM-888: стационарная sentry-турель инженера («Ключ Часового»).
# Разворачивается оружием (class_weapon._fire_engineer_sentry_link) по кулдауну;
# живёт до конца боя или до замены старейшей (лимит max_summons оружия, жёсткий
# кап 2). Автострельба: каждый пульс — снаряд (orb_projectile) в БЛИЖАЙШЕГО
# врага в радиусе оружия; урон идёт через weapon._rolled_damage (крит +
# summon_role-фактор Лидерства), темп зеркалит бюджет-модель
# (_budget_summon_dps): pulse / (1 + min(summon_amount*0.014 + leadership*0.006, 0.30)).
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

var _weapon_instance_id := 0
var _owner_instance_id := 0
var _fire_cooldown := FIRST_AUTO_SHOT_DELAY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("engineer_devices")
	z_index = 7
	_play_deploy_pop()


func setup(weapon: Node, owner_node: Node2D) -> void:
	_weapon_instance_id = weapon.get_instance_id() if weapon != null else 0
	_owner_instance_id = owner_node.get_instance_id() if owner_node != null else 0


func _play_deploy_pop() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	visual.scale = Vector2.ONE * 0.55
	var pop := create_tween()
	pop.tween_property(visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
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
	# Темп растёт от Лидерства/summon_amount с капом +30% — зеркало
	# progression_data._budget_summon_dps (модель и рантайм считают одинаково).
	var pulse := maxf(float(weapon.get("amp_pulse_interval")), 0.18)
	var leadership := 0.0
	var summon_amount := 0.0
	var owner_node := instance_from_id(_owner_instance_id) as Node2D
	if owner_node != null and is_instance_valid(owner_node):
		var stats = owner_node.get("stats")
		if stats is Dictionary:
			leadership = float((stats as Dictionary).get("leadership", 0.0))
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			summon_amount = float((params as Dictionary).get("summon_amount", 0.0))
	var tempo_lift := 1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
	return pulse / tempo_lift


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
	var falloff := clampf(float(weapon.get("damage_falloff")), 0.05, 1.0)
	var fired := false
	for index in range(targets.size()):
		var target := targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var shot_damage := float(weapon.call("_rolled_damage", owner_node)) * pow(falloff, float(index))
		_launch_projectile(weapon, target, shot_damage)
		fired = true
	return fired


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
