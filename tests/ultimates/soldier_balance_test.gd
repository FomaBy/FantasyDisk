extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPONS := ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(),
		"the inherited 51-row balance harness must remain clean")
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var metrics := {}
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		metrics[weapon_id] = _measure(weapon_id, row, profile)
		_test_weapon(weapon_id, row, profile, metrics[weapon_id])
	_test_trio(metrics)
	_test_harness_goes_red(registry, rows)
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) \
		* float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_coefficient := 0.0
	var representative_aoe_coefficient := 0.0
	var crowd_cap := 0
	var defense_seconds := 0.0
	match weapon_id:
		"soldier_rifle":
			solo_coefficient = float(params["damage"]) * float(params["volley_count"])
			representative_aoe_coefficient = solo_coefficient
			crowd_cap = int(params["target_limit"])
		"soldier_grenade":
			solo_coefficient = float(params["damage"]) \
				+ float(params["crater_damage"]) * float(params["crater_ticks"])
			# One distinct silhouette per grenade plus the crater tail on the
			# same seven-seat representative pack; the hard runtime cap remains 26.
			representative_aoe_coefficient = float(params["grenade_count"]) \
				* (float(params["damage"]) \
					+ float(params["crater_damage"]) * float(params["crater_ticks"]))
			crowd_cap = int(params["target_limit"])
		"soldier_bayonet":
			solo_coefficient = float(params["damage"])
			representative_aoe_coefficient = float(params["damage"]) \
				* float(params["rank_count"])
			crowd_cap = int(params["target_limit"])
			defense_seconds = float(params["pin_duration"])
	var solo_output := solo_coefficient * base_damage
	var aoe_output := representative_aoe_coefficient * base_damage
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"]) \
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must keep its immutable whole-activation boss cap" % weapon_id)
	_check(str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_BURST,
		"%s must preserve Soldier's frozen burst archetype" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	match weapon_id:
		"soldier_rifle":
			_check(int(params["volley_count"]) == 3 and int(metrics["crowd_cap"]) == 3,
				"rifle must retain three volleys over three dense-corridor seats")
		"soldier_grenade":
			_check(int(params["grenade_count"]) == 7 and int(params["seed"]) == 1469
				and int(metrics["crowd_cap"]) == 26,
				"grenade must retain seven deterministic throws and its crowd rail")
		"soldier_bayonet":
			_check(int(params["rank_count"]) == 3 and int(metrics["crowd_cap"]) == 18,
				"bayonet must retain three ranks and its corridor rail")
			_check(float(metrics["defense_seconds"]) >= 2.2
				and is_equal_approx(float(params["guard_defense"]), 0.25),
				"bayonet must contribute a decisive pin plus its declared guard")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(float((metrics["soldier_grenade"] as Dictionary)["aoe_output"])
		> float((metrics["soldier_bayonet"] as Dictionary)["aoe_output"])
		and float((metrics["soldier_bayonet"] as Dictionary)["aoe_output"])
		> float((metrics["soldier_rifle"] as Dictionary)["aoe_output"]),
		"grenade, bayonet and rifle must keep distinct descending crowd roles")
	_check(int((metrics["soldier_rifle"] as Dictionary)["crowd_cap"]) == 3
		and int((metrics["soldier_grenade"] as Dictionary)["crowd_cap"]) == 26
		and int((metrics["soldier_bayonet"] as Dictionary)["crowd_cap"]) == 18,
		"the trio must retain distinct 3/26/18 target rails")
	_check(is_equal_approx(float((metrics["soldier_bayonet"] as Dictionary)["defense_seconds"]), 2.4)
		and is_zero_approx(float((metrics["soldier_rifle"] as Dictionary)["defense_seconds"]))
		and is_zero_approx(float((metrics["soldier_grenade"] as Dictionary)["defense_seconds"])),
		"only bayonet may own the class package's control/save contribution")


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var profiles := {}
	for weapon_id in WEAPONS:
		profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var grenade := (profiles["soldier_grenade"] as Dictionary).duplicate(true)
	((grenade["executor"] as Dictionary)["params"] as Dictionary)["damage"] = 400.0
	profiles["soldier_grenade"] = grenade
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, profiles[weapon_id])
		if float(measured["solo_output"]) < float(row["power_budget_min"]) \
				or float(measured["solo_output"]) > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["soldier_grenade"],
		"the Soldier balance proof must go red for a runaway grenade coefficient")


func _average(metrics: Dictionary, key: String) -> float:
	var total := 0.0
	for weapon_id in WEAPONS:
		total += float((metrics[weapon_id] as Dictionary)[key])
	return total / float(WEAPONS.size())


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s solo=%.3f aoe=%.2f crowd=%d defense=%.2fs" % [
			weapon_id,
			row["solo_ratio"],
			row["aoe_output"],
			row["crowd_cap"],
			row["defense_seconds"],
		])
	if _errors.is_empty():
		print("soldier_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("soldier_balance_test: %s" % error)
	print("soldier_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
