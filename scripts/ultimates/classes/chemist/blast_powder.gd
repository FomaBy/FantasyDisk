extends RefCounted

## Chemist / Взрывная пыль — «Философский Взрыв».
##
## Five alchemical charges form a pentagram around the caster, crystallize every
## live enemy, pull that exact set inward and transmute it in one capped blast.
## The pentagram remains the cast's visual anchor; it no longer limits reach.
##
## The detonation reads back the set the pentagram recorded and consumes each
## mark exactly once, so a kill can never recruit a fresh victim: there is no
## re-selection step a chain could recurse through. Displacement and the
## crystal lock go through `apply_control`, so the declared tier policy is what
## reduces them for elites and refuses the movement lock on bosses.
##
## Declaration params: pentagram_radius, pull_at,
## pull_force, detonate_at, recover_at, damage, target_damage_cap,
## control_policy, crystal_status.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.chemist.blast_powder"
const EXECUTOR_ID := "weapon_ultimate.executor.chemist.blast_powder"

const CRYSTAL_KEY := "philosopher_crystal"
const CRYSTALLIZE_EVENT := "chemist.blast_powder.crystallize"
const TRANSMUTE_EVENT := "chemist.blast_powder.transmute"
const CRYSTAL_STATUS_ID := "chemist_philosopher_crystal"
const PENTAGRAM_VERTICES := 5
const PENTAGRAM_ROTATION_DEGREES := -90.0


static func parameter_contract() -> Dictionary:
	return {
		"pentagram_radius": {"type": "number", "minimum": 1.0},
		"pull_at": {"type": "number", "minimum": 0.0},
		"pull_force": {"type": "number", "minimum": 0.0},
		"detonate_at": {"type": "number", "minimum": 0.0},
		"recover_at": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"target_damage_cap": {"type": "number", "minimum": 0.001, "maximum": 1.0},
		"control_policy": {"type": "dictionary"},
		"crystal_status": {"type": "dictionary"},
	}


## The zero-duration setup every later beat depends on. Reported separately so
## the mechanics test can assert the shipped declaration is admitted rather than
## discovering a malformed policy in the middle of a live cast.
static func prepare(activation: Activation) -> bool:
	# The pentagram is cast around the alchemist, so the geometry anchor is the
	# caster itself rather than an aim sample the host may not be able to give.
	var origin := activation.origin()
	activation.set_primitive_state({
		"source": origin,
		"points": activation.pattern_points(
			origin,
			"polygon",
			{
				"count": PENTAGRAM_VERTICES,
				"radius": activation.param_float("pentagram_radius", 0.0),
				"rotation_degrees": PENTAGRAM_ROTATION_DEGREES,
				"arc_degrees": 360.0,
			}
		),
		"targets": activation.select_targets(origin, INF, 0, "nearest"),
	})
	var ready := Library.execute_primitive(
		"per_target_damage_cap",
		activation,
		{"cap_fraction": activation.param_float("target_damage_cap", 0.0), "cap_flat": 0.0}
	)
	ready = Library.execute_primitive(
		"control_resistance_policy", activation, activation.param_dictionary("control_policy")
	) and ready
	# An empty map is a legitimate miss, not a malformed declaration: the ledger
	# step only has work when at least one live enemy was selected.
	if (activation.primitive_value("targets", []) as Array).is_empty():
		return ready
	return Library.execute_primitive(
		"stateful_target_ledger",
		activation,
		{
			"operation": "record",
			"target_source": "targets",
			"key": CRYSTAL_KEY,
			"value": 1.0,
			"event_id": CRYSTALLIZE_EVENT,
		}
	) and ready


static func execute(activation: Activation) -> float:
	prepare(activation)
	var origin := activation.origin()
	var crystallized: Array = (activation.primitive_value("targets", []) as Array).duplicate()
	activation.present(EXECUTOR_ID, {
		"shape": "ring_pulse",
		"position": origin,
		"radius": activation.param_float("pentagram_radius", 0.0),
		"duration": activation.param_float("recover_at", 0.0),
	})
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	var pull_at := activation.param_float("pull_at", 0.0)
	var detonate_at := maxf(activation.param_float("detonate_at", 0.0), pull_at)
	tween.tween_interval(pull_at)
	tween.tween_callback(func() -> void: _crystallize(activation, origin, crystallized))
	tween.tween_interval(detonate_at - pull_at)
	tween.tween_callback(func() -> void: _transmute(activation, origin, crystallized))
	tween.tween_interval(maxf(activation.param_float("recover_at", 0.0) - detonate_at, 0.0))
	return maxf(activation.param_float("recover_at", 0.0), detonate_at)


## Pull the recorded set toward the pentagram centre and freeze it there.
static func _crystallize(activation: Activation, origin: Vector2, crystallized: Array) -> void:
	var pull_force := activation.param_float("pull_force", 0.0)
	var status := activation.param_dictionary("crystal_status")
	for raw_target in crystallized:
		var target := raw_target as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var inward := origin - target.global_position
		var impulse := inward.normalized() * pull_force \
			if pull_force > 0.0 and inward.length_squared() > 0.001 else Vector2.ZERO
		activation.apply_control(target, impulse, CRYSTAL_STATUS_ID, status)


## One capped blast on the crystallized set only. Consuming the mark is what
## makes a second detonation — from a retrigger or a kill chain — a no-op.
static func _transmute(activation: Activation, origin: Vector2, crystallized: Array) -> void:
	var damage := activation.scaled_damage()
	activation.present(EXECUTOR_ID, {
		"shape": "orb_burst",
		"position": origin,
		"radius": activation.param_float("pentagram_radius", 0.0),
	})
	for raw_target in crystallized:
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		if activation.consume_target_value(target, CRYSTAL_KEY, TRANSMUTE_EVENT) == null:
			continue
		activation.deal_damage(target, damage, {}, TRANSMUTE_EVENT)
