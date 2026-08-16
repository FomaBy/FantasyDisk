extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "assassin"
const WEAPONS := ["chakrams", "shadow_daggers", "venom_wire"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const DEFENSE_REFERENCE_SECONDS := 1.6

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
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_coefficient := 0.0
	var five_target_coefficient := 0.0
	var crowd_cap := 0
	var defense_seconds := 0.0
	match weapon_id:
		"chakrams":
			solo_coefficient = float(params["pass_damage"]) * 2.0
			five_target_coefficient = solo_coefficient \
				* (1.0 + 4.0 * float(params["secondary_damage_ratio"]))
			crowd_cap = 8
		"shadow_daggers":
			solo_coefficient = float(params["backstab_damage"])
			five_target_coefficient = solo_coefficient \
				* (1.0 + 4.0 * float(params["secondary_damage_ratio"]))
			crowd_cap = int(params["target_count"])
			defense_seconds = float(params["untargetable_duration"])
		"venom_wire":
			var pulses := float(params["cut_pulses"])
			var max_cuts := float(params["max_cuts_per_pulse"])
			var stacks := pulses * max_cuts
			solo_coefficient = stacks * float(params["cut_damage"]) \
				+ float(params["burst_damage"]) \
				* (1.0 + (stacks - 1.0) * float(params["stack_bonus"]))
			var edge_stacks := pulses
			var edge_output := edge_stacks * float(params["cut_damage"]) \
				+ float(params["burst_damage"]) \
				* (1.0 + (edge_stacks - 1.0) * float(params["stack_bonus"]))
			five_target_coefficient = edge_output * 5.0
			crowd_cap = int(params["target_limit"])
			defense_seconds = float(params["poison_duration"])
	var solo_output := solo_coefficient * base_damage
	var aoe_output := five_target_coefficient * base_damage
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / maxf(aoe_midpoint, 0.01),
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"])
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	match weapon_id:
		"chakrams":
			_check(int(metrics["crowd_cap"]) == 8,
				"Eight Moons must keep exactly eight compass lanes")
		"shadow_daggers":
			_check(int(metrics["crowd_cap"]) == 7
				and float(metrics["defense_seconds"]) >= 1.5,
				"Moment Before Death must keep seven marks and its brief safe window")
		"venom_wire":
			_check(int(metrics["crowd_cap"]) == 24
				and float(metrics["defense_seconds"]) >= 3.0,
				"Black Web must keep its bounded crowd/control niche")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["chakrams"] as Dictionary)["crowd_cap"]) / 8.0
		+ float((metrics["shadow_daggers"] as Dictionary)["crowd_cap"]) / 7.0
		+ float((metrics["venom_wire"] as Dictionary)["crowd_cap"]) / 24.0
	) / 3.0
	var defense_score := _average(metrics, "defense_seconds") / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0), "all three crowd rails must obey their hard caps")
	_check(defense_score >= TRIO_MIN and defense_score <= TRIO_MAX,
		"trio defense score %.3f must stay inside %.2f..%.2f" % [defense_score, TRIO_MIN, TRIO_MAX])
	_check(float((metrics["shadow_daggers"] as Dictionary)["solo_ratio"])
		> float((metrics["venom_wire"] as Dictionary)["solo_ratio"])
		and int((metrics["venom_wire"] as Dictionary)["crowd_cap"])
		> int((metrics["shadow_daggers"] as Dictionary)["crowd_cap"]),
		"Shadow Daggers must lead focused burst while Venom Wire leads crowd reach")
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var row := Budget.row_for(rows, CLASS_ID, "shadow_daggers")
	var profile := registry.catalog_profile_for(CLASS_ID, "shadow_daggers")
	var mutated := profile.duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["backstab_damage"] = 600.0
	var measured := _measure("shadow_daggers", row, mutated)
	_check(float(measured["solo_output"]) > float(row["power_budget_max"]),
		"the balance proof must go red for runaway stored backstab damage")


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
		print("assassin_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("assassin_balance_test: %s" % error)
	print("assassin_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
