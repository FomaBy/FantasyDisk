extends "res://scripts/classes/class_weapon_combat.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса assassin.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_boomerang(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_boomerang(owner_node, direction)


func _exec_stab_flurry(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_stab_flurry(owner_node, direction)


func _exec_dot_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_dot_beam(owner_node, direction)


func _fire_boomerang(owner_node: Node2D, direction: Vector2) -> void:
	# Чакрамы: урон по коридору к цели сразу и повторно на «возврате» через 0.25с.
	var origin := owner_node.global_position
	var outbound_damage := _rolled_damage(owner_node)
	var chakram_profile := _constellation_profile("chakram_return_execute_mark")
	for hit in _enemies_in_corridor(origin, direction, beam_width, attack_range):
		var outbound_target := hit["node"] as Node2D
		_damage_enemy(outbound_target, outbound_damage)
		if not chakram_profile.is_empty() and is_instance_valid(outbound_target):
			var params: Dictionary = chakram_profile.get("params", {})
			_arm_constellation_target_mark(outbound_target, "chakram", float(params.get("mark_seconds", 1.8)), float(params.get("return_bonus_cap", 0.30)), float(params.get("execute_threshold", 0.28)))
	var orb := _spawn_projectile_visual(origin + direction * 24.0, direction)
	_register_effect(orb)
	var far_point := origin + direction * attack_range
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", far_point, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# SCRUM-551: захват owner_node/orb (Node) в lambda интермиттентно «освобождался»
	# под быстрым create/free в balance-CSV. Резолвим по instance_id внутри + гвард.
	var owner_id := owner_node.get_instance_id()
	var orb_id := orb.get_instance_id()
	var weapon_self_id := get_instance_id()
	if return_arc_offset > 0.0:
		orb_tween.tween_callback(Callable(self, "_begin_boomerang_return_arc").bind(owner_id, orb_id, far_point, direction))
		return
	orb_tween.tween_property(orb, "global_position", origin, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	orb_tween.tween_callback(func() -> void:
		var w := instance_from_id(weapon_self_id) as Node
		var o := instance_from_id(owner_id) as Node2D
		if w != null and o != null and is_instance_valid(w) and is_instance_valid(o):
			w.call("_damage_boomerang_return", o.global_position, direction, w.call("_rolled_damage", o))
		var orb_node := instance_from_id(orb_id) as Node
		if w != null and is_instance_valid(w) and orb_node != null and is_instance_valid(orb_node):
			w.call("_release_effect", orb_node)
	)


# SCRUM-961 «Руна обратной дуги»: обратный проход чакрамов идёт по широкой дуге
# (+boomerang_return_width_mult к коридору) и бьёт больнее (+boomerang_return_damage_mult).
# Без ключей тождествен прежнему возврату.
func _damage_boomerang_return(origin: Vector2, direction: Vector2, amount: float) -> void:
	var return_width := beam_width * (1.0 + _owner_mod("boomerang_return_width_mult"))
	var return_damage := amount * (1.0 + _owner_mod("boomerang_return_damage_mult"))
	for hit in _enemies_in_corridor(origin, direction, return_width, attack_range):
		var enemy_node := hit["node"] as Node2D
		var return_event := _constellation_event("return", enemy_node, 0.0, {"constellation_consumer_event": true})
		var marked_damage := return_damage * _consume_constellation_target_mark(enemy_node, "chakram") if bool(return_event.get("triggered", false)) else return_damage
		_damage_enemy(enemy_node, marked_damage)


# SCRUM-894: разворот чакрамов — считаем дугу от точки разворота к текущей позиции
# героя, наносим return-урон вдоль дуги и ведём орб по той же кривой. Bound-метод
# вместо лямбды с захватом узлов (канон SCRUM-551), резолв по instance_id + гварды.
func _begin_boomerang_return_arc(owner_id: int, orb_id: int, far_point: Vector2, direction: Vector2) -> void:
	var owner_node := instance_from_id(owner_id) as Node2D
	var orb := instance_from_id(orb_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or not is_inside_tree():
		if orb != null and is_instance_valid(orb):
			_release_effect(orb)
		return
	var home := owner_node.global_position
	var control := _boomerang_return_control_point(far_point, home, direction)
	_damage_boomerang_return_arc(far_point, control, home, _rolled_damage(owner_node))
	if orb == null or not is_instance_valid(orb):
		return
	var arc_tween := create_tween()
	arc_tween.tween_method(Callable(self, "_step_orb_along_return_arc").bind(orb_id, far_point, control, home), 0.0, 1.0, 0.25)
	arc_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(orb_id))


# Контрольная точка возврата: середина хорды + смещение в ЛЕВУЮ сторону
# относительно направления броска (в экранных координатах Godot y вниз,
# левая нормаль = (dir.y, -dir.x)).
func _boomerang_return_control_point(from_point: Vector2, home: Vector2, direction: Vector2) -> Vector2:
	var left_normal := Vector2(direction.y, -direction.x)
	return (from_point + home) * 0.5 + left_normal * return_arc_offset


# Возврат-урон вдоль дуги: сэмплируем кривую полилинией и бьём каждого врага
# коридора НЕ БОЛЕЕ ОДНОГО РАЗА (дедуп по instance_id — per-cast/per-target гейт).
# Артефактные ключи SCRUM-961 (ширина/урон возврата) продолжают действовать.
func _damage_boomerang_return_arc(from_point: Vector2, control: Vector2, home: Vector2, amount: float) -> void:
	var return_width := beam_width * (1.0 + _owner_mod("boomerang_return_width_mult"))
	var return_damage := amount * (1.0 + _owner_mod("boomerang_return_damage_mult"))
	var hit_ids := {}
	var previous := from_point
	for step in range(1, BOOMERANG_ARC_SAMPLES + 1):
		var point := _quadratic_bezier_point(from_point, control, home, float(step) / float(BOOMERANG_ARC_SAMPLES))
		for enemy_raw in TARGET_QUERY.in_segment(self, previous, point, return_width):
			var enemy_node := enemy_raw as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var enemy_id := enemy_node.get_instance_id()
			if hit_ids.has(enemy_id):
				continue
			hit_ids[enemy_id] = true
			var return_event := _constellation_event("return", enemy_node, 0.0, {"constellation_consumer_event": true})
			var marked_damage := return_damage * _consume_constellation_target_mark(enemy_node, "chakram") if bool(return_event.get("triggered", false)) else return_damage
			_damage_enemy(enemy_node, marked_damage)
		previous = point


func _step_orb_along_return_arc(progress: float, orb_id: int, from_point: Vector2, control: Vector2, home: Vector2) -> void:
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	orb.global_position = _quadratic_bezier_point(from_point, control, home, clampf(progress, 0.0, 1.0))


func _fire_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	# FAN-1893: луч — не снаряд; generic «+1 снаряд» веер лучей не расширяет.
	var count := maxi(beam_count, 1)
	_emit_weapon_animation_event(owner_node, "channel", maxf(0.16, float(maxi(dot_ticks, 1)) * 0.04), direction, {"beam_count": count, "dot_ticks": dot_ticks})
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_dot_beam(owner_node, direction.rotated(fan_offset))


func _fire_single_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-894: при close_contact_radius > 0 (Ядовитая струна) линия начинается
	# у самого героя, а враги вплотную (с любой стороны) становятся ПЕРВЫМИ
	# кандидатами — точка в упор не мёртвая. Пирс-лимит общий для близких и
	# коридорных целей — бесплатных дополнительных хитов нет.
	var beam_visual_offset := 6.0 if close_contact_radius > 0.0 else 26.0
	var start := owner_node.global_position + direction * beam_visual_offset
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	var seen_ids := {}
	if close_contact_radius > 0.0:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, close_contact_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.18), false)
		for enemy_node in TARGET_QUERY.in_radius(self, owner_node.global_position, close_contact_radius):
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			seen_ids[enemy_node.get_instance_id()] = true
			# Отрицательный forward ставит цели в упор впереди коридорных при сортировке.
			hits.append({
				"node": enemy_node,
				"forward": owner_node.global_position.distance_to(enemy_node.global_position) - close_contact_radius,
			})
	var corridor_origin := owner_node.global_position if close_contact_radius > 0.0 else start
	for hit in _enemies_in_corridor(corridor_origin, direction, beam_width, attack_range):
		var corridor_enemy := hit["node"] as Node2D
		if corridor_enemy != null and seen_ids.has(corridor_enemy.get_instance_id()):
			continue
		hits.append(hit)

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var pierced_ids := {}
	var spread_center := finish
	for hit in hits:
		if hit_count >= hit_limit:
			break
		var hit_node := hit["node"] as Node2D
		_damage_enemy_with_dot(hit_node, damage_value * pow(falloff, float(hit_count)), owner_node)
		if hit_node != null and is_instance_valid(hit_node):
			pierced_ids[hit_node.get_instance_id()] = true
			spread_center = hit_node.global_position  # ядро спреда — самый глубокий пробитый (там плотнее толпа)
		hit_count += 1
	# FAN-1031 v7: ядовитый крауд-спред (assassin venom_wire) — крауд-канал В СУЩЕСТВУЮЩИХ капах,
	# ортогональный solo (пробитые исключены). Сентинел 0.0 → ветка не выполняется (no-op).
	if dot_beam_spread_ratio > 0.0 and hit_count > 0:
		_venom_crowd_spread(spread_center, damage_value * dot_beam_spread_ratio, pierced_ids)


# FAN-1031 v7: ядовитый крауд-спред dot_beam (assassin venom_wire crowd-ниша). Брызг яда
# по врагам ВНЕ пробитой линии (exclude_ids) — отдельный крауд-канал, ОРТОГОНАЛЬНЫЙ solo:
# на 1 цели она пробита → исключена → спреда нет → solo не двигается. Кап ШИРИНЫ — те же
# aoe_max_targets/aoe_full_targets/aoe_target_diminish, что и прямой AoE (сентинел <0 → дефолт),
# та же диминиш-формула по рангу удалённости. Урон прямой (не DoT), доля direct×spread_ratio.
func _venom_crowd_spread(center: Vector2, amount: float, exclude_ids: Dictionary) -> void:
	var enemies: Array = []
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if exclude_ids.has((enemy_node as Node).get_instance_id()):
			continue
		enemies.append(enemy_node)
	if enemies.is_empty():
		return
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius * 0.6, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	var full_targets := aoe_full_targets if aoe_full_targets >= 0 else AOE_PROJECTILE_FULL_TARGETS
	var diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else AOE_PROJECTILE_TARGET_DIMINISH
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		# Жёсткий кап ШИРИНЫ — дальше aoe_max_targets НОЛЬ (как у прямого AoE, coverage-контракт).
		if aoe_max_targets >= 0 and index >= aoe_max_targets:
			break
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor)
