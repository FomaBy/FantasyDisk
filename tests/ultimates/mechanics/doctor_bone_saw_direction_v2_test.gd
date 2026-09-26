extends SceneTree

## FAN-3236 / Ultimate Direction v2: every live target inside Emergency
## Surgery's orbit receives the complete six-tick floor. The targeted runtime
## probe also preserves the shared whole-activation boss cap and charge ledger.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const BoneSaw := preload("res://scripts/ultimates/classes/doctor/bone_saw.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "doctor"
const WEAPON_ID := "bone_saw"
const CROWD_COUNTS := [1, 5, 10, 20]
const COUNT_SHAPED_PATTERN := \
	"[A-Za-z0-9_]*(target_cap|target_count|target_limit|targets_per|max_targets|crowd_cap)[A-Za-z0-9_]*"
const EPSILON := 0.001


class FixtureTarget extends Node2D:
	var health := 0.0
	var max_health := 0.0
	var received: Array[Dictionary] = []

	func _init(maximum_health: float) -> void:
		health = maximum_health
		max_health = maximum_health

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class FixtureHost extends Node2D:
	var health := 0.0
	var max_health := 100.0
	var base_damage := 0.0
	var targets: Array[FixtureTarget] = []
	var modifiers: Dictionary = {}

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(_max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[FixtureTarget] = []
		for target in targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		found.sort_custom(func(left: FixtureTarget, right: FixtureTarget) -> bool:
			return left.global_position.distance_squared_to(center) < right.global_position.distance_squared_to(center)
		)
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_repair(target: Node, amount: float) -> float:
		if target != self or health <= 0.0:
			return 0.0
		var before := health
		health = minf(health + amount, max_health)
		return health - before

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		var current := float(modifiers.get(key, 1.0 if operation == "mul" else 0.0))
		modifiers[key] = current * value if operation == "mul" else current + value

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(_value: bool) -> void:
		pass


var _errors: Array[String] = []
var _evidence: Array[Dictionary] = []


func _initialize() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable catalog must remain valid")
	var profile := registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	_test_no_count_caps(params)
	for count in CROWD_COUNTS:
		_test_live_crowd(profile, params, row, count)
	_test_elite(profile, params, row)
	_test_boss_cap(profile, params)
	_test_charge_economy(profile, row)
	_report()


func _test_no_count_caps(params: Dictionary) -> void:
	for source in [BoneSaw.parameter_contract().keys(), params.keys()]:
		for raw_key in source:
			_check(_count_shaped_names(str(raw_key)).is_empty(),
				"bone_saw still carries the count-shaped parameter %s" % str(raw_key))


func _test_live_crowd(profile: Dictionary, params: Dictionary, row: Dictionary, count: int) -> void:
	var host := _host()
	for index in count:
		_add_target(host, Vector2(16.0 + float(index) * 8.0, 0.0), 100000.0)
	var activation := _activation(host, profile)
	_cast(activation, params)
	var hits := 0
	var weakest := INF
	for target in host.targets:
		var applied := _removed(target)
		if applied > 0.0:
			hits += 1
		weakest = minf(weakest, applied)
	var floor_share := Budget.PER_ENEMY_FLOOR_FRACTION \
		* Budget.live_standard_pool(float(row["reference_solo_dps"])) / float(count)
	_evidence.append({"scenario": "%d live" % count, "hits": hits, "weakest": weakest, "floor": floor_share})
	_check(hits == count, "Emergency Surgery must hit all %d live enemies, got %d" % [count, hits])
	_check(weakest >= floor_share - EPSILON,
		"Emergency Surgery weakest live enemy %.2f must clear the %d-enemy floor %.2f" % [
			weakest, count, floor_share,
		])
	host.free()


func _test_elite(profile: Dictionary, params: Dictionary, row: Dictionary) -> void:
	var host := _host()
	var elite := _add_target(host, Vector2(120.0, 0.0), 100000.0)
	elite.add_to_group(Activation.EPIC_GROUP)
	var activation := _activation(host, profile)
	_cast(activation, params)
	var applied := _removed(elite)
	var floor_share := Budget.PER_ENEMY_FLOOR_FRACTION \
		* Budget.live_standard_pool(float(row["reference_solo_dps"]))
	_evidence.append({"scenario": "elite", "hits": int(applied > 0.0), "weakest": applied, "floor": floor_share})
	_check(applied >= floor_share - EPSILON,
		"Emergency Surgery elite damage %.2f must clear the solo floor %.2f" % [applied, floor_share])
	host.free()


func _test_boss_cap(profile: Dictionary, params: Dictionary) -> void:
	var host := _host()
	var boss := _add_target(host, Vector2(120.0, 0.0), 2000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var activation := _activation(host, profile)
	_cast(activation, params)
	var applied := _removed(boss)
	var cap := boss.max_health * float(profile.get("total_boss_cap", 0.0))
	_evidence.append({"scenario": "boss", "hits": boss.received.size(), "weakest": applied, "floor": cap})
	_check(is_equal_approx(applied, cap),
		"Emergency Surgery boss damage %.2f must remain at the whole-activation cap %.2f" % [applied, cap])
	host.free()


func _test_charge_economy(profile: Dictionary, row: Dictionary) -> void:
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"Emergency Surgery must retain the rare-charge ledger")
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate(), "Emergency Surgery must spend one full charge")
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)),
		"Emergency Surgery must not earn charge while active")
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate(), "Emergency Surgery must not activate twice in one encounter")


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, WEAPON_ID))
	host.base_damage = float(derived["damage"])
	return host


func _add_target(host: FixtureHost, position: Vector2, health: float) -> FixtureTarget:
	var target := FixtureTarget.new(health)
	target.global_position = position
	host.add_child(target)
	host.targets.append(target)
	return target


func _activation(host: FixtureHost, profile: Dictionary) -> Activation:
	var params := ((profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary).duplicate(true)
	return Activation.new(host, params, float(profile.get("total_boss_cap", 0.0)))


func _cast(activation: Activation, params: Dictionary) -> void:
	_check(activation.configure_repair(activation.scaled_damage("repair_total", 10.0)),
		"Emergency Surgery must open its existing repair budget")
	var state := {"vitality": 0.0}
	for tick in int(params.get("tick_count", 0)):
		BoneSaw.tick(activation, state, tick)


static func _count_shaped_names(text: String) -> Array[String]:
	var found: Array[String] = []
	var pattern := RegEx.create_from_string(COUNT_SHAPED_PATTERN)
	for raw_match in pattern.search_all(text):
		var name := str((raw_match as RegExMatch).get_string())
		if not found.has(name):
			found.append(name)
	return found


static func _removed(target: FixtureTarget) -> float:
	return target.max_health - target.health


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	for row in _evidence:
		print("  %s hits=%d weakest=%.2f floor=%.2f" % [
			row["scenario"], row["hits"], row["weakest"], row["floor"],
		])
	if _errors.is_empty():
		print("doctor_bone_saw_direction_v2_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("doctor_bone_saw_direction_v2_test: %s" % error)
	print("doctor_bone_saw_direction_v2_test: FAIL (%d)" % _errors.size())
	quit(1)
