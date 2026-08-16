extends RefCounted

## Aimed sequence family: N aimed shots spread over time, one target each.
##
## Targets are picked once so the sequence keeps its spread, but a shot whose
## target died before its turn re-acquires the nearest live one instead of
## being wasted.
##
## Declaration params: radius, damage, shot_count, interval.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const STRATEGY_ID := "aimed_sequence"


static func execute(activation: Activation) -> float:
	var radius := activation.param_float("radius", 620.0)
	var shots := maxi(activation.param_int("shot_count", 5), 1)
	var interval := maxf(activation.param_float("interval", 0.09), 0.01)
	var damage := activation.scaled_damage()
	var planned := activation.targets(activation.origin(), radius, shots)
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	for shot_index in shots:
		tween.tween_interval(interval)
		tween.tween_callback(func() -> void:
			var target := _target_for_shot(activation, planned, shot_index, radius)
			if target == null:
				return
			activation.present(STRATEGY_ID, {
				"shape": "beam",
				"from": activation.origin(),
				"to": target.global_position,
			})
			activation.deal_damage(target, damage)
		)
	return interval * float(shots)


static func _target_for_shot(
	activation: Activation,
	planned: Array,
	shot_index: int,
	radius: float
) -> Node2D:
	if shot_index < planned.size():
		var planned_target = planned[shot_index]
		if planned_target is Node2D and is_instance_valid(planned_target):
			return planned_target as Node2D
	var fresh := activation.targets(activation.origin(), radius, 1)
	if fresh.is_empty() or not fresh[0] is Node2D or not is_instance_valid(fresh[0]):
		return null
	return fresh[0] as Node2D
