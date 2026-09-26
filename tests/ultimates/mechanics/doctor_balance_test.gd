extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "doctor"
const WEAPONS := ["restore_potion", "plague_syringe", "bone_saw"]
const CROWD_COUNTS := [1, 5, 10, 20, 100, 1000]
const EXECUTOR_DIR := "res://scripts/ultimates/classes/doctor"

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(), "the inherited 51-row harness must stay clean")
	_check(Harness.COVERAGE_V2_CLASSES.has(CLASS_ID),
		"Doctor must be recorded in the coverage v2 ledger")
	_check(not Harness.COVERAGE_MIGRATION_ALLOWLIST.has(CLASS_ID),
		"Doctor must leave the coverage migration allowlist")
	_check(registry.package_validation_errors().is_empty(),
		"Doctor package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var metrics := {}
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		_check(Harness.count_cap_params(FileAccess.get_file_as_string("%s/%s.gd" % [EXECUTOR_DIR, weapon_id])).is_empty(),
			"%s must declare no count-shaped reach parameter" % weapon_id)
		metrics[weapon_id] = _measure(weapon_id, profile)
		_check(float((metrics[weapon_id] as Dictionary)["power_seconds"]) >= Budget.POWER_SECONDS_MIN,
			"%s must clear the one-activation power floor" % weapon_id)
		_check(float((metrics[weapon_id] as Dictionary)["power_seconds"]) <= Budget.POWER_SECONDS_MAX,
			"%s must remain below the one-activation power ceiling" % weapon_id)
		_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
			"%s must retain its whole-activation boss cap" % weapon_id)
		_check_charge(row, weapon_id)
	_test_plague_syringe_v2(
		registry.catalog_profile_for(CLASS_ID, "plague_syringe"),
		Budget.row_for(rows, CLASS_ID, "plague_syringe"),
		metrics["plague_syringe"] as Dictionary
	)
	var restore_profile := registry.catalog_profile_for(CLASS_ID, "restore_potion")
	var restore_params := (restore_profile["executor"] as Dictionary)["params"] as Dictionary
	_check(not restore_params.has("target_cap"),
		"Life and Death must not retain a count-shaped target cap")
	_check_trio(metrics)
	_report(metrics)


func _measure(weapon_id: String, profile: Dictionary) -> Dictionary:
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, weapon_id))
	var base_damage := float(derived["magic_damage"] if weapon_id != "bone_saw" else derived["damage"])
	var reference := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, weapon_id)
	var coefficient := 0.0
	var aoe := 0.0
	var crowd := 0.0
	var defense := 0.0
	match weapon_id:
		"restore_potion":
			coefficient = float(params["outer_damage"]) * float(params["pulse_count"])
			aoe = coefficient * 5.0
			crowd = INF
			defense = float(params["repair_total"]) + float(params["shield_cap"])
		"plague_syringe":
			coefficient = float(params["direct_damage"]) + float(params["wave_damage"]) * float(params["wave_count"])
			aoe = coefficient * 5.0
			crowd = 0.0
			defense = float(params["repair_total"])
		"bone_saw":
			coefficient = float(params["tick_damage"]) * float(params["tick_count"])
			aoe = coefficient * 5.0
			crowd = INF
			defense = float(params["repair_total"]) + float(params["shield_cap"])
	var output := coefficient * base_damage
	return {
		"power_seconds": output / float(reference["reference_solo_dps"]),
		"solo": output / float(reference["power_budget_min"]),
		"aoe": aoe / maxf(float(reference["power_budget_min"]), 1.0),
		"crowd": crowd,
		"defense": defense,
		"floor_damage": float(params.get("wave_damage", 0.0)) \
			* float(params.get("wave_count", 0)) * base_damage,
		"map_wide": weapon_id == "plague_syringe",
	}


func _test_plague_syringe_v2(profile: Dictionary, row: Dictionary, metrics: Dictionary) -> void:
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	for parameter in ["max_range", "spread_per_wave", "death_spread_cap", "infected_cap"]:
		_check(not params.has(parameter),
			"Black Epidemic must not retain the count-shaped or range-gated parameter %s" % parameter)
	var pool := Budget.live_standard_pool(float(row["reference_solo_dps"]))
	for count in CROWD_COUNTS:
		var required := Budget.PER_ENEMY_FLOOR_FRACTION * pool / float(count)
		_check(float(metrics["floor_damage"]) >= required - 0.001,
			"Black Epidemic leaves a %d-enemy floor of %.2f below %.2f" % [
				count, float(metrics["floor_damage"]), required,
			])


func _check_trio(metrics: Dictionary) -> void:
	var restore := metrics["restore_potion"] as Dictionary
	var plague := metrics["plague_syringe"] as Dictionary
	var saw := metrics["bone_saw"] as Dictionary
	_check(float(saw["solo"]) > float(restore["solo"]) * 0.9,
		"Emergency Surgery must remain the close-range solo option")
	_check(bool(plague["map_wide"]),
		"Black Epidemic must retain map-wide crowd reach")
	_check(float(restore["defense"]) > float(plague["defense"]),
		"Life and Death must retain the stronger pool/shield defense axis")
	var total := (float(restore["power_seconds"]) + float(plague["power_seconds"]) + float(saw["power_seconds"])) / 3.0
	_check(total >= Budget.POWER_SECONDS_MIN and total <= Budget.POWER_SECONDS_MAX,
		"Doctor trio power midpoint must remain inside the v2 power corridor")


func _check_charge(row: Dictionary, weapon_id: String) -> void:
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate(), "%s must spend one full charge" % weapon_id)
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)),
		"%s must not earn charge while active" % weapon_id)
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate(), "%s must not activate twice in one encounter" % weapon_id)
	var restored := Ledger.new(row)
	ledger.set_ultimate_active(false)
	ledger.apply_start_charge(0.63)
	restored.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(restored.charge, 63.0) and not restored.is_ultimate_active(),
		"%s must persist charge, not active state" % weapon_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s power=%.2fs aoe=%.2f crowd=%.0f defense=%.1f" % [weapon_id, row["power_seconds"], row["aoe"], row["crowd"], row["defense"]])
	if _errors.is_empty():
		print("doctor_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("doctor_balance_test: %s" % error)
	quit(1)
