extends SceneTree

# SCRUM-499: детерминированное превью узлов маршрута.
# Гейт: превью в тултипе (биом/тип элитки), посчитанное заранее из node["seed"],
# ОБЯЗАНО совпадать с тем, что реально выберет combat при входе в узел; плюс
# каждый узел несёт стабильный seed, а тултип содержит ожидаемые поля.

func _fail(message: String) -> void:
	push_error("[route_node_preview] " + message)
	quit(1)


func _initialize() -> void:
	var ok := await _run()
	if ok:
		print("[route_node_preview] PASSED")
		quit(0)


func _run() -> bool:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn не загрузилась")
		return false
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var route_obj = main.get("route")
	var combat = main.get("combat")
	if route_obj == null or combat == null:
		_fail("route/combat компоненты не инициализированы")
		return false

	# Несколько независимых маршрутов — детерминизм не должен зависеть от конкретного сида.
	for attempt in range(3):
		var route: Array = main.call("_generate_route")
		if route.is_empty():
			_fail("_generate_route вернул пустой маршрут")
			return false
		var saw_battle := false
		var saw_elite := false
		var saw_boss := false
		for row in route:
			for node in (row as Array):
				var node_type := str(node.get("type", ""))

				# (1) Каждый узел несёт стабильный целочисленный seed.
				if not node.has("seed"):
					_fail("узел без поля seed: %s" % str(node))
					return false
				var node_seed := int(node["seed"])

				# (2) Превью биома детерминировано и совпадает с реальным выбором combat.
				if node_type == "battle" or node_type == "elite_battle" or node_type == "boss":
					var is_boss := node_type == "boss"
					main.set("current_node_seed", node_seed)
					main.set("current_node_type", node_type)
					var reality_bg: String = combat.call("_background_path_for_current_node", is_boss)
					var preview_bg: String = main.call("node_background_path", node_type, is_boss, node_seed)
					if reality_bg != preview_bg:
						_fail("биом превью != реальность (%s): preview=%s reality=%s" % [node_type, preview_bg, reality_bg])
						return false
					var preview_bg_again: String = main.call("node_background_path", node_type, is_boss, node_seed)
					if preview_bg != preview_bg_again:
						_fail("биом превью недетерминирован для seed=%d" % node_seed)
						return false

				# (3) Для элитки: тип элитки превью == реальный выбор combat.
				if node_type == "elite_battle":
					main.set("current_node_seed", node_seed)
					var reality_elite = combat.call("_random_elite_scene")
					var preview_elite = main.call("node_elite_scene", node_seed)
					if reality_elite != preview_elite:
						_fail("тип элитки превью != реальность для seed=%d" % node_seed)
						return false

				# (4) Тултип содержит ожидаемые превью-поля.
				var definition = route_obj.call("_map_node_definition", node_type)
				var tip: String = route_obj.call("_node_preview_tooltip", node, definition)
				match node_type:
					"battle":
						saw_battle = true
						if not tip.contains("Арена:") or not tip.contains("Угроза:"):
							_fail("battle-тултип без Арена/Угроза: %s" % tip)
							return false
					"elite_battle":
						saw_elite = true
						if not tip.contains("Арена:") or not tip.contains("Элита:") or not tip.contains("артефакт"):
							_fail("elite-тултип без Арена/Элита/артефакт: %s" % tip)
							return false
					"boss":
						saw_boss = true
						var boss_name := str(node.get("name", ""))
						if not tip.contains("Босс:") or not tip.contains(boss_name):
							_fail("boss-тултип без имени босса (%s): %s" % [boss_name, tip])
							return false
		if not saw_boss:
			_fail("в маршруте нет boss-узла")
			return false
		if not (saw_battle or saw_elite):
			_fail("в маршруте нет боёв/элиток")
			return false

	main.queue_free()
	return true
