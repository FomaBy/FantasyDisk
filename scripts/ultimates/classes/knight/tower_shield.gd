extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.knight.tower_shield"
const EXECUTOR_ID := "weapon_ultimate.executor.knight.tower_shield"
const EFFECT_SCENE := "res://scripts/ultimates/classes/knight/tower_shield.tscn"
const RESOURCE_ID := "knight_tower_shield.counter"

var guard_owner_id_for_tests := ""
var counter_amount_for_tests := 0.0
var counter_target_count_for_tests := 0

var _activation = null
var _direction := Vector2.RIGHT
var _counter_resolved := false
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"counter_at": {"type": "number", "minimum": 0.0},
		"guard_cap": {"type": "number", "minimum": 0.1},
		"guard_arc_degrees": {"type": "number", "minimum": 1.0, "maximum": 360.0},
		"counter_radius": {"type": "number", "minimum": 1.0},
		"counter_arc_degrees": {"type": "number", "minimum": 1.0, "maximum": 360.0},
		"counter_target_cap": {"type": "integer", "minimum": 1},
		"counter_damage_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"push_force": {"type": "number", "minimum": 0.0},
		"control_duration": {"type": "number", "minimum": 0.0},
		"epic_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_flat": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.35),
		activation.param_float("per_target_cap_flat", 0.0)
	) or not activation.set_control_resistance_policy(_control_policy(activation)):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure") or not effect.call("configure", activation):
		return 0.0
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var counter_at: float = activation.param_float("counter_at", 5.6)
	if counter_at > 0.0:
		tween.tween_interval(counter_at)
	tween.tween_callback(Callable(effect, "counter_burst"))
	var lifetime: float = maxf(activation.param_float("lifetime", 8.6), counter_at)
	if lifetime > counter_at:
		tween.tween_interval(lifetime - counter_at)
	return lifetime


static func _control_policy(activation) -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": activation.param_float("epic_displacement", 0.25),
			"duration_multiplier": activation.param_float("epic_duration", 0.5),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0, "duration_multiplier": 0.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
	}


func configure(activation) -> bool:
	_activation = activation
	_direction = activation.aim_direction(activation.param_float("counter_radius", 195.0))
	if _direction.length_squared() <= 0.001:
		return false
	_direction = _direction.normalized()
	global_position = activation.origin()
	guard_owner_id_for_tests = "%s:%d" % [EXECUTOR_ID, get_instance_id()]
	var guard_sources: Array[String] = ["contact"]
	return activation.configure_guard_prevention(
		guard_owner_id_for_tests,
		RESOURCE_ID,
		activation.param_float("guard_cap", 80.0),
		_direction,
		activation.param_float("guard_arc_degrees", 110.0),
		guard_sources
	)


func counter_burst() -> void:
	if _counter_resolved or _activation == null or _activation.is_finished():
		return
	_counter_resolved = true
	var counter: Dictionary = _activation.consume_owner_resource(
		guard_owner_id_for_tests, RESOURCE_ID, "counter_release"
	)
	counter_amount_for_tests = maxf(float(counter.get("amount", 0.0)), 0.0)
	if counter_amount_for_tests <= 0.0:
		return
	_activation.present(EXECUTOR_ID + ".counter", {
		"shape": "ring_pulse", "position": global_position,
		"radius": _activation.param_float("counter_radius", 195.0),
	})
	for raw_target in _activation.select_targets(
		global_position, _activation.param_float("counter_radius", 195.0), 0, "nearest"
	):
		if counter_target_count_for_tests >= _activation.param_int("counter_target_cap", 4):
			break
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target) or not _inside_counter_arc(target):
			continue
		counter_target_count_for_tests += 1
		var offset := target.global_position - global_position
		var impulse := _direction if offset.length_squared() <= 0.001 else offset.normalized()
		var status_id := "knight_tower_shield_push_%d_%d" % [
			get_instance_id(), target.get_instance_id()
		]
		var applied: Dictionary = _activation.apply_control(target, impulse * _activation.param_float("push_force", 230.0), status_id, {
			"duration": _activation.param_float("control_duration", 0.85),
			"speed_multiplier": 0.78,
			"tower_shield_counter": true,
		})
		if bool(applied.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})
		_activation.deal_damage(
			target,
			counter_amount_for_tests * _activation.param_float("counter_damage_ratio", 0.55),
			{"ultimate_mechanic": "tower_shield_stored_counter"},
			"counter:%d" % target.get_instance_id(),
			true
		)


func _inside_counter_arc(target: Node2D) -> bool:
	var offset := target.global_position - global_position
	if offset.length_squared() <= 0.001:
		return true
	var half_arc := deg_to_rad(_activation.param_float("counter_arc_degrees", 135.0) * 0.5)
	return _direction.dot(offset.normalized()) >= cos(half_arc)


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_activation = null


static func _remove_leased_status(lease: Dictionary) -> void:
	var target = lease.get("target") as Node
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
