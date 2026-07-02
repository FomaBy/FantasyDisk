extends SceneTree

# SCRUM-537 / SCRUM-787: route chest reward as an UNMISSABLE chest-line row.
# Verifies that exactly CHEST_LINE_ROWS full rows have EVERY branch = chest (so any chosen
# path hits a chest), placement preserves shops and start battle-only rows, icon/tooltip
# contract, 1-of-3 artifact choice, exactly one artifact applied per chest row, and no
# same-node re-open after returning to the map.

const CHEST_ICON_PATH := "res://assets/sprites/map_icons/map_chest_artifact.png"
const ProgressionData := preload("res://scripts/progression_data.gd")


func _fail(message: String) -> void:
	push_error("[route_chest_artifact] " + message)
	quit(1)


func _initialize() -> void:
	var ok := await _run()
	if ok:
		print("[route_chest_artifact] PASSED")
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
	if route_obj == null:
		_fail("route component missing")
		return false

	for attempt in range(8):
		var route: Array = main.call("_generate_route")
		if not _assert_generated_route(main, route, attempt):
			return false

	if not await _assert_open_choose_and_advance(main):
		return false

	main.queue_free()
	return true


# Полные «линии» сундуков: ряды (кроме босс-ряда), где КАЖДАЯ ветка — chest.
func _full_chest_rows(route: Array) -> Array:
	var rows := []
	# route.back() — ряд босса; не-боссовые ряды = 0..route.size()-2.
	for row_index in range(route.size() - 1):
		var row: Array = route[row_index]
		if row.is_empty():
			continue
		var all_chest := true
		for route_node in row:
			if str((route_node as Dictionary).get("type", "")) != "chest":
				all_chest = false
				break
		if all_chest:
			rows.append(row_index)
	return rows


func _assert_generated_route(main: Node, route: Array, attempt: int) -> bool:
	var non_boss_rows := route.size() - 1
	var expected_lines := int(main.CHEST_LINE_ROWS)
	var start_battle_only := 2  # route_map_screen.START_BATTLE_ONLY_ROWS

	var chest_rows := _full_chest_rows(route)
	# SCRUM-787: ≥1 непропускаемая линия; ровно CHEST_LINE_ROWS полных chest-рядов.
	if chest_rows.size() != expected_lines:
		_fail("attempt %d: expected %d full chest-line row(s), got %d" % [attempt, expected_lines, chest_rows.size()])
		return false

	var shop_count := 0
	for row_index in range(route.size()):
		for route_node in (route[row_index] as Array):
			if str((route_node as Dictionary).get("type", "")) == "shop":
				shop_count += 1
	if shop_count != 2:
		_fail("attempt %d: chest-line placement must preserve exactly two shops, got %d" % [attempt, shop_count])
		return false

	for chest_row in chest_rows:
		# Линия — внутренний ряд (не стартовый battle-only, не босс-ряд).
		if int(chest_row) < start_battle_only or int(chest_row) >= non_boss_rows:
			_fail("attempt %d: chest-line row %d must be an inner row (>=%d, <%d)" % [attempt, chest_row, start_battle_only, non_boss_rows])
			return false
		# Непропускаемость: КАЖДАЯ ветка ряда — сундук (любой путь проходит сундук).
		var row: Array = route[chest_row]
		for route_node in row:
			if str((route_node as Dictionary).get("type", "")) != "chest":
				_fail("attempt %d: chest-line row %d has a non-chest branch (missable)" % [attempt, chest_row])
				return false

	for early_row in range(mini(start_battle_only, non_boss_rows)):
		for route_node in (route[early_row] as Array):
			if str((route_node as Dictionary).get("type", "")) != "battle":
				_fail("attempt %d: early row %d must remain battle-only" % [attempt, early_row])
				return false

	# Icon/tooltip контракт на одном сундуке линии.
	var sample_row: int = int(chest_rows[0])
	var chest_node: Dictionary = (route[sample_row] as Array)[0]
	var definition: Dictionary = main.get("route").call("_map_node_definition", "chest")
	var icon_path: String = main.call("_route_node_icon_path", chest_node, definition)
	if icon_path != CHEST_ICON_PATH:
		_fail("chest icon mismatch: %s" % icon_path)
		return false
	var tooltip: String = main.get("route").call("_node_preview_tooltip", chest_node, definition)
	if not tooltip.contains("1 из 3") or not tooltip.contains("артефакт"):
		_fail("chest tooltip does not explain artifact choice: %s" % tooltip)
		return false
	return true


func _assert_open_choose_and_advance(main: Node) -> bool:
	var route: Array = main.call("_generate_route")
	var chest_rows := _full_chest_rows(route)
	if chest_rows.is_empty():
		_fail("generated route has no full chest-line row")
		return false
	var chest_row: int = int(chest_rows[0])
	var chest_branch := 0  # вся линия — сундуки; берём первую ветку

	main.set("route_nodes", route)
	main.set("route_stage", chest_row)
	main.set("route_selected_indices", _route_path_to_row(route, chest_row, chest_branch))
	main.set("run_player_snapshot", {})
	main.get("route").call("_activate_route_node", chest_row, chest_branch, (route[chest_row] as Array)[chest_branch])
	await process_frame
	await process_frame

	var row := main.find_child("EliteArtifactRewardRow", true, false) as HBoxContainer
	if row == null:
		_fail("opening chest did not show artifact reward row")
		return false
	if row.get_child_count() != 3:
		_fail("expected exactly 3 chest artifact buttons, got %d" % row.get_child_count())
		return false

	var choices: Array = ProgressionData.elite_artifact_choices(main.call("route_scaling_stage"), 3)
	var ids := {}
	for reward in choices:
		var reward_id := str((reward as Dictionary).get("id", ""))
		if reward_id == "" or ids.has(reward_id):
			_fail("artifact choices must contain 3 unique ids, duplicate/empty: %s" % reward_id)
			return false
		ids[reward_id] = true

	var first_button := row.get_child(0) as Button
	if first_button == null:
		_fail("first artifact choice is not a Button")
		return false
	first_button.pressed.emit()
	await process_frame
	await process_frame

	var snapshot: Dictionary = main.get("run_player_snapshot")
	var artifacts: Array = snapshot.get("artifacts", [])
	# Игрок проходит ровно ОДНУ ветку ряда → получает ровно 1 артефакт с chest-линии.
	if artifacts.size() != 1:
		_fail("choosing chest artifact must apply exactly one artifact, got %d" % artifacts.size())
		return false
	if int(main.get("route_stage")) != chest_row + 1:
		_fail("choosing chest must advance route_stage to %d, got %d" % [chest_row + 1, int(main.get("route_stage"))])
		return false
	var state: String = main.get("route").call("_route_node_state", chest_row, chest_branch)
	if state != "completed":
		_fail("completed chest should not be available after return to map; state=%s" % state)
		return false
	return true


func _route_path_to_row(route: Array, target_row: int, target_branch: int) -> Array:
	var path := []
	if target_row <= 0:
		return path
	var next_branch := target_branch
	for row_index in range(target_row - 1, -1, -1):
		var selected := 0
		var row: Array = route[row_index]
		for branch_index in range(row.size()):
			var route_node: Dictionary = row[branch_index]
			var branches: Array = route_node.get("next_branches", [])
			if branches.has(next_branch):
				selected = branch_index
				break
		path.insert(0, selected)
		next_branch = selected
	return path
