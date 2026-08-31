extends "res://scripts/classes/sniper_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса soldier.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# SCRUM-937 «Граната с фитилем»: медленный снаряд долго летит в телеграфированную
const GRENADE_MAX_FLIGHT_SPEED := 460.0


# SCRUM-938 «Штык-конус»: активный ближний сектор (cone_degrees) в направлении
# атаки — каждый враг в конусе получает укол и отброс за один взмах; вплотную к
# ногам мёртвой зоны нет (contact-rescue радиус). Поверх укола — редкий
# авто-выстрел винтовки по цели ЗА конусом (bayonet_auto_shot_chance + артефакт
# «Спуск штыка»). Выстрел — бонус-акцент, не превращает штык в вторую аркебузу.
const BAYONET_CONTACT_RESCUE_RADIUS := 52.0


func _exec_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_arquebus_shot(owner_node, target, direction)


func _exec_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_grenade_fuse(owner_node, target, direction)


func _exec_bayonet_cone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_bayonet_cone(owner_node, direction)


# SCRUM-936 «Аркебуза»: одна быстрая взрывная пуля — видимый снаряд летит далеко
# в цель и взрывается малым AoE (полный урон в центре, falloff к краю зоны).
# Внутренний capability seam extra_projectile при injected value добавляет пули
# по следующим ближайшим целям. FAN-2247: player-facing source отсутствует —
# ни один active artifact/reward/config сейчас не выдаёт этот ключ. Trait
# «Двойное действие» даёт второй независимый выстрел через _maybe_fire_action_echo
# (без рекурсии).
func _fire_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var count := maxi(1 + _extra_projectiles(), 1)
	var targets := _find_closest_enemies(owner_node, count)
	if targets.is_empty():
		if target != null and is_instance_valid(target):
			targets = [target]  # цель вне базового радиуса поиска (передана _attack)
		else:
			_launch_arquebus_bullet(owner_node, null, direction)
			return
	for target_index in range(mini(count, targets.size())):
		var target_node := targets[target_index] as Node2D
		var aim := direction
		if target_node != null:
			var to_target: Vector2 = target_node.global_position - owner_node.global_position
			if to_target.length_squared() > 0.001:
				aim = to_target.normalized()
		_launch_arquebus_bullet(owner_node, target_node, aim)


func _launch_arquebus_bullet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 28.0
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 560.0)
	if target != null:
		target_position = target.global_position
	# Короткая вспышка у дула — читаемое начало выстрела (важно для эха: два дула).
	var muzzle := AttackVfx.beam(_projectile_parent(), start, start + direction * 46.0, beam_width, Color(visual_color.r, visual_color.g, visual_color.b, 0.55))
	_register_effect(muzzle)
	var bullet := _spawn_projectile_visual(start, target_position - start)
	_register_effect(bullet)
	var travel_time: float = clampf(start.distance_to(target_position) / maxf(projectile_speed, 1.0), 0.05, 0.60)
	var tween := create_tween()
	tween.tween_property(bullet, "global_position", target_position, travel_time).set_trans(Tween.TRANS_LINEAR)
	# SCRUM-551: Callable + примитивные bind-аргументы вместо лямбды с захватом узлов.
	tween.tween_callback(Callable(self, "_explode_arquebus_bullet").bind(bullet.get_instance_id(), owner_node.get_instance_id(), target_position, direction))


func _explode_arquebus_bullet(bullet_id: int, owner_id: int, center: Vector2, direction: Vector2) -> void:
	var bullet := instance_from_id(bullet_id) as Node
	if _effects_shutdown:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner)
	# SCRUM-961 «Шрапнель аркебузы» (rework SCRUM-936): осколочная зона шире (+25%)
	# и злее к соседям (falloff-пол 0.45→0.59); центр без изменений.
	var shrapnel := _owner_mod("arquebus_shrapnel_bonus") > 0.0
	var blast_radius := aoe_radius * (1.25 if shrapnel else 1.0)
	var edge_falloff := clampf(damage_falloff + (0.14 if shrapnel else 0.0), 0.0, 0.9)
	_damage_enemies_in_circle_falloff(center, blast_radius, explosion_damage, edge_falloff)
	for enemy_node in TARGET_QUERY.in_radius(self, center, blast_radius):
		_push_enemy(enemy_node, direction)
	AttackVfx.orb_burst(_projectile_parent(), center, blast_radius, _projectile_impact_color())
	if bullet != null and is_instance_valid(bullet):
		_release_effect(bullet)


func _fire_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-961 «Длинный фитиль»: фитиль горит дольше (+0.35с телеграф), взрыв
	# окупается (+long_fuse_bonus урона, +10% радиуса).
	var fuse_bonus := _owner_mod("long_fuse_bonus")
	var fuse_delay := maxf(grenade_delay, 0.20) + (0.35 if fuse_bonus > 0.0 else 0.0)
	var blast_radius := aoe_radius * (1.10 if fuse_bonus > 0.0 else 1.0)
	var blast_damage_mult := 1.0 + fuse_bonus
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 440.0)
	if target != null:
		target_position = target.global_position
	var start := owner_node.global_position + direction * 26.0
	var flight_speed := clampf(projectile_speed, 60.0, GRENADE_MAX_FLIGHT_SPEED)
	var travel_time := maxf(start.distance_to(target_position) / flight_speed, 0.25)
	_emit_weapon_animation_event(owner_node, "windup", travel_time + fuse_delay, direction, {"delayed": true})
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), target_position, blast_radius, visual_color, true)
	_register_effect(telegraph)
	var grenade := _spawn_projectile_visual(start, target_position - start)
	_register_effect(grenade)
	var tween := create_tween()
	tween.tween_property(grenade, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Посадка: отдельный «armed»-пульс фитиля — читаемая фаза между полётом и взрывом.
	tween.tween_callback(Callable(self, "_arm_grenade_fuse").bind(owner_node.get_instance_id(), target_position, blast_radius, direction, fuse_delay))
	tween.tween_interval(fuse_delay)
	tween.tween_callback(Callable(self, "_explode_grenade_fuse").bind(grenade.get_instance_id(), telegraph.get_instance_id(), owner_node.get_instance_id(), target_position, blast_radius, blast_damage_mult, direction))


func _arm_grenade_fuse(owner_id: int, center: Vector2, blast_radius: float, direction: Vector2, fuse_delay: float) -> void:
	if _effects_shutdown:
		return
	var fuse_ring := AttackVfx.ring_pulse(_projectile_parent(), center, blast_radius * 0.45, Color(1.0, 0.82, 0.30, 0.55), false)
	if fuse_ring != null:
		_register_effect(fuse_ring)
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_emit_weapon_animation_event(current_owner, "pulse", fuse_delay, direction, {"fuse": true})


func _explode_grenade_fuse(grenade_id: int, telegraph_id: int, owner_id: int, center: Vector2, blast_radius: float, blast_damage_mult: float, direction: Vector2) -> void:
	var current_grenade := instance_from_id(grenade_id) as Node
	var current_telegraph := instance_from_id(telegraph_id) as Node
	if _effects_shutdown:
		if current_grenade != null and is_instance_valid(current_grenade):
			current_grenade.queue_free()
		if current_telegraph != null and is_instance_valid(current_telegraph):
			current_telegraph.queue_free()
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner)
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	explosion_damage *= blast_damage_mult
	_damage_enemies_in_circle_falloff(center, blast_radius, explosion_damage, damage_falloff)
	var shrapnel_result := _constellation_event("explosion", null, explosion_damage)
	if bool(shrapnel_result.get("triggered", false)):
		var shrapnel_ratio := maxf(float(shrapnel_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
		var shrapnel_tween := create_tween()
		shrapnel_tween.tween_interval(0.18)
		shrapnel_tween.tween_callback(Callable(self, "_constellation_grenade_second_wave").bind(center, explosion_damage * shrapnel_ratio, blast_radius))
	AttackVfx.orb_burst(_projectile_parent(), center, blast_radius, _projectile_impact_color())
	if current_grenade != null and is_instance_valid(current_grenade):
		_release_effect(current_grenade)
	if current_telegraph != null and is_instance_valid(current_telegraph):
		_release_effect(current_telegraph)


func _constellation_grenade_second_wave(center: Vector2, shard_damage: float, blast_radius: float) -> void:
	if _effects_shutdown or shard_damage <= 0.0:
		return
	var hit_counts := {}
	for shard_index in range(8):
		var shard_direction := Vector2.RIGHT.rotated(TAU * float(shard_index) / 8.0)
		var finish := center + shard_direction * blast_radius * 1.25
		_register_effect(AttackVfx.beam(_projectile_parent(), center, finish, maxf(beam_width * 0.35, 10.0), visual_color))
		for enemy_raw in TARGET_QUERY.in_segment(self, center, finish, maxf(beam_width, 28.0)):
			var enemy := enemy_raw as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var enemy_id := enemy.get_instance_id()
			if int(hit_counts.get(enemy_id, 0)) >= 2:
				continue
			hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
			_call_take_damage(enemy, shard_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "grenade_shrapnel_second_wave"})


func _fire_bayonet_cone(owner_node: Node2D, direction: Vector2) -> void:
	var cone_visual := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(cone_visual)
	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position
	var brace_profile := _constellation_profile("bayonet_brace_countershot")
	var brace_params: Dictionary = brace_profile.get("params", {}) if not brace_profile.is_empty() else {}
	var brace_seconds := maxf(float(brace_params.get("brace_window_seconds", 0.5)), 0.0)
	var brace_candidate_id := 0
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_enemy_inside_bayonet_cone(origin, enemy_node.global_position, direction):
			continue
		_damage_enemy(enemy_node, damage_value)
		var push_direction := (enemy_node.global_position - origin)
		_push_enemy(enemy_node, push_direction.normalized() if push_direction.length_squared() > 0.001 else direction)
		if brace_candidate_id == 0:
			brace_candidate_id = enemy_node.get_instance_id()
	if brace_candidate_id != 0 and brace_seconds > 0.0:
		var brace_token := int(_constellation_local_state.get("bayonet_brace_token", 0)) + 1
		var brace_until_msec := Time.get_ticks_msec() + int(brace_seconds * 1000.0)
		_constellation_local_state["bayonet_brace_token"] = brace_token
		_constellation_local_state["bayonet_brace_until_msec"] = brace_until_msec
		_constellation_local_state["bayonet_brace_used"] = false
		var brace_tween := create_tween()
		brace_tween.tween_interval(0.10)
		brace_tween.tween_callback(Callable(self, "_resolve_bayonet_brace_countershot").bind(brace_token, origin, brace_candidate_id, damage_value))
	# Редкий выстрел: встроенный шанс оружия + артефакт SCRUM-961 «Спуск штыка».
	var shot_chance := clampf(bayonet_auto_shot_chance + _owner_mod("bayonet_shot_chance"), 0.0, 1.0)
	if randf() < shot_chance:
		_fire_bayonet_auto_shot(owner_node, direction)


func _resolve_bayonet_brace_countershot(brace_token: int, origin: Vector2, target_id: int, base_damage: float) -> void:
	if _effects_shutdown or int(_constellation_local_state.get("bayonet_brace_token", 0)) != brace_token:
		return
	if bool(_constellation_local_state.get("bayonet_brace_used", false)):
		return
	var brace_until_msec := int(_constellation_local_state.get("bayonet_brace_until_msec", 0))
	if Time.get_ticks_msec() >= brace_until_msec:
		return
	var target := instance_from_id(target_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	var counter_result := _constellation_event("brace_hit", target, 0.0, {"brace_until_msec": brace_until_msec})
	if not bool(counter_result.get("triggered", false)):
		return
	_constellation_local_state["bayonet_brace_used"] = true
	var ratio := _constellation_result_param(counter_result, "countershot_damage_ratio", 0.55)
	_fire_bayonet_countershot_line(origin, target.global_position, base_damage * ratio)


func _fire_bayonet_countershot_line(origin: Vector2, through_position: Vector2, counter_damage: float) -> void:
	var line_direction := (through_position - origin).normalized()
	if line_direction.length_squared() <= 0.001 or counter_damage <= 0.0:
		return
	var line_end := origin + line_direction * maxf(bayonet_shot_range, attack_range)
	_register_effect(AttackVfx.beam(_projectile_parent(), origin, line_end, maxf(beam_width * 0.55, 10.0), visual_color))
	var half_width := maxf(beam_width * 0.75, 14.0)
	for target in TARGET_QUERY.enemies(self):
		if not is_instance_valid(target):
			continue
		var enemy := target as Node2D
		if enemy == null:
			continue
		var relative := enemy.global_position - origin
		var forward := relative.dot(line_direction)
		if forward < 0.0 or forward > maxf(bayonet_shot_range, attack_range):
			continue
		if absf(relative.cross(line_direction)) > half_width:
			continue
		_call_take_damage(enemy, counter_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "bayonet_brace_countershot"})


func _is_enemy_inside_bayonet_cone(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var to_enemy := enemy_position - origin
	var distance := to_enemy.length()
	# Анти-deadzone: враг у самых ног (включая застрявшего на игроке) всегда в зоне.
	if distance <= BAYONET_CONTACT_RESCUE_RADIUS:
		return true
	if distance > attack_range:
		return false
	return absf(direction.angle_to(to_enemy)) <= deg_to_rad(clampf(cone_degrees, 1.0, 360.0) * 0.5)


# Авто-выстрел штыка: цель — ближайший враг ВНЕ конуса (дальше досягаемости укола),
# в пределах bayonet_shot_range; без такой цели пуля уходит по направлению укола.
# Урон bayonet_shot_damage_multiplier от укола первому врагу на траектории.
func _fire_bayonet_auto_shot(owner_node: Node2D, direction: Vector2) -> void:
	var shot_direction := direction
	var beyond_target := _find_bayonet_shot_target(owner_node)
	if beyond_target != null:
		var to_target := beyond_target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			shot_direction = to_target.normalized()
	var start := owner_node.global_position + shot_direction * 22.0
	var tracer := AttackVfx.beam(_projectile_parent(), start, owner_node.global_position + shot_direction * bayonet_shot_range, beam_width * 0.6, Color(visual_color.r, visual_color.g, visual_color.b, 0.50))
	_register_effect(tracer)
	_emit_weapon_animation_event(owner_node, "pulse", 0.0, shot_direction, {"bayonet_shot": true})
	var hits := _enemies_in_corridor(start, shot_direction, maxf(beam_width, 40.0), bayonet_shot_range)
	if hits.is_empty():
		return
	_damage_enemy(hits[0]["node"], _rolled_damage(owner_node) * bayonet_shot_damage_multiplier)


func _find_bayonet_shot_target(owner_node: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var origin := owner_node.global_position
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := origin.distance_to(enemy_node.global_position)
		if distance <= attack_range or distance > bayonet_shot_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best = enemy_node
	return best
