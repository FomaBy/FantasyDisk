extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.guitarist.sound_amp"
const EXECUTOR_ID := "weapon_ultimate.executor.guitarist.sound_amp"
const SELF_PATH := "res://scripts/ultimates/classes/guitarist/sound_amp.gd"
const EFFECT_SCENE := "res://scripts/ultimates/classes/guitarist/sound_amp.tscn"

const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.30, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}


static func parameter_contract() -> Dictionary:
	return {
		"deploy_delay": {"type": "number", "minimum": 0.0},
		"pulse_count": {"type": "integer", "minimum": 4, "maximum": 4},
		"pulse_interval": {"type": "number", "minimum": 0.01},
		"overload_delay": {"type": "number", "minimum": 0.0},
		"recovery_tail": {"type": "number", "minimum": 0.0},
		"amp_radius": {"type": "number", "minimum": 1.0},
		"square_half_side": {"type": "number", "minimum": 1.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"feedback_damage": {"type": "number", "minimum": 0.0},
		"overload_damage": {"type": "number", "minimum": 0.0},
		"feedback_duration": {"type": "number", "minimum": 0.0},
		"feedback_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"overload_knockback": {"type": "number", "minimum": 0.0},
		"per_target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_flat": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.30),
		activation.param_float("per_target_cap_flat", 0.0)
	) or not activation.set_control_resistance_policy(CONTROL_POLICY):
		return 0.0
	var presentation = activation.spawn(EFFECT_SCENE)
	if presentation is Node2D:
		(presentation as Node2D).global_position = activation.origin()
	var state := {"points": _amp_points(activation), "pulses": 0, "linked": false}
	activation.set_primitive_state({"guitarist_wall_of_sound": state})
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("deploy_delay", 0.68))
	tween.tween_callback(Callable(script, "deploy_stage").bind(activation, state))
	for pulse_index in activation.param_int("pulse_count", 4):
		if pulse_index > 0:
			tween.tween_interval(activation.param_float("pulse_interval", 0.27))
		tween.tween_callback(Callable(script, "feedback_pulse").bind(activation, state, pulse_index))
	tween.tween_interval(activation.param_float("overload_delay", 0.45))
	tween.tween_callback(Callable(script, "overload").bind(activation, state))
	tween.tween_interval(activation.param_float("recovery_tail", 4.06))
	return activation.param_float("deploy_delay", 0.68) \
		+ activation.param_float("pulse_interval", 0.27) \
			* float(activation.param_int("pulse_count", 4) - 1) \
		+ activation.param_float("overload_delay", 0.45) \
		+ activation.param_float("recovery_tail", 4.06)


static func deploy_stage(activation, state: Dictionary) -> void:
	if activation.is_finished():
		return
	for point in state["points"] as PackedVector2Array:
		activation.present(EXECUTOR_ID + ".amp", {"shape": "orb_burst", "position": point, "radius": 70.0})
	state["linked"] = true
	activation.present(EXECUTOR_ID + ".cables", {
		"shape": "ring_pulse", "position": activation.origin(),
		"radius": activation.param_float("square_half_side", 260.0),
	})


static func feedback_pulse(activation, state: Dictionary, pulse_index: int) -> void:
	if activation.is_finished() or not bool(state.get("linked", false)):
		return
	for raw_target in _square_targets(activation):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		activation.deal_damage(
			target,
			activation.scaled_damage("feedback_damage", 10.0),
			{"ultimate_mechanic": "amp_feedback", "pulse": pulse_index},
			"feedback:%d" % pulse_index
		)
		activation.apply_control(target, Vector2.ZERO, "feedback:%d:%d" % [pulse_index, target.get_instance_id()], {
			"duration": activation.param_float("feedback_duration", 2.0),
			"speed_multiplier": activation.param_float("feedback_slow", 0.52),
			"feedback_field": true,
		})
	state["pulses"] = int(state.get("pulses", 0)) + 1
	activation.present(EXECUTOR_ID + ".feedback:%d" % pulse_index, {
		"shape": "ring_pulse", "position": activation.origin(),
		"radius": activation.param_float("square_half_side", 260.0),
	})


static func overload(activation, state: Dictionary) -> void:
	if activation.is_finished() or not bool(state.get("linked", false)):
		return
	for raw_target in _square_targets(activation):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var away: Vector2 = target.global_position - activation.origin()
		var impulse: Vector2 = away.normalized() * activation.param_float("overload_knockback", 880.0) \
			if away.length_squared() > 0.001 else Vector2.ZERO
		activation.deal_damage(target, activation.scaled_damage("overload_damage", 40.0), {
			"ultimate_mechanic": "amp_overload",
		}, "overload")
		activation.apply_control(target, impulse, "overload:%d" % target.get_instance_id(), {
			"duration": 0.5, "speed_multiplier": 0.75, "feedback_overload": true,
		})
	for point in state["points"] as PackedVector2Array:
		activation.present(EXECUTOR_ID + ".overload", {"shape": "orb_burst", "position": point, "radius": 120.0})


static func _amp_points(activation) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius: float = activation.param_float("amp_radius", 260.0)
	for index in 4:
		points.append(activation.origin() + Vector2.RIGHT.rotated(TAU * float(index) / 4.0) * radius)
	return points


static func _square_targets(activation) -> Array:
	var selected: Array = []
	var half_side: float = activation.param_float("square_half_side", 260.0)
	var origin: Vector2 = activation.origin()
	for raw_target in activation.targets(origin, half_side * sqrt(2.0), 0):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var offset: Vector2 = target.global_position - origin
		if absf(offset.x) <= half_side and absf(offset.y) <= half_side:
			selected.append(target)
			if selected.size() >= activation.param_int("crowd_cap", 14):
				break
	return selected
