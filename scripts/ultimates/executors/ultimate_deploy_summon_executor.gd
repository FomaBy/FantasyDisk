extends RefCounted

## Deploy/summon family: place declared scenes that outlive the execute step.
##
## The activation owns the spawned nodes, so their lifetime is the cast duration
## and cancelling the cast removes them. A spawn that exposes an
## `ultimate_damage_sink` property is bound to the activation ledger, so its
## deferred damage still spends the same whole-activation boss budget.
##
## Declaration params: scene, count, spawn_radius, lifetime, damage, properties.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const STRATEGY_ID := "deploy_summon"


static func execute(activation: Activation) -> float:
	var scene_path := activation.param_string("scene")
	var count := maxi(activation.param_int("count", 1), 1)
	var spawn_radius := activation.param_float("spawn_radius", 72.0)
	var lifetime := maxf(activation.param_float("lifetime", 6.0), 0.1)
	var damage := activation.scaled_damage()
	var properties := activation.param_dictionary("properties")
	var origin := activation.origin()
	activation.present(STRATEGY_ID, {
		"shape": "ring_pulse",
		"position": origin,
		"radius": spawn_radius,
		"duration": lifetime,
	})
	for spawn_index in count:
		var node := activation.spawn(scene_path)
		if node == null:
			continue
		if node is Node2D:
			(node as Node2D).global_position = origin \
				+ Vector2.RIGHT.rotated(TAU * float(spawn_index) / float(count)) * spawn_radius
		if "owner_node" in node:
			node.set("owner_node", activation.host)
		if "damage" in node:
			node.set("damage", damage)
		for raw_key in properties.keys():
			var key := str(raw_key)
			if key in node:
				node.set(key, properties[raw_key])
	return lifetime
