extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")

# Shared failure lifecycle for executable runtime-smoke scenarios. Godot defers
# quit(), so a later success exit must not overwrite an earlier failing exit.
var _failure_reported := false


func _fail(message: String, evidence_path := "") -> void:
	# Set the sticky state before diagnostics or evidence writes: reporting a
	# failure must not depend on either operation succeeding.
	_failure_reported = true
	push_error(message)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa")
	if not DirAccess.dir_exists_absolute(qa_dir):
		DirAccess.make_dir_recursive_absolute(qa_dir)
	var crumb := FileAccess.open("%s/runtime_smoke_last_failure.md" % qa_dir, FileAccess.WRITE)
	if crumb != null:
		crumb.store_string("# Runtime smoke — последний провал\n\n- Проверка/система: %s\n- Evidence: %s\n" % [
			message, evidence_path if evidence_path != "" else "(см. контекст push_error в логе выше)"])
		crumb.close()
	quit(1)


func _finish(passed_message: String) -> void:
	if _failure_reported:
		quit(1)
		return
	print(passed_message)
	quit()


func _find_player_weapon(player: Node) -> Node:
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket")
	if socket != null:
		for child in socket.get_children():
			if child.is_in_group("player_weapons"):
				return child
	for child in player.get_children():
		if child.is_in_group("player_weapons"):
			return child
	return null


func _node_sprite_texture_path(node: Node, sprite_name: String) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var sprite := node as Sprite2D
	if sprite == null:
		if sprite_name.is_empty():
			var sprites := node.find_children("*", "Sprite2D", true, false)
			if not sprites.is_empty():
				sprite = sprites[0] as Sprite2D
		else:
			sprite = node.find_child(sprite_name, true, false) as Sprite2D
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path
