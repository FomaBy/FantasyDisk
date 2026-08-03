extends SceneTree


func _initialize() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene

	var player := player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector2(300, 300)
	player.configure_character("berserk")
	player.equip_weapon("sword")
	await process_frame

	var weapon := _find_player_weapon(player)
	if weapon == null:
		push_error("Expected equipped Berserk subclass to attach a melee weapon.")
		quit(1)
		return
	if weapon.name != "TwoHandedSword" or weapon.get_parent().name != "WeaponSocket":
		push_error("Expected sword to be a separate scene attached to WeaponSocket.")
		quit(1)
		return
	if str(weapon.get("attack_shape")) != "sweep" or absf(float(weapon.get("sweep_degrees")) - 100.0) > 0.01 or absf(float(weapon.get("attack_range")) - 350.0) > 0.01:
		push_error("Expected sword to be a 100-degree 350px sector.")
		quit(1)
		return
	weapon.set_process(false)

	var close_enemy := enemy_scene.instantiate()
	root.add_child(close_enemy)
	close_enemy.global_position = Vector2(300, 250)

	var side_enemy := enemy_scene.instantiate()
	root.add_child(side_enemy)
	side_enemy.global_position = Vector2(386, 300)

	var inside_angle_enemy := enemy_scene.instantiate()
	root.add_child(inside_angle_enemy)
	inside_angle_enemy.global_position = Vector2(350, 250)

	var far_enemy := enemy_scene.instantiate()
	root.add_child(far_enemy)
	far_enemy.global_position = Vector2(300, -40)

	var outside_range_enemy := enemy_scene.instantiate()
	root.add_child(outside_range_enemy)
	outside_range_enemy.global_position = Vector2(300, -60)

	await process_frame
	close_enemy.set_physics_process(false)
	side_enemy.set_physics_process(false)
	inside_angle_enemy.set_physics_process(false)
	far_enemy.set_physics_process(false)
	outside_range_enemy.set_physics_process(false)
	close_enemy.add_to_group("enemies")
	side_enemy.add_to_group("enemies")
	inside_angle_enemy.add_to_group("enemies")
	far_enemy.add_to_group("enemies")
	outside_range_enemy.add_to_group("enemies")
	close_enemy.global_position = Vector2(300, 250)
	side_enemy.global_position = Vector2(386, 300)
	inside_angle_enemy.global_position = Vector2(350, 250)
	far_enemy.global_position = Vector2(300, -40)
	outside_range_enemy.global_position = Vector2(300, -60)
	close_enemy.set("health", close_enemy.get("max_health"))
	side_enemy.set("health", side_enemy.get("max_health"))
	inside_angle_enemy.set("health", inside_angle_enemy.get("max_health"))
	far_enemy.set("health", far_enemy.get("max_health"))
	outside_range_enemy.set("health", outside_range_enemy.get("max_health"))
	var isolated_parameters: Dictionary = player.get("derived_parameters")
	isolated_parameters["magic_damage"] = 0.0
	isolated_parameters["dot_damage"] = 0.0
	isolated_parameters["dot_speed"] = 0.0
	isolated_parameters["summon_amount"] = 0.0
	isolated_parameters["aura_radius"] = 0.0
	player.set("derived_parameters", isolated_parameters)

	var target = weapon.call("_find_closest_enemy", player)
	if target != close_enemy:
		push_error("Expected melee weapon to select the close enemy as target.")
		quit(1)
		return

	weapon.set("_last_direction", Vector2.RIGHT)
	weapon.call("_attack")

	if float(close_enemy.get("health")) >= float(close_enemy.get("max_health")):
		push_error("Expected sword sector to aim at and damage the closest enemy.")
		quit(1)
		return

	if float(side_enemy.get("health")) < float(side_enemy.get("max_health")):
		push_error("Expected sword sector to avoid enemies outside its 100-degree angle.")
		quit(1)
		return

	if float(inside_angle_enemy.get("health")) >= float(inside_angle_enemy.get("max_health")):
		push_error("Expected sword sector to damage enemies inside its 100-degree angle.")
		quit(1)
		return

	if float(far_enemy.get("health")) >= float(far_enemy.get("max_health")):
		push_error("Expected sword sector to reach enemies inside its 350px radius.")
		quit(1)
		return

	if float(outside_range_enemy.get("health")) < float(outside_range_enemy.get("max_health")):
		push_error("Expected sword sector to avoid enemies beyond its 350px radius.")
		quit(1)
		return

	var edge_probe := enemy_scene.instantiate()
	root.add_child(edge_probe)
	edge_probe.global_position = player.global_position + Vector2.UP.rotated(deg_to_rad(49.0)) * 340.0
	if not bool(weapon.call("_is_enemy_inside_attack", player, edge_probe, Vector2.UP)):
		push_error("Expected sword sector to include enemies inside its 100-degree edge.")
		quit(1)
		return

	var outside_angle_probe := enemy_scene.instantiate()
	root.add_child(outside_angle_probe)
	outside_angle_probe.global_position = player.global_position + Vector2.UP.rotated(deg_to_rad(51.0)) * 340.0
	if bool(weapon.call("_is_enemy_inside_attack", player, outside_angle_probe, Vector2.UP)):
		push_error("Expected sword sector to reject enemies outside its 100-degree edge.")
		quit(1)
		return

	player.apply_reward({"mods": {"aoe_radius_multiplier": 1.20}})
	if absf(float(weapon.get("sweep_degrees")) - 120.0) > 0.01 or absf(float(weapon.get("attack_range")) - 350.0) > 0.01:
		push_error("Expected attack-area upgrade to widen sword sector without changing target reach.")
		quit(1)
		return

	var hammer_player := player_scene.instantiate()
	root.add_child(hammer_player)
	hammer_player.global_position = Vector2(900, 300)
	hammer_player.configure_character("berserk")
	hammer_player.equip_weapon("hammer")
	await process_frame

	var hammer := _find_player_weapon(hammer_player)
	if hammer == null or str(hammer.get("attack_shape")) != "circle":
		push_error("Expected hammer subclass to attach circular AoE weapon.")
		quit(1)
		return
	if absf(float(hammer.get("max_aoe_radius"))) > 0.01 or absf(float(hammer.get("aoe_radius")) - 150.0) > 0.01:
		push_error("Expected hammer AoE to start at uncapped 150px radius.")
		quit(1)
		return
	var hammer_center := hammer.call("_circle_attack_center", hammer_player) as Vector2
	var hammer_scale := hammer.call("_circle_attack_visual_scale") as Vector2
	if hammer_center.distance_to(hammer_player.global_position + Vector2(0.0, 16.0)) > 0.01 or hammer_scale.distance_to(Vector2.ONE) > 0.01:
		push_error("Expected FAN-1100 hammer contract: +16px footline center and a round (unit-scale) circle, not an oval.")
		quit(1)
		return
	hammer.set_process(false)

	var hammer_enemy := enemy_scene.instantiate()
	root.add_child(hammer_enemy)
	hammer_enemy.global_position = Vector2(900, 440)
	hammer_enemy.add_to_group("enemies")
	hammer_enemy.set("health", hammer_enemy.get("max_health"))

	# FAN-1100: the hammer AoE is a true circle (no vertical stretch). With the
	# retained +16px footline center and a 150px radius, the lower reach is ~166px.
	# Probe an enemy inside that circle (155px) and one just past it (185px) to
	# lock the round shape without weakening the gameplay contract.
	var hammer_lower_inside_enemy := enemy_scene.instantiate()
	root.add_child(hammer_lower_inside_enemy)
	hammer_lower_inside_enemy.global_position = hammer_player.global_position + Vector2(0.0, 155.0)
	hammer_lower_inside_enemy.add_to_group("enemies")
	hammer_lower_inside_enemy.set("health", hammer_lower_inside_enemy.get("max_health"))

	var hammer_outside_enemy := enemy_scene.instantiate()
	root.add_child(hammer_outside_enemy)
	hammer_outside_enemy.global_position = hammer_player.global_position + Vector2(0.0, 185.0)
	hammer_outside_enemy.add_to_group("enemies")
	hammer_outside_enemy.set("health", hammer_outside_enemy.get("max_health"))

	await process_frame
	hammer.call("_attack")
	if float(hammer_enemy.get("health")) >= float(hammer_enemy.get("max_health")):
		push_error("Expected hammer AoE to damage enemies around Berserk.")
		quit(1)
		return
	if float(hammer_lower_inside_enemy.get("health")) >= float(hammer_lower_inside_enemy.get("max_health")):
		push_error("Expected FAN-1100 hammer circle to include the lower y=155 probe (inside the 166px reach).")
		quit(1)
		return
	if float(hammer_outside_enemy.get("health")) < float(hammer_outside_enemy.get("max_health")):
		push_error("Expected hammer AoE to reject the 185px lower probe outside the round radius.")
		quit(1)
		return

	hammer_player.apply_reward({"mods": {"sector_multiplier": 1.50}})
	if absf(float(hammer.get("aoe_radius")) - 150.0) > 0.01:
		push_error("Expected removed sector modifier not to change hammer circle radius.")
		quit(1)
		return
	hammer_player.apply_reward({"mods": {"aoe_radius_multiplier": 1.20}})
	var expected_hammer_radius := 150.0 * pow(1.20, float(hammer_player.get("weapon_config").get("upgrade_aoe_exponent", 1.0)))
	if absf(float(hammer.get("aoe_radius")) - expected_hammer_radius) > 0.01:
		push_error("Expected radius upgrade to increase hammer circle radius.")
		quit(1)
		return
	var cap_inside_probe := enemy_scene.instantiate()
	root.add_child(cap_inside_probe)
	cap_inside_probe.global_position = hammer_center + Vector2.DOWN * (expected_hammer_radius * hammer_scale.y - 1.0)
	if not bool(hammer.call("_is_enemy_inside_attack", hammer_player, cap_inside_probe, Vector2.RIGHT)):
		push_error("Expected scaled hammer AoE to include the 1px-inside enlarged circle boundary.")
		quit(1)
		return
	var cap_outside_probe := enemy_scene.instantiate()
	root.add_child(cap_outside_probe)
	cap_outside_probe.global_position = hammer_center + Vector2.DOWN * (expected_hammer_radius * hammer_scale.y + 1.0)
	if bool(hammer.call("_is_enemy_inside_attack", hammer_player, cap_outside_probe, Vector2.RIGHT)):
		push_error("Expected scaled hammer AoE to reject the 1px-outside enlarged circle boundary.")
		quit(1)
		return

	print("Melee weapon targeting test passed.")
	quit()


func _find_player_weapon(player: Node) -> Node:
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket")
	if socket != null:
		for child in socket.get_children():
			if child.is_in_group("player_weapons"):
				return child
	for child in player.get_children():
		if child.is_in_group("player_weapons"):
			return child
	return null
