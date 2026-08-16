extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "elementalist"
const WEAPONS := [
	"elementalist_orb_ring",
	"elementalist_prism_focus",
	"elementalist_meteor_core",
]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const DEFENSE_REFERENCE_SECONDS := 3.75

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var inherited_report := Harness.measure(rows)
	_check(Harness.violations(inherited_report).is_empty(),
		"the inherited 51-row charge/power harness must remain clean")
	_check(registry.package_validation_errors().is_empty(),
		"package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var metrics := {}
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		metrics[weapon_id] = _measure(weapon_id, row, profile)
		_test_weapon(weapon_id, row, profile, metrics[weapon_id], registry)
	_test_trio(metrics)
	_test_charge_contract(rows)
	_test_harness_goes_red(registry, rows)
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived["magic_damage"]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_output := 0.0
	var aoe_output := 0.0
	var defense_seconds := 0.0
	var crowd_cap := int(params["crowd_cap"])
	match weapon_id:
		"elementalist_orb_ring":
			var nova := float(params["nova_damage"]) \
				* (1.0 + 4.0 * float(params["nova_status_bonus"]))
			var direct := float(params["burn_damage"]) + float(params["frost_damage"]) \
				+ float(params["gale_damage"])
			solo_output = (direct + float(params["shock_damage"]) + nova) * base_damage
			var chain := 0.0
			for hop in mini(5, int(params["shock_chain_count"])):
				chain += pow(float(params["shock_falloff"]), hop)
			aoe_output = (direct * 5.0 + float(params["shock_damage"]) * chain \
				+ nova * 5.0) * base_damage
			defense_seconds = float(params["freeze_duration"])
		"elementalist_prism_focus":
			var admitted_hits := mini(int(params["sweep_count"]), int(params["lattice_hit_cap"]))
			solo_output = (float(admitted_hits) * float(params["lattice_damage"]) \
				+ float(params["shatter_damage"])) * base_damage
			# Three bodies cross the moving focus three times; two edge bodies catch
			# one lattice pass. All five remain inside the terminal fracture.
			aoe_output = (
				3.0 * float(admitted_hits) * float(params["lattice_damage"])
				+ 2.0 * float(params["lattice_damage"])
				+ 5.0 * float(params["shatter_damage"])
			) * base_damage
			defense_seconds = float(params["fracture_duration"])
		"elementalist_meteor_core":
			var coefficient := float(params["impact_damage"]) \
				+ float(params["crater_pulses"]) * float(params["crater_damage"])
			solo_output = coefficient * base_damage
			aoe_output = solo_output * 5.0
			defense_seconds = float(params["crater_duration"])
	var power_midpoint := (float(row["power_budget_min"]) \
		+ float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"base_damage": base_damage,
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / aoe_midpoint,
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _test_weapon(
	weapon_id: String,
	row: Dictionary,
	profile: Dictionary,
	metrics: Dictionary,
	registry: Registry
) -> void:
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id)
	_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must own an exact executor pair" % weapon_id)
	_check(str((profile["charge"] as Dictionary)["strategy_id"]) == "rare_charge_ledger",
		"%s must consume rare-charge contract U3" % weapon_id)
	_check(str((profile["cleanup_policy"] as Dictionary)["strategy_id"]) == "activation_owned",
		"%s must use activation-owned cleanup" % weapon_id)
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must inherit the frozen whole-activation boss cap" % weapon_id)
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"]) \
			and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	match weapon_id:
		"elementalist_orb_ring":
			_check(float(metrics["aoe_ratio"]) >= 1.05 and float(metrics["aoe_ratio"]) <= 1.45,
				"Conclave must lead control/AoE without leaving its corridor")
			_check(int(params["crowd_cap"]) == 24 and int(params["shock_chain_count"]) == 6,
				"Conclave crowd/chain rails must remain 24/6")
		"elementalist_prism_focus":
			_check(float(metrics["aoe_ratio"]) >= 0.75 and float(metrics["aoe_ratio"]) <= 1.05,
				"Prism must buy arena geometry with bounded focus output")
			_check(int(params["lattice_hit_cap"]) == 3 and int(params["crowd_cap"]) == 18,
				"Prism must retain its triple-hit and crowd caps")
		"elementalist_meteor_core":
			_check(float(metrics["aoe_ratio"]) >= 1.05 and float(metrics["aoe_ratio"]) <= 1.45,
				"Meteor must retain the aimed crowd-nuke corridor")
			_check(int(params["crowd_cap"]) == 20 \
					and float(params["normal_execute_max_health"]) == 900.0,
				"Meteor must retain its bounded normal execute rail")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics[WEAPONS[0]] as Dictionary)["crowd_cap"]) / 24.0
		+ float((metrics[WEAPONS[1]] as Dictionary)["crowd_cap"]) / 18.0
		+ float((metrics[WEAPONS[2]] as Dictionary)["crowd_cap"]) / 20.0
	) / 3.0
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= 1.20,
		"AoE-class trio score %.3f must stay inside 0.90..1.20" % aoe_score)
	_check(is_equal_approx(crowd_score, 1.0), "all three crowd rails must obey their caps")
	_check(defense_seconds >= 3.5 and defense_seconds <= 4.0,
		"trio defense contribution %.3fs must stay inside 3.5..4.0s" % defense_seconds)
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])
	_check(float((metrics[WEAPONS[0]] as Dictionary)["defense_seconds"]) \
			> float((metrics[WEAPONS[1]] as Dictionary)["defense_seconds"]),
		"Conclave control and Prism geometry must not converge onto one role")


func _test_charge_contract(rows: Array) -> void:
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var ledger := Ledger.new(row)
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		ledger.apply_start_charge(1.0)
		_check(ledger.try_activate(), "%s full charge must buy one activation" % weapon_id)
		ledger.set_ultimate_active(true)
		_check(is_zero_approx(ledger.add_removed_health(
			float(row["reference_solo_dps"]) * Budget.NORMAL_ENCOUNTER_SECONDS
		)), "%s must earn no dealt-damage charge while active" % weapon_id)
		_check(is_zero_approx(ledger.add_taken_health(100.0, 100.0)),
			"%s must earn no taken-damage charge while active" % weapon_id)
		ledger.apply_start_charge(1.0)
		_check(not ledger.try_activate(), "%s must refuse a second encounter activation" % weapon_id)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, Budget.MAX_CHARGE) \
				and not restored.is_ultimate_active() and restored.encounter_activations() == 0,
			"%s snapshot must retain charge but drop transient active/use state" % weapon_id)
		_check(restored.try_activate(),
			"%s restored charge must activate in the fresh encounter" % weapon_id)


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var profile := registry.catalog_profile_for(CLASS_ID, "elementalist_prism_focus")
	((profile["executor"] as Dictionary)["params"] as Dictionary)["lattice_damage"] = 80.0
	var row := Budget.row_for(rows, CLASS_ID, "elementalist_prism_focus")
	var measured := _measure("elementalist_prism_focus", row, profile)
	_check(float(measured["solo_output"]) > float(row["power_budget_max"]),
		"the balance proof must go red for runaway lattice damage")


func _average(metrics: Dictionary, key: String) -> float:
	var total := 0.0
	for weapon_id in WEAPONS:
		total += float((metrics[weapon_id] as Dictionary)[key])
	return total / float(WEAPONS.size())


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	print("Elementalist ultimate balance (after package):")
	print("  weapon                         solo    aoe  crowd defense  base")
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %-29s %.3f  %.3f  %5d  %5.2fs %.2f" % [
			weapon_id,
			row["solo_ratio"],
			row["aoe_ratio"],
			row["crowd_cap"],
			row["defense_seconds"],
			row["base_damage"],
		])
	if _errors.is_empty():
		print("elementalist_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("elementalist_balance_test: %s" % error)
	print("elementalist_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
