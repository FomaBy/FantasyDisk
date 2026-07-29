extends SceneTree

## Player-side evidence for FAN-1457.
##
## Two halves:
##  1. Compatibility — while every catalog profile is still `declared`, the
##     generic runtime declines and each class ultimate runs exactly as before,
##     spending its charge once.
##  2. Integration — with a ready declaration injected, the UltimatePlayerHost
##     adapter drives the generic runtime end to end, and a new run or a node
##     end drops the live cast instead of carrying it over.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/controller_player_integration_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const PD := preload("res://scripts/progression_data.gd")

const READY_CLASS := "berserk"
const READY_WEAPON := "sword"


class ReadyRegistry extends RefCounted:
	var profile: Dictionary = {}

	func resolution_source(_class_id: String, _weapon_id: String, _allow_legacy := true) -> String:
		return Resolver.SOURCE_WEAPON_PROFILE

	func catalog_profile_for(_class_id: String, _weapon_id: String) -> Dictionary:
		return profile.duplicate(true)


var _errors: Array[String] = []
var _holder: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	await _test_catalog_is_still_declared()
	await _test_legacy_class_ultimates_unchanged()
	await _test_ready_declaration_runs_through_the_adapter()
	await _test_new_run_drops_a_live_cast()
	await _test_node_end_drops_a_live_cast()

	_holder.queue_free()
	await process_frame
	_report()


## The migration bridge is only safe while nothing claims to be executable.
func _test_catalog_is_still_declared() -> void:
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "shipped catalog must stay valid: %s" % str(registry.validation_errors()))
	for class_id in registry.class_ids():
		for weapon_id in registry.weapon_ids(class_id):
			_check(
				str(registry.resolution_source(class_id, weapon_id))
					== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
				"%s/%s must still resolve to the legacy class ultimate" % [class_id, weapon_id]
			)
	await process_frame


func _test_legacy_class_ultimates_unchanged() -> void:
	var player := await _spawn_player()
	var enemy := await _spawn_enemy(Vector2(90.0, 0.0))
	_check(
		Activation.host_supports(PlayerHost.for_player(player)),
		"the player host adapter must implement the whole host contract"
	)

	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		var weapons: Dictionary = PD.WEAPONS_BY_CLASS[class_id]
		var weapon_id := str(weapons.keys()[0])
		player.call("configure_character", class_id, weapon_id)
		await process_frame
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("ultimate_ready")), "%s must be able to charge its ultimate" % class_id)

		_check(bool(player.call("activate_ultimate")), "%s ultimate must still fire" % class_id)
		_check(
			not PlayerHost.for_player(player).controller().is_active(),
			"%s must still run its legacy ultimate, not the generic runtime" % class_id
		)
		_check(
			is_zero_approx(float(player.get("ultimate_charge"))),
			"%s activation must spend the charge" % class_id
		)
		_check(
			not bool(player.call("activate_ultimate")),
			"%s must refuse a second activation on an empty charge" % class_id
		)

	if is_instance_valid(enemy):
		enemy.queue_free()
	player.queue_free()
	await process_frame


func _test_ready_declaration_runs_through_the_adapter() -> void:
	var player := await _spawn_player()
	var enemy := await _spawn_enemy(Vector2(120.0, 0.0))
	_inject_ready_profile(player, {
		"strategy_id": "burst",
		"params": {"radius": 400.0, "damage": 1.0},
	}, 0.1)

	var health_before := float(enemy.get("health"))
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a ready declaration must still report a cast")
	_check(
		float(enemy.get("health")) < health_before,
		"the adapter must route generic ultimate damage into the real enemy contract"
	)
	_check(
		is_zero_approx(float(player.get("ultimate_charge"))),
		"a generic cast must spend the charge exactly once"
	)
	_check(
		not bool(player.call("activate_ultimate")),
		"a spent charge must refuse the next input"
	)

	if is_instance_valid(enemy):
		enemy.queue_free()
	player.queue_free()
	await process_frame


func _test_new_run_drops_a_live_cast() -> void:
	var player := await _spawn_player()
	_inject_ready_profile(player, {
		"strategy_id": "timed_modifier",
		"params": {
			"duration": 30.0,
			"modifiers": {"move_speed_multiplier": {"value": 1.5, "op": "mul"}},
		},
	}, 0.1)

	var run_modifiers: Dictionary = player.get("run_modifiers")
	var before := float(run_modifiers.get("move_speed_multiplier", 1.0))
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "the timed cast must start")
	_check(
		PlayerHost.for_player(player).controller().is_active(),
		"a long timed cast must still be live before the new run"
	)
	_check(
		float((player.get("run_modifiers") as Dictionary).get("move_speed_multiplier", 1.0)) > before,
		"the timed modifier must reach run_modifiers through the adapter"
	)

	player.call("configure_character", READY_CLASS, READY_WEAPON)
	await process_frame
	_check(
		not PlayerHost.for_player(player).controller().is_active(),
		"a new run must not carry an active effect over"
	)
	_check(
		is_equal_approx(
			float((player.get("run_modifiers") as Dictionary).get("move_speed_multiplier", 1.0)), 1.0
		),
		"a new run must leave the ultimate modifier reverted"
	)

	player.queue_free()
	await process_frame


func _test_node_end_drops_a_live_cast() -> void:
	var player := await _spawn_player()
	_inject_ready_profile(player, {
		"strategy_id": "timed_modifier",
		"params": {
			"duration": 30.0,
			"modifiers": {"absorb_flat": {"value": 12.0, "op": "add"}},
		},
	}, 0.1)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "the timed cast must start")
	var controller = PlayerHost.for_player(player).controller()
	_check(controller.is_active(), "the cast must be live before the node ends")

	_holder.remove_child(player)
	_check(
		not controller.is_active(),
		"leaving the tree must drop the cast instead of stranding its modifiers"
	)
	_check(
		is_equal_approx(float((player.get("run_modifiers") as Dictionary).get("absorb_flat", 0.0)), 0.0),
		"leaving the tree must revert the transient modifier"
	)

	player.queue_free()
	await process_frame


# --- fixture plumbing --------------------------------------------------------

func _spawn_player() -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", READY_CLASS, READY_WEAPON)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _spawn_enemy(offset: Vector2) -> Node2D:
	var enemy := EnemyScene.instantiate() as Node2D
	_holder.add_child(enemy)
	enemy.global_position = offset
	enemy.set("max_health", 4000.0)
	enemy.set("health", 4000.0)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	await process_frame
	return enemy


## Swap the shared catalog for a single ready declaration so the real adapter
## can be exercised before any profile has been migrated.
func _inject_ready_profile(player: Node2D, executor: Dictionary, total_boss_cap: float) -> void:
	var registry := ReadyRegistry.new()
	registry.profile = {
		"class_id": READY_CLASS,
		"weapon_id": READY_WEAPON,
		"implementation_state": "ready",
		"total_boss_cap": total_boss_cap,
		"executor": executor,
	}
	PlayerHost.for_player(player).use_registry(registry)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("controller_player_integration_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("controller_player_integration_test: %s" % error)
	print("controller_player_integration_test: FAIL (%d)" % _errors.size())
	quit(1)
