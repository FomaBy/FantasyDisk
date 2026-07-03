extends SceneTree

# SCRUM-854: persistent ground hazards must stay on the ground for their
# configured lifetime instead of replacing the previous attack instance.

const ClassWeaponScript := preload("res://scripts/class_weapon.gd")


class TestOwner:
	extends Node2D

	var derived_parameters := {
		"damage": 10.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
	}


class TestEnemy:
	extends Node2D

	var damage_taken := 0.0

	func take_damage(amount: float) -> void:
		damage_taken += maxf(amount, 0.0)


func _initialize() -> void:
	var errors: Array = []
	await process_frame
	await _test_multiple_damage_pools_can_overlap(errors)
	await _test_engineer_mine_ticks_until_duration(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Persistent hazard contract: %s" % error)
		push_error("Persistent hazard contract test failed: %d errors." % errors.size())
		quit(1)
		return
	print("Persistent hazard contract test passed.")
	quit(0)


func _test_multiple_damage_pools_can_overlap(errors: Array) -> void:
	var weapon := ClassWeaponScript.new()
	root.add_child(weapon)
	weapon.aoe_radius = 80.0
	weapon.pool_duration = 1.0
	weapon.pool_tick_interval = 0.2

	for index in range(3):
		weapon.call("_spawn_damage_pool", Vector2(120.0 + index * 48.0, 140.0), 4.0)
	await process_frame

	var active_pools := []
	for pool in get_nodes_in_group("chemist_clouds"):
		var pool_node := pool as Node2D
		if pool_node != null and int(pool_node.get_meta("pool_weapon_owner", 0)) == weapon.get_instance_id():
			active_pools.append(pool_node)
	if active_pools.size() != 3:
		errors.append("Expected 3 overlapping damage pools, got %d." % active_pools.size())
	for pool in active_pools:
		if absf(float(pool.get_meta("pool_duration", 0.0)) - 1.0) > 0.01:
			errors.append("Expected pool_duration metadata to mirror scaled duration.")
		if absf(float(pool.get_meta("pool_tick_interval", 0.0)) - 0.2) > 0.01:
			errors.append("Expected pool_tick_interval metadata to mirror scaled tick interval.")

	for pool in active_pools:
		if is_instance_valid(pool):
			pool.queue_free()
	weapon.queue_free()
	await process_frame


func _test_engineer_mine_ticks_until_duration(errors: Array) -> void:
	var weapon := ClassWeaponScript.new()
	var owner := TestOwner.new()
	var enemy := TestEnemy.new()
	root.add_child(weapon)
	root.add_child(owner)
	root.add_child(enemy)
	owner.global_position = Vector2(200, 200)
	enemy.global_position = Vector2(232, 200)
	enemy.add_to_group("enemies")

	weapon.damage = 8.0
	weapon.damage_parameter = "damage"
	weapon.aoe_radius = 64.0
	weapon.damage_falloff = 1.0
	weapon.pool_duration = 0.36
	weapon.pool_tick_interval = 0.10
	weapon.visual_color = Color(0.4, 0.7, 1.0, 0.4)
	weapon.call("_spawn_engineer_pressure_mine", owner, Vector2(220, 200), 0)
	await process_frame

	var mine := _first_named_node("EngineerPressureMine") as Node2D
	if mine == null:
		errors.append("Expected engineer pressure mine to spawn.")
	else:
		if not bool(mine.get_meta("persistent_hazard", false)):
			errors.append("Expected engineer mine to be tagged as a persistent hazard.")
		if absf(float(mine.get_meta("pool_duration", 0.0)) - 0.36) > 0.01:
			errors.append("Expected engineer mine duration metadata.")

	await create_timer(0.26).timeout
	if enemy.damage_taken <= 8.01:
		errors.append("Expected engineer mine to tick repeatedly before expiring, damage %.2f." % enemy.damage_taken)
	if mine == null or not is_instance_valid(mine):
		errors.append("Expected engineer mine to remain valid before configured duration expires.")
	elif mine.is_queued_for_deletion():
		errors.append("Expected engineer mine not to queue_free before configured duration expires.")

	await create_timer(0.16).timeout
	if mine != null and is_instance_valid(mine) and not mine.is_queued_for_deletion():
		errors.append("Expected engineer mine to clean up after configured duration expires.")

	weapon.queue_free()
	owner.queue_free()
	enemy.queue_free()
	if mine != null and is_instance_valid(mine):
		mine.queue_free()
	await process_frame


func _first_named_node(node_name: String) -> Node:
	for child in root.get_children():
		if child.name == node_name:
			return child
	return null
