extends SceneTree

# FAN-3917: characterization + top-k operation parity for
# CombatTargetQuery.nearest_many. The suite is intentionally valid against the
# pre-optimization implementation: the frozen `_baseline_nearest_many` replica
# below is the measured operation baseline, and every parity assertion compares
# the shipped implementation against that replica on a fixed seeded fixture.

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")

const FIXTURE_SEED := 3917
const FIXTURE_ENEMY_COUNT := 200
const QUERY_RANGE := 600.0
# Exact duplicates are deliberate: they force distance ties across the top-k
# boundary so tie handling is characterized, not assumed.
const TIE_POSITIONS := [Vector2(150.0, 0.0), Vector2(150.0, 0.0), Vector2(150.0, 0.0)]


func _initialize() -> void:
	var errors := []
	var holder := Node2D.new()
	holder.name = "TopKFixture"
	root.add_child(holder)
	await process_frame

	var origin := Node2D.new()
	origin.name = "QueryOrigin"
	holder.add_child(origin)
	origin.global_position = Vector2.ZERO

	var enemies := _spawn_fixture(holder)
	var boundary := _spawn_boundary_pair(holder)
	await process_frame

	_counts_semantics(origin, enemies, errors)
	_boundary_semantics(origin, boundary, errors)
	_exclusion_semantics(origin, enemies, errors)
	_tie_semantics(origin, enemies, errors)
	_parity_and_operations(origin, enemies, errors)

	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for error in errors:
			push_error("CombatTargetQuery top-k: %s" % error)
		quit(1)
		return
	print("CombatTargetQuery top-k test passed.")
	quit(0)


func _spawn_fixture(holder: Node2D) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	var spawned: Array = []
	for i in FIXTURE_ENEMY_COUNT:
		var position := Vector2(
			rng.randf_range(-QUERY_RANGE * 1.4, QUERY_RANGE * 1.4),
			rng.randf_range(-QUERY_RANGE * 1.4, QUERY_RANGE * 1.4)
		)
		if i < TIE_POSITIONS.size():
			position = TIE_POSITIONS[i]
		var enemy := Node2D.new()
		enemy.name = "SeededEnemy%d" % i
		holder.add_child(enemy)
		enemy.global_position = position
		enemy.add_to_group("enemies")
		spawned.append(enemy)
	return spawned


func _spawn_boundary_pair(holder: Node2D) -> Dictionary:
	# One enemy exactly at QUERY_RANGE from the origin and one just past it.
	var at_edge := Node2D.new()
	at_edge.name = "AtEdgeEnemy"
	holder.add_child(at_edge)
	at_edge.global_position = Vector2(QUERY_RANGE, 0.0)
	at_edge.add_to_group("enemies")
	var past_edge := Node2D.new()
	past_edge.name = "PastEdgeEnemy"
	holder.add_child(past_edge)
	past_edge.global_position = Vector2(QUERY_RANGE + 1.0, 0.0)
	past_edge.add_to_group("enemies")
	return {"at_edge": at_edge, "past_edge": past_edge}


func _counts_semantics(origin: Node2D, enemies: Array, errors: Array) -> void:
	var single := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, 1)
	if single.size() != 1 or single[0] != TARGET_QUERY.nearest(origin, origin.global_position, QUERY_RANGE):
		errors.append("count=1 must return exactly the nearest enemy")
	var empty := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, 0)
	if not empty.is_empty():
		errors.append("count=0 must return an empty array")
	var all_targets := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, enemies.size() + 10)
	if all_targets.size() > enemies.size() + 2:
		errors.append("count above the in-range population must return only the in-range enemies")
	var distances := []
	for node in all_targets:
		distances.append(origin.global_position.distance_squared_to(node.global_position))
	for i in distances.size() - 1:
		if distances[i] > distances[i + 1]:
			errors.append("nearest_many result must be sorted by ascending distance")
			break


func _boundary_semantics(origin: Node2D, boundary: Dictionary, errors: Array) -> void:
	# nearest uses a strict comparison against range_limit^2, so an enemy at
	# exactly range_limit is excluded; nearest_many/in_radius use <= / > culls
	# and include it.
	var nearest_at_edge := TARGET_QUERY.nearest(origin, origin.global_position, QUERY_RANGE)
	if nearest_at_edge == boundary["at_edge"]:
		errors.append("nearest must exclude an enemy at exactly range_limit (strict boundary)")
	var many_at_edge := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, FIXTURE_ENEMY_COUNT + 10)
	if not many_at_edge.has(boundary["at_edge"]):
		errors.append("nearest_many must include an enemy at exactly range_limit (inclusive boundary)")
	if many_at_edge.has(boundary["past_edge"]):
		errors.append("nearest_many must exclude an enemy past range_limit")
	var radius_hits := TARGET_QUERY.in_radius(origin, origin.global_position, QUERY_RANGE)
	if not radius_hits.has(boundary["at_edge"]) or radius_hits.has(boundary["past_edge"]):
		errors.append("in_radius boundary must be inclusive at exactly radius")


func _exclusion_semantics(origin: Node2D, enemies: Array, errors: Array) -> void:
	var nearest_node = TARGET_QUERY.nearest(origin, origin.global_position, QUERY_RANGE)
	var excluded := {nearest_node.get_instance_id(): true}
	var rerouted := TARGET_QUERY.nearest(origin, origin.global_position, QUERY_RANGE, excluded)
	if rerouted == nearest_node:
		errors.append("nearest must honor excluded_ids")
	var many_excluded := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, 3, excluded)
	if many_excluded.has(nearest_node):
		errors.append("nearest_many must honor excluded_ids")
	if many_excluded.size() > 3:
		errors.append("nearest_many must cap the result at count")


func _tie_semantics(origin: Node2D, enemies: Array, errors: Array) -> void:
	var first_pass := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, 5)
	var second_pass := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, 5)
	if first_pass.size() != second_pass.size():
		errors.append("nearest_many tie handling must be deterministic in size")
	else:
		for i in first_pass.size():
			if first_pass[i] != second_pass[i]:
				errors.append("nearest_many tie handling must pick identical nodes across runs")
				break
	var full := TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, enemies.size() + 10)
	var tie_count := 0
	for node in full:
		if origin.global_position.distance_squared_to(node.global_position) == 150.0 * 150.0:
			tie_count += 1
	if tie_count != TIE_POSITIONS.size():
		errors.append("every member of the fixed tie cluster must be selected once the count covers it")


# Verbatim copy of the pre-FAN-3917 nearest_many body, kept as the operation
# baseline: every candidate becomes an allocated Dictionary, the full
# candidate list is sorted, and the sort comparator call count is measurable.
func _baseline_nearest_many(origin: Node2D, range_limit: float, count: int, excluded_ids: Dictionary, comparator_calls: Array) -> Array:
	var tree_nodes := TARGET_QUERY.enemies(origin)
	var candidates := []
	var range_squared := range_limit * range_limit
	for enemy_node in tree_nodes:
		if not is_instance_valid(enemy_node) or excluded_ids.has(enemy_node.get_instance_id()):
			continue
		var distance := origin.global_position.distance_squared_to(enemy_node.global_position)
		if distance > range_squared:
			continue
		candidates.append({"node": enemy_node, "distance": distance})
	var result := []
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		comparator_calls[0] += 1
		return float(a["distance"]) < float(b["distance"])
	)
	for candidate in candidates.slice(0, count):
		result.append(candidate["node"])
	return result


func _parity_and_operations(origin: Node2D, enemies: Array, errors: Array) -> void:
	var counts_to_check := [1, 2, 3, 5, 10, 25]
	var baseline_comparator_calls := 0
	for count in counts_to_check:
		var comparator_calls := [0]
		var baseline := _baseline_nearest_many(origin, QUERY_RANGE, count, {}, comparator_calls)
		baseline_comparator_calls = max(baseline_comparator_calls, comparator_calls[0])
		var shipped: Array = TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, count)
		if shipped.size() != baseline.size():
			errors.append("parity mismatch at count=%d: size %d vs baseline %d" % [count, shipped.size(), baseline.size()])
			continue
		for i in shipped.size():
			if shipped[i] != baseline[i]:
				errors.append("parity mismatch at count=%d index %d" % [count, i])
				break
	var candidates_in_range := 0
	for node in TARGET_QUERY.enemies(origin):
		if is_instance_valid(node) and origin.global_position.distance_squared_to(node.global_position) <= QUERY_RANGE * QUERY_RANGE:
			candidates_in_range += 1
	print("CombatTargetQuery top-k baseline: %d enemies, %d in range, full-sort comparator calls %d" % [
		enemies.size() + 2, candidates_in_range, baseline_comparator_calls
	])
	var query_script: Script = TARGET_QUERY
	var has_debug_counters := false
	for property in query_script.get_property_list():
		if str(property["name"]) == "debug_top_k_counters_enabled":
			has_debug_counters = true
			break
	if not has_debug_counters:
		print("CombatTargetQuery top-k: shipped implementation has no debug counters (baseline build); ops comparison skipped.")
		return
	query_script.set("debug_top_k_counters_enabled", true)
	query_script.set("debug_top_k_distance_comparisons", 0)
	var shipped: Array = TARGET_QUERY.nearest_many(origin, origin.global_position, QUERY_RANGE, 3)
	var shipped_comparisons: int = query_script.get("debug_top_k_distance_comparisons")
	query_script.set("debug_top_k_counters_enabled", false)
	var comparator_calls := [0]
	_baseline_nearest_many(origin, QUERY_RANGE, 3, {}, comparator_calls)
	print("CombatTargetQuery top-k candidate (count=3): %d distance comparisons vs baseline sort comparator calls %d" % [
		shipped_comparisons, comparator_calls[0]
	])
	if shipped_comparisons > comparator_calls[0]:
		errors.append("candidate top-k must not exceed the baseline comparator call count")
