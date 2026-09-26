extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Executor := preload("res://scripts/ultimates/classes/knight/long_spear.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "knight"
const WEAPON_ID := "long_spear"
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
	var aim_point := Vector2(780.0, 0.0)
	var active := false
	var damage_calls := 0
	var base_damage := 10.0
	var presentation_rows: Array[int] = []

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
		damage_calls += 1
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(event_id: String, payload: Dictionary) -> Node:
		if event_id == Executor.EXECUTOR_ID + ".row":
			presentation_rows.append(int(payload.get("row", 0)))
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_test_discovery_and_fail_closed_profile()
	await _test_phalanx_order_damage_and_control()
	await _test_cancel_replay_and_wrong_owner_cleanup()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_discovery_and_fail_closed_profile() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "the immutable catalog must remain valid")
	_check(_package_errors_for(registry, "knight/long_spear.json").is_empty(),
		"Long Spear package discovery must be clean: %s" % [registry.package_validation_errors()])
	_check(registry.resolution_source(CLASS_ID, WEAPON_ID) == Resolver.SOURCE_WEAPON_PROFILE,
		"exact knight/long_spear must resolve through its local ready profile")
	_check(registry.has_exact_executor_pair(CLASS_ID, WEAPON_ID),
		"Long Spear must expose exactly one local executor")
	for sibling in ["tower_shield", "holy_flail"]:
		var expected_source := Resolver.SOURCE_WEAPON_PROFILE if registry.has_exact_executor_pair(CLASS_ID, sibling) \
				else Resolver.SOURCE_LEGACY_CLASS_FALLBACK
		_check(registry.resolution_source(CLASS_ID, sibling) == expected_source,
			"%s must not leak Long Spear readiness" % sibling)
	var profile := registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	var executor = registry.executor_for(CLASS_ID, WEAPON_ID)
	_check(str(profile.get("implementation_state", "")) == "ready", "Long Spear must be ready")
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.09),
		"Long Spear must keep its nine-percent boss cap")
	_check(executor is GDScript and (executor as GDScript).resource_path.ends_with("knight/long_spear.gd"),
		"Long Spear must load only its class-local executor")
	var executor_params: Variant = (profile.get("executor", {}) as Dictionary).get("params", {})
	_check(executor_params is Dictionary and not (executor_params as Dictionary).has("target_limit"),
		"Long Spear must not admit a count-shaped target limit")
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/knight/long_spear.json"
	))
	if not document is Dictionary or not executor is GDScript:
		_check(false, "Long Spear package fixtures must load")
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["unbounded_row"] = true
	var base_profiles := Schema.index_documents(registry.documents_for_tests())
	var result := Discovery.new().validate_pair(mutated, "knight/long_spear.json", executor,
		base_profiles["knight/long_spear"])
	_check(_has_error(result.get("errors", []) as Array, "executor_params.unknown"),
		"unknown Long Spear mechanics must fail closed: %s" % [result.get("errors", [])])


func _test_phalanx_order_damage_and_control() -> void:
	var host := await _host()
	var first := _target(host, Vector2(120.0, 0.0))
	var second := _target(host, Vector2(240.0, 0.0))
	var third := _target(host, Vector2(360.0, 0.0))
	var epic := _target(host, Vector2(480.0, 0.0))
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(600.0, 0.0))
	boss.add_to_group(Activation.BOSS_GROUP)
	var crowd_targets: Array[FixtureTarget] = [first, second, third, epic, boss]
	for index in 15:
		crowd_targets.append(_target(host, Vector2(610.0 + float(index) * 10.0, 0.0)))
	var off_corridor := _target(host, Vector2(360.0, 180.0))
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var controller := Controller.new(host, registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Long Spear must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null, "Long Spear must spawn its activation-owned scene")
	_advance(activation, 1.0)
	_check(effect != null and effect.get("row_order_for_tests") == [1, 2, 3],
		"three phalanx rows must advance in order")
	_check(host.presentation_rows == [1, 2, 3], "every row must have a distinct presentation event")
	for pair in [[first, 1], [second, 2], [third, 3], [epic, 1], [boss, 2]]:
		var target := pair[0] as FixtureTarget
		var expected_row := int(pair[1])
		_check(target.received.size() == 1, "every corridor target must receive one pierce hit")
		if not target.received.is_empty():
			var feedback := target.received[0]["feedback"] as Dictionary
			_check(str(feedback.get("damage_type", "")) == "pierce"
				and int(feedback.get("phalanx_row", 0)) == expected_row,
				"pierce hit must retain its assigned phalanx row")
		_check(int(activation.target_value(target, Executor.HIT_KEY, 0)) == expected_row,
			"target ledger must claim the target exactly once before its row hit")
	for target in crowd_targets:
		_check(target.received.size() == 1,
			"every one of 20 eligible corridor targets must receive one pierce hit")
	_check(off_corridor.received.is_empty(), "the phalanx corridor must not leak sideways")
	for target in [first, second, third]:
		_check(target.knockbacks.size() == 1 and is_equal_approx(target.knockbacks[0].length(), 180.0),
			"normal targets must receive the declared stagger")
		_check(_pin(target).get("movement_locked", false) == true,
			"normal targets must receive the pin")
	_check(epic.knockbacks.is_empty() and boss.knockbacks.is_empty()
		and _pin(epic).is_empty() and _pin(boss).is_empty(),
		"epic and boss controls must fail closed")
	var calls := host.damage_calls
	if effect != null:
		for row in 3:
			effect.call("advance_row", row)
	_check(host.damage_calls == calls, "replayed row callbacks must not duplicate any hit")
	_advance(activation, 0.8)
	await process_frame
	_check(not controller.is_active() and not host.active, "completion must clear the active owner state")
	_check(activation.spawned_for_tests().is_empty() and _pin(first).is_empty(),
		"completion must clear transient nodes and leased pins")
	await _drop(host)


func _test_cancel_replay_and_wrong_owner_cleanup() -> void:
	var host := await _host()
	var target := _target(host, Vector2(180.0, 0.0))
	var controller := Controller.new(host, Registry.new(PD.WEAPONS_BY_CLASS))
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Long Spear cancel fixture must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, STEP)
	var calls := host.damage_calls
	var foreign := Executor.new()
	_holder.add_child(foreign)
	foreign.call("advance_row", 0)
	_check(host.damage_calls == calls, "an unowned phalanx scene must fail closed")
	foreign.queue_free()
	controller.cancel()
	if effect != null:
		effect.call("advance_row", 1)
	_check(host.damage_calls == calls and activation.target_ledger_size_for_tests() == 0,
		"stale or cancelled callbacks must not retain ledger state or damage")
	await process_frame
	_check(not controller.is_active() and not host.active and activation.spawned_for_tests().is_empty()
		and _pin(target).is_empty(),
		"cancel, death, encounter end and Continue cleanup must leave no phalanx state")
	await _drop(host)


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var row := Budget.row_for(rows, CLASS_ID, WEAPON_ID)
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate() and is_zero_approx(ledger.charge),
		"Long Spear must spend its charge exactly once")
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate(), "Long Spear must refuse a duplicate encounter activation")
	ledger.set_ultimate_active(true)
	var before := ledger.charge
	ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)
	_check(is_equal_approx(ledger.charge, before), "Long Spear must not refill while active")
	ledger.set_ultimate_active(false)
	ledger.apply_start_charge(0.63)
	var continued := Ledger.new(row)
	continued.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(continued.charge, 63.0) and not continued.is_ultimate_active(),
		"Continue must retain charge but clear the transient active state")


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _target(host: FixtureHost, position: Vector2) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
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


func _pin(target: Node) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("knight_long_spear_pin_"):
			return (StatusEffects.snapshot(target)[status_id] as Dictionary).duplicate(true)
	return {}


func _has_error(errors: Array, prefix: String) -> bool:
	for error in errors:
		if str(error).contains(prefix):
			return true
	return false


func _package_errors_for(registry: Registry, relative_path: String) -> Array:
	var matched: Array = []
	for error in registry.package_validation_errors():
		if str(error).begins_with(relative_path + ":"):
			matched.append(error)
	return matched


func _drop(host: FixtureHost) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("knight_long_spear_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("knight_long_spear_test: %s" % error)
	print("knight_long_spear_test: FAIL (%d)" % _errors.size())
	quit(1)
