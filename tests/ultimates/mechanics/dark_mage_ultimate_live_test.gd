extends SceneTree

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "dark_mage"
const WEAPONS := ["dark_book", "cursed_skull", "dark_wand"]

var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	_check(registry.package_validation_errors().is_empty(),
		"Dark Mage packages must admit cleanly: %s" % [registry.package_validation_errors()])
	for weapon_id in WEAPONS:
		await _test_live_cast(weapon_id, registry)
	await _test_wand_real_runtime()
	_holder.queue_free()
	await process_frame
	_report()


## Real Player + real Enemy nodes, wall-time natural completion, and the
## encounter-use ledger boundary: refused re-entry in the same encounter, one
## activation reopened by the next encounter.
func _test_wand_real_runtime() -> void:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.global_position = Vector2(600.0, 500.0)
	player.call("configure_character", CLASS_ID, "dark_wand")
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	for child in player.find_children("*", "Node", true, false):
		(child as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var host := PlayerHost.for_player(player)
	var aim := host.call("ultimate_host_aim", 760.0) as Dictionary
	var direction := aim.get("direction", Vector2.ZERO) as Vector2
	_check(direction.length_squared() > 0.001,
		"the real Player aim snapshot must be usable for the rail probe")
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var enemies: Array[Node2D] = []
	for ratio in [0.25, 0.5, 0.75]:
		var enemy := EnemyScene.instantiate() as Node2D
		_holder.add_child(enemy)
		enemy.global_position = player.global_position + direction * 760.0 * float(ratio)
		enemy.add_to_group("enemies")
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await process_frame
	var baseline := 0.0
	for enemy in enemies:
		baseline += float(enemy.get("health"))
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"dark_wand must activate for the real-runtime probe")
	var controller = PlayerHost.for_player(player).controller()
	var activation = controller.active_activation()
	_check(controller.is_active() and activation != null,
		"the real-runtime probe must own a live generic activation")
	var deadline := Time.get_ticks_msec() + int(4.85 * 1000.0)
	while controller.is_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active"))
		and activation != null and activation.is_finished(),
		"dark_wand must complete naturally on the real Player within its 3.85s lifetime")
	var after := 0.0
	for enemy in enemies:
		after += float(enemy.get("health"))
	_check(after < baseline,
		"the joint collapse must remove real Enemy health")
	_check(activation != null and float(activation.applied_total) > 0.0,
		"real-runtime attribution must record the applied damage")
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(not bool(player.call("activate_ultimate")),
		"the encounter-use ledger must refuse re-entry after completion in the same encounter")
	_check(is_equal_approx(float(player.get("ultimate_charge")),
			float(player.get("ultimate_max_charge"))),
		"a refused re-entry must not drain the refilled bar")
	player.call("configure_character", CLASS_ID, "dark_wand")
	await process_frame
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"a new encounter must reopen exactly one activation")
	PlayerHost.for_player(player).controller().cancel()
	player.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await process_frame


func _test_live_cast(weapon_id: String, registry) -> void:
	_check(registry.resolution_source(CLASS_ID, weapon_id) == Resolver.SOURCE_WEAPON_PROFILE,
		"%s must resolve through the exact ready package" % weapon_id)
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	_check(str(player.get("weapon_id")) == weapon_id,
		"the real Player must equip %s before activation" % weapon_id)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"%s must activate through the real Player entry point" % weapon_id)
	var host := PlayerHost.for_player(player)
	var controller = host.controller()
	_check(controller.is_active(), "%s must leave a live generic activation" % weapon_id)
	var activation = controller.active_activation()
	var spawned: Array[Node] = activation.spawned_for_tests() if activation != null else []
	_check(spawned.size() == 1,
		"%s must create one activation-owned runtime effect" % weapon_id)
	_check(is_zero_approx(float(player.get("ultimate_charge"))),
		"%s must spend full charge exactly once" % weapon_id)
	_check(bool(player.get("_ultimate_active")),
		"%s must own Player's active-cast latch" % weapon_id)
	player.call("_gain_ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(is_zero_approx(float(player.get("ultimate_charge"))),
		"%s must reject charge gain while its activation is live" % weapon_id)
	_check(not bool(player.call("activate_ultimate")),
		"%s must refuse active re-entry" % weapon_id)

	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active")),
		"a new run must cancel %s before resetting Player state" % weapon_id)
	for node in spawned:
		_check(not is_instance_valid(node),
			"a new run must clean the activation-owned effect from %s" % weapon_id)
	player.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("dark_mage_ultimate_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_ultimate_live_test: %s" % error)
	print("dark_mage_ultimate_live_test: FAIL (%d)" % _errors.size())
	quit(1)
