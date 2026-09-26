extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра bone_caller.
# Домен владения: actor/bone_caller (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("bone_caller")


func _run_actor_checks() -> void:
	_assert_enemy_pack("bone_caller", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("bone_caller", "res://scenes/EnemySummoner.tscn")
	_assert_static_sprite_path("res://scenes/EnemySummoner.tscn", "Body", "res://assets/sprites/enemies/enemy_summoner.png")
	_test_enemy_archetype_pose("res://scenes/EnemySummoner.tscn", "cast", "bone caller", "RigRoot/Pelvis/Figure/Torso/ArmR")
