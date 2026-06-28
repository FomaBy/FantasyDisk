extends "res://tests/runtime_smoke_test.gd"


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
