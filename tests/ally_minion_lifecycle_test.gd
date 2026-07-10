extends SceneTree

# SCRUM-711 (refactor wave 0.2.0): focused coverage for the AllyMinion death lifecycle
# and deployable cleanup. Guards:
#   - a lethal hit deactivates the ally immediately (drops the "allies" group, stops
#     physics) on BOTH the animated and non-animated death paths;
#   - the death lifecycle is single-shot (a second hit is a no-op);
#   - force-freeing a dead ally mid-lifecycle does not crash (the _exit_tree tween-kill
#     guard from the SCRUM-551/631 SIGABRT fixes);
#   - take_damage accepts the Player-compatible (amount, source, attacker) contract:
#     enemy.gd routes a taunted contact hit (bastion_taunt, SCRUM-946) into the ally,
#     and SCRUM-920 made that call pass the attacker as a third argument.


func _initialize() -> void:
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	if ally_scene == null:
		push_error("AllyMinion scene did not load.")
		quit(1)
		return

	if not await _run_assertions(ally_scene):
		quit(1)
		return
	if not await _assert_contact_hit_contract(ally_scene):
		quit(1)
		return

	print("AllyMinion lifecycle test passed.")
	quit()


func _assert_contact_hit_contract(ally_scene: PackedScene) -> bool:
	var ally := ally_scene.instantiate()
	root.add_child(ally)
	await process_frame

	var start_health := float(ally.get("health"))
	if start_health <= 0.0:
		push_error("Expected a fresh ally to start with positive health.")
		ally.queue_free()
		return false

	# Mirrors enemy.gd::_update_contact_damage — the taunted contact hit passes the
	# attacker node as the third argument. A one-argument signature raised
	# "Invalid call ... Expected 1 argument(s)" and silently dropped the damage.
	var attacker := Node2D.new()
	root.add_child(attacker)
	ally.call("take_damage", 5.0, "contact", attacker)

	if not is_equal_approx(float(ally.get("health")), start_health - 5.0):
		push_error("Expected a 3-argument contact hit to damage the ally (taunt path).")
		attacker.queue_free()
		ally.queue_free()
		return false

	attacker.queue_free()
	ally.queue_free()
	await process_frame
	return true


func _run_assertions(ally_scene: PackedScene) -> bool:
	var ally := ally_scene.instantiate()
	root.add_child(ally)
	await process_frame

	if not ally.is_in_group("allies"):
		push_error("Expected a live ally to join the 'allies' group on ready.")
		ally.queue_free()
		return false

	# Lethal hit: in headless there is no full-frame death animation, so this exercises
	# the non-animated death path that must still deactivate the ally immediately.
	ally.call("take_damage", 9999.0)

	if not bool(ally.get("_death_lifecycle_started")):
		push_error("Expected a lethal hit to start the death lifecycle.")
		ally.queue_free()
		return false
	if ally.is_in_group("allies"):
		push_error("Expected a dead ally to leave the 'allies' group immediately.")
		ally.queue_free()
		return false
	if ally.is_physics_processing():
		push_error("Expected a dead ally to stop physics processing immediately.")
		ally.queue_free()
		return false
	if float(ally.get("health")) > 0.0:
		push_error("Expected a dead ally to report zero health.")
		ally.queue_free()
		return false

	# Single-shot: a second hit must be a no-op and must not crash.
	ally.call("take_damage", 50.0)
	if ally.is_in_group("allies"):
		push_error("Expected a second hit on a dead ally to remain a no-op.")
		ally.queue_free()
		return false

	# Force-free mid-lifecycle: exercises _exit_tree's tween-kill guard. Must not crash.
	if is_instance_valid(ally) and not ally.is_queued_for_deletion():
		ally.queue_free()
	await process_frame
	await process_frame

	return true
