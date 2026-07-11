extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const HeroSelectConstants := preload("res://scripts/ui/hero_select_constants.gd")
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const STATS := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
const ROW_SURFACE := Color(0x171613ff)
const MIN_TEXT_CONTRAST := 4.5

var _errors: Array[String] = []


func _initialize() -> void:
	_assert_shared_palette_contract()
	for viewport_size in VIEWPORTS:
		await _assert_runtime_at_size(viewport_size)
	if _errors.is_empty():
		print("SCRUM-951 Hero Select stat identity colors passed palette, contrast, tooltip, hero-refresh and 720p/1080p/2K safe-zone checks.")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _assert_shared_palette_contract() -> void:
	if HeroSelectConstants.HERO_STAT_COLORS.size() != STATS.size():
		_errors.append("Shared HERO_STAT_COLORS must contain exactly the eight canonical stats.")
	var unique_accents := {}
	for stat_id in STATS:
		if not HeroSelectConstants.HERO_STAT_COLORS.has(stat_id):
			_errors.append("Shared palette is missing %s." % stat_id)
			continue
		var accent := HeroSelectConstants.stat_accent_color(stat_id)
		var text_color := HeroSelectConstants.stat_text_color(stat_id)
		unique_accents[accent.to_html(false)] = true
		var contrast := _contrast_ratio(text_color, ROW_SURFACE)
		if contrast + 0.001 < MIN_TEXT_CONTRAST:
			_errors.append("%s text contrast %.2f is below %.1f:1." % [stat_id, contrast, MIN_TEXT_CONTRAST])
	if unique_accents.size() != STATS.size():
		_errors.append("Every canonical stat must keep a distinct accent color.")
	var strength_accent := HeroSelectConstants.stat_accent_color("strength")
	var strength_text := HeroSelectConstants.stat_text_color("strength")
	if strength_accent.is_equal_approx(strength_text):
		_errors.append("Strength must preserve canonical bar red and the documented accessible text adjustment as separate values.")


func _assert_runtime_at_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.call("_show_character_select")
	await process_frame
	await process_frame

	var context := str(viewport_size)
	var dossier := main.find_child("HS4DossierFrame", true, false) as Control
	var stats_column := main.find_child("HS4StatsColumn", true, false) as Control
	var stats_grid := main.find_child("HS4StatsGrid", true, false) as GridContainer
	if dossier == null or stats_column == null or stats_grid == null:
		_errors.append("%s: Hero Select dossier/stat column is missing." % context)
		viewport.queue_free()
		await process_frame
		return
	var dossier_rect := dossier.get_global_rect()
	var column_rect := stats_column.get_global_rect()
	var expected_columns := 2 if viewport_size.y < 800 else 1
	if stats_grid.columns != expected_columns:
		_errors.append("%s: expected %d responsive stat columns, got %d." % [context, expected_columns, stats_grid.columns])
	var first_row: Button = null
	var before_refresh := {}
	for stat_id in STATS:
		var button := main.find_child("HS4Stat_%s" % stat_id, true, false) as Button
		var name_label := main.find_child("HS4StatName_%s" % stat_id, true, false) as Label
		var bar_track := main.find_child("HS4StatBar_%s" % stat_id, true, false) as ColorRect
		var bar_fill := main.find_child("HS4StatBarFill_%s" % stat_id, true, false) as ColorRect
		var value_label := main.find_child("HS4StatValue_%s" % stat_id, true, false) as Label
		if button == null or name_label == null or bar_track == null or bar_fill == null or value_label == null:
			_errors.append("%s: incomplete stat row %s." % [context, stat_id])
			continue
		if first_row == null:
			first_row = button
		if not dossier_rect.grow(1.0).encloses(button.get_global_rect()) or not column_rect.grow(1.0).encloses(button.get_global_rect()):
			_errors.append("%s: %s leaves the dossier/stat safe zone." % [context, stat_id])
		var row_rect := button.get_global_rect()
		if not row_rect.grow(1.0).encloses(bar_track.get_global_rect()):
			_errors.append("%s: %s bar leaves its row interior." % [context, stat_id])
		# SCRUM-951 keeps visible text at every supported target (720p uses 2x4).
		for text_node in [name_label, value_label]:
			if not (text_node as Label).visible:
				_errors.append("%s: %s must stay visible so color is not the only meaning carrier." % [context, (text_node as Label).name])
			elif not dossier_rect.grow(1.0).encloses((text_node as Label).get_global_rect()) or not column_rect.grow(1.0).encloses((text_node as Label).get_global_rect()):
				_errors.append("%s: visible %s leaves the dossier/stat safe zone." % [context, (text_node as Label).name])
		if name_label.text.strip_edges().is_empty() or value_label.text.strip_edges().is_empty():
			_errors.append("%s: %s must retain name and numeric value nodes as non-color meaning." % [context, stat_id])
		var name_font := name_label.get_theme_font("font")
		var name_font_size := name_label.get_theme_font_size("font_size")
		if name_font != null:
			var required_name_width := name_font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_font_size).x
			if required_name_width > name_label.size.x + 0.5:
				_errors.append("%s: %s localized name is visually truncated (needs %.1f, has %.1f)." % [context, stat_id, required_name_width, name_label.size.x])
		if button.tooltip_text.strip_edges().is_empty() or not button.tooltip_text.contains(" — ") or button.tooltip_text.contains("Формула:"):
			_errors.append("%s: %s lost the existing concise hover/focus tooltip." % [context, stat_id])
		elif not button.tooltip_text.begins_with(name_label.text):
			_errors.append("%s: %s tooltip no longer exposes the localized stat name." % [context, stat_id])
		var expected_accent := HeroSelectConstants.stat_accent_color(stat_id)
		var expected_text := HeroSelectConstants.stat_text_color(stat_id)
		if not bar_fill.color.is_equal_approx(expected_accent):
			_errors.append("%s: %s bar does not use the shared canonical accent." % [context, stat_id])
		if not name_label.get_theme_color("font_color").is_equal_approx(expected_text) or not value_label.get_theme_color("font_color").is_equal_approx(expected_text):
			_errors.append("%s: %s name/value do not use the shared accessible text color." % [context, stat_id])
		before_refresh[stat_id] = bar_fill.color

	# Focus/hover styles must not resize the first stat row.
	if first_row != null:
		var before_focus := first_row.get_global_rect()
		first_row.grab_focus()
		await process_frame
		if not first_row.get_global_rect().is_equal_approx(before_focus):
			_errors.append("%s: stat focus shifted row geometry." % context)

	# Stat identity is independent of the selected class. Exercise the real
	# carousel refresh path, not only the constants helper.
	var next_button := main.find_child("HS4CarouselNextButton", true, false) as Button
	if next_button == null:
		_errors.append("%s: carousel next button missing for hero-refresh oracle." % context)
	else:
		next_button.emit_signal("pressed")
		await process_frame
		for stat_id in STATS:
			var refreshed_fill := main.find_child("HS4StatBarFill_%s" % stat_id, true, false) as ColorRect
			if refreshed_fill == null or not refreshed_fill.color.is_equal_approx(before_refresh.get(stat_id, Color.TRANSPARENT)):
				_errors.append("%s: %s changed identity color after hero selection." % [context, stat_id])

	viewport.queue_free()
	await process_frame


func _contrast_ratio(foreground: Color, background: Color) -> float:
	var lighter := maxf(_relative_luminance(foreground), _relative_luminance(background))
	var darker := minf(_relative_luminance(foreground), _relative_luminance(background))
	return (lighter + 0.05) / (darker + 0.05)


func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)


func _linear_channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)
