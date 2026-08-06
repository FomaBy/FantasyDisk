extends SceneTree

## FAN-2131: every Berserk coefficient is measured against its frozen budget
## row, the trio keeps its solo/AoE/crowd corridor, and the three weapons stay
## in distinct roles.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/berserk_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Sword := preload("res://scripts/ultimates/classes/berserk/sword.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "berserk"
const WEAPONS := ["sword", "axe", "hammer"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
# Every Berserk ultimate is a melee crowd swing: the declared solo coefficient
# lands on roughly three bodies inside its own shape.
const AOE_MULTIPLIER := 3.0
const DECLARED_CROWD_CAPS := {"sword": 24, "axe": 18, "hammer": 20}

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
	_test_roles(registry)
	_test_proof_goes_red(rows, registry)
	_report(metrics)


## The sword coefficient is not a free number: it is however many blade bites
## the declared round-robin actually clears through its own cooldown gate.
static func landed_blade_hits(params: Dictionary) -> int:
	var blades := int(params["blade_count"])
	var release := float(params["release_delay"])
	var interval := float(params["sweep_interval"])
	var cooldown := float(params["blade_hit_cooldown"])
	var last := {}
	var landed := 0
	for index in int(params["sweep_count"]):
		var blade := index % blades
		var elapsed := release + float(index) * interval
		if not Sword.blade_ready(last.get(blade), elapsed, cooldown):
			continue
		last[blade] = elapsed
		landed += 1
	return landed


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var derived := PD.derived_parameters(
		PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, weapon_id)
	)
	var base_damage := float(derived["damage"]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var coefficient := 0.0
	match weapon_id:
		"sword":
			coefficient = float(params["blade_damage"]) * float(landed_blade_hits(params)) \
				+ float(params["cross_damage"])
		"axe":
			coefficient = float(params["outbound_damage"]) + float(params["return_damage"]) \
				+ float(params["execute_damage"])
		"hammer":
			coefficient = float(params["cardinal_damage"]) + float(params["diagonal_damage"]) \
				+ float(params["quake_damage"])
	var solo_output := coefficient * base_damage
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"power_seconds": solo_output / float(row["reference_solo_dps"]),
		"aoe_output": solo_output * AOE_MULTIPLIER,
		"aoe_ratio": solo_output * AOE_MULTIPLIER / aoe_midpoint,
		"crowd_cap": int(params["crowd_cap"]),
		"lifetime": float(params["lifetime"]),
	}


func _test_weapon(weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary) -> void:
	_check(float(metrics["solo_output"]) >= float(row["power_budget_min"])
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], row["power_budget_min"], row["power_budget_max"],
		])
	_check(float(metrics["power_seconds"]) >= Budget.POWER_SECONDS_MIN
		and float(metrics["power_seconds"]) <= Budget.POWER_SECONDS_MAX,
		"%s one-activation power %.2fs must stay inside %.1f..%.1f" % [
			weapon_id, metrics["power_seconds"], Budget.POWER_SECONDS_MIN, Budget.POWER_SECONDS_MAX,
		])
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	_check(int(metrics["crowd_cap"]) == int(DECLARED_CROWD_CAPS[weapon_id]),
		"%s must keep the authorized crowd cap %s" % [weapon_id, DECLARED_CROWD_CAPS[weapon_id]])


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := 0.0
	for weapon_id in WEAPONS:
		crowd_score += float((metrics[weapon_id] as Dictionary)["crowd_cap"]) \
			/ float(DECLARED_CROWD_CAPS[weapon_id])
	crowd_score /= float(WEAPONS.size())
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0), "declared crowd caps must stay hard-capped")
	var total_score := (solo_score + aoe_score + crowd_score) / 3.0
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


## The three weapons must not converge on one role: sword owns the widest and
## longest crowd window, axe the heaviest single contact plus the only execute,
## hammer the shortest and most concentrated burst.
func _test_roles(registry: Registry) -> void:
	var sword := _params(registry, "sword")
	var axe := _params(registry, "axe")
	var hammer := _params(registry, "hammer")
	_check(int(sword["crowd_cap"]) > int(axe["crowd_cap"])
		and int(sword["crowd_cap"]) > int(hammer["crowd_cap"])
		and float(sword["lifetime"]) > float(axe["lifetime"]),
		"the whirlwind must remain the widest and longest crowd option")
	_check(float(axe["return_damage"]) > float(sword["cross_damage"])
		and float(axe["return_damage"]) > float(hammer["quake_damage"])
		and float(axe["execute_damage"]) > 0.0,
		"the loop must remain the heaviest single-contact execute option")
	_check(float(hammer["lifetime"]) < float(axe["lifetime"])
		and float(hammer["stagger_impulse"]) > 0.0,
		"the rift must remain the shortest staggering burst")


func _test_proof_goes_red(rows: Array, registry: Registry) -> void:
	var row := Budget.row_for(rows, CLASS_ID, "sword")
	var profile := registry.catalog_profile_for(CLASS_ID, "sword")
	var mutated := profile.duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["blade_damage"] = 99.0
	var measured := _measure("sword", row, mutated)
	_check(float(measured["solo_output"]) > float(row["power_budget_max"]),
		"the balance proof must go red for an unbounded blade coefficient")


func _params(registry: Registry, weapon_id: String) -> Dictionary:
	var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
	return (profile["executor"] as Dictionary)["params"] as Dictionary


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
		print("  %s solo=%.3f aoe=%.3f power=%.2fs crowd=%d lifetime=%.2fs" % [
			weapon_id, row["solo_ratio"], row["aoe_ratio"], row["power_seconds"],
			row["crowd_cap"], row["lifetime"],
		])
	if _errors.is_empty():
		print("berserk_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("berserk_balance_test: %s" % error)
	quit(1)
