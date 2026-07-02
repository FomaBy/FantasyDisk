extends SceneTree

# SCRUM-718 (refactor wave 0.2.0): route-graph traversability invariants. runtime_smoke
# checks that nodes expose next_branches and that paths are limited, but nothing verified
# the generated graph is fully traversable. A connection-assignment regression could
# strand a node (no incoming) or dead-end a branch (no outgoing) -> soft-lock. This sweeps
# many freshly generated routes and asserts, via BFS, that every node is reachable from
# row 0 and that the boss is reachable. Read-only; no generation logic changed.

const ROUTE_SAMPLES := 24


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Main scene did not load.")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var errors: Array = []
	var steps_to_boss := int(main.ROUTE_STEPS_TO_BOSS)
	for sample in range(ROUTE_SAMPLES):
		var route: Array = main._generate_route()
		_validate_route(errors, route, steps_to_boss, sample)
		if not errors.is_empty():
			break

	main.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Route reachability: %s" % e)
		push_error("Route generation reachability test: %d errors." % errors.size())
		quit(1)
		return
	print("Route generation reachability test passed (%d routes, %d rows + boss)." % [ROUTE_SAMPLES, steps_to_boss])
	quit()


func _validate_route(errors: Array, route: Array, steps_to_boss: int, sample: int) -> void:
	if route.size() != steps_to_boss + 1:
		errors.append("sample %d: route has %d rows, expected %d activity rows + boss" % [sample, route.size(), steps_to_boss + 1])
		return
	var boss_row: Array = route[route.size() - 1]
	if boss_row.size() != 1 or str((boss_row[0] as Dictionary).get("type", "")) != "boss":
		errors.append("sample %d: last row must be a single boss node" % sample)
		return

	# Forward edges: every non-boss node exposes >=1 in-range next_branch.
	for row_index in range(route.size() - 1):
		var row: Array = route[row_index]
		var next_size: int = (route[row_index + 1] as Array).size()
		for branch_index in range(row.size()):
			var node: Dictionary = row[branch_index]
			var next_branches: Array = node.get("next_branches", [])
			if next_branches.is_empty():
				errors.append("sample %d: node [%d,%d] is a dead end (no next_branches)" % [sample, row_index, branch_index])
				return
			for nb in next_branches:
				if int(nb) < 0 or int(nb) >= next_size:
					errors.append("sample %d: node [%d,%d] next_branch %s out of range (next size %d)" % [sample, row_index, branch_index, str(nb), next_size])
					return

	# BFS from every row-0 node: every node in every row must be reachable.
	var reached := {}  # "row:branch" -> true
	var frontier: Array = []
	for branch_index in range((route[0] as Array).size()):
		var key := "0:%d" % branch_index
		reached[key] = true
		frontier.append([0, branch_index])
	while not frontier.is_empty():
		var cur: Array = frontier.pop_back()
		var r := int(cur[0])
		var b := int(cur[1])
		if r >= route.size() - 1:
			continue
		var node: Dictionary = (route[r] as Array)[b]
		for nb in node.get("next_branches", []):
			var nkey := "%d:%d" % [r + 1, int(nb)]
			if not reached.has(nkey):
				reached[nkey] = true
				frontier.append([r + 1, int(nb)])

	for row_index in range(route.size()):
		var row: Array = route[row_index]
		for branch_index in range(row.size()):
			if not reached.has("%d:%d" % [row_index, branch_index]):
				errors.append("sample %d: node [%d,%d] is unreachable from row 0 (soft-lock risk)" % [sample, row_index, branch_index])
				return

	if not reached.has("%d:0" % (route.size() - 1)):
		errors.append("sample %d: boss node is unreachable" % sample)
