extends "res://tests/runtime_smoke_test.gd"

# SCRUM-1000: консольная команда `win` обязана завершать бой тем же каноническим
# victory-путём, что и настоящая победа, и НЕ ломать следующий бой.
# Root cause бага: win/die из консоли достижимы при активной геймплейной паузе
# (level-up окно, Esc-досье, фидбек), в отличие от штатных победных путей,
# которые живут в main._process за гейтом get_tree().paused. Победный флоу
# сносил pause-экран через _clear_ui без pop_pause → get_tree().paused застревал
# true → следующий бой рождался мёртвым: без спавна, тика таймера, инпута и
# обновления камеры (видна верхняя-левая четверть арены).
#
# Сценарий: карта → активация узла → бой → `win` → победный флоу (баннер →
# докачка → карта) → следующий бой. Три подряд:
#   round 0 — чистый win (базовый кейс тикета);
#   round 1 — win при ОТКРЫТОМ окне level-up (пауза level_up);
#   round 2 — win при ОТКРЫТОМ Esc-досье паузы (пауза escape_menu).
# После каждого старта боя ассертим: игрок жив/видим, камера игрока активна во
# вьюпорте, combat director тикает (таймер/волны/враги), инпут двигает игрока,
# get_tree().paused == false и pause_reasons пуст.

const WIN_FLOW_COMBAT_ROUNDS := 3


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("SCRUM-1000: Main.tscn не загрузилась.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var console = main.get("dev_console")
	if console == null or not is_instance_valid(console):
		_fail("SCRUM-1000: dev_console не создана в Main._ready.")
		return

	# Детерминированный маршрут: подбираем сид, у которого в рядах 0..2 есть боевой узел.
	if not _seed_route_with_combat_rows(main, WIN_FLOW_COMBAT_ROUNDS):
		_fail("SCRUM-1000: не нашёлся сид с боевыми узлами в рядах 0..%d." % (WIN_FLOW_COMBAT_ROUNDS - 1))
		return
	main.route_selected_indices.clear()
	main.route_stage = 0
	main.run_player_snapshot = {}
	main.reset_run_metrics()

	for combat_round in range(WIN_FLOW_COMBAT_ROUNDS):
		var row: int = main.route_stage
		if row >= main.route_nodes.size():
			_fail("SCRUM-1000: маршрут закончился раньше времени (row=%d)." % row)
			return
		var branch := _combat_branch_in_row(main, row)
		if branch < 0:
			_fail("SCRUM-1000: в ряду %d нет боевого узла (сид-подбор обязан был это исключить)." % row)
			return
		var route_node: Dictionary = main.route_nodes[row][branch]

		# Активация узла — тот же путь, что клик по доступному узлу карты.
		main.route._activate_route_node(row, branch, route_node)
		await process_frame
		await process_frame

		if not bool(main.combat_active):
			_fail("SCRUM-1000(r%d): активация узла '%s' не запустила бой." % [combat_round, str(route_node.get("type"))])
			return
		var health_report := await _assert_combat_healthy(main, combat_round)
		if health_report != "":
			_fail("SCRUM-1000(r%d): следующий после win бой сломан: %s" % [combat_round, health_report])
			return

		# Раунды 1 и 2 воспроизводят реальный триггер бага: win при активной паузе.
		if combat_round == 1:
			var pause_error := await _open_level_up_pause(main)
			if pause_error != "":
				_fail("SCRUM-1000(r1): не удалось открыть level-up паузу: %s" % pause_error)
				return
		elif combat_round == 2:
			main.ui._show_pause_menu(true)
			await process_frame
			if not paused or not main.pause_reasons.has("escape_menu"):
				_fail("SCRUM-1000(r2): Esc-досье не поставило паузу escape_menu.")
				return

		# Консольная победа.
		console.open_console()
		console.execute_command("win")
		await process_frame
		if bool(main.combat_active):
			_fail("SCRUM-1000(r%d): win не завершил бой." % combat_round)
			return
		if paused or not (main.pause_reasons as Dictionary).is_empty():
			_fail("SCRUM-1000(r%d): сразу после win остался pause-хвост: %s (tree paused=%s)." % [combat_round, str(main.pause_reasons), str(paused)])
			return

		# Победный флоу: баннер (автопродолжение ~1.65с) → докачка → карта.
		var flow_report := await _drive_victory_flow_to_map(main)
		if flow_report != "":
			_fail("SCRUM-1000(r%d): победный флоу после win не дошёл до карты: %s" % [combat_round, flow_report])
			return

	# Финал: после трёх win-циклов нет pause-хвостов и timescale номинален.
	if paused or not (main.pause_reasons as Dictionary).is_empty():
		_fail("SCRUM-1000: после трёх win-циклов остался pause-хвост: %s (tree paused=%s)." % [str(main.pause_reasons), str(paused)])
		return
	if absf(Engine.time_scale - 1.0) > 0.01:
		_fail("SCRUM-1000: после трёх win-циклов Engine.time_scale=%f (ожидалось 1.0)." % Engine.time_scale)
		return

	main.queue_free()
	await process_frame
	_finish("Dev console win flow passed: %d consecutive win->route->combat cycles are healthy (incl. win under level-up and escape-menu pauses)." % WIN_FLOW_COMBAT_ROUNDS)


# Подбирает сид, у которого первые combat_rows рядов маршрута содержат боевой узел.
func _seed_route_with_combat_rows(main, combat_rows: int) -> bool:
	for seed_candidate in range(1, 128):
		main.rng.seed = 100_000 + seed_candidate * 7919
		var route: Array = main.route._generate_route()
		var all_rows_have_combat := true
		for row in range(combat_rows):
			main.route_nodes = route
			if _combat_branch_in_row(main, row) < 0:
				all_rows_have_combat = false
				break
		if all_rows_have_combat:
			main.route_nodes = route
			return true
	return false


func _combat_branch_in_row(main, row: int) -> int:
	if row >= main.route_nodes.size():
		return -1
	var branches: Array = main.route_nodes[row]
	for branch_index in range(branches.size()):
		var node_type := str((branches[branch_index] as Dictionary).get("type", ""))
		if node_type == "battle" or node_type == "elite_battle" or node_type == "boss":
			return branch_index
	return -1


# Открывает окно level-up мид-файт (как Space по кнопке докачки): выдаёт XP до
# уровня и вызывает _open_pending_level_up. Возвращает "" при успехе.
func _open_level_up_pause(main) -> String:
	var player = main.current_player
	if player == null or not is_instance_valid(player):
		return "нет игрока"
	player.gain_xp(int(player.get("xp_to_next")) + 3)
	await process_frame
	if int(main.pending_level_ups) <= 0:
		return "gain_xp не дал pending_level_ups"
	main.ui._open_pending_level_up()
	await process_frame
	if not paused or not main.pause_reasons.has("level_up"):
		return "окно level-up не поставило паузу level_up"
	return ""


# Возвращает "" если бой здоров, иначе описание первой найденной поломки.
func _assert_combat_healthy(main, _combat_round: int) -> String:
	if paused:
		return "SceneTree на паузе (pause_reasons=%s)" % str(main.pause_reasons)
	if not (main.pause_reasons as Dictionary).is_empty():
		return "остались pause-причины: %s" % str(main.pause_reasons)

	var player = main.current_player
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return "игрок не заспавнен (current_player=%s)" % str(player)
	if not bool(player.visible):
		return "игрок невидим"
	if float(player.get("health")) <= 0.0:
		return "игрок мёртв на старте боя"

	# Камера: существует и активна во вьюпорте — иначе видна верхняя-левая
	# четверть арены (identity canvas transform).
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return "у игрока нет Camera2D"
	var active_camera: Camera2D = player.get_viewport().get_camera_2d()
	if active_camera != camera:
		return "камера игрока не активна во вьюпорте (active=%s)" % str(active_camera)

	# Combat director: таймер тикает, волны спавнят врагов, инпут двигает игрока.
	var timer_before := float(main.round_time_left)
	var position_before: Vector2 = player.global_position
	Input.action_press("move_right")
	await create_timer(0.6).timeout
	Input.action_release("move_right")
	await process_frame

	if not bool(main.combat_active):
		return "combat_active сбросился сам по себе"
	if float(main.round_time_left) >= timer_before - 0.05:
		return "таймер боя не тикает (%.2f -> %.2f)" % [timer_before, float(main.round_time_left)]
	if get_nodes_in_group("enemies").is_empty():
		return "враги не спавнятся (группа enemies пуста спустя 0.6с)"
	if not is_instance_valid(player):
		return "игрок исчез в первые секунды боя"
	if player.global_position.distance_to(position_before) < 12.0:
		return "инпут мёртв: move_right не сдвинул игрока (%.1f px)" % player.global_position.distance_to(position_before)
	return ""


# Ведёт победный флоу до карты маршрута: ждёт баннер, жмёт «Пропустить» в докачке.
# Возвращает "" при успехе, иначе описание затыка.
func _drive_victory_flow_to_map(main) -> String:
	# Баннер победы автопродолжается через ~1.65с (tween 0.35 + interval 1.3).
	var skip_button: Button = null
	for _attempt in range(24):
		await create_timer(0.25).timeout
		if main.ui_layer != null and is_instance_valid(main.ui_layer):
			skip_button = main.ui_layer.find_child("AttributeSkipButton", true, false) as Button
			if skip_button != null:
				break
	if skip_button == null:
		return "экран докачки (AttributeSkipButton) не появился после баннера победы"
	skip_button.pressed.emit()
	await process_frame
	await process_frame
	if main.ui_layer == null or not is_instance_valid(main.ui_layer):
		return "после докачки нет ui_layer"
	if main.ui_layer.find_child("RouteMapScreen", true, false) == null:
		return "после докачки не открылась карта маршрута"
	return ""
