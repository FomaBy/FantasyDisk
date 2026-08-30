extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_siege_rammer.
# Домен владения: actor/mini_siege_rammer (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_siege_rammer")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_siege_rammer", ["skill_shield_block", "skill_slam_wave"])
	_assert_mini_scene_full_frame("mini_siege_rammer", "res://scenes/EliteArmored.tscn", "mini_siege_rammer:slam_wave:windup", "skill_slam_wave")
