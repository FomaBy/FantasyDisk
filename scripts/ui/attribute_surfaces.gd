class_name AttributeSurfaces
extends RefCounted

# FAN-1927: построители атрибутных поверхностей поверх canonical view-model
# (AttributeContract): раскладка Докачки с approved AS.DetailDrawer, зона
# LU.DetailDrawer, дельты канонических осей для превью/«Влияет на», живые
# строки оси Кодекса и компактные проекции карточек. Извлечено из ui_screens.gd
# по monolith-ратчету quality_static_guard; функции статические, весь контекст —
# явные аргументы (game-состояние сюда не проникает).


# Раскладка Attribute Shop (спека fan1883_attribute_clarity, AS.*): AS.DetailDrawer
# живёт в реальной свободной зоне: между рядом и действиями на 1080p+, слева от
# ряда на compact-вьюпортах. Это исключает viewport-clamped engine tooltip.
static func shop_layout(viewport_size: Vector2, safe_rect: Rect2, inner_rect: Rect2) -> Dictionary:
	var tier_t := clampf((viewport_size.y - 720.0) / 360.0, 0.0, 1.0)
	var large_t := clampf((viewport_size.y - 1080.0) / 360.0, 0.0, 1.0)
	var card_size := Vector2.ZERO
	var offer_gap := 0.0
	var offer_top_offset := 0.0
	var compact_tooltip_width := 0.0
	var compact_tooltip_gap := 0.0
	var action_size := Vector2.ZERO
	var action_gap := 0.0
	var action_bottom_inset := 0.0
	var title_size := Vector2.ZERO
	var money_size := Vector2.ZERO
	if viewport_size.y <= 1080.0:
		card_size = Vector2(276.0, 258.0).lerp(Vector2(360.0, 410.0), tier_t)
		offer_gap = lerpf(22.0, 70.0, tier_t)
		offer_top_offset = lerpf(81.0, 137.0, tier_t)
		action_size = Vector2(300.0, 64.0).lerp(Vector2(380.0, 72.0), tier_t)
		action_gap = lerpf(80.0, 160.0, tier_t)
		action_bottom_inset = lerpf(19.0, 30.0, tier_t)
		title_size = Vector2(378.0, 50.0).lerp(Vector2(500.0, 60.0), tier_t)
		money_size = Vector2(240.0, 42.0).lerp(Vector2(380.0, 50.0), tier_t)
	else:
		card_size = Vector2(360.0, 410.0).lerp(Vector2(460.0, 540.0), large_t)
		offer_gap = lerpf(70.0, 120.0, large_t)
		offer_top_offset = lerpf(137.0, 173.0, large_t)
		action_size = Vector2(380.0, 72.0).lerp(Vector2(460.0, 88.0), large_t)
		action_gap = lerpf(160.0, 340.0, large_t)
		action_bottom_inset = lerpf(30.0, 35.0, large_t)
		title_size = Vector2(500.0, 60.0).lerp(Vector2(700.0, 64.0), large_t)
		money_size = Vector2(380.0, 50.0).lerp(Vector2(480.0, 64.0), large_t)

	# 720p reserves a real left content zone for the production disclosure host.
	# The offer lane starts after it, so even the Atlas three-offer row stays clear.
	var offer_lane := inner_rect
	if viewport_size.y < 1000.0:
		compact_tooltip_width = minf(210.0, maxf(180.0, inner_rect.size.x * 0.22))
		compact_tooltip_gap = 18.0
		offer_lane.position.x += 12.0 + compact_tooltip_width + compact_tooltip_gap
		offer_lane.size.x = maxf(180.0, inner_rect.end.x - 12.0 - offer_lane.position.x)
	# Width-constrained windows still keep exactly three cards in one row.
	var offer_available_width := offer_lane.size.x if compact_tooltip_width > 0.0 else inner_rect.size.x - 48.0
	var max_offer_width := maxf(180.0, (offer_available_width - offer_gap * 2.0) / 3.0)
	card_size.x = minf(card_size.x, max_offer_width)
	var offer_row_size := Vector2(card_size.x * 3.0 + offer_gap * 2.0, card_size.y)
	var offer_rect := Rect2(
		Vector2(roundf(offer_lane.position.x + (offer_lane.size.x - offer_row_size.x) * 0.5), roundf(inner_rect.position.y + offer_top_offset)),
		offer_row_size
	)

	var max_action_width := maxf(180.0, (inner_rect.size.x - 48.0 - action_gap) * 0.5)
	action_size.x = minf(action_size.x, max_action_width)
	var action_row_size := Vector2(action_size.x * 2.0 + action_gap, action_size.y)
	var action_rect := Rect2(
		Vector2(
			roundf(inner_rect.position.x + (inner_rect.size.x - action_row_size.x) * 0.5),
			roundf(inner_rect.end.y - action_bottom_inset - action_size.y)
		),
		action_row_size
	)
	# Never let the offer row collide with the bottom action band on unusual aspect ratios.
	var drawer_height := 0.0
	if compact_tooltip_width > 0.0:
		drawer_height = maxf(160.0, action_rect.position.y - offer_rect.position.y - 20.0)
	elif viewport_size.y >= 1000.0:
		drawer_height = lerpf(112.0, 132.0, tier_t) if viewport_size.y <= 1080.0 else lerpf(132.0, 176.0, large_t)
	var card_floor := lerpf(232.0, 360.0, tier_t) if viewport_size.y <= 1080.0 else lerpf(360.0, 500.0, large_t)
	var available := maxf(160.0, action_rect.position.y - offer_rect.position.y - 24.0)
	card_size.y = minf(card_size.y, available)
	if drawer_height > 0.0 and compact_tooltip_width <= 0.0:
		card_size.y = clampf(available - drawer_height - 16.0, minf(card_floor, card_size.y), card_size.y)
	offer_rect.size.y = card_size.y
	var drawer_rect := Rect2()
	if compact_tooltip_width > 0.0:
		drawer_rect = Rect2(
			Vector2(inner_rect.position.x + 12.0, offer_rect.position.y),
			Vector2(compact_tooltip_width, drawer_height)
		)
	elif drawer_height > 0.0:
		var drawer_top := offer_rect.end.y + 8.0
		drawer_height = minf(drawer_height, action_rect.position.y - drawer_top - 8.0)
		if drawer_height >= 40.0:
			var drawer_width := minf(lerpf(872.0, 980.0, tier_t) if viewport_size.y <= 1080.0 else lerpf(980.0, 1300.0, large_t), inner_rect.size.x - 48.0)
			drawer_rect = Rect2(
				Vector2(roundf(inner_rect.position.x + (inner_rect.size.x - drawer_width) * 0.5), roundf(drawer_top)),
				Vector2(drawer_width, drawer_height)
			)

	var title_rect := Rect2(
		Vector2(roundf(inner_rect.position.x + (inner_rect.size.x - title_size.x) * 0.5), roundf(inner_rect.position.y + lerpf(6.0, 10.0, clampf((viewport_size.y - 720.0) / 720.0, 0.0, 1.0)))),
		title_size
	)
	var money_rect := Rect2(
		Vector2(inner_rect.position.x + 24.0, inner_rect.position.y + (20.0 if viewport_size.y >= 1000.0 else 10.0)),
		money_size
	)
	# Compact 1152×648 legacy verification: keep the left money status and the
	# centered title as separate peers instead of allowing their labels to touch.
	money_rect.size.x = minf(money_rect.size.x, maxf(120.0, title_rect.position.x - money_rect.position.x - 12.0))
	return {
		"safe_rect": safe_rect,
		"inner_rect": inner_rect,
		"title_rect": title_rect,
		"money_rect": money_rect,
		"offers_rect": offer_rect,
		"offer_size": card_size,
		"offer_gap": offer_gap,
		"actions_rect": action_rect,
		"action_size": action_size,
		"action_gap": action_gap,
		"drawer_rect": drawer_rect,
		"tooltip_host_rect": drawer_rect,
	}


# Фактический rect LU.DetailDrawer из остатка зоны ПОД контентной высотой
# карточек (карточный план не ужимается). На сверхкомпактных вьюпортах остатка
# нет — drawer становится focus-overlay (спека: «focus drawer — scroll»).
static func level_up_drawer_placement(layout: Dictionary, rewards_row_position: Vector2, rewards_row_size: Vector2) -> Dictionary:
	var desired: Vector2 = layout.get("drawer_size", Vector2(760.0, 120.0))
	var scale := float(layout.get("scale", 1.0))
	var gap := maxf(8.0, roundf(10.0 * scale))
	# Орнамент плашки «Позже» поднимается над её логическим rect — держим зазор.
	var clearance := maxf(12.0, roundf(18.0 * scale))
	var plan_card_height: float = ((layout.get("card_plan", {}) as Dictionary).get("card_size", Vector2.ZERO) as Vector2).y
	var slack := rewards_row_size.y - plan_card_height
	var height := minf(desired.y, slack - gap) - clearance
	var content_width: float = (layout.get("content_size", Vector2(1280.0, 720.0)) as Vector2).x
	var overlay := height < 40.0
	if overlay:
		return {
			"overlay": true,
			"reduced_row_size": rewards_row_size,
			"rect": Rect2(
				Vector2(roundf((content_width - desired.x) * 0.5), rewards_row_position.y + rewards_row_size.y - desired.y - clearance),
				desired
			),
		}
	var reduced_row_size := rewards_row_size - Vector2(0.0, height + gap + clearance)
	return {
		"overlay": false,
		"reduced_row_size": reduced_row_size,
		"rect": Rect2(
			Vector2(roundf((content_width - desired.x) * 0.5), rewards_row_position.y + reduced_row_size.y + gap),
			Vector2(desired.x, roundf(height))
		),
	}


# Узлы approved detail-drawer (панель + scroll + label без ellipsis) для
# LU.DetailDrawer / AS.DetailDrawer; позиционирует вызывающая сторона.
static func make_detail_drawer(prefix: String, style: StyleBox) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "%sDetailDrawer" % prefix
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.visible = false
	var scroll := ScrollContainer.new()
	scroll.name = "%sDetailScroll" % prefix
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content_margin := MarginContainer.new()
	content_margin.name = "%sDetailContentMargin" % prefix
	content_margin.add_theme_constant_override("margin_left", 3)
	content_margin.add_theme_constant_override("margin_right", 3)
	content_margin.add_theme_constant_override("margin_top", 2)
	content_margin.add_theme_constant_override("margin_bottom", 2)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_margin)
	var label := Label.new()
	label.name = "%sDetailLabel" % prefix
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = -1
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.add_child(label)
	return {"panel": panel, "scroll": scroll, "label": label}


# Фактические строки оси карточки level-up (before→after/реально, кап крита,
# отдельный шанс срабатывания вампиризма) — из weapon-aware presentation.
static func axis_presentation_lines(reward: Dictionary, character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config: Dictionary) -> Array:
	var attr_id := str(reward.get("attr", ""))
	if attr_id == "" or not ProgressionData.ATTRIBUTE_RELEVANCE.has(attr_id):
		return []
	var presentation: Dictionary = AttributeContract.attribute_presentation(
		reward, character_id, stats, run_modifiers, weapon_config)
	var parameter: String = "summon_amount" if attr_id == "summon_amount" else AttributeContract.presentation_parameter_for(attr_id, character_id, weapon_config)
	var before_text := AttributeContract.format_value(parameter, float(presentation.get("before", 0.0)))
	var after_text := AttributeContract.format_value(parameter, float(presentation.get("after", 0.0)))
	var delta := float(presentation.get("delta_effective", 0.0))
	var delta_text := AttributeContract.format_value(parameter, absf(delta))
	if before_text == after_text and absf(delta) > 0.0:
		# Малый канал (например magic-канал pure-summon кита): целые значения
		# схлопываются — показываем честную дельту с одним знаком после запятой.
		before_text = "%.1f" % float(presentation.get("before", 0.0))
		after_text = "%.1f" % float(presentation.get("after", 0.0))
		delta_text = "%.1f" % absf(delta)
	var channel := str(presentation.get("channel_label", ""))
	var axis_label := channel if channel != "" else str(presentation.get("axis_name", attr_id))
	var lines: Array = []
	lines.append("%s: %s -> %s · реально: %s%s" % [axis_label, before_text, after_text, "+" if delta >= 0.0 else "-", delta_text])
	if presentation.has("cap") and attr_id == "crit_chance":
		lines.append("сейчас %s · максимум %s" % [before_text, AttributeContract.format_value(parameter, float(presentation.get("cap", 0.0)))])
	if presentation.has("proc_chance_current"):
		lines.append("шанс срабатывания: сейчас %s · максимум %s" % [
			AttributeContract.format_value("vampiric_chance", float(presentation.get("proc_chance_current", 0.0))),
			AttributeContract.format_value("vampiric_chance", float(presentation.get("proc_chance_cap", 0.0)))])
	return lines


# Дельты канонических осей героя при +delta к базовой характеристике — единый
# effective-value source для «Влияет на: …», предпросмотра и drawer Докачки.
static func axis_diffs(character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config: Dictionary, stat_id: String, delta := 1.0) -> Array:
	if not stats.has(stat_id):
		return []
	var after_stats := stats.duplicate(true)
	after_stats[stat_id] = float(after_stats.get(stat_id, 0.0)) + delta
	var diffs: Array = []
	for snapshot_value in AttributeContract.class_axes_snapshot(character_id, stats, run_modifiers, weapon_config):
		var snapshot := snapshot_value as Dictionary
		var axis_id := str(snapshot.get("axis_id", ""))
		var after_snapshot: Dictionary = AttributeContract.axis_snapshot(axis_id, character_id, after_stats, run_modifiers, weapon_config)
		var before_text := str(snapshot.get("value_text", ""))
		var after_text := str(after_snapshot.get("value_text", ""))
		if before_text == after_text:
			continue
		diffs.append({
			"axis_id": axis_id,
			"axis_name": str(snapshot.get("axis_name", axis_id)),
			"before_text": before_text,
			"after_text": after_text,
		})
	return diffs


static func influence_text(diffs: Array) -> String:
	var labels: Array = []
	for diff in diffs:
		var label := str((diff as Dictionary).get("axis_name", ""))
		if label != "" and not labels.has(label):
			labels.append(label)
	return ", ".join(labels)


static func preview_lines(diffs: Array, max_lines := 4) -> Array:
	var lines: Array = []
	for diff_value in diffs:
		var diff := diff_value as Dictionary
		lines.append("%s: %s -> %s" % [str(diff.get("axis_name", "")), str(diff.get("before_text", "")), str(diff.get("after_text", ""))])
		if lines.size() >= max_lines:
			break
	return lines


# FAN-1927 (спека AS, eligible_stat_ids): базовая характеристика попадает в
# offer только если +1 реально меняет отображаемое effective-значение хотя бы
# одной player-facing оси текущего класса/оружия.
static func shop_stat_eligible(character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config: Dictionary, stat_id: String) -> bool:
	return not axis_diffs(character_id, stats, run_modifiers, weapon_config, stat_id, 1.0).is_empty()


# Строки «Этот герой» для оси кодекса — тот же canonical axis_snapshot, что у
# Pause/Hero Select: текущее значение, канал урона, кап-состояние (читаемая
# история без CTA) и изменение относительно базы класса.
static func codex_axis_live_lines(axis_id: String, character_id: String, stats: Dictionary, run_modifiers: Dictionary, weapon_config: Dictionary, base_stats: Dictionary) -> Array:
	var snapshot: Dictionary = AttributeContract.axis_snapshot(axis_id, character_id, stats, run_modifiers, weapon_config)
	var lines: Array = []
	if not bool(snapshot.get("eligible", false)):
		lines.append("Этому герою сейчас не выдаётся: класс или текущее оружие не использует ось.")
		return lines
	var value_text := str(snapshot.get("value_text", ""))
	lines.append("Сейчас: %s" % value_text)
	if snapshot.has("channel_label"):
		lines.append("Канал: %s" % str(snapshot.get("channel_label", "")))
	if snapshot.has("cap"):
		if bool(snapshot.get("cap_reached", false)):
			lines.append("Достигнут максимум: %s" % AttributeContract.format_value(str(snapshot.get("parameter", axis_id)), float(snapshot.get("cap", 0.0))))
		else:
			lines.append("Максимум: %s" % AttributeContract.format_value(str(snapshot.get("parameter", axis_id)), float(snapshot.get("cap", 0.0))))
	if snapshot.has("proc_chance_current"):
		lines.append("Шанс срабатывания: сейчас %s · максимум %s" % [
			AttributeContract.format_value("vampiric_chance", float(snapshot.get("proc_chance_current", 0.0))),
			AttributeContract.format_value("vampiric_chance", float(snapshot.get("proc_chance_cap", 0.0))),
		])
	var base_snapshot: Dictionary = AttributeContract.axis_snapshot(axis_id, character_id, base_stats, {}, weapon_config)
	var base_text := str(base_snapshot.get("value_text", ""))
	if base_text != "" and base_text != value_text:
		lines.append("За забег: %s → %s" % [base_text, value_text])
	return lines


# Пошагово убирает последние пункты списка, пока Label не вмещает все свои
# wrapped-строки (данные полностью сохранены в full_text meta / drawer).
static func fit_list_label(label: Label, prefix: String, separator: String) -> void:
	if label == null or not is_instance_valid(label):
		return
	var guard := 8
	while guard > 0 and label.get_line_count() > 0 and label.get_visible_line_count() < label.get_line_count():
		var body := label.text.trim_prefix(prefix)
		var items := body.split(separator, false)
		if items.size() <= 1:
			return
		items.remove_at(items.size() - 1)
		label.text = prefix + separator.join(items)
		guard -= 1


# FAN-1927: compact-режим НЕ удаляет before→after — сокращается только подпись
# оси, числовой прогноз «X -> Y» сохраняется целиком.
static func compact_preview_line(line: String) -> String:
	var parts := line.split(":", true, 1)
	if parts.size() < 2:
		return line
	var label := str(parts[0]).strip_edges()
	if label.length() > 14:
		label = label.left(13).strip_edges() + "."
	return "%s: %s" % [label, str(parts[1]).strip_edges()]


# FAN-1927 (HS.CapPotential/HS.CapabilityLine): строки досье Hero Select —
# потенциал капов (крит «сейчас · максимум», вампиризм с отдельным шансом
# срабатывания, без CTA) и capability-строка реальных потребителей призыва
# (оружия, где summon_bonus двигает фактический парк). Пустая строка = скрыть.
static func hero_dossier_lines(character_id: String, stats: Dictionary, weapon_config: Dictionary) -> Dictionary:
	var cap_parts := PackedStringArray()
	var crit_snapshot: Dictionary = AttributeContract.axis_snapshot("crit_chance", character_id, stats, {}, weapon_config)
	if bool(crit_snapshot.get("eligible", false)) and crit_snapshot.has("cap"):
		cap_parts.append("Шанс крита: сейчас %s · максимум %s" % [
			str(crit_snapshot.get("value_text", "")),
			AttributeContract.format_value("crit_chance", float(crit_snapshot.get("cap", 0.0))),
		])
	var vampiric_snapshot: Dictionary = AttributeContract.axis_snapshot("vampiric", character_id, stats, {}, weapon_config)
	if bool(vampiric_snapshot.get("eligible", false)):
		cap_parts.append("Вампиризм: %s HP при срабатывании · шанс срабатывания: сейчас %s · максимум %s" % [
			str(vampiric_snapshot.get("value_text", "")),
			AttributeContract.format_value("vampiric_chance", float(vampiric_snapshot.get("proc_chance_current", 0.0))),
			AttributeContract.format_value("vampiric_chance", float(vampiric_snapshot.get("proc_chance_cap", 0.0))),
		])
	var summon_weapon_titles := PackedStringArray()
	for weapon_id_value in ProgressionData.weapon_ids(character_id):
		var candidate_config: Dictionary = ProgressionData.weapon(character_id, str(weapon_id_value))
		if AttributeContract.weapon_consumes_summon_bonus(candidate_config):
			summon_weapon_titles.append(str(candidate_config.get("title", weapon_id_value)))
	return {
		"cap_potential": "Потенциал: %s." % "; ".join(cap_parts) if not cap_parts.is_empty() else "",
		"capability": "Сила призыва действует с: %s." % ", ".join(summon_weapon_titles) if not summon_weapon_titles.is_empty() else "",
	}


# Подписка карточки на drawer: фокус/наведение показывают полную копию; в
# overlay-режиме drawer появляется на фокусе и прячется при его потере.
static func wire_detail_focus(button: BaseButton, label: Label, panel: Control, overlay: bool, text: String) -> void:
	var panel_overlay_active := func() -> bool:
		return overlay or (is_instance_valid(panel) and panel.is_inside_tree() and bool(panel.get_meta("production_tooltip_host", false)) \
			and panel.get_viewport_rect().size.y < 1000.0)
	button.mouse_entered.connect(func() -> void:
		if is_instance_valid(label):
			label.text = text
		if panel_overlay_active.call() and is_instance_valid(panel):
			panel.set_meta("detail_drawer_open", true)
			panel.visible = true
	)
	button.focus_entered.connect(func() -> void:
		if is_instance_valid(label):
			label.text = text
		if overlay and is_instance_valid(panel):
			panel.set_meta("detail_drawer_open", true)
			panel.visible = true
	)
	if overlay or panel != null:
		button.mouse_exited.connect(func() -> void:
			if panel_overlay_active.call() and is_instance_valid(panel) and is_instance_valid(button) and not button.has_focus():
				panel.set_meta("detail_drawer_open", false)
				panel.visible = false
		)
		button.focus_exited.connect(func() -> void:
			if panel_overlay_active.call() and is_instance_valid(panel):
				panel.set_meta("detail_drawer_open", false)
				panel.visible = false
		)


# FAN-1927 (AS.DetailDrawer): полная копия сфокусированной карточки Докачки —
# все затронутые player-facing оси и полный прогноз, без ellipsis.
static func shop_card_detail_text(stat_title: String, buy_cost: int, interpretation: String, influence: String, preview_lines_full: Array) -> String:
	var detail_lines := PackedStringArray(["%s +1 · цена %d зол." % [stat_title, buy_cost]])
	if interpretation != "":
		detail_lines.append(interpretation)
	if influence != "":
		detail_lines.append("Влияет на: %s." % influence)
	for preview_line in preview_lines_full:
		detail_lines.append(str(preview_line))
	return "\n".join(detail_lines)
