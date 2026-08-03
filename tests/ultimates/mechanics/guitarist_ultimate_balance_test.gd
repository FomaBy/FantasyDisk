extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "guitarist"
const WEAPONS := ["electric_guitar", "bass_guitar", "sound_amp"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const DEFENSE_REFERENCE_SECONDS := 1.8

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(),
		"the inherited 51-row charge and boss-cap harness must remain clean")
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.package_validation_errors().is_empty(),
		"Guitarist package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var metrics := {}
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		metrics[weapon_id] = _measure(weapon_id, row, profile)
		_check_profile(weapon_id, row, profile, registry, metrics[weapon_id])
		_check_charge_contract(weapon_id, row)
	_check_trio(metrics)
	_check_balance_proof_goes_red(registry, rows)
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived["magic_damage"]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_coefficient := 0.0
	var aoe_coefficient := 0.0
	var crowd_cap := int(params["crowd_cap"])
	var defense_seconds := 0.0
	match weapon_id:
		"electric_guitar":
			solo_coefficient = float(params["strip_count"]) * float(params["strip_damage"]) \
				+ float(params["final_damage"])
			aoe_coefficient = float(params["strip_count"]) * float(params["strip_damage"]) * 2.0 \
				+ float(params["final_damage"]) * 5.0
			defense_seconds = float(params["stun_duration"])
		"bass_guitar":
			solo_coefficient = float(params["pull_damage"]) + float(params["weight_damage"]) \
				+ float(params["launch_damage"]) + float(params["shock_damage"])
			aoe_coefficient = float(params["pull_damage"]) \
				+ float(params["weight_damage"]) * 2.0 \
				+ float(params["launch_damage"]) * 3.0 \
				+ float(params["shock_damage"]) * 5.0
			defense_seconds = float(params["weight_duration"])
		"sound_amp":
			solo_coefficient = float(params["pulse_count"]) * float(params["feedback_damage"]) \
				+ float(params["overload_damage"])
			aoe_coefficient = solo_coefficient * 5.0
			defense_seconds = float(params["feedback_duration"])
	var solo_output := solo_coefficient * base_damage
	var aoe_output := aoe_coefficient * base_damage
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / aoe_midpoint,
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _check_profile(
	weapon_id: String,
	row: Dictionary,
	profile: Dictionary,
	registry,
	metrics: Dictionary
) -> void:
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve only through its exact ready pair" % weapon_id)
	_check(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must have its matching class-local executor" % weapon_id)
	_check(str(profile.get("implementation_state", "")) == "ready"
		and str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger"
		and str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
		"%s must retain ready, rare-charge and activation-owned contracts" % weapon_id)
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must inherit Guitarist's immutable nine-percent boss cap" % weapon_id)
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"])
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must remain inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	match weapon_id:
		"electric_guitar":
			_check(float(metrics["aoe_ratio"]) >= 0.75 and float(metrics["aoe_ratio"]) <= 0.95
				and int(metrics["crowd_cap"]) == 14,
				"Last Chord must retain the precision/intersection lane")
		"bass_guitar":
			_check(float(metrics["aoe_ratio"]) >= 0.75 and float(metrics["aoe_ratio"]) <= 0.95
				and int(metrics["crowd_cap"]) == 12,
				"Hell Subwoofer must retain the expanding crowd-control lane")
		"sound_amp":
			_check(float(metrics["aoe_ratio"]) >= 1.15 and float(metrics["aoe_ratio"]) <= 1.40
				and int(metrics["crowd_cap"]) == 14,
				"Wall of Sound must retain the stationary field-clear lane")


func _check_charge_contract(weapon_id: String, row: Dictionary) -> void:
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate(), "%s full charge must buy one activation" % weapon_id)
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)),
		"%s active effect must not earn dealt-damage charge" % weapon_id)
	_check(is_zero_approx(ledger.add_taken_health(100.0, 100.0)),
		"%s active effect must not earn taken-damage charge" % weapon_id)
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate() and is_equal_approx(ledger.charge, Budget.MAX_CHARGE),
		"%s must refuse a second encounter activation without spending charge" % weapon_id)
	var restored := Ledger.new(row)
	restored.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(restored.charge, Budget.MAX_CHARGE)
		and not restored.is_ultimate_active() and restored.encounter_activations() == 0,
		"%s battle/act/Continue snapshot must keep charge but clear active state" % weapon_id)
	_check(restored.try_activate(), "%s restored charge must activate in a new encounter" % weapon_id)


func _check_trio(metrics: Dictionary) -> void:
	var solo_score := 0.0
	var aoe_score := 0.0
	var crowd_score := 0.0
	var defense_score := 0.0
	for weapon_id in WEAPONS:
		var metric := metrics[weapon_id] as Dictionary
		solo_score += float(metric["solo_ratio"])
		aoe_score += float(metric["aoe_ratio"])
		crowd_score += float(metric["crowd_cap"]) / (12.0 if weapon_id == "bass_guitar" else 14.0)
		defense_score += float(metric["defense_seconds"]) / DEFENSE_REFERENCE_SECONDS
	solo_score /= float(WEAPONS.size())
	aoe_score /= float(WEAPONS.size())
	crowd_score /= float(WEAPONS.size())
	defense_score /= float(WEAPONS.size())
	var total := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"Guitarist trio solo score %.3f must remain in %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"Guitarist trio AoE score %.3f must remain in %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0), "each Guitarist crowd rail must remain capped")
	_check(defense_score >= TRIO_MIN and defense_score <= TRIO_MAX,
		"Guitarist trio defense score %.3f must remain in %.2f..%.2f" % [defense_score, TRIO_MIN, TRIO_MAX])
	_check(total >= TRIO_MIN and total <= TRIO_MAX,
		"Guitarist trio total %.3f must remain in %.2f..%.2f" % [total, TRIO_MIN, TRIO_MAX])


func _check_balance_proof_goes_red(registry, rows: Array) -> void:
	var profiles := {}
	for weapon_id in WEAPONS:
		profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var electric := (profiles["electric_guitar"] as Dictionary).duplicate(true)
	((electric["executor"] as Dictionary)["params"] as Dictionary)["final_damage"] = 700.0
	profiles["electric_guitar"] = electric
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var output := float((_measure(weapon_id, row, profiles[weapon_id]) as Dictionary)["solo_output"])
		if output < float(row["power_budget_min"]) or output > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["electric_guitar"], "the balance proof must go red for a runaway final chord")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	print("guitarist ultimate balance:")
	for weapon_id in WEAPONS:
		var metric := metrics[weapon_id] as Dictionary
		print("  %-16s solo=%7.2f (%0.3f) aoe=%7.2f (%0.3f) crowd=%2d defense=%.2fs" % [
			weapon_id, metric["solo_output"], metric["solo_ratio"],
			metric["aoe_output"], metric["aoe_ratio"],
			metric["crowd_cap"], metric["defense_seconds"],
		])
	if _errors.is_empty():
		print("guitarist_ultimate_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guitarist_ultimate_balance_test: %s" % error)
	print("guitarist_ultimate_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
