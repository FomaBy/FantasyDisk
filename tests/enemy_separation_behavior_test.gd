extends SceneTree

# Combat Feel Rework (этап B): анти-прилипание — естественное поведение монстров.
# Контракты:
#  (a) melee с 400px подходит к игроку, останавливается у engage-кольца
#      (d стабилизируется в [0.6, 1.0]×contact_range) и наносит контакт-удар;
#  (b) враг, поставленный ТОЧНО на игрока, мягко отходит, но добровольно
#      НИКОГДА не дальше 0.8×contact_range (уптайм контакт-урона) и всё равно
#      попадает ударом после замаха;
#  (c) два врага, наложенные в одну точку в 300px от игрока, расходятся
#      steering-сепарацией на ≥30px, оба остаются в contact_range (engaged);
#  (d) стрелок в hold-полосе НЕ замерзает: тангенциальный строб (velocity != 0);
#  (e) спавн-фильтр меряет до ЖИВОГО игрока: точка в 100px от игрока вдали от
#      центра арены отклоняется; given-position спавн выталкивается на ≥320px.
#
# Движение гоняется вручную: enemy.set_physics_process(false) + прямые вызовы
# _physics_process(1/60) — move_and_slide внутри использует физический тик 1/60,
# поэтому dt согласован с фактическим смещением (как в runtime_smoke_combat).
#
# Запуск: Godot --headless --path . --script res://tests/enemy_separation_behavior_test.gd

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const COMBAT_DIRECTOR_SCRIPT := preload("res://scripts/combat_director.gd")

const DT := 1.0 / 60.0


# Стоячая цель: только то, что нужно contact-пути врага (take_damage/max_health).
class PlayerStub:
	extends Node2D
	var max_health := 100.0
	var health := 100.0
	var hits_taken := 0

	func take_damage(amount: float, _source = "", _attacker = null) -> bool:
		hits_taken += 1
		health = maxf(health - amount, 0.0)
		return true


# Мини-контекст game для RefCounted CombatDirector (см. main.gd поля/константы).
class GameStub:
	extends Node2D
	var current_player: Node2D = null
	var rng := RandomNumberGenerator.new()
	var ARENA_SIZE := Vector2(4096, 2304)
	var ARENA_CENTER := Vector2(2048, 1152)
	var SPAWN_PLAYER_SAFE_RADIUS := 420.0
	var SPAWN_EDGE_PADDING := 72.0
	var OBSTACLE_MAX_ATTEMPTS := 150


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
	# Движением управляет тест (ручные тики), авто-физика выключена.
	enemy.set_physics_process(false)
	return enemy


func _cleanup(nodes: Array) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()


func _initialize() -> void:
	seed(20260712)
	var errors: Array[String] = []
	await process_frame

	await _test_melee_arrival(errors)
	await _test_deep_overlap_backoff(errors)
	await _test_pair_separation(errors)
	await _test_shooter_strafe(errors)
	await _test_spawn_protection(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Enemy separation behavior: %s" % error)
		quit(1)
		return
	print("Enemy separation behavior test passed.")
	quit(0)


# (a) Подход с 400px: остановка у engage-кольца + контакт-удар.
func _test_melee_arrival(errors: Array[String]) -> void:
	var player := _make_player(Vector2(2048, 1152))
	var enemy := _make_enemy(player.global_position + Vector2(400, 0))
	await process_frame
	var contact_range := float(enemy.get("contact_range"))

	var min_settled := INF
	var max_settled := 0.0
	for tick in range(900):
		enemy.call("_physics_process", DT)
		if tick >= 600:
			var d: float = enemy.global_position.distance_to(player.global_position)
			min_settled = minf(min_settled, d)
			max_settled = maxf(max_settled, d)

	if max_settled > contact_range:
		errors.append("(a) melee не остановился у кольца: max d=%.1f > contact_range=%.1f." % [max_settled, contact_range])
	if min_settled < contact_range * 0.6:
		errors.append("(a) melee прилип глубже кольца: min d=%.1f < 0.6×contact_range=%.1f." % [min_settled, contact_range * 0.6])
	if player.hits_taken < 1:
		errors.append("(a) melee с кольца не нанёс ни одного контакт-удара (uptime потерян).")
	print("INFO (a): settled d=[%.1f, %.1f], contact_range=%.1f, hits=%d" % [min_settled, max_settled, contact_range, player.hits_taken])

	_cleanup([enemy, player])
	await process_frame


# (b) Глубокий оверлап: отход не дальше 0.8×contact_range, удар всё равно попадает.
func _test_deep_overlap_backoff(errors: Array[String]) -> void:
	var player := _make_player(Vector2(2048, 1152))
	var enemy := _make_enemy(player.global_position)
	await process_frame
	var contact_range := float(enemy.get("contact_range"))

	var max_distance := 0.0
	for tick in range(900):
		enemy.call("_physics_process", DT)
		max_distance = maxf(max_distance, enemy.global_position.distance_to(player.global_position))

	if max_distance > contact_range * 0.8 + 4.0:
		errors.append("(b) отход из оверлапа ушёл за 0.8×contact_range: max d=%.1f > %.1f." % [max_distance, contact_range * 0.8])
	if max_distance < 1.0:
		errors.append("(b) враг вообще не отошёл из глубокого оверлапа (max d=%.2f)." % max_distance)
	if player.hits_taken < 1:
		errors.append("(b) враг из оверлапа не нанёс контакт-удар — замах сорван отходом.")
	print("INFO (b): max backoff d=%.1f (cap %.1f), hits=%d" % [max_distance, contact_range * 0.8, player.hits_taken])

	_cleanup([enemy, player])
	await process_frame


# (c) Два врага в одной точке расходятся сепарацией, оба остаются engaged.
func _test_pair_separation(errors: Array[String]) -> void:
	var player := _make_player(Vector2(2048, 1152))
	var stack_position: Vector2 = player.global_position + Vector2(300, 0)
	var enemy_a := _make_enemy(stack_position)
	var enemy_b := _make_enemy(stack_position)
	await process_frame
	var contact_range := float(enemy_a.get("contact_range"))

	for tick in range(900):
		enemy_a.call("_physics_process", DT)
		enemy_b.call("_physics_process", DT)

	var pair_distance: float = enemy_a.global_position.distance_to(enemy_b.global_position)
	var d_a: float = enemy_a.global_position.distance_to(player.global_position)
	var d_b: float = enemy_b.global_position.distance_to(player.global_position)
	if pair_distance < 30.0:
		errors.append("(c) наложенные враги не разошлись: дистанция пары %.1f < 30px." % pair_distance)
	if d_a > contact_range or d_b > contact_range:
		errors.append("(c) сепарация вытолкнула врага из contact_range: d=[%.1f, %.1f] > %.1f." % [d_a, d_b, contact_range])
	print("INFO (c): pair distance=%.1f, d to player=[%.1f, %.1f], contact_range=%.1f" % [pair_distance, d_a, d_b, contact_range])

	_cleanup([enemy_a, enemy_b, player])
	await process_frame


# (d) Стрелок в hold-полосе стробит (не freeze).
func _test_shooter_strafe(errors: Array[String]) -> void:
	var player := _make_player(Vector2(2048, 1152))
	var desired := 280.0
	var enemy := _make_enemy(player.global_position + Vector2(desired * 0.85, 0.0))
	enemy.set("can_shoot", true)
	enemy.set("desired_shooting_distance", desired)
	await process_frame

	enemy.call("_physics_process", DT)
	var strafe_velocity: Vector2 = enemy.get("velocity")
	if strafe_velocity.length() < 5.0:
		errors.append("(d) стрелок в hold-полосе заморожен: |velocity|=%.2f (ожидали строб)." % strafe_velocity.length())
	else:
		var toward: Vector2 = (player.global_position - enemy.global_position).normalized()
		var radial_share: float = absf(strafe_velocity.normalized().dot(toward))
		if radial_share > 0.5:
			errors.append("(d) строб не тангенциален: радиальная доля %.2f > 0.5." % radial_share)
	print("INFO (d): strafe velocity=%s (|v|=%.1f)" % [strafe_velocity, strafe_velocity.length()])

	_cleanup([enemy, player])
	await process_frame


# (e) Спавн-фильтр меряет до живого игрока; given-позиции выталкиваются на 320px.
func _test_spawn_protection(errors: Array[String]) -> void:
	var game := GameStub.new()
	root.add_child(game)
	# Игрок далеко от центра арены (у верхне-правого края).
	var player := _make_player(Vector2(3400, 400))
	game.current_player = player
	await process_frame

	var director = COMBAT_DIRECTOR_SCRIPT.new(game)

	var near_player: Vector2 = player.global_position + Vector2(100, 0)
	if bool(director.call("_is_spawn_position_clear", near_player)):
		errors.append("(e) точка в 100px от живого игрока принята (фильтр всё ещё меряет до ARENA_CENTER).")
	# Центр арены далеко от игрока — теперь легальная точка спавна.
	if not bool(director.call("_is_spawn_position_clear", game.ARENA_CENTER)):
		errors.append("(e) точка у центра арены (игрок далеко) отклонена — фильтр не перешёл на живого игрока.")
	# given-position спавн (пачка/свита) выталкивается от игрока на ≥320px.
	var pushed: Vector2 = director.call("_push_spawn_from_player", player.global_position + Vector2(50, 0), 320.0)
	if pushed.distance_to(player.global_position) < 320.0 - 0.5:
		errors.append("(e) given-position спавн не вытолкнут: d=%.1f < 320." % pushed.distance_to(player.global_position))
	print("INFO (e): near reject OK, center accept OK, pushed d=%.1f" % pushed.distance_to(player.global_position))

	_cleanup([player, game])
	await process_frame
