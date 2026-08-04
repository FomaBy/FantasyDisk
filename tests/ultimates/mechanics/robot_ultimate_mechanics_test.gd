extends SceneTree

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "robot"
const WEAPONS := ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"]
const STEP := 0.01


class Target extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 1000.0
	var modifiers: Dictionary = {}
	var events: Array[String] = []

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

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

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D
var _registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(_registry.package_validation_errors().is_empty(), "Robot package admission must be clean")
	for weapon_id in WEAPONS:
		_check(_registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must resolve through its exact Robot executor" % weapon_id)
		_check(_registry.has_exact_executor_pair(CLASS_ID, weapon_id), "%s must own its exact pair" % weapon_id)
	_check(_registry.resolution_source("engineer", "engineer_sentry_wrench") != Resolver.SOURCE_WEAPON_PROFILE
		or _registry.executor_for("engineer", "engineer_sentry_wrench") != _registry.executor_for(CLASS_ID, WEAPONS[0]),
		"Robot executor must not leak into another class")
	await _test_anchor()
	await _test_press()
	await _test_reactor()
	_holder.queue_free()
	await process_frame
	_report()


func _test_anchor() -> void:
	var host := _host()
	var normal := _target(host, Vector2(260.0, 0.0))
	var epic := _target(host, Vector2(240.0, -40.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(200.0, 50.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "robot_magnetic_anchor"), "anchor must activate")
	var activation = controller.active_activation()
	_advance(activation, 0.50)
	_check(not normal.knockbacks.is_empty() and normal.knockbacks[0].x < 0.0,
		"anchor well must pull normal targets toward the aimed anchor")
	_check(StatusEffects.is_movement_locked(normal),
		"the well must hold a gripped normal so it neither walks nor fires")
	_check(not epic.knockbacks.is_empty()
		and is_equal_approx(epic.knockbacks[0].length(), normal.knockbacks[0].length() * 0.25),
		"anchor must apply epic control resistance to the pull")
	_check(not StatusEffects.is_movement_locked(epic), "the well must never movement-lock an epic")
	_check(boss.knockbacks.is_empty() and not StatusEffects.is_movement_locked(boss),
		"anchor must neither displace nor lock bosses")
	_check(is_zero_approx(activation.applied_total), "the well itself must hold, not damage")
	_advance(activation, 0.60)
	_check(boss.max_health - boss.health <= boss.max_health * 0.08 + 0.001,
		"anchor damage must share the whole-activation boss cap")
	_check(_has_event(host, "robot_magnetic_anchor.implosion") and _has_event(host, "robot_magnetic_anchor.emp"),
		"anchor must publish accepted implosion and EMP animation events")
	_check(is_equal_approx(activation.applied_total, _removed(host)), "anchor attribution must use actual HP removed")
	controller.cancel()
	await _drop(host)


func _test_press() -> void:
	var host := _host()
	var normal := _target(host, Vector2(160.0, 70.0))
	var epic := _target(host, Vector2(180.0, -70.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(200.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "robot_hydraulic_press"), "press must activate")
	var activation = controller.active_activation()
	_advance(activation, 0.75)
	_check(not normal.knockbacks.is_empty() and normal.knockbacks[0].y < 0.0,
		"press must squeeze the upper normal target toward the aimed axis")
	_check(not epic.knockbacks.is_empty() and is_equal_approx(epic.knockbacks[0].length(), normal.knockbacks[0].length() * 0.25),
		"press must apply epic control resistance")
	_check(boss.knockbacks.is_empty(), "press must not move bosses")
	_advance(activation, 1.70)
	_check(boss.max_health - boss.health <= boss.max_health * 0.08 + 0.001,
		"all press crushes and release must share the boss cap")
	_check(_has_event(host, "robot_hydraulic_press.release"), "press must publish its hydraulic release event")
	controller.cancel()
	await _drop(host)


func _test_reactor() -> void:
	var host := _host()
	var boss := _target(host, Vector2(120.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "robot_reactor_core"), "reactor must activate")
	var activation = controller.active_activation()
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))),
		"reactor absorb must never touch modifiers on the activation frame")
	_advance(activation, 0.05)
	_check(float(host.modifiers.get("absorb_flat", 0.0)) > 0.0,
		"reactor overdrive must own a temporary absorb window")
	_advance(activation, 1.55)
	_check(boss.max_health - boss.health <= boss.max_health * 0.08 + 0.001,
		"all eight rotating vents must share the boss cap")
	_check(_has_event(host, "robot_reactor_core.vent_wave") and _has_event(host, "robot_reactor_core.final_vent"),
		"reactor must publish vent-wave and cooling-release animation events")
	controller.cancel()
	await process_frame
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))),
		"cancel must remove the non-persistent reactor absorb")
	await _drop(host)


func _host() -> Host:
	var host := Host.new()
	_holder.add_child(host)
	return host


func _target(host: Host, position: Vector2) -> Target:
	var target := Target.new()
	target.global_position = position
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(minf(STEP, seconds - elapsed))
		elapsed += STEP


func _has_event(host: Host, suffix: String) -> bool:
	for event_id in host.events:
		if event_id.ends_with(suffix):
			return true
	return false


func _removed(host: Host) -> float:
	var total := 0.0
	for target in host.fixture_targets:
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
		print("robot_ultimate_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("robot_ultimate_mechanics_test: %s" % error)
	print("robot_ultimate_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
