extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса knight.
# Домен владения: class/knight (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_knight_identity_modes()
	await _check_knight_identity()
	_finish("[balance/knight] PASSED")


func _check_knight_identity_modes() -> void:
	if float(ProgressionData.weapon("knight", "long_spear").get("passive_mods", {}).get("block_reduction", 0.0)) <= 0.0:
		_fail("Expected Knight weapons to carry block/counter passive data.")
		return


func _check_knight_identity() -> void:
	var holder := Node2D.new()
	holder.name = "KnightIdentityScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var knight := player_scene.instantiate()
	holder.add_child(knight)
	knight.global_position = Vector2(1300, 700)
	await process_frame
	knight.call("configure_character", "knight", "tower_shield")
	var knight_weapon: Node = knight.get("equipped_weapon")
	knight_weapon.set_process(false)
	var knight_parameters: Dictionary = knight.get("derived_parameters")
	knight_parameters["dodge"] = 0.0
	knight_parameters["raw_dodge"] = 0.0
	knight_parameters["defense"] = 0.0
	knight_parameters["raw_defense"] = 0.0
	knight_parameters["absorb"] = 0.0
	if not _assert_raw_pair(knight_parameters, "dodge", "raw_dodge") or not _assert_raw_pair(knight_parameters, "defense", "raw_defense"):
		return
	knight.set("derived_parameters", knight_parameters)
	var knight_enemy := enemy_scene.instantiate()
	holder.add_child(knight_enemy)
	knight_enemy.set("max_health", 100000.0)
	knight_enemy.set("health", 100000.0)
	knight_enemy.global_position = knight.global_position + Vector2(80, 0)
	await process_frame
	knight.set("_knight_counter_cooldown_left", 0.0)
	var knight_hp_before := float(knight.get("health"))
	var knight_enemy_hp_before := float(knight_enemy.get("health"))
	knight.call("take_damage", 20.0, "test_counter")
	await process_frame
	var knight_damage_taken := knight_hp_before - float(knight.get("health"))
	if knight_damage_taken >= 20.0 or float(knight_enemy.get("health")) >= knight_enemy_hp_before:
		_fail("Expected Knight tower shield block to reduce damage and counter frontal enemies.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
