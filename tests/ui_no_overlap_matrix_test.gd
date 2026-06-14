extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]


func _initialize() -> void:
	var dump_lines := PackedStringArray()
	dump_lines.append("# UI No-Overlap Matrix")
	dump_lines.append("")
	var errors := []
	for viewport_size in VIEWPORT_SIZES:
		await _check_screen(viewport_size, "main_menu", Callable(self, "_open_main_menu"), [
			"MainMenuStartButton", "MainMenuSettingsButton", "MainMenuSkillTreeButton",
			"MainMenuPatchNotesButton", "MainMenuCodexButton", "MainMenuExitButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "settings", Callable(self, "_open_settings"), [
			"SettingsResolutionOption", "SettingsWindowModeOption",
		], dump_lines, errors)
		await _check_screen(viewport_size, "codex", Callable(self, "_open_codex"), [
			"CodexBackButton", "CodexTabs", "CodexContent",
		], dump_lines, errors, false)
		await _check_screen(viewport_size, "skill_tree", Callable(self, "_open_skill_tree"), [
			"SkillTreeBackButton", "SkillTreePointsBadge", "SkillTreeClassPanel",
			"SkillTreeBranches",
		], dump_lines, errors)
		await _check_screen(viewport_size, "patch_notes", Callable(self, "_open_patch_notes"), [
			"PatchNotesBackButton",
		], dump_lines, errors, false)
		await _check_screen(viewport_size, "pause_menu", Callable(self, "_open_pause_menu"), [
			"RunPauseMenuPanel", "RunPauseContinueButton", "RunPauseDossierButton",
			"RunPauseSettingsButton", "RunPauseEndRunButton", "RunPauseMainMenuButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "pause_stats", Callable(self, "_open_pause_stats"), [
			"EscapeStatsPanelFrame", "PauseControlButtons", "BaseStatsList",
			"DerivedStatsGroups",
		], dump_lines, errors)
		await _check_screen(viewport_size, "hero_select", Callable(self, "_open_hero_select"), [
			"HeroSelectHeader", "HeroSelectPortraitPanel", "HeroSelectDossierPanel",
			"HeroSelectChooseButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "victory", Callable(self, "_open_victory"), [
			"PauseEndModalPanel_victory", "ResultCrest", "VictoryNewRunButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "death", Callable(self, "_open_death"), [
			"PauseEndModalPanel_death", "ResultCrest", "DeathRetryButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "battle_reward", Callable(self, "_open_battle_reward"), [
			"BattleRewardButton0", "BattleRewardButton1", "BattleRewardButton2",
		], dump_lines, errors)
		await _check_screen(viewport_size, "elite_reward", Callable(self, "_open_elite_reward"), [
			"EliteArtifactRewardButton0", "EliteArtifactRewardButton1", "EliteArtifactRewardButton2",
		], dump_lines, errors)
		await _check_screen(viewport_size, "shop_economy", Callable(self, "_open_shop"), [
			"ShopHeader", "ShopParchmentWall", "ShopItemButton0", "ShopItemButton1",
			"ShopItemButton2", "ShopItemButton3", "ShopLeaveButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "attribute_shop_economy", Callable(self, "_open_attribute_shop"), [
			"AttributeShopPanel", "AttributeOffer_damage", "AttributeOffer_attack_speed",
			"AttributeRerollButton", "AttributeSkipButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "rest_economy", Callable(self, "_open_rest"), [
			"RestHealButton", "RestGuardButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "upgrade_economy", Callable(self, "_open_upgrade"), [
			"UpgradeChoiceButton0", "UpgradeChoiceButton1", "UpgradeChoiceButton2",
		], dump_lines, errors)
		await _check_screen(viewport_size, "event_economy", Callable(self, "_open_event"), [
			"EventChoiceButton0", "EventChoiceButton1", "EventChoiceButton2", "EventBackButton",
		], dump_lines, errors, false)

	var qa_dir := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var file := FileAccess.open("%s/ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(dump_lines))
		file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum330" % qa_dir)
	var scrum330_file := FileAccess.open("%s/scrum330/pause_end_ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum330_file != null:
		scrum330_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["pause_menu", "pause_stats", "victory", "death"])))
		scrum330_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum332" % qa_dir)
	var scrum332_file := FileAccess.open("%s/scrum332/economy_ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum332_file != null:
		scrum332_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["_economy"])))
		scrum332_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum331" % qa_dir)
	var scrum331_file := FileAccess.open("%s/scrum331/progression_ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum331_file != null:
		scrum331_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["skill_tree"])))
		scrum331_file.close()

	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("UI no-overlap matrix test passed.")
	quit(0)


func _check_screen(viewport_size: Vector2i, screen_id: String, open_callable: Callable, control_names: Array, dump_lines: PackedStringArray, errors: Array, require_two_controls := true) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	open_callable.call(main)
	await process_frame
	await process_frame

	var context := "%s %s" % [screen_id, str(viewport_size)]
	var controls := []
	for control_name in control_names:
		var control := main.find_child(control_name, true, false) as Control
		if control == null:
			continue
		if not control.visible or control.get_global_rect().size.x <= 1.0 or control.get_global_rect().size.y <= 1.0:
			continue
		controls.append(control)
	if require_two_controls and controls.size() < 2:
		errors.append("%s: expected at least 2 visible controls, got %d." % [context, controls.size()])
	dump_lines.append("## %s" % context)
	for control in controls:
		var rect := (control as Control).get_global_rect()
		dump_lines.append("- `%s`: `%s`" % [(control as Control).name, str(rect)])
	var overlap := _first_peer_overlap(controls, 2.0)
	if not overlap.is_empty():
		errors.append("%s: %s" % [context, overlap])
	viewport.queue_free()
	await process_frame


func _open_main_menu(main: Node) -> void:
	main.ui._show_main_menu()


func _open_settings(main: Node) -> void:
	main.call("_show_settings_menu")


func _open_codex(main: Node) -> void:
	main.ui._show_codex_screen()


func _open_skill_tree(main: Node) -> void:
	main.ui._show_skill_tree_screen()


func _open_patch_notes(main: Node) -> void:
	main.ui._show_patch_notes_screen()


func _open_pause_menu(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat")
	main.ui._show_pause_menu()


func _open_pause_stats(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat")
	main.ui._show_pause_menu()
	main.ui._show_pause_dossier_menu()


func _open_hero_select(main: Node) -> void:
	main.call("_show_character_select")


func _open_victory(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.ui._show_victory_screen()


func _open_death(main: Node) -> void:
	main.ui._show_death_screen("Тестовое поражение.")


func _open_battle_reward(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.ui._show_reward_screen()


func _open_elite_reward(main: Node) -> void:
	main.set("route_stage", 6)
	main.ui._show_elite_artifact_reward(Callable())


func _open_shop(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 3)
	main.set("current_node_type", "shop")
	main.set("current_route_choice", "matrix_shop")
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	main.add_child(player)
	player.configure_character("berserk", "sword")
	player.set("money", 5000)
	main.call("_store_player_snapshot", player)
	player.queue_free()
	main.call("_show_shop_screen")


func _open_attribute_shop(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("attribute_offer", ["damage", "attack_speed"])
	main.ui._show_attribute_shop(Callable())


func _open_rest(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.call("_show_rest_screen")


func _open_upgrade(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.call("_show_upgrade_screen")


func _open_event(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.ui._show_event_screen({
		"name": "Тестовое событие",
		"event_id": "wandering_bard",
	})


func _first_peer_overlap(controls: Array, tolerance_px: float) -> String:
	for first_index in range(controls.size()):
		var first := controls[first_index] as Control
		if first == null:
			continue
		var first_rect := _rect_with_tolerance(first.get_global_rect(), tolerance_px)
		for second_index in range(first_index + 1, controls.size()):
			var second := controls[second_index] as Control
			if second == null:
				continue
			if _is_ancestor(first, second) or _is_ancestor(second, first):
				continue
			var second_rect := _rect_with_tolerance(second.get_global_rect(), tolerance_px)
			if first_rect.intersects(second_rect):
				return "%s %s intersects %s %s" % [first.name, first.get_global_rect(), second.name, second.get_global_rect()]
	return ""


func _is_ancestor(parent: Control, child: Control) -> bool:
	var node := child.get_parent()
	while node != null:
		if node == parent:
			return true
		node = node.get_parent()
	return false


func _rect_with_tolerance(rect: Rect2, tolerance_px: float) -> Rect2:
	var shrink := tolerance_px * 0.5
	var size := Vector2(maxf(rect.size.x - tolerance_px, 0.0), maxf(rect.size.y - tolerance_px, 0.0))
	return Rect2(rect.position + Vector2(shrink, shrink), size)


func _filter_dump_sections(lines: PackedStringArray, markers: Array) -> PackedStringArray:
	var filtered := PackedStringArray()
	filtered.append("# Filtered UI No-Overlap Matrix")
	filtered.append("")
	var keep := false
	for line in lines:
		if line.begins_with("## "):
			keep = false
			for marker in markers:
				if line.contains(str(marker)):
					keep = true
					break
		if keep:
			filtered.append(line)
	return filtered
