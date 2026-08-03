extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.dark_mage.dark_wand"
const EXECUTOR_ID := "weapon_ultimate.executor.dark_mage.dark_wand"
const EFFECT_SCENE := "res://scripts/ultimates/classes/dark_mage/dark_wand.tscn"
const NODE_KEY := "dark_mage_vanishing_thread_ramp"

var ultimate_damage_sink: Callable = Callable()
var marked_count_for_tests := 0
var collapse_count_for_tests := 0

var _activation = null
var _nodes: Array = []


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"half_width": {"type": "number", "minimum": 0.0},
		"chain_cap": {"type": "integer", "minimum": 1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"collapse_delay": {"type": "number", "minimum": 0.0},
		"base_collapse_damage": {"type": "number", "minimum": 0.0},
		"distinct_target_ramp": {"type": "number", "minimum": 0.0},
		"per_target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"lifetime": {"type": "number", "minimum": 0.1},
	}


static func execute(activation) -> float:
	var max_range: float = activation.param_float("max_range", 760.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": max_range,
		"target_mode": "host_aim",
	}):
		return 0.0
	if not Library.execute_primitive("line_pierce_geometry", activation, {
		"start": "source",
		"direction": "aim",
		"length": max_range,
		"half_width": activation.param_float("half_width", 72.0),
		"limit": activation.param_int("chain_cap", 10),
	}):
		return 0.0
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.65)
	):
		return 0.0
	var targets = activation.primitive_value("targets", [])
	if not targets is Array:
		targets = []
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets as Array)
	var aim = activation.aim_context(max_range)
	activation.present("weapon_ultimate.phase.dark_mage.dark_wand.execute", {
		"from": activation.origin(),
		"to": aim.get("target", activation.origin()),
		"position": aim.get("target", activation.origin()),
		"shape": "beam",
	})
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.28)
	tween.tween_interval(release_delay)
	for index in (targets as Array).size():
		tween.tween_callback(Callable(effect, "mark_node").bind(index))
	tween.tween_interval(activation.param_float("collapse_delay", 0.34))
	tween.tween_callback(Callable(effect, "collapse"))
	var elapsed: float = release_delay + activation.param_float("collapse_delay", 0.34)
	var lifetime: float = activation.param_float("lifetime", 3.85)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation, targets: Array) -> void:
	_activation = activation
	_nodes = targets.duplicate()
	global_position = activation.origin()


func mark_node(index: int) -> void:
	if _activation == null or _activation.is_finished() or index < 0 or index >= _nodes.size():
		return
	var target := _nodes[index] as Node2D
	if target == null or not is_instance_valid(target):
		return
	var ramp: float = 1.0 + _activation.param_float("distinct_target_ramp", 0.14) * float(index)
	if _activation.record_target_value(target, NODE_KEY, ramp, "vanishing_mark:%d" % index):
		marked_count_for_tests += 1
		_activation.present("weapon_ultimate.phase.dark_mage.dark_wand.active", {
			"position": target.global_position,
			"radius": 38.0,
			"shape": "orb_burst",
		})


func collapse() -> void:
	if _activation == null or _activation.is_finished():
		return
	for index in _nodes.size():
		var target := _nodes[index] as Node
		if target == null or not is_instance_valid(target):
			continue
		var ramp: Variant = _activation.target_value(target, NODE_KEY, null)
		if not (ramp is float or ramp is int):
			continue
		collapse_count_for_tests += 1
		_deal(
			target,
			_activation.scaled_damage("base_collapse_damage", 0.0) * float(ramp),
			"vanishing_collapse:%d" % index,
			false,
			{"ultimate_mechanic": "vanishing_collapse", "ramp": float(ramp), "node": index}
		)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_nodes.clear()
	_activation = null
