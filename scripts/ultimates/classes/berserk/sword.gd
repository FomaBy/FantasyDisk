extends Node2D

## Берсерк / Двуручный меч — «Алый Вихрь».
##
## Three spectral blades take turns on one expanding orbit: every sweep belongs
## to exactly one blade, and a blade may not touch the same target again before
## its own cooldown elapsed. The cast ends with the blades collapsing inward
## into an aim-oriented cross slash.
##
## Ultimate Direction v2 (FAN-2953): every sweep bites every live enemy on the
## map, on screen and off — the expanding orbit is presentation, never reach.
## The cross stays geometric: the sweeps are the guaranteed floor, the collapse
## is the aimed bonus layered on top of it.

const StatusEffects := preload("res://scripts/status_effects.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const VICTIM_FRAMES := preload("res://assets/sprites/effects/berserk/sword/victim_explosion/victim_explosion_spriteframes.tres")

const PROFILE_ID := "weapon_ultimate.profile.berserk.sword"
const EXECUTOR_ID := "weapon_ultimate.executor.berserk.sword"
const EFFECT_SCENE := "res://scripts/ultimates/classes/berserk/sword.tscn"

var ultimate_damage_sink: Callable = Callable()
var sweep_radii_for_tests: Array[float] = []
var blade_hits_for_tests: Array[int] = []
var cross_count_for_tests := 0

var _activation = null
var _impacts: Node2D = null
var _impacts_started := false
var _resolved_sweeps := {}
var _cross_done := false
var _leased_statuses: Array[Dictionary] = []


static func parameter_contract() -> Dictionary:
	return {
		"lifetime": {"type": "number", "minimum": 0.1},
		"release_delay": {"type": "number", "minimum": 0.0},
		"sweep_interval": {"type": "number", "minimum": 0.01},
		"sweep_count": {"type": "integer", "minimum": 2},
		"blade_count": {"type": "integer", "minimum": 3, "maximum": 3},
		"blade_hit_cooldown": {"type": "number", "minimum": 0.0},
		"orbit_start_radius": {"type": "number", "minimum": 1.0},
		"orbit_end_radius": {"type": "number", "minimum": 1.0},
		"blade_damage": {"type": "number", "minimum": 0.0},
		"cross_at": {"type": "number", "minimum": 0.0},
		"cross_length": {"type": "number", "minimum": 1.0},
		"cross_half_width": {"type": "number", "minimum": 1.0},
		"cross_damage": {"type": "number", "minimum": 0.0},
		"vortex_duration": {"type": "number", "minimum": 0.0},
		"vortex_slow": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"epic_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"boss_duration": {"type": "number", "minimum": 0.0, "maximum": 1.0},
	}


static func execute(activation) -> float:
	if not activation.set_control_resistance_policy({
		"normal": {
			"displacement_multiplier": 0.0, "duration_multiplier": 1.0,
			"allow_movement_lock": false, "allow_execute": false,
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
	var release_delay: float = activation.param_float("release_delay", 0.6)
	var interval: float = activation.param_float("sweep_interval", 0.55)
	var sweeps: int = activation.param_int("sweep_count", 11)
	tween.tween_interval(release_delay)
	var elapsed := release_delay
	for sweep in sweeps:
		if sweep > 0:
			tween.tween_interval(interval)
			elapsed += interval
		tween.tween_callback(Callable(effect, "sweep_blade").bind(sweep))
	var cross_at: float = activation.param_float("cross_at", 6.9)
	if cross_at > elapsed:
		tween.tween_interval(cross_at - elapsed)
		elapsed = cross_at
	tween.tween_callback(Callable(effect, "cross_slash"))
	var lifetime: float = activation.param_float("lifetime", 7.45)
	if lifetime > elapsed:
		tween.tween_interval(lifetime - elapsed)
	return maxf(lifetime, elapsed)


## Expanding orbit: the first sweep rides the inner radius, the last one the
## outer radius, so the reach grows monotonically across the cast.
static func orbit_radius(index: int, sweeps: int, start_radius: float, end_radius: float) -> float:
	if sweeps <= 1:
		return end_radius
	return lerpf(start_radius, end_radius, float(clampi(index, 0, sweeps - 1)) / float(sweeps - 1))


## Class-local per-blade hit cooldown: `last_hit` is the elapsed time of this
## blade's previous contact with the same target, or null when it never landed.
static func blade_ready(last_hit, elapsed: float, cooldown: float) -> bool:
	if not (last_hit is int or last_hit is float) or last_hit is bool:
		return true
	return elapsed - float(last_hit) >= cooldown - 0.001


func configure(activation) -> void:
	_activation = activation
	global_position = activation.origin()
	blade_hits_for_tests.resize(activation.param_int("blade_count", 3))
	blade_hits_for_tests.fill(0)


func sweep_blade(index: int) -> void:
	if not _live() or _resolved_sweeps.has(index):
		return
	_resolved_sweeps[index] = true
	var sweeps: int = _activation.param_int("sweep_count", 11)
	var blade: int = index % _activation.param_int("blade_count", 3)
	var elapsed: float = _activation.param_float("release_delay", 0.6) \
		+ float(index) * _activation.param_float("sweep_interval", 0.55)
	var radius := orbit_radius(
		index,
		sweeps,
		_activation.param_float("orbit_start_radius", 190.0),
		_activation.param_float("orbit_end_radius", 420.0)
	)
	sweep_radii_for_tests.append(radius)
	var center: Vector2 = _activation.origin()
	global_position = center
	_activation.present(EXECUTOR_ID + ".orbit", {
		"position": center, "radius": radius, "shape": "ring_pulse",
	})
	var cooldown: float = _activation.param_float("blade_hit_cooldown", 1.65)
	var ledger_key := "whirlwind_blade_%d" % blade
	var bitten: Array[Node2D] = []
	for raw_target in _activation.select_targets(center, INF, 0, "nearest"):
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		# The orbit passes over the target on every sweep; only the blade whose
		# own cooldown has elapsed actually bites.
		if not blade_ready(_activation.target_value(target, ledger_key, null), elapsed, cooldown):
			continue
		if not _activation.record_target_value(
			target, ledger_key, elapsed, "%s:%d" % [ledger_key, index]
		):
			continue
		blade_hits_for_tests[blade] += 1
		_slow(target)
		_deal(
			target,
			_activation.scaled_damage("blade_damage", 6.0),
			"whirlwind:blade:%d:%d" % [blade, index],
			"scarlet_whirlwind_blade"
		)
		bitten.append(target)
	_play_impacts(bitten)


func cross_slash() -> void:
	if not _live() or _cross_done:
		return
	_cross_done = true
	cross_count_for_tests += 1
	var center: Vector2 = _activation.origin()
	global_position = center
	var length: float = _activation.param_float("cross_length", 300.0)
	var half_width: float = _activation.param_float("cross_half_width", 92.0)
	_activation.present(EXECUTOR_ID + ".cross", {
		"position": center, "radius": length, "shape": "cross_slash",
	})
	var targets: Array[Node] = []
	var seen := {}
	for arm in cross_axes(_activation.aim_direction(length)):
		for raw_target in _activation.targets_in_corridor(
			center, arm, length, half_width, 0
		):
			var target := raw_target as Node
			if target == null or not is_instance_valid(target) \
					or seen.has(target.get_instance_id()):
				continue
			seen[target.get_instance_id()] = true
			targets.append(target)
	# One event id for the synchronized cross, including arm overlap. The cross
	# is the aimed bonus on top of the sweeps' map-wide floor, so it stays
	# geometric and unbounded in count.
	for target in targets:
		_deal(
			target,
			_activation.scaled_damage("cross_damage", 25.0),
			"whirlwind:cross",
			"scarlet_whirlwind_cross"
		)
	_play_impacts(targets)


## The cross is oriented by the hero's aim, so the collapse reads as the blades
## converging on the aimed line rather than on world axes.
static func cross_axes(aim: Vector2) -> Array[Vector2]:
	var axis := aim if aim.length_squared() > 0.001 else Vector2.RIGHT
	axis = axis.normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	return [axis, -axis, perpendicular, -perpendicular]


func _slow(target: Node) -> void:
	var status_id := "berserk_ultimate_whirlwind_%d" % get_instance_id()
	var applied: Dictionary = _activation.apply_control(target, Vector2.ZERO, status_id, {
		"duration": _activation.param_float("vortex_duration", 3.0),
		"speed_multiplier": _activation.param_float("vortex_slow", 0.62),
		"scarlet_whirlwind": true,
	})
	if bool(applied.get("status_applied", false)):
		_lease_status(target, status_id)


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


## Per-victim read (FAN-3008): every bitten enemy pops its own scarlet
## explosion on top of its white hit flash, staggered outward from the hero.
## Sweeps land closer together than one ripple spans, so every beat after the
## first joins the running ripple instead of replacing it.
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
