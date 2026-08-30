extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра druid_ghost_lion.
# Домен владения: actor/druid_ghost_lion (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("druid_ghost_lion")


func _run_actor_checks() -> void:
	_assert_druid_ghost_pack("druid_ghost_lion", true, false)
