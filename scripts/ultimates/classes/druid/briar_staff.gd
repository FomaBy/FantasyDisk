extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.druid.briar_staff"
const EXECUTOR_ID := "weapon_ultimate.executor.druid.briar_staff"
const EFFECT_SCENE := "res://scripts/ultimates/classes/druid/briar_staff.tscn"

var ultimate_damage_sink: Callable = Callable()
var seed_count_for_tests := 0
var impale_count_for_tests := 0

var _activation = null
var _targets: Array = []
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"pulse_interval": {"type": "number", "minimum": 0.01},
		"impale_pulses": {"type": "integer", "minimum": 1},
		"seed_count": {"type": "integer", "minimum": 5, "maximum": 5},
		"root_radius": {"type": "number", "minimum": 1.0},
		"root_duration": {"type": "number", "minimum": 0.1},
		"slow_multiplier": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"impale_damage": {"type": "number", "minimum": 0.0},
		"thorn_crown_damage": {"type": "number", "minimum": 0.0},
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
	var release_delay: float = activation.param_float("release_delay", 1.1)
	var interval: float = activation.param_float("pulse_interval", 1.8)
	var pulses: int = activation.param_int("impale_pulses", 3)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "grow_lattice"))
	for pulse in range(1, pulses):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(effect, "impale").bind(pulse))
	var elapsed: float = release_delay + interval * float(maxi(pulses - 1, 0))
	var lifetime: float = activation.param_float("lifetime", 7.9)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 0.0, "duration_multiplier": 1.0,
			"allow_movement_lock": true, "allow_execute": false,
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
	seed_count_for_tests = activation.param_int("seed_count", 5)


func grow_lattice() -> void:
	if _activation == null or _activation.is_finished():
		return
	_targets = _activation.select_targets(
		global_position,
		INF,
		0,
		"nearest"
	)
	for raw_target in _targets:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var status_id := "druid_ultimate_briar_%d" % get_instance_id()
		var applied: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
			"duration": _activation.param_float("root_duration", 5.0),
			"movement_locked": true,
			"speed_multiplier": _activation.param_float("slow_multiplier", 0.45),
			"briar_lattice": true,
		})
		if bool(applied.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})
	impale(0)


func impale(pulse: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	impale_count_for_tests += 1
	for raw_target in _targets:
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var damage_key := "thorn_crown_damage" if pulse == _activation.param_int("impale_pulses", 3) - 1 else "impale_damage"
		_deal(
			target,
			_activation.scaled_damage(damage_key, 0.0),
			"forest_breath:impale:%d" % pulse,
			{"ultimate_mechanic": "briar_lattice_impale", "pulse": pulse}
		)
	_activation.present(EXECUTOR_ID + ".impale", {
		"position": global_position, "radius": _activation.param_float("root_radius", 430.0),
		"shape": "ring_pulse",
	})


func _deal(target: Node, amount: float, event_id: String, feedback: Dictionary) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, feedback, event_id, false)


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
	_targets.clear()
	_activation = null
