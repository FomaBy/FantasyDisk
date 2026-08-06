extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "ranger"
const WEAPONS := ["moon_crossbow", "storm_longbow", "hunter_trap"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
# Ranger is a burst archetype: the class ultimate declares no duration, so its
# defensive contribution is the shared control window the trio actually leaves
# on the field, normalized against its own class reference rather than a
# melee-grade one.
const DEFENSE_REFERENCE_SECONDS := 2.0

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


## Solo is one silhouette alone; AoE is the declared crowd ceiling — the full
## split rail, the full corridor rank decay, the full trap chain.
func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) \
		* float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_coefficient := 0.0
	var crowd_multiplier := 1.0
	var defense_seconds := 0.0
	var crowd_cap := 0
	match weapon_id:
		"moon_crossbow":
			solo_coefficient = float(params["wave_count"]) * float(params["bolt_damage"])
			crowd_multiplier = 1.0 + float(params["split_count"]) * float(params["split_ratio"])
			crowd_cap = int(params["split_count"]) + 1
		"storm_longbow":
			solo_coefficient = float(params["beat_count"]) * float(params["beat_damage"])
			# A lone body is always rank zero; a full corridor adds the decayed ranks
			# behind it, which is what bounds the sweep no matter how deep it is.
			for rank in int(params["crowd_cap"]):
				crowd_multiplier += pow(float(params["beat_falloff"]), float(rank))
			crowd_multiplier -= 1.0
			defense_seconds = float(params["slow_duration"])
			crowd_cap = int(params["crowd_cap"])
		"hunter_trap":
			solo_coefficient = float(params["ring_count"]) * float(params["snap_damage"]) \
				+ float(params["closure_damage"])
			crowd_multiplier = 1.0 + float(int(params["crowd_cap"]) - 1) * float(params["net_ratio"])
			defense_seconds = float(params["lock_duration"])
			crowd_cap = int(params["crowd_cap"])
	var solo_output := solo_coefficient * base_damage
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": solo_output * crowd_multiplier,
		"aoe_ratio": solo_output * crowd_multiplier / aoe_midpoint,
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	_check(
		float(metrics["solo_output"]) >= float(row["power_budget_min"])
			and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		]
	)
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	match weapon_id:
		"moon_crossbow":
			# Share of a full split wave that still lands on the marked prey.
			var direct_share := float(metrics["solo_output"]) \
				/ maxf(float(metrics["aoe_output"]), 0.01)
			_check(direct_share >= 0.70,
				"the hunt must stay mark-led instead of flattening into a crowd clear")
			_check(float(metrics["aoe_ratio"]) >= 0.85 and float(metrics["aoe_ratio"]) <= 1.05,
				"Moon Hunt must own the solo-leading corridor")
			_check(int(params["split_count"]) == 4 and int(metrics["crowd_cap"]) == 5,
				"the moon split rail must remain one mark plus four neighbours")
			_check(is_zero_approx(float(metrics["defense_seconds"])),
				"Moon Hunt must buy its damage without a control window")
		"storm_longbow":
			_check(float(metrics["aoe_ratio"]) >= 0.95 and float(metrics["aoe_ratio"]) <= 1.15,
				"Storm Eye must own the corridor sweep corridor")
			_check(int(metrics["crowd_cap"]) == 8 and float(params["beat_falloff"]) < 0.5,
				"the corridor rank decay must stay bounded at 8/<0.5")
			_check(float(metrics["defense_seconds"]) >= 2.5,
				"the storm push must leave a readable slow window")
		"hunter_trap":
			_check(float(metrics["aoe_ratio"]) >= 0.95 and float(metrics["aoe_ratio"]) <= 1.15,
				"Grand Trap must stay in the crowd-hold corridor")
			_check(int(metrics["crowd_cap"]) == 10 and float(params["net_ratio"]) <= 0.15,
				"the chain-net share must remain the declared anti-focus rail")
			# Ranger prices its ultimates as burst, so the shared control-save bar
			# does not apply; the trap still has to carry a decisive hold window.
			_check(float(metrics["defense_seconds"]) >= 3.0,
				"the jaw lock must contribute a decisive hold window")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["moon_crossbow"] as Dictionary)["crowd_cap"]) / 5.0
		+ float((metrics["storm_longbow"] as Dictionary)["crowd_cap"]) / 8.0
		+ float((metrics["hunter_trap"] as Dictionary)["crowd_cap"]) / 10.0
	) / 3.0
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0), "all three declared crowd rails must obey their caps")
	_check(defense_score >= TRIO_MIN and defense_score <= TRIO_MAX,
		"trio control score %.3f must stay inside %.2f..%.2f" % [defense_score, TRIO_MIN, TRIO_MAX])
	_check(
		float((metrics["moon_crossbow"] as Dictionary)["solo_ratio"])
			> float((metrics["hunter_trap"] as Dictionary)["solo_ratio"])
		and float((metrics["hunter_trap"] as Dictionary)["aoe_ratio"])
			> float((metrics["moon_crossbow"] as Dictionary)["aoe_ratio"]),
		"the mark hunter and the crowd trap must not converge onto the same role"
	)
	_check(
		float((metrics["hunter_trap"] as Dictionary)["defense_seconds"])
			> float((metrics["storm_longbow"] as Dictionary)["defense_seconds"])
		and is_zero_approx(float((metrics["moon_crossbow"] as Dictionary)["defense_seconds"])),
		"the trap must own the class hold, the storm the shorter push, the hunt none"
	)
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var mutated_profiles := {}
	for weapon_id in WEAPONS:
		mutated_profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var storm := (mutated_profiles["storm_longbow"] as Dictionary).duplicate(true)
	((storm["executor"] as Dictionary)["params"] as Dictionary)["beat_damage"] = 60.0
	mutated_profiles["storm_longbow"] = storm
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, mutated_profiles[weapon_id])
		if float(measured["solo_output"]) < float(row["power_budget_min"]) \
				or float(measured["solo_output"]) > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["storm_longbow"],
		"the balance proof must go red for a runaway corridor coefficient")


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
		print("ranger_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ranger_balance_test: %s" % error)
	print("ranger_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
