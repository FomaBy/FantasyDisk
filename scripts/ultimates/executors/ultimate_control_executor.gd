extends RefCounted

## Control family: displace and lock down everything in the radius.
##
## Declaration params: radius, damage, target_limit, knockback, status_id,
## status.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const STRATEGY_ID := "control"


static func execute(activation: Activation) -> float:
	var origin := activation.origin()
	var radius := activation.param_float("radius", 340.0)
	var knockback := activation.param_float("knockback", 620.0)
	var damage := activation.scaled_damage("damage", 0.0)
	var status_id := activation.param_string("status_id")
	var status_config := activation.param_dictionary("status")
	status_config.erase("dot_damage")
	activation.present(STRATEGY_ID, {"shape": "ring_pulse", "position": origin, "radius": radius})
	for raw_target in activation.targets(origin, radius, activation.param_int("target_limit", 0)):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var away := target.global_position - origin
		if knockback > 0.0 and target.has_method("apply_knockback") and away.length_squared() > 0.001:
			target.call("apply_knockback", away.normalized() * knockback)
		if not status_id.is_empty():
			StatusEffects.apply_status(target, status_id, status_config)
		if damage > 0.0:
			activation.deal_damage(target, damage)
	return 0.0
