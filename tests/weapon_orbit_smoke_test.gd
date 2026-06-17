extends SceneTree

# SCRUM-455: Back-end smoke for held weapon orbit/visibility.
# Run: Godot --headless --path . --script res://tests/weapon_orbit_smoke_test.gd


func _initialize() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		_fail("Player scene did not load.")
		return

	var player := player_scene.instantiate()
	root.add_child(player)
	player.call("configure_character", "berserk", "sword")
	await process_frame

	var weapon := _find_player_weapon(player)
	if weapon == null:
		_fail("Expected Berserk sword to equip a weapon node.")
		return
	if weapon.get_parent() == null or weapon.get_parent().name != "WeaponSocket":
		_fail("Expected weapon to remain directly attached to WeaponSocket.")
		return
	if not _assert_weapon_orbit_pose(player, Vector2.RIGHT, "right attack"):
		return
	weapon.set("_last_direction", Vector2.UP)
	if not _assert_weapon_orbit_pose(player, Vector2.UP, "upward attack"):
		return

	_write_qa_dump(player, weapon)
	print("Weapon orbit smoke test passed.")
	quit(0)


func _assert_weapon_orbit_pose(player: Node, expected_direction: Vector2, label: String) -> bool:
	player.call("play_action_animation", "attack", expected_direction)
	player.call("_apply_sprite_transform")
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	if socket == null:
		_fail("Expected %s pose to keep a WeaponSocket." % label)
		return false
	var body := player.get_node_or_null("VisualRoot/Body") as CanvasItem
	if body == null:
		_fail("Expected %s pose to keep a Body for layer checks." % label)
		return false
	var socket_distance := socket.position.length()
	if socket_distance < 88.0:
		_fail("Expected %s pose weapon socket to orbit outside the hero body, got distance %.1f." % [label, socket_distance])
		return false
	var weapon := _find_player_weapon(player)
	var weapon_canvas := weapon as CanvasItem
	var weapon_visual: CanvasItem = null
	if weapon != null:
		weapon_visual = weapon.get_node_or_null("WeaponVisual") as CanvasItem
	if socket.z_index >= body.z_index:
		_fail("Expected %s pose socket z-index to stay behind Body." % label)
		return false
	if weapon_canvas != null and socket.z_index + weapon_canvas.z_index >= body.z_index:
		_fail("Expected %s pose weapon root effective z to stay behind Body." % label)
		return false
	if weapon_canvas != null and weapon_visual != null and socket.z_index + weapon_canvas.z_index + weapon_visual.z_index >= body.z_index:
		_fail("Expected %s pose WeaponVisual effective z to stay behind Body." % label)
		return false
	var actual_direction := socket.position.normalized()
	var expected := expected_direction.normalized()
	if actual_direction.dot(expected) < 0.82:
		_fail("Expected %s pose socket to follow %s, got %s." % [label, str(expected), str(actual_direction)])
		return false
	return true


func _find_player_weapon(player: Node) -> Node:
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket")
	if socket != null:
		for child in socket.get_children():
			if child.is_in_group("player_weapons"):
				return child
	return null


func _write_qa_dump(player: Node, weapon: Node) -> void:
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	var body := player.get_node_or_null("VisualRoot/Body") as CanvasItem
	var visual: CanvasItem = null
	if weapon != null:
		visual = weapon.get_node_or_null("WeaponVisual") as CanvasItem
	var weapon_canvas := weapon as CanvasItem
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum455")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray()
	lines.append("# SCRUM-455 Weapon Orbit Runtime Dump")
	lines.append("")
	lines.append("- `Character`: `%s`" % str(player.get("character_id")))
	lines.append("- `Weapon`: `%s`" % str(weapon.name if weapon != null else ""))
	lines.append("- `WeaponParent`: `%s`" % str(weapon.get_parent().name if weapon != null and weapon.get_parent() != null else ""))
	lines.append("- `SocketPosition`: `%s`" % str(socket.position if socket != null else Vector2.ZERO))
	lines.append("- `SocketDistance`: `%.2f`" % (socket.position.length() if socket != null else 0.0))
	lines.append("- `SocketZIndex`: `%d`" % (socket.z_index if socket != null else 0))
	lines.append("- `WeaponRootZIndex`: `%d`" % (weapon_canvas.z_index if weapon_canvas != null else 0))
	lines.append("- `WeaponVisualZIndex`: `%d`" % (visual.z_index if visual != null else 0))
	lines.append("- `BodyZIndex`: `%d`" % (body.z_index if body != null else 0))
	lines.append("- `OrbitRadiusMeta`: `%.2f`" % (float(socket.get_meta("weapon_orbit_radius", 0.0)) if socket != null else 0.0))
	var file := FileAccess.open("%s/weapon_orbit_runtime_dump.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
