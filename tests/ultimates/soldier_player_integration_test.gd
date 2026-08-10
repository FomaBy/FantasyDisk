extends SceneTree

## Live Player regression for the shipped Soldier package through the real
## Player, UltimatePlayerHost, shared registry and UltimateController path.

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const PRIMARY_WEAPON_ID := "soldier_rifle"
const WEAPON_TIMINGS := {
	"soldier_rifle": {"impact": 1.35, "lifecycle": 5.6},
	"soldier_grenade": {"impact": 4.7, "lifecycle": 8.4},
	"soldier_bayonet": {"impact": 0.48, "lifecycle": 4.25},
}
const GRACE_SECONDS := 1.0

var _errors: Array[String] = []
var _holder: Node2D
var _registry


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_check(_registry.is_valid(), "the shipped registry must remain valid")
	_check(_registry.package_validation_errors().is_empty(),
		"the shipped registry must have no package errors")
	for weapon_id in WEAPON_TIMINGS:
		_check(_registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
			"%s must use the shipped weapon-profile route" % weapon_id)
		_check(_registry.has_exact_executor_pair(CLASS_ID, weapon_id),
			"%s must expose its shipped executor" % weapon_id)
		_assert_declared_timing(weapon_id)
		await _test_live_impact_and_cleanup(weapon_id)
	await _test_cancel_and_new_run_cleanup()
	await _test_node_end_cleanup()

	_holder.queue_free()
	current_scene = null
	await process_frame
	_report()


func _test_live_impact_and_cleanup(weapon_id: String) -> void:
	var timing := WEAPON_TIMINGS[weapon_id] as Dictionary
	var player := await _spawn_player(weapon_id)
	var host := PlayerHost.for_player(player)
	var enemies := await _spawn_enemies(player, host, weapon_id)
	var controller = host.controller()
	var baseline := _health_total(enemies)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	var started_ms := Time.get_ticks_msec()
	_check(bool(player.call("activate_ultimate")), "%s must use the real Player path" % weapon_id)
	var activation = controller.active_activation()
	_check(activation != null and bool(player.get("_ultimate_active")),
		"the real Player path must expose one active %s cast" % weapon_id)
	if activation == null:
		await _drop(player, enemies)
		return
	_check((activation.tweens_for_tests() as Array).size() == 1,
		"%s must own exactly one lifecycle tween" % weapon_id)
	_check(is_zero_approx(float(player.get("ultimate_charge"))),
		"the real Player path must spend the charge exactly once")
	_check(not bool(player.call("activate_ultimate")),
		"the real Player path must refuse the empty-charge recast")
	_check(float(activation.applied_total) <= 0.01 and is_equal_approx(_health_total(enemies), baseline),
		"the activation frame must only telegraph; disabled auto-attack cannot supply a false hit")

	var impact_deadline := started_ms + int(ceil((float(timing["impact"]) + GRACE_SECONDS) * 1000.0))
	while float(activation.applied_total) <= 0.01 and Time.get_ticks_msec() < impact_deadline:
		await process_frame
	_check(float(activation.applied_total) > 0.01,
		"the live %s must affect reachable targets by %.2fs" % [weapon_id, timing["impact"]])

	var cleanup_deadline := started_ms + int(ceil((float(timing["lifecycle"]) + GRACE_SECONDS) * 1000.0))
	while controller.is_active() and Time.get_ticks_msec() < cleanup_deadline:
		await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active")) and activation.is_finished(),
		"the live %s must clean up by %.2fs" % [weapon_id, timing["lifecycle"]])
	await _drop(player, enemies)


func _test_cancel_and_new_run_cleanup() -> void:
	var player := await _spawn_player(PRIMARY_WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var enemies := await _spawn_enemies(player, host, PRIMARY_WEAPON_ID)
	var controller = host.controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a shipped rifle cast must start before cancellation")
	var activation = controller.active_activation()
	controller.cancel()
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation != null and activation.is_finished(),
		"cancel must leave no active rifle controller or activation")

	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a shipped rifle cast must start before a new run")
	var new_run_activation = controller.active_activation()
	player.call("configure_character", CLASS_ID, PRIMARY_WEAPON_ID)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and new_run_activation != null and new_run_activation.is_finished(),
		"a new run must cancel the shipped rifle without residual active state")
	await _drop(player, enemies)


func _test_node_end_cleanup() -> void:
	var player := await _spawn_player(PRIMARY_WEAPON_ID)
	var host := PlayerHost.for_player(player)
	var enemies := await _spawn_enemies(player, host, PRIMARY_WEAPON_ID)
	var controller = host.controller()
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "a shipped rifle cast must start before node end")
	var activation = controller.active_activation()
	_holder.remove_child(player)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation != null and activation.is_finished(),
		"node end must cancel the shipped rifle without residual active state")
	player.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func _spawn_player(weapon_id: String) -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.global_position = Vector2(900.0, 700.0)
	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	var weapon := player.get("equipped_weapon") as Node
	if weapon != null:
		weapon.set_process(false)
		weapon.set_physics_process(false)
	return player


func _spawn_enemies(player: Node2D, host: Node, weapon_id: String) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var profile: Dictionary = _registry.catalog_profile_for(CLASS_ID, weapon_id)
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var max_range := float(params.get("max_range", 720.0))
	var aim := host.call("ultimate_host_aim", max_range) as Dictionary
	var aim_point := aim.get("point", player.global_position) as Vector2
	var direction := aim.get("direction", Vector2.ZERO) as Vector2
	_check(direction.length_squared() > 0.001 and aim_point.distance_to(player.global_position) > 0.001,
		"the real Player aim snapshot must be usable for shipped Soldier targeting")
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var side := Vector2(-direction.y, direction.x).normalized()
	var target_center := aim_point
	var positions: Array[Vector2] = []
	if weapon_id == "soldier_grenade":
		var probe := Activation.new(host, {}, 0.0)
		positions.append(target_center)
		for point in probe.pattern_points(target_center, "seeded_annulus", {
			"count": 7, "inner_radius": 90.0, "outer_radius": 260.0, "seed": 1469,
		}):
			positions.append(point)
		probe.shutdown(true)
	elif weapon_id == "soldier_bayonet":
		target_center = player.global_position + direction.normalized() * 50.0
		positions = [target_center, target_center + direction * 130.0, target_center + direction * 260.0]
	else:
		positions = [target_center, target_center + direction * 80.0, target_center + direction * 160.0 + side * 30.0]
	for position in positions:
		var enemy := EnemyScene.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = position
		enemy.add_to_group("enemies")
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await process_frame
	return enemies


func _assert_declared_timing(weapon_id: String) -> void:
	var profile: Dictionary = _registry.catalog_profile_for(CLASS_ID, weapon_id)
	var params := (profile.get("executor", {}) as Dictionary).get("params", {}) as Dictionary
	var timing := WEAPON_TIMINGS[weapon_id] as Dictionary
	var impact_key := "first_impact_delay" if weapon_id == "soldier_grenade" else "rank_interval" \
		if weapon_id == "soldier_bayonet" else "volley_interval"
	_check(is_equal_approx(float(params.get(impact_key, 0.0)), float(timing["impact"])),
		"%s must declare its real first-impact timing" % weapon_id)
	_check(is_equal_approx(float(params.get("lifetime", 0.0)), float(timing["lifecycle"])),
		"%s must declare its real lifecycle timing" % weapon_id)


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
