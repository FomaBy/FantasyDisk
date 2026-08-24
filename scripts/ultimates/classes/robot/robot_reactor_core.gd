extends RefCounted

## Красная Зона: core panels open → eight red-orange vents spin faster each
## wave → white-hot final vent clears the space → cooldown. The temporary
## absorb opens on the first deferred overdrive beat — never on the activation
## frame — so an immediately cancelled cast leaves run modifiers untouched,
## and shutdown unwinds it so no buff is carried out of the cast.

const PROFILE_ID := "weapon_ultimate.profile.robot.robot_reactor_core"
const EXECUTOR_ID := "weapon_ultimate.executor.robot.robot_reactor_core"
const SELF_PATH := "res://scripts/ultimates/classes/robot/robot_reactor_core.gd"


static func parameter_contract() -> Dictionary:
	return {
		"vent_count": {"type": "integer", "minimum": 1, "maximum": 8},
		"wave_count": {"type": "integer", "minimum": 1, "maximum": 8},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"range": {"type": "number", "minimum": 1.0},
		"half_width": {"type": "number", "minimum": 1.0},
		"vent_damage": {"type": "number", "minimum": 0.0},
		"final_damage": {"type": "number", "minimum": 0.0},
		"absorb_flat": {"type": "number", "minimum": 0.0},
		"recovery_tail": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	activation.present(EXECUTOR_ID + ".windup", {"position": activation.origin(), "radius": 104.0, "shape": "ring_pulse"})
	vent_wave(activation, 0)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_callback(Callable(script, "overdrive").bind(activation))
	var interval: float = activation.param_float("wave_interval", 0.38)
	for wave in range(1, activation.param_int("wave_count", 4)):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(script, "vent_wave").bind(activation, wave))
	tween.tween_interval(interval)
	tween.tween_callback(Callable(script, "final_vent").bind(activation))
	tween.tween_interval(activation.param_float("recovery_tail", 4.50))
	return interval * float(activation.param_int("wave_count", 4)) + activation.param_float("recovery_tail", 4.50)


static func overdrive(activation) -> void:
	if activation == null or activation.is_finished():
		return
	activation.apply_modifier("absorb_flat", activation.param_float("absorb_flat", 5.0), "add")
	activation.present(EXECUTOR_ID + ".overdrive", {"position": activation.origin(), "radius": 104.0, "shape": "ring_pulse"})


static func vent_wave(activation, wave: int) -> void:
	if activation == null or activation.is_finished():
		return
	var count: int = activation.param_int("vent_count", 8)
	# Quadratic offset per wave: the vent ring visibly accelerates its spin.
	var spin := float(wave * (wave + 1)) * 0.11
	for index in count:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(count) + spin)
		for raw_target in activation.targets_in_corridor(
			activation.origin(), direction, activation.param_float("range", 300.0), activation.param_float("half_width", 90.0), 0
		):
			var target := raw_target as Node
			if target != null and is_instance_valid(target):
				activation.deal_damage(target, activation.scaled_damage("vent_damage", 6.50),
					{"source": "robot_reactor_vent", "wave": wave, "vent": index}, "vent:%d:%d" % [wave, index])
	activation.present(EXECUTOR_ID + ".vent_wave", {"position": activation.origin(), "radius": activation.param_float("range", 300.0), "shape": "ring_pulse"})


static func final_vent(activation) -> void:
	if activation == null or activation.is_finished():
		return
	for raw_target in activation.targets(activation.origin(), activation.param_float("range", 300.0), 0):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(target, activation.scaled_damage("final_damage", 10.0),
				{"source": "robot_reactor_final_vent"}, "final", true)
	activation.present(EXECUTOR_ID + ".final_vent", {"position": activation.origin(), "radius": activation.param_float("range", 300.0), "shape": "orb_burst"})
