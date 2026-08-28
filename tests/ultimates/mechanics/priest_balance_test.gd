extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
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
	_test_direction_v2(registry, rows)
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
	var floor_output := 0.0
	var defense_seconds := 0.0
	match weapon_id:
		"priest_reliquary":
			var rings := float(params["first_ring_damage"]) + float(params["sanctify_damage"]) \
				+ float(params["pillar_damage"])
			solo_output = rings * base_damage
			var sanctum_weight := 0.0
			for index in 5:
				sanctum_weight += pow(float(params["crowd_falloff"]), float(index))
			aoe_output = rings * base_damage * sanctum_weight
			floor_output = rings * base_damage * float(params["crowd_floor"])
			defense_seconds = float(params["lifetime"]) - float(params["pillar_at"])
		"priest_censer":
			# The counter uses observed prevented HP, but its cap expresses the
			# maximum priced output. No incoming hit means no counter damage.
			solo_output = float(params["counter_damage_cap"]) * base_damage
			var counter_weight := 0.0
			for index in 5:
				counter_weight += pow(float(params["counter_falloff"]), float(index))
			aoe_output = solo_output * counter_weight
			floor_output = solo_output * float(params["counter_floor"])
			defense_seconds = float(params["lifetime"])
		"priest_chime":
			var chain := 0.0
			for index in 5:
				chain += pow(float(params["chain_falloff"]), float(index))
			solo_output = (float(params["interrupt_damage"]) + float(params["chain_damage"])) * base_damage
			aoe_output = (float(params["interrupt_damage"]) * 5.0 + float(params["chain_damage"]) * chain) * base_damage
			floor_output = (float(params["interrupt_damage"]) + float(params["chain_damage"])
				* float(params["chain_floor"])) * base_damage
			defense_seconds = float(params["lifetime"]) - float(params["third_toll_at"])
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / aoe_midpoint,
		"floor_share": floor_output / solo_output,
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
			_check(float(params["crowd_floor"]) == 0.4 and float(params["heal_ratio"]) == 0.35,
				"Reliquary must retain rank falloff, its v2 floor and actual-damage heal rail")
			_check(float(metrics["defense_seconds"]) >= 3.0,
				"Reliquary shield must remain live for a meaningful post-pillar window")
		"priest_censer":
			_check(float(params["counter_floor"]) == 0.41 and float(params["stored_ratio"]) == 0.65,
				"Censer must remain an observed-prevention counter with a v2 floor")
			_check(float(metrics["defense_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"Censer mitigation must remain the trio's decisive defense save")
		"priest_chime":
			_check(float(params["chain_floor"]) == 0.27,
				"Chime must retain its falling chain with a v2 floor")
			_check(float(metrics["defense_seconds"]) >= 2.0,
				"Chime must leave a visible lethal-prevention window after the third toll")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + defense_score) / 3.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= 0.90 and aoe_score <= 1.35,
		"trio AoE score %.3f must preserve the defensive tradeoff" % aoe_score)
	for weapon_id in WEAPONS:
		var floor_share := float((metrics[weapon_id] as Dictionary)["floor_share"])
		_check(floor_share >= 0.40 and floor_share <= 0.42,
			"%s per-enemy share %.3f must keep the bounded v2 floor" % [weapon_id, floor_share])
	_check(defense_seconds >= 4.2 and defense_seconds <= 4.6,
		"trio defense contribution %.3fs must stay inside 4.2..4.6s" % defense_seconds)
	_check(float((metrics["priest_censer"] as Dictionary)["defense_seconds"])
			> float((metrics["priest_chime"] as Dictionary)["defense_seconds"])
		and float((metrics["priest_chime"] as Dictionary)["aoe_ratio"])
			> float((metrics["priest_censer"] as Dictionary)["aoe_ratio"]),
		"the protection counter and bell chain must not converge onto one role")
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


## The per-enemy floor is derived independently from the shared corridor. The
## guaranteed channel stays constant at any crowd size; count only multiplies
## the total map-wide contribution and must never dilute one silhouette.
func _test_direction_v2(registry: Registry, rows: Array) -> void:
	_check(not Harness.COVERAGE_MIGRATION_ALLOWLIST.has(CLASS_ID)
			and Harness.COVERAGE_V2_CLASSES.has(CLASS_ID),
		"Priest must leave the coverage allowlist and enter the v2 ledger")
	var prohibited := [
		"radius", "crowd_cap", "counter_radius", "counter_target_cap",
		"interrupt_radius", "chain_radius", "chain_targets",
	]
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var params := ((profile["executor"] as Dictionary)["params"] as Dictionary)
		for key in prohibited:
			_check(not params.has(key), "%s must not keep count/radius reach rail %s" % [weapon_id, key])
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var weapon := PD.weapon(CLASS_ID, weapon_id)
		var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
		var base_damage := float(derived[str(weapon["damage_parameter"])]) \
			* float(derived["ultimate_multiplier"])
		var guaranteed := 0.0
		match weapon_id:
			"priest_reliquary":
				guaranteed = (
					float(params["first_ring_damage"]) + float(params["sanctify_damage"])
					+ float(params["pillar_damage"])
				) * float(params.get("crowd_floor", 0.0)) * base_damage
			"priest_censer":
				guaranteed = float(params["counter_damage_cap"]) \
					* float(params.get("counter_floor", 0.0)) * base_damage
			"priest_chime":
				guaranteed = (
					float(params["interrupt_damage"]) + float(params["chain_damage"])
					* float(params.get("chain_floor", 0.0))
				) * base_damage
		var floor_damage := float(row["power_budget_min"]) * Budget.PER_ENEMY_FLOOR_FRACTION
		for count in [1, 5, 10, 20, 100, 1000]:
			_check(guaranteed >= floor_damage,
				"%s guarantees %.2f below %.2f at %d enemies" % [
					weapon_id, guaranteed, floor_damage, count,
				])


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
		print("  %s solo=%.3f aoe=%.3f floor=%.3f defense=%.2fs" % [
			weapon_id, row["solo_ratio"], row["aoe_ratio"], row["floor_share"], row["defense_seconds"],
		])
	if _errors.is_empty():
		print("priest_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("priest_balance_test: %s" % error)
	print("priest_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
