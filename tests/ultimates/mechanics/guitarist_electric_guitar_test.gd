extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const CLASS_ID := "guitarist"
const WEAPON_ID := "electric_guitar"
const STEP := 0.01
const RIFF_FLOOR := 67.5


class Target extends Node2D:
	var health := 100000.0
	var max_health := 100000.0

	func take_damage(amount: float, _feedback := {}) -> void:
		health = maxf(health - amount, 0.0)


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
		"Electric Guitar package must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_every_enemy_gets_the_riff_floor()
	await _test_final_chord_is_uncapped()
	await _test_v2_power_corridor()
	await _test_caps_and_control_resistance()
	_test_charge_lifecycle()
	_holder.queue_free()
	await process_frame
	_report()


## FAN-3262 / Ultimate Direction v2: one strip's geometry remains presentation,
## but all five riffs guarantee 67.5 damage to every live enemy, even off-map.
func _test_every_enemy_gets_the_riff_floor() -> void:
	for count in [1, 5, 10, 20]:
		var host := _new_host(1.0)
		for index in count:
			_target(host, _riff_position(index))
		if count == 20:
			host.fixture_targets.back().global_position = Vector2(5000.0, -4000.0)
		var controller := Controller.new(host, _registry)
		_check(controller.activate(CLASS_ID, WEAPON_ID), "%d-target riff fixture must activate" % count)
		var activation = controller.active_activation()
		_advance(activation, 1.25)
		var removed := _removed_health(host.fixture_targets)
		var reached := 0
		for target in host.fixture_targets:
			var loss: float = target.max_health - target.health
			if loss > 0.0:
				reached += 1
			_check(is_equal_approx(loss, RIFF_FLOOR),
				"%d-target riff fixture must give each enemy the 67.5 guaranteed floor" % count)
		_measurements.append({"targets": count, "total": removed, "per_target": removed / float(count)})
		_check(reached == count and is_equal_approx(removed, RIFF_FLOOR * float(count)),
			"%d-target v2 corridor must reach every enemy, got %d and %.1f total" % [count, reached, removed])
		controller.cancel()
		await process_frame
		await _drop(host)


func _test_final_chord_is_uncapped() -> void:
	var host := _new_host(1.0)
	for index in 20:
		_target(host, Vector2(720.0, -500.0 + float(index) * 50.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "20-target final-chord fixture must activate")
	var activation = controller.active_activation()
	_advance(activation, 1.5)
	for target in host.fixture_targets:
		_check(is_equal_approx(target.max_health - target.health, 114.8),
			"the final chord must reach every in-corridor enemy after the five-riff floor")
	_check(is_equal_approx(_removed_health(host.fixture_targets), 2296.0),
		"the final chord must not stop after fourteen in-corridor enemies")
	controller.cancel()
	await process_frame
	await _drop(host)


func _test_v2_power_corridor() -> void:
	var row := Budget.row_for(Budget.build_rows(PD.WEAPONS_BY_CLASS, PD), CLASS_ID, WEAPON_ID)
	var weapon := PD.weapon(CLASS_ID, WEAPON_ID)
	var derived := PD.derived_parameters(PD.base_stats(CLASS_ID), {}, weapon)
	var base := float(derived[str(weapon["damage_parameter"])]) * float(derived["ultimate_multiplier"])
	var host := _new_host(base)
	var focused := _target(host, Vector2(720.0, 0.0), 100000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "v2 power fixture must activate")
	var activation = controller.active_activation()
	_advance(activation, 1.5)
	var output: float = focused.max_health - focused.health
	var floor: float = RIFF_FLOOR * base
	print("electric_guitar_v2 power=%.2f floor=%.2f corridor=%.2f..%.2f" % [
		output, floor, float(row["power_budget_min"]), float(row["power_budget_max"]),
	])
	_check(output >= float(row["power_budget_min"]) and output <= float(row["power_budget_max"]),
		"focused Last Chord output %.2f must stay inside the v2 corridor %.2f..%.2f" % [
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
	var normal := _target(host, Vector2(720.0, -12.0), 1000.0)
	var epic := _target(host, Vector2(720.0, 0.0), 1000.0)
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(720.0, 12.0), 1000.0)
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "cap-and-control fixture must activate")
	var activation = controller.active_activation()
	_advance(activation, 1.5)
	_check(is_equal_approx(normal.max_health - normal.health, 300.0)
		and is_equal_approx(epic.max_health - epic.health, 300.0),
		"per-target 30 percent shaping must remain on normal and elite enemies")
	_check(is_equal_approx(boss.max_health - boss.health, 90.0),
		"the whole activation must retain the nine-percent boss cap")
	_check(_has_last_chord_status(normal) and _has_last_chord_status(epic)
		and not _has_last_chord_status(boss),
		"Last Chord must preserve normal/epic control and boss immunity")
	_check(is_equal_approx(activation.applied_total, 690.0),
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
		"a full charge must buy exactly one Electric Guitar activation")
	ledger.set_ultimate_active(true)
	_check(is_zero_approx(ledger.add_removed_health(100000.0)),
		"the active riff must not earn dealt-damage charge")
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


static func _riff_position(index: int) -> Vector2:
	var axis := Vector2.RIGHT.rotated(deg_to_rad(24.0))
	return Vector2(720.0, 0.0) + axis * (-500.0 + float(index) * 45.0)


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


static func _has_last_chord_status(target: Target) -> bool:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("last_chord:"):
			return true
	return false


func _drop(host: Host) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	for measurement in _measurements:
		print("electric_guitar_v2 targets=%d total=%.1f per_target=%.1f" % [
			int(measurement["targets"]), float(measurement["total"]), float(measurement["per_target"]),
		])
	if _errors.is_empty():
		print("guitarist_electric_guitar_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guitarist_electric_guitar_test: %s" % error)
	print("guitarist_electric_guitar_test: FAIL (%d)" % _errors.size())
	quit(1)
