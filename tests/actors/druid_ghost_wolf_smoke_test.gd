extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра druid_ghost_wolf.
# Домен владения: actor/druid_ghost_wolf (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("druid_ghost_wolf")


func _run_actor_checks() -> void:
	_assert_druid_ghost_pack("druid_ghost_wolf", false, false)
