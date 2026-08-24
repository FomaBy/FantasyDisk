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

const CLASS_EXECUTOR_ROOT := "res://scripts/ultimates/classes"


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
	_check_v2_coverage_corridor(report, errors)
	_check_coverage_ratchet(errors)
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
	print(
		"  v2 power corridor   live pool %.1f..%.1f HP -> one activation %.1f..%.1f HP (k %.1f-%.1f x live pool)"
		% [
			reference.x * Budget.NORMAL_ENCOUNTER_SECONDS,
			reference.y * Budget.NORMAL_ENCOUNTER_SECONDS,
			reference.x * Budget.POWER_SECONDS_MIN,
			reference.y * Budget.POWER_SECONDS_MAX,
			Budget.POWER_CORRIDOR_K_MIN,
			Budget.POWER_CORRIDOR_K_MAX,
		]
	)


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
			is_equal_approx(float(row["power_budget_min"]), reference * Budget.POWER_SECONDS_MIN)
				and is_equal_approx(float(row["power_budget_max"]), reference * Budget.POWER_SECONDS_MAX),
			"%s power budget must be %.1f-%.1fs of its own output" % [key, Budget.POWER_SECONDS_MIN, Budget.POWER_SECONDS_MAX],
			errors
		)
		_expect(
			str(row.get("coverage", "")) == Budget.COVERAGE_ALL_ENEMIES,
			"%s must declare coverage=%s" % [key, Budget.COVERAGE_ALL_ENEMIES],
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


## FAN-2949: the re-derived value corridor and the boss-cap exclusion.
func _check_v2_coverage_corridor(report: Array, errors: Array[String]) -> void:
	# The corridor is k x the live standard-monster pool, and the per-enemy
	# floor holds at any enemy count exactly because k_min is at or above the
	# floor fraction: pool = enemy_count x one standard monster's HP, so the
	# per-enemy share is k x one standard monster's HP for every count.
	_expect(
		Budget.POWER_CORRIDOR_K_MIN >= Budget.PER_ENEMY_FLOOR_FRACTION,
		"k_min %.2f must be >= the per-enemy floor fraction %.2f" % [
			Budget.POWER_CORRIDOR_K_MIN, Budget.PER_ENEMY_FLOOR_FRACTION
		],
		errors
	)
	_expect(
		is_equal_approx(Budget.POWER_SECONDS_MIN, Budget.POWER_CORRIDOR_K_MIN * Budget.NORMAL_ENCOUNTER_SECONDS)
			and is_equal_approx(Budget.POWER_SECONDS_MAX, Budget.POWER_CORRIDOR_K_MAX * Budget.NORMAL_ENCOUNTER_SECONDS),
		"POWER_SECONDS must stay k x the canonical encounter window",
		errors
	)
	var row := report[0] as Dictionary
	var reference := float(row["reference_solo_dps"])
	var pool := Budget.live_standard_pool(reference)
	var budget_min := float(row["power_budget_min"])
	# The floor is provably independent of the crowd size: spread the corridor
	# budget over any count, the per-enemy guarantee stays >= k_min standard
	# monsters' HP, which is >= the 0.5 floor.
	for enemy_count in [1, 5, 20, 100, 1000]:
		var guarantee := Budget.per_enemy_guarantee(budget_min, pool, enemy_count)
		_expect(
			is_equal_approx(guarantee, Budget.POWER_CORRIDOR_K_MIN * pool / float(enemy_count)),
			"per-enemy guarantee must be k x one standard monster at count %d" % enemy_count,
			errors
		)
		_expect(
			guarantee >= Budget.PER_ENEMY_FLOOR_FRACTION * pool / float(enemy_count) - 0.001,
			"per-enemy floor broken at count %d" % enemy_count,
			errors
		)
	# Boss-cap exclusion: the cap may refuse most of the activation budget
	# (boss pool far larger than the corridor, cap at its minimum) and that
	# refusal is NOT a corridor violation — the boss scenario asserts
	# total_boss_cap only.
	var capped := report.duplicate(true)
	for raw_row in capped:
		(raw_row as Dictionary)["total_boss_cap"] = Budget.BOSS_CAP_MIN
	var capped_errors := Harness.violations(capped)
	for violation in capped_errors:
		_expect(
			not str(violation).begins_with("row.power_budget")
				and not str(violation).begins_with("class.trio_power_ratio"),
			"boss-cap refusal surfaced as a corridor violation: %s" % str(violation),
			errors
		)
	_expect(
		Budget.boss_capped_budget(budget_min, pool * 10.0, Budget.BOSS_CAP_MIN) < budget_min,
		"the control must actually exercise a refusing boss cap",
		errors
	)


## FAN-2949: the coverage ratchet over the real class executor sources.
func _check_coverage_ratchet(errors: Array[String]) -> void:
	var sources := _class_executor_sources(errors)
	_expect(sources.size() == 17, "must discover 17 class packages, got %d" % sources.size(), errors)
	var ratchet_errors := Harness.coverage_violations(sources)
	_expect(
		ratchet_errors.is_empty(),
		"coverage ratchet must be clean for the allowlist plus the converted ledger: %s" % str(ratchet_errors.slice(0, 6)),
		errors
	)
	# The ratchet only ever shrinks: every converted class has left the allowlist
	# and every remaining entry is still awaiting its own conversion card.
	for class_id in Harness.COVERAGE_V2_CLASSES:
		_expect(
			not (Harness.COVERAGE_MIGRATION_ALLOWLIST as Dictionary).has(class_id),
			"converted class %s must have left the allowlist" % str(class_id),
			errors
		)
	# The named count caps and their siblings must be caught; per-target damage
	# shaping must not be.
	var scan := Harness.count_cap_params(
		'"target_cap" "impale_target_cap" "dive_target_cap" "counter_target_cap" '
		+ '"analysis_target_cap" "intercept_target_cap" "per_target_cap_fraction" '
		+ '"per_target_cap_flat" "target_cap_fraction" "target_cap_flat"'
	)
	_expect(
		str(scan) == str(["analysis_target_cap", "counter_target_cap", "dive_target_cap", "impale_target_cap", "intercept_target_cap", "target_cap"]),
		"count-cap scan must separate count caps from damage shaping, got %s" % str(scan),
		errors
	)

	# Fail closed: a class taken out of the allowlist before its conversion
	# lands is red (not converted), and a count-carrying one is red twice.
	var missing_conversion := (Harness.COVERAGE_MIGRATION_ALLOWLIST as Dictionary).duplicate()
	missing_conversion.erase("chemist")
	_expect_ratchet_violation(
		sources, missing_conversion, [], "coverage.conversion_missing", errors
	)
	var with_count_caps := (Harness.COVERAGE_MIGRATION_ALLOWLIST as Dictionary).duplicate()
	with_count_caps.erase("knight")
	_expect_ratchet_violation(sources, with_count_caps, [], "coverage.count_cap", errors)

	# Stale entry: a converted, clean class must not still be allowlisted.
	# `thief` is still awaiting its own card, so it stands in for the next class
	# whose conversion lands without its allowlist entry being retired.
	_expect_ratchet_violation(
		sources, Harness.COVERAGE_MIGRATION_ALLOWLIST.duplicate(), ["thief"],
		"coverage.allowlist_stale", errors
	)
	# The converted ledger is load-bearing, not decorative: dropping the already
	# converted `assassin` from it leaves the class outside the allowlist with no
	# declaration, which fails closed.
	_expect_ratchet_violation(
		sources, Harness.COVERAGE_MIGRATION_ALLOWLIST.duplicate(), [],
		"coverage.conversion_missing", errors
	)
	# Reason required.
	var no_reason := (Harness.COVERAGE_MIGRATION_ALLOWLIST as Dictionary).duplicate()
	no_reason["chemist"] = "   "
	_expect_ratchet_violation(
		sources, no_reason, [], "coverage.allowlist_reason_missing", errors
	)
	# An entry naming no class package fails.
	var unknown := (Harness.COVERAGE_MIGRATION_ALLOWLIST as Dictionary).duplicate()
	unknown["__no_such_class__"] = "reason"
	_expect_ratchet_violation(
		sources, unknown, [], "coverage.allowlist_unknown", errors
	)


func _class_executor_sources(errors: Array[String]) -> Dictionary:
	var sources := {}
	var root := DirAccess.open(CLASS_EXECUTOR_ROOT)
	if root == null:
		errors.append("cannot open %s" % CLASS_EXECUTOR_ROOT)
		return sources
	root.list_dir_begin()
	var class_dir_name := root.get_next()
	while not class_dir_name.is_empty():
		if root.current_is_dir() and not class_dir_name.begins_with("."):
			var source := ""
			var package := DirAccess.open(CLASS_EXECUTOR_ROOT.path_join(class_dir_name))
			package.list_dir_begin()
			var file_name := package.get_next()
			while not file_name.is_empty():
				if file_name.ends_with(".gd"):
					var path := CLASS_EXECUTOR_ROOT.path_join(class_dir_name).path_join(file_name)
					source += "\n" + FileAccess.get_file_as_string(path)
				file_name = package.get_next()
			package.list_dir_end()
			sources[class_dir_name] = source
		class_dir_name = root.get_next()
	root.list_dir_end()
	return sources


func _expect_ratchet_violation(
	sources: Dictionary,
	allowlist: Dictionary,
	converted: Array[String],
	expected_code: String,
	errors: Array[String]
) -> void:
	var found := Harness.coverage_violations(sources, allowlist, converted)
	var matched := false
	for violation in found:
		if str(violation).begins_with(expected_code):
			matched = true
			break
	_expect(
		matched,
		"coverage ratchet stayed green on tampered '%s' (reported %s)" % [expected_code, str(found.slice(0, 4))],
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
	_expect_violation(report, "row.coverage", errors, func(copy: Array) -> void:
		(copy[8] as Dictionary)["coverage"] = "nearest_8"
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
