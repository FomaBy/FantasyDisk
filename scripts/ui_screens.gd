extends RefCounted

# Меню, настройки, выбор персонажа/оружия, магазин, события, отдых,
# level-up, победа/смерть, HUD и общие UI-стили.

var game

const HeroStatRadar := preload("res://scripts/ui/hero_stat_radar.gd")
const UIThemePaths := preload("res://scripts/ui/ui_theme_paths.gd")
const ShopUIConstants := preload("res://scripts/ui/shop_ui_constants.gd")
const HeroSelectConstants := preload("res://scripts/ui/hero_select_constants.gd")
const FEEDBACK_REPORTER_SCRIPT := preload("res://scripts/feedback_reporter.gd")

const ARTIFACT_ICON_DIR := ShopUIConstants.ARTIFACT_ICON_DIR
const SHOP_ICON_DIR := ShopUIConstants.SHOP_ICON_DIR
const SHOP_SLOT_FRAME_PATH := ShopUIConstants.SHOP_SLOT_FRAME_PATH
const SHOP_SLOT_HOVER_PATH := ShopUIConstants.SHOP_SLOT_HOVER_PATH
const SHOP_PRICE_BADGE_PATH := ShopUIConstants.SHOP_PRICE_BADGE_PATH
const SHOP_PURCHASED_OVERLAY_PATH := ShopUIConstants.SHOP_PURCHASED_OVERLAY_PATH
const SHOP_TOOLTIP_FRAME_PATH := ShopUIConstants.SHOP_TOOLTIP_FRAME_PATH
const DF_FRAME_DIR := UIThemePaths.DF_FRAME_DIR
const RED_GOLD_BUTTON_DIR := UIThemePaths.RED_GOLD_BUTTON_DIR
const GLOBAL_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_PANEL_FRAME_PATH
const GLOBAL_BUTTON_FRAME_PATH := UIThemePaths.GLOBAL_BUTTON_FRAME_PATH
const GLOBAL_CARD_FRAME_PATH := UIThemePaths.GLOBAL_CARD_FRAME_PATH
const GLOBAL_HERO_CARD_FRAME_PATH := UIThemePaths.GLOBAL_HERO_CARD_FRAME_PATH
const GLOBAL_CARD_HOVER_FRAME_PATH := UIThemePaths.GLOBAL_CARD_HOVER_FRAME_PATH
const GLOBAL_LEVEL_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_LEVEL_PANEL_FRAME_PATH
const GLOBAL_HUD_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_HUD_PANEL_FRAME_PATH
const GLOBAL_HUD_CARD_FRAME_PATH := UIThemePaths.GLOBAL_HUD_CARD_FRAME_PATH
const GLOBAL_TOOLTIP_FRAME_PATH := UIThemePaths.GLOBAL_TOOLTIP_FRAME_PATH
const GLOBAL_TIMER_PANEL_FRAME_PATH := UIThemePaths.GLOBAL_TIMER_PANEL_FRAME_PATH
const UNIFIED_MASTER_FILL_FRAME_PATH := UIThemePaths.UNIFIED_MASTER_FILL_FRAME_PATH
const UNIFIED_FRAME_TEXTURE_MARGINS := UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS
const UNIFIED_FRAME_CONTENT := UIThemePaths.UNIFIED_FRAME_CONTENT
const ORNATE_FRAME_MARGINS := UIThemePaths.ORNATE_FRAME_MARGINS
const ORNATE_FRAME_CONTENT := UIThemePaths.ORNATE_FRAME_CONTENT
const RED_GOLD_BUTTON_TEXTURES := UIThemePaths.RED_GOLD_BUTTON_TEXTURES
const RED_GOLD_BUTTON_MARGINS := UIThemePaths.RED_GOLD_BUTTON_MARGINS
const RED_GOLD_BUTTON_CONTENT := UIThemePaths.RED_GOLD_BUTTON_CONTENT
const GLOSSARY := preload("res://scripts/glossary.gd")
const SYSTEM_CHECKBOX_UNCHECKED_PATH := "res://assets/sprites/ui/icons/system/ui_checkbox_unchecked.png"
const SYSTEM_CHECKBOX_CHECKED_PATH := "res://assets/sprites/ui/icons/system/ui_checkbox_checked.png"
const SYSTEM_SLIDER_TRACK_PATH := "res://assets/sprites/ui/icons/system/ui_slider_track.png"
const SYSTEM_SLIDER_GRABBER_PATH := "res://assets/sprites/ui/icons/system/ui_slider_grabber.png"
const SHOP_INLINE_SLOT_SIZE := ShopUIConstants.SHOP_INLINE_SLOT_SIZE
const SHOP_INLINE_ICON_SIZE := ShopUIConstants.SHOP_INLINE_ICON_SIZE
const SHOP_CURSOR_VARIANTS := ShopUIConstants.SHOP_CURSOR_VARIANTS
const HERO_RADAR_STATS := HeroSelectConstants.HERO_RADAR_STATS
const HERO_CLASS_COLORS := HeroSelectConstants.HERO_CLASS_COLORS
const STANDARD_ACTION_BUTTON_HEIGHT := 104.0
const STANDARD_ACTION_BUTTON_WIDTH := 420.0
const MAX_ACTION_BUTTON_VISUAL_WIDTH := 560.0
const MAIN_MENU_ACTION_BUTTON_WIDTH := 380.0
const COMPACT_UTILITY_BUTTON_SIZE := Vector2(54.0, 42.0)
const ASCENSION_BUTTON_SIZE := Vector2(54.0, 62.0)
const BUTTON_NEUTRAL_HOVER_TINT := Color(1.16, 1.16, 1.16, 1.0)
const BUTTON_NEUTRAL_FOCUS_TINT := Color(1.20, 1.20, 1.20, 1.0)
const BUTTON_NEUTRAL_HOVER_FONT := Color(1.0, 1.0, 1.0, 1.0)
const HERO_SELECT_UNIFIED_FRAME_SOURCE_SIZE := Vector2(1536.0, 1024.0)
const HERO_SELECT_UNIFIED_PORTRAIT_RECT := Rect2(130.0, 145.0, 420.0, 560.0)
const HERO_SELECT_UNIFIED_DESCRIPTION_RECT := Rect2(610.0, 145.0, 786.0, 500.0)
const HERO_SELECT_UNIFIED_BOTTOM_CONTROLS_RECT := Rect2(570.0, 705.0, 660.0, 178.0)
const HERO_SELECT_ASC_BUTTON_SMALL_SOURCE_SIZE := Vector2(256.0, 256.0)
const HERO_SELECT_ASC_BUTTON_SMALL_CONTENT_BASE := Vector4(76.0, 74.0, 76.0, 76.0)
const HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE := Vector2(734.0, 1162.0)
const HERO_SELECT_PORTRAIT_CONTENT_BASE := Vector4(128.0, 230.0, 128.0, 330.0)
const HERO_SELECT_RADAR_FRAME_SOURCE_SIZE := Vector2(1024.0, 1024.0)
const HERO_SELECT_RADAR_FRAME_BASE_SIZE := Vector2(390.0, 390.0)
const HERO_SELECT_RADAR_CONTENT_BASE := Vector4(245.0, 245.0, 245.0, 235.0)
const HERO_SELECT_RADAR_GRAPH_BASE_SIZE := Vector2(200.0, 150.0)
const HERO_SELECT_DOSSIER_FRAME_SOURCE_SIZE := Vector2(1120.0, 1140.0)
const HERO_SELECT_DOSSIER_FRAME_BASE_SIZE := Vector2(387.0, 394.0)
const HERO_SELECT_DOSSIER_CONTENT_BASE := Vector4(126.0, 160.0, 126.0, 172.0)
const HERO_SELECT_CAROUSEL_FRAME_SOURCE_SIZE := Vector2(1536.0, 255.0)
const HERO_SELECT_CAROUSEL_FRAME_BASE_SIZE := Vector2(1024.0, 170.0)
const HERO_SELECT_CAROUSEL_CONTENT_BASE := Vector4(132.0, 62.0, 132.0, 62.0)
const HERO_SELECT_CAROUSEL_THUMBNAIL_SEPARATION := 2
const HERO_SELECT_FRAME_DIR := "res://assets/sprites/ui/frames/hero_select/"
const SETTINGS_TAB_SWITCHER_FRAME_PATH := "res://assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png"
const SETTINGS_TAB_SWITCHER_BASE_SIZE := Vector2(1280.0, 256.0)
const SETTINGS_TAB_SWITCHER_DISPLAY_SIZE := Vector2(640.0, 128.0)
const SETTINGS_TAB_SWITCHER_SAFE_RECTS := [
	Rect2(160.0, 88.0, 270.0, 82.0),
	Rect2(506.0, 88.0, 270.0, 82.0),
	Rect2(852.0, 88.0, 270.0, 82.0),
]
const HERO_SELECT_FRAME_TEXTURES := {
	"unified_panel": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_unified_panel.png",
	"portrait": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_portrait.png",
	"dossier": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_dossier.png",
	"radar": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_radar.png",
	"thumbnail_strip": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_thumbnail_strip.png",
	"thumbnail": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_thumbnail.png",
	"asc_button": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_asc_button.png",
	"asc_button_small": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_asc_button_small.png",
	"asc_label": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_asc_label.png",
	"asc_mods": HERO_SELECT_FRAME_DIR + "ui_frame_hero_select_asc_mods.png",
}
const HERO_SELECT_FRAME_MARGINS := {
	"unified_panel": Vector4(112, 110, 112, 104),
	"portrait": Vector4(72, 86, 72, 92),
	"dossier": Vector4(92, 86, 92, 90),
	"radar": Vector4(88, 88, 88, 88),
	"thumbnail_strip": Vector4(112, 48, 112, 52),
	"thumbnail": Vector4(78, 72, 78, 76),
	"asc_button": Vector4(58, 58, 58, 62),
	"asc_button_small": HERO_SELECT_ASC_BUTTON_SMALL_CONTENT_BASE,
	"asc_label": Vector4(86, 36, 86, 38),
	"asc_mods": Vector4(96, 30, 96, 32),
}
const HERO_SELECT_FRAME_CONTENT := {
	"unified_panel": Vector4(0, 0, 0, 0),
	"portrait": Vector4(38, 42, 38, 44),
	"dossier": Vector4(28, 18, 32, 18),
	"radar": Vector4(12, 12, 12, 12),
	"thumbnail_strip": Vector4(72, 36, 72, 36),
	"thumbnail": Vector4(14, 12, 14, 12),
	"asc_button": Vector4(14, 12, 14, 14),
	"asc_button_small": Vector4(6, 4, 6, 5),
	"asc_label": Vector4(24, 8, 24, 8),
	"asc_mods": Vector4(28, 6, 28, 6),
}

func _init(game_ref) -> void:
	game = game_ref


func _show_main_menu() -> void:
	game._play_music("menu")
	game._clear_all_game_pauses()
	game.pending_rebind_action = ""
	game._clear_world()
	game._clear_hud()
	game._clear_ui()
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.pending_level_ups = 0
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.route_nodes = game.route._generate_route()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "MainMenuScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)

	var background := TextureRect.new()
	background.name = "MainMenuBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = game._cached_texture(game.MAIN_MENU_BACKGROUND)
	root.add_child(background)

	var global_shade := ColorRect.new()
	global_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	global_shade.color = Color(0.02, 0.02, 0.04, 0.18)
	root.add_child(global_shade)

	var layout := MarginContainer.new()
	layout.anchor_left = 0.0
	layout.anchor_top = 0.0
	layout.anchor_right = 0.0
	layout.anchor_bottom = 1.0
	layout.offset_left = 72.0
	layout.offset_top = 0.0
	layout.offset_right = 452.0
	layout.offset_bottom = 0.0
	layout.add_theme_constant_override("margin_left", 0)
	layout.add_theme_constant_override("margin_top", 0)
	layout.add_theme_constant_override("margin_right", 0)
	layout.add_theme_constant_override("margin_bottom", 0)
	root.add_child(layout)

	var action_box := VBoxContainer.new()
	action_box.name = "MainMenuActions"
	action_box.custom_minimum_size = Vector2(380, 0)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 10)
	layout.add_child(action_box)

	var start_button := _make_button("Начать новую игру")
	start_button.name = "MainMenuStartButton"
	_set_action_button_size(start_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	start_button.pressed.connect(func() -> void:
		if game.run_autosave_has_run():
			_show_continue_run_dialog()
		else:
			_show_character_select()
	)
	action_box.add_child(start_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "MainMenuSettingsButton"
	_set_action_button_size(settings_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	settings_button.pressed.connect(_show_settings_menu)
	action_box.add_child(settings_button)

	var version_label := Label.new()
	version_label.name = "MainMenuVersionLabel"
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -120.0
	version_label.offset_top = -34.0
	version_label.offset_right = -16.0
	version_label.offset_bottom = -10.0
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72, 0.85))
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(version_label)

	var skill_tree_button := _make_button("Древо умений")
	skill_tree_button.name = "MainMenuSkillTreeButton"
	_set_action_button_size(skill_tree_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	skill_tree_button.pressed.connect(_show_skill_tree_screen)
	action_box.add_child(skill_tree_button)

	# SCRUM-159: «Что нового» с бейджем непросмотренной версии (не модалка).
	var patch_notes_data := preload("res://scripts/patch_notes_data.gd")
	var settings_module := preload("res://scripts/game_settings.gd")
	var last_seen: String = str(settings_module.load_settings().get("last_seen_version", "0.0.0"))
	var patch_notes_button := _make_button("Что нового  ●" if patch_notes_data.has_new_since(last_seen) else "Что нового")
	patch_notes_button.name = "MainMenuPatchNotesButton"
	_set_action_button_size(patch_notes_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	patch_notes_button.pressed.connect(func() -> void:
		# Просмотр отмечает актуальную версию как увиденную — бейдж гаснет.
		var saved: Dictionary = settings_module.load_settings()
		saved["last_seen_version"] = patch_notes_data.latest_version()
		settings_module.save_settings(saved)
		_show_patch_notes_screen()
	)
	action_box.add_child(patch_notes_button)

	var codex_button := _make_button("Кодекс")
	codex_button.name = "MainMenuCodexButton"
	_set_action_button_size(codex_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	codex_button.pressed.connect(_show_codex_screen)
	action_box.add_child(codex_button)

	var exit_button := _make_button("Выйти из игры")
	exit_button.name = "MainMenuExitButton"
	_set_action_button_size(exit_button, MAIN_MENU_ACTION_BUTTON_WIDTH)
	exit_button.pressed.connect(_show_quit_confirmation_dialog)
	action_box.add_child(exit_button)
	game.ui_escape_action = _show_quit_confirmation_dialog


func _show_quit_confirmation_dialog() -> void:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return
	if game.ui_layer.find_child("QuitConfirmationDialog", true, false) != null:
		var existing_cancel := game.ui_layer.find_child("QuitConfirmCancelButton", true, false) as Button
		if existing_cancel != null:
			existing_cancel.grab_focus()
		return

	var overlay := Control.new()
	overlay.name = "QuitConfirmationDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 500
	game.ui_layer.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "QuitConfirmationDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.70)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "QuitConfirmationPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -170.0
	panel.offset_right = 300.0
	panel.offset_bottom = 170.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "QuitConfirmationTitle"
	title_label.text = "Выйти из игры?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "QuitConfirmationSubtitle"
	subtitle_label.text = "Несохраненный забег будет завершен. Продолжить выход?"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "QuitConfirmationButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, 72.0)
	button_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var confirm_button := _make_button("Выйти")
	confirm_button.name = "QuitConfirmExitButton"
	_set_action_button_size(confirm_button, 220.0, 72.0)
	confirm_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_button.pressed.connect(func() -> void:
		if game.has_method("request_game_quit"):
			game.request_game_quit()
		else:
			game.get_tree().quit()
	)
	button_row.add_child(confirm_button)

	var cancel_button := _make_button("Отмена")
	cancel_button.name = "QuitConfirmCancelButton"
	_set_action_button_size(cancel_button, 220.0, 72.0)
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_button.pressed.connect(_cancel_quit_confirmation_dialog)
	button_row.add_child(cancel_button)

	confirm_button.focus_neighbor_right = cancel_button.get_path()
	confirm_button.focus_neighbor_left = cancel_button.get_path()
	cancel_button.focus_neighbor_left = confirm_button.get_path()
	cancel_button.focus_neighbor_right = confirm_button.get_path()
	cancel_button.grab_focus()

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not panel.get_global_rect().has_point((event as InputEventMouseButton).global_position):
				_cancel_quit_confirmation_dialog()
	)
	game.ui_escape_action = _cancel_quit_confirmation_dialog


func _cancel_quit_confirmation_dialog() -> void:
	if game.ui_layer != null and is_instance_valid(game.ui_layer):
		var overlay: Node = game.ui_layer.find_child("QuitConfirmationDialog", true, false)
		if overlay != null:
			overlay.queue_free()
	game.ui_escape_action = _show_quit_confirmation_dialog


func _show_continue_run_dialog() -> void:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return
	if game.ui_layer.find_child("ContinueRunDialog", true, false) != null:
		var existing_continue := game.ui_layer.find_child("ContinueRunButton", true, false) as Button
		if existing_continue != null:
			existing_continue.grab_focus()
		return

	var autosave_state: Dictionary = game.RUN_AUTOSAVE.load_run()
	if autosave_state.is_empty():
		_show_character_select()
		return

	var overlay := Control.new()
	overlay.name = "ContinueRunDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 520
	game.ui_layer.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "ContinueRunDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "ContinueRunPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_top = -190.0
	panel.offset_right = 340.0
	panel.offset_bottom = 190.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.name = "ContinueRunTitle"
	title_label.text = "Продолжить забег?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title_label)

	var character_id := str(autosave_state.get("selected_character_id", "berserk"))
	var character_config: Dictionary = game.PROGRESSION_DATA.character_config(character_id)
	var character_title := str(character_config.get("title", character_id))
	var route_stage := int(autosave_state.get("route_stage", 0)) + 1
	var snapshot: Dictionary = {}
	if autosave_state.get("run_player_snapshot", {}) is Dictionary:
		snapshot = (autosave_state.get("run_player_snapshot", {}) as Dictionary)
	var money := int(snapshot.get("money", 0))
	var level := int(snapshot.get("level", 1))
	var subtitle_label := Label.new()
	subtitle_label.name = "ContinueRunSubtitle"
	subtitle_label.text = "%s · этап %d · уровень %d · золото %d\nМожно вернуться на карту или начать новый забег." % [character_title, route_stage, level, money]
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.name = "ContinueRunButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, 76.0)
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var continue_button := _make_button("Продолжить")
	continue_button.name = "ContinueRunButton"
	_set_action_button_size(continue_button, 240.0, 72.0)
	continue_button.pressed.connect(func() -> void:
		if game.load_run_autosave():
			game.route._show_battle_map()
		else:
			_show_character_select()
	)
	button_row.add_child(continue_button)

	var new_game_button := _make_button("Новая игра")
	new_game_button.name = "ContinueRunNewGameButton"
	_set_action_button_size(new_game_button, 240.0, 72.0)
	new_game_button.pressed.connect(func() -> void:
		game.clear_run_autosave()
		_show_character_select()
	)
	button_row.add_child(new_game_button)

	continue_button.focus_neighbor_right = new_game_button.get_path()
	continue_button.focus_neighbor_left = new_game_button.get_path()
	new_game_button.focus_neighbor_left = continue_button.get_path()
	new_game_button.focus_neighbor_right = continue_button.get_path()
	continue_button.grab_focus()
	game.ui_escape_action = func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		game.ui_escape_action = _show_quit_confirmation_dialog


func _show_character_select() -> void:
	game.clear_run_autosave()
	game.run_player_snapshot.clear()
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.shop_reentry_pending = false
	game.shop_reentry_route_stage = -1
	game.shop_reentry_branch_index = -1
	game.route_nodes = game.route._generate_route()
	_clear_current_shop_stock()
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "HeroSelectScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)

	_add_screen_background(root, "hero_select")

	var margins := MarginContainer.new()
	margins.name = "HeroSelectMargins"
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 24)
	margins.add_theme_constant_override("margin_top", 16)
	margins.add_theme_constant_override("margin_right", 24)
	margins.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margins)

	var layout := VBoxContainer.new()
	layout.name = "HeroSelectLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	margins.add_child(layout)

	var header := HBoxContainer.new()
	header.name = "HeroSelectHeader"
	header.custom_minimum_size = Vector2(0, 50)
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.clip_contents = true
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)

	var title_label := Label.new()
	title_label.text = "Выбор героя"
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	title_box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Выберите героя и уровень Возвышения."
	subtitle_label.clip_text = true
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 0.92))
	title_box.add_child(subtitle_label)

	var back_button := _make_button("Назад")
	back_button.name = "HeroSelectBackButton"
	_set_action_button_size(back_button, 240.0)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)

	var content_row := HBoxContainer.new()
	content_row.name = "HeroSelectContent"
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	layout.add_child(content_row)

	var unified_panel := CenterContainer.new()
	unified_panel.name = "HeroSelectUnifiedPanel"
	unified_panel.custom_minimum_size = _hero_select_unified_frame_size()
	unified_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unified_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unified_panel.size_flags_stretch_ratio = 1.0
	unified_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(unified_panel)

	var unified_frame := Control.new()
	unified_frame.name = "HeroSelectUnifiedFrame"
	unified_frame.custom_minimum_size = _hero_select_unified_frame_size()
	unified_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	unified_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	unified_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unified_panel.add_child(unified_frame)

	var unified_frame_art := TextureRect.new()
	unified_frame_art.name = "HeroSelectUnifiedFrameArt"
	unified_frame_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	unified_frame_art.texture = game._cached_texture(HERO_SELECT_FRAME_TEXTURES["unified_panel"])
	unified_frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unified_frame_art.stretch_mode = TextureRect.STRETCH_SCALE
	unified_frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unified_frame.add_child(unified_frame_art)

	var portrait_safe_rect := _hero_select_unified_scaled_rect(HERO_SELECT_UNIFIED_PORTRAIT_RECT)
	var portrait_panel := Control.new()
	portrait_panel.name = "HeroSelectPortraitPanel"
	portrait_panel.position = portrait_safe_rect.position
	portrait_panel.size = portrait_safe_rect.size
	portrait_panel.custom_minimum_size = portrait_safe_rect.size
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unified_frame.add_child(portrait_panel)

	var portrait_frame := Control.new()
	portrait_frame.name = "HeroSelectPortraitFrame"
	portrait_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait_frame)

	var portrait_content := MarginContainer.new()
	portrait_content.name = "HeroSelectPortraitContent"
	portrait_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Инсет контента внутрь рамки портрета (доли реальной прозрачной зоны рамки),
	# чтобы спрайт героя не налезал на орнамент. SCRUM-336/hero-select.
	portrait_content.add_theme_constant_override("margin_left", int(round(portrait_safe_rect.size.x * 0.11)))
	portrait_content.add_theme_constant_override("margin_top", int(round(portrait_safe_rect.size.y * 0.18)))
	portrait_content.add_theme_constant_override("margin_right", int(round(portrait_safe_rect.size.x * 0.11)))
	portrait_content.add_theme_constant_override("margin_bottom", int(round(portrait_safe_rect.size.y * 0.13)))
	portrait_frame.add_child(portrait_content)

	var portrait_box := VBoxContainer.new()
	portrait_box.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_box.add_theme_constant_override("separation", 6)
	portrait_content.add_child(portrait_box)

	var large_portrait := TextureRect.new()
	large_portrait.name = "HeroSelectLargePortrait"
	large_portrait.custom_minimum_size = Vector2(0, 0)
	large_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	large_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	large_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	large_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	large_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(large_portrait)
	# Имя героя теперь ТОЛЬКО в досье (HeroSelectInfoTitle) — подпись под портретом убрана.

	var right_region := Control.new()
	right_region.name = "HeroSelectRightRegion"
	right_region.custom_minimum_size = Vector2(_hero_select_radar_frame_size().x + 18.0, _hero_select_radar_frame_size().y)
	right_region.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_region.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(right_region)

	var dossier_safe_rect := _hero_select_unified_scaled_rect(HERO_SELECT_UNIFIED_DESCRIPTION_RECT)
	var dossier_panel := Control.new()
	dossier_panel.name = "HeroSelectDossierPanel"
	dossier_panel.position = dossier_safe_rect.position
	dossier_panel.size = dossier_safe_rect.size
	dossier_panel.custom_minimum_size = dossier_safe_rect.size
	dossier_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unified_frame.add_child(dossier_panel)

	var dossier_frame := Control.new()
	dossier_frame.name = "HeroSelectDossierFrame"
	dossier_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	dossier_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dossier_panel.add_child(dossier_frame)

	var dossier_content := MarginContainer.new()
	dossier_content.name = "HeroSelectDossierContent"
	dossier_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	dossier_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Инсет контента внутрь рамки досье, чтобы текст/возвышение не налезали на орнамент.
	dossier_content.add_theme_constant_override("margin_left", int(round(dossier_safe_rect.size.x * 0.085)))
	dossier_content.add_theme_constant_override("margin_top", int(round(dossier_safe_rect.size.y * 0.15)))
	dossier_content.add_theme_constant_override("margin_right", int(round(dossier_safe_rect.size.x * 0.085)))
	dossier_content.add_theme_constant_override("margin_bottom", int(round(dossier_safe_rect.size.y * 0.12)))
	dossier_frame.add_child(dossier_content)

	var dossier := VBoxContainer.new()
	dossier.name = "HeroSelectDossier"
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.add_theme_constant_override("separation", 2)
	dossier_content.add_child(dossier)

	var dossier_title := Label.new()
	dossier_title.name = "HeroSelectInfoTitle"
	dossier_title.add_theme_font_size_override("font_size", 22)
	dossier_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38, 1.0))
	dossier.add_child(dossier_title)

	var dossier_desc := Label.new()
	dossier_desc.name = "HeroSelectInfoDescription"
	dossier_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dossier_desc.max_lines_visible = 3
	dossier_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dossier_desc.add_theme_font_size_override("font_size", 12)
	dossier_desc.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	dossier.add_child(dossier_desc)

	var dossier_traits := Label.new()
	dossier_traits.name = "HeroSelectTraits"
	dossier_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dossier_traits.max_lines_visible = 2
	dossier_traits.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dossier_traits.add_theme_font_size_override("font_size", 11)
	dossier_traits.add_theme_color_override("font_color", Color(0.80, 0.92, 0.86, 1.0))
	dossier.add_child(dossier_traits)

	var weapons_label := Label.new()
	weapons_label.name = "HeroSelectWeapons"
	weapons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapons_label.max_lines_visible = 2
	weapons_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weapons_label.add_theme_font_size_override("font_size", 11)
	weapons_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 1.0))
	dossier.add_child(weapons_label)

	var bottom_safe_rect := _hero_select_unified_scaled_rect(HERO_SELECT_UNIFIED_BOTTOM_CONTROLS_RECT)
	var bottom_controls := VBoxContainer.new()
	bottom_controls.name = "HeroSelectBottomControls"
	bottom_controls.position = bottom_safe_rect.position
	bottom_controls.size = bottom_safe_rect.size
	bottom_controls.custom_minimum_size = bottom_safe_rect.size
	bottom_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_controls.add_theme_constant_override("separation", 1)
	unified_frame.add_child(bottom_controls)

	var asc_row := HBoxContainer.new()
	asc_row.name = "AscensionSelectorRow"
	asc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	asc_row.add_theme_constant_override("separation", 6)
	bottom_controls.add_child(asc_row)
	var asc_minus := _make_compact_button("-")
	asc_minus.name = "AscensionMinusButton"
	asc_minus.custom_minimum_size = _hero_select_asc_small_button_size()
	_apply_hero_select_button_frame(asc_minus, "asc_button_small")
	asc_row.add_child(asc_minus)
	var asc_label := Label.new()
	asc_label.name = "AscensionLevelLabel"
	asc_label.custom_minimum_size = Vector2(round(220.0 * _hero_select_unified_scale()), maxf(_hero_select_asc_small_button_size().y * 0.72, 20.0))
	asc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_label.add_theme_font_size_override("font_size", 13)
	asc_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32, 1.0))
	asc_label.add_theme_stylebox_override("normal", _hero_select_frame_style("asc_label"))
	asc_row.add_child(asc_label)
	var asc_plus := _make_compact_button("+")
	asc_plus.name = "AscensionPlusButton"
	asc_plus.custom_minimum_size = _hero_select_asc_small_button_size()
	_apply_hero_select_button_frame(asc_plus, "asc_button_small")
	asc_row.add_child(asc_plus)
	var asc_mods := Label.new()
	asc_mods.name = "AscensionModsLabel"
	asc_mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asc_mods.max_lines_visible = 1
	asc_mods.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	asc_mods.add_theme_font_size_override("font_size", 10)
	asc_mods.add_theme_color_override("font_color", Color(0.95, 0.62, 0.55, 0.95))
	asc_mods.custom_minimum_size = Vector2(bottom_safe_rect.size.x * 0.76, clampf(bottom_safe_rect.size.y * 0.18, 12.0, 22.0))
	asc_mods.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_mods.visible = _hero_select_unified_scale() >= 0.52
	asc_mods.add_theme_stylebox_override("normal", _hero_select_frame_style("asc_mods"))
	bottom_controls.add_child(asc_mods)

	var select_button := _make_button("Выбрать")
	select_button.name = "HeroSelectChooseButton"
	var choose_height := clampf(bottom_safe_rect.size.y * 0.36, 24.0, 54.0)
	_set_action_button_size(select_button, clampf(bottom_safe_rect.size.x * 0.62, 124.0, 260.0), choose_height)
	select_button.add_theme_stylebox_override("normal", _hero_select_compact_choice_style(false, false))
	select_button.add_theme_stylebox_override("hover", _hero_select_compact_choice_style(true, false))
	select_button.add_theme_stylebox_override("pressed", _hero_select_compact_choice_style(true, true))
	select_button.add_theme_stylebox_override("focus", _hero_select_compact_choice_style(true, false))
	select_button.add_theme_font_size_override("font_size", 11 if _hero_select_unified_scale() < 0.52 else 13)
	select_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_controls.add_child(select_button)

	var radar_frame_size := _hero_select_radar_frame_size()

	var radar_panel := Control.new()
	radar_panel.name = "HeroSelectRadarPanel"
	radar_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar_panel.offset_left = -24.0 - radar_frame_size.x
	radar_panel.offset_top = 132
	radar_panel.offset_right = -24
	radar_panel.offset_bottom = 132.0 + radar_frame_size.y
	radar_panel.custom_minimum_size = radar_frame_size
	radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar_panel)

	var radar_frame_art := TextureRect.new()
	radar_frame_art.name = "HeroSelectRadarFrameArt"
	radar_frame_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	radar_frame_art.texture = game._cached_texture(HERO_SELECT_FRAME_TEXTURES["radar"])
	radar_frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	radar_frame_art.stretch_mode = TextureRect.STRETCH_SCALE
	radar_frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_panel.add_child(radar_frame_art)

	var radar_content := MarginContainer.new()
	radar_content.name = "HeroSelectRadarContent"
	radar_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	radar_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var radar_source_scale := radar_frame_size.x / HERO_SELECT_RADAR_FRAME_SOURCE_SIZE.x
	radar_content.add_theme_constant_override("margin_left", int(round(HERO_SELECT_RADAR_CONTENT_BASE.x * radar_source_scale)))
	radar_content.add_theme_constant_override("margin_top", int(round(HERO_SELECT_RADAR_CONTENT_BASE.y * radar_source_scale)))
	radar_content.add_theme_constant_override("margin_right", int(round(HERO_SELECT_RADAR_CONTENT_BASE.z * radar_source_scale)))
	radar_content.add_theme_constant_override("margin_bottom", int(round(HERO_SELECT_RADAR_CONTENT_BASE.w * radar_source_scale)))
	radar_panel.add_child(radar_content)

	var radar_box := VBoxContainer.new()
	radar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	radar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	radar_box.add_theme_constant_override("separation", 6)
	radar_content.add_child(radar_box)

	var radar := HeroStatRadar.new()
	radar.name = "HeroStatRadar"
	radar.custom_minimum_size = _hero_select_radar_graph_size()
	radar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	radar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	radar_box.add_child(radar)

	var thumbnail_strip_frame := Control.new()
	thumbnail_strip_frame.name = "HeroThumbnailStripFrame"
	thumbnail_strip_frame.custom_minimum_size = _hero_select_carousel_frame_size()
	thumbnail_strip_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumbnail_strip_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(thumbnail_strip_frame)

	var thumbnail_strip_art := TextureRect.new()
	thumbnail_strip_art.name = "HeroThumbnailStripFrameArt"
	thumbnail_strip_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumbnail_strip_art.texture = game._cached_texture(HERO_SELECT_FRAME_TEXTURES["thumbnail_strip"])
	thumbnail_strip_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail_strip_art.stretch_mode = TextureRect.STRETCH_SCALE
	thumbnail_strip_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail_strip_frame.add_child(thumbnail_strip_art)

	var thumbnail_strip_content := MarginContainer.new()
	thumbnail_strip_content.name = "HeroThumbnailStripContent"
	thumbnail_strip_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumbnail_strip_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var carousel_source_scale := _hero_select_carousel_frame_size().x / HERO_SELECT_CAROUSEL_FRAME_SOURCE_SIZE.x
	thumbnail_strip_content.add_theme_constant_override("margin_left", int(round(HERO_SELECT_CAROUSEL_CONTENT_BASE.x * carousel_source_scale)))
	thumbnail_strip_content.add_theme_constant_override("margin_top", int(round(HERO_SELECT_CAROUSEL_CONTENT_BASE.y * carousel_source_scale)))
	thumbnail_strip_content.add_theme_constant_override("margin_right", int(round(HERO_SELECT_CAROUSEL_CONTENT_BASE.z * carousel_source_scale)))
	thumbnail_strip_content.add_theme_constant_override("margin_bottom", int(round(HERO_SELECT_CAROUSEL_CONTENT_BASE.w * carousel_source_scale)))
	thumbnail_strip_frame.add_child(thumbnail_strip_content)

	var thumbnail_strip := HBoxContainer.new()
	thumbnail_strip.name = "HeroThumbnailStrip"
	thumbnail_strip.custom_minimum_size = Vector2(0, 96)
	thumbnail_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumbnail_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumbnail_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	thumbnail_strip.add_theme_constant_override("separation", HERO_SELECT_CAROUSEL_THUMBNAIL_SEPARATION)
	thumbnail_strip_content.add_child(thumbnail_strip)

	var legacy_grid := GridContainer.new()
	legacy_grid.name = "CharacterCardsGrid"
	legacy_grid.columns = 3
	legacy_grid.visible = false
	legacy_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(legacy_grid)

	var stat_maxima := _hero_radar_global_maxima()
	var character_ids: Array = game.PROGRESSION_DATA.character_ids()
	var thumbnail_size := _hero_thumbnail_size(character_ids.size())
	thumbnail_strip.custom_minimum_size = Vector2(0, maxf(thumbnail_size.y + 8.0, 64.0))
	if not character_ids.has(game.selected_character_id):
		game.selected_character_id = str(character_ids[0])
	var thumbnail_buttons: Array[Button] = []

	var refresh_asc := func() -> void:
		game.selected_ascension_level = clampi(game.selected_ascension_level, 0, game.ascension_selectable_max(game.selected_character_id))
		var lvl: int = game.selected_ascension_level
		var max_level: int = game.ascension_selectable_max(game.selected_character_id)
		asc_label.text = ("Возв.: %d/%d" % [lvl, max_level]) if _hero_select_unified_scale() < 0.52 else ("Возвышение: %d / %d" % [lvl, max_level])
		asc_mods.text = game.PROGRESSION_DATA.ascension_level_change_line(lvl)

	var select_character := func(character_id: String) -> void:
		game.selected_character_id = character_id
		game.selected_ascension_level = game.ascension_selectable_max(character_id)
		var config: Dictionary = game.PROGRESSION_DATA.character_config(character_id)
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
		var title := str(config.get("title", character_id))
		large_portrait.texture = game._cached_texture(str(config.get("sprite_path", "")))
		dossier_title.text = title
		dossier_desc.text = str(config.get("description", ""))
		dossier_traits.text = "Сильные: %s\nСлабые: %s" % [str(config.get("strengths", "")), str(config.get("weaknesses", ""))]
		weapons_label.text = "Оружие: %s" % _hero_weapon_names(character_id)
		radar.setup(stats, stat_maxima, game.PROGRESSION_DATA.STAT_NAMES, HERO_RADAR_STATS, HERO_CLASS_COLORS.get(character_id, Color(0.95, 0.78, 0.34, 0.82)))
		for button in thumbnail_buttons:
			var thumb_id := str(button.get_meta("character_id", ""))
			button.button_pressed = thumb_id == character_id
			button.add_theme_stylebox_override("normal", _hero_select_frame_style("thumbnail", Color(1.12, 1.02, 0.78, 1.0)) if thumb_id == character_id else _hero_select_frame_style("thumbnail"))
		refresh_asc.call()

	asc_minus.pressed.connect(func() -> void:
		game.selected_ascension_level = maxi(game.selected_ascension_level - 1, 0)
		refresh_asc.call()
	)
	asc_plus.pressed.connect(func() -> void:
		game.selected_ascension_level = mini(game.selected_ascension_level + 1, game.ascension_selectable_max(game.selected_character_id))
		refresh_asc.call()
	)
	select_button.pressed.connect(func() -> void:
		_show_weapon_select()
	)

	for character_id in character_ids:
		var char_id := str(character_id)
		var captured_id := char_id
		var thumb := _make_hero_thumbnail_button(captured_id, select_character, thumbnail_size)
		thumbnail_strip.add_child(thumb)
		thumbnail_buttons.append(thumb)
		var legacy_card := Button.new()
		legacy_card.name = "CharacterCard_%s" % captured_id
		legacy_card.set_meta("character_id", captured_id)
		legacy_card.pressed.connect(func() -> void:
			select_character.call(captured_id)
		)
		legacy_grid.add_child(legacy_card)
	for index in range(thumbnail_buttons.size()):
		var button := thumbnail_buttons[index]
		button.focus_neighbor_left = thumbnail_buttons[(index - 1 + thumbnail_buttons.size()) % thumbnail_buttons.size()].get_path()
		button.focus_neighbor_right = thumbnail_buttons[(index + 1) % thumbnail_buttons.size()].get_path()

	select_character.call(game.selected_character_id)
	if not thumbnail_buttons.is_empty():
		thumbnail_buttons[0].grab_focus()
	game.ui_escape_action = _show_main_menu


func _hero_thumbnail_size(character_count: int) -> Vector2:
	var frame_size := _hero_select_carousel_frame_size()
	var carousel_source_scale := frame_size.x / HERO_SELECT_CAROUSEL_FRAME_SOURCE_SIZE.x
	var horizontal_margins := (HERO_SELECT_CAROUSEL_CONTENT_BASE.x + HERO_SELECT_CAROUSEL_CONTENT_BASE.z) * carousel_source_scale
	var vertical_margins := (HERO_SELECT_CAROUSEL_CONTENT_BASE.y + HERO_SELECT_CAROUSEL_CONTENT_BASE.w) * carousel_source_scale
	var gap_total := maxf(float(character_count - 1), 0.0) * float(HERO_SELECT_CAROUSEL_THUMBNAIL_SEPARATION)
	var available_width := maxf(frame_size.x - horizontal_margins - gap_total, 1.0)
	var available_height := maxf(frame_size.y - vertical_margins, 1.0)
	var width := clampf(floor(available_width / maxf(float(character_count), 1.0)), 42.0, 136.0)
	var height := clampf(width * 1.35, 56.0, available_height)
	return Vector2(width, height)


func _hero_select_unified_scale() -> float:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var content_height := _hero_select_content_row_height()
	var radar_reserve_width := _hero_select_radar_frame_size().x + 34.0
	var available_width := maxf(viewport_size.x - 48.0 - radar_reserve_width - 16.0, 1.0)
	var height_scale := content_height / HERO_SELECT_UNIFIED_FRAME_SOURCE_SIZE.y
	var width_scale := available_width / HERO_SELECT_UNIFIED_FRAME_SOURCE_SIZE.x
	return clampf(minf(height_scale, width_scale), 0.36, 1.0)


func _hero_select_unified_frame_size() -> Vector2:
	var scale := _hero_select_unified_scale()
	return Vector2(
		round(HERO_SELECT_UNIFIED_FRAME_SOURCE_SIZE.x * scale),
		round(HERO_SELECT_UNIFIED_FRAME_SOURCE_SIZE.y * scale)
	)


func _hero_select_unified_scaled_rect(source_rect: Rect2) -> Rect2:
	var scale := _hero_select_unified_scale()
	return Rect2(
		Vector2(round(source_rect.position.x * scale), round(source_rect.position.y * scale)),
		Vector2(round(source_rect.size.x * scale), round(source_rect.size.y * scale))
	)


func _hero_select_asc_small_button_size() -> Vector2:
	var bottom_rect := _hero_select_unified_scaled_rect(HERO_SELECT_UNIFIED_BOTTOM_CONTROLS_RECT)
	var side := clampf(floor(bottom_rect.size.y * 0.42), 28.0, 56.0)
	return Vector2(side, side)


func _hero_select_portrait_scale() -> float:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var content_height := _hero_select_content_row_height()
	var available_width := maxf(viewport_size.x - 48.0, 1.0)
	var dossier_height_scale: float = content_height / HERO_SELECT_DOSSIER_FRAME_BASE_SIZE.y
	var dossier_width_scale: float = maxf(viewport_size.x, 1.0) / 1280.0
	var dossier_estimated_scale: float = clampf(minf(dossier_height_scale, dossier_width_scale), 0.84, 2.0)
	var right_min_width: float = round(HERO_SELECT_DOSSIER_FRAME_BASE_SIZE.x * dossier_estimated_scale) + _hero_select_radar_frame_size().x + 18.0
	var portrait_width_cap := maxf(available_width - right_min_width - 48.0, HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.x * 0.32)
	var width_cap_scale := portrait_width_cap / HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.x
	return clampf(content_height / HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.y, 0.32, minf(0.82, width_cap_scale))


func _hero_select_portrait_frame_size() -> Vector2:
	var scale := _hero_select_portrait_scale()
	return Vector2(
		round(HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.x * scale),
		round(HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.y * scale)
	)


func _hero_select_radar_scale() -> float:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var height_scale := maxf(viewport_size.y, 1.0) / 720.0
	var width_scale := maxf(viewport_size.x, 1.0) / 1280.0
	return clampf(minf(height_scale, width_scale), 1.0, 2.0)


func _hero_select_radar_frame_size() -> Vector2:
	var scale := _hero_select_radar_scale()
	return Vector2(
		round(HERO_SELECT_RADAR_FRAME_BASE_SIZE.x * scale),
		round(HERO_SELECT_RADAR_FRAME_BASE_SIZE.y * scale)
	)


func _hero_select_radar_graph_size() -> Vector2:
	var scale := _hero_select_radar_scale()
	return Vector2(
		round(HERO_SELECT_RADAR_GRAPH_BASE_SIZE.x * scale),
		round(HERO_SELECT_RADAR_GRAPH_BASE_SIZE.y * scale)
	)


func _hero_select_dossier_scale() -> float:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var content_row_height: float = _hero_select_content_row_height()
	var height_scale: float = content_row_height / HERO_SELECT_DOSSIER_FRAME_BASE_SIZE.y
	var width_scale: float = maxf(viewport_size.x, 1.0) / 1280.0
	var content_width: float = maxf(viewport_size.x - 48.0, 1.0)
	var portrait_scale: float = clampf(content_row_height / HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.y, 0.32, 0.82)
	var portrait_width: float = float(round(HERO_SELECT_PORTRAIT_FRAME_SOURCE_SIZE.x * portrait_scale))
	var radar_width: float = _hero_select_radar_frame_size().x + 18.0
	var available_dossier_width: float = maxf(content_width - 16.0 - portrait_width - 16.0 - radar_width, 1.0)
	var slot_width_scale: float = available_dossier_width / HERO_SELECT_DOSSIER_FRAME_BASE_SIZE.x
	return clampf(minf(minf(height_scale, width_scale), slot_width_scale), 0.84, 2.0)


func _hero_select_dossier_frame_size() -> Vector2:
	var scale := _hero_select_dossier_scale()
	return Vector2(
		round(HERO_SELECT_DOSSIER_FRAME_BASE_SIZE.x * scale),
		round(HERO_SELECT_DOSSIER_FRAME_BASE_SIZE.y * scale)
	)


func _hero_select_content_row_height() -> float:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var vertical_padding := 32.0
	var header_height := 104.0
	var layout_gaps := 20.0
	return maxf(viewport_size.y - vertical_padding - header_height - layout_gaps - _hero_select_carousel_frame_size().y, 300.0)


func _hero_select_carousel_scale() -> float:
	var viewport_size := Vector2(1280.0, 720.0)
	if game != null and game.get_viewport() != null:
		viewport_size = game.get_viewport().get_visible_rect().size
	var available_width := maxf(viewport_size.x - 48.0, 1.0)
	var height_scale := maxf(viewport_size.y, 1.0) / 720.0
	var width_scale := available_width / HERO_SELECT_CAROUSEL_FRAME_BASE_SIZE.x
	return clampf(minf(height_scale, width_scale), 0.64, 2.08)


func _hero_select_carousel_frame_size() -> Vector2:
	var scale := _hero_select_carousel_scale()
	return Vector2(round(HERO_SELECT_CAROUSEL_FRAME_BASE_SIZE.x * scale), round(HERO_SELECT_CAROUSEL_FRAME_BASE_SIZE.y * scale))


func _make_hero_thumbnail_button(character_id: String, select_character: Callable, thumbnail_size := Vector2(124, 88)) -> Button:
	var config: Dictionary = game.PROGRESSION_DATA.character_config(character_id)
	var button := Button.new()
	button.name = "HeroThumbnail_%s" % character_id
	button.toggle_mode = true
	button.set_meta("character_id", character_id)
	button.custom_minimum_size = thumbnail_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [str(config.get("title", character_id)), str(config.get("description", ""))]
	button.add_theme_stylebox_override("normal", _hero_select_frame_style("thumbnail"))
	button.add_theme_stylebox_override("hover", _hero_select_frame_style("thumbnail", BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _hero_select_frame_style("thumbnail", Color(0.92, 0.86, 0.76, 1.0)))
	button.add_theme_stylebox_override("focus", _hero_select_frame_style("thumbnail", BUTTON_NEUTRAL_FOCUS_TINT))
	button.pressed.connect(func() -> void:
		select_character.call(character_id)
	)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 6)
	button.add_child(content)

	# Карусель — ТОЛЬКО миниатюра-картинка (имя доступно в тултипе при hover).
	var portrait := TextureRect.new()
	portrait.name = "HeroThumbnailPortrait_%s" % character_id
	portrait.texture = game._cached_texture(str(config.get("sprite_path", "")))
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	return button


func _hero_radar_global_maxima() -> Dictionary:
	var maxima := {}
	for stat_id in HERO_RADAR_STATS:
		maxima[stat_id] = 1.0
	for character_id in game.PROGRESSION_DATA.character_ids():
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(str(character_id))
		for stat_id in HERO_RADAR_STATS:
			maxima[stat_id] = max(float(maxima.get(stat_id, 1.0)), float(stats.get(stat_id, 0.0)))
	return maxima


func _hero_weapon_names(character_id: String) -> String:
	var names := []
	for weapon_id in game.PROGRESSION_DATA.weapon_ids(character_id):
		var weapon: Dictionary = game.PROGRESSION_DATA.weapon(character_id, str(weapon_id))
		names.append(str(weapon.get("title", weapon_id)))
	return ", ".join(names)


const CODEX_DATA := preload("res://scripts/codex_data.gd")
const CODEX_SECTIONS := [
	{"id": "characters", "title": "Персонажи"},
	{"id": "monsters", "title": "Монстры"},
	{"id": "artifacts", "title": "Артефакты"},
	{"id": "stats", "title": "Характеристики"},
	{"id": "glossary", "title": "Глоссарий"},
	{"id": "ascensions", "title": "Возвышения"},
]


const ATTRIBUTE_BUY_BASE_COST := 18
const ATTRIBUTE_BUY_STAGE_COST := 6
const ATTRIBUTE_REROLL_BASE_COST := 6
const ATTRIBUTE_REROLL_STAGE_COST := 2
const ATTRIBUTE_REROLLS_PER_WINDOW := 2


func _ascension_price(base: int) -> int:
	# Ветвь Богатства мета-древа (SCRUM-150): удешевление докачки атрибутов
	# (attr_cost_mult ≤ 0). Используется только ценами докачки, не магазином.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var discount := maxf(1.0 + float(skill_mods.get("attr_cost_mult", 0.0)), 0.1)
	return maxi(1, int(round(float(base) * float(game.ascension_difficulty()["price_mult"]) * discount)))


func _attribute_buy_cost() -> int:
	return _ascension_price(game.PROGRESSION_DATA.stage_scaled_cost(ATTRIBUTE_BUY_BASE_COST + ATTRIBUTE_BUY_STAGE_COST * game.route_stage, game.route_stage))


func _attribute_reroll_cost() -> int:
	return _ascension_price(game.PROGRESSION_DATA.stage_scaled_cost(ATTRIBUTE_REROLL_BASE_COST + ATTRIBUTE_REROLL_STAGE_COST * game.route_stage, game.route_stage))


func _show_victory_banner(on_continue: Callable) -> void:
	# Затемнение + крупная «Победа»; продолжение по клику или через 1.3с.
	var banner_layer := CanvasLayer.new()
	banner_layer.name = "VictoryBannerLayer"
	banner_layer.layer = 80
	banner_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(banner_layer)

	var continue_once := func() -> void:
		if is_instance_valid(banner_layer):
			banner_layer.queue_free()
			if on_continue.is_valid():
				on_continue.call()

	var click_catcher := Button.new()
	click_catcher.name = "VictoryBanner"
	click_catcher.flat = true
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_catcher.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	click_catcher.pressed.connect(continue_once)
	banner_layer.add_child(click_catcher)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.02, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_catcher.add_child(shade)

	var label := Label.new()
	label.name = "VictoryBannerLabel"
	label.text = "ПОБЕДА"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.30, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 10)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_catcher.add_child(label)

	var tween := banner_layer.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shade, "color:a", 0.66, 0.30)
	tween.tween_property(label, "modulate:a", 1.0, 0.35)
	tween.chain().tween_interval(1.3)
	tween.chain().tween_callback(continue_once)

	game._play_sfx("level_up")


func _random_attribute_pair() -> Array:
	var pool := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
	# Ветвь Знаний мета-древа (SCRUM-150): attr_extra_options добавляет варианты
	# в окне докачки (по умолчанию 2 — обратная совместимость).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	var option_count: int = clampi(2 + int(skill_mods.get("attr_extra_options", 0.0)), 2, pool.size())
	var pair := []
	for _pick in range(option_count):
		var index: int = game.rng.randi_range(0, pool.size() - 1)
		pair.append(pool[index])
		pool.remove_at(index)
	return pair


func _show_attribute_shop(on_done: Callable) -> void:
	# Окно докачки после боя: 1 из 2 характеристик за деньги, reroll x2, пропуск.
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "AttributeShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "meta_progression")

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.045, 0.92)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "AttributeShopPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_top = -260.0
	panel.offset_right = 340.0
	panel.offset_bottom = 260.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Докачка"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var money_label := Label.new()
	money_label.name = "AttributeShopMoney"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.30, 1.0))
	box.add_child(money_label)

	var offers_box := VBoxContainer.new()
	offers_box.name = "AttributeOffers"
	offers_box.add_theme_constant_override("separation", 10)
	box.add_child(offers_box)

	var reroll_button := _make_button("")
	reroll_button.name = "AttributeRerollButton"
	box.add_child(reroll_button)

	var skip_button := _make_button("Пропустить")
	skip_button.name = "AttributeSkipButton"
	box.add_child(skip_button)

	# Набор и счетчик rerolls живут в game-state: переоткрытие окна (FAB)
	# не дает бесплатного реролла; сброс — только в победном флоу нового боя.
	if game.attribute_offer.is_empty():
		game.attribute_offer = _random_attribute_pair()
	skip_button.pressed.connect(func() -> void:
		if on_done.is_valid():
			on_done.call()
	)
	reroll_button.pressed.connect(func() -> void:
		if game.attribute_rerolls_left <= 0 or not _spend_run_money(_attribute_reroll_cost()):
			return
		game.attribute_rerolls_left -= 1
		game.attribute_offer = _random_attribute_pair()
		_refresh_attribute_shop(root, on_done)
	)
	game.ui_escape_action = skip_button.pressed.emit
	_refresh_attribute_shop(root, on_done)


func _refresh_attribute_shop(root: Control, on_done: Callable) -> void:
	if root == null or not is_instance_valid(root):
		return
	var offers_box := root.find_child("AttributeOffers", true, false) as VBoxContainer
	var money_label := root.find_child("AttributeShopMoney", true, false) as Label
	var reroll_button := root.find_child("AttributeRerollButton", true, false) as Button
	for child in offers_box.get_children():
		child.queue_free()

	var buy_cost := _attribute_buy_cost()
	var money := _run_money()
	money_label.text = "Золото: %d   |   +1 к характеристике: %d зол." % [money, buy_cost]
	reroll_button.text = "Обновить (%d зол.) — осталось %d" % [_attribute_reroll_cost(), game.attribute_rerolls_left]
	reroll_button.disabled = game.attribute_rerolls_left <= 0 or money < _attribute_reroll_cost()

	for stat_id in game.attribute_offer:
		var stat_title := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
		var offer_button := _make_button("%s +1   (%d зол.)" % [stat_title, buy_cost])
		offer_button.name = "AttributeOffer_%s" % stat_id
		_set_action_button_size(offer_button, 560.0)
		offer_button.disabled = money < buy_cost
		offer_button.tooltip_text = "%s +1\n%s" % [
			stat_title,
			game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, stat_id),
		]
		var icon_control: Control = game.UIIconRegistry.make_icon(stat_id, Vector2(36, 36))
		icon_control.position = Vector2(14, 14)
		icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		offer_button.add_child(icon_control)
		offer_button.pressed.connect(func() -> void:
			if not _spend_run_money(buy_cost):
				return
			_apply_reward_to_run({"stats": {stat_id: 1.0}})
			game.attribute_offer = []
			if on_done.is_valid():
				on_done.call()
		)
		offers_box.add_child(offer_button)


func _spend_run_money(amount: int) -> bool:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player.spend_money(amount)
	var temp_player = game.combat._snapshot_player_for_menu()
	if temp_player == null:
		return false
	if not temp_player.spend_money(amount):
		temp_player.queue_free()
		return false
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()
	return true


func _create_upgrade_fab(root: Control, return_action: Callable, allow_attribute_shop := true) -> void:
	# При pending level-up единственная точка входа — нижняя кнопка
	# "Повышение уровня (N)" с бейджем. FAB остается только для докачки за золото.
	if game.pending_level_ups > 0:
		_update_level_up_button()
		return

	# Желтая стрелка прокачки: докачка характеристик за деньги.
	var fab := _make_compact_button("⬆")
	fab.name = "UpgradeFabButton"
	fab.custom_minimum_size = Vector2(50, 50)
	fab.anchor_left = 1.0
	fab.anchor_top = 1.0
	fab.anchor_right = 1.0
	fab.anchor_bottom = 1.0
	fab.offset_left = -88.0
	fab.offset_top = -88.0
	fab.offset_right = -24.0
	fab.offset_bottom = -24.0
	fab.add_theme_font_size_override("font_size", 30)
	_apply_compact_button_theme(fab)
	fab.tooltip_text = "Докачка характеристик за золото"
	if not allow_attribute_shop:
		fab.disabled = true
		fab.tooltip_text = "Докачка здесь недоступна"
	fab.pressed.connect(func() -> void:
		if allow_attribute_shop:
			_show_attribute_shop(return_action)
	)
	root.add_child(fab)


func _show_skill_tree_screen() -> void:
	# SCRUM-150 ч.3: общий экран древа умений из главного меню. Данные/логика —
	# META_PROGRESSION (data-driven), сохранение узлов в user://. Применение
	# эффектов к забегу — player.apply_meta_skill_modifiers (ч.2a) + старт-вайринг (ч.2b).
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "SkillTreeScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "codex")

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 48.0
	layout.offset_top = 26.0
	layout.offset_right = -48.0
	layout.offset_bottom = -26.0
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var title := Label.new()
	title.text = "Древо умений"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	header.add_child(title)
	var points_label := Label.new()
	points_label.name = "SkillTreePointsLabel"
	points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 22)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34, 1.0))
	header.add_child(points_label)
	var back_button := _make_button("Назад в меню")
	back_button.name = "SkillTreeBackButton"
	_set_action_button_size(back_button, 260.0)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	var hint := Label.new()
	hint.name = "SkillTreeHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.80, 0.86, 0.92, 0.9))
	layout.add_child(hint)

	# SCRUM-360: прогресс ПО КЛАССУ (выбранный класс) — реиграбельность за классы.
	var class_panel := PanelContainer.new()
	class_panel.name = "SkillTreeClassPanel"
	class_panel.add_theme_stylebox_override("panel", _character_card_style())
	layout.add_child(class_panel)
	var class_margin := MarginContainer.new()
	class_margin.add_theme_constant_override("margin_left", 18)
	class_margin.add_theme_constant_override("margin_right", 18)
	class_margin.add_theme_constant_override("margin_top", 12)
	class_margin.add_theme_constant_override("margin_bottom", 12)
	class_panel.add_child(class_margin)
	var class_box := VBoxContainer.new()
	class_box.add_theme_constant_override("separation", 5)
	class_margin.add_child(class_box)
	var class_header := Label.new()
	class_header.name = "SkillTreeClassHeader"
	class_header.text = "Классы"
	class_header.add_theme_font_size_override("font_size", 18)
	class_header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.40, 1.0))
	class_box.add_child(class_header)
	var class_progress := Label.new()
	class_progress.name = "SkillTreeClassProgress"
	class_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_progress.add_theme_font_size_override("font_size", 15)
	class_progress.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 0.95))
	class_box.add_child(class_progress)
	var class_bonus_list := Label.new()
	class_bonus_list.name = "SkillTreeClassBonusList"
	class_bonus_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_bonus_list.add_theme_font_size_override("font_size", 13)
	class_bonus_list.add_theme_color_override("font_color", Color(0.78, 0.94, 0.82, 0.95))
	class_box.add_child(class_bonus_list)
	var class_id := str(game.selected_character_id)
	var class_config: Dictionary = game.PROGRESSION_DATA.character_config(class_id)
	var class_title := str(class_config.get("title", class_id))
	var class_wins: int = game.META_PROGRESSION.class_boss_wins(game.meta_state, class_id)
	var class_unlocked: int = game.META_PROGRESSION.class_level(game.meta_state, class_id)
	var class_next: Dictionary = game.META_PROGRESSION.class_next_threshold(game.meta_state, class_id)
	var class_text := "«%s»: %d побед над боссами, открыто бонусов: %d/%d." % [class_title, class_wins, class_unlocked, game.META_PROGRESSION.class_progression().size()]
	if class_next.is_empty():
		class_text += " Все бонусы класса открыты."
	else:
		class_text += " Следующий бонус — на %d победах: %s (%s)." % [int(class_next.get("wins", 0)), str(class_next.get("title", "")), str(class_next.get("desc", ""))]
	class_progress.text = class_text
	var unlocked_tiers: Array = game.META_PROGRESSION.class_unlocked_tiers(game.meta_state, class_id)
	if unlocked_tiers.is_empty():
		class_bonus_list.text = "Открытых классовых бонусов пока нет. Победи босса этим героем, чтобы начать его личную ветку."
	else:
		var bonus_lines := PackedStringArray()
		for tier in unlocked_tiers:
			bonus_lines.append("%s: %s" % [str(tier.get("title", "")), str(tier.get("desc", ""))])
		class_bonus_list.text = "\n".join(bonus_lines)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var branches_row := HBoxContainer.new()
	branches_row.name = "SkillTreeBranches"
	branches_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branches_row.add_theme_constant_override("separation", 16)
	scroll.add_child(branches_row)

	var node_buttons: Array[Button] = []
	var refresh := func() -> void:
		var pts: int = game.META_PROGRESSION.skill_points(game.meta_state)
		points_label.text = "Очки умений: %d" % pts
		var bought: int = game.META_PROGRESSION.purchased_nodes(game.meta_state).size()
		hint.text = "Очки умений зарабатываются за победы над боссами. Открывай узлы по ветвям — следующий требует предыдущий." if (pts == 0 and bought == 0) else ""
		for nb in node_buttons:
			var node_id: String = str(nb.get_meta("node_id"))
			var status: String = game.META_PROGRESSION.node_status(game.meta_state, node_id)
			nb.disabled = status != "available"
			match status:
				"purchased":
					nb.modulate = Color(0.62, 1.0, 0.66, 1.0)
				"available":
					nb.modulate = Color(1.0, 0.92, 0.6, 1.0)
				_:
					nb.modulate = Color(0.62, 0.64, 0.70, 0.7)

	for branch in game.META_PROGRESSION.SKILL_BRANCHES:
		var branch_id: String = str(branch)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		branches_row.add_child(col)
		var branch_title := Label.new()
		branch_title.text = str(game.META_PROGRESSION.SKILL_BRANCH_TITLES.get(branch_id, branch_id))
		branch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		branch_title.add_theme_font_size_override("font_size", 20)
		branch_title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.54, 1.0))
		col.add_child(branch_title)
		for node in game.META_PROGRESSION.branch_nodes(branch_id):
			var node_data: Dictionary = node
			var node_id: String = str(node_data["id"])
			var nb := _make_button("%s  (%d)\n%s" % [str(node_data["title"]), int(node_data["cost"]), str(node_data["desc"])])
			nb.name = "SkillNode_%s" % node_id
			nb.custom_minimum_size = Vector2(0, 103)
			nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nb.add_theme_font_size_override("font_size", 13)
			nb.set_meta("node_id", node_id)
			nb.pressed.connect(func() -> void:
				game.meta_state = game.META_PROGRESSION.buy_skill_node(game.meta_state, node_id)
				game.META_PROGRESSION.save_state(game.meta_state)
				refresh.call()
			)
			node_buttons.append(nb)
			col.add_child(nb)

	refresh.call()
	if not node_buttons.is_empty():
		node_buttons[0].grab_focus()


func _show_patch_notes_screen() -> void:
	# SCRUM-159: экран «Что нового» из главного меню — data-driven патч-ноуты
	# по версиям (новейшая первой), только пользовательский русский текст.
	const PatchNotesData := preload("res://scripts/patch_notes_data.gd")
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "PatchNotesScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "codex")

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 48.0
	layout.offset_top = 26.0
	layout.offset_right = -48.0
	layout.offset_bottom = -26.0
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var title := Label.new()
	title.text = "Что нового"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	header.add_child(title)
	var back_button := _make_button("Назад в меню")
	back_button.name = "PatchNotesBackButton"
	_set_action_button_size(back_button, 260.0)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "PatchNotesContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	for entry in PatchNotesData.all_entries():
		var entry_data: Dictionary = entry
		var version_label := Label.new()
		version_label.name = "PatchNotesVersion_%s" % str(entry_data.get("version", "")).replace(".", "_")
		version_label.text = "Версия %s  (%s)" % [str(entry_data.get("version", "")), str(entry_data.get("date", ""))]
		version_label.add_theme_font_size_override("font_size", 24)
		version_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.40, 1.0))
		content.add_child(version_label)
		for line in (entry_data.get("highlights", []) as Array):
			var bullet := Label.new()
			bullet.text = "•  %s" % str(line)
			bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bullet.add_theme_font_size_override("font_size", 16)
			bullet.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1.0))
			content.add_child(bullet)


func _show_codex_screen() -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "CodexScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)

	_add_screen_background(root, "codex")

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 48.0
	layout.offset_top = 26.0
	layout.offset_right = -48.0
	layout.offset_bottom = -26.0
	layout.add_theme_constant_override("separation", 14)
	root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Кодекс"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	header.add_child(title)

	var back_button := _make_button("Назад в меню")
	back_button.name = "CodexBackButton"
	_set_action_button_size(back_button, 260.0)
	back_button.pressed.connect(_show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _show_main_menu

	var tabs_row := HBoxContainer.new()
	tabs_row.name = "CodexTabs"
	tabs_row.add_theme_constant_override("separation", 10)
	layout.add_child(tabs_row)

	var content := PanelContainer.new()
	content.name = "CodexContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override("panel", _panel_style())
	layout.add_child(content)

	for section in CODEX_SECTIONS:
		var section_id := str(section["id"])
		var tab_button := _make_button(str(section["title"]))
		tab_button.name = "CodexTab_%s" % section_id
		_set_action_button_size(tab_button, 230.0)
		tab_button.pressed.connect(_show_codex_section.bind(content, section_id))
		tabs_row.add_child(tab_button)

	_show_codex_section(content, "characters")


func _show_codex_section(content: PanelContainer, section_id: String) -> void:
	# Ленивое построение: раздел собирается при первом открытии и кэшируется
	# внутри экрана, остальные скрываются — меню не фризит на старте.
	if content == null or not is_instance_valid(content):
		return
	for child in content.get_children():
		child.visible = false
	var existing := content.get_node_or_null("CodexSection_%s" % section_id)
	if existing != null:
		existing.visible = true
		return

	var scroll := ScrollContainer.new()
	scroll.name = "CodexSection_%s" % section_id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	match section_id:
		"characters":
			_build_codex_characters(list)
		"monsters":
			_build_codex_monsters(list)
		"artifacts":
			_build_codex_artifacts(list)
		"stats":
			_build_codex_stats(list)
		"glossary":
			_build_codex_glossary(list)
		"ascensions":
			_build_codex_ascensions(list)


func _codex_entry_panel(list: VBoxContainer) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _character_card_style())
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	return row


func _codex_portrait(row: HBoxContainer, sprite_path: String, size: Vector2) -> void:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = game._cached_texture(sprite_path)
	row.add_child(portrait)


func _codex_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_glossary_term_button(term_id: String, popup_context := false) -> Button:
	var definition: Dictionary = GLOSSARY.definition(term_id)
	var button := Button.new()
	button.name = "GlossaryTerm_%s" % term_id
	button.text = str(definition.get("name", term_id))
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = "" if popup_context else _glossary_tooltip_text(term_id)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.92, 0.82, 0.54, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62, 1.0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(func() -> void:
		if not popup_context or Input.is_key_pressed(KEY_ALT):
			_show_glossary_tooltip(button, term_id)
	)
	button.mouse_exited.connect(_hide_glossary_tooltip)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if popup_context and event is InputEventKey and Input.is_key_pressed(KEY_ALT):
			_show_glossary_tooltip(button, term_id)
	)
	var underline := HBoxContainer.new()
	underline.name = "GlossaryDottedUnderline"
	underline.anchor_left = 0.0
	underline.anchor_top = 1.0
	underline.anchor_right = 1.0
	underline.anchor_bottom = 1.0
	underline.offset_top = -4.0
	underline.offset_bottom = -1.0
	underline.alignment = BoxContainer.ALIGNMENT_CENTER
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.add_theme_constant_override("separation", 3)
	for dot_index in range(10):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(3, 2)
		dot.color = Color(0.92, 0.74, 0.38, 0.95)
		underline.add_child(dot)
	button.add_child(underline)
	return button


func _glossary_tooltip_text(term_id: String) -> String:
	var definition: Dictionary = GLOSSARY.definition(term_id)
	return "%s\n%s" % [str(definition.get("name", term_id)), str(definition.get("desc", ""))]


func _show_glossary_tooltip(anchor: Control, term_id: String) -> void:
	_hide_glossary_tooltip()
	if game.ui_layer == null:
		return
	var definition: Dictionary = GLOSSARY.definition(term_id)
	if definition.is_empty():
		return
	var tooltip := PanelContainer.new()
	tooltip.name = "GlossaryTooltipPanel"
	tooltip.process_mode = Node.PROCESS_MODE_ALWAYS
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.custom_minimum_size = Vector2(360, 0)
	tooltip.add_theme_stylebox_override("panel", _unified_frame_style("tooltip"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_theme_constant_override("margin_left", 12)
	box.add_theme_constant_override("margin_top", 10)
	box.add_theme_constant_override("margin_right", 12)
	box.add_theme_constant_override("margin_bottom", 10)
	tooltip.add_child(box)
	var title := Label.new()
	title.text = str(definition.get("name", term_id))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	box.add_child(title)
	var desc := Label.new()
	desc.text = str(definition.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 1.0))
	box.add_child(desc)
	game.ui_layer.add_child(tooltip)
	var anchor_rect := anchor.get_global_rect()
	var viewport_size := anchor.get_viewport_rect().size
	tooltip.position = anchor_rect.position + Vector2(0, anchor_rect.size.y + 8.0)
	tooltip.size = Vector2(380, 0)
	await game.get_tree().process_frame
	var rect := tooltip.get_global_rect()
	tooltip.position.x = clampf(tooltip.position.x, 16.0, maxf(16.0, viewport_size.x - rect.size.x - 16.0))
	tooltip.position.y = clampf(tooltip.position.y, 16.0, maxf(16.0, viewport_size.y - rect.size.y - 16.0))


func _hide_glossary_tooltip() -> void:
	if game.ui_layer == null:
		return
	var existing: Node = game.ui_layer.find_child("GlossaryTooltipPanel", true, false)
	if existing != null:
		existing.queue_free()


func _build_codex_characters(list: VBoxContainer) -> void:
	for character in CODEX_DATA.characters():
		var row := _codex_entry_panel(list)
		_codex_portrait(row, str(character["sprite"]), Vector2(176, 176))
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 4)
		row.add_child(text_box)
		_codex_label(text_box, str(character["title"]), 24, Color(0.96, 0.88, 0.40, 1.0))
		_codex_label(text_box, str(character["playstyle"]), 15, Color(0.94, 0.90, 0.81, 1.0))
		_codex_label(text_box, "Сильное: %s" % character["strengths"], 14, Color(0.62, 0.88, 0.58, 1.0))
		_codex_label(text_box, "Слабое: %s" % character["weaknesses"], 14, Color(0.92, 0.62, 0.52, 1.0))
		var ultimate: Dictionary = character.get("ultimate", {})
		if not ultimate.is_empty():
			_codex_label(text_box, "Ульта: %s — %s" % [ultimate.get("title", ""), ultimate.get("description", "")], 14, Color(1.0, 0.78, 0.96, 1.0))
		for weapon in character["weapons"]:
			_codex_label(text_box, "• %s — %s" % [weapon["title"], weapon["description"]], 13, Color(0.78, 0.84, 0.92, 1.0))


func _build_codex_monsters(list: VBoxContainer) -> void:
	var kind_titles := {"standard": "Обычные Монстры", "elite": "Элитные Монстры", "mini_elite": "Мини-элитки (свита Возвышения)", "boss": "Боссы"}
	for kind in ["standard", "elite", "mini_elite", "boss"]:
		_codex_label(list, str(kind_titles[kind]), 26, Color(0.96, 0.90, 0.68, 1.0))
		for monster in CODEX_DATA.monsters():
			if str(monster["kind"]) != kind:
				continue
			var row := _codex_entry_panel(list)
			_codex_portrait(row, str(monster["sprite"]), Vector2(150, 150))
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_box.add_theme_constant_override("separation", 3)
			row.add_child(text_box)
			_codex_label(text_box, "%s   (%s)" % [monster["title"], monster["id"]], 21, Color(0.96, 0.88, 0.40, 1.0))
			_codex_label(text_box, str(monster["behavior"]), 14, Color(0.94, 0.90, 0.81, 1.0))
			for ability in monster["abilities"]:
				_codex_label(text_box, "✦ %s — %s" % [ability["title"], ability["description"]], 13, Color(0.80, 0.68, 1.0, 1.0))


func _build_codex_artifacts(list: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for artifact in CODEX_DATA.artifacts():
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _character_card_style())
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(96, 96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _artifact_icon_texture(str(artifact["id"]))
		row.add_child(icon)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		var artifact_definition: Dictionary = game.PROGRESSION_DATA.artifact_definition(str(artifact["id"]))
		_codex_label(text_box, "%s   [%s]" % [artifact["title"], _artifact_tier_text(artifact_definition)], 16, Color(0.96, 0.88, 0.40, 1.0))
		_codex_label(text_box, str(artifact["description"]), 13, Color(0.92, 0.88, 0.79, 1.0))
		var codex_note := _artifact_affinity_note(artifact_definition)
		if not codex_note.is_empty():
			_codex_label(text_box, str(codex_note["text"]), 12, codex_note["color"])
		var affinity_list: Array = artifact_definition.get("class_affinity", [])
		if not affinity_list.is_empty():
			var class_names := []
			for class_id in affinity_list:
				class_names.append(str(CLASS_RU.get(class_id, class_id)))
			_codex_label(text_box, "Тематика: %s" % ", ".join(class_names), 12, Color(0.70, 0.78, 0.88, 1.0))


func _build_codex_ascensions(list: VBoxContainer) -> void:
	_codex_label(list, "Возвышения — режим усложнения (10 кумулятивных уровней)", 26, Color(0.96, 0.90, 0.68, 1.0))
	_codex_label(list, "Уровень N включает все усложнения 1..N. Повышает сложность и открывает мета-прогрессию (награда за победу над финальным боссом).", 13, Color(0.86, 0.90, 0.95, 1.0))
	for entry in CODEX_DATA.ascensions():
		var row := _codex_entry_panel(list)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		_codex_label(text_box, "%d. %s" % [entry["level"], entry["title"]], 18, Color(1.0, 0.74, 0.30, 1.0))
		_codex_label(text_box, str(entry["description"]), 13, Color(0.93, 0.89, 0.80, 1.0))


func _build_codex_stats(list: VBoxContainer) -> void:
	var type_titles := {"base": "Базовые Характеристики", "derived": "Производные Параметры"}
	for stat_type in ["base", "derived"]:
		_codex_label(list, str(type_titles.get(stat_type, stat_type)), 26, Color(0.96, 0.90, 0.68, 1.0))
		for stat in CODEX_DATA.stats():
			if str(stat["type"]) != stat_type:
				continue
			var row := _codex_entry_panel(list)
			var icon_control: Control = game.UIIconRegistry.make_icon(str(stat["id"]), Vector2(36, 36))
			row.add_child(icon_control)
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text_box)
			_codex_label(text_box, str(stat["title"]), 17, Color(0.96, 0.88, 0.40, 1.0))
			_codex_label(text_box, str(stat["description"]), 13, Color(0.93, 0.89, 0.80, 1.0))
			if str(stat["influences"]) != "":
				_codex_label(text_box, "Влияет на: %s" % stat["influences"], 12, Color(0.70, 0.78, 0.88, 1.0))


func _build_codex_glossary(list: VBoxContainer) -> void:
	_codex_label(list, "Глоссарий терминов", 26, Color(0.96, 0.90, 0.68, 1.0))
	_codex_label(list, "Термины с пунктиром можно навести мышью. Во всплывающих окнах такие подсказки показываются только при зажатом Alt.", 13, Color(0.86, 0.90, 0.95, 1.0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	list.add_child(grid)
	for term_id in GLOSSARY.term_ids():
		var definition: Dictionary = GLOSSARY.definition(term_id)
		var panel := PanelContainer.new()
		panel.name = "GlossaryEntry_%s" % term_id
		panel.add_theme_stylebox_override("panel", _character_card_style())
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		panel.add_child(box)
		box.add_child(_make_glossary_term_button(term_id, false))
		_codex_label(box, str(definition.get("desc", "")), 12, Color(0.90, 0.86, 0.76, 1.0))


func _show_settings_menu() -> void:
	var box := _create_menu_box("Настройки", "Экран, звук и управление", "settings")
	box.alignment = BoxContainer.ALIGNMENT_BEGIN

	var tabs := TabContainer.new()
	tabs.name = "SettingsTabs"
	tabs.custom_minimum_size = Vector2(1000, 300)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tabs_visible = false
	tabs.add_theme_font_size_override("font_size", 17)
	tabs.add_theme_color_override("font_selected_color", Color(0.98, 0.90, 0.50, 1.0))
	tabs.add_theme_color_override("font_unselected_color", Color(0.73, 0.78, 0.84, 1.0))
	box.add_child(_make_settings_tab_switcher(tabs))
	box.add_child(tabs)

	var screen_tab := _make_settings_tab("Экран")
	var screen_box := screen_tab.get_child(0) as VBoxContainer
	tabs.add_child(screen_tab)

	var screen_count := DisplayServer.get_screen_count()
	if screen_count > 1:
		var screen_options := OptionButton.new()
		screen_options.name = "SettingsScreenOption"
		screen_options.custom_minimum_size = Vector2(520, 62)
		screen_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_compact_button_theme(screen_options)
		for screen_index in range(screen_count):
			var size := DisplayServer.screen_get_size(screen_index)
			screen_options.add_item("Экран %d (%dx%d)" % [screen_index + 1, size.x, size.y])
		screen_options.selected = clampi(game.selected_screen_index, 0, screen_count - 1)
		screen_options.item_selected.connect(func(index: int) -> void:
			game.selected_screen_index = index
			_apply_video_settings()
			_show_settings_menu()
		)
		_add_settings_control_row(screen_box, "Монитор", screen_options)

	var resolution_options := OptionButton.new()
	resolution_options.name = "SettingsResolutionOption"
	resolution_options.custom_minimum_size = Vector2(520, 62)
	resolution_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_compact_button_theme(resolution_options)
	var usable_size := Vector2i(99999, 99999)
	if DisplayServer.get_name() != "headless":
		usable_size = DisplayServer.screen_get_usable_rect(clampi(game.selected_screen_index, 0, maxi(screen_count - 1, 0))).size
	for option_index in range(game.RESOLUTION_OPTIONS.size()):
		var resolution: Vector2i = game.RESOLUTION_OPTIONS[option_index]
		resolution_options.add_item("%dx%d" % [resolution.x, resolution.y])
		# Разрешения больше выбранного монитора недоступны.
		if resolution.x > usable_size.x or resolution.y > usable_size.y:
			resolution_options.set_item_disabled(option_index, true)
	resolution_options.selected = game.selected_resolution_index
	resolution_options.item_selected.connect(func(index: int) -> void:
		game.selected_resolution_index = index
		_apply_video_settings()
	)
	_add_settings_control_row(screen_box, "Разрешение", resolution_options)

	var mode_options := OptionButton.new()
	mode_options.name = "SettingsWindowModeOption"
	mode_options.custom_minimum_size = Vector2(520, 62)
	mode_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_compact_button_theme(mode_options)
	for mode_name in game.WINDOW_MODE_OPTIONS:
		mode_options.add_item(mode_name)
	mode_options.selected = game.selected_window_mode_index
	mode_options.item_selected.connect(func(index: int) -> void:
		game.selected_window_mode_index = index
		_apply_video_settings()
	)
	_add_settings_control_row(screen_box, "Режим окна", mode_options)

	var screen_hint := Label.new()
	screen_hint.text = "Оконные разрешения автоматически ограничиваются выбранным монитором."
	screen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_hint.add_theme_font_size_override("font_size", 14)
	screen_hint.add_theme_color_override("font_color", Color(0.70, 0.76, 0.82, 1.0))
	screen_box.add_child(screen_hint)

	var shake_row := HBoxContainer.new()
	shake_row.name = "ScreenShakeRow"
	shake_row.add_theme_constant_override("separation", 12)
	screen_box.add_child(shake_row)
	var shake_label := Label.new()
	shake_label.text = "Тряска камеры"
	shake_label.custom_minimum_size = Vector2(220, 36)
	shake_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.96, 1.0))
	shake_row.add_child(shake_label)
	var shake_toggle := CheckBox.new()
	shake_toggle.name = "ScreenShakeToggle"
	shake_toggle.button_pressed = game.screen_shake_enabled
	_style_checkbox(shake_toggle)
	shake_toggle.toggled.connect(func(pressed: bool) -> void:
		game.screen_shake_enabled = pressed
		game.get_tree().root.set_meta("screen_shake", pressed)
		game.save_game_settings()
	)
	shake_row.add_child(shake_toggle)

	var audio_tab := _make_settings_tab("Звук")
	var audio_box := audio_tab.get_child(0) as VBoxContainer
	tabs.add_child(audio_tab)
	_add_volume_row(audio_box, "Общая громкость", "master_volume", "")
	_add_volume_row(audio_box, "Музыка", "music_volume", "music_enabled")
	_add_volume_row(audio_box, "Эффекты", "sfx_volume", "sfx_enabled")
	var reset_audio_button := _make_button("Сбросить звук по умолчанию")
	reset_audio_button.name = "SettingsResetAudioButton"
	_set_action_button_size(reset_audio_button, 420.0)
	reset_audio_button.pressed.connect(func() -> void:
		_reset_audio_to_defaults()
		_show_settings_menu()
	)
	audio_box.add_child(reset_audio_button)

	var controls_tab := _make_settings_tab("Управление")
	tabs.add_child(controls_tab)
	# Вкладка «Управление» переполнялась (прицеливание + строка-ребинд на каждый
	# INPUT_ACTION) — оборачиваем контент в вертикальный ScrollContainer, чтобы
	# всё помещалось и прокручивалось внутри высоты таба.
	var controls_page := controls_tab.get_child(0) as VBoxContainer
	var controls_scroll := ScrollContainer.new()
	controls_scroll.name = "ControlsScroll"
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	controls_scroll.follow_focus = true
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_page.add_child(controls_scroll)
	var controls_box := VBoxContainer.new()
	controls_box.name = "ControlsContent"
	controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_box.add_theme_constant_override("separation", 14)
	controls_scroll.add_child(controls_box)

	var aim_options := OptionButton.new()
	aim_options.name = "SettingsAimModeOption"
	aim_options.custom_minimum_size = Vector2(520, 62)
	aim_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_compact_button_theme(aim_options)
	aim_options.add_item("Автонаводка на ближайшего")
	aim_options.add_item("По курсору")
	aim_options.selected = 1 if str(game.aim_mode) == "cursor" else 0
	aim_options.item_selected.connect(func(index: int) -> void:
		game.aim_mode = "cursor" if index == 1 else "nearest"
		game.get_tree().root.set_meta("aim_mode", game.aim_mode)
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Прицеливание", aim_options)

	var debug_toggle := CheckBox.new()
	debug_toggle.name = "DebugModeToggle"
	debug_toggle.custom_minimum_size = Vector2(300, 42)
	debug_toggle.button_pressed = game.debug_mode_enabled
	debug_toggle.text = "Вкл. (ПКМ / Shift+ЛКМ)" if debug_toggle.button_pressed else "Выкл."
	debug_toggle.tooltip_text = "Дебаг: в бою ПКМ или Shift+ЛКМ задают точку движения, средняя кнопка телепортирует."
	_style_checkbox(debug_toggle)
	debug_toggle.toggled.connect(func(pressed: bool) -> void:
		game.debug_mode_enabled = pressed
		game.get_tree().root.set_meta("debug_mode", pressed)
		debug_toggle.text = "Вкл. (ПКМ / Shift+ЛКМ)" if pressed else "Выкл."
		game.save_game_settings()
	)
	_add_settings_control_row(controls_box, "Дебаг-режим", debug_toggle)

	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var row := HBoxContainer.new()
		row.name = "BindingRow_%s" % action_name
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 12)
		controls_box.add_child(row)

		var label := Label.new()
		label.text = input_action["label"]
		label.custom_minimum_size = Vector2(170, 38)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
		row.add_child(label)

		var bind_button := _make_compact_button(_binding_text(action_name))
		bind_button.name = "BindingButton_%s" % action_name
		bind_button.custom_minimum_size = Vector2(420, 62)
		bind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_compact_button_theme(bind_button)
		bind_button.pressed.connect(func() -> void:
			_begin_rebind(action_name)
		)
		row.add_child(bind_button)

	var hint_label := Label.new()
	hint_label.text = "Клик по биндингу, затем нажми клавишу. Esc отменяет."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.82, 1.0))
	controls_box.add_child(hint_label)

	var reset_button := _make_button("Сбросить управление по умолчанию")
	reset_button.name = "SettingsResetBindingsButton"
	_set_action_button_size(reset_button, 440.0)
	reset_button.pressed.connect(func() -> void:
		_reset_input_bindings_to_defaults()
		_show_settings_menu()
	)
	controls_box.add_child(reset_button)

	var settings_back := func() -> void:
		if game._is_gameplay_paused() and game.combat_active:
			_show_pause_menu()
		else:
			_show_main_menu()
	var back_button := _make_button("Назад")
	back_button.pressed.connect(settings_back)
	box.add_child(back_button)
	game.ui_escape_action = settings_back


func _make_settings_tab_switcher(tabs: TabContainer) -> Control:
	var switcher := Control.new()
	switcher.name = "SettingsTabSwitcher"
	switcher.custom_minimum_size = SETTINGS_TAB_SWITCHER_DISPLAY_SIZE
	switcher.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	switcher.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switcher.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := TextureRect.new()
	art.name = "SettingsTabSwitcherFrame"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.texture = game._cached_texture(SETTINGS_TAB_SWITCHER_FRAME_PATH)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# The control uses the same 5:1 aspect ratio as the source PNG, so this is
	# uniform scaling, not one-axis stretching.
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switcher.add_child(art)

	var buttons: Array[Button] = []
	var labels := ["Экран", "Звук", "Управление"]
	var scale := SETTINGS_TAB_SWITCHER_DISPLAY_SIZE / SETTINGS_TAB_SWITCHER_BASE_SIZE
	for tab_index in range(labels.size()):
		var safe_rect: Rect2 = SETTINGS_TAB_SWITCHER_SAFE_RECTS[tab_index]
		var button := Button.new()
		button.name = "SettingsTabButton_%d" % tab_index
		button.text = labels[tab_index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_mode = Control.FOCUS_ALL
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.offset_left = round(safe_rect.position.x * scale.x)
		button.offset_top = round(safe_rect.position.y * scale.y)
		button.offset_right = round((safe_rect.position.x + safe_rect.size.x) * scale.x)
		button.offset_bottom = round((safe_rect.position.y + safe_rect.size.y) * scale.y)
		button.add_theme_font_size_override("font_size", 12)
		button.tooltip_text = "Открыть вкладку: %s" % labels[tab_index]
		var target_tab := tab_index
		button.pressed.connect(func() -> void:
			tabs.current_tab = target_tab
		)
		switcher.add_child(button)
		buttons.append(button)

	var update_buttons := func(active_tab: int) -> void:
		for button_index in range(buttons.size()):
			_apply_settings_tab_button_theme(buttons[button_index], button_index == active_tab)
	update_buttons.call(tabs.current_tab)
	tabs.tab_changed.connect(func(tab_index: int) -> void:
		update_buttons.call(tab_index)
	)
	return switcher


func _apply_settings_tab_button_theme(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", _settings_tab_button_style(selected, false, false))
	button.add_theme_stylebox_override("hover", _settings_tab_button_style(selected, true, false))
	button.add_theme_stylebox_override("pressed", _settings_tab_button_style(selected, true, true))
	button.add_theme_stylebox_override("focus", _settings_tab_button_style(selected, true, false))
	button.add_theme_stylebox_override("disabled", _settings_tab_button_style(false, false, false))
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0) if selected else Color(0.84, 0.86, 0.91, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _settings_tab_button_style(selected: bool, hovered: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.032, 0.040, 0.08)
	style.border_color = Color(0.74, 0.80, 0.88, 0.14)
	if selected:
		style.bg_color = Color(0.22, 0.045, 0.035, 0.34)
		style.border_color = Color(0.95, 0.82, 0.48, 0.42)
	if hovered:
		style.bg_color = Color(0.16, 0.16, 0.18, 0.38) if not selected else Color(0.28, 0.075, 0.060, 0.44)
		style.border_color = Color(0.92, 0.94, 0.98, 0.56)
	if pressed:
		style.bg_color = Color(0.05, 0.12, 0.13, 0.46)
		style.border_color = Color(0.72, 1.0, 0.96, 0.70)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_settings_tab(tab_name: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	var page := VBoxContainer.new()
	page.name = "%sContent" % tab_name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	return margin


func _add_settings_control_row(parent: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "SettingsRow_%s" % title.replace(" ", "_")
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(180, 46)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	row.add_child(label)
	row.add_child(control)


func _add_volume_row(box: VBoxContainer, title: String, volume_key: String, enabled_key: String) -> void:
	var row := HBoxContainer.new()
	row.name = "VolumeRow_%s" % volume_key
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(170, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	row.add_child(label)

	var slider := HSlider.new()
	slider.name = "VolumeSlider_%s" % volume_key
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 2.0
	slider.custom_minimum_size = Vector2(560, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	_style_slider(slider)
	slider.value = float(game.audio_settings.get(volume_key, 1.0)) * 100.0
	slider.value_changed.connect(func(value: float) -> void:
		game.audio_settings[volume_key] = value / 100.0
		game._apply_audio_settings()
		game.save_game_settings()
	)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58, 42)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text = "%d%%" % int(slider.value)
	value_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45, 1.0))
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(value)
	)
	row.add_child(value_label)

	if enabled_key != "":
		var toggle := CheckBox.new()
		toggle.name = "VolumeToggle_%s" % enabled_key
		toggle.custom_minimum_size = Vector2(108, 42)
		toggle.button_pressed = bool(game.audio_settings.get(enabled_key, true))
		toggle.text = "Вкл." if toggle.button_pressed else "Выкл."
		_style_checkbox(toggle)
		slider.editable = toggle.button_pressed
		toggle.toggled.connect(func(pressed: bool) -> void:
			game.audio_settings[enabled_key] = pressed
			toggle.text = "Вкл." if pressed else "Выкл."
			slider.editable = pressed
			game._apply_audio_settings()
			game.save_game_settings()
		)
		row.add_child(toggle)


func _reset_audio_to_defaults() -> void:
	for key in ["master_volume", "music_volume", "sfx_volume", "music_enabled", "sfx_enabled"]:
		game.audio_settings[key] = game.GAME_SETTINGS.DEFAULTS[key]
	game.audio_settings["master_zero_intent"] = false
	game._apply_audio_settings()
	game.save_game_settings()


func _show_pause_menu() -> void:
	if not _can_open_pause_dossier():
		return

	game.push_pause("escape_menu")
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		game.pause_overlay_layer.queue_free()
	game.pause_overlay_layer = CanvasLayer.new()
	game.pause_overlay_layer.name = "RunPauseOverlayLayer"
	game.pause_overlay_layer.layer = 120
	game.pause_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.pause_overlay_layer)
	game.pause_stats_menu = null
	_build_run_pause_menu()


func _build_run_pause_menu() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	for child in game.pause_overlay_layer.get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.name = "RunPauseDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.025, 0.70)
	game.pause_overlay_layer.add_child(dim)

	var root := CenterContainer.new()
	root.name = "RunPauseMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.pause_overlay_layer.add_child(root)

	var panel := PanelContainer.new()
	panel.name = "RunPauseMenuPanel"
	panel.custom_minimum_size = Vector2(520, 480)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "RunPauseMenuButtons"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.name = "RunPauseMenuTitle"
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "RunPauseMenuSubtitle"
	subtitle.text = "Забег поставлен на паузу"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.82, 0.90, 1.0))
	box.add_child(subtitle)

	var continue_button := _make_button("Продолжить")
	continue_button.name = "RunPauseContinueButton"
	_set_action_button_size(continue_button, 280.0, 60.0)
	continue_button.pressed.connect(_resume_game)
	box.add_child(continue_button)

	var dossier_button := _make_button("Досье персонажа")
	dossier_button.name = "RunPauseDossierButton"
	_set_action_button_size(dossier_button, 280.0, 60.0)
	dossier_button.pressed.connect(_show_pause_dossier_menu)
	box.add_child(dossier_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "RunPauseSettingsButton"
	_set_action_button_size(settings_button, 280.0, 60.0)
	settings_button.pressed.connect(_show_settings_menu)
	box.add_child(settings_button)

	var end_run_button := _make_button("Покинуть забег")
	end_run_button.name = "RunPauseEndRunButton"
	_set_action_button_size(end_run_button, 280.0, 60.0)
	end_run_button.pressed.connect(_end_current_run_by_player)
	box.add_child(end_run_button)

	var main_menu_button := _make_button("Главное меню")
	main_menu_button.name = "RunPauseMainMenuButton"
	_set_action_button_size(main_menu_button, 280.0, 60.0)
	main_menu_button.pressed.connect(_quit_current_run)
	box.add_child(main_menu_button)


func _show_pause_dossier_menu() -> void:
	if game.pause_overlay_layer == null or not is_instance_valid(game.pause_overlay_layer):
		return
	for child in game.pause_overlay_layer.get_children():
		child.queue_free()

	game.pause_stats_menu = game.PAUSE_STATS_MENU_SCENE.instantiate() as Control
	game.pause_overlay_layer.add_child(game.pause_stats_menu)
	if game.pause_stats_menu.has_method("setup"):
		game.pause_stats_menu.setup(_pause_dossier_player())
	game.pause_stats_menu.resume_requested.connect(_resume_game)
	game.pause_stats_menu.settings_requested.connect(_show_settings_menu)
	game.pause_stats_menu.end_run_confirmed.connect(_end_current_run_by_player)
	game.pause_stats_menu.main_menu_requested.connect(_quit_current_run)


func _is_run_pause_overlay_open() -> bool:
	return game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer)


func _can_open_pause_dossier() -> bool:
	if game.combat_active:
		return true
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	for screen_name in ["RouteMapScreen", "ShopScreen", "AttributeShopScreen", "LevelUpOverlay", "EliteArtifactRewardScreen", "EventScreen"]:
		if game.ui_layer.find_child(screen_name, true, false) != null:
			return true
	return false


func _pause_dossier_player() -> Node:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player
	var temp_player: Node = game.combat._snapshot_player_for_menu()
	temp_player.set_meta("pause_dossier_temp_player", true)
	return temp_player


func _resume_game() -> void:
	game.pending_rebind_action = ""
	game.pop_pause("escape_menu")
	if game.pause_stats_menu != null and is_instance_valid(game.pause_stats_menu):
		var temp_player := game.pause_stats_menu.get("_player") as Node
		if temp_player != null and is_instance_valid(temp_player) and bool(temp_player.get_meta("pause_dossier_temp_player", false)):
			temp_player.queue_free()
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		game.pause_overlay_layer.queue_free()
	game.pause_overlay_layer = null
	game.pause_stats_menu = null


func _quit_current_run() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	game.route_stage = 0
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game.route_nodes = game.route._generate_route()
	game._clear_world()
	game._clear_hud()
	_show_main_menu()


func _end_current_run_by_player() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
	game.used_event_ids.clear()
	game.current_event_definition.clear()
	game.pending_event_combat.clear()
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game._clear_world()
	game._clear_hud()
	_show_death_screen("Забег завершен игроком.")


func _add_character_button(box: Container, character_id: String, info_labels: Dictionary) -> void:
	var config: Dictionary = game.PROGRESSION_DATA.character_config(character_id)
	var stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
	var title := str(config.get("title", character_id))
	var description := str(config.get("description", ""))
	var strengths := str(config.get("strengths", ""))
	var weaknesses := str(config.get("weaknesses", ""))
	var stats_text: String = game.PROGRESSION_DATA.display_stats(stats)
	# Вся карточка — одна кнопка: клик в любом месте, hover подсвечивает рамку.
	var card := Button.new()
	card.name = "CharacterCard_%s" % character_id
	card.custom_minimum_size = Vector2(300, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "%s\n%s\nСильные: %s\nСлабые: %s\n%s" % [title, description, strengths, weaknesses, stats_text]
	card.add_theme_stylebox_override("normal", _character_card_style())
	card.add_theme_stylebox_override("hover", _card_hover_style())
	card.add_theme_stylebox_override("pressed", _card_hover_style())
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.mouse_entered.connect(func() -> void:
		_update_hero_select_info(info_labels, title, description, strengths, weaknesses, stats_text)
	)
	card.pressed.connect(func() -> void:
		game.selected_character_id = character_id
		# Уровень возвышения клампится к открытому максимуму этого героя.
		game.selected_ascension_level = clampi(game.selected_ascension_level, 0, game.ascension_selectable_max(character_id))
		_show_weapon_select()
	)
	box.add_child(card)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)

	var portrait := TextureRect.new()
	portrait.name = "CharacterPortrait_%s" % character_id
	portrait.texture = game._cached_texture(str(config.get("sprite_path", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(0, 96)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(portrait)

	var asc_badge := Label.new()
	asc_badge.name = "CharacterAscension_%s" % character_id
	var asc_unlocked: int = game.ascension_level_for(character_id)
	asc_badge.text = ("Возвышение %d" % asc_unlocked) if asc_unlocked > 0 else "Возвышение 0"
	asc_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	asc_badge.add_theme_font_size_override("font_size", 11)
	asc_badge.add_theme_color_override("font_color", Color(1.0, 0.74, 0.30, 0.9))
	asc_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(asc_badge)

	var title_label := Label.new()
	title_label.name = "CharacterTitle_%s" % character_id
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38, 1.0))
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)

	var style_line := _hero_card_line(description, 13, Color(0.94, 0.90, 0.81, 1.0))
	style_line.name = "CharacterStyle_%s" % character_id
	column.add_child(style_line)

	var strengths_line := _hero_card_line("Сильные: %s" % strengths, 12, Color(0.70, 0.95, 0.78, 1.0))
	strengths_line.name = "CharacterStrengths_%s" % character_id
	column.add_child(strengths_line)

	var weaknesses_line := _hero_card_line("Слабые: %s" % weaknesses, 12, Color(0.95, 0.72, 0.70, 1.0))
	weaknesses_line.name = "CharacterWeaknesses_%s" % character_id
	column.add_child(weaknesses_line)

	var ascension_level = game.ascension_level_for(character_id)
	if ascension_level > 0:
		var ascension_label := Label.new()
		ascension_label.name = "CharacterAscension_%s" % character_id
		ascension_label.text = "Возвышение: %d/10" % ascension_level
		ascension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ascension_label.add_theme_font_size_override("font_size", 11)
		ascension_label.add_theme_color_override("font_color", Color(0.78, 0.58, 1.0, 1.0))
		ascension_label.clip_text = true
		ascension_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(ascension_label)


func _hero_card_line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _update_hero_select_info(info_labels: Dictionary, title: String, description: String, strengths: String, weaknesses: String, stats_text: String) -> void:
	var title_label := info_labels.get("title") as Label
	var description_label := info_labels.get("description") as Label
	var stats_label := info_labels.get("stats") as Label
	if title_label != null:
		title_label.text = title
	if description_label != null:
		description_label.text = "%s  |  Сильные: %s  |  Слабые: %s" % [description, strengths, weaknesses]
	if stats_label != null:
		stats_label.text = stats_text


func _show_weapon_select() -> void:
	var character_config = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var box := _create_menu_box("Выбор оружия", "%s: выбери стартовый подкласс/оружие." % str(character_config["title"]), "weapon_select")
	for weapon_id in game.PROGRESSION_DATA.weapon_ids(game.selected_character_id):
		var config = game.PROGRESSION_DATA.weapon(game.selected_character_id, str(weapon_id))
		var button := _make_weapon_select_card(config)
		button.pressed.connect(func() -> void:
			game.selected_weapon_id = str(config["id"])
			game.route._show_battle_map()
		)
		box.add_child(button)

	var back_button := _make_button("Назад")
	back_button.pressed.connect(_show_character_select)
	box.add_child(back_button)
	game.ui_escape_action = _show_character_select


func _make_weapon_select_card(config: Dictionary) -> Button:
	var weapon_id := str(config.get("id", ""))
	var button := Button.new()
	button.name = "WeaponOption_%s" % weapon_id
	button.set_meta("weapon_id", weapon_id)
	button.text = ""
	button.custom_minimum_size = Vector2(860, 173)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [str(config.get("title", weapon_id)), str(config.get("description", ""))]
	button.add_theme_stylebox_override("normal", _weapon_card_style(false))
	button.add_theme_stylebox_override("hover", _weapon_card_style(true))
	button.add_theme_stylebox_override("pressed", _weapon_card_style(true, true))
	button.add_theme_stylebox_override("focus", _weapon_card_style(true))
	button.add_theme_stylebox_override("disabled", _weapon_card_style(false, false, true))

	var row := HBoxContainer.new()
	row.name = "WeaponOptionContent_%s" % weapon_id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18.0
	row.offset_top = 12.0
	row.offset_right = -18.0
	row.offset_bottom = -12.0
	row.add_theme_constant_override("separation", 18)
	button.add_child(row)

	var sprite := TextureRect.new()
	sprite.name = "WeaponSelectSprite_%s" % weapon_id
	sprite.custom_minimum_size = Vector2(112, 112)
	sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture = game._cached_texture(_weapon_sprite_path(config))
	row.add_child(sprite)

	var text_box := VBoxContainer.new()
	text_box.name = "WeaponSelectText_%s" % weapon_id
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 5)
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.name = "WeaponSelectTitle_%s" % weapon_id
	title_label.text = str(config.get("title", weapon_id))
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var desc_label := Label.new()
	desc_label.name = "WeaponSelectDescription_%s" % weapon_id
	desc_label.text = str(config.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.91, 0.88, 0.78, 1.0))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(desc_label)

	var stats_label := Label.new()
	stats_label.name = "WeaponSelectStats_%s" % weapon_id
	stats_label.custom_minimum_size = Vector2(190, 0)
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = "Дальность: %.0f\nРадиус: %.0f\nПерезарядка: %.2fс" % [
		float(config.get("attack_range", 0.0)),
		float(config.get("aoe_radius", 0.0)),
		float(config.get("fire_interval", 0.0)),
	]
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0, 1.0))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stats_label)
	return button


func _weapon_sprite_path(config: Dictionary) -> String:
	for key in ["icon_path", "sprite_path", "weapon_sprite_path"]:
		var configured_path := str(config.get(key, ""))
		if configured_path != "" and ResourceLoader.exists(configured_path):
			return configured_path
	var weapon_id := str(config.get("id", ""))
	var aliases := {
		"sword": "two_handed_sword",
		"axe": "two_handed_axe",
		"hammer": "two_handed_hammer",
	}
	var asset_id := str(aliases.get(weapon_id, weapon_id))
	var direct_path := "res://assets/sprites/weapons/%s.png" % asset_id
	if ResourceLoader.exists(direct_path):
		return direct_path
	return ""


func _show_reward_screen() -> void:
	var box := _create_menu_box("Награда за бой", "Выбери 1 из 3 усилений.", "artifact_reward")
	_create_menu_run_hud()
	for reward in _random_rewards(3):
		var button := _add_text_action_block(box, str(reward["title"]), str(reward["description"]), "Получить", "")
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.save_run_autosave("reward_choice")
			game.route._show_battle_map()
		)


func _show_level_up_screen(return_to_map := false) -> void:
	game.level_up_return_to_map = return_to_map
	var box := _create_level_up_menu_box("Повышение уровня", "Выбери 1 из 3 усилений. Один выбор за уровень.")
	if not game.combat_active:
		_create_menu_run_hud()

	# HFlowContainer: 3 карточки в ряд на широком экране, перенос на узком.
	var rewards_row := HFlowContainer.new()
	rewards_row.name = "LevelUpRewardsRow"
	rewards_row.alignment = FlowContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, 260.0)
	rewards_row.add_theme_constant_override("h_separation", 14)
	rewards_row.add_theme_constant_override("v_separation", 12)
	box.add_child(rewards_row)

	# Набор фиксируется на полученный уровень: переоткрытие окна показывает то же.
	if game.level_up_offer.is_empty():
		game.level_up_offer = _random_level_up_rewards(3)
	var reward_buttons: Array[Button] = []
	for reward in game.level_up_offer:
		var button := _make_level_up_reward_button(reward)
		button.name = "LevelUpRewardButton%d" % reward_buttons.size()
		button.pressed.connect(func() -> void:
			_apply_reward_to_active_run(reward)
			game.level_up_offer = []
			game.pending_level_ups = maxi(game.pending_level_ups - 1, 0)
			game.ui_escape_action = Callable()
			_update_level_up_button()
			if game.pending_level_ups > 0:
				_show_level_up_screen(return_to_map)
			else:
				game.level_up_return_to_map = false
				game.pop_pause("level_up")
				game._clear_ui()
				if game.combat_active:
					_create_hud()
					_update_hud()
				elif return_to_map or not game.combat_active:
					game.save_run_autosave("level_up_choice")
					game.route._show_battle_map()
		)
		rewards_row.add_child(button)
		reward_buttons.append(button)

	# Клавиатура/геймпад: фокус по карточкам стрелками по кругу, Enter/Space выбирают.
	for index in range(reward_buttons.size()):
		var card := reward_buttons[index]
		var left := reward_buttons[(index - 1 + reward_buttons.size()) % reward_buttons.size()]
		var right := reward_buttons[(index + 1) % reward_buttons.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
	if not reward_buttons.is_empty():
		reward_buttons[0].grab_focus()

	# Отложенный выбор: «Позже» (и Escape) закрывают окно БЕЗ траты пика — набор
	# зафиксирован, вернуться можно кнопкой повышения внизу экрана.
	var defer_choice := func() -> void:
		game.ui_escape_action = Callable()
		game.level_up_return_to_map = false
		game.pop_pause("level_up")
		game._clear_ui()
		if game.combat_active:
			_create_hud()
			_update_hud()
			_update_level_up_button()
		else:
			game.save_run_autosave("level_up_deferred")
			game.route._show_battle_map()

	var later_button := _make_button("Позже")
	later_button.name = "LevelUpLaterButton"
	_set_action_button_size(later_button, 260.0)
	later_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later_button.tooltip_text = "Закрыть без выбора — пик сохранится, вернуться можно кнопкой повышения внизу."
	later_button.pressed.connect(defer_choice)
	box.add_child(later_button)
	game.ui_escape_action = defer_choice

	var panel := box.get_parent() as PanelContainer
	var title_label := box.get_node_or_null("LevelUpTitle") as Label
	var sparkle_root = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpParticles") as Control
	_start_level_up_intro(panel, title_label, reward_buttons, sparkle_root)


func _show_elite_artifact_reward(on_done: Callable) -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "EliteArtifactRewardScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	game.ui_layer.add_child(root)
	_add_screen_background(root, "elite_reward")

	var shade := ColorRect.new()
	shade.name = "EliteArtifactRewardShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.015, 0.025, 0.76)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.name = "EliteArtifactRewardCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "EliteArtifactRewardPanel"
	panel.custom_minimum_size = Vector2(1140, 560)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _level_up_panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)

	var title := Label.new()
	title.name = "EliteArtifactRewardTitle"
	title.text = "Трофей элитки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "EliteArtifactRewardSubtitle"
	subtitle.text = "Выбери 1 из 3 артефактов. Чем глубже маршрут, тем выше шанс редкой добычи."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.90, 0.98, 1.0))
	box.add_child(subtitle)

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "EliteArtifactRewardRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, 380.0)
	rewards_row.add_theme_constant_override("separation", 22)
	box.add_child(rewards_row)

	var choices: Array = game.PROGRESSION_DATA.elite_artifact_choices(game.route_stage, 3)
	var reward_cards: Array[Button] = []
	for reward in choices:
		var reward_data: Dictionary = reward
		var button := _make_elite_artifact_card(reward_data)
		button.name = "EliteArtifactRewardButton%d" % rewards_row.get_child_count()
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward_data)
			game._clear_ui()
			if on_done.is_valid():
				on_done.call()
		)
		rewards_row.add_child(button)
		reward_cards.append(button)

	# Клавиатура/геймпад: стрелки двигают фокус по кругу, Enter/Space выбирают.
	for index in range(reward_cards.size()):
		var card := reward_cards[index]
		var left := reward_cards[(index - 1 + reward_cards.size()) % reward_cards.size()]
		var right := reward_cards[(index + 1) % reward_cards.size()]
		card.focus_neighbor_left = left.get_path()
		card.focus_neighbor_right = right.get_path()
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path()
	if not reward_cards.is_empty():
		reward_cards[0].grab_focus()

	# Выбор обязателен: Escape ничего не закрывает.
	game.ui_escape_action = Callable()
	game._play_sfx("level_up")


func _make_level_up_reward_button(reward: Dictionary) -> Button:
	var is_rare := bool(reward.get("rare", false))
	var rare_color: Color = TIER_COLORS[3]
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(245, 364)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _format_level_up_reward_text(reward)
	button.set_meta("level_up_text_field_card", true)
	button.add_theme_stylebox_override("normal", _level_up_text_field_style(false, is_rare))
	button.add_theme_stylebox_override("hover", _level_up_text_field_style(true, is_rare))
	button.add_theme_stylebox_override("pressed", _level_up_text_field_style(true, is_rare, true))
	button.add_theme_stylebox_override("focus", _level_up_text_field_style(true, is_rare))
	button.add_theme_stylebox_override("disabled", _level_up_text_field_style(false, is_rare, false, true))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12.0
	content.offset_top = 10.0
	content.offset_right = -12.0
	content.offset_bottom = -10.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	button.add_child(content)

	if is_rare:
		var rare_tag := Label.new()
		rare_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rare_tag.text = "★ ХАРАКТЕРИСТИКА"
		rare_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rare_tag.add_theme_font_size_override("font_size", 12)
		rare_tag.add_theme_color_override("font_color", rare_color)
		content.add_child(rare_tag)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(56, 56)))

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Upgrade"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", rare_color if is_rare else Color(1.0, 0.91, 0.58, 1.0))
	content.add_child(title_label)

	var preview_label := Label.new()
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.text = _level_up_reward_preview(reward)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_font_size_override("font_size", 15)
	preview_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	content.add_child(preview_label)

	var description_label := Label.new()
	description_label.name = "LevelUpRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(reward.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.64, 0.72, 0.80, 1.0))
	content.add_child(description_label)
	return button


func _make_elite_artifact_card(reward: Dictionary) -> Button:
	# Крупная карточка трофея элитки: иконка 112px, название/тир цветом тира,
	# эффект и классовая интерпретация. Кликается целиком, фокусируется с клавиатуры.
	var tier_color := _artifact_tier_color(reward)
	var button := _make_button("")
	button.custom_minimum_size = Vector2(340, 502)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.tooltip_text = _format_level_up_reward_text(reward)
	_apply_fantasy_button_theme(button, "reward")

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18.0
	content.offset_top = 18.0
	content.offset_right = -18.0
	content.offset_bottom = -18.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	button.add_child(content)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(112, 112)))

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Артефакт"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", tier_color)
	content.add_child(title_label)

	var tier_label := Label.new()
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_label.text = _artifact_tier_text(reward)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 15)
	tier_label.add_theme_color_override("font_color", tier_color)
	content.add_child(tier_label)

	var effect_label := Label.new()
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_label.text = str(reward.get("description", ""))
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_font_size_override("font_size", 15)
	effect_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	content.add_child(effect_label)

	var interpretation := _reward_interpretation_text(reward)
	if interpretation != "":
		var interp_label := Label.new()
		interp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		interp_label.text = interpretation
		interp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		interp_label.add_theme_font_size_override("font_size", 13)
		interp_label.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82, 1.0))
		content.add_child(interp_label)

	return button


func _resume_combat_after_level_up() -> void:
	game.pop_pause("level_up")
	game._clear_ui()
	if game.combat_active:
		_create_hud()
		_update_hud()


func _current_shop_node_key() -> String:
	var stage := int(game.route_stage)
	var node_type := str(game.current_node_type)
	if node_type == "":
		node_type = "shop"
	var route_choice := str(game.current_route_choice)
	if route_choice == "":
		route_choice = "direct"
	return "%d:%s:%s" % [stage, node_type, route_choice]


func _ensure_shop_stock_for_current_node() -> void:
	var node_key := _current_shop_node_key()
	if game.current_shop_node_key == "":
		game.current_shop_node_key = node_key
	var should_generate: bool = game.current_shop_items.is_empty()
	if should_generate:
		game.current_shop_items = _random_shop_items(4)
		game.current_shop_purchased.clear()
	while game.current_shop_purchased.size() < game.current_shop_items.size():
		game.current_shop_purchased.append(false)
	if game.current_shop_purchased.size() > game.current_shop_items.size():
		game.current_shop_purchased.resize(game.current_shop_items.size())


func _clear_current_shop_stock() -> void:
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	game.current_shop_node_key = ""


func _show_shop_screen() -> void:
	_ensure_shop_stock_for_current_node()

	var money := _run_money()
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "ShopScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)

	_add_screen_background(root, "shop")
	_create_menu_run_hud()
	_create_upgrade_fab(root, _show_shop_screen)

	var title_box := VBoxContainer.new()
	title_box.name = "ShopHeader"
	title_box.anchor_left = 0.5
	title_box.anchor_top = 0.0
	title_box.anchor_right = 0.5
	title_box.anchor_bottom = 0.0
	title_box.offset_left = -380.0
	title_box.offset_top = 104.0
	title_box.offset_right = 380.0
	title_box.offset_bottom = 190.0
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_box)

	var title := Label.new()
	title.text = "Магазин"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Выбери предмет. Описание появляется при наведении."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 1.0))
	title_box.add_child(subtitle)

	# Товары лежат в центральной свободной зоне shop backdrop как предметы
	# лавки, а не как UI-карточки.
	var wall := Control.new()
	wall.name = "ShopParchmentWall"
	wall.anchor_left = 0.20
	wall.anchor_top = 0.33
	wall.anchor_right = 0.80
	wall.anchor_bottom = 0.79
	wall.offset_left = 0.0
	wall.offset_top = 0.0
	wall.offset_right = 0.0
	wall.offset_bottom = 0.0
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wall)

	var items_area := Control.new()
	items_area.name = "ShopInlineItems"
	items_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.add_child(items_area)

	for index in range(game.current_shop_items.size()):
		var item: Dictionary = game.current_shop_items[index]
		var slot := _make_shop_item_slot(item, index, money)
		var slot_anchor := _shop_wall_slot_anchor(index)
		slot.anchor_left = slot_anchor.x
		slot.anchor_top = slot_anchor.y
		slot.anchor_right = slot_anchor.x
		slot.anchor_bottom = slot_anchor.y
		slot.offset_left = -SHOP_INLINE_SLOT_SIZE.x * 0.5
		slot.offset_top = -SHOP_INLINE_SLOT_SIZE.y * 0.5
		slot.offset_right = SHOP_INLINE_SLOT_SIZE.x * 0.5
		slot.offset_bottom = SHOP_INLINE_SLOT_SIZE.y * 0.5
		items_area.add_child(slot)

	var skip_button := _make_button("Назад")
	skip_button.name = "ShopLeaveButton"
	skip_button.tooltip_text = "Покинуть магазин и продолжить маршрут."
	skip_button.anchor_left = 0.5
	skip_button.anchor_top = 1.0
	skip_button.anchor_right = 0.5
	skip_button.anchor_bottom = 1.0
	skip_button.offset_left = -180.0
	skip_button.offset_top = -126.0
	skip_button.offset_right = 180.0
	skip_button.offset_bottom = -58.0
	_set_action_button_size(skip_button, 360.0)
	var leave_shop := func() -> void:
		game.route._return_to_map_after_shop_visit()
	skip_button.pressed.connect(leave_shop)
	game.ui_escape_action = leave_shop
	root.add_child(skip_button)


func _make_shop_item_slot(item: Dictionary, index: int, money: int) -> Button:
	var purchased: bool = index < game.current_shop_purchased.size() and bool(game.current_shop_purchased[index])
	var cost := int(item.get("cost", 0))
	var affordable := money >= cost
	var button := Button.new()
	button.name = "ShopItemButton%d" % index
	button.custom_minimum_size = SHOP_INLINE_SLOT_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	button.tooltip_text = _shop_item_tooltip(item, purchased, affordable)
	if str(item.get("kind", "")) == "artifact":
		button.tooltip_text += "\n%s" % _artifact_tier_text(item)
		var affinity_note := _artifact_affinity_note(item)
		if not affinity_note.is_empty():
			button.tooltip_text += "\n[%s]" % affinity_note["text"]
			var note_label := Label.new()
			note_label.name = "ShopAffinityNote"
			note_label.text = "!"
			note_label.tooltip_text = str(affinity_note["text"])
			note_label.add_theme_font_size_override("font_size", 22)
			note_label.add_theme_color_override("font_color", affinity_note["color"])
			note_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			note_label.offset_left = -26.0
			note_label.offset_top = 4.0
			note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(note_label)
	button.add_theme_stylebox_override("normal", _shop_wall_button_style(false))
	button.add_theme_stylebox_override("hover", _shop_wall_button_style(true))
	button.add_theme_stylebox_override("pressed", _shop_wall_button_style(true))
	button.add_theme_stylebox_override("focus", _shop_wall_button_style(true))
	button.add_theme_stylebox_override("disabled", _shop_wall_button_style(false))
	button.pressed.connect(func() -> void:
		_buy_shop_item_at(index)
	)

	if purchased:
		button.disabled = true
		_add_shop_empty_hook(button)
		return button

	var content := Control.new()
	content.name = "ShopWallItemContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(content)

	var shadow := PanelContainer.new()
	shadow.name = "ShopItemContactShadow"
	shadow.anchor_left = 0.5
	shadow.anchor_top = 0.0
	shadow.anchor_right = 0.5
	shadow.anchor_bottom = 0.0
	shadow.offset_left = -46.0
	shadow.offset_top = 112.0
	shadow.offset_right = 46.0
	shadow.offset_bottom = 130.0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", _shop_item_shadow_style())
	content.add_child(shadow)

	var icon := TextureRect.new()
	icon.name = "ShopItemIcon"
	icon.texture = _shop_item_icon_texture(item)
	icon.custom_minimum_size = SHOP_INLINE_ICON_SIZE
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.0
	icon.offset_left = -SHOP_INLINE_ICON_SIZE.x * 0.5
	icon.offset_top = 16.0
	icon.offset_right = SHOP_INLINE_ICON_SIZE.x * 0.5
	icon.offset_bottom = 16.0 + SHOP_INLINE_ICON_SIZE.y
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if affordable else Color(0.52, 0.48, 0.45, 0.82)
	content.add_child(icon)

	var price_badge := PanelContainer.new()
	price_badge.name = "ShopPriceBadge"
	price_badge.anchor_left = 0.5
	price_badge.anchor_top = 1.0
	price_badge.anchor_right = 0.5
	price_badge.anchor_bottom = 1.0
	price_badge.offset_left = -54.0
	price_badge.offset_top = -42.0
	price_badge.offset_right = 54.0
	price_badge.offset_bottom = -12.0
	price_badge.custom_minimum_size = Vector2(108, 30)
	price_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_theme_stylebox_override("panel", _shop_price_badge_style(affordable))
	content.add_child(price_badge)

	var price_row := HBoxContainer.new()
	price_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_child(price_row)

	var money_icon := TextureRect.new()
	money_icon.name = "ShopPriceMoneyIcon"
	money_icon.texture = game.UIIconRegistry.texture_for("money")
	money_icon.custom_minimum_size = Vector2(18, 18)
	money_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	money_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	money_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(money_icon)

	var price_label := Label.new()
	price_label.name = "ShopItemPrice"
	price_label.text = "%d" % cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0) if affordable else Color(1.0, 0.42, 0.42, 1.0))
	price_row.add_child(price_label)

	if not affordable:
		_add_shop_state_overlay(button, "Нет монет")
	return button


func _shop_wall_slot_anchor(index: int) -> Vector2:
	var anchors := [
		Vector2(0.30, 0.20),
		Vector2(0.70, 0.20),
		Vector2(0.30, 0.80),
		Vector2(0.70, 0.80),
	]
	return anchors[index % anchors.size()]


func _add_shop_empty_hook(button: Button) -> void:
	var hook := PanelContainer.new()
	hook.name = "ShopEmptyHook"
	hook.anchor_left = 0.5
	hook.anchor_top = 0.5
	hook.anchor_right = 0.5
	hook.anchor_bottom = 0.5
	hook.offset_left = -34.0
	hook.offset_top = -18.0
	hook.offset_right = 34.0
	hook.offset_bottom = 18.0
	hook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_theme_stylebox_override("panel", _shop_empty_hook_style())
	button.add_child(hook)

	var label := Label.new()
	label.text = "снято"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.40, 0.30, 0.20, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hook.add_child(label)


func _add_shop_state_overlay(button: Button, text: String) -> void:
	var overlay := PanelContainer.new()
	overlay.name = "ShopItemStateOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_stylebox_override("panel", _shop_purchased_overlay_style())
	button.add_child(overlay)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	overlay.add_child(label)


func _shop_item_tooltip(item: Dictionary, purchased: bool, affordable: bool) -> String:
	var lines := [
		str(item.get("title", "Предмет")),
		str(item.get("description", "")),
		"Цена: %dg" % int(item.get("cost", 0)),
	]
	var class_text := _shop_item_classes_text(item)
	if class_text != "":
		lines.append("Класс: %s" % class_text)
	if purchased:
		lines.append("Уже куплено")
	elif not affordable:
		lines.append("Не хватает монет")
	return "\n".join(lines)


func _shop_item_classes_text(item: Dictionary) -> String:
	var classes: Array = item.get("classes", [])
	if classes.is_empty():
		return ""
	var titles := []
	for character_id in classes:
		var config: Dictionary = game.PROGRESSION_DATA.character_config(str(character_id))
		titles.append(str(config.get("title", character_id)))
	return ", ".join(titles)


func _shop_item_icon_texture(item: Dictionary) -> Texture2D:
	var dedicated_path := _shop_item_icon_path(item)
	var dedicated_texture: Texture2D = game._cached_texture(dedicated_path)
	if dedicated_texture != null:
		return dedicated_texture
	return game.UIIconRegistry.texture_for(_shop_item_fallback_icon_id(item))


func _shop_item_icon_path(item: Dictionary) -> String:
	var item_id := str(item.get("id", ""))
	if item_id == "":
		return ""
	if str(item.get("kind", "")) == "artifact" or not item_id.begins_with("shop_"):
		return "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, item_id]
	return "%sshop_%s.png" % [SHOP_ICON_DIR, item_id]


func _shop_item_fallback_icon_id(item: Dictionary) -> String:
	var stats: Dictionary = item.get("stats", {})
	for stat_id in game.UIIconRegistry.BASE_STAT_IDS:
		if stats.has(stat_id):
			return stat_id

	var modifiers: Dictionary = item.get("mods", {})
	if item.has("heal_percent") or modifiers.has("max_health_flat") or modifiers.has("max_health_multiplier"):
		return "health_point"
	if modifiers.has("attack_speed_multiplier"):
		return "attack_speed"
	if modifiers.has("move_speed_multiplier"):
		return "move_speed"
	if modifiers.has("pickup_radius_flat"):
		return "pickup_radius"
	if modifiers.has("range_multiplier"):
		return "attack_range"
	if modifiers.has("aoe_radius_multiplier"):
		return "aoe_radius"
	if modifiers.has("crit_chance_flat") or modifiers.has("crit_damage_flat"):
		return "crit_chance"
	if modifiers.has("defense_flat"):
		return "defense"
	if modifiers.has("summon_bonus"):
		return "summon_amount"
	if modifiers.has("knockback_multiplier"):
		return "knockback_power"

	var classes: Array = item.get("classes", [])
	if classes.has("dark_mage"):
		return "magic_damage"
	if classes.has("guitarist"):
		return "sound_wave_damage"
	if modifiers.has("money_gain_multiplier"):
		return "money"
	if modifiers.has("xp_gain_multiplier"):
		return "xp"
	if modifiers.has("damage_multiplier"):
		return "damage"
	return "artifact"


func _shop_slot_style(is_hovered: bool) -> StyleBox:
	var texture_path := SHOP_SLOT_HOVER_PATH if is_hovered else SHOP_SLOT_FRAME_PATH
	var texture_style := _shop_texture_style(texture_path, Vector2(24, 24))
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.060, 0.105, 0.110, 0.72) if is_hovered else Color(0.035, 0.055, 0.070, 0.58)
	style.border_color = Color(0.60, 0.98, 0.92, 0.96) if is_hovered else Color(0.96, 0.75, 0.26, 0.72)
	style.set_border_width_all(2 if is_hovered else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12 if is_hovered else 6
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _shop_wall_button_style(is_hovered: bool) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.76, 0.38, 0.08) if is_hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(1.0, 0.86, 0.42, 0.38) if is_hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(1 if is_hovered else 0)
	style.set_corner_radius_all(18)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(1.0, 0.70, 0.24, 0.18) if is_hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 12 if is_hovered else 0
	return style


func _shop_item_shadow_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.016, 0.38)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(16)
	return style


func _shop_empty_hook_style() -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.075, 0.050, 0.22)
	style.border_color = Color(0.18, 0.13, 0.08, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style


func _shop_price_badge_style(affordable := true) -> StyleBox:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.055, 0.035, 0.78) if affordable else Color(0.20, 0.055, 0.050, 0.82)
	style.border_color = Color(0.72, 0.48, 0.16, 0.72) if affordable else Color(0.96, 0.30, 0.26, 0.76)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 5
	style.content_margin_top = 3
	style.content_margin_right = 6
	style.content_margin_bottom = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _shop_purchased_overlay_style() -> StyleBox:
	var texture_style := _shop_texture_style(SHOP_PURCHASED_OVERLAY_PATH, Vector2(18, 18))
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.030, 0.68)
	style.border_color = Color(0.36, 0.48, 0.52, 0.86)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _shop_texture_style(path: String, margin: Vector2) -> StyleBoxTexture:
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin.x
	style.texture_margin_top = margin.y
	style.texture_margin_right = margin.x
	style.texture_margin_bottom = margin.y
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _show_rest_screen() -> void:
	var box := _create_menu_box("Костер", "Восстановись или подготовься перед следующим боем.", "campfire")
	_create_menu_run_hud()
	# Escape = уйти от костра без бонуса (последовательно с пропуском магазина).
	game.ui_escape_action = game.route._advance_route_after_noncombat
	_create_upgrade_fab(box.get_parent().get_parent() if box.get_parent() != null else box, _show_rest_screen)
	var heal_button := _add_text_action_block(box, "Передышка", "Восстановить 35% максимального здоровья.", "Отдохнуть", "RestHealButton")
	heal_button.name = "RestHealButton"
	heal_button.pressed.connect(func() -> void:
		_apply_event_choice({"title": "Rest", "description": "Recover", "heal_percent": 0.35})
		game.route._advance_route_after_noncombat()
	)

	var guard_button := _add_text_action_block(box, "Защитная стойка", "Получить +6% защиты до конца забега.", "Подготовиться", "RestGuardButton")
	guard_button.name = "RestGuardButton"
	guard_button.pressed.connect(func() -> void:
		_apply_reward_to_run({"title": "Защитная стойка", "description": "+6% к защите.", "mods": {"defense_flat": 0.06}})
		game.route._advance_route_after_noncombat()
	)


func _show_upgrade_screen() -> void:
	var box := _create_menu_box("Улучшение", "Выбери усиление оружия или параметра.", "upgrade")
	_create_menu_run_hud()
	for reward in _random_level_up_rewards(3):
		var button := _add_text_action_block(box, str(reward["title"]), str(reward["description"]), "Выбрать", "")
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.route._advance_route_after_noncombat()
		)


func _show_event_screen(route_node: Dictionary) -> void:
	var event_definition: Dictionary = {}
	if route_node.has("event_id"):
		event_definition = game.EVENT_DATA.event_by_id(str(route_node.get("event_id", "")))
	if event_definition.is_empty():
		event_definition = game.EVENT_DATA.pick_event(game.used_event_ids, game.rng)
	var event_id := str(event_definition.get("id", ""))
	if event_id != "" and not game.used_event_ids.has(event_id):
		game.used_event_ids.append(event_id)
	game.current_event_definition = event_definition.duplicate(true)

	var box := _create_menu_box(str(event_definition.get("title", route_node["name"])), str(event_definition.get("story", "Странная возможность на дороге: риск, награда или оба сразу.")), "event")
	var event_root := box.get_parent().get_parent() as Control if box.get_parent() != null and box.get_parent().get_parent() != null else null
	if event_root != null:
		event_root.name = "EventScreen"
	_create_menu_run_hud()
	# На событии докачка недоступна: повторный вход перегенерировал бы выборы события.
	_create_upgrade_fab(box.get_parent().get_parent() if box.get_parent() != null else box, Callable(), false)
	var event_choices: Array = event_definition.get("choices", _random_event_choices())
	var index := 0
	for event_choice in event_choices:
		var title_text := str(event_choice.get("title", "Выбор"))
		var desc_text := _event_choice_description_text(event_choice)
		var button := _add_text_action_block(box, title_text, desc_text, "Выбрать", "EventChoiceButton%d" % index)
		button.name = "EventChoiceButton%d" % index
		button.pressed.connect(func() -> void:
			var starts_combat := _apply_event_choice(event_choice)
			if not starts_combat:
				game.current_event_definition.clear()
				game.route._advance_route_after_noncombat()
		)
		index += 1
	var back_button := _make_button("Назад")
	back_button.name = "EventBackButton"
	_set_action_button_size(back_button, 380.0)
	var allow_skip := bool(event_definition.get("allow_skip", false))
	back_button.disabled = not allow_skip
	back_button.tooltip_text = "Вернуться на карту без исхода события." if allow_skip else "Это событие требует выбрать исход."
	back_button.pressed.connect(func() -> void:
		if not allow_skip:
			return
		game.current_event_definition.clear()
		game.route._show_battle_map()
	)
	box.add_child(back_button)


func _show_victory_screen() -> void:
	game.clear_run_autosave()
	var ascension_level: int = game.ascension_level_for(game.selected_character_id)
	var character_config: Dictionary = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var character_title := str(character_config.get("title", "Герой"))
	if character_title == "" or character_title == game.selected_character_id:
		character_title = "Герой"
	var run_level: int = game.selected_ascension_level
	# Победа над боссом даёт очко умений (record_boss_victory) — показываем игроку.
	var skill_points_total: int = game.META_PROGRESSION.skill_points(game.meta_state)
	var subtitle := "Финальный босс повержен.\n%s завершил забег.\nОчки наследия: %d.\nПолучено очко умений — всего %d, потрать их в «Древе умений» в меню.\n%s" % [
		character_title,
		game.meta_points,
		skill_points_total,
		_victory_ascension_summary(game.selected_character_id, run_level, ascension_level),
	]
	var box = _create_menu_box("Победа", subtitle, "victory")
	var finish_run := func() -> void:
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var restart_button := _make_button("Новый забег")
	restart_button.pressed.connect(finish_run)
	box.add_child(restart_button)
	game.ui_escape_action = finish_run


func _show_death_screen(reason := "") -> void:
	game.clear_run_autosave()
	var subtitle := str(reason)
	if subtitle == "":
		subtitle = "Забег завершён на этапе маршрута %d." % [game.route_stage + 1]
	var box := _create_menu_box("Поражение", subtitle, "death")
	var back_to_menu := func() -> void:
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.used_event_ids.clear()
		game.current_event_definition.clear()
		game.pending_event_combat.clear()
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var retry_button := _make_button("Начать заново")
	retry_button.pressed.connect(back_to_menu)
	box.add_child(retry_button)
	game.ui_escape_action = back_to_menu


func _victory_ascension_summary(character_id: String, run_level: int, unlocked_level: int) -> String:
	var lines := ["Текущий предел Возвышения: %d из 10." % unlocked_level]
	if run_level >= unlocked_level - 1 and unlocked_level > 0:
		lines.append("Открыт следующий уровень Возвышения.")
		var reward_text := _ascension_reward_summary(character_id, unlocked_level)
		if reward_text != "":
			lines.append(reward_text)
	else:
		lines.append("Пройден уже освоенный уровень Возвышения.")
	return "\n".join(lines)


func _ascension_reward_summary(character_id: String, level: int) -> String:
	var rewards: Array = game.PROGRESSION_DATA.ascension_levels(character_id)
	var index := clampi(level - 1, 0, rewards.size() - 1)
	if rewards.is_empty() or index < 0 or index >= rewards.size():
		return ""
	var reward: Dictionary = rewards[index]
	var title := str(reward.get("title", "Новая мета-награда"))
	var modifier_text := _modifier_summary_text(reward.get("mods", {}))
	if modifier_text == "":
		return "Новая награда для будущих забегов: %s." % title
	return "Новая награда для будущих забегов: %s — %s." % [title, modifier_text]


func _modifier_summary_text(mods_value) -> String:
	var mods: Dictionary = mods_value if mods_value is Dictionary else {}
	var parts := []
	for key in mods.keys():
		var value := float(mods[key])
		match str(key):
			"damage_multiplier":
				parts.append("урон +%d%%" % int(round((value - 1.0) * 100.0)))
			"attack_speed_multiplier":
				parts.append("скорость атаки +%d%%" % int(round((value - 1.0) * 100.0)))
			"move_speed_multiplier":
				parts.append("скорость движения +%d%%" % int(round((value - 1.0) * 100.0)))
			"aoe_radius_multiplier":
				parts.append("радиус атак +%d%%" % int(round((value - 1.0) * 100.0)))
			"range_multiplier":
				parts.append("дальность атак +%d%%" % int(round((value - 1.0) * 100.0)))
			"knockback_multiplier":
				parts.append("отталкивание +%d%%" % int(round((value - 1.0) * 100.0)))
			"max_health_flat":
				parts.append("максимальное здоровье +%d" % int(round(value)))
			"defense_flat":
				parts.append("защита +%d%%" % int(round(value * 100.0)))
			"crit_chance_flat":
				parts.append("шанс крита +%d%%" % int(round(value * 100.0)))
	return ", ".join(parts)


func _random_event_choices() -> Array:
	var rewards := _random_rewards(2)
	var choices := [
		{
			"title": "Train",
			"description": "Gain a random characteristic upgrade.",
			"reward": rewards[0],
		},
		{
			"title": "Risky Relic",
			"description": "Потерять 15% здоровья и получить артефакт или характеристику.",
			"reward": rewards[1],
			"health_percent_cost": 0.15,
		},
		{
			"title": "Rest",
			"description": "Восстановить 25% максимального здоровья.",
			"heal_percent": 0.25,
		},
	]
	return choices


func _event_choice_button_text(event_choice: Dictionary) -> String:
	var marker := "Риск: " if bool(event_choice.get("risk", false)) else ""
	return "%s\n%s%s" % [
		str(event_choice.get("title", "Выбор")),
		marker,
		str(event_choice.get("description", "")),
	]


func _event_choice_description_text(event_choice: Dictionary) -> String:
	var marker := "Риск: " if bool(event_choice.get("risk", false)) else ""
	return "%s%s" % [marker, str(event_choice.get("description", ""))]


func _apply_event_choice(event_choice: Dictionary) -> bool:
	var temp_player = game.player_scene.instantiate()
	game.add_child(temp_player)
	if game.run_player_snapshot.is_empty():
		temp_player.configure_character(game.selected_character_id, game.selected_weapon_id)
	else:
		game.combat._restore_player_snapshot(temp_player)

	var outcome := _resolve_event_choice_outcome(event_choice, temp_player)
	_apply_event_outcome_to_player(outcome, temp_player)
	var combat_payload: Dictionary = outcome.get("combat", {})

	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()

	if not combat_payload.is_empty():
		game.pending_event_combat = combat_payload.duplicate(true)
		if outcome.has("post_combat"):
			game.pending_event_combat["post_combat"] = outcome["post_combat"]
		game.current_event_definition.clear()
		var combat_type := str(combat_payload.get("type", "battle"))
		game.combat._start_combat(false, "elite" if combat_type == "elite" else "battle")
		return true
	return false


func _resolve_event_choice_outcome(event_choice: Dictionary, temp_player: Node) -> Dictionary:
	var outcome := event_choice.duplicate(true)
	if outcome.has("random_outcomes"):
		var outcomes: Array = outcome.get("random_outcomes", [])
		if not outcomes.is_empty():
			var picked: Dictionary = outcomes[game.rng.randi_range(0, outcomes.size() - 1)]
			outcome.merge(picked.duplicate(true), true)
	if outcome.has("check"):
		var check: Dictionary = outcome.get("check", {})
		var stats: Dictionary = temp_player.get("stats")
		var stat_id := str(check.get("stat", "knowledge"))
		var difficulty := float(check.get("difficulty", 0.0))
		var passed := float(stats.get(stat_id, 0.0)) >= difficulty
		var branch: Dictionary = outcome.get("success" if passed else "failure", {})
		outcome.merge(branch.duplicate(true), true)
		outcome["check_passed"] = passed
	return outcome


func _apply_event_outcome_to_player(outcome: Dictionary, temp_player: Node) -> void:
	if outcome.has("cost_money"):
		temp_player.spend_money(game.PROGRESSION_DATA.stage_scaled_cost(int(outcome["cost_money"]), game.route_stage))
	if outcome.has("money"):
		temp_player.gain_money(int(outcome["money"]))
	if outcome.has("reward"):
		temp_player.apply_reward(outcome["reward"])
	if outcome.has("stats") or outcome.has("mods") or outcome.has("heal_percent"):
		temp_player.apply_reward({
			"kind": "event",
			"title": str(outcome.get("title", "Событие")),
			"stats": outcome.get("stats", {}),
			"mods": outcome.get("mods", {}),
			"heal_percent": outcome.get("heal_percent", 0.0),
		})
	if bool(outcome.get("random_artifact", false)):
		var artifacts := _weighted_sample(game.PROGRESSION_DATA.reward_pool(game.selected_character_id).filter(func(reward: Dictionary) -> bool:
			return str(reward.get("kind", "")) == "artifact"
		), 1)
		if not artifacts.is_empty():
			temp_player.apply_reward(artifacts[0])
	if outcome.has("health_percent_cost"):
		var cost := float(temp_player.get("max_health")) * float(outcome["health_percent_cost"])
		temp_player.set("health", max(1.0, float(temp_player.get("health")) - cost))


func _random_rewards(count: int) -> Array:
	return _weighted_sample(game.PROGRESSION_DATA.reward_pool(game.selected_character_id), count)


func _weighted_sample(pool: Array, count: int) -> Array:
	# Выбор без возврата с учетом weight (редкость артефактов растет с тиром).
	var picked := []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for entry in pool:
			total += float(entry.get("weight", 1.0))
		var roll: float = game.rng.randf() * total
		var index := 0
		for entry_index in range(pool.size()):
			roll -= float(pool[entry_index].get("weight", 1.0))
			if roll <= 0.0:
				index = entry_index
				break
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


const MAIN_STAT_SLOT_CHANCE := 0.05


func _random_level_up_rewards(count: int) -> Array:
	# Микс: улучшения оружия/класса/вторичных атрибутов + РЕДКО (~5% на слот)
	# основная характеристика. Набор уникален и фиксируется на уровень.
	var regular_pool: Array = game.PROGRESSION_DATA.level_up_rewards(game.selected_character_id)
	var stat_pool: Array = game.PROGRESSION_DATA.main_stat_level_up_rewards(game.selected_character_id)
	var rewards := []
	# Capstone «Озарение» (ветвь Знаний мета-древа, SCRUM-150): ПЕРВОЕ повышение
	# в забеге гарантированно даёт основную характеристику. Гейт по level<=2
	# (run-persistent через снапшот) — срабатывает один раз за забег.
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	if float(skill_mods.get("first_levelup_rare", 0.0)) > 0.0 and not stat_pool.is_empty() \
			and game.current_player != null and is_instance_valid(game.current_player) \
			and int(game.current_player.get("level")) <= 2:
		var forced_index: int = game.rng.randi_range(0, stat_pool.size() - 1)
		rewards.append(stat_pool[forced_index])
		stat_pool.remove_at(forced_index)
	while rewards.size() < count and (not regular_pool.is_empty() or not stat_pool.is_empty()):
		var want_rare: bool = not stat_pool.is_empty() and float(game.rng.randf()) < MAIN_STAT_SLOT_CHANCE
		var source: Array = stat_pool if (want_rare or regular_pool.is_empty()) else regular_pool
		var index: int = _weighted_level_up_index(source)
		rewards.append(source[index])
		source.remove_at(index)
	return rewards


func _weighted_level_up_index(source: Array) -> int:
	if source.size() <= 1:
		return 0
	var total := 0.0
	var weights := []
	for reward in source:
		var weight: float = game.PROGRESSION_DATA.level_up_reward_weight(reward, game.selected_character_id)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return game.rng.randi_range(0, source.size() - 1)
	var roll: float = game.rng.randf() * total
	for index in range(source.size()):
		roll -= float(weights[index])
		if roll <= 0.0:
			return index
	return source.size() - 1


func _random_shop_items(count: int) -> Array:
	var items := _weighted_sample(game.PROGRESSION_DATA.shop_items(game.route_stage), count)
	var price_mult := float(game.ascension_difficulty()["price_mult"])
	# Ветвь Богатства мета-древа (SCRUM-150): скидка магазина (shop_price_mult ≤ 0).
	var skill_mods: Dictionary = game.META_PROGRESSION.skill_modifiers(game.meta_state)
	price_mult *= maxf(1.0 + float(skill_mods.get("shop_price_mult", 0.0)), 0.1)
	# Capstone «Связи в гильдии»: гарантированный редкий (tier 3) товар на стене.
	if float(skill_mods.get("guaranteed_rare_shop", 0.0)) > 0.0 and not items.is_empty():
		var has_rare := false
		for item in items:
			if int(item.get("tier", 1)) >= 3:
				has_rare = true
				break
		if not has_rare:
			var rares: Array = (game.PROGRESSION_DATA.shop_items(game.route_stage) as Array).filter(
				func(it): return int((it as Dictionary).get("tier", 1)) >= 3)
			if not rares.is_empty():
				items[game.rng.randi_range(0, items.size() - 1)] = (rares[game.rng.randi_range(0, rares.size() - 1)] as Dictionary).duplicate(true)
	if not is_equal_approx(price_mult, 1.0):
		for item in items:
			item["cost"] = maxi(1, int(round(float(item.get("cost", 0)) * price_mult)))
	return items


func _on_player_leveled_up() -> void:
	game._play_sfx("level_up")
	game.level_up_return_to_map = not game.combat_active
	game.pending_level_ups += 1
	_show_level_up_toast()
	_update_level_up_button()


func _open_pending_level_up() -> void:
	if game.pending_level_ups <= 0:
		return

	game.push_pause("level_up")
	_show_level_up_screen(game.level_up_return_to_map)


func _show_level_up_toast() -> void:
	_spawn_level_up_effect()

	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		if game.combat_active:
			_create_hud()
		else:
			_create_menu_run_hud()

	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return

	var toast = game.LEVEL_UP_TOAST_SCENE.instantiate()
	toast.name = "LevelUpToast"
	toast.process_mode = Node.PROCESS_MODE_ALWAYS
	if toast.has_method("setup"):
		toast.setup(game.current_player, game.pending_level_ups)
	game.hud_layer.add_child(toast)


func _spawn_level_up_effect() -> void:
	if game.current_player == null or not is_instance_valid(game.current_player):
		return

	var effect = game.LEVEL_UP_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	effect.name = "LevelUpEffect"
	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(effect)
	effect.global_position = game.current_player.global_position
	if effect.has_method("setup"):
		effect.setup(game.current_player)


func _show_combat_title_banner(title: String, color: Color, big := false) -> void:
	# Баннер появления элитки/босса: имя/титул вспыхивает над ареной и гаснет,
	# бой не ставится на паузу. Самоосвобождается; привязан к HUD-слою.
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var existing: Node = game.hud_layer.get_node_or_null("CombatIntroBanner")
	if existing != null:
		existing.queue_free()
	var banner := Label.new()
	banner.name = "CombatIntroBanner"
	banner.process_mode = Node.PROCESS_MODE_ALWAYS
	banner.text = title
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 66 if big else 40)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 1.0))
	banner.add_theme_constant_override("outline_size", 9 if big else 6)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = -640.0
	banner.offset_right = 640.0
	banner.offset_top = 120.0 if big else 92.0
	banner.offset_bottom = banner.offset_top + (90.0 if big else 56.0)
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	banner.pivot_offset = Vector2(640.0, 0.0)
	game.hud_layer.add_child(banner)
	var tween := banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.18)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.1 if big else 0.7)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(banner.queue_free)


func _update_level_up_button() -> void:
	if game.pending_level_ups <= 0:
		if game.level_up_button != null and is_instance_valid(game.level_up_button):
			game.level_up_button.queue_free()
		game.level_up_button = null
		return

	var level_button_parent: CanvasLayer = game.hud_layer
	if level_button_parent == null or not is_instance_valid(level_button_parent):
		level_button_parent = game.ui_layer
	if level_button_parent == null or not is_instance_valid(level_button_parent):
		return

	if game.level_up_button == null or not is_instance_valid(game.level_up_button):
		# SCRUM-278: corner return button keeps unspent picks visible without blocking center combat.
		game.level_up_button = Button.new()
		game.level_up_button.name = "LevelUpPlusButton"
		game.level_up_button.process_mode = Node.PROCESS_MODE_ALWAYS
		game.level_up_button.anchor_left = 1.0
		game.level_up_button.anchor_right = 1.0
		game.level_up_button.anchor_top = 1.0
		game.level_up_button.anchor_bottom = 1.0
		game.level_up_button.offset_left = -412.0
		game.level_up_button.offset_right = -28.0
		game.level_up_button.offset_top = -130.0
		game.level_up_button.offset_bottom = -26.0
		_set_action_button_size(game.level_up_button, 380.0)
		game.level_up_button.tooltip_text = "Открыть выбор улучшения (непотраченные уровни)"
		game.level_up_button.add_theme_font_size_override("font_size", 22)
		_apply_fantasy_button_theme(game.level_up_button)
		game.level_up_button.pressed.connect(_open_pending_level_up)
		level_button_parent.add_child(game.level_up_button)

		var badge_panel := PanelContainer.new()
		badge_panel.name = "LevelUpPlusBadgePanel"
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.anchor_left = 1.0
		badge_panel.anchor_top = 0.0
		badge_panel.anchor_right = 1.0
		badge_panel.anchor_bottom = 0.0
		badge_panel.offset_left = -34.0
		badge_panel.offset_top = -10.0
		badge_panel.offset_right = -6.0
		badge_panel.offset_bottom = 18.0
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.84, 0.22, 1.0)
		badge_style.set_corner_radius_all(12)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		game.level_up_button.add_child(badge_panel)

		var badge := Label.new()
		badge.name = "LevelUpPlusBadge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02, 1.0))
		badge_panel.add_child(badge)

	game.level_up_button.text = "Повышение уровня (%d)" % game.pending_level_ups
	game.level_up_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var badge_label := game.level_up_button.find_child("LevelUpPlusBadge", true, false) as Label
	if badge_label != null:
		badge_label.text = str(game.pending_level_ups)


func _level_up_affinity_suffix(reward: Dictionary) -> String:
	if str(reward.get("kind", "")) != "artifact":
		return ""
	return _artifact_affinity_suffix(reward)


func _format_level_up_reward_text(reward: Dictionary) -> String:
	var preview := _level_up_reward_preview(reward)
	var interpretation := _reward_interpretation_text(reward)
	return "%s\n%s\n%s%s" % [
		str(reward.get("title", "Upgrade")),
		preview,
		str(reward.get("description", "")),
		"\n%s" % interpretation if interpretation != "" else "",
	]


func _reward_icon_id(reward: Dictionary) -> String:
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return str(stat_keys[0])
	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var modifier_id := str(modifier_keys[0])
		return str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, "artifact"))
	if str(reward.get("kind", "")) == "artifact":
		return "artifact"
	return "buff_power"


func _level_up_reward_preview(reward: Dictionary) -> String:
	var kind := "Параметр"
	if reward.has("stats"):
		kind = "Атрибут"
	elif str(reward.get("kind", "")) == "skill":
		kind = "Скилл"

	var before_stats := _active_stats_snapshot()
	var before_mods := _active_modifiers_snapshot()
	var after_stats := before_stats.duplicate(true)
	var after_mods := before_mods.duplicate(true)
	if reward.has("stats"):
		for stat_id in (reward["stats"] as Dictionary).keys():
			after_stats[stat_id] = float(after_stats.get(stat_id, 0.0)) + float(reward["stats"][stat_id])
	if reward.has("mods"):
		for modifier_id in (reward["mods"] as Dictionary).keys():
			if str(modifier_id).ends_with("_multiplier"):
				after_mods[modifier_id] = float(after_mods.get(modifier_id, 1.0)) * float(reward["mods"][modifier_id])
			else:
				after_mods[modifier_id] = float(after_mods.get(modifier_id, 0.0)) + float(reward["mods"][modifier_id])

	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		var stat_id := str(stat_keys[0])
		return "%s: %s %.0f -> %.0f" % [
			kind,
			str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id)),
			float(before_stats.get(stat_id, 0.0)),
			float(after_stats.get(stat_id, 0.0)),
		]

	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var modifier_id := str(modifier_keys[0])
		var parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, modifier_id))
		# Превью урона честное: показываем «свой» damage-параметр класса.
		if parameter_id == "damage":
			parameter_id = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
		var weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
		var before_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, before_mods, weapon_config)
		var after_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(after_stats, after_mods, weapon_config)
		return "%s: %s %s -> %s" % [
			kind,
			_level_up_parameter_label(parameter_id),
			_format_level_up_value(parameter_id, float(before_parameters.get(parameter_id, before_mods.get(modifier_id, 0.0)))),
			_format_level_up_value(parameter_id, float(after_parameters.get(parameter_id, after_mods.get(modifier_id, 0.0)))),
		]

	return kind


func _reward_interpretation_text(reward: Dictionary) -> String:
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, str(stat_keys[0]))
	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(str(modifier_keys[0]), modifier_keys[0]))
		if parameter_id == "damage":
			parameter_id = game.PROGRESSION_DATA.damage_parameter_for(game.selected_character_id)
		return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, parameter_id)
	if reward.has("affinity_mods"):
		var affinity_keys := (reward.get("affinity_mods", {}) as Dictionary).keys()
		if not affinity_keys.is_empty():
			var affinity_parameter = str(game.LEVEL_UP_MOD_DISPLAY.get(str(affinity_keys[0]), affinity_keys[0]))
			return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, affinity_parameter)
	return ""


func _active_stats_snapshot() -> Dictionary:
	if game.current_player != null and is_instance_valid(game.current_player):
		return (game.current_player.get("stats") as Dictionary).duplicate(true)
	if not game.run_player_snapshot.is_empty():
		return (game.run_player_snapshot.get("stats", {}) as Dictionary).duplicate(true)
	return game.PROGRESSION_DATA.base_stats(game.selected_character_id)


func _active_modifiers_snapshot() -> Dictionary:
	if game.current_player != null and is_instance_valid(game.current_player):
		return (game.current_player.get("run_modifiers") as Dictionary).duplicate(true)
	if not game.run_player_snapshot.is_empty():
		return (game.run_player_snapshot.get("run_modifiers", {}) as Dictionary).duplicate(true)
	return {}


func _level_up_parameter_label(parameter_id: String) -> String:
	match parameter_id:
		"damage":
			return "Урон"
		"magic_damage":
			return "Маг. урон"
		"sound_wave_damage":
			return "Звуковой урон"
		"attack_speed":
			return "Скорость атаки"
		"health_point":
			return "Макс. здоровье"
		"move_speed":
			return "Скорость"
		"aoe_radius":
			return "Радиус области"
		"pickup_radius":
			return "Радиус подбора"
		"defense":
			return "Защита"
		"attack_range":
			return "Дальность"
		"crit_chance":
			return "Шанс крита"
		"crit_damage_multiplier":
			return "Крит. урон"
		"knockback_power":
			return "Отталкивание"
		"dot_damage":
			return "Периодический урон"
		"dot_speed":
			return "Скорость тиков"
		"projectile_speed":
			return "Скорость снарядов"
		"aura_radius":
			return "Радиус ауры"
		"buff_power":
			return "Сила баффов"
		"summon_amount":
			return "Призывы"
		"absorb":
			return "Поглощение"
		"regeneration":
			return "Регенерация"
		"vampiric_amount":
			return "Вампиризм"
		"vampiric_chance":
			return "Шанс вампиризма"
		"ultimate_multiplier":
			return "Сила уник. механики"
		_:
			return parameter_id


func _format_level_up_value(parameter_id: String, value: float) -> String:
	if parameter_id in ["crit_chance", "defense", "dodge", "vampiric_chance"]:
		return "%.0f%%" % (value * 100.0)
	if parameter_id in ["attack_speed", "crit_damage_multiplier", "dot_speed", "buff_power", "ultimate_multiplier"]:
		return "%.2f" % value
	return "%.0f" % value


func _buy_shop_item_at(index: int) -> bool:
	if index < 0 or index >= game.current_shop_items.size():
		return false
	if index >= game.current_shop_purchased.size() or bool(game.current_shop_purchased[index]):
		return false
	var item: Dictionary = game.current_shop_items[index]
	if not _buy_shop_item(item):
		return false
	game.current_shop_purchased[index] = true
	_show_shop_screen()
	return true


func _buy_shop_item(item: Dictionary) -> bool:
	var temp_player = game.combat._snapshot_player_for_menu()
	if temp_player == null:
		return false

	if not temp_player.spend_money(int(item["cost"])):
		temp_player.queue_free()
		return false

	temp_player.apply_reward(item)
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()
	return true


func _apply_reward_to_active_run(reward: Dictionary) -> void:
	if game.current_player != null and is_instance_valid(game.current_player):
		game.current_player.apply_reward(reward)
		game.combat._store_player_snapshot(game.current_player)
	else:
		_apply_reward_to_run(reward)


func _apply_reward_to_run(reward: Dictionary) -> void:
	var temp_player = game.combat._snapshot_player_for_menu()
	temp_player.apply_reward(reward)
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()


func _setup_default_input_actions() -> void:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		if InputMap.action_get_events(action_name).is_empty():
			_apply_keycodes_to_action(action_name, _default_keycodes_for_action(input_action))
	_apply_saved_input_bindings()


func _apply_saved_input_bindings() -> void:
	var saved_bindings: Dictionary = game.input_bindings
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var saved_keys: Array = saved_bindings.get(action_name, [])
		if saved_keys.is_empty():
			continue
		_apply_keycodes_to_action(action_name, saved_keys)


func _default_keycodes_for_action(input_action: Dictionary) -> Array:
	var keys := []
	var default_key := int(input_action.get("default_key", 0))
	var alternate_key := int(input_action.get("alternate_key", 0))
	if default_key != 0:
		keys.append(default_key)
	if alternate_key != 0 and alternate_key != default_key:
		keys.append(alternate_key)
	return keys


func _apply_keycodes_to_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for keycode_value in keycodes:
		var keycode := int(keycode_value)
		if keycode == 0:
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _current_input_bindings() -> Dictionary:
	var result := {}
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var keys := []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
				if keycode != 0:
					keys.append(keycode)
		result[action_name] = keys
	return result


func _apply_game_cursor() -> void:
	var arrow_texture: Texture2D = game._cached_texture(game.GAME_CURSOR_PATH)
	if arrow_texture == null:
		return
	Input.set_custom_mouse_cursor(arrow_texture, Input.CURSOR_ARROW, game.GAME_CURSOR_HOTSPOT)

	var hover_texture: Texture2D = game._cached_texture(str(SHOP_CURSOR_VARIANTS["pointing_hand"]))
	if hover_texture != null:
		Input.set_custom_mouse_cursor(hover_texture, Input.CURSOR_POINTING_HAND, game.GAME_CURSOR_HOTSPOT)

	var attack_texture: Texture2D = game._cached_texture(str(SHOP_CURSOR_VARIANTS["cross"]))
	if attack_texture != null:
		Input.set_custom_mouse_cursor(attack_texture, Input.CURSOR_CROSS, game.GAME_CURSOR_HOTSPOT)


func _begin_rebind(action_name: String) -> void:
	game.pending_rebind_action = action_name
	var label := _action_label(action_name)
	var box := _create_menu_box("Клавиша: %s" % label, "Нажми новую клавишу. Esc отменяет.", "settings")

	var cancel_button := _make_button("Отмена")
	cancel_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	box.add_child(cancel_button)


func _handle_rebind_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		game.pending_rebind_action = ""
		_show_settings_menu()
		return

	var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
	var conflict_action := _binding_conflict_action(game.pending_rebind_action, keycode)
	if conflict_action != "":
		_show_rebind_conflict(game.pending_rebind_action, keycode, conflict_action)
		return

	InputMap.action_erase_events(game.pending_rebind_action)
	var new_event := InputEventKey.new()
	new_event.keycode = keycode
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(game.pending_rebind_action, new_event)

	game.input_bindings = _current_input_bindings()
	game.save_game_settings()
	game.pending_rebind_action = ""
	_show_settings_menu()


func _binding_conflict_action(target_action: String, keycode: int) -> String:
	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		if action_name == target_action:
			continue
		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey:
				var existing_key: int = int(existing_event.keycode if existing_event.keycode != 0 else existing_event.physical_keycode)
				if existing_key == keycode:
					return action_name
	return ""


func _show_rebind_conflict(target_action: String, keycode: int, conflict_action: String) -> void:
	var target_label := _action_label(target_action)
	var conflict_label := _action_label(conflict_action)
	var key_name := OS.get_keycode_string(keycode)
	var box := _create_menu_box("Клавиша занята", "%s уже используется для «%s». Выбери другую клавишу для «%s»." % [key_name, conflict_label, target_label], "settings")
	var retry_button := _make_button("Выбрать другую")
	retry_button.pressed.connect(func() -> void:
		_begin_rebind(target_action)
	)
	box.add_child(retry_button)
	var back_button := _make_button("Назад к настройкам")
	back_button.pressed.connect(func() -> void:
		game.pending_rebind_action = ""
		_show_settings_menu()
	)
	box.add_child(back_button)


func _reset_input_bindings_to_defaults() -> void:
	for input_action in game.INPUT_ACTIONS:
		_apply_keycodes_to_action(str(input_action["action"]), _default_keycodes_for_action(input_action))
	game.input_bindings = _current_input_bindings()
	game.save_game_settings()


func _binding_text(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Не назначено"

	var labels := []
	for event in events:
		if event is InputEventKey:
			var keycode: int = int(event.keycode if event.keycode != 0 else event.physical_keycode)
			labels.append(OS.get_keycode_string(keycode))
		else:
			labels.append(event.as_text())
	return " / ".join(labels)


func _action_label(action_name: String) -> String:
	for input_action in game.INPUT_ACTIONS:
		if input_action["action"] == action_name:
			return input_action["label"]

	return action_name


func _apply_video_settings() -> void:
	game.selected_resolution_index = clampi(game.selected_resolution_index, 0, game.RESOLUTION_OPTIONS.size() - 1)
	game.selected_window_mode_index = clampi(game.selected_window_mode_index, 0, game.WINDOW_MODE_OPTIONS.size() - 1)
	if DisplayServer.get_name() == "headless":
		game.save_game_settings()
		return

	var screen_count := DisplayServer.get_screen_count()
	game.selected_screen_index = clampi(game.selected_screen_index, 0, maxi(screen_count - 1, 0))
	var screen: int = game.selected_screen_index
	# usable rect учитывает масштаб ОС, док и меню-бар: окно не вылезет за экран.
	var usable := DisplayServer.screen_get_usable_rect(screen)

	match game.selected_window_mode_index:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_position(usable.position)
			DisplayServer.window_set_size(usable.size)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			var resolution: Vector2i = game.RESOLUTION_OPTIONS[game.selected_resolution_index]
			resolution.x = mini(resolution.x, usable.size.x)
			resolution.y = mini(resolution.y, usable.size.y)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_current_screen(screen)
			DisplayServer.window_set_size(resolution)
			# Центр выбранного монитора: позиция считается от origin его usable rect.
			DisplayServer.window_set_position(usable.position + (usable.size - resolution) / 2)

	game.save_game_settings()


func _show_feedback_overlay(screenshot: Image = null) -> void:
	_close_feedback_overlay()
	# Пауза при открытии формы фидбека — как Escape (оверлей PROCESS_MODE_ALWAYS,
	# поэтому ввод в форму работает на паузе). Снимается в _close_feedback_overlay.
	game.push_pause("feedback")

	game.feedback_overlay_layer = CanvasLayer.new()
	game.feedback_overlay_layer.name = "FeedbackOverlayLayer"
	game.feedback_overlay_layer.layer = 128
	game.feedback_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.feedback_overlay_layer)

	var root := Control.new()
	root.name = "FeedbackOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	game.feedback_overlay_layer.add_child(root)

	var dim := ColorRect.new()
	dim.name = "FeedbackDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "FeedbackPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470.0
	panel.offset_top = -350.0
	panel.offset_right = 470.0
	panel.offset_bottom = 350.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "FeedbackContent"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Отправить фидбек"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Опиши баг или впечатление. Скриншот ниже уже снят до открытия формы."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	box.add_child(hint)

	var text_edit := TextEdit.new()
	text_edit.name = "FeedbackTextEdit"
	text_edit.custom_minimum_size = Vector2(780, 150)
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.placeholder_text = "Что случилось? Где ты был в игре? Что ожидал увидеть?"
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.add_theme_font_size_override("font_size", 17)
	text_edit.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	text_edit.add_theme_color_override("font_placeholder_color", Color(0.66, 0.64, 0.58, 1.0))
	box.add_child(text_edit)

	var preview_frame := PanelContainer.new()
	preview_frame.name = "FeedbackScreenshotFrame"
	preview_frame.custom_minimum_size = Vector2(780, 300)
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", _character_card_style())
	box.add_child(preview_frame)

	var preview := TextureRect.new()
	preview.name = "FeedbackScreenshotPreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(760, 280)
	var safe_screenshot: Image = FEEDBACK_REPORTER_SCRIPT._normalized_screenshot(screenshot)
	preview.texture = ImageTexture.create_from_image(safe_screenshot)
	preview_frame.add_child(preview)

	var status := Label.new()
	status.name = "FeedbackStatusLabel"
	status.text = "Отправка происходит только после нажатия «Отправить»."
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.74, 0.82, 0.88, 1.0))
	box.add_child(status)

	var buttons := HBoxContainer.new()
	buttons.name = "FeedbackButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)

	var send_button := _make_button("Отправить")
	send_button.name = "FeedbackSendButton"
	_set_action_button_size(send_button, 260.0, 72.0)
	buttons.add_child(send_button)

	var cancel_button := _make_button("Отмена")
	cancel_button.name = "FeedbackCancelButton"
	_set_action_button_size(cancel_button, 220.0, 72.0)
	cancel_button.pressed.connect(_close_feedback_overlay)
	buttons.add_child(cancel_button)

	send_button.pressed.connect(func() -> void:
		send_button.disabled = true
		status.text = "Отправляем..."
		var reporter: Node = _feedback_reporter()
		reporter.connect("report_finished", func(success: bool, message: String, local_path: String) -> void:
			status.text = message if local_path == "" else "%s\n%s" % [message, local_path]
			status.add_theme_color_override("font_color", Color(0.74, 0.96, 0.74, 1.0) if success else Color(1.0, 0.82, 0.50, 1.0))
			send_button.disabled = false
		, CONNECT_ONE_SHOT)
		reporter.call("submit_report", text_edit.text, safe_screenshot, _feedback_metadata())
	)

	text_edit.grab_focus()


func _is_feedback_overlay_open() -> bool:
	return game.feedback_overlay_layer != null and is_instance_valid(game.feedback_overlay_layer)


func _close_feedback_overlay() -> void:
	if game.feedback_overlay_layer != null and is_instance_valid(game.feedback_overlay_layer):
		game.feedback_overlay_layer.queue_free()
	game.feedback_overlay_layer = null
	# Снять паузу, поставленную при открытии формы фидбека (no-op, если не стояла).
	game.pop_pause("feedback")


func _feedback_reporter() -> Node:
	var reporter: Node = game.get_node_or_null("FeedbackReporter")
	if reporter != null and is_instance_valid(reporter):
		return reporter
	reporter = FEEDBACK_REPORTER_SCRIPT.new()
	reporter.name = "FeedbackReporter"
	reporter.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(reporter)
	return reporter


func _feedback_metadata() -> Dictionary:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	return {
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"character": str(game.selected_character_id),
		"weapon": str(game.selected_weapon_id),
		"ascension": int(game.selected_ascension_level),
		"route_stage": int(game.route_stage),
		"current_node_type": str(game.current_node_type),
		"combat_active": bool(game.combat_active),
		"boss_active": bool(game.boss_combat_active),
		"screen": _current_ui_screen_name(),
		"resolution": "%dx%d" % [int(viewport_size.x), int(viewport_size.y)],
		"os": OS.get_name(),
		"timestamp": Time.get_datetime_string_from_system(),
	}


func _current_ui_screen_name() -> String:
	if game.ui_layer != null and is_instance_valid(game.ui_layer):
		for child in game.ui_layer.get_children():
			if child is Control and not str(child.name).begins_with("ScreenBackground"):
				return str(child.name)
	if game.pause_overlay_layer != null and is_instance_valid(game.pause_overlay_layer):
		return str(game.pause_overlay_layer.name)
	if game.combat_active:
		return "Combat"
	return "World"


func _create_menu_box(title: String, subtitle: String, screen_background_id := "") -> VBoxContainer:
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui_layer.add_child(root)

	if screen_background_id != "":
		_add_screen_background(root, screen_background_id)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560.0
	panel.offset_top = -330.0
	panel.offset_right = 560.0
	panel.offset_bottom = 330.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.80, 1.0))
	box.add_child(subtitle_label)

	return box


func _add_screen_background(root: Control, screen_background_id: String) -> void:
	var texture := _screen_background_texture(screen_background_id)
	if texture != null:
		var background := TextureRect.new()
		background.name = "ScreenBackground_%s" % screen_background_id
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture = texture
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)
	else:
		var fallback := ColorRect.new()
		fallback.name = "ScreenBackgroundFallback_%s" % screen_background_id
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = game.SCREEN_BACKGROUND_FALLBACK_COLORS.get(screen_background_id, Color(0.035, 0.040, 0.060, 1.0))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fallback)

	var shade := ColorRect.new()
	shade.name = "ScreenBackgroundReadableShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.44)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)


func _screen_background_texture(screen_background_id: String) -> Texture2D:
	if game.screen_background_cache.has(screen_background_id):
		return game.screen_background_cache[screen_background_id]
	var path = str(game.SCREEN_BACKGROUND_PATHS.get(screen_background_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		game.screen_background_cache[screen_background_id] = null
		return null
	var texture = game._cached_texture(path)
	game.screen_background_cache[screen_background_id] = texture
	return texture


func _create_level_up_menu_box(title: String, subtitle: String) -> VBoxContainer:
	game._clear_ui()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "LevelUpOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_add_screen_background(root, "level_up")

	var dim := ColorRect.new()
	dim.name = "LevelUpDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.035, 0.0)
	root.add_child(dim)

	var sparkle_root := Control.new()
	sparkle_root.name = "LevelUpParticles"
	sparkle_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	sparkle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sparkle_root)
	_create_level_up_burst_shapes(sparkle_root)

	var panel := PanelContainer.new()
	panel.name = "LevelUpPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560.0
	panel.offset_top = -330.0
	panel.offset_right = 560.0
	panel.offset_bottom = 330.0
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _level_up_panel_style())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var badge_label := Label.new()
	badge_label.name = "LevelUpBadge"
	badge_label.text = _level_up_badge_text()
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 18)
	badge_label.add_theme_color_override("font_color", Color(0.38, 0.95, 1.0, 1.0))
	box.add_child(badge_label)

	var hero_header := HBoxContainer.new()
	hero_header.name = "LevelUpHeroHeader"
	hero_header.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_header.add_theme_constant_override("separation", 14)
	box.add_child(hero_header)

	var hero_frame := PanelContainer.new()
	hero_frame.name = "LevelUpHeroFrame"
	hero_frame.custom_minimum_size = Vector2(92, 92)
	hero_frame.add_theme_stylebox_override("panel", _level_up_hero_style())
	hero_header.add_child(hero_frame)

	var hero_portrait := TextureRect.new()
	hero_portrait.name = "LevelUpHeroPortrait"
	hero_portrait.texture = game._cached_texture(str(game.PROGRESSION_DATA.character_config(game.selected_character_id).get("sprite_path", "")))
	hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_portrait.custom_minimum_size = Vector2(92, 92)
	hero_frame.add_child(hero_portrait)

	var title_label := Label.new()
	title_label.name = "LevelUpTitle"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.scale = Vector2(1.18, 1.18)
	title_label.modulate.a = 0.0
	title_label.add_theme_font_size_override("font_size", 50)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30, 1.0))
	box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "LevelUpSubtitle"
	subtitle_label.text = subtitle
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
	box.add_child(subtitle_label)

	return box


func _create_level_up_burst_shapes(parent: Control) -> void:
	var center = game.ARENA_CENTER
	for index in range(12):
		var ray := ColorRect.new()
		ray.name = "LevelUpRay%d" % index
		ray.color = Color(1.0, 0.78, 0.24, 0.0)
		ray.position = center
		ray.size = Vector2(240.0 + float(index % 3) * 42.0, 4.0)
		ray.pivot_offset = Vector2(0.0, 2.0)
		ray.rotation = TAU * float(index) / 12.0
		parent.add_child(ray)

	for index in range(20):
		var spark := ColorRect.new()
		spark.name = "LevelUpSpark%d" % index
		spark.color = Color(0.38, 0.95, 1.0, 0.0) if index % 2 == 0 else Color(1.0, 0.78, 0.24, 0.0)
		spark.position = center
		spark.size = Vector2(8.0, 8.0)
		spark.pivot_offset = Vector2(4.0, 4.0)
		parent.add_child(spark)


func _start_level_up_intro(panel: Node, title_label: Node, reward_buttons: Array, sparkle_root: Node) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	await game.get_tree().process_frame
	if panel == null or not is_instance_valid(panel) or game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return

	var level_up_panel := panel as PanelContainer
	if level_up_panel == null:
		return
	level_up_panel.pivot_offset = level_up_panel.size * 0.5
	var dim = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpDim") as ColorRect
	if dim != null:
		var dim_tween = dim.create_tween()
		dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		dim_tween.tween_property(dim, "color:a", 0.68, 0.16)

	var panel_tween = level_up_panel.create_tween()
	panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.set_trans(Tween.TRANS_BACK)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(level_up_panel, "scale", Vector2.ONE, 0.34)
	panel_tween.parallel().tween_property(level_up_panel, "modulate:a", 1.0, 0.18)

	var title := title_label as Label
	if title != null and is_instance_valid(title):
		title.pivot_offset = title.size * 0.5
		var title_tween = title.create_tween()
		title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		title_tween.set_trans(Tween.TRANS_BACK)
		title_tween.set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title, "scale", Vector2.ONE, 0.28)
		title_tween.parallel().tween_property(title, "modulate:a", 1.0, 0.18)

	_start_level_up_button_intro(reward_buttons)
	_start_level_up_burst_intro(sparkle_root)


func _start_level_up_button_intro(reward_buttons: Array) -> void:
	for index in range(reward_buttons.size()):
		var button := reward_buttons[index] as Button
		if button == null or not is_instance_valid(button):
			continue
		button.modulate.a = 0.0
		button.scale = Vector2(0.94, 0.94)
		button.pivot_offset = button.size * 0.5
		var button_tween = button.create_tween()
		button_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		button_tween.set_trans(Tween.TRANS_CUBIC)
		button_tween.set_ease(Tween.EASE_OUT)
		button_tween.tween_interval(0.10 + float(index) * 0.07)
		button_tween.tween_property(button, "scale", Vector2.ONE, 0.22)
		button_tween.parallel().tween_property(button, "modulate:a", 1.0, 0.18)


func _start_level_up_burst_intro(sparkle_root: Node) -> void:
	if sparkle_root == null or not is_instance_valid(sparkle_root):
		return

	var center = game.ARENA_CENTER
	for child in sparkle_root.get_children():
		if not child is ColorRect:
			continue
		var rect := child as ColorRect
		var tween = rect.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		if rect.name.begins_with("LevelUpRay"):
			rect.position = center
			rect.scale = Vector2(0.12, 1.0)
			tween.tween_property(rect, "scale", Vector2(1.0, 1.0), 0.24)
			tween.parallel().tween_property(rect, "color:a", 0.32, 0.10)
			tween.tween_property(rect, "color:a", 0.0, 0.30)
		else:
			var index := int(str(rect.name).trim_prefix("LevelUpSpark"))
			var angle := TAU * float(index) / 20.0
			var distance := 120.0 + float(index % 5) * 26.0
			rect.position = center
			rect.scale = Vector2(0.35, 0.35)
			tween.tween_interval(float(index % 4) * 0.035)
			tween.tween_property(rect, "position", center + Vector2.RIGHT.rotated(angle) * distance, 0.34)
			tween.parallel().tween_property(rect, "scale", Vector2(1.0, 1.0), 0.18)
			tween.parallel().tween_property(rect, "color:a", 0.92, 0.10)
			tween.tween_property(rect, "color:a", 0.0, 0.28)


func _level_up_badge_text() -> String:
	if game.current_player != null and is_instance_valid(game.current_player):
		return "УРОВЕНЬ %d" % int(game.current_player.get("level"))
	return "НОВЫЙ УРОВЕНЬ"


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = _action_button_size()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button_control(button)
	return button


func _add_text_action_block(parent: Control, title: String, description: String, action_text := "Выбрать", button_name := "") -> Button:
	var block := VBoxContainer.new()
	block.name = "%sBlock" % button_name if button_name != "" else "TextActionBlock"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 8)
	parent.add_child(block)

	var frame := PanelContainer.new()
	frame.name = "%sInfoFrame" % button_name if button_name != "" else "TextActionInfoFrame"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _character_card_style())
	block.add_child(frame)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 3)
	frame.add_child(text_box)

	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	text_box.add_child(title_label)

	if description.strip_edges() != "":
		var desc_label := Label.new()
		desc_label.text = description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76, 1.0))
		text_box.add_child(desc_label)

	var button := _make_button(action_text)
	if button_name != "":
		button.name = button_name
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_action_button_size(button, STANDARD_ACTION_BUTTON_WIDTH)
	block.add_child(button)
	return button


func _make_compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = COMPACT_UTILITY_BUTTON_SIZE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	_apply_compact_button_theme(button)
	return button


func _action_button_size(width := STANDARD_ACTION_BUTTON_WIDTH) -> Vector2:
	return Vector2(minf(width, MAX_ACTION_BUTTON_VISUAL_WIDTH), STANDARD_ACTION_BUTTON_HEIGHT)


func _set_action_button_size(button: Button, width := STANDARD_ACTION_BUTTON_WIDTH, height := STANDARD_ACTION_BUTTON_HEIGHT) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(minf(width, MAX_ACTION_BUTTON_VISUAL_WIDTH), height)
	_apply_fantasy_button_theme(button)


func _style_button_control(button: Button) -> void:
	_apply_fantasy_button_theme(button)
	button.add_theme_font_size_override("font_size", 16)


func _apply_fantasy_button_theme(button: Button, variant := "default") -> void:
	var role := _button_role(button, variant)
	button.add_theme_stylebox_override("normal", _button_state_style(button, role, "normal"))
	button.add_theme_stylebox_override("hover", _button_state_style(button, role, "hover"))
	button.add_theme_stylebox_override("pressed", _button_state_style(button, role, "pressed"))
	button.add_theme_stylebox_override("disabled", _button_state_style(button, role, "disabled"))
	button.add_theme_stylebox_override("focus", _button_state_style(button, role, "hover", BUTTON_NEUTRAL_FOCUS_TINT))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _apply_static_level_up_return_button_theme(button: Button) -> void:
	var style := _level_up_return_button_style()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.58, 1.0))
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_disabled_color", Color(0.78, 0.70, 0.48, 1.0))
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _level_up_return_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.035, 0.025, 1.0)
	style.border_color = Color(0.96, 0.72, 0.24, 1.0)
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.content_margin_left = 24
	style.content_margin_top = 14
	style.content_margin_right = 24
	style.content_margin_bottom = 14
	return style


func _button_role(button: Button, variant := "default") -> String:
	if variant == "danger":
		return "danger"
	if variant in ["reward", "level_up", "primary"]:
		return "primary"
	var text := button.text.to_lower()
	if text.contains("выйти") or text.contains("покинуть") or text.contains("смерть") or text.contains("поражение"):
		return "danger"
	if text.contains("начать") or text.contains("выбрать") or text.contains("купить") or text.contains("получить") or text.contains("продолжить"):
		return "primary"
	return "secondary"


func _button_asset_type(button: Button, variant := "default") -> String:
	var button_name: String = button.name if button != null else ""
	var button_text: String = button.text.to_lower() if button != null else ""
	var size: Vector2 = button.custom_minimum_size if button != null else _action_button_size()
	if button_name.begins_with("MainMenu"):
		return "main_menu"
	if button_name == "HeroSelectChooseButton":
		return "hero_confirm"
	if button_name == "LevelUpPlusButton":
		return "main_menu"
	if button_name == "SettingsResetAudioButton":
		return "reset_audio"
	if button_name == "SettingsResetBindingsButton":
		return "reset_bindings"
	if button_name.begins_with("CodexTab_"):
		return "codex_tab"
	if button_name.begins_with("AttributeOffer_"):
		return "attr_selector"
	if button_name.begins_with("RunPause"):
		return "pause"
	if button_name.begins_with("QuitConfirm"):
		return "pause"
	if button_name == "UpgradeFabButton":
		return "fab"
	if button_name.begins_with("BindingButton_") or button_name == "SettingsAimModeOption":
		return "rebind"
	if button_name in ["AscensionMinusButton", "AscensionPlusButton"] or size.x <= 64.0:
		return "utility"
	if variant == "level_up" or button_name == "LevelUpButton":
		return "back_l"
	if button_text == "назад":
		if size.x <= 180.0:
			return "back_s"
		if size.x <= 300.0:
			return "back_m"
		return "back_l"
	if variant in ["reward", "primary"] and size.x >= 540.0:
		return "attr_selector"
	if size.y <= 66.0:
		if size.x <= 70.0:
			return "utility"
		if size.x <= 300.0:
			return "pause"
		return "rebind"
	if size.x >= 540.0:
		return "max"
	if size.x >= 430.0:
		return "reset_bindings"
	if size.x >= 400.0:
		return "standard"
	if size.x >= 360.0:
		return "back_l"
	if size.x >= 300.0:
		return "hero_confirm"
	if size.x >= 240.0:
		return "back_m"
	return "back_s"


func _button_state_style(button: Button, _role: String, state: String, tint := Color.WHITE) -> StyleBox:
	var button_type := _button_asset_type(button)
	var type_map: Dictionary = RED_GOLD_BUTTON_TEXTURES.get(button_type, RED_GOLD_BUTTON_TEXTURES["standard"])
	var texture_state := "normal" if state == "hover" else state
	var path := str(type_map.get(texture_state, type_map.get("normal", GLOBAL_BUTTON_FRAME_PATH)))
	var final_tint := BUTTON_NEUTRAL_HOVER_TINT if state == "hover" and tint == Color.WHITE else tint
	var margins: Vector4 = RED_GOLD_BUTTON_MARGINS.get(button_type, Vector4(84, 30, 84, 32))
	var content: Vector4 = RED_GOLD_BUTTON_CONTENT.get(button_type, Vector4(76, 14, 76, 14))
	return _global_texture_style(path, margins, final_tint, content)


func _apply_compact_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_state_style(button, "secondary", "normal"))
	button.add_theme_stylebox_override("hover", _button_state_style(button, "secondary", "hover"))
	button.add_theme_stylebox_override("pressed", _button_state_style(button, "secondary", "pressed"))
	button.add_theme_stylebox_override("focus", _button_state_style(button, "secondary", "hover", BUTTON_NEUTRAL_FOCUS_TINT))
	button.add_theme_stylebox_override("disabled", _button_state_style(button, "secondary", "disabled"))
	button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.80, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _compact_button_style(hovered := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.085, 0.78)
	style.border_color = Color(0.58, 0.48, 0.28, 0.86)
	if hovered:
		style.bg_color = Color(0.12, 0.10, 0.075, 0.92)
		style.border_color = Color(0.92, 0.72, 0.32, 1.0)
	if pressed:
		style.bg_color = Color(0.055, 0.060, 0.070, 0.96)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.58)
		style.border_color = Color(0.24, 0.24, 0.25, 0.72)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


func _hero_select_compact_choice_style(hovered := false, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.058, 0.064, 0.075, 0.80)
	style.border_color = Color(0.56, 0.50, 0.36, 0.82)
	if hovered:
		style.bg_color = Color(0.080, 0.084, 0.090, 0.92)
		style.border_color = Color(0.78, 0.72, 0.58, 0.96)
	if pressed:
		style.bg_color = Color(0.045, 0.050, 0.058, 0.96)
	style.set_corner_radius_all(7)
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_top = 2
	style.content_margin_right = 6
	style.content_margin_bottom = 2
	return style


func _weapon_card_style(hovered := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.060, 0.074, 0.82)
	style.border_color = Color(0.50, 0.42, 0.25, 0.72)
	if hovered:
		style.bg_color = Color(0.085, 0.075, 0.060, 0.92)
		style.border_color = Color(0.92, 0.72, 0.30, 0.96)
	if pressed:
		style.bg_color = Color(0.045, 0.050, 0.060, 0.96)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.55)
		style.border_color = Color(0.22, 0.23, 0.25, 0.65)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	return style


func _level_up_text_field_style(hovered := false, rare := false, pressed := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.060, 0.050, 0.88) if rare else Color(0.052, 0.058, 0.074, 0.86)
	style.border_color = Color(0.92, 0.72, 0.28, 0.98) if rare else Color(0.46, 0.52, 0.58, 0.82)
	if hovered:
		style.bg_color = Color(0.095, 0.080, 0.052, 0.94) if rare else Color(0.075, 0.082, 0.098, 0.94)
		style.border_color = Color(1.0, 0.84, 0.34, 1.0) if rare else Color(0.72, 0.82, 0.90, 0.94)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.12)
	if disabled:
		style.bg_color = Color(0.04, 0.045, 0.055, 0.56)
		style.border_color = Color(0.25, 0.25, 0.27, 0.70)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2 if rare else 1)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	return label


func _panel_style() -> StyleBox:
	return _unified_frame_style("global_panel")


func _level_up_panel_style() -> StyleBox:
	return _unified_frame_style("level_panel", Color(1.08, 1.03, 1.10, 1.0))


func _level_up_hero_style() -> StyleBox:
	return _unified_frame_style("hero_card", Color(0.82, 1.06, 1.10, 1.0))


func _hero_portrait_style() -> StyleBox:
	return _unified_frame_style("hero_card", Color(1.08, 0.98, 0.76, 1.0))


func _card_hover_style() -> StyleBox:
	return _unified_frame_style("card_hover", Color(1.08, 1.08, 1.08, 1.0))


func _character_card_style() -> StyleBox:
	return _unified_frame_style("card_frame")


func _hero_select_frame_style(frame_type: String, tint := Color.WHITE) -> StyleBox:
	var path: String = HERO_SELECT_FRAME_TEXTURES.get(frame_type, HERO_SELECT_FRAME_TEXTURES["dossier"])
	var margins: Vector4 = HERO_SELECT_FRAME_MARGINS.get(frame_type, Vector4(40, 40, 40, 40))
	var content: Vector4 = HERO_SELECT_FRAME_CONTENT.get(frame_type, Vector4(16, 16, 16, 16))
	return _global_texture_style(path, margins, tint, content)


func _apply_hero_select_button_frame(button: Button, frame_type: String) -> void:
	button.add_theme_stylebox_override("normal", _hero_select_frame_style(frame_type))
	button.add_theme_stylebox_override("hover", _hero_select_frame_style(frame_type, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _hero_select_frame_style(frame_type, Color(0.88, 0.82, 0.74, 1.0)))
	button.add_theme_stylebox_override("focus", _hero_select_frame_style(frame_type, BUTTON_NEUTRAL_FOCUS_TINT))
	button.add_theme_stylebox_override("disabled", _hero_select_frame_style(frame_type, Color(0.62, 0.62, 0.62, 1.0)))


func _button_style(background: Color, _border: Color, _shadow_alpha := 0.38, _border_width := 2) -> StyleBox:
	var tint := background.lightened(0.38)
	tint.a = 1.0
	return _global_texture_style(GLOBAL_BUTTON_FRAME_PATH, Vector4(34, 26, 34, 28), tint, Vector4(18, 12, 18, 14))


func _bar_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(6)
	return style


func _slider_track_style(background: Color, border := Color(0.0, 0.0, 0.0, 0.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(9)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _global_texture_style(path: String, margins: Vector4, tint := Color.WHITE, content := Vector4.ZERO, tile_edges := false) -> StyleBox:
	var texture: Texture2D = game._cached_texture(path)
	if texture == null:
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.06, 0.08, 0.12, 0.94)
		fallback.border_color = Color(0.95, 0.78, 0.32, 0.85)
		fallback.set_border_width_all(2)
		fallback.set_corner_radius_all(8)
		fallback.content_margin_left = content.x
		fallback.content_margin_top = content.y
		fallback.content_margin_right = content.z
		fallback.content_margin_bottom = content.w
		return fallback
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	if tile_edges:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.modulate_color = tint
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


func _unified_frame_style(frame_type: String, tint := Color.WHITE, center_fill := true) -> StyleBox:
	var content: Vector4 = UNIFIED_FRAME_CONTENT.get(frame_type, UNIFIED_FRAME_CONTENT.get("global_panel", Vector4(24, 24, 24, 24)))
	var path := UNIFIED_MASTER_FILL_FRAME_PATH if center_fill else GLOBAL_PANEL_FRAME_PATH
	return _global_texture_style(path, UNIFIED_FRAME_TEXTURE_MARGINS, tint, content, true)


func _ornate_frame_style(path: String, frame_type: String, tint := Color.WHITE) -> StyleBox:
	var margins: Vector4 = ORNATE_FRAME_MARGINS.get(frame_type, Vector4(30, 30, 30, 30))
	var content: Vector4 = ORNATE_FRAME_CONTENT.get(frame_type, Vector4(12, 12, 12, 12))
	return _global_texture_style(path, margins, tint, content)


func _style_slider(slider: HSlider) -> void:
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_stylebox_override("slider", _slider_track_style(Color(0.035, 0.045, 0.065, 0.96), Color(0.55, 0.42, 0.18, 0.85)))
	slider.add_theme_stylebox_override("grabber_area", _slider_track_style(Color(0.86, 0.62, 0.20, 0.82), Color(1.0, 0.82, 0.36, 0.90)))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_track_style(Color(1.0, 0.76, 0.28, 0.95), Color(1.0, 0.92, 0.54, 1.0)))
	slider.add_theme_constant_override("center_grabber", 1)
	var grabber: Texture2D = game._cached_texture(SYSTEM_SLIDER_GRABBER_PATH)
	if grabber != null:
		slider.add_theme_icon_override("grabber", grabber)
		slider.add_theme_icon_override("grabber_highlight", grabber)
		slider.add_theme_icon_override("grabber_disabled", grabber)


func _style_checkbox(toggle: CheckBox) -> void:
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var unchecked: Texture2D = game._cached_texture(SYSTEM_CHECKBOX_UNCHECKED_PATH)
	var checked: Texture2D = game._cached_texture(SYSTEM_CHECKBOX_CHECKED_PATH)
	if unchecked != null:
		toggle.add_theme_icon_override("unchecked", unchecked)
		toggle.add_theme_icon_override("unchecked_disabled", unchecked)
	if checked != null:
		toggle.add_theme_icon_override("checked", checked)
		toggle.add_theme_icon_override("checked_disabled", checked)
	toggle.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	toggle.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.54, 1.0))
	toggle.add_theme_color_override("font_pressed_color", Color(0.70, 1.0, 0.92, 1.0))


func _create_hud() -> void:
	game._clear_hud()
	game.hud_layer = CanvasLayer.new()
	game.hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.hud_layer)

	var root := Control.new()
	root.name = "CombatHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)

	_create_resource_hud_panel(root, Vector2(20, 18))
	_create_combat_timer_panel(root)
	_create_artifact_hud_row(root)
	_create_damage_flash_overlay(root)
	root.resized.connect(func() -> void:
		_layout_combat_hud(root)
	)
	_layout_combat_hud(root)
	call_deferred("_layout_combat_hud", root)
	_update_level_up_button()
	_update_hud()


const ROMAN_NUMERALS := ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]


func _create_combat_timer_panel(root: Control) -> void:
	# Индикатор уровня возвышения (римская цифра) — поверх любого боя.
	if game.selected_ascension_level > 0:
		var asc_badge := PanelContainer.new()
		asc_badge.name = "AscensionHudBadge"
		asc_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		asc_badge.position = Vector2(0, 18)
		asc_badge.custom_minimum_size = Vector2(54, 44)
		asc_badge.add_theme_stylebox_override("panel", _timer_panel_style(false))
		asc_badge.tooltip_text = "Возвышение %d\n%s" % [game.selected_ascension_level, "\n".join(game.PROGRESSION_DATA.ascension_modifier_lines(game.selected_ascension_level))]
		root.add_child(asc_badge)
		var asc_text := Label.new()
		asc_text.text = ROMAN_NUMERALS[clampi(game.selected_ascension_level, 0, 10)]
		asc_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		asc_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		asc_text.add_theme_font_size_override("font_size", 24)
		asc_text.add_theme_color_override("font_color", Color(1.0, 0.74, 0.30, 1.0))
		asc_badge.add_child(asc_text)

	# На босс-файтах таймера нет — панель не создается вовсе.
	if game.boss_combat_active:
		game.timer_label = null
		return
	var panel := PanelContainer.new()
	panel.name = "CombatTimerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(0, 14)
	panel.custom_minimum_size = Vector2(172, 52)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _timer_panel_style(false))
	root.add_child(panel)

	var label := Label.new()
	label.name = "CombatTimerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	panel.add_child(label)
	game.timer_label = label


func _timer_panel_style(alarm: bool) -> StyleBox:
	var tint := Color(1.22, 0.82, 0.72, 1.0) if alarm else Color.WHITE
	return _unified_frame_style("timer_panel", tint)


func _create_artifact_hud_row(root: Control) -> void:
	var row := HFlowContainer.new()
	row.name = "ArtifactHudRow"
	row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.position = Vector2(0, 16)
	row.custom_minimum_size = Vector2(402, 104)
	row.alignment = FlowContainer.ALIGNMENT_END
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)


func _layout_combat_hud(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var viewport_width := maxf(root.size.x, root.get_viewport_rect().size.x)
	if viewport_width <= 0.0:
		viewport_width = 1280.0
	var margin := 18.0
	var gap := 14.0
	var timer_size := Vector2(172, 52)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource != null:
		var resource_width := clampf(viewport_width * 0.50, 540.0, 750.0)
		if viewport_width <= 1280.0:
			resource_width = minf(resource_width, 600.0)
		resource.set_anchors_preset(Control.PRESET_TOP_LEFT)
		resource.position = Vector2(margin, 18.0)
		resource.custom_minimum_size = Vector2(resource_width, 78.0)
		resource.size = resource.custom_minimum_size
	var resource_right := margin
	if resource != null:
		resource_right = resource.position.x + resource.custom_minimum_size.x

	var timer_panel := root.find_child("CombatTimerPanel", true, false) as PanelContainer
	var timer_left := viewport_width * 0.5 - timer_size.x * 0.5
	if timer_panel != null:
		var right_limit := viewport_width - timer_size.x - margin
		if timer_left < resource_right + gap:
			timer_left = minf(resource_right + gap, right_limit)
			if timer_left < resource_right + gap:
				var narrow_resource_width := maxf(480.0, timer_left - gap - margin)
				if resource != null:
					resource.custom_minimum_size.x = narrow_resource_width
					resource.size.x = narrow_resource_width
					resource_right = resource.position.x + resource.custom_minimum_size.x
				timer_left = maxf(resource_right + gap, margin)
		timer_left = minf(timer_left, right_limit)
		timer_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		timer_panel.position = Vector2(timer_left, 14.0)
		timer_panel.custom_minimum_size = timer_size
		timer_panel.size = timer_size

	var asc_badge := root.find_child("AscensionHudBadge", true, false) as PanelContainer
	if asc_badge != null:
		var anchor_left := timer_left + timer_size.x + 8.0
		if timer_panel == null:
			anchor_left = maxf(viewport_width * 0.5 - 27.0, resource_right + gap)
		if anchor_left + 54.0 > viewport_width - margin:
			anchor_left = maxf(margin, timer_left - 62.0)
		asc_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		asc_badge.position = Vector2(anchor_left, 18.0)
		asc_badge.custom_minimum_size = Vector2(54, 44)
		asc_badge.size = asc_badge.custom_minimum_size

	var artifact_row := root.find_child("ArtifactHudRow", true, false) as HFlowContainer
	if artifact_row != null:
		var row_width := clampf(viewport_width * 0.28, 220.0, 402.0)
		var row_left := viewport_width - row_width - margin
		var row_top := 16.0
		var occupied_right := resource_right
		if timer_panel != null:
			occupied_right = maxf(occupied_right, timer_panel.position.x + timer_size.x)
		if asc_badge != null:
			occupied_right = maxf(occupied_right, asc_badge.position.x + asc_badge.custom_minimum_size.x)
		if row_left < occupied_right + gap:
			row_top = 88.0
		artifact_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		artifact_row.position = Vector2(row_left, row_top)
		artifact_row.custom_minimum_size = Vector2(row_width, 104.0)
		artifact_row.size = artifact_row.custom_minimum_size


func _refresh_artifact_hud_row() -> void:
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var row := game.hud_layer.find_child("ArtifactHudRow", true, false) as HFlowContainer
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	for artifact in _player_artifacts():
		var artifact_id := str(artifact.get("id", ""))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _artifact_icon_texture(artifact_id)
		icon.tooltip_text = _artifact_tooltip(artifact)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(icon)


func _player_artifact_count() -> int:
	# Дешевый счетчик для ежекадрового HUD-снапшота (без нормализации списка).
	if game.current_player != null and is_instance_valid(game.current_player):
		return (game.current_player.get("artifacts") as Array).size()
	return (game.run_player_snapshot.get("artifacts", []) as Array).size()


func _player_artifacts() -> Array:
	var raw: Array = []
	if game.current_player != null and is_instance_valid(game.current_player):
		raw = game.current_player.get("artifacts")
	else:
		raw = game.run_player_snapshot.get("artifacts", [])
	var normalized := []
	for entry in raw:
		if entry is Dictionary:
			normalized.append(entry)
		else:
			# Совместимость со старым форматом, где хранился только title.
			normalized.append({"id": "", "title": str(entry)})
	return normalized


func _artifact_icon_texture(artifact_id: String) -> Texture2D:
	var path := "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, artifact_id]
	if artifact_id != "" and ResourceLoader.exists(path):
		return game._cached_texture(path)
	return game.UIIconRegistry.texture_for("buff_power")


const TIER_LABELS := {1: "Тир 1", 2: "Тир 2 — редкий", 3: "Тир 3 — легендарный"}
const TIER_COLORS := {
	1: Color(0.80, 0.86, 0.94, 1.0),
	2: Color(0.46, 0.78, 1.0, 1.0),
	3: Color(1.0, 0.74, 0.30, 1.0),
}
const CLASS_RU := {
	"berserk": "Берсерк",
	"dark_mage": "Темный маг",
	"guitarist": "Гитарист",
	"assassin": "Ассасин",
	"ranger": "Рейнджер",
	"doctor": "Доктор",
	"chemist": "Химик",
	"knight": "Рыцарь",
	"druid": "Друид",
}


func _artifact_affinity_note(definition: Dictionary) -> Dictionary:
	# С 0.2 классовая часть больше не пропадает: affinity теперь объясняет,
	# как артефакт интерпретируется текущим классом.
	var affinity: Array = definition.get("class_affinity", definition.get("classes", []))
	if affinity.is_empty() or affinity.has(game.selected_character_id):
		return {}
	var affinity_keys := (definition.get("affinity_mods", {}) as Dictionary).keys()
	var parameter_id := "buff_power"
	if not affinity_keys.is_empty():
		parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(str(affinity_keys[0]), affinity_keys[0]))
	var text := "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, parameter_id)
	return {"text": text, "color": Color(0.55, 0.92, 1.0, 1.0)}


func _artifact_affinity_suffix(definition: Dictionary) -> String:
	var note := _artifact_affinity_note(definition)
	if note.is_empty():
		return ""
	return "
[%s]" % note["text"]


func _artifact_tier_text(definition: Dictionary) -> String:
	return str(TIER_LABELS.get(int(definition.get("tier", 1)), "Тир 1"))


func _artifact_tier_color(definition: Dictionary) -> Color:
	return TIER_COLORS.get(int(definition.get("tier", 1)), TIER_COLORS[1])


func _artifact_tooltip(artifact: Dictionary) -> String:
	var artifact_id := str(artifact.get("id", ""))
	var title := str(artifact.get("title", ""))
	var definition: Dictionary = game.PROGRESSION_DATA.artifact_definition(artifact_id)
	var description := str(definition.get("description", ""))
	if description == "":
		return title
	return "%s (%s)
%s%s" % [title, _artifact_tier_text(definition), description, _artifact_affinity_suffix(definition)]


func _create_damage_flash_overlay(root: Control) -> void:
	var flash := ColorRect.new()
	flash.name = "DamageFlashOverlay"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.85, 0.08, 0.06, 1.0)
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Затухание вспышки должно замирать вместе с паузой, хотя HUD-слой ALWAYS.
	flash.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(flash)


func _on_player_damaged(_amount: float) -> void:
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var flash := game.hud_layer.find_child("DamageFlashOverlay", true, false) as ColorRect
	if flash == null:
		return
	var existing_tween: Tween = flash.get_meta("flash_tween") if flash.has_meta("flash_tween") else null
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	# Фиксированный пик не дает вспышке стакаться до непрозрачности при частых попаданиях.
	flash.modulate.a = 0.20
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.set_meta("flash_tween", tween)


func _create_menu_run_hud() -> void:
	game._clear_hud()
	game.hud_layer = CanvasLayer.new()
	game.hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.hud_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)
	_create_resource_hud_panel(root, Vector2(18, 16))
	_update_hud()
	_update_level_up_button()


func _create_resource_hud_panel(parent: Control, position: Vector2) -> void:
	game._last_hud_snapshot.clear()
	var panel := PanelContainer.new()
	panel.name = "RunResourceHud"
	panel.position = position
	panel.custom_minimum_size = Vector2(650, 78)
	panel.add_theme_stylebox_override("panel", _hud_panel_style())
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	game.health_bar = _add_hud_resource_card(row, "hp", "HP", Color(0.92, 0.08, 0.08, 1.0))
	game.xp_bar = _add_hud_resource_card(row, "xp", "XP", Color(0.25, 0.78, 1.0, 1.0))
	_add_hud_money_card(row)
	game.ultimate_bar = _add_hud_resource_card(row, "ultimate_multiplier", "ULT", Color(0.95, 0.68, 1.0, 1.0))


func _add_hud_resource_card(parent: HBoxContainer, icon_id: String, label_text: String, fill_color: Color) -> ProgressBar:
	var card := PanelContainer.new()
	card.name = "Hud%sCard" % label_text
	card.custom_minimum_size = Vector2(126, 54)
	card.add_theme_stylebox_override("panel", _hud_card_style())
	parent.add_child(card)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	card.add_child(line)
	line.add_child(game.UIIconRegistry.make_icon(icon_id, Vector2(30, 30)))

	var value_box := VBoxContainer.new()
	value_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_box.add_theme_constant_override("separation", 3)
	line.add_child(value_box)

	var value_label := Label.new()
	value_label.name = "Hud%sLabel" % label_text
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1.0))
	value_box.add_child(value_label)
	if icon_id == "hp":
		game.health_label = value_label
	elif icon_id == "xp":
		game.xp_label = value_label
	elif icon_id == "ultimate_multiplier":
		game.ultimate_label = value_label

	var bar := ProgressBar.new()
	bar.name = "Hud%sBar" % label_text
	bar.custom_minimum_size = Vector2(62, 10)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.06, 0.07, 0.09, 0.94)))
	bar.add_theme_stylebox_override("fill", _bar_style(fill_color))
	value_box.add_child(bar)
	return bar


func _add_hud_money_card(parent: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.name = "HudMoneyCard"
	card.custom_minimum_size = Vector2(88, 54)
	card.add_theme_stylebox_override("panel", _hud_card_style())
	parent.add_child(card)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	card.add_child(line)
	line.add_child(game.UIIconRegistry.make_icon("money", Vector2(30, 30)))

	game.money_label = Label.new()
	game.money_label.name = "HudMoneyLabel"
	game.money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.money_label.add_theme_font_size_override("font_size", 18)
	game.money_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))
	line.add_child(game.money_label)


func _hud_panel_style() -> StyleBox:
	return _unified_frame_style("hud_panel")


func _hud_card_style() -> StyleBox:
	return _unified_frame_style("hud_card")


func _run_resource_values() -> Dictionary:
	var hp = float(game.run_player_snapshot.get("health", game.run_player_snapshot.get("max_health", 0.0)))
	var max_hp = float(game.run_player_snapshot.get("max_health", 0.0))
	var xp = int(game.run_player_snapshot.get("xp", 0))
	var xp_to_next = int(game.run_player_snapshot.get("xp_to_next", 5))
	var money := _run_money()
	var ultimate_charge := 0.0
	var ultimate_max := 100.0
	if game.current_player != null and is_instance_valid(game.current_player):
		hp = float(game.current_player.get("health"))
		max_hp = float(game.current_player.get("max_health"))
		xp = int(game.current_player.get("xp"))
		xp_to_next = int(game.current_player.get("xp_to_next"))
		money = int(game.current_player.get("money"))
		ultimate_charge = float(game.current_player.get("ultimate_charge"))
		ultimate_max = float(game.current_player.get("ultimate_max_charge"))
	return {
		"hp": hp,
		"max_hp": max_hp,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"money": money,
		"ultimate_charge": ultimate_charge,
		"ultimate_max": ultimate_max,
	}


func _run_money() -> int:
	if game.current_player != null and is_instance_valid(game.current_player):
		return int(game.current_player.get("money"))
	return int(game.run_player_snapshot.get("money", 0))


func _update_hud() -> void:
	if game.health_bar == null or game.health_label == null:
		return

	var values: Dictionary = _run_resource_values()
	var max_hp: float = max(float(values["max_hp"]), 1.0)
	var hp: float = clamp(float(values["hp"]), 0.0, max_hp)
	var xp_to_next: int = max(int(values["xp_to_next"]), 1)
	var xp: int = clamp(int(values["xp"]), 0, xp_to_next)
	var money: int = int(values["money"])
	var ultimate_max: float = maxf(float(values.get("ultimate_max", 100.0)), 1.0)
	var ultimate_charge: float = clampf(float(values.get("ultimate_charge", 0.0)), 0.0, ultimate_max)
	var timer_seconds := -1
	if game.combat_active and not game.boss_combat_active:
		timer_seconds = maxi(int(ceil(game.round_time_left)), 0)
	var next_snapshot := {
		"hp": int(ceil(hp)),
		"max_hp": int(ceil(max_hp)),
		"xp": xp,
		"xp_to_next": xp_to_next,
		"money": money,
		"ultimate": int(floor(ultimate_charge)),
		"ultimate_max": int(floor(ultimate_max)),
		"timer": timer_seconds,
		"artifact_count": _player_artifact_count(),
	}
	if game._last_hud_snapshot == next_snapshot:
		return
	var artifacts_changed: bool = int(game._last_hud_snapshot.get("artifact_count", -1)) != int(next_snapshot["artifact_count"])
	game._last_hud_snapshot = next_snapshot
	_update_combat_timer(timer_seconds)
	if artifacts_changed:
		_refresh_artifact_hud_row()

	game.health_bar.max_value = max_hp
	game.health_bar.value = hp
	game.health_label.text = "ОЗ %d/%d" % [ceil(hp), ceil(max_hp)]

	if game.xp_bar != null and game.xp_label != null:
		game.xp_bar.max_value = xp_to_next
		game.xp_bar.value = xp
		game.xp_label.text = "Опыт %d/%d" % [xp, xp_to_next]

	if game.money_label != null:
		game.money_label.text = "%dg" % money

	if game.ultimate_bar != null and game.ultimate_label != null:
		game.ultimate_bar.max_value = ultimate_max
		game.ultimate_bar.value = ultimate_charge
		var ready := ultimate_charge >= ultimate_max
		game.ultimate_label.text = "Ульта %d%%" % int(floor(ultimate_charge / ultimate_max * 100.0))
		game.ultimate_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 1.0) if ready else Color(0.98, 0.96, 0.86, 1.0))
		game.ultimate_bar.tooltip_text = "Ультимейт (%s): %s" % [_binding_text("ultimate"), "готов" if ready else "заряжается от урона"]


func _update_combat_timer(timer_seconds: int) -> void:
	if game.timer_label == null or not is_instance_valid(game.timer_label):
		return
	if timer_seconds < 0:
		return
	game.timer_label.text = "%d:%02d" % [timer_seconds / 60, timer_seconds % 60]
	var alarm := timer_seconds <= 5
	var panel := game.timer_label.get_parent() as PanelContainer
	var was_alarm := bool(game.timer_label.get_meta("alarm_active", false))
	if alarm == was_alarm:
		return
	game.timer_label.set_meta("alarm_active", alarm)
	game.timer_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.26, 1.0) if alarm else Color(0.96, 0.92, 0.74, 1.0))
	if panel != null:
		panel.add_theme_stylebox_override("panel", _timer_panel_style(alarm))
	if alarm:
		var tween: Tween = game.timer_label.create_tween()
		tween.set_loops(timer_seconds)
		tween.tween_property(game.timer_label, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(game.timer_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUAD)
		game.timer_label.pivot_offset = game.timer_label.size * 0.5


func _format_artifact_list(artifacts: Array) -> String:
	if artifacts.is_empty():
		return "Artifacts\nNone"

	var visible_artifacts := []
	for index in range(min(artifacts.size(), 6)):
		var entry = artifacts[index]
		visible_artifacts.append(str(entry.get("title", "")) if entry is Dictionary else str(entry))
	if artifacts.size() > visible_artifacts.size():
		visible_artifacts.append("+%d more" % (artifacts.size() - visible_artifacts.size()))
	return "Artifacts\n%s" % "\n".join(visible_artifacts)
