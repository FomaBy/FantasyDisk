extends RefCounted

## Chained projectile family: a bolt that hops from target to target.
##
## Each hop searches from where the previous one landed and never revisits a
## target, so the chain walks outward instead of ping-ponging between two
## enemies. Damage decays by `falloff` per hop.
##
## Declaration params: radius, damage, jumps, hop_delay, falloff.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const STRATEGY_ID := "chained_projectile"


static func execute(activation: Activation) -> float:
	var radius := activation.param_float("radius", 260.0)
	var jumps := maxi(activation.param_int("jumps", 4), 1)
	var hop_delay := maxf(activation.param_float("hop_delay", 0.1), 0.01)
	var falloff := clampf(activation.param_float("falloff", 0.8), 0.0, 1.0)
	var damage := activation.scaled_damage()
	# Dictionaries are references, so the chain head survives across callbacks.
	var chain := {"position": activation.origin(), "hit": {}}
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	for hop_index in jumps:
		tween.tween_interval(hop_delay)
		tween.tween_callback(func() -> void:
			var target := _next_target(activation, chain, radius)
			if target == null:
				return
			(chain["hit"] as Dictionary)[target.get_instance_id()] = true
			activation.present(STRATEGY_ID, {
				"shape": "beam",
				"from": chain["position"],
				"to": target.global_position,
			})
			chain["position"] = target.global_position
			activation.deal_damage(target, damage * pow(falloff, float(hop_index)))
		)
	return hop_delay * float(jumps)


static func _next_target(activation: Activation, chain: Dictionary, radius: float) -> Node2D:
	var hit: Dictionary = chain["hit"]
	for raw_target in activation.targets(chain["position"], radius, 0):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target) or hit.has(target.get_instance_id()):
			continue
		return target
	return null
