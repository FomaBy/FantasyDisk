extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра rift_warden.
# Домен владения: actor/rift_warden (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("rift_warden")


func _run_actor_checks() -> void:
	_assert_boss_pack("rift_warden", ["skill_gravity_well", "skill_rift_zone"], {"idle": 1, "move": 7, "attack": 6, "hit": 6, "death": 6, "skill_gravity_well": 6, "skill_rift_zone": 6})
	_assert_boss_scene_full_frame("rift_warden", "res://scenes/BossWarden.tscn", "rift_warden:gravity_well:windup", "skill_gravity_well", "_play_boss_skill_visual", ["skill_gravity_well", "cast", Vector2.RIGHT], "skill_gravity_well")
	_assert_static_sprite_path("res://scenes/BossWarden.tscn", "Sprite2D", "res://assets/sprites/bosses/boss_rift_warden.png")
	_check_rift_warden_rig()


func _check_rift_warden_rig() -> void:
	var boss := (load("res://scenes/BossWarden.tscn") as PackedScene).instantiate()
	root.add_child(boss)
	boss.call("_update_movement_animation", 0.2)
	if boss.get_node_or_null("RigRoot/Pelvis/Figure/Torso/Vortex") == null:
		_fail("Expected Rift Warden rig to animate its vortex as a separate part.")
	boss.call("_play_rig_action", "cast", Vector2.UP)
	boss.call("_update_movement_animation", 0.2)
	var boss_arm_l := boss.get_node("RigRoot/Pelvis/Figure/Torso/ArmL") as Node2D
	var boss_arm_r := boss.get_node("RigRoot/Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(boss_arm_l.rotation - boss_arm_r.rotation) <= 0.2:
		_fail("Expected boss cast to raise both fists.")
	boss.queue_free()
