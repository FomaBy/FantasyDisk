extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "thief"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(500.0, 0.0)
	var active := false
	var damage_calls := 0
	var base_damage := 10.0
	var money := 0
	var modifiers := {"dodge_flat": 0.0}

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "physical"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_point - global_position
		return {"point": global_position + offset.normalized() * minf(offset.length(), max_range), "direction": offset.normalized()}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[Node2D] = []
		for target in fixture_targets:
			if is_instance_valid(target) and target.global_position.distance_to(center) <= radius:
				found.append(target)
		found.sort_custom(func(left: Node2D, right: Node2D) -> bool:
			return left.global_position.distance_squared_to(center) < right.global_position.distance_squared_to(center))
		return found.slice(0, limit) if limit > 0 else found

	func ultimate_host_summons(_group_id: String) -> Array:
		return []

	func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
		damage_calls += 1
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		if operation == "add":
			modifiers[key] = float(modifiers.get(key, 0.0)) + value
		else:
			modifiers[key] = float(modifiers.get(key, 1.0)) * value

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(value: bool) -> void:
		active = value

	func gain_money(amount: int) -> void:
		money += amount


var _errors: Array[String] = []
var _holder: Node2D = null
var _registry: Registry = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	await process_frame
	await _test_coin_pouch()
	await _test_shadow_cloak()
	await _test_smoke_bomb()
	await _test_map_wide_coverage()
	_test_charge_and_persistence_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_coin_pouch() -> void:
	var host := await _host()
	for index in 13:
		_target(host, Vector2(80.0 + float(index) * 32.0, 0.0), 10000.0, 10000.0)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "thief_coin_pouch"), "Jackpot must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 1.4)
	_check(host.damage_calls == 13, "thirteen coins must hit unique admitted silhouettes")
	_check(host.money == 4 and effect != null and int(effect.get("gold_awarded_for_tests")) == 4,
		"every third hit must award capped gold exactly four times")
	_check(effect != null and bool(effect.get("return_burst_for_tests")),
		"the thirteenth coin must return with the jackpot burst")
	if effect != null:
		effect.call("hit", 2)
	_check(host.money == 4 and host.damage_calls == 13,
		"repeating a coin event must not duplicate damage or gold")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Jackpot attribution must equal HP actually removed")
	await process_frame
	_check(not controller.is_active() and not host.active, "Jackpot must complete after its finite ricochet chain")
	await _drop(host)


func _test_shadow_cloak() -> void:
	var host := await _host()
	var boss := _target(host, Vector2(220.0, 0.0), 5000.0, 5000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "thief_shadow_cloak"), "Silent Sentence must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 1.35)
	_check(effect != null and int(effect.get("strike_count_for_tests")) == 8,
		"a lone boss must receive all eight escalating shadow stabs")
	_check(_feedback_count([boss], "shadow_backstab") == host.damage_calls and host.damage_calls < 8,
		"the boss cap must stop later shadow stabs before they reach the damage sink")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.08),
		"the full shadow sequence must obey the 8%% whole-activation boss cap (got %.2f)" % [boss.max_health - boss.health])
	_check(effect != null and bool(effect.get("finish_line_for_tests")),
		"the final red-line finish must run once")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Silent Sentence attribution must equal HP actually removed")
	await process_frame
	_check(not controller.is_active() and not host.active, "Silent Sentence must cleanly end after the sequence")
	_check(_status_with_prefix(boss, "thief_ultimate_shadow_").is_empty(),
		"shadow marks must not survive activation cleanup")
	await _drop(host)


func _test_smoke_bomb() -> void:
	var host := await _host()
	var normal := _target(host, Vector2(100.0, 0.0), 5000.0, 5000.0)
	var epic := _target(host, Vector2(160.0, 0.0), 5000.0, 5000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(220.0, 0.0), 5000.0, 5000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "thief_smoke_bomb"), "Perfect Heist must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_check(is_equal_approx(float(host.modifiers["dodge_flat"]), 0.34),
		"the smoke dome must grant its declared temporary evasion")
	var normal_status := _status_with_prefix(normal, "thief_ultimate_smoke_")
	_check(bool(normal_status.get("decoy_taunt", false)) and bool(normal_status.get("ranged_lock_blocked", false)),
		"outlined enemies must receive the decoy/ranged-lock contract")
	if effect != null:
		effect.call("collapse")
		effect.call("collapse")
	_check(host.damage_calls == 3 and effect != null and int(effect.get("collapse_count_for_tests")) == 3,
		"collapse must damage each marked enemy once and stay idempotent")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.08),
		"the collapse must obey the 8% whole-activation boss cap")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Perfect Heist attribution must equal HP actually removed")
	_advance(activation, 4.1)
	await process_frame
	_check(not controller.is_active() and not host.active, "the dome must end after its declared duration")
	_check(is_zero_approx(float(host.modifiers["dodge_flat"])), "dome evasion must be unwound on cleanup")
	for target in [normal, epic, boss]:
		_check(_status_with_prefix(target, "thief_ultimate_smoke_").is_empty(),
			"smoke cleanup must remove only its activation-owned outlines")
	await _drop(host)


func _test_charge_and_persistence_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]:
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
		_check(is_equal_approx(ledger.charge, before), "%s must earn no charge while active" % weapon_id)
		ledger.set_ultimate_active(false)
		ledger.apply_start_charge(0.63)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, 63.0), "%s charge must survive snapshots" % weapon_id)


## Ultimate Direction v2: each executor must affect every live enemy, including
## silhouettes far beyond the old radius/count rails.
func _test_map_wide_coverage() -> void:
	for weapon_id in ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]:
		var host := await _host()
		for index in 20:
			_target(host, Vector2(80.0 + float(index) * 180.0, float(index % 3) * 40.0), 10000.0, 10000.0)
		var controller := Controller.new(host, _registry)
		_check(controller.activate(CLASS_ID, weapon_id), "%s map-wide cast must activate" % weapon_id)
		var activation := controller.active_activation()
		_advance(activation, 4.2)
		for target in host.fixture_targets:
			_check(target.health < target.max_health, "%s must damage every live enemy" % weapon_id)
		await _drop(host)


func _host() -> FixtureHost:
	var host := FixtureHost.new()
	host.process_mode = Node.PROCESS_MODE_DISABLED
	_holder.add_child(host)
	await process_frame
	return host


func _target(host: FixtureHost, position: Vector2, health: float, maximum: float) -> FixtureTarget:
	var target := FixtureTarget.new()
	target.global_position = position
	target.health = health
	target.max_health = maximum
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
		print("thief_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("thief_live_test: %s" % error)
	print("thief_live_test: FAIL (%d)" % _errors.size())
	quit(1)
