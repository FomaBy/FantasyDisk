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
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const PD := preload("res://scripts/progression_data.gd")

const READY_CLASS := "sniper"
const READY_WEAPON := "sniper_deadeye_rifle"
const READY_WEAPONS := [
	"sniper_deadeye_rifle",
	"sniper_spotter_scope",
	"sniper_shatter_rounds",
]


## FAN-2044 deploy fixture: its untyped-compatible `owner_node` can hold the
## real host adapter, which is what the primitive's ownership check verifies.
class TemporaryDeployFixture extends Node2D:
	var owner_node: Node = null


class ReadyRegistry extends RefCounted:
	var canonical_pairs: Dictionary = {}
	var profiles: Dictionary = {}
	var executable_pairs: Dictionary = {}

	func _init(pairs: Dictionary) -> void:
		canonical_pairs = pairs.duplicate(true)

	func resolution_source(class_id: String, weapon_id: String, _allow_legacy := true) -> String:
		var key := Resolver.profile_key(class_id, weapon_id)
		if not canonical_pairs.has(key):
			return Resolver.SOURCE_INVALID_PAIR
		var profile := profiles.get(key, {}) as Dictionary
		return Resolver.SOURCE_WEAPON_PROFILE \
			if executable_pairs.has(key) and str(profile.get("implementation_state", "")) == "ready" \
			else Resolver.SOURCE_LEGACY_CLASS_FALLBACK

	func catalog_profile_for(class_id: String, weapon_id: String) -> Dictionary:
		return (profiles.get(Resolver.profile_key(class_id, weapon_id), {}) as Dictionary).duplicate(true)

	func admit_ready_profile(profile: Dictionary) -> void:
		var key := Resolver.profile_key(str(profile.get("class_id", "")), str(profile.get("weapon_id", "")))
		profiles[key] = profile.duplicate(true)
		executable_pairs[key] = true


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
	await _test_exact_ready_pair_routing()
	await _test_incomplete_ready_profile_refuses_before_player_side_effects()
	await _test_ready_declaration_runs_through_the_adapter()
	await _test_new_run_drops_a_live_cast()
	await _test_node_end_drops_a_live_cast()
	await _test_new_run_drops_deploys_and_repair_state()

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


func _test_exact_ready_pair_routing() -> void:
	var registry := ReadyRegistry.new(_canonical_pairs())
	for weapon_id in READY_WEAPONS:
		var profile := _ready_profile(weapon_id, {
			"strategy_id": "burst",
			"params": {"radius": 400.0, "damage": 1.0, "target_limit": 0},
		}, 0.1)
		_check(not profile.is_empty(), "%s fixture must satisfy the live executor contract" % weapon_id)
		registry.admit_ready_profile(profile)

	var legacy_pairs := 0
	for raw_class_id in PD.WEAPONS_BY_CLASS.keys():
		var class_id := str(raw_class_id)
		for raw_weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			var weapon_id := str(raw_weapon_id)
			var source := registry.resolution_source(class_id, weapon_id)
			if class_id == READY_CLASS and READY_WEAPONS.has(weapon_id):
				_check(source == Resolver.SOURCE_WEAPON_PROFILE,
					"%s/%s exact ready pair must select weapon_profile" % [class_id, weapon_id])
				_check(str(registry.catalog_profile_for(class_id, weapon_id).get("weapon_id", "")) == weapon_id,
					"%s/%s exact ready pair must retain weapon identity" % [class_id, weapon_id])
			else:
				legacy_pairs += 1
				_check(source == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
					"%s/%s declared or unbound pair must keep legacy fallback" % [class_id, weapon_id])
	_check(legacy_pairs == 48, "all 48 remaining declared or unbound pairs must keep legacy fallback")
	_check(
		registry.resolution_source(READY_CLASS, "__unknown_weapon__") == Resolver.SOURCE_INVALID_PAIR,
		"unknown package pairs must stay invalid"
	)
	await process_frame


func _test_ready_declaration_runs_through_the_adapter() -> void:
	var player := await _spawn_player()
	var enemy := await _spawn_enemy(Vector2(120.0, 0.0))
	for weapon_id in READY_WEAPONS:
		player.call("configure_character", READY_CLASS, weapon_id)
		await process_frame
		_check(_inject_ready_profile(player, weapon_id, {
			"strategy_id": "burst",
			"params": {"radius": 400.0, "damage": 1.0, "target_limit": 0},
		}, 0.1), "%s ready burst fixture must satisfy the live contract" % weapon_id)

		var health_before := float(enemy.get("health"))
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")), "%s ready declaration must report a cast" % weapon_id)
		_check(
			float(enemy.get("health")) < health_before,
			"%s adapter must route generic damage into the real enemy contract" % weapon_id
		)
		_check(
			is_zero_approx(float(player.get("ultimate_charge"))),
			"%s generic cast must spend the charge exactly once" % weapon_id
		)
		_check(
			not bool(player.call("activate_ultimate")),
			"%s spent charge must refuse the next input" % weapon_id
		)

	if is_instance_valid(enemy):
		enemy.queue_free()
	player.queue_free()
	await process_frame


func _test_new_run_drops_a_live_cast() -> void:
	var player := await _spawn_player()
	_check(_inject_ready_profile(player, READY_WEAPON, {
		"strategy_id": "timed_modifier",
		"params": {
			"duration": 30.0,
			"radius": 200.0,
			"modifiers": {"move_speed_multiplier": {"value": 1.5, "op": "mul"}},
		},
	}, 0.1), "the ready timed-modifier fixture must satisfy the live contract")

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
	_check(_inject_ready_profile(player, READY_WEAPON, {
		"strategy_id": "timed_modifier",
		"params": {
			"duration": 30.0,
			"radius": 200.0,
			"modifiers": {"absorb_flat": {"value": 12.0, "op": "add"}},
		},
	}, 0.1), "the ready timed-modifier fixture must satisfy the live contract")
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


## FAN-2044: a class executor that used the repair and temporary-deploy host
## primitives inside a live cast must lose all of that state on a new run.
func _test_new_run_drops_deploys_and_repair_state() -> void:
	var player := await _spawn_player()
	_check(_inject_ready_profile(player, READY_WEAPON, {
		"strategy_id": "timed_modifier",
		"params": {"duration": 30.0, "radius": 200.0, "modifiers": {}},
	}, 0.1), "the ready holder fixture must satisfy the live contract")
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "the holder cast must start")
	var controller = PlayerHost.for_player(player).controller()
	var activation = controller.active_activation()
	_check(activation != null, "the live cast must expose its activation")

	var template := Node2D.new()
	template.set_script(TemporaryDeployFixture)
	var deploy_scene := PackedScene.new()
	deploy_scene.pack(template)
	template.free()
	var deployed: Array[Node] = activation.deploy_temporary(deploy_scene, {}, 2)
	_check(deployed.size() == 2, "a live cast must accept a temporary deploy")
	for node in deployed:
		_check(node.get("owner_node") == PlayerHost.for_player(player),
			"a live deploy must attribute back to the real adapter")
	_check(activation.configure_repair(12.0), "a live cast must accept a repair cap")
	player.set("health", float(player.get("max_health")) - 6.0)
	_check(
		is_equal_approx(float(activation.repair(player, 20.0)["applied"]), 6.0),
		"hero repair through the adapter must restore only the missing HP"
	)

	player.call("configure_character", READY_CLASS, READY_WEAPON)
	await process_frame
	_check(not controller.is_active(), "a new run must drop the holding cast")
	for node in deployed:
		_check(not is_instance_valid(node), "a new run must remove every temporary deploy")
	_check(
		activation.repair(player, 5.0)["applied"] == 0.0,
		"repair state must not survive the new run"
	)

	player.queue_free()
	await process_frame


# --- fixture plumbing --------------------------------------------------------

func _test_incomplete_ready_profile_refuses_before_player_side_effects() -> void:
	var player := await _spawn_player()
	var charge := float(player.get("ultimate_max_charge"))
	player.set("ultimate_charge", charge)
	_check(
		not _inject_ready_profile(player, READY_WEAPON, {
			"strategy_id": "burst",
			"params": {"radius": 400.0, "damage": 1.0},
		}, 0.1),
		"an incomplete ready profile must be rejected before fixture injection"
	)
	_check(
		is_equal_approx(float(player.get("ultimate_charge")), charge),
		"a rejected ready profile must not spend player charge"
	)
	_check(
		not bool(player.get("_ultimate_active")),
		"a rejected ready profile must not mark the player active"
	)
	_check(
		player.get_node_or_null(PlayerHost.NODE_NAME) == null,
		"a rejected ready profile must not create a host side effect"
	)
	player.queue_free()
	await process_frame

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


## Swap the shared catalog for one normalized, exact ready package pair.
func _inject_ready_profile(
	player: Node2D,
	weapon_id: String,
	executor: Dictionary,
	total_boss_cap: float
) -> bool:
	var profile := _ready_profile(weapon_id, executor, total_boss_cap)
	if profile.is_empty():
		return false
	var registry := ReadyRegistry.new(_canonical_pairs())
	registry.admit_ready_profile(profile)
	if registry.resolution_source(READY_CLASS, weapon_id) != Resolver.SOURCE_WEAPON_PROFILE:
		return false
	PlayerHost.for_player(player).use_registry(registry)
	return true


func _ready_profile(weapon_id: String, executor: Dictionary, total_boss_cap: float) -> Dictionary:
	var strategy_id := str(executor.get("strategy_id", ""))
	var normalized := Library.normalize_params(strategy_id, executor.get("params", {}))
	if not (normalized["errors"] as Array).is_empty():
		return {}
	return {
		"class_id": READY_CLASS,
		"weapon_id": weapon_id,
		"implementation_state": "ready",
		"total_boss_cap": total_boss_cap,
		"executor": {"strategy_id": strategy_id, "params": normalized["params"]},
	}


func _canonical_pairs() -> Dictionary:
	return Registry.new(PD.WEAPONS_BY_CLASS).canonical_pairs_for_tests()


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
