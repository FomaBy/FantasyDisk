extends "res://scripts/ui/screens/hud.gd"

# FAN-3824: модуль распределённого UI-класса — HUD-оверлеи и ресурсы: виньетка, урон-вспышка, меню-HUD, обновление HUD.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





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




func _create_threat_indicator_overlay(root: Control) -> void:
	# SCRUM-498: edge-стрелки к внеэкранным угрозам (босс/элитки/стреляющие дальнобои).
	var overlay := ThreatIndicatorOverlay.new()
	overlay.game = game
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)




# HUD пересоздаётся на каждом открытии/закрытии level-up в бою: шейдер виньетки
# компилируется один раз на сессию, а ссылка на виньетку хранится вместо
# рекурсивного find_child по HUD-слою на каждом кадре (_update_hud до дедупа).
static var _low_hp_vignette_shader: Shader = null
var _low_hp_vignette: ColorRect = null


func _create_low_hp_vignette(root: Control) -> void:
	var vignette := ColorRect.new()
	vignette.name = "LowHpVignetteOverlay"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color.WHITE
	vignette.modulate.a = 0.0
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fade animation should pause together with combat even though the HUD layer is ALWAYS.
	vignette.process_mode = Node.PROCESS_MODE_PAUSABLE
	if _low_hp_vignette_shader == null:
		_low_hp_vignette_shader = Shader.new()
		_low_hp_vignette_shader.code = """
shader_type canvas_item;

uniform vec3 vignette_color = vec3(0.72, 0.035, 0.035);
uniform float inner_radius = 0.50;
uniform float outer_radius = 0.92;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	centered_uv.x *= 1.7777778;
	float distance_from_center = length(centered_uv);
	float edge_alpha = smoothstep(inner_radius, outer_radius, distance_from_center);
	COLOR = vec4(vignette_color, edge_alpha * COLOR.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = _low_hp_vignette_shader
	vignette.material = material
	_low_hp_vignette = vignette
	vignette.set_meta("vignette_active", false)
	vignette.set_meta("vignette_target_alpha", 0.0)
	root.add_child(vignette)
	# Keep the long-lived warning behind the HUD cards; DamageFlashOverlay remains an intentional flash above them.
	root.move_child(vignette, 0)




func _update_low_hp_vignette(hp: float, max_hp: float) -> void:
	if game.hud_layer == null or not is_instance_valid(game.hud_layer):
		return
	if _low_hp_vignette == null or not is_instance_valid(_low_hp_vignette):
		_low_hp_vignette = game.hud_layer.find_child("LowHpVignetteOverlay", true, false) as ColorRect
	var vignette := _low_hp_vignette
	if vignette == null:
		return
	var feedback_enabled := true
	if game.get_tree() != null:
		feedback_enabled = bool(game.get_tree().root.get_meta("combat_feedback", true))
	var active := bool(vignette.get_meta("vignette_active", false))
	if not feedback_enabled:
		_set_low_hp_vignette_active(vignette, false, true)
		return
	var hp_ratio := hp / maxf(max_hp, 1.0)
	var target_active := active
	if hp_ratio < LOW_HP_VIGNETTE_ON_RATIO:
		target_active = true
	elif hp_ratio >= LOW_HP_VIGNETTE_OFF_RATIO:
		target_active = false
	if target_active == active:
		return
	_set_low_hp_vignette_active(vignette, target_active)




func _set_low_hp_vignette_active(vignette: ColorRect, active: bool, immediate := false) -> void:
	var target_alpha := LOW_HP_VIGNETTE_ALPHA if active else 0.0
	var current_target := float(vignette.get_meta("vignette_target_alpha", -1.0))
	if not immediate and bool(vignette.get_meta("vignette_active", false)) == active and is_equal_approx(current_target, target_alpha):
		return
	var existing_tween: Tween = vignette.get_meta("vignette_tween") if vignette.has_meta("vignette_tween") else null
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	vignette.set_meta("vignette_active", active)
	vignette.set_meta("vignette_target_alpha", target_alpha)
	if immediate:
		vignette.modulate.a = target_alpha
		return
	var duration := LOW_HP_VIGNETTE_FADE_IN if active else LOW_HP_VIGNETTE_FADE_OUT
	var tween := vignette.create_tween()
	tween.tween_property(vignette, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	vignette.set_meta("vignette_tween", tween)




func _on_player_damaged(amount: float) -> void:
	# SCRUM-502: аккумулируем полученный урон для экрана итогов. amount = входящий урон
	# (как эмитится player.gd:damaged), до индивидуальных мультипликаторов — приемлемо для сводки.
	game.add_run_damage_taken(amount)
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
	root.name = "MenuRunHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud_layer.add_child(root)
	_prepare_global_tooltips(root)
	# SCRUM-876: меню-экраны забега (карта/level-up/награды/магазины/события)
	# показывают ТОТ ЖЕ боевой ресурс-кластер SCRUM-806 (HP/XP/ULT + золото),
	# что и бой — один вид HUD во всех местах. Боевые-only элементы (таймер,
	# боссбар, ascension-пипсы) здесь не создаются; _layout_combat_hud null-safe.
	_create_resource_hud_panel(root, Vector2(20, 18))
	var shell_safe_rect := _active_gold_shell_content_rect()
	if shell_safe_rect.has_area():
		root.set_meta("gold_shell_content_rect", shell_safe_rect)
		var shell_inner_rect := _active_gold_shell_inner_rect()
		root.set_meta("gold_shell_inner_rect", shell_inner_rect)
		if _active_gold_shell_screen_id() == "shop":
			root.resized.connect(func() -> void:
				_layout_shop_gold_shell_resource_hud_current(root)
				call_deferred("_layout_shop_gold_shell_resource_hud_current", root)
			)
			_layout_shop_gold_shell_resource_hud_current(root)
			call_deferred("_layout_shop_gold_shell_resource_hud_current", root)
		else:
			root.resized.connect(func() -> void:
				_layout_gold_shell_menu_resource_hud_current(root)
				call_deferred("_layout_gold_shell_menu_resource_hud_current", root)
			)
			_layout_gold_shell_menu_resource_hud(root, shell_inner_rect)
			call_deferred("_layout_gold_shell_menu_resource_hud_current", root)
	else:
		root.resized.connect(func() -> void:
			_layout_combat_hud(root)
		)
		_layout_combat_hud(root)
		call_deferred("_layout_combat_hud", root)
	_update_hud()
	_update_level_up_button()
	if shell_safe_rect.has_area():
		_layout_level_up_button_in_gold_shell(root.size)
		root.resized.connect(func() -> void:
			_layout_level_up_button_in_gold_shell(root.size)
			_layout_level_up_button_in_gold_shell.call_deferred(root.size)
		)




func _layout_gold_shell_menu_resource_hud_current(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	# Derive from the current root size instead of frame metadata captured by a
	# different resized signal. This makes the deferred pass resize-safe in both
	# directions and keeps the HUD's acceptance metadata current.
	var inner_rect := _gold_shell_inner_rect_for_size(root.size)
	root.set_meta("gold_shell_inner_rect", inner_rect)
	_layout_gold_shell_menu_resource_hud(root, inner_rect)




func _layout_shop_gold_shell_resource_hud_current(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var metrics := _shop_gold_shell_metrics(root.size)
	var zone: Rect2 = metrics["hud_rect"]
	_layout_menu_resource_hud(root, Vector2.ZERO)
	var resource := root.find_child("RunResourceHud", true, false) as PanelContainer
	if resource == null:
		return
	resource.scale = Vector2.ONE
	resource.pivot_offset = Vector2.ZERO
	var source_size := resource.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = resource.custom_minimum_size
	var fit_scale := minf(1.0, minf(zone.size.x / maxf(source_size.x, 1.0), zone.size.y / maxf(source_size.y, 1.0)))
	resource.scale = Vector2(fit_scale, fit_scale)
	resource.position = Vector2(zone.position.x, zone.position.y + roundf((zone.size.y - source_size.y * fit_scale) * 0.5))
	resource.set_meta("scrum993_zone_rect", zone)
	resource.set_meta("gold_shell_inner_rect", metrics["inner_rect"])




func _active_gold_shell_content_rect() -> Rect2:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return Rect2()
	for child in game.ui_layer.get_children():
		if child is Control and child.has_meta("gold_shell_content_rect"):
			return child.get_meta("gold_shell_content_rect", Rect2()) as Rect2
	return Rect2()




func _active_gold_shell_screen_id() -> String:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return ""
	for child in game.ui_layer.get_children():
		if child is Control and child.has_meta("gold_shell_screen_id"):
			return str(child.get_meta("gold_shell_screen_id", ""))
	return ""




func _active_gold_shell_inner_rect() -> Rect2:
	if game.ui_layer == null or not is_instance_valid(game.ui_layer):
		return Rect2()
	for child in game.ui_layer.get_children():
		if child is Control and child.has_meta("gold_shell_inner_rect"):
			return child.get_meta("gold_shell_inner_rect", Rect2()) as Rect2
	for child in game.ui_layer.find_children("*", "Control", true, false):
		if child is Control and child.has_meta("gold_shell_inner_rect"):
			return child.get_meta("gold_shell_inner_rect", Rect2()) as Rect2
	return Rect2()




func _create_resource_hud_panel(parent: Control, position: Vector2) -> void:
	# SCRUM-806 боевой HUD v2 (слим-бары с пиксель-иконками); с SCRUM-876 —
	# единственный вид ресурс-панели: и бой, и все меню-экраны забега.
	game._last_hud_snapshot.clear()
	var panel := PanelContainer.new()
	panel.name = "RunResourceHud"
	panel.position = position
	panel.custom_minimum_size = HUD_V2_CLUSTER_2K.size
	panel.add_theme_stylebox_override("panel", _hud_v2_cluster_style(HUD_V2_CLUSTER_2K.size))
	parent.add_child(panel)

	var content := Control.new()
	content.name = "RunResourceHudContent"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_build_hud_v2_cluster(content)




func _build_hud_v2_cluster(content: Control) -> void:
	game.health_bar = _add_hud_v2_bar(content, "hp", "HP", Color(0.92, 0.08, 0.08, 1.0))
	game.xp_bar = _add_hud_v2_bar(content, "xp", "XP", Color(0.25, 0.78, 1.0, 1.0))
	game.ultimate_bar = _add_hud_v2_bar(content, "ultimate_multiplier", "ULT", Color(0.95, 0.68, 1.0, 1.0))

	var money_icon := _make_hud_v2_icon("money")
	money_icon.name = "UIIcon_money"
	content.add_child(money_icon)

	game.money_label = Label.new()
	game.money_label.name = "HudMoneyLabel"
	game.money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	game.money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.money_label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_HUD, 18))
	game.money_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 1.0))
	game.money_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03, 1.0))
	game.money_label.add_theme_constant_override("outline_size", 3)
	game.money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(game.money_label)




func _make_hud_v2_icon(icon_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = game._cached_texture(str(HUD_V2_ICON_PATHS.get(icon_id, HUD_V2_ICON_PATHS["hp"])))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Пиксель-арт PixelLab: nearest сохраняет хрусткие пиксели при даунскейле.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon




func _add_hud_v2_bar(parent: Control, icon_id: String, tag: String, fill_fallback: Color) -> ProgressBar:
	var icon := _make_hud_v2_icon(icon_id)
	icon.name = "UIIcon_%s" % icon_id
	parent.add_child(icon)

	var track := PanelContainer.new()
	track.name = "Hud%sTrack" % tag
	track.mouse_filter = Control.MOUSE_FILTER_PASS
	track.add_theme_stylebox_override("panel", _hud_v2_bar_track_style())
	parent.add_child(track)

	var bar := ProgressBar.new()
	bar.name = "Hud%sBar" % tag
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	# PanelContainer не гарантирует растяжку Range-ребёнка — фиксируем флагами,
	# высоту дожимает _layout_hud_v2_cluster через custom_minimum_size.
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.05, 0.06, 0.08, 0.85)))
	bar.add_theme_stylebox_override("fill", _hud_v2_bar_fill_style(icon_id, fill_fallback))
	track.add_child(bar)

	# Лейбл — сиблинг трека (не ребёнок бара): min-height шрифта на 4K выше слим-бара,
	# внутри бара он вылезал бы за родителя (text-overflow инвариант матрицы).
	# Позиционируется _layout_hud_v2_cluster по зоне бара с вертикальным центрированием.
	var label := Label.new()
	label.name = "Hud%sLabel" % tag
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_HUD, 13))
	label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.86, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

	if icon_id == "hp":
		game.health_label = label
	elif icon_id == "xp":
		game.xp_label = label
	elif icon_id == "ultimate_multiplier":
		game.ultimate_label = label
	return bar




func _compact_character_stat_entries(limit := 4) -> Array:
	var entries: Array = []
	var character_id := str(game.selected_character_id)
	if game.current_player != null and is_instance_valid(game.current_player):
		character_id = str(game.current_player.get("character_id"))
		var sections: Dictionary = StatFormulas.stat_sections_for_player(game.current_player)
		entries = sections.get("base", [])
	else:
		var stats: Dictionary = game.PROGRESSION_DATA.base_stats(character_id)
		for stat_id in game.PROGRESSION_DATA.STAT_NAMES.keys():
			entries.append({
				"id": str(stat_id),
				"name_ru": str(game.PROGRESSION_DATA.STAT_NAMES[stat_id]),
				"value": float(stats.get(stat_id, 0.0)),
				"value_text": "%.0f" % float(stats.get(stat_id, 0.0)),
			})
	var priority_ids: Array = game.PROGRESSION_DATA.attribute_priorities(character_id)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ai: int = priority_ids.find(str(a.get("id", "")))
		var bi: int = priority_ids.find(str(b.get("id", "")))
		if ai == -1:
			ai = 999
		if bi == -1:
			bi = 999
		if ai == bi:
			return str(a.get("name_ru", "")) < str(b.get("name_ru", ""))
		return ai < bi
	)
	return entries.slice(0, mini(limit, entries.size()))




func _make_character_stat_chip(entry: Dictionary) -> Control:
	var stat_id := str(entry.get("id", ""))
	var chip := PanelContainer.new()
	chip.name = "CharacterStatChip_%s" % stat_id
	chip.custom_minimum_size = Vector2(132, 38)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = "%s: %s" % [str(entry.get("name_ru", stat_id)), _compact_stat_value_text(entry)]
	chip.add_theme_stylebox_override("panel", _hud_card_style(stat_id))

	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 5)
	chip.add_child(line)

	line.add_child(game.UIIconRegistry.make_icon(stat_id, Vector2(22, 22)))

	var value := Label.new()
	value.name = "CharacterStatValue_%s" % stat_id
	value.text = _compact_stat_value_text(entry)
	value.clip_text = true
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_VALUE, 15))
	value.add_theme_color_override("font_color", _hud_stat_value_color(entry))
	line.add_child(value)
	return chip




func _compact_stat_value_text(entry: Dictionary) -> String:
	return str(entry.get("value_text", "N/A")).replace(" / sec", "/s").replace(" units", "")




func _hud_stat_value_color(entry: Dictionary) -> Color:
	var raw_value: Variant = entry.get("value", null)
	if raw_value == null:
		return Color(0.91, 0.86, 0.65, 1.0)
	var value := float(raw_value)
	return Color(0.44, 0.95, 0.65, 1.0) if value >= 8.0 else Color(0.91, 0.86, 0.65, 1.0)




func _hud_v2_cluster_style(display_size := Vector2(640.0, 122.0)) -> StyleBox:
	# SCRUM-806: лёгкая кожаная подложка с тонкой латунной линией (768×256, OpenAI),
	# полупрозрачная, чтобы кластер не выглядел тяжёлой плитой поверх арены.
	var texture_margins := _scaled_frame_margins_xy(Vector2(768.0, 256.0), display_size, Vector4(26, 22, 26, 22))
	return _global_texture_style(HUD_V2_CLUSTER_BG_PATH, texture_margins, Color(1.0, 1.0, 1.0, 0.93), Vector4.ZERO, true)




func _hud_v2_bar_track_style(display_size := Vector2(516.0, 32.0), content_inset := 3.0) -> StyleBox:
	# SCRUM-806: слим-жёлоб с тонкой латунной окантовкой (512×32) под лайн-бар.
	var texture_margins := _scaled_frame_margins_xy(Vector2(512.0, 32.0), display_size, Vector4(10, 5, 10, 5))
	var inset := maxf(2.0, content_inset)
	return _global_texture_style(HUD_V2_BAR_TRACK_PATH, texture_margins, Color.WHITE, Vector4(inset, inset, inset, inset), true)




func _hud_v2_bar_fill_style(icon_id: String, fallback_color: Color) -> StyleBox:
	# SCRUM-806: филл слим-бара — прежние gradient-текстуры, но с полной вертикальной
	# растяжкой (margins только по X), иначе на треке высотой 10-20px поля съедают центр.
	var path := str(COMBAT_HUD_BAR_FILL_PATHS.get(icon_id, ""))
	if path != "" and ResourceLoader.exists(path):
		return _global_texture_style(path, Vector4(6, 0, 6, 0), Color.WHITE, Vector4.ZERO)
	return _bar_style(fallback_color)




func _character_stats_hud_style() -> StyleBox:
	return _global_texture_style(MINIMAL_FIELD_PATH, Vector4(10, 10, 10, 10), Color(1.0, 1.0, 1.0, 0.95), Vector4(16, 12, 16, 12), true)




func _hud_card_style(icon_id := "hp", display_size := Vector2.ZERO) -> StyleBox:
	var path := str(COMBAT_HUD_CARD_PATHS.get(icon_id, COMBAT_HUD_CARD_PATHS["hp"]))
	var resolved_size := display_size
	if resolved_size == Vector2.ZERO:
		resolved_size = Vector2(104.0, 48.0) if icon_id == "money" else Vector2(132.0, 48.0)
	var texture_margins := _scaled_frame_margins_xy(Vector2(616.0, 286.0), resolved_size, COMBAT_HUD_CARD_MARGINS)
	var content_margins := _scaled_frame_margins_xy(Vector2(616.0, 286.0), resolved_size, COMBAT_HUD_CARD_CONTENT)
	return _global_texture_style(path, texture_margins, Color.WHITE, content_margins, true)




func _run_resource_values() -> Dictionary:
	var snapshot := {}
	if typeof(game.run_player_snapshot) == TYPE_DICTIONARY:
		snapshot = game.run_player_snapshot
	var hp = _number_value(snapshot.get("health", snapshot.get("max_health", 0.0)), 0.0)
	var max_hp = _number_value(snapshot.get("max_health", 0.0), 0.0)
	var xp = _int_value(snapshot.get("xp", 0), 0)
	var xp_to_next = _int_value(snapshot.get("xp_to_next", 5), 5)
	var money := _run_money()
	var ultimate_charge := 0.0
	var ultimate_max := 100.0
	if game.current_player != null and is_instance_valid(game.current_player):
		hp = _number_value(game.current_player.get("health"), hp)
		max_hp = _number_value(game.current_player.get("max_health"), max_hp)
		xp = _int_value(game.current_player.get("xp"), xp)
		xp_to_next = _int_value(game.current_player.get("xp_to_next"), xp_to_next)
		money = _int_value(game.current_player.get("money"), money)
		ultimate_charge = _number_value(game.current_player.get("ultimate_charge"), ultimate_charge)
		ultimate_max = _number_value(game.current_player.get("ultimate_max_charge"), ultimate_max)
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
		return _int_value(game.current_player.get("money"), 0)
	if typeof(game.run_player_snapshot) == TYPE_DICTIONARY:
		return _int_value(game.run_player_snapshot.get("money", 0), 0)
	return 0




func _number_value(value, fallback: float = 0.0) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback




func _int_value(value, fallback: int = 0) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback




func _update_hud() -> void:
	if game.health_bar == null or game.health_label == null:
		return

	# SCRUM-874: боссбар обновляется ДО дедуп-гарда _last_hud_snapshot ниже —
	# HP цели меняется независимо от ресурсов игрока.
	_update_boss_hud_bar()

	var values: Dictionary = _run_resource_values()
	var max_hp: float = max(float(values["max_hp"]), 1.0)
	var hp: float = clamp(float(values["hp"]), 0.0, max_hp)
	_update_low_hp_vignette(hp, max_hp)
	var xp_to_next: int = max(int(values["xp_to_next"]), 1)
	var xp: int = clamp(int(values["xp"]), 0, xp_to_next)
	var money: int = int(values["money"])
	var ultimate_max: float = maxf(float(values.get("ultimate_max", 100.0)), 1.0)
	var ultimate_charge: float = clampf(float(values.get("ultimate_charge", 0.0)), 0.0, ultimate_max)
	var timer_seconds := -1
	# SCRUM-785: таймер показываем во всех боях, включая боссовый (5-минутный kill-timer).
	if game.combat_active:
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
		var content_margins: Vector4 = panel.get_meta("scrum666_content_margins", _scrum666_content_margins(HUD_V2_TIMER_2K, HUD_V2_TIMER_ZONE_2K, _scrum666_hud_scale_for_size(panel.get_viewport_rect().size))) as Vector4
		panel.add_theme_stylebox_override("panel", _timer_panel_style(alarm, panel.size, content_margins))
	if alarm:
		var tween: Tween = game.timer_label.create_tween()
		tween.set_loops(timer_seconds)
		tween.tween_property(game.timer_label, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(game.timer_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUAD)
		game.timer_label.pivot_offset = game.timer_label.size * 0.5
