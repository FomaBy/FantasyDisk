extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "sniper"
const WEAPONS := [
	"sniper_deadeye_rifle",
	"sniper_spotter_scope",
	"sniper_shatter_rounds",
]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
# A long-range burst class buys reach with control: only the kill zone clears
# the shared decisive-save bar, and the trio is normalized against that lower
# class reference instead of a melee-grade one.
const DEFENSE_REFERENCE_SECONDS := 2.4

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
	var solo_output := 0.0
	var aoe_output := 0.0
	var defense_seconds := 0.0
	var crowd_cap := 0
	match weapon_id:
		"sniper_deadeye_rifle":
			# Solo: the lone body on the rail is always the headshot. Crowd: the
			# headshot plus the declared penetration decay behind it.
			var headshot := float(params["shot_damage"]) * float(params["headshot_multiplier"])
			var penetration := 0.0
			for depth in range(1, int(params["pierce_limit"])):
				penetration += pow(float(params["penetration_falloff"]), float(depth))
			solo_output = headshot * base_damage
			aoe_output = (headshot + penetration * float(params["shot_damage"])) * base_damage
			crowd_cap = int(params["pierce_limit"])
		"sniper_spotter_scope":
			# Solo: only `max_locks_per_target` locks may stack on one silhouette;
			# the surplus is never armed. Crowd: all nine locks find a body.
			solo_output = float(params["max_locks_per_target"]) \
				* float(params["strike_damage"]) * base_damage
			aoe_output = float(params["lock_count"]) * float(params["strike_damage"]) * base_damage
			defense_seconds = float(params["suppression_duration"])
			crowd_cap = int(params["lock_count"])
		"sniper_shatter_rounds":
			# Solo: every trajectory stops at its entry impact and sprays nothing.
			# Crowd: the full ricochet decay plus one shard per impact.
			var chain := 0.0
			for hop in int(params["ricochet_jumps"]) + 1:
				chain += pow(float(params["ricochet_falloff"]), float(hop))
			solo_output = float(params["trajectory_count"]) \
				* float(params["impact_damage"]) * base_damage
			aoe_output = float(params["trajectory_count"]) * chain \
				* float(params["impact_damage"]) \
				* (1.0 + float(params["shard_count"]) * float(params["shard_ratio"])) * base_damage
			defense_seconds = float(params["stagger_duration"])
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
		"sniper_deadeye_rifle":
			# Share of a full four-body rail that still lands on the headshot.
			var direct_share := float(metrics["solo_output"]) \
				/ maxf(float(metrics["aoe_output"]), 0.01)
			_check(direct_share >= 0.75,
				"the rail must stay duel-led instead of flattening into a line clear")
			_check(float(metrics["aoe_ratio"]) >= 0.50 and float(metrics["aoe_ratio"]) <= 0.65,
				"Deadeye must own the solo-leading corridor")
			_check(int(metrics["crowd_cap"]) == 4
					and is_equal_approx(float(params["headshot_multiplier"]), 1.5),
				"Deadeye pierce/headshot rails must remain 4/1.5")
		"sniper_spotter_scope":
			_check(float(metrics["aoe_ratio"]) >= 1.15 and float(metrics["aoe_ratio"]) <= 1.40,
				"Spotter must own the AoE-leading corridor")
			_check(int(metrics["crowd_cap"]) == 9 and int(params["max_locks_per_target"]) == 3,
				"Spotter lock/stack caps must remain 9/3")
			_check(float(metrics["defense_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"the kill-zone suppression must contribute a decisive control save")
		"sniper_shatter_rounds":
			_check(float(metrics["aoe_ratio"]) >= 1.05 and float(metrics["aoe_ratio"]) <= 1.30,
				"Shatter must stay in the crowd-clear corridor")
			_check(int(metrics["crowd_cap"]) == 15 and int(params["trajectory_count"]) == 5,
				"Shatter crowd/trajectory caps must remain 15/5")
			_check(is_equal_approx(float(params["cap_fraction"]), 0.4)
					and is_zero_approx(float(params["cap_flat"])),
				"the anti-focus per-target rail must remain the declared 40% share")


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["sniper_deadeye_rifle"] as Dictionary)["crowd_cap"]) / 4.0
		+ float((metrics["sniper_spotter_scope"] as Dictionary)["crowd_cap"]) / 9.0
		+ float((metrics["sniper_shatter_rounds"] as Dictionary)["crowd_cap"]) / 15.0
	) / 3.0
	var defense_seconds := _average(metrics, "defense_seconds")
	var defense_score := defense_seconds / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0), "all three declared crowd rails must obey their caps")
	_check(defense_seconds >= 2.2 and defense_seconds <= 2.6,
		"trio defense contribution %.3fs must stay inside 2.2..2.6s" % defense_seconds)
	_check(
		float((metrics["sniper_deadeye_rifle"] as Dictionary)["solo_ratio"])
			> float((metrics["sniper_shatter_rounds"] as Dictionary)["solo_ratio"])
		and float((metrics["sniper_shatter_rounds"] as Dictionary)["aoe_ratio"])
			> float((metrics["sniper_deadeye_rifle"] as Dictionary)["aoe_ratio"]),
		"the duelist and the crowd sweep must not converge onto the same role"
	)
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var mutated_profiles := {}
	for weapon_id in WEAPONS:
		mutated_profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var spotter := (mutated_profiles["sniper_spotter_scope"] as Dictionary).duplicate(true)
	((spotter["executor"] as Dictionary)["params"] as Dictionary)["strike_damage"] = 200.0
	mutated_profiles["sniper_spotter_scope"] = spotter
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, mutated_profiles[weapon_id])
		if float(measured["solo_output"]) < float(row["power_budget_min"]) \
				or float(measured["solo_output"]) > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["sniper_spotter_scope"],
		"the balance proof must go red for a runaway sky-lock coefficient")


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
		print("sniper_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_balance_test: %s" % error)
	print("sniper_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
