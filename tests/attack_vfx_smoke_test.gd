extends SceneTree

## Smoke test: every AttackVfx helper spawns without errors and the player
## weapons fire through the new textured effects pipeline.

const AttackVfxScript := preload("res://scripts/attack_vfx.gd")


func _initialize() -> void:
	await process_frame
	_test_vfx_helpers()
	await _test_weapon_fire_paths()
	print("Attack VFX smoke test passed.")
	quit()


func _test_vfx_helpers() -> void:
	var host := Node2D.new()
	root.add_child(host)

	var color := Color(0.6, 0.4, 1.0, 0.4)
	var nodes := [
		AttackVfxScript.slash(host, Vector2.RIGHT, 240.0, color),
		AttackVfxScript.hammer_slam(host, Vector2(100, 100), 200.0, color),
		AttackVfxScript.orb_projectile(host, Vector2(50, 50), color),
		AttackVfxScript.orb_burst(host, Vector2(80, 80), 160.0, color),
		AttackVfxScript.beam(host, Vector2.ZERO, Vector2(300, 0), 50.0, color),
		AttackVfxScript.sound_wave_blast(host, Vector2.ZERO, Vector2.RIGHT, 300.0, color),
		AttackVfxScript.ring_pulse(host, Vector2(10, 10), 180.0, color, true),
		AttackVfxScript.curse_skull(host, Vector2.ZERO, Vector2(120, 0), color, 0.2, Callable()),
		AttackVfxScript.weapon_signature(host, Vector2(42, 42), "sword", 140.0, color, 0.0),
	]
	for node in nodes:
		if node == null or not is_instance_valid(node):
			push_error("Expected AttackVfx helper to return a live node.")
			quit(1)
	var slash_node := nodes[0] as Node2D
	var found_sprite := false
	for child in slash_node.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			found_sprite = true
	if not found_sprite:
		push_error("Expected slash VFX to use textured sprites.")
		quit(1)
	if _max_additive_alpha(slash_node) > 0.69:
		push_error("Expected slash VFX additive alpha to stay below the SCRUM-457 calmness cap.")
		quit(1)
	var beam_node := nodes[4] as Node2D
	var beam_sprite := _first_textured_sprite(beam_node, "beam_strip.png")
	if beam_sprite == null or beam_sprite.scale.y > 0.92:
		push_error("Expected beam VFX to use the narrower SCRUM-457 visual width.")
		quit(1)
	var sound_wave_node := nodes[5] as Node2D
	if _count_textured_sprites(sound_wave_node, "music_note.png") > 1:
		push_error("Expected sound wave VFX to limit note clutter.")
		quit(1)
	var ring_node := nodes[6] as Node2D
	if _count_textured_sprites(ring_node, "music_note.png") > 2:
		push_error("Expected ring pulse VFX to limit note clutter.")
		quit(1)
	_write_scrum457_dump(slash_node, beam_sprite, sound_wave_node, ring_node)
	host.queue_free()


func _test_weapon_fire_paths() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as Node2D
	root.add_child(enemy)
	await process_frame
	enemy.global_position = Vector2(900, 760)

	var weapon_sets := {
		"berserk": ["sword", "axe", "hammer"],
		"knight": ["long_spear", "tower_shield", "holy_flail"],
		"dark_mage": ["dark_book", "cursed_skull", "dark_wand"],
		"guitarist": ["electric_guitar", "bass_guitar", "sound_amp"],
	}
	for character_id in weapon_sets.keys():
		for weapon_id in weapon_sets[character_id]:
			player.configure_character(character_id, weapon_id)
			player.global_position = Vector2(800, 760)
			var weapon: Node = player.get("equipped_weapon")
			if weapon == null:
				push_error("Expected %s/%s to equip a weapon." % [character_id, weapon_id])
				quit(1)
			if weapon.has_method("_attack"):
				weapon.call("_attack")
			if not _has_vfx_node("WeaponSignatureVfx_%s" % weapon_id):
				push_error("Expected %s/%s to spawn dedicated weapon signature VFX." % [character_id, weapon_id])
				quit(1)
	player.queue_free()
	enemy.queue_free()


func _has_vfx_node(node_name: String) -> bool:
	for child in root.get_children():
		if child.name == node_name:
			return true
	return false


func _max_additive_alpha(node: Node) -> float:
	var max_alpha := 0.0
	for child in node.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			var material := sprite.material as CanvasItemMaterial
			if material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD:
				max_alpha = maxf(max_alpha, sprite.modulate.a)
		max_alpha = maxf(max_alpha, _max_additive_alpha(child))
	return max_alpha


func _first_textured_sprite(node: Node, texture_suffix: String) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture != null and sprite.texture.resource_path.ends_with(texture_suffix):
				return sprite
		var nested := _first_textured_sprite(child, texture_suffix)
		if nested != null:
			return nested
	return null


func _count_textured_sprites(node: Node, texture_suffix: String) -> int:
	var count := 0
	for child in node.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture != null and sprite.texture.resource_path.ends_with(texture_suffix):
				count += 1
		count += _count_textured_sprites(child, texture_suffix)
	return count


func _write_scrum457_dump(slash_node: Node2D, beam_sprite: Sprite2D, sound_wave_node: Node2D, ring_node: Node2D) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum457")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray()
	lines.append("# SCRUM-457 Attack VFX Calmness Dump")
	lines.append("")
	lines.append("- `SlashMaxAdditiveAlpha`: `%.3f`" % _max_additive_alpha(slash_node))
	lines.append("- `BeamVisualScaleY`: `%.3f`" % (beam_sprite.scale.y if beam_sprite != null else 0.0))
	lines.append("- `SoundWaveNoteSprites`: `%d`" % _count_textured_sprites(sound_wave_node, "music_note.png"))
	lines.append("- `RingPulseNoteSprites`: `%d`" % _count_textured_sprites(ring_node, "music_note.png"))
	lines.append("- `Policy`: additive VFX color is desaturated/dimmed globally in `AttackVfx._calmed_color`; damage radii and hit queries are unchanged.")
	var file := FileAccess.open("%s/attack_vfx_calmness_dump.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
