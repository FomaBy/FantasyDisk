extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "doctor"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 1000.0
	var max_health := 1000.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class FixtureHost extends Node2D:
	var health := 35.0
	var max_health := 100.0
	var targets: Array[FixtureTarget] = []
	var events: Array[String] = []
	var modifiers: Dictionary = {}
	var active := false
	var aim := Vector2(250.0, 0.0)
	var base_damage := 10.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim - global_position
		return {"point": global_position + offset.normalized() * minf(offset.length(), max_range), "direction": offset.normalized()}

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

	func ultimate_host_present(event_id: String, _payload: Dictionary) -> Node:
		events.append(event_id)
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D = null
var _registry: Registry = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	await process_frame
	await _test_restore_potion()
	await _test_restore_potion_reaches_every_enemy()
	await _test_plague_syringe()
	await _test_bone_saw()
	_holder.queue_free()
	await process_frame
	_report()


func _test_restore_potion() -> void:
	var host := await _host()
	var boss := _target(host, Vector2(250.0, 0.0), 2000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	_target(host, Vector2(310.0, 0.0), 1000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "restore_potion"), "Life and Death must activate")
	var activation: Activation = controller.active_activation()
	_advance(activation, 3.1)
	_check(host.health > 35.0, "actual outer-zone damage must repair the Doctor")
	_check(float(host.modifiers.get("absorb_flat", 0.0)) > 0.0, "final overload must form a capped shield")
	_check(_has_event(host, ".release") and _has_event(host, ".outer_ring") and _has_event(host, ".inner_spiral"),
		"Life and Death must emit its accepted flask, poison-ring, and healing-spiral events")
	_check(boss.max_health - boss.health <= boss.max_health * 0.08,
		"Life and Death must apply one shared boss cap")
	controller.cancel()
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))) and not host.active,
		"Life and Death cancel must clean temporary absorb and active state")
	await _drop(host)


func _test_restore_potion_reaches_every_enemy() -> void:
	var host := await _host()
	for index in 13:
		var angle := TAU * float(index) / 13.0
		_target(host, Vector2(250.0, 0.0) + Vector2.from_angle(angle) * 100.0, 10000.0)
	for index in 7:
		_target(host, Vector2(float(index) * 16.0, -40.0), 10000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "restore_potion"),
		"Life and Death must activate against a map-wide crowd")
	var activation: Activation = controller.active_activation()
	_advance(activation, 4.2)
	var reached := 0
	for target in host.targets:
		if target.health < target.max_health:
			reached += 1
	_check(reached == 20,
		"Life and Death must damage every live enemy, got %d of 20" % reached)
	controller.cancel()
	await _drop(host)


func _test_plague_syringe() -> void:
	var host := await _host()
	var patient := _target(host, Vector2(250.0, 0.0), 2000.0)
	patient.add_to_group(Activation.BOSS_GROUP)
	for x in [310.0, 380.0, 450.0, 520.0]:
		_target(host, Vector2(x, 0.0), 400.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "plague_syringe"), "Black Epidemic must activate")
	var activation: Activation = controller.active_activation()
	_advance(activation, 6.0)
	_check(patient.received.size() >= 1, "patient zero must receive the syringe strike")
	_check(_infected_target_count(host) >= 3, "timed waves must spread from patient zero")
	_check(patient.max_health - patient.health <= patient.max_health * 0.08,
		"Black Epidemic must cap all patient-zero boss damage across waves")
	_check(_has_event(host, ".inject") and _has_event(host, ".veins") and _has_event(host, ".wave") and _has_event(host, ".mask"),
		"Black Epidemic must emit syringe, veins, waves, and mask finale events")
	controller.cancel()
	_check(not host.active, "Black Epidemic cancel must end the active window")
	await _drop(host)


func _test_bone_saw() -> void:
	var host := await _host()
	var boss := _target(host, Vector2(120.0, 0.0), 2000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	_target(host, Vector2(170.0, 0.0), 1000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "bone_saw"), "Emergency Surgery must activate")
	var activation: Activation = controller.active_activation()
	_advance(activation, 2.6)
	_check(host.health > 35.0, "saw damage must convert actual removed HP into drain repair")
	_check(float(host.modifiers.get("absorb_flat", 0.0)) > 0.0, "stored vitality must become a capped stitch shield")
	_check(_has_event(host, ".stance") and _has_event(host, ".orbit") and _has_event(host, ".stitch_shield"),
		"Emergency Surgery must emit stance, orbit, and stitch-shield events")
	_check(boss.max_health - boss.health <= boss.max_health * 0.08,
		"Emergency Surgery must cap the full saw orbit against a boss")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.targets)),
		"ultimate attribution must equal HP actually removed, not attempted overkill")
	controller.cancel()
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))) and not host.active,
		"Emergency Surgery cancel must clean its shield and active state")
	await _drop(host)


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _target(host: FixtureHost, position: Vector2, health: float) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = health
	host.add_child(target)
	host.targets.append(target)
	return target


func _advance(activation: Activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _has_event(host: FixtureHost, suffix: String) -> bool:
	for event_id in host.events:
		if event_id.ends_with(suffix):
			return true
	return false


func _infected_target_count(host: FixtureHost) -> int:
	var count := 0
	for target in host.targets:
		for hit in target.received:
			if str((hit["feedback"] as Dictionary).get("ultimate_mechanic", "")) == "black_epidemic_wave":
				count += 1
				break
	return count


func _removed_health(targets: Array[FixtureTarget]) -> float:
	var total := 0.0
	for target in targets:
		total += target.max_health - target.health
	return total


func _drop(host: FixtureHost) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("doctor_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("doctor_live_test: %s" % error)
	quit(1)
