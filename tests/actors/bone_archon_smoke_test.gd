extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра bone_archon.
# Домен владения: actor/bone_archon (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("bone_archon")


func _run_actor_checks() -> void:
	_assert_boss_pack("bone_archon", ["skill_skull_volley", "skill_bone_prison"], {})
	_assert_boss_scene_full_frame("bone_archon", "res://scenes/BossBoneArchon.tscn", "bone_archon:skull_volley:windup", "skill_skull_volley", "_play_boss_skill_visual", ["skill_bone_prison", "cast", Vector2.RIGHT], "skill_bone_prison")
	_assert_static_sprite_path("res://scenes/BossBoneArchon.tscn", "Sprite2D", "res://assets/sprites/bosses/boss_bone_archon.png")
