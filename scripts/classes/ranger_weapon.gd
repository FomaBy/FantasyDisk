extends "res://scripts/classes/priest_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса ranger.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# SCRUM-913 «Охотничий капкан»: ПЕРМАНЕНТНЫЙ контрольный капкан.
const HUNTER_TRAP_ACTIVE_CAP := 6


func _exec_trap(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_trap(owner_node, direction)


func _exec_moon_split_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_moon_split_shot(owner_node, target, direction)


func _exec_storm_pierce_cone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_storm_pierce_cone(owner_node, direction)


# SCRUM-910 «Лунный арбалет»: одиночный физический болт в цель; после попадания
func _fire_moon_split_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", 0.16, direction, {"split_count": split_count})
	var primary := target
	if primary == null or not is_instance_valid(primary):
		primary = _find_closest_enemy(owner_node)
	var start := owner_node.global_position + direction * 26.0
	if primary == null:
		# Холостой болт: цели нет — рисуем трассер по направлению, урона нет.
		var miss_finish := owner_node.global_position + direction * attack_range
		var miss_visual := AttackVfx.projectile_trace(_projectile_parent(), start, miss_finish, visual_color, _projectile_visual_profile(), 0.14)
		_register_effect(miss_visual)
		return
	var bolt_visual := AttackVfx.beam(_projectile_parent(), start, primary.global_position, beam_width, visual_color)
	_register_effect(bolt_visual)
	_register_effect(AttackVfx.projectile_trace(_projectile_parent(), start, primary.global_position, visual_color, _projectile_visual_profile(), 0.12))
	var damage_value := _rolled_damage(owner_node)
	_damage_enemy(primary, damage_value)
	if charge_seconds > 0.0 and _current_charge_multiplier >= maxf(charge_max_multiplier - 0.01, 1.0):
		var moon_mark := _constellation_event("full_charge", primary, 0.0, {"constellation_consumer_event": true})
		if bool(moon_mark.get("triggered", false)) and is_instance_valid(primary):
			_arm_constellation_target_mark(primary, "moon", _constellation_result_param(moon_mark, "mark_seconds", 4.0), _constellation_result_param(moon_mark, "bonus_damage_cap", 0.28))
	var split_targets := maxi(split_count + int(_owner_mod("moon_split_targets")), 0)
	if split_targets <= 0 or not is_instance_valid(primary):
		return
	var excluded := {primary.get_instance_id(): true}
	for branch_raw in TARGET_QUERY.nearest_many(self, primary.global_position, maxf(aoe_radius, 120.0), split_targets, excluded):
		var branch_target := branch_raw as Node2D
		if branch_target == null or not is_instance_valid(branch_target):
			continue
		var branch := AttackVfx.beam(_projectile_parent(), primary.global_position, branch_target.global_position, beam_width * 0.55, Color(visual_color.r, visual_color.g, visual_color.b, 0.36))
		_register_effect(branch)
		_register_effect(AttackVfx.projectile_trace(_projectile_parent(), primary.global_position, branch_target.global_position, visual_color, _projectile_visual_profile(), 0.10))
		_damage_enemy(branch_target, damage_value)


# SCRUM-911 «Грозовой длинный лук»: дальнобойный КОНУС пробивающих стрел.
func _fire_storm_pierce_cone(owner_node: Node2D, direction: Vector2) -> void:
	var arrow_count := maxi(beam_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "channel", 0.18, direction, {"beam_count": arrow_count, "cone_degrees": cone_degrees})
	_spawn_storm_longbow_release_vfx(owner_node, direction)
	var damage_value := _rolled_damage(owner_node)
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var hit_ids := {}
	for arrow_index in range(arrow_count):
		var fan_offset := 0.0
		if arrow_count > 1:
			fan_offset = deg_to_rad(cone_degrees) * (float(arrow_index) / float(arrow_count - 1) - 0.5)
		var arrow_direction := direction.rotated(fan_offset)
		var start := owner_node.global_position + arrow_direction * 26.0
		var finish := owner_node.global_position + arrow_direction * attack_range
		var arrow_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
		_register_effect(arrow_visual)
		_register_effect(AttackVfx.projectile_trace(_projectile_parent(), start, finish, visual_color, _projectile_visual_profile(), 0.16))

		var hits := []
		for hit in _enemies_in_corridor(start, arrow_direction, beam_width, attack_range):
			hits.append(hit)
		hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["forward"]) < float(b["forward"])
		)
		var pierced := 0
		var outer_primary: Node2D = null
		for hit in hits:
			if pierced >= hit_limit:
				break
			var enemy_node := hit["node"] as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			if hit_ids.has(enemy_node.get_instance_id()):
				pierced += 1  # тело уже поражено другой стрелой — бюджет пирса съеден
				continue
			hit_ids[enemy_node.get_instance_id()] = true
			_damage_enemy(enemy_node, damage_value * pow(falloff, float(pierced)))
			if outer_primary == null and (arrow_index == 0 or arrow_index == arrow_count - 1):
				outer_primary = enemy_node
			pierced += 1
		if outer_primary != null:
			var branch_result := _constellation_event("outer_hit", outer_primary, 0.0)
			if bool(branch_result.get("triggered", false)):
				var branch_target := TARGET_QUERY.nearest(self, outer_primary.global_position, maxf(aoe_radius, 160.0), hit_ids)
				if branch_target != null:
					hit_ids[branch_target.get_instance_id()] = true
					var branch_ratio := maxf(float(branch_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
					_register_effect(AttackVfx.beam(_projectile_parent(), outer_primary.global_position, branch_target.global_position, maxf(beam_width * 0.55, 10.0), visual_color))
					_call_take_damage(branch_target, damage_value * branch_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "longbow_outer_storm_branch"})


# SCRUM-1037: Animator-owned release is an additive one-shot cue. It is
# registered through the same lifecycle path as the five gameplay corridors;
# damage, hit queries, pierce budget and cooldown remain entirely above.
func _spawn_storm_longbow_release_vfx(owner_node: Node2D, direction: Vector2) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or _effects_shutdown:
		return
	var release_vfx := STORM_LONGBOW_VOLLEY_VFX_SCENE.instantiate() as Node2D
	if release_vfx == null:
		return
	_projectile_parent().add_child(release_vfx)
	if release_vfx.has_method("configure"):
		release_vfx.call("configure", owner_node.global_position, direction, attack_range)
	_register_effect(release_vfx)


func _fire_trap(owner_node: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "deploy", 0.6, direction, {"check_interval": pool_tick_interval})
	# FAN-1893: дополнительные капканы одним броском (веером поперёк направления)
	# даёт только семантический мета-ключ trap_extra_count («Капканщик»);
	# generic extra_projectile здесь инертен (real_projectile_count 0), поэтому
	# _extra_projectiles() возвращает лишь семантическую добавку.
	var extra_traps := maxi(_extra_projectiles(), 0)
	var center := owner_node.global_position + direction * minf(attack_range, 180.0)
	var side := direction.orthogonal().normalized()
	for trap_index in range(1 + extra_traps):
		# 0, +70, -70, +140, ... — веер поперёк направления броска.
		var lateral := float((trap_index + 1) / 2) * 70.0 * (1.0 if trap_index % 2 == 1 else -1.0)
		if trap_index == 0:
			lateral = 0.0
		_deploy_hunter_trap(owner_node, center + side * lateral)


func _deploy_hunter_trap(owner_node: Node2D, trap_position: Vector2) -> void:
	var trap := Node2D.new()
	trap.name = "WeaponTrapNode"
	_register_effect(trap)
	trap.z_index = 5
	var trap_visual := Sprite2D.new()
	trap_visual.texture = _weapon_visual_texture()
	trap_visual.scale = Vector2(0.34, 0.34)
	trap.add_child(trap_visual)
	_projectile_parent().add_child(trap)
	trap.global_position = trap_position
	trap.set_meta("hunter_trap", true)
	# Снапшот заряда стойки: капкан, поставленный из полной стойки, хлопает
	# сильнее (identity «терпеливого охотника»); сам ролл — на момент триггера.
	trap.set_meta("charge_snapshot", _current_charge_multiplier)
	_retire_excess_hunter_traps(trap)

	var state := {"triggered": false}
	var check_interval := maxf(pool_tick_interval, 0.15)
	var instant_arm := false
	if owner_node.has_method("meta_trap_instant_arm"):
		instant_arm = bool(owner_node.call("meta_trap_instant_arm", _meta_context()))
	var check_callable := Callable(self, "_hunter_trap_check").bind(trap.get_instance_id(), owner_node.get_instance_id(), state)
	# Вечный цикл проверки: интервал → проверка; живёт, пока жив узел капкана.
	var trap_tween := trap.create_tween()
	trap_tween.set_loops()
	trap_tween.tween_interval(check_interval)
	trap_tween.tween_callback(check_callable)
	if instant_arm:
		check_callable.call_deferred()


# Периодическая проверка капкана (Callable без лямбды — SCRUM-551): первый враг
# в радиусе захлопывает капкан. Игрок и союзные сущности проверку не проходят
# (только группа enemies).
func _hunter_trap_check(trap_id: int, owner_id: int, state: Dictionary) -> void:
	var trap := instance_from_id(trap_id) as Node2D
	if trap == null or not is_instance_valid(trap) or bool(state.get("triggered", false)):
		return
	if not _has_enemy_in_circle(trap.global_position, aoe_radius):
		return
	state["triggered"] = true
	_trigger_hunter_trap(trap, instance_from_id(owner_id) as Node2D)


# Срабатывание: физический AoE-хлопок по всем врагам в радиусе + контроль
# (_apply_hunter_trap_control: паралич + кровотечение). Урон и статусы идут
# по ОДНОМУ набору целей — читаемая зона совпадает с фактической.
func _trigger_hunter_trap(trap: Node2D, owner_node: Node2D) -> void:
	var trap_damage := damage
	if owner_node != null and is_instance_valid(owner_node):
		trap_damage = _rolled_damage(owner_node)
	trap_damage *= maxf(float(trap.get_meta("charge_snapshot", 1.0)), 1.0)
	var center := trap.global_position
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	for enemy_raw in TARGET_QUERY.in_radius(self, center, aoe_radius):
		var enemy_node := enemy_raw as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		_damage_enemy(enemy_node, trap_damage)
		var prey_result := _constellation_event("trap_trigger", enemy_node, 0.0)
		if bool(prey_result.get("triggered", false)):
			var mechanic = owner_node.call("constellation_weapon_mechanic", weapon_id, "trap_prey_mark_distribution") if owner_node != null and owner_node.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (mechanic as Dictionary).get("params", {}) if mechanic is Dictionary else {}
			enemy_node.set_meta("constellation_prey_owner", owner_node.get_instance_id() if owner_node != null else 0)
			enemy_node.set_meta("constellation_prey_until", Time.get_ticks_msec() + int(maxf(float(params.get("prey_seconds", 4.0)), 0.0) * 1000.0))
			enemy_node.set_meta("constellation_prey_share", clampf(float(params.get("shared_damage_ratio", 0.22)), 0.0, 0.5))
			enemy_node.set_meta("constellation_prey_neighbors", maxi(int(params.get("neighbor_targets", 3)), 0))
		if is_instance_valid(enemy_node):
			_apply_hunter_trap_control(enemy_node, owner_node)
	_release_effect(trap)


# Контроль капкана (SCRUM-913):
func _apply_hunter_trap_control(enemy_node: Node2D, owner_node: Node2D) -> void:
	var paralyze_duration := (trap_paralyze_seconds + _owner_mod("trap_paralysis_bonus")) * _control_resist_factor(enemy_node)
	if paralyze_duration > 0.0:
		StatusEffects.apply_status(enemy_node, "hunter_trap_paralysis", {
			"duration": paralyze_duration,
			"movement_locked": true,
			"speed_multiplier": 0.0,
			"marker_color": Color(0.45, 0.90, 0.40, 1.0),
		})
	if dot_ticks <= 0:
		return
	var bleed_tick := 3.0
	if owner_node != null and is_instance_valid(owner_node):
		var parameters_raw = owner_node.get("derived_parameters")
		if parameters_raw is Dictionary:
			bleed_tick = maxf(float((parameters_raw as Dictionary).get("dot_damage", 3.0)), 1.0)
	var tick_interval := maxf(trap_bleed_tick_interval, 0.1)
	StatusEffects.apply_status_from(owner_node, enemy_node, "hunter_trap_bleed", {
		"duration": float(dot_ticks) * tick_interval,
		"dot_damage": bleed_tick,
		"dot_interval": tick_interval,
		"marker_color": Color(0.35, 0.85, 0.30, 1.0),
	})


# Кап живых капканов (перманентность без замусоривания поля): старейшие сверх
# капа тихо снимаются. Это КАП, а не таймер — одинокий капкан живёт вечно.
func _retire_excess_hunter_traps(new_trap: Node2D) -> void:
	var cap := maxi(HUNTER_TRAP_ACTIVE_CAP + int(_owner_mod("trap_cap_bonus")), 1)
	var alive_traps: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("hunter_trap") and effect != new_trap:
			alive_traps.append(effect as Node2D)
	while alive_traps.size() >= cap:
		var oldest := alive_traps.pop_front() as Node2D
		_release_effect(oldest)


# SCRUM-909 «Сторожевой лук» (CLASS_TRAITS.ranger, data-driven): каждый прямой
func _apply_ranger_bow_knockback(enemy: Node) -> void:
	if not bow_knockback_trait:
		return
	var enemy_node := enemy as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var owner_node := _owner_node()
	if owner_node == null or not owner_node.has_method("class_trait_value"):
		return
	var trait_scale := float(owner_node.call("class_trait_value", "bow_hit_knockback"))
	if trait_scale <= 0.0:
		return
	var away := enemy_node.global_position - owner_node.global_position
	if away.length_squared() <= 0.001:
		return
	_push_enemy_scaled(enemy_node, away.normalized(), trait_scale * _control_resist_factor(enemy_node))


func _apply_constellation_prey_distribution(enemy: Node, owner_node: Node, amount: float, hit_type: String) -> void:
	if enemy == null or owner_node == null or not enemy.has_meta("constellation_prey_owner"):
		return
	if int(enemy.get_meta("constellation_prey_owner", 0)) != owner_node.get_instance_id() or Time.get_ticks_msec() > int(enemy.get_meta("constellation_prey_until", 0)):
		return
	if str(owner_node.get("character_id")) != "ranger":
		return
	var ratio := clampf(float(enemy.get_meta("constellation_prey_share", 0.0)), 0.0, 0.5)
	var count := maxi(int(enemy.get_meta("constellation_prey_neighbors", 0)), 0)
	if ratio <= 0.0 or count <= 0 or not enemy is Node2D:
		return
	var candidates := []
	for neighbor_raw in TARGET_QUERY.in_radius(self, (enemy as Node2D).global_position, aoe_radius):
		var neighbor := neighbor_raw as Node2D
		if neighbor == null or neighbor == enemy:
			continue
		if int(neighbor.get_meta("constellation_prey_owner", 0)) != owner_node.get_instance_id() or Time.get_ticks_msec() > int(neighbor.get_meta("constellation_prey_until", 0)):
			continue
		candidates.append(neighbor)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return (enemy as Node2D).global_position.distance_squared_to(a.global_position) < (enemy as Node2D).global_position.distance_squared_to(b.global_position)
	)
	for neighbor_index in range(mini(candidates.size(), count)):
		_call_take_damage(candidates[neighbor_index] as Node, amount * ratio, {"damage_type": hit_type, "constellation_final": "trap_prey_mark_distribution"})


func _has_enemy_in_circle(origin: Vector2, radius: float) -> bool:
	return TARGET_QUERY.has_in_radius(self, origin, radius)
