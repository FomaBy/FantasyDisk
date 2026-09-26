extends SceneTree

# SCRUM-909..913: фокусный гейт редизайна кита Рейнджера («Сторожевой лук»).
#
# Trait «Сторожевой лук» (SCRUM-909, CLASS_TRAITS.ranger): каждый прямой хит
#   лучного оружия (bow_knockback_trait) отбрасывает жертву ОТ ИГРОКА — вектор
#   игрок→монстр на момент попадания, а не направление полёта снаряда; сила =
#   weapon.knockback × 3.6 (уроном не скейлится), боссы/элиты ×0.25
#   (общий контроль-резист POISON_PARALYSIS_BOSS_FACTOR); другим классам не течёт.
# «Лунный арбалет» (SCRUM-910, moon_split_shot): болт в одну цель + расщепление
#   в до split_count(4)+артефакт РАЗНЫХ соседей с ТЕМ ЖЕ уроном; без рекурсии.
# «Грозовой длинный лук» (SCRUM-911, storm_pierce_cone): дальнобойный конус
#   beam_count(5) пробивающих стрел по cone_degrees(34°); пирс pierce_count(4)
#   на стрелу без спада; дедуп на весь залп (у вершины — ровно один хит).
# «Охотничий капкан» (SCRUM-913, trap): перманентный (без таймера жизни), игрок
#   не запускает; триггер = физический AoE + жёсткий паралич (movement_locked,
#   боссы ×0.25) + зелёное кровотечение по dot-оси (тик = dot_damage владельца),
#   текущее и после паралича; кап живых капканов 6 (+2 артефакт), БЕЗ отброса.
#
# Запуск: Godot --headless --path . --script res://tests/ranger_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
const SE := preload("res://scripts/status_effects.gd")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const EPS := 0.001


class MockOwner extends CharacterBody2D:
	var character_id := "ranger"
	var derived_parameters := {
		"damage": 40.0,
		"magic_damage": 25.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 5.0,
		"dot_speed": 2.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0

	# Зеркало Player.class_trait_value (SCRUM-935): data-driven чтение trait'а
	# по character_id — тест переключает класс для проверки отсутствия утечки.
	func class_trait_value(key: String, default_value := 0.0) -> float:
		var trait_config: Dictionary = PD.CLASS_TRAITS.get(character_id, {})
		return float(trait_config.get(key, default_value))


class TypedEnemy extends Node2D:
	var total_damage := 0.0
	var hits: Array = []
	var impulses: Array = []

	func take_damage(amount: float, feedback: Dictionary = {}) -> void:
		total_damage += amount
		hits.append({"amount": amount, "type": str(feedback.get("damage_type", ""))})

	func apply_knockback(impulse: Vector2) -> void:
		impulses.append(impulse)

	# Маркер для ClassWeapon._take_damage_accepts_feedback (2-арг take_damage).
	func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
		pass


# «Игрок» для проверки НЕ-срабатывания капкана: Node2D вне группы enemies.
class NeutralBody extends Node2D:
	func take_damage(_amount: float, _source = null) -> bool:
		return true


func _initialize() -> void:
	# Гейт компиляции: если class_weapon.gd не собрался, ClassWeapon.new()
	# в стендах молча возвращает null и сценарии абортятся ДО ассертов —
	# получился бы ложный PASS с пустым errors. Красним сразу и громко.
	var weapon_script: Script = ClassWeapon
	if not weapon_script.can_instantiate():
		push_error("Ranger kit: class_weapon.gd не компилируется — все стенды мертвы, см. Parse Error выше.")
		quit(1)
		return
	var errors: Array = []
	_test_trait_registry_contract(errors)
	_test_kit_data_contracts(errors)
	await _test_bow_knockback_direction_and_magnitude(errors)
	await _test_bow_knockback_boss_resist(errors)
	await _test_bow_knockback_no_class_leak(errors)
	await _test_charge_cycle_production_cadence(errors)
	await _test_moon_split_counts(errors)
	await _test_moon_split_artifact_extra_targets(errors)
	await _test_storm_cone_geometry(errors)
	await _test_storm_pierce_and_apex_dedup(errors)
	await _test_trap_persistence_and_player_safety(errors)
	await _test_trap_trigger_effects(errors)
	await _test_trap_boss_resist_and_charge_snapshot(errors)
	await _test_trap_active_cap(errors)
	await _test_paralysis_stops_real_enemy(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Ranger kit: %s" % str(error))
		push_error("Ranger kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Ranger kit test passed (SCRUM-909..913).")
	quit(0)


# --- Контракты данных ---


func _test_trait_registry_contract(errors: Array) -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("ranger", {})
	if trait_config.is_empty():
		errors.append("trait: нет записи CLASS_TRAITS.ranger")
		return
	if str(trait_config.get("title", "")) != "Сторожевой лук":
		errors.append("trait: title '%s' != 'Сторожевой лук'" % str(trait_config.get("title", "")))
	if float(trait_config.get("bow_hit_knockback", 0.0)) <= 0.0:
		errors.append("trait: bow_hit_knockback не задан — отброс лука мёртв")
	var moon: Dictionary = PD.weapon("ranger", "moon_crossbow")
	var storm: Dictionary = PD.weapon("ranger", "storm_longbow")
	var trap: Dictionary = PD.weapon("ranger", "hunter_trap")
	for config in [moon, storm]:
		if not bool(config.get("bow_knockback_trait", false)):
			errors.append("%s: лучное оружие без bow_knockback_trait" % str(config.get("id")))
		# «Высокий отброс против обычного дальнобоя»: дефолт поля knockback = 80.
		if float(config.get("knockback", 0.0)) < 120.0:
			errors.append("%s: knockback %.0f < 120 — identity высокого отброса не читается" % [str(config.get("id")), float(config.get("knockback", 0.0))])
	if bool(trap.get("bow_knockback_trait", false)):
		errors.append("капкан: bow_knockback_trait не должен распространяться на капкан (паралич держит жертву)")
	# Весь кит физический: physical-апгрейды скейлят, magic/DoT прямые хиты не трогают.
	for config in [moon, storm, trap]:
		if str(config.get("damage_parameter", "")) != "damage":
			errors.append("%s: damage_parameter '%s' != 'damage' (кит физический)" % [str(config.get("id")), str(config.get("damage_parameter", ""))])


func _test_kit_data_contracts(errors: Array) -> void:
	var moon: Dictionary = PD.weapon("ranger", "moon_crossbow")
	var storm: Dictionary = PD.weapon("ranger", "storm_longbow")
	var trap: Dictionary = PD.weapon("ranger", "hunter_trap")
	if str(moon.get("attack_mode", "")) != "moon_split_shot":
		errors.append("арбалет: attack_mode '%s' != 'moon_split_shot'" % str(moon.get("attack_mode", "")))
	if str(storm.get("attack_mode", "")) != "storm_pierce_cone":
		errors.append("лук: attack_mode '%s' != 'storm_pierce_cone'" % str(storm.get("attack_mode", "")))
	if str(trap.get("attack_mode", "")) != "trap":
		errors.append("капкан: attack_mode '%s' != 'trap'" % str(trap.get("attack_mode", "")))
	# Арбалет: сплит ровно 1→4 (AC SCRUM-910).
	if int(moon.get("split_count", 0)) != 4:
		errors.append("арбалет: split_count %d != 4" % int(moon.get("split_count", 0)))
	# Лук: конус читаемо конический и дальнобойный (AC SCRUM-911).
	if int(storm.get("beam_count", 0)) < 5:
		errors.append("лук: beam_count %d < 5 — конус не читается" % int(storm.get("beam_count", 0)))
	var storm_cone := float(storm.get("cone_degrees", 0.0))
	if storm_cone < 20.0 or storm_cone > 60.0:
		errors.append("лук: cone_degrees %.1f вне полосы 20..60" % storm_cone)
	if float(storm.get("attack_range", 0.0)) < 900.0:
		errors.append("лук: attack_range %.0f < 900 — «дальнобойный» не читается" % float(storm.get("attack_range", 0.0)))
	if int(storm.get("pierce_count", 0)) < 3:
		errors.append("лук: pierce_count %d < 3 — пирс-идентичность слаба" % int(storm.get("pierce_count", 0)))
	# Капкан: перманентность = НЕТ таймера жизни (pool_duration) в конфиге.
	if trap.has("pool_duration"):
		errors.append("капкан: конфиг несёт pool_duration — перманентность нарушена (кап, а не таймер!)")
	var paralyze := float(trap.get("trap_paralyze_seconds", 0.0))
	if paralyze < 1.0 or paralyze > 3.5:
		errors.append("капкан: trap_paralyze_seconds %.2f вне полосы 1.0..3.5" % paralyze)
	var bleed_ticks := int(trap.get("dot_ticks", 0))
	var bleed_interval := float(trap.get("trap_bleed_tick_interval", 0.0))
	if bleed_ticks <= 0 or bleed_interval < 0.2 or bleed_interval > 1.0:
		errors.append("капкан: кровотечение dot_ticks=%d/interval=%.2f вне контракта" % [bleed_ticks, bleed_interval])
	# Кровотечение обязано пережить паралич на «несколько секунд» (AC SCRUM-913).
	if float(bleed_ticks) * bleed_interval < paralyze + 1.5:
		errors.append("капкан: кровотечение %.1fс не переживает паралич %.1fс + хвост" % [float(bleed_ticks) * bleed_interval, paralyze])
	if ClassWeapon.HUNTER_TRAP_ACTIVE_CAP < 3 or ClassWeapon.HUNTER_TRAP_ACTIVE_CAP > 10:
		errors.append("капкан: HUNTER_TRAP_ACTIVE_CAP %d вне разумной полосы 3..10" % ClassWeapon.HUNTER_TRAP_ACTIVE_CAP)
	# Тюнинг не в клэмп-сатурации: кит реально балансируется бюджетом.
	for config in [moon, storm, trap]:
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
	weapon.configure_weapon(PD.weapon("ranger", weapon_id))
	weapon.set_process(false)
	# Квирк headless-прогона (см. thief_kit_test): глушим авто-атаку кулдауном,
	# тесты зовут _fire_* напрямую.
	weapon.set("_cooldown", 1.0e9)
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


func _status(enemy: Node, status_id: String) -> Dictionary:
	if not enemy.has_meta("status_effects"):
		return {}
	var statuses: Dictionary = enemy.get_meta("status_effects")
	var status_raw = statuses.get(status_id, {})
	return status_raw if status_raw is Dictionary else {}


# --- SCRUM-909: trait «Сторожевой лук» ---


func _test_bow_knockback_direction_and_magnitude(errors: Array) -> void:
	var holder := _new_scene("BowKnockbackScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "moon_crossbow")
	var owner_position := owner.global_position
	var primary := _new_enemy(holder, owner.global_position + Vector2(120.0, 0.0))
	# Ветка сплита МЕЖДУ игроком и первичной целью: вектор «от снаряда»
	# (primary→branch) смотрит НА игрока, но отброс обязан идти ОТ игрока.
	var branch := _new_enemy(holder, owner.global_position + Vector2(60.0, 0.0))
	await process_frame
	weapon.call("_fire_moon_split_shot", owner, primary, Vector2.RIGHT)
	if primary.impulses.is_empty():
		errors.append("отброс: первичная цель не получила импульса")
	else:
		var impulse: Vector2 = primary.impulses[0]
		if impulse.normalized().dot(Vector2.RIGHT) < 0.99:
			errors.append("отброс: направление %s не от игрока (+X)" % str(impulse.normalized()))
		# Сила = knockback(175) × trait(1.0) × 3.6; уроном не скейлится.
		var expected := float(weapon.get("knockback")) * 3.6
		if absf(impulse.length() - expected) > 0.5:
			errors.append("отброс: |импульс| %.1f != %.1f (knockback×3.6)" % [impulse.length(), expected])
	if branch.impulses.is_empty():
		errors.append("отброс: ветка сплита без импульса")
	else:
		var branch_impulse: Vector2 = branch.impulses[0]
		if branch_impulse.normalized().dot(Vector2.RIGHT) < 0.99:
			errors.append("отброс: ветка толкнулась %s — не ОТ игрока (back-hit/сплит обязан толкать прочь)" % str(branch_impulse.normalized()))
	if owner.global_position.distance_to(owner_position) > EPS:
		errors.append("отброс: герой сместился — принудительного движения игрока быть не должно")
	await _cleanup(holder)


func _test_bow_knockback_boss_resist(errors: Array) -> void:
	var holder := _new_scene("BowBossResistScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "storm_longbow")
	var boss := _new_enemy(holder, owner.global_position + Vector2(200.0, 0.0))
	boss.add_to_group("bosses")
	await process_frame
	weapon.call("_fire_storm_pierce_cone", owner, Vector2.RIGHT)
	if boss.impulses.is_empty():
		errors.append("босс-резист: босс совсем без импульса (ожидался срезанный)")
	else:
		var expected := float(weapon.get("knockback")) * 3.6 * ClassWeapon.POISON_PARALYSIS_BOSS_FACTOR
		var actual: float = (boss.impulses[0] as Vector2).length()
		if absf(actual - expected) > 0.5:
			errors.append("босс-резист: |импульс| %.1f != %.1f (×%.2f)" % [actual, expected, ClassWeapon.POISON_PARALYSIS_BOSS_FACTOR])
	await _cleanup(holder)


func _test_bow_knockback_no_class_leak(errors: Array) -> void:
	var holder := _new_scene("BowLeakScene")
	var owner := _new_owner(holder)
	owner.character_id = "soldier"  # класс без trait'а «Сторожевой лук»
	var weapon := _new_weapon(owner, "moon_crossbow")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(120.0, 0.0))
	await process_frame
	weapon.call("_fire_moon_split_shot", owner, enemy, Vector2.RIGHT)
	if enemy.total_damage <= 0.0:
		errors.append("утечка: контрольный выстрел чужим классом не нанёс урона (стенд сломан)")
	if not enemy.impulses.is_empty():
		errors.append("утечка: trait-отброс сработал у класса без bow_hit_knockback")
	await _cleanup(holder)


# --- FAN-2237: partial auto-fire keeps the standing charge until one full release ---


func _test_charge_cycle_production_cadence(errors: Array) -> void:
	var l1_stats: Dictionary = PD.base_stats("ranger")
	var l20_stats := l1_stats.duplicate(true)
	l20_stats["agility"] = float(l20_stats.get("agility", 0.0)) + 19.0
	for scenario in [{"label": "L1", "stats": l1_stats}, {"label": "L20", "stats": l20_stats}]:
		var holder := _new_scene("RangerCharge%sScene" % str(scenario["label"]))
		var owner := _new_owner(holder)
		owner.stats = (scenario["stats"] as Dictionary).duplicate(true)
		var config: Dictionary = PD.weapon("ranger", "moon_crossbow")
		owner.derived_parameters = PD.derived_parameters(owner.stats, {}, config)
		var weapon := ClassWeapon.new()
		owner.add_child(weapon)
		weapon.configure_weapon(config)
		weapon.set_process(false)
		weapon.fire_interval = maxf(float(config.get("fire_interval", 1.0)) / maxf(float(owner.derived_parameters.get("attack_speed", 1.0)), 0.1), 0.18)
		var target := _new_enemy(holder, owner.global_position + Vector2(140.0, 0.0))
		var partial_charge_seen := false
		var full_release_seen := false
		for cast_index in range(12):
			weapon._process(weapon.fire_interval)
			var charge_after_cast := float(weapon.get("_charge_time"))
			if charge_after_cast > EPS:
				partial_charge_seen = true
			if partial_charge_seen and charge_after_cast <= EPS:
				full_release_seen = true
				break
		if not partial_charge_seen:
			errors.append("%s cadence: partial auto-fire reset stance accumulation before the threshold" % str(scenario["label"]))
		if not full_release_seen or target.hits.size() < 2:
			errors.append("%s cadence: production auto-fire never reached one real full-charge release" % str(scenario["label"]))
		weapon._process(weapon.fire_interval)
		var restarted_charge := float(weapon.get("_charge_time"))
		if restarted_charge <= EPS:
			errors.append("%s cadence: full release left a permanent full-charge state" % str(scenario["label"]))
		owner.velocity = Vector2(8.0, 0.0)
		weapon._process(weapon.fire_interval)
		if float(weapon.get("_charge_time")) >= restarted_charge - EPS:
			errors.append("%s cadence: movement did not decay the restarted charge" % str(scenario["label"]))
		owner.velocity = Vector2.ZERO
		await _cleanup(holder)


# --- SCRUM-910: «Лунный арбалет» 1→4 ---


func _test_moon_split_counts(errors: Array) -> void:
	# Одна цель: ровно 1 хит, веток нет.
	var holder := _new_scene("MoonSoloScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "moon_crossbow")
	var solo := _new_enemy(holder, owner.global_position + Vector2(150.0, 0.0))
	await process_frame
	weapon.call("_fire_moon_split_shot", owner, solo, Vector2.RIGHT)
	if solo.hits.size() != 1:
		errors.append("арбалет: одиночная цель получила %d хитов (ожидался ровно 1)" % solo.hits.size())
	await _cleanup(holder)

	# Толпа 6: первичная + ровно 4 ближайшие ветки, дальний сосед цел; урон равный.
	holder = _new_scene("MoonCrowdScene")
	owner = _new_owner(holder)
	weapon = _new_weapon(owner, "moon_crossbow")
	var primary := _new_enemy(holder, owner.global_position + Vector2(150.0, 0.0))
	var neighbors: Array = []
	for offset in [Vector2(100.0, 0.0), Vector2(0.0, 150.0), Vector2(150.0, 110.0), Vector2(200.0, 0.0)]:
		neighbors.append(_new_enemy(holder, primary.global_position + offset))
	var far := _new_enemy(holder, primary.global_position + Vector2(700.0, 500.0))
	await process_frame
	weapon.call("_fire_moon_split_shot", owner, primary, Vector2.RIGHT)
	if primary.hits.size() != 1:
		errors.append("арбалет: первичная цель получила %d хитов (рекурсия/повтор?)" % primary.hits.size())
	var primary_amount := float(primary.hits[0]["amount"]) if primary.hits.size() > 0 else 0.0
	var split_hits := 0
	for neighbor_raw in neighbors:
		var neighbor := neighbor_raw as TypedEnemy
		if neighbor.hits.size() > 1:
			errors.append("арбалет: сосед получил %d хитов — повторные хиты запрещены" % neighbor.hits.size())
		if neighbor.hits.size() == 1:
			split_hits += 1
			if absf(float(neighbor.hits[0]["amount"]) - primary_amount) > EPS:
				errors.append("арбалет: урон ветки %.2f != урона первичного %.2f (AC: тот же урон)" % [float(neighbor.hits[0]["amount"]), primary_amount])
			if str(neighbor.hits[0]["type"]) != "physical":
				errors.append("арбалет: тип урона ветки '%s' != physical" % str(neighbor.hits[0]["type"]))
	if split_hits != 4:
		errors.append("арбалет: веток %d != 4 (5+ целей → ровно 4 ближайшие)" % split_hits)
	if not far.hits.is_empty():
		errors.append("арбалет: дальний враг (вне сплит-радиуса) получил хит")
	await _cleanup(holder)


func _test_moon_split_artifact_extra_targets(errors: Array) -> void:
	var holder := _new_scene("MoonArtifactScene")
	var owner := _new_owner(holder)
	owner.run_modifiers = {"moon_split_targets": 2.0}  # «Лунный расщепитель»
	var weapon := _new_weapon(owner, "moon_crossbow")
	var primary := _new_enemy(holder, owner.global_position + Vector2(150.0, 0.0))
	var neighbors: Array = []
	for neighbor_index in range(7):
		var angle := TAU * float(neighbor_index) / 7.0
		neighbors.append(_new_enemy(holder, primary.global_position + Vector2.RIGHT.rotated(angle) * 120.0))
	await process_frame
	weapon.call("_fire_moon_split_shot", owner, primary, Vector2.RIGHT)
	var split_hits := 0
	for neighbor_raw in neighbors:
		split_hits += (neighbor_raw as TypedEnemy).hits.size()
	if split_hits != 6:
		errors.append("арбалет: с артефактом веток %d != 6 (база 4 + 2)" % split_hits)
	await _cleanup(holder)


# --- SCRUM-911: «Грозовой длинный лук» — конус ---


func _test_storm_cone_geometry(errors: Array) -> void:
	var holder := _new_scene("StormGeometryScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "storm_longbow")
	var origin := owner.global_position
	# Вдоль крайней стрелы (+8.5°) — внутри конуса.
	var inside_edge := _new_enemy(holder, origin + Vector2.RIGHT.rotated(deg_to_rad(8.5)) * 400.0)
	# Далеко по оси (940 < 980+26) — дальнобойность.
	var far_axis := _new_enemy(holder, origin + Vector2(940.0, 0.0))
	# 30° — за раствором конуса (макс стрела 17°).
	var outside_angle := _new_enemy(holder, origin + Vector2.RIGHT.rotated(deg_to_rad(30.0)) * 400.0)
	# За спиной.
	var behind := _new_enemy(holder, origin + Vector2(-140.0, 0.0))
	# За пределом дальности.
	var beyond := _new_enemy(holder, origin + Vector2(1120.0, 0.0))
	await process_frame
	weapon.call("_fire_storm_pierce_cone", owner, Vector2.RIGHT)
	if inside_edge.hits.size() != 1:
		errors.append("конус: цель вдоль крайней стрелы (+8.5°) не поражена")
	if far_axis.hits.size() != 1:
		errors.append("конус: дальняя осевая цель (940) не поражена — дальнобойность потеряна")
	if not outside_angle.hits.is_empty():
		errors.append("конус: цель на 30° поражена — конус шире заявленного (QA: невидимая зона)")
	if not behind.hits.is_empty():
		errors.append("конус: цель за спиной поражена")
	if not beyond.hits.is_empty():
		errors.append("конус: цель за пределом дальности поражена")
	if far_axis.hits.size() == 1 and str(far_axis.hits[0]["type"]) != "physical":
		errors.append("конус: тип урона '%s' != physical" % str(far_axis.hits[0]["type"]))
	await _cleanup(holder)


func _test_storm_pierce_and_apex_dedup(errors: Array) -> void:
	# Колонна 6 врагов по оси: центральная стрела пробивает первых pierce_count(4).
	var holder := _new_scene("StormPierceScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "storm_longbow")
	var column: Array = []
	for column_index in range(6):
		column.append(_new_enemy(holder, owner.global_position + Vector2(1000.0 - 900.0 + 120.0 * column_index, 0.0)))
	await process_frame
	weapon.call("_fire_storm_pierce_cone", owner, Vector2.RIGHT)
	var pierce_cap := int(weapon.get("pierce_count"))
	for column_index in range(6):
		var column_enemy := column[column_index] as TypedEnemy
		if column_index < pierce_cap and column_enemy.hits.size() != 1:
			errors.append("пирс: враг #%d в колонне получил %d хитов (ожидался 1)" % [column_index, column_enemy.hits.size()])
		if column_index >= pierce_cap and not column_enemy.hits.is_empty():
			errors.append("пирс: враг #%d за пирс-капом (%d) поражён" % [column_index, pierce_cap])
	# Урон пирса без спада (pierce_damage_falloff = 1.0): первый и четвёртый равны.
	var first_hit := column[0] as TypedEnemy
	var fourth_hit := column[3] as TypedEnemy
	if first_hit.hits.size() == 1 and fourth_hit.hits.size() == 1 \
			and absf(float(first_hit.hits[0]["amount"]) - float(fourth_hit.hits[0]["amount"])) > EPS:
		errors.append("пирс: урон по глубине спадает (%.2f → %.2f), у лука спада быть не должно" % [float(first_hit.hits[0]["amount"]), float(fourth_hit.hits[0]["amount"])])
	await _cleanup(holder)

	# Вершина конуса: враг в упор, куда сходятся все 5 стрел, — ровно 1 хит и 1 отброс.
	holder = _new_scene("StormApexScene")
	owner = _new_owner(holder)
	weapon = _new_weapon(owner, "storm_longbow")
	var apex := _new_enemy(holder, owner.global_position + Vector2(40.0, 0.0))
	await process_frame
	weapon.call("_fire_storm_pierce_cone", owner, Vector2.RIGHT)
	if apex.hits.size() != 1:
		errors.append("вершина: враг в упор получил %d хитов (дедуп залпа обязан оставить 1)" % apex.hits.size())
	if apex.impulses.size() != 1:
		errors.append("вершина: враг в упор получил %d отбросов (ожидался 1)" % apex.impulses.size())
	await _cleanup(holder)


# --- SCRUM-913: «Охотничий капкан» ---


func _trap_node(weapon: ClassWeapon) -> Node2D:
	for effect in weapon.call("_alive_effects"):
		if effect is Node2D and (effect as Node2D).has_meta("hunter_trap"):
			return effect as Node2D
	return null


func _test_trap_persistence_and_player_safety(errors: Array) -> void:
	var holder := _new_scene("TrapPersistScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "hunter_trap")
	weapon.call("_fire_trap", owner, Vector2.RIGHT)
	var trap := _trap_node(weapon)
	if trap == null:
		errors.append("капкан: не поставился")
		await _cleanup(holder)
		return
	# «Игрок» стоит на капкане: не в группе enemies → не срабатывает и не снимается.
	var bystander := NeutralBody.new()
	holder.add_child(bystander)
	bystander.global_position = trap.global_position
	await process_frame
	# 30 холостых проверок >> старого лимита жизни (pool_duration 4с / 0.2с = 20):
	# перманентный капкан обязан пережить их все.
	for check_index in range(30):
		weapon.call("_hunter_trap_check", trap.get_instance_id(), owner.get_instance_id(), {})
	if not is_instance_valid(trap) or trap.is_queued_for_deletion():
		errors.append("капкан: исчез без врага — таймер жизни/срабатывание от игрока")
	# Враг вошёл — капкан захлопнулся и снялся.
	var prey := _new_enemy(holder, trap.global_position + Vector2(40.0, 0.0))
	await process_frame
	weapon.call("_hunter_trap_check", trap.get_instance_id(), owner.get_instance_id(), {})
	if prey.hits.is_empty():
		errors.append("капкан: враг в радиусе не захлопнул капкан")
	if is_instance_valid(trap) and not trap.is_queued_for_deletion():
		errors.append("капкан: не снялся после срабатывания")
	await _cleanup(holder)


func _test_trap_trigger_effects(errors: Array) -> void:
	var holder := _new_scene("TrapEffectsScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "hunter_trap")
	weapon.call("_fire_trap", owner, Vector2.RIGHT)
	var trap := _trap_node(weapon)
	if trap == null:
		errors.append("капкан: не поставился (effects)")
		await _cleanup(holder)
		return
	var caught_a := _new_enemy(holder, trap.global_position + Vector2(50.0, 0.0))
	var caught_b := _new_enemy(holder, trap.global_position + Vector2(-60.0, 30.0))
	var outside := _new_enemy(holder, trap.global_position + Vector2(400.0, 0.0))
	await process_frame
	weapon.call("_trigger_hunter_trap", trap, owner)
	for caught_raw in [caught_a, caught_b]:
		var caught := caught_raw as TypedEnemy
		if caught.hits.size() != 1 or str(caught.hits[0]["type"]) != "physical":
			errors.append("капкан: жертва без физического AoE-хита (hits=%s)" % str(caught.hits))
		var paralysis := _status(caught, "hunter_trap_paralysis")
		if paralysis.is_empty():
			errors.append("капкан: нет статуса паралича")
		else:
			if not bool(paralysis.get("movement_locked", false)):
				errors.append("капкан: паралич без movement_locked — жертва не остановится")
			if absf(float(paralysis.get("duration", 0.0)) - float(weapon.get("trap_paralyze_seconds"))) > EPS:
				errors.append("капкан: паралич %.2f != конфигу %.2f" % [float(paralysis.get("duration", 0.0)), float(weapon.get("trap_paralyze_seconds"))])
			if not SE.is_movement_locked(caught):
				errors.append("капкан: is_movement_locked не видит паралич")
		var bleed := _status(caught, "hunter_trap_bleed")
		if bleed.is_empty():
			errors.append("капкан: нет статуса кровотечения")
		else:
			# dot-ось: тик = dot_damage владельца (мок: 5.0), интервал из конфига.
			if absf(float(bleed.get("dot_damage", 0.0)) - 5.0) > EPS:
				errors.append("капкан: тик кровотечения %.2f != dot_damage владельца 5.0" % float(bleed.get("dot_damage", 0.0)))
			var bleed_duration := float(bleed.get("duration", 0.0))
			if bleed_duration < float(weapon.get("trap_paralyze_seconds")) + 1.5:
				errors.append("капкан: кровотечение %.1fс не длиннее паралича + хвост" % bleed_duration)
			# Тики красятся dot-каналом (зелёное кровотечение по dot-оси).
			SE.tick(caught, float(bleed.get("dot_interval", 0.5)) + 0.01)
			var last_hit: Dictionary = caught.hits[caught.hits.size() - 1]
			if str(last_hit.get("type", "")) != "dot":
				errors.append("капкан: тик кровотечения типа '%s' != 'dot'" % str(last_hit.get("type", "")))
		if not caught.impulses.is_empty():
			errors.append("капкан: жертва получила отброс — паралич обязан держать её в капкане")
	if not outside.hits.is_empty():
		errors.append("капкан: враг вне радиуса получил хит")
	await _cleanup(holder)


func _test_trap_boss_resist_and_charge_snapshot(errors: Array) -> void:
	var holder := _new_scene("TrapBossScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "hunter_trap")
	# Снапшот стойки: капкан из полной стойки хлопает сильнее.
	weapon.set("_current_charge_multiplier", 1.35)
	weapon.call("_fire_trap", owner, Vector2.RIGHT)
	weapon.set("_current_charge_multiplier", 1.0)
	var trap := _trap_node(weapon)
	var boss := _new_enemy(holder, trap.global_position + Vector2(30.0, 0.0))
	boss.add_to_group("bosses")
	await process_frame
	weapon.call("_trigger_hunter_trap", trap, owner)
	var paralysis := _status(boss, "hunter_trap_paralysis")
	var expected_duration := float(weapon.get("trap_paralyze_seconds")) * ClassWeapon.POISON_PARALYSIS_BOSS_FACTOR
	if absf(float(paralysis.get("duration", 0.0)) - expected_duration) > EPS:
		errors.append("капкан: паралич босса %.2f != %.2f (резист ×%.2f — вечный стан босса недопустим)" % [float(paralysis.get("duration", 0.0)), expected_duration, ClassWeapon.POISON_PARALYSIS_BOSS_FACTOR])
	var bleed := _status(boss, "hunter_trap_bleed")
	if bleed.is_empty():
		errors.append("капкан: босс без кровотечения (резист режет только контроль)")
	if boss.hits.size() >= 1 and absf(float(boss.hits[0]["amount"]) - 40.0 * 1.35) > EPS:
		errors.append("капкан: урон %.1f != 54.0 (ролл 40 × снапшот стойки 1.35)" % float(boss.hits[0]["amount"]))
	await _cleanup(holder)


func _test_trap_active_cap(errors: Array) -> void:
	var holder := _new_scene("TrapCapScene")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "hunter_trap")
	for deploy_index in range(9):
		weapon.call("_fire_trap", owner, Vector2.RIGHT.rotated(TAU * float(deploy_index) / 9.0))
	var alive := 0
	for effect in weapon.call("_alive_effects"):
		if effect is Node2D and (effect as Node2D).has_meta("hunter_trap") and not (effect as Node2D).is_queued_for_deletion():
			alive += 1
	if alive != ClassWeapon.HUNTER_TRAP_ACTIVE_CAP:
		errors.append("капкан: живых %d != кап %d" % [alive, ClassWeapon.HUNTER_TRAP_ACTIVE_CAP])
	await _cleanup(holder)

	# Артефакт «Корневой капкан»: +2 к капу.
	holder = _new_scene("TrapCapArtifactScene")
	owner = _new_owner(holder)
	owner.run_modifiers = {"trap_cap_bonus": 2.0}
	weapon = _new_weapon(owner, "hunter_trap")
	for deploy_index in range(11):
		weapon.call("_fire_trap", owner, Vector2.RIGHT.rotated(TAU * float(deploy_index) / 11.0))
	var alive_bonus := 0
	for effect in weapon.call("_alive_effects"):
		if effect is Node2D and (effect as Node2D).has_meta("hunter_trap") and not (effect as Node2D).is_queued_for_deletion():
			alive_bonus += 1
	if alive_bonus != ClassWeapon.HUNTER_TRAP_ACTIVE_CAP + 2:
		errors.append("капкан: с артефактом живых %d != %d" % [alive_bonus, ClassWeapon.HUNTER_TRAP_ACTIVE_CAP + 2])
	await _cleanup(holder)


# --- Паралич на НАСТОЯЩЕМ враге: стоит, потом идёт (AC SCRUM-913) ---


func _test_paralysis_stops_real_enemy(errors: Array) -> void:
	var holder := _new_scene("ParalysisRealEnemyScene")
	var bait := NeutralBody.new()
	bait.add_to_group("player")
	holder.add_child(bait)
	bait.global_position = Vector2(900.0, 700.0)
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(enemy)
	enemy.global_position = Vector2(1300.0, 700.0)
	await physics_frame
	await physics_frame
	SE.apply_status(enemy, "hunter_trap_paralysis", {
		"duration": 0.6,
		"movement_locked": true,
		"speed_multiplier": 0.0,
		"marker_color": Color(0.45, 0.90, 0.40, 1.0),
	})
	var frozen_position := enemy.global_position
	for frame_index in range(12):
		await physics_frame
	var frozen_drift := enemy.global_position.distance_to(frozen_position)
	if frozen_drift > 2.0:
		errors.append("паралич: враг сместился на %.1fpx под movement_locked (обязан стоять)" % frozen_drift)
	# Статус истёк → враг снова идёт к цели.
	SE.apply_status(enemy, "hunter_trap_paralysis", {"duration": 0.01, "movement_locked": true})
	await physics_frame
	await physics_frame
	var resume_position := enemy.global_position
	for frame_index in range(20):
		await physics_frame
	var resume_drift := enemy.global_position.distance_to(resume_position)
	if resume_drift < 4.0:
		errors.append("паралич: враг не возобновил движение после истечения статуса (сдвиг %.1fpx)" % resume_drift)
	enemy.queue_free()
	await _cleanup(holder)
