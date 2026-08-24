extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.guitarist.electric_guitar"
const EXECUTOR_ID := "weapon_ultimate.executor.guitarist.electric_guitar"
const SELF_PATH := "res://scripts/ultimates/classes/guitarist/electric_guitar.gd"
const RIFF_LEDGER_KEY := "guitarist_last_chord_riff"

const CONTROL_POLICY := {
	"normal": {
		"displacement_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"allow_movement_lock": true,
		"allow_execute": true,
	},
	"epic": {
		"displacement_multiplier": 0.0,
		"duration_multiplier": 0.35,
		"allow_movement_lock": false,
		"allow_execute": true,
	},
	"boss": {
		"displacement_multiplier": 0.0,
		"duration_multiplier": 0.0,
		"allow_movement_lock": false,
		"allow_execute": false,
	},
}


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 1.0},
		"strip_count": {"type": "integer", "minimum": 5, "maximum": 5},
		"strip_length": {"type": "number", "minimum": 1.0},
		"strip_half_width": {"type": "number", "minimum": 1.0},
		"angle_degrees": {"type": "number", "minimum": 0.0, "maximum": 80.0},
		"windup_delay": {"type": "number", "minimum": 0.0},
		"strip_interval": {"type": "number", "minimum": 0.01},
		"final_delay": {"type": "number", "minimum": 0.0},
		"recovery_tail": {"type": "number", "minimum": 0.0},
		"strip_damage": {"type": "number", "minimum": 0.0},
		"final_damage": {"type": "number", "minimum": 0.0},
		"stun_duration": {"type": "number", "minimum": 0.0},
		"per_target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_flat": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.30),
		activation.param_float("per_target_cap_flat", 0.0)
	) or not activation.set_control_resistance_policy(CONTROL_POLICY):
		return 0.0
	var aim: Dictionary = activation.aim_context(activation.param_float("max_range", 720.0))
	if aim.is_empty():
		return 0.0
	var center: Vector2 = aim["target"]
	var direction: Vector2 = aim["direction"]
	var state := {"center": center, "strips_fired": 0, "intersections": 0}
	activation.set_primitive_state({"guitarist_last_chord": state})
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("windup_delay", 0.52))
	for strip_index in activation.param_int("strip_count", 5):
		if strip_index > 0:
			tween.tween_interval(activation.param_float("strip_interval", 0.16))
		tween.tween_callback(Callable(script, "fire_riff_strip").bind(
			activation, state, center, direction, strip_index
		))
	tween.tween_interval(activation.param_float("final_delay", 0.24))
	tween.tween_callback(Callable(script, "fire_final_chord").bind(activation, state, center, direction))
	tween.tween_interval(activation.param_float("recovery_tail", 4.0))
	return activation.param_float("windup_delay", 0.52) \
		+ activation.param_float("strip_interval", 0.16) \
			* float(activation.param_int("strip_count", 5) - 1) \
		+ activation.param_float("final_delay", 0.24) \
		+ activation.param_float("recovery_tail", 4.0)


static func fire_riff_strip(
	activation,
	state: Dictionary,
	center: Vector2,
	direction: Vector2,
	strip_index: int
) -> void:
	if activation.is_finished():
		return
	var angle := deg_to_rad(activation.param_float("angle_degrees", 24.0))
	var axis := direction.rotated(angle if strip_index % 2 == 0 else -angle)
	var length: float = activation.param_float("strip_length", 1400.0)
	var start := center - axis * length * 0.5
	var damage: float = activation.scaled_damage("strip_damage", 10.0)
	for raw_target in activation.select_targets(center, INF, 0, "nearest"):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		activation.record_target_value(target, RIFF_LEDGER_KEY, 1.0, "riff:%d" % strip_index)
		activation.deal_damage(target, damage, {"ultimate_mechanic": "riff_strip"}, "riff:%d" % strip_index)
	state["strips_fired"] = int(state.get("strips_fired", 0)) + 1
	activation.present(EXECUTOR_ID + ".riff:%d" % strip_index, {
		"shape": "beam", "from": start, "to": start + axis * length,
	})


static func fire_final_chord(activation, state: Dictionary, center: Vector2, direction: Vector2) -> void:
	if activation.is_finished():
		return
	var axis := direction.rotated(PI * 0.5)
	var length: float = activation.param_float("strip_length", 1400.0)
	var start := center - axis * length * 0.5
	for raw_target in activation.targets_in_corridor(
		start,
		axis,
		length,
		activation.param_float("strip_half_width", 46.0),
		0
	):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		activation.deal_damage(
			target,
			activation.scaled_damage("final_damage", 35.0),
			{"ultimate_mechanic": "final_chord"},
			"final_chord"
		)
		if activation.target_value(target, RIFF_LEDGER_KEY) == null:
			continue
		activation.apply_control(target, Vector2.ZERO, "last_chord:%d" % target.get_instance_id(), {
			"duration": activation.param_float("stun_duration", 1.4),
			"movement_locked": true,
			"last_chord_stun": true,
		})
		state["intersections"] = int(state.get("intersections", 0)) + 1
	activation.present(EXECUTOR_ID + ".final", {
		"shape": "beam", "from": start, "to": start + axis * length,
	})
