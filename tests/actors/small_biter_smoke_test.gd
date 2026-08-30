extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра small_biter.
# Домен владения: actor/small_biter (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("small_biter")


func _run_actor_checks() -> void:
	_assert_enemy_pack("small_biter", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("small_biter", "res://scenes/EnemyBiter.tscn")
	_assert_static_sprite_path("res://scenes/EnemyBiter.tscn", "Body", "res://assets/sprites/enemies/enemy_small_biter.png")
	_test_enemy_archetype_pose("res://scenes/EnemyBiter.tscn", "attack", "small biter", "RigRoot/Pelvis/Figure/Torso/ArmR")
