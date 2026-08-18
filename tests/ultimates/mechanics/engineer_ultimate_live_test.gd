extends SceneTree

## Live Player/UltimatePlayerHost evidence for the three Engineer packages.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/mechanics/engineer_ultimate_live_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "engineer"
const CASES := [
	{"weapon_id": "engineer_sentry_wrench", "device": "sentry", "count": 6},
	{"weapon_id": "engineer_repair_drone", "device": "microdrone", "count": 12},
	{"weapon_id": "engineer_pressure_mines", "device": "mine", "count": 16},
]

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
		"Engineer packages must admit cleanly: %s" % [registry.package_validation_errors()])
	for spec in CASES:
		await _test_live_cast(spec, registry)
	_holder.queue_free()
	await process_frame
	_report()


func _test_live_cast(spec: Dictionary, registry) -> void:
	var weapon_id := str(spec["weapon_id"])
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
	# FAN-2985: the activation also owns one presentation carrier; the device
	# contract below is about the deploy set only.
	var devices: Array[Node] = []
	for node in spawned:
		if node.has_meta("engineer_ultimate_device"):
			devices.append(node)
	_check(devices.size() == int(spec["count"]),
		"%s must atomically deploy %d temporary devices" % [weapon_id, int(spec["count"])])
	for node in devices:
		_check(node.get_meta("engineer_ultimate_device", "") == spec["device"],
			"%s must preserve its temporary-device identity" % weapon_id)
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
			"a new run must clean every temporary device from %s" % weapon_id)
	player.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("engineer_ultimate_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("engineer_ultimate_live_test: %s" % error)
	print("engineer_ultimate_live_test: FAIL (%d)" % _errors.size())
	quit(1)
