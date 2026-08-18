extends SceneTree

## FAN-2985: every weapon ultimate must carry its authored presentation into
## the live cast. The budget test preloads authored scenes directly from
## `scenes/vfx/ultimates/…`, so it stays green even when the runtime never
## instances them; this test activates every ultimate through the real Player
## entry point and requires the spawned effect itself to own a `Presentation`
## node. A disconnected bridge — a missing `scripts/ultimates/classes` scene,
## a bridge without the instanced authored scene, or an executor that never
## spawns it — fails here, not in a file-existence check.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##     --script res://tests/ultimates/presentation/weapon_ultimate_presentation_wiring_live_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const PD := preload("res://scripts/progression_data.gd")

const EXPECTED_WEAPON_COUNT := 51


class Prey extends Node2D:
	var health := 100000.0
	var max_health := 100000.0

	func take_damage(_amount: float, _feedback := {}) -> void:
		pass

	func apply_knockback(_impulse: Vector2) -> void:
		pass


var _errors: Array[String] = []
var _holder: Node2D


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	var pairs: Array = []
	for class_id in PD.WEAPONS_BY_CLASS.keys():
		for weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			pairs.append([str(class_id), str(weapon_id)])
	_check(pairs.size() == EXPECTED_WEAPON_COUNT,
		"the canonical catalog must expose %d weapons, got %d" % [EXPECTED_WEAPON_COUNT, pairs.size()])
	var wired := 0
	for pair in pairs:
		if await _weapon_carries_presentation(str(pair[0]), str(pair[1])):
			wired += 1
	print("presentation wiring: %d/%d ultimates carry a live Presentation node" % [wired, pairs.size()])
	_check(wired == pairs.size(),
		"every ultimate must carry its presentation, wired %d of %d" % [wired, pairs.size()])
	_holder.queue_free()
	await process_frame
	_report()


func _weapon_carries_presentation(class_id: String, weapon_id: String) -> bool:
	var label := "%s/%s" % [class_id, weapon_id]
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", class_id, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	var prey_list: Array[Node2D] = []
	for offset in [Vector2(120, 0), Vector2(240, 40), Vector2(360, -40), Vector2(480, 0)]:
		var prey := Prey.new()
		prey.global_position = player.global_position + (offset as Vector2)
		prey.add_to_group("enemies")
		_holder.add_child(prey)
		prey_list.append(prey)
	await process_frame
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")),
		"%s must activate through the real Player entry point" % label)
	var controller = PlayerHost.for_player(player).controller()
	var activation = controller.active_activation() if controller != null else null
	var carriers := 0
	if activation != null:
		for node in activation.spawned_for_tests():
			if node is Node and is_instance_valid(node) and (node as Node).has_node("Presentation"):
				carriers += 1
	var carried: bool = carriers == 1
	_check(carried,
		"%s must spawn exactly one live effect owning a Presentation node, got %d" % [label, carriers])
	player.call("configure_character", class_id, weapon_id)
	await process_frame
	player.queue_free()
	for prey in prey_list:
		prey.queue_free()
	await process_frame
	return carried


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("weapon_ultimate_presentation_wiring_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		printerr("FAIL: %s" % error)
	quit(1)
