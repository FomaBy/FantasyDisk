extends RefCounted

## Aimed sequence family: N aimed volleys spread over time.
##
## Targets are picked once for the opening volley; later volleys re-acquire
## every live target so no enemy is excluded by a stale selection.
##
## Declaration params: radius, damage, shot_count, interval.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const STRATEGY_ID := "aimed_sequence"


static func execute(activation: Activation) -> float:
	var radius := activation.param_float("radius", 620.0)
	var shots := maxi(activation.param_int("shot_count", 5), 1)
	var interval := maxf(activation.param_float("interval", 0.09), 0.01)
	var damage := activation.scaled_damage()
	var planned := activation.targets(activation.origin(), radius, 0)
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	for shot_index in shots:
		tween.tween_interval(interval)
		tween.tween_callback(func() -> void:
			for target in _targets_for_volley(activation, planned, shot_index, radius):
				activation.present(STRATEGY_ID, {"shape": "beam", "from": activation.origin(), "to": target.global_position})
				activation.deal_damage(target, damage)
		)
	return interval * float(shots)


static func _targets_for_volley(
	activation: Activation,
	planned: Array,
	shot_index: int,
	radius: float
) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var source: Array = planned if shot_index == 0 else activation.targets(activation.origin(), radius, 0)
	for raw_target in source:
		if raw_target is Node2D and is_instance_valid(raw_target):
			targets.append(raw_target as Node2D)
	return targets
