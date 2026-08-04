extends SceneTree

# FAN-1513: targeted suite for the A5 conditional-final scenario pack.
#
# The pack's runtime probe costs minutes because it drives the real game loop, so
# this suite covers the parts that decide a verdict - the family matrix, the
# versioned convergence rule and the A/B oracle - against synthetic measurements,
# and then checks the committed fragment the probe actually produced against the
# same code. Every fail-closed branch is exercised from the failing side: a rule
# that is never observed rejecting anything is not a rule.

const Pack := preload("res://tools/a5/scenarios/conditional/conditional_final_pack.gd")

var _errors := PackedStringArray()


func _initialize() -> void:
	_verify_contract()
	_verify_matrix()
	_verify_matrix_rejects_regressions()
	_verify_coefficient_of_variation()
	_verify_convergence_rule()
	_verify_escalation()
	_verify_ab_oracle()
	_verify_committed_fragment()
	_finish()


func _verify_contract() -> void:
	var contract := Pack.contract()
	_check(str(contract.get("pack_contract", "")) == "a5.scenario-pack.v1", "pack must declare the versioned scenario-pack contract")
	_check(str(contract.get("convergence_rule", "")) == "a5.conditional-convergence.v1", "pack must declare the versioned convergence rule")
	# AC3: the threshold and the minimum sample/window are part of the contract,
	# not an implementation detail a later change can quietly relax.
	var convergence: Dictionary = contract.get("convergence", {})
	_check(float(convergence.get("cv_threshold", -1.0)) == 0.15, "convergence rule v1 pins a 0.15 CV threshold")
	_check(int(convergence.get("min_seeds", 0)) == 3, "convergence rule v1 pins a 3-seed minimum sample")
	_check(int(convergence.get("max_seeds", 0)) == 7, "convergence rule v1 pins a 7-seed escalation ceiling")
	_check(float(convergence.get("min_window_seconds", 0.0)) == 6.0, "convergence rule v1 pins a 6.0s minimum window")
	_check(float(convergence.get("max_window_seconds", 0.0)) == 12.0, "convergence rule v1 pins a 12.0s window ceiling")
	_check(Pack.SEEDS.size() >= Pack.MAX_SEEDS, "the pinned seed list must cover the escalation ceiling")


func _verify_matrix() -> void:
	var result := Pack.verify_matrix()
	for error_value in result.get("errors", []):
		_check(false, "canonical family matrix: %s" % error_value)
	# AC1/AC2: every conditional family named by the issue has an executable pair,
	# and the kill-driven ones cannot regress to an immortal dummy.
	var families := {}
	for entry_value in Pack.FAMILY_MATRIX:
		var entry: Dictionary = entry_value
		families[str(entry.get("family", ""))] = true
		if Pack.MORTAL_ONLY_FAMILIES.has(str(entry.get("family", ""))):
			var mortal := str(entry.get("fixture", "")) == "mortal"
			var lethal_stimulus := str(entry.get("stimulus", "")) != "autofire"
			_check(mortal or lethal_stimulus, "%s must run against targets that can die" % Pack.pair_key(entry))
		_check(float(entry.get("warmup_seconds", 0.0)) > 0.0, "%s must warm its deployables up before measuring" % Pack.pair_key(entry))
	for family in ["summon", "summon_death", "deploy", "mine", "kill", "execute"]:
		_check(families.has(family), "conditional family %s must have a matrix entry" % family)


func _verify_matrix_rejects_regressions() -> void:
	var base: Dictionary = (Pack.FAMILY_MATRIX[0] as Dictionary).duplicate(true)
	var kill_entry := _matrix_entry_for_family("kill")
	var sustain_kill := kill_entry.duplicate(true)
	sustain_kill["fixture"] = "sustain"
	sustain_kill["stimulus"] = "autofire"
	_check(not bool(Pack.verify_matrix([sustain_kill]).get("ok", false)), "a kill final on immortal dummies must be rejected")
	var zero_triggers := base.duplicate(true)
	zero_triggers["min_triggers"] = 0
	_check(not bool(Pack.verify_matrix([zero_triggers]).get("ok", false)), "a pair expecting zero events must be rejected")
	var duplicated := [base.duplicate(true), base.duplicate(true)]
	_check(not bool(Pack.verify_matrix(duplicated).get("ok", false)), "a duplicated pair must be rejected")
	_check(not bool(Pack.verify_matrix([]).get("ok", false)), "an empty family matrix must be rejected")
	var unknown_stimulus := base.duplicate(true)
	unknown_stimulus["stimulus"] = "hope"
	_check(not bool(Pack.verify_matrix([unknown_stimulus]).get("ok", false)), "a pair without an executable trigger must be rejected")


func _verify_coefficient_of_variation() -> void:
	_check(Pack.coefficient_of_variation([4, 4, 4]) == 0.0, "an identical sample has zero dispersion")
	_check(is_equal_approx(Pack.coefficient_of_variation([2, 4]), 1.0 / 3.0), "CV is the population sigma over the mean")
	# Fail closed: samples that carry no evidence report infinite dispersion rather
	# than a comfortable zero.
	_check(not is_finite(Pack.coefficient_of_variation([])), "an empty sample must not report a finite CV")
	_check(not is_finite(Pack.coefficient_of_variation([5])), "a single-value sample must not report a finite CV")
	_check(not is_finite(Pack.coefficient_of_variation([0, 0, 0])), "an all-zero sample must not report a finite CV")


func _verify_convergence_rule() -> void:
	_check(bool(Pack.evaluate_convergence([6, 6, 6], 3, 6.0).get("ok", false)), "a stable sample at the pinned minimums converges")
	_check(not bool(Pack.evaluate_convergence([6, 6], 2, 6.0).get("ok", false)), "a sample below the seed minimum must fail closed")
	_check(not bool(Pack.evaluate_convergence([6, 6, 6], 3, 4.0).get("ok", false)), "a window below the minimum must fail closed")
	_check(not bool(Pack.evaluate_convergence([6, 6], 3, 6.0).get("ok", false)), "a truncated per-seed series must fail closed")
	# AC3: a high-CV sample is rejected, including when escalation is exhausted.
	# Running out of budget must never be a way to reach a verdict.
	_check(not bool(Pack.evaluate_convergence([1, 9, 2], 3, 6.0).get("ok", false)), "a high-CV sample must fail closed")
	var exhausted := Pack.evaluate_convergence([1, 9, 2, 8, 1, 7, 2], Pack.MAX_SEEDS, Pack.MAX_WINDOW_SECONDS)
	_check(not bool(exhausted.get("ok", false)), "a high-CV sample at the escalation ceiling must fail closed")
	_check(not bool(exhausted.get("escalation_available", true)), "the escalation ceiling must report itself exhausted")
	var borderline := Pack.evaluate_convergence([100, 100, 140], 3, 6.0)
	_check(float(borderline.get("cv", -1.0)) > Pack.CV_THRESHOLD, "the borderline fixture must sit above the threshold")
	_check(not bool(borderline.get("ok", false)), "a sample just above the threshold must fail closed")


func _verify_escalation() -> void:
	var first := Pack.next_escalation(Pack.MIN_SEEDS, Pack.MIN_WINDOW_SECONDS)
	_check(int(first.get("seed_count", 0)) == Pack.MIN_SEEDS + 1, "escalation spends the seed budget first")
	_check(float(first.get("window_seconds", 0.0)) == Pack.MIN_WINDOW_SECONDS, "escalation does not lengthen the window while seeds remain")
	var widened := Pack.next_escalation(Pack.MAX_SEEDS, Pack.MIN_WINDOW_SECONDS)
	_check(float(widened.get("window_seconds", 0.0)) == Pack.MIN_WINDOW_SECONDS + Pack.WINDOW_STEP_SECONDS, "escalation lengthens the window once seeds are exhausted")
	var capped := Pack.next_escalation(Pack.MAX_SEEDS, Pack.MAX_WINDOW_SECONDS)
	_check(not bool(capped.get("ok", false)), "escalation must stop at the pinned ceiling")
	_check(not Pack.can_escalate(Pack.MAX_SEEDS, Pack.MAX_WINDOW_SECONDS), "the ceiling must not advertise further escalation")


func _verify_ab_oracle() -> void:
	var tagged := _matrix_entry_for_evidence("tagged")
	var resolver := _matrix_entry_for_evidence("resolver_only")
	_check(bool(Pack.evaluate_pair(tagged, _measurement(tagged, {})).get("ok", false)), "a well-formed tagged A/B measurement is green")
	_check(bool(Pack.evaluate_pair(resolver, _measurement(resolver, {})).get("ok", false)), "a well-formed resolver-only A/B measurement is green")

	# AC4: the missing-event verdict. A pair that never resolved its final stays red
	# no matter how large the surrounding damage numbers are.
	var silent := _measurement(tagged, {"enabled_triggers": 0, "enabled_ledger": 999999.0})
	var silent_result := Pack.evaluate_pair(tagged, silent)
	_check(not bool(silent_result.get("ok", false)), "a pair with no observed trigger must never be green")
	_check(str(silent_result.get("verdict", "")) == "red", "a pair with no observed trigger must report a red verdict")
	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"enabled_triggers": 2})).get("ok", false)), "fewer triggers than the matrix expects must fail")

	# The arms must stay isolated: the disabled arm proves the node removal worked.
	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"disabled_triggers": 1})).get("ok", false)), "a final that resolves in the disabled arm must fail")
	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"disabled_final_events": 1})).get("ok", false)), "final telemetry in the disabled arm must fail")

	# AC4: quantitative isolation for the pairs whose payout is tagged.
	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"enabled_final_damage": 0.0})).get("ok", false)), "a tagged payout with no isolated final damage must fail")
	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"disabled_final_damage": 1.0})).get("ok", false)), "final damage attributed without the node must fail")
	_check(not bool(Pack.evaluate_pair(resolver, _measurement(resolver, {"disabled_final_damage": 1.0})).get("ok", false)), "final damage attributed without the node must fail for resolver-only pairs too")
	# A final often substitutes for baseline output instead of adding to it, so the
	# ledger delta is context and not an assertion. Neither evidence kind may be
	# failed for an unchanged or lower total.
	_check(bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"enabled_ledger": 100.0, "disabled_ledger": 140.0})).get("ok", false)), "a tagged payout that substitutes for baseline damage is still green")
	_check(bool(Pack.evaluate_pair(resolver, _measurement(resolver, {"enabled_ledger": 100.0, "disabled_ledger": 100.0})).get("ok", false)), "a resolver-only payout is not required to raise applied damage")

	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"enabled_sources": []})).get("ok", false)), "a missing expected damage bucket must fail")
	_check(not bool(Pack.evaluate_pair(tagged, _measurement(tagged, {"per_seed": [1, 9, 2]})).get("ok", false)), "an unconverged pair must fail even with events present")


func _verify_committed_fragment() -> void:
	if not FileAccess.file_exists(Pack.FRAGMENT_PATH):
		_check(false, "the committed conditional fragment %s must exist" % Pack.FRAGMENT_PATH)
		return
	var text := FileAccess.get_file_as_string(Pack.FRAGMENT_PATH)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		_check(false, "the committed conditional fragment must parse as JSON")
		return
	var fragment: Dictionary = parsed
	var result := Pack.evaluate_fragment(fragment)
	for error_value in result.get("errors", []):
		_check(false, "committed fragment: %s" % error_value)
	_check(str(fragment.get("verdict", "")) == "green", "the committed fragment must record a green verdict")
	_check((result.get("pairs", []) as Array).size() == Pack.FAMILY_MATRIX.size(), "the committed fragment must cover every matrix pair")


func _matrix_entry_for_family(family: String) -> Dictionary:
	for entry_value in Pack.FAMILY_MATRIX:
		var entry: Dictionary = entry_value
		if str(entry.get("family", "")) == family:
			return entry.duplicate(true)
	_check(false, "no matrix entry for family %s" % family)
	return {}


func _matrix_entry_for_evidence(kind: String) -> Dictionary:
	for entry_value in Pack.FAMILY_MATRIX:
		var entry: Dictionary = entry_value
		if str(entry.get("damage_evidence", "")) == kind:
			return entry.duplicate(true)
	_check(false, "no matrix entry with %s damage evidence" % kind)
	return {}


# A green-by-default synthetic measurement for `entry`, with individual fields
# overridden so each assertion above changes exactly one thing.
func _measurement(entry: Dictionary, overrides: Dictionary) -> Dictionary:
	var seed_count := int(overrides.get("seed_count", Pack.MIN_SEEDS))
	var per_seed: Array = overrides.get("per_seed", [])
	if per_seed.is_empty():
		for _index in range(seed_count):
			per_seed.append(int(entry.get("min_triggers", 1)) * 4)
	var enabled_triggers := 0
	for value in per_seed:
		enabled_triggers += int(value)
	return {
		"enabled": {
			"trigger_resolutions": int(overrides.get("enabled_triggers", enabled_triggers)),
			"final_event_count": int(overrides.get("enabled_final_events", 4)),
			"final_event_damage": float(overrides.get("enabled_final_damage", 250.0)),
			"ledger_damage": float(overrides.get("enabled_ledger", 4200.0)),
			"kills": 0,
			"damage_sources": overrides.get("enabled_sources", (entry.get("expected_sources", []) as Array).duplicate()),
		},
		"disabled": {
			"trigger_resolutions": int(overrides.get("disabled_triggers", 0)),
			"final_event_count": int(overrides.get("disabled_final_events", 0)),
			"final_event_damage": float(overrides.get("disabled_final_damage", 0.0)),
			"ledger_damage": float(overrides.get("disabled_ledger", 3900.0)),
			"kills": 0,
			"damage_sources": (entry.get("expected_sources", []) as Array).duplicate(),
		},
		"per_seed_triggers": per_seed,
		"seed_count": per_seed.size(),
		"window_seconds": float(overrides.get("window_seconds", Pack.MIN_WINDOW_SECONDS)),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-1513 A5 conditional final family matrix, convergence rule and A/B oracle passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
