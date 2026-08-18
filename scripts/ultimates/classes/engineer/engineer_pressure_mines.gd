extends RefCounted

const PROFILE_ID := "weapon_ultimate.profile.engineer.engineer_pressure_mines"
const EXECUTOR_ID := "weapon_ultimate.executor.engineer.engineer_pressure_mines"
const SELF_PATH := "res://scripts/ultimates/classes/engineer/engineer_pressure_mines.gd"
const EFFECT_SCENE := "res://scripts/ultimates/classes/engineer/engineer_pressure_mines.tscn"
const DEVICE_SCENE := preload(
	"res://scripts/ultimates/classes/engineer/temporary_engineer_device.tscn"
)
const DEVICE_TEXTURE := preload(
	"res://assets/sprites/effects/ultimates/engineer/engineer_smart_mine.png"
)


static func parameter_contract() -> Dictionary:
	return {
		"mine_count": {"type": "integer", "minimum": 1, "maximum": 16},
		"inner_radius": {"type": "number", "minimum": 0.0},
		"outer_radius": {"type": "number", "minimum": 0.0},
		"seed": {"type": "integer"},
		"arm_delay": {"type": "number", "minimum": 0.0},
		"finale_delay": {"type": "number", "minimum": 0.0},
		"finale_interval": {"type": "number", "minimum": 0.01},
		"finale_tail": {"type": "number", "minimum": 0.0},
		"trigger_radius": {"type": "number", "minimum": 1.0},
		"chain_radius": {"type": "number", "minimum": 1.0},
		"chain_count": {"type": "integer", "minimum": 0},
		"blast_radius": {"type": "number", "minimum": 1.0},
		"damage": {"type": "number", "minimum": 0.0},
		"chain_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"target_cap_flat": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var count: int = activation.param_int("mine_count", 16)
	var inner: float = activation.param_float("inner_radius", 80.0)
	var outer: float = activation.param_float("outer_radius", 260.0)
	var arm_delay: float = activation.param_float("arm_delay", 0.7)
	var finale_delay: float = activation.param_float("finale_delay", 1.7)
	if outer < inner or finale_delay < arm_delay:
		return 0.0
	var points: PackedVector2Array = activation.pattern_points(activation.origin(), "seeded_annulus", {
		"count": count,
		"inner_radius": inner,
		"outer_radius": outer,
		"seed": activation.param_int("seed", 1466),
	})
	var devices: Array[Node] = activation.deploy_temporary(DEVICE_SCENE, {}, count)
	if points.size() != count or devices.size() != count:
		return 0.0
	decorate_and_place(devices, points)
	var presentation = activation.spawn(EFFECT_SCENE)
	if presentation is Node2D:
		(presentation as Node2D).global_position = activation.origin()
	if not activation.set_per_target_damage_cap(
		activation.param_float("target_cap_fraction", 0.65),
		activation.param_float("target_cap_flat", 0.0)
	):
		return 0.0
	var state := {
		"nodes": devices,
		"points": points,
		"detonated": {},
		"trace": [],
	}
	activation.set_primitive_state({"engineer_mine_state": state})
	activation.present(EXECUTOR_ID + ".seed", {
		"position": activation.origin(), "radius": outer, "shape": "ring_pulse",
	})
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(arm_delay)
	tween.tween_callback(Callable(script, "smart_chain").bind(activation, state))
	if finale_delay > arm_delay:
		tween.tween_interval(finale_delay - arm_delay)
	var order := outer_to_inner_order(points, activation.origin())
	var interval: float = activation.param_float("finale_interval", 0.10)
	for position in order.size():
		if position > 0:
			tween.tween_interval(interval)
		tween.tween_callback(
			Callable(script, "detonate_mine").bind(
				activation,
				state,
				int(order[position]),
				activation.scaled_damage("damage", 1.20),
				activation.param_float("blast_radius", 135.0),
				"finale",
				false
			)
		)
	var tail: float = activation.param_float("finale_tail", 0.80)
	if tail > 0.0:
		tween.tween_interval(tail)
	return finale_delay + interval * float(maxi(order.size() - 1, 0)) + tail


static func smart_chain(activation, state: Dictionary) -> void:
	if activation == null or activation.is_finished():
		return
	var points := state.get("points", PackedVector2Array()) as PackedVector2Array
	var trigger_index := -1
	for index in points.size():
		if not activation.targets(
			points[index], activation.param_float("trigger_radius", 90.0), 1
		).is_empty():
			trigger_index = index
			break
	if trigger_index < 0:
		return
	detonate_mine(
		activation,
		state,
		trigger_index,
		activation.scaled_damage("damage", 1.20),
		activation.param_float("blast_radius", 135.0),
		"smart",
		false
	)
	var neighbors: Array[int] = []
	for index in points.size():
		if index != trigger_index \
				and points[index].distance_to(points[trigger_index]) \
				<= activation.param_float("chain_radius", 155.0):
			neighbors.append(index)
	neighbors.sort_custom(func(left: int, right: int) -> bool:
		return points[left].distance_squared_to(points[trigger_index]) \
			< points[right].distance_squared_to(points[trigger_index])
	)
	var chain_count := mini(neighbors.size(), activation.param_int("chain_count", 2))
	for rank in chain_count:
		detonate_mine(
			activation,
			state,
			neighbors[rank],
			activation.scaled_damage("damage", 1.20) \
				* pow(activation.param_float("chain_falloff", 0.65), rank + 1),
			activation.param_float("blast_radius", 135.0),
			"chain",
			true
		)


static func detonate_mine(
	activation,
	state: Dictionary,
	index: int,
	damage: float,
	blast_radius: float,
	phase: String,
	secondary: bool
) -> void:
	if activation == null or activation.is_finished():
		return
	var detonated := state.get("detonated", {}) as Dictionary
	var points := state.get("points", PackedVector2Array()) as PackedVector2Array
	if index < 0 or index >= points.size() or detonated.has(index):
		return
	detonated[index] = true
	(state.get("trace", []) as Array).append({"phase": phase, "index": index, "position": points[index]})
	for raw_target in activation.targets(points[index], blast_radius, 0):
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(
				target,
				damage,
				{"source": "engineer_smart_mine", "phase": phase},
				"mine:%d" % index,
				secondary
			)
	activation.present(EXECUTOR_ID + "." + phase, {
		"position": points[index], "radius": blast_radius, "shape": "orb_burst",
	})
	var nodes := state.get("nodes", []) as Array
	if index < nodes.size():
		var node := nodes[index] as Node
		if node != null and is_instance_valid(node):
			node.queue_free()


static func outer_to_inner_order(points: PackedVector2Array, center: Vector2) -> Array[int]:
	var order: Array[int] = []
	for index in points.size():
		order.append(index)
	order.sort_custom(func(left: int, right: int) -> bool:
		var left_distance := points[left].distance_squared_to(center)
		var right_distance := points[right].distance_squared_to(center)
		return left_distance > right_distance \
			if not is_equal_approx(left_distance, right_distance) else left < right
	)
	return order


static func decorate_and_place(devices: Array[Node], points: PackedVector2Array) -> void:
	for index in mini(devices.size(), points.size()):
		var device := devices[index] as Node2D
		if device == null or not is_instance_valid(device):
			continue
		device.global_position = points[index]
		device.set_meta("engineer_ultimate_device", "mine")
		var sprite := Sprite2D.new()
		sprite.texture = DEVICE_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * 0.34
		sprite.modulate.a = 0.88
		device.add_child(sprite)
