extends RefCounted

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.soldier.soldier_rifle"
const EXECUTOR_ID := "weapon_ultimate.executor.soldier.soldier_rifle"


static func parameter_contract() -> Dictionary:
	return {
		"aim_range": {"type": "number", "minimum": 0.01},
		"search_radius": {"type": "number", "minimum": 0.0},
		"cluster_radius": {"type": "number", "minimum": 0.01},
		"corridor_half_width": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 1},
		"volley_count": {"type": "integer", "minimum": 1},
		"volley_interval": {"type": "number", "minimum": 0.01},
		"damage": {"type": "number", "minimum": 0.0},
		"recover_time": {"type": "number", "minimum": 0.01},
	}


## Aim, pick the first dense formation near that aim, cut one exact corridor
## through it, then let the accepted aimed-sequence family fire three beats at
## only those silhouettes. The generic composition owns ordering and aborts if
## any required world snapshot cannot be produced.
static func execute(activation) -> float:
	var package_params: Dictionary = activation.params
	var aim_range: float = activation.param_float("aim_range", 960.0)
	var composition := Library.normalize_params(Library.COMPOSITION_ID, {
		"steps": [
			{"at": 0.0, "primitive_id": "aim_context", "params": {
				"max_range": aim_range, "target_mode": "host_aim",
			}},
			{"at": 0.0, "primitive_id": "priority_target_selector", "params": {
				"center": "target",
				"radius": activation.param_float("search_radius", 280.0),
				"limit": 1,
				"priority": "densest_cluster",
				"hint": {"cluster_radius": activation.param_float("cluster_radius", 135.0)},
			}},
			{"at": 0.0, "primitive_id": "line_pierce_geometry", "params": {
				"start": "source",
				"direction": "source_to_target",
				"length": aim_range,
				"half_width": activation.param_float("corridor_half_width", 90.0),
				"limit": activation.param_int("target_limit", 3),
			}},
			{"at": 0.0, "family": "aimed_sequence", "params": {
				"radius": aim_range,
				"damage": activation.param_float("damage", 33.5),
				"shot_count": activation.param_int("volley_count", 3),
				"interval": activation.param_float("volley_interval", 1.35),
			}},
		],
	})
	if not (composition["errors"] as Array).is_empty():
		return 0.0
	activation.params = composition["params"]
	var sequence_duration := Library.execute(Library.COMPOSITION_ID, activation)
	activation.params = package_params
	if sequence_duration <= 0.0:
		return 0.0
	var recover_time: float = activation.param_float("recover_time", 5.6)
	var recovery: Tween = activation.track_tween()
	if recovery == null:
		return 0.0
	recovery.tween_interval(maxf(recover_time, sequence_duration))
	return maxf(recover_time, sequence_duration)
