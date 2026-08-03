extends SceneTree

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "druid"
const STEP := 0.01


class Target extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": feedback.duplicate(true)})
		health = maxf(health - amount, 0.0)


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
			return left.global_position.distance_squared_to(center) < right.global_position.distance_squared_to(center)
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
		"Druid packages must admit cleanly: %s" % [_registry.package_validation_errors()])
	await _test_wild_hunt()
	await _test_briar_lattice()
	await _test_raven_vortex()
	await _test_real_player_path()
	_test_charge_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_wild_hunt() -> void:
	var host := _host()
	var boss := _target(host, Vector2(180.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "summon_amulet"), "Wild Hunt must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_check(effect != null and int(effect.get("pack_count_for_tests")) == 8,
		"Wild Hunt must create eight transient spectral beasts")
	_advance(activation, 5.4)
	_check(int(effect.get("hunt_waves_for_tests")) == 6,
		"Wild Hunt must complete its declared priority hunt cadence")
	_check(boss.health < boss.max_health and boss.max_health - boss.health <= boss.max_health * 0.08,
		"all beast impacts must share the eight-percent whole-activation boss cap")
	controller.cancel()
	await process_frame
	_check(not is_instance_valid(effect) and not host.active,
		"cancellation must remove the transient hunt and its active latch")
	await _drop(host)


func _test_briar_lattice() -> void:
	var host := _host()
	var normal := _target(host, Vector2(120.0, 0.0))
	var epic := _target(host, Vector2(160.0, 0.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(200.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "briar_staff"), "Forest In One Breath must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 1.11)
	_check(effect != null and int(effect.get("seed_count_for_tests")) == 5,
		"the lattice must grow from exactly five seeds")
	var normal_status := _status(normal, "druid_ultimate_briar_")
	var epic_status := _status(epic, "druid_ultimate_briar_")
	var boss_status := _status(boss, "druid_ultimate_briar_")
	_check(bool(normal_status.get("movement_locked", false)), "normal targets must be rooted")
	_check(not bool(epic_status.get("movement_locked", false)) and is_equal_approx(float(epic_status.get("duration", 0.0)), 2.25),
		"epic targets must keep only the resistant slow")
	_check(not bool(boss_status.get("movement_locked", false)) and is_equal_approx(float(boss_status.get("duration", 0.0)), 1.0),
		"bosses must keep only the capped control window")
	_advance(activation, 3.7)
	_check(int(effect.get("impale_count_for_tests")) == 3,
		"the lattice must resolve exactly three impale pulses")
	_check(boss.max_health - boss.health <= boss.max_health * 0.08,
		"all thorn damage must share the whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [normal, epic, boss]:
		_check(_status(target, "druid_ultimate_briar_").is_empty(),
			"lattice cleanup must remove only its leased control")
	await _drop(host)


func _test_raven_vortex() -> void:
	var host := _host()
	var normal := _target(host, Vector2(100.0, 0.0))
	var epic := _target(host, Vector2(130.0, 0.0))
	epic.add_to_group("elite_enemies")
	var boss := _target(host, Vector2(160.0, 0.0))
	boss.add_to_group("bosses")
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "raven_totem"), "Night of a Thousand Wings must activate")
	var activation = controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.61)
	var normal_status := _status(normal, "druid_ultimate_raven_")
	var epic_status := _status(epic, "druid_ultimate_raven_")
	var boss_status := _status(boss, "druid_ultimate_raven_")
	_check(is_equal_approx(float(normal_status.get("speed_multiplier", 0.0)), 0.58)
		and is_equal_approx(float(normal_status.get("accuracy_multiplier", 0.0)), 0.65),
		"raven marks must reduce normal speed and accuracy")
	_check(is_equal_approx(float(epic_status.get("duration", 0.0)), 3.51)
		and is_equal_approx(float(boss_status.get("duration", 0.0)), 1.56),
		"epic and boss marks must use the shared control-resistance policy")
	_advance(activation, 6.6)
	_check(effect != null and int(effect.get("dive_count_for_tests")) == 4
		and int(effect.get("wisp_return_count_for_tests")) > 0,
		"the marked flock must perform four dives and return damage wisps")
	_check(boss.max_health - boss.health <= boss.max_health * 0.08,
		"dives and collapse must share the whole-activation boss cap")
	controller.cancel()
	await process_frame
	for target in [normal, epic, boss]:
		_check(_status(target, "druid_ultimate_raven_").is_empty(),
			"vortex cleanup must remove only its own marks")
	await _drop(host)


func _test_charge_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in ["summon_amulet", "briar_staff", "raven_totem"]:
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


func _test_real_player_path() -> void:
	for weapon_id in ["summon_amulet", "briar_staff", "raven_totem"]:
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
		print("druid_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("druid_live_test: %s" % error)
	quit(1)
