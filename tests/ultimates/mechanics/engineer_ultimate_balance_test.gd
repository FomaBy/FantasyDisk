extends SceneTree

## Engineer-specific consumption of the frozen 51-row charge/power budget.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/engineer_ultimate_balance_test.gd

const PD := preload("res://scripts/progression_data.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Harness := preload("res://scripts/ultimates/balance/ultimate_balance_harness.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "engineer"
const WEAPONS := [
	"engineer_sentry_wrench",
	"engineer_repair_drone",
	"engineer_pressure_mines",
]


func _initialize() -> void:
	var errors: Array[String] = []
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var report := Harness.measure(rows)
	_expect(Harness.violations(report).is_empty(),
		"the inherited 51-row balance harness must remain clean", errors)
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.package_validation_errors().is_empty(),
		"package discovery must remain clean: %s" % [registry.package_validation_errors()], errors)

	print("engineer ultimate balance (base lvl1 normal-weapon references):")
	print("  weapon                         solo      aoe    crowd      ehp   active")
	for weapon_id in WEAPONS:
		_check_weapon(weapon_id, rows, report, registry, errors)

	if not errors.is_empty():
		for error in errors:
			push_error("engineer_ultimate_balance_test: %s" % error)
		print("engineer_ultimate_balance_test: FAIL (%d)" % errors.size())
		quit(1)
		return
	print("engineer_ultimate_balance_test: PASS")
	quit(0)


func _check_weapon(
	weapon_id: String,
	rows: Array,
	report: Array,
	registry,
	errors: Array[String]
) -> void:
	var row := Budget.row_for(rows, CLASS_ID, weapon_id)
	var measured := _report_row(report, weapon_id)
	_expect(not row.is_empty() and not measured.is_empty(),
		"%s must retain one immutable harness row" % weapon_id, errors)
	if row.is_empty() or measured.is_empty():
		return
	_expect(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through its exact ready package" % weapon_id, errors)
	_expect(registry.has_exact_executor_pair(CLASS_ID, weapon_id),
		"%s must own an exact executor pair" % weapon_id, errors)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, weapon_id)
	_expect(str((profile.get("identity", {}) as Dictionary).get("profile_id", "")) \
		== "weapon_ultimate.profile.engineer.%s" % weapon_id,
		"%s must keep the frozen profile identity" % weapon_id, errors)
	_expect(str((profile.get("executor", {}) as Dictionary).get("executor_id", "")) \
		== "weapon_ultimate.executor.engineer.%s" % weapon_id,
		"%s must keep the frozen executor identity" % weapon_id, errors)
	_expect(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"%s must consume the shared rare-charge policy" % weapon_id, errors)
	_expect(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", "")) == "activation_owned",
		"%s must use activation-owned cleanup" % weapon_id, errors)
	_expect(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), float(row["total_boss_cap"])),
		"%s must inherit the fixture's whole-activation boss cap" % weapon_id, errors)
	_expect(str(row["power_archetype"]) == Budget.POWER_ARCHETYPE_CONTROL_SAVE,
		"%s must preserve Engineer's control/save power archetype" % weapon_id, errors)
	_expect(float(row["control_save_seconds"]) >= Budget.CONTROL_SAVE_MIN_SECONDS,
		"%s inherited control/save window must meet the %.1fs floor" \
			% [weapon_id, Budget.CONTROL_SAVE_MIN_SECONDS], errors)

	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var active_seconds := _active_seconds(weapon_id, params)
	_expect(active_seconds >= Budget.CONTROL_SAVE_MIN_SECONDS,
		"%s package lifetime %.2fs must meet the %.1fs control/save floor" \
			% [weapon_id, active_seconds, Budget.CONTROL_SAVE_MIN_SECONDS], errors)
	_check_identity(weapon_id, params, errors)
	_check_charge_contract(weapon_id, row, errors)
	print("  %-29s %7.2f %8.2f %8.2f %8.2f %7.2fs" % [
		weapon_id,
		float(measured["reference_solo_dps"]),
		float(measured["reference_aoe_dps"]),
		_crowd_reference(weapon_id),
		float(measured["reference_ehp"]),
		active_seconds,
	])


func _check_identity(weapon_id: String, params: Dictionary, errors: Array[String]) -> void:
	match weapon_id:
		"engineer_sentry_wrench":
			_expect(int(params.get("volley_count", 0)) == 8 \
				and float(params.get("corridor_half_width", 0.0)) > 0.0 \
				and int(params.get("target_limit", -1)) == 0,
				"sentry must retain uncapped synchronized corridor crossfire", errors)
		"engineer_repair_drone":
			_expect(int(params.get("drone_count", 0)) == 12 \
				and int(params.get("intercept_target_cap", 0)) == 4 \
				and float(params.get("repair_total", 0.0)) > 0.0 \
				and float(params.get("shield", 0.0)) > 0.0,
				"repair drones must retain capped intercept, repair, and shield axes", errors)
		"engineer_pressure_mines":
			_expect(int(params.get("mine_count", 0)) == 16 \
				and int(params.get("seed", 0)) == 1466 \
				and int(params.get("chain_count", 0)) == 2 \
				and is_equal_approx(float(params.get("target_cap_fraction", 0.0)), 0.65),
				"pressure mines must retain deterministic capped local-chain AoE", errors)


func _check_charge_contract(weapon_id: String, row: Dictionary, errors: Array[String]) -> void:
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_expect(ledger.try_activate(), "%s full charge must buy one activation" % weapon_id, errors)
	ledger.set_ultimate_active(true)
	_expect(is_zero_approx(ledger.add_removed_health(
		float(row["reference_solo_dps"]) * Budget.NORMAL_ENCOUNTER_SECONDS)),
		"%s active payoff window must earn no damage charge" % weapon_id, errors)
	_expect(is_zero_approx(ledger.add_taken_health(100.0, 100.0)),
		"%s active payoff window must earn no taken-damage charge" % weapon_id, errors)
	ledger.apply_start_charge(1.0)
	_expect(not ledger.try_activate() and is_equal_approx(ledger.charge, Budget.MAX_CHARGE),
		"%s second activation must refuse without spending charge" % weapon_id, errors)
	var restored := Ledger.new(row)
	restored.apply_snapshot(ledger.to_snapshot())
	_expect(is_equal_approx(restored.charge, Budget.MAX_CHARGE) \
		and not restored.is_ultimate_active() and restored.encounter_activations() == 0,
		"%s snapshot must preserve charge but not transient activation state" % weapon_id, errors)
	_expect(restored.try_activate(),
		"%s restored charge must activate in the fresh encounter" % weapon_id, errors)


func _active_seconds(weapon_id: String, params: Dictionary) -> float:
	match weapon_id:
		"engineer_sentry_wrench":
			return float(params.get("duration", 0.0))
		"engineer_repair_drone":
			return float(params.get("final_pulse_at", 0.0)) \
				+ float(params.get("shield_duration", 0.0))
		"engineer_pressure_mines":
			return float(params.get("finale_delay", 0.0)) \
				+ float(maxi(int(params.get("mine_count", 0)) - 1, 0)) \
					* float(params.get("finale_interval", 0.0)) \
				+ float(params.get("finale_tail", 0.0))
	return 0.0


func _report_row(report: Array, weapon_id: String) -> Dictionary:
	for raw_row in report:
		var row := raw_row as Dictionary
		if str(row.get("class_id", "")) == CLASS_ID \
				and str(row.get("weapon_id", "")) == weapon_id:
			return row
	return {}


func _crowd_reference(weapon_id: String) -> float:
	var weapon := PD.weapon(CLASS_ID, weapon_id)
	var result := PD.estimate_crowd_clear_budget_for_stats(
		CLASS_ID, weapon, 20, PD.base_stats(CLASS_ID), true, {}, false
	)
	return float(result.get("crowd_dps", 0.0))


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)
