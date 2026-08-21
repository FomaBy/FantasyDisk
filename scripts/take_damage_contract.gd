extends RefCounted


static func accepts_feedback(target: Object) -> bool:
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
