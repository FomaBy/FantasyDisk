extends SceneTree

## FAN-3239: the raven totem's Ultimate Direction v2 coverage card.
##
## The frozen class-wide Druid suites stay read-only, so this weapon-local
## proof carries the v2 statement the shared `*target_cap*` scan cannot make:
## the mark, every dive wave and the collapse reach every live enemy on the
## map — solo, at 5/10/20, against elite and boss tiers, and past both retired
## count caps (crowd_cap 22, dive_target_cap 3) — while the whole-activation
## boss cap, the control-resistance shares and the charge economy hold.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/druid_raven_totem_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "druid"
const WEAPON_ID := "raven_totem"
const STEP := 0.01
## Past the declared cast: release 0.6, four dives to 5.6, collapse at 7.1.
const CAST_SECONDS := 7.2
const HITS_PER_TARGET := 5


class Target extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var received: Array[Dictionary] = []
	var removed_by_damage := 0.0

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": feedback.duplicate(true)})
		var before := health
		health = maxf(health - amount, 0.0)
		removed_by_damage += before - health


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 12.0

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
	_check(_registry.package_validation_errors().is_empty(),
		"the Druid package must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_scenarios()
	await _test_map_wide_past_retired_caps()
	await _test_control_shares_and_cleanup()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


## The v2 acceptance set: solo, 5, 10, 20, elite and boss. Every live enemy
## takes the proven floor — four dive hits plus the collapse — and the boss
## never loses more than its frozen whole-activation share.
func _test_scenarios() -> void:
	var scenarios := [
		{"id": "solo", "count": 1, "tier": ""},
		{"id": "crowd_5", "count": 5, "tier": ""},
		{"id": "crowd_10", "count": 10, "tier": ""},
		{"id": "crowd_20", "count": 20, "tier": ""},
		{"id": "elite", "count": 1, "tier": "elite_enemies"},
		{"id": "boss", "count": 1, "tier": "bosses"},
	]
	for scenario in scenarios:
		var host := _host()
		var targets: Array[Target] = []
		for index in int(scenario["count"]):
			var target := _target(host, Vector2(120.0 + 30.0 * float(index), 40.0 * float(index % 3)))
			if str(scenario["tier"]) != "":
				target.add_to_group(str(scenario["tier"]))
			targets.append(target)
		var controller := Controller.new(host, _registry)
		_check(controller.activate(CLASS_ID, WEAPON_ID),
			"%s must activate" % str(scenario["id"]))
		var activation = controller.active_activation()
		var effect := _effect(activation)
		_advance(activation, CAST_SECONDS)
		var struck := 0
		for target in targets:
			if not target.received.is_empty():
				struck += 1
		_check(struck == targets.size(),
			"%s must strike every live enemy, got %d of %d" % [
				str(scenario["id"]), struck, targets.size(),
			])
		if str(scenario["id"]) == "solo":
			_check(effect != null and int(effect.get("marked_count_for_tests")) == 1,
				"the solo cast must mark exactly the one live enemy")
		for target in targets:
			if target.is_in_group("bosses"):
				_check(target.max_health - target.health <= target.max_health * 0.08,
					"dives and collapse must share the 8% whole-activation boss cap")
			else:
				_check(target.received.size() == HITS_PER_TARGET,
					"%s: every enemy must take four dives and the collapse, got %d hits" % [
						str(scenario["id"]), target.received.size(),
					])
		_check(is_equal_approx(activation.applied_total, _removed_health(targets)),
			"%s attribution must equal HP actually removed" % str(scenario["id"]))
		controller.cancel()
		await process_frame
		await _drop(host)


## A crowd past the retired crowd_cap 22 plus a silhouette parked far
## off-screen: the mark and every strike are map-wide, so all of them end the
## cast damaged — the wave sequence reaches every live enemy inside the window.
func _test_map_wide_past_retired_caps() -> void:
	var host := _host()
	var targets: Array[Target] = []
	for index in 28:
		targets.append(_target(host, Vector2(60.0 + 35.0 * float(index % 7), 90.0 * float(index / 7))))
	targets.append(_target(host, Vector2(5000.0, -4000.0)))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "the map-wide cast must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.61)
	_check(effect != null and int(effect.get("marked_count_for_tests")) == targets.size(),
		"the mark must reach every live enemy on the map, got %d of %d" % [
			effect.get("marked_count_for_tests") if effect != null else -1, targets.size(),
		])
	_advance(activation, CAST_SECONDS)
	var struck := 0
	for target in targets:
		if not target.received.is_empty():
			struck += 1
	_check(struck == targets.size(),
		"the cast must strike every live enemy on the map, got %d of %d" % [
			struck, targets.size(),
		])
	controller.cancel()
	await process_frame
	await _drop(host)


## The shared control policy is untouched by v2: normals keep the full mark,
## epic targets keep 45% of it, bosses keep 20%, and the totem's own leases are
## the only thing its cleanup removes.
func _test_control_shares_and_cleanup() -> void:
	var host := _host()
	var normal := _target(host, Vector2(100.0, 0.0))
	var epic := _target(host, Vector2(130.0, 0.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(160.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, WEAPON_ID), "the control fixture must activate")
	var activation = controller.active_activation()
	_advance(activation, 0.61)
	var normal_status := _status(normal)
	var epic_status := _status(epic)
	var boss_status := _status(boss)
	_check(is_equal_approx(float(normal_status.get("duration", 0.0)), 7.8)
		and is_equal_approx(float(normal_status.get("speed_multiplier", 0.0)), 0.58)
		and is_equal_approx(float(normal_status.get("accuracy_multiplier", 0.0)), 0.65),
		"a normal target must carry the full declared mark")
	_check(is_equal_approx(float(epic_status.get("duration", 0.0)), 3.51)
		and is_equal_approx(float(boss_status.get("duration", 0.0)), 1.56),
		"epic and boss marks must keep their resistant shares")
	_advance(activation, CAST_SECONDS)
	controller.cancel()
	await process_frame
	for target in [normal, epic, boss]:
		_check(_status(target).is_empty(),
			"vortex cleanup must remove only its own marks")
	await _drop(host)


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	var row := Budget.row_for(rows, CLASS_ID, WEAPON_ID)
	var ledger := Ledger.new(row)
	ledger.begin_encounter(Budget.ENCOUNTER_NORMAL)
	ledger.apply_start_charge(1.0)
	_check(ledger.try_activate(), "the cast must spend one full charge")
	ledger.apply_start_charge(1.0)
	_check(not ledger.try_activate(), "an encounter must refuse a second cast")
	ledger.set_ultimate_active(true)
	var before := ledger.charge
	ledger.add_removed_health(float(row["reference_solo_dps"]) * 30.0)
	_check(is_equal_approx(ledger.charge, before),
		"the active window must not earn charge")
	ledger.set_ultimate_active(false)
	ledger.apply_start_charge(0.63)
	var restored := Ledger.new(row)
	restored.apply_snapshot(ledger.to_snapshot())
	_check(is_equal_approx(restored.charge, 63.0),
		"charge must survive battle, act and Continue snapshots")


func _host() -> Host:
	var host := Host.new()
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


func _status(target: Node) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with("druid_ultimate_raven_"):
			return StatusEffects.snapshot(target)[status_id] as Dictionary
	return {}


func _removed_health(targets: Array[Target]) -> float:
	var removed := 0.0
	for target in targets:
		removed += target.removed_by_damage
	return removed


func _drop(host: Host) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("druid_raven_totem_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("druid_raven_totem_test: %s" % error)
	quit(1)
