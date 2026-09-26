extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса ranger.
# Домен владения: class/ranger (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_ranger_identity_modes()
	await _check_ranger_identity()
	_finish("[balance/ranger] PASSED")


func _check_ranger_identity_modes() -> void:
	if float(ProgressionData.weapon("ranger", "moon_crossbow").get("charge_seconds", 0.0)) <= 0.0:
		_fail("Expected Ranger moon crossbow to expose stance charge seconds.")
		return


func _check_ranger_identity() -> void:
	var holder := Node2D.new()
	holder.name = "RangerIdentityScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var ranger := player_scene.instantiate()
	holder.add_child(ranger)
	ranger.global_position = Vector2(700, 700)
	await process_frame
	ranger.call("configure_character", "ranger", "moon_crossbow")
	var ranger_weapon: Node = ranger.get("equipped_weapon")
	ranger_weapon.set_process(false)
	var ranger_params: Dictionary = ranger.get("derived_parameters")
	ranger_params["crit_chance"] = 0.0
	ranger.set("derived_parameters", ranger_params)
	var ranger_enemy := enemy_scene.instantiate()
	holder.add_child(ranger_enemy)
	ranger_enemy.set("max_health", 100000.0)
	ranger_enemy.set("health", 100000.0)
	ranger_enemy.global_position = ranger.global_position + Vector2(140, 0)
	await process_frame
	var partial_damage := 0.0
	var full_charge_damage := 0.0
	for cast_index in range(12):
		var health_before := float(ranger_enemy.get("health"))
		ranger_weapon.call("_process", float(ranger_weapon.get("fire_interval")))
		var dealt := health_before - float(ranger_enemy.get("health"))
		if float(ranger_weapon.get("_charge_time")) > 0.001 and partial_damage <= 0.0:
			partial_damage = dealt
		elif float(ranger_weapon.get("_charge_time")) <= 0.001 and partial_damage > 0.0:
			full_charge_damage = dealt
			break
	if full_charge_damage <= partial_damage * 1.2:
		_fail("Expected Ranger production auto-fire to preserve partial stance charge through one stronger full release.")
		return
	ranger_weapon.call("_process", float(ranger_weapon.get("fire_interval")))
	if float(ranger_weapon.get("_charge_time")) <= 0.001:
		_fail("Expected Ranger full release to restart, not retain, the stance cycle.")
		return
	ranger_enemy.remove_from_group("enemies")
	holder.queue_free()
	current_scene = null
	await process_frame
