extends Node2D

## Берсерк / Двуручный молот — «Раскол Четырёх Сторон».
##
## Three ordered beats, never any other order: four cardinal ground lanes, then
## the four diagonals, then one central quake that staggers and launches what
## survived. The order is the mechanic, so a beat that arrives out of turn
## aborts the composition instead of resolving on its own.
##
## Ultimate Direction v2 (FAN-2953): every beat reaches every live enemy on the
## map, on screen and off — the ground lanes and the quake ring are
## presentation, never reach. Lane membership is attribution only; the stagger
## launches every survivor straight away from the hero.

const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/berserk/hammer/victim_impact/victim_impact_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.berserk.hammer"
const EXECUTOR_ID := "weapon_ultimate.executor.berserk.hammer"
const EFFECT_SCENE := "res://scripts/ultimates/classes/berserk/hammer.tscn"

const STEPS := ["cardinal_lanes", "diagonal_lanes", "central_quake"]

var ultimate_damage_sink: Callable = Callable()
var staggered_count_for_tests := 0
var lane_hits_for_tests := 0

var _activation = null
var _impacts: Node2D = null
var _impacts_started := false
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
	var step_id := str(STEPS[step])
	var damage_key := "cardinal_damage" if step == 0 else "diagonal_damage"
	var fallback := 12.0 if step == 0 else 13.0
	_activation.present(EXECUTOR_ID + "." + step_id, {
		"position": center, "radius": length, "shape": "rift_lanes",
	})
	# One event id per beat: the four lanes are one synchronized impact. Lane
	# membership is attribution, so the beat itself walks every live enemy.
	var crushed: Array[Node] = []
	for raw_target in _activation.select_targets(center, INF, 0, "nearest"):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		lane_hits_for_tests += 1
		_deal(
			target,
			_activation.scaled_damage(damage_key, fallback),
			"rift:" + step_id,
			"fourfold_rift_" + step_id
		)
		crushed.append(target)
	_play_impacts(crushed)


func _central_quake() -> void:
	var center: Vector2 = _activation.origin()
	global_position = center
	var radius: float = _activation.param_float("quake_radius", 330.0)
	var crushed: Array[Node2D] = []
	var impulse: float = _activation.param_float("stagger_impulse", 460.0)
	_activation.present(EXECUTOR_ID + ".central_quake", {
		"position": center, "radius": radius, "shape": "quake_ring",
	})
	for raw_target in _activation.select_targets(center, INF, 0, "nearest"):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		crushed.append(target)
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
	_play_impacts(crushed)


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


## Per-victim read (FAN-3008): every crushed enemy pops its own ground-shatter
## burst on top of its white hit flash, staggered outward from the hero. Beats
## land closer together than one ripple spans, so each beat joins the running
## ripple instead of replacing it.
func _play_impacts(victims: Array) -> void:
	if victims.is_empty() or _activation == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(victims, _activation.origin())
	else:
		_impacts.play(VICTIM_FRAMES, victims, _activation.origin())
		_impacts_started = true


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
