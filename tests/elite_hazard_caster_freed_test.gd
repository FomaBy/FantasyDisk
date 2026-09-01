extends SceneTree

# Аудит 2026-07 (долг FAN-1040): отложенные tween-колбэки элитных хазардов
# ссылались на кастера (`self`). Если элита умирала во время замаха или полёта,
# лямбда вызывалась на освобождённом объекте: ошибка в логе, `ElitePoisonLob`
# навсегда зависал на арене, зона и лужа переставали бить игрока. Контракты:
#  (a) лоб, чей кастер освобождён в полёте, всё равно удаляется (нет утечки ноды);
#  (b) зона `ElitePoisonZone`, чей кастер освобождён во время замаха, детонирует
#      по своему таймлайну (игрок в центре получает удар) и удаляется;
#  (c) уже лежащая лужа продолжает тикать по игроку после смерти кастера и
#      удаляется по истечении срока.
#
# Запуск: Godot --headless --path . --script res://tests/elite_hazard_caster_freed_test.gd

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")


class PlayerStub:
	extends Node2D
	var hits_taken := 0

	func take_damage(_amount: float, _source = "", _attacker = null) -> bool:
		hits_taken += 1
		return true


func _make_player(position: Vector2) -> PlayerStub:
	var player := PlayerStub.new()
	player.global_position = position
	player.add_to_group("player")
	root.add_child(player)
	return player


func _make_enemy(position: Vector2) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	root.add_child(enemy)
	enemy.global_position = position
	enemy.set_physics_process(false)
	return enemy


func _initialize() -> void:
	var errors: Array[String] = []
	await process_frame

	await _test_lob_without_caster(errors)
	await _test_zone_without_caster(errors)
	await _test_puddle_without_caster(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Elite hazard caster freed: %s" % error)
		quit(1)
		return
	print("Elite hazard caster freed test passed.")
	quit(0)


# (a) Лоб в полёте, кастер освобождён до приземления.
func _test_lob_without_caster(errors: Array[String]) -> void:
	var player := _make_player(Vector2(1000, 1000))
	var enemy := _make_enemy(Vector2(700, 1000))
	await process_frame
	enemy.call("_spawn_poison_lob", Vector2(1000, 1000), 0.05, 3.0, {"puddle_duration": 0.2, "tick_interval": 0.1})
	if root.get_node_or_null("ElitePoisonLob") == null:
		errors.append("(a) лоб не заспавнился — тест не покрывает контракт.")
	enemy.free()
	await create_timer(0.5).timeout
	if root.get_node_or_null("ElitePoisonLob") != null:
		errors.append("(a) лоб освобождённого кастера завис на арене (утечка ноды).")
	for hazard in root.get_tree().get_nodes_in_group("enemy_hazards"):
		hazard.queue_free()
	player.queue_free()
	await process_frame


# (b) Зона в замахе, кастер освобождён до детонации.
func _test_zone_without_caster(errors: Array[String]) -> void:
	var player := _make_player(Vector2(1000, 1000))
	var enemy := _make_enemy(Vector2(700, 1000))
	await process_frame
	var windup: float = CombatFairness.fair_windup(ENEMY_SCRIPT.ELITE_HAZARD_WINDUP_BASE, ENEMY_SCRIPT.ELITE_HAZARD_RADIUS, 1.0, player)
	enemy.call("_spawn_elite_hazard", player.global_position)
	if root.get_node_or_null("ElitePoisonZone") == null:
		errors.append("(b) зона не заспавнилась — тест не покрывает контракт.")
	enemy.free()
	await create_timer(windup + 0.3).timeout
	if player.hits_taken < 1:
		errors.append("(b) зона освобождённого кастера не детонировала по игроку в центре (windup=%.2f)." % windup)
	await create_timer(1.5).timeout
	if root.get_node_or_null("ElitePoisonZone") != null:
		errors.append("(b) зона освобождённого кастера не удалилась после детонации.")
	player.queue_free()
	await process_frame


# (c) Лужа уже лежит, кастер освобождён — тики по игроку продолжаются.
func _test_puddle_without_caster(errors: Array[String]) -> void:
	var player := _make_player(Vector2(1000, 1000))
	var enemy := _make_enemy(Vector2(700, 1000))
	await process_frame
	enemy.call("_spawn_poison_puddle", player.global_position, 2.0, {"puddle_duration": 0.5, "tick_interval": 0.1, "radius": 56.0})
	if root.get_node_or_null("ElitePoisonPuddle") == null:
		errors.append("(c) лужа не заспавнилась — тест не покрывает контракт.")
	enemy.free()
	await create_timer(0.7).timeout
	if player.hits_taken < 2:
		errors.append("(c) лужа освобождённого кастера перестала тикать (hits=%d)." % player.hits_taken)
	await create_timer(0.5).timeout
	if root.get_node_or_null("ElitePoisonPuddle") != null:
		errors.append("(c) лужа освобождённого кастера не удалилась по истечении срока.")
	player.queue_free()
	await process_frame
