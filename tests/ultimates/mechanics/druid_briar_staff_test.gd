extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Runner := preload("res://scripts/ultimates/balance/ultimate_effectiveness_runner.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "druid"
const WEAPON_ID := "briar_staff"
const CROWD_SCENARIOS := {"solo": 1, "crowd_5": 5, "crowd_10": 10, "crowd_20": 20}

var _errors: Array[String] = []


func _initialize() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame

	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var profile := registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	for forbidden in ["target_cap", "impale_target_cap"]:
		_check(not params.has(forbidden), "Briar must not declare count-shaped %s" % forbidden)

	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	var measured: Array = await Runner.new().measure(holder, registry, [row], PD)
	_check(measured.size() == 1, "Briar must produce one live effectiveness row")
	if measured.size() == 1:
		_test_live_row(measured[0] as Dictionary)

	holder.queue_free()
	await process_frame
	_report()


func _test_live_row(row: Dictionary) -> void:
	var scenarios := row["scenarios"] as Dictionary
	var solo_damage := float((scenarios["solo"] as Dictionary)["damage_applied"])
	var per_enemy_floor := Budget.PER_ENEMY_FLOOR_FRACTION * float(row["power_budget_max"])
	for scenario_id in CROWD_SCENARIOS:
		var enemy_count: int = CROWD_SCENARIOS[scenario_id]
		var scenario := scenarios[scenario_id] as Dictionary
		var per_enemy_damage := float(scenario["damage_applied"]) / float(enemy_count)
		_check(is_equal_approx(float(scenario["targets_struck"]), float(enemy_count)),
			"%s must strike all %d live enemies" % [scenario_id, enemy_count])
		_check(is_equal_approx(per_enemy_damage, solo_damage),
			"%s must give every enemy the full Briar pulse sequence" % scenario_id)
		_check(per_enemy_damage >= per_enemy_floor,
			"%s per-enemy damage %.2f must keep the %.2f floor" % [
				scenario_id, per_enemy_damage, per_enemy_floor,
			])

	var elite := scenarios["elite"] as Dictionary
	var boss := scenarios["boss"] as Dictionary
	_check(is_equal_approx(float(elite["control_seconds"]), 2.25),
		"elite control shaping must remain 45% of the five-second root")
	_check(is_equal_approx(float(boss["control_seconds"]), 1.0),
		"boss control shaping must remain 20% of the five-second root")
	_check(float(boss["damage_applied"]) > 0.0
		and float(boss["boss_cap_ratio"]) <= 1.0,
		"the boss must take damage without exceeding the whole-activation cap")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("druid_briar_staff_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("druid_briar_staff_test: %s" % error)
	quit(1)
