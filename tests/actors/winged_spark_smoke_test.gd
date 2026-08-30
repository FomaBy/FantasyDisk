extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра winged_spark.
# Домен владения: actor/winged_spark (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("winged_spark")


func _run_actor_checks() -> void:
	_assert_enemy_pack("winged_spark", {"idle": 6, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("winged_spark", "res://scenes/EnemyFlyingRunner.tscn")
	_assert_static_sprite_path("res://scenes/EnemyFlyingRunner.tscn", "Body", "res://assets/sprites/enemies/enemy_winged_spark.png")
	_test_enemy_archetype_pose("res://scenes/EnemyFlyingRunner.tscn", "attack", "winged spark", "RigRoot/Pelvis/Figure/Torso/WingL")
	_check_winged_spark_wing_rig()


func _check_winged_spark_wing_rig() -> void:
	var flying := (load("res://scenes/EnemyFlyingRunner.tscn") as PackedScene).instantiate()
	root.add_child(flying)
	flying.set("velocity", Vector2(100, 0))
	flying.call("_update_movement_animation", 0.2)
	var wing_l := flying.get_node_or_null("RigRoot/Pelvis/Figure/Torso/WingL") as Node2D
	var wing_r := flying.get_node_or_null("RigRoot/Pelvis/Figure/Torso/WingR") as Node2D
	if wing_l == null or wing_r == null:
		_fail("Expected flying enemy rig to use sliced wing parts.")
	if maxf(abs(wing_l.rotation), abs(wing_r.rotation)) <= 0.04:
		_fail("Expected flying enemy wings to flap.")
	flying.queue_free()
