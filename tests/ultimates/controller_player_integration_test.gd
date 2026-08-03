extends SceneTree

## Player-side evidence for FAN-1457; shipped ready-package contract per FAN-2057.
##
## Two halves:
##  1. Shipped contract — the real registry routes exactly the three ready
##     Biologist packages through `weapon_profile`, every other declared pair
##     keeps the legacy class fallback, and the real adapter follows that
##     routing pair by pair: legacy ultimates run unchanged, ready packages
##     cast through the generic runtime, and each live generic cast the loop
##     starts is cancelled without leaking state.
##  2. Fixture integration — with a synthetic ready declaration injected, the
##     UltimatePlayerHost adapter drives the generic runtime end to end, and a
##     new run or a node end drops the live cast instead of carrying it over.
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

const FIXTURE_CLASS := "sniper"
const FIXTURE_WEAPON := "sniper_deadeye_rifle"
const FIXTURE_WEAPONS := [
	"sniper_deadeye_rifle",
	"sniper_spotter_scope",
	"sniper_shatter_rounds",
]
const SHIPPED_READY_CLASS := "biologist"
const SHIPPED_READY_WEAPONS := [
	"biologist_spore_lens",
	"biologist_sample_injector",
	"biologist_symbiote_seed",
]
const SHIPPED_LEGACY_PAIRS := 48


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

	await _test_catalog_routes_exact_ready_packages()
	await _test_player_adapter_follows_shipped_routing()
	await _test_exact_ready_pair_routing()
	await _test_incomplete_ready_profile_refuses_before_player_side_effects()
	await _test_ready_declaration_runs_through_the_adapter()
	await _test_new_run_drops_a_live_cast()
	await _test_node_end_drops_a_live_cast()

	_holder.queue_free()
	await process_frame
	_report()


## The shipped registry is the routing contract: exactly the three ready
## Biologist packages may leave the legacy bridge, nothing else.
func _test_catalog_routes_exact_ready_packages() -> void:
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.is_valid(), "shipped catalog must stay valid: %s" % str(registry.validation_errors()))
	_check(
		(registry.package_validation_errors() as Array).is_empty(),
		"shipped packages must stay valid: %s" % str(registry.package_validation_errors())
	)
	var ready_pairs := 0
	var legacy_pairs := 0
	for class_id in registry.class_ids():
		for weapon_id in registry.weapon_ids(class_id):
			var source := str(registry.resolution_source(class_id, weapon_id))
			if class_id == SHIPPED_READY_CLASS and SHIPPED_READY_WEAPONS.has(weapon_id):
				ready_pairs += 1
				_check(
					source == Resolver.SOURCE_WEAPON_PROFILE,
					"%s/%s ready package must resolve through weapon_profile" % [class_id, weapon_id]
				)
				var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
				_check(
					str(profile.get("class_id", "")) == class_id
						and str(profile.get("weapon_id", "")) == weapon_id,
					"%s/%s ready package must retain exact pair identity" % [class_id, weapon_id]
				)
				_check(
					str(profile.get("implementation_state", "")) == "ready",
					"%s/%s package must stay declared ready" % [class_id, weapon_id]
				)
			else:
				legacy_pairs += 1
				_check(
					source == Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
					"%s/%s must keep the legacy class fallback" % [class_id, weapon_id]
				)
	_check(
		ready_pairs == SHIPPED_READY_WEAPONS.size(),
		"the catalog must carry all three ready Biologist packages"
	)
	_check(
		legacy_pairs == SHIPPED_LEGACY_PAIRS,
		"all %d remaining catalog pairs must keep legacy fallback" % SHIPPED_LEGACY_PAIRS
	)
	_check(
		registry.resolution_source(SHIPPED_READY_CLASS, "__unknown_weapon__")
			== Resolver.SOURCE_INVALID_PAIR,
		"unknown package pairs must stay invalid"
	)
	await process_frame


## The real adapter on the real registry, pair by pair: legacy pairs run their
## class ultimate off the generic runtime, ready Biologist pairs cast through
## it, charge is spent once either way, and every live generic cast is
## cancelled without leaking state.
func _test_player_adapter_follows_shipped_routing() -> void:
	var player := await _spawn_player()
	var enemy := await _spawn_enemy(Vector2(90.0, 0.0))
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(
		Activation.host_supports(PlayerHost.for_player(player)),
		"the player host adapter must implement the whole host contract"
	)

	var generic_casts := 0
	for class_id in registry.class_ids():
		for weapon_id in registry.weapon_ids(class_id):
			player.call("configure_character", class_id, weapon_id)
			await process_frame
			var expects_generic := str(registry.resolution_source(class_id, weapon_id)) \
				== Resolver.SOURCE_WEAPON_PROFILE
			var modifiers_before: Dictionary = (player.get("run_modifiers") as Dictionary).duplicate(true)
			player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
			_check(
				bool(player.call("ultimate_ready")),
				"%s/%s must be able to charge its ultimate" % [class_id, weapon_id]
			)
			_check(bool(player.call("activate_ultimate")), "%s/%s ultimate must fire" % [class_id, weapon_id])
			var controller = PlayerHost.for_player(player).controller()
			if expects_generic:
				generic_casts += 1
				_check(
					controller.is_active(),
					"%s/%s ready package must cast through the generic runtime" % [class_id, weapon_id]
				)
			else:
				_check(
					not controller.is_active(),
					"%s/%s must still run its legacy ultimate, not the generic runtime" % [class_id, weapon_id]
				)
			_check(
				is_zero_approx(float(player.get("ultimate_charge"))),
				"%s/%s activation must spend the charge exactly once" % [class_id, weapon_id]
			)
			_check(
				not bool(player.call("activate_ultimate")),
				"%s/%s must refuse a second activation on an empty charge" % [class_id, weapon_id]
			)
			if expects_generic:
				controller.cancel()
				_check(
					not controller.is_active(),
					"%s/%s cancelled generic cast must not stay live" % [class_id, weapon_id]
				)
				_check(
					not bool(player.get("_ultimate_active")),
					"%s/%s cancelled generic cast must clear the active flag" % [class_id, weapon_id]
				)
				_check(
					(player.get("run_modifiers") as Dictionary) == modifiers_before,
					"%s/%s cancelled generic cast must not leak run modifiers" % [class_id, weapon_id]
				)
	_check(
		generic_casts == SHIPPED_READY_WEAPONS.size(),
		"exactly the three ready Biologist pairs must reach the generic runtime"
	)

	if is_instance_valid(enemy):
		enemy.queue_free()
	player.queue_free()
	await process_frame


func _test_exact_ready_pair_routing() -> void:
	var registry := ReadyRegistry.new(_canonical_pairs())
	for weapon_id in FIXTURE_WEAPONS:
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
			if class_id == FIXTURE_CLASS and FIXTURE_WEAPONS.has(weapon_id):
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
		registry.resolution_source(FIXTURE_CLASS, "__unknown_weapon__") == Resolver.SOURCE_INVALID_PAIR,
		"unknown package pairs must stay invalid"
	)
	await process_frame


func _test_ready_declaration_runs_through_the_adapter() -> void:
	var player := await _spawn_player()
	var enemy := await _spawn_enemy(Vector2(120.0, 0.0))
	for weapon_id in FIXTURE_WEAPONS:
		player.call("configure_character", FIXTURE_CLASS, weapon_id)
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
	_check(_inject_ready_profile(player, FIXTURE_WEAPON, {
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

	player.call("configure_character", FIXTURE_CLASS, FIXTURE_WEAPON)
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
	_check(_inject_ready_profile(player, FIXTURE_WEAPON, {
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


# --- fixture plumbing --------------------------------------------------------

func _test_incomplete_ready_profile_refuses_before_player_side_effects() -> void:
	var player := await _spawn_player()
	var charge := float(player.get("ultimate_max_charge"))
	player.set("ultimate_charge", charge)
	_check(
		not _inject_ready_profile(player, FIXTURE_WEAPON, {
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
	player.call("configure_character", FIXTURE_CLASS, FIXTURE_WEAPON)
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
	if registry.resolution_source(FIXTURE_CLASS, weapon_id) != Resolver.SOURCE_WEAPON_PROFILE:
		return false
	PlayerHost.for_player(player).use_registry(registry)
	return true


func _ready_profile(weapon_id: String, executor: Dictionary, total_boss_cap: float) -> Dictionary:
	var strategy_id := str(executor.get("strategy_id", ""))
	var normalized := Library.normalize_params(strategy_id, executor.get("params", {}))
	if not (normalized["errors"] as Array).is_empty():
		return {}
	return {
		"class_id": FIXTURE_CLASS,
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
