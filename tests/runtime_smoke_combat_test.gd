extends "res://tests/runtime_smoke_test.gd"


func _combat_feedback_nodes(name_filter := "") -> Array:
	var nodes := []
	for node in root.get_tree().get_nodes_in_group("combat_feedback_labels"):
		if not is_instance_valid(node):
			continue
		if name_filter == "" or node.name == name_filter:
			nodes.append(node)
	return nodes


func _combat_flash_nodes() -> Array:
	var nodes := []
	for node in root.get_tree().get_nodes_in_group("combat_feedback_flashes"):
		if is_instance_valid(node):
			nodes.append(node)
	return nodes


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
	await process_frame
	if _combat_feedback_nodes("CombatDamageNumber").is_empty():
		_fail("Expected enemy hit to spawn a combat damage number.")
		return
	if _combat_flash_nodes().is_empty():
		_fail("Expected enemy hit to spawn a short hit flash.")
		return
	# SCRUM-611: вспышка попадания — мягкий радиальный Sprite2D (CombatHitTick), а НЕ
	# квадратная рамка Line2D (CombatHitOutline читалась как UI-артефакт).
	for flash in _combat_flash_nodes():
		if flash is Line2D or flash.name == "CombatHitOutline":
			_fail("SCRUM-611: hit-flash должен быть мягким тиком, а не квадратной рамкой Line2D.")
			return
	var has_tick := false
	for flash in _combat_flash_nodes():
		if flash is Sprite2D and flash.name == "CombatHitTick":
			has_tick = true
	if not has_tick:
		_fail("SCRUM-611: ожидался радиальный Sprite2D 'CombatHitTick' как вспышка попадания.")
		return

	contact_enemy.call("take_damage", 0.25, {"critical": true})
	await process_frame
	if _combat_feedback_nodes("CombatCritNumber").is_empty() or _combat_feedback_nodes("CombatCritMarker").is_empty():
		_fail("Expected critical enemy hit to spawn a distinct crit number and marker.")
		return

	var player_health_before_heal := float(player.get("health"))
	player.call("heal_percent", 0.05)
	await process_frame
	if float(player.get("health")) <= player_health_before_heal or _combat_feedback_nodes("CombatHealNumber").is_empty():
		_fail("Expected player healing to spawn a green combat heal number.")
		return

	root.get_tree().root.set_meta("combat_feedback", false)
	var disabled_count := _combat_feedback_nodes().size()
	contact_enemy.call("take_damage", 0.05)
	await process_frame
	if _combat_feedback_nodes().size() > disabled_count:
		_fail("Expected combat_feedback=false to suppress new combat labels.")
		return
	root.get_tree().root.set_meta("combat_feedback", true)

	contact_enemy.set("max_health", 999.0)
	contact_enemy.set("health", 999.0)
	for index in range(60):
		contact_enemy.call("take_damage", 0.01)
	await process_frame
	if _combat_feedback_nodes().size() > 42:
		_fail("Expected combat feedback labels to respect the active cap under dense AoE.")
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

	# SCRUM-708: спавн-кап волны — инвариант. CombatDirector кэширует _active_enemy_cap()
	# один раз на волну; проверяем, что число врагов в группе никогда не превышает кап
	# даже после нескольких подряд волн (включая small-pack спавны).
	# Freeze must happen before queue_free()+await: Main._process() is another wave
	# producer and may otherwise refill the group during that first awaited frame.
	var previous_spawn_cooldown := float(main.get("spawn_cooldown"))
	main.set("spawn_cooldown", 3600.0)
	for stray in main.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray):
			stray.queue_free()
	await process_frame
	var combat_director = main.get("combat")
	if combat_director == null:
		_fail("SCRUM-708: expected CombatDirector to be reachable via main.combat.")
		return
	main.set("spawn_wave_index", 0)
	var wave_cap := int(main.call("_active_enemy_cap"))
	for wave_iteration in range(4):
		combat_director.call("_spawn_enemy_wave")
		await process_frame
		var live_enemies := int(main.get_tree().get_nodes_in_group("enemies").size())
		if live_enemies > wave_cap:
			_fail("SCRUM-708: spawn wave exceeded the active enemy cap (%d > %d)." % [live_enemies, wave_cap])
			return
		main.set("spawn_wave_index", int(main.get("spawn_wave_index")) + 1)
		wave_cap = int(main.call("_active_enemy_cap"))
	for stray in main.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(stray):
			stray.queue_free()
	await process_frame
	main.set("spawn_cooldown", previous_spawn_cooldown)

	await _test_death_flow(main_scene)
	await _test_hud_no_overlap_layouts(main_scene)

	main.queue_free()
	await process_frame
	_finish("Runtime combat smoke suite passed.")
