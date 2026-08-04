extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.robot.robot_hydraulic_press"
const EXECUTOR_ID := "weapon_ultimate.executor.robot.robot_hydraulic_press"
const SELF_PATH := "res://scripts/ultimates/classes/robot/robot_hydraulic_press.gd"


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 1.0},
		"length": {"type": "number", "minimum": 1.0},
		"half_width": {"type": "number", "minimum": 1.0},
		"target_limit": {"type": "integer", "minimum": 1, "maximum": 8},
		"windup_delay": {"type": "number", "minimum": 0.01},
		"crush_count": {"type": "integer", "minimum": 1, "maximum": 8},
		"crush_interval": {"type": "number", "minimum": 0.01},
		"compression_strength": {"type": "number", "minimum": 0.0},
		"crush_damage": {"type": "number", "minimum": 0.0},
		"release_damage": {"type": "number", "minimum": 0.0},
		"recovery_tail": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var direction: Vector2 = activation.aim_direction(activation.param_float("max_range", 430.0))
	if direction.length_squared() <= 0.001 or not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	activation.set_primitive_state({"robot_press_direction": direction.normalized()})
	activation.present(EXECUTOR_ID + ".windup", {
		"position": activation.origin(), "radius": activation.param_float("half_width", 150.0), "shape": "beam",
		"from": activation.origin(), "to": activation.origin() + direction * activation.param_float("length", 430.0),
	})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	var interval: float = activation.param_float("crush_interval", 0.30)
	tween.tween_interval(activation.param_float("windup_delay", 0.72))
	tween.tween_callback(Callable(script, "crush").bind(activation, 0))
	for index in range(1, activation.param_int("crush_count", 3)):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(script, "crush").bind(activation, index))
	tween.tween_interval(interval)
	tween.tween_callback(Callable(script, "release").bind(activation))
	tween.tween_interval(activation.param_float("recovery_tail", 2.43))
	return activation.param_float("windup_delay", 0.72) \
		+ interval * float(activation.param_int("crush_count", 3)) \
		+ activation.param_float("recovery_tail", 2.43)


static func crush(activation, index: int) -> void:
	if activation == null or activation.is_finished():
		return
	var direction = activation.primitive_value("robot_press_direction", Vector2.ZERO)
	if not direction is Vector2:
		return
	var axis := direction as Vector2
	var perpendicular := Vector2(-axis.y, axis.x)
	for raw_target in activation.targets_in_corridor(
		activation.origin(), axis, activation.param_float("length", 430.0), activation.param_float("half_width", 150.0), activation.param_int("target_limit", 8)
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var lateral: float = (target.global_position - activation.origin()).dot(perpendicular)
		activation.apply_control(
			target, -perpendicular * signf(lateral) * activation.param_float("compression_strength", 180.0),
			"robot_press_%d_%d" % [index, target.get_instance_id()], {"duration": 0.28, "speed_multiplier": 0.60}
		)
		activation.deal_damage(target, activation.scaled_damage("crush_damage", 7.50),
			{"source": "robot_hydraulic_crush", "crush": index}, "crush:%d" % index)
	activation.present(EXECUTOR_ID + ".crush", {
		"position": activation.origin(), "radius": activation.param_float("half_width", 150.0), "shape": "beam",
		"from": activation.origin(), "to": activation.origin() + axis * activation.param_float("length", 430.0),
	})


static func release(activation) -> void:
	if activation == null or activation.is_finished():
		return
	var direction = activation.primitive_value("robot_press_direction", Vector2.ZERO)
	if not direction is Vector2:
		return
	for raw_target in activation.targets_in_corridor(
		activation.origin(), direction as Vector2, activation.param_float("length", 430.0), activation.param_float("half_width", 150.0), activation.param_int("target_limit", 8)
	):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(target, activation.scaled_damage("release_damage", 7.50),
				{"source": "robot_hydraulic_release"}, "release", true)
	activation.present(EXECUTOR_ID + ".release", {"position": activation.origin(), "radius": 180.0, "shape": "orb_burst"})


static func _control_policy() -> Dictionary:
	return {
		"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": false},
		"epic": {"displacement_multiplier": 0.25, "duration_multiplier": 0.50, "allow_movement_lock": false, "allow_execute": false},
		"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
	}
