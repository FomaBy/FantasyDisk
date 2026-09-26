extends "res://tests/animation_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): анимационный smoke актёра plague_prophet.
# Домен владения: actor/plague_prophet (docs/process/ownership_map.md).


func _initialize() -> void:
	_run_actor_suite("plague_prophet")


func _run_actor_checks() -> void:
	_assert_elite_pack("plague_prophet", ["skill_poison_volley"], {"idle": 1, "move": 8, "skill_poison_volley": 10, "hit": 5, "death": 7}, [], true)
	_assert_elite_scene_full_frame("plague_prophet", "res://scenes/ElitePoisoned.tscn", "plague_prophet:poison_volley:windup", "skill_poison_volley")
	_assert_static_sprite_path("res://scenes/ElitePoisoned.tscn", "Body", "res://assets/sprites/elites/plague_prophet.png")
	_assert_elite_attack_phase("plague_prophet", "res://scenes/ElitePoisoned.tscn", "poison_volley")
	_check_plague_prophet_stale_rows()


func _check_plague_prophet_stale_rows() -> void:
	if not bool(FullFrameAnimationRegistry.registry_config("elite", "plague_prophet").get("explicit_eight_directions", false)):
		return
	var frames := FullFrameAnimationRegistry.sprite_frames_for("elite", "plague_prophet")
	if frames == null:
		return
	for stale_row in ["skill_plague_aura_east", "attack_poison_volley_east"]:
		if frames.has_animation(stale_row):
			_fail("Expected plague_prophet not to expose stale %s." % stale_row)


func _check_elite_windup_pose(rig: Node2D) -> void:
	var windup_arm_l := rig.get_node_or_null("Pelvis/Figure/Torso/ArmL") as Node2D
	var windup_arm_r := rig.get_node_or_null("Pelvis/Figure/Torso/ArmR") as Node2D
	if windup_arm_l == null or windup_arm_r == null or abs(windup_arm_l.rotation - windup_arm_r.rotation) <= 0.6:
		_fail("Expected Plague Prophet windup to read as a ritual arm raise.")
