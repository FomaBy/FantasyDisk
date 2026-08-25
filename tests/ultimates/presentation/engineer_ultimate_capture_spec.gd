extends RefCounted

## Layout contract for the engineer sentry-wrench live-capture sheet.
##
## The renderer and the focused test both read this file, so the geometry a test
## asserts is the geometry the committed PNGs were rendered with.

const CAPTURE_ROOT := "res://docs/design/references/weapon_ultimates/engineer/"
const SHEET_TITLE := "ENGINEER SENTRY WRENCH — «ГНЕЗДО ЧАСОВЫХ» v2 — LIVE PHASE TIMELINE"

## The four supported viewports of the shared visual-direction contract.
const CAPTURES := [
	{"name": "648p", "path": CAPTURE_ROOT + "engineer_sentry_wrench_timeline_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": CAPTURE_ROOT + "engineer_sentry_wrench_timeline_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": CAPTURE_ROOT + "engineer_sentry_wrench_timeline_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": CAPTURE_ROOT + "engineer_sentry_wrench_timeline_2k.png", "size": Vector2i(2560, 1440)},
]

## One panel per phase, sampled inside the phase rather than on its boundary.
## The last panel is driven into `active` and then cancelled, so it shows what
## the cleanup path leaves behind.
const PANELS := [
	{"phase": "windup", "time": 0.45, "title": "WINDUP 0.45s"},
	{"phase": "release", "time": 0.95, "title": "RELEASE 0.95s"},
	{"phase": "active", "time": 2.20, "title": "ACTIVE 2.20s"},
	{"phase": "recovery", "time": 3.40, "title": "RECOVERY 3.40s"},
	{"phase": "cancel", "time": 2.20, "title": "CANCEL CLEANUP", "cancel": true},
]

const PANEL_CENTER_Y_RATIO := 0.53
const PANEL_HALF_WIDTH_RATIO := 0.092
const PANEL_HALF_HEIGHT_RATIO := 0.31
const PANEL_CONTENT_MARGIN_RATIO := 0.022
const SHEET_TITLE_Y_RATIO := 0.125
const SHEET_TITLE_FONT_RATIO := 0.026
const PANEL_LABEL_FONT_RATIO := 0.017
const SHEET_TEXT_MARGIN := 8.0

## The screen bands the HUD owns. A presentation that reaches into either band
## stops being readable in real combat, so they are drawn on every sheet.
const HUD_TOP_RATIO := 0.09
const HUD_BOTTOM_RATIO := 0.91

const CROWD_MARKERS_PER_PANEL := 8
const CROWD_MARKER_RATIO := 0.016


static func panel_center(size: Vector2i, index: int) -> Vector2:
	var slot := (float(index) + 0.5) / float(PANELS.size())
	return Vector2(float(size.x) * slot, float(size.y) * PANEL_CENTER_Y_RATIO)


static func panel_rect(size: Vector2i, index: int) -> Rect2:
	var half := Vector2(float(size.x) * PANEL_HALF_WIDTH_RATIO, float(size.y) * PANEL_HALF_HEIGHT_RATIO)
	return Rect2(panel_center(size, index) - half, half * 2.0)


## The drawable zone of a panel: the panel minus its margin and its caption row.
static func panel_content_rect(size: Vector2i, index: int) -> Rect2:
	var panel := panel_rect(size, index)
	var margin := float(size.y) * PANEL_CONTENT_MARGIN_RATIO
	var caption := float(panel_label_font_size(size)) * 2.0
	return Rect2(
		panel.position + Vector2.ONE * margin,
		Vector2(panel.size.x - margin * 2.0, panel.size.y - margin * 2.0 - caption)
	)


static func hud_bands(size: Vector2i) -> Array[Rect2]:
	return [
		Rect2(Vector2.ZERO, Vector2(float(size.x), float(size.y) * HUD_TOP_RATIO)),
		Rect2(Vector2(0.0, float(size.y) * HUD_BOTTOM_RATIO), Vector2(float(size.x), float(size.y) * (1.0 - HUD_BOTTOM_RATIO))),
	] as Array[Rect2]


## A fixed crowd field behind each panel. Deterministic, so two runs of the
## renderer produce the same sheet.
static func crowd_markers(size: Vector2i, index: int) -> Array[Rect2]:
	var zone := panel_content_rect(size, index)
	var marker := Vector2.ONE * float(size.y) * CROWD_MARKER_RATIO
	var markers: Array[Rect2] = []
	for slot in CROWD_MARKERS_PER_PANEL:
		var column := float(slot % 4) / 3.0
		var row := float(slot / 4)
		var offset := Vector2(
			lerpf(0.06, 0.94, column) * zone.size.x,
			lerpf(0.18, 0.86, (row + float(index % 2) * 0.35) / 1.35) * zone.size.y
		)
		markers.append(Rect2(zone.position + offset - marker * 0.5, marker))
	return markers


static func sheet_title_font_size(size: Vector2i) -> int:
	return maxi(14, int(float(size.y) * SHEET_TITLE_FONT_RATIO))


static func panel_label_font_size(size: Vector2i) -> int:
	return maxi(10, int(float(size.y) * PANEL_LABEL_FONT_RATIO))


static func sheet_title_rect(size: Vector2i) -> Rect2:
	var text_size := ThemeDB.fallback_font.get_string_size(
		SHEET_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sheet_title_font_size(size)
	)
	return Rect2(
		Vector2((float(size.x) - text_size.x) * 0.5, float(size.y) * SHEET_TITLE_Y_RATIO),
		text_size
	)


static func panel_label_rect(size: Vector2i, index: int, caption: String) -> Rect2:
	var panel := panel_rect(size, index)
	var font_size := panel_label_font_size(size)
	var text_size := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(
		Vector2(panel.get_center().x - text_size.x * 0.5, panel.end.y - text_size.y - float(size.y) * 0.014),
		text_size
	)


## Fit the live scene into its panel and return the bounds it ends up covering.
static func layout_capture_scene(scene: Node2D, size: Vector2i, index: int) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := capture_content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var zone := panel_content_rect(size, index)
	var scale := minf(float(size.y) / 1080.0, minf(zone.size.x / bounds.size.x, zone.size.y / bounds.size.y))
	scene.scale = Vector2.ONE * scale
	scene.position = zone.get_center() - bounds.get_center() * scale
	return Rect2(scene.position + bounds.position * scale, bounds.size * scale)


## Union of every visible formation sprite, in scene-local pixels.
static func capture_content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.visible or sprite.modulate.a <= 0.01:
			continue
		if bool(sprite.get_meta("fullscreen_layer", false)):
			continue
		var rect := sprite.get_rect()
		var item := Rect2(sprite.position + rect.position * sprite.scale, rect.size * sprite.scale)
		bounds = item if not found else bounds.merge(item)
		found = true
	return bounds
