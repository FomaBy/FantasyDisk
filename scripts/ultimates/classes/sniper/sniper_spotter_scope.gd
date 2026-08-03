extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.sniper.sniper_spotter_scope"
const EXECUTOR_ID := "weapon_ultimate.executor.sniper.sniper_spotter_scope"
const EFFECT_SCENE := "res://scripts/ultimates/classes/sniper/sniper_spotter_scope.tscn"
const LOCK_KEY := "spotter_sky_locks"
# Suppression is the price of standing under nine locks; epic and boss tiers buy
# most of it back, and neither is ever pinned in place.
const CONTROL_POLICY := {
	"normal": {
		"displacement_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"allow_movement_lock": true,
		"allow_execute": true,
	},
	"epic": {
		"displacement_multiplier": 0.25,
		"duration_multiplier": 0.5,
		"allow_movement_lock": false,
		"allow_execute": true,
	},
	"boss": {
		"displacement_multiplier": 0.0,
		"duration_multiplier": 0.25,
		"allow_movement_lock": false,
		"allow_execute": false,
	},
}

var ultimate_damage_sink: Callable = Callable()
var strike_count_for_tests := 0
var transfer_count_for_tests := 0

var _activation = null
var _locks: Array = []
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"zone_radius": {"type": "number", "minimum": 0.0},
		"lock_count": {"type": "integer", "minimum": 1},
		"max_locks_per_target": {"type": "integer", "minimum": 1},
		"lock_delay": {"type": "number", "minimum": 0.0},
		"strike_interval": {"type": "number", "minimum": 0.01},
		"strike_damage": {"type": "number", "minimum": 0.0},
		"suppression_duration": {"type": "number", "minimum": 0.0},
		"suppression_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": activation.param_float("max_range", 760.0),
		"target_mode": "host_aim",
	}):
		return 0.0
	var zone_center = activation.primitive_value("target")
	if not zone_center is Vector2:
		return 0.0
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "target",
		"radius": activation.param_float("zone_radius", 300.0),
		"limit": activation.param_int("lock_count", 9),
		"priority": "highest_hp",
		"hint": {},
	}):
		return 0.0
	var marked = activation.primitive_value("targets", [])
	if not marked is Array:
		marked = []
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, zone_center as Vector2, _assign_locks(activation, marked as Array))
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var lock_delay: float = activation.param_float("lock_delay", 1.0)
	var strike_interval: float = activation.param_float("strike_interval", 0.12)
	var lock_count: int = activation.param_int("lock_count", 9)
	tween.tween_interval(lock_delay)
	for index in lock_count:
		tween.tween_callback(Callable(effect, "strike").bind(index))
		tween.tween_interval(strike_interval)
	# The kill zone stays live for the whole suppression window, so teardown —
	# and with it the lease removal — never cuts the declared duration short.
	var elapsed := lock_delay + strike_interval * float(lock_count)
	var lifetime := maxf(elapsed, activation.param_float("suppression_duration", 4.4))
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


## Nine locks are dealt round-robin over the marked silhouettes and no single
## silhouette may carry more than `max_locks_per_target`; the surplus is simply
## never armed.
static func _assign_locks(activation, marked: Array) -> Array:
	var locks: Array = []
	var per_target := {}
	var lock_count: int = activation.param_int("lock_count", 9)
	var cap: int = activation.param_int("max_locks_per_target", 3)
	while locks.size() < lock_count:
		var placed := false
		for raw_target in marked:
			var target := raw_target as Node2D
			if target == null or not is_instance_valid(target):
				continue
			var target_id := target.get_instance_id()
			if int(per_target.get(target_id, 0)) >= cap:
				continue
			per_target[target_id] = int(per_target.get(target_id, 0)) + 1
			locks.append(target)
			placed = true
			if locks.size() >= lock_count:
				break
		if not placed:
			break
	return locks


func configure(activation, zone_center: Vector2, locks: Array) -> void:
	_activation = activation
	_locks = locks.duplicate()
	global_position = zone_center
	for index in _locks.size():
		var target := _locks[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		activation.add_target_value(target, LOCK_KEY, 1.0, "spotter_lock:%d" % index)
	_suppress()


## One artillery round per armed lock. A lock whose silhouette is already gone
## transfers to the most dangerous survivor still inside the zone instead of
## being wasted.
func strike(index: int) -> void:
	if _activation == null or _activation.is_finished() or index >= _locks.size():
		return
	var target := _locks[index] as Node2D
	if not _strikeable(target):
		target = _transfer(index)
		if target == null:
			return
	strike_count_for_tests += 1
	_deal(
		target,
		_activation.scaled_damage("strike_damage", 0.0),
		"spotter_strike:%d" % index,
		false,
		{"ultimate_mechanic": "sky_lock_strike", "sky_lock": index}
	)


func lock_count_for(target: Node) -> float:
	if _activation == null:
		return 0.0
	return float(_activation.target_value(target, LOCK_KEY, 0.0))


func _transfer(index: int) -> Node2D:
	var replacement := _replacement_target()
	if replacement == null:
		return null
	# One lock moves, not the whole mark: the ledger holds a count, so releasing
	# and re-arming exactly one is what keeps both silhouettes honest.
	var previous := _locks[index] as Node2D
	if previous != null and is_instance_valid(previous):
		_activation.add_target_value(previous, LOCK_KEY, -1.0, "spotter_release:%d" % index)
	_activation.add_target_value(replacement, LOCK_KEY, 1.0, "spotter_transfer:%d" % index)
	_locks[index] = replacement
	transfer_count_for_tests += 1
	return replacement


func _replacement_target() -> Node2D:
	var found: Array = _activation.select_targets(
		global_position, _activation.param_float("zone_radius", 300.0), 0, "highest_hp"
	)
	for raw_target in found:
		var target := raw_target as Node2D
		if _strikeable(target):
			return target
	return null


func _strikeable(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health_value = target.get("health")
	return health_value == null or float(health_value) > 0.0


func _suppress() -> void:
	var seen := {}
	for raw_target in _locks:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target) or seen.has(target.get_instance_id()):
			continue
		seen[target.get_instance_id()] = true
		var status_id := "sniper_ultimate_spotter_%d_%d" % [get_instance_id(), target.get_instance_id()]
		var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("suppression_duration", 4.4),
			"movement_locked": true,
			"speed_multiplier": _activation.param_float("suppression_slow", 0.45),
			"spotter_suppressed": true,
		})
		if bool(result.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_locks.clear()
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
