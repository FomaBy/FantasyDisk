extends SceneTree

const SPATIAL_INDEX := preload("res://scripts/combat_spatial_index.gd")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ENEMY_COUNT := 48
const SEARCH_LIMIT := 140.0


func _initialize() -> void:
	var errors: Array[String] = []
	await _check_sparse_fixture(errors)
	await _check_dense_fixture(errors)
	await _check_edge_fixture(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("Enemy separation operation count: %s" % error)
		quit(1)
		return
	print("Enemy separation operation-count test passed.")
	quit(0)


func _make_enemy(holder: Node2D, position: Vector2) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _expected_neighbors(source: Node2D, all_enemies: Array[Node2D], baseline_visits: Array[int]) -> Array[Node2D]:
	var distances: Array[float] = []
	var neighbors: Array[Node2D] = []
	var limit_sq := SEARCH_LIMIT * SEARCH_LIMIT
	for other in all_enemies:
		baseline_visits[0] += 1
		if other == source or not is_instance_valid(other):
			continue
		var distance_sq := source.global_position.distance_squared_to(other.global_position)
		if distance_sq >= limit_sq:
			continue
		var insert_at := distances.size()
		for index in range(distances.size()):
			if distance_sq < distances[index]:
				insert_at = index
				break
		if insert_at >= 4:
			continue
		distances.insert(insert_at, distance_sq)
		neighbors.insert(insert_at, other)
		if distances.size() > 4:
			distances.resize(4)
			neighbors.resize(4)
	return neighbors


func _assert_parity(enemies: Array[Node2D], baseline_visits: Array[int], errors: Array[String], label: String) -> void:
	SPATIAL_INDEX.debug_candidate_visits_enabled = true
	SPATIAL_INDEX.debug_candidate_visits = 0
	for enemy in enemies:
		var expected := _expected_neighbors(enemy, enemies, baseline_visits)
		enemy.call("_refresh_separation_neighbors")
		var actual: Array = enemy.get("_separation_neighbors")
		if actual != expected:
			errors.append("%s fixture changed four-neighbor order or membership." % label)
			break
	SPATIAL_INDEX.debug_candidate_visits_enabled = false


func _check_sparse_fixture(errors: Array[String]) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var enemies: Array[Node2D] = []
	for index in range(ENEMY_COUNT):
		enemies.append(_make_enemy(holder, Vector2(float(index % 8) * 210.0, float(index / 8) * 210.0)))
	await process_frame
	var baseline_visits: Array[int] = [0]
	_assert_parity(enemies, baseline_visits, errors, "sparse")
	var candidate_visits: int = SPATIAL_INDEX.debug_candidate_visits
	if baseline_visits[0] != ENEMY_COUNT * ENEMY_COUNT:
		errors.append("Sparse baseline visit count was %d, expected %d." % [baseline_visits[0], ENEMY_COUNT * ENEMY_COUNT])
	if candidate_visits >= baseline_visits[0]:
		errors.append("Sparse candidate visits were not reduced (%d >= %d)." % [candidate_visits, baseline_visits[0]])
	else:
		print("INFO sparse visits: baseline=%d candidate=%d" % [baseline_visits[0], candidate_visits])
	holder.queue_free()
	await process_frame


func _check_dense_fixture(errors: Array[String]) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var enemies: Array[Node2D] = []
	for index in range(ENEMY_COUNT):
		enemies.append(_make_enemy(holder, Vector2(float(index % 8) * 8.0, float(index / 8) * 8.0)))
	await process_frame
	var baseline_visits: Array[int] = [0]
	_assert_parity(enemies, baseline_visits, errors, "dense")
	var candidate_visits: int = SPATIAL_INDEX.debug_candidate_visits
	if candidate_visits != baseline_visits[0]:
		errors.append("Dense fixture must retain full-cell cost (%d != %d)." % [candidate_visits, baseline_visits[0]])
	else:
		print("INFO dense visits: baseline=%d candidate=%d" % [baseline_visits[0], candidate_visits])
	holder.queue_free()
	await process_frame


func _check_edge_fixture(errors: Array[String]) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var source := _make_enemy(holder, Vector2.ZERO)
	var inside := _make_enemy(holder, Vector2(139.999, 0))
	var edge := _make_enemy(holder, Vector2(140.0, 0))
	await process_frame
	source.call("_refresh_separation_neighbors")
	var actual: Array = source.get("_separation_neighbors")
	if not actual.has(inside) or actual.has(edge):
		errors.append("Range edge fixture did not preserve strict < 140px behavior.")
	holder.queue_free()
	await process_frame
