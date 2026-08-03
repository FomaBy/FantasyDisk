extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "sniper"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 4000.0
	var max_health := 4000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(940.0, 0.0)
	var active := false
	var damage_calls := 0
	var base_damage := 10.0

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

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value


var _errors: Array[String] = []
var _holder: Node2D = null
var _registry: Registry = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	await process_frame
	await _test_deadeye_rifle()
	await _test_spotter_scope()
	await _test_shatter_rounds()
	await _test_shatter_focus_cap()
	_test_charge_and_persistence_contract()
	_holder.queue_free()
	await process_frame
	_report()


## One aimed rail: the highest-HP silhouette on it takes the headshot, everyone
## behind keeps only the declared penetration share, and the boss share of the
## whole activation stays inside the frozen 10%.
func _test_deadeye_rifle() -> void:
	var host := await _host()
	host.aim_point = Vector2(940.0, 0.0)
	var near := _target(host, Vector2(150.0, 10.0), 900.0, 900.0)
	var boss := _target(host, Vector2(400.0, -12.0), 12000.0, 12000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var mid := _target(host, Vector2(620.0, 20.0), 3000.0, 3000.0)
	var far := _target(host, Vector2(820.0, -30.0), 2500.0, 2500.0)
	var off_rail := _target(host, Vector2(300.0, 300.0), 50000.0, 50000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "sniper_deadeye_rifle"), "Deadeye Rifle must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and effect.get("priority_target_for_tests") == boss,
		"the headshot must choose the highest-HP target on the aimed rail")
	_check(effect != null and int(effect.get("rail_size_for_tests")) == 4,
		"the rail must stop at the declared four-body pierce limit")
	_check(boss.health < boss.max_health,
		"the shot must resolve on the activation frame, not after a scheduled windup")
	_check(off_rail.received.is_empty(), "the corridor must not leak onto off-rail targets")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"the headshot must obey the 10% whole-activation boss cap")
	_check(
		(near.max_health - near.health) > (mid.max_health - mid.health)
			and (mid.max_health - mid.health) > (far.max_health - far.health),
		"penetration must decay strictly with pierce depth"
	)
	_check(_feedback_count([near, mid, far], "deadeye_penetration") == 3
			and _feedback_count([boss], "deadeye_headshot") == 1,
		"exactly one headshot and three penetration hits must be attributed")
	var calls_after_shot := host.damage_calls
	effect.call("fire")
	_check(host.damage_calls == calls_after_shot, "repeating the shot event must be idempotent")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Deadeye attribution must equal HP actually removed, including cap clamps")
	_check(controller.is_active(), "the rail must stay live through its recovery window")
	_advance(activation, 0.3)
	await process_frame
	_check(not controller.is_active() and not host.active,
		"the shot must complete after its recovery window")
	_check(not is_instance_valid(effect), "completion must free the activation-owned rail")
	await _drop(host)


## Nine sky locks inside one kill zone: locks are dealt round-robin under a
## per-silhouette cap, suppression respects the tier policy, and a lock left
## without a body transfers to the most dangerous survivor.
func _test_spotter_scope() -> void:
	var host := await _host()
	host.aim_point = Vector2(600.0, 0.0)
	var epic := _target(host, Vector2(650.0, 0.0), 5200.0, 5200.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var normal := _target(host, Vector2(600.0, 40.0), 3000.0, 3000.0)
	var boss := _target(host, Vector2(700.0, 0.0), 2500.0, 2500.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var doomed := _target(host, Vector2(560.0, 60.0), 120.0, 120.0)
	var outside := _target(host, Vector2(1400.0, 0.0), 9000.0, 9000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "sniper_spotter_scope"), "Spotter Scope must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and is_equal_approx(float(effect.call("lock_count_for", epic)), 3.0),
		"the most dangerous silhouette must carry the declared three-lock maximum")
	_check(effect != null and is_equal_approx(float(effect.call("lock_count_for", boss)), 2.0),
		"the remaining locks must be dealt round-robin, not stacked")
	_check(outside.received.is_empty() and _suppression(outside).is_empty(),
		"the kill zone must not reach outside its declared radius")
	_check(bool(_suppression(normal).get("movement_locked", false)),
		"normal targets must be pinned by the lock telegraph")
	var epic_suppression := _suppression(epic)
	_check(not epic_suppression.is_empty()
			and not bool(epic_suppression.get("movement_locked", false)),
		"epic resistance must keep the slow but reject the movement lock")
	_check(is_equal_approx(float(epic_suppression.get("duration", 0.0)), 2.2),
		"epic resistance must halve the suppression window")
	_check(is_equal_approx(float(_suppression(boss).get("duration", 0.0)), 1.1),
		"boss resistance must cut the suppression window to a quarter")
	_advance(activation, 2.2)
	_check(effect != null and int(effect.get("strike_count_for_tests")) == 9,
		"all nine sky locks must resolve exactly once")
	_check(effect != null and int(effect.get("transfer_count_for_tests")) == 1,
		"the lock left without a body must transfer instead of being wasted")
	_check(is_equal_approx(float(effect.call("lock_count_for", doomed)), 1.0)
			and is_equal_approx(float(effect.call("lock_count_for", epic)), 4.0),
		"a transfer must move exactly one lock between the two ledgers")
	_check(is_zero_approx(doomed.health)
			and is_equal_approx(float(doomed.received[0]["amount"]), 150.0),
		"the attempted strike must stay visible for attribution after the overkill clamp")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"all sky-lock strikes together must obey the 10% boss cap")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Spotter attribution must equal HP actually removed")
	_check(controller.is_active(), "the kill zone must stay live for its suppression window")
	_advance(activation, 2.3)
	await process_frame
	_check(not controller.is_active() and not host.active,
		"the kill zone must complete after the declared 4.4s suppression window")
	for target in host.fixture_targets:
		_check(_suppression(target).is_empty(), "completion must remove only its own leases")
	await _drop(host)


## Five ricochet trajectories: distinct entry silhouettes, shards on every
## impact, tiered stagger and one shared boss budget.
func _test_shatter_rounds() -> void:
	var host := await _host()
	var alpha := _target(host, Vector2(120.0, 0.0), 4000.0, 4000.0)
	var beta := _target(host, Vector2(210.0, 40.0), 4000.0, 4000.0)
	var epic := _target(host, Vector2(-120.0, 40.0), 6000.0, 6000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var delta := _target(host, Vector2(-210.0, 80.0), 4000.0, 4000.0)
	var boss := _target(host, Vector2(80.0, -100.0), 5000.0, 5000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "sniper_shatter_rounds"), "Shatter Rounds must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 2.9)
	_check(effect != null and int(effect.get("impact_count_for_tests")) == 15,
		"five trajectories must resolve three impacts each")
	_check(effect != null and int(effect.get("shard_count_for_tests")) == 15,
		"every impact must spray its declared single shard")
	# Impacts and shards that arrive on an exhausted budget are refused before
	# the host is touched, so the honest invariant is that nothing reaches the
	# host outside the two declared channels.
	_check(
		_feedback_count(host.fixture_targets, "ricochet_impact")
			+ _feedback_count(host.fixture_targets, "ricochet_shard") == host.damage_calls,
		"no volley damage may reach the host outside its two declared mechanics"
	)
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"impacts and shards must share one 10% boss budget")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Shatter attribution must equal HP actually removed")
	_check(is_equal_approx(float(_stagger(alpha).get("duration", 0.0)), 2.8)
			and not bool(_stagger(alpha).get("movement_locked", false)),
		"normal targets must be staggered without ever being pinned")
	_check(is_equal_approx(float(_stagger(epic).get("duration", 0.0)), 1.4),
		"epic resistance must halve the stagger")
	_check(is_equal_approx(float(_stagger(boss).get("duration", 0.0)), 0.7),
		"boss resistance must cut the stagger to a quarter")
	_check(beta.knockbacks.is_empty() and delta.knockbacks.is_empty(),
		"the volley must never displace anything")
	await process_frame
	_check(not controller.is_active() and not is_instance_valid(effect),
		"volley completion must free the activation-owned sweep")
	for target in host.fixture_targets:
		_check(_stagger(target).is_empty(), "completion must remove its stagger leases")
	await _drop(host)


## The anti-focus rail: five trajectories converging on one silhouette spend
## only the declared share of that silhouette, and nothing more.
func _test_shatter_focus_cap() -> void:
	var host := await _host()
	var lone := _target(host, Vector2(160.0, 0.0), 3000.0, 3000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "sniper_shatter_rounds"),
		"Shatter Rounds must activate against a single target")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	# Stops just after the last entry impact and before teardown, so the live
	# per-target budget is still readable.
	_advance(activation, 2.5)
	_check(effect != null and int(effect.get("impact_count_for_tests")) == 5,
		"without a second body every trajectory must stop at its entry impact")
	_check(effect != null and int(effect.get("shard_count_for_tests")) == 0,
		"a lone target must produce no shards")
	_check(is_equal_approx(lone.max_health - lone.health, lone.max_health * 0.4),
		"one silhouette must absorb only the declared 40% per-target share")
	_check(is_zero_approx(float(effect.call("remaining_budget_for", lone))),
		"the per-target budget must be fully spent, not exceeded")
	_advance(activation, 0.4)
	await process_frame
	_check(not controller.is_active(), "the focused volley must still complete cleanly")
	await _drop(host)


func _test_charge_and_persistence_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in [
		"sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"
	]:
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
	host: FixtureHost,
	position: Vector2,
	health: float,
	max_health: float
) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = max_health
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


func _suppression(target: Node) -> Dictionary:
	return _status_with_prefix(target, "sniper_ultimate_spotter_")


func _stagger(target: Node) -> Dictionary:
	return _status_with_prefix(target, "sniper_ultimate_shatter_")


func _status_with_prefix(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
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
		print("sniper_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("sniper_live_test: %s" % error)
	print("sniper_live_test: FAIL (%d)" % _errors.size())
	quit(1)
