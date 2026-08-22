extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.biologist.biologist_symbiote_seed"
const EXECUTOR_ID := "weapon_ultimate.executor.biologist.biologist_symbiote_seed"
const EFFECT_SCENE := "res://scripts/ultimates/classes/biologist/biologist_symbiote_seed.tscn"
const SUMMON_GROUP := "biologist_ultimate_symbiotes"

var ultimate_damage_sink: Callable = Callable()
var owner_node: Node = null
var larva_count_for_tests := 0
var terminal_burst_for_tests := false

var _activation = null
var _leased_statuses: Array[Dictionary] = []
var _targets: Array = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"max_range": {"type": "number", "minimum": 0.01},
		"release_delay": {"type": "number", "minimum": 0.0},
		"active_delay": {"type": "number", "minimum": 0.0},
		"hatch_delay": {"type": "number", "minimum": 0.0},
		"pull_strength": {"type": "number", "minimum": 0.0},
		"root_duration": {"type": "number", "minimum": 0.1},
		"slow_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"impact_damage": {"type": "number", "minimum": 0.0},
		"larva_count": {"type": "integer", "minimum": 1},
		"larva_interval": {"type": "number", "minimum": 0.01},
		"larva_damage": {"type": "number", "minimum": 0.0},
		"hatch_damage": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": activation.param_float("max_range", 700.0),
		"target_mode": "host_aim",
	}):
		return 0.0
	if not Library.execute_primitive("control_resistance_policy", activation, _control_policy()):
		return 0.0
	if not Library.execute_primitive("summon_interaction_contract", activation, {
		"group_id": SUMMON_GROUP,
		"temporary_cap": 1,
		"snapshot_properties": [],
		"setup": {},
	}):
		return 0.0
	var target_point = activation.primitive_value("target")
	if not target_point is Vector2:
		return 0.0
	var pod = activation.spawn(EFFECT_SCENE)
	if pod == null or not pod.has_method("configure"):
		return 0.0
	if pod is Node2D:
		(pod as Node2D).global_position = target_point as Vector2
	pod.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 1.15)
	var active_delay: float = activation.param_float("active_delay", 1.75)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(pod, "pull_and_root"))
	if active_delay > release_delay:
		tween.tween_interval(active_delay - release_delay)
	var larvae: int = activation.param_int("larva_count", 6)
	for larva in larvae:
		if larva > 0:
			tween.tween_interval(activation.param_float("larva_interval", 0.6))
		tween.tween_callback(Callable(pod, "launch_larva").bind(larva))
	var elapsed: float = active_delay + activation.param_float("larva_interval", 0.6) * float(larvae - 1)
	var hatch_delay: float = activation.param_float("hatch_delay", 8.1)
	if hatch_delay > elapsed:
		tween.tween_interval(hatch_delay - elapsed)
	tween.tween_callback(Callable(pod, "hatch"))
	var lifetime: float = activation.param_float("lifetime", 9.0)
	if lifetime > hatch_delay:
		tween.tween_interval(lifetime - hatch_delay)
	return lifetime


static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 1.0,
			"duration_multiplier": 1.0,
			"allow_movement_lock": true,
			"allow_execute": true,
		},
		"epic": {
			"displacement_multiplier": 0.25,
			"duration_multiplier": 0.45,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.2,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
	}


func configure(activation) -> void:
	_activation = activation
	owner_node = activation.host
	add_to_group(SUMMON_GROUP)


func pull_and_root() -> void:
	if _activation == null or _activation.is_finished():
		return
	_targets = _activation.select_targets(
		global_position, INF, 0, "nearest"
	)
	for raw_target in _targets:
		if raw_target == null or not is_instance_valid(raw_target):
			continue
		var target := raw_target as Node2D
		if target == null:
			continue
		var toward := global_position - target.global_position
		var impulse: Vector2 = toward.normalized() * _activation.param_float("pull_strength", 520.0) \
			if toward.length_squared() > 0.001 else Vector2.ZERO
		var status_id := "biologist_ultimate_symbiote_%d" % get_instance_id()
		var applied: Dictionary = _activation.apply_control(
			target,
			impulse,
			status_id,
			{
				"duration": _activation.param_float("root_duration", 4.5),
				"movement_locked": true,
				"speed_multiplier": _activation.param_float("slow_multiplier", 0.5),
				"symbiote_root": true,
			}
		)
		if bool(applied.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})
		_deal(
			target,
			_activation.scaled_damage("impact_damage", 0.0),
			"symbiote_impact",
			false,
			{"ultimate_mechanic": "symbiote_impact"}
		)


func launch_larva(index: int) -> void:
	larva_count_for_tests += 1
	if _activation == null or _activation.is_finished():
		return
	var live_targets: Array = []
	for raw_target in _targets:
		if raw_target == null or not is_instance_valid(raw_target):
			continue
		var target := raw_target as Node2D
		if target != null \
				and (target.get("health") == null or float(target.get("health")) > 0.0):
			live_targets.append(target)
	if live_targets.is_empty():
		live_targets = _activation.select_targets(
			global_position, INF, 0, "highest_hp"
		)
	if live_targets.is_empty():
		return
	var target := live_targets[index % live_targets.size()] as Node
	_deal(
		target,
		_activation.scaled_damage("larva_damage", 0.0),
		"symbiote_larva:%d" % index,
		false,
		{"ultimate_mechanic": "larval_projectile", "larva": index}
	)


func hatch() -> void:
	terminal_burst_for_tests = true
	if _activation == null or _activation.is_finished():
		return
	for raw_target in _activation.select_targets(
		global_position, INF, 0, "nearest"
	):
		if raw_target == null or not is_instance_valid(raw_target):
			continue
		var target := raw_target as Node
		if target == null:
			continue
		_deal(
			target,
			_activation.scaled_damage("hatch_damage", 0.0),
			"symbiote_hatch",
			false,
			{"ultimate_mechanic": "terminal_hatch"}
		)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_activation = null


func _remove_leased_status(lease: Dictionary) -> void:
	var raw_target = lease.get("target")
	if raw_target == null or not is_instance_valid(raw_target):
		return
	var target := raw_target as Node
	if target == null or not target.has_meta(StatusEffects.META_KEY):
		return
	var statuses = target.get_meta(StatusEffects.META_KEY)
	if not statuses is Dictionary:
		return
	var owned := (statuses as Dictionary).duplicate(true)
	owned.erase(str(lease.get("status_id", "")))
	if owned.is_empty():
		target.remove_meta(StatusEffects.META_KEY)
	else:
		target.set_meta(StatusEffects.META_KEY, owned)
