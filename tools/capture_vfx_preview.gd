extends SceneTree

## Captures in-game screenshots of the attack VFX for visual review.
## Run windowed:  Godot --path . --script res://tools/capture_vfx_preview.gd
## Output: build/vfx_preview/*.png

var _player: Node
var _shots := []


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute("build/vfx_preview")

	var background := Sprite2D.new()
	background.texture = load("res://assets/backgrounds/field_meadow.png")
	background.centered = false
	background.scale = Vector2(2.0, 2.0)
	root.add_child(background)

	_player = (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	root.add_child(_player)
	_player.global_position = Vector2(1280, 720)

	for offset in [Vector2(260, -40), Vector2(300, 60), Vector2(210, 130)]:
		var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Node2D
		root.add_child(enemy)
		enemy.global_position = _player.global_position + offset

	await process_frame
	await _shot_weapon("berserk", "sword", [0.03, 0.08], "sword_slash")
	await _shot_weapon("berserk", "axe", [0.03, 0.08], "axe_slash")
	await _shot_weapon("berserk", "hammer", [0.30, 0.48], "hammer_slam")
	await _shot_weapon("dark_mage", "dark_book", [0.16, 0.42], "void_orb")
	await _shot_weapon("dark_mage", "cursed_skull", [0.12, 0.30], "curse_skull")
	await _shot_weapon("dark_mage", "dark_wand", [0.08], "beam")
	await _shot_weapon("guitarist", "electric_guitar", [0.10], "sound_wave")
	await _shot_weapon("guitarist", "bass_guitar", [0.12], "bass_pulse")
	print("captured: ", ", ".join(_shots))
	quit()


func _shot_weapon(character_id: String, weapon_id: String, delays: Array, label: String) -> void:
	_player.configure_character(character_id, weapon_id)
	_player.global_position = Vector2(1280, 720)
	await process_frame
	var weapon: Node = _player.get("equipped_weapon")
	if weapon == null:
		push_error("no weapon %s" % weapon_id)
		return
	# Заморозить авто-стрельбу, чтобы кадр был предсказуемым.
	weapon.set("fire_interval", 999.0)
	weapon.set("_cooldown", 999.0)
	if weapon.has_method("_attack"):
		weapon.call("_attack")
	var elapsed := 0.0
	var shot_index := 0
	for delay in delays:
		while elapsed < float(delay):
			await process_frame
			elapsed += 1.0 / 60.0
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var path := "build/vfx_preview/%s_%d.png" % [label, shot_index]
		image.save_png(path)
		_shots.append(path)
		shot_index += 1
	# Дать эффектам догореть.
	for _i in range(30):
		await process_frame
