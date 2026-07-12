extends SceneTree

# SCRUM-900: focused-тест редизайна кита Доктора (plague-doctor weapon-only sustain).
#   Trait «Клятва чумного доктора» (plague_oath):
#     - generic реген/вампиризм/kill-heal/room-clear/low-HP regen НЕ лечат Доктора
#       (применение наград/меты — no-op по sustain-ключам), но лечат другой класс;
#     - пул level-up/артефактов Доктору их не предлагает;
#     - пометка doctor_friendly пропускает и оффер, и применение (хил работает).
#   Оружие:
#     - restore_potion: магический AoE-взрыв; хил = доля ФАКТИЧЕСКИ нанесённого
#       урона; нет урона — нет хила; физического урона нет;
#     - plague_syringe: долгая чума (20-30с) с медленным ramp'ом тиков,
#       распространением на соседей (шанс, радиус, кап) и хилом от чумного урона;
#     - bone_saw: сектор 120-150° с реальной дальностью, мультихит с диминишем,
#       сильнейший хил кита; вне сектора (фланг/спина) не бьёт и не лечит.
#   Анти-бессмертие: всё оружейное лечение идёт через apply_drain_heal
#   (per-second бюджет SCRUM-517) — проверяем на реальном Player.
#
# Запуск: Godot --headless --path . --script res://tests/doctor_kit_test.gd

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
		"dot_damage": 4.0,
		"dot_speed": 1.0,
		"sector_multiplier": 1.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 50.0
	var max_health := 100.0
	var drain_healed := 0.0

	# Аналог Player.apply_drain_heal без бюджета: копим фактический drain-хил,
	# чтобы проверять «лечение только через drain-канал» и его пропорции.
	func apply_drain_heal(amount: float) -> float:
		drain_healed += amount
		health = minf(health + amount, max_health)
		return amount

	func class_trait_value(_key: String, default_value := 0.0) -> float:
		return default_value


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1


func _initialize() -> void:
	seed(20260900)
	var errors: Array = []
	# Дешёвые data-гейты первыми (FAIL fast), потом live-механика.
	_test_trait_registry_and_configs(errors)
	_test_reward_pools_filtered(errors)
	await _test_trait_runtime_on_player(errors)
	await _test_restore_potion_aoe_heal(errors)
	await _test_restore_potion_splash_cap(errors)
	await _test_plague_infection_ramp_spread_cap(errors)
	await _test_saw_sector_geometry_and_heal(errors)
	await _test_drain_budget_caps_weapon_heal(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Doctor kit (SCRUM-900): %s" % str(error))
		push_error("Doctor kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Doctor kit test passed (SCRUM-900: plague_oath trait, potion AoE heal, plague spread, saw sector).")
	quit(0)


# --- data-гейты ---------------------------------------------------------------


func _test_trait_registry_and_configs(errors: Array) -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("doctor", {})
	if str(trait_config.get("id", "")) != "plague_oath":
		errors.append("CLASS_TRAITS.doctor.id != plague_oath")
	if float(trait_config.get("generic_sustain_blocked", 0.0)) <= 0.0:
		errors.append("CLASS_TRAITS.doctor.generic_sustain_blocked должен быть > 0")
	if not PD.class_blocks_generic_sustain("doctor"):
		errors.append("class_blocks_generic_sustain(doctor) != true")
	if PD.class_blocks_generic_sustain("ranger"):
		errors.append("trait утёк: class_blocks_generic_sustain(ranger) == true")

	# Реестр режимов: новые executor'ы зарегистрированы.
	for mode in ["plague_dart", "saw_sector"]:
		if not ClassWeapon.has_attack_mode_executor(mode):
			errors.append("attack_mode '%s' не зарегистрирован в ClassWeapon" % mode)

	var potion: Dictionary = PD.weapon("doctor", "restore_potion")
	var syringe: Dictionary = PD.weapon("doctor", "plague_syringe")
	var saw: Dictionary = PD.weapon("doctor", "bone_saw")

	# Restore Potion: магический AoE-бросок, никакой физики.
	if str(potion.get("attack_mode", "")) != "aoe_projectile":
		errors.append("restore_potion.attack_mode != aoe_projectile")
	if str(potion.get("damage_parameter", "")) != "magic_damage":
		errors.append("restore_potion должен бить magic_damage (AC: без физического урона)")

	# Plague Syringe: чумной дротик с коридорами тикета.
	if str(syringe.get("attack_mode", "")) != "plague_dart":
		errors.append("plague_syringe.attack_mode != plague_dart")
	if str(syringe.get("damage_parameter", "")) != "magic_damage":
		errors.append("plague_syringe должен скейлиться от magic_damage")
	var duration := float(syringe.get("plague_duration", 0.0))
	if duration < 20.0 or duration > 30.0:
		errors.append("plague_duration %.1f вне целевого коридора 20-30с" % duration)
	var spread_chance := float(syringe.get("plague_spread_chance", 0.0))
	if spread_chance <= 0.0 or spread_chance > 0.5:
		errors.append("plague_spread_chance %.2f вне (0, 0.5] — spread обязан быть ограниченным" % spread_chance)
	if int(syringe.get("plague_max_infected", 0)) <= 0:
		errors.append("plague_max_infected должен ограничивать одновременные заразы")
	if float(syringe.get("plague_spread_radius", 0.0)) <= 0.0:
		errors.append("plague_spread_radius должен быть > 0")

	# Bone Saw: сектор 120-150, физика (скейл от атак-статов), мультихит.
	if str(saw.get("attack_mode", "")) != "saw_sector":
		errors.append("bone_saw.attack_mode != saw_sector")
	if str(saw.get("damage_parameter", "")) != "damage":
		errors.append("bone_saw должен скейлиться от физического damage")
	var cone := float(saw.get("cone_degrees", 0.0))
	if cone < 120.0 or cone > 150.0:
		errors.append("bone_saw cone_degrees %.0f вне AC-коридора 120-150" % cone)
	if float(saw.get("attack_range", 0.0)) < 180.0:
		errors.append("bone_saw attack_range %.0f — сектор должен иметь ощутимую дальность" % float(saw.get("attack_range", 0.0)))

	# Иерархия сустейна: пила сильнейшая, чума слабее зелья.
	var saw_heal := float(saw.get("heal_percent_of_damage", 0.0))
	var potion_heal := float(potion.get("heal_percent_of_damage", 0.0))
	var syringe_heal := float(syringe.get("heal_percent_of_damage", 0.0))
	if not (saw_heal > potion_heal and potion_heal > syringe_heal and syringe_heal > 0.0):
		errors.append("иерархия хила нарушена: saw %.2f > potion %.2f > syringe %.2f > 0 не выполняется" % [saw_heal, potion_heal, syringe_heal])

	# Бюджетный тюнинг не упирается в клампы (кит честно вписан в целевые DPS).
	for pair in [["restore_potion", potion], ["plague_syringe", syringe], ["bone_saw", saw]]:
		var mult := float((pair[1] as Dictionary).get("budget_damage_multiplier", 0.0))
		if mult <= 0.281 or mult >= 2.799:
			errors.append("%s: budget_damage_multiplier %.3f упёрся в кламп — база разбалансирована" % [str(pair[0]), mult])


func _test_reward_pools_filtered(errors: Array) -> void:
	# Level-up пул Доктора: без regen/vampirism-апгрейдов; у другого класса есть.
	var doctor_attrs := {}
	for reward in PD.level_up_rewards("doctor"):
		doctor_attrs[str((reward as Dictionary).get("attr", ""))] = true
	for forbidden_attr in ["regeneration", "vampiric"]:
		if doctor_attrs.has(forbidden_attr):
			errors.append("level-up пул Доктора предлагает '%s'" % forbidden_attr)
	var ranger_attrs := {}
	for reward in PD.level_up_rewards("ranger"):
		ranger_attrs[str((reward as Dictionary).get("attr", ""))] = true
	if not ranger_attrs.has("regeneration"):
		errors.append("контроль: level-up пул Рейнджера должен содержать regeneration")

	# Пул артефактов Доктора: ни одного запрещённого sustain-предмета/мода.
	for offer in PD.reward_pool("doctor"):
		var offer_dict: Dictionary = offer
		var offer_id := str(offer_dict.get("id", ""))
		if PD.DOCTOR_FORBIDDEN_SUSTAIN_REWARD_IDS.has(offer_id):
			errors.append("пул артефактов Доктора содержит запрещённый '%s'" % offer_id)
		for key in (offer_dict.get("mods", {}) as Dictionary).keys():
			if PD.is_blocked_sustain_mod_key(str(key)):
				errors.append("пул Доктора: '%s' несёт запрещённый мод '%s'" % [offer_id, str(key)])
		if offer_dict.has("heal_percent"):
			errors.append("пул Доктора: '%s' несёт прямой heal_percent" % offer_id)

	# doctor_friendly пропускает и запрещённые по содержимому награды.
	var friendly_reward := {"id": "test_doctor_tonic", "doctor_friendly": true, "mods": {"regeneration_flat": 1.0}}
	if not PD.is_reward_relevant(friendly_reward, "doctor"):
		errors.append("doctor_friendly награда не прошла is_reward_relevant для Доктора")
	var plain_reward := {"id": "test_plain_regen", "mods": {"regeneration_flat": 1.0}}
	if PD.is_reward_relevant(plain_reward, "doctor"):
		errors.append("не-friendly regen-награда прошла фильтр пула Доктора")
	if not PD.is_reward_relevant(plain_reward, "ranger"):
		errors.append("контроль: regen-награда должна проходить для Рейнджера")


# --- trait на реальном Player ---------------------------------------------------


func _spawn_player(character_id: String) -> Node:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.call("configure_character", character_id)
	return player


func _test_trait_runtime_on_player(errors: Array) -> void:
	var doctor := _spawn_player("doctor")
	var ranger := _spawn_player("ranger")
	await process_frame

	# 1) Реген: базовый пассивный реген Доктора отрезан, наградной regen — no-op.
	var regen_reward := {"id": "test_regen", "mods": {"regeneration_flat": 2.6}}
	doctor.call("apply_reward", regen_reward)
	ranger.call("apply_reward", regen_reward)
	if float((doctor.get("run_modifiers") as Dictionary).get("regeneration_flat", 0.0)) > EPS:
		errors.append("regen-мод применился к Доктору (должен быть no-op)")
	if float((ranger.get("run_modifiers") as Dictionary).get("regeneration_flat", 0.0)) <= EPS:
		errors.append("контроль: regen-мод не применился к Рейнджеру")
	if float((doctor.get("derived_parameters") as Dictionary).get("regeneration", 0.0)) > EPS:
		errors.append("derived regeneration Доктора > 0 после regen-награды")
	doctor.set("health", float(doctor.get("max_health")) * 0.5)
	ranger.set("health", float(ranger.get("max_health")) * 0.5)
	var doctor_hp_before := float(doctor.get("health"))
	var ranger_hp_before := float(ranger.get("health"))
	doctor.call("_apply_regeneration", 2.0)
	ranger.call("_apply_regeneration", 2.0)
	if float(doctor.get("health")) > doctor_hp_before + EPS:
		errors.append("Доктор вылечился пассивным регеном (%.3f -> %.3f)" % [doctor_hp_before, float(doctor.get("health"))])
	if float(ranger.get("health")) <= ranger_hp_before + EPS:
		errors.append("контроль: Рейнджер не вылечился регеном")

	# 2) Вампиризм: наградные vampiric-моды — no-op, on_weapon_hit не лечит.
	var vamp_reward := {"id": "test_vamp", "mods": {"vampiric_chance_flat": 1.0, "vampiric_amount_flat": 5.0, "vampiric_heal_per_second_cap": 5.0}}
	doctor.call("apply_reward", vamp_reward)
	ranger.call("apply_reward", vamp_reward)
	if float((doctor.get("run_modifiers") as Dictionary).get("vampiric_chance_flat", 0.0)) > EPS:
		errors.append("vampiric-мод применился к Доктору (должен быть no-op)")
	if float((doctor.get("derived_parameters") as Dictionary).get("vampiric_chance", 0.0)) > EPS:
		errors.append("derived vampiric_chance Доктора > 0")
	var enemy := MockEnemy.new()
	root.add_child(enemy)
	doctor.call("_apply_regeneration", 2.0)  # пополнить вампирный бюджет (если бы он был нужен)
	ranger.call("_apply_regeneration", 2.0)
	doctor_hp_before = float(doctor.get("health"))
	ranger_hp_before = float(ranger.get("health"))
	for hit_index in range(12):
		doctor.call("on_weapon_hit", enemy, 60.0, false, {})
		ranger.call("on_weapon_hit", enemy, 60.0, false, {})
	if float(doctor.get("health")) > doctor_hp_before + EPS:
		errors.append("Доктор вылечился вампиризмом на ударе")
	if float(ranger.get("health")) <= ranger_hp_before + EPS:
		errors.append("контроль: Рейнджер не вылечился вампиризмом (chance 1.0)")

	# 3) Триггерный сустейн: kill-heal / room-clear / kill-streak — no-op ключи.
	var trigger_reward := {"id": "test_triggers", "mods": {"kill_heal_percent": 0.05, "room_clear_heal_percent": 0.10, "kill_streak_heal_every": 3.0}}
	doctor.call("apply_reward", trigger_reward)
	ranger.call("apply_reward", trigger_reward)
	var doctor_mods: Dictionary = doctor.get("run_modifiers")
	for blocked_key in ["kill_heal_percent", "room_clear_heal_percent", "kill_streak_heal_every"]:
		if float(doctor_mods.get(blocked_key, 0.0)) > EPS:
			errors.append("триггерный sustain-ключ '%s' применился к Доктору" % blocked_key)
	if float((ranger.get("run_modifiers") as Dictionary).get("kill_heal_percent", 0.0)) <= EPS:
		errors.append("контроль: kill_heal_percent не применился к Рейнджеру")

	# 4) Low-HP реген («Второе Дыхание»): рантайм-страховка не лечит Доктора.
	(doctor.get("run_modifiers") as Dictionary)["lowhp_regen_bonus"] = 6.0
	(ranger.get("run_modifiers") as Dictionary)["lowhp_regen_bonus"] = 6.0
	doctor.set("health", float(doctor.get("max_health")) * 0.2)
	ranger.set("health", float(ranger.get("max_health")) * 0.2)
	doctor.call("_update_low_hp_state")
	ranger.call("_update_low_hp_state")
	doctor_hp_before = float(doctor.get("health"))
	ranger_hp_before = float(ranger.get("health"))
	doctor.call("_apply_regeneration", 1.0)
	ranger.call("_apply_regeneration", 1.0)
	if float(doctor.get("health")) > doctor_hp_before + EPS:
		errors.append("Доктор вылечился low-HP регеном")
	if float(ranger.get("health")) <= ranger_hp_before + EPS:
		errors.append("контроль: Рейнджер не вылечился low-HP регеном")

	# 5) Мета-дерево: regen/vampiric звёзды — no-op для Доктора.
	doctor.call("apply_meta_skill_modifiers", {"regeneration_flat": 2.0, "vampiric_chance_flat": 0.5})
	doctor_mods = doctor.get("run_modifiers")
	if float(doctor_mods.get("regeneration_flat", 0.0)) > EPS or float(doctor_mods.get("vampiric_chance_flat", 0.0)) > EPS:
		errors.append("мета-звёзды сустейна применились к Доктору")

	# 6) Прямой heal_percent награды: гасится, doctor_friendly — проходит.
	doctor.set("health", float(doctor.get("max_health")) * 0.3)
	doctor_hp_before = float(doctor.get("health"))
	doctor.call("apply_reward", {"id": "test_heal", "heal_percent": 0.5})
	if float(doctor.get("health")) > doctor_hp_before + EPS:
		errors.append("heal_percent награды вылечил Доктора")

	# 7) doctor_friendly предмет: моды применяются, реген работает штатно.
	doctor.call("apply_reward", {"id": "test_tonic", "doctor_friendly": true, "mods": {"regeneration_flat": 2.6}})
	if float((doctor.get("run_modifiers") as Dictionary).get("regeneration_flat", 0.0)) <= EPS:
		errors.append("doctor_friendly regen-мод не применился к Доктору")
	if float((doctor.get("derived_parameters") as Dictionary).get("regeneration", 0.0)) <= EPS:
		errors.append("derived regeneration Доктора == 0 после doctor_friendly регена")
	doctor.set("health", float(doctor.get("max_health")) * 0.5)
	doctor_hp_before = float(doctor.get("health"))
	doctor.call("_apply_regeneration", 2.0)
	if float(doctor.get("health")) <= doctor_hp_before + EPS:
		errors.append("doctor_friendly реген не вылечил Доктора")

	enemy.queue_free()
	doctor.queue_free()
	ranger.queue_free()
	await process_frame


# --- оружие -------------------------------------------------------------------


func _new_scene(name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	root.add_child(holder)
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
	weapon.configure_weapon(PD.weapon("doctor", weapon_id))
	weapon.set_process(false)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.add_to_group("enemies")
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	await process_frame


func _test_restore_potion_aoe_heal(errors: Array) -> void:
	var holder := _new_scene("PotionScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "restore_potion")
	var near := _new_enemy(holder, owner.global_position + Vector2(300, 0))
	var near_second := _new_enemy(holder, owner.global_position + Vector2(340, 40))
	var far := _new_enemy(holder, owner.global_position + Vector2(300, 900))
	await process_frame

	# Взрыв по точке: урон только целям в радиусе, хил = доля нанесённого.
	weapon.call("_damage_aoe_projectile_explosion", near.global_position, weapon.aoe_radius, 100.0)
	await process_frame
	if near.total_damage <= EPS or near_second.total_damage <= EPS:
		errors.append("зелье: взрыв не задел цели в радиусе")
	if far.total_damage > EPS:
		errors.append("зелье: взрыв задел цель вне радиуса")
	var dealt := near.total_damage + near_second.total_damage
	var expected_heal := dealt * 0.16 * PD.WEAPON_DRAIN_HEAL_MULTIPLIER
	if absf(owner.drain_healed - expected_heal) > maxf(expected_heal * 0.02, 0.05):
		errors.append("зелье: хил %.2f != %.2f (16%% от фактического урона %.1f через drain-канал)" % [owner.drain_healed, expected_heal, dealt])

	# Нет нанесённого урона (пустая зона) — нет лечения.
	var healed_before := owner.drain_healed
	weapon.call("_damage_aoe_projectile_explosion", owner.global_position + Vector2(-2000, -2000), weapon.aoe_radius, 100.0)
	await process_frame
	if owner.drain_healed > healed_before + EPS:
		errors.append("зелье: хил без нанесённого урона (промах должен лечить на 0)")
	await _cleanup(holder)


# FAN-1031 S3 (Stage 3a): хил-склянка возвращена в сустейн/solo-нишу. Baseline v2:
# restore_potion 68.9k DPS@20t = #3 AoE-оружие ростера (для лечащего оружия — дефект).
# Правка — data-driven кап прямого AoE (S1): aoe_full_targets=1, aoe_target_diminish=4.0
# → осн. цель получает полный урон/хил, сплэш круто спадает. Тест A/B на живой
# _damage_enemies_in_circle_capped: override vs default. 1t solo не тронут (rank0=full).
func _test_restore_potion_splash_cap(errors: Array) -> void:
	var holder := _new_scene("PotionSplashScene")
	var owner := _new_owner(holder)

	# Цели по лучу с растущим удалением от точки взрыва (все в aoe_radius=150),
	# ранг = удалённость: rank0 полный, дальше диминиш.
	var origin := owner.global_position + Vector2(300, 0)
	var ranks: Array = []
	for k in range(4):
		ranks.append(_new_enemy(holder, origin + Vector2(float(k) * 25.0, 0.0)))
	await process_frame

	# A. restore_potion (override F=1, D=4): 2-я цель уже срезана, не полная.
	var weapon := _new_weapon(owner, "restore_potion")
	if weapon.aoe_full_targets != 1 or absf(weapon.aoe_target_diminish - 4.0) > EPS:
		errors.append("зелье-сплэш: конфиг не загрузился (aoe_full_targets=%d, aoe_target_diminish=%.2f; ждали 1 / 4.0) — silent-retune?" % [weapon.aoe_full_targets, weapon.aoe_target_diminish])
	weapon.call("_damage_aoe_projectile_explosion", origin, weapon.aoe_radius, 100.0)
	await process_frame
	var d0: float = ranks[0].total_damage
	var d1: float = ranks[1].total_damage
	var d2: float = ranks[2].total_damage
	if absf(d0 - 100.0) > 0.5:
		errors.append("зелье-сплэш: осн. цель %.1f != 100 (rank0 обязан быть полным — solo-хил не должен страдать)" % d0)
	# rank1 = 100 / (1 + 1*4) = 20; rank2 = 100 / (1 + 2*4) = 11.11.
	if absf(d1 - 20.0) > 0.5:
		errors.append("зелье-сплэш: 2-я цель %.1f != 20 (кап F=1/D=4 не сработал — сплэш всё ещё бьёт как F=5)" % d1)
	if d1 >= d0 * 0.5:
		errors.append("зелье-сплэш: сплэш не круто спадает (2-я %.1f >= 50%% осн. %.1f)" % [d1, d0])
	if absf(d2 - 100.0 / 9.0) > 0.5:
		errors.append("зелье-сплэш: 3-я цель %.1f != 11.1 (диминиш формулы нарушен)" % d2)

	# B. Контроль — тот же конфиг БЕЗ override: default F=5 → 2-я цель полная.
	var control_owner := _new_owner(holder, owner.global_position + Vector2(0, 600))
	var control_origin := control_owner.global_position + Vector2(300, 0)
	var control_ranks: Array = []
	for k in range(4):
		control_ranks.append(_new_enemy(holder, control_origin + Vector2(float(k) * 25.0, 0.0)))
	await process_frame
	var default_cfg: Dictionary = PD.weapon("doctor", "restore_potion").duplicate(true)
	default_cfg.erase("aoe_full_targets")
	default_cfg.erase("aoe_target_diminish")
	var control := ClassWeapon.new()
	control_owner.add_child(control)
	control.configure_weapon(default_cfg)
	control.set_process(false)
	control.call("_damage_aoe_projectile_explosion", control_origin, control.aoe_radius, 100.0)
	await process_frame
	if absf(float(control_ranks[1].total_damage) - 100.0) > 0.5:
		errors.append("зелье-сплэш(контроль): без override 2-я цель %.1f != 100 — сентинел-механика data-driven капа не работает" % float(control_ranks[1].total_damage))

	await _cleanup(holder)


func _test_plague_infection_ramp_spread_cap(errors: Array) -> void:
	var holder := _new_scene("PlagueScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "plague_syringe")
	var host := _new_enemy(holder, owner.global_position + Vector2(320, 0))
	var neighbor := _new_enemy(holder, owner.global_position + Vector2(320, 120))
	var outsider := _new_enemy(holder, owner.global_position + Vector2(320, 1400))
	await process_frame

	# Профиль чумы: длительность в коридоре 20-30с, ramp поднимается до 1.0.
	var profile: Dictionary = PD.plague_tick_profile({
		"plague_duration": weapon.plague_duration,
		"plague_tick_interval": weapon.plague_tick_interval,
		"plague_tick_ratio": weapon.plague_tick_ratio,
		"plague_dot_coupling": weapon.plague_dot_coupling,
		"plague_ramp_ticks": weapon.plague_ramp_ticks,
	}, owner.derived_parameters)
	var total_seconds := float(profile.get("ticks", 0)) * float(profile.get("tick_interval", 0.0))
	if total_seconds < 20.0 - EPS or total_seconds > 30.0 + EPS:
		errors.append("чума: фактическая длительность %.1fс вне 20-30с" % total_seconds)
	if PD.plague_ramp_factor(0, weapon.plague_ramp_ticks) >= PD.plague_ramp_factor(weapon.plague_ramp_ticks, weapon.plague_ramp_ticks) - EPS:
		errors.append("чума: ramp не растёт от первого тика к зрелому")

	# Заражение: регистрация в реестре, рефреш без дублей.
	weapon.set("plague_spread_chance", 0.0)  # изолируем спред для первых проверок
	weapon.call("_apply_plague_infection", host, owner)
	var registry: Dictionary = weapon.get("_plague_tweens")
	if registry.size() != 1:
		errors.append("чума: после заражения в реестре %d записей (ждали 1)" % registry.size())
	weapon.call("_apply_plague_infection", host, owner)
	registry = weapon.get("_plague_tweens")
	if registry.size() != 1:
		errors.append("чума: повторное заражение продублировало запись (%d)" % registry.size())

	# Тики: урон ramp'ится (зрелый тик сильнее первого), хил = доля тика.
	var damage_before := host.total_damage
	weapon.call("_plague_tick", host.get_instance_id(), owner.get_instance_id(), 0)
	var early_tick := host.total_damage - damage_before
	var healed_before := owner.drain_healed
	damage_before = host.total_damage
	weapon.call("_plague_tick", host.get_instance_id(), owner.get_instance_id(), weapon.plague_ramp_ticks)
	var mature_tick := host.total_damage - damage_before
	if early_tick <= EPS or mature_tick <= EPS:
		errors.append("чума: тик не нанёс урона (early %.2f, mature %.2f)" % [early_tick, mature_tick])
	if early_tick >= mature_tick - EPS:
		errors.append("чума: ранний тик %.2f не слабее зрелого %.2f (ramp обязателен)" % [early_tick, mature_tick])
	var tick_heal := owner.drain_healed - healed_before
	var expected_tick_heal := mature_tick * 0.12 * PD.WEAPON_DRAIN_HEAL_MULTIPLIER
	if absf(tick_heal - expected_tick_heal) > maxf(expected_tick_heal * 0.02, 0.02):
		errors.append("чума: хил тика %.3f != %.3f (12%% чумного урона)" % [tick_heal, expected_tick_heal])

	# Спред: с шансом 1.0 тик заражает ближайшего соседа; дальний вне радиуса цел.
	weapon.set("plague_spread_chance", 1.0)
	weapon.call("_plague_tick", host.get_instance_id(), owner.get_instance_id(), 1)
	await process_frame
	registry = weapon.get("_plague_tweens")
	if not registry.has(neighbor.get_instance_id()):
		errors.append("чума: спред с шансом 1.0 не заразил соседа в радиусе")
	if registry.has(outsider.get_instance_id()):
		errors.append("чума: спред заразил цель вне spread-радиуса")

	# Кап одновременных зараз: сверх plague_max_infected заражение не создаётся.
	weapon.set("plague_max_infected", 2)
	var extra := _new_enemy(holder, owner.global_position + Vector2(200, -80))
	await process_frame
	weapon.call("_apply_plague_infection", extra, owner)
	registry = weapon.get("_plague_tweens")
	if registry.size() > 2:
		errors.append("чума: кап max_infected=2 нарушен (%d зараз)" % registry.size())

	# Спред-ролл при нулевом шансе не срабатывает (bounded probability).
	weapon.set("plague_max_infected", 10)
	weapon.set("plague_spread_chance", 0.0)
	var registry_size_before: int = (weapon.get("_plague_tweens") as Dictionary).size()
	for tick_index in range(10):
		weapon.call("_plague_tick", host.get_instance_id(), owner.get_instance_id(), tick_index)
	registry = weapon.get("_plague_tweens")
	if registry.size() != registry_size_before:
		errors.append("чума: спред сработал при шансе 0.0")
	weapon.call("cleanup_effects")
	registry = weapon.get("_plague_tweens")
	if not registry.is_empty():
		errors.append("чума: cleanup_effects не погасил реестр зараз")
	await _cleanup(holder)


func _test_saw_sector_geometry_and_heal(errors: Array) -> void:
	var holder := _new_scene("SawScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "bone_saw")
	# 135° сектор вправо: half-angle 67.5°. Цели за пределами melee_close (110),
	# чтобы не подмешивать close-bonus в пропорции хила.
	var front := _new_enemy(holder, owner.global_position + Vector2(180, 0))          # 0° — в секторе
	var edge := _new_enemy(holder, owner.global_position + Vector2(140, 120))         # ~40.6° — в секторе
	var flank := _new_enemy(holder, owner.global_position + Vector2(30, 170))         # ~80° — вне сектора
	var behind := _new_enemy(holder, owner.global_position + Vector2(-160, 0))        # 180° — за спиной
	var beyond := _new_enemy(holder, owner.global_position + Vector2(400, 0))         # дальше attack_range
	await process_frame

	weapon.call("_fire_saw_sector", owner, Vector2.RIGHT)
	await process_frame
	if front.total_damage <= EPS or edge.total_damage <= EPS:
		errors.append("пила: цели в секторе 135° не получили урона")
	if flank.total_damage > EPS:
		errors.append("пила: задет фланг вне сектора (~80° при half-angle 67.5°)")
	if behind.total_damage > EPS:
		errors.append("пила: задета цель за спиной — позиционный риск сломан")
	if beyond.total_damage > EPS:
		errors.append("пила: задета цель дальше attack_range")

	# Хил: 34% от суммарного фактического урона, строго через drain-канал.
	var dealt := front.total_damage + edge.total_damage
	var expected_heal := dealt * 0.34 * PD.WEAPON_DRAIN_HEAL_MULTIPLIER
	if absf(owner.drain_healed - expected_heal) > maxf(expected_heal * 0.02, 0.05):
		errors.append("пила: хил %.2f != %.2f (34%% от урона %.1f)" % [owner.drain_healed, expected_heal, dealt])

	# Иерархия сустейна live: на одинаковом уроне пила лечит больше зелья и чумы.
	var potion_ratio := 0.16 * PD.WEAPON_DRAIN_HEAL_MULTIPLIER
	var syringe_ratio := 0.12 * PD.WEAPON_DRAIN_HEAL_MULTIPLIER
	var saw_ratio := owner.drain_healed / maxf(dealt, EPS)
	if not (saw_ratio > potion_ratio + EPS and potion_ratio > syringe_ratio + EPS):
		errors.append("иерархия live-хила нарушена: saw %.3f, potion %.3f, syringe %.3f" % [saw_ratio, potion_ratio, syringe_ratio])

	# Диминиш толпы: 6 целей во фронте — дальние сверх sector_full_targets слабее.
	var crowd_holder := _new_scene("SawCrowd")
	var crowd_owner := _new_owner(crowd_holder)
	var crowd_weapon := _new_weapon(crowd_owner, "bone_saw")
	var crowd: Array = []
	for crowd_index in range(6):
		crowd.append(_new_enemy(crowd_holder, crowd_owner.global_position + Vector2(120.0 + 15.0 * float(crowd_index), 0)))
	await process_frame
	crowd_weapon.call("_fire_saw_sector", crowd_owner, Vector2.RIGHT)
	await process_frame
	var nearest_hit := (crowd[0] as MockEnemy).total_damage
	var farthest_hit := (crowd[5] as MockEnemy).total_damage
	if farthest_hit <= EPS:
		errors.append("пила: 6-я цель сектора не задета (мультихит обязан покрывать толпу)")
	elif farthest_hit >= nearest_hit - EPS:
		errors.append("пила: нет диминиша сверх sector_full_targets (ближний %.1f, 6-й %.1f)" % [nearest_hit, farthest_hit])
	await _cleanup(crowd_holder)
	await _cleanup(holder)


func _test_drain_budget_caps_weapon_heal(errors: Array) -> void:
	# Анти-бессмертие: на реальном Player весь оружейный хил Доктора проходит
	# через apply_drain_heal с per-second бюджетом (SCRUM-517) — залповое
	# лечение сверх бюджета не проходит.
	var doctor := _spawn_player("doctor")
	await process_frame
	doctor.set("health", float(doctor.get("max_health")) * 0.2)
	doctor.set("_drain_heal_budget", 7.0)
	var healed_first := float(doctor.call("apply_drain_heal", 1000.0))
	var healed_second := float(doctor.call("apply_drain_heal", 1000.0))
	if healed_first <= EPS:
		errors.append("drain-канал Доктора не лечит вовсе (бюджет 7.0)")
	if healed_first > 7.0 * 2.0 + EPS:
		errors.append("drain-хил %.1f превысил разумный потолок бюджета 7.0 (healing_mult учтён)" % healed_first)
	if healed_second > EPS:
		errors.append("drain-хил сверх исчерпанного per-second бюджета: %.2f (бессмертие в толпе)" % healed_second)
	doctor.queue_free()
	await process_frame
