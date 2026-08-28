extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/dark_mage/dark_wand/dark_wand_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.dark_mage.dark_wand"
const EXECUTOR_ID := "weapon_ultimate.executor.dark_mage.dark_wand"
const EFFECT_SCENE := "res://scripts/ultimates/classes/dark_mage/dark_wand.tscn"
const NODE_KEY := "dark_mage_vanishing_thread_ramp"

var ultimate_damage_sink: Callable = Callable()
var marked_count_for_tests := 0
var collapse_count_for_tests := 0

var _activation = null
var _nodes: Array = []
var _focus_target_id := 0
var _impacts: Node2D = null


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"release_delay": {"type": "number", "minimum": 0.0},
		"collapse_delay": {"type": "number", "minimum": 0.0},
		"base_collapse_damage": {"type": "number", "minimum": 0.0},
		"focus_collapse_bonus": {"type": "number", "minimum": 0.0},
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
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.65)
	):
		return 0.0
	var targets: Array = activation.select_targets(activation.origin(), INF, 0, "nearest")
	var aim: Dictionary = activation.aim_context(max_range)
	var focus_targets: Array = activation.select_targets(
		activation.origin(), INF, 1, "aimed", {"point": aim.get("target", activation.origin())}
	)
	var focus_target = focus_targets[0] as Node if not focus_targets.is_empty() else null
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets, focus_target)
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


func configure(activation, targets: Array, focus_target: Node = null) -> void:
	_activation = activation
	_nodes = targets.duplicate()
	_focus_target_id = focus_target.get_instance_id() if focus_target != null and is_instance_valid(focus_target) else 0
	global_position = activation.origin()


func mark_node(index: int) -> void:
	if _activation == null or _activation.is_finished() or index < 0 or index >= _nodes.size():
		return
	var target := _nodes[index] as Node2D
	if target == null or not is_instance_valid(target):
		return
	var ramp: float = 1.0
	if _nodes.size() > 1 and target.get_instance_id() == _focus_target_id:
		ramp += _activation.param_float("focus_collapse_bonus", 0.0)
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
	var victims: Array = []
	for index in _nodes.size():
		var target := _nodes[index] as Node
		if target == null or not is_instance_valid(target):
			continue
		var ramp: Variant = _activation.target_value(target, NODE_KEY, null)
		if not (ramp is float or ramp is int):
			continue
		collapse_count_for_tests += 1
		victims.append(target)
		_deal(
			target,
			_activation.scaled_damage("base_collapse_damage", 0.0) * float(ramp),
			"vanishing_collapse:%d" % index,
			false,
			{"ultimate_mechanic": "vanishing_collapse", "ramp": float(ramp), "node": index}
		)
	_play_impacts(victims)


func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	if _impacts == null:
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
	_impacts.play(VICTIM_FRAMES, victims, global_position)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_nodes.clear()
	_focus_target_id = 0
	_activation = null
