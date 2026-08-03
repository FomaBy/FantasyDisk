extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "priest"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var archetype := "swarm"
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class FixturePlayer extends Node2D:
	signal constellation_final_resolved(
		weapon_id: String, event: String, target: Node2D, context: Dictionary, resolution: Dictionary
	)
	var health := 100.0
	var max_health := 100.0


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var player: FixturePlayer = null
	var active := false
	var base_damage := 10.0
	var modifiers := {}

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(_max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT, "direction": Vector2.RIGHT}

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

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		if operation == "mul":
			modifiers[key] = float(modifiers.get(key, 1.0)) * value
		else:
			modifiers[key] = float(modifiers.get(key, 0.0)) + value

	func ultimate_host_repair(target: Node, amount: float) -> void:
		if target == player:
			player.health = minf(player.health + amount, player.max_health)

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
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
	await _test_reliquary()
	await _test_censer()
	await _test_chime()
	_test_charge_and_persistence_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_reliquary() -> void:
	var host := await _host()
	host.player.health = 60.0
	for index in 3:
		_target(host, Vector2(110.0 + 60.0 * index, 0.0), 5000.0, 5000.0)
	var boss := _target(host, Vector2(340.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "priest_reliquary"), "Reliquary must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 5.35)
	_check(effect != null and float(effect.get("actual_removed_for_tests")) > 0.0,
		"all three rings must record actual HP removed before healing")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Reliquary attribution must equal HP actually removed")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.08),
		"Reliquary rings must share the frozen 8% boss cap")
	_check(host.player.health == host.player.max_health,
		"the final pillar must heal the owner from actual damage")
	_check(float(host.modifiers.get("absorb_flat", 0.0)) > 0.0,
		"Reliquary overheal must become a temporary shield")
	for target in host.fixture_targets:
		_check(not _status_with_prefix(target, "priest_ultimate_reliquary_").is_empty(),
			"the sanctify ring must lease its mark")
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not host.active, "Reliquary cancel must close the active window")
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))),
		"Reliquary cancellation must reverse its shield")
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "priest_ultimate_reliquary_").is_empty(),
			"Reliquary cancellation must clear only its marks")
	await _drop(host)


func _test_censer() -> void:
	var host := await _host()
	for index in 2:
		_target(host, Vector2(120.0 + 90.0 * index, 0.0), 5000.0, 5000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "priest_censer"), "Censer must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(is_equal_approx(float(host.modifiers.get("absorb_flat", 0.0)), 340.0),
		"Censer must grant the declared strong temporary mitigation")
	host.player.constellation_final_resolved.emit(
		"priest_censer", "damage_absorbed", null, {"absorbed_amount": 500.0}, {}
	)
	_check(effect != null and is_equal_approx(float(effect.get("stored_prevented_for_tests")), 325.0),
		"Censer must store a capped fraction of actually prevented damage")
	_advance(activation, 6.35)
	_check(effect != null and is_equal_approx(float(effect.get("counter_burst_for_tests")), 325.0),
		"Censer must return the stored prevention as its finish counter")
	_check(_feedback_count(host.fixture_targets, "censer_stored_counter") == 2,
		"the finish counter must resolve through the activation damage ledger")
	controller.cancel()
	await process_frame
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))),
		"Censer cancellation must reverse mitigation")
	_check(not host.player.is_connected(
		"constellation_final_resolved", Callable(effect, "_on_constellation_final_resolved")
	), "Censer cancellation must disconnect its actual-prevention listener")
	await _drop(host)


func _test_chime() -> void:
	var host := await _host()
	host.player.health = 20.0
	var normal := _target(host, Vector2(110.0, 0.0), 5000.0, 5000.0)
	var epic := _target(host, Vector2(170.0, 0.0), 5000.0, 5000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(230.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "priest_chime"), "Chime must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.55)
	_check(bool(_status_with_prefix(normal, "priest_ultimate_chime_").get("movement_locked", false)),
		"the first bell must interrupt normal targets")
	_check(not bool(_status_with_prefix(epic, "priest_ultimate_chime_").get("movement_locked", false))
			and not bool(_status_with_prefix(boss, "priest_ultimate_chime_").get("movement_locked", false)),
		"epics and bosses must resist the interrupt lock and only stagger")
	_advance(activation, 3.60)
	_check(effect != null and int(effect.get("toll_count_for_tests")) == 3,
		"Chime must resolve exactly three tolls")
	_check(float(effect.get("chain_removed_for_tests")) > 0.0 and host.player.health > 20.0,
		"the second bell's actual damage must fund the third bell heal")
	_check(is_equal_approx(float(host.modifiers.get("death_save", 0.0)), 1.0),
		"the third bell must open exactly one temporary lethal-prevention window")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.08),
		"all Chime damage must share the frozen 8% boss cap")
	_advance(activation, 2.4)
	await process_frame
	_check(not controller.is_active() and not host.active,
		"Chime completion must close the active window")
	_check(is_zero_approx(float(host.modifiers.get("death_save", 0.0))),
		"Chime completion must remove lethal prevention")
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "priest_ultimate_chime_").is_empty(),
			"Chime completion must clear only its status leases")
	await _drop(host)


func _test_charge_and_persistence_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in ["priest_reliquary", "priest_censer", "priest_chime"]:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var ledger := Ledger.new(row)
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		ledger.apply_start_charge(1.0)
		_check(ledger.try_activate(), "%s must spend one full charge" % weapon_id)
		ledger.apply_start_charge(1.0)
		_check(not ledger.try_activate(), "%s must refuse a second cast in one encounter" % weapon_id)
		ledger.set_ultimate_active(true)
		var before := ledger.charge
		ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)
		_check(is_equal_approx(ledger.charge, before),
			"%s must earn no charge during its active effect" % weapon_id)
		ledger.set_ultimate_active(false)
		ledger.apply_start_charge(0.63)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, 63.0),
			"%s charge must survive battle/act/Continue snapshots" % weapon_id)


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	var player := FixturePlayer.new()
	host.add_child(player)
	host.player = player
	await process_frame
	return host


func _target(host: FixtureHost, position: Vector2, health: float, max_health: float) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = max_health
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _effect(activation: Activation) -> Node:
	if activation == null:
		return null
	var spawned := activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _advance(activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _status_with_prefix(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return (StatusEffects.snapshot(target)[status_id] as Dictionary).duplicate(true)
	return {}


func _feedback_count(targets: Array, mechanic: String) -> int:
	var count := 0
	for raw_target in targets:
		var target := raw_target as FixtureTarget
		for hit in target.received:
			if str((hit["feedback"] as Dictionary).get("ultimate_mechanic", "")) == mechanic:
				count += 1
	return count


func _removed_health(targets: Array) -> float:
	var total := 0.0
	for raw_target in targets:
		var target := raw_target as FixtureTarget
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
		print("priest_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("priest_live_test: %s" % error)
	print("priest_live_test: FAIL (%d)" % _errors.size())
	quit(1)
