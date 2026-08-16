extends "res://tests/runtime_smoke_test.gd"

# SCRUM-994: инвариант «elite = обязательный бой».
# Root cause бага: узел «Алтарь жертвы» (открывает СОБЫТИЕ sacrifice_altar) носил
# ту же иконку map_elite_skull_bones.png, что и elite_battle, и при генерации мог
# затирать elite-ветку — игрок видел «элитный» узел, а получал событие.
# Проверяем:
#   1. Иконка элитки эксклюзивна: ни один тип узла, кроме elite_battle, её не носит.
#   2. _place_altar_node не переписывает elite_battle-ветки (наравне с shop/chest).
#   3. Активация КАЖДОГО elite-узла на нескольких сгенерированных маршрутах/сидах
#      стартует именно элитный бой (combat_active, type=elite, элитка заспавнена
#      детерминированно от seed узла, никакого EventScreen).
#   4. Полный победный флоу элитки: убийство → _end_combat(true) → баннер →
#      выбор артефакта элитки → докачка → возврат на карту с продвижением ряда.
#   5. Алиас типа "elite" (дрейф данных старых сейвов) тоже ведёт в элитный бой.
#   6. Event/altar узлы продолжают открывать event UI (не регресснуты).

const ELITE_ICON := "res://assets/sprites/map_icons/map_elite_skull_bones.png"
const GENERATION_SEEDS := [11, 2026, 70907, 424242, 999331, 5150, 86420, 13571113]
const ACTIVATION_SEEDS := [70907, 424242, 999331]


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("SCRUM-994: Main.tscn не загрузилась.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# --- 1. Иконка элитки эксклюзивна для elite_battle. ---
	for node_type in main.MAP_NODE_DEFINITIONS.keys():
		var definition: Dictionary = main.MAP_NODE_DEFINITIONS[node_type]
		var icon_paths := [str(definition.get("icon_path", "")), str(definition.get("disk_icon_path", ""))]
		if icon_paths.has(ELITE_ICON) and str(node_type) != "elite_battle":
			_fail("SCRUM-994: узел '%s' носит иконку элитки %s — игрок прочитает его как элитный бой." % [str(node_type), ELITE_ICON])
			return
	if str((main.MAP_NODE_DEFINITIONS["elite_battle"] as Dictionary).get("icon_path", "")) != ELITE_ICON:
		_fail("SCRUM-994: elite_battle потерял каноническую иконку %s." % ELITE_ICON)
		return

	# --- 2. Алтарь не затирает elite-ветки. ---
	# 2a. Синтетический маршрут: все свободные ветки внутренних рядов — элитки.
	#     Алтарю некуда встать — маршрут обязан остаться без алтаря и без потерь элиток.
	for altar_seed in GENERATION_SEEDS:
		main.rng.seed = altar_seed
		var all_elite_route := [
			[_stub_node("battle", 0, 0), _stub_node("battle", 0, 1)],
			[_stub_node("battle", 1, 0), _stub_node("battle", 1, 1)],
			[_stub_node("elite_battle", 2, 0), _stub_node("shop", 2, 1)],
			[_stub_node("elite_battle", 3, 0), _stub_node("elite_battle", 3, 1)],
			[_stub_node("chest", 4, 0), _stub_node("elite_battle", 4, 1)],
		]
		main.route._place_altar_node(all_elite_route)
		var elite_count := 0
		for row in all_elite_route:
			for route_node in row:
				var node_type := str((route_node as Dictionary).get("type", ""))
				if node_type == "altar":
					_fail("SCRUM-994: алтарь встал на защищённую ветку в маршруте без свободных мест (seed=%d)." % altar_seed)
					return
				if node_type == "elite_battle":
					elite_count += 1
		if elite_count != 4:
			_fail("SCRUM-994: _place_altar_node потерял элитку: %d/4 (seed=%d)." % [elite_count, altar_seed])
			return
	# 2b. Смешанные ряды: алтарь встаёт, но никогда на elite/shop/chest-ветку.
	for altar_seed in GENERATION_SEEDS:
		main.rng.seed = altar_seed
		var mixed_route := [
			[_stub_node("battle", 0, 0), _stub_node("battle", 0, 1)],
			[_stub_node("battle", 1, 0), _stub_node("battle", 1, 1)],
			[_stub_node("elite_battle", 2, 0), _stub_node("battle", 2, 1)],
			[_stub_node("elite_battle", 3, 0), _stub_node("event", 3, 1), _stub_node("battle", 3, 2)],
			[_stub_node("rest", 4, 0), _stub_node("elite_battle", 4, 1)],
		]
		var elite_positions := _typed_positions(mixed_route, "elite_battle")
		main.route._place_altar_node(mixed_route)
		if _typed_positions(mixed_route, "elite_battle") != elite_positions:
			_fail("SCRUM-994: алтарь переписал elite-ветку в смешанном маршруте (seed=%d)." % altar_seed)
			return
		if _typed_positions(mixed_route, "altar").size() != 1:
			_fail("SCRUM-994: алтарь не встал в смешанный маршрут со свободными ветками (seed=%d)." % altar_seed)
			return

	# 2c. Полная генерация: у каждого сида ровно один алтарь, и никакой узел,
	#     кроме elite_battle, не рендерится с иконкой элитки.
	for generation_seed in GENERATION_SEEDS:
		main.rng.seed = generation_seed
		var generated_route: Array = main.route._generate_route()
		var altar_count := 0
		for row in generated_route:
			for route_node in row:
				var node_dictionary := route_node as Dictionary
				var node_type := str(node_dictionary.get("type", ""))
				if node_type == "altar":
					altar_count += 1
				var definition: Dictionary = main.route._map_node_definition(node_type)
				var icon_path: String = main.route._route_node_icon_path(node_dictionary, definition)
				if icon_path == ELITE_ICON and node_type != "elite_battle":
					_fail("SCRUM-994: seed=%d — узел '%s' рендерится с иконкой элитки." % [generation_seed, node_type])
					return
		if altar_count != 1:
			_fail("SCRUM-994: seed=%d — ожидался ровно 1 алтарь на маршрут, получено %d." % [generation_seed, altar_count])
			return

	# --- 3. Активация всех elite-узлов на нескольких маршрутах = элитный бой. ---
	var full_flow_checked := false
	for activation_seed in ACTIVATION_SEEDS:
		main.rng.seed = activation_seed
		main.route_nodes = main.route._generate_route()
		main.route_selected_indices.clear()
		main.run_player_snapshot = {}
		main.reset_run_metrics()
		var elite_checked := 0
		for row in range(main.route_nodes.size()):
			for branch in range(main.route_nodes[row].size()):
				var route_node: Dictionary = main.route_nodes[row][branch]
				if str(route_node.get("type", "")) != "elite_battle":
					continue
				elite_checked += 1
				main.route_stage = row
				main.route._route_node_activating = false  # латч сбрасывает _show_battle_map; в тесте руками
				main.route._activate_route_node(row, branch, route_node)
				await process_frame
				var combat_report := _assert_elite_combat(main, route_node)
				if combat_report != "":
					_fail("SCRUM-994: seed=%d row=%d branch=%d: %s" % [activation_seed, row, branch, combat_report])
					return
				if not full_flow_checked:
					# Полный победный флоу одной элитки: убийство → награда → карта.
					full_flow_checked = true
					var flow_report := await _drive_elite_victory_to_map(main)
					if flow_report != "":
						_fail("SCRUM-994: победный флоу элитки не вернулся на карту: %s" % flow_report)
						return
				else:
					_neutralize_combat(main)
					await process_frame
		if elite_checked == 0:
			_fail("SCRUM-994: seed=%d — маршрут без единого elite-узла (сид непоказателен)." % activation_seed)
			return

	# --- 5. Алиас "elite" (дрейф данных) тоже стартует элитный бой. ---
	main.route_stage = 3
	main.current_act = 1
	main.route._open_route_node({"type": "elite", "name": "Legacy Elite", "row": 3, "branch": 0, "seed": 987654})
	await process_frame
	if not bool(main.combat_active) or str(main.current_combat_type) != "elite" or bool(main.boss_combat_active):
		_fail("SCRUM-994: узел с legacy-типом 'elite' не стартовал элитный бой (combat_active=%s, type=%s)." % [str(main.combat_active), str(main.current_combat_type)])
		return
	_neutralize_combat(main)
	await process_frame

	# --- 6. Event- и altar-узлы продолжают открывать event UI. ---
	main.current_event_definition.clear()
	main.route._open_route_node({"type": "event", "name": "Event Node", "row": 3, "branch": 0, "seed": 5})
	await process_frame
	if bool(main.combat_active):
		_fail("SCRUM-994: event-узел запустил бой вместо события.")
		return
	if main.ui_layer == null or not is_instance_valid(main.ui_layer) or main.ui_layer.find_child("EventScreen", true, false) == null:
		_fail("SCRUM-994: event-узел не открыл EventScreen.")
		return
	main.current_event_definition.clear()
	main.route._open_route_node({"type": "altar", "name": "Алтарь жертвы", "row": 4, "branch": 0, "seed": 6, "event_id": "sacrifice_altar"})
	await process_frame
	if bool(main.combat_active):
		_fail("SCRUM-994: altar-узел запустил бой вместо события sacrifice_altar.")
		return
	if main.ui_layer == null or not is_instance_valid(main.ui_layer) or main.ui_layer.find_child("EventScreen", true, false) == null:
		_fail("SCRUM-994: altar-узел не открыл EventScreen (sacrifice_altar).")
		return
	if str(main.current_event_definition.get("id", "")) != "sacrifice_altar":
		_fail("SCRUM-994: altar-узел открыл событие '%s' вместо sacrifice_altar." % str(main.current_event_definition.get("id", "")))
		return

	main.queue_free()
	await process_frame
	_finish("Route elite invariant passed: elite nodes always start elite combat across %d seeds (icon exclusivity, altar protection, activation, reward flow, legacy alias, event UI intact)." % GENERATION_SEEDS.size())


func _stub_node(node_type: String, row: int, branch: int) -> Dictionary:
	return {
		"type": node_type,
		"name": "%s %d:%d" % [node_type, row, branch],
		"row": row,
		"branch": branch,
		"seed": row * 1000 + branch,
	}


func _typed_positions(route: Array, node_type: String) -> Array:
	var positions := []
	for row_index in range(route.size()):
		var row: Array = route[row_index]
		for branch_index in range(row.size()):
			if str((row[branch_index] as Dictionary).get("type", "")) == node_type:
				positions.append([row_index, branch_index])
	return positions


# Возвращает "" если активированный узел дал корректный элитный бой.
func _assert_elite_combat(main, route_node: Dictionary) -> String:
	if not bool(main.combat_active):
		return "бой не стартовал"
	if str(main.current_combat_type) != "elite":
		return "тип боя '%s' вместо 'elite'" % str(main.current_combat_type)
	if bool(main.boss_combat_active):
		return "элитный узел поднял boss_combat_active"
	if main.ui_layer != null and is_instance_valid(main.ui_layer) and main.ui_layer.find_child("EventScreen", true, false) != null:
		return "открылся EventScreen вместо боя"
	if not (main.pending_event_combat as Dictionary).is_empty():
		return "элитный бой ошибочно несёт pending_event_combat"
	var elites := get_nodes_in_group("elite_enemies")
	if elites.is_empty():
		return "элитка не заспавнена"
	var elite := elites[0] as Node2D
	if main.boss_hud_target == null or not is_instance_valid(main.boss_hud_target):
		return "boss_hud_target (HUD-полоса элитки) не выставлен"
	# Детерминизм seed → сцена элитки (существующий elite flow, SCRUM-499).
	var expected_scene: PackedScene = main.node_elite_scene(int(route_node.get("seed", 0)))
	if expected_scene != null and elite.scene_file_path != expected_scene.resource_path:
		return "сцена элитки %s не совпала с детерминированной от seed %s" % [elite.scene_file_path, expected_scene.resource_path]
	if main.current_player == null or not is_instance_valid(main.current_player):
		return "игрок не заспавнен в элитном бою"
	return ""


# Полный победный флоу элитки: убить элитку → _end_combat(true) → баннер →
# выбор артефакта → докачка → карта; route_stage должен продвинуться.
func _drive_elite_victory_to_map(main) -> String:
	var stage_before: int = int(main.route_stage)
	for elite in get_nodes_in_group("elite_enemies"):
		if elite.has_method("take_damage"):
			elite.take_damage(9.0e9)
	await process_frame
	if not bool(main.combat.is_elite_defeated()):
		return "убийство элитки не взвело _elite_defeated"
	main.combat._end_combat(true)
	await process_frame
	if bool(main.combat_active):
		return "_end_combat(true) не завершил бой"
	# Баннер (~1.65с) → экран артефакта элитки.
	var artifact_button: Button = null
	for _attempt in range(24):
		await create_timer(0.25).timeout
		if main.ui_layer != null and is_instance_valid(main.ui_layer):
			artifact_button = main.ui_layer.find_child("EliteArtifactRewardButton0", true, false) as Button
			if artifact_button != null:
				break
	if artifact_button == null:
		return "экран артефакта элитки не появился после баннера победы"
	artifact_button.pressed.emit()
	await process_frame
	# Докачка → карта.
	var skip_button: Button = null
	for _attempt in range(12):
		if main.ui_layer != null and is_instance_valid(main.ui_layer):
			skip_button = main.ui_layer.find_child("AttributeSkipButton", true, false) as Button
			if skip_button != null:
				break
		await create_timer(0.2).timeout
	if skip_button == null:
		return "экран докачки не появился после артефакта элитки"
	skip_button.pressed.emit()
	await process_frame
	await process_frame
	if main.ui_layer == null or not is_instance_valid(main.ui_layer) or main.ui_layer.find_child("RouteMapScreen", true, false) == null:
		return "после докачки не открылась карта маршрута"
	if int(main.route_stage) != stage_before + 1:
		return "route_stage не продвинулся (%d -> %d)" % [stage_before, int(main.route_stage)]
	return ""


# Нейтральный сброс боевого узла между активациями — тот же reset, что делает
# рестор автосейва (_apply_run_autosave_state): без победного/смертельного флоу.
func _neutralize_combat(main) -> void:
	main.combat_active = false
	main.boss_combat_active = false
	main.boss_hud_target = null
	main.pending_event_combat.clear()
	main._clear_all_game_pauses()
	main._clear_world()
	main._clear_hud()
	main._clear_ui()
