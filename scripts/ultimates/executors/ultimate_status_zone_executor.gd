extends RefCounted

## Status/zone family: a lingering area that ticks damage and refreshes a status.
##
## The tick damage runs through the activation rather than through a StatusEffects
## `dot_damage`, because a status ticks on the target and would bypass the
## whole-activation boss budget. Any declared `dot_damage` is dropped for the
## same reason.
##
## Declaration params: radius, damage, duration, interval, follow_host,
## status_id, status.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const STRATEGY_ID := "status_zone"


static func execute(activation: Activation) -> float:
	var anchor := activation.origin()
	var radius := activation.param_float("radius", 260.0)
	var duration := maxf(activation.param_float("duration", 4.0), 0.1)
	var interval := maxf(activation.param_float("interval", 0.5), 0.05)
	var follow_host := activation.param_bool("follow_host")
	var tick_damage := activation.scaled_damage()
	var status_id := activation.param_string("status_id")
	var status_config := activation.param_dictionary("status")
	status_config.erase("dot_damage")
	activation.present(STRATEGY_ID, {
		"shape": "ring_pulse",
		"position": anchor,
		"radius": radius,
		"duration": duration,
	})
	var ticks := maxi(int(floor(duration / interval)), 1)
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	for _tick_index in ticks:
		tween.tween_interval(interval)
		tween.tween_callback(func() -> void:
			var center := activation.origin() if follow_host else anchor
			for raw_target in activation.targets(center, radius, 0):
				var target := raw_target as Node
				activation.deal_damage(target, tick_damage, {"damage_type": "dot"})
				if not status_id.is_empty():
					StatusEffects.apply_status(target, status_id, status_config)
		)
	return interval * float(ticks)
