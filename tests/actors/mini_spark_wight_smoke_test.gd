extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_spark_wight.
# Домен владения: actor/mini_spark_wight (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_spark_wight")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_spark_wight", ["skill_spark_fan", "skill_static_field"])
	_assert_mini_scene_full_frame("mini_spark_wight", "res://scenes/EliteCommander.tscn", "mini_spark_wight:spark_fan:windup", "skill_spark_fan")
