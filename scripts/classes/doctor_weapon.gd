extends "res://scripts/classes/dark_mage_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса doctor.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_plague_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_plague_dart(owner_node, target, direction)


func _exec_saw_sector(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_saw_sector(owner_node, direction)


# ============================ SCRUM-900: кит Доктора ============================
# «Клятва чумного доктора»: весь сустейн класса — heal_percent_of_damage от
# ФАКТИЧЕСКИ нанесённого урона (_damage_enemy → _heal_owner_from_damage →
# apply_drain_heal с per-second бюджетом SCRUM-517). Нет урона — нет лечения.


# Чумной дротик: летящий снаряд в цель; на попадании — малый прямой урон и
# долгая зараза (см. _apply_plague_infection). Мета-ветка drain_extra_targets
# (Атлас Доктора) добавляет дротики по ближайшим соседям первичной цели.
func _fire_plague_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		return
	var targets: Array = [target]
	var extra_darts := _extra_projectiles()
	if extra_darts > 0:
		var used := {target.get_instance_id(): true}
		var previous_position := target.global_position
		for _extra_index in range(extra_darts):
			var next_target := _find_nearest_enemy_from(previous_position, maxf(plague_spread_radius, aoe_radius), used)
			if next_target == null:
				break
			used[next_target.get_instance_id()] = true
			targets.append(next_target)
			previous_position = next_target.global_position
	for dart_target_raw in targets:
		var dart_target := dart_target_raw as Node2D
		if dart_target == null or not is_instance_valid(dart_target):
			continue
		_launch_plague_dart_at(owner_node, dart_target, direction)


func _launch_plague_dart_at(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var dart := _spawn_projectile_visual(owner_node.global_position + direction * 26.0, target.global_position - owner_node.global_position)
	_register_effect(dart)
	var travel_time: float = clampf(dart.global_position.distance_to(target.global_position) / maxf(projectile_speed, 1.0), 0.06, 0.42)
	var tween := create_tween()
	tween.tween_property(dart, "global_position", target.global_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# SCRUM-551: bound-метод вместо лямбды (захват узлов в лямбде — use-after-free).
	tween.tween_callback(Callable(self, "_plague_dart_arrive").bind(dart.get_instance_id(), owner_node.get_instance_id(), target.get_instance_id()))


func _plague_dart_arrive(dart_id: int, owner_id: int, target_id: int) -> void:
	var dart := instance_from_id(dart_id) as Node
	if dart != null:
		_release_effect(dart)
	if _effects_shutdown:
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	var target := instance_from_id(target_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or target == null or not is_instance_valid(target):
		return
	# Прямой урон дротика: небольшой укол (magic), лечит через heal_percent_of_damage.
	_damage_enemy(target, _rolled_damage(owner_node))
	_apply_plague_infection(target, owner_node)


# Профиль чумы из текущих полей оружия + derived-статов владельца.
func _plague_runtime_profile(owner_node: Node2D) -> Dictionary:
	var params_raw = owner_node.get("derived_parameters") if owner_node != null else null
	var params: Dictionary = params_raw if params_raw is Dictionary else {}
	return ProgressionData.plague_tick_profile({
		"plague_duration": plague_duration,
		"plague_tick_interval": plague_tick_interval,
		"plague_tick_ratio": plague_tick_ratio,
		"plague_dot_coupling": plague_dot_coupling,
		"plague_ramp_ticks": plague_ramp_ticks,
	}, params)


func _plague_active_count() -> int:
	# Чистка мёртвых записей (враг умер/освобождён — tween-тики уже no-op).
	for enemy_id in _plague_tweens.keys().duplicate():
		var enemy := instance_from_id(int(enemy_id)) as Node2D
		if enemy == null or not is_instance_valid(enemy):
			var stale_tween: Tween = _plague_tweens[enemy_id]
			if stale_tween != null and stale_tween.is_valid():
				stale_tween.kill()
			_plague_tweens.erase(enemy_id)
	return _plague_tweens.size()


# Заражение цели чумой: долгий DoT с медленным ramp'ом тиков. Повторное
# попадание РЕФРЕШИТ заразу (полная длительность, ramp заново — без стакинга).
# Кап одновременных зараз plague_max_infected — «бессмертие от полного
# заражения карты» отрезано и здесь, и per-second drain-бюджетом лечения.
func _apply_plague_infection(enemy: Node2D, owner_node: Node2D, constellation_depth := 0, duration_scale := 1.0) -> void:
	if enemy == null or not is_instance_valid(enemy) or owner_node == null or not is_instance_valid(owner_node):
		return
	if _effects_shutdown:
		return
	var enemy_id := enemy.get_instance_id()
	var refreshing := _plague_tweens.has(enemy_id)
	if not refreshing and _plague_active_count() >= maxi(plague_max_infected, 1):
		return
	if refreshing:
		var old_tween: Tween = _plague_tweens[enemy_id]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		_plague_tweens.erase(enemy_id)
	var profile := _plague_runtime_profile(owner_node)
	var tick_interval := maxf(float(profile.get("tick_interval", 1.0)), 0.2)
	var ticks := maxi(int(ceil(float(profile.get("ticks", 1)) * clampf(duration_scale, 0.05, 1.0))), 1)
	AttackVfx.ring_pulse(_projectile_parent(), enemy.global_position, 44.0, visual_color, false)
	var tween := create_tween()
	_plague_tweens[enemy_id] = tween
	var owner_id := owner_node.get_instance_id()
	for tick_index in range(ticks):
		tween.tween_interval(tick_interval)
		tween.tween_callback(Callable(self, "_plague_tick").bind(enemy_id, owner_id, tick_index))
	tween.tween_callback(Callable(self, "_end_plague_infection").bind(enemy_id))
	if constellation_depth == 0 and not _constellation_profile("syringe_infection_threshold_spread").is_empty():
		var stack_key := _constellation_mark_key("syringe_infection")
		var stack_raw = enemy.get_meta(stack_key, {})
		var stack_state: Dictionary = stack_raw if stack_raw is Dictionary else {}
		var now_msec := Time.get_ticks_msec()
		if now_msec > int(stack_state.get("until_msec", 0)):
			stack_state = {"count": 0, "spread": false}
		stack_state["count"] = mini(int(stack_state.get("count", 0)) + 1, 4)
		stack_state["until_msec"] = now_msec + int(tick_interval * float(ticks) * 1000.0)
		var infection_event := {"valid": true, "triggered": false}
		if not bool(stack_state.get("spread", false)):
			infection_event = _constellation_event("hit", enemy, 0.0, {"infection_stacks": int(stack_state["count"]), "constellation_consumer_event": true})
		if int(stack_state["count"]) >= 4 and not bool(stack_state.get("spread", false)) and bool(infection_event.get("triggered", false)):
			stack_state["spread"] = true
			var excluded := {enemy.get_instance_id(): true}
			for infected_id in _plague_tweens.keys():
				excluded[int(infected_id)] = true
			var spread_cap := maxi(int(_constellation_result_param(infection_event, "spread_targets", 3.0)), 0)
			var duration_ratio := _constellation_result_param(infection_event, "spread_duration_ratio", 0.50)
			for spread_raw in TARGET_QUERY.nearest_many(self, enemy.global_position, plague_spread_radius, spread_cap, excluded):
				var spread_target := spread_raw as Node2D
				if spread_target != null and is_instance_valid(spread_target):
					_apply_plague_infection(spread_target, owner_node, 1, duration_ratio)
		enemy.set_meta(stack_key, stack_state)


func _plague_tick(enemy_id: int, owner_id: int, tick_index: int) -> void:
	if _effects_shutdown:
		return
	var enemy := instance_from_id(enemy_id) as Node2D
	if enemy == null or not is_instance_valid(enemy):
		_end_plague_infection(enemy_id)
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var profile := _plague_runtime_profile(owner_node)
	var tick_damage := float(profile.get("tick_damage", 0.0)) * ProgressionData.plague_ramp_factor(tick_index, plague_ramp_ticks)
	if tick_damage <= 0.0:
		return
	# Тик чумы: dot-канал, без melee-эффектов и без owner-hit нотификаций;
	# лечение Доктора идёт внутри _damage_enemy → _heal_owner_from_damage.
	_damage_enemy(enemy, tick_damage, false, "dot", false)
	HazardVfx.dot_tick(enemy, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))
	# Распространение: тикающая зараза с ограниченным шансом перескакивает на
	# ближайшего НЕзаражённого соседа (кап учтён в _apply_plague_infection).
	if plague_spread_chance > 0.0 and randf() < plague_spread_chance:
		_spread_plague_from(enemy, owner_node)


func _spread_plague_from(enemy: Node2D, owner_node: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _plague_active_count() >= maxi(plague_max_infected, 1):
		return
	var excluded := {}
	for infected_id in _plague_tweens.keys():
		excluded[int(infected_id)] = true
	var next_target := _find_nearest_enemy_from(enemy.global_position, plague_spread_radius, excluded)
	if next_target == null:
		return
	AttackVfx.beam(_projectile_parent(), enemy.global_position, next_target.global_position, 10.0, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
	_apply_plague_infection(next_target, owner_node, 1, 1.0)


func _end_plague_infection(enemy_id: int) -> void:
	_plague_tweens.erase(enemy_id)


# Костяная пила: melee-сектор cone_degrees (120-150°) перед Доктором с реальной
# дальностью. Бьёт все цели в дуге (диминиш сверх sector_full_targets), лечит
# сильнее всех оружий Доктора (heal_percent_of_damage) — но только по фронту:
# враги с флангов/спины давят безнаказанно, позиционирование = выживание.
func _fire_saw_sector(owner_node: Node2D, direction: Vector2) -> void:
	var slash := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(slash)
	# cone_degrees уже масштабирован Player единым множителем области атаки.
	var cone_effective := clampf(
		cone_degrees * (1.0 + _owner_mod("saw_arc_width_mult")),
		20.0, 360.0)
	var half_angle := deg_to_rad(cone_effective * 0.5)
	var candidates := []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node):
			continue
		var offset: Vector2 = enemy_node.global_position - owner_node.global_position
		var distance := offset.length()
		if distance > attack_range:
			continue
		if distance > 0.001 and absf(direction.angle_to(offset)) > half_angle:
			continue
		candidates.append({"node": enemy_node, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var damage_value := _rolled_damage(owner_node)
	var hit_index := 0
	for candidate in candidates:
		var saw_target := candidate["node"] as Node2D
		var hit_damage := damage_value
		if hit_index >= maxi(sector_full_targets, 1) and sector_target_diminish > 0.0:
			hit_damage *= pow(sector_target_diminish, float(hit_index - maxi(sector_full_targets, 1) + 1))
		_damage_enemy(saw_target, hit_damage)
		if not _constellation_profile("saw_wound_execute_heal").is_empty() and is_instance_valid(saw_target):
			var wound_count := _advance_constellation_target_stack(saw_target, "saw_wound", 5, 6.0)
			var wound_event := _constellation_event("hit", saw_target, 0.0, {"wounds": wound_count, "constellation_consumer_event": true})
			var hp_value = saw_target.get("health")
			var max_hp_value = saw_target.get("max_health")
			var low_enough := hp_value != null and max_hp_value != null and float(max_hp_value) > 0.0 and float(hp_value) / float(max_hp_value) <= _constellation_result_param(wound_event, "execute_threshold", 0.25)
			if wound_count >= 5 and low_enough and bool(wound_event.get("triggered", false)):
				saw_target.remove_meta(_constellation_mark_key("saw_wound"))
				if owner_node.has_method("apply_drain_heal"):
					owner_node.call("apply_drain_heal", hit_damage * _constellation_result_param(wound_event, "heal_ratio", 0.06))
		hit_index += 1


# ========================== конец кита Доктора (SCRUM-900) ==========================


# SCRUM-961 «Восстановительный пар»: короткая паровая зона у цели — 2 тика
# за 1.4с, тик жжёт 28% урона, 20% урона пара лечит Доктора через
# apply_drain_heal (капы drain-бюджета соблюдены). SCRUM-900: хук переехал с
# drain_link-связи на взрыв зелья (см. _launch_aoe_projectile).
func _spawn_restore_vapor(owner_node: Node2D, center: Vector2, link_damage: float) -> void:
	var vapor_radius := maxf(aoe_radius * 0.8, 90.0)
	var tick_damage := link_damage * 0.28
	# FAN-1031 S3 (3c): артефактный vapor-канал «Восстановительного пара» теперь
	var vapor_full := aoe_full_targets if aoe_full_targets >= 0 else 2
	var vapor_diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else 1.5
	var weapon_self_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	AttackVfx.ring_pulse(_projectile_parent(), center, vapor_radius, Color(0.45, 1.0, 0.75, 0.35), true)
	var vapor_tween := create_tween()
	for tick_index in range(2):
		vapor_tween.tween_interval(0.7)
		vapor_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
			if current_weapon == null or not is_instance_valid(current_weapon) or current_weapon._effects_shutdown:
				return
			AttackVfx.ring_pulse(current_weapon._projectile_parent(), center, vapor_radius, Color(0.45, 1.0, 0.75, 0.26), false)
			current_weapon._damage_enemies_in_circle_capped(center, vapor_radius, tick_damage, vapor_full, vapor_diminish)
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_owner != null and is_instance_valid(current_owner) and current_owner.has_method("apply_drain_heal"):
				current_owner.call("apply_drain_heal", tick_damage * 0.20)
		)
