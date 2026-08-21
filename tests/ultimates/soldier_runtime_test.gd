extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Grenade := preload("res://scripts/ultimates/classes/soldier/soldier_grenade.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPONS := ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]
const DATA_ROOT := "res://data/ultimates/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/classes"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 3000.0
	var max_health := 3000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(700.0, 0.0)
	var active := false
	var damage_calls := 0
	var base_damage := 10.0
	var modifiers: Array[Dictionary] = []

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_point - global_position
		var point := global_position + offset.normalized() * minf(offset.length(), max_range)
		return {"point": point, "direction": offset.normalized()}

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

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		modifiers.append({"key": key, "value": value, "operation": operation})

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


class ActiveRegistry extends RefCounted:
	var canonical_pairs: Dictionary
	var profiles: Dictionary = {}
	var executors: Dictionary = {}
	var pairs: Dictionary = {}

	func _init(source: Discovery, canonical: Dictionary) -> void:
		canonical_pairs = canonical.duplicate(true)
		pairs = source.pair_keys()
		for raw_key in pairs:
			var key := str(raw_key)
			profiles[key] = source.profile_for(key)
			executors[key] = source.executor_for(key)

	func resolution_source(class_id: String, weapon_id: String, _allow_legacy := true) -> String:
		var key := Resolver.profile_key(class_id, weapon_id)
		if not canonical_pairs.has(key):
			return Resolver.SOURCE_INVALID_PAIR
		if pairs.has(key) and str((profiles.get(key, {}) as Dictionary).get("implementation_state", "")) == "ready":
			return Resolver.SOURCE_WEAPON_PROFILE
		return Resolver.SOURCE_LEGACY_CLASS_FALLBACK

	func catalog_profile_for(class_id: String, weapon_id: String) -> Dictionary:
		return (profiles.get(Resolver.profile_key(class_id, weapon_id), {}) as Dictionary).duplicate(true)

	func executor_for(class_id: String, weapon_id: String):
		return executors.get(Resolver.profile_key(class_id, weapon_id))


var _errors: Array[String] = []
var _holder: Node2D
var _registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	var shipped := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(shipped.is_valid(), "the immutable catalog must remain valid")
	var active := Discovery.new(DATA_ROOT, SCRIPT_ROOT)
	active.discover(Schema.index_documents(shipped.documents_for_tests()))
	_check(active.validation_errors().is_empty(),
		"active runtime discovery must stay valid: %s" % [active.validation_errors()])
	_registry = ActiveRegistry.new(active, shipped.canonical_pairs_for_tests())
	await process_frame
	await _test_rifle_dense_corridor()
	await _test_grenade_chain_and_crater()
	await _test_bayonet_control_guard_and_cleanup()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_rifle_dense_corridor() -> void:
	var host := await _host()
	host.aim_point = Vector2(700.0, 0.0)
	var boss := _target(host, Vector2(690.0, 0.0), 3000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var wing_a := _target(host, Vector2(650.0, 35.0), 3000.0)
	var wing_b := _target(host, Vector2(740.0, -45.0), 3000.0)
	var off_corridor := _target(host, Vector2(680.0, 240.0), 3000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "soldier_rifle"), "rifle package must activate")
	var activation := controller.active_activation()
	_check(activation.composition_trace_for_tests() == [
		"aim_context", "priority_target_selector", "line_pierce_geometry", "aimed_sequence",
	], "rifle must use the admitted dense-corridor composition")
	_check(not controller.activate(CLASS_ID, "soldier_rifle"),
		"an active rifle cast must refuse re-entry")
	_advance(activation, 4.2)
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.09),
		"all three rifle volleys together must obey the nine-percent boss cap")
	_check(not wing_a.received.is_empty() and not wing_b.received.is_empty(),
		"the dense corridor must feed all three declared volley seats")
	_check(not off_corridor.received.is_empty(), "the rifle must apply its volley floor to every living enemy")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"rifle attribution must equal actual HP removed")
	_check(controller.is_active(), "rifle must remain active through its recovery window")
	_advance(activation, 1.5)
	await process_frame
	_check(not controller.is_active() and not host.active,
		"rifle completion must close controller and host state")
	await _drop(host)


func _test_grenade_chain_and_crater() -> void:
	var host := await _host()
	host.aim_point = Vector2(500.0, 0.0)
	var boss := _target(host, host.aim_point, 4000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	for offset in [
		Vector2(100.0, 0.0), Vector2(-100.0, 0.0), Vector2(0.0, 100.0),
		Vector2(0.0, -100.0), Vector2(180.0, 80.0), Vector2(-180.0, -80.0),
	]:
		_target(host, host.aim_point + offset, 3000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "soldier_grenade"), "grenade package must activate")
	var activation := controller.active_activation()
	var state := activation.primitive_value("soldier_grenade_state", {}) as Dictionary
	var points := state.get("points", PackedVector2Array()) as PackedVector2Array
	var spawned := activation.spawned_for_tests()
	_check(points.size() == 7 and spawned.size() == 7,
		"grenade must atomically deploy seven seeded activation-owned nodes")
	_check(points == activation.pattern_points(host.aim_point, "seeded_annulus", {
		"count": 7, "inner_radius": 90.0, "outer_radius": 260.0, "seed": 1469,
	}), "grenade placement must be reproducible from seed 1469")
	var hit_index := -1
	for raw_index in state["order"] as Array:
		var calls_before := host.damage_calls
		Grenade.detonate(activation, state, int(raw_index))
		if host.damage_calls > calls_before:
			hit_index = int(raw_index)
			break
	var calls_after := host.damage_calls
	Grenade.detonate(activation, state, hit_index)
	_check(hit_index >= 0 and host.damage_calls == calls_after,
		"a repeated grenade index must be idempotent")
	_advance(activation, 8.5)
	await process_frame
	_check(boss.max_health - boss.health <= boss.max_health * 0.09 + 0.001,
		"chain and crater ticks must share the nine-percent boss budget")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"grenade attribution must equal actual HP removed")
	_check(not controller.is_active() and not host.active,
		"grenade completion must close controller and host state")
	for node in spawned:
		_check(not is_instance_valid(node), "grenade completion must free every deploy")
	await _drop(host)


func _test_bayonet_control_guard_and_cleanup() -> void:
	var host := await _host()
	host.aim_point = Vector2(780.0, 0.0)
	var normal := _target(host, Vector2(180.0, 0.0), 3000.0)
	var epic := _target(host, Vector2(360.0, 0.0), 3000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(540.0, 0.0), 3000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "soldier_bayonet"), "bayonet package must activate")
	var activation := controller.active_activation()
	var spawned := activation.spawned_for_tests()
	var effect := spawned[0] if not spawned.is_empty() else null
	_check(effect != null and is_equal_approx(float(effect.call("guard_value_for_tests")), 0.25),
		"bayonet must open its declared 25-percent frontal guard")
	_check(host.modifiers == [{"key": "defense_flat", "value": 0.25, "operation": "add"}],
		"bayonet guard must use one activation-owned additive modifier")
	_advance(activation, 1.5)
	_check(_pin(normal).get("movement_locked", false) == true,
		"normal targets must receive the full pin")
	_check(is_equal_approx(float(_pin(normal).get("duration", 0.0)), 2.4),
		"normal pin duration must remain 2.4 seconds")
	_check(not _pin(epic).has("movement_locked")
		and is_equal_approx(float(_pin(epic).get("duration", 0.0)), 1.2),
		"epic resistance must remove the lock and halve duration")
	_check(not _pin(boss).has("movement_locked")
		and is_equal_approx(float(_pin(boss).get("duration", 0.0)), 0.6),
		"boss resistance must remove the lock and quarter duration")
	_check(normal.knockbacks.size() == 1 and is_equal_approx(normal.knockbacks[0].length(), 260.0),
		"normal displacement must keep the full declared impulse")
	_check(epic.knockbacks.size() == 1 and is_equal_approx(epic.knockbacks[0].length(), 65.0),
		"epic displacement must be reduced to one quarter")
	_check(boss.knockbacks.is_empty(), "bosses must never be displaced")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.09),
		"bayonet damage must obey the nine-percent boss cap")
	var calls_after_charge := host.damage_calls
	effect.call("charge_rank", 0)
	_check(host.damage_calls == calls_after_charge, "a repeated charge rank must be idempotent")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"bayonet attribution must equal actual HP removed")
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not host.active,
		"bayonet cancel must close controller and host state")
	_check(host.modifiers.size() == 2
		and host.modifiers[1] == {"key": "defense_flat", "value": -0.25, "operation": "add"},
		"bayonet cancel must unwind only its own guard modifier")
	_check(_pin(normal).is_empty() and _pin(epic).is_empty() and _pin(boss).is_empty(),
		"bayonet cleanup must remove all activation-owned control leases")
	_check(not is_instance_valid(effect), "bayonet cancel must free its activation-owned effect")
	await _drop(host)


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in WEAPONS:
		var row := Budget.row_for(rows, CLASS_ID, weapon_id)
		var ledger := Ledger.new(row)
		ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
		ledger.apply_start_charge(1.0)
		_check(ledger.try_activate(), "%s must spend one full charge" % weapon_id)
		ledger.apply_start_charge(1.0)
		_check(not ledger.try_activate(), "%s must refuse a second cast per encounter" % weapon_id)
		ledger.set_ultimate_active(true)
		var before := ledger.charge
		ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)
		_check(is_equal_approx(ledger.charge, before),
			"%s must earn no charge while active" % weapon_id)
		ledger.set_ultimate_active(false)
		ledger.apply_start_charge(0.63)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, 63.0),
			"%s charge must survive run snapshots" % weapon_id)


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _target(host: FixtureHost, position: Vector2, max_health: float) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = max_health
	target.max_health = max_health
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _advance(activation: Activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		var step := minf(STEP, seconds - elapsed)
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step


func _pin(target: Node) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("soldier_bayonet_pin_"):
			return (StatusEffects.snapshot(target)[status_id] as Dictionary).duplicate(true)
	return {}


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
		print("soldier_runtime_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("soldier_runtime_test: %s" % error)
	print("soldier_runtime_test: FAIL (%d)" % _errors.size())
	quit(1)
