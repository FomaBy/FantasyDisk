extends SceneTree

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")
const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Ledger := preload("res://scripts/ultimates/balance/ultimate_charge_ledger.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")
const PD := preload("res://scripts/progression_data.gd")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerScene := preload("res://scenes/Player.tscn")

const CLASS_ID := "priest"
const STEP := 0.01


class FixtureTarget extends Node2D:
	var health := 5000.0
	var max_health := 5000.0
	var archetype := "swarm"
	var received: Array[Dictionary] = []

	func take_damage(amount: float, feedback := {}) -> void:
		received.append({"amount": amount, "feedback": (feedback as Dictionary).duplicate(true)})
		health = maxf(health - amount, 0.0)


class FixturePlayer extends Node2D:
	var health := 100.0
	var max_health := 100.0


class FixtureHost extends Node2D:
	var fixture_targets: Array[Node2D] = []
	var player: FixturePlayer = null
	var active := false
	var base_damage := 10.0
	var modifiers := {}

	func ultimate_host_context() -> Dictionary:
		return {"damage": base_damage, "multiplier": 1.0, "damage_type": "magic"}

	func ultimate_host_position() -> Vector2:
		return global_position

	func ultimate_host_aim(_max_range: float) -> Dictionary:
		return {"point": global_position + Vector2.RIGHT, "direction": Vector2.RIGHT}

	func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
		var found: Array[Node2D] = []
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
		target.call("take_damage", amount, feedback)

	func ultimate_host_modifier(key: String, value: float, operation: String) -> void:
		if operation == "mul":
			modifiers[key] = float(modifiers.get(key, 1.0)) * value
		else:
			modifiers[key] = float(modifiers.get(key, 0.0)) + value

	func ultimate_host_repair(target: Node, amount: float) -> void:
		if target == player:
			player.health = minf(player.health + amount, player.max_health)

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
	await _test_reliquary()
	await _test_censer()
	await _test_chime()
	_test_charge_and_persistence_contract()
	_holder.queue_free()
	await process_frame
	_report()


func _test_reliquary() -> void:
	var host := await _host()
	host.player.health = 60.0
	for index in 3:
		_target(host, Vector2(110.0 + 60.0 * index, 0.0), 5000.0, 5000.0)
	var boss := _target(host, Vector2(340.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "priest_reliquary"), "Reliquary must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 5.35)
	_check(effect != null and float(effect.get("actual_removed_for_tests")) > 0.0,
		"all three rings must record actual HP removed before healing")
	_check(is_equal_approx(activation.applied_total, _removed_health(host.fixture_targets)),
		"Reliquary attribution must equal HP actually removed")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.08),
		"Reliquary rings must share the frozen 8% boss cap")
	_check(host.player.health == host.player.max_health,
		"the final pillar must heal the owner from actual damage")
	_check(float(host.modifiers.get("absorb_flat", 0.0)) > 0.0,
		"Reliquary overheal must become a temporary shield")
	for target in host.fixture_targets:
		_check(not _status_with_prefix(target, "priest_ultimate_reliquary_").is_empty(),
			"the sanctify ring must lease its mark")
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not host.active, "Reliquary cancel must close the active window")
	_check(is_zero_approx(float(host.modifiers.get("absorb_flat", 0.0))),
		"Reliquary cancellation must reverse its shield")
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "priest_ultimate_reliquary_").is_empty(),
			"Reliquary cancellation must clear only its marks")
	await _drop(host)


func _test_censer() -> void:
	await _test_censer_real_hit_and_cancel()
	await _test_censer_natural_completion()
	await _test_censer_new_run_cleanup()
	await _test_censer_transition_cleanup()


func _test_censer_real_hit_and_cancel() -> void:
	var player := await _real_player()
	var targets: Array = []
	targets.append(await _real_enemy(Vector2(120.0, 0.0)))
	targets.append(await _real_enemy(Vector2(210.0, 0.0)))
	var original_weapon := player.get("equipped_weapon") as Node
	var controller = PlayerHost.for_player(player).controller()
	_check(controller.activate(CLASS_ID, "priest_censer"), "Censer must activate on the real Player host")
	var activation: Activation = controller.active_activation()
	var effect := _effect(activation)
	var modifiers := player.get("run_modifiers") as Dictionary
	_check(effect != null and player.get("equipped_weapon") == effect,
		"Censer must observe the real Player owner-event seam while active")
	if activation == null or effect == null:
		controller.cancel()
		await _drop_real(player, targets)
		return
	_check(modifiers.has("absorb_flat") and float(modifiers["absorb_flat"]) > 0.0,
		"Censer must grant the declared strong temporary mitigation")

	var incoming := 10.0
	var absorb := float((player.get("derived_parameters") as Dictionary).get("absorb", 0.0))
	var post_absorb := maxf(
		incoming - absorb, incoming * PD.SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION
	)
	var actual_prevented := maxf(incoming - post_absorb, 0.0)
	var expected_stored := minf(
		actual_prevented * activation.param_float("stored_ratio", 0.0),
		activation.scaled_damage("stored_cap", 0.0)
	)
	(player.get("derived_parameters") as Dictionary)["dodge"] = 0.0
	player.set("debug_godmode", false)
	player.set("damage_invulnerability_time", 0.0)
	player.set("_damage_invulnerability_left", 0.0)
	var health_before := float(player.get("health"))
	player.call("take_damage", incoming)
	var health_after := float(player.get("health"))
	var stored := float(effect.get("stored_prevented_for_tests"))
	_check(actual_prevented > 0.0 and effect != null \
			and is_equal_approx(stored, expected_stored),
		"real Player prevention expected %.2f stored %.2f (absorb %.2f, HP %.2f -> %.2f)" % [
			expected_stored, stored, absorb, health_before, health_after,
		])

	var health_before_counter := _real_health(targets)
	effect.call("counter_burst")
	var health_after_counter := _real_health(targets)
	effect.call("counter_burst")
	_check(health_after_counter < health_before_counter,
		"Censer must emit its stored prevention as holy counter damage")
	_check(float(effect.get("counter_burst_for_tests")) <= activation.scaled_damage("counter_damage_cap", 0.0),
		"Censer counter damage must remain capped")
	_check(is_equal_approx(_real_health(targets), health_after_counter),
		"repeated Censer counter resolution must remain idempotent")

	controller.cancel()
	_check(not modifiers.has("absorb_flat"),
		"Censer cancellation must synchronously remove its transient mitigation key")
	_check(player.get("equipped_weapon") == original_weapon,
		"Censer cancellation must synchronously restore the real equipped weapon")
	await process_frame
	await _drop_real(player, targets)


func _test_censer_natural_completion() -> void:
	var player := await _real_player()
	var original_weapon := player.get("equipped_weapon") as Node
	var controller = PlayerHost.for_player(player).controller()
	_check(controller.activate(CLASS_ID, "priest_censer"), "natural Censer fixture must activate")
	var activation: Activation = controller.active_activation()
	var modifiers := player.get("run_modifiers") as Dictionary
	_advance(activation, 7.7)
	await process_frame
	_check(not controller.is_active(), "Censer must finish on its declared timeline")
	_check(not modifiers.has("absorb_flat"),
		"natural Censer completion must remove its transient mitigation key")
	_check(player.get("equipped_weapon") == original_weapon,
		"natural Censer completion must restore the equipped weapon")
	await _drop_real(player, [])


func _test_censer_new_run_cleanup() -> void:
	var player := await _real_player()
	var controller = PlayerHost.for_player(player).controller()
	_check(controller.activate(CLASS_ID, "priest_censer"), "new-run Censer fixture must activate")
	player.call("configure_character", CLASS_ID, "priest_censer")
	await process_frame
	_check(not controller.is_active(), "a new run must cancel the live Censer")
	_check(not (player.get("run_modifiers") as Dictionary).has("absorb_flat"),
		"battle/act reset must not carry the Censer mitigation key")
	await _drop_real(player, [])


func _test_censer_transition_cleanup() -> void:
	var player := await _real_player()
	var controller = PlayerHost.for_player(player).controller()
	_check(controller.activate(CLASS_ID, "priest_censer"), "transition Censer fixture must activate")
	var modifiers := player.get("run_modifiers") as Dictionary
	PlayerHost.reset(player)
	await process_frame
	_holder.remove_child(player)
	_check(not controller.is_active(), "leaving the battle tree must cancel the live Censer")
	_check(not modifiers.has("absorb_flat"),
		"battle/act transition must remove the Censer mitigation key")
	player.queue_free()
	await process_frame
	var continued := await _real_player()
	_check(not (continued.get("run_modifiers") as Dictionary).has("absorb_flat"),
		"Continue must start without a stale Censer mitigation key")
	await _drop_real(continued, [])


func _test_chime() -> void:
	var host := await _host()
	host.player.health = 20.0
	var normal := _target(host, Vector2(110.0, 0.0), 5000.0, 5000.0)
	var epic := _target(host, Vector2(170.0, 0.0), 5000.0, 5000.0)
	epic.add_to_group(Activation.EPIC_GROUP)
	var boss := _target(host, Vector2(230.0, 0.0), 1000.0, 1000.0)
	boss.add_to_group(Activation.BOSS_GROUP)
	var controller := Controller.new(host, _registry)
	_check(controller.activate(CLASS_ID, "priest_chime"), "Chime must activate")
	var activation := controller.active_activation()
	var effect := _effect(activation)
	_advance(activation, 0.55)
	_check(bool(_status_with_prefix(normal, "priest_ultimate_chime_").get("movement_locked", false)),
		"the first bell must interrupt normal targets")
	_check(not bool(_status_with_prefix(epic, "priest_ultimate_chime_").get("movement_locked", false))
			and not bool(_status_with_prefix(boss, "priest_ultimate_chime_").get("movement_locked", false)),
		"epics and bosses must resist the interrupt lock and only stagger")
	_advance(activation, 3.60)
	_check(effect != null and int(effect.get("toll_count_for_tests")) == 3,
		"Chime must resolve exactly three tolls")
	_check(float(effect.get("chain_removed_for_tests")) > 0.0 and host.player.health > 20.0,
		"the second bell's actual damage must fund the third bell heal")
	_check(is_equal_approx(float(host.modifiers.get("death_save", 0.0)), 1.0),
		"the third bell must open exactly one temporary lethal-prevention window")
	_check(is_equal_approx(boss.max_health - boss.health, boss.max_health * 0.08),
		"all Chime damage must share the frozen 8% boss cap")
	_advance(activation, 2.4)
	await process_frame
	_check(not controller.is_active() and not host.active,
		"Chime completion must close the active window")
	_check(is_zero_approx(float(host.modifiers.get("death_save", 0.0))),
		"Chime completion must remove lethal prevention")
	for target in host.fixture_targets:
		_check(_status_with_prefix(target, "priest_ultimate_chime_").is_empty(),
			"Chime completion must clear only its status leases")
	await _drop(host)


func _test_charge_and_persistence_contract() -> void:
	var rows := Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)
	for weapon_id in ["priest_reliquary", "priest_censer", "priest_chime"]:
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
	var player := FixturePlayer.new()
	host.add_child(player)
	host.player = player
	await process_frame
	return host


func _real_player() -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", CLASS_ID, "priest_censer")
	await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _real_enemy(position: Vector2) -> Node2D:
	var enemy := EnemyScene.instantiate() as Node2D
	_holder.add_child(enemy)
	enemy.global_position = position
	enemy.set("max_health", 5000.0)
	enemy.set("health", 5000.0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.set_process(false)
	enemy.set_physics_process(false)
	await process_frame
	return enemy


func _real_health(targets: Array) -> float:
	var total := 0.0
	for target in targets:
		if target is Node and is_instance_valid(target):
			total += float(target.get("health"))
	return total


func _drop_real(player: Node, targets: Array) -> void:
	for target in targets:
		if target is Node and is_instance_valid(target):
			target.queue_free()
	if player != null and is_instance_valid(player):
		player.queue_free()
	await process_frame


func _target(host: FixtureHost, position: Vector2, health: float, max_health: float) -> FixtureTarget:
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


func _status_with_prefix(target: Node, prefix: String) -> Dictionary:
	for status_id in StatusEffects.snapshot(target):
		if str(status_id).begins_with(prefix):
			return (StatusEffects.snapshot(target)[status_id] as Dictionary).duplicate(true)
	return {}


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
		print("priest_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("priest_live_test: %s" % error)
	print("priest_live_test: FAIL (%d)" % _errors.size())
	quit(1)
