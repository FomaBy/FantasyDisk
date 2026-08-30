extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_bone_warden.
# Домен владения: actor/mini_bone_warden (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_bone_warden")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_bone_warden", ["skill_bone_guard", "skill_slam_wave"])
	_assert_mini_scene_full_frame("mini_bone_warden", "res://scenes/EliteArmored.tscn", "mini_bone_warden:slam_wave:windup", "skill_slam_wave")
