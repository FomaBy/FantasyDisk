extends SceneTree

## Deterministic Ultimate Direction V2 proof for the Dark Mage trio. Every
## live enemy receives the declared floor; the focused Wand collapse is a
## bounded identity bonus, never a count-shaped reach gate.

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "dark_mage"
const WEAPONS := ["dark_book", "cursed_skull", "dark_wand"]
const CROWD_COUNTS := [1, 2, 5, 10, 20, 100, 1000]
const COUNT_SHAPED_PATTERN := \
	"[A-Za-z0-9_]*(target_cap|target_count|target_limit|targets_per|max_targets|crowd_cap|chain_cap|transfer_cap|reflection_cap|kill_burst_cap)[A-Za-z0-9_]*"
const COUNT_SHAPED_ALLOWED_SUFFIXES := ["_fraction", "_flat"]

var _errors: Array[String] = []


func _initialize() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var harness := Harness.measure(rows)
	_check(Harness.violations(harness).is_empty(),
		"the inherited 51-row balance harness must remain clean")
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.package_validation_errors().is_empty(),
		"Dark Mage package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var metrics := {}
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
		metrics[weapon_id] = _measure(weapon_id, profile)
		_test_weapon(weapon_id, row, profile, metrics[weapon_id] as Dictionary)
		_test_per_enemy_floor(weapon_id, row, metrics[weapon_id] as Dictionary)
		_check_charge_contract(weapon_id, row)
	_test_no_count_caps(registry)
	_test_trio(metrics)
	_test_goes_red(registry, rows)
	_report(metrics)


static func _base_damage(weapon_id: String) -> float:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	return float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])


func _measure(weapon_id: String, profile: Dictionary) -> Dictionary:
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var base := _base_damage(weapon_id)
	var damage := 0.0
	var focused_damage := 0.0
	var control_seconds := 0.0
	match weapon_id:
		"dark_book":
			damage = base * float(params.get("original_damage", 0.0))
			focused_damage = damage
		"cursed_skull":
			damage = base * (float(params.get("curse_damage", 0.0)) \
				* float(params.get("pulse_count", 0)) + float(params.get("harvest_damage", 0.0)))
			focused_damage = damage
			control_seconds = float(params.get("curse_duration", 0.0)) \
				* (1.0 - float(params.get("outgoing_damage_multiplier", 1.0)))
		"dark_wand":
			damage = base * float(params.get("base_collapse_damage", 0.0))
			focused_damage = damage * (1.0 + float(params.get("focus_collapse_bonus", 0.0)))
	return {
		"damage": damage,
		"focused_damage": focused_damage,
		"control_seconds": control_seconds,
		"solo_effect": damage,
		"lifetime": float(params.get("lifetime", 0.0)),
	}


func _test_weapon(weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary) -> void:
	_check(str(row.get("coverage", "")) == Budget.COVERAGE_ALL_ENEMIES,
		"%s must retain the all-enemies V2 coverage contract" % weapon_id)
	_check(registry_resolution(profile, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id)
	_check(float(metrics["solo_effect"]) >= float(row["power_budget_min"])
		and float(metrics["solo_effect"]) <= float(row["power_budget_max"]),
		"%s solo output %.2f must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_effect"], row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.11)
		and is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must retain Dark Mage's immutable 11%% whole-activation boss cap" % weapon_id)
	if weapon_id == "cursed_skull":
		_check(is_equal_approx(float(metrics["control_seconds"]), 1.05),
			"Crown must retain 35%% outgoing reduction for its declared three seconds")
	if weapon_id == "dark_wand":
		_check(float(metrics["focused_damage"]) > float(metrics["damage"]),
			"Wand must keep one bounded focus bonus above the universal floor")


func registry_resolution(_profile: Dictionary, weapon_id: String) -> String:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	return registry.resolution_source(CLASS_ID, weapon_id)


## The minimum damage channel is delivered to every target. The shared live
## pool scales with enemy count, so proving all official pressure counts proves
## that neither map size nor crowd size can erase a nontrivial floor.
func _test_per_enemy_floor(weapon_id: String, row: Dictionary, metrics: Dictionary) -> void:
	var pool := Budget.live_standard_pool(float(row["reference_solo_dps"]))
	for count in CROWD_COUNTS:
		var required := Budget.PER_ENEMY_FLOOR_FRACTION * pool / float(count)
		_check(float(metrics["damage"]) >= required - 0.001,
			"%s leaves an enemy at %.2f against the %d-enemy floor %.2f" % [
				weapon_id, metrics["damage"], count, required,
			])


func _test_no_count_caps(registry: Registry) -> void:
	for weapon_id in WEAPONS:
		var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
		var executor = registry.executor_for(CLASS_ID, weapon_id)
		var contract: Dictionary = executor.parameter_contract() if executor is GDScript else {}
		var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
		for source in [contract.keys(), params.keys()]:
			for raw_key in source:
				_check(_count_shaped_names(str(raw_key)).is_empty(),
					"%s still carries count-shaped reach parameter %s" % [weapon_id, raw_key])


static func _count_shaped_names(text: String) -> Array[String]:
	var found: Array[String] = []
	var pattern := RegEx.create_from_string(COUNT_SHAPED_PATTERN)
	for raw_match in pattern.search_all(text):
		var name := str((raw_match as RegExMatch).get_string())
		var permitted := false
		for suffix in COUNT_SHAPED_ALLOWED_SUFFIXES:
			if name.ends_with(suffix):
				permitted = true
				break
		if not permitted and not found.has(name):
			found.append(name)
	return found


func _test_trio(metrics: Dictionary) -> void:
	var book := metrics["dark_book"] as Dictionary
	var skull := metrics["cursed_skull"] as Dictionary
	var wand := metrics["dark_wand"] as Dictionary
	_check(float(book["damage"]) > 0.0 and float(skull["control_seconds"]) > 0.0
		and float(wand["focused_damage"]) > float(wand["damage"]),
		"Book, Crown and Wand must retain distinct floor, control and focus roles")
	var lifetimes := [float(book["lifetime"]), float(skull["lifetime"]), float(wand["lifetime"])]
	lifetimes.sort()
	_check(lifetimes == [3.1, 3.6, 3.9],
		"Dark Mage must keep three short, distinct V2 mechanics windows")


func _test_goes_red(registry: Registry, rows: Array) -> void:
	var book: Dictionary = registry.catalog_profile_for(CLASS_ID, "dark_book").duplicate(true)
	((book["executor"] as Dictionary)["params"] as Dictionary)["original_damage"] = 100.0
	var row := Budget.row_for(rows, CLASS_ID, "dark_book")
	var measured := _measure("dark_book", book)
	_check(float(measured["solo_effect"]) > float(row["power_budget_max"]),
		"the balance proof must go red for a runaway Book coefficient")


func _check_charge_contract(weapon_id: String, row: Dictionary) -> void:
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate(), "%s full charge must buy one activation" % weapon_id)
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(float(row["reference_solo_dps"]) * 35.0)),
		"%s active effect must not earn damage charge" % weapon_id)
	_check(is_zero_approx(ledger.add_taken_health(100.0, 100.0)),
		"%s active effect must not earn taken-damage charge" % weapon_id)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s floor=%.2f focus=%.2f control=%.2fs lifetime=%.2fs" % [
			weapon_id, row["damage"], row["focused_damage"], row["control_seconds"], row["lifetime"],
		])
	if _errors.is_empty():
		print("dark_mage_ultimate_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_ultimate_balance_test: %s" % error)
	print("dark_mage_ultimate_balance_test: FAIL (%d)" % _errors.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
