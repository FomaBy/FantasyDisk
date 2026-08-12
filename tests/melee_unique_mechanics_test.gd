extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	await _test_melee_unique_configs(errors)
	await _test_knight_tower_shield_counter_pack(errors)
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
		# SCRUM-900: сустейн пилы = heal_percent_of_damage (weapon-only «Клятва
		# чумного доктора»), легаси melee_heal_percent_on_hit удалён из конфига.
		"doctor/bone_saw": ["melee_close_bonus_radius", "heal_percent_of_damage"],
		# SCRUM-921/922: тройной секвенс-укол копья и масштабируемый конус-баш щита.
		"knight/long_spear": ["melee_execute_threshold", "thrust_count", "thrust_fan_degrees"],
		"knight/tower_shield": ["melee_stagger_knockback_multiplier", "stagger_knockback_stat_ratio"],
		"knight/holy_flail": ["melee_arc_followup_radius", "spiral_steps"],
		# SCRUM-914..918: robot_hydraulic_press больше не melee-identity оружие —
		# кит Робота снёс легаси melee-ключи (4fc0472ac), пресс покрыт robot_kit_test.
	}
	for key in required:
		var parts := str(key).split("/")
		var config: Dictionary = ProgressionData.weapon(str(parts[0]), str(parts[1]))
		for required_key in required[key]:
			if not config.has(required_key) or float(config.get(required_key, 0.0)) <= 0.0:
				errors.append("Expected %s to define positive %s." % [key, required_key])
	var spear_mods: Dictionary = ProgressionData.weapon("knight", "long_spear").get("passive_mods", {})
	var shield_mods: Dictionary = ProgressionData.weapon("knight", "tower_shield").get("passive_mods", {})
	var flail_mods: Dictionary = ProgressionData.weapon("knight", "holy_flail").get("passive_mods", {})
	if float(shield_mods.get("counter_incoming_multiplier", 0.0)) <= float(spear_mods.get("counter_incoming_multiplier", 0.0)):
		errors.append("Expected tower_shield to own the strongest incoming-damage counter fantasy.")
	if float(shield_mods.get("block_reduction", 0.0)) <= float(flail_mods.get("block_reduction", 0.0)):
		errors.append("Expected tower_shield block reduction to exceed holy_flail.")
	if float(flail_mods.get("counter_radius", 0.0)) <= float(spear_mods.get("counter_radius", 0.0)):
		errors.append("Expected holy_flail to keep broader circular counter/control than long_spear.")
	if float(shield_mods.get("counter_arc_degrees", 360.0)) >= float(flail_mods.get("counter_arc_degrees", 0.0)):
		errors.append("Expected tower_shield counter to stay frontal while holy_flail remains circular.")


func _test_knight_tower_shield_counter_pack(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var knight := player_scene.instantiate()
	holder.add_child(knight)
	knight.global_position = Vector2(620, 620)
	await process_frame
	knight.call("configure_character", "knight", "tower_shield")
	var params: Dictionary = knight.get("derived_parameters")
	params["dodge"] = 0.0
	params["raw_dodge"] = 0.0
	params["defense"] = 0.0
	params["raw_defense"] = 0.0
	params["absorb"] = 0.0
	knight.set("derived_parameters", params)
	knight.set("_knight_counter_cooldown_left", 0.0)

	var pack := []
	for offset in [Vector2(72, 0), Vector2(112, 38), Vector2(150, -24)]:
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.global_position = knight.global_position + offset
		enemy.set("max_health", 24.0)
		enemy.set("health", 24.0)
		pack.append(enemy)
	var behind := enemy_scene.instantiate()
	holder.add_child(behind)
	behind.global_position = knight.global_position + Vector2(-92, 0)
	behind.set("max_health", 24.0)
	behind.set("health", 24.0)
	var outside := enemy_scene.instantiate()
	holder.add_child(outside)
	outside.global_position = knight.global_position + Vector2(245, 0)
	outside.set("max_health", 24.0)
	outside.set("health", 24.0)
	await process_frame

	var hp_before := float(knight.get("health"))
	var landed: bool = knight.call("take_damage", 5.0, "tower_counter_test")
	await process_frame
	if not landed:
		errors.append("Expected tower_shield contact hit to land before counter checks.")
	var damage_taken := hp_before - float(knight.get("health"))
	if damage_taken <= 0.0 or damage_taken >= 5.0:
		errors.append("Expected tower_shield block to reduce but not erase a 5-damage hit (taken %.2f)." % damage_taken)
	var killed := 0
	for enemy in pack:
		if _enemy_health(enemy) <= 0.0:
			killed += 1
	if killed < 2:
		errors.append("Expected tower_shield 5-damage block counter to kill part of a 24 HP contact pack, killed %d." % killed)
	if _enemy_health(outside) < 23.9:
		errors.append("Expected tower_shield counter radius not to hit outside enemy (HP %.2f)." % _enemy_health(outside))
	if _enemy_health(behind) < 23.9:
		errors.append("Expected tower_shield counter arc not to hit behind enemy (HP %.2f)." % _enemy_health(behind))
	if float(knight.get("_knight_counter_cooldown_left")) <= 0.0:
		errors.append("Expected tower_shield counter to set a cooldown window.")

	var cooldown_target := enemy_scene.instantiate()
	holder.add_child(cooldown_target)
	cooldown_target.global_position = knight.global_position + Vector2(78, 0)
	cooldown_target.set("max_health", 24.0)
	cooldown_target.set("health", 24.0)
	knight.set("_damage_invulnerability_left", 0.0)
	var second_hp_before := float(knight.get("health"))
	knight.call("take_damage", 5.0, "tower_counter_cooldown_test")
	await process_frame
	if _enemy_health(cooldown_target) < 23.9:
		errors.append("Expected tower_shield counter cooldown to prevent immediate second retaliation.")
	var second_damage_taken := second_hp_before - float(knight.get("health"))
	if second_damage_taken <= damage_taken + 1.0:
		errors.append("Expected cooldown hit to be less protected than block-counter hit (first %.2f, second %.2f)." % [damage_taken, second_damage_taken])
	knight.call("configure_character", "knight", "tower_shield")
	if float(knight.get("_knight_counter_cooldown_left")) != 0.0:
		errors.append("Expected configure_character/equip reset to clear Knight counter cooldown.")
	holder.queue_free()
	await process_frame


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
	player.set("derived_parameters", {"damage": 100.0, "magic_damage": 0.0, "dot_damage": 0.0, "summon_amount": 0.0, "crit_chance": 0.0, "crit_damage_multiplier": 1.0})

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


func _enemy_health(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 0.0
	return float(enemy.get("health"))
