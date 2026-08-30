extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра mini_swarm_sniper.
# Домен владения: actor/mini_swarm_sniper (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("mini_swarm_sniper")


func _run_actor_checks() -> void:
	_assert_mini_pack("mini_swarm_sniper", ["skill_shard_fan", "skill_command_pulse"])
	_assert_mini_scene_full_frame("mini_swarm_sniper", "res://scenes/EliteCommander.tscn", "mini_swarm_sniper:shard_fan:windup", "skill_shard_fan")
