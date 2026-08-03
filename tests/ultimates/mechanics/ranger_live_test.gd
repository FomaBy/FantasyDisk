extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "ranger"
const STEP := 0.01


class Target extends Node2D:
	var health := 4000.0
	var max_health := 4000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(900.0, 0.0)
	var active := false
	var presentations: Array[Dictionary] = []
	var base_damage := 10.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

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
			return left.global_position.distance_squared_to(center) < right.global_position.distance_squared_to(center)
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
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	await process_frame
	await _test_moon_crossbow()
	await _test_storm_longbow()
	await _test_hunter_trap()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_moon_crossbow() -> void:
	var host := await _host()
	host.aim_point = Vector2(300.0, 0.0)
	var aimed := _target(host, Vector2(300.0, 0.0), 300.0, 300.0)
	var boss := _target(host, Vector2(560.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var neighbors: Array[Target] = []
	for position in [Vector2(340.0, 100.0), Vector2(340.0, -100.0), Vector2(220.0, 100.0), Vector2(220.0, -100.0)]:
		neighbors.append(_target(host, position, 1000.0, 1000.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "moon_crossbow"), "Moon Crossbow must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and effect.get("mark_target_for_tests") == aimed,
		"the aimed prey must win before the highest-HP fallback")
	_check(effect != null and effect.get_node_or_null("Presentation") != null,
		"Moon Crossbow must mount its class-local presentation")
	_advance(activation, STEP)
	_check(effect != null and int(effect.get("wave_count_for_tests")) == 1,
		"the first moon wave must resolve")
	_check(effect != null and int(effect.get("split_hits_for_tests")) == 4,
		"one moon wave must split into four distinct neighbours")
	_check(effect != null and int(effect.get("transfer_count_for_tests")) == 1
			and effect.get("mark_target_for_tests") == boss,
		"a killed moon mark must transfer to the highest-HP survivor")
	for neighbor in neighbors:
		_check(not neighbor.received.is_empty(), "every distinct neighbour must receive one split bolt")
	_advance(activation, 1.5)
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.09),
		"all moon waves must share the frozen 9% boss budget")
	_check(not host.presentations.is_empty(), "Moon Crossbow must publish presentation events")
	await _drop(host)


func _test_storm_longbow() -> void:
	var host := await _host()
	host.aim_point = Vector2(900.0, 0.0)
	var normal := _target(host, Vector2(180.0, 10.0), 4000.0, 4000.0)
	var epic := _target(host, Vector2(420.0, -20.0), 4000.0, 4000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var off_corridor := _target(host, Vector2(300.0, 240.0), 4000.0, 4000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "storm_longbow"), "Storm Longbow must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and int(effect.get("corridor_size_for_tests")) == 2,
		"the storm corridor must reject off-axis targets")
	_check(effect != null and effect.get_node_or_null("Presentation") != null,
		"Storm Longbow must mount its class-local presentation")
	_advance(activation, 3.0)
	_check(effect != null and int(effect.get("beat_count_for_tests")) == 7,
		"the storm must resolve all seven tail-to-tip beats")
	_check(off_corridor.received.is_empty(), "storm beats must not leak out of the corridor")
	_check(normal.knockbacks.size() >= 1 and epic.knockbacks.size() >= 1
			and epic.knockbacks[0].length() == normal.knockbacks[0].length() * 0.5,
		"storm control must respect epic resistance")
	await _drop(host)


func _test_hunter_trap() -> void:
	var host := await _host()
	host.aim_point = Vector2(400.0, 0.0)
	var normal := _target(host, Vector2(400.0, 0.0), 4000.0, 4000.0)
	var epic := _target(host, Vector2(450.0, 0.0), 4000.0, 4000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var outside := _target(host, Vector2(700.0, 0.0), 4000.0, 4000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "hunter_trap"), "Hunter Trap must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and effect.get_node_or_null("Presentation") != null,
		"Hunter Trap must mount its class-local presentation")
	_advance(activation, STEP)
	_check(effect != null and int(effect.get("ring_count_for_tests")) == 1,
		"the first inward trap ring must snap")
	_check(not _status(normal).is_empty() and is_equal_approx(float(_status(normal).get("duration", 0.0)), 4.2),
		"normal prey must receive the full snare")
	_check(not _status(epic).is_empty() and is_equal_approx(float(_status(epic).get("duration", 0.0)), 2.1),
		"epic prey must receive the reduced snare")
	_check(outside.received.is_empty() and _status(outside).is_empty(),
		"the trap rings must stay inside their declared radius")
	controller.cancel()
	await process_frame
	_check(_status(normal).is_empty() and _status(epic).is_empty(),
		"cancel must clean up only Hunter Trap's leased snares")
	await _drop(host)


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in ["moon_crossbow", "storm_longbow", "hunter_trap"]:
		var ledger := Ledger.new(Budget.row_for(rows, CLASS_ID, weapon_id))
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		ledger.apply_start_charge(1.0)
		_check(ledger.try_activate(), "%s must spend one full charge" % weapon_id)
		ledger.set_ultimate_active(true)
		var before := ledger.charge
		ledger.add_removed_health(500.0)
		_check(is_equal_approx(ledger.charge, before),
			"%s must earn no charge while its activation is live" % weapon_id)


func _host() -> Host:
	var host := Host.new()
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
	var spawned: Array = activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _status(target: Node) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("ranger_ultimate_trap_"):
			return StatusEffects.snapshot(target)[status_id] as Dictionary
	return {}


func _drop(host: Host) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ranger_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ranger_live_test: %s" % error)
	print("ranger_live_test: FAIL (%d)" % _errors.size())
	quit(1)
