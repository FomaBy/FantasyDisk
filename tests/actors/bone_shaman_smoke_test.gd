extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра bone_shaman.
# Домен владения: actor/bone_shaman (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("bone_shaman")


func _run_actor_checks() -> void:
	_assert_enemy_pack("bone_shaman", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("bone_shaman", "res://scenes/EnemyBoneShaman.tscn")
	_assert_static_sprite_path("res://scenes/EnemyBoneShaman.tscn", "Body", "res://assets/sprites/enemies/enemy_bone_shaman.png")
	_test_enemy_archetype_pose("res://scenes/EnemyBoneShaman.tscn", "cast", "bone shaman", "RigRoot/Pelvis/Figure/Torso/ArmR")
