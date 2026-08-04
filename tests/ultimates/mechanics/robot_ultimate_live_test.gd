extends SceneTree

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")

const WEAPONS := ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"]
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
		"Robot packages must admit cleanly: %s" % [registry.package_validation_errors()])
	for weapon_id in WEAPONS:
		await _cast(weapon_id, registry)
	_holder.queue_free()
	await process_frame
	_report()


func _cast(weapon_id: String, registry) -> void:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", "robot", weapon_id)
	player.set_process(false)
	player.set_physics_process(false)
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "%s must activate through Player" % weapon_id)
	var host := PlayerHost.for_player(player)
	_check(host.controller().is_active() and bool(player.get("_ultimate_active")),
		"%s must own the shared active latch" % weapon_id)
	_check(is_zero_approx(float(player.get("ultimate_charge"))), "%s must spend charge once" % weapon_id)
	player.call("_gain_ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(is_zero_approx(float(player.get("ultimate_charge"))), "%s must block active-window charge gain" % weapon_id)
	_check(not bool(player.call("activate_ultimate")), "%s must refuse active re-entry" % weapon_id)
	player.call("configure_character", "robot", weapon_id)
	await process_frame
	_check(not host.controller().is_active() and not bool(player.get("_ultimate_active")),
		"new run must clean the active %s cast" % weapon_id)
	player.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("robot_ultimate_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("robot_ultimate_live_test: %s" % error)
	print("robot_ultimate_live_test: FAIL (%d)" % _errors.size())
	quit(1)
