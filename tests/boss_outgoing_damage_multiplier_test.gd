extends SceneTree

const BossScene := preload("res://scenes/BossWarden.tscn")
const StatusEffects := preload("res://scripts/status_effects.gd")


func _initialize() -> void:
	var errors: Array = []
	var boss := BossScene.instantiate()
	root.add_child(boss)
	await process_frame

	StatusEffects.apply_status(boss, "test_suppressed", {
		"duration": 1.0,
		"damage_multiplier": 0.5,
	})
	var outgoing := float(boss.call("_outgoing_damage", 100.0))
	if not is_equal_approx(outgoing, 50.0):
		errors.append("boss _outgoing_damage must respect StatusEffects.damage_multiplier (got %.2f)" % outgoing)

	var source := FileAccess.get_file_as_string("res://scripts/boss.gd")
	for forbidden in [
		"take_damage(projectile_damage *",
		"take_damage(contact_damage *",
		"player.take_damage(zone_damage",
		"player.take_damage(slam_damage",
		"player.take_damage(web_damage",
		"player.take_damage(ember_damage",
		"projectile.setup(global_position, target_position, projectile_damage",
		"projectile.setup(global_position, global_position + shot_direction * 160.0, projectile_damage",
	]:
		if source.contains(forbidden):
			errors.append("boss.gd still has raw outgoing damage pattern: %s" % forbidden)

	boss.queue_free()
	await process_frame

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("boss_outgoing_damage_multiplier_test passed.")
	quit(0)
