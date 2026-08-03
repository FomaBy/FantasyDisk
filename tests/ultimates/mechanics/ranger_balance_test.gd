extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "ranger"
const WEAPONS := ["moon_crossbow", "storm_longbow", "hunter_trap"]
const POWER_SECONDS := (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_check(Harness.violations(report).is_empty(), "the inherited 51-row balance harness must remain clean")
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var solo_total := 0.0
	var aoe_total := 0.0
	print("ranger ultimate balance (normal-weapon references):")
	print("  weapon             solo-ratio  aoe-ratio  crowd  defense")
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
		var metrics := _measure(weapon_id, row, profile)
		solo_total += float(metrics["solo_ratio"])
		aoe_total += float(metrics["aoe_ratio"])
		_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must use its ready profile" % weapon_id)
		_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
			"%s must preserve the immutable boss cap" % weapon_id)
		_check(float(metrics["solo_seconds"]) >= Budget.POWER_SECONDS_MIN
				and float(metrics["solo_seconds"]) <= Budget.POWER_SECONDS_MAX,
			"%s solo window %.2fs must remain in its power corridor" % [weapon_id, metrics["solo_seconds"]])
		if weapon_id == "hunter_trap":
			_check(float(metrics["defense_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
				"Hunter Trap must retain its decisive four-second control save")
		print("  %-18s %8.3f  %8.3f  %5d  %6.2fs" % [
			weapon_id, metrics["solo_ratio"], metrics["aoe_ratio"], metrics["crowd_cap"], metrics["defense_seconds"],
		])
	_check(solo_total / 3.0 >= 0.95 and solo_total / 3.0 <= 1.05,
		"Ranger trio solo average %.3f must remain balanced" % [solo_total / 3.0])
	_check(aoe_total / 3.0 >= 0.95 and aoe_total / 3.0 <= 1.30,
		"Ranger trio AoE average %.3f must remain bounded" % [aoe_total / 3.0])
	_report()


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base_damage := float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo := 0.0
	var aoe := 0.0
	var crowd_cap := 0
	var defense_seconds := 0.0
	match weapon_id:
		"moon_crossbow":
			solo = float(params["wave_count"]) * float(params["mark_damage"]) * base_damage
			aoe = float(params["wave_count"]) * (
				float(params["mark_damage"]) + float(params["split_count"]) * float(params["split_damage"])
			) * base_damage
			crowd_cap = 1 + int(params["split_count"])
		"storm_longbow":
			solo = float(params["beat_count"]) * float(params["storm_damage"]) * base_damage
			aoe = solo
			crowd_cap = int(params["target_limit"])
			defense_seconds = float(params["beat_count"]) * float(params["beat_interval"])
		"hunter_trap":
			solo = float(params["ring_count"]) * float(params["snap_damage"]) * base_damage
			aoe = solo * minf(float(params["target_limit"]), 5.0)
			crowd_cap = int(params["target_limit"])
			defense_seconds = float(params["snare_duration"])
	return {
		"solo_seconds": solo / float(row["reference_solo_dps"]),
		"solo_ratio": solo / (float(row["reference_solo_dps"]) * POWER_SECONDS),
		"aoe_ratio": aoe / (float(row["reference_aoe_dps"]) * POWER_SECONDS),
		"crowd_cap": crowd_cap,
		"defense_seconds": defense_seconds,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ranger_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ranger_balance_test: %s" % error)
	print("ranger_balance_test: FAIL (%d)" % _errors.size())
	quit(1)
