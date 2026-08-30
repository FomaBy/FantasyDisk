extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра void_mage.
# Домен владения: actor/void_mage (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("void_mage")


func _run_actor_checks() -> void:
	_assert_enemy_pack("void_mage", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("void_mage", "res://scenes/EnemyMage.tscn")
	_assert_static_sprite_path("res://scenes/EnemyMage.tscn", "Body", "res://assets/sprites/enemies/enemy_void_mage.png")
	_test_enemy_archetype_pose("res://scenes/EnemyMage.tscn", "cast", "void mage", "RigRoot/Pelvis/Figure/Torso/ArmR")
