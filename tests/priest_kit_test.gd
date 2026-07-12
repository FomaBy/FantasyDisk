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

	# SCRUM-927/928/929: оружейный кит — ниши (data-контракт) + рантайм-механики.
	_check_priest_weapon_niches()
	await _check_reliquary_burst_no_heal()
	await _check_censer_large_close_aoe()
	await _check_bell_dual_toll()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Priest kit: %s" % str(e))
		push_error("Priest kit test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Priest kit test passed (trait: pool 3/one-choice/buffs/cleanup/no-leak; reliquary burst no-heal; censer large close AoE; bell dual toll dedup).")
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


# --- SCRUM-925/926: контракт выбора (один за бой, без скрытого автовыбора) -------

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
	# Battle-start hooks do not overwrite an explicit UI choice.
	player.call("on_battle_start")
	if str(player.call("active_battle_prayer_id")) != "prayer_mending":
		_errors.append("select: on_battle_start перетёр сделанный выбор")
	player.free()
	await process_frame
	# SCRUM-926: on_battle_start must not make a hidden default choice; the
	# mandatory UI owns selection before CombatDirector calls this hook.
	var auto_player := _make_player("priest", "priest_censer")
	await process_frame
	auto_player.call("on_battle_start")
	if str(auto_player.call("active_battle_prayer_id")) != "":
		_errors.append("select: on_battle_start сделал скрытый автовыбор без UI")
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


# --- SCRUM-927/928/929: ниши трёх оружий (data-контракт) ------------------------
# Кросс-оружейные инварианты редизайна на уровне ProgressionData.weapon():
#   реликварий — самый дальний, малый радиус, самый быстрый темп, бурст-тики;
#   кадило — радиус БОЛЬШЕ реликвария, дальность КОРОЧЕ, кулдаун ДЛИННЕЕ;
#   колокол — dual toll (не chain); у всех троих оружейный сустейн выпилен.

func _check_priest_weapon_niches() -> void:
	var reliquary: Dictionary = PD.weapon("priest", "priest_reliquary")
	var censer: Dictionary = PD.weapon("priest", "priest_censer")
	var bell: Dictionary = PD.weapon("priest", "priest_chime")

	# Оружейного сустейна нет ни у одного из трёх (сустейн класса — trait SCRUM-925).
	for entry in [["Реликварий", reliquary], ["Кадило", censer], ["Колокол", bell]]:
		var wname: String = str((entry as Array)[0])
		var cfg: Dictionary = (entry as Array)[1]
		if not is_equal_approx(float(cfg.get("heal_percent_of_damage", 0.0)), 0.0):
			_errors.append("no-heal: у оружия «%s» снова есть heal_percent_of_damage" % wname)
		if not is_equal_approx(float(cfg.get("heal_percent_on_attack", 0.0)), 0.0):
			_errors.append("no-heal: у оружия «%s» снова есть heal_percent_on_attack" % wname)
		var passive: Dictionary = cfg.get("passive_mods", {})
		if not is_equal_approx(float(passive.get("regeneration_flat", 0.0)), 0.0):
			_errors.append("no-heal: у оружия «%s» осталась regen-пассивка regeneration_flat" % wname)
		if str(cfg.get("damage_parameter", "")) != "magic_damage":
			_errors.append("family: у оружия «%s» damage_parameter != magic_damage" % wname)

	var rel_range := float(reliquary.get("attack_range", 0.0))
	var cen_range := float(censer.get("attack_range", 0.0))
	var rel_radius := float(reliquary.get("aoe_radius", 0.0))
	var cen_radius := float(censer.get("aoe_radius", 0.0))
	var rel_interval := float(reliquary.get("fire_interval", 0.0))
	var cen_interval := float(censer.get("fire_interval", 0.0))
	# SCRUM-927 vs SCRUM-928: дальность реликвария > кадила; радиус кадила > реликвария.
	if not (rel_range > cen_range):
		_errors.append("niche: range реликвария %.0f не больше кадила %.0f (SCRUM-927/928)" % [rel_range, cen_range])
	if not (cen_radius > rel_radius):
		_errors.append("niche: радиус кадила %.0f не больше реликвария %.0f (SCRUM-928)" % [cen_radius, rel_radius])
	# SCRUM-928: кулдаун кадила длиннее (каденция медленнее) реликвария.
	if not (cen_interval > rel_interval):
		_errors.append("niche: КД кадила %.2f не длиннее реликвария %.2f (SCRUM-928)" % [cen_interval, rel_interval])

	# SCRUM-927: реликварий — читаемая серия тиков, доля ролла на тик в (0,1).
	if int(reliquary.get("storm_ticks", 1)) < 2:
		_errors.append("burst: реликварий не бьёт серией (storm_ticks < 2)")
	var tick_ratio := float(reliquary.get("sanctify_tick_ratio", 0.0))
	if tick_ratio <= 0.0 or tick_ratio >= 1.0:
		_errors.append("burst: sanctify_tick_ratio %.2f вне (0,1) — тик не «доля» ролла" % tick_ratio)
	if float(reliquary.get("burst_interval", 0.0)) <= 0.0:
		_errors.append("burst: burst_interval реликвария <= 0 (нет читаемой каденции)")

	# SCRUM-929: колокол — dual toll, старый prayer-chain выпилен.
	if str(bell.get("attack_mode", "")) != "priest_dual_toll":
		_errors.append("bell: attack_mode '%s' != priest_dual_toll (SCRUM-929)" % str(bell.get("attack_mode", "")))
	if bell.has("projectile_count"):
		_errors.append("bell: остался projectile_count от старого prayer-chain")


# --- SCRUM-927: реликварий — бурст-тик БЕЗ лечения ------------------------------
# Один реальный тик бурста (то, что дёргает tween-каденция) наносит урон цели в
# малом радиусе и НЕ задевает врага вне радиуса; жрец при этом НЕ лечится от
# нанесённого урона (весь heal-канал оружия убран — сустейн в trait SCRUM-925).

func _check_reliquary_burst_no_heal() -> void:
	var player := _make_player("priest", "priest_reliquary")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("reliquary: у Жреца нет equipped_weapon для priest_reliquary")
		player.free()
		await process_frame
		return
	# Глушим авто-атаку ДО первого кадра: иначе weapon._process (cooldown 0)
	# выстрелит на первом же process_frame и наплодит tween-пульсы, которые
	# позже задевают тестовых врагов (стрэй-урон).
	weapon.set_process(false)
	weapon.set_physics_process(false)
	await process_frame
	_neutralize_player(player)
	# Нейтрализуем мета-моды (тест читает реальный dev-сейв с разлоками): убирает
	# reliquary_barrage_mode/vow/twin — оружие в базовом поведении.
	player.set("run_modifiers", {})
	var max_hp := float(player.get("max_health"))
	player.set("health", maxf(max_hp * 0.4, 1.0))
	player.set("_damage_invulnerability_left", 0.0)
	var hp_before := float(player.get("health"))
	var aoe := float(weapon.get("aoe_radius"))
	var center := player.global_position + Vector2(300.0, 0.0)
	var near := _make_dummy_enemy(center)
	# Дальний враг заведомо вне малого радиуса тика (3× радиуса).
	var far := _make_dummy_enemy(center + Vector2(aoe * 3.0, 0.0))
	await process_frame
	near.set_meta("damage_taken", 0.0)
	far.set_meta("damage_taken", 0.0)
	var tick_damage := maxf(float(weapon.get("damage")) * float(weapon.get("sanctify_tick_ratio")), 1.0)
	weapon.call("_sanctify_burst_tick", player.get_instance_id(), near.get_instance_id(), center, Vector2.RIGHT, 0, int(weapon.get("storm_ticks")), tick_damage)
	var near_dmg := float(near.get_meta("damage_taken"))
	var far_dmg := float(far.get_meta("damage_taken"))
	if near_dmg <= 0.0:
		_errors.append("reliquary: тик бурста не нанёс урон цели в радиусе")
	# Малый радиус: дальний враг — максимум вторичный грейз on-hit, не полный тик.
	elif far_dmg > near_dmg * 0.5:
		_errors.append("reliquary: дальний враг получил %.2f (>%.2f×0.5) — радиус тика не мал" % [far_dmg, near_dmg])
	# Ключевой AC SCRUM-927: реликварий НЕ лечит Жреца от нанесённого урона.
	if float(player.get("health")) > hp_before + EPS:
		_errors.append("reliquary: HP выросло после урона — оружие лечит (SCRUM-927 запрещает)")
	player.free()
	near.free()
	far.free()
	await process_frame


# --- SCRUM-928: кадило — большой БЛИЗКИЙ AoE без скрытого сустейна --------------
# Самая широкая волна кадила достигает ПОЛНОГО aoe_radius (SCRUM-928: lerp до 1.0),
# накрывая врага у 0.9× радиуса и не задевая врага за радиусом; хила на атаке нет.

func _check_censer_large_close_aoe() -> void:
	var player := _make_player("priest", "priest_censer")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("censer: у Жреца нет equipped_weapon для priest_censer")
		player.free()
		await process_frame
		return
	# Глушим авто-атаку ДО первого кадра (см. reliquary): без этого ward-пульсы
	# первого выстрела задевают тестовых врагов вне проверяемого радиуса.
	weapon.set_process(false)
	weapon.set_physics_process(false)
	await process_frame
	_neutralize_player(player)
	# Нейтрализуем мета-моды (тест читает реальный dev-сейв с разлоками): без этого
	# мета-хуки on-hit (heal_to_holy chain и т.п.) добавляют стрэй-урон рядом.
	player.set("run_modifiers", {})
	var max_hp := float(player.get("max_health"))
	player.set("health", maxf(max_hp * 0.4, 1.0))
	player.set("_damage_invulnerability_left", 0.0)
	var hp_before := float(player.get("health"))
	var aoe := float(weapon.get("aoe_radius"))
	var origin: Vector2 = player.global_position
	# Враг у ПОЛНОГО радиуса (0.9×) — большой близкий AoE обязан его накрыть;
	# дальний враг (1.5×) — вне круга (максимум вторичный on-hit грейз).
	var inside := _make_dummy_enemy(origin + Vector2(aoe * 0.9, 0.0))
	var outside := _make_dummy_enemy(origin + Vector2(aoe * 1.5, 0.0))
	await process_frame
	inside.set_meta("damage_taken", 0.0)
	outside.set_meta("damage_taken", 0.0)
	# Урон самой широкой волны (примитив, который дёргает tween-цикл _fire_priest_ward).
	weapon.call("_damage_enemies_in_circle", origin, aoe, maxf(float(weapon.get("damage")), 1.0))
	var inside_dmg := float(inside.get_meta("damage_taken"))
	var outside_dmg := float(outside.get_meta("damage_taken"))
	if inside_dmg <= 0.0:
		_errors.append("censer: враг у 0.9× радиуса не накрыт — большой AoE не достаёт полного радиуса")
	# Круг ограничен: внешний враг — максимум вторичный грейз, не полный член AoE.
	elif outside_dmg > inside_dmg * 0.5:
		_errors.append("censer: внешний враг получил %.2f (>%.2f×0.5) — радиус волны не ограничен" % [outside_dmg, inside_dmg])
	# SCRUM-928: скрытого оружейного хила на атаке нет.
	if float(player.get("health")) > hp_before + EPS:
		_errors.append("censer: HP выросло после урона — скрытый оружейный сустейн")
	player.free()
	inside.free()
	outside.free()
	await process_frame


# --- SCRUM-929: колокол — dual toll (два центра, дедуп, без самоурона) ----------

func _check_bell_dual_toll() -> void:
	# A. Двойной взрыв: дальняя цель И ближний к жрецу враг бьются одним кастом,
	#    враг между центрами не задет (два дискретных центра, не один большой круг).
	var player := _make_player("priest", "priest_chime")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("bell: у Жреца нет equipped_weapon для priest_chime")
		player.free()
		await process_frame
		return
	# Глушим авто-атаку ДО первого кадра (см. reliquary).
	weapon.set_process(false)
	weapon.set_physics_process(false)
	await process_frame
	_neutralize_player(player)
	# Нейтрализуем мета-моды (dev-сейв): убирает chime_twin_toll (эхо-tween) и пр.
	player.set("run_modifiers", {})
	player.set("health", float(player.get("max_health")))
	player.set("_damage_invulnerability_left", 0.0)
	var hp_before := float(player.get("health"))
	var aoe := float(weapon.get("aoe_radius"))
	var origin: Vector2 = player.global_position
	var far_target := _make_dummy_enemy(origin + Vector2(aoe * 3.0, 0.0))
	var near_priest := _make_dummy_enemy(origin + Vector2(aoe * 0.25, 0.0))
	var between := _make_dummy_enemy(origin + Vector2(aoe * 1.6, 0.0))
	await process_frame
	for e in [far_target, near_priest, between]:
		(e as Node).set_meta("damage_taken", 0.0)
	weapon.call("_fire_priest_dual_toll", player, far_target, Vector2.RIGHT)
	var far_dmg := float(far_target.get_meta("damage_taken"))
	var near_dmg := float(near_priest.get_meta("damage_taken"))
	var between_dmg := float(between.get_meta("damage_taken"))
	if far_dmg <= 0.0:
		_errors.append("bell: дальняя цель не получила взрыв (target-центр отсутствует)")
	if near_dmg <= 0.0:
		_errors.append("bell: ближний к жрецу враг не получил взрыв (priest-центр отсутствует)")
	# Два ДИСКРЕТНЫХ центра: враг между ними — максимум вторичный грейз, не полный взрыв.
	if between_dmg > minf(far_dmg, near_dmg) * 0.5:
		_errors.append("bell: враг МЕЖДУ центрами получил %.2f — взрыв не два дискретных центра" % between_dmg)
	if float(player.get("health")) < hp_before - EPS:
		_errors.append("bell: жрец получил самоурон от своего взрыва (SCRUM-929: самоурона нет)")
	player.free()
	far_target.free()
	near_priest.free()
	between.free()
	await process_frame

	# B. Перекрытие капится: враг в радиусе ОБОИХ центров ловит РОВНО один взрыв
	#    (дедуп по instance id), а не двойной фулл-урон.
	var player2 := _make_player("priest", "priest_chime")
	var weapon2: Node = player2.get("equipped_weapon")
	if weapon2 == null:
		_errors.append("bell: нет weapon2 для проверки дедупа")
		player2.free()
		await process_frame
		return
	weapon2.set_process(false)
	weapon2.set_physics_process(false)
	await process_frame
	_neutralize_player(player2)
	player2.set("run_modifiers", {})
	var o2: Vector2 = player2.global_position
	var close_target := _make_dummy_enemy(o2 + Vector2(120.0, 0.0))
	var overlap := _make_dummy_enemy(o2 + Vector2(60.0, 0.0))
	var solo := _make_dummy_enemy(o2 + Vector2(-150.0, 0.0))
	await process_frame
	for e in [close_target, overlap, solo]:
		(e as Node).set_meta("damage_taken", 0.0)
	weapon2.call("_fire_priest_dual_toll", player2, close_target, Vector2.RIGHT)
	var overlap_dmg := float(overlap.get_meta("damage_taken"))
	var solo_dmg := float(solo.get_meta("damage_taken"))
	if solo_dmg <= 0.0:
		_errors.append("bell: контрольный враг (один центр) не получил урон")
	elif overlap_dmg <= 0.0:
		_errors.append("bell: враг в перекрытии не получил урон вовсе")
	elif overlap_dmg > solo_dmg * 1.5:
		_errors.append("bell: перекрытие дало %.2f > %.2f×1.5 — двойной фулл-урон (дедуп сломан, SCRUM-929)" % [overlap_dmg, solo_dmg])
	player2.free()
	close_target.free()
	overlap.free()
	solo.free()
	await process_frame
