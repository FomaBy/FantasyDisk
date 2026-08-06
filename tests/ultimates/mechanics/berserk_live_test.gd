extends SceneTree

## FAN-2131: the three Berserk mechanics resolve on a live activation and stay
## distinguishable — expanding blade orbits with an inward cross, an aimed
## execution loop to the arena edge and back, and three ordered rift beats.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/berserk_live_test.gd

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")
const Sword := preload("res://scripts/ultimates/classes/berserk/sword.gd")
const Axe := preload("res://scripts/ultimates/classes/berserk/axe.gd")
const Hammer := preload("res://scripts/ultimates/classes/berserk/hammer.gd")

const CLASS_ID := "berserk"
const WEAPONS := ["sword", "axe", "hammer"]
const STEP := 0.01
# `blade_hits_for_tests` counts blade/target contacts, so the whirlwind
# expectations are written against this fixture's target count.
const VORTEX_TARGETS := 3


class Target extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var received: Array[Dictionary] = []
	var knockbacks: Array[Vector2] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": feedback.duplicate(true)})
		health = maxf(health - amount, 0.0)

	func apply_knockback(impulse: Vector2) -> void:
		knockbacks.append(impulse)


class Host extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var active := false
	var base_damage := 12.0

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
	_check(_registry.package_validation_errors().is_empty(),
		"Berserk packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	_test_primitive_falsifications()
	await _test_scarlet_whirlwind()
	await _test_execution_loop()
	await _test_fourfold_rift()
	await _test_ordered_composition_fails_closed()
	await _test_real_player_path()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


## The four primitives this class had to derive locally are pure functions, so
## both branches of each are asserted here instead of only the branch a live
## cast happens to walk.
func _test_primitive_falsifications() -> void:
	_check(Sword.blade_ready(null, 0.0, 2.2), "an untouched blade must be ready")
	_check(not Sword.blade_ready(0.6, 2.25, 2.2), "a blade must refuse a hit inside its cooldown")
	_check(Sword.blade_ready(0.6, 2.8, 2.2), "a blade must re-arm exactly after its cooldown")
	_check(is_equal_approx(Sword.orbit_radius(0, 11, 190.0, 420.0), 190.0)
		and is_equal_approx(Sword.orbit_radius(10, 11, 190.0, 420.0), 420.0)
		and Sword.orbit_radius(4, 11, 190.0, 420.0) < Sword.orbit_radius(5, 11, 190.0, 420.0),
		"orbits must expand monotonically from the inner to the outer radius")

	_check(Axe.arena_edge(Vector2.ZERO, Vector2.RIGHT, 900.0) == Vector2(900.0, 0.0),
		"the loop must reach the declared arena radius along the aim")
	_check(Axe.arena_edge(Vector2.ZERO, Vector2.ZERO, 900.0) == Vector2(900.0, 0.0),
		"a degenerate aim must fall back to a deterministic arena edge")
	_check(Axe.trajectory_point(Vector2.ZERO, Vector2(900.0, 0.0), 0.5) == Vector2(450.0, 0.0),
		"the trajectory sample must interpolate hero to arena edge")
	_check(Axe.execute_ready(20.0, 100.0, 0.3), "a target under the threshold must be executable")
	_check(not Axe.execute_ready(50.0, 100.0, 0.3),
		"a target above the threshold must survive the catch")
	_check(not Axe.execute_ready(0.0, 100.0, 0.3), "an already dead target must not be executed")
	_check(Axe.pass_allowed(1.0, 2) and not Axe.pass_allowed(2.0, 2),
		"the double-pass cap must admit two contacts and refuse the third")

	_check(Hammer.lane_axes(0)[0].is_equal_approx(Vector2.RIGHT),
		"the first beat must run the world cardinal lanes")
	_check(Hammer.lane_axes(1)[0].is_equal_approx(Vector2.RIGHT.rotated(PI * 0.25)),
		"the second beat must run the diagonals")


func _test_scarlet_whirlwind() -> void:
	var host := _host()
	var normal := _target(host, Vector2(150.0, 0.0))
	var epic := _target(host, Vector2(160.0, 0.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(170.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "sword"), "Scarlet Whirlwind must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.61)
	_check(effect != null
		and (effect.get("blade_hits_for_tests") as Array) == [VORTEX_TARGETS, 0, 0],
		"the first sweep must belong to exactly one blade")
	_advance(activation, 0.56)
	_check((effect.get("blade_hits_for_tests") as Array) == [VORTEX_TARGETS, VORTEX_TARGETS, 0],
		"each sweep must hand the orbit to the next blade")
	var normal_status := _status(normal, "berserk_ultimate_whirlwind_")
	var epic_status := _status(epic, "berserk_ultimate_whirlwind_")
	var boss_status := _status(boss, "berserk_ultimate_whirlwind_")
	_check(is_equal_approx(float(normal_status.get("duration", 0.0)), 3.0)
		and is_equal_approx(float(normal_status.get("speed_multiplier", 0.0)), 0.62),
		"the vortex must slow normal targets for its declared window")
	_check(is_equal_approx(float(epic_status.get("duration", 0.0)), 1.35)
		and is_equal_approx(float(boss_status.get("duration", 0.0)), 0.6),
		"epic and boss targets must keep only the resistant share of the vortex")
	_advance(activation, 6.4)
	var radii := effect.get("sweep_radii_for_tests") as Array
	_check(radii.size() == 11 and is_equal_approx(float(radii[0]), 190.0)
		and is_equal_approx(float(radii[10]), 420.0),
		"eleven sweeps must expand the orbit from 190 to 420, got %s" % [radii])
	_check((effect.get("blade_hits_for_tests") as Array)
		== [2 * VORTEX_TARGETS, 2 * VORTEX_TARGETS, 2 * VORTEX_TARGETS],
		"each blade must bite twice per target across eleven sweeps, got %s"
			% [effect.get("blade_hits_for_tests")])
	_check(int(effect.get("cross_count_for_tests")) == 1,
		"the cast must end in exactly one inward cross slash")
	_check(normal.received.size() == 7,
		"a target inside the vortex must take six gated blade hits and the cross")
	_check(boss.max_health - boss.health <= boss.max_health * 0.1,
		"every blade and the cross must share the whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [normal, epic, boss]:
		_check(_status(target, "berserk_ultimate_whirlwind_").is_empty(),
			"vortex cleanup must remove only its own leased slow")
	await _drop(host)


func _test_execution_loop() -> void:
	var host := _host()
	var low := _target(host, Vector2(300.0, 0.0))
	low.health = 2000.0
	var healthy := _target(host, Vector2(400.0, 0.0))
	var epic := _target(host, Vector2(500.0, 0.0))
	epic.health = 2000.0
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(600.0, 0.0))
	boss.add_to_group("bosses")
	var aside := _target(host, Vector2(300.0, 400.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "axe"), "Executioner's Loop must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and (effect.get("edge_for_tests") as Vector2) == Vector2(900.0, 0.0),
		"the axe must fly to the arena edge along the aim")
	_advance(activation, 0.46)
	_check((effect.get("beat_trace_for_tests") as Array) == ["outbound"]
		and int(effect.get("marked_count_for_tests")) == 4,
		"the outbound pass must mark exactly the corridor, got %s" % [effect.get("marked_count_for_tests")])
	_check(aside.received.is_empty(), "a target beside the corridor must stay untouched")
	_check(low.received.size() == 1 and boss.received.size() == 1,
		"the outbound pass must land once on every corridor target")
	_advance(activation, 2.21)
	_check((effect.get("beat_trace_for_tests") as Array) == ["outbound", "turn"],
		"the loop must turn at the arena edge before returning")
	_advance(activation, 2.41)
	_check((effect.get("beat_trace_for_tests") as Array) == ["outbound", "turn", "return"],
		"the return catch must be the third and last beat")
	_check(int(effect.get("executed_count_for_tests")) == 1,
		"only the marked normal target under the threshold may be executed")
	_check(low.received.size() == 3, "the executed target must take pass, catch and finisher")
	_check(healthy.received.size() == 2, "a healthy target must survive on two loop passes")
	_check(epic.received.size() == 2,
		"an epic target must be denied the execute by the control policy")
	_check(boss.received.size() == 2,
		"a boss must never exceed the declared double-pass cap")
	_check(boss.max_health - boss.health <= boss.max_health * 0.1,
		"both loop passes must share the whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [low, healthy, epic, boss]:
		_check(_status(target, "berserk_ultimate_loop_mark_").is_empty(),
			"loop cleanup must remove its own execution marks")
	await _drop(host)


func _test_fourfold_rift() -> void:
	var host := _host()
	var cardinal := _target(host, Vector2(200.0, 0.0))
	var diagonal := _target(host, Vector2(150.0, 150.0))
	var epic := _target(host, Vector2(0.0, 210.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(-220.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "hammer"), "Fourfold Rift must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.71)
	_check(activation.composition_trace_for_tests() == ["cardinal_lanes"],
		"the rift must open on the cardinal beat")
	_check(cardinal.received.size() == 1 and diagonal.received.is_empty(),
		"the cardinal beat must hit the world axes and spare the diagonals")
	_advance(activation, 0.86)
	_check(activation.composition_trace_for_tests() == ["cardinal_lanes", "diagonal_lanes"],
		"the second beat must be the diagonals")
	_check(diagonal.received.size() == 1,
		"the diagonal beat must reach the targets the cardinal lanes missed")
	_advance(activation, 0.86)
	_check(activation.composition_trace_for_tests()
		== ["cardinal_lanes", "diagonal_lanes", "central_quake"],
		"the rift must close on the central quake")
	_check(not activation.composition_aborted(), "the declared order must not abort itself")
	_check(int(effect.get("staggered_count_for_tests")) == 4,
		"the quake must stagger every target inside its radius")
	_check(cardinal.knockbacks.size() == 1
		and is_equal_approx(cardinal.knockbacks[0].length(), 460.0),
		"a normal target must take the full stagger launch")
	_check(epic.knockbacks.size() == 1
		and is_equal_approx(epic.knockbacks[0].length(), 460.0 * 0.35)
		and boss.knockbacks.size() == 1
		and is_equal_approx(boss.knockbacks[0].length(), 460.0 * 0.1),
		"epic and boss targets must keep only the resistant share of the launch")
	_check(is_equal_approx(float(_status(cardinal, "berserk_ultimate_stagger_").get("duration", 0.0)), 1.4)
		and bool(_status(cardinal, "berserk_ultimate_stagger_").get("movement_locked", false)),
		"the stagger must lock a normal target for its declared window")
	_check(not bool(_status(boss, "berserk_ultimate_stagger_").get("movement_locked", false)),
		"a boss must never be movement locked by the quake")
	_check(boss.max_health - boss.health <= boss.max_health * 0.1,
		"all three beats must share the whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [cardinal, diagonal, epic, boss]:
		_check(_status(target, "berserk_ultimate_stagger_").is_empty(),
			"quake cleanup must remove only its own stagger leases")
	await _drop(host)


## The order is the mechanic: a beat that arrives out of turn aborts the
## composition instead of resolving early, and never damages anything.
func _test_ordered_composition_fails_closed() -> void:
	var host := _host()
	var target := _target(host, Vector2(200.0, 0.0))
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "hammer"), "Fourfold Rift must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	effect.call("beat", 2)
	_check(activation.composition_aborted(), "an out-of-order beat must abort the composition")
	_check(activation.composition_trace_for_tests().is_empty()
		and target.received.is_empty(),
		"an aborted beat must neither be traced nor deal damage")
	controller.cancel()
	await process_frame
	await _drop(host)


func _test_real_player_path() -> void:
	for weapon_id in WEAPONS:
		var player := PlayerScene.instantiate() as Node2D
		_holder.add_child(player)
		await process_frame
		player.call("configure_character", CLASS_ID, weapon_id)
		await process_frame
		player.set_process(false)
		player.set_physics_process(false)
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")),
			"%s must activate through the real Player entry point" % weapon_id)
		var controller = PlayerHost.for_player(player).controller()
		var activation = controller.active_activation()
		_check(controller.is_active() and activation != null
			and activation.spawned_for_tests().size() == 1,
			"%s must own one live activation scene through Player" % weapon_id)
		_check(is_zero_approx(float(player.get("ultimate_charge"))),
			"%s must spend the real Player charge exactly once" % weapon_id)
		player.call("_gain_ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(is_zero_approx(float(player.get("ultimate_charge"))),
			"%s must reject Player charge gain while active" % weapon_id)
		player.call("configure_character", CLASS_ID, weapon_id)
		await process_frame
		_check(not controller.is_active() and not bool(player.get("_ultimate_active")),
			"a new run must cancel %s through the real Player path" % weapon_id)
		player.queue_free()
		await process_frame


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in WEAPONS:
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
		_check(is_equal_approx(ledger.charge, before), "%s must not earn active-window charge" % weapon_id)
		ledger.set_ultimate_active(false)
		ledger.apply_start_charge(0.63)
		var restored := Ledger.new(row)
		restored.apply_snapshot(ledger.to_snapshot())
		_check(is_equal_approx(restored.charge, 63.0),
			"%s charge must survive battle, act and Continue snapshots" % weapon_id)


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


func _status(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return StatusEffects.snapshot(target)[status_id] as Dictionary
	return {}


func _drop(host: Host) -> void:
	host.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("berserk_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("berserk_live_test: %s" % error)
	quit(1)
