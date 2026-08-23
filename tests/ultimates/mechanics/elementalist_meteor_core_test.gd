extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const MeteorCore := preload("res://scripts/ultimates/classes/elementalist/elementalist_meteor_core.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "elementalist"
const WEAPON_ID := "elementalist_meteor_core"
const CROWD_COUNT := 25
const STEP := 0.01

class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(600.0, 0.0)
	var base_damage := 20.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_point - global_position
		var direction := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
		return {"point": global_position + direction * minf(offset.length(), max_range), "direction": direction}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[Node2D] = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
				return left.global_position.distance_squared_to(center) \
					< right.global_position.distance_squared_to(center)
		)
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(_value: bool) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_test_contract_and_economy()
	_holder = Node2D.new()
	root.add_child(_holder)
	await process_frame
	await _test_map_wide_impact_and_crater()
	_holder.queue_free()
	await process_frame
	_report()


func _test_contract_and_economy() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.package_validation_errors().is_empty(),
		"Meteor Core package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var profile := registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	_check(not MeteorCore.parameter_contract().has("crowd_cap"),
		"Meteor Core contract must not expose a count-shaped crowd cap")
	_check(not params.has("crowd_cap"),
		"Meteor Core data must not ship a count-shaped crowd cap")
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.10),
		"Meteor Core must preserve its 10% whole-activation boss cap")
	_check(str((profile["charge"] as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"Meteor Core must preserve the rare charge ledger")


func _test_map_wide_impact_and_crater() -> void:
	var host := FixtureHost.new()
	_holder.add_child(host)
	await process_frame
	var boss := FixtureTarget.new()
	boss.max_health = 1000.0
	boss.health = 1000.0
	boss.global_position = host.aim_point
	boss.add_to_group(Activation.BOSS_GROUP)
	host.add_child(boss)
	host.fixture_targets.append(boss)
	var normals: Array[FixtureTarget] = []
	for index in CROWD_COUNT:
		var target := FixtureTarget.new()
		target.global_position = host.aim_point + Vector2(900.0, 0.0) \
			if index == CROWD_COUNT - 1 \
			else Vector2.RIGHT.rotated(TAU * float(index) / CROWD_COUNT) * (40.0 + index)
		host.add_child(target)
		host.fixture_targets.append(target)
		normals.append(target)

	var controller := Controller.new(host, Registry.new(PD.WEAPONS_BY_CLASS))
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Meteor Core must activate")
	var activation := controller.active_activation()
	_advance(activation, 2.8)
	for target in normals:
		_check(not target.received.is_empty(),
			"Meteor impact must affect every one of %d live normal enemies" % CROWD_COUNT)
	_advance(activation, 5.3)
	_check(boss.health < boss.max_health, "Meteor Core must affect the boss")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"Meteor impact and crater pulses must preserve the 10% boss cap")
	controller.cancel()
	await process_frame
	host.queue_free()
	await process_frame


func _advance(activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("elementalist_meteor_core_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("elementalist_meteor_core_test: %s" % error)
	print("elementalist_meteor_core_test: FAIL (%d)" % _errors.size())
	quit(1)
