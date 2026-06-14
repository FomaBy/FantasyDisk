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
	player.queue_free()
	enemy.queue_free()
