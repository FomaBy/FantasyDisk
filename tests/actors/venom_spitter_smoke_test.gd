extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра venom_spitter.
# Домен владения: actor/venom_spitter (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("venom_spitter")


func _run_actor_checks() -> void:
	_assert_enemy_pack("venom_spitter", {"idle": 1, "move": 6, "attack": 6, "hit": 4, "death": 6})
	_assert_enemy_scene_full_frame("venom_spitter", "res://scenes/EnemySpitter.tscn")
	_assert_static_sprite_path("res://scenes/EnemySpitter.tscn", "Body", "res://assets/sprites/enemies/enemy_venom_spitter.png")
	_test_enemy_archetype_pose("res://scenes/EnemySpitter.tscn", "shoot", "venom spitter", "")
