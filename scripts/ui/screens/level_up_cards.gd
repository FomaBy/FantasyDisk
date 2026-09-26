extends "res://scripts/ui/screens/level_up_screen.gd"

# FAN-3824: модуль распределённого UI-класса — карточки наград level-up/боя/артефактов и превью эффектов.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# SCRUM-871/FAN-1887: актуальный weapon_config — боевой или собранный по
# выбранному классу/оружию тем же ProgressionData.weapon путём. Общая точка для
# прогноза советника и presentation-фильтра карточек.
func _active_weapon_config() -> Dictionary:
	var weapon_config = {}
	if game.current_player != null and is_instance_valid(game.current_player):
		weapon_config = game.current_player.get("weapon_config")
	if not (weapon_config is Dictionary) or (weapon_config as Dictionary).is_empty():
		weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
	return weapon_config




# SCRUM-871: контекст прогноза — живые статы/моды игрока (бой или меню-снапшот,
# fallback на базу класса) + актуальный weapon_config.
func _level_up_offer_advice(rewards: Array) -> Dictionary:
	return LevelUpAdvisor.recommend(rewards, _active_stats_snapshot(), _active_modifiers_snapshot(), _active_weapon_config())




# SCRUM-871: понижает размер шрифта, пока строка не влезает в ширину зоны —
# юзерский масштаб шрифта (readability) может раздуть текст шире слота, а
# клип срезал бы края подписи. Вызывать после присвоения label.text.
func _shrink_label_font_to_width(label: Label, role: StringName, base_font_size: int, max_width: float, min_font_size := 12, fit_ratio := 0.62) -> void:
	# Внешняя мерка Font.get_string_size детерминирована, но фактический рендер
	# строки в окне шире мерки до ~1.5x (font oversampling/DPI), а внутренняя
	# мерка Label.get_minimum_size в этом же окружении флачит. Поэтому меряем
	# внешне и держим жёсткий запас fit_ratio 0.62 (~1/1.6): подпись гарантированно
	# помещается на всех целевых разрешениях, клип/ellipsis остаются страховкой.
	var font: Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := base_font_size
	if font != null:
		var fit_width := maxf(max_width, 8.0) * fit_ratio
		while font_size > min_font_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > fit_width:
			font_size -= 1
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		role, font_size
	))




# FAN-1887 (спека fan1883_attribute_clarity): фактическая строка результата оси —
# «было → стало · реально: +…» по действующим формулам/капам, канал урона подписан,
# у шанса крита строка «сейчас · максимум», у вампиризма — отдельный шанс срабатывания.
func _level_up_axis_lines(reward: Dictionary) -> Array:
	return AttributeSurfaces.axis_presentation_lines(
		reward, game.selected_character_id, _active_stats_snapshot(), _active_modifiers_snapshot(), _active_weapon_config())




# Строки блока изменений карточки: фактическая строка оси (FAN-1887), затем
# дельты прогноза; без измеримых дельт — прежнее SCRUM-525 превью (спец-эффекты
# вроде призывов), затем краткий фолбэк.
func _level_up_delta_lines(reward: Dictionary, forecast: Dictionary) -> Array:
	var lines: Array = []
	var explicit_summary := str(reward.get("effect_summary", "")).strip_edges()
	if explicit_summary != "":
		lines.append(explicit_summary)
		return lines
	lines = _level_up_axis_lines(reward)
	var axis_parameter := ""
	if not lines.is_empty():
		var attr_id := str(reward.get("attr", ""))
		axis_parameter = "summon_amount" if attr_id == "summon_amount" else AttributeContract.presentation_parameter_for(attr_id, game.selected_character_id)
	for delta in (forecast.get("deltas", []) as Array):
		if lines.size() >= 3:
			break
		if str((delta as Dictionary).get("id", "")) == axis_parameter:
			continue
		lines.append(LevelUpAdvisor.delta_line(delta))
	if lines.is_empty():
		lines = _level_up_effect_preview_lines(reward, 2)
	if lines.is_empty():
		lines.append(_level_up_reward_preview(reward))
	return lines




func _format_level_up_gain_percent(gain: float) -> String:
	var percent := gain * 100.0
	return "%.1f%%" % percent if absf(percent) < 10.0 else "%d%%" % int(roundf(percent))




# Тултип карточки: название, описание, полный список изменений, классовая
# интерпретация и объяснение бейджа рекомендации.
# FAN-1927 (LU.DetailDrawer): полная копия сфокусированной карточки — фактические
# оси (before→after, кап, шанс срабатывания) + полный текст карточки/советника.
func _level_up_detail_drawer_text(reward: Dictionary, forecast: Dictionary, badge_kind: String, advice := {}) -> String:
	var parts: Array = []
	for axis_line in _level_up_axis_lines(reward):
		parts.append(str(axis_line))
	var tooltip := _level_up_card_tooltip(reward, forecast, badge_kind, advice)
	if tooltip != "":
		parts.append(tooltip)
	return "\n".join(parts)




func _level_up_card_tooltip(reward: Dictionary, forecast: Dictionary, badge_kind: String, advice := {}) -> String:
	var parts: Array = [str(reward.get("title", "Upgrade"))]
	var deltas: Array = forecast.get("deltas", [])
	if not deltas.is_empty():
		var delta_lines: Array = []
		for delta in deltas:
			delta_lines.append("  %s" % LevelUpAdvisor.delta_line(delta))
		parts.append("Изменения:\n%s" % "\n".join(delta_lines))
	else:
		parts.append(_level_up_reward_preview(reward))
	var interpretation := _reward_interpretation_text(reward)
	if interpretation != "":
		parts.append(interpretation)
	match badge_kind:
		"dps":
			parts.append("Метка «Лучший урон»: наибольший прирост урона в секунду (+%s) для твоего класса и оружия." % _format_level_up_gain_percent(float(advice.get("dps_gain", 0.0))))
		"surv":
			parts.append("Метка «Выживание»: наибольший прирост живучести (+%s) — здоровье, защита, уклонение, поглощение и лечение." % _format_level_up_gain_percent(float(advice.get("surv_gain", 0.0))))
		"both":
			parts.append("Метка «Лучший выбор»: сильнейший рост и урона (+%s), и живучести (+%s)." % [_format_level_up_gain_percent(float(advice.get("dps_gain", 0.0))), _format_level_up_gain_percent(float(advice.get("surv_gain", 0.0)))])
	var description := str(reward.get("description", "")).strip_edges()
	if description != "":
		parts.append(description)
	return "\n".join(parts)




# SCRUM-883: бейдж рекомендации советника — полупрозрачная плашка атласа
# (_atlas_translucent_style) в бейдж-слоте стека карточки (rect из плана
# SCRUM-892), подпись цветом типа бейджа. Механика kind — в LevelUpAdvisor.
func _add_level_up_badge(content: Control, badge_kind: String, badge_rect: Rect2, base_font_size: int) -> void:
	var badge_meta: Dictionary = LU_BADGE_META[badge_kind]
	var badge := PanelContainer.new()
	badge.name = "LevelUpRewardBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _atlas_translucent_style(0.7, 6.0))
	badge.position = badge_rect.position
	badge.size = badge_rect.size
	badge.custom_minimum_size = badge_rect.size
	content.add_child(badge)

	var badge_label := Label.new()
	badge_label.name = "LevelUpRewardBadgeLabel"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.text = str(badge_meta["text"])
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.clip_text = true
	badge_label.max_lines_visible = 1
	badge_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Фидбек читаемости SCRUM-883: пол кегля 12 — подпись всегда читаемая.
	_shrink_label_font_to_width(badge_label, SemanticTypography.ROLE_HUD, base_font_size, badge_rect.size.x - 8.0, SemanticTypography.role_min(SemanticTypography.ROLE_HUD))
	badge_label.add_theme_color_override("font_color", badge_meta["text_color"])
	badge.add_child(badge_label)




func _make_battle_reward_card(reward: Dictionary) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = _battle_reward_card_size()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _format_level_up_reward_text(reward)
	button.set_meta("reward_frame_kind", "battle")
	_apply_reward_card_theme(button, false)

	var content := _add_reward_card_content_container(button, false)
	content.name = "BattleRewardCardContent"
	content.add_theme_constant_override("separation", 5)

	var icon_row := HBoxContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	# SCRUM-963: пост-боевые награды тоже содержат артефакты (reward_pool) —
	# артефакт показывает свою artifact_<id>.png, статы — реестровые иконки.
	icon_row.add_child(_make_reward_card_icon(reward, Vector2(40, 40)))

	var title_label := Label.new()
	title_label.name = "BattleRewardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Награда"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_TITLE,
		_readable_font_size(SemanticTypography.ROLE_TITLE, 17, 12, 22),
		SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
		SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
	))
	# SCRUM-963: титул артефакта — цветом редкости (язык элитных карточек);
	# стат/атрибут-награды остаются золотыми.
	if str(reward.get("kind", "")) == "artifact":
		title_label.add_theme_color_override("font_color", _artifact_tier_color(reward))
	else:
		title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	content.add_child(title_label)

	var preview_label := Label.new()
	preview_label.name = "BattleRewardPreview"
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.text = _level_up_reward_preview(reward)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_BODY, 14, 12, 16))
	preview_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content.add_child(preview_label)

	var description_label := Label.new()
	description_label.name = "BattleRewardDescription"
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(reward.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DESCRIPTION, 12, 12, 14))
	description_label.add_theme_color_override("font_color", Color(0.78, 0.66, 0.44, 1.0))
	content.add_child(description_label)

	# SCRUM-963: классовая пометка классового артефакта — одна строка цветом пометки.
	var reward_note := _artifact_affinity_note(reward)
	if not reward_note.is_empty():
		var note_label := Label.new()
		note_label.name = "BattleRewardClassNote"
		note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note_label.text = str(reward_note["text"])
		note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_label.max_lines_visible = 1
		note_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		note_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 11, 12, 14),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
		note_label.add_theme_color_override("font_color", reward_note["color"])
		content.add_child(note_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0.0, 0.0)
	content.add_child(spacer)

	var action_label := Label.new()
	action_label.name = "BattleRewardActionLabel"
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.text = "Получить"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, 15, 12, 16))
	action_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	action_label.add_theme_color_override("font_outline_color", Color(0.13, 0.04, 0.035, 0.92))
	action_label.add_theme_constant_override("outline_size", 2)
	content.add_child(action_label)
	_resize_reward_card(button, button.custom_minimum_size)
	return button




func _make_elite_artifact_card(reward: Dictionary, presentation := {}) -> Button:
	# SCRUM-990/991: одна карточка трофея для elite/chest/boss. Содержит только
	# concrete current-class effect и безопасные recommendation badges; старой
	# отдельной строки «Интерпретация» больше нет.
	var resolved_presentation: Dictionary = presentation as Dictionary
	if resolved_presentation.is_empty():
		resolved_presentation = _artifact_reward_single_presentation(reward)
	var tier_color := _artifact_tier_color(reward)
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = (_artifact_reward_layout_metrics(game.get_viewport().get_visible_rect().size)["card_size"] as Vector2)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s\n%s" % [_format_level_up_reward_text(reward), str(resolved_presentation.get("resolved_effect", ""))]
	button.set_meta("reward_frame_kind", "elite_artifact")
	button.set_meta("artifact_reward_id", str(reward.get("id", "")))
	_resize_elite_artifact_card(button, button.custom_minimum_size)

	var content := VBoxContainer.new()
	content.name = "EliteArtifactRewardContent"
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(content)

	var icon_row := HBoxContainer.new()
	icon_row.name = "EliteArtifactRewardIconRow"
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(icon_row)
	# SCRUM-963: у артефакта — его уникальная иконка artifact_<id>.png.
	icon_row.add_child(_make_reward_card_icon(reward, Vector2(52, 52)))

	var title_label := Label.new()
	title_label.name = "EliteArtifactRewardCardTitle"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = str(reward.get("title", "Артефакт"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.add_theme_color_override("font_color", tier_color)
	content.add_child(title_label)

	var tier_label := Label.new()
	tier_label.name = "EliteArtifactRewardTier"
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_label.text = _artifact_tier_text(reward)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.max_lines_visible = 1
	tier_label.add_theme_color_override("font_color", tier_color)
	content.add_child(tier_label)

	var badge_label := Label.new()
	badge_label.name = "EliteArtifactRewardBadge"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.text = str(resolved_presentation.get("badge_text", ""))
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.80, 0.32, 1.0))
	content.add_child(badge_label)

	var resolved_label := Label.new()
	resolved_label.name = "EliteArtifactRewardResolvedEffect"
	resolved_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved_label.text = str(resolved_presentation.get("resolved_effect", ""))
	resolved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolved_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resolved_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resolved_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resolved_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 1.0))
	content.add_child(resolved_label)

	var action_label := Label.new()
	action_label.name = "EliteArtifactRewardAction"
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.text = "Выбрать"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	content.add_child(action_label)

	_resize_elite_artifact_card(button, button.custom_minimum_size)

	return button




func _artifact_reward_weapon_config() -> Dictionary:
	var config: Dictionary = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id).duplicate(true)
	config["character_id"] = game.selected_character_id
	return config




func _artifact_reward_presentations(rewards: Array) -> Array:
	return ArtifactRewardPresenter.build_offer_presentations(
		rewards,
		game.selected_character_id,
		_active_stats_snapshot(),
		_active_modifiers_snapshot(),
		_artifact_reward_weapon_config()
	)




func _artifact_reward_single_presentation(reward: Dictionary) -> Dictionary:
	return ArtifactRewardPresenter.build_single_presentation(
		reward,
		game.selected_character_id,
		_active_stats_snapshot(),
		_active_modifiers_snapshot(),
		_artifact_reward_weapon_config()
	)




func _artifact_reward_card_pad(display_size: Vector2) -> float:
	if display_size.y < 400.0:
		return 16.0
	if display_size.y < 600.0:
		return 20.0
	return 24.0




func _resize_elite_artifact_card(button: Button, display_size: Vector2) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.custom_minimum_size = display_size
	button.size = display_size
	var pad := _artifact_reward_card_pad(display_size)
	_apply_atlas_choice_card_theme(button, pad)
	var margins := _atlas_chip_content_margins(pad)
	button.set_meta("artifact_reward_display_size", display_size)
	button.set_meta("artifact_reward_content_margins", margins)
	var content := button.find_child("EliteArtifactRewardContent", false, false) as VBoxContainer
	if content == null:
		return
	content.offset_left = margins.x
	content.offset_top = margins.y
	content.offset_right = -margins.z
	content.offset_bottom = -margins.w
	var compact := display_size.y < 400.0
	var medium := display_size.y < 600.0 and not compact
	content.add_theme_constant_override("separation", 2 if compact else (5 if medium else 7))
	var icon := content.find_child("UIIcon_*", true, false) as Control
	if icon != null:
		var icon_size := Vector2(32.0, 32.0) if compact else (Vector2(68.0, 68.0) if medium else Vector2(94.0, 94.0))
		icon.custom_minimum_size = icon_size
	var title := content.find_child("EliteArtifactRewardCardTitle", false, false) as Label
	if title != null:
		title.custom_minimum_size.y = 32.0 if compact else (58.0 if medium else 72.0)
		title.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_TITLE,
			_readable_font_size(SemanticTypography.ROLE_TITLE, 12 if compact else (16 if medium else 19), 11, 16 if compact else (20 if medium else 25)),
			SemanticTypography.role_min(SemanticTypography.ROLE_TITLE),
			SemanticTypography.role_max(SemanticTypography.ROLE_TITLE)
		))
	var tier := content.find_child("EliteArtifactRewardTier", false, false) as Label
	if tier != null:
		tier.custom_minimum_size.y = 18.0 if compact else (24.0 if medium else 30.0)
		tier.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 10 if compact else (12 if medium else 14), 10, 13 if compact else (16 if medium else 19)),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
	var badge := content.find_child("EliteArtifactRewardBadge", false, false) as Label
	if badge != null:
		badge.custom_minimum_size.y = 20.0 if compact else (34.0 if medium else 42.0)
		badge.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_HUD,
			_readable_font_size(SemanticTypography.ROLE_HUD, 9 if compact else (11 if medium else 13), 9, 11 if compact else (15 if medium else 18)),
			SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
			SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
		))
	var resolved := content.find_child("EliteArtifactRewardResolvedEffect", false, false) as Label
	if resolved != null:
		resolved.add_theme_constant_override("line_spacing", -2 if compact else 0)
		resolved.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_BODY,
			_readable_font_size(SemanticTypography.ROLE_BODY, 9 if compact else (12 if medium else 14), 9, 11 if compact else (16 if medium else 19)),
			SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
			SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
		))
	var action := content.find_child("EliteArtifactRewardAction", false, false) as Label
	if action != null:
		action.custom_minimum_size.y = 22.0 if compact else (28.0 if medium else 34.0)
		action.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_ACTION,
			_readable_font_size(SemanticTypography.ROLE_ACTION, 10 if compact else (13 if medium else 16), 10, 14 if compact else (18 if medium else 22)),
			SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
		))




func _on_player_leveled_up() -> void:
	game._play_sfx("level_up")
	game.level_up_return_to_map = not game.combat_active
	game.pending_level_ups += 1
	_show_level_up_toast()
	_update_level_up_button()




func _open_pending_level_up() -> void:
	if game.pending_level_ups <= 0:
		return

	# SCRUM-530: помним, открыт ли level-up С УЗЛА-СОБЫТИЯ — тогда после выбора/«Позже»
	# возвращаемся на то же событие, а не на карту (иначе случайное событие рероллится).
	# Пересчитываем на каждом открытии: нейтрализует устаревший флаг от прошлого узла.
	game.level_up_return_to_event = _is_event_screen_active()
	game.push_pause("level_up")
	_show_level_up_screen(game.level_up_return_to_map)




func _is_event_screen_active() -> bool:
	if game.current_event_definition.is_empty():
		return false
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return false
	return game.ui_layer.find_child("EventScreen", true, false) != null




func _return_from_level_up_to_event() -> void:
	# SCRUM-530: повторно рендерим тот же узел-событие из сохранённого current_event_definition
	# (route_node без event_id → ветка переиспользования в _show_event_screen не рероллит).
	if game.current_event_definition.is_empty():
		game.save_run_autosave("level_up_choice")
		game.route._show_battle_map()
		return
	_show_event_screen({"type": "event", "name": str(game.current_event_definition.get("title", "Событие"))})




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

	for existing in game.get_tree().get_nodes_in_group("level_up_effects"):
		if existing != null and is_instance_valid(existing):
			if existing.name != "LevelUpEffect":
				continue
			if existing is CanvasItem:
				(existing as CanvasItem).visible = false
			var parent: Node = existing.get_parent()
			if parent != null:
				parent.remove_child(existing)
			existing.queue_free()

	var effect = game.LEVEL_UP_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	effect.name = "LevelUpEffect"
	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(effect)
	effect.global_position = game.current_player.global_position
	if effect.has_method("setup"):
		effect.setup(game.current_player)




func _show_combat_title_banner(title: String, color: Color, big := false, lore_line := "") -> void:
	# Баннер появления элитки/босса: имя/титул вспыхивает над ареной и гаснет,
	# бой не ставится на паузу. Самоосвобождается; привязан к HUD-слою.
	# FAN-1080: lore_line — короткая лор-подводка (кто это и зачем он здесь),
	# отдельной строкой без рамки под баннером; живёт чуть дольше титула.
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	var existing: Node = game.hud_layer.get_node_or_null("CombatIntroBanner")
	if existing != null:
		existing.queue_free()
	var existing_lore: Node = game.hud_layer.get_node_or_null("CombatIntroLoreLine")
	if existing_lore != null:
		existing_lore.queue_free()
	var ctb_slot := "ctb_big" if big else "ctb_small"
	var ctb_spec: Rect2 = CTB_BIG_2K if big else CTB_SMALL_2K
	var ctb_half_width := ctb_spec.size.x * 0.5
	var banner := PanelContainer.new()
	banner.name = "CombatIntroBanner"
	banner.process_mode = Node.PROCESS_MODE_ALWAYS
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", _overhaul_2k_frame_style(ctb_slot, ctb_spec.size))
	# SCRUM-487: ширина баннера берётся из 2K-спеки (CTB_*_2K), а не из легаси 1280 (720p).
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = -ctb_half_width
	banner.offset_right = ctb_half_width
	banner.offset_top = ctb_spec.position.y
	banner.offset_bottom = ctb_spec.position.y + ctb_spec.size.y
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.9, 0.9)
	banner.pivot_offset = Vector2(ctb_half_width, 0.0)
	var content_margins := _overhaul_2k_content_margins(ctb_slot, ctb_spec.size)
	var content_rect := Rect2(
		Vector2(content_margins.x, content_margins.y),
		Vector2(
			ctb_spec.size.x - content_margins.x - content_margins.z,
			ctb_spec.size.y - content_margins.y - content_margins.w
		)
	)
	banner.set_meta("combat_title_slot", ctb_slot)
	banner.set_meta("combat_title_content_margins", content_margins)
	banner.set_meta("combat_title_content_rect", content_rect)
	var label := Label.new()
	label.name = "CombatIntroBannerLabel"
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_DISPLAY, 54 if big else 34, 0, 54 if big else 36))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 6 if big else 4)
	banner.add_child(label)
	game.hud_layer.add_child(banner)
	var tween := banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.18)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.1 if big else 0.7)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(banner.queue_free)

	# FAN-1080: лор-подводка отдельной строкой под баннером (scripts/ui/lore_screens.gd).
	LoreScreens.show_banner_lore_line(self, lore_line, ctb_spec, ctb_half_width, big)




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
		game.level_up_button.tooltip_text = "Открыть выбор улучшения (непотраченные уровни)"
		game.level_up_button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_ACTION,
			_readable_font_size(SemanticTypography.ROLE_ACTION, 34),
			SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
			SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
		))
		_apply_fantasy_button_theme(game.level_up_button)
		game.level_up_button.pressed.connect(_open_pending_level_up)
		level_button_parent.add_child(game.level_up_button)

		var badge_panel := PanelContainer.new()
		badge_panel.name = "LevelUpPlusBadgePanel"
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.84, 0.22, 1.0)
		badge_style.set_corner_radius_all(12)
		badge_panel.add_theme_stylebox_override("panel", badge_style)
		game.level_up_button.add_child(badge_panel)

		var badge := Label.new()
		badge.name = "LevelUpPlusBadge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_HUD, 16))
		badge.add_theme_color_override("font_color", Color(0.08, 0.05, 0.02, 1.0))
		badge_panel.add_child(badge)

	game.level_up_button.text = "+"
	game.level_up_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	# A menu pass may have moved the persistent button into a gold-shell socket.
	# Restore combat anchors before applying SCRUM-666 bottom-right offsets.
	game.level_up_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	game.level_up_button.scale = Vector2.ONE
	game.level_up_button.pivot_offset = Vector2.ZERO
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var metrics := _configure_level_up_button_for_viewport(viewport_size)
	var plus_rect: Rect2 = metrics["plus_rect"]
	var base_size: Vector2 = metrics["base_size"]
	game.level_up_button.offset_left = plus_rect.position.x - base_size.x
	game.level_up_button.offset_right = plus_rect.position.x + plus_rect.size.x - base_size.x
	game.level_up_button.offset_top = plus_rect.position.y - base_size.y
	game.level_up_button.offset_bottom = plus_rect.position.y + plus_rect.size.y - base_size.y
	# Menus with ornate gold shells own a smaller empty content rectangle than
	# the combat HUD. Re-socket the persistent button after every count update so
	# its semantic-size badge cannot fall back onto the frame rail.
	var shell_screen: Control = game.find_child("RouteMapScreen", true, false) as Control
	if shell_screen == null:
		shell_screen = game.find_child("AttributeShopScreen", true, false) as Control
	if shell_screen != null and shell_screen.has_meta("gold_shell_inner_rect"):
		_layout_level_up_button_in_gold_shell(viewport_size)




func _configure_level_up_button_for_viewport(viewport_size: Vector2) -> Dictionary:
	var scale := _scrum666_hud_scale_for_size(viewport_size)
	var plus_rect := _scrum666_scaled_rect(SCRUM666_CHUD_LEVELUP_BUTTON_2K, scale)
	var badge_rect := _scrum666_scaled_rect(SCRUM666_CHUD_LEVELUP_BADGE_2K, scale)
	var local_badge_pos := badge_rect.position - plus_rect.position
	game.level_up_button.custom_minimum_size = plus_rect.size
	game.level_up_button.size = plus_rect.size
	game.level_up_button.set_meta("scrum666_frame_rect", _scrum666_scaled_rect(SCRUM666_CHUD_LEVELUP_FRAME_2K, scale))
	game.level_up_button.set_meta("scrum666_content_zone", plus_rect)
	game.level_up_button.clip_text = true
	game.level_up_button.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_ACTION, maxi(18, int(roundf(24.0 * scale))), 0, 34))
	_apply_fantasy_button_theme(game.level_up_button)
	var badge_panel := game.level_up_button.find_child("LevelUpPlusBadgePanel", true, false) as PanelContainer
	if badge_panel != null:
		badge_panel.offset_left = local_badge_pos.x
		badge_panel.offset_top = local_badge_pos.y
		badge_panel.offset_right = local_badge_pos.x + badge_rect.size.x
		badge_panel.offset_bottom = local_badge_pos.y + badge_rect.size.y
		badge_panel.custom_minimum_size = badge_rect.size
		badge_panel.size = badge_rect.size
		badge_panel.set_meta("scrum666_content_zone", badge_rect)
	var badge_label := game.level_up_button.find_child("LevelUpPlusBadge", true, false) as Label
	if badge_label != null:
		badge_label.text = str(game.pending_level_ups)
		badge_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_HUD,
			_readable_font_size(SemanticTypography.ROLE_HUD, maxi(9, int(roundf(14.0 * scale))), 0, 22),
			SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
			SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
		))
	return {
		"plus_rect": plus_rect,
		"base_size": COMBAT_BLOCK_DESIGN_BASE_2K * scale,
		"badge_local_rect": Rect2(local_badge_pos, badge_rect.size),
		"right_overhang": maxf(0.0, local_badge_pos.x + badge_rect.size.x - plus_rect.size.x),
	}




func _layout_level_up_button_in_gold_shell(viewport_size: Vector2) -> void:
	if game.pending_level_ups <= 0 or game.level_up_button == null or not is_instance_valid(game.level_up_button):
		return
	var inner_rect := _gold_shell_inner_rect_for_size(viewport_size)
	var metrics := _configure_level_up_button_for_viewport(viewport_size)
	var button_size: Vector2 = (metrics["plus_rect"] as Rect2).size
	var reserve := 24.0 if viewport_size.y >= 1000.0 else 16.0
	var right_reserve := reserve + float(metrics["right_overhang"])
	var target_rect := Rect2(
		Vector2(inner_rect.end.x - right_reserve - button_size.x, inner_rect.end.y - reserve - button_size.y),
		button_size
	)
	game.level_up_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.level_up_button.scale = Vector2.ONE
	game.level_up_button.pivot_offset = Vector2.ZERO
	game.level_up_button.position = target_rect.position
	game.level_up_button.size = target_rect.size
	game.level_up_button.set_meta("gold_shell_inner_rect", inner_rect)
	game.level_up_button.set_meta("gold_shell_socket_rect", target_rect)
	var badge_local_rect: Rect2 = metrics["badge_local_rect"]
	game.level_up_button.set_meta("gold_shell_descendant_rect", target_rect.merge(Rect2(target_rect.position + badge_local_rect.position, badge_local_rect.size)))




func _format_level_up_reward_text(reward: Dictionary) -> String:
	var preview := _level_up_reward_preview(reward)
	var interpretation := _reward_interpretation_text(reward)
	# SCRUM-963: у классовых артефактов вместо интерпретации — классовая пометка.
	if interpretation == "":
		var note := _artifact_affinity_note(reward)
		if not note.is_empty():
			interpretation = str(note["text"])
	return "%s\n%s\n%s%s" % [
		str(reward.get("title", "Upgrade")),
		preview,
		str(reward.get("description", "")),
		"\n%s" % interpretation if interpretation != "" else "",
	]




func _level_up_card_description(reward: Dictionary) -> String:
	var description := str(reward.get("description", "")).strip_edges()
	if description == "":
		var interpretation := _reward_interpretation_text(reward).replace("Интерпретация: ", "")
		if interpretation != "":
			return interpretation
		return "Особое усиление текущего билда."
	return description




func _reward_icon_id(reward: Dictionary) -> String:
	var explicit_icon_id := str(reward.get("icon_id", "")).strip_edges()
	if explicit_icon_id != "":
		return explicit_icon_id
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return str(stat_keys[0])
	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var modifier_id := str(modifier_keys[0])
		return str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, "artifact"))
	if str(reward.get("kind", "")) == "artifact":
		return "artifact"
	return "artifact"




# SCRUM-963: иконка карточки награды. Артефакт получает СВОЮ artifact_<id>.png
# (резолвер _artifact_icon_texture, с dev-fallback внутри); стат/атрибут-награды
# остаются на реестровых иконках _reward_icon_id как раньше.
func _make_reward_card_icon(reward: Dictionary, size: Vector2) -> Control:
	if str(reward.get("kind", "")) == "artifact" and str(reward.get("id", "")) != "":
		var icon := TextureRect.new()
		icon.name = "RewardArtifactIcon_%s" % str(reward["id"])
		icon.texture = _artifact_icon_texture(str(reward["id"]))
		icon.custom_minimum_size = size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return icon
	return game.UIIconRegistry.make_icon(_reward_icon_id(reward), size)




# SCRUM-525: какие производные статы реально двигает +1 к базовому атрибуту.
# Список — самые значимые производные (порядок = приоритет показа), чтобы тултип
# докачки не разрастался и не давал overflow на 720p. Damage-типы тут приводятся к
# «своему» типу класса в _attribute_upgrade_preview_lines/_attribute_influence_text
# (изоляция типов урона SCRUM-524): чужой тип урона в превью не показываем.


# SCRUM-525/FAN-1927: «Влияет на: …» и предпросмотр «было -> станет» — дельты
# канонических осей единого view-model (AttributeSurfaces.axis_diffs).
func _attribute_axis_diffs(stat_id: String, delta := 1.0) -> Array:
	return AttributeSurfaces.axis_diffs(
		game.selected_character_id, _active_stats_snapshot(), _active_modifiers_snapshot(), _active_weapon_config(), stat_id, delta)




func _attribute_influence_text(stat_id: String) -> String:
	return AttributeSurfaces.influence_text(_attribute_axis_diffs(stat_id, 1.0))




func _attribute_upgrade_preview_lines(stat_id: String, delta := 1.0, max_lines := 4) -> Array:
	return AttributeSurfaces.preview_lines(_attribute_axis_diffs(stat_id, delta), max_lines)




func _level_up_effect_preview_lines(reward: Dictionary, max_lines := 2) -> Array:
	var lines: Array = []
	if reward.has("stats"):
		for stat_key in (reward.get("stats", {}) as Dictionary).keys():
			var stat_id := str(stat_key)
			var delta := float((reward["stats"] as Dictionary).get(stat_id, 0.0))
			for line in _attribute_upgrade_preview_lines(stat_id, delta):
				lines.append(line)
				if lines.size() >= max_lines:
					return lines
			if lines.is_empty():
				var before_stats := _active_stats_snapshot()
				var before_value := float(before_stats.get(stat_id, 0.0))
				var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
				lines.append("%s: %.0f -> %.0f" % [stat_name, before_value, before_value + delta])
				if lines.size() >= max_lines:
					return lines
	if reward.has("mods") or reward.has("affinity_mods"):
		var before_stats := _active_stats_snapshot()
		var before_mods := _active_modifiers_snapshot()
		var after_mods := before_mods.duplicate(true)
		_level_up_apply_mod_preview(after_mods, reward.get("mods", {}) as Dictionary)
		_level_up_apply_mod_preview(after_mods, reward.get("affinity_mods", {}) as Dictionary)
		var weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
		var before_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, before_mods, weapon_config)
		var after_parameters: Dictionary = game.PROGRESSION_DATA.derived_parameters(before_stats, after_mods, weapon_config)
		var seen_parameters := {}
		for mod_dict in [reward.get("mods", {}) as Dictionary, reward.get("affinity_mods", {}) as Dictionary]:
			for modifier_id_raw in mod_dict.keys():
				var modifier_id := str(modifier_id_raw)
				var parameter_id := str(game.LEVEL_UP_MOD_DISPLAY.get(modifier_id, modifier_id))
				if parameter_id == "damage":
					parameter_id = AttributeContract.weapon_damage_parameter(_active_weapon_config(), game.selected_character_id)
				if seen_parameters.has(parameter_id):
					continue
				seen_parameters[parameter_id] = true
				var before_value := float(before_parameters.get(parameter_id, before_mods.get(modifier_id, 0.0)))
				var after_value := float(after_parameters.get(parameter_id, after_mods.get(modifier_id, 0.0)))
				var before_text := _format_level_up_value(parameter_id, before_value)
				var after_text := _format_level_up_value(parameter_id, after_value)
				if before_text == after_text and after_mods.has(modifier_id):
					before_text = _format_level_up_value(parameter_id, float(before_mods.get(modifier_id, 0.0)))
					after_text = _format_level_up_value(parameter_id, float(after_mods.get(modifier_id, 0.0)))
				if before_text == after_text:
					continue
				lines.append("%s: %s -> %s" % [_level_up_parameter_label(parameter_id), before_text, after_text])
				if lines.size() >= max_lines:
					return lines
	if lines.is_empty():
		var description := str(reward.get("description", "")).strip_edges()
		lines.append(description if description != "" else "Эффект применится к текущему билду")
	return lines




func _level_up_apply_mod_preview(target_mods: Dictionary, mods: Dictionary) -> void:
	for modifier_id in mods.keys():
		if str(modifier_id).ends_with("_multiplier"):
			target_mods[modifier_id] = float(target_mods.get(modifier_id, 1.0)) * float(mods[modifier_id])
		else:
			target_mods[modifier_id] = float(target_mods.get(modifier_id, 0.0)) + float(mods[modifier_id])




func _level_up_reward_preview(reward: Dictionary) -> String:
	var preview_lines := _level_up_effect_preview_lines(reward, 2)
	if not preview_lines.is_empty():
		return " • ".join(preview_lines)
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
			parameter_id = AttributeContract.weapon_damage_parameter(_active_weapon_config(), game.selected_character_id)
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
	# SCRUM-963: классовые артефакты говорят классовой пометкой (_artifact_affinity_note),
	# а не генерик-интерпретацией первого mod-ключа — новые классовые ключи
	# (rage_hit_stacks и т.п.) неизвестны LEVEL_UP_MOD_DISPLAY и давали филлер.
	if not (reward.get("class_affinity", []) as Array).is_empty():
		return ""
	var stat_keys := (reward.get("stats", {}) as Dictionary).keys()
	if not stat_keys.is_empty():
		return "Интерпретация: %s" % game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, str(stat_keys[0]))
	var modifier_keys := (reward.get("mods", {}) as Dictionary).keys()
	if not modifier_keys.is_empty():
		var parameter_id = str(game.LEVEL_UP_MOD_DISPLAY.get(str(modifier_keys[0]), modifier_keys[0]))
		if parameter_id == "damage":
			parameter_id = AttributeContract.weapon_damage_parameter(_active_weapon_config(), game.selected_character_id)
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
	return AttributeContract.parameter_label(parameter_id)




func _format_level_up_value(parameter_id: String, value: float) -> String:
	return AttributeContract.format_value(parameter_id, value)




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
	game.record_codex_artifact_discovery(item)
	game.combat._store_player_snapshot(temp_player)
	game.run_used_shop = true
	temp_player.queue_free()
	return true




func _apply_reward_to_active_run(reward: Dictionary) -> void:
	if game.current_player != null and is_instance_valid(game.current_player):
		game.current_player.apply_reward(reward)
		game.record_codex_artifact_discovery(reward)
		game.combat._store_player_snapshot(game.current_player)
	else:
		_apply_reward_to_run(reward)




func _apply_reward_to_run(reward: Dictionary) -> void:
	var temp_player = game.combat._snapshot_player_for_menu()
	temp_player.apply_reward(reward)
	game.record_codex_artifact_discovery(reward)
	game.combat._store_player_snapshot(temp_player)
	temp_player.queue_free()
