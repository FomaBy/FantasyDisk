extends RefCounted

# Меню, настройки, выбор персонажа/оружия, магазин, события, отдых,
# level-up, победа/смерть, HUD и общие UI-стили.

var game

const ARTIFACT_ICON_DIR := "res://assets/sprites/ui/icons/artifacts/"
const SHOP_ICON_DIR := "res://assets/sprites/ui/icons/shop/"
const SHOP_SLOT_FRAME_PATH := "res://assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png"
const SHOP_SLOT_HOVER_PATH := "res://assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png"
const SHOP_PRICE_BADGE_PATH := "res://assets/sprites/ui/shop/ui_shop_price_badge.png"
const SHOP_PURCHASED_OVERLAY_PATH := "res://assets/sprites/ui/shop/ui_shop_purchased_overlay.png"
const SHOP_TOOLTIP_FRAME_PATH := "res://assets/sprites/ui/shop/ui_shop_tooltip_frame.png"
const SHOP_INLINE_SLOT_SIZE := Vector2(164, 186)
const SHOP_INLINE_ICON_SIZE := Vector2(100, 100)
const SHOP_CURSOR_VARIANTS := {
	"arrow": "res://assets/sprites/ui/cursor/game_cursor.png",
	"pointing_hand": "res://assets/sprites/ui/cursor/game_cursor_hover.png",
	"cross": "res://assets/sprites/ui/cursor/game_cursor_attack.png",
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
	game.pending_level_ups = 0
	game.route_nodes = game.route._generate_route()

	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
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
	action_box.add_theme_constant_override("separation", 14)
	layout.add_child(action_box)

	var start_button := _make_button("Начать новую игру")
	start_button.name = "MainMenuStartButton"
	start_button.custom_minimum_size = Vector2(380, 62)
	start_button.pressed.connect(_show_character_select)
	action_box.add_child(start_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "MainMenuSettingsButton"
	settings_button.custom_minimum_size = Vector2(380, 62)
	settings_button.pressed.connect(_show_settings_menu)
	action_box.add_child(settings_button)

	var codex_button := _make_button("Кодекс")
	codex_button.name = "MainMenuCodexButton"
	codex_button.custom_minimum_size = Vector2(380, 62)
	codex_button.pressed.connect(_show_codex_screen)
	action_box.add_child(codex_button)

	var exit_button := _make_button("Выйти из игры")
	exit_button.name = "MainMenuExitButton"
	exit_button.custom_minimum_size = Vector2(380, 62)
	exit_button.pressed.connect(func() -> void:
		game.get_tree().quit()
	)
	action_box.add_child(exit_button)


func _show_character_select() -> void:
	game.run_player_snapshot.clear()
	game.route_stage = 0
	game.route_selected_indices.clear()
	game.route_nodes = game.route._generate_route()
	game.current_shop_items.clear()
	game.current_shop_purchased.clear()
	var box := _create_menu_box("Выбор героя", "Выбери стиль боя для этого забега.")

	for character_id in game.PROGRESSION_DATA.character_ids():
		var config = game.PROGRESSION_DATA.character_config(str(character_id))
		var stats = game.PROGRESSION_DATA.base_stats(str(character_id))
		_add_character_button(
			box,
			str(config["title"]),
			"%s\nСильные: %s\nСлабые: %s\n%s" % [
				str(config["description"]),
				str(config["strengths"]),
				str(config["weaknesses"]),
				game.PROGRESSION_DATA.display_stats(stats),
			],
			str(character_id)
		)

	var back_button := _make_button("Назад")
	back_button.pressed.connect(_show_main_menu)
	box.add_child(back_button)
	game.ui_escape_action = _show_main_menu


const CODEX_DATA := preload("res://scripts/codex_data.gd")
const CODEX_SECTIONS := [
	{"id": "characters", "title": "Персонажи"},
	{"id": "monsters", "title": "Монстры"},
	{"id": "artifacts", "title": "Артефакты"},
	{"id": "stats", "title": "Характеристики"},
]


const ATTRIBUTE_BUY_BASE_COST := 18
const ATTRIBUTE_BUY_STAGE_COST := 6
const ATTRIBUTE_REROLL_BASE_COST := 6
const ATTRIBUTE_REROLL_STAGE_COST := 2
const ATTRIBUTE_REROLLS_PER_WINDOW := 2


func _attribute_buy_cost() -> int:
	return ATTRIBUTE_BUY_BASE_COST + ATTRIBUTE_BUY_STAGE_COST * game.route_stage


func _attribute_reroll_cost() -> int:
	return ATTRIBUTE_REROLL_BASE_COST + ATTRIBUTE_REROLL_STAGE_COST * game.route_stage


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
	var pair := []
	for _pick in range(2):
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

	root.set_meta("rerolls_left", ATTRIBUTE_REROLLS_PER_WINDOW)
	skip_button.pressed.connect(func() -> void:
		if on_done.is_valid():
			on_done.call()
	)
	reroll_button.pressed.connect(func() -> void:
		var left := int(root.get_meta("rerolls_left", 0))
		if left <= 0 or not _spend_run_money(_attribute_reroll_cost()):
			return
		root.set_meta("rerolls_left", left - 1)
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
	var rerolls_left := int(root.get_meta("rerolls_left", 0))
	reroll_button.text = "Обновить (%d зол.) — осталось %d" % [_attribute_reroll_cost(), rerolls_left]
	reroll_button.disabled = rerolls_left <= 0 or money < _attribute_reroll_cost()

	for stat_id in _random_attribute_pair():
		var stat_title := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
		var offer_button := _make_button("%s +1   (%d зол.)" % [stat_title, buy_cost])
		offer_button.name = "AttributeOffer_%s" % stat_id
		offer_button.custom_minimum_size = Vector2(560, 64)
		offer_button.disabled = money < buy_cost
		var icon_control: Control = game.UIIconRegistry.make_icon(stat_id, Vector2(36, 36))
		icon_control.position = Vector2(14, 14)
		icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		offer_button.add_child(icon_control)
		offer_button.pressed.connect(func() -> void:
			if not _spend_run_money(buy_cost):
				return
			_apply_reward_to_run({"stats": {stat_id: 1.0}})
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
	# Желтая стрелка прокачки: level-up при непотраченных выборах, иначе докачка за деньги.
	var fab := _make_button("⬆")
	fab.name = "UpgradeFabButton"
	fab.custom_minimum_size = Vector2(64, 64)
	fab.anchor_left = 1.0
	fab.anchor_top = 1.0
	fab.anchor_right = 1.0
	fab.anchor_bottom = 1.0
	fab.offset_left = -88.0
	fab.offset_top = -88.0
	fab.offset_right = -24.0
	fab.offset_bottom = -24.0
	fab.add_theme_font_size_override("font_size", 30)
	_apply_fantasy_button_theme(fab, "level_up")
	fab.tooltip_text = "Прокачка: непотраченные уровни или докачка характеристик за золото"
	if not allow_attribute_shop and game.pending_level_ups <= 0:
		fab.disabled = true
		fab.tooltip_text = "Нет непотраченных уровней"
	fab.pressed.connect(func() -> void:
		if game.pending_level_ups > 0:
			game.level_up_return_to_map = false
			game.push_pause("level_up")
			_show_level_up_screen(false)
		elif allow_attribute_shop:
			_show_attribute_shop(return_action)
	)
	root.add_child(fab)

	if game.pending_level_ups > 0:
		var badge := Label.new()
		badge.name = "UpgradeFabBadge"
		badge.text = str(game.pending_level_ups)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02, 1.0))
		var badge_panel := PanelContainer.new()
		badge_panel.name = "UpgradeFabBadgePanel"
		badge_panel.anchor_left = 1.0
		badge_panel.anchor_top = 1.0
		badge_panel.anchor_right = 1.0
		badge_panel.anchor_bottom = 1.0
		badge_panel.offset_left = -36.0
		badge_panel.offset_top = -104.0
		badge_panel.offset_right = -10.0
		badge_panel.offset_bottom = -78.0
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.84, 0.22, 1.0)
		badge_style.set_corner_radius_all(12)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		badge_panel.add_child(badge)
		root.add_child(badge_panel)
		var pulse := badge_panel.create_tween().set_loops()
		pulse.tween_property(badge_panel, "scale", Vector2(1.12, 1.12), 0.45).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(badge_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		badge_panel.pivot_offset = Vector2(13, 13)


func _show_codex_screen() -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "CodexScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.030, 0.034, 0.055, 0.985)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

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
	back_button.custom_minimum_size = Vector2(240, 54)
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
		tab_button.custom_minimum_size = Vector2(220, 50)
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


func _build_codex_characters(list: VBoxContainer) -> void:
	for character in CODEX_DATA.characters():
		var row := _codex_entry_panel(list)
		_codex_portrait(row, str(character["sprite"]), Vector2(176, 176))
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 4)
		row.add_child(text_box)
		_codex_label(text_box, str(character["title"]), 24, Color(0.96, 0.88, 0.40, 1.0))
		_codex_label(text_box, str(character["playstyle"]), 15, Color(0.88, 0.92, 0.96, 1.0))
		_codex_label(text_box, "Сильное: %s" % character["strengths"], 14, Color(0.62, 0.88, 0.58, 1.0))
		_codex_label(text_box, "Слабое: %s" % character["weaknesses"], 14, Color(0.92, 0.62, 0.52, 1.0))
		for weapon in character["weapons"]:
			_codex_label(text_box, "• %s — %s" % [weapon["title"], weapon["description"]], 13, Color(0.78, 0.84, 0.92, 1.0))


func _build_codex_monsters(list: VBoxContainer) -> void:
	var kind_titles := {"standard": "Обычные Монстры", "elite": "Элитные Монстры", "boss": "Боссы"}
	for kind in ["standard", "elite", "boss"]:
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
			_codex_label(text_box, str(monster["behavior"]), 14, Color(0.88, 0.92, 0.96, 1.0))
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
		_codex_label(text_box, str(artifact["description"]), 13, Color(0.84, 0.88, 0.94, 1.0))
		var codex_note := _artifact_affinity_note(artifact_definition)
		if not codex_note.is_empty():
			_codex_label(text_box, str(codex_note["text"]), 12, codex_note["color"])
		var affinity_list: Array = artifact_definition.get("class_affinity", [])
		if not affinity_list.is_empty():
			var class_names := []
			for class_id in affinity_list:
				class_names.append(str(CLASS_RU.get(class_id, class_id)))
			_codex_label(text_box, "Классы: %s" % ", ".join(class_names), 12, Color(0.70, 0.78, 0.88, 1.0))


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
			_codex_label(text_box, str(stat["description"]), 13, Color(0.86, 0.90, 0.95, 1.0))
			if str(stat["influences"]) != "":
				_codex_label(text_box, "Влияет на: %s" % stat["influences"], 12, Color(0.70, 0.78, 0.88, 1.0))


func _show_settings_menu() -> void:
	var box := _create_menu_box("Settings", "Video and controls")

	var resolution_label := _make_section_label("Resolution")
	box.add_child(resolution_label)

	var resolution_options := OptionButton.new()
	resolution_options.custom_minimum_size = Vector2(420, 48)
	_style_button_control(resolution_options)
	for resolution in game.RESOLUTION_OPTIONS:
		resolution_options.add_item("%dx%d" % [resolution.x, resolution.y])
	resolution_options.selected = game.selected_resolution_index
	resolution_options.item_selected.connect(func(index: int) -> void:
		game.selected_resolution_index = index
		_apply_video_settings()
	)
	box.add_child(resolution_options)

	var mode_label := _make_section_label("Window Mode")
	box.add_child(mode_label)

	var mode_options := OptionButton.new()
	mode_options.custom_minimum_size = Vector2(420, 48)
	_style_button_control(mode_options)
	for mode_name in game.WINDOW_MODE_OPTIONS:
		mode_options.add_item(mode_name)
	mode_options.selected = game.selected_window_mode_index
	mode_options.item_selected.connect(func(index: int) -> void:
		game.selected_window_mode_index = index
		_apply_video_settings()
	)
	box.add_child(mode_options)

	var apply_button := _make_button("Apply")
	apply_button.pressed.connect(_apply_video_settings)
	box.add_child(apply_button)

	var controls_label := _make_section_label("Key Bindings")
	box.add_child(controls_label)

	for input_action in game.INPUT_ACTIONS:
		var action_name: String = input_action["action"]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)

		var label := Label.new()
		label.text = input_action["label"]
		label.custom_minimum_size = Vector2(150, 36)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95, 1.0))
		row.add_child(label)

		var bind_button := _make_button(_binding_text(action_name))
		bind_button.custom_minimum_size = Vector2(240, 42)
		bind_button.pressed.connect(func() -> void:
			_begin_rebind(action_name)
		)
		row.add_child(bind_button)

	var hint_label := Label.new()
	hint_label.text = "Click a binding, then press a key. Esc cancels rebinding."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.82, 1.0))
	box.add_child(hint_label)

	var settings_back := func() -> void:
		if game._is_gameplay_paused() and game.combat_active:
			_show_pause_menu()
		else:
			_show_main_menu()
	var back_button := _make_button("Назад")
	back_button.pressed.connect(settings_back)
	box.add_child(back_button)
	game.ui_escape_action = settings_back


func _show_pause_menu() -> void:
	if not game.combat_active:
		return

	game.push_pause("escape_menu")
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	game.pause_stats_menu = game.PAUSE_STATS_MENU_SCENE.instantiate() as Control
	game.ui_layer.add_child(game.pause_stats_menu)
	if game.pause_stats_menu.has_method("setup"):
		game.pause_stats_menu.setup(game.current_player)
	game.pause_stats_menu.resume_requested.connect(_resume_game)
	game.pause_stats_menu.settings_requested.connect(_show_settings_menu)
	game.pause_stats_menu.end_run_confirmed.connect(_end_current_run_by_player)
	game.pause_stats_menu.main_menu_requested.connect(_quit_current_run)


func _resume_game() -> void:
	game.pending_rebind_action = ""
	game.pop_pause("escape_menu")
	game._clear_ui()


func _quit_current_run() -> void:
	game.pending_rebind_action = ""
	game._clear_all_game_pauses()
	game.combat_active = false
	game.boss_combat_active = false
	game.route_stage = 0
	game.run_player_snapshot.clear()
	game.route_selected_indices.clear()
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
	game.pending_level_ups = 0
	game.current_route_choice = ""
	game._clear_world()
	game._clear_hud()
	_show_death_screen("Забег завершен игроком.")


func _add_character_button(box: VBoxContainer, title: String, description: String, character_id: String) -> void:
	var config = game.PROGRESSION_DATA.character_config(character_id)
	# Вся карточка — одна кнопка: клик в любом месте, hover подсвечивает рамку.
	var card := Button.new()
	card.name = "CharacterCard_%s" % character_id
	card.custom_minimum_size = Vector2(760, 150)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", _character_card_style())
	card.add_theme_stylebox_override("hover", _card_hover_style())
	card.add_theme_stylebox_override("pressed", _card_hover_style())
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(func() -> void:
		game.selected_character_id = character_id
		_show_weapon_select()
	)
	box.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_top = 10.0
	row.offset_right = -14.0
	row.offset_bottom = -10.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.name = "CharacterPortrait_%s" % character_id
	portrait.texture = game._cached_texture(str(config.get("sprite_path", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38, 1.0))
	text_box.add_child(title_label)

	var details := Label.new()
	details.text = description
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	details.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96, 1.0))
	text_box.add_child(details)

	var ascension_level = game.ascension_level_for(character_id)
	if ascension_level > 0:
		var ascension_label := Label.new()
		ascension_label.name = "CharacterAscension_%s" % character_id
		ascension_label.text = "Возвышение: %d/10" % ascension_level
		ascension_label.add_theme_font_size_override("font_size", 13)
		ascension_label.add_theme_color_override("font_color", Color(0.78, 0.58, 1.0, 1.0))
		text_box.add_child(ascension_label)

	var select_hint := Label.new()
	select_hint.text = "▶"
	select_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	select_hint.add_theme_font_size_override("font_size", 30)
	select_hint.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32, 0.9))
	select_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(select_hint)


func _show_weapon_select() -> void:
	var character_config = game.PROGRESSION_DATA.character_config(game.selected_character_id)
	var box := _create_menu_box("Выбор оружия", "%s: выбери стартовый подкласс/оружие." % str(character_config["title"]))
	for weapon_id in game.PROGRESSION_DATA.weapon_ids(game.selected_character_id):
		var config = game.PROGRESSION_DATA.weapon(game.selected_character_id, str(weapon_id))
		var button := _make_button("%s\n%s\nRange %.0f | AoE %.0f | Cooldown %.2fs" % [
			config["title"],
			config["description"],
			float(config.get("attack_range", 0.0)),
			float(config.get("aoe_radius", 0.0)),
			float(config.get("fire_interval", 0.0)),
		])
		button.custom_minimum_size = Vector2(680, 84)
		button.pressed.connect(func() -> void:
			game.selected_weapon_id = str(config["id"])
			game.route._show_battle_map()
		)
		box.add_child(button)

	var back_button := _make_button("Назад")
	back_button.pressed.connect(_show_character_select)
	box.add_child(back_button)
	game.ui_escape_action = _show_character_select


func _show_reward_screen() -> void:
	var box := _create_menu_box("Награда за бой", "Выбери 1 из 3 усилений.", "event")
	_create_menu_run_hud()
	for reward in _random_rewards(3):
		var button := _make_button("%s\n%s" % [reward["title"], reward["description"]])
		button.custom_minimum_size = Vector2(640, 74)
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.route._show_battle_map()
		)
		box.add_child(button)


func _show_level_up_screen(return_to_map := false) -> void:
	game.level_up_return_to_map = return_to_map
	var box := _create_level_up_menu_box("Повышение уровня", "Выбери 1 из 3 улучшений. Бой на паузе до выбора.")
	if not game.combat_active:
		_create_menu_run_hud()

	var rewards_row := HBoxContainer.new()
	rewards_row.name = "LevelUpRewardsRow"
	rewards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rewards_row.custom_minimum_size = Vector2(0.0, 178.0)
	rewards_row.add_theme_constant_override("separation", 18)
	box.add_child(rewards_row)

	var reward_buttons: Array[Button] = []
	for reward in _random_level_up_rewards(3):
		var button := _make_level_up_reward_button(reward)
		button.name = "LevelUpRewardButton%d" % reward_buttons.size()
		button.pressed.connect(func() -> void:
			_apply_reward_to_active_run(reward)
			game.pending_level_ups = maxi(game.pending_level_ups - 1, 0)
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
					game.route._show_battle_map()
		)
		rewards_row.add_child(button)
		reward_buttons.append(button)

	var panel := box.get_parent() as PanelContainer
	var title_label := box.get_node_or_null("LevelUpTitle") as Label
	var sparkle_root = game.ui_layer.get_node_or_null("LevelUpOverlay/LevelUpParticles") as Control
	_start_level_up_intro(panel, title_label, reward_buttons, sparkle_root)


func _make_level_up_reward_button(reward: Dictionary) -> Button:
	var button := _make_button("")
	button.custom_minimum_size = Vector2(320, 168)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.tooltip_text = _format_level_up_reward_text(reward)
	_apply_fantasy_button_theme(button, "reward")

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 12.0
	content.offset_right = -14.0
	content.offset_bottom = -12.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	button.add_child(content)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	icon_row.add_child(game.UIIconRegistry.make_icon(_reward_icon_id(reward), Vector2(48, 48)))

	var title_label := Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Upgrade"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.58, 1.0))
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
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(reward.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.64, 0.72, 0.80, 1.0))
	content.add_child(description_label)
	return button


func _resume_combat_after_level_up() -> void:
	game.pop_pause("level_up")
	game._clear_ui()
	if game.combat_active:
		_create_hud()
		_update_hud()


func _show_shop_screen() -> void:
	if game.current_shop_items.is_empty():
		game.current_shop_items = _random_shop_items(4)
		game.current_shop_purchased.clear()
		for _index in range(game.current_shop_items.size()):
			game.current_shop_purchased.append(false)

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
	title_box.offset_top = 70.0
	title_box.offset_right = 380.0
	title_box.offset_bottom = 150.0
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

	# Сетка товаров лежит на «пустой стене» — светлом пергаменте правее торговца
	# (~48-84% ширины и ~5-75% высоты фона screen_shop_background.png).
	var wall := CenterContainer.new()
	wall.name = "ShopParchmentWall"
	wall.anchor_left = 0.50
	wall.anchor_top = 0.10
	wall.anchor_right = 0.82
	wall.anchor_bottom = 0.72
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wall)

	var items_area := GridContainer.new()
	items_area.name = "ShopInlineItems"
	items_area.columns = 2
	items_area.add_theme_constant_override("h_separation", 22)
	items_area.add_theme_constant_override("v_separation", 18)
	wall.add_child(items_area)

	for index in range(game.current_shop_items.size()):
		var item: Dictionary = game.current_shop_items[index]
		items_area.add_child(_make_shop_item_slot(item, index, money))

	var skip_button := _make_button("Покинуть магазин")
	skip_button.name = "ShopLeaveButton"
	skip_button.anchor_left = 0.5
	skip_button.anchor_top = 1.0
	skip_button.anchor_right = 0.5
	skip_button.anchor_bottom = 1.0
	skip_button.offset_left = -170.0
	skip_button.offset_top = -118.0
	skip_button.offset_right = 170.0
	skip_button.offset_bottom = -58.0
	skip_button.custom_minimum_size = Vector2(340, 58)
	var leave_shop := func() -> void:
		game.current_shop_items.clear()
		game.current_shop_purchased.clear()
		game.route._advance_route_after_noncombat()
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
	button.add_theme_stylebox_override("normal", _shop_slot_style(false))
	button.add_theme_stylebox_override("hover", _shop_slot_style(true))
	button.add_theme_stylebox_override("pressed", _shop_slot_style(true))
	button.add_theme_stylebox_override("focus", _shop_slot_style(true))
	button.pressed.connect(func() -> void:
		_buy_shop_item_at(index)
	)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 14.0
	content.offset_right = -14.0
	content.offset_bottom = -12.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	button.add_child(content)

	var icon_holder := CenterContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.custom_minimum_size = Vector2(108, 92)
	content.add_child(icon_holder)

	var icon := TextureRect.new()
	icon.name = "ShopItemIcon"
	icon.texture = _shop_item_icon_texture(item)
	icon.custom_minimum_size = SHOP_INLINE_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)

	var price_badge := PanelContainer.new()
	price_badge.name = "ShopPriceBadge"
	price_badge.custom_minimum_size = Vector2(106, 34)
	price_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_badge.add_theme_stylebox_override("panel", _shop_price_badge_style())
	content.add_child(price_badge)

	var price_label := Label.new()
	price_label.name = "ShopItemPrice"
	price_label.text = "%dg" % cost
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0) if affordable else Color(1.0, 0.42, 0.42, 1.0))
	price_badge.add_child(price_label)

	if purchased or not affordable:
		_add_shop_state_overlay(button, "Куплено" if purchased else "Нет монет")
	return button


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


func _shop_price_badge_style() -> StyleBox:
	var texture_style := _shop_texture_style(SHOP_PRICE_BADGE_PATH, Vector2(14, 14))
	if texture_style != null:
		return texture_style

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.065, 0.050, 0.88)
	style.border_color = Color(1.0, 0.78, 0.24, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
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
	var heal_button := _make_button("Передышка\nВосстановить 35% максимального HP.")
	heal_button.name = "RestHealButton"
	heal_button.pressed.connect(func() -> void:
		_apply_event_choice({"title": "Rest", "description": "Recover", "heal_percent": 0.35})
		game.route._advance_route_after_noncombat()
	)
	box.add_child(heal_button)

	var guard_button := _make_button("Защитная стойка\nПолучить +6% защиты до конца забега.")
	guard_button.name = "RestGuardButton"
	guard_button.pressed.connect(func() -> void:
		_apply_reward_to_run({"title": "Guard Stance", "description": "+6% defense.", "mods": {"defense_flat": 0.06}})
		game.route._advance_route_after_noncombat()
	)
	box.add_child(guard_button)


func _show_upgrade_screen() -> void:
	var box := _create_menu_box("Улучшение", "Выбери усиление оружия или параметра.", "event")
	_create_menu_run_hud()
	for reward in _random_level_up_rewards(3):
		var button := _make_button("%s\n%s" % [reward["title"], reward["description"]])
		button.custom_minimum_size = Vector2(640, 74)
		button.pressed.connect(func() -> void:
			_apply_reward_to_run(reward)
			game.route._advance_route_after_noncombat()
		)
		box.add_child(button)


func _show_event_screen(route_node: Dictionary) -> void:
	var box := _create_menu_box(route_node["name"], "Странная возможность на дороге: риск, награда или оба сразу.", "event")
	_create_menu_run_hud()
	# На событии докачка недоступна: повторный вход перегенерировал бы выборы события.
	_create_upgrade_fab(box.get_parent().get_parent() if box.get_parent() != null else box, Callable(), false)
	var event_choices := _random_event_choices()
	var index := 0
	for event_choice in event_choices:
		var button := _make_button("%s\n%s" % [event_choice["title"], event_choice["description"]])
		button.name = "EventChoiceButton%d" % index
		button.custom_minimum_size = Vector2(640, 74)
		button.pressed.connect(func() -> void:
			_apply_event_choice(event_choice)
			game.route_stage += 1
			game.route._show_battle_map()
		)
		box.add_child(button)
		index += 1


func _show_victory_screen() -> void:
	var ascension_level = game.ascension_level_for(game.selected_character_id)
	var character_title = str(game.PROGRESSION_DATA.character_config(game.selected_character_id).get("title", game.selected_character_id))
	var ascension_text = "Возвышение героя %s: %d/10." % [character_title, ascension_level]
	if ascension_level <= 0:
		ascension_text = "Возвышение еще не открыто."
	var box = _create_menu_box("Победа", "Финальный босс повержен. Meta points: %d. %s" % [game.meta_points, ascension_text], "event")
	var finish_run := func() -> void:
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var restart_button := _make_button("Новый забег")
	restart_button.pressed.connect(finish_run)
	box.add_child(restart_button)
	game.ui_escape_action = finish_run


func _show_death_screen(reason := "") -> void:
	var subtitle := str(reason)
	if subtitle == "":
		subtitle = "Забег завершен на этапе маршрута %d." % [game.route_stage + 1]
	var box := _create_menu_box("Поражение", subtitle, "event")
	var back_to_menu := func() -> void:
		game.route_stage = 0
		game.run_player_snapshot.clear()
		game.route_selected_indices.clear()
		game.route_nodes = game.route._generate_route()
		_show_main_menu()
	var retry_button := _make_button("Начать заново")
	retry_button.pressed.connect(back_to_menu)
	box.add_child(retry_button)
	game.ui_escape_action = back_to_menu


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
			"description": "Lose 15% HP, gain an artifact/stat reward.",
			"reward": rewards[1],
			"health_percent_cost": 0.15,
		},
		{
			"title": "Rest",
			"description": "Recover 25% maximum HP.",
			"heal_percent": 0.25,
		},
	]
	return choices


func _apply_event_choice(event_choice: Dictionary) -> void:
	var temp_player = game.player_scene.instantiate()
	game.add_child(temp_player)
	if game.run_player_snapshot.is_empty():
		temp_player.configure_character(game.selected_character_id, game.selected_weapon_id)
	else:
		game.combat._restore_player_snapshot(temp_player)

	if event_choice.has("reward"):
		temp_player.apply_reward(event_choice["reward"])

	if event_choice.has("health_percent_cost"):
		var cost := float(temp_player.get("max_health")) * float(event_choice["health_percent_cost"])
		temp_player.set("health", max(1.0, float(temp_player.get("health")) - cost))

	if event_choice.has("heal_percent"):
		var heal := float(temp_player.get("max_health")) * float(event_choice["heal_percent"])
		temp_player.set("health", min(float(temp_player.get("max_health")), float(temp_player.get("health")) + heal))

	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()


func _random_rewards(count: int) -> Array:
	return _weighted_sample(game.PROGRESSION_DATA.reward_pool(), count)


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


func _random_level_up_rewards(count: int) -> Array:
	var pool: Array = game.PROGRESSION_DATA.level_up_rewards()
	var rewards := []
	while rewards.size() < count and not pool.is_empty():
		var index = game.rng.randi_range(0, pool.size() - 1)
		rewards.append(pool[index])
		pool.remove_at(index)
	return rewards


func _random_shop_items(count: int) -> Array:
	return _weighted_sample(game.PROGRESSION_DATA.shop_items(), count)


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


func _update_level_up_button() -> void:
	if game.pending_level_ups <= 0:
		if game.level_up_button != null and is_instance_valid(game.level_up_button):
			game.level_up_button.queue_free()
		game.level_up_button = null
		return

	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return

	if game.level_up_button == null or not is_instance_valid(game.level_up_button):
		game.level_up_button = Button.new()
		game.level_up_button.name = "LevelUpPlusButton"
		game.level_up_button.process_mode = Node.PROCESS_MODE_ALWAYS
		game.level_up_button.position = Vector2(1480, 786)
		game.level_up_button.size = Vector2(88, 88)
		game.level_up_button.custom_minimum_size = Vector2(88, 88)
		game.level_up_button.tooltip_text = "Открыть выбор улучшения"
		game.level_up_button.add_theme_font_size_override("font_size", 32)
		_apply_fantasy_button_theme(game.level_up_button, "level_up")
		game.level_up_button.pressed.connect(_open_pending_level_up)
		game.hud_layer.add_child(game.level_up_button)

	game.level_up_button.text = "+" if game.pending_level_ups == 1 else "+%d" % game.pending_level_ups


func _level_up_affinity_suffix(reward: Dictionary) -> String:
	if str(reward.get("kind", "")) != "artifact":
		return ""
	return _artifact_affinity_suffix(reward)


func _format_level_up_reward_text(reward: Dictionary) -> String:
	var preview := _level_up_reward_preview(reward)
	return "%s\n%s\n%s" % [
		str(reward.get("title", "Upgrade")),
		preview,
		str(reward.get("description", "")),
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
		"attack_speed":
			return "Скорость атаки"
		"health_point":
			return "Макс. HP"
		"move_speed":
			return "Скорость"
		"aoe_radius":
			return "AoE радиус"
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
		_:
			return parameter_id


func _format_level_up_value(parameter_id: String, value: float) -> String:
	if parameter_id in ["crit_chance", "defense", "dodge"]:
		return "%.0f%%" % (value * 100.0)
	if parameter_id in ["attack_speed", "crit_damage_multiplier"]:
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
			var default_event := InputEventKey.new()
			default_event.keycode = input_action["default_key"]
			InputMap.action_add_event(action_name, default_event)

			var alternate_event := InputEventKey.new()
			alternate_event.keycode = input_action["alternate_key"]
			InputMap.action_add_event(action_name, alternate_event)


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
	var box := _create_menu_box("Rebind %s" % label, "Press a key. Esc cancels.")

	var cancel_button := _make_button("Cancel")
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

	InputMap.action_erase_events(game.pending_rebind_action)
	var new_event := InputEventKey.new()
	new_event.keycode = event.keycode
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(game.pending_rebind_action, new_event)

	game.pending_rebind_action = ""
	_show_settings_menu()


func _binding_text(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "Unbound"

	var event := events[0]
	if event is InputEventKey:
		return OS.get_keycode_string(event.keycode)

	return event.as_text()


func _action_label(action_name: String) -> String:
	for input_action in game.INPUT_ACTIONS:
		if input_action["action"] == action_name:
			return input_action["label"]

	return action_name


func _apply_video_settings() -> void:
	game.selected_resolution_index = clampi(game.selected_resolution_index, 0, game.RESOLUTION_OPTIONS.size() - 1)
	game.selected_window_mode_index = clampi(game.selected_window_mode_index, 0, game.WINDOW_MODE_OPTIONS.size() - 1)

	var resolution: Vector2i = game.RESOLUTION_OPTIONS[game.selected_resolution_index]
	DisplayServer.window_set_size(resolution)

	match game.selected_window_mode_index:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	if game.selected_window_mode_index != 2:
		var screen_id := DisplayServer.window_get_current_screen()
		var screen_size := DisplayServer.screen_get_size(screen_id)
		DisplayServer.window_set_position((screen_size - resolution) / 2)


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
	subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95, 1.0))
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
		var dim_tween = game.create_tween()
		dim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		dim_tween.tween_property(dim, "color:a", 0.68, 0.16)

	var panel_tween = game.create_tween()
	panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.set_trans(Tween.TRANS_BACK)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(level_up_panel, "scale", Vector2.ONE, 0.34)
	panel_tween.parallel().tween_property(level_up_panel, "modulate:a", 1.0, 0.18)

	var title := title_label as Label
	if title != null and is_instance_valid(title):
		title.pivot_offset = title.size * 0.5
		var title_tween = game.create_tween()
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
		var button_tween = game.create_tween()
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
		var tween = game.create_tween()
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
	button.custom_minimum_size = Vector2(420, 54)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button_control(button)
	return button


func _style_button_control(button: Button) -> void:
	_apply_fantasy_button_theme(button)
	button.add_theme_font_size_override("font_size", 16)


func _apply_fantasy_button_theme(button: Button, variant := "default") -> void:
	var normal_bg := Color(0.075, 0.095, 0.13, 0.97)
	var hover_bg := Color(0.13, 0.17, 0.22, 1.0)
	var pressed_bg := Color(0.045, 0.060, 0.085, 1.0)
	var border := Color(0.68, 0.52, 0.22, 0.92)
	var hover_border := Color(1.0, 0.82, 0.26, 1.0)
	var pressed_border := Color(0.95, 0.62, 0.18, 1.0)
	var border_width := 2
	var shadow_alpha := 0.42
	if variant == "reward":
		normal_bg = Color(0.075, 0.065, 0.115, 0.98)
		hover_bg = Color(0.125, 0.095, 0.19, 1.0)
		pressed_bg = Color(0.055, 0.045, 0.09, 1.0)
		border = Color(0.56, 0.42, 0.86, 0.98)
		hover_border = Color(1.0, 0.82, 0.28, 1.0)
		pressed_border = Color(0.55, 0.96, 1.0, 1.0)
		border_width = 3
		shadow_alpha = 0.58
	elif variant == "danger":
		normal_bg = Color(0.24, 0.055, 0.055, 0.98)
		hover_bg = Color(0.36, 0.075, 0.070, 1.0)
		pressed_bg = Color(0.16, 0.035, 0.040, 1.0)
		border = Color(0.80, 0.20, 0.16, 0.96)
		hover_border = Color(1.0, 0.48, 0.34, 1.0)
		pressed_border = Color(0.95, 0.30, 0.22, 1.0)
	elif variant == "level_up":
		normal_bg = Color(0.08, 0.22, 0.20, 0.98)
		hover_bg = Color(0.12, 0.34, 0.30, 1.0)
		pressed_bg = Color(0.05, 0.15, 0.15, 1.0)
		border = Color(0.38, 0.95, 0.78, 1.0)
		hover_border = Color(0.78, 1.0, 0.88, 1.0)
		pressed_border = Color(1.0, 0.82, 0.28, 1.0)
		border_width = 3
	button.add_theme_stylebox_override("normal", _button_style(normal_bg, border, shadow_alpha, border_width))
	button.add_theme_stylebox_override("hover", _button_style(hover_bg, hover_border, min(shadow_alpha + 0.16, 0.74), border_width))
	button.add_theme_stylebox_override("pressed", _button_style(pressed_bg, pressed_border, shadow_alpha, border_width))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.06, 0.065, 0.075, 0.82), Color(0.20, 0.22, 0.25, 0.95), 0.18, border_width))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.55, 0.96, 1.0, 0.60), 0.0, 1))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.68, 1.0))
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	style.border_color = Color(0.95, 0.78, 0.32, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28
	style.content_margin_top = 26
	style.content_margin_right = 28
	style.content_margin_bottom = 26
	return style


func _level_up_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.045, 0.085, 0.98)
	style.border_color = Color(1.0, 0.78, 0.24, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.content_margin_left = 34
	style.content_margin_top = 30
	style.content_margin_right = 34
	style.content_margin_bottom = 30
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 10.0)
	return style


func _level_up_hero_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.060, 0.88)
	style.border_color = Color(0.55, 0.96, 1.0, 0.86)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.40, 0.18, 0.88, 0.44)
	style.shadow_size = 12
	style.shadow_offset = Vector2.ZERO
	return style


func _hero_portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.10, 0.58)
	style.border_color = Color(1.0, 0.82, 0.24, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _card_hover_style() -> StyleBoxFlat:
	var style := _character_card_style()
	style.border_color = Color(1.0, 0.86, 0.28, 1.0)
	style.bg_color = style.bg_color.lightened(0.06)
	style.set_border_width_all(3)
	return style


func _character_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
	style.border_color = Color(0.38, 0.62, 0.72, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	return style


func _button_style(background: Color, border: Color, shadow_alpha := 0.38, border_width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.border_width_bottom = border_width + 2
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_top = 12
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _bar_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(6)
	return style


func _create_hud() -> void:
	game._clear_hud()
	game.hud_layer = CanvasLayer.new()
	game.hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.hud_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)

	_create_resource_hud_panel(root, Vector2(20, 18))
	_create_combat_timer_panel(root)
	_create_artifact_hud_row(root)
	_create_damage_flash_overlay(root)
	_update_level_up_button()
	_update_hud()


func _create_combat_timer_panel(root: Control) -> void:
	# На босс-файтах таймера нет — панель не создается вовсе.
	if game.boss_combat_active:
		game.timer_label = null
		return
	var panel := PanelContainer.new()
	panel.name = "CombatTimerPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -86.0
	panel.offset_top = 14.0
	panel.offset_right = 86.0
	panel.offset_bottom = 66.0
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


func _timer_panel_style(alarm: bool) -> StyleBoxFlat:
	# Стилизованная рамка кодом; заменить на StyleBoxTexture c timer_frame.png,
	# когда Design выдаст ассет (design_artifact_icons_fantasy_restyle_task).
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.05, 0.88) if not alarm else Color(0.22, 0.05, 0.04, 0.92)
	style.border_color = Color(0.78, 0.62, 0.28, 1.0) if not alarm else Color(1.0, 0.26, 0.20, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _create_artifact_hud_row(root: Control) -> void:
	var row := HFlowContainer.new()
	row.name = "ArtifactHudRow"
	row.anchor_left = 1.0
	row.anchor_top = 0.0
	row.anchor_right = 1.0
	row.anchor_bottom = 0.0
	row.offset_left = -420.0
	row.offset_top = 16.0
	row.offset_right = -18.0
	row.offset_bottom = 120.0
	row.alignment = FlowContainer.ALIGNMENT_END
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)


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


const TIER_LABELS := {1: "Tier 1", 2: "Tier 2 — редкий", 3: "Tier 3 — легендарный"}
const CLASS_RU := {"berserk": "Берсерк", "dark_mage": "Темный маг", "guitarist": "Гитарист"}


func _artifact_affinity_note(definition: Dictionary) -> Dictionary:
	# Честная пометка: красная — весь эффект классовый и класс чужой;
	# желтая — классовая часть пропадает, универсальная работает; пусто — полный эффект.
	var affinity: Array = definition.get("class_affinity", definition.get("classes", []))
	if affinity.is_empty() or affinity.has(game.selected_character_id):
		return {}
	var has_universal: bool = not (definition.get("mods", {}) as Dictionary).is_empty() \
		or not (definition.get("stats", {}) as Dictionary).is_empty()
	if has_universal:
		return {"text": "Работает вполсилы", "color": Color(0.95, 0.82, 0.25, 1.0)}
	return {"text": "Не работает на текущем классе", "color": Color(0.95, 0.30, 0.24, 1.0)}


func _artifact_affinity_suffix(definition: Dictionary) -> String:
	var note := _artifact_affinity_note(definition)
	if note.is_empty():
		return ""
	return "
[%s]" % note["text"]


func _artifact_tier_text(definition: Dictionary) -> String:
	return str(TIER_LABELS.get(int(definition.get("tier", 1)), "Tier 1"))


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
	panel.custom_minimum_size = Vector2(560, 78)
	panel.add_theme_stylebox_override("panel", _hud_panel_style())
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	game.health_bar = _add_hud_resource_card(row, "hp", "HP", Color(0.92, 0.08, 0.08, 1.0))
	game.xp_bar = _add_hud_resource_card(row, "xp", "XP", Color(0.25, 0.78, 1.0, 1.0))
	_add_hud_money_card(row)


func _add_hud_resource_card(parent: HBoxContainer, icon_id: String, label_text: String, fill_color: Color) -> ProgressBar:
	var card := PanelContainer.new()
	card.name = "Hud%sCard" % label_text
	card.custom_minimum_size = Vector2(178, 54)
	card.add_theme_stylebox_override("panel", _hud_card_style())
	parent.add_child(card)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	card.add_child(line)
	line.add_child(game.UIIconRegistry.make_icon(icon_id, Vector2(38, 38)))

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

	var bar := ProgressBar.new()
	bar.name = "Hud%sBar" % label_text
	bar.custom_minimum_size = Vector2(112, 10)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.06, 0.07, 0.09, 0.94)))
	bar.add_theme_stylebox_override("fill", _bar_style(fill_color))
	value_box.add_child(bar)
	return bar


func _add_hud_money_card(parent: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.name = "HudMoneyCard"
	card.custom_minimum_size = Vector2(138, 54)
	card.add_theme_stylebox_override("panel", _hud_card_style())
	parent.add_child(card)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	card.add_child(line)
	line.add_child(game.UIIconRegistry.make_icon("money", Vector2(38, 38)))

	game.money_label = Label.new()
	game.money_label.name = "HudMoneyLabel"
	game.money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.money_label.add_theme_font_size_override("font_size", 18)
	game.money_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))
	line.add_child(game.money_label)


func _hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 0.76)
	style.border_color = Color(0.95, 0.78, 0.32, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_top = 9
	style.content_margin_right = 10
	style.content_margin_bottom = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _hud_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.88)
	style.border_color = Color(0.28, 0.40, 0.48, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style


func _run_resource_values() -> Dictionary:
	var hp = float(game.run_player_snapshot.get("health", game.run_player_snapshot.get("max_health", 0.0)))
	var max_hp = float(game.run_player_snapshot.get("max_health", 0.0))
	var xp = int(game.run_player_snapshot.get("xp", 0))
	var xp_to_next = int(game.run_player_snapshot.get("xp_to_next", 5))
	var money := _run_money()
	if game.current_player != null and is_instance_valid(game.current_player):
		hp = float(game.current_player.get("health"))
		max_hp = float(game.current_player.get("max_health"))
		xp = int(game.current_player.get("xp"))
		xp_to_next = int(game.current_player.get("xp_to_next"))
		money = int(game.current_player.get("money"))
	return {
		"hp": hp,
		"max_hp": max_hp,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"money": money,
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
	var timer_seconds := -1
	if game.combat_active and not game.boss_combat_active:
		timer_seconds = maxi(int(ceil(game.round_time_left)), 0)
	var next_snapshot := {
		"hp": int(ceil(hp)),
		"max_hp": int(ceil(max_hp)),
		"xp": xp,
		"xp_to_next": xp_to_next,
		"money": money,
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
	game.health_label.text = "HP %d/%d" % [ceil(hp), ceil(max_hp)]

	if game.xp_bar != null and game.xp_label != null:
		game.xp_bar.max_value = xp_to_next
		game.xp_bar.value = xp
		game.xp_label.text = "XP %d/%d" % [xp, xp_to_next]

	if game.money_label != null:
		game.money_label.text = "%dg" % money


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
