extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/sniper/shatter_rounds/shatter_rounds_spriteframes.tres")

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
var _activation = null
var _pool: Array = []
var _staggered: Dictionary = {}
var _leased_statuses: Array[Dictionary] = []
var _impacts = null


static func parameter_contract() -> Dictionary:
	return {
		"arena_radius": {"type": "number", "minimum": 0.01},
		"wave_count": {"type": "integer", "minimum": 1},
		"windup_delay": {"type": "number", "minimum": 0.0},
		"wave_interval": {"type": "number", "minimum": 0.01},
		"impact_damage": {"type": "number", "minimum": 0.0},
		"wave_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"duration": {"type": "number", "minimum": 0.0},
		"stagger_duration": {"type": "number", "minimum": 0.0},
		"stagger_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not Library.execute_primitive("control_resistance_policy", activation, CONTROL_POLICY):
		return 0.0
	# The sweep is fired from the hip, not down an aimed rail, so the hero's own
	# position is the geometry source the selector reads.
	activation.set_primitive_state({"source": activation.origin()})
	if not Library.execute_primitive("priority_target_selector", activation, {
		"center": "source",
		"radius": activation.param_float("arena_radius", 100000.0),
		"limit": 0,
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
	var waves: int = activation.param_int("wave_count", 5)
	var windup: float = activation.param_float("windup_delay", 0.65)
	var interval: float = activation.param_float("wave_interval", 0.22)
	tween.tween_interval(windup)
	for wave in waves:
		tween.tween_callback(Callable(effect, "impact").bind(wave))
		tween.tween_interval(interval)
	var elapsed := windup + float(waves) * interval
	var lifetime := maxf(elapsed, activation.param_float("duration", 3.1))
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation, pool: Array) -> void:
	_activation = activation
	_pool = pool.duplicate()
	global_position = activation.origin()


## Five crystal waves sweep the full arena. The rhythm is finite, but every
## wave reaches every living enemy; it never truncates the enemy set.
func impact(wave: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	var victims: Array[Node2D] = []
	for raw_target in _pool:
		var target := raw_target as Node2D
		if not _alive(target):
			continue
		impact_count_for_tests += 1
		var amount: float = _activation.scaled_damage("impact_damage", 0.0) \
			* pow(_activation.param_float("wave_falloff", 0.82), float(wave))
		_deal(
			target,
			amount,
			"shatter_wave:%d:%d" % [wave, target.get_instance_id()],
			false,
			{"ultimate_mechanic": "crystal_wave", "wave": wave}
		)
		_stagger(target)
		victims.append(target)
	_play_impacts(victims)


func _play_impacts(victims: Array) -> void:
	if victims.is_empty():
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts.play(VICTIM_FRAMES, victims, global_position)
		return
	_impacts.enqueue(victims, global_position)


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
	_pool.clear()
	_impacts = null
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
