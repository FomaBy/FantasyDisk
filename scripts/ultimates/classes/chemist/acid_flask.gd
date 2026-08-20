extends RefCounted

## Chemist / Кислотная колба — «Царь-Колба».
##
## One aimed flask floods a lake, dissolves every live enemy, and converts the
## MEASURED outcome of every tick into one capped charge that the finale spends
## as the acid pillars.
##
## Both lasting effects are activation-owned rather than enemy statuses. The
## dissolve stack lives in the activation target ledger and the charge lives in
## the activation owner-resource ledger, so a completed cast, a cancel, a death
## or an encounter end all clear them through the same `shutdown()` and no
## residue survives the cast. Tick damage runs through the activation too, so
## the whole-cast boss budget binds the entire pour and the finale.
##
## Declaration params: aim_range, lake_radius,
## pour_at, tick_count, tick_interval, recover_at, damage, dissolve_bonus,
## dissolve_stack_cap, charge_cap_ratio, charge_conversion, pillar_ratio.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")

const PROFILE_ID := "weapon_ultimate.profile.chemist.acid_flask"
const EXECUTOR_ID := "weapon_ultimate.executor.chemist.acid_flask"

const CHARGE_RESOURCE_ID := "chemist_acid_flask.charge"
const DISSOLVE_KEY := "acid_dissolve"
const PILLAR_EVENT := "pillar_release"


static func parameter_contract() -> Dictionary:
	return {
		"aim_range": {"type": "number", "minimum": 0.001},
		"lake_radius": {"type": "number", "minimum": 0.0},
		"pour_at": {"type": "number", "minimum": 0.0},
		"tick_count": {"type": "integer", "minimum": 1},
		"tick_interval": {"type": "number", "minimum": 0.05},
		"recover_at": {"type": "number", "minimum": 0.0},
		"damage": {"type": "number", "minimum": 0.0},
		"dissolve_bonus": {"type": "number", "minimum": 0.0},
		"dissolve_stack_cap": {"type": "integer", "minimum": 0},
		"charge_cap_ratio": {"type": "number", "minimum": 0.001},
		"charge_conversion": {"type": "number", "minimum": 0.0, "maximum": 1.0},
		"pillar_ratio": {"type": "number", "minimum": 0.0},
	}


## One owner per activation, so two casts can never share a charge pool.
static func charge_owner_id(activation: Activation) -> String:
	return "%s:%d" % [EXECUTOR_ID, activation.get_instance_id()]


## The charge ceiling is priced in the weapon's own tick damage, so it scales
## with the build instead of freezing one absolute number into the declaration.
static func charge_cap(activation: Activation) -> float:
	return activation.scaled_damage() * activation.param_float("charge_cap_ratio", 0.001)


## Where the lake lands. A host that cannot report an aim (headless fixtures, a
## Player without the aim methods) floods the caster's own position instead of
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
		tween.tween_callback(func() -> void: _corrode(activation, centre, tick_index))
	tween.tween_callback(func() -> void: _pillars(activation, centre, lake_radius))
	var poured := pour_at + interval * float(ticks)
	tween.tween_interval(maxf(activation.param_float("recover_at", 0.0) - poured, 0.0))
	return maxf(activation.param_float("recover_at", 0.0), poured)


## One lake tick: damage scaled by how far this target is already dissolved,
## then one more dissolve stack and the measured-outcome charge conversion.
static func _corrode(activation: Activation, centre: Vector2, tick_index: int) -> void:
	var base_damage := activation.scaled_damage()
	var bonus := activation.param_float("dissolve_bonus", 0.0)
	var stack_cap := float(activation.param_int("dissolve_stack_cap", 0))
	var conversion := activation.param_float("charge_conversion", 0.0)
	var cap := charge_cap(activation)
	var owner_id := charge_owner_id(activation)
	for raw_target in activation.select_targets(centre, INF, 0, "nearest"):
		var target := raw_target as Node
		if target == null or not is_instance_valid(target):
			continue
		var stacks := float(activation.target_value(target, DISSOLVE_KEY, 0.0))
		var result := activation.deal_damage(
			target, base_damage * (1.0 + bonus * stacks), {"damage_type": "dot"}
		)
		# Only a tick that actually removed HP dissolves further or pays charge:
		# a capped or overkilled swing buys neither.
		if result.applied <= 0.0:
			continue
		if stacks < stack_cap:
			activation.add_target_value(target, DISSOLVE_KEY, 1.0, "dissolve:%d" % tick_index)
		activation.apply_owner_resource(
			owner_id,
			CHARGE_RESOURCE_ID,
			result.applied * conversion,
			cap,
			"pour:%d:%d" % [tick_index, target.get_instance_id()]
		)


## The finale spends the whole capped charge once and shares it across the lake.
## Consuming it is what makes a repeated release a no-op.
static func _pillars(activation: Activation, centre: Vector2, radius: float) -> void:
	var released: Dictionary = activation.consume_owner_resource(
		charge_owner_id(activation), CHARGE_RESOURCE_ID, PILLAR_EVENT
	)
	var stored := float(released.get("amount", 0.0)) * activation.param_float("pillar_ratio", 0.0)
	if stored <= 0.0:
		return
	var targets := activation.select_targets(centre, INF, 0, "nearest")
	if targets.is_empty():
		return
	activation.present(EXECUTOR_ID, {"shape": "orb_burst", "position": centre, "radius": radius})
	var share := stored / float(targets.size())
	for raw_target in targets:
		var target := raw_target as Node
		if target != null and is_instance_valid(target):
			activation.deal_damage(target, share, {"damage_type": "dot"}, PILLAR_EVENT)
