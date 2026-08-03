extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.guitarist.bass_guitar"
const EXECUTOR_ID := "weapon_ultimate.executor.guitarist.bass_guitar"
const SELF_PATH := "res://scripts/ultimates/classes/guitarist/bass_guitar.gd"

const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.35, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}


static func parameter_contract() -> Dictionary:
	return {
		"windup_delay": {"type": "number", "minimum": 0.0},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"recovery_tail": {"type": "number", "minimum": 0.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"pull_radius": {"type": "number", "minimum": 1.0},
		"weight_radius": {"type": "number", "minimum": 1.0},
		"launch_radius": {"type": "number", "minimum": 1.0},
		"shock_radius": {"type": "number", "minimum": 1.0},
		"pull_damage": {"type": "number", "minimum": 0.0},
		"weight_damage": {"type": "number", "minimum": 0.0},
		"launch_damage": {"type": "number", "minimum": 0.0},
		"shock_damage": {"type": "number", "minimum": 0.0},
		"pull_force": {"type": "number", "minimum": 0.0},
		"launch_force": {"type": "number", "minimum": 0.0},
		"shock_force": {"type": "number", "minimum": 0.0},
		"pull_duration": {"type": "number", "minimum": 0.0},
		"weight_duration": {"type": "number", "minimum": 0.0},
		"launch_duration": {"type": "number", "minimum": 0.0},
		"shock_duration": {"type": "number", "minimum": 0.0},
		"weight_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_flat": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.30),
		activation.param_float("per_target_cap_flat", 0.0)
	) or not activation.set_control_resistance_policy(CONTROL_POLICY):
		return 0.0
	var state := {"waves": []}
	activation.set_primitive_state({"guitarist_hell_subwoofer": state})
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("windup_delay", 0.70))
	for stage in ["pull", "weight", "launch", "shock"]:
		if stage != "pull":
			tween.tween_interval(activation.param_float("wave_interval", 0.53))
		tween.tween_callback(Callable(script, "fire_wave").bind(activation, state, stage))
	tween.tween_interval(activation.param_float("recovery_tail", 3.51))
	return activation.param_float("windup_delay", 0.70) \
		+ activation.param_float("wave_interval", 0.53) * 3.0 \
		+ activation.param_float("recovery_tail", 3.51)


static func fire_wave(activation, state: Dictionary, stage: String) -> void:
	if activation.is_finished():
		return
	var radius: float = activation.param_float("%s_radius" % stage, 0.0)
	var damage: float = activation.scaled_damage("%s_damage" % stage, 0.0)
	var duration: float = activation.param_float("%s_duration" % stage, 0.0)
	for raw_target in activation.targets(activation.origin(), radius, activation.param_int("crowd_cap", 12)):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var away: Vector2 = target.global_position - activation.origin()
		var impulse := Vector2.ZERO
		if away.length_squared() > 0.001:
			match stage:
				"pull": impulse = -away.normalized() * activation.param_float("pull_force", 480.0)
				"launch": impulse = away.normalized() * activation.param_float("launch_force", 620.0)
				"shock": impulse = away.normalized() * activation.param_float("shock_force", 920.0)
		activation.deal_damage(target, damage, {"ultimate_mechanic": "bass_%s" % stage}, "bass:%s" % stage)
		activation.apply_control(target, impulse, "bass:%s:%d" % [stage, target.get_instance_id()], {
			"duration": duration,
			"speed_multiplier": activation.param_float("weight_slow", 0.42) if stage == "weight" else 0.78,
			"bass_wave": stage,
		})
	(state["waves"] as Array).append(stage)
	activation.present(EXECUTOR_ID + "." + stage, {
		"shape": "ring_pulse", "position": activation.origin(), "radius": radius,
	})
