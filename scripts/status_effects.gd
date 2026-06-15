class_name StatusEffects
extends RefCounted

const META_KEY := "status_effects"
const MARKER_META_KEY := "status_marker_color"


static func apply_status(target: Node, status_id: String, config: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or status_id.strip_edges() == "":
		return
	var statuses := _statuses(target)
	var existing: Dictionary = statuses.get(status_id, {})
	var max_stacks := maxi(int(config.get("max_stacks", existing.get("max_stacks", 1))), 1)
	var stack_mode := str(config.get("stack_mode", "refresh"))
	var current_stacks := int(existing.get("stacks", 0))
	var stacks := 1
	match stack_mode:
		"add":
			stacks = mini(current_stacks + 1, max_stacks)
		"extend":
			stacks = maxi(current_stacks, 1)
		_:
			stacks = maxi(current_stacks, 1)
	var duration := maxf(float(config.get("duration", existing.get("duration", 0.0))), 0.0)
	var remaining := duration
	if stack_mode == "extend" and not existing.is_empty():
		remaining = maxf(float(existing.get("remaining", 0.0)), 0.0) + duration
	var status := config.duplicate(true)
	status["id"] = status_id
	status["duration"] = duration
	status["remaining"] = remaining
	status["stacks"] = stacks
	status["max_stacks"] = max_stacks
	status["tick_left"] = minf(float(existing.get("tick_left", config.get("dot_interval", 1.0))), maxf(float(config.get("dot_interval", 1.0)), 0.1))
	statuses[status_id] = status
	_set_statuses(target, statuses)
	if config.has("marker_color"):
		target.set_meta(MARKER_META_KEY, config["marker_color"])


static func tick(target: Node, delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.has_meta(META_KEY):
		return
	var statuses := _statuses(target)
	var changed := false
	var expired: Array[String] = []
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		status["remaining"] = float(status.get("remaining", 0.0)) - delta
		if float(status.get("dot_damage", 0.0)) > 0.0 and target.has_method("take_damage"):
			var interval := maxf(float(status.get("dot_interval", 1.0)), 0.1)
			status["tick_left"] = float(status.get("tick_left", interval)) - delta
			while float(status["tick_left"]) <= 0.0 and float(status.get("remaining", 0.0)) > 0.0:
				status["tick_left"] = float(status["tick_left"]) + interval
				target.call("take_damage", float(status.get("dot_damage", 0.0)) * float(status.get("stacks", 1)))
		if float(status.get("remaining", 0.0)) <= 0.0:
			expired.append(str(status_id))
		else:
			statuses[status_id] = status
		changed = true
	for status_id in expired:
		statuses.erase(status_id)
	if changed:
		_set_statuses(target, statuses)


static func has_status(target: Node, status_id: String) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return _statuses(target).has(status_id)


static func snapshot(target: Node) -> Dictionary:
	return _statuses(target).duplicate(true)


static func damage_multiplier(target: Node) -> float:
	var multiplier := 1.0
	for status in _statuses(target).values():
		multiplier *= _stacked_multiplier(status, "damage_multiplier")
	return multiplier


static func damage_taken_multiplier(target: Node) -> float:
	var multiplier := 1.0
	for status in _statuses(target).values():
		multiplier *= _stacked_multiplier(status, "damage_taken_multiplier")
	return multiplier


static func speed_multiplier(target: Node) -> float:
	var multiplier := 1.0
	for status in _statuses(target).values():
		multiplier *= _stacked_multiplier(status, "speed_multiplier")
	return clampf(multiplier, 0.25, 1.75)


static func _stacked_multiplier(status: Dictionary, key: String) -> float:
	if not status.has(key):
		return 1.0
	var value := float(status.get(key, 1.0))
	var stacks := maxi(int(status.get("stacks", 1)), 1)
	if is_equal_approx(value, 1.0) or stacks <= 1:
		return value
	return maxf(0.0, 1.0 + (value - 1.0) * float(stacks))


static func _statuses(target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target) or not target.has_meta(META_KEY):
		return {}
	var raw = target.get_meta(META_KEY)
	return raw if raw is Dictionary else {}


static func _set_statuses(target: Node, statuses: Dictionary) -> void:
	if statuses.is_empty():
		target.remove_meta(META_KEY)
		if target.has_meta(MARKER_META_KEY):
			target.remove_meta(MARKER_META_KEY)
		return
	target.set_meta(META_KEY, statuses)
