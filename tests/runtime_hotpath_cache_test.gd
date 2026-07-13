extends SceneTree

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const MASS_ENEMY_COUNT := 48


func _initialize() -> void:
	var errors: Array[String] = []
	var holder := Node2D.new()
	root.add_child(holder)

	var enemies: Array[Node] = []
	for index in range(MASS_ENEMY_COUNT):
		var enemy := ENEMY_SCENE.instantiate()
		holder.add_child(enemy)
		enemy.global_position = Vector2(
			float(index % 8) * 42.0,
			float(index / 8) * 42.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await process_frame

	var generation_before := TARGET_QUERY.cache_generation()
	for enemy in enemies:
		enemy.call("_refresh_separation_neighbors")
	var generation_after := TARGET_QUERY.cache_generation()
	if generation_after != generation_before + 1:
		errors.append(
			"48 separation refreshes must share one group snapshot (%d -> %d)" %
			[generation_before, generation_after])

	var populated := 0
	for enemy in enemies:
		var neighbors: Array = enemy.get("_separation_neighbors")
		if neighbors.size() > 4:
			errors.append("separation cache exceeded the four-neighbor bound")
			break
		if not neighbors.is_empty():
			populated += 1
	if populated < MASS_ENEMY_COUNT / 2:
		errors.append("mass scenario did not populate enough bounded separation caches")

	holder.queue_free()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error("Runtime hot-path cache: %s" % error)
		quit(1)
		return
	print("Runtime hot-path cache test passed (%d enemies, one shared snapshot)." % MASS_ENEMY_COUNT)
	quit(0)
