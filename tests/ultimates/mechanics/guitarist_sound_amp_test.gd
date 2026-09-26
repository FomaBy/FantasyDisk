extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "guitarist"
const WEAPON_ID := "sound_amp"
const STEP := 0.01
const FULL_FLOOR := 108.0


class Target extends Node2D:
	var health := 100000.0
	var max_health := 100000.0
	var knockback_calls := 0

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)

	func apply_knockback(_impulse: Vector2) -> void:
		knockback_calls += 1


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 1.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

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
var _measurements: Array[Dictionary] = []


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(_registry.package_validation_errors().is_empty(),
		"Sound Amp package must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_every_enemy_gets_the_floor()
	await _test_v2_power_corridor()
	await _test_caps_and_control_resistance()
	_test_charge_lifecycle()
	_holder.queue_free()
	await process_frame
	_report()


## FAN-3285 / Ultimate Direction v2: the square shape stays presentation, but
## all four feedback pulses plus the overload guarantee 108.0 damage to every
## live enemy, on the map or off it, with no fixed crowd cap left to drop any.
func _test_every_enemy_gets_the_floor() -> void:
	for count in [1, 5, 10, 20]:
		var host := _new_host(1.0)
		for index in count:
			_target(host, Vector2(200.0 + float(index) * 60.0, -400.0 + float(index) * 40.0))
		if count == 20:
			host.fixture_targets.back().global_position = Vector2(6000.0, -5000.0)
		var controller := Controller.new(host, _registry)
		_check(controller.activate(CLASS_ID, WEAPON_ID), "%d-target amp fixture must activate" % count)
		var activation = controller.active_activation()
		_advance(activation, 2.5)
		var removed := _removed_health(host.fixture_targets)
		var reached := 0
		for target in host.fixture_targets:
			var loss: float = target.max_health - target.health
			if loss > 0.0:
				reached += 1
			_check(is_equal_approx(loss, FULL_FLOOR),
				"%d-target amp fixture must give each enemy the 108.0 guaranteed floor, got %.2f" \
					% [count, loss])
			_check((target as Target).knockback_calls == 1,
				"%d-target amp fixture must knock back every reached enemy exactly once" % count)
		_measurements.append({"targets": count, "total": removed, "per_target": removed / float(count)})
		_check(reached == count and is_equal_approx(removed, FULL_FLOOR * float(count)),
			"%d-target v2 corridor must reach every enemy, got %d and %.1f total" % [count, reached, removed])
		controller.cancel()
		await process_frame
		await _drop(host)


func _test_v2_power_corridor() -> void:
	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	var weapon := PD.weapon(CLASS_ID, WEAPON_ID)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base := float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])
	var host := _new_host(base)
	var focused := _target(host, Vector2(0.0, 0.0), 100000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "v2 power fixture must activate")
	var activation = controller.active_activation()
	_advance(activation, 2.5)
	var output: float = focused.max_health - focused.health
	var floor: float = FULL_FLOOR * base
	print("sound_amp_v2 power=%.2f floor=%.2f corridor=%.2f..%.2f" % [
		output, floor, float(row["power_budget_min"]), float(row["power_budget_max"]),
	])
	_check(output >= float(row["power_budget_min"]) and output <= float(row["power_budget_max"]),
		"focused Wall of Sound output %.2f must stay inside the v2 corridor %.2f..%.2f" % [
			output, row["power_budget_min"], row["power_budget_max"],
		])
	for count in [1, 5, 10, 20]:
		var required := Budget.PER_ENEMY_FLOOR_FRACTION \
			* Budget.live_standard_pool(float(row["reference_solo_dps"])) / float(count)
		_check(floor >= required - 0.001,
			"the %d-enemy v2 floor %.2f must cover %.2f" % [count, floor, required])
	controller.cancel()
	await process_frame
	await _drop(host)


func _test_caps_and_control_resistance() -> void:
	var host := _new_host(10.0)
	var normal := _target(host, Vector2(0.0, -24.0), 300.0)
	var epic := _target(host, Vector2(0.0, -12.0), 300.0)
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(0.0, 12.0), 1000.0)
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "cap-and-control fixture must activate")
	var activation = controller.active_activation()
	_advance(activation, 2.5)
	_check(is_equal_approx(normal.max_health - normal.health, 90.0),
		"the 30 percent per-target cap must still bind the normal enemy, got %.2f" \
			% (normal.max_health - normal.health))
	_check(is_equal_approx(epic.max_health - epic.health, 90.0),
		"the 30 percent per-target cap must still bind the elite enemy, got %.2f" \
			% (epic.max_health - epic.health))
	_check(is_equal_approx(boss.max_health - boss.health, 90.0),
		"the whole activation must retain the nine-percent boss cap, got %.2f" \
			% (boss.max_health - boss.health))
	_check(normal.knockback_calls == 1 and epic.knockback_calls == 1 and boss.knockback_calls == 0,
		"the boss control policy must still refuse overload displacement while normal/epic keep it")
	_check(_status_duration(normal, "feedback:3:") > _status_duration(epic, "feedback:3:")
		and _status_duration(epic, "feedback:3:") > _status_duration(boss, "feedback:3:"),
		"feedback control duration shaping (normal > epic > boss) must remain in place")
	_check(is_equal_approx(activation.applied_total, 270.0),
		"damage attribution must preserve the shaped normal, elite and boss totals")
	controller.cancel()
	await process_frame
	await _drop(host)


func _test_charge_lifecycle() -> void:
	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate() and is_zero_approx(ledger.charge),
		"a full charge must buy exactly one Sound Amp activation")
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(100000.0)),
		"the active amp field must not earn dealt-damage charge")
	ledger.set_ultimate_active(false)
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate(), "the same encounter must reject a second activation")
	var restored := Ledger.new(row)
	restored.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(restored.charge, Budget.MAX_CHARGE)
		and not restored.is_ultimate_active() and restored.encounter_activations() == 0,
		"Continue must retain charge but clear the active and encounter latches")


func _new_host(base_damage: float) -> Host:
	var host := Host.new()
	host.base_damage = base_damage
	_holder.add_child(host)
	return host


func _target(host: Host, position: Vector2, max_health := 100000.0) -> Target:
	var target := Target.new()
	target.max_health = max_health
	target.health = max_health
	target.global_position = position
	host.add_child(target)
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


static func _removed_health(targets: Array[Node2D]) -> float:
	var removed := 0.0
	for target in targets:
		removed += target.max_health - target.health
	return removed


static func _status_duration(target: Target, prefix: String) -> float:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return float((StatusEffects.snapshot(target)[status_id] as Dictionary).get("duration", 0.0))
	return -1.0


func _drop(host: Host) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	for measurement in _measurements:
		print("sound_amp_v2 targets=%d total=%.1f per_target=%.1f" % [
			int(measurement["targets"]), float(measurement["total"]), float(measurement["per_target"]),
		])
	if _errors.is_empty():
		print("guitarist_sound_amp_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guitarist_sound_amp_test: %s" % error)
	print("guitarist_sound_amp_test: FAIL (%d)" % _errors.size())
	quit(1)
