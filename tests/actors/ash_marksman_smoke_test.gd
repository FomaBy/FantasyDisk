extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра ash_marksman.
# Домен владения: actor/ash_marksman (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("ash_marksman")


func _run_actor_checks() -> void:
	_assert_enemy_pack("ash_marksman", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("ash_marksman", "res://scenes/EnemyShooter.tscn")
	_assert_static_sprite_path("res://scenes/EnemyShooter.tscn", "Body", "res://assets/sprites/enemies/enemy_ranged.png")
	_check_ash_marksman_cutout_rig()


func _check_ash_marksman_cutout_rig() -> void:
	var shooter := (load("res://scenes/EnemyShooter.tscn") as PackedScene).instantiate()
	root.add_child(shooter)
	shooter.call("_update_movement_animation", 0.1)
	var weapon := shooter.get_node_or_null("RigRoot/Pelvis/Figure/Torso/Weapon") as Node2D
	if weapon == null:
		_fail("Expected marksman rig to carry the crossbow as a separate part.")
	shooter.call("_play_rig_action", "shoot", Vector2.RIGHT)
	shooter.call("_update_movement_animation", 0.13)
	var shooter_pelvis := shooter.get_node("RigRoot/Pelvis") as Node2D
	if shooter_pelvis.position.x >= -0.01:
		_fail("Expected shoot action to recoil the marksman.")
	shooter.queue_free()
