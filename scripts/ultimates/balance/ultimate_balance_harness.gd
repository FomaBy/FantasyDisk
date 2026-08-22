class_name UltimateBalanceHarness
extends RefCounted

## FAN-1460: the measurement harness for the charge economy and the power
## corridor.
##
## `measure()` produces one report row per weapon ultimate (51) with every
## scenario resolved; `violations()` turns that report into the pass/fail
## statement the class mechanics packs and QA read. The two are separate on
## purpose: `violations()` judges any report it is handed, so a deliberately
## tampered report must come back red — a harness that cannot go red would be
## inherited green by all 17 downstream packs.
##
## The encounter model is normalized per weapon: an encounter contains exactly
## the HP its own reference output clears inside the canonical window. Swinging
## harder than there is HP removes no extra HP, which is what makes the overkill
## scenario a real control rather than a restatement of the neutral one.

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")

const REFERENCE_MAX_HEALTH := 100.0
const READY_SEARCH_LIMIT := 24

## FAN-2949 coverage ratchet. The 51 executors still carry count caps, so the
## `coverage=all_enemies` assertion ships behind this migration allowlist with
## the same semantics `ContactSheetBeatsContract.MIGRATION_ALLOWLIST` uses:
## seeded with every class, it only ever shrinks (each per-class conversion card
## removes its own entry; the target state is EMPTY). An entry that names no
## class package, an entry that states no reason, and an entry for a class that
## already satisfies v2 (clean sources AND listed in COVERAGE_V2_CLASSES) all
## fail. A class outside the allowlist is asserted against v2 and fails closed.
const COVERAGE_MIGRATION_ALLOWLIST: Dictionary = {
	"dark_mage": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"doctor": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"druid": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"elementalist": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"guitarist": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"knight": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"priest": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"ranger": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"robot": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"soldier": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
	"thief": "awaiting per-class v2 coverage conversion (FAN-2949 ratchet)",
}

## The per-class conversion ledger: a class satisfies v2 coverage only when its
## conversion card has landed HERE and its executor sources carry no count
## caps. Source cleanliness alone is not satisfaction — an executor whose
## params merely lack a count cap has not thereby declared map-wide reach.
##
## `assassin` (FAN-2952): the trio reaches every live enemy through the
## activation itself rather than a radius or a count — `shadow_daggers` marks
## the whole map and serves it in a fixed wave sequence, `chakrams` strikes
## every enemy on its outbound pass and layers the curved return on top, and
## `venom_wire` cuts every enemy once per pulse before the wire crossings raise
## it. The per-enemy floor is proven under crowd pressure in
## `tests/ultimates/assassin_balance_test.gd`.
##
## `berserk` (FAN-2953): every sweep of the Scarlet Whirlwind bites every live
## enemy with the aimed cross as the geometric bonus, the Executioner's Loop
## strikes and marks the whole map on its outbound pass with the return leg as
## the aimed execute bonus, and every Fourfold Rift beat reaches every live
## enemy with lane membership as attribution. The per-enemy floor is proven
## under crowd pressure in `tests/ultimates/berserk_balance_test.gd`.
##
## `engineer` (FAN-2955): every volley of the sentry hex suppresses the whole
## map with the three chords as attribution, every microdrone ram wave
## intercepts every live enemy, and all sixteen smart mines detonate once each
## as arena-wide pressure waves bounded per TARGET rather than per count. The
## per-enemy floor is proven under crowd pressure in
## `tests/ultimates/engineer_balance_test.gd`.
##
## `chemist` (FAN-2954): the philosopher's blast crystallizes every live enemy
## before its bounded per-target transmutation, every acid pour and its finale
## reach the full map, and every homunculus taunt, stomp and toxin wave reaches
## the full map while keeping its summon and stack contracts. The per-enemy
## floor and the class-local `target_limit` vocabulary are proven in
## `tests/ultimates/chemist_balance_test.gd`.
##
## `biologist` (FAN-2526): every mycelium wave infects every live enemy,
## every analysis pulse reaches the whole map after the aimed priority sample,
## and the Matriarch's pull/root plus terminal hatch cover every live enemy;
## blooms and larvae stay finite identity bonuses rather than reach bounds.
const COVERAGE_V2_CLASSES: Array[String] = ["assassin", "berserk", "biologist", "chemist", "engineer", "sniper"]

## A count-shaped parameter bounds HOW MANY enemies an activation can reach
## (target_cap, impale_target_cap, dive_target_cap, counter_target_cap,
## analysis_target_cap, intercept_target_cap, hunt_splash_target_cap and any
## sibling). Per-target DAMAGE shaping is not a count cap and stays allowed:
## per_target_cap_fraction, per_target_cap_flat — any `*_target_cap_fraction`
## or `*_target_cap_flat` shapes damage per target instead of bounding reach.
const COUNT_CAP_PARAM_PATTERN := "[A-Za-z0-9_]*target_cap[A-Za-z0-9_]*"
const COUNT_CAP_SHAPING_SUFFIXES := ["_fraction", "_flat"]

## `output_factor` > 1 is attempted damage beyond the HP present (overkill);
## `health_bars_lost` overrides the neutral damage-taken profile.
const SCENARIOS := [
	{"id": "neutral", "energy": 0.0, "ult_charge_multiplier": 1.0, "start_charge": 0.0, "output_factor": 1.0},
	{"id": "high_energy", "energy": 24.0, "ult_charge_multiplier": 1.0, "start_charge": 0.0, "output_factor": 1.0},
	{"id": "high_energy_stacked", "energy": 24.0, "ult_charge_multiplier": 1.35, "start_charge": 0.0, "output_factor": 1.0},
	{"id": "atlas_half", "energy": 0.0, "ult_charge_multiplier": 1.0, "start_charge": 0.5, "output_factor": 1.0},
	{"id": "atlas_full", "energy": 0.0, "ult_charge_multiplier": 1.0, "start_charge": 1.0, "output_factor": 1.0},
	{"id": "overkill_abuse", "energy": 0.0, "ult_charge_multiplier": 1.0, "start_charge": 0.0, "output_factor": 6.0},
	{"id": "tank_runaway", "energy": 0.0, "ult_charge_multiplier": 1.0, "start_charge": 0.0, "output_factor": 1.0, "health_bars_lost": 6.0},
]

const NEUTRAL_SCENARIO_ID := "neutral"
const OVERKILL_SCENARIO_ID := "overkill_abuse"
const TANK_SCENARIO_ID := "tank_runaway"


static func scenario_ids() -> Array[String]:
	var ids: Array[String] = []
	for scenario in SCENARIOS:
		ids.append(str((scenario as Dictionary)["id"]))
	return ids


## One report row per fixture row, each carrying every scenario.
static func measure(rows: Array) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for raw_row in rows:
		if not raw_row is Dictionary:
			continue
		var row := raw_row as Dictionary
		var scenarios := {}
		for raw_scenario in SCENARIOS:
			var scenario := raw_scenario as Dictionary
			scenarios[str(scenario["id"])] = _measure_scenario(row, scenario)
		report.append(
			{
				"key": str(row.get("key", "")),
				"class_id": str(row.get("class_id", "")),
				"weapon_id": str(row.get("weapon_id", "")),
				"reference_solo_dps": float(row.get("reference_solo_dps", 0.0)),
				"reference_aoe_dps": float(row.get("reference_aoe_dps", 0.0)),
				"reference_ehp": float(row.get("reference_ehp", 0.0)),
				"charge_per_removed_hp": float(row.get("charge_per_removed_hp", 0.0)),
				"total_boss_cap": float(row.get("total_boss_cap", 0.0)),
				"power_archetype": str(row.get("power_archetype", "")),
				"coverage": str(row.get("coverage", "")),
				"power_budget_min": float(row.get("power_budget_min", 0.0)),
				"power_budget_max": float(row.get("power_budget_max", 0.0)),
				"control_save_seconds": float(row.get("control_save_seconds", 0.0)),
				"scenarios": scenarios,
			}
		)
	return report


## Every corridor, cap and abuse invariant the 17 class packs inherit. An empty
## result is the pass statement.
static func violations(report: Array) -> Array[String]:
	var errors: Array[String] = []
	if report.size() != Budget.EXPECTED_ROW_COUNT:
		errors.append("harness.row_count: expected %d, got %d" % [Budget.EXPECTED_ROW_COUNT, report.size()])

	var classes := {}
	for raw_row in report:
		if not raw_row is Dictionary:
			errors.append("harness.row_type: report rows must be Dictionaries")
			continue
		var row := raw_row as Dictionary
		_check_row(row, errors)
		var class_id := str(row.get("class_id", ""))
		if not classes.has(class_id):
			classes[class_id] = []
		(classes[class_id] as Array).append(row)

	if classes.size() != Budget.EXPECTED_CLASS_COUNT:
		errors.append("harness.class_count: expected %d, got %d" % [Budget.EXPECTED_CLASS_COUNT, classes.size()])
	for class_id in classes.keys():
		_check_class_trio(str(class_id), classes[class_id] as Array, errors)
	return errors


static func _check_row(row: Dictionary, errors: Array[String]) -> void:
	var key := str(row.get("key", "?"))
	var reference_dps := float(row.get("reference_solo_dps", 0.0))
	if reference_dps <= 0.0:
		errors.append("row.reference_solo_dps: %s must be positive" % key)
	if float(row.get("reference_aoe_dps", 0.0)) <= 0.0:
		errors.append("row.reference_aoe_dps: %s must be positive" % key)
	if float(row.get("reference_ehp", 0.0)) <= 0.0:
		errors.append("row.reference_ehp: %s must be positive" % key)
	if float(row.get("charge_per_removed_hp", 0.0)) <= 0.0:
		errors.append("row.charge_per_removed_hp: %s must be positive" % key)

	var boss_cap := float(row.get("total_boss_cap", 0.0))
	if boss_cap < Budget.BOSS_CAP_MIN or boss_cap > Budget.BOSS_CAP_MAX:
		errors.append("row.total_boss_cap: %s = %.3f outside [%.2f, %.2f]" % [key, boss_cap, Budget.BOSS_CAP_MIN, Budget.BOSS_CAP_MAX])
	# FAN-2949: boss HP is excluded from the standard-monster pool the power
	# corridor prices. The boss scenario asserts total_boss_cap ONLY — the part
	# of the activation budget the boss cap refuses (see
	# Budget.boss_capped_budget) is explicitly NOT a corridor violation, or
	# every boss row would go falsely red the moment the corridor rises.

	if str(row.get("coverage", "")) != Budget.COVERAGE_ALL_ENEMIES:
		errors.append(
			"row.coverage: %s = '%s' must be '%s'" % [key, str(row.get("coverage", "")), Budget.COVERAGE_ALL_ENEMIES]
		)

	var archetype := str(row.get("power_archetype", ""))
	if archetype != Budget.POWER_ARCHETYPE_BURST and archetype != Budget.POWER_ARCHETYPE_CONTROL_SAVE:
		errors.append("row.power_archetype: %s = '%s'" % [key, archetype])
	elif archetype == Budget.POWER_ARCHETYPE_CONTROL_SAVE \
			and float(row.get("control_save_seconds", 0.0)) < Budget.CONTROL_SAVE_MIN_SECONDS:
		errors.append("row.control_save_seconds: %s below %.1fs" % [key, Budget.CONTROL_SAVE_MIN_SECONDS])

	var power_min := float(row.get("power_budget_min", 0.0))
	var power_max := float(row.get("power_budget_max", 0.0))
	# FAN-2949: POWER_SECONDS_* are k x the canonical encounter window, so this
	# is the k in [POWER_CORRIDOR_K_MIN, POWER_CORRIDOR_K_MAX] corridor against
	# the live standard-monster pool (reference output x window seconds).
	if not is_equal_approx(power_min, reference_dps * Budget.POWER_SECONDS_MIN):
		errors.append("row.power_budget_min: %s must be %.1fs of its own output" % [key, Budget.POWER_SECONDS_MIN])
	if not is_equal_approx(power_max, reference_dps * Budget.POWER_SECONDS_MAX):
		errors.append("row.power_budget_max: %s must be %.1fs of its own output" % [key, Budget.POWER_SECONDS_MAX])
	if power_max <= power_min:
		errors.append("row.power_budget_range: %s is empty" % key)

	var scenarios = row.get("scenarios")
	if not scenarios is Dictionary:
		errors.append("row.scenarios: %s missing scenario results" % key)
		return
	for scenario_id in scenario_ids():
		if not (scenarios as Dictionary).has(scenario_id):
			errors.append("row.scenarios.missing: %s/%s" % [key, scenario_id])
	_check_scenarios(key, scenarios as Dictionary, errors)


static func _check_scenarios(key: String, scenarios: Dictionary, errors: Array[String]) -> void:
	for raw_scenario_id in scenarios.keys():
		var scenario_id := str(raw_scenario_id)
		var result = scenarios[raw_scenario_id]
		if not result is Dictionary:
			errors.append("scenario.type: %s/%s" % [key, scenario_id])
			continue
		var measured := result as Dictionary
		for kind in [Budget.ENCOUNTER_NORMAL, Budget.ENCOUNTER_ELITE]:
			var gained := float(measured.get("%s_charge" % kind, -1.0))
			var cap := Budget.encounter_cap(kind)
			if gained < 0.0 or gained > cap + 0.001:
				errors.append("scenario.encounter_cap: %s/%s %s gained %.2f over cap %.2f" % [key, scenario_id, kind, gained, cap])
		var taken := float(measured.get("normal_taken_charge", 0.0))
		if taken > Budget.taken_channel_cap(Budget.ENCOUNTER_NORMAL) + 0.001:
			errors.append("scenario.taken_channel_cap: %s/%s taken %.2f" % [key, scenario_id, taken])
		# The recurring cadence — measured AFTER the first activation, so a
		# once-per-run Atlas pre-charge cannot hide inside it.
		var recurring := int(measured.get("recurring_encounters_to_ready", 0))
		if recurring < Budget.MIN_ENCOUNTERS_TO_READY:
			errors.append("scenario.recurring_cadence: %s/%s ready again after %d encounters" % [key, scenario_id, recurring])
		var activations := int(measured.get("activations_per_encounter", 0))
		if activations != Budget.MAX_ACTIVATIONS_PER_ENCOUNTER:
			errors.append("scenario.activation_gate: %s/%s allowed %d activations in one encounter" % [key, scenario_id, activations])

	var neutral = scenarios.get(NEUTRAL_SCENARIO_ID)
	if not neutral is Dictionary:
		errors.append("scenario.neutral_missing: %s" % key)
		return
	var neutral_result := neutral as Dictionary
	for kind in [Budget.ENCOUNTER_NORMAL, Budget.ENCOUNTER_ELITE]:
		var bounds := Budget.corridor(kind)
		var gained := float(neutral_result.get("%s_charge" % kind, -1.0))
		if gained < bounds.x - 0.001 or gained > bounds.y + 0.001:
			errors.append("neutral.corridor: %s %s gained %.2f outside [%.1f, %.1f]" % [key, kind, gained, bounds.x, bounds.y])
	var first_ready := int(neutral_result.get("encounters_to_ready", 0))
	if first_ready < Budget.MIN_ENCOUNTERS_TO_READY or first_ready > Budget.NEUTRAL_ENCOUNTERS_TO_READY_MAX:
		errors.append("neutral.readiness: %s ready after %d normal encounters" % [key, first_ready])

	var overkill = scenarios.get(OVERKILL_SCENARIO_ID)
	if overkill is Dictionary:
		var overkill_charge := float((overkill as Dictionary).get("normal_charge", -1.0))
		var neutral_charge := float(neutral_result.get("normal_charge", 0.0))
		if not is_equal_approx(overkill_charge, neutral_charge):
			errors.append("overkill.no_inflation: %s gained %.2f vs neutral %.2f" % [key, overkill_charge, neutral_charge])

	var tank = scenarios.get(TANK_SCENARIO_ID)
	if tank is Dictionary:
		var tank_taken := float((tank as Dictionary).get("normal_taken_charge", 0.0))
		if tank_taken > Budget.taken_channel_cap(Budget.ENCOUNTER_NORMAL) + 0.001:
			errors.append("tank.taken_channel_cap: %s taken %.2f" % [key, tank_taken])


## The three weapons of a class must price their ultimates against their OWN
## output: same corridor, different absolute budget. That is what keeps the
## solo / AoE / defense identity of the trio intact once the packs land.
static func _check_class_trio(class_id: String, rows: Array, errors: Array[String]) -> void:
	if rows.size() != 3:
		errors.append("class.trio_size: %s has %d weapons" % [class_id, rows.size()])
		return
	var archetypes := {}
	var boss_caps := {}
	for raw_row in rows:
		var row := raw_row as Dictionary
		var reference_dps := maxf(float(row.get("reference_solo_dps", 0.0)), 0.0001)
		var seconds := float(row.get("power_budget_max", 0.0)) / reference_dps
		if not is_equal_approx(seconds, Budget.POWER_SECONDS_MAX):
			errors.append("class.trio_power_ratio: %s/%s prices its ultimate at %.2fs" % [class_id, str(row.get("weapon_id", "?")), seconds])
		archetypes[str(row.get("power_archetype", ""))] = true
		boss_caps[snappedf(float(row.get("total_boss_cap", 0.0)), 0.0001)] = true
	if archetypes.size() != 1:
		errors.append("class.trio_archetype: %s mixes power archetypes" % class_id)
	if boss_caps.size() != 1:
		errors.append("class.trio_boss_cap: %s declares more than one boss cap" % class_id)


static func _measure_scenario(row: Dictionary, scenario: Dictionary) -> Dictionary:
	var normal := _simulate_encounter(row, scenario, Budget.ENCOUNTER_NORMAL)
	var elite := _simulate_encounter(row, scenario, Budget.ENCOUNTER_ELITE)
	return {
		"normal_charge": float(normal["charge"]),
		"normal_taken_charge": float(normal["taken_charge"]),
		"elite_charge": float(elite["charge"]),
		"elite_taken_charge": float(elite["taken_charge"]),
		"build_multiplier": Budget.build_multiplier(
			float(scenario.get("energy", 0.0)), float(scenario.get("ult_charge_multiplier", 1.0))
		),
		"encounters_to_ready": _encounters_to_ready(row, scenario, false),
		"recurring_encounters_to_ready": _encounters_to_ready(row, scenario, true),
		"activations_per_encounter": _activations_in_one_encounter(row, scenario),
	}


static func _new_ledger(row: Dictionary, scenario: Dictionary) -> Ledger:
	var ledger := Ledger.new(row)
	ledger.set_build(
		float(scenario.get("energy", 0.0)), float(scenario.get("ult_charge_multiplier", 1.0))
	)
	ledger.apply_start_charge(float(scenario.get("start_charge", 0.0)))
	return ledger


## One encounter of the weapon's own normalized window.
static func _run_encounter(ledger: Ledger, row: Dictionary, scenario: Dictionary, kind: String) -> Dictionary:
	ledger.begin_encounter(kind)
	var before := ledger.charge
	var taken_before := ledger.encounter_taken_charge()
	var hp_pool := float(row.get("reference_solo_dps", 0.0)) * Budget.encounter_seconds(kind)
	var attempted := hp_pool * maxf(float(scenario.get("output_factor", 1.0)), 0.0)
	# HP that is not there cannot be removed: overkill buys nothing.
	ledger.add_removed_health(minf(attempted, hp_pool))
	var bars := float(scenario.get("health_bars_lost", Budget.neutral_health_bars_lost(kind)))
	ledger.add_taken_health(bars * REFERENCE_MAX_HEALTH, REFERENCE_MAX_HEALTH)
	return {
		"charge": ledger.charge - before,
		"taken_charge": ledger.encounter_taken_charge() - taken_before,
	}


static func _simulate_encounter(row: Dictionary, scenario: Dictionary, kind: String) -> Dictionary:
	return _run_encounter(_new_ledger(row, scenario), row, scenario, kind)


## Normal encounters needed before the ultimate is available. With
## `after_first_activation` the Atlas pre-charge is spent first, so the result is
## the recurring cadence rather than the one-off run opener.
static func _encounters_to_ready(row: Dictionary, scenario: Dictionary, after_first_activation: bool) -> int:
	var ledger := _new_ledger(row, scenario)
	if after_first_activation:
		var opener := 0
		while not ledger.is_ready() and opener < READY_SEARCH_LIMIT:
			_run_encounter(ledger, row, scenario, Budget.ENCOUNTER_NORMAL)
			opener += 1
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		if not ledger.try_activate():
			return 0
	var encounters := 0
	while not ledger.is_ready() and encounters < READY_SEARCH_LIMIT:
		_run_encounter(ledger, row, scenario, Budget.ENCOUNTER_NORMAL)
		encounters += 1
	return encounters


## A full bar plus a whole encounter of income must still buy exactly one cast.
static func _activations_in_one_encounter(row: Dictionary, scenario: Dictionary) -> int:
	var ledger := _new_ledger(row, scenario)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	var activations := 0
	for attempt in 4:
		if ledger.try_activate():
			activations += 1
		_run_encounter_without_reset(ledger, row, scenario)
		ledger.apply_start_charge(1.0)
	return activations


static func _run_encounter_without_reset(ledger: Ledger, row: Dictionary, scenario: Dictionary) -> void:
	var hp_pool := float(row.get("reference_solo_dps", 0.0)) * Budget.NORMAL_ENCOUNTER_SECONDS
	ledger.add_removed_health(hp_pool * maxf(float(scenario.get("output_factor", 1.0)), 0.0))


## The `coverage=all_enemies` assertion (FAN-2949). `class_sources` maps
## class_id -> the concatenated executor source of that class package (the
## caller gathers it; the harness only judges, like `violations()`). Overrides
## exist so the negative controls can exercise the ratchet itself.
static func coverage_violations(
	class_sources: Dictionary,
	allowlist: Dictionary = COVERAGE_MIGRATION_ALLOWLIST,
	converted: Array[String] = COVERAGE_V2_CLASSES
) -> Array[String]:
	var errors: Array[String] = []
	for raw_class_id in allowlist.keys():
		var class_id := str(raw_class_id)
		if not class_sources.has(class_id):
			errors.append("coverage.allowlist_unknown: entry '%s' names no class package" % class_id)
		elif str(allowlist[raw_class_id]).strip_edges().is_empty():
			errors.append("coverage.allowlist_reason_missing: entry '%s' states no reason" % class_id)

	for raw_class_id in class_sources.keys():
		var class_id := str(raw_class_id)
		var source := str(class_sources[raw_class_id])
		var caps := count_cap_params(source)
		var clean := caps.is_empty()
		var is_converted := converted.has(class_id)
		if allowlist.has(class_id):
			# Stale entry: the class already satisfies v2, so its allowlist
			# entry must be gone — the allowlist only ever shrinks.
			if clean and is_converted:
				errors.append(
					"coverage.allowlist_stale: %s already satisfies coverage=%s; remove its entry" % [class_id, Budget.COVERAGE_ALL_ENEMIES]
				)
			continue
		# Outside the allowlist the class is asserted against v2 and fails
		# closed: converted AND clean, or red.
		if not is_converted:
			errors.append(
				"coverage.conversion_missing: %s is outside the allowlist but not in COVERAGE_V2_CLASSES" % class_id
			)
		if not clean:
			errors.append(
				"coverage.count_cap: %s declares count-shaped parameters %s — prohibited by coverage=%s" % [class_id, str(caps), Budget.COVERAGE_ALL_ENEMIES]
			)
	return errors


## Every count-shaped parameter name in an executor source. Per-target damage
## shaping (`*_target_cap_fraction`, `*_target_cap_flat`) is not a count cap.
static func count_cap_params(source: String) -> Array[String]:
	var pattern := RegEx.create_from_string(COUNT_CAP_PARAM_PATTERN)
	var found: Array[String] = []
	for raw_match in pattern.search_all(source):
		var param := str((raw_match as RegExMatch).get_string())
		var is_shaping := false
		for suffix in COUNT_CAP_SHAPING_SUFFIXES:
			if param.ends_with(suffix):
				is_shaping = true
				break
		if not is_shaping and not found.has(param):
			found.append(param)
	found.sort()
	return found
