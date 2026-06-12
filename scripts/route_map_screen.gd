extends RefCounted

# Генерация маршрута и full-screen экран маршрутной карты:
# узлы, связи, скролл/пан, активация encounter-ов.

var game


func _init(game_ref) -> void:
	game = game_ref


func _show_battle_map() -> void:
	game._play_music("menu")
	game._clear_world()
	game._clear_hud()
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "RouteMapScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)

	var backdrop_path := "res://assets/backgrounds/route_map_backdrop.png"
	if ResourceLoader.exists(backdrop_path):
		var backdrop := TextureRect.new()
		backdrop.name = "RouteMapBackdrop"
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.texture = game._cached_texture(backdrop_path)
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(backdrop)
		# Затемнение, чтобы узлы и линии читались поверх арта.
		var backdrop_shade := ColorRect.new()
		backdrop_shade.name = "RouteMapBackdropShade"
		backdrop_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop_shade.color = Color(0.012, 0.016, 0.030, 0.62)
		backdrop_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(backdrop_shade)
	else:
		# Fallback: текущий однотонный фон, пока Codex не положил backdrop PNG.
		var background := ColorRect.new()
		background.name = "RouteMapBackground"
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color(0.025, 0.032, 0.050, 0.98)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)

	var grid_shade := ColorRect.new()
	grid_shade.name = "RouteMapTopShade"
	grid_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_shade.color = Color(0.0, 0.0, 0.0, 0.20)
	grid_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grid_shade)

	var header := PanelContainer.new()
	header.name = "RouteMapHeader"
	header.anchor_left = 0.0
	header.anchor_top = 0.0
	header.anchor_right = 1.0
	header.anchor_bottom = 0.0
	header.offset_left = game.ROUTE_MAP_SCREEN_MARGIN
	header.offset_top = 18.0
	header.offset_right = -game.ROUTE_MAP_SCREEN_MARGIN
	header.offset_bottom = game.ROUTE_MAP_HEADER_HEIGHT - 12.0
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", game.ui._hud_panel_style())
	root.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 24)
	header.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title_box)

	var title_label := Label.new()
	title_label.text = "Карта маршрута"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(title_label)

	var stage_label := Label.new()
	stage_label.text = "Прогресс: %d/%d   Следующий бой: %ds   Выбранный путь фиксируется" % [
		min(game.route_stage, game.route_nodes.size() - 1),
		game.ROUTE_STEPS_TO_BOSS,
		int(game.combat._current_round_duration()),
	]
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_label.add_theme_font_size_override("font_size", 18)
	stage_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 1.0))
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(stage_label)

	if game.route_debug_free_pick:
		var debug_label := Label.new()
		debug_label.name = "RouteDebugFreePickLabel"
		debug_label.text = "DEBUG: свободный выбор любого узла включен (F12 — выключить)"
		debug_label.add_theme_font_size_override("font_size", 16)
		debug_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40, 1.0))
		debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_box.add_child(debug_label)

	var scroll := ScrollContainer.new()
	scroll.name = "RouteMapScroll"
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = game.ROUTE_MAP_SCREEN_MARGIN
	scroll.offset_top = game.ROUTE_MAP_HEADER_HEIGHT
	scroll.offset_right = -game.ROUTE_MAP_SCREEN_MARGIN
	scroll.offset_bottom = -game.ROUTE_MAP_SCREEN_MARGIN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(scroll)

	var map_area := Control.new()
	map_area.name = "VerticalRouteMap"
	var canvas_size := _route_map_canvas_size()
	map_area.custom_minimum_size = canvas_size
	map_area.size = canvas_size
	map_area.mouse_filter = Control.MOUSE_FILTER_PASS
	map_area.gui_input.connect(func(event: InputEvent) -> void:
		_handle_route_map_pan_input(scroll, event)
	)
	scroll.add_child(map_area)

	var node_positions := _map_node_positions(map_area.custom_minimum_size)
	_draw_map_connections(map_area, node_positions)
	_draw_route_nodes(map_area, node_positions)
	game.ui._create_resource_hud_panel(root, Vector2(game.ROUTE_MAP_SCREEN_MARGIN, game.ROUTE_MAP_HEADER_HEIGHT + 8.0))
	game.ui._create_upgrade_fab(root, _show_battle_map)
	game.ui._update_hud()
	game.route_map_pan_active = false
	game.route_map_drag_distance = 0.0
	game.route_map_drag_suppressed_click = false
	_center_route_map_on_current_row.call_deferred(scroll, map_area.custom_minimum_size)


func _random_battle_node_name(index: int) -> String:
	var names := [
		"Forgotten Road",
		"Broken Watch",
		"Moonlit Crossing",
		"Old Battlefield",
		"Whispering Gate",
		"Ash Path",
	]
	return "Battle %d: %s" % [index + 1, names[game.rng.randi_range(0, names.size() - 1)]]


func _route_map_canvas_size() -> Vector2:
	# Ширина подгоняется под экран, чтобы горизонтальный скролл не появлялся;
	# высота растет с количеством рядов маршрута.
	var viewport_width: float = game.get_viewport().get_visible_rect().size.x
	var width: float = maxf(viewport_width - game.ROUTE_MAP_SCREEN_MARGIN * 2.0 - 16.0, 1000.0)
	var row_count: int = maxi(game.route_nodes.size(), game.ROUTE_STEPS_TO_BOSS + 1)
	var row_gap := 165.0
	var height: float = game.ROUTE_MAP_PADDING.y * 2.0 + game.MAP_NODE_SIZE.y + row_gap * float(row_count - 1)
	return Vector2(width, height)


func _node_pool_for_step(step_index: int) -> Array:
	if step_index == 0:
		return ["battle", "battle", "battle", "event"]
	if step_index <= 2:
		return ["battle", "battle", "battle", "event", "shop"]
	if step_index == game.ROUTE_STEPS_TO_BOSS - 1:
		return ["rest", "shop", "battle", "rest", "elite_battle"]
	if step_index >= game.ROUTE_STEPS_TO_BOSS - 3:
		return ["battle", "elite_battle", "elite_battle", "event", "battle", "shop"]
	return ["battle", "battle", "battle", "shop", "rest", "event", "elite_battle"]


func _generate_route() -> Array:
	var route := []
	for step_index in range(game.ROUTE_STEPS_TO_BOSS):
		var branches := []
		var branch_count = game.rng.randi_range(game.MIN_BRANCHES_PER_STEP, game.MAX_BRANCHES_PER_STEP)
		for branch_index in range(branch_count):
			var pool := _node_pool_for_step(step_index)
			var node_type: String = pool[game.rng.randi_range(0, pool.size() - 1)]
			branches.append({
				"type": node_type,
				"name": _random_route_node_name(branch_index, node_type),
				"row": step_index,
				"branch": branch_index,
			})
		if step_index == 0:
			var has_battle := false
			for branch in branches:
				if str(branch["type"]) == "battle":
					has_battle = true
			if not has_battle:
				branches[0]["type"] = "battle"
				branches[0]["name"] = _random_route_node_name(0, "battle")
		route.append(branches)
	route.append([_random_boss_route_node()])
	_assign_route_connections(route)
	return route


func _random_boss_route_node() -> Dictionary:
	var boss_options := [
		{
			"boss_id": "rift_warden",
			"name": "Rift Warden",
		},
		{
			"boss_id": "disk_devourer",
			"name": "Disk Devourer",
		},
	]
	var boss: Dictionary = boss_options[game.rng.randi_range(0, boss_options.size() - 1)]
	return {
		"type": "boss",
		"name": boss["name"],
		"boss_id": boss["boss_id"],
		"row": game.ROUTE_STEPS_TO_BOSS,
		"branch": 0,
	}


func _assign_route_connections(route: Array) -> void:
	for step_index in range(route.size() - 1):
		var current_row: Array = route[step_index]
		var next_row: Array = route[step_index + 1]
		var incoming := {}
		for next_index in range(next_row.size()):
			incoming[next_index] = 0

		for branch_index in range(current_row.size()):
			var connections := _route_connection_candidates(branch_index, current_row.size(), next_row.size())
			var route_node: Dictionary = current_row[branch_index]
			route_node["next_branches"] = connections
			current_row[branch_index] = route_node
			for next_branch in connections:
				incoming[int(next_branch)] = int(incoming.get(int(next_branch), 0)) + 1

		for next_index in range(next_row.size()):
			if int(incoming.get(next_index, 0)) > 0:
				continue
			var closest_previous := _closest_route_branch_for_next(next_index, current_row.size(), next_row.size())
			var previous_node: Dictionary = current_row[closest_previous]
			var previous_connections: Array = previous_node.get("next_branches", [])
			if not previous_connections.has(next_index):
				previous_connections.append(next_index)
				previous_connections.sort()
			previous_node["next_branches"] = previous_connections
			current_row[closest_previous] = previous_node

		route[step_index] = current_row


func _route_connection_candidates(branch_index: int, current_count: int, next_count: int) -> Array:
	if next_count <= 1:
		return [0]

	var mapped := 0
	if current_count <= 1:
		mapped = int(floor(float(next_count - 1) * 0.5))
	else:
		mapped = int(round(float(branch_index) * float(next_count - 1) / float(current_count - 1)))
	mapped = clampi(mapped, 0, next_count - 1)

	var connections := [mapped]
	if next_count > 2 and game.rng.randf() < 0.64:
		var side := 1 if branch_index <= current_count / 2 else -1
		if game.rng.randf() < 0.35:
			side *= -1
		var extra := clampi(mapped + side, 0, next_count - 1)
		if extra != mapped:
			connections.append(extra)

	connections.sort()
	return connections


func _closest_route_branch_for_next(next_index: int, current_count: int, next_count: int) -> int:
	if current_count <= 1 or next_count <= 1:
		return 0
	return clampi(int(round(float(next_index) * float(current_count - 1) / float(next_count - 1))), 0, current_count - 1)


func _random_route_node_name(index: int, node_type: String) -> String:
	if node_type == "shop":
		return "Shop %d: Broken Caravan" % [index + 1]
	if node_type == "rest":
		return "Rest %d: Moon Well" % [index + 1]
	if node_type == "event":
		return "Event %d: Strange Stone" % [index + 1]
	if node_type == "elite_battle":
		return "Elite %d: Crowned Threat" % [index + 1]
	if node_type == "boss":
		return "Disk Warden"

	return _random_battle_node_name(index)


func _map_node_positions(map_size: Vector2) -> Array:
	var positions := []
	var row_count = game.route_nodes.size()
	var usable_height: float = max(map_size.y - game.MAP_NODE_SIZE.y - game.ROUTE_MAP_PADDING.y * 2.0, game.MAP_NODE_SIZE.y)
	var vertical_gap := usable_height / float(max(row_count - 1, 1))
	for step_index in range(row_count):
		var step_positions := []
		var branch_count: int = game.route_nodes[step_index].size()
		var horizontal_gap = (map_size.x - game.ROUTE_MAP_PADDING.x * 2.0) / float(branch_count + 1)
		var y_position = map_size.y - game.ROUTE_MAP_PADDING.y - game.MAP_NODE_SIZE.y - vertical_gap * float(step_index)
		for branch_index in range(branch_count):
			step_positions.append(Vector2(
				game.ROUTE_MAP_PADDING.x + horizontal_gap * float(branch_index + 1) - game.MAP_NODE_SIZE.x * 0.5,
				y_position
			))
		positions.append(step_positions)
	return positions


func _center_route_map_on_current_row(scroll: ScrollContainer, map_size: Vector2) -> void:
	await game.get_tree().process_frame
	if scroll == null or not is_instance_valid(scroll):
		return
	if game.route_nodes.is_empty():
		return
	var node_positions := _map_node_positions(map_size)
	var active_step = clampi(game.route_stage, 0, node_positions.size() - 1)
	if node_positions[active_step].is_empty():
		return
	var row_center_y = float(node_positions[active_step][0].y) + game.MAP_NODE_SIZE.y * 0.5
	var focus_ratio := 0.78 if active_step == 0 else 0.64
	var target_y := maxi(0, int(row_center_y - scroll.size.y * focus_ratio))
	scroll.scroll_vertical = target_y
	scroll.scroll_horizontal = 0


func _handle_route_map_pan_input(scroll: ScrollContainer, event: InputEvent) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			game.route_map_pan_active = mouse_event.pressed
			game.route_map_pan_last_position = mouse_event.position
			game.route_map_drag_distance = 0.0
			game.route_map_drag_suppressed_click = false
	elif event is InputEventMouseMotion and game.route_map_pan_active:
		var motion := event as InputEventMouseMotion
		_pan_route_map_scroll(scroll, motion.relative)


func _pan_route_map_scroll(scroll: ScrollContainer, drag_delta: Vector2) -> void:
	game.route_map_drag_distance += drag_delta.length()
	if game.route_map_drag_distance > game.ROUTE_MAP_DRAG_THRESHOLD:
		game.route_map_drag_suppressed_click = true
	scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - int(drag_delta.y))


func _draw_map_connections(map_area: Control, node_positions: Array) -> void:
	for step_index in range(game.route_nodes.size() - 1):
		for from_index in range(node_positions[step_index].size()):
			for to_index in _route_node_connections(step_index, from_index):
				var to_branch := int(to_index)
				if to_branch < 0 or to_branch >= node_positions[step_index + 1].size():
					continue
				var from_position: Vector2 = node_positions[step_index][from_index] + game.MAP_NODE_SIZE * 0.5
				var to_position: Vector2 = node_positions[step_index + 1][to_branch] + game.MAP_NODE_SIZE * 0.5
				var active := _is_route_connection_active(step_index, from_index, to_branch)
				_add_map_line(map_area, from_position, to_position, active)


func _draw_route_nodes(map_area: Control, node_positions: Array) -> void:
	for step_index in range(game.route_nodes.size()):
		for branch_index in range(game.route_nodes[step_index].size()):
			var route_node: Dictionary = game.route_nodes[step_index][branch_index]
			var node_name: String = route_node["name"]
			var node_type: String = route_node["type"]
			var definition := _map_node_definition(node_type)
			var state := _route_node_state(step_index, branch_index)
			var button = game.ui._make_button("")
			button.name = "RouteNode_%s_%d_%d" % [node_type, step_index, branch_index]
			button.tooltip_text = "%s\n%s" % [str(definition["name"]), str(definition["tooltip"])]
			button.custom_minimum_size = game.MAP_NODE_SIZE
			button.size = game.MAP_NODE_SIZE
			button.position = node_positions[step_index][branch_index]
			button.disabled = state != "available"
			button.focus_mode = Control.FOCUS_NONE
			button.z_index = 20 if state == "available" else 10
			_style_route_node_button(button, node_type, state)
			_add_route_node_icon(button, _route_node_icon_path(route_node, definition), str(definition["icon"]))
			if state == "completed":
				_add_route_node_completed_mark(button)
			elif state == "locked":
				button.modulate = Color(0.55, 0.58, 0.62, 0.72)
			if state == "available":
				button.gui_input.connect(func(event: InputEvent) -> void:
					_handle_route_node_input(button, event, map_area.get_parent() as ScrollContainer, step_index, branch_index, route_node)
				)
			map_area.add_child(button)


func _handle_route_node_input(button: Button, event: InputEvent, scroll: ScrollContainer, step_index: int, branch_index: int, route_node: Dictionary) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			game.route_map_pan_active = true
			game.route_map_pan_last_position = mouse_event.position
			game.route_map_drag_distance = 0.0
			game.route_map_drag_suppressed_click = false
			button.accept_event()
			return

		var should_open = game.route_map_pan_active and not game.route_map_drag_suppressed_click and not button.disabled
		game.route_map_pan_active = false
		button.accept_event()
		if should_open:
			_activate_route_node(step_index, branch_index, route_node)
	elif event is InputEventMouseMotion and game.route_map_pan_active:
		var motion := event as InputEventMouseMotion
		_pan_route_map_scroll(scroll, motion.relative)
		button.accept_event()


func _activate_route_node(step_index: int, branch_index: int, route_node: Dictionary) -> void:
	game.current_route_choice = str(route_node.get("name", ""))
	game.current_node_type = str(route_node.get("type", "battle"))
	if game.route_debug_free_pick and step_index != game.route_stage:
		# Debug-переход: прогресс перематывается к выбранному ряду.
		game.route_selected_indices.resize(step_index)
		game.route_stage = step_index
	_record_route_choice(step_index, branch_index)
	_open_route_node(route_node)


func _add_route_node_icon(button: Button, icon_path: String, fallback_text: String) -> void:
	if icon_path == "":
		button.text = fallback_text
		return

	var icon_texture = game._cached_texture(icon_path)
	if icon_texture == null:
		button.text = fallback_text
		return

	var icon := TextureRect.new()
	icon.name = "RouteNodeIcon"
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10.0
	icon.offset_top = 10.0
	icon.offset_right = -10.0
	icon.offset_bottom = -10.0
	button.add_child(icon)


func _add_route_node_completed_mark(button: Button) -> void:
	var mark := Label.new()
	mark.name = "RouteNodeCompletedMark"
	mark.text = "✓"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_font_size_override("font_size", 24)
	mark.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 1.0))
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.offset_left = 42.0
	mark.offset_top = -6.0
	button.add_child(mark)


func _route_node_icon_path(route_node: Dictionary, definition: Dictionary) -> String:
	if str(route_node.get("type", "")) == "boss" and str(route_node.get("boss_id", "")) == "disk_devourer":
		return str(definition.get("disk_icon_path", definition.get("icon_path", "")))
	return str(definition.get("icon_path", ""))


func _add_map_line(parent: Control, from_position: Vector2, to_position: Vector2, active: bool) -> void:
	var line := ColorRect.new()
	var delta := to_position - from_position
	line.name = "RouteMapLine"
	line.color = Color(0.95, 0.78, 0.32, 0.72) if active else Color(0.35, 0.42, 0.50, 0.42)
	line.position = from_position
	line.size = Vector2(delta.length(), 2.25 if active else 1.25)
	line.rotation = delta.angle()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.z_index = 0
	parent.add_child(line)
	parent.move_child(line, 0)


func _map_node_definition(node_type: String) -> Dictionary:
	return game.MAP_NODE_DEFINITIONS.get(node_type, game.MAP_NODE_DEFINITIONS["battle"])


func _route_node_state(step_index: int, branch_index: int) -> String:
	if game.route_debug_free_pick:
		return "available"
	if step_index < game.route_stage:
		if step_index < game.route_selected_indices.size() and int(game.route_selected_indices[step_index]) == branch_index:
			return "completed"
		return "locked"
	if step_index == game.route_stage:
		if not _is_route_node_reachable(step_index, branch_index):
			return "locked"
		return "available"
	return "locked"


func _is_route_node_reachable(step_index: int, branch_index: int) -> bool:
	if step_index == 0:
		return true
	var previous_step := step_index - 1
	if previous_step < 0 or previous_step >= game.route_nodes.size():
		return false
	if previous_step >= game.route_selected_indices.size():
		return false
	var previous_branch = int(game.route_selected_indices[previous_step])
	if previous_branch < 0:
		return false
	return _route_node_connections(previous_step, previous_branch).has(branch_index)


func _route_node_connections(step_index: int, branch_index: int) -> Array:
	if step_index < 0 or step_index >= game.route_nodes.size():
		return []
	if branch_index < 0 or branch_index >= game.route_nodes[step_index].size():
		return []
	var route_node: Dictionary = game.route_nodes[step_index][branch_index]
	return route_node.get("next_branches", [])


func _is_route_connection_active(step_index: int, from_index: int, to_index: int) -> bool:
	if step_index >= game.route_selected_indices.size():
		return false
	if int(game.route_selected_indices[step_index]) != from_index:
		return false
	if step_index + 1 < game.route_selected_indices.size() and int(game.route_selected_indices[step_index + 1]) >= 0:
		return int(game.route_selected_indices[step_index + 1]) == to_index
	return true


func _record_route_choice(step_index: int, branch_index: int) -> void:
	while game.route_selected_indices.size() <= step_index:
		game.route_selected_indices.append(-1)
	game.route_selected_indices[step_index] = branch_index


func _open_route_node(route_node: Dictionary) -> void:
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	match str(route_node.get("type", "battle")):
		"shop":
			game.ui._show_shop_screen()
		"rest":
			game.ui._show_rest_screen()
		"event":
			game.ui._show_event_screen(route_node)
		"elite_battle":
			game.combat._start_combat(false, "elite")
		"boss":
			game.current_boss_id = str(route_node.get("boss_id", "rift_warden"))
			game.combat._start_combat(true, "boss")
		_:
			game.combat._start_combat(false, "battle")


func _advance_route_after_noncombat() -> void:
	game.route_stage += 1
	_show_battle_map()


func _style_route_node_button(button: Button, node_type: String, state: String) -> void:
	var definition := _map_node_definition(node_type)
	var background: Color = definition.get("color", Color(0.14, 0.18, 0.24, 1.0))
	var border: Color = definition.get("border", Color(0.48, 0.62, 0.72, 1.0))
	if state == "locked":
		background = Color(0.08, 0.09, 0.12, 0.78)
		border = Color(0.25, 0.28, 0.33, 0.85)
	elif state == "completed":
		background = Color(0.13, 0.16, 0.18, 0.90)
		border = Color(0.95, 0.78, 0.32, 0.82)
	elif state == "available":
		background = background.lightened(0.08)
		border = Color(1.0, 0.86, 0.28, 1.0)

	button.add_theme_stylebox_override("normal", _map_node_button_style(background, border))
	button.add_theme_stylebox_override("hover", _map_node_button_style(background.lightened(0.18), Color(1.0, 0.86, 0.28, 1.0)))
	button.add_theme_stylebox_override("pressed", _map_node_button_style(background.darkened(0.16), border))
	button.add_theme_stylebox_override("disabled", _map_node_button_style(background, border))
	button.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.74, 0.76, 1.0) if state == "completed" else Color(0.46, 0.48, 0.52, 1.0))
	button.add_theme_font_size_override("font_size", 34)


func _map_node_button_style(background: Color, _border: Color) -> StyleBox:
	var tint := background.lightened(0.48)
	tint.a = 1.0
	if game.ui != null and game.ui.has_method("_global_texture_style"):
		return game.ui._global_texture_style(
			"res://assets/sprites/ui/frames/global/ui_card_frame.png",
			Vector4(30, 30, 30, 30),
			tint,
			Vector4.ZERO
		)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = _border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
