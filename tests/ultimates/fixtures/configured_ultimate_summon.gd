extends Node2D

var ultimate_damage_sink: Callable = Callable()
var role := ""
var setup_owner: Node = null


func ultimate_spawn_setup(config: Dictionary, owner: Node, damage_sink: Callable) -> bool:
	if config.keys() != ["role"] or not config["role"] is String \
			or str(config["role"]).is_empty() or not damage_sink.is_valid():
		return false
	role = str(config["role"])
	setup_owner = owner
	ultimate_damage_sink = damage_sink
	return true
