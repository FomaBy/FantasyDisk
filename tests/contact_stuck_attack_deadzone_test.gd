extends SceneTree

const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")


class DummyEnemy:
	extends Node2D

	var max_health := 100.0
	var health := 100.0

	func take_damage(amount: float) -> void:
		health = maxf(health - amount, 0.0)


func _initialize() -> void:
	var errors := []
	await _test_berserk_contact_strip(errors)
	await _test_class_contact_mode("aoe_projectile", errors, {"projectile_speed": 9999.0}, 20)
	await _test_class_contact_mode("boomerang", errors)
	await _test_class_contact_mode("stab_flurry", errors, {"projectile_count": 1})
	await _test_class_contact_mode("beam", errors)
	await _test_class_contact_mode("dot_beam", errors, {"dot_ticks": 1})
	await _test_class_contact_mode("drain_link", errors)
	await _test_class_contact_mode("sound_wave", errors)
	await _test_class_contact_mode("bayonet_cone", errors, {"cone_degrees": 105.0}, 12)
	await _test_class_contact_mode("sniper_lockshot", errors, {"grenade_delay": 0.01}, 20)
	await _test_class_contact_mode("robot_compression_line", errors, {"grenade_delay": 0.01}, 20)
	await _test_class_contact_mode("robot_reactor_vent", errors, {"projectile_count": 4})
	await _test_class_contact_mode("arquebus_shot", errors, {"projectile_speed": 9999.0}, 20)

	if not errors.is_empty():
		for error in errors:
			push_error("Contact stuck attack deadzone: %s" % error)
		quit(1)
		return
	print("Contact stuck attack deadzone test passed.")
	quit(0)


func _test_berserk_contact_strip(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var owner := CharacterBody2D.new()
	holder.add_child(owner)
	owner.global_position = Vector2(320.0, 320.0)
	var weapon := BerserkWeaponScript.new()
	weapon.attack_shape = "strip"
	weapon.attack_range = 240.0
	weapon.start_distance = 24.0
	weapon.inner_width = 48.0
	weapon.damage = 12.0
	weapon.set_process(false)
	owner.add_child(weapon)
	var contact_enemy := _enemy(holder, owner.global_position)
	await process_frame
	if not bool(weapon.call("_is_enemy_inside_attack", owner, contact_enemy, Vector2.RIGHT)):
		errors.append("Berserk strip geometry rejected an enemy standing on the player.")
	weapon.call("_attack")
	await process_frame
	if contact_enemy.health >= contact_enemy.max_health:
		errors.append("Berserk strip attack did not damage an enemy standing on the player.")
	var behind_probe := _enemy(holder, owner.global_position - Vector2.RIGHT * 45.0)
	if bool(weapon.call("_is_enemy_inside_attack", owner, behind_probe, Vector2.RIGHT)):
		errors.append("Berserk strip contact rescue reached beyond the intended close-contact radius.")
	holder.queue_free()
	await process_frame


func _test_class_contact_mode(mode: String, errors: Array, overrides := {}, wait_frames := 8) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var owner := CharacterBody2D.new()
	holder.add_child(owner)
	owner.global_position = Vector2(640.0, 360.0)
	var weapon := ClassWeaponScript.new()
	weapon.weapon_id = "contact_%s" % mode
	weapon.attack_mode = mode
	weapon.damage = 12.0
	weapon.attack_range = 260.0
	weapon.aoe_radius = 96.0
	weapon.beam_width = 54.0
	weapon.wave_width = 150.0
	weapon.fire_interval = 0.2
	weapon.visual_color = Color(0.5, 0.8, 1.0, 0.25)
	for key in overrides.keys():
		weapon.set(str(key), overrides[key])
	weapon.set_process(false)
	owner.add_child(weapon)
	var contact_enemy := _enemy(holder, owner.global_position)
	await process_frame
	weapon.call("_attack")
	for _frame in range(wait_frames):
		await process_frame
	if contact_enemy.health >= contact_enemy.max_health:
		errors.append("%s did not damage an enemy standing on the player." % mode)
	if weapon.has_method("cleanup_effects"):
		weapon.cleanup_effects()
	holder.queue_free()
	await process_frame


func _enemy(holder: Node, position: Vector2) -> DummyEnemy:
	var enemy := DummyEnemy.new()
	enemy.global_position = position
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	return enemy
