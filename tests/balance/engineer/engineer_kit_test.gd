extends SceneTree

# SCRUM-905..908: focused-тест редизайна кита Инженера.
#   905 «Часовая турель»: турели с боезапасом 15 — расстреляла магазин →
#       свернулась; таймера жизни нет; предел парка 2+floor(summon_amount/4)
#       (рельс 6, «Полевой чертеж» поверх), при полном парке деплой skip;
#       темп стрельбы ускоряется attack_speed (расход боезапаса быстрее).
#   906 «Орбитальный Дрон»: дроны кружат вокруг игрока (стартовая пара
#       антиподальна на одном кольце, с третьего дрона — спираль по слотам),
#       физический контактный урон с per-enemy кулдауном; число дронов
#       2+floor(max(sa-12,0)/4) (2 на базовом профиле, 6 при sa=28, рельс 6);
#       FAN-1075: радиус 121 px; FAN-1101: визуальный scale 0.36, контакт 66 px
#       (физически крупнее дроны); RPM растёт от attack_speed.
#   907 «Минная Сетка»: ровно 2 персистентные мины за деплой в случайном
#       кольце 110..260; таймера жизни НЕТ; враг подрывает сразу (и в первые
#       3с), сам игрок — только после 3с; кап живых 6 (skip, не retire).
#   908 «Сеть мастерской»: живые устройства дают стеки (турель/дрон 1.0,
#       мина 0.5), кап 3+floor(Лидерство/6), +6% урона устройств за стек;
#       не течёт классам без trait'а.
#   Бюджет-зеркала: _budget_sentry_ammo_model / _budget_orbit_drone_dps /
#       _budget_network_factor.
#
# Запуск: Godot --headless --path . --script res://tests/engineer_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EPS := 0.001


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"attack_speed": 1.0,
		"summon_amount": 0.0,
		"leadership": 0.0,
		"dot_damage": 4.0,
	}
	var run_modifiers := {}
	var stats := {"leadership": 0.0}
	var health := 100.0
	var max_health := 100.0
	# false = класс без trait'а (утечка «Сети мастерской» запрещена).
	var engineer_trait := false

	func class_trait_value(key: String, default_value := 0.0) -> float:
		if not engineer_trait:
			return default_value
		var trait_config: Dictionary = PD.CLASS_TRAITS.get("engineer", {})
		return float(trait_config.get(key, default_value))


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _initialize() -> void:
	seed(20260905)
	var errors: Array = []
	# Дешёвые data-гейты первыми (FAIL fast), потом live-механика.
	_test_trait_registry_and_configs(errors)
	_test_budget_models(errors)
	await _test_trait_runtime_on_player(errors)
	await _test_sentry_cadence_exact_once(errors)
	await _test_sentry_extra_projectile_invariants(errors)
	await _test_turret_shot_limit_and_persistence(errors)
	await _test_turret_capacity_scaling(errors)
	await _test_orbit_drone_orbit_and_contact(errors)
	await _test_orbit_drone_count_scaling_and_spiral(errors)
	await _test_mines_pair_random_persistent(errors)
	await _test_mines_triggers_and_cap(errors)
	await _test_workshop_network_stacks(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Engineer kit (SCRUM-905..908): %s" % str(error))
		push_error("Engineer kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Engineer kit test passed (SCRUM-905..908: shot-limit turrets, orbit drones, persistent mines, workshop network).")
	quit(0)


# --- data-гейты ---------------------------------------------------------------


func _test_trait_registry_and_configs(errors: Array) -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("engineer", {})
	if str(trait_config.get("id", "")) != "workshop_network":
		errors.append("CLASS_TRAITS.engineer.id != workshop_network")
	if float(trait_config.get("network_damage_per_stack", 0.0)) <= 0.0:
		errors.append("network_damage_per_stack должен быть > 0")
	if float(trait_config.get("network_stack_cap_base", 0.0)) <= 0.0:
		errors.append("network_stack_cap_base должен быть > 0")
	if float(trait_config.get("network_cap_leadership_step", 0.0)) <= 0.0:
		errors.append("network_cap_leadership_step должен быть > 0")
	if absf(float(trait_config.get("network_mine_weight", 0.0)) - 0.5) > EPS:
		errors.append("network_mine_weight мин должен быть 0.5 (предохранитель от мин-спама)")
	if str(trait_config.get("title", "")) == "" or str(trait_config.get("description", "")) == "":
		errors.append("trait обязан нести player-facing title/description (RU)")

	# Реестр режимов: орбитальный дрон зарегистрирован, старая цепь удалена.
	if not ClassWeapon.has_attack_mode_executor("engineer_orbit_drone"):
		errors.append("attack_mode 'engineer_orbit_drone' не зарегистрирован")
	if ClassWeapon.has_attack_mode_executor("engineer_repair_drone"):
		errors.append("старый attack_mode 'engineer_repair_drone' обязан быть удалён")
	for mode in ["engineer_sentry_link", "engineer_pressure_mines"]:
		if not ClassWeapon.has_attack_mode_executor(mode):
			errors.append("attack_mode '%s' не зарегистрирован" % mode)

	var sentry: Dictionary = PD.weapon("engineer", "engineer_sentry_wrench")
	var drone: Dictionary = PD.weapon("engineer", "engineer_repair_drone")
	var mines: Dictionary = PD.weapon("engineer", "engineer_pressure_mines")

	# 905: магазин 15, предел парка растёт (рельс 6), физическая ось.
	if int(sentry.get("sentry_shot_magazine", 0)) != 15:
		errors.append("sentry_shot_magazine != 15")
	if int(sentry.get("max_summons", 0)) != 2 or int(sentry.get("max_summons_cap", 0)) != 6:
		errors.append("sentry max_summons/cap != 2/6")
	if str(sentry.get("damage_parameter", "")) != "damage":
		errors.append("турели обязаны скейлиться от физического damage")
	# SCRUM-904: переименование «Ключ Часового» → «Часовая турель» (id сохранён).
	if str(sentry.get("title", "")) != "Часовая турель":
		errors.append("sentry title != «Часовая турель» (got %s)" % sentry.get("title", ""))
	if str(sentry.get("id", "")) != "engineer_sentry_wrench":
		errors.append("внутренний id sentry обязан остаться engineer_sentry_wrench")

	# 906: орбитальный режим, ремонт удалён, физическая ось.
	if str(drone.get("attack_mode", "")) != "engineer_orbit_drone":
		errors.append("drone.attack_mode != engineer_orbit_drone")
	if str(drone.get("damage_parameter", "")) != "damage":
		errors.append("дрон обязан наносить физический damage")
	if drone.has("heal_percent_of_damage") or drone.has("summon_support_heal_percent"):
		errors.append("ремонт/скрытый сустейн дрона обязан быть удалён (AC SCRUM-906)")
	for key in ["drone_orbit_radius", "drone_visual_scale", "drone_orbit_speed", "drone_contact_radius", "drone_hit_cooldown", "drone_count_threshold", "drone_count_step"]:
		if float(drone.get(key, 0.0)) <= 0.0:
			errors.append("drone config без ключа %s" % key)
	if int(drone.get("max_summons", 0)) != 2 or int(drone.get("max_summons_cap", 0)) != 6:
		errors.append("drone max_summons/cap != 2/6")
	if absf(float(drone.get("drone_orbit_radius", 0.0)) - 121.0) > EPS:
		errors.append("drone_orbit_radius != 121 (+55% к 78)")
	if absf(float(drone.get("drone_visual_scale", 0.0)) - 0.36) > EPS:
		errors.append("drone_visual_scale != 0.36 (FAN-1101: +50% к 0.24)")
	if absf(float(drone.get("drone_contact_radius", 0.0)) - 66.0) > EPS:
		errors.append("drone_contact_radius != 66 (FAN-1101: +50% к 44)")

	# 907: ровно 2 мины, персистентные ключи, таймер жизни удалён.
	if int(mines.get("projectile_count", 0)) != 2:
		errors.append("mines projectile_count != 2")
	if mines.has("pool_duration") or mines.has("pool_tick_interval"):
		errors.append("минный pool-таймер обязан быть удалён (мины персистентные)")
	if absf(float(mines.get("mine_self_arm_delay", 0.0)) - 3.0) > EPS:
		errors.append("mine_self_arm_delay != 3.0")
	if int(mines.get("mine_active_cap", 0)) != 6:
		errors.append("mine_active_cap != 6")
	var place_min := float(mines.get("mine_place_min_distance", 0.0))
	var place_max := float(mines.get("mine_place_max_distance", 0.0))
	if place_min < 24.0 or place_max <= place_min or place_max > 320.0:
		errors.append("кольцо размещения мин вне разумной зоны (%.0f..%.0f)" % [place_min, place_max])


func _test_budget_models(errors: Array) -> void:
	var stats: Dictionary = PD.base_stats("engineer")
	var sentry: Dictionary = PD.weapon("engineer", "engineer_sentry_wrench")
	var drone: Dictionary = PD.weapon("engineer", "engineer_repair_drone")
	var mines: Dictionary = PD.weapon("engineer", "engineer_pressure_mines")
	var sentry_params: Dictionary = PD.derived_parameters(stats, {}, sentry)
	var drone_params: Dictionary = PD.derived_parameters(stats, {}, drone)

	# Ammo-модель турели: непустая, DPS > 0, supply ограничивает толпу.
	var sentry_model: Dictionary = PD._budget_sentry_ammo_model(sentry, sentry_params, stats)
	if sentry_model.is_empty() or float(sentry_model.get("summon_dps", 0.0)) <= 0.0:
		errors.append("_budget_sentry_ammo_model пуст для турели")
	if not PD._budget_sentry_ammo_model(mines, sentry_params, stats).is_empty():
		errors.append("_budget_sentry_ammo_model протёк на мины")

	# Орбитальная модель: базовый профиль — ровно 2 дрона; рост RPM от attack_speed.
	var orbit_model: Dictionary = PD._budget_orbit_drone_dps(drone, drone_params, stats)
	if orbit_model.is_empty() or float(orbit_model.get("summon_dps", 0.0)) <= 0.0:
		errors.append("_budget_orbit_drone_dps пуст для дрона")
	var fast_params: Dictionary = drone_params.duplicate(true)
	fast_params["attack_speed"] = float(drone_params.get("attack_speed", 1.0)) * 1.5
	var fast_model: Dictionary = PD._budget_orbit_drone_dps(drone, fast_params, stats)
	if float(fast_model.get("summon_dps", 0.0)) <= float(orbit_model.get("summon_dps", 0.0)) + EPS:
		errors.append("attack_speed обязан поднимать контактный DPS дрона (RPM)")

	# Network-фактор: > 1 для устройств инженера, ровно 1 для чужого класса.
	for config in [sentry, drone, mines]:
		if PD._budget_network_factor(config, sentry_params, stats) <= 1.0 + EPS:
			errors.append("_budget_network_factor не поднял %s" % config.get("id", "?"))
	var rifle: Dictionary = PD.weapon("soldier", "soldier_rifle")
	rifle["character_id"] = "soldier"
	if absf(PD._budget_network_factor(rifle, sentry_params, PD.base_stats("soldier")) - 1.0) > EPS:
		errors.append("network-фактор протёк на класс без trait'а")

	# Тюнинг кита: множители в коридоре, без клампов (0.28 / 2.80).
	for weapon_id in PD.weapon_ids("engineer"):
		var config: Dictionary = PD.weapon("engineer", str(weapon_id))
		var mult := float(config.get("budget_damage_multiplier", 1.0))
		if mult <= 0.29 or mult >= 2.79:
			errors.append("%s: budget_damage_multiplier %.3f у клампа — модель/скаляр рассогласованы" % [weapon_id, mult])


# --- live-механика ------------------------------------------------------------


func _test_trait_runtime_on_player(errors: Array) -> void:
	var holder := _new_scene("TraitPlayerScene")
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	await process_frame
	player.call("configure_character", "engineer", "engineer_pressure_mines")
	await process_frame
	if absf(float(player.call("class_trait_value", "network_damage_per_stack", 0.0)) - 0.06) > EPS:
		errors.append("реальный Player не читает network_damage_per_stack=0.06")
	if float(player.call("class_trait_value", "network_stack_cap_base", 0.0)) <= 0.0:
		errors.append("реальный Player не читает network_stack_cap_base")
	await _cleanup(holder)


func _test_sentry_cadence_exact_once(errors: Array) -> void:
	var holder := _new_scene("SentryCadencePlayerScene")
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	await process_frame
	player.call("configure_character", "engineer", "engineer_sentry_wrench")
	await process_frame
	var weapon := player.get("equipped_weapon") as Node
	if weapon == null:
		errors.append("real Player не экипировал sentry для cadence regression")
		await _cleanup(holder)
		return
	weapon.call("_fire_engineer_sentry_link", player, Vector2.RIGHT)
	await process_frame
	var devices := _engineer_devices(holder)
	if devices.is_empty():
		errors.append("real Player не развернул sentry для cadence regression")
		await _cleanup(holder)
		return
	var turret: Node2D = devices[0]
	var config := PD.weapon("engineer", "engineer_sentry_wrench")
	var baseline_pulse := float(turret.call("effective_pulse_interval", weapon))
	var baseline_expected := _sentry_budget_pulse(config, player)
	if absf(baseline_pulse - baseline_expected) > EPS:
		errors.append("real Player baseline sentry pulse %.3f != budget %.3f" % [baseline_pulse, baseline_expected])
	player.call("apply_reward", {"stats": {"agility": 5.0}})
	var fast_pulse := float(turret.call("effective_pulse_interval", weapon))
	var fast_expected := _sentry_budget_pulse(config, player)
	if fast_pulse >= baseline_pulse - EPS or absf(fast_pulse - fast_expected) > EPS:
		errors.append("real Player sentry cadence not exact-once (base %.3f, fast %.3f, budget %.3f)" % [baseline_pulse, fast_pulse, fast_expected])
	var stored_pulse := float(weapon.get("amp_pulse_interval"))
	if absf(stored_pulse - float(config.get("amp_pulse_interval", 0.0))) > EPS:
		errors.append("Player pre-scaled sentry pulse before turret consumed attack_speed (%.3f != raw %.3f)" % [stored_pulse, config.get("amp_pulse_interval", 0.0)])
	player.call("_apply_weapon_scaling", weapon)
	if absf(float(turret.call("effective_pulse_interval", weapon)) - fast_pulse) > EPS:
		errors.append("repeated real Player scaling changed sentry cadence")
	await _cleanup(holder)


func _sentry_budget_pulse(config: Dictionary, player: Node) -> float:
	var stats: Dictionary = player.get("stats")
	var params: Dictionary = player.get("derived_parameters")
	var tempo := 1.0 + minf(float(params.get("summon_amount", 0.0)) * 0.014 + float(stats.get("leadership", 0.0)) * 0.006, 0.30)
	return maxf(maxf(float(config.get("amp_pulse_interval", 0.55)), 0.18) / tempo / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.10)


func _test_sentry_extra_projectile_invariants(errors: Array) -> void:
	var holder := _new_scene("SentryExtraProjectileInvariantScene")
	var owner := _new_owner(holder)
	owner.derived_parameters["summon_amount"] = 12.0
	owner.derived_parameters["leadership"] = 6.0
	owner.stats["leadership"] = 6.0
	var weapon := _new_weapon(owner, "engineer_sentry_wrench")
	var base_park := int(weapon.get("max_summons"))
	var base_limit := int(weapon.call("_engineer_turret_limit", owner))
	var base_damage := float(weapon.call("_rolled_damage", owner))
	var base_summon_amount := float(owner.derived_parameters["summon_amount"])
	weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	var turrets := _engineer_devices(holder)
	if turrets.is_empty():
		errors.append("extra_projectile invariant: baseline sentry did not deploy")
		await _cleanup(holder)
		return
	var base_cadence := float(turrets[0].call("effective_pulse_interval", weapon))
	owner.run_modifiers = {"extra_projectile": 1.0}
	if int(weapon.call("_extra_projectiles")) != 1:
		errors.append("extra_projectile invariant: sentry must consume one modifier point per volley")
	if int(weapon.get("projectile_count")) != 2:
		errors.append("extra_projectile invariant: base volley changed from 2")
	if int(weapon.get("max_summons")) != base_park or absf(float(owner.derived_parameters["summon_amount"]) - base_summon_amount) > EPS:
		errors.append("extra_projectile invariant: summon scaling changed")
	if int(weapon.call("_engineer_turret_limit", owner)) != base_limit:
		errors.append("extra_projectile invariant: turret cap changed %d -> %d" % [base_limit, int(weapon.call("_engineer_turret_limit", owner))])
	if absf(float(weapon.call("_rolled_damage", owner)) - base_damage) > EPS:
		errors.append("extra_projectile invariant: sentry damage changed")
	if absf(float(turrets[0].call("effective_pulse_interval", weapon)) - base_cadence) > EPS:
		errors.append("extra_projectile invariant: sentry cadence changed")
	for _deploy in range(base_limit + 1):
		weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != base_limit:
		errors.append("extra_projectile invariant: active turret count %d != cap %d" % [_engineer_devices(holder).size(), base_limit])
	await _cleanup(holder)


func _test_turret_shot_limit_and_persistence(errors: Array) -> void:
	var holder := _new_scene("TurretScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "engineer_sentry_wrench")
	await process_frame

	# Деплой БЕЗ врагов: турель стоит, боезапас цел, таймера жизни нет.
	weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	var turrets := _engineer_devices(holder)
	if turrets.size() != 1:
		errors.append("ожидалась 1 турель после деплоя, получено %d" % turrets.size())
		await _cleanup(holder)
		return
	var turret: Node2D = turrets[0]
	if int(turret.call("shots_left")) != 15:
		errors.append("боезапас новой турели != 15 (got %s)" % turret.call("shots_left"))
	for _frame in range(90):  # ~1.5с без врагов — персистентность без таймера
		await process_frame
	if not is_instance_valid(turret):
		errors.append("турель без врагов обязана стоять (нет таймера жизни)")
		await _cleanup(holder)
		return
	if int(turret.call("shots_left")) != 15:
		errors.append("без врагов боезапас не должен тратиться")

	# Одиночная цель: try_fire тратит РОВНО 1 заряд за пульс; 15-й — деспаун.
	turret.set_physics_process(false)  # детерминизм: пульсы руками (ДО спавна цели)
	var enemy := _new_enemy(holder, turret.global_position + Vector2(120, 0))
	await process_frame
	for shot_index in range(14):
		if not bool(turret.call("try_fire", weapon)):
			errors.append("try_fire #%d не выстрелил по живой цели" % (shot_index + 1))
	if int(turret.call("shots_left")) != 1:
		errors.append("после 14 выстрелов должен остаться 1 заряд (got %s)" % turret.call("shots_left"))
	if not is_instance_valid(turret) or turret.is_queued_for_deletion():
		errors.append("турель свернулась раньше 15-го выстрела")
	turret.call("try_fire", weapon)  # 15-й выстрел
	await process_frame
	if is_instance_valid(turret) and not turret.is_queued_for_deletion():
		errors.append("после 15-го выстрела турель обязана свернуться немедленно")
	for _frame in range(40):  # дать снарядам долететь (твин полёта)
		await process_frame
	if enemy.total_damage <= EPS:
		errors.append("выстрелы турели не нанесли физический урон")

	# Скорость атаки ускоряет пульс (расход боезапаса быстрее).
	weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	var second_turret: Node2D = _engineer_devices(holder)[0]
	var base_pulse := float(second_turret.call("effective_pulse_interval", weapon))
	owner.derived_parameters["attack_speed"] = 2.0
	var fast_pulse := float(second_turret.call("effective_pulse_interval", weapon))
	if absf(fast_pulse - base_pulse / 2.0) > 0.011:
		errors.append("attack_speed x2 обязан вдвое ускорить пульс турели (%.3f -> %.3f)" % [base_pulse, fast_pulse])
	owner.derived_parameters["attack_speed"] = 1.0

	# Lifecycle-чистка: cleanup_effects не оставляет висячих устройств.
	weapon.call("cleanup_effects")
	await process_frame
	if not _engineer_devices(holder).is_empty():
		errors.append("cleanup_effects оставил висячие турели")
	await _cleanup(holder)


func _test_turret_capacity_scaling(errors: Array) -> void:
	var holder := _new_scene("TurretCapScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "engineer_sentry_wrench")
	await process_frame

	# База (summon_amount 0): предел 2; третий деплой пропускается.
	for _cast in range(3):
		weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 2:
		errors.append("предел парка на базе != 2 (got %d)" % _engineer_devices(holder).size())
	weapon.call("cleanup_effects")
	await process_frame

	# Лидерская прокачка: summon_amount 12.5 -> 2 + 3 = 5 (документированные пороги).
	owner.derived_parameters["summon_amount"] = 12.5
	for _cast in range(7):
		weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 5:
		errors.append("предел парка при sa=12.5 != 5 (got %d)" % _engineer_devices(holder).size())
	weapon.call("cleanup_effects")
	await process_frame

	# Рельс 6 + «Полевой чертеж» поверх (+2 за 12 Лидерства): 6 + 2 = 8.
	owner.derived_parameters["summon_amount"] = 40.0
	owner.run_modifiers["blueprint_leadership_scaling"] = 1.0
	owner.stats["leadership"] = 12.0
	for _cast in range(10):
		weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 8:
		errors.append("рельс 6 + чертеж (+2) != 8 турелей (got %d)" % _engineer_devices(holder).size())
	weapon.call("cleanup_effects")
	await _cleanup(holder)


func _test_orbit_drone_orbit_and_contact(errors: Array) -> void:
	var holder := _new_scene("DroneScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "engineer_repair_drone")
	await process_frame

	# Базовый профиль mock-владельца (summon_amount 0): ровно 2 дрона.
	weapon.call("_fire_engineer_orbit_drone", owner, Vector2.RIGHT)
	await process_frame
	var drones := _engineer_devices(holder)
	if drones.size() != 2:
		errors.append("на базе ожидалось ровно 2 дрона, получено %d" % drones.size())
		await _cleanup(holder)
		return
	var drone: Node2D = drones[0]

	# Орбита: стартовая пара держит единый радиус 121, движется и остаётся
	# строго напротив друг друга (разница фаз 180 градусов).
	var start_position := drone.global_position
	for _frame in range(20):
		await process_frame
	if not is_instance_valid(drone):
		errors.append("дрон исчез без причины")
		await _cleanup(holder)
		return
	var travelled := start_position.distance_to(drone.global_position)
	if travelled <= 8.0:
		errors.append("дрон не движется по орбите (сдвиг %.1f)" % travelled)
	var orbit_distance := owner.global_position.distance_to(drone.global_position)
	if absf(orbit_distance - 121.0) > 6.0:
		errors.append("радиус орбиты слота 0 != ~121 (got %.1f)" % orbit_distance)
	var opposite: Node2D = drones[1]
	var opposite_distance := owner.global_position.distance_to(opposite.global_position)
	if absf(opposite_distance - 121.0) > 6.0:
		errors.append("радиус орбиты слота 1 != ~121 (got %.1f)" % opposite_distance)
	var first_direction := (drone.global_position - owner.global_position).normalized()
	var second_direction := (opposite.global_position - owner.global_position).normalized()
	if first_direction.dot(second_direction) > -0.999:
		errors.append("стартовые дроны не напротив друг друга (dot %.4f)" % first_direction.dot(second_direction))
	var visual := drone.get_child(0) as Sprite2D
	if visual == null or absf(visual.scale.x - 0.36) > EPS or absf(visual.scale.y - 0.36) > EPS:
		errors.append("визуальный scale дрона != 0.36")

	# Контакт: враг в точке дрона получает физический урон РОВНО раз за кулдаун.
	var enemy := _new_enemy(holder, drone.global_position)
	for _frame in range(18):  # ~0.3с: несколько сканов, кулдаун 0.85с не истёк
		if is_instance_valid(drone):
			enemy.global_position = drone.global_position  # клей к дрону
		await process_frame
	if enemy.hit_count != 1:
		errors.append("per-enemy кулдаун: ожидался ровно 1 хит за 0.3с, получено %d" % enemy.hit_count)
	# Урон контакта = 100 (damage) x 0.9 (контакт) x 1.1 (orbit_drone role, без LDR).
	if enemy.hit_count >= 1 and absf(enemy.total_damage - 99.0) > 0.5:
		errors.append("урон контакта дрона != ~99 (got %.2f)" % enemy.total_damage)

	# RPM от attack_speed: угловая скорость удваивается.
	var base_speed := float(drone.call("orbit_angular_speed", weapon, owner))
	owner.derived_parameters["attack_speed"] = 2.0
	var fast_speed := float(drone.call("orbit_angular_speed", weapon, owner))
	if absf(fast_speed - base_speed * 2.0) > EPS:
		errors.append("attack_speed x2 обязан удвоить RPM (%.2f -> %.2f)" % [base_speed, fast_speed])
	owner.derived_parameters["attack_speed"] = 1.0

	weapon.call("cleanup_effects")
	await process_frame
	if not _engineer_devices(holder).is_empty():
		errors.append("cleanup_effects оставил висячие дроны")
	await _cleanup(holder)


func _test_orbit_drone_count_scaling_and_spiral(errors: Array) -> void:
	var holder := _new_scene("DroneSpiralScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "engineer_repair_drone")
	await process_frame

	# Документированные пороги: sa=16 -> 3, sa=28 -> 6 (жёсткий рельс).
	owner.derived_parameters["summon_amount"] = 16.0
	weapon.call("_fire_engineer_orbit_drone", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 3:
		errors.append("sa=16 обязан дать 3 дрона (got %d)" % _engineer_devices(holder).size())

	owner.derived_parameters["summon_amount"] = 28.0
	weapon.call("_fire_engineer_orbit_drone", owner, Vector2.RIGHT)
	await process_frame
	var drones := _engineer_devices(holder)
	if drones.size() != 6:
		errors.append("sa=28 обязан дать 6 дронов (got %d)" % drones.size())

	# Спираль: дроны не слипаются в одну точку, радиусы слотов различаются.
	await process_frame
	var min_pair_distance := INF
	var radii: Array = []
	for drone in drones:
		radii.append(owner.global_position.distance_to((drone as Node2D).global_position))
		for other in drones:
			if other == drone:
				continue
			min_pair_distance = minf(min_pair_distance, (drone as Node2D).global_position.distance_to((other as Node2D).global_position))
	if drones.size() >= 2 and min_pair_distance < 16.0:
		errors.append("дроны слиплись в одну точку (min дистанция %.1f)" % min_pair_distance)
	radii.sort()
	if drones.size() >= 2 and float(radii[radii.size() - 1]) - float(radii[0]) < 20.0:
		errors.append("спираль не читается: радиусы слотов почти равны (%.1f..%.1f)" % [radii[0], radii[radii.size() - 1]])

	weapon.call("cleanup_effects")
	await _cleanup(holder)


func _test_mines_pair_random_persistent(errors: Array) -> void:
	var holder := _new_scene("MineScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "engineer_pressure_mines")
	await process_frame

	# Ровно 2 мины за деплой, в кольце 110..260, в РАЗНЫХ точках.
	weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	await process_frame
	var mines := _engineer_devices(holder)
	if mines.size() != 2:
		errors.append("ожидалось ровно 2 мины за деплой, получено %d" % mines.size())
		await _cleanup(holder)
		return
	for mine in mines:
		var distance := owner.global_position.distance_to((mine as Node2D).global_position)
		if distance < 110.0 - EPS or distance > 260.0 + EPS:
			errors.append("мина вне документированного кольца 110..260 (%.1f)" % distance)
	if (mines[0] as Node2D).global_position.distance_to((mines[1] as Node2D).global_position) < 8.0:
		errors.append("мины легли в одну точку — размещение не случайное")

	# Персистентность: 5 сим-секунд без врагов (старый pool-таймер был 3с).
	for _frame in range(300):
		await process_frame
	if _engineer_devices(holder).size() != 2:
		errors.append("мины обязаны лежать без таймера жизни (осталось %d)" % _engineer_devices(holder).size())

	# Игрок на СВЕЖЕЙ мине (возраст < 3с обнуляем принудительно): не подрывает.
	var young_mine: Node2D = _engineer_devices(holder)[0]
	young_mine.call("debug_force_age", 0.0)
	owner.global_position = young_mine.global_position
	for _frame in range(30):
		await process_frame
	if not is_instance_valid(young_mine) or young_mine.is_queued_for_deletion():
		errors.append("свежая мина не должна подрываться под своим игроком (< 3с)")

	# После 3с — самоподрыв тем же касанием.
	if is_instance_valid(young_mine):
		young_mine.call("debug_force_age", 3.1)
		for _frame in range(30):
			await process_frame
		if is_instance_valid(young_mine) and not young_mine.is_queued_for_deletion():
			errors.append("после 3с мина обязана подрываться игроком")

	weapon.call("cleanup_effects")
	await _cleanup(holder)


func _test_mines_triggers_and_cap(errors: Array) -> void:
	var holder := _new_scene("MineTriggerScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "engineer_pressure_mines")
	await process_frame

	# Враг подрывает СВЕЖУЮ мину немедленно (включая первые 3 секунды).
	weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	await process_frame
	var mines := _engineer_devices(holder)
	if mines.size() != 2:
		errors.append("ожидались 2 мины (got %d)" % mines.size())
		await _cleanup(holder)
		return
	var target_mine: Node2D = mines[0]
	# Детерминизм точного урона: вторую мину снимаем (случайное кольцо может
	# положить её в радиус триггера того же врага — сдвоенный взрыв).
	weapon.call("_release_effect", mines[1])
	await process_frame
	var enemy := _new_enemy(holder, target_mine.global_position)
	for _frame in range(20):
		await process_frame
	if is_instance_valid(target_mine) and not target_mine.is_queued_for_deletion():
		errors.append("враг обязан подрывать свежую мину немедленно")
	if enemy.total_damage <= EPS:
		errors.append("взрыв мины не нанёс урона врагу в эпицентре")
	# Урон эпицентра = 100 (damage; mock без крита/сети) — полный, без спада.
	if enemy.total_damage > EPS and absf(enemy.total_damage - 100.0) > 0.5:
		errors.append("урон эпицентра != ~100 (got %.2f)" % enemy.total_damage)
	enemy.queue_free()
	await process_frame

	# Кап 6: три деплоя добивают до 6, четвёртый пропускается (skip, не retire).
	weapon.call("cleanup_effects")
	await process_frame
	for _cast in range(4):
		weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 6:
		errors.append("кап живых мин != 6 (got %d)" % _engineer_devices(holder).size())

	weapon.call("cleanup_effects")
	await process_frame
	if not _engineer_devices(holder).is_empty():
		errors.append("cleanup_effects оставил висячие мины")
	await _cleanup(holder)


func _test_workshop_network_stacks(errors: Array) -> void:
	var holder := _new_scene("NetworkScene")
	var owner := _new_owner(holder)
	owner.engineer_trait = true
	var weapon := _new_weapon(owner, "engineer_pressure_mines")
	await process_frame

	# 4 живые мины x вес 0.5 = 2 стека; кап 3 (Лидерство 0) не задет.
	weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 4:
		errors.append("ожидались 4 мины для стеков (got %d)" % _engineer_devices(holder).size())
	var rolled := float(weapon.call("_rolled_damage", owner))
	if absf(rolled - 100.0 * 1.12) > 0.5:
		errors.append("2 стека сети обязаны дать x1.12 (got %.2f)" % rolled)

	# 6 мин = 3.0 веса; кап 3 (LDR 0) держит стеки: x1.18.
	weapon.call("_fire_engineer_pressure_mines", owner, Vector2.RIGHT)
	await process_frame
	rolled = float(weapon.call("_rolled_damage", owner))
	if absf(rolled - 100.0 * 1.18) > 0.5:
		errors.append("кап сети 3 (LDR 0) обязан дать x1.18 (got %.2f)" % rolled)

	# Лидерство поднимает кап: LDR 12 -> кап 5, но веса всего 3.0 -> тот же x1.18;
	# turret-парк веса 1.0 иллюстрирует рост: 5 турелей при капе 5 -> x1.30.
	owner.stats["leadership"] = 12.0
	rolled = float(weapon.call("_rolled_damage", owner))
	if absf(rolled - 100.0 * 1.18) > 0.5:
		errors.append("рост капа не должен менять фактор при 3.0 веса (got %.2f)" % rolled)
	weapon.call("cleanup_effects")
	await process_frame

	var turret_weapon := _new_weapon(owner, "engineer_sentry_wrench")
	owner.derived_parameters["summon_amount"] = 12.5  # предел парка 5
	await process_frame
	for _cast in range(5):
		turret_weapon.call("_fire_engineer_sentry_link", owner, Vector2.RIGHT)
	await process_frame
	if _engineer_devices(holder).size() != 5:
		errors.append("ожидалось 5 турелей для сети (got %d)" % _engineer_devices(holder).size())
	# 5 турелей, кап 5 (LDR 12): фактор сети 1.30; role-фактор турели при
	# derived leadership 0 = 1.45 (конфиг) x (1 + min(0 + 12.5*0.016, 1.15)).
	var role_factor := 1.45 * (1.0 + minf(12.5 * 0.016, 1.15))
	var expected := 100.0 * role_factor * 1.30
	rolled = float(turret_weapon.call("_rolled_damage", owner))
	if absf(rolled - expected) > 1.0:
		errors.append("5 турелей при капе 5 обязаны дать x1.30 к role-урону (%.2f, ожидалось %.2f)" % [rolled, expected])

	# Утечка запрещена: владелец без trait'а с теми же устройствами — фактор 1.
	owner.engineer_trait = false
	var plain := float(turret_weapon.call("_rolled_damage", owner))
	if absf(plain - 100.0 * role_factor) > 1.0:
		errors.append("сеть протекла классу без trait'а (%.2f, ожидалось %.2f)" % [plain, 100.0 * role_factor])

	turret_weapon.call("cleanup_effects")
	await _cleanup(holder)


# --- helpers ------------------------------------------------------------------


func _new_scene(scene_name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = scene_name
	root.add_child(holder)
	# current_scene нужен _projectile_parent() оружия.
	if current_scene == null:
		current_scene = holder
	return holder


func _new_owner(holder: Node2D, position := Vector2(900, 700)) -> MockOwner:
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = position
	return owner


func _new_weapon(owner: MockOwner, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon("engineer", weapon_id))
	weapon.set_process(false)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.add_to_group("enemies")
	return enemy


func _engineer_devices(holder: Node2D) -> Array[Node2D]:
	var devices: Array[Node2D] = []
	for node in get_nodes_in_group("engineer_devices"):
		var device := node as Node2D
		if device == null or not is_instance_valid(device) or device.is_queued_for_deletion():
			continue
		if holder.is_ancestor_of(device) or device.get_parent() == current_scene or holder == current_scene:
			devices.append(device)
	return devices


func _cleanup(holder: Node2D) -> void:
	if current_scene == holder:
		current_scene = null
	holder.queue_free()
	await process_frame
