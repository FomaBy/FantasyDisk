extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса robot.
# Домен владения: class/robot (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_robot_identity_modes()
	await _test_robot_weapon_mechanics()
	_finish("[balance/robot] PASSED")


func _check_robot_identity_modes() -> void:
	var robot_modes := {}
	for robot_weapon_id in ProgressionData.weapon_ids("robot"):
		var robot_mode := str(ProgressionData.weapon("robot", robot_weapon_id).get("attack_mode", ""))
		if robot_modes.has(robot_mode):
			_fail("Expected Robot weapons to use three distinct attack modes.")
			return
		robot_modes[robot_mode] = true
	for required_robot_mode in ["robot_magnetic_anchor", "robot_compression_line", "robot_reactor_vent"]:
		if not robot_modes.has(required_robot_mode):
			_fail("Expected Robot to include unique %s attack mode." % required_robot_mode)
			return


func _test_robot_weapon_mechanics() -> void:
	var robot_weapons := ProgressionData.weapon_ids("robot")
	if robot_weapons != ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"]:
		_fail("Expected Robot to expose exactly magnetic anchor/hydraulic press/reactor core weapons.")
		return
	var expected_modes := {
		"robot_magnetic_anchor": "robot_magnetic_anchor",
		"robot_hydraulic_press": "robot_compression_line",
		"robot_reactor_core": "robot_reactor_vent",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("robot", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Robot weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("robot").size() != 5:
		_fail("Expected Robot to have 5 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "RobotWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var robot := player_scene.instantiate()
		holder.add_child(robot)
		robot.global_position = Vector2(860, 720)
		await process_frame
		robot.call("configure_character", "robot", weapon_id)
		var weapon: Node = robot.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Robot %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = robot.global_position + Vector2(180, 0)
		var second_enemy := enemy_scene.instantiate()
		holder.add_child(second_enemy)
		second_enemy.set("max_health", 100000.0)
		second_enemy.set("health", 100000.0)
		second_enemy.global_position = robot.global_position + Vector2(210, 70)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_second_hp := float(second_enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.55).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Robot weapon %s to damage its primary target." % weapon_id)
			return
		if weapon_id in ["robot_magnetic_anchor", "robot_reactor_core"] and float(second_enemy.get("health")) >= before_second_hp:
			_fail("Expected Robot weapon %s to affect a nearby secondary target." % weapon_id)
			return
		robot.queue_free()
		enemy.queue_free()
		second_enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
