extends "res://scripts/classes/druid_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса elementalist.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# === SCRUM-947..950: кит Элементалиста (редизайн поверх trait «Проводник стихий») ===
# Ниши: постоянный квадрат-ореол (кольцо) / редкий полнокартный X (призма) /
# сверхредкий нюк с догорающей зоной (метеор). Константы ниже — единственный
# источник истины по долям/геометрии; бюджетная модель (_budget_hit_model в
# progression_data.gd) зеркалит эти же числа в комментариях.

# SCRUM-948 «Кольцо Четырёх Стихий»: квадратная зона в точке каста.
const SQUARE_HALF_RATIO := 0.72          # половина стороны квадрата = aoe_radius * ratio


const SQUARE_DOT_TICK_SHARE := 0.70      # доля dot_damage владельца на тик ожога


const SQUARE_EARTH_CORE_PHYS_BONUS := 0.60  # артефакт «Четвертое кольцо»: +60% физ.доли


const SQUARE_EXTRA_TICK_CAP := 2         # кап доп. тиков от extra-рун («Монолит»)


const SQUARE_ELEMENT_COLORS := [
	Color(1.0, 0.42, 0.16, 0.85),  # огонь
	Color(0.26, 0.76, 1.0, 0.85),  # вода
	Color(0.64, 1.0, 0.28, 0.85),  # природа
	Color(0.72, 0.52, 0.24, 0.85), # земля — четвёртая стихия
]


# SCRUM-949 «Призматический Фокус»: полнокартный X-разлом.
# PRISM_FULL_MAP_REACH — документированный практический предел «во всю карту»:
# длина плеча луча от центра. Диагональ арены 4096×2304 ≈ 4700px, значит 4800px
# достигает любой точки арены из любого центра каста (тест держит этот инвариант).
const PRISM_FULL_MAP_REACH := 4800.0


const PRISM_BEAM_DAMAGE_SHARE := 0.72    # один луч-хит на врага за каст (без дублей)


const PRISM_CENTER_BONUS_SHARE := 0.55   # бонус-хит центра пересечения (стакается с лучом)


const PRISM_CROSS_EXTRA_SHARE := 0.60    # артефакт «Призматический крест»: доп. крест «+»


# SCRUM-950 «Ядро Метеора»: grenade_delay = ПОЛНАЯ задержка до удара.
const METEOR_TELEGRAPH_RATIO := 0.42     # доля задержки на чистый телеграф до падения


const METEOR_FALL_HEIGHT := 540.0        # высота, с которой метеор летит в зону


const METEOR_ZONE_RADIUS_RATIO := 0.78   # радиус догорающей зоны от aoe_radius


const METEOR_ZONE_FULL_TARGETS := 2      # полные тики зоны ближайшим к ядру


const METEOR_ZONE_TARGET_DIMINISH := 1.2 # спад по рангу удалённости в зоне


const METEOR_HEART_CENTER_BONUS := 0.55  # артефакт «Сердце метеора»: +55% центра


const METEOR_HEART_EXTRA_ZONE_TICKS := 2 # и догорание на 2 тика дольше


const ORBIT_FANOUT_FULL_TARGETS := 4


const ORBIT_FANOUT_TARGET_DIMINISH := 0.0


func _exec_elemental_orbit(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_elemental_orbit(owner_node, direction)


func _exec_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_prism_rift(owner_node, target, direction)


func _exec_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_meteor_shards(owner_node, target, direction)


# SCRUM-948: враги внутри КВАДРАТА (углы поражаются — вписанный круг их не берёт,
# за пределами стороны — нет). Сбор через окружающий радиус + осевой фильтр.
func _enemies_in_square(center: Vector2, half_size: float) -> Array:
	var result := []
	for enemy in TARGET_QUERY.in_radius(self, center, half_size * 1.4143):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var offset := enemy_node.global_position - center
		if absf(offset.x) <= half_size and absf(offset.y) <= half_size:
			result.append(enemy_node)
	return result


# SCRUM-948 «Кольцо Четырёх Стихий»: квадратная AoE четырёх стихий в точке каста
func _fire_elemental_orbit(owner_node: Node2D, direction: Vector2) -> void:
	# «Монолит»/extra-руны: дополнительные тики поля (кап SQUARE_EXTRA_TICK_CAP).
	var ticks := maxi(storm_ticks, 1) + clampi(_extra_projectiles(), 0, SQUARE_EXTRA_TICK_CAP)
	_emit_weapon_animation_event(owner_node, "channel", orbit_duration, direction, {"ticks": ticks})
	var center: Vector2 = owner_node.global_position
	var half_size: float = aoe_radius * SQUARE_HALF_RATIO
	var field_root := Node2D.new()
	field_root.name = "ElementalSquareField"
	field_root.z_index = 3
	_projectile_parent().add_child(field_root)
	_register_effect(field_root)
	field_root.global_position = center
	_draw_square_field(field_root, half_size)
	_elemental_square_tick(owner_node, center, half_size, ticks, 0)
	var tick_interval := maxf(orbit_duration / float(ticks), 0.08)
	var owner_id := owner_node.get_instance_id()
	var field_id := field_root.get_instance_id()
	var field_tween := create_tween()
	for tick_index in range(1, ticks):
		field_tween.tween_interval(tick_interval)
		field_tween.tween_callback(Callable(self, "_elemental_square_scheduled_tick").bind(owner_id, center, half_size, ticks, tick_index, direction))
	field_tween.tween_interval(tick_interval)
	field_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(field_id))


# FAN-2981: квадрат читается только текстурными рунами четырёх стихий по углам
# (под врагами, z_index поля 3). Линейная разметка граней удаллена — зона
# унифицирована по образцу меча: нарисованный спрайт, без Line2D-схем.
func _draw_square_field(field_root: Node2D, half_size: float) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner_index in range(4):
		var rune := Sprite2D.new()
		rune.name = "ElementRune%d" % corner_index
		rune.texture = _weapon_visual_texture()
		rune.modulate = SQUARE_ELEMENT_COLORS[corner_index % SQUARE_ELEMENT_COLORS.size()]
		rune.scale = Vector2.ONE * 0.16
		rune.position = (corners[corner_index] as Vector2) * half_size
		field_root.add_child(rune)


func _elemental_square_scheduled_tick(owner_id: int, center: Vector2, half_size: float, ticks: int, tick_index: int, direction: Vector2) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_emit_weapon_animation_event(current_owner, "pulse", 0.0, direction, {"index": tick_index, "count": ticks})
	_elemental_square_tick(current_owner, center, half_size, ticks, tick_index)


# Один тик квадрата: три канала + отброс от ЦЕНТРА КВАДРАТА (не от героя — зона
# автономна после каста). Элиты/боссы получают тот же apply_knockback-импульс,
# что и у прочих отбросов оружий (их устойчивость решает enemy-сторона).
func _elemental_square_tick(owner_node: Node2D, center: Vector2, half_size: float, ticks: int, phase_index := 0) -> void:
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_divisor := float(maxi(ticks, 1))
	var magic_tick := _rolled_damage(owner_node) / tick_divisor
	var physical_total := float(parameters.get("damage", 0.0)) * SQUARE_PHYSICAL_SHARE
	if _owner_mod("earth_orb_mode") > 0.0:
		# «Четвертое кольцо»: земляное ядро укрепляет физический канал квадрата.
		physical_total *= 1.0 + SQUARE_EARTH_CORE_PHYS_BONUS
	var physical_tick := physical_total / tick_divisor
	var dot_tick_damage := maxf(float(parameters.get("dot_damage", 2.0)) * SQUARE_DOT_TICK_SHARE, 0.5)
	var dot_interval := 1.0 / maxf(float(parameters.get("dot_speed", 1.0)), 0.2)
	var burn_ticks := maxi(dot_ticks, 1)
	var phase_target: Node2D = null
	# FAN-1031 3c(b2): крауд-кап тика квадрата. Ранг по дистанции к центру каста
	# берётся из отдельной карты — порядок итерации и phase_target (вход constellation
	# «hit») НЕ трогаем (zero-collateral). Сентинел (без orbit_*-override) → factor 1.0
	# всем → magic/phys/ожог побайтово прежние; оффендер (orb_ring) душит хвост толпы.
	var square_enemies := _enemies_in_square(center, half_size)
	var orbit_ranks := {}
	var orbit_ordered := _status_fanout_order(center, square_enemies)
	for order_rank in range(orbit_ordered.size()):
		orbit_ranks[(orbit_ordered[order_rank] as Node2D).get_instance_id()] = order_rank
	for enemy in square_enemies:
		var enemy_node := enemy as Node2D
		if phase_target == null:
			phase_target = enemy_node
		var orbit_factor := _orbit_fanout_factor(int(orbit_ranks.get(enemy_node.get_instance_id(), 0)))
		# FAN-1031 3c-final fix (peer review MAJOR): жёсткий кап ШИРИНЫ = SKIP, не ×0. Цель за
		# orbit_max_targets (factor==0) НЕ должна получать ни он-хит пайплайн `_damage_enemy`
		# (hit-фидбек / on_weapon_hit / constellation-хуки / он-хит статусы), ни refresh ожога
		# нулём (затирал живой four_elements_burn от предыдущего in-cap тика), ни пуш — как в
		# bio/pool/aoe-ветках (break/skip). Диминиш (factor>0) по-прежнему масштабирует урон.
		if orbit_factor <= 0.0:
			continue
		_damage_enemy(enemy_node, magic_tick * orbit_factor)
		if physical_tick > 0.0:
			_damage_enemy(enemy_node, physical_tick * orbit_factor, false, "physical", false)
		StatusEffects.apply_status(enemy_node, "four_elements_burn", {
			"duration": dot_interval * float(burn_ticks),
			"dot_damage": dot_tick_damage * orbit_factor,
			"dot_interval": dot_interval,
			"marker_color": Color(0.40, 0.82, 1.0, 1.0),
		})
		var away := enemy_node.global_position - center
		if away.length_squared() > 0.001:
			_push_enemy(enemy_node, away.normalized())
	if phase_target != null:
		var phase_name: String = ["fire", "water", "air", "earth"][phase_index % 4]
		var resonance := _constellation_event("hit", phase_target, 0.0, {"phase": phase_name, "constellation_consumer_event": true})
		if bool(resonance.get("triggered", false)):
			_damage_enemies_in_circle(center, half_size * 1.4143, _rolled_damage(owner_node) * _constellation_result_param(resonance, "resonance_damage_ratio", 0.48))
	# SCRUM-961 «Стихийный отдачник»: дополнительный радиальный пуш от кастера.
	_apply_elemental_repulse(owner_node, center, half_size * 1.4143)


# SCRUM-961 «Стихийный отдачник»: радиальный пуш от кастера по врагам в зоне.
func _apply_elemental_repulse(owner_node: Node2D, center: Vector2, radius: float) -> void:
	var repulse_power := _owner_mod("elemental_repulse_power")
	if repulse_power <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	for enemy in TARGET_QUERY.in_radius(self, center, radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var away := enemy_node.global_position - owner_node.global_position
		if away.length_squared() <= 0.001:
			continue
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(away.normalized() * repulse_power * 3.0)
		else:
			enemy_node.global_position += away.normalized() * repulse_power * 0.10


# SCRUM-949 «Призматический Фокус»: полнокартный X-разлом через точку фокуса
func _fire_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.12), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var axis_a := direction.rotated(PI / 4.0)
	if axis_a.length_squared() <= 0.001:
		axis_a = Vector2(1, -1)
	axis_a = axis_a.normalized()
	var axis_b := axis_a.rotated(PI / 2.0)
	var telegraph_ids: Array = []
	for axis in [axis_a, axis_b]:
		var axis_vector: Vector2 = axis
		var tele_beam := AttackVfx.beam(_projectile_parent(), center - axis_vector * PRISM_FULL_MAP_REACH, center + axis_vector * PRISM_FULL_MAP_REACH, maxf(beam_width * 0.35, 12.0), Color(visual_color.r, visual_color.g, visual_color.b, 0.20))
		_register_effect(tele_beam)
		telegraph_ids.append(tele_beam.get_instance_id())
	var telegraph_ring := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph_ring)
	telegraph_ids.append(telegraph_ring.get_instance_id())
	var rift_tween := create_tween()
	rift_tween.tween_interval(maxf(grenade_delay, 0.12))
	rift_tween.tween_callback(Callable(self, "_resolve_prism_rift").bind(owner_node.get_instance_id(), center, axis_a, axis_b, direction, telegraph_ids))


func _resolve_prism_rift(owner_id: int, center: Vector2, axis_a: Vector2, axis_b: Vector2, direction: Vector2, telegraph_ids: Array) -> void:
	for telegraph_id in telegraph_ids:
		_release_effect_by_id(int(telegraph_id))
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	var damage_value := damage
	if current_owner != null and is_instance_valid(current_owner):
		damage_value = _rolled_damage(current_owner)
	# Оси урона: главные диагонали X, при артефакте «Призматический крест» — ещё
	# крест «+» (горизонталь/вертикаль относительно атаки) со сниженной долей.
	var beam_axes := [[axis_a, PRISM_BEAM_DAMAGE_SHARE], [axis_b, PRISM_BEAM_DAMAGE_SHARE]]
	if _owner_mod("prism_cross_pierce") > 0.0:
		var cross_axis := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
		beam_axes.append([cross_axis, PRISM_BEAM_DAMAGE_SHARE * PRISM_CROSS_EXTRA_SHARE])
		beam_axes.append([cross_axis.rotated(PI / 2.0), PRISM_BEAM_DAMAGE_SHARE * PRISM_CROSS_EXTRA_SHARE])
	var color_cycle := [Color(0.26, 0.78, 1.0, 0.50), Color(1.0, 0.46, 0.20, 0.50), Color(0.76, 0.42, 1.0, 0.42), Color(0.64, 1.0, 0.28, 0.42)]
	var struck := {}
	for axis_index in range(beam_axes.size()):
		var axis_vector: Vector2 = beam_axes[axis_index][0]
		var axis_share: float = beam_axes[axis_index][1]
		var beam_start := center - axis_vector * PRISM_FULL_MAP_REACH
		var beam_end := center + axis_vector * PRISM_FULL_MAP_REACH
		var beam_visual := AttackVfx.beam(_projectile_parent(), beam_start, beam_end, beam_width, color_cycle[axis_index % color_cycle.size()])
		_register_effect(beam_visual)
		for enemy in TARGET_QUERY.in_segment(self, beam_start, beam_end, beam_width):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var enemy_key := enemy_node.get_instance_id()
			if struck.has(enemy_key):
				continue
			struck[enemy_key] = true
			_damage_enemy(enemy_node, damage_value * axis_share)
	for enemy in TARGET_QUERY.in_radius(self, center, aoe_radius):
		_damage_enemy(enemy as Node2D, damage_value * PRISM_CENTER_BONUS_SHARE)
	var rift_result := _constellation_event("intersection", null, damage_value)
	if bool(rift_result.get("triggered", false)):
		var tick_ratio := _constellation_result_param(rift_result, "tick_damage_ratio", 0.18)
		var rift_seconds := _constellation_result_param(rift_result, "rift_seconds", 1.2)
		var boss_pin_factor := _constellation_result_param(rift_result, "boss_pin_factor", 0.0)
		for rift_target_raw in TARGET_QUERY.in_radius(self, center, aoe_radius * 0.72):
			var rift_target := rift_target_raw as Node2D
			var pin_duration := rift_seconds * (boss_pin_factor if TARGET_QUERY.is_epic_displacement_immune(rift_target) else 1.0)
			if pin_duration > 0.0:
				StatusEffects.apply_status(rift_target, "constellation_prism_pin", {"duration": pin_duration, "movement_locked": true})
		var rift_tween := create_tween()
		for tick_index in range(3):
			rift_tween.tween_interval(0.4)
			rift_tween.tween_callback(Callable(self, "_constellation_prism_rift_tick").bind(center, damage_value * tick_ratio))
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, visual_color)
	# SCRUM-961 «Стихийный отдачник»: центр разлома толкает монстров от кастера.
	if current_owner != null and is_instance_valid(current_owner):
		_apply_elemental_repulse(current_owner, center, aoe_radius)


func _constellation_prism_rift_tick(center: Vector2, tick_damage: float) -> void:
	if _effects_shutdown or tick_damage <= 0.0:
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius * 0.72, visual_color, false)
	for enemy_raw in TARGET_QUERY.in_radius(self, center, aoe_radius * 0.72):
		_call_take_damage(enemy_raw as Node2D, tick_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "prism_intersection_rift"})


# SCRUM-950 «Ядро Метеора»: самое медленное оружие игрока. grenade_delay — полная
func _fire_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var total_delay := maxf(grenade_delay, 0.30)
	_emit_weapon_animation_event(owner_node, "windup", total_delay, direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 430.0)
	if target != null:
		center = target.global_position
	var telegraph_holder := Node2D.new()
	telegraph_holder.name = "MeteorTelegraph"
	_projectile_parent().add_child(telegraph_holder)
	telegraph_holder.global_position = center
	_register_effect(telegraph_holder)
	HazardVfx.telegraph(telegraph_holder, aoe_radius, Color(1.0, 0.45, 0.15, 1.0), total_delay)
	var meteor_start := center + Vector2(200.0, -METEOR_FALL_HEIGHT)
	var meteor := _spawn_projectile_visual(meteor_start, center - meteor_start)
	_register_effect(meteor)
	var fall_time := maxf(total_delay * (1.0 - METEOR_TELEGRAPH_RATIO), 0.15)
	var meteor_tween := create_tween()
	meteor_tween.tween_interval(total_delay - fall_time)
	meteor_tween.tween_property(meteor, "global_position", center, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	meteor_tween.tween_callback(Callable(self, "_resolve_meteor_impact").bind(owner_node.get_instance_id(), center, direction, meteor.get_instance_id(), telegraph_holder.get_instance_id()))


func _resolve_meteor_impact(owner_id: int, center: Vector2, direction: Vector2, meteor_id: int, telegraph_id: int) -> void:
	_release_effect_by_id(meteor_id)
	_release_effect_by_id(telegraph_id)
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var owner_alive := current_owner != null and is_instance_valid(current_owner)
	if owner_alive:
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	var damage_value := damage
	if owner_alive:
		damage_value = _rolled_damage(current_owner)
	var heart_mode := _owner_mod("meteor_heart_mode") > 0.0
	# «Сердце метеора»: реже (интервал ×1.45 в _fire_interval_artifact_factor),
	# но центральный удар жирнее и зона догорает дольше.
	var center_multiplier := 1.0 + (METEOR_HEART_CENTER_BONUS if heart_mode else 0.0)
	_damage_enemies_in_circle_falloff(center, aoe_radius, damage_value * center_multiplier, 0.55)
	var recall_result := _constellation_event("return", null, damage_value)
	if bool(recall_result.get("triggered", false)):
		var recall_ratio := maxf(float(recall_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
		var recall_tween := create_tween()
		recall_tween.tween_interval(0.20)
		recall_tween.tween_callback(Callable(self, "_constellation_meteor_recall").bind(center, damage_value * recall_ratio))
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, _projectile_impact_color())
	if owner_alive:
		# SCRUM-961 «Стихийный отдачник»: удар метеора толкает монстров от кастера.
		_apply_elemental_repulse(current_owner, center, aoe_radius)
	var zone_ticks := maxi(dot_ticks, 1) + (METEOR_HEART_EXTRA_ZONE_TICKS if heart_mode else 0)
	var tick_interval := maxf(pool_tick_interval, 0.18)
	var zone_radius := aoe_radius * METEOR_ZONE_RADIUS_RATIO
	var zone_tween := create_tween()
	for tick_index in range(zone_ticks):
		zone_tween.tween_interval(tick_interval)
		zone_tween.tween_callback(Callable(self, "_meteor_zone_tick").bind(owner_id, center, zone_radius))


# Тик догорающей зоны метеора: периодический канал (тип "dot", ось знания),
# полные тики — ближайшим к ядру, дальше спад по рангу (анти-раздувание толпой).
func _meteor_zone_tick(owner_id: int, center: Vector2, zone_radius: float) -> void:
	if _effects_shutdown:
		return
	var tick_damage := 2.0
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		var parameters_raw = current_owner.get("derived_parameters")
		if parameters_raw is Dictionary:
			tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	AttackVfx.ring_pulse(_projectile_parent(), center, zone_radius, Color(1.0, 0.45, 0.15, 0.22), false)
	var enemies: Array = TARGET_QUERY.in_radius(self, center, zone_radius)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var factor := 1.0
		if index >= METEOR_ZONE_FULL_TARGETS:
			factor = 1.0 / (1.0 + float(index - METEOR_ZONE_FULL_TARGETS + 1) * METEOR_ZONE_TARGET_DIMINISH)
		_damage_enemy(enemies[index] as Node2D, tick_damage * factor, false, "dot", false)


func _constellation_meteor_recall(center: Vector2, shard_damage: float) -> void:
	if _effects_shutdown or shard_damage <= 0.0:
		return
	var hit_counts := {}
	for shard_index in range(6):
		var outer := center + Vector2.RIGHT.rotated(TAU * float(shard_index) / 6.0) * aoe_radius
		_register_effect(AttackVfx.beam(_projectile_parent(), outer, center, maxf(beam_width * 0.4, 12.0), visual_color))
		for enemy_raw in TARGET_QUERY.in_segment(self, outer, center, maxf(beam_width, 30.0)):
			var enemy := enemy_raw as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var enemy_id := enemy.get_instance_id()
			if int(hit_counts.get(enemy_id, 0)) >= 2:
				continue
			hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
			_call_take_damage(enemy, shard_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "meteor_shard_recall"})


func _orbit_fanout_factor(rank: int) -> float:
	return WEAPON_CROWD_CAPS.fanout_factor(rank, orbit_full_targets, orbit_target_diminish, orbit_max_targets, ORBIT_FANOUT_FULL_TARGETS, ORBIT_FANOUT_TARGET_DIMINISH)
