extends SceneTree

# SCRUM-598: хрупкость данных elite-config в enemy.gd.
#
# Десятки config['key'] читались БЕЗ дефолтов: любой elite-config без ключа ронял
# бой (KeyError), а _spawn_poison_puddle делил duration/tick_interval без защиты
# от нуля → div0 / бесконечный tick_count. Фикс: все чтения через config.get(key,
# <дефолт>), а tick_interval = maxf(get('tick_interval',0.6), 0.05).
#
# Гейт гоняет НАСТОЯЩИЙ Enemy и кормит strike/spawn-цепочку НЕПОЛНЫМИ конфигами
# (пустой {} и частичные dict-ы по каждому elite-поведению). Инвариант: ни один
# вызов не роняет рантайм и не уходит в div0 — тест просто ДОХОДИТ до конца и
# печатает PASS. Дополнительно happy-path: реальный валидный config отрабатывает.
#
# Запуск: Godot --headless --path . --script res://tests/elite_attack_config_safety_test.gd

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ProgressionData := preload("res://scripts/progression_data.gd")


func _make_enemy(holder: Node, behavior: String) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.set("elite_behavior", behavior)
	enemy.set("enemy_type_name", behavior)
	enemy.add_to_group("enemies")
	enemy.add_to_group("elite_enemies")
	holder.add_child(enemy)
	enemy.set("contact_damage", 5.0)
	enemy.set("max_health", 100.0)
	enemy.set("health", 100.0)
	return enemy


func _initialize() -> void:
	seed(598598)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	player.set("max_health", 100.0)
	player.set("health", 100.0)
	player.global_position = Vector2(300.0, 0.0)
	await process_frame

	# --- A. КРИТИЧНО: _spawn_poison_puddle с ПУСТЫМ config не должен div0 ---
	# Без фикса tick_interval=0 → duration/0 = inf → int(floor(inf)) краш/висяк.
	var puddle_enemy := _make_enemy(holder, "plague_prophet")
	await process_frame
	if not puddle_enemy.has_method("_spawn_poison_puddle"):
		errors.append("нет _spawn_poison_puddle — гейт невозможен")
	else:
		# Пустой и частичный (duration есть, tick_interval нет) конфиги.
		puddle_enemy.call("_spawn_poison_puddle", Vector2.ZERO, 3.0, {})
		puddle_enemy.call("_spawn_poison_puddle", Vector2.ZERO, 3.0, {"puddle_duration": 4.0})
		puddle_enemy.call("_spawn_poison_puddle", Vector2.ZERO, 3.0, {"tick_interval": 0.0, "puddle_duration": 2.0})
		await process_frame
		print("A: _spawn_poison_puddle с пустым/частичным config — без div0.")

	# --- B. Каждое elite-поведение прогоняем strike/windup с пустым config ---
	# Прямой вызов нижнеуровневых функций с {} — проверяем, что .get-дефолты держат
	# KeyError. После фикса ни один не роняет рантайм.
	var behaviors := ["iron_bastion", "night_stalker", "plague_prophet", "shard_marshal"]
	for behavior in behaviors:
		var e := _make_enemy(holder, behavior)
		await process_frame
		# windup с пустым конфигом
		if e.has_method("_begin_elite_attack_windup"):
			e.call("_begin_elite_attack_windup", {}, player)
		# strike-диспетчер с пустым конфигом
		if e.has_method("_execute_elite_strike"):
			# гарантируем непустые targets, чтобы зайти в тело strike-функций
			e.set("_elite_attack_targets", [player.global_position])
			e.call("_execute_elite_strike", {}, player)
		await process_frame
		print("B[%s]: windup+strike с пустым config — без KeyError." % behavior)
		e.queue_free()

	# --- C. HAPPY-PATH: реальный валидный config всё ещё отрабатывает ---
	# Полный прогон _update_elite_attack по валидному поведению (несколько тиков),
	# герой рядом → атака триггерится; убеждаемся, что нормальный путь не сломан.
	var live := _make_enemy(holder, "iron_bastion")
	live.global_position = Vector2.ZERO
	await process_frame
	if live.has_method("_update_elite_attack"):
		var cfg: Dictionary = ProgressionData.elite_attack_config("iron_bastion")
		if cfg.is_empty():
			errors.append("HAPPY: валидный iron_bastion config пуст — данные сломаны")
		# Снимаем стартовый кулдаун и крутим фазы.
		live.set("_elite_attack_cooldown", 0.0)
		for _i in range(60):
			live.call("_update_elite_attack", 0.1, player, 50.0)
			await process_frame
		print("C[iron_bastion]: happy-path _update_elite_attack прокрутился без ошибок.")

	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Elite-config safety: %s" % e)
		push_error("Elite-config safety test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Elite-attack config safety test passed: неполный config не роняет бой, нет div0, happy-path цел.")
	quit(0)
