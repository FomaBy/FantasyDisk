extends SceneTree

const EXPECTED_ARENA_SIZE := Vector2(4096, 2304)  # SCRUM-518: lock-step с ARENA_SIZE (×1.6)
const EXPECTED_ARENA_CENTER := EXPECTED_ARENA_SIZE * 0.5
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const MetaProgression := preload("res://scripts/meta_progression.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")
const EventData := preload("res://scripts/event_data.gd")
const Glossary := preload("res://scripts/glossary.gd")
const RunAutosave := preload("res://scripts/run_autosave.gd")
const FeedbackReporter := preload("res://scripts/feedback_reporter.gd")
const HeroStatRadarScript := preload("res://scripts/ui/hero_stat_radar.gd")
const STANDARD_ACTION_BUTTON_HEIGHT := 104.0
const HERO_SELECT_UNIFIED_SOURCE_SIZE := Vector2(1536.0, 1024.0)
const HERO_SELECT_UNIFIED_PORTRAIT_RECT := Rect2(130.0, 145.0, 420.0, 560.0)
const HERO_SELECT_UNIFIED_DESCRIPTION_RECT := Rect2(610.0, 145.0, 786.0, 500.0)
const HERO_SELECT_UNIFIED_BOTTOM_CONTROLS_RECT := Rect2(570.0, 705.0, 660.0, 178.0)
const HERO_SELECT_V3_SOURCE_SIZE := Vector2(1536.0, 864.0)
const HERO_SELECT_V3_OUTER_SAFE := Rect2(0.0, 0.0, 1536.0, 864.0)
const HERO_SELECT_V3_PORTRAIT_FRAME := Rect2(42.0, 82.0, 342.0, 540.0)
const HERO_SELECT_V3_PORTRAIT_SAFE := Rect2(112.1, 182.0, 201.7, 329.4)
const HERO_SELECT_V3_DOSSIER_FRAME := Rect2(388.0, 93.0, 625.0, 467.0)
const HERO_SELECT_V3_DOSSIER_CONTENT := Rect2(490.9, 174.9, 419.1, 289.6)
const HERO_SELECT_V3_DOSSIER_TITLE_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_DOSSIER_BODY_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_DOSSIER_DESCRIPTION_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_TRAITS_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_WEAPONS_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_ASC_PANEL := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_SELECT_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V3_BACK_SAFE := Rect2(52.0, 28.0, 123.0, 54.0)
const HERO_SELECT_V3_RADAR_PANEL := Rect2(1086.0, 100.5, 388.0, 388.0)
const HERO_SELECT_V3_RADAR_CONTENT := Rect2(1173.2, 187.7, 213.7, 213.7)
const HERO_SELECT_V3_CAROUSEL_FRAME := Rect2(26.0, 626.0, 1488.0, 226.0)
const HERO_SELECT_V3_CAROUSEL_SAFE := Rect2(197.1, 683.7, 1145.7, 110.6)
const HERO_SELECT_V3_TOOLTIP_SAFE := HERO_SELECT_V3_DOSSIER_CONTENT
const HERO_SELECT_V4_BG := "res://assets/sprites/ui/hero_select_v4/background.png"
const HERO_SELECT_V4_SOURCE_SIZE := Vector2(1536.0, 1024.0)
const HERO_SELECT_V4_TITLE := Rect2(0.265, 0.018, 0.470, 0.105)
const HERO_SELECT_V4_BACK := Rect2(0.022, 0.028, 0.110, 0.070)
const HERO_SELECT_V4_PORTRAIT_FRAME := Rect2(0.020, 0.135, 0.247, 0.580)
const HERO_SELECT_V4_PORTRAIT_SAFE := Rect2(0.035, 0.168, 0.217, 0.512)
const HERO_SELECT_V4_DOSSIER := Rect2(0.288, 0.138, 0.362, 0.555)
const HERO_SELECT_V4_RADAR := Rect2(0.715, 0.175, 0.230, 0.320)
const HERO_SELECT_V4_CAROUSEL := Rect2(0.020, 0.735, 0.960, 0.215)
const HERO_SELECT_V4_VISIBLE_SLOTS := 9
const HERO_SELECT_DOSSIER_SOURCE_SIZE := Vector2(1120.0, 1140.0)
const HERO_SELECT_DOSSIER_SAFE_MARGINS := Vector4(126.0, 160.0, 126.0, 172.0)
const HERO_SELECT_THUMBNAIL_SOURCE_SIZE := Vector2(1536.0, 255.0)
const HERO_SELECT_THUMBNAIL_SAFE_MARGINS := Vector4(132.0, 62.0, 132.0, 62.0)
const MINIMAL_MODAL_TEXTURE := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_modal.png"
const MINIMAL_PANEL_TEXTURE := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png"
const MINIMAL_CARD_TEXTURE := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png"
const MINIMAL_TOOLTIP_TEXTURE := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png"
const MINIMAL_HUD_STRIP_TEXTURE := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_hud_strip.png"
const MINIMAL_FIELD_TEXTURE := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png"
const REWARD_FRAME_SOURCE_SIZE := Vector2(426.0, 486.0)
const REWARD_CARD_SAFE_MARGINS := Vector4(45.0, 58.0, 45.0, 56.0)
const REWARD_ELITE_CARD_SAFE_MARGINS := Vector4(45.0, 58.0, 45.0, 56.0)
const REWARD_CARD_TEXTURE := MINIMAL_CARD_TEXTURE
const REWARD_ELITE_CARD_TEXTURE := MINIMAL_CARD_TEXTURE
const ECONOMY_CHOICE_WIDE_TEXTURE := MINIMAL_CARD_TEXTURE
const ECONOMY_CHOICE_WIDE_HOVER_TEXTURE := MINIMAL_CARD_TEXTURE
const EXPECTED_PLAYER_COMBAT_VISUAL_SCALE := 0.425  # SCRUM-518: −15% от 0.5 (lock-step с player.gd)
const ROUTE_START_BATTLE_ONLY_ROWS := 2
const EXPECTED_CODEX_CHARACTER_PORTRAIT_SIZE := Vector2(216.0, 216.0)
const DUPLICATE_ARTIFACT_SKIP_DIRS := [".godot", ".git", "tmp", "node_modules"]
const DUPLICATE_ARTIFACT_SKIP_PATH_PREFIXES := ["res://build/dmg"]
const DUPLICATE_ARTIFACT_PATTERN := " 2(\\.|$)"

func _initialize() -> void:
	if not _test_no_space_number_duplicate_artifacts():
		quit(1)
		return

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
	await _test_glossary_terms(main)
	var main_menu_background := main.find_child("MainMenuBackground", true, false) as TextureRect
	if main_menu_background == null or main_menu_background.texture == null or main_menu_background.texture.resource_path != "res://assets/backgrounds/main_menu_epic_battle_v2.png":
		push_error("Expected main menu to render the v2 epic battle background image.")
		quit(1)
		return
	var main_menu_actions := main.find_child("MainMenuActions", true, false) as VBoxContainer
	if main_menu_actions == null or main_menu_actions.get_child_count() != 6:
		push_error("Expected main menu to expose six action buttons (start, settings, skill tree, what's new, codex, exit).")
		quit(1)
		return
	for required_button in ["MainMenuStartButton", "MainMenuSettingsButton", "MainMenuSkillTreeButton", "MainMenuPatchNotesButton", "MainMenuCodexButton", "MainMenuExitButton"]:
		if main.find_child(required_button, true, false) == null:
			push_error("Expected main menu to expose %s." % required_button)
			quit(1)
			return
	var start_theme_button := main.find_child("MainMenuStartButton", true, false) as Button
	var settings_theme_button := main.find_child("MainMenuSettingsButton", true, false) as Button
	var exit_theme_button := main.find_child("MainMenuExitButton", true, false) as Button
	if not _button_uses_minimal_metal_type(start_theme_button, "main_menu") or not _button_uses_minimal_metal_type(settings_theme_button, "main_menu") or not _button_uses_minimal_metal_type(exit_theme_button, "main_menu"):
		push_error("Expected main menu buttons to use canonical minimal-metal state textures.")
		quit(1)
		return
	await _test_back_button_frame_safety(main_scene)
	await _test_main_menu_quit_confirmation(main_scene)
	await _test_feedback_overlay_and_local_fallback(main_scene)
	if main_menu_actions.global_position.x > 140.0:
		push_error("Expected main menu buttons to stay on the left side of the start screen.")
		quit(1)
		return
	# Тексты кнопок не ассертим списком: «Что нового» несёт бейдж-маркер; проверка по именам выше.

	var route_nodes: Array = main.get("route_nodes")
	# 10 рядов активностей + финальный ряд босса.
	if route_nodes.size() != 11:
		push_error("Expected the vertical route to have 10 activity rows plus a boss row.")
		quit(1)
		return
	if str(route_nodes[route_nodes.size() - 1][0].get("type", "")) != "boss":
		push_error("Expected the last vertical route row to be boss-only.")
		quit(1)
		return
	for early_step_index in range(mini(ROUTE_START_BATTLE_ONLY_ROWS, route_nodes.size() - 1)):
		for route_node in route_nodes[early_step_index]:
			if str(route_node.get("type", "")) != "battle":
				push_error("Expected route row %d to contain only normal battle nodes before noncombat route nodes can appear." % early_step_index)
				quit(1)
				return
	if not _assert_route_shop_distribution(route_nodes, "initial route"):
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
		"res://assets/backgrounds/ui/ui_backdrop_system_cathedral.png",
		"res://assets/backgrounds/ui/ui_backdrop_merchant_archive.png",
		"res://assets/backgrounds/ui/ui_backdrop_arcane_lab.png",
		"res://assets/backgrounds/ui/ui_backdrop_reward_hall.png",
		"res://assets/backgrounds/ui/ui_backdrop_defeat_crypt.png",
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
	await _test_shop_reentry_until_next_level(main_scene)
	await _test_run_autosave_continue_prompt(main_scene)
	await _test_random_event_data_and_outcomes(main_scene)
	var generated_elite := false
	var generated_disk_boss := false
	# Детерминированный reseed: с ростером из 5 боссов (SCRUM-155) disk_devourer
	# выпадает ~1/5, поэтому фикс. seed + достаточная выборка вместо хрупких 20.
	(main.get("rng") as RandomNumberGenerator).seed = 8675309
	for _attempt in range(45):
		var generated_route: Array = main.call("_generate_route")
		for early_step_index in range(mini(ROUTE_START_BATTLE_ONLY_ROWS, generated_route.size() - 1)):
			for route_node in generated_route[early_step_index]:
				if str(route_node.get("type", "")) != "battle":
					push_error("Expected every generated route row %d to contain only battle nodes." % early_step_index)
					quit(1)
					return
		if not _assert_route_shop_distribution(generated_route, "generated route attempt %d" % _attempt):
			quit(1)
			return
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
	if not _has_screen_background(main, "settings"):
		push_error("Expected settings screen to use the system/cathedral screen backdrop.")
		quit(1)
		return
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
	await process_frame
	var hero_screen := main.find_child("HeroSelectScreen", true, false) as Control
	if hero_screen == null:
		push_error("Expected character select to use a fullscreen hero select root.")
		quit(1)
		return
	# Выбор героя v4 native layout (SCRUM-470): live panels over the canonical hero_select backdrop.
	if not _has_screen_background(main, "hero_select"):
		push_error("Expected hero select v4 to use the canonical hero_select screen backdrop.")
		quit(1)
		return
	var v4_portrait := main.find_child("HS4Portrait", true, false) as TextureRect
	if v4_portrait == null or v4_portrait.texture == null:
		push_error("Expected hero select v4 to show the selected hero portrait.")
		quit(1)
		return
	var v4_radar := main.find_child("HS4Radar", true, false) as Control
	if v4_radar == null:
		push_error("Expected hero select v4 to build a stat radar.")
		quit(1)
		return
	var v4_carousel := main.find_child("HS4Carousel", true, false) as Control
	if v4_carousel == null or _visible_texture_button_count(v4_carousel) < HERO_SELECT_V4_VISIBLE_SLOTS:
		push_error("Expected hero select v4 to expose a scrollable carousel with slots and arrows.")
		quit(1)
		return
	var v4_choose := main.find_child("HS4ChooseButton", true, false) as Button
	if v4_choose == null:
		push_error("Expected hero select v4 to expose a choose button.")
		quit(1)
		return
	main.set("selected_character_id", "berserk")
	v4_choose.pressed.emit()
	await process_frame
	if main.find_child("HeroSelectScreen", true, false) != null:
		push_error("Expected hero choose button to advance to weapon select.")
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
	var resource_style := resource_hud.get_theme_stylebox("panel")
	if _stylebox_texture_path(resource_style) != MINIMAL_HUD_STRIP_TEXTURE:
		push_error("Expected combat resource HUD to use the SCRUM-448 minimal HUD strip frame.")
		quit(1)
		return
	var expected_hud_cards := {
		"HudHPCard": MINIMAL_FIELD_TEXTURE,
		"HudXPCard": MINIMAL_FIELD_TEXTURE,
		"HudMoneyCard": MINIMAL_FIELD_TEXTURE,
		"HudULTCard": MINIMAL_FIELD_TEXTURE,
	}
	for hud_node_name in ["HudHPCard", "HudXPCard", "HudMoneyCard"]:
		if resource_hud.find_child(hud_node_name, true, false) == null:
			push_error("Expected combat resource HUD to include %s." % hud_node_name)
			quit(1)
			return
	for hud_node_name in expected_hud_cards.keys():
		var hud_card := resource_hud.find_child(str(hud_node_name), true, false) as PanelContainer
		if hud_card == null or _stylebox_texture_path(hud_card.get_theme_stylebox("panel")) != str(expected_hud_cards[hud_node_name]):
			push_error("Expected %s to use SCRUM-448 minimal field frame %s." % [hud_node_name, str(expected_hud_cards[hud_node_name])])
			quit(1)
			return
	var expected_hud_fills := {
		"HudHPBar": "res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_hp.png",
		"HudXPBar": "res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_xp.png",
		"HudULTBar": "res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_ult.png",
	}
	for bar_name in expected_hud_fills.keys():
		var hud_bar := resource_hud.find_child(str(bar_name), true, false) as ProgressBar
		if hud_bar == null or _stylebox_texture_path(hud_bar.get_theme_stylebox("fill")) != str(expected_hud_fills[bar_name]):
			push_error("Expected %s to use SCRUM-390 bar fill %s." % [bar_name, str(expected_hud_fills[bar_name])])
			quit(1)
			return
	for hud_icon_id in ["hp", "xp", "money"]:
		var hud_icon := resource_hud.find_child("UIIcon_%s" % hud_icon_id, true, false) as TextureRect
		if hud_icon == null or hud_icon.texture == null:
			push_error("Expected combat HUD icon %s to use a PNG texture." % hud_icon_id)
			quit(1)
			return
	if (resource_hud.find_child("UIIcon_money", true, false) as TextureRect).texture.resource_path != "res://assets/sprites/ui/hud/combat_hud/ui_hud_gold_medallion.png":
		push_error("Expected combat money HUD icon to use the SCRUM-390 gold medallion.")
		quit(1)
		return
	if main.get("status_label") != null:
		push_error("Expected combat HUD to stay compact and not expose the status label.")
		quit(1)
		return
	# Таймер боя: по центру сверху, при <=5с переходит в alarm-состояние (PM 2026-06-11).
	var timer_panel := main.find_child("CombatTimerPanel", true, false) as PanelContainer
	var timer_text := main.get("timer_label") as Label
	if timer_panel == null or timer_text == null or timer_panel.get_global_rect().position.y > 24.0:
		push_error("Expected the combat timer panel to stay in the top HUD band.")
		quit(1)
		return
	if _stylebox_texture_path(timer_panel.get_theme_stylebox("panel")) != MINIMAL_FIELD_TEXTURE:
		push_error("Expected combat timer panel to use the SCRUM-448 minimal field frame.")
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
	var hud_player: Node = main.get("current_player")
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

	var player: Node = main.get("current_player")
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
	if player_body == null or absf(player_body.scale.x - EXPECTED_PLAYER_COMBAT_VISUAL_SCALE) > 0.001 or absf(player_body.scale.y - EXPECTED_PLAYER_COMBAT_VISUAL_SCALE) > 0.001:
		push_error("Expected player visual scale to match combat scale %.3f (SCRUM-518 −15%%)." % EXPECTED_PLAYER_COMBAT_VISUAL_SCALE)
		quit(1)
		return
	var player_rig := player.get_node_or_null("VisualRoot/RigRoot") as Node2D
	if not player_body.visible or player_rig == null or player_rig.visible:
		push_error("Expected selected full-frame player Body to be visible with hidden cutout RigRoot.")
		quit(1)
		return
	var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_shape := player_collision.shape as CircleShape2D
	if player_shape == null or player_shape.radius > 11.0:
		push_error("Expected player hurtbox to match the smaller character size.")
		quit(1)
		return
	var scrum417_combat_qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum417")
	DirAccess.make_dir_recursive_absolute(scrum417_combat_qa_dir)
	var scrum417_combat_dump := PackedStringArray()
	scrum417_combat_dump.append("# SCRUM-417 Combat Character Size Runtime Dump")
	scrum417_combat_dump.append("")
	scrum417_combat_dump.append("- `PlayerVisualScale`: `%s`" % str(player_body.scale))
	scrum417_combat_dump.append("- `PlayerBodyVisible`: `%s`" % str(player_body.visible))
	scrum417_combat_dump.append("- `PlayerRigVisible`: `%s`" % str(player_rig.visible))
	scrum417_combat_dump.append("- `PlayerCollisionRadius`: `%.2f`" % player_shape.radius)
	var scrum417_combat_file := FileAccess.open("%s/combat_character_size_runtime_dump.md" % scrum417_combat_qa_dir, FileAccess.WRITE)
	if scrum417_combat_file != null:
		scrum417_combat_file.store_string("\n".join(scrum417_combat_dump))
		scrum417_combat_file.close()
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
		push_error("Expected player to start at the center of the arena.")
		quit(1)
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or camera.limit_left != 0 or camera.limit_top != 0 or camera.limit_right != int(EXPECTED_ARENA_SIZE.x) or camera.limit_bottom != int(EXPECTED_ARENA_SIZE.y):
		push_error("Expected player camera limits to match arena bounds.")
		quit(1)
		return
	if camera.zoom.x < 1.05 or camera.zoom.y < 1.05:
		push_error("Expected player camera to be zoomed in enough that the arena is not fully visible.")
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
	contact_enemy.set("max_health", 100000.0)
	contact_enemy.set("health", 100000.0)
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
	cleanup_enemy_projectile.global_position = Vector2(3600, 2000)  # SCRUM-518: внутри расширенной арены 4096×2304
	if bool(cleanup_enemy_projectile.call("_is_outside_arena")):
		push_error("Expected enemy projectile cleanup bounds to include the expanded arena.")
		quit(1)
		return
	cleanup_enemy_projectile.global_position = Vector2(4400, 2600)  # SCRUM-518: за пределами 4096×2304 + margin
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
	cleanup_player_projectile.global_position = Vector2(3600, 2000)  # SCRUM-518: внутри расширенной арены 4096×2304
	if bool(cleanup_player_projectile.call("_is_outside_arena")):
		push_error("Expected player projectile cleanup bounds to include the expanded arena.")
		quit(1)
		return
	cleanup_player_projectile.global_position = Vector2(4400, 2600)  # SCRUM-518: за пределами 4096×2304 + margin
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
	await process_frame
	var level_up_plus_rect := level_up_plus.get_global_rect()
	var level_up_viewport_size := main.get_viewport().get_visible_rect().size
	if level_up_plus.anchor_left != 1.0 or level_up_plus.anchor_right != 1.0 or level_up_plus.anchor_top != 1.0 or level_up_plus.anchor_bottom != 1.0:
		push_error("Expected combat level-up return button to use bottom-right anchors.")
		quit(1)
		return
	if level_up_plus_rect.get_center().x < level_up_viewport_size.x * 0.68 or level_up_plus_rect.get_center().y < level_up_viewport_size.y * 0.74:
		push_error("Expected combat level-up return button to sit in the bottom-right corner, got %s in viewport %s." % [level_up_plus_rect, level_up_viewport_size])
		quit(1)
		return
	if absf(level_up_plus.modulate.a - 1.0) > 0.001:
		push_error("Expected combat level-up return button modulate alpha to be fully opaque.")
		quit(1)
		return
	var plus_normal_style := level_up_plus.get_theme_stylebox("normal")
	if plus_normal_style == null or not _button_uses_combat_hud_plus_style(level_up_plus):
		push_error("Expected combat level-up return button to use the SCRUM-390 combat HUD plus button kit.")
		quit(1)
		return
	if not _is_neutral_button_font(level_up_plus.get_theme_color("font_hover_color")) or not _is_neutral_button_font(level_up_plus.get_theme_color("font_focus_color")):
		push_error("Expected combat level-up return button hover/focus font colors to be neutral near-white.")
		quit(1)
		return
	if plus_normal_style is StyleBoxTexture and (plus_normal_style as StyleBoxTexture).modulate_color.a < 0.999:
		push_error("Expected combat level-up return button background style to be opaque.")
		quit(1)
		return
	var plus_layout_controls := [level_up_plus]
	for control in _visible_hud_top_controls(main):
		plus_layout_controls.append(control)
	var upgrade_fab := main.find_child("UpgradeFabButton", true, false) as Control
	if upgrade_fab != null and upgrade_fab.visible:
		plus_layout_controls.append(upgrade_fab)
	var plus_overlap := _first_control_overlap(plus_layout_controls, 2.0)
	if not plus_overlap.is_empty():
		push_error("Expected combat level-up return button not to overlap HUD controls, got %s." % plus_overlap)
		quit(1)
		return
	var level_up_badge_panel := level_up_plus.find_child("LevelUpPlusBadgePanel", true, false) as Control
	var qa_dir_level_up := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(qa_dir_level_up)
	var level_up_dump_text := ""
	var level_up_dump := FileAccess.open("%s/combat_level_up_button.md" % qa_dir_level_up, FileAccess.WRITE)
	if level_up_dump != null:
		var plus_texture := (plus_normal_style as StyleBoxTexture).texture if plus_normal_style is StyleBoxTexture else null
		level_up_dump_text = "# Combat Level-Up Return Button\n\n- Viewport: `%s`\n- Button: `%s`\n- Badge: `%s`\n- Alpha: `%.3f`\n- Texture: `%s`\n" % [str(level_up_viewport_size), str(level_up_plus_rect), str(level_up_badge_panel.get_global_rect() if level_up_badge_panel != null else Rect2()), level_up_plus.modulate.a, str(plus_texture.resource_path if plus_texture != null else "")]
		level_up_dump.store_string(level_up_dump_text)
		level_up_dump.close()
	var scrum390_level_up_dir := ProjectSettings.globalize_path("res://build/qa/scrum390")
	DirAccess.make_dir_recursive_absolute(scrum390_level_up_dir)
	var scrum390_level_up_dump := FileAccess.open("%s/combat_level_up_button.md" % scrum390_level_up_dir, FileAccess.WRITE)
	if scrum390_level_up_dump != null:
		if level_up_dump_text == "":
			level_up_dump_text = "# Combat Level-Up Return Button\n\n- Viewport: `%s`\n- Button: `%s`\n- Badge: `%s`\n- Alpha: `%.3f`\n- Texture: `%s`\n" % [str(level_up_viewport_size), str(level_up_plus_rect), str(level_up_badge_panel.get_global_rect() if level_up_badge_panel != null else Rect2()), level_up_plus.modulate.a, _stylebox_texture_path(plus_normal_style)]
		scrum390_level_up_dump.store_string(level_up_dump_text)
		scrum390_level_up_dump.close()
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
	var level_up_portrait := _expected_character_portrait_path(str(main.get("selected_character_id")))
	if level_up_hero.texture.resource_path != level_up_portrait:
		push_error("Expected level-up hero portrait to use new full-frame portrait %s, got %s." % [level_up_portrait, level_up_hero.texture.resource_path])
		quit(1)
		return
	# SCRUM-149: ровно 3 варианта за уровень.
	var level_up_buttons := level_up_overlay.find_children("LevelUpRewardButton*", "Button", true, false)
	if level_up_buttons.size() != 3:
		push_error("Expected level-up to animate exactly three reward buttons.")
		quit(1)
		return
	for button_index in range(level_up_buttons.size()):
		var reward_button := level_up_buttons[button_index] as Button
		var button_rect := reward_button.get_global_rect()
		if button_rect.size.x < 190.0 or button_rect.size.y < 120.0:
			push_error("Expected level-up reward buttons to keep readable card dimensions.")
			quit(1)
			return
		if reward_button.find_child("UIIcon_*", true, false) == null:
			push_error("Expected each level-up reward button to show a stat or artifact icon.")
			quit(1)
			return
		if not bool(reward_button.get_meta("level_up_text_field_card", false)):
			push_error("Expected level-up reward cards to be styled as clickable text-field panels.")
			quit(1)
			return
		if reward_button.get_theme_stylebox("normal") is StyleBoxTexture or reward_button.get_theme_stylebox("hover") is StyleBoxTexture:
			push_error("Expected level-up reward cards to avoid heavy reward button frame textures.")
			quit(1)
			return
		var description_label := reward_button.find_child("LevelUpRewardDescription", true, false) as Label
		if description_label == null or description_label.text.strip_edges() == "":
			push_error("Expected level-up reward cards to expose readable description text.")
			quit(1)
			return

	# Escape поверх level-up открывает единое меню забега, а досье доступно кнопкой.
	var pause_escape := InputEventKey.new()
	pause_escape.keycode = KEY_ESCAPE
	pause_escape.pressed = true
	main.call("_input", pause_escape)
	await process_frame
	if main.find_child("RunPauseMenuRoot", true, false) == null:
		push_error("Expected Escape on level-up to open the run pause menu.")
		quit(1)
		return
	var dossier_button := main.find_child("RunPauseDossierButton", true, false) as Button
	if dossier_button == null:
		push_error("Expected run pause menu to expose a character dossier button.")
		quit(1)
		return
	dossier_button.pressed.emit()
	await process_frame
	if main.find_child("PauseStatsMenuRoot", true, false) == null:
		push_error("Expected dossier button to open the character dossier overlay.")
		quit(1)
		return
	if main.find_child("PriorityBadge_strength", true, false) == null:
		push_error("Expected pause dossier to highlight Berserk priority attributes.")
		quit(1)
		return
	if (main.get("ui_layer") as CanvasLayer).get_node_or_null("LevelUpOverlay") == null:
		push_error("Expected level-up overlay to remain underneath the pause dossier.")
		quit(1)
		return
	var pause_close := InputEventKey.new()
	pause_close.keycode = KEY_ESCAPE
	pause_close.pressed = true
	main.call("_input", pause_close)
	await process_frame
	if main.find_child("RunPauseMenuRoot", true, false) != null or main.find_child("PauseStatsMenuRoot", true, false) != null:
		push_error("Expected second Escape to close the run pause overlay.")
		quit(1)
		return
	if (main.get("ui_layer") as CanvasLayer).get_node_or_null("LevelUpOverlay") == null:
		push_error("Expected closing the dossier to preserve the level-up overlay.")
		quit(1)
		return

	# Отложенный выбор: нижняя кнопка закрывает окно БЕЗ траты пика (пик сохраняется),
	# внизу появляется заметная кнопка возврата к тому же набору.
	var pending_before_defer := int(main.get("pending_level_ups"))
	var defer_button := main.find_child("LevelUpLaterButton", true, false) as Button
	if defer_button == null:
		push_error("Expected level-up to expose a bottom button for deferred choice.")
		quit(1)
		return
	var defer_rect := defer_button.get_global_rect()
	if defer_rect.size.x < 250.0 or defer_rect.size.y < 70.0 or not _button_uses_minimal_metal_type(defer_button, "back_m"):
		push_error("Expected level-up Later button to use a non-cropped compact medium back frame, got rect=%s min=%s." % [str(defer_rect), str(defer_button.custom_minimum_size)])
		quit(1)
		return
	defer_button.pressed.emit()
	await process_frame
	if bool(main.call("_has_pause_reason", "level_up")):
		push_error("Expected Esc to defer (close) the level-up without keeping it paused.")
		quit(1)
		return
	if int(main.get("pending_level_ups")) != pending_before_defer:
		push_error("Expected deferred level-up to preserve the unspent pick.")
		quit(1)
		return
	var return_button := main.find_child("LevelUpPlusButton", true, false) as Button
	if return_button == null or return_button.text != "+" or not _button_uses_combat_hud_plus_style(return_button):
		push_error("Expected a SCRUM-390 level-up plus return button after deferring.")
		quit(1)
		return
	# Возврат к тому же зафиксированному набору.
	main.call("_open_pending_level_up")
	await process_frame
	var reopened := (main.get("ui_layer") as CanvasLayer).get_node_or_null("LevelUpOverlay")
	if reopened == null or reopened.find_children("LevelUpRewardButton*", "Button", true, false).size() != 3:
		push_error("Expected the return button to reopen the same fixed set of three rewards.")
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
	if main.find_child("RunPauseMenuRoot", true, false) == null:
		push_error("Expected Esc to open the unified run pause menu.")
		quit(1)
		return
	var run_pause_panel := main.find_child("RunPauseMenuPanel", true, false) as PanelContainer
	if run_pause_panel == null or _stylebox_texture_path(run_pause_panel.get_theme_stylebox("panel")) != MINIMAL_MODAL_TEXTURE:
		push_error("Expected run pause menu to use the SCRUM-448 minimal modal frame.")
		quit(1)
		return
	var pause_dossier_button := main.find_child("RunPauseDossierButton", true, false) as Button
	if pause_dossier_button == null:
		push_error("Expected run pause menu to provide a character dossier button.")
		quit(1)
		return
	pause_dossier_button.pressed.emit()
	await process_frame
	var pause_menu: Node = main.get("pause_stats_menu")
	if pause_menu == null or not is_instance_valid(pause_menu):
		push_error("Expected dossier button to open pause stats menu.")
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
	if derived_groups.columns < 1 or derived_groups.columns > 2 or derived_groups.get_child_count() < 5:
		push_error("Expected derived stats to be organized into responsive compact logical groups.")
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
	if _stylebox_texture_path(escape_panel.get_theme_stylebox("panel")) != MINIMAL_MODAL_TEXTURE:
		push_error("Expected pause dossier/stats panel shell to use the SCRUM-448 minimal modal frame.")
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
	if not _button_uses_minimal_metal_type(resume_button, "pause"):
		push_error("Expected Escape menu buttons to use neutral minimal-metal hover/focus states.")
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
	if paused or main.get("pause_stats_menu") != null or main.find_child("RunPauseMenuRoot", true, false) != null:
		push_error("Expected second Esc to close run pause overlay and resume combat.")
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
	var attribute_offers := main.find_child("AttributeOffers", true, false) as Container
	if attribute_offers == null or attribute_offers.get_child_count() < 2 or attribute_offers.get_child_count() > 8:
		push_error("Expected 2-8 attribute offers in the post-battle window, including meta skill extra options.")
		quit(1)
		return
	if _stylebox_texture_path((attribute_panel as PanelContainer).get_theme_stylebox("panel")) != MINIMAL_PANEL_TEXTURE:
		push_error("Expected attribute shop panel to use the SCRUM-448 minimal panel frame.")
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
	if first_offer == null or _stylebox_texture_path(first_offer.get_theme_stylebox("normal")) != ECONOMY_CHOICE_WIDE_TEXTURE:
		push_error("Expected attribute offers to use the SCRUM-448 minimal card frame.")
		quit(1)
		return
	if _stylebox_texture_path(first_offer.get_theme_stylebox("hover")) != ECONOMY_CHOICE_WIDE_HOVER_TEXTURE:
		push_error("Expected attribute offers to use the SCRUM-448 minimal hover card frame.")
		quit(1)
		return
	_write_scrum437_attribute_offer_dump(attribute_panel as Control, attribute_offers)
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
	var expected_round_duration := (30.0 + float(main.get("route_stage")) * 3.0) * float((main.call("ascension_difficulty") as Dictionary).get("round_duration_mult", 1.0))
	if abs(float(main.call("_current_round_duration")) - expected_round_duration) > 0.01:
		push_error("Expected next round duration to include stage and ascension scaling.")
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
	_test_weapon_orbit_no_overlap()
	_test_class_weapon_configs()
	_test_class_weapon_mode_registry()
	_test_all_weapon_variants_equip()
	await _test_weapon_effect_cleanup()
	await _test_victory_flow(main)
	await _test_elite_flow(main_scene)
	await _test_debug_free_pick(main_scene)
	await _test_debug_combat_click_to_move(main_scene)
	await _test_codex_screen(main_scene)
	await _test_escape_navigation(main_scene)
	await _test_economy_tiers_and_fab(main_scene)
	await _test_ascension_difficulty_ladder(main_scene)
	await _test_class_relevance_and_offer_fixation(main_scene)
	_test_settings_persistence_and_audio()
	await _test_full_attribute_wiring()
	_test_attribute_weapon_synergy_matrix()
	await _test_all_playable_classes()
	await _test_soldier_weapon_mechanics()
	await _test_thief_weapon_mechanics()
	await _test_elementalist_weapon_mechanics()
	await _test_sniper_weapon_mechanics()
	await _test_priest_weapon_mechanics()
	await _test_biologist_weapon_mechanics()
	await _test_robot_weapon_mechanics()
	await _test_engineer_weapon_mechanics()
	_test_unique_encounter_pattern_catalog()
	await _test_elite_unique_attacks()
	await _test_weapon_aiming()
	await _test_no_auto_player_movement_from_crit_or_dodge()
	await _test_class_weapon_rework()
	await _test_unique_class_identity_patterns()
	_test_class_mechanic_identity_framework()
	await _test_universal_attribute_interpretations()
	_test_class_budget_profiles()
	await _test_enemy_stage_scaling_and_elite_rewards(main_scene)
	await _test_ultimate_framework()
	await _test_death_flow(main_scene)
	await _test_epic_elite_boss_scale_hitbox()
	await _test_elite_phase2_escalation()
	await _test_boss_zone_wave_safe_corridor()
	await _test_elite_boss_presentation(main_scene)
	await _test_boss_hud_omits_timer(main_scene)
	await _test_weapon_select_clean_layout(main_scene)
	await _test_parchment_button_seal_sizes(main_scene)
	await _test_skill_tree_progression_kit(main_scene)
	await _test_hero_select_radar_no_overlap_layouts(main_scene)
	await _test_shop_wall_no_overlap_layouts(main_scene)
	await _test_hud_no_overlap_layouts(main_scene)
	await _test_mini_elite_roster(main_scene)
	await _test_new_boss_roster(main_scene)

	print("Runtime smoke test passed.")
	quit()


func _test_glossary_terms(main: Node) -> void:
	var term_ids: Array = Glossary.term_ids()
	if term_ids.size() < 24:
		_fail("Expected the Russian glossary to cover core stats and mechanics, got %d terms." % term_ids.size())
		return
	for term_id in term_ids:
		var definition: Dictionary = Glossary.definition(str(term_id))
		if str(definition.get("name", "")) == "" or str(definition.get("desc", "")) == "":
			_fail("Expected glossary term %s to include Russian name and description." % str(term_id))
			return
	var button := main.ui._make_glossary_term_button("crit", false) as Button
	button.position = Vector2(24, 120)
	(main.get("ui_layer") as CanvasLayer).add_child(button)
	await process_frame
	if button.find_child("GlossaryDottedUnderline", true, false) == null:
		_fail("Expected glossary terms to expose a dotted underline marker.")
		return
	if not button.tooltip_text.contains("Критический удар"):
		_fail("Expected normal-screen glossary term to expose hover tooltip text.")
		return
	await main.ui._show_glossary_tooltip(button, "crit")
	await process_frame
	var tooltip := main.find_child("GlossaryTooltipPanel", true, false) as PanelContainer
	if tooltip == null or not _collect_label_text(tooltip).contains("Критический удар"):
		_fail("Expected glossary hover to create a tooltip panel with the term name.")
		return
	if _stylebox_texture_path(tooltip.get_theme_stylebox("panel")) != MINIMAL_TOOLTIP_TEXTURE:
		_fail("Expected glossary tooltip to use the SCRUM-448 minimal tooltip frame texture.")
		return
	main.ui._hide_glossary_tooltip()
	button.queue_free()
	await process_frame


func _test_new_boss_roster(main_scene: PackedScene) -> void:
	# SCRUM-155 ч.2: 3 новых босса — сцены валидны, behavior уникален, атаки
	# тикают без ошибок (телеграф-зоны создаются), ротация маршрута из 5.
	var m := main_scene.instantiate()
	root.add_child(m)
	await process_frame
	var expected := {
		"rift_warden": "",
		"disk_devourer": "",
		"bone_archon": "Костяной Архонт",
		"brood_mother": "Матерь Роя",
		"ashen_colossus": "Пепельный Колосс",
	}
	var expected_unique_nodes := {
		"rift_warden": "BossGravityWell",
		"disk_devourer": "BossVampiricBite",
		"bone_archon": "BossRiftZone",
		"brood_mother": "BroodWebZone",
		"ashen_colossus": "BossMoltenArmorPulse",
	}
	for boss_id in expected.keys():
		var scene: PackedScene = m.combat.call("_boss_scene_for_id", boss_id)
		if scene == null:
			_fail("Expected boss scene for '%s'." % boss_id)
			return
		var holder := Node2D.new()
		root.add_child(holder)
		current_scene = holder
		var boss := scene.instantiate() as Node2D
		holder.add_child(boss)
		await process_frame
		if str(boss.get("boss_behavior")) != boss_id:
			_fail("Expected boss behavior '%s', got '%s'." % [boss_id, str(boss.get("boss_behavior"))])
			return
		if str(expected[boss_id]) != "" and str(boss.get("boss_display_name")) != str(expected[boss_id]):
			_fail("Expected Russian display name for '%s'." % boss_id)
			return
		if str(boss.get_meta("unique_pattern_id", "")) != boss_id:
			_fail("Expected boss '%s' to expose its unique encounter pattern meta." % boss_id)
			return
		var boss_mechanics: Array = boss.get_meta("unique_mechanics", []) as Array
		if boss_mechanics.size() < 3:
			_fail("Expected boss '%s' to expose at least 3 unique mechanics." % boss_id)
			return
		var expected_boss_scale: float = float(ProgressionData.enemy_size_profile("boss").get("scale", 1.9))
		if absf(boss.scale.x - expected_boss_scale) > 0.01:
			_fail("Expected epic boss scale %.2f for '%s'." % [expected_boss_scale, boss_id])
			return
		# Игрок рядом + прогон атак: хазард-зоны телеграфятся без ошибок.
		var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
		holder.add_child(player)
		player.add_to_group("player")
		player.global_position = boss.global_position + Vector2(120 if boss_id == "disk_devourer" else 280, 0)
		await process_frame
		boss.set("_boss_unique_cooldown", 0.0)
		boss.call("_update_boss_attacks", 0.1)
		await process_frame
		if holder.find_child(str(expected_unique_nodes[boss_id]), true, false) == null:
			_fail("Expected boss '%s' unique mechanic to spawn %s." % [boss_id, str(expected_unique_nodes[boss_id])])
			return
		var hazards_before := holder.find_children("*", "Node2D", true, false).size()
		for _tick in range(220):
			boss.call("_update_boss_attacks", 0.05)
		await process_frame
		if holder.find_children("*", "Node2D", true, false).size() <= hazards_before:
			_fail("Expected boss '%s' attack rotation to spawn hazards/summons." % boss_id)
			return
		# Фазы переключаются от потери HP.
		boss.set("health", float(boss.get("max_health")) * 0.30)
		boss.call("_update_boss_phase")
		if int(boss.get("boss_phase")) < 3:
			_fail("Expected boss '%s' to reach phase 3 at 30%% HP." % boss_id)
			return
		holder.queue_free()
		current_scene = null
		await process_frame
	# Ротация маршрута: пул финального узла включает всех 5.
	var seen_bosses := {}
	for _roll in range(120):
		var node: Dictionary = m.route.call("_random_boss_route_node")
		seen_bosses[str(node.get("boss_id", ""))] = true
	for boss_id in ["rift_warden", "disk_devourer", "bone_archon", "brood_mother", "ashen_colossus"]:
		if not seen_bosses.has(boss_id):
			_fail("Expected boss rotation to include '%s'." % boss_id)
			return
	m.queue_free()
	await process_frame


func _test_unique_encounter_pattern_catalog() -> void:
	var catalog: Dictionary = ProgressionData.enemy_mechanic_catalog()
	for required_id in ["aura_buff", "summon_retinue", "blink_reposition", "hazard_pool", "poison_dot", "shield_block", "charge_telegraph", "reflect_thorns", "slow_zone", "vampirism", "rift_wave", "mirror_double", "gravity_pull", "weakpoint_shell", "healing_inversion", "split_spawn"]:
		if not catalog.has(required_id):
			_fail("Expected enemy mechanic catalog to include %s." % required_id)
			return
	var patterns: Dictionary = ProgressionData.unique_encounter_patterns()
	var expected_entities := ["iron_bastion", "night_stalker", "plague_prophet", "shard_marshal", "rift_warden", "disk_devourer", "bone_archon", "brood_mother", "ashen_colossus"]
	var seen_signatures := {}
	for entity_id in expected_entities:
		var pattern: Dictionary = ProgressionData.unique_encounter_pattern(entity_id)
		if pattern.is_empty():
			_fail("Expected unique encounter pattern for %s." % entity_id)
			return
		var mechanics: Array = pattern.get("mechanics", []) as Array
		if mechanics.size() < 3:
			_fail("Expected %s to have at least 3 mechanics." % entity_id)
			return
		for mechanic_id in mechanics:
			if not catalog.has(str(mechanic_id)):
				_fail("Expected %s mechanic %s to exist in catalog." % [entity_id, str(mechanic_id)])
				return
		var signature_parts := PackedStringArray()
		for mechanic_id in mechanics:
			signature_parts.append(str(mechanic_id))
		var signature := ",".join(signature_parts)
		if seen_signatures.has(signature):
			_fail("Expected unique mechanic signature for %s; duplicated %s." % [entity_id, str(seen_signatures[signature])])
			return
		seen_signatures[signature] = entity_id


func _test_mini_elite_roster(main_scene: PackedScene) -> void:
	# SCRUM-155: 6 data-driven видов мини-элиток — валидные поля, маппинг сцен,
	# HP-бюджет «мини» (0 < hp_mult < 1: убиваемы, не полная элитка).
	var m := main_scene.instantiate()
	root.add_child(m)
	await process_frame
	var kinds: Array = m.get("PROGRESSION_DATA").call("mini_elite_kinds")
	if kinds.size() != 6:
		_fail("Expected 6 mini-elite kinds in the roster, got %d." % kinds.size())
		return
	var seen := {}
	for entry in kinds:
		var kind: Dictionary = entry
		for field in ["id", "title", "scene", "hp_mult", "tint", "desc"]:
			if not kind.has(field):
				_fail("Mini-elite kind missing field '%s'." % field)
				return
		var kind_id := str(kind["id"])
		if seen.has(kind_id):
			_fail("Duplicate mini-elite kind id '%s'." % kind_id)
			return
		seen[kind_id] = true
		if m.combat.call("_elite_scene_by_key", str(kind["scene"])) == null:
			_fail("Mini-elite kind '%s' maps to unknown scene key '%s'." % [kind_id, str(kind["scene"])])
			return
		var hp_mult := float(kind["hp_mult"])
		if hp_mult <= 0.0 or hp_mult >= 1.0:
			_fail("Expected mini-elite '%s' hp_mult in (0,1), got %f." % [kind_id, hp_mult])
			return
		# Тинт — RGB-триплет для различимости placeholder-спрайта.
		if (kind["tint"] as Array).size() < 3:
			_fail("Expected mini-elite '%s' tint to be an RGB triplet." % kind_id)
			return
	m.queue_free()
	await process_frame


func _test_elite_boss_presentation(main_scene: PackedScene) -> void:
	# Подача: баннер появления элитки + hit-stop (замедление времени и возврат).
	var pm := main_scene.instantiate()
	root.add_child(pm)
	await process_frame
	pm.set("selected_character_id", "berserk")
	pm.call("_start_combat")
	await process_frame

	pm.combat.call("_spawn_elite_enemy")
	await process_frame
	if pm.find_child("CombatIntroBanner", true, false) == null:
		_fail("Expected elite spawn to flash an intro banner.")
		return

	# Hit-stop: time_scale падает, затем восстанавливается (восстанавливаем до
	# любых ассертов, чтобы не оставить замедление следующим тестам).
	pm.combat.call("_hit_stop", 0.3, 0.3)
	var slowed := Engine.time_scale < 0.99
	pm.combat.call("_restore_time_scale")
	if not slowed:
		_fail("Expected hit-stop to slow time scale on elite/boss death.")
		return
	if absf(Engine.time_scale - 1.0) > 0.001:
		_fail("Expected time scale to restore to 1.0 after hit-stop.")
		return

	pm.queue_free()
	await process_frame


func _test_boss_zone_wave_safe_corridor() -> void:
	# +1 боссовый паттерн (волна зон) всегда оставляет безопасный коридор, и
	# _safe_radius капит любой хазард ниже полувысоты арены.
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var boss := (load("res://scenes/BossDiskDevourer.tscn") as PackedScene).instantiate() as Node2D
	holder.add_child(boss)
	await process_frame
	# safe_radius капит огромный радиус (коридор гарантирован даже на В4+).
	# SCRUM-518: cap = ARENA_SIZE.y * 0.34 — берём из EXPECTED_ARENA_SIZE (lock-step с ареной).
	if float(boss.call("_safe_radius", 9999.0)) > EXPECTED_ARENA_SIZE.y * 0.34 + 0.5:
		_fail("Expected _safe_radius to cap hazard radius for a safe corridor.")
		return
	# Волна зон: кольцо с двумя пропущенными секторами -> проход всегда есть.
	boss.call("_spawn_zone_wave", boss.global_position)
	await process_frame
	var zone_count := holder.find_children("BossRiftZone", "Node2D", true, false).size()
	if zone_count <= 0 or zone_count >= 8:
		_fail("Expected boss zone wave to leave a safe corridor (got %d of 8 sectors)." % zone_count)
		return
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_elite_phase2_escalation() -> void:
	# Фаза 2 (HP ≤ порога): уникальные атаки получают второе применение.
	# Проверяем на shard_marshal: фаза 1 — веер; фаза 2 — веер + кольцо осколков.
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	await process_frame
	var elite := (load("res://scenes/EliteArmored.tscn") as PackedScene).instantiate() as Node2D
	holder.add_child(elite)
	await process_frame
	elite.set("elite_behavior", "shard_marshal")
	elite.set("_elite_attack_direction", Vector2.RIGHT)
	elite.set("max_health", 100.0)
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	holder.add_child(player)
	player.global_position = elite.global_position + Vector2(400, 0)
	await process_frame
	var config := {"shard_count": 5, "spread_degrees": 60.0, "shard_speed": 430.0, "damage_factor": 1.0, "radius": 0.0}

	# Фаза 1: полное HP -> только веер.
	elite.set("health", 100.0)
	if bool(elite.call("_elite_in_phase2")):
		_fail("Expected full-HP elite to be in phase 1.")
		return
	var before_fan := holder.get_child_count()
	elite.call("_strike_shard_fan", config, player)
	await process_frame
	var fan_count := holder.get_child_count() - before_fan

	# Фаза 2: низкое HP -> веер + кольцо (второе применение).
	elite.set("health", 30.0)
	if not bool(elite.call("_elite_in_phase2")):
		_fail("Expected low-HP elite to enter phase 2.")
		return
	var before_ring := holder.get_child_count()
	elite.call("_strike_shard_fan", config, player)
	await process_frame
	var phase2_count := holder.get_child_count() - before_ring
	if phase2_count <= fan_count:
		_fail("Expected phase-2 shard_marshal to add a ring (fan %d vs phase2 %d)." % [fan_count, phase2_count])
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_epic_elite_boss_scale_hitbox() -> void:
	# Мини-элитки/элитки/боссы разведены по data-driven size profile; хитбоксы
	# согласованы: node scale тянет визуал +
	# CollisionShape2D + contact_range вместе. Проверяем масштаб и что collision-
	# радиус близок к видимому силуэту (нет «урона по воздуху» и непопадания вплотную).
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder

	# Базовый моб для эталонного contact_range.
	var mob := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Node2D
	holder.add_child(mob)
	await process_frame
	var mob_contact := float(mob.get("contact_range"))

	var observed_scales: Dictionary = {}
	var cases: Array[Dictionary] = [
		{"scene": "res://scenes/EliteArmored.tscn", "profile": "mini_elite"},
		{"scene": "res://scenes/EliteArmored.tscn", "profile": "elite"},
		{"scene": "res://scenes/BossDiskDevourer.tscn", "profile": "boss"},
	]
	for case: Dictionary in cases:
		var scene_path: String = str(case["scene"])
		var profile: String = str(case["profile"])
		var expected_scale: float = float(ProgressionData.enemy_size_profile(profile).get("scale", 1.0))
		var unit := (load(scene_path) as PackedScene).instantiate() as Node2D
		unit.set_meta("epic_scale_profile", profile)
		holder.add_child(unit)
		await process_frame
		if absf(unit.scale.x - expected_scale) > 0.001 or absf(unit.scale.y - expected_scale) > 0.001:
			_fail("Expected %s profile '%s' node scale %.2f, got %.2f." % [scene_path, profile, expected_scale, unit.scale.x])
			return
		observed_scales[profile] = unit.scale.x
		# Хитбокс vs силуэт: эффективный радиус CollisionShape близок к видимому.
		var shape_node := unit.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			_fail("Expected %s to keep a CollisionShape2D." % scene_path)
			return
		var effective_radius: float = float(shape_node.shape.get("radius")) * unit.scale.x
		var body := unit.get_node_or_null("Body") as Sprite2D
		if body == null:
			body = unit.get_node_or_null("Sprite2D") as Sprite2D
		var visible_radius: float = body.texture.get_size().x * body.scale.x * unit.scale.x * 0.5
		var ratio := effective_radius / maxf(visible_radius, 1.0)
		if ratio < 0.45 or ratio > 1.25:
			_fail("Expected %s collision radius to match silhouette (ratio %.2f, no air/point-blank gap)." % [scene_path, ratio])
			return
		# Контакт-урон крупнее моба (растёт с силуэтом).
		if float(unit.get("contact_range")) <= mob_contact:
			_fail("Expected %s contact_range to exceed a base mob's (%.1f vs %.1f)." % [scene_path, float(unit.get("contact_range")), mob_contact])
			return
		unit.queue_free()
	if not (float(observed_scales["mini_elite"]) < float(observed_scales["elite"]) and float(observed_scales["elite"]) < float(observed_scales["boss"])):
		_fail("Expected size order mini_elite < elite < boss, got %s." % str(observed_scales))
		return
	holder.queue_free()
	current_scene = null
	await process_frame


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


func _assert_weapon_orbit_pose(player: Node, expected_direction: Vector2, label: String) -> bool:
	player.call("play_action_animation", "attack", expected_direction)
	player.call("_apply_sprite_transform")
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	if socket == null:
		_fail("Expected %s to keep a WeaponSocket." % label)
		return false
	var body := player.get_node_or_null("VisualRoot/Body") as CanvasItem
	if body == null:
		_fail("Expected %s to keep a visible Body sibling for weapon overlap checks." % label)
		return false
	var socket_distance := socket.position.length()
	if socket_distance < 88.0:
		_fail("Expected %s weapon socket to orbit outside the hero body, got distance %.1f." % [label, socket_distance])
		return false
	if socket.z_index >= body.z_index:
		_fail("Expected %s weapon socket to render behind the hero body (socket z=%d, body z=%d)." % [label, socket.z_index, body.z_index])
		return false
	var weapon := _find_player_weapon(player)
	var weapon_canvas := weapon as CanvasItem
	if weapon_canvas != null and socket.z_index + weapon_canvas.z_index >= body.z_index:
		_fail("Expected %s weapon root effective z to stay behind the hero body." % label)
		return false
	var weapon_visual: CanvasItem = null
	if weapon != null:
		weapon_visual = weapon.get_node_or_null("WeaponVisual") as CanvasItem
	if weapon_canvas != null and weapon_visual != null and socket.z_index + weapon_canvas.z_index + weapon_visual.z_index >= body.z_index:
		_fail("Expected %s weapon visual effective z to stay behind the hero body." % label)
		return false
	var actual_direction := socket.position.normalized()
	var expected := expected_direction.normalized()
	if actual_direction.dot(expected) < 0.82:
		_fail("Expected %s weapon socket to follow attack direction %s, got %s." % [label, str(expected), str(actual_direction)])
		return false
	return true


func _write_weapon_orbit_qa_dump(player: Node, weapon: Node) -> void:
	var socket := player.get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	var body := player.get_node_or_null("VisualRoot/Body") as CanvasItem
	var weapon_canvas := weapon as CanvasItem
	var weapon_visual: CanvasItem = null
	if weapon != null:
		weapon_visual = weapon.get_node_or_null("WeaponVisual") as CanvasItem
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum455")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var lines := PackedStringArray()
	lines.append("# SCRUM-455 Weapon Orbit Runtime Dump")
	lines.append("")
	lines.append("- `Character`: `%s`" % str(player.get("character_id")))
	lines.append("- `Weapon`: `%s`" % str(weapon.name if weapon != null else ""))
	lines.append("- `WeaponParent`: `%s`" % str(weapon.get_parent().name if weapon != null and weapon.get_parent() != null else ""))
	lines.append("- `SocketPosition`: `%s`" % str(socket.position if socket != null else Vector2.ZERO))
	lines.append("- `SocketDistance`: `%.2f`" % (socket.position.length() if socket != null else 0.0))
	lines.append("- `SocketZIndex`: `%d`" % (socket.z_index if socket != null else 0))
	lines.append("- `WeaponRootZIndex`: `%d`" % (weapon_canvas.z_index if weapon_canvas != null else 0))
	lines.append("- `WeaponVisualZIndex`: `%d`" % (weapon_visual.z_index if weapon_visual != null else 0))
	lines.append("- `BodyZIndex`: `%d`" % (body.z_index if body != null else 0))
	lines.append("- `OrbitRadiusMeta`: `%.2f`" % (float(socket.get_meta("weapon_orbit_radius", 0.0)) if socket != null else 0.0))
	var file := FileAccess.open("%s/weapon_orbit_runtime_dump.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _assert_route_shop_distribution(route_nodes: Array, context: String) -> bool:
	var non_boss_rows := maxi(route_nodes.size() - 1, 0)
	var half_split := clampi(ceili(float(non_boss_rows) * 0.5), 1, maxi(non_boss_rows, 1))
	var shop_count := 0
	var first_half_shops := 0
	var second_half_shops := 0
	for row_index in range(non_boss_rows):
		var row: Array = route_nodes[row_index]
		for route_node in row:
			if str(route_node.get("type", "")) != "shop":
				continue
			shop_count += 1
			if row_index < ROUTE_START_BATTLE_ONLY_ROWS:
				push_error("Expected no shop in battle-only start row %d for %s." % [row_index, context])
				return false
			if row_index < half_split:
				first_half_shops += 1
			else:
				second_half_shops += 1
	if shop_count != 2:
		push_error("Expected exactly 2 shop nodes on %s, got %d." % [context, shop_count])
		return false
	if first_half_shops != 1 or second_half_shops != 1:
		push_error("Expected one shop in each route half for %s, got first=%d second=%d." % [context, first_half_shops, second_half_shops])
		return false
	return true


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

	# SCRUM-477 регресс: экран события не должен быть «серым/некликабельным». Опции обязаны
	# существовать, иметь хотя бы одну выбираемую (не disabled) карту, быть клавиатурно-
	# фокусируемыми, и экран должен сразу ставить фокус на опцию — иначе при сбое мыши
	# (HiDPI/слои/платформа) забег застревает без способа выбрать исход с клавиатуры.
	var selectable_event_options := 0
	var option_cursor := 0
	while true:
		var probe := route_main.find_child("EventChoiceButton%d" % option_cursor, true, false) as Button
		if probe == null:
			break
		if probe.focus_mode == Control.FOCUS_NONE:
			push_error("Expected event option %d to be keyboard-focusable." % option_cursor)
			quit(1)
			return
		if not probe.disabled:
			selectable_event_options += 1
		option_cursor += 1
	if selectable_event_options <= 0:
		push_error("Expected event screen to expose at least one selectable (non-disabled) option.")
		quit(1)
		return
	var event_focus_owner := route_main.get_viewport().gui_get_focus_owner()
	if event_focus_owner == null or not str(event_focus_owner.name).begins_with("EventChoiceButton"):
		push_error("Expected event screen to grab keyboard focus on a choice option, got %s." % (str(event_focus_owner.name) if event_focus_owner != null else "<null>"))
		quit(1)
		return

	route_main.ui._show_pause_menu()
	await process_frame
	if route_main.find_child("RunPauseMenuRoot", true, false) == null:
		push_error("Expected run pause menu to open over an event screen.")
		quit(1)
		return
	if route_main.find_child("EventScreen", true, false) == null:
		push_error("Expected event screen to remain underneath the run pause menu.")
		quit(1)
		return
	route_main.ui._resume_game()
	await process_frame
	event_choice = route_main.find_child("EventChoiceButton0", true, false) as Button
	if event_choice == null:
		push_error("Expected closing the run pause menu to preserve event choices.")
		quit(1)
		return
	var event_back_button := route_main.find_child("EventBackButton", true, false) as Button
	if event_back_button == null or not event_back_button.disabled or event_back_button.tooltip_text == "":
		push_error("Expected event screen to show a disabled Back button with explanation when skip is not allowed.")
		quit(1)
		return

	# SCRUM-530: Escape на экране события открывает run-pause ПОВЕРХ события (не no-op).
	# Проверяем через реальный _input/Escape, а не прямой вызов _show_pause_menu.
	var event_escape := InputEventKey.new()
	event_escape.keycode = KEY_ESCAPE
	event_escape.pressed = true
	route_main.call("_input", event_escape)
	await process_frame
	if route_main.find_child("RunPauseMenuRoot", true, false) == null:
		push_error("Expected Escape on the event screen to open the run pause menu (SCRUM-530).")
		quit(1)
		return
	if route_main.find_child("EventScreen", true, false) == null:
		push_error("Expected the event screen to remain under the pause menu opened via Escape (SCRUM-530).")
		quit(1)
		return
	route_main.ui._resume_game()
	await process_frame
	if route_main.find_child("EventChoiceButton0", true, false) == null:
		push_error("Expected event choices to survive an Escape→pause→resume cycle (SCRUM-530).")
		quit(1)
		return

	# SCRUM-530: level-up, открытый С УЗЛА-СОБЫТИЯ, после выбора возвращает на ТО ЖЕ событие
	# (тот же набор опций, route_stage не сдвинут, событие не подменено), а не уводит на карту.
	var event_id_before := str((route_main.get("current_event_definition") as Dictionary).get("id", ""))
	var event_stage_before := int(route_main.get("route_stage"))
	route_main.set("pending_level_ups", 1)
	route_main.ui._update_level_up_button()
	await process_frame
	if route_main.find_child("LevelUpPlusButton", true, false) == null:
		push_error("Expected a pending level-up on the event to surface the corner + button (SCRUM-530).")
		quit(1)
		return
	route_main.call("_open_pending_level_up")
	await process_frame
	var event_level_reward := route_main.find_child("LevelUpRewardButton0", true, false) as Button
	if event_level_reward == null:
		push_error("Expected opening the pending level-up from the event to show reward choices (SCRUM-530).")
		quit(1)
		return
	event_level_reward.emit_signal("pressed")
	await process_frame
	await process_frame
	if route_main.find_child("RouteMapScreen", true, false) != null:
		push_error("Expected a level-up chosen from an event to return to the event, not the route map (SCRUM-530).")
		quit(1)
		return
	if route_main.find_child("EventScreen", true, false) == null:
		push_error("Expected to land back on the event screen after resolving a level-up opened from it (SCRUM-530).")
		quit(1)
		return
	var event_id_after := str((route_main.get("current_event_definition") as Dictionary).get("id", ""))
	if event_id_after == "" or event_id_after != event_id_before:
		push_error("Expected the event to keep the same id after a level-up (no silent reroll), got '%s' vs '%s' (SCRUM-530)." % [event_id_after, event_id_before])
		quit(1)
		return
	if int(route_main.get("route_stage")) != event_stage_before:
		push_error("Expected route_stage to stay put when returning from a level-up to the event (SCRUM-530).")
		quit(1)
		return
	if int(route_main.get("pending_level_ups")) != 0:
		push_error("Expected the chosen level-up pick to be spent on return to the event (SCRUM-530).")
		quit(1)
		return
	var event_return_focus := route_main.get_viewport().gui_get_focus_owner()
	if event_return_focus == null or not str(event_return_focus.name).begins_with("EventChoiceButton"):
		push_error("Expected keyboard focus back on an event option after returning from the level-up (SCRUM-530).")
		quit(1)
		return

	event_choice = route_main.find_child("EventChoiceButton0", true, false) as Button
	if event_choice == null:
		push_error("Expected event options to be present again after returning from the level-up (SCRUM-530).")
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


func _test_shop_reentry_until_next_level(main_scene: PackedScene) -> void:
	var shop_main := main_scene.instantiate()
	root.add_child(shop_main)
	await process_frame
	shop_main.set("selected_character_id", "berserk")
	shop_main.set("selected_weapon_id", "sword")
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var shop_player := player_scene.instantiate()
	root.add_child(shop_player)
	shop_player.configure_character("berserk", "sword")
	shop_player.set("money", 5000)
	shop_main.call("_store_player_snapshot", shop_player)
	shop_player.queue_free()
	shop_main.set("route_stage", 0)
	shop_main.set("route_nodes", [
		[
			{"type": "shop", "name": "Shop 1: Test Caravan", "row": 0, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "battle", "name": "Battle 2: Test Road", "row": 1, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "boss", "name": "Rift Warden", "boss_id": "rift_warden", "row": 2, "branch": 0},
		],
	])
	shop_main.call("_show_battle_map")
	await process_frame
	await process_frame

	var route_scroll := shop_main.find_child("RouteMapScroll", true, false) as ScrollContainer
	var shop_button := shop_main.find_child("RouteNode_shop_0_0", true, false) as Button
	if route_scroll == null or shop_button == null or shop_button.disabled:
		push_error("Expected test shop route node to start clickable.")
		quit(1)
		return
	var route_nodes: Array = shop_main.get("route_nodes")
	var shop_route_node: Dictionary = route_nodes[0][0]
	_send_route_node_mouse_press(shop_main, shop_button, route_scroll, 0, shop_route_node, 0)
	_send_route_node_mouse_release(shop_main, shop_button, route_scroll, 0, shop_route_node, 0)
	await process_frame
	if shop_main.find_child("ShopScreen", true, false) == null:
		push_error("Expected clicking a shop route node to open the shop.")
		quit(1)
		return
	var initial_shop_key := str(shop_main.get("current_shop_node_key"))
	var initial_shop_ids: Array[String] = []
	for item in (shop_main.get("current_shop_items") as Array):
		var item_dict: Dictionary = item
		initial_shop_ids.append(str(item_dict.get("id", "")))
	if initial_shop_ids.is_empty():
		push_error("Expected route shop to generate stock.")
		quit(1)
		return
	if not bool(shop_main.call("_buy_shop_item_at", 0)):
		push_error("Expected first route-shop item purchase to succeed.")
		quit(1)
		return
	await process_frame
	var purchased_after_buy: Array = shop_main.get("current_shop_purchased")
	if purchased_after_buy.is_empty() or not bool(purchased_after_buy[0]):
		push_error("Expected purchased route-shop item to stay marked.")
		quit(1)
		return
	var money_after_buy := int(shop_main.call("_run_money"))
	var leave_button := shop_main.find_child("ShopLeaveButton", true, false) as Button
	if leave_button == null:
		push_error("Expected route shop to expose a leave button.")
		quit(1)
		return
	leave_button.pressed.emit()
	await process_frame
	await process_frame
	if int(shop_main.get("route_stage")) != 0 or not bool(shop_main.get("shop_reentry_pending")):
		push_error("Expected leaving shop to keep route_stage=0 and mark shop reentry pending.")
		quit(1)
		return
	if shop_main.find_child("RouteMapScreen", true, false) == null:
		push_error("Expected leaving shop to return to the route map.")
		quit(1)
		return
	shop_button = shop_main.find_child("RouteNode_shop_0_0", true, false) as Button
	var next_battle_button := shop_main.find_child("RouteNode_battle_1_0", true, false) as Button
	if shop_button == null or shop_button.disabled or next_battle_button == null or next_battle_button.disabled:
		push_error("Expected both the visited shop and next route node to be clickable before leaving the level. shop=%s next=%s" % [str(shop_button), str(next_battle_button)])
		quit(1)
		return

	route_scroll = shop_main.find_child("RouteMapScroll", true, false) as ScrollContainer
	if route_scroll == null:
		push_error("Expected route map scroll to exist before revisiting shop.")
		quit(1)
		return
	_send_route_node_mouse_press(shop_main, shop_button, route_scroll, 0, shop_route_node, 0)
	_send_route_node_mouse_release(shop_main, shop_button, route_scroll, 0, shop_route_node, 0)
	await process_frame
	if shop_main.find_child("ShopScreen", true, false) == null:
		push_error("Expected revisiting the pending shop to reopen shop screen.")
		quit(1)
		return
	var revisited_ids: Array[String] = []
	for item in (shop_main.get("current_shop_items") as Array):
		var item_dict: Dictionary = item
		revisited_ids.append(str(item_dict.get("id", "")))
	if revisited_ids != initial_shop_ids or str(shop_main.get("current_shop_node_key")) != initial_shop_key:
		push_error("Expected revisited shop to keep same stock/key, got %s/%s instead of %s/%s." % [str(revisited_ids), str(shop_main.get("current_shop_node_key")), str(initial_shop_ids), initial_shop_key])
		quit(1)
		return
	var revisited_purchased: Array = shop_main.get("current_shop_purchased")
	if revisited_purchased.is_empty() or not bool(revisited_purchased[0]):
		push_error("Expected revisited shop to preserve purchased state.")
		quit(1)
		return
	if bool(shop_main.call("_buy_shop_item_at", 0)) or int(shop_main.call("_run_money")) != money_after_buy:
		push_error("Expected revisited purchased shop slot to be non-rebuyable.")
		quit(1)
		return
	leave_button = shop_main.find_child("ShopLeaveButton", true, false) as Button
	leave_button.pressed.emit()
	await process_frame
	await process_frame
	route_scroll = shop_main.find_child("RouteMapScroll", true, false) as ScrollContainer
	next_battle_button = shop_main.find_child("RouteNode_battle_1_0", true, false) as Button
	if route_scroll == null or next_battle_button == null or next_battle_button.disabled:
		push_error("Expected next battle node to stay clickable after a repeated shop visit.")
		quit(1)
		return
	var next_route_node: Dictionary = route_nodes[1][0]
	_send_route_node_mouse_press(shop_main, next_battle_button, route_scroll, 0, next_route_node, 1)
	_send_route_node_mouse_release(shop_main, next_battle_button, route_scroll, 0, next_route_node, 1)
	await process_frame
	if int(shop_main.get("route_stage")) != 1 or bool(shop_main.get("shop_reentry_pending")):
		push_error("Expected choosing the next route node to advance route_stage and clear shop reentry pending.")
		quit(1)
		return
	if str(shop_main.get("current_shop_node_key")) != "" or not (shop_main.get("current_shop_items") as Array).is_empty() or not (shop_main.get("current_shop_purchased") as Array).is_empty():
		push_error("Expected choosing next route node to finalize/clear previous shop stock.")
		quit(1)
		return
	if not bool(shop_main.get("combat_active")) or str(shop_main.get("current_combat_type")) != "battle":
		push_error("Expected choosing next route node after shop to start that battle.")
		quit(1)
		return

	shop_main.queue_free()
	await process_frame


func _test_run_autosave_continue_prompt(main_scene: PackedScene) -> void:
	RunAutosave.clear_run()

	var save_main := main_scene.instantiate()
	root.add_child(save_main)
	await process_frame
	save_main.set("selected_character_id", "dark_mage")
	save_main.set("selected_weapon_id", "shadow_orb")
	save_main.set("selected_ascension_level", 2)
	save_main.set("route_stage", 3)
	save_main.set("route_selected_indices", [1, 0, 2])
	save_main.set("run_player_snapshot", {
		"character_id": "dark_mage",
		"weapon_id": "shadow_orb",
		"health": 77.0,
		"max_health": 120.0,
		"stats": {"intelligence": 13, "endurance": 8},
		"run_modifiers": {"damage_multiplier": 1.15},
		"artifacts": [{"id": "hawk_eye", "title": "Ястребиный глаз"}],
		"xp": 21,
		"xp_to_next": 42,
		"level": 5,
		"money": 314,
	})
	if not bool(save_main.call("save_run_autosave", "runtime_smoke")):
		_fail("Expected run autosave to be created from safe route state.")
		return
	if not RunAutosave.has_run():
		_fail("Expected RunAutosave.has_run after save.")
		return
	save_main.queue_free()
	await process_frame

	var continue_main := main_scene.instantiate()
	root.add_child(continue_main)
	await process_frame
	var start_button := continue_main.find_child("MainMenuStartButton", true, false) as Button
	if start_button == null:
		_fail("Expected main menu start button before autosave prompt.")
		return
	start_button.pressed.emit()
	await process_frame
	var dialog := continue_main.find_child("ContinueRunDialog", true, false) as Control
	var continue_button := continue_main.find_child("ContinueRunButton", true, false) as Button
	var new_game_button := continue_main.find_child("ContinueRunNewGameButton", true, false) as Button
	if dialog == null or continue_button == null or new_game_button == null:
		_fail("Expected autosave prompt with Continue/New Game buttons.")
		return
	continue_button.pressed.emit()
	await process_frame
	if continue_main.find_child("RouteMapScreen", true, false) == null:
		_fail("Expected Continue to restore directly to route map.")
		return
	if str(continue_main.get("selected_character_id")) != "dark_mage" or int(continue_main.get("route_stage")) != 3:
		_fail("Expected Continue to restore character and route stage.")
		return
	var restored_snapshot: Dictionary = continue_main.get("run_player_snapshot")
	if int(restored_snapshot.get("money", 0)) != 314 or int(restored_snapshot.get("level", 0)) != 5:
		_fail("Expected Continue to restore player money/level snapshot.")
		return
	continue_main.queue_free()
	await process_frame

	var fixture_route := [
		[
			{"type": "battle", "name": "Autosave Battle", "row": 0, "branch": 0, "next_branches": [0]},
		],
		[
			{"type": "boss", "name": "Rift Warden", "boss_id": "rift_warden", "row": 1, "branch": 0},
		],
	]
	if not RunAutosave.save_run({
		"selected_character_id": "berserk",
		"selected_weapon_id": "sword",
		"route_stage": 0,
		"route_nodes": fixture_route,
		"run_player_snapshot": {"character_id": "berserk", "weapon_id": "sword", "money": 99, "level": 3},
	}):
		_fail("Expected manual run autosave fixture to save.")
		return
	var new_main := main_scene.instantiate()
	root.add_child(new_main)
	await process_frame
	var new_start := new_main.find_child("MainMenuStartButton", true, false) as Button
	if new_start == null:
		_fail("Expected start button for New Game autosave prompt.")
		return
	new_start.pressed.emit()
	await process_frame
	var prompt_new_game := new_main.find_child("ContinueRunNewGameButton", true, false) as Button
	if prompt_new_game == null:
		_fail("Expected New Game choice while autosave exists.")
		return
	prompt_new_game.pressed.emit()
	await process_frame
	if RunAutosave.has_run():
		_fail("Expected New Game choice to clear existing autosave.")
		return
	if new_main.find_child("HeroSelectScreen", true, false) == null or int(new_main.get("route_stage")) != 0:
		_fail("Expected New Game choice to enter fresh hero select.")
		return
	new_main.queue_free()
	await process_frame

	var clear_main := main_scene.instantiate()
	root.add_child(clear_main)
	await process_frame
	clear_main.call("save_run_autosave", "clear_death")
	clear_main.ui._show_death_screen("Тестовая смерть.")
	await process_frame
	if RunAutosave.has_run():
		_fail("Expected death screen to clear run autosave.")
		return
	clear_main.call("save_run_autosave", "clear_victory")
	clear_main.ui._show_victory_screen()
	await process_frame
	if RunAutosave.has_run():
		_fail("Expected victory screen to clear run autosave.")
		return
	clear_main.queue_free()
	await process_frame
	RunAutosave.clear_run()


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

	var poor_event_player := player_scene.instantiate()
	root.add_child(poor_event_player)
	poor_event_player.configure_character("berserk", "sword")
	poor_event_player.set("money", 0)
	event_main.combat._store_player_snapshot(poor_event_player)
	poor_event_player.queue_free()
	event_main.ui._show_event_screen({"name": "Недоступная лотерея", "event_id": "goblin_lottery"})
	await process_frame
	var paid_event_choice := event_main.find_child("EventChoiceButton0", true, false) as Button
	if paid_event_choice == null or not paid_event_choice.disabled or not paid_event_choice.tooltip_text.contains("Недостаточно золота"):
		_fail("Expected unaffordable event choices to be disabled with an insufficient-gold tooltip.")
		event_main.queue_free()
		return
	var lottery_event: Dictionary = EventData.event_by_id("goblin_lottery")
	var lottery_choices: Array = lottery_event.get("choices", [])
	if lottery_choices.is_empty() or bool(event_main.ui._apply_event_choice(lottery_choices[0])):
		_fail("Expected direct activation of an unaffordable paid event choice to fail safely.")
		event_main.queue_free()
		return
	var poor_snapshot: Dictionary = event_main.get("run_player_snapshot")
	if int(poor_snapshot.get("money", -1)) != 0:
		_fail("Expected failed paid event choice to preserve run money.")
		event_main.queue_free()
		return

	event_player = player_scene.instantiate()
	root.add_child(event_player)
	event_player.configure_character("berserk", "sword")
	event_player.set("money", 500)
	stats = event_player.get("stats")
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
			var formatted_choice_text: String = event_main.ui._event_choice_description_text(choice)
			if formatted_choice_text.contains("Риск: Риск:"):
				_fail("Expected event choice risk text to avoid duplicate prefix for %s." % choice.get("id", ""))
				event_main.queue_free()
				return
			if bool(choice.get("risk", false)) and not formatted_choice_text.begins_with("Риск:"):
				_fail("Expected risk event choice text to include a single player-facing risk prefix for %s." % choice.get("id", ""))
				event_main.queue_free()
				return
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


func _send_route_node_mouse_press(main: Node, button: Button, scroll: ScrollContainer, branch_index: int, route_node: Dictionary, step_index := 0) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	main.call("_handle_route_node_input", button, press, scroll, step_index, branch_index, route_node)


func _send_route_node_mouse_release(main: Node, button: Button, scroll: ScrollContainer, branch_index: int, route_node: Dictionary, step_index := 0) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	main.call("_handle_route_node_input", button, release, scroll, step_index, branch_index, route_node)


func _send_route_node_mouse_drag(main: Node, button: Button, scroll: ScrollContainer, branch_index: int, route_node: Dictionary, relative: Vector2, step_index := 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	main.call("_handle_route_node_input", button, motion, scroll, step_index, branch_index, route_node)


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
	main.set("current_node_type", "shop")
	main.set("current_route_choice", "smoke_shop_a")
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var shop_player := player_scene.instantiate()
	root.add_child(shop_player)
	shop_player.configure_character("berserk", "sword")
	shop_player.set("money", 5000)
	main.call("_store_player_snapshot", shop_player)
	shop_player.queue_free()
	main.call("_show_shop_screen")
	var shop_screen := main.find_child("ShopScreen", true, false) as Control
	if shop_screen == null:
		push_error("Expected shop to render as an inline full-screen shop screen.")
		quit(1)
		return
	var inline_items := main.find_child("ShopInlineItems", true, false) as Control
	if inline_items == null or inline_items is GridContainer:
		push_error("Expected shop offers to hang freely on the wall, not inside a card grid.")
		quit(1)
		return
	var parchment_wall := main.find_child("ShopParchmentWall", true, false) as Control
	if parchment_wall == null or parchment_wall.anchor_left > 0.25 or parchment_wall.anchor_right < 0.75:
		push_error("Expected the shop grid to be anchored to the centered backdrop wall zone.")
		quit(1)
		return
	var first_shop_button := main.find_child("ShopItemButton0", true, false) as Button
	if first_shop_button == null or first_shop_button.text != "" or first_shop_button.tooltip_text == "":
		push_error("Expected shop wall items to show icon/price only and move descriptions into hover tooltip.")
		quit(1)
		return
	var first_shop_icon := first_shop_button.find_child("ShopItemIcon", true, false) as TextureRect
	var first_shop_price := first_shop_button.find_child("ShopItemPrice", true, false) as Label
	var first_shop_shadow := first_shop_button.find_child("ShopItemContactShadow", true, false) as PanelContainer
	var first_shop_money_icon := first_shop_button.find_child("ShopPriceMoneyIcon", true, false) as TextureRect
	if first_shop_icon == null or first_shop_icon.texture == null or first_shop_price == null or not first_shop_price.text.is_valid_int() or first_shop_shadow == null or first_shop_money_icon == null or first_shop_money_icon.texture == null:
		push_error("Expected every inline shop offer to include a texture icon and visible price.")
		quit(1)
		return
	var shop_items: Array = main.get("current_shop_items")
	if shop_items.size() < 2:
		push_error("Expected shop to offer multiple purchasable items.")
		quit(1)
		return
	var initial_shop_node_key := str(main.get("current_shop_node_key"))
	var initial_shop_ids: Array[String] = []
	for item in shop_items:
		var item_dict: Dictionary = item
		initial_shop_ids.append(str(item_dict.get("id", "")))
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
	if first_shop_button.get_theme_stylebox("normal") is StyleBoxTexture or first_shop_button.get_theme_stylebox("hover") is StyleBoxTexture:
		push_error("Expected wall shop items to avoid card/frame StyleBoxTexture slots.")
		quit(1)
		return
	var first_price_badge := first_shop_button.find_child("ShopPriceBadge", true, false) as PanelContainer
	if first_price_badge == null or _stylebox_texture_path(first_price_badge.get_theme_stylebox("panel")) != MINIMAL_FIELD_TEXTURE:
		push_error("Expected inline shop price badge to use the SCRUM-448 minimal field frame.")
		quit(1)
		return
	main.ui._show_pause_menu()
	await process_frame
	if main.find_child("RunPauseMenuRoot", true, false) == null:
		push_error("Expected run pause menu to open over the shop screen.")
		quit(1)
		return
	var shop_dossier_button := main.find_child("RunPauseDossierButton", true, false) as Button
	if shop_dossier_button == null:
		push_error("Expected run pause menu to expose character dossier from shop.")
		quit(1)
		return
	if main.find_child("ShopScreen", true, false) == null:
		push_error("Expected shop screen to remain underneath the run pause menu.")
		quit(1)
		return
	main.ui._resume_game()
	await process_frame
	first_shop_button = main.find_child("ShopItemButton0", true, false) as Button
	if first_shop_button == null:
		push_error("Expected closing the run pause menu to preserve shop buttons.")
		quit(1)
		return
	var shop_back_button := main.find_child("ShopLeaveButton", true, false) as Button
	if shop_back_button == null or shop_back_button.text != "Назад":
		push_error("Expected shop leave button to be the unified Back button.")
		quit(1)
		return
	if not bool(main.call("_buy_shop_item_at", 0)):
		push_error("Expected first shop purchase to succeed without leaving shop.")
		quit(1)
		return
	await process_frame
	if not bool(main.get("current_shop_purchased")[0]):
		push_error("Expected bought shop item to be marked as purchased.")
		quit(1)
		return
	var purchased_button := main.find_child("ShopItemButton0", true, false) as Button
	var empty_hook := purchased_button.find_child("ShopEmptyHook", true, false) as PanelContainer if purchased_button != null else null
	if purchased_button == null or not purchased_button.disabled or empty_hook == null or purchased_button.find_child("ShopItemIcon", true, false) != null:
		push_error("Expected bought shop item to be removed from the wall and replaced by a small empty hook.")
		quit(1)
		return
	if not bool(main.call("_buy_shop_item_at", 1)):
		push_error("Expected second shop purchase in the same visit to succeed.")
		quit(1)
		return
	await process_frame
	for purchase_index in range(2, shop_items.size()):
		if not bool(main.call("_buy_shop_item_at", purchase_index)):
			push_error("Expected every shop item to be purchasable once during the same visit.")
			quit(1)
			return
		await process_frame
	var money_after_full_purchase := int(main.call("_run_money"))
	main.call("_show_shop_screen")
	var reshown_shop_ids: Array[String] = []
	for item in main.get("current_shop_items"):
		var item_dict: Dictionary = item
		reshown_shop_ids.append(str(item_dict.get("id", "")))
	if reshown_shop_ids != initial_shop_ids:
		push_error("Expected reopening the same shop node to keep the original stock, got %s instead of %s." % [str(reshown_shop_ids), str(initial_shop_ids)])
		quit(1)
		return
	var reshown_purchased: Array = main.get("current_shop_purchased")
	for purchase_index in range(reshown_purchased.size()):
		if not bool(reshown_purchased[purchase_index]):
			push_error("Expected reopened shop stock position %d to remain purchased." % purchase_index)
			quit(1)
			return
	var rebuy_button := _find_active_ui_child(main, "ShopItemButton0") as Button
	if rebuy_button == null or not rebuy_button.disabled or rebuy_button.find_child("ShopEmptyHook", true, false) == null:
		push_error("Expected fully purchased shop stock to re-render as disabled empty hooks. button=%s disabled=%s hook=%s purchased=%s ui=%s" % [str(rebuy_button), str(rebuy_button.disabled if rebuy_button != null else false), str(rebuy_button.find_child("ShopEmptyHook", true, false) if rebuy_button != null else null), str(main.get("current_shop_purchased")), _debug_child_tree(main.get("ui_layer") as Node)])
		quit(1)
		return
	if bool(main.call("_buy_shop_item_at", 0)) or int(main.call("_run_money")) != money_after_full_purchase:
		push_error("Expected rebuying a purchased shop position on the same node to be impossible.")
		quit(1)
		return
	await process_frame
	main.set("route_stage", 2)
	main.set("current_route_choice", "smoke_shop_b")
	main.call("_open_route_node", {"type": "shop", "name": "Smoke Shop B"})
	await process_frame
	if str(main.get("current_shop_node_key")) == initial_shop_node_key:
		push_error("Expected a new shop route node to receive a distinct stock key.")
		quit(1)
		return
	var new_shop_purchased: Array = main.get("current_shop_purchased")
	if new_shop_purchased.is_empty():
		push_error("Expected new shop node to generate stock.")
		quit(1)
		return
	for purchase_index in range(new_shop_purchased.size()):
		if bool(new_shop_purchased[purchase_index]):
			push_error("Expected new shop node stock to start unpurchased.")
			quit(1)
			return
	if main.get("hud_layer") == null:
		push_error("Expected shop screen to keep the compact run HUD.")
		quit(1)
		return
	if not _has_screen_background(main, "shop"):
		push_error("Expected shop screen to include a shop background or fallback layer. Active UI tree: %s" % _debug_child_tree(main.get("ui_layer") as Node))
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
	var ui_layer = node.get("ui_layer")
	if ui_layer is Node:
		if (ui_layer as Node).find_child("ScreenBackground_%s" % screen_background_id, true, false) != null:
			return true
		if (ui_layer as Node).find_child("ScreenBackgroundFallback_%s" % screen_background_id, true, false) != null:
			return true
	return node.find_child("ScreenBackground_%s" % screen_background_id, true, false) != null \
		or node.find_child("ScreenBackgroundFallback_%s" % screen_background_id, true, false) != null


func _find_active_ui_child(node: Node, child_name: String) -> Node:
	var ui_layer = node.get("ui_layer")
	if ui_layer is Node:
		var found := (ui_layer as Node).find_child(child_name, true, false)
		if found != null:
			return found
	return node.find_child(child_name, true, false)


func _debug_child_tree(node: Node, depth: int = 0) -> String:
	if node == null or depth > 2:
		return ""
	var names := []
	for child in node.get_children():
		names.append("%s%s" % [" ".repeat(depth), child.name])
		var nested := _debug_child_tree(child, depth + 1)
		if nested != "":
			names.append(nested)
	return ", ".join(names)


func _node_sprite_texture_path(node: Node, sprite_name: String) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var sprite := node as Sprite2D
	if sprite == null:
		if sprite_name.is_empty():
			var sprites := node.find_children("*", "Sprite2D", true, false)
			if not sprites.is_empty():
				sprite = sprites[0] as Sprite2D
		else:
			sprite = node.find_child(sprite_name, true, false) as Sprite2D
	if sprite == null or sprite.texture == null:
		return ""
	return sprite.texture.resource_path


func _button_uses_minimal_metal_type(button: Button, button_type: String) -> bool:
	if button == null:
		return false
	var expected := {
		"normal": "res://assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_%s.png" % button_type,
		"hover": "res://assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_%s_hover.png" % button_type,
		"focus": "res://assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_%s_focus.png" % button_type,
		"pressed": "res://assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_%s_pressed.png" % button_type,
		"disabled": "res://assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_%s_disabled.png" % button_type,
	}
	for state in expected.keys():
		var style := button.get_theme_stylebox(state)
		if not (style is StyleBoxTexture):
			return false
		var texture := (style as StyleBoxTexture).texture
		if texture == null or texture.resource_path != str(expected[state]):
			return false
	var hover_style := button.get_theme_stylebox("hover") as StyleBoxTexture
	var focus_style := button.get_theme_stylebox("focus") as StyleBoxTexture
	if hover_style == null or focus_style == null:
		return false
	if not _is_neutral_bright_button_tint(hover_style.modulate_color) or not _is_neutral_bright_button_tint(focus_style.modulate_color):
		return false
	if not _is_neutral_button_font(button.get_theme_color("font_hover_color")) or not _is_neutral_button_font(button.get_theme_color("font_focus_color")):
		return false
	return true


func _button_uses_combat_hud_plus_style(button: Button) -> bool:
	if button == null:
		return false
	var expected := {
		"normal": "res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png",
		"hover": "res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_hover.png",
		"focus": "res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_hover.png",
		"pressed": "res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_pressed.png",
		"disabled": "res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_disabled.png",
	}
	for state in expected.keys():
		var style := button.get_theme_stylebox(state)
		if not (style is StyleBoxTexture):
			return false
		var texture := (style as StyleBoxTexture).texture
		if texture == null or texture.resource_path != str(expected[state]):
			return false
	var hover_style := button.get_theme_stylebox("hover") as StyleBoxTexture
	var focus_style := button.get_theme_stylebox("focus") as StyleBoxTexture
	if hover_style == null or focus_style == null:
		return false
	if not _is_neutral_bright_button_tint(hover_style.modulate_color) or not _is_neutral_bright_button_tint(focus_style.modulate_color):
		return false
	if not _is_neutral_button_font(button.get_theme_color("font_hover_color")) or not _is_neutral_button_font(button.get_theme_color("font_focus_color")):
		return false
	return true


func _is_neutral_bright_button_tint(color: Color) -> bool:
	return color.r >= 1.0 and color.g >= 1.0 and color.b >= 1.0 and absf(color.r - color.g) <= 0.015 and absf(color.g - color.b) <= 0.015


func _is_neutral_button_font(color: Color) -> bool:
	return color.r >= 0.98 and color.g >= 0.98 and color.b >= 0.98 and absf(color.r - color.g) <= 0.015 and absf(color.g - color.b) <= 0.015


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


func _test_weapon_orbit_no_overlap() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	player.configure_character("berserk")
	player.equip_weapon("sword")
	var weapon := _find_player_weapon(player)
	if weapon == null:
		_fail("Expected SCRUM-455 weapon orbit smoke to equip Berserk sword.")
		return
	if weapon.get_parent() == null or weapon.get_parent().name != "WeaponSocket":
		_fail("Expected SCRUM-455 weapon to remain directly attached to WeaponSocket.")
		return
	if not _assert_weapon_orbit_pose(player, Vector2.RIGHT, "SCRUM-455 right attack"):
		return
	weapon.set("_last_direction", Vector2.UP)
	if not _assert_weapon_orbit_pose(player, Vector2.UP, "SCRUM-455 upward attack"):
		return
	_write_weapon_orbit_qa_dump(player, weapon)
	player.queue_free()


func _test_class_weapon_configs() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var expected := {
		"soldier": {
			"soldier_rifle": {"scene": "SoldierRifle", "mode": "suppression_burst", "sprite": "res://assets/sprites/weapons/soldier_rifle.png"},
			"soldier_grenade": {"scene": "SoldierGrenade", "mode": "grenade_cook", "sprite": "res://assets/sprites/weapons/soldier_grenade.png"},
			"soldier_bayonet": {"scene": "SoldierBayonet", "mode": "bayonet_brace", "sprite": "res://assets/sprites/weapons/soldier_bayonet.png"},
		},
		"thief": {
			"thief_coin_pouch": {"scene": "ThiefCoinPouch", "mode": "coin_ricochet", "sprite": "res://assets/sprites/weapons/thief_coin_pouch.png"},
			"thief_shadow_cloak": {"scene": "ThiefShadowCloak", "mode": "shadow_backstab", "sprite": "res://assets/sprites/weapons/thief_shadow_cloak.png"},
			"thief_smoke_bomb": {"scene": "ThiefSmokeBomb", "mode": "smoke_bomb", "sprite": "res://assets/sprites/weapons/thief_smoke_bomb.png"},
		},
		"elementalist": {
			"elementalist_orb_ring": {"scene": "ElementalistOrbRing", "mode": "elemental_orbit", "sprite": "res://assets/sprites/weapons/elementalist_orb_ring.png"},
			"elementalist_prism_focus": {"scene": "ElementalistPrismFocus", "mode": "prism_rift", "sprite": "res://assets/sprites/weapons/elementalist_prism_focus.png"},
			"elementalist_meteor_core": {"scene": "ElementalistMeteorCore", "mode": "meteor_shards", "sprite": "res://assets/sprites/weapons/elementalist_meteor_core.png"},
		},
		"sniper": {
			"sniper_deadeye_rifle": {"scene": "SniperDeadeyeRifle", "mode": "sniper_lockshot", "sprite": "res://assets/sprites/weapons/sniper_deadeye_rifle.png"},
			"sniper_spotter_scope": {"scene": "SniperSpotterScope", "mode": "sniper_kill_zone", "sprite": "res://assets/sprites/weapons/sniper_spotter_scope.png"},
			"sniper_shatter_rounds": {"scene": "SniperShatterRounds", "mode": "sniper_split_round", "sprite": "res://assets/sprites/weapons/sniper_shatter_rounds.png"},
		},
		"priest": {
			"priest_reliquary": {"scene": "PriestReliquary", "mode": "priest_sanctify", "sprite": "res://assets/sprites/weapons/priest_reliquary.png"},
			"priest_censer": {"scene": "PriestCenser", "mode": "priest_ward", "sprite": "res://assets/sprites/weapons/priest_censer.png"},
			"priest_chime": {"scene": "PriestChime", "mode": "priest_prayer_chain", "sprite": "res://assets/sprites/weapons/priest_chime.png"},
		},
		"biologist": {
			"biologist_spore_lens": {"scene": "BiologistSporeLens", "mode": "bio_spore_bloom", "sprite": "res://assets/sprites/weapons/biologist_spore_lens.png"},
			"biologist_sample_injector": {"scene": "BiologistSampleInjector", "mode": "bio_sample_dart", "sprite": "res://assets/sprites/weapons/biologist_sample_injector.png"},
			"biologist_symbiote_seed": {"scene": "BiologistSymbioteSeed", "mode": "bio_symbiote_web", "sprite": "res://assets/sprites/weapons/biologist_symbiote_seed.png"},
		},
		"robot": {
			"robot_magnetic_anchor": {"scene": "RobotMagneticAnchor", "mode": "robot_magnetic_anchor", "sprite": "res://assets/sprites/weapons/robot_magnetic_anchor.png"},
			"robot_hydraulic_press": {"scene": "RobotHydraulicPress", "mode": "robot_compression_line", "sprite": "res://assets/sprites/weapons/robot_hydraulic_press.png"},
			"robot_reactor_core": {"scene": "RobotReactorCore", "mode": "robot_reactor_vent", "sprite": "res://assets/sprites/weapons/robot_reactor_core.png"},
		},
		"engineer": {
			"engineer_sentry_wrench": {"scene": "EngineerSentryWrench", "mode": "engineer_sentry_link", "sprite": "res://assets/sprites/weapons/engineer_sentry_wrench.png"},
			"engineer_repair_drone": {"scene": "EngineerRepairDrone", "mode": "engineer_repair_drone", "sprite": "res://assets/sprites/weapons/engineer_repair_drone.png"},
			"engineer_pressure_mines": {"scene": "EngineerPressureMines", "mode": "engineer_pressure_mines", "sprite": "res://assets/sprites/weapons/engineer_pressure_mines.png"},
		},
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


func _test_class_weapon_mode_registry() -> void:
	var missing_modes := PackedStringArray()
	for character_id in ProgressionData.WEAPONS_BY_CLASS.keys():
		if str(character_id) == "berserk":
			continue
		var weapons: Dictionary = ProgressionData.WEAPONS_BY_CLASS.get(character_id, {})
		for weapon_id in weapons.keys():
			var config: Dictionary = weapons.get(weapon_id, {})
			if not config.has("attack_mode"):
				continue
			var attack_mode := str(config.get("attack_mode", ""))
			if attack_mode.is_empty() or not ClassWeaponScript.has_attack_mode_executor(attack_mode):
				missing_modes.append("%s/%s:%s" % [str(character_id), str(weapon_id), attack_mode])
	if not missing_modes.is_empty():
		push_error("Expected every non-Berserk class weapon attack_mode to have a ClassWeapon executor: %s" % ", ".join(missing_modes))
		quit(1)
		return


func _test_all_weapon_variants_equip() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var expected_weapon_ids := {
		"berserk": ["sword", "axe", "hammer"],
		"soldier": ["soldier_rifle", "soldier_grenade", "soldier_bayonet"],
		"thief": ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"],
		"elementalist": ["elementalist_orb_ring", "elementalist_prism_focus", "elementalist_meteor_core"],
		"sniper": ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"],
		"priest": ["priest_reliquary", "priest_censer", "priest_chime"],
		"biologist": ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"],
		"robot": ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"],
		"engineer": ["engineer_sentry_wrench", "engineer_repair_drone", "engineer_pressure_mines"],
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
	var deployed_amps: Array = weapon.get("_deployed_amps")
	if get_nodes_in_group("player_weapon_effects").is_empty() and deployed_amps.is_empty():
		push_error("Expected sound amp to register temporary weapon effects.")
		quit(1)
		return
	if deployed_amps.is_empty() or _node_sprite_texture_path(deployed_amps[0], "") != "res://assets/sprites/allies/deploy_sound_amp_field.png":
		push_error("Expected sound amp deployable to use its source-specific field sprite.")
		quit(1)
		return

	var old_weapon_id := weapon.get_instance_id()
	player.equip_weapon("electric_guitar")
	await process_frame
	var owned_leftovers := []
	for effect in get_nodes_in_group("player_weapon_effects"):
		if int(effect.get_meta("weapon_owner_id", 0)) == old_weapon_id:
			owned_leftovers.append(effect)
	if not owned_leftovers.is_empty() or not deployed_amps.filter(func(effect: Node) -> bool: return effect != null and is_instance_valid(effect)).is_empty():
		var leftover_names := []
		for effect in owned_leftovers:
			leftover_names.append(str(effect.name))
		push_error("Expected switching Guitarist weapons to clean up amp/effect nodes. Leftover: %s" % ", ".join(leftover_names))
		quit(1)
		return
	player.queue_free()
	await process_frame


func _assert_health_bar_visible_when_near_viewport_top(entity: Node2D, health_bar: Node2D, context: String) -> bool:
	if entity == null or health_bar == null:
		return false
	var viewport := entity.get_viewport()
	if viewport == null:
		return false
	var visible_rect := viewport.get_visible_rect()
	var canvas_inverse := viewport.get_canvas_transform().affine_inverse()
	var visible_top_left: Vector2 = canvas_inverse * visible_rect.position
	var visible_bottom_right: Vector2 = canvas_inverse * (visible_rect.position + visible_rect.size)
	var original_position := entity.global_position
	entity.global_position = Vector2((visible_top_left.x + visible_bottom_right.x) * 0.5, visible_top_left.y + 10.0)
	if entity.has_method("_update_health_bar"):
		entity.call("_update_health_bar")
	var screen_position: Vector2 = health_bar.get_global_transform_with_canvas().origin
	var half_width := maxf(8.0, float(health_bar.get("bar_width")) * 0.5)
	var bar_height := maxf(4.0, float(health_bar.get("bar_height")))
	var visible := (
		screen_position.x - half_width >= -1.0
		and screen_position.x + half_width <= float(visible_rect.size.x) + 1.0
		and screen_position.y - bar_height >= -1.0
		and screen_position.y <= float(visible_rect.size.y) + 1.0
	)
	if not visible:
		print("%s health bar offscreen at %s in viewport %s." % [context, str(screen_position), str(visible_rect.size)])
	entity.global_position = original_position
	if entity.has_method("_update_health_bar"):
		entity.call("_update_health_bar")
	return visible


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
	if not _assert_health_bar_visible_when_near_viewport_top(boss, boss_health_bar, "boss"):
		push_error("Expected boss health bar to stay visible when the large boss sprite reaches the viewport top edge.")
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
	var victory_text := ""
	for _attempt in range(120):
		await process_frame
		victory_text = _collect_label_text(main)
		if not bool(main.get("combat_active")) and victory_text.contains("Победа"):
			break
	if bool(main.get("combat_active")):
		push_error("Expected boss death to end combat.")
		quit(1)
		return
	if int(main.get("meta_points")) < 1 or not bool(main.get("berserk_ascension_unlocked")):
		push_error("Expected boss victory to grant meta progress and Berserk Ascension 1.")
		quit(1)
		return
	for forbidden in ["Meta points", "asc_", "_id", "berserk_asc"]:
		if victory_text.contains(forbidden):
			push_error("Expected victory screen text to hide internal technical token '%s'." % forbidden)
			quit(1)
			return
	for expected in ["Победа", "Финальный босс повержен", "Очки наследия", "Возвышения"]:
		if not victory_text.contains(expected):
			push_error("Expected victory screen text to include '%s'." % expected)
			quit(1)
			return
	var victory_panel := main.find_child("PauseEndModalPanel_victory", true, false) as PanelContainer
	if victory_panel == null or _stylebox_texture_path(victory_panel.get_theme_stylebox("panel")) != MINIMAL_MODAL_TEXTURE:
		push_error("Expected victory screen to use the SCRUM-448 minimal modal frame.")
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
	if not _assert_health_bar_visible_when_near_viewport_top(elite_enemy, elite_health_bar, "elite"):
		push_error("Expected elite health bar to stay visible when the large elite sprite reaches the viewport top edge.")
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
	# Снимок до награды: текущее число артефактов забега.
	var pre_player: Node = elite_main.combat._snapshot_player_for_menu()
	var artifacts_before: int = (pre_player.get("artifacts") as Array).size()
	pre_player.queue_free()

	elite_main.ui._show_elite_artifact_reward(Callable())
	await process_frame
	var elite_reward_buttons := elite_main.find_children("EliteArtifactRewardButton*", "Button", true, false)
	if elite_reward_buttons.size() != 3:
		push_error("Expected elite victory reward to offer exactly 3 artifact choices.")
		quit(1)
		return
	var elite_reward_panel := elite_main.find_child("EliteArtifactRewardPanel", true, false) as Control
	if elite_reward_panel == null:
		push_error("Expected elite reward panel.")
		quit(1)
		return
	if not _control_center_matches_viewport(elite_reward_panel, 2.0):
		var panel_rect := elite_reward_panel.get_global_rect()
		var viewport_center := root.get_visible_rect().size * 0.5
		push_error("Expected elite reward panel global center %s to match viewport center %s." % [panel_rect.get_center(), viewport_center])
		quit(1)
		return
	# Клавиатура/геймпад: первая карточка получает фокус.
	if not (elite_reward_buttons[0] as Control).has_focus():
		push_error("Expected first elite reward card to grab keyboard focus.")
		quit(1)
		return

	# Выбор одной карточки выдаёт РОВНО один артефакт (две другие — нет).
	(elite_reward_buttons[0] as Button).emit_signal("pressed")
	await process_frame
	var post_player: Node = elite_main.combat._snapshot_player_for_menu()
	var artifacts_after: int = (post_player.get("artifacts") as Array).size()
	post_player.queue_free()
	if artifacts_after != artifacts_before + 1:
		push_error("Expected exactly one artifact granted by elite reward (%d -> %d)." % [artifacts_before, artifacts_after])
		quit(1)
		return

	# SCRUM-528 happy-path: элитка УБИТА -> окно награды показывается ДО докачки.
	# (Раньше тест добивал не элитку, а сразу звал _end_combat с живой элиткой —
	# это закрепляло баг. Теперь добиваем элитку, чтобы выставился _elite_defeated.)
	elite_main.call("_start_combat", false, "elite")
	await process_frame
	var killed_elite := elite_main.get_tree().get_first_node_in_group("elite_enemies")
	if killed_elite == null:
		push_error("Expected elite combat restart to spawn an elite enemy.")
		quit(1)
		return
	killed_elite.call("take_damage", 1.0e9)  # достоверный сигнал died -> _elite_defeated=true
	await process_frame
	if not bool(elite_main.combat.get("_elite_defeated")):
		push_error("Expected killing the elite to mark _elite_defeated on the combat director.")
		quit(1)
		return
	elite_main.combat.call("_end_combat", true)
	await process_frame
	var victory_banner := elite_main.find_child("VictoryBanner", true, false) as Button
	if victory_banner == null:
		push_error("Expected victory banner on elite victory before the reward.")
		quit(1)
		return
	victory_banner.emit_signal("pressed")
	await process_frame
	if elite_main.find_child("EliteArtifactRewardScreen", true, false) == null:
		push_error("Expected elite reward window to appear after the elite is killed.")
		quit(1)
		return

	# SCRUM-528 регресс: элитка ВЫЖИЛА (победа по таймеру с живой элиткой) ->
	# артефакт-награды НЕТ, сразу идёт обычный победный флоу (докачка атрибутов).
	elite_main.call("_start_combat", false, "elite")
	await process_frame
	var survivor_elite := elite_main.get_tree().get_first_node_in_group("elite_enemies")
	if survivor_elite == null:
		push_error("Expected elite combat to spawn an elite enemy for the survival regression case.")
		quit(1)
		return
	if bool(elite_main.combat.get("_elite_defeated")):
		push_error("Expected _elite_defeated to reset to false at the start of a fresh elite fight.")
		quit(1)
		return
	# Моделируем победу по истечении таймера с ЖИВОЙ элиткой.
	elite_main.set("round_time_left", 0.0)
	elite_main.combat.call("_end_combat", true)
	await process_frame
	var survivor_banner := elite_main.find_child("VictoryBanner", true, false) as Button
	if survivor_banner == null:
		push_error("Expected victory banner even when the elite survived the timer.")
		quit(1)
		return
	survivor_banner.emit_signal("pressed")
	await process_frame
	if elite_main.find_child("EliteArtifactRewardScreen", true, false) != null:
		push_error("Expected NO elite reward window when the elite survived (timer victory with a live elite).")
		quit(1)
		return
	if elite_main.find_child("AttributeShopScreen", true, false) == null and elite_main.find_child("AttributeShopPanel", true, false) == null:
		push_error("Expected the normal victory flow (attribute shop) when the elite survived.")
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
	var amp_nodes := get_nodes_in_group("deployed_sound_amps")
	if amp_nodes.is_empty() or _node_sprite_texture_path(amp_nodes[0], "") != "res://assets/sprites/allies/deploy_sound_amp_field.png":
		_fail("Expected sound amp deployables to use the source-specific field sprite.")
		return

	guitarist.queue_free()
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_unique_class_identity_patterns() -> void:
	var soldier_modes := {}
	for soldier_weapon_id in ProgressionData.weapon_ids("soldier"):
		var mode := str(ProgressionData.weapon("soldier", soldier_weapon_id).get("attack_mode", ""))
		if soldier_modes.has(mode):
			_fail("Expected Soldier weapons to use three distinct attack modes.")
			return
		soldier_modes[mode] = true
	for required_soldier_mode in ["suppression_burst", "grenade_cook", "bayonet_brace"]:
		if not soldier_modes.has(required_soldier_mode):
			_fail("Expected Soldier to include unique %s attack mode." % required_soldier_mode)
			return
	var thief_modes := {}
	for thief_weapon_id in ProgressionData.weapon_ids("thief"):
		var thief_mode := str(ProgressionData.weapon("thief", thief_weapon_id).get("attack_mode", ""))
		if thief_modes.has(thief_mode):
			_fail("Expected Thief weapons to use three distinct attack modes.")
			return
		thief_modes[thief_mode] = true
	for required_thief_mode in ["coin_ricochet", "shadow_backstab", "smoke_bomb"]:
		if not thief_modes.has(required_thief_mode):
			_fail("Expected Thief to include unique %s attack mode." % required_thief_mode)
			return
	var elementalist_modes := {}
	for elementalist_weapon_id in ProgressionData.weapon_ids("elementalist"):
		var elementalist_mode := str(ProgressionData.weapon("elementalist", elementalist_weapon_id).get("attack_mode", ""))
		if elementalist_modes.has(elementalist_mode):
			_fail("Expected Elementalist weapons to use three distinct attack modes.")
			return
		elementalist_modes[elementalist_mode] = true
	for required_elementalist_mode in ["elemental_orbit", "prism_rift", "meteor_shards"]:
		if not elementalist_modes.has(required_elementalist_mode):
			_fail("Expected Elementalist to include unique %s attack mode." % required_elementalist_mode)
			return
	var sniper_modes := {}
	for sniper_weapon_id in ProgressionData.weapon_ids("sniper"):
		var sniper_mode := str(ProgressionData.weapon("sniper", sniper_weapon_id).get("attack_mode", ""))
		if sniper_modes.has(sniper_mode):
			_fail("Expected Sniper weapons to use three distinct attack modes.")
			return
		sniper_modes[sniper_mode] = true
	for required_sniper_mode in ["sniper_lockshot", "sniper_kill_zone", "sniper_split_round"]:
		if not sniper_modes.has(required_sniper_mode):
			_fail("Expected Sniper to include unique %s attack mode." % required_sniper_mode)
			return
	var priest_modes := {}
	for priest_weapon_id in ProgressionData.weapon_ids("priest"):
		var priest_mode := str(ProgressionData.weapon("priest", priest_weapon_id).get("attack_mode", ""))
		if priest_modes.has(priest_mode):
			_fail("Expected Priest weapons to use three distinct attack modes.")
			return
		priest_modes[priest_mode] = true
	for required_priest_mode in ["priest_sanctify", "priest_ward", "priest_prayer_chain"]:
		if not priest_modes.has(required_priest_mode):
			_fail("Expected Priest to include unique %s attack mode." % required_priest_mode)
			return
	var biologist_modes := {}
	for biologist_weapon_id in ProgressionData.weapon_ids("biologist"):
		var biologist_mode := str(ProgressionData.weapon("biologist", biologist_weapon_id).get("attack_mode", ""))
		if biologist_modes.has(biologist_mode):
			_fail("Expected Biologist weapons to use three distinct attack modes.")
			return
		biologist_modes[biologist_mode] = true
	for required_biologist_mode in ["bio_spore_bloom", "bio_sample_dart", "bio_symbiote_web"]:
		if not biologist_modes.has(required_biologist_mode):
			_fail("Expected Biologist to include unique %s attack mode." % required_biologist_mode)
			return
	var robot_modes := {}
	for robot_weapon_id in ProgressionData.weapon_ids("robot"):
		var robot_mode := str(ProgressionData.weapon("robot", robot_weapon_id).get("attack_mode", ""))
		if robot_modes.has(robot_mode):
			_fail("Expected Robot weapons to use three distinct attack modes.")
			return
		robot_modes[robot_mode] = true
	for required_robot_mode in ["robot_magnetic_anchor", "robot_compression_line", "robot_reactor_vent"]:
		if not robot_modes.has(required_robot_mode):
			_fail("Expected Robot to include unique %s attack mode." % required_robot_mode)
			return
	var engineer_modes := {}
	for engineer_weapon_id in ProgressionData.weapon_ids("engineer"):
		var engineer_mode := str(ProgressionData.weapon("engineer", engineer_weapon_id).get("attack_mode", ""))
		if engineer_modes.has(engineer_mode):
			_fail("Expected Engineer weapons to use three distinct attack modes.")
			return
		engineer_modes[engineer_mode] = true
	for required_engineer_mode in ["engineer_sentry_link", "engineer_repair_drone", "engineer_pressure_mines"]:
		if not engineer_modes.has(required_engineer_mode):
			_fail("Expected Engineer to include unique %s attack mode." % required_engineer_mode)
			return
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
	var druid_visual_ok := false
	for ally in get_nodes_in_group("allies"):
		var ally_target = ally.get("command_target")
		if ally.get("owner_node") == druid and ally_target != null and is_instance_valid(ally_target) and ally.get("command_mode") == "attack_target":
			commanded = true
			var ally_texture_path := _node_sprite_texture_path(ally, "Body")
			if ally_texture_path in [
				"res://assets/sprites/allies/ally_druid_beast.png",
				"res://assets/sprites/allies/ally_druid_pack_spirit.png",
			]:
				druid_visual_ok = true
	if not commanded:
		_fail("Expected Druid pets to receive an attack-target command.")
		return
	if not druid_visual_ok:
		_fail("Expected Druid pets to use a source-specific beast/pack-spirit sprite.")
		return
	for ally in get_nodes_in_group("allies"):
		if ally != null and is_instance_valid(ally):
			ally.queue_free()
	await process_frame

	var chemist_minion_owner := player_scene.instantiate()
	holder.add_child(chemist_minion_owner)
	chemist_minion_owner.global_position = Vector2(1600, 700)
	await process_frame
	chemist_minion_owner.call("configure_character", "chemist", "homunculus_vial")
	var homunculus_weapon: Node = chemist_minion_owner.get("equipped_weapon")
	homunculus_weapon.set_process(false)
	homunculus_weapon.call("_summon")
	await process_frame
	var homunculus_visual_ok := false
	for ally in get_nodes_in_group("allies"):
		if ally.get("owner_node") == chemist_minion_owner and _node_sprite_texture_path(ally, "Body") == "res://assets/sprites/allies/ally_homunculus.png":
			homunculus_visual_ok = true
	if not homunculus_visual_ok:
		_fail("Expected Chemist homunculus summons to use the homunculus sprite.")
		return

	var raven_druid := player_scene.instantiate()
	holder.add_child(raven_druid)
	raven_druid.global_position = Vector2(1620, 820)
	await process_frame
	raven_druid.call("configure_character", "druid", "raven_totem")
	var raven_weapon: Node = raven_druid.get("equipped_weapon")
	raven_weapon.set_process(false)
	raven_weapon.call("_attack")
	await process_frame
	var raven_visual_ok := false
	for deployable in get_nodes_in_group("deployed_sound_amps"):
		if _node_sprite_texture_path(deployable, "") == "res://assets/sprites/allies/deploy_raven_totem_field.png":
			raven_visual_ok = true
	if not raven_visual_ok:
		_fail("Expected Druid raven totem deployables to use the raven field sprite.")
		return

	var assassin := player_scene.instantiate()
	holder.add_child(assassin)
	assassin.global_position = Vector2(1700, 700)
	await process_frame
	assassin.call("configure_character", "assassin", "chakrams")
	var assassin_weapon: Node = assassin.get("equipped_weapon")
	if assassin_weapon != null:
		assassin_weapon.set_process(false)
	var assassin_enemy := enemy_scene.instantiate()
	holder.add_child(assassin_enemy)
	assassin_enemy.global_position = assassin.global_position + Vector2(220, 0)
	await process_frame
	var assassin_start: Vector2 = assassin.global_position
	var vfx_before := {}
	for existing_vfx in holder.find_children("*Vfx", "Node2D", true, false):
		vfx_before[int(existing_vfx.get_instance_id())] = true
	assassin.set("_assassin_crit_shadow_cooldown_left", 0.0)
	assassin.call("trigger_assassin_crit_shadow", assassin_enemy, 100.0)
	if assassin.global_position.distance_to(assassin_start) > 0.01:
		_fail("Expected Assassin critical shadow hook to preserve player-controlled position.")
		return
	var spawned_assassin_vfx_names := []
	for current_vfx in holder.find_children("*Vfx", "Node2D", true, false):
		if not vfx_before.has(int(current_vfx.get_instance_id())):
			spawned_assassin_vfx_names.append(String(current_vfx.name))
	if spawned_assassin_vfx_names.is_empty():
		_fail("Expected Assassin critical shadow hook to keep a non-moving combat/VFX effect.")
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_class_mechanic_identity_framework() -> void:
	var valid_stats := ProgressionData.STAT_NAMES.keys()
	var identity_titles := {}
	for character_id in ProgressionData.character_ids():
		var identity: Dictionary = ProgressionData.class_mechanic_identity(character_id)
		if identity.is_empty():
			_fail("Expected %s to expose a class mechanic identity." % character_id)
			return
		var main_attribute := ProgressionData.class_main_attribute(character_id)
		if not valid_stats.has(main_attribute):
			_fail("Expected %s main attribute to be a valid base stat, got %s." % [character_id, main_attribute])
			return
		var priorities := ProgressionData.attribute_priorities(character_id)
		if priorities.is_empty() or str(priorities[0]) != main_attribute:
			_fail("Expected %s main attribute %s to match first attribute priority %s." % [character_id, main_attribute, str(priorities)])
			return
		var title := str(identity.get("identity_title", ""))
		if title == "" or identity_titles.has(title):
			_fail("Expected unique non-empty identity title for %s, got '%s'." % [character_id, title])
			return
		identity_titles[title] = true
		var tags: Array = identity.get("mechanic_tags", [])
		if tags.size() < 3:
			_fail("Expected %s to expose at least three mechanic tags." % character_id)
			return
		var weapon_identities: Dictionary = identity.get("weapon_identities", {})
		var weapon_ids := ProgressionData.weapon_ids(character_id)
		if weapon_identities.size() != weapon_ids.size():
			_fail("Expected %s weapon identities to cover exactly %d weapons, got %d." % [character_id, weapon_ids.size(), weapon_identities.size()])
			return
		for weapon_id in weapon_ids:
			var weapon_text := ProgressionData.weapon_mechanic_identity(character_id, str(weapon_id))
			if weapon_text == "":
				_fail("Expected %s/%s to expose weapon mechanic identity text." % [character_id, str(weapon_id)])
				return


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
	var expected_pairs := 0
	for character_id in ProgressionData.character_ids():
		expected_pairs += ProgressionData.weapon_ids(character_id).size()
	if checked != expected_pairs:
		_fail("Expected balance budget coverage for %d class+weapon pairs, got %d." % [expected_pairs, checked])
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
	if stage0_damage_cost != 47:
		_fail("Expected shop_damage stage 0 cost to include the 0.1.4 economy multiplier (47), got %d." % stage0_damage_cost)
		return
	var ordinary_drop := ProgressionData.drop_class_rewards("ordinary", 3, 0)
	var heavy_drop := ProgressionData.drop_class_rewards("heavy", 3, 0)
	var mini_drop := ProgressionData.drop_class_rewards("mini_elite", 3, 0)
	var elite_drop := ProgressionData.drop_class_rewards("elite", 3, 0)
	var boss_drop := ProgressionData.drop_class_rewards("boss", 3, 0)
	if int(heavy_drop["xp"]) < int(ordinary_drop["xp"]) * 1.5 or int(heavy_drop["money"]) < int(ordinary_drop["money"]) * 1.5:
		_fail("Expected heavy enemies to drop roughly 1.5-2x ordinary rewards.")
		return
	if int(mini_drop["xp"]) <= int(heavy_drop["xp"]) or int(elite_drop["xp"]) <= int(mini_drop["xp"]) or int(boss_drop["money"]) <= int(elite_drop["money"]):
		_fail("Expected drop classes to increase ordinary < heavy < mini_elite < elite < boss.")
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
	scaling_main.set("selected_character_id", "berserk")
	scaling_main.ui._show_reward_screen()
	await process_frame
	await process_frame
	var battle_reward_buttons := scaling_main.find_children("BattleRewardButton*", "Button", true, false)
	if battle_reward_buttons.size() != 3:
		_fail("Expected battle reward screen to render 3 SCRUM-338 framed reward cards.")
		scaling_main.queue_free()
		return
	if not _assert_reward_cards_use_scrum338_frames(battle_reward_buttons, "BattleRewardCardContent", REWARD_CARD_TEXTURE, REWARD_CARD_SAFE_MARGINS, "battle_reward"):
		scaling_main.queue_free()
		return
	scaling_main.ui._show_elite_artifact_reward(Callable())
	await process_frame
	await process_frame
	var reward_screen := scaling_main.find_child("EliteArtifactRewardScreen", true, false) as Control
	var reward_buttons := scaling_main.find_children("EliteArtifactRewardButton*", "Button", true, false)
	if reward_screen == null or reward_buttons.size() != 3:
		_fail("Expected elite artifact reward screen to render 3 clickable artifact buttons.")
		scaling_main.queue_free()
		return
	if not _assert_reward_cards_use_scrum338_frames(reward_buttons, "EliteArtifactRewardContent", REWARD_ELITE_CARD_TEXTURE, REWARD_ELITE_CARD_SAFE_MARGINS, "elite_reward"):
		scaling_main.queue_free()
		return
	scaling_main.queue_free()
	await process_frame

	var drop_main := main_scene.instantiate()
	root.add_child(drop_main)
	await process_frame
	drop_main.set("route_stage", 3)
	var elite_enemy: Node2D = drop_main.combat._spawn_random_enemy(drop_main.elite_armored_scene, drop_main.ARENA_CENTER, true)
	if elite_enemy == null or str(elite_enemy.get_meta("drop_class", "")) != "elite":
		_fail("Expected spawned elite to receive elite drop_class.")
		drop_main.queue_free()
		return
	var elite_xp := int(elite_enemy.get("reward_xp"))
	elite_enemy.take_damage(999999.0)
	await process_frame
	var found_elite_xp_pickup := false
	var found_elite_money_pickup := false
	for pickup in get_nodes_in_group("pickups"):
		if not is_instance_valid(pickup):
			continue
		if pickup.get("pickup_type") == "xp" and int(pickup.get("amount")) == elite_xp:
			found_elite_xp_pickup = true
		if pickup.get("pickup_type") == "money":
			found_elite_money_pickup = true
	if not found_elite_xp_pickup or not found_elite_money_pickup:
		_fail("Expected elite death to spawn visible XP and money pickups using drop rewards.")
		drop_main.queue_free()
		return
	drop_main.queue_free()
	await process_frame

	for viewport_size in [Vector2i(1280, 720), Vector2i(1469, 908), Vector2i(2560, 1440)]:
		await _assert_elite_reward_panel_centered(main_scene, viewport_size)


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


func _test_no_auto_player_movement_from_crit_or_dodge() -> void:
	var holder := Node2D.new()
	holder.name = "NoAutoMovementTestScene"
	root.add_child(holder)
	current_scene = holder

	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene

	var assassin := player_scene.instantiate()
	holder.add_child(assassin)
	assassin.global_position = Vector2(900, 720)
	await process_frame
	assassin.call("configure_character", "assassin", "chakrams")
	assassin.set("derived_parameters", {"damage": 30.0, "crit_chance": 1.0, "crit_damage_multiplier": 2.0})
	var weapon: Node = assassin.get("equipped_weapon")
	weapon.set_process(false)

	var target := enemy_scene.instantiate()
	holder.add_child(target)
	target.set("max_health", 100000.0)
	target.set("health", 100000.0)
	target.global_position = assassin.global_position + Vector2(160, 0)
	await process_frame

	var crit_position_before: Vector2 = assassin.global_position
	weapon.call("_damage_enemy", target, weapon.call("_rolled_damage", assassin))
	await create_timer(0.16).timeout
	if assassin.global_position.distance_to(crit_position_before) > 0.01:
		_fail("Expected critical weapon hooks to preserve player-controlled position.")
		return

	assassin.set("derived_parameters", {"dodge": 1.0, "defense": 0.0})
	var dodge_position_before: Vector2 = assassin.global_position
	assassin.call("take_damage", 12.0)
	await process_frame
	if assassin.global_position.distance_to(dodge_position_before) > 0.01:
		_fail("Expected dodge hooks to preserve player-controlled position.")
		return

	holder.queue_free()
	current_scene = null
	await process_frame


func _test_all_playable_classes() -> void:
	# Каждый класс экипирует сигнатурное оружие и наносит урон (друид — призывает).
	var signature := {
		"berserk": "sword", "soldier": "soldier_rifle", "thief": "thief_coin_pouch", "elementalist": "elementalist_orb_ring", "sniper": "sniper_deadeye_rifle", "priest": "priest_reliquary", "biologist": "biologist_spore_lens", "robot": "robot_magnetic_anchor", "engineer": "engineer_sentry_wrench", "dark_mage": "dark_wand", "guitarist": "electric_guitar",
		"assassin": "chakrams", "ranger": "moon_crossbow", "doctor": "restore_potion",
		"chemist": "blast_powder", "knight": "long_spear", "druid": "summon_amulet",
	}
	if ProgressionData.character_ids().size() != signature.size():
		_fail("Expected playable class data to match the signature smoke list.")
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


func _test_soldier_weapon_mechanics() -> void:
	var soldier_weapons := ProgressionData.weapon_ids("soldier")
	if soldier_weapons != ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]:
		_fail("Expected Soldier to expose exactly rifle/grenade/bayonet weapons.")
		return
	var expected_modes := {
		"soldier_rifle": "suppression_burst",
		"soldier_grenade": "grenade_cook",
		"soldier_bayonet": "bayonet_brace",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("soldier", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Soldier weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
		if ProgressionData.ascension_levels("soldier").size() != 10:
			_fail("Expected Soldier to have 10 ascension levels.")
			return

	var holder := Node2D.new()
	holder.name = "SoldierWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var soldier := player_scene.instantiate()
		holder.add_child(soldier)
		soldier.global_position = Vector2(800, 700)
		await process_frame
		soldier.call("configure_character", "soldier", weapon_id)
		var weapon: Node = soldier.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Soldier %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		var offset := Vector2(220, 0)
		if weapon_id == "soldier_bayonet":
			offset = Vector2(140, 0)
		enemy.global_position = soldier.global_position + offset
		await process_frame
		var before_hp := float(enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.85).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Soldier weapon %s to damage its target." % weapon_id)
			return
		soldier.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_thief_weapon_mechanics() -> void:
	var thief_weapons := ProgressionData.weapon_ids("thief")
	if thief_weapons != ["thief_coin_pouch", "thief_shadow_cloak", "thief_smoke_bomb"]:
		_fail("Expected Thief to expose exactly coin pouch/shadow cloak/smoke bomb weapons.")
		return
	var expected_modes := {
		"thief_coin_pouch": "coin_ricochet",
		"thief_shadow_cloak": "shadow_backstab",
		"thief_smoke_bomb": "smoke_bomb",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("thief", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Thief weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("thief").size() != 10:
		_fail("Expected Thief to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "ThiefWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var thief := player_scene.instantiate()
		holder.add_child(thief)
		thief.global_position = Vector2(860, 720)
		await process_frame
		thief.call("configure_character", "thief", weapon_id)
		var weapon: Node = thief.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Thief %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = thief.global_position + Vector2(180, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_money := int(thief.get("money"))
		var before_dodge := float((thief.get("derived_parameters") as Dictionary).get("dodge", 0.0))
		var before_position: Vector2 = thief.global_position
		weapon.call("_attack")
		await create_timer(0.85).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Thief weapon %s to damage its target." % weapon_id)
			return
		if weapon_id == "thief_shadow_cloak" and thief.global_position.distance_to(before_position) > 0.01:
			_fail("Expected Thief shadow cloak to strike without moving the player body.")
			return
		if weapon_id == "thief_coin_pouch" and int(thief.get("money")) <= before_money:
			_fail("Expected Thief coin pouch to steal money on hit.")
			return
		if weapon_id == "thief_smoke_bomb":
			var current_dodge := float((thief.get("derived_parameters") as Dictionary).get("dodge", 0.0))
			if current_dodge <= before_dodge:
				_fail("Expected Thief smoke bomb to grant temporary dodge.")
				return
		thief.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_elementalist_weapon_mechanics() -> void:
	var elementalist_weapons := ProgressionData.weapon_ids("elementalist")
	if elementalist_weapons != ["elementalist_orb_ring", "elementalist_prism_focus", "elementalist_meteor_core"]:
		_fail("Expected Elementalist to expose exactly orb/prism/meteor weapons.")
		return
	var expected_modes := {
		"elementalist_orb_ring": "elemental_orbit",
		"elementalist_prism_focus": "prism_rift",
		"elementalist_meteor_core": "meteor_shards",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("elementalist", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Elementalist weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("elementalist").size() != 10:
		_fail("Expected Elementalist to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "ElementalistWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var elementalist := player_scene.instantiate()
		holder.add_child(elementalist)
		elementalist.global_position = Vector2(860, 720)
		await process_frame
		elementalist.call("configure_character", "elementalist", weapon_id)
		var weapon: Node = elementalist.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Elementalist %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = elementalist.global_position + Vector2(160, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.95).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Elementalist weapon %s to damage its target." % weapon_id)
			return
		elementalist.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_sniper_weapon_mechanics() -> void:
	var sniper_weapons := ProgressionData.weapon_ids("sniper")
	if sniper_weapons != ["sniper_deadeye_rifle", "sniper_spotter_scope", "sniper_shatter_rounds"]:
		_fail("Expected Sniper to expose exactly deadeye/scope/shatter weapons.")
		return
	var expected_modes := {
		"sniper_deadeye_rifle": "sniper_lockshot",
		"sniper_spotter_scope": "sniper_kill_zone",
		"sniper_shatter_rounds": "sniper_split_round",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("sniper", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Sniper weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("sniper").size() != 10:
		_fail("Expected Sniper to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "SniperWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var sniper := player_scene.instantiate()
		holder.add_child(sniper)
		sniper.global_position = Vector2(860, 720)
		await process_frame
		sniper.call("configure_character", "sniper", weapon_id)
		var weapon: Node = sniper.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Sniper %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = sniper.global_position + Vector2(220, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.90).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Sniper weapon %s to damage its target." % weapon_id)
			return
		sniper.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_priest_weapon_mechanics() -> void:
	var priest_weapons := ProgressionData.weapon_ids("priest")
	if priest_weapons != ["priest_reliquary", "priest_censer", "priest_chime"]:
		_fail("Expected Priest to expose exactly reliquary/censer/chime weapons.")
		return
	var expected_modes := {
		"priest_reliquary": "priest_sanctify",
		"priest_censer": "priest_ward",
		"priest_chime": "priest_prayer_chain",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("priest", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Priest weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("priest").size() != 10:
		_fail("Expected Priest to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "PriestWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var priest := player_scene.instantiate()
		holder.add_child(priest)
		priest.global_position = Vector2(860, 720)
		await process_frame
		priest.call("configure_character", "priest", weapon_id)
		var weapon: Node = priest.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Priest %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = priest.global_position + Vector2(180, 0)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_player_hp := float(priest.get("health"))
		priest.set("health", maxf(1.0, before_player_hp - 18.0))
		weapon.call("_attack")
		await create_timer(0.85).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Priest weapon %s to damage its target." % weapon_id)
			return
		if weapon_id in ["priest_reliquary", "priest_chime"] and float(priest.get("health")) <= before_player_hp - 18.0:
			_fail("Expected Priest weapon %s to return sustain healing." % weapon_id)
			return
		priest.queue_free()
		enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_biologist_weapon_mechanics() -> void:
	var biologist_weapons := ProgressionData.weapon_ids("biologist")
	if biologist_weapons != ["biologist_spore_lens", "biologist_sample_injector", "biologist_symbiote_seed"]:
		_fail("Expected Biologist to expose exactly spore lens/sample injector/symbiote seed weapons.")
		return
	var expected_modes := {
		"biologist_spore_lens": "bio_spore_bloom",
		"biologist_sample_injector": "bio_sample_dart",
		"biologist_symbiote_seed": "bio_symbiote_web",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("biologist", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Biologist weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("biologist").size() != 10:
		_fail("Expected Biologist to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "BiologistWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var biologist := player_scene.instantiate()
		holder.add_child(biologist)
		biologist.global_position = Vector2(860, 720)
		await process_frame
		biologist.call("configure_character", "biologist", weapon_id)
		var weapon: Node = biologist.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Biologist %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = biologist.global_position + Vector2(180, 0)
		var second_enemy := enemy_scene.instantiate()
		holder.add_child(second_enemy)
		second_enemy.set("max_health", 100000.0)
		second_enemy.set("health", 100000.0)
		second_enemy.global_position = biologist.global_position + Vector2(230, 50)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_second_hp := float(second_enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.90).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Biologist weapon %s to damage its primary target." % weapon_id)
			return
		if weapon_id == "biologist_symbiote_seed" and float(second_enemy.get("health")) >= before_second_hp:
			_fail("Expected Biologist symbiote web to damage a linked nearby target.")
			return
		biologist.queue_free()
		enemy.queue_free()
		second_enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_robot_weapon_mechanics() -> void:
	var robot_weapons := ProgressionData.weapon_ids("robot")
	if robot_weapons != ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"]:
		_fail("Expected Robot to expose exactly magnetic anchor/hydraulic press/reactor core weapons.")
		return
	var expected_modes := {
		"robot_magnetic_anchor": "robot_magnetic_anchor",
		"robot_hydraulic_press": "robot_compression_line",
		"robot_reactor_core": "robot_reactor_vent",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("robot", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Robot weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("robot").size() != 10:
		_fail("Expected Robot to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "RobotWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var robot := player_scene.instantiate()
		holder.add_child(robot)
		robot.global_position = Vector2(860, 720)
		await process_frame
		robot.call("configure_character", "robot", weapon_id)
		var weapon: Node = robot.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Robot %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = robot.global_position + Vector2(180, 0)
		var second_enemy := enemy_scene.instantiate()
		holder.add_child(second_enemy)
		second_enemy.set("max_health", 100000.0)
		second_enemy.set("health", 100000.0)
		second_enemy.global_position = robot.global_position + Vector2(210, 70)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_second_hp := float(second_enemy.get("health"))
		weapon.call("_attack")
		await create_timer(0.55).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Robot weapon %s to damage its primary target." % weapon_id)
			return
		if weapon_id in ["robot_magnetic_anchor", "robot_reactor_core"] and float(second_enemy.get("health")) >= before_second_hp:
			_fail("Expected Robot weapon %s to affect a nearby secondary target." % weapon_id)
			return
		robot.queue_free()
		enemy.queue_free()
		second_enemy.queue_free()
		await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_engineer_weapon_mechanics() -> void:
	var engineer_weapons := ProgressionData.weapon_ids("engineer")
	if engineer_weapons != ["engineer_sentry_wrench", "engineer_repair_drone", "engineer_pressure_mines"]:
		_fail("Expected Engineer to expose exactly sentry wrench/repair drone/pressure mines weapons.")
		return
	var expected_modes := {
		"engineer_sentry_wrench": "engineer_sentry_link",
		"engineer_repair_drone": "engineer_repair_drone",
		"engineer_pressure_mines": "engineer_pressure_mines",
	}
	for weapon_id in expected_modes.keys():
		var config: Dictionary = ProgressionData.weapon("engineer", weapon_id)
		if str(config.get("attack_mode", "")) != str(expected_modes[weapon_id]):
			_fail("Expected Engineer weapon %s to use unique mode %s." % [weapon_id, expected_modes[weapon_id]])
			return
	if ProgressionData.ascension_levels("engineer").size() != 10:
		_fail("Expected Engineer to have 10 ascension levels.")
		return

	var holder := Node2D.new()
	holder.name = "EngineerWeaponMechanicsScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for weapon_id in expected_modes.keys():
		var engineer := player_scene.instantiate()
		holder.add_child(engineer)
		engineer.global_position = Vector2(860, 720)
		await process_frame
		engineer.call("configure_character", "engineer", weapon_id)
		var weapon: Node = engineer.get("equipped_weapon")
		if weapon == null:
			_fail("Expected Engineer %s to attach a weapon." % weapon_id)
			return
		weapon.set_process(false)
		var enemy := enemy_scene.instantiate()
		holder.add_child(enemy)
		enemy.set("max_health", 100000.0)
		enemy.set("health", 100000.0)
		enemy.global_position = engineer.global_position + Vector2(180, 0)
		var second_enemy := enemy_scene.instantiate()
		holder.add_child(second_enemy)
		second_enemy.set("max_health", 100000.0)
		second_enemy.set("health", 100000.0)
		second_enemy.global_position = engineer.global_position + Vector2(240, 45)
		await process_frame
		var before_hp := float(enemy.get("health"))
		var before_second_hp := float(second_enemy.get("health"))
		var before_player_hp := float(engineer.get("health"))
		engineer.set("health", maxf(1.0, before_player_hp - 15.0))
		weapon.call("_attack")
		await create_timer(1.35).timeout
		if float(enemy.get("health")) >= before_hp:
			_fail("Expected Engineer weapon %s to damage its primary target." % weapon_id)
			return
		if weapon_id in ["engineer_sentry_wrench", "engineer_repair_drone"] and float(second_enemy.get("health")) >= before_second_hp:
			_fail("Expected Engineer weapon %s to affect a secondary target." % weapon_id)
			return
		if weapon_id == "engineer_repair_drone" and float(engineer.get("health")) <= before_player_hp - 15.0:
			_fail("Expected Engineer repair drone to restore health from damage.")
			return
		engineer.queue_free()
		enemy.queue_free()
		second_enemy.queue_free()
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
	if absf(float(vamp["vampiric_chance"]) - ProgressionData.VAMPIRIC_CHANCE_CAP) > 0.001 \
			or absf(float(vamp["vampiric_amount"]) - 2.0 * ProgressionData.VAMPIRIC_BASE_HEAL_MULTIPLIER) > 0.001:
		_fail("Expected vampiric rewards to use SCRUM-255 nerfed chance/amount caps.")
		return
	var berserk_priorities: Array = ProgressionData.attribute_priorities("berserk")
	var mage_priorities: Array = ProgressionData.attribute_priorities("dark_mage")
	if berserk_priorities.slice(0, 3) != ["strength", "endurance", "agility"]:
		_fail("Expected Berserk priorities to start with strength/endurance/agility.")
		return
	if mage_priorities.slice(0, 3) != ["intelligence", "energy", "knowledge"]:
		_fail("Expected Dark Mage priorities to start with intelligence/energy/knowledge.")
		return
	var defense_reward := {"mods": {"defense_flat": 0.10}}
	if ProgressionData.level_up_reward_weight(defense_reward, "knight") <= ProgressionData.level_up_reward_weight(defense_reward, "dark_mage"):
		_fail("Expected weighted level-up rewards to favor defense more for Knight than Dark Mage.")
		return
	var off_priority_reward := {"mods": {"damage_multiplier": 1.10}}
	if ProgressionData.level_up_reward_weight(off_priority_reward, "dark_mage") <= 0.3:
		_fail("Expected weighted level-up rewards to keep off-priority rewards available.")
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
	# Шанс капится в формулах; для детерминизма теста форсируем гарантированный прок.
	var wiring_derived: Dictionary = wiring_player.get("derived_parameters")
	wiring_derived["vampiric_chance"] = 1.0
	wiring_derived["regeneration"] = 0.0
	wiring_player.set("derived_parameters", wiring_derived)
	wiring_player.set("health", float(wiring_player.get("max_health")) * 0.5)
	var hp_before_vamp := float(wiring_player.get("health"))
	wiring_player.call("_apply_regeneration", 1.0)
	wiring_player.call("on_weapon_hit", wiring_player, 10.0)
	if float(wiring_player.get("health")) <= hp_before_vamp:
		_fail("Expected a guaranteed vampiric hit to heal the player.")
		return
	if float(wiring_player.get("health")) - hp_before_vamp > 4.1:
		_fail("Expected vampiric healing to be capped by heal-per-second budget.")
		return
	wiring_derived["regeneration"] = 2.0
	wiring_player.set("derived_parameters", wiring_derived)
	var hp_before_regen := float(wiring_player.get("health"))
	wiring_player.call("_apply_regeneration", 5.0)
	if float(wiring_player.get("health")) <= hp_before_regen:
		_fail("Expected regeneration to heal over time.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame


func _test_attribute_weapon_synergy_matrix() -> void:
	var synergy_map: Dictionary = ProgressionData.attribute_weapon_synergy_map()
	var required_archetypes := ["melee", "projectile", "beam", "aoe", "summon", "aura"]
	var stat_ids := ProgressionData.STAT_NAMES.keys()
	for stat_id in stat_ids:
		var stat_map: Dictionary = synergy_map.get(stat_id, {}) as Dictionary
		for archetype in required_archetypes:
			if str(stat_map.get(archetype, "")) == "":
				_fail("Expected synergy map to explain %s x %s." % [stat_id, archetype])
				return

	var representatives := {}
	for character_id in ProgressionData.character_ids():
		for weapon_id in ProgressionData.weapon_ids(character_id):
			var weapon_config: Dictionary = ProgressionData.weapon(character_id, weapon_id)
			var archetype := ProgressionData.weapon_archetype(weapon_config)
			if not representatives.has(archetype):
				representatives[archetype] = {
					"character_id": character_id,
					"weapon_id": weapon_id,
					"weapon": weapon_config,
				}
	for archetype in required_archetypes:
		if not representatives.has(archetype):
			_fail("Expected at least one weapon representative for archetype %s." % archetype)
			return

	var watched_parameters := [
		"damage", "magic_damage", "sound_wave_damage", "attack_speed",
		"crit_chance", "crit_damage_multiplier", "move_speed", "dodge",
		"defense", "health_point", "attack_range", "aoe_radius",
		"pickup_radius", "dot_damage", "dot_speed", "projectile_speed",
		"aura_radius", "buff_power", "knockback_power", "summon_amount",
		"absorb", "regeneration", "knockback_distance", "ultimate_multiplier",
	]
	for archetype in required_archetypes:
		var rep: Dictionary = representatives[archetype]
		var character_id := str(rep.get("character_id", "berserk"))
		var weapon_config: Dictionary = rep.get("weapon", {}) as Dictionary
		var base_stats: Dictionary = ProgressionData.base_stats(character_id)
		var base_params: Dictionary = ProgressionData.derived_parameters(base_stats, {}, weapon_config)
		for stat_id in stat_ids:
			var boosted_stats := base_stats.duplicate(true)
			boosted_stats[stat_id] = float(boosted_stats.get(stat_id, 0.0)) + 4.0
			var boosted_params: Dictionary = ProgressionData.derived_parameters(boosted_stats, {}, weapon_config)
			var changed := false
			for parameter_id in watched_parameters:
				if absf(float(boosted_params.get(parameter_id, 0.0)) - float(base_params.get(parameter_id, 0.0))) > 0.001:
					changed = true
					break
			if not changed:
				_fail("Expected %s to change at least one effective parameter for %s weapon %s/%s." % [
					stat_id,
					archetype,
					character_id,
					str(rep.get("weapon_id", "")),
				])
				return


func _test_settings_persistence_and_audio() -> void:
	# Save/load roundtrip настроек.
	var game_settings := load("res://scripts/game_settings.gd")
	var legacy_config := ConfigFile.new()
	legacy_config.set_value(game_settings.SECTION, "resolution_index", 1)
	legacy_config.set_value(game_settings.SECTION, "window_mode_index", 0)
	legacy_config.set_value(game_settings.SECTION, "screen_index", 0)
	legacy_config.set_value(game_settings.SECTION, "master_volume", 0.0)
	legacy_config.set_value(game_settings.SECTION, "music_volume", 1.0)
	legacy_config.set_value(game_settings.SECTION, "sfx_volume", 1.0)
	legacy_config.set_value(game_settings.SECTION, "music_enabled", true)
	legacy_config.set_value(game_settings.SECTION, "sfx_enabled", true)
	legacy_config.save(game_settings.SAVE_PATH)
	var migrated: Dictionary = game_settings.load_settings()
	if absf(float(migrated.get("master_volume", 0.0)) - 1.0) > 0.001:
		_fail("Expected legacy master_volume=0 without explicit intent to migrate back to 100%.")
		return
	var saved := {
		"resolution_index": 2, "window_mode_index": 1, "screen_index": 1,
		"master_volume": 0.85, "music_volume": 0.4, "sfx_volume": 0.65,
		"music_enabled": false, "sfx_enabled": true, "aim_mode": "cursor",
		"debug_mode": true,
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
	var master_bus := AudioServer.get_bus_index("Master")
	audio.apply_volume_settings({"master_volume": 0.0, "music_volume": 1.0, "sfx_volume": 1.0, "music_enabled": true, "sfx_enabled": true})
	if AudioServer.is_bus_mute(master_bus):
		_fail("Expected master_volume=0 to set quiet volume without hard-muting the Master bus.")
		return
	if AudioServer.get_bus_volume_db(master_bus) > -70.0:
		_fail("Expected master_volume=0 to apply a very quiet Master bus volume.")
		return
	audio.apply_volume_settings({"master_volume": 1.0, "music_volume": 0.5, "sfx_volume": 1.0, "music_enabled": false, "sfx_enabled": true})
	var music_bus := AudioServer.get_bus_index("Music")
	if not AudioServer.is_bus_mute(music_bus):
		_fail("Expected the music toggle to mute the Music bus.")
		return
	if absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.5)) > 0.1:
		_fail("Expected the music slider to set bus volume (value preserved while muted).")
		return
	if AudioServer.is_bus_mute(master_bus):
		_fail("Expected toggling Music to not mute the Master bus.")
		return
	audio.apply_volume_settings({"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0, "music_enabled": true, "sfx_enabled": true})


func _test_feedback_overlay_and_local_fallback(main_scene: PackedScene) -> void:
	var feedback_main := main_scene.instantiate()
	root.add_child(feedback_main)
	await process_frame
	if not InputMap.has_action("feedback"):
		_fail("Expected feedback InputMap action to exist.")
		feedback_main.queue_free()
		await process_frame
		return
	var feedback_has_p := false
	for event in InputMap.action_get_events("feedback"):
		if event is InputEventKey and int(event.keycode) == KEY_P:
			feedback_has_p = true
	if not feedback_has_p:
		_fail("Expected feedback InputMap action to default to P.")
		feedback_main.queue_free()
		await process_frame
		return

	var feedback_event := InputEventKey.new()
	feedback_event.keycode = KEY_P
	feedback_event.physical_keycode = KEY_P
	feedback_event.pressed = true
	feedback_main.call("_input", feedback_event)
	await process_frame
	var overlay := feedback_main.get("feedback_overlay_layer") as CanvasLayer
	if overlay == null or not is_instance_valid(overlay):
		_fail("Expected P to open FeedbackOverlayLayer.")
		feedback_main.queue_free()
		await process_frame
		return
	var text_edit := feedback_main.find_child("FeedbackTextEdit", true, false) as TextEdit
	var preview := feedback_main.find_child("FeedbackScreenshotPreview", true, false) as TextureRect
	if text_edit == null or preview == null or preview.texture == null:
		_fail("Expected feedback overlay to show text input and screenshot preview.")
		feedback_main.queue_free()
		await process_frame
		return

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.physical_keycode = KEY_ESCAPE
	escape_event.pressed = true
	feedback_main.call("_input", escape_event)
	await process_frame
	if feedback_main.get("feedback_overlay_layer") != null:
		_fail("Expected Escape to close feedback overlay.")
		feedback_main.queue_free()
		await process_frame
		return

	var screenshot := Image.create(32, 18, false, Image.FORMAT_RGBA8)
	screenshot.fill(Color(0.12, 0.18, 0.24, 1.0))
	var local_path := FeedbackReporter.save_local_report("Smoke feedback fallback", screenshot, {
		"screen": "runtime_smoke",
		"version": "test",
	})
	if not FileAccess.file_exists("%s/report.txt" % local_path) or not FileAccess.file_exists("%s/screenshot.png" % local_path):
		_fail("Expected feedback local fallback to write report.txt and screenshot.png under %s." % local_path)
		feedback_main.queue_free()
		await process_frame
		return
	var boundary := "----FantasyDiskSmokeBoundary"
	var multipart := FeedbackReporter.multipart_payload("Smoke payload", screenshot, {"screen": "runtime_smoke"}, boundary)
	if not _packed_bytes_contains(multipart, "payload_json".to_utf8_buffer()) or not _packed_bytes_contains(multipart, FeedbackReporter.UPLOAD_FILENAME.to_utf8_buffer()):
		_fail("Expected feedback multipart payload to include Discord payload_json and screenshot file part.")
		feedback_main.queue_free()
		await process_frame
		return
	var payload_json := _feedback_multipart_payload_json(multipart, boundary)
	var multipart_filename := _feedback_multipart_file_filename(multipart)
	var attachments: Array = payload_json.get("attachments", [])
	if attachments.size() != 1 or not attachments[0] is Dictionary:
		_fail("Expected feedback payload_json to declare one Discord attachment.")
		feedback_main.queue_free()
		await process_frame
		return
	var attachment := attachments[0] as Dictionary
	if int(attachment.get("id", -1)) != 0 or str(attachment.get("filename", "")) != multipart_filename or multipart_filename != FeedbackReporter.UPLOAD_FILENAME:
		_fail("Expected feedback payload_json attachment filename to match files[0] filename.")
		feedback_main.queue_free()
		await process_frame
		return
	feedback_main.queue_free()
	await process_frame


func _feedback_multipart_payload_json(multipart: PackedByteArray, boundary: String) -> Dictionary:
	var text := _feedback_multipart_header_text(multipart)
	var marker := "Content-Type: application/json\r\n\r\n"
	var start := text.find(marker)
	if start < 0:
		return {}
	start += marker.length()
	var end := text.find("\r\n--%s" % boundary, start)
	if end < 0:
		return {}
	var parsed = JSON.parse_string(text.substr(start, end - start))
	return parsed if parsed is Dictionary else {}


func _feedback_multipart_file_filename(multipart: PackedByteArray) -> String:
	var text := _feedback_multipart_header_text(multipart)
	var marker := "Content-Disposition: form-data; name=\"files[0]\"; filename=\""
	var start := text.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end := text.find("\"", start)
	if end < 0:
		return ""
	return text.substr(start, end - start)


func _feedback_multipart_header_text(multipart: PackedByteArray) -> String:
	# Вложение files[0] теперь JPEG (SOI FF D8 FF), не PNG — отсекаем бинарь по его
	# сигнатуре, оставляя текстовые заголовки multipart для парсинга (SCRUM-460).
	var jpeg_signature := PackedByteArray([0xFF, 0xD8, 0xFF])
	var bin_start := _packed_bytes_find(multipart, jpeg_signature)
	var header := PackedByteArray()
	var length := bin_start if bin_start >= 0 else multipart.size()
	for index in range(length):
		header.append(multipart[index])
	return header.get_string_from_utf8()


func _packed_bytes_find(haystack: PackedByteArray, needle: PackedByteArray) -> int:
	if needle.is_empty() or haystack.size() < needle.size():
		return -1
	for index in range(haystack.size() - needle.size() + 1):
		var matched := true
		for offset in range(needle.size()):
			if haystack[index + offset] != needle[offset]:
				matched = false
				break
		if matched:
			return index
	return -1


func _packed_bytes_contains(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	return _packed_bytes_find(haystack, needle) >= 0


func _test_settings_tabs_and_rebind(main: Node) -> void:
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	if tabs == null or tabs.get_child_count() != 3:
		_fail("Expected settings screen to use three tabs.")
		return
	for tab_name in ["Экран", "Звук", "Управление"]:
		if tabs.get_node_or_null(tab_name) == null:
			_fail("Expected settings tab %s to exist." % tab_name)
			return
	var tab_switcher := main.find_child("SettingsTabSwitcher", true, false) as Control
	var tab_switcher_frame := main.find_child("SettingsTabSwitcherFrame", true, false) as Panel
	if tab_switcher == null or tab_switcher_frame == null:
		_fail("Expected settings screen to use the SettingsTabSwitcher frame panel.")
		return
	var tab_switcher_frame_path := _stylebox_texture_path(tab_switcher_frame.get_theme_stylebox("panel"))
	if tab_switcher_frame_path != MINIMAL_FIELD_TEXTURE:
		_fail("Expected settings screen to use the SCRUM-448 minimal field switcher texture, got %s." % tab_switcher_frame_path)
		return
	var switcher_rect := tab_switcher.get_global_rect()
	var base_size := Vector2(616.0, 286.0)
	var content_margins := Vector4(59.0, 53.0, 59.0, 50.0)
	var content_left := roundf(switcher_rect.size.x * content_margins.x / base_size.x)
	var content_top := roundf(switcher_rect.size.y * content_margins.y / base_size.y)
	var content_right := roundf(switcher_rect.size.x * content_margins.z / base_size.x)
	var content_bottom := roundf(switcher_rect.size.y * content_margins.w / base_size.y)
	var safe_rect := Rect2(
		Vector2(content_left, content_top),
		Vector2(
			maxf(1.0, switcher_rect.size.x - content_left - content_right),
			maxf(1.0, switcher_rect.size.y - content_top - content_bottom)
		)
	)
	var tab_gap := maxf(6.0, roundf(switcher_rect.size.x * 0.014))
	var tab_width := maxf(1.0, (safe_rect.size.x - tab_gap * 2.0) / 3.0)
	if main.find_child("SettingsTabButton_3", true, false) != null:
		_fail("Expected 3-slot settings switcher to avoid an obsolete fourth tab hit area.")
		return
	var settings_switcher_dump := PackedStringArray()
	settings_switcher_dump.append("# SCRUM-448 Settings Minimal Runtime Layout")
	settings_switcher_dump.append("")
	settings_switcher_dump.append("- frame_path: `%s`" % tab_switcher_frame_path)
	settings_switcher_dump.append("- switcher_rect: `%s`" % str(switcher_rect))
	settings_switcher_dump.append("- base_size: `%s`" % str(base_size))
	settings_switcher_dump.append("- display_size: `%s`" % str(switcher_rect.size))
	var modal := main.find_child("SettingsV2Modal", true, false) as Control
	var content_panel := main.find_child("SettingsContentPanel", true, false) as Control
	if modal != null:
		settings_switcher_dump.append("- modal_rect: `%s`" % str(modal.get_global_rect()))
	if content_panel != null:
		settings_switcher_dump.append("- content_panel_rect: `%s`" % str(content_panel.get_global_rect()))
	settings_switcher_dump.append("")
	settings_switcher_dump.append("| tab | actual | expected scaled safe rect | source safe rect |")
	settings_switcher_dump.append("| --- | --- | --- | --- |")
	for tab_index in range(3):
		var tab_button := main.find_child("SettingsTabButton_%d" % tab_index, true, false) as Button
		if tab_button == null:
			_fail("Expected SettingsTabButton_%d to exist." % tab_index)
			return
		var expected := Rect2(
			switcher_rect.position + safe_rect.position + Vector2(float(tab_index) * (tab_width + tab_gap), 0.0),
			Vector2(tab_width, safe_rect.size.y)
		)
		var actual := tab_button.get_global_rect()
		settings_switcher_dump.append("| `%d` | `%s` | `%s` | `%s` |" % [tab_index, str(actual), str(expected), str(safe_rect)])
		if actual.position.distance_to(expected.position) > 3.0 or actual.size.distance_to(expected.size) > 3.0:
			_fail("Expected SettingsTabButton_%d to stay inside its recorded safe rect. Actual=%s expected=%s" % [tab_index, str(actual), str(expected)])
			return
		tab_button.pressed.emit()
		await process_frame
		if tabs.current_tab != tab_index:
			_fail("Expected SettingsTabButton_%d to switch SettingsTabs current_tab." % tab_index)
			return
	var settings_switcher_qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum439")
	DirAccess.make_dir_recursive_absolute(settings_switcher_qa_dir)
	var settings_switcher_file := FileAccess.open("%s/settings_v2_runtime_rects.md" % settings_switcher_qa_dir, FileAccess.WRITE)
	if settings_switcher_file != null:
		settings_switcher_file.store_string("\n".join(settings_switcher_dump))
		settings_switcher_file.close()
	var scrum448_settings_dir := ProjectSettings.globalize_path("res://build/qa/scrum448_ui_minimalist")
	DirAccess.make_dir_recursive_absolute(scrum448_settings_dir)
	var scrum448_settings_file := FileAccess.open("%s/settings_minimal_runtime_rects.md" % scrum448_settings_dir, FileAccess.WRITE)
	if scrum448_settings_file != null:
		scrum448_settings_file.store_string("\n".join(settings_switcher_dump))
		scrum448_settings_file.close()
	if DisplayServer.get_name() != "headless":
		var settings_switcher_image := main.get_viewport().get_texture().get_image()
		if settings_switcher_image != null:
			settings_switcher_image.save_png("%s/settings_v2_runtime.png" % settings_switcher_qa_dir)
	var controls_scroll := main.find_child("ControlsScroll", true, false) as ScrollContainer
	if controls_scroll == null:
		_fail("Expected controls settings tab to wrap bindings in ControlsScroll.")
		return
	if controls_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or controls_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("Expected ControlsScroll to use vertical-only scrolling.")
		return
	if not controls_scroll.follow_focus:
		_fail("Expected ControlsScroll to follow keyboard/gamepad focus.")
		return
	var controls_content := controls_scroll.find_child("ControlsContent", true, false) as VBoxContainer
	if controls_content == null:
		_fail("Expected ControlsScroll to contain ControlsContent.")
		return
	var reset_bindings := controls_content.find_child("SettingsResetBindingsButton", true, false) as Button
	if reset_bindings == null:
		_fail("Expected reset bindings button to live inside the scrollable controls content.")
		return
	if controls_content.find_child("SettingsAimModeOption", true, false) == null:
		_fail("Expected aim mode selector to live inside the scrollable controls content.")
		return
	var debug_toggle := controls_content.find_child("DebugModeToggle", true, false) as CheckBox
	if debug_toggle == null:
		_fail("Expected controls settings to expose the DebugModeToggle.")
		return
	debug_toggle.button_pressed = true
	debug_toggle.toggled.emit(true)
	await process_frame
	var game_settings := load("res://scripts/game_settings.gd")
	var loaded_debug: Dictionary = game_settings.load_settings()
	if not bool(main.get("debug_mode_enabled")) or not bool(loaded_debug.get("debug_mode", false)):
		_fail("Expected DebugModeToggle to update runtime state and persist to settings.")
		return
	debug_toggle.button_pressed = false
	debug_toggle.toggled.emit(false)
	await process_frame
	loaded_debug = game_settings.load_settings()
	if bool(main.get("debug_mode_enabled")) or bool(loaded_debug.get("debug_mode", true)):
		_fail("Expected DebugModeToggle to restore OFF state.")
		return
	_write_debug_settings_artifact(main, debug_toggle)
	var combat_feedback_toggle := controls_content.find_child("CombatFeedbackToggle", true, false) as CheckBox
	if combat_feedback_toggle == null:
		_fail("Expected controls settings to expose the CombatFeedbackToggle.")
		return
	combat_feedback_toggle.button_pressed = false
	combat_feedback_toggle.toggled.emit(false)
	await process_frame
	var loaded_feedback: Dictionary = game_settings.load_settings()
	if bool(main.get("combat_feedback_enabled")) or bool(loaded_feedback.get("combat_feedback", true)):
		_fail("Expected CombatFeedbackToggle to update runtime state and persist OFF.")
		return
	combat_feedback_toggle.button_pressed = true
	combat_feedback_toggle.toggled.emit(true)
	await process_frame
	loaded_feedback = game_settings.load_settings()
	if not bool(main.get("combat_feedback_enabled")) or not bool(loaded_feedback.get("combat_feedback", false)):
		_fail("Expected CombatFeedbackToggle to restore ON state.")
		return
	if controls_content.get_child_count() < 8:
		_fail("Expected controls content to include aim mode, binding rows, hint, and reset button.")
		return
	tabs.current_tab = 1
	await process_frame
	for slider_id in ["master_volume", "music_volume", "sfx_volume"]:
		var slider := main.find_child("VolumeSlider_%s" % slider_id, true, false) as HSlider
		if slider == null or not slider.visible or slider.max_value != 100.0:
			_fail("Expected visible 0-100 settings slider for %s." % slider_id)
			return
		if not bool(slider.size_flags_horizontal & Control.SIZE_EXPAND_FILL):
			_fail("Expected %s slider to expand across the audio tab." % slider_id)
			return
		var track := slider.get_theme_stylebox("slider")
		var fill := slider.get_theme_stylebox("grabber_area")
		if not (track is StyleBoxFlat) or track.content_margin_top < 8.0 or track.content_margin_bottom < 8.0:
			_fail("Expected %s slider to have a visible non-zero-height track StyleBoxFlat." % slider_id)
			return
		if not (fill is StyleBoxFlat) or (fill as StyleBoxFlat).bg_color.a < 0.5:
			_fail("Expected %s slider to have a visible filled track area." % slider_id)
			return
		if slider.step > 2.0 or slider.focus_mode != Control.FOCUS_ALL:
			_fail("Expected %s slider to support fine keyboard focus adjustments." % slider_id)
			return
	var music_toggle := main.find_child("VolumeToggle_music_enabled", true, false) as CheckBox
	if music_toggle == null or (music_toggle.text != "Вкл." and music_toggle.text != "Выкл."):
		_fail("Expected music mute toggle to use clear Вкл./Выкл. text.")
		return
	var music_slider := main.find_child("VolumeSlider_music_volume", true, false) as HSlider
	var master_slider := main.find_child("VolumeSlider_master_volume", true, false) as HSlider
	if master_slider == null:
		_fail("Expected master volume slider to exist.")
		return
	master_slider.value = 24.0
	await process_frame
	var master_bus := AudioServer.get_bus_index("Master")
	if absf(AudioServer.get_bus_volume_db(master_bus) - linear_to_db(0.24)) > 0.1:
		_fail("Expected moving the master slider to apply the Master bus live.")
		return
	music_slider.value = 42.0
	await process_frame
	var loaded_audio: Dictionary = game_settings.load_settings()
	if absf(float(loaded_audio.get("master_volume", 0.0)) - 0.24) > 0.021:
		_fail("Expected moving the master slider to persist live volume.")
		return
	if absf(float(loaded_audio.get("music_volume", 0.0)) - 0.42) > 0.021:
		_fail("Expected moving the music slider to persist live volume.")
		return
	var reset_audio := main.find_child("SettingsResetAudioButton", true, false) as Button
	if reset_audio == null:
		_fail("Expected sound settings to expose a reset audio defaults button.")
		return
	reset_audio.pressed.emit()
	await process_frame
	loaded_audio = game_settings.load_settings()
	if absf(float(loaded_audio.get("master_volume", 0.0)) - 1.0) > 0.001 or absf(float(loaded_audio.get("music_volume", 0.0)) - 1.0) > 0.001 or absf(float(loaded_audio.get("sfx_volume", 0.0)) - 1.0) > 0.001:
		_fail("Expected audio reset button to restore all audio sliders to 100%.")
		return
	if not bool(loaded_audio.get("music_enabled", false)) or not bool(loaded_audio.get("sfx_enabled", false)):
		_fail("Expected audio reset button to enable music and SFX.")
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
	var loaded: Dictionary = game_settings.load_settings()
	var bindings: Dictionary = loaded.get("input_bindings", {})
	if not bindings.has("ultimate") or not (KEY_T in (bindings["ultimate"] as Array)):
		_fail("Expected ultimate rebind to persist in settings.cfg.")
		return
	ui.call("_reset_input_bindings_to_defaults")
	if not (KEY_R in _keycodes_for_action("ultimate")):
		_fail("Expected reset defaults to restore ultimate to R.")
		return


func _write_debug_settings_artifact(main: Node, debug_toggle: CheckBox) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum375")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump := PackedStringArray()
	dump.append("# SCRUM-375 Settings Debug Toggle")
	dump.append("")
	dump.append("- toggle: `%s`" % str(debug_toggle.get_global_rect()))
	dump.append("- text: `%s`" % debug_toggle.text)
	var viewport := main.get_viewport()
	if viewport != null and DisplayServer.get_name() != "headless":
		var image := viewport.get_texture().get_image()
		if image != null and image.get_width() > 0 and image.get_height() > 0:
			var png_path := "%s/settings_debug_mode_toggle.png" % qa_dir
			image.save_png(png_path)
			dump.append("- screenshot: `%s`" % png_path)
	else:
		dump.append("- screenshot: skipped in headless; rect dump is authoritative.")
	var file := FileAccess.open("%s/settings_debug_mode_toggle.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump))
		file.close()


func _keycodes_for_action(action_name: String) -> Array:
	var keys := []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			keys.append((event as InputEventKey).keycode)
	return keys


func _test_debug_combat_click_to_move(main_scene: PackedScene) -> void:
	var debug_main := main_scene.instantiate()
	root.add_child(debug_main)
	await process_frame
	debug_main.set("selected_character_id", "berserk")
	debug_main.set("selected_weapon_id", "sword")
	debug_main.call("_start_combat")
	await process_frame
	await process_frame
	var player := debug_main.get("current_player") as Node2D
	if player == null:
		_fail("Expected debug click-to-move smoke to spawn a player.")
		debug_main.queue_free()
		await process_frame
		return
	debug_main.set("debug_mode_enabled", false)
	var screen_target := root.get_visible_rect().size * 0.5 + Vector2(180.0, 0.0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = screen_target
	click.pressed = true
	debug_main.call("_input", click)
	await process_frame
	if bool(player.call("debug_has_move_target")):
		_fail("Expected debug click-to-move to ignore combat clicks while debug_mode is OFF.")
		debug_main.queue_free()
		await process_frame
		return
	debug_main.set("debug_mode_enabled", true)
	var expected_target: Vector2 = debug_main.call("_screen_position_to_arena_world", screen_target)
	debug_main.call("_input", click)
	await process_frame
	if not bool(player.call("debug_has_move_target")):
		_fail("Expected debug_mode ON right-click to assign a player move target.")
		debug_main.queue_free()
		await process_frame
		return
	var assigned_target: Vector2 = player.call("debug_move_target_position")
	if assigned_target.distance_to(expected_target) > 2.0:
		_fail("Expected assigned debug target %s to match screen-to-world target %s." % [str(assigned_target), str(expected_target)])
		debug_main.queue_free()
		await process_frame
		return
	var start_position := player.global_position
	for _step in range(8):
		player.call("_physics_process", 0.1)
	if player.global_position.distance_to(expected_target) >= start_position.distance_to(expected_target):
		_fail("Expected player to move closer to debug click target.")
		debug_main.queue_free()
		await process_frame
		return
	Input.action_press("move_left")
	player.call("_physics_process", 0.1)
	Input.action_release("move_left")
	if bool(player.call("debug_has_move_target")):
		_fail("Expected manual movement input to cancel debug click-to-move target.")
		debug_main.queue_free()
		await process_frame
		return
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.position = screen_target + Vector2(0.0, 90.0)
	middle.pressed = true
	var instant_target: Vector2 = debug_main.call("_screen_position_to_arena_world", middle.position)
	debug_main.call("_input", middle)
	await process_frame
	if player.global_position.distance_to(instant_target) > 2.0:
		_fail("Expected middle-click debug input to teleport player to the clamped arena target.")
		debug_main.queue_free()
		await process_frame
		return
	debug_main.queue_free()
	await process_frame


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
	# SCRUM-524: типы урона изолированы по атрибутам. Сила — атрибут ФИЗИЧЕСКОГО
	# урона, поэтому остаётся универсально полезной (поднимает physical damage даже
	# магу), но НЕ протекает в магический урон (изоляция по типам).
	if float(after.get("damage", 0.0)) <= float(before.get("damage", 0.0)):
		_fail("Expected +10 strength to raise dark mage physical damage (universal stat usefulness).")
		return
	if absf(float(after.get("magic_damage", 0.0)) - float(before.get("magic_damage", 0.0))) > 0.0001:
		_fail("Expected +10 strength NOT to change dark mage magic damage (SCRUM-524 damage-type isolation).")
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

	# 4b. Состав 3 вариантов: уникальность + РЕДКОСТЬ основной характеристики (~3-7%/слот).
	#     Большой детерминированный сэмпл; редкие помечены rare=true + kind "stat".
	(fix_main.get("rng") as RandomNumberGenerator).seed = 90125
	var rare_slots := 0
	var total_slots := 0
	var draws := 400
	for _draw in range(draws):
		var offer: Array = fix_main.ui._random_level_up_rewards(3)
		if offer.size() != 3:
			_fail("Expected level-up generator to always return three options.")
			return
		var seen_ids := {}
		for entry in offer:
			var reward: Dictionary = entry
			var rid := str(reward.get("id"))
			if seen_ids.has(rid):
				_fail("Expected level-up options within a draw to be unique.")
				return
			seen_ids[rid] = true
			total_slots += 1
			if bool(reward.get("rare", false)):
				rare_slots += 1
				if str(reward.get("kind")) != "stat" or not (reward.get("stats", {}) as Dictionary).size() > 0:
					_fail("Expected rare level-up slot to be a main-characteristic stat reward.")
					return
	var rare_fraction := float(rare_slots) / float(total_slots)
	if rare_fraction < 0.025 or rare_fraction > 0.085:
		_fail("Expected rare main-characteristic frequency near 3-7%%, got %.1f%%." % (rare_fraction * 100.0))
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
	# SCRUM-358: L1 enemy hp 1.20, L1 dmg 1.14, L2 price 1.25, L3 spawn density 1.26 — кумулятивно активны.
	if absf(float(level3["enemy_hp_mult"]) - 1.20) > 0.001 or absf(float(level3["price_mult"]) - 1.25) > 0.001 or absf(float(level3["spawn_count_mult"]) - 1.26) > 0.001:
		_fail("Expected level 3 to cumulatively include levels 1+2+3 modifiers.")
		return
	var level0_change := ProgressionData.ascension_level_change_line(0)
	if not level0_change.to_lower().contains("без усложнений"):
		_fail("Expected ascension level 0 delta text to say no complications, got: %s" % level0_change)
		return
	var level3_change := ProgressionData.ascension_level_change_line(3)
	if not level3_change.contains("Уровень 3") or not level3_change.contains("Быстрая орда"):
		_fail("Expected ascension level 3 delta text to describe only level 3, got: %s" % level3_change)
		return
	if level3_change.contains("Закалённые враги") or level3_change.contains("Жадные торговцы"):
		_fail("Expected ascension level 3 delta text not to include lower-level changes, got: %s" % level3_change)
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

	# UI у кнопки старта показывает дельту выбранного уровня, а не кумулятивный список.
	var delta_main := main_scene.instantiate()
	root.add_child(delta_main)
	await process_frame
	var delta_meta := MetaProgression.default_state()
	for unlock_level in range(2):
		delta_meta = MetaProgression.record_boss_victory(delta_meta, "berserk", unlock_level)
	delta_main.set("meta_state", delta_meta)
	delta_main.set("selected_character_id", "berserk")
	delta_main.set("selected_ascension_level", 0)
	delta_main.call("_show_character_select")
	await process_frame
	await process_frame
	if int(delta_main.get("selected_ascension_level")) != delta_main.call("ascension_selectable_max", "berserk"):
		_fail("Expected hero select to default ascension to the selected class selectable max.")
		return
	var asc_label := delta_main.find_child("AscensionLevelLabel", true, false) as Label
	if asc_label == null or (not asc_label.text.contains("3 / 3") and not asc_label.text.contains("3/3")):
		_fail("Expected hero select ascension label to reflect selectable max 3/3, got: %s" % (asc_label.text if asc_label != null else "<missing>"))
		return
	var asc_mods_label := delta_main.find_child("AscensionModsLabel", true, false) as Label
	if asc_mods_label == null:
		_fail("Expected AscensionModsLabel on hero select.")
		return
	if not asc_mods_label.text.contains("Уровень 3") or not asc_mods_label.text.contains("Быстрая орда"):
		_fail("Expected hero select ascension label to show selected level delta, got: %s" % asc_mods_label.text)
		return
	if asc_mods_label.text.contains("Закалённые враги") or asc_mods_label.text.contains("Жадные торговцы"):
		_fail("Expected hero select ascension label not to show cumulative lower-level changes, got: %s" % asc_mods_label.text)
		return
	var asc_minus_button := delta_main.find_child("AscensionMinusButton", true, false) as Button
	if asc_minus_button == null:
		_fail("Expected AscensionMinusButton on hero select.")
		return
	asc_minus_button.pressed.emit()
	await process_frame
	if int(delta_main.get("selected_ascension_level")) != 2:
		_fail("Expected manual ascension decrease to remain available after max default.")
		return
	asc_minus_button.pressed.emit()
	asc_minus_button.pressed.emit()
	await process_frame
	asc_mods_label = delta_main.find_child("AscensionModsLabel", true, false) as Label
	if asc_mods_label == null or not asc_mods_label.text.to_lower().contains("без усложнений"):
		_fail("Expected hero select ascension level 0 label to say no complications.")
		return
	var hero_carousel := delta_main.find_child("HS4Carousel", true, false) as Control
	if hero_carousel == null:
		_fail("Expected hero select v4 carousel for ascension class-switch smoke.")
		return
	var next_hero_button: Button = null
	for carousel_child in hero_carousel.get_children():
		var carousel_nav_button := carousel_child as Button
		if carousel_nav_button != null and carousel_nav_button.text == "►":
			next_hero_button = carousel_nav_button
			break
	var selected_dark_mage := false
	for _page in range(ProgressionData.character_ids().size()):
		for carousel_child in hero_carousel.get_children():
			var hero_slot := carousel_child as TextureButton
			if hero_slot == null or not hero_slot.visible:
				continue
			hero_slot.pressed.emit()
			await process_frame
			if str(delta_main.get("selected_character_id")) == "dark_mage":
				selected_dark_mage = true
				break
		if selected_dark_mage:
			break
		if next_hero_button == null:
			break
		next_hero_button.pressed.emit()
		await process_frame
	if not selected_dark_mage:
		_fail("Expected hero select v4 carousel to expose dark mage for ascension class-switch smoke.")
		return
	var dark_mage_max: int = int(delta_main.call("ascension_selectable_max", "dark_mage"))
	if int(delta_main.get("selected_ascension_level")) != dark_mage_max:
		_fail("Expected hero class switch to recalculate ascension default to dark mage selectable max.")
		return
	delta_main.queue_free()
	await process_frame

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
	# Убиваемая, не танк: HP = тот же волновой elite-скейл × data-driven hp_mult вида.
	var mini_node: Node = spawned[0]
	var mini_hp: float = float(mini_node.get("max_health"))
	var expected_mini_scale: float = float(ProgressionData.enemy_size_profile("mini_elite").get("scale", 1.05))
	var expected_elite_scale: float = float(ProgressionData.enemy_size_profile("elite").get("scale", 1.68))
	if absf((mini_node as Node2D).scale.x - expected_mini_scale) > 0.01:
		_fail("Expected spawned ascension mini-elite scale %.2f, got %.2f." % [expected_mini_scale, (mini_node as Node2D).scale.x])
		return
	if expected_mini_scale >= expected_elite_scale:
		_fail("Expected mini-elite size profile to stay smaller than card elite.")
		return
	var expected_hp_mult := 0.55
	var mini_kind_id := str(mini_node.get_meta("mini_elite_kind", ""))
	for kind in ProgressionData.mini_elite_kinds():
		if str((kind as Dictionary).get("id", "")) == mini_kind_id:
			expected_hp_mult = float((kind as Dictionary).get("hp_mult", expected_hp_mult))
			break
	var ref_elite: Node = (load(mini_node.scene_file_path) as PackedScene).instantiate()
	ref_elite.add_to_group("elite_enemies")
	mini_main.add_child(ref_elite)
	mini_main.combat.call("_scale_enemy_for_current_wave", ref_elite)
	var ref_hp: float = float(ref_elite.get("max_health"))
	if ref_hp <= 0.0 or absf(mini_hp - ref_hp * expected_hp_mult) > ref_hp * 0.03:
		_fail("Expected mini-elite HP ≈ wave elite ×%.2f (mini %f vs ref %f)." % [expected_hp_mult, mini_hp, ref_hp])
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

	# При pending level-up не должно быть двух входов одновременно:
	# нижняя кнопка с бейджем остается единственным входом, FAB сохраняется для докачки при pending=0.
	econ_main.set("pending_level_ups", 2)
	econ_main.call("_show_battle_map")
	await process_frame
	var fab := econ_main.find_child("UpgradeFabButton", true, false) as Button
	if fab != null:
		_fail("Expected route map to hide UpgradeFabButton while pending level-up return button is visible.")
		return
	var level_return := econ_main.find_child("LevelUpPlusButton", true, false) as Button
	var level_badge := econ_main.find_child("LevelUpPlusBadge", true, false) as Label
	if level_return == null or level_badge == null or level_badge.text != "2":
		_fail("Expected the bottom level-up return button with a pending-levels badge of 2.")
		return
	econ_main.set("pending_level_ups", 0)
	econ_main.call("_show_battle_map")
	await process_frame
	fab = econ_main.find_child("UpgradeFabButton", true, false) as Button
	if fab == null or fab.disabled:
		_fail("Expected the attribute upgrade FAB to remain available when no level-up is pending.")
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
	if nav_main.find_child("HeroSelectScreen", true, false) == null:
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

	# Hero select v4: thumbnail slot selects a hero, «Выбрать» opens weapon select.
	nav_main.call("_show_character_select")
	await process_frame
	var v4_carousel := nav_main.find_child("HS4Carousel", true, false) as Control
	if v4_carousel == null:
		_fail("Expected hero select v4 to expose a scrollable carousel.")
		return
	var carousel_slot: TextureButton = null
	for slot_child in v4_carousel.get_children():
		if slot_child is TextureButton and (slot_child as TextureButton).visible:
			carousel_slot = slot_child as TextureButton
			break
	if carousel_slot == null:
		_fail("Expected hero select v4 carousel to expose clickable hero slots.")
		return
	carousel_slot.pressed.emit()
	await process_frame
	if str(nav_main.get("selected_character_id")) == "":
		_fail("Expected clicking a hero carousel slot to select a hero.")
		return
	nav_main.set("selected_character_id", "berserk")
	var choose := nav_main.find_child("HS4ChooseButton", true, false) as Button
	if choose == null:
		_fail("Expected hero select to keep a choose button.")
		return
	choose.pressed.emit()
	await process_frame
	if nav_main.find_child("HeroSelectScreen", true, false) != null:
		_fail("Expected clicking choose to advance to weapon select.")
		return

	nav_main.queue_free()
	await process_frame


func _test_main_menu_quit_confirmation(main_scene: PackedScene) -> void:
	var quit_main := main_scene.instantiate()
	root.add_child(quit_main)
	quit_main.set_meta("suppress_game_quit", true)
	await process_frame
	await process_frame

	var exit_button := quit_main.find_child("MainMenuExitButton", true, false) as Button
	if exit_button == null:
		_fail("Expected main menu exit button for quit confirmation smoke.")
		return
	exit_button.pressed.emit()
	await process_frame
	await process_frame

	var dialog := quit_main.find_child("QuitConfirmationDialog", true, false) as Control
	var panel := quit_main.find_child("QuitConfirmationPanel", true, false) as Control
	var confirm_button := quit_main.find_child("QuitConfirmExitButton", true, false) as Button
	var cancel_button := quit_main.find_child("QuitConfirmCancelButton", true, false) as Button
	if dialog == null or panel == null or confirm_button == null or cancel_button == null:
		_fail("Expected game-styled quit confirmation dialog, panel and two buttons.")
		return
	if dialog.mouse_filter != Control.MOUSE_FILTER_STOP or panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Expected quit confirmation dialog to be modal and block clicks below it.")
		return
	if quit_main.get_viewport().gui_get_focus_owner() != cancel_button:
		_fail("Expected quit confirmation dialog to focus safe Cancel by default.")
		return
	if not _assert_quit_dialog_button_size(confirm_button, "exit") or not _assert_quit_dialog_button_size(cancel_button, "cancel"):
		return
	if bool(quit_main.get_meta("game_quit_requested", false)):
		_fail("Expected main menu quit request to remain false before explicit confirmation.")
		return

	_write_quit_confirmation_qa_dump(quit_main, panel)
	cancel_button.pressed.emit()
	await process_frame
	if quit_main.find_child("QuitConfirmationDialog", true, false) != null:
		_fail("Expected Cancel to close quit confirmation dialog.")
		return
	if quit_main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected Cancel to keep the player on the main menu.")
		return
	if bool(quit_main.get_meta("game_quit_requested", false)):
		_fail("Expected Cancel not to request game quit.")
		return

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	quit_main.call("_input", escape_event)
	await process_frame
	if quit_main.find_child("QuitConfirmationDialog", true, false) == null:
		_fail("Expected Escape on main menu to open quit confirmation dialog.")
		return
	quit_main.call("_input", escape_event)
	await process_frame
	if quit_main.find_child("QuitConfirmationDialog", true, false) != null:
		_fail("Expected Escape inside quit confirmation dialog to cancel it.")
		return

	exit_button = quit_main.find_child("MainMenuExitButton", true, false) as Button
	exit_button.pressed.emit()
	await process_frame
	confirm_button = quit_main.find_child("QuitConfirmExitButton", true, false) as Button
	cancel_button = quit_main.find_child("QuitConfirmCancelButton", true, false) as Button
	if confirm_button == null or cancel_button == null:
		_fail("Expected quit confirmation buttons before confirm flow.")
		return
	confirm_button.grab_focus()
	await process_frame
	confirm_button.pressed.emit()
	await process_frame
	if not bool(quit_main.get_meta("game_quit_requested", false)):
		_fail("Expected explicit Exit confirmation to request game quit.")
		return

	quit_main.queue_free()
	await process_frame


func _test_back_button_frame_safety(main_scene: PackedScene) -> void:
	var back_main := main_scene.instantiate()
	root.add_child(back_main)
	await process_frame
	var checked := []

	back_main.call("_show_character_select")
	await process_frame
	var hero_back_button := back_main.find_child("HS4BackButton", true, false) as Button
	if hero_back_button == null:
		hero_back_button = back_main.find_child("HeroSelectBackButton", true, false) as Button
	if hero_back_button == null:
		_fail("Expected hero select v4 to expose a back button.")
		return
	var hb_rect := hero_back_button.get_global_rect()
	var hb_vp := hero_back_button.get_viewport_rect().size
	if hb_rect.position.x < -1.0 or hb_rect.position.y < -1.0 or hb_rect.end.x > hb_vp.x + 1.0 or hb_rect.end.y > hb_vp.y + 1.0:
		_fail("Expected hero select v4 back button to stay on-screen, got %s." % str(hb_rect))
		return
	if hero_back_button.get_theme_stylebox("normal") == null:
		_fail("Expected hero select v4 back button to have a themed stylebox.")
		return
	hero_back_button.pressed.emit()
	await process_frame

	var skill_tree_button := back_main.find_child("MainMenuSkillTreeButton", true, false) as Button
	if skill_tree_button == null:
		_fail("Expected MainMenuSkillTreeButton for back-button frame QA.")
		return
	skill_tree_button.pressed.emit()
	await process_frame
	var skill_tree_back_button := back_main.find_child("SkillTreeBackButton", true, false) as Button
	if not _assert_back_button_frame_safe(skill_tree_back_button, "skill_tree", 260.0, checked):
		return
	skill_tree_back_button.pressed.emit()
	await process_frame

	var patch_button := back_main.find_child("MainMenuPatchNotesButton", true, false) as Button
	if patch_button == null:
		_fail("Expected MainMenuPatchNotesButton for back-button frame QA.")
		return
	patch_button.pressed.emit()
	await process_frame
	var patch_back_button := back_main.find_child("PatchNotesBackButton", true, false) as Button
	if not _assert_back_button_frame_safe(patch_back_button, "patch_notes", 260.0, checked):
		return
	patch_back_button.pressed.emit()
	await process_frame

	var codex_button := back_main.find_child("MainMenuCodexButton", true, false) as Button
	if codex_button == null:
		_fail("Expected MainMenuCodexButton for back-button frame QA.")
		return
	codex_button.pressed.emit()
	await process_frame
	var codex_back_button := back_main.find_child("CodexBackButton", true, false) as Button
	if not _assert_codex_v2_back_button_safe(codex_back_button, checked):
		return

	_write_back_button_qa_dump(back_main, checked)
	back_main.queue_free()
	await process_frame


func _assert_codex_v2_back_button_safe(button: Button, checked: Array) -> bool:
	if button == null:
		_fail("Expected codex v2 back button to exist.")
		return false
	var rect := button.get_global_rect()
	var expected := _codex_v2_expected_rect(Rect2(1684, 60, 126, 96), button.get_viewport_rect().size)
	if rect.position.distance_to(expected.position) > 2.0 or rect.size.distance_to(expected.size) > 2.0:
		_fail("Expected codex v2 compact back button to sit inside SCRUM-438 safe rect %s, got %s." % [str(expected), str(rect)])
		return false
	if button.text != "←":
		_fail("Expected codex v2 compact back button to use icon text, got `%s`." % button.text)
		return false
	var normal_style := button.get_theme_stylebox("normal")
	if normal_style == null:
		_fail("Expected codex v2 back button to have a themed normal stylebox.")
		return false
	var content_width := rect.size.x - normal_style.get_content_margin(SIDE_LEFT) - normal_style.get_content_margin(SIDE_RIGHT)
	var content_height := rect.size.y - normal_style.get_content_margin(SIDE_TOP) - normal_style.get_content_margin(SIDE_BOTTOM)
	if content_width < 20.0 or content_height < 34.0:
		_fail("Expected codex v2 back arrow to fit inside content zone, got %.1fx%.1f." % [content_width, content_height])
		return false
	checked.append({
		"context": "codex_v2",
		"name": button.name,
		"text": button.text,
		"rect": rect,
		"min_size": button.custom_minimum_size,
		"content_size": Vector2(content_width, content_height),
	})
	return true


func _assert_hero_select_v3_back_button_safe(button: Button, checked: Array) -> bool:
	if button == null:
		_fail("Expected hero select v3 back button to exist.")
		return false
	var rect := button.get_global_rect()
	var expected := _hero_select_v3_expected_rect(HERO_SELECT_V3_BACK_SAFE, button.get_viewport_rect().size)
	if rect.position.distance_to(expected.position) > 2.0 or rect.size.distance_to(expected.size) > 2.0:
		_fail("Expected hero select v3 back button to sit inside SCRUM-446/SCRUM-447 safe rect %s, got %s." % [str(expected), str(rect)])
		return false
	var normal_style := button.get_theme_stylebox("normal")
	if normal_style == null:
		_fail("Expected hero select v3 back button to have a themed normal stylebox.")
		return false
	var content_width := rect.size.x - normal_style.get_content_margin(SIDE_LEFT) - normal_style.get_content_margin(SIDE_RIGHT)
	var content_height := rect.size.y - normal_style.get_content_margin(SIDE_TOP) - normal_style.get_content_margin(SIDE_BOTTOM)
	if content_width < 34.0 or content_height < 18.0:
		_fail("Expected hero select v3 back text to fit inside content zone, got %.1fx%.1f." % [content_width, content_height])
		return false
	checked.append({
		"context": "hero_select_v3",
		"name": button.name,
		"text": button.text,
		"rect": rect,
		"min_size": button.custom_minimum_size,
		"content_size": Vector2(content_width, content_height),
	})
	return true


func _hero_select_v3_expected_rect(base_rect: Rect2, viewport_size: Vector2) -> Rect2:
	var scale := minf(viewport_size.x / HERO_SELECT_V3_SOURCE_SIZE.x, viewport_size.y / HERO_SELECT_V3_SOURCE_SIZE.y)
	var offset := (viewport_size - HERO_SELECT_V3_SOURCE_SIZE * scale) * 0.5
	return Rect2(offset + base_rect.position * scale, base_rect.size * scale)


func _hero_select_v4_expected_rect(zone: Rect2, viewport_size: Vector2) -> Rect2:
	var scale := minf(viewport_size.x / HERO_SELECT_V4_SOURCE_SIZE.x, viewport_size.y / HERO_SELECT_V4_SOURCE_SIZE.y)
	var canvas_size := HERO_SELECT_V4_SOURCE_SIZE * scale
	var offset := (viewport_size - canvas_size) * 0.5
	return Rect2(
		offset + Vector2(zone.position.x * canvas_size.x, zone.position.y * canvas_size.y),
		Vector2(zone.size.x * canvas_size.x, zone.size.y * canvas_size.y)
	)


func _visible_texture_button_count(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		var texture_button := child as TextureButton
		if texture_button != null and texture_button.visible and texture_button.get_global_rect().has_area():
			count += 1
	return count


func _codex_v2_expected_rect(base_rect: Rect2, viewport_size: Vector2) -> Rect2:
	var base_size := Vector2(1920.0, 1080.0)
	var scale := minf(viewport_size.x / base_size.x, viewport_size.y / base_size.y)
	var offset := (viewport_size - base_size * scale) * 0.5
	return Rect2(offset + base_rect.position * scale, base_rect.size * scale)


func _assert_back_button_frame_safe(button: Button, context: String, min_width: float, checked: Array) -> bool:
	if button == null:
		_fail("Expected %s back button to exist." % context)
		return false
	var rect := button.get_global_rect()
	var viewport_rect := button.get_viewport().get_visible_rect()
	if button.custom_minimum_size.x < min_width or rect.size.x < min_width - 1.0:
		_fail("Expected %s back button to use a non-cropped medium/large frame, got min=%s rect=%s." % [context, str(button.custom_minimum_size), str(rect)])
		return false
	if rect.size.y < 92.0:
		_fail("Expected %s back button height to keep minimal-metal ornament readable, got %s." % [context, str(rect)])
		return false
	if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > viewport_rect.size.x + 0.5 or rect.end.y > viewport_rect.size.y + 0.5:
		_fail("Expected %s back button to stay inside viewport, got rect=%s viewport=%s." % [context, str(rect), str(viewport_rect)])
		return false
	var normal_style := button.get_theme_stylebox("normal")
	if normal_style == null:
		_fail("Expected %s back button to have a themed normal stylebox." % context)
		return false
	var content_width := rect.size.x - normal_style.get_content_margin(SIDE_LEFT) - normal_style.get_content_margin(SIDE_RIGHT)
	var content_height := rect.size.y - normal_style.get_content_margin(SIDE_TOP) - normal_style.get_content_margin(SIDE_BOTTOM)
	var estimated_text_width := float(button.text.length()) * 8.5 + 8.0
	if content_width < estimated_text_width or content_height < 34.0:
		_fail("Expected %s back button text to fit inside content zone, got content %.1fx%.1f text_est=%.1f rect=%s." % [context, content_width, content_height, estimated_text_width, str(rect)])
		return false
	checked.append({
		"context": context,
		"name": button.name,
		"text": button.text,
		"rect": rect,
		"min_size": button.custom_minimum_size,
		"content_size": Vector2(content_width, content_height),
	})
	return true


func _write_back_button_qa_dump(main: Node, checked: Array) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum343")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump := PackedStringArray()
	dump.append("# SCRUM-343 Back Button QA")
	dump.append("")
	for entry in checked:
		var item: Dictionary = entry
		dump.append("- `%s` `%s`: rect `%s`, min `%s`, content `%s`" % [
			str(item.get("context", "")),
			str(item.get("name", "")),
			str(item.get("rect", "")),
			str(item.get("min_size", "")),
			str(item.get("content_size", "")),
		])
	var file := FileAccess.open("%s/back_button_frames.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump))
		file.close()
	if DisplayServer.get_name() != "headless":
		var image := main.get_viewport().get_texture().get_image()
		if image != null and image.get_width() > 0 and image.get_height() > 0:
			image.save_png("%s/back_button_frames.png" % qa_dir)


func _write_quit_confirmation_qa_dump(main: Node, panel: Control) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum319")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump := PackedStringArray()
	dump.append("# SCRUM-319 Quit Confirmation QA")
	dump.append("")
	dump.append("- dialog: `%s`" % str(main.find_child("QuitConfirmationDialog", true, false) != null))
	dump.append("- panel_rect: `%s`" % str(panel.get_global_rect()))
	dump.append("- focus_owner: `%s`" % str(main.get_viewport().gui_get_focus_owner().name if main.get_viewport().gui_get_focus_owner() != null else ""))
	for button_name in ["QuitConfirmExitButton", "QuitConfirmCancelButton"]:
		var button := main.find_child(button_name, true, false) as Button
		if button != null:
			var style := button.get_theme_stylebox("normal") as StyleBoxTexture
			dump.append("- %s: rect `%s`, min `%s`, texture `%s`" % [
				button_name,
				str(button.get_global_rect()),
				str(button.custom_minimum_size),
				str(style.texture.resource_path if style != null and style.texture != null else ""),
			])
	var file := FileAccess.open("%s/quit_confirmation_dialog.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump))
		file.close()
	if DisplayServer.get_name() != "headless":
		var image := main.get_viewport().get_texture().get_image()
		if image != null and image.get_width() > 0 and image.get_height() > 0:
			image.save_png("%s/quit_confirmation_dialog.png" % qa_dir)


func _assert_quit_dialog_button_size(button: Button, context: String) -> bool:
	if button == null:
		_fail("Expected quit confirmation %s button." % context)
		return false
	var rect := button.get_global_rect()
	if absf(button.custom_minimum_size.x - 220.0) > 0.5 or absf(button.custom_minimum_size.y - 72.0) > 0.5:
		_fail("Expected quit confirmation %s button minimum size to stay 220x72, got %s." % [context, str(button.custom_minimum_size)])
		return false
	if absf(rect.size.x - 220.0) > 1.0 or absf(rect.size.y - 72.0) > 1.0:
		_fail("Expected quit confirmation %s button rect to stay 220x72, got %s." % [context, str(rect)])
		return false
	if not _button_uses_minimal_metal_type(button, "pause"):
		_fail("Expected quit confirmation %s button to use the 72px-safe pause minimal-metal frame." % context)
		return false
	var normal_style := button.get_theme_stylebox("normal")
	if normal_style == null:
		_fail("Expected quit confirmation %s button to have content margins." % context)
		return false
	var content_height := rect.size.y - normal_style.get_content_margin(SIDE_TOP) - normal_style.get_content_margin(SIDE_BOTTOM)
	if content_height < 36.0:
		_fail("Expected quit confirmation %s button content height to remain readable, got %.1f." % [context, content_height])
		return false
	return true


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
	var codex_screen := codex_main.find_child("CodexScreen", true, false) as Control
	if codex_screen == null:
		_fail("Expected the Codex screen to open from the main menu.")
		return
	var codex_main_panel := codex_main.find_child("CodexMainPanel", true, false) as PanelContainer
	var codex_nav_panel := codex_main.find_child("CodexNavPanel", true, false) as PanelContainer
	var codex_tabs := codex_main.find_child("CodexTabs", true, false) as Control
	var codex_content := codex_main.find_child("CodexContent", true, false) as PanelContainer
	var codex_detail := codex_main.find_child("CodexDetailPanel", true, false) as PanelContainer
	var default_section := codex_main.find_child("CodexSection_characters", true, false) as Control
	var default_entry := codex_main.find_child("CodexEntryCard", true, false) as Control
	var default_portrait := codex_main.find_child("CodexPortraitSlot", true, false) as PanelContainer
	var detail_portrait := codex_main.find_child("CodexDetailPortraitSlot", true, false) as PanelContainer
	if codex_main_panel == null or codex_nav_panel == null or codex_content == null or codex_detail == null or codex_tabs == null or default_section == null or default_entry == null or default_portrait == null or detail_portrait == null:
		_fail("Expected SCRUM-438 Codex runtime layout to include main/nav/list/detail panels, tabs, entry card, and portrait slots.")
		return
	var expected_codex_textures := {
		"CodexMainPanel": MINIMAL_MODAL_TEXTURE,
		"CodexNavPanel": MINIMAL_PANEL_TEXTURE,
		"CodexContent": MINIMAL_PANEL_TEXTURE,
		"CodexDetailPanel": MINIMAL_PANEL_TEXTURE,
		"CodexPortraitSlot": MINIMAL_FIELD_TEXTURE,
		"CodexDetailPortraitSlot": MINIMAL_FIELD_TEXTURE,
	}
	for node_name in expected_codex_textures.keys():
		var panel := codex_main.find_child(str(node_name), true, false) as PanelContainer
		if panel == null:
			_fail("Expected Codex panel %s to exist." % node_name)
			return
		var actual_path := _stylebox_texture_path(panel.get_theme_stylebox("panel"))
		if actual_path != str(expected_codex_textures[node_name]):
			_fail("Expected %s to use `%s`, got `%s`." % [node_name, expected_codex_textures[node_name], actual_path])
			return
	if _stylebox_texture_path(default_entry.get_theme_stylebox("normal")) != MINIMAL_CARD_TEXTURE:
		_fail("Expected SCRUM-448 Codex list cards to use the minimal card frame.")
		return
	var codex_portrait_texture := _first_child_texture_rect(detail_portrait)
	var expected_default_portrait := _expected_character_portrait_path("berserk")
	if codex_portrait_texture == null or codex_portrait_texture.texture == null or codex_portrait_texture.texture.resource_path != expected_default_portrait:
		_fail("Expected default Codex character portrait to use new full-frame portrait %s." % expected_default_portrait)
		return
	if codex_portrait_texture.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		_fail("Expected Codex character detail portrait to preserve SCRUM-417 covered scaling.")
		return
	var character_tab := codex_main.find_child("CodexTab_characters", true, false) as Button
	if character_tab == null or not _button_uses_minimal_metal_type(character_tab, "codex_tab"):
		_fail("Expected Codex tabs to use the minimal-metal Codex tab texture kit.")
		return
	var expected_layout := {
		"CodexMainPanel": Rect2(24, 20, 1872, 1040),
		"CodexTabs": Rect2(88, 198, 258, 720),
		"CodexContent": Rect2(388, 170, 835, 872),
		"CodexDetailPanel": Rect2(1242, 170, 606, 872),
	}
	var codex_viewport_size := codex_screen.get_viewport_rect().size
	for node_name in expected_layout.keys():
		var control := codex_main.find_child(str(node_name), true, false) as Control
		var expected_rect := _codex_v2_expected_rect(expected_layout[node_name], codex_viewport_size)
		var actual_rect := control.get_global_rect()
		if actual_rect.position.distance_to(expected_rect.position) > 2.0 or actual_rect.size.distance_to(expected_rect.size) > 2.0:
			_fail("Expected SCRUM-438 %s rect near %s, got %s." % [node_name, str(expected_rect), str(actual_rect)])
			return
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum345")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-345 Codex Texture Runtime Dump")
	dump_lines.append("")
	for control in [codex_main_panel, codex_nav_panel, codex_tabs, codex_content, codex_detail, default_entry, default_portrait, detail_portrait]:
		var control_node := control as Control
		var texture_path := ""
		if control_node is PanelContainer:
			texture_path = _stylebox_texture_path((control_node as PanelContainer).get_theme_stylebox("panel"))
		elif control_node is Button:
			texture_path = _stylebox_texture_path((control_node as Button).get_theme_stylebox("normal"))
		dump_lines.append("- `%s`: `%s`, texture `%s`" % [control_node.name, str(control_node.get_global_rect()), texture_path])
	dump_lines.append("- `CodexDefaultCharacterPortrait`: `%s`" % codex_portrait_texture.texture.resource_path)
	var dump_file := FileAccess.open("%s/codex_texture_runtime_dump.md" % qa_dir, FileAccess.WRITE)
	if dump_file != null:
		dump_file.store_string("\n".join(dump_lines))
		dump_file.close()
	var scrum416_qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum416")
	DirAccess.make_dir_recursive_absolute(scrum416_qa_dir)
	var scrum416_codex_dump := PackedStringArray()
	scrum416_codex_dump.append("# SCRUM-416 Codex Character Portrait Runtime Paths")
	scrum416_codex_dump.append("")
	scrum416_codex_dump.append("- `CodexDefaultCharacterPortrait`: `%s`" % codex_portrait_texture.texture.resource_path)
	var scrum416_codex_file := FileAccess.open("%s/codex_character_portrait_runtime_paths.md" % scrum416_qa_dir, FileAccess.WRITE)
	if scrum416_codex_file != null:
		scrum416_codex_file.store_string("\n".join(scrum416_codex_dump))
		scrum416_codex_file.close()
	var scrum417_codex_qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum417")
	DirAccess.make_dir_recursive_absolute(scrum417_codex_qa_dir)
	var scrum417_codex_dump := PackedStringArray()
	scrum417_codex_dump.append("# SCRUM-417 Codex Character Portrait Runtime Dump")
	scrum417_codex_dump.append("")
	scrum417_codex_dump.append("- `CodexPortraitSlot`: `%s`" % str(default_portrait.get_global_rect()))
	scrum417_codex_dump.append("- `CodexDetailPortraitSlot`: `%s`" % str(detail_portrait.get_global_rect()))
	scrum417_codex_dump.append("- `CodexDetailPortraitTextureRect`: `%s`" % str(codex_portrait_texture.get_global_rect()))
	scrum417_codex_dump.append("- `CodexDetailPortraitMinimumSize`: `%s`" % str(codex_portrait_texture.custom_minimum_size))
	scrum417_codex_dump.append("- `CodexDetailPortraitStretch`: `%s`" % str(codex_portrait_texture.stretch_mode))
	scrum417_codex_dump.append("- `CodexDefaultCharacterPortrait`: `%s`" % codex_portrait_texture.texture.resource_path)
	var scrum417_codex_file := FileAccess.open("%s/codex_character_portrait_runtime_dump.md" % scrum417_codex_qa_dir, FileAccess.WRITE)
	if scrum417_codex_file != null:
		scrum417_codex_file.store_string("\n".join(scrum417_codex_dump))
		scrum417_codex_file.close()
	var scrum438_qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum438")
	DirAccess.make_dir_recursive_absolute(scrum438_qa_dir)
	var scrum438_dump := PackedStringArray()
	scrum438_dump.append("# SCRUM-438 Codex V2 Runtime Dump")
	scrum438_dump.append("")
	for control in [codex_main_panel, codex_nav_panel, codex_tabs, codex_content, codex_detail, default_entry, default_portrait, detail_portrait]:
		var c := control as Control
		scrum438_dump.append("- `%s`: `%s`" % [c.name, str(c.get_global_rect())])
	scrum438_dump.append("- `CodexDefaultCharacterPortrait`: `%s`" % codex_portrait_texture.texture.resource_path)
	var scrum438_file := FileAccess.open("%s/codex_v2_runtime_dump.md" % scrum438_qa_dir, FileAccess.WRITE)
	if scrum438_file != null:
		scrum438_file.store_string("\n".join(scrum438_dump))
		scrum438_file.close()

	# Полнота данных кодекса.
	var codex_data := load("res://scripts/codex_data.gd")
	var monsters: Array = codex_data.monsters()
	if monsters.size() != 26:
		_fail("Expected codex to list all 26 monsters (11 standard + 4 elites + 6 mini-elites + 5 bosses), got %d." % monsters.size())
		return
	var codex_mini_count := 0
	for monster_entry in monsters:
		if str((monster_entry as Dictionary).get("kind", "")) == "mini_elite":
			codex_mini_count += 1
	if codex_mini_count != 6:
		_fail("Expected 6 mini-elite codex entries, got %d." % codex_mini_count)
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
	if codex_data.characters().size() != ProgressionData.character_ids().size() or codex_data.stats().size() < 20:
		_fail("Expected codex to cover all playable characters and the stat definitions.")
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


func _test_skill_tree_progression_kit(main_scene: PackedScene) -> void:
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-331 Progression Skill Tree Runtime Dump")
	dump_lines.append("")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await _assert_skill_tree_progression_kit_at_size(main_scene, viewport_size, dump_lines)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum331")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump_file := FileAccess.open("%s/progression_skill_tree_runtime_dump.md" % qa_dir, FileAccess.WRITE)
	if dump_file != null:
		dump_file.store_string("\n".join(dump_lines))
		dump_file.close()


func _assert_skill_tree_progression_kit_at_size(main_scene: PackedScene, viewport_size: Vector2i, dump_lines: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var skill_main := main_scene.instantiate()
	viewport.add_child(skill_main)
	await process_frame
	skill_main.ui._show_skill_tree_screen()
	await process_frame
	await process_frame

	var context := "skill_tree %s" % str(viewport_size)
	var screen := skill_main.find_child("SkillTreeScreen", true, false) as Control
	var main_panel := skill_main.find_child("SkillTreeMainPanel", true, false) as PanelContainer
	var points_badge := skill_main.find_child("SkillTreePointsBadge", true, false) as PanelContainer
	var class_panel := skill_main.find_child("SkillTreeClassPanel", true, false) as PanelContainer
	var branches := skill_main.find_child("SkillTreeBranches", true, false) as Control
	var branch_panel := skill_main.find_child("SkillTreeBranchPanel_*", true, false) as PanelContainer
	var node_button := skill_main.find_child("SkillNode_*", true, false) as Button
	var node_title := skill_main.find_child("SkillNodeTitle_*", true, false) as Label
	var node_desc := skill_main.find_child("SkillNodeDesc_*", true, false) as Label
	if screen == null or main_panel == null or points_badge == null or class_panel == null or branches == null or branch_panel == null or node_button == null or node_title == null or node_desc == null:
		_fail("Expected SCRUM-331 skill tree controls to exist at %s." % context)
		return

	var expected_panel_textures := {
		"SkillTreeMainPanel": "res://assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png",
		"SkillTreePointsBadge": "res://assets/sprites/ui/frames/progression/ui_frame_progression_points_badge.png",
		"SkillTreeClassPanel": "res://assets/sprites/ui/frames/progression/ui_frame_progression_class_panel.png",
		"SkillTreeBranchPanel": "res://assets/sprites/ui/frames/progression/ui_frame_progression_branch_panel.png",
	}
	var actual_panel_textures := {
		"SkillTreeMainPanel": _stylebox_texture_path(main_panel.get_theme_stylebox("panel")),
		"SkillTreePointsBadge": _stylebox_texture_path(points_badge.get_theme_stylebox("panel")),
		"SkillTreeClassPanel": _stylebox_texture_path(class_panel.get_theme_stylebox("panel")),
		"SkillTreeBranchPanel": _stylebox_texture_path(branch_panel.get_theme_stylebox("panel")),
	}
	for node_name in expected_panel_textures.keys():
		if str(actual_panel_textures[node_name]) != str(expected_panel_textures[node_name]):
			_fail("Expected %s to use `%s`, got `%s` at %s." % [node_name, expected_panel_textures[node_name], actual_panel_textures[node_name], context])
			return

	var node_texture_path := _stylebox_texture_path(node_button.get_theme_stylebox("normal"))
	if not node_texture_path.begins_with("res://assets/sprites/ui/frames/progression/ui_frame_progression_node_"):
		_fail("Expected skill node to use SCRUM-331 circular node frame, got `%s` at %s." % [node_texture_path, context])
		return
	if node_button.text.length() > 3 or node_button.text.contains("\n"):
		_fail("Expected circular skill node to contain only short cost text, got `%s` at %s." % [node_button.text, context])
		return
	if node_title.get_global_rect().intersects(node_button.get_global_rect()) or node_desc.get_global_rect().intersects(node_button.get_global_rect()):
		_fail("Expected skill node title/description labels to stay outside the circular node frame at %s." % context)
		return
	if class_panel.get_global_rect().intersects(branches.get_global_rect()):
		_fail("Expected class panel and branch grid not to overlap at %s." % context)
		return

	dump_lines.append("## %s" % context)
	for control in [main_panel, points_badge, class_panel, branches, branch_panel, node_button, node_title, node_desc]:
		var ctrl := control as Control
		dump_lines.append("- `%s`: `%s` texture `%s`" % [ctrl.name, str(ctrl.get_global_rect()), _progression_dump_texture(ctrl)])
	viewport.queue_free()
	await process_frame


func _progression_dump_texture(control: Control) -> String:
	if control is PanelContainer:
		return _stylebox_texture_path((control as PanelContainer).get_theme_stylebox("panel"))
	if control is Button:
		return _stylebox_texture_path((control as Button).get_theme_stylebox("normal"))
	return ""


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
		if str(elite.get_meta("unique_pattern_id", "")) != behavior_id:
			_fail("Expected elite %s to expose its unique encounter pattern meta." % behavior_id)
			return
		var mechanics: Array = elite.get_meta("unique_mechanics", []) as Array
		if mechanics.size() < 3:
			_fail("Expected elite %s to expose at least 3 unique mechanics." % behavior_id)
			return
		var config: Dictionary = ProgressionData.elite_attack_config(behavior_id)
		if config.is_empty() or str(config.get("attack_id", "")) != str(elite.get("elite_attack_id")):
			_fail("Expected elite %s attack config to come from ProgressionData." % behavior_id)
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


func _assert_elite_reward_panel_centered(main_scene: PackedScene, viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	await process_frame

	var modal_main := main_scene.instantiate()
	viewport.add_child(modal_main)
	await process_frame
	modal_main.set("route_stage", 6)
	modal_main.ui._show_elite_artifact_reward(Callable())
	await process_frame
	await process_frame

	var panel := modal_main.find_child("EliteArtifactRewardPanel", true, false) as Control
	if panel == null:
		_fail("Expected elite reward panel at viewport %s." % viewport_size)
		return
	if not _control_center_matches_viewport_size(panel, Vector2(viewport_size), 2.0):
		var rect := panel.get_global_rect()
		_fail("Expected elite reward panel global center %s to match viewport center %s at viewport %s." % [rect.get_center(), Vector2(viewport_size) * 0.5, viewport_size])
		return
	var rect := panel.get_global_rect()
	var visible_size := Vector2(viewport_size)
	if rect.position.x < -2.0 or rect.position.y < -2.0 or rect.end.x > visible_size.x + 2.0 or rect.end.y > visible_size.y + 2.0:
		_fail("Expected elite reward panel rect %s to stay inside viewport %s." % [rect, visible_size])
		return

	viewport.queue_free()
	await process_frame


func _assert_reward_cards_use_scrum338_frames(buttons: Array, content_name: String, texture_path: String, safe_margins: Vector4, context: String) -> bool:
	var dump_lines := PackedStringArray()
	dump_lines.append("# SCRUM-338 Reward Frame Runtime Dump")
	dump_lines.append("")
	dump_lines.append("- Context: `%s`" % context)
	dump_lines.append("- Expected texture: `%s`" % texture_path)
	for button_node in buttons:
		var button := button_node as Button
		if button == null:
			_fail("Expected %s reward card button." % context)
			return false
		var style_path := _stylebox_texture_path(button.get_theme_stylebox("normal"))
		if style_path != texture_path:
			_fail("Expected %s to use reward texture %s, got %s." % [button.name, texture_path, style_path])
			return false
			var hover_style_path := _stylebox_texture_path(button.get_theme_stylebox("hover"))
			if hover_style_path != texture_path and not hover_style_path.ends_with("_hover.png"):
				_fail("Expected %s to use a hover reward texture or SCRUM-448 shared minimal card, got %s." % [button.name, hover_style_path])
				return false
		var content := button.find_child(content_name, false, false) as Control
		if content == null:
			_fail("Expected %s to expose %s inside the reward safe-zone." % [button.name, content_name])
			return false
		var card_rect := button.get_global_rect()
		var content_rect := content.get_global_rect()
		var safe_rect := _scaled_safe_rect(card_rect, REWARD_FRAME_SOURCE_SIZE, safe_margins)
		dump_lines.append("- `%s`: card `%s`, safe `%s`, content `%s`, texture `%s`" % [
			button.name,
			str(card_rect),
			str(safe_rect),
			str(content_rect),
			style_path,
		])
		if not _rect_contains_with_tolerance(safe_rect, content_rect, 2.0):
			_fail("Expected %s content rect %s to stay inside reward safe rect %s." % [button.name, content_rect, safe_rect])
			return false
		if context == "battle_reward" and button.find_child("BattleRewardActionLabel", true, false) == null:
			_fail("Expected %s to show the player-facing Получить action label." % button.name)
			return false
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum338")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/%s_reward_frames.md" % [qa_dir, context], FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	return true


func _control_center_matches_viewport(control: Control, tolerance_px := 2.0) -> bool:
	return _control_center_matches_viewport_size(control, root.get_visible_rect().size, tolerance_px)


func _control_center_matches_viewport_size(control: Control, viewport_size: Vector2, tolerance_px := 2.0) -> bool:
	var rect := control.get_global_rect()
	var viewport_center := viewport_size * 0.5
	return absf(rect.get_center().x - viewport_center.x) <= tolerance_px and absf(rect.get_center().y - viewport_center.y) <= tolerance_px


func _test_weapon_select_clean_layout(main_scene: PackedScene) -> void:
	var weapon_main := main_scene.instantiate()
	root.add_child(weapon_main)
	await process_frame
	weapon_main.set("selected_character_id", "berserk")
	weapon_main.call("_show_weapon_select")
	await process_frame
	await process_frame

	var dump_lines := PackedStringArray()
	dump_lines.append("# Weapon Select Clean Layout Dump")
	dump_lines.append("")
	var weapon_ids: Array = ProgressionData.weapon_ids("berserk")
	for weapon_id_value in weapon_ids:
		var weapon_id := str(weapon_id_value)
		var button := weapon_main.find_child("WeaponOption_%s" % weapon_id, true, false) as Button
		if button == null:
			_fail("Expected weapon select card for %s." % weapon_id)
			return
		var rect := button.get_global_rect()
		dump_lines.append("- `%s`: `%s`" % [button.name, str(rect)])
		if rect.size.y < 110.0:
			_fail("Expected weapon select card %s to keep readable row height, got %s." % [weapon_id, rect])
			return
		if button.get_theme_stylebox("normal") is StyleBoxTexture or button.get_theme_stylebox("hover") is StyleBoxTexture:
			_fail("Expected weapon select card %s to use lightweight flat styling, not heavy button textures." % weapon_id)
			return
		var sprite := button.find_child("WeaponSelectSprite_%s" % weapon_id, true, false) as TextureRect
		var expected_sprite := _expected_weapon_sprite_path(weapon_id)
		if sprite == null or sprite.texture == null or sprite.texture.resource_path != expected_sprite:
			_fail("Expected weapon select card %s to show sprite %s." % [weapon_id, expected_sprite])
			return
		var stats := button.find_child("WeaponSelectStats_%s" % weapon_id, true, false) as Label
		if stats == null or not stats.text.contains("Дальность") or not stats.text.contains("Перезарядка"):
			_fail("Expected weapon select card %s to show Russian stat labels." % weapon_id)
			return
	var first_button := weapon_main.find_child("WeaponOption_%s" % str(weapon_ids[0]), true, false) as Button
	first_button.pressed.emit()
	await process_frame
	if str(weapon_main.get("selected_weapon_id")) != str(weapon_ids[0]):
		_fail("Expected weapon select card click to select %s." % str(weapon_ids[0]))
		return
	var qa_dir := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/weapon_select_clean_layout.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	weapon_main.queue_free()
	await process_frame


func _expected_weapon_sprite_path(weapon_id: String) -> String:
	var aliases := {
		"sword": "two_handed_sword",
		"axe": "two_handed_axe",
		"hammer": "two_handed_hammer",
	}
	return "res://assets/sprites/weapons/%s.png" % str(aliases.get(weapon_id, weapon_id))


func _expected_character_portrait_path(character_id: String) -> String:
	return "res://assets/sprites/characters/full_frame/%s/%s_idle_00.png" % [character_id, character_id]


func _first_child_texture_rect(parent: Node) -> TextureRect:
	if parent == null:
		return null
	for child in parent.get_children():
		var texture_rect := child as TextureRect
		if texture_rect != null:
			return texture_rect
		var nested := _first_child_texture_rect(child)
		if nested != null:
			return nested
	return null


func _test_parchment_button_seal_sizes(main_scene: PackedScene) -> void:
	var seal_main := main_scene.instantiate()
	root.add_child(seal_main)
	await process_frame

	var dump_lines := PackedStringArray()
	dump_lines.append("# Minimal Metal Button Size Dump")
	dump_lines.append("")
	_assert_visible_seal_buttons(seal_main, "main menu", dump_lines)
	seal_main.call("_show_character_select")
	await process_frame
	await process_frame
	_assert_visible_seal_buttons(seal_main, "hero select", dump_lines)
	seal_main.set("selected_character_id", "berserk")
	seal_main.call("_show_weapon_select")
	await process_frame
	await process_frame
	_assert_visible_seal_buttons(seal_main, "weapon select", dump_lines)
	seal_main.call("_show_settings_menu")
	await process_frame
	await process_frame
	_assert_visible_seal_buttons(seal_main, "settings", dump_lines)

	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum450_minimal_metal_buttons")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/minimal_metal_button_sizes.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	seal_main.queue_free()
	await process_frame


func _assert_visible_seal_buttons(node: Node, context: String, dump_lines: PackedStringArray) -> void:
	var ui_root = node.get("ui_layer")
	if not (ui_root is Node):
		return
	dump_lines.append("## %s" % context)
	var buttons: Array = (ui_root as Node).find_children("*", "Button", true, false)
	for button_node in buttons:
		var button := button_node as Button
		if button == null or not button.visible:
			continue
		var texture_path := _button_normal_texture_path(button)
		if not texture_path.contains("/minimal_metal_buttons/ui_btn_minimal_metal_"):
			continue
		var rect := button.get_global_rect()
		dump_lines.append("- `%s`: rect=`%s`, min=`%s`, texture=`%s`" % [button.name, str(rect), str(button.custom_minimum_size), texture_path])
		if context == "hero select" and (button.name == "AscensionMinusButton" or button.name == "AscensionPlusButton"):
			if button.custom_minimum_size.x < 42.0 or button.custom_minimum_size.y < 42.0:
				_fail("Expected hero select v4 ascension button %s to remain usable, got min=%s." % [button.name, button.custom_minimum_size])
				return
			continue
		if texture_path.contains("ui_btn_minimal_metal_utility"):
			if absf(button.custom_minimum_size.x - 54.0) > 0.5 or absf(button.custom_minimum_size.y - 42.0) > 0.5:
				_fail("Expected compact utility button %s on %s to use 54x42 minimal-metal asset, got min=%s." % [button.name, context, button.custom_minimum_size])
				return
			continue
		if texture_path.contains("ui_btn_minimal_metal_fab"):
			if absf(button.custom_minimum_size.x - 50.0) > 0.5 or absf(button.custom_minimum_size.y - 50.0) > 0.5:
				_fail("Expected FAB button %s on %s to use 50x50 minimal-metal asset, got min=%s." % [button.name, context, button.custom_minimum_size])
				return
			continue
		if texture_path.contains("ui_btn_minimal_metal_pause"):
			if absf(button.custom_minimum_size.x - 280.0) > 0.5 or absf(button.custom_minimum_size.y - 60.0) > 0.5:
				_fail("Expected pause button %s on %s to use 280x60 minimal-metal asset, got min=%s." % [button.name, context, button.custom_minimum_size])
				return
			continue
		if context == "settings" and button.name == "SettingsBackButton":
			if absf(button.custom_minimum_size.x - 280.0) > 0.5 or absf(button.custom_minimum_size.y - 64.0) > 0.5:
				_fail("Expected SCRUM-439 SettingsBackButton to use 280x64 inside the v2 modal safe zone, got min=%s." % button.custom_minimum_size)
				return
			continue
		if texture_path.contains("ui_btn_minimal_metal_rebind"):
			if button.custom_minimum_size.y < 62.0:
				_fail("Expected rebind/dropdown button %s on %s to use at least 62px height, got min=%s." % [button.name, context, button.custom_minimum_size])
				return
			continue
		if texture_path.contains("ui_btn_minimal_metal_hero_confirm") and (button.name == "HeroSelectChooseButton" or button.name == "HS4ChooseButton"):
			if button.custom_minimum_size.y < 24.0:
				_fail("Expected SCRUM-356 compact hero select confirm button %s on %s to stay usable inside the unified bottom safe-zone, got min=%s." % [button.name, context, button.custom_minimum_size])
				return
			continue
		if context == "hero select" and button.name == "HS4BackButton":
			if button.custom_minimum_size.x < 120.0 or button.custom_minimum_size.y < 42.0:
				_fail("Expected hero select v4 back button %s to remain usable, got min=%s." % [button.name, button.custom_minimum_size])
				return
			continue
		if context == "hero select" and button.get_parent() != null and button.get_parent().name == "HS4Carousel":
			if button.custom_minimum_size.x < 42.0 or button.custom_minimum_size.y < 42.0:
				_fail("Expected hero select v4 carousel nav button %s to remain usable, got min=%s." % [button.name, button.custom_minimum_size])
				return
			continue
		if rect.size.y < 64.0 or button.custom_minimum_size.y < 64.0:
			_fail("Expected minimal-metal button %s on %s to stay tall enough, rect=%s min=%s." % [button.name, context, rect, button.custom_minimum_size])
			return
		if absf(button.custom_minimum_size.y - STANDARD_ACTION_BUTTON_HEIGHT) > 0.5:
			_fail("Expected action button %s on %s to use standard height %.0f, got min=%s." % [button.name, context, STANDARD_ACTION_BUTTON_HEIGHT, button.custom_minimum_size])
			return


func _button_normal_texture_path(button: Button) -> String:
	var style := button.get_theme_stylebox("normal")
	return _stylebox_texture_path(style)


func _stylebox_texture_path(style: StyleBox) -> String:
	if not (style is StyleBoxTexture):
		return ""
	var texture := (style as StyleBoxTexture).texture
	if texture == null:
		return ""
	return texture.resource_path


func _write_scrum437_attribute_offer_dump(panel: Control, offers: Container) -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum437")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var dump := PackedStringArray()
	dump.append("# SCRUM-437 Wide Economy Choice Card Runtime Dump")
	dump.append("")
	dump.append("- `AttributeShopPanel`: `%s`" % str(panel.get_global_rect() if panel != null else Rect2()))
	if offers != null:
		dump.append("- `AttributeOffers`: `%s`, children `%d`" % [str(offers.get_global_rect()), offers.get_child_count()])
		for node in offers.get_children():
			var card := node as Button
			if card == null:
				continue
			dump.append("- `%s`: rect `%s`, min `%s`, normal `%s`, hover `%s`, source `%s`, safe `%s`, content `%s`" % [
				card.name,
				str(card.get_global_rect()),
				str(card.custom_minimum_size),
				_stylebox_texture_path(card.get_theme_stylebox("normal")),
				_stylebox_texture_path(card.get_theme_stylebox("hover")),
				str(card.get_meta("economy_source_size", Vector2.ZERO)),
				str(card.get_meta("economy_source_safe_rect", Rect2())),
				str(card.get_meta("economy_content_margins", Vector4.ZERO)),
			])
	var file := FileAccess.open("%s/wide_economy_choice_card_runtime_dump.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump))
		file.close()


func _test_hero_select_radar_no_overlap_layouts(main_scene: PackedScene) -> void:
	var dump_lines := PackedStringArray()
	dump_lines.append("# Hero Select Radar Rect Dump")
	dump_lines.append("")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(2560, 1440)]:
		await _assert_hero_select_radar_layout_at_size(main_scene, viewport_size, dump_lines)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/hero_select_radar_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	var scrum470_dir := "%s/scrum470_hero_select_v4" % qa_dir
	DirAccess.make_dir_recursive_absolute(scrum470_dir)
	var scrum470_file := FileAccess.open("%s/hero_select_v4_runtime_rects.md" % scrum470_dir, FileAccess.WRITE)
	if scrum470_file != null:
		scrum470_file.store_string("\n".join(dump_lines))
		scrum470_file.close()


func _assert_hero_select_radar_layout_at_size(main_scene: PackedScene, viewport_size: Vector2i, dump_lines: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var hero_main := main_scene.instantiate()
	viewport.add_child(hero_main)
	await process_frame
	hero_main.call("_show_character_select")
	await process_frame
	await process_frame

	var context := "hero select %s" % str(viewport_size)
	var hero_screen := hero_main.find_child("HeroSelectScreen", true, false) as Control
	var radar := hero_main.find_child("HS4Radar", true, false) as Control
	var radar_title := hero_main.find_child("HeroStatRadarTitle", true, false) as Control
	var large_portrait := hero_main.find_child("HS4Portrait", true, false) as TextureRect
	var asc_label := hero_main.find_child("AscensionLevelLabel", true, false) as Control
	var asc_mods := hero_main.find_child("AscensionModsLabel", true, false) as Control
	var choose_button := hero_main.find_child("HS4ChooseButton", true, false) as Control
	var thumbnail_strip := hero_main.find_child("HS4Carousel", true, false) as Control
	var back_button := hero_main.find_child("HS4BackButton", true, false) as Control
	if back_button == null:
		back_button = hero_main.find_child("HeroSelectBackButton", true, false) as Control
	if hero_screen == null or radar == null or large_portrait == null or asc_label == null or asc_mods == null or choose_button == null or thumbnail_strip == null or back_button == null:
		_fail("Expected native hero select v4 portrait/radar/ascension/carousel/back nodes at %s." % context)
		return
	if radar_title != null:
		_fail("Expected hero stat radar title to be removed at %s." % context)
		return
	if not _has_screen_background(hero_main, "hero_select"):
		_fail("Expected native hero select v4 to use the hero_select backdrop at %s." % context)
		return
	var screen_rect := hero_screen.get_global_rect()
	var radar_rect := radar.get_global_rect()
	var portrait_image_rect := large_portrait.get_global_rect()
	var thumbnail_rect := thumbnail_strip.get_global_rect()
	dump_lines.append("## %s" % context)
	dump_lines.append("- `HeroSelectScreen`: `%s`" % str(screen_rect))
	dump_lines.append("- `%s`: `%s`" % [back_button.name, str(back_button.get_global_rect())])
	dump_lines.append("- `HS4Portrait`: `%s`" % str(portrait_image_rect))
	dump_lines.append("- `AscensionLevelLabel`: `%s`" % str(asc_label.get_global_rect()))
	dump_lines.append("- `AscensionModsLabel`: `%s`" % str(asc_mods.get_global_rect()))
	dump_lines.append("- `HS4ChooseButton`: `%s`" % str(choose_button.get_global_rect()))
	dump_lines.append("- `HS4Radar`: `%s`" % str(radar_rect))
	dump_lines.append("- `HS4Carousel`: `%s`" % str(thumbnail_rect))
	var thumbnail_buttons := []
	for child in thumbnail_strip.get_children():
		var thumb := child as TextureButton
		if thumb != null and thumb.visible:
			thumbnail_buttons.append(thumb)
	if thumbnail_buttons.size() != HERO_SELECT_V4_VISIBLE_SLOTS:
		_fail("Expected %d visible hero thumbnail buttons at %s, got %d." % [HERO_SELECT_V4_VISIBLE_SLOTS, context, thumbnail_buttons.size()])
		return
	var first_thumb := thumbnail_buttons[0] as Control
	var first_thumb_rect := first_thumb.get_global_rect()
	dump_lines.append("- `HeroThumbnailSample`: min=`%s`, rect=`%s`" % [str(first_thumb.custom_minimum_size), str(first_thumb_rect)])
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0)
	for control in [back_button, large_portrait, radar, thumbnail_strip, choose_button, asc_label, asc_mods]:
		var rect := (control as Control).get_global_rect()
		if not viewport_rect.encloses(rect):
			_fail("Expected native hero select v4 control %s to stay on-screen at %s, got %s." % [(control as Control).name, context, rect])
			return
	var major_controls: Array = [large_portrait, radar, thumbnail_strip, choose_button]
	for i in range(major_controls.size()):
		for j in range(i + 1, major_controls.size()):
			var a := (major_controls[i] as Control)
			var b := (major_controls[j] as Control)
			if a.get_global_rect().grow(-2.0).intersects(b.get_global_rect().grow(-2.0)):
				_fail("Expected native hero select v4 controls not to overlap at %s: %s %s intersects %s %s." % [context, a.name, a.get_global_rect(), b.name, b.get_global_rect()])
				return
	var min_expected_thumb_width := 42.0
	if viewport_size.x >= 1600:
		min_expected_thumb_width = 60.0
	if viewport_size.x >= 2560:
		min_expected_thumb_width = 86.0
	var thumb_square_tolerance := maxf(8.0, maxf(first_thumb_rect.size.x, first_thumb_rect.size.y) * 0.10)
	if first_thumb_rect.size.x < min_expected_thumb_width or first_thumb_rect.size.y < min_expected_thumb_width or absf(first_thumb_rect.size.x - first_thumb_rect.size.y) > thumb_square_tolerance:
		_fail("Expected large roughly square hero thumbnails at %s, got rect %s min %s tolerance %.2f." % [context, first_thumb_rect, first_thumb.custom_minimum_size, thumb_square_tolerance])
		return
	for thumb in thumbnail_buttons:
		var thumb_rect := (thumb as Control).get_global_rect()
		if not _rect_contains_with_tolerance(thumbnail_rect, thumb_rect, 1.5):
			_fail("Expected hero thumbnail %s to stay inside carousel content-zone at %s, got thumb %s content %s." % [(thumb as Control).name, context, thumb_rect, thumbnail_rect])
			return
	if HeroStatRadarScript.HERO_RADAR_RADIUS_FACTOR < 0.36:
		_fail("Expected hero radar polygon radius factor to stay enlarged at %s." % context)
		return

	viewport.queue_free()
	await process_frame


func _test_hud_no_overlap_layouts(main_scene: PackedScene) -> void:
	var dump_lines := PackedStringArray()
	dump_lines.append("# HUD No-Overlap Rect Dump")
	dump_lines.append("")
	for viewport_size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(2560, 1440)]:
		await _assert_hud_no_overlap_at_size(main_scene, viewport_size, false, dump_lines)
		await _assert_hud_no_overlap_at_size(main_scene, viewport_size, true, dump_lines)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/hud_no_overlap_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	var scrum390_dir := ProjectSettings.globalize_path("res://build/qa/scrum390")
	DirAccess.make_dir_recursive_absolute(scrum390_dir)
	var scrum390_file := FileAccess.open("%s/combat_hud_runtime_rects.md" % scrum390_dir, FileAccess.WRITE)
	if scrum390_file != null:
		scrum390_file.store_string("\n".join(dump_lines))
		scrum390_file.close()


func _test_shop_wall_no_overlap_layouts(main_scene: PackedScene) -> void:
	var dump_lines := PackedStringArray()
	dump_lines.append("# Shop Wall No-Overlap Rect Dump")
	dump_lines.append("")
	for viewport_size in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		await _assert_shop_wall_layout_at_size(main_scene, viewport_size, dump_lines)
	var qa_dir := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/shop_wall_frameless_rects.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()


func _assert_shop_wall_layout_at_size(main_scene: PackedScene, viewport_size: Vector2i, dump_lines: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var shop_main := main_scene.instantiate()
	viewport.add_child(shop_main)
	await process_frame
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var shop_player := player_scene.instantiate()
	viewport.add_child(shop_player)
	shop_player.configure_character("berserk", "sword")
	shop_player.set("money", 300)
	shop_main.call("_store_player_snapshot", shop_player)
	shop_player.queue_free()
	shop_main.set("route_stage", 2)
	shop_main.call("_show_shop_screen")
	await process_frame
	await process_frame

	var context := "shop %s" % str(viewport_size)
	dump_lines.append("## %s" % context)
	var wall := shop_main.find_child("ShopParchmentWall", true, false) as Control
	var inline_items := shop_main.find_child("ShopInlineItems", true, false) as Control
	if wall == null or inline_items == null:
		_fail("Expected shop wall and item layer at %s." % context)
		return
	if inline_items is GridContainer:
		_fail("Expected frameless shop items to avoid GridContainer/card layout at %s." % context)
		return
	if wall.anchor_left > 0.25 or wall.anchor_right < 0.75:
		_fail("Expected shop wall to cover the centered backdrop display area at %s." % context)
		return

	var buttons := shop_main.find_children("ShopItemButton*", "Button", true, false)
	if buttons.size() != 4:
		_fail("Expected four wall shop buttons at %s." % context)
		return
	var button_controls := []
	var visual_controls := []
	var item_bounds := Rect2()
	var has_item_bounds := false
	for node in buttons:
		var button := node as Button
		if button == null:
			continue
		button_controls.append(button)
		var button_rect := button.get_global_rect()
		item_bounds = button_rect if not has_item_bounds else item_bounds.merge(button_rect)
		has_item_bounds = true
		dump_lines.append("- `%s`: `%s`" % [button.name, str(button_rect)])
		if button.get_theme_stylebox("normal") is StyleBoxTexture or button.get_theme_stylebox("hover") is StyleBoxTexture:
			_fail("Expected %s to be frameless, got StyleBoxTexture." % button.name)
			return
		var icon := button.find_child("ShopItemIcon", true, false) as TextureRect
		var price := button.find_child("ShopPriceBadge", true, false) as PanelContainer
		var shadow := button.find_child("ShopItemContactShadow", true, false) as PanelContainer
		if icon == null or icon.texture == null or price == null or shadow == null:
			_fail("Expected %s to include icon, contact shadow, and compact price tag." % button.name)
			return
			if _stylebox_texture_path(price.get_theme_stylebox("panel")) != MINIMAL_FIELD_TEXTURE:
				_fail("Expected %s price tag to use the SCRUM-448 minimal field frame." % button.name)
				return
		visual_controls.append(icon)
		visual_controls.append(price)
		var money_icon := button.find_child("ShopPriceMoneyIcon", true, false) as TextureRect
		var price_label := button.find_child("ShopItemPrice", true, false) as Label
		if money_icon == null or money_icon.texture == null or price_label == null or not price_label.text.is_valid_int():
			_fail("Expected %s price to show money icon plus numeric cost." % button.name)
			return
	var item_overlap := _first_control_overlap(button_controls, 6.0)
	if not item_overlap.is_empty():
		_fail("Expected shop wall hit areas not to overlap at %s, got %s." % [context, item_overlap])
		return
	var viewport_center_x := float(viewport_size.x) * 0.5
	var item_center_delta := absf(item_bounds.get_center().x - viewport_center_x)
	var allowed_center_delta := maxf(28.0, float(viewport_size.x) * 0.025)
	dump_lines.append("- Item bounds: `%s`, center_delta_x=%.1f" % [str(item_bounds), item_center_delta])
	if item_center_delta > allowed_center_delta:
		_fail("Expected shop item group to be centered at %s, delta %.1f > %.1f." % [context, item_center_delta, allowed_center_delta])
		return
	var cross_slot_overlap := _first_cross_parent_overlap(visual_controls, 4.0)
	if not cross_slot_overlap.is_empty():
		_fail("Expected shop item visuals not to overlap at %s, got %s." % [context, cross_slot_overlap])
		return

	var layout_controls := button_controls + _visible_hud_top_controls(shop_main)
	for name in ["ShopHeader", "ShopLeaveButton", "UpgradeFabButton"]:
		var control := shop_main.find_child(name, true, false) as Control
		if control != null and control.visible:
			layout_controls.append(control)
	var hud_overlap := _first_control_overlap(layout_controls, 2.0)
	if not hud_overlap.is_empty():
		_fail("Expected centered shop controls not to overlap header/back/HUD at %s, got %s." % [context, hud_overlap])
		return

	if viewport_size == Vector2i(1280, 720):
		var qa_dir := ProjectSettings.globalize_path("res://build/qa")
		DirAccess.make_dir_recursive_absolute(qa_dir)
		if DisplayServer.get_name() != "headless":
			var image := viewport.get_texture().get_image()
			image.save_png("%s/shop_wall_frameless_1280x720.png" % qa_dir)

	viewport.queue_free()
	await process_frame


func _assert_hud_no_overlap_at_size(main_scene: PackedScene, viewport_size: Vector2i, boss_fight: bool, dump_lines: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var hud_main := main_scene.instantiate()
	viewport.add_child(hud_main)
	await process_frame
	hud_main.set("selected_character_id", "berserk")
	hud_main.set("selected_weapon_id", "axe")
	hud_main.set("selected_ascension_level", 2)
	hud_main.call("_start_combat", boss_fight)
	await process_frame
	await process_frame
	var player: Node = hud_main.get("current_player")
	if player != null:
		player.call("apply_reward", {"kind": "artifact", "id": "cracked_shield", "title": "Треснувший щит", "mods": {"defense_flat": 0.12}})
		player.call("apply_reward", {"kind": "artifact", "id": "hawk_eye", "title": "Ястребиный глаз", "mods": {"range_multiplier": 1.12}})
	hud_main.set("_last_hud_snapshot", {})
	hud_main.ui._update_hud()
	await process_frame
	await process_frame
	var context := "%s %s" % ["boss" if boss_fight else "battle", str(viewport_size)]
	var controls := _visible_hud_top_controls(hud_main)
	dump_lines.append("## %s" % context)
	for control in controls:
		dump_lines.append("- `%s`: `%s`, texture `%s`" % [control.name, str(control.get_global_rect()), _stylebox_texture_path(control.get_theme_stylebox("panel") if control is PanelContainer else null)])
		if control.name == "RunResourceHud" and _stylebox_texture_path((control as PanelContainer).get_theme_stylebox("panel")) != MINIMAL_HUD_STRIP_TEXTURE:
			_fail("Expected RunResourceHud to use SCRUM-448 minimal HUD strip frame at %s." % context)
			return
		if control.name == "CombatTimerPanel" and _stylebox_texture_path((control as PanelContainer).get_theme_stylebox("panel")) != MINIMAL_FIELD_TEXTURE:
			_fail("Expected CombatTimerPanel to use SCRUM-448 minimal field frame at %s." % context)
			return
		if control.name == "AscensionHudBadge" and _stylebox_texture_path((control as PanelContainer).get_theme_stylebox("panel")) != MINIMAL_CARD_TEXTURE:
			_fail("Expected AscensionHudBadge to use SCRUM-448 minimal card frame at %s." % context)
			return
	var overlap := _first_control_overlap(controls, 2.0)
	if not overlap.is_empty():
		_fail("Expected no top HUD overlap at %s, got %s." % [context, overlap])
		return
	viewport.queue_free()
	await process_frame


func _visible_hud_top_controls(main: Node) -> Array:
	var controls := []
	for node_name in ["RunResourceHud", "CombatTimerPanel", "AscensionHudBadge", "ArtifactHudRow"]:
		var control := main.find_child(node_name, true, false) as Control
		if control != null and control.visible:
			controls.append(control)
	return controls


func _first_control_overlap(controls: Array, tolerance_px := 2.0) -> String:
	for first_index in range(controls.size()):
		var first := controls[first_index] as Control
		if first == null:
			continue
		var first_rect := _rect_with_tolerance(first.get_global_rect(), tolerance_px)
		for second_index in range(first_index + 1, controls.size()):
			var second := controls[second_index] as Control
			if second == null:
				continue
			var second_rect := _rect_with_tolerance(second.get_global_rect(), tolerance_px)
			if first_rect.intersects(second_rect):
				return "%s %s intersects %s %s" % [first.name, first.get_global_rect(), second.name, second.get_global_rect()]
	return ""


func _first_cross_parent_overlap(controls: Array, tolerance_px := 2.0) -> String:
	for first_index in range(controls.size()):
		var first := controls[first_index] as Control
		if first == null:
			continue
		var first_button := _ancestor_button(first)
		var first_rect := _rect_with_tolerance(first.get_global_rect(), tolerance_px)
		for second_index in range(first_index + 1, controls.size()):
			var second := controls[second_index] as Control
			if second == null:
				continue
			if first_button != null and first_button == _ancestor_button(second):
				continue
			var second_rect := _rect_with_tolerance(second.get_global_rect(), tolerance_px)
			if first_rect.intersects(second_rect):
				return "%s %s intersects %s %s" % [first.name, first.get_global_rect(), second.name, second.get_global_rect()]
	return ""


func _ancestor_button(control: Control) -> Button:
	var node: Node = control
	while node != null:
		if node is Button:
			return node as Button
		node = node.get_parent()
	return null


func _rect_with_tolerance(rect: Rect2, tolerance_px: float) -> Rect2:
	var shrink := tolerance_px * 0.5
	var size := Vector2(maxf(rect.size.x - tolerance_px, 0.0), maxf(rect.size.y - tolerance_px, 0.0))
	return Rect2(rect.position + Vector2(shrink, shrink), size)


func _rect_contains_with_tolerance(outer: Rect2, inner: Rect2, tolerance_px: float) -> bool:
	return inner.position.x >= outer.position.x - tolerance_px \
		and inner.position.y >= outer.position.y - tolerance_px \
		and inner.end.x <= outer.end.x + tolerance_px \
		and inner.end.y <= outer.end.y + tolerance_px


func _scaled_safe_rect(frame_rect: Rect2, source_size: Vector2, margins: Vector4) -> Rect2:
	var scale_x := frame_rect.size.x / maxf(source_size.x, 1.0)
	var scale_y := frame_rect.size.y / maxf(source_size.y, 1.0)
	var margin_left := margins.x * scale_x
	var margin_top := margins.y * scale_y
	var margin_right := margins.z * scale_x
	var margin_bottom := margins.w * scale_y
	return Rect2(
		frame_rect.position + Vector2(margin_left, margin_top),
		Vector2(
			maxf(frame_rect.size.x - margin_left - margin_right, 0.0),
			maxf(frame_rect.size.y - margin_top - margin_bottom, 0.0)
		)
	)


func _scaled_source_rect(frame_rect: Rect2, source_size: Vector2, source_rect: Rect2) -> Rect2:
	var scale_x := frame_rect.size.x / maxf(source_size.x, 1.0)
	var scale_y := frame_rect.size.y / maxf(source_size.y, 1.0)
	return Rect2(
		frame_rect.position + Vector2(source_rect.position.x * scale_x, source_rect.position.y * scale_y),
		Vector2(source_rect.size.x * scale_x, source_rect.size.y * scale_y)
	)


func _collect_label_text(node: Node) -> String:
	var parts := []
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_collect_label_text(child))
	return "\n".join(parts)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _test_boss_hud_omits_timer(main_scene: PackedScene) -> void:
	var boss_main := main_scene.instantiate()
	root.add_child(boss_main)
	await process_frame
	boss_main.set("selected_character_id", "berserk")
	boss_main.set("selected_weapon_id", "axe")
	boss_main.call("_start_combat", true)
	await process_frame
	if boss_main.find_child("CombatTimerPanel", true, false) != null or boss_main.get("timer_label") != null:
		_fail("Expected boss combat HUD to omit CombatTimerPanel and timer_label.")
		return
	boss_main.set("_last_hud_snapshot", {})
	boss_main.ui._update_hud()
	if boss_main.find_child("CombatTimerPanel", true, false) != null or boss_main.get("timer_label") != null:
		_fail("Expected boss combat HUD update not to recreate CombatTimerPanel.")
		return
	boss_main.queue_free()
	await process_frame

	var battle_main := main_scene.instantiate()
	root.add_child(battle_main)
	await process_frame
	battle_main.set("selected_character_id", "berserk")
	battle_main.set("selected_weapon_id", "axe")
	battle_main.call("_start_combat", false)
	await process_frame
	var timer_panel := battle_main.find_child("CombatTimerPanel", true, false) as PanelContainer
	var timer_label := battle_main.get("timer_label") as Label
	if timer_panel == null or timer_label == null:
		_fail("Expected normal combat HUD to create CombatTimerPanel and timer_label.")
		return
	var timer_before := str(timer_label.text)
	battle_main.set("round_time_left", 12.0)
	battle_main.set("_last_hud_snapshot", {})
	battle_main.ui._update_hud()
	if timer_label.text == timer_before:
		_fail("Expected normal combat timer text to update.")
		return
	battle_main.queue_free()
	await process_frame


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
	var run_modifiers: Dictionary = player.get("run_modifiers")
	run_modifiers["death_save"] = 0.0
	run_modifiers["death_save_used"] = 1.0
	player.set("run_modifiers", run_modifiers)
	player.call("take_damage", 99999.0)
	await process_frame
	if bool(death_main.get("combat_active")):
		push_error("Expected player death to end combat.")
		quit(1)
		return
	var death_panel := death_main.find_child("PauseEndModalPanel_death", true, false) as PanelContainer
	if death_panel == null or _stylebox_texture_path(death_panel.get_theme_stylebox("panel")) != MINIMAL_MODAL_TEXTURE:
		push_error("Expected death screen to use the SCRUM-448 minimal modal frame.")
		quit(1)
		return
	death_main.queue_free()


func _test_no_space_number_duplicate_artifacts() -> bool:
	var regex := RegEx.new()
	var err := regex.compile(DUPLICATE_ARTIFACT_PATTERN)
	if err != OK:
		push_error("Duplicate-artifact guard regex failed to compile.")
		return false
	var hits: Array = []
	var scanned := _walk_no_duplicate_artifacts("res://", regex, hits)
	if scanned < 100:
		push_error("Duplicate-artifact guard scanned too few files (%d)." % scanned)
		return false
	if not hits.is_empty():
		hits.sort()
		for path in hits:
			push_error("Duplicate artifact path: %s" % path)
		push_error("Duplicate-artifact guard found %d Finder/sync ` 2` duplicate paths." % hits.size())
		return false
	print("Duplicate-artifact guard passed (%d files scanned)." % scanned)
	return true


func _walk_no_duplicate_artifacts(path: String, regex: RegEx, hits: Array) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			if regex.search(name) != null:
				hits.append(full)
			if _duplicate_artifact_path_is_skipped(full):
				name = dir.get_next()
				continue
			if not DUPLICATE_ARTIFACT_SKIP_DIRS.has(name):
				count += _walk_no_duplicate_artifacts(full, regex, hits)
		else:
			count += 1
			if regex.search(name) != null:
				hits.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return count


func _duplicate_artifact_path_is_skipped(path: String) -> bool:
	for prefix in DUPLICATE_ARTIFACT_SKIP_PATH_PREFIXES:
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false
