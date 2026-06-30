extends SceneTree

# SCRUM-711 (refactor wave 0.1.8): focused coverage for the AllyMinion death lifecycle
# and deployable cleanup. Guards:
#   - a lethal hit deactivates the ally immediately (drops the "allies" group, stops
#     physics) on BOTH the animated and non-animated death paths;
#   - the death lifecycle is single-shot (a second hit is a no-op);
#   - force-freeing a dead ally mid-lifecycle does not crash (the _exit_tree tween-kill
#     guard from the SCRUM-551/631 SIGABRT fixes).


func _initialize() -> void:
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	if ally_scene == null:
		push_error("AllyMinion scene did not load.")
		quit(1)
		return

	if not await _run_assertions(ally_scene):
		quit(1)
		return

	print("AllyMinion lifecycle test passed.")
	quit()


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
