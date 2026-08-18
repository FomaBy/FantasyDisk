extends RefCounted

## Сингулярный Якорь: anchor locks → gravity well drags and holds normals →
## black-point implosion → cyan EMP ring. The catalog's projectile clause is
## expressed through the accepted control surface: held normals are movement-
## locked, which freezes their fire for the well window. Already-flying
## projectiles need the still-missing `projectile_interaction_query` host
## primitive (see executor_contract_audit.json) and stay outside this package.

const PROFILE_ID := "weapon_ultimate.profile.robot.robot_magnetic_anchor"
const EXECUTOR_ID := "weapon_ultimate.executor.robot.robot_magnetic_anchor"
const SELF_PATH := "res://scripts/ultimates/classes/robot/robot_magnetic_anchor.gd"
const EFFECT_SCENE := "res://scripts/ultimates/classes/robot/robot_magnetic_anchor.tscn"


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 1.0},
		"radius": {"type": "number", "minimum": 1.0},
		"target_limit": {"type": "integer", "minimum": 1, "maximum": 8},
		"pull_strength": {"type": "number", "minimum": 0.0},
		"release_delay": {"type": "number", "minimum": 0.01},
		"implosion_delay": {"type": "number", "minimum": 0.01},
		"implosion_damage": {"type": "number", "minimum": 0.0},
		"emp_damage": {"type": "number", "minimum": 0.0},
		"emp_radius": {"type": "number", "minimum": 1.0},
		"recovery_tail": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var center: Vector2 = activation.aim_point(activation.param_float("max_range", 520.0))
	if center == Vector2.ZERO and activation.origin() != Vector2.ZERO:
		return 0.0
	if not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	var presentation = activation.spawn(EFFECT_SCENE)
	if presentation is Node2D:
		(presentation as Node2D).global_position = center
	activation.present(EXECUTOR_ID + ".windup", {
		"position": center, "radius": activation.param_float("radius", 250.0), "shape": "ring_pulse",
	})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("release_delay", 0.45))
	tween.tween_callback(Callable(script, "release").bind(activation, center))
	tween.tween_interval(activation.param_float("implosion_delay", 0.60))
	tween.tween_callback(Callable(script, "implode").bind(activation, center))
	tween.tween_interval(activation.param_float("recovery_tail", 3.70))
	return activation.param_float("release_delay", 0.45) \
		+ activation.param_float("implosion_delay", 0.60) \
		+ activation.param_float("recovery_tail", 3.70)


## The well grips: every held normal is dragged toward the anchor and movement-
## locked until the implosion, so it neither walks nor fires out of the grip.
static func release(activation, center: Vector2) -> void:
	if activation == null or activation.is_finished():
		return
	for raw_target in activation.targets(
		center, activation.param_float("radius", 250.0), activation.param_int("target_limit", 8)
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		activation.apply_control(
			target,
			(center - target.global_position).normalized() * activation.param_float("pull_strength", 220.0),
			"robot_anchor_pull_%d" % target.get_instance_id(),
			{
				"duration": activation.param_float("implosion_delay", 0.60),
				"movement_locked": true,
				"speed_multiplier": 0.65,
			}
		)
	activation.present(EXECUTOR_ID + ".release", {"position": center, "radius": 166.0, "shape": "ring_pulse"})


static func implode(activation, center: Vector2) -> void:
	if activation == null or activation.is_finished():
		return
	for raw_target in activation.targets(
		center, activation.param_float("radius", 250.0), activation.param_int("target_limit", 8)
	):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(
				target, activation.scaled_damage("implosion_damage", 16.0),
				{"source": "robot_singularity_implosion"}, "implosion"
			)
	activation.present(EXECUTOR_ID + ".implosion", {"position": center, "radius": 48.0, "shape": "orb_burst"})
	for raw_target in activation.targets(
		center, activation.param_float("emp_radius", 300.0), activation.param_int("target_limit", 8)
	):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(
				target, activation.scaled_damage("emp_damage", 6.0),
				{"source": "robot_singularity_emp"}, "emp", true
			)
	activation.present(EXECUTOR_ID + ".emp", {
		"position": center, "radius": activation.param_float("emp_radius", 300.0), "shape": "ring_pulse",
	})


static func _control_policy() -> Dictionary:
	return {
		"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": true, "allow_execute": false},
		"epic": {"displacement_multiplier": 0.25, "duration_multiplier": 0.50, "allow_movement_lock": false, "allow_execute": false},
		"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
	}
