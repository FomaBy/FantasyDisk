extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.elementalist.elementalist_meteor_core"
const EXECUTOR_ID := "weapon_ultimate.executor.elementalist.elementalist_meteor_core"
const EFFECT_SCENE := "res://scripts/ultimates/classes/elementalist/elementalist_meteor_core.tscn"

var ultimate_damage_sink: Callable = Callable()
var impact_count_for_tests := 0
var pulse_count_for_tests := 0
var execute_count_for_tests := 0

var _activation = null
var _impact_point := Vector2.ZERO
var _impact_done := false
var _resolved_pulses := {}
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"max_range": {"type": "number", "minimum": 0.01},
		"impact_radius": {"type": "number", "minimum": 1.0},
		"meteor_drop_at": {"type": "number", "minimum": 0.0},
		"impact_at": {"type": "number", "minimum": 0.0},
		"crater_pulses": {"type": "integer", "minimum": 1},
		"crater_interval": {"type": "number", "minimum": 0.01},
		"cooling_at": {"type": "number", "minimum": 0.0},
		"lifetime": {"type": "number", "minimum": 0.1},
		"impact_damage": {"type": "number", "minimum": 0.0},
		"crater_damage": {"type": "number", "minimum": 0.0},
		"gravity_pull": {"type": "number", "minimum": 0.0},
		"crater_duration": {"type": "number", "minimum": 0.0},
		"crater_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"normal_execute_max_health": {"type": "number", "minimum": 0.0},
		"epic_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	var aim: Dictionary = activation.aim_context(activation.param_float("max_range", 800.0))
	if aim.is_empty():
		return 0.0
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": true,
		},
		"epic": {
			"displacement_multiplier": activation.param_float("epic_displacement", 0.25),
			"duration_multiplier": activation.param_float("epic_duration", 0.40),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": activation.param_float("boss_displacement", 0.0),
			"duration_multiplier": activation.param_float("boss_duration", 0.20),
			"allow_movement_lock": false, "allow_execute": false,
		},
	}):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, aim["target"] as Vector2)
	effect.call("begin")
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var elapsed := 0.0
	var meteor_drop_at: float = activation.param_float("meteor_drop_at", 2.45)
	tween.tween_interval(meteor_drop_at)
	tween.tween_callback(Callable(effect, "meteor_drop"))
	elapsed = meteor_drop_at
	var impact_at: float = activation.param_float("impact_at", 2.75)
	if impact_at > elapsed:
		tween.tween_interval(impact_at - elapsed)
		elapsed = impact_at
	tween.tween_callback(Callable(effect, "impact"))
	var pulse_interval: float = activation.param_float("crater_interval", 0.85)
	for pulse in activation.param_int("crater_pulses", 5):
		tween.tween_interval(pulse_interval)
		elapsed += pulse_interval
		tween.tween_callback(Callable(effect, "crater_pulse").bind(pulse))
	var cooling_at: float = activation.param_float("cooling_at", 8.1)
	if cooling_at > elapsed:
		tween.tween_interval(cooling_at - elapsed)
		elapsed = cooling_at
	tween.tween_callback(Callable(effect, "cooling"))
	var lifetime: float = activation.param_float("lifetime", 8.9)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return lifetime


func configure(activation, impact_point: Vector2) -> void:
	_activation = activation
	_impact_point = impact_point
	global_position = impact_point
	set_meta("elementalist_ultimate", "elementalist_meteor_core")


func begin() -> void:
	if not _live():
		return
	_activation.present(EXECUTOR_ID + ".rune_shadow", {
		"position": _impact_point,
		"radius": _activation.param_float("impact_radius", 360.0),
		"shape": "ring_pulse",
	})


func meteor_drop() -> void:
	if not _live():
		return
	_activation.present(EXECUTOR_ID + ".meteor", {
		"position": _impact_point,
		"radius": _activation.param_float("impact_radius", 360.0) * 0.55,
		"shape": "orb_burst",
	})


func impact() -> void:
	if not _live() or _impact_done:
		return
	_impact_done = true
	impact_count_for_tests += 1
	var radius: float = _activation.param_float("impact_radius", 360.0)
	_activation.present(EXECUTOR_ID + ".impact", {
		"position": _impact_point, "radius": radius, "shape": "orb_burst",
	})
	for raw_target in _activation.select_targets(_impact_point, INF, 0, "nearest"):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var direction := _impact_point - target.global_position
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		var control: Dictionary = _apply_crater_control(
			target, direction.normalized() * _activation.param_float("gravity_pull", 260.0)
		)
		_deal(target, _activation.scaled_damage("impact_damage", 10.0),
			"meteor:impact", "meteor_impact")
		if bool(control.get("execute_allowed", false)) and _is_weak_normal(target):
			var remaining = target.get("health")
			if remaining != null and float(remaining) > 0.0:
				_deal(target, float(remaining), "meteor:execute", "meteor_normal_execute")
				execute_count_for_tests += 1


func crater_pulse(pulse: int) -> void:
	if not _live() or pulse < 0 \
			or pulse >= _activation.param_int("crater_pulses", 5) \
			or _resolved_pulses.has(pulse):
		return
	_resolved_pulses[pulse] = true
	pulse_count_for_tests += 1
	_activation.present(EXECUTOR_ID + ".crater_pulse", {
		"position": _impact_point,
		"radius": _activation.param_float("impact_radius", 360.0),
		"shape": "ring_pulse",
	})
	for raw_target in _activation.select_targets(
		_impact_point, INF, 0, "nearest"
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var direction := _impact_point - target.global_position
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		_apply_crater_control(
			target,
			direction.normalized() * _activation.param_float("gravity_pull", 260.0) * 0.25
		)
		_deal(target, _activation.scaled_damage("crater_damage", 1.0),
			"meteor:crater:%d" % pulse, "meteor_crater")


func cooling() -> void:
	if _live():
		_activation.present(EXECUTOR_ID + ".cooling", {
			"position": _impact_point,
			"radius": _activation.param_float("impact_radius", 360.0) * 0.65,
			"shape": "ring_pulse",
		})


func _apply_crater_control(target: Node, impulse: Vector2) -> Dictionary:
	var status_id := "elementalist_meteor_crater_%d" % get_instance_id()
	var result: Dictionary = _activation.apply_control(target, impulse, status_id, {
		"duration": _activation.param_float("crater_duration", 4.8),
		"speed_multiplier": _activation.param_float("crater_slow", 0.55),
		"marker_color": Color(1.0, 0.30, 0.08, 0.70),
	})
	if bool(result.get("status_applied", false)):
		_lease_status(target, status_id)
	return result


func _is_weak_normal(target: Node) -> bool:
	var maximum = target.get("max_health")
	return maximum != null and float(maximum) <= _activation.param_float(
		"normal_execute_max_health", 900.0
	)


func _lease_status(target: Node, status_id: String) -> void:
	for lease in _leased_statuses:
		if lease.get("target") == target and str(lease.get("status_id", "")) == status_id:
			return
	_leased_statuses.append({"target": target, "status_id": status_id})


func _deal(target: Node, amount: float, event_id: String, mechanic: String) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, {
			"ultimate_mechanic": mechanic,
		}, event_id, false)


func _live() -> bool:
	return _activation != null and not _activation.is_finished()


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_activation = null


static func _remove_leased_status(lease: Dictionary) -> void:
	var target = lease.get("target")
	if target == null or not is_instance_valid(target) or not (target as Node).has_meta(StatusEffects.META_KEY):
		return
	var statuses = (target as Node).get_meta(StatusEffects.META_KEY)
	if not statuses is Dictionary:
		return
	var owned := (statuses as Dictionary).duplicate(true)
	owned.erase(str(lease.get("status_id", "")))
	if owned.is_empty():
		(target as Node).remove_meta(StatusEffects.META_KEY)
	else:
		(target as Node).set_meta(StatusEffects.META_KEY, owned)
