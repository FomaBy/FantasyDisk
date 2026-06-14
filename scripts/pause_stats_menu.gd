extends Control

signal resume_requested
signal settings_requested
signal end_run_confirmed
signal main_menu_requested

const StatFormulas := preload("res://scripts/stat_formulas.gd")
const UIIconRegistry := preload("res://scripts/ui_icon_registry.gd")
const ESCAPE_PANEL_FRAME := preload("res://assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_main.png")
const STAT_BASIC_ROW_FRAME := preload("res://assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_chip.png")
const STAT_GROUP_FRAME := preload("res://assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_group.png")
const STAT_CHIP_FRAME := preload("res://assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_chip.png")
const STAT_TOOLTIP_FRAME := preload("res://assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_tooltip.png")
const STAT_SECTION_DIVIDER := preload("res://assets/sprites/ui/frames/escape/ui_stat_section_divider.png")
const PAUSE_BUTTON_NORMAL := preload("res://assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause.png")
const PAUSE_BUTTON_HOVER := preload("res://assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause_hover.png")
const PAUSE_BUTTON_PRESSED := preload("res://assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause_pressed.png")
const PAUSE_BUTTON_DISABLED := preload("res://assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause_disabled.png")

const VALUE_HIGH := Color(0.439, 0.949, 0.651, 1.0)
const VALUE_LOW := Color(1.0, 0.420, 0.420, 1.0)
const VALUE_NEUTRAL := Color(0.914, 0.863, 0.655, 1.0)
const VALUE_EFFECTIVE := Color(1.0, 0.863, 0.361, 1.0)
const TEXT_PRIMARY := Color(0.937, 0.886, 0.698, 1.0)
const TEXT_SECONDARY := Color(0.592, 0.647, 0.722, 1.0)
const TOOLTIP_MAX_WIDTH := 430.0

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
	_build_layout()


func setup(player: Node) -> void:
	_player = player
	_refresh_dossier()
	_refresh_stats()
	_refresh_artifacts()


func _build_layout() -> void:
	var overlay := ColorRect.new()
	overlay.name = "PauseStatsDim"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.015, 0.025, 0.74)
	add_child(overlay)

	var root := MarginContainer.new()
	root.name = "PauseStatsMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 30)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_right", 30)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "EscapeStatsPanelFrame"
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var layout := HBoxContainer.new()
	layout.name = "EscapeStatsLayout"
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)

	var left_column := VBoxContainer.new()
	left_column.name = "RunControls"
	left_column.custom_minimum_size = Vector2(330, 0)
	left_column.add_theme_constant_override("separation", 10)
	layout.add_child(left_column)

	_build_left_controls(left_column)
	_build_dossier_header(left_column)
	_build_base_stats_block(left_column)

	var right_column := VBoxContainer.new()
	right_column.name = "DerivedStatsPanel"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 12)
	layout.add_child(right_column)

	var header := HBoxContainer.new()
	header.name = "DerivedStatsHeader"
	header.add_theme_constant_override("separation", 10)
	right_column.add_child(header)

	var stats_title := Label.new()
	stats_title.text = "Боевые параметры"
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_title.add_theme_font_size_override("font_size", 30)
	stats_title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	header.add_child(stats_title)

	var stats_hint := Label.new()
	stats_hint.text = "Наведи на параметр для деталей"
	stats_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_hint.add_theme_font_size_override("font_size", 15)
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
	_derived_groups_container.columns = 2
	_derived_groups_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_derived_groups_container.add_theme_constant_override("h_separation", 12)
	_derived_groups_container.add_theme_constant_override("v_separation", 12)
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
	title.add_theme_font_size_override("font_size", 18)
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
	details.add_theme_font_size_override("font_size", 13)
	details.add_theme_color_override("font_color", TEXT_SECONDARY)
	text_box.add_child(details)

	var asc := Label.new()
	asc.name = "PauseDossierAscension"
	asc.text = "Возвышение %d" % int(_player.get_parent().get("selected_ascension_level") if _player.get_parent() != null and _player.get_parent().get("selected_ascension_level") != null else 0)
	asc.add_theme_font_size_override("font_size", 12)
	asc.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 1.0))
	text_box.add_child(asc)


func _build_left_controls(left_column: VBoxContainer) -> void:
	var title := Label.new()
	title.name = "PauseStatsTitle"
	title.text = "Пауза"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	left_column.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "PauseStatsSubtitle"
	subtitle.text = "Управление забегом и текущий билд"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84, 1.0))
	left_column.add_child(subtitle)

	var button_box := VBoxContainer.new()
	button_box.name = "PauseControlButtons"
	button_box.add_theme_constant_override("separation", 8)
	left_column.add_child(button_box)

	var resume_button := _make_button("Продолжить")
	resume_button.name = "PauseResumeButton"
	resume_button.pressed.connect(func() -> void:
		resume_requested.emit()
	)
	button_box.add_child(resume_button)

	var settings_button := _make_button("Настройки")
	settings_button.name = "PauseSettingsButton"
	settings_button.pressed.connect(func() -> void:
		settings_requested.emit()
	)
	button_box.add_child(settings_button)

	var end_run_button := _make_button("Завершить забег")
	end_run_button.name = "PauseEndRunButton"
	_apply_fantasy_button_theme(end_run_button, "danger")
	end_run_button.pressed.connect(_show_end_run_confirm)
	button_box.add_child(end_run_button)

	var menu_button := _make_button("Выйти в главное меню")
	menu_button.name = "PauseMainMenuButton"
	menu_button.pressed.connect(func() -> void:
		main_menu_requested.emit()
	)
	button_box.add_child(menu_button)


func _build_base_stats_block(left_column: VBoxContainer) -> void:
	left_column.add_child(_make_section_divider())

	var section_title := Label.new()
	section_title.name = "BaseStatsTitle"
	section_title.text = "Базовые характеристики"
	section_title.add_theme_font_size_override("font_size", 19)
	section_title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	left_column.add_child(section_title)

	_base_stats_container = VBoxContainer.new()
	_base_stats_container.name = "BaseStatsList"
	_base_stats_container.add_theme_constant_override("separation", 4)
	left_column.add_child(_base_stats_container)

	_build_artifacts_block(left_column)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(fill)

	var hint := Label.new()
	hint.name = "PauseStatsHint"
	hint.text = "Esc закрывает меню."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.58, 0.65, 0.72, 1.0))
	left_column.add_child(hint)


func _build_artifacts_block(left_column: VBoxContainer) -> void:
	left_column.add_child(_make_section_divider())

	var section_title := Label.new()
	section_title.name = "ArtifactsTitle"
	section_title.text = "Артефакты"
	section_title.add_theme_font_size_override("font_size", 19)
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
		empty_label.add_theme_font_size_override("font_size", 14)
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
	row.custom_minimum_size = Vector2(0, 36)
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
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)

	var icon := UIIconRegistry.make_icon(str(entry.get("id", "")), Vector2(28, 28))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)

	var name_label := Label.new()
	name_label.name = "BaseStatName_%s" % stat_id
	name_label.text = str(entry.get("name_ru", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 1.0))
	line.add_child(name_label)

	if is_priority:
		var badge := Label.new()
		badge.name = "PriorityBadge_%s" % stat_id
		badge.text = "★"
		badge.tooltip_text = ProgressionData.attribute_priority_reason(character_id, stat_id)
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
		line.add_child(badge)

	var value_label := Label.new()
	value_label.name = "BaseStatValue_%s" % str(entry.get("id", ""))
	value_label.text = _compact_value_text(entry)
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", _value_color(entry))
	line.add_child(value_label)
	return row


func _make_derived_group(group: Dictionary, entries_by_id: Dictionary) -> Control:
	var group_panel := PanelContainer.new()
	group_panel.name = "DerivedStatGroup_%s" % str(group.get("id", ""))
	group_panel.custom_minimum_size = Vector2(430, 0)
	group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_panel.add_theme_stylebox_override("panel", _group_style(group.get("accent", Color(0.95, 0.78, 0.32, 1.0))))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	group_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(5, 26)
	accent.color = group.get("accent", Color(0.95, 0.78, 0.32, 1.0))
	header.add_child(accent)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)

	var title := Label.new()
	title.text = str(group.get("title", "Группа"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	title_box.add_child(title)

	var description := Label.new()
	description.text = str(group.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.62, 0.70, 0.78, 1.0))
	title_box.add_child(description)

	var chips := GridContainer.new()
	chips.name = "DerivedStatChips_%s" % str(group.get("id", ""))
	chips.columns = 2
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 7)
	box.add_child(chips)

	for stat_id in group.get("stats", []):
		if entries_by_id.has(str(stat_id)):
			chips.add_child(_make_stat_chip(entries_by_id[str(stat_id)]))
	return group_panel


func _make_stat_chip(entry: Dictionary) -> Control:
	var chip := PanelContainer.new()
	chip.name = "DerivedStatChip_%s" % str(entry.get("id", ""))
	chip.custom_minimum_size = Vector2(200, 44)
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
	line.add_theme_constant_override("separation", 7)
	chip.add_child(line)

	line.add_child(UIIconRegistry.make_icon(str(entry.get("id", "")), Vector2(30, 30)))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	line.add_child(text_box)

	var name_label := Label.new()
	name_label.text = str(entry.get("name_ru", ""))
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.86, 0.91, 0.96, 1.0))
	text_box.add_child(name_label)

	var value_label := Label.new()
	value_label.name = "DerivedStatValue_%s" % str(entry.get("id", ""))
	value_label.text = _compact_value_text(entry)
	value_label.clip_text = true
	value_label.add_theme_font_size_override("font_size", 15)
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


func _make_custom_tooltip(for_text: String) -> Object:
	var tooltip := PanelContainer.new()
	tooltip.name = "StatTooltipPanel"
	tooltip.custom_minimum_size = Vector2(TOOLTIP_MAX_WIDTH, 0.0)
	tooltip.add_theme_stylebox_override("panel", _tooltip_style())

	var label := Label.new()
	label.name = "StatTooltipLabel"
	label.custom_minimum_size = Vector2(TOOLTIP_MAX_WIDTH - 40.0, 0.0)
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	tooltip.add_child(label)
	return tooltip


func _tooltip_for_entry(entry: Dictionary) -> String:
	return "%s: %s\nЗначение: %s\n\n%s\n\nФормула: %s\nВлияет: %s" % [
		str(entry.get("name_ru", "")),
		str(entry.get("name_en", "")),
		str(entry.get("value_text", "N/A")),
		str(entry.get("description", "")),
		str(entry.get("formula", "Формула пока не подключена.")),
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
	var hover_tint := Color(1.08, 1.05, 0.86, 1.0)
	var pressed_tint := Color(0.92, 0.88, 0.82, 1.0)
	if variant == "danger":
		normal_tint = Color(1.08, 0.72, 0.72, 1.0)
		hover_tint = Color(1.18, 0.78, 0.68, 1.0)
		pressed_tint = Color(0.92, 0.55, 0.55, 1.0)
	button.add_theme_stylebox_override("normal", _button_style(PAUSE_BUTTON_NORMAL, normal_tint))
	button.add_theme_stylebox_override("hover", _button_style(PAUSE_BUTTON_HOVER, hover_tint))
	button.add_theme_stylebox_override("pressed", _button_style(PAUSE_BUTTON_PRESSED, pressed_tint))
	button.add_theme_stylebox_override("disabled", _button_style(PAUSE_BUTTON_DISABLED, Color(0.72, 0.72, 0.72, 1.0)))
	button.add_theme_stylebox_override("focus", _button_style(PAUSE_BUTTON_HOVER, hover_tint))
	button.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.45, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.86, 1.0, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54, 1.0))


func _panel_style() -> StyleBox:
	return _texture_style(ESCAPE_PANEL_FRAME, 40, 40, 40, 40, Color.WHITE, Vector4(24, 24, 24, 24))


func _basic_stat_row_style(is_hovered: bool, is_priority := false) -> StyleBox:
	var tint := Color(1.10, 1.10, 1.10, 1.0) if is_hovered else Color.WHITE
	if is_priority:
		tint = Color(1.18, 1.08, 0.72, 1.0) if is_hovered else Color(1.10, 1.02, 0.74, 1.0)
	return _texture_style(STAT_BASIC_ROW_FRAME, 20, 12, 20, 14, tint, Vector4(8, 4, 8, 4))


func _group_style(accent: Color) -> StyleBox:
	var tint := Color(
		lerpf(1.0, accent.r, 0.12),
		lerpf(1.0, accent.g, 0.12),
		lerpf(1.0, accent.b, 0.12),
		1.0
	)
	return _texture_style(STAT_GROUP_FRAME, 34, 30, 34, 34, tint, Vector4(14, 12, 14, 14))


func _chip_style(is_hovered: bool) -> StyleBox:
	var tint := Color(1.12, 1.12, 1.12, 1.0) if is_hovered else Color.WHITE
	return _texture_style(STAT_CHIP_FRAME, 20, 12, 20, 14, tint, Vector4(8, 6, 8, 6))


func _tooltip_style() -> StyleBox:
	return _texture_style(STAT_TOOLTIP_FRAME, 34, 30, 34, 34, Color.WHITE, Vector4(18, 16, 18, 16))


func _make_section_divider() -> TextureRect:
	var divider := TextureRect.new()
	divider.name = "StatSectionDivider"
	divider.custom_minimum_size = Vector2(0.0, 10.0)
	divider.texture = STAT_SECTION_DIVIDER
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	return divider


func _button_style(texture: Texture2D, tint: Color) -> StyleBox:
	var style := _texture_style(texture, 68, 20, 68, 20, tint, Vector4(56, 8, 56, 8))
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
	return style
