extends "res://tests/runtime_smoke_test.gd"

# Focused regression gate for the compact Main Menu utility cluster.  A future
# prerelease version is injected before screen construction so a fixed-width or
# hardcoded label cannot pass on today's short `v0.2.0` value.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FUTURE_VERSION := "0.2.10-beta"
const TARGETS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2048, 1152),
	Vector2i(2560, 1440),
]

var _errors := PackedStringArray()
var _original_version: Variant


func _initialize() -> void:
	_original_version = ProjectSettings.get_setting("application/config/version", "0.0.0")
	ProjectSettings.set_setting("application/config/version", FUTURE_VERSION)
	for viewport_size in TARGETS:
		await _validate_fresh(viewport_size)
	await _validate_live_resize()
	ProjectSettings.set_setting("application/config/version", _original_version)
	if not _errors.is_empty():
		for error in _errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1093 compact version corner passed four viewports, future version and live resize.")
	quit(0)


func _validate_fresh(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle_frames()
	main.ui._show_main_menu()
	await _settle_frames()
	_assert_cluster(main, viewport_size, "fresh")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _validate_live_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = TARGETS[TARGETS.size() - 1]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle_frames()
	main.ui._show_main_menu()
	await _settle_frames()
	for index in range(TARGETS.size() - 1, -1, -1):
		var viewport_size: Vector2i = TARGETS[index]
		viewport.size = viewport_size
		await _settle_frames()
		_assert_cluster(main, viewport_size, "live resize")
	main.queue_free()
	viewport.queue_free()
	await process_frame


func _assert_cluster(main: Node, viewport_size: Vector2i, phase: String) -> void:
	var context := "%s %s" % [phase, str(viewport_size)]
	var screen := main.find_child("MainMenuScreen", true, false) as Control
	var glow := main.find_child("MainMenuGratitudeGlow", true, false) as TextureRect
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	var version := main.find_child("MainMenuVersionLabel", true, false) as Label
	if screen == null or glow == null or credits == null or version == null:
		_errors.append("%s: compact utility nodes are incomplete." % context)
		return
	var expected_text := "v%s" % FUTURE_VERSION
	if version.text != expected_text:
		_errors.append("%s: dynamic version '%s' != '%s'." % [context, version.text, expected_text])
	var font := version.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var measured := ceilf(font.get_string_size(
		version.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		version.get_theme_font_size("font_size")
	).x)
	if absf(version.size.x - measured - 6.0) > 1.1:
		_errors.append("%s: future version rect %.1f is not measured width %.1f + 6." % [context, version.size.x, measured])
	if float(version.get_meta("scrum1093_measured_text_width", -1.0)) != measured:
		_errors.append("%s: published measured width drifted." % context)
	var frame_margins := Vector2(
		roundf(160.0 * float(viewport_size.x) / 1536.0),
		roundf(160.0 * float(viewport_size.y) / 1024.0)
	)
	var utility_safe := Rect2(
		frame_margins + Vector2.ONE * 8.0,
		Vector2(viewport_size) - frame_margins * 2.0 - Vector2.ONE * 16.0
	)
	if version.get_global_rect().end.distance_to(utility_safe.end) > 1.1:
		_errors.append("%s: future version is not exactly 8 px inside the frame-safe rail." % context)
	for control in [glow, credits, version]:
		if not utility_safe.grow(1.0).encloses((control as Control).get_global_rect()):
			_errors.append("%s: %s escapes utility safe zone." % [context, str((control as Control).name)])
	if absf(version.get_global_rect().position.x - glow.get_global_rect().end.x - 2.0) > 1.1:
		_errors.append("%s: glow-to-version rect gap is not 2 px." % context)
	var glyph_start := version.get_global_rect().end.x - measured
	var icon_image := credits.icon.get_image()
	var used := icon_image.get_used_rect()
	var style := credits.get_theme_stylebox("normal")
	var left_margin := style.get_content_margin(SIDE_LEFT) if style != null else 0.0
	var right_margin := style.get_content_margin(SIDE_RIGHT) if style != null else 0.0
	var top_margin := style.get_content_margin(SIDE_TOP) if style != null else 0.0
	var bottom_margin := style.get_content_margin(SIDE_BOTTOM) if style != null else 0.0
	var content_size := credits.size - Vector2(left_margin + right_margin, top_margin + bottom_margin)
	var source_size := Vector2(icon_image.get_width(), icon_image.get_height())
	var icon_scale := minf(content_size.x / source_size.x, content_size.y / source_size.y)
	var draw_size := source_size * icon_scale
	var draw_start := credits.get_global_rect().position + Vector2(
		left_margin + (content_size.x - draw_size.x) * 0.5,
		top_margin + (content_size.y - draw_size.y) * 0.5
	)
	var visible_alpha_right := draw_start.x + float(used.end.x) * icon_scale
	var visible_gap := glyph_start - visible_alpha_right
	if visible_gap < 0.0 or visible_gap > 20.0:
		_errors.append("%s: actual alpha-to-version gap %.1f is outside 0..20 px." % [context, visible_gap])
	if not (credits.icon is AtlasTexture):
		_errors.append("%s: Gratitude icon must use the runtime alpha-aware AtlasTexture." % context)
	else:
		var atlas := credits.icon as AtlasTexture
		if atlas.atlas == null or atlas.atlas.resource_path != "res://assets/sprites/ui/icons/credits/ui_icon_gratitude.png":
			_errors.append("%s: alpha-aware crop lost the accepted PixelLab source." % context)
		if atlas.region != Rect2(41, 48, 160, 160) or used != Rect2i(14, 0, 146, 160):
			_errors.append("%s: alpha-aware region/used-alpha contract drifted (%s / %s)." % [context, str(atlas.region), str(used)])
	if credits.get_global_rect().intersects(version.get_global_rect()) or glow.get_global_rect().intersects(version.get_global_rect()):
		_errors.append("%s: compact controls overlap." % context)
	if credits.tooltip_text != "Благодарности" or str(credits.get_meta("accessibility_name", "")) != "Благодарности":
		_errors.append("%s: Gratitude tooltip/accessibility drifted." % context)
	if credits.pressed.get_connections().size() < 2:
		_errors.append("%s: Gratitude callback or UI SFX connection was lost." % context)
	if credits.focus_mode != Control.FOCUS_ALL:
		_errors.append("%s: Gratitude focusability drifted." % context)
	if screen.find_children("*", "ScrollContainer", true, false).size() > 0:
		_errors.append("%s: Main Menu must not gain scrolling." % context)


func _settle_frames() -> void:
	for _frame in range(6):
		await process_frame
