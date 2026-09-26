extends SceneTree

# SCRUM-896/1005: фокусный тест кита Биолога.
#
#   SCRUM-896 biologist_spore_lens (bio_spore_bloom):
#     - ЛОКАЛЬНОСТЬ: стартовый attack_range резко срезан (данные ≤260); враг на
#       дистанции старого радиуса (560) не задевается даже максимальным кольцом;
#     - три кольца с falloff по прогрессии пульсов; задетые получают
#       bio_spore_slow (refresh, 1 стак — в перманентный рут не стакуется) и
#       bio_infection с source_id владельца;
#     - сила замедления: ~5% на lvl1-базе, растёт с эффективным magic_damage,
#       жёсткий кап 20% (не пробивается дальнейшим ростом урона).
#   SCRUM-896 biologist_sample_injector (bio_sample_dart):
#     - пирсинг-луч: ВСЕ враги на длине луча получают полный маг.ролл + физ.долю
#       INJECTOR_PHYSICAL_SHARE канала damage (гибрид); стоящие между Биологом
#       и целью страдают, стоящие сбоку от луча — нет;
#     - на конце луча малый бурст анализа (tip_burst_ratio, радиус << Линзы);
#     - пробу-инфекцию получает ТОЛЬКО ближайший на луче.
#   SCRUM-896 biologist_symbiote_seed (bio_symbiote_web):
#     - самое дальнобойное оружие кита (данные); урон ОТЛОЖЕН до прорастания
#       (grenade_delay), затем стартовый маг.хит seed_impact_ratio с falloff;
#     - все задетые заражаются; суммарный DoT инфекции строго БОЛЬШЕ стартового
#       хита (главный пейофф — со временем);
#     - радиус области между бурстом Инъектора и кольцами Линзы (данные).
#   SCRUM-1005 trait «Разбор образцов» (CLASS_TRAITS.biologist):
#     - прямой хит по цели под СВОИМ DoT = ровно ×1.20; по чистой цели — базовый;
#     - тики DoT НЕ усиливаются трейтом;
#     - чужой DoT (другой владелец / статус без source_id) бонуса не даёт;
#     - после истечения инфекции бонус не протекает;
#     - у другого класса (soldier) бонуса нет даже по заражённой цели.
#
# Запуск: Godot --headless --path . --script res://tests/biologist_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.01


class MockOwner extends CharacterBody2D:
	var character_id := "biologist"
	var derived_parameters := {
		"damage": 40.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 10.0,
		"dot_speed": 1.0,
	}
	var run_modifiers := {}
	var stats := {}

	# Зеркало generic-хука Player.class_trait_value (SCRUM-935): trait читается
	# из канонического реестра CLASS_TRAITS по классу владельца.
	func class_trait_value(key: String, default_value := 0.0) -> float:
		var trait_config: Dictionary = PD.CLASS_TRAITS.get(character_id, {})
		return float(trait_config.get(key, default_value))


# Feedback-capable мок (группа enemies + _show_combat_feedback => оружие шлёт
# take_damage(amount, feedback), и тест видит тип/атрибуцию каждого хита).
class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0
	var hits: Array = []

	func take_damage(amount: float, feedback := {}) -> void:
		total_damage += amount
		hit_count += 1
		hits.append({"amount": amount, "feedback": (feedback if feedback is Dictionary else {}).duplicate(true)})

	func _show_combat_feedback(_amount: float, _feedback: Dictionary) -> void:
		pass

	func hits_of_type(damage_type: String) -> int:
		var count := 0
		for hit in hits:
			if str((hit["feedback"] as Dictionary).get("damage_type", "")) == damage_type:
				count += 1
		return count

	func damage_of_type(damage_type: String) -> float:
		var total := 0.0
		for hit in hits:
			if str((hit["feedback"] as Dictionary).get("damage_type", "")) == damage_type:
				total += float(hit["amount"])
		return total


func _initialize() -> void:
	var errors: Array = []
	_test_kit_data_shape(errors)
	await _test_lens_locality_and_rings(errors)
	await _test_lens_slow_progression_and_refresh(errors)
	await _test_injector_pierce_line_and_tip(errors)
	await _test_injector_infection_and_trait_followup(errors)
	await _test_seed_delayed_zone_and_dot_payoff(errors)
	await _test_sample_analysis_trait(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Biologist kit: %s" % str(error))
		push_error("Biologist kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Biologist kit test passed (SCRUM-896/1005).")
	quit(0)


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


func _new_weapon(owner: CharacterBody2D, class_id: String, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon(class_id, weapon_id))
	# Гвоздь от авто-атак: тест стреляет только явными вызовами _fire_*.
	weapon.set_process(false)
	weapon.set("_cooldown", 1.0e9)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _lens_baseline_magic() -> float:
	var baseline: Dictionary = PD.derived_parameters(PD.base_stats("biologist"), {}, PD.weapon("biologist", "biologist_spore_lens"))
	return maxf(float(baseline.get("magic_damage", 1.0)), 0.001)


# --- SCRUM-896: форма данных кита -------------------------------------------


func _test_kit_data_shape(errors: Array) -> void:
	var lens: Dictionary = PD.weapon("biologist", "biologist_spore_lens")
	var injector: Dictionary = PD.weapon("biologist", "biologist_sample_injector")
	var seed: Dictionary = PD.weapon("biologist", "biologist_symbiote_seed")
	# Локальность линзы: стартовый range резко срезан (был 560).
	if float(lens.get("attack_range", 999.0)) > 260.0:
		errors.append("lens attack_range must be sharply reduced to a local radius (<=260), got %.1f" % float(lens.get("attack_range", 0.0)))
	# «Нравящийся» радиус колец сохранён.
	if absf(float(lens.get("aoe_radius", 0.0)) - 210.0) > 5.0:
		errors.append("lens aoe_radius should keep the liked baseline ~210 (got %.1f)" % float(lens.get("aoe_radius", 0.0)))
	# Инъектор — длинный пирсинг-инструмент; семя — самое дальнобойное.
	if float(injector.get("attack_range", 0.0)) < 600.0:
		errors.append("injector must stay the long piercing tool (range >= 600)")
	if float(seed.get("attack_range", 0.0)) < 680.0 or float(seed.get("attack_range", 0.0)) <= float(injector.get("attack_range", 0.0)):
		errors.append("seed must be the highest-range weapon of the kit")
	# Радиусы: бурст Инъектора << Линзы; область Семени строго между ними.
	var tip_radius := float(injector.get("aoe_radius", 0.0))
	var seed_radius := float(seed.get("aoe_radius", 0.0))
	var lens_radius := float(lens.get("aoe_radius", 0.0))
	if not (tip_radius < seed_radius and seed_radius < lens_radius):
		errors.append("aoe ordering must be injector tip < seed zone < lens rings (got %.0f/%.0f/%.0f)" % [tip_radius, seed_radius, lens_radius])
	if tip_radius > lens_radius * 0.6:
		errors.append("injector tip burst must stay much smaller than lens rings (%.0f vs %.0f)" % [tip_radius, lens_radius])
	# Кламп замедления линзы — данные AC: 5% минимум, 20% максимум.
	if absf(float(lens.get("spore_slow_base", 0.0)) - 0.05) > 0.001 or absf(float(lens.get("spore_slow_max", 0.0)) - 0.20) > 0.001:
		errors.append("lens slow clamps must be data-driven 0.05..0.20")
	# Все три оружия заражают (топливо trait'а SCRUM-1005).
	for pair in [["lens", lens], ["injector", injector], ["seed", seed]]:
		if int((pair[1] as Dictionary).get("dot_ticks", 0)) <= 0:
			errors.append("%s must carry dot_ticks > 0 (bio infection fuel)" % str(pair[0]))


# --- SCRUM-896: Споровая Линза ------------------------------------------------


func _test_lens_locality_and_rings(errors: Array) -> void:
	var holder := _new_scene("Scrum896LensLocality")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "biologist", "biologist_spore_lens")
	# База lvl1: замедление должно быть у пола 5%.
	owner.derived_parameters["magic_damage"] = _lens_baseline_magic()
	var near := _new_enemy(holder, owner.global_position + Vector2(150, 0))
	var far := _new_enemy(holder, owner.global_position + Vector2(560, 0))
	await process_frame

	# Полный путь _attack: цель ищется в срезанном attack_range — дальний враг
	# не может быть целью, а кольца физически не дотягиваются до него.
	weapon.call("_attack")
	await create_timer(0.85).timeout

	if near.hit_count < 3:
		errors.append("lens rings must hit the nearby target with all pulses (got %d)" % near.hit_count)
	if far.hit_count != 0:
		errors.append("lens must not reach across the old 560 range at start (far hits %d)" % far.hit_count)
	# Прогрессия колец: полный ролл, затем falloff^index; со 2-го кольца цель
	# уже заражена 1-м => прямые кольца усилены трейтом ×1.2 (SCRUM-1005).
	var roll := float(owner.derived_parameters["magic_damage"])
	var falloff := float(weapon.get("damage_falloff"))
	var trait_multiplier := float(PD.class_trait("biologist").get("infected_direct_hit_multiplier", 1.0))
	var expected := roll + roll * falloff * trait_multiplier + roll * falloff * falloff * trait_multiplier
	var direct_total := near.damage_of_type("magic")
	if absf(direct_total - expected) > 0.5:
		errors.append("lens ring damage must follow falloff+trait progression (got %.2f, want %.2f)" % [direct_total, expected])
	if not StatusEffects.has_status(near, "bio_spore_slow"):
		errors.append("every enemy damaged by lens rings must be slowed")
	if not StatusEffects.has_status(near, "bio_infection"):
		errors.append("lens rings must infect damaged enemies (trait fuel)")
	var infection: Dictionary = StatusEffects.snapshot(near).get("bio_infection", {})
	if int(infection.get("source_id", 0)) != owner.get_instance_id():
		errors.append("lens infection must carry the owner's source_id")
	if StatusEffects.has_status(far, "bio_spore_slow") or StatusEffects.has_status(far, "bio_infection"):
		errors.append("far enemy must not receive lens statuses")
	# Слоу на lvl1-базе — у пола 5% (кап движка не задет).
	var slow_speed := StatusEffects.speed_multiplier(near)
	if absf(slow_speed - 0.95) > 0.015:
		errors.append("baseline lens slow must sit near 5%% (speed factor %.3f, want ~0.95)" % slow_speed)
	await _cleanup(holder)


func _test_lens_slow_progression_and_refresh(errors: Array) -> void:
	var holder := _new_scene("Scrum896LensSlowScale")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "biologist", "biologist_spore_lens")
	var baseline := _lens_baseline_magic()
	var probe := _new_enemy(holder, owner.global_position + Vector2(120, 0))
	await process_frame

	# Прогрессия ×3 базы => кап 20%; дальнейший рост урона кап НЕ пробивает.
	owner.derived_parameters["magic_damage"] = baseline * 3.0
	weapon.call("_apply_bio_spore_slow", owner, probe.global_position, 80.0)
	var capped_speed := StatusEffects.speed_multiplier(probe)
	if absf(capped_speed - 0.80) > 0.015:
		errors.append("lens slow must reach the 20%% cap at ~x3 progression (speed %.3f, want ~0.80)" % capped_speed)
	owner.derived_parameters["magic_damage"] = baseline * 12.0
	weapon.call("_apply_bio_spore_slow", owner, probe.global_position, 80.0)
	var overcap_speed := StatusEffects.speed_multiplier(probe)
	if overcap_speed < 0.80 - 0.015:
		errors.append("lens slow cap must hold against raw damage growth (speed %.3f)" % overcap_speed)
	# Refresh, не стак: повторные применения держат 1 стак и ту же силу.
	var slow_status: Dictionary = StatusEffects.snapshot(probe).get("bio_spore_slow", {})
	if int(slow_status.get("stacks", 0)) != 1:
		errors.append("lens slow must refresh, not stack (stacks %d)" % int(slow_status.get("stacks", 0)))
	await _cleanup(holder)


# --- SCRUM-896: Инъектор Образцов ----------------------------------------------


func _test_injector_pierce_line_and_tip(errors: Array) -> void:
	var holder := _new_scene("Scrum896InjectorLine")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "biologist", "biologist_sample_injector")
	var tip_radius := float(weapon.get("aoe_radius"))
	# Цель на 600; враги МЕЖДУ Биологом и целью; сбоку от луча; сосед бурста.
	var target := _new_enemy(holder, owner.global_position + Vector2(600, 0))
	var mid_close := _new_enemy(holder, owner.global_position + Vector2(200, 0))
	var mid_far := _new_enemy(holder, owner.global_position + Vector2(400, 0))
	var side := _new_enemy(holder, owner.global_position + Vector2(300, 60))
	var tip_neighbor := _new_enemy(holder, owner.global_position + Vector2(600, tip_radius * 0.5))
	await process_frame

	weapon.call("_fire_bio_sample_dart", owner, target, Vector2.RIGHT)
	await create_timer(0.25).timeout

	var roll := 100.0
	var physical_share := float(owner.derived_parameters["damage"]) * ClassWeapon.INJECTOR_PHYSICAL_SHARE
	# Луч: полный маг.ролл + физ.доля КАЖДОМУ на линии (гибрид).
	for pair in [["mid_close", mid_close], ["mid_far", mid_far]]:
		var line_enemy := pair[1] as MockEnemy
		if line_enemy.hits_of_type("magic") != 1 or absf(line_enemy.damage_of_type("magic") - roll) > 0.5:
			errors.append("%s must take one full magic line hit (got %.2f)" % [str(pair[0]), line_enemy.damage_of_type("magic")])
		if line_enemy.hits_of_type("physical") != 1 or absf(line_enemy.damage_of_type("physical") - physical_share) > 0.5:
			errors.append("%s must take the hybrid physical share (got %.2f, want %.2f)" % [str(pair[0]), line_enemy.damage_of_type("physical"), physical_share])
	# Цель на конце: луч + бурст анализа в центре бурста (полный tip-ролл).
	var tip_ratio := float(weapon.get("tip_burst_ratio"))
	var expected_target := roll + roll * tip_ratio
	if absf(target.damage_of_type("magic") - expected_target) > 0.5:
		errors.append("target must take line hit + tip burst (got %.2f, want %.2f)" % [target.damage_of_type("magic"), expected_target])
	# Сбоку от луча — нетронут (узкий пирсинг, не полоса экрана).
	if side.hit_count != 0:
		errors.append("enemy beside the beam must not be hit (hits %d)" % side.hit_count)
	# Сосед у конца луча — только малый бурст (диминишинг от центра).
	if tip_neighbor.hits_of_type("magic") != 1:
		errors.append("tip neighbor must take exactly the analysis burst (hits %d)" % tip_neighbor.hit_count)
	elif tip_neighbor.damage_of_type("magic") > roll * tip_ratio + 0.5:
		errors.append("tip burst must diminish from the burst center (got %.2f)" % tip_neighbor.damage_of_type("magic"))
	await _cleanup(holder)


func _test_injector_infection_and_trait_followup(errors: Array) -> void:
	var holder := _new_scene("Scrum896InjectorTrait")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "biologist", "biologist_sample_injector")
	var first := _new_enemy(holder, owner.global_position + Vector2(220, 0))
	var second := _new_enemy(holder, owner.global_position + Vector2(430, 0))
	await process_frame

	weapon.call("_fire_bio_sample_dart", owner, second, Vector2.RIGHT)
	await create_timer(0.2).timeout
	# Пробу получает ТОЛЬКО ближайший на луче.
	if not StatusEffects.has_status(first, "bio_infection"):
		errors.append("closest enemy on the beam must receive the sample infection")
	if StatusEffects.has_status(second, "bio_infection"):
		errors.append("only the closest line victim is injected (dot_targets 1)")
	# Первый каст шёл по чистым целям — базовые суммы без ×1.2.
	var physical_share := float(owner.derived_parameters["damage"]) * ClassWeapon.INJECTOR_PHYSICAL_SHARE
	var first_cast_first := first.total_damage
	if absf(first_cast_first - (100.0 + physical_share)) > 0.5:
		errors.append("first cast must not carry the infected bonus (got %.2f)" % first_cast_first)
	# Второй каст: ближайший уже заражён => ВЕСЬ его прямой урон (магия+физика) ×1.2.
	weapon.call("_fire_bio_sample_dart", owner, second, Vector2.RIGHT)
	await create_timer(0.2).timeout
	var second_cast_delta := first.total_damage - first_cast_first
	var expected_infected := (100.0 + physical_share) * 1.20
	if absf(second_cast_delta - expected_infected) > 0.5:
		errors.append("follow-up cast on the infected target must be exactly x1.2 (got %.2f, want %.2f)" % [second_cast_delta, expected_infected])
	await _cleanup(holder)


# --- SCRUM-896: Семя Симбионта -------------------------------------------------


func _test_seed_delayed_zone_and_dot_payoff(errors: Array) -> void:
	var holder := _new_scene("Scrum896SeedZone")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "biologist", "biologist_symbiote_seed")
	var zone_radius := float(weapon.get("aoe_radius"))
	var primary := _new_enemy(holder, owner.global_position + Vector2(300, 0))
	var neighbor := _new_enemy(holder, primary.global_position + Vector2(0, zone_radius * 0.6))
	var outside := _new_enemy(holder, primary.global_position + Vector2(zone_radius * 1.6, 0))
	await process_frame

	weapon.call("_fire_bio_symbiote_web", owner, primary, Vector2.RIGHT)
	# Темпоральность: до прорастания урона нет.
	await create_timer(0.15).timeout
	if primary.hit_count != 0:
		errors.append("seed must deal no damage before germination (hits %d)" % primary.hit_count)
	await create_timer(maxf(float(weapon.get("grenade_delay")), 0.08) + 0.25).timeout

	var impact_ratio := float(weapon.get("seed_impact_ratio"))
	var expected_impact := 100.0 * impact_ratio
	if primary.hits_of_type("magic") != 1 or absf(primary.damage_of_type("magic") - expected_impact) > 0.5:
		errors.append("seed must land one initial magic hit at germination (got %.2f, want %.2f)" % [primary.damage_of_type("magic"), expected_impact])
	if neighbor.hits_of_type("magic") != 1 or neighbor.damage_of_type("magic") >= primary.damage_of_type("magic"):
		errors.append("zone neighbors take the diminished initial hit (got %.2f)" % neighbor.damage_of_type("magic"))
	if outside.hit_count != 0:
		errors.append("enemies outside the seed zone must be untouched (hits %d)" % outside.hit_count)
	for pair in [["primary", primary], ["neighbor", neighbor]]:
		if not StatusEffects.has_status(pair[1] as Node, "bio_infection"):
			errors.append("seed must infect everyone caught in the zone (%s)" % str(pair[0]))
	# Главный пейофф — DoT: суммарные тики инфекции строго больше стартового хита.
	var before_dot := primary.damage_of_type("dot")
	for _frame in range(90):
		StatusEffects.tick(primary, 0.12)
	var dot_total := primary.damage_of_type("dot") - before_dot
	var tick_damage := float(owner.derived_parameters["dot_damage"]) * float(weapon.get("curse_tick_multiplier"))
	var expected_dot := tick_damage * float(weapon.get("dot_ticks"))
	if absf(dot_total - expected_dot) > 0.5:
		errors.append("seed infection must tick dot_ticks x tick (got %.2f, want %.2f)" % [dot_total, expected_dot])
	if dot_total <= primary.damage_of_type("magic"):
		errors.append("most of seed output must come from the DoT over time (dot %.2f vs impact %.2f)" % [dot_total, primary.damage_of_type("magic")])
	# Тики летят с атрибуцией игрока, но БЕЗ усиления трейтом (ровно tick_damage).
	for hit in primary.hits:
		var feedback: Dictionary = hit["feedback"]
		if str(feedback.get("damage_type", "")) != "dot":
			continue
		if absf(float(hit["amount"]) - tick_damage) > 0.5:
			errors.append("dot tick must not be amplified by the trait (tick %.2f, want %.2f)" % [float(hit["amount"]), tick_damage])
			break
	await _cleanup(holder)


# --- SCRUM-1005: trait «Разбор образцов» ---------------------------------------


func _test_sample_analysis_trait(errors: Array) -> void:
	var trait_config: Dictionary = PD.class_trait("biologist")
	if str(trait_config.get("id", "")) != "sample_analysis" or absf(float(trait_config.get("infected_direct_hit_multiplier", 0.0)) - 1.20) > 0.001:
		errors.append("biologist must expose sample_analysis x1.20 via the CLASS_TRAITS registry")
		return

	var holder := _new_scene("Scrum1005SampleAnalysis")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "biologist", "biologist_spore_lens")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(140, 0))
	await process_frame

	# Чистая цель: базовый прямой урон без бонуса.
	weapon.call("_damage_enemy", enemy, 100.0)
	if absf(enemy.total_damage - 100.0) > EPS:
		errors.append("direct damage on a clean target must be unchanged (got %.3f)" % enemy.total_damage)
	# Под СВОИМ DoT: ровно +20%.
	weapon.call("_apply_bio_infection", enemy, owner)
	weapon.call("_damage_enemy", enemy, 100.0)
	if absf(enemy.total_damage - 220.0) > EPS:
		errors.append("direct damage under own DoT must be exactly x1.20 (delta %.3f)" % (enemy.total_damage - 100.0))
	# Тик DoT самого статуса не усилен (10 * 1.0 у линзы).
	var dot_before := enemy.damage_of_type("dot")
	StatusEffects.tick(enemy, 0.55)
	var tick_delta := enemy.damage_of_type("dot") - dot_before
	if tick_delta > 0.0 and absf(tick_delta - 10.0) > EPS:
		errors.append("infection ticks must stay unamplified (tick %.3f, want 10)" % tick_delta)

	# Чужой владелец: инфекция ДРУГОГО Биолога бонуса этому не даёт.
	var stranger := _new_owner(holder, owner.global_position + Vector2(0, 200))
	var stranger_weapon := _new_weapon(stranger, "biologist", "biologist_spore_lens")
	var foreign_probe := _new_enemy(holder, owner.global_position + Vector2(260, 0))
	await process_frame
	stranger_weapon.call("_apply_bio_infection", foreign_probe, stranger)
	weapon.call("_damage_enemy", foreign_probe, 100.0)
	if absf(foreign_probe.total_damage - 100.0) > EPS:
		errors.append("a stranger's DoT must not feed the bonus (got %.3f)" % foreign_probe.total_damage)
	# Статус без source_id (например, ожог Элементалиста) бонуса тоже не даёт.
	var untagged_probe := _new_enemy(holder, owner.global_position + Vector2(-220, 0))
	await process_frame
	StatusEffects.apply_status(untagged_probe, "four_elements_burn", {
		"duration": 3.0, "dot_damage": 5.0, "dot_interval": 1.0,
	})
	weapon.call("_damage_enemy", untagged_probe, 100.0)
	if absf(untagged_probe.total_damage - 100.0) > EPS:
		errors.append("untagged periodic effects must not feed the bonus (got %.3f)" % untagged_probe.total_damage)

	# Истечение: после смерти инфекции бонус не протекает.
	var expiry_probe := _new_enemy(holder, owner.global_position + Vector2(0, -220))
	await process_frame
	weapon.call("_apply_bio_infection", expiry_probe, owner)
	for _frame in range(40):
		StatusEffects.tick(expiry_probe, 0.12)
	if StatusEffects.has_status(expiry_probe, "bio_infection"):
		errors.append("infection must expire after its duration")
	var expiry_before := expiry_probe.total_damage
	weapon.call("_damage_enemy", expiry_probe, 100.0)
	if absf((expiry_probe.total_damage - expiry_before) - 100.0) > EPS:
		errors.append("no bonus may leak after infection expiry (delta %.3f)" % (expiry_probe.total_damage - expiry_before))

	# Другой класс: заражённая Биологом цель не даёт бонуса чужому оружию.
	var soldier := _new_owner(holder, owner.global_position + Vector2(0, 320))
	soldier.character_id = "soldier"
	var soldier_weapon := _new_weapon(soldier, "soldier", "soldier_rifle")
	var soldier_probe := _new_enemy(holder, owner.global_position + Vector2(320, 0))
	await process_frame
	weapon.call("_apply_bio_infection", soldier_probe, owner)
	soldier_weapon.call("_damage_enemy", soldier_probe, 100.0)
	if absf(soldier_probe.total_damage - 100.0) > EPS:
		errors.append("other classes must not gain the infected bonus (got %.3f)" % soldier_probe.total_damage)

	await _cleanup(holder)
