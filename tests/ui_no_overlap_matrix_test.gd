extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1536, 864),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]
const SCRUM483_GATE_SIZES := [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const TEXT_OVERFLOW_TOLERANCE := 6.0
const UI_FRAME_TEXTURE_PREFIX := "res://assets/sprites/ui/frames/"
const MINIMAL_CARD_PATH := "res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png"
const ECONOMY_CHOICE_WIDE_PATH := MINIMAL_CARD_PATH
const ECONOMY_CHOICE_WIDE_HOVER_PATH := MINIMAL_CARD_PATH
const CR_PANEL_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_cr_panel.png"
const CR_BTN_2K_FRAME_PATH := "res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_240x72_normal.png"
const CR_BTN_CONTINUE_LONG_FRAME_PATH := "res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_run_long_420x72_normal.png"
const RC_PANEL_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_panel.png"
const RC_BTN_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_btn.png"
# SCRUM-565: Событие @2K использует собственные per-слот overhaul_2k-рамки.
const EVT_PANEL_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_evt_panel.png"
const EVT_CARD_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_evt_card.png"
const ATTR_PANEL_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_attr_panel.png"
const PN_PANEL_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pn_panel.png"
# SCRUM-879: кодекс на едином атлас-стиле — COVERED-фон atlas_style, панели-чипы
# StyleBoxFlat в safe-зоне полой рамы meta40 (ассерты совпадают с runtime_smoke_test.gd).
const CODEX_FRAME_BORDER_SUFFIX := "meta40/frame_border.png"
const LUT_TOAST_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png"
const CTB_BIG_2K_FRAME_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ctb_big.png"
const VBN_FRAME_2K_PATH := "res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_vbn_frame.png"
const CHUD_RESOURCE_2K_FRAME_PATH := "res://assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png"  # SCRUM-806
const CHUD_TIMER_2K_FRAME_PATH := "res://assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png"  # SCRUM-806 reopen: единая подложка, без жёлтой рамки
const CHUD_V2_BAR_TRACK_PATH := "res://assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_bar_track.png"  # SCRUM-806


func _initialize() -> void:
	var dump_lines := PackedStringArray()
	dump_lines.append("# UI No-Overlap Matrix")
	dump_lines.append("")
	dump_lines.append("SCRUM-483 render verifier gates: 1920x1080, 2560x1440, 3840x2160.")
	dump_lines.append("Checks: viewport fit, peer overlap, text allocation overflow, parent content containment, and exact-frame TextureRect stretch mode.")
	dump_lines.append("")
	var errors := []
	for viewport_size in VIEWPORT_SIZES:
		await _check_screen(viewport_size, "main_menu", Callable(self, "_open_main_menu"), [
			"MainMenuStartButton", "MainMenuSettingsButton", "MainMenuSkillTreeButton",
			"MainMenuPatchNotesButton", "MainMenuCodexButton", "MainMenuExitButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "continue_run_dialog", Callable(self, "_open_continue_run_dialog"), [
			"ContinueRunPanel", "ContinueRunButton", "ContinueRunNewGameButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "settings", Callable(self, "_open_settings"), [
			"SettingsTabSwitcher", "SettingsContentPanel",
			"SettingsResolutionOption", "SettingsWindowModeOption",
			"SettingsApplyButton", "SettingsRevertButton", "SettingsBackButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "rebind_conflict", Callable(self, "_open_rebind_conflict"), [
			"RebindConflictPanel", "RebindConflictTitle", "RebindConflictMessage",
			"RebindConflictRetryButton", "RebindConflictBackButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "codex", Callable(self, "_open_codex"), [
			"CodexBackButton", "CodexTabs", "CodexCenterObjectStage",
			"CodexCenterSummaryPanel", "CodexCenterListHost", "CodexDetailPanel",
		], dump_lines, errors, false)
		# SCRUM-827: экран дерева заменён «Атласом героев» (шапка-валюты/вкладки,
		# лента классов, холст созвездия, панель узла, низ с респеком и легендой).
		await _check_screen(viewport_size, "skill_tree", Callable(self, "_open_skill_tree"), [
			"AtlasBackButton", "AtlasEmblemBadge", "AtlasStardustBadge",
			"AtlasTabGuild", "AtlasClassStrip", "AtlasCanvas", "AtlasNodePanel",
			"AtlasRespecButton", "AtlasLegend",
		], dump_lines, errors)
		await _check_screen(viewport_size, "patch_notes", Callable(self, "_open_patch_notes"), [
			"PatchNotesPanel", "PatchNotesBackButton",
		], dump_lines, errors, false)
		await _check_screen(viewport_size, "level_up", Callable(self, "_open_level_up"), [
			"LevelUpPanel", "LevelUpHeroHeader", "LevelUpRewardButton0",
			"LevelUpRewardButton1", "LevelUpRewardButton2", "LevelUpLaterButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "pause_menu", Callable(self, "_open_pause_menu"), [
			"EscapeStatsPanelFrame", "PauseControlButtons", "BaseStatsList",
			"DerivedStatsGroups",
		], dump_lines, errors)
		await _check_screen(viewport_size, "pause_stats", Callable(self, "_open_pause_stats"), [
			"EscapeStatsPanelFrame", "PauseControlButtons", "BaseStatsList",
			"DerivedStatsGroups",
		], dump_lines, errors)
		await _check_screen(viewport_size, "hero_select", Callable(self, "_open_hero_select"), [
			"HS4PortraitFrame", "HS4DossierFrame", "HS4AscensionFrame", "HS4Carousel", "HS4ChooseButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "victory", Callable(self, "_open_victory"), [
			"PauseEndModalPanel_victory", "ResultCrest", "VictoryNewRunButton",
			"RunSummaryOutcome", "RunSummaryStat_kills", "RunSummaryStat_time",
		], dump_lines, errors)
		await _check_screen(viewport_size, "death", Callable(self, "_open_death"), [
			"PauseEndModalPanel_death", "ResultCrest", "DeathRetryButton",
			"RunSummaryOutcome", "RunSummaryStat_kills", "RunSummaryStat_time",
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
			"RestHealButton", "RestGuardButton", "RestBackButton",
		], dump_lines, errors)
		await _check_screen(viewport_size, "upgrade_economy", Callable(self, "_open_upgrade"), [
			"UpgradeChoiceButton0", "UpgradeChoiceButton1", "UpgradeChoiceButton2",
		], dump_lines, errors)
		await _check_screen(viewport_size, "event_economy", Callable(self, "_open_event"), [
			"EventChoiceButton0", "EventChoiceButton1", "EventChoiceButton2", "EventBackButton",
		], dump_lines, errors, false)
		# SCRUM-671: боевой HUD — clean essential-only set from SCRUM-666:
		# HP/XP/money/ULT, timer, ascension/elevation and bottom-right level-up plus only.
		await _check_screen(viewport_size, "combat_hud", Callable(self, "_open_combat_hud"), [
			"RunResourceHud", "CombatTimerPanel", "AscensionHudRow", "LevelUpPlusButton",
		], dump_lines, errors)
		# SCRUM-487: баннер появления босса — ширина из CTB_*_2K (фикс легаси 1280=720p),
		# текст центрируется по 2K-базе и помещается в рамку. Транзиентный — один контрол.
		await _check_screen(viewport_size, "combat_title_banner", Callable(self, "_open_combat_title_banner"), [
			"CombatIntroBanner",
		], dump_lines, errors, false)
		await _check_screen(viewport_size, "victory_banner", Callable(self, "_open_victory_banner"), [
			"VictoryBannerFrame",
		], dump_lines, errors, false)
		# SCRUM-588/user bugfix: transient level-up toast uses an isolated @2K frame and keeps
		# both the Level Up label and sparkle content inside the documented safe zone.
		await _check_screen(viewport_size, "level_up_toast", Callable(self, "_open_level_up_toast"), [
			"LevelUpToastFrame",
		], dump_lines, errors, false)
		# SCRUM-489: блок «Результаты/Старт» — экран выбора оружия (economy-панель WS_*_2K):
		# карточки оружия не пересекаются, текст в рамках, рамка не на STRETCH_SCALE.
		await _check_screen(viewport_size, "weapon_select", Callable(self, "_open_weapon_select"), [
			"WeaponOption_sword", "WeaponOption_axe", "WeaponOption_hammer",
		], dump_lines, errors)
		# SCRUM-489: карта маршрута (полноэкранный скролл RM_*_2K) — хедер/скролл/canvas не
		# наслаиваются; canvas выше viewport — это норма (скролл), viewport-fit не требуется.
		await _check_screen(viewport_size, "route_map", Callable(self, "_open_route_map"), [
			"RouteMapHeader", "RouteMapScroll", "VerticalRouteMap",
		], dump_lines, errors)

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
	DirAccess.make_dir_recursive_absolute("%s/scrum448_ui_minimalist" % qa_dir)
	var scrum448_file := FileAccess.open("%s/scrum448_ui_minimalist/ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum448_file != null:
		scrum448_file.store_string("\n".join(dump_lines))
		scrum448_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum451_minimal_metal_rollout" % qa_dir)
	var scrum451_file := FileAccess.open("%s/scrum451_minimal_metal_rollout/ui_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum451_file != null:
		scrum451_file.store_string("\n".join(dump_lines))
		scrum451_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum470_hero_select_v4" % qa_dir)
	var scrum470_file := FileAccess.open("%s/scrum470_hero_select_v4/hero_select_v4_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum470_file != null:
		scrum470_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["hero_select"])))
		scrum470_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum483_ui_render_verifier" % qa_dir)
	var scrum483_file := FileAccess.open("%s/scrum483_ui_render_verifier/ui_render_verifier_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum483_file != null:
		scrum483_file.store_string("\n".join(_filter_dump_viewport_sections(dump_lines, SCRUM483_GATE_SIZES)))
		scrum483_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum487" % qa_dir)
	var scrum487_file := FileAccess.open("%s/scrum487/combat_block_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum487_file != null:
		scrum487_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["combat_hud", "combat_title_banner", "level_up", "battle_reward", "elite_reward", "event_economy"])))
		scrum487_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum683" % qa_dir)
	var scrum683_file := FileAccess.open("%s/scrum683/level_up_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum683_file != null:
		scrum683_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["level_up"])))
		scrum683_file.close()
	DirAccess.make_dir_recursive_absolute("%s/scrum489" % qa_dir)
	var scrum489_file := FileAccess.open("%s/scrum489/results_block_no_overlap_matrix.md" % qa_dir, FileAccess.WRITE)
	if scrum489_file != null:
		scrum489_file.store_string("\n".join(_filter_dump_sections(dump_lines, ["victory", "death", "hero_select", "weapon_select", "route_map"])))
		scrum489_file.close()

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
	_append_text_overflow_errors(main, context, errors, dump_lines)
	_append_texture_stretch_errors(main, context, errors, dump_lines)
	var screen_error := _screen_specific_assertions(main, screen_id, context)
	if screen_error != "":
		errors.append(screen_error)
	viewport.queue_free()
	await process_frame


func _open_main_menu(main: Node) -> void:
	main.ui._show_main_menu()


func _open_continue_run_dialog(main: Node) -> void:
	main.RUN_AUTOSAVE.save_run({
		"selected_character_id": "berserk",
		"current_act": 1,
		"route_stage": 2,
		"run_player_snapshot": {
			"money": 240,
			"level": 5,
		},
	})
	main.ui._show_continue_run_dialog()
	main.RUN_AUTOSAVE.clear_run()


func _open_settings(main: Node) -> void:
	main.call("_show_settings_menu")


func _open_rebind_conflict(main: Node) -> void:
	main.ui._show_rebind_conflict("move_up", KEY_W, "move_down")


func _open_codex(main: Node) -> void:
	main.ui._show_codex_screen()


func _open_skill_tree(main: Node) -> void:
	main.ui._show_atlas_screen()


func _open_patch_notes(main: Node) -> void:
	main.ui._show_patch_notes_screen()


func _open_level_up(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("pending_level_ups", 1)
	main.set("level_up_offer", [
		{"id": "matrix_stat_strength", "title": "Сила +1", "description": "Редкий рост основной характеристики: +1 к параметру «Сила».", "kind": "stat", "stats": {"strength": 1.0}, "rare": true},
		{"id": "matrix_damage", "title": "+Урон", "description": "+15% к урону.", "kind": "upgrade", "mods": {"damage_multiplier": 1.15}},
		{"id": "matrix_aoe", "title": "+Радиус области", "description": "+15% к конусам и радиусам атак.", "kind": "upgrade", "mods": {"aoe_radius_multiplier": 1.15, "range_multiplier": 1.08}},
	])
	main.ui._show_level_up_screen(false)


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
	main.set("run_metrics", _sample_run_metrics("Повержен финальный босс: Лорд Бездны"))
	main.ui._show_victory_screen()


func _open_death(main: Node) -> void:
	main.set("run_metrics", _sample_run_metrics("Пал в бою на этапе маршрута 6"))
	main.ui._show_death_screen("Тестовое поражение.")


func _sample_run_metrics(outcome: String) -> Dictionary:
	# SCRUM-502: непустые метрики, чтобы строки сводки рендерились на всех разрешениях.
	return {
		"kills": 137, "boss_kills": 1, "damage_dealt": 48213.0, "damage_taken": 6042.0,
		"gold_collected": 1840, "time_seconds": 742.0, "route_stage_reached": 5,
		"final_level": 12, "artifacts": [{"title": "Сердце Пиявки"}, {"title": "Шип Бездны"}],
		"outcome_reason": outcome, "last_boss_name": "Лорд Бездны",
	}


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


func _open_combat_hud(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("selected_ascension_level", 1)
	main.set("pending_level_ups", 1)
	main.call("_start_combat")
	main.ui._update_level_up_button()


func _open_combat_title_banner(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat")
	main.ui._show_combat_title_banner("Лорд Бездны", Color(1.0, 0.4, 0.3, 1.0), true)


func _open_victory_banner(main: Node) -> void:
	main.ui._show_victory_banner(Callable())


func _open_level_up_toast(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.call("_start_combat")
	main.set("pending_level_ups", 1)
	main.ui._show_level_up_toast()


func _open_weapon_select(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.ui._show_weapon_select()


func _open_route_map(main: Node) -> void:
	main.set("selected_character_id", "berserk")
	main.set("selected_weapon_id", "sword")
	main.set("route_stage", 0)
	main.set("route_nodes", main.route._generate_route())
	main.route._show_battle_map()


func _screen_specific_assertions(main: Node, screen_id: String, context: String) -> String:
	# SCRUM-565/568: Событие и Докача переехали на overhaul_2k card-рамку (evt_card),
	# поэтому общий minimal-metal card-контракт к ним больше не применяется (проверка
	# evt_card-рамки — в их match-ветках ниже).
	if ["rest_economy", "upgrade_economy"].has(screen_id):
		for node in main.find_children("*", "Button", true, false):
			var card := node as Button
			if card == null or str(card.get_meta("economy_frame_kind", "")) != "choice_card":
				continue
			var card_error := _economy_choice_card_contract_error(card, context)
			if card_error != "":
				return card_error
	match screen_id:
		"weapon_select":
			var layer := main.find_child("WeaponSelectPixelLabRuntimeLayer", true, false) as TextureRect
			if layer != null:
				return "%s: SCRUM-870 forbids the rejected WeaponSelectPixelLabRuntimeLayer." % context
			var panel := main.find_child("MenuPanel_weapon_select", true, false) as Control
			if panel == null:
				return "%s: expected live SCRUM-870 Weapon Select panel." % context
			var panel_style := panel.get_theme_stylebox("panel")
			if not panel_style is StyleBoxFlat or (panel_style as StyleBoxFlat).bg_color.a < 0.80:
				return "%s: expected Weapon Select panel to be an opaque readable dark live panel." % context
			for node in main.find_children("WeaponOption_*", "Button", true, false):
				var button := node as Button
				if button == null:
					continue
				var normal := button.get_theme_stylebox("normal")
				if not normal is StyleBoxFlat or (normal as StyleBoxFlat).bg_color.a < 0.80:
					return "%s: expected %s normal style to be an opaque readable SCRUM-870 card." % [context, button.name]
				if button.find_child("WeaponSelectIconWell_*", true, false) == null:
					return "%s: expected %s to contain a framed weapon icon well." % [context, button.name]
				if button.find_child("WeaponSelectStatsPanel_*", true, false) == null:
					return "%s: expected %s to contain a compact stats panel." % [context, button.name]
		"pause_menu", "pause_stats":
			var strength_row := main.find_child("BaseStatRow_strength", true, false) as Control
			var strength_name := main.find_child("BaseStatName_strength", true, false) as Label
			var strength_value := main.find_child("BaseStatValue_strength", true, false) as Label
			var strength_icon := main.find_child("UIIcon_strength", true, false) as Control
			var damage_chip := main.find_child("DerivedStatChip_damage", true, false) as Control
			var damage_name := main.find_child("DerivedStatName_damage", true, false) as Label
			var damage_value := main.find_child("DerivedStatValue_damage", true, false) as Label
			var damage_icon := main.find_child("UIIcon_damage", true, false) as Control
			if strength_row == null or strength_name == null or strength_value == null or strength_icon == null:
				return "%s: expected readable base stat controls for SCRUM-839." % context
			if damage_chip == null or damage_name == null or damage_value == null or damage_icon == null:
				return "%s: expected readable derived stat chip controls for SCRUM-839." % context
			if strength_row.custom_minimum_size.y < 44.0:
				return "%s: expected base stat row min height >= 44px for SCRUM-839 readability." % context
			if strength_name.get_theme_font_size("font_size") < 17 or strength_value.get_theme_font_size("font_size") < 18:
				return "%s: expected base stat label/value font sizes >= 17/18 for SCRUM-839 readability." % context
			if strength_icon.custom_minimum_size.x < 44.0 or strength_icon.custom_minimum_size.y < 44.0:
				return "%s: expected base stat icons >= 44px for SCRUM-839 readability." % context
			if damage_chip.custom_minimum_size.x < 236.0 or damage_chip.custom_minimum_size.y < 54.0:
				return "%s: expected derived stat chips >= 236x54px for SCRUM-839 readability." % context
			if damage_name.get_theme_font_size("font_size") < 15 or damage_value.get_theme_font_size("font_size") < 17:
				return "%s: expected derived stat label/value font sizes >= 15/17 for SCRUM-839 readability." % context
			if damage_icon.custom_minimum_size.x < 46.0 or damage_icon.custom_minimum_size.y < 46.0:
				return "%s: expected derived stat icons >= 46px for SCRUM-839 readability." % context
		"combat_hud":
			if main.find_child("CharacterStatsHud", true, false) != null:
				return "%s: SCRUM-671 essential-only HUD must not show CharacterStatsHud." % context
			if main.find_child("ArtifactHudRow", true, false) != null:
				return "%s: SCRUM-671 essential-only HUD must not show ArtifactHudRow." % context
			var resource := main.find_child("RunResourceHud", true, false) as PanelContainer
			if resource == null or _stylebox_texture_path(resource.get_theme_stylebox("panel")) != CHUD_RESOURCE_2K_FRAME_PATH:
				return "%s: expected RunResourceHud to use chud_resource_panel @2K frame." % context
			# SCRUM-806: HUD v2 — вместо карточек проверяем слим-треки и денежную строку.
			for legacy_card_name in ["HudHPCard", "HudXPCard", "HudMoneyCard", "HudULTCard"]:
				if main.find_child(legacy_card_name, true, false) != null:
					return "%s: SCRUM-806 HUD v2 must not show legacy card %s." % [context, legacy_card_name]
			for track_name in ["HudHPTrack", "HudXPTrack", "HudULTTrack"]:
				var track := main.find_child(track_name, true, false) as PanelContainer
				if track == null or not track.visible or not track.get_global_rect().has_area():
					return "%s: expected visible %s slim track." % [context, track_name]
				if _stylebox_texture_path(track.get_theme_stylebox("panel")) != CHUD_V2_BAR_TRACK_PATH:
					return "%s: expected %s to use SCRUM-806 slim bar track." % [context, track_name]
				var track_zone: Rect2 = track.get_meta("scrum666_content_zone", Rect2()) as Rect2
				if not track_zone.has_area() or not track_zone.grow(1.0).encloses(track.get_global_rect()):
					return "%s: expected %s to occupy HUD v2 zone %s, got %s." % [context, track_name, str(track_zone), str(track.get_global_rect())]
			var money_label := main.find_child("HudMoneyLabel", true, false) as Label
			var money_icon := main.find_child("UIIcon_money", true, false) as TextureRect
			if money_label == null or not money_label.visible or money_icon == null or money_icon.texture == null:
				return "%s: expected HUD v2 money row (pixel coin icon + label)." % context
			var timer_panel := main.find_child("CombatTimerPanel", true, false) as PanelContainer
			if timer_panel == null or _stylebox_texture_path(timer_panel.get_theme_stylebox("panel")) != CHUD_TIMER_2K_FRAME_PATH:
				return "%s: expected CombatTimerPanel to use chud_timer @2K frame." % context
			var timer_label := main.find_child("CombatTimerLabel", true, false) as Label
			var timer_zone: Rect2 = timer_panel.get_meta("scrum666_content_zone", Rect2()) as Rect2
			if timer_label == null or not timer_zone.has_area() or not timer_zone.grow(1.0).encloses(timer_label.get_global_rect()):
				return "%s: expected CombatTimerLabel to stay inside SCRUM-666 timer zone %s." % [context, str(timer_zone)]
			# SCRUM-806 reopen: возвышение — голый ряд эмблем, рамка и цифра убраны.
			if main.find_child("AscensionHudBadge", true, false) != null:
				return "%s: SCRUM-806 HUD v2 must not show the framed ascension badge." % context
			var ascension_row := main.find_child("AscensionHudRow", true, false) as HBoxContainer
			if ascension_row != null:
				if ascension_row.get_child_count() < 1 or not ascension_row.get_global_rect().has_area():
					return "%s: expected non-empty visible ascension pip row." % context
				for pip in ascension_row.get_children():
					if (pip as TextureRect) == null or (pip as TextureRect).texture == null:
						return "%s: expected textured ascension pips." % context
			var plus := main.find_child("LevelUpPlusButton", true, false) as Button
			if plus == null or plus.text != "+":
				return "%s: expected bottom-right LevelUpPlusButton." % context
			var plus_zone: Rect2 = plus.get_meta("scrum666_content_zone", Rect2()) as Rect2
			if not plus_zone.has_area() or not plus_zone.grow(1.0).encloses(plus.get_global_rect()):
				return "%s: expected LevelUpPlusButton to occupy SCRUM-666 plus zone %s, got %s." % [context, str(plus_zone), str(plus.get_global_rect())]
			if context.contains("(1920, 1080)"):
				var viewport_rect := main.get_viewport().get_visible_rect()
				var top_band_bottom := maxf(resource.get_global_rect().end.y, timer_panel.get_global_rect().end.y)
				if ascension_row != null:
					top_band_bottom = maxf(top_band_bottom, ascension_row.get_global_rect().end.y)
				var top_band_ratio := top_band_bottom / maxf(1.0, viewport_rect.size.y)
				if top_band_ratio > 0.18:
					return "%s: expected compact 1080p combat HUD top band <= 18%% viewport height, got %.2f%%." % [context, top_band_ratio * 100.0]
				var plus_frame: Rect2 = plus.get_meta("scrum666_frame_rect", Rect2()) as Rect2
				var plus_footprint_ratio := (plus_frame.size.x * plus_frame.size.y) / maxf(1.0, viewport_rect.size.x * viewport_rect.size.y)
				if plus_footprint_ratio > 0.035:
					return "%s: expected compact 1080p pending-level footprint <= 3.5%% viewport area, got %.2f%%." % [context, plus_footprint_ratio * 100.0]
			var badge_panel := plus.find_child("LevelUpPlusBadgePanel", true, false) as PanelContainer
			var badge_zone: Rect2 = badge_panel.get_meta("scrum666_content_zone", Rect2()) as Rect2 if badge_panel != null else Rect2()
			var badge_label := plus.find_child("LevelUpPlusBadge", true, false) as Label
			if badge_panel == null or badge_label == null or not badge_zone.has_area() or not badge_zone.grow(1.0).encloses(badge_label.get_global_rect()):
				return "%s: expected LevelUpPlusBadge label to stay inside SCRUM-666 count zone %s." % [context, str(badge_zone)]
		"continue_run_dialog":
			var continue_panel := main.find_child("ContinueRunPanel", true, false) as PanelContainer
			if continue_panel == null or not continue_panel.visible or not continue_panel.get_global_rect().has_area():
				return "%s: expected visible ContinueRunPanel." % context
			if _stylebox_texture_path(continue_panel.get_theme_stylebox("panel")) != CR_PANEL_2K_FRAME_PATH:
				return "%s: expected ContinueRunPanel to use cr_panel @2K frame." % context
			if str(continue_panel.get_meta("continue_run_slot", "")) != "cr_panel":
				return "%s: expected ContinueRunPanel slot metadata to be cr_panel." % context
			if not _vector2_approx(continue_panel.get_global_rect().size, Vector2(840, 380), 1.0):
				return "%s: expected SCRUM-842 widened ContinueRunPanel 840x380, got %s." % [context, str(continue_panel.get_global_rect().size)]
			var expected_cr_margins := Vector4(58.0 * 840.0 / 680.0, 72.0, 58.0 * 840.0 / 680.0, 66.0)
			var cr_margins := Vector4(continue_panel.get_meta("continue_run_content_margins", Vector4.ZERO))
			if not _vector4_approx(cr_margins, expected_cr_margins, 1.0):
				return "%s: expected ContinueRunPanel SCRUM-842 scaled content margins, got %s." % [context, str(cr_margins)]
			var expected_cr_safe := Rect2(
				Vector2(expected_cr_margins.x, expected_cr_margins.y),
				Vector2(840.0 - expected_cr_margins.x - expected_cr_margins.z, 380.0 - expected_cr_margins.y - expected_cr_margins.w)
			)
			var cr_safe := continue_panel.get_meta("continue_run_content_rect", Rect2()) as Rect2
			if not _rect2_approx(cr_safe, expected_cr_safe, 1.0):
				return "%s: expected ContinueRunPanel safe rect to match widened SCRUM-842 content area, got %s." % [context, str(cr_safe)]
			var cr_global_safe := Rect2(continue_panel.get_global_rect().position + cr_safe.position, cr_safe.size).grow(1.0)
			for button_name in ["ContinueRunButton", "ContinueRunNewGameButton"]:
				var cr_button := main.find_child(button_name, true, false) as Button
				if cr_button == null:
					return "%s: expected %s in ContinueRunPanel." % [context, button_name]
				if not cr_global_safe.encloses(cr_button.get_global_rect()):
					return "%s: expected %s to stay inside ContinueRunPanel safe rect %s, got %s." % [context, button_name, str(cr_global_safe), str(cr_button.get_global_rect())]
				var expected_button_path := CR_BTN_CONTINUE_LONG_FRAME_PATH if button_name == "ContinueRunButton" else CR_BTN_2K_FRAME_PATH
				if _stylebox_texture_path(cr_button.get_theme_stylebox("normal")) != expected_button_path:
					return "%s: expected %s to use %s." % [context, button_name, expected_button_path]
				if button_name == "ContinueRunButton":
					for state in ["normal", "hover", "focus", "pressed", "disabled"]:
						var fit_error := _button_label_content_fit_error(cr_button, state, context)
						if fit_error != "":
							return fit_error
		"rebind_conflict":
			var rebind_panel := main.find_child("RebindConflictPanel", true, false) as Control
			if rebind_panel == null or not rebind_panel.visible or not rebind_panel.get_global_rect().has_area():
				return "%s: expected visible RebindConflictPanel." % context
			if _stylebox_texture_path(rebind_panel.get_theme_stylebox("panel")) != RC_PANEL_2K_FRAME_PATH:
				return "%s: expected RebindConflictPanel to use rc_panel @2K frame." % context
			if str(rebind_panel.get_meta("rebind_conflict_stage", "")) != "openai_mockup_ready_runtime_rc_assets":
				return "%s: expected RebindConflictPanel to expose completed SCRUM-584 stage metadata." % context
			if Vector4(rebind_panel.get_meta("rebind_conflict_content_margins", Vector4.ZERO)) != Vector4(58, 72, 58, 66):
				return "%s: expected RebindConflictPanel strict SCRUM-584 content margins." % context
			var rebind_safe: Rect2 = rebind_panel.get_meta("rebind_conflict_content_rect", Rect2()) as Rect2
			if rebind_safe != Rect2(58, 72, 564, 242):
				return "%s: expected RebindConflictPanel safe rect to match RC_SAFE_2K." % context
			var scaled_rebind_safe := _scaled_source_rect(rebind_panel.get_global_rect(), Vector2(680, 380), rebind_safe).grow(1.0)
			for child_name in ["RebindConflictTitle", "RebindConflictMessage", "RebindConflictRetryButton", "RebindConflictBackButton"]:
				var child := main.find_child(child_name, true, false) as Control
				if child == null or not child.visible or not child.get_global_rect().has_area():
					return "%s: expected visible %s." % [context, child_name]
				if not scaled_rebind_safe.encloses(child.get_global_rect()):
					return "%s: expected %s to stay inside scaled rebind conflict safe rect %s." % [context, child_name, str(scaled_rebind_safe)]
			for button_name in ["RebindConflictRetryButton", "RebindConflictBackButton"]:
				var rebind_button := main.find_child(button_name, true, false) as Button
				if rebind_button == null:
					return "%s: expected %s button." % [context, button_name]
				if _stylebox_texture_path(rebind_button.get_theme_stylebox("normal")) != RC_BTN_2K_FRAME_PATH:
					return "%s: expected %s to use rc_btn @2K button frame." % [context, button_name]
		"victory", "death":
			var result_panel := main.find_child("PauseEndModalPanel_%s" % screen_id, true, false) as PanelContainer
			if result_panel == null or not result_panel.visible or not result_panel.get_global_rect().has_area():
				return "%s: expected visible result panel." % context
			if main.find_child("PauseEndModalScroll_%s" % screen_id, true, false) != null:
				return "%s: SCRUM-841 result screens must not use PauseEndModalScroll_%s." % [context, screen_id]
			var result_content := main.find_child("ResultContent_%s" % screen_id, true, false) as Control
			var result_body := main.find_child("ResultBody_%s" % screen_id, true, false) as Control
			var summary_column := main.find_child("RunSummaryColumn_%s" % screen_id, true, false) as Control
			if result_content == null or result_body == null or summary_column == null:
				return "%s: expected SCRUM-841 no-scroll result content/body/summary nodes." % context
			var content_rect: Rect2 = result_panel.get_meta("pause_end_content_rect", Rect2()) as Rect2
			var display_size: Vector2 = result_panel.get_meta("pause_end_display_size", result_panel.get_global_rect().size) as Vector2
			if not content_rect.has_area():
				return "%s: expected result panel to expose pause_end_content_rect metadata." % context
			var scaled_safe := _scaled_source_rect(result_panel.get_global_rect(), display_size, content_rect).grow(1.0)
			var content_safe := result_content.get_global_rect().grow(1.0)
			if not scaled_safe.encloses(result_content.get_global_rect()):
				return "%s: expected ResultContent_%s to match result frame safe rect %s, got %s." % [context, screen_id, str(scaled_safe), str(result_content.get_global_rect())]
			var result_button_name := "DeathRetryButton"
			if screen_id == "victory":
				result_button_name = "VictoryNewRunButton"
			for child_name in ["ResultBody_%s" % screen_id, "RunSummaryStats", result_button_name]:
				var child := main.find_child(child_name, true, false) as Control
				if child == null or not child.visible or not child.get_global_rect().has_area():
					return "%s: expected visible %s inside result panel." % [context, child_name]
				if not content_safe.encloses(child.get_global_rect()):
					return "%s: expected %s to stay inside ResultContent safe rect %s, got %s." % [context, child_name, str(content_safe), str(child.get_global_rect())]
		"codex":
			# SCRUM-879: единый атлас-стиль — фон COVERED без осевого stretch,
			# полая рама meta40 поверх, панели-чипы StyleBoxFlat в safe-зоне рамы.
			var codex_background := main.find_child("UnifiedBackground_codex", true, false) as TextureRect
			if codex_background == null or codex_background.texture == null:
				return "%s: expected UnifiedBackground_codex with a loaded texture." % context
			if codex_background.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED or codex_background.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
				return "%s: expected UnifiedBackground_codex to cover the viewport without axis stretch." % context
			var codex_frame := main.find_child("CodexFrame", true, false) as Panel
			if codex_frame == null:
				return "%s: expected CodexFrame ornament overlay." % context
			var codex_frame_style := codex_frame.get_theme_stylebox("panel") as StyleBoxTexture
			if codex_frame_style == null or codex_frame_style.draw_center:
				return "%s: expected hollow CodexFrame (StyleBoxTexture, draw_center=false)." % context
			if codex_frame_style.texture == null or not codex_frame_style.texture.resource_path.ends_with(CODEX_FRAME_BORDER_SUFFIX):
				return "%s: expected CodexFrame to use the meta40 frame_border 9-slice." % context
			var codex_vp := codex_frame.get_viewport_rect().size
			var codex_margin_x := roundf(160.0 * codex_vp.x / 1536.0)
			var codex_margin_y := roundf(160.0 * codex_vp.y / 1024.0)
			var codex_safe := Rect2(
				codex_margin_x, codex_margin_y,
				codex_vp.x - 2.0 * codex_margin_x, codex_vp.y - 2.0 * codex_margin_y
			).grow(2.0)
			for codex_panel_name in ["CodexNavPanel", "CodexContent", "CodexDetailPanel"]:
				var codex_panel := main.find_child(str(codex_panel_name), true, false) as PanelContainer
				if codex_panel == null or not codex_panel.get_global_rect().has_area():
					return "%s: expected visible %s." % [context, codex_panel_name]
				var codex_chip := codex_panel.get_theme_stylebox("panel") as StyleBoxFlat
				if codex_chip == null or codex_chip.bg_color.a < 0.8 or codex_chip.bg_color.v > 0.35:
					return "%s: expected %s to use a dark atlas chip StyleBoxFlat (alpha >= 0.8)." % [context, codex_panel_name]
				if not codex_safe.encloses(codex_panel.get_global_rect()):
					return "%s: expected %s to stay inside unified safe margins %s, got %s." % [context, codex_panel_name, str(codex_safe), str(codex_panel.get_global_rect())]
			var entry_card := main.find_child("CodexEntryCard", true, false) as Button
			if entry_card == null or not (entry_card.get_theme_stylebox("normal") is StyleBoxFlat):
				return "%s: expected CodexEntryCard to use the unified leather row StyleBoxFlat." % context
			var tab_button := main.find_child("CodexTab_characters", true, false) as Button
			if tab_button == null or not _stylebox_texture_path(tab_button.get_theme_stylebox("normal")).contains("minimal_metal_codex_tab"):
				return "%s: expected CodexTab_characters to use the global codex_tab kit button." % context
			var center_panel := main.find_child("CodexContent", true, false) as Control
			var center_stage := main.find_child("CodexCenterObjectStage", true, false) as Control
			var center_texture := main.find_child("CodexCenterObjectTexture", true, false) as TextureRect
			var center_summary := main.find_child("CodexCenterSummaryPanel", true, false) as Control
			var center_list := main.find_child("CodexCenterListHost", true, false) as Control
			var detail_panel := main.find_child("CodexDetailPanel", true, false) as Control
			var detail_portrait := main.find_child("CodexDetailPortraitSlot", true, false) as Control
			var detail_texture := main.find_child("CodexDetailPortraitTexture", true, false) as TextureRect
			var detail_chips := main.find_child("CodexDetailChipRow", true, false) as Control
			var detail_text := main.find_child("CodexDetailParchmentInset", true, false) as Control
			for required in [center_panel, center_stage, center_texture, center_summary, center_list, detail_panel, detail_portrait, detail_texture, detail_chips, detail_text]:
				var required_control := required as Control
				if required_control == null or not required_control.get_global_rect().has_area():
					var required_name := str(required_control.name) if required_control != null else "<missing>"
					return "%s: expected SCRUM-850 Codex object-first zone %s to be visible." % [context, required_name]
			var center_rect := center_panel.get_global_rect().grow(1.0)
			for child in [center_stage, center_summary, center_list]:
				var child_control := child as Control
				if not center_rect.encloses(child_control.get_global_rect()):
					return "%s: expected %s to stay inside CodexContent safe panel." % [context, str(child_control.name)]
			var detail_rect := detail_panel.get_global_rect().grow(1.0)
			for child in [detail_portrait, detail_chips, detail_text]:
				var child_control := child as Control
				if not detail_rect.encloses(child_control.get_global_rect()):
					return "%s: expected %s to stay inside CodexDetailPanel safe panel." % [context, str(child_control.name)]
			if center_texture.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or detail_texture.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				return "%s: expected SCRUM-850 Codex object art to use contained centered scaling." % context
			if detail_portrait.get_global_rect().size.x <= center_stage.get_global_rect().size.x:
				return "%s: expected SCRUM-850 right detail object stage to be wider than the center selected-object stage." % context
			# SCRUM-881 (директива юзера, суперсидит object-first пропорции SCRUM-850):
			# компактный центральный объект + досье ×2 по ширине.
			if detail_panel.get_global_rect().size.x < 1.8 * center_stage.get_global_rect().size.x:
				return "%s: expected SCRUM-881 dossier panel to be at least 1.8x wider than the compact center stage, got %.0f vs %.0f." % [context, detail_panel.get_global_rect().size.x, center_stage.get_global_rect().size.x]
			if center_stage.get_global_rect().size.y > maxf(0.35 * center_panel.get_global_rect().size.y, 165.0):
				return "%s: expected SCRUM-881 compact center object stage (<= ~35 percent of column height / 165px floor), got %.0f of %.0f." % [context, center_stage.get_global_rect().size.y, center_panel.get_global_rect().size.y]
			var center_summary_body := main.find_child("CodexCenterSummaryBody", true, false) as Label
			if center_summary_body == null or center_summary_body.max_lines_visible > 2 or center_summary_body.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
				return "%s: expected SCRUM-881 center summary body to stay very short (<= 2 lines with ellipsis)." % context
			var dossier_headings := main.find_children("CodexDetailSectionHeading_*", "Label", true, false)
			if dossier_headings.size() < 3:
				return "%s: expected SCRUM-881 structured dossier sections (>= 3) for the default entry, got %d." % [context, dossier_headings.size()]
		"attribute_shop_economy":
			var panel := main.find_child("AttributeShopPanel", true, false) as Control
			var skip_button := main.find_child("AttributeSkipButton", true, false) as Button
			if panel == null or not panel.get_global_rect().has_area():
				return "%s: expected visible AttributeShopPanel." % context
			# SCRUM-568: панель докачи рисуется собственной attr_panel @2K-рамкой.
			if _stylebox_texture_path(panel.get_theme_stylebox("panel")) != ATTR_PANEL_2K_FRAME_PATH:
				return "%s: expected AttributeShopPanel to use attr_panel @2K frame." % context
			if skip_button == null or skip_button.disabled:
				return "%s: expected AttributeSkipButton to remain reachable and enabled." % context
			for node in main.find_children("AttributeOffer_*", "Button", true, false):
				var offer := node as Button
				if offer == null:
					continue
				# SCRUM-568: карточки опций используют evt_card @2K-рамку (normal+hover).
				if _stylebox_texture_path(offer.get_theme_stylebox("normal")) != EVT_CARD_2K_FRAME_PATH:
					return "%s: expected %s normal StyleBox to use evt_card @2K frame." % [context, offer.name]
				if _stylebox_texture_path(offer.get_theme_stylebox("hover")) != EVT_CARD_2K_FRAME_PATH:
					return "%s: expected %s hover StyleBox to use evt_card @2K frame." % [context, offer.name]
				if not offer.disabled:
					return "%s: expected zero-money attribute offers to be disabled." % context
				if not offer.tooltip_text.contains("Недостаточно золота"):
					return "%s: expected disabled attribute offer tooltip to explain insufficient gold." % context
		"rest_economy":
			var rest_panel := main.find_child("MenuPanel_campfire", true, false) as Control
			if rest_panel == null or not rest_panel.visible or not rest_panel.get_global_rect().has_area():
				return "%s: expected visible Rest panel instead of an empty campfire shell." % context
			if rest_panel.find_child("UpgradeFabButton", true, false) != null:
				return "%s: Rest panel must not contain UpgradeFabButton; it hides title/body/choices in screenshots." % context
			var rest_content := main.find_child("RestContent", true, false) as Control
			if rest_content == null or not rest_content.visible or not rest_content.get_global_rect().has_area():
				return "%s: expected visible RestContent inside the campfire panel." % context
			var rest_panel_rect := rest_panel.get_global_rect().grow(-4.0)
			if not rest_panel_rect.encloses(rest_content.get_global_rect()):
				return "%s: expected RestContent to stay inside the campfire panel, got %s." % [context, str(rest_content.get_global_rect())]
			for label_name in ["RestTitle", "RestSubtitle"]:
				var label := main.find_child(label_name, true, false) as Label
				if label == null or not label.visible or label.text.strip_edges() == "" or not label.get_global_rect().has_area():
					return "%s: expected visible non-empty %s." % [context, label_name]
			for card_name in ["RestHealButton", "RestGuardButton"]:
				var card := main.find_child(card_name, true, false) as Button
				if card == null or not card.visible or card.text.strip_edges() != "":
					return "%s: expected visible textless economy card %s." % [context, card_name]
				var card_error := _economy_choice_card_contract_error(card, context)
				if card_error != "":
					return card_error
			var rest_back := main.find_child("RestBackButton", true, false) as Button
			if rest_back == null or not rest_back.visible or rest_back.text.strip_edges() == "" or not rest_back.get_global_rect().has_area():
				return "%s: expected visible non-empty RestBackButton." % context
		"patch_notes":
			# SCRUM-879: «Что нового» в едином атлас-стиле — тёмная кожаная панель
			# в safe-зоне, фон-хроника COVERED без растяжки осей, полая рама поверх.
			var pn_panel := main.find_child("PatchNotesPanel", true, false) as Control
			if pn_panel == null or not pn_panel.get_global_rect().has_area():
				return "%s: expected visible PatchNotesPanel." % context
			var pn_style := pn_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if pn_style == null or pn_style.bg_color.a < 0.8:
				return "%s: expected PatchNotesPanel to use a dark StyleBoxFlat chip (bg alpha >= 0.8)." % context
			var pn_bg := main.find_child("UnifiedBackground_patch_notes", true, false) as TextureRect
			if pn_bg == null or pn_bg.texture == null:
				return "%s: expected UnifiedBackground_patch_notes with a texture." % context
			if pn_bg.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED or pn_bg.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
				return "%s: expected patch notes background KEEP_ASPECT_COVERED without axis stretch." % context
			var pn_frame := main.find_child("PatchNotesFrame", true, false) as Panel
			if pn_frame == null:
				return "%s: expected PatchNotesFrame overlay." % context
			var pn_frame_style := pn_frame.get_theme_stylebox("panel") as StyleBoxTexture
			if pn_frame_style == null or pn_frame_style.draw_center or pn_frame_style.texture == null \
					or not str(pn_frame_style.texture.resource_path).ends_with("meta40/frame_border.png"):
				return "%s: expected PatchNotesFrame to draw the hollow meta40/frame_border 9-slice." % context
			var pn_vp: Vector2 = pn_frame.get_viewport().get_visible_rect().size
			var pn_margins := Vector2(roundf(160.0 * pn_vp.x / 1536.0), roundf(160.0 * pn_vp.y / 1024.0))
			var pn_safe := Rect2(pn_margins, pn_vp - pn_margins * 2.0)
			if not pn_safe.grow(2.0).encloses(pn_panel.get_global_rect()):
				return "%s: expected PatchNotesPanel %s inside frame safe rect %s." % [context, str(pn_panel.get_global_rect()), str(pn_safe)]
		"level_up":
			# SCRUM-883: оверлей на едином атлас-стиле — плотный чип StyleBoxFlat
			# поверх дима (полноэкранной рамы нет), карточки = чип-ряды с золотым
			# hover-кантом, «Позже» = глобальный кнопочный кит. Safe-ректы считаются
			# от фактических content margins чип-стилей.
			var level_panel := main.find_child("LevelUpPanel", true, false) as Control
			if level_panel == null or not level_panel.visible or not level_panel.get_global_rect().has_area():
				return "%s: expected visible LevelUpPanel." % context
			var level_style := level_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if level_style == null or level_style.bg_color.a < 0.9:
				return "%s: expected LevelUpPanel to use a dense StyleBoxFlat chip (bg alpha >= 0.9)." % context
			if str(level_panel.get_meta("level_up_slot", "")) != "level_up_panel":
				return "%s: expected LevelUpPanel slot metadata to be level_up_panel." % context
			var level_rect := level_panel.get_global_rect()
			var scaled_level_safe := Rect2(
				level_rect.position + Vector2(level_style.content_margin_left, level_style.content_margin_top),
				level_rect.size - Vector2(
					level_style.content_margin_left + level_style.content_margin_right,
					level_style.content_margin_top + level_style.content_margin_bottom
				)
			).grow(1.0)
			for child_name in ["LevelUpHeroHeader", "LevelUpTitle", "LevelUpSubtitle", "LevelUpRewardsRow", "LevelUpLaterButton"]:
				var child := main.find_child(child_name, true, false) as Control
				if child == null or not child.visible or not child.get_global_rect().has_area():
					return "%s: expected visible %s." % [context, child_name]
				if not scaled_level_safe.encloses(child.get_global_rect()):
					return "%s: expected %s to stay inside LevelUpPanel safe rect %s." % [context, child_name, str(scaled_level_safe)]
			var hero_frame := main.find_child("LevelUpHeroFrame", true, false) as Control
			if hero_frame == null or not (hero_frame.get_theme_stylebox("panel") is StyleBoxFlat):
				return "%s: expected LevelUpHeroFrame to use a translucent StyleBoxFlat portrait slot." % context
			var later_button := main.find_child("LevelUpLaterButton", true, false) as Button
			var later_path := _stylebox_texture_path(later_button.get_theme_stylebox("normal")) if later_button != null else ""
			if later_button == null or not (later_path.contains("text_buttons_unique/") or later_path.contains("minimal_metal_buttons/")):
				return "%s: expected LevelUpLaterButton to use the global button kit, got %s." % [context, later_path]
			for node in main.find_children("LevelUpRewardButton*", "Button", true, false):
				var reward_button := node as Button
				if reward_button == null:
					continue
				var card_normal := reward_button.get_theme_stylebox("normal") as StyleBoxFlat
				if card_normal == null or card_normal.bg_color.a < 0.8:
					return "%s: expected %s to use a dense StyleBoxFlat chip (bg alpha >= 0.8)." % [context, reward_button.name]
				var card_hover := reward_button.get_theme_stylebox("hover") as StyleBoxFlat
				if card_hover == null or card_hover.border_color.get_luminance() <= card_normal.border_color.get_luminance():
					return "%s: expected %s hover border to be brighter than normal (golden highlight)." % [context, reward_button.name]
				if str(reward_button.get_meta("level_up_card_slot", "")) != "level_up_card":
					return "%s: expected %s slot metadata to be level_up_card." % [context, reward_button.name]
				var card_rect := reward_button.get_global_rect()
				var scaled_card_safe := Rect2(
					card_rect.position + Vector2(card_normal.content_margin_left, card_normal.content_margin_top),
					card_rect.size - Vector2(
						card_normal.content_margin_left + card_normal.content_margin_right,
						card_normal.content_margin_top + card_normal.content_margin_bottom
					)
				).grow(1.0)
				var content := reward_button.find_child("LevelUpRewardContent", true, false) as Control
				if content == null or not scaled_card_safe.encloses(content.get_global_rect()):
					return "%s: expected %s content to stay inside card chip safe rect %s." % [context, reward_button.name, str(scaled_card_safe)]
				for child_name in ["LevelUpRewardDescription", "LevelUpRewardEffectPreview", "LevelUpRewardEffectText"]:
					var child := reward_button.find_child(child_name, true, false) as Control
					if child == null or not child.visible or not child.get_global_rect().has_area():
						return "%s: expected visible %s inside %s." % [context, child_name, reward_button.name]
					if not scaled_card_safe.encloses(child.get_global_rect()):
						return "%s: expected %s to stay inside card chip safe rect %s." % [context, child_name, str(scaled_card_safe)]
				var effect_panel := reward_button.find_child("LevelUpRewardEffectPreview", true, false) as PanelContainer
				if effect_panel == null or not (effect_panel.get_theme_stylebox("panel") is StyleBoxFlat):
					return "%s: expected %s effect preview field to use an atlas chip StyleBoxFlat." % [context, reward_button.name]
				var effect_text := reward_button.find_child("LevelUpRewardEffectText", true, false) as Label
				if effect_text == null or not effect_text.text.contains("->"):
					return "%s: expected %s visible effect preview to contain before/after delta, got %s." % [context, reward_button.name, effect_text.text if effect_text != null else ""]
		"event_economy":
			# SCRUM-565: панель события рисуется собственной evt_panel @2K-рамкой.
			var event_panel := main.find_child("MenuPanel_event", true, false) as Control
			if event_panel == null or not event_panel.visible or not event_panel.get_global_rect().has_area():
				return "%s: expected visible event panel instead of an empty event shell." % context
			if _stylebox_texture_path(event_panel.get_theme_stylebox("panel")) != EVT_PANEL_2K_FRAME_PATH:
				return "%s: expected event MenuPanel to use evt_panel @2K frame." % context
			if main.find_child("UpgradeFabButton", true, false) != null:
				return "%s: event screen must not render the disabled UpgradeFabButton inside MenuPanel_event." % context
			var event_safe := _scaled_source_rect(event_panel.get_global_rect(), Vector2(1720, 780), Rect2(58, 72, 1604, 642)).grow(1.0)
			var event_content := main.find_child("EventContent", true, false) as Control
			if event_content == null or not event_content.visible or not event_content.get_global_rect().has_area():
				return "%s: expected visible EventContent inside the event panel." % context
			if not event_safe.encloses(event_content.get_global_rect()):
				return "%s: expected EventContent to stay inside evt_panel safe rect %s, got %s." % [context, str(event_safe), str(event_content.get_global_rect())]
			var event_title := main.find_child("EventTitle", true, false) as Label
			var event_story := main.find_child("EventStory", true, false) as Label
			for label in [event_title, event_story]:
				if label == null or not label.visible or label.text.strip_edges() == "" or not label.get_global_rect().has_area():
					return "%s: expected event title/story labels to be visible and non-empty." % context
				if not event_safe.encloses(label.get_global_rect()):
					return "%s: expected %s to stay inside evt_panel safe rect %s." % [context, label.name, str(event_safe)]
			var visible_event_choices := 0
			for node in main.find_children("EventChoiceButton*", "Button", true, false):
				var event_button := node as Button
				if event_button == null:
					continue
				if event_button.visible and event_button.get_global_rect().has_area():
					visible_event_choices += 1
				# SCRUM-565: карточки выбора используют evt_card @2K-рамку (normal+hover).
				if _stylebox_texture_path(event_button.get_theme_stylebox("normal")) != EVT_CARD_2K_FRAME_PATH:
					return "%s: expected %s normal StyleBox to use evt_card @2K frame." % [context, event_button.name]
				if _stylebox_texture_path(event_button.get_theme_stylebox("hover")) != EVT_CARD_2K_FRAME_PATH:
					return "%s: expected %s hover StyleBox to use evt_card @2K frame." % [context, event_button.name]
				if event_button.tooltip_text.contains("Риск: Риск:"):
					return "%s: expected event option text to avoid duplicated risk prefix." % context
				if not event_safe.encloses(event_button.get_global_rect()):
					return "%s: expected %s to stay inside evt_panel safe rect %s." % [context, event_button.name, str(event_safe)]
				var desc := event_button.find_child("%sDescription" % event_button.name, true, false) as Label
				if desc != null and not event_button.get_global_rect().grow(1.0).encloses(desc.get_global_rect()):
					return "%s: event description %s escapes its card safe content rect." % [context, desc.name]
			if visible_event_choices < 2:
				return "%s: expected at least two visible event choices, got %d." % [context, visible_event_choices]
			var event_back := main.find_child("EventBackButton", true, false) as Button
			if event_back == null or not event_back.visible or event_back.text.strip_edges() == "" or not event_back.get_global_rect().has_area():
				return "%s: expected visible non-empty EventBackButton." % context
			if not event_safe.encloses(event_back.get_global_rect()):
				return "%s: expected EventBackButton to stay inside evt_panel safe rect %s." % [context, str(event_safe)]
		"level_up_toast":
			var toast_frame := main.find_child("LevelUpToastFrame", true, false) as PanelContainer
			if toast_frame == null or not toast_frame.visible or not toast_frame.get_global_rect().has_area():
				return "%s: expected visible LevelUpToastFrame." % context
			if _stylebox_texture_path(toast_frame.get_theme_stylebox("panel")) != LUT_TOAST_2K_FRAME_PATH:
				return "%s: expected LevelUpToastFrame to use lut_toast @2K frame." % context
			if Vector4(toast_frame.get_meta("toast_content_margins", Vector4.ZERO)) != Vector4(70, 112, 70, 112):
				return "%s: expected LevelUpToastFrame to expose strict SCRUM-588 content margins." % context
			var safe_rect: Rect2 = toast_frame.get_meta("toast_content_rect", Rect2()) as Rect2
			if not safe_rect.has_area():
				return "%s: expected LevelUpToastFrame to expose content safe rect metadata." % context
			var toast := main.find_child("LevelUpToast", true, false)
			if toast == null:
				return "%s: expected LevelUpToast node." % context
			var toast_label := toast.find_child("LevelUpToastLabel", true, false) as Label
			if toast_label == null or toast_label.text != "Level Up":
				return "%s: expected LevelUpToastLabel with Level Up text." % context
			if not safe_rect.grow(1.0).encloses(Rect2(toast_label.position, toast_label.size)):
				return "%s: expected LevelUpToastLabel to stay inside safe rect %s." % [context, str(safe_rect)]
			for node in toast.get_children():
				var sprite := node as Sprite2D
				if sprite != null and not safe_rect.grow(4.0).has_point(sprite.position):
					return "%s: toast sparkle %s starts outside safe rect %s." % [context, sprite.name, str(safe_rect)]
		"combat_title_banner":
			var banner := main.find_child("CombatIntroBanner", true, false) as PanelContainer
			if banner == null or not banner.visible or not banner.get_global_rect().has_area():
				return "%s: expected visible CombatIntroBanner frame." % context
			if _stylebox_texture_path(banner.get_theme_stylebox("panel")) != CTB_BIG_2K_FRAME_PATH:
				return "%s: expected CombatIntroBanner to use ctb_big @2K frame." % context
			if str(banner.get_meta("combat_title_slot", "")) != "ctb_big":
				return "%s: expected CombatIntroBanner slot metadata to be ctb_big." % context
			if Vector4(banner.get_meta("combat_title_content_margins", Vector4.ZERO)) != Vector4(86, 10, 86, 10):
				return "%s: expected CombatIntroBanner strict SCRUM-589 content margins." % context
			var banner_safe: Rect2 = banner.get_meta("combat_title_content_rect", Rect2()) as Rect2
			if banner_safe != Rect2(86, 10, 2188, 70):
				return "%s: expected CombatIntroBanner safe rect to match CTB_BIG_2K content zone." % context
			var banner_label := banner.find_child("CombatIntroBannerLabel", true, false) as Label
			if banner_label == null or banner_label.text.strip_edges() == "":
				return "%s: expected CombatIntroBannerLabel runtime text inside the frame." % context
			var scaled_safe := _scaled_source_rect(banner.get_global_rect(), Vector2(2360, 90), banner_safe).grow(1.0)
			if not scaled_safe.encloses(banner_label.get_global_rect()):
				return "%s: expected CombatIntroBannerLabel to stay inside scaled safe rect %s." % [context, str(scaled_safe)]
		"victory_banner":
			var frame := main.find_child("VictoryBannerFrame", true, false) as PanelContainer
			if frame == null or not frame.visible or not frame.get_global_rect().has_area():
				return "%s: expected visible VictoryBannerFrame." % context
			if _stylebox_texture_path(frame.get_theme_stylebox("panel")) != VBN_FRAME_2K_PATH:
				return "%s: expected VictoryBannerFrame to use vbn_frame @2K asset." % context
			if str(frame.get_meta("victory_banner_slot", "")) != "vbn_frame":
				return "%s: expected VictoryBannerFrame slot metadata to be vbn_frame." % context
			if Vector4(frame.get_meta("victory_banner_content_margins", Vector4.ZERO)) != Vector4(112, 52, 112, 52):
				return "%s: expected VictoryBannerFrame strict SCRUM-590 content margins." % context
			var frame_safe: Rect2 = frame.get_meta("victory_banner_content_rect", Rect2()) as Rect2
			if frame_safe != Rect2(112, 52, 1216, 136):
				return "%s: expected VictoryBannerFrame safe rect to match VBN_FRAME_2K content zone." % context
			var victory_label := frame.find_child("VictoryBannerLabel", true, false) as Label
			if victory_label == null or victory_label.text.strip_edges() == "":
				return "%s: expected VictoryBannerLabel runtime text inside the frame." % context
			var scaled_victory_safe := _scaled_source_rect(frame.get_global_rect(), Vector2(1440, 240), frame_safe).grow(1.0)
			if not scaled_victory_safe.encloses(victory_label.get_global_rect()):
				return "%s: expected VictoryBannerLabel to stay inside scaled safe rect %s." % [context, str(scaled_victory_safe)]
	return ""


func _requires_viewport_fit(screen_id: String) -> bool:
	return screen_id in ["level_up", "attribute_shop_economy", "rest_economy", "upgrade_economy", "event_economy", "combat_hud"]


func _economy_choice_card_contract_error(card: Button, context: String) -> String:
	if str(card.get_meta("economy_frame_path", "")) != ECONOMY_CHOICE_WIDE_PATH:
		return "%s: expected %s to use SCRUM-451 minimal-metal economy choice frame, got %s." % [context, card.name, str(card.get_meta("economy_frame_path", ""))]
	if str(card.get_meta("economy_hover_frame_path", "")) != ECONOMY_CHOICE_WIDE_HOVER_PATH:
		return "%s: expected %s hover to use SCRUM-451 minimal-metal hover frame." % [context, card.name]
	if _stylebox_texture_path(card.get_theme_stylebox("normal")) != ECONOMY_CHOICE_WIDE_PATH:
		return "%s: expected %s normal StyleBox to use minimal-metal economy choice frame." % [context, card.name]
	if _stylebox_texture_path(card.get_theme_stylebox("hover")) != ECONOMY_CHOICE_WIDE_HOVER_PATH:
		return "%s: expected %s hover StyleBox to use minimal-metal economy choice hover frame." % [context, card.name]
	var expected_min_width := 320.0 if context.contains("(1152, 648)") else 360.0
	if context.contains("(1920, 1080)"):
		expected_min_width = 420.0
	elif context.contains("(2560, 1440)"):
		expected_min_width = 480.0
	if card.custom_minimum_size.x < expected_min_width or card.custom_minimum_size.y < 240.0:
		return "%s: expected %s to use the SCRUM-451 minimal-metal card display target, got %s." % [context, card.name, str(card.custom_minimum_size)]
	var source_size: Vector2 = card.get_meta("economy_source_size", Vector2.ZERO)
	var source_safe: Rect2 = card.get_meta("economy_source_safe_rect", Rect2())
	if source_size != Vector2(426.0, 486.0) or source_safe != Rect2(46.0, 58.0, 334.0, 374.0):
		return "%s: expected %s to expose SCRUM-451 source size/safe rect metadata." % [context, card.name]
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
		var first_rect := _rect_with_tolerance(_effective_rect(first), tolerance_px)
		for second_index in range(first_index + 1, controls.size()):
			var second := controls[second_index] as Control
			if second == null:
				continue
			if _is_ancestor(first, second) or _is_ancestor(second, first):
				continue
			var second_rect := _rect_with_tolerance(_effective_rect(second), tolerance_px)
			if first_rect.intersects(second_rect):
				return "%s %s intersects %s %s" % [first.name, _effective_rect(first), second.name, _effective_rect(second)]
	return ""


# SCRUM-489: контрол внутри ScrollContainer визуально обрезается клип-прямоугольником скролла.
# Для проверки наслоений берём ВИДИМУЮ часть (пересечение с rect ближайшего ScrollContainer),
# иначе авто-центрированный длинный canvas карты маршрута (глоб. rect уходит выше вьюпорта)
# даёт ложное пересечение с хедером. Для контролов без скролл-предка — это no-op.
func _effective_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			rect = rect.intersection((ancestor as ScrollContainer).get_global_rect())
			break
		ancestor = ancestor.get_parent()
	return rect


func _append_text_overflow_errors(root_node: Node, context: String, errors: Array, dump_lines: PackedStringArray) -> void:
	var text_controls := _visible_text_controls(root_node)
	if text_controls.is_empty():
		return
	var checked_count := 0
	for control in text_controls:
		var text_control := control as Control
		if text_control == null:
			continue
		var error := _text_control_contract_error(text_control, context)
		if error != "":
			errors.append(error)
		checked_count += 1
	dump_lines.append("- text controls checked: `%d`" % checked_count)


func _visible_text_controls(root_node: Node) -> Array:
	var results := []
	for node in root_node.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not control.get_global_rect().has_area():
			continue
		if _control_text(control).strip_edges() == "":
			continue
		if control is Label or control is Button or control is RichTextLabel:
			results.append(control)
	return results


func _control_text(control: Control) -> String:
	if control is Label:
		return str((control as Label).text)
	if control is Button:
		return str((control as Button).text)
	if control is RichTextLabel:
		return str((control as RichTextLabel).text)
	return ""


func _text_control_contract_error(control: Control, context: String) -> String:
	var rect := control.get_global_rect()
	var parent_control := control.get_parent() as Control
	if parent_control != null and parent_control.is_visible_in_tree() and parent_control.get_global_rect().has_area():
		var parent_rect := parent_control.get_global_rect().grow(TEXT_OVERFLOW_TOLERANCE)
		if not parent_rect.encloses(rect):
			return "%s: text control %s rect %s escapes parent content rect %s." % [context, control.name, str(rect), str(parent_control.get_global_rect())]

	var needed := _text_control_needed_size(control)
	if needed.y > rect.size.y + TEXT_OVERFLOW_TOLERANCE:
		return "%s: text control %s needs height %.1f but has %.1f." % [context, control.name, needed.y, rect.size.y]
	if not _text_control_wraps(control) and needed.x > rect.size.x + TEXT_OVERFLOW_TOLERANCE:
		return "%s: text control %s needs width %.1f but has %.1f." % [context, control.name, needed.x, rect.size.x]
	return ""


func _text_control_needed_size(control: Control) -> Vector2:
	if control is Button:
		var button := control as Button
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		if font != null:
			var text_size := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			return text_size + Vector2(8.0, 8.0)
		return Vector2.ZERO
	if control is RichTextLabel:
		var rich := control as RichTextLabel
		return Vector2(maxf(rich.get_content_width(), rich.get_combined_minimum_size().x), maxf(rich.get_content_height(), rich.get_combined_minimum_size().y))
	return control.get_combined_minimum_size()


func _button_label_content_fit_error(button: Button, state: String, context: String) -> String:
	var style := button.get_theme_stylebox(state) as StyleBoxTexture
	if style == null:
		return "%s: expected %s %s style to be StyleBoxTexture." % [context, button.name, state]
	var rect := button.get_global_rect()
	var content_rect := Rect2(
		rect.position + Vector2(style.content_margin_left, style.content_margin_top),
		Vector2(
			maxf(0.0, rect.size.x - style.content_margin_left - style.content_margin_right),
			maxf(0.0, rect.size.y - style.content_margin_top - style.content_margin_bottom)
		)
	)
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	if font == null:
		return ""
	var text_size := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	if text_size.x > content_rect.size.x + TEXT_OVERFLOW_TOLERANCE:
		return "%s: expected %s label '%s' to fit %s content width %.1f, needs %.1f." % [context, button.name, button.text, state, content_rect.size.x, text_size.x]
	if text_size.y > content_rect.size.y + TEXT_OVERFLOW_TOLERANCE:
		return "%s: expected %s label '%s' to fit %s content height %.1f, needs %.1f." % [context, button.name, button.text, state, content_rect.size.y, text_size.y]
	return ""


func _text_control_wraps(control: Control) -> bool:
	if control is Label:
		return (control as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
	if control is RichTextLabel:
		return bool((control as RichTextLabel).fit_content)
	return false


func _vector2_approx(a: Vector2, b: Vector2, tolerance := 0.5) -> bool:
	return absf(a.x - b.x) <= tolerance and absf(a.y - b.y) <= tolerance


func _vector4_approx(a: Vector4, b: Vector4, tolerance := 0.5) -> bool:
	return absf(a.x - b.x) <= tolerance and absf(a.y - b.y) <= tolerance and absf(a.z - b.z) <= tolerance and absf(a.w - b.w) <= tolerance


func _rect2_approx(a: Rect2, b: Rect2, tolerance := 0.5) -> bool:
	return _vector2_approx(a.position, b.position, tolerance) and _vector2_approx(a.size, b.size, tolerance)


func _append_texture_stretch_errors(root_node: Node, context: String, errors: Array, dump_lines: PackedStringArray) -> void:
	var checked_count := 0
	for node in root_node.find_children("*", "TextureRect", true, false):
		var texture_rect := node as TextureRect
		if texture_rect == null or not texture_rect.is_visible_in_tree():
			continue
		var texture := texture_rect.texture
		if texture == null:
			continue
		var path := texture.resource_path
		if not _is_exact_frame_texture_path(path):
			continue
		checked_count += 1
		if texture_rect.stretch_mode == TextureRect.STRETCH_SCALE:
			errors.append("%s: exact UI frame TextureRect %s uses STRETCH_SCALE for %s." % [context, texture_rect.name, path])
	dump_lines.append("- exact frame TextureRects checked: `%d`" % checked_count)


func _is_exact_frame_texture_path(path: String) -> bool:
	if not path.begins_with(UI_FRAME_TEXTURE_PREFIX):
		return false
	# Decorative dividers are intentionally line-scaled; they are not content
	# containers and do not carry the no-stretch frame contract.
	if path.get_file().contains("divider"):
		return false
	return true


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


func _filter_dump_viewport_sections(lines: PackedStringArray, viewport_sizes: Array) -> PackedStringArray:
	var filtered := PackedStringArray()
	filtered.append("# SCRUM-483 UI Render Verifier Matrix")
	filtered.append("")
	filtered.append("Gate sizes: 1920x1080, 2560x1440, 3840x2160.")
	filtered.append("")
	var keep := false
	for line in lines:
		if line.begins_with("## "):
			keep = false
			for viewport_size in viewport_sizes:
				if line.contains(str(viewport_size)):
					keep = true
					break
		if keep:
			filtered.append(line)
	return filtered
