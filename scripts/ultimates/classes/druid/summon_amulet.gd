extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.druid.summon_amulet"
const EXECUTOR_ID := "weapon_ultimate.executor.druid.summon_amulet"
const EFFECT_SCENE := "res://scripts/ultimates/classes/druid/summon_amulet.tscn"

var ultimate_damage_sink: Callable = Callable()
var pack_count_for_tests := 0
var hunt_waves_for_tests := 0

var _activation = null


## Ultimate Direction v2 (FAN-2944): the Wild Hunt reaches every live enemy on
## the map — every beast sweeps the whole arena on the stampede and on every
## hunt wave, so no count-shaped parameter bounds the reach. The splash radius
## remains a presentation/attribution detail; it does not limit primary reach.
static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"hunt_interval": {"type": "number", "minimum": 0.01},
		"hunt_waves": {"type": "integer", "minimum": 1},
		"pack_count": {"type": "integer", "minimum": 1, "maximum": 8},
		"hunt_range": {"type": "number", "minimum": 1.0},
		"hunt_splash_radius": {"type": "number", "minimum": 0.0},
		"splash_damage_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"stampede_damage": {"type": "number", "minimum": 0.0},
		"hunt_damage": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.85)
	var hunt_interval: float = activation.param_float("hunt_interval", 0.75)
	var waves: int = activation.param_int("hunt_waves", 6)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "stampede"))
	for wave in waves:
		tween.tween_interval(hunt_interval)
		tween.tween_callback(Callable(effect, "hunt").bind(wave))
	var elapsed: float = release_delay + hunt_interval * float(waves)
	var lifetime: float = activation.param_float("lifetime", 6.6)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	pack_count_for_tests = activation.param_int("pack_count", 8)


func stampede() -> void:
	if _activation == null or _activation.is_finished():
		return
	var targets := _live_targets()
	var splash_targets: Array = _activation.select_targets(_activation.origin(), INF, 0, "nearest")
	var splash_radius: float = _activation.param_float("hunt_splash_radius", 160.0)
	var splash_index: Dictionary = _splash_index(splash_targets, splash_radius)
	var splash_neighbors: Dictionary = {}
	for beast in pack_count_for_tests:
		for target in targets:
			_strike(target, _activation.scaled_damage("stampede_damage", 7.0),
				"wild_hunt:stampede:%d:%d" % [beast, target.get_instance_id()],
				{"ultimate_mechanic": "wild_hunt_stampede", "beast": beast},
				splash_index, splash_radius, splash_neighbors)
	_activation.present(EXECUTOR_ID + ".stampede", {
		"position": _activation.origin(), "radius": _activation.param_float("hunt_range", 560.0),
		"shape": "ring_pulse",
	})


func hunt(wave: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	hunt_waves_for_tests += 1
	var targets := _live_targets()
	var splash_targets: Array = _activation.select_targets(_activation.origin(), INF, 0, "nearest")
	var splash_radius: float = _activation.param_float("hunt_splash_radius", 160.0)
	var splash_index: Dictionary = _splash_index(splash_targets, splash_radius)
	var splash_neighbors: Dictionary = {}
	for beast in pack_count_for_tests:
		for target in targets:
			_strike(target, _activation.scaled_damage("hunt_damage", 2.5),
				"wild_hunt:hunt:%d:%d:%d" % [wave, beast, target.get_instance_id()],
				{"ultimate_mechanic": "wild_hunt_priority", "wave": wave, "beast": beast},
				splash_index, splash_radius, splash_neighbors)


## Every live enemy on the map, re-read on each wave so enemies that spawn or
## die during the hunt stay correctly covered.
func _live_targets() -> Array:
	var live: Array = []
	if _activation == null:
		return live
	for raw_target in _activation.select_targets(_activation.origin(), INF, 0, "highest_hp"):
		var target := raw_target as Node
		if target != null and is_instance_valid(target) \
				and (target.get("health") == null or float(target.get("health")) > 0.0):
			live.append(target)
	return live


func _strike(
	target: Node,
	amount: float,
	event_id: String,
	feedback: Dictionary,
	splash_index: Dictionary,
	splash_radius: float,
	splash_neighbors: Dictionary
) -> void:
	_deal(target, amount, event_id, feedback)
	var anchor := target as Node2D
	if anchor == null:
		return
	var target_id := target.get_instance_id()
	if not splash_neighbors.has(target_id):
		splash_neighbors[target_id] = _neighbors_for(anchor, splash_index, splash_radius)
	var splash_feedback := feedback.duplicate(true)
	splash_feedback["ultimate_mechanic"] = "wild_hunt_splash"
	for raw_neighbor in splash_neighbors[target_id]:
		var neighbor := raw_neighbor as Node
		var neighbor_anchor := neighbor as Node2D
		if neighbor_anchor == null or neighbor == target or not is_instance_valid(neighbor):
			continue
		_deal(neighbor, amount * _activation.param_float("splash_damage_ratio", 0.65),
			"%s:splash:%d" % [event_id, neighbor.get_instance_id()], splash_feedback, true)


func _splash_index(candidates: Array, radius: float) -> Dictionary:
	var index: Dictionary = {}
	var cell_size := maxf(radius, 0.001)
	for raw_candidate in candidates:
		var candidate := raw_candidate as Node2D
		if candidate == null or not is_instance_valid(candidate):
			continue
		var cell := _splash_cell(candidate.global_position, cell_size)
		var bucket: Array = index.get(cell, [])
		bucket.append(candidate)
		index[cell] = bucket
	return index


func _splash_cell(position: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func _neighbors_for(anchor: Node2D, index: Dictionary, radius: float) -> Array:
	var neighbors: Array = []
	var radius_squared := radius * radius
	var cell_size := maxf(radius, 0.001)
	var cell := _splash_cell(anchor.global_position, cell_size)
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			var bucket: Array = index.get(Vector2i(x, y), [])
			for candidate in bucket:
				if candidate == anchor or not is_instance_valid(candidate):
					continue
				if anchor.global_position.distance_squared_to(candidate.global_position) <= radius_squared:
					neighbors.append(candidate)
	return neighbors


func _deal(
	target: Node, amount: float, event_id: String, feedback: Dictionary, secondary := false
) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_activation = null
