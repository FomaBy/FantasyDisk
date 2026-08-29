extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.ranger.hunter_trap"
const EXECUTOR_ID := "weapon_ultimate.executor.ranger.hunter_trap"
const EFFECT_SCENE := "res://scripts/ultimates/classes/ranger/hunter_trap.tscn"

var ultimate_damage_sink: Callable = Callable()
var ring_count_for_tests := 0
var closure_count_for_tests := 0
var jaw_target_for_tests: Node = null

var _activation = null
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"windup_delay": {"type": "number", "minimum": 0.0},
		"ring_interval": {"type": "number", "minimum": 0.01},
		"ring_count": {"type": "integer", "minimum": 1},
		"closure_delay": {"type": "number", "minimum": 0.0},
		"max_range": {"type": "number", "minimum": 1.0},
		"outer_radius": {"type": "number", "minimum": 1.0},
		"ring_shrink": {"type": "number", "minimum": 0.01, "maximum": 1.0},
		"snap_damage": {"type": "number", "minimum": 0.0},
		"net_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"closure_damage": {"type": "number", "minimum": 0.0},
		"lock_duration": {"type": "number", "minimum": 0.1},
		"pull_force": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": activation.param_float("max_range", 520.0),
		"target_mode": "host_aim",
	}):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var windup: float = activation.param_float("windup_delay", 0.85)
	var interval: float = activation.param_float("ring_interval", 0.95)
	var rings: int = activation.param_int("ring_count", 3)
	tween.tween_interval(windup)
	for ring in rings:
		tween.tween_callback(Callable(effect, "snap").bind(ring))
		tween.tween_interval(interval)
	var elapsed: float = windup + interval * float(rings)
	var closure_delay: float = activation.param_float("closure_delay", 4.6)
	if closure_delay > elapsed:
		tween.tween_interval(closure_delay - elapsed)
		elapsed = closure_delay
	tween.tween_callback(Callable(effect, "close_net"))
	var lifetime: float = activation.param_float("lifetime", 5.35)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


## The trap pins what it can hold: normals stay locked in the jaws, resistant
## tiers keep only a shortened pull and slow.
static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": true, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": 0.45, "duration_multiplier": 0.45,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.2, "duration_multiplier": 0.2,
			"allow_movement_lock": false, "allow_execute": false,
		},
	}


func configure(activation) -> void:
	_activation = activation
	var anchor = activation.primitive_value("target")
	global_position = anchor as Vector2 if anchor is Vector2 else activation.origin()


## Ring `index` closes one step further inward. The body nearest the trap centre
## is the one the jaws actually bite; everything else inside keeps only the
## `net_ratio` share carried by the chain between the jaws.
func snap(index: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	ring_count_for_tests += 1
	var radius: float = _activation.param_float("outer_radius", 320.0) \
		* pow(_activation.param_float("ring_shrink", 0.72), float(index))
	_bite(
		_caught(radius),
		_activation.scaled_damage("snap_damage", 54.0),
		"grand_trap:snap:%d" % index,
		{"ultimate_mechanic": "trap_jaw_snap", "ring": index},
		true
	)
	_activation.present(EXECUTOR_ID + ".snap", {
		"position": global_position, "radius": radius, "shape": "jaw_ring",
	})


## The chain net spans the whole trap once, so the closure reaches the outer
## ring again instead of only what the last jaw still held.
func close_net() -> void:
	if _activation == null or _activation.is_finished():
		return
	closure_count_for_tests += 1
	_bite(
		_caught(_activation.param_float("outer_radius", 320.0)),
		_activation.scaled_damage("closure_damage", 27.0),
		"grand_trap:closure",
		{"ultimate_mechanic": "trap_net_closure"},
		false
	)
	_activation.present(EXECUTOR_ID + ".closure", {
		"position": global_position,
		"radius": _activation.param_float("outer_radius", 320.0),
		"shape": "chain_net",
	})


func _caught(radius: float) -> Array:
	return _activation.select_targets(
		global_position, INF, 0, "nearest"
	)


func _bite(
	caught: Array, amount: float, event_id: String, feedback: Dictionary, lock: bool
) -> void:
	var net_ratio: float = _activation.param_float("net_ratio", 0.11)
	for index in caught.size():
		var target := caught[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var payload := feedback.duplicate(true)
		payload["ultimate_mechanic"] = str(feedback.get("ultimate_mechanic", "")) \
			if index == 0 else "trap_chain_net"
		_deal(
			target,
			amount if index == 0 else amount * net_ratio,
			event_id,
			index > 0,
			payload
		)
		if index == 0:
			jaw_target_for_tests = target
		if lock:
			_lock(target)


func _lock(target: Node2D) -> void:
	var status_id := "ranger_ultimate_trap_%d" % get_instance_id()
	var pull := global_position - target.global_position
	var impulse := Vector2.ZERO
	if pull.length_squared() > 0.001:
		impulse = pull.normalized() * _activation.param_float("pull_force", 220.0)
	var applied: Dictionary = _activation.apply_control(target, impulse, status_id, {
		"duration": _activation.param_float("lock_duration", 3.4),
		"movement_locked": true,
		"speed_multiplier": _activation.param_float("net_ratio", 0.11),
		"hunter_trap_jaw": true,
	})
	if bool(applied.get("status_applied", false)) and not _has_lease(target):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _has_lease(target: Node) -> bool:
	for lease in _leased_statuses:
		if lease.get("target") == target:
			return true
	return false


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		var target = lease.get("target") as Node
		if target == null or not is_instance_valid(target) \
				or not target.has_meta(StatusEffects.META_KEY):
			continue
		var statuses = target.get_meta(StatusEffects.META_KEY)
		if not statuses is Dictionary:
			continue
		var owned := (statuses as Dictionary).duplicate(true)
		owned.erase(str(lease.get("status_id", "")))
		if owned.is_empty():
			target.remove_meta(StatusEffects.META_KEY)
		else:
			target.set_meta(StatusEffects.META_KEY, owned)
	_leased_statuses.clear()
	jaw_target_for_tests = null
	_activation = null
