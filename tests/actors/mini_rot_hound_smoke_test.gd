extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_rot_hound.
# Домен владения: actor/mini_rot_hound (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_rot_hound")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_rot_hound", ["skill_shadow_strike"])
	_assert_mini_scene_full_frame("mini_rot_hound", "res://scenes/EliteStalker.tscn", "mini_rot_hound:shadow_strike:windup", "skill_shadow_strike")
