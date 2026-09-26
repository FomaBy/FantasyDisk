extends "res://scripts/classes/robot_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса sniper.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# SCRUM-931 «Винтовка Мертвого Глаза» (PREFERRED-вариант, зафиксирован): всегда
const DEADEYE_LOCK_MAIN_MULT := 1.34        # тяжёлый прямой хит по дальней цели


const DEADEYE_ENDPOINT_BLAST_RATIO := 0.42  # FAN-1031 v7: 0.35→0.42 — deadeye-специфичный буст снайпера (терминальный взрыв на конце линии; вне budget-компенсации, лендится напрямую). Артефакт «Патрон мертвого глаза» добавляет сверху.


const SHATTER_VOLLEY_HIT_LIMIT := 2         # макс пуль в одного врага за залп


func _exec_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_lockshot(owner_node, target, direction)


func _exec_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_kill_zone(owner_node, target, direction)


func _exec_sniper_split_round(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_split_round(owner_node, target, direction)


func _fire_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# Всегда самая дальняя валидная цель; переданная цель — резервный aim.
	var locked_target := _find_farthest_enemy(owner_node, attack_range)
	if locked_target == null:
		locked_target = target
	var aim := direction
	if locked_target != null and is_instance_valid(locked_target):
		var to_target := locked_target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			aim = to_target.normalized()
	var endpoint := owner_node.global_position + aim * attack_range
	if locked_target != null and is_instance_valid(locked_target):
		endpoint = locked_target.global_position
	var start := owner_node.global_position + aim * 30.0
	var telegraph := AttackVfx.beam(_projectile_parent(), start, endpoint, maxf(beam_width * 0.65, 18.0), Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	_register_effect(telegraph)
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.08), aim, {"delayed": true})
	var target_id := locked_target.get_instance_id() if (locked_target != null and is_instance_valid(locked_target)) else 0
	var lock_tween := create_tween()
	lock_tween.tween_interval(maxf(grenade_delay, 0.08))
	lock_tween.tween_callback(Callable(self, "_resolve_sniper_lockshot").bind(owner_node.get_instance_id(), target_id, aim, telegraph.get_instance_id()))


# SCRUM-931: разрешение выстрела винтовки — тяжёлый хит по дальней цели +
# overpenetration-коридор по попутчикам (кроме первичной цели, чтобы соло-выход
# совпадал с budget-моделью 1.34 + endpoint) + терминальный взрыв на конце линии
# + ближний самоподрыв. Trait «Дальний расчёт» скейлит каждый _damage_enemy по
# дистанции владелец→жертва в этот момент (AC: отложенная атака честна).
func _resolve_sniper_lockshot(owner_id: int, target_id: int, aim: Vector2, telegraph_id: int) -> void:
	var current_owner := instance_from_id(owner_id) as Node2D
	if _effects_shutdown or current_owner == null or not is_instance_valid(current_owner):
		_release_effect_by_id(telegraph_id)
		return
	var shot_aim := aim
	var locked := instance_from_id(target_id) as Node2D
	var endpoint := current_owner.global_position + shot_aim * attack_range
	if locked != null and is_instance_valid(locked):
		var to_target := locked.global_position - current_owner.global_position
		if to_target.length_squared() > 0.001:
			shot_aim = to_target.normalized()
		endpoint = locked.global_position
	var start := current_owner.global_position + shot_aim * 30.0
	var damage_value := _rolled_damage(current_owner)
	var tracer := AttackVfx.beam(_projectile_parent(), start, endpoint, beam_width, visual_color)
	_register_effect(tracer)
	_emit_weapon_animation_event(current_owner, "release", 0.0, shot_aim, {"delayed": true})
	var rifle_hit := damage_value * DEADEYE_LOCK_MAIN_MULT
	var pierced := {}
	if locked != null and is_instance_valid(locked):
		pierced[locked.get_instance_id()] = true
		rifle_hit *= _consume_constellation_target_mark(locked, "weakpoint", 1.0)
		_damage_enemy(locked, rifle_hit)
		var weakpoint := _constellation_event("hit", locked, 0.0, {"constellation_consumer_event": true})
		if bool(weakpoint.get("triggered", false)):
			_arm_constellation_target_mark(locked, "weakpoint", _constellation_result_param(weakpoint, "weakpoint_seconds", 4.0), _constellation_result_param(weakpoint, "bonus_damage_cap", 0.30))
	# Overpenetration: попутчики на линии (не первичная цель) ловят falloff-долю.
	for hit in _enemies_in_corridor(start, shot_aim, beam_width * 0.72, start.distance_to(endpoint)):
		var pierce_node := hit["node"] as Node2D
		if pierce_node == null or not is_instance_valid(pierce_node) or pierced.has(pierce_node.get_instance_id()):
			continue
		pierced[pierce_node.get_instance_id()] = true
		_damage_enemy(pierce_node, damage_value * damage_falloff)
	# Терминальный взрыв на конце линии (артефакт «Патрон мертвого глаза» усиливает).
	var endpoint_ratio := DEADEYE_ENDPOINT_BLAST_RATIO + _owner_mod("deadeye_terminal_blast")
	var blast_radius := maxf(beam_width * 2.2, aoe_radius * 0.28)
	AttackVfx.orb_burst(_projectile_parent(), endpoint, blast_radius, visual_color)
	_damage_enemies_in_circle_falloff(endpoint, blast_radius, damage_value * endpoint_ratio, 0.5)
	# Ближний самоподрыв у ног — ~80% урона выстрела по врагам вплотную.
	if close_burst_ratio > 0.0 and close_burst_radius > 0.0:
		AttackVfx.orb_burst(_projectile_parent(), current_owner.global_position, close_burst_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
		_damage_enemies_in_circle_falloff(current_owner.global_position, close_burst_radius, rifle_hit * close_burst_ratio, 0.6)
	_release_effect_by_id(telegraph_id)


# SCRUM-961 «Патрон мертвого глаза»: самая дальняя цель в пределах дальности.
func _find_farthest_enemy(owner_node: Node2D, range_limit: float) -> Node2D:
	var best: Node2D = null
	var best_distance := -1.0
	var range_squared := range_limit * range_limit
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		if distance <= range_squared and distance > best_distance:
			best_distance = distance
			best = enemy_node
	return best


# SCRUM-932 «Прицел Наводчика»: отложенный артиллерийский AoE. Красный
func _fire_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var center: Vector2 = owner_node.global_position + direction * minf(attack_range, 620.0)
	if target != null and is_instance_valid(target):
		center = target.global_position
	# Артефакт «Метка наводчика»: зона ложится быстрее и добивает сильнее.
	var fast_mark := _owner_mod("spotter_fast_mark") > 0.0
	var mark_delay := maxf(grenade_delay * (0.65 if fast_mark else 1.0), 0.12)
	var zone_radius := aoe_radius
	# Красный полупрозрачный телеграф (AC: semi-transparent red circle).
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, zone_radius, Color(0.95, 0.15, 0.12, 0.32), true)
	_register_effect(telegraph)
	_emit_weapon_animation_event(owner_node, "windup", mark_delay, direction, {"delayed": true})
	var zone_tween := create_tween()
	zone_tween.tween_interval(mark_delay)
	zone_tween.tween_callback(Callable(self, "_land_spotter_shell").bind(owner_node.get_instance_id(), center, zone_radius, telegraph.get_instance_id(), direction))


# SCRUM-932: падение снаряда Наводчика в конце задержки — тяжёлый AoE по всей
# зоне (falloff к краю), урон каждого попадания скейлит trait по дистанции
# владелец→жертва. Артефакт «Метка наводчика» добавляет добивающий множитель
# взамен снятого серийного удара старого дизайна.
func _land_spotter_shell(owner_id: int, center: Vector2, zone_radius: float, telegraph_id: int, direction: Vector2) -> void:
	if _effects_shutdown:
		_release_effect_by_id(telegraph_id)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var damage_value := damage
	if current_owner != null and is_instance_valid(current_owner):
		damage_value = _rolled_damage(current_owner)
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	if _owner_mod("spotter_fast_mark") > 0.0:
		damage_value *= 1.15
	AttackVfx.orb_burst(_projectile_parent(), center, zone_radius, visual_color)
	_damage_enemies_in_circle_falloff(center, zone_radius, damage_value, damage_falloff)
	var priority_target: Node2D = null
	var priority_health := -1.0
	for candidate_raw in TARGET_QUERY.in_radius(self, center, zone_radius):
		var candidate := candidate_raw as Node2D
		var candidate_health = candidate.get("health")
		var score := float(candidate_health) if candidate_health != null else 0.0
		if score > priority_health:
			priority_health = score
			priority_target = candidate
	if priority_target != null:
		var priority := _constellation_event("target_acquired", priority_target, 0.0)
		if bool(priority.get("triggered", false)):
			var mark_until := Time.get_ticks_msec() + int(_constellation_result_param(priority, "mark_seconds", 3.0) * 1000.0)
			priority_target.set_meta(_constellation_mark_key("spotter"), {"until_msec": mark_until})
			var reserved := create_tween()
			reserved.tween_interval(0.08)
			reserved.tween_callback(Callable(self, "_constellation_spotter_reserved_beam").bind(priority_target.get_instance_id(), center, damage_value, mark_until, _constellation_result_param(priority, "priority_bonus_cap", 0.26)))
	_release_effect_by_id(telegraph_id)


func _constellation_spotter_reserved_beam(target_id: int, origin: Vector2, base_damage: float, mark_until: int, bonus_cap: float) -> void:
	if _effects_shutdown or Time.get_ticks_msec() > mark_until:
		return
	var target := instance_from_id(target_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	var mark_raw = target.get_meta(_constellation_mark_key("spotter"), {})
	if not mark_raw is Dictionary or int((mark_raw as Dictionary).get("until_msec", 0)) != mark_until:
		return
	target.remove_meta(_constellation_mark_key("spotter"))
	_register_effect(AttackVfx.beam(_projectile_parent(), origin, target.global_position, maxf(beam_width * 0.55, 12.0), visual_color))
	_call_take_damage(target, base_damage * clampf(bonus_cap, 0.0, 0.30), {"damage_type": _weapon_damage_type(), "constellation_final": "spotter_highest_hp_priority"})


# SCRUM-933 «Осколочные Патроны»: скорострельный круговой веер пуль по ближним
func _fire_sniper_split_round(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_constellation_shatter_volley_token += 1
	var volley_token := _constellation_shatter_volley_token
	_constellation_shatter_volleys[volley_token] = {}
	while _constellation_shatter_volleys.size() > 8:
		var oldest_token: int = int(_constellation_shatter_volleys.keys().min())
		_constellation_shatter_volleys.erase(oldest_token)
	var origin := owner_node.global_position
	var bullet_count := maxi(projectile_count + _extra_projectiles() + int(_owner_mod("shatter_extra_splits")), 1)
	var spray_radius := maxf(aoe_radius, 160.0)
	var candidates := _nearest_enemies_from(origin, spray_radius, bullet_count)
	if candidates.is_empty() and target != null and is_instance_valid(target):
		if origin.distance_to(target.global_position) <= spray_radius:
			candidates = [target]
	# Round-robin слоты: каждый ближний враг получает до SHATTER_VOLLEY_HIT_LIMIT
	# пуль, ближайшие — первыми (проходы по отсортированному списку).
	var target_slots: Array = []
	for volley_pass in range(SHATTER_VOLLEY_HIT_LIMIT):
		for candidate in candidates:
			if target_slots.size() >= bullet_count:
				break
			target_slots.append(candidate)
		if target_slots.size() >= bullet_count:
			break
	var damage_value := _rolled_damage(owner_node)
	var base_angle := direction.angle() if direction.length_squared() > 0.001 else 0.0
	for bullet_index in range(bullet_count):
		var aimed_target: Node2D = (target_slots[bullet_index] as Node2D) if bullet_index < target_slots.size() else null
		var bullet_aim: Vector2
		var bullet_finish: Vector2
		if aimed_target != null and is_instance_valid(aimed_target):
			var to_target: Vector2 = aimed_target.global_position - origin
			bullet_aim = to_target.normalized() if to_target.length_squared() > 0.001 else Vector2.RIGHT.rotated(base_angle)
			bullet_finish = aimed_target.global_position
		else:
			# Пустое направление: ровный радиальный веер, урона нет.
			var fan_angle := base_angle + TAU * float(bullet_index) / float(bullet_count)
			bullet_aim = Vector2.RIGHT.rotated(fan_angle)
			bullet_finish = origin + bullet_aim * spray_radius
		var bullet_start := origin + bullet_aim * 24.0
		var bullet := _spawn_projectile_visual(bullet_start, bullet_aim)
		_register_effect(bullet)
		var travel_time := clampf(bullet_start.distance_to(bullet_finish) / maxf(projectile_speed, 1.0), 0.04, 0.6)
		var aimed_id := aimed_target.get_instance_id() if (aimed_target != null and is_instance_valid(aimed_target)) else 0
		var bullet_tween := create_tween()
		bullet_tween.tween_property(bullet, "global_position", bullet_finish, travel_time).set_trans(Tween.TRANS_LINEAR)
		bullet_tween.tween_callback(Callable(self, "_impact_shatter_bullet").bind(bullet.get_instance_id(), aimed_id, damage_value, volley_token))
	_emit_weapon_animation_event(owner_node, "release", 0.0, direction, {})


# SCRUM-933: импакт одиночной пули веера — одиночный физический хит по своей
# цели (trait «Дальний расчёт» скейлит по дистанции), пули без цели просто
# гаснут. Разрешение через Callable + примитивы (SCRUM-551, без захвата узлов).
func _impact_shatter_bullet(bullet_id: int, target_id: int, damage_value: float, volley_token := 0) -> void:
	var bullet := instance_from_id(bullet_id) as Node
	if _effects_shutdown:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
		return
	var enemy := instance_from_id(target_id) as Node2D
	if enemy != null and is_instance_valid(enemy):
		var enemy_id := enemy.get_instance_id()
		var state_key := volley_token
		if state_key <= 0:
			_constellation_shatter_volley_token += 1
			state_key = _constellation_shatter_volley_token
		var hit_counts_raw = _constellation_shatter_volleys.get(state_key, {})
		var hit_counts: Dictionary = hit_counts_raw if hit_counts_raw is Dictionary else {}
		if int(hit_counts.get(enemy_id, 0)) < 2:
			hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
			_constellation_shatter_volleys[state_key] = hit_counts
			AttackVfx.orb_burst(_projectile_parent(), enemy.global_position, maxf(beam_width, 18.0), _projectile_impact_color())
			_damage_enemy(enemy, damage_value)
			var pierce_result := _constellation_event("pierce", enemy, 0.0)
			if bool(pierce_result.get("triggered", false)):
				var excluded := {enemy_id: true}
				for counted_id in hit_counts.keys():
					if int(hit_counts.get(counted_id, 0)) >= 2:
						excluded[int(counted_id)] = true
				var next_target := TARGET_QUERY.nearest(self, enemy.global_position, maxf(aoe_radius, 160.0), excluded)
				if next_target != null:
					var repeat_ratio := maxf(float(pierce_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
					_register_effect(AttackVfx.beam(_projectile_parent(), enemy.global_position, next_target.global_position, maxf(beam_width * 0.45, 10.0), visual_color))
					_call_take_damage(next_target, damage_value * repeat_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "shatter_extra_pierce_falloff"})
					hit_counts[next_target.get_instance_id()] = int(hit_counts.get(next_target.get_instance_id(), 0)) + 1
					_constellation_shatter_volleys[state_key] = hit_counts
	if bullet != null and is_instance_valid(bullet):
		_release_effect(bullet)


func _nearest_enemies_from(origin: Vector2, range_limit: float, count: int, excluded_ids: Dictionary = {}) -> Array:
	return TARGET_QUERY.nearest_many(self, origin, range_limit, count, excluded_ids)


func _damage_split_shard_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float, amount: float, excluded_ids: Dictionary, hit_limit: int) -> int:
	var hit_count := 0
	for hit in _enemies_in_corridor(origin, direction, width, range_limit):
		if hit_count >= hit_limit:
			break
		var enemy_node := hit["node"] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var enemy_id := enemy_node.get_instance_id()
		if excluded_ids.has(enemy_id):
			continue
		excluded_ids[enemy_id] = true
		_damage_enemy(enemy_node, amount * pow(0.72, float(hit_count)))
		hit_count += 1
	return hit_count
