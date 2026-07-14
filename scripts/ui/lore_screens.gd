class_name LoreScreens
extends RefCounted

# FAN-1080: лор-UI, извлечённый из ui_screens.gd под static-quality ратчет
# (по образцу WeaponCrowdCaps/PauseDossierActionLayout). Тексты — только из
# scripts/lore_data.gd (канон: docs/design/lore.md). `ui` — инстанс ui_screens:
# модуль переиспользует его стили/кнопки/фокус-хелперы, чтобы лор-экраны
# оставались в едином FantasyDisk-ките.

const LORE_DATA := preload("res://scripts/lore_data.gd")
const CODEX_DATA := preload("res://scripts/codex_data.gd")
const CODEX_IMAGE_FIT := preload("res://scripts/ui/codex_image_fit.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")


# Вступление истории: 4 слайда перед первым забегом. Показ один раз
# (settings.cfg: lore_intro_seen), пропуск Esc/B/кнопкой; пересмотр — запись
# «Вступление» на вкладке «Летопись» Кодекса.
static func maybe_show_intro(ui, next_action: Callable) -> void:
	if ui.game.force_skip_lore_intro:
		next_action.call()
		return
	if bool(GAME_SETTINGS.load_settings().get("lore_intro_seen", false)):
		next_action.call()
	else:
		show_intro(ui, next_action)


static func show_intro(ui, on_finish: Callable, mark_seen := true) -> void:
	var game = ui.game
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "LoreIntroScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	ui._prepare_global_tooltips(root)
	ui._unified_add_background(root, "codex")

	var shade := ColorRect.new()
	shade.name = "LoreIntroShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.01, 0.03, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	# Панель-пергамент по центру: контент только в пустой зоне рамы (56/44 px
	# content margins поверх 46 px texture margins кодекс-панели).
	var panel := PanelContainer.new()
	panel.name = "LoreIntroPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var half_size := Vector2(920, 560) * 0.5
	panel.offset_left = -half_size.x
	panel.offset_top = -half_size.y
	panel.offset_right = half_size.x
	panel.offset_bottom = half_size.y
	panel.add_theme_stylebox_override("panel", ui._codex_panel_style(0.95, Vector4(56, 44, 56, 44)))
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "LoreIntroColumn"
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var caption := Label.new()
	caption.name = "LoreIntroCaption"
	caption.text = "ЛЕТОПИСЬ ДИСКА"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", ui._readable_font_size(SemanticTypography.ROLE_CAPTION, 16))
	caption.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	column.add_child(caption)

	var title_label := Label.new()
	title_label.name = "LoreIntroTitle"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", ui._readable_font_size(SemanticTypography.ROLE_TITLE, 34))
	title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	column.add_child(title_label)

	var body_label := Label.new()
	body_label.name = "LoreIntroBody"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", ui._readable_font_size(SemanticTypography.ROLE_BODY, 21))
	body_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.97, 0.97))
	column.add_child(body_label)

	var progress := Label.new()
	progress.name = "LoreIntroProgress"
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", ui._readable_font_size(SemanticTypography.ROLE_CAPTION, 15))
	progress.add_theme_color_override("font_color", Color(0.72, 0.70, 0.62, 0.92))
	column.add_child(progress)

	var button_row := HBoxContainer.new()
	button_row.name = "LoreIntroButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 24)
	column.add_child(button_row)

	var skip_button: Button = ui._make_button("Пропустить")
	skip_button.name = "LoreIntroSkipButton"
	ui._set_action_button_size(skip_button, 240.0, 64.0)
	button_row.add_child(skip_button)

	var next_button: Button = ui._make_button("Далее")
	next_button.name = "LoreIntroNextButton"
	ui._set_action_button_size(next_button, 280.0, 64.0)
	button_row.add_child(next_button)

	var slides: Array = LORE_DATA.intro_slides()
	panel.set_meta("lore_slide_index", 0)

	var finish := func() -> void:
		if mark_seen:
			var saved: Dictionary = GAME_SETTINGS.load_settings()
			saved["lore_intro_seen"] = true
			GAME_SETTINGS.save_settings(saved)
		on_finish.call()

	var render_slide := func() -> void:
		var index := clampi(int(panel.get_meta("lore_slide_index", 0)), 0, slides.size() - 1)
		var slide: Dictionary = slides[index]
		title_label.text = str(slide.get("title", ""))
		body_label.text = str(slide.get("body", ""))
		progress.text = "%d / %d" % [index + 1, slides.size()]
		next_button.text = "В путь" if index == slides.size() - 1 else "Далее"

	var advance := func() -> void:
		var index := int(panel.get_meta("lore_slide_index", 0))
		if index >= slides.size() - 1:
			finish.call()
			return
		panel.set_meta("lore_slide_index", index + 1)
		render_slide.call()

	next_button.pressed.connect(advance)
	skip_button.pressed.connect(finish)
	ui._connect_ui_sfx(next_button, "click")
	ui._connect_ui_sfx(skip_button, "back")
	game.ui_escape_action = finish
	render_slide.call()

	# SCRUM-813-совместимость: стартовый фокус на «Далее», B/Esc — пропуск.
	ui._wire_run_ui_focus([skip_button, next_button], true, [], next_button)


# Вкладка «Летопись» Кодекса. Записи статичны и всегда открыты; исключение —
# спойлер-строка про Исток в «Владыках Разлома»: только после победы над
# secret_ascension_boss (его нет в канонических Кодекс-id, поэтому гейт идёт
# по мета-флагу secret_boss_defeated, а не по codex-discovery).
static func build_chronicle(ui, list: VBoxContainer) -> void:
	for entry in LORE_DATA.chronicle_entries():
		var entry_id := str(entry.get("id", ""))
		var icon_path := str(entry.get("icon", ""))
		var texture: Texture2D = null
		if icon_path != "" and ResourceLoader.exists(icon_path):
			texture = ui.game._cached_texture(icon_path)
		var image_policy: String = CODEX_IMAGE_FIT.POLICY_CONTAIN
		if entry_id == "chronicle_keepers":
			image_policy = CODEX_IMAGE_FIT.POLICY_CHARACTER
		elif entry_id == "chronicle_lords":
			image_policy = CODEX_IMAGE_FIT.POLICY_MONSTER
		var body_lines := []
		for line in entry.get("lines", []):
			body_lines.append(str(line))
		var row: HBoxContainer = ui._codex_entry_panel(list, {
			"title": str(entry.get("title", "")),
			"summary": str(entry.get("summary", "")),
			"texture": texture,
			"texture_path": icon_path,
			"image_policy": image_policy,
			"covered_portrait": false,
			"chips": entry.get("chips", ["Летопись"]),
			"body_lines": body_lines,
			"sections": chronicle_sections(ui, entry),
		})
		ui._codex_icon_slot(row, texture, ui._codex_entry_portrait_size(), "CodexChronicleIconSlot", image_policy, icon_path)
		ui._codex_add_entry_name(row, str(entry.get("title", "")))


static func chronicle_sections(ui, entry: Dictionary) -> Array:
	var sections := []
	# «Вступление»: те же 4 слайда, что и интро-экран новой игры (пересмотр).
	if str(entry.get("sections", "")) == "intro_slides":
		var slide_lines := []
		for slide in LORE_DATA.intro_slides():
			slide_lines.append({"title": str(slide.get("title", "")), "text": str(slide.get("body", ""))})
		sections.append({"heading": "Как всё началось", "lines": slide_lines})
		return sections
	var lines := []
	for line in entry.get("lines", []):
		if str(line) != "":
			lines.append(str(line))
	if not lines.is_empty():
		sections.append({"heading": "Летопись Диска", "lines": lines})
	# «Владыки Разлома»: по строке гибели на каждого Владыку из Кодекса.
	if bool(entry.get("lords", false)):
		var lord_lines := []
		for monster in CODEX_DATA.monsters():
			if str(monster.get("kind", "")) != "boss":
				continue
			var doom := LORE_DATA.boss_doom_line(str(monster.get("id", "")))
			if doom != "":
				lord_lines.append({"title": str(monster.get("title", "")), "text": doom})
		if ui.game.META_PROGRESSION.secret_boss_defeated(ui.game.meta_state):
			lord_lines.append({"title": "Исток", "text": LORE_DATA.SECRET_LORD_LINE})
		if not lord_lines.is_empty():
			sections.append({"heading": "Вахта у кромки", "lines": lord_lines})
	return sections


# Лор-строка под боевым титул-баннером босса/элитки: без рамки, только текст
# с сильным outline (не спорит с рамой баннера и орнаментом). Живёт дольше
# титула, чтобы подводку успели прочитать.
static func show_banner_lore_line(ui, lore_line: String, ctb_spec: Rect2, ctb_half_width: float, big: bool) -> void:
	if lore_line == "":
		return
	var game = ui.game
	var lore_label := Label.new()
	lore_label.name = "CombatIntroLoreLine"
	lore_label.text = lore_line
	lore_label.process_mode = Node.PROCESS_MODE_ALWAYS
	lore_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.anchor_left = 0.5
	lore_label.anchor_right = 0.5
	lore_label.anchor_top = 0.0
	lore_label.anchor_bottom = 0.0
	lore_label.offset_left = -ctb_half_width
	lore_label.offset_right = ctb_half_width
	lore_label.offset_top = ctb_spec.position.y + ctb_spec.size.y + 10.0
	lore_label.offset_bottom = ctb_spec.position.y + ctb_spec.size.y + 66.0
	lore_label.add_theme_font_size_override("font_size", ui._readable_font_size(SemanticTypography.ROLE_SECTION, 26 if big else 20))
	lore_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.74, 0.98))
	lore_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 1.0))
	lore_label.add_theme_constant_override("outline_size", 5)
	lore_label.modulate.a = 0.0
	game.hud_layer.add_child(lore_label)
	var lore_tween := lore_label.create_tween()
	lore_tween.tween_interval(0.24)
	lore_tween.tween_property(lore_label, "modulate:a", 1.0, 0.28)
	lore_tween.tween_interval(2.2 if big else 1.2)
	lore_tween.tween_property(lore_label, "modulate:a", 0.0, 0.5)
	lore_tween.tween_callback(lore_label.queue_free)


static func codex_monster_sections(ui, monster: Dictionary) -> Array:
	var monster_id := str(monster.get("id", ""))
	var kind := str(monster.get("kind", "standard"))
	var sections := []
	# Профиль угрозы: тип из ENEMY_SIZE_PROFILES + поведение.
	var profile_id := "ordinary"
	match kind:
		"elite":
			profile_id = "elite"
		"mini_elite":
			profile_id = "mini_elite"
		"boss":
			profile_id = "boss"
	var size_profile: Dictionary = ui.game.PROGRESSION_DATA.enemy_size_profile(profile_id)
	var behavior_lines := []
	if str(size_profile.get("label", "")) != "":
		behavior_lines.append("Класс угрозы: %s (габарит ×%.2f)." % [str(size_profile["label"]), float(size_profile.get("scale", 1.0))])
	if str(monster.get("behavior", "")) != "":
		behavior_lines.append(str(monster["behavior"]))
	if not behavior_lines.is_empty():
		sections.append({"heading": "Тип и поведение", "lines": behavior_lines})
	# FAN-1080: лор — боссы получают строку гибели своего мира («Владыка
	# Разлома»), элитки — строку офицера прибоя (lore_data.gd / lore.md).
	if kind == "boss":
		var doom := LORE_DATA.boss_doom_line(monster_id)
		if doom != "":
			sections.append({"heading": "Владыка Разлома", "lines": [doom]})
	elif kind == "elite":
		var elite_line := LORE_DATA.elite_lore(monster_id)
		if elite_line != "":
			sections.append({"heading": "Офицер прибоя", "lines": [elite_line]})
	# Умения — канонические имена и описания из codex_data.
	var ability_lines := []
	for ability in monster.get("abilities", []):
		ability_lines.append({"title": str((ability as Dictionary).get("title", "")), "text": str((ability as Dictionary).get("description", ""))})
	if not ability_lines.is_empty():
		sections.append({"heading": "Умения", "lines": ability_lines})
	# Боевой паттерн элиток/боссов: UNIQUE_ENCOUNTER_PATTERNS + каталог механик.
	var pattern: Dictionary = ui.game.PROGRESSION_DATA.unique_encounter_pattern(monster_id)
	if not pattern.is_empty():
		var pattern_lines := []
		if str(pattern.get("summary", "")) != "":
			pattern_lines.append({"title": str(pattern.get("title", "")), "text": "Паттерн боя: %s." % str(pattern["summary"])})
		var mechanic_catalog: Dictionary = ui.game.PROGRESSION_DATA.enemy_mechanic_catalog()
		for mechanic_id in pattern.get("mechanics", []):
			var mechanic: Dictionary = mechanic_catalog.get(str(mechanic_id), {})
			if mechanic.is_empty():
				continue
			var mechanic_text := str(mechanic.get("desc", ""))
			if bool(mechanic.get("telegraph", false)):
				mechanic_text += " Телеграфится заранее."
			pattern_lines.append({"title": str(mechanic.get("title", mechanic_id)), "text": mechanic_text})
		if not pattern_lines.is_empty():
			sections.append({"heading": "Боевой паттерн", "lines": pattern_lines})
	# Боевые параметры из конфигов: спецатака элитки / множители мини-элитки.
	var combat_lines := []
	var attack_source_id := monster_id
	var mini_kind: Dictionary = {}
	if kind == "mini_elite":
		mini_kind = ui.game.PROGRESSION_DATA.mini_elite_kind_by_id(monster_id)
		if not mini_kind.is_empty():
			combat_lines.append("Относительно базовой элитки: здоровье ×%.2f; скорость ×%.2f; урон ×%.2f." % [float(mini_kind.get("hp_mult", 1.0)), float(mini_kind.get("speed_mult", 1.0)), float(mini_kind.get("damage_mult", 1.0))])
			attack_source_id = str(mini_kind.get("behavior", monster_id))
	var attack_config: Dictionary = ui.game.PROGRESSION_DATA.elite_attack_config(attack_source_id)
	if not attack_config.is_empty():
		var attack_bits := PackedStringArray()
		if float(attack_config.get("cooldown", 0.0)) > 0.0:
			attack_bits.append("перезарядка %.1f с" % float(attack_config["cooldown"]))
		if float(attack_config.get("trigger_range", 0.0)) > 0.0:
			attack_bits.append("дистанция срабатывания %d" % int(attack_config["trigger_range"]))
		if float(attack_config.get("radius", 0.0)) > 0.0:
			attack_bits.append("радиус %d" % int(attack_config["radius"]))
		if float(attack_config.get("damage_factor", 0.0)) > 0.0:
			attack_bits.append("урон ×%.1f от базового" % float(attack_config["damage_factor"]))
		if not attack_bits.is_empty():
			combat_lines.append("Спецатака: %s." % "; ".join(attack_bits))
	if not combat_lines.is_empty():
		sections.append({"heading": "Боевые параметры", "lines": combat_lines})
	return sections
