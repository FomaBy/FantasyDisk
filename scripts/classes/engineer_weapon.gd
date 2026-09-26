extends "res://scripts/classes/elementalist_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса engineer.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# SCRUM-908: последний целый уровень стеков «Сети мастерской» (для VFX-кью).
var _network_cue_tier := 0.0


func _exec_engineer_sentry_link(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_sentry_link(owner_node, direction)


func _exec_engineer_orbit_drone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_orbit_drone(owner_node, direction)


func _exec_engineer_pressure_mines(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_pressure_mines(owner_node, direction)


func _fire_engineer_sentry_link(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-905: «Часовая турель» = развёртка турелей С БОЕЗАПАСОМ.
	var alive_turrets: Array[Node] = []
	for device in _deployed_amps:
		if device != null and is_instance_valid(device):
			alive_turrets.append(device)
	_deployed_amps = alive_turrets
	var turret_limit := _engineer_turret_limit(owner_node)
	if _deployed_amps.size() >= turret_limit:
		return
	_emit_weapon_animation_event(owner_node, "deploy", 0.62, direction, {"pulse_interval": amp_pulse_interval})
	var turret_scene := SENTRY_TURRET_SCENE as PackedScene
	if turret_scene == null:
		return
	var turret := turret_scene.instantiate() as Node2D
	if turret == null:
		return
	if turret.has_method("setup"):
		turret.call("setup", self, owner_node)
	_projectile_parent().add_child(turret)
	_register_effect(turret)
	turret.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(turret)
	AttackVfx.ring_pulse(_projectile_parent(), turret.global_position, aoe_radius * 0.45, visual_color, false)
	# Мгновенное включение: турель сразу обстреливает ближайшего врага.
	if turret.has_method("try_fire"):
		turret.call("try_fire", self)


func _engineer_turret_limit(owner_node: Node2D) -> int:
	# SCRUM-905: предел парка = max_summons + floor(summon_amount/4)
	# (зеркало summon_count бюджет-модели), жёсткий рельс max_summons_cap;
	# бонус «Полевого чертежа» (+1 за каждые 6 Лидерства) добавляется ПОВЕРХ
	# рельса — иначе артефакт мёртв на раскачанном Лидерстве.
	var summon_amount := 0.0
	if owner_node != null and is_instance_valid(owner_node):
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			summon_amount = maxf(float((params as Dictionary).get("summon_amount", 0.0)), 0.0)
	var limit := maxi(max_summons, 1) + int(floor(summon_amount / 4.0))
	if max_summons_cap > 0:
		limit = mini(limit, max_summons_cap)
	return maxi(limit + _blueprint_device_cap_bonus(owner_node), 1)


func _engineer_turret_projectile_hit(target_instance_id: int, shot_damage: float) -> void:
	# Прилёт снаряда турели (колбэк твина полёта; цель — по instance id,
	# см. SCRUM-551: без захвата узлов в лямбдах).
	if _effects_shutdown:
		return
	var target := instance_from_id(target_instance_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	_damage_enemy(target, shot_damage)
	_damage_engineer_sentry_splash(target, shot_damage)


func _damage_engineer_sentry_splash(primary_target: Node2D, shot_damage: float) -> void:
	if primary_target == null or not is_instance_valid(primary_target):
		return
	if sentry_splash_radius <= 0.0 or sentry_splash_damage_multiplier <= 0.0 or sentry_splash_target_cap <= 0:
		return
	var excluded := {primary_target.get_instance_id(): true}
	var splash_targets := TARGET_QUERY.nearest_many(self, primary_target.global_position, sentry_splash_radius, sentry_splash_target_cap, excluded)
	for index in range(splash_targets.size()):
		var splash_target := splash_targets[index] as Node2D
		if splash_target == null or not is_instance_valid(splash_target):
			continue
		var factor := sentry_splash_damage_multiplier / (1.0 + float(index) * 0.75)
		_damage_enemy(splash_target, shot_damage * factor, false, _weapon_damage_type(), false)


func _fire_engineer_orbit_drone(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-906: «Орбитальный Дрон» — обслуживание ПОСТОЯННОГО парка орбитальных
	var alive_drones := _alive_orbit_drones()
	var target_count := _engineer_drone_target_count(owner_node)
	if alive_drones.size() >= target_count:
		return
	_emit_weapon_animation_event(owner_node, "deploy", 0.30, direction, {"drones": target_count})
	while alive_drones.size() < target_count:
		var drone := Node2D.new()
		drone.name = "EngineerOrbitDrone"
		drone.set_script(ENGINEER_ORBIT_DRONE_SCRIPT)
		var visual := Sprite2D.new()
		visual.texture = _weapon_visual_texture()
		visual.scale = Vector2.ONE * maxf(drone_visual_scale, 0.01)
		visual.modulate = Color(1.0, 1.0, 1.0, 0.92)
		drone.add_child(visual)
		_projectile_parent().add_child(drone)
		_register_effect(drone)
		if drone.has_method("setup"):
			drone.call("setup", self, owner_node, alive_drones.size(), target_count)
		alive_drones.append(drone)
	# Перераспределение фаз: спираль читается при любом числе дронов.
	for slot_index in range(alive_drones.size()):
		var slot_drone := alive_drones[slot_index]
		if slot_drone != null and is_instance_valid(slot_drone) and slot_drone.has_method("set_slot"):
			slot_drone.call("set_slot", slot_index, alive_drones.size())
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, drone_orbit_radius, visual_color, false)


func _engineer_drone_target_count(owner_node: Node2D) -> int:
	# SCRUM-906, FAN-1075: 2 дрона на базовом профиле Инженера; +1 за каждые
	# drone_count_step summon_amount сверх drone_count_threshold (порог ~
	# базовый summon_amount класса), рельс max_summons_cap. Задокументированные
	# пороги (threshold 12, step 4): 16 → 3, 20 → 4, 24 → 5, 28 → 6.
	var summon_amount := 0.0
	if owner_node != null and is_instance_valid(owner_node):
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			summon_amount = maxf(float((params as Dictionary).get("summon_amount", 0.0)), 0.0)
	var extra := int(floor(maxf(summon_amount - drone_count_threshold, 0.0) / maxf(drone_count_step, 0.5)))
	var count := maxi(max_summons, 1) + extra
	if max_summons_cap > 0:
		count = mini(count, max_summons_cap)
	return maxi(count, 1)


func _alive_orbit_drones() -> Array[Node2D]:
	var drones: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("orbit_drone"):
			drones.append(effect as Node2D)
	return drones


func _fire_engineer_pressure_mines(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-907: каждый деплой — 2 персистентные мины (projectile_count; extra-
	var mine_count := maxi(projectile_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "deploy", 0.40, direction, {"count": mine_count})
	var mine_cap := _engineer_mine_cap(owner_node)
	var alive_count := _alive_persistent_mines().size()
	var placement_min := maxf(mine_place_min_distance, 24.0)
	var placement_max := maxf(mine_place_max_distance, placement_min + 1.0)
	for mine_index in range(mine_count):
		if alive_count >= mine_cap:
			return
		var mine_direction := Vector2.RIGHT.rotated(randf() * TAU)
		var distance := randf_range(placement_min, placement_max)
		_spawn_engineer_pressure_mine(owner_node, owner_node.global_position + mine_direction * distance, mine_index)
		alive_count += 1


func _spawn_engineer_pressure_mine(owner_node: Node2D, mine_position: Vector2, mine_index: int) -> void:
	var mine := Node2D.new()
	mine.name = "EngineerPressureMine"
	mine.set_script(ENGINEER_MINE_SCRIPT)
	var visual := Sprite2D.new()
	visual.texture = _weapon_visual_texture()
	visual.scale = Vector2.ONE * 0.18
	visual.modulate = Color(1.0, 1.0, 1.0, 0.86)
	mine.add_child(visual)
	_projectile_parent().add_child(mine)
	_register_effect(mine)
	mine.global_position = mine_position
	if mine.has_method("setup"):
		mine.call("setup", self, owner_node, mine_index)
	AttackVfx.ring_pulse(_projectile_parent(), mine_position, aoe_radius * 0.52, visual_color, true)


# SCRUM-907: подрыв персистентной мины (зовёт scripts/engineer_mine.gd по
# триггеру врага/игрока). Урон по области с damage_falloff от эпицентра;
# «Ядро утилизации» возвращает долю перезарядки.
func _detonate_engineer_mine(mine_instance_id: int, owner_instance_id: int, mine_index: int, chain_depth := 0, chain_scale := 1.0, chain_hit_counts := {}) -> void:
	var mine := instance_from_id(mine_instance_id) as Node2D
	if mine == null or not is_instance_valid(mine):
		return
	var current_owner := instance_from_id(owner_instance_id) as Node2D
	var owner_alive := current_owner != null and is_instance_valid(current_owner)
	if owner_alive:
		_emit_weapon_animation_event(current_owner, "release", 0.0, Vector2.RIGHT, {"mine_index": mine_index})
	var mine_damage := (_rolled_damage(current_owner) if owner_alive else damage) * clampf(chain_scale, 0.0, 1.0)
	var hit_counts: Dictionary = chain_hit_counts if chain_hit_counts is Dictionary else {}
	for enemy_raw in TARGET_QUERY.in_radius(self, mine.global_position, aoe_radius):
		var enemy := enemy_raw as Node2D
		var enemy_id := enemy.get_instance_id()
		if int(hit_counts.get(enemy_id, 0)) >= 2:
			continue
		hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
		var distance := mine.global_position.distance_to(enemy.global_position)
		var factor := lerpf(1.0, clampf(damage_falloff, 0.0, 1.0), distance / maxf(aoe_radius, 1.0))
		_damage_enemy(enemy, mine_damage * factor)
	var chain_result := _constellation_event("mine_explosion", null, 0.0, {"chain_depth": chain_depth})
	if bool(chain_result.get("triggered", false)) and chain_depth < 2:
		var adjacent_mines := _alive_persistent_mines(mine)
		adjacent_mines.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return mine.global_position.distance_squared_to(a.global_position) < mine.global_position.distance_squared_to(b.global_position)
		)
		if not adjacent_mines.is_empty():
			var adjacent := adjacent_mines[0]
			var ratio := maxf(float(chain_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
			var chain_tween := create_tween()
			chain_tween.tween_interval(0.12)
			chain_tween.tween_callback(Callable(self, "_detonate_engineer_mine").bind(adjacent.get_instance_id(), owner_instance_id, mine_index, chain_depth + 1, ratio, hit_counts))
	AttackVfx.orb_burst(_projectile_parent(), mine.global_position, aoe_radius * 0.72, visual_color)
	_release_effect(mine)
	_salvage_device_refund()  # SCRUM-961 «Ядро утилизации»


func _engineer_mine_cap(owner_node: Node2D) -> int:
	# SCRUM-907: кап живых мин = mine_active_cap (база 6) + «Минная сумка»
	# (mine_cap_bonus) + «Полевой чертеж» (+1 за каждые 6 Лидерства).
	var cap := maxi(mine_active_cap, 1) + int(_owner_mod("mine_cap_bonus")) + _blueprint_device_cap_bonus(owner_node)
	return maxi(cap, 1)


# SCRUM-961 «Полевой чертеж» (SCRUM-905/907 rework): +1 к пределу устройств
# (турели и мины) за каждые 6 Лидерства. Прежний lifetime-бонус мин умер вместе
# с таймером жизни (мины теперь персистентные, SCRUM-907).
func _blueprint_device_cap_bonus(owner_node: Node2D) -> int:
	if _owner_mod("blueprint_leadership_scaling") <= 0.0:
		return 0
	var reference: Node2D = owner_node if owner_node != null and is_instance_valid(owner_node) else _owner_node()
	if reference == null:
		return 0
	var stats = reference.get("stats")
	if not (stats is Dictionary):
		return 0
	return int(floor(float((stats as Dictionary).get("leadership", 0.0)) / 6.0))


# SCRUM-961 «Корневой капкан»: сработавший капкан укореняет жертв (кламп движка


func _alive_persistent_mines(exclude: Node2D = null) -> Array[Node2D]:
	var alive_mines: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("persistent_mine") and effect != exclude:
			alive_mines.append(effect as Node2D)
	return alive_mines


# SCRUM-961 «Ядро утилизации»: отжившее/подорванное устройство возвращает
# долю перезарядки текущего deploy-оружия.
func _salvage_device_refund() -> void:
	var refund_ratio := _owner_mod("salvage_refund_ratio")
	if refund_ratio <= 0.0:
		return
	_cooldown = maxf(_cooldown - fire_interval * refund_ratio, 0.0)


# SCRUM-961 «Полевой чертеж»: Лидерство продлевает жизнь ловушек (+12% за 6 LDR).
# SCRUM-907: мины инженера персистентны и этот множитель больше НЕ используют —
# остаётся только generic trap-путь; для устройств см. _blueprint_device_cap_bonus.
func _blueprint_lifetime_multiplier() -> float:
	if _owner_mod("blueprint_leadership_scaling") <= 0.0:
		return 1.0
	var owner_node := _owner_node()
	if owner_node == null:
		return 1.0
	var stats = owner_node.get("stats")
	if not (stats is Dictionary):
		return 1.0
	return 1.0 + 0.12 * floor(float((stats as Dictionary).get("leadership", 0.0)) / 6.0)


# SCRUM-908 «Сеть мастерской» (workshop_network): активные устройства инженера
func _workshop_network_factor(owner_node: Node2D) -> float:
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("class_trait_value"):
		return 1.0
	var per_stack := float(owner_node.call("class_trait_value", "network_damage_per_stack", 0.0))
	if per_stack <= 0.0:
		return 1.0
	var stacks := _workshop_network_stacks(owner_node)
	if stacks <= 0.0:
		return 1.0
	return 1.0 + stacks * per_stack


func _workshop_network_stacks(owner_node: Node2D) -> float:
	var weight_sum := 0.0
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("network_weight"):
			weight_sum += maxf(float(effect.get_meta("network_weight")), 0.0)
	var cap_base := float(owner_node.call("class_trait_value", "network_stack_cap_base", 3.0))
	var cap_step := maxf(float(owner_node.call("class_trait_value", "network_cap_leadership_step", 6.0)), 1.0)
	var leadership := 0.0
	var stats = owner_node.get("stats")
	if stats is Dictionary:
		leadership = maxf(float((stats as Dictionary).get("leadership", 0.0)), 0.0)
	var cap := maxf(cap_base + floor(leadership / cap_step), 0.0)
	var stacks := minf(weight_sum, cap)
	_maybe_pulse_network_cue(owner_node, stacks)
	return stacks


# Лёгкий фидбек сети (AC SCRUM-908): при смене ЦЕЛОГО числа стеков — короткий
# ринг-пульс вокруг инженера (существующий VFX-паттерн, без новых UI-файлов).
func _maybe_pulse_network_cue(owner_node: Node2D, stacks: float) -> void:
	var tier := floorf(stacks)
	if is_equal_approx(tier, _network_cue_tier):
		return
	_network_cue_tier = tier
	if tier <= 0.0 or _effects_shutdown or not is_inside_tree():
		return
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, 54.0 + 8.0 * tier, Color(0.98, 0.82, 0.30, 0.30), false)
