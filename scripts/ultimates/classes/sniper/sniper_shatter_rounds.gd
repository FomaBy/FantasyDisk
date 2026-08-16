extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.sniper.sniper_shatter_rounds"
const EXECUTOR_ID := "weapon_ultimate.executor.sniper.sniper_shatter_rounds"
const EFFECT_SCENE := "res://scripts/ultimates/classes/sniper/sniper_shatter_rounds.tscn"
# Shards only stagger; nothing in this volley pins a target in place.
const CONTROL_POLICY := {
	"normal": {
		"displacement_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"allow_movement_lock": false,
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
var impact_count_for_tests := 0
var shard_count_for_tests := 0

var _activation = null
var _pool: Array = []
var _touched: Array[Dictionary] = []
var _bounce_points: Array = []
var _staggered: Dictionary = {}
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"zone_radius": {"type": "number", "minimum": 0.01},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"trajectory_count": {"type": "integer", "minimum": 1},
		"ricochet_jumps": {"type": "integer", "minimum": 0},
		"volley_delay": {"type": "number", "minimum": 0.0},
		"hop_delay": {"type": "number", "minimum": 0.01},
		"impact_damage": {"type": "number", "minimum": 0.0},
		"ricochet_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"shard_count": {"type": "integer", "minimum": 0},
		"shard_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"shard_radius": {"type": "number", "minimum": 0.0},
		"cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"cap_flat": {"type": "number", "minimum": 0.0},
		"stagger_duration": {"type": "number", "minimum": 0.0},
		"stagger_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	# The anti-focus rail is opened before the first bullet leaves: five
	# trajectories may converge on one silhouette, the ledger still refuses to
	# spend more than the declared share of it on that one target.
	if not Library.execute_primitive("per_target_damage_cap", activation, {
		"cap_fraction": activation.param_float("cap_fraction", 0.4),
		"cap_flat": activation.param_float("cap_flat", 0.0),
	}):
		return 0.0
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	# The sweep is fired from the hip, not down an aimed rail, so the hero's own
	# position is the geometry source the selector reads.
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": activation.param_float("zone_radius", 420.0),
		"limit": activation.param_int("crowd_cap", 15),
		"priority": "nearest",
		"hint": {},
	}):
		return 0.0
	var pool = activation.primitive_value("targets", [])
	if not pool is Array:
		pool = []
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, pool as Array)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var trajectories: int = activation.param_int("trajectory_count", 5)
	var hops: int = activation.param_int("ricochet_jumps", 2)
	var volley_delay: float = activation.param_float("volley_delay", 0.18)
	var hop_delay: float = activation.param_float("hop_delay", 0.14)
	for trajectory in trajectories:
		if trajectory > 0:
			tween.tween_interval(volley_delay)
		for hop in hops + 1:
			tween.tween_callback(Callable(effect, "impact").bind(trajectory, hop))
			tween.tween_interval(hop_delay)
	return float(trajectories) * float(hops + 1) * hop_delay \
		+ float(maxi(trajectories - 1, 0)) * volley_delay


func configure(activation, pool: Array) -> void:
	_activation = activation
	_pool = pool.duplicate()
	global_position = activation.origin()
	_touched.clear()
	_bounce_points.clear()
	for _index in activation.param_int("trajectory_count", 5):
		_touched.append({})
		_bounce_points.append(null)


## Hop 0 enters on the trajectory's own entry silhouette — round-robin over the
## admitted pool, so five bullets never all open on the same body. Every later
## hop ricochets from where the previous one landed to the nearest silhouette
## this trajectory has not touched yet; a lethal hop still leaves its bounce
## point behind, so killing a target never ends the chain.
func impact(trajectory: int, hop: int) -> void:
	if _activation == null or _activation.is_finished() or trajectory >= _touched.size():
		return
	var target: Node2D = null
	if hop == 0:
		target = _entry_target(trajectory)
	elif _bounce_points[trajectory] is Vector2:
		target = _ricochet_target(trajectory, _bounce_points[trajectory] as Vector2)
	if target == null:
		return
	_touched[trajectory][target.get_instance_id()] = true
	_bounce_points[trajectory] = target.global_position
	impact_count_for_tests += 1
	var amount: float = _activation.scaled_damage("impact_damage", 0.0) \
		* pow(_activation.param_float("ricochet_falloff", 0.82), float(hop))
	_deal(
		target,
		amount,
		"shatter_impact:%d:%d" % [trajectory, hop],
		false,
		{"ultimate_mechanic": "ricochet_impact", "trajectory": trajectory, "hop": hop}
	)
	_stagger(target)
	_spray_shards(target, amount, trajectory, hop)


func remaining_budget_for(target: Node) -> float:
	if _activation == null:
		return 0.0
	return _activation.remaining_target_damage_budget(target)


func _entry_target(trajectory: int) -> Node2D:
	var live: Array[Node2D] = []
	for raw_target in _pool:
		var target := raw_target as Node2D
		if _alive(target):
			live.append(target)
	if live.is_empty():
		return null
	return live[trajectory % live.size()]


func _ricochet_target(trajectory: int, from_point: Vector2) -> Node2D:
	var touched: Dictionary = _touched[trajectory]
	for raw_target in _activation.select_targets(
		from_point, _activation.param_float("zone_radius", 420.0), 0, "nearest"
	):
		var target := raw_target as Node2D
		if _alive(target) and not touched.has(target.get_instance_id()):
			return target
	return null


func _spray_shards(source: Node2D, amount: float, trajectory: int, hop: int) -> void:
	var shards: int = _activation.param_int("shard_count", 1)
	if shards <= 0:
		return
	var ratio: float = _activation.param_float("shard_ratio", 0.22)
	var sprayed := 0
	for raw_target in _activation.select_targets(
		source.global_position, _activation.param_float("shard_radius", 130.0), 0, "nearest"
	):
		var target := raw_target as Node2D
		if target == source or not _alive(target):
			continue
		sprayed += 1
		shard_count_for_tests += 1
		_deal(
			target,
			amount * ratio,
			"shatter_shard:%d:%d:%d" % [trajectory, hop, sprayed],
			true,
			{"ultimate_mechanic": "ricochet_shard", "trajectory": trajectory, "hop": hop}
		)
		if sprayed >= shards:
			return


func _stagger(target: Node2D) -> void:
	var target_id := target.get_instance_id()
	if _staggered.has(target_id):
		return
	_staggered[target_id] = true
	var status_id := "sniper_ultimate_shatter_%d_%d" % [get_instance_id(), target_id]
	var result: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
		"duration": _activation.param_float("stagger_duration", 2.8),
		"speed_multiplier": _activation.param_float("stagger_slow", 0.55),
		"shatter_staggered": true,
	})
	if bool(result.get("status_applied", false)):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _alive(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health_value = target.get("health")
	return health_value == null or float(health_value) > 0.0


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_staggered.clear()
	_touched.clear()
	_bounce_points.clear()
	_pool.clear()
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
