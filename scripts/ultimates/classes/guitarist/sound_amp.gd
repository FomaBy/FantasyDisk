extends Node2D

## Ultimate Direction v2 (FAN-3285): every feedback pulse and the overload
## reach every live enemy on the map, on screen and off — `amp_radius` and
## `square_half_side` are presentation only, never reach.
##
## Doubles as the root script of the authored presentation scene
## (GuitaristSoundAmpWallOfSound.tscn): the static half executes the
## mechanics, the instance half receives beat payloads while the scene is the
## live channel and plays the shared per-victim impact for the enemies each
## pulse and the overload actually struck.

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/guitarist/sound_amp/sound_amp_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.guitarist.sound_amp"
const EXECUTOR_ID := "weapon_ultimate.executor.guitarist.sound_amp"
const SELF_PATH := "res://scripts/ultimates/classes/guitarist/sound_amp.gd"

const CONTROL_POLICY := {
	"normal": {"displacement_multiplier": 1.0, "duration_multiplier": 1.0, "allow_movement_lock": false, "allow_execute": true},
	"epic": {"displacement_multiplier": 0.30, "duration_multiplier": 0.5, "allow_movement_lock": false, "allow_execute": true},
	"boss": {"displacement_multiplier": 0.0, "duration_multiplier": 0.25, "allow_movement_lock": false, "allow_execute": false},
}

var _impacts: Node2D = null
var _impacts_started := false


static func parameter_contract() -> Dictionary:
	return {
		"deploy_delay": {"type": "number", "minimum": 0.0},
		"pulse_count": {"type": "integer", "minimum": 4, "maximum": 4},
		"pulse_interval": {"type": "number", "minimum": 0.01},
		"overload_delay": {"type": "number", "minimum": 0.0},
		"recovery_tail": {"type": "number", "minimum": 0.0},
		"amp_radius": {"type": "number", "minimum": 1.0},
		"square_half_side": {"type": "number", "minimum": 1.0},
		"feedback_damage": {"type": "number", "minimum": 0.0},
		"overload_damage": {"type": "number", "minimum": 0.0},
		"feedback_duration": {"type": "number", "minimum": 0.0},
		"feedback_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"overload_knockback": {"type": "number", "minimum": 0.0},
		"per_target_cap_fraction": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"per_target_cap_flat": {"type": "number", "minimum": 0.0},
	}


static func execute(activation) -> float:
	if not activation.set_per_target_damage_cap(
		activation.param_float("per_target_cap_fraction", 0.30),
		activation.param_float("per_target_cap_flat", 0.0)
	) or not activation.set_control_resistance_policy(CONTROL_POLICY):
		return 0.0
	var state := {"points": _amp_points(activation), "pulses": 0, "linked": false}
	activation.set_primitive_state({"guitarist_wall_of_sound": state})
	var tween = activation.track_tween()
	if tween == null:
		return 0.0
	var script := load(SELF_PATH)
	tween.tween_interval(activation.param_float("deploy_delay", 0.68))
	tween.tween_callback(Callable(script, "deploy_stage").bind(activation, state))
	for pulse_index in activation.param_int("pulse_count", 4):
		if pulse_index > 0:
			tween.tween_interval(activation.param_float("pulse_interval", 0.27))
		tween.tween_callback(Callable(script, "feedback_pulse").bind(activation, state, pulse_index))
	tween.tween_interval(activation.param_float("overload_delay", 0.45))
	tween.tween_callback(Callable(script, "overload").bind(activation, state))
	tween.tween_interval(activation.param_float("recovery_tail", 4.06))
	return activation.param_float("deploy_delay", 0.68) \
		+ activation.param_float("pulse_interval", 0.27) \
			* float(activation.param_int("pulse_count", 4) - 1) \
		+ activation.param_float("overload_delay", 0.45) \
		+ activation.param_float("recovery_tail", 4.06)


static func deploy_stage(activation, state: Dictionary) -> void:
	if activation.is_finished():
		return
	for point in state["points"] as PackedVector2Array:
		activation.present(EXECUTOR_ID + ".amp", {"shape": "orb_burst", "position": point, "radius": 70.0})
	state["linked"] = true
	activation.present(EXECUTOR_ID + ".cables", {
		"shape": "ring_pulse", "position": activation.origin(),
		"radius": activation.param_float("square_half_side", 260.0),
	})


static func feedback_pulse(activation, state: Dictionary, pulse_index: int) -> void:
	if activation.is_finished() or not bool(state.get("linked", false)):
		return
	var victims: Array = []
	for raw_target in _live_targets(activation):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		activation.deal_damage(
			target,
			activation.scaled_damage("feedback_damage", 10.0),
			{"ultimate_mechanic": "amp_feedback", "pulse": pulse_index},
			"feedback:%d" % pulse_index
		)
		activation.apply_control(target, Vector2.ZERO, "feedback:%d:%d" % [pulse_index, target.get_instance_id()], {
			"duration": activation.param_float("feedback_duration", 2.0),
			"speed_multiplier": activation.param_float("feedback_slow", 0.52),
			"feedback_field": true,
		})
		victims.append(target)
	state["pulses"] = int(state.get("pulses", 0)) + 1
	activation.present(EXECUTOR_ID + ".feedback:%d" % pulse_index, {
		"shape": "ring_pulse", "position": activation.origin(),
		"radius": activation.param_float("square_half_side", 260.0),
		"victims": victims,
	})


static func overload(activation, state: Dictionary) -> void:
	if activation.is_finished() or not bool(state.get("linked", false)):
		return
	var victims: Array = []
	for raw_target in _live_targets(activation):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var away: Vector2 = target.global_position - activation.origin()
		var impulse: Vector2 = away.normalized() * activation.param_float("overload_knockback", 880.0) \
			if away.length_squared() > 0.001 else Vector2.ZERO
		activation.deal_damage(target, activation.scaled_damage("overload_damage", 40.0), {
			"ultimate_mechanic": "amp_overload",
		}, "overload")
		activation.apply_control(target, impulse, "overload:%d" % target.get_instance_id(), {
			"duration": 0.5, "speed_multiplier": 0.75, "feedback_overload": true,
		})
		victims.append(target)
	var points := state["points"] as PackedVector2Array
	for index in points.size():
		var payload := {"shape": "orb_burst", "position": points[index], "radius": 120.0}
		if index == 0:
			# The overload strikes once; only one of its four point bursts may
			# carry the victims, or the per-victim ripple would play fourfold.
			payload["victims"] = victims
		activation.present(EXECUTOR_ID + ".overload", payload)


func present(_event_id: String, payload: Dictionary) -> void:
	_play_impacts(payload.get("victims"))


func finish(_reason: String) -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()


func _play_impacts(raw_victims: Variant) -> void:
	if not raw_victims is Array or (raw_victims as Array).is_empty():
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(raw_victims as Array, global_position)
	else:
		_impacts.play(VICTIM_FRAMES, raw_victims as Array, global_position)
		_impacts_started = true


func _exit_tree() -> void:
	_impacts = null
	_impacts_started = false


static func _amp_points(activation) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius: float = activation.param_float("amp_radius", 260.0)
	for index in 4:
		points.append(activation.origin() + Vector2.RIGHT.rotated(TAU * float(index) / 4.0) * radius)
	return points


static func _live_targets(activation) -> Array:
	return activation.select_targets(activation.origin(), INF, 0, "nearest")
