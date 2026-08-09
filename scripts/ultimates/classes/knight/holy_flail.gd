extends Node2D

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.knight.holy_flail"
const EXECUTOR_ID := "weapon_ultimate.executor.knight.holy_flail"
const EFFECT_SCENE := "res://scripts/ultimates/classes/knight/holy_flail.tscn"

var ultimate_damage_sink: Callable = Callable()
var direction_switches_for_tests := 0
var turn_count_for_tests := 0

var _activation = null
var _state: Dictionary = {}
var _next_turn := 0
var _resolved_turns := {}
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"turn_interval": {"type": "number", "minimum": 0.01},
		"turn_count": {"type": "integer", "minimum": 2, "maximum": 12},
		"inner_radius": {"type": "number", "minimum": 1.0},
		"outer_radius": {"type": "number", "minimum": 1.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"pull_damage": {"type": "number", "minimum": 0.0},
		"launch_damage": {"type": "number", "minimum": 0.0},
		"pull_force": {"type": "number", "minimum": 0.0},
		"launch_force": {"type": "number", "minimum": 0.0},
		"control_duration": {"type": "number", "minimum": 0.0},
		"pull_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"launch_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
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
	if effect == null or not effect.has_method("configure"):
		return 0.0
	var state := {
		"turns": [],
		"radii": [],
		"impulses": [],
		"direction_switches": 0,
	}
	activation.set_primitive_state({"knight_holy_flail": state})
	effect.call("configure", activation, state)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 1.6)
	var interval: float = activation.param_float("turn_interval", 0.75)
	var turns: int = activation.param_int("turn_count", 7)
	var elapsed := release_delay
	tween.tween_interval(release_delay)
	for turn_index in turns:
		tween.tween_callback(Callable(effect, "turn").bind(turn_index))
		if turn_index < turns - 1:
			tween.tween_interval(interval)
			elapsed += interval
	var lifetime: float = activation.param_float("lifetime", 7.6)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


static func radius_for_turn(
	turn_index: int, turn_count: int, inner_radius: float, outer_radius: float
) -> float:
	if turn_count <= 1:
		return maxf(outer_radius, 0.0)
	return lerpf(inner_radius, outer_radius, clampf(
		float(turn_index) / float(turn_count - 1), 0.0, 1.0
	))


static func _control_policy(activation) -> Dictionary:
	return {
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": activation.param_float("epic_displacement", 0.35),
			"duration_multiplier": activation.param_float("epic_duration", 0.5),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": activation.param_float("boss_displacement", 0.0),
			"duration_multiplier": activation.param_float("boss_duration", 0.2),
			"allow_movement_lock": false, "allow_execute": false,
		},
	}


func configure(activation, state: Dictionary) -> void:
	_activation = activation
	_state = state
	global_position = activation.origin()


## A repeated callback is a no-op; a genuinely out-of-order callback aborts the
## composition. Thus neither replay nor a stale timer can add damage or impulse.
func turn(turn_index: int) -> void:
	if not _live() or turn_index < 0:
		return
	if _resolved_turns.has(turn_index):
		return
	var turn_count: int = _activation.param_int("turn_count", 7)
	if turn_index != _next_turn or turn_index >= turn_count:
		_activation.abort_composition()
		return
	_resolved_turns[turn_index] = true
	_next_turn += 1
	turn_count_for_tests += 1
	var final_turn := turn_index == turn_count - 1
	if final_turn:
		direction_switches_for_tests += 1
		_state["direction_switches"] = direction_switches_for_tests
	var step_id := "launch_%d" % turn_index if final_turn else "pull_%d" % turn_index
	_activation.composition_step(step_id)
	var radius := radius_for_turn(
		turn_index,
		turn_count,
		_activation.param_float("inner_radius", 90.0),
		_activation.param_float("outer_radius", 430.0)
	)
	(_state["turns"] as Array).append(step_id)
	(_state["radii"] as Array).append(radius)
	_resolve_targets(turn_index, radius, final_turn)


func _resolve_targets(turn_index: int, radius: float, final_turn: bool) -> void:
	var center: Vector2 = _activation.origin()
	global_position = center
	var signed_force: float = _activation.param_float("launch_force", 720.0) if final_turn \
		else -_activation.param_float("pull_force", 240.0)
	var damage_key := "launch_damage" if final_turn else "pull_damage"
	var fallback_damage := 10.0 if final_turn else 4.0
	var seen := {}
	for raw_target in _activation.select_targets(
		center, radius, _activation.param_int("crowd_cap", 20), "nearest"
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_id := target.get_instance_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		var outward: Vector2 = target.global_position - center
		if outward.length_squared() <= 0.001:
			outward = Vector2.RIGHT
		var status_id := "knight_ultimate_spiral_%d" % get_instance_id()
		var applied: Dictionary = _activation.apply_control(
			target,
			outward.normalized() * signed_force,
			status_id,
			{
				"duration": _activation.param_float("control_duration", 1.2),
				"speed_multiplier": _activation.param_float(
					"launch_slow" if final_turn else "pull_slow", 0.85 if final_turn else 0.72
				),
				"holy_flail_turn": turn_index,
			}
		)
		if bool(applied.get("status_applied", false)):
			_lease_status(target, status_id)
		(_state["impulses"] as Array).append({
			"turn": turn_index,
			"target_id": target_id,
			"tier": str(applied.get("tier", "")),
			"signed_force": signed_force,
			"displaced": bool(applied.get("displaced", false)),
		})
		_deal(
			target,
			_activation.scaled_damage(damage_key, fallback_damage),
			"holy_flail:turn:%d" % turn_index,
			"holy_flail_launch" if final_turn else "holy_flail_pull"
		)


func _lease_status(target: Node, status_id: String) -> void:
	for lease in _leased_statuses:
		if lease.get("target") == target and str(lease.get("status_id", "")) == status_id:
			return
	_leased_statuses.append({"target": target, "status_id": status_id})


func _deal(target: Node, amount: float, event_id: String, mechanic: String) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(
			target, amount, {"ultimate_mechanic": mechanic}, event_id, false
		)


func _live() -> bool:
	return _activation != null and not _activation.is_finished() \
		and not _activation.composition_aborted()


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_resolved_turns.clear()
	_state.clear()
	_activation = null


static func _remove_leased_status(lease: Dictionary) -> void:
	var target = lease.get("target") as Node
	if target == null or not is_instance_valid(target) \
			or not target.has_meta(StatusEffects.META_KEY):
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
