extends Node2D

const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/ranger/storm_longbow/storm_longbow_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.ranger.storm_longbow"
const EXECUTOR_ID := "weapon_ultimate.executor.ranger.storm_longbow"
const EFFECT_SCENE := "res://scripts/ultimates/classes/ranger/storm_longbow.tscn"

var ultimate_damage_sink: Callable = Callable()
var beat_count_for_tests := 0
var rail_size_for_tests := 0
var pushed_count_for_tests := 0

var _activation = null
var _rail: Array = []
var _axis := Vector2.RIGHT
var _perpendicular := Vector2.DOWN
var _start := Vector2.ZERO
var _leased_statuses: Array[Dictionary] = []
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"windup_delay": {"type": "number", "minimum": 0.0},
		"beat_interval": {"type": "number", "minimum": 0.01},
		"beat_count": {"type": "integer", "minimum": 1},
		"max_range": {"type": "number", "minimum": 1.0},
		"half_width": {"type": "number", "minimum": 0.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"beat_damage": {"type": "number", "minimum": 0.0},
		"beat_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"push_force": {"type": "number", "minimum": 0.0},
		"slow_duration": {"type": "number", "minimum": 0.1},
		"slow_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	var length: float = activation.param_float("max_range", 780.0)
	if not Library.execute_primitive("aim_context", activation, {
		"max_range": length,
		"target_mode": "host_aim",
	}):
		return 0.0
	if not Library.execute_primitive("line_pierce_geometry", activation, {
		"start": "source",
		"direction": "aim",
		"length": length,
		"half_width": activation.param_float("half_width", 120.0),
		"limit": activation.param_int("crowd_cap", 8),
	}):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var windup: float = activation.param_float("windup_delay", 0.55)
	var interval: float = activation.param_float("beat_interval", 0.6)
	var beats: int = activation.param_int("beat_count", 6)
	tween.tween_interval(windup)
	for beat in beats:
		tween.tween_callback(Callable(effect, "strike").bind(beat))
		tween.tween_interval(interval)
	var elapsed: float = windup + interval * float(beats)
	var lifetime: float = activation.param_float("lifetime", 4.45)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


## The storm displaces, it does not pin: nothing on the corridor is ever
## movement-locked, and resistant tiers keep a shorter, weaker push.
static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": 0.5, "duration_multiplier": 0.45,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.2, "duration_multiplier": 0.2,
			"allow_movement_lock": false, "allow_execute": false,
		},
	}


func configure(activation) -> void:
	_activation = activation
	_start = activation.origin()
	global_position = _start
	var direction = activation.primitive_value("direction")
	if direction is Vector2 and (direction as Vector2).length_squared() > 0.001:
		_axis = (direction as Vector2).normalized()
	_perpendicular = Vector2(-_axis.y, _axis.x)
	var rail = activation.primitive_value("targets", [])
	_rail = (rail as Array).duplicate() if rail is Array else []
	rail_size_for_tests = _rail.size()


## One beat: the lightning front walks one more step from tail to tip, the body
## closest to it takes the full strike, and everything else on the corridor keeps
## only `beat_falloff` of what the body in front of it took. Every struck body is
## pushed off the axis, which is what keeps the safe lane readable.
func strike(index: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	beat_count_for_tests += 1
	var beats: int = maxi(_activation.param_int("beat_count", 6), 1)
	var front: float = _activation.param_float("max_range", 780.0) \
		* float(index + 1) / float(beats)
	var ranked := _ranked_by_front(front)
	var strike_damage: float = _activation.scaled_damage("beat_damage", 11.2)
	var falloff: float = _activation.param_float("beat_falloff", 0.46)
	for rank in ranked.size():
		var target := ranked[rank] as Node2D
		_deal(
			target,
			strike_damage * pow(falloff, float(rank)),
			"storm_eye:beat:%d" % index,
			rank > 0,
			{"ultimate_mechanic": "storm_beat", "beat": index, "rank": rank}
		)
		_push(target)
	_play_impacts(ranked)
	_activation.present(EXECUTOR_ID + ".beat", {
		"position": _start + _axis * front,
		"radius": _activation.param_float("half_width", 120.0),
		"shape": "corridor_beat",
	})


## Corridor order is fixed by the arrow; only the distance to the current front
## decides who takes the full strike, with a stable positional tie-break.
func _ranked_by_front(front: float) -> Array:
	var ordered: Array[Dictionary] = []
	for raw_target in _rail:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var offset := target.global_position - _start
		ordered.append({
			"node": target,
			"gap": absf(offset.dot(_axis) - front),
			"forward": offset.dot(_axis),
			"id": target.get_instance_id(),
		})
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		for key in ["gap", "forward"]:
			if not is_equal_approx(float(left[key]), float(right[key])):
				return float(left[key]) < float(right[key])
		return int(left["id"]) < int(right["id"])
	)
	var ranked: Array = []
	for entry in ordered:
		ranked.append(entry["node"])
	return ranked


func _push(target: Node2D) -> void:
	var lateral := (target.global_position - _start).dot(_perpendicular)
	var away := _perpendicular * (-1.0 if lateral < 0.0 else 1.0)
	var status_id := "ranger_ultimate_storm_%d" % get_instance_id()
	var applied: Dictionary = _activation.apply_control(
		target,
		away * _activation.param_float("push_force", 260.0),
		status_id,
		{
			"duration": _activation.param_float("slow_duration", 2.6),
			"speed_multiplier": _activation.param_float("slow_multiplier", 0.55),
			"storm_shock": true,
		}
	)
	if bool(applied.get("displaced", false)):
		pushed_count_for_tests += 1
	if bool(applied.get("status_applied", false)) and not _has_lease(target):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _has_lease(target: Node) -> bool:
	for lease in _leased_statuses:
		if lease.get("target") == target:
			return true
	return false


func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims, _start)
	else:
		_impacts.play(VICTIM_FRAMES, victims, _start)
		_impacts_started = true


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
	_rail.clear()
	_impacts = null
	_impacts_started = false
	_activation = null
