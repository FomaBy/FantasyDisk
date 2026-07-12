extends SceneTree

# Independent SCRUM-1093 visual acceptance oracle.  The implementation-owned
# tests measure the transparent Button hitbox to the version glyphs.  This gate
# measures from the rightmost non-transparent pixel in the accepted Gratitude
# PNG after Button expansion/content margins, which is the user-visible gap.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FUTURE_VERSION := "0.2.10-beta"
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2048, 1152),
	Vector2i(2560, 1440),
]
const MAX_VISIBLE_GAP := 20.0

var errors := PackedStringArray()
var original_version: Variant


func _initialize() -> void:
	original_version = ProjectSettings.get_setting("application/config/version", "0.0.0")
	ProjectSettings.set_setting("application/config/version", FUTURE_VERSION)
	for target in TARGETS:
		await _audit_target(target)
	ProjectSettings.set_setting("application/config/version", original_version)
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1093 visible alpha-to-glyph gap passed four viewports.")
	quit(0)


func _audit_target(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle()
	main.ui._show_main_menu()
	await _settle()
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	var version := main.find_child("MainMenuVersionLabel", true, false) as Label
	if credits == null or version == null or credits.icon == null:
		errors.append("%s: utility controls/icon missing" % str(viewport_size))
	else:
		var texture_image := credits.icon.get_image()
		var used := texture_image.get_used_rect()
		var style := credits.get_theme_stylebox("normal")
		var left_margin := style.get_content_margin(SIDE_LEFT) if style != null else 0.0
		var right_margin := style.get_content_margin(SIDE_RIGHT) if style != null else 0.0
		var top_margin := style.get_content_margin(SIDE_TOP) if style != null else 0.0
		var bottom_margin := style.get_content_margin(SIDE_BOTTOM) if style != null else 0.0
		var content_size := Vector2(
			credits.size.x - left_margin - right_margin,
			credits.size.y - top_margin - bottom_margin
		)
		var source_size := Vector2(texture_image.get_width(), texture_image.get_height())
		var icon_scale := minf(content_size.x / source_size.x, content_size.y / source_size.y)
		var draw_size := source_size * icon_scale
		var draw_start := credits.get_global_rect().position + Vector2(
			left_margin + (content_size.x - draw_size.x) * 0.5,
			top_margin + (content_size.y - draw_size.y) * 0.5
		)
		var visible_icon_right := draw_start.x + float(used.end.x) * icon_scale
		var font := version.get_theme_font("font")
		if font == null:
			font = ThemeDB.fallback_font
		var measured := ceilf(font.get_string_size(
			version.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			version.get_theme_font_size("font_size")
		).x)
		var glyph_start := version.get_global_rect().end.x - measured
		var visible_gap := glyph_start - visible_icon_right
		print("SCRUM-1093 visible gap %s: %.2f px (alpha rect %s, scale %.4f)" % [
			str(viewport_size), visible_gap, str(used), icon_scale,
		])
		if visible_gap < 0.0 or visible_gap > MAX_VISIBLE_GAP:
			errors.append("%s: actual visible icon alpha-to-version glyph gap %.2f px is outside 0..%.0f" % [
				str(viewport_size), visible_gap, MAX_VISIBLE_GAP,
			])
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _settle() -> void:
	for _frame in range(8):
		await process_frame
