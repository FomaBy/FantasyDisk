extends "res://scripts/classes/chemist_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса dark_mage.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_homing_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_curse(owner_node, target, direction)


func _exec_dark_chain_burst(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_dark_chain_burst(owner_node, target, direction)


func _exec_skull_curse_burn(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_skull_curse_burn(owner_node, target, direction)


func _exec_dark_mirror_blast(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_dark_mirror_blast(owner_node, target, direction)


func _exec_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_beam(owner_node, direction)


func _exec_drain_link(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_drain_link(owner_node, target, direction)


func _fire_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		var miss_target: Vector2 = owner_node.global_position + direction * min(attack_range, 260.0)
		var miss_skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, miss_target, visual_color, 0.22, Callable(), _projectile_visual_profile())
		_register_effect(miss_skull)
		return

	var target_position := target.global_position
	var rolled := _rolled_damage(owner_node)
	var target_id := target.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		if current_weapon == null:
			return
		var current_target := instance_from_id(target_id) as Node2D
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_target != null:
			current_weapon.call("_damage_enemy_with_dot", current_target, rolled, current_owner)
		if aoe_radius > 0.0:
			current_weapon.call("_damage_enemies_in_circle_falloff", target_position, aoe_radius * 0.72, rolled * 0.42, current_weapon.get("damage_falloff"))
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius * 0.72, current_weapon.call("_projectile_impact_color"))
	, _projectile_visual_profile())
	_register_effect(skull)


# ============================================================================
# SCRUM-939..941: кит Тёмного мага (цепь палочки / curse-прожиг черепа /
# зеркальные взрывы книги). Все лямбды в tween_callback заменены на
# Callable(self, "...").bind(...) (канон SCRUM-551 против freed-lambda).
# ============================================================================


# SCRUM-939: Тёмная палочка — видимый цепной/рикошет-снаряд.
func _fire_dark_chain_burst(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var first_target := target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		# Пустая арена: видимый снаряд «в никуда», урона нет.
		var miss := _spawn_projectile_visual(owner_node.global_position + direction * 24.0, direction)
		_register_effect(miss)
		var miss_tween := create_tween()
		miss_tween.tween_property(miss, "global_position", owner_node.global_position + direction * minf(attack_range, 300.0), 0.2)
		miss_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(miss.get_instance_id()))
		return
	# Цепь выбирается детерминированно в момент каста.
	var chain: Array = [first_target]
	var used := {first_target.get_instance_id(): true}
	var hop_origin: Vector2 = first_target.global_position
	# FAN-1893: прыжки цепи — не снаряды; generic «+1 снаряд» цепь не удлиняет
	# (длину растит только классовый артефакт wand_extra_chain).
	var chain_limit := maxi(chain_targets + int(_owner_mod("wand_extra_chain")), 1)
	for hop_index in range(chain_limit - 1):
		var next_target := _find_nearest_enemy_from(hop_origin, chain_hop_range, used)
		if next_target == null:
			break  # документированный fallback: цепь обрывается без повторов
		chain.append(next_target)
		used[next_target.get_instance_id()] = true
		hop_origin = next_target.global_position
	_launch_dark_chain_hop(owner_node.global_position + direction * 26.0, chain, 0, _rolled_damage(owner_node))


# Один видимый прыжок цепи: орб летит из точки предыдущего попадания в
# следующую цель; попадание резолвится по прилёту.
func _launch_dark_chain_hop(from_position: Vector2, chain: Array, hop_index: int, damage_value: float) -> void:
	if _effects_shutdown or hop_index >= chain.size():
		return
	var enemy_node := chain[hop_index] as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		# Цель умерла в полёте — цепь продолжает к следующей из той же точки.
		_launch_dark_chain_hop(from_position, chain, hop_index + 1, damage_value)
		return
	var target_position := enemy_node.global_position
	var orb := _spawn_projectile_visual(from_position, target_position - from_position)
	_register_effect(orb)
	var travel_time := clampf(from_position.distance_to(target_position) / maxf(projectile_speed, 1.0), 0.05, 0.30)
	var hop_tween := create_tween()
	hop_tween.tween_property(orb, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_callback(Callable(self, "_resolve_dark_chain_hit").bind(orb.get_instance_id(), chain, hop_index, damage_value))


func _resolve_dark_chain_hit(orb_id: int, chain: Array, hop_index: int, damage_value: float) -> void:
	if _effects_shutdown:
		return
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	var impact_position := orb.global_position
	_release_effect(orb)
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var enemy_node := chain[hop_index] as Node2D
	if enemy_node != null and is_instance_valid(enemy_node):
		impact_position = enemy_node.global_position
		var hit_damage := damage_value * pow(falloff, float(hop_index))
		_damage_enemy(enemy_node, hit_damage)
		_constellation_event("pierce", enemy_node, hit_damage)
		_fire_dark_chain_hit_burst(enemy_node, impact_position, hit_damage * chain_burst_ratio * (1.0 + _owner_mod("wand_burst_bonus")))
	_launch_dark_chain_hop(impact_position, chain, hop_index + 1, damage_value)


# Малый бурст у точки попадания цепи: соседи жертвы получают долю урона хита.
# Прямой урон без он-хит проков (анти-каскад §8.4: бурст не рикошетит и не
# порождает новые бурсты); сама жертва исключена (уже получила прямой хит).
func _fire_dark_chain_hit_burst(victim: Node2D, center: Vector2, amount: float) -> void:
	if amount <= 0.0 or aoe_radius <= 0.0:
		return
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, _projectile_impact_color())
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		if enemy_node == victim:
			continue
		if enemy_node.has_method("take_damage"):
			_call_take_damage(enemy_node, amount, {"damage_type": _weapon_damage_type()})


# SCRUM-940: Проклятый череп — ЧИСТОЕ проклятие, прямого урона нет.
func _fire_skull_curse_burn(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 300.0)
	if target != null:
		target_position = target.global_position
	elif _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
		target_position = owner_node.call("attack_aim_position", attack_range)
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, Callable(self, "_apply_skull_curse_zone").bind(target_position), _projectile_visual_profile())
	_register_effect(skull)


func _apply_skull_curse_zone(center: Vector2) -> void:
	if _effects_shutdown:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	# Документированный curse-пайплайн (SCRUM-940): сила тика = dot_damage *
	# curse_tick_multiplier * (1 + Интеллект * curse_int_scale). Интеллект
	# «углубляет» проклятие (канон identity), Знание/флэты дают dot_damage;
	# магические множители не участвуют. Зеркало — _budget_dot_dps.
	var owner_stats_raw = owner_node.get("stats")
	var owner_stats: Dictionary = owner_stats_raw if owner_stats_raw is Dictionary else {}
	var curse_depth := 1.0 + maxf(float(owner_stats.get("intelligence", 0.0)), 0.0) * maxf(curse_int_scale, 0.0)
	var tick_damage := maxf(float(parameters.get("dot_damage", 1.0)), 1.0) * maxf(curse_tick_multiplier, 0.0) * curse_depth
	var tick_speed := maxf(float(parameters.get("dot_speed", 1.0)), 0.2) * maxf(curse_tick_rate, 0.2)
	# Floor 0.1с зеркалит кламп StatusEffects.tick: выше ~10 тик/с прожиг не
	# ускоряется, но суммарный урон каста сохраняется (число тиков фиксировано).
	var tick_interval := maxf(1.0 / tick_speed, 0.1)
	var ticks := maxi(dot_ticks, 1)
	# +0.99 тика запаса: StatusEffects.tick списывает remaining ДО проверки
	# тика, и k-й тик реально срабатывает на первом кадре ПОСЛЕ k*interval —
	# с меньшим буфером последний тик терялся. +0.99 (а не +1.0) не даёт
	# родиться лишнему (ticks+1)-му тику на границе.
	var duration := (float(ticks) + 0.99) * tick_interval
	var cursed_count := 0
	var curse_burn_total := 0.0
	# FAN-1031 3c(b): крауд-проклятие ранжируется по дистанции от центра каста —
	# ближние status_full_targets прогорают полным тиком, дальний хвост толпы
	# диминишится (_status_fanout_factor). Кап бьёт крауд-runaway 20t (v3
	# cursed_skull 96.9k ≈21× медианы), НЕ трогая силу тика 1t/5t (identity кита).
	# Сентинел по умолчанию (без override) = factor 1.0 → прежнее поведение.
	for enemy_node in _status_fanout_order(center, TARGET_QUERY.in_radius(self, center, aoe_radius)):
		var target_tick := tick_damage * _status_fanout_factor(cursed_count)
		# FAN-1031 3c-final fix (peer review MINOR): жёсткий кап ШИРИНЫ = skip. Цель за
		# status_max_targets (factor==0) НЕ получает 0-уронный skull_curse (refresh затирал бы
		# живое проклятие) и НЕ кормит ульту — как в bio-ветках. order отсортирован → break.
		if target_tick <= 0.0:
			break
		StatusEffects.apply_status(enemy_node, "skull_curse", {
			"duration": duration,
			"dot_damage": target_tick,
			"dot_interval": tick_interval,
			"max_stacks": 1,
			"stack_mode": "refresh",
			"marker_color": Color(0.78, 0.16, 1.0, 1.0),
			# SCRUM-1007: тики проклятия — урон игрока (атрибуция он-килл trait).
			"tick_feedback": {"damage_type": "dot", "player_owned": true, "curse": true},
		})
		enemy_node.set_meta(_constellation_mark_key("skull_curse"), {
			"status": {
				"duration": duration,
				"dot_damage": target_tick,
				"dot_interval": tick_interval,
				"max_stacks": 1,
				"stack_mode": "refresh",
				"marker_color": Color(0.78, 0.16, 1.0, 1.0),
				"tick_feedback": {"damage_type": "dot", "player_owned": true, "curse": true},
			},
			"depth": 0,
		})
		if enemy_node is Node2D:
			HazardVfx.dot_tick(enemy_node, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))
		curse_burn_total += target_tick
		cursed_count += 1
	# Прямого урона нет → on_weapon_hit не зовётся; заряд ульты кормим явно
	# ожидаемым прожигом каста (половинный вес, без он-хит проков/вампиризма).
	# FAN-1031 3c-final fix (peer review MINOR): фид считаем от ФАКТИЧЕСКОГО прожига каста на
	# толпе (Σ диминишированных тиков = tick_damage × Σfactor), а НЕ tick_damage × cursed_count —
	# status fan-out кап (cursed_skull 4/1.0) теперь корректно урезает крауд-фид ульты.
	if cursed_count > 0 and owner_node.has_method("on_curse_applied"):
		owner_node.call("on_curse_applied", curse_burn_total * float(ticks) * 0.5)


# SCRUM-941: Книга тьмы — зеркальные AoE-взрывы вокруг мага.
func _fire_dark_mirror_blast(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var primary_targets: Array = []
	if target != null:
		# FAN-1893: единица атаки книги — зеркальная ПАРА (2 сферы); «+1 снаряд»
		# дал бы сразу две, поэтому generic-ось книгой не потребляется
		# (real_projectile_count 0) и пара всегда одна.
		primary_targets = _find_closest_enemies(owner_node, 1)
	var target_positions: Array[Vector2] = []
	if primary_targets.is_empty():
		var aim_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 360.0)
		if _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
			aim_position = owner_node.call("attack_aim_position", attack_range)
		target_positions.append(aim_position)
	else:
		for target_node in primary_targets:
			var enemy_node := target_node as Node2D
			if enemy_node != null and is_instance_valid(enemy_node):
				target_positions.append(enemy_node.global_position)
	if target_positions.is_empty():
		return
	_constellation_mirror_cast_token += 1
	var cast_token := _constellation_mirror_cast_token
	_constellation_mirror_casts[cast_token] = {"pending_pairs": target_positions.size(), "collapsed": false}
	for target_position in target_positions:
		_launch_dark_mirror_pair(owner_node, target_position, cast_token)


func _launch_dark_mirror_pair(owner_node: Node2D, target_position: Vector2, cast_token := 0) -> void:
	if cast_token <= 0:
		_constellation_mirror_cast_token += 1
		cast_token = _constellation_mirror_cast_token
		_constellation_mirror_casts[cast_token] = {"pending_pairs": 1, "collapsed": false}
	var mirror_position: Vector2 = owner_node.global_position * 2.0 - target_position
	var damage_value := _rolled_damage(owner_node)
	_constellation_mirror_pair_token += 1
	var pair_token := _constellation_mirror_pair_token
	_constellation_mirror_pairs[pair_token] = {
		"resolved": 0,
		"positions": [],
		"base_damage": damage_value,
		"cast_token": cast_token,
	}
	var to_target := (target_position - owner_node.global_position).normalized()
	if to_target.length_squared() <= 0.001:
		to_target = Vector2.RIGHT
	_launch_dark_mirror_orb(owner_node.global_position + to_target * 28.0, target_position, damage_value, pair_token)
	_launch_dark_mirror_orb(owner_node.global_position - to_target * 28.0, mirror_position, damage_value * maxf(mirror_damage_ratio, 0.0), pair_token)


func _launch_dark_mirror_orb(start: Vector2, blast_position: Vector2, blast_damage: float, pair_token: int) -> void:
	if blast_damage <= 0.0:
		return
	var orb := _spawn_projectile_visual(start, blast_position - start)
	_register_effect(orb)
	var travel_time := clampf(start.distance_to(blast_position) / maxf(projectile_speed, 1.0), 0.08, 0.45)
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", blast_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	orb_tween.tween_callback(Callable(self, "_resolve_dark_mirror_blast").bind(orb.get_instance_id(), blast_position, blast_damage, pair_token))


func _resolve_dark_mirror_blast(orb_id: int, blast_position: Vector2, blast_damage: float, pair_token := 0) -> void:
	if _effects_shutdown:
		return
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	_release_effect(orb)
	AttackVfx.orb_burst(_projectile_parent(), blast_position, aoe_radius, _projectile_impact_color())
	var pair_probe = _constellation_mirror_pairs.get(pair_token, {})
	var cast_probe := int((pair_probe as Dictionary).get("cast_token", 0)) if pair_probe is Dictionary else 0
	_damage_dark_mirror_explosion(blast_position, aoe_radius, blast_damage, cast_probe, AOE_PROJECTILE_FULL_TARGETS, AOE_PROJECTILE_TARGET_DIMINISH)
	var pair_raw = _constellation_mirror_pairs.get(pair_token, {})
	if pair_raw is Dictionary and not (pair_raw as Dictionary).is_empty():
		var pair: Dictionary = pair_raw
		var positions_raw = pair.get("positions", [])
		var positions: Array = positions_raw if positions_raw is Array else []
		positions.append(blast_position)
		pair["positions"] = positions
		pair["resolved"] = int(pair.get("resolved", 0)) + 1
		if int(pair["resolved"]) >= 2 and positions.size() >= 2:
			var cast_token := int(pair.get("cast_token", 0))
			var cast_raw = _constellation_mirror_casts.get(cast_token, {})
			var cast_state: Dictionary = cast_raw if cast_raw is Dictionary else {}
			if not bool(cast_state.get("collapsed", false)):
				var midpoint := (Vector2(positions[0]) + Vector2(positions[1])) * 0.5
				var midpoint_target := TARGET_QUERY.nearest(self, midpoint, aoe_radius)
				var collapse := _constellation_event("mirror_midpoint", midpoint_target, 0.0)
				if bool(collapse.get("triggered", false)):
					var collapse_damage := float(pair.get("base_damage", blast_damage)) * _constellation_result_param(collapse, "collapse_damage_ratio", 0.42)
					_damage_dark_mirror_explosion(midpoint, aoe_radius, collapse_damage, cast_token, 1, 1.0)
					cast_state["collapsed"] = true
			cast_state["pending_pairs"] = maxi(int(cast_state.get("pending_pairs", 1)) - 1, 0)
			if int(cast_state["pending_pairs"]) <= 0:
				_constellation_mirror_casts.erase(cast_token)
			else:
				_constellation_mirror_casts[cast_token] = cast_state
			_constellation_mirror_pairs.erase(pair_token)
		else:
			_constellation_mirror_pairs[pair_token] = pair
	# SCRUM-961 «Зеркальная страница» (репозиционирована под новый кит): взрыв
	# отдаётся эхом на долю урона; эхо НЕ зеркалится и НЕ эхоится повторно.
	var echo_ratio := _owner_mod("book_mirror_echo")
	if echo_ratio > 0.0:
		var echo_tween := create_tween()
		echo_tween.tween_interval(0.22)
		echo_tween.tween_callback(Callable(self, "_resolve_dark_mirror_echo").bind(blast_position, blast_damage * clampf(echo_ratio, 0.0, 1.0)))


func _damage_dark_mirror_explosion(origin: Vector2, radius: float, amount: float, cast_token: int, full_targets: int, diminish: float) -> void:
	var cast_raw = _constellation_mirror_casts.get(cast_token, {})
	if not cast_raw is Dictionary or (cast_raw as Dictionary).is_empty():
		return
	var cast_state: Dictionary = cast_raw
	var hit_counts_raw = cast_state.get("hit_counts", {})
	var hit_counts: Dictionary = hit_counts_raw if hit_counts_raw is Dictionary else {}
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var enemy := enemies[index] as Node2D
		var enemy_id := enemy.get_instance_id()
		if int(hit_counts.get(enemy_id, 0)) >= 3:
			continue
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemy, amount * factor, index < full_targets)
		hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
	cast_state["hit_counts"] = hit_counts
	_constellation_mirror_casts[cast_token] = cast_state


func _resolve_dark_mirror_echo(blast_position: Vector2, echo_damage: float) -> void:
	if _effects_shutdown or echo_damage <= 0.0:
		return
	AttackVfx.orb_burst(_projectile_parent(), blast_position, aoe_radius * 0.8, Color(visual_color.r, visual_color.g, visual_color.b, visual_color.a * 0.7))
	_damage_aoe_projectile_explosion(blast_position, aoe_radius * 0.8, echo_damage)


func _fire_beam(owner_node: Node2D, direction: Vector2) -> void:
	# Веер из beam_count лучей с шагом beam_fan_degrees, центрированный на цели.
	# FAN-1893: луч — не снаряд; generic «+1 снаряд» веер лучей не расширяет.
	var count := maxi(beam_count, 1)
	_emit_weapon_animation_event(owner_node, "channel", 0.16, direction, {"beam_count": count})
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_beam(owner_node, direction.rotated(fan_offset))


func _fire_single_beam(owner_node: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 26.0
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	for hit in _enemies_in_corridor(start, direction, beam_width, attack_range):
		hits.append(hit)

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	# SCRUM-939: хук «Цепной палочки» (wand_chain_blasts) удалён — dark_wand
	# ушёл с beam на dark_chain_burst, артефакт репозиционирован (wand_extra_chain).
	# SCRUM-910: moon-сплит переехал из beam-хука в собственный режим
	# moon_split_shot (_fire_moon_split_shot) — beam снова универсален.
	for hit in hits:
		if hit_count >= hit_limit:
			break
		_damage_enemy(hit["node"], damage_value * pow(falloff, float(hit_count)))
		hit_count += 1


func _fire_drain_link(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", 0.20, direction, {"chain": true})
	var finish: Vector2 = owner_node.global_position + direction * min(attack_range, 520.0)
	if target != null:
		finish = target.global_position
	var start := owner_node.global_position + direction * 24.0
	var link_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(link_visual)
	if target == null:
		return

	var damage_value := _rolled_damage(owner_node)
	if dot_ticks > 0:
		_damage_enemy_with_dot(target, damage_value, owner_node)
	else:
		_damage_enemy(target, damage_value)
	var extra_links := int(_extra_projectiles())
	if extra_links <= 0:
		return
	var used := {target.get_instance_id(): true}
	var previous_position := target.global_position
	for link_index in range(extra_links):
		var next_target := _find_nearest_enemy_from(previous_position, aoe_radius, used)
		if next_target == null:
			break
		used[next_target.get_instance_id()] = true
		var width: float = beam_width * maxf(0.42, pow(damage_falloff, float(link_index + 1)) + 0.10)
		var tether := AttackVfx.beam(_projectile_parent(), previous_position, next_target.global_position, width, visual_color)
		_register_effect(tether)
		var chained_damage := damage_value * pow(damage_falloff, float(link_index + 1))
		if dot_ticks > 0:
			_damage_enemy_with_dot(next_target, chained_damage, owner_node)
		else:
			_damage_enemy(next_target, chained_damage)
		previous_position = next_target.global_position


func _constellation_transfer_skull_curse(dead_host: Node2D, payload: Dictionary) -> Dictionary:
	var key := _constellation_mark_key("skull_curse")
	var raw = dead_host.get_meta(key, {})
	if not raw is Dictionary or int((raw as Dictionary).get("depth", 1)) >= 1:
		return {"valid": true, "triggered": false}
	dead_host.remove_meta(key)
	var transfer := _constellation_event("kill", dead_host, 0.0, payload)
	if not bool(transfer.get("triggered", false)):
		return transfer
	var status_raw = (raw as Dictionary).get("status", {})
	if not status_raw is Dictionary:
		return transfer
	var status: Dictionary = (status_raw as Dictionary).duplicate(true)
	status["duration"] = maxf(float(status.get("duration", 0.0)) * _constellation_result_param(transfer, "transfer_duration_ratio", 0.55), 0.0)
	var excluded := {dead_host.get_instance_id(): true}
	var target_cap := maxi(int(_constellation_result_param(transfer, "transfer_targets", 3.0)), 0)
	for target_raw in TARGET_QUERY.nearest_many(self, dead_host.global_position, aoe_radius * 1.5, target_cap, excluded):
		var target := target_raw as Node2D
		if target == null or not is_instance_valid(target):
			continue
		StatusEffects.apply_status(target, "skull_curse", status)
		target.set_meta(key, {"status": status.duplicate(true), "depth": 1})
	return transfer
