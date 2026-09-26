extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "knight"
const WEAPON_ID := "holy_flail"
const PAIR_KEY := "knight/holy_flail"
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
	var base_damage := 10.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT * max_range, "direction": Vector2.RIGHT}

	## Deliberate duplicate rows prove package-level target uniqueness.
	func ultimate_host_targets(center: Vector2, radius: float, _limit: int) -> Array:
		var found: Array = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
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
var _registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_test_discovery()
	await _test_ordered_pull_launch()
	await _test_wrong_pair_fails_closed()
	_test_charge_and_continue_contract()
	await _test_real_player_lifecycle()
	_holder.queue_free()
	current_scene = null
	await process_frame
	_report()


func _test_discovery() -> void:
	_check(_registry.is_valid(), "the immutable 51-profile catalog must remain valid")
	_check(_registry.package_validation_errors().is_empty(),
		"Holy Flail package admission must be clean: %s" % [_registry.package_validation_errors()])
	_check(_registry.resolution_source(CLASS_ID, WEAPON_ID) == Resolver.SOURCE_WEAPON_PROFILE,
		"the exact Knight/Holy Flail pair must auto-resolve through its local package")
	_check(_registry.has_exact_executor_pair(CLASS_ID, WEAPON_ID),
		"the exact pair must own one executor")
	var knight_pairs: Array[String] = []
	for key in _registry.package_pair_keys():
		if str(key).begins_with(CLASS_ID + "/"):
			knight_pairs.append(str(key))
	knight_pairs.sort()
	_check(knight_pairs == [PAIR_KEY, "knight/long_spear", "knight/tower_shield"],
		"the shipped Knight package set must contain its exact three weapons")
	_check(_registry.resolution_source(CLASS_ID, "long_spear") == Resolver.SOURCE_WEAPON_PROFILE
		and _registry.resolution_source(CLASS_ID, "tower_shield") == Resolver.SOURCE_WEAPON_PROFILE,
		"both shipped sibling Knight weapons must keep their exact package routes")
	_check(_registry.executor_for(CLASS_ID, "long_spear") != _registry.executor_for(CLASS_ID, WEAPON_ID)
		and _registry.executor_for(CLASS_ID, "tower_shield") != _registry.executor_for(CLASS_ID, WEAPON_ID),
		"each Knight weapon must retain its own executor")
	_check(_registry.executor_for("robot", "robot_magnetic_anchor")
		!= _registry.executor_for(CLASS_ID, WEAPON_ID),
		"the Holy Flail executor must not leak across classes")
	var profile: Dictionary = _registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	_check(str((profile.get("charge", {}) as Dictionary).get("strategy_id", ""))
		== "rare_charge_ledger", "Holy Flail must use the one-cast encounter gate")
	_check(str((profile.get("cleanup_policy", {}) as Dictionary).get("strategy_id", ""))
		== "activation_owned", "Holy Flail must use activation-owned cleanup")
	_check(profile.get("total_boss_cap") is float
		and is_equal_approx(float(profile.get("total_boss_cap")), 0.07),
		"Holy Flail must inherit Knight's seven-percent whole-activation boss cap")


func _test_ordered_pull_launch() -> void:
	var host := _host()
	var normal := _target(host, Vector2(80.0, 0.0))
	var epic := _target(host, Vector2(80.0, 10.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(80.0, -10.0))
	boss.add_to_group("bosses")
	var crowd: Array[Target] = []
	for index in 22:
		crowd.append(_target(host, Vector2(70.0, -50.0 + float(index) * 5.0)))
	var outer := _target(host, Vector2(410.0, 0.0))
	var outside := _target(host, Vector2(450.0, 0.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Holy Flail must activate")
	var activation = controller.active_activation()
	_check(activation != null and activation.spawned_for_tests().size() == 1,
		"one activation must own exactly one spiral scene")
	var effect = activation.spawned_for_tests()[0]

	_advance(activation, 1.61)
	var state: Dictionary = activation.primitive_value("knight_holy_flail", {})
	_check(state.get("turns", []) == ["pull_0"], "the first ordered turn must be inward")
	_check(normal.knockbacks.size() == 1 and normal.knockbacks[0].x < 0.0,
		"the first turn must pull a normal toward the source")
	_check(epic.knockbacks.size() == 1
		and is_equal_approx(epic.knockbacks[0].length(), normal.knockbacks[0].length() * 0.35),
		"epic displacement must retain exactly 35 percent of the pull")
	_check(boss.knockbacks.is_empty(), "a boss must never move on an early turn")
	var first_health := normal.health
	effect.call("turn", 0)
	_check(normal.knockbacks.size() == 1 and is_equal_approx(normal.health, first_health),
		"a replayed turn must add neither impulse nor damage")

	_advance(activation, 4.45)
	_check((state.get("turns", []) as Array).size() == 6,
		"six early turns must resolve before the final ring")
	_check(normal.knockbacks.size() == 6 and normal.knockbacks.back().x < 0.0,
		"every early normal impulse must remain inward")
	_check(outer.knockbacks.is_empty() and is_equal_approx(outer.health, outer.max_health),
		"the expanding spiral must not reach the outer-ring target early")
	_advance(activation, 0.06)
	_check((state.get("turns", []) as Array).size() == 7
		and str((state.get("turns", []) as Array).back()) == "launch_6",
		"the seventh and final ring must be the only launch")
	_check(int(state.get("direction_switches", 0)) == 1
		and int(effect.get("direction_switches_for_tests")) == 1,
		"the impulse direction must switch exactly once")
	_check(normal.knockbacks.size() == 7 and normal.knockbacks.back().x > 0.0,
		"the final normal impulse must launch outward")
	_check(outer.knockbacks.size() == 1 and outer.knockbacks[0].x > 0.0,
		"the final expanded ring must launch its newly reached target")
	_check(boss.knockbacks.is_empty(), "the final ring must not move a boss")
	_check(outside.knockbacks.is_empty() and is_equal_approx(outside.health, outside.max_health),
		"targets beyond the declared outer radius must remain untouched")

	var radii := state.get("radii", []) as Array
	_check(radii.size() == 7 and is_equal_approx(float(radii[0]), 90.0)
		and is_equal_approx(float(radii[6]), 430.0),
		"ordered radii must measure 90 through 430 pixels")
	for index in range(1, radii.size()):
		_check(float(radii[index]) > float(radii[index - 1]),
			"spiral radii must grow strictly at turn %d" % index)
	_check(normal.knockbacks.size() == 7,
		"duplicate host rows must still yield one control event per target and turn")
	for target in crowd:
		_check(target.knockbacks.size() == 7,
			"every eligible crowded target must receive every spiral turn without a count cap")
	_check(normal.max_health - normal.health <= normal.max_health * 0.35 + 0.001,
		"normal damage must respect the per-target rail")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.07),
		"all seven boss contacts must share the seven-percent activation cap")
	_check(is_equal_approx(activation.applied_total, _removed(host)),
		"damage attribution must equal actual unique HP removed")
	_check(_status(epic).get("duration", 0.0) <= 0.6 + 0.001,
		"epic control duration must use the declared resistance")

	var impulse_count := normal.knockbacks.size()
	var health_before_stale := normal.health
	controller.cancel()
	effect.call("turn", 6)
	_check(normal.knockbacks.size() == impulse_count and is_equal_approx(normal.health, health_before_stale),
		"a stale post-cancel callback must fail closed")
	_check(activation.is_finished() and activation.spawned_for_tests().is_empty()
		and activation.tweens_for_tests().is_empty()
		and activation.primitive_value("knight_holy_flail") == null
		and activation.target_ledger_size_for_tests() == 0
		and activation.guard_prevention_owner_id().is_empty(),
		"cancel must clear transient nodes, timing, ledgers and owner resources")
	await process_frame
	_check(not is_instance_valid(effect) and not controller.is_active() and not host.active,
		"cancel must free the spiral scene and clear active state")
	for target in [normal, epic, boss, outer]:
		_check(not _has_spiral_status(target), "cleanup must remove only the spiral's leased status")
	await _drop(host)


func _test_wrong_pair_fails_closed() -> void:
	var host := _host()
	var controller := Controller.new(host, _registry)
	_check(not controller.activate("robot", WEAPON_ID),
		"a cross-class owner pair must fail closed")
	_check(not controller.activate(CLASS_ID, "tower_shield_alias"),
		"an unknown Knight pair must fail closed")
	_check(not controller.is_active() and host.get_child_count() == 0,
		"a refused owner pair must allocate no transient node")
	await _drop(host)


func _test_charge_and_continue_contract() -> void:
	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.charge = Budget.MAX_CHARGE
	_check(ledger.try_activate() and is_zero_approx(ledger.charge),
		"one full bar must be spent exactly once")
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(100000.0)) and is_zero_approx(ledger.charge),
		"the active effect must not refill itself")
	ledger.set_ultimate_active(false)
	ledger.charge = Budget.MAX_CHARGE
	_check(not ledger.try_activate() and is_equal_approx(ledger.charge, Budget.MAX_CHARGE),
		"a refused second encounter cast must not spend the refilled bar")
	ledger.set_ultimate_active(true)
	ledger.charge = 63.0
	var restored := Ledger.new(row)
	restored.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(restored.charge, 63.0) and not restored.is_ultimate_active()
		and restored.encounter_activations() == 0,
		"Continue must restore charge but no transient active state or encounter latch")


func _test_real_player_lifecycle() -> void:
	var player := await _spawn_player()
	var controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "the real Player path must activate Holy Flail")
	var activation = controller.active_activation()
	var effect = activation.spawned_for_tests()[0]
	_check(is_zero_approx(float(player.get("ultimate_charge"))) and bool(player.get("_ultimate_active")),
		"Player activation must spend charge once and own the active latch")
	player.call("_gain_ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(is_zero_approx(float(player.get("ultimate_charge")))
		and not bool(player.call("activate_ultimate")),
		"the live Player effect must block refill and re-entry")
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and not is_instance_valid(effect),
		"cancel/encounter end must clear the real Player and scene")
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(not bool(player.call("activate_ultimate"))
		and is_equal_approx(float(player.get("ultimate_charge")), float(player.get("ultimate_max_charge"))),
		"same-encounter refill must remain unspent and refused")
	await _drop_player(player)

	player = await _spawn_player()
	controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "completion fixture must activate")
	activation = controller.active_activation()
	effect = activation.spawned_for_tests()[0]
	_advance(activation, 7.7)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation.is_finished() and not is_instance_valid(effect),
		"natural completion must clear controller, latch and transient scene")
	await _drop_player(player)

	player = await _spawn_player()
	controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "new-run fixture must activate")
	activation = controller.active_activation()
	effect = activation.spawned_for_tests()[0]
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation.is_finished() and not is_instance_valid(effect),
		"new run/Continue reset must clear the previous transient activation")
	await _drop_player(player)

	player = await _spawn_player()
	controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "death fixture must activate")
	activation = controller.active_activation()
	effect = activation.spawned_for_tests()[0]
	player.queue_free()
	await process_frame
	_check(not controller.is_active() and activation.is_finished() and not is_instance_valid(effect),
		"death/node exit must clear the activation and every transient node")


func _host() -> Host:
	var host := Host.new()
	_holder.add_child(host)
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


func _advance(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.is_finished():
		var step := minf(STEP, seconds - elapsed)
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step


func _status(target: Node) -> Dictionary:
	if not target.has_meta(StatusEffects.META_KEY):
		return {}
	for raw_status in (target.get_meta(StatusEffects.META_KEY) as Dictionary).values():
		if raw_status is Dictionary and (raw_status as Dictionary).has("holy_flail_turn"):
			return raw_status as Dictionary
	return {}


func _has_spiral_status(target: Node) -> bool:
	return not _status(target).is_empty()


func _removed(host: Host) -> float:
	var total := 0.0
	for target in host.fixture_targets:
		total += target.max_health - target.health
	return total


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
		print("knight_holy_flail_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("knight_holy_flail_test: %s" % error)
	print("knight_holy_flail_test: FAIL (%d)" % _errors.size())
	quit(1)
