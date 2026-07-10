class_name CombatTargetQuery
extends RefCounted

static var _cached_frame := -1
static var _cached_tree_id := 0
static var _cached_enemies: Array[Node2D] = []
static var _cache_generation := 0


static func enemies(source: Node) -> Array[Node2D]:
	var tree := source.get_tree() if source != null and source.is_inside_tree() else null
	if tree == null:
		return []
	var frame_key := Engine.get_process_frames() + Engine.get_physics_frames() * 1000000
	var tree_id := tree.get_instance_id()
	if _cached_frame != frame_key or _cached_tree_id != tree_id:
		_cached_frame = frame_key
		_cached_tree_id = tree_id
		_cache_generation += 1
		_cached_enemies.clear()
		for enemy in tree.get_nodes_in_group("enemies"):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			_cached_enemies.append(enemy_node)
	return _cached_enemies


static func cache_generation() -> int:
	return _cache_generation


# SCRUM-920/922: единая таксономия «эпиков» для правил смещения (knockback).
# Боссы и ГЛАВНЫЕ элиты карты не смещаются (или капятся потребителем); мини-элиты
# волн (профиль epic_scale_profile == "mini_elite", спавн:
# combat_director._maybe_spawn_mini_elite) считаются обычными целями и отбрасываются
# полноценно. Порядок проверок важен: мини-элитки тоже состоят в группе
# elite_enemies — профиль-мета решает раньше группового признака.
static func is_epic_displacement_immune(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("bosses"):
		return true
	var profile := str(node.get_meta("epic_scale_profile", ""))
	if profile == "mini_elite":
		return false
	if profile == "boss" or profile == "elite":
		return true
	if node.is_in_group("elite_enemies"):
		return true
	var elite_behavior = node.get("elite_behavior")
	return elite_behavior != null and str(elite_behavior) != ""


static func nearest(source: Node, origin: Vector2, range_limit := INF, excluded_ids: Dictionary = {}) -> Node2D:
	var closest_enemy: Node2D = null
	var closest_distance := range_limit * range_limit
	for enemy_node in enemies(source):
		if not is_instance_valid(enemy_node) or excluded_ids.has(enemy_node.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy_node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node
	return closest_enemy


static func nearest_many(source: Node, origin: Vector2, range_limit: float, count: int, excluded_ids: Dictionary = {}) -> Array:
	var candidates := []
	var range_squared := range_limit * range_limit
	for enemy_node in enemies(source):
		if not is_instance_valid(enemy_node) or excluded_ids.has(enemy_node.get_instance_id()):
			continue
		var distance := origin.distance_squared_to(enemy_node.global_position)
		if distance > range_squared:
			continue
		candidates.append({"node": enemy_node, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var result := []
	for candidate in candidates.slice(0, count):
		result.append(candidate["node"])
	return result


static func in_radius(source: Node, origin: Vector2, radius: float) -> Array:
	var result := []
	var radius_squared := radius * radius
	for enemy_node in enemies(source):
		if not is_instance_valid(enemy_node):
			continue
		if origin.distance_squared_to(enemy_node.global_position) <= radius_squared:
			result.append(enemy_node)
	return result


static func has_in_radius(source: Node, origin: Vector2, radius: float) -> bool:
	var radius_squared := radius * radius
	for enemy_node in enemies(source):
		if not is_instance_valid(enemy_node):
			continue
		if origin.distance_squared_to(enemy_node.global_position) <= radius_squared:
			return true
	return false


static func in_corridor(source: Node, origin: Vector2, direction: Vector2, width: float, range_limit: float, back_allowance := 0.0) -> Array:
	var hits := []
	var normalized_direction := direction.normalized()
	if normalized_direction.length_squared() <= 0.001:
		normalized_direction = Vector2.RIGHT
	var perpendicular := Vector2(-normalized_direction.y, normalized_direction.x)
	for enemy_node in enemies(source):
		if not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - origin
		var forward := to_enemy.dot(normalized_direction)
		if forward < -back_allowance or forward > range_limit:
			continue
		var side: float = abs(to_enemy.dot(perpendicular))
		if side > width * 0.5:
			continue
		hits.append({"node": enemy_node, "forward": forward})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)
	return hits


static func in_segment(source: Node, start: Vector2, finish: Vector2, width: float, back_allowance := 0.0) -> Array:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.001:
		return in_radius(source, start, width * 0.5)
	var direction := segment / length
	var result := []
	for hit in in_corridor(source, start, direction, width, length, back_allowance):
		result.append(hit["node"])
	return result
