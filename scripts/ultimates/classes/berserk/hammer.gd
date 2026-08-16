extends Node2D

## Берсерк / Двуручный молот — «Раскол Четырёх Сторон».
##
## Three ordered beats, never any other order: four cardinal ground lanes, then
## the four diagonals, then one central quake that staggers and launches what
## survived. The order is the mechanic, so a beat that arrives out of turn
## aborts the composition instead of resolving on its own.

const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.berserk.hammer"
const EXECUTOR_ID := "weapon_ultimate.executor.berserk.hammer"
const EFFECT_SCENE := "res://scripts/ultimates/classes/berserk/hammer.tscn"

const STEPS := ["cardinal_lanes", "diagonal_lanes", "central_quake"]

var ultimate_damage_sink: Callable = Callable()
var staggered_count_for_tests := 0
var lane_hits_for_tests := 0

var _activation = null
var _next_step := 0
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"beat_interval": {"type": "number", "minimum": 0.01},
		"lane_length": {"type": "number", "minimum": 1.0},
		"lane_half_width": {"type": "number", "minimum": 1.0},
		"quake_radius": {"type": "number", "minimum": 1.0},
		"crowd_cap": {"type": "integer", "minimum": 1},
		"cardinal_damage": {"type": "number", "minimum": 0.0},
		"diagonal_damage": {"type": "number", "minimum": 0.0},
		"quake_damage": {"type": "number", "minimum": 0.0},
		"stagger_impulse": {"type": "number", "minimum": 0.0},
		"stagger_duration": {"type": "number", "minimum": 0.0},
		"epic_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_displacement": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 1.0, "duration_multiplier": 1.0,
			"allow_movement_lock": true, "allow_execute": false,
		},
		"epic": {
			"displacement_multiplier": activation.param_float("epic_displacement", 0.35),
			"duration_multiplier": activation.param_float("epic_duration", 0.45),
			"allow_movement_lock": false, "allow_execute": false,
		},
		"boss": {
			"displacement_multiplier": activation.param_float("boss_displacement", 0.1),
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
	var release_delay: float = activation.param_float("release_delay", 0.7)
	var interval: float = activation.param_float("beat_interval", 0.85)
	tween.tween_interval(release_delay)
	var elapsed := release_delay
	for step in STEPS.size():
		if step > 0:
			tween.tween_interval(interval)
			elapsed += interval
		tween.tween_callback(Callable(effect, "beat").bind(step))
	var lifetime: float = activation.param_float("lifetime", 3.4)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


## Class-local lane geometry: the cardinal beat uses the world axes, the
## diagonal beat the same axes rotated by a half step.
static func lane_axes(step: int) -> Array[Vector2]:
	var axes: Array[Vector2] = []
	var offset := PI * 0.25 if step == 1 else 0.0
	for lane in 4:
		axes.append(Vector2.RIGHT.rotated(offset + float(lane) * PI * 0.5))
	return axes


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()


func beat(step: int) -> void:
	if not _live():
		return
	if step != _next_step:
		_activation.abort_composition()
		return
	_next_step += 1
	_activation.composition_step(str(STEPS[step]))
	if step == STEPS.size() - 1:
		_central_quake()
		return
	_lanes(step)


func _lanes(step: int) -> void:
	var center: Vector2 = _activation.origin()
	global_position = center
	var length: float = _activation.param_float("lane_length", 460.0)
	var half_width: float = _activation.param_float("lane_half_width", 96.0)
	var crowd_cap: int = _activation.param_int("crowd_cap", 20)
	var step_id := str(STEPS[step])
	var damage_key := "cardinal_damage" if step == 0 else "diagonal_damage"
	var fallback := 12.0 if step == 0 else 13.0
	_activation.present(EXECUTOR_ID + "." + step_id, {
		"position": center, "radius": length, "shape": "rift_lanes",
	})
	var targets: Array[Node] = []
	var seen := {}
	for axis in lane_axes(step):
		for raw_target in _activation.targets_in_corridor(
			center, axis, length, half_width, 0
		):
			var target := raw_target as Node
			if target == null or not is_instance_valid(target) \
					or seen.has(target.get_instance_id()):
				continue
			seen[target.get_instance_id()] = true
			targets.append(target)
			if targets.size() >= crowd_cap:
				break
		if targets.size() >= crowd_cap:
			break
	# One cap and event id per beat: the four lanes are one synchronized
	# impact, including where they overlap at the hero.
	for target in targets:
		lane_hits_for_tests += 1
		_deal(
			target,
			_activation.scaled_damage(damage_key, fallback),
			"rift:" + step_id,
			"fourfold_rift_" + step_id
		)


func _central_quake() -> void:
	var center: Vector2 = _activation.origin()
	global_position = center
	var radius: float = _activation.param_float("quake_radius", 330.0)
	var impulse: float = _activation.param_float("stagger_impulse", 460.0)
	_activation.present(EXECUTOR_ID + ".central_quake", {
		"position": center, "radius": radius, "shape": "quake_ring",
	})
	for raw_target in _activation.select_targets(
		center, radius, _activation.param_int("crowd_cap", 20), "nearest"
	):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var outward := target.global_position - center
		if outward.length_squared() <= 0.001:
			outward = Vector2.RIGHT
		var status_id := "berserk_ultimate_stagger_%d" % get_instance_id()
		var applied: Dictionary = _activation.apply_control(
			target,
			outward.normalized() * impulse,
			status_id,
			{
				"duration": _activation.param_float("stagger_duration", 1.4),
				"movement_locked": true,
				"fourfold_stagger": true,
			}
		)
		if bool(applied.get("displaced", false)):
			staggered_count_for_tests += 1
		if bool(applied.get("status_applied", false)):
			_lease_status(target, status_id)
		_deal(
			target,
			_activation.scaled_damage("quake_damage", 18.0),
			"rift:central_quake",
			"fourfold_rift_central_quake"
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
