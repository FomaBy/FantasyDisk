extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	await _test_melee_unique_configs(errors)
	await _test_class_weapon_close_and_execute(errors)
	await _test_berserk_weapon_followup(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Melee unique mechanics: %s" % error)
		push_error("Melee unique mechanics test failed: %d errors." % errors.size())
		quit(1)
		return
	print("Melee unique mechanics test passed.")
	quit(0)


func _test_melee_unique_configs(errors: Array) -> void:
	var required := {
		"berserk/sword": ["melee_execute_threshold"],
		"berserk/axe": ["melee_arc_followup_radius"],
		"berserk/hammer": ["melee_stagger_knockback_multiplier"],
		"soldier/soldier_bayonet": ["melee_close_bonus_radius", "melee_stagger_knockback_multiplier"],
		"assassin/shadow_daggers": ["melee_close_bonus_radius", "melee_execute_threshold"],
		"doctor/bone_saw": ["melee_close_bonus_radius", "melee_heal_percent_on_hit"],
		"knight/long_spear": ["melee_execute_threshold"],
		"knight/tower_shield": ["melee_stagger_knockback_multiplier"],
		"knight/holy_flail": ["melee_arc_followup_radius"],
		"robot/robot_hydraulic_press": ["melee_close_bonus_radius", "melee_stagger_knockback_multiplier"],
	}
	for key in required:
		var parts := str(key).split("/")
		var config: Dictionary = ProgressionData.weapon(str(parts[0]), str(parts[1]))
		for required_key in required[key]:
			if not config.has(required_key) or float(config.get(required_key, 0.0)) <= 0.0:
				errors.append("Expected %s to define positive %s." % [key, required_key])


func _test_class_weapon_close_and_execute(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var player := player_scene.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(600, 600)
	await process_frame
	player.call("configure_character", "assassin", "shadow_daggers")
	var weapon := _first_weapon(player)
	if weapon == null:
		errors.append("Expected assassin shadow daggers weapon to attach.")
		holder.queue_free()
		await process_frame
		return
	weapon.set("melee_close_bonus_radius", 140.0)
	weapon.set("melee_close_damage_multiplier", 1.50)
	weapon.set("melee_execute_threshold", 0.35)
	weapon.set("melee_execute_multiplier", 1.40)
	weapon.set("melee_arc_followup_radius", 0.0)
	weapon.set("melee_stagger_knockback_multiplier", 0.0)
	player.set("derived_parameters", {"damage": 100.0, "magic_damage": 0.0, "dot_damage": 0.0, "summon_amount": 0.0, "sound_wave_damage": 0.0, "crit_chance": 0.0, "crit_damage_multiplier": 1.0})

	var far_enemy := enemy_scene.instantiate()
	holder.add_child(far_enemy)
	far_enemy.global_position = player.global_position + Vector2(260, 0)
	far_enemy.set("max_health", 1000.0)
	far_enemy.set("health", 1000.0)
	weapon.call("_damage_enemy", far_enemy, 100.0)
	var far_loss := 1000.0 - float(far_enemy.get("health"))

	var near_enemy := enemy_scene.instantiate()
	holder.add_child(near_enemy)
	near_enemy.global_position = player.global_position + Vector2(60, 0)
	near_enemy.set("max_health", 1000.0)
	near_enemy.set("health", 1000.0)
	weapon.call("_damage_enemy", near_enemy, 100.0)
	var near_loss := 1000.0 - float(near_enemy.get("health"))
	if near_loss <= far_loss + 35.0:
		errors.append("Expected close melee hit to deal extra damage (near %.1f, far %.1f)." % [near_loss, far_loss])

	var execute_enemy := enemy_scene.instantiate()
	holder.add_child(execute_enemy)
	execute_enemy.global_position = player.global_position + Vector2(60, 0)
	execute_enemy.set("max_health", 1000.0)
	execute_enemy.set("health", 300.0)
	weapon.call("_damage_enemy", execute_enemy, 50.0)
	if float(execute_enemy.get("health")) >= 225.0:
		errors.append("Expected execute melee hit to add finishing damage.")

	holder.queue_free()
	await process_frame


func _test_berserk_weapon_followup(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var player := player_scene.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(600, 600)
	await process_frame
	player.call("configure_character", "berserk", "axe")
	var weapon := _first_weapon(player)
	if weapon == null:
		errors.append("Expected berserk axe weapon to attach.")
		holder.queue_free()
		await process_frame
		return
	weapon.set("melee_arc_followup_radius", 180.0)
	weapon.set("melee_arc_followup_multiplier", 0.50)
	var primary := enemy_scene.instantiate()
	var secondary := enemy_scene.instantiate()
	holder.add_child(primary)
	holder.add_child(secondary)
	primary.global_position = player.global_position + Vector2(90, 0)
	secondary.global_position = primary.global_position + Vector2(80, 0)
	for enemy in [primary, secondary]:
		enemy.set("max_health", 1000.0)
		enemy.set("health", 1000.0)
	# Враги должны попасть в группу `enemies` до любого _process-запроса покадрового
	# кэша CombatTargetQuery, иначе arc-cleave не увидит secondary (флака SCRUM-272,
	# тот же класс, что фикс SCRUM-228).
	await process_frame
	weapon.call("_apply_unique_melee_hit_effects", player, primary, Vector2.RIGHT, 100.0)
	if float(secondary.get("health")) >= 960.0:
		errors.append("Expected berserk melee arc follow-up to damage a nearby secondary target.")
	holder.queue_free()
	await process_frame


func _first_weapon(player: Node) -> Node:
	for child in player.find_children("*", "Node", true, false):
		if child.is_in_group("player_weapons"):
			return child
	return null
