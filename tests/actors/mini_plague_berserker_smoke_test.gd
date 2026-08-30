extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_plague_berserker.
# Домен владения: actor/mini_plague_berserker (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_plague_berserker")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_plague_berserker", ["skill_poison_volley"])
	_assert_mini_scene_full_frame("mini_plague_berserker", "res://scenes/ElitePoisoned.tscn", "mini_plague_berserker:poison_volley:windup", "skill_poison_volley")
