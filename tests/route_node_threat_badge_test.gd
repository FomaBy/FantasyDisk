extends SceneTree

# SCRUM-616: бейдж-превью угрозы на узле карты маршрута.
#
# route_map_screen._draw_route_nodes вешает компактный угловой Label
# (RouteNodeThreatBadge) поверх кнопок battle/elite_battle/chest — детерминированный
# хинт без наведения и без нового арта. Тултип-превью остаётся. На completed/
# shop_revisit бейджа нет (там ✓-метка). Бейдж не перехватывает клик/hover.
#
# Проверки:
#   1. На доступных узлах battle/elite_battle/chest есть RouteNodeThreatBadge.
#   2. Текст бейджа корректен по типу: elite_battle='★', chest='1/3',
#      battle ∈ {Л,С,Т} (буква-хинт силы волны).
#   3. Бейдж — Label с mouse_filter == IGNORE (не ломает клик/тултип узла).
#   4. На узле с completed-меткой (✓) бейджа угрозы нет (не дублируем оверлеи).
#   5. Узлы НЕ battle/elite/chest (boss/shop/...) бейджа не получают.
#
# Запуск: Godot --headless --path . --script res://tests/route_node_threat_badge_test.gd

const BADGE_NAME := "RouteNodeThreatBadge"
const COMPLETED_NAME := "RouteNodeCompletedMark"
const BADGED_TYPES := ["battle", "elite_battle", "chest"]
const VALID_BATTLE_LETTERS := ["Л", "С", "Т"]


func _fail(message: String) -> void:
	push_error("[route_node_threat_badge] " + message)
	quit(1)


func _initialize() -> void:
	var ok := await _run()
	if ok:
		print("[route_node_threat_badge] PASSED")
		quit(0)


func _run() -> bool:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn не загрузилась")
		return false
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_show_battle_map")
	await process_frame
	await process_frame

	var route_map := main.find_child("VerticalRouteMap", true, false) as Control
	if route_map == null:
		_fail("карта маршрута (VerticalRouteMap) не отрисовалась")
		return false

	var route_nodes: Array = main.get("route_nodes")
	if route_nodes == null or route_nodes.is_empty():
		_fail("route_nodes пуст")
		return false

	var seen_types := {}
	var checked_badges := 0
	for step_index in range(route_nodes.size()):
		var row: Array = route_nodes[step_index]
		for branch_index in range(row.size()):
			var route_node: Dictionary = row[branch_index]
			var node_type := str(route_node.get("type", ""))
			var button := main.find_child("RouteNode_%s_%d_%d" % [node_type, step_index, branch_index], true, false) as Button
			if button == null:
				continue
			var badge := button.find_child(BADGE_NAME, false, false) as Label
			var completed := button.find_child(COMPLETED_NAME, false, false)

			if completed != null:
				# Гейт 4: на completed/shop_revisit бейджа угрозы быть не должно.
				if badge != null:
					_fail("узел %s[%d,%d] имеет и ✓-метку, и бейдж угрозы — дублирование оверлеев" % [node_type, step_index, branch_index])
					return false
				continue

			if node_type in BADGED_TYPES:
				if badge == null:
					_fail("узел %s[%d,%d] без RouteNodeThreatBadge" % [node_type, step_index, branch_index])
					return false
				# Гейт 3: бейдж не перехватывает ввод.
				if badge.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					_fail("бейдж узла %s[%d,%d] перехватывает ввод (mouse_filter != IGNORE)" % [node_type, step_index, branch_index])
					return false
				# Гейт 2: текст бейджа корректен.
				var txt := badge.text
				match node_type:
					"elite_battle":
						if txt != "★":
							_fail("elite_battle бейдж = '%s', ожидался '★'" % txt)
							return false
					"chest":
						if txt != "1/3":
							_fail("chest бейдж = '%s', ожидался '1/3'" % txt)
							return false
					"battle":
						if not (txt in VALID_BATTLE_LETTERS):
							_fail("battle бейдж = '%s', ожидался один из %s" % [txt, str(VALID_BATTLE_LETTERS)])
							return false
				seen_types[node_type] = true
				checked_badges += 1
			else:
				# Гейт 5: прочие типы (boss/shop/...) бейджа не получают.
				if badge != null:
					_fail("узел типа %s[%d,%d] не должен иметь бейдж угрозы" % [node_type, step_index, branch_index])
					return false

	if checked_badges == 0:
		_fail("ни одного бейджа не проверено — карта без battle/elite/chest узлов?")
		return false
	# На стартовом ряду гарантированно есть battle-узел → хотя бы 'battle' встречен.
	if not seen_types.has("battle"):
		_fail("на карте не найдено battle-узлов с бейджем (минимум — стартовый ряд)")
		return false

	print("[route_node_threat_badge] проверено бейджей: %d, типы: %s" % [checked_badges, str(seen_types.keys())])
	main.queue_free()
	await process_frame
	return true
