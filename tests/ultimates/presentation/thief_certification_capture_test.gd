extends SceneTree

## FAN-3941 — headless gate and shared spec for the Thief certification
## capture package.
##
## The package proves the three canonical Thief ultimates in the four
## presentation modes at the four supported viewports, one native-size frame
## per weapon/mode/viewport at the active beat and, at the 1152x648 judging
## viewport, the release and recovery beats as well. Every frame is a real
## render of the shipped scene composed with the hero, a crowd, hazards and the
## real ultimate HUD widget at the on-screen scale the game uses.
##
## This file owns the geometry the capture script draws, the readability
## probes it records and the validators that read the committed package back,
## so the frames, the manifest and the gate can never describe different
## pictures. The renderer lives in thief_certification_live_capture.gd and
## preloads this file; nothing here renders.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Pack := preload("res://scenes/vfx/ultimates/thief/thief_ultimate_presentation_pack.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const TEXT_FIT := preload("res://tests/ultimates/presentation/contact_sheet_text_fit.gd")

const CLASS_ID := "thief"
const ISSUE := "FAN-3941"
const SCHEMA_VERSION := 1
const CAPTURE_SCRIPT := "tests/ultimates/presentation/thief_certification_live_capture.gd"
const FOCUSED_TEST := "tests/ultimates/presentation/thief_certification_capture_test.gd"
const CAPTURE_ROOT := "docs/design/reference-assets-lfs/ultimate-certification/thief"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/thief/certification_capture_manifest.json"
const READABILITY_REPORT := "docs/design/references/weapon_ultimates/thief/certification_readability_report.md"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/thief/manifest.json"
const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/thief.json"
const ADOPTION_SHARD_PATH := "res://data/ultimates/classes/thief/presentation_adoption.json"

## The shipped scenes were captured from this integrated revision. The capture
## tooling and the evidence it produces are added by FAN-3941 on top of it, so
## the pin is the source of the pictures, never the commit that carries them.
const SOURCE_REF := "dev"
const SOURCE_COMMIT_SHA := "d192be10bbe52dd89971cab0acc66eb92ccab37f"
const SOURCE_TREE_SHA := "e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf"

const CAPTURE_COMMAND := "FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --script res://tests/ultimates/presentation/thief_certification_live_capture.gd"
const TEST_COMMAND := "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/thief_certification_capture_test.gd"
const CAPTURE_SEED := 3941

## On-screen scale. project.godot renders a 2560x1440 logical canvas with the
## canvas_items stretch mode and the combat camera zooms it by
## main.gd:COMBAT_CAMERA_ZOOM, so a world unit covers
## viewport_height / 1440 * 1.12 pixels at every supported window size. The
## hero sprite is the Player's 512 px full frame at player.gd's combat visual
## scale. Nothing is fitted to the frame: the effect is drawn at the size the
## player sees.
const LOGICAL_CANVAS := Vector2(2560.0, 1440.0)
const COMBAT_CAMERA_ZOOM := 1.12
const PLAYER_VISUAL_SCALE := 0.64
const PLAYER_SPRITE := "res://assets/sprites/characters/full_frame/thief_pixellab/thief_idle_south.png"
const PLAYER_SPRITE_SOURCE_PX := 512.0

const VIEWPORTS := [
	{"id": "648p", "size": Vector2i(1152, 648)},
	{"id": "720p", "size": Vector2i(1280, 720)},
	{"id": "1080p", "size": Vector2i(1920, 1080)},
	{"id": "2k", "size": Vector2i(2560, 1440)},
]
const VIEWPORT_IDS: Array[String] = ["648p", "720p", "1080p", "2k"]

const MODE_NORMAL := "normal"
const MODE_CROWDED := "crowded"
const MODE_REDUCED_MOTION := "reduced_motion"
const MODE_PHOTOSENSITIVITY_SAFE := "photosensitivity_safe"
## `crowd` draws the weapon's declared crowd cap, `screen_shake` is the shipped
## settings toggle main.gd mirrors onto the tree root. The Thief timeline
## scenes author no arena-wide surface, so `veil` is recorded for parity with
## the other class packages and there is nothing for the photosensitivity-safe
## variant to drop: it is the shipped scene with motion off, which the gate
## proves by counting full-screen surfaces (zero) rather than by assuming it.
const MODES := [
	{"id": MODE_NORMAL, "label": "NORMAL", "crowd": false, "screen_shake": true, "veil": true, "swatch": Color(0.18, 0.76, 1.0)},
	{"id": MODE_CROWDED, "label": "CROWDED", "crowd": true, "screen_shake": true, "veil": true, "swatch": Color(1.0, 0.58, 0.18)},
	{"id": MODE_REDUCED_MOTION, "label": "REDUCED MOTION", "crowd": false, "screen_shake": false, "veil": true, "swatch": Color(0.36, 0.92, 0.48)},
	{"id": MODE_PHOTOSENSITIVITY_SAFE, "label": "PHOTOSENSITIVITY-SAFE", "crowd": false, "screen_shake": false, "veil": false, "swatch": Color(0.78, 0.48, 1.0)},
]
const MODE_IDS: Array[String] = [MODE_NORMAL, MODE_CROWDED, MODE_REDUCED_MOTION, MODE_PHOTOSENSITIVITY_SAFE]

## Beats sit at the middle of their declared phase window, so every weapon is
## sampled where the phase is unmistakably itself rather than on a boundary.
const BEAT_IDS: Array[String] = ["release", "active", "recovery"]
const BEAT_NEXT_PHASE := {"release": "active", "active": "recovery", "recovery": "cancel"}
## Every viewport carries the active beat; release and recovery are committed at
## the 648p viewport the readability contract judges on.
const FULL_VIEWPORT_BEAT := "active"
const BEAT_VIEWPORT := "648p"

const WEAPONS := [
	{
		"weapon_id": Pack.COIN_POUCH,
		"scene_path": "scenes/vfx/ultimates/thief/ThiefCoinPouchUltimate.tscn",
		"scene": preload("res://scenes/vfx/ultimates/thief/ThiefCoinPouchUltimate.tscn"),
		"victim_frames": preload("res://assets/sprites/effects/thief/coin_pouch/coin_pouch_spriteframes.tres"),
		"label": "COIN POUCH",
		"swatch": Color(1.0, 0.84, 0.36),
	},
	{
		"weapon_id": Pack.SHADOW_CLOAK,
		"scene_path": "scenes/vfx/ultimates/thief/ThiefShadowCloakUltimate.tscn",
		"scene": preload("res://scenes/vfx/ultimates/thief/ThiefShadowCloakUltimate.tscn"),
		"victim_frames": preload("res://assets/sprites/effects/thief/shadow_cloak/shadow_cloak_spriteframes.tres"),
		"label": "SHADOW CLOAK",
		"swatch": Color(0.70, 0.46, 0.96),
	},
	{
		"weapon_id": Pack.SMOKE_BOMB,
		"scene_path": "scenes/vfx/ultimates/thief/ThiefSmokeBombUltimate.tscn",
		"scene": preload("res://scenes/vfx/ultimates/thief/ThiefSmokeBombUltimate.tscn"),
		"victim_frames": preload("res://assets/sprites/effects/thief/smoke_bomb/smoke_bomb_spriteframes.tres"),
		"label": "SMOKE BOMB",
		"swatch": Color(0.56, 0.72, 0.84),
	},
]

## Arena bands in viewport ratios. The HUD strip, the hero column and the hazard
## column are the readability claim; the effect zone between them is where the
## scene is placed, at its on-screen scale, without fitting.
const HUD_BAND_HEIGHT_RATIO := 0.12
const STATE_BAND_HEIGHT_RATIO := 0.07
const PLAYER_COLUMN_WIDTH_RATIO := 0.16
const HAZARD_COLUMN_WIDTH_RATIO := 0.12
const HAZARD_LOGICAL_SIZE := 128.0
const HAZARD_STRIPES := 3
const HAZARD_TOP_RATIOS: Array[float] = [0.18, 0.58]
const CROWD_LOGICAL_RADIUS := 28.0
const CROWD_COLUMNS := 6
const HUD_TEXT := "HP 62/120"
const HUD_FONT_LOGICAL := 34
const CAPTION_MARGIN_RATIO := 0.008

const FLOOR_COLOR := Color(0.043, 0.056, 0.068, 1.0)
const HUD_BAND_COLOR := Color(0.10, 0.13, 0.17, 0.92)
const HUD_TEXT_COLOR := Color(0.86, 0.92, 0.98)
const STATE_BAND_COLOR := Color(0.08, 0.10, 0.13, 1.0)
const STATE_TEXT_COLOR := Color(0.72, 0.80, 0.88)
const HAZARD_COLOR := Color(0.98, 0.62, 0.20, 1.0)
const HAZARD_BASE_COLOR := Color(0.98, 0.62, 0.20, 0.28)
const CROWD_COLOR := Color(0.72, 0.36, 0.42, 0.92)
const PLAYER_BACKING_COLOR := Color(0.08, 0.11, 0.14, 0.85)

## Readability floors the gate measures on the decoded frames. Contrast is the
## luma difference against a sampled floor/band pixel, so a tinted veil still
## passes as long as the thing behind it stays readable.
const HUD_CONTRAST_MIN := 0.25
const HUD_CONTRAST_MIN_RATIO := 0.004
const PLAYER_CONTRAST_MIN := 0.15
const PLAYER_CONTRAST_MIN_RATIO := 0.15
const HAZARD_CONTRAST_MIN := 0.15
const HAZARD_HUE_MIN_SPREAD := 0.25
const SWATCH_TOLERANCE := 0.06
const PROBE_STRIDE := 2
const COVERAGE_STRIDE := 2
const COVERAGE_ALPHA_MIN := 0.5
const SWEEP_STEP_SECONDS := 1.0 / 30.0
const SEEK_STEP := 1.0 / 120.0

## Ceiling any arena-wide tint would have to respect; Thief authors none.
const MAX_OVERLAY_ALPHA := 0.35
const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)
	var manifest := load_json(MANIFEST_PATH, errors)
	var class_manifest := load_json(CLASS_MANIFEST_PATH, errors)
	var profile := load_json(PROFILE_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_check_declaration(errors)
	for violation in identity_violations(manifest, profile):
		errors.append(violation)
	for violation in coverage_violations(manifest):
		errors.append(violation)
	_check_files(manifest, errors)
	for violation in quality_violations(class_manifest, manifest):
		errors.append(violation)
	for violation in class_manifest_link_violations(class_manifest):
		errors.append(violation)
	for violation in adoption_violations():
		errors.append(violation)
	_check_live_composition(registry, errors)
	_check_photosensitivity(errors)
	_check_negatives(manifest, class_manifest, profile, errors)
	_finish(errors)


# --- declaration ------------------------------------------------------------


## The spec itself: four viewports at the contract sizes, the canonical trio,
## the four modes, and the committed beat set of 72 frames.
func _check_declaration(errors: Array[String]) -> void:
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var id := str(viewport["id"])
		_expect(Contract.REQUIRED_CAPTURES.has(id), "viewport %s must be a contract slot" % id, errors)
		_expect(Contract.REQUIRED_CAPTURES.get(id, Vector2i.ZERO) == viewport["size"], "viewport %s must be the contract size" % id, errors)
	_expect(weapon_ids() == Pack.WEAPON_IDS, "spec must cover the canonical Thief trio in order", errors)
	_expect(mode_ids() == MODE_IDS, "spec must cover the four presentation modes", errors)
	_expect(expected_entries().size() == 72, "spec must commit 72 frames (48 active + 24 beats at 648p)", errors)


static func weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_weapon in WEAPONS:
		ids.append(str((raw_weapon as Dictionary)["weapon_id"]))
	return ids


static func mode_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_mode in MODES:
		ids.append(str((raw_mode as Dictionary)["id"]))
	return ids


static func weapon_spec(weapon_id: String) -> Dictionary:
	for raw_weapon in WEAPONS:
		if str((raw_weapon as Dictionary)["weapon_id"]) == weapon_id:
			return raw_weapon as Dictionary
	return {}


static func mode_spec(mode_id: String) -> Dictionary:
	for raw_mode in MODES:
		if str((raw_mode as Dictionary)["id"]) == mode_id:
			return raw_mode as Dictionary
	return {}


static func viewport_size(viewport_id: String) -> Vector2i:
	for raw_viewport in VIEWPORTS:
		if str((raw_viewport as Dictionary)["id"]) == viewport_id:
			return (raw_viewport as Dictionary)["size"] as Vector2i
	return Vector2i.ZERO


static func key_for(weapon_id: String) -> String:
	return "%s/%s" % [CLASS_ID, weapon_id]


## Every frame the package commits, in capture order.
static func expected_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for weapon_id in weapon_ids():
		for mode_id in MODE_IDS:
			for viewport_id in VIEWPORT_IDS:
				for beat_id in BEAT_IDS:
					if beat_id != FULL_VIEWPORT_BEAT and viewport_id != BEAT_VIEWPORT:
						continue
					entries.append({"weapon_id": weapon_id, "mode": mode_id, "viewport": viewport_id, "beat": beat_id})
	return entries


static func entry_id(entry: Dictionary) -> String:
	return "%s/%s/%s/%s" % [str(entry["weapon_id"]), str(entry["mode"]), str(entry["viewport"]), str(entry["beat"])]


static func capture_path(entry: Dictionary) -> String:
	return "%s/%s__%s__%s__%s.png" % [CAPTURE_ROOT, str(entry["weapon_id"]), str(entry["mode"]), str(entry["beat"]), str(entry["viewport"])]


## The declared phase timing is the beat source; the Thief pack and the class
## manifest agree on it field by field (thief_ultimate_presentation_test.gd).
static func beat_seconds(weapon_id: String, beat_id: String) -> float:
	var timing: Dictionary = Pack.weapon_config(weapon_id).get("timing", {})
	var start := float(timing.get(beat_id, 0.0))
	var end := float(timing.get(str(BEAT_NEXT_PHASE.get(beat_id, "cancel")), start))
	return snappedf((start + end) * 0.5, 0.01)


static func crowd_cap(weapon_id: String) -> int:
	return Pack.MAX_ELEMENTS_PER_ULTIMATE


static func crowd_count(weapon_id: String, mode: Dictionary) -> int:
	return crowd_cap(weapon_id) if bool(mode.get("crowd", false)) else 0


# --- geometry ---------------------------------------------------------------


static func on_screen_scale(size: Vector2i) -> float:
	return float(size.y) / LOGICAL_CANVAS.y * COMBAT_CAMERA_ZOOM


static func ui_scale(size: Vector2i) -> float:
	return float(size.y) / LOGICAL_CANVAS.y


static func hud_band_rect(size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(float(size.x), float(size.y) * HUD_BAND_HEIGHT_RATIO))


static func state_band_rect(size: Vector2i) -> Rect2:
	var height := float(size.y) * STATE_BAND_HEIGHT_RATIO
	return Rect2(Vector2(0.0, float(size.y) - height), Vector2(float(size.x), height))


## Everything between the HUD strip and the state caption.
static func body_rect(size: Vector2i) -> Rect2:
	var top := hud_band_rect(size).end.y
	return Rect2(Vector2(0.0, top), Vector2(float(size.x), state_band_rect(size).position.y - top))


static func player_column_rect(size: Vector2i) -> Rect2:
	var body := body_rect(size)
	return Rect2(body.position, Vector2(float(size.x) * PLAYER_COLUMN_WIDTH_RATIO, body.size.y))


static func hazard_column_rect(size: Vector2i) -> Rect2:
	var body := body_rect(size)
	var width := float(size.x) * HAZARD_COLUMN_WIDTH_RATIO
	return Rect2(Vector2(float(size.x) - width, body.position.y), Vector2(width, body.size.y))


static func effect_zone(size: Vector2i) -> Rect2:
	var body := body_rect(size)
	var left := player_column_rect(size).end.x
	var right := hazard_column_rect(size).position.x
	return Rect2(Vector2(left, body.position.y), Vector2(right - left, body.size.y))


static func effect_origin(size: Vector2i) -> Vector2:
	return effect_zone(size).get_center()


## The hero at the Player's combat visual scale, centred in its column.
static func player_sprite_rect(size: Vector2i) -> Rect2:
	var column := player_column_rect(size)
	var side := PLAYER_SPRITE_SOURCE_PX * PLAYER_VISUAL_SCALE * on_screen_scale(size)
	return Rect2(column.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)


## The part of the drawn hero frame that carries pixels: the full frame pads
## the character with transparency, and the readability probe measures the
## character, not the padding.
static func player_used_rect(size: Vector2i) -> Rect2:
	var drawn := player_sprite_rect(size)
	var texture: Texture2D = load(PLAYER_SPRITE)
	if texture == null:
		return drawn
	var image := texture.get_image()
	if image == null or image.is_empty():
		return drawn
	var used := image.get_used_rect()
	var ratio := drawn.size.x / float(image.get_width())
	return Rect2(drawn.position + Vector2(used.position) * ratio, Vector2(used.size) * ratio)


static func hazard_rects(size: Vector2i) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var column := hazard_column_rect(size)
	var side := HAZARD_LOGICAL_SIZE * on_screen_scale(size)
	for ratio in HAZARD_TOP_RATIOS:
		rects.append(Rect2(
			Vector2(column.get_center().x - side * 0.5, column.position.y + column.size.y * ratio),
			Vector2(side, side)
		))
	return rects


static func hazard_stripe_rects(rect: Rect2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var stripe := rect.size.y / float(HAZARD_STRIPES * 2)
	for index in HAZARD_STRIPES:
		rects.append(Rect2(rect.position.x, rect.position.y + float(index * 2) * stripe, rect.size.x, stripe))
	return rects


## A crowd grid across the effect zone, so every crowd member stands where the
## effect draws and the crowd read is measured against the effect itself.
static func crowd_positions(size: Vector2i, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var zone := effect_zone(size)
	var rows := int(ceil(float(count) / float(CROWD_COLUMNS)))
	for index in count:
		var column := index % CROWD_COLUMNS
		var row := index / CROWD_COLUMNS
		positions.append(zone.position + Vector2(
			zone.size.x * (float(column) + 0.5) / float(CROWD_COLUMNS),
			zone.size.y * (float(row) + 0.5) / float(rows)
		))
	return positions


static func crowd_radius(size: Vector2i) -> float:
	return maxf(2.0, CROWD_LOGICAL_RADIUS * on_screen_scale(size))


static func caption_margin(size: Vector2i) -> float:
	return maxf(2.0, float(size.y) * CAPTION_MARGIN_RATIO)


static func mode_swatch_rect(size: Vector2i) -> Rect2:
	var band := state_band_rect(size)
	var side := band.size.y * 0.56
	return Rect2(Vector2(band.position.x + caption_margin(size) * 2.0, band.get_center().y - side * 0.5), Vector2(side, side))


static func weapon_swatch_rect(size: Vector2i) -> Rect2:
	var mode_rect := mode_swatch_rect(size)
	return Rect2(mode_rect.position + Vector2(mode_rect.size.x + caption_margin(size), 0.0), mode_rect.size)


static func caption_text(entry: Dictionary, beat_seconds_value: float, crowd: int, mode: Dictionary, veil_alpha: float) -> String:
	var size := viewport_size(str(entry["viewport"]))
	var veil := "NONE" if is_zero_approx(veil_alpha) else "%.2f" % veil_alpha
	return "%s · %s · %dx%d · %s %.2fs · SHAKE %s · CROWD %d · VEIL %s" % [
		key_for(str(entry["weapon_id"])).to_upper(),
		str(mode.get("label", "")),
		size.x, size.y,
		str(entry["beat"]).to_upper(),
		beat_seconds_value,
		"ON" if bool(mode.get("screen_shake", true)) else "OFF",
		crowd,
		veil,
	]


static func caption_font_size(size: Vector2i, text: String) -> int:
	var band := state_band_rect(size)
	var left := weapon_swatch_rect(size).end.x + caption_margin(size) * 2.0
	return TEXT_FIT.fitted_font_size(text, maxi(6, int(band.size.y * 0.62)), 6, band.end.x - left - caption_margin(size) * 2.0)


static func caption_text_rect(size: Vector2i, text: String) -> Rect2:
	var band := state_band_rect(size)
	var font_size := caption_font_size(size, text)
	var text_size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var left := weapon_swatch_rect(size).end.x + caption_margin(size) * 2.0
	return Rect2(Vector2(left, band.get_center().y - text_size.y * 0.5), text_size)


static func hud_font_size(size: Vector2i) -> int:
	return maxi(6, int(float(HUD_FONT_LOGICAL) * ui_scale(size)))


## A floor pixel nothing draws over: the bottom of the hero column, under the
## sprite. It is the reference every contrast probe compares against.
static func floor_probe(size: Vector2i) -> Vector2i:
	var column := player_column_rect(size)
	return Vector2i(roundi(column.position.x + column.size.x * 0.5), roundi(column.end.y - 3.0))


static func hud_background_probe(size: Vector2i) -> Vector2i:
	var band := hud_band_rect(size)
	return Vector2i(roundi(band.end.x - 4.0), roundi(band.end.y - 4.0))


# --- readability probes -----------------------------------------------------


static func luma(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


static func color_near(actual: Color, expected: Color, tolerance: float = SWATCH_TOLERANCE) -> bool:
	return absf(actual.r - expected.r) <= tolerance \
			and absf(actual.g - expected.g) <= tolerance \
			and absf(actual.b - expected.b) <= tolerance


## Fraction of the sampled pixels inside `rect` whose luma differs from
## `reference` by at least `minimum`.
static func contrast_ratio(image: Image, rect: Rect2, reference: Color, minimum: float, stride: int = PROBE_STRIDE) -> float:
	var reference_luma := luma(reference)
	var sampled := 0
	var contrasting := 0
	var x_start := maxi(0, int(rect.position.x))
	var y_start := maxi(0, int(rect.position.y))
	var x_end := mini(image.get_width(), int(rect.end.x))
	var y_end := mini(image.get_height(), int(rect.end.y))
	var y := y_start
	while y < y_end:
		var x := x_start
		while x < x_end:
			sampled += 1
			if absf(luma(image.get_pixel(x, y)) - reference_luma) >= minimum:
				contrasting += 1
			x += stride
		y += stride
	return float(contrasting) / float(maxi(sampled, 1))


## Fraction of the sampled pixels whose alpha reaches the opaque threshold: the
## measurement behind `quality.max_viewport_coverage_ratio`.
static func opaque_coverage_ratio(image: Image, stride: int = COVERAGE_STRIDE) -> float:
	var sampled := 0
	var opaque := 0
	var y := 0
	while y < image.get_height():
		var x := 0
		while x < image.get_width():
			sampled += 1
			if image.get_pixel(x, y).a >= COVERAGE_ALPHA_MIN:
				opaque += 1
			x += stride
		y += stride
	return float(opaque) / float(maxi(sampled, 1))


## The readability record for one decoded frame. Every number is recomputed by
## the gate from the committed PNG, so the manifest cannot claim what the
## picture does not show.
static func readability_report(image: Image, entry: Dictionary) -> Dictionary:
	var size := image.get_size()
	var floor_color := image.get_pixelv(floor_probe(size))
	var hud_background := image.get_pixelv(hud_background_probe(size))
	var hazards: Array = []
	for hazard in hazard_rects(size):
		var stripe := hazard_stripe_rects(hazard)[0]
		var pixel := image.get_pixelv(Vector2i(roundi(stripe.get_center().x), roundi(stripe.get_center().y)))
		hazards.append({
			"contrast": snappedf(absf(luma(pixel) - luma(floor_color)), 0.001),
			"hue_spread": snappedf(pixel.r - pixel.b, 0.001),
			"warm": pixel.r > pixel.g and pixel.g > pixel.b,
		})
	var mode := mode_spec(str(entry["mode"]))
	var weapon := weapon_spec(str(entry["weapon_id"]))
	var mode_pixel := image.get_pixelv(Vector2i(mode_swatch_rect(size).get_center()))
	var weapon_pixel := image.get_pixelv(Vector2i(weapon_swatch_rect(size).get_center()))
	return {
		"hud_contrast_ratio": snappedf(contrast_ratio(image, hud_band_rect(size), hud_background, HUD_CONTRAST_MIN), 0.0001),
		"player_contrast_ratio": snappedf(contrast_ratio(image, player_used_rect(size), floor_color, PLAYER_CONTRAST_MIN), 0.0001),
		"hazards": hazards,
		"mode_swatch_matches": color_near(mode_pixel, mode.get("swatch", Color.WHITE) as Color),
		"weapon_swatch_matches": color_near(weapon_pixel, weapon.get("swatch", Color.WHITE) as Color),
	}


static func readability_violations(entry: Dictionary, report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := entry_id(entry)
	if float(report.get("hud_contrast_ratio", 0.0)) < HUD_CONTRAST_MIN_RATIO:
		errors.append("%s: HUD band shows no readable HUD (contrast ratio %.4f)" % [id, float(report.get("hud_contrast_ratio", 0.0))])
	if float(report.get("player_contrast_ratio", 0.0)) < PLAYER_CONTRAST_MIN_RATIO:
		errors.append("%s: hero sprite is not readable against the floor (contrast ratio %.4f)" % [id, float(report.get("player_contrast_ratio", 0.0))])
	var hazards: Array = report.get("hazards", [])
	if hazards.size() != HAZARD_TOP_RATIOS.size():
		errors.append("%s: expected %d hazard probes, got %d" % [id, HAZARD_TOP_RATIOS.size(), hazards.size()])
	for index in hazards.size():
		var hazard := hazards[index] as Dictionary
		if float(hazard.get("contrast", 0.0)) < HAZARD_CONTRAST_MIN or not bool(hazard.get("warm", false)) \
				or float(hazard.get("hue_spread", 0.0)) < HAZARD_HUE_MIN_SPREAD:
			errors.append("%s: hazard %d is not readable through the effect (%s)" % [id, index, str(hazard)])
	if not bool(report.get("mode_swatch_matches", false)):
		errors.append("%s: frame does not carry its mode swatch" % id)
	if not bool(report.get("weapon_swatch_matches", false)):
		errors.append("%s: frame does not carry its weapon swatch" % id)
	return errors


# --- manifest validators ----------------------------------------------------


static func identity_violations(manifest: Dictionary, profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(manifest.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("manifest schema_version must be %d" % SCHEMA_VERSION)
	if str(manifest.get("class_id", "")) != CLASS_ID:
		errors.append("manifest must stay Thief-local")
	if str(manifest.get("issue", "")) != ISSUE:
		errors.append("manifest must name %s" % ISSUE)
	var expected_keys: Array[String] = []
	for raw_profile in profile.get("profiles", []) as Array:
		if raw_profile is Dictionary:
			expected_keys.append(key_for(str((raw_profile as Dictionary).get("weapon_id", ""))))
	var declared_keys := _string_list(manifest.get("canonical_keys"))
	if declared_keys != expected_keys:
		errors.append("manifest canonical_keys %s must equal the frozen profile keys %s" % [declared_keys, expected_keys])
	var spec_keys: Array[String] = []
	for weapon_id in weapon_ids():
		spec_keys.append(key_for(weapon_id))
	if spec_keys != expected_keys:
		errors.append("spec weapons %s must equal the frozen profile keys %s" % [spec_keys, expected_keys])
	var source := manifest.get("source", {}) as Dictionary
	if str(source.get("ref", "")) != SOURCE_REF:
		errors.append("manifest source.ref must pin %s" % SOURCE_REF)
	for field in ["commit_sha", "tree_sha"]:
		var value := str(source.get(field, ""))
		if value.length() != 40 or not value.is_valid_hex_number():
			errors.append("manifest source.%s must be a full SHA" % field)
	if str(source.get("commit_sha", "")) != SOURCE_COMMIT_SHA:
		errors.append("manifest source.commit_sha must pin %s" % SOURCE_COMMIT_SHA)
	if str(source.get("tree_sha", "")) != SOURCE_TREE_SHA:
		errors.append("manifest source.tree_sha must pin %s" % SOURCE_TREE_SHA)
	var engine := manifest.get("engine", {}) as Dictionary
	for field in ["godot", "rendering_method", "rendering_driver", "video_adapter", "os"]:
		if str(engine.get(field, "")).strip_edges().is_empty():
			errors.append("manifest engine.%s must be recorded" % field)
	var capture := manifest.get("capture", {}) as Dictionary
	if str(capture.get("script", "")) != CAPTURE_SCRIPT or not FileAccess.file_exists("res://" + CAPTURE_SCRIPT):
		errors.append("manifest capture.script must name the existing %s" % CAPTURE_SCRIPT)
	if str(capture.get("focused_test", "")) != FOCUSED_TEST or not FileAccess.file_exists("res://" + FOCUSED_TEST):
		errors.append("manifest capture.focused_test must name the existing %s" % FOCUSED_TEST)
	if str(capture.get("capture_command", "")) != CAPTURE_COMMAND:
		errors.append("manifest capture.capture_command must record the gated windowed command")
	if str(capture.get("test_command", "")) != TEST_COMMAND:
		errors.append("manifest capture.test_command must record the gated headless command")
	if int(capture.get("seed", -1)) != CAPTURE_SEED:
		errors.append("manifest capture.seed must record %d" % CAPTURE_SEED)
	if str(capture.get("method", "")).strip_edges().is_empty():
		errors.append("manifest capture.method must describe the capture")
	if capture.get("headless_skipped") != false:
		errors.append("manifest must record a windowed run, not a headless skip")
	var viewports := manifest.get("viewports", {}) as Dictionary
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var declared := viewports.get(str(viewport["id"]), {}) as Dictionary
		var size := viewport["size"] as Vector2i
		if int(declared.get("width", -1)) != size.x or int(declared.get("height", -1)) != size.y:
			errors.append("manifest viewports.%s must declare %dx%d" % [str(viewport["id"]), size.x, size.y])
	if _string_list(manifest.get("modes")) != MODE_IDS:
		errors.append("manifest modes must list %s" % [MODE_IDS])
	if _string_list(manifest.get("beats")) != BEAT_IDS:
		errors.append("manifest beats must list %s" % [BEAT_IDS])
	return errors


## The committed set equals the spec set exactly: nothing missing, nothing
## extra, nothing twice, every entry at the viewport size its slot demands.
static func coverage_violations(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var expected := {}
	for entry in expected_entries():
		expected[entry_id(entry)] = entry
	var seen := {}
	for raw_capture in manifest.get("captures", []) as Array:
		if not raw_capture is Dictionary:
			errors.append("capture entries must be objects")
			continue
		var capture := raw_capture as Dictionary
		var id := entry_id(capture)
		if seen.has(id):
			errors.append("capture %s is declared twice" % id)
		seen[id] = true
		if not expected.has(id):
			errors.append("capture %s is not a spec combination" % id)
			continue
		var size := viewport_size(str(capture["viewport"]))
		if int(capture.get("width", -1)) != size.x or int(capture.get("height", -1)) != size.y:
			errors.append("capture %s must declare %dx%d" % [id, size.x, size.y])
		if str(capture.get("path", "")) != capture_path(capture):
			errors.append("capture %s must be committed at %s" % [id, capture_path(capture)])
		if str(capture.get("key", "")) != key_for(str(capture["weapon_id"])):
			errors.append("capture %s must carry its canonical key" % id)
		if not is_equal_approx(float(capture.get("beat_seconds", -1.0)), beat_seconds(str(capture["weapon_id"]), str(capture["beat"]))):
			errors.append("capture %s must sample the declared %s beat" % [id, str(capture["beat"])])
		var mode := mode_spec(str(capture["mode"]))
		if int(capture.get("crowd", -1)) != crowd_count(str(capture["weapon_id"]), mode):
			errors.append("capture %s must draw the %s crowd" % [id, str(capture["mode"])])
		if capture.get("screen_shake") != bool(mode.get("screen_shake", true)):
			errors.append("capture %s must record the %s screen_shake toggle" % [id, str(capture["mode"])])
		var digest := str(capture.get("sha256", ""))
		if digest.length() != 64 or not digest.is_valid_hex_number():
			errors.append("capture %s must pin a sha256" % id)
	for id in expected:
		if not seen.has(id):
			errors.append("capture %s is missing" % id)
	var summary := manifest.get("coverage", {}) as Dictionary
	if int(summary.get("expected_frames", -1)) != expected.size() or int(summary.get("written_frames", -1)) != expected.size():
		errors.append("manifest coverage must account for all %d frames" % expected.size())
	return errors


## One committed file: present, a real PNG rather than an LFS pointer, the
## IHDR at the declared size, decoding at that size, and hashing to its pin.
static func file_violations(capture: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := entry_id(capture)
	var path := "res://" + str(capture.get("path", ""))
	var expected := Vector2i(int(capture.get("width", 0)), int(capture.get("height", 0)))
	if not FileAccess.file_exists(path):
		errors.append("%s: file is missing: %s" % [id, path])
		return errors
	if is_lfs_pointer(path):
		errors.append("%s: file is an unsmudged LFS pointer: %s" % [id, path])
		return errors
	for violation in png_ihdr_violations(path, expected):
		errors.append("%s: PNG/IHDR invalid (%s)" % [id, violation])
	var actual := FileAccess.get_sha256(path).to_lower()
	if actual != str(capture.get("sha256", "")).to_lower():
		errors.append("%s: sha256 %s does not match the pinned %s" % [id, actual, str(capture.get("sha256", ""))])
	if FileAccess.open(path, FileAccess.READ).get_length() != int(capture.get("bytes", -1)):
		errors.append("%s: byte size does not match the pinned size" % id)
	return errors


static func png_ihdr_violations(path: String, expected_size: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24:
		errors.append("truncated")
		return errors
	if file.get_buffer(8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		file.close()
		errors.append("not_png")
		return errors
	file.big_endian = true
	var ihdr_length := file.get_32()
	var chunk_type := file.get_buffer(4).get_string_from_ascii()
	var width := file.get_32()
	var height := file.get_32()
	file.close()
	if ihdr_length != 13 or chunk_type != "IHDR":
		errors.append("missing_ihdr")
	elif width != expected_size.x or height != expected_size.y:
		errors.append("ihdr_size:%dx%d expected %dx%d" % [width, height, expected_size.x, expected_size.y])
	return errors


static func is_lfs_pointer(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var expected := LFS_POINTER_PREFIX.to_utf8_buffer()
	var head := file.get_buffer(expected.size())
	file.close()
	return head == expected


## Decodes each frame and recomputes its readability record and, for the
## measured coverage, checks the frame agrees with what the manifest recorded.
func _check_files(manifest: Dictionary, errors: Array[String]) -> void:
	for raw_capture in manifest.get("captures", []) as Array:
		if not raw_capture is Dictionary:
			continue
		var capture := raw_capture as Dictionary
		var file_errors := file_violations(capture)
		errors.append_array(file_errors)
		if not file_errors.is_empty():
			continue
		var image := Image.load_from_file("res://" + str(capture.get("path", "")))
		var expected := Vector2i(int(capture.get("width", 0)), int(capture.get("height", 0)))
		if image == null or image.is_empty() or image.get_size() != expected:
			errors.append("%s: PNG does not decode at %dx%d" % [entry_id(capture), expected.x, expected.y])
			continue
		var report := readability_report(image, capture)
		errors.append_array(readability_violations(capture, report))
		var recorded := capture.get("readability", {}) as Dictionary
		for field in ["hud_contrast_ratio", "player_contrast_ratio"]:
			if absf(float(recorded.get(field, -1.0)) - float(report.get(field, 0.0))) > 0.0005:
				errors.append("%s: recorded %s %s disagrees with the frame (%s)" % [entry_id(capture), field, str(recorded.get(field)), str(report.get(field))])
		var measured := capture.get("measured", {}) as Dictionary
		var coverage := float(measured.get("opaque_coverage_ratio", -1.0))
		if coverage < 0.0 or coverage > Contract.MAX_VIEWPORT_COVERAGE_RATIO:
			errors.append("%s: measured opaque coverage %.4f is outside 0..%.2f" % [entry_id(capture), coverage, Contract.MAX_VIEWPORT_COVERAGE_RATIO])
		if measured.get("effect_inside_zone") != true:
			errors.append("%s: the effect must stay inside the effect zone" % entry_id(capture))
		if float(measured.get("veil_alpha", 1.0)) > MAX_OVERLAY_ALPHA:
			errors.append("%s: veil alpha over the %.2f ceiling" % [entry_id(capture), MAX_OVERLAY_ALPHA])
		if not bool(mode_spec(str(capture["mode"])).get("veil", true)) and not is_zero_approx(float(measured.get("veil_alpha", 1.0))):
			errors.append("%s: photosensitivity-safe frame must draw no veil" % entry_id(capture))


## The class manifest's quality block, per weapon, against the contract and
## against what was measured: the declared cap covers every measured frame and
## the full-envelope sweep, and the flash declaration matches the pack's own
## backdrop envelope.
static func quality_violations(class_manifest: Dictionary, manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for violation in Contract.violations(CLASS_ID, class_manifest):
		if Contract.gate_of(violation) == "quality":
			errors.append("contract: %s" % violation)
	var measured_by_weapon := {}
	for raw_capture in manifest.get("captures", []) as Array:
		if not raw_capture is Dictionary:
			continue
		var capture := raw_capture as Dictionary
		var weapon_id := str(capture.get("weapon_id", ""))
		var coverage := float((capture.get("measured", {}) as Dictionary).get("opaque_coverage_ratio", 0.0))
		measured_by_weapon[weapon_id] = maxf(float(measured_by_weapon.get(weapon_id, 0.0)), coverage)
	var sweeps := {}
	for raw_weapon in manifest.get("weapons", []) as Array:
		if raw_weapon is Dictionary:
			var record := raw_weapon as Dictionary
			sweeps[str(record.get("weapon_id", ""))] = record
	for raw_weapon in class_manifest.get("weapons", []) as Array:
		if not raw_weapon is Dictionary:
			continue
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		var quality := weapon.get("quality", {}) as Dictionary
		var declared := float(quality.get("max_viewport_coverage_ratio", 0.0))
		var sweep := (sweeps.get(weapon_id, {}) as Dictionary).get("envelope_sweep", {}) as Dictionary
		var peak := maxf(float(measured_by_weapon.get(weapon_id, 0.0)), float(sweep.get("peak_opaque_coverage_ratio", 0.0)))
		if not sweeps.has(weapon_id) or int(sweep.get("samples", 0)) <= 0:
			errors.append("%s: manifest must record a full-envelope coverage sweep" % weapon_id)
		if peak <= 0.0:
			errors.append("%s: measured coverage must be positive; the effect must actually draw" % weapon_id)
		if declared < peak:
			errors.append("%s: declared max_viewport_coverage_ratio %.3f is under the measured %.4f" % [weapon_id, declared, peak])
		if not is_zero_approx(float(quality.get("full_screen_flash_hz", -1.0))):
			errors.append("%s: the scene authors no full-screen surface, full_screen_flash_hz must be 0.0" % weapon_id)
		if not is_zero_approx(float(quality.get("max_flash_coverage_ratio", -1.0))):
			errors.append("%s: the scene authors no full-screen surface, max_flash_coverage_ratio must be 0.0" % weapon_id)
		var reduced := str(quality.get("reduced_motion_substitute", ""))
		if not reduced.contains("screen_shake"):
			errors.append("%s: reduced_motion_substitute must name the shipped screen_shake toggle it rides on" % weapon_id)
	return errors


## The class manifest links the package: the certification block names this
## manifest, the report, the renderer and the gate, and pins the same source.
static func class_manifest_link_violations(class_manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var evidence := class_manifest.get("evidence", {}) as Dictionary
	var certification := evidence.get("certification", {}) as Dictionary
	if certification.is_empty():
		errors.append("class manifest must carry evidence.certification")
		return errors
	var expected := {
		"issue": ISSUE,
		"capture_manifest": MANIFEST_PATH.trim_prefix("res://"),
		"readability_report": READABILITY_REPORT,
		"capture_script": CAPTURE_SCRIPT,
		"focused_test": FOCUSED_TEST,
		"source_ref": SOURCE_REF,
		"source_commit_sha": SOURCE_COMMIT_SHA,
		"source_tree_sha": SOURCE_TREE_SHA,
	}
	for field in expected:
		if str(certification.get(field, "")) != str(expected[field]):
			errors.append("class manifest evidence.certification.%s must be %s" % [field, str(expected[field])])
	for field in ["capture_manifest", "readability_report", "capture_script", "focused_test"]:
		if not FileAccess.file_exists("res://" + str(certification.get(field, ""))):
			errors.append("class manifest evidence.certification.%s must exist" % field)
	if _string_list(certification.get("modes")) != MODE_IDS:
		errors.append("class manifest evidence.certification.modes must list %s" % [MODE_IDS])
	var viewports := certification.get("viewports", {}) as Dictionary
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		if str(viewports.get(str(viewport["id"]), "")) != "%dx%d" % [size.x, size.y]:
			errors.append("class manifest evidence.certification.viewports.%s must be %dx%d" % [str(viewport["id"]), size.x, size.y])
	return errors


## The class shard is empty: Thief claims no exemption from any gate.
static func adoption_violations() -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADOPTION_SHARD_PATH))
	if not parsed is Dictionary:
		errors.append("adoption shard must parse")
		return errors
	var shard := parsed as Dictionary
	if str(shard.get("class_id", "")) != CLASS_ID:
		errors.append("adoption shard must be Thief-local")
	var gaps: Variant = shard.get("adoption_gaps")
	if not gaps is Dictionary or not (gaps as Dictionary).is_empty():
		errors.append("adoption shard must declare no gap, got %s" % str(gaps))
	return errors


# --- live scene driving (shared with the renderer) --------------------------


static func instantiate_scene(weapon_id: String) -> Node2D:
	return (weapon_spec(weapon_id)["scene"] as PackedScene).instantiate() as Node2D


static func capture_handles() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


## The shipped motion toggle, exactly as main.gd publishes it.
static func apply_mode(tree: SceneTree, mode: Dictionary) -> void:
	tree.root.set_meta("screen_shake", bool(mode.get("screen_shake", true)))


static func reset_mode(tree: SceneTree) -> void:
	tree.root.set_meta("screen_shake", true)


## Drives the shipped scene to `seconds` with fixed steps and holds it there.
static func seek_scene(scene: Node2D, registry, seconds: float) -> void:
	scene.begin(registry, capture_handles(), 0)
	var remaining := seconds
	while remaining > SEEK_STEP:
		scene.step(SEEK_STEP)
		remaining -= SEEK_STEP
	if remaining > 0.0:
		scene.step(remaining)
	scene.set_process(false)


## The Thief scenes author no arena-wide surface, so the photosensitivity-safe
## variant has nothing to drop; the gate proves that with
## full_screen_surface_count() instead of assuming it.
static func apply_veil(_scene: Node2D, _mode: Dictionary) -> void:
	pass


static func hide_veil(_scene: Node2D) -> void:
	pass


static func veil_alpha(_weapon_id: String, _seconds: float, _mode: Dictionary) -> float:
	return 0.0


## Full-screen surfaces a driven scene carries: a CanvasLayer, a node flagged
## as a fullscreen layer, or a top-level CanvasItem fitted to the viewport.
static func full_screen_surface_count(scene: Node) -> int:
	var count := 0
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CanvasLayer or node.get_meta("fullscreen_layer", false) == true:
			count += 1
		elif node != scene and node is CanvasItem and (node as CanvasItem).top_level:
			count += 1
		for child in node.get_children():
			pending.append(child)
	return count


## Places the scene at its on-screen scale on the effect origin.
static func place_scene(scene: Node2D, size: Vector2i) -> void:
	scene.scale = Vector2.ONE * on_screen_scale(size)
	scene.position = effect_origin(size)


## Drawn bounds of the formation in viewport pixels.
static func content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.visible or sprite.modulate.a <= 0.0:
			continue
		if sprite.texture == null:
			continue
		var local := Rect2(sprite.offset, Vector2(sprite.texture.get_size()))
		var item: Rect2 = scene.transform * (sprite.transform * local)
		bounds = item if not found else bounds.merge(item)
		found = true
	return bounds


static func formation_signature(scene: Node2D) -> String:
	var parts: Array[String] = []
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.visible:
			continue
		parts.append("%.3f:%.3f:%.3f:%.3f:%.3f" % [
			sprite.position.x, sprite.position.y, sprite.scale.x, sprite.rotation, sprite.modulate.a,
		])
	return "|".join(parts)


## Headless half of the live claim: at every committed beat the shipped scene,
## driven exactly as the renderer drives it, draws inside the effect zone at
## both extreme viewports, the reduced-motion variant preserves the normal
## formation and timing, and a seek repeats.
func _check_live_composition(registry, errors: Array[String]) -> void:
	for weapon_id in weapon_ids():
		for beat_id in BEAT_IDS:
			var seconds := beat_seconds(weapon_id, beat_id)
			var phase := Pack.phase_at(weapon_id, seconds)
			_expect(str(phase.get("name", "")) == beat_id, "%s %s beat %.2fs must sample its own phase, got %s" % [weapon_id, beat_id, seconds, phase], errors)
			var signatures := {}
			for mode_id in MODE_IDS:
				var mode := mode_spec(mode_id)
				for viewport_id in ["648p", "2k"]:
					var size := viewport_size(viewport_id)
					var scene := instantiate_scene(weapon_id)
					root.add_child(scene)
					apply_mode(self, mode)
					seek_scene(scene, registry, seconds)
					apply_veil(scene, mode)
					place_scene(scene, size)
					var bounds := content_bounds(scene)
					var context := "%s/%s/%s/%s" % [weapon_id, mode_id, viewport_id, beat_id]
					_expect(bounds.has_area(), "%s must draw visible effect content" % context, errors)
					_expect(effect_zone(size).grow(0.5).encloses(bounds), "%s effect bounds %s must stay inside %s" % [context, bounds, effect_zone(size)], errors)
					_expect(full_screen_surface_count(scene) == 0, "%s must author no full-screen surface" % context, errors)
					if viewport_id == "648p":
						signatures[mode_id] = formation_signature(scene)
					scene.free()
			_expect(signatures[MODE_NORMAL] == signatures[MODE_REDUCED_MOTION], "%s %s reduced-motion variant must preserve the normal formation and timing" % [weapon_id, beat_id], errors)
			_expect(signatures[MODE_NORMAL] == signatures[MODE_PHOTOSENSITIVITY_SAFE], "%s %s photosensitivity-safe variant must preserve the normal formation" % [weapon_id, beat_id], errors)
			_expect(not str(signatures[MODE_NORMAL]).is_empty(), "%s %s formation signature must not be empty" % [weapon_id, beat_id], errors)
			var repeat := instantiate_scene(weapon_id)
			root.add_child(repeat)
			apply_mode(self, mode_spec(MODE_NORMAL))
			seek_scene(repeat, registry, seconds)
			place_scene(repeat, viewport_size("648p"))
			_expect(formation_signature(repeat) == signatures[MODE_NORMAL], "%s seek to %.2fs must be deterministic" % [weapon_id, seconds], errors)
			_expect(not repeat.is_processing(), "%s seek must leave the scene held at its beat" % weapon_id, errors)
			repeat.free()
	reset_mode(self)


## No arena-wide surface exists anywhere in the cast, and the formation's own
## visibility never strobes: every element's alpha over the whole timeline is
## sampled at 240 Hz and rises through half its peak at most once per second
## beyond the WCAG 2.3.1 general threshold — which for Thief is never.
func _check_photosensitivity(errors: Array[String]) -> void:
	for weapon_id in weapon_ids():
		var report := backdrop_report(weapon_id)
		_expect(int(report["surfaces"]) == 0, "%s must author no full-screen surface, found %d" % [weapon_id, int(report["surfaces"])], errors)
		_expect(float(report["max_element_rise_hz"]) <= Contract.MAX_FLASH_HZ, "%s element alpha rises at %.2f Hz over %.1f Hz" % [weapon_id, float(report["max_element_rise_hz"]), Contract.MAX_FLASH_HZ], errors)


## Full-screen surfaces (always zero for Thief) and the fastest alpha rise rate
## of any formation element over the cast, from the pack's own envelope.
static func backdrop_report(weapon_id: String) -> Dictionary:
	var duration := Pack.timeline_seconds(weapon_id)
	var count := int((Pack.weapon_config(weapon_id).get("formation", {}) as Dictionary).get("count", 0))
	var peaks: Array[float] = []
	var samples: Array = []
	for index in count:
		peaks.append(0.0)
		samples.append(PackedFloat32Array())
	var elapsed := 0.0
	while elapsed <= duration:
		var phase := Pack.phase_at(weapon_id, elapsed)
		var points := Pack.formation_points(weapon_id, str(phase.get("name", "")), float(phase.get("progress", 0.0)))
		for index in mini(count, points.size()):
			var alpha := float((points[index] as Dictionary).get("alpha", 0.0))
			(samples[index] as PackedFloat32Array).append(alpha)
			peaks[index] = maxf(peaks[index], alpha)
		elapsed += 1.0 / 240.0
	var max_hz := 0.0
	for index in count:
		var trigger := peaks[index] * 0.5
		var rises := 0
		var above := false
		for value in samples[index] as PackedFloat32Array:
			if value > trigger and not above:
				rises += 1
				above = true
			elif value <= trigger:
				above = false
		max_hz = maxf(max_hz, float(rises) / maxf(duration, 0.0001))
	var scene := (weapon_spec(weapon_id)["scene"] as PackedScene).instantiate()
	var surfaces := full_screen_surface_count(scene)
	scene.free()
	return {"peak": 0.0, "rises": 0, "surfaces": surfaces, "max_element_rise_hz": snappedf(max_hz, 0.01), "duration": duration}


# --- negatives --------------------------------------------------------------


## Every validator is data-driven so it can be shown to reject: a dropped mode,
## a substituted key, a missing file, an LFS pointer, a wrong size, a wrong
## hash, an understated coverage cap and a non-empty shard all go red.
func _check_negatives(manifest: Dictionary, class_manifest: Dictionary, profile: Dictionary, errors: Array[String]) -> void:
	_expect(coverage_violations(manifest).is_empty(), "the committed coverage must pass before negatives are meaningful", errors)

	var missing_mode := manifest.duplicate(true)
	var trimmed: Array = []
	for raw_capture in missing_mode.get("captures", []) as Array:
		if str((raw_capture as Dictionary).get("mode", "")) != MODE_PHOTOSENSITIVITY_SAFE:
			trimmed.append(raw_capture)
	missing_mode["captures"] = trimmed
	_expect_red(coverage_violations(missing_mode), "a dropped presentation mode", errors)

	var missing_key := manifest.duplicate(true)
	var swapped := (missing_key["captures"] as Array)[0] as Dictionary
	swapped["weapon_id"] = "thief_coin_pouch_v2"
	_expect_red(coverage_violations(missing_key), "a substituted weapon key", errors)

	var wrong_keys := manifest.duplicate(true)
	wrong_keys["canonical_keys"] = ["thief/thief_coin_pouch", "thief/thief_shadow_cloak"]
	_expect_red(identity_violations(wrong_keys, profile), "a missing canonical key", errors)

	var wrong_source := manifest.duplicate(true)
	(wrong_source["source"] as Dictionary)["commit_sha"] = "0".repeat(40)
	_expect_red(identity_violations(wrong_source, profile), "an unpinned source commit", errors)

	var first := ((manifest["captures"] as Array)[0] as Dictionary).duplicate(true)
	var absent := first.duplicate(true)
	absent["path"] = str(first["path"]).replace(".png", "_missing.png")
	_expect_red(file_violations(absent), "a missing frame", errors)

	var wrong_size := first.duplicate(true)
	wrong_size["width"] = int(first["width"]) - 1
	_expect_red(file_violations(wrong_size), "a frame declared at the wrong size", errors)

	var wrong_hash := first.duplicate(true)
	wrong_hash["sha256"] = "f".repeat(64)
	_expect_red(file_violations(wrong_hash), "a frame with a wrong hash", errors)

	var pointer_path := "user://fan3941_thief_pointer_probe.png"
	var pointer := FileAccess.open(pointer_path, FileAccess.WRITE)
	if pointer == null:
		errors.append("pointer probe could not be written")
	else:
		pointer.store_string("%s\noid sha256:%s\nsize 65536\n" % [LFS_POINTER_PREFIX, "a".repeat(64)])
		pointer.close()
		_expect(is_lfs_pointer(pointer_path), "the pointer probe must read as an LFS pointer", errors)
		_expect_red(png_ihdr_violations(pointer_path, Vector2i(1152, 648)), "an unsmudged LFS pointer", errors)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pointer_path))

	var understated := class_manifest.duplicate(true)
	((understated["weapons"] as Array)[0] as Dictionary)["quality"]["max_viewport_coverage_ratio"] = 0.0001
	_expect_red(quality_violations(understated, manifest), "an understated coverage cap", errors)

	var undeclared := class_manifest.duplicate(true)
	((undeclared["weapons"] as Array)[0] as Dictionary).erase("quality")
	_expect_red(quality_violations(undeclared, manifest), "a missing quality block", errors)

	var unlinked := class_manifest.duplicate(true)
	(unlinked["evidence"] as Dictionary).erase("certification")
	_expect_red(class_manifest_link_violations(unlinked), "a class manifest without the certification link", errors)

	var blank := Image.create_empty(64, 36, false, Image.FORMAT_RGBA8)
	blank.fill(FLOOR_COLOR)
	_expect_red(readability_violations(first, readability_report(blank, first)), "a blank frame", errors)


# --- helpers ----------------------------------------------------------------


static func _string_list(value: Variant) -> Array[String]:
	var list: Array[String] = []
	if value is Array:
		for entry in value as Array:
			list.append(str(entry))
	return list


static func load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _expect_red(violations: Array[String], what: String, errors: Array[String]) -> void:
	if violations.is_empty():
		errors.append("%s must be rejected" % what)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Thief certification capture gate: %d frames (%d weapons x %d modes x %d viewports at the active beat, plus release/recovery at %s) verified with readability probes, coverage measurement, quality declaration, empty adoption shard and negatives." % [
			expected_entries().size(), WEAPONS.size(), MODES.size(), VIEWPORTS.size(), BEAT_VIEWPORT,
		])
		quit(0)
		return
	for error in errors:
		push_error("Thief certification capture gate: %s" % error)
	quit(1)
