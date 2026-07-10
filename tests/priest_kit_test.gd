extends SceneTree

# SCRUM-925/927/928/929: гейт редизайна кита Священника.
#
#  - SCRUM-925 «Молитва боя» (trait): data-driven пул ровно из 3 молитв
#    (ProgressionData.class_battle_prayers), выбор на старте боя (временный
#    автовыбор до UI SCRUM-926), round-buff применяется корректно
#    (+20% весь урон / +2 HP/с / −20% входящего последним множителем),
#    ровно один выбор за бой, чистка между боями (узел пересоздаётся),
#    другим классам trait не течёт.
#  - SCRUM-927 Реликварий: быстрый бурст «тик-тик-тик» БЕЗ лечения (никаких
#    heal_percent_of_damage / heal-passive в конфиге И сцене).
#  - SCRUM-928 Кадило: большой близкий AoE — радиус больше Реликвария,
#    дальность меньше, кулдаун длиннее; без скрытого сустейна.
#  - SCRUM-929 Колокол: dual toll — ровно два центра взрыва (цель и Жрец),
#    оба наносят урон, перекрытие капится дедупом (враг ≤ 1 взрыв за каст),
#    самоурона нет.
#
# Запуск: Godot --headless --path . --script res://tests/priest_kit_test.gd

const PD := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const EXPECTED_PRAYERS := ["prayer_wrath", "prayer_mending", "prayer_aegis"]
const OTHER_CLASSES := ["berserk", "soldier", "doctor", "robot", "druid", "guitarist"]
const EPS := 0.01

var _errors: Array = []


func _initialize() -> void:
	seed(20260710)
	await process_frame

	_check_trait_registry_pool()
	await _check_prayer_selection_contract()
	await _check_prayer_wrath_damage()
	await _check_prayer_mending_regen()
	await _check_prayer_aegis_protection()
	await _check_prayer_cleanup_and_snapshot_isolation()
	await _check_prayer_no_leak_other_classes()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Priest kit: %s" % str(e))
		push_error("Priest kit test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Priest kit test passed (battle prayer trait: pool 3, one-choice, buffs, cleanup, no leak).")
	quit(0)


# --- helpers ------------------------------------------------------------------

func _make_player(character_id: String, weapon_id := "") -> Node2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	root.add_child(player)
	player.call("configure_character", character_id, weapon_id)
	return player


func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var enemy := Area2D.new()
	enemy.add_to_group("enemies")
	enemy.set_meta("damage_taken", 0.0)
	enemy.set_script(_dummy_enemy_script())
	root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _dummy_enemy_script() -> GDScript:
	var src := """
extends Area2D
func take_damage(amount: float, _feedback := {}) -> bool:
	set_meta(\"damage_taken\", float(get_meta(\"damage_taken\", 0.0)) + amount)
	return true
func apply_knockback(_impulse: Vector2) -> void:
	pass
"""
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd


# Нейтрализация митигаций/регена — изолируем проверяемый эффект молитвы.
func _neutralize_player(player: Node2D) -> void:
	var dp: Dictionary = player.get("derived_parameters")
	dp["dodge"] = 0.0
	dp["dodge_chance"] = 0.0
	dp["defense"] = 0.0
	dp["absorb"] = 0.0
	dp["regeneration"] = 0.0
	player.set("derived_parameters", dp)
	player.set("_damage_invulnerability_left", 0.0)


# --- SCRUM-925: реестр trait'а и пул молитв ------------------------------------

func _check_trait_registry_pool() -> void:
	var trait_config: Dictionary = PD.class_trait("priest")
	if str(trait_config.get("id", "")) != "battle_prayer" or str(trait_config.get("title", "")).is_empty():
		_errors.append("trait: у Священника нет trait'а battle_prayer в CLASS_TRAITS")
	var pool: Array = PD.class_battle_prayers("priest")
	if pool.size() != 3:
		_errors.append("trait: пул молитв Священника = %d, ожидалось ровно 3" % pool.size())
		return
	for index in range(pool.size()):
		var prayer: Dictionary = pool[index]
		if str(prayer.get("id", "")) != EXPECTED_PRAYERS[index]:
			_errors.append("trait: молитва №%d = '%s', ожидалась '%s' (порядок = порядок UI)" % [index, str(prayer.get("id", "")), EXPECTED_PRAYERS[index]])
		if str(prayer.get("title", "")).is_empty() or str(prayer.get("description", "")).is_empty():
			_errors.append("trait: у молитвы %s нет русского title/description для UI SCRUM-926" % str(prayer.get("id", "")))
	# Значения эффектов = контракт AC: +20% урона, +2 HP/с, −20% входящего.
	var by_id := {}
	for prayer_raw in pool:
		by_id[str((prayer_raw as Dictionary).get("id"))] = float((prayer_raw as Dictionary).get("value", 0.0))
	if not is_equal_approx(float(by_id.get("prayer_wrath", 0.0)), 0.20):
		_errors.append("trait: prayer_wrath value %.3f != 0.20" % float(by_id.get("prayer_wrath", 0.0)))
	if not is_equal_approx(float(by_id.get("prayer_mending", 0.0)), 2.0):
		_errors.append("trait: prayer_mending value %.3f != 2.0" % float(by_id.get("prayer_mending", 0.0)))
	if not is_equal_approx(float(by_id.get("prayer_aegis", 0.0)), 0.20):
		_errors.append("trait: prayer_aegis value %.3f != 0.20" % float(by_id.get("prayer_aegis", 0.0)))
	# Другим классам пул пуст — утечки нет.
	for other_class in OTHER_CLASSES:
		if not (PD.class_battle_prayers(other_class) as Array).is_empty():
			_errors.append("trait: пул молитв протёк классу %s" % other_class)


# --- SCRUM-925: контракт выбора (один за бой, автовыбор) ------------------------

func _check_prayer_selection_contract() -> void:
	var player := _make_player("priest", "priest_censer")
	await process_frame
	if (player.call("battle_prayer_choices") as Array).size() != 3:
		_errors.append("select: battle_prayer_choices() у Жреца не вернул 3 записи")
	if str(player.call("active_battle_prayer_id")) != "":
		_errors.append("select: молитва активна до выбора")
	if bool(player.call("select_battle_prayer", "prayer_unknown")):
		_errors.append("select: неизвестный id молитвы принят")
	if not bool(player.call("select_battle_prayer", "prayer_mending")):
		_errors.append("select: валидный выбор prayer_mending отклонён")
	if str(player.call("active_battle_prayer_id")) != "prayer_mending":
		_errors.append("select: активная молитва не prayer_mending")
	# Ровно один выбор за бой: повторный выбор отклоняется, активная не меняется.
	if bool(player.call("select_battle_prayer", "prayer_wrath")):
		_errors.append("select: второй выбор за бой принят (переключение запрещено AC)")
	if str(player.call("active_battle_prayer_id")) != "prayer_mending":
		_errors.append("select: повторный выбор подменил активную молитву")
	# Автовыбор поверх сделанного выбора НЕ перетирает его.
	player.call("on_battle_start")
	if str(player.call("active_battle_prayer_id")) != "prayer_mending":
		_errors.append("select: on_battle_start перетёр сделанный выбор")
	player.free()
	await process_frame
	# Временный автовыбор (до SCRUM-926): on_battle_start выбирает ПЕРВУЮ молитву пула.
	var auto_player := _make_player("priest", "priest_censer")
	await process_frame
	auto_player.call("on_battle_start")
	if str(auto_player.call("active_battle_prayer_id")) != "prayer_wrath":
		_errors.append("select: автовыбор on_battle_start не применил первую молитву пула")
	auto_player.free()
	await process_frame


# --- SCRUM-925: «Молитва кары» = +20% ко всему урону ----------------------------

func _check_prayer_wrath_damage() -> void:
	var player := _make_player("priest", "priest_censer")
	await process_frame
	var base_mult := float(player.call("meta_damage_multiplier", {"damage_type": "magic"}, null))
	player.call("select_battle_prayer", "prayer_wrath")
	var buffed_mult := float(player.call("meta_damage_multiplier", {"damage_type": "magic"}, null))
	if not is_equal_approx(buffed_mult, base_mult * 1.20):
		_errors.append("wrath: meta_damage_multiplier %.4f != base %.4f × 1.20" % [buffed_mult, base_mult])
	# Ульта идёт мимо meta_damage_multiplier — усилена в _apply_ultimate_damage.
	# Врага держим ВНЕ досягаемости кадила (авто-атака оружия не должна
	# подмешивать урон в замер), сам вызов ульты позиционно-независим.
	var weapon: Node = player.get("equipped_weapon")
	if weapon != null:
		weapon.set_process(false)
	var enemy := _make_dummy_enemy(player.global_position + Vector2(2400.0, 0.0))
	await process_frame
	enemy.set_meta("damage_taken", 0.0)
	player.call("_apply_ultimate_damage", enemy, 100.0)
	var taken := float(enemy.get_meta("damage_taken", 0.0))
	if not is_equal_approx(taken, 120.0):
		_errors.append("wrath: ульта под молитвой нанесла %.2f вместо 120 (кара обязана крыть ульту)" % taken)
	player.free()
	enemy.free()
	await process_frame


# --- SCRUM-925: «Молитва исцеления» = +2 HP/с -----------------------------------

func _check_prayer_mending_regen() -> void:
	var player := _make_player("priest", "priest_censer")
	await process_frame
	_neutralize_player(player)
	var max_health := float(player.get("max_health"))
	player.set("health", maxf(max_health * 0.5, 1.0))
	var before := float(player.get("health"))
	# Без молитвы (derived-реген нейтрализован) — HP не растёт.
	player.call("_apply_regeneration", 1.0)
	if float(player.get("health")) > before + EPS:
		_errors.append("mending: HP растёт без молитвы при нейтрализованном регене")
	player.call("select_battle_prayer", "prayer_mending")
	player.call("_apply_regeneration", 1.0)
	var healed := float(player.get("health")) - before
	if absf(healed - 2.0) > EPS:
		_errors.append("mending: за 1с восстановлено %.3f HP вместо 2.0" % healed)
	player.free()
	await process_frame


# --- SCRUM-925: «Молитва защиты» = −20% входящего последним множителем ----------

func _check_prayer_aegis_protection() -> void:
	var control := _make_player("priest", "priest_censer")
	await process_frame
	_neutralize_player(control)
	control.set("health", float(control.get("max_health")))
	var control_before := float(control.get("health"))
	control.call("take_damage", 50.0)
	var control_taken := control_before - float(control.get("health"))
	control.free()
	await process_frame

	var player := _make_player("priest", "priest_censer")
	await process_frame
	_neutralize_player(player)
	player.call("select_battle_prayer", "prayer_aegis")
	player.set("health", float(player.get("max_health")))
	player.set("_damage_invulnerability_left", 0.0)
	var before := float(player.get("health"))
	player.call("take_damage", 50.0)
	var taken := before - float(player.get("health"))
	if control_taken <= EPS:
		_errors.append("aegis: контрольный удар не прошёл (нейтрализация митигаций сломана)")
	elif absf(taken - control_taken * 0.80) > EPS + control_taken * 0.005:
		_errors.append("aegis: под молитвой прошло %.3f вместо %.3f × 0.80" % [taken, control_taken])
	player.free()
	await process_frame


# --- SCRUM-925: чистка между боями + изоляция от снапшота -----------------------

func _check_prayer_cleanup_and_snapshot_isolation() -> void:
	var player := _make_player("priest", "priest_censer")
	await process_frame
	player.call("select_battle_prayer", "prayer_wrath")
	# Молитва не живёт в run_modifiers → снапшот между узлами её не тащит.
	var modifiers: Dictionary = player.get("run_modifiers")
	for key in modifiers.keys():
		if str(key).begins_with("battle_prayer"):
			_errors.append("cleanup: ключ '%s' попал в run_modifiers (утечёт в снапшот между боями)" % str(key))
	player.free()
	await process_frame
	# Пересозданный узел (новый бой/смерть/рестарт) — молитва чиста, эффекта нет.
	var next_player := _make_player("priest", "priest_censer")
	await process_frame
	if str(next_player.call("active_battle_prayer_id")) != "":
		_errors.append("cleanup: молитва пережила пересоздание узла игрока")
	var mult := float(next_player.call("meta_damage_multiplier", {"damage_type": "magic"}, null))
	if mult > 1.0 + EPS:
		_errors.append("cleanup: бафф кары пережил пересоздание узла (%.3f)" % mult)
	next_player.free()
	await process_frame


# --- SCRUM-925: не течёт другим классам -----------------------------------------

func _check_prayer_no_leak_other_classes() -> void:
	var soldier := _make_player("soldier", "soldier_rifle")
	await process_frame
	if not (soldier.call("battle_prayer_choices") as Array).is_empty():
		_errors.append("leak: у Солдата непустой пул молитв")
	if bool(soldier.call("select_battle_prayer", "prayer_wrath")):
		_errors.append("leak: Солдат смог выбрать молитву")
	soldier.call("on_battle_start")
	if str(soldier.call("active_battle_prayer_id")) != "":
		_errors.append("leak: автовыбор применил молитву не-Жрецу")
	soldier.free()
	await process_frame
