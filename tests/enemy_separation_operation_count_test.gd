extends SceneTree

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const SPATIAL_INDEX := preload("res://scripts/combat_spatial_index.gd")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const SEARCH_LIMIT := 140.0
const FIXTURE_SEED := 3918001
const BASELINE_REVISION := "f58261208246e081d534afdf22a13f8a010e5eeb"
const CROWD_CASES := [
	{"id": "encounter_deck_5", "count": 5},
	{"id": "encounter_deck_6", "count": 6},
	{"id": "encounter_deck_7", "count": 7},
	{"id": "normal_default_cap", "count": 22},
	{"id": "normal_elite_max", "count": 48},
	{"id": "normal_elite_max_plus_reward_carrier", "count": 49},
]
# These signatures were produced by executing the unchanged separation
# implementation at BASELINE_REVISION with counter-only instrumentation. They
# are not derived from the expected-neighbor oracle below.
const BASELINE_NEIGHBOR_SIGNATURES := {
	"sparse/encounter_deck_5": "cd78315e89efd3b995a46d7db22d66e6f39d18760da8091498c965ff94908153",
	"dense/encounter_deck_5": "5653518714ac5929a3d2b4d40be091de2cd71e1616347b5fea133c224849d04e",
	"sparse/encounter_deck_6": "4d0abf09e1a346c2cce4b4f00e11d4b8a280230f9464518b725b6d94a077f287",
	"dense/encounter_deck_6": "f9e4a4b6b431468d46b3552c7b71db07410b92c8547f83159c6026275eb56021",
	"sparse/encounter_deck_7": "7f5db18c899569053eb6651b6d29b70595abb41e80189a89ced18896700dfd50",
	"dense/encounter_deck_7": "6cba0bbe3dce6236ffefcf33f81c887db8825ce4b53a3a2618db79286c917145",
	"sparse/normal_default_cap": "7c170059479ea337a6ca36cfd67f74b1a333b5d9c02ef8d9cd68c0938e0eaab6",
	"dense/normal_default_cap": "da6da250b086ca7a54347e5c1747557f1f4e0364c8732bf4a904940e53fbdecc",
	"sparse/normal_elite_max": "ea671cbe88347b12c30482ade7b99b0ce6aaa66da8c36c7bb407716f7e16dfc0",
	"dense/normal_elite_max": "a1f809051efd814e5ce76b2de96be967be3229e9a1486197ca08a91e4de20273",
	"sparse/normal_elite_max_plus_reward_carrier": "5fc7ab6b2bc5b1233b92ef1ffb9b52e72569c46c507c53d288da2d6ba522b6eb",
	"dense/normal_elite_max_plus_reward_carrier": "fb0c7f3db5115c574e421bf48bca3421ea18ee08898a96a9701769bbb3e9eca6",
}


func _initialize() -> void:
	var errors: Array[String] = []
	for crowd_case in CROWD_CASES:
		await _measure_fixture("sparse", crowd_case, errors)
		await _measure_fixture("dense", crowd_case, errors)
	await _check_edge_fixture(errors)
	await _check_same_frame_move_fixture(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("Enemy separation operation count: %s" % error)
		quit(1)
		return
	print("Enemy separation operation-count test passed.")
	quit(0)


func _make_enemy(holder: Node2D, position: Vector2, fixture_index: int) -> Node2D:
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(enemy)
	enemy.global_position = position
	enemy.set_meta("separation_fixture_index", fixture_index)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _fixture_positions(kind: String, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED + count * 101 + (0 if kind == "sparse" else 1)
	var columns := ceili(sqrt(float(count)))
	var spacing := 210.0 if kind == "sparse" else 8.0
	var jitter := 7.0 if kind == "sparse" else 0.35
	for index in range(count):
		positions.append(Vector2(
			300.0 + float(index % columns) * spacing + rng.randf_range(-jitter, jitter),
			300.0 + float(index / columns) * spacing + rng.randf_range(-jitter, jitter)
		))
	return positions


func _fixture_hash(kind: String, count: int, positions: Array[Vector2]) -> String:
	var payload := "%s|%d|%d" % [kind, count, FIXTURE_SEED]
	for position in positions:
		payload += "|%.6f,%.6f" % [position.x, position.y]
	return payload.sha256_text()


func _expected_neighbors(source: Node2D, all_enemies: Array[Node2D]) -> Array[Node2D]:
	var distances: Array[float] = []
	var neighbors: Array[Node2D] = []
	var limit_sq := SEARCH_LIMIT * SEARCH_LIMIT
	for other in all_enemies:
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


func _neighbor_signature(enemies: Array[Node2D]) -> String:
	var payload := ""
	for enemy in enemies:
		payload += "%d:" % int(enemy.get_meta("separation_fixture_index", -1))
		for neighbor in enemy.get("_separation_neighbors") as Array:
			payload += "%d," % int(neighbor.get_meta("separation_fixture_index", -1))
		payload += ";"
	return payload.sha256_text()


func _measure_fixture(kind: String, crowd_case: Dictionary, errors: Array[String]) -> void:
	var count := int(crowd_case["count"])
	var holder := Node2D.new()
	root.add_child(holder)
	var positions := _fixture_positions(kind, count)
	var enemies: Array[Node2D] = []
	for index in range(count):
		enemies.append(_make_enemy(holder, positions[index], index))
	await process_frame

	TARGET_QUERY.debug_snapshot_build_visits_enabled = true
	TARGET_QUERY.debug_snapshot_build_visits = 0
	SPATIAL_INDEX.debug_candidate_visits_enabled = true
	SPATIAL_INDEX.debug_candidate_visits = 0
	SPATIAL_INDEX.debug_build_visits = 0
	SPATIAL_INDEX.debug_move_update_visits = 0
	for enemy in enemies:
		var expected := _expected_neighbors(enemy, enemies)
		enemy.call("_refresh_separation_neighbors")
		var actual: Array = enemy.get("_separation_neighbors")
		if actual != expected:
			errors.append("%s/%s changed four-neighbor order or membership." % [kind, crowd_case["id"]])
			break
	TARGET_QUERY.debug_snapshot_build_visits_enabled = false
	SPATIAL_INDEX.debug_candidate_visits_enabled = false

	var snapshot_visits: int = TARGET_QUERY.debug_snapshot_build_visits
	var index_build_visits: int = SPATIAL_INDEX.debug_build_visits
	var index_update_visits: int = SPATIAL_INDEX.debug_move_update_visits
	var query_visits: int = SPATIAL_INDEX.debug_candidate_visits
	var total_work := snapshot_visits + index_build_visits + index_update_visits + query_visits
	var fixture_id := "%s/%s" % [kind, crowd_case["id"]]
	var neighbor_signature := _neighbor_signature(enemies)
	if snapshot_visits != count:
		errors.append("%s/%s snapshot visits were %d, expected %d." % [kind, crowd_case["id"], snapshot_visits, count])
	if index_build_visits != count:
		errors.append("%s/%s index-build visits were %d, expected %d." % [kind, crowd_case["id"], index_build_visits, count])
	if index_update_visits != 0:
		errors.append("%s/%s unexpectedly moved %d indexed enemies." % [kind, crowd_case["id"], index_update_visits])
	if kind == "dense" and query_visits != count * count:
		errors.append("%s/%s must retain dense-cell query cost (%d != %d)." % [kind, crowd_case["id"], query_visits, count * count])
	if kind == "sparse" and query_visits >= count * count:
		errors.append("%s/%s did not reduce candidate-query visits (%d >= %d)." % [kind, crowd_case["id"], query_visits, count * count])
	if kind == "sparse" and total_work >= count + count * count:
		errors.append("%s total work was not reduced (%d >= %d)." % [fixture_id, total_work, count + count * count])
	if neighbor_signature != str(BASELINE_NEIGHBOR_SIGNATURES[fixture_id]):
		errors.append("%s neighbor signature differs from the measured immutable baseline." % fixture_id)

	var result := {
		"revision": "candidate",
		"fixture": fixture_id,
		"seed": FIXTURE_SEED,
		"enemy_count": count,
		"fixture_sha256": _fixture_hash(kind, count, positions),
		"baseline_revision": BASELINE_REVISION,
		"neighbor_signature_sha256": neighbor_signature,
		"snapshot_build_visits": snapshot_visits,
		"spatial_index_build_visits": index_build_visits,
		"spatial_index_update_visits": index_update_visits,
		"candidate_query_visits": query_visits,
		"total_work": total_work,
	}
	print("MEASUREMENT %s" % JSON.stringify(result))
	holder.queue_free()
	await process_frame


func _check_edge_fixture(errors: Array[String]) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var source := _make_enemy(holder, Vector2.ZERO, 0)
	var inside := _make_enemy(holder, Vector2(139.999, 0), 1)
	var edge := _make_enemy(holder, Vector2(140.0, 0), 2)
	await process_frame
	source.call("_refresh_separation_neighbors")
	var actual: Array = source.get("_separation_neighbors")
	if not actual.has(inside) or actual.has(edge):
		errors.append("Range edge fixture did not preserve strict < 140px behavior.")
	holder.queue_free()
	await process_frame


func _check_same_frame_move_fixture(errors: Array[String]) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var source := _make_enemy(holder, Vector2(280.0, 0.0), 0)
	var mover := _make_enemy(holder, Vector2(139.0, 0.0), 1)
	await process_frame

	TARGET_QUERY.debug_snapshot_build_visits_enabled = true
	TARGET_QUERY.debug_snapshot_build_visits = 0
	SPATIAL_INDEX.debug_candidate_visits_enabled = true
	SPATIAL_INDEX.debug_candidate_visits = 0
	SPATIAL_INDEX.debug_build_visits = 0
	SPATIAL_INDEX.debug_move_update_visits = 0
	source.call("_refresh_separation_neighbors")
	mover.global_position = Vector2(141.0, 0.0)
	source.call("_refresh_separation_neighbors")
	TARGET_QUERY.debug_snapshot_build_visits_enabled = false
	SPATIAL_INDEX.debug_candidate_visits_enabled = false

	var actual: Array = source.get("_separation_neighbors")
	if not actual.has(mover):
		errors.append("Same-frame move fixture missed the current-position neighbour.")
	if SPATIAL_INDEX.debug_move_update_visits != 1:
		errors.append("Same-frame move fixture recorded %d index-update visits, expected 1." % SPATIAL_INDEX.debug_move_update_visits)
	var total_work := (
		TARGET_QUERY.debug_snapshot_build_visits
		+ SPATIAL_INDEX.debug_build_visits
		+ SPATIAL_INDEX.debug_move_update_visits
		+ SPATIAL_INDEX.debug_candidate_visits
	)
	var result := {
		"revision": "candidate",
		"fixture": "same_frame_cell_boundary_move",
		"enemy_count": 2,
		"baseline_snapshot_build_visits": 2,
		"baseline_candidate_query_visits": 4,
		"baseline_total_work": 6,
		"snapshot_build_visits": TARGET_QUERY.debug_snapshot_build_visits,
		"spatial_index_build_visits": SPATIAL_INDEX.debug_build_visits,
		"spatial_index_update_visits": SPATIAL_INDEX.debug_move_update_visits,
		"candidate_query_visits": SPATIAL_INDEX.debug_candidate_visits,
		"total_work": total_work,
	}
	print("MEASUREMENT %s" % JSON.stringify(result))
	holder.queue_free()
	await process_frame
