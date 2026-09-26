extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_scavenger_reaper.
# Домен владения: actor/mini_scavenger_reaper (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_scavenger_reaper")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_scavenger_reaper", ["skill_reaping_dash", "skill_bleed_finish"])
	_assert_mini_scene_full_frame("mini_scavenger_reaper", "res://scenes/EliteStalker.tscn", "mini_scavenger_reaper:reaping_dash:windup", "skill_reaping_dash")
