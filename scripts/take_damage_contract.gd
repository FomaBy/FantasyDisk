extends RefCounted

# FAN-3061: get_method_list() rebuilds hundreds of method dictionaries per call
# (~2.7ms on enemy.gd), and the map-wide ultimates (FAN-2952/FAN-2953) call this
# once per hit across every live enemy — enough to stall a frame for seconds on a
# dense map. The take_damage arity is a property of the script, not the instance,
# so the scan result is cached per script.
const DICTIONARY_FEEDBACK := 1
const SECOND_ARGUMENT := 2

static var _contract_by_script := {}


static func accepts_feedback(target: Object) -> bool:
	return (_contract(target) & DICTIONARY_FEEDBACK) != 0


# Weapons and summons historically use arity, with their own target eligibility
# rules. Keep that contract separate from the stricter player feedback API.
static func accepts_second_argument(target: Object) -> bool:
	return (_contract(target) & SECOND_ARGUMENT) != 0


static func _contract(target: Object) -> int:
	var script = target.get_script()
	var key: int = script.get_instance_id() if script is Object else 0
	if key != 0 and _contract_by_script.has(key):
		return _contract_by_script[key]
	var result := _scan_contract(target)
	if key != 0:
		_contract_by_script[key] = result
	return result


static func _scan_contract(target: Object) -> int:
	for method in target.get_method_list():
		if str(method.get("name", "")) != "take_damage":
			continue
		var args: Array = method.get("args", [])
		if args.size() < 2:
			return 0
		var feedback_type := int((args[1] as Dictionary).get("type", TYPE_NIL))
		if feedback_type != TYPE_NIL:
			return SECOND_ARGUMENT | (DICTIONARY_FEEDBACK if feedback_type == TYPE_DICTIONARY else 0)
		# Godot reports untyped parameters as TYPE_NIL. A concrete Dictionary
		# default opts in; String or unresolved/null defaults stay on the safe
		# one-argument contract instead of receiving structured feedback.
		var defaults: Array = method.get("default_args", [])
		var default_index := 1 - (args.size() - defaults.size())
		var dictionary_default := default_index >= 0 and default_index < defaults.size() \
			and defaults[default_index] is Dictionary
		return SECOND_ARGUMENT | (DICTIONARY_FEEDBACK if dictionary_default else 0)
	return 0
