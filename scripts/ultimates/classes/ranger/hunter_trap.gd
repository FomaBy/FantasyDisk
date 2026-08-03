extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.ranger.hunter_trap"
const EXECUTOR_ID := "weapon_ultimate.executor.ranger.hunter_trap"
const EFFECT_SCENE := "res://scripts/ultimates/classes/ranger/hunter_trap.tscn"
const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": true, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.5, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.25, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}

var ultimate_damage_sink: Callable = Callable()
var ring_count_for_tests := 0
var snared_targets_for_tests := 0

var _activation = null
var _targets: Array = []
var _leases: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"trap_radius": {"type": "number", "minimum": 0.0},
		"target_limit": {"type": "integer", "minimum": 1},
		"ring_count": {"type": "integer", "minimum": 1},
		"ring_interval": {"type": "number", "minimum": 0.01},
		"snap_damage": {"type": "number", "minimum": 0.0},
		"snare_duration": {"type": "number", "minimum": 0.0},
		"snare_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	var max_range: float = activation.param_float("max_range", 620.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": max_range,
		"target_mode": "host_aim",
	}) or not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	var center: Vector2 = activation.aim_point(max_range)
	var targets: Array = activation.select_targets(
		center,
		activation.param_float("trap_radius", 190.0),
		activation.param_int("target_limit", 10),
		"nearest"
	)
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets, center)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var rings: int = activation.param_int("ring_count", 3)
	for ring in rings:
		if ring > 0:
			tween.tween_interval(activation.param_float("ring_interval", 0.60))
		tween.tween_callback(Callable(effect, "snap_ring").bind(ring))
	return float(maxi(rings - 1, 0)) * activation.param_float("ring_interval", 0.60)


func configure(activation, targets: Array, center: Vector2) -> void:
	_activation = activation
	_targets = targets.duplicate()
	global_position = center
	activation.present("weapon_ultimate.presentation.ranger.hunter_trap", {
		"weapon_id": "hunter_trap", "phase": "arm", "center": center,
	})


func snap_ring(ring: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	ring_count_for_tests += 1
	for raw_target in _targets:
		var target := raw_target as Node2D
		if not _alive(target):
			continue
		_deal(
			target,
			_activation.scaled_damage("snap_damage", 0.0),
			"trap_snap:%d" % ring,
			false,
			{"ultimate_mechanic": "trap_ring", "ring": ring}
		)
		var status_id := "ranger_ultimate_trap_%d_%d_%d" % [get_instance_id(), ring, target.get_instance_id()]
		var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("snare_duration", 3.2),
			"speed_multiplier": _activation.param_float("snare_multiplier", 0.55),
		})
		if bool(result.get("status_applied", false)):
			_leases.append({"target": target, "status_id": status_id})
			snared_targets_for_tests += 1
	_activation.present("weapon_ultimate.presentation.ranger.hunter_trap", {
		"weapon_id": "hunter_trap", "phase": "snap", "ring": ring,
	})


func _alive(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health = target.get("health")
	return health == null or float(health) > 0.0


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leases:
		_remove_lease(lease)
	_leases.clear()
	_targets.clear()
	_activation = null


func _remove_lease(lease: Dictionary) -> void:
	var target := lease.get("target") as Node
	if target == null or not is_instance_valid(target) or not target.has_meta(StatusEffects.META_KEY):
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
