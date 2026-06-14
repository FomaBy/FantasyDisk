extends SceneTree

const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	await _test_summon_configs(errors)
	await _test_summon_profile_scales_with_leadership(errors)
	await _test_ally_minion_profile_and_lifecycle(errors)

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
	if float(high_profile.get("max_health", 0.0)) <= float(low_profile.get("max_health", 0.0)):
		errors.append("Expected Leadership to raise summon health (low %.2f, high %.2f)." % [low_profile.get("max_health", 0.0), high_profile.get("max_health", 0.0)])
	if float(high_profile.get("attack_interval", 99.0)) >= float(low_profile.get("attack_interval", 99.0)):
		errors.append("Expected Leadership to shorten summon attack interval (low %.3f, high %.3f)." % [low_profile.get("attack_interval", 0.0), high_profile.get("attack_interval", 0.0)])

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
	ally.call("take_damage", 50.0)
	await process_frame
	if is_instance_valid(ally) and not ally.is_queued_for_deletion():
		errors.append("Expected AllyMinion to queue_free after lethal damage.")
	holder.queue_free()
	await process_frame
