extends SceneTree

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")


func _initialize() -> void:
	var errors := []
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var origin := Node2D.new()
	origin.name = "QueryOrigin"
	holder.add_child(origin)
	origin.global_position = Vector2.ZERO

	var near := _enemy("NearEnemy", Vector2(80.0, 0.0))
	var far := _enemy("FarEnemy", Vector2(220.0, 0.0))
	var side := _enemy("SideEnemy", Vector2(90.0, 90.0))
	holder.add_child(near)
	holder.add_child(far)
	holder.add_child(side)
	await process_frame

	var generation_before := TARGET_QUERY.cache_generation()
	var nearest := TARGET_QUERY.nearest(origin, origin.global_position, 500.0)
	var generation_after_first := TARGET_QUERY.cache_generation()
	var in_radius := TARGET_QUERY.in_radius(origin, origin.global_position, 120.0)
	var corridor := TARGET_QUERY.in_corridor(origin, origin.global_position, Vector2.RIGHT, 60.0, 240.0)
	var segment := TARGET_QUERY.in_segment(origin, Vector2.ZERO, Vector2(240.0, 0.0), 60.0)
	var generation_after_queries := TARGET_QUERY.cache_generation()

	if nearest != near:
		errors.append("nearest did not select NearEnemy")
	if not in_radius.has(near) or in_radius.has(far) or in_radius.has(side):
		errors.append("in_radius returned unexpected targets")
	if corridor.size() != 2 or corridor[0]["node"] != near or corridor[1]["node"] != far:
		errors.append("corridor should return near/far sorted by forward distance")
	if not segment.has(near) or not segment.has(far) or segment.has(side):
		errors.append("segment should include only enemies near the segment line")
	if generation_after_first <= generation_before:
		errors.append("cache generation did not build on first query")
	if generation_after_queries != generation_after_first:
		errors.append("cache rebuilt more than once in the same frame")

	var contact := _enemy("ContactEnemy", Vector2.ZERO)
	holder.add_child(contact)
	await process_frame
	var offset_start := Vector2(30.0, 0.0)
	var contact_corridor := TARGET_QUERY.in_corridor(origin, offset_start, Vector2.RIGHT, 60.0, 240.0, 40.0)
	var contact_segment := TARGET_QUERY.in_segment(origin, offset_start, Vector2(240.0, 0.0), 60.0, 40.0)
	if contact_corridor.is_empty() or contact_corridor[0]["node"] != contact:
		errors.append("corridor back_allowance should include a contact-stuck enemy behind the beam start")
	if not contact_segment.has(contact):
		errors.append("segment back_allowance should include a contact-stuck enemy behind the segment start")

	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for error in errors:
			push_error("CombatTargetQuery: %s" % error)
		quit(1)
		return
	print("CombatTargetQuery cache test passed.")
	quit(0)


func _enemy(node_name: String, position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.name = node_name
	enemy.global_position = position
	enemy.add_to_group("enemies")
	return enemy
