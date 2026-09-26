extends SceneTree

const Anchor := preload("res://scripts/ultimates/classes/robot/robot_magnetic_anchor.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const PROFILE_PATH := "res://data/ultimates/classes/robot/robot_magnetic_anchor.json"
const SCRIPT_PATH := "res://scripts/ultimates/classes/robot/robot_magnetic_anchor.gd"
const CLASS_ID := "robot"
const WEAPON_ID := "robot_magnetic_anchor"
const TARGET_COUNT := 20


class Target extends Node2D:
	var health := 100000.0
	var max_health := 100000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var modifiers: Dictionary = {}
	var events: Array[String] = []

	func ultimate_host_context() -> Dictionary:
		return {"damage": 1000.0, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * minf(max_range, 200.0), "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		var current := float(modifiers.get(key, 1.0 if operation == "mul" else 0.0))
		modifiers[key] = current * value if operation == "mul" else current + value

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(event_id: String, _payload: Dictionary) -> Node:
		events.append(event_id)
		var marker := Node2D.new()
		add_child(marker)
		return marker

	func ultimate_host_set_active(_value: bool) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_test_profile_keeps_identity_and_safety_contracts()
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_test_every_target_receives_anchor_effect()
	_holder.queue_free()
	await process_frame
	_report()


func _test_profile_keeps_identity_and_safety_contracts() -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	_check(document is Dictionary, "Magnetic Anchor profile must remain readable")
	if not document is Dictionary:
		return
	var profile := document as Dictionary
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	_check(not params.has("target_limit"), "Magnetic Anchor profile must not carry a target count cap")
	_check(not Anchor.parameter_contract().has("target_limit"),
		"Magnetic Anchor parameter contract must not carry a target count cap")
	_check(not FileAccess.get_file_as_string(SCRIPT_PATH).contains("target_limit"),
		"Magnetic Anchor executor must not declare or pass a target count cap")
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.08),
		"Magnetic Anchor must keep its 8% whole-activation boss cap")
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"Magnetic Anchor must keep rare-charge accounting")
	_check(str(profile.get("weapon_id", "")) == WEAPON_ID,
		"Magnetic Anchor identity must remain canonical")
	_check(is_equal_approx(float(params.get("release_delay", -1.0)), 0.45)
		and is_equal_approx(float(params.get("implosion_delay", -1.0)), 0.60)
		and is_equal_approx(float(params.get("recovery_tail", -1.0)), 3.70),
		"Magnetic Anchor timing must remain unchanged")


func _test_every_target_receives_anchor_effect() -> void:
	var host := Host.new()
	_holder.add_child(host)
	var normals: Array[Node2D] = []
	for index in TARGET_COUNT:
		var normal := Target.new()
		normal.global_position = Vector2(201.0 + float(index), float(index - 10))
		host.add_child(normal)
		host.fixture_targets.append(normal)
		normals.append(normal)
	var epic := Target.new()
	epic.global_position = Vector2(230.0, 30.0)
	host.add_child(epic)
	host.fixture_targets.append(epic)
	epic.add_to_group("elite_enemies")
	var boss := Target.new()
	boss.health = 10000.0
	boss.max_health = 10000.0
	boss.global_position = Vector2(240.0, 40.0)
	host.add_child(boss)
	host.fixture_targets.append(boss)
	boss.add_to_group("bosses")

	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var controller := Controller.new(host, registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Magnetic Anchor must activate")
	var activation = controller.active_activation()
	_advance(activation, 0.50)
	for normal in normals:
		_check(not normal.knockbacks.is_empty() and StatusEffects.is_movement_locked(normal),
			"the well must pull and hold every normal target")
	_check(not epic.knockbacks.is_empty() and is_equal_approx(epic.knockbacks[0].length(), normals[0].knockbacks[0].length() * 0.25),
		"the well must preserve epic control resistance")
	_check(not StatusEffects.is_movement_locked(epic), "the well must never movement-lock an epic")
	_check(boss.knockbacks.is_empty() and not StatusEffects.is_movement_locked(boss),
		"the well must neither displace nor lock a boss")
	_check(is_zero_approx(activation.applied_total), "the well itself must hold, not damage")

	_advance(activation, 0.60)
	for normal in normals:
		_check(normal.received.size() == 2 and _all_received_damage_positive(normal),
			"implosion and EMP must each hit every normal target")
	_check(epic.received.size() == 2 and _all_received_damage_positive(epic),
		"implosion and EMP must each hit the elite")
	var boss_removed := boss.max_health - boss.health
	_check(boss_removed > 0.0 and boss_removed <= boss.max_health * 0.08 + 0.001,
		"all boss damage must stay inside the 8% whole-activation cap")
	_check(_has_event(host, "robot_magnetic_anchor.implosion") and _has_event(host, "robot_magnetic_anchor.emp"),
		"Magnetic Anchor must publish implosion and EMP events")
	_check(is_equal_approx(activation.applied_total, _removed(host)),
		"Magnetic Anchor attribution must use actual HP removed")
	controller.cancel()
	await _drop(host)


func _all_received_damage_positive(target: Target) -> bool:
	for hit in target.received:
		if float(hit.get("amount", 0.0)) <= 0.0:
			return false
	return true


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(minf(0.01, seconds - elapsed))
		elapsed += 0.01


func _has_event(host: Host, suffix: String) -> bool:
	for event_id in host.events:
		if event_id.ends_with(suffix):
			return true
	return false


func _removed(host: Host) -> float:
	var total := 0.0
	for raw_target in host.fixture_targets:
		var target := raw_target as Target
		if target != null:
			total += target.max_health - target.health
	return total


func _drop(host: Host) -> void:
	if is_instance_valid(host):
		host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("robot_magnetic_anchor_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("robot_magnetic_anchor_test: %s" % error)
	print("robot_magnetic_anchor_test: FAIL (%d)" % _errors.size())
	quit(1)
