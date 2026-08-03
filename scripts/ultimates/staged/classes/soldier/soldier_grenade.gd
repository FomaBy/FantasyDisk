extends RefCounted

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.soldier.soldier_grenade"
const EXECUTOR_ID := "weapon_ultimate.executor.soldier.soldier_grenade"
const SELF_PATH := "res://scripts/ultimates/staged/classes/soldier/soldier_grenade.gd"
const GRENADE_SCENE := "res://scripts/ultimates/staged/classes/soldier/temporary_soldier_grenade.tscn"
const TARGET_KEY := "soldier_grenade_armed"


static func parameter_contract() -> Dictionary:
	return {
		"aim_range": {"type": "number", "minimum": 0.01},
		"grenade_count": {"type": "integer", "minimum": 1, "maximum": 16},
		"inner_radius": {"type": "number", "minimum": 0.0},
		"outer_radius": {"type": "number", "minimum": 0.0},
		"seed": {"type": "integer"},
		"probe_radius": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 1},
		"fuse_time": {"type": "number", "minimum": 0.0},
		"chain_interval": {"type": "number", "minimum": 0.01},
		"blast_radius": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"crater_delay": {"type": "number", "minimum": 0.0},
		"crater_radius": {"type": "number", "minimum": 0.0},
		"crater_ticks": {"type": "integer", "minimum": 1},
		"crater_interval": {"type": "number", "minimum": 0.05},
		"crater_damage": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.1},
	}


## The shared composition captures one aim, lays out one deterministic seven-
## point annulus and atomically deploys seven activation-owned nodes. Class-
## local callbacks only add the outside-in fuse order and crater cadence.
static func execute(activation) -> float:
	var package_params: Dictionary = activation.params
	var count: int = activation.param_int("grenade_count", 7)
	var lifetime: float = activation.param_float("lifetime", 8.4)
	var composition := Library.normalize_params(Library.COMPOSITION_ID, {
		"steps": [
			{"at": 0.0, "primitive_id": "aim_context", "params": {
				"max_range": activation.param_float("aim_range", 720.0),
				"target_mode": "host_aim",
			}},
			{"at": 0.0, "primitive_id": "pattern_geometry", "params": {
				"center": "target",
				"pattern": "seeded_annulus",
				"params": {
					"count": count,
					"inner_radius": activation.param_float("inner_radius", 90.0),
					"outer_radius": activation.param_float("outer_radius", 260.0),
					"seed": activation.param_int("seed", 1469),
				},
				"hit_radius": activation.param_float("probe_radius", 170.0),
				"target_limit": activation.param_int("target_limit", 26),
			}},
			{"at": 0.0, "family": "deploy_summon", "params": {
				"scene": GRENADE_SCENE,
				"count": count,
				"spawn_radius": 0.0,
				"lifetime": lifetime,
				"damage": 0.0,
				"properties": {},
			}},
		],
	})
	if not (composition["errors"] as Array).is_empty():
		return 0.0
	activation.params = composition["params"]
	var composition_duration := Library.execute(Library.COMPOSITION_ID, activation)
	activation.params = package_params
	if composition_duration <= 0.0:
		return 0.0
	var points = activation.primitive_value("points", PackedVector2Array())
	if not points is PackedVector2Array or (points as PackedVector2Array).size() != count:
		return 0.0
	var nodes := _last_spawns(activation, count)
	if nodes.size() != count:
		return 0.0
	_place(nodes, points as PackedVector2Array)
	var selected = activation.primitive_value("targets", [])
	if selected is Array and not (selected as Array).is_empty():
		Library.execute_primitive("stateful_target_ledger", activation, {
			"operation": "record",
			"target_source": "targets",
			"key": TARGET_KEY,
			"value": 1.0,
			"event_id": "soldier_grenade_arm",
		})
	var state := {
		"nodes": nodes,
		"points": points,
		"order": _outside_in(points as PackedVector2Array, activation.primitive_value("target", activation.origin())),
		"detonated": {},
	}
	activation.set_primitive_state({"soldier_grenade_state": state})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("fuse_time", 4.7))
	var order := state["order"] as Array
	for position in order.size():
		tween.tween_callback(Callable(script, "detonate").bind(activation, state, int(order[position])))
		if position + 1 < order.size():
			tween.tween_interval(activation.param_float("chain_interval", 0.3))
	tween.tween_interval(activation.param_float("crater_delay", 0.4))
	var crater_ticks: int = activation.param_int("crater_ticks", 3)
	for tick in crater_ticks:
		tween.tween_callback(Callable(script, "crater_tick").bind(activation, tick))
		if tick + 1 < crater_ticks:
			tween.tween_interval(activation.param_float("crater_interval", 0.5))
	var elapsed: float = activation.param_float("fuse_time", 4.7) \
		+ activation.param_float("chain_interval", 0.3) * float(maxi(order.size() - 1, 0)) \
		+ activation.param_float("crater_delay", 0.4) \
		+ activation.param_float("crater_interval", 0.5) * float(maxi(crater_ticks - 1, 0))
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


static func detonate(activation, state: Dictionary, index: int) -> void:
	if activation == null or activation.is_finished():
		return
	var points := state.get("points", PackedVector2Array()) as PackedVector2Array
	var detonated := state.get("detonated", {}) as Dictionary
	if index < 0 or index >= points.size() or detonated.has(index):
		return
	detonated[index] = true
	var event_id := "soldier_grenade_chain:%d" % index
	for raw_target in activation.targets(
		points[index], activation.param_float("blast_radius", 155.0), 0
	):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		if activation.consume_target_value(target, TARGET_KEY, event_id) == null:
			continue
		activation.deal_damage(
			target,
			activation.scaled_damage("damage", 24.0),
			{"ultimate_mechanic": "seven_grenade_chain", "grenade_index": index},
			"soldier_grenade_hit",
			false
		)
	activation.present(EXECUTOR_ID + ".detonate", {
		"position": points[index],
		"radius": activation.param_float("blast_radius", 155.0),
		"shape": "orb_burst",
	})
	var nodes := state.get("nodes", []) as Array
	if index < nodes.size():
		var node := nodes[index] as Node
		if node != null and is_instance_valid(node):
			node.queue_free()


static func crater_tick(activation, tick: int) -> void:
	if activation == null or activation.is_finished():
		return
	var center = activation.primitive_value("target")
	if not center is Vector2:
		return
	for raw_target in activation.targets(
		center as Vector2, activation.param_float("crater_radius", 190.0), 0
	):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(
				target,
				activation.scaled_damage("crater_damage", 1.2),
				{"ultimate_mechanic": "burning_crater", "tick": tick},
				"soldier_grenade_crater:%d" % tick,
				false
			)


static func _last_spawns(activation, count: int) -> Array[Node]:
	var result: Array[Node] = []
	var spawned: Array = activation.spawned_for_tests()
	for index in range(maxi(spawned.size() - count, 0), spawned.size()):
		var node := spawned[index] as Node
		if node != null and is_instance_valid(node):
			result.append(node)
	return result


static func _place(nodes: Array[Node], points: PackedVector2Array) -> void:
	for index in mini(nodes.size(), points.size()):
		var node := nodes[index] as Node2D
		if node != null and is_instance_valid(node):
			node.global_position = points[index]


static func _outside_in(points: PackedVector2Array, center) -> Array[int]:
	var order: Array[int] = []
	if not center is Vector2:
		return order
	for index in points.size():
		order.append(index)
	order.sort_custom(func(left: int, right: int) -> bool:
		var left_distance := points[left].distance_squared_to(center as Vector2)
		var right_distance := points[right].distance_squared_to(center as Vector2)
		return left_distance > right_distance \
			if not is_equal_approx(left_distance, right_distance) else left < right
	)
	return order
