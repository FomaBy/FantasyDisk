extends Control

signal resume_requested
signal settings_requested
signal end_run_confirmed
signal main_menu_requested

const StatFormulas := preload("res://scripts/stat_formulas.gd")
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")
const GlobalTooltipControl := preload("res://scripts/ui/global_tooltip_control.gd")
const ESCAPE_PANEL_FRAME := preload("res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png")
const STAT_BASIC_ROW_FRAME := preload("res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png")
const STAT_GROUP_FRAME := preload("res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png")
const STAT_CHIP_FRAME := preload("res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png")
const STAT_TOOLTIP_FRAME := preload("res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png")
# SCRUM-486/SCRUM-593: per-slot @2K pause dossier plus dedicated SCRUM-586 stat tooltip.
const ESCAPE_PANEL_FRAME_2K := preload("res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pd_panel.png")
const STAT_TOOLTIP_FRAME_2K := preload("res://assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png")
const STAT_SECTION_DIVIDER := preload("res://assets/sprites/ui/frames/escape/ui_stat_section_divider.png")
const PAUSE_END_MODAL_FRAME := preload("res://assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_modal.png")
const PAUSE_BUTTON_NORMAL := preload("res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_pause_280x60_normal.png")
const PAUSE_BUTTON_HOVER := preload("res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_pause_280x60_hover.png")
const PAUSE_BUTTON_FOCUS := preload("res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_pause_280x60_focus.png")
const PAUSE_BUTTON_PRESSED := preload("res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_pause_280x60_pressed.png")
const PAUSE_BUTTON_DISABLED := preload("res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_pause_280x60_disabled.png")
const PAUSE_BUTTON_TEXTURE_MARGINS := Vector4(34.0, 12.0, 34.0, 12.0)
const PAUSE_BUTTON_CONTENT_MARGINS := Vector4(45.0, 12.0, 45.0, 12.0)
const BUTTON_NEUTRAL_HOVER_TINT := Color(1.16, 1.16, 1.16, 1.0)
const BUTTON_NEUTRAL_FOCUS_TINT := Color(1.20, 1.20, 1.20, 1.0)
const BUTTON_NEUTRAL_HOVER_FONT := Color(1.0, 1.0, 1.0, 1.0)
const PAUSE_END_MODAL_SOURCE_SIZE := Vector2(986.0, 900.0)
const PAUSE_END_MODAL_TEXTURE_MARGINS := Vector4(46.0, 62.0, 46.0, 58.0)
const PAUSE_END_MODAL_CONTENT := Vector4(72.0, 92.0, 72.0, 84.0)

const VALUE_HIGH := Color(0.439, 0.949, 0.651, 1.0)
const VALUE_LOW := Color(1.0, 0.420, 0.420, 1.0)
const VALUE_NEUTRAL := Color(0.914, 0.863, 0.655, 1.0)
const VALUE_EFFECTIVE := Color(1.0, 0.863, 0.361, 1.0)
const TEXT_PRIMARY := Color(0.937, 0.886, 0.698, 1.0)
const TEXT_SECONDARY := Color(0.592, 0.647, 0.722, 1.0)

const DERIVED_GROUPS := [
	{
		"id": "physical_damage",
		"title": "Физический урон",
		"description": "Melee и прямой физический burst.",
		"stats": ["damage", "attack_speed", "crit_chance", "crit_damage_multiplier", "knockback_power"],
		"accent": Color(0.95, 0.38, 0.22, 1.0),
	},
	{
		"id": "magic_damage",
		"title": "Магия",
		"description": "Темная магия, области поражения и снаряды.",
		"stats": ["magic_damage", "aoe_radius", "projectile_speed", "attack_range", "range_multiplier"],
		"accent": Color(0.55, 0.42, 1.0, 1.0),
	},
	{
		"id": "sound_control",
		"title": "Звук / Контроль",
		"description": "Волны, ауры, бафы и отталкивание.",
		"stats": ["sound_wave_damage", "aura_radius", "buff_power", "knockback_distance"],
		"accent": Color(0.30, 0.86, 1.0, 1.0),
	},
	{
		"id": "dot_poison",
		"title": "Яд / периодический урон",
		"description": "Периодический урон и темп тиков.",
		"stats": ["dot_damage", "dot_speed"],
		"accent": Color(0.45, 0.95, 0.44, 1.0),
	},
	{
		"id": "survival",
		"title": "Выживаемость",
		"description": "Здоровье, защита, движение и восстановление.",
		"stats": ["health_point", "defense", "dodge", "move_speed", "absorb", "regeneration", "vampiric_amount", "vampiric_chance"],
		"accent": Color(0.95, 0.78, 0.32, 1.0),
	},
	{
		"id": "summons_support",
		"title": "Приспешники / Поддержка",
		"description": "Summons, pickup и будущие support-системы.",
		"stats": ["summon_amount", "pickup_radius", "ultimate_multiplier"],
		"accent": Color(0.90, 0.62, 1.0, 1.0),
	},
]

var _base_stats_container: VBoxContainer = null
var _artifacts_container: HFlowContainer = null
var _derived_groups_container: GridContainer = null
var _dossier_container: HBoxContainer = null
var _player: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlobalTooltip.make_theme()
	# Единственная рамка тултипа — на движковом попапе: своя SCRUM-586 stat_tooltip
	# рамка вместо общей, контент внутри — голый Label (см. _make_custom_tooltip).
	theme.set_stylebox("panel", "TooltipPanel", _tooltip_style())
	_build_layout()
	call_deferred("_install_global_tooltip_skin")


func setup(player: Node) -> void:
	_player = player
	_refresh_dossier()
	_refresh_stats()
	_refresh_artifacts()
	call_deferred("_install_global_tooltip_skin")


# SCRUM-484: координатная спека @2560×1440 — пауза-досье (двухколоночная модалка).
# Панель почти на весь экран (offset 20/18/-20/-18 → 2520×1404), _pause_end_modal_style
# margins (74,94,74,86)×1.56 → safe-area Rect2(135,165,2290,1123). Внутри ScrollContainer
# HBox(sep18): левая колонка управления (ширина 330, кнопки 280×60) + правая область
# статов/артефактов (группы-панели шириной 430). Контент list-driven, тянется по высоте.
const PD_PANEL_2K := Rect2(20, 18, 2520, 1404)
const PD_SAFE_2K := Rect2(135, 165, 2290, 1123)
const PD_LEFT_COLUMN_2K := Rect2(135, 165, 330, 1123)
const PD_RIGHT_AREA_2K := Rect2(483, 165, 1942, 1123)
const PD_BTN_2K := Rect2(0, 0, 280, 60)  # шаблон-размер кнопки управления
const PD_STAT_GROUP_2K := Rect2(0, 0, 430, 0)  # шаблон-ширина панели группы статов
const READABILITY_BASE_VIEWPORT := Vector2(1280.0, 720.0)
const READABILITY_MAX_SCALE := 1.18
const READABLE_BASE_ROW_HEIGHT := 44.0
const READABLE_BASE_ICON_SIZE := 30.0
const READABLE_CHIP_HEIGHT := 54.0
const READABLE_CHIP_WIDTH := 236.0
const READABLE_CHIP_ICON_SIZE := 32.0
const READABLE_GROUP_WIDTH := 520.0


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


func _build_layout() -> void:
	var overlay := ColorRect.new()
	overlay.name = "PauseStatsDim"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.015, 0.025, 0.74)
	add_child(overlay)

	var root := Control.new()
	root.name = "PauseStatsMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "EscapeStatsPanelFrame"
	var panel_size := get_viewport_rect().size - Vector2(40.0, 36.0)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20.0
	panel.offset_top = 18.0
	panel.offset_right = -20.0
	panel.offset_bottom = -18.0
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _pause_end_modal_style(panel_size))
	root.add_child(panel)

	var safe_scroll := ScrollContainer.new()
	safe_scroll.name = "PauseStatsSafeScroll"
	safe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe_scroll.follow_focus = true
	panel.add_child(safe_scroll)

	var layout := HBoxContainer.new()
	layout.name = "EscapeStatsLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", _readable_px(18.0))
	safe_scroll.add_child(layout)

	var left_column := VBoxContainer.new()
	left_column.name = "RunControls"
	left_column.custom_minimum_size = Vector2(320 if get_viewport_rect().size.x < 1500.0 else 360, 0)
	left_column.add_theme_constant_override("separation", _readable_px(10.0))
	layout.add_child(left_column)

	_build_left_controls(left_column)
	_build_dossier_header(left_column)
	_build_base_stats_block(left_column)

	var right_column := VBoxContainer.new()
	right_column.name = "DerivedStatsPanel"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", _readable_px(12.0))
	layout.add_child(right_column)

	var header := HBoxContainer.new()
	header.name = "DerivedStatsHeader"
	header.add_theme_constant_override("separation", 10)
	right_column.add_child(header)

	var stats_title := Label.new()
	stats_title.text = "Боевые параметры"
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_title.add_theme_font_size_override("font_size", _readable_px(30.0))
	stats_title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	header.add_child(stats_title)

	var stats_hint := Label.new()
	stats_hint.text = "Наведи на параметр для деталей"
	stats_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_hint.add_theme_font_size_override("font_size", _readable_px(15.0))
	stats_hint.add_theme_color_override("font_color", Color(0.62, 0.70, 0.78, 1.0))
	header.add_child(stats_hint)

	var scroll := ScrollContainer.new()
	scroll.name = "DerivedStatsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(scroll)

	_derived_groups_container = GridContainer.new()
	_derived_groups_container.name = "DerivedStatsGroups"
	_derived_groups_container.columns = 1 if get_viewport_rect().size.x < 1800.0 else 2
	_derived_groups_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_derived_groups_container.add_theme_constant_override("h_separation", _readable_px(12.0))
	_derived_groups_container.add_theme_constant_override("v_separation", _readable_px(12.0))
	scroll.add_child(_derived_groups_container)


func _build_dossier_header(left_column: VBoxContainer) -> void:
	left_column.add_child(_make_section_divider())
	_dossier_container = HBoxContainer.new()
	_dossier_container.name = "PauseCharacterDossier"
	_dossier_container.add_theme_constant_override("separation", 10)
	left_column.add_child(_dossier_container)


func _refresh_dossier() -> void:
	if _dossier_container == null:
		return
	for child in _dossier_container.get_children():
		child.queue_free()
	if _player == null or not is_instance_valid(_player):
		return
	var character_id := str(_player.get("character_id"))
	var weapon_id := str(_player.get("weapon_id"))
	var config: Dictionary = ProgressionData.character_config(character_id)
	var weapon: Dictionary = ProgressionData.weapon(character_id, weapon_id)
	var portrait := TextureRect.new()
	portrait.name = "PauseDossierPortrait"
	portrait.custom_minimum_size = Vector2(58, 58)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sprite_path := str(config.get("sprite_path", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	_dossier_container.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	_dossier_container.add_child(text_box)

	var title := Label.new()
	title.name = "PauseDossierTitle"
	title.text = str(config.get("title", "Герой"))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", _readable_px(19.0))
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40, 1.0))
	text_box.add_child(title)

	var details := Label.new()
	details.name = "PauseDossierDetails"
	details.text = "%s  |  Уровень %d  |  XP %d/%d" % [
		str(weapon.get("title", "Оружие")),
		int(_player.get("level")),
		int(_player.get("xp")),
		int(_player.get("xp_to_next")),
	]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", _readable_px(14.0))
	details.add_theme_color_override("font_color", TEXT_SECONDARY)
	text_box.add_child(details)

	var asc := Label.new()
	asc.name = "PauseDossierAscension"
	asc.text = "Возвышение %d" % int(_player.get_parent().get("selected_ascension_level") if _player.get_parent() != null and _player.get_parent().get("selected_ascension_level") != null else 0)
	asc.add_theme_font_size_override("font_size", _readable_px(13.0))
	asc.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 1.0))
	text_box.add_child(asc)


func _build_left_controls(left_column: VBoxContainer) -> void:
	var title := Label.new()
	title.name = "PauseStatsTitle"
	title.text = "Пауза"
	title.add_theme_font_size_override("font_size", _readable_px(38.0))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	left_column.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "PauseStatsSubtitle"
	subtitle.text = "Управление забегом и текущий билд"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", _readable_px(16.0))
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84, 1.0))
	left_column.add_child(subtitle)

	var button_box := VBoxContainer.new()
	button_box.name = "PauseControlButtons"
	button_box.add_theme_constant_override("separation", _readable_px(8.0))
	left_column.add_child(button_box)

	# SCRUM-580: 4 кнопки управления досье-паузы переодеты в выделенный pd_btn @2K-фрейм.
	var resume_button := _make_button("Продолжить")
	resume_button.name = "PauseResumeButton"
	_apply_pd_2k_button_theme(resume_button)
	resume_button.pressed.connect(func() -> void:
		resume_requested.emit()
	)
	button_box.add_child(resume_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "PauseSettingsButton"
	_apply_pd_2k_button_theme(settings_button)
	settings_button.pressed.connect(func() -> void:
		settings_requested.emit()
	)
	button_box.add_child(settings_button)

	var end_run_button := _make_button("Завершить забег")
	end_run_button.name = "PauseEndRunButton"
	_apply_pd_2k_button_theme(end_run_button, "danger")
	end_run_button.pressed.connect(_show_end_run_confirm)
	button_box.add_child(end_run_button)

	var menu_button := _make_button("Выйти в главное меню")
	menu_button.name = "PauseMainMenuButton"
	_apply_pd_2k_button_theme(menu_button)
	menu_button.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	button_box.add_child(menu_button)

	# SCRUM-812: досье-пауза проходима с геймпада/стрелок — кнопки фокусируемы (VBox
	# ведёт фокус вверх/вниз по геометрии), стартовый фокус — «Продолжить». B/Esc
	# (назад в паузу/продолжить) обрабатывается централизованно в main._input.
	for b in [resume_button, settings_button, end_run_button, menu_button]:
		b.focus_mode = Control.FOCUS_ALL
	resume_button.call_deferred("grab_focus")


func _build_base_stats_block(left_column: VBoxContainer) -> void:
	left_column.add_child(_make_section_divider())

	var section_title := Label.new()
	section_title.name = "BaseStatsTitle"
	section_title.text = "Базовые характеристики"
	section_title.add_theme_font_size_override("font_size", _readable_px(22.0))
	section_title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	left_column.add_child(section_title)

	_base_stats_container = VBoxContainer.new()
	_base_stats_container.name = "BaseStatsList"
	_base_stats_container.add_theme_constant_override("separation", _readable_px(5.0))
	left_column.add_child(_base_stats_container)

	_build_artifacts_block(left_column)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(fill)

	var hint := Label.new()
	hint.name = "PauseStatsHint"
	hint.text = "Esc закрывает меню."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", _readable_px(14.0))
	hint.add_theme_color_override("font_color", Color(0.58, 0.65, 0.72, 1.0))
	left_column.add_child(hint)


func _build_artifacts_block(left_column: VBoxContainer) -> void:
	left_column.add_child(_make_section_divider())

	var section_title := Label.new()
	section_title.name = "ArtifactsTitle"
	section_title.text = "Артефакты"
	section_title.add_theme_font_size_override("font_size", _readable_px(21.0))
	section_title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	left_column.add_child(section_title)

	_artifacts_container = HFlowContainer.new()
	_artifacts_container.name = "ArtifactsList"
	_artifacts_container.add_theme_constant_override("h_separation", 6)
	_artifacts_container.add_theme_constant_override("v_separation", 6)
	left_column.add_child(_artifacts_container)


func _refresh_artifacts() -> void:
	if _artifacts_container == null or _player == null or not is_instance_valid(_player):
		return
	for child in _artifacts_container.get_children():
		child.queue_free()
	var artifacts: Array = _player.get("artifacts") if _player.get("artifacts") != null else []
	if artifacts.is_empty():
		var empty_label := Label.new()
		empty_label.name = "ArtifactsEmptyLabel"
		empty_label.text = "Пока не найдено"
		empty_label.add_theme_font_size_override("font_size", _readable_px(15.0))
		empty_label.add_theme_color_override("font_color", Color(0.58, 0.65, 0.72, 1.0))
		_artifacts_container.add_child(empty_label)
		return
	for entry in artifacts:
		var artifact: Dictionary = entry if entry is Dictionary else {"id": "", "title": str(entry)}
		var artifact_id := str(artifact.get("id", ""))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path := "res://assets/sprites/ui/icons/artifacts/artifact_%s.png" % artifact_id
		if artifact_id != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
		else:
			icon.texture = UIIconRegistry.texture_for("buff_power")
		var definition: Dictionary = ProgressionData.artifact_definition(artifact_id)
		var description := str(definition.get("description", ""))
		var title := str(artifact.get("title", ""))
		var tier_text := "Тир %d" % int(definition.get("tier", 1))
		icon.tooltip_text = title if description == "" else "%s (%s)\n%s" % [title, tier_text, description]
		var pause_affinity: Array = definition.get("class_affinity", [])
		if not pause_affinity.is_empty() and _player != null and not pause_affinity.has(str(_player.get("character_id"))):
			var interpreted_parameter := ""
			for key in (definition.get("affinity_mods", {}) as Dictionary).keys():
				interpreted_parameter = str(key)
				break
			if interpreted_parameter == "":
				interpreted_parameter = "summon_amount"
			icon.tooltip_text += "\n[Интерпретация: %s]" % ProgressionData.class_interpretation_text(str(_player.get("character_id")), interpreted_parameter)
			icon.modulate = Color(0.78, 0.95, 1.0, 1.0)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		_artifacts_container.add_child(icon)


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


func _make_basic_stat_row(entry: Dictionary) -> Control:
	var stat_id := str(entry.get("id", ""))
	var character_id := str(_player.get("character_id")) if _player != null and is_instance_valid(_player) else ""
	var is_priority := ProgressionData.attribute_priorities(character_id).has(stat_id)
	var row := PanelContainer.new()
	row.name = "BaseStatRow_%s" % stat_id
	row.custom_minimum_size = Vector2(0, _readable_px(READABLE_BASE_ROW_HEIGHT))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = _tooltip_for_entry(entry)
	if is_priority:
		row.tooltip_text += "\n\n%s" % ProgressionData.attribute_priority_reason(character_id, stat_id)
	row.add_theme_stylebox_override("panel", _basic_stat_row_style(false, is_priority))
	row.mouse_entered.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _basic_stat_row_style(true, is_priority))
	)
	row.mouse_exited.connect(func() -> void:
		row.add_theme_stylebox_override("panel", _basic_stat_row_style(false, is_priority))
	)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", _readable_px(9.0))
	row.add_child(line)

	var icon_size := _readable_px(READABLE_BASE_ICON_SIZE)
	var icon := UIIconRegistry.make_icon(str(entry.get("id", "")), Vector2(icon_size, icon_size))
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
	name_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 1.0))
	line.add_child(name_label)

	if is_priority:
		var badge := Label.new()
		badge.name = "PriorityBadge_%s" % stat_id
		badge.text = "★"
		badge.tooltip_text = ProgressionData.attribute_priority_reason(character_id, stat_id)
		badge.add_theme_font_size_override("font_size", _readable_px(17.0))
		badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
		line.add_child(badge)

	var value_label := Label.new()
	value_label.name = "BaseStatValue_%s" % str(entry.get("id", ""))
	value_label.text = _compact_value_text(entry)
	value_label.custom_minimum_size = Vector2(_readable_px(58.0), 0)
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", _readable_px(18.0))
	value_label.add_theme_color_override("font_color", _value_color(entry))
	line.add_child(value_label)
	return row


func _make_derived_group(group: Dictionary, entries_by_id: Dictionary) -> Control:
	var group_panel := PanelContainer.new()
	group_panel.name = "DerivedStatGroup_%s" % str(group.get("id", ""))
	group_panel.custom_minimum_size = Vector2(_readable_px(READABLE_GROUP_WIDTH), 0)
	group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_panel.add_theme_stylebox_override("panel", _group_style(group.get("accent", Color(0.95, 0.78, 0.32, 1.0))))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _readable_px(9.0))
	group_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", _readable_px(9.0))
	box.add_child(header)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(_readable_px(5.0), _readable_px(30.0))
	accent.color = group.get("accent", Color(0.95, 0.78, 0.32, 1.0))
	header.add_child(accent)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)

	var title := Label.new()
	title.text = str(group.get("title", "Группа"))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", _readable_px(20.0))
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	title_box.add_child(title)

	var description := Label.new()
	description.text = str(group.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", _readable_px(13.0))
	description.add_theme_color_override("font_color", Color(0.62, 0.70, 0.78, 1.0))
	title_box.add_child(description)

	var chips := GridContainer.new()
	chips.name = "DerivedStatChips_%s" % str(group.get("id", ""))
	chips.columns = 2
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", _readable_px(8.0))
	chips.add_theme_constant_override("v_separation", _readable_px(8.0))
	box.add_child(chips)

	for stat_id in group.get("stats", []):
		if entries_by_id.has(str(stat_id)):
			chips.add_child(_make_stat_chip(entries_by_id[str(stat_id)]))
	return group_panel


func _make_stat_chip(entry: Dictionary) -> Control:
	var chip := PanelContainer.new()
	chip.name = "DerivedStatChip_%s" % str(entry.get("id", ""))
	chip.custom_minimum_size = Vector2(_readable_px(READABLE_CHIP_WIDTH), _readable_px(READABLE_CHIP_HEIGHT))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.tooltip_text = _tooltip_for_entry(entry)
	chip.add_theme_stylebox_override("panel", _chip_style(false))
	chip.mouse_entered.connect(func() -> void:
		chip.add_theme_stylebox_override("panel", _chip_style(true))
	)
	chip.mouse_exited.connect(func() -> void:
		chip.add_theme_stylebox_override("panel", _chip_style(false))
	)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", _readable_px(8.0))
	chip.add_child(line)

	var icon_size := _readable_px(READABLE_CHIP_ICON_SIZE)
	line.add_child(UIIconRegistry.make_icon(str(entry.get("id", "")), Vector2(icon_size, icon_size)))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	line.add_child(text_box)

	var name_label := Label.new()
	name_label.name = "DerivedStatName_%s" % str(entry.get("id", ""))
	name_label.text = str(entry.get("name_ru", ""))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", _readable_px(15.0))
	name_label.add_theme_color_override("font_color", Color(0.86, 0.91, 0.96, 1.0))
	text_box.add_child(name_label)

	var value_label := Label.new()
	value_label.name = "DerivedStatValue_%s" % str(entry.get("id", ""))
	value_label.text = _compact_value_text(entry)
	value_label.clip_text = true
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.add_theme_font_size_override("font_size", _readable_px(17.0))
	value_label.add_theme_color_override("font_color", _value_color(entry))
	text_box.add_child(value_label)
	return chip


func _compact_value_text(entry: Dictionary) -> String:
	return str(entry.get("value_text", "N/A")).replace(" / sec", "/s").replace(" units", "")


func _show_end_run_confirm() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = "Завершить забег?"
	dialog.dialog_text = "Завершить текущий забег?"
	dialog.confirmed.connect(func() -> void:
		end_run_confirmed.emit()
	)
	add_child(dialog)
	_apply_fantasy_button_theme(dialog.get_ok_button(), "danger")
	_apply_fantasy_button_theme(dialog.get_cancel_button())
	dialog.popup_centered(Vector2i(360, 140))


# SCRUM-593/SCRUM-851: тултип статов — движковый попап с рамкой stat_tooltip из темы
# ("TooltipPanel" override в _ready), внутри голый Label: ширина/перенос считаются
# GlobalTooltip.make_tooltip_label, позицию и кламп в экран даёт сам Godot.
func _make_custom_tooltip(for_text: String) -> Object:
	return GlobalTooltip.make_tooltip_label(
		for_text,
		"StatTooltipLabel",
		GlobalTooltip.DEFAULT_FONT_SIZE,
		TEXT_PRIMARY
	)


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


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 60)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_fantasy_button_theme(button)
	button.add_theme_font_size_override("font_size", 16)
	return button


func _apply_fantasy_button_theme(button: Button, variant := "default") -> void:
	var normal_tint := Color.WHITE
	var pressed_tint := Color(0.92, 0.88, 0.82, 1.0)
	if variant == "danger":
		normal_tint = Color(1.08, 0.72, 0.72, 1.0)
		pressed_tint = Color(0.92, 0.55, 0.55, 1.0)
	button.add_theme_stylebox_override("normal", _button_style(PAUSE_BUTTON_NORMAL, normal_tint))
	button.add_theme_stylebox_override("hover", _button_style(PAUSE_BUTTON_HOVER, BUTTON_NEUTRAL_HOVER_TINT))
	button.add_theme_stylebox_override("pressed", _button_style(PAUSE_BUTTON_PRESSED, pressed_tint))
	button.add_theme_stylebox_override("disabled", _button_style(PAUSE_BUTTON_DISABLED, Color(0.72, 0.72, 0.72, 1.0)))
	button.add_theme_stylebox_override("focus", _button_style(PAUSE_BUTTON_FOCUS, BUTTON_NEUTRAL_FOCUS_TINT))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_focus_color", BUTTON_NEUTRAL_HOVER_FONT)
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


# SCRUM-669: pause-dossier text actions use the generated SCRUM-657 exact-size
# pause_280x60 state kit. The helper remains for call-site compatibility.
func _apply_pd_2k_button_theme(button: Button, variant := "default") -> void:
	_apply_fantasy_button_theme(button, variant)


func _panel_style() -> StyleBox:
	return _texture_style(ESCAPE_PANEL_FRAME, 38, 52, 38, 48, Color.WHITE, Vector4(58, 72, 58, 66))


# SCRUM-486: панель паузы-досье на @2K-ассете pd_panel (нарисован ровно 2520×1404 c
# modal-маргинами). Бордюры скейлятся от source 2520×1404 → на 2K display==source (1:1),
# на 1080p/4K — uniform-скейл вьюпорта. Ассет несёт свой орнамент, центр тянется 9-slice.
const PD_PANEL_SOURCE_SIZE := Vector2(2520.0, 1404.0)
const PD_PANEL_TEXTURE_MARGINS := Vector4(46.0, 62.0, 46.0, 58.0)
const PD_PANEL_CONTENT := Vector4(72.0, 92.0, 72.0, 84.0)

func _pause_end_modal_style(display_size: Vector2) -> StyleBox:
	var texture_margins := _scaled_frame_margins(PD_PANEL_SOURCE_SIZE, display_size, PD_PANEL_TEXTURE_MARGINS)
	var content_margins := _scaled_frame_margins(PD_PANEL_SOURCE_SIZE, display_size, PD_PANEL_CONTENT)
	return _texture_style(
		ESCAPE_PANEL_FRAME_2K,
		texture_margins.x,
		texture_margins.y,
		texture_margins.z,
		texture_margins.w,
		Color.WHITE,
		content_margins
	)


func _scaled_frame_margins(source_size: Vector2, display_size: Vector2, source_margins: Vector4) -> Vector4:
	var scale := minf(display_size.x / source_size.x, display_size.y / source_size.y)
	return Vector4(
		roundf(source_margins.x * scale),
		roundf(source_margins.y * scale),
		roundf(source_margins.z * scale),
		roundf(source_margins.w * scale)
	)


func _basic_stat_row_style(is_hovered: bool, is_priority := false) -> StyleBox:
	var tint := Color(1.10, 1.10, 1.10, 1.0) if is_hovered else Color.WHITE
	if is_priority:
		tint = Color(1.18, 1.08, 0.72, 1.0) if is_hovered else Color(1.10, 1.02, 0.74, 1.0)
	return _texture_style(STAT_BASIC_ROW_FRAME, 42, 38, 42, 36, tint, Vector4(58, 52, 58, 48))


func _group_style(accent: Color) -> StyleBox:
	var tint := Color(
		lerpf(1.0, accent.r, 0.12),
		lerpf(1.0, accent.g, 0.12),
		lerpf(1.0, accent.b, 0.12),
		1.0
	)
	return _texture_style(STAT_GROUP_FRAME, 38, 52, 38, 48, tint, Vector4(58, 72, 58, 66))


func _chip_style(is_hovered: bool) -> StyleBox:
	var tint := Color(1.12, 1.12, 1.12, 1.0) if is_hovered else Color.WHITE
	return _texture_style(STAT_CHIP_FRAME, 42, 38, 42, 36, tint, Vector4(58, 52, 58, 48))


func _tooltip_style() -> StyleBox:
	# SCRUM-593: SCRUM-586 tooltip frame (430x288) has stricter safe content than old st_panel.
	var margins: Vector4 = UIThemePaths.OVERHAUL_2K_FRAME_TEXTURE_MARGINS["stat_tooltip"]
	var content: Vector4 = UIThemePaths.OVERHAUL_2K_FRAME_CONTENT["stat_tooltip"]
	return _texture_style(STAT_TOOLTIP_FRAME_2K, margins.x, margins.y, margins.z, margins.w, Color.WHITE, content)


func _make_section_divider() -> TextureRect:
	var divider := TextureRect.new()
	divider.name = "StatSectionDivider"
	divider.custom_minimum_size = Vector2(0.0, 10.0)
	divider.texture = STAT_SECTION_DIVIDER
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	return divider


func _button_style(texture: Texture2D, tint: Color) -> StyleBox:
	var style := _texture_style(
		texture,
		PAUSE_BUTTON_TEXTURE_MARGINS.x,
		PAUSE_BUTTON_TEXTURE_MARGINS.y,
		PAUSE_BUTTON_TEXTURE_MARGINS.z,
		PAUSE_BUTTON_TEXTURE_MARGINS.w,
		tint,
		PAUSE_BUTTON_CONTENT_MARGINS
	)
	if style is StyleBoxTexture:
		(style as StyleBoxTexture).modulate_color.a = 1.0
	return style


func _texture_style(texture: Texture2D, left: float, top: float, right: float, bottom: float, tint: Color, content := Vector4.ZERO) -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin(SIDE_LEFT, left)
	style.set_texture_margin(SIDE_TOP, top)
	style.set_texture_margin(SIDE_RIGHT, right)
	style.set_texture_margin(SIDE_BOTTOM, bottom)
	style.modulate_color = tint
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style
