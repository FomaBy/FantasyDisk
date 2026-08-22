extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "thief"
const WEAPONS := ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const DEFENSE_REFERENCE_SECONDS := 0.45
const COUNT_SHAPED_PATTERN := \
	"[A-Za-z0-9_]*(target_cap|target_count|target_limit|mark_limit|coin(?:_[A-Za-z0-9]+)*_count|max_targets|crowd_cap)[A-Za-z0-9_]*"
const COUNT_SHAPED_ALLOWED_SUFFIXES := ["_fraction", "_flat"]
const COUNT_SHAPED_ALLOWED_NAMES := ["coin_wave_count"]

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
	_test_no_count_caps(registry)
	_test_trio(metrics)
	_test_harness_goes_red(registry, rows)
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_output := 0.0
	var aoe_output := 0.0
	var defense_seconds := 0.0
	var crowd_cap := 0
	match weapon_id:
		"thief_coin_pouch":
			var chain := 0.0
			for index in int(params["coin_wave_count"]):
				chain += pow(float(params["damage_falloff"]), float(index))
			solo_output = float(params["coin_damage"]) * base_damage
			aoe_output = chain * float(params["coin_damage"]) * base_damage
			crowd_cap = int(params["coin_wave_count"])
		"thief_shadow_cloak":
			var sequence := 0.0
			for index in int(params["strike_count"]):
				sequence += 1.0 + float(params["escalation"]) * float(index)
			solo_output = sequence * float(params["stab_damage"]) * base_damage
			aoe_output = float(params["strike_count"]) * float(params["stab_damage"]) * base_damage
			crowd_cap = int(params["strike_count"])
		"thief_smoke_bomb":
			solo_output = float(params["pressure_damage"]) * base_damage
			aoe_output = 5.0 * solo_output
			crowd_cap = 5
			defense_seconds = float(params["duration"]) * float(params["evasion_bonus"])
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) * (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / aoe_midpoint,
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _test_weapon(weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary) -> void:
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"]) and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"]])
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	match weapon_id:
		"thief_coin_pouch":
			_check(float(metrics["aoe_ratio"]) >= 1.0 and int(metrics["crowd_cap"]) == 13,
				"Jackpot must own capped ricochet crowd pressure")
			_check(int(params["gold_cap"]) == 4 and int(params["gold_every"]) == 3,
				"Jackpot gold must remain every third hit under the cap")
		"thief_shadow_cloak":
			_check(float(metrics["solo_ratio"]) > 1.0 and int(metrics["crowd_cap"]) == 8,
				"Silent Sentence must remain the escalating solo specialist")
		"thief_smoke_bomb":
			_check(float(metrics["defense_seconds"]) >= 1.0 and int(metrics["crowd_cap"]) == 5,
			"Perfect Heist must retain its defensive dome and capped collapse")


## Only the declared Coin Pouch wave may cap reach; other count-shaped reach
## caps remain forbidden.
func _test_no_count_caps(registry: Registry) -> void:
	var forbidden := RegEx.new()
	forbidden.compile(COUNT_SHAPED_PATTERN)
	_check(not _is_forbidden_count_name("coin_wave_count", forbidden),
		"the approved Coin Pouch wave cap must remain allowed")
	_check(_is_forbidden_count_name("target_count", forbidden),
		"unapproved count-shaped reach caps must remain forbidden")
	for weapon_id in WEAPONS:
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
		var executor = registry.executor_for(CLASS_ID, weapon_id)
		var contract: Dictionary = executor.parameter_contract() if executor is GDScript else {}
		for key in params.keys() + contract.keys():
			var name := str(key)
			if _is_forbidden_count_name(name, forbidden):
				_check(false, "%s must not ship a count-shaped reach cap (%s)" % [weapon_id, name])


func _is_forbidden_count_name(name: String, forbidden: RegEx) -> bool:
	return forbidden.search(name) != null and not _allowed_count_name(name)


func _allowed_count_name(name: String) -> bool:
	if name in COUNT_SHAPED_ALLOWED_NAMES:
		return true
	for suffix in COUNT_SHAPED_ALLOWED_SUFFIXES:
		if name.ends_with(suffix):
			return true
	return false


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := (
		float((metrics["thief_coin_pouch"] as Dictionary)["crowd_cap"]) / 13.0
		+ float((metrics["thief_shadow_cloak"] as Dictionary)["crowd_cap"]) / 8.0
		+ float((metrics["thief_smoke_bomb"] as Dictionary)["crowd_cap"]) / 5.0
	) / 3.0
	var defense_score := _average(metrics, "defense_seconds") / DEFENSE_REFERENCE_SECONDS
	var total_score := (solo_score + aoe_score + crowd_score + defense_score) / 4.0
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= 1.45,
		"trio AoE score %.3f must preserve the three-role corridor" % aoe_score)
	_check(is_equal_approx(crowd_score, 1.0), "all three declared crowd rails must obey their caps")
	_check(defense_score >= 0.90 and defense_score <= 1.10,
		"trio defense score %.3f must stay in the corridor" % defense_score)
	_check(float((metrics["thief_shadow_cloak"] as Dictionary)["solo_ratio"]) > float((metrics["thief_coin_pouch"] as Dictionary)["solo_ratio"])
		and float((metrics["thief_coin_pouch"] as Dictionary)["aoe_ratio"]) > float((metrics["thief_shadow_cloak"] as Dictionary)["aoe_ratio"]),
		"the duelist and crowd ricochet must not converge onto the same role")
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_harness_goes_red(registry: Registry, rows: Array) -> void:
	var profiles := {}
	for weapon_id in WEAPONS:
		profiles[weapon_id] = registry.catalog_profile_for(CLASS_ID, weapon_id)
	var shadow := (profiles["thief_shadow_cloak"] as Dictionary).duplicate(true)
	((shadow["executor"] as Dictionary)["params"] as Dictionary)["stab_damage"] = 200.0
	profiles["thief_shadow_cloak"] = shadow
	var violations: Array[String] = []
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var measured := _measure(weapon_id, row, profiles[weapon_id])
		if float(measured["solo_output"]) < float(row["power_budget_min"]) or float(measured["solo_output"]) > float(row["power_budget_max"]):
			violations.append(weapon_id)
	_check(violations == ["thief_shadow_cloak"],
		"the balance proof must go red for a runaway backstab coefficient")


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
		print("  %s solo=%.3f aoe=%.3f crowd=%d defense=%.2fs" % [weapon_id, row["solo_ratio"], row["aoe_ratio"], row["crowd_cap"], row["defense_seconds"]])
	if _errors.is_empty():
		print("thief_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("thief_balance_test: %s" % error)
	print("thief_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
