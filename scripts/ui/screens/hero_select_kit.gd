extends "res://scripts/ui/screens/main_menu.gd"

# FAN-3824: модуль распределённого UI-класса — хелперы экрана выбора героя (hs4-стили, превью портретов).
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





func _hs4_scaled_rect(zone: Rect2, canvas_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(round(zone.position.x * canvas_size.x), round(zone.position.y * canvas_size.y)),
		Vector2(round(zone.size.x * canvas_size.x), round(zone.size.y * canvas_size.y))
	)




func _hs4_pixellab_scale(viewport_size: Vector2) -> float:
	return minf(viewport_size.x / HS4_DESIGN_BASE_2K.x, viewport_size.y / HS4_DESIGN_BASE_2K.y)




func _hs4_pixellab_origin(viewport_size: Vector2, scale: float) -> Vector2:
	return Vector2(
		roundf((viewport_size.x - HS4_DESIGN_BASE_2K.x * scale) * 0.5),
		roundf((viewport_size.y - HS4_DESIGN_BASE_2K.y * scale) * 0.5)
	)




func _hs4_pixellab_content_margins(slot: String, display_size: Vector2) -> Vector4:
	if not HS4_PIXELLAB_SOURCE_SIZE.has(slot) or not HS4_PIXELLAB_CONTENT_RECT.has(slot):
		return Vector4.ZERO
	var source_size: Vector2 = HS4_PIXELLAB_SOURCE_SIZE[slot]
	var content_rect: Rect2 = HS4_PIXELLAB_CONTENT_RECT[slot]
	var scale_x := display_size.x / maxf(source_size.x, 1.0)
	var scale_y := display_size.y / maxf(source_size.y, 1.0)
	return Vector4(
		roundf(content_rect.position.x * scale_x),
		roundf(content_rect.position.y * scale_y),
		roundf((source_size.x - content_rect.position.x - content_rect.size.x) * scale_x),
		roundf((source_size.y - content_rect.position.y - content_rect.size.y) * scale_y)
	)




func _hs4_pixellab_style(slot: String, display_size: Vector2, tint := Color.WHITE) -> StyleBox:
	if not HS4_PIXELLAB_PATHS.has(slot):
		return _minimal_metal_frame_style("panel", tint)
	var margins := _hs4_pixellab_content_margins(slot, display_size)
	return _global_texture_style(str(HS4_PIXELLAB_PATHS[slot]), margins, tint, margins, false)




func _hs4_apply_wide_control_style(button: Button, display_size: Vector2) -> void:
	UIButtonFamily.assign(button, "hero_carousel_arrow")
	# SCRUM-1063: the accepted textless PixelLab Ascension plate is the universal
	# horizontal source for carousel and Ascension controls. StyleBoxTexture keeps
	# its corners intact while only the calm centre stretches; all runtime glyphs
	# remain inside the authored Rect2(32,22,68,48) content zone.
	button.add_theme_stylebox_override("normal", _hs4_pixellab_style("asc_minus", display_size, Color.WHITE))
	button.add_theme_stylebox_override("hover", _hs4_pixellab_style("asc_minus", display_size, Color(1.08, 1.04, 0.92, 1.0)))
	button.add_theme_stylebox_override("focus", _hs4_pixellab_style("asc_minus", display_size, Color(1.08, 1.04, 0.92, 1.0)))
	button.add_theme_stylebox_override("pressed", _hs4_pixellab_style("asc_minus", display_size, Color(0.82, 0.76, 0.66, 1.0)))
	button.add_theme_stylebox_override("disabled", _hs4_pixellab_style("asc_minus", display_size, Color(0.46, 0.46, 0.50, 0.72)))
	button.add_theme_color_override("font_color", Color(0.98, 0.91, 0.66, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.82, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.82, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.90, 0.82, 0.62, 1.0))
	button.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_ACTION,
		clampi(int(roundf(display_size.y * 0.28)), 20, 38),
		SemanticTypography.role_min(SemanticTypography.ROLE_ACTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_ACTION)
	))
	button.set_meta("hero_wide_control_source", HS4_PIXELLAB_PATHS["asc_minus"])
	button.set_meta("hero_wide_control_source_size", HS4_PIXELLAB_SOURCE_SIZE["asc_minus"])
	button.set_meta("hero_wide_control_content_rect", HS4_PIXELLAB_CONTENT_RECT["asc_minus"])




func _hs4_overlay_style(fill: Color, border: Color = Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_top = 3
	style.content_margin_right = 4
	style.content_margin_bottom = 3
	return style




func _hero_select_preview_sprite_frames(character_id: String) -> SpriteFrames:
	var frames_path := "res://assets/sprites/characters/%s_spriteframes.tres" % character_id
	if not ResourceLoader.exists(frames_path):
		return null
	var frames := load(frames_path) as SpriteFrames
	if frames == null:
		return null
	for direction in HERO_SELECT_PREVIEW_CLOCKWISE_DIRECTIONS:
		if not _hero_select_direction_animation_name(frames, direction).is_empty():
			return frames
	return null




func _hero_select_direction_animation_name(frames: SpriteFrames, direction: String) -> String:
	for prefix in ["idle", "move", "walk"]:
		var animation_name := "%s_%s" % [prefix, direction]
		if frames.has_animation(animation_name):
			return animation_name
	return ""




func _set_hero_select_portrait_preview(portrait: TextureRect, character_id: String, config: Dictionary, preview_state: Dictionary) -> void:
	var frames := _hero_select_preview_sprite_frames(character_id)
	if frames == null:
		preview_state["character_id"] = ""
		preview_state["sprite_frames"] = null
		portrait.texture = game._cached_texture(str(config.get("sprite_path", config.get("sprite", ""))))
		return
	preview_state["character_id"] = character_id
	preview_state["sprite_frames"] = frames
	preview_state["direction_index"] = 0
	preview_state["frame_index"] = 0
	_advance_hero_select_portrait_preview(portrait, preview_state)




func _advance_hero_select_portrait_preview(portrait: TextureRect, preview_state: Dictionary) -> void:
	if portrait == null or not is_instance_valid(portrait):
		return
	var frames := preview_state.get("sprite_frames", null) as SpriteFrames
	if frames == null:
		return
	var direction_index := int(preview_state.get("direction_index", 0))
	var frame_index := int(preview_state.get("frame_index", 0))
	var directions := HERO_SELECT_PREVIEW_CLOCKWISE_DIRECTIONS
	for attempt in range(directions.size()):
		var direction := str(directions[posmod(direction_index + attempt, directions.size())])
		var animation_name := _hero_select_direction_animation_name(frames, direction)
		if animation_name.is_empty():
			continue
		var frame_count := maxi(frames.get_frame_count(animation_name), 1)
		frame_index = posmod(frame_index, frame_count)
		portrait.texture = frames.get_frame_texture(animation_name, frame_index)
		frame_index += 1
		if frame_index >= frame_count:
			frame_index = 0
			direction_index = posmod(direction_index + attempt + 1, directions.size())
		else:
			direction_index = posmod(direction_index + attempt, directions.size())
		preview_state["direction_index"] = direction_index
		preview_state["frame_index"] = frame_index
		return




# SCRUM-851: тултип стата краткий — «Имя — значение» + человеческое описание.
# Формулы, тех-листинги производных и классовые интерпретации — в кодекс, не в ховер.
func _hs4_stat_tooltip(stat_id: String, value: float, _character_id: String) -> String:
	var definition: Dictionary = StatFormulas.STAT_DEFINITIONS.get(stat_id, {})
	var stat_name := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
	return "%s — %d\n%s" % [
		stat_name,
		int(round(value)),
		str(definition.get("description", "")),
	]




func _hs4_ascension_text(level: int) -> String:
	var lines: Array = game.PROGRESSION_DATA.ascension_modifier_lines(level)
	if lines.is_empty():
		return "Уровень 0: без усложнений."
	return "\n".join(lines)




func _hs4_join_dossier_names(entries: Array) -> String:
	if entries.is_empty():
		return "Нет."
	var names := PackedStringArray()
	for entry_value in entries:
		var entry := entry_value as Dictionary
		names.append(str(entry.get("name", entry.get("id", ""))))
	return ", ".join(names)




func _hs4_stat_fill_color(stat_id: String) -> Color:
	return HeroSelectConstants.stat_accent_color(stat_id)




func _hs4_stat_text_color(stat_id: String) -> Color:
	return HeroSelectConstants.stat_text_color(stat_id)
