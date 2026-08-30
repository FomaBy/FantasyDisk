extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_void_phantom.
# Домен владения: actor/mini_void_phantom (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_void_phantom")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_void_phantom", ["skill_shadow_strike", "skill_phase_dash"])
	_assert_mini_scene_full_frame("mini_void_phantom", "res://scenes/EliteStalker.tscn", "mini_void_phantom:shadow_strike:windup", "skill_shadow_strike")
