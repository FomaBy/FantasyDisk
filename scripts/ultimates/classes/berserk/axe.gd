extends Node2D

## Берсерк / Двуручный топор — «Петля Палача».
##
## One giant axe flies along the aim to the arena edge, marks everything on the
## outbound corridor, turns, and detonates on the way back. A marked normal
## target under the execute threshold takes the finishing blow; resistant tiers
## are denied the execute by the control policy and a boss can never be touched
## by more than the two declared passes.

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.berserk.axe"
const EXECUTOR_ID := "weapon_ultimate.executor.berserk.axe"
const EFFECT_SCENE := "res://scripts/ultimates/classes/berserk/axe.tscn"

const MARK_KEY := "execution_mark"
const PASS_KEY := "execution_pass"

var ultimate_damage_sink: Callable = Callable()
var marked_count_for_tests := 0
var executed_count_for_tests := 0
var edge_for_tests := Vector2.ZERO
var beat_trace_for_tests: Array[String] = []

var _activation = null
var _resolved_beats := {}
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"outbound_seconds": {"type": "number", "minimum": 0.01},
		"return_seconds": {"type": "number", "minimum": 0.01},
		"arena_radius": {"type": "number", "minimum": 1.0},
		"corridor_half_width": {"type": "number", "minimum": 1.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"outbound_damage": {"type": "number", "minimum": 0.0},
		"return_damage": {"type": "number", "minimum": 0.0},
		"execute_damage": {"type": "number", "minimum": 0.0},
		"execute_threshold": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_pass_cap": {"type": "integer", "minimum": 1},
		"mark_duration": {"type": "number", "minimum": 0.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 0.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": true,
		},
		"epic": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": activation.param_float("epic_duration", 0.45),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": 0.0,
			"duration_multiplier": activation.param_float("boss_duration", 0.2),
			"allow_movement_lock": false, "allow_execute": false,
		},
	}):
		return 0.0
	var effect = activation.spawn(EFFECT_SCENE)
	if effect == null or not effect.has_method("configure"):
		return 0.0
	effect.call("configure", activation)
	var tween: Tween = activation.track_tween()
	if tween == null:
		return 0.0
	var release_delay: float = activation.param_float("release_delay", 0.45)
	var outbound: float = activation.param_float("outbound_seconds", 2.2)
	var inbound: float = activation.param_float("return_seconds", 2.4)
	tween.tween_interval(release_delay)
	tween.tween_callback(Callable(effect, "launch"))
	tween.tween_interval(outbound)
	tween.tween_callback(Callable(effect, "turn"))
	tween.tween_interval(inbound)
	tween.tween_callback(Callable(effect, "catch"))
	var elapsed := release_delay + outbound + inbound
	var lifetime: float = activation.param_float("lifetime", 5.85)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


## Class-local arena bounds query: the loop always reaches the declared arena
## radius along the aim, never the (usually much closer) aim point itself.
static func arena_edge(source: Vector2, aim: Vector2, arena_radius: float) -> Vector2:
	var axis := aim if aim.length_squared() > 0.001 else Vector2.RIGHT
	return source + axis.normalized() * maxf(arena_radius, 0.0)


## Class-local trajectory sample between the hero and the arena edge.
static func trajectory_point(source: Vector2, edge: Vector2, ratio: float) -> Vector2:
	return source.lerp(edge, clampf(ratio, 0.0, 1.0))


## Class-local execute threshold: only a target already below the declared
## share of its own pool can be finished by the return catch.
static func execute_ready(health: float, max_health: float, threshold: float) -> bool:
	return max_health > 0.0 and health > 0.0 and health / max_health <= threshold


## Class-local double-pass cap: `passes` is the number of loop contacts a
## target already took, `cap` the declared ceiling for its tier.
static func pass_allowed(passes: float, cap: int) -> bool:
	return passes < float(cap)


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	edge_for_tests = arena_edge(
		activation.origin(),
		activation.aim_direction(activation.param_float("arena_radius", 900.0)),
		activation.param_float("arena_radius", 900.0)
	)


func launch() -> void:
	if not _beat("outbound"):
		return
	var source: Vector2 = _activation.origin()
	global_position = source
	_activation.present(EXECUTOR_ID + ".outbound", {
		"position": trajectory_point(source, edge_for_tests, 0.5),
		"radius": _activation.param_float("corridor_half_width", 130.0),
		"shape": "axe_pass",
	})
	for raw_target in _corridor(source, edge_for_tests - source):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target) or not _claim_pass(target, "outbound"):
			continue
		_mark(target)
		_deal(
			target,
			_activation.scaled_damage("outbound_damage", 17.0),
			"loop:outbound",
			"execution_loop_outbound"
		)


func turn() -> void:
	if not _beat("turn"):
		return
	global_position = edge_for_tests
	_activation.present(EXECUTOR_ID + ".turn", {
		"position": edge_for_tests,
		"radius": _activation.param_float("corridor_half_width", 130.0),
		"shape": "axe_turn",
	})


func catch() -> void:
	if not _beat("return"):
		return
	var source: Vector2 = _activation.origin()
	global_position = source
	_activation.present(EXECUTOR_ID + ".detonation", {
		"position": trajectory_point(source, edge_for_tests, 0.25),
		"radius": _activation.param_float("corridor_half_width", 130.0),
		"shape": "axe_detonation",
	})
	var threshold: float = _activation.param_float("execute_threshold", 0.3)
	for raw_target in _corridor(edge_for_tests, source - edge_for_tests):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target) or not _claim_pass(target, "return"):
			continue
		_deal(
			target,
			_activation.scaled_damage("return_damage", 27.0),
			"loop:return",
			"execution_loop_return"
		)
		# The outbound mark already recorded whether this tier may be executed.
		var marked = _activation.consume_target_value(target, MARK_KEY, "loop:execute", false)
		if not bool(marked):
			continue
		if not execute_ready(
			float(target.get("health") if target.get("health") != null else 0.0),
			float(target.get("max_health") if target.get("max_health") != null else 0.0),
			threshold
		):
			continue
		executed_count_for_tests += 1
		_deal(
			target,
			_activation.scaled_damage("execute_damage", 16.0),
			"loop:execute",
			"execution_loop_execute"
		)


func _corridor(start: Vector2, offset: Vector2) -> Array:
	return _activation.targets_in_corridor(
		start,
		offset,
		offset.length(),
		_activation.param_float("corridor_half_width", 130.0),
		_activation.param_int("crowd_cap", 18)
	)


func _beat(beat_id: String) -> bool:
	if not _live() or _resolved_beats.has(beat_id):
		return false
	_resolved_beats[beat_id] = true
	beat_trace_for_tests.append(beat_id)
	return true


## The cap applies to every tier; only a boss can actually reach it, because a
## normal target spends its third contact on the execute rather than on a pass.
func _claim_pass(target: Node, beat_id: String) -> bool:
	var passes = _activation.target_value(target, PASS_KEY, 0.0)
	var taken := float(passes) if (passes is int or passes is float) and not passes is bool else 0.0
	if not pass_allowed(taken, _activation.param_int("boss_pass_cap", 2)):
		return false
	return _activation.add_target_value(target, PASS_KEY, 1.0, "loop:pass:" + beat_id)


## The mark carries the tier's own execute permission, so the return catch never
## re-derives a policy decision the outbound pass already made.
func _mark(target: Node) -> void:
	var status_id := "berserk_ultimate_loop_mark_%d" % get_instance_id()
	var applied: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
		"duration": _activation.param_float("mark_duration", 3.2),
		"execution_mark": true,
	})
	if not _activation.record_target_value(
		target, MARK_KEY, bool(applied.get("execute_allowed", false)), "loop:mark"
	):
		return
	marked_count_for_tests += 1
	if bool(applied.get("status_applied", false)):
		_leased_statuses.append({"target": target, "status_id": status_id})


func _deal(target: Node, amount: float, event_id: String, mechanic: String) -> void:
	if ultimate_damage_sink.is_valid():
		ultimate_damage_sink.call(
			target, amount, {"ultimate_mechanic": mechanic}, event_id, false
		)


func _live() -> bool:
	return _activation != null and not _activation.is_finished()


func _exit_tree() -> void:
	for lease in _leased_statuses:
		_remove_leased_status(lease)
	_leased_statuses.clear()
	_activation = null


static func _remove_leased_status(lease: Dictionary) -> void:
	var target = lease.get("target")
	if target == null or not is_instance_valid(target) \
			or not (target as Node).has_meta(StatusEffects.META_KEY):
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
