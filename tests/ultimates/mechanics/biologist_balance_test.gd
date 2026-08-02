extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "biologist"
const WEAPONS := [
	"biologist_spore_lens",
	"biologist_sample_injector",
	"biologist_symbiote_seed",
]
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
	_test_harness_goes_red(registry, rows)
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var derived := PD.derived_parameters(
		PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, weapon_id)
	)
	var base_damage := float(derived["magic_damage"]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_output := 0.0
	var aoe_output := 0.0
	var defense_seconds := 0.0
	match weapon_id:
		"biologist_spore_lens":
			solo_output = float(params["infection_damage"]) \
				* float(params["propagation_waves"]) * base_damage
			aoe_output = solo_output * 5.0
			defense_seconds = float(params["root_duration"])
		"biologist_sample_injector":
			var primary_coeff := float(params["extraction_damage"]) \
				+ float(params["analysis_damage"]) * float(params["analysis_pulses"])
			solo_output = primary_coeff * float(params["durable_bonus"]) * base_damage
			var tissue_targets := mini(int(params["analysis_target_cap"]), 5) - 1
			aoe_output = solo_output + float(tissue_targets) \
				* float(params["analysis_pulses"]) * float(params["analysis_damage"]) \
				* float(params["tissue_damage_ratio"]) * base_damage
		"biologist_symbiote_seed":
			var shared_coeff := float(params["impact_damage"]) + float(params["hatch_damage"])
			var larvae_coeff := float(params["larva_damage"]) * float(params["larva_count"])
			solo_output = (shared_coeff + larvae_coeff) * base_damage
			aoe_output = (shared_coeff * 5.0 + larvae_coeff) * base_damage
			defense_seconds = float(params["root_duration"])
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / aoe_midpoint,
		"crowd_cap": int(params["crowd_cap"]),
		"defense_seconds": defense_seconds,
	}


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	_check(
		float(metrics["solo_output"]) >= float(row["power_budget_min"]) \
			and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		]
	)
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	match weapon_id:
		"biologist_spore_lens":
			_check(float(metrics["aoe_ratio"]) >= 1.0 and float(metrics["aoe_ratio"]) <= 1.4,
				"Spore Lens must own the AoE-leading corridor")
			_check(int(metrics["crowd_cap"]) == 18 and int(params["secondary_bloom_cap"]) == 3,
				"Spore Lens crowd/bloom caps must remain 18/3")
			_check(float(metrics["defense_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"Spore root must contribute a decisive control save")
		"biologist_sample_injector":
			var direct_share := float(params["extraction_damage"]) / (
				float(params["extraction_damage"]) \
				+ float(params["analysis_damage"]) * float(params["analysis_pulses"])
			)
			_check(direct_share >= 0.5 and float(metrics["aoe_ratio"]) >= 0.25 \
				and float(metrics["aoe_ratio"]) <= 0.55,
				"Sample must stay direct-hit/solo-led instead of flattening into AoE")
			_check(int(metrics["crowd_cap"]) == 16 and int(params["analysis_pulses"]) == 3,
				"Sample rail/pulse caps must remain 16/3")
		"biologist_symbiote_seed":
			_check(float(metrics["aoe_ratio"]) >= 0.7 and float(metrics["aoe_ratio"]) <= 1.0,
				"Seed must stay in the control/AoE bridge corridor")
			_check(int(metrics["crowd_cap"]) == 22 and int(params["larva_count"]) == 6,
				"Seed crowd/larva caps must remain 22/6")
			_check(float(metrics["defense_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"Seed pull/root must contribute a decisive control save")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["biologist_spore_lens"] as Dictionary)["crowd_cap"]) / 18.0
		+ float((metrics["biologist_sample_injector"] as Dictionary)["crowd_cap"]) / 16.0
		+ float((metrics["biologist_symbiote_seed"] as Dictionary)["crowd_cap"]) / 22.0
	) / 3.0
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / 3.2
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= 0.75 and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must preserve the solo-specialist tradeoff" % aoe_score)
	_check(is_equal_approx(crowd_score, 1.0), "all three declared crowd rails must obey their caps")
	_check(defense_seconds >= 3.0 and defense_seconds <= 4.0,
		"trio defense contribution %.3fs must stay inside 3..4s" % defense_seconds)
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var mutated_profiles := {}
	for weapon_id in WEAPONS:
		mutated_profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var sample := (mutated_profiles["biologist_sample_injector"] as Dictionary).duplicate(true)
	((sample["executor"] as Dictionary)["params"] as Dictionary)["extraction_damage"] = 700.0
	mutated_profiles["biologist_sample_injector"] = sample
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, mutated_profiles[weapon_id])
		if float(measured["solo_output"]) < float(row["power_budget_min"]) \
				or float(measured["solo_output"]) > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["biologist_sample_injector"],
		"the balance proof must go red for a runaway extraction coefficient")


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
			weapon_id,
			row["solo_ratio"],
			row["aoe_ratio"],
			row["crowd_cap"],
			row["defense_seconds"],
		])
	if _errors.is_empty():
		print("biologist_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("biologist_balance_test: %s" % error)
	print("biologist_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
