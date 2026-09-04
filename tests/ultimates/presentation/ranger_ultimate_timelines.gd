extends SceneTree

## Layout spec and focused gate for FAN-3889's live Ranger four-viewport
## capture package.
##
## The package is engineering evidence, not new art: every panel is a real
## render of a shipped Ranger ultimate scene, driven through `begin()`/`step()`
## exactly like the runtime drives it. This file owns the geometry the capture
## script draws, so the committed sheets and the gate can never describe
## different pictures.
##
## Four presentation modes share one beat per weapon, because a reduced-motion
## variant is a variant and not a second timeline: comparing the row only means
## something when every panel samples the same moment.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Pack := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_presentation_pack.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const TEXT_FIT := preload("res://tests/ultimates/presentation/contact_sheet_text_fit.gd")

const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/ranger/manifest.json"
const CAPTURE_SCRIPT := "tests/ultimates/presentation/ranger_ultimate_contact_capture.gd"

## Derived evidence, so it lives in the LFS zone the repository storage policy
## mandates for changed design binaries — never next to the hand-written docs.
const CAPTURE_ROOT := "res://docs/design/reference-assets-lfs/ranger-ultimate-timelines-fan3889"
const CAPTURES := [
	{"name": "648p", "path": CAPTURE_ROOT + "/ranger_ultimate_timelines_648p.png", "size": Vector2i(1152, 648)},
	{"name": "720p", "path": CAPTURE_ROOT + "/ranger_ultimate_timelines_720p.png", "size": Vector2i(1280, 720)},
	{"name": "1080p", "path": CAPTURE_ROOT + "/ranger_ultimate_timelines_1080p.png", "size": Vector2i(1920, 1080)},
	{"name": "2k", "path": CAPTURE_ROOT + "/ranger_ultimate_timelines_2k.png", "size": Vector2i(2560, 1440)},
]

## The four presentation modes, one sheet column each. `motion` drives the
## shipped `screen_shake` root meta the Ranger driver already reads; `veil`
## suppresses the arena-wide backdrop for the photosensitivity-safe variant.
## Neither knob edits a scene: both are capture-side presentation state.
const MODE_NORMAL := "normal"
const MODE_CROWDED := "crowded"
const MODE_REDUCED_MOTION := "reduced_motion"
const MODE_PHOTOSENSITIVITY_SAFE := "photosensitivity_safe"
const MODES := [
	{"id": MODE_NORMAL, "label": "NORMAL", "crowd": 0, "motion": true, "veil": true},
	{"id": MODE_CROWDED, "label": "CROWDED", "crowd": Pack.CROWD_CAP, "motion": true, "veil": true},
	{"id": MODE_REDUCED_MOTION, "label": "REDUCED MOTION", "crowd": 0, "motion": false, "veil": true},
	{"id": MODE_PHOTOSENSITIVITY_SAFE, "label": "PHOTOSENSITIVITY-SAFE", "crowd": 0, "motion": false, "veil": false},
]
const REQUIRED_MODE_IDS: Array[String] = [
	MODE_NORMAL, MODE_CROWDED, MODE_REDUCED_MOTION, MODE_PHOTOSENSITIVITY_SAFE,
]

## One sheet row per canonical weapon. The beat sits inside `active`, where each
## formation is at its widest and the trio is easiest to tell apart.
const PACKS := [
	{
		"weapon_id": Pack.MOON_CROSSBOW,
		"scene": preload("res://scenes/vfx/ultimates/ranger/RangerMoonCrossbowMoonHunt.tscn"),
		"label": "MOON CROSSBOW",
		"beat": 1.60,
		"color": Color(0.82, 0.88, 1.0),
	},
	{
		"weapon_id": Pack.STORM_LONGBOW,
		"scene": preload("res://scenes/vfx/ultimates/ranger/RangerStormLongbowStormEye.tscn"),
		"label": "STORM LONGBOW",
		"beat": 1.70,
		"color": Color(0.45, 0.92, 1.0),
	},
	{
		"weapon_id": Pack.HUNTER_TRAP,
		"scene": preload("res://scenes/vfx/ultimates/ranger/RangerHunterTrapGrandTrap.tscn"),
		"label": "HUNTER TRAP",
		"beat": 2.00,
		"color": Color(0.48, 0.95, 0.72),
	},
]

const PLAYER_SPRITE := Pack.CAST_POSE_ASSET
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]

## Sheet chrome.
const SHEET_TITLE := "RANGER WEAPON ULTIMATES — LIVE FOUR-VIEWPORT CAPTURE"
const SHEET_TITLE_Y_RATIO := 0.022
const SHEET_TITLE_FONT_RATIO := 0.030
const SHEET_TEXT_MARGIN := 8.0
const BACKGROUND := Color(0.028, 0.036, 0.046, 1.0)
const PANEL_TINT := Color(0.055, 0.070, 0.088, 1.0)

## Grid: four mode columns by three weapon rows.
const GRID_MARGIN_X_RATIO := 0.012
const GRID_TOP_RATIO := 0.085
const GRID_BOTTOM_RATIO := 0.985
const GRID_GAP_X_RATIO := 0.006
const GRID_GAP_Y_RATIO := 0.010
const PANEL_LABEL_FONT_RATIO := 0.014
const PANEL_MARGIN_RATIO := 0.006

## Arena bands, in arena-local ratios. The effect owns the middle; the HUD strip,
## the player column and the hazard column are the readability claim this package
## exists to make, so the effect zone is disjoint from all three.
const HUD_BAND_HEIGHT_RATIO := 0.14
const STATE_BAND_HEIGHT_RATIO := 0.11
const PLAYER_COLUMN_WIDTH_RATIO := 0.18
const HAZARD_COLUMN_WIDTH_RATIO := 0.14
const PLAYER_HEIGHT_RATIO := 0.40
const HAZARD_HEIGHT_RATIO := 0.18
const HAZARD_TOP_RATIOS: Array[float] = [0.20, 0.56]
const HUD_TEXT := "HP 62/120    ULT"
const HUD_BAND_COLOR := Color(0.10, 0.13, 0.17, 0.92)
const HUD_TEXT_COLOR := Color(0.86, 0.92, 0.98)
const STATE_BAND_COLOR := Color(0.08, 0.10, 0.13, 0.94)
const STATE_TEXT_COLOR := Color(0.72, 0.80, 0.88)
const FLOOR_COLOR := Color(0.043, 0.056, 0.068, 1.0)
const HAZARD_COLOR := Color(0.98, 0.62, 0.20, 0.95)
const CROWD_COLOR := Color(0.72, 0.36, 0.42, 0.92)

## Readability floor, shared with the FAN-1474 Ranger presentation test: below
## six drawn pixels a silhouette stops being a silhouette.
const MIN_READABLE_PIXELS := 6.0

## Translucency ceiling for the arena-wide veil. The HUD strip, player and
## hazards read through the backdrop only while it stays a tint; above this it
## becomes an occluder and the readability claim is false.
const MAX_OVERLAY_ALPHA := 0.35

## Deterministic seek: fixed steps, so a beat is reached by the same arithmetic
## in the gate and in the capture script.
const SEEK_STEP := 1.0 / 120.0

## Photosensitivity sweep over the whole envelope, and the WCAG 2.3.1 ceilings
## the shared contract already owns.
const FLASH_SWEEP_STEP := 1.0 / 240.0
const FLASH_TRIGGER_RATIO := 0.5

const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"


class HandleProbe extends RefCounted:
	var released := 0

	func release() -> void:
		released += 1


func _initialize() -> void:
	var errors: Array[String] = []
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)

	_check_declaration(errors)
	_check_layout(errors)
	_check_live_composition(registry, errors)
	_check_reduced_motion_parity(registry, errors)
	_check_photosensitivity(errors)
	_check_evidence(errors)
	_check_manifest(errors)
	_check_probes_go_red(errors)

	_finish(errors)


## The declared capture set: four viewports, three canonical weapons, four modes.
func _check_declaration(errors: Array[String]) -> void:
	for violation in capture_set_violations(CAPTURES):
		errors.append(violation)
	for violation in weapon_set_violations(PACKS):
		errors.append(violation)
	for violation in mode_set_violations(MODES):
		errors.append(violation)


## Geometry only: every panel, label and arena band stays where the capture
## script will draw it, and the effect zone never overlaps the readability bands.
func _check_layout(errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture["size"] as Vector2i
		var name := str(capture["name"])
		var sheet := Rect2(Vector2.ZERO, Vector2(size))
		var text_zone := sheet.grow(-SHEET_TEXT_MARGIN)
		TEXT_FIT.check_fits(errors, name, SHEET_TITLE, sheet_title_rect(size), text_zone, "sheet")
		for column in MODES.size():
			for row in PACKS.size():
				var pack := PACKS[row] as Dictionary
				var mode := MODES[column] as Dictionary
				var context := "%s %s %s" % [name, str(pack["weapon_id"]), str(mode["id"])]
				var panel := panel_rect(size, column, row)
				_expect(sheet.encloses(panel), "%s panel %s must stay inside the sheet" % [context, panel], errors)
				var label := panel_label_rect(size, column, row)
				TEXT_FIT.check_fits(errors, context, panel_label_text(pack, mode), label, panel, "panel")
				var arena := arena_rect(size, column, row)
				_expect(arena.size.x > 0 and arena.size.y > 0, "%s arena must have area" % context, errors)
				_expect(
					panel.grow(0.5).encloses(Rect2(arena)),
					"%s arena %s must stay inside its panel %s" % [context, arena, panel],
					errors
				)
				var arena_size := arena.size
				var effect := effect_zone(arena_size)
				var bands := readability_bands(arena_size)
				for band_name in bands:
					var band: Rect2 = bands[band_name]
					_expect(
						Rect2(Vector2.ZERO, Vector2(arena_size)).encloses(band),
						"%s %s %s must stay inside the arena" % [context, band_name, band],
						errors
					)
					_expect(
						not effect.intersects(band),
						"%s effect zone %s must stay clear of the %s %s" % [context, effect, band_name, band],
						errors
					)
					_expect(
						minf(band.size.x, band.size.y) >= MIN_READABLE_PIXELS,
						"%s %s %s falls under the %.0f px readability floor"
						% [context, band_name, band.size, MIN_READABLE_PIXELS],
						errors
					)
				var player := player_sprite_rect(arena_size)
				_expect(
					minf(player.size.x, player.size.y) >= MIN_READABLE_PIXELS,
					"%s drawn player %s falls under the %.0f px readability floor"
					% [context, player.size, MIN_READABLE_PIXELS],
					errors
				)
				var caption := state_text(pack, mode)
				TEXT_FIT.check_fits(
					errors,
					context,
					caption,
					state_text_rect(arena_size, pack, mode),
					state_band_rect(arena_size),
					"state caption"
				)
				TEXT_FIT.check_fits(
					errors, context, HUD_TEXT, hud_text_rect(arena_size), hud_band_rect(arena_size), "HUD band"
				)


## The live half: a real scene, seeked to its beat under each mode, must fit its
## effect zone and still draw a silhouette worth reading at the smallest sheet.
func _check_live_composition(registry, errors: Array[String]) -> void:
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture["size"] as Vector2i
		for column in MODES.size():
			var mode := MODES[column] as Dictionary
			for row in PACKS.size():
				var pack := PACKS[row] as Dictionary
				var context := "%s %s %s" % [str(capture["name"]), str(pack["weapon_id"]), str(mode["id"])]
				var arena_size := arena_rect(size, column, row).size
				var scene := instantiate_scene(pack)
				root.add_child(scene)
				apply_mode(self, mode)
				seek_scene(scene, registry, float(pack["beat"]))
				apply_veil(scene, mode)
				var bounds := layout_scene(scene, arena_size)
				var zone := effect_zone(arena_size)
				_expect(bounds.has_area(), "%s must draw visible effect content" % context, errors)
				_expect(
					zone.grow(0.5).encloses(bounds),
					"%s effect content %s must stay inside %s" % [context, bounds, zone],
					errors
				)
				_expect(
					minf(bounds.size.x, bounds.size.y) >= MIN_READABLE_PIXELS,
					"%s effect content %s falls under the %.0f px readability floor"
					% [context, bounds.size, MIN_READABLE_PIXELS],
					errors
				)
				_check_veil(scene, pack, mode, context, errors)
				scene.free()
	reset_mode(self)


## The backdrop is the only full-screen surface, so it is the only thing that can
## make the HUD, player and hazards unreadable. It stays a tint in every mode and
## is gone entirely in the photosensitivity-safe variant.
func _check_veil(scene: Node2D, pack: Dictionary, mode: Dictionary, context: String, errors: Array[String]) -> void:
	var veil := scene.get_node_or_null(Pack.BACKDROP_NODE) as CanvasItem
	_expect(veil != null, "%s must author a %s node" % [context, Pack.BACKDROP_NODE], errors)
	if veil == null:
		return
	var alpha := veil.self_modulate.a if veil.visible else 0.0
	if bool(mode["veil"]):
		_expect(
			alpha <= MAX_OVERLAY_ALPHA,
			"%s backdrop alpha %.2f is over the %.2f readability ceiling" % [context, alpha, MAX_OVERLAY_ALPHA],
			errors
		)
		_expect(
			is_equal_approx(alpha, Pack.backdrop_alpha(str(pack["weapon_id"]), float(pack["beat"]))),
			"%s backdrop must draw the shipped envelope alpha" % context,
			errors
		)
	else:
		_expect(alpha == 0.0, "%s photosensitivity-safe panel must draw no backdrop" % context, errors)


## Reduced motion is a variant, not a second timeline: same beat, same phase, and
## the same drawn formation as the normal panel. Only the shake device changes.
func _check_reduced_motion_parity(registry, errors: Array[String]) -> void:
	var normal := _mode_by_id(MODE_NORMAL)
	var reduced := _mode_by_id(MODE_REDUCED_MOTION)
	_expect(
		float(normal.get("crowd", -1.0)) == float(reduced.get("crowd", -1.0)),
		"reduced-motion panel must hold the crowd of the normal panel",
		errors
	)
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var weapon_id := str(pack["weapon_id"])
		var beat := float(pack["beat"])
		var phase := Pack.phase_at(weapon_id, beat)
		_expect(
			str(phase.get("name", "")) == "active",
			"%s beat %.2fs must sample the active phase, got %s" % [weapon_id, beat, phase],
			errors
		)
		var signatures := {}
		for mode in [normal, reduced]:
			var scene := instantiate_scene(pack)
			root.add_child(scene)
			apply_mode(self, mode as Dictionary)
			seek_scene(scene, registry, beat)
			signatures[str((mode as Dictionary)["id"])] = formation_signature(scene)
			scene.free()
		_expect(
			signatures[MODE_NORMAL] == signatures[MODE_REDUCED_MOTION],
			"%s reduced-motion variant must preserve the normal formation and timing" % weapon_id,
			errors
		)
		_expect(
			not str(signatures[MODE_NORMAL]).is_empty(),
			"%s formation signature must not be empty" % weapon_id,
			errors
		)
		# A seek that does not repeat is not evidence: the sheet would depend on
		# frame pacing rather than on the beat it prints.
		var repeat := instantiate_scene(pack)
		root.add_child(repeat)
		apply_mode(self, normal)
		seek_scene(repeat, registry, beat)
		_expect(
			formation_signature(repeat) == signatures[MODE_NORMAL],
			"%s seek to %.2fs must be deterministic" % [weapon_id, beat],
			errors
		)
		_expect(not repeat.is_processing(), "%s seek must leave the scene held at its beat" % weapon_id, errors)
		repeat.free()
	reset_mode(self)


## The full envelope, not one frame: peak backdrop weight and flash rate over the
## whole cast, against the ceilings the shared visual-direction contract owns.
func _check_photosensitivity(errors: Array[String]) -> void:
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var weapon_id := str(pack["weapon_id"])
		var duration := Pack.timeline_seconds(weapon_id)
		var report := flash_report(backdrop_samples(weapon_id), duration)
		for violation in flash_violations(weapon_id, report):
			errors.append(violation)
		_expect(
			float(report.get("peak", 0.0)) > 0.0,
			"%s must actually draw its declared backdrop" % weapon_id,
			errors
		)


## The committed sheets: present, real PNGs rather than LFS pointers, and exactly
## the pixel size their slot claims.
func _check_evidence(errors: Array[String]) -> void:
	for violation in evidence_violations(CAPTURES):
		errors.append(violation)


## The manifest is the package's index. It pins what a reviewer needs to redo the
## capture: the script, the base revision, the weapons, modes, viewports, and the
## LFS object id of every committed sheet.
func _check_manifest(errors: Array[String]) -> void:
	var manifest := _load_json(MANIFEST_PATH, errors)
	if manifest.is_empty():
		return
	var evidence: Variant = manifest.get("evidence")
	if not evidence is Dictionary:
		errors.append("manifest must carry an evidence block")
		return
	var record := evidence as Dictionary
	_expect(
		str(record.get("capture_script", "")) == CAPTURE_SCRIPT,
		"manifest capture_script must name %s" % CAPTURE_SCRIPT,
		errors
	)
	_expect(
		FileAccess.file_exists("res://" + CAPTURE_SCRIPT),
		"capture script must exist: %s" % CAPTURE_SCRIPT,
		errors
	)
	var sheets: Variant = record.get("contact_sheets")
	_expect(sheets is Array, "manifest must list contact_sheets", errors)
	if sheets is Array:
		var listed := (sheets as Array).map(func(value): return str(value))
		_expect(
			listed.size() == CAPTURES.size(),
			"manifest must list %d contact sheets, got %d" % [CAPTURES.size(), listed.size()],
			errors
		)
		for raw_capture in CAPTURES:
			var expected := str((raw_capture as Dictionary)["path"]).trim_prefix("res://")
			_expect(listed.has(expected), "manifest must list %s" % expected, errors)

	var capture: Variant = record.get("live_capture")
	if not capture is Dictionary:
		errors.append("manifest must carry an evidence.live_capture block")
		return
	var live := capture as Dictionary
	for key in ["source_commit_sha", "source_tree_sha"]:
		var value := str(live.get(key, ""))
		_expect(
			value.length() == 40 and value.is_valid_hex_number(),
			"manifest live_capture.%s must pin a full SHA, got \"%s\"" % [key, value],
			errors
		)
	_expect(
		_string_list(live.get("weapon_ids")) == Pack.WEAPON_IDS,
		"manifest live_capture.weapon_ids must pin %s" % [Pack.WEAPON_IDS],
		errors
	)
	_expect(
		_string_list(live.get("modes")) == REQUIRED_MODE_IDS,
		"manifest live_capture.modes must pin %s" % [REQUIRED_MODE_IDS],
		errors
	)
	var viewports: Variant = live.get("viewports")
	_expect(viewports is Dictionary, "manifest live_capture.viewports must be a map", errors)
	if viewports is Dictionary:
		for raw_capture in CAPTURES:
			var entry := raw_capture as Dictionary
			var size := entry["size"] as Vector2i
			_expect(
				str((viewports as Dictionary).get(str(entry["name"]), "")) == "%dx%d" % [size.x, size.y],
				"manifest live_capture.viewports must pin %s as %dx%d" % [str(entry["name"]), size.x, size.y],
				errors
			)
	var objects: Variant = live.get("png_object_ids")
	_expect(objects is Dictionary, "manifest live_capture.png_object_ids must be a map", errors)
	if objects is Dictionary:
		for raw_capture in CAPTURES:
			var entry := raw_capture as Dictionary
			var declared := str((objects as Dictionary).get(str(entry["name"]), ""))
			_expect(
				declared.length() == 64 and declared.is_valid_hex_number(),
				"manifest live_capture.png_object_ids.%s must pin a sha256 oid" % str(entry["name"]),
				errors
			)
			var actual := _file_sha256(str(entry["path"]))
			_expect(
				actual.is_empty() or actual == declared,
				"manifest live_capture.png_object_ids.%s is %s but the committed sheet is %s"
				% [str(entry["name"]), declared, actual],
				errors
			)


## Every validator above is data-driven so it can be shown to reject. A gate that
## cannot go red certifies nothing: a missing viewport, a substituted weapon, a
## dropped mode, an LFS pointer, a wrong size and a strobing envelope all fail.
func _check_probes_go_red(errors: Array[String]) -> void:
	_expect(capture_set_violations(CAPTURES).is_empty(), "the shipped capture set must pass", errors)
	_expect(weapon_set_violations(PACKS).is_empty(), "the shipped weapon set must pass", errors)
	_expect(mode_set_violations(MODES).is_empty(), "the shipped mode set must pass", errors)

	var missing_viewport := CAPTURES.duplicate(true)
	missing_viewport.remove_at(0)
	_expect_red(capture_set_violations(missing_viewport), "a missing viewport", errors)

	var wrong_size := CAPTURES.duplicate(true)
	(wrong_size[1] as Dictionary)["size"] = Vector2i(1281, 720)
	_expect_red(capture_set_violations(wrong_size), "a viewport declared at the wrong size", errors)

	var substituted := PACKS.duplicate(true)
	(substituted[0] as Dictionary)["weapon_id"] = "moon_crossbow_v2"
	_expect_red(weapon_set_violations(substituted), "a substituted weapon id", errors)

	var missing_mode := MODES.duplicate(true)
	missing_mode.remove_at(3)
	_expect_red(mode_set_violations(missing_mode), "a dropped presentation mode", errors)

	var pointer_path := "user://fan3889_pointer_probe.png"
	var pointer := FileAccess.open(pointer_path, FileAccess.WRITE)
	if pointer == null:
		errors.append("pointer probe could not be written")
	else:
		pointer.store_string("%s\noid sha256:%s\nsize 65536\n" % [LFS_POINTER_PREFIX, "a".repeat(64)])
		pointer.close()
		var unsmudged := CAPTURES.duplicate(true)
		(unsmudged[0] as Dictionary)["path"] = pointer_path
		_expect_red(evidence_violations(unsmudged), "an unsmudged LFS pointer", errors)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pointer_path))

	var absent := CAPTURES.duplicate(true)
	(absent[0] as Dictionary)["path"] = CAPTURE_ROOT + "/ranger_ultimate_timelines_missing.png"
	_expect_red(evidence_violations(absent), "a missing sheet", errors)

	var strobe: Array[float] = []
	for index in 240:
		strobe.append(0.3 if index % 12 < 6 else 0.0)
	_expect_red(flash_violations("strobe probe", flash_report(strobe, 1.0)), "a strobing backdrop", errors)

	var opaque: Array[float] = [0.0, 0.9, 0.9, 0.0]
	_expect_red(flash_violations("opaque probe", flash_report(opaque, 3.0)), "an opaque backdrop", errors)


# --- declaration validators -------------------------------------------------


static func capture_set_violations(captures: Array) -> Array[String]:
	var errors: Array[String] = []
	var required: Dictionary = Contract.REQUIRED_CAPTURES
	if captures.size() != required.size():
		errors.append("capture set lists %d of %d viewports" % [captures.size(), required.size()])
	var seen := {}
	for raw_capture in captures:
		var capture := raw_capture as Dictionary
		var name := str(capture.get("name", ""))
		if seen.has(name):
			errors.append("viewport %s is declared twice" % name)
		seen[name] = true
		if not required.has(name):
			errors.append("viewport %s is not a supported capture slot" % name)
			continue
		var expected: Vector2i = required[name]
		if (capture.get("size", Vector2i.ZERO) as Vector2i) != expected:
			errors.append("viewport %s must be %dx%d" % [name, expected.x, expected.y])
		if not str(capture.get("path", "")).ends_with("_%s.png" % name):
			errors.append("viewport %s must be committed as a _%s.png sheet" % [name, name])
	for name in required:
		if not seen.has(name):
			errors.append("viewport %s is missing from the capture set" % name)
	return errors


static func weapon_set_violations(packs: Array) -> Array[String]:
	var errors: Array[String] = []
	var declared: Array[String] = []
	for raw_pack in packs:
		var weapon_id := str((raw_pack as Dictionary).get("weapon_id", ""))
		declared.append(weapon_id)
		if not Pack.WEAPON_IDS.has(weapon_id):
			errors.append("%s is not a canonical Ranger weapon id" % weapon_id)
	if declared != Pack.WEAPON_IDS:
		errors.append("capture must cover %s, got %s" % [Pack.WEAPON_IDS, declared])
	return errors


static func mode_set_violations(modes: Array) -> Array[String]:
	var errors: Array[String] = []
	var declared: Array[String] = []
	for raw_mode in modes:
		var mode := raw_mode as Dictionary
		declared.append(str(mode.get("id", "")))
		if not (mode.get("motion") is bool) or not (mode.get("veil") is bool):
			errors.append("mode %s must declare its motion and veil state" % str(mode.get("id", "")))
		if int(mode.get("crowd", -1)) < 0 or int(mode.get("crowd", -1)) > Pack.CROWD_CAP:
			errors.append("mode %s crowd must stay inside the declared crowd cap" % str(mode.get("id", "")))
	if declared != REQUIRED_MODE_IDS:
		errors.append("capture must cover %s, got %s" % [REQUIRED_MODE_IDS, declared])
	return errors


static func evidence_violations(captures: Array) -> Array[String]:
	var errors: Array[String] = []
	for raw_capture in captures:
		var capture := raw_capture as Dictionary
		var path := str(capture.get("path", ""))
		if not FileAccess.file_exists(path):
			errors.append("contact sheet is missing: %s" % path)
			continue
		if is_lfs_pointer(path):
			errors.append("contact sheet is an unsmudged LFS pointer: %s" % path)
			continue
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			errors.append("contact sheet does not decode as a PNG: %s" % path)
			continue
		var expected := capture.get("size", Vector2i.ZERO) as Vector2i
		if image.get_size() != expected:
			errors.append(
				"contact sheet %s is %dx%d, expected %dx%d"
				% [path, image.get_size().x, image.get_size().y, expected.x, expected.y]
			)
	return errors


## An LFS pointer opens as a small text file. Reading the header keeps a
## checkout that never ran `git lfs pull` from passing as committed evidence.
## Compared as raw bytes: a PNG starts with 0x89, which is not valid UTF-8, and
## decoding it first only produces parser warnings on every healthy sheet.
static func is_lfs_pointer(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var expected := LFS_POINTER_PREFIX.to_utf8_buffer()
	var head := file.get_buffer(expected.size())
	file.close()
	return head == expected


# --- photosensitivity -------------------------------------------------------


static func backdrop_samples(weapon_id: String) -> Array[float]:
	var samples: Array[float] = []
	var duration := Pack.timeline_seconds(weapon_id)
	var elapsed := 0.0
	while elapsed <= duration:
		samples.append(Pack.backdrop_alpha(weapon_id, elapsed))
		elapsed += FLASH_SWEEP_STEP
	return samples


## Peak weight plus how often the backdrop crosses back up through half its own
## peak: that rising-edge count over the cast length is the flash rate WCAG 2.3.1
## bounds, and a single-shot envelope reports well under 1 Hz.
static func flash_report(samples: Array, duration: float) -> Dictionary:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, float(value))
	var trigger := peak * FLASH_TRIGGER_RATIO
	var rises := 0
	var above := false
	for value in samples:
		if float(value) > trigger and not above:
			rises += 1
			above = true
		elif float(value) <= trigger:
			above = false
	return {"peak": peak, "rises": rises, "hz": float(rises) / maxf(duration, 0.0001)}


static func flash_violations(label: String, report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var peak := float(report.get("peak", 0.0))
	var hz := float(report.get("hz", 0.0))
	if peak > MAX_OVERLAY_ALPHA:
		errors.append("%s backdrop peaks at %.2f over the %.2f readability ceiling" % [label, peak, MAX_OVERLAY_ALPHA])
	if hz > Contract.MAX_FLASH_HZ:
		errors.append("%s backdrop flashes at %.2f Hz over the %.1f Hz threshold" % [label, hz, Contract.MAX_FLASH_HZ])
	return errors


# --- sheet geometry ---------------------------------------------------------


static func sheet_title_font_size(size: Vector2i) -> int:
	return TEXT_FIT.scaled_font_size(size, SHEET_TITLE_FONT_RATIO, 14)


static func sheet_title_rect(size: Vector2i) -> Rect2:
	return TEXT_FIT.centered_rect(SHEET_TITLE, size, float(size.y) * SHEET_TITLE_Y_RATIO, sheet_title_font_size(size))


static func grid_rect(size: Vector2i) -> Rect2:
	var left := float(size.x) * GRID_MARGIN_X_RATIO
	var top := float(size.y) * GRID_TOP_RATIO
	return Rect2(
		Vector2(left, top),
		Vector2(float(size.x) * (1.0 - GRID_MARGIN_X_RATIO) - left, float(size.y) * GRID_BOTTOM_RATIO - top)
	)


static func panel_rect(size: Vector2i, column: int, row: int) -> Rect2:
	var grid := grid_rect(size)
	var gap := Vector2(float(size.x) * GRID_GAP_X_RATIO, float(size.y) * GRID_GAP_Y_RATIO)
	var columns := MODES.size()
	var rows := PACKS.size()
	var cell := Vector2(
		(grid.size.x - gap.x * float(columns - 1)) / float(columns),
		(grid.size.y - gap.y * float(rows - 1)) / float(rows)
	)
	return Rect2(grid.position + Vector2(float(column) * (cell.x + gap.x), float(row) * (cell.y + gap.y)), cell)


static func panel_label_text(pack: Dictionary, mode: Dictionary) -> String:
	return "%s · %s" % [str(pack.get("label", "")), str(mode.get("label", ""))]


static func panel_label_font_size(size: Vector2i, column: int, row: int) -> int:
	var panel := panel_rect(size, column, row)
	var margin := panel_margin(size)
	return TEXT_FIT.fitted_font_size(
		panel_label_text(PACKS[row] as Dictionary, MODES[column] as Dictionary),
		TEXT_FIT.scaled_font_size(size, PANEL_LABEL_FONT_RATIO, 8),
		6,
		panel.size.x - margin * 2.0
	)


static func panel_label_rect(size: Vector2i, column: int, row: int) -> Rect2:
	var panel := panel_rect(size, column, row)
	var margin := panel_margin(size)
	return TEXT_FIT.centered_in_rect(
		panel_label_text(PACKS[row] as Dictionary, MODES[column] as Dictionary),
		panel,
		panel.position.y + margin,
		panel_label_font_size(size, column, row)
	)


static func panel_margin(size: Vector2i) -> float:
	return maxf(2.0, float(size.y) * PANEL_MARGIN_RATIO)


## The arena is the sub-viewport the panel renders: whole pixels, because it is a
## real render target and not a drawing rectangle.
static func arena_rect(size: Vector2i, column: int, row: int) -> Rect2i:
	var panel := panel_rect(size, column, row)
	var margin := panel_margin(size)
	var label := panel_label_rect(size, column, row)
	var top := label.end.y + margin
	var position := Vector2(panel.position.x + margin, top)
	var arena_size := Vector2(panel.end.x - margin, panel.end.y - margin) - position
	return Rect2i(Vector2i(position.floor()), Vector2i(arena_size.floor()))


static func hud_band_rect(arena_size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(float(arena_size.x), float(arena_size.y) * HUD_BAND_HEIGHT_RATIO))


## Capture annotation, not game HUD: the shipped state each panel was rendered
## under. Without it the reduced-motion column is indistinguishable from the
## normal one in a still frame, because the only thing it changes is the shake.
static func state_band_rect(arena_size: Vector2i) -> Rect2:
	var height := float(arena_size.y) * STATE_BAND_HEIGHT_RATIO
	return Rect2(Vector2(0.0, float(arena_size.y) - height), Vector2(float(arena_size.x), height))


static func state_text(pack: Dictionary, mode: Dictionary) -> String:
	var veil := "OFF"
	if bool(mode.get("veil", true)):
		veil = "%.2f" % Pack.backdrop_alpha(str(pack["weapon_id"]), float(pack["beat"]))
	return "BEAT %.2fs · SHAKE %s · CROWD %d · VEIL %s" % [
		float(pack["beat"]),
		"ON" if bool(mode.get("motion", true)) else "OFF",
		int(mode.get("crowd", 0)),
		veil,
	]


static func band_font_size(text: String, band: Rect2) -> int:
	return TEXT_FIT.fitted_font_size(text, maxi(6, int(band.size.y * 0.68)), 6, band.size.x * 0.94)


static func hud_text_rect(arena_size: Vector2i) -> Rect2:
	var band := hud_band_rect(arena_size)
	var font_size := band_font_size(HUD_TEXT, band)
	var text_size := ThemeDB.fallback_font.get_string_size(HUD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(band.position + Vector2(band.size.x * 0.03, (band.size.y - text_size.y) * 0.5), text_size)


static func state_text_rect(arena_size: Vector2i, pack: Dictionary, mode: Dictionary) -> Rect2:
	var band := state_band_rect(arena_size)
	var text := state_text(pack, mode)
	var font_size := band_font_size(text, band)
	var text_size := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return Rect2(band.get_center() - text_size * 0.5, text_size)


static func player_rect(arena_size: Vector2i) -> Rect2:
	var body := body_rect(arena_size)
	var player_size := Vector2(
		float(arena_size.x) * PLAYER_COLUMN_WIDTH_RATIO * 0.9,
		float(arena_size.y) * PLAYER_HEIGHT_RATIO
	)
	return Rect2(Vector2(0.0, body.get_center().y - player_size.y * 0.5), player_size)


## The drawn player, fitted into its column. This is what the readability floor
## is measured against — the column is a reservation, the sprite is the read.
static func player_sprite_rect(arena_size: Vector2i) -> Rect2:
	var column := player_rect(arena_size)
	var texture: Texture2D = load(PLAYER_SPRITE)
	if texture == null:
		return Rect2()
	var source := Vector2(texture.get_size())
	var fit := minf(column.size.x / source.x, column.size.y / source.y)
	var drawn := source * fit
	return Rect2(column.get_center() - drawn * 0.5, drawn)


static func hazard_rects(arena_size: Vector2i) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var width := float(arena_size.x) * HAZARD_COLUMN_WIDTH_RATIO * 0.9
	var left := float(arena_size.x) - width
	for ratio in HAZARD_TOP_RATIOS:
		rects.append(Rect2(
			Vector2(left, float(arena_size.y) * ratio),
			Vector2(width, float(arena_size.y) * HAZARD_HEIGHT_RATIO)
		))
	return rects


## Everything under the HUD strip and above the state caption.
static func body_rect(arena_size: Vector2i) -> Rect2:
	var top := float(arena_size.y) * HUD_BAND_HEIGHT_RATIO
	return Rect2(
		Vector2(0.0, top),
		Vector2(float(arena_size.x), state_band_rect(arena_size).position.y - top)
	)


static func effect_zone(arena_size: Vector2i) -> Rect2:
	var body := body_rect(arena_size)
	var left := float(arena_size.x) * PLAYER_COLUMN_WIDTH_RATIO
	var right := float(arena_size.x) * (1.0 - HAZARD_COLUMN_WIDTH_RATIO)
	return Rect2(Vector2(left, body.position.y), Vector2(right - left, body.size.y))


## Every band the effect must never cover, by the name the failure reports.
static func readability_bands(arena_size: Vector2i) -> Dictionary:
	var bands := {
		"HUD band": hud_band_rect(arena_size),
		"state caption": state_band_rect(arena_size),
		"player column": player_rect(arena_size),
	}
	var hazards := hazard_rects(arena_size)
	for index in hazards.size():
		bands["hazard %d" % index] = hazards[index]
	return bands


# --- live scene driving -----------------------------------------------------


static func instantiate_scene(pack: Dictionary) -> Node2D:
	return (pack["scene"] as PackedScene).instantiate() as Node2D


static func capture_handles() -> Dictionary:
	return {"animation": HandleProbe.new(), "vfx": HandleProbe.new(), "sfx": HandleProbe.new()}


## The shipped motion toggle, read exactly as `main.gd` publishes it.
static func apply_mode(tree: SceneTree, mode: Dictionary) -> void:
	tree.root.set_meta("screen_shake", bool(mode.get("motion", true)))


static func reset_mode(tree: SceneTree) -> void:
	tree.root.set_meta("screen_shake", true)


## Capture-side only: the photosensitivity-safe column drops the arena-wide
## backdrop after the scene has drawn its beat. The scene itself is untouched.
static func apply_veil(scene: Node2D, mode: Dictionary) -> void:
	if bool(mode.get("veil", true)):
		return
	var veil := scene.get_node_or_null(Pack.BACKDROP_NODE) as CanvasItem
	if veil != null:
		veil.self_modulate = Color(veil.self_modulate.r, veil.self_modulate.g, veil.self_modulate.b, 0.0)
		veil.visible = false


## Drives the shipped scene to `seconds` with fixed steps, then stops its own
## `_process`. Without that stop the scene keeps advancing by real frame deltas
## between being built and being drawn, and the captured beat is whatever the
## frame pacing happened to be.
static func seek_scene(scene: Node2D, registry, seconds: float) -> void:
	scene.begin(registry, capture_handles(), 0)
	var remaining := seconds
	while remaining > SEEK_STEP:
		scene.step(SEEK_STEP)
		remaining -= SEEK_STEP
	if remaining > 0.0:
		scene.step(remaining)
	scene.set_process(false)


static func formation_signature(scene: Node2D) -> String:
	var parts: Array[String] = []
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.visible or _is_presence_node(sprite):
			continue
		parts.append("%.3f:%.3f:%.3f:%.3f:%.3f" % [
			sprite.position.x, sprite.position.y, sprite.scale.x, sprite.rotation, sprite.modulate.a,
		])
	return "|".join(parts)


## Fits the drawn formation into its effect zone. The arena-wide backdrop is
## excluded on purpose: it is a full-viewport tint, so including it would make
## every panel's content bounds the whole arena and measure nothing.
static func layout_scene(scene: Node2D, arena_size: Vector2i) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var zone := effect_zone(arena_size)
	var applied := minf(zone.size.x / bounds.size.x, zone.size.y / bounds.size.y)
	scene.scale = Vector2.ONE * applied
	scene.position = zone.get_center() - bounds.get_center() * applied
	return Rect2(bounds.position * applied + scene.position, bounds.size * applied)


static func content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	for child in scene.get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.visible or sprite.modulate.a <= 0.0 or _is_presence_node(sprite):
			continue
		if sprite.texture == null:
			continue
		var local := Rect2(sprite.offset, Vector2(sprite.texture.get_size()))
		var item: Rect2 = sprite.transform * local
		bounds = item if not found else bounds.merge(item)
		found = true
	return bounds


static func _is_presence_node(node: Node) -> bool:
	return node.name == Pack.BACKDROP_NODE or node.name == Pack.HERO_POSE_NODE


# --- helpers ----------------------------------------------------------------


func _mode_by_id(id: String) -> Dictionary:
	for raw_mode in MODES:
		if str((raw_mode as Dictionary).get("id", "")) == id:
			return raw_mode as Dictionary
	return {}


static func _string_list(value: Variant) -> Array[String]:
	var list: Array[String] = []
	if value is Array:
		for entry in value as Array:
			list.append(str(entry))
	return list


static func _file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path)


func _load_json(resource_path: String, errors: Array[String]) -> Dictionary:
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		errors.append("cannot read %s" % resource_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		errors.append("%s must contain a JSON object" % resource_path)
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
		print("Ranger live capture gate: %d viewports x %d weapons x %d modes verified" % [
			CAPTURES.size(), PACKS.size(), MODES.size(),
		])
		quit(0)
		return
	for error in errors:
		push_error("Ranger live capture gate: %s" % error)
	quit(1)
