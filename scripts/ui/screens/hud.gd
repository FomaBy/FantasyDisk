extends "res://scripts/ui/screens/battle_prayer.gd"

# FAN-3824: модуль распределённого UI-класса — боевой и меню-HUD: панели, таймер, босс-бар, артефакты.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





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
	_prepare_global_tooltips(root)

	_create_resource_hud_panel(root, Vector2(20, 18))
	_create_combat_timer_panel(root)
	_create_boss_health_panel(root)
	_create_damage_flash_overlay(root)
	_create_low_hp_vignette(root)
	_create_threat_indicator_overlay(root)
	root.resized.connect(func() -> void:
		_layout_combat_hud(root)
	)
	_layout_combat_hud(root)
	call_deferred("_layout_combat_hud", root)
	UltimateHudRuntimeAdapter.attach(root, game)
	_update_level_up_button()
	_update_hud()




func _create_combat_timer_panel(root: Control) -> void:
	# SCRUM-806 (reopen): уровень возвышения — ряд пиксель-эмблем по числу уровня,
	# без плашки-рамки и цифры: считывается как «звёзды сложности», тултип сохранён.
	if game.selected_ascension_level > 0:
		var asc_row := HBoxContainer.new()
		asc_row.name = "AscensionHudRow"
		asc_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		asc_row.mouse_filter = Control.MOUSE_FILTER_STOP
		asc_row.tooltip_text = "Возвышение %d\n%s" % [game.selected_ascension_level, "\n".join(game.PROGRESSION_DATA.ascension_modifier_lines(game.selected_ascension_level))]
		root.add_child(asc_row)
		var pip_count := clampi(game.selected_ascension_level, 0, game.META_PROGRESSION.MAX_ASCENSION_LEVEL)  # SCRUM-622: клампить по динамическому капу (5), не хардкод 10
		for pip_index in range(pip_count):
			var pip := _make_hud_v2_icon("ascension")
			pip.name = "AscensionHudPip%d" % pip_index
			pip.custom_minimum_size = Vector2(44, 44)
			asc_row.add_child(pip)

	# SCRUM-799: таймер показываем во всех боях, включая боссовый/элитный
	# (5-минутный kill-timer из SCRUM-785). Ранний выход по boss_combat_active снят —
	# панель и timer_label создаются одинаково для обычного, элитного и боссового боя,
	# иначе игрок не видит обратный отсчёт и внезапно проигрывает на 5:00.
	var panel := PanelContainer.new()
	panel.name = "CombatTimerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(0, 14)
	panel.custom_minimum_size = Vector2(192, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _timer_panel_style(false, HUD_V2_TIMER_2K.size, _scrum666_content_margins(HUD_V2_TIMER_2K, HUD_V2_TIMER_ZONE_2K, 1.0)))
	root.add_child(panel)

	var label := Label.new()
	label.name = "CombatTimerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_HUD,
		_readable_font_size(SemanticTypography.ROLE_HUD, 26),
		SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
		SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
	))
	label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	panel.add_child(label)
	game.timer_label = label

	# SCRUM-806: пиксель-песочные часы на левом краю плашки таймера.
	var timer_icon := _make_hud_v2_icon("timer")
	timer_icon.name = "CombatTimerIcon"
	timer_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timer_icon.custom_minimum_size = Vector2(28, 28)
	root.add_child(timer_icon)




func _create_boss_health_panel(root: Control) -> void:
	# SCRUM-874: общий HUD-боссбар цели узла (акт-босс/элитка) — крупная полоса HP
	# с именем цели по центру верха экрана. Создаётся скрытым; видимость и значения
	# ведёт _update_boss_hud_bar() по game.boss_hud_target (ставит combat_director
	# в _spawn_boss/_spawn_elite_enemy, снимает _end_combat). Плавающая полоса над
	# спрайтом у таких целей не создаётся (enemy._uses_hud_boss_bar).
	var name_label := Label.new()
	name_label.name = "BossHudNameLabel"
	name_label.visible = false
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_HUD,
		_readable_font_size(SemanticTypography.ROLE_HUD, 24),
		SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
		SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
	))
	name_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	name_label.add_theme_constant_override("outline_size", 4)
	root.add_child(name_label)

	var track := PanelContainer.new()
	track.name = "BossHudTrack"
	track.visible = false
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style())
	root.add_child(track)

	var bar := ProgressBar.new()
	bar.name = "BossHudBar"
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.05, 0.06, 0.08, 0.85)))
	bar.add_theme_stylebox_override("fill", _hud_v2_bar_fill_style("hp", Color(0.86, 0.20, 0.16, 0.95)))
	track.add_child(bar)

	game.boss_hud_name_label = name_label
	game.boss_hud_bar = bar




func _update_boss_hud_bar() -> void:
	var bar := game.boss_hud_bar as ProgressBar
	var name_label := game.boss_hud_name_label as Label
	if bar == null or not is_instance_valid(bar) or name_label == null or not is_instance_valid(name_label):
		return
	var track := bar.get_parent() as Control
	# ВАЖНО: не кастовать boss_hud_target до is_instance_valid — после free цели
	# `as Node2D` на freed-объекте даёт script error «Trying to cast a freed object».
	if game.boss_hud_target == null or not is_instance_valid(game.boss_hud_target):
		game.boss_hud_target = null
		if track != null:
			track.visible = false
		name_label.visible = false
		return
	var target: Node2D = game.boss_hud_target
	if not target.is_inside_tree():
		if track != null:
			track.visible = false
		name_label.visible = false
		return
	var max_hp := maxf(_number_value(target.get("max_health"), 1.0), 1.0)
	# Смерть цели: hp клампится в 0 — полоса доводится в ноль на время
	# death-анимации (SCRUM-865, ~2s), затем узел освобождается и панель гаснет.
	var hp := clampf(_number_value(target.get("health"), 0.0), 0.0, max_hp)
	bar.max_value = max_hp
	bar.value = hp
	var display_name = target.get("boss_display_name")
	var target_name := str(display_name) if display_name != null else ""
	if target_name == "":
		target_name = str(target.get("enemy_type_name"))
	name_label.text = target_name
	if track != null:
		track.visible = true
	name_label.visible = true




func _timer_panel_style(alarm: bool, display_size := Vector2(264.0, 92.0), content_margins := Vector4.ZERO) -> StyleBox:
	# SCRUM-806 (reopen): жёлтая рамка chud_timer убрана — таймер на той же кожаной
	# подложке, что левый кластер (единый стиль); alarm подкрашивает кожу в алый.
	var tint := Color(1.45, 0.58, 0.50, 0.96) if alarm else Color(1.0, 1.0, 1.0, 0.93)
	var texture_margins := _scaled_frame_margins_xy(Vector2(768.0, 256.0), display_size, Vector4(26, 22, 26, 22))
	var style := _global_texture_style(HUD_V2_CLUSTER_BG_PATH, texture_margins, tint, Vector4.ZERO, true)
	if content_margins != Vector4.ZERO:
		_apply_stylebox_content_margins(style, content_margins)
	return style




func _scrum666_hud_scale_for_size(viewport_size: Vector2) -> float:
	var scale_x := viewport_size.x / COMBAT_BLOCK_DESIGN_BASE_2K.x
	var scale_y := viewport_size.y / COMBAT_BLOCK_DESIGN_BASE_2K.y
	var scale := minf(scale_x, scale_y)
	if scale <= 0.0:
		return 0.5
	return scale




func _scrum666_hud_scale(root: Control) -> float:
	var viewport_size := root.get_viewport_rect().size
	if root.size.x > 0.0 and root.size.y > 0.0:
		viewport_size = root.size
	return _scrum666_hud_scale_for_size(viewport_size)




func _scrum666_scaled_rect(base_rect: Rect2, scale: float) -> Rect2:
	return Rect2(
		Vector2(roundf(base_rect.position.x * scale), roundf(base_rect.position.y * scale)),
		Vector2(roundf(base_rect.size.x * scale), roundf(base_rect.size.y * scale))
	)




func _scrum666_content_margins(frame_rect: Rect2, zone_rect: Rect2, scale: float) -> Vector4:
	return Vector4(
		roundf((zone_rect.position.x - frame_rect.position.x) * scale),
		roundf((zone_rect.position.y - frame_rect.position.y) * scale),
		roundf((frame_rect.position.x + frame_rect.size.x - zone_rect.position.x - zone_rect.size.x) * scale),
		roundf((frame_rect.position.y + frame_rect.size.y - zone_rect.position.y - zone_rect.size.y) * scale)
	)




func _apply_stylebox_content_margins(style: StyleBox, margins: Vector4) -> void:
	if style == null:
		return
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w




func _apply_chud_rect(control: Control, rect: Rect2, meta_key := "") -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.custom_minimum_size = rect.size
	control.size = rect.size
	if meta_key != "":
		control.set_meta(meta_key, rect)




# SCRUM-876: разложить боевой ресурс-кластер на меню-экране с кастомной точкой
# привязки (карта держит его ПОД своим заголовком). Размер/содержимое — тот же
# скейл и лейаут, что в бою.
func _layout_menu_resource_hud(root: Control, origin: Vector2) -> void:
	if root == null or not is_instance_valid(root):
		return
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource == null:
		return
	var scale := _scrum666_hud_scale(root)
	# Внутренние зоны кластера (_hud_v2_place_in_panel) заданы в абсолютных
	# боевых 2K-координатах и вычитают позицию панели — раскладываем содержимое
	# относительно БОЕВОГО ректа, а саму панель ставим на кастомный origin.
	var combat_rect := _scrum666_scaled_rect(HUD_V2_CLUSTER_2K, scale)
	_apply_chud_rect(resource, Rect2(origin, combat_rect.size), "scrum666_frame_rect")
	resource.add_theme_stylebox_override("panel", _hud_v2_cluster_style(combat_rect.size))
	_layout_hud_v2_cluster(resource, combat_rect, scale)




func _layout_gold_shell_menu_resource_hud(root: Control, inner_rect: Rect2) -> void:
	if root == null or not is_instance_valid(root) or not inner_rect.has_area():
		return
	# Rebuild the canonical unscaled HUD for this viewport first, then fit the
	# entire composition uniformly into the authored header-left zone. Resetting
	# scale before every pass keeps 2K -> 720p -> 2K resize idempotent.
	_layout_menu_resource_hud(root, Vector2.ZERO)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource == null:
		return
	resource.scale = Vector2.ONE
	resource.pivot_offset = Vector2.ZERO
	var source_size := resource.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = resource.custom_minimum_size
	var header_height := 72.0 if root.size.y < 900.0 else (104.0 if root.size.y >= 1200.0 else 88.0)
	var header_rect := Rect2(
		inner_rect.position,
		Vector2(maxf(1.0, inner_rect.size.x - 96.0), minf(header_height, inner_rect.size.y))
	)
	var fit_scale := minf(1.0, minf(header_rect.size.x / source_size.x, header_rect.size.y / source_size.y))
	resource.scale = Vector2(fit_scale, fit_scale)
	resource.position = Vector2(
		header_rect.position.x,
		header_rect.position.y
	)
	resource.set_meta("gold_shell_inner_rect", inner_rect)
	resource.set_meta("scrum1036_zone_rect", header_rect)




func _layout_combat_hud(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var scale := _scrum666_hud_scale(root)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource != null:
		var resource_rect := _scrum666_scaled_rect(HUD_V2_CLUSTER_2K, scale)
		_apply_chud_rect(resource, resource_rect, "scrum666_frame_rect")
		resource.add_theme_stylebox_override("panel", _hud_v2_cluster_style(resource_rect.size))
		_layout_hud_v2_cluster(resource, resource_rect, scale)

	var timer_panel := root.find_child("CombatTimerPanel", true, false) as PanelContainer
	if timer_panel != null:
		var timer_rect := _scrum666_scaled_rect(HUD_V2_TIMER_2K, scale)
		var timer_content := _scrum666_content_margins(HUD_V2_TIMER_2K, HUD_V2_TIMER_ZONE_2K, scale)
		_apply_chud_rect(timer_panel, timer_rect, "scrum666_frame_rect")
		timer_panel.set_meta("scrum666_content_margins", timer_content)
		timer_panel.set_meta("scrum666_content_zone", _scrum666_scaled_rect(HUD_V2_TIMER_ZONE_2K, scale))
		timer_panel.add_theme_stylebox_override("panel", _timer_panel_style(bool(game.timer_label != null and game.timer_label.get_meta("alarm_active", false)), timer_rect.size, timer_content))
		if game.timer_label != null:
			game.timer_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
				SemanticTypography.ROLE_HUD,
				SemanticTypography.resolve_scaled_compat( SemanticTypography.ROLE_HUD, 34.0, scale, 16, 96 ),
				SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
				SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
			))
		var timer_icon := root.find_child("CombatTimerIcon", true, false) as TextureRect
		if timer_icon != null:
			_apply_chud_rect(timer_icon, _scrum666_scaled_rect(HUD_V2_TIMER_ICON_2K, scale))

	# SCRUM-874: HUD-боссбар — центр верха, ниже кластера/таймера.
	var boss_track := root.find_child("BossHudTrack", true, false) as PanelContainer
	if boss_track != null:
		var boss_rect := _scrum666_scaled_rect(HUD_V2_BOSS_BAR_2K, scale)
		_apply_chud_rect(boss_track, boss_rect, "scrum666_frame_rect")
		var boss_inset := maxf(2.0, roundf(4.0 * scale))
		boss_track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style(boss_rect.size, boss_inset))
		var boss_bar := boss_track.find_child("BossHudBar", true, false) as ProgressBar
		if boss_bar != null:
			boss_bar.custom_minimum_size = Vector2(0.0, maxf(4.0, boss_rect.size.y - boss_inset * 2.0))
		var boss_name := root.find_child("BossHudNameLabel", true, false) as Label
		if boss_name != null:
			_apply_chud_rect(boss_name, _scrum666_scaled_rect(HUD_V2_BOSS_NAME_2K, scale))
			boss_name.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
				SemanticTypography.ROLE_HUD,
				SemanticTypography.resolve_scaled_compat( SemanticTypography.ROLE_HUD, 32.0, scale, 16, 96 ),
				SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
				SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
			))

	var asc_row := root.find_child("AscensionHudRow", true, false) as HBoxContainer
	if asc_row != null:
		var pip_size := maxf(18.0, roundf(HUD_V2_ASCENSION_PIP_2K * scale))
		var pip_gap := maxf(2.0, roundf(HUD_V2_ASCENSION_GAP_2K * scale))
		asc_row.add_theme_constant_override("separation", int(pip_gap))
		var pip_count := asc_row.get_child_count()
		for pip in asc_row.get_children():
			var pip_icon := pip as TextureRect
			if pip_icon != null:
				pip_icon.custom_minimum_size = Vector2(pip_size, pip_size)
		var row_size := Vector2(pip_count * pip_size + maxf(0.0, pip_count - 1.0) * pip_gap, pip_size)
		var row_rect := Rect2(Vector2(roundf(HUD_V2_ASCENSION_RIGHT_2K * scale) - row_size.x, roundf(HUD_V2_ASCENSION_TOP_2K * scale)), row_size)
		_apply_chud_rect(asc_row, row_rect, "scrum666_frame_rect")
		asc_row.set_meta("scrum666_content_zone", row_rect)




func _layout_hud_v2_cluster(resource: PanelContainer, panel_rect: Rect2, scale: float) -> void:
	# SCRUM-806: раскладка слим-кластера — все дети RunResourceHudContent позиционируются
	# по @2K-зонам, переведённым в координаты панели (content = full-rect без margins).
	var icon_zones := {
		"UIIcon_hp": HUD_V2_HP_ICON_2K,
		"UIIcon_xp": HUD_V2_XP_ICON_2K,
		"UIIcon_ultimate_multiplier": HUD_V2_ULT_ICON_2K,
		"UIIcon_money": HUD_V2_MONEY_ICON_2K,
	}
	for icon_name in icon_zones.keys():
		var icon := resource.find_child(str(icon_name), true, false) as TextureRect
		if icon != null:
			_hud_v2_place_in_panel(icon, icon_zones[icon_name], panel_rect, scale)
	var track_zones := {
		"HudHPTrack": HUD_V2_HP_BAR_2K,
		"HudXPTrack": HUD_V2_XP_BAR_2K,
		"HudULTTrack": HUD_V2_ULT_BAR_2K,
	}
	for track_name in track_zones.keys():
		var track := resource.find_child(str(track_name), true, false) as PanelContainer
		if track == null:
			continue
		var zone: Rect2 = track_zones[track_name]
		var track_size := _scrum666_scaled_rect(zone, scale).size
		var inset := maxf(2.0, roundf(4.0 * scale))
		var bar := track.find_child(track_name.replace("Track", "Bar"), true, false) as ProgressBar
		# SCRUM-1039: shrink the child minimum before assigning the smaller parent
		# rect. PanelContainer otherwise retains the previous 2K child minimum for
		# one sort pass and physically overlaps sibling tracks after 2K -> 720p.
		if bar != null:
			bar.custom_minimum_size = Vector2(0.0, maxf(4.0, track_size.y - inset * 2.0))
		track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style(track_size, inset))
		_hud_v2_place_in_panel(track, zone, panel_rect, scale)
	var money_label := resource.find_child("HudMoneyLabel", true, false) as Label
	if money_label != null:
		_hud_v2_place_in_panel(money_label, HUD_V2_MONEY_LABEL_2K, panel_rect, scale)
		money_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_HUD,
			SemanticTypography.resolve_scaled_compat( SemanticTypography.ROLE_HUD, 24.0, scale, 14, 96 ),
			SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
			SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
		))
	var bar_labels := {
		"HudHPLabel": [HUD_V2_HP_BAR_2K, 20.0],
		"HudXPLabel": [HUD_V2_XP_BAR_2K, 17.0],
		"HudULTLabel": [HUD_V2_ULT_BAR_2K, 17.0],
	}
	for label_name in bar_labels.keys():
		var label := resource.find_child(str(label_name), true, false) as Label
		if label == null:
			continue
		label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
			SemanticTypography.ROLE_HUD,
			SemanticTypography.resolve_scaled_compat( SemanticTypography.ROLE_HUD, float(bar_labels[label_name][1]), scale, 12, 96 ),
			SemanticTypography.role_min(SemanticTypography.ROLE_HUD),
			SemanticTypography.role_max(SemanticTypography.ROLE_HUD)
		))
		label.add_theme_constant_override("outline_size", maxi(2, int(roundf(3.0 * scale))))
		_hud_v2_place_in_panel(label, bar_labels[label_name][0], panel_rect, scale)
		# Шрифт может требовать больше высоты, чем слим-бар: расширяем рект лейбла
		# симметрично вокруг зоны бара, текст остаётся визуально по центру бара.
		var min_h := label.get_combined_minimum_size().y
		if min_h > label.size.y:
			label.position.y -= roundf((min_h - label.size.y) * 0.5)
			label.size.y = min_h
			label.custom_minimum_size.y = 0.0




func _hud_v2_place_in_panel(node: Control, zone_2k: Rect2, panel_rect: Rect2, scale: float) -> void:
	var zone := _scrum666_scaled_rect(zone_2k, scale)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = zone.position - panel_rect.position
	node.custom_minimum_size = zone.size
	node.size = zone.size
	node.set_meta("scrum666_content_zone", zone)




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




func _artifact_icon_path(artifact_id: String) -> String:
	var path := "%sartifact_%s.png" % [ARTIFACT_ICON_DIR, artifact_id]
	if artifact_id != "" and ResourceLoader.exists(path):
		return path
	# CodexData appends SHOP_ITEMS to the artifact section. Their canonical icons
	# use the existing shop/shop_<id>.png family, not artifact_<id>.png.
	var shop_path := "%sshop_%s.png" % [SHOP_ICON_DIR, artifact_id]
	if artifact_id.begins_with("shop_") and ResourceLoader.exists(shop_path):
		return shop_path
	return ""




func _artifact_icon_texture(artifact_id: String) -> Texture2D:
	var path := _artifact_icon_path(artifact_id)
	if not path.is_empty():
		return game._cached_texture(path)
	return game.UIIconRegistry.texture_for("artifact")




func _artifact_affinity_note(definition: Dictionary) -> Dictionary:
	# SCRUM-963: классовая пометка вместо старой «Интерпретации» — после гейта
	# SCRUM-961 классовый артефакт больше не «перетолковывается» чужим классом,
	# а честно подписывается своим классом и порогом Возвышения. Пометка есть у
	# ЛЮБОГО классового артефакта (свой класс — знак эксклюзива, cross-class
	# выпадение «Украденного герба» — честное имя чужого класса).
	var affinity: Array = definition.get("class_affinity", definition.get("classes", []))
	if affinity.is_empty():
		return {}
	var class_names := PackedStringArray()
	for class_id in affinity:
		class_names.append(str(CLASS_RU.get(str(class_id), class_id)))
	var text := "Класс: %s" % ", ".join(class_names)
	var required := int(definition.get("requires_ascension", 0))
	if required > 0:
		text += " · Возвышение %d" % required
	return {"text": text, "color": Color(0.55, 0.92, 1.0, 1.0)}




func _artifact_affinity_suffix(definition: Dictionary) -> String:
	var note := _artifact_affinity_note(definition)
	if note.is_empty():
		return ""
	return "
[%s]" % note["text"]




# Подпись редкости по конкретному тиру (0/неизвестный → пусто: старые записи
# player.artifacts без тира редкость не показывают).
func _tier_label(tier: int) -> String:
	return str(TIER_LABELS.get(tier, ""))




func _artifact_tier_text(definition: Dictionary) -> String:
	return str(TIER_LABELS.get(int(definition.get("tier", 1)), TIER_LABELS[1]))




func _artifact_tier_color(definition: Dictionary) -> Color:
	return TIER_COLORS.get(int(definition.get("tier", 1)), TIER_COLORS[1])




func _artifact_tooltip(artifact: Dictionary) -> String:
	var artifact_id := str(artifact.get("id", ""))
	var title := str(artifact.get("title", ""))
	var definition: Dictionary = game.PROGRESSION_DATA.artifact_definition(artifact_id)
	var description := str(definition.get("description", ""))
	if description == "":
		return title
	# SCRUM-963: редкость полученного артефакта — РОЛЛНУТЫЙ тир записи забега
	# (player.artifacts[].tier, пишется с SCRUM-960); фоллбек — корневой тир
	# определения (старые сейвы без тира).
	var rolled_tier := int(artifact.get("tier", 0))
	var tier_text := _tier_label(rolled_tier) if rolled_tier > 0 else _artifact_tier_text(definition)
	return "%s (%s)
%s%s" % [title, tier_text, description, _artifact_affinity_suffix(definition)]
