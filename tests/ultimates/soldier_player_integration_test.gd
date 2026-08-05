extends SceneTree

## Live Player regression for the staged Soldier package. It uses the real Player,
## UltimatePlayerHost and UltimateController; only package discovery is injected.

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Discovery := preload("res://scripts/ultimates/registry/weapon_ultimate_package_discovery.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const Schema := preload("res://scripts/ultimates/schema/weapon_ultimate_schema.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPON_ID := "soldier_rifle"
const DATA_ROOT := "res://data/ultimates/staged/classes"
const SCRIPT_ROOT := "res://scripts/ultimates/staged/classes"
const IMPACT_SECONDS := 1.35
const LIFECYCLE_SECONDS := 5.6
const GRACE_SECONDS := 1.0


class StagedRegistry extends RefCounted:
	var canonical_pairs: Dictionary
	var profiles: Dictionary = {}
	var executors: Dictionary = {}
	var pairs: Dictionary = {}

	func _init(discovery: Discovery, canonical: Dictionary) -> void:
		canonical_pairs = canonical.duplicate(true)
		pairs = discovery.pair_keys()
		for raw_key in pairs:
			var key := str(raw_key)
			profiles[key] = discovery.profile_for(key)
			executors[key] = discovery.executor_for(key)

	func resolution_source(class_id: String, weapon_id: String, _allow_legacy := true) -> String:
		var key := Resolver.profile_key(class_id, weapon_id)
		if not canonical_pairs.has(key):
			return Resolver.SOURCE_INVALID_PAIR
		if pairs.has(key) and str((profiles.get(key, {}) as Dictionary).get("implementation_state", "")) == "ready":
			return Resolver.SOURCE_WEAPON_PROFILE
		return Resolver.SOURCE_LEGACY_CLASS_FALLBACK

	func catalog_profile_for(class_id: String, weapon_id: String) -> Dictionary:
		return (profiles.get(Resolver.profile_key(class_id, weapon_id), {}) as Dictionary).duplicate(true)

	func executor_for(class_id: String, weapon_id: String):
		return executors.get(Resolver.profile_key(class_id, weapon_id))


var _errors: Array[String] = []
var _holder: Node2D
var _registry: StagedRegistry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	var shipped := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(shipped.is_valid(), "the shipped registry must remain valid")
	_check(shipped.package_validation_errors().is_empty(),
		"the shipped registry must have no package errors")
	_check(shipped.resolution_source(CLASS_ID, WEAPON_ID)
		== Resolver.SOURCE_LEGACY_CLASS_FALLBACK,
		"the shipped Soldier rifle must remain legacy-routed")
	var discovery := Discovery.new(DATA_ROOT, SCRIPT_ROOT)
	discovery.discover(Schema.index_documents(shipped.documents_for_tests()))
	_check(discovery.validation_errors().is_empty(),
		"the staged Soldier package must validate: %s" % [discovery.validation_errors()])
	_registry = StagedRegistry.new(discovery, shipped.canonical_pairs_for_tests())
	_check(_registry.resolution_source(CLASS_ID, WEAPON_ID) == Resolver.SOURCE_WEAPON_PROFILE,
		"the exact staged Soldier rifle must be injectable")

	await _test_live_rifle_impact_and_cleanup()
	await _test_cancel_and_new_run_cleanup()
	await _test_node_end_cleanup()

	_holder.queue_free()
	current_scene = null
	await process_frame
	_report()


func _test_live_rifle_impact_and_cleanup() -> void:
	var player := await _spawn_player()
	var host := PlayerHost.for_player(player)
	var enemies := await _spawn_enemies(player, host)
	host.use_registry(_registry)
	var controller = host.controller()
	var baseline := _health_total(enemies)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "the staged rifle must use the real Player path")
	var activation = controller.active_activation()
	_check(activation != null and bool(player.get("_ultimate_active")),
		"the real Player path must expose one active rifle cast")
	_check(is_zero_approx(float(player.get("ultimate_charge"))),
		"the real Player path must spend the charge exactly once")
	_check(not bool(player.call("activate_ultimate")),
		"the real Player path must refuse the empty-charge recast")
	_check(float(activation.applied_total) <= 0.01 and is_equal_approx(_health_total(enemies), baseline),
		"the activation frame must only telegraph; disabled auto-attack cannot supply a false hit")

	var impact_deadline := Time.get_ticks_msec() + int(ceil((IMPACT_SECONDS + GRACE_SECONDS) * 1000.0))
	while float(activation.applied_total) <= 0.01 and Time.get_ticks_msec() < impact_deadline:
		await process_frame
	_check(float(activation.applied_total) > 0.01,
		"the live rifle must affect its reachable targets by %.2fs" % IMPACT_SECONDS)

	var cleanup_deadline := Time.get_ticks_msec() + int(ceil((LIFECYCLE_SECONDS + GRACE_SECONDS) * 1000.0))
	while controller.is_active() and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active")) and activation.is_finished(),
		"the live rifle must clear controller, player and activation state by %.2fs" % LIFECYCLE_SECONDS)
	await _drop(player, enemies)


func _test_cancel_and_new_run_cleanup() -> void:
	var player := await _spawn_player()
	var host := PlayerHost.for_player(player)
	var enemies := await _spawn_enemies(player, host)
	host.use_registry(_registry)
	var controller = host.controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a staged rifle cast must start before cancellation")
	var activation = controller.active_activation()
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation != null and activation.is_finished(),
		"cancel must leave no active rifle controller or activation")

	# FAN-2074: отменённый каст уже потратил единственную активацию encounter'а —
	# ledger обязан отказать в повторе и ничего не списать; новый бой открывает гейт.
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(not bool(player.call("activate_ultimate")),
		"the encounter-use ledger must refuse a same-encounter recast after cancel")
	_check(is_equal_approx(float(player.get("ultimate_charge")), float(player.get("ultimate_max_charge"))),
		"a refused same-encounter recast must spend nothing")
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a staged rifle cast must start before a new run")
	var new_run_activation = controller.active_activation()
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and new_run_activation != null and new_run_activation.is_finished(),
		"a new run must cancel the staged rifle without residual active state")
	await _drop(player, enemies)


func _test_node_end_cleanup() -> void:
	var player := await _spawn_player()
	var host := PlayerHost.for_player(player)
	var enemies := await _spawn_enemies(player, host)
	host.use_registry(_registry)
	var controller = host.controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a staged rifle cast must start before node end")
	var activation = controller.active_activation()
	_holder.remove_child(player)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation != null and activation.is_finished(),
		"node end must cancel the staged rifle without residual active state")
	player.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func _spawn_player() -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.global_position = Vector2(900.0, 700.0)
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	var weapon := player.get("equipped_weapon") as Node
	if weapon != null:
		weapon.set_process(false)
		weapon.set_physics_process(false)
	return player


func _spawn_enemies(player: Node2D, host: Node) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var aim := host.call("ultimate_host_aim", 960.0) as Dictionary
	var aim_point := aim.get("point", player.global_position) as Vector2
	var direction := aim.get("direction", Vector2.ZERO) as Vector2
	_check(direction.length_squared() > 0.001 and aim_point.distance_to(player.global_position) > 0.001,
		"the real Player aim snapshot must be usable for staged rifle targeting")
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	if aim_point.distance_to(player.global_position) <= 0.001:
		aim_point = player.global_position + direction.normalized() * 960.0
	var side := Vector2(-direction.y, direction.x).normalized()
	for offset in [-direction * 100.0, Vector2.ZERO, direction * 100.0 + side * 30.0]:
		var enemy := EnemyScene.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = aim_point + offset
		enemy.add_to_group("enemies")
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await process_frame
	return enemies


func _health_total(enemies: Array[Node2D]) -> float:
	var total := 0.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			total += float(enemy.get("health"))
	return total


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
		print("soldier_player_integration_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("soldier_player_integration_test: %s" % error)
	print("soldier_player_integration_test: FAIL (%d)" % _errors.size())
	quit(1)
