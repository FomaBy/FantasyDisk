extends Node2D

const PROFILE_ID := "weapon_ultimate.profile.priest.priest_censer"
const EXECUTOR_ID := "weapon_ultimate.executor.priest.priest_censer"
const EFFECT_SCENE := "res://scripts/ultimates/classes/priest/priest_censer.tscn"

var ultimate_damage_sink: Callable = Callable()
var stored_prevented_for_tests := 0.0
var counter_burst_for_tests := 0.0

var _activation = null
var _player: Node = null
var _signal_connected := false


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"ward_absorb": {"type": "number", "minimum": 0.0},
		"stored_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"stored_cap": {"type": "number", "minimum": 0.0},
		"counter_at": {"type": "number", "minimum": 0.0},
		"counter_damage_cap": {"type": "number", "minimum": 0.0},
		"counter_radius": {"type": "number", "minimum": 0.0},
		"counter_target_cap": {"type": "integer", "minimum": 1},
		"counter_falloff": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	activation.apply_modifier("absorb_flat", activation.scaled_damage("ward_absorb", 0.0), "add")
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var counter_at: float = activation.param_float("counter_at", 6.3)
	if counter_at > 0.0:
		tween.tween_interval(counter_at)
	tween.tween_callback(Callable(effect, "counter_burst"))
	var lifetime: float = maxf(activation.param_float("lifetime", 7.6), counter_at)
	if lifetime > counter_at:
		tween.tween_interval(lifetime - counter_at)
	return lifetime


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	_player = _player_from_host()
	if _player != null and _player.has_signal("constellation_final_resolved"):
		_player.connect("constellation_final_resolved", Callable(self, "_on_constellation_final_resolved"))
		_signal_connected = true


## Player emits this after the pre-defense ward/absorb channel has measured an
## actual prevented amount. The ultimate stores a capped fraction of that real
## value; it never derives a counter from attempted incoming damage.
func _on_constellation_final_resolved(
	_weapon_id: String,
	event: String,
	_target: Node2D,
	context: Dictionary,
	_resolution: Dictionary
) -> void:
	if _activation == null or _activation.is_finished() or event != "damage_absorbed":
		return
	var prevented := maxf(float(context.get("absorbed_amount", 0.0)), 0.0)
	if prevented <= 0.0:
		return
	var cap: float = _activation.scaled_damage("stored_cap", 0.0)
	stored_prevented_for_tests = minf(
		stored_prevented_for_tests + prevented * _activation.param_float("stored_ratio", 0.0),
		cap
	)


func counter_burst() -> void:
	if _activation == null or _activation.is_finished() or stored_prevented_for_tests <= 0.0:
		return
	counter_burst_for_tests = minf(
		stored_prevented_for_tests,
		_activation.scaled_damage("counter_damage_cap", 0.0)
	)
	if counter_burst_for_tests <= 0.0:
		return
	var targets: Array = _activation.select_targets(
		_activation.origin(),
		_activation.param_float("counter_radius", 360.0),
		_activation.param_int("counter_target_cap", 12),
		"nearest"
	)
	for index in targets.size():
		var target := targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		_deal(
			target,
			counter_burst_for_tests * pow(_activation.param_float("counter_falloff", 1.0), float(index)),
			"censer_counter:%d" % target.get_instance_id(),
			true,
			{"ultimate_mechanic": "censer_stored_counter", "prevented_damage": stored_prevented_for_tests}
		)


func _deal(target: Node, amount: float, event_id: String, secondary: bool, feedback: Dictionary) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(target, amount, feedback, event_id, secondary)


func _player_from_host() -> Node:
	if _activation == null or _activation.host == null or not is_instance_valid(_activation.host):
		return null
	var player = _activation.host.get("player")
	return player as Node if player is Node and is_instance_valid(player) else null


func _exit_tree() -> void:
	if _signal_connected and _player != null and is_instance_valid(_player) \
			and _player.is_connected("constellation_final_resolved", Callable(self, "_on_constellation_final_resolved")):
		_player.disconnect("constellation_final_resolved", Callable(self, "_on_constellation_final_resolved"))
	_signal_connected = false
	_player = null
	_activation = null
