extends SceneTree

const EXPECTED_ARENA_SIZE := Vector2(2560, 1440)
const EXPECTED_ARENA_CENTER := EXPECTED_ARENA_SIZE * 0.5
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const MetaProgression := preload("res://scripts/meta_progression.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const EventData := preload("res://scripts/event_data.gd")

func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Main scene did not load.")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	if main.get("ui_layer") == null:
		push_error("Expected main menu UI to be created.")
		quit(1)
		return
	var main_menu_background := main.find_child("MainMenuBackground", true, false) as TextureRect
	if main_menu_background == null or main_menu_background.texture == null or main_menu_background.texture.resource_path != "res://assets/backgrounds/main_menu_epic_battle.png":
		push_error("Expected main menu to render the epic battle background image.")
		quit(1)
		return
	var main_menu_actions := main.find_child("MainMenuActions", true, false) as VBoxContainer
	if main_menu_actions == null or main_menu_actions.get_child_count() != 4:
		push_error("Expected main menu to expose four action buttons (start, settings, codex, exit).")
		quit(1)
		return
	if main_menu_actions.global_position.x > 140.0:
		push_error("Expected main menu buttons to stay on the left side of the start screen.")
		quit(1)
		return
	var main_menu_button_texts := []
	for child in main_menu_actions.get_children():
		var button := child as Button
		if button != null:
			main_menu_button_texts.append(button.text)
	if main_menu_button_texts != ["Начать новую игру", "Настройки", "Кодекс", "Выйти из игры"]:
		push_error("Expected main menu buttons to be start/settings/codex/exit.")
		quit(1)
		return

	var route_nodes: Array = main.get("route_nodes")
	# 10 рядов активностей + финальный ряд босса.
	if route_nodes.size() != 11:
		push_error("Expected the vertical route to have 3 choice rows plus a boss row.")
		quit(1)
		return
	if str(route_nodes[route_nodes.size() - 1][0].get("type", "")) != "boss":
		push_error("Expected the last vertical route row to be boss-only.")
		quit(1)
		return
	var first_row_has_battle := false
	for route_node in route_nodes[0]:
		if str(route_node.get("type", "")) == "battle":
			first_row_has_battle = true
	if not first_row_has_battle:
		push_error("Expected the first route row to include at least one normal battle.")
		quit(1)
		return
	var has_limited_route_branch := false
	for step_index in range(route_nodes.size() - 1):
		var next_count := (route_nodes[step_index + 1] as Array).size()
		for route_node in route_nodes[step_index]:
			var next_branches: Array = route_node.get("next_branches", [])
			if next_branches.is_empty():
				push_error("Expected every route node before boss to expose next_branches.")
				quit(1)
				return
			if next_count > 1 and next_branches.size() < next_count:
				has_limited_route_branch = true
	if not has_limited_route_branch:
		push_error("Expected route generation to create limited paths instead of all-to-all map connections.")
		quit(1)
		return
	for node_type in ["battle", "elite_battle", "shop", "event", "rest", "boss"]:
		var definition: Dictionary = main.call("_map_node_definition", node_type)
		if str(definition.get("name", "")) == "" or str(definition.get("icon", "")) == "" or str(definition.get("tooltip", "")) == "":
			push_error("Expected map node definition %s to include name/icon/tooltip." % node_type)
			quit(1)
			return
		if not str(definition.get("icon_path", "")).begins_with("res://assets/sprites/map_icons/"):
			push_error("Expected map node definition %s to use a PNG map icon." % node_type)
			quit(1)
			return
		if not ResourceLoader.exists(str(definition.get("icon_path", ""))):
			push_error("Expected map node icon for %s to exist." % node_type)
			quit(1)
			return
	for screen_background_path in [
		"res://assets/sprites/ui/screens/screen_event_background.png",
		"res://assets/sprites/ui/screens/screen_shop_background.png",
		"res://assets/sprites/ui/screens/screen_campfire_background.png",
	]:
		if not ResourceLoader.exists(screen_background_path):
			push_error("Expected screen background asset to exist: %s" % screen_background_path)
			quit(1)
			return
	var boss_definition: Dictionary = main.call("_map_node_definition", "boss")
	if main.call("_route_node_icon_path", {"type": "boss", "boss_id": "disk_devourer"}, boss_definition) != "res://assets/sprites/map_icons/map_boss_disk_devourer.png":
		push_error("Expected Disk Devourer boss node to use its own map icon.")
		quit(1)
		return
	main.call("_show_battle_map")
	await process_frame
	await process_frame
	var route_scroll := main.find_child("RouteMapScroll", true, false) as ScrollContainer
	if route_scroll == null:
		push_error("Expected route map to render inside a ScrollContainer.")
		quit(1)
		return
	if route_scroll.anchor_left != 0.0 or route_scroll.anchor_right != 1.0 or route_scroll.anchor_bottom != 1.0:
		push_error("Expected route map scroll area to be full-screen width instead of a small panel widget.")
		quit(1)
		return
	if route_scroll.offset_top > 140.0 or route_scroll.offset_left > 40.0 or route_scroll.offset_right < -40.0:
		push_error("Expected route map scroll area to use almost the entire screen.")
		quit(1)
		return
	var route_map := route_scroll.find_child("VerticalRouteMap", true, false) as Control
	if route_map == null:
		push_error("Expected route map scroll area to contain the map canvas.")
		quit(1)
		return
	if route_map.custom_minimum_size.y < 1700.0:
		push_error("Expected route map canvas to be tall enough for 10 activity rows plus the boss row.")
		quit(1)
		return
	if route_map.custom_minimum_size.x < 900.0 or route_map.custom_minimum_size.x > route_scroll.size.x + 1.0:
		push_error("Expected route map canvas width to fit the screen without horizontal scrolling.")
		quit(1)
		return
	if route_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		push_error("Expected route map horizontal scrolling to be disabled.")
		quit(1)
		return
	if main.find_child("RouteNodeIcon", true, false) == null:
		push_error("Expected rendered route map nodes to include TextureRect icons.")
		quit(1)
		return
	var route_line := main.find_child("RouteMapLine", true, false) as Control
	if route_line == null or route_line.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("Expected route map lines to ignore mouse input so route nodes stay clickable.")
		quit(1)
		return
	if route_line.size.y > 2.5:
		push_error("Expected route map connection lines to stay thin and non-dominant.")
		quit(1)
		return
	var available_start_found := false
	for branch_index in range((route_nodes[0] as Array).size()):
		var route_node: Dictionary = route_nodes[0][branch_index]
		var button := main.find_child("RouteNode_%s_0_%d" % [str(route_node.get("type", "battle")), branch_index], true, false) as Button
		if button != null and not button.disabled:
			available_start_found = true
			if button.tooltip_text == "":
				push_error("Expected available start route nodes to expose hover tooltips.")
				quit(1)
				return
			var icon := button.find_child("RouteNodeIcon", true, false) as Control
			if icon == null or icon.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				push_error("Expected route node icons to ignore mouse input so buttons receive clicks.")
				quit(1)
				return
	if not available_start_found:
		push_error("Expected at least one start route node to be available at route stage 0.")
		quit(1)
		return
	await _test_route_map_start_selection(main_scene)
	await _test_event_route_node_click(main_scene)
	await _test_random_event_data_and_outcomes(main_scene)
	var generated_elite := false
	var generated_disk_boss := false
	for _attempt in range(20):
		var generated_route: Array = main.call("_generate_route")
		for row in generated_route:
			for route_node in row:
				if str(route_node.get("type", "")) == "elite_battle":
					generated_elite = true
				if str(route_node.get("boss_id", "")) == "disk_devourer":
					generated_disk_boss = true
	if not generated_elite:
		push_error("Expected route generation to sometimes include elite battle nodes.")
		quit(1)
		return
	if not generated_disk_boss:
		push_error("Expected route generation to sometimes include Disk Devourer as a final boss.")
		quit(1)
		return

	var extra_enemy_scene_properties := [
		"mage_enemy_scene",
		"spitter_enemy_scene",
		"shield_enemy_scene",
		"biter_enemy_scene",
		"bone_shaman_enemy_scene",
		"flying_enemy_scene",
		"elite_armored_scene",
		"elite_stalker_scene",
		"elite_poisoned_scene",
		"elite_commander_scene",
	]
	for property_name in extra_enemy_scene_properties:
		if main.get(property_name) == null:
			push_error("Expected Main to include %s in the enemy spawn pool." % property_name)
			quit(1)
			return
	if main.get("disk_devourer_boss_scene") == null:
		push_error("Expected Main to expose the second act boss scene.")
		quit(1)
		return

	main.call("_show_settings_menu")
	await process_frame
	await _test_settings_tabs_and_rebind(main)
	main.set("selected_resolution_index", 0)
	main.set("selected_window_mode_index", 1)
	main.call("_apply_video_settings")
	if int(main.get("selected_resolution_index")) != 0 or int(main.get("selected_window_mode_index")) != 1:
		push_error("Expected video settings to keep selected values.")
		quit(1)
		return

	main.call("_show_character_select")
	await process_frame
	var hero_screen := main.find_child("HeroSelectScreen", true, false) as Control
	if hero_screen == null:
		push_error("Expected character select to use a fullscreen hero select root.")
		quit(1)
		return
	if main.find_child("CharacterCardsScroll", true, false) != null:
		push_error("Expected fullscreen hero select to show all 9 cards without a scroll container.")
		quit(1)
		return
	var hero_grid := main.find_child("CharacterCardsGrid", true, false) as GridContainer
	if hero_grid == null or hero_grid.columns != 3:
		push_error("Expected character select to use a 3x3 hero grid.")
		quit(1)
		return
	if hero_grid.get_child_count() != 9:
		push_error("Expected character select to show 9 hero cards at once.")
		quit(1)
		return
	for character_id in ProgressionData.character_ids():
		var card := main.find_child("CharacterCard_%s" % character_id, true, false) as Button
		if card == null or card.tooltip_text == "":
			push_error("Expected character card with stats tooltip for %s." % character_id)
			quit(1)
			return
		var portrait := main.find_child("CharacterPortrait_%s" % character_id, true, false) as TextureRect
		if portrait == null or portrait.texture == null:
			push_error("Expected character select to show portrait for %s." % character_id)
			quit(1)
			return
	if ProgressionData.reward_pool().size() < 28:
		push_error("Expected expanded working artifact/reward pool.")
		quit(1)
		return
	if ProgressionData.shop_items().size() <= ProgressionData.reward_pool().size() / 2:
		push_error("Expected shop pool to include artifact items, not only base goods.")
		quit(1)
		return
	for icon_id in UIIconRegistry.BASE_STAT_IDS + UIIconRegistry.DERIVED_ATTRIBUTE_IDS + UIIconRegistry.HUD_IDS:
		if not UIIconRegistry.has_texture(icon_id):
			push_error("Expected UI icon registry to expose a PNG texture for %s." % icon_id)
			quit(1)
			return
	for artifact in ProgressionData.ARTIFACTS:
		var artifact_icon_path := "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % str(artifact.get("id", ""))
		if not ResourceLoader.exists(artifact_icon_path):
			push_error("Expected artifact icon asset to exist: %s" % artifact_icon_path)
			quit(1)
			return
	for shop_item in ProgressionData.SHOP_ITEMS:
		var shop_icon_path := "res://assets/sprites/ui/icons/shop/shop_%s.png" % str(shop_item.get("id", ""))
		if not ResourceLoader.exists(shop_icon_path):
			push_error("Expected shop item icon asset to exist: %s" % shop_icon_path)
			quit(1)
			return
	for ui_asset_path in [
		"res://assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png",
		"res://assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png",
		"res://assets/sprites/ui/shop/ui_shop_price_badge.png",
		"res://assets/sprites/ui/shop/ui_shop_purchased_overlay.png",
		"res://assets/sprites/ui/shop/ui_shop_tooltip_frame.png",
		"res://assets/sprites/ui/cursor/game_cursor.png",
		"res://assets/sprites/ui/cursor/game_cursor_hover.png",
		"res://assets/sprites/ui/cursor/game_cursor_attack.png",
	]:
		if not ResourceLoader.exists(ui_asset_path):
			push_error("Expected shop/cursor UI asset to exist: %s" % ui_asset_path)
			quit(1)
			return
	for character_id in ProgressionData.character_ids():
		if not ProgressionData.character_ids().has(character_id):
			push_error("Expected playable character %s in progression data." % character_id)
			quit(1)
			return
		if (ProgressionData.weapon_ids(character_id) as Array).size() != 3:
			push_error("Expected %s to have exactly three weapon variants." % character_id)
			quit(1)
			return
	main.set("selected_character_id", "berserk")
	main.call("_show_weapon_select")
	await process_frame
	main.set("selected_weapon_id", "axe")
	main.call("_start_combat")
	await create_timer(1.0).timeout
	var resource_hud := main.find_child("RunResourceHud", true, false) as PanelContainer
	if resource_hud == null:
		push_error("Expected combat to create the compact resource HUD.")
		quit(1)
		return
	for hud_node_name in ["HudHPCard", "HudXPCard", "HudMoneyCard"]:
		if resource_hud.find_child(hud_node_name, true, false) == null:
			push_error("Expected combat resource HUD to include %s." % hud_node_name)
			quit(1)
			return
	for hud_icon_id in ["hp", "xp", "money"]:
		var hud_icon := resource_hud.find_child("UIIcon_%s" % hud_icon_id, true, false) as TextureRect
		if hud_icon == null or hud_icon.texture == null:
			push_error("Expected combat HUD icon %s to use a PNG texture." % hud_icon_id)
			quit(1)
			return
	if main.get("status_label") != null:
		push_error("Expected combat HUD to stay compact and not expose the status label.")
		quit(1)
		return
	# Таймер боя: по центру сверху, при <=5с переходит в alarm-состояние (PM 2026-06-11).
	var timer_panel := main.find_child("CombatTimerPanel", true, false) as PanelContainer
	var timer_text := main.get("timer_label") as Label
	if timer_panel == null or timer_text == null or timer_panel.anchor_left != 0.5:
		push_error("Expected the combat timer panel centered at the top of the HUD.")
		quit(1)
		return
	main.set("round_time_left", 4.0)
	main.set("_last_hud_snapshot", {})
	main.ui._update_hud()
	if not bool(timer_text.get_meta("alarm_active", false)):
		push_error("Expected the combat timer to turn red at <=5 seconds.")
		quit(1)
		return
	main.set("round_time_left", 30.0)
	main.set("_last_hud_snapshot", {})
	main.ui._update_hud()
	if bool(timer_text.get_meta("alarm_active", false)):
		push_error("Expected the combat timer alarm to reset above 5 seconds.")
		quit(1)
		return
	# HUD артефактов: подбор артефакта добавляет иконку с tooltip.
	var hud_player := get_first_node_in_group("player")
	hud_player.call("apply_reward", {"kind": "artifact", "id": "cracked_shield", "title": "Треснувший щит", "mods": {"defense_flat": 0.12}})
	main.set("_last_hud_snapshot", {})
	main.ui._update_hud()
	var artifact_row := main.find_child("ArtifactHudRow", true, false) as HFlowContainer
	if artifact_row == null or artifact_row.get_child_count() != 1:
		push_error("Expected one artifact icon on the HUD after pickup.")
		quit(1)
		return
	var hud_artifact_icon := artifact_row.get_child(0) as TextureRect
	if hud_artifact_icon == null or hud_artifact_icon.texture == null or hud_artifact_icon.tooltip_text == "":
		push_error("Expected the artifact HUD icon to carry a texture and tooltip.")
		quit(1)
		return
	var stored_artifacts: Array = hud_player.get("artifacts")
	if stored_artifacts.is_empty() or str((stored_artifacts[0] as Dictionary).get("id", "")) != "cracked_shield":
		push_error("Expected player artifacts to store ids alongside titles.")
		quit(1)
		return

	var player := get_first_node_in_group("player")
	if player == null:
		push_error("Expected selected player to spawn.")
		quit(1)
		return
	if player.get("character_id") != "berserk" or player.get("weapon_id") != "axe":
		push_error("Expected Berserk with selected axe weapon.")
		quit(1)
		return
	if player.get_node_or_null("VisualRoot/WeaponSocket") == null:
		push_error("Expected Berserk to expose a WeaponSocket attachment point.")
		quit(1)
		return
	var player_body := player.get_node_or_null("VisualRoot/Body") as AnimatedSprite2D
	if player_body == null or player_body.scale.x > 0.30:
		push_error("Expected player visual scale to be reduced by another 20-30% for the larger arena view.")
		quit(1)
		return
	var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_shape := player_collision.shape as CircleShape2D
	if player_shape == null or player_shape.radius > 11.0:
		push_error("Expected player hurtbox to match the smaller character size.")
		quit(1)
		return
	if int(player.get("collision_mask")) & 6 != 0:
		push_error("Expected player physics mask to ignore enemy collision layers.")
		quit(1)
		return
	if int(player.get("collision_mask")) & 64 != 0:
		push_error("Expected player physics mask to ignore disabled pit collision layer.")
		quit(1)
		return
	if float(player.get("speed")) < 300.0:
		push_error("Expected player stat-derived move speed to be noticeably faster.")
		quit(1)
		return
	if player.global_position.distance_to(EXPECTED_ARENA_CENTER) > 1.0:
		push_error("Expected player to start at the center of the 2560x1440 arena.")
		quit(1)
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or camera.limit_left != 0 or camera.limit_top != 0 or camera.limit_right != int(EXPECTED_ARENA_SIZE.x) or camera.limit_bottom != int(EXPECTED_ARENA_SIZE.y):
		push_error("Expected player camera limits to match arena bounds.")
		quit(1)
		return
	if camera.zoom.x < 1.05 or camera.zoom.y < 1.05:
		push_error("Expected player camera to be zoomed in enough that the 2K arena is not fully visible.")
		quit(1)
		return
	var visible_at_1600 := Vector2(1600.0 / camera.zoom.x, 900.0 / camera.zoom.y)
	var visible_at_2560 := Vector2(2560.0 / camera.zoom.x, 1440.0 / camera.zoom.y)
	if visible_at_1600.x >= EXPECTED_ARENA_SIZE.x or visible_at_1600.y >= EXPECTED_ARENA_SIZE.y:
		push_error("Expected 1600x900 view to show only part of the arena.")
		quit(1)
		return
	if visible_at_2560.x >= EXPECTED_ARENA_SIZE.x or visible_at_2560.y >= EXPECTED_ARENA_SIZE.y:
		push_error("Expected 2560x1440 view to show only part of the arena.")
		quit(1)
		return

	var melee_weapon := _find_player_weapon(player)
	if melee_weapon == null:
		push_error("Expected Berserk to have a melee weapon.")
		quit(1)
		return
	if melee_weapon.name != "TwoHandedAxe" or melee_weapon.get_parent().name != "WeaponSocket":
		push_error("Expected axe to be a separate scene attached to WeaponSocket.")
		quit(1)
		return
	var axe_visual := melee_weapon.get_node_or_null("WeaponVisual") as Sprite2D
	if axe_visual == null or axe_visual.texture == null or axe_visual.texture.resource_path != "res://assets/sprites/weapons/two_handed_axe.png":
		push_error("Expected axe weapon to use the two-handed axe sprite.")
		quit(1)
		return
	if str(melee_weapon.get("attack_shape")) != "sweep" or float(melee_weapon.get("sweep_degrees")) != 140.0 or float(melee_weapon.get("attack_range")) < 320.0:
		push_error("Expected axe to use a wide 140-degree sweep arc.")
		quit(1)
		return
	var sword_config: Dictionary = ProgressionData.weapon("berserk", "sword")
	if str(sword_config.get("attack_shape")) != "frustum" or float(sword_config.get("inner_width")) != 150.0 or float(sword_config.get("outer_width")) != 1200.0 or float(sword_config.get("attack_range")) != 600.0 or float(sword_config.get("damage_multiplier")) != 1.15:
		push_error("Expected sword to be a 90-degree 600px frustum with 150px base and 1.15 damage.")
		quit(1)
		return
	var hammer_config: Dictionary = ProgressionData.weapon("berserk", "hammer")
	if float(hammer_config.get("damage_multiplier")) != 0.55 or float(hammer_config.get("upgrade_aoe_exponent", 1.0)) <= 1.0 or float(hammer_config.get("upgrade_damage_exponent", 1.0)) <= 1.0:
		push_error("Expected hammer to start weak with boosted upgrade scaling exponents.")
		quit(1)
		return
	await _test_arena_generation(main, player)

	# Dodge делает проверки урона недетерминированными; для damage-блока обнуляем уворот.
	var damage_test_derived: Dictionary = player.get("derived_parameters")
	damage_test_derived["dodge"] = 0.0
	player.set("derived_parameters", damage_test_derived)

	var hp_before_contact := float(player.get("health"))
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var contact_enemy := enemy_scene.instantiate()
	root.add_child(contact_enemy)
	contact_enemy.global_position = player.global_position
	await process_frame
	if int(contact_enemy.get("collision_mask")) & 1 != 0:
		push_error("Expected enemies not to physically block the player body.")
		quit(1)
		return
	var player_position_before_overlap: Vector2 = player.global_position
	Input.action_press("move_right")
	await create_timer(0.18).timeout
	Input.action_release("move_right")
	if player.global_position.distance_to(player_position_before_overlap) < 12.0:
		push_error("Expected player to move through overlapping monsters instead of being blocked.")
		quit(1)
		return
	contact_enemy.global_position = player.global_position
	# Сбрасываем windup, накопившийся за время прохода сквозь врага выше:
	# проверяем именно свежую атаку с замахом.
	contact_enemy.set("_contact_windup_left", -1.0)
	contact_enemy.set("_contact_cooldown", 0.0)
	hp_before_contact = float(player.get("health"))
	contact_enemy.call("_physics_process", 0.05)
	await process_frame
	if float(player.get("health")) < hp_before_contact:
		push_error("Expected contact damage to wait for wind-up instead of hitting instantly.")
		quit(1)
		return
	contact_enemy.call("_physics_process", float(contact_enemy.get("contact_windup_time")) + 0.04)
	await process_frame
	var hp_after_contact := float(player.get("health"))
	if hp_after_contact >= hp_before_contact:
		push_error("Expected contact damage to reduce player HP after wind-up.")
		quit(1)
		return
	var damage_flash := main.find_child("DamageFlashOverlay", true, false) as ColorRect
	if damage_flash == null:
		push_error("Expected combat HUD to include the damage flash overlay.")
		quit(1)
		return
	if damage_flash.modulate.a <= 0.01 or damage_flash.modulate.a > 0.3:
		push_error("Expected a light screen flash right after player damage (alpha ~0.2).")
		quit(1)
		return
	var enemy_health_bar := contact_enemy.get_node_or_null("HealthBar")
	if enemy_health_bar == null:
		push_error("Expected enemies to carry an overhead health bar node.")
		quit(1)
		return
	if absf(float(enemy_health_bar.get("max_value")) - float(contact_enemy.get("max_health"))) > 0.01:
		push_error("Expected enemy health bar max value to match scaled enemy max health.")
		quit(1)
		return
	contact_enemy.call("take_damage", 1.0)
	if float(enemy_health_bar.get("value")) >= float(enemy_health_bar.get("max_value")):
		push_error("Expected enemy health bar to track damage.")
		quit(1)
		return
	if absf(float(enemy_health_bar.get("value")) - float(contact_enemy.get("health"))) > 0.01:
		push_error("Expected enemy health bar value to match current enemy health after damage.")
		quit(1)
		return
	if float(ProgressionData.weapon("berserk", "hammer").get("aoe_radius", 0.0)) != 100.0 or float(ProgressionData.weapon("berserk", "hammer").get("attack_range", 0.0)) != 100.0:
		push_error("Expected hammer starting radius and range to be nerfed to 100.")
		quit(1)
		return
	if float(contact_enemy.get("contact_range")) <= 34.0:
		push_error("Expected contact range to auto-fit the visible sprite size.")
		quit(1)
		return
	contact_enemy.call("_physics_process", 0.10)
	await process_frame
	if float(player.get("health")) < hp_after_contact:
		push_error("Expected contact damage cooldown/invulnerability to prevent every-frame damage.")
		quit(1)
		return
	player.set("_damage_invulnerability_left", 0.0)
	var enemy_projectile_scene := load("res://scenes/EnemyProjectile.tscn") as PackedScene
	var enemy_projectile := enemy_projectile_scene.instantiate()
	root.add_child(enemy_projectile)
	enemy_projectile.setup(player.global_position + Vector2(-24, 0), player.global_position, 4.0, 360.0)
	var hp_before_projectile := float(player.get("health"))
	enemy_projectile.call("_on_body_entered", player)
	var hp_after_projectile := float(player.get("health"))
	if hp_after_projectile >= hp_before_projectile:
		push_error("Expected enemy projectile to damage the player.")
		quit(1)
		return
	player.set("_damage_invulnerability_left", 0.0)
	enemy_projectile.call("_on_body_entered", player)
	if float(player.get("health")) < hp_after_projectile:
		push_error("Expected enemy projectile to deal damage only once.")
		quit(1)
		return
	await process_frame
	var cleanup_enemy_projectile := enemy_projectile_scene.instantiate()
	root.add_child(cleanup_enemy_projectile)
	cleanup_enemy_projectile.global_position = Vector2(2300, 1200)
	if bool(cleanup_enemy_projectile.call("_is_outside_arena")):
		push_error("Expected enemy projectile cleanup bounds to include the expanded arena.")
		quit(1)
		return
	cleanup_enemy_projectile.global_position = Vector2(2800, 1700)
	if not bool(cleanup_enemy_projectile.call("_is_outside_arena")):
		push_error("Expected enemy projectile cleanup bounds to remove shots outside the expanded arena.")
		quit(1)
		return
	cleanup_enemy_projectile.queue_free()
	var player_projectile_scene := load("res://scenes/Projectile.tscn") as PackedScene
	var cleanup_player_projectile := player_projectile_scene.instantiate()
	root.add_child(cleanup_player_projectile)
	var player_projectile_visual := cleanup_player_projectile.get_node("Shape") as Sprite2D
	if player_projectile_visual == null or player_projectile_visual.texture == null or player_projectile_visual.texture.resource_path != "res://assets/sprites/projectiles/player_projectile_spark_64.png":
		push_error("Expected player projectile to use the stylized spark PNG.")
		quit(1)
		return
	cleanup_player_projectile.global_position = Vector2(2300, 1200)
	if bool(cleanup_player_projectile.call("_is_outside_arena")):
		push_error("Expected player projectile cleanup bounds to include the expanded arena.")
		quit(1)
		return
	cleanup_player_projectile.global_position = Vector2(2800, 1700)
	if not bool(cleanup_player_projectile.call("_is_outside_arena")):
		push_error("Expected player projectile cleanup bounds to remove shots outside the expanded arena.")
		quit(1)
		return
	cleanup_player_projectile.queue_free()

	var xp_before := int(player.get("xp"))
	var money_before := int(player.get("money"))
	main.call("_spawn_pickup", "xp", 3, player.global_position)
	main.call("_spawn_pickup", "money", 4, player.global_position)
	for pickup in main.get_tree().get_nodes_in_group("pickups"):
		var pickup_node := pickup as Node2D
		if pickup_node == null:
			continue
		var pickup_visual := pickup_node.get_node_or_null("Body") as Sprite2D
		if pickup_visual == null or pickup_visual.texture == null:
			push_error("Expected pickups to use Sprite2D texture art instead of Polygon2D placeholders.")
			quit(1)
			return
	await create_timer(0.2).timeout
	if int(player.get("xp")) <= xp_before or int(player.get("money")) <= money_before:
		push_error("Expected XP and money pickups to be collected.")
		quit(1)
		return

	var freeze_enemy := enemy_scene.instantiate()
	freeze_enemy.set("max_health", 9999.0)
	root.add_child(freeze_enemy)
	freeze_enemy.global_position = player.global_position + Vector2(420, 0)

	player.gain_xp(20)
	await process_frame
	if paused:
		push_error("Expected level-up to stay in combat until the + upgrade button is pressed.")
		quit(1)
		return
	if int(main.get("pending_level_ups")) <= 0:
		push_error("Expected level-up to queue pending upgrade choices.")
		quit(1)
		return
	var level_up_plus := main.find_child("LevelUpPlusButton", true, false) as Button
	if level_up_plus == null or level_up_plus.text == "":
		push_error("Expected level-up to show a persistent + button.")
		quit(1)
		return
	var level_up_toast := main.find_child("LevelUpToast", true, false)
	if level_up_toast == null:
		push_error("Expected level-up to play a placeholder toast animation.")
		quit(1)
		return
	var level_up_effect := main.find_child("LevelUpEffect", true, false) as Node2D
	if level_up_effect == null:
		push_error("Expected level-up to spawn a world effect around the player.")
		quit(1)
		return
	if level_up_effect.global_position.distance_to(player.global_position) > 6.0:
		push_error("Expected level-up world effect to appear around the current player.")
		quit(1)
		return
	Input.action_press("move_right")
	await process_frame
	var timer_before_level_pause := float(main.get("round_time_left"))
	var spawn_before_level_pause := int(get_nodes_in_group("enemies").size())
	var player_position_before_pause: Vector2 = player.global_position
	var enemy_position_before_pause: Vector2 = freeze_enemy.global_position
	main.call("_open_pending_level_up")
	await process_frame
	if (player.get("velocity") as Vector2).length_squared() > 0.001:
		push_error("Expected level-up pause to zero player velocity even if movement input is held.")
		quit(1)
		return
	if not paused:
		push_error("Expected pressing + to pause combat with a reward screen.")
		quit(1)
		return
	if not bool(main.call("_has_pause_reason", "level_up")):
		push_error("Expected level-up pause to be tracked by the pause stack.")
		quit(1)
		return
	await create_timer(0.2, true).timeout
	if abs(float(main.get("round_time_left")) - timer_before_level_pause) > 0.001:
		push_error("Expected gameplay timer to freeze while level-up choices are open.")
		quit(1)
		return
	if player.global_position.distance_to(player_position_before_pause) > 0.01:
		push_error("Expected player position to stay frozen during level-up pause.")
		quit(1)
		return
	if is_instance_valid(freeze_enemy) and freeze_enemy.global_position.distance_to(enemy_position_before_pause) > 0.01:
		push_error("Expected enemy position to stay frozen during level-up pause.")
		quit(1)
		return
	if int(get_nodes_in_group("enemies").size()) != spawn_before_level_pause:
		push_error("Expected enemy spawns to stop during level-up pause.")
		quit(1)
		return
	var escape_during_level_up := InputEventKey.new()
	escape_during_level_up.keycode = KEY_ESCAPE
	escape_during_level_up.pressed = true
	main.call("_input", escape_during_level_up)
	if not paused or not bool(main.call("_has_pause_reason", "level_up")):
		push_error("Expected Esc not to cancel the level-up choice pause.")
		quit(1)
		return
	if main.get("ui_layer") == null:
		push_error("Expected level-up to open a reward UI while paused.")
		quit(1)
		return
	var level_up_overlay := (main.get("ui_layer") as CanvasLayer).get_node_or_null("LevelUpOverlay")
	if level_up_overlay == null:
		push_error("Expected level-up to use an animated overlay root.")
		quit(1)
		return
	var level_up_panel := level_up_overlay.get_node_or_null("LevelUpPanel") as PanelContainer
	if level_up_panel == null:
		push_error("Expected level-up to create an animated reward panel.")
		quit(1)
		return
	var level_up_particles := level_up_overlay.get_node_or_null("LevelUpParticles")
	if level_up_particles == null or level_up_particles.get_child_count() < 20:
		push_error("Expected level-up to create burst particles and rays.")
		quit(1)
		return
	var level_up_hero := level_up_overlay.find_child("LevelUpHeroPortrait", true, false) as TextureRect
	if level_up_hero == null or level_up_hero.texture == null:
		push_error("Expected level-up screen to include the selected hero portrait.")
		quit(1)
		return
	var level_up_buttons := level_up_overlay.find_children("LevelUpRewardButton*", "Button", true, false)
	if level_up_buttons.size() != 3:
		push_error("Expected level-up to animate exactly three reward buttons.")
		quit(1)
		return
	for button_index in range(level_up_buttons.size()):
		var reward_button := level_up_buttons[button_index] as Button
		var button_rect := reward_button.get_global_rect()
		if button_rect.size.x < 250.0 or button_rect.size.y < 120.0:
			push_error("Expected level-up reward buttons to keep readable card dimensions.")
			quit(1)
			return
		if reward_button.find_child("UIIcon_*", true, false) == null:
			push_error("Expected each level-up reward button to show a stat or artifact icon.")
			quit(1)
			return
		if reward_button.get_theme_stylebox("normal") == null or reward_button.get_theme_stylebox("hover") == null:
			push_error("Expected level-up reward buttons to use stylized FantasyDisk button states.")
			quit(1)
			return
		for compare_index in range(button_index + 1, level_up_buttons.size()):
			var compare_rect := (level_up_buttons[compare_index] as Button).get_global_rect()
			if button_rect.intersects(compare_rect):
				push_error("Expected level-up reward buttons to stay separated instead of collapsing into one stack.")
				quit(1)
				return
	var loop_guard := 0
	while int(main.get("pending_level_ups")) > 0 and loop_guard < 8:
		var active_overlay := (main.get("ui_layer") as CanvasLayer).get_node_or_null("LevelUpOverlay")
		var active_buttons := active_overlay.find_children("LevelUpRewardButton*", "Button", true, false)
		if active_buttons.is_empty():
			push_error("Expected queued level-up choices to keep showing reward buttons.")
			quit(1)
			return
		(active_buttons[0] as Button).pressed.emit()
		await process_frame
		loop_guard += 1
	if int(main.get("pending_level_ups")) > 0:
		push_error("Expected all queued level-up choices to resolve.")
		quit(1)
		return
	if paused:
		push_error("Expected level-up reward flow to resume combat.")
		quit(1)
		return
	Input.action_release("move_right")
	await create_timer(1.0).timeout
	if main.find_child("LevelUpEffect", true, false) != null:
		push_error("Expected level-up world effect to clean itself up.")
		quit(1)
		return
	if main.find_child("RunResourceHud", true, false) == null or main.get("health_bar") == null or main.get("xp_bar") == null or main.get("money_label") == null:
		push_error("Expected combat HUD to be restored as compact HP/XP/money resources.")
		quit(1)
		return
	if main.get("status_label") != null or main.get("artifact_label") != null:
		push_error("Expected combat HUD to omit status/debug text labels.")
		quit(1)
		return

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	main.call("_input", escape_event)
	if not paused:
		push_error("Expected Esc to pause active combat.")
		quit(1)
		return
	var pause_menu: Node = main.get("pause_stats_menu")
	if pause_menu == null or not is_instance_valid(pause_menu):
		push_error("Expected Esc to open pause stats menu.")
		quit(1)
		return
	var run_controls := pause_menu.find_child("RunControls", true, false) as VBoxContainer
	var control_buttons := pause_menu.find_child("PauseControlButtons", true, false) as VBoxContainer
	var base_stats_list := pause_menu.find_child("BaseStatsList", true, false) as VBoxContainer
	var derived_groups := pause_menu.find_child("DerivedStatsGroups", true, false) as GridContainer
	if run_controls == null or control_buttons == null or base_stats_list == null or derived_groups == null:
		push_error("Expected pause stats menu to build left controls, base stats, and grouped derived stats.")
		quit(1)
		return
	if control_buttons.get_child_count() < 4:
		push_error("Expected pause stats menu controls to stay grouped on the left.")
		quit(1)
		return
	var pause_artifacts := pause_menu.find_child("ArtifactsList", true, false) as HFlowContainer
	if pause_artifacts == null or pause_artifacts.get_child_count() < 1:
		push_error("Expected the pause menu to show the artifacts block (icons or empty hint).")
		quit(1)
		return
	if base_stats_list.get_child_count() != UIIconRegistry.BASE_STAT_IDS.size():
		push_error("Expected base stats to sit under controls as one compact row per base stat.")
		quit(1)
		return
	if derived_groups.columns != 2 or derived_groups.get_child_count() < 5:
		push_error("Expected derived stats to be organized into compact logical groups.")
		quit(1)
		return
	var strength_row := pause_menu.find_child("BaseStatRow_strength", true, false) as Control
	var damage_chip := pause_menu.find_child("DerivedStatChip_damage", true, false) as Control
	if strength_row == null or damage_chip == null or strength_row.tooltip_text == "" or damage_chip.tooltip_text == "":
		push_error("Expected base and derived stats to expose hover tooltips.")
		quit(1)
		return
	var escape_panel := pause_menu.find_child("EscapeStatsPanelFrame", true, false) as PanelContainer
	var resume_button := pause_menu.find_child("PauseResumeButton", true, false) as Button
	var physical_group := pause_menu.find_child("DerivedStatGroup_physical_damage", true, false) as PanelContainer
	if escape_panel == null or resume_button == null or physical_group == null:
		push_error("Expected pause stats menu to expose Design kit hook nodes.")
		quit(1)
		return
	if not (escape_panel.get_theme_stylebox("panel") is StyleBoxTexture):
		push_error("Expected Escape stats panel to use Design StyleBoxTexture frame.")
		quit(1)
		return
	if not (resume_button.get_theme_stylebox("normal") is StyleBoxTexture):
		push_error("Expected Escape menu buttons to use Design StyleBoxTexture frame.")
		quit(1)
		return
	if not (strength_row.get_theme_stylebox("panel") is StyleBoxTexture) or not (damage_chip.get_theme_stylebox("panel") is StyleBoxTexture) or not (physical_group.get_theme_stylebox("panel") is StyleBoxTexture):
		push_error("Expected base rows, derived chips, and derived groups to use Design StyleBoxTexture frames.")
		quit(1)
		return
	var tooltip := pause_menu.call("_make_custom_tooltip", strength_row.tooltip_text) as PanelContainer
	if tooltip == null or not (tooltip.get_theme_stylebox("panel") is StyleBoxTexture) or tooltip.custom_minimum_size.x > 430.0:
		push_error("Expected custom stat tooltip to use Design frame and stay clamped to target width.")
		quit(1)
		return
	tooltip.queue_free()
	var stat_icons := pause_menu.find_children("UIIcon_*", "Control", true, false)
	if stat_icons.size() < UIIconRegistry.BASE_STAT_IDS.size() + UIIconRegistry.DERIVED_ATTRIBUTE_IDS.size():
		push_error("Expected pause stats menu to show icons for base stats and derived attributes.")
		quit(1)
		return
	main.call("_input", escape_event)
	if paused or main.get("pause_stats_menu") != null:
		push_error("Expected second Esc to close pause stats menu and resume combat.")
		quit(1)
		return

	main.set("round_time_left", 0.05)
	await create_timer(0.2).timeout
	if bool(main.get("combat_active")):
		push_error("Expected combat to finish when the timer ends.")
		quit(1)
		return
	if int(main.get("route_stage")) != 1:
		push_error("Expected route stage to advance after normal victory.")
		quit(1)
		return
	# Новый победный флоу: баннер «Победа» -> окно докачки атрибутов -> карта.
	var victory_banner := main.find_child("VictoryBanner", true, false) as Button
	if victory_banner == null:
		push_error("Expected the victory banner overlay after a won battle.")
		quit(1)
		return
	# Пополняем кошелек снапшота: проверяем механику покупки, а не экономику дропа.
	var run_snapshot: Dictionary = main.get("run_player_snapshot")
	run_snapshot["money"] = int(run_snapshot.get("money", 0)) + 200
	victory_banner.pressed.emit()
	await process_frame
	var attribute_panel := main.find_child("AttributeShopPanel", true, false)
	if attribute_panel == null:
		push_error("Expected the attribute purchase window after the victory banner.")
		quit(1)
		return
	var attribute_offers := main.find_child("AttributeOffers", true, false) as VBoxContainer
	if attribute_offers == null or attribute_offers.get_child_count() != 2:
		push_error("Expected exactly two attribute offers in the post-battle window.")
		quit(1)
		return
	var reroll_button := main.find_child("AttributeRerollButton", true, false) as Button
	if reroll_button == null:
		push_error("Expected the attribute window to include a reroll button.")
		quit(1)
		return
	# Покупка: стат растет, деньги списываются.
	var snapshot: Dictionary = main.get("run_player_snapshot")
	var stats_before: Dictionary = (snapshot.get("stats", {}) as Dictionary).duplicate(true)
	var attr_money_before := int(main.ui._run_money())
	var first_offer := attribute_offers.get_child(0) as Button
	var offered_stat := str(first_offer.name).replace("AttributeOffer_", "")
	if first_offer.disabled:
		push_error("Expected the attribute offer to be affordable in the test run (money %d)." % attr_money_before)
		quit(1)
		return
	first_offer.pressed.emit()
	await process_frame
	snapshot = main.get("run_player_snapshot")
	var stats_after: Dictionary = snapshot.get("stats", {})
	if float(stats_after.get(offered_stat, 0.0)) != float(stats_before.get(offered_stat, 0.0)) + 1.0:
		push_error("Expected buying an attribute to raise %s by 1." % offered_stat)
		quit(1)
		return
	if int(main.ui._run_money()) >= attr_money_before:
		push_error("Expected the attribute purchase to spend money.")
		quit(1)
		return
	if abs(float(main.call("_current_round_duration")) - 33.0) > 0.01:
		push_error("Expected next round duration to increase by 3 seconds per stage.")
		quit(1)
		return
	if not get_nodes_in_group("arena_obstacles").is_empty():
		push_error("Expected arena obstacles to be cleaned up after combat.")
		quit(1)
		return
	if main.find_child("RunResourceHud", true, false) == null or main.get("health_bar") == null or main.get("xp_bar") == null or main.get("money_label") == null:
		push_error("Expected route map to keep a compact run HUD without a click-blocking overlay layer.")
		quit(1)
		return
	var route_button := main.find_child("RouteNode_*", true, false) as Button
	if route_button == null or route_button.tooltip_text == "":
		push_error("Expected vertical route nodes to expose readable tooltips.")
		quit(1)
		return

	_test_noncombat_nodes(main)
	_test_stat_artifact_recording()
	_test_berserk_weapon_configs()
	_test_class_weapon_configs()
	_test_all_weapon_variants_equip()
	await _test_weapon_effect_cleanup()
	await _test_victory_flow(main)
	await _test_elite_flow(main_scene)
	await _test_debug_free_pick(main_scene)
	await _test_codex_screen(main_scene)
	await _test_escape_navigation(main_scene)
	await _test_economy_tiers_and_fab(main_scene)
	await _test_ascension_difficulty_ladder(main_scene)
	await _test_class_relevance_and_offer_fixation(main_scene)
	_test_settings_persistence_and_audio()
	await _test_full_attribute_wiring()
	await _test_all_nine_classes()
	await _test_elite_unique_attacks()
	await _test_weapon_aiming()
	await _test_class_weapon_rework()
	await _test_unique_class_identity_patterns()
	await _test_universal_attribute_interpretations()
	_test_class_budget_profiles()
	await _test_enemy_stage_scaling_and_elite_rewards(main_scene)
	await _test_ultimate_framework()
	await _test_death_flow(main_scene)

	print("Runtime smoke test passed.")
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


func _test_route_map_start_selection(main_scene: PackedScene) -> void:
	var route_main := main_scene.instantiate()
	root.add_child(route_main)
	await process_frame
	route_main.set("selected_character_id", "berserk")
	route_main.set("selected_weapon_id", "sword")
	route_main.call("_show_battle_map")
	await process_frame
	await process_frame

	var route_scroll := route_main.find_child("RouteMapScroll", true, false) as ScrollContainer
	var route_map := route_main.find_child("VerticalRouteMap", true, false) as Control
	if route_scroll == null or route_map == null:
		push_error("Expected start route selection to use a scrollable map.")
		quit(1)
		return

	route_scroll.scroll_vertical = 0
	route_scroll.scroll_horizontal = 0
	await process_frame

	var route_nodes: Array = route_main.get("route_nodes")
	var battle_index := -1
	for branch_index in range((route_nodes[0] as Array).size()):
		var route_node: Dictionary = route_nodes[0][branch_index]
		if str(route_node.get("type", "")) == "battle":
			battle_index = branch_index
			break
	if battle_index < 0:
		push_error("Expected start row to include a battle node for click-through testing.")
		quit(1)
		return

	var start_button := route_main.find_child("RouteNode_battle_0_%d" % battle_index, true, false) as Button
	if start_button == null or start_button.disabled:
		push_error("Expected start battle route node to be enabled and clickable.")
		quit(1)
		return
	if start_button.tooltip_text == "":
		push_error("Expected start battle route node to keep a readable tooltip.")
		quit(1)
		return

	var start_route_node: Dictionary = route_nodes[0][battle_index]
	var start_scroll_position := Vector2(route_scroll.scroll_horizontal, route_scroll.scroll_vertical)
	_send_route_node_mouse_press(route_main, start_button, route_scroll, battle_index, start_route_node)
	_send_route_node_mouse_drag(route_main, start_button, route_scroll, battle_index, start_route_node, Vector2(0.0, -96.0))
	_send_route_node_mouse_release(route_main, start_button, route_scroll, battle_index, start_route_node)
	await process_frame
	var selected_indices: Array = route_main.get("route_selected_indices")
	if not selected_indices.is_empty() and int(selected_indices[0]) == battle_index:
		push_error("Expected dragging a route node to pan without selecting it.")
		quit(1)
		return
	if bool(route_main.get("combat_active")):
		push_error("Expected dragging a route node to avoid starting combat.")
		quit(1)
		return
	var end_scroll_position := Vector2(route_scroll.scroll_horizontal, route_scroll.scroll_vertical)
	if end_scroll_position == start_scroll_position:
		push_error("Expected dragging a route node to pan the scroll container.")
		quit(1)
		return

	_send_route_node_mouse_press(route_main, start_button, route_scroll, battle_index, start_route_node)
	_send_route_node_mouse_release(route_main, start_button, route_scroll, battle_index, start_route_node)
	await process_frame
	selected_indices = route_main.get("route_selected_indices")
	if selected_indices.is_empty() or int(selected_indices[0]) != battle_index:
		push_error("Expected clicking the start route node to record the selected branch.")
		quit(1)
		return
	if not bool(route_main.get("combat_active")) or str(route_main.get("current_combat_type")) != "battle":
		push_error("Expected clicking the start battle route node to start combat.")
		quit(1)
		return

	route_main.queue_free()
	await process_frame


func _test_event_route_node_click(main_scene: PackedScene) -> void:
	var route_main := main_scene.instantiate()
	root.add_child(route_main)
	await process_frame
	route_main.set("selected_character_id", "berserk")
	route_main.set("selected_weapon_id", "sword")
	route_main.set("route_stage", 0)
	route_main.set("route_nodes", [
		[
			{"type": "event", "name": "Event 1: Test Stone", "event_id": "hot_spring", "row": 0, "branch": 0, "next_branches": [0]},
			{"type": "battle", "name": "Battle 1: Test Road", "row": 0, "branch": 1, "next_branches": [0]},
		],
		[
			{"type": "battle", "name": "Battle 2: Test Road", "row": 1, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "battle", "name": "Battle 3: Test Road", "row": 2, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "boss", "name": "Rift Warden", "boss_id": "rift_warden", "row": 3, "branch": 0},
		],
	])
	route_main.call("_show_battle_map")
	await process_frame
	await process_frame

	var route_scroll := route_main.find_child("RouteMapScroll", true, false) as ScrollContainer
	var event_button := route_main.find_child("RouteNode_event_0_0", true, false) as Button
	if route_scroll == null or event_button == null or event_button.disabled:
		push_error("Expected event route node to be enabled and clickable from the start row.")
		quit(1)
		return
	if event_button.tooltip_text == "":
		push_error("Expected event route node to expose a hover tooltip.")
		quit(1)
		return

	var route_nodes: Array = route_main.get("route_nodes")
	var event_route_node: Dictionary = route_nodes[0][0]
	_send_route_node_mouse_press(route_main, event_button, route_scroll, 0, event_route_node)
	_send_route_node_mouse_release(route_main, event_button, route_scroll, 0, event_route_node)
	await process_frame

	var event_choice := route_main.find_child("EventChoiceButton0", true, false) as Button
	if event_choice == null:
		push_error("Expected clicking an event route node to open the event choice screen.")
		quit(1)
		return
	if not _has_screen_background(route_main, "event"):
		push_error("Expected event screen to include an event background or fallback layer.")
		quit(1)
		return

	event_choice.emit_signal("pressed")
	await process_frame
	if int(route_main.get("route_stage")) != 1:
		push_error("Expected choosing an event option to advance the route stage.")
		quit(1)
		return
	if route_main.find_child("RouteMapScreen", true, false) == null:
		push_error("Expected choosing an event option to return to the route map.")
		quit(1)
		return

	route_main.queue_free()
	await process_frame


func _test_random_event_data_and_outcomes(main_scene: PackedScene) -> void:
	if EventData.RANDOM_EVENTS.size() < 10:
		_fail("Expected at least 10 random event scenarios.")
		return
	var ids := {}
	var combat_outcomes := 0
	var reward_outcomes := 0
	var rest_outcomes := 0
	var check_outcomes := 0
	for event in EventData.RANDOM_EVENTS:
		var event_id := str(event.get("id", ""))
		if event_id == "" or ids.has(event_id):
			_fail("Expected random event ids to be non-empty and unique.")
			return
		ids[event_id] = true
		if str(event.get("title", "")) == "" or str(event.get("story", "")).length() < 40:
			_fail("Expected event %s to include title and story text." % event_id)
			return
		var choices: Array = event.get("choices", [])
		if choices.size() < 2:
			_fail("Expected event %s to include at least two choices." % event_id)
			return
		for choice in choices:
			if choice.has("combat") or _choice_nested_outcome_has(choice, "combat"):
				combat_outcomes += 1
			if choice.has("random_artifact") or choice.has("reward") or choice.has("money") or _choice_nested_outcome_has(choice, "random_artifact"):
				reward_outcomes += 1
			if choice.has("heal_percent"):
				rest_outcomes += 1
			if choice.has("check"):
				check_outcomes += 1
	if combat_outcomes < 3 or reward_outcomes < 3 or rest_outcomes < 1 or check_outcomes < 2:
		_fail("Expected random events to cover combat, reward, rest and attribute-check outcomes.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var used := []
	for _index in range(EventData.RANDOM_EVENTS.size()):
		var picked: Dictionary = EventData.pick_event(used, rng)
		var picked_id := str(picked.get("id", ""))
		if used.has(picked_id):
			_fail("Expected event picker to avoid repeats within an act.")
			return
		used.append(picked_id)

	var event_main := main_scene.instantiate()
	root.add_child(event_main)
	await process_frame
	event_main.set("selected_character_id", "berserk")
	event_main.set("selected_weapon_id", "sword")
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var event_player := player_scene.instantiate()
	root.add_child(event_player)
	event_player.configure_character("berserk", "sword")
	event_player.set("money", 500)
	var stats: Dictionary = event_player.get("stats")
	for stat_id in ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]:
		stats[stat_id] = 12
	event_player.set("stats", stats)
	event_main.combat._store_player_snapshot(event_player)
	event_player.queue_free()

	var checked_success := false
	var checked_failure := false
	var checked_combat := false
	for event in EventData.RANDOM_EVENTS:
		for choice in (event.get("choices", []) as Array):
			if choice.has("check") and not checked_success:
				var high_player: Node = event_main.combat._snapshot_player_for_menu()
				var success_outcome: Dictionary = event_main.ui._resolve_event_choice_outcome(choice, high_player)
				high_player.queue_free()
				if not bool(success_outcome.get("check_passed", false)):
					_fail("Expected high-stat event check to pass for %s." % choice.get("id", ""))
					event_main.queue_free()
					return
				checked_success = true
			if choice.has("check") and not checked_failure:
				var low_player: Node = event_main.combat._snapshot_player_for_menu()
				var low_stats: Dictionary = low_player.get("stats")
				var check: Dictionary = choice.get("check", {})
				low_stats[str(check.get("stat", "knowledge"))] = 0
				low_player.set("stats", low_stats)
				var failure_outcome: Dictionary = event_main.ui._resolve_event_choice_outcome(choice, low_player)
				low_player.queue_free()
				if bool(failure_outcome.get("check_passed", true)):
					_fail("Expected low-stat event check to fail for %s." % choice.get("id", ""))
					event_main.queue_free()
					return
				checked_failure = true
			if (choice.has("combat") or _choice_nested_outcome_has(choice, "combat")) and not checked_combat:
				var combat_choice: Dictionary = choice.duplicate(true)
				if not combat_choice.has("combat"):
					combat_choice["combat"] = {"type": "battle", "enemy_health_multiplier": 1.05}
				var started_combat: bool = event_main.ui._apply_event_choice(combat_choice)
				await process_frame
				if not started_combat or not bool(event_main.get("combat_active")):
					_fail("Expected combat event outcome to start combat.")
					event_main.queue_free()
					return
				event_main.combat._end_combat(true)
				await process_frame
				if bool(event_main.get("combat_active")) or not (event_main.get("pending_event_combat") as Dictionary).is_empty():
					_fail("Expected event combat to clean up pending combat payload after victory.")
					event_main.queue_free()
					return
				checked_combat = true
			if checked_success and checked_failure and checked_combat:
				break
		if checked_success and checked_failure and checked_combat:
			break
	if not checked_success or not checked_failure or not checked_combat:
		_fail("Expected random event tests to exercise checks and combat outcome.")
		event_main.queue_free()
		return
	event_main.queue_free()
	await process_frame


func _choice_nested_outcome_has(choice: Dictionary, key: String) -> bool:
	for branch_id in ["success", "failure", "post_combat"]:
		var branch: Dictionary = choice.get(branch_id, {})
		if branch.has(key):
			return true
	for outcome in (choice.get("random_outcomes", []) as Array):
		if (outcome as Dictionary).has(key):
			return true
	return false


func _send_route_node_mouse_press(main: Node, button: Button, scroll: ScrollContainer, branch_index: int, route_node: Dictionary) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	main.call("_handle_route_node_input", button, press, scroll, 0, branch_index, route_node)


func _send_route_node_mouse_release(main: Node, button: Button, scroll: ScrollContainer, branch_index: int, route_node: Dictionary) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	main.call("_handle_route_node_input", button, release, scroll, 0, branch_index, route_node)


func _send_route_node_mouse_drag(main: Node, button: Button, scroll: ScrollContainer, branch_index: int, route_node: Dictionary, relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	main.call("_handle_route_node_input", button, motion, scroll, 0, branch_index, route_node)


func _test_arena_generation(main: Node, player: Node) -> void:
	var backgrounds := get_nodes_in_group("arena_backgrounds")
	if backgrounds.is_empty():
		push_error("Expected combat arena to create a background layer.")
		quit(1)
		return
	var background := backgrounds[0] as Sprite2D
	if background == null or background.texture == null or not background.texture.resource_path.begins_with("res://assets/backgrounds/"):
		push_error("Expected arena background to use assets/backgrounds.")
		quit(1)
		return
	var rendered_size := background.texture.get_size() * background.scale
	if abs(rendered_size.x - EXPECTED_ARENA_SIZE.x) > 1.0 or abs(rendered_size.y - EXPECTED_ARENA_SIZE.y) > 1.0:
		push_error("Expected arena background to stretch to map boundaries.")
		quit(1)
		return
	if background.position.distance_to(EXPECTED_ARENA_CENTER) > 1.0:
		push_error("Expected arena background to be centered on the 2K map.")
		quit(1)
		return

	if get_nodes_in_group("arena_boundaries").size() < 4:
		push_error("Expected physical arena boundaries.")
		quit(1)
		return
	if get_nodes_in_group("arena_border_visuals").is_empty():
		push_error("Expected visible arena border to show map bounds.")
		quit(1)
		return

	var columns := get_nodes_in_group("arena_columns")
	var pits := get_nodes_in_group("arena_pits")
	if not columns.is_empty() or not pits.is_empty():
		push_error("Expected arena columns and pits to be disabled in the current build.")
		quit(1)
		return

	var ground_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var ground_enemy := ground_scene.instantiate()
	root.add_child(ground_enemy)
	var flying_scene := main.get("flying_enemy_scene") as PackedScene
	var flying_enemy := flying_scene.instantiate()
	root.add_child(flying_enemy)
	await process_frame

	if bool(ground_enemy.get("is_flying")):
		push_error("Expected base melee enemy to be ground enemy.")
		quit(1)
		return
	if int(ground_enemy.get("collision_mask")) & 64 != 0:
		push_error("Expected ground enemy collision mask to ignore disabled pit layer.")
		quit(1)
		return
	if not bool(flying_enemy.get("is_flying")):
		push_error("Expected flying enemy variant to set is_flying.")
		quit(1)
		return
	if int(flying_enemy.get("collision_mask")) & 64 != 0:
		push_error("Expected flying enemy collision mask to ignore disabled pit layer.")
		quit(1)
		return
	if int(flying_enemy.get("collision_mask")) & 32 == 0:
		push_error("Expected flying enemy collision mask to include solid obstacles.")
		quit(1)
		return

	var melee_weight := float(main.call("_spawn_weight_for_scene", ground_scene))
	var shooter_weight := float(main.call("_spawn_weight_for_scene", main.get("shooter_enemy_scene")))
	if shooter_weight >= melee_weight:
		push_error("Expected shooter spawn weight to be lower than melee spawn weight.")
		quit(1)
		return
	var early_cap := int(main.call("_active_enemy_cap"))
	if early_cap < 12 or early_cap > 22:
		push_error("Expected early active enemy cap to leave room for maneuver.")
		quit(1)
		return
	main.set("spawn_wave_index", 8)
	var later_cap := int(main.call("_active_enemy_cap"))
	if later_cap <= early_cap:
		push_error("Expected active enemy cap to grow by wave number.")
		quit(1)
		return
	main.set("spawn_wave_index", 1)
	main.call("_choose_wave_spawn_edges")
	if (main.get("active_spawn_edges") as Array).is_empty() or (main.get("active_spawn_edges") as Array).size() > 2:
		push_error("Expected each wave to choose one or two active spawn sides.")
		quit(1)
		return

	var spawn_position: Vector2 = main.call("_random_spawn_position")
	if spawn_position.distance_to(player.global_position) < 320.0:
		push_error("Expected spawn position to avoid player proximity.")
		quit(1)
		return
	if spawn_position.x < 0.0 or spawn_position.x > EXPECTED_ARENA_SIZE.x or spawn_position.y < 0.0 or spawn_position.y > EXPECTED_ARENA_SIZE.y:
		push_error("Expected spawn position to stay inside the 2K arena bounds.")
		quit(1)
		return
	main.set("active_spawn_edges", [1])
	var right_edge_spawn: Vector2 = main.call("_random_edge_spawn_position")
	if right_edge_spawn.x < EXPECTED_ARENA_SIZE.x - 100.0:
		push_error("Expected right-edge spawns to use the new arena width.")
		quit(1)
		return
	main.set("active_spawn_edges", [2])
	var bottom_edge_spawn: Vector2 = main.call("_random_edge_spawn_position")
	if bottom_edge_spawn.y < EXPECTED_ARENA_SIZE.y - 100.0:
		push_error("Expected bottom-edge spawns to use the new arena height.")
		quit(1)
		return

	ground_enemy.queue_free()
	flying_enemy.queue_free()


func _test_noncombat_nodes(main: Node) -> void:
	main.set("route_stage", 1)
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var shop_player := player_scene.instantiate()
	root.add_child(shop_player)
	shop_player.configure_character("berserk", "sword")
	shop_player.set("money", 300)
	main.call("_store_player_snapshot", shop_player)
	shop_player.queue_free()
	main.call("_show_shop_screen")
	var shop_screen := main.find_child("ShopScreen", true, false) as Control
	if shop_screen == null:
		push_error("Expected shop to render as an inline full-screen shop screen.")
		quit(1)
		return
	var inline_items := main.find_child("ShopInlineItems", true, false) as GridContainer
	if inline_items == null or inline_items.columns != 2:
		push_error("Expected shop offers to sit in a 2-column grid on the parchment wall.")
		quit(1)
		return
	var parchment_wall := main.find_child("ShopParchmentWall", true, false) as Control
	if parchment_wall == null or parchment_wall.anchor_left < 0.45 or parchment_wall.anchor_right > 0.84:
		push_error("Expected the shop grid to be anchored to the empty parchment wall zone.")
		quit(1)
		return
	var first_shop_button := main.find_child("ShopItemButton0", true, false) as Button
	if first_shop_button == null or first_shop_button.text != "" or first_shop_button.tooltip_text == "":
		push_error("Expected shop item cards to show icon/price only and move descriptions into hover tooltip.")
		quit(1)
		return
	var first_shop_icon := first_shop_button.find_child("ShopItemIcon", true, false) as TextureRect
	var first_shop_price := first_shop_button.find_child("ShopItemPrice", true, false) as Label
	if first_shop_icon == null or first_shop_icon.texture == null or first_shop_price == null or not first_shop_price.text.ends_with("g"):
		push_error("Expected every inline shop offer to include a texture icon and visible price.")
		quit(1)
		return
	var shop_items: Array = main.get("current_shop_items")
	if shop_items.size() < 2:
		push_error("Expected shop to offer multiple purchasable items.")
		quit(1)
		return
	var expected_first_icon_path := ""
	var first_shop_item: Dictionary = shop_items[0]
	if str(first_shop_item.get("kind", "")) == "artifact" or not str(first_shop_item.get("id", "")).begins_with("shop_"):
		expected_first_icon_path = "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % str(first_shop_item.get("id", ""))
	else:
		expected_first_icon_path = "res://assets/sprites/ui/icons/shop/shop_%s.png" % str(first_shop_item.get("id", ""))
	if first_shop_icon.texture.resource_path != expected_first_icon_path:
		push_error("Expected inline shop to use the dedicated Design icon %s, got %s." % [expected_first_icon_path, first_shop_icon.texture.resource_path])
		quit(1)
		return
	if not (first_shop_button.get_theme_stylebox("normal") is StyleBoxTexture) or not (first_shop_button.get_theme_stylebox("hover") is StyleBoxTexture):
		push_error("Expected inline shop item slots to use Design StyleBoxTexture frames.")
		quit(1)
		return
	var first_price_badge := first_shop_button.find_child("ShopPriceBadge", true, false) as PanelContainer
	if first_price_badge == null or not (first_price_badge.get_theme_stylebox("panel") is StyleBoxTexture):
		push_error("Expected inline shop price badge to use the Design price frame.")
		quit(1)
		return
	if not bool(main.call("_buy_shop_item_at", 0)):
		push_error("Expected first shop purchase to succeed without leaving shop.")
		quit(1)
		return
	if not bool(main.get("current_shop_purchased")[0]):
		push_error("Expected bought shop item to be marked as purchased.")
		quit(1)
		return
	var purchased_overlay := main.find_child("ShopItemStateOverlay", true, false) as PanelContainer
	if purchased_overlay == null:
		push_error("Expected bought shop item to expose a purchased state overlay.")
		quit(1)
		return
	if not (purchased_overlay.get_theme_stylebox("panel") is StyleBoxTexture):
		push_error("Expected bought shop item overlay to use the Design purchased/unavailable frame.")
		quit(1)
		return
	if not bool(main.call("_buy_shop_item_at", 1)):
		push_error("Expected second shop purchase in the same visit to succeed.")
		quit(1)
		return
	if main.get("hud_layer") == null:
		push_error("Expected shop screen to keep the compact run HUD.")
		quit(1)
		return
	if not _has_screen_background(main, "shop"):
		push_error("Expected shop screen to include a shop background or fallback layer.")
		quit(1)
		return
	main.call("_show_rest_screen")
	if not _has_screen_background(main, "campfire"):
		push_error("Expected rest screen to include a campfire background or fallback layer.")
		quit(1)
		return
	main.call("_apply_event_choice", {"title": "Rest", "description": "Recover", "heal_percent": 0.25})
	main.call("_show_upgrade_screen")
	main.call("_apply_reward_to_run", {"title": "Test Upgrade", "description": "+defense", "mods": {"defense_flat": 0.04}})


func _has_screen_background(node: Node, screen_background_id: String) -> bool:
	return node.find_child("ScreenBackground_%s" % screen_background_id, true, false) != null \
		or node.find_child("ScreenBackgroundFallback_%s" % screen_background_id, true, false) != null


func _test_stat_artifact_recording() -> void:
	var reward_pool: Array = load("res://scripts/progression_data.gd").reward_pool()
	var stat_only_artifact := {}
	for reward in reward_pool:
		if reward.get("kind", "") == "artifact" and reward.has("stats") and not reward.has("mods"):
			stat_only_artifact = reward
			break
	if stat_only_artifact.is_empty():
		push_error("Expected at least one stat-only artifact reward.")
		quit(1)
		return

	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var reward_player := player_scene.instantiate()
	root.add_child(reward_player)
	reward_player.configure_character("berserk")
	reward_player.equip_weapon("sword")
	reward_player.apply_reward(stat_only_artifact)
	if (reward_player.get("artifacts") as Array).is_empty():
		push_error("Expected stat-only artifacts to be recorded on the player.")
		quit(1)
		return
	reward_player.queue_free()


func _test_berserk_weapon_configs() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var expected := {
		"sword": {"shape": "frustum", "scene": "TwoHandedSword", "sprite": "res://assets/sprites/weapons/two_handed_sword.png"},
		"axe": {"shape": "sweep", "scene": "TwoHandedAxe", "sprite": "res://assets/sprites/weapons/two_handed_axe.png"},
		"hammer": {"shape": "circle", "scene": "TwoHandedHammer", "sprite": "res://assets/sprites/weapons/two_handed_hammer.png"},
	}

	var base_player := player_scene.instantiate()
	root.add_child(base_player)
	base_player.configure_character("berserk")
	if _find_player_weapon(base_player) != null:
		push_error("Expected base Berserk to spawn without a default weapon.")
		quit(1)
		return
	base_player.queue_free()

	for weapon_id in expected.keys():
		var player := player_scene.instantiate()
		root.add_child(player)
		player.configure_character("berserk")
		player.equip_weapon(weapon_id)
		var weapon := _find_player_weapon(player)
		if weapon == null:
			push_error("Expected Berserk weapon for %s." % weapon_id)
			quit(1)
			return
		if weapon.name != expected[weapon_id]["scene"] or weapon.get_parent().name != "WeaponSocket":
			push_error("Expected %s to attach its own weapon scene to WeaponSocket." % weapon_id)
			quit(1)
			return
		if str(weapon.get("attack_shape")) != expected[weapon_id]["shape"]:
			push_error("Expected %s shape to match config." % weapon_id)
			quit(1)
			return
		var weapon_visual := weapon.get_node_or_null("WeaponVisual") as Sprite2D
		if weapon_visual == null or weapon_visual.texture == null or weapon_visual.texture.resource_path != expected[weapon_id]["sprite"]:
			push_error("Expected %s to use its weapon sprite." % weapon_id)
			quit(1)
			return
		player.queue_free()


func _test_class_weapon_configs() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var expected := {
		"dark_mage": {
			"dark_book": {"scene": "DarkBook", "mode": "aoe_projectile", "sprite": "res://assets/sprites/weapons/dark_book.png"},
			"cursed_skull": {"scene": "CursedSkull", "mode": "homing_curse", "sprite": "res://assets/sprites/weapons/cursed_skull.png"},
			"dark_wand": {"scene": "DarkWand", "mode": "beam", "sprite": "res://assets/sprites/weapons/dark_wand.png"},
		},
		"guitarist": {
			"electric_guitar": {"scene": "ElectricGuitar", "mode": "sound_wave", "sprite": "res://assets/sprites/weapons/electric_guitar.png"},
			"bass_guitar": {"scene": "BassGuitar", "mode": "pulse", "sprite": "res://assets/sprites/weapons/bass_guitar.png"},
			"sound_amp": {"scene": "SoundAmp", "mode": "amp", "sprite": "res://assets/sprites/weapons/sound_amp.png"},
		},
	}

	for character_id in expected.keys():
		for weapon_id in expected[character_id].keys():
			var player := player_scene.instantiate()
			root.add_child(player)
			player.configure_character(character_id, weapon_id)
			var weapon := _find_player_weapon(player)
			var weapon_expected: Dictionary = expected[character_id][weapon_id]
			if weapon == null:
				push_error("Expected %s/%s to attach a weapon scene." % [character_id, weapon_id])
				quit(1)
				return
			if weapon.name != weapon_expected["scene"] or weapon.get_parent().name != "WeaponSocket":
				push_error("Expected %s to attach to WeaponSocket." % weapon_id)
				quit(1)
				return
			if str(weapon.get("attack_mode")) != weapon_expected["mode"]:
				push_error("Expected %s attack mode to match config." % weapon_id)
				quit(1)
				return
			var weapon_visual := weapon.get_node_or_null("WeaponVisual") as Sprite2D
			if weapon_visual == null or weapon_visual.texture == null or weapon_visual.texture.resource_path != weapon_expected["sprite"]:
				push_error("Expected %s to use its weapon sprite." % weapon_id)
				quit(1)
				return
			player.queue_free()


func _test_all_weapon_variants_equip() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var expected_weapon_ids := {
		"berserk": ["sword", "axe", "hammer"],
		"dark_mage": ["dark_book", "cursed_skull", "dark_wand"],
		"guitarist": ["electric_guitar", "bass_guitar", "sound_amp"],
		"assassin": ["chakrams", "shadow_daggers", "venom_wire"],
		"ranger": ["moon_crossbow", "storm_longbow", "hunter_trap"],
		"doctor": ["restore_potion", "plague_syringe", "bone_saw"],
		"chemist": ["blast_powder", "acid_flask", "homunculus_vial"],
		"knight": ["long_spear", "tower_shield", "holy_flail"],
		"druid": ["summon_amulet", "briar_staff", "raven_totem"],
	}
	for character_id in expected_weapon_ids.keys():
		var weapon_ids: Array = ProgressionData.weapon_ids(character_id)
		if weapon_ids.size() != 3:
			_fail("Expected %s to have exactly 3 selectable weapons." % character_id)
			return
		for expected_id in expected_weapon_ids[character_id]:
			if not weapon_ids.has(expected_id):
				_fail("Expected %s to expose weapon %s." % [character_id, expected_id])
				return
			var config: Dictionary = ProgressionData.weapon(character_id, expected_id)
			if str(config.get("scene_path", "")) == "" or not ResourceLoader.exists(str(config["scene_path"])):
				_fail("Expected %s/%s scene_path to exist." % [character_id, expected_id])
				return
			var player := player_scene.instantiate()
			root.add_child(player)
			player.configure_character(character_id, expected_id)
			var weapon := _find_player_weapon(player)
			if weapon == null:
				_fail("Expected %s/%s to equip a weapon node." % [character_id, expected_id])
				return
			if str(weapon.get("weapon_id")) != expected_id:
				_fail("Expected equipped weapon_id %s, got %s." % [expected_id, str(weapon.get("weapon_id"))])
				return
			if config.has("attack_mode") and weapon.get("attack_mode") != null and str(weapon.get("attack_mode")) != str(config["attack_mode"]):
				_fail("Expected %s attack_mode to match config." % expected_id)
				return
			if config.has("attack_shape") and weapon.get("attack_shape") != null and str(weapon.get("attack_shape")) != str(config["attack_shape"]):
				_fail("Expected %s attack_shape to match config." % expected_id)
				return
			var weapon_visual := weapon.get_node_or_null("WeaponVisual") as Sprite2D
			if weapon_visual == null or weapon_visual.texture == null:
				_fail("Expected %s/%s to have a visible WeaponVisual texture." % [character_id, expected_id])
				return
			player.queue_free()


func _test_weapon_effect_cleanup() -> void:
	for effect in get_nodes_in_group("player_weapon_effects"):
		if is_instance_valid(effect):
			effect.queue_free()
	await process_frame

	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	player.configure_character("guitarist", "sound_amp")
	var weapon := _find_player_weapon(player)
	if weapon == null:
		push_error("Expected sound amp weapon to attach before cleanup test.")
		quit(1)
		return
	weapon.call("_fire_amp", player, Vector2.RIGHT)
	await process_frame
	if get_nodes_in_group("player_weapon_effects").is_empty():
		push_error("Expected sound amp to register temporary weapon effects.")
		quit(1)
		return

	player.equip_weapon("electric_guitar")
	if not get_nodes_in_group("player_weapon_effects").is_empty():
		var leftover_names := []
		for effect in get_nodes_in_group("player_weapon_effects"):
			leftover_names.append(str(effect.name))
		push_error("Expected switching Guitarist weapons to clean up amp/effect nodes. Leftover: %s" % ", ".join(leftover_names))
		quit(1)
		return
	await process_frame
	player.queue_free()
	await process_frame


func _test_victory_flow(main: Node) -> void:
	paused = false
	main.set("route_stage", 3)
	main.call("_start_combat", true)
	await process_frame
	var boss := get_first_node_in_group("bosses")
	if boss == null:
		push_error("Expected boss fight to spawn a boss.")
		quit(1)
		return
	if float(boss.get("max_health")) < 550.0:
		push_error("Expected boss to have much higher final encounter health.")
		quit(1)
		return
	if not boss.has_meta("boss_behavior"):
		push_error("Expected boss to expose a unique boss behavior flag.")
		quit(1)
		return
	if float(boss.get("shield_damage_reduction")) >= 1.0 or float(boss.get("dodge_chance")) <= 0.0:
		push_error("Expected boss to expose shield and dodge mechanics.")
		quit(1)
		return
	var boss_health_bar := boss.get_node_or_null("HealthBar")
	if boss_health_bar == null:
		push_error("Expected boss to carry an overhead health bar node.")
		quit(1)
		return
	if absf(float(boss_health_bar.get("max_value")) - float(boss.get("max_health"))) > 0.01:
		push_error("Expected boss health bar max value to match scaled boss max health.")
		quit(1)
		return
	var boss_phase_markers: Array = boss.get_meta("boss_phase_markers", [])
	if boss_phase_markers.size() < 2 or not boss_health_bar.has_meta("phase_markers"):
		push_error("Expected boss to expose HP phase markers for the uber-boss encounter.")
		quit(1)
		return
	boss.set("health", float(boss.get("max_health")) * 0.64)
	boss.call("_update_boss_phase")
	if int(boss.get("boss_phase")) != 2 or int(boss.get_meta("boss_phase", 0)) != 2:
		push_error("Expected boss to enter phase 2 below 66%% HP.")
		quit(1)
		return
	boss.set("health", float(boss.get("max_health")) * 0.30)
	boss.call("_update_boss_phase")
	if int(boss.get("boss_phase")) != 3 or int(boss.get_meta("boss_phase", 0)) != 3:
		push_error("Expected boss to enter phase 3 below 33%% HP.")
		quit(1)
		return
	boss.set("dodge_chance", 0.0)
	boss.set("shield_active", false)
	boss.take_damage(25.0)
	if float(boss_health_bar.get("value")) >= float(boss_health_bar.get("max_value")):
		push_error("Expected boss health bar to decrease after damage.")
		quit(1)
		return
	if absf(float(boss_health_bar.get("value")) - float(boss.get("health"))) > 0.01:
		push_error("Expected boss health bar value to match current boss health after damage.")
		quit(1)
		return
	boss.take_damage(99999.0)
	await process_frame
	await process_frame
	if bool(main.get("combat_active")):
		push_error("Expected boss death to end combat.")
		quit(1)
		return
	if int(main.get("meta_points")) < 1 or not bool(main.get("berserk_ascension_unlocked")):
		push_error("Expected boss victory to grant meta progress and Berserk Ascension 1.")
		quit(1)
		return


func _test_elite_flow(main_scene: PackedScene) -> void:
	paused = false
	var elite_main := main_scene.instantiate()
	root.add_child(elite_main)
	elite_main.set("selected_character_id", "berserk")
	elite_main.set("selected_weapon_id", "sword")
	elite_main.set("current_node_type", "elite_battle")
	elite_main.call("_open_route_node", {"type": "elite_battle", "name": "Test Elite"})
	await process_frame
	if not bool(elite_main.get("combat_active")) or str(elite_main.get("current_combat_type")) != "elite":
		push_error("Expected elite node to start elite combat mode.")
		quit(1)
		return
	var elite_enemy := elite_main.get_tree().get_first_node_in_group("elite_enemies")
	if elite_enemy == null or not elite_enemy.has_meta("elite_modifier"):
		push_error("Expected elite combat to spawn a mechanically flagged elite enemy.")
		quit(1)
		return
	if not elite_enemy.has_meta("elite_behavior"):
		push_error("Expected elite enemy to expose a unique behavior flag.")
		quit(1)
		return
	if float(elite_enemy.get("max_health")) <= 70.0:
		push_error("Expected elite enemy to be roughly an order of magnitude tougher than normal enemies.")
		quit(1)
		return
	var elite_health_bar := elite_enemy.get_node_or_null("HealthBar")
	if elite_health_bar == null:
		push_error("Expected elite enemies to carry an overhead health bar node.")
		quit(1)
		return
	if absf(float(elite_health_bar.get("max_value")) - float(elite_enemy.get("max_health"))) > 0.01:
		push_error("Expected elite health bar max value to match scaled elite max health.")
		quit(1)
		return
	elite_enemy.call("take_damage", 10.0)
	if float(elite_health_bar.get("value")) >= float(elite_health_bar.get("max_value")):
		push_error("Expected elite health bar to decrease after damage.")
		quit(1)
		return
	if absf(float(elite_health_bar.get("value")) - float(elite_enemy.get("health"))) > 0.01:
		push_error("Expected elite health bar value to match current elite health after damage.")
		quit(1)
		return
	var elite_body := elite_enemy.get_node_or_null("Body") as Sprite2D
	if elite_body == null or elite_body.texture == null or not elite_body.texture.resource_path.begins_with("res://assets/sprites/elites/"):
		push_error("Expected elite combat to use one of the new elite monster sprites.")
		quit(1)
		return
	if not elite_enemy.has_meta("elite_phase_threshold") or float(elite_enemy.get_meta("elite_phase_threshold", 0.0)) > 0.51:
		push_error("Expected elite enemies to expose a 50%% challenge phase threshold.")
		quit(1)
		return
	elite_main.set("route_stage", 4)
	elite_main.ui._show_elite_artifact_reward(Callable())
	await process_frame
	var elite_reward_buttons := elite_main.find_children("EliteArtifactRewardButton*", "Button", true, false)
	if elite_reward_buttons.size() != 3:
		push_error("Expected elite victory reward to offer exactly 3 artifact choices.")
		quit(1)
		return
	elite_main.queue_free()


func _test_debug_free_pick(main_scene: PackedScene) -> void:
	var debug_main := main_scene.instantiate()
	root.add_child(debug_main)
	await process_frame

	# Без debug-режима дальние ряды заблокированы.
	var route_module: Object = debug_main.get("route")
	if str(route_module.call("_route_node_state", 5, 0)) != "locked":
		push_error("Expected far route rows to be locked without debug free pick.")
		quit(1)
		return

	debug_main.set("route_debug_free_pick", true)
	debug_main.call("_show_battle_map")
	await process_frame
	if str(route_module.call("_route_node_state", 5, 0)) != "available":
		push_error("Expected debug free pick to make any route node available.")
		quit(1)
		return
	if debug_main.find_child("RouteDebugFreePickLabel", true, false) == null:
		push_error("Expected route map header to show the debug free pick indicator.")
		quit(1)
		return

	var route_nodes: Array = debug_main.get("route_nodes")
	var target_node: Dictionary = route_nodes[5][0]
	route_module.call("_activate_route_node", 5, 0, target_node)
	await process_frame
	if int(debug_main.get("route_stage")) != 5:
		push_error("Expected debug free pick to fast-forward route stage to the picked row.")
		quit(1)
		return
	var node_type := str(target_node.get("type", "battle"))
	if node_type in ["battle", "elite_battle"] and not bool(debug_main.get("combat_active")):
		push_error("Expected debug-picked battle node to start combat.")
		quit(1)
		return
	debug_main.queue_free()
	await process_frame


func _test_class_weapon_rework() -> void:
	var wand_config: Dictionary = ProgressionData.weapon("dark_mage", "dark_wand")
	if int(wand_config.get("beam_count", 1)) != 2:
		_fail("Expected dark wand to fire 2 beams by default.")
		return
	var book_config: Dictionary = ProgressionData.weapon("dark_mage", "dark_book")
	if int(book_config.get("projectile_count", 1)) != 2:
		_fail("Expected dark book to launch 2 AoE projectiles.")
		return
	var bass_config: Dictionary = ProgressionData.weapon("guitarist", "bass_guitar")
	if float(bass_config.get("damage_multiplier", 1.0)) > 0.35 or float(bass_config.get("fire_interval", 9.9)) > 0.9 or float(bass_config.get("knockback", 0.0)) < 150.0:
		_fail("Expected bass guitar to be a fast low-damage control pulse.")
		return
	var amp_config: Dictionary = ProgressionData.weapon("guitarist", "sound_amp")
	if float(amp_config.get("amp_lifetime", 0.0)) < 6.0 or float(amp_config.get("amp_lifetime", 0.0)) > 8.0 or int(amp_config.get("max_summons", 0)) != 1:
		_fail("Expected sound amp to live 6-8s with base limit 1.")
		return

	var holder := Node2D.new()
	holder.name = "ClassWeaponReworkScene"
	root.add_child(holder)
	current_scene = holder

	# 2 луча wand: считаем визуальные beam-эффекты после одной атаки.
	var mage := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(mage)
	mage.global_position = Vector2(700, 700)
	await process_frame
	mage.call("configure_character", "dark_mage", "dark_wand")
	var wand: Node = mage.get("equipped_weapon")
	wand.set_process(false)
	var beam_enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
	holder.add_child(beam_enemy)
	beam_enemy.set("max_health", 100000.0)
	beam_enemy.global_position = mage.global_position + Vector2(300, 0)
	await process_frame
	var effects_before := get_nodes_in_group("player_weapon_effects").size()
	wand.call("_attack")
	var beams_spawned := get_nodes_in_group("player_weapon_effects").size() - effects_before
	if beams_spawned < 2:
		_fail("Expected dark wand attack to spawn 2 beam effects, got %d." % beams_spawned)
		return
	mage.queue_free()
	beam_enemy.queue_free()
	await process_frame

	# Лимит ампов: гитарист с Лидерством 7 держит 1 + floor(7/4) = 2 усилителя.
	var guitarist := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(guitarist)
	guitarist.global_position = Vector2(700, 700)
	await process_frame
	guitarist.call("configure_character", "guitarist", "sound_amp")
	var amp_weapon: Node = guitarist.get("equipped_weapon")
	amp_weapon.set_process(false)
	if int(amp_weapon.get("max_summons")) != 2:
		_fail("Expected guitarist (leadership 7) amp limit to be 2, got %d." % int(amp_weapon.get("max_summons")))
		return
	for deploy_index in range(3):
		amp_weapon.call("_attack")
		await process_frame
	var active_amps := get_nodes_in_group("deployed_sound_amps").size()
	if active_amps != 2:
		_fail("Expected oldest amp to despawn at the limit, got %d active." % active_amps)
		return

	guitarist.queue_free()
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_unique_class_identity_patterns() -> void:
	if ProgressionData.weapon("doctor", "restore_potion").get("attack_mode", "") != "drain_link":
		_fail("Expected Doctor restore potion slot to use the drain/lifesteal link pattern.")
		return
	if float(ProgressionData.weapon("ranger", "moon_crossbow").get("charge_seconds", 0.0)) <= 0.0:
		_fail("Expected Ranger moon crossbow to expose stance charge seconds.")
		return
	if not bool(ProgressionData.weapon("chemist", "blast_powder").get("combo_clouds", false)):
		_fail("Expected Chemist clouds to support combo explosions.")
		return
	if float(ProgressionData.weapon("knight", "long_spear").get("passive_mods", {}).get("block_reduction", 0.0)) <= 0.0:
		_fail("Expected Knight weapons to carry block/counter passive data.")
		return
	if ProgressionData.weapon("druid", "summon_amulet").get("command_mode", "") != "attack_target":
		_fail("Expected Druid summon amulet to command pets toward a target.")
		return

	var holder := Node2D.new()
	holder.name = "UniqueClassIdentityScene"
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
	ranger_weapon.set("_charge_time", 0.0)
	ranger_weapon.set("_current_charge_multiplier", 1.0)
	var base_shot := float(ranger_weapon.call("_rolled_damage", ranger))
	ranger_weapon.set("_charge_time", float(ranger_weapon.get("charge_seconds")))
	ranger_weapon.set("_current_charge_multiplier", float(ranger_weapon.call("_charge_multiplier")))
	var charged_shot := float(ranger_weapon.call("_rolled_damage", ranger))
	if charged_shot <= base_shot * 1.2:
		_fail("Expected Ranger charged stance shot to deal meaningfully more damage.")
		return

	var doctor := player_scene.instantiate()
	holder.add_child(doctor)
	doctor.global_position = Vector2(900, 700)
	await process_frame
	doctor.call("configure_character", "doctor", "restore_potion")
	var doctor_weapon: Node = doctor.get("equipped_weapon")
	doctor_weapon.set_process(false)
	doctor.set("health", float(doctor.get("max_health")) * 0.5)
	var doctor_enemy := enemy_scene.instantiate()
	holder.add_child(doctor_enemy)
	doctor_enemy.set("max_health", 100000.0)
	doctor_enemy.set("health", 100000.0)
	doctor_enemy.global_position = doctor.global_position + Vector2(220, 0)
	await process_frame
	var doctor_health_before := float(doctor.get("health"))
	doctor_weapon.call("_attack")
	await process_frame
	if float(doctor.get("health")) <= doctor_health_before:
		_fail("Expected Doctor drain link to heal from dealt damage.")
		return

	var chemist := player_scene.instantiate()
	holder.add_child(chemist)
	chemist.global_position = Vector2(1100, 700)
	await process_frame
	chemist.call("configure_character", "chemist", "blast_powder")
	var chemist_weapon: Node = chemist.get("equipped_weapon")
	chemist_weapon.set_process(false)
	var chemist_enemy := enemy_scene.instantiate()
	holder.add_child(chemist_enemy)
	chemist_enemy.set("max_health", 100000.0)
	chemist_enemy.set("health", 100000.0)
	chemist_enemy.global_position = chemist.global_position + Vector2(40, 0)
	await process_frame
	var chemist_hp_before := float(chemist_enemy.get("health"))
	chemist_weapon.set("pool_element", "spark")
	chemist_weapon.call("_spawn_damage_pool", chemist_enemy.global_position, 1.0)
	chemist_weapon.set("pool_element", "poison")
	chemist_weapon.call("_spawn_damage_pool", chemist_enemy.global_position + Vector2(18, 0), 1.0)
	await process_frame
	if float(chemist_enemy.get("health")) >= chemist_hp_before:
		_fail("Expected Chemist overlapping cloud elements to trigger combo damage.")
		return

	var knight := player_scene.instantiate()
	holder.add_child(knight)
	knight.global_position = Vector2(1300, 700)
	await process_frame
	knight.call("configure_character", "knight", "long_spear")
	var knight_parameters: Dictionary = knight.get("derived_parameters")
	knight_parameters["dodge"] = 0.0
	knight.set("derived_parameters", knight_parameters)
	var knight_enemy := enemy_scene.instantiate()
	holder.add_child(knight_enemy)
	knight_enemy.set("max_health", 100000.0)
	knight_enemy.set("health", 100000.0)
	knight_enemy.global_position = knight.global_position + Vector2(80, 0)
	await process_frame
	var knight_hp_before := float(knight.get("health"))
	var knight_enemy_hp_before := float(knight_enemy.get("health"))
	knight.call("take_damage", 20.0, "test_counter")
	await process_frame
	var knight_damage_taken := knight_hp_before - float(knight.get("health"))
	if knight_damage_taken >= 20.0 or float(knight_enemy.get("health")) >= knight_enemy_hp_before:
		_fail("Expected Knight block to reduce damage and counter nearby enemies.")
		return

	var druid := player_scene.instantiate()
	holder.add_child(druid)
	druid.global_position = Vector2(1500, 700)
	await process_frame
	druid.call("configure_character", "druid", "summon_amulet")
	var druid_enemy := enemy_scene.instantiate()
	holder.add_child(druid_enemy)
	druid_enemy.global_position = druid.global_position + Vector2(240, 0)
	var druid_weapon: Node = druid.get("equipped_weapon")
	druid_weapon.set_process(false)
	druid_weapon.call("_summon")
	await process_frame
	var commanded := false
	for ally in get_nodes_in_group("allies"):
		var ally_target = ally.get("command_target")
		if ally.get("owner_node") == druid and ally_target != null and is_instance_valid(ally_target) and ally.get("command_mode") == "attack_target":
			commanded = true
	if not commanded:
		_fail("Expected Druid pets to receive an attack-target command.")
		return

	var assassin := player_scene.instantiate()
	holder.add_child(assassin)
	assassin.global_position = Vector2(1700, 700)
	await process_frame
	assassin.call("configure_character", "assassin", "chakrams")
	var assassin_enemy := enemy_scene.instantiate()
	holder.add_child(assassin_enemy)
	assassin_enemy.global_position = assassin.global_position + Vector2(220, 0)
	var assassin_start: Vector2 = assassin.global_position
	assassin.call("trigger_assassin_dash", assassin_enemy, 100.0)
	await create_timer(0.15).timeout
	if assassin.global_position.distance_to(assassin_start) < 40.0:
		_fail("Expected Assassin critical mobility hook to dash toward a target.")
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_universal_attribute_interpretations() -> void:
	var holder := Node2D.new()
	holder.name = "UniversalAttributeInterpretationScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene

	var universal_player := player_scene.instantiate()
	holder.add_child(universal_player)
	universal_player.global_position = Vector2(900, 700)
	await process_frame
	universal_player.call("configure_character", "berserk", "sword")
	var boosted: Dictionary = universal_player.get("derived_parameters")
	boosted["magic_damage"] = 80.0
	boosted["dot_damage"] = 40.0
	boosted["dot_speed"] = 4.0
	boosted["summon_amount"] = 18.0
	boosted["sound_wave_damage"] = 34.0
	boosted["aura_radius"] = 220.0
	universal_player.set("derived_parameters", boosted)

	var enemy := enemy_scene.instantiate()
	holder.add_child(enemy)
	enemy.set("max_health", 100000.0)
	enemy.set("health", 100000.0)
	enemy.global_position = universal_player.global_position + Vector2(90, 0)
	await process_frame
	var hp_before := float(enemy.get("health"))
	universal_player.call("on_weapon_hit", enemy, 12.0)
	await create_timer(0.65).timeout
	if float(enemy.get("health")) >= hp_before:
		_fail("Expected universal magic/DoT interpretations to damage the hit target.")
		return

	var leadership_hp_before := float(enemy.get("health"))
	for hit_index in range(6):
		universal_player.call("on_weapon_hit", enemy, 12.0)
		await process_frame
	if float(enemy.get("health")) >= leadership_hp_before:
		_fail("Expected leadership interpretation to trigger echo weapon damage.")
		return

	var shout_enemy := enemy_scene.instantiate()
	holder.add_child(shout_enemy)
	shout_enemy.global_position = universal_player.global_position + Vector2(60, 0)
	await process_frame
	universal_player.call("_update_battle_shout")
	if float(universal_player.get("_battle_shout_cooldown_left")) <= 0.0:
		_fail("Expected sound damage interpretation to trigger a battle shout cooldown.")
		return

	var rewards := ProgressionData.level_up_rewards("berserk")
	var derived_icons_seen := {}
	var mod_display := {
		"dot_damage_flat": "dot_damage",
		"dot_speed_flat": "dot_speed",
		"projectile_speed_flat": "projectile_speed",
		"aura_radius_flat": "aura_radius",
		"buff_power_flat": "buff_power",
		"summon_bonus": "summon_amount",
		"absorb_flat": "absorb",
		"regeneration_flat": "regeneration",
		"vampiric_amount_flat": "vampiric_amount",
		"vampiric_chance_flat": "vampiric_chance",
		"ultimate_flat": "ultimate_multiplier",
	}
	for reward in rewards:
		var mods: Dictionary = reward.get("mods", {})
		for modifier_id in mods.keys():
			var icon_id := str(mod_display.get(str(modifier_id), ""))
			if icon_id != "":
				derived_icons_seen[icon_id] = true
	for icon_id in ["dot_damage", "dot_speed", "projectile_speed", "aura_radius", "buff_power", "summon_amount", "absorb", "regeneration", "vampiric_amount", "vampiric_chance", "ultimate_multiplier"]:
		if not derived_icons_seen.has(icon_id):
			_fail("Expected level-up pool to expose derived attribute reward %s." % icon_id)
			return
		if not UIIconRegistry.has_texture(icon_id):
			_fail("Expected derived attribute %s to resolve to an icon texture." % icon_id)
			return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_class_budget_profiles() -> void:
	var checked := 0
	for character_id in ProgressionData.character_ids():
		var profile: Dictionary = ProgressionData.class_budget_profile(character_id)
		if str(profile.get("profile", "")) == "":
			_fail("Expected class %s to have a balance profile." % character_id)
			return
		for weapon_id in ProgressionData.weapon_ids(character_id):
			var weapon: Dictionary = ProgressionData.weapon(character_id, weapon_id)
			var tuning: Dictionary = weapon.get("budget_tuning", {})
			if tuning.is_empty():
				_fail("Expected %s/%s to expose budget tuning." % [character_id, weapon_id])
				return
			var metrics: Dictionary = ProgressionData.estimate_weapon_budget(character_id, weapon, true)
			var solo_target := float(tuning.get("solo_target", 0.0))
			var aoe_target := float(tuning.get("aoe_target", 0.0))
			var solo_dev := absf(float(metrics.get("solo_dps", 0.0)) / maxf(solo_target, 0.001) - 1.0)
			var aoe_dev := absf(float(metrics.get("aoe_dps", 0.0)) / maxf(aoe_target, 0.001) - 1.0)
			if solo_dev > 0.10 or aoe_dev > 0.10:
				_fail("Expected %s/%s budget deviation <=10%%, got solo %.1f%% and 5T %.1f%%." % [character_id, weapon_id, solo_dev * 100.0, aoe_dev * 100.0])
				return
			checked += 1
	if checked != 27:
		_fail("Expected balance budget coverage for 27 class+weapon pairs, got %d." % checked)
		return


func _test_enemy_stage_scaling_and_elite_rewards(main_scene: PackedScene) -> void:
	var previous_scale := 0.0
	for stage in range(0, 9):
		var scale := ProgressionData.stage_scale(stage)
		if scale <= previous_scale:
			_fail("Expected stage_scale to increase monotonically, stage %d scale %.3f after %.3f." % [stage, scale, previous_scale])
			return
		previous_scale = scale
	var stage0_damage_cost := 0
	var stage6_damage_cost := 0
	for item in ProgressionData.shop_items(0):
		if str(item.get("id", "")) == "shop_damage":
			stage0_damage_cost = int(item.get("cost", 0))
	for item in ProgressionData.shop_items(6):
		if str(item.get("id", "")) == "shop_damage":
			stage6_damage_cost = int(item.get("cost", 0))
	if stage0_damage_cost <= 0 or stage6_damage_cost <= stage0_damage_cost:
		_fail("Expected shop prices to scale with stage_scale, got %d -> %d." % [stage0_damage_cost, stage6_damage_cost])
		return
	var elite_choices := ProgressionData.elite_artifact_choices(6, 3)
	if elite_choices.size() != 3:
		_fail("Expected elite artifact reward generator to return 3 choices.")
		return
	var seen_ids := {}
	for choice in elite_choices:
		if str(choice.get("kind", "")) != "artifact" or not choice.has("tier"):
			_fail("Expected elite reward choices to be artifact rewards.")
			return
		var choice_id := str(choice.get("id", ""))
		if seen_ids.has(choice_id):
			_fail("Expected elite reward choices to be unique artifacts.")
			return
		seen_ids[choice_id] = true

	var scaling_main := main_scene.instantiate()
	root.add_child(scaling_main)
	await process_frame
	scaling_main.set("route_stage", 6)
	scaling_main.ui._show_elite_artifact_reward(Callable())
	await process_frame
	var reward_screen := scaling_main.find_child("EliteArtifactRewardScreen", true, false) as Control
	var reward_buttons := scaling_main.find_children("EliteArtifactRewardButton*", "Button", true, false)
	if reward_screen == null or reward_buttons.size() != 3:
		_fail("Expected elite artifact reward screen to render 3 clickable artifact buttons.")
		scaling_main.queue_free()
		return
	scaling_main.queue_free()
	await process_frame


func _test_ultimate_framework() -> void:
	var holder := Node2D.new()
	holder.name = "UltimateFrameworkScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for character_id in ProgressionData.character_ids():
		var player := player_scene.instantiate()
		holder.add_child(player)
		player.global_position = Vector2(900, 700)
		await process_frame
		var weapon_ids := ProgressionData.weapon_ids(character_id)
		player.call("configure_character", character_id, str(weapon_ids[0]))
		var parameters: Dictionary = player.get("derived_parameters")
		parameters["ultimate_multiplier"] = 1.5
		player.set("derived_parameters", parameters)
		var enemies := []
		for index in range(3):
			var enemy := enemy_scene.instantiate()
			holder.add_child(enemy)
			enemy.add_to_group("enemies")
			enemy.set("max_health", 100000.0)
			enemy.set("health", 100000.0)
			enemy.global_position = player.global_position + Vector2(110 + index * 45, 0)
			enemies.append(enemy)
		await process_frame
		var hp_before := 0.0
		for enemy in enemies:
			hp_before += float(enemy.get("health"))
		player.set("ultimate_charge", 100.0)
		if not bool(player.call("ultimate_ready")):
			_fail("Expected %s ultimate to be ready at full charge." % character_id)
			return
		if not bool(player.call("activate_ultimate")):
			_fail("Expected %s ultimate activation to succeed." % character_id)
			return
		if float(player.get("ultimate_charge")) > 0.01:
			_fail("Expected %s ultimate to reset charge after activation." % character_id)
			return
		await process_frame
		if character_id == "berserk":
			player.call("on_weapon_hit", enemies[0], 20.0)
			await process_frame
		var hp_after := 0.0
		for enemy in enemies:
			if is_instance_valid(enemy):
				hp_after += float(enemy.get("health"))
		if character_id == "druid":
			if get_nodes_in_group("allies").is_empty():
				_fail("Expected Druid ultimate to summon temporary allies.")
				return
		elif hp_after >= hp_before:
			_fail("Expected %s ultimate to have a measurable combat effect." % character_id)
			return
		player.queue_free()
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_weapon_aiming() -> void:
	var holder := Node2D.new()
	holder.name = "AimTestScene"
	root.add_child(holder)
	current_scene = holder

	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene

	var aim_checks := [
		{"character": "berserk", "weapon": "sword"},
		{"character": "dark_mage", "weapon": "dark_wand"},
		{"character": "guitarist", "weapon": "electric_guitar"},
	]
	for check in aim_checks:
		var aim_player := player_scene.instantiate()
		holder.add_child(aim_player)
		aim_player.global_position = Vector2(700, 700)
		await process_frame
		aim_player.call("configure_character", check["character"], check["weapon"])
		var weapon: Node = aim_player.get("equipped_weapon")
		if weapon == null:
			_fail("Expected %s to equip %s for the aim test." % [check["character"], check["weapon"]])
			return
		# Отключаем автоатаку, чтобы оружие не убило тестового врага между кадрами.
		weapon.set_process(false)

		# Враг справа, персонаж «двигался» влево: атака обязана уйти вправо к врагу.
		var aim_enemy := enemy_scene.instantiate()
		holder.add_child(aim_enemy)
		aim_enemy.global_position = aim_player.global_position + Vector2(260, 0)
		await process_frame
		weapon.set("_last_direction", Vector2.LEFT)
		if weapon.has_method("_start_swing"):
			weapon.call("_start_swing", true)
		else:
			weapon.call("_attack")
		var aim_direction: Vector2 = weapon.get("_last_direction")
		if aim_direction.x <= 0.5:
			_fail("Expected %s weapon to aim at the nearest enemy instead of movement direction." % check["character"])
			return

		# Без врагов направление атаки не должно дергаться за движением.
		aim_enemy.queue_free()
		await process_frame
		weapon.set("_last_direction", Vector2.UP)
		if weapon.has_method("_start_swing"):
			weapon.call("_start_swing", true)
		else:
			weapon.call("_attack")
		var no_enemy_direction: Vector2 = weapon.get("_last_direction")
		if no_enemy_direction.distance_to(Vector2.UP) > 0.01:
			_fail("Expected %s weapon to keep last attack direction when no enemies exist." % check["character"])
			return
		aim_player.queue_free()
		await process_frame

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_all_nine_classes() -> void:
	# Каждый из 9 классов экипирует сигнатурное оружие и наносит урон (друид — призывает).
	var signature := {
		"berserk": "sword", "dark_mage": "dark_wand", "guitarist": "electric_guitar",
		"assassin": "chakrams", "ranger": "moon_crossbow", "doctor": "restore_potion",
		"chemist": "blast_powder", "knight": "long_spear", "druid": "summon_amulet",
	}
	if ProgressionData.character_ids().size() != 9:
		_fail("Expected nine playable classes in the data.")
		return
	for class_id in signature.keys():
		if ProgressionData.ascension_levels(class_id).size() != 10:
			_fail("Expected 10 ascension levels for %s." % class_id)
			return

	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	for class_id in signature.keys():
		var class_player := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
		holder.add_child(class_player)
		class_player.global_position = Vector2(700, 700)
		await process_frame
		class_player.call("configure_character", class_id, signature[class_id])
		var weapon: Node = class_player.get("equipped_weapon")
		if weapon == null:
			_fail("Expected %s to equip its signature weapon %s." % [class_id, signature[class_id]])
			return
		weapon.set_process(false)

		if class_id == "druid":
			weapon.call("_summon")
			await process_frame
			if get_nodes_in_group("allies").is_empty():
				_fail("Expected the druid amulet to summon a beast.")
				return
			for ally in get_nodes_in_group("allies"):
				ally.queue_free()
		else:
			var class_enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
			holder.add_child(class_enemy)
			class_enemy.set("max_health", 100000.0)
			class_enemy.set("health", 100000.0)
			class_enemy.global_position = class_player.global_position + Vector2(180, 0)
			await process_frame
			var enemy_hp := float(class_enemy.get("health"))
			if weapon.has_method("_start_swing"):
				weapon.call("_start_swing", true)
			else:
				weapon.call("_attack")
			# Снарядным оружиям (зелье/пыль) нужно время полета до взрыва.
			await create_timer(0.7).timeout
			if float(class_enemy.get("health")) >= enemy_hp:
				_fail("Expected %s signature weapon to damage an enemy." % class_id)
				return
			class_enemy.queue_free()
		class_player.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_full_attribute_wiring() -> void:
	# Каждый подключенный параметр присутствует и реагирует на свой стат/награду.
	var stats: Dictionary = ProgressionData.base_stats("berserk")
	var weapon: Dictionary = ProgressionData.weapon("berserk", "sword")
	var base: Dictionary = ProgressionData.derived_parameters(stats, {}, weapon)
	for parameter_id in ["absorb", "regeneration", "vampiric_chance", "vampiric_amount", "knockback_distance", "range_multiplier", "ultimate_multiplier"]:
		if not base.has(parameter_id):
			_fail("Expected derived parameters to include %s." % parameter_id)
			return
	var boosted_stats: Dictionary = stats.duplicate(true)
	boosted_stats["endurance"] = boosted_stats["endurance"] + 4.0
	boosted_stats["knowledge"] = boosted_stats["knowledge"] + 5.0
	boosted_stats["energy"] = boosted_stats["energy"] + 5.0
	var boosted: Dictionary = ProgressionData.derived_parameters(boosted_stats, {}, weapon)
	if boosted["absorb"] <= base["absorb"] or boosted["regeneration"] <= base["regeneration"]:
		_fail("Expected endurance/knowledge to raise absorb and regeneration.")
		return
	if boosted["knockback_distance"] <= base["knockback_distance"] or boosted["ultimate_multiplier"] <= base["ultimate_multiplier"]:
		_fail("Expected endurance/energy to raise knockback distance and ultimate multiplier.")
		return
	var vamp_mods := {"vampiric_chance_flat": 0.25, "vampiric_amount_flat": 2.0}
	var vamp: Dictionary = ProgressionData.derived_parameters(stats, vamp_mods, weapon)
	if absf(float(vamp["vampiric_chance"]) - 0.25) > 0.001 or absf(float(vamp["vampiric_amount"]) - 2.0) > 0.001:
		_fail("Expected vampiric rewards to feed the vampiric parameters.")
		return

	# Геймплейная проводка: вампиризм лечит, регенерация тикает, absorb режет урон.
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var wiring_player := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(wiring_player)
	await process_frame
	wiring_player.call("configure_character", "berserk", "sword")
	wiring_player.call("apply_reward", {"mods": {"vampiric_chance_flat": 1.0, "vampiric_amount_flat": 5.0}})
	# Шанс капится на 0.6 — для детерминизма теста форсируем гарантированный прок.
	var wiring_derived: Dictionary = wiring_player.get("derived_parameters")
	wiring_derived["vampiric_chance"] = 1.0
	wiring_player.set("derived_parameters", wiring_derived)
	wiring_player.set("health", float(wiring_player.get("max_health")) * 0.5)
	var hp_before_vamp := float(wiring_player.get("health"))
	wiring_player.call("on_weapon_hit", wiring_player, 10.0)
	if float(wiring_player.get("health")) <= hp_before_vamp:
		_fail("Expected a guaranteed vampiric hit to heal the player.")
		return
	var hp_before_regen := float(wiring_player.get("health"))
	wiring_player.call("_apply_regeneration", 5.0)
	if float(wiring_player.get("health")) <= hp_before_regen:
		_fail("Expected regeneration to heal over time.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_settings_persistence_and_audio() -> void:
	# Save/load roundtrip настроек.
	var game_settings := load("res://scripts/game_settings.gd")
	var saved := {
		"resolution_index": 2, "window_mode_index": 1, "screen_index": 1,
		"master_volume": 0.85, "music_volume": 0.4, "sfx_volume": 0.65,
		"music_enabled": false, "sfx_enabled": true,
	}
	game_settings.save_settings(saved)
	var loaded: Dictionary = game_settings.load_settings()
	for key in saved.keys():
		if typeof(loaded[key]) == TYPE_FLOAT:
			if absf(float(loaded[key]) - float(saved[key])) > 0.001:
				_fail("Expected settings key %s to survive the save/load roundtrip." % key)
				return
		elif loaded[key] != saved[key]:
			_fail("Expected settings key %s to survive the save/load roundtrip." % key)
			return
	# Вернуть дефолты, чтобы не влиять на следующие запуски тестов.
	game_settings.save_settings(game_settings.DEFAULTS.duplicate(true))

	# Аудио-шины созданы и реагируют на настройки.
	var audio := root.get_node_or_null("/root/AudioManager")
	if audio == null:
		_fail("Expected the AudioManager autoload to exist.")
		return
	if AudioServer.get_bus_index("Music") == -1 or AudioServer.get_bus_index("SFX") == -1:
		_fail("Expected Music and SFX audio buses to be created.")
		return
	audio.apply_volume_settings({"master_volume": 1.0, "music_volume": 0.5, "sfx_volume": 1.0, "music_enabled": false, "sfx_enabled": true})
	var music_bus := AudioServer.get_bus_index("Music")
	if not AudioServer.is_bus_mute(music_bus):
		_fail("Expected the music toggle to mute the Music bus.")
		return
	if absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.5)) > 0.1:
		_fail("Expected the music slider to set bus volume (value preserved while muted).")
		return
	audio.apply_volume_settings({"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0, "music_enabled": true, "sfx_enabled": true})


func _test_settings_tabs_and_rebind(main: Node) -> void:
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	if tabs == null or tabs.get_child_count() != 3:
		_fail("Expected settings screen to use three tabs.")
		return
	for tab_name in ["Экран", "Звук", "Управление"]:
		if tabs.get_node_or_null(tab_name) == null:
			_fail("Expected settings tab %s to exist." % tab_name)
			return
	for slider_id in ["master_volume", "music_volume", "sfx_volume"]:
		var slider := main.find_child("VolumeSlider_%s" % slider_id, true, false) as HSlider
		if slider == null or not slider.visible or slider.max_value != 100.0:
			_fail("Expected visible 0-100 settings slider for %s." % slider_id)
			return
		if not bool(slider.size_flags_horizontal & Control.SIZE_EXPAND_FILL):
			_fail("Expected %s slider to expand across the audio tab." % slider_id)
			return
	if not InputMap.has_action("ultimate"):
		_fail("Expected InputMap action 'ultimate' to exist.")
		return
	var ui = main.get("ui")
	if ui == null:
		_fail("Expected main UI helper to be available for settings tests.")
		return
	if str(ui.call("_binding_conflict_action", "ultimate", KEY_W)) != "move_up":
		_fail("Expected rebinding ultimate to W to report a move_up conflict.")
		return
	main.set("pending_rebind_action", "ultimate")
	var rebind_event := InputEventKey.new()
	rebind_event.keycode = KEY_T
	rebind_event.pressed = true
	ui.call("_handle_rebind_input", rebind_event)
	var ultimate_events := InputMap.action_get_events("ultimate")
	if ultimate_events.is_empty() or not (ultimate_events[0] is InputEventKey) or (ultimate_events[0] as InputEventKey).keycode != KEY_T:
		_fail("Expected ultimate rebind to apply the new key.")
		return
	var game_settings := load("res://scripts/game_settings.gd")
	var loaded: Dictionary = game_settings.load_settings()
	var bindings: Dictionary = loaded.get("input_bindings", {})
	if not bindings.has("ultimate") or not (KEY_T in (bindings["ultimate"] as Array)):
		_fail("Expected ultimate rebind to persist in settings.cfg.")
		return
	ui.call("_reset_input_bindings_to_defaults")
	if not (KEY_R in _keycodes_for_action("ultimate")):
		_fail("Expected reset defaults to restore ultimate to R.")
		return


func _keycodes_for_action(action_name: String) -> Array:
	var keys := []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			keys.append((event as InputEventKey).keycode)
	return keys


func _test_class_relevance_and_offer_fixation(main_scene: PackedScene) -> void:
	# 1. Новая философия: все базовые атрибуты доступны всем классам.
	for stat_id in UIIconRegistry.BASE_STAT_IDS:
		for class_id in ProgressionData.character_ids():
			if not ProgressionData.is_stat_relevant(stat_id, class_id):
				_fail("Expected stat %s to be universally relevant for %s." % [stat_id, class_id])
				return
	if ProgressionData.class_interpretation_text("berserk", "intelligence") == "" or ProgressionData.class_interpretation_text("dark_mage", "strength") == "":
		_fail("Expected foreign stats to expose class interpretation text.")
		return
	var mage_stats: Dictionary = ProgressionData.base_stats("dark_mage")
	var mage_weapon: Dictionary = ProgressionData.weapon("dark_mage", "dark_wand")
	var before: Dictionary = ProgressionData.derived_parameters(mage_stats, {}, mage_weapon)
	mage_stats["strength"] = mage_stats["strength"] + 10.0
	var after: Dictionary = ProgressionData.derived_parameters(mage_stats, {}, mage_weapon)
	if float(after.get("magic_damage", 0.0)) != float(before.get("magic_damage", 0.0)):
		_fail("Expected +10 strength to leave dark mage magic damage unchanged.")
		return

	# 2. Пулы: больше не скрывают magic focus или «чужие» базовые статы.
	var berserk_has_magic_focus := false
	for reward in ProgressionData.level_up_rewards("berserk"):
		if str(reward.get("id")) == "magic_focus_up":
			berserk_has_magic_focus = true
	if not berserk_has_magic_focus:
		_fail("Expected magic focus upgrade to be available to berserk as weapon enchantment.")
		return
	var mage_has_strength := false
	for reward in ProgressionData.reward_pool("dark_mage"):
		if str(reward.get("kind")) == "stat" and (reward.get("stats", {}) as Dictionary).has("strength"):
			mage_has_strength = true
	if not mage_has_strength:
		_fail("Expected strength stat rewards to remain available to dark mage via interpretation.")
		return

	var fix_main := main_scene.instantiate()
	root.add_child(fix_main)
	await process_frame
	fix_main.set("selected_character_id", "dark_mage")
	fix_main.set("selected_weapon_id", "dark_wand")

	# 3. Превью урона показывает классовый параметр.
	var preview: String = fix_main.ui._level_up_reward_preview({"kind": "upgrade", "mods": {"damage_multiplier": 1.15}})
	if not preview.contains("Маг. урон"):
		_fail("Expected the damage preview for dark mage to reference magic damage, got: %s" % preview)
		return

	# 4. Фиксация набора level-up при переоткрытии.
	fix_main.set("pending_level_ups", 1)
	fix_main.ui._show_level_up_screen(true)
	await process_frame
	var first_offer: Array = (fix_main.get("level_up_offer") as Array).duplicate(true)
	if first_offer.size() != 3:
		_fail("Expected a fixed set of three level-up rewards.")
		return
	fix_main.call("_clear_ui")
	fix_main.ui._show_level_up_screen(true)
	await process_frame
	var second_offer: Array = fix_main.get("level_up_offer")
	for offer_index in range(3):
		if str((first_offer[offer_index] as Dictionary).get("id")) != str((second_offer[offer_index] as Dictionary).get("id")):
			_fail("Expected reopening the level-up window to keep the same reward set.")
			return

	# 5. Фиксация пары атрибутов: переоткрытие окна докачки не реролит бесплатно.
	var fix_player := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	root.add_child(fix_player)
	fix_player.call("configure_character", "dark_mage", "dark_wand")
	fix_player.set("money", 500)
	fix_main.call("_store_player_snapshot", fix_player)
	fix_player.queue_free()
	fix_main.set("attribute_offer", [])
	fix_main.set("attribute_rerolls_left", 2)
	fix_main.ui._show_attribute_shop(Callable())
	await process_frame
	var pair_before: Array = (fix_main.get("attribute_offer") as Array).duplicate()
	fix_main.call("_clear_ui")
	fix_main.ui._show_attribute_shop(Callable())
	await process_frame
	var pair_after: Array = fix_main.get("attribute_offer")
	if pair_before != pair_after:
		_fail("Expected reopening the attribute window to keep the same stat pair.")
		return
	# Платный reroll меняет пару и тратит счетчик.
	var reroll := fix_main.find_child("AttributeRerollButton", true, false) as Button
	reroll.pressed.emit()
	await process_frame
	if int(fix_main.get("attribute_rerolls_left")) != 1:
		_fail("Expected the paid reroll to consume one reroll charge.")
		return
	fix_main.queue_free()
	await process_frame


func _test_ascension_difficulty_ladder(main_scene: PackedScene) -> void:
	# Данные: 10 кумулятивных усложнений, уровень 0 нейтрален, кумулятивность.
	if ProgressionData.ascension_modifiers().size() != 10:
		_fail("Expected 10 ascension difficulty modifiers.")
		return
	var level0: Dictionary = ProgressionData.ascension_difficulty_mods(0)
	for key in level0.keys():
		var neutral: float = 0.0 if str(key) in ["elite_instant_phase", "boss_extra_phase", "first_wave_boost", "mini_elite_chance"] else 1.0
		if absf(float(level0[key]) - neutral) > 0.001:
			_fail("Expected ascension level 0 modifier %s to be neutral (%f)." % [key, neutral])
			return
	var level3: Dictionary = ProgressionData.ascension_difficulty_mods(3)
	# L1 enemy hp 1.15, L1 dmg 1.10, L2 price 1.25, L3 spawn density 1.20 — кумулятивно активны.
	if absf(float(level3["enemy_hp_mult"]) - 1.15) > 0.001 or absf(float(level3["price_mult"]) - 1.25) > 0.001 or absf(float(level3["spawn_count_mult"]) - 1.20) > 0.001:
		_fail("Expected level 3 to cumulatively include levels 1+2+3 modifiers.")
		return
	# L4+ модификаторы НЕ активны на уровне 3.
	if float(level3["elite_instant_phase"]) > 0.0 or absf(float(level3["healing_mult"]) - 1.0) > 0.001:
		_fail("Expected level 3 to exclude level 4+ modifiers.")
		return
	var level10: Dictionary = ProgressionData.ascension_difficulty_mods(10)
	if float(level10["boss_extra_phase"]) <= 0.0 or absf(float(level10["player_max_hp_mult"]) - 0.80) > 0.001 or absf(float(level10["healing_mult"]) - 0.70) > 0.001:
		_fail("Expected level 10 to include boss extra phase, -20%% HP and -30%% healing.")
		return

	# Разблокировка по персонажу: победа на уровне N открывает N+1.
	var meta := MetaProgression.default_state()
	if MetaProgression.selectable_max(meta, "berserk") != 1:
		_fail("Expected a fresh character to be able to select up to ascension 1.")
		return
	meta = MetaProgression.record_boss_victory(meta, "berserk", 1)
	if MetaProgression.ascension_level(meta, "berserk") != 1 or MetaProgression.selectable_max(meta, "berserk") != 2:
		_fail("Expected beating ascension 1 to unlock selection up to 2.")
		return
	# Победа на уровне НИЖЕ максимума не разблокирует новый.
	meta = MetaProgression.record_boss_victory(meta, "berserk", 0)
	if MetaProgression.ascension_level(meta, "berserk") != 1:
		_fail("Expected beating a lower ascension level not to unlock further.")
		return

	# Применение в забеге: difficulty влияет на цены и HP игрока.
	var asc_main := main_scene.instantiate()
	root.add_child(asc_main)
	await process_frame
	asc_main.set("selected_character_id", "berserk")
	# Мета-сейв с разблокированными уровнями (selectable_max>=2), чтобы уровень 2
	# не клампился; наградные баффы тут не влияют на цены.
	var price_meta := MetaProgression.default_state()
	price_meta = MetaProgression.record_boss_victory(price_meta, "berserk", 0)
	price_meta = MetaProgression.record_boss_victory(price_meta, "berserk", 1)
	price_meta = MetaProgression.record_boss_victory(price_meta, "berserk", 2)
	asc_main.set("meta_state", price_meta)
	asc_main.set("selected_ascension_level", 0)
	asc_main.call("reset_run_ascension")
	var price_l0: int = asc_main.ui._attribute_buy_cost()
	asc_main.set("selected_ascension_level", 2)
	asc_main.call("reset_run_ascension")
	var price_l2: int = asc_main.ui._attribute_buy_cost()
	if price_l2 <= price_l0:
		_fail("Expected ascension 2 (greedy merchants) to raise attribute prices.")
		return

	# Уровень 10 урезает макс HP. Берсерк разблокирован до 10, сравниваем L0 vs L10
	# при ОДНОМ мета-сейве — наградные баффы одинаковы, разница = чистый difficulty -20%.
	var hp_meta := MetaProgression.default_state()
	for unlock_level in range(10):
		hp_meta = MetaProgression.record_boss_victory(hp_meta, "berserk", unlock_level)
	asc_main.set("meta_state", hp_meta)
	asc_main.set("selected_ascension_level", 0)
	asc_main.call("reset_run_ascension")
	var asc_player_l0 := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	root.add_child(asc_player_l0)
	asc_player_l0.call("configure_character", "berserk", "sword")
	asc_main.call("apply_ascension_bonuses", asc_player_l0)
	var hp_l0 := float(asc_player_l0.get("max_health"))
	asc_player_l0.queue_free()
	asc_main.set("selected_ascension_level", 10)
	asc_main.call("reset_run_ascension")
	var asc_player10 := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	root.add_child(asc_player10)
	asc_player10.call("configure_character", "berserk", "sword")
	asc_main.call("apply_ascension_bonuses", asc_player10)
	if float(asc_player10.get("max_health")) >= hp_l0 * 0.95:
		_fail("Expected ascension 10 to reduce player max HP vs level 0 (%f vs %f)." % [float(asc_player10.get("max_health")), hp_l0])
		return
	asc_player10.queue_free()

	# Багфикс 3: селектор не даёт уйти выше selectable_max — reset_run_ascension клампит.
	asc_main.set("meta_state", MetaProgression.default_state())
	asc_main.set("selected_character_id", "berserk")
	asc_main.set("selected_ascension_level", 9)
	asc_main.call("reset_run_ascension")
	if int(asc_main.get("selected_ascension_level")) > asc_main.call("ascension_selectable_max", "berserk"):
		_fail("Expected reset_run_ascension to clamp level to the character selectable max.")
		return

	# Багфикс 1: элитка с ascension_instant_phase открывает боевую фазу сразу (кулдаун ~0).
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var asc_elite := (load("res://scenes/EliteArmored.tscn") as PackedScene).instantiate()
	asc_elite.set_meta("ascension_instant_phase", true)
	holder.add_child(asc_elite)
	await process_frame
	var test_player := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(test_player)
	test_player.global_position = asc_elite.global_position + Vector2(120, 0)
	await process_frame
	# Один физический тик: instant-phase обнуляет стартовый кулдаун -> элитка сразу в windup.
	asc_elite.call("_physics_process", 0.05)
	if float(asc_elite.get("_elite_attack_cooldown")) > 0.1 and str(asc_elite.get("elite_attack_state")) == "idle":
		_fail("Expected ascension_instant_phase to zero the elite startup cooldown.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame

	# Багфикс 2 (данные): на возвышении 7 mini_elite_chance > 0.
	if float(ProgressionData.ascension_difficulty_mods(7)["mini_elite_chance"]) <= 0.0:
		_fail("Expected ascension level 7 to expose a mini-elite chance.")
		return

	# Багфикс 2 (поведение): mini_elite_chance реально ПОТРЕБЛЯЕТСЯ — мини-элитка
	# спавнится в обычной волне. Data-only тест ровно это и пропустил в исходном баге.
	var mini_main := main_scene.instantiate()
	root.add_child(mini_main)
	await process_frame
	mini_main.set("selected_character_id", "berserk")
	mini_main.set("selected_ascension_level", 0)
	mini_main.call("_start_combat")
	await process_frame
	# Детерминированный rng + чистая арена (как соседние ascension-тесты).
	(mini_main.get("rng") as RandomNumberGenerator).seed = 24607
	for stray in mini_main.get_tree().get_nodes_in_group("enemies"):
		stray.queue_free()
	for stray in mini_main.get_tree().get_nodes_in_group("elite_enemies"):
		stray.queue_free()
	await process_frame

	# (A) Путь потребления: _spawn_enemy_wave при forced chance=1.0 обязан создать мини-элитку.
	#     На «мёртвой» версии (спавн не вызывается из волны) elite_enemies не вырастет.
	(mini_main.get("run_ascension_difficulty") as Dictionary)["mini_elite_chance"] = 1.0
	var elites_before: int = mini_main.get_tree().get_nodes_in_group("elite_enemies").size()
	mini_main.combat.call("_spawn_enemy_wave")
	await process_frame
	var elites_after: int = mini_main.get_tree().get_nodes_in_group("elite_enemies").size()
	if elites_after <= elites_before:
		_fail("Expected ascension mini-elite to spawn via _spawn_enemy_wave (consumption path dead).")
		return

	# (B) Прямой вызов: учёт слотов + убиваемое HP (волновой elite-скейл × 0.55).
	for stray in mini_main.get_tree().get_nodes_in_group("enemies"):
		stray.queue_free()
	for stray in mini_main.get_tree().get_nodes_in_group("elite_enemies"):
		stray.queue_free()
	await process_frame
	var asc_force: Dictionary = (mini_main.call("ascension_difficulty") as Dictionary).duplicate()
	asc_force["mini_elite_chance"] = 1.0
	var used: int = int(mini_main.combat.call("_maybe_spawn_mini_elite", asc_force, 5))
	await process_frame
	var spawned: Array = mini_main.get_tree().get_nodes_in_group("elite_enemies")
	if spawned.size() != 1:
		_fail("Expected exactly one mini-elite from _maybe_spawn_mini_elite (got %d)." % spawned.size())
		return
	if used < 2 or used > 5:
		_fail("Expected mini-elite slot usage 2..5 (1 elite + 1-2 retinue), got %d." % used)
		return
	# Учёт слотов: группа enemies = мини-элитка (она же в enemies через _ready) + свита = used.
	var enemies_total: int = mini_main.get_tree().get_nodes_in_group("enemies").size()
	if enemies_total != used:
		_fail("Expected slot accounting enemies==used (%d vs %d)." % [enemies_total, used])
		return
	# Убиваемая, не танк: HP = тот же волновой elite-скейл × 0.55.
	var mini_node: Node = spawned[0]
	var mini_hp: float = float(mini_node.get("max_health"))
	var ref_elite: Node = (load(mini_node.scene_file_path) as PackedScene).instantiate()
	ref_elite.add_to_group("elite_enemies")
	mini_main.add_child(ref_elite)
	mini_main.combat.call("_scale_enemy_for_current_wave", ref_elite)
	var ref_hp: float = float(ref_elite.get("max_health"))
	if ref_hp <= 0.0 or absf(mini_hp - ref_hp * 0.55) > ref_hp * 0.03:
		_fail("Expected mini-elite HP ≈ wave elite ×0.55 (mini %f vs ref %f)." % [mini_hp, ref_hp])
		return
	mini_main.queue_free()
	await process_frame

	asc_main.queue_free()
	await process_frame


func _test_economy_tiers_and_fab(main_scene: PackedScene) -> void:
	# Данные: у всех артефактов tier и class_affinity; tier 3 — 5-8 штук.
	var tier3_count := 0
	for artifact in ProgressionData.ARTIFACTS:
		var tier := int(artifact.get("tier", 0))
		if tier < 1 or tier > 3 or not artifact.has("class_affinity"):
			_fail("Expected artifact %s to declare tier 1-3 and class_affinity." % artifact.get("id"))
			return
		if tier == 3:
			tier3_count += 1
	if tier3_count < 5 or tier3_count > 8:
		_fail("Expected 5-8 tier-3 artifacts, got %d." % tier3_count)
		return
	# Цены магазина x3-4.
	for item in ProgressionData.SHOP_ITEMS:
		if str(item.get("id")) == "shop_damage" and int(item.get("cost", 0)) != 42:
			_fail("Expected shop_damage cost to be 42 after the x3.5 economy pass.")
			return

	var econ_main := main_scene.instantiate()
	root.add_child(econ_main)
	await process_frame
	econ_main.set("selected_character_id", "berserk")

	# Аффинити-пометки: больше не красные/желтые запреты, а текст интерпретации.
	var split_note: Dictionary = econ_main.ui._artifact_affinity_note(ProgressionData.artifact_definition("split_core"))
	var void_note: Dictionary = econ_main.ui._artifact_affinity_note(ProgressionData.artifact_definition("void_ink"))
	var none_note: Dictionary = econ_main.ui._artifact_affinity_note(ProgressionData.artifact_definition("warrior_charm"))
	if not str(split_note.get("text", "")).begins_with("Интерпретация:"):
		_fail("Expected a class interpretation note for a foreign affinity artifact.")
		return
	if not str(void_note.get("text", "")).begins_with("Интерпретация:"):
		_fail("Expected a class interpretation note for a mixed affinity artifact.")
		return
	if not none_note.is_empty():
		_fail("Expected no affinity note for a universal artifact.")
		return

	# Механики tier 3: Кровавый Рубеж (low HP -> +урон) и Договор Шипов (отражение).
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var t3_player := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(t3_player)
	await process_frame
	t3_player.call("configure_character", "berserk", "sword")
	t3_player.call("apply_reward", ProgressionData.artifact_definition("blood_pact"))
	var damage_before := float((t3_player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	t3_player.set("health", float(t3_player.get("max_health")) * 0.1)
	t3_player.call("_update_low_hp_state")
	var damage_low := float((t3_player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	if damage_low < damage_before * 1.4:
		_fail("Expected Blood Pact to boost damage below 30%% HP (%f -> %f)." % [damage_before, damage_low])
		return

	t3_player.call("apply_reward", ProgressionData.artifact_definition("thorn_pact"))
	var thorn_enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
	holder.add_child(thorn_enemy)
	thorn_enemy.set("max_health", 100000.0)
	thorn_enemy.global_position = t3_player.global_position + Vector2(80, 0)
	await process_frame
	var enemy_hp_before := float(thorn_enemy.get("health"))
	var derived: Dictionary = t3_player.get("derived_parameters")
	derived["dodge"] = 0.0
	t3_player.set("derived_parameters", derived)
	t3_player.set("_damage_invulnerability_left", 0.0)
	t3_player.call("take_damage", 10.0)
	if float(thorn_enemy.get("health")) >= enemy_hp_before:
		_fail("Expected Thorn Pact to reflect damage to nearby enemies.")
		return
	holder.queue_free()
	current_scene = null

	# FAB прокачки на карте с бейджем.
	econ_main.set("pending_level_ups", 2)
	econ_main.call("_show_battle_map")
	await process_frame
	var fab := econ_main.find_child("UpgradeFabButton", true, false) as Button
	var badge := econ_main.find_child("UpgradeFabBadge", true, false) as Label
	if fab == null or badge == null or badge.text != "2":
		_fail("Expected the route map upgrade FAB with a pending-levels badge of 2.")
		return
	econ_main.queue_free()
	await process_frame


func _test_escape_navigation(main_scene: PackedScene) -> void:
	var nav_main := main_scene.instantiate()
	root.add_child(nav_main)
	await process_frame

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true

	# Настройки -> Esc -> меню.
	nav_main.call("_show_settings_menu")
	await process_frame
	nav_main.call("_input", escape_event)
	await process_frame
	if nav_main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected Escape on settings to return to the main menu.")
		return

	# Выбор персонажа -> Esc -> меню.
	nav_main.call("_show_character_select")
	await process_frame
	nav_main.call("_input", escape_event)
	await process_frame
	if nav_main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected Escape on character select to return to the main menu.")
		return

	# Выбор оружия -> Esc -> выбор персонажа.
	nav_main.set("selected_character_id", "berserk")
	nav_main.call("_show_weapon_select")
	await process_frame
	nav_main.call("_input", escape_event)
	await process_frame
	if nav_main.find_child("CharacterCard_berserk", true, false) == null:
		_fail("Expected Escape on weapon select to return to character select.")
		return

	# Кодекс -> Esc -> меню.
	nav_main.ui._show_codex_screen()
	await process_frame
	nav_main.call("_input", escape_event)
	await process_frame
	if nav_main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected Escape on codex to return to the main menu.")
		return

	# Карточка персонажа кликабельна целиком (Button) и с hover-стилем.
	nav_main.call("_show_character_select")
	await process_frame
	var card := nav_main.find_child("CharacterCard_berserk", true, false) as Button
	if card == null:
		_fail("Expected the whole character card to be a clickable Button.")
		return
	if not card.has_theme_stylebox_override("hover"):
		_fail("Expected the character card to carry a hover highlight style.")
		return
	card.pressed.emit()
	await process_frame
	if nav_main.find_child("CharacterCard_berserk", true, false) != null:
		_fail("Expected clicking the character card body to advance to weapon select.")
		return

	nav_main.queue_free()
	await process_frame


func _test_codex_screen(main_scene: PackedScene) -> void:
	var codex_main := main_scene.instantiate()
	root.add_child(codex_main)
	await process_frame

	var codex_button := codex_main.find_child("MainMenuCodexButton", true, false) as Button
	if codex_button == null:
		_fail("Expected the main menu to include the Codex button.")
		return
	codex_button.pressed.emit()
	await process_frame
	if codex_main.find_child("CodexScreen", true, false) == null:
		_fail("Expected the Codex screen to open from the main menu.")
		return

	# Полнота данных кодекса.
	var codex_data := load("res://scripts/codex_data.gd")
	var monsters: Array = codex_data.monsters()
	if monsters.size() != 17:
		_fail("Expected codex to list all 17 monsters (11 standard + 4 elites + 2 bosses), got %d." % monsters.size())
		return
	for monster in monsters:
		var abilities: Array = monster.get("abilities", [])
		if abilities.is_empty():
			_fail("Expected codex monster %s to have named abilities." % monster.get("id"))
			return
		for ability in abilities:
			if str(ability.get("title", "")) == "" or str(ability.get("id", "")) == "":
				_fail("Expected codex ability of %s to carry canonical id and title." % monster.get("id"))
				return
	var artifacts: Array = codex_data.artifacts()
	var expected_artifacts: int = ProgressionData.ARTIFACTS.size() + ProgressionData.SHOP_ITEMS.size()
	if artifacts.size() != expected_artifacts:
		_fail("Expected codex artifacts (%d) to match progression data (%d)." % [artifacts.size(), expected_artifacts])
		return
	if codex_data.characters().size() != 9 or codex_data.stats().size() < 20:
		_fail("Expected codex to cover all 9 characters and the stat definitions.")
		return

	# Все разделы открываются.
	for section_id in ["monsters", "artifacts", "stats", "ascensions", "characters"]:
		var tab := codex_main.find_child("CodexTab_%s" % section_id, true, false) as Button
		if tab == null:
			_fail("Expected codex tab %s." % section_id)
			return
		tab.pressed.emit()
		await process_frame
		var section := codex_main.find_child("CodexSection_%s" % section_id, true, false)
		if section == null or not (section as Control).visible:
			_fail("Expected codex section %s to build and become visible." % section_id)
			return

	var back_button := codex_main.find_child("CodexBackButton", true, false) as Button
	back_button.pressed.emit()
	await process_frame
	if codex_main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected the codex back button to return to the main menu.")
		return
	codex_main.queue_free()
	await process_frame


func _test_elite_unique_attacks() -> void:
	var elite_scenes := {
		"iron_bastion": "res://scenes/EliteArmored.tscn",
		"night_stalker": "res://scenes/EliteStalker.tscn",
		"plague_prophet": "res://scenes/ElitePoisoned.tscn",
		"shard_marshal": "res://scenes/EliteCommander.tscn",
	}
	var holder := Node2D.new()
	holder.name = "EliteAttackTestScene"
	root.add_child(holder)
	current_scene = holder

	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var test_player := player_scene.instantiate()
	holder.add_child(test_player)
	test_player.global_position = Vector2(800, 700)
	await process_frame

	for behavior_id in elite_scenes.keys():
		var elite := (load(elite_scenes[behavior_id]) as PackedScene).instantiate()
		holder.add_child(elite)
		elite.global_position = test_player.global_position + Vector2(200, 0)
		await process_frame

		if str(elite.get("elite_attack_id")) == "":
			_fail("Expected elite %s to expose a unique attack id." % behavior_id)
			return
		var observed_phases := []
		elite.elite_attack_phase_changed.connect(func(_attack_id: String, phase: String) -> void:
			observed_phases.append(phase)
		)
		elite.set("_elite_attack_cooldown", 0.0)
		var guard := 0
		while str(elite.get("elite_attack_state")) != "windup" and guard < 10:
			elite.call("_physics_process", 0.05)
			guard += 1
		if str(elite.get("elite_attack_state")) != "windup":
			_fail("Expected elite %s to enter windup phase." % behavior_id)
			return
		if holder.find_child("EliteAttackTelegraph", true, false) == null:
			_fail("Expected elite %s windup to spawn a telegraph." % behavior_id)
			return
		guard = 0
		while str(elite.get("elite_attack_state")) != "idle" and guard < 80:
			elite.call("_physics_process", 0.05)
			guard += 1
		if str(elite.get("elite_attack_state")) != "idle":
			_fail("Expected elite %s attack to return to idle." % behavior_id)
			return
		for expected_phase in ["windup", "strike", "recover", "idle"]:
			if not observed_phases.has(expected_phase):
				_fail("Expected elite %s to emit phase %s for the Animator." % [behavior_id, expected_phase])
				return
		if float(elite.get("_elite_attack_cooldown")) <= 0.0:
			_fail("Expected elite %s attack to set its cooldown." % behavior_id)
			return
		elite.queue_free()
		await process_frame

	holder.queue_free()
	current_scene = null
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _test_death_flow(main_scene: PackedScene) -> void:
	paused = false
	var death_main := main_scene.instantiate()
	root.add_child(death_main)
	death_main.set("selected_character_id", "berserk")
	death_main.set("selected_weapon_id", "sword")
	death_main.call("_start_combat")
	await process_frame
	var player: Node = death_main.get("current_player")
	# Dodge делает одиночный удар недетерминированным; для теста смерти обнуляем уворот.
	var derived: Dictionary = player.get("derived_parameters")
	derived["dodge"] = 0.0
	player.set("derived_parameters", derived)
	player.call("take_damage", 99999.0)
	await process_frame
	if bool(death_main.get("combat_active")):
		push_error("Expected player death to end combat.")
		quit(1)
		return
	death_main.queue_free()
