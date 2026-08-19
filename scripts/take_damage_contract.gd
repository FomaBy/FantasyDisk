extends RefCounted

# FAN-3061: get_method_list() rebuilds hundreds of method dictionaries per call
# (~2.7ms on enemy.gd), and the map-wide ultimates (FAN-2952/FAN-2953) call this
# once per hit across every live enemy — enough to stall a frame for seconds on a
# dense map. The take_damage arity is a property of the script, not the instance,
# so the scan result is cached per script.
static var _accepts_by_script := {}


static func accepts_feedback(target: Object) -> bool:
	var script = target.get_script()
	var key: int = script.get_instance_id() if script is Object else 0
	if key != 0 and _accepts_by_script.has(key):
		return _accepts_by_script[key]
	var result := _scan_accepts_feedback(target)
	if key != 0:
		_accepts_by_script[key] = result
	return result


static func _scan_accepts_feedback(target: Object) -> bool:
	for method in target.get_method_list():
		if str(method.get("name", "")) != "take_damage":
			continue
		var args: Array = method.get("args", [])
		if args.size() < 2:
			return false
		var feedback_type := int((args[1] as Dictionary).get("type", TYPE_NIL))
		if feedback_type != TYPE_NIL:
			return feedback_type == TYPE_DICTIONARY
		# Godot reports untyped parameters as TYPE_NIL. A concrete Dictionary
		# default opts in; String or unresolved/null defaults stay on the safe
		# one-argument contract instead of receiving structured feedback.
		var defaults: Array = method.get("default_args", [])
		var default_index := 1 - (args.size() - defaults.size())
		return default_index >= 0 and default_index < defaults.size() \
			and defaults[default_index] is Dictionary
	return false
