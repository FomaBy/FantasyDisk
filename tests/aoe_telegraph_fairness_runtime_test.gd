extends SceneTree

# Combat Feel Rework, этап C (runtime-гейт честных АОЕ):
#  (a) элитная ядовитая зона: при спавне существует ребёнок HazardTelegraph, а
#      детонация происходит НЕ РАНЬШЕ пола CombatFairness.fair_windup;
#  (b) night_stalker фаза-2, второй теневой удар: цель — СНАПШОТ точки на момент
#      спавна телеграфа; игрок, ушедший дальше радиуса от снапшота, урона НЕ
#      получает; оставшийся — получает;
#  (c) рывок элитки-сталкера: первые 0.4s после решения — замах (позиция и
#      скорость не меняются), направление рывка залочено в момент решения даже
#      если игрок ушёл.
#
# Время меряется суммой process-дельт по кадрам (та же шкала, что двигает tween'ы).
#
# Запуск: python3 tools/godot_gate.py --headless --path . --script res://tests/aoe_telegraph_fairness_runtime_test.gd

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const CombatFairnessScript := preload("res://scripts/combat_fairness.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

var _errors: Array = []


class StubPlayer extends Node2D:
	var max_health := 1000.0
	var health := 1000.0
	var hits: Array = []

	func take_damage(amount: float, source := "", _attacker: Node2D = null) -> bool:
		hits.append({"amount": amount, "source": str(source)})
		health -= amount
		return true


func _fail(msg: String) -> void:
	_errors.append(msg)


func _make_elite(holder: Node, behavior: String) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.set("elite_behavior", behavior)
	enemy.set("enemy_type_name", behavior)
	enemy.add_to_group("enemies")
	enemy.add_to_group("elite_enemies")
	holder.add_child(enemy)
	# Гоняем фазы руками — авто-ИИ выключаем, чтобы тест был детерминирован.
	enemy.set_physics_process(false)
	enemy.set("contact_damage", 5.0)
	enemy.set("max_health", 100.0)
	enemy.set("health", 100.0)
	return enemy


func _initialize() -> void:
	seed(20260712)
	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var stub := StubPlayer.new()
	holder.add_child(stub)
	stub.add_to_group("player")
	stub.global_position = Vector2(900.0, 700.0)
	await process_frame

	await _test_elite_poison_hazard_floor(holder, stub)
	await _test_night_stalker_snapshot(holder, stub)
	await _test_stalker_dash_windup_lock(holder, stub)

	holder.queue_free()
	await process_frame

	if not _errors.is_empty():
		for e in _errors:
			push_error("AoE telegraph fairness: %s" % e)
		push_error("AoE telegraph fairness runtime test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("AoE telegraph fairness runtime test passed: пол детонации, снапшот второго удара и замах рывка честны.")
	quit(0)


# --- (a) элитная ядовитая зона --------------------------------------------
func _test_elite_poison_hazard_floor(holder: Node2D, stub: StubPlayer) -> void:
	var poison := _make_elite(holder, "plague_prophet")
	poison.global_position = stub.global_position + Vector2(240.0, 0.0)
	poison.set("elite_hazard_damage", 5.0)
	await process_frame

	stub.hits.clear()
	var expected_floor: float = CombatFairnessScript.fair_windup(0.55, 72.0, 1.0, stub)
	poison.call("_spawn_elite_hazard", stub.global_position)
	var elapsed := 0.0

	var hazard := holder.find_child("ElitePoisonZone", true, false)
	if hazard == null:
		_fail("(a) зона ElitePoisonZone не заспавнилась")
		return
	if hazard.get_node_or_null("HazardTelegraph") == null:
		_fail("(a) у зоны нет ребёнка HazardTelegraph — телеграф обязателен")
		return

	# Рано (заметно ниже пола ~0.69s) урона быть не должно.
	while elapsed < 0.32:
		await process_frame
		elapsed += root.get_process_delta_time()
	if not stub.hits.is_empty():
		_fail("(a) урон прошёл на %.2fs — раньше честного окна %.2fs" % [elapsed, expected_floor])
		return

	# Ждём детонацию (щедрый таймаут по движковому времени) и сверяем момент с полом.
	while stub.hits.is_empty() and elapsed < expected_floor + 2.0:
		await process_frame
		elapsed += root.get_process_delta_time()
	if stub.hits.is_empty():
		_fail("(a) детонация так и не случилась (таймаут)")
		return
	if elapsed + 0.08 < expected_floor:
		_fail("(a) детонация на %.2fs раньше пола fair_windup %.2fs" % [elapsed, expected_floor])
	if str((stub.hits[0] as Dictionary).get("source", "")) != "poison_zone":
		_fail("(a) неожиданный источник урона: %s" % str((stub.hits[0] as Dictionary).get("source", "")))
	poison.queue_free()
	await process_frame


# --- (b) night_stalker: второй удар бьёт только по снапшоту -----------------
func _test_night_stalker_snapshot(holder: Node2D, stub: StubPlayer) -> void:
	var cfg: Dictionary = ProgressionData.elite_attack_config("night_stalker")
	if cfg.is_empty():
		_fail("(b) config night_stalker пуст")
		return
	var radius := float(cfg.get("radius", 92.0))
	var behind := float(cfg.get("behind_offset", 74.0))
	if behind > radius:
		_fail("(b) config: behind_offset больше радиуса — сценарий «остался в зоне» невозможен")
		return

	var stalker := _make_elite(holder, "night_stalker")
	stalker.set("health", 30.0)  # фаза 2 (порог 0.5) → серия из двух ударов
	stalker.global_position = stub.global_position + Vector2(-300.0, 0.0)
	await process_frame

	# Кейс 1: игрок сбегает от снапшота дальше радиуса → урона НЕТ.
	stub.hits.clear()
	stub.global_position = Vector2(900.0, 700.0)
	var snapshot: Vector2 = stub.global_position - Vector2.RIGHT * behind
	stalker.set("_elite_attack_direction", Vector2.RIGHT)
	# Первый удар уводим в заведомый промах (далеко от игрока).
	stalker.set("_elite_attack_targets", [stub.global_position + Vector2(600.0, 0.0)])
	stalker.call("_strike_shadow_strike", cfg, stub)
	# Телеграф второго удара существует и стоит в снапшоте (учитываем авто-
	# переименование дублей add_child'ом — матчим по подстроке имени).
	var telegraph_found := false
	for node in holder.find_children("*EliteAttackTelegraph*", "Node2D", true, false):
		if (node as Node2D).global_position.distance_to(snapshot) < 1.0:
			telegraph_found = true
	if not telegraph_found:
		_fail("(b) телеграф второго удара в точке снапшота не найден")
	# Сбегаем сразу после спавна телеграфа.
	stub.global_position = snapshot + Vector2(400.0, 0.0)
	var waited := 0.0
	while stalker.global_position.distance_to(snapshot) > 1.0 and waited < 4.0:
		await process_frame
		waited += root.get_process_delta_time()
	if waited >= 4.0:
		_fail("(b) второй удар не исполнился (телепорт в снапшот не случился)")
		return
	if waited + 0.05 < 0.35:
		_fail("(b) окно второго удара %.2fs короче обязательных 0.35s" % waited)
	await process_frame
	if not stub.hits.is_empty():
		_fail("(b) сбежавший за радиус игрок получил урон — удар не по снапшоту")

	# Кейс 2: игрок остаётся в радиусе снапшота → урон проходит.
	stub.hits.clear()
	stub.global_position = Vector2(1400.0, 900.0)
	stalker.set("health", 30.0)
	stalker.set("_elite_attack_direction", Vector2.RIGHT)
	stalker.set("_elite_attack_targets", [stub.global_position + Vector2(600.0, 0.0)])
	stalker.call("_strike_shadow_strike", cfg, stub)
	# Игрок стоит: дистанция до снапшота = behind_offset (74) ≤ radius (92).
	var stay_waited := 0.0
	while stub.hits.is_empty() and stay_waited < 4.0:
		await process_frame
		stay_waited += root.get_process_delta_time()
	if stub.hits.is_empty():
		_fail("(b) оставшийся в радиусе снапшота игрок НЕ получил урон второго удара")
	elif str((stub.hits[0] as Dictionary).get("source", "")) != "elite_shadow_strike":
		_fail("(b) неожиданный источник урона второго удара: %s" % str((stub.hits[0] as Dictionary).get("source", "")))
	stalker.queue_free()
	await process_frame


# --- (c) рывок сталкера: замах без движения + залоченное направление --------
func _test_stalker_dash_windup_lock(holder: Node2D, stub: StubPlayer) -> void:
	var dasher := _make_elite(holder, "night_stalker")
	dasher.global_position = Vector2(2000.0, 1200.0)
	stub.global_position = dasher.global_position + Vector2(200.0, 0.0)
	await process_frame

	dasher.set("_elite_dash_cooldown", 0.0)
	dasher.call("_prepare_elite_dash", 0.0, stub, 200.0)
	if float(dasher.get("_elite_dash_windup_left")) <= 0.0:
		_fail("(c) решение о рывке обязано взводить замах (windup_left > 0)")
		return
	if float(dasher.get("_elite_dash_time_left")) > 0.0:
		_fail("(c) рывок стартовал в кадр решения — ноль-телеграф не починен")
		return
	if float(dasher.get("_elite_dash_cooldown")) <= 0.0:
		_fail("(c) кулдаун рывка обязан взводиться с решения (прежняя семантика)")
	var locked: Vector2 = dasher.get("_elite_dash_direction")
	if locked.distance_to(Vector2.RIGHT) > 0.01:
		_fail("(c) направление обязано лочиться на игрока в момент решения")

	# Игрок уходит вбок — направление меняться не должно, позиция стоит 0.4s.
	stub.global_position = dasher.global_position + Vector2(0.0, 300.0)
	var start_position: Vector2 = dasher.global_position
	for _i in range(8):  # 8 × 0.05 = 0.40s замаха
		dasher.call("_physics_process", 0.05)
		if dasher.global_position.distance_to(start_position) > 0.5:
			_fail("(c) элитка сдвинулась во время замаха рывка")
			return
		if (dasher.get("velocity") as Vector2).length() > 0.01:
			_fail("(c) скорость во время замаха обязана быть нулевой")
			return

	# Замах истёк → рывок стартует по направлению, залоченному при решении.
	dasher.call("_physics_process", 0.05)
	if float(dasher.get("_elite_dash_time_left")) <= 0.0:
		_fail("(c) по истечении замаха рывок обязан стартовать")
		return
	var direction_after: Vector2 = dasher.get("_elite_dash_direction")
	if direction_after.distance_to(Vector2.RIGHT) > 0.01:
		_fail("(c) направление рывка изменилось после решения — лока нет")
	dasher.call("_physics_process", 0.05)
	var dash_velocity: Vector2 = dasher.get("velocity")
	if dash_velocity.x <= 0.0 or absf(dash_velocity.y) > 0.01:
		_fail("(c) рывок обязан лететь по залоченному направлению (+X), получено %s" % str(dash_velocity))
	dasher.queue_free()
	await process_frame
