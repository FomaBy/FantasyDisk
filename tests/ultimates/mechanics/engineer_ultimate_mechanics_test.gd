extends SceneTree

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Mines := preload("res://scripts/ultimates/classes/engineer/engineer_pressure_mines.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")

const CLASS_ID := "engineer"
const SENTRY := "engineer_sentry_wrench"
const DRONES := "engineer_repair_drone"
const MINES := "engineer_pressure_mines"
const STEP := 0.01


class Target extends Node2D:
	var health := 1000.0
	var max_health := 1000.0
	var damage_taken_multiplier := 1.0
	var knockback_impulses: Array[Vector2] = []

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount * damage_taken_multiplier, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockback_impulses.append(impulse)


class Repairable extends Node2D:
	var owner_node: Node = null
	var health := 10.0
	var max_health := 40.0


class PlayerProbe extends Node2D:
	var health := 50.0
	var max_health := 100.0


class Host extends Node2D:
	var player := PlayerProbe.new()
	var fixture_targets: Array[Node2D] = []
	var permanent_devices: Array[Node] = []
	var modifiers: Dictionary = {}
	var presentations: Array[Dictionary] = []
	var active := false
	var base_damage := 10.0

	func _ready() -> void:
		add_child(player)

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return left.global_position.distance_squared_to(center) \
				< right.global_position.distance_squared_to(center)
		)
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(group_id: String) -> Array:
		if group_id != "engineer_devices":
			return []
		var result: Array = []
		for device in permanent_devices:
			if is_instance_valid(device) and device.get("owner_node") == player:
				result.append(device)
		return result

	func ultimate_host_repair(target: Node, amount: float) -> float:
		if target == null or not is_instance_valid(target) or target.get("health") == null \
				or target.get("max_health") == null:
			return 0.0
		if target != player and target.get("owner_node") != player and target.get("owner_node") != self:
			return 0.0
		var before := float(target.get("health"))
		if before <= 0.0:
			return 0.0
		target.set("health", minf(before + amount, float(target.get("max_health"))))
		return float(target.get("health")) - before

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		if target != null and is_instance_valid(target):
			target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		var multiplicative := operation == "mul"
		var current := float(modifiers.get(key, 1.0 if multiplicative else 0.0))
		modifiers[key] = current * value if multiplicative else current + value

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
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(_registry.package_validation_errors().is_empty(),
		"Engineer packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_sentry_hex_and_cleanup()
	await _test_drone_intercept_repair_and_shield()
	await _test_seeded_mine_chain_and_finale()
	await _test_trio_reaches_every_enemy()
	_holder.queue_free()
	await process_frame
	_report()


func _test_sentry_hex_and_cleanup() -> void:
	var host := _new_host()
	var target := _target(host, Vector2.ZERO)
	var permanent := Repairable.new()
	permanent.owner_node = host.player
	permanent.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(permanent)
	host.permanent_devices.append(permanent)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, SENTRY), "sentry package must activate")
	var activation = controller.active_activation()
	var spawned: Array[Node] = activation.spawned_for_tests()
	_check(spawned.size() == 6, "sentry must atomically deploy six temporary pylons")
	var positions := {}
	for node in spawned:
		var device := node as Node2D
		positions[device.global_position.round()] = true
		_check(device.get_meta("engineer_ultimate_device", "") == "sentry",
			"every temporary pylon must keep sentry identity")
		_check(is_equal_approx(device.global_position.length(), 210.0),
			"sentries must sit on the fixed hex radius")
	_check(positions.size() == 6, "sentry hex must contain six distinct seats")
	_check(target.health < target.max_health, "the first synchronized crossfire must deal damage")
	_check(not controller.activate(CLASS_ID, SENTRY), "an active cast must refuse re-entry")
	_check(is_instance_valid(permanent) and permanent.visible \
		and permanent.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"temporary crossfire must not replace or suspend the permanent device park")
	controller.cancel()
	await process_frame
	for node in spawned:
		_check(not is_instance_valid(node), "cancel must remove every temporary sentry")
	_check(is_instance_valid(permanent), "cancel must preserve the permanent device park")
	await _drop(host)


func _test_drone_intercept_repair_and_shield() -> void:
	var host := _new_host()
	var normal := _target(host, Vector2(100.0, 0.0))
	var epic := _target(host, Vector2(120.0, 0.0))
	epic.add_to_group("elite_enemies")
	var owned := Repairable.new()
	owned.owner_node = host.player
	host.add_child(owned)
	host.permanent_devices.append(owned)
	var foreign_owner := Node.new()
	host.add_child(foreign_owner)
	var foreign := Repairable.new()
	foreign.owner_node = foreign_owner
	host.add_child(foreign)
	host.permanent_devices.append(foreign)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, DRONES), "repair-drone package must activate")
	var activation = controller.active_activation()
	var spawned: Array[Node] = activation.spawned_for_tests()
	_check(spawned.size() == 12, "repair swarm must atomically deploy twelve microdrones")
	_check(normal.knockback_impulses.size() == 1 and epic.knockback_impulses.size() == 1,
		"the first intercept wave must reach every live target")
	if not normal.knockback_impulses.is_empty() and not epic.knockback_impulses.is_empty():
		_check(is_equal_approx(epic.knockback_impulses[0].length(),
			normal.knockback_impulses[0].length() * 0.35),
			"epic resistance must reduce intercept displacement to the declared 35 percent")
	_check(is_equal_approx(host.player.health, 60.0) and is_equal_approx(owned.health, 20.0),
		"the first repair pulse must restore actual missing HP to hero and owned device")
	_check(is_equal_approx(foreign.health, 10.0), "repair must refuse a foreign device")
	var first: Dictionary = activation.repair(host.player, 10.0, "manual_idempotency")
	var duplicate: Dictionary = activation.repair(host.player, 10.0, "manual_idempotency")
	_check(is_equal_approx(float(first["applied"]), 10.0) and duplicate["applied"] == 0.0,
		"repair event IDs must be idempotent and spend only actual restored HP")
	_advance(activation, 4.35)
	_check(controller.is_active() and float(host.modifiers.get("absorb_flat", 0.0)) > 0.0,
		"the final pulse must open a live shield window")
	controller.cancel()
	await process_frame
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))),
		"cancel must unwind the final shield")
	for node in spawned:
		_check(not is_instance_valid(node), "cancel must remove every microdrone")
	await _drop(host)


func _test_seeded_mine_chain_and_finale() -> void:
	var host := _new_host()
	host.base_damage = 1000.0
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, MINES), "pressure-mine package must activate")
	var activation = controller.active_activation()
	var state: Dictionary = activation.primitive_value("engineer_mine_state", {})
	var points := state.get("points", PackedVector2Array()) as PackedVector2Array
	var spawned: Array[Node] = activation.spawned_for_tests()
	_check(points.size() == 16 and spawned.size() == 16,
		"minefield must deploy all sixteen deterministic smart mines")
	var first_points: PackedVector2Array = activation.pattern_points(Vector2.ZERO, "seeded_annulus", {
		"count": 16, "inner_radius": 80.0, "outer_radius": 260.0, "seed": 1466,
	})
	_check(points == first_points, "mine placement must be reproducible from seed 1466")
	var mitigated := _target(host, points[0])
	mitigated.damage_taken_multiplier = 0.5
	var boss := _target(host, Vector2.ZERO)
	boss.add_to_group("bosses")
	_advance(activation, 0.75)
	var trace := state.get("trace", []) as Array
	_check(not trace.is_empty() and str((trace[0] as Dictionary).get("phase", "")) == "smart",
		"an occupied armed mine must start one local smart chain")
	_check(trace.size() <= 3, "the local chain must stay capped at one trigger plus two neighbors")
	var manual_target := _target(host, points[15])
	var before := manual_target.health
	Mines.detonate_mine(activation, state, 15, 1200.0, 20.0, "manual", false)
	var after_first := manual_target.health
	Mines.detonate_mine(activation, state, 15, 1200.0, 20.0, "manual", false)
	_check(after_first < before and is_equal_approx(manual_target.health, after_first),
		"a mine index must detonate once even when the same event is repeated")
	_advance(activation, 5.0)
	await process_frame
	var previous_distance := INF
	var finale_count := 0
	for raw_entry in trace:
		var entry := raw_entry as Dictionary
		if str(entry.get("phase", "")) != "finale":
			continue
		var distance := (entry.get("position", Vector2.ZERO) as Vector2).length()
		_check(distance <= previous_distance + 0.001,
			"the finale must detonate remaining mines from the outer ring inward")
		previous_distance = distance
		finale_count += 1
	_check(finale_count > 0, "the minefield must execute an outer-to-inner finale")
	_check(boss.max_health - boss.health <= boss.max_health * 0.08 + 0.001,
		"the entire mine activation must respect the inherited eight-percent boss cap")
	var actual_lost := (mitigated.max_health - mitigated.health) \
		+ (manual_target.max_health - manual_target.health) + (boss.max_health - boss.health)
	_check(is_equal_approx(activation.applied_total, actual_lost),
		"activation attribution must equal actual HP removed after mitigation and caps")
	_check(not controller.is_active(), "the finale tail must complete the activation")
	for node in spawned:
		_check(not is_instance_valid(node), "completion must remove every mine deploy")
	await _drop(host)


## Ultimate Direction v2 (FAN-2955): no count-shaped cap survives in the trio.
## Each weapon is cast against a crowd far larger than its old cap plus one
## silhouette parked thousands of pixels off-screen, and every one of them has
## to end the cast with HP removed.
func _test_trio_reaches_every_enemy() -> void:
	for weapon_id in [SENTRY, DRONES, MINES]:
		var host := _new_host()
		for index in 28:
			_target(host, Vector2(0.0, -270.0 + float(index) * 20.0))
		_target(host, Vector2(5000.0, -4000.0))
		var controller := Controller.new(host, _registry)
		_check(controller.activate(CLASS_ID, weapon_id),
			"%s map-wide fixture must activate" % weapon_id)
		var activation = controller.active_activation()
		# Past the longest declared cast in the trio (the swarm's 5.50 s), so a
		# sequence that resolves only on its final beat is measured after it.
		_advance(activation, 6.0)
		var reached := 0
		for raw_target in host.fixture_targets:
			if (raw_target as Target).health < (raw_target as Target).max_health:
				reached += 1
		_check(reached == host.fixture_targets.size(),
			"%s must reach every live enemy on the map, got %d of %d" % [
				weapon_id, reached, host.fixture_targets.size(),
			])
		controller.cancel()
		await process_frame
		await _drop(host)


func _new_host() -> Host:
	var host := Host.new()
	_holder.add_child(host)
	return host


func _target(host: Host, position: Vector2) -> Target:
	var target := Target.new()
	host.add_child(target)
	target.global_position = position
	host.fixture_targets.append(target)
	return target


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		var step := minf(STEP, seconds - elapsed)
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step


func _drop(host: Host) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("engineer_ultimate_mechanics_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("engineer_ultimate_mechanics_test: %s" % error)
	print("engineer_ultimate_mechanics_test: FAIL (%d)" % _errors.size())
	quit(1)
