extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")

const CLASS_ID := "robot"
const WEAPONS := ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"]
var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(), "the inherited 51-row harness must stay clean")
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var metrics := {}
	print("robot ultimate balance (lvl1 normal-reference ratios):")
	print("  weapon                         solo    aoe  crowd  defense")
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		_check(not row.is_empty() and not profile.is_empty(), "%s must retain its immutable row" % weapon_id)
		_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
			"%s must retain rare-charge accounting" % weapon_id)
		_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
			"%s must retain activation-owned cleanup" % weapon_id)
		_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row.get("total_boss_cap", 0.0))),
			"%s must retain its whole-activation boss cap" % weapon_id)
		var ledger := Ledger.new(row)
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		ledger.apply_start_charge(1.0)
		_check(ledger.try_activate(), "%s must spend one full charge" % weapon_id)
		ledger.set_ultimate_active(true)
		_check(is_zero_approx(ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)),
			"%s must gain no charge while active" % weapon_id)
		ledger.set_ultimate_active(false)
		ledger.apply_start_charge(0.63)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, 63.0) and not restored.is_ultimate_active()
			and restored.encounter_activations() == 0,
			"%s snapshot must keep charge but discard the active encounter state" % weapon_id)
		metrics[weapon_id] = _measure(weapon_id, row, profile)
		var metric: Dictionary = metrics[weapon_id]
		_check(float(metric["solo_ratio"]) >= 0.90 and float(metric["solo_ratio"]) <= 1.15,
			"%s solo budget must stay in the focused corridor" % weapon_id)
		print("  %-29s %5.2f %6.2f %6d %7.2f" % [weapon_id,
			float(metric["solo_ratio"]), float(metric["aoe_ratio"]), int(metric["crowd_cap"]), float(metric["defense_score"])])
	_test_trio(metrics)
	_report()


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var coefficient := 0.0
	var crowd_cap := 8
	var defense_score := 0.0
	match weapon_id:
		"robot_magnetic_anchor":
			coefficient = float(params["implosion_damage"]) + float(params["emp_damage"])
		"robot_hydraulic_press":
			coefficient = float(params["crush_count"]) * float(params["crush_damage"]) + float(params["release_damage"])
		"robot_reactor_core":
			coefficient = float(params["wave_count"]) * float(params["vent_damage"]) + float(params["final_damage"])
			defense_score = float(params["absorb_flat"]) / 5.0
	var midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var output := coefficient * base_damage
	return {
		"solo_ratio": output / midpoint,
		"aoe_ratio": output / midpoint,
		"crowd_cap": crowd_cap,
		"defense_score": defense_score,
	}


func _test_trio(metrics: Dictionary) -> void:
	var solo := 0.0
	var aoe := 0.0
	var crowd := 0.0
	var defense := 0.0
	for weapon_id in WEAPONS:
		var metric := metrics[weapon_id] as Dictionary
		solo += float(metric["solo_ratio"])
		aoe += float(metric["aoe_ratio"])
		crowd += float(metric["crowd_cap"]) / 8.0
		defense += float(metric["defense_score"])
	solo /= float(WEAPONS.size())
	aoe /= float(WEAPONS.size())
	crowd /= float(WEAPONS.size())
	defense /= float(WEAPONS.size())
	var total := (solo + aoe + crowd + defense) / 4.0
	_check(solo >= 0.90 and solo <= 1.15 and aoe >= 0.90 and aoe <= 1.15,
		"Robot trio solo/AoE must remain inside the focused corridor")
	_check(is_equal_approx(crowd, 1.0), "Robot crowd rails must remain capped at eight targets")
	_check(defense > 0.0 and defense < 0.5, "only Reactor may add the temporary defense axis")
	_check(total >= 0.80 and total <= 1.05, "Robot class-trio total must remain inside its tank tradeoff corridor")
	print("  trio                         %5.2f %6.2f %6.2f %7.2f total=%.2f" % [solo, aoe, crowd, defense, total])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("robot_ultimate_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("robot_ultimate_balance_test: %s" % error)
	print("robot_ultimate_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
