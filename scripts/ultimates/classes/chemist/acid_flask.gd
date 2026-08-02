extends RefCounted

## Chemist / Кислотная колба — «Царь-Колба».
##
## One aimed flask floods a lake that expands from `start_ratio` to the full
## radius across its ticks. Every tick corrodes what stands in the lake, keeps
## the armour-dissolve debuff refreshed, and converts the MEASURED outcome — the
## HP the tick actually removed — into one permanent acid charge.
##
## The charge grant is capped twice and deliberately so: the activation ledger
## grants at most one charge per target per cast, and the shared
## `acid_charge` prefix cap keeps the target inside the documented five-charge
## ceiling it already has from ordinary pools (SCRUM-944). Tick damage runs
## through the activation, so the whole-cast boss budget still binds it; only the
## permanent charge — the accepted lasting payload of this weapon — outlives the
## cast. The lake itself is activation-owned: its tween and VFX end with the
## cast, a cancel, a death or the encounter.
##
## Declaration params: aim_range, lake_radius, start_ratio, target_limit,
## pour_at, tick_count, tick_interval, recover_at, damage, charge_cap,
## charge_dot_damage, charge_dot_interval, dissolve_status.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_ID := "weapon_ultimate.profile.chemist.acid_flask"
const EXECUTOR_ID := "weapon_ultimate.executor.chemist.acid_flask"

## SCRUM-944 owns this prefix: sharing it is what makes the ultimate charge
## count against the same per-target ceiling as a pool charge instead of opening
## a second, uncapped channel.
const ACID_CHARGE_STATUS_PREFIX := "acid_charge"
const ACID_CHARGE_PERSIST_SECONDS := 999999.0
const CHARGE_KEY := "acid_charge"
const CHARGE_EVENT := "chemist.acid_flask.charge"
const DISSOLVE_STATUS_ID := "chemist_acid_dissolve"


static func parameter_contract() -> Dictionary:
	return {
		"aim_range": {"type": "number", "minimum": 0.001},
		"lake_radius": {"type": "number", "minimum": 0.0},
		"start_ratio": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"target_limit": {"type": "integer", "minimum": 0},
		"pour_at": {"type": "number", "minimum": 0.0},
		"tick_count": {"type": "integer", "minimum": 1},
		"tick_interval": {"type": "number", "minimum": 0.05},
		"recover_at": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"charge_cap": {"type": "integer", "minimum": 0},
		"charge_dot_damage": {"type": "number", "minimum": 0.0},
		"charge_dot_interval": {"type": "number", "minimum": 0.05},
		"dissolve_status": {"type": "dictionary"},
	}


## Where the lake lands. A host that cannot report an aim (headless fixtures,
## a Player without the aim methods) floods the caster's own position instead of
## silently spending the charge on nothing.
static func anchor(activation: Activation) -> Vector2:
	if Library.execute_primitive(
		"aim_context",
		activation,
		{"max_range": activation.param_float("aim_range", 0.001), "target_mode": "host_aim"}
	):
		var aimed = activation.primitive_value("target")
		if aimed is Vector2:
			return aimed as Vector2
	return activation.origin()


static func execute(activation: Activation) -> float:
	var centre := anchor(activation)
	var lake_radius := activation.param_float("lake_radius", 0.0)
	var ticks := maxi(activation.param_int("tick_count", 1), 1)
	var interval := maxf(activation.param_float("tick_interval", 0.05), 0.05)
	var pour_at := activation.param_float("pour_at", 0.0)
	activation.present(EXECUTOR_ID, {
		"shape": "ring_pulse",
		"position": centre,
		"radius": lake_radius,
		"duration": activation.param_float("recover_at", 0.0),
	})
	var tween := activation.track_tween()
	if tween == null:
		return 0.0
	tween.tween_interval(pour_at)
	for tick_index in ticks:
		tween.tween_interval(interval)
		var radius := lerpf(
			lake_radius * activation.param_float("start_ratio", 1.0),
			lake_radius,
			float(tick_index + 1) / float(ticks)
		)
		tween.tween_callback(func() -> void: _corrode(activation, centre, radius))
	var poured := pour_at + interval * float(ticks)
	tween.tween_interval(maxf(activation.param_float("recover_at", 0.0) - poured, 0.0))
	return maxf(activation.param_float("recover_at", 0.0), poured)


static func _corrode(activation: Activation, centre: Vector2, radius: float) -> void:
	var tick_damage := activation.scaled_damage()
	var dissolve := activation.param_dictionary("dissolve_status")
	for raw_target in activation.targets(centre, radius, activation.param_int("target_limit", 0)):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var result := activation.deal_damage(target, tick_damage, {"damage_type": "dot"})
		StatusEffects.apply_status(target, DISSOLVE_STATUS_ID, dissolve)
		if result.applied > 0.0:
			_grant_permanent_charge(activation, target)


## Measured outcome -> capped permanent charge. `record_target_value` claims one
## ledger event per target, so the cast can never hand the same enemy a second
## charge no matter how many ticks reach it.
static func _grant_permanent_charge(activation: Activation, target: Node) -> void:
	var cap := activation.param_int("charge_cap", 0)
	if cap <= 0 or StatusEffects.count_status_prefix(target, ACID_CHARGE_STATUS_PREFIX) >= cap:
		return
	if not activation.record_target_value(target, CHARGE_KEY, 1.0, CHARGE_EVENT):
		return
	StatusEffects.apply_status(
		target,
		"%s_u%d" % [ACID_CHARGE_STATUS_PREFIX, activation.get_instance_id()],
		{
			"duration": ACID_CHARGE_PERSIST_SECONDS,
			"dot_damage": activation.param_float("charge_dot_damage", 0.0),
			"dot_interval": activation.param_float("charge_dot_interval", 0.05),
			"max_stacks": 1,
		}
	)
