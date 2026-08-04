extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "druid"
const WEAPONS := ["summon_amulet", "briar_staff", "raven_totem"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10

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
	_test_proof_goes_red(rows, registry)
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var derived := PD.derived_parameters(
		PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, weapon_id)
	)
	var base_damage := float(derived["magic_damage"]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var coefficient := 0.0
	var crowd_cap := 0
	var defense_seconds := 0.0
	match weapon_id:
		"summon_amulet":
			coefficient = float(params["pack_count"]) * (
				float(params["stampede_damage"])
				+ float(params["hunt_waves"]) * float(params["hunt_damage"])
			)
			crowd_cap = int(params["target_cap"])
		"briar_staff":
			coefficient = float(params["impale_damage"]) * float(params["impale_pulses"] - 1) \
				+ float(params["thorn_crown_damage"])
			crowd_cap = int(params["target_cap"])
			defense_seconds = float(params["root_duration"])
		"raven_totem":
			coefficient = float(params["dive_damage"]) * float(params["dive_waves"]) \
				+ float(params["final_damage"])
			crowd_cap = int(params["crowd_cap"])
			defense_seconds = float(params["mark_duration"])
	var solo_output := coefficient * base_damage
	var aoe_multiplier := 1.0
	match weapon_id:
		"summon_amulet":
			aoe_multiplier = 1.0 + float(params["hunt_splash_target_cap"] - 1) \
				* float(params["splash_damage_ratio"])
		"briar_staff", "raven_totem":
			aoe_multiplier = 3.0
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": solo_output * aoe_multiplier,
		"aoe_ratio": solo_output * aoe_multiplier / aoe_midpoint,
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
	match weapon_id:
		"summon_amulet":
			_check(int(metrics["crowd_cap"]) == 12 and float(metrics["defense_seconds"]) == 0.0,
				"Wild Hunt must remain the transient priority-pack damage role")
		"briar_staff":
			_check(int(metrics["crowd_cap"]) == 20 and float(metrics["defense_seconds"]) >= 4.0,
				"Briar must remain the five-seed crowd-control role")
		"raven_totem":
			_check(int(metrics["crowd_cap"]) == 22 and float(metrics["defense_seconds"]) >= 7.0,
				"Raven must remain the marked-vortex control role")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["summon_amulet"] as Dictionary)["crowd_cap"]) / 12.0
		+ float((metrics["briar_staff"] as Dictionary)["crowd_cap"]) / 20.0
		+ float((metrics["raven_totem"] as Dictionary)["crowd_cap"]) / 22.0
	) / 3.0
	var defense_score := _average(metrics, "defense_seconds") / 4.27
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0), "declared crowd caps must stay hard-capped")
	_check(defense_score >= TRIO_MIN and defense_score <= TRIO_MAX,
		"trio control score %.3f must stay inside %.2f..%.2f" % [defense_score, TRIO_MIN, TRIO_MAX])
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_proof_goes_red(rows: Array, registry: Registry) -> void:
	var row := Budget.row_for(rows, CLASS_ID, "summon_amulet")
	var profile := registry.catalog_profile_for(CLASS_ID, "summon_amulet")
	var mutated := profile.duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["hunt_damage"] = 99.0
	var measured := _measure("summon_amulet", row, mutated)
	_check(float(measured["solo_output"]) > float(row["power_budget_max"]),
		"the balance proof must go red for an unbounded hunt coefficient")


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
		print("druid_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("druid_balance_test: %s" % error)
	quit(1)
