extends SceneTree

## FAN-2363: the Player host must pass its presentation intent to the real
## runtime constructor. A forced non-headless run observes the VFX scene,
## rather than accepting the headless no-op timeline.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/ultimate_player_host_presentation_constructor_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PresentationRuntime := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_runtime.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const CLASS_ID := "soldier"
const WEAPON_ID := "soldier_rifle"

var _errors: Array[String] = []
var _holder: Node2D = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	await _test_production_constructor_uses_non_headless_intent()
	_holder.queue_free()
	await process_frame
	_report()


func _test_production_constructor_uses_non_headless_intent() -> void:
	var player := await _spawn_player()
	var host := PlayerHost.for_player(player)
	var registry := Registry.new(PD.WEAPONS_BY_CLASS)
	var profile: Dictionary = registry.catalog_profile_for(CLASS_ID, WEAPON_ID)
	host.set("_runtime_registry", registry)
	host.set("_presentation_headless_mode", 0)

	_check(host.ultimate_host_begin_presentation(profile),
		"the production constructor must accept a valid non-headless presentation")
	var presentation := host.get("_presentation") as PresentationRuntime
	var scene := presentation.get("_scene") as Node if presentation != null else null
	var expected_parent := player.call("_vfx_parent") as Node
	_check(scene != null and scene.get_parent() == expected_parent,
		"the production constructor must parent the real VFX scene, not accept a headless no-op")

	host.ultimate_host_finish_presentation("test")
	player.queue_free()
	await process_frame


func _spawn_player() -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", CLASS_ID, WEAPON_ID)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("ultimate_player_host_presentation_constructor_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ultimate_player_host_presentation_constructor_test: %s" % error)
	quit(1)
