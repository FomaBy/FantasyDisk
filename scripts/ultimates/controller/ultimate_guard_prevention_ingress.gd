class_name UltimateGuardPreventionIngress
extends RefCounted

## Emits only final-mitigation prevention that a live guard has explicitly
## opened. Keeping this outside Player preserves its generic ingress boundary.

const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")

static var _event_sequence := 0


static func emit_measured(
		player_node: Node2D,
		incoming_amount: float,
		applied_amount: float,
		source: String,
		attacker: Node2D
) -> void:
	if not is_finite(incoming_amount) or not is_finite(applied_amount) \
			or incoming_amount <= 0.0 or applied_amount < 0.0 \
			or source.strip_edges().is_empty() \
			or attacker == null or not is_instance_valid(attacker):
		return
	var incoming_direction := attacker.global_position - player_node.global_position
	var prevented_amount := maxf(incoming_amount - applied_amount, 0.0)
	var owner_id := PlayerHost.guard_prevention_owner(player_node)
	if incoming_direction.length_squared() <= 0.001 or prevented_amount <= 0.0 or owner_id.is_empty():
		return
	_event_sequence += 1
	player_node.emit_signal("guard_prevention_measured", {
		"event_id": "player_guard_prevention:%d" % _event_sequence,
		"owner_id": owner_id,
		"source": source.strip_edges(),
		"direction": incoming_direction.normalized(),
		"incoming_amount": incoming_amount,
		"applied_amount": applied_amount,
		"prevented_amount": prevented_amount,
	})
