extends SceneTree

## FAN-2985: an executor beat belongs to the weapon's own authored presentation.
## While that presentation is live the host must draw no generic primitive over
## it and must deliver the beat's `event_id` to it. The primitive path survives
## only as the explicit fallback for a profile without an authored presentation,
## it honours the flash budget the weapon manifest declares, and it never turns
## a shape it cannot draw into a silent ring pulse.
##
## Every class/weapon pair runs through the real Player with the presentation
## runtime forced non-headless, so the authored scene is really instanced.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/presentation/ultimate_beat_routing_live_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")

const EXPECTED_WEAPON_COUNT := 51
const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"
## The three shapes the primitive fallback can actually draw.
const SUPPORTED_SHAPES: Array[String] = ["ring_pulse", "orb_burst", "beam"]
## Shapes the class packages ask for that the fallback has no drawing for.
const UNSUPPORTED_SHAPES: Array[String] = [
	"axe_detonation", "axe_pass", "axe_turn", "chain_net", "corridor_beat",
	"cross_slash", "jaw_ring", "moon_mark", "quake_ring", "rift_lanes",
]

var _errors: Array[String] = []
var _holder: Node2D = null
var _registry = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	await process_frame
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	var pairs := _catalog_pairs()
	_check(pairs.size() == EXPECTED_WEAPON_COUNT,
		"the canonical catalog must expose %d weapons, got %d" % [EXPECTED_WEAPON_COUNT, pairs.size()])
	var player := await _spawn_player(str(pairs[0][0]), str(pairs[0][1]))
	for pair in pairs:
		await _check_pair(player, str(pair[0]), str(pair[1]))
	player.queue_free()
	_holder.queue_free()
	await process_frame
	_report()


func _check_pair(player: Node2D, class_id: String, weapon_id: String) -> void:
	var label := "%s/%s" % [class_id, weapon_id]
	player.call("configure_character", class_id, weapon_id)
	await process_frame
	var host := PlayerHost.for_player(player)
	host.set("_presentation_headless_mode", 0)
	var profile: Dictionary = _registry.catalog_profile_for(class_id, weapon_id)
	if not _check(bool(host.call("ultimate_host_begin_presentation", profile)),
			"%s must begin its authored presentation" % label):
		return
	var parent := player.call("_vfx_parent") as Node
	var before := parent.get_child_count()
	var beats := PackedStringArray()
	for shape in SUPPORTED_SHAPES + UNSUPPORTED_SHAPES:
		var event_id := "fan2985.live.%s.%s" % [weapon_id, shape]
		var node = host.call("ultimate_host_present", event_id, _payload(player, shape))
		_check(node == null,
			"%s must draw no controller primitive over its live presentation (shape %s)" % [label, shape])
		beats.append(event_id)
	_check(parent.get_child_count() == before,
		"%s must add no controller VFX node while its presentation is live" % label)
	var delivered := _delivered_event_ids(host)
	for event_id in beats:
		_check(event_id in delivered,
			"%s must deliver beat '%s' to its live presentation" % [label, event_id])
	host.call("ultimate_host_finish_presentation", "test")
	_check_fallback(player, host, class_id, weapon_id)


## Without a live authored presentation the primitive is the declared fallback,
## but a weapon that banned flashes in its manifest still gets none.
func _check_fallback(player: Node2D, host: Node, class_id: String, weapon_id: String) -> void:
	var label := "%s/%s" % [class_id, weapon_id]
	var flash_forbidden := _manifest_forbids_flash(class_id, weapon_id)
	for shape in SUPPORTED_SHAPES:
		var node = host.call("ultimate_host_present", "fan2985.fallback.%s" % shape, _payload(player, shape))
		if flash_forbidden:
			_check(node == null,
				"%s declares a zero flash budget, so shape %s must draw no controller flash" % [label, shape])
		else:
			_check(node != null,
				"%s must keep the explicit primitive fallback for shape %s" % [label, shape])
		_release(node)
	for shape in UNSUPPORTED_SHAPES:
		var node = host.call("ultimate_host_present", "fan2985.fallback.%s" % shape, _payload(player, shape))
		_check(node == null,
			"%s must not turn unsupported shape '%s' into a silent ring pulse" % [label, shape])
		_release(node)


func _payload(player: Node2D, shape: String) -> Dictionary:
	return {
		"position": player.global_position,
		"radius": 200.0,
		"shape": shape,
		"from": player.global_position,
		"to": player.global_position + Vector2(200.0, 0.0),
	}


func _delivered_event_ids(host: Node) -> PackedStringArray:
	var ids := PackedStringArray()
	var runtime = host.get("_presentation")
	if runtime == null:
		return ids
	for raw_beat in runtime.call("beats"):
		ids.append(str((raw_beat as Dictionary).get("event_id", "")))
	return ids


## Read straight from the manifest document, not through the runtime helper the
## host uses, so the budget evidence stays independent of the implementation.
func _manifest_forbids_flash(class_id: String, weapon_id: String) -> bool:
	var path := "%s/%s/manifest.json" % [MANIFEST_ROOT, class_id]
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	for raw_weapon in (parsed as Dictionary).get("weapons", []):
		if not raw_weapon is Dictionary or str((raw_weapon as Dictionary).get("weapon_id", "")) != weapon_id:
			continue
		var quality = (raw_weapon as Dictionary).get("quality", {})
		if not quality is Dictionary:
			return false
		return is_zero_approx(float((quality as Dictionary).get("full_screen_flash_hz", 1.0))) \
			and is_zero_approx(float((quality as Dictionary).get("max_flash_coverage_ratio", 1.0)))
	return false


func _catalog_pairs() -> Array:
	var pairs: Array = []
	for class_id in PD.WEAPONS_BY_CLASS.keys():
		for weapon_id in (PD.WEAPONS_BY_CLASS[class_id] as Dictionary).keys():
			pairs.append([str(class_id), str(weapon_id)])
	return pairs


func _spawn_player(class_id: String, weapon_id: String) -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", class_id, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _release(node) -> void:
	if node is Node and is_instance_valid(node):
		(node as Node).queue_free()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_errors.append(message)
	return condition


func _report() -> void:
	if _errors.is_empty():
		print("ultimate_beat_routing_live_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("ultimate_beat_routing_live_test: %s" % error)
	printerr("ultimate_beat_routing_live_test: FAIL (%d)" % _errors.size())
	quit(1)
