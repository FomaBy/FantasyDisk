extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "dark_mage"
const WEAPONS := ["dark_book", "cursed_skull", "dark_wand"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const DEFENSE_REFERENCE_SECONDS := 0.64

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var harness := Harness.measure(rows)
	_check(Harness.violations(harness).is_empty(),
		"the inherited 51-row balance harness must remain clean")
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.package_validation_errors().is_empty(),
		"Dark Mage package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var metrics := {}
	print("dark_mage ultimate balance (base lvl1 normal-weapon references):")
	print("  weapon       base    budget        solo  solo-r      aoe   aoe-r crowd defense")
	for weapon_id in WEAPONS:
		metrics[weapon_id] = _check_weapon(weapon_id, rows, registry)
	_test_trio(metrics)
	_test_harness_goes_red(registry, rows)
	_report()


func _check_weapon(weapon_id: String, rows: Array, registry) -> Dictionary:
	var row := Budget.row_for(rows, CLASS_ID, weapon_id)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	_check(not row.is_empty() and not profile.is_empty(),
		"%s must retain its immutable budget and ready profile" % weapon_id)
	if row.is_empty() or profile.is_empty():
		return {}
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id)
	_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must retain its exact executor pair" % weapon_id)
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"%s must use the shared rare charge ledger" % weapon_id)
	_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
		"%s must use activation-owned cleanup" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must retain the class whole-activation boss cap" % weapon_id)
	var metrics := _measure(weapon_id, row, profile)
	print("  %-11s %6.2f %5.1f..%-5.1f %8.2f %7.3f %8.2f %7.3f %5d %6.2fs" % [
		weapon_id,
		metrics["base_damage"],
		row["power_budget_min"],
		row["power_budget_max"],
		metrics["solo_output"],
		metrics["solo_ratio"],
		metrics["aoe_output"],
		metrics["aoe_ratio"],
		metrics["crowd_cap"],
		metrics["defense_seconds"],
	])
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"])
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	_check_charge_contract(weapon_id, row)
	_check_identity(weapon_id, profile, metrics)
	return metrics


func _measure(weapon_id: String, _row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) \
		* float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_output := 0.0
	var aoe_output := 0.0
	var crowd_cap := 0
	var defense_seconds := 0.0
	match weapon_id:
		"dark_book":
			solo_output = float(params["original_damage"]) * base_damage
			aoe_output = (float(params["original_damage"])
				+ float(params["reflection_damage"]) * float(params["reflection_cap"])
				+ float(params["kill_burst_damage"]) * float(params["kill_burst_cap"])) * base_damage
			crowd_cap = int(params["crowd_cap"])
		"cursed_skull":
			solo_output = (float(params["curse_damage"]) * float(params["pulse_count"])
				+ float(params["harvest_damage"])) * base_damage
			aoe_output = solo_output * 5.0
			crowd_cap = int(params["crowd_cap"])
			defense_seconds = float(params["curse_duration"]) \
				* (1.0 - float(params["outgoing_damage_multiplier"]))
		"dark_wand":
			solo_output = float(params["base_collapse_damage"]) * base_damage
			var chain_coeff := 0.0
			for index in 5:
				chain_coeff += 1.0 + float(params["distinct_target_ramp"]) * float(index)
			aoe_output = float(params["base_collapse_damage"]) * chain_coeff * base_damage
			crowd_cap = int(params["chain_cap"])
	var power_midpoint := (float(_row["power_budget_min"]) + float(_row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(_row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"base_damage": base_damage,
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / maxf(aoe_midpoint, 0.01),
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _check_identity(weapon_id: String, profile: Dictionary, metrics: Dictionary) -> void:
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	match weapon_id:
		"dark_book":
			_check(int(params["crowd_cap"]) == 12 and int(params["reflection_cap"]) == 2 \
				and int(params["kill_burst_cap"]) == 3,
				"Book must retain its 12-body mirror and bounded 2/3 reflection caps")
			_check(float(metrics["aoe_ratio"]) >= 0.65 and float(metrics["aoe_ratio"]) <= 0.80,
				"Book must remain the bounded paired-blast AoE role")
		"cursed_skull":
			_check(int(params["crowd_cap"]) == 14 and int(params["pulse_count"]) == 4 \
				and int(params["transfer_cap"]) == 8,
				"Crown must retain its 14-body 4-pulse and 8-transfer caps")
			_check(is_equal_approx(float(params["outgoing_damage_multiplier"]), 0.65)
				and is_equal_approx(float(metrics["defense_seconds"]), 1.925),
				"Crown must retain its 35% output reduction for 5.5s")
			_check(float(metrics["aoe_ratio"]) >= 0.75 and float(metrics["aoe_ratio"]) <= 0.90,
				"Crown must remain the broad curse/control bridge")
		"dark_wand":
			_check(int(params["chain_cap"]) == 10 and is_equal_approx(float(params["half_width"]), 72.0)
				and is_equal_approx(float(params["per_target_cap_fraction"]), 0.65),
				"Wand must retain its 10-node aimed rail and 65% focus cap")
			_check(is_equal_approx(float(params["distinct_target_ramp"]), 0.14)
				and float(metrics["aoe_ratio"]) >= 1.0 and float(metrics["aoe_ratio"]) <= 1.10,
				"Wand must remain the ramping aimed-chain output role")


func _test_trio(metrics: Dictionary) -> void:
	if metrics.size() != WEAPONS.size():
		return
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["dark_book"] as Dictionary)["crowd_cap"]) / 12.0
		+ float((metrics["cursed_skull"] as Dictionary)["crowd_cap"]) / 14.0
		+ float((metrics["dark_wand"] as Dictionary)["crowd_cap"]) / 10.0
	) / 3.0
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"Dark Mage trio solo score %.3f must stay inside %.2f..%.2f" \
			% [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= 0.80 and aoe_score <= 0.95,
		"Dark Mage trio AoE score %.3f must preserve its burst/control tradeoff" % aoe_score)
	_check(is_equal_approx(crowd_score, 1.0),
		"all three Dark Mage crowd rails must remain at their declared caps")
	_check(defense_seconds >= 0.60 and defense_seconds <= 0.70,
		"Dark Mage trio defense contribution %.3fs must remain crown-led" % defense_seconds)
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"Dark Mage class-trio total %.3f must stay inside %.2f..%.2f" \
			% [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry, rows: Array) -> void:
	var book: Dictionary = registry.catalog_profile_for(CLASS_ID, "dark_book").duplicate(true)
	((book["executor"] as Dictionary)["params"] as Dictionary)["original_damage"] = 100.0
	var row := Budget.row_for(rows, CLASS_ID, "dark_book")
	var metrics := _measure("dark_book", row, book)
	_check(float(metrics["solo_output"]) > float(row["power_budget_max"]),
		"the balance proof must go red for a runaway Book coefficient")


func _average(metrics: Dictionary, key: String) -> float:
	var total := 0.0
	for weapon_id in WEAPONS:
		total += float((metrics[weapon_id] as Dictionary)[key])
	return total / float(WEAPONS.size())


func _check_charge_contract(weapon_id: String, row: Dictionary) -> void:
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate(), "%s full charge must buy one activation" % weapon_id)
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(float(row["reference_solo_dps"]) * 35.0)),
		"%s active effect must not earn damage charge" % weapon_id)
	_check(is_zero_approx(ledger.add_taken_health(100.0, 100.0)),
		"%s active effect must not earn taken-damage charge" % weapon_id)
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate() and is_equal_approx(ledger.charge, Budget.MAX_CHARGE),
		"%s must refuse a second encounter activation without spending charge" % weapon_id)
	var restored := Ledger.new(row)
	restored.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(restored.charge, Budget.MAX_CHARGE) \
		and not restored.is_ultimate_active() and restored.encounter_activations() == 0,
		"%s charge must persist while active and encounter state is cleared" % weapon_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("dark_mage_ultimate_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_ultimate_balance_test: %s" % error)
	print("dark_mage_ultimate_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
