extends RefCounted

## Burst family: one instant hit on everything the declaration selects.
##
## Declaration params: radius, damage, target_limit.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const STRATEGY_ID := "burst"


static func execute(activation: Activation) -> float:
	var origin := activation.origin()
	var radius := activation.param_float("radius", 320.0)
	var damage := activation.scaled_damage()
	activation.present(STRATEGY_ID, {"shape": "orb_burst", "position": origin, "radius": radius})
	for target in activation.targets(origin, radius, activation.param_int("target_limit", 0)):
		activation.deal_damage(target as Node, damage)
	return 0.0
