extends RefCounted

# FAN-1513: standalone A5 conditional-final scenario pack.
#
# The pack owns its canonical family matrix, its versioned convergence rule and
# its A/B oracle, so it loads and verifies without any sibling A5 scenario pack
# and without touching the canonical FAN-1438 artifacts. Everything in this file
# is pure and static: the runtime probe in conditional_final_probe.gd produces
# the measurements, this script decides whether they are admissible.
#
# Production balance data is read-only here. The pack only observes the live
# runtime through the same production signals the FAN-1511 telemetry uses.

const PACK_ID := "a5_conditional_final"
const PACK_CONTRACT := "a5.scenario-pack.v1"
const CONVERGENCE_RULE := "a5.conditional-convergence.v1"
const FRAGMENT_SCHEMA := "fan1513.a5-conditional-fragment.v1"
const FRAGMENT_DIR := "res://docs/design/reports/fan1438_a5_balance/fragments/conditional"
const FRAGMENT_PATH := FRAGMENT_DIR + "/conditional_final_convergence.json"

# Convergence rule a5.conditional-convergence.v1.
#
# A conditional final only pays out when its gating condition is met, so the
# per-seed event count is a discrete, low-count variable: a single seed proves
# nothing. The rule below is the whole policy and every number in it is
# load-bearing and asserted by tests/a5/scenarios/conditional_final_pack_test.gd.
#
# * A verdict needs at least MIN_SEEDS distinct seeds and a measurement window of
#   at least MIN_WINDOW_SECONDS. Anything smaller is inadmissible, not "probably
#   fine".
# * Admissible samples must also be stable: the coefficient of variation of the
#   per-seed trigger counts must be at or below CV_THRESHOLD.
# * A sample that is admissible but unstable escalates - first more seeds up to
#   MAX_SEEDS, then a longer window in WINDOW_STEP_SECONDS steps up to
#   MAX_WINDOW_SECONDS.
# * When escalation is exhausted and the sample is still unstable the pair fails
#   closed. A high-CV sample never converts into a green verdict by running out
#   of budget.
const MIN_SEEDS := 3
const MAX_SEEDS := 7
const MIN_WINDOW_SECONDS := 6.0
const MAX_WINDOW_SECONDS := 12.0
const WINDOW_STEP_SECONDS := 3.0
const CV_THRESHOLD := 0.15
const SEEDS := [151301, 151302, 151303, 151304, 151305, 151306, 151307]

# Canonical conditional-final family matrix.
#
# Scope is the conditional families whose final cannot fire from an unconditional
# weapon hit: a summon must be commanded or must die, a deployable must reach its
# own pulse/heat/trigger condition, a mine must detonate next to another mine, and
# kill/execute finals need a target that can actually die. Geometric offensive
# finals, defensive/reactive finals and ultimate attribution belong to the sibling
# packs and are deliberately absent here.
#
# Per entry:
#   trigger_event   production event name the final resolver is dispatched with.
#   stimulus        executable trigger the probe applies on top of auto-attack.
#   fixture         "sustain" (immortal dummies) or "mortal" (targets that die).
#   layout          "pack" (the canonical A5 huddle) or "ring" at layout_radius.
#                   A deployable that places itself at a fixed distance from its
#                   owner never meets a huddle: engineer mines drop into a 110-260
#                   ring, so a pack at 80 leaves most of them dud, clogs the mine
#                   cap and starves the chain. The ring layout puts the targets
#                   where the deployable actually lands.
#   expected_sources damage buckets that must exist in the enabled arm sample.
#   damage_evidence "tagged"        -> the payout carries constellation_final and
#                                      must show up as final-event damage;
#                   "resolver_only" -> the payout is a status/buff/untagged hit,
#                                      so the resolver trigger is the evidence.
#   min_triggers    minimum triggered resolutions per seed in the enabled arm.
const FAMILY_MATRIX := [
	{
		"family": "summon",
		"class_id": "druid",
		"weapon_id": "summon_amulet",
		"mechanic_id": "pack_alpha_pounce_guard",
		"trigger_event": "command",
		"stimulus": "autofire",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "tagged",
		"min_triggers": 1,
	},
	{
		"family": "summon_death",
		"class_id": "chemist",
		"weapon_id": "homunculus_vial",
		"mechanic_id": "homunculus_intercept_death_burst",
		"trigger_event": "summon_death",
		"stimulus": "summon_lethal",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "tagged",
		"min_triggers": 1,
	},
	{
		"family": "deploy",
		"class_id": "engineer",
		"weapon_id": "engineer_sentry_wrench",
		"mechanic_id": "sentry_marked_target_overclock",
		"trigger_event": "sentry_hit",
		"stimulus": "autofire",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "resolver_only",
		"min_triggers": 1,
	},
	{
		"family": "deploy",
		"class_id": "engineer",
		"weapon_id": "engineer_repair_drone",
		"mechanic_id": "drone_excess_repair_shield",
		"trigger_event": "repair",
		"stimulus": "autofire",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "resolver_only",
		"min_triggers": 1,
	},
	{
		"family": "deploy",
		"class_id": "druid",
		"weapon_id": "raven_totem",
		"mechanic_id": "totem_every_nth_raven_strike",
		"trigger_event": "totem_pulse",
		"stimulus": "autofire",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "resolver_only",
		"min_triggers": 1,
	},
	{
		"family": "deploy",
		"class_id": "guitarist",
		"weapon_id": "sound_amp",
		"mechanic_id": "amp_instrument_echo",
		"trigger_event": "amp_pulse",
		"stimulus": "autofire",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "tagged",
		"min_triggers": 1,
	},
	{
		"family": "deploy",
		"class_id": "ranger",
		"weapon_id": "hunter_trap",
		"mechanic_id": "trap_prey_mark_distribution",
		"trigger_event": "trap_trigger",
		"stimulus": "autofire",
		"fixture": "sustain",
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "tagged",
		"min_triggers": 1,
	},
	{
		"family": "mine",
		"class_id": "engineer",
		"weapon_id": "engineer_pressure_mines",
		"mechanic_id": "mine_adjacency_chain",
		"trigger_event": "mine_explosion",
		"stimulus": "autofire",
		"fixture": "sustain",
		"layout": "ring",
		"layout_radius": 185.0,
		"target_count": 10,
		"initial_target_hp": 0.0,
		"warmup_seconds": 4.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "resolver_only",
		"min_triggers": 1,
	},
	{
		"family": "kill",
		"class_id": "dark_mage",
		"weapon_id": "cursed_skull",
		"mechanic_id": "skull_death_curse_transfer",
		"trigger_event": "kill",
		"stimulus": "autofire",
		"fixture": "mortal",
		"target_count": 10,
		"initial_target_hp": 40.0,
		"warmup_seconds": 2.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "resolver_only",
		"min_triggers": 1,
	},
	{
		"family": "execute",
		"class_id": "assassin",
		"weapon_id": "shadow_daggers",
		"mechanic_id": "dagger_execute_shadow_window",
		"trigger_event": "execute",
		"stimulus": "autofire",
		"fixture": "mortal",
		"target_count": 10,
		"initial_target_hp": 40.0,
		"warmup_seconds": 2.0,
		"expected_sources": ["player_weapon|damage_application"],
		"damage_evidence": "resolver_only",
		"min_triggers": 1,
	},
]

const FAMILIES := ["summon", "summon_death", "deploy", "mine", "kill", "execute"]
# Kill-driven finals only resolve when a target actually dies, so an immortal
# dummy silently turns their probe into a no-op. The matrix must never regress to
# that fixture for these families.
const MORTAL_ONLY_FAMILIES := ["kill", "execute", "summon_death"]
const STIMULI := ["autofire", "summon_lethal"]
const DAMAGE_EVIDENCE_KINDS := ["tagged", "resolver_only"]


static func contract() -> Dictionary:
	return {
		"pack_id": PACK_ID,
		"pack_contract": PACK_CONTRACT,
		"convergence_rule": CONVERGENCE_RULE,
		"fragment_schema": FRAGMENT_SCHEMA,
		"convergence": {
			"min_seeds": MIN_SEEDS,
			"max_seeds": MAX_SEEDS,
			"min_window_seconds": MIN_WINDOW_SECONDS,
			"max_window_seconds": MAX_WINDOW_SECONDS,
			"window_step_seconds": WINDOW_STEP_SECONDS,
			"cv_threshold": CV_THRESHOLD,
		},
	}


static func pair_key(entry: Dictionary) -> String:
	return "%s/%s" % [entry.get("class_id", ""), entry.get("weapon_id", "")]


static func verify_matrix(matrix := FAMILY_MATRIX) -> Dictionary:
	var errors := PackedStringArray()
	var seen := {}
	var covered_families := {}
	if matrix.is_empty():
		errors.append("family matrix must not be empty")
	for entry_value in matrix:
		var entry: Dictionary = entry_value
		var key := pair_key(entry)
		if seen.has(key):
			errors.append("%s appears more than once in the family matrix" % key)
		seen[key] = true
		var family := str(entry.get("family", ""))
		if not FAMILIES.has(family):
			errors.append("%s declares unknown conditional family %s" % [key, family])
		covered_families[family] = true
		for field in ["class_id", "weapon_id", "mechanic_id", "trigger_event"]:
			if str(entry.get(field, "")) == "":
				errors.append("%s is missing %s" % [key, field])
		if not STIMULI.has(str(entry.get("stimulus", ""))):
			errors.append("%s declares unknown executable trigger %s" % [key, entry.get("stimulus", "")])
		if not DAMAGE_EVIDENCE_KINDS.has(str(entry.get("damage_evidence", ""))):
			errors.append("%s declares unknown damage evidence %s" % [key, entry.get("damage_evidence", "")])
		if int(entry.get("min_triggers", 0)) < 1:
			errors.append("%s must expect at least one trigger per seed" % key)
		if (entry.get("expected_sources", []) as Array).is_empty():
			errors.append("%s must declare at least one expected damage source bucket" % key)
		if int(entry.get("target_count", 0)) < 1:
			errors.append("%s must declare at least one target" % key)
		if float(entry.get("warmup_seconds", 0.0)) <= 0.0:
			errors.append("%s must declare a positive warm-up" % key)
		var fixture := str(entry.get("fixture", ""))
		if not ["sustain", "mortal"].has(fixture):
			errors.append("%s declares unknown fixture %s" % [key, fixture])
		var layout := str(entry.get("layout", "pack"))
		if not ["pack", "ring"].has(layout):
			errors.append("%s declares unknown target layout %s" % [key, layout])
		if layout == "ring" and float(entry.get("layout_radius", 0.0)) <= 0.0:
			errors.append("%s uses the ring layout and must pin a positive radius" % key)
		if MORTAL_ONLY_FAMILIES.has(family):
			if fixture != "mortal" and str(entry.get("stimulus", "")) == "autofire":
				errors.append("%s is a %s final and needs a mortal target fixture or an explicit lethal stimulus" % [key, family])
		if fixture == "mortal" and float(entry.get("initial_target_hp", 0.0)) <= 0.0:
			errors.append("%s uses the mortal fixture and must pin a positive target HP" % key)
	for family in FAMILIES:
		if not covered_families.has(family):
			errors.append("conditional family %s has no matrix entry" % family)
	return {"ok": errors.is_empty(), "errors": errors}


static func coefficient_of_variation(values: Array) -> float:
	# Fail closed: an empty, single-value or zero-mean sample carries no evidence
	# of stability, so it reports infinite dispersion rather than a tidy 0.0.
	if values.size() < 2:
		return INF
	var total := 0.0
	for value in values:
		total += float(value)
	var mean := total / float(values.size())
	if is_zero_approx(mean):
		return INF
	var variance := 0.0
	for value in values:
		variance += pow(float(value) - mean, 2.0)
	variance /= float(values.size())
	return sqrt(variance) / absf(mean)


static func can_escalate(seed_count: int, window_seconds: float) -> bool:
	return seed_count < MAX_SEEDS or window_seconds < MAX_WINDOW_SECONDS


static func next_escalation(seed_count: int, window_seconds: float) -> Dictionary:
	# Seeds are cheaper than window seconds per unit of extra evidence, so the
	# rule spends the whole seed budget before it lengthens the window.
	if seed_count < MAX_SEEDS:
		return {"ok": true, "seed_count": seed_count + 1, "window_seconds": window_seconds}
	if window_seconds < MAX_WINDOW_SECONDS:
		return {"ok": true, "seed_count": seed_count, "window_seconds": minf(window_seconds + WINDOW_STEP_SECONDS, MAX_WINDOW_SECONDS)}
	return {"ok": false, "seed_count": seed_count, "window_seconds": window_seconds}


static func evaluate_convergence(per_seed_values: Array, seed_count: int, window_seconds: float) -> Dictionary:
	var errors := PackedStringArray()
	if seed_count < MIN_SEEDS:
		errors.append("sample of %d seeds is below the %d-seed minimum" % [seed_count, MIN_SEEDS])
	if per_seed_values.size() != seed_count:
		errors.append("expected %d per-seed values, got %d" % [seed_count, per_seed_values.size()])
	if window_seconds < MIN_WINDOW_SECONDS:
		errors.append("window of %.2fs is below the %.2fs minimum" % [window_seconds, MIN_WINDOW_SECONDS])
	var cv := coefficient_of_variation(per_seed_values)
	var converged := is_finite(cv) and cv <= CV_THRESHOLD
	if not converged:
		errors.append("coefficient of variation %s exceeds the %.2f threshold" % ["inf" if not is_finite(cv) else "%.4f" % cv, CV_THRESHOLD])
	return {
		"ok": errors.is_empty(),
		"rule": CONVERGENCE_RULE,
		"cv": cv if is_finite(cv) else -1.0,
		"cv_threshold": CV_THRESHOLD,
		"seed_count": seed_count,
		"window_seconds": window_seconds,
		"converged": converged,
		"escalation_available": can_escalate(seed_count, window_seconds),
		"errors": errors,
	}


static func evaluate_pair(entry: Dictionary, measurement: Dictionary) -> Dictionary:
	var key := pair_key(entry)
	var errors := PackedStringArray()
	var enabled: Dictionary = measurement.get("enabled", {})
	var disabled: Dictionary = measurement.get("disabled", {})
	var per_seed: Array = measurement.get("per_seed_triggers", [])
	var seed_count := int(measurement.get("seed_count", 0))
	var window_seconds := float(measurement.get("window_seconds", 0.0))
	if enabled.is_empty() or disabled.is_empty():
		errors.append("%s is missing an A/B arm" % key)
	# AC4: a pair with no observed trigger can never reach a green verdict, no
	# matter how stable or how large the surrounding damage numbers are.
	var enabled_triggers := int(enabled.get("trigger_resolutions", 0))
	var min_triggers := int(entry.get("min_triggers", 1))
	if enabled_triggers < min_triggers * seed_count:
		errors.append("%s observed %d triggered %s resolutions across %d seeds, expected at least %d" % [key, enabled_triggers, entry.get("trigger_event", ""), seed_count, min_triggers * seed_count])
	if int(disabled.get("trigger_resolutions", 0)) != 0:
		errors.append("%s resolved its final in the disabled arm; the A/B arms are not isolated" % key)
	if int(disabled.get("final_event_count", 0)) != 0:
		errors.append("%s emitted final telemetry events in the disabled arm" % key)
	for source_value in entry.get("expected_sources", []):
		if not (enabled.get("damage_sources", []) as Array).has(str(source_value)):
			errors.append("%s enabled arm is missing the %s damage bucket" % [key, source_value])
	var damage_delta := float(enabled.get("ledger_damage", 0.0)) - float(disabled.get("ledger_damage", 0.0))
	# AC4's quantitative isolation is the mechanic-attributed final-event damage,
	# not the total-damage delta. A final routinely substitutes for baseline output
	# rather than adding to it - an alpha pounce replaces the attack the ally would
	# have made anyway, an overclocked sentry retargets, a mine chain detonates a
	# mine that would have fired later - so the ledger delta is small, sometimes
	# negative, and flips sign between runs even at a fixed seed. It is recorded in
	# the fragment as context; the oracle asserts on the attributed damage, which is
	# a positive quantity in the enabled arm and exactly zero in the disabled one.
	if str(entry.get("damage_evidence", "")) == "tagged":
		if float(enabled.get("final_event_damage", 0.0)) <= 0.0:
			errors.append("%s declares tagged payouts but isolated no final-event damage" % key)
	if float(disabled.get("final_event_damage", 0.0)) != 0.0:
		errors.append("%s attributed final-event damage in the disabled arm" % key)
	var convergence := evaluate_convergence(per_seed, seed_count, window_seconds)
	if not bool(convergence.get("ok", false)):
		for convergence_error in convergence.get("errors", []):
			errors.append("%s convergence: %s" % [key, convergence_error])
	return {
		"ok": errors.is_empty(),
		"pair": key,
		"family": str(entry.get("family", "")),
		"mechanic_id": str(entry.get("mechanic_id", "")),
		"verdict": "green" if errors.is_empty() else "red",
		"final_event_damage": float(enabled.get("final_event_damage", 0.0)),
		"damage_delta": damage_delta,
		"convergence": convergence,
		"errors": errors,
	}


static func evaluate_fragment(fragment: Dictionary, matrix := FAMILY_MATRIX) -> Dictionary:
	var errors := PackedStringArray()
	if str(fragment.get("fragment_schema", "")) != FRAGMENT_SCHEMA:
		errors.append("fragment schema %s is not %s" % [fragment.get("fragment_schema", ""), FRAGMENT_SCHEMA])
	if str(fragment.get("pack_contract", "")) != PACK_CONTRACT:
		errors.append("fragment pack contract %s is not %s" % [fragment.get("pack_contract", ""), PACK_CONTRACT])
	if str(fragment.get("convergence_rule", "")) != CONVERGENCE_RULE:
		errors.append("fragment convergence rule %s is not %s" % [fragment.get("convergence_rule", ""), CONVERGENCE_RULE])
	var matrix_check := verify_matrix(matrix)
	for matrix_error in matrix_check.get("errors", []):
		errors.append(str(matrix_error))
	var measurements: Dictionary = fragment.get("measurements", {})
	var pair_results := []
	for entry_value in matrix:
		var entry: Dictionary = entry_value
		var key := pair_key(entry)
		if not measurements.has(key):
			errors.append("%s has no measurement in the fragment" % key)
			continue
		var result := evaluate_pair(entry, measurements[key])
		pair_results.append(result)
		for pair_error in result.get("errors", []):
			errors.append(str(pair_error))
	return {"ok": errors.is_empty(), "pairs": pair_results, "errors": errors}
