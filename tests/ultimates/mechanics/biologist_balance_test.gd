extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "biologist"
const WEAPONS := ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]
const CROWD_COUNTS := [1, 5, 10, 20]
const COUNT_SHAPED_PATTERN := "[A-Za-z0-9_]*(pierce_limit|max_locks_per_target|crowd_cap|target_limit|max_targets|target_count|analysis_target_cap|bloom_cap|bloom_targets)[A-Za-z0-9_]*"

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var harness_report := Harness.measure(rows)
	_check(registry.package_validation_errors().is_empty(), "Biologist packages must remain valid")
	_check(Harness.violations(harness_report).is_empty(), "the inherited balance harness must remain clean")
	var metrics := {}
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		metrics[weapon_id] = _measure(weapon_id, profile)
		_test_weapon(weapon_id, row, profile, metrics[weapon_id])
	_test_no_count_caps()
	_test_charge_economy(harness_report)
	_test_trio(metrics)
	_report(metrics)


func _measure(weapon_id: String, profile: Dictionary) -> Dictionary:
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base := float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])
	var floor_damage := 0.0
	var solo_damage := 0.0
	match weapon_id:
		"biologist_spore_lens":
			floor_damage = base * float(params.get("propagation_waves", 0)) * float(params.get("infection_damage", 0.0))
			solo_damage = floor_damage
		"biologist_sample_injector":
			var primary_coeff := float(params.get("extraction_damage", 0.0)) \
				+ float(params.get("analysis_pulses", 0)) * float(params.get("analysis_damage", 0.0))
			solo_damage = base * primary_coeff * float(params.get("swarm_bonus", 1.0))
			floor_damage = base * float(params.get("analysis_pulses", 0)) \
				* float(params.get("analysis_damage", 0.0)) * float(params.get("tissue_damage_ratio", 0.0))
		"biologist_symbiote_seed":
			var shared_coeff := float(params.get("impact_damage", 0.0)) + float(params.get("hatch_damage", 0.0))
			solo_damage = base * (shared_coeff + float(params.get("larva_count", 0)) * float(params.get("larva_damage", 0.0)))
			floor_damage = base * shared_coeff
	return {"floor_damage": floor_damage, "solo_damage": solo_damage}


func _test_weapon(weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary) -> void:
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must preserve its whole-cast boss cap" % weapon_id)
	_check(float(metrics["solo_damage"]) >= float(row["power_budget_min"])
		and float(metrics["solo_damage"]) <= float(row["power_budget_max"]),
		"%s solo output must stay inside its power corridor" % weapon_id)
	var pool := Budget.live_standard_pool(float(row["reference_solo_dps"]))
	for count in CROWD_COUNTS:
		var required := Budget.PER_ENEMY_FLOOR_FRACTION * pool / float(count)
		# At crowd 1 the lone enemy is the injector's own primary, so its
		# guaranteed delivery is the full extraction, not the tissue echo.
		var guaranteed := float(metrics["solo_damage"]) \
			if weapon_id == "biologist_sample_injector" and count == 1 \
			else float(metrics["floor_damage"])
		_check(guaranteed >= required,
			"%s must keep a non-trivial floor for every enemy at crowd %d" % [weapon_id, count])
	match weapon_id:
		"biologist_spore_lens":
			_check(int(((profile["executor"] as Dictionary)["params"] as Dictionary).get("propagation_waves", 0)) == 3,
				"Spore Lens must retain its three-wave identity without a reach cap")
		"biologist_sample_injector":
			_check(int(((profile["executor"] as Dictionary)["params"] as Dictionary).get("analysis_pulses", 0)) == 3,
				"Sample Injector must retain its three-pulse identity without a reach cap")
		"biologist_symbiote_seed":
			_check(int(((profile["executor"] as Dictionary)["params"] as Dictionary).get("larva_count", 0)) == 6,
				"Symbiote Seed must retain its six-larva identity without a reach cap")


func _test_no_count_caps() -> void:
	var sources := ""
	for weapon_id in WEAPONS:
		sources += FileAccess.get_file_as_string("res://scripts/ultimates/classes/biologist/%s.gd" % weapon_id)
	var pattern := RegEx.create_from_string(COUNT_SHAPED_PATTERN)
	_check(pattern.search_all(sources).is_empty(), "Biologist executors must declare no count-shaped reach caps")
	_check(not Harness.COVERAGE_MIGRATION_ALLOWLIST.has(CLASS_ID), "Biologist must leave the coverage migration allowlist")
	_check(Harness.COVERAGE_V2_CLASSES.has(CLASS_ID), "Biologist must be recorded as coverage v2")


func _test_charge_economy(report: Array) -> void:
	for raw_row in report:
		var row := raw_row as Dictionary
		if str(row.get("class_id", "")) != CLASS_ID:
			continue
		var neutral := (row["scenarios"] as Dictionary)[Harness.NEUTRAL_SCENARIO_ID] as Dictionary
		_check(
			int(neutral["encounters_to_ready"]) >= 3 and int(neutral["encounters_to_ready"]) <= 4,
			"%s must be ready after three to four normal encounters" % str(row["key"])
		)
		_check(
			float(neutral["normal_charge"]) <= Budget.NORMAL_ENCOUNTER_CAP + 0.001,
			"%s must preserve the normal encounter charge cap" % str(row["key"])
		)
		_check(
			int(neutral["activations_per_encounter"]) == 1,
			"%s must allow one activation per encounter" % str(row["key"])
		)


func _test_trio(metrics: Dictionary) -> void:
	_check(float((metrics["biologist_spore_lens"] as Dictionary)["solo_damage"])
		> float((metrics["biologist_sample_injector"] as Dictionary)["solo_damage"]),
		"Spore Lens must remain the raw-damage member of the trio")
	_check(float((metrics["biologist_symbiote_seed"] as Dictionary)["floor_damage"])
		> float((metrics["biologist_sample_injector"] as Dictionary)["floor_damage"]),
		"Symbiote Seed must keep the stronger guaranteed per-enemy floor")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var metric := metrics[weapon_id] as Dictionary
		print("  %s solo=%.2f floor=%.2f" % [weapon_id, metric["solo_damage"], metric["floor_damage"]])
	if _errors.is_empty():
		print("biologist_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("biologist_balance_test: %s" % error)
	print("biologist_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
