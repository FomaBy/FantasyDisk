extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "dark_mage"
const STEP := 0.01


class Target extends Node2D:
	var health := 1000.0
	var max_health := 1000.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(760.0, 0.0)
	var active := false
	var base_damage := 10.0
	var presentations: Array[Dictionary] = []

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_point - global_position
		return {
			"point": global_position + offset.normalized() * minf(offset.length(), max_range),
			"direction": offset.normalized(),
		}

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

	func ultimate_host_present(event_id: String, payload: Dictionary) -> Node:
		presentations.append({"event_id": event_id, "payload": payload.duplicate(true)})
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D
var _registry: Registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(_registry.package_validation_errors().is_empty(),
		"Dark Mage packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_abyss_mirror()
	await _test_cursed_crown()
	await _test_vanishing_thread()
	_holder.queue_free()
	await process_frame
	_report()


func _test_abyss_mirror() -> void:
	var host := await _host()
	host.base_damage = 100.0
	var original := _target(host, Vector2(120.0, 0.0), 80.0, 80.0)
	var reflection := _target(host, Vector2(-120.0, 0.0), 10000.0, 10000.0)
	var boss := _target(host, Vector2(260.0, 0.0), 1200.0, 1200.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "dark_book"), "Abyss Mirror must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 1.2)
	_check(effect != null and int(effect.get("pair_count_for_tests")) >= 2,
		"every nearby silhouette must receive an original/mirror pair")
	_check(effect != null and int(effect.get("kill_reflection_count_for_tests")) == 1,
		"a lethal original must produce exactly one non-recursive reflection burst, got %d" \
			% [int(effect.get("kill_reflection_count_for_tests")) if effect != null else -1])
	_check(_feedback_count([reflection], "abyss_reflection") > 0
		and _feedback_count([reflection], "abyss_kill_reflection") > 0,
		"the reflected silhouette must receive the paired hit and one kill burst")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.11),
		"all Book hits must share the 11% boss cap")
	_check(_has_presentation(host, "weapon_ultimate.phase.dark_mage.dark_book.execute")
		and _has_presentation(host, "weapon_ultimate.phase.dark_mage.dark_book.active"),
		"Book mechanics must emit the accepted execute/active event IDs")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Book attribution must equal actual HP removed after all caps")
	controller.cancel()
	await process_frame
	_check(not is_instance_valid(effect) and not host.active,
		"Book cancel must drop the activation-owned effect and active latch")
	await _drop(host)


func _test_cursed_crown() -> void:
	var host := await _host()
	host.base_damage = 100.0
	var doomed := _target(host, Vector2(850.0, 0.0), 80.0, 80.0)
	var replacement := _target(host, Vector2(1040.0, 0.0), 4000.0, 4000.0)
	var epic := _target(host, Vector2(180.0, 0.0), 4000.0, 4000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(240.0, 0.0), 10000.0, 10000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	for index in 11:
		_target(host, Vector2(50.0 + float(index) * 20.0, 120.0), 4000.0, 4000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "cursed_skull"), "Cursed Crown must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 5.7)
	var epic_status := _status_with_prefix(epic, "dark_mage_ultimate_crown_")
	var boss_status := _status_with_prefix(boss, "dark_mage_ultimate_crown_")
	_check(is_equal_approx(StatusEffects.damage_multiplier(epic), 0.65),
		"the crown must reduce cursed enemy outgoing damage")
	_check(is_equal_approx(float(epic_status.get("duration", 0.0)), 2.75)
		and is_equal_approx(float(boss_status.get("duration", 0.0)), 1.375),
		"epic and boss curse duration must obey the shared resistance policy")
	_check(effect != null and int(effect.get("transfer_count_for_tests")) == 1,
		"one killed cursed target must transfer its curse once to the nearby unmarked target")
	_check(not _status_with_prefix(replacement, "dark_mage_ultimate_crown_").is_empty(),
		"the transfer recipient must receive the same crown curse contract")
	_check(effect != null and int(effect.get("harvest_count_for_tests")) == 1,
		"the crown must harvest the remaining marks once")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.11),
		"curse pulses and harvest must share the 11% boss cap")
	_check(_has_presentation(host, "weapon_ultimate.phase.dark_mage.cursed_skull.execute")
		and _has_presentation(host, "weapon_ultimate.phase.dark_mage.cursed_skull.recover"),
		"Crown mechanics must emit the accepted execute/recover event IDs")
	controller.cancel()
	await process_frame
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "dark_mage_ultimate_crown_").is_empty(),
			"crown cleanup must remove only its own curse leases")
	await _drop(host)


func _test_vanishing_thread() -> void:
	var host := await _host()
	host.base_damage = 100.0
	host.aim_point = Vector2(760.0, 0.0)
	var first := _target(host, Vector2(150.0, 0.0), 10000.0, 10000.0)
	var second := _target(host, Vector2(350.0, 20.0), 10000.0, 10000.0)
	var boss := _target(host, Vector2(550.0, -10.0), 10000.0, 10000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var off_rail := _target(host, Vector2(350.0, 300.0), 10000.0, 10000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "dark_wand"), "Vanishing Thread must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.7)
	_check(effect != null and int(effect.get("marked_count_for_tests")) == 3
		and int(effect.get("collapse_count_for_tests")) == 3,
		"the aimed rail must mark and collapse exactly its three distinct nodes")
	_check(off_rail.received.is_empty(), "the thread must not leak outside its aimed corridor")
	_check(first.received.size() == 1 and second.received.size() == 1
		and float(second.received[0]["amount"]) > float(first.received[0]["amount"]),
		"each distinct chain node must raise the final collapse ramp")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.11),
		"all simultaneous collapse nodes must share the 11% boss cap")
	_check(_has_presentation(host, "weapon_ultimate.phase.dark_mage.dark_wand.execute")
		and _has_presentation(host, "weapon_ultimate.phase.dark_mage.dark_wand.active"),
		"Thread mechanics must emit the accepted execute/active event IDs")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Thread attribution must equal actual HP removed after caps")
	controller.cancel()
	await process_frame
	_check(not is_instance_valid(effect) and not host.active,
		"Thread cancel must drop the activation-owned effect and active latch")
	await _drop(host)


func _host() -> Host:
	var host := Host.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _target(host: Host, position: Vector2, health: float, max_health: float) -> Target:
	var target := Target.new()
	target.global_position = position
	target.health = health
	target.max_health = max_health
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _effect(activation) -> Node:
	if activation == null:
		return null
	var spawned: Array[Node] = activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _status_with_prefix(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return StatusEffects.snapshot(target)[status_id] as Dictionary
	return {}


func _feedback_count(targets: Array, mechanic: String) -> int:
	var count := 0
	for raw_target in targets:
		for hit in (raw_target as Target).received:
			if str((hit["feedback"] as Dictionary).get("ultimate_mechanic", "")) == mechanic:
				count += 1
	return count


func _has_presentation(host: Host, event_id: String) -> bool:
	for raw_event in host.presentations:
		if str((raw_event as Dictionary).get("event_id", "")) == event_id:
			return true
	return false


func _removed_health(targets: Array) -> float:
	var total := 0.0
	for raw_target in targets:
		var target := raw_target as Target
		total += target.max_health - target.health
	return total


func _drop(host: Host) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("dark_mage_ultimate_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_ultimate_mechanics_test: %s" % error)
	print("dark_mage_ultimate_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
