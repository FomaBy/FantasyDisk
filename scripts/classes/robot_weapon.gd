extends "res://scripts/classes/ranger_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса robot.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_robot_magnetic_anchor(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_robot_magnetic_anchor(owner_node, target, direction)


func _exec_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_robot_compression_line(owner_node, target, direction)


func _exec_robot_reactor_vent(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_robot_reactor_vent(owner_node, direction)


func _damage_enemies_in_corridor(origin: Vector2, direction: Vector2, amount: float, width_override := -1.0) -> void:
	# SCRUM-916: width_override позволяет бить ПОЛНУЮ ширину коридора компрессии
	# (suppression_width Пресса), не только центральный beam_width.
	var corridor_hit_width := width_override if width_override > 0.0 else beam_width
	for hit in _enemies_in_corridor(origin, direction, corridor_hit_width, attack_range):
		_damage_enemy(hit["node"], amount)


func _fire_robot_magnetic_anchor(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-915: редкий ТЯЖЁЛЫЙ AoE-пулл. Центр = точка якоря (цель/направление),
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph)
	var tether := AttackVfx.beam(_projectile_parent(), owner_node.global_position + direction * 24.0, center, beam_width, Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	_register_effect(tether)
	var owner_id := owner_node.get_instance_id()
	var stored_center := center
	# SCRUM-1034: удар отложен на grenade_delay. Раньше колбэк был лямбдой с
	# ПРЯМЫМ захватом Node-ов telegraph/tether; эти VFX само-освобождаются раньше
	# удара, и Godot писал engine-ERROR «Lambda capture at index N was freed».
	# Канон SCRUM-551: Callable+bind по instance id, VFX/владелец — через id.
	var telegraph_id := telegraph.get_instance_id()
	var tether_id := tether.get_instance_id()
	var anchor_tween := create_tween()
	anchor_tween.tween_interval(maxf(grenade_delay, 0.08))
	anchor_tween.tween_callback(Callable(self, "_resolve_robot_anchor").bind(owner_id, stored_center, telegraph_id, tether_id))


func _resolve_robot_anchor(owner_id: int, center: Vector2, telegraph_id: int, tether_id: int) -> void:
	# Отложенный удар Магнитного Якоря. Твин принадлежит оружию (умирает вместе с
	# ним); владелец и VFX перепроверяются по instance id, поэтому освобождённый
	# телеграф/тезер даёт null без engine-ERROR (SCRUM-1034/551).
	if _effects_shutdown:
		_release_effect_by_id(telegraph_id)
		_release_effect_by_id(tether_id)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var damage_value: float = _rolled_damage(current_owner) if (current_owner != null and is_instance_valid(current_owner)) else damage
	# Контракт SCRUM-915 не меняется: полный ролл с falloff от ЦЕНТРА якоря + пулл.
	_damage_enemies_in_circle_falloff(center, aoe_radius, damage_value, damage_falloff)
	_pull_enemies_toward(center, aoe_radius, knockback)
	for enemy_raw in TARGET_QUERY.in_radius(self, center, aoe_radius):
		var enemy := enemy_raw as Node2D
		if enemy == null or TARGET_QUERY.is_epic_displacement_immune(enemy):
			continue
		var setup := _constellation_event("hit", enemy, 0.0, {"constellation_consumer_event": true})
		if bool(setup.get("triggered", false)):
			_arm_constellation_target_mark(enemy, "anchor", _constellation_result_param(setup, "mark_seconds", 2.0), _constellation_result_param(setup, "bonus_damage_cap", 0.25))
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius * 0.62, visual_color)
	_release_effect_by_id(telegraph_id)
	_release_effect_by_id(tether_id)


func _fire_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-916: широкий коридор компрессии. Урон наносится по ВСЕЙ ширине
	var center: Vector2 = owner_node.global_position + direction * min(attack_range * 0.58, 260.0)
	if target != null:
		var to_target := target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			center = owner_node.global_position + to_target.normalized() * minf(to_target.length(), attack_range * 0.58)
	var start := owner_node.global_position + direction * 28.0
	var finish := owner_node.global_position + direction * attack_range
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	# SCRUM-961 «Калибратор пресса»: коридор компрессии шире (+30%), урон не растёт.
	var corridor_width := suppression_width
	if _owner_mod("press_corridor_bonus") > 0.0:
		corridor_width *= 1.30
	var left_start := start + perpendicular * corridor_width * 0.5
	var left_finish := finish + perpendicular * corridor_width * 0.5
	var right_start := start - perpendicular * corridor_width * 0.5
	var right_finish := finish - perpendicular * corridor_width * 0.5
	var left := AttackVfx.beam(_projectile_parent(), left_start, left_finish, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	var right := AttackVfx.beam(_projectile_parent(), right_start, right_finish, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	_register_effect(left)
	_register_effect(right)
	var owner_id := owner_node.get_instance_id()
	var line_start := start
	var line_finish := finish
	var line_direction := direction
	var line_perpendicular := perpendicular
	var clamp_center := center
	# SCRUM-1034: как и якорь — раньше колбэк был лямбдой с прямым захватом боковых
	# телеграфов left/right, которые само-освобождаются до удара (engine-ERROR
	# «Lambda capture was freed»). Канон SCRUM-551: Callable+bind по instance id.
	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()
	var press_tween := create_tween()
	press_tween.tween_interval(maxf(grenade_delay, 0.08))
	press_tween.tween_callback(Callable(self, "_resolve_robot_press").bind(owner_id, line_start, line_finish, line_direction, line_perpendicular, clamp_center, corridor_width, left_id, right_id))


func _resolve_robot_press(owner_id: int, line_start: Vector2, line_finish: Vector2, line_direction: Vector2, line_perpendicular: Vector2, clamp_center: Vector2, corridor_width: float, left_id: int, right_id: int) -> void:
	# Отложенная компрессия Гидравлического Пресса. Твин принадлежит оружию;
	# владелец и боковые VFX перепроверяются по instance id (SCRUM-1034/551).
	if _effects_shutdown:
		_release_effect_by_id(left_id)
		_release_effect_by_id(right_id)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var damage_value: float = _rolled_damage(current_owner) if (current_owner != null and is_instance_valid(current_owner)) else damage
	var impact := AttackVfx.beam(_projectile_parent(), line_start, line_finish, beam_width, visual_color)
	_register_effect(impact)
	# SCRUM-916: урон по полной ширине коридора, затем компрессия к оси (контракт не меняется).
	_damage_enemies_in_corridor(line_start, line_direction, damage_value, corridor_width)
	_compress_enemies_to_axis(line_start, line_direction, line_perpendicular, corridor_width, attack_range, knockback)
	AttackVfx.ring_pulse(_projectile_parent(), clamp_center, aoe_radius * 0.42, visual_color, false)
	_release_effect_by_id(left_id)
	_release_effect_by_id(right_id)


func _fire_robot_reactor_vent(owner_node: Node2D, _direction: Vector2) -> void:
	# SCRUM-918: Реакторное Ядро — вращающийся четырёхнаправленный веер.
	var damage_value := _rolled_damage(owner_node) * REACTOR_VENT_DAMAGE_RATIO
	var cycle_resolution := _constellation_event("cast", null, damage_value)
	if bool(cycle_resolution.get("triggered", false)):
		var pulse_ratio := _constellation_result_param(cycle_resolution, "pulse_damage_ratio", 0.40)
		var pulse_knockback := _constellation_result_param(cycle_resolution, "pulse_knockback", 110.0)
		for pulse_target in TARGET_QUERY.in_radius(self, owner_node.global_position, aoe_radius):
			var pulse_enemy := pulse_target as Node2D
			if pulse_enemy == null or not is_instance_valid(pulse_enemy):
				continue
			_call_take_damage(pulse_enemy, damage_value * pulse_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "reactor_vent_cycle_pulse"})
			var away := pulse_enemy.global_position - owner_node.global_position
			_push_enemy_scaled(pulse_enemy, away.normalized() if away.length_squared() > 0.001 else Vector2.RIGHT, pulse_knockback / maxf(knockback, 1.0))
	# FAN-1893: ширина лопасти — не число снарядов; generic «+1 снаряд» вентили
	# не расширяет (перегруженная width-интерпретация удалена), направлений
	# всегда ровно REACTOR_VENT_COUNT.
	var vent_width := beam_width
	var base_phase := _reactor_vent_phase
	_reactor_vent_phase = fmod(_reactor_vent_phase + deg_to_rad(REACTOR_ROTATION_STEP_DEG), TAU)
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, aoe_radius * 0.62, visual_color, true)
	# SCRUM-961 «Реакторный хронометр»: вентили этого каста идут последовательной
	# волной внутри интервала (без мёртвых пауз); канонический шаг паттерна
	# остаётся +6°/атака — артефакт меняет только развёртку внутри каста.
	if _owner_mod("reactor_smooth_rotation") > 0.0:
		var step := maxf(fire_interval, 0.2) * 0.85 / float(REACTOR_VENT_COUNT)
		var owner_id := owner_node.get_instance_id()
		var rotation_tween := create_tween()
		for vent_index in range(REACTOR_VENT_COUNT):
			var vent_direction := Vector2.RIGHT.rotated(base_phase + TAU * float(vent_index) / float(REACTOR_VENT_COUNT))
			if vent_index > 0:
				rotation_tween.tween_interval(step)
			# SCRUM-551: Callable+bind вместо лямбды с захватом узлов.
			rotation_tween.tween_callback(Callable(self, "_fire_reactor_vent_step").bind(owner_id, vent_direction, damage_value, vent_width))
		return
	for vent_index in range(REACTOR_VENT_COUNT):
		var vent_direction := Vector2.RIGHT.rotated(base_phase + TAU * float(vent_index) / float(REACTOR_VENT_COUNT))
		_fire_reactor_single_vent(owner_node, vent_direction, damage_value, vent_width)


func _fire_reactor_vent_step(owner_id: int, vent_direction: Vector2, damage_value: float, vent_width: float) -> void:
	# Отложенный вентиль «Реакторного хронометра». Твин принадлежит оружию
	# (умирает вместе с ним), владелец перепроверяется по instance id (SCRUM-551).
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_fire_reactor_single_vent(current_owner, vent_direction, damage_value, vent_width)


func _fire_reactor_single_vent(owner_node: Node2D, vent_direction: Vector2, damage_value: float, vent_width := -1.0) -> void:
	var effective_width := vent_width if vent_width > 0.0 else beam_width
	var start := owner_node.global_position + vent_direction * 22.0
	var finish := owner_node.global_position + vent_direction * attack_range
	var beam := AttackVfx.beam(_projectile_parent(), start, finish, effective_width, visual_color)
	_register_effect(beam)
	_damage_enemies_in_segment(start, finish, effective_width, damage_value)
	for enemy in _enemies_in_corridor(start, vent_direction, effective_width, attack_range):
		var enemy_node := enemy["node"] as Node2D
		if enemy_node == null:
			continue
		_push_enemy(enemy_node, vent_direction)


func _pull_enemies_toward(center: Vector2, radius: float, force: float) -> void:
	# SCRUM-915: тяжёлый пулл Магнитного Якоря. Рядовые враги стягиваются К
	var anchor_bonus := _owner_mod("anchor_pull_power") if attack_mode == "robot_magnetic_anchor" else 0.0
	var convergence := clampf(
		ANCHOR_PULL_CONVERGENCE * (force / ANCHOR_PULL_FORCE_NORM) * (1.0 + maxf(anchor_bonus, 0.0)),
		0.10, ANCHOR_PULL_CONVERGENCE_CAP)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_non_elite_target(enemy_node):
			continue
		var to_center := center - enemy_node.global_position
		var distance := to_center.length()
		if distance <= 0.001 or distance > radius:
			continue
		var travel := distance * convergence
		if enemy_node.has_method("apply_knockback"):
			var impulse := minf(sqrt(KNOCKBACK_IMPULSE_TRAVEL_FACTOR * travel), ANCHOR_PULL_IMPULSE_CAP)
			enemy_node.apply_knockback(to_center.normalized() * impulse)
		else:
			enemy_node.global_position += to_center.normalized() * travel


# SCRUM-961: рядовой враг (не элитка/босс) — для эффектов, которые по контракту
# «элитки/боссы прямо исключены» (ядро якоря и т.п.).
func _is_non_elite_target(enemy_node: Node2D) -> bool:
	if enemy_node.is_in_group("elite_enemies") or enemy_node.is_in_group("bosses"):
		return false
	if enemy_node.has_meta("elite_behavior") or enemy_node.has_meta("boss_id"):
		return false
	return true


func _compress_enemies_to_axis(origin: Vector2, direction: Vector2, perpendicular: Vector2, width: float, range_limit: float, force: float) -> void:
	# SCRUM-916: компрессия Гидравлического Пресса. Врагов в коридоре прижимает
	var force_scale := clampf(force / PRESS_COMPRESSION_FORCE_NORM, 0.25, 1.6)
	var convergence := clampf(PRESS_COMPRESSION_CONVERGENCE * force_scale, 0.10, 0.95)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - origin
		var forward := to_enemy.dot(direction)
		if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > range_limit:
			continue
		var side := to_enemy.dot(perpendicular)
		if absf(side) > width * 0.5 or absf(side) <= 0.001:
			continue
		var resist := 1.0 if _is_non_elite_target(enemy_node) else PRESS_ELITE_BOSS_COMPRESSION_FACTOR
		var travel := absf(side) * convergence * resist
		if travel <= 0.001:
			continue
		var push_direction := (-perpendicular if side > 0.0 else perpendicular).normalized()
		if push_direction.length_squared() <= 0.001:
			continue
		if enemy_node.has_method("apply_knockback"):
			var impulse := minf(sqrt(KNOCKBACK_IMPULSE_TRAVEL_FACTOR * travel), PRESS_COMPRESSION_IMPULSE_CAP)
			enemy_node.apply_knockback(push_direction * impulse)
		else:
			enemy_node.global_position += push_direction * travel


func _damage_enemies_in_segment(start: Vector2, finish: Vector2, width: float, amount: float) -> void:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.001:
		_damage_enemies_in_circle(start, width * 0.5, amount)
		return
	for enemy_node in TARGET_QUERY.in_segment(self, start, finish, width, _line_back_allowance(start)):
		_damage_enemy(enemy_node, amount)
