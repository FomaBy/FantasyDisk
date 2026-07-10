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

# SCRUM-893: язык Атласа в полном составе — полая рама meta40 по краю экрана
# (числа = ui_screens._atlas_frame_style/_unified_safe_margins, коэффициент
# захода в тёмное поле рамы 0.86 = атлас после фидбека), парадная рама портрета
# (PixelLab), герб класса и орнамент-разделители.
const META40_FRAME_BORDER_PATH := "res://assets/sprites/ui/meta40/frame_border.png"
const ATLAS_FRAME_SOURCE_SIZE := Vector2(1536.0, 1024.0)
const ATLAS_FRAME_SOURCE_MARGIN := 160.0
const INNER_RESERVE_COMPACT := 24.0
const INNER_RESERVE_LARGE := 32.0
const PORTRAIT_FRAME_PATH := "res://assets/sprites/ui/atlas_style/dossier_portrait_frame.png"
const CLASS_CREST_DIR := "res://assets/sprites/ui/meta40/"
const DIVIDER_ORNAMENT_PATH := "res://assets/sprites/ui/atlas_style/divider_ornament.png"

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
		"id": "support_control",
		"title": "Поддержка / Контроль",
		"stats": ["aura_radius", "buff_power", "knockback_distance"],
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
var _base_stats_grid: GridContainer = null
var _derived_groups_container: GridContainer = null
var _survival_stats_container: VBoxContainer = null
var _hero_card_container: VBoxContainer = null
var _equipment_flow: HFlowContainer = null
var _arsenal_box: VBoxContainer = null
var _player: Node = null
var _dossier_root: Control = null
var _dossier_header: HBoxContainer = null
var _dossier_body: HBoxContainer = null
var _hero_card: PanelContainer = null
var _right_column: VBoxContainer = null
var _hero_scroll: ScrollContainer = null
var _derived_scroll: ScrollContainer = null
var _button_box: HBoxContainer = null
var _action_buttons: Array[Button] = []
var _title_label: Label = null
var _header_summary: Label = null
var _frame_panel: PanelContainer = null
var _focus_tooltip: PanelContainer = null
var _focus_tooltip_label: Label = null
var _focus_tooltip_anchor: Control = null
var _base_focus_targets: Array[Control] = []
var _survival_focus_targets: Array[Control] = []
var _derived_focus_targets: Array[Control] = []
var _reserve_masks: Array[ColorRect] = []

# SCRUM-890 (доработка): derived-статы выживания живут в карточке героя
# компактным блоком под базовыми статами; «Призывы» добавляются одной строкой
# только у призывного кита (канон: ProgressionData.weapon_archetype == "summon").
const SURVIVAL_STAT_IDS := ["health_point", "defense", "dodge", "regeneration"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Тултипы — глобальный чип-стиль (SCRUM-890): рамку рисует TooltipPanel из
	# GlobalTooltip.make_theme, свой texture-override сцене больше не нужен.
	theme = GlobalTooltip.make_theme()
	_build_layout()
	resized.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	call_deferred("_install_global_tooltip_skin")


func setup(player: Node) -> void:
	_player = player
	_refresh_hero_card()
	_refresh_stats()
	call_deferred("_apply_responsive_layout")
	call_deferred("_rebuild_focus_navigation")
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


# SCRUM-893: полая рама meta40 на весь экран — как на экранах атласа/настроек/
# кодекса. Контент живёт в safe-зоне (маргины 160·vp/source ×0.86); фолбэк без
# ассета — прежний плотный чип.
func _frame_style() -> StyleBox:
	if not ResourceLoader.exists(META40_FRAME_BORDER_PATH):
		return _chip_style(0.95, maxf(7.0, roundf(16.0 * _atlas_scale())))
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = Vector2(2560.0, 1440.0)
	var style := StyleBoxTexture.new()
	style.texture = load(META40_FRAME_BORDER_PATH)
	style.texture_margin_left = ATLAS_FRAME_SOURCE_MARGIN
	style.texture_margin_top = ATLAS_FRAME_SOURCE_MARGIN
	style.texture_margin_right = ATLAS_FRAME_SOURCE_MARGIN
	style.texture_margin_bottom = ATLAS_FRAME_SOURCE_MARGIN
	style.draw_center = false
	var margin_h := roundf(ATLAS_FRAME_SOURCE_MARGIN * vp.x / ATLAS_FRAME_SOURCE_SIZE.x)
	var margin_v := roundf(ATLAS_FRAME_SOURCE_MARGIN * vp.y / ATLAS_FRAME_SOURCE_SIZE.y)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


# Орнамент-разделитель секций (atlas_style); фолбэк — латунная линия 2px.
func _make_section_divider() -> Control:
	if ResourceLoader.exists(DIVIDER_ORNAMENT_PATH):
		var ornament := TextureRect.new()
		ornament.name = "DossierDivider"
		ornament.texture = load(DIVIDER_ORNAMENT_PATH)
		ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ornament.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ornament.custom_minimum_size = Vector2(0.0, maxf(16.0, roundf(24.0 * _atlas_scale())))
		ornament.modulate = Color(1.0, 1.0, 1.0, 0.85)
		ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return ornament
	var line := ColorRect.new()
	line.name = "DossierDivider"
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.color = Color(0.52, 0.41, 0.24, 0.55)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


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
	# SCRUM-893: рама полая — фон паузы теперь дим, гасим игру сильнее, чтобы
	# контент досье читался как передний план.
	overlay.color = Color(0.01, 0.015, 0.025, 0.88)
	add_child(overlay)

	_dossier_root = Control.new()
	_dossier_root.name = "PauseStatsMenuRoot"
	_dossier_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dossier_root)
	_build_reserve_masks(_dossier_root)

	var content := Control.new()
	content.name = "DossierContentRoot"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	_dossier_root.add_child(content)

	var s := _atlas_scale()
	_build_header(content, s)
	_build_body(content, s)
	_build_action_footer(content)
	_build_focus_tooltip(content)

	# The hollow shell is the final, mouse-ignored art layer. All runtime
	# content is laid out inside the published inner rect before this node.
	_frame_panel = PanelContainer.new()
	_frame_panel.name = "EscapeStatsPanelFrame"
	_frame_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame_panel.add_theme_stylebox_override("panel", _frame_style())
	_dossier_root.add_child(_frame_panel)


func _build_reserve_masks(parent: Control) -> void:
	for side in ["Top", "Bottom", "Left", "Right"]:
		var mask := ColorRect.new()
		mask.name = "DossierReserveMask%s" % side
		mask.color = Color(0.01, 0.015, 0.025, 1.0)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(mask)
		_reserve_masks.append(mask)


# SCRUM-983: the header is informational only. All destructive/navigation
# actions live in a fixed footer so compact viewports retain a stable body.
func _build_header(parent: Control, s: float) -> void:
	_dossier_header = HBoxContainer.new()
	_dossier_header.name = "DossierHeader"
	_dossier_header.add_theme_constant_override("separation", 12)
	parent.add_child(_dossier_header)

	var title_chip := PanelContainer.new()
	title_chip.name = "DossierTitleChip"
	title_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_chip.add_theme_stylebox_override("panel", _chip_style(0.86, maxf(5.0, roundf(10.0 * s))))
	_dossier_header.add_child(title_chip)

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

	_title_label = Label.new()
	_title_label.name = "DossierTitleLabel"
	_title_label.text = "Досье героя"
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", _readable_px(22.0))
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_row.add_child(_title_label)

	var spacer := Control.new()
	spacer.name = "DossierHeaderSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier_header.add_child(spacer)

	_header_summary = Label.new()
	_header_summary.name = "DossierHeaderSummary"
	_header_summary.text = "Герой · текущий билд"
	_header_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header_summary.add_theme_font_size_override("font_size", _readable_px(15.0))
	_header_summary.add_theme_color_override("font_color", COLOR_KIND)
	_dossier_header.add_child(_header_summary)


func _build_action_footer(parent: Control) -> void:
	_button_box = HBoxContainer.new()
	_button_box.name = "PauseControlButtons"
	_button_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(_button_box)

	var resume_button := _kit_button("Продолжить", 220.0)
	resume_button.name = "PauseResumeButton"
	resume_button.pressed.connect(func() -> void:
		resume_requested.emit()
	)
	_button_box.add_child(resume_button)

	var settings_button := _kit_button("Настройки", 220.0)
	settings_button.name = "PauseSettingsButton"
	settings_button.pressed.connect(func() -> void:
		settings_requested.emit()
	)
	_button_box.add_child(settings_button)

	var end_run_button := _kit_button("Завершить забег", 260.0, "danger")
	end_run_button.name = "PauseEndRunButton"
	end_run_button.pressed.connect(_show_end_run_confirm)
	_button_box.add_child(end_run_button)

	var menu_button := _kit_button("Главное меню", 220.0)
	menu_button.name = "PauseMainMenuButton"
	menu_button.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	_button_box.add_child(menu_button)
	_action_buttons = [resume_button, settings_button, end_run_button, menu_button]

	# SCRUM-812: досье проходимо с геймпада/стрелок — горизонтальное кольцо фокуса,
	# стартовый фокус «Продолжить». B/Esc (resume) — централизованно в main._input.
	var ring: Array[Button] = [resume_button, settings_button, end_run_button, menu_button]
	for i in range(ring.size()):
		var b := ring[i]
		b.focus_mode = Control.FOCUS_ALL
		b.focus_neighbor_left = ring[(i - 1 + ring.size()) % ring.size()].get_path()
		b.focus_neighbor_right = ring[(i + 1) % ring.size()].get_path()
	resume_button.call_deferred("grab_focus")


func _build_body(parent: Control, s: float) -> void:
	_dossier_body = HBoxContainer.new()
	_dossier_body.name = "DossierBody"
	_dossier_body.add_theme_constant_override("separation", maxi(10, int(roundf(16.0 * s))))
	parent.add_child(_dossier_body)

	# ЛЕВО — карточка героя: портрет, класс, оружие/уровень/возвышение, 8 базовых
	# статов плотными chip-рядами и компактный блок «Выживание».
	_hero_card = PanelContainer.new()
	_hero_card.name = "HeroCard"
	# SCRUM-893: шире под парадный портрет 200px + ряды с значениями.
	_hero_card.custom_minimum_size = Vector2(clampf(520.0 * s, 320.0, 560.0), 0.0)
	_hero_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_card.add_theme_stylebox_override("panel", _chip_style(0.90, 12.0))
	_dossier_body.add_child(_hero_card)

	# SCRUM-890 (доработка): на компакт-высотах контент карточки длиннее панели —
	# вертикальный скролл; на ≥1920×1080 контент помещается и скролл не активен.
	_hero_scroll = ScrollContainer.new()
	_hero_scroll.name = "HeroCardScroll"
	_hero_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hero_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_scroll.follow_focus = true
	_hero_card.add_child(_hero_scroll)

	_hero_card_container = VBoxContainer.new()
	_hero_card_container.name = "HeroCardContent"
	_hero_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SCRUM-893: сепарация 4 + портрет 188 — карточка (8 базовых + «Выживание»)
	# помещается на 1440p без скролла; на компактных высотах скролл остаётся.
	_hero_card_container.add_theme_constant_override("separation", 4)
	_hero_scroll.add_child(_hero_card_container)

	# ПРАВО — «Боевые параметры»: 4 секции кожаными чипами в сетке 2×2.
	_right_column = VBoxContainer.new()
	_right_column.name = "DerivedStatsPanel"
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", maxi(6, int(roundf(10.0 * s))))
	_dossier_body.add_child(_right_column)

	var header := HBoxContainer.new()
	header.name = "DerivedStatsHeader"
	header.add_theme_constant_override("separation", 10)
	_right_column.add_child(header)

	var stats_title := Label.new()
	stats_title.name = "DerivedStatsTitle"
	stats_title.text = "Боевые параметры"
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_title.add_theme_font_size_override("font_size", _readable_px(24.0))
	stats_title.add_theme_color_override("font_color", COLOR_TITLE)
	header.add_child(stats_title)

	var stats_hint := Label.new()
	stats_hint.name = "DerivedStatsHint"
	stats_hint.text = "Фокус или наведение — подробности"
	stats_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_hint.add_theme_font_size_override("font_size", _readable_px(14.0))
	stats_hint.add_theme_color_override("font_color", COLOR_KIND)
	header.add_child(stats_hint)

	# Без скролла на ≥1920×1080 (сетка 2×2 помещается в тело); на компактных
	# вьюпортах секции складываются в 1 колонку и правая зона скроллится.
	_derived_scroll = ScrollContainer.new()
	_derived_scroll.name = "DerivedStatsScroll"
	_derived_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_derived_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_derived_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_derived_scroll.follow_focus = true
	_right_column.add_child(_derived_scroll)

	# Скролл держит и сетку, и снаряжение: на 1440p всё помещается без скролла,
	# на компактных вьюпортах правая зона листается целиком.
	var right_content := VBoxContainer.new()
	right_content.name = "DerivedStatsScrollContent"
	right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_content.add_theme_constant_override("separation", maxi(8, int(roundf(12.0 * s))))
	_derived_scroll.add_child(right_content)

	_derived_groups_container = GridContainer.new()
	_derived_groups_container.name = "DerivedStatsGroups"
	_derived_groups_container.columns = 2
	_derived_groups_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_derived_groups_container.add_theme_constant_override("h_separation", maxi(8, int(roundf(12.0 * s))))
	_derived_groups_container.add_theme_constant_override("v_separation", maxi(8, int(roundf(12.0 * s))))
	right_content.add_child(_derived_groups_container)

	# SCRUM-893: «Арсенал» — механика оружия и ульта словами (та же дата-база,
	# что у кодекса: weapon.description + ultimate_config).
	var arsenal_panel := PanelContainer.new()
	arsenal_panel.name = "ArsenalPanel"
	arsenal_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arsenal_panel.add_theme_stylebox_override("panel", _chip_style(0.86, maxf(6.0, roundf(10.0 * s))))
	right_content.add_child(arsenal_panel)

	var arsenal_outer := VBoxContainer.new()
	arsenal_outer.add_theme_constant_override("separation", 6)
	arsenal_panel.add_child(arsenal_outer)

	var arsenal_header := HBoxContainer.new()
	arsenal_header.add_theme_constant_override("separation", 8)
	arsenal_outer.add_child(arsenal_header)

	var arsenal_marker := ColorRect.new()
	arsenal_marker.custom_minimum_size = Vector2(5.0, 22.0)
	arsenal_marker.color = Color(0.85, 0.62, 0.30, 1.0)
	arsenal_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arsenal_header.add_child(arsenal_marker)

	var arsenal_title := Label.new()
	arsenal_title.name = "ArsenalTitle"
	arsenal_title.text = "Арсенал"
	arsenal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arsenal_title.add_theme_font_size_override("font_size", _readable_px(18.0))
	arsenal_title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	arsenal_header.add_child(arsenal_title)

	_arsenal_box = VBoxContainer.new()
	_arsenal_box.name = "ArsenalEntries"
	_arsenal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arsenal_box.add_theme_constant_override("separation", 6)
	arsenal_outer.add_child(_arsenal_box)

	# SCRUM-893: под параметрами — снаряжение текущего забега (артефакты игрока).
	# Панель тянется на остаток высоты: свободное место читается как инвентарь
	# с запасом под будущие находки, а не как дыра лейаута.
	var equip_panel := PanelContainer.new()
	equip_panel.name = "RunEquipmentPanel"
	equip_panel.custom_minimum_size = Vector2(0.0, 110.0)
	equip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equip_panel.add_theme_stylebox_override("panel", _chip_style(0.86, maxf(6.0, roundf(10.0 * s))))
	right_content.add_child(equip_panel)

	var equip_box := VBoxContainer.new()
	equip_box.add_theme_constant_override("separation", 6)
	equip_panel.add_child(equip_box)

	var equip_header := HBoxContainer.new()
	equip_header.add_theme_constant_override("separation", 8)
	equip_box.add_child(equip_header)

	var equip_marker := ColorRect.new()
	equip_marker.custom_minimum_size = Vector2(5.0, 22.0)
	equip_marker.color = Color(0.94, 0.80, 0.46, 1.0)
	equip_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip_header.add_child(equip_marker)

	var equip_title := Label.new()
	equip_title.name = "RunEquipmentTitle"
	equip_title.text = "Снаряжение забега"
	equip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_title.add_theme_font_size_override("font_size", _readable_px(18.0))
	equip_title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	equip_header.add_child(equip_title)

	_equipment_flow = HFlowContainer.new()
	_equipment_flow.name = "RunEquipmentFlow"
	_equipment_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_flow.add_theme_constant_override("h_separation", 8)
	_equipment_flow.add_theme_constant_override("v_separation", 6)
	equip_box.add_child(_equipment_flow)


func _build_focus_tooltip(parent: Control) -> void:
	_focus_tooltip = PanelContainer.new()
	_focus_tooltip.name = "DossierFocusTooltip"
	_focus_tooltip.visible = false
	_focus_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_tooltip.z_index = 100
	_focus_tooltip.add_theme_stylebox_override("panel", _chip_style(0.98, 12.0))
	parent.add_child(_focus_tooltip)

	_focus_tooltip_label = Label.new()
	_focus_tooltip_label.name = "DossierFocusTooltipLabel"
	_focus_tooltip_label.custom_minimum_size = Vector2(390.0, 0.0)
	_focus_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focus_tooltip_label.add_theme_font_size_override("font_size", _readable_px(15.0))
	_focus_tooltip_label.add_theme_color_override("font_color", COLOR_BODY)
	_focus_tooltip.add_child(_focus_tooltip_label)


func _safe_rect_for_size(viewport_size: Vector2) -> Rect2:
	var margin_x := roundf(ATLAS_FRAME_SOURCE_MARGIN * viewport_size.x / ATLAS_FRAME_SOURCE_SIZE.x)
	var margin_y := roundf(ATLAS_FRAME_SOURCE_MARGIN * viewport_size.y / ATLAS_FRAME_SOURCE_SIZE.y)
	return Rect2(
		Vector2(margin_x, margin_y),
		viewport_size - Vector2(margin_x * 2.0, margin_y * 2.0)
	)


func _responsive_contract(viewport_size: Vector2) -> Dictionary:
	var safe_rect := _safe_rect_for_size(viewport_size)
	var compact := viewport_size.y < 900.0
	var large := viewport_size.y >= 1200.0
	var reserve := INNER_RESERVE_LARGE if large else INNER_RESERVE_COMPACT
	var inner_rect := safe_rect.grow(-reserve)
	var header_height := 60.0 if compact else (104.0 if large else 72.0)
	var header_gap := 12.0 if compact else (24.0 if large else 16.0)
	var footer_gap := 12.0 if compact else (40.0 if large else 28.0)
	var footer_bottom := 16.0 if compact else 36.0
	var action_height := 60.0 if compact else 72.0
	var hero_width := 320.0 if compact else (520.0 if large else 420.0)
	var column_gap := 12.0 if compact else (24.0 if large else 20.0)
	var action_widths := [220.0, 220.0, 260.0, 220.0] if compact else (
		[280.0, 280.0, 320.0, 300.0] if large else [260.0, 260.0, 280.0, 280.0]
	)
	var action_gap := 8.0 if compact else (20.0 if large else 16.0)
	var action_total := float(action_widths[0] + action_widths[1] + action_widths[2] + action_widths[3]) + action_gap * 3.0
	var action_rect := Rect2(
		Vector2(inner_rect.get_center().x - action_total * 0.5, inner_rect.end.y - footer_bottom - action_height),
		Vector2(action_total, action_height)
	)
	var body_top := inner_rect.position.y + header_height + header_gap
	var body_rect := Rect2(
		Vector2(inner_rect.position.x, body_top),
		Vector2(inner_rect.size.x, maxf(1.0, action_rect.position.y - footer_gap - body_top))
	)
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"header_rect": Rect2(inner_rect.position, Vector2(inner_rect.size.x, header_height)),
		"body_rect": body_rect,
		"hero_width": hero_width,
		"column_gap": column_gap,
		"action_rect": action_rect,
		"action_widths": action_widths,
		"action_gap": action_gap,
	}


func _apply_responsive_layout() -> void:
	if _dossier_root == null or not is_instance_valid(_dossier_root):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var contract := _responsive_contract(viewport_size)
	var safe_rect: Rect2 = contract["safe_rect"]
	var inner_rect: Rect2 = contract["inner_rect"]
	var header_rect: Rect2 = contract["header_rect"]
	var body_rect: Rect2 = contract["body_rect"]
	var action_rect: Rect2 = contract["action_rect"]

	_dossier_root.set_meta("gold_shell_content_rect", safe_rect)
	_dossier_root.set_meta("dossier_inner_content_rect", inner_rect)
	_apply_reserve_masks(viewport_size, inner_rect)
	_refresh_responsive_metrics(viewport_size)
	_dossier_body.add_theme_constant_override("separation", int(contract["column_gap"]))
	_hero_card.custom_minimum_size = Vector2(float(contract["hero_width"]), body_rect.size.y)
	if _base_stats_grid != null and is_instance_valid(_base_stats_grid):
		_base_stats_grid.columns = 1 if viewport_size.y < 900.0 else 2
	_button_box.add_theme_constant_override("separation", int(contract["action_gap"]))
	var action_widths: Array = contract["action_widths"]
	for index in range(_action_buttons.size()):
		var button := _action_buttons[index]
		button.custom_minimum_size = Vector2(float(action_widths[index]), action_rect.size.y)
		_apply_kit_button_theme(button, "danger" if index == 2 else "default")
	_frame_panel.add_theme_stylebox_override("panel", _frame_style())
	_frame_panel.set_meta("gold_shell_content_rect", safe_rect)
	_frame_panel.set_meta("dossier_inner_content_rect", inner_rect)
	if _hero_scroll != null:
		_hero_scroll.set_meta("dossier_scrollbar_lane", 14.0)
	if _derived_scroll != null:
		_derived_scroll.set_meta("dossier_scrollbar_lane", 14.0)
	_button_box.queue_sort()
	_dossier_body.queue_sort()
	call_deferred("_finalize_responsive_rects", contract)
	if _focus_tooltip != null and _focus_tooltip.visible:
		call_deferred("_position_focus_tooltip")


func _apply_reserve_masks(viewport_size: Vector2, inner_rect: Rect2) -> void:
	if _reserve_masks.size() != 4:
		return
	var mask_rects := [
		Rect2(Vector2.ZERO, Vector2(viewport_size.x, inner_rect.position.y)),
		Rect2(Vector2(0.0, inner_rect.end.y), Vector2(viewport_size.x, viewport_size.y - inner_rect.end.y)),
		Rect2(Vector2(0.0, inner_rect.position.y), Vector2(inner_rect.position.x, inner_rect.size.y)),
		Rect2(Vector2(inner_rect.end.x, inner_rect.position.y), Vector2(viewport_size.x - inner_rect.end.x, inner_rect.size.y)),
	]
	for index in range(_reserve_masks.size()):
		_reserve_masks[index].position = (mask_rects[index] as Rect2).position
		_reserve_masks[index].size = (mask_rects[index] as Rect2).size


func _refresh_responsive_metrics(viewport_size: Vector2) -> void:
	var s := _atlas_scale()
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", _readable_px(22.0))
	if _header_summary != null:
		_header_summary.add_theme_font_size_override("font_size", _readable_px(15.0))
	var title_chip := find_child("DossierTitleChip", true, false) as PanelContainer
	if title_chip != null:
		title_chip.add_theme_stylebox_override("panel", _chip_style(0.86, maxf(5.0, roundf(10.0 * s))))
	var title_emblem := find_child("DossierTitleEmblem", true, false) as TextureRect
	if title_emblem != null:
		var emblem_px := maxf(26.0, roundf(44.0 * s))
		title_emblem.custom_minimum_size = Vector2(emblem_px, emblem_px)
	var portrait_slot := find_child("PauseDossierPortraitSlot", true, false) as Control
	if portrait_slot != null:
		var portrait_px := clampf(188.0 * s, 128.0, 196.0)
		portrait_slot.custom_minimum_size = Vector2(portrait_px, portrait_px)
	var crest := find_child("PauseDossierCrest", true, false) as TextureRect
	if crest != null:
		var crest_px := maxf(30.0, roundf(42.0 * s))
		crest.custom_minimum_size = Vector2(crest_px, crest_px)
	for button in _action_buttons:
		button.add_theme_font_size_override("font_size", _readable_px(16.0))
	var derived_title := find_child("DerivedStatsTitle", true, false) as Label
	if derived_title != null:
		derived_title.add_theme_font_size_override("font_size", _readable_px(24.0))
	var derived_hint := find_child("DerivedStatsHint", true, false) as Label
	if derived_hint != null:
		derived_hint.add_theme_font_size_override("font_size", _readable_px(14.0))
	for node in find_children("DerivedStatChips_*", "GridContainer", true, false):
		(node as GridContainer).columns = 2 if viewport_size.x >= 1500.0 else 1
	for node in find_children("DerivedStatGroup_*", "PanelContainer", true, false):
		(node as PanelContainer).add_theme_stylebox_override("panel", _chip_style(0.86, maxf(6.0, roundf(12.0 * s))))
	for node in find_children("BaseStatName_*", "Label", true, false):
		(node as Label).add_theme_font_size_override("font_size", _readable_px(17.0))
	for node in find_children("BaseStatValue_*", "Label", true, false):
		var label := node as Label
		label.custom_minimum_size = Vector2(_readable_px(32.0), 0.0)
		label.add_theme_font_size_override("font_size", _readable_px(18.0))
	for node in find_children("SurvivalStatName_*", "Label", true, false):
		(node as Label).add_theme_font_size_override("font_size", _readable_px(15.0))
	for node in find_children("SurvivalStatValue_*", "Label", true, false):
		var label := node as Label
		label.custom_minimum_size = Vector2(_readable_px(96.0), 0.0)
		label.add_theme_font_size_override("font_size", _readable_px(16.0))
	for node in find_children("DerivedStatName_*", "Label", true, false):
		(node as Label).add_theme_font_size_override("font_size", _readable_px(15.0))
	for node in find_children("DerivedStatValue_*", "Label", true, false):
		var label := node as Label
		label.custom_minimum_size = Vector2(_readable_px(84.0), 0.0)
		label.add_theme_font_size_override("font_size", _readable_px(17.0))


func _finalize_responsive_rects(contract: Dictionary) -> void:
	if _dossier_header == null or not is_instance_valid(_dossier_header):
		return
	var header_rect: Rect2 = contract["header_rect"]
	var body_rect: Rect2 = contract["body_rect"]
	var action_rect: Rect2 = contract["action_rect"]
	_dossier_header.position = header_rect.position
	_dossier_header.size = header_rect.size
	_dossier_body.position = body_rect.position
	_dossier_body.size = body_rect.size
	_button_box.position = action_rect.position
	_button_box.size = action_rect.size
	_dossier_header.queue_sort()
	_dossier_body.queue_sort()
	_button_box.queue_sort()
	call_deferred("_rebuild_focus_navigation")


func _position_focus_tooltip() -> void:
	if _focus_tooltip == null or not _focus_tooltip.visible or _focus_tooltip_anchor == null:
		return
	if not is_instance_valid(_focus_tooltip_anchor):
		_focus_tooltip.visible = false
		return
	var viewport_size := get_viewport_rect().size
	var inner_rect: Rect2 = _responsive_contract(viewport_size)["inner_rect"]
	var minimum := _focus_tooltip.get_combined_minimum_size()
	var tooltip_size := Vector2(minf(430.0, maxf(260.0, minimum.x)), minf(288.0, maxf(80.0, minimum.y)))
	_focus_tooltip.size = tooltip_size
	var anchor_rect := _focus_tooltip_anchor.get_global_rect()
	var candidate := Vector2(anchor_rect.end.x + 12.0, anchor_rect.position.y)
	if candidate.x + tooltip_size.x > inner_rect.end.x:
		candidate.x = anchor_rect.position.x - tooltip_size.x - 12.0
	candidate.x = clampf(candidate.x, inner_rect.position.x, inner_rect.end.x - tooltip_size.x)
	candidate.y = clampf(candidate.y, inner_rect.position.y, inner_rect.end.y - tooltip_size.y)
	_focus_tooltip.position = candidate


func _show_focus_tooltip(anchor: Control) -> void:
	if anchor == null or anchor.tooltip_text.strip_edges() == "" or _focus_tooltip == null:
		return
	_focus_tooltip_anchor = anchor
	_focus_tooltip_label.text = anchor.tooltip_text
	_focus_tooltip.visible = true
	call_deferred("_position_focus_tooltip")


func _hide_focus_tooltip(anchor: Control) -> void:
	if _focus_tooltip_anchor != anchor:
		return
	_focus_tooltip_anchor = null
	_focus_tooltip.visible = false


func _wire_stat_focus(control: Control, target_list: Array[Control]) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_HELP
	target_list.append(control)
	control.focus_entered.connect(_show_focus_tooltip.bind(control))
	control.focus_exited.connect(_hide_focus_tooltip.bind(control))


func _rebuild_focus_navigation() -> void:
	var stat_targets: Array[Control] = []
	for source in [_base_focus_targets, _survival_focus_targets, _derived_focus_targets]:
		for target in source:
			if target != null and is_instance_valid(target) and target.is_inside_tree():
				stat_targets.append(target as Control)
	if stat_targets.is_empty() or _action_buttons.size() != 4:
		return
	for target in stat_targets:
		var left := _nearest_focus_target(target, stat_targets, Vector2.LEFT)
		var right := _nearest_focus_target(target, stat_targets, Vector2.RIGHT)
		var up := _nearest_focus_target(target, stat_targets, Vector2.UP)
		var down := _nearest_focus_target(target, stat_targets, Vector2.DOWN)
		if left != null:
			target.focus_neighbor_left = left.get_path()
		if right != null:
			target.focus_neighbor_right = right.get_path()
		target.focus_neighbor_top = (up if up != null else _nearest_action_by_x(target)).get_path()
		target.focus_neighbor_bottom = (down if down != null else _nearest_action_by_x(target)).get_path()
	for button in _action_buttons:
		var upper_target := _nearest_stat_edge_by_x(button, stat_targets, true)
		var lower_target := _nearest_stat_edge_by_x(button, stat_targets, false)
		if upper_target != null:
			button.focus_neighbor_top = upper_target.get_path()
		if lower_target != null:
			button.focus_neighbor_bottom = lower_target.get_path()


func _nearest_focus_target(source: Control, candidates: Array[Control], direction: Vector2) -> Control:
	var source_center := source.get_global_rect().get_center()
	var best: Control = null
	var best_score := INF
	for candidate in candidates:
		if candidate == source:
			continue
		var delta := candidate.get_global_rect().get_center() - source_center
		var primary := delta.dot(direction)
		if primary <= 1.0:
			continue
		var lateral := absf(delta.cross(direction))
		# Lateral drift is expensive: D-pad up/down preserves logical columns,
		# while left/right selects the geometric sibling in the same row.
		var score := primary + lateral * 3.0
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _nearest_action_by_x(source: Control) -> Button:
	var source_x := source.get_global_rect().get_center().x
	var best := _action_buttons[0]
	var best_distance := INF
	for button in _action_buttons:
		var distance := absf(button.get_global_rect().get_center().x - source_x)
		if distance < best_distance:
			best_distance = distance
			best = button
	return best


func _nearest_stat_edge_by_x(source: Control, candidates: Array[Control], bottom_edge: bool) -> Control:
	var edge_y := -INF if bottom_edge else INF
	for candidate in candidates:
		var y := candidate.get_global_rect().get_center().y
		edge_y = maxf(edge_y, y) if bottom_edge else minf(edge_y, y)
	var source_x := source.get_global_rect().get_center().x
	var best: Control = null
	var best_score := INF
	for candidate in candidates:
		var center := candidate.get_global_rect().get_center()
		var row_distance := absf(center.y - edge_y)
		var score := row_distance * 4.0 + absf(center.x - source_x)
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _refresh_hero_card() -> void:
	if _hero_card_container == null:
		return
	for child in _hero_card_container.get_children():
		child.queue_free()
	_base_stats_container = null
	_survival_stats_container = null
	if _player == null or not is_instance_valid(_player):
		return

	var s := _atlas_scale()
	var character_id := str(_player.get("character_id"))
	var weapon_id := str(_player.get("weapon_id"))
	var config: Dictionary = ProgressionData.character_config(character_id)
	var weapon: Dictionary = ProgressionData.weapon(character_id, weapon_id)
	if _title_label != null:
		_title_label.text = "Досье героя"
	if _header_summary != null:
		_header_summary.text = "%s · %s" % [str(config.get("title", "Герой")), str(weapon.get("title", "—"))]

	var identity := HBoxContainer.new()
	identity.name = "HeroIdentityRow"
	identity.add_theme_constant_override("separation", maxi(10, int(roundf(14.0 * s))))
	_hero_card_container.add_child(identity)

	# SCRUM-893: парадный портрет — крупный, в резной раме PixelLab поверх
	# тёмного колодца; фолбэк без ассета — прежний полупрозрачный слот.
	var portrait_px := clampf(188.0 * s, 128.0, 196.0)
	var portrait_slot := Control.new()
	portrait_slot.name = "PauseDossierPortraitSlot"
	portrait_slot.custom_minimum_size = Vector2(portrait_px, portrait_px)
	portrait_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(portrait_slot)

	var portrait_well := Panel.new()
	portrait_well.name = "PauseDossierPortraitWell"
	portrait_well.set_anchors_preset(Control.PRESET_FULL_RECT)
	var well_inset := roundf(portrait_px * 0.08)
	portrait_well.offset_left = well_inset
	portrait_well.offset_top = well_inset
	portrait_well.offset_right = -well_inset
	portrait_well.offset_bottom = -well_inset
	portrait_well.add_theme_stylebox_override("panel", _translucent_style(0.62, 10.0))
	portrait_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_slot.add_child(portrait_well)

	var portrait := TextureRect.new()
	portrait.name = "PauseDossierPortrait"
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	var portrait_inset := roundf(portrait_px * 0.10)
	portrait.offset_left = portrait_inset
	portrait.offset_top = portrait_inset
	portrait.offset_right = -portrait_inset
	portrait.offset_bottom = -portrait_inset
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite_path := str(config.get("sprite_path", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	portrait_slot.add_child(portrait)

	if ResourceLoader.exists(PORTRAIT_FRAME_PATH):
		var portrait_frame := TextureRect.new()
		portrait_frame.name = "PauseDossierPortraitFrame"
		portrait_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait_frame.texture = load(PORTRAIT_FRAME_PATH)
		portrait_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_slot.add_child(portrait_frame)

	var text_box := VBoxContainer.new()
	text_box.name = "HeroIdentityText"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 3)
	identity.add_child(text_box)

	# Имя героя золотом + герб класса meta40 рядом.
	var name_row := HBoxContainer.new()
	name_row.name = "PauseDossierNameRow"
	name_row.add_theme_constant_override("separation", 8)
	text_box.add_child(name_row)

	var crest_path := "%screst_%s.png" % [CLASS_CREST_DIR, character_id]
	if ResourceLoader.exists(crest_path):
		var crest := TextureRect.new()
		crest.name = "PauseDossierCrest"
		crest.texture = load(crest_path)
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var crest_px := maxf(30.0, roundf(42.0 * s))
		crest.custom_minimum_size = Vector2(crest_px, crest_px)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(crest)

	var title := Label.new()
	title.name = "PauseDossierTitle"
	title.text = str(config.get("title", "Герой"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", _readable_px(27.0))
	title.add_theme_color_override("font_color", COLOR_TITLE)
	name_row.add_child(title)

	_add_identity_row(text_box, "PauseDossierWeapon", "Оружие", str(weapon.get("title", "—")))
	_add_identity_row(text_box, "PauseDossierLevel", "Уровень", "%d · XP %d/%d" % [
		int(_player.get("level")), int(_player.get("xp")), int(_player.get("xp_to_next")),
	])
	var ascension_level := 0
	if _player.get_parent() != null and _player.get_parent().get("selected_ascension_level") != null:
		ascension_level = int(_player.get_parent().get("selected_ascension_level"))
	_add_identity_row(text_box, "PauseDossierAscension", "Возвышение", str(ascension_level))

	# SCRUM-893: орнамент-разделители atlas_style между секциями карточки.
	var divider := _make_section_divider()
	divider.name = "HeroCardDivider"
	_hero_card_container.add_child(divider)

	var base_title := Label.new()
	base_title.name = "BaseStatsTitle"
	base_title.text = "Характеристики"
	base_title.add_theme_font_size_override("font_size", _readable_px(16.0))
	base_title.add_theme_color_override("font_color", COLOR_KIND)
	_hero_card_container.add_child(base_title)

	_base_stats_container = VBoxContainer.new()
	_base_stats_container.name = "BaseStatsList"
	_base_stats_container.add_theme_constant_override("separation", 0)
	_hero_card_container.add_child(_base_stats_container)

	_hero_card_container.add_child(_make_section_divider())

	# SCRUM-890 (доработка): блок «Выживание» — оборонительные derived-статы
	# под базовыми (правые 4 секции остались атакующими).
	var survival_title := Label.new()
	survival_title.name = "SurvivalTitle"
	survival_title.text = "Выживание"
	survival_title.add_theme_font_size_override("font_size", _readable_px(16.0))
	survival_title.add_theme_color_override("font_color", COLOR_KIND)
	_hero_card_container.add_child(survival_title)

	_survival_stats_container = VBoxContainer.new()
	_survival_stats_container.name = "SurvivalStatsList"
	_survival_stats_container.add_theme_constant_override("separation", 2)
	_hero_card_container.add_child(_survival_stats_container)


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
	if _survival_stats_container != null:
		for child in _survival_stats_container.get_children():
			child.queue_free()

	if _player == null or not is_instance_valid(_player):
		return
	_base_focus_targets.clear()
	_survival_focus_targets.clear()
	_derived_focus_targets.clear()

	_base_stats_grid = GridContainer.new()
	_base_stats_grid.name = "BaseStatsGrid"
	_base_stats_grid.columns = 1 if get_viewport_rect().size.y < 900.0 else 2
	_base_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_base_stats_grid.add_theme_constant_override("h_separation", 6)
	_base_stats_grid.add_theme_constant_override("v_separation", 2)
	_base_stats_container.add_child(_base_stats_grid)

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
		_base_stats_grid.add_child(_make_basic_stat_row(entry))

	var derived_entries_by_id := _entries_by_id(sections.get("derived", []))
	for group in DERIVED_GROUPS:
		_derived_groups_container.add_child(_make_derived_group(group, derived_entries_by_id))
	_refresh_survival_rows(derived_entries_by_id)
	_refresh_arsenal()
	_refresh_equipment()
	call_deferred("_rebuild_focus_navigation")


# SCRUM-893: словесная часть досье — как играет оружие и что делает ульта.
func _refresh_arsenal() -> void:
	if _arsenal_box == null:
		return
	for child in _arsenal_box.get_children():
		child.queue_free()
	if _player == null or not is_instance_valid(_player):
		return
	var character_id := str(_player.get("character_id"))
	var weapon: Dictionary = ProgressionData.weapon(character_id, str(_player.get("weapon_id")))
	_add_arsenal_entry("ArsenalWeapon", "Оружие — %s" % str(weapon.get("title", "—")),
		str(weapon.get("description", "")))
	var ultimate: Dictionary = ProgressionData.ultimate_config(character_id)
	if not ultimate.is_empty():
		_add_arsenal_entry("ArsenalUltimate", "Ульта — %s" % str(ultimate.get("title", "")),
			str(ultimate.get("description", "")))


func _add_arsenal_entry(entry_name: String, kind_text: String, body_text: String) -> void:
	var entry := VBoxContainer.new()
	entry.name = entry_name
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 1)
	_arsenal_box.add_child(entry)

	var kind := Label.new()
	kind.name = "%sKind" % entry_name
	kind.text = kind_text
	kind.add_theme_font_size_override("font_size", _readable_px(15.0))
	kind.add_theme_color_override("font_color", COLOR_KIND)
	entry.add_child(kind)

	var body := Label.new()
	body.name = "%sBody" % entry_name
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", _readable_px(14.0))
	body.add_theme_color_override("font_color", COLOR_BODY)
	entry.add_child(body)


# SCRUM-893: чипы артефактов текущего забега (player.artifacts: [{id, title, tier?}]) +
# пустые слоты-сокеты meta40 до минимума 8 — свободное место панели читается
# как инвентарь под будущие находки, а не как дыра лейаута.
const EQUIPMENT_MIN_SLOTS := 8
const EQUIPMENT_SOCKET_PATH := "res://assets/sprites/ui/meta40/socket_minor.png"
# SCRUM-963: канон редкости — строки/цвета = ui_screens.TIER_LABELS/TIER_COLORS
# (сцена не имеет доступа к хелперам ui_screens — локальный дубль по паттерну файла).
const EQUIPMENT_TIER_LABELS := {1: "Обычный", 2: "Редкий", 3: "Эпический"}
const EQUIPMENT_TIER_COLORS := {
	1: Color(0.80, 0.86, 0.94, 1.0),
	2: Color(0.46, 0.78, 1.0, 1.0),
	3: Color(1.0, 0.74, 0.30, 1.0),
}


# SCRUM-963: уникальная иконка артефакта artifact_<id>.png (реестровая
# «artifact»-иконка — только dev-fallback на отсутствующий файл/пустой id).
func _equipment_artifact_icon(artifact_id: String) -> Control:
	var path := "%sartifact_%s.png" % [ShopUIConstants.ARTIFACT_ICON_DIR, artifact_id]
	if artifact_id != "" and ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.name = "RunEquipmentIcon_%s" % artifact_id
		icon.texture = load(path)
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icon
	return UIIconRegistry.make_icon("artifact", Vector2(22, 22))


# SCRUM-963: тултип чипа — редкость РОЛЛНУТОГО тира записи забега (фоллбек —
# корневой тир определения для старых сейвов) + описание из определения.
func _equipment_artifact_tooltip(artifact: Dictionary) -> String:
	var title := str(artifact.get("title", "Артефакт"))
	var definition: Dictionary = ProgressionData.artifact_definition(str(artifact.get("id", "")))
	var tier := int(artifact.get("tier", 0))
	if tier <= 0:
		tier = int(definition.get("tier", 0))
	var lines := PackedStringArray()
	if EQUIPMENT_TIER_LABELS.has(tier):
		lines.append("%s (%s)" % [title, EQUIPMENT_TIER_LABELS[tier]])
	else:
		lines.append(title)
	var description := str(definition.get("description", ""))
	if description != "":
		lines.append(description)
	return "\n".join(lines)


func _refresh_equipment() -> void:
	if _equipment_flow == null:
		return
	for child in _equipment_flow.get_children():
		child.queue_free()
	var artifacts: Array = []
	if _player != null and is_instance_valid(_player) and _player.get("artifacts") != null:
		artifacts = _player.get("artifacts")
	if artifacts.is_empty():
		var empty_label := Label.new()
		empty_label.name = "RunEquipmentEmpty"
		empty_label.text = "Артефакты ещё не найдены — ищи награды за бои и события."
		# EXPAND на всю строку flow — сокеты уходят на собственный ряд ниже.
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_font_size_override("font_size", _readable_px(14.0))
		empty_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70, 1.0))
		_equipment_flow.add_child(empty_label)
		_add_equipment_sockets(EQUIPMENT_MIN_SLOTS)
		return
	for artifact_entry in artifacts:
		# Совместимость со старыми сейвами: запись может быть голым title (String).
		var artifact: Dictionary = artifact_entry if artifact_entry is Dictionary else {"id": "", "title": str(artifact_entry)}
		var chip := PanelContainer.new()
		chip.name = "RunEquipmentChip_%s" % str(artifact.get("id", ""))
		chip.custom_minimum_size = Vector2(0, 40.0)
		chip.add_theme_stylebox_override("panel", _stat_row_style(false))
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = _equipment_artifact_tooltip(artifact)
		_equipment_flow.add_child(chip)

		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		chip.add_child(line)

		# SCRUM-963: уникальная иконка артефакта в чипе.
		var icon := _equipment_artifact_icon(str(artifact.get("id", "")))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)

		var chip_label := Label.new()
		chip_label.text = str(artifact.get("title", "Артефакт"))
		chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip_label.add_theme_font_size_override("font_size", _readable_px(14.0))
		# SCRUM-963: имя — цветом роллнутой редкости (язык карточек наград);
		# записи без тира (старые сейвы) остаются нейтральными.
		var rolled_tier := int(artifact.get("tier", 0))
		chip_label.add_theme_color_override("font_color", EQUIPMENT_TIER_COLORS.get(rolled_tier, COLOR_BODY))
		line.add_child(chip_label)
	_add_equipment_sockets(maxi(EQUIPMENT_MIN_SLOTS - artifacts.size(), 2))


func _add_equipment_sockets(count: int) -> void:
	if _equipment_flow == null or not ResourceLoader.exists(EQUIPMENT_SOCKET_PATH):
		return
	for i in range(count):
		var socket := TextureRect.new()
		socket.name = "RunEquipmentSlot_%d" % i
		socket.texture = load(EQUIPMENT_SOCKET_PATH)
		socket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		socket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		socket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		socket.custom_minimum_size = Vector2(56.0, 56.0)
		socket.modulate = Color(1.0, 1.0, 1.0, 0.55)
		socket.tooltip_text = "Свободный слот — артефакты выпадают из наград за бои и события."
		_equipment_flow.add_child(socket)


# SCRUM-890 (доработка): плотные ряды «Выживания» в карточке героя — ОЗ (тек/макс),
# Защита, Уворот, Регенерация; «Призывы» одной строкой только у призывного кита.
func _refresh_survival_rows(entries_by_id: Dictionary) -> void:
	if _survival_stats_container == null or _player == null or not is_instance_valid(_player):
		return
	for stat_id in SURVIVAL_STAT_IDS:
		if not entries_by_id.has(stat_id):
			continue
		var entry: Dictionary = entries_by_id[stat_id]
		var display_name := ""
		var value_override := ""
		if stat_id == "health_point":
			display_name = "ОЗ"
			var current_hp: Variant = _player.get("health")
			var max_hp: Variant = entry.get("value", null)
			if current_hp != null and max_hp != null:
				value_override = "%d/%d" % [int(round(clampf(float(current_hp), 0.0, float(max_hp)))), int(round(float(max_hp)))]
		_survival_stats_container.add_child(_make_survival_stat_row(entry, display_name, value_override))
	var weapon: Dictionary = ProgressionData.weapon(str(_player.get("character_id")), str(_player.get("weapon_id")))
	if ProgressionData.weapon_archetype(weapon) == "summon" and entries_by_id.has("summon_amount"):
		_survival_stats_container.add_child(_make_survival_stat_row(entries_by_id["summon_amount"], "Призывы"))


# Мини-ряд выживания: иконка 24 (реестр → 35) + имя + значение, высота ~40;
# тултип и hover — как у параметров правой зоны.
func _make_survival_stat_row(entry: Dictionary, display_name := "", value_override := "") -> Control:
	var stat_id := str(entry.get("id", ""))
	var row := PanelContainer.new()
	row.name = "SurvivalStatRow_%s" % stat_id
	row.custom_minimum_size = Vector2(0, 40.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = _tooltip_for_entry(entry)
	row.add_theme_stylebox_override("panel", _stat_row_style(false))
	row.mouse_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _stat_row_style(true))
	)
	row.mouse_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _stat_row_style(false))
	)
	row.focus_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _stat_row_style(true))
	)
	row.focus_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _stat_row_style(false))
	)
	_wire_stat_focus(row, _survival_focus_targets)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)

	var icon := UIIconRegistry.make_icon(stat_id, Vector2(24, 24))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)

	var name_label := Label.new()
	name_label.name = "SurvivalStatName_%s" % stat_id
	name_label.text = display_name if display_name != "" else str(entry.get("name_ru", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", _readable_px(15.0))
	name_label.add_theme_color_override("font_color", COLOR_BODY)
	line.add_child(name_label)

	var value_label := Label.new()
	value_label.name = "SurvivalStatValue_%s" % stat_id
	value_label.text = value_override if value_override != "" else _compact_value_text(entry)
	# SCRUM-893: clip_text обнуляет min-width Label — без явного минимума метка
	# схлопывается в 0 рядом с EXPAND_FILL-именем (значения «исчезали» на рендере).
	value_label.custom_minimum_size = Vector2(_readable_px(96.0), 0)
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _readable_px(16.0))
	value_label.add_theme_color_override("font_color", _value_color(entry))
	line.add_child(value_label)
	return row


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
	row.add_theme_stylebox_override("panel", _base_stat_row_style(false, is_priority))
	row.mouse_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _base_stat_row_style(true, is_priority))
	)
	row.mouse_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _base_stat_row_style(false, is_priority))
	)
	row.focus_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _base_stat_row_style(true, is_priority))
	)
	row.focus_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _base_stat_row_style(false, is_priority))
	)
	_wire_stat_focus(row, _base_focus_targets)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
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
	value_label.custom_minimum_size = Vector2(_readable_px(32.0), 0)
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
	# SCRUM-893: секции делят высоту сетки поровну (без пустого поля под ними).
	group_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	# SCRUM-893: 2 колонки чипов только на широких вьюпортах — на 1920 и уже
	# имя+значение не делят чип без эллипсиса, читаемость дороже плотности.
	chips.columns = 2 if get_viewport_rect().size.x >= 1500.0 else 1
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
	chip.focus_entered.connect(func() -> void:
		chip.add_theme_stylebox_override("panel", _stat_row_style(true))
	)
	chip.focus_exited.connect(func() -> void:
		chip.add_theme_stylebox_override("panel", _stat_row_style(false))
	)
	_wire_stat_focus(chip, _derived_focus_targets)

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
	# SCRUM-893: см. SurvivalStatValue — clip_text без min-width схлопывал значение в 0.
	value_label.custom_minimum_size = Vector2(_readable_px(84.0), 0)
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
# На компакт-высотах (<1000) вертикальный pad 1px: базовые ряды + блок
# «Выживание» держат карточку героя без скролла вплоть до 1600×900.
func _stat_row_style(is_hovered: bool, is_priority := false) -> StyleBoxFlat:
	var row_pad_v := 1.0 if get_viewport_rect().size.y < 1000.0 else 4.0
	var style := _chip_style(0.82 if is_hovered else 0.62, row_pad_v)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	if is_hovered:
		style.border_color = Color(0.72, 0.58, 0.34, 0.95)
	if is_priority:
		style.border_color = Color(0.93, 0.77, 0.40, 0.95) if is_hovered else Color(0.70, 0.56, 0.32, 0.95)
	return style


func _base_stat_row_style(is_hovered: bool, is_priority := false) -> StyleBoxFlat:
	var style := _stat_row_style(is_hovered, is_priority)
	# In the 1080p 2x4 grid every row is only ~205px wide. Six-pixel side
	# padding preserves a readable localized-name lane without shrinking icons,
	# font sizes or the accepted grid topology.
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	return style


func _compact_value_text(entry: Dictionary) -> String:
	var raw_value: Variant = entry.get("value", null)
	if raw_value == null:
		return "N/A"
	var value := float(raw_value)
	var stat_id := str(entry.get("id", ""))
	if stat_id in ["crit_chance", "dodge", "defense", "vampiric_chance", "range_multiplier"]:
		return "%d%%" % int(round(value * 100.0))
	if stat_id in ["crit_damage_multiplier", "ultimate_multiplier", "buff_power"]:
		return ("×%.2f" % value).replace(".", ",")
	if stat_id in ["attack_speed", "dot_speed", "regeneration"]:
		return ("%.2f/с" % value).replace(".", ",")
	if str(entry.get("type", "derived")) == "base" and is_equal_approx(value, roundf(value)):
		return str(int(round(value)))
	if stat_id in ["attack_range", "aoe_radius", "aura_radius", "projectile_speed", "knockback_distance", "knockback_power", "move_speed", "pickup_radius"]:
		return str(int(round(value)))
	return ("%.1f" % value).replace(".", ",")


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


# SCRUM-983: the visible row is compact; the tooltip owns the complete
# explanation, formula/source and influence list from StatFormulas.
func _tooltip_for_entry(entry: Dictionary) -> String:
	return "%s — %s\n%s\n\nФормула / источник: %s\nВлияет: %s" % [
		str(entry.get("name_ru", "")),
		_compact_value_text(entry),
		str(entry.get("description", "")),
		str(entry.get("formula", "")),
		str(entry.get("influences", "")),
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
		"damage", "magic_damage":
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
				tint = Color(0.72, 0.42, 0.42, 1.0) if variant == "danger" else Color(0.72, 0.72, 0.72, 1.0)
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
	if size.y <= 76.0:
		var vertical_margin := 12.0 if size.y <= 64.0 else 14.0
		var vertical_content := 10.0 if size.y <= 64.0 else 14.0
		margins.y = minf(margins.y, vertical_margin)
		margins.w = minf(margins.w, vertical_margin)
		content.y = minf(content.y, vertical_content)
		content.w = minf(content.w, vertical_content)

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
