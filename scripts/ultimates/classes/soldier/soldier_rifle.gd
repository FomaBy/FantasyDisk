extends RefCounted

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.soldier.soldier_rifle"
const EXECUTOR_ID := "weapon_ultimate.executor.soldier.soldier_rifle"


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"search_radius": {"type": "number", "minimum": 0.0},
		"cluster_radius": {"type": "number", "minimum": 0.01},
		"corridor_half_width": {"type": "number", "minimum": 0.0},
		"volley_count": {"type": "integer", "minimum": 1},
		"volley_interval": {"type": "number", "minimum": 0.01},
		"damage": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.01},
	}


## Aim, pick the first dense formation near that aim, cut one exact corridor
## through it, then let the accepted aimed-sequence family fire three beats at
## only those silhouettes. Every step shares one activation-owned lifecycle
## tween so cleanup cannot race a parallel nominal timer.
static func execute(activation) -> float:
	var package_params: Dictionary = activation.params
	var aim_range: float = activation.param_float("max_range", 960.0)
	activation.composition_step("aim_context")
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": aim_range, "target_mode": "host_aim",
	}):
		return 0.0
	activation.composition_step("priority_target_selector")
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "target",
		"radius": activation.param_float("search_radius", 280.0),
		"limit": 1,
		"priority": "densest_cluster",
		"hint": {"cluster_radius": activation.param_float("cluster_radius", 135.0)},
	}):
		return 0.0
	activation.composition_step("line_pierce_geometry")
	if not Library.execute_primitive("line_pierce_geometry", activation, {
		"start": "source",
		"direction": "source_to_target",
		"length": aim_range,
		"half_width": activation.param_float("corridor_half_width", 99999.0),
		"limit": 0,
	}):
		return 0.0
	var sequence := Library.normalize_params("aimed_sequence", {
		"radius": aim_range,
		"damage": activation.param_float("damage", 33.5),
		"shot_count": activation.param_int("volley_count", 3),
		"interval": activation.param_float("volley_interval", 1.35),
	})
	if not (sequence["errors"] as Array).is_empty():
		return 0.0
	activation.composition_step("aimed_sequence")
	activation.params = sequence["params"]
	var sequence_duration := Library.execute("aimed_sequence", activation)
	activation.params = package_params
	if sequence_duration <= 0.0:
		return 0.0
	var lifetime: float = activation.param_float("lifetime", 5.6)
	var lifecycle: Tween = activation.last_tween()
	if lifecycle == null:
		return 0.0
	if lifetime > sequence_duration:
		lifecycle.tween_interval(lifetime - sequence_duration)
	return maxf(lifetime, sequence_duration)
