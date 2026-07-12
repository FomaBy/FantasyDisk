extends SceneTree

# SCRUM-1004: фокусный гейт class trait'а Берсерка «Ярость» (реестр SCRUM-953,
# docs/design/class_traits_registry.md; данные — ProgressionData.CLASS_TRAITS.berserk).
#
#  - Формула: бонус исходящего урона = rage_damage_bonus_cap × missing_ratio,
#    missing_ratio = clamp(1 − health/max_health, 0, 1) — НЕПРЕРЫВНАЯ линейная
#    шкала: полное HP → ×1.0, половина → ×1.2, пустое → ровно ×1.4 (кап).
#  - Клампы невалидного HP: health<0 → ровно кап (×1.4), health>max → ×1.0,
#    max_health<=0 → ×1.0; NaN/бесконечность невозможны.
#  - Непрерывность: нет ступеньки нигде на шкале (в т.ч. на 30% HP — пороге
#    артефактных low-HP эффектов SCRUM-500, которые остаются отдельным слоем).
#  - Слой применяется ко всем ТРЁМ оружиям кита (меч/топор/молот) ПОСЛЕ обычных
#    модификаторов урона/крита и РОВНО один раз за хит: вторичные melee-эффекты
#    (close bonus и т.п.) наследуют усиленный dealt без повторного множения —
#    рекурсивного стака нет.
#  - Вторая ось кита — эхо-волна ульты «Неистовство» — усилена тем же слоем.
#  - Другим классам trait не течёт (data-driven CLASS_TRAITS, у остальных 1.0).
#  - Бюджет-зеркало: class_rage_expected_damage_factor = 1 + 0.40×0.30 = 1.12
#    только для Берсерка (budget_tuning_for компенсирует кит).
#
# Запуск: Godot --headless --path . --script res://tests/berserk_rage_trait_test.gd

const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.001
const RAGE_CAP := 0.40

var _errors: Array = []
var _holder: Node2D


func _initialize() -> void:
	seed(20260710)
	await process_frame
	_holder = Node2D.new()
	_holder.name = "BerserkRageTraitHolder"
	root.add_child(_holder)

	_check_trait_registry()
	_check_formula_and_clamps()
	_check_continuity()
	await _check_player_multiplier_and_isolation()
	await _check_all_three_weapons()
	await _check_hit_path_applies_once()
	await _check_ultimate_echo_axis()
	_check_budget_mirror()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Berserk rage trait: %s" % str(e))
		push_error("Berserk rage trait test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Berserk rage trait test passed (formula, cap, continuity, 3 weapons, ult echo, isolation, budget mirror).")
	quit(0)


# --- Реестр: data-driven запись только у Берсерка ---------------------------------

func _check_trait_registry() -> void:
	var trait_config: Dictionary = PD.CLASS_TRAITS.get("berserk", {})
	if trait_config.is_empty():
		_errors.append("реестр: у Берсерка нет записи в CLASS_TRAITS")
		return
	if str(trait_config.get("id", "")) != "rage":
		_errors.append("реестр: CLASS_TRAITS.berserk.id != rage")
	if str(trait_config.get("title", "")) != "Ярость":
		_errors.append("реестр: title != «Ярость»")
	if str(trait_config.get("description", "")).strip_edges().is_empty():
		_errors.append("реестр: пустое description")
	if absf(float(trait_config.get("rage_damage_bonus_cap", 0.0)) - RAGE_CAP) > EPS:
		_errors.append("реестр: rage_damage_bonus_cap %.3f вместо %.2f" % [float(trait_config.get("rage_damage_bonus_cap", 0.0)), RAGE_CAP])
	for class_id in PD.CLASS_TRAITS:
		if str(class_id) == "berserk":
			continue
		if (PD.CLASS_TRAITS[class_id] as Dictionary).has("rage_damage_bonus_cap"):
			_errors.append("реестр: rage_damage_bonus_cap протёк классу %s" % class_id)


# --- Формула и клампы невалидного HP ----------------------------------------------

func _check_formula_and_clamps() -> void:
	var cases := [
		# [health, max_health, ожидаемый бонус, метка]
		[100.0, 100.0, 0.0, "полное HP"],
		[50.0, 100.0, 0.20, "половина HP"],
		[25.0, 100.0, 0.30, "четверть HP"],
		[0.0, 100.0, RAGE_CAP, "пустое HP (ровно кап)"],
		[-35.0, 100.0, RAGE_CAP, "отрицательное HP (кламп в кап)"],
		[160.0, 100.0, 0.0, "HP выше максимума (кламп в 0)"],
		[50.0, 0.0, 0.0, "невалидный max_health=0"],
		[50.0, -10.0, 0.0, "невалидный max_health<0"],
	]
	for case in cases:
		var got := PD.class_rage_damage_bonus("berserk", float(case[0]), float(case[1]))
		if absf(got - float(case[2])) > EPS:
			_errors.append("формула (%s): бонус %.4f вместо %.4f" % [case[3], got, float(case[2])])
	# Near-zero HP: бонус вплотную к капу, но НЕ выше его.
	var near_zero := PD.class_rage_damage_bonus("berserk", 0.5, 100.0)
	if near_zero > RAGE_CAP + EPS:
		_errors.append("формула: near-zero бонус %.4f превысил кап" % near_zero)
	if absf(near_zero - 0.398) > EPS:
		_errors.append("формула: near-zero бонус %.4f вместо 0.398" % near_zero)


# --- Непрерывность: линейная шкала без ступенек -----------------------------------

func _check_continuity() -> void:
	var steps := 400
	var max_health := 100.0
	var previous := PD.class_rage_damage_bonus("berserk", max_health, max_health)
	var max_step_delta := RAGE_CAP / float(steps) + EPS
	for i in range(1, steps + 1):
		var hp := max_health * (1.0 - float(i) / float(steps))
		var bonus := PD.class_rage_damage_bonus("berserk", hp, max_health)
		var delta := bonus - previous
		if delta < -EPS:
			_errors.append("непрерывность: бонус упал при снижении HP (hp=%.2f)" % hp)
			return
		if delta > max_step_delta:
			_errors.append("непрерывность: ступенька %.4f на hp=%.2f (ожидался шаг <= %.4f)" % [delta, hp, max_step_delta])
			return
		previous = bonus
	# Явно: на границе 30% HP (порог артефактных low-HP эффектов SCRUM-500)
	# ступеньки нет — шкала trait'а от порога не зависит.
	var just_above := PD.class_rage_damage_bonus("berserk", 30.01, 100.0)
	var just_below := PD.class_rage_damage_bonus("berserk", 29.99, 100.0)
	if absf(just_below - just_above) > 0.001:
		_errors.append("непрерывность: скачок %.4f на пороге 30%% HP" % absf(just_below - just_above))


# --- Player-множитель и изоляция от других классов --------------------------------

func _check_player_multiplier_and_isolation() -> void:
	var player := _make_player("berserk", "sword")
	await process_frame
	player.set_physics_process(false)
	var max_hp := float(player.get("max_health"))
	if max_hp <= 0.0:
		_errors.append("player: невалидный max_health %.1f" % max_hp)

	player.set("health", max_hp)
	_expect_multiplier(player, 1.0, "полное HP")
	player.set("health", max_hp * 0.5)
	_expect_multiplier(player, 1.2, "половина HP")
	player.set("health", 0.0)
	_expect_multiplier(player, 1.4, "пустое HP (кап)")
	player.set("health", -25.0)
	_expect_multiplier(player, 1.4, "отрицательное HP (кламп)")
	player.set("health", max_hp * 2.0)
	_expect_multiplier(player, 1.0, "HP выше максимума (кламп)")
	player.queue_free()

	# Не течёт другим классам: у контрольных классов множитель ровно 1.0 при любом HP.
	for control_id in ["soldier", "knight", "guitarist"]:
		var control := _make_player(str(control_id))
		await process_frame
		control.set_physics_process(false)
		control.set("health", float(control.get("max_health")) * 0.25)
		if absf(float(control.call("rage_damage_multiplier")) - 1.0) > EPS:
			_errors.append("изоляция: %s получил rage-множитель %.3f" % [control_id, float(control.call("rage_damage_multiplier"))])
		control.queue_free()
	# Формула-уровень: ни один другой класс не имеет бонуса даже на нуле HP.
	for class_id in PD.character_ids():
		if str(class_id) == "berserk":
			continue
		if PD.class_rage_damage_bonus(str(class_id), 0.0, 100.0) > EPS:
			_errors.append("изоляция: формула дала бонус классу %s" % class_id)
	await process_frame


func _expect_multiplier(player: Node2D, expected: float, label: String) -> void:
	var got := float(player.call("rage_damage_multiplier"))
	if absf(got - expected) > EPS:
		_errors.append("player-множитель (%s): %.4f вместо %.2f" % [label, got, expected])


# --- Все три оружия кита получают один и тот же слой -------------------------------

func _check_all_three_weapons() -> void:
	for wid in ["sword", "axe", "hammer"]:
		var player := _make_player("berserk", str(wid))
		await process_frame
		player.set_physics_process(false)
		var weapon: Node = player.get("equipped_weapon")
		if weapon == null or not is_instance_valid(weapon):
			_errors.append("оружие %s: не экипировалось" % wid)
			continue
		# Детерминизм: выключаем крит, чтобы сравнивать чистые роллы.
		var derived: Dictionary = player.get("derived_parameters")
		derived["crit_chance"] = 0.0
		var base_damage := float(weapon.get("damage"))
		if base_damage <= 0.0:
			_errors.append("оружие %s: невалидный базовый урон %.2f" % [wid, base_damage])

		var max_hp := float(player.get("max_health"))
		player.set("health", max_hp)
		var full_roll := float(weapon.call("_rolled_damage", player))
		if absf(full_roll - base_damage) > base_damage * 0.001:
			_errors.append("оружие %s: на полном HP ролл %.3f вместо базового %.3f (×1.0)" % [wid, full_roll, base_damage])
		player.set("health", max_hp * 0.5)
		var half_roll := float(weapon.call("_rolled_damage", player))
		if absf(half_roll - base_damage * 1.2) > base_damage * 0.001:
			_errors.append("оружие %s: на половине HP ролл %.3f вместо %.3f (×1.2)" % [wid, half_roll, base_damage * 1.2])
		player.set("health", 0.0)
		var empty_roll := float(weapon.call("_rolled_damage", player))
		if absf(empty_roll - base_damage * 1.4) > base_damage * 0.001:
			_errors.append("оружие %s: на пустом HP ролл %.3f вместо %.3f (ровно ×1.4)" % [wid, empty_roll, base_damage * 1.4])
		# Кап жёсткий: ниже нуля HP множитель НЕ растёт дальше 1.4.
		player.set("health", -100.0)
		var clamped_roll := float(weapon.call("_rolled_damage", player))
		if clamped_roll > base_damage * 1.4 + base_damage * 0.001:
			_errors.append("оружие %s: бонус превысил кап +40%% (%.3f)" % [wid, clamped_roll])
		player.queue_free()
	await process_frame


# --- Реальный hit-path: слой применяется ровно один раз (без рекурсии) -------------

func _check_hit_path_applies_once() -> void:
	# Молот: melee_close_bonus (×1.18 вплотную) наследует усиленный dealt —
	# суммарно base×1.4×(1+0.18), а НЕ ×1.4² — рекурсивного стака нет.
	var player := _make_player("berserk", "hammer")
	await process_frame
	player.set_physics_process(false)
	var weapon: Node2D = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("hit-path: молот не экипировался")
		return
	var derived: Dictionary = player.get("derived_parameters")
	derived["crit_chance"] = 0.0
	var base_damage := float(weapon.get("damage"))
	var close_multiplier := float(weapon.get("melee_close_damage_multiplier"))
	player.set("health", 0.0)

	var enemy := _make_dummy_enemy(player.global_position + Vector2(60, 0))
	await process_frame
	weapon.call("_damage_target", player, enemy, Vector2.RIGHT, 1.0)
	var taken := float(enemy.get_meta("damage_taken", 0.0))
	var expected := base_damage * 1.4 * close_multiplier
	if absf(taken - expected) > expected * 0.005:
		_errors.append("hit-path: молот на пустом HP нанёс %.3f вместо %.3f (base×1.4×close %.2f — слой ровно один раз)" % [taken, expected, close_multiplier])
	var recursive := base_damage * 1.4 * 1.4
	if absf(taken - recursive) < expected * 0.005 and absf(expected - recursive) > expected * 0.005:
		_errors.append("hit-path: урон совпал с рекурсивным ×1.4² — стак множителя")
	enemy.queue_free()
	player.queue_free()
	await process_frame


# --- Вторая ось кита: эхо-волна ульты усилена тем же слоем -------------------------

func _check_ultimate_echo_axis() -> void:
	var player := _make_player("berserk", "sword")
	await process_frame
	player.set_physics_process(false)
	var max_hp := float(player.get("max_health"))
	player.set("health", max_hp * 0.5)
	player.set("_ultimate_active", true)

	var enemy := _make_dummy_enemy(player.global_position + Vector2(40, 0))
	await process_frame
	player.call("_trigger_berserk_ultimate_echo", enemy)
	var derived: Dictionary = player.get("derived_parameters")
	var config: Dictionary = PD.ultimate_config("berserk")
	var expected := float(derived.get("damage", 10.0)) * float(config.get("damage", 0.75)) * float(derived.get("ultimate_multiplier", 1.0)) * 1.2
	var taken := float(enemy.get_meta("damage_taken", 0.0))
	if absf(taken - expected) > maxf(expected * 0.005, 0.01):
		_errors.append("ульта-эхо: на половине HP волна нанесла %.3f вместо %.3f (×1.2)" % [taken, expected])
	enemy.queue_free()
	player.queue_free()
	await process_frame


# --- Бюджет-зеркало ----------------------------------------------------------------

func _check_budget_mirror() -> void:
	var factor := PD.class_rage_expected_damage_factor("berserk")
	var expected := 1.0 + RAGE_CAP * PD.RAGE_BUDGET_EXPECTED_MISSING_HP
	if absf(factor - expected) > EPS:
		_errors.append("бюджет: фактор Берсерка %.4f вместо %.4f" % [factor, expected])
	if absf(expected - 1.12) > EPS:
		_errors.append("бюджет: ожидаемый фактор %.4f вместо документированного 1.12" % expected)
	for control_id in ["soldier", "druid", "robot"]:
		if absf(PD.class_rage_expected_damage_factor(str(control_id)) - 1.0) > EPS:
			_errors.append("бюджет: фактор протёк классу %s" % control_id)


# --- Хелперы -----------------------------------------------------------------------

func _make_player(character_id: String, weapon_id := "") -> Node2D:
	var scene := load("res://scenes/Player.tscn") as PackedScene
	if scene == null or not scene.can_instantiate():
		_errors.append("player: Player.tscn не инстанцируется")
		return Node2D.new()
	var player := scene.instantiate() as Node2D
	_holder.add_child(player)
	player.global_position = Vector2(600, 400)
	player.call("configure_character", character_id, weapon_id)
	return player


func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var enemy := Area2D.new()
	enemy.add_to_group("enemies")
	enemy.set_meta("damage_taken", 0.0)
	enemy.set_script(_dummy_enemy_script())
	_holder.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _dummy_enemy_script() -> GDScript:
	# _show_combat_feedback — маркер typed-фидбэка (см. guitarist_kit_test).
	var src := """
extends Area2D
func take_damage(amount: float, feedback := {}) -> bool:
	set_meta(\"damage_taken\", float(get_meta(\"damage_taken\", 0.0)) + amount)
	return true
func apply_knockback(_impulse: Vector2) -> void:
	pass
func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
	pass
"""
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd
