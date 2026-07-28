extends RefCounted

## Timed modifier family: hold declared run modifiers for the cast duration.
##
## Nothing is reverted here — every modifier is applied through the activation,
## which unwinds them in reverse order when the cast ends or is cancelled.
##
## Declaration params: duration, radius, modifiers {key: {value, op}}.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const STRATEGY_ID := "timed_modifier"


static func execute(activation: Activation) -> float:
	var duration := maxf(activation.param_float("duration", 5.0), 0.1)
	var modifiers := activation.param_dictionary("modifiers")
	for raw_key in modifiers.keys():
		var entry = modifiers[raw_key]
		if not entry is Dictionary:
			continue
		activation.apply_modifier(
			str(raw_key),
			float((entry as Dictionary).get("value", 0.0)),
			str((entry as Dictionary).get("op", Activation.OP_ADD))
		)
	activation.present(STRATEGY_ID, {
		"shape": "ring_pulse",
		"position": activation.origin(),
		"radius": activation.param_float("radius", 200.0),
		"duration": duration,
	})
	return duration
