extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "priest"
const WEAPONS := ["priest_reliquary", "priest_censer", "priest_chime"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const DEFENSE_REFERENCE_SECONDS := 4.4

var _errors: Array[String] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
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
	var params := ((profile["executor"] as Dictionary)["params"] as Dictionary)
	var solo_output := 0.0
	var aoe_output := 0.0
	var defense_seconds := 0.0
	var crowd_cap := 0
	match weapon_id:
		"priest_reliquary":
			var rings := float(params["first_ring_damage"]) + float(params["sanctify_damage"]) \
				+ float(params["pillar_damage"])
			solo_output = rings * base_damage
			var sanctum_weight := 0.0
			for index in 5:
				sanctum_weight += pow(float(params["crowd_falloff"]), float(index))
			aoe_output = rings * base_damage * sanctum_weight
			defense_seconds = float(params["lifetime"]) - float(params["pillar_at"])
			crowd_cap = int(params["crowd_cap"])
		"priest_censer":
			# The counter uses observed prevented HP, but its cap expresses the
			# maximum priced output. No incoming hit means no counter damage.
			solo_output = float(params["counter_damage_cap"]) * base_damage
			var counter_weight := 0.0
			for index in 5:
				counter_weight += pow(float(params["counter_falloff"]), float(index))
			aoe_output = solo_output * counter_weight
			defense_seconds = float(params["lifetime"])
			crowd_cap = int(params["counter_target_cap"])
		"priest_chime":
			var chain := 0.0
			for index in int(params["chain_targets"]):
				chain += pow(float(params["chain_falloff"]), float(index))
			solo_output = (float(params["interrupt_damage"]) + float(params["chain_damage"])) * base_damage
			aoe_output = (float(params["interrupt_damage"]) * 5.0 + float(params["chain_damage"]) * chain) * base_damage
			defense_seconds = float(params["lifetime"]) - float(params["third_toll_at"])
			crowd_cap = int(params["crowd_cap"])
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


func _test_weapon(weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary) -> void:
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"])
			and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	var params := ((profile["executor"] as Dictionary)["params"] as Dictionary)
	match weapon_id:
		"priest_reliquary":
			_check(int(metrics["crowd_cap"]) == 22 and float(params["heal_ratio"]) == 0.35,
				"Reliquary must retain its 22-target sanctum and actual-damage heal rail")
			_check(float(metrics["defense_seconds"]) >= 3.0,
				"Reliquary shield must remain live for a meaningful post-pillar window")
		"priest_censer":
			_check(int(metrics["crowd_cap"]) == 12 and float(params["stored_ratio"]) == 0.65,
				"Censer must remain a capped observed-prevention counter")
			_check(float(metrics["defense_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"Censer mitigation must remain the trio's decisive defense save")
		"priest_chime":
			_check(int(metrics["crowd_cap"]) == 18 and int(params["chain_targets"]) == 6,
				"Chime must retain its 18-target interrupt and six-link chain")
			_check(float(metrics["defense_seconds"]) >= 2.0,
				"Chime must leave a visible lethal-prevention window after the third toll")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["priest_reliquary"] as Dictionary)["crowd_cap"]) / 22.0
		+ float((metrics["priest_censer"] as Dictionary)["crowd_cap"]) / 12.0
		+ float((metrics["priest_chime"] as Dictionary)["crowd_cap"]) / 18.0
	) / 3.0
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= 0.90 and aoe_score <= 1.35,
		"trio AoE score %.3f must preserve the defensive tradeoff" % aoe_score)
	_check(is_equal_approx(crowd_score, 1.0), "all three declared crowd rails must obey their caps")
	_check(defense_seconds >= 4.2 and defense_seconds <= 4.6,
		"trio defense contribution %.3fs must stay inside 4.2..4.6s" % defense_seconds)
	_check(float((metrics["priest_censer"] as Dictionary)["defense_seconds"])
			> float((metrics["priest_chime"] as Dictionary)["defense_seconds"])
		and float((metrics["priest_chime"] as Dictionary)["aoe_ratio"])
			> float((metrics["priest_censer"] as Dictionary)["aoe_ratio"]),
		"the protection counter and bell chain must not converge onto one role")
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var profiles := {}
	for weapon_id in WEAPONS:
		profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var chime := (profiles["priest_chime"] as Dictionary).duplicate(true)
	((chime["executor"] as Dictionary)["params"] as Dictionary)["chain_damage"] = 500.0
	profiles["priest_chime"] = chime
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var measured := _measure(weapon_id, Budget.row_for(rows, CLASS_ID, weapon_id), profiles[weapon_id])
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		if float(measured["solo_output"]) < float(row["power_budget_min"]) \
				or float(measured["solo_output"]) > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["priest_chime"],
		"the balance proof must go red for a runaway third-bell chain")


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
		print("  %s solo=%.3f aoe=%.3f crowd=%d defense=%.2fs" % [
			weapon_id, row["solo_ratio"], row["aoe_ratio"], row["crowd_cap"], row["defense_seconds"],
		])
	if _errors.is_empty():
		print("priest_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("priest_balance_test: %s" % error)
	print("priest_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
