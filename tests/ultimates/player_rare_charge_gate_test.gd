extends SceneTree

## FAN-2090: real-Player evidence for the rare-charge encounter gate.
##
## The shipped Doctor packages declare the `rare_charge_ledger` charge strategy:
## one ultimate activation per encounter. The real Player routes its charge and
## active state through UltimateChargeLedger, so a refilled bar must not cast
## again in the same encounter after cancel or natural completion. The
## accumulated charge stays a run resource and survives the battle boundary
## (combat_director snapshot -> fresh player node), where the fresh node is the
## canonical encounter reset. Pairs that declare `ultimate_charge_ledger` keep
## their pre-FAN-2090 refill activation.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/player_rare_charge_gate_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const CombatDirector := preload("res://scripts/combat_director.gd")

const DOCTOR_WEAPONS := ["restore_potion", "plague_syringe", "bone_saw"]
const COMPLETION_WEAPON := "restore_potion"
const COMPLETION_TIME_SCALE := 4.0
const COMPLETION_DEADLINE_SECONDS := 5.0
const CARRIED_CHARGE := 63.5


class StubGame extends RefCounted:
	var run_player_snapshot := {}
	var selected_character_id := "doctor"
	var selected_weapon_id := ""


var _errors: Array[String] = []
var _holder: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	_test_shipped_doctor_pairs_declare_rare_charge()
	for weapon_id in DOCTOR_WEAPONS:
		await _test_refill_after_cancel_is_refused(str(weapon_id))
	await _test_refill_after_natural_completion_is_refused()
	await _test_encounter_boundary_resets_gate_and_keeps_charge()
	await _test_standard_ledger_pair_keeps_refill_activation()

	_holder.queue_free()
	await process_frame
	_report()


## The data contract the gate is derived from: every Doctor pair resolves as a
## ready weapon profile and declares the rare_charge_ledger strategy.
func _test_shipped_doctor_pairs_declare_rare_charge() -> void:
	var registry = PlayerHost.shared_registry()
	for weapon_id in DOCTOR_WEAPONS:
		_check(
			str(registry.resolution_source("doctor", str(weapon_id))) == Resolver.SOURCE_WEAPON_PROFILE,
			"doctor/%s must resolve through its ready weapon profile" % weapon_id
		)
		var charge = registry.catalog_profile_for("doctor", str(weapon_id)).get("charge")
		_check(
			charge is Dictionary
				and str((charge as Dictionary).get("strategy_id", "")) == "rare_charge_ledger",
			"doctor/%s must declare the rare_charge_ledger strategy" % weapon_id
		)


func _test_refill_after_cancel_is_refused(weapon_id: String) -> void:
	var player := await _spawn_player("doctor", weapon_id)
	var enemies := await _spawn_enemies(player)
	var controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "doctor/%s first activation must fire" % weapon_id)
	_check(controller.is_active(), "doctor/%s must cast through the generic runtime" % weapon_id)
	_check(
		is_zero_approx(float(player.get("ultimate_charge"))),
		"doctor/%s activation must spend the charge" % weapon_id
	)
	controller.cancel()
	_check(
		not bool(player.get("_ultimate_active")),
		"doctor/%s cancel must clear the active latch" % weapon_id
	)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(
		not bool(player.call("activate_ultimate")),
		"doctor/%s refilled bar must refuse a second activation in the same encounter" % weapon_id
	)
	_check(
		is_equal_approx(float(player.get("ultimate_charge")), float(player.get("ultimate_max_charge"))),
		"doctor/%s refused activation must not spend the refilled charge" % weapon_id
	)
	await _drop(player, enemies)


func _test_refill_after_natural_completion_is_refused() -> void:
	var player := await _spawn_player("doctor", COMPLETION_WEAPON)
	var enemies := await _spawn_enemies(player)
	var controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "doctor completion case must start its cast")
	_check(controller.is_active(), "doctor completion case must own a live cast")
	var original_time_scale := Engine.time_scale
	Engine.time_scale = COMPLETION_TIME_SCALE
	var deadline := Time.get_ticks_msec() + int(COMPLETION_DEADLINE_SECONDS * 1000.0)
	while controller.is_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	Engine.time_scale = original_time_scale
	_check(not controller.is_active(), "doctor cast must complete naturally within the deadline")
	_check(
		not bool(player.get("_ultimate_active")),
		"doctor completion must clear the active latch"
	)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(
		not bool(player.call("activate_ultimate")),
		"doctor refilled bar must stay refused after natural completion"
	)
	await _drop(player, enemies)


## The production encounter boundary: the charge snapshot moves to the fresh
## player node of the next battle, the activation gate does not. No enemies
## here: adjacent contact damage would feed the taken-charge channel and shift
## the carried value under the exact-persistence assert (bone_saw casts fine
## without targets).
func _test_encounter_boundary_resets_gate_and_keeps_charge() -> void:
	var game := StubGame.new()
	var combat = CombatDirector.new(game)
	var first := await _spawn_player("doctor", "bone_saw")
	var controller = PlayerHost.for_player(first).controller()
	first.set("ultimate_charge", float(first.get("ultimate_max_charge")))
	_check(bool(first.call("activate_ultimate")), "battle-one activation must fire")
	controller.cancel()
	first.set("ultimate_charge", CARRIED_CHARGE)
	combat._store_player_snapshot(first)
	await _drop(first, [])

	var second := await _spawn_player("doctor", "bone_saw")
	combat._restore_player_snapshot(second)
	await process_frame
	_check(
		is_equal_approx(float(second.get("ultimate_charge")), CARRIED_CHARGE),
		"the accumulated charge must survive the battle boundary"
	)
	_check(
		not bool(second.call("activate_ultimate")),
		"a partially charged bar must not activate on the fresh node"
	)
	second.set("ultimate_charge", float(second.get("ultimate_max_charge")))
	_check(
		bool(second.call("activate_ultimate")),
		"the fresh encounter must accept one activation again"
	)
	PlayerHost.for_player(second).controller().cancel()
	await _drop(second, [])


## Pairs on the standard ultimate_charge_ledger strategy keep the established
## behavior: a refilled bar may activate again inside one encounter.
func _test_standard_ledger_pair_keeps_refill_activation() -> void:
	var player := await _spawn_player("sniper", "sniper_deadeye_rifle")
	var enemies := await _spawn_enemies(player)
	var controller = PlayerHost.for_player(player).controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "sniper first activation must fire")
	controller.cancel()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(
		bool(player.call("activate_ultimate")),
		"an ultimate_charge_ledger pair must keep its refill activation"
	)
	_check(
		is_zero_approx(float(player.get("ultimate_charge"))),
		"the retained refill activation must still spend the charge once"
	)
	controller.cancel()
	await _drop(player, enemies)


func _spawn_player(class_id: String, weapon_id: String) -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.global_position = Vector2(900.0, 700.0)
	player.call("configure_character", class_id, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	var weapon := player.get("equipped_weapon") as Node
	if weapon != null:
		weapon.set_process(false)
		weapon.set_physics_process(false)
	return player


func _spawn_enemies(player: Node2D) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for offset in [Vector2(140.0, 0.0), Vector2(220.0, 0.0), Vector2(300.0, 40.0)]:
		var enemy := EnemyScene.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = player.global_position + (offset as Vector2)
		enemy.add_to_group("enemies")
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await process_frame
	return enemies


func _drop(player: Node2D, enemies: Array[Node2D]) -> void:
	player.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("player_rare_charge_gate_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("player_rare_charge_gate_test: %s" % error)
	print("player_rare_charge_gate_test: FAIL (%d)" % _errors.size())
	quit(1)
