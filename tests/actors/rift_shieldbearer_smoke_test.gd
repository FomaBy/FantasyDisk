extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра rift_shieldbearer.
# Домен владения: actor/rift_shieldbearer (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("rift_shieldbearer")


func _run_actor_checks() -> void:
	_assert_enemy_pack("rift_shieldbearer", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("rift_shieldbearer", "res://scenes/EnemyShield.tscn")
	_assert_static_sprite_path("res://scenes/EnemyShield.tscn", "Body", "res://assets/sprites/enemies/enemy_rift_shieldbearer.png")
	_test_enemy_archetype_pose("res://scenes/EnemyShield.tscn", "attack", "rift shieldbearer", "RigRoot/Pelvis/Figure/Torso/Shield")
