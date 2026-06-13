extends "res://tests/runtime_smoke_test.gd"


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy_projectile_scene := load("res://scenes/EnemyProjectile.tscn") as PackedScene
	if main_scene == null or enemy_scene == null or enemy_projectile_scene == null:
		_fail("Expected combat smoke scenes to load.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "axe")
	main.call("_start_combat")
	await create_timer(1.0).timeout

	var player: Node = main.get("current_player")
	if player == null:
		_fail("Expected player to spawn in combat smoke.")
		return
	if player.global_position.distance_to(EXPECTED_ARENA_CENTER) > 1.0:
		_fail("Expected combat player to start at arena center.")
		return
	await _test_arena_generation(main, player)

	var resource_hud := main.find_child("RunResourceHud", true, false) as PanelContainer
	if resource_hud == null:
		_fail("Expected combat resource HUD.")
		return
	var timer_panel := main.find_child("CombatTimerPanel", true, false) as PanelContainer
	if timer_panel == null:
		_fail("Expected normal combat timer panel.")
		return

	var damage_test_derived: Dictionary = player.get("derived_parameters")
	damage_test_derived["dodge"] = 0.0
	player.set("derived_parameters", damage_test_derived)

	var contact_enemy := enemy_scene.instantiate()
	root.add_child(contact_enemy)
	contact_enemy.global_position = player.global_position
	await process_frame
	player.set("_damage_invulnerability_left", 0.0)
	contact_enemy.set("_contact_windup_left", -1.0)
	contact_enemy.set("_contact_cooldown", 0.0)
	var hp_before := float(player.get("health"))
	contact_enemy.call("_physics_process", 0.05)
	await process_frame
	if float(player.get("health")) < hp_before:
		_fail("Expected contact windup to avoid instant damage in combat smoke.")
		return
	contact_enemy.call("_physics_process", float(contact_enemy.get("contact_windup_time")) + 0.04)
	await process_frame
	if float(player.get("health")) >= hp_before:
		_fail("Expected contact damage to reduce player HP in combat smoke.")
		return
	var health_bar := contact_enemy.get_node_or_null("HealthBar")
	if health_bar == null:
		_fail("Expected enemy health bar in combat smoke.")
		return
	contact_enemy.call("take_damage", 1.0)
	if absf(float(health_bar.get("value")) - float(contact_enemy.get("health"))) > 0.01:
		_fail("Expected enemy health bar to match current HP.")
		return

	player.set("_damage_invulnerability_left", 0.0)
	var projectile := enemy_projectile_scene.instantiate()
	root.add_child(projectile)
	projectile.setup(player.global_position + Vector2(-24, 0), player.global_position, 4.0, 360.0)
	hp_before = float(player.get("health"))
	projectile.call("_on_body_entered", player)
	if float(player.get("health")) >= hp_before:
		_fail("Expected enemy projectile to damage player in combat smoke.")
		return

	await _test_death_flow(main_scene)
	await _test_hud_no_overlap_layouts(main_scene)

	main.queue_free()
	await process_frame
	print("Runtime combat smoke suite passed.")
	quit()
