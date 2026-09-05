extends SceneTree

## FAN-2516: the live effectiveness runner for the 51 weapon ultimates.
##
## Run:
## Godot --headless --path . \
##   --script res://tests/ultimates/effectiveness_runner_test.gd
##
## Three separate statements, because passing one does not imply the others:
##
## 1. The committed baseline really covers all 51 executors, keyed by class and
##    weapon, with no legacy-substituted row.
## 2. The instrument is deterministic — a live re-measure of a bounded slice
##    reproduces the committed numbers inside RERUN_TOLERANCE. The slice is the
##    three classes that between them exercise every measured channel: repair
##    (doctor), guard prevention and host modifiers (knight), summons (druid).
## 3. The validator and the regression gate can go RED. A gate that cannot fail
##    would be inherited green by every consumer of these numbers.

const PD := preload("res://scripts/progression_data.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const BaselineStore := preload("res://tools/ultimate_effectiveness_report.gd")

const BASELINE_PATH := "res://build/ultimate_effectiveness_baseline.json"
const DETERMINISM_CLASSES := ["doctor", "knight", "druid"]

var _errors: Array[String] = []


func _initialize() -> void:
	var baseline := _baseline_document().get("rows", []) as Array
	_check_baseline(baseline)
	await _check_determinism(baseline)
	_check_validator_can_fail(baseline)
	_check_regression_gate(baseline)
	_report(baseline)


## The committed artifact is the deliverable, so it is verified as one — not
## re-derived here, which would only prove the runner agrees with itself.
func _check_baseline(baseline: Array) -> void:
	_expect(
		baseline.size() == Budget.EXPECTED_ROW_COUNT,
		"baseline must carry %d rows, got %d" % [Budget.EXPECTED_ROW_COUNT, baseline.size()]
	)
	var violations := Runner.violations(baseline)
	_expect(violations.is_empty(), "baseline must be clean: %s" % str(violations.slice(0, 8)))

	var keys := {}
	for raw_row in baseline:
		var row := raw_row as Dictionary
		keys[str(row.get("key", ""))] = true
		_expect(
			str(row.get("resolution_source", "")) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must resolve to its own weapon profile" % str(row.get("key", "?"))
		)
	_expect(keys.size() == Budget.EXPECTED_ROW_COUNT, "baseline keys must be unique")

	# Every canonical pair from the frozen inventory has to be present by name,
	# so a renamed or dropped weapon cannot hide behind a correct row count.
	for raw_row in Budget.build_rows(PD.WEAPONS_BY_CLASS, PD):
		var key := str((raw_row as Dictionary).get("key", ""))
		_expect(keys.has(key), "baseline misses canonical pair %s" % key)


## Re-measures a bounded live slice and compares it against the committed rows.
func _check_determinism(baseline: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "registry must load the catalog: %s" % str(registry.validation_errors()))
	_expect(
		registry.package_validation_errors().is_empty(),
		"packages must admit cleanly: %s" % str(registry.package_validation_errors())
	)

	var slice: Array = []
	for raw_row in Budget.build_rows(PD.WEAPONS_BY_CLASS, PD):
		if DETERMINISM_CLASSES.has(str((raw_row as Dictionary).get("class_id", ""))):
			slice.append(raw_row)
	_expect(
		slice.size() == DETERMINISM_CLASSES.size() * 3,
		"determinism slice must be %d rows, got %d" % [DETERMINISM_CLASSES.size() * 3, slice.size()]
	)

	var measured: Array = await Runner.new().measure(holder, registry, slice, PD)
	holder.queue_free()
	await process_frame

	var baseline_by_key := {}
	for raw_row in baseline:
		baseline_by_key[str((raw_row as Dictionary).get("key", ""))] = raw_row as Dictionary

	var channels := {"healing_applied": false, "prevention_applied": false, "summon_count": false}
	for raw_row in measured:
		var row := raw_row as Dictionary
		var key := str(row.get("key", ""))
		if not baseline_by_key.has(key):
			_expect(false, "live slice produced an unknown row %s" % key)
			continue
		var stored := baseline_by_key[key] as Dictionary
		for scenario_id in Runner.SCENARIOS.map(func(entry: Dictionary) -> String: return str(entry["id"])):
			var live := (row["scenarios"] as Dictionary)[scenario_id] as Dictionary
			var kept := (stored["scenarios"] as Dictionary).get(scenario_id) as Dictionary
			for metric in Runner.METRIC_KEYS:
				var now := float(live.get(metric, 0.0))
				var was := float(kept.get(metric, 0.0))
				if channels.has(metric) and now > 0.0:
					channels[metric] = true
				_expect(
					absf(now - was) <= maxf(absf(was), 1.0) * Runner.RERUN_TOLERANCE,
					"%s/%s %s drifted %.6f -> %.6f" % [key, scenario_id, metric, was, now]
				)
	for metric in channels.keys():
		_expect(bool(channels[metric]), "the determinism slice must exercise %s" % str(metric))


## Each tampering is a distinct failure mode the report has to reject.
func _check_validator_can_fail(baseline: Array) -> void:
	_expect(
		not Runner.violations(baseline.slice(0, baseline.size() - 1)).is_empty(),
		"a short report must be rejected"
	)

	var missing_id := _tamper(baseline, 0, func(row: Dictionary) -> void:
		row["weapon_id"] = ""
	)
	_expect(not Runner.violations(missing_id).is_empty(), "a row without a weapon id must be rejected")

	var legacy := _tamper(baseline, 1, func(row: Dictionary) -> void:
		row["resolution_source"] = Resolver.SOURCE_LEGACY_CLASS_FALLBACK
	)
	_expect(not Runner.violations(legacy).is_empty(), "a legacy-substituted row must be rejected")

	var no_executor := _tamper(baseline, 2, func(row: Dictionary) -> void:
		row["executor_present"] = false
	)
	_expect(not Runner.violations(no_executor).is_empty(), "a row without a live executor must be rejected")

	var negative := _tamper(baseline, 3, func(row: Dictionary) -> void:
		((row["scenarios"] as Dictionary)["solo"] as Dictionary)["damage_applied"] = -1.0
	)
	_expect(not Runner.violations(negative).is_empty(), "a negative metric must be rejected")

	var non_finite := _tamper(baseline, 4, func(row: Dictionary) -> void:
		((row["scenarios"] as Dictionary)["solo"] as Dictionary)["control_seconds"] = INF
	)
	_expect(not Runner.violations(non_finite).is_empty(), "a non-finite metric must be rejected")

	var dead := _tamper(baseline, 5, func(row: Dictionary) -> void:
		var solo := (row["scenarios"] as Dictionary)["solo"] as Dictionary
		solo["effect_total"] = 0.0
	)
	_expect(not Runner.violations(dead).is_empty(), "a row that measured nothing must be rejected")

	var dropped_scenario := _tamper(baseline, 6, func(row: Dictionary) -> void:
		(row["scenarios"] as Dictionary).erase("boss")
	)
	_expect(not Runner.violations(dropped_scenario).is_empty(), "a missing scenario must be rejected")

	var over_cap := _tamper(baseline, 7, func(row: Dictionary) -> void:
		((row["scenarios"] as Dictionary)["boss"] as Dictionary)["boss_cap_ratio"] = 1.5
	)
	_expect(not Runner.violations(over_cap).is_empty(), "a boss cap over its whole budget must be rejected")

	var duplicated := baseline.duplicate(true)
	duplicated[1] = (duplicated[0] as Dictionary).duplicate(true)
	_expect(not Runner.violations(duplicated).is_empty(), "a duplicated key must be rejected")


## A later report is judged against the stored baseline, and only an explained
## drop is allowed through.
func _check_regression_gate(baseline: Array) -> void:
	_expect(
		Runner.regressions(baseline, baseline).is_empty(),
		"a report identical to its baseline must not regress"
	)

	var halved := _tamper(baseline, 0, func(row: Dictionary) -> void:
		var solo := (row["scenarios"] as Dictionary)["solo"] as Dictionary
		solo["damage_applied"] = float(solo["damage_applied"]) * 0.5
	)
	_expect(
		not Runner.regressions(baseline, halved).is_empty(),
		"an unexplained halved row must be reported as a regression"
	)

	var explained := _tamper(halved, 0, func(row: Dictionary) -> void:
		row["regression_reason"] = "FAN-2516 test: deliberate corridor move"
	)
	_expect(
		Runner.regressions(baseline, explained).is_empty(),
		"an explained regression must pass the gate"
	)

	# Inside the tolerance a small drop is noise, not a regression.
	var noise := _tamper(baseline, 0, func(row: Dictionary) -> void:
		var solo := (row["scenarios"] as Dictionary)["solo"] as Dictionary
		solo["damage_applied"] = float(solo["damage_applied"]) * (1.0 - Runner.REGRESSION_TOLERANCE * 0.5)
	)
	_expect(
		Runner.regressions(baseline, noise).is_empty(),
		"a drop inside the tolerance must not be reported"
	)

	_expect(
		not Runner.regressions(baseline, baseline.slice(1)).is_empty(),
		"a report that lost a row must be reported"
	)


func _tamper(report: Array, index: int, mutate: Callable) -> Array:
	var copy := report.duplicate(true)
	mutate.call(copy[index] as Dictionary)
	return copy


func _baseline_document() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		_expect(false, "missing committed baseline %s" % BASELINE_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	if not parsed is Dictionary:
		_expect(false, "baseline %s is not a JSON object" % BASELINE_PATH)
		return {}
	var legacy_document := parsed as Dictionary
	var loaded := BaselineStore.read_baseline_document()
	for raw_error in loaded.get("errors", []) as Array:
		_expect(false, str(raw_error))
	var document = loaded.get("document")
	if not document is Dictionary:
		_expect(false, "sharded baseline reader did not return a document")
		return {}
	_expect(
		document == legacy_document,
		"sharded baseline must reassemble exactly to the compatibility export"
	)
	_expect(
		int((document as Dictionary).get("schema_version", -1)) == Runner.SCHEMA_VERSION,
		"baseline schema_version must be %d" % Runner.SCHEMA_VERSION
	)
	return document as Dictionary


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(baseline: Array) -> void:
	if not _errors.is_empty():
		for error in _errors:
			push_error("effectiveness_runner_test: %s" % error)
		quit(1)
		return
	print(
		"effectiveness_runner_test passed (%d baseline rows, %d scenarios, live slice %s)."
		% [baseline.size(), Runner.SCENARIOS.size(), str(DETERMINISM_CLASSES)]
	)
	quit(0)
