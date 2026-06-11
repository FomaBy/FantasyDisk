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
	weapon.set_process(false)

	var close_enemy := enemy_scene.instantiate()
	root.add_child(close_enemy)
	close_enemy.global_position = Vector2(300, 250)

	var side_enemy := enemy_scene.instantiate()
	root.add_child(side_enemy)
	side_enemy.global_position = Vector2(480, 300)

	var close_side_probe := enemy_scene.instantiate()
	root.add_child(close_side_probe)
	close_side_probe.global_position = Vector2(365, 300)

	var far_enemy := enemy_scene.instantiate()
	root.add_child(far_enemy)
	far_enemy.global_position = Vector2(300, -280)

	var outside_range_enemy := enemy_scene.instantiate()
	root.add_child(outside_range_enemy)
	outside_range_enemy.global_position = Vector2(300, -340)

	await process_frame
	close_enemy.set_physics_process(false)
	side_enemy.set_physics_process(false)
	close_side_probe.set_physics_process(false)
	far_enemy.set_physics_process(false)
	outside_range_enemy.set_physics_process(false)
	close_enemy.add_to_group("enemies")
	side_enemy.add_to_group("enemies")
	close_side_probe.add_to_group("enemies")
	far_enemy.add_to_group("enemies")
	outside_range_enemy.add_to_group("enemies")
	close_enemy.global_position = Vector2(300, 250)
	side_enemy.global_position = Vector2(480, 300)
	close_side_probe.global_position = Vector2(365, 300)
	far_enemy.global_position = Vector2(300, -280)
	outside_range_enemy.global_position = Vector2(300, -340)
	close_enemy.set("health", close_enemy.get("max_health"))
	side_enemy.set("health", side_enemy.get("max_health"))
	close_side_probe.set("health", close_side_probe.get("max_health"))
	far_enemy.set("health", far_enemy.get("max_health"))
	outside_range_enemy.set("health", outside_range_enemy.get("max_health"))

	var target = weapon.call("_find_closest_enemy", player)
	if target != close_enemy:
		push_error("Expected melee weapon to select the close enemy as target.")
		quit(1)
		return

	weapon.set("_last_direction", Vector2.RIGHT)
	weapon.call("_attack")

	if float(close_enemy.get("health")) >= float(close_enemy.get("max_health")):
		push_error("Expected sword truncated cone to aim at and damage the closest enemy.")
		quit(1)
		return

	if float(side_enemy.get("health")) < float(side_enemy.get("max_health")):
		push_error("Expected sword truncated cone to avoid enemies outside the wide base.")
		quit(1)
		return

	if float(close_side_probe.get("health")) >= float(close_side_probe.get("max_health")):
		push_error("Expected sword truncated cone base to damage nearby enemies beside Berserk.")
		quit(1)
		return

	if float(far_enemy.get("health")) >= float(far_enemy.get("max_health")):
		push_error("Expected sword truncated cone to reach enemies close to 600 radius.")
		quit(1)
		return

	if float(outside_range_enemy.get("health")) < float(outside_range_enemy.get("max_health")):
		push_error("Expected sword truncated cone to avoid enemies beyond its radius.")
		quit(1)
		return

	var edge_probe := enemy_scene.instantiate()
	root.add_child(edge_probe)
	edge_probe.global_position = Vector2(724, -124)
	if not bool(weapon.call("_is_enemy_inside_attack", player, edge_probe, Vector2.UP)):
		push_error("Expected sword truncated cone to include enemies inside the wide outer arc.")
		quit(1)
		return

	var outside_angle_probe := enemy_scene.instantiate()
	root.add_child(outside_angle_probe)
	outside_angle_probe.global_position = Vector2(760, -86)
	if bool(weapon.call("_is_enemy_inside_attack", player, outside_angle_probe, Vector2.UP)):
		push_error("Expected sword truncated cone to reject enemies outside the outer width.")
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
	hammer.set_process(false)

	var hammer_enemy := enemy_scene.instantiate()
	root.add_child(hammer_enemy)
	hammer_enemy.global_position = Vector2(900, 430)
	hammer_enemy.add_to_group("enemies")
	hammer_enemy.set("health", hammer_enemy.get("max_health"))

	var hammer_outside_enemy := enemy_scene.instantiate()
	root.add_child(hammer_outside_enemy)
	hammer_outside_enemy.global_position = Vector2(900, 570)
	hammer_outside_enemy.add_to_group("enemies")
	hammer_outside_enemy.set("health", hammer_outside_enemy.get("max_health"))

	hammer.call("_attack")
	if float(hammer_enemy.get("health")) >= float(hammer_enemy.get("max_health")):
		push_error("Expected hammer AoE to damage enemies around Berserk.")
		quit(1)
		return
	if float(hammer_outside_enemy.get("health")) < float(hammer_outside_enemy.get("max_health")):
		push_error("Expected hammer AoE to avoid enemies outside the circular hit area.")
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
