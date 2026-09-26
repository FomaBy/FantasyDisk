extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра shard_marshal.
# Домен владения: actor/shard_marshal (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("shard_marshal")


func _run_actor_checks() -> void:
	_assert_elite_pack("shard_marshal", ["skill_shard_fan", "skill_command_pulse"], {"idle": 1, "move": 8, "attack": 7, "hit": 5, "death": 7, "skill_shard_fan": 7, "skill_command_pulse": 7}, [], true)
	_assert_elite_scene_full_frame("shard_marshal", "res://scenes/EliteCommander.tscn", "shard_marshal:shard_fan:windup", "skill_shard_fan")
	_assert_static_sprite_path("res://scenes/EliteCommander.tscn", "Body", "res://assets/sprites/elites/shard_marshal.png")
	_assert_elite_attack_phase("shard_marshal", "res://scenes/EliteCommander.tscn", "shard_fan")


func _check_elite_windup_pose(rig: Node2D) -> void:
	var windup_arm_l := rig.get_node_or_null("Pelvis/Figure/Torso/ArmL") as Node2D
	var windup_arm_r := rig.get_node_or_null("Pelvis/Figure/Torso/ArmR") as Node2D
	if windup_arm_l == null or windup_arm_r == null or abs(windup_arm_l.position.x - windup_arm_r.position.x) <= 6.0:
		_fail("Expected Shard Marshal windup to spread both arms.")


func _check_elite_strike_pose(rig: Node2D) -> void:
	var strike_pelvis := rig.get_node("Pelvis") as Node2D
	if strike_pelvis.position.x <= 1.0:
		_fail("Expected shard_marshal strike to lunge/gesture forward.")
