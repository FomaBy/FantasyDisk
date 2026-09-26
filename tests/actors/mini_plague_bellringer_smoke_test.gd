extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_plague_bellringer.
# Домен владения: actor/mini_plague_bellringer (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_plague_bellringer")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_plague_bellringer", ["skill_bell_toll", "skill_poison_pool"])
	_assert_mini_scene_full_frame("mini_plague_bellringer", "res://scenes/ElitePoisoned.tscn", "mini_plague_bellringer:bell_toll:windup", "skill_bell_toll")
