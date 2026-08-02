class_name UltimateDamageResult
extends RefCounted

## Typed outcome of a single ultimate hit.
##
## `applied` is the HP the target actually lost, never the attempted amount: the
## whole-activation boss budget, charge gain and kill attribution all read the
## applied value, so overkill and damage-taken reductions cannot inflate them.

var target_id: int = 0
var attempted: float = 0.0
var applied: float = 0.0
var boss_capped: bool = false
var target_capped: bool = false
var killed: bool = false
var event_id := ""
var secondary := false
var creditable := false


func _init(
	target_id_value := 0,
	attempted_value := 0.0,
	applied_value := 0.0,
	boss_capped_value := false,
	killed_value := false,
	target_capped_value := false,
	event_id_value := "",
	secondary_value := false
) -> void:
	target_id = target_id_value
	attempted = attempted_value
	applied = applied_value
	boss_capped = boss_capped_value
	killed = killed_value
	target_capped = target_capped_value
	event_id = event_id_value
	secondary = secondary_value
	creditable = applied > 0.0 and not secondary


func to_dictionary() -> Dictionary:
	return {
		"target_id": target_id,
		"attempted": attempted,
		"applied": applied,
		"boss_capped": boss_capped,
		"target_capped": target_capped,
		"killed": killed,
		"event_id": event_id,
		"secondary": secondary,
		"creditable": creditable,
	}
