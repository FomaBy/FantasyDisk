extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const ECONOMY_CHOICE_WIDE_PATH := "res://assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png"
const ECONOMY_CHOICE_WIDE_HOVER_PATH := "res://assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide_hover.png"


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
			"SettingsTabSwitcher", "SettingsContentPanel",
			"SettingsResolutionOption", "SettingsWindowModeOption", "SettingsBackButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "codex", Callable(self, "_open_codex"), [
			"CodexBackButton", "CodexTabs", "CodexContent", "CodexDetailPanel",
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
	DirAccess.make_dir_recursive_absolute("%s/scrum413" % qa_dir)
	var scrum413_file := FileAccess.open("%s/scrum413/attribute_shop_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum413_file != null:
		scrum413_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["attribute_shop_economy"])))
		scrum413_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum415" % qa_dir)
	var scrum415_file := FileAccess.open("%s/scrum415/event_option_text_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum415_file != null:
		scrum415_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["event_economy"])))
		scrum415_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum437" % qa_dir)
	var scrum437_file := FileAccess.open("%s/scrum437/wide_economy_choice_card_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum437_file != null:
		scrum437_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["rest_economy", "upgrade_economy", "event_economy", "attribute_shop_economy"])))
		scrum437_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum331" % qa_dir)
	var scrum331_file := FileAccess.open("%s/scrum331/progression_ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum331_file != null:
		scrum331_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["skill_tree"])))
		scrum331_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum438" % qa_dir)
	var scrum438_file := FileAccess.open("%s/scrum438/codex_v2_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum438_file != null:
		scrum438_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["codex"])))
		scrum438_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum439" % qa_dir)
	var scrum439_file := FileAccess.open("%s/scrum439/settings_v2_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum439_file != null:
		scrum439_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["settings"])))
		scrum439_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum436" % qa_dir)
	var scrum436_file := FileAccess.open("%s/scrum436/hero_select_v2_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum436_file != null:
		scrum436_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["hero_select"])))
		scrum436_file.close()

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
		if _requires_viewport_fit(screen_id) and not Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0).encloses(rect):
			errors.append("%s: %s rect %s escapes viewport %s." % [context, (control as Control).name, str(rect), str(viewport_size)])
	var overlap := _first_peer_overlap(controls, 2.0)
	if not overlap.is_empty():
		errors.append("%s: %s" % [context, overlap])
	var screen_error := _screen_specific_assertions(main, screen_id, context)
	if screen_error != "":
		errors.append(screen_error)
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
		"event_id": "cursed_altar",
	})


func _screen_specific_assertions(main: Node, screen_id: String, context: String) -> String:
	if ["attribute_shop_economy", "rest_economy", "upgrade_economy", "event_economy"].has(screen_id):
		for node in main.find_children("*", "Button", true, false):
			var card := node as Button
			if card == null or str(card.get_meta("economy_frame_kind", "")) != "choice_card":
				continue
			var card_error := _economy_choice_card_contract_error(card, context)
			if card_error != "":
				return card_error
	match screen_id:
		"attribute_shop_economy":
			var panel := main.find_child("AttributeShopPanel", true, false) as Control
			var skip_button := main.find_child("AttributeSkipButton", true, false) as Button
			if panel == null or not panel.get_global_rect().has_area():
				return "%s: expected visible AttributeShopPanel." % context
			if skip_button == null or skip_button.disabled:
				return "%s: expected AttributeSkipButton to remain reachable and enabled." % context
			for node in main.find_children("AttributeOffer_*", "Button", true, false):
				var offer := node as Button
				if offer == null:
					continue
				if not offer.disabled:
					return "%s: expected zero-money attribute offers to be disabled." % context
				if not offer.tooltip_text.contains("Недостаточно золота"):
					return "%s: expected disabled attribute offer tooltip to explain insufficient gold." % context
		"event_economy":
			for node in main.find_children("EventChoiceButton*", "Button", true, false):
				var event_button := node as Button
				if event_button == null:
					continue
				if event_button.tooltip_text.contains("Риск: Риск:"):
					return "%s: expected event option text to avoid duplicated risk prefix." % context
				var desc := event_button.find_child("%sDescription" % event_button.name, true, false) as Label
				if desc != null and not event_button.get_global_rect().grow(1.0).encloses(desc.get_global_rect()):
					return "%s: event description %s escapes its card safe content rect." % [context, desc.name]
	return ""


func _requires_viewport_fit(screen_id: String) -> bool:
	return screen_id in ["attribute_shop_economy", "rest_economy", "upgrade_economy", "event_economy"]


func _economy_choice_card_contract_error(card: Button, context: String) -> String:
	if str(card.get_meta("economy_frame_path", "")) != ECONOMY_CHOICE_WIDE_PATH:
		return "%s: expected %s to use SCRUM-437 wide economy choice frame, got %s." % [context, card.name, str(card.get_meta("economy_frame_path", ""))]
	if str(card.get_meta("economy_hover_frame_path", "")) != ECONOMY_CHOICE_WIDE_HOVER_PATH:
		return "%s: expected %s hover to use SCRUM-437 wide hover frame." % [context, card.name]
	if _stylebox_texture_path(card.get_theme_stylebox("normal")) != ECONOMY_CHOICE_WIDE_PATH:
		return "%s: expected %s normal StyleBox to use wide economy choice frame." % [context, card.name]
	if _stylebox_texture_path(card.get_theme_stylebox("hover")) != ECONOMY_CHOICE_WIDE_HOVER_PATH:
		return "%s: expected %s hover StyleBox to use wide economy choice hover frame." % [context, card.name]
	var expected_min_width := 320.0 if context.contains("(1152, 648)") else 360.0
	if context.contains("(1920, 1080)"):
		expected_min_width = 420.0
	elif context.contains("(2560, 1440)"):
		expected_min_width = 480.0
	if card.custom_minimum_size.x < expected_min_width or card.custom_minimum_size.y < 240.0:
		return "%s: expected %s to use the SCRUM-437 wide-card display target, got %s." % [context, card.name, str(card.custom_minimum_size)]
	var source_size: Vector2 = card.get_meta("economy_source_size", Vector2.ZERO)
	var source_safe: Rect2 = card.get_meta("economy_source_safe_rect", Rect2())
	if source_size != Vector2(960.0, 640.0) or source_safe != Rect2(132.0, 118.0, 696.0, 394.0):
		return "%s: expected %s to expose SCRUM-437 source size/safe rect metadata." % [context, card.name]
	var card_rect := card.get_global_rect()
	var safe_rect := _scaled_source_rect(card_rect, source_size, source_safe).grow(1.0)
	var content := card.find_child("%sContent" % card.name, true, false) as Control
	if content != null:
		for child in content.get_children():
			var child_control := child as Control
			if child_control != null and child_control.visible and not safe_rect.encloses(child_control.get_global_rect()):
				return "%s: expected %s child %s to stay inside scaled wide-card safe rect %s." % [context, card.name, child_control.name, str(safe_rect)]
	for suffix in ["Title", "Description", "Action"]:
		var label := card.find_child("%s%s" % [card.name, suffix], true, false) as Label
		if label != null and not safe_rect.encloses(label.get_global_rect()):
			return "%s: expected %s label %s to stay inside scaled wide-card safe rect %s." % [context, card.name, label.name, str(safe_rect)]
	return ""


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


func _stylebox_texture_path(style: StyleBox) -> String:
	if not (style is StyleBoxTexture):
		return ""
	var texture := (style as StyleBoxTexture).texture
	if texture == null:
		return ""
	return texture.resource_path


func _scaled_source_rect(frame_rect: Rect2, source_size: Vector2, source_rect: Rect2) -> Rect2:
	var scale_x := frame_rect.size.x / maxf(source_size.x, 1.0)
	var scale_y := frame_rect.size.y / maxf(source_size.y, 1.0)
	return Rect2(
		frame_rect.position + Vector2(source_rect.position.x * scale_x, source_rect.position.y * scale_y),
		Vector2(source_rect.size.x * scale_x, source_rect.size.y * scale_y)
	)


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
