extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "biologist"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var archetype := "swarm"
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class FixtureSummon extends Node2D:
	var owner_node: Node = null


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var fixture_summons: Array[Node] = []
	var aim_point := Vector2(700.0, 0.0)
	var active := false
	var damage_calls := 0
	var base_damage := 10.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

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

	func ultimate_host_summons(group_id: String) -> Array:
		var result: Array = []
		for summon in fixture_summons:
			if is_instance_valid(summon) and summon.is_in_group(group_id) \
					and summon.get("owner_node") == self:
				result.append(summon)
		return result

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
	await _test_spore_lens()
	await _test_sample_injector()
	await _test_symbiote_seed()
	_test_charge_and_persistence_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_spore_lens() -> void:
	var host := await _host()
	var vulnerable: Array[FixtureTarget] = []
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var victim := _target(host, Vector2.RIGHT.rotated(angle) * 190.0, 100.0, 100.0)
		vulnerable.append(victim)
		_target(host, Vector2.RIGHT.rotated(angle) * 220.0, 5000.0, 5000.0)
	var epic := host.fixture_targets[3] as FixtureTarget
	epic.add_to_group(Activation.EPIC_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "biologist_spore_lens"), "Spore Lens must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.95)
	_check(effect != null and int(effect.get("propagation_count_for_tests")) == 2,
		"contact germination plus the first outward branch must resolve by 0.9s")
	_check(effect != null and int(effect.get("bloom_count_for_tests")) == 3,
		"infected deaths must stop at three secondary blooms")
	_check(_feedback_count(host.fixture_targets, "secondary_bloom") <= 9,
		"three non-recursive blooms may hit at most three neighbors each")
	for victim in vulnerable:
		_check(is_zero_approx(victim.health), "primary infection must kill the low-HP fixture")
		_check(is_equal_approx(float(victim.received[0]["amount"]), host.base_damage * 78.65),
			"the attempted infection hit must remain visible for attribution")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Spore attribution must equal HP actually removed, including overkill clamps")
	var epic_status := _status_with_prefix(epic, "biologist_ultimate_spore_")
	_check(not epic_status.is_empty(), "epic targets must receive the resistant slow")
	_check(not bool(epic_status.get("movement_locked", false)),
		"epic resistance must reject the root movement lock")
	controller.cancel()
	await process_frame
	_check(not host.active and not controller.is_active(), "Spore cancel must end the active window")
	_check(not is_instance_valid(effect), "Spore cancel must free the activation-owned growth")
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "biologist_ultimate_spore_").is_empty(),
			"Spore cancel must remove only its leased statuses")
	await _drop(host)


func _test_sample_injector() -> void:
	var host := await _host()
	host.aim_point = Vector2(760.0, 0.0)
	host.base_damage = 20.0
	_target(host, Vector2(120.0, 0.0), 600.0, 5000.0, "swarm")
	var boss := _target(host, Vector2(300.0, 12.0), 10000.0, 10000.0, "durable")
	boss.add_to_group(Activation.BOSS_GROUP)
	var tissue := _target(host, Vector2(390.0, 10.0), 700.0, 5000.0, "ranged")
	var off_line := _target(host, Vector2(130.0, 240.0), 20000.0, 20000.0, "durable")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "biologist_sample_injector"),
		"Sample Injector must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and effect.get("primary_target_for_tests") == boss,
		"extraction must choose the highest-HP target inside the aimed rail")
	_check(effect == null or effect.get("primary_target_for_tests") != off_line,
		"priority selection must not leak outside the line corridor")
	_advance(activation, 0.7)
	_check(boss.health < boss.max_health and tissue.received.is_empty(),
		"release must directly extract only the priority target")
	_check(is_equal_approx(float(activation.target_value(
		boss, "sample_direct_hit_bonus", 0.0
	)), 1.35), "durable archetypes must receive the 1.35 direct-hit adaptation")
	var calls_after_extract := host.damage_calls
	effect.call("extract")
	_check(host.damage_calls == calls_after_extract,
		"repeating the extraction event must be idempotent")
	_advance(activation, 5.1)
	_check(int(effect.get("analysis_pulse_count_for_tests")) == 3,
		"analysis must emit exactly three capped pulses")
	_check(_feedback_count([tissue], "analysis_tissue") == 3,
		"nearby corridor tissue must receive the three reduced secondary pulses")
	effect.call("analysis_pulse", 3)
	_check(int(effect.get("analysis_pulse_count_for_tests")) == 3,
		"the public pulse seam must reject a fourth pulse")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.09),
		"all direct hits together must obey the 9% whole-activation boss cap")
	_check(not _status_with_prefix(boss, "biologist_ultimate_sample_").is_empty(),
		"the adaptive sample must remain leased during its ten-second window")
	_advance(activation, 4.7)
	_check(controller.is_active(), "the 10s sample window must remain active after its pulses")
	_advance(activation, 0.3)
	await process_frame
	_check(not controller.is_active() and not host.active,
		"Sample must complete after release plus its exact 10s window")
	_check(_status_with_prefix(boss, "biologist_ultimate_sample_").is_empty(),
		"Sample completion must remove the adaptive mark")
	await _drop(host)


func _test_symbiote_seed() -> void:
	var host := await _host()
	host.aim_point = Vector2(400.0, 0.0)
	var normal := _target(host, Vector2(450.0, 0.0), 5000.0, 5000.0)
	var epic := _target(host, Vector2(500.0, 0.0), 5000.0, 5000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(550.0, 0.0), 10000.0, 10000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var owned := _summon(host, host)
	var foreign_owner := Node.new()
	_holder.add_child(foreign_owner)
	var foreign := _summon(host, foreign_owner)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "biologist_symbiote_seed"),
		"Symbiote Seed must activate")
	var activation := controller.active_activation()
	var pod := _effect(activation)
	_check(pod != null and (pod as Node2D).global_position == host.aim_point,
		"the pod must deploy at the clamped aimed point")
	_check(pod != null and pod.get("owner_node") == host,
		"the temporary pod must retain player ownership")
	_check(not owned.visible and owned.process_mode == Node.PROCESS_MODE_DISABLED,
		"only the player's existing symbiote must be suspended")
	_check(foreign.visible and foreign.process_mode != Node.PROCESS_MODE_DISABLED,
		"a foreign summon must remain untouched")
	_advance(activation, 1.2)
	_check(normal.knockbacks.size() == 1 and is_equal_approx(normal.knockbacks[0].length(), 520.0),
		"normal targets must receive the full pod pull")
	_check(epic.knockbacks.size() == 1 and is_equal_approx(epic.knockbacks[0].length(), 130.0),
		"epic targets must receive only 25% displacement")
	_check(boss.knockbacks.is_empty(), "boss resistance must reject pod displacement")
	_check(bool(_status_with_prefix(normal, "biologist_ultimate_symbiote_").get(
		"movement_locked", false
	)), "normal targets must be rooted")
	_check(not bool(_status_with_prefix(epic, "biologist_ultimate_symbiote_").get(
		"movement_locked", false
	)), "epic targets must be slowed but not rooted")
	_advance(activation, 4.0)
	_check(int(pod.get("larva_count_for_tests")) == 6,
		"the pod must launch exactly six larval projectiles")
	_check(_feedback_count(host.fixture_targets, "larval_projectile") == 6,
		"each larva must resolve through the activation damage sink once")
	_advance(activation, 3.0)
	_check(bool(pod.get("terminal_burst_for_tests")),
		"the pod must end its offense with the terminal hatch burst")
	_check(_feedback_count(host.fixture_targets, "terminal_hatch") == 3,
		"terminal hatch must hit each admitted target once")
	_check(boss.max_health - boss.health <= boss.max_health * 0.09,
		"pod, larvae and hatch must stay inside one shared 9% boss budget")
	_advance(activation, 1.0)
	await process_frame
	_check(not controller.is_active() and not is_instance_valid(pod),
		"terminal completion must free the pod and its tweens")
	_check(owned.visible and owned.process_mode == Node.PROCESS_MODE_INHERIT,
		"owned summons must restore their exact pre-cast state")
	_check(foreign.visible and foreign.process_mode == Node.PROCESS_MODE_INHERIT,
		"foreign summon state must stay unchanged")
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "biologist_ultimate_symbiote_").is_empty(),
			"pod completion must remove its root/slow leases")
	foreign_owner.queue_free()
	await _drop(host)


func _test_charge_and_persistence_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in [
		"biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"
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
	max_health: float,
	archetype := "swarm"
) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = max_health
	target.archetype = archetype
	host.add_child(target)
	host.fixture_targets.append(target)
	return target


func _summon(host: FixtureHost, owner: Node) -> FixtureSummon:
	var summon := FixtureSummon.new()
	summon.owner_node = owner
	host.add_child(summon)
	summon.add_to_group("biologist_ultimate_symbiotes")
	host.fixture_summons.append(summon)
	return summon


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
		print("biologist_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("biologist_live_test: %s" % error)
	print("biologist_live_test: FAIL (%d)" % _errors.size())
	quit(1)
