extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_shadow_devourer.
# Домен владения: actor/mini_shadow_devourer (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_shadow_devourer")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_shadow_devourer", ["skill_shadow_blink", "skill_devour_bite"])
	_assert_mini_scene_full_frame("mini_shadow_devourer", "res://scenes/EliteStalker.tscn", "mini_shadow_devourer:shadow_blink:windup", "skill_shadow_blink")
