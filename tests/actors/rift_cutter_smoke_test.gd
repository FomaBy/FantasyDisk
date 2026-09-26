extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра rift_cutter.
# Домен владения: actor/rift_cutter (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("rift_cutter")


func _run_actor_checks() -> void:
	_assert_enemy_pack("rift_cutter", {"idle": 4, "move": 6, "attack": 6, "hit": 6, "death": 6})
	_assert_enemy_scene_full_frame("rift_cutter", "res://scenes/Enemy.tscn")
	_assert_static_sprite_path("res://scenes/Enemy.tscn", "Body", "res://assets/sprites/enemies/enemy_melee.png")
	_check_rift_cutter_eight_direction_contract()
	_check_rift_cutter_cutout_rig()


func _check_rift_cutter_eight_direction_contract() -> void:
	var frames := FullFrameAnimationRegistry.sprite_frames_for("enemy", "rift_cutter")
	if frames == null:
		return
	# FAN-2609: explicit 8-direction runtime contract — every state must
	# expose all eight `<state>_<suffix>` rows, never a mirrored fallback.
	for state_name in ["idle", "move", "attack_primary", "hit", "death"]:
		if not FullFrameAnimationRegistry.has_full_directional_rows(frames, state_name):
			_fail("Expected rift_cutter %s to expose all eight directional rows." % state_name)
	for suffix in FullFrameAnimationRegistry.DIRECTION_SUFFIXES:
		if frames.get_frame_count("idle_%s" % suffix) != 4:
			_fail("Expected rift_cutter idle_%s to have 4 frames." % suffix)
		for state_name in ["move", "attack_primary", "hit", "death"]:
			if frames.get_frame_count("%s_%s" % [state_name, suffix]) != 6:
				_fail("Expected rift_cutter %s_%s to have 6 frames." % [state_name, suffix])


func _check_rift_cutter_cutout_rig() -> void:
	var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
	root.add_child(enemy)
	enemy.set("velocity", Vector2(100, 0))
	enemy.call("_update_movement_animation", 0.2)
	var body := enemy.get_node("Body") as Sprite2D
	if body.visible:
		_fail("Expected enemy source Body to be hidden behind RigRoot.")
	_assert_sliced_rig(enemy, "RigRoot", "enemies/cutout", ["Torso", "ArmL", "ArmR"], ["LegL", "LegR"], "rift cutter")

	var rig := enemy.get_node("RigRoot") as Node2D
	var pelvis := rig.get_node("Pelvis") as Node2D
	var leg_l := rig.get_node("Pelvis/Figure/LegL") as Node2D
	var leg_r := rig.get_node("Pelvis/Figure/LegR") as Node2D
	if abs(pelvis.position.y) <= 0.01 and abs(pelvis.rotation) <= 0.01:
		_fail("Expected enemy movement animation to affect rig pelvis transform.")
	if abs(leg_l.rotation - leg_r.rotation) <= 0.05:
		_fail("Expected enemy walk to animate opposing legs.")
	if abs(leg_l.position.y - leg_r.position.y) <= 0.02:
		_fail("Expected enemy walk to lift feet on alternating phases.")
	if pelvis.scale.x >= 0.0:
		_fail("Expected left-facing enemy art to mirror when moving right (negative pelvis scale.x).")
	enemy.set("velocity", Vector2(-100, 0))
	enemy.call("_update_movement_animation", 0.2)
	if pelvis.scale.x <= 0.0:
		_fail("Expected left-facing enemy art to stay unmirrored when moving left.")
	enemy.set("velocity", Vector2(100, 0))
	enemy.call("_update_movement_animation", 0.2)

	enemy.call("_play_rig_action", "attack", Vector2.RIGHT)
	enemy.call("_update_movement_animation", 0.15)
	var arm_r := rig.get_node("Pelvis/Figure/Torso/ArmR") as Node2D
	if abs(arm_r.rotation) <= 0.08:
		_fail("Expected enemy attack to swing the claw arm.")
	enemy.queue_free()
