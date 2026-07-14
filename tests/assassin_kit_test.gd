extends SceneTree

# SCRUM-894: фокусный гейт редизайна кита Ассасина (crit-cap identity).
#
# Trait «Хладнокровие» (CLASS_TRAITS.assassin, docs/design/class_traits_registry.md):
#   кап шанса крита Ассасина = 100% (у остальных глобальный CRIT_CHANCE_CAP 55%),
#   diminishing крит-вложений выключен (окупаются полностью), избыток raw-шанса
#   сверх капа переливается в крит-урон (overflow 0.5; итог зажат CRIT_DAMAGE_CAP).
# Чакрамы: возврат ЛЕВОЙ дугой (не тем же коридором): цель на прямой у разворота
#   ловит оба прохода, цель на левой дуге — только возврат, зеркальная справа —
#   ничего; per-cast/per-target гейт: максимум 1 outbound + 1 return хит.
# Теневые кинжалы: сектор + point-blank покрытие вокруг героя (мёртвой зоны в
#   упор нет), общий лимит целей; после серии по врагам — «Рывок темпа»
#   (скорость+уворот, bounded duration, внутренний кулдаун — без перманентного
#   аптайма; замена Shadow Momentum).
# Ядовитая струна: линия от самого героя + close-contact радиус (враги вплотную —
#   первые кандидаты, пирс-лимит общий), диапазон не full-screen; крит-снапшот
#   DoT (dot_crit_snapshot_ratio) — крит прямого удара усиливает тики.
# «Теневая завеса»: самоцентричная аура уворота — бонус только при враге внутри
#   derived aura_radius, масштаб от buff_power (кап veil_dodge_cap), суммарный
#   уворот ≤ SURVIVABILITY_DODGE_CAP (бессмертия нет).
#
# Запуск: Godot --headless --path . --script res://tests/assassin_kit_test.gd

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EPS := 0.001


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 40.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 6.0,
		"dot_speed": 2.0,
	}
	var run_modifiers := {}
	var stats := {}
	var health := 70.0
	var max_health := 100.0
	var flurry_tempo_triggers := 0

	func trigger_flurry_tempo() -> void:
		flurry_tempo_triggers += 1


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
	_test_trait_crit_cap_100(errors)
	_test_trait_no_diminish_linearity(errors)
	_test_trait_overflow_to_crit_damage(errors)
	_test_trait_anti_runaway(errors)
	_test_kit_data_contracts(errors)
	await _test_chakram_return_arc(errors)
	await _test_shadow_daggers_point_blank(errors)
	await _test_flurry_tempo_player_flow(errors)
	await _test_venom_wire_close_contact(errors)
	await _test_venom_wire_crit_snapshot(errors)
	await _test_venom_wire_crowd_spread(errors)
	await _test_dodge_veil(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Assassin kit: %s" % str(error))
		push_error("Assassin kit test failed with %d error(s)." % errors.size())
		quit(1)
		return
	print("Assassin kit test passed (SCRUM-894).")
	quit(0)


# --- Trait «Хладнокровие»: кап 100% / без diminish / overflow ---


func _derived(character_id: String, weapon_id: String, run_modifiers: Dictionary) -> Dictionary:
	var config: Dictionary = PD.weapon(character_id, weapon_id)
	return PD.derived_parameters(PD.base_stats(character_id), run_modifiers, config)


func _test_trait_crit_cap_100(errors: Array) -> void:
	# Большие крит-вложения: Ассасин достигает ровно 100%, контрольный класс
	# на тех же вложениях остаётся на глобальном капе 55%.
	var big_mods := {"crit_chance_flat": 2.0}
	var assassin_crit := float(_derived("assassin", "chakrams", big_mods).get("crit_chance", 0.0))
	var thief_crit := float(_derived("thief", str(PD.weapon_ids("thief")[0]), big_mods).get("crit_chance", 0.0))
	if absf(assassin_crit - 1.0) > EPS:
		errors.append("кап: Ассасин с большими вложениями crit=%.4f, ожидалось 1.0" % assassin_crit)
	if absf(thief_crit - PD.CRIT_CHANCE_CAP) > EPS:
		errors.append("кап контроля: не-Ассасин crit=%.4f, ожидался глобальный кап %.2f" % [thief_crit, PD.CRIT_CHANCE_CAP])
	# Реестр: trait-запись существует и заявляет кап 1.0.
	var trait_config: Dictionary = PD.class_trait("assassin")
	if absf(float(trait_config.get("crit_chance_cap", 0.0)) - 1.0) > EPS:
		errors.append("CLASS_TRAITS.assassin.crit_chance_cap != 1.0")
	# Hero-описание обязано явно заявлять 100% крита (AC SCRUM-894, копирайт — SCRUM-952).
	var description := str(PD.character_config("assassin").get("description", ""))
	if not description.contains("100%"):
		errors.append("описание героя не заявляет кап крита 100%: '%s'" % description)


func _test_trait_no_diminish_linearity(errors: Array) -> void:
	# Ниже капа крит-шанс Ассасина == raw без размывания:
	# base 0.04 + agility 10 × 0.0075 + (run 0.4 + passive 0.06) × 0.75 = 0.46.
	var crit := float(_derived("assassin", "chakrams", {"crit_chance_flat": 0.4}).get("crit_chance", 0.0))
	if absf(crit - 0.46) > EPS:
		errors.append("линейность: crit=%.4f, ожидалось 0.46 (без diminish)" % crit)


func _test_trait_overflow_to_crit_damage(errors: Array) -> void:
	# Избыток raw-крита сверх 1.0 переливается в крит-урон (×0.5 overflow,
	# затем ×CRIT_DAMAGE_FLAT_EFFECTIVENESS внутри формулы крит-урона).
	var at_cap := _derived("assassin", "chakrams", {"crit_chance_flat": 1.12})   # raw = 1.000
	var over_cap := _derived("assassin", "chakrams", {"crit_chance_flat": 1.18}) # raw = 1.045
	if absf(float(at_cap.get("crit_chance", 0.0)) - 1.0) > EPS or absf(float(over_cap.get("crit_chance", 0.0)) - 1.0) > EPS:
		errors.append("overflow: оба билда должны стоять на капе 1.0")
	var expected_delta := 0.045 * 0.5 * PD.CRIT_DAMAGE_FLAT_EFFECTIVENESS
	var actual_delta := float(over_cap.get("crit_damage_multiplier", 0.0)) - float(at_cap.get("crit_damage_multiplier", 0.0))
	if absf(actual_delta - expected_delta) > EPS:
		errors.append("overflow: дельта крит-урона %.5f != ожидаемой %.5f" % [actual_delta, expected_delta])
	# Контроль: у класса без overflow-ключа крит-вложения не трогают крит-урон.
	var thief_weapon := str(PD.weapon_ids("thief")[0])
	var thief_low := float(_derived("thief", thief_weapon, {"crit_chance_flat": 1.0}).get("crit_damage_multiplier", 0.0))
	var thief_high := float(_derived("thief", thief_weapon, {"crit_chance_flat": 2.0}).get("crit_damage_multiplier", 0.0))
	if absf(thief_low - thief_high) > EPS:
		errors.append("overflow контроля: crit_chance_flat изменил крит-урон не-Ассасина")


func _test_trait_anti_runaway(errors: Array) -> void:
	# Абсурдные вложения: шанс зажат 1.0, крит-урон зажат CRIT_DAMAGE_CAP.
	var params := _derived("assassin", "shadow_daggers", {"crit_chance_flat": 20.0, "crit_damage_flat": 20.0})
	if float(params.get("crit_chance", 0.0)) > 1.0 + EPS:
		errors.append("anti-runaway: crit_chance %.4f > 1.0" % float(params.get("crit_chance", 0.0)))
	if float(params.get("crit_damage_multiplier", 0.0)) > PD.CRIT_DAMAGE_CAP + EPS:
		errors.append("anti-runaway: crit_damage %.4f > CRIT_DAMAGE_CAP %.2f" % [float(params.get("crit_damage_multiplier", 0.0)), PD.CRIT_DAMAGE_CAP])


# --- Данные кита ---


func _test_kit_data_contracts(errors: Array) -> void:
	var chakrams: Dictionary = PD.weapon("assassin", "chakrams")
	var daggers: Dictionary = PD.weapon("assassin", "shadow_daggers")
	var venom: Dictionary = PD.weapon("assassin", "venom_wire")
	# Кит физический (crit-скейлер), не magic-кастер.
	for config in [chakrams, daggers, venom]:
		if str(config.get("damage_parameter", "")) != "damage":
			errors.append("%s: damage_parameter '%s' != 'damage' (кит не magic)" % [str(config.get("id")), str(config.get("damage_parameter"))])
		if str(config.get("kill_growth_role", "")) != "":
			errors.append("%s: Shadow Momentum (kill_growth_*) должен быть удалён" % str(config.get("id")))
		var tuned := float(config.get("budget_damage_multiplier", 1.0))
		if tuned <= 0.30 or tuned >= 2.75:
			errors.append("%s: budget_damage_multiplier %.3f у границы клэмпа [0.28..2.80]" % [str(config.get("id")), tuned])
	if float(chakrams.get("return_arc_offset", 0.0)) <= 0.0:
		errors.append("chakrams: нет return_arc_offset (дуга возврата)")
	if float(daggers.get("point_blank_radius", 0.0)) <= 0.0:
		errors.append("shadow_daggers: нет point_blank_radius (покрытие в упор)")
	var tempo_duration := float(daggers.get("flurry_tempo_duration", 0.0))
	var tempo_cooldown := float(daggers.get("flurry_tempo_cooldown", 0.0))
	if tempo_duration <= 0.0 or tempo_duration > 2.5:
		errors.append("shadow_daggers: flurry_tempo_duration %.2f вне (0, 2.5]" % tempo_duration)
	if tempo_cooldown < tempo_duration:
		errors.append("shadow_daggers: кулдаун %.2f < длительности %.2f — перманентный аптайм" % [tempo_cooldown, tempo_duration])
	if float(daggers.get("flurry_tempo_speed_bonus", 0.0)) > 0.25 or float(daggers.get("flurry_tempo_dodge_bonus", 0.0)) > 0.20:
		errors.append("shadow_daggers: flurry_tempo бонусы выше страховочных капов")
	if float(venom.get("close_contact_radius", 0.0)) <= 0.0:
		errors.append("venom_wire: нет close_contact_radius (мёртвая зона в упор)")
	var snapshot := float(venom.get("dot_crit_snapshot_ratio", 0.0))
	if snapshot <= 0.0 or snapshot > 1.0:
		errors.append("venom_wire: dot_crit_snapshot_ratio %.2f вне (0, 1]" % snapshot)
	if float(venom.get("attack_range", 0.0)) > 460.0:
		errors.append("venom_wire: attack_range %.0f — full-screen луч, а не сектор-линия" % float(venom.get("attack_range", 0.0)))


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
	weapon.configure_weapon(PD.weapon("assassin", weapon_id))
	# set_process(false) на script-created оружии слетает через кадр (движковый
	# квирк перезапуска process при первом входе в дерево) — авто-атака _process
	# дублировала бы касты. Гигантский _cooldown детерминированно глушит авто-фаер
	# на всё окно теста; касты зовём напрямую (_fire_*).
	weapon.set_process(false)
	weapon.set("_cooldown", 9999.0)
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


# --- Чакрамы: левая дуга возврата ---


func _test_chakram_return_arc(errors: Array) -> void:
	var holder := _new_scene("ChakramArc")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "chakrams")
	var origin := owner.global_position
	# A: середина прямой — только outbound (дуга уходит влево от линии).
	var enemy_mid_line := _new_enemy(holder, origin + Vector2(230, 0))
	# B: у точки разворота — outbound + начало дуги = двойной проход.
	var enemy_turn_point := _new_enemy(holder, origin + Vector2(430, 0))
	# C: на левой дуге (середина кривой) — только возврат.
	var enemy_left_arc := _new_enemy(holder, origin + Vector2(230, -85))
	# D: зеркально СПРАВА — дуга левая, хитов нет.
	var enemy_right_mirror := _new_enemy(holder, origin + Vector2(230, 85))
	await process_frame
	weapon.call("_fire_boomerang", owner, Vector2.RIGHT)
	await create_timer(0.75).timeout

	if enemy_mid_line.hits.size() != 1:
		errors.append("чакрамы: цель на середине прямой получила %d хитов, ожидался 1 (outbound)" % enemy_mid_line.hits.size())
	if enemy_turn_point.hits.size() != 2:
		errors.append("чакрамы: цель у разворота получила %d хитов, ожидалось 2 (double-pass)" % enemy_turn_point.hits.size())
	if enemy_left_arc.hits.size() != 1:
		errors.append("чакрамы: цель на левой дуге получила %d хитов, ожидался 1 (return)" % enemy_left_arc.hits.size())
	if enemy_right_mirror.hits.size() != 0:
		errors.append("чакрамы: зеркальная цель справа получила %d хитов, ожидалось 0 (дуга левая)" % enemy_right_mirror.hits.size())
	# Гейт per-cast/per-target: ни одна цель не может превысить 2 хита за каст.
	for enemy in [enemy_mid_line, enemy_turn_point, enemy_left_arc, enemy_right_mirror]:
		if (enemy as TypedEnemy).hits.size() > 2:
			errors.append("чакрамы: цель получила %d хитов за каст — гейт 1+1 сломан" % (enemy as TypedEnemy).hits.size())
	await _cleanup(holder)


# --- Теневые кинжалы: point-blank + лимит целей + триггер темпа ---


func _test_shadow_daggers_point_blank(errors: Array) -> void:
	var holder := _new_scene("DaggerPointBlank")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "shadow_daggers")
	var origin := owner.global_position
	var enemy_on_top := _new_enemy(holder, origin + Vector2(10, 0))    # «под ногами»
	var enemy_behind := _new_enemy(holder, origin + Vector2(-60, 0))   # за спиной, в упор
	var enemy_sector := _new_enemy(holder, origin + Vector2(150, 0))   # сектор перед героем
	var enemy_over_limit := _new_enemy(holder, origin + Vector2(200, 0)) # 4-й: за лимитом целей
	await process_frame
	weapon.call("_fire_stab_flurry", owner, Vector2.RIGHT)
	await process_frame

	if enemy_on_top.total_damage <= 0.0:
		errors.append("кинжалы: враг вплотную (под героем) не получил урона — мёртвая зона в упор")
	if enemy_behind.total_damage <= 0.0:
		errors.append("кинжалы: враг за спиной в point-blank радиусе не получил урона")
	if enemy_sector.total_damage <= 0.0:
		errors.append("кинжалы: враг в переднем секторе не получил урона")
	if enemy_over_limit.total_damage > 0.0:
		errors.append("кинжалы: 4-я цель получила урон — лимит projectile_count не работает")
	if owner.flurry_tempo_triggers != 1:
		errors.append("кинжалы: серия по врагам должна дёрнуть trigger_flurry_tempo ровно 1 раз (=%d)" % owner.flurry_tempo_triggers)
	await _cleanup(holder)

	# Серия в пустоту темп не даёт (бафф — награда за committed-атаку по врагу).
	var empty_holder := _new_scene("DaggerWhiff")
	var empty_owner := _new_owner(empty_holder)
	var empty_weapon := _new_weapon(empty_owner, "shadow_daggers")
	await process_frame
	empty_weapon.call("_fire_stab_flurry", empty_owner, Vector2.RIGHT)
	await process_frame
	if empty_owner.flurry_tempo_triggers != 0:
		errors.append("кинжалы: серия без попаданий не должна давать «Рывок темпа»")
	await _cleanup(empty_holder)


# --- «Рывок темпа»: бафф игрока bounded, без стакинга и перманентного аптайма ---


func _test_flurry_tempo_player_flow(errors: Array) -> void:
	var holder := _new_scene("FlurryTempo")
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.global_position = Vector2(640, 420)
	await process_frame
	player.call("configure_character", "assassin", "shadow_daggers")
	await process_frame
	var config: Dictionary = player.get("weapon_config")
	var duration := float(config.get("flurry_tempo_duration", 0.0))
	var base_params: Dictionary = player.get("derived_parameters")
	var base_speed := float(base_params.get("move_speed", 0.0))
	var base_dodge := float(base_params.get("dodge", 0.0))
	var base_attack_speed := float(base_params.get("attack_speed", 0.0))
	var health_before := float(player.get("health"))

	player.call("trigger_flurry_tempo")
	var mods: Dictionary = player.get("run_modifiers")
	var params: Dictionary = player.get("derived_parameters")
	if absf(float(mods.get("flurry_tempo_active", 0.0)) - 1.0) > EPS:
		errors.append("темп: flurry_tempo_active != 1.0 после триггера")
	var expected_speed := base_speed * (1.0 + float(config.get("flurry_tempo_speed_bonus", 0.0)))
	if absf(float(params.get("move_speed", 0.0)) - expected_speed) > 0.01:
		errors.append("темп: move_speed %.2f != ожидаемого %.2f" % [float(params.get("move_speed", 0.0)), expected_speed])
	if float(params.get("dodge", 0.0)) <= base_dodge + EPS:
		errors.append("темп: dodge не вырос после триггера")
	if absf(float(params.get("attack_speed", 0.0)) - base_attack_speed) > EPS:
		errors.append("темп: бафф не должен трогать attack_speed (это скорость+уворот)")
	if absf(float(player.get("health")) - health_before) > 0.05:
		errors.append("темп: триггер не должен лечить")

	# Не стакается: повторный триггер в окне ничего не наращивает.
	var speed_snapshot := float((player.get("derived_parameters") as Dictionary).get("move_speed", 0.0))
	player.call("trigger_flurry_tempo")
	if absf(float((player.get("derived_parameters") as Dictionary).get("move_speed", 0.0)) - speed_snapshot) > 0.01:
		errors.append("темп: повторный триггер в окне изменил move_speed (стакинг)")

	# Истечение окна: бафф спадает, но кулдаун ещё держит — retrigger no-op.
	player.call("_update_flurry_tempo", duration + 0.1)
	mods = player.get("run_modifiers")
	if float(mods.get("flurry_tempo_active", 0.0)) > EPS:
		errors.append("темп: бафф не истёк после duration")
	if absf(float((player.get("derived_parameters") as Dictionary).get("move_speed", 0.0)) - base_speed) > 0.01:
		errors.append("темп: move_speed не вернулся к базе после истечения")
	player.call("trigger_flurry_tempo")
	if float((player.get("run_modifiers") as Dictionary).get("flurry_tempo_active", 0.0)) > EPS:
		errors.append("темп: триггер в кулдауне должен быть no-op (перманентный аптайм)")

	# Кулдаун прошёл — темп снова доступен; смена оружия чистит бафф.
	player.call("_update_flurry_tempo", float(config.get("flurry_tempo_cooldown", 0.0)))
	player.call("trigger_flurry_tempo")
	if absf(float((player.get("run_modifiers") as Dictionary).get("flurry_tempo_active", 0.0)) - 1.0) > EPS:
		errors.append("темп: после кулдауна триггер должен сработать")
	player.call("equip_weapon", "venom_wire")
	await process_frame
	if float((player.get("run_modifiers") as Dictionary).get("flurry_tempo_active", 0.0)) > EPS:
		errors.append("темп: смена оружия не сняла бафф")
	# У струны нет flurry-ключей — триггер no-op (data-driven гейт).
	player.call("trigger_flurry_tempo")
	if float((player.get("run_modifiers") as Dictionary).get("flurry_tempo_active", 0.0)) > EPS:
		errors.append("темп: оружие без flurry_tempo_* ключей получило бафф")
	await _cleanup(holder)


# --- Ядовитая струна: close-contact + пирс-лимит ---


func _test_venom_wire_close_contact(errors: Array) -> void:
	var holder := _new_scene("VenomClose")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "venom_wire")
	var origin := owner.global_position
	var enemy_point_blank := _new_enemy(holder, origin + Vector2(0, 60))  # сбоку, вне линии
	var enemy_corridor := _new_enemy(holder, origin + Vector2(300, 0))
	var enemy_beyond_range := _new_enemy(holder, origin + Vector2(460, 0)) # за attack_range 420
	await process_frame
	weapon.call("_fire_single_dot_beam", owner, Vector2.RIGHT)
	await process_frame

	if enemy_point_blank.total_damage <= 0.0:
		errors.append("струна: враг вплотную (вне линии) не получил урона — мёртвая зона в упор")
	if enemy_corridor.total_damage <= 0.0:
		errors.append("струна: враг на линии не получил урона")
	if enemy_beyond_range.total_damage > 0.0:
		errors.append("струна: враг за пределом attack_range получил урон")
	# DoT существует: ждём первый тик (dot_speed 2.0 → 0.5с).
	await create_timer(0.75).timeout
	if enemy_corridor.typed_count("dot") < 1:
		errors.append("струна: по цели на линии не тикает яд (dot-канал)")
	if enemy_point_blank.typed_count("dot") < 1:
		errors.append("струна: по цели в упор не тикает яд (dot-канал)")
	await _cleanup(holder)

	# Пирс-лимит общий для близких и коридорных целей: 5 кандидатов, 4 хита.
	# FAN-1031 v7: изолируем ПИРС-канал — гасим отдельный крауд-спред (dot_beam_spread_ratio),
	# он тестируется своим сабтестом _test_venom_wire_crowd_spread. Контракт «бесплатных пирс-хитов
	# нет» проверяется чисто по пирсу; спред — ОРТОГОНАЛЬНЫЙ капнутый канал, не пирс.
	var limit_holder := _new_scene("VenomPierceLimit")
	var limit_owner := _new_owner(limit_holder)
	var limit_weapon := _new_weapon(limit_owner, "venom_wire")
	limit_weapon.set("dot_beam_spread_ratio", 0.0)
	var limit_origin := limit_owner.global_position
	var close_first := _new_enemy(limit_holder, limit_origin + Vector2(20, 20))
	_new_enemy(limit_holder, limit_origin + Vector2(150, 0))
	_new_enemy(limit_holder, limit_origin + Vector2(200, 0))
	_new_enemy(limit_holder, limit_origin + Vector2(250, 0))
	var farthest := _new_enemy(limit_holder, limit_origin + Vector2(320, 0))
	await process_frame
	limit_weapon.call("_fire_single_dot_beam", limit_owner, Vector2.RIGHT)
	await process_frame
	if close_first.total_damage <= 0.0:
		errors.append("струна: цель в упор должна бить первой (приоритет close-contact)")
	if farthest.total_damage > 0.0:
		errors.append("струна: 5-я цель получила урон — общий пирс-лимит сломан (бесплатные хиты)")
	await _cleanup(limit_holder)


# --- Ядовитая струна: крит-снапшот DoT ---


func _test_venom_wire_crit_snapshot(errors: Array) -> void:
	var holder := _new_scene("VenomCritSnapshot")
	var owner := _new_owner(holder)
	owner.derived_parameters["crit_chance"] = 1.0
	owner.derived_parameters["crit_damage_multiplier"] = 2.0
	var weapon := _new_weapon(owner, "venom_wire")
	var enemy := _new_enemy(holder, owner.global_position + Vector2(200, 0))
	await process_frame
	weapon.call("_fire_single_dot_beam", owner, Vector2.RIGHT)
	await create_timer(0.75).timeout
	if enemy.typed_count("dot") < 1:
		errors.append("снапшот: нет dot-тиков по цели")
	else:
		# tick = dot_damage 6.0 × (1 + (2.0 − 1) × dot_crit_snapshot_ratio 0.6) = 9.6
		var first_tick := 0.0
		for hit in enemy.hits:
			if str(hit["type"]) == "dot":
				first_tick = float(hit["amount"])
				break
		if absf(first_tick - 9.6) > 0.05:
			errors.append("снапшот: крит-тик %.3f != ожидаемых 9.6 (6.0 × 1.6)" % first_tick)
	await _cleanup(holder)

	# Контроль: без крита тик равен чистому dot_damage.
	var plain_holder := _new_scene("VenomPlainTick")
	var plain_owner := _new_owner(plain_holder)
	var plain_weapon := _new_weapon(plain_owner, "venom_wire")
	var plain_enemy := _new_enemy(plain_holder, plain_owner.global_position + Vector2(200, 0))
	await process_frame
	plain_weapon.call("_fire_single_dot_beam", plain_owner, Vector2.RIGHT)
	await create_timer(0.75).timeout
	if plain_enemy.typed_count("dot") < 1:
		errors.append("снапшот-контроль: нет dot-тиков")
	else:
		var tick := 0.0
		for hit in plain_enemy.hits:
			if str(hit["type"]) == "dot":
				tick = float(hit["amount"])
				break
		if absf(tick - 6.0) > 0.05:
			errors.append("снапшот-контроль: некритовый тик %.3f != 6.0" % tick)
	await _cleanup(plain_holder)


# --- FAN-1031 v7: ядовитый крауд-спред (assassin crowd-ниша, в существующих капах) ---


func _test_venom_wire_crowd_spread(errors: Array) -> void:
	# (1) Solo-ОРТОГОНАЛЬНОСТЬ: 1 цель пробивается → исключена из спреда → урон со спредом
	# РАВЕН урону без спреда (сентинел A/B). Гарантия: крауд-канал не раздувает solo-ось.
	var on_holder := _new_scene("VenomSpreadSoloOn")
	var on_owner := _new_owner(on_holder)
	var on_weapon := _new_weapon(on_owner, "venom_wire")
	var on_enemy := _new_enemy(on_holder, on_owner.global_position + Vector2(200, 0))
	await process_frame
	on_weapon.call("_fire_single_dot_beam", on_owner, Vector2.RIGHT)
	await process_frame
	var solo_on_dmg: float = on_enemy.total_damage
	await _cleanup(on_holder)

	var off_holder := _new_scene("VenomSpreadSoloOff")
	var off_owner := _new_owner(off_holder)
	var off_weapon := _new_weapon(off_owner, "venom_wire")
	off_weapon.set("dot_beam_spread_ratio", 0.0)
	var off_enemy := _new_enemy(off_holder, off_owner.global_position + Vector2(200, 0))
	await process_frame
	off_weapon.call("_fire_single_dot_beam", off_owner, Vector2.RIGHT)
	await process_frame
	var solo_off_dmg: float = off_enemy.total_damage
	await _cleanup(off_holder)

	if absf(solo_on_dmg - solo_off_dmg) > 0.05:
		errors.append("спред: solo %.3f (спред) != %.3f (без спреда) — пробитая цель не исключена, крауд-канал раздувает solo" % [solo_on_dmg, solo_off_dmg])

	# (2)+(3): 4 пробитых на линии (ровно pierce_count) + 8 НЕ-пробитых кучно вокруг самой
	# глубокой пробитой (в aoe_radius 75, но ВНЕ коридора beam_width 32 → не пирс-кандидаты).
	# Контракт: спред задевает не-пробитых (крауд-канал жив), но не больше aoe_max_targets (кап ширины).
	var crowd := _new_scene("VenomSpreadCrowd")
	var crowd_owner := _new_owner(crowd)
	var crowd_weapon := _new_weapon(crowd_owner, "venom_wire")
	var o: Vector2 = crowd_owner.global_position
	_new_enemy(crowd, o + Vector2(60, 0))
	_new_enemy(crowd, o + Vector2(120, 0))
	_new_enemy(crowd, o + Vector2(180, 0))
	var deep := _new_enemy(crowd, o + Vector2(240, 0))  # самая глубокая пробитая — ядро спреда
	var extras: Array = []
	for i in range(8):
		# столбцы выше/ниже линии (|y| >= 40 > half-corridor 16) в радиусе 45 < aoe_radius 75
		var dy := 40.0 if i % 2 == 0 else -40.0
		var dx := float(i - 4) * 12.0
		extras.append(_new_enemy(crowd, deep.global_position + Vector2(dx, dy)))
	await process_frame
	crowd_weapon.call("_fire_single_dot_beam", crowd_owner, Vector2.RIGHT)
	await process_frame
	var sprayed := 0
	for e in extras:
		if e.total_damage > 0.0:
			sprayed += 1
	var cap := int(crowd_weapon.get("aoe_max_targets"))
	if sprayed <= 0:
		errors.append("спред: ни один не-пробитый враг в радиусе не задет ядом — крауд-канал мёртв")
	if sprayed > cap:
		errors.append("спред: %d не-пробитых задето > кап aoe_max_targets %d — ширина не капнута" % [sprayed, cap])
	await _cleanup(crowd)


# --- «Теневая завеса»: самоцентричная аура уворота ---


func _test_dodge_veil(errors: Array) -> void:
	var holder := _new_scene("DodgeVeil")
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.global_position = Vector2(640, 420)
	await process_frame
	player.call("configure_character", "assassin", "shadow_daggers")
	await process_frame

	var veil_bonus := float(player.call("assassin_veil_dodge_bonus"))
	var veil_radius := float(player.call("assassin_veil_radius"))
	if veil_bonus <= 0.0:
		errors.append("завеса: у Ассасина нет бонуса уворота")
	if veil_radius <= 0.0:
		errors.append("завеса: радиус ауры не положителен")
	# Без врагов рядом — чистый базовый уворот.
	var base_chance := float(player.call("current_dodge_chance"))
	var base_dodge := clampf(float((player.get("derived_parameters") as Dictionary).get("dodge", 0.0)), 0.0, PD.SURVIVABILITY_DODGE_CAP)
	if absf(base_chance - base_dodge) > EPS:
		errors.append("завеса: без прессинга шанс %.4f != базовому %.4f" % [base_chance, base_dodge])

	# Враг внутри радиуса — бонус активен (ближний прессинг).
	var close_enemy := _new_enemy(holder, player.global_position + Vector2(minf(veil_radius * 0.5, veil_radius - 5.0), 0))
	await process_frame
	var pressured_chance := float(player.call("current_dodge_chance"))
	if absf(pressured_chance - clampf(base_dodge + veil_bonus, 0.0, PD.SURVIVABILITY_DODGE_CAP)) > EPS:
		errors.append("завеса: под прессингом шанс %.4f != base+bonus (кап %.2f)" % [pressured_chance, PD.SURVIVABILITY_DODGE_CAP])
	# Враг за радиусом — бонуса нет (дальний обстрел не в счёт).
	close_enemy.global_position = player.global_position + Vector2(veil_radius + 150.0, 0)
	await process_frame
	await process_frame
	if absf(float(player.call("current_dodge_chance")) - base_dodge) > EPS:
		errors.append("завеса: враг за радиусом всё ещё даёт бонус")

	# Масштаб от buff_power: рост → бонус растёт, гигантский buff_power упирается в кап.
	var mods: Dictionary = player.get("run_modifiers")
	mods["buff_power_flat"] = 0.5
	player.call("_apply_stat_scaling", false, float(player.get("max_health")))
	var boosted_bonus := float(player.call("assassin_veil_dodge_bonus"))
	if boosted_bonus <= veil_bonus + EPS:
		errors.append("завеса: бонус не растёт от buff_power (%.4f -> %.4f)" % [veil_bonus, boosted_bonus])
	mods["buff_power_flat"] = 50.0
	player.call("_apply_stat_scaling", false, float(player.get("max_health")))
	var capped_bonus := float(player.call("assassin_veil_dodge_bonus"))
	var trait_cap := float(PD.class_trait("assassin").get("veil_dodge_cap", 0.0))
	if absf(capped_bonus - trait_cap) > EPS:
		errors.append("завеса: бонус %.4f не упёрся в veil_dodge_cap %.2f" % [capped_bonus, trait_cap])
	mods["buff_power_flat"] = 0.0

	# Никакого бессмертия: с огромным dodge_flat итог ровно на SURVIVABILITY_DODGE_CAP.
	mods["dodge_flat"] = 10.0
	player.call("_apply_stat_scaling", false, float(player.get("max_health")))
	close_enemy.global_position = player.global_position + Vector2(60, 0)
	await process_frame
	if absf(float(player.call("current_dodge_chance")) - PD.SURVIVABILITY_DODGE_CAP) > EPS:
		errors.append("завеса: суммарный уворот %.4f превысил SURVIVABILITY_DODGE_CAP" % float(player.call("current_dodge_chance")))
	await _cleanup(holder)

	# Контроль: у не-Ассасина завесы нет.
	if float(PD.class_veil_dodge_bonus("thief", 2.0)) > 0.0:
		errors.append("завеса: не-Ассасин получил veil-бонус")
