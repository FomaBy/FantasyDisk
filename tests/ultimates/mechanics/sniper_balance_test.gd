extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "sniper"
const WEAPONS := ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"]
const CROWD_COUNTS := [1, 5, 10, 20]
const COUNT_SHAPED_PATTERN := "[A-Za-z0-9_]*(pierce_limit|max_locks_per_target|crowd_cap|target_limit|max_targets|target_count)[A-Za-z0-9_]*"

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var harness_report := Harness.measure(rows)
	_check(registry.package_validation_errors().is_empty(), "Sniper packages must remain valid")
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
		"sniper_deadeye_rifle":
			floor_damage = base * float(params.get("shot_damage", 0.0))
			solo_damage = floor_damage * float(params.get("headshot_multiplier", 1.0))
		"sniper_spotter_scope":
			floor_damage = base * float(params.get("pulse_count", 0)) * float(params.get("strike_damage", 0.0))
			solo_damage = floor_damage
		"sniper_shatter_rounds":
			floor_damage = base * float(params.get("wave_count", 0)) * float(params.get("impact_damage", 0.0))
			solo_damage = floor_damage
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
		_check(float(metrics["floor_damage"]) >= required,
			"%s must keep a non-trivial floor for every enemy at crowd %d" % [weapon_id, count])
	match weapon_id:
		"sniper_deadeye_rifle":
			_check(float(metrics["solo_damage"]) > float(metrics["floor_damage"]),
				"Deadeye must keep its priority headshot above the arena-wide floor")
		"sniper_spotter_scope":
			_check(int(((profile["executor"] as Dictionary)["params"] as Dictionary).get("pulse_count", 0)) == 9,
				"Spotter must retain its nine-pulse identity without a target cap")
		"sniper_shatter_rounds":
			_check(int(((profile["executor"] as Dictionary)["params"] as Dictionary).get("wave_count", 0)) == 5,
				"Shatter must retain its five-wave identity without a crowd cap")


func _test_no_count_caps() -> void:
	var sources := ""
	for weapon_id in WEAPONS:
		sources += FileAccess.get_file_as_string("res://scripts/ultimates/classes/sniper/%s.gd" % weapon_id)
	var pattern := RegEx.create_from_string(COUNT_SHAPED_PATTERN)
	_check(pattern.search_all(sources).is_empty(), "Sniper executors must declare no count-shaped reach caps")
	_check(not Harness.COVERAGE_MIGRATION_ALLOWLIST.has(CLASS_ID), "Sniper must leave the coverage migration allowlist")
	_check(Harness.COVERAGE_V2_CLASSES.has(CLASS_ID), "Sniper must be recorded as coverage v2")


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
	_check(float((metrics["sniper_deadeye_rifle"] as Dictionary)["solo_damage"])
		> float((metrics["sniper_spotter_scope"] as Dictionary)["solo_damage"]),
		"Deadeye must remain the focused-priority member of the trio")
	_check(float((metrics["sniper_shatter_rounds"] as Dictionary)["floor_damage"])
		> float((metrics["sniper_spotter_scope"] as Dictionary)["floor_damage"]),
		"Shatter must remain the stronger arena-wide pressure wave")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var metric := metrics[weapon_id] as Dictionary
		print("  %s solo=%.2f floor=%.2f" % [weapon_id, metric["solo_damage"], metric["floor_damage"]])
	if _errors.is_empty():
		print("sniper_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_balance_test: %s" % error)
	print("sniper_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
