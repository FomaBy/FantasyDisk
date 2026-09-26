class_name UltimateEffectivenessRunner
extends RefCounted

## FAN-2516: the live effectiveness instrument for the 51 weapon ultimates.
##
## Every row is produced by activating the REAL registry-resolved executor
## through the real generic controller against a deterministic probe formation.
## No row is a class-level legacy kit, and no row is a sustain measurement taken
## with the ultimate disabled: a pair that does not resolve to its own weapon
## profile is reported as such and `violations()` turns it red.
##
## `measure()` produces the report, `violations()` judges any report it is
## handed, and `regressions()` compares a later report against a stored
## baseline. The three are separate on purpose — a harness that cannot go red
## would be inherited green by every consumer of its numbers.
##
## Metric semantics and the tolerances below are documented in
## `docs/design/ultimates/live_effectiveness_metrics.md`.

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const SCHEMA_VERSION := 1

## The live encounter set. `tier` is the group the probes join, which is what
## selects the executor's own declared control-resistance and boss-cap branch.
const SCENARIOS := [
	{"id": "solo", "probes": 1, "tier": "normal"},
	{"id": "crowd_5", "probes": 5, "tier": "normal"},
	{"id": "crowd_10", "probes": 10, "tier": "normal"},
	{"id": "crowd_20", "probes": 20, "tier": "normal"},
	{"id": "elite", "probes": 1, "tier": "epic"},
	{"id": "boss", "probes": 1, "tier": "boss"},
]

const BOSS_SCENARIO_ID := "boss"
const SOLO_SCENARIO_ID := "solo"

## Every measured quantity of one scenario. Adding one here is what makes the
## validator, the re-run determinism check and the regression gate cover it.
const METRIC_KEYS := [
	"damage_applied",
	"healing_applied",
	"prevention_applied",
	"modifier_granted",
	"control_seconds",
	"displacement",
	"summon_count",
	"targets_struck",
	"uptime_seconds",
]

## Metrics a regression gate reads as "less is worse". `uptime_seconds` is
## deliberately absent: a shorter cast is a design choice, not a loss of impact.
const EFFECT_METRIC_KEYS := [
	"damage_applied",
	"healing_applied",
	"prevention_applied",
	"modifier_granted",
	"control_seconds",
	"displacement",
	"summon_count",
	"targets_struck",
]

## Deterministic stepping. The cast is driven by `Tween.custom_step`, never by
## real frame time, so two runs of the same tree produce bit-identical numbers
## and RERUN_TOLERANCE only absorbs float re-association.
const STEP_SECONDS := 0.02
const MAX_CAST_SECONDS := 40.0
const SUMMON_SAMPLE_STEPS := 10
const RERUN_TOLERANCE := 0.0001
## Relative drop a later report may show before it counts as a regression.
const REGRESSION_TOLERANCE := 0.02

## Probe formation: a constant-density disc centred ahead of the host on its aim
## axis. One probe sits exactly on the aim point, and a larger pack spreads out
## instead of stacking, so a wide radial ultimate and a narrow corridor one are
## measured against the same pack rather than against a shape that flatters one
## of them. The layout is the deterministic sunflower placement — no RNG, so the
## same probe count always produces the same positions.
const FORMATION_DISTANCE := 200.0
const FORMATION_DENSITY := 42.0
const FORMATION_GOLDEN_ANGLE := 2.39996322972865332

## Each normal/elite probe carries a whole power budget of its own weapon's
## reference output, so a full-corridor activation can never be inflated by
## overkill and can never be truncated by a probe that was too small.
const PROBE_BUDGET_SECONDS := Budget.POWER_SECONDS_MAX
## The boss pool is normalized so its declared cap equals exactly one power
## budget: `boss_cap_ratio` 1.0 then means "the cap bound this activation".
const MIN_BOSS_CAP := 0.0001

## One canonical incoming hit offered to a guard that opened a prevention
## ledger. A cast without a guard measures 0.0, which is the correct answer.
const PREVENTION_PROBE_INCOMING := 100.0
const PREVENTION_PROBE_APPLIED := 0.0
const PREVENTION_PROBE_SOURCE := "contact"

const TIER_GROUPS := {"normal": "enemies", "epic": "elite_enemies", "boss": "bosses"}


## A damage/control sink with the exact surface the runtime reads: `health`,
## `max_health`, `take_damage` and `apply_knockback`. Nothing else is stubbed,
## so an executor that never reaches a probe measures zero rather than a
## fixture-supplied number.
class Probe:
	extends Node2D

	var health := 0.0
	var max_health := 0.0
	var damage_taken := 0.0
	var displacement := 0.0

	func take_damage(amount: float, _feedback := {}) -> void:
		var applied := clampf(amount, 0.0, health)
		health -= applied
		damage_taken += applied

	func apply_knockback(impulse: Vector2) -> void:
		displacement += impulse.length()


## The measuring host. It implements the same ten `ultimate_host_*` methods the
## shipped Player adapter does plus the optional repair channel, and it stands
## in for the hero itself when an executor repairs its owner.
class MeasuringHost:
	extends Node2D

	var probes: Array = []
	var formation_centre := Vector2.ZERO
	var context := {}
	var health := 0.0
	var max_health := 0.0
	var healing_applied := 0.0
	var modifiers := {}
	## Largest simultaneous deviation from neutral this cast ever held. Read as
	## a peak rather than a running sum because `shutdown()` unwinds every
	## modifier before the caller can look at the dictionary.
	var modifier_granted := 0.0
	var active := false

	var _modifier_neutral := {}

	func ultimate_host_context() -> Dictionary:
		return context.duplicate()

	func ultimate_host_position() -> Vector2:
		return global_position

	## Auto-aim onto the probe block: the aim point is the formation the host is
	## standing in front of, clamped to whatever range the executor declared.
	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := formation_centre - global_position
		if offset.length_squared() <= 0.001:
			return {}
		var direction := offset.normalized()
		return {"point": global_position + direction * minf(offset.length(), max_range), "direction": direction}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for probe in probes:
			if is_instance_valid(probe) and probe.global_position.distance_to(center) <= radius:
				found.append(probe)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return left.global_position.distance_squared_to(center) \
				< right.global_position.distance_squared_to(center)
		)
		return found.slice(0, limit) if limit > 0 else found

	## The fixture owns no pre-existing summons; only the activation's own
	## temporary deploys are measured. See the metric document.
	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_repair(target: Node, amount: float) -> float:
		if target != self or health <= 0.0 or not is_finite(amount) or amount <= 0.0:
			return 0.0
		var before := health
		health = minf(health + amount, max_health)
		healing_applied += health - before
		return health - before

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			target.call("take_damage", amount, feedback)

	## Mirrors the shipped adapter's accumulation and, on top of it, tracks how
	## far the whole modifier set stands from neutral — an additive key is
	## neutral at 0.0, a multiplicative one at 1.0.
	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		var neutral := 1.0 if operation == "mul" else 0.0
		var current := float(modifiers.get(key, neutral))
		modifiers[key] = current * value if operation == "mul" else current + value
		_modifier_neutral[key] = neutral
		var deviation := 0.0
		for raw_key in modifiers.keys():
			deviation += absf(float(modifiers[raw_key]) - float(_modifier_neutral[raw_key]))
		modifier_granted = maxf(modifier_granted, deviation)

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


## One report row per canonical pair, each carrying every scenario.
##
## `parent` must already be inside the tree; `registry` is the loaded weapon
## ultimate registry; `rows` are the frozen `UltimateChargeBudget` fixture rows;
## `progression` supplies the same base-stat/weapon/derived channel the shipped
## Player adapter reads, so the measured damage is the real per-class one.
func measure(parent: Node, registry, rows: Array, progression) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for raw_row in rows:
		if not raw_row is Dictionary:
			continue
		report.append(await _measure_row(parent, registry, raw_row as Dictionary, progression))
	return report


## Everything a report must satisfy on its own, without a baseline to compare
## against. An empty result is the pass statement.
static func violations(report: Array) -> Array[String]:
	var errors: Array[String] = []
	if report.size() != Budget.EXPECTED_ROW_COUNT:
		errors.append("runner.row_count: expected %d, got %d" % [Budget.EXPECTED_ROW_COUNT, report.size()])

	var classes := {}
	var seen_keys := {}
	for raw_row in report:
		if not raw_row is Dictionary:
			errors.append("runner.row_type: report rows must be Dictionaries")
			continue
		var row := raw_row as Dictionary
		var key := str(row.get("key", ""))
		if seen_keys.has(key):
			errors.append("row.duplicate_key: %s" % key)
		seen_keys[key] = true
		_check_row(row, errors)
		var class_id := str(row.get("class_id", ""))
		if not classes.has(class_id):
			classes[class_id] = 0
		classes[class_id] = int(classes[class_id]) + 1

	if classes.size() != Budget.EXPECTED_CLASS_COUNT:
		errors.append("runner.class_count: expected %d, got %d" % [Budget.EXPECTED_CLASS_COUNT, classes.size()])
	for class_id in classes.keys():
		if int(classes[class_id]) != 3:
			errors.append("class.trio_size: %s has %d weapons" % [str(class_id), int(classes[class_id])])
	return errors


## Corridor movement between a stored baseline and a later report. A row that
## lost measured impact beyond REGRESSION_TOLERANCE must say why in its own
## `regression_reason`; an unexplained one is an error.
static func regressions(baseline: Array, final: Array) -> Array[String]:
	var errors: Array[String] = []
	var baseline_by_key := {}
	for raw_row in baseline:
		if raw_row is Dictionary:
			baseline_by_key[str((raw_row as Dictionary).get("key", ""))] = raw_row as Dictionary
	var final_by_key := {}
	for raw_row in final:
		if raw_row is Dictionary:
			final_by_key[str((raw_row as Dictionary).get("key", ""))] = raw_row as Dictionary

	for key in baseline_by_key.keys():
		if not final_by_key.has(key):
			errors.append("regression.row_missing: %s" % str(key))
	for key in final_by_key.keys():
		if not baseline_by_key.has(key):
			errors.append("regression.row_unknown: %s" % str(key))

	for raw_key in baseline_by_key.keys():
		var key := str(raw_key)
		if not final_by_key.has(key):
			continue
		var before := baseline_by_key[key] as Dictionary
		var after := final_by_key[key] as Dictionary
		var reason := str(after.get("regression_reason", "")).strip_edges()
		for scenario_id in _scenario_ids():
			var before_scenario = (before.get("scenarios") as Dictionary).get(scenario_id) \
				if before.get("scenarios") is Dictionary else null
			var after_scenario = (after.get("scenarios") as Dictionary).get(scenario_id) \
				if after.get("scenarios") is Dictionary else null
			if not before_scenario is Dictionary or not after_scenario is Dictionary:
				errors.append("regression.scenario_missing: %s/%s" % [key, scenario_id])
				continue
			for metric in EFFECT_METRIC_KEYS:
				var was := float((before_scenario as Dictionary).get(metric, 0.0))
				var now := float((after_scenario as Dictionary).get(metric, 0.0))
				if was <= 0.0 or now >= was * (1.0 - REGRESSION_TOLERANCE):
					continue
				if reason.is_empty():
					errors.append(
						"regression.unexplained: %s/%s %s %.3f -> %.3f"
						% [key, scenario_id, metric, was, now]
					)
	return errors


## The machine-readable envelope. `label` separates the stored baseline from a
## later final report; both share this exact schema.
static func report_document(report: Array, label: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"label": label,
		"scenario_ids": _scenario_ids(),
		"metric_keys": METRIC_KEYS.duplicate(),
		"tolerances": {
			"step_seconds": STEP_SECONDS,
			"rerun": RERUN_TOLERANCE,
			"regression": REGRESSION_TOLERANCE,
		},
		"rows": report.duplicate(true),
	}


static func _scenario_ids() -> Array[String]:
	var ids: Array[String] = []
	for scenario in SCENARIOS:
		ids.append(str((scenario as Dictionary)["id"]))
	return ids


static func _check_row(row: Dictionary, errors: Array[String]) -> void:
	var key := str(row.get("key", "?"))
	var class_id := str(row.get("class_id", ""))
	var weapon_id := str(row.get("weapon_id", ""))
	if class_id.is_empty() or weapon_id.is_empty():
		errors.append("row.identity: %s misses a class or weapon id" % key)
	elif key != Budget.row_key(class_id, weapon_id):
		errors.append("row.key: %s does not match %s/%s" % [key, class_id, weapon_id])

	if str(row.get("resolution_source", "")) != Resolver.SOURCE_WEAPON_PROFILE:
		errors.append(
			"row.legacy_substituted: %s resolved as '%s'" % [key, str(row.get("resolution_source", ""))]
		)
	if not bool(row.get("executor_present", false)):
		errors.append("row.executor_missing: %s has no live executor" % key)

	var reference_dps := float(row.get("reference_solo_dps", 0.0))
	if not is_finite(reference_dps) or reference_dps <= 0.0:
		errors.append("row.reference_solo_dps: %s must be positive" % key)
	var archetype := str(row.get("power_archetype", ""))
	if archetype != Budget.POWER_ARCHETYPE_BURST and archetype != Budget.POWER_ARCHETYPE_CONTROL_SAVE:
		errors.append("row.power_archetype: %s = '%s'" % [key, archetype])
	var boss_cap := float(row.get("total_boss_cap", 0.0))
	if boss_cap < Budget.BOSS_CAP_MIN or boss_cap > Budget.BOSS_CAP_MAX:
		errors.append("row.total_boss_cap: %s = %.3f outside [%.2f, %.2f]" % [key, boss_cap, Budget.BOSS_CAP_MIN, Budget.BOSS_CAP_MAX])
	var encounters := int(row.get("encounters_to_ready", 0))
	if encounters < Budget.MIN_ENCOUNTERS_TO_READY \
			or encounters > Budget.NEUTRAL_ENCOUNTERS_TO_READY_MAX:
		errors.append("row.encounters_to_ready: %s ready after %d encounters" % [key, encounters])

	var scenarios = row.get("scenarios")
	if not scenarios is Dictionary:
		errors.append("row.scenarios: %s misses its scenario results" % key)
		return
	for scenario_id in _scenario_ids():
		if not (scenarios as Dictionary).has(scenario_id):
			errors.append("row.scenarios.missing: %s/%s" % [key, scenario_id])
			continue
		_check_scenario(key, scenario_id, (scenarios as Dictionary)[scenario_id], errors)

	# "No skipped row": the solo encounter is the one every ultimate has to move.
	var solo = (scenarios as Dictionary).get(SOLO_SCENARIO_ID)
	if solo is Dictionary and float((solo as Dictionary).get("effect_total", 0.0)) <= 0.0:
		errors.append("row.no_measured_effect: %s did nothing in the solo encounter" % key)


static func _check_scenario(key: String, scenario_id: String, raw_result, errors: Array[String]) -> void:
	if not raw_result is Dictionary:
		errors.append("scenario.type: %s/%s" % [key, scenario_id])
		return
	var result := raw_result as Dictionary
	for metric in METRIC_KEYS:
		if not result.has(metric):
			errors.append("scenario.metric_missing: %s/%s %s" % [key, scenario_id, metric])
			continue
		var value := float(result[metric])
		if not is_finite(value) or value < 0.0:
			errors.append("scenario.metric_invalid: %s/%s %s = %s" % [key, scenario_id, metric, str(result[metric])])
	if not bool(result.get("cast_completed", false)):
		errors.append("scenario.cast_incomplete: %s/%s never finished" % [key, scenario_id])
	var struck := float(result.get("targets_struck", 0.0))
	var probes := float(result.get("probe_count", 0.0))
	if struck > probes:
		errors.append("scenario.targets_struck: %s/%s struck %.0f of %.0f probes" % [key, scenario_id, struck, probes])
	if scenario_id == BOSS_SCENARIO_ID:
		var ratio := float(result.get("boss_cap_ratio", -1.0))
		if not is_finite(ratio) or ratio < 0.0 or ratio > 1.0 + RERUN_TOLERANCE:
			errors.append("scenario.boss_cap_ratio: %s = %s outside [0, 1]" % [key, str(result.get("boss_cap_ratio"))])


func _measure_row(parent: Node, registry, row: Dictionary, progression) -> Dictionary:
	var class_id := str(row.get("class_id", ""))
	var weapon_id := str(row.get("weapon_id", ""))
	var context := _host_context(class_id, weapon_id, progression)
	var scenarios := {}
	for raw_scenario in SCENARIOS:
		var scenario := raw_scenario as Dictionary
		scenarios[str(scenario["id"])] = await _measure_scenario(
			parent, registry, row, scenario, context
		)
	var charge := (Harness.measure([row])[0]["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID] as Dictionary
	return {
		"key": str(row.get("key", "")),
		"class_id": class_id,
		"weapon_id": weapon_id,
		"resolution_source": str(registry.resolution_source(class_id, weapon_id, false)),
		"executor_present": bool(registry.has_exact_executor_pair(class_id, weapon_id)),
		"reference_solo_dps": float(row.get("reference_solo_dps", 0.0)),
		"power_archetype": str(row.get("power_archetype", "")),
		"power_budget_min": float(row.get("power_budget_min", 0.0)),
		"power_budget_max": float(row.get("power_budget_max", 0.0)),
		"total_boss_cap": float(row.get("total_boss_cap", 0.0)),
		"host_damage": float(context.get("damage", 0.0)),
		"host_multiplier": float(context.get("multiplier", 1.0)),
		# Charge cadence stays the frozen economy of FAN-1460: this instrument
		# reports it next to the live impact, it never re-derives it.
		"encounters_to_ready": int(charge.get("encounters_to_ready", 0)),
		"normal_charge": float(charge.get("normal_charge", 0.0)),
		"elite_charge": float(charge.get("elite_charge", 0.0)),
		"regression_reason": "",
		"scenarios": scenarios,
	}


## Mirrors `UltimatePlayerHost.ultimate_host_context()` so the measured per-hit
## damage is the class's real damage channel, not a fixture constant.
func _host_context(class_id: String, weapon_id: String, progression) -> Dictionary:
	var config: Dictionary = progression.weapon(class_id, weapon_id)
	var derived: Dictionary = progression.derived_parameters(
		progression.base_stats(class_id), {}, config
	)
	var damage_parameter := str(progression.damage_parameter_for(class_id))
	return {
		"damage": float(derived.get(damage_parameter, derived.get("damage", 10.0))),
		"multiplier": float(derived.get("ultimate_multiplier", 1.0)),
		"damage_type": "magic" if damage_parameter == "magic_damage" else "physical",
	}


func _measure_scenario(
	parent: Node, registry, row: Dictionary, scenario: Dictionary, context: Dictionary
) -> Dictionary:
	var class_id := str(row.get("class_id", ""))
	var weapon_id := str(row.get("weapon_id", ""))
	var tier := str(scenario["tier"])
	var probe_count := int(scenario["probes"])
	var boss_pool := _boss_pool(row)

	var host := MeasuringHost.new()
	host.context = context
	host.max_health = float(row.get("reference_ehp", 0.0))
	# Half health so a repair channel has room to land: the host reports the HP
	# it actually regained, so a cast that only overheals measures zero.
	host.health = host.max_health * 0.5
	host.formation_centre = Vector2.RIGHT * FORMATION_DISTANCE
	parent.add_child(host)
	await host.get_tree().process_frame

	var probe_health := float(row.get("reference_solo_dps", 0.0)) * PROBE_BUDGET_SECONDS
	if tier == "boss":
		probe_health = boss_pool
	for index in probe_count:
		var probe := Probe.new()
		probe.max_health = probe_health
		probe.health = probe_health
		probe.global_position = host.formation_centre + _formation_offset(index)
		probe.add_to_group(str(TIER_GROUPS[tier]))
		host.add_child(probe)
		host.probes.append(probe)
	await host.get_tree().process_frame

	var controller := Controller.new(host, registry)
	var started := controller.activate(class_id, weapon_id)
	var activation = controller.active_activation()
	var uptime := 0.0
	var prevention := 0.0
	# `shutdown()` clears the spawn list, so the count has to be taken while the
	# cast is still live; `_advance` returns the peak it saw.
	var summon_count := 0
	if started:
		prevention = _probe_prevention(controller)
		var progress := _advance(activation)
		uptime = float(progress["uptime"])
		summon_count = int(progress["summon_peak"])
	var completed := started and (activation == null or activation.is_finished())
	var damage_applied := float(activation.applied_total) if activation != null else 0.0

	var control_seconds := 0.0
	var displacement := 0.0
	var targets_struck := 0
	for probe in host.probes:
		if not is_instance_valid(probe):
			continue
		displacement += float(probe.displacement)
		if float(probe.damage_taken) > 0.0:
			targets_struck += 1
		var statuses := StatusEffects.snapshot(probe)
		for status_id in statuses.keys():
			var status = statuses[status_id]
			if status is Dictionary:
				control_seconds += maxf(float((status as Dictionary).get("duration", 0.0)), 0.0)

	var healing := host.healing_applied
	var modifier_granted := host.modifier_granted
	controller.cancel()
	host.queue_free()
	await parent.get_tree().process_frame

	var result := {
		"probe_count": probe_count,
		"tier": tier,
		"activated": started,
		"cast_completed": completed,
		"damage_applied": damage_applied,
		"healing_applied": healing,
		"prevention_applied": prevention,
		"modifier_granted": modifier_granted,
		"control_seconds": control_seconds,
		"displacement": displacement,
		"summon_count": float(summon_count),
		"targets_struck": float(targets_struck),
		"uptime_seconds": uptime,
	}
	# The "this ultimate did something" statement. Every channel an ultimate is
	# allowed to win through counts, so a pure ward or a pure control cast is
	# not read as a dead row.
	result["effect_total"] = damage_applied + healing + prevention + modifier_granted \
		+ control_seconds + displacement + float(summon_count)
	if str(scenario["id"]) == BOSS_SCENARIO_ID:
		var cap_budget := maxf(boss_pool * float(row.get("total_boss_cap", 0.0)), MIN_BOSS_CAP)
		result["boss_cap_budget"] = cap_budget
		result["boss_cap_ratio"] = minf(damage_applied / cap_budget, 1.0)
	return result


## The boss pool is expressed so that its declared share equals exactly one
## power budget: `boss_cap_ratio` is then a direct read of how much of the
## allowance the activation actually spent.
static func _boss_pool(row: Dictionary) -> float:
	var cap := maxf(float(row.get("total_boss_cap", 0.0)), MIN_BOSS_CAP)
	return maxf(float(row.get("power_budget_max", 0.0)), 1.0) / cap


## Sunflower placement: probe 0 sits on the aim point, every further probe adds
## one constant-density ring step. Deterministic and independent of the pack
## size, so the solo, 5, 10 and 20 formations are nested subsets of each other.
static func _formation_offset(index: int) -> Vector2:
	return Vector2.RIGHT.rotated(FORMATION_GOLDEN_ANGLE * float(index)) \
		* (FORMATION_DENSITY * sqrt(float(index)))


## One canonical incoming hit for a guard that opened a prevention ledger.
## Without a guard the ledger returns 0.0 and the row measures no prevention.
static func _probe_prevention(controller) -> float:
	var owner_id := str(controller.guard_prevention_owner_id())
	if owner_id.is_empty():
		return 0.0
	return controller.record_guard_prevention({
		"event_id": "effectiveness_probe",
		"owner_id": owner_id,
		"source": PREVENTION_PROBE_SOURCE,
		"direction": Vector2.RIGHT,
		"incoming_amount": PREVENTION_PROBE_INCOMING,
		"applied_amount": PREVENTION_PROBE_APPLIED,
		"prevented_amount": PREVENTION_PROBE_INCOMING - PREVENTION_PROBE_APPLIED,
	})


## Drives the cast on its own tweens in fixed steps, so the measured uptime is
## the executor's declared cast length and never wall-clock time. The spawn peak
## is sampled here because teardown drops the list the moment the cast ends.
static func _advance(activation) -> Dictionary:
	var progress := {"uptime": 0.0, "summon_peak": 0}
	if activation == null:
		return progress
	var elapsed := 0.0
	var steps := 0
	var summon_peak := int(activation.spawned_for_tests().size())
	while not activation.is_finished() and elapsed < MAX_CAST_SECONDS:
		var stepped := false
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP_SECONDS)
				stepped = true
		elapsed += STEP_SECONDS
		steps += 1
		# `spawned_for_tests()` copies the list, so it is sampled on a coarse
		# cadence rather than every step; deploys land on tween callbacks that
		# are far wider apart than SUMMON_SAMPLE_STEPS.
		if steps % SUMMON_SAMPLE_STEPS == 0 and not activation.is_finished():
			summon_peak = maxi(summon_peak, int(activation.spawned_for_tests().size()))
		if not stepped:
			break
	progress["uptime"] = elapsed
	progress["summon_peak"] = summon_peak
	return progress
