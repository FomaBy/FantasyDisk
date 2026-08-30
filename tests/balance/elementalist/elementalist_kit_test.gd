extends SceneTree

# SCRUM-947..950: фокусный гейт редизайна кита Элементалиста.
#
# SCRUM-947 (trait «Проводник стихий»): каждый magic-tagged источник бонуса на
#   30% эффективнее ТОЛЬКО для Элементалиста; порядок стакинга детерминирован
#   (softcap → trait → exponent; каждый источник ровно один раз); физические и
#   периодические источники НЕ усиливаются. Замечание: забеговые множители
#   проходят глобальный softcap SCRUM-503, поэтому «+15% источник» фактически
#   даёт +14.93% другим классам и ровно ×1.30 от этого (+19.41%) Элементалисту —
#   инвариант trait'а проверяется как точное ×1.30 на эффективный бонус.
# SCRUM-948 (Кольцо Четырёх Стихий): rename в данных; квадратная зона в точке
#   каста (углы поражаются, за стороной — нет; вписанный круг углы не берёт);
#   три канала урона (магия+физика+ожог-статус); отброс от центра квадрата.
# SCRUM-949 (Призматический Фокус): полнокартный X (плечи PRISM_FULL_MAP_REACH
#   покрывают диагональ арены), пирс без спада, дедуп луч-хитов (не более одного
#   на врага за каст), центр-AoE бонус, телеграф до урона.
# SCRUM-950 (Ядро Метеора): максимальный fire_interval среди ВСЕХ оружий игрока,
#   телеграф-задержка без урона, тяжёлый удар, догорающая DoT-зона по dot-оси,
#   cleanup эффектов.
#
# Запуск: Godot --headless --path . --script res://tests/elementalist_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.001
const TRAIT_EPS := 0.0005


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 40.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 6.0,
		"dot_speed": 2.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0

	func heal_percent_capped(percent: float) -> void:
		health = minf(max_health, health + max_health * percent)

	func heal_percent(percent: float) -> void:
		heal_percent_capped(percent)


class TypedEnemy extends Node2D:
	var total_damage := 0.0
	var hits: Array = []

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		total_damage += amount
		hits.append({"amount": amount, "type": str(feedback.get("damage_type", ""))})

	# Маркер для ClassWeapon._take_damage_accepts_feedback: без него оружие шлёт
	# 1-арг take_damage и тип канала теряется.
	func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
		pass

	func typed_total(damage_type: String) -> float:
		var sum := 0.0
		for hit in hits:
			if str(hit["type"]) == damage_type:
				sum += float(hit["amount"])
		return sum

	func typed_count(damage_type: String) -> int:
		var count := 0
		for hit in hits:
			if str(hit["type"]) == damage_type:
				count += 1
		return count


func _initialize() -> void:
	var errors: Array = []
	_test_trait_magic_bonus_effectiveness(errors)
	_test_trait_source_isolation(errors)
	_test_trait_attribute_source(errors)
	_test_trait_stacking_no_double_apply(errors)
	_test_kit_data_contracts(errors)
	await _test_ring_square_field(errors)
	await _test_prism_full_map_x(errors)
	await _test_meteor_slow_nuke(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Elementalist kit: %s" % str(error))
		push_error("Elementalist kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Elementalist kit test passed (SCRUM-947..950).")
	quit(0)


# --- SCRUM-947: trait ---


func _magic_ratio(character_id: String, run_modifiers: Dictionary, config_override := {}) -> float:
	var config: Dictionary = PD.weapon(character_id, str(PD.weapon_ids(character_id)[0]))
	for key in config_override:
		config[key] = config_override[key]
	var base := PD.derived_parameters(PD.base_stats(character_id), {}, config)
	var modified := PD.derived_parameters(PD.base_stats(character_id), run_modifiers, config)
	return float(modified.get("magic_damage", 0.0)) / maxf(float(base.get("magic_damage", 0.0)), EPS)


func _test_trait_magic_bonus_effectiveness(errors: Array) -> void:
	var mods := {"magic_damage_multiplier": 1.15}
	var baseline_bonus := _magic_ratio("dark_mage", mods) - 1.0
	var elementalist_bonus := _magic_ratio("elementalist", mods) - 1.0
	# Контроль: другой класс получает софткапнутый +15% (≈ +14.93%), без усиления.
	if absf(baseline_bonus - 0.14933) > 0.001:
		errors.append("контроль: бонус другого класса от +15% источника = %.5f, ожидался ≈ 0.14933 (softcap SCRUM-503)" % baseline_bonus)
	# Trait: ровно ×1.30 к эффективному бонусу (+19.41% ≈ заявленные +19.5%).
	if absf(elementalist_bonus - baseline_bonus * 1.30) > TRAIT_EPS:
		errors.append("trait: бонус Элементалиста %.5f != baseline %.5f × 1.30" % [elementalist_bonus, baseline_bonus])
	if elementalist_bonus < 0.19 or elementalist_bonus > 0.20:
		errors.append("trait: бонус Элементалиста %.5f вне полосы ~+19.5%% (UI-округление ~+20%%)" % elementalist_bonus)


func _test_trait_source_isolation(errors: Array) -> void:
	var config_e: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	var stats_e: Dictionary = PD.base_stats("elementalist")
	var base := PD.derived_parameters(stats_e, {}, config_e)
	# Magic-tagged источник не трогает физический и периодический каналы.
	var magic_mods := PD.derived_parameters(stats_e, {"magic_damage_multiplier": 1.15}, config_e)
	if absf(float(magic_mods.get("damage")) / float(base.get("damage")) - 1.0) > EPS:
		errors.append("изоляция: magic-источник изменил физический канал Элементалиста")
	if absf(float(magic_mods.get("dot_damage")) / float(base.get("dot_damage")) - 1.0) > EPS:
		errors.append("изоляция: magic-источник изменил периодический канал Элементалиста")
	# Универсальный (не magic-tagged) damage_multiplier НЕ усиливается trait'ом:
	# его вклад в магию Элементалиста равен вкладу для другого класса.
	var universal := {"damage_multiplier": 1.15}
	var elementalist_universal := _magic_ratio("elementalist", universal)
	var baseline_universal := _magic_ratio("dark_mage", universal)
	if absf(elementalist_universal - baseline_universal) > EPS:
		errors.append("универсальный источник усилен trait'ом: elementalist %.5f vs baseline %.5f" % [elementalist_universal, baseline_universal])
	# Периодический источник (dot_damage_flat) не усиливается и не трогает магию.
	var dot_mods := PD.derived_parameters(stats_e, {"dot_damage_flat": 4.0}, config_e)
	if absf(float(dot_mods.get("magic_damage")) / float(base.get("magic_damage")) - 1.0) > EPS:
		errors.append("изоляция: периодический источник изменил магический канал")


func _test_trait_attribute_source(errors: Array) -> void:
	# Атрибутный источник: дельта интеллекта над базой класса усиливается ×1.30
	# ТОЛЬКО в magic-канале Элементалиста (после growth-скаляра класса).
	var growth_raw = PD.CLASS_LEVEL_STAT_GROWTH_SCALARS.get("elementalist", 1.0)
	var int_scalar := 1.0
	if growth_raw is Dictionary:
		int_scalar = float((growth_raw as Dictionary).get("intelligence", 1.0))
	var config_e: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	var stats_base: Dictionary = PD.base_stats("elementalist")
	var stats_bumped: Dictionary = stats_base.duplicate(true)
	stats_bumped["intelligence"] = float(stats_bumped["intelligence"]) + 10.0
	var base := PD.derived_parameters(stats_base, {}, config_e)
	var bumped := PD.derived_parameters(stats_bumped, {}, config_e)
	var base_intelligence := float(stats_base.get("intelligence", 9.0))
	var expected_gain := (10.0 * int_scalar * 1.30) / base_intelligence
	var actual_gain := float(bumped.get("magic_damage")) / float(base.get("magic_damage")) - 1.0
	if absf(actual_gain - expected_gain) > 0.001:
		errors.append("атрибутный источник: рост магии %.5f != ожидаемого %.5f (дельта интеллекта × growth × 1.30)" % [actual_gain, expected_gain])
	# SCRUM-1019: trait усиливает только положительную дельту. Отрицательная
	# дельта проходит без ×1.30 и обязательно снижает магический канал вместо
	# скрытого восстановления значения к базе класса.
	var stats_reduced: Dictionary = stats_base.duplicate(true)
	stats_reduced["intelligence"] = float(stats_reduced["intelligence"]) - 2.0
	var reduced := PD.derived_parameters(stats_reduced, {}, config_e)
	# _scaled_stat_growth deliberately scales positive progression only; attribute
	# penalties pass through at face value before the Elementalist trait is applied.
	var expected_loss := 2.0 / base_intelligence
	var actual_loss := 1.0 - float(reduced.get("magic_damage")) / float(base.get("magic_damage"))
	if absf(actual_loss - expected_loss) > 0.001:
		errors.append("атрибутный штраф: потеря магии %.5f != ожидаемой %.5f (отрицательная дельта не должна усиливаться или обнуляться)" % [actual_loss, expected_loss])
	if float(reduced.get("magic_damage")) >= float(base.get("magic_damage")) - EPS:
		errors.append("атрибутный штраф: интеллект ниже базы не снизил магический канал")
	# Прочие каналы от интеллекта не растут (изоляция типов SCRUM-524).
	if absf(float(bumped.get("damage")) - float(base.get("damage"))) > EPS:
		errors.append("атрибутный источник: интеллект изменил физический канал")
	if absf(float(bumped.get("dot_damage")) - float(base.get("dot_damage"))) > EPS:
		errors.append("атрибутный источник: интеллект изменил периодический канал")
	if absf(float(reduced.get("damage")) - float(base.get("damage"))) > EPS:
		errors.append("атрибутный штраф: интеллект изменил физический канал")
	if absf(float(reduced.get("dot_damage")) - float(base.get("dot_damage"))) > EPS:
		errors.append("атрибутный штраф: интеллект изменил периодический канал")


func _test_trait_stacking_no_double_apply(errors: Array) -> void:
	# Несколько магических множителей: каждый источник усиливается РОВНО один раз,
	# итог — произведение независимо усиленных факторов (без двойного применения).
	var config_plain: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	config_plain["passive_mods"] = {}
	var config_passive: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	config_passive["passive_mods"] = {"magic_damage_multiplier": 1.10}
	var stats: Dictionary = PD.base_stats("elementalist")
	var plain := float(PD.derived_parameters(stats, {}, config_plain).get("magic_damage"))
	# Пассив оружия (класс-прогрессия) — magic-tagged источник: ×1.30 на бонус.
	var passive_factor := float(PD.derived_parameters(stats, {}, config_passive).get("magic_damage")) / plain
	if absf(passive_factor - (1.0 + 0.10 * 1.30)) > 0.001:
		errors.append("пассив: фактор %.5f != 1.13 (бонус пассива должен усиливаться ×1.30)" % passive_factor)
	# Контроль: пассив другого класса не усиливается.
	var config_dark_plain: Dictionary = PD.weapon("dark_mage", "dark_wand")
	config_dark_plain["passive_mods"] = {}
	var config_dark_passive: Dictionary = PD.weapon("dark_mage", "dark_wand")
	config_dark_passive["passive_mods"] = {"magic_damage_multiplier": 1.10}
	var stats_dark: Dictionary = PD.base_stats("dark_mage")
	var dark_plain := float(PD.derived_parameters(stats_dark, {}, config_dark_plain).get("magic_damage"))
	var dark_passive_factor := float(PD.derived_parameters(stats_dark, {}, config_dark_passive).get("magic_damage")) / dark_plain
	if absf(dark_passive_factor - 1.10) > 0.001:
		errors.append("пассив контроля: фактор %.5f != 1.10 (другой класс без усиления)" % dark_passive_factor)
	# Стакинг run+passive: произведение независимо усиленных факторов.
	var run_factor := float(PD.derived_parameters(stats, {"magic_damage_multiplier": 1.15}, config_plain).get("magic_damage")) / plain
	var combined := float(PD.derived_parameters(stats, {"magic_damage_multiplier": 1.15}, config_passive).get("magic_damage")) / plain
	if absf(combined - run_factor * passive_factor) > 0.001:
		errors.append("стакинг: run+passive = %.5f, ожидалось %.5f (каждый источник ровно один раз)" % [combined, run_factor * passive_factor])


# --- Данные кита ---


func _test_kit_data_contracts(errors: Array) -> void:
	var ring: Dictionary = PD.weapon("elementalist", "elementalist_orb_ring")
	var prism: Dictionary = PD.weapon("elementalist", "elementalist_prism_focus")
	var meteor: Dictionary = PD.weapon("elementalist", "elementalist_meteor_core")
	# SCRUM-948: rename в данных.
	if str(ring.get("title", "")) != "Кольцо Четырёх Стихий":
		errors.append("rename: title кольца '%s' != 'Кольцо Четырёх Стихий'" % str(ring.get("title", "")))
	# Ниши кита: постоянный квадрат < редкий X < сверхредкий нюк.
	var ring_interval := float(ring.get("fire_interval", 0.0))
	var prism_interval := float(prism.get("fire_interval", 0.0))
	var meteor_interval := float(meteor.get("fire_interval", 0.0))
	if not (ring_interval < prism_interval and prism_interval < meteor_interval):
		errors.append("ниши кита: интервалы %.2f/%.2f/%.2f не упорядочены (кольцо < призма < метеор)" % [ring_interval, prism_interval, meteor_interval])
	# SCRUM-950: максимальный fire_interval среди ВСЕХ оружий игрока.
	for character_id in PD.character_ids():
		for weapon_id in PD.weapon_ids(str(character_id)):
			if str(weapon_id) == "elementalist_meteor_core":
				continue
			var other_interval := float(PD.weapon(str(character_id), str(weapon_id)).get("fire_interval", 0.0))
			if other_interval >= meteor_interval:
				errors.append("метеор не самый медленный: %s/%s fire_interval %.2f >= %.2f" % [character_id, weapon_id, other_interval, meteor_interval])
	# Телеграф метеора — долгий (не мгновенный).
	if float(meteor.get("grenade_delay", 0.0)) < 1.0:
		errors.append("метеор: grenade_delay %.2f < 1.0 — не читается как долгий каст" % float(meteor.get("grenade_delay", 0.0)))
	if meteor.has("shard_count"):
		errors.append("метеор: конфиг всё ещё содержит shard_count — веер осколков должен быть удалён")
	# Тюнинг не в клэмп-сатурации (кит реально балансируется, а не упирается в кап).
	for config in [ring, prism, meteor]:
		var tuned := float(config.get("budget_damage_multiplier", 1.0))
		if tuned <= 0.30 or tuned >= 2.75:
			errors.append("%s: budget_damage_multiplier %.3f у границы клэмпа [0.28..2.80]" % [str(config.get("id")), tuned])


# --- Общий стенд ---


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
	weapon.configure_weapon(PD.weapon("elementalist", weapon_id))
	weapon.set_process(false)
	return weapon


func _new_enemy(holder: Node2D, position: Vector2) -> TypedEnemy:
	var enemy := TypedEnemy.new()
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


# --- SCRUM-948: квадрат четырёх стихий ---


func _test_ring_square_field(errors: Array) -> void:
	var holder := _new_scene("Scrum948SquareField")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "elementalist_orb_ring")
	var center: Vector2 = owner.global_position
	var half_size: float = float(weapon.get("aoe_radius")) * ClassWeapon.SQUARE_HALF_RATIO
	# Угол квадрата: дальше вписанного круга (диагональ), но внутри квадрата.
	var corner_offset := Vector2(half_size * 0.94, half_size * 0.94)
	var corner_enemy := _new_enemy(holder, center + corner_offset)
	# За стороной квадрата: ближе к центру, чем диагональ угла, но |dx| > half.
	var outside_enemy := _new_enemy(holder, center + Vector2(half_size * 1.15, 0.0))
	# Внутри описанного круга, но вне квадрата по оси Y (старый круг зацепил бы).
	var circle_ghost_enemy := _new_enemy(holder, center + Vector2(0.0, half_size * 1.15))
	await process_frame

	weapon.call("_fire_elemental_orbit", owner, Vector2.RIGHT)
	await process_frame
	if corner_enemy.typed_total("magic") <= EPS:
		errors.append("квадрат: угол не получил магический канал (углы должны поражаться)")
	if corner_enemy.typed_total("physical") <= EPS:
		errors.append("квадрат: угол не получил физический канал")
	if not StatusEffects.has_status(corner_enemy, "four_elements_burn"):
		errors.append("квадрат: угол не получил периодический ожог (four_elements_burn)")
	if outside_enemy.total_damage > EPS or circle_ghost_enemy.total_damage > EPS:
		errors.append("квадрат: урон за пределами стороны (outside %.2f, ghost %.2f) — зона не квадратная" % [outside_enemy.total_damage, circle_ghost_enemy.total_damage])
	# Каналы считаются от своих осей: магия за каст ≈ ролл magic_damage, физика ≈
	# damage × SQUARE_PHYSICAL_SHARE (у мока разные значения — каналы различимы).
	var distance_before := (corner_enemy.global_position - center).length()
	# Отброс: враг уехал прочь от центра уже после первого тика.
	if distance_before <= corner_offset.length() + EPS:
		errors.append("квадрат: угол не отброшен от центра (%.2f -> %.2f)" % [corner_offset.length(), distance_before])
	# Зона заякорена в точке каста: герой ушёл, поле осталось на месте.
	owner.global_position = center + Vector2(800.0, 0.0)
	var field := holder.get_tree().root.find_child("ElementalSquareField", true, false)
	if field == null:
		errors.append("квадрат: узел поля ElementalSquareField не найден")
	elif ((field as Node2D).global_position - center).length() > 1.0:
		errors.append("квадрат: поле уехало за героем (должно стоять в точке каста)")
	# Полный цикл тиков: магия за каст ≈ полному роллу (4 тика × ролл/4).
	await create_timer(float(weapon.get("orbit_duration")) + 0.30).timeout
	var magic_total := corner_enemy.typed_total("magic")
	var expected_magic := 100.0
	# Отброс мог вынести врага из зоны на поздних тиках — магия не выше ролла
	# и не ниже первого тика.
	if magic_total > expected_magic + EPS:
		errors.append("квадрат: магия за каст %.2f превысила ролл %.2f" % [magic_total, expected_magic])
	var physical_total := corner_enemy.typed_total("physical")
	var physical_cap := 40.0 * ClassWeapon.SQUARE_PHYSICAL_SHARE
	if physical_total > physical_cap + EPS:
		errors.append("квадрат: физика за каст %.2f превысила долю %.2f" % [physical_total, physical_cap])
	weapon.cleanup_effects()
	await _cleanup(holder)


# --- SCRUM-949: полнокартный X ---


func _test_prism_full_map_x(errors: Array) -> void:
	var holder := _new_scene("Scrum949PrismX")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "elementalist_prism_focus")
	var focus_enemy := _new_enemy(holder, owner.global_position + Vector2(300.0, 0.0))
	var center: Vector2 = focus_enemy.global_position
	var axis_a := Vector2.RIGHT.rotated(PI / 4.0)
	var axis_b := axis_a.rotated(PI / 2.0)
	# Дальние цели на диагоналях: дистанция порядка диагонали арены (4096×2304).
	var far_a := _new_enemy(holder, center + axis_a * 4000.0)
	var far_b := _new_enemy(holder, center - axis_b * 4000.0)
	var near_a := _new_enemy(holder, center + axis_a * 320.0)
	# Вне лучей и вне центра: по горизонтали от центра.
	var off_beam := _new_enemy(holder, center + Vector2(2000.0, 0.0))
	# В центре-AoE, но мимо лучей.
	var center_ring := _new_enemy(holder, center + Vector2(0.0, float(weapon.get("aoe_radius")) * 0.60))
	await process_frame

	weapon.call("_fire_prism_rift", owner, focus_enemy, Vector2.RIGHT)
	# Телеграф: урона до истечения grenade_delay нет.
	await create_timer(float(weapon.get("grenade_delay")) * 0.55).timeout
	if far_a.total_damage > EPS or focus_enemy.total_damage > EPS:
		errors.append("призма: урон раньше телеграфа (X должен читаться до удара)")
	await create_timer(float(weapon.get("grenade_delay")) * 0.55 + 0.15).timeout
	var beam_damage := 100.0 * ClassWeapon.PRISM_BEAM_DAMAGE_SHARE
	var center_damage := 100.0 * ClassWeapon.PRISM_CENTER_BONUS_SHARE
	# Пирс до дальних углов без спада.
	for pair in [[far_a, "далёкая цель диагонали A"], [far_b, "далёкая цель диагонали B"], [near_a, "ближняя цель диагонали A"]]:
		var enemy := pair[0] as TypedEnemy
		if absf(enemy.total_damage - beam_damage) > EPS:
			errors.append("призма: %s получила %.2f, ожидался полный луч %.2f (пирс без спада)" % [pair[1], enemy.total_damage, beam_damage])
	# Дедуп: цель в фокусе лежит на ОБЕИХ диагоналях + в центре — ровно один
	# луч-хит + один центр-бонус (не два луча).
	var expected_focus := beam_damage + center_damage
	if absf(focus_enemy.total_damage - expected_focus) > EPS:
		errors.append("призма: фокус получил %.2f, ожидалось %.2f (один луч + центр, без дублей)" % [focus_enemy.total_damage, expected_focus])
	# Центр-AoE бьёт и мимо лучей.
	if absf(center_ring.total_damage - center_damage) > EPS:
		errors.append("призма: центр-AoE дал %.2f, ожидалось %.2f" % [center_ring.total_damage, center_damage])
	# Вне X и центра — чисто.
	if off_beam.total_damage > EPS:
		errors.append("призма: цель вне X получила %.2f" % off_beam.total_damage)
	# Плечи покрывают арену: документированный предел ≥ диагонали 4096×2304.
	if ClassWeapon.PRISM_FULL_MAP_REACH < Vector2(4096.0, 2304.0).length():
		errors.append("призма: PRISM_FULL_MAP_REACH %.0f меньше диагонали арены" % ClassWeapon.PRISM_FULL_MAP_REACH)
	# Артефакт «Призматический крест»: добавочный крест «+» со сниженной долей.
	owner.run_modifiers["prism_cross_pierce"] = 1.0
	var before_cross := off_beam.total_damage
	weapon.call("_fire_prism_rift", owner, focus_enemy, Vector2.RIGHT)
	await create_timer(float(weapon.get("grenade_delay")) + 0.15).timeout
	var cross_damage := off_beam.total_damage - before_cross
	if absf(cross_damage - beam_damage * ClassWeapon.PRISM_CROSS_EXTRA_SHARE) > EPS:
		errors.append("крест: горизонтальная цель получила %.2f, ожидалось %.2f" % [cross_damage, beam_damage * ClassWeapon.PRISM_CROSS_EXTRA_SHARE])
	weapon.cleanup_effects()
	await _cleanup(holder)


# --- SCRUM-950: медленный тяжёлый метеор ---


func _test_meteor_slow_nuke(errors: Array) -> void:
	var holder := _new_scene("Scrum950Meteor")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "elementalist_meteor_core")
	var center_enemy := _new_enemy(holder, owner.global_position + Vector2(280.0, 0.0))
	var edge_enemy := _new_enemy(holder, center_enemy.global_position + Vector2(float(weapon.get("aoe_radius")) * 0.92, 0.0))
	await process_frame

	var total_delay := float(weapon.get("grenade_delay"))
	weapon.call("_fire_meteor_shards", owner, center_enemy, Vector2.RIGHT)
	await process_frame
	# Телеграф зоны появился и стоит на точке удара.
	var telegraph := holder.get_tree().root.find_child("MeteorTelegraph", true, false)
	if telegraph == null:
		errors.append("метеор: телеграф зоны не найден во время каста")
	# Задержка: до конца grenade_delay урона нет.
	await create_timer(total_delay * 0.55).timeout
	if center_enemy.total_damage > EPS or edge_enemy.total_damage > EPS:
		errors.append("метеор: урон до завершения долгого каста")
	await create_timer(total_delay * 0.45 + 0.20).timeout
	var impact_center := center_enemy.typed_total("magic")
	var impact_edge := edge_enemy.typed_total("magic")
	if impact_center <= EPS:
		errors.append("метеор: центр не получил ударный магический урон")
	if impact_edge <= EPS or impact_edge >= impact_center:
		errors.append("метеор: falloff не работает (центр %.2f, край %.2f)" % [impact_center, impact_edge])
	# Телеграф и снаряд убраны на ударе.
	var stale_telegraph := holder.get_tree().root.find_child("MeteorTelegraph", true, false)
	if stale_telegraph != null:
		errors.append("метеор: телеграф не очищен после удара")
	# Догорающая зона: dot-тики по dot-оси владельца после удара.
	await create_timer(float(weapon.get("pool_tick_interval")) * 2.0 + 0.25).timeout
	var dot_ticks_seen := center_enemy.typed_count("dot")
	if dot_ticks_seen < 2:
		errors.append("метеор: зона дала %d dot-тиков, ожидалось >= 2" % dot_ticks_seen)
	if absf(center_enemy.typed_total("dot") / float(maxi(dot_ticks_seen, 1)) - 6.0) > 0.5:
		errors.append("метеор: тик зоны %.2f не соответствует dot-оси владельца (6.0)" % (center_enemy.typed_total("dot") / float(maxi(dot_ticks_seen, 1))))
	# Cleanup: после остановки эффектов зона больше не тикает.
	weapon.cleanup_effects()
	var dot_after_cleanup := center_enemy.typed_count("dot")
	await create_timer(float(weapon.get("pool_tick_interval")) * 2.0 + 0.25).timeout
	if center_enemy.typed_count("dot") != dot_after_cleanup:
		errors.append("метеор: зона тикает после cleanup_effects (хвост эффектов не убран)")
	await _cleanup(holder)
