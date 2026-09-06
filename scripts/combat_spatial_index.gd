class_name CombatSpatialIndex
extends RefCounted

# Separation refreshes need candidates only within 140px. Cells deliberately
# match that reach: every possible candidate is in the source cell or one of
# its eight neighbours. A dense cell still has dense-cell cost by design.
const CELL_SIZE := 140.0

static var _cached_tree_id := 0
static var _cached_query_generation := -1
static var _cells: Dictionary = {}

# FAN-3918: test-only counter for comparable fixed-fixture visit counts.
static var debug_candidate_visits_enabled := false
static var debug_candidate_visits := 0


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


static func _ensure_current(source: Node) -> void:
	var enemies := CombatTargetQuery.enemies(source)
	var tree := source.get_tree() if source != null and source.is_inside_tree() else null
	var tree_id := tree.get_instance_id() if tree != null else 0
	var generation := CombatTargetQuery.cache_generation()
	if _cached_tree_id == tree_id and _cached_query_generation == generation:
		return
	_cached_tree_id = tree_id
	_cached_query_generation = generation
	_cells.clear()
	for node in enemies:
		if not is_instance_valid(node):
			continue
		var cell_key := _cell_for(node.global_position)
		var cell: Array = _cells.get(cell_key, [])
		cell.append(node)
		_cells[cell_key] = cell


static func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))
