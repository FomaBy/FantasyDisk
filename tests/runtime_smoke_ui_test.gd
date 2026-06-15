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
