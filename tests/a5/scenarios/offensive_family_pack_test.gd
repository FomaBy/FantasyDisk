extends SceneTree

const Pack := preload("res://tools/a5/scenarios/offensive/offensive_family_pack.gd")

var _errors := PackedStringArray()


func _initialize() -> void:
	_verify_contract_and_matrix()
	_verify_ab_oracle()
	_verify_committed_fragment()
	_finish()


func _verify_contract_and_matrix() -> void:
	var contract := Pack.contract()
	_check(str(contract.get("pack_contract", "")) == "a5.scenario-pack.v1", "pack contract must be versioned")
	_check(str(contract.get("matrix_schema", "")) == "fan1512.pair-family-event.v1", "matrix schema must be versioned")
	_check(float(contract.get("formula_live_tolerance_pct", 0.0)) == 35.0, "formula/live tolerance must stay at 35%")
	var matrix := Pack.family_matrix()
	var check := Pack.verify_matrix(matrix)
	for error_value in check.get("errors", []):
		_check(false, "matrix: %s" % error_value)
	_check(int(check.get("runtime_pair_count", 0)) == 51, "the matrix must cover all 51 runtime pairs")
	var representatives := Pack.representative_matrix(matrix)
	_check(representatives.size() == Pack.FAMILIES.size(), "each offensive family needs exactly one A/B representative")
	var coverage := {}
	for entry_value in representatives:
		var entry: Dictionary = entry_value
		var geometry: Dictionary = entry.get("geometry", {})
		coverage[str(geometry.get("name", ""))] = true
		coverage[str(geometry.get("orientation", ""))] = true
		coverage[str(geometry.get("layout", ""))] = true
	_check(coverage.has("minimum_80px"), "A/B plan must include the 80px minimum")
	_check(coverage.has("formula_expected_distance"), "A/B plan must include formula-expected distance")
	_check(coverage.has("practical_range"), "A/B plan must include practical range")
	_check(coverage.has("forward") and coverage.has("diagonal") and coverage.has("reverse"), "A/B plan must preserve all orientations")
	_check(coverage.has("solo") and coverage.has("pack"), "A/B plan must preserve solo and pack layouts")


func _verify_ab_oracle() -> void:
	var entry: Dictionary = Pack.representative_matrix()[0]
	_check(bool(Pack.evaluate_pair(entry, _measurement()).get("ok", false)), "well-formed same-seed A/B evidence must pass")
	var silent := _measurement()
	(silent["enabled"] as Dictionary)["trigger_resolutions"] = 0
	_check(not bool(Pack.evaluate_pair(entry, silent).get("ok", true)), "an enabled arm without the expected event must fail")
	var leaked := _measurement()
	(leaked["disabled"] as Dictionary)["trigger_resolutions"] = 1
	_check(not bool(Pack.evaluate_pair(entry, leaked).get("ok", true)), "a disabled arm that resolves the final must fail")
	var high_delta := _measurement()
	high_delta["formula_expected_dpm"] = 1.0
	var result := Pack.evaluate_pair(entry, high_delta)
	_check(bool(result.get("ok", false)), "formula/live red must not hide a valid A/B observation")
	_check(str(result.get("formula_live_verdict", "")) == "red", "over-35% formula/live delta must stay red")


func _verify_committed_fragment() -> void:
	_check(FileAccess.file_exists(Pack.FRAGMENT_PATH), "the committed offensive fragment must exist")
	if not FileAccess.file_exists(Pack.FRAGMENT_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(Pack.FRAGMENT_PATH))
	_check(parsed is Dictionary, "the committed offensive fragment must parse")
	if not parsed is Dictionary:
		return
	var fragment: Dictionary = parsed
	var result := Pack.evaluate_fragment(fragment)
	for error_value in result.get("errors", []):
		_check(false, "fragment: %s" % error_value)
	_check(str(fragment.get("ab_verdict", "")) == "green", "all family A/B arms must be green")
	_check((result.get("pairs", []) as Array).size() == Pack.FAMILIES.size(), "fragment must contain five family measurements")
	for pair_value in result.get("pairs", []):
		var pair: Dictionary = pair_value
		var measurement: Dictionary = (fragment.get("measurements", {}) as Dictionary).get(str(pair.get("pair", "")), {})
		var enabled: Dictionary = measurement.get("enabled", {})
		var disabled: Dictionary = measurement.get("disabled", {})
		_check(int(enabled.get("casts", 0)) > 0 and int(disabled.get("casts", 0)) > 0, "%s must retain casts in both arms" % pair.get("pair", "?"))
		_check(int(enabled.get("hits", 0)) > 0 and int(disabled.get("hits", 0)) > 0, "%s must retain hits in both arms" % pair.get("pair", "?"))
		_check(int(enabled.get("unique_target_count", 0)) > 0 and int(disabled.get("unique_target_count", 0)) > 0, "%s must retain targets in both arms" % pair.get("pair", "?"))
		_check(float(enabled.get("ledger_damage", 0.0)) > 0.0 and float(disabled.get("ledger_damage", 0.0)) > 0.0, "%s must retain source damage in both arms" % pair.get("pair", "?"))


func _measurement() -> Dictionary:
	return {
		"enabled": {"trigger_resolutions": 1, "final_event_count": 1, "final_event_damage": 10.0, "ledger_damage": 100.0, "casts": 1, "hits": 1, "unique_target_count": 1, "dpm": 1000.0},
		"disabled": {"trigger_resolutions": 0, "final_event_count": 0, "final_event_damage": 0.0, "ledger_damage": 90.0, "casts": 1, "hits": 1, "unique_target_count": 1, "dpm": 900.0},
		"formula_expected_dpm": 1000.0,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _finish() -> void:
	if _errors.is_empty():
		print("FAN-1512 offensive pair matrix and same-seed A/B oracle passed.")
		quit(0)
		return
	for error_value in _errors:
		push_error(error_value)
	quit(1)
