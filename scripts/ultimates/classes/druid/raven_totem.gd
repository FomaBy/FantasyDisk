extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.druid.raven_totem"
const EXECUTOR_ID := "weapon_ultimate.executor.druid.raven_totem"
const EFFECT_SCENE := "res://scripts/ultimates/classes/druid/raven_totem.tscn"

var ultimate_damage_sink: Callable = Callable()
var marked_count_for_tests := 0
var dive_count_for_tests := 0
var wisp_return_count_for_tests := 0

var _activation = null
var _marked: Array = []
var _leased_statuses: Array[Dictionary] = []


## Ultimate Direction v2 (FAN-3239): the mark, every dive wave and the collapse
## reach every live enemy on the map — `mark_radius` is the presentation ring,
## never reach. Dive and collapse parameters shape the fixed sequence, not its
## per-activation target count.
static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"dive_interval": {"type": "number", "minimum": 0.01},
		"dive_waves": {"type": "integer", "minimum": 1},
		"final_delay": {"type": "number", "minimum": 0.0},
		"mark_radius": {"type": "number", "minimum": 1.0},
		"mark_duration": {"type": "number", "minimum": 0.1},
		"slow_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"accuracy_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"dive_damage": {"type": "number", "minimum": 0.0},
		"final_damage": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.6)
	var interval: float = activation.param_float("dive_interval", 1.25)
	var waves: int = activation.param_int("dive_waves", 4)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "mark"))
	for wave in waves:
		tween.tween_interval(interval)
		tween.tween_callback(Callable(effect, "dive").bind(wave))
	var elapsed: float = release_delay + interval * float(waves)
	var final_delay: float = activation.param_float("final_delay", 7.1)
	if final_delay > elapsed:
		tween.tween_interval(final_delay - elapsed)
	tween.tween_callback(Callable(effect, "collapse"))
	var lifetime: float = activation.param_float("lifetime", 8.4)
	if lifetime > final_delay:
		tween.tween_interval(lifetime - final_delay)
	return maxf(lifetime, final_delay)


static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 0.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": 0.0, "duration_multiplier": 0.45,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0, "duration_multiplier": 0.2,
			"allow_movement_lock": false, "allow_execute": false,
		},
	}


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()


func mark() -> void:
	if _activation == null or _activation.is_finished():
		return
	_marked = _activation.select_targets(global_position, INF, 0, "nearest")
	for raw_target in _marked:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var status_id := "druid_ultimate_raven_%d" % get_instance_id()
		var applied: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("mark_duration", 7.8),
			"speed_multiplier": _activation.param_float("slow_multiplier", 0.58),
			"accuracy_multiplier": _activation.param_float("accuracy_multiplier", 0.65),
			"damage_multiplier": _activation.param_float("accuracy_multiplier", 0.65),
			"raven_mark": true,
		})
		if bool(applied.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})
	marked_count_for_tests = _marked.size()


func dive(wave: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	dive_count_for_tests += 1
	for raw_target in _marked:
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var result = _deal(
			target,
			_activation.scaled_damage("dive_damage", 18.0),
			"thousand_wings:dive:%d" % wave,
			{"ultimate_mechanic": "raven_dive", "wave": wave}
		)
		if result != null and float(result.applied) > 0.0:
			wisp_return_count_for_tests += 1


func collapse() -> void:
	if _activation == null or _activation.is_finished():
		return
	for raw_target in _marked:
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var result = _deal(
			target,
			_activation.scaled_damage("final_damage", 28.0),
			"thousand_wings:collapse",
			{"ultimate_mechanic": "raven_collapse"}
		)
		if result != null and float(result.applied) > 0.0:
			wisp_return_count_for_tests += 1
	_activation.present(EXECUTOR_ID + ".collapse", {
		"position": global_position, "radius": _activation.param_float("mark_radius", 520.0),
		"shape": "ring_pulse",
	})


func _deal(target: Node, amount: float, event_id: String, feedback: Dictionary):
	if not ultimate_damage_sink.is_valid():
		return null
	return ultimate_damage_sink.call(target, amount, feedback, event_id, false)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		var target = lease.get("target") as Node
		if target == null or not is_instance_valid(target) or not target.has_meta(StatusEffects.META_KEY):
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
	_marked.clear()
	_activation = null
