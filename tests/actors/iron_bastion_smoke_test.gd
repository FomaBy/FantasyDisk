extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра iron_bastion.
# Домен владения: actor/iron_bastion (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("iron_bastion")


func _run_actor_checks() -> void:
	_assert_elite_pack("iron_bastion", ["skill_shield_block", "skill_slam_wave"], {"idle": 1, "move": 8, "attack": 7, "hit": 6, "death": 7, "skill_shield_block": 7, "skill_slam_wave": 7}, [], false)
	_assert_elite_scene_full_frame("iron_bastion", "res://scenes/EliteArmored.tscn", "iron_bastion:slam_wave:windup", "skill_slam_wave")
	_assert_static_sprite_path("res://scenes/EliteArmored.tscn", "Body", "res://assets/sprites/elites/iron_bastion.png")
	_assert_elite_attack_phase("iron_bastion", "res://scenes/EliteArmored.tscn", "slam_wave")
	_check_iron_bastion_rig_parts()


func _check_iron_bastion_rig_parts() -> void:
	var elite := (load("res://scenes/EliteArmored.tscn") as PackedScene).instantiate()
	root.add_child(elite)
	elite.call("_update_movement_animation", 0.2)
	if elite.get_node_or_null("RigRoot/Pelvis/Figure/Torso/Shield") == null:
		_fail("Expected Iron Bastion rig to carry its shield as a separate part.")
	if elite.get_node_or_null("RigRoot/Pelvis/Figure/Torso/WeaponSocketMount") == null:
		_fail("Expected elite enemy to use the shared rig architecture.")
	elite.queue_free()


func _check_elite_windup_pose(rig: Node2D) -> void:
	var windup_pelvis := rig.get_node("Pelvis") as Node2D
	var windup_arm_r := rig.get_node_or_null("Pelvis/Figure/Torso/ArmR") as Node2D
	if windup_pelvis.position.y >= -1.0 or windup_arm_r == null or windup_arm_r.position.y >= -2.0:
		_fail("Expected Iron Bastion windup to lift into a slam pose.")


func _check_elite_strike_pose(rig: Node2D) -> void:
	var strike_pelvis := rig.get_node("Pelvis") as Node2D
	if strike_pelvis.position.y <= 2.0:
		_fail("Expected Iron Bastion strike to drop into the slam.")
