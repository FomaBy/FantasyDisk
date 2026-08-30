extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра disk_devourer.
# Домен владения: actor/disk_devourer (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("disk_devourer")


func _run_actor_checks() -> void:
	_assert_boss_pack("disk_devourer", ["skill_vampiric_bite", "skill_rift_zone"], {"idle": 1, "move": 7, "attack": 7, "hit": 5, "death": 7, "skill_vampiric_bite": 7, "skill_rift_zone": 7})
	_assert_boss_scene_full_frame("disk_devourer", "res://scenes/BossDiskDevourer.tscn", "disk_devourer:vampiric_bite:windup", "skill_vampiric_bite", "_play_boss_skill_visual", ["skill_rift_zone", "cast", Vector2.RIGHT], "skill_rift_zone")
	_assert_static_sprite_path("res://scenes/BossDiskDevourer.tscn", "Sprite2D", "res://assets/sprites/bosses/boss_disk_devourer.png")
	_test_enemy_archetype_pose("res://scenes/BossDiskDevourer.tscn", "attack", "disk devourer", "")
