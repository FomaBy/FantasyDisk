extends SceneTree

# SCRUM-241: режим прицеливания хранится в настройках, а оружие умеет
# переключаться между ближайшим врагом и направлением на курсор.

const GameSettings := preload("res://scripts/game_settings.gd")
const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

class FakeOwner:
	extends CharacterBody2D

	var aim_mode := "nearest"
	var cursor_direction := Vector2.RIGHT
	var last_direction := Vector2.ZERO
	var weapon_id := "dark_wand"
	var character_id := "dark_mage"
	var derived_parameters := {
		"magic_damage": 12.0,
		"damage": 10.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.5,
	}
	var run_modifiers := {
		"extra_projectile": 0,
		"knockback_multiplier": 1.0,
		"healing_multiplier": 1.0,
	}

	func attack_aim_mode() -> String:
		return aim_mode

	func attack_aim_direction(_default_direction := Vector2.RIGHT, _range_limit := 999999.0) -> Vector2:
		return cursor_direction.normalized()

	func attack_aim_position(range_limit := 999999.0) -> Vector2:
		return global_position + cursor_direction.normalized() * minf(range_limit, 320.0)

	func play_action_animation(_action_id: String, direction := Vector2.ZERO, _phase := "", _duration := 0.0, _metadata := {}) -> void:
		last_direction = direction.normalized()

	func on_weapon_hit(_enemy: Node, _amount: float) -> void:
		pass


func _initialize() -> void:
	var had_original := FileAccess.file_exists(SAVE_PATH)
	var original_bytes := PackedByteArray()
	if had_original:
		var original := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if original != null:
			original_bytes = original.get_buffer(original.get_length())
			original.close()

	var errors: Array = []
	await _run(errors)

	if had_original:
		var restore := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_buffer(original_bytes)
			restore.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	if not errors.is_empty():
		for error in errors:
			push_error("Aim mode test: %s" % error)
		quit(1)
		return
	print("Aim mode settings test passed.")
	quit(0)


func _write_raw(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SECTION, key, values[key])
	config.save(SAVE_PATH)


func _run(errors: Array) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var settings := GameSettings.load_settings()
	if str(settings.get("aim_mode", "")) != "nearest":
		errors.append("default aim_mode должен быть nearest")

	GameSettings.save_settings({"aim_mode": "cursor"})
	settings = GameSettings.load_settings()
	if str(settings.get("aim_mode", "")) != "cursor":
		errors.append("aim_mode=cursor не сохранился")

	_write_raw({"aim_mode": "broken"})
	settings = GameSettings.load_settings()
	if str(settings.get("aim_mode", "")) != "nearest":
		errors.append("битый aim_mode не нормализован в nearest")

	await _assert_weapon_direction_switch(errors)


func _assert_weapon_direction_switch(errors: Array) -> void:
	var weapon_scene := load("res://scenes/DarkWand.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var owner := FakeOwner.new()
	root.add_child(owner)
	owner.global_position = Vector2(220, 220)
	var weapon := weapon_scene.instantiate()
	owner.add_child(weapon)
	if weapon == null:
		errors.append("dark_wand weapon не прикрепился к игроку")
		return
	weapon.set_process(false)

	var enemy := enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.global_position = owner.global_position + Vector2(0, -180)
	enemy.add_to_group("enemies")
	enemy.set_physics_process(false)
	await process_frame

	owner.aim_mode = "nearest"
	weapon.call("_attack")
	var nearest_direction: Vector2 = owner.last_direction
	if nearest_direction.dot(Vector2.UP) < 0.82:
		errors.append("nearest mode должен целиться в ближайшего врага сверху, direction=%s" % nearest_direction)

	owner.aim_mode = "cursor"
	owner.cursor_direction = Vector2.RIGHT
	await process_frame
	weapon.call("_attack")
	var cursor_direction: Vector2 = owner.last_direction
	if cursor_direction.dot(Vector2.RIGHT) < 0.82:
		errors.append("cursor mode должен целиться по курсору вправо, direction=%s" % cursor_direction)
