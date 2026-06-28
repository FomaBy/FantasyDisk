extends "res://tests/runtime_smoke_test.gd"

const LevelUpEffectScript := preload("res://scripts/level_up_effect.gd")


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for UI smoke.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if main.get("ui_layer") == null:
		_fail("Expected main menu UI to be created.")
		return
	if main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected main menu actions in UI smoke.")
		return
	await _test_glossary_terms(main)
	await _test_main_menu_quit_confirmation(main_scene)

	main.call("_show_settings_menu")
	await process_frame
	if not _has_screen_background(main, "settings"):
		_fail("Expected settings backdrop in UI smoke.")
		return
	await _test_settings_tabs_and_rebind(main)
	await _test_settings_return_origins(main_scene)

	main.call("_show_character_select")
	await process_frame
	if main.find_child("HeroSelectScreen", true, false) == null:
		_fail("Expected hero select screen in UI smoke.")
		return
	await _test_weapon_select_clean_layout(main_scene)
	await _test_parchment_button_seal_sizes(main_scene)
	await _test_skill_tree_progression_kit(main_scene)
	await _test_hero_select_radar_no_overlap_layouts(main_scene)
	await _test_codex_screen(main_scene)
	await _test_escape_navigation(main_scene)
	await _test_shop_wall_no_overlap_layouts(main_scene)
	await _test_hud_no_overlap_layouts(main_scene)
	await _test_level_up_toast_frame(main_scene)
	await _test_level_up_single_compact_badge(main_scene)

	main.queue_free()
	await process_frame
	print("Runtime UI smoke suite passed.")
	quit()


func _test_settings_return_origins(main_scene: PackedScene) -> void:
	var menu_main := main_scene.instantiate()
	root.add_child(menu_main)
	await process_frame
	menu_main.call("_show_settings_menu")
	await process_frame
	var menu_back := menu_main.find_child("SettingsBackButton", true, false) as Button
	if menu_back == null:
		_fail("Expected SettingsBackButton for main-menu settings return smoke.")
		return
	menu_back.emit_signal("pressed")
	await process_frame
	if menu_main.find_child("MainMenuActions", true, false) == null:
		_fail("Expected Settings opened from main menu to return to the main menu.")
		return
	menu_main.queue_free()
	await process_frame

	var run_main := main_scene.instantiate()
	root.add_child(run_main)
	await process_frame
	run_main.set("combat_active", true)
	run_main.set("route_stage", 2)
	run_main.ui._show_pause_menu()
	await process_frame
	var settings_button := run_main.find_child("RunPauseSettingsButton", true, false) as Button
	if settings_button == null:
		_fail("Expected run pause menu to expose Settings.")
		return
	settings_button.emit_signal("pressed")
	await process_frame
	if run_main.find_child("SettingsV2Root", true, false) == null:
		_fail("Expected run pause Settings button to open Settings.")
		return
	var run_back := run_main.find_child("SettingsBackButton", true, false) as Button
	if run_back == null:
		_fail("Expected SettingsBackButton for run settings return smoke.")
		return
	run_back.emit_signal("pressed")
	await process_frame
	if run_main.find_child("RunPauseMenuRoot", true, false) == null:
		_fail("Expected Settings opened from run pause to return to the run pause menu.")
		return
	if run_main.find_child("MainMenuActions", true, false) != null:
		_fail("Expected run-origin Settings return not to navigate to the main menu.")
		return
	if not bool(run_main.get("combat_active")) or int(run_main.get("route_stage")) != 2:
		_fail("Expected run-origin Settings return to preserve active run state.")
		return
	run_main.queue_free()
	await process_frame


func _test_level_up_single_compact_badge(main_scene: PackedScene) -> void:
	var run_main := main_scene.instantiate()
	root.add_child(run_main)
	await process_frame
	run_main.set("selected_character_id", "berserk")
	run_main.set("selected_weapon_id", "sword")
	run_main.call("_start_combat")
	await process_frame
	await process_frame
	if run_main.get("current_player") == null:
		_fail("Expected player for level-up compact badge smoke.")
		return

	run_main.ui._spawn_level_up_effect()
	await process_frame
	run_main.ui._spawn_level_up_effect()
	await process_frame

	var live_effects := []
	for node in run_main.get_tree().get_nodes_in_group("level_up_effects"):
		if node != null and is_instance_valid(node):
			live_effects.append(node)
	if live_effects.size() != 1:
		_fail("Expected exactly one live LevelUpEffect after rapid spawns, got %d." % live_effects.size())
		return

	var effect := live_effects[0] as Node
	var badge := effect.find_child("LevelUpPopupBadge", true, false) as Node2D
	if badge == null:
		_fail("Expected LevelUpPopupBadge in compact badge smoke.")
		return
	var display_size := Vector2(LevelUpEffectScript.BADGE_DISPLAY_SIZE)
	if display_size.x < 144.0 or display_size.x > 180.0 or display_size.y < 72.0 or display_size.y > 90.0:
		_fail("Expected compact LevelUpEffect badge within 144x72..180x90, got %s." % str(display_size))
		return

	for label in run_main.find_children("*", "Label", true, false):
		var label_text := String((label as Label).text).strip_edges().to_lower()
		if label_text.find("level up") >= 0:
			_fail("Expected no extra runtime Label with Level Up text.")
			return

	run_main.queue_free()
	await process_frame


func _test_level_up_toast_frame(main_scene: PackedScene) -> void:
	var run_main := main_scene.instantiate()
	root.add_child(run_main)
	await process_frame
	run_main.set("selected_character_id", "berserk")
	run_main.set("selected_weapon_id", "sword")
	run_main.set("pending_level_ups", 1)
	run_main.call("_start_combat")
	run_main.ui._show_level_up_toast()
	await process_frame
	await process_frame
	var toast_frame := run_main.find_child("LevelUpToastFrame", true, false) as PanelContainer
	if toast_frame == null:
		_fail("Expected LevelUpToastFrame in runtime UI smoke.")
		return
	var style := toast_frame.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null or style.texture == null or style.texture.resource_path != "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png":
		_fail("Expected LevelUpToastFrame to use SCRUM-588 @2K frame.")
		return
	var toast := run_main.find_child("LevelUpToast", true, false)
	if toast == null:
		_fail("Expected LevelUpToast effect node in runtime UI smoke.")
		return
	if not toast.find_children("*", "Label", true, false).is_empty():
		_fail("Expected LevelUpToast to stay textless in runtime UI smoke.")
		return
	run_main.queue_free()
	await process_frame
