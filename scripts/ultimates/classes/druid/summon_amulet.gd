extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.druid.summon_amulet"
const EXECUTOR_ID := "weapon_ultimate.executor.druid.summon_amulet"
const EFFECT_SCENE := "res://scripts/ultimates/classes/druid/summon_amulet.tscn"

var ultimate_damage_sink: Callable = Callable()
var pack_count_for_tests := 0
var hunt_waves_for_tests := 0

var _activation = null
var _targets: Array = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"hunt_interval": {"type": "number", "minimum": 0.01},
		"hunt_waves": {"type": "integer", "minimum": 1},
		"pack_count": {"type": "integer", "minimum": 1, "maximum": 8},
		"hunt_range": {"type": "number", "minimum": 1.0},
		"target_cap": {"type": "integer", "minimum": 1},
		"hunt_splash_radius": {"type": "number", "minimum": 0.0},
		"hunt_splash_target_cap": {"type": "integer", "minimum": 1},
		"splash_damage_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"stampede_damage": {"type": "number", "minimum": 0.0},
		"hunt_damage": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.85)
	var hunt_interval: float = activation.param_float("hunt_interval", 0.75)
	var waves: int = activation.param_int("hunt_waves", 6)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "stampede"))
	for wave in waves:
		tween.tween_interval(hunt_interval)
		tween.tween_callback(Callable(effect, "hunt").bind(wave))
	var elapsed: float = release_delay + hunt_interval * float(waves)
	var lifetime: float = activation.param_float("lifetime", 6.6)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	pack_count_for_tests = activation.param_int("pack_count", 8)


func stampede() -> void:
	if _activation == null or _activation.is_finished():
		return
	_targets = _activation.select_targets(
		_activation.origin(),
		_activation.param_float("hunt_range", 560.0),
		_activation.param_int("target_cap", 12),
		"highest_hp"
	)
	for beast in pack_count_for_tests:
		var target := _target_for(beast)
		if target != null:
			_strike(target, _activation.scaled_damage("stampede_damage", 7.0),
				"wild_hunt:stampede:%d" % beast,
				{"ultimate_mechanic": "wild_hunt_stampede", "beast": beast})
	_activation.present(EXECUTOR_ID + ".stampede", {
		"position": _activation.origin(), "radius": _activation.param_float("hunt_range", 560.0),
		"shape": "ring_pulse",
	})


func hunt(wave: int) -> void:
	if _activation == null or _activation.is_finished():
		return
	hunt_waves_for_tests += 1
	for beast in pack_count_for_tests:
		var target := _target_for(beast)
		if target != null:
			_strike(target, _activation.scaled_damage("hunt_damage", 2.5),
				"wild_hunt:hunt:%d:%d" % [wave, beast],
				{"ultimate_mechanic": "wild_hunt_priority", "wave": wave, "beast": beast})


func _target_for(index: int) -> Node:
	if _targets.is_empty():
		return null
	var target := _targets[index % _targets.size()] as Node
	return target if target != null and is_instance_valid(target) else null


func _strike(target: Node, amount: float, event_id: String, feedback: Dictionary) -> void:
	_deal(target, amount, event_id, feedback)
	var anchor := target as Node2D
	if anchor == null:
		return
	var splashed := 0
	for raw_neighbor in _activation.select_targets(
		anchor.global_position,
		_activation.param_float("hunt_splash_radius", 160.0),
		_activation.param_int("hunt_splash_target_cap", 4),
		"nearest"
	):
		var neighbor := raw_neighbor as Node
		if neighbor == null or neighbor == target or not is_instance_valid(neighbor):
			continue
		splashed += 1
		var splash_feedback := feedback.duplicate(true)
		splash_feedback["ultimate_mechanic"] = "wild_hunt_splash"
		_deal(neighbor, amount * _activation.param_float("splash_damage_ratio", 0.65),
			"%s:splash:%d" % [event_id, splashed], splash_feedback, true)


func _deal(
	target: Node, amount: float, event_id: String, feedback: Dictionary, secondary := false
) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _exit_tree() -> void:
	_targets.clear()
	_activation = null
