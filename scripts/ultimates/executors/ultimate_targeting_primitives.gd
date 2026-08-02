extends RefCounted

## The four zero-duration targeting/geometry steps used by ordered composition.
## Admission lives in UltimateExecutorLibrary; this file only applies already
## normalized parameters to one activation-owned context.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const AIM_CONTEXT := "aim_context"
const PRIORITY_TARGET_SELECTOR := "priority_target_selector"
const LINE_PIERCE_GEOMETRY := "line_pierce_geometry"
const PATTERN_GEOMETRY := "pattern_geometry"


static func execute(primitive_id: String, activation: Activation, params: Dictionary) -> bool:
	match primitive_id:
		AIM_CONTEXT:
			return _aim_context(activation, params)
		PRIORITY_TARGET_SELECTOR:
			return _priority_targets(activation, params)
		LINE_PIERCE_GEOMETRY:
			return _line_targets(activation, params)
		PATTERN_GEOMETRY:
			return _pattern_targets(activation, params)
	return false


static func _aim_context(activation: Activation, params: Dictionary) -> bool:
	var source := activation.origin()
	var target := Vector2.ZERO
	var direction := Vector2.ZERO
	match str(params["target_mode"]):
		"host_aim":
			var snapshot := activation.aim_context(float(params["max_range"]))
			if snapshot.is_empty():
				return false
			source = snapshot["source"]
			target = snapshot["target"]
			direction = snapshot["direction"]
		"nearest_target":
			var targets := activation.select_targets(
				source, float(params["max_range"]), 1, "nearest"
			)
			if targets.is_empty() or not targets[0] is Node2D:
				return false
			target = (targets[0] as Node2D).global_position
			direction = (target - source).normalized()
		_:
			return false
	if direction.length_squared() <= 0.001:
		return false
	activation.set_primitive_state({
		"source": source,
		"target": target,
		"direction": direction,
	})
	return true


static func _priority_targets(activation: Activation, params: Dictionary) -> bool:
	var center = activation.primitive_value(str(params["center"]))
	if not center is Vector2:
		return false
	var hint: Dictionary = (params["hint"] as Dictionary).duplicate(true)
	if str(params["priority"]) == "aimed":
		var aimed = activation.primitive_value("target")
		if not aimed is Vector2:
			return false
		hint["point"] = aimed
	var selected := activation.select_targets(
		center as Vector2,
		float(params["radius"]),
		int(params["limit"]),
		str(params["priority"]),
		hint
	)
	activation.set_primitive_targets(selected)
	if not selected.is_empty() and selected[0] is Node2D:
		activation.set_primitive_state({
			"primary_target": selected[0],
			"target": (selected[0] as Node2D).global_position,
		})
	return true


static func _line_targets(activation: Activation, params: Dictionary) -> bool:
	var start = activation.primitive_value(str(params["start"]))
	if not start is Vector2:
		return false
	var direction := Vector2.ZERO
	match str(params["direction"]):
		"aim":
			var aimed = activation.primitive_value("direction")
			if aimed is Vector2:
				direction = aimed
		"source_to_target":
			var source = activation.primitive_value("source")
			var target = activation.primitive_value("target")
			if source is Vector2 and target is Vector2:
				direction = (target as Vector2) - (source as Vector2)
	if direction.length_squared() <= 0.001:
		return false
	var selected := activation.targets_in_corridor(
		start as Vector2,
		direction,
		float(params["length"]),
		float(params["half_width"]),
		int(params["limit"])
	)
	activation.set_primitive_targets(selected)
	return true


static func _pattern_targets(activation: Activation, params: Dictionary) -> bool:
	var center = activation.primitive_value(str(params["center"]))
	if not center is Vector2:
		return false
	var points := activation.pattern_points(
		center as Vector2, str(params["pattern"]), params["params"] as Dictionary
	)
	if points.is_empty():
		return false
	var selected := activation.targets_at_points(
		points, float(params["hit_radius"]), int(params["target_limit"])
	)
	activation.set_primitive_state({"points": points})
	activation.set_primitive_targets(selected)
	return true
