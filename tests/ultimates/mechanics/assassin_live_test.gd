extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "assassin"
const STEP := 0.01


class FixturePlayer extends Node2D:
	var _shadow_invisible_left := 0.0


class FixtureTarget extends Node2D:
	var health := 2000.0
	var max_health := 2000.0
	var starting_health := 2000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		var tick := int(get_parent().get("tick")) if get_parent() != null else -1
		received.append({
			"amount": amount,
			"feedback": (feedback as Dictionary).duplicate(true),
			"tick": tick,
		})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var damage_calls := 0
	var base_damage := 1.0
	var tick := 0
	var player: FixturePlayer

	func _init() -> void:
		player = FixturePlayer.new()
		add_child(player)

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

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
		damage_calls += 1
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
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
	await process_frame
	await _test_eight_moons_return_execute()
	await _test_moment_before_death()
	await _test_black_web()
	await _test_black_web_unique_target_cap()
	await _test_cancel_restores_owner()
	_test_charge_and_persistence_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_eight_moons_return_execute() -> void:
	var host := await _host()
	var durable := _target(host, Vector2(86.0, 36.0), 1000.0, 1000.0)
	var low_health := _target(host, Vector2(-86.0, -36.0), 20.0, 100.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "chakrams"), "Eight Moons must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and (effect.get("orbit_points_for_tests") as PackedVector2Array).size() == 8,
		"Eight Moons must begin with exactly eight orbit points")
	_check(effect != null and (effect.get("return_paths_for_tests") as Array).size() == 8,
		"every compass launch must own one curved return path")
	_advance(host, activation, 1.8)
	_check(effect != null and int(effect.get("outbound_hits_for_tests")) == 2,
		"outbound compass lanes must mark both in-lane targets exactly once")
	_check(effect != null and int(effect.get("return_hits_for_tests")) == 2,
		"curved returns must consume both outbound marks exactly once")
	_check(effect != null and int(effect.get("execute_count_for_tests")) == 1
		and is_zero_approx(low_health.health),
		"the return pass must execute one marked low-health normal")
	_check(_feedback_count([durable], "eight_moons_outbound") == 1
		and _feedback_count([durable], "eight_moons_return") == 1,
		"the durable target must receive one outbound and one return hit")
	_check(_feedback_count([low_health], "eight_moons_return_execute") == 1,
		"the executed target must retain explicit return attribution")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Eight Moons attribution must equal HP actually removed")
	await process_frame
	_check(not controller.is_active() and not host.active and not is_instance_valid(effect),
		"Eight Moons completion must clear the activation-owned scene")
	await _drop(host)


func _test_moment_before_death() -> void:
	var host := await _host()
	var alpha := _target(host, Vector2(120.0, 0.0), 1000.0, 1000.0)
	var beta := _target(host, Vector2(180.0, 20.0), 1000.0, 1000.0)
	var gamma := _target(host, Vector2(220.0, -20.0), 1000.0, 1000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "shadow_daggers"), "Moment Before Death must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and int(effect.get("marked_count_for_tests")) == 3,
		"all admitted silhouettes must be marked before the sequence")
	_check(effect != null and bool(effect.get("owner_untargetable_for_tests"))
		and host.player._shadow_invisible_left >= 1.75,
		"the owner must become briefly untargetable during the backstab sequence")
	_advance(host, activation, 0.8)
	_check(alpha.received.is_empty() and beta.received.is_empty() and gamma.received.is_empty(),
		"sequential backstabs must store damage instead of resolving early")
	_check(effect != null and int(effect.get("backstab_count_for_tests")) == 3,
		"all three sequential backstabs must enter the activation ledger")
	_advance(host, activation, 0.5)
	_check(alpha.received.size() == 1 and beta.received.size() == 1 and gamma.received.size() == 1,
		"the final reveal must resolve every stored mark once")
	_check(alpha.received[0]["tick"] == beta.received[0]["tick"]
		and beta.received[0]["tick"] == gamma.received[0]["tick"],
		"all stored damage must resolve on the same reveal tick")
	_check((alpha.max_health - alpha.health) > (beta.max_health - beta.health),
		"the priority mark must lead focused damage while secondary marks stay bounded")
	await process_frame
	_check(not controller.is_active() and is_zero_approx(host.player._shadow_invisible_left),
		"normal completion must restore the owner targeting gate")
	await _drop(host)


func _test_black_web() -> void:
	var host := await _host()
	var normal := _target(host, Vector2(0.0, -100.0), 2000.0, 2000.0)
	var epic := _target(host, Vector2(0.0, 100.0), 2000.0, 2000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var outside := _target(host, Vector2(500.0, 500.0), 2000.0, 2000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "venom_wire"), "Black Web must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and (effect.get("web_points_for_tests") as PackedVector2Array).size() == 6,
		"Black Web must deploy exactly six anchors")
	_check(effect != null and (effect.get("web_segments_for_tests") as Array).size() == 9,
		"the six edges and three crossing chords must share one runtime geometry")
	_advance(host, activation, 0.7)
	_check(not normal.knockbacks.is_empty(), "the web must pull normal targets toward its center")
	_check(epic.knockbacks.is_empty(), "epic targets must resist the web pull")
	_check(not _black_web_status(normal).is_empty()
		and is_equal_approx(float(_black_web_status(epic).get("duration", 0.0)), 1.5),
		"poison control must be full on normals and half-duration on epics")
	_check(outside.received.is_empty(), "Black Web must not leak beyond its hex geometry")
	_advance(host, activation, 0.5)
	_check(effect != null and int(effect.get("cut_count_for_tests")) == 6,
		"two chord targets across three pulses must receive six bounded poison cuts")
	_check(effect != null and int(effect.get("burst_count_for_tests")) == 2,
		"each poisoned target must resolve one toxin burst")
	_check(_feedback_count([normal, epic], "black_web_toxin_burst") == 2,
		"toxin bursts must keep explicit feedback attribution")
	await process_frame
	_check(not controller.is_active() and not is_instance_valid(effect),
		"Black Web completion must clear the activation-owned scene")
	_check(_black_web_status(normal).is_empty() and _black_web_status(epic).is_empty(),
		"completion must remove only Black Web's leased statuses")
	await _drop(host)


func _test_black_web_unique_target_cap() -> void:
	var host := await _host()
	for index in 25:
		_target(host, Vector2(0.0, -240.0 + float(index) * 20.0), 2000.0, 2000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "venom_wire"),
		"Black Web crowd-cap fixture must activate")
	var activation := controller.active_activation()
	_advance(host, activation, 0.01)
	var hit_targets := 0
	for raw_target in host.fixture_targets:
		if not (raw_target as FixtureTarget).received.is_empty():
			hit_targets += 1
	_check(hit_targets == 24,
		"Black Web must admit at most 24 unique targets across all wire segments")
	controller.cancel()
	await process_frame
	await _drop(host)


func _test_cancel_restores_owner() -> void:
	var host := await _host()
	_target(host, Vector2(100.0, 0.0), 1000.0, 1000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "shadow_daggers"),
		"Shadow Daggers cancellation fixture must activate")
	_check(host.player._shadow_invisible_left > 0.0, "setup must lease untargetability")
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not host.active
		and is_zero_approx(host.player._shadow_invisible_left),
		"death/node-end cancellation must restore owner lifecycle state")
	await _drop(host)


func _test_charge_and_persistence_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in ["chakrams", "shadow_daggers", "venom_wire"]:
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
	await process_frame
	return host


func _target(
	host: FixtureHost, position: Vector2, health: float, max_health: float
) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = max_health
	target.starting_health = health
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _effect(activation: Activation) -> Node:
	if activation == null:
		return null
	var spawned := activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _advance(host: FixtureHost, activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		host.tick += 1
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _black_web_status(target: Node) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("assassin_ultimate_black_web_"):
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
		total += target.starting_health - target.health
	return total


func _drop(host: FixtureHost) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("assassin_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("assassin_live_test: %s" % error)
	print("assassin_live_test: FAIL (%d)" % _errors.size())
	quit(1)
