extends SceneTree

## Real Player entry-point coverage for the Guitarist's three exact packages.

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

const CLASS_ID := "guitarist"
const CASES := [
	{"weapon_id": "electric_guitar", "primitive_key": "guitarist_last_chord"},
	{"weapon_id": "bass_guitar", "primitive_key": "guitarist_hell_subwoofer"},
	{"weapon_id": "sound_amp", "primitive_key": "guitarist_wall_of_sound"},
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
		"Guitarist packages must admit cleanly: %s" % [registry.package_validation_errors()])
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
	_check(bool(player.call("activate_ultimate")), "%s must activate through Player" % weapon_id)
	var controller = PlayerHost.for_player(player).controller()
	var activation = controller.active_activation()
	_check(controller.is_active() and activation != null,
		"%s must leave one live generic activation" % weapon_id)
	_check(activation.primitive_value(str(spec["primitive_key"])) != null,
		"%s must install its own primitive state before the first scheduled beat" % weapon_id)
	_check(is_zero_approx(float(player.get("ultimate_charge"))),
		"%s must spend full charge exactly once" % weapon_id)
	_check(bool(player.get("_ultimate_active")), "%s must own Player's active-cast latch" % weapon_id)
	player.call("_gain_ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(is_zero_approx(float(player.get("ultimate_charge"))),
		"%s must not gain charge while active" % weapon_id)
	_check(not bool(player.call("activate_ultimate")), "%s must refuse active re-entry" % weapon_id)

	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	_check(not controller.is_active() and not bool(player.get("_ultimate_active")),
		"a new run must cancel %s and clear Player's active latch" % weapon_id)
	player.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("guitarist_ultimate_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("guitarist_ultimate_live_test: %s" % error)
	print("guitarist_ultimate_live_test: FAIL (%d)" % _errors.size())
	quit(1)
