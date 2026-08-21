extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPONS := ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]
const DATA_ROOT := "res://data/ultimates/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/classes"
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(),
		"the inherited 51-row balance harness must remain clean")
	var profiles := _active_profiles()
	var metrics := {}
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile := profiles.get(weapon_id, {}) as Dictionary
		metrics[weapon_id] = _measure(weapon_id, row, profile)
		_test_weapon(weapon_id, row, profile, metrics[weapon_id])
	_test_trio(metrics)
	_test_harness_goes_red(profiles, rows)
	_report(metrics)


func _active_profiles() -> Dictionary:
	var shipped := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(shipped.is_valid(), "the immutable catalog must remain valid")
	var discovery := Discovery.new(DATA_ROOT, SCRIPT_ROOT)
	discovery.discover(Schema.index_documents(shipped.documents_for_tests()))
	_check(discovery.validation_errors().is_empty(),
		"active balance discovery must stay valid: %s" % [discovery.validation_errors()])
	var profiles := {}
	for weapon_id in WEAPONS:
		profiles[weapon_id] = discovery.profile_for("%s/%s" % [CLASS_ID, weapon_id])
	return profiles


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) 		* float(derived["ultimate_multiplier"])
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var solo_coefficient := 0.0
	var representative_aoe_coefficient := 0.0
	var crowd_cap := 0
	var defense_seconds := 0.0
	match weapon_id:
		"soldier_rifle":
			solo_coefficient = float(params.get("damage", 0.0)) * float(params.get("volley_count", 0))
			representative_aoe_coefficient = solo_coefficient
			crowd_cap = 0
		"soldier_grenade":
			solo_coefficient = float(params.get("damage", 0.0)) 				+ float(params.get("crater_damage", 0.0)) * float(params.get("crater_ticks", 0))
			representative_aoe_coefficient = float(params.get("grenade_count", 0)) * solo_coefficient
			crowd_cap = 0
		"soldier_bayonet":
			solo_coefficient = float(params.get("damage", 0.0))
			representative_aoe_coefficient = solo_coefficient * float(params.get("rank_count", 0))
			crowd_cap = 0
			defense_seconds = float(params.get("pin_duration", 0.0))
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	return {
		"solo_output": solo_coefficient * base_damage,
		"solo_ratio": solo_coefficient * base_damage / power_midpoint,
		"aoe_output": representative_aoe_coefficient * base_damage,
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"]) 		and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must keep its immutable whole-activation boss cap" % weapon_id)
	_check(str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_BURST,
		"%s must preserve Soldier's frozen burst archetype" % weapon_id)
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	match weapon_id:
		"soldier_rifle":
			_check(int(params.get("volley_count", 0)) == 3 and not params.has("target_limit"),
				"rifle must retain three volleys without a target-count cap")
		"soldier_grenade":
			_check(int(params.get("grenade_count", 0)) == 7 and int(params.get("seed", 0)) == 1469
				and not params.has("target_limit"),
				"grenade must retain seven deterministic throws without a target-count cap")
		"soldier_bayonet":
			_check(int(params.get("rank_count", 0)) == 3 and not params.has("target_limit"),
				"bayonet must retain three ranks without a target-count cap")
			_check(float(metrics["defense_seconds"]) >= 2.2
				and is_equal_approx(float(params.get("guard_defense", 0.0)), 0.25),
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
	_check(is_zero_approx(float((metrics["soldier_rifle"] as Dictionary)["crowd_cap"]))
		and is_zero_approx(float((metrics["soldier_grenade"] as Dictionary)["crowd_cap"]))
		and is_zero_approx(float((metrics["soldier_bayonet"] as Dictionary)["crowd_cap"])),
		"the trio must keep map-wide targeting without count-shaped caps")
	_check(is_equal_approx(float((metrics["soldier_bayonet"] as Dictionary)["defense_seconds"]), 2.4)
		and is_zero_approx(float((metrics["soldier_rifle"] as Dictionary)["defense_seconds"]))
		and is_zero_approx(float((metrics["soldier_grenade"] as Dictionary)["defense_seconds"])),
		"only bayonet may own the class package's control/save contribution")


func _test_harness_goes_red(profiles: Dictionary, rows: Array) -> void:
	var altered := profiles.duplicate(true)
	var grenade := (altered["soldier_grenade"] as Dictionary).duplicate(true)
	((grenade["executor"] as Dictionary)["params"]["damage"]) = 400.0
	altered["soldier_grenade"] = grenade
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, altered[weapon_id])
		if float(measured["solo_output"]) < float(row["power_budget_min"]) 				or float(measured["solo_output"]) > float(row["power_budget_max"]):
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
			weapon_id, row["solo_ratio"], row["aoe_output"], row["crowd_cap"], row["defense_seconds"],
		])
	if _errors.is_empty():
		print("soldier_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("soldier_balance_test: %s" % error)
	print("soldier_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
