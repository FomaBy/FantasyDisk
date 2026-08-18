extends SceneTree

## FAN-2203: Berserk balance is measured through the admitted runtime package.
## Solo and three-target output are actual HP loss. Ultimate Direction v2
## (FAN-2953) removed the trio's count-shaped reach caps, so the crowd rail is
## no longer a cap: all three weapons reach every live enemy, and what separates
## them in a crowd is the SHAPE of the guaranteed per-enemy channel.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/berserk_balance_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "berserk"
const WEAPONS := ["sword", "axe", "hammer"]
const TRIO_MIN := 0.90
const TRIO_MAX := 1.10
const STEP := 0.01

## Ultimate Direction v2 (FAN-2953). A map-wide ultimate necessarily scales
## with the crowd, so the AoE rail is no longer scored against the pre-v2 cap
## union: it must BEAT the weapon's own ordinary AoE reference window, and the
## trio must not spread so far that two of its three options stop mattering in
## a crowd.
const AOE_MIN := 1.00
const AOE_MAX := 2.00
const AOE_TRIO_SPREAD_MAX := 2.50
## The trio average carries the rift's documented displacement-paid discount:
## its damage-only share sits at its own floor, so the AVERAGE is bounded at
## the floor-adjusted rail rather than the per-weapon one.
const AOE_TRIO_MIN := 0.95

## The rift pays roughly a third of its corridor budget in the stagger launch
## (`stagger_impulse` 460 per enemy), a channel the HP-priced AoE reference
## window cannot see. Its damage-only crowd share is therefore bounded below by
## its own floor instead of the AoE reference — the same bounded-exception
## family as `HAMMER_DAMAGE_FLOOR` in the closed-form twin
## (`tests/ultimates/berserk_balance_test.gd`).
const HAMMER_AOE_FLOOR := 0.75


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
	var power_midpoint := (float(row["power_budget_min"]) + float(row["power_budget_max"])) * 0.5
	var aoe_midpoint := float(row["reference_aoe_dps"]) \
		* (Budget.POWER_SECONDS_MIN + Budget.POWER_SECONDS_MAX) * 0.5
	var base := _base_damage(weapon_id)
	var solo_coefficient := 0.0
	# The coefficient the WEAKEST enemy of a crowd is guaranteed, with every
	# geometric bonus removed — the closed-form twin of the channel
	# `tests/ultimates/berserk_balance_test.gd` asserts the per-enemy floor
	# against, read from the same shipped params the cast above walked.
	var floor_coefficient := 0.0
	var control_seconds := 0.0
	match weapon_id:
		"sword":
			solo_coefficient = _round_robin_bites(params) \
				* float(params["blade_damage"]) + float(params["cross_damage"])
			floor_coefficient = _round_robin_bites(params) * float(params["blade_damage"])
			control_seconds = float(params["vortex_duration"])
		"axe":
			solo_coefficient = float(params["outbound_damage"]) \
				+ float(params["return_damage"])
			floor_coefficient = float(params["outbound_damage"])
			control_seconds = float(params["mark_duration"])
		"hammer":
			solo_coefficient = float(params["cardinal_damage"]) \
				+ float(params["diagonal_damage"]) + float(params["quake_damage"])
			floor_coefficient = solo_coefficient
			control_seconds = float(params["stagger_duration"])
	return {
		"solo_output": solo_output,
		"solo_ratio": solo_output / power_midpoint,
		"power_seconds": solo_output / float(row["reference_solo_dps"]),
		"aoe_output": aoe_output,
		"aoe_ratio": aoe_output / maxf(aoe_midpoint, 0.01),
		"floor_share": floor_coefficient / maxf(solo_coefficient, 0.01),
		"control_seconds": control_seconds,
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


## How many bites the declared round-robin admits on one target — the exact
## `blade_ready` contract the live whirlwind walks.
static func _round_robin_bites(params: Dictionary) -> int:
	var blade_count := maxi(int(params.get("blade_count", 1)), 1)
	var sweep_count := int(params.get("sweep_count", 0))
	var interval := float(params.get("sweep_interval", 0.0))
	var cooldown := float(params.get("blade_hit_cooldown", 0.0))
	var last_hit: Array = []
	for blade in blade_count:
		last_hit.append(-1)
	var bites := 0
	for sweep in sweep_count:
		var blade := sweep % blade_count
		var gap := float(sweep - int(last_hit[blade])) * interval
		if int(last_hit[blade]) < 0 or gap >= cooldown - 0.001:
			bites += 1
			last_hit[blade] = sweep
	return bites


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
	# The map-wide floor is the crowd identity now: every option must hand the
	# weakest silhouette a real share of its own focused channel.
	_check(float(metrics["floor_share"]) > 0.0
		and float(metrics["control_seconds"]) > 0.0,
		"%s must keep a non-trivial per-enemy floor and control window" % weapon_id)


func _test_trio(metrics: Dictionary) -> void:
	var solo_score := _average(metrics, "solo_ratio")
	var aoe_score := _average(metrics, "aoe_ratio")
	_check(solo_score >= TRIO_MIN and solo_score <= TRIO_MAX,
		"trio solo score %.3f must stay inside %.2f..%.2f" % [solo_score, TRIO_MIN, TRIO_MAX])
	# The crowd rail used to be the three hard target caps. Ultimate Direction
	# v2 retires them: all three weapons reach every live enemy (proven in
	# `berserk_live_test.gd`), so what separates them in a crowd is the SHAPE of
	# the guaranteed channel.
	_check(aoe_score >= AOE_TRIO_MIN and aoe_score <= AOE_MAX,
		"trio AoE score %.3f must stay inside %.2f..%.2f" % [aoe_score, AOE_TRIO_MIN, AOE_MAX])
	var lowest_aoe := INF
	var highest_aoe := 0.0
	for weapon_id in WEAPONS:
		var ratio := float((metrics[weapon_id] as Dictionary)["aoe_ratio"])
		var floor_ratio := HAMMER_AOE_FLOOR if weapon_id == "hammer" else AOE_MIN
		_check(ratio >= floor_ratio,
			"%s reaches the whole map, so its three-target output %.3f must beat its bounded crowd floor %.2f"
				% [weapon_id, ratio, floor_ratio])
		lowest_aoe = minf(lowest_aoe, ratio)
		highest_aoe = maxf(highest_aoe, ratio)
	_check(highest_aoe <= lowest_aoe * AOE_TRIO_SPREAD_MAX,
		"trio AoE spread %.2fx must stay inside %.2fx so every option still matters in a crowd"
			% [highest_aoe / maxf(lowest_aoe, 0.01), AOE_TRIO_SPREAD_MAX])


func _test_roles(registry: Registry) -> void:
	var sword := _params(registry, "sword")
	var axe := _params(registry, "axe")
	var hammer := _params(registry, "hammer")
	# All three reach the whole map, so the niches live in the shape and the
	# timings, never in a reach cap: the whirlwind is the longest multi-hit
	# crowd option, the loop the only low-health corridor execute, the rift the
	# shortest staggering burst.
	_check(float(sword["lifetime"]) > float(axe["lifetime"])
		and float(sword["lifetime"]) > float(hammer["lifetime"])
		and int(sword["sweep_count"]) > 3,
		"the whirlwind must remain the longest, multi-hit crowd option")
	_check(float(axe["return_damage"]) > float(sword["cross_damage"])
		and float(axe["return_damage"]) > float(hammer["quake_damage"])
		and float(axe["execute_damage"]) > 0.0
		and float(axe["execute_threshold"]) > 0.0
		and not sword.has("execute_threshold") and not hammer.has("execute_threshold"),
		"only the loop may carry the corridor finisher and the low-health execute")
	_check(float(hammer["lifetime"]) < float(axe["lifetime"])
		and float(hammer["stagger_impulse"]) > 0.0,
		"the rift must remain the shortest staggering burst")


func _test_proof_goes_red(metrics: Dictionary, rows: Array) -> void:
	var row := Budget.row_for(rows, CLASS_ID, "sword")
	var runaway := (metrics["sword"] as Dictionary).duplicate(true)
	runaway["solo_output"] = float(row["power_budget_max"]) + 1.0
	_check(not _power_in_corridor(runaway, row),
		"the runtime balance proof must reject output above the frozen corridor")


static func _power_in_corridor(metrics: Dictionary, row: Dictionary) -> bool:
	return float(metrics["solo_output"]) >= float(row["power_budget_min"]) \
		and float(metrics["solo_output"]) <= float(row["power_budget_max"]) \
		and float(metrics["power_seconds"]) >= Budget.POWER_SECONDS_MIN \
		and float(metrics["power_seconds"]) <= Budget.POWER_SECONDS_MAX


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
		print("  %s solo=%.3f aoe=%.3f power=%.2fs floor_share=%.3f control=%.2fs lifetime=%.2fs" % [
			weapon_id, row["solo_ratio"], row["aoe_ratio"], row["power_seconds"],
			row["floor_share"], row["control_seconds"], row["lifetime"],
		])
	if _errors.is_empty():
		print("berserk_balance_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("berserk_balance_test: %s" % error)
	quit(1)
