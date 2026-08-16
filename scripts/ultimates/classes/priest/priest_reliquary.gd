extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.priest.priest_reliquary"
const EXECUTOR_ID := "weapon_ultimate.executor.priest.priest_reliquary"
const EFFECT_SCENE := "res://scripts/ultimates/classes/priest/priest_reliquary.tscn"
const StatusEffects := preload("res://scripts/status_effects.gd")

var ultimate_damage_sink: Callable = Callable()
var actual_removed_for_tests := 0.0

var _activation = null
var _targets: Array = []
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"radius": {"type": "number", "minimum": 0.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"crowd_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"first_ring_at": {"type": "number", "minimum": 0.0},
		"sanctify_ring_at": {"type": "number", "minimum": 0.0},
		"pillar_at": {"type": "number", "minimum": 0.0},
		"first_ring_damage": {"type": "number", "minimum": 0.0},
		"sanctify_damage": {"type": "number", "minimum": 0.0},
		"pillar_damage": {"type": "number", "minimum": 0.0},
		"sanctify_duration": {"type": "number", "minimum": 0.1},
		"heal_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"heal_cap": {"type": "number", "minimum": 0.0},
		"shield_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"shield_cap": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.configure_repair(activation.scaled_damage("heal_cap", 0.0)):
		return 0.0
	var targets: Array = activation.select_targets(
		activation.origin(),
		activation.param_float("radius", 470.0),
		activation.param_int("crowd_cap", 22),
		"nearest"
	)
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation, targets)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var first_at: float = activation.param_float("first_ring_at", 1.25)
	var sanctify_at: float = maxf(activation.param_float("sanctify_ring_at", 2.60), first_at)
	var pillar_at: float = maxf(activation.param_float("pillar_at", 5.30), sanctify_at)
	if first_at > 0.0:
		tween.tween_interval(first_at)
	tween.tween_callback(Callable(effect, "first_ring"))
	if sanctify_at > first_at:
		tween.tween_interval(sanctify_at - first_at)
	tween.tween_callback(Callable(effect, "sanctify_ring"))
	if pillar_at > sanctify_at:
		tween.tween_interval(pillar_at - sanctify_at)
	tween.tween_callback(Callable(effect, "pillar"))
	var lifetime: float = maxf(activation.param_float("lifetime", 8.6), pillar_at)
	if lifetime > pillar_at:
		tween.tween_interval(lifetime - pillar_at)
	return lifetime


func configure(activation, targets: Array) -> void:
	_activation = activation
	_targets = targets.duplicate()
	global_position = activation.origin()


func first_ring() -> void:
	_hit_all("reliquary_first_ring", _activation.scaled_damage("first_ring_damage", 0.0), false)


func sanctify_ring() -> void:
	for index in _targets.size():
		var target := _targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		_lease_sanctify(target)
		_deal(
			target,
			_activation.scaled_damage("sanctify_damage", 0.0) * _crowd_multiplier(index),
			"reliquary_sanctify:%d" % target.get_instance_id(),
			false,
			{"ultimate_mechanic": "reliquary_sanctify", "sanctified": true}
		)


func pillar() -> void:
	_hit_all("reliquary_pillar", _activation.scaled_damage("pillar_damage", 0.0), true)
	var player := _player()
	if player == null:
		return
	var repair_result = _activation.repair(
		player,
		actual_removed_for_tests * _activation.param_float("heal_ratio", 0.0),
		"reliquary_actual_damage_heal"
	)
	var healed := float(repair_result.get("applied", 0.0)) if repair_result is Dictionary else 0.0
	var overflow := maxf(actual_removed_for_tests * _activation.param_float("heal_ratio", 0.0) - healed, 0.0)
	var shield := minf(
		overflow * _activation.param_float("shield_ratio", 0.0),
		_activation.scaled_damage("shield_cap", 0.0)
	)
	if shield > 0.0:
		_activation.apply_modifier("absorb_flat", shield, "add")


func _hit_all(event_prefix: String, amount: float, secondary: bool) -> void:
	if _activation == null or _activation.is_finished():
		return
	for index in _targets.size():
		var target := _targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		_deal(
			target,
			amount * _crowd_multiplier(index),
			"%s:%d" % [event_prefix, target.get_instance_id()],
			secondary,
			{"ultimate_mechanic": event_prefix}
		)


func _crowd_multiplier(index: int) -> float:
	return pow(_activation.param_float("crowd_falloff", 1.0), float(index))


func _lease_sanctify(target: Node2D) -> void:
	var status_id := "priest_ultimate_reliquary_%d_%d" % [get_instance_id(), target.get_instance_id()]
	var applied: Dictionary = _activation.apply_control(
		target,
		Vector2.ZERO,
		status_id,
		{
			"duration": _activation.param_float("sanctify_duration", 3.0),
			"sanctified": true,
			"speed_multiplier": 0.82,
		}
	)
	if bool(applied.get("status_applied", false)):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary) -> void:
	if not ultimate_damage_sink.is_valid():
		return
	var result = ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)
	if result != null:
		actual_removed_for_tests += maxf(float(result.applied), 0.0)


func _player() -> Node:
	if _activation == null or _activation.host == null or not is_instance_valid(_activation.host):
		return null
	var player = _activation.host.get("player")
	return player as Node if player is Node and is_instance_valid(player) else null


func _exit_tree() -> void:
	for lease in _leased_statuses:
		var target = lease.get("target") as Node
		if target == null or not is_instance_valid(target) or not target.has_meta(StatusEffects.META_KEY):
			continue
		var statuses = target.get_meta(StatusEffects.META_KEY)
		if not statuses is Dictionary:
			continue
		var owned: Dictionary = (statuses as Dictionary).duplicate(true)
		owned.erase(str(lease.get("status_id", "")))
		if owned.is_empty():
			target.remove_meta(StatusEffects.META_KEY)
		else:
			target.set_meta(StatusEffects.META_KEY, owned)
	_leased_statuses.clear()
	_targets.clear()
	_activation = null
