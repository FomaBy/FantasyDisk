class_name CombatSpatialIndex
extends RefCounted

# Separation refreshes need candidates only within 140px. Cells deliberately
# match that reach: every possible candidate is in the source cell or one of
# its eight neighbours. A dense cell still has dense-cell cost by design.
const CELL_SIZE := 140.0

static var _cached_tree_id := 0
static var _cached_query_generation := -1
static var _cached_frame_key := -1
static var _cells: Dictionary = {}
static var _node_cells: Dictionary = {}

# FAN-3918: test-only counter for comparable fixed-fixture visit counts.
static var debug_candidate_visits_enabled := false
static var debug_candidate_visits := 0
static var debug_build_visits := 0
static var debug_move_update_visits := 0


static func candidates(source: Node, position: Vector2) -> Array[Node2D]:
	_ensure_current(source)
	var result: Array[Node2D] = []
	var source_cell := _cell_for(position)
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			var cell: Array = _cells.get(source_cell + Vector2i(x_offset, y_offset), [])
			for node in cell:
				if debug_candidate_visits_enabled:
					debug_candidate_visits += 1
				if is_instance_valid(node):
					result.append(node)
	return result


static func track_moved(node: Node2D) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	if _cached_frame_key != _frame_key():
		return
	var tree := node.get_tree()
	if tree == null or tree.get_instance_id() != _cached_tree_id:
		return
	if CombatTargetQuery.cache_generation() != _cached_query_generation:
		return
	var node_id := node.get_instance_id()
	if not _node_cells.has(node_id):
		return
	if debug_candidate_visits_enabled:
		debug_move_update_visits += 1
	var previous_cell: Vector2i = _node_cells[node_id]
	var current_cell := _cell_for(node.global_position)
	if current_cell == previous_cell:
		return
	var previous_nodes: Array = _cells.get(previous_cell, [])
	var previous_index := previous_nodes.find(node)
	if previous_index >= 0:
		previous_nodes.remove_at(previous_index)
		if previous_nodes.is_empty():
			_cells.erase(previous_cell)
	var current_nodes: Array = _cells.get(current_cell, [])
	current_nodes.append(node)
	_cells[current_cell] = current_nodes
	_node_cells[node_id] = current_cell


static func _ensure_current(source: Node) -> void:
	var enemies := CombatTargetQuery.enemies(source)
	var tree := source.get_tree() if source != null and source.is_inside_tree() else null
	var tree_id := tree.get_instance_id() if tree != null else 0
	var generation := CombatTargetQuery.cache_generation()
	if _cached_tree_id == tree_id and _cached_query_generation == generation:
		return
	_cached_tree_id = tree_id
	_cached_query_generation = generation
	_cached_frame_key = _frame_key()
	_cells.clear()
	_node_cells.clear()
	for node in enemies:
		if debug_candidate_visits_enabled:
			debug_build_visits += 1
		if not is_instance_valid(node):
			continue
		var cell_key := _cell_for(node.global_position)
		var cell: Array = _cells.get(cell_key, [])
		cell.append(node)
		_cells[cell_key] = cell
		_node_cells[node.get_instance_id()] = cell_key


static func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))


static func _frame_key() -> int:
	return Engine.get_process_frames() + Engine.get_physics_frames() * 1000000
