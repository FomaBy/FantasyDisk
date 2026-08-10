extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Executor := preload("res://scripts/ultimates/classes/knight/tower_shield.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "knight"
const WEAPON_ID := "tower_shield"
const STEP := 0.01


class Target extends Node2D:
	var health := 1000.0
	var max_health := 1000.0
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false

	func ultimate_host_context() -> Dictionary:
		return {"damage": 10.0, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, _limit: int) -> Array:
		var found: Array = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		return found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		if target != null and is_instance_valid(target):
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
	_test_discovery_and_parameter_contract()
	await _test_measured_guard_counter_and_cleanup()
	await _test_completion_and_player_lifecycle()
	_test_charge_contract()
	_holder.queue_free()
	current_scene = null
	await process_frame
	_report()


func _test_discovery_and_parameter_contract() -> void:
	_check(_registry.is_valid(), "the immutable catalog must remain valid")
	_check(_package_errors_for(_registry, "knight/tower_shield.json").is_empty(),
		"Tower Shield package discovery must be clean: %s" % [_registry.package_validation_errors()])
	_check(_registry.resolution_source(CLASS_ID, WEAPON_ID) == Resolver.SOURCE_WEAPON_PROFILE,
		"the exact Knight/Tower Shield pair must auto-resolve through its local package")
	_check(_registry.has_exact_executor_pair(CLASS_ID, WEAPON_ID),
		"Tower Shield must expose exactly one local executor")
	_check(_registry.resolution_source("robot", WEAPON_ID) != Resolver.SOURCE_WEAPON_PROFILE,
		"Tower Shield readiness must not leak across classes")
	var profile: Dictionary = _registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	var executor = _registry.executor_for(CLASS_ID, WEAPON_ID)
	_check(str(profile.get("implementation_state", "")) == "ready"
		and is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.07),
		"Tower Shield must retain the ready seven-percent boss rail")
	_check(executor is GDScript and (executor as GDScript).resource_path.ends_with("knight/tower_shield.gd"),
		"Tower Shield must load only its class-local executor")
	var document = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ultimates/classes/knight/tower_shield.json"
	))
	if not document is Dictionary or not executor is GDScript:
		_check(false, "Tower Shield package fixtures must load")
		return
	var mutated := (document as Dictionary).duplicate(true)
	((mutated["executor"] as Dictionary)["params"] as Dictionary)["nominal_prevention"] = true
	var base_profiles := Schema.index_documents(_registry.documents_for_tests())
	var result := Discovery.new().validate_pair(mutated, "knight/tower_shield.json", executor,
		base_profiles["knight/tower_shield"])
	_check(_has_error(result.get("errors", []) as Array, "executor_params.unknown"),
		"undeclared nominal-prevention tuning must fail closed: %s" % [result.get("errors", [])])


func _test_measured_guard_counter_and_cleanup() -> void:
	var host := await _host()
	var normal := _target(host, Vector2(90.0, 0.0))
	var epic := _target(host, Vector2(110.0, 8.0))
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(130.0, -8.0))
	boss.add_to_group(Activation.BOSS_GROUP)
	var behind := _target(host, Vector2(-80.0, 0.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Tower Shield must activate")
	var activation := controller.active_activation()
	var effect = _effect(activation)
	_check(effect != null and not str(effect.get("guard_owner_id_for_tests")).is_empty(),
		"the guard effect must declare one activation-local owner")
	if effect == null:
		await _drop(host)
		return
	var owner_id := str(effect.get("guard_owner_id_for_tests"))
	_check(activation.record_guard_prevention(_event(owner_id, "wrong_owner", {"owner_id": "foreign"})) == 0.0,
		"a prevention event from another owner must fail closed")
	_check(activation.record_guard_prevention(_event(owner_id, "wrong_source", {"source": "projectile"})) == 0.0,
		"an undeclared prevention source must fail closed")
	_check(activation.record_guard_prevention(_event(owner_id, "wrong_direction", {"direction": Vector2.LEFT})) == 0.0,
		"a hit outside the shield-facing arc must fail closed")
	_check(activation.record_guard_prevention(_event(owner_id, "nominal", {"prevented_amount": 90.0})) == 0.0,
		"a nominal value that differs from measured prevention must fail closed")
	var first := _event(owner_id, "first")
	_check(is_equal_approx(activation.record_guard_prevention(first), 50.0),
		"the eligible event must store its final measured prevention")
	_check(activation.record_guard_prevention(first) == 0.0,
		"a replayed guard event must not double count")
	_check(is_equal_approx(activation.record_guard_prevention(_event(owner_id, "capped", {
		"applied_amount": 0.0, "prevented_amount": 100.0,
	})), 30.0), "the guard cap must admit only its remaining measured value")
	_check(is_equal_approx(activation.owner_resource_amount(owner_id, Executor.RESOURCE_ID), 80.0),
		"only eligible measured prevention may fill the capped wall ledger")

	effect.call("counter_burst")
	_check(is_equal_approx(float(effect.get("counter_amount_for_tests")), 80.0)
		and int(effect.get("counter_target_count_for_tests")) == 3,
		"the one-shot counter must consume the stored resource once for front targets")
	_check(normal.knockbacks.size() == 1 and is_equal_approx(normal.knockbacks[0].length(), 230.0),
		"normal targets must receive the full wall push")
	_check(epic.knockbacks.size() == 1 and is_equal_approx(epic.knockbacks[0].length(), 57.5),
		"epic targets must receive the declared resistance")
	_check(boss.knockbacks.is_empty() and _counter_status(boss).is_empty(),
		"bosses must be immune to Tower Shield counter control")
	_check(behind.knockbacks.is_empty() and is_equal_approx(behind.health, behind.max_health),
		"a rear target must remain outside the counter arc")
	_check(not _counter_status(normal).is_empty()
		and is_equal_approx(float(_counter_status(epic).get("duration", 0.0)), 0.425),
		"counter statuses must preserve normal duration and epic resistance")
	var normal_health := normal.health
	effect.call("counter_burst")
	_check(is_equal_approx(normal.health, normal_health)
		and activation.consume_owner_resource(owner_id, Executor.RESOURCE_ID, "counter_replay").get("amount", 0.0) == 0.0,
		"the spent counter must not replay or emit a second resource")

	controller.cancel()
	effect.call("counter_burst")
	_check(activation.is_finished() and activation.record_guard_prevention(_event(owner_id, "stale")) == 0.0
		and activation.guard_prevention_owner_id().is_empty(),
		"cancel must reject stale prevention and clear the active guard owner")
	await process_frame
	_check(not is_instance_valid(effect) and not controller.is_active() and not host.active
		and _counter_status(normal).is_empty() and _counter_status(epic).is_empty(),
		"cancel must clear the effect, owner state, and only its leased controls")
	await _drop(host)


func _test_completion_and_player_lifecycle() -> void:
	var host := await _host()
	var controller := Controller.new(host, _registry)
	_check(not controller.activate("robot", WEAPON_ID), "a cross-class Tower Shield pair must fail closed")
	_check(controller.activate(CLASS_ID, WEAPON_ID), "completion fixture must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 8.7)
	await process_frame
	_check(activation.is_finished() and not controller.is_active() and not host.active
		and not is_instance_valid(effect), "natural completion must clear every transient guard resource")
	await _drop(host)

	var player := await _spawn_player()
	controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "the real Player path must activate Tower Shield")
	activation = controller.active_activation()
	effect = _effect(activation)
	controller.cancel()
	await process_frame
	_check(activation.is_finished() and not controller.is_active() and not bool(player.get("_ultimate_active"))
		and not is_instance_valid(effect), "encounter cancel must clear the live Player guard")
	await _drop_player(player)

	player = await _spawn_player()
	controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "Continue fixture must activate Tower Shield")
	activation = controller.active_activation()
	effect = _effect(activation)
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	_check(activation.is_finished() and not controller.is_active() and not bool(player.get("_ultimate_active"))
		and not is_instance_valid(effect), "Continue/new-run reset must clear the live guard")
	await _drop_player(player)

	player = await _spawn_player()
	controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "death fixture must activate Tower Shield")
	activation = controller.active_activation()
	effect = _effect(activation)
	player.queue_free()
	await process_frame
	_check(activation.is_finished() and not controller.is_active() and not is_instance_valid(effect),
		"player node exit must clear the activation and every transient node")


func _test_charge_contract() -> void:
	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate() and is_zero_approx(ledger.charge),
		"Tower Shield must spend a full charge exactly once")
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(100000.0)),
		"a live Tower Shield must not refill from its own counter")
	ledger.set_ultimate_active(false)
	ledger.apply_start_charge(0.63)
	var continued := Ledger.new(row)
	continued.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(continued.charge, 63.0) and not continued.is_ultimate_active(),
		"Continue must preserve charge while clearing transient active state")


func _host() -> Host:
	var host := Host.new()
	_holder.add_child(host)
	await process_frame
	return host


func _target(host: Host, position: Vector2) -> Target:
	var target := Target.new()
	host.add_child(target)
	target.global_position = position
	host.fixture_targets.append(target)
	return target


func _spawn_player() -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.global_position = Vector2(900.0, 700.0)
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	var weapon := player.get("equipped_weapon") as Node
	if weapon != null:
		weapon.set_process(false)
		weapon.set_physics_process(false)
	return player


func _effect(activation) -> Node:
	if activation == null:
		return null
	var spawned: Array = activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _event(owner_id: String, event_id: String, overrides: Dictionary = {}) -> Dictionary:
	var event := {
		"event_id": event_id,
		"owner_id": owner_id,
		"source": "contact",
		"direction": Vector2.RIGHT,
		"incoming_amount": 100.0,
		"applied_amount": 50.0,
		"prevented_amount": 50.0,
	}
	event.merge(overrides, true)
	return event


func _counter_status(target: Node) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("knight_tower_shield_push_"):
			return (StatusEffects.snapshot(target)[status_id] as Dictionary).duplicate(true)
	return {}


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		var step := minf(STEP, seconds - elapsed)
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step


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


func _drop(host: Host) -> void:
	if is_instance_valid(host):
		host.queue_free()
	await process_frame


func _drop_player(player: Node2D) -> void:
	if player != null and is_instance_valid(player):
		player.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("knight_tower_shield_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("knight_tower_shield_test: %s" % error)
	print("knight_tower_shield_test: FAIL (%d)" % _errors.size())
	quit(1)
