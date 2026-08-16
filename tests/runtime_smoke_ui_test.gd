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
	if not _has_unified_screen_background(main, "settings"):
		_fail("Expected SCRUM-879 unified settings backdrop in UI smoke.")
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
	await _test_level_up_world_burst_without_badge(main_scene)

	main.queue_free()
	await process_frame
	_finish("Runtime UI smoke suite passed.")


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
	run_main.set("selected_character_id", "berserk")
	run_main.set("selected_weapon_id", "sword")
	run_main.set("route_stage", 2)
	run_main.call("_start_combat")
	var time_before_escape := float(run_main.get("round_time_left"))
	var player_before_escape: Node2D = run_main.get("current_player") as Node2D
	var player_position_before_escape := player_before_escape.global_position if player_before_escape != null else Vector2.ZERO
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	run_main.call("_input", escape_event)
	await process_frame
	if run_main.find_child("PauseStatsMenuRoot", true, false) == null:
		_fail("Expected active-run Escape to open the character board immediately.")
		return
	if run_main.find_child("RunPauseMenuRoot", true, false) != null:
		_fail("Expected active-run Escape not to show the old standalone pause menu.")
		return
	if not bool(run_main.get_tree().paused):
		_fail("Expected active-run character board to pause gameplay.")
		return
	var settings_button := run_main.find_child("PauseSettingsButton", true, false) as Button
	if settings_button == null:
		_fail("Expected active-run character board left controls to expose Settings.")
		return
	settings_button.emit_signal("pressed")
	await process_frame
	if run_main.find_child("SettingsV2Root", true, false) == null:
		_fail("Expected character-board Settings button to open Settings.")
		return
	var run_back := run_main.find_child("SettingsBackButton", true, false) as Button
	if run_back == null:
		_fail("Expected SettingsBackButton for run settings return smoke.")
		return
	run_back.emit_signal("pressed")
	await process_frame
	if run_main.find_child("PauseStatsMenuRoot", true, false) == null:
		_fail("Expected Settings opened from active run to return to the character board.")
		return
	if run_main.find_child("RunPauseMenuRoot", true, false) != null:
		_fail("Expected Settings return in active run not to restore the old standalone pause menu.")
		return
	if run_main.find_child("MainMenuActions", true, false) != null:
		_fail("Expected run-origin Settings return not to navigate to the main menu.")
		return
	if not bool(run_main.get("combat_active")) or int(run_main.get("route_stage")) != 2:
		_fail("Expected run-origin Settings return to preserve active run state.")
		return
	if abs(float(run_main.get("round_time_left")) - time_before_escape) > 0.001:
		_fail("Expected active-run character board to freeze the combat timer.")
		return
	var resume_button := run_main.find_child("PauseResumeButton", true, false) as Button
	if resume_button == null:
		_fail("Expected active-run character board to expose Resume.")
		return
	resume_button.emit_signal("pressed")
	await process_frame
	if bool(run_main.get_tree().paused) or run_main.find_child("PauseStatsMenuRoot", true, false) != null:
		_fail("Expected Resume to close the character board and resume gameplay.")
		return
	var player_after_resume: Node2D = run_main.get("current_player") as Node2D
	if player_after_resume == null or player_after_resume.global_position.distance_to(player_position_before_escape) > 0.01:
		_fail("Expected active-run Escape flow not to move or replace the player.")
		return
	run_main.queue_free()
	await process_frame


func _test_level_up_world_burst_without_badge(main_scene: PackedScene) -> void:
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
	if badge != null:
		_fail("LevelUpEffect must not create a separate LevelUpPopupBadge plaque.")
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
	if not toast.is_in_group("level_up_effects"):
		_fail("Expected LevelUpToast to join level_up_effects for cleanup.")
		return
	var label := toast.find_child("LevelUpToastLabel", true, false) as Label
	if label == null or label.text != "Level Up":
		_fail("Expected LevelUpToastLabel with Level Up text in runtime UI smoke.")
		return
	var safe_rect: Rect2 = toast_frame.get_meta("toast_content_rect", Rect2()) as Rect2
	if not safe_rect.has_area() or not safe_rect.grow(1.0).encloses(Rect2(label.position, label.size)):
		_fail("Expected LevelUpToastLabel to stay inside the toast safe rect.")
		return
	run_main.queue_free()
	await process_frame
