extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра spark_runner.
# Домен владения: actor/spark_runner (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("spark_runner")


func _run_actor_checks() -> void:
	_assert_enemy_pack("spark_runner", {"idle": 1, "move": 6, "attack": 7, "hit": 5, "death": 7})
	_assert_enemy_scene_full_frame("spark_runner", "res://scenes/EnemyRunner.tscn")
	_assert_static_sprite_path("res://scenes/EnemyRunner.tscn", "Body", "res://assets/sprites/enemies/enemy_suicide_runner.png")
	_test_enemy_archetype_pose("res://scenes/EnemyRunner.tscn", "attack", "spark runner", "RigRoot/Pelvis/Figure/Torso/Tail")
