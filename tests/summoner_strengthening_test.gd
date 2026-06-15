extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")


class TestEnemy:
	extends Node2D

	var health := 30.0
	var max_health := 30.0
	var damage_taken := 0.0
	var knockback_taken := Vector2.ZERO

	func take_damage(amount: float) -> void:
		damage_taken += maxf(amount, 0.0)
		health -= maxf(amount, 0.0)

	func apply_knockback(vector: Vector2) -> void:
		knockback_taken += vector


func _initialize() -> void:
	var errors: Array = []
	await _test_summon_configs(errors)
	await _test_summon_profile_scales_with_leadership(errors)
	await _test_ally_minion_profile_and_lifecycle(errors)
	await _test_summon_group_target_distribution(errors)
	await _test_ally_attack_splash(errors)

	if not errors.is_empty():
		for error in errors:
			push_error("Summoner strengthening: %s" % error)
		push_error("Summoner strengthening test failed: %d errors." % errors.size())
		quit(1)
		return
	print("Summoner strengthening test passed.")
	quit(0)


func _test_summon_configs(errors: Array) -> void:
	var expected := {
		"druid/summon_amulet": "pack_damage",
		"druid/raven_totem": "support_totem",
		"chemist/homunculus_vial": "tank_control",
		"engineer/engineer_sentry_wrench": "engineer_sentry",
		"engineer/engineer_repair_drone": "support_drone",
	}
	for key in expected:
		var parts := str(key).split("/")
		var config: Dictionary = ProgressionData.weapon(str(parts[0]), str(parts[1]))
		if str(config.get("summon_role", "")) != str(expected[key]):
			errors.append("Expected %s summon_role=%s, got %s." % [key, expected[key], config.get("summon_role", "")])
		if ProgressionData.weapon_archetype(config) != "summon":
			errors.append("Expected %s to be counted as summon archetype." % key)
		if float(config.get("summon_role_damage_multiplier", 0.0)) <= 0.0:
			errors.append("Expected %s to define summon_role_damage_multiplier." % key)


func _test_summon_profile_scales_with_leadership(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(640, 480)
	await process_frame
	player.call("configure_character", "druid", "summon_amulet")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		errors.append("Expected Druid summon amulet to attach.")
		holder.queue_free()
		await process_frame
		return
	weapon.set_process(false)

	var stats: Dictionary = player.get("stats")
	stats["leadership"] = 2.0
	player.set("stats", stats)
	player.call("_apply_stat_scaling", false, player.get("max_health"))
	var low_profile: Dictionary = weapon.call("_summon_profile", player)
	stats["leadership"] = 16.0
	player.set("stats", stats)
	player.call("_apply_stat_scaling", false, player.get("max_health"))
	var high_profile: Dictionary = weapon.call("_summon_profile", player)

	if float(high_profile.get("damage", 0.0)) <= float(low_profile.get("damage", 0.0)):
		errors.append("Expected Leadership to raise summon damage (low %.2f, high %.2f)." % [low_profile.get("damage", 0.0), high_profile.get("damage", 0.0)])
	if float(high_profile.get("damage", 0.0)) < float(low_profile.get("damage", 0.0)) * 1.20:
		errors.append("Expected Leadership to raise summon damage noticeably (low %.2f, high %.2f)." % [low_profile.get("damage", 0.0), high_profile.get("damage", 0.0)])
	if float(high_profile.get("max_health", 0.0)) <= float(low_profile.get("max_health", 0.0)):
		errors.append("Expected Leadership to raise summon health (low %.2f, high %.2f)." % [low_profile.get("max_health", 0.0), high_profile.get("max_health", 0.0)])
	if float(high_profile.get("attack_interval", 99.0)) >= float(low_profile.get("attack_interval", 99.0)):
		errors.append("Expected Leadership to shorten summon attack interval (low %.3f, high %.3f)." % [low_profile.get("attack_interval", 0.0), high_profile.get("attack_interval", 0.0)])
	if float(high_profile.get("aoe_radius", 0.0)) <= float(low_profile.get("aoe_radius", 0.0)):
		errors.append("Expected Leadership to raise summon splash radius (low %.2f, high %.2f)." % [low_profile.get("aoe_radius", 0.0), high_profile.get("aoe_radius", 0.0)])

	holder.queue_free()
	await process_frame


func _test_summon_group_target_distribution(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	holder.add_child(player)
	player.global_position = Vector2(400, 320)
	await process_frame
	player.call("configure_character", "druid", "summon_amulet")
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		errors.append("Expected Druid summon weapon for target distribution test.")
		holder.queue_free()
		await process_frame
		return
	weapon.set_process(false)

	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	var allies: Array = []
	for index in range(3):
		var ally := ally_scene.instantiate()
		holder.add_child(ally)
		ally.global_position = player.global_position + Vector2(-32.0 + index * 32.0, 34.0)
		ally.set("owner_node", player)
		ally.call("set_combat_profile", {
			"damage": 18.0,
			"attack_range": 36.0,
			"lifetime": 20.0,
			"max_health": 35.0,
			"leash_radius": 560.0,
		})
		allies.append(ally)

	for index in range(3):
		var enemy := TestEnemy.new()
		holder.add_child(enemy)
		enemy.add_to_group("enemies")
		enemy.health = 18.0
		enemy.max_health = 18.0
		enemy.global_position = player.global_position + Vector2(95.0 + index * 38.0, -20.0 + index * 12.0)
	await process_frame

	weapon.call("_command_existing_summons")
	var assigned_ids := {}
	for ally in allies:
		var target = ally.get("command_target")
		if target != null and is_instance_valid(target):
			assigned_ids[target.get_instance_id()] = true
	if assigned_ids.size() < 2:
		errors.append("Expected summon target assignment to split 3 allies across at least 2 enemies, got %d unique targets." % assigned_ids.size())

	holder.queue_free()
	await process_frame


func _test_ally_attack_splash(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	var ally := ally_scene.instantiate()
	holder.add_child(ally)
	ally.global_position = Vector2(200, 200)
	ally.call("set_combat_profile", {
		"damage": 10.0,
		"attack_range": 48.0,
		"attack_interval": 0.35,
		"aoe_radius": 76.0,
		"aoe_damage_multiplier": 0.50,
		"lifetime": 10.0,
		"max_health": 20.0,
	})
	var primary := TestEnemy.new()
	var nearby := TestEnemy.new()
	var far := TestEnemy.new()
	holder.add_child(primary)
	holder.add_child(nearby)
	holder.add_child(far)
	primary.add_to_group("enemies")
	nearby.add_to_group("enemies")
	far.add_to_group("enemies")
	primary.global_position = Vector2(238, 200)
	nearby.global_position = Vector2(270, 202)
	far.global_position = Vector2(390, 200)
	await process_frame

	ally.call("_try_attack", primary)
	if absf(primary.damage_taken - 10.0) > 0.01:
		errors.append("Expected primary summon target to take exactly full damage once, got %.2f." % primary.damage_taken)
	if absf(nearby.damage_taken - 5.0) > 0.01:
		errors.append("Expected nearby enemy to take splash damage, got %.2f." % nearby.damage_taken)
	if far.damage_taken > 0.01:
		errors.append("Expected far enemy outside splash radius to stay unharmed, got %.2f." % far.damage_taken)

	holder.queue_free()
	await process_frame


func _test_ally_minion_profile_and_lifecycle(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var ally_scene := load("res://scenes/AllyMinion.tscn") as PackedScene
	var ally := ally_scene.instantiate()
	holder.add_child(ally)
	await process_frame
	ally.call("set_combat_profile", {
		"damage": 12.0,
		"move_speed": 260.0,
		"attack_range": 36.0,
		"attack_interval": 0.32,
		"lifetime": 18.0,
		"max_health": 42.0,
		"summon_role": "tank_control",
		"control_knockback": 80.0,
		"support_heal_percent": 0.005,
	})
	if absf(float(ally.get("damage")) - 12.0) > 0.01 or absf(float(ally.get("max_health")) - 42.0) > 0.01:
		errors.append("Expected AllyMinion set_combat_profile to apply combat values.")
	if str(ally.get("summon_role")) != "tank_control":
		errors.append("Expected AllyMinion profile to set summon_role.")
	var animated_body := ally.get_node_or_null("AnimatedBody") as AnimatedSprite2D
	var expects_delayed_death := animated_body != null and animated_body.visible and animated_body.sprite_frames != null and animated_body.sprite_frames.has_animation("death")
	ally.call("take_damage", 50.0)
	await process_frame
	if expects_delayed_death:
		if not is_instance_valid(ally) or ally.is_queued_for_deletion():
			errors.append("Expected animated AllyMinion death to delay queue_free until death playback ends.")
		elif not bool(ally.get("_death_lifecycle_started")):
			errors.append("Expected AllyMinion lethal damage to start the death lifecycle.")
		elif ally.is_in_group("allies"):
			errors.append("Expected dying AllyMinion to leave the allies group before delayed cleanup.")
		else:
			ally.call("take_damage", 50.0)
			await process_frame
			if not bool(ally.get("_death_lifecycle_started")):
				errors.append("Expected repeated lethal damage not to reset AllyMinion death lifecycle.")
			var frame_guard := 0
			while is_instance_valid(ally) and not ally.is_queued_for_deletion() and frame_guard < 100:
				await process_frame
				frame_guard += 1
			if is_instance_valid(ally) and not ally.is_queued_for_deletion():
				errors.append("Expected animated AllyMinion to queue_free after death playback.")
	else:
		if is_instance_valid(ally) and not ally.is_queued_for_deletion():
			errors.append("Expected non-animated AllyMinion to queue_free after lethal damage.")
	holder.queue_free()
	await process_frame
