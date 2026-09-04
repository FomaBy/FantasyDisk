extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.priest.priest_chime"
const EXECUTOR_ID := "weapon_ultimate.executor.priest.priest_chime"
const EFFECT_SCENE := "res://scripts/ultimates/classes/priest/priest_chime.tscn"
const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/priest/priest_chime/priest_chime_spriteframes.tres")

## Ultimate Direction v2 (FAN-2535): bell one interrupts every live enemy and
## bell two chains through the same full set. Chain rank still shapes damage,
## clamped by the corridor-derived floor instead of limiting reach.

var ultimate_damage_sink: Callable = Callable()
var chain_removed_for_tests := 0.0
var toll_count_for_tests := 0

var _activation = null
var _leased_statuses: Array[Dictionary] = []
var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"first_toll_at": {"type": "number", "minimum": 0.0},
		"second_toll_at": {"type": "number", "minimum": 0.0},
		"third_toll_at": {"type": "number", "minimum": 0.0},
		"interrupt_duration": {"type": "number", "minimum": 0.1},
		"interrupt_damage": {"type": "number", "minimum": 0.0},
		"chain_damage": {"type": "number", "minimum": 0.0},
		"chain_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"chain_floor": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"heal_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"heal_cap": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.configure_repair(activation.scaled_damage("heal_cap", 0.0)):
		return 0.0
	if not activation.set_control_resistance_policy(_control_policy()):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var first_at: float = activation.param_float("first_toll_at", 0.5)
	var second_at: float = maxf(activation.param_float("second_toll_at", 2.3), first_at)
	var third_at: float = maxf(activation.param_float("third_toll_at", 4.1), second_at)
	if first_at > 0.0:
		tween.tween_interval(first_at)
	tween.tween_callback(Callable(effect, "first_toll"))
	if second_at > first_at:
		tween.tween_interval(second_at - first_at)
	tween.tween_callback(Callable(effect, "second_toll"))
	if third_at > second_at:
		tween.tween_interval(third_at - second_at)
	tween.tween_callback(Callable(effect, "third_toll"))
	var lifetime: float = maxf(activation.param_float("lifetime", 6.4), third_at)
	if lifetime > third_at:
		tween.tween_interval(lifetime - third_at)
	return lifetime


static func _control_policy() -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 1.0,
			"allow_movement_lock": true,
			"allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.45,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": 0.25,
			"allow_movement_lock": false,
			"allow_execute": false,
		},
	}


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()


func first_toll() -> void:
	if _activation == null or _activation.is_finished():
		return
	toll_count_for_tests += 1
	var targets: Array = _activation.select_targets(
		_activation.origin(),
		INF,
		0,
		"nearest"
	)
	for raw_target in targets:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var status_id := "priest_ultimate_chime_%d_%d" % [get_instance_id(), target.get_instance_id()]
		var applied: Dictionary = _activation.apply_control(
			target,
			Vector2.ZERO,
			status_id,
			{
				"duration": _activation.param_float("interrupt_duration", 1.2),
				"movement_locked": true,
				"interrupted": true,
				"staggered": true,
				"speed_multiplier": 0.55,
			}
		)
		if bool(applied.get("status_applied", false)):
			_leased_statuses.append({"target": target, "status_id": status_id})
		_deal(
			target,
			_activation.scaled_damage("interrupt_damage", 0.0),
			"chime_interrupt:%d" % target.get_instance_id(),
			false,
			{"ultimate_mechanic": "chime_interrupt"}
		)


func second_toll() -> void:
	if _activation == null or _activation.is_finished():
		return
	toll_count_for_tests += 1
	var targets: Array = _activation.select_targets(
		_activation.origin(),
		INF,
		0,
		"nearest"
	)
	for index in targets.size():
		var target := targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var amount: float = _activation.scaled_damage("chain_damage", 0.0) \
			* maxf(
				pow(_activation.param_float("chain_falloff", 0.75), float(index)),
				_activation.param_float("chain_floor", 0.0)
			)
		_deal(
			target,
			amount,
			"chime_chain:%d" % target.get_instance_id(),
			index > 0,
			{"ultimate_mechanic": "chime_chain", "chain_index": index}
		)


func third_toll() -> void:
	if _activation == null or _activation.is_finished():
		return
	toll_count_for_tests += 1
	var player := _player()
	if player == null:
		return
	_activation.repair(
		player,
		chain_removed_for_tests * _activation.param_float("heal_ratio", 0.0),
		"chime_dawn_heal"
	)
	# `death_save` is an existing Player combat modifier. Activation owns and
	# reverses it at completion/cancel, yielding exactly one lethal-prevention
	# window without a Player or ClassWeapon special case.
	_activation.apply_modifier("death_save", 1.0, "add")


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary) -> void:
	if not ultimate_damage_sink.is_valid():
		return
	var result = ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)
	_play_impacts([target])
	if result != null:
		chain_removed_for_tests += maxf(float(result.applied), 0.0)


func _play_impacts(victims: Array) -> void:
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims, global_position)
	else:
		_impacts.play(VICTIM_FRAMES, victims, global_position)
		_impacts_started = true


func _player() -> Node:
	if _activation == null or _activation.host == null or not is_instance_valid(_activation.host):
		return null
	var player = _activation.host.get("player")
	return player as Node if player is Node and is_instance_valid(player) else null


func _exit_tree() -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
	_impacts = null
	_impacts_started = false
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
	_activation = null
