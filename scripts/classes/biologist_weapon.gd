extends "res://scripts/classes/assassin_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса biologist.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_bio_spore_bloom(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_spore_bloom(owner_node, target, direction)


func _exec_bio_sample_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_sample_dart(owner_node, target, direction)


func _exec_bio_symbiote_web(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_symbiote_web(owner_node, target, direction)


# SCRUM-896: Споровая Линза — ЛОКАЛЬНЫЙ AoE у персонажа. Стартовый attack_range
# резко срезан данными (через экран не стреляет), «нравящийся» радиус колец
# сохранён. Три расширяющихся кольца бьют с falloff; КАЖДЫЙ задетый кольцом враг
# получает замедление (_apply_bio_spore_slow, AC SCRUM-896) и биоинфекцию
# (_apply_bio_infection — топливо trait'а «Разбор образцов», SCRUM-1005).
func _fire_bio_spore_bloom(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.08) * float(maxi(storm_ticks - 1, 1)), direction, {"count": maxi(storm_ticks, 1)})
	var center: Vector2 = owner_node.global_position + direction * minf(attack_range, 420.0)
	var target_id := 0
	if target != null:
		center = target.global_position
		target_id = target.get_instance_id()
	var damage_value: float = _rolled_damage(owner_node)
	# SCRUM-961 «Расщепленный анализ»: первый задетый враг делится спорами с соседями.
	_apply_bio_split_analysis(TARGET_QUERY.nearest(self, center, aoe_radius), damage_value)
	var pulse_count: int = maxi(storm_ticks, 1)
	for pulse_index in range(pulse_count):
		var bloom_tween := create_tween()
		bloom_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.08))
		# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
		bloom_tween.tween_callback(Callable(self, "_bio_spore_pulse").bind(owner_node.get_instance_id(), target_id, center, direction, pulse_index, pulse_count, damage_value))


# Одно кольцо линзы: урон с диминишингом по дистанции, затем замедление и
# инфекция ВСЕХ задетых (порядок «урон → статусы»: бонус trait'а по заражённым
# окупается со следующего кольца/каста, не в момент заражения).
func _bio_spore_pulse(owner_id: int, target_id: int, stored_center: Vector2, direction: Vector2, pulse_index: int, pulse_count: int, damage_value: float) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_emit_weapon_animation_event(current_owner, "pulse", maxf(burst_interval, 0.08), direction, {"index": pulse_index, "count": pulse_count})
	var impact_center := stored_center
	var current_target := instance_from_id(target_id) as Node2D
	if current_target != null and is_instance_valid(current_target):
		impact_center = current_target.global_position
	var radius: float = aoe_radius * (0.44 + 0.24 * float(pulse_index + 1))
	var factor: float = pow(damage_falloff, float(pulse_index))
	AttackVfx.ring_pulse(_projectile_parent(), impact_center, radius, visual_color, pulse_index == 0)
	_damage_enemies_in_circle_falloff(impact_center, radius, damage_value * factor, damage_falloff)
	_apply_bio_spore_slow(current_owner, impact_center, radius)
	var ring_targets := TARGET_QUERY.in_radius(self, impact_center, radius)
	# FAN-1031 3c(b): крауд-инфекция — ближние status_full_targets получают полный
	# DoT, дальний хвост толпы диминишится (порядок ring_targets для constellation
	# ниже НЕ трогаем — ранжируем в дубликате).
	var infect_order := _status_fanout_order(impact_center, ring_targets)
	for rank in range(infect_order.size()):
		var infect_factor := _status_fanout_factor(rank)
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ — за status_max_targets factor==0 → дальний
		# хвост толпы вообще не заражается (order отсортирован по дистанции → break). Без
		# override factor>0 всегда → цикл не прерывается (нулевое изменение поведения).
		if infect_factor <= 0.0:
			break
		_apply_bio_infection(infect_order[rank] as Node2D, current_owner, infect_factor)
	if pulse_index == pulse_count - 1 and not ring_targets.is_empty():
		var bloom_result := _constellation_event("final_ring", ring_targets[0] as Node2D, 0.0)
		if bool(bloom_result.get("triggered", false)):
			var bloom_cap := maxi(int(_constellation_result_param(bloom_result, "secondary_blooms", 4.0)), 0)
			var bloom_ratio := _constellation_result_param(bloom_result, "bloom_damage_ratio", 0.30)
			for bloom_index in range(mini(ring_targets.size(), bloom_cap)):
				var bloom_target := ring_targets[bloom_index] as Node2D
				AttackVfx.orb_burst(_projectile_parent(), bloom_target.global_position, maxf(aoe_radius * 0.18, 24.0), visual_color)
				_call_take_damage(bloom_target, damage_value * factor * bloom_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "spore_final_ring_blooms"})


# SCRUM-896: Инъектор Образцов — длинный пирсинг-луч Биолога. Урон получают ВСЕ
func _fire_bio_sample_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var beam_direction := direction
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			beam_direction = to_target.normalized()
	if beam_direction.length_squared() <= 0.001:
		beam_direction = Vector2.RIGHT
	var start: Vector2 = owner_node.global_position + beam_direction * 26.0
	var beam_length: float = maxf(attack_range - 26.0, 60.0)
	var tip_center: Vector2 = start + beam_direction * beam_length
	if target != null and is_instance_valid(target):
		tip_center = target.global_position
	var tracer := AttackVfx.beam(_projectile_parent(), start, start + beam_direction * beam_length, beam_width, visual_color)
	_register_effect(tracer)
	_register_effect(AttackVfx.projectile_trace(_projectile_parent(), start, tip_center, visual_color, _projectile_visual_profile(), 0.14))
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.08), direction, {"count": 1})
	var damage_value: float = _rolled_damage(owner_node)
	var chain_artifact := _owner_mod("sample_beam_full_damage") > 0.0
	var line_multiplier := 1.3 if chain_artifact else 1.0
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var physical_bonus := maxf(float(parameters.get("damage", 0.0)), 0.0) * INJECTOR_PHYSICAL_SHARE * line_multiplier
	var injected: Node2D = null
	var injected_forward := INF
	for hit in _enemies_in_corridor(start, beam_direction, beam_width, beam_length):
		var line_enemy := hit["node"] as Node2D
		if line_enemy == null or not is_instance_valid(line_enemy):
			continue
		var sample_multiplier := 1.0
		if not _constellation_profile("injector_sample_analysis_ramp").is_empty():
			var sample_event := _constellation_event("hit", line_enemy, 0.0, {"constellation_consumer_event": true})
			var sample_stacks := _advance_constellation_target_stack(line_enemy, "sample", 4, _constellation_result_param(sample_event, "duration_seconds", 5.0))
			var sample_bonus := 0.08 * float(sample_stacks)
			if TARGET_QUERY.is_epic_displacement_immune(line_enemy):
				sample_bonus = minf(sample_bonus, 0.28)
			sample_multiplier += sample_bonus
		_damage_enemy(line_enemy, damage_value * line_multiplier * sample_multiplier)
		if physical_bonus > 0.0:
			_damage_enemy(line_enemy, physical_bonus, false, "physical", false)
		var forward := float(hit.get("forward", INF))
		if forward < injected_forward:
			injected_forward = forward
			injected = line_enemy
	var tip_radius := aoe_radius * (1.25 if chain_artifact else 1.0)
	AttackVfx.orb_burst(_projectile_parent(), tip_center, tip_radius * 0.42, _projectile_impact_color())
	_damage_enemies_in_circle_falloff(tip_center, tip_radius, damage_value * tip_burst_ratio, damage_falloff)
	if injected != null:
		_apply_bio_infection(injected, owner_node)
		# SCRUM-961 «Расщепленный анализ»: взятый образец делится с соседями.
		_apply_bio_split_analysis(injected, damage_value)


# SCRUM-896: Семя Симбионта — самое дальнобойное оружие кита с ТЕМПОРАЛЬНОЙ
func _fire_bio_symbiote_web(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var germination_center: Vector2 = owner_node.global_position + direction * minf(attack_range, 720.0)
	if target != null and is_instance_valid(target):
		germination_center = target.global_position
	_emit_weapon_animation_event(owner_node, "channel", maxf(grenade_delay, 0.16), direction, {"seed": true})
	var seed_flight := AttackVfx.beam(_projectile_parent(), owner_node.global_position + direction * 24.0, germination_center, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
	_register_effect(seed_flight)
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), germination_center, aoe_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.22), false)
	_register_effect(telegraph)
	var damage_value: float = _rolled_damage(owner_node)
	var seed_tween := create_tween()
	seed_tween.tween_interval(maxf(grenade_delay, 0.08))
	# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
	seed_tween.tween_callback(Callable(self, "_germinate_symbiote_seed").bind(owner_node.get_instance_id(), germination_center, damage_value))


# Прорастание семени: стартовый маг.хит по области, затем инфекция всех задетых
# (порядок «урон → статусы»: trait-бонус окупается со следующего каста).
func _germinate_symbiote_seed(owner_id: int, center: Vector2, damage_value: float) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	var impact_damage := damage_value * maxf(seed_impact_ratio, 0.0) * (1.0 + _owner_mod("symbiote_impact_bonus"))
	_damage_enemies_in_circle_falloff(center, aoe_radius, impact_damage, damage_falloff)
	var ring_targets: Array = TARGET_QUERY.in_radius(self, center, aoe_radius)
	# FAN-1031 3c(b): крауд-инфекция ранжируется по дистанции (диминиш хвоста);
	# linked_targets (constellation) сохраняют ИСХОДНЫЙ порядок выборки — zero-collateral.
	var linked_targets: Array = []
	for enemy_node in ring_targets:
		if linked_targets.size() < 5:
			linked_targets.append(enemy_node)
	var infect_order := _status_fanout_order(center, ring_targets)
	for rank in range(infect_order.size()):
		var seed_infect_factor := _status_fanout_factor(rank)
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ заражения (см. _bio_spore_pulse). linked_targets
		# (constellation, кап 5) взяты ВЫШЕ из исходного порядка — их break не трогает.
		if seed_infect_factor <= 0.0:
			break
		_apply_bio_infection(infect_order[rank] as Node2D, current_owner, seed_infect_factor)
	if not linked_targets.is_empty():
		var host := linked_targets[0] as Node2D
		var link_result := _constellation_event("link", host, 0.0, {"linked_targets": linked_targets.size()})
		if bool(link_result.get("triggered", false)):
			var profile: Dictionary = current_owner.call("constellation_weapon_mechanic", weapon_id, "symbiote_link_transfer") as Dictionary if current_owner.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (profile as Dictionary).get("params", {}) if profile is Dictionary else {}
			var linked_ids := linked_targets.map(func(target): return (target as Node).get_instance_id())
			for linked_raw in linked_targets:
				var linked := linked_raw as Node2D
				linked.set_meta("constellation_symbiote_owner", current_owner.get_instance_id())
				linked.set_meta("constellation_symbiote_ids", linked_ids.duplicate())
				linked.set_meta("constellation_symbiote_share", clampf(float(params.get("shared_damage_ratio", 0.22)), 0.0, 0.5))
				linked.set_meta("constellation_symbiote_transfers", maxi(int(params.get("transfers_per_cast", 2)), 0))
	# SCRUM-961 «Расщепленный анализ»: ближайший к центру делится с соседями.
	_apply_bio_split_analysis(TARGET_QUERY.nearest(self, center, aoe_radius), impact_damage)


# SCRUM-896: базовое замедление Споровой Линзы (AC). Каждый задетый кольцом
func _apply_bio_spore_slow(owner_node: Node2D, center: Vector2, radius: float) -> void:
	var slow_power := _spore_slow_power(owner_node) + maxf(_owner_mod("spore_slow_power"), 0.0)
	if slow_power <= 0.0:
		return
	for enemy_node in TARGET_QUERY.in_radius(self, center, radius):
		StatusEffects.apply_status(enemy_node, "bio_spore_slow", {
			"duration": 1.6,
			"speed_multiplier": maxf(1.0 - slow_power, 0.25),
			"max_stacks": 1,
			"stack_mode": "refresh",
			"marker_color": Color(0.55, 0.95, 0.35, 1.0),
		})


# SCRUM-896: сила замедления линзы от прогрессии. spore_slow_base (5%) на
# старте, линейный рост к spore_slow_max (20%) к ~×3 эффективного magic_damage
# владельца от lvl1-базы класса; кламп с обеих сторон (AC: 5% мин, 20% макс) —
# сырой ростом урона потолок не пробивается.
func _spore_slow_power(owner_node: Node2D) -> float:
	if spore_slow_max <= 0.0:
		return 0.0
	if owner_node == null or not is_instance_valid(owner_node):
		return spore_slow_base
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var current_magic := maxf(float(parameters.get("magic_damage", 0.0)), 0.0)
	if _bio_magic_baseline <= 0.0:
		var raw_character = owner_node.get("character_id")
		var owner_class := str(raw_character) if raw_character != null and str(raw_character) != "" else "biologist"
		var baseline: Dictionary = ProgressionData.derived_parameters(ProgressionData.base_stats(owner_class), {}, ProgressionData.weapon(owner_class, weapon_id))
		_bio_magic_baseline = maxf(float(baseline.get("magic_damage", 1.0)), 0.001)
	var progress := clampf((current_magic / _bio_magic_baseline - 1.0) * 0.5, 0.0, 1.0)
	return clampf(spore_slow_base + (spore_slow_max - spore_slow_base) * progress, spore_slow_base, spore_slow_max)


# SCRUM-896/1005: биоинфекция — status-based DoT Биолога с атрибуцией владельца.
func _apply_bio_infection(enemy: Node, owner_node: Node2D, fanout_factor := 1.0) -> void:
	if dot_ticks <= 0 or enemy == null or not is_instance_valid(enemy):
		return
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := maxf(float(parameters.get("dot_damage", 1.0)), 1.0) * maxf(curse_tick_multiplier, 0.0) * clampf(fanout_factor, 0.0, 1.0)
	if tick_damage <= 0.0:
		return
	var tick_speed := maxf(float(parameters.get("dot_speed", 1.0)), 0.2) * maxf(curse_tick_rate, 0.2)
	var tick_interval := maxf(1.0 / tick_speed, 0.1)
	var total_ticks := dot_ticks
	if attack_mode == "bio_symbiote_web":
		total_ticks += int(_owner_mod("symbiote_dot_extra_ticks"))
	# SCRUM-942 паритет: классовый периодический множитель источника (у Биолога
	# 1.0) запекается в dot_damage на моменте применения — как у Химика.
	StatusEffects.apply_status_from(owner_node, enemy, "bio_infection", {
		"duration": (float(maxi(total_ticks, 1)) + 0.99) * tick_interval,
		"dot_damage": tick_damage,
		"dot_interval": tick_interval,
		"max_stacks": 1,
		"stack_mode": "refresh",
		"source_id": owner_node.get_instance_id(),
		"marker_color": Color(0.55, 0.95, 0.35, 1.0),
		"tick_feedback": {"damage_type": "dot", "player_owned": true, "bio_infection": true},
	})
	if enemy is Node2D:
		HazardVfx.dot_tick(enemy as Node2D, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))


# SCRUM-961 «Расщепленный анализ»: первичная цель каста сплэшит долю урона на
# 2 ближайших врагов. Сплэш бьёт напрямую (без _damage_enemy) — без каскада.
func _apply_bio_split_analysis(primary: Node2D, amount: float) -> void:
	var split_ratio := _owner_mod("analysis_split_ratio")
	if split_ratio <= 0.0 or primary == null or not is_instance_valid(primary):
		return
	var excluded := {primary.get_instance_id(): true}
	for neighbor in TARGET_QUERY.nearest_many(self, primary.global_position, maxf(aoe_radius, 160.0), 2, excluded):
		if neighbor == null or not is_instance_valid(neighbor) or not neighbor.has_method("take_damage"):
			continue
		var spore := AttackVfx.beam(_projectile_parent(), primary.global_position, neighbor.global_position, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
		_register_effect(spore)
		_call_take_damage(neighbor, amount * split_ratio, {"damage_type": _weapon_damage_type()})


func _apply_constellation_symbiote_share(enemy: Node, owner_node: Node, amount: float, hit_type: String) -> void:
	if enemy == null or owner_node == null or not enemy.has_meta("constellation_symbiote_owner"):
		return
	if int(enemy.get_meta("constellation_symbiote_owner", 0)) != owner_node.get_instance_id():
		return
	var ratio := clampf(float(enemy.get_meta("constellation_symbiote_share", 0.0)), 0.0, 0.5)
	var linked_ids = enemy.get_meta("constellation_symbiote_ids", [])
	if ratio > 0.0 and linked_ids is Array:
		for linked_id in linked_ids:
			var linked := instance_from_id(int(linked_id)) as Node
			if linked == null or not is_instance_valid(linked) or linked == enemy or not linked.has_method("take_damage"):
				continue
			_call_take_damage(linked, amount * ratio, {"damage_type": hit_type, "constellation_final": "symbiote_link_transfer"})
	var health_value = enemy.get("health")
	if health_value == null or float(health_value) > 0.0:
		return
	_constellation_transfer_symbiote_host(enemy, owner_node)


func _constellation_transfer_symbiote_host(enemy: Node, owner_node: Node) -> bool:
	if enemy == null or owner_node == null or not enemy.has_meta("constellation_symbiote_owner"):
		return false
	if int(enemy.get_meta("constellation_symbiote_owner", 0)) != owner_node.get_instance_id():
		return false
	var ratio := clampf(float(enemy.get_meta("constellation_symbiote_share", 0.0)), 0.0, 0.5)
	var linked_ids = enemy.get_meta("constellation_symbiote_ids", [])
	var transfers := maxi(int(enemy.get_meta("constellation_symbiote_transfers", 0)), 0)
	if transfers <= 0 or not linked_ids is Array:
		return false
	var excluded := {}
	for linked_id in linked_ids:
		excluded[int(linked_id)] = true
	var enemy_position := (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
	var replacement := TARGET_QUERY.nearest(self, enemy_position, aoe_radius, excluded)
	if replacement == null:
		return false
	var next_ids: Array = (linked_ids as Array).duplicate()
	next_ids.erase(enemy.get_instance_id())
	next_ids.append(replacement.get_instance_id())
	enemy.remove_meta("constellation_symbiote_owner")
	enemy.remove_meta("constellation_symbiote_ids")
	enemy.remove_meta("constellation_symbiote_share")
	enemy.remove_meta("constellation_symbiote_transfers")
	for linked_id in next_ids:
		var linked := instance_from_id(int(linked_id)) as Node
		if linked == null or not is_instance_valid(linked):
			continue
		linked.set_meta("constellation_symbiote_owner", owner_node.get_instance_id())
		linked.set_meta("constellation_symbiote_ids", next_ids.duplicate())
		linked.set_meta("constellation_symbiote_share", ratio)
		linked.set_meta("constellation_symbiote_transfers", transfers - 1)
	return true
