extends SceneTree

## FAN-3268: rework of the FAN-3264 focused Meteor Core proof. The old version
## only checked that impact reached every normal and that the boss aggregate
## sat at its cap; it never asserted a single crater pulse, per-tier control
## shaping or a real charge-ledger commit. This version proves each of those
## against the unchanged production executor
## (res://scripts/ultimates/classes/elementalist/elementalist_meteor_core.gd)
## and its data (res://data/ultimates/classes/elementalist/elementalist_meteor_core.json).

const StatusEffects := preload("res://scripts/status_effects.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const MeteorCore := preload("res://scripts/ultimates/classes/elementalist/elementalist_meteor_core.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "elementalist"
const WEAPON_ID := "elementalist_meteor_core"
const STEP := 0.01

# Cumulative tween schedule baked into the JSON contract (impact_at, then five
# crater_interval pulses); a small buffer past each mark absorbs float drift
# from the STEP-sized custom_step loop without ever crossing the next mark.
const IMPACT_AT := 2.75
const PULSE_INTERVAL := 0.85
const PULSE_COUNT := 5
const ADVANCE_BUFFER := 0.02

const REGULAR_NORMAL_COUNT := 17
# Base damage 1.0 keeps impact_damage/crater_damage coefficients (13.0/1.3) as
# clean per-hit amounts; boss max_health 190 puts the 10% cap (19.0) between
# the 4th (18.2) and 5th (19.5) cumulative pulse total, so every one of the
# five boss hits is provably non-zero and the final one is the one that clips.
const BOSS_MAX_HEALTH := 190.0
const WEAK_NORMAL_MAX_HEALTH := 500.0
const REGULAR_MAX_HEALTH := 5000.0
const GRAVITY_PULL := 260.0
const CRATER_DURATION := 4.8


class FixtureTarget extends Node2D:
	var health := REGULAR_MAX_HEALTH
	var max_health := REGULAR_MAX_HEALTH
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)

	func crater_hits() -> int:
		var count := 0
		for entry in received:
			if str((entry["feedback"] as Dictionary).get("ultimate_mechanic", "")) == "meteor_crater":
				count += 1
		return count


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var aim_point := Vector2(600.0, 0.0)
	var base_damage := 1.0

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(max_range: float) -> Dictionary:
		var offset := aim_point - global_position
		var direction := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
		return {"point": global_position + direction * minf(offset.length(), max_range), "direction": direction}

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
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(_key: String, _value: float, _operation: String) -> void:
		pass

	func ultimate_host_effect_parent() -> Node:
		return self

	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node:
		return null

	func ultimate_host_set_active(_value: bool) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_test_contract_and_economy()
	_holder = Node2D.new()
	root.add_child(_holder)
	await process_frame
	await _test_map_wide_impact_and_crater()
	await _test_ledger_backed_commit()
	await _test_scale_smoke()
	_holder.queue_free()
	await process_frame
	_report()


func _test_contract_and_economy() -> void:
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.package_validation_errors().is_empty(),
		"Meteor Core package discovery must remain clean: %s" % [registry.package_validation_errors()])
	var profile := registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	var params := (profile["executor"] as Dictionary)["params"] as Dictionary
	_check(not MeteorCore.parameter_contract().has("crowd_cap"),
		"Meteor Core contract must not expose a count-shaped crowd cap")
	_check(not params.has("crowd_cap"),
		"Meteor Core data must not ship a count-shaped crowd cap")
	_check(is_equal_approx(float(profile.get("total_boss_cap", 0.0)), 0.10),
		"Meteor Core must preserve its 10% whole-activation boss cap")
	_check(str((profile["charge"] as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
		"Meteor Core must preserve the rare charge ledger")


## AC1-3: >20 live targets (far normal, epic, boss included); every one of the
## five crater pulses proven separately per eligible live target with no
## duplicate pulse effect; per-tier control shaping; boss non-zero and capped
## at exactly 10% max_health across impact plus all five pulses.
func _test_map_wide_impact_and_crater() -> void:
	var host := FixtureHost.new()
	_holder.add_child(host)
	await process_frame

	var boss := FixtureTarget.new()
	boss.max_health = BOSS_MAX_HEALTH
	boss.health = BOSS_MAX_HEALTH
	boss.global_position = host.aim_point
	boss.add_to_group(Activation.BOSS_GROUP)
	host.add_child(boss)
	host.fixture_targets.append(boss)

	var epic := FixtureTarget.new()
	epic.global_position = host.aim_point + Vector2(150.0, 90.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	host.add_child(epic)
	host.fixture_targets.append(epic)

	var normal_far := FixtureTarget.new()
	normal_far.global_position = host.aim_point + Vector2(900.0, 0.0)
	host.add_child(normal_far)
	host.fixture_targets.append(normal_far)

	var weak_normal := FixtureTarget.new()
	weak_normal.max_health = WEAK_NORMAL_MAX_HEALTH
	weak_normal.health = WEAK_NORMAL_MAX_HEALTH
	weak_normal.global_position = host.aim_point + Vector2(50.0, 0.0)
	host.add_child(weak_normal)
	host.fixture_targets.append(weak_normal)

	var live_normals: Array[FixtureTarget] = [normal_far]
	for index in REGULAR_NORMAL_COUNT:
		var target := FixtureTarget.new()
		target.global_position = host.aim_point \
			+ Vector2.RIGHT.rotated(TAU * float(index) / REGULAR_NORMAL_COUNT) * (40.0 + index)
		host.add_child(target)
		host.fixture_targets.append(target)
		live_normals.append(target)

	_check(host.fixture_targets.size() > 20,
		"the focused cast must field more than 20 live targets")

	var controller := Controller.new(host, Registry.new(PD.WEAPONS_BY_CLASS))
	_check(controller.activate(CLASS_ID, WEAPON_ID), "Meteor Core must activate")
	var activation := controller.active_activation()
	_check(activation != null and not activation.spawned_for_tests().is_empty(),
		"Meteor Core must spawn its crater effect on activation")
	var effect := activation.spawned_for_tests()[0]
	var status_id := "elementalist_meteor_crater_%d" % effect.get_instance_id()

	# --- impact: damage, execute, per-tier control shaping ---
	_advance(activation, IMPACT_AT + ADVANCE_BUFFER)
	_check(int(effect.get("impact_count_for_tests")) == 1, "impact must resolve exactly once")
	_check(int(effect.get("execute_count_for_tests")) == 1,
		"exactly one weak normal must be executed at impact")

	for target in live_normals:
		_check(target.received.size() == 1 and is_equal_approx(float(target.received[0]["amount"]), 13.0),
			"every live normal enemy must take one non-zero impact hit")
		_check(str((target.received[0]["feedback"] as Dictionary).get("ultimate_mechanic", "")) == "meteor_impact",
			"the impact hit must be tagged meteor_impact")
	_check(is_equal_approx(epic.received[0]["amount"], 13.0) and epic.received.size() == 1,
		"the epic target must take the same impact damage as a normal")
	_check(is_equal_approx(boss.received[0]["amount"], 13.0) and boss.received.size() == 1,
		"the boss must take the same impact damage as a normal, before its cap trims later pulses")

	_check(weak_normal.received.size() == 2, "a weak normal must receive impact then execute")
	_check(is_equal_approx(weak_normal.received[0]["amount"], 13.0),
		"the weak normal's impact hit must be the standard amount")
	_check(str((weak_normal.received[1]["feedback"] as Dictionary).get("ultimate_mechanic", "")) == "meteor_normal_execute",
		"the weak normal's second hit must be tagged meteor_normal_execute")
	_check(is_equal_approx(weak_normal.received[1]["amount"], WEAK_NORMAL_MAX_HEALTH - 13.0),
		"execute must finish exactly the health the weak normal had left")
	_check(is_zero_approx(weak_normal.health), "an executed weak normal must reach zero health")

	for target in [epic, boss]:
		for entry in target.received:
			_check(str((entry["feedback"] as Dictionary).get("ultimate_mechanic", "")) != "meteor_normal_execute",
				"execute must never reach an epic or boss target")
	for target in live_normals:
		if is_equal_approx(target.max_health, WEAK_NORMAL_MAX_HEALTH):
			continue
		for entry in target.received:
			_check(str((entry["feedback"] as Dictionary).get("ultimate_mechanic", "")) != "meteor_normal_execute",
				"execute must never reach a normal enemy above the execute health rail")

	# Displacement/duration shaping: normal is full, epic is 0.25/0.40, boss is 0/0.20.
	_check(normal_far.knockbacks.size() == 1 and is_equal_approx(normal_far.knockbacks[0].length(), GRAVITY_PULL),
		"a normal target must receive full impact displacement")
	_check(epic.knockbacks.size() == 1 and is_equal_approx(epic.knockbacks[0].length(), GRAVITY_PULL * 0.25),
		"an epic target must receive 0.25x impact displacement")
	_check(boss.knockbacks.is_empty(),
		"a boss target must receive zero impact displacement")
	_check(is_equal_approx(float(StatusEffects.status_value(normal_far, status_id, "duration", -1.0)), CRATER_DURATION),
		"a normal target must receive the full crater control duration")
	_check(is_equal_approx(float(StatusEffects.status_value(epic, status_id, "duration", -1.0)), CRATER_DURATION * 0.40),
		"an epic target must receive 0.40x crater control duration")
	_check(is_equal_approx(float(StatusEffects.status_value(boss, status_id, "duration", -1.0)), CRATER_DURATION * 0.20),
		"a boss target must receive 0.20x crater control duration")

	# --- five crater pulses: proven separately, one new non-zero hit each ---
	var pulse_targets: Array[FixtureTarget] = live_normals.duplicate()
	pulse_targets.append(epic)
	pulse_targets.append(boss)
	for pulse in range(PULSE_COUNT):
		_advance(activation, PULSE_INTERVAL + ADVANCE_BUFFER)
		_check(int(effect.get("pulse_count_for_tests")) == pulse + 1,
			"crater pulse %d must resolve exactly once" % pulse)
		for target in pulse_targets:
			_check(target.crater_hits() == pulse + 1,
				"every eligible live target must gain exactly one new meteor_crater hit on pulse %d" % pulse)
			var last: Dictionary = target.received[target.received.size() - 1]
			_check(str((last["feedback"] as Dictionary).get("ultimate_mechanic", "")) == "meteor_crater"
					and float(last["amount"]) > 0.0,
				"the newest hit after pulse %d must be a non-zero meteor_crater hit" % pulse)

	# A replayed pulse index must never duplicate its effect (production guard).
	effect.call("crater_pulse", 0)
	_check(int(effect.get("pulse_count_for_tests")) == PULSE_COUNT,
		"replaying an already-resolved pulse index must not fire it again")
	_check(normal_far.crater_hits() == PULSE_COUNT,
		"a replayed pulse index must not add a duplicate hit")

	_check(boss.health < boss.max_health, "Meteor Core must affect the boss")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.10),
		"Meteor impact and crater pulses must preserve the 10% boss cap exactly")

	controller.cancel()
	await process_frame
	host.queue_free()
	await process_frame


## AC4: UltimateController.activate(..., commit) is backed by a real
## UltimateChargeLedger — a full charge spends to zero exactly once with
## encounter_activations == 1; a rejected commit starts no gameplay and
## leaves charge/state unchanged.
func _test_ledger_backed_commit() -> void:
	var host := FixtureHost.new()
	_holder.add_child(host)
	await process_frame
	var target := FixtureTarget.new()
	target.global_position = host.aim_point
	host.add_child(target)
	host.fixture_targets.append(target)

	var ledger := Ledger.new()
	ledger.begin_encounter()
	ledger.apply_start_charge(1.0)
	var commit := Callable(ledger, "try_activate")
	var controller := Controller.new(host, Registry.new(PD.WEAPONS_BY_CLASS))

	_check(controller.activate(CLASS_ID, WEAPON_ID, commit),
		"a full ledger charge must commit and start the cast")
	_check(is_zero_approx(ledger.charge),
		"a committed activation must spend the full charge to zero")
	_check(ledger.encounter_activations() == 1,
		"a committed activation must count exactly one encounter activation")
	controller.cancel()
	await process_frame

	ledger.apply_start_charge(1.0)
	_check(not controller.activate(CLASS_ID, WEAPON_ID, commit),
		"a second commit in the same encounter must be rejected")
	_check(not controller.is_active(), "a rejected commit must start no gameplay")
	_check(is_equal_approx(ledger.charge, 100.0),
		"a rejected commit must leave the refilled charge unchanged")
	_check(ledger.encounter_activations() == 1,
		"a rejected commit must not add another encounter activation")

	host.queue_free()
	await process_frame


## AC7: bounded no-SLA scale smoke — at least 100 live targets, proving
## impact plus all five map-wide pulse phases complete without the
## presentation/spawn footprint growing with crowd size.
func _test_scale_smoke() -> void:
	var host := FixtureHost.new()
	_holder.add_child(host)
	await process_frame
	var scale_count := 100
	for index in scale_count:
		var target := FixtureTarget.new()
		target.global_position = host.aim_point \
			+ Vector2.RIGHT.rotated(TAU * float(index) / scale_count) * (40.0 + index)
		host.add_child(target)
		host.fixture_targets.append(target)
	_check(host.fixture_targets.size() >= 100, "the scale smoke must field at least 100 live targets")

	var controller := Controller.new(host, Registry.new(PD.WEAPONS_BY_CLASS))
	_check(controller.activate(CLASS_ID, WEAPON_ID), "the scale smoke cast must activate")
	var activation := controller.active_activation()
	_check(activation != null and not activation.spawned_for_tests().is_empty(),
		"the scale smoke cast must spawn its crater effect")
	var effect := activation.spawned_for_tests()[0]

	_advance(activation, IMPACT_AT + PULSE_COUNT * PULSE_INTERVAL + ADVANCE_BUFFER)
	_check(int(effect.get("impact_count_for_tests")) == 1,
		"impact must resolve exactly once regardless of crowd size")
	_check(int(effect.get("pulse_count_for_tests")) == PULSE_COUNT,
		"all five map-wide pulses must complete regardless of crowd size")
	_check(activation.spawned_for_tests().size() == 1,
		"the spawn footprint must stay bounded, not grow with target count")
	for raw_target in host.fixture_targets:
		_check(not (raw_target as FixtureTarget).received.is_empty(),
			"every one of %d live targets must be reached by the map-wide cast" % scale_count)

	controller.cancel()
	await process_frame
	host.queue_free()
	await process_frame


func _advance(activation: Activation, seconds: float) -> void:
	if activation == null:
		return
	var elapsed := 0.0
	while elapsed < seconds:
		for tween in activation.tweens_for_tests():
			if tween != null and tween.is_valid():
				tween.custom_step(STEP)
		elapsed += STEP


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("elementalist_meteor_core_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("elementalist_meteor_core_test: %s" % error)
	print("elementalist_meteor_core_test: FAIL (%d)" % _errors.size())
	quit(1)
