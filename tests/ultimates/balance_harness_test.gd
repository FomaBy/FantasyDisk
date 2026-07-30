extends SceneTree

## FAN-1460: the 51-row charge-economy and power harness.
##
## Run:
## Godot --headless --path . \
##   --script res://tests/ultimates/balance_harness_test.gd
##
## The last block is the point of the file: a harness that cannot go red on a
## tampered report would be inherited green by all 17 class mechanics packs, so
## every invariant is also exercised against a deliberately broken report.

const PD := preload("res://scripts/progression_data.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")


func _initialize() -> void:
	var errors: Array[String] = []
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)

	_expect(rows.size() == 51, "fixtures must contain 51 rows, got %d" % rows.size(), errors)
	_expect(report.size() == 51, "harness must report 51 rows, got %d" % report.size(), errors)

	var harness_errors := Harness.violations(report)
	_expect(
		harness_errors.is_empty(),
		"harness must be clean: %s" % str(harness_errors.slice(0, 8)),
		errors
	)

	_check_fixture_immutability(rows, errors)
	_check_neutral_corridor(report, errors)
	_check_build_and_atlas_scenarios(report, errors)
	_check_power_and_boss_caps(report, errors)
	_check_harness_can_fail(report, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Ultimate balance harness: %s" % error)
		quit(1)
		return
	print(
		"balance_harness_test passed (%d rows, %d scenarios)." % [report.size(), Harness.SCENARIOS.size()]
	)
	_print_measured_spread(report)
	quit(0)


## Measured evidence, so a reader does not have to re-run the harness to see
## where the 51 rows actually landed inside the corridor.
func _print_measured_spread(report: Array) -> void:
	var normal := Vector2(INF, -INF)
	var elite := Vector2(INF, -INF)
	var reference := Vector2(INF, -INF)
	var ready_min := 99
	var ready_max := 0
	for raw_row in report:
		var row := raw_row as Dictionary
		var neutral: Dictionary = (row["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID]
		normal = Vector2(minf(normal.x, float(neutral["normal_charge"])), maxf(normal.y, float(neutral["normal_charge"])))
		elite = Vector2(minf(elite.x, float(neutral["elite_charge"])), maxf(elite.y, float(neutral["elite_charge"])))
		reference = Vector2(minf(reference.x, float(row["reference_solo_dps"])), maxf(reference.y, float(row["reference_solo_dps"])))
		ready_min = mini(ready_min, int(neutral["encounters_to_ready"]))
		ready_max = maxi(ready_max, int(neutral["encounters_to_ready"]))
	print("  neutral normal charge %.2f..%.2f (corridor %.0f-%.0f, cap %.0f)" % [normal.x, normal.y, Budget.NORMAL_CORRIDOR_MIN, Budget.NORMAL_CORRIDOR_MAX, Budget.NORMAL_ENCOUNTER_CAP])
	print("  neutral elite charge  %.2f..%.2f (corridor %.0f-%.0f, cap %.0f)" % [elite.x, elite.y, Budget.ELITE_CORRIDOR_MIN, Budget.ELITE_CORRIDOR_MAX, Budget.ELITE_ENCOUNTER_CAP])
	print("  neutral readiness     %d..%d normal encounters" % [ready_min, ready_max])
	print("  reference solo output %.2f..%.2f dps normalized to one corridor" % [reference.x, reference.y])


## The class packs consume the fixtures; a pack must not be able to widen its own
## corridor by mutating what it was handed.
func _check_fixture_immutability(rows: Array, errors: Array[String]) -> void:
	var first := Budget.row_for(rows, "berserk", "sword")
	_expect(not first.is_empty(), "berserk/sword fixture must resolve", errors)
	first["total_boss_cap"] = 0.99
	first["charge_per_removed_hp"] = 99.0
	var again := Budget.row_for(rows, "berserk", "sword")
	_expect(
		not is_equal_approx(float(again.get("total_boss_cap", 0.0)), 0.99),
		"row_for must hand out copies, not the live fixture",
		errors
	)
	_expect(
		Budget.row_for(rows, "berserk", "not_a_weapon").is_empty(),
		"unknown pair must resolve to an empty fixture",
		errors
	)


func _check_neutral_corridor(report: Array, errors: Array[String]) -> void:
	for raw_row in report:
		var row := raw_row as Dictionary
		var key := str(row["key"])
		var neutral: Dictionary = (row["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID]
		var normal := float(neutral["normal_charge"])
		var elite := float(neutral["elite_charge"])
		_expect(
			normal >= Budget.NORMAL_CORRIDOR_MIN and normal <= Budget.NORMAL_CORRIDOR_MAX,
			"%s neutral normal charge %.2f outside corridor" % [key, normal],
			errors
		)
		_expect(
			elite >= Budget.ELITE_CORRIDOR_MIN and elite <= Budget.ELITE_CORRIDOR_MAX,
			"%s neutral elite charge %.2f outside corridor" % [key, elite],
			errors
		)
		var ready_after := int(neutral["encounters_to_ready"])
		_expect(
			ready_after >= 3 and ready_after <= 4,
			"%s neutral readiness after %d normal encounters" % [key, ready_after],
			errors
		)
		# The corridor is measured, not clamped: a neutral build must never be
		# pinned to the per-encounter cap, otherwise the cap is doing the tuning.
		_expect(
			normal < Budget.NORMAL_ENCOUNTER_CAP,
			"%s neutral normal charge is pinned to the encounter cap" % key,
			errors
		)


func _check_build_and_atlas_scenarios(report: Array, errors: Array[String]) -> void:
	_expect(
		is_equal_approx(Budget.build_multiplier(0.0, 1.0), 1.0),
		"a neutral build must be exactly 1.0 for every class",
		errors
	)
	_expect(
		is_equal_approx(Budget.build_multiplier(24.0, 1.35), Budget.BUILD_CHARGE_MULTIPLIER_CAP),
		"Energy stacked with ult_charge_multiplier must clamp to the build cap",
		errors
	)
	for raw_row in report:
		var row := raw_row as Dictionary
		var key := str(row["key"])
		var scenarios := row["scenarios"] as Dictionary
		var neutral: Dictionary = scenarios[Harness.NEUTRAL_SCENARIO_ID]
		var stacked: Dictionary = scenarios["high_energy_stacked"]
		var atlas_half: Dictionary = scenarios["atlas_half"]
		var atlas_full: Dictionary = scenarios["atlas_full"]
		var overkill: Dictionary = scenarios[Harness.OVERKILL_SCENARIO_ID]
		var tank: Dictionary = scenarios[Harness.TANK_SCENARIO_ID]

		_expect(
			float(stacked["normal_charge"]) <= Budget.NORMAL_ENCOUNTER_CAP + 0.001,
			"%s stacked build broke the per-encounter cap" % key,
			errors
		)
		_expect(
			int(stacked["recurring_encounters_to_ready"]) >= Budget.MIN_ENCOUNTERS_TO_READY,
			"%s stacked build made the ultimate a per-round ability" % key,
			errors
		)
		# The Atlas keystones pre-fill the bar once at run start (main.gd applies
		# meta modifiers only when run_player_snapshot is empty); the recurring
		# cadence behind them is the ordinary one.
		_expect(
			int(atlas_half["encounters_to_ready"]) < int(neutral["encounters_to_ready"]),
			"%s Atlas 0.5 must shorten the run opener" % key,
			errors
		)
		_expect(
			int(atlas_full["encounters_to_ready"]) == 0,
			"%s Atlas 1.0 must open the run ready" % key,
			errors
		)
		for scenario_id in ["atlas_half", "atlas_full"]:
			_expect(
				int((scenarios[scenario_id] as Dictionary)["recurring_encounters_to_ready"])
					>= Budget.MIN_ENCOUNTERS_TO_READY,
				"%s Atlas %s leaked into the recurring cadence" % [key, scenario_id],
				errors
			)
		_expect(
			is_equal_approx(float(overkill["normal_charge"]), float(neutral["normal_charge"])),
			"%s overkill inflated charge (%.2f vs %.2f)" % [key, float(overkill["normal_charge"]), float(neutral["normal_charge"])],
			errors
		)
		_expect(
			float(tank["normal_taken_charge"])
				<= Budget.taken_channel_cap(Budget.ENCOUNTER_NORMAL) + 0.001,
			"%s tanking farmed charge past the taken-channel cap" % key,
			errors
		)
		for scenario_id in Harness.scenario_ids():
			_expect(
				int((scenarios[scenario_id] as Dictionary)["activations_per_encounter"]) == 1,
				"%s/%s allowed more than one activation per encounter" % [key, scenario_id],
				errors
			)


func _check_power_and_boss_caps(report: Array, errors: Array[String]) -> void:
	var control_save_classes := {}
	var by_class := {}
	for raw_row in report:
		var row := raw_row as Dictionary
		var key := str(row["key"])
		var reference := float(row["reference_solo_dps"])
		_expect(
			is_equal_approx(float(row["power_budget_min"]), reference * 20.0)
				and is_equal_approx(float(row["power_budget_max"]), reference * 35.0),
			"%s power budget must be 20-35s of its own output" % key,
			errors
		)
		if str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_CONTROL_SAVE:
			control_save_classes[str(row["class_id"])] = true
			_expect(
				float(row["control_save_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"%s control save shorter than %.1fs" % [key, Budget.CONTROL_SAVE_MIN_SECONDS],
				errors
			)
		var boss_cap := float(row["total_boss_cap"])
		_expect(
			boss_cap > 0.0 and boss_cap <= Budget.BOSS_CAP_MAX,
			"%s whole-activation boss cap %.3f is out of contract" % [key, boss_cap],
			errors
		)
		if not by_class.has(str(row["class_id"])):
			by_class[str(row["class_id"])] = []
		(by_class[str(row["class_id"])] as Array).append(row)

	_expect(by_class.size() == 17, "harness must cover 17 classes, got %d" % by_class.size(), errors)
	_expect(
		not control_save_classes.is_empty(),
		"the defensive/control archetype must be represented",
		errors
	)
	# Class trio: the three weapons price their ultimates against their own solo
	# output, so the trio keeps its solo / AoE / defense identity.
	for class_id in by_class.keys():
		var trio := by_class[class_id] as Array
		_expect(trio.size() == 3, "%s must have 3 weapons, got %d" % [class_id, trio.size()], errors)
		for raw_row in trio:
			var row := raw_row as Dictionary
			_expect(
				float(row["reference_aoe_dps"]) > 0.0 and float(row["reference_ehp"]) > 0.0,
				"%s must publish AoE and defense budgets" % str(row["key"]),
				errors
			)


## Negative controls. Each tampered report must produce at least one violation
## naming the invariant that was broken.
func _check_harness_can_fail(report: Array, errors: Array[String]) -> void:
	_expect_violation(report, "harness.row_count", errors, func(copy: Array) -> void:
		copy.remove_at(0)
	)
	_expect_violation(report, "neutral.corridor", errors, func(copy: Array) -> void:
		var row := copy[0] as Dictionary
		var neutral := (row["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID] as Dictionary
		neutral["normal_charge"] = Budget.NORMAL_CORRIDOR_MIN - 1.0
	)
	_expect_violation(report, "scenario.encounter_cap", errors, func(copy: Array) -> void:
		var row := copy[1] as Dictionary
		var neutral := (row["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID] as Dictionary
		neutral["elite_charge"] = Budget.ELITE_ENCOUNTER_CAP + 5.0
	)
	_expect_violation(report, "scenario.recurring_cadence", errors, func(copy: Array) -> void:
		var row := copy[2] as Dictionary
		var stacked := (row["scenarios"] as Dictionary)["high_energy_stacked"] as Dictionary
		stacked["recurring_encounters_to_ready"] = 1
	)
	_expect_violation(report, "scenario.activation_gate", errors, func(copy: Array) -> void:
		var row := copy[3] as Dictionary
		var neutral := (row["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID] as Dictionary
		neutral["activations_per_encounter"] = 2
	)
	_expect_violation(report, "overkill.no_inflation", errors, func(copy: Array) -> void:
		var row := copy[4] as Dictionary
		var overkill := (row["scenarios"] as Dictionary)[Harness.OVERKILL_SCENARIO_ID] as Dictionary
		overkill["normal_charge"] = float(overkill["normal_charge"]) * 3.0
	)
	_expect_violation(report, "tank.taken_channel_cap", errors, func(copy: Array) -> void:
		var row := copy[5] as Dictionary
		var tank := (row["scenarios"] as Dictionary)[Harness.TANK_SCENARIO_ID] as Dictionary
		tank["normal_taken_charge"] = Budget.NORMAL_ENCOUNTER_CAP
	)
	_expect_violation(report, "row.total_boss_cap", errors, func(copy: Array) -> void:
		(copy[6] as Dictionary)["total_boss_cap"] = 0.9
	)
	_expect_violation(report, "class.trio_power_ratio", errors, func(copy: Array) -> void:
		(copy[7] as Dictionary)["power_budget_max"] = float((copy[7] as Dictionary)["power_budget_max"]) * 4.0
	)


func _expect_violation(
	report: Array, expected_code: String, errors: Array[String], tamper: Callable
) -> void:
	var copy := report.duplicate(true)
	tamper.call(copy)
	var found := Harness.violations(copy)
	var matched := false
	for violation in found:
		if str(violation).begins_with(expected_code):
			matched = true
			break
	_expect(
		matched,
		"harness stayed green on tampered '%s' (reported %s)" % [expected_code, str(found.slice(0, 4))],
		errors
	)


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
