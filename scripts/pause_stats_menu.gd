extends Control

signal resume_requested
signal settings_requested
signal end_run_confirmed
signal main_menu_requested

const StatFormulas := preload("res://scripts/stat_formulas.gd")
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const GlobalTooltipControl := preload("res://scripts/ui/global_tooltip_control.gd")

# SCRUM-890: досье героя (пауза) — вариант Б: атлас-шапка (чип-титул + кит-кнопки
# в ряд) и плотное тело (карточка героя слева, «Боевые параметры» 2×2 справа).
# Сцена не имеет доступа к хелперам ui_screens — мини-хелперы стилей продублированы
# локально с ТЕМИ ЖЕ числами (см. комментарии «числа = ...»).

const HERO_EMBLEM_PATH := "res://assets/sprites/ui/atlas_style/emblem_hero_hall.png"

# Глобальный кнопочный кит: нативные плиты text_buttons_unique, size-маппинг
# = ui_screens._text_button_unique_id (72-высоты → 220/240/260-плиты,
# 104 → back_260x104, промежуточная 88 → minimal_metal back_m 9-slice).
const KIT_UNIQUE_DIR := "res://assets/sprites/ui/frames/text_buttons_unique/"
const KIT_MINIMAL_DIR := "res://assets/sprites/ui/frames/minimal_metal_buttons/"
const KIT_STATES := ["normal", "hover", "pressed", "focus", "disabled"]
# margins/content = UIThemePaths.TEXT_BUTTON_UNIQUE_MARGINS/CONTENT
const KIT_UNIQUE_72_MARGINS := Vector4(37, 14, 37, 14)
const KIT_UNIQUE_72_CONTENT := Vector4(47, 14, 47, 14)
const KIT_UNIQUE_104_MARGINS := Vector4(54, 21, 54, 21)
const KIT_UNIQUE_104_CONTENT := Vector4(64, 21, 64, 21)
# margins/content = UIThemePaths.MINIMAL_METAL_BUTTON_MARGINS/CONTENT["back_m"]
const KIT_BACK_M_MARGINS := Vector4(42, 28, 42, 28)
const KIT_BACK_M_CONTENT := Vector4(56, 32, 56, 32)
const BUTTON_HOVER_EXTRA_TINT := Color(1.12, 1.12, 1.12, 1.0)
const BUTTON_DANGER_TINT := Color(1.08, 0.72, 0.72, 1.0)
const BUTTON_DANGER_PRESSED_TINT := Color(0.92, 0.55, 0.55, 1.0)

# Цвета единого атлас-стиля (= _show_atlas_screen и родня).
const COLOR_TITLE := Color(0.96, 0.90, 0.68, 1.0)
const COLOR_KIND := Color(0.78, 0.66, 0.44, 1.0)
const COLOR_BODY := Color(0.88, 0.92, 0.98, 1.0)

const VALUE_HIGH := Color(0.439, 0.949, 0.651, 1.0)
const VALUE_LOW := Color(1.0, 0.420, 0.420, 1.0)
const VALUE_NEUTRAL := Color(0.914, 0.863, 0.655, 1.0)
const VALUE_EFFECTIVE := Color(1.0, 0.863, 0.361, 1.0)

# SCRUM-890 вариант Б: «Боевые параметры» = ровно 4 секции в сетке 2×2.
# Выживаемость/саммоны-производные ушли из досье (плотность по мокапу Б);
# ключевые цифры выживания видны в HUD, полные — в кодексе.
const DERIVED_GROUPS := [
	{
		"id": "physical_damage",
		"title": "Физический урон",
		"stats": ["damage", "attack_speed", "crit_chance", "crit_damage_multiplier", "knockback_power"],
		"accent": Color(0.95, 0.38, 0.22, 1.0),
	},
	{
		"id": "magic_damage",
		"title": "Магия",
		"stats": ["magic_damage", "aoe_radius", "projectile_speed", "attack_range", "range_multiplier"],
		"accent": Color(0.55, 0.42, 1.0, 1.0),
	},
	{
		"id": "sound_control",
		"title": "Звук / Контроль",
		"stats": ["sound_wave_damage", "aura_radius", "buff_power", "knockback_distance"],
		"accent": Color(0.30, 0.86, 1.0, 1.0),
	},
	{
		"id": "dot_poison",
		"title": "Яд / периодический урон",
		"stats": ["dot_damage", "dot_speed"],
		"accent": Color(0.45, 0.95, 0.44, 1.0),
	},
]

# SCRUM-890: кнопка «Завершить забег» открывает модалку EndRunConfirm ui_screens
# (SCRUM-883) через этот хук; standalone-сцена (тесты/превью) падает в
# движковый ConfirmationDialog-фолбэк.
var end_run_confirm_handler := Callable()

var _base_stats_container: VBoxContainer = null
var _derived_groups_container: GridContainer = null
var _hero_card_container: VBoxContainer = null
var _player: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Тултипы — глобальный чип-стиль (SCRUM-890): рамку рисует TooltipPanel из
	# GlobalTooltip.make_theme, свой texture-override сцене больше не нужен.
	theme = GlobalTooltip.make_theme()
	_build_layout()
	call_deferred("_install_global_tooltip_skin")


func setup(player: Node) -> void:
	_player = player
	_refresh_hero_card()
	_refresh_stats()
	call_deferred("_install_global_tooltip_skin")


const READABILITY_BASE_VIEWPORT := Vector2(1280.0, 720.0)
const READABILITY_MAX_SCALE := 1.18
const READABLE_BASE_ROW_HEIGHT := 44.0
const READABLE_CHIP_HEIGHT := 54.0
const READABLE_CHIP_WIDTH := 236.0


func _readability_scale() -> float:
	var viewport := get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return 1.0
	return clampf(
		minf(viewport.x / READABILITY_BASE_VIEWPORT.x, viewport.y / READABILITY_BASE_VIEWPORT.y),
		1.0,
		READABILITY_MAX_SCALE
	)


func _readable_px(base_size: float) -> int:
	return int(roundf(base_size * _readability_scale()))


# числа = ui_screens._atlas_ui_scale (база 2560×1440).
func _atlas_scale() -> float:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return 1.0
	return minf(vp.x / 2560.0, vp.y / 1440.0)


# числа = ui_screens._atlas_chip_style: тёмная кожа + латунный кант.
func _chip_style(alpha: float, pad: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.070, 0.055, alpha)
	style.border_color = Color(0.52, 0.41, 0.24, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = pad * 1.4
	style.content_margin_right = pad * 1.4
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	return style


# числа = ui_screens._atlas_translucent_style.
func _translucent_style(alpha: float, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, alpha)
	style.set_corner_radius_all(int(radius))
	return style


# логика = ui_screens._atlas_action_button_height (72/88/104 по высоте вьюпорта).
func _action_button_height() -> float:
	var vp_h := get_viewport_rect().size.y
	if vp_h <= 0.0:
		vp_h = 1440.0
	if vp_h < 760.0:
		return 72.0
	if vp_h < 1000.0:
		return 88.0
	return 104.0


func _build_layout() -> void:
	var overlay := ColorRect.new()
	overlay.name = "PauseStatsDim"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.015, 0.025, 0.75)
	add_child(overlay)

	var root := Control.new()
	root.name = "PauseStatsMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var s := _atlas_scale()
	var panel := PanelContainer.new()
	panel.name = "EscapeStatsPanelFrame"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20.0
	panel.offset_top = 18.0
	panel.offset_right = -20.0
	panel.offset_bottom = -18.0
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _chip_style(0.95, maxf(7.0, roundf(16.0 * s))))
	root.add_child(panel)

	var layout := VBoxContainer.new()
	layout.name = "DossierLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", maxi(5, int(roundf(12.0 * s))))
	panel.add_child(layout)

	_build_header(layout, s)
	_build_body(layout, s)


# ШАПКА: чип-титул «Досье героя» слева, кит-кнопки управления забегом в ряд справа.
# Кнопки НЕ растягиваются контейнером — нативные размеры кита (SIZE_SHRINK_*).
func _build_header(layout: VBoxContainer, s: float) -> void:
	var header := HBoxContainer.new()
	header.name = "DossierHeader"
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var vp := get_viewport_rect().size
	# На узких вьюпортах (1152/1280) полный сет 260/280 не помещается в строку —
	# уходим на узкие нативные плиты кита (220/240/260), титул сжимаем.
	var compact := vp.x < 1300.0

	var title_chip := PanelContainer.new()
	title_chip.name = "DossierTitleChip"
	title_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_chip.add_theme_stylebox_override("panel", _chip_style(0.86, maxf(5.0, roundf(10.0 * s))))
	header.add_child(title_chip)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(maxf(6.0, roundf(10.0 * s))))
	title_chip.add_child(title_row)

	if ResourceLoader.exists(HERO_EMBLEM_PATH):
		var emblem := TextureRect.new()
		emblem.name = "DossierTitleEmblem"
		emblem.texture = load(HERO_EMBLEM_PATH)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var emblem_px := maxf(26.0, roundf(44.0 * s))
		emblem.custom_minimum_size = Vector2(emblem_px, emblem_px)
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(emblem)

	# На сверхузких (1152) текст титула прячем — эмблема остаётся якорем, место
	# отдаём нативным плитам кнопок.
	if vp.x >= 1200.0:
		var title_label := Label.new()
		title_label.name = "DossierTitleLabel"
		title_label.text = "Досье героя"
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", _readable_px(22.0))
		title_label.add_theme_color_override("font_color", COLOR_TITLE)
		title_row.add_child(title_label)

	var spacer := Control.new()
	spacer.name = "DossierHeaderSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var button_box := HBoxContainer.new()
	button_box.name = "PauseControlButtons"
	button_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	button_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button_box.add_theme_constant_override("separation", 8)
	header.add_child(button_box)

	var side_w := 220.0 if compact else 260.0
	var danger_w := 260.0 if compact else 280.0

	var resume_button := _kit_button("Продолжить", side_w)
	resume_button.name = "PauseResumeButton"
	resume_button.pressed.connect(func() -> void:
		resume_requested.emit()
	)
	button_box.add_child(resume_button)

	var settings_button := _kit_button("Настройки", side_w)
	settings_button.name = "PauseSettingsButton"
	settings_button.pressed.connect(func() -> void:
		settings_requested.emit()
	)
	button_box.add_child(settings_button)

	var end_run_button := _kit_button("Завершить забег", danger_w, "danger")
	end_run_button.name = "PauseEndRunButton"
	end_run_button.pressed.connect(_show_end_run_confirm)
	button_box.add_child(end_run_button)

	var menu_button := _kit_button("Главное меню", side_w)
	menu_button.name = "PauseMainMenuButton"
	menu_button.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	button_box.add_child(menu_button)

	# SCRUM-812: досье проходимо с геймпада/стрелок — горизонтальное кольцо фокуса,
	# стартовый фокус «Продолжить». B/Esc (resume) — централизованно в main._input.
	var ring: Array[Button] = [resume_button, settings_button, end_run_button, menu_button]
	for i in range(ring.size()):
		var b := ring[i]
		b.focus_mode = Control.FOCUS_ALL
		b.focus_neighbor_left = ring[(i - 1 + ring.size()) % ring.size()].get_path()
		b.focus_neighbor_right = ring[(i + 1) % ring.size()].get_path()
	resume_button.call_deferred("grab_focus")


func _build_body(layout: VBoxContainer, s: float) -> void:
	var body := HBoxContainer.new()
	body.name = "DossierBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", maxi(10, int(roundf(16.0 * s))))
	layout.add_child(body)

	# ЛЕВО — карточка героя: портрет, класс, оружие/уровень/возвышение, 8 базовых
	# статов плотными chip-рядами.
	var hero_card := PanelContainer.new()
	hero_card.name = "HeroCard"
	hero_card.custom_minimum_size = Vector2(clampf(430.0 * s, 320.0, 460.0), 0.0)
	hero_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_card.add_theme_stylebox_override("panel", _chip_style(0.90, maxf(5.0, roundf(12.0 * s))))
	body.add_child(hero_card)

	_hero_card_container = VBoxContainer.new()
	_hero_card_container.name = "HeroCardContent"
	_hero_card_container.add_theme_constant_override("separation", 6)
	hero_card.add_child(_hero_card_container)

	# ПРАВО — «Боевые параметры»: 4 секции кожаными чипами в сетке 2×2.
	var right_column := VBoxContainer.new()
	right_column.name = "DerivedStatsPanel"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", maxi(6, int(roundf(10.0 * s))))
	body.add_child(right_column)

	var header := HBoxContainer.new()
	header.name = "DerivedStatsHeader"
	header.add_theme_constant_override("separation", 10)
	right_column.add_child(header)

	var stats_title := Label.new()
	stats_title.name = "DerivedStatsTitle"
	stats_title.text = "Боевые параметры"
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_title.add_theme_font_size_override("font_size", _readable_px(24.0))
	stats_title.add_theme_color_override("font_color", COLOR_TITLE)
	header.add_child(stats_title)

	var stats_hint := Label.new()
	stats_hint.name = "DerivedStatsHint"
	stats_hint.text = "Наведи на параметр для деталей"
	stats_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_hint.add_theme_font_size_override("font_size", _readable_px(14.0))
	stats_hint.add_theme_color_override("font_color", COLOR_KIND)
	header.add_child(stats_hint)

	# Без скролла на ≥1920×1080 (сетка 2×2 помещается в тело); на компактных
	# вьюпортах секции складываются в 1 колонку и правая зона скроллится.
	var scroll := ScrollContainer.new()
	scroll.name = "DerivedStatsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	right_column.add_child(scroll)

	_derived_groups_container = GridContainer.new()
	_derived_groups_container.name = "DerivedStatsGroups"
	_derived_groups_container.columns = 2 if get_viewport_rect().size.x >= 1500.0 else 1
	_derived_groups_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_derived_groups_container.add_theme_constant_override("h_separation", maxi(8, int(roundf(12.0 * s))))
	_derived_groups_container.add_theme_constant_override("v_separation", maxi(8, int(roundf(12.0 * s))))
	scroll.add_child(_derived_groups_container)


func _refresh_hero_card() -> void:
	if _hero_card_container == null:
		return
	for child in _hero_card_container.get_children():
		child.queue_free()
	_base_stats_container = null
	if _player == null or not is_instance_valid(_player):
		return

	var s := _atlas_scale()
	var character_id := str(_player.get("character_id"))
	var weapon_id := str(_player.get("weapon_id"))
	var config: Dictionary = ProgressionData.character_config(character_id)
	var weapon: Dictionary = ProgressionData.weapon(character_id, weapon_id)

	var identity := HBoxContainer.new()
	identity.name = "HeroIdentityRow"
	identity.add_theme_constant_override("separation", 10)
	_hero_card_container.add_child(identity)

	var portrait_px := clampf(128.0 * s, 96.0, 128.0)
	var portrait_slot := PanelContainer.new()
	portrait_slot.name = "PauseDossierPortraitSlot"
	portrait_slot.custom_minimum_size = Vector2(portrait_px, portrait_px)
	portrait_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_slot.add_theme_stylebox_override("panel", _translucent_style(0.55, 10.0))
	identity.add_child(portrait_slot)

	var portrait := TextureRect.new()
	portrait.name = "PauseDossierPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite_path := str(config.get("sprite_path", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	portrait_slot.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.name = "HeroIdentityText"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	identity.add_child(text_box)

	var title := Label.new()
	title.name = "PauseDossierTitle"
	title.text = str(config.get("title", "Герой"))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", _readable_px(20.0))
	title.add_theme_color_override("font_color", COLOR_TITLE)
	text_box.add_child(title)

	_add_identity_row(text_box, "PauseDossierWeapon", "Оружие", str(weapon.get("title", "—")))
	_add_identity_row(text_box, "PauseDossierLevel", "Уровень", "%d · XP %d/%d" % [
		int(_player.get("level")), int(_player.get("xp")), int(_player.get("xp_to_next")),
	])
	var ascension_level := 0
	if _player.get_parent() != null and _player.get_parent().get("selected_ascension_level") != null:
		ascension_level = int(_player.get_parent().get("selected_ascension_level"))
	_add_identity_row(text_box, "PauseDossierAscension", "Возвышение", str(ascension_level))

	var divider := ColorRect.new()
	divider.name = "HeroCardDivider"
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.color = Color(0.52, 0.41, 0.24, 0.55)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_card_container.add_child(divider)

	_base_stats_container = VBoxContainer.new()
	_base_stats_container.name = "BaseStatsList"
	_base_stats_container.add_theme_constant_override("separation", 2)
	_hero_card_container.add_child(_base_stats_container)


func _add_identity_row(parent: VBoxContainer, row_name: String, kind_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var kind := Label.new()
	kind.name = "%sKind" % row_name
	kind.text = kind_text
	kind.add_theme_font_size_override("font_size", _readable_px(14.0))
	kind.add_theme_color_override("font_color", COLOR_KIND)
	row.add_child(kind)

	var value := Label.new()
	value.name = "%sValue" % row_name
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_size_override("font_size", _readable_px(14.0))
	value.add_theme_color_override("font_color", COLOR_BODY)
	row.add_child(value)


func _refresh_stats() -> void:
	if _base_stats_container == null or _derived_groups_container == null:
		return

	for child in _base_stats_container.get_children():
		child.queue_free()
	for child in _derived_groups_container.get_children():
		child.queue_free()

	if _player == null or not is_instance_valid(_player):
		return

	var sections: Dictionary = StatFormulas.stat_sections_for_player(_player)
	var priority_ids := ProgressionData.attribute_priorities(str(_player.get("character_id")))
	var base_entries: Array = sections.get("base", [])
	base_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai := priority_ids.find(str(a.get("id", "")))
		var bi := priority_ids.find(str(b.get("id", "")))
		if ai == -1:
			ai = 999
		if bi == -1:
			bi = 999
		if ai == bi:
			return str(a.get("name_ru", "")) < str(b.get("name_ru", ""))
		return ai < bi
	)
	for entry in base_entries:
		_base_stats_container.add_child(_make_basic_stat_row(entry))

	var derived_entries_by_id := _entries_by_id(sections.get("derived", []))
	for group in DERIVED_GROUPS:
		_derived_groups_container.add_child(_make_derived_group(group, derived_entries_by_id))


func _entries_by_id(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		var stat_entry: Dictionary = entry
		result[str(stat_entry.get("id", ""))] = stat_entry
	return result


# Плотный chip-ряд базового стата: иконка + имя + ★ (main-атрибут) + значение.
# Минимумы SCRUM-839: ряд ≥44, имя ≥17 / значение ≥18, иконка ≥44
# (реестр скейлит запрошенные 30 → 44).
func _make_basic_stat_row(entry: Dictionary) -> Control:
	var stat_id := str(entry.get("id", ""))
	var character_id := str(_player.get("character_id")) if _player != null and is_instance_valid(_player) else ""
	var is_priority := ProgressionData.attribute_priorities(character_id).has(stat_id)
	var row := PanelContainer.new()
	row.name = "BaseStatRow_%s" % stat_id
	row.custom_minimum_size = Vector2(0, READABLE_BASE_ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = _tooltip_for_entry(entry)
	if is_priority:
		row.tooltip_text += "\n\n%s" % ProgressionData.attribute_priority_reason(character_id, stat_id)
	row.add_theme_stylebox_override("panel", _stat_row_style(false, is_priority))
	row.mouse_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _stat_row_style(true, is_priority))
	)
	row.mouse_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _stat_row_style(false, is_priority))
	)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)

	var icon := UIIconRegistry.make_icon(stat_id, Vector2(30, 30))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)

	var name_label := Label.new()
	name_label.name = "BaseStatName_%s" % stat_id
	name_label.text = str(entry.get("name_ru", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", _readable_px(17.0))
	name_label.add_theme_color_override("font_color", COLOR_BODY)
	line.add_child(name_label)

	if is_priority:
		var badge := Label.new()
		badge.name = "PriorityBadge_%s" % stat_id
		badge.text = "★"
		badge.tooltip_text = ProgressionData.attribute_priority_reason(character_id, stat_id)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", _readable_px(17.0))
		badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
		line.add_child(badge)

	var value_label := Label.new()
	value_label.name = "BaseStatValue_%s" % stat_id
	value_label.text = _compact_value_text(entry)
	value_label.custom_minimum_size = Vector2(_readable_px(52.0), 0)
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _readable_px(18.0))
	value_label.add_theme_color_override("font_color", _value_color(entry))
	line.add_child(value_label)
	return row


# Секция «Боевых параметров»: кожаный чип 0.86, цветной маркер-полоска слева
# заголовка, внутри чипы-ряды в 2 колонки.
func _make_derived_group(group: Dictionary, entries_by_id: Dictionary) -> Control:
	var s := _atlas_scale()
	var group_panel := PanelContainer.new()
	group_panel.name = "DerivedStatGroup_%s" % str(group.get("id", ""))
	group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_panel.add_theme_stylebox_override("panel", _chip_style(0.86, maxf(6.0, roundf(12.0 * s))))
	var accent: Color = group.get("accent", Color(0.95, 0.78, 0.32, 1.0))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	group_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var marker := ColorRect.new()
	marker.name = "DerivedGroupMarker_%s" % str(group.get("id", ""))
	marker.custom_minimum_size = Vector2(5.0, 24.0)
	marker.color = accent
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(marker)

	var title := Label.new()
	title.text = str(group.get("title", "Группа"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", _readable_px(18.0))
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	header.add_child(title)

	var chips := GridContainer.new()
	chips.name = "DerivedStatChips_%s" % str(group.get("id", ""))
	chips.columns = 2
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	box.add_child(chips)

	for stat_id in group.get("stats", []):
		if entries_by_id.has(str(stat_id)):
			chips.add_child(_make_stat_chip(entries_by_id[str(stat_id)]))
	return group_panel


# Плотный ряд параметра: иконка + имя + значение в одну строку.
# Минимумы SCRUM-839: чип ≥236×54, имя ≥15 / значение ≥17, иконка ≥46
# (реестр скейлит запрошенные 32 → 46).
func _make_stat_chip(entry: Dictionary) -> Control:
	var stat_id := str(entry.get("id", ""))
	var chip := PanelContainer.new()
	chip.name = "DerivedStatChip_%s" % stat_id
	chip.custom_minimum_size = Vector2(READABLE_CHIP_WIDTH, READABLE_CHIP_HEIGHT)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = _tooltip_for_entry(entry)
	chip.add_theme_stylebox_override("panel", _stat_row_style(false))
	chip.mouse_entered.connect(func() -> void:
		chip.add_theme_stylebox_override("panel", _stat_row_style(true))
	)
	chip.mouse_exited.connect(func() -> void:
		chip.add_theme_stylebox_override("panel", _stat_row_style(false))
	)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	chip.add_child(line)

	var icon := UIIconRegistry.make_icon(stat_id, Vector2(32, 32))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)

	var name_label := Label.new()
	name_label.name = "DerivedStatName_%s" % stat_id
	name_label.text = str(entry.get("name_ru", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", _readable_px(15.0))
	name_label.add_theme_color_override("font_color", COLOR_BODY)
	line.add_child(name_label)

	var value_label := Label.new()
	value_label.name = "DerivedStatValue_%s" % stat_id
	value_label.text = _compact_value_text(entry)
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _readable_px(17.0))
	value_label.add_theme_color_override("font_color", _value_color(entry))
	line.add_child(value_label)
	return chip


# Чип-ряд контента (0.62, hover 0.82) — язык рядов Атласа
# (числа = ui_screens._unified_apply_row_theme normal/hover).
func _stat_row_style(is_hovered: bool, is_priority := false) -> StyleBoxFlat:
	var style := _chip_style(0.82 if is_hovered else 0.62, 4.0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	if is_hovered:
		style.border_color = Color(0.72, 0.58, 0.34, 0.95)
	if is_priority:
		style.border_color = Color(0.93, 0.77, 0.40, 0.95) if is_hovered else Color(0.70, 0.56, 0.32, 0.95)
	return style


func _compact_value_text(entry: Dictionary) -> String:
	return str(entry.get("value_text", "N/A")).replace(" / sec", "/s").replace(" units", "")


func _show_end_run_confirm() -> void:
	# Основной путь — модалка EndRunConfirm ui_screens (SCRUM-883, стиль quit-диалога).
	if end_run_confirm_handler.is_valid():
		end_run_confirm_handler.call()
		return
	# Standalone-фолбэк (сцена без ui_screens): движковый диалог.
	var dialog := ConfirmationDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = "Завершить забег?"
	dialog.dialog_text = "Завершить текущий забег?"
	dialog.confirmed.connect(func() -> void:
		end_run_confirmed.emit()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 140))


# SCRUM-593/SCRUM-851/SCRUM-890: тултип статов — движковый попап с чип-рамкой
# TooltipPanel из GlobalTooltip.make_theme; контент — титул золотом + тело светлым
# (GlobalTooltip.make_tooltip_content), позиция и кламп — GlobalTooltip.
func _make_custom_tooltip(for_text: String) -> Object:
	return GlobalTooltip.make_tooltip_content(for_text, self)


func _install_global_tooltip_skin() -> void:
	GlobalTooltip.install_on_tree(self, GlobalTooltipControl)


# SCRUM-851: тултип краткий — имя, значение, одно описание; формулы и списки
# производных — справочная вода, им место в кодексе.
func _tooltip_for_entry(entry: Dictionary) -> String:
	return "%s — %s\n%s" % [
		str(entry.get("name_ru", "")),
		str(entry.get("value_text", "N/A")),
		str(entry.get("description", "")),
	]


func _value_color(entry: Dictionary) -> Color:
	var raw_value: Variant = entry.get("value", null)
	if raw_value == null:
		return Color(0.62, 0.66, 0.70, 1.0)

	var value := float(raw_value)
	var stat_type := str(entry.get("type", "derived"))
	if stat_type == "base":
		if value >= 8.0:
			return VALUE_HIGH
		if value <= 3.0:
			return VALUE_LOW
		return VALUE_NEUTRAL

	var stat_id := str(entry.get("id", ""))
	match stat_id:
		"damage", "magic_damage", "sound_wave_damage":
			return VALUE_HIGH if value >= 15.0 else VALUE_EFFECTIVE
		"attack_speed":
			return VALUE_HIGH if value >= 1.2 else VALUE_EFFECTIVE
		"health_point":
			return VALUE_HIGH if value >= 90.0 else VALUE_EFFECTIVE
		"crit_chance", "dodge", "defense":
			if value >= 0.25:
				return VALUE_HIGH
			if value <= 0.06:
				return VALUE_LOW
		"attack_range", "aoe_radius", "pickup_radius":
			return VALUE_HIGH if value >= 250.0 else VALUE_EFFECTIVE

	return VALUE_NEUTRAL


# --- Локальный дубль глобального кнопочного кита -----------------------------
# Правило 2: кнопки — только глобальный кит. size-маппинг и margins/content
# скопированы из ui_screens (_text_button_unique_id/_button_asset_type):
# высота 72 → нативные 220/240/260-плиты, 104 → back_260x104,
# промежуточная 88 → minimal_metal back_m (generic 9-slice).
func _kit_button(text: String, width: float, variant := "default") -> Button:
	var button := Button.new()
	button.text = text
	var height := _action_button_height()
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _readable_px(16.0))
	_apply_kit_button_theme(button, variant)
	return button


func _apply_kit_button_theme(button: Button, variant := "default") -> void:
	var normal_tint := Color.WHITE
	var pressed_tint := Color(0.92, 0.88, 0.82, 1.0)
	if variant == "danger":
		# danger-роль кита: красный tint плит (паритет с локальным китом досье до SCRUM-890).
		normal_tint = BUTTON_DANGER_TINT
		pressed_tint = BUTTON_DANGER_PRESSED_TINT
	for state in KIT_STATES:
		var tint := normal_tint
		match state:
			"hover":
				tint = BUTTON_HOVER_EXTRA_TINT if variant != "danger" else BUTTON_DANGER_TINT
			"focus":
				tint = Color(1.20, 1.20, 1.20, 1.0) if variant != "danger" else BUTTON_DANGER_TINT
			"pressed":
				tint = pressed_tint
			"disabled":
				tint = Color(0.72, 0.72, 0.72, 1.0)
		button.add_theme_stylebox_override(state, _kit_button_state_style(button.custom_minimum_size, state, tint))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _kit_button_state_style(size: Vector2, state: String, tint: Color) -> StyleBox:
	var plate_id := ""
	if size.y <= 76.0:
		if size.x <= 230.0:
			plate_id = "quit_220x72"
		elif size.x <= 250.0:
			plate_id = "continue_240x72"
		elif size.x <= 300.0:
			plate_id = "later_260x72"
	elif size.y >= 96.0 and size.x >= 240.0:
		plate_id = "back_260x104"

	var texture: Texture2D = null
	var margins := KIT_BACK_M_MARGINS
	var content := KIT_BACK_M_CONTENT
	if plate_id != "":
		var suffix := "_%s" % state
		texture = load("%sui_btn_text_unique_%s%s.png" % [KIT_UNIQUE_DIR, plate_id, suffix]) as Texture2D
		margins = KIT_UNIQUE_104_MARGINS if plate_id == "back_260x104" else KIT_UNIQUE_72_MARGINS
		content = KIT_UNIQUE_104_CONTENT if plate_id == "back_260x104" else KIT_UNIQUE_72_CONTENT
	else:
		var mm_suffix := "" if state == "normal" else "_%s" % state
		texture = load("%sui_btn_minimal_metal_back_m%s.png" % [KIT_MINIMAL_DIR, mm_suffix]) as Texture2D

	if texture == null:
		return _chip_style(0.9, 10.0)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin(SIDE_LEFT, margins.x)
	style.set_texture_margin(SIDE_TOP, margins.y)
	style.set_texture_margin(SIDE_RIGHT, margins.z)
	style.set_texture_margin(SIDE_BOTTOM, margins.w)
	style.modulate_color = tint
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style
