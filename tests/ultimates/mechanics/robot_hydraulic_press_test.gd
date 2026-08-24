extends SceneTree

const Press := preload("res://scripts/ultimates/classes/robot/robot_hydraulic_press.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")

const PROFILE_PATH := "res://data/ultimates/classes/robot/robot_hydraulic_press.json"
const SCRIPT_PATH := "res://scripts/ultimates/classes/robot/robot_hydraulic_press.gd"
const CLASS_ID := "robot"
const WEAPON_ID := "robot_hydraulic_press"
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
		return {"point": global_position + Vector2.RIGHT * minf(max_range, 400.0), "direction": Vector2.RIGHT}

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
	_test_every_target_in_corridor_receives_press_effect()
	_holder.queue_free()
	await process_frame
	_report()


func _test_profile_keeps_identity_and_safety_contracts() -> void:
	var document = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	_check(document is Dictionary, "Hydraulic Press profile must remain readable")
	if not document is Dictionary:
		return
	var profile := document as Dictionary
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	_check(not params.has("target_limit"), "Hydraulic Press profile must not carry a target count cap")
	_check(not Press.parameter_contract().has("target_limit"),
		"Hydraulic Press parameter contract must not carry a target count cap")
	_check(not FileAccess.get_file_as_string(SCRIPT_PATH).contains("target_limit"),
		"Hydraulic Press executor must not declare or pass a target count cap")
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.08),
		"Hydraulic Press must keep its 8% whole-activation boss cap")
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"Hydraulic Press must keep rare-charge accounting")
	_check(str(profile.get("weapon_id", "")) == WEAPON_ID,
		"Hydraulic Press identity must remain canonical")
	_check(is_equal_approx(float(params.get("windup_delay", -1.0)), 0.72)
		and int(params.get("crush_count", -1)) == 3
		and is_equal_approx(float(params.get("crush_interval", -1.0)), 0.30)
		and is_equal_approx(float(params.get("recovery_tail", -1.0)), 2.43),
		"Hydraulic Press timing must remain unchanged")


func _test_every_target_in_corridor_receives_press_effect() -> void:
	var host := Host.new()
	_holder.add_child(host)
	var normals: Array[Node2D] = []
	for index in TARGET_COUNT:
		var normal := Target.new()
		normal.global_position = Vector2(30.0 + float(index) * 18.0, float(index - 10) * 8.0 + 4.0)
		host.add_child(normal)
		host.fixture_targets.append(normal)
		normals.append(normal)
	var epic := Target.new()
	epic.global_position = Vector2(220.0, 40.0)
	host.add_child(epic)
	host.fixture_targets.append(epic)
	epic.add_to_group("elite_enemies")
	var boss := Target.new()
	boss.health = 10000.0
	boss.max_health = 10000.0
	boss.global_position = Vector2(260.0, -60.0)
	host.add_child(boss)
	host.fixture_targets.append(boss)
	boss.add_to_group("bosses")

	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var controller := Controller.new(host, registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Hydraulic Press must activate")
	var activation = controller.active_activation()
	_advance(activation, 1.65)

	for normal in normals:
		_check(normal.received.size() == 4, "the press must crush and release every normal target in the corridor")
		_check(normal.knockbacks.size() == 3, "each crush pulse must compress every normal target")
	_check(epic.received.size() == 4, "the press must crush and release the elite")
	_check(epic.knockbacks.size() == 3
		and is_equal_approx(epic.knockbacks[0].length(), normals[0].knockbacks[0].length() * 0.25),
		"the press must preserve elite compression resistance")
	_check(not boss.received.is_empty(), "the press must still crush the boss within its damage budget")
	_check(boss.knockbacks.is_empty(), "the press must never displace a boss")
	var boss_removed := boss.max_health - boss.health
	_check(boss_removed > 0.0 and boss_removed <= boss.max_health * 0.08 + 0.001,
		"all boss damage must stay inside the 8% whole-activation cap")
	_check(_has_event(host, "robot_hydraulic_press.crush") and _has_event(host, "robot_hydraulic_press.release"),
		"Hydraulic Press must publish crush and release events")
	_check(is_equal_approx(activation.applied_total, _removed(host)),
		"Hydraulic Press attribution must use actual HP removed")
	controller.cancel()
	await _drop(host)


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
		print("robot_hydraulic_press_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("robot_hydraulic_press_test: %s" % error)
	print("robot_hydraulic_press_test: FAIL (%d)" % _errors.size())
	quit(1)
