extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра stone_bruiser.
# Домен владения: actor/stone_bruiser (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("stone_bruiser")


func _run_actor_checks() -> void:
	_assert_enemy_pack("stone_bruiser", {"idle": 1, "move": 6, "attack": 6, "hit": 6, "death": 8})
	_assert_enemy_scene_full_frame("stone_bruiser", "res://scenes/EnemyBruiser.tscn")
	_assert_static_sprite_path("res://scenes/EnemyBruiser.tscn", "Body", "res://assets/sprites/enemies/enemy_bruiser_slow.png")
	_test_enemy_archetype_pose("res://scenes/EnemyBruiser.tscn", "attack", "stone bruiser", "RigRoot/Pelvis/Figure/Torso/ArmR")
