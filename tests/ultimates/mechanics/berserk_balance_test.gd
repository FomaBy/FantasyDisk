extends SceneTree

## FAN-2203: Berserk balance is measured through the admitted runtime package.
## Solo and three-target output are actual HP loss; crowd score is the unique
## target union reached by each declared synchronized shape.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/berserk_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Sword := preload("res://scripts/ultimates/classes/berserk/sword.gd")
const Hammer := preload("res://scripts/ultimates/classes/berserk/hammer.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "berserk"
const WEAPONS := ["sword", "axe", "hammer"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const STEP := 0.01


class Target extends Node2D:
	var health := 1000000.0
	var max_health := 1000000.0
	var removed_by_damage := 0.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		var before := health
		health = maxf(health - amount, 0.0)
		removed_by_damage += before - health
		received.append({"amount": amount, "feedback": feedback.duplicate(true)})

	func apply_knockback(_impulse: Vector2) -> void:
		pass


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 0.0

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
	var rows: Array = Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var metrics: Dictionary = {}
	for weapon_id in WEAPONS:
		var row: Dictionary = Budget.row_for(rows, CLASS_ID, weapon_id)
		var profile: Dictionary = _registry.catalog_profile_for(CLASS_ID, weapon_id)
		metrics[weapon_id] = await _measure(weapon_id, row, profile)
		_test_weapon(weapon_id, row, profile, metrics[weapon_id])
	_test_trio(metrics)
	_test_roles(_registry)
	_test_proof_goes_red(metrics, rows)
	_holder.queue_free()
	await process_frame
	_report(metrics)


func _measure(weapon_id: String, row: Dictionary, profile: Dictionary) -> Dictionary:
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	var solo_output := await _measure_output(weapon_id, 1, params)
	var aoe_output := await _measure_output(weapon_id, 3, params)
	var crowd_hits := await _measure_crowd_union(weapon_id, params)
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"power_seconds": solo_output / float(row["reference_solo_dps"]),
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / aoe_midpoint,
		"crowd_hits": crowd_hits,
		"crowd_cap": int(params["crowd_cap"]),
		"lifetime": float(params["lifetime"]),
	}


func _measure_output(weapon_id: String, target_count: int, params: Dictionary) -> float:
	var host := _host(_base_damage(weapon_id))
	var positions := _measurement_positions(weapon_id)
	for index in target_count:
		var target := _target(host, positions[index])
		if weapon_id == "axe":
			target.health = 200000.0
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, weapon_id), "%s balance cast must activate" % weapon_id)
	var activation = controller.active_activation()
	_advance(activation, float(params["lifetime"]) + 0.1)
	var actual_removed := _removed_health(host.fixture_targets)
	_check(is_equal_approx(activation.applied_total, actual_removed),
		"%s balance attribution must equal actual HP loss" % weapon_id)
	if controller.is_active():
		controller.cancel()
	await process_frame
	await _drop(host)
	return actual_removed


func _measure_crowd_union(weapon_id: String, params: Dictionary) -> int:
	var host := _host(_base_damage(weapon_id))
	var cap := int(params["crowd_cap"])
	var controller := Controller.new(host, _registry)
	var mechanic := ""
	match weapon_id:
		"sword":
			for axis in Sword.cross_axes(Vector2.RIGHT):
				for index in int(ceil(float(cap + 4) / 4.0)):
					_target(host, axis * (105.0 + float(index) * 28.0))
		"axe":
			for index in cap + 4:
				_target(host, Vector2(120.0 + float(index) * 24.0, 0.0))
		"hammer":
			var targets_per_lane := int(ceil(float(cap + 4) / 4.0))
			for step in 2:
				for axis in Hammer.lane_axes(step):
					for index in targets_per_lane:
						_target(host, axis * (150.0 + float(index) * 60.0))
	_check(controller.activate(CLASS_ID, weapon_id), "%s crowd cast must activate" % weapon_id)
	var effect := _effect(controller.active_activation())
	match weapon_id:
		"sword":
			mechanic = "scarlet_whirlwind_cross"
			effect.call("cross_slash")
		"axe":
			mechanic = "execution_loop_outbound"
			effect.call("launch")
		"hammer":
			effect.call("beat", 0)
			var cardinal := _mechanic_target_count(
				host.fixture_targets, "fourfold_rift_cardinal_lanes"
			)
			effect.call("beat", 1)
			var diagonal := _mechanic_target_count(
				host.fixture_targets, "fourfold_rift_diagonal_lanes"
			)
			_check(cardinal == diagonal,
				"hammer cardinal and diagonal unions must honor the same runtime cap")
			controller.cancel()
			await process_frame
			await _drop(host)
			return mini(cardinal, diagonal)
	var unique_hits := _mechanic_target_count(host.fixture_targets, mechanic)
	controller.cancel()
	await process_frame
	await _drop(host)
	return unique_hits


func _test_weapon(
	weapon_id: String, row: Dictionary, profile: Dictionary, metrics: Dictionary
) -> void:
	_check(_power_in_corridor(metrics, row),
		"%s runtime solo output %.2f (%.2fs) must stay inside %.2f..%.2f" % [
			weapon_id, metrics["solo_output"], metrics["power_seconds"],
			row["power_budget_min"], row["power_budget_max"],
		])
	_check(is_equal_approx(float(profile["total_boss_cap"]), float(row["total_boss_cap"])),
		"%s must use its immutable budget-row boss cap" % weapon_id)
	_check(int(metrics["crowd_hits"]) == int(metrics["crowd_cap"]),
		"%s runtime union must stop at its configured crowd cap %d" % [
			weapon_id, metrics["crowd_cap"],
		])


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	var crowd_score := 0.0
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		crowd_score += float(row["crowd_hits"]) / float(row["crowd_cap"])
	crowd_score /= float(WEAPONS.size())
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	_check(aoe_score >= TRIO_MIN and aoe_score <= TRIO_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, TRIO_MIN, TRIO_MAX])
	_check(is_equal_approx(crowd_score, 1.0),
		"runtime crowd unions must stop at their configured caps")
	var total_score := (solo_score + aoe_score + crowd_score) / 3.0
	_check(total_score >= TRIO_MIN and total_score <= TRIO_MAX,
		"class trio total %.3f must stay inside %.2f..%.2f" % [total_score, TRIO_MIN, TRIO_MAX])


func _test_roles(registry: Registry) -> void:
	var sword := _params(registry, "sword")
	var axe := _params(registry, "axe")
	var hammer := _params(registry, "hammer")
	_check(int(sword["crowd_cap"]) > int(axe["crowd_cap"])
		and int(sword["crowd_cap"]) > int(hammer["crowd_cap"])
		and float(sword["lifetime"]) > float(axe["lifetime"]),
		"the whirlwind must remain the widest and longest crowd option")
	_check(float(axe["return_damage"]) > float(sword["cross_damage"])
		and float(axe["return_damage"]) > float(hammer["quake_damage"])
		and float(axe["execute_damage"]) > 0.0,
		"the loop must remain the heaviest single-contact execute option")
	_check(float(hammer["lifetime"]) < float(axe["lifetime"])
		and float(hammer["stagger_impulse"]) > 0.0,
		"the rift must remain the shortest staggering burst")


func _test_proof_goes_red(metrics: Dictionary, rows: Array) -> void:
	var row := Budget.row_for(rows, CLASS_ID, "sword")
	var runaway := (metrics["sword"] as Dictionary).duplicate(true)
	runaway["solo_output"] = float(row["power_budget_max"]) + 1.0
	_check(not _power_in_corridor(runaway, row),
		"the runtime balance proof must reject output above the frozen corridor")
	_check(not _crowd_within_cap(
		int((metrics["sword"] as Dictionary)["crowd_cap"]) + 1,
		int((metrics["sword"] as Dictionary)["crowd_cap"])
	), "the runtime balance proof must reject a global-cap overflow")


static func _power_in_corridor(metrics: Dictionary, row: Dictionary) -> bool:
	return float(metrics["solo_output"]) >= float(row["power_budget_min"]) \
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]) \
		and float(metrics["power_seconds"]) >= Budget.POWER_SECONDS_MIN \
		and float(metrics["power_seconds"]) <= Budget.POWER_SECONDS_MAX


static func _crowd_within_cap(hits: int, cap: int) -> bool:
	return hits <= cap


func _base_damage(weapon_id: String) -> float:
	var derived := PD.derived_parameters(
		PD.base_stats(CLASS_ID), {}, PD.weapon(CLASS_ID, weapon_id)
	)
	return float(derived["damage"]) * float(derived["ultimate_multiplier"])


static func _measurement_positions(weapon_id: String) -> Array[Vector2]:
	if weapon_id == "axe":
		return [Vector2(300.0, 0.0), Vector2(360.0, 20.0), Vector2(420.0, -20.0)]
	return [Vector2(60.0, 0.0), Vector2(0.0, 60.0), Vector2(-60.0, 0.0)]


func _host(base_damage: float) -> Host:
	var host := Host.new()
	host.base_damage = base_damage
	_holder.add_child(host)
	return host


func _target(host: Host, position: Vector2) -> Target:
	var target := Target.new()
	target.global_position = position
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _effect(activation) -> Node:
	if activation == null:
		return null
	var spawned: Array = activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


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
		removed += target.removed_by_damage
	return removed


func _mechanic_target_count(targets: Array[Node2D], mechanic: String) -> int:
	var count := 0
	for target in targets:
		var hits := 0
		for received in target.received:
			if str((received.get("feedback", {}) as Dictionary).get("ultimate_mechanic", "")) \
					== mechanic:
				hits += 1
		_check(hits <= 1, "%s must not hit one target twice" % mechanic)
		if hits == 1:
			count += 1
	return count


func _drop(host: Host) -> void:
	host.queue_free()
	await process_frame


func _params(registry: Registry, weapon_id: String) -> Dictionary:
	var profile := registry.catalog_profile_for(CLASS_ID, weapon_id)
	return (profile["executor"] as Dictionary)["params"] as Dictionary


func _average(metrics: Dictionary, key: String) -> float:
	var total := 0.0
	for weapon_id in WEAPONS:
		total += float((metrics[weapon_id] as Dictionary)[key])
	return total / float(WEAPONS.size())


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report(metrics: Dictionary) -> void:
	for weapon_id in WEAPONS:
		var row := metrics[weapon_id] as Dictionary
		print("  %s solo=%.3f aoe=%.3f power=%.2fs crowd=%d/%d lifetime=%.2fs" % [
			weapon_id, row["solo_ratio"], row["aoe_ratio"], row["power_seconds"],
			row["crowd_hits"], row["crowd_cap"], row["lifetime"],
		])
	if _errors.is_empty():
		print("berserk_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("berserk_balance_test: %s" % error)
	quit(1)
