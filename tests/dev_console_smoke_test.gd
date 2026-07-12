extends "res://tests/runtime_smoke_test.gd"

# SCRUM-831/SCRUM-845: смоук дев-консоли (~). Проверяет: тоггл синтетической
# тильдой без глобальной паузы, help/ошибки без игрока, live-combat ticking при
# открытой консоли, и боевые команды (gold/godmode/spawn/kill/timer/timescale/win).
# Бой стартует прямым вызовом _start_combat — как в остальных смоуках.


func _press_tilde() -> void:
	var down := InputEventKey.new()
	down.physical_keycode = KEY_QUOTELEFT
	down.keycode = KEY_QUOTELEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = KEY_QUOTELEFT
	up.keycode = KEY_QUOTELEFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("SCRUM-831: Main.tscn не загрузилась для смоука дев-консоли.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var console = main.get("dev_console")
	if console == null or not is_instance_valid(console):
		_fail("SCRUM-831: dev_console не создана в Main._ready.")
		return
	if console.is_console_open():
		_fail("SCRUM-831: консоль должна стартовать закрытой.")
		return

	# (a) Тоггл синтетической тильдой: консоль открылась, но НЕ ставит бой/дерево на паузу.
	await _press_tilde()
	if not console.is_console_open():
		_fail("SCRUM-831(a): тильда не открыла консоль.")
		return
	if paused:
		_fail("SCRUM-845(a): открытая консоль не должна ставить SceneTree на паузу.")
		return
	if main.pause_reasons.has("dev_console"):
		_fail("SCRUM-845(a): открытая консоль не должна добавлять pause-причину dev_console.")
		return

	# (b) help перечисляет команды; неизвестная команда даёт ошибку, не краш.
	console.execute_command("help")
	var log_text: String = console.get_output_text()
	for expected_name in ["godmode", "spawn", "timescale", "artifact"]:
		if not log_text.contains(expected_name):
			_fail("SCRUM-831(b): help не перечислил команду %s." % expected_name)
			return
	console.execute_command("no_such_command_xyz")
	if not console.get_output_text().contains("Неизвестная команда"):
		_fail("SCRUM-831(b): неизвестная команда не дала внятную ошибку.")
		return

	# (c) Команды, требующие игрока, в главном меню вежливо отказывают.
	console.execute_command("gold 100")
	if not console.get_output_text().contains("Нет ни игрока"):
		_fail("SCRUM-831(c): gold в меню должен сообщать об отсутствии игрока/забега.")
		return

	# (d) Живой бой: прямой старт, консоль остаётся открытой как live overlay.
	main.combat._start_combat(false, "battle")
	await process_frame
	await process_frame
	var player = main.current_player
	if player == null or not is_instance_valid(player):
		_fail("SCRUM-831(d): _start_combat не создал игрока.")
		return
	if paused or main.pause_reasons.has("dev_console"):
		_fail("SCRUM-845(d): бой не должен быть на паузе из-за открытой консоли.")
		return
	var timer_before_live := float(main.round_time_left)
	var player_position_before_live: Vector2 = player.global_position
	console.execute_command("spawn basic 1")
	await process_frame
	var live_enemies := get_nodes_in_group("enemies")
	if live_enemies.is_empty():
		_fail("SCRUM-845(d): spawn basic 1 не создал врага для live-check.")
		return
	var live_enemy := live_enemies[live_enemies.size() - 1] as Node2D
	var enemy_position_before_live: Vector2 = live_enemy.global_position
	Input.action_press("move_right")
	await create_timer(0.18).timeout
	Input.action_release("move_right")
	if float(main.round_time_left) >= timer_before_live - 0.02:
		_fail("SCRUM-845(d): таймер боя не тикает при открытой консоли.")
		return
	if player.global_position.distance_to(player_position_before_live) < 12.0:
		_fail("SCRUM-845(d): игрок не двигается при открытой консоли.")
		return
	if is_instance_valid(live_enemy) and live_enemy.global_position.distance_to(enemy_position_before_live) < 4.0:
		_fail("SCRUM-845(d): враг не двигается при открытой консоли.")
		return

	# (e) gold: ровно +250 к текущему значению (без множителей).
	var money_before := int(player.get("money"))
	console.execute_command("gold 250")
	if int(player.get("money")) != money_before + 250:
		_fail("SCRUM-831(e): gold 250 дал %d, ожидалось %d." % [int(player.get("money")), money_before + 250])
		return

	# (f) godmode: флаг на игроке, урон полностью игнорируется.
	console.execute_command("godmode")
	if not bool(player.get("debug_godmode")):
		_fail("SCRUM-831(f): godmode не взвёл debug_godmode на игроке.")
		return
	var hp_before := float(player.get("health"))
	var damage_result: bool = player.take_damage(50.0)
	if damage_result or float(player.get("health")) < hp_before - 0.001:
		_fail("SCRUM-831(f): в годмоде take_damage обязан вернуть false и не менять HP.")
		return

	# (g) spawn: трое базовых врагов появляются в группе enemies.
	var enemies_before := get_nodes_in_group("enemies").size()
	console.execute_command("spawn basic 3")
	await process_frame
	var spawned := get_nodes_in_group("enemies").size() - enemies_before
	if spawned < 3:
		_fail("SCRUM-831(g): spawn basic 3 добавил %d врагов, ожидалось >=3." % spawned)
		return

	# (h) kill all: группа врагов пустеет после кадра очистки.
	console.execute_command("kill all")
	await process_frame
	await process_frame
	if not get_nodes_in_group("enemies").is_empty():
		_fail("SCRUM-831(h): kill all оставил живых врагов: %d." % get_nodes_in_group("enemies").size())
		return

	# (i) timer/timescale: значения применяются и восстанавливаются.
	console.execute_command("timer 5")
	if absf(main.round_time_left - 5.0) > 0.001:
		_fail("SCRUM-831(i): timer 5 не выставил round_time_left (=%f)." % main.round_time_left)
		return
	console.execute_command("timescale 2")
	if absf(Engine.time_scale - 2.0) > 0.001:
		_fail("SCRUM-831(i): timescale 2 не применился (=%f)." % Engine.time_scale)
		return
	console.execute_command("timescale 1")
	if absf(Engine.time_scale - 1.0) > 0.001:
		_fail("SCRUM-831(i): timescale 1 не вернул скорость (=%f)." % Engine.time_scale)
		return

	# (j) win: бой завершается победой, консоль сама закрывается без pause-хвоста.
	console.execute_command("win")
	await process_frame
	await process_frame
	if main.combat_active:
		_fail("SCRUM-831(j): win не завершил бой.")
		return
	if console.is_console_open():
		_fail("SCRUM-831(j): win обязан закрывать консоль.")
		return
	if main.pause_reasons.has("dev_console"):
		_fail("SCRUM-845(j): pause-причина dev_console не должна оставаться после win.")
		return

	# (k) Повторный цикл: открыть → stats → закрыть тильдой.
	console.open_console()
	console.execute_command("stats")
	if not console.get_output_text().contains("Акт"):
		_fail("SCRUM-831(k): stats не вывел сводку состояния.")
		return
	await _press_tilde()
	if console.is_console_open() or main.pause_reasons.has("dev_console"):
		_fail("SCRUM-845(k): тильда не закрыла консоль или оставила pause-причину.")
		return

	main.queue_free()
	await process_frame
	print("Dev console smoke passed.")
	quit()
