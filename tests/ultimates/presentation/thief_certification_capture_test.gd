extends SceneTree

## FAN-3941 — headless gate and shared spec for the Thief certification
## capture package (real-runtime edition after the first independent review).
##
## The package proves the three canonical Thief ultimates in the four
## presentation modes at the four supported viewports, rendered from the real
## runtime: the shipped Player (its own current Camera2D, real HP and charge),
## real Enemy scenes as the crowd, a real hazard telegraph and a real enemy
## projectile, the real live ultimate HUD adapter, and the cast started
## through UltimatePlayerHost so the executor, the authored presentation, the
## victim impacts and every weight device run exactly as in the game. Frames
## are taken under `--fixed-fps 60`, so a beat is a frame index and the
## package reproduces byte for byte.
##
## Accessibility modes run through the production policy, not a capture
## switch: the reduced-motion and photosensitivity-safe variants publish the
## shipped `ultimate_accessibility_settings` root snapshot
## (scripts/settings/ultimate_accessibility_settings.gd, the same call
## main.gd makes at startup) and the live cast's own driver honours it. The
## manifest records the camera offset trace and the full-screen surface alpha
## trace of every run, so reduced motion must show a zero offset against a
## moving normal run, and photosensitivity-safe must show a zero surface
## against a lit normal run; a measured no-op is only accepted with its
## production semantics recorded. This file owns the spec, the probes and the
## validators; the renderer thief_certification_live_capture.gd preloads it
## and draws nothing this file does not describe.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")
const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const TEXT_FIT := preload("res://tests/ultimates/presentation/contact_sheet_text_fit.gd")

const CLASS_ID := "thief"
const ISSUE := "FAN-3941"
const SCHEMA_VERSION := 3
const CAPTURE_SCRIPT := "tests/ultimates/presentation/thief_certification_live_capture.gd"
const FOCUSED_TEST := "tests/ultimates/presentation/thief_certification_capture_test.gd"
const CAPTURE_ROOT := "docs/design/reference-assets-lfs/ultimate-certification/thief"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/thief/certification_capture_manifest.json"
const READABILITY_REPORT := "docs/design/references/weapon_ultimates/thief/certification_readability_report.md"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/thief/manifest.json"
const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/thief.json"
const ADOPTION_SHARD_PATH := "res://data/ultimates/classes/thief/presentation_adoption.json"

## The shipped scenes, executors and assets were captured from this integrated
## revision; the capture tooling and evidence are added by FAN-3941 on top.
## The recorded source is checked against git itself: the commit must exist in
## this repository, its tree must be the recorded tree, and it must be an
## ancestor of (or equal to) the checked-out HEAD — the evidence commit that
## carries the frames comes after it, so the manifest never refers to itself.
static func git_source_violations(source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var commit := str(source.get("commit_sha", ""))
	var tree := str(source.get("tree_sha", ""))
	if commit.length() != 40 or tree.length() != 40:
		return errors
	var resolved := _git(["rev-parse", "--verify", "--quiet", commit + "^{commit}"])
	if resolved != commit:
		errors.append("manifest source.commit_sha %s is not a commit of this repository" % commit)
		return errors
	var resolved_tree := _git(["rev-parse", commit + "^{tree}"])
	if resolved_tree != tree:
		errors.append("manifest source.tree_sha %s is not the tree of commit %s (%s)" % [tree, commit, resolved_tree])
	if _git_exit(["merge-base", "--is-ancestor", commit, "HEAD"]) != 0:
		errors.append("manifest source.commit_sha %s is not an ancestor of the checked-out HEAD" % commit)
	return errors


static func _git(args: Array) -> String:
	var output: Array = []
	var packed := PackedStringArray()
	for arg in args:
		packed.append(str(arg))
	if OS.execute("git", packed, output, true) != 0:
		return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""


static func _git_exit(args: Array) -> int:
	var packed := PackedStringArray()
	for arg in args:
		packed.append(str(arg))
	return OS.execute("git", packed, [], true)


## Provenance is read from git by the renderer at capture time: the source
## commit and tree are whatever the clean worktree is checked out at, so the
## amended scenes, drivers and tooling are committed first and the evidence
## commit that carries the frames comes after. A dirty worktree refuses to
## capture.
const SOURCE_REF := "agent/fable/e50731ad6088"
const SOURCE_RECORDER := "git rev-parse at capture time"

## Certification captures run under the explicit exclusive process admission
## of tools/godot_gate.py on the fixed frame clock.
const CAPTURE_COMMAND := "FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --fixed-fps 60 --disable-vsync --script res://tests/ultimates/presentation/thief_certification_live_capture.gd"
const TEST_COMMAND := "python3 tools/godot_gate.py --headless --path . --fixed-fps 60 --script res://tests/ultimates/presentation/thief_certification_capture_test.gd"
const CAPTURE_SEED := 3941
const FIXED_FPS := 60

## On-screen scale. project.godot renders a 2560x1440 logical canvas with the
## canvas_items stretch mode and the combat camera zooms it by
## main.gd:COMBAT_CAMERA_ZOOM; the capture sets the shipped Player camera to
## that zoom times the window ratio, so a world unit covers exactly the pixels
## it covers in the game at each supported window size.
const LOGICAL_CANVAS := Vector2(2560.0, 1440.0)
const COMBAT_CAMERA_ZOOM := 1.12

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
## `enemies` is the real Enemy scene count (`crowd_cap` reads the weapon's
## declared crowd cap); `reduced_motion` and `photosensitivity_safe` are the
## two persisted production preferences published on the tree root through
## scripts/settings/ultimate_accessibility_settings.gd, exactly as main.gd
## publishes the saved settings. The shipped `screen_shake` toggle stays on in
## every mode so the frames prove the ultimate preference on its own.
const MODES := [
	{"id": MODE_NORMAL, "label": "NORMAL", "enemies": "representative", "reduced_motion": false, "photosensitivity_safe": false, "swatch": Color(0.18, 0.76, 1.0)},
	{"id": MODE_CROWDED, "label": "CROWDED", "enemies": "crowd_cap", "reduced_motion": false, "photosensitivity_safe": false, "swatch": Color(1.0, 0.58, 0.18)},
	{"id": MODE_REDUCED_MOTION, "label": "REDUCED MOTION", "enemies": "representative", "reduced_motion": true, "photosensitivity_safe": false, "swatch": Color(0.36, 0.92, 0.48)},
	{"id": MODE_PHOTOSENSITIVITY_SAFE, "label": "PHOTOSENSITIVITY-SAFE", "enemies": "representative", "reduced_motion": false, "photosensitivity_safe": true, "swatch": Color(0.78, 0.48, 1.0)},
]
const MODE_IDS: Array[String] = [MODE_NORMAL, MODE_CROWDED, MODE_REDUCED_MOTION, MODE_PHOTOSENSITIVITY_SAFE]
const REPRESENTATIVE_ENEMIES := 3

## How a mode is allowed to differ from normal, as the manifest must record it
## per weapon: a real device that ran, or an explicit measured no-op.
const EFFECT_CAMERA_SHAKE := "camera_shake"
const EFFECT_FULLSCREEN_SUPPRESSED := "fullscreen_suppressed"
## The production preferences and the module that publishes them.
const POLICY_MODULE := "scripts/settings/ultimate_accessibility_settings.gd"
const EFFECT_CROWD := "crowd"
const EFFECT_NONE_INTRINSIC := "none_intrinsic"

## Beats on the presentation clock. release/active/recovery sit mid-window;
## `impact` is just after the active edge, where the first-impact hitstop and
## the camera shake device are live for the weapons that own one.
const BEAT_IDS: Array[String] = ["release", "impact", "active", "recovery"]
const BEAT_NEXT_PHASE := {"release": "active", "active": "recovery", "recovery": "cancel"}
const IMPACT_OFFSET_SECONDS := 0.15
## Every viewport carries the active beat and every payoff beat; release,
## impact and recovery are committed at the 648p judging viewport.
const FULL_VIEWPORT_BEATS: Array[String] = ["active"]
const BEAT_VIEWPORT := "648p"

## Canonical trio. `scene_node` is the root name of the shipped presentation
## scene as the runtime instantiates it under the Player's effect parent;
## `payoff_beats` are executor-clock beats past the phase envelope (Soldier
## grenade only) committed at every viewport.
const WEAPONS := [
	{"weapon_id": "thief_coin_pouch", "scene_node": "ThiefCoinPouchUltimate", "label": "COIN POUCH", "swatch": Color(1.0, 0.84, 0.36), "payoff_beats": {}},
	{"weapon_id": "thief_shadow_cloak", "scene_node": "ThiefShadowCloakUltimate", "label": "SHADOW CLOAK", "swatch": Color(0.70, 0.46, 0.96), "payoff_beats": {}},
	{"weapon_id": "thief_smoke_bomb", "scene_node": "ThiefSmokeBombUltimate", "label": "SMOKE BOMB", "swatch": Color(0.56, 0.72, 0.84), "payoff_beats": {}},
]

## World layout (world units). The Player stands at the centre of the shipped
## 4096x2304 arena (main.gd ARENA_SIZE) so its camera limits behave as in the
## game; every other position is an offset from the Player. Enemies fill a
## deterministic spiral around the aim centre the cast is pointed at; the
## hazard telegraph and the enemy projectile sit inside the frame at every
## viewport.
const PLAYER_ORIGIN := Vector2(2048.0, 1152.0)
const AIM_OFFSET := Vector2(250.0, 0.0)
const ENEMY_SPIRAL_BASE := 110.0
const ENEMY_SPIRAL_STEP := 14.0
const ENEMY_GOLDEN_ANGLE := 2.399963
const HAZARD_ZONE_OFFSET := Vector2(-190.0, 140.0)
const HAZARD_ZONE_RADIUS := 96.0
const HAZARD_ZONE_COLOR := Color(1.0, 0.36, 0.16)
const PROJECTILE_OFFSET := Vector2(-120.0, -180.0)
const ENEMY_HEALTH := 100000.0
## Sprite footprints the probes read (texture size x scene scale), in world units.
const PLAYER_FOOTPRINT := Vector2(96.0, 118.0)
const ENEMY_FOOTPRINT := Vector2(54.0, 54.0)
## The enemy bolt is scenes/EnemyProjectile.tscn's 64 px sprite at 0.52 scale;
## its drawn pixels are read from the texture's used rect, not its padding.
const PROJECTILE_TEXTURE := "res://assets/sprites/projectiles/enemy_projectile_magic_64.png"
const PROJECTILE_SCALE := 0.52
const PROJECTILE_SURROUND_PX := 6.0

## Overlays, in viewport ratios: the HUD band (real ultimate HUD adapter widget
## plus the live HP readout) and the capture caption with the mode/weapon swatches.
const HUD_BAND_HEIGHT_RATIO := 0.12
const STATE_BAND_HEIGHT_RATIO := 0.07
const HUD_FONT_LOGICAL := 34
const CAPTION_MARGIN_RATIO := 0.008
const FLOOR_COLOR := Color(0.043, 0.056, 0.068, 1.0)
const HUD_BAND_COLOR := Color(0.10, 0.13, 0.17, 0.92)
const HUD_TEXT_COLOR := Color(0.86, 0.92, 0.98)
const STATE_BAND_COLOR := Color(0.08, 0.10, 0.13, 1.0)
const STATE_TEXT_COLOR := Color(0.72, 0.80, 0.88)

## Readability floors measured on the decoded frames. Contrast is the luma
## difference against the sampled floor, so a tinted veil still passes as long
## as the thing behind it stays readable.
const HUD_CONTRAST_MIN := 0.25
const HUD_CONTRAST_MIN_RATIO := 0.004
const ENTITY_CONTRAST_MIN := 0.15
const PLAYER_CONTRAST_MIN_RATIO := 0.12
const ENEMY_CONTRAST_MIN_RATIO := 0.10
## Readability of the small enemy bolt: the share of its drawn pixels (the
## texture's opaque pixels, not the padding of its used rect) whose luma
## differs from the bolt's immediate surround by the entity floor. The
## surround is what the eye compares it with under a veil, a flash or a
## formation element, so the ultimate's own art counts against it. The floor
## is the value the first certification candidate published and is unchanged.
const PROJECTILE_CONTRAST_MIN_RATIO := 0.06
const HAZARD_CONTRAST_MIN := 0.10
const SWATCH_TOLERANCE := 0.06
const PROBE_STRIDE := 2
const COVERAGE_STRIDE := 2
const COVERAGE_ALPHA_MIN := 0.5
const DIFF_LUMA_MIN := 0.02
const DIFF_STRIDE := 2
const MIN_MODE_DIFF_RATIO := 0.0005

const MAX_OVERLAY_ALPHA := 0.35
const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"

## The shipped presentation runtime is forced live on headless for the device
## checks, exactly like beat_routing_gate_test.gd does.
const LIVE_PRESENTATION_HEADLESS_MODE := 0

static var _class_manifest_cache := {}


func _initialize() -> void:
	var errors: Array[String] = []
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
	var images := _check_files(manifest, errors)
	for violation in mode_violations(manifest, images):
		errors.append(violation)
	for violation in quality_violations(class_manifest, manifest):
		errors.append(violation)
	for violation in class_manifest_link_violations(class_manifest, manifest):
		errors.append(violation)
	for violation in adoption_violations():
		errors.append(violation)
	await _check_live_devices(manifest, errors)
	_check_negatives(manifest, class_manifest, profile, images, errors)
	_finish(errors)


# --- declaration ------------------------------------------------------------


func _check_declaration(errors: Array[String]) -> void:
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var id := str(viewport["id"])
		_expect(Contract.REQUIRED_CAPTURES.has(id), "viewport %s must be a contract slot" % id, errors)
		_expect(Contract.REQUIRED_CAPTURES.get(id, Vector2i.ZERO) == viewport["size"], "viewport %s must be the contract size" % id, errors)
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid", errors)
	var canonical: Array[String] = []
	for weapon_id in registry.weapon_ids(CLASS_ID):
		canonical.append(str(weapon_id))
	_expect(weapon_ids() == canonical, "spec must cover the canonical %s trio in registry order, got %s vs %s" % [CLASS_ID, weapon_ids(), canonical], errors)
	_expect(mode_ids() == MODE_IDS, "spec must cover the four presentation modes", errors)
	for weapon_id in weapon_ids():
		_expect(not timing_seconds(weapon_id).is_empty(), "%s must declare timing_seconds in the class manifest" % weapon_id, errors)
		_expect(crowd_cap(weapon_id) >= REPRESENTATIVE_ENEMIES, "%s crowd cap must cover the representative crowd" % weapon_id, errors)


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


static func class_weapon(weapon_id: String) -> Dictionary:
	if _class_manifest_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CLASS_MANIFEST_PATH))
		if parsed is Dictionary:
			for raw_weapon in (parsed as Dictionary).get("weapons", []) as Array:
				if raw_weapon is Dictionary:
					_class_manifest_cache[str((raw_weapon as Dictionary).get("weapon_id", ""))] = raw_weapon
	return (_class_manifest_cache.get(weapon_id, {}) as Dictionary).duplicate(true)


## The class manifest's declared timing is the beat source for every class;
## the class presentation tests prove it agrees with the scenes/packs.
static func timing_seconds(weapon_id: String) -> Dictionary:
	return class_weapon(weapon_id).get("timing_seconds", {}) as Dictionary


static func timeline_seconds(weapon_id: String) -> float:
	return float(timing_seconds(weapon_id).get("cancel", 0.0))


static func crowd_cap(weapon_id: String) -> int:
	return int((class_weapon(weapon_id).get("performance", {}) as Dictionary).get("crowd_cap", 0))


static func beat_ids(weapon_id: String) -> Array[String]:
	var ids: Array[String] = BEAT_IDS.duplicate()
	for beat_id in (weapon_spec(weapon_id).get("payoff_beats", {}) as Dictionary):
		ids.append(str(beat_id))
	return ids


static func is_payoff_beat(weapon_id: String, beat_id: String) -> bool:
	return (weapon_spec(weapon_id).get("payoff_beats", {}) as Dictionary).has(beat_id)


static func beat_seconds(weapon_id: String, beat_id: String) -> float:
	var payoff := weapon_spec(weapon_id).get("payoff_beats", {}) as Dictionary
	if payoff.has(beat_id):
		return float(payoff[beat_id])
	var timing := timing_seconds(weapon_id)
	if beat_id == "impact":
		return snappedf(float(timing.get("active", 0.0)) + IMPACT_OFFSET_SECONDS, 0.01)
	var start := float(timing.get(beat_id, 0.0))
	var end := float(timing.get(str(BEAT_NEXT_PHASE.get(beat_id, "cancel")), start))
	return snappedf((start + end) * 0.5, 0.01)


static func beat_frame(weapon_id: String, beat_id: String) -> int:
	return roundi(beat_seconds(weapon_id, beat_id) * float(FIXED_FPS))


## The phase a presentation-clock time falls in, by the declared timing.
static func phase_at(weapon_id: String, elapsed: float) -> String:
	var timing := timing_seconds(weapon_id)
	var current := "windup"
	var started := 0.0
	for phase in ["windup", "release", "active", "recovery", "cancel"]:
		var start := float(timing.get(phase, -1.0))
		if elapsed >= start and start >= started:
			current = phase
			started = start
	return current


static func enemy_count(weapon_id: String, mode: Dictionary) -> int:
	return crowd_cap(weapon_id) if str(mode.get("enemies", "")) == "crowd_cap" else REPRESENTATIVE_ENEMIES


## Every frame the package commits, in capture order.
static func expected_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for weapon_id in weapon_ids():
		for mode_id in MODE_IDS:
			for viewport_id in VIEWPORT_IDS:
				for beat_id in beat_ids(weapon_id):
					var everywhere := FULL_VIEWPORT_BEATS.has(beat_id) or is_payoff_beat(weapon_id, beat_id)
					if not everywhere and viewport_id != BEAT_VIEWPORT:
						continue
					entries.append({"weapon_id": weapon_id, "mode": mode_id, "viewport": viewport_id, "beat": beat_id})
	return entries


static func entry_id(entry: Dictionary) -> String:
	return "%s/%s/%s/%s" % [str(entry["weapon_id"]), str(entry["mode"]), str(entry["viewport"]), str(entry["beat"])]


static func capture_path(entry: Dictionary) -> String:
	return "%s/%s__%s__%s__%s.png" % [CAPTURE_ROOT, str(entry["weapon_id"]), str(entry["mode"]), str(entry["beat"]), str(entry["viewport"])]


# --- world and screen geometry ---------------------------------------------


static func camera_zoom(size: Vector2i) -> float:
	return COMBAT_CAMERA_ZOOM * float(size.y) / LOGICAL_CANVAS.y


static func ui_scale(size: Vector2i) -> float:
	return float(size.y) / LOGICAL_CANVAS.y


static func aim_center() -> Vector2:
	return PLAYER_ORIGIN + AIM_OFFSET


static func hazard_zone_center() -> Vector2:
	return PLAYER_ORIGIN + HAZARD_ZONE_OFFSET


static func projectile_position() -> Vector2:
	return PLAYER_ORIGIN + PROJECTILE_OFFSET


static func enemy_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for index in count:
		var angle := ENEMY_GOLDEN_ANGLE * float(index)
		var radius := ENEMY_SPIRAL_BASE + ENEMY_SPIRAL_STEP * float(index)
		positions.append(aim_center() + Vector2(cos(angle), sin(angle)) * radius)
	return positions


## World → viewport pixels for a recorded camera state (centre includes the
## shake offset the way Camera2D.get_screen_center_position reports it).
static func project(world: Vector2, camera: Dictionary, size: Vector2i) -> Vector2:
	var center := Vector2(float((camera.get("center", [0.0, 0.0]) as Array)[0]), float((camera.get("center", [0.0, 0.0]) as Array)[1]))
	var zoom := float(camera.get("zoom", 1.0))
	return (world - center) * zoom + Vector2(size) * 0.5


static func project_rect(world_center: Vector2, footprint: Vector2, camera: Dictionary, size: Vector2i) -> Rect2:
	var zoom := float(camera.get("zoom", 1.0))
	var pixel_size := footprint * zoom
	return Rect2(project(world_center, camera, size) - pixel_size * 0.5, pixel_size)


## The bolt's drawn pixels on screen: the texture's used rect scaled by the
## scene scale and the camera zoom around its world position.
static func projectile_rect(world_center: Vector2, camera: Dictionary, size: Vector2i) -> Rect2:
	var zoom := float(camera.get("zoom", 1.0))
	var texture: Texture2D = load(PROJECTILE_TEXTURE)
	if texture == null:
		return project_rect(world_center, Vector2(30.0, 30.0), camera, size)
	var image := texture.get_image()
	var used := image.get_used_rect() if image != null and not image.is_empty() else Rect2i(Vector2i.ZERO, texture.get_size())
	var scale := PROJECTILE_SCALE * zoom
	var center := project(world_center, camera, size)
	var offset := (Vector2(used.position) + Vector2(used.size) * 0.5 - Vector2(texture.get_size()) * 0.5) * scale
	return Rect2(center + offset - Vector2(used.size) * scale * 0.5, Vector2(used.size) * scale)


## Contrast share over the bolt's drawn pixels only: every screen pixel of the
## rect is mapped back onto the bolt texture and counted when the texel is
## opaque, so the transparent padding of the used rect neither helps nor hurts.
static func projectile_contrast_ratio(image: Image, rect: Rect2, reference: Color, zoom: float) -> Dictionary:
	var texture: Texture2D = load(PROJECTILE_TEXTURE)
	var texel_image := texture.get_image() if texture != null else null
	if texel_image == null or texel_image.is_empty():
		return {"ratio": contrast_ratio(image, rect, reference, ENTITY_CONTRAST_MIN, 1), "drawn_pixels": -1}
	var used := texel_image.get_used_rect()
	var scale := PROJECTILE_SCALE * zoom
	var reference_luma := luma(reference)
	var drawn := 0
	var contrasting := 0
	var y := maxi(0, int(rect.position.y))
	while y < mini(image.get_height(), int(rect.end.y)):
		var x := maxi(0, int(rect.position.x))
		while x < mini(image.get_width(), int(rect.end.x)):
			var tx := int((float(x) - rect.position.x) / scale) + used.position.x
			var ty := int((float(y) - rect.position.y) / scale) + used.position.y
			if tx >= 0 and ty >= 0 and tx < texel_image.get_width() and ty < texel_image.get_height() and texel_image.get_pixel(tx, ty).a >= 0.5:
				drawn += 1
				if absf(luma(image.get_pixel(x, y)) - reference_luma) >= ENTITY_CONTRAST_MIN:
					contrasting += 1
			x += 1
		y += 1
	return {"ratio": float(contrasting) / float(maxi(drawn, 1)), "drawn_pixels": drawn}


## Mean colour of the ring of pixels just outside a rect: the local surround
## a small sprite is read against.
static func surround_color(image: Image, rect: Rect2, margin: float) -> Color:
	var outer := rect.grow(margin)
	var sum := Color(0.0, 0.0, 0.0, 0.0)
	var count := 0
	var y := maxi(0, int(outer.position.y))
	while y < mini(image.get_height(), int(outer.end.y)):
		var x := maxi(0, int(outer.position.x))
		while x < mini(image.get_width(), int(outer.end.x)):
			if not rect.has_point(Vector2(x, y)):
				sum += image.get_pixel(x, y)
				count += 1
			x += 1
		y += 1
	return sum / float(maxi(count, 1))


static func hud_band_rect(size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(float(size.x), float(size.y) * HUD_BAND_HEIGHT_RATIO))


static func state_band_rect(size: Vector2i) -> Rect2:
	var height := float(size.y) * STATE_BAND_HEIGHT_RATIO
	return Rect2(Vector2(0.0, float(size.y) - height), Vector2(float(size.x), height))


## Everything between the overlays: where mode frames must actually differ.
static func arena_rect(size: Vector2i) -> Rect2:
	var top := hud_band_rect(size).end.y
	return Rect2(Vector2(0.0, top), Vector2(float(size.x), state_band_rect(size).position.y - top))


static func caption_margin(size: Vector2i) -> float:
	return maxf(2.0, float(size.y) * CAPTION_MARGIN_RATIO)


static func mode_swatch_rect(size: Vector2i) -> Rect2:
	var band := state_band_rect(size)
	var side := band.size.y * 0.56
	return Rect2(Vector2(band.position.x + caption_margin(size) * 2.0, band.get_center().y - side * 0.5), Vector2(side, side))


static func weapon_swatch_rect(size: Vector2i) -> Rect2:
	var mode_rect := mode_swatch_rect(size)
	return Rect2(mode_rect.position + Vector2(mode_rect.size.x + caption_margin(size), 0.0), mode_rect.size)


static func caption_text(entry: Dictionary, beat_seconds_value: float, enemies: int, mode: Dictionary, camera_offset: Vector2) -> String:
	var size := viewport_size(str(entry["viewport"]))
	return "%s · %s · %dx%d · %s %.2fs · RM %s · PS %s · OFFSET %.1f,%.1f · ENEMIES %d" % [
		key_for(str(entry["weapon_id"])).to_upper(),
		str(mode.get("label", "")),
		size.x, size.y,
		str(entry["beat"]).to_upper(),
		beat_seconds_value,
		"ON" if bool(mode.get("reduced_motion", false)) else "OFF",
		"ON" if bool(mode.get("photosensitivity_safe", false)) else "OFF",
		camera_offset.x, camera_offset.y,
		enemies,
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


static func hud_background_probe(size: Vector2i) -> Vector2i:
	var band := hud_band_rect(size)
	return Vector2i(roundi(band.size.x * 0.5), roundi(band.end.y - 4.0))


## A floor pixel nothing draws over: just under the caption band, far left.
static func floor_probe(size: Vector2i) -> Vector2i:
	var arena := arena_rect(size)
	return Vector2i(4, roundi(arena.end.y - 4.0))


# --- readability probes -----------------------------------------------------


static func luma(color: Color) -> float:
	return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b


static func color_near(actual: Color, expected: Color, tolerance: float = SWATCH_TOLERANCE) -> bool:
	return absf(actual.r - expected.r) <= tolerance \
			and absf(actual.g - expected.g) <= tolerance \
			and absf(actual.b - expected.b) <= tolerance


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


## Fraction of the sampled pixels whose alpha reaches the opaque threshold,
## and the bounding box of those pixels: the measurement behind
## `quality.max_viewport_coverage_ratio` and `quality.hud_bands_clear`.
static func opaque_coverage(image: Image, stride: int = COVERAGE_STRIDE) -> Dictionary:
	var sampled := 0
	var opaque := 0
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	var y := 0
	while y < image.get_height():
		var x := 0
		while x < image.get_width():
			sampled += 1
			if image.get_pixel(x, y).a >= COVERAGE_ALPHA_MIN:
				opaque += 1
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
			x += stride
		y += stride
	var bounds := Rect2()
	if max_x >= 0:
		bounds = Rect2(float(min_x), float(min_y), float(max_x - min_x + stride), float(max_y - min_y + stride))
	return {"ratio": float(opaque) / float(maxi(sampled, 1)), "bounds": bounds}


## Share of arena pixels whose luma differs between two frames: how much a
## mode actually changed the picture outside the overlays.
static func arena_diff_ratio(a: Image, b: Image, stride: int = DIFF_STRIDE) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var arena := arena_rect(a.get_size())
	var sampled := 0
	var differing := 0
	var y := int(arena.position.y)
	while y < int(arena.end.y):
		var x := 0
		while x < a.get_width():
			sampled += 1
			if absf(luma(a.get_pixel(x, y)) - luma(b.get_pixel(x, y))) >= DIFF_LUMA_MIN:
				differing += 1
			x += stride
		y += stride
	return float(differing) / float(maxi(sampled, 1))


## The readability record for one decoded frame, recomputed by the gate from
## the committed PNG and the recorded camera/world state.
static func readability_report(image: Image, entry: Dictionary, capture: Dictionary) -> Dictionary:
	var size := image.get_size()
	var camera := capture.get("camera", {}) as Dictionary
	var world := capture.get("world", {}) as Dictionary
	var floor_color := image.get_pixelv(floor_probe(size))
	var hud_background := image.get_pixelv(hud_background_probe(size))
	var player := _vector(world.get("player", [0.0, 0.0]))
	var enemies: Array = []
	for raw in world.get("enemies", []) as Array:
		var rect := project_rect(_vector(raw), ENEMY_FOOTPRINT, camera, size)
		if arena_rect(size).encloses(rect):
			enemies.append(snappedf(contrast_ratio(image, rect, floor_color, ENTITY_CONTRAST_MIN), 0.0001))
	var zone := world.get("hazard_zone", {}) as Dictionary
	var zone_center := project(_vector(zone.get("center", [0.0, 0.0])), camera, size)
	var zone_pixel := floor_color
	var radius := float(zone.get("radius", 0.0)) * float(camera.get("zoom", 1.0))
	# The shipped telegraph is a faint fill with a bright rim just inside its
	# radius and a pulsing alpha, so the read is the best pixel along four
	# spokes from the centre to the rim.
	var spokes: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	for fraction in [0.0, 0.7, 0.85, 1.0]:
		for direction in spokes:
			var probe: Vector2 = zone_center + direction * radius * float(fraction)
			if not arena_rect(size).has_point(probe):
				continue
			var candidate := image.get_pixelv(Vector2i(roundi(probe.x), roundi(probe.y)))
			if absf(luma(candidate) - luma(floor_color)) > absf(luma(zone_pixel) - luma(floor_color)):
				zone_pixel = candidate
	var bolt := projectile_rect(_vector(world.get("projectile", [0.0, 0.0])), camera, size)
	var bolt_in_frame := arena_rect(size).encloses(bolt.grow(PROJECTILE_SURROUND_PX))
	var bolt_probe := projectile_contrast_ratio(image, bolt, surround_color(image, bolt, PROJECTILE_SURROUND_PX), float(camera.get("zoom", 1.0))) if bolt_in_frame else {"ratio": -1.0, "drawn_pixels": 0}
	var bolt_ratio := float(bolt_probe["ratio"])
	var mode := mode_spec(str(entry["mode"]))
	var weapon := weapon_spec(str(entry["weapon_id"]))
	return {
		"hud_contrast_ratio": snappedf(contrast_ratio(image, hud_band_rect(size), hud_background, HUD_CONTRAST_MIN), 0.0001),
		"player_contrast_ratio": snappedf(contrast_ratio(image, project_rect(player, PLAYER_FOOTPRINT, camera, size), floor_color, ENTITY_CONTRAST_MIN), 0.0001),
		"enemy_contrast_ratios": enemies,
		"hazard_zone_contrast": snappedf(absf(luma(zone_pixel) - luma(floor_color)), 0.001),
		"hazard_zone_warm": zone_pixel.r > zone_pixel.g and zone_pixel.r > zone_pixel.b,
		"projectile_contrast_ratio": snappedf(bolt_ratio, 0.0001),
		"projectile_drawn_pixels": int(bolt_probe["drawn_pixels"]),
		"projectile_readable": bolt_in_frame and bolt_ratio >= PROJECTILE_CONTRAST_MIN_RATIO,
		"mode_swatch_matches": color_near(image.get_pixelv(Vector2i(mode_swatch_rect(size).get_center())), mode.get("swatch", Color.WHITE) as Color),
		"weapon_swatch_matches": color_near(image.get_pixelv(Vector2i(weapon_swatch_rect(size).get_center())), weapon.get("swatch", Color.WHITE) as Color),
	}


static func readability_violations(entry: Dictionary, report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := entry_id(entry)
	if float(report.get("hud_contrast_ratio", 0.0)) < HUD_CONTRAST_MIN_RATIO:
		errors.append("%s: HUD band shows no readable HUD (contrast ratio %.4f)" % [id, float(report.get("hud_contrast_ratio", 0.0))])
	if float(report.get("player_contrast_ratio", 0.0)) < PLAYER_CONTRAST_MIN_RATIO:
		errors.append("%s: the Player is not readable against the floor (contrast ratio %.4f)" % [id, float(report.get("player_contrast_ratio", 0.0))])
	var enemies: Array = report.get("enemy_contrast_ratios", [])
	if enemies.is_empty():
		errors.append("%s: no enemy stands inside the arena frame" % id)
	var readable := 0
	for value in enemies:
		if float(value) >= ENEMY_CONTRAST_MIN_RATIO:
			readable += 1
	if readable * 2 < enemies.size():
		errors.append("%s: fewer than half of the enemies in frame are readable (%d of %d)" % [id, readable, enemies.size()])
	if float(report.get("hazard_zone_contrast", 0.0)) < HAZARD_CONTRAST_MIN or not bool(report.get("hazard_zone_warm", false)):
		errors.append("%s: the hazard telegraph is not readable through the effect (%s)" % [id, str(report.get("hazard_zone_contrast"))])
	if float(report.get("projectile_contrast_ratio", -1.0)) >= 0.0 and not bool(report.get("projectile_readable", false)):
		errors.append("%s: the enemy projectile is not readable against its surround (contrast ratio %.4f)" % [id, float(report.get("projectile_contrast_ratio", 0.0))])
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
		errors.append("manifest must stay %s-local" % CLASS_ID)
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
	if source.get("worktree_clean") != true:
		errors.append("manifest source.worktree_clean must be true: the amended source is committed before the capture")
	errors.append_array(git_source_violations(source))
	if str(source.get("recorded_by", "")) != SOURCE_RECORDER:
		errors.append("manifest source must be recorded by %s, not typed in" % SOURCE_RECORDER)
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
		errors.append("manifest capture.capture_command must record the exclusive fixed-fps windowed command")
	if capture.get("exclusive_gate") != true:
		errors.append("manifest capture.exclusive_gate must record the exclusive process admission (FSD_GODOT_EXCLUSIVE=1)")
	if str(capture.get("accessibility_policy", "")) != POLICY_MODULE:
		errors.append("manifest capture.accessibility_policy must name %s" % POLICY_MODULE)
	if str(capture.get("test_command", "")) != TEST_COMMAND:
		errors.append("manifest capture.test_command must record the gated headless command")
	if int(capture.get("seed", -1)) != CAPTURE_SEED:
		errors.append("manifest capture.seed must record %d" % CAPTURE_SEED)
	if int(capture.get("fixed_fps", -1)) != FIXED_FPS:
		errors.append("manifest capture.fixed_fps must record %d" % FIXED_FPS)
	if str(capture.get("method", "")).strip_edges().is_empty():
		errors.append("manifest capture.method must describe the capture")
	if capture.get("headless_skipped") != false:
		errors.append("manifest must record a windowed run, not a headless skip")
	if capture.get("real_runtime") != true:
		errors.append("manifest must record the real-runtime capture path")
	var viewports := manifest.get("viewports", {}) as Dictionary
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var declared := viewports.get(str(viewport["id"]), {}) as Dictionary
		var size := viewport["size"] as Vector2i
		if int(declared.get("width", -1)) != size.x or int(declared.get("height", -1)) != size.y:
			errors.append("manifest viewports.%s must declare %dx%d" % [str(viewport["id"]), size.x, size.y])
	if _string_list(manifest.get("modes")) != MODE_IDS:
		errors.append("manifest modes must list %s" % [MODE_IDS])
	return errors


## The committed set equals the spec set exactly, at the viewport size its slot
## demands, with the beat, mode configuration, camera state and hash recorded.
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
		if int(capture.get("frame", -1)) != beat_frame(str(capture["weapon_id"]), str(capture["beat"])):
			errors.append("capture %s must sample frame %d of the fixed-fps run" % [id, beat_frame(str(capture["weapon_id"]), str(capture["beat"]))])
		var mode := mode_spec(str(capture["mode"]))
		if int(capture.get("enemies", -1)) != enemy_count(str(capture["weapon_id"]), mode):
			errors.append("capture %s must stand %d real enemies" % [id, enemy_count(str(capture["weapon_id"]), mode)])
		var policy := capture.get("accessibility", {}) as Dictionary
		if policy.get(Accessibility.REDUCED_MOTION_KEY) != bool(mode.get("reduced_motion", false)) \
				or policy.get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY) != bool(mode.get("photosensitivity_safe", false)):
			errors.append("capture %s must record the %s production accessibility snapshot" % [id, str(capture["mode"])])
		var digest := str(capture.get("sha256", ""))
		if digest.length() != 64 or not digest.is_valid_hex_number():
			errors.append("capture %s must pin a sha256" % id)
		var camera := capture.get("camera", {}) as Dictionary
		if not (camera.get("center") is Array) or not (camera.get("offset") is Array) or not is_equal_approx(float(camera.get("zoom", 0.0)), camera_zoom(size)):
			errors.append("capture %s must record its camera centre, offset and the %.4f zoom" % [id, camera_zoom(size)])
		var world := capture.get("world", {}) as Dictionary
		if (world.get("enemies", []) as Array).size() != enemy_count(str(capture["weapon_id"]), mode):
			errors.append("capture %s must record every enemy position" % id)
		if not (world.get("player") is Array) or not (world.get("hazard_zone") is Dictionary) or not (world.get("projectile") is Array):
			errors.append("capture %s must record the Player, hazard and projectile positions" % id)
		if not bool(capture.get("activation_started", false)):
			errors.append("capture %s must come from a started activation" % id)
	for id in expected:
		if not seen.has(id):
			errors.append("capture %s is missing" % id)
	var summary := manifest.get("coverage", {}) as Dictionary
	if int(summary.get("expected_frames", -1)) != expected.size() or int(summary.get("written_frames", -1)) != expected.size():
		errors.append("manifest coverage must account for all %d frames" % expected.size())
	return errors


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


## Decodes each frame, recomputes its readability record and the measured
## HUD clearance, and returns the decoded images keyed by entry id.
func _check_files(manifest: Dictionary, errors: Array[String]) -> Dictionary:
	var images := {}
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
		images[entry_id(capture)] = image
		var report := readability_report(image, capture, capture)
		errors.append_array(readability_violations(capture, report))
		var recorded := capture.get("readability", {}) as Dictionary
		for field in ["hud_contrast_ratio", "player_contrast_ratio"]:
			if absf(float(recorded.get(field, -1.0)) - float(report.get(field, 0.0))) > 0.0005:
				errors.append("%s: recorded %s %s disagrees with the frame (%s)" % [entry_id(capture), field, str(recorded.get(field)), str(report.get(field))])
		var measured := capture.get("measured", {}) as Dictionary
		var coverage := float(measured.get("opaque_coverage_ratio", -1.0))
		if coverage < 0.0 or coverage > Contract.MAX_VIEWPORT_COVERAGE_RATIO:
			errors.append("%s: measured opaque coverage %.4f is outside 0..%.2f" % [entry_id(capture), coverage, Contract.MAX_VIEWPORT_COVERAGE_RATIO])
		if measured.get("hud_band_clear") != true:
			errors.append("%s: the effect must keep the HUD band clear" % entry_id(capture))
		if float(measured.get("fullscreen_alpha", 1.0)) > MAX_OVERLAY_ALPHA:
			errors.append("%s: full-screen surface alpha over the %.2f ceiling" % [entry_id(capture), MAX_OVERLAY_ALPHA])
		if bool(mode_spec(str(capture["mode"])).get("photosensitivity_safe", false)) and not is_zero_approx(float(measured.get("fullscreen_alpha", 1.0))):
			errors.append("%s: photosensitivity-safe frame must draw no full-screen surface" % entry_id(capture))
	return images


## Each non-normal frame against its normal twin, as pixels outside the
## overlays, judged by the effect the manifest claims for that weapon and mode
## and by the camera/device evidence recorded for the run.
static func mode_violations(manifest: Dictionary, images: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var captures := {}
	for raw_capture in manifest.get("captures", []) as Array:
		if raw_capture is Dictionary:
			captures[entry_id(raw_capture)] = raw_capture
	var runs := _runs_by_id(manifest)
	for weapon_id in weapon_ids():
		var effects := mode_effects(manifest, weapon_id)
		for mode_id in [MODE_CROWDED, MODE_REDUCED_MOTION, MODE_PHOTOSENSITIVITY_SAFE]:
			var effect := effects.get(mode_id, {}) as Dictionary
			var kind := str(effect.get("effect", ""))
			if kind.is_empty():
				errors.append("%s/%s: manifest must record the mode effect" % [weapon_id, mode_id])
				continue
			if kind == EFFECT_NONE_INTRINSIC and str(effect.get("production_semantics", "")).strip_edges().is_empty():
				errors.append("%s/%s: an intrinsic no-op must state its production semantics" % [weapon_id, mode_id])
			# Every mode is judged against the normal twin: the production
			# preferences are independent, so photosensitivity-safe keeps the
			# camera device and differs from normal only by the surface.
			var baseline_mode := MODE_NORMAL
			for viewport_id in VIEWPORT_IDS:
				for beat_id in beat_ids(weapon_id):
					var id := entry_id({"weapon_id": weapon_id, "mode": mode_id, "viewport": viewport_id, "beat": beat_id})
					var base_id := entry_id({"weapon_id": weapon_id, "mode": baseline_mode, "viewport": viewport_id, "beat": beat_id})
					if not images.has(id) or not images.has(base_id):
						continue
					var ratio := arena_diff_ratio(images[id] as Image, images[base_id] as Image)
					var capture := captures[id] as Dictionary
					var base := captures[base_id] as Dictionary
					var offset := _vector((capture.get("camera", {}) as Dictionary).get("offset", [0.0, 0.0]))
					var base_offset := _vector((base.get("camera", {}) as Dictionary).get("offset", [0.0, 0.0]))
					match kind:
						EFFECT_CROWD:
							if ratio < MIN_MODE_DIFF_RATIO:
								errors.append("%s: the crowded frame must differ from normal outside the overlays" % id)
						EFFECT_CAMERA_SHAKE:
							if not offset.is_zero_approx():
								errors.append("%s: the reduced-motion camera must hold zero offset, got %s" % [id, offset])
							if beat_id == "impact" and bool(base.get("presentation_live", true)):
								if base_offset.is_zero_approx():
									errors.append("%s: the normal twin must show the shake device live at the impact beat" % id)
								if ratio < MIN_MODE_DIFF_RATIO:
									errors.append("%s: the reduced-motion impact frame must differ from the shaken normal frame" % id)
						EFFECT_FULLSCREEN_SUPPRESSED:
							# A lit surface in the normal twin must be visibly gone; a beat
							# whose presentation is already released in the normal twin
							# (nothing to remove) must reproduce it exactly.
							var base_lit := bool(base.get("presentation_live", true)) and float((base.get("measured", {}) as Dictionary).get("fullscreen_alpha", 0.0)) > 0.0
							if base_lit and ratio < MIN_MODE_DIFF_RATIO and beat_id in ["impact", "active"]:
								errors.append("%s: the photosensitivity-safe policy must visibly remove the lit full-screen surface" % id)
							if not base_lit and ratio > 0.0:
								errors.append("%s: with no surface lit in the normal twin the photosensitivity-safe frame must reproduce it exactly, differs by %.4f" % [id, ratio])
						EFFECT_NONE_INTRINSIC:
							if ratio > 0.0:
								errors.append("%s: an intrinsic no-op must reproduce its baseline frame exactly, differs by %.4f" % [id, ratio])
						_:
							errors.append("%s: unknown mode effect %s" % [id, kind])
			# The device evidence behind the claim: the recorded camera trace.
			if mode_id == MODE_REDUCED_MOTION:
				for viewport_id in VIEWPORT_IDS:
					var normal_run := runs.get(_run_id(weapon_id, MODE_NORMAL, viewport_id), {}) as Dictionary
					var reduced_run := runs.get(_run_id(weapon_id, MODE_REDUCED_MOTION, viewport_id), {}) as Dictionary
					var normal_peak := float((normal_run.get("camera_trace", {}) as Dictionary).get("max_offset", -1.0))
					var reduced_peak := float((reduced_run.get("camera_trace", {}) as Dictionary).get("max_offset", -1.0))
					if normal_peak < 0.0 or reduced_peak < 0.0:
						errors.append("%s/%s: both runs must record a camera trace" % [weapon_id, viewport_id])
						continue
					if kind == EFFECT_CAMERA_SHAKE and normal_peak <= 0.0:
						errors.append("%s/%s: a camera_shake claim needs a non-zero offset in the normal run" % [weapon_id, viewport_id])
					if kind == EFFECT_NONE_INTRINSIC and normal_peak > 0.0:
						errors.append("%s/%s: the normal run shook the camera, so reduced motion is not an intrinsic no-op" % [weapon_id, viewport_id])
					if reduced_peak > 0.0:
						errors.append("%s/%s: the reduced-motion run moved the camera by %.3f" % [weapon_id, viewport_id, reduced_peak])
			if mode_id == MODE_PHOTOSENSITIVITY_SAFE:
				for viewport_id in VIEWPORT_IDS:
					var normal_run := runs.get(_run_id(weapon_id, MODE_NORMAL, viewport_id), {}) as Dictionary
					var surfaces := int(normal_run.get("fullscreen_surfaces", -1))
					if kind == EFFECT_FULLSCREEN_SUPPRESSED and surfaces <= 0:
						errors.append("%s/%s: a suppression claim needs a full-screen surface in the live scene" % [weapon_id, viewport_id])
					if kind == EFFECT_NONE_INTRINSIC and surfaces != 0:
						errors.append("%s/%s: the live scene authors %d full-screen surfaces, so photosensitivity-safe is not an intrinsic no-op" % [weapon_id, viewport_id, surfaces])
		# Payoff beats past the phase envelope must show something the envelope did not.
		for beat_id in (weapon_spec(weapon_id).get("payoff_beats", {}) as Dictionary):
			for viewport_id in VIEWPORT_IDS:
				var id := entry_id({"weapon_id": weapon_id, "mode": MODE_NORMAL, "viewport": viewport_id, "beat": str(beat_id)})
				var recovery_id := entry_id({"weapon_id": weapon_id, "mode": MODE_NORMAL, "viewport": viewport_id, "beat": "recovery"})
				if images.has(id) and images.has(recovery_id):
					if arena_diff_ratio(images[id] as Image, images[recovery_id] as Image) < MIN_MODE_DIFF_RATIO:
						errors.append("%s: the payoff beat must visibly differ from the recovery frame" % id)
	return errors


## The presentation clock of a live cast, read from the host's runtime.
static func presentation_elapsed(host: Node) -> float:
	if host == null or not is_instance_valid(host):
		return -1.0
	var presentation = host.get("_presentation")
	if presentation == null:
		return -1.0
	var timeline = presentation.get("_timeline")
	if timeline == null or not timeline.has_method("elapsed_seconds"):
		return -1.0
	return float(timeline.elapsed_seconds())


## Two real-time casts never land on the same frame, so a beat is compared on
## the pair of samples (one per run, at or after the beat, within two frames
## of it) whose presentation clocks are closest to each other.
## The pair of samples inside the beat window whose formations agree, closest
## in time first; on the real clock the two runs sample the drawn pose at
## slightly different phases of a fast beat (the hitstop shifts the drawn
## clock by whole frames), so the nearest pair alone is not the fair test.
## Falls back to the closest pair so a genuine mismatch is reported with it.
static func matching_samples(a: Array, b: Array, beat: float) -> Array:
	var window := beat + 3.0 / float(FIXED_FPS)
	var candidates: Array = []
	for left in a:
		var la := float((left as Dictionary)["elapsed"])
		if la < beat or la > window:
			continue
		for right in b:
			var lb := float((right as Dictionary)["elapsed"])
			if lb < beat or lb > window:
				continue
			candidates.append([absf(la - lb), left, right])
	candidates.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	for candidate in candidates:
		if formation_close(str((candidate[1] as Dictionary)["signature"]), str((candidate[2] as Dictionary)["signature"])):
			return [candidate[1], candidate[2]]
	return [candidates[0][1], candidates[0][2]] if not candidates.is_empty() else []


static func closest_samples(a: Array, b: Array, beat: float) -> Array:
	var window := beat + 3.0 / float(FIXED_FPS)
	var best: Array = []
	var best_gap := INF
	for left in a:
		var la := float((left as Dictionary)["elapsed"])
		if la < beat or la > window:
			continue
		for right in b:
			var lb := float((right as Dictionary)["elapsed"])
			if lb < beat or lb > window:
				continue
			if absf(la - lb) < best_gap:
				best_gap = absf(la - lb)
				best = [left, right]
	return best


## A presentation the executor releases before its declared timeline must be
## recorded per run; the headless cast confirms the release time within a
## generous wall-clock tolerance (the capture runs on the fixed clock).
## The renderer watches a cast only until its last committed beat frame; a
## release it recorded (-1 = none inside its window) must agree with what the
## live cast does here: an observed release inside the recorded window must
## have been recorded at the same time, one past the window may be unrecorded.
static func _consistent_release(manifest: Dictionary, weapon_id: String, released_at: float) -> bool:
	var recorded := -1.0
	var window := timeline_seconds(weapon_id)
	for raw_run in manifest.get("runs", []) as Array:
		var run := raw_run as Dictionary
		if str(run.get("weapon_id", "")) == weapon_id and str(run.get("mode", "")) == MODE_NORMAL and str(run.get("viewport", "")) == BEAT_VIEWPORT:
			recorded = float(run.get("presentation_released_seconds", -1.0))
			window = float(run.get("frames", 0)) / float(FIXED_FPS)
	if released_at < 0.0:
		return recorded < 0.0 or recorded >= window - 0.35
	if recorded < 0.0:
		return released_at >= window - 0.35
	return absf(recorded - released_at) <= 0.35


static func mode_effects(manifest: Dictionary, weapon_id: String) -> Dictionary:
	for raw_weapon in manifest.get("weapons", []) as Array:
		if raw_weapon is Dictionary and str((raw_weapon as Dictionary).get("weapon_id", "")) == weapon_id:
			return (raw_weapon as Dictionary).get("mode_effects", {}) as Dictionary
	return {}


static func _run_id(weapon_id: String, mode_id: String, viewport_id: String) -> String:
	return "%s/%s/%s" % [weapon_id, mode_id, viewport_id]


static func _runs_by_id(manifest: Dictionary) -> Dictionary:
	var runs := {}
	for raw_run in manifest.get("runs", []) as Array:
		if raw_run is Dictionary:
			var run := raw_run as Dictionary
			runs[_run_id(str(run.get("weapon_id", "")), str(run.get("mode", "")), str(run.get("viewport", "")))] = run
	return runs


## The class manifest's quality block against the contract and the measurements:
## the declared cap covers every measured frame and the envelope sweep, the HUD
## clearance was measured true on every frame, and the flash declaration matches
## the live surface count.
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
	var records := {}
	for raw_weapon in manifest.get("weapons", []) as Array:
		if raw_weapon is Dictionary:
			records[str((raw_weapon as Dictionary).get("weapon_id", ""))] = raw_weapon
	for raw_weapon in class_manifest.get("weapons", []) as Array:
		if not raw_weapon is Dictionary:
			continue
		var weapon := raw_weapon as Dictionary
		var weapon_id := str(weapon.get("weapon_id", ""))
		var quality := weapon.get("quality", {}) as Dictionary
		var declared := float(quality.get("max_viewport_coverage_ratio", 0.0))
		var record := records.get(weapon_id, {}) as Dictionary
		var sweep := record.get("envelope_sweep", {}) as Dictionary
		var peak := maxf(float(measured_by_weapon.get(weapon_id, 0.0)), float(sweep.get("peak_opaque_coverage_ratio", 0.0)))
		if int(sweep.get("samples", 0)) <= 0:
			errors.append("%s: manifest must record a full-envelope coverage sweep" % weapon_id)
		if peak <= 0.0:
			errors.append("%s: measured coverage must be positive; the effect must actually draw" % weapon_id)
		if declared < peak:
			errors.append("%s: declared max_viewport_coverage_ratio %.3f is under the measured %.4f" % [weapon_id, declared, peak])
		if not is_zero_approx(float(quality.get("full_screen_flash_hz", -1.0))):
			errors.append("%s: no cast repeats a full-screen flash, full_screen_flash_hz must be 0.0" % weapon_id)
		var surfaces := int(record.get("fullscreen_surfaces", -1))
		var flash_coverage := float(quality.get("max_flash_coverage_ratio", -1.0))
		var backdrop := str((weapon.get("presence", {}) as Dictionary).get("backdrop", ""))
		if surfaces == 0 and not is_zero_approx(flash_coverage):
			errors.append("%s: the live scene authors no full-screen surface, max_flash_coverage_ratio must be 0.0" % weapon_id)
		if surfaces > 0 and backdrop == "flash" and not is_equal_approx(flash_coverage, 1.0):
			errors.append("%s: a live full-screen flash surface must declare max_flash_coverage_ratio 1.0" % weapon_id)
		if surfaces > 0 and backdrop != "flash" and not is_zero_approx(flash_coverage):
			errors.append("%s: a darken surface is not a flash, max_flash_coverage_ratio must be 0.0" % weapon_id)
		if quality.get("hud_bands_clear") == true and record.get("hud_band_clear_all_frames") != true:
			errors.append("%s: hud_bands_clear is declared but not measured true on every frame" % weapon_id)
		if not str(quality.get("reduced_motion_substitute", "")).contains("ultimate_reduced_motion"):
			errors.append("%s: reduced_motion_substitute must name the production ultimate_reduced_motion preference it honours" % weapon_id)
	return errors


static func class_manifest_link_violations(class_manifest: Dictionary, capture_manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var evidence := class_manifest.get("evidence", {}) as Dictionary
	var certification := evidence.get("certification", {}) as Dictionary
	if certification.is_empty():
		errors.append("class manifest must carry evidence.certification")
		return errors
	var source := capture_manifest.get("source", {}) as Dictionary
	var expected := {
		"issue": ISSUE,
		"capture_manifest": MANIFEST_PATH.trim_prefix("res://"),
		"readability_report": READABILITY_REPORT,
		"capture_script": CAPTURE_SCRIPT,
		"focused_test": FOCUSED_TEST,
		"source_ref": SOURCE_REF,
		"source_commit_sha": str(source.get("commit_sha", "")),
		"source_tree_sha": str(source.get("tree_sha", "")),
		"accessibility_policy": POLICY_MODULE,
		"exclusive_gate": true,
	}
	for field in expected:
		if str(certification.get(field, "")) != str(expected[field]):
			errors.append("class manifest evidence.certification.%s must be %s" % [field, str(expected[field])])
	for field in ["capture_manifest", "readability_report", "capture_script", "focused_test"]:
		if not FileAccess.file_exists("res://" + str(certification.get(field, ""))):
			errors.append("class manifest evidence.certification.%s must exist" % field)
	if _string_list(certification.get("modes")) != MODE_IDS:
		errors.append("class manifest evidence.certification.modes must list %s" % [MODE_IDS])
	if int(certification.get("frames", -1)) != expected_entries().size():
		errors.append("class manifest evidence.certification.frames must be %d" % expected_entries().size())
	var viewports := certification.get("viewports", {}) as Dictionary
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		if str(viewports.get(str(viewport["id"]), "")) != "%dx%d" % [size.x, size.y]:
			errors.append("class manifest evidence.certification.viewports.%s must be %dx%d" % [str(viewport["id"]), size.x, size.y])
	return errors


static func adoption_violations() -> Array[String]:
	var errors: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADOPTION_SHARD_PATH))
	if not parsed is Dictionary:
		errors.append("adoption shard must parse")
		return errors
	var shard := parsed as Dictionary
	if str(shard.get("class_id", "")) != CLASS_ID:
		errors.append("adoption shard must be %s-local" % CLASS_ID)
	var gaps: Variant = shard.get("adoption_gaps")
	if not gaps is Dictionary or not (gaps as Dictionary).is_empty():
		errors.append("adoption shard must declare no gap, got %s" % str(gaps))
	return errors


# --- real-runtime driving (shared with the renderer) ------------------------


## The production accessibility policy, published exactly as main.gd
## publishes the saved settings; the shipped screen_shake toggle stays on.
static func apply_mode(tree: SceneTree, mode: Dictionary) -> void:
	tree.root.set_meta("screen_shake", true)
	Accessibility.apply_snapshot(tree.root, mode_snapshot(mode))


static func reset_mode(tree: SceneTree) -> void:
	tree.root.set_meta("screen_shake", true)
	Accessibility.apply_snapshot(tree.root, mode_snapshot(mode_spec(MODE_NORMAL)))


static func mode_snapshot(mode: Dictionary) -> Dictionary:
	return {
		Accessibility.REDUCED_MOTION_KEY: bool(mode.get("reduced_motion", false)),
		Accessibility.PHOTOSENSITIVITY_SAFE_KEY: bool(mode.get("photosensitivity_safe", false)),
	}


## The snapshot the tree root publishes right now, as the frames record it.
static func current_snapshot(tree: SceneTree) -> Dictionary:
	return Accessibility.read_snapshot(tree.root)


## The live authored scene of the cast, read from the host's own presentation
## runtime (the exact instance it begins and releases), with the effect-parent
## name lookup as the fallback for a host without one.
static func live_scene(host: Node, world: Node, weapon_id: String) -> Node:
	if host != null and is_instance_valid(host):
		var presentation = host.get("_presentation")
		if presentation != null:
			var scene = presentation.get("_scene")
			if scene is Node and is_instance_valid(scene):
				return scene as Node
	return world.get_node_or_null(str(weapon_spec(weapon_id).get("scene_node", "")))


## Nodes the live scene flags as full-screen layers (the arena-wide veil).
static func fullscreen_nodes(scene: Node) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	if scene == null:
		return found
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node != scene and node is CanvasItem and (node.get_meta("fullscreen_layer", false) == true or node is CanvasLayer):
			found.append(node as CanvasItem)
		for child in node.get_children():
			pending.append(child)
	return found


static func fullscreen_alpha(scene: Node) -> float:
	var alpha := 0.0
	for node in fullscreen_nodes(scene):
		if node.visible:
			alpha = maxf(alpha, node.self_modulate.a * node.modulate.a)
	return alpha


## What the live scene draws, as a device-independent signature of its
## Sprite2D/Node2D children: position, scale, rotation, alpha, visibility.
## Two signatures sampled by different runs at the closest presentation-clock
## pair around a beat: under the documented fixed clock the pair is exact and
## the signatures must be identical; on a real-time clock the pair can sit up
## to half a frame apart, so every field may differ by that much motion (the
## fastest authored element, a launching bolt, covers about 8 px per frame) and
## a node fading through zero may differ in visibility. A retimed or altered
## variant is far outside these bounds.
const FORMATION_POSITION_TOLERANCE := 12.0
const FORMATION_SCALE_TOLERANCE := 0.06
const FORMATION_ROTATION_TOLERANCE := 0.12
const FORMATION_ALPHA_TOLERANCE := 0.15
const FORMATION_FADE_ALPHA := 0.2


static func formation_close(a: String, b: String) -> bool:
	if a == b:
		return true
	var left := a.split("|")
	var right := b.split("|")
	if left.size() != right.size():
		return false
	for index in left.size():
		var fa := left[index].split(":")
		var fb := right[index].split(":")
		if fa.size() != 7 or fb.size() != 7 or fa[0] != fb[0]:
			return false
		if fa[6] != fb[6] and (float(fa[5]) > FORMATION_FADE_ALPHA or float(fb[5]) > FORMATION_FADE_ALPHA):
			return false
		if absf(float(fa[1]) - float(fb[1])) > FORMATION_POSITION_TOLERANCE or absf(float(fa[2]) - float(fb[2])) > FORMATION_POSITION_TOLERANCE:
			return false
		if absf(float(fa[3]) - float(fb[3])) > FORMATION_SCALE_TOLERANCE or absf(float(fa[4]) - float(fb[4])) > FORMATION_ROTATION_TOLERANCE:
			return false
		if absf(float(fa[5]) - float(fb[5])) > FORMATION_ALPHA_TOLERANCE:
			return false
	return true


static func formation_signature(scene: Node) -> String:
	var parts: Array[String] = []
	if scene == null:
		return ""
	var children := scene.get_children()
	for index in children.size():
		var node := children[index] as Node2D
		if node == null or node.get_meta("fullscreen_layer", false) == true or node.get_script() != null:
			continue
		# Runtime-built sprites get engine-generated names that differ between
		# casts; they are keyed by their child index instead.
		var label := "#%d" % index if str(node.name).begins_with("@") else str(node.name)
		parts.append("%s:%.2f:%.2f:%.3f:%.3f:%.2f:%s" % [
			label, node.position.x, node.position.y, node.scale.x, node.rotation, node.modulate.a, str(node.visible),
		])
	return "|".join(parts)


class Arena extends RefCounted:
	var world: Node2D = null
	var player: Node2D = null
	var host: Node = null
	var camera: Camera2D = null
	var enemies: Array[Node2D] = []
	var hazard: Node2D = null
	var projectile: Node2D = null


## Builds the real world: shipped Player at the origin with its own camera,
## real enemies on the spiral, a real hazard telegraph and enemy projectile,
## all frozen in place so the frame depends only on the cast.
static func build_arena(tree: SceneTree, parent: Node, weapon_id: String, mode: Dictionary, zoom: float, headless_presentation: bool) -> Arena:
	var arena := Arena.new()
	arena.world = Node2D.new()
	arena.world.name = "CertificationWorld"
	parent.add_child(arena.world)
	# The current scene must be a direct child of the root: the SubViewport
	# (renderer) or the holder (gate). Executors that parent effects to it then
	# land inside the captured world.
	tree.current_scene = parent
	arena.player = PlayerScene.instantiate() as Node2D
	arena.player.position = PLAYER_ORIGIN
	arena.world.add_child(arena.player)
	arena.player.call("configure_character", CLASS_ID, weapon_id)
	arena.player.set("ultimate_charge", arena.player.get("ultimate_max_charge"))
	hold_basic_attack(tree, arena.player)
	arena.camera = arena.player.get_node_or_null("Camera2D") as Camera2D
	if arena.camera != null:
		arena.camera.zoom = Vector2.ONE * zoom
		arena.camera.position_smoothing_enabled = false
		arena.camera.offset = Vector2.ZERO
		arena.camera.enabled = true
		# A headless contract tree parents the arena before root is in the
		# tree; the camera becomes current once it is.
		if arena.camera.is_inside_tree():
			arena.camera.make_current()
		else:
			arena.camera.call_deferred("make_current")
	arena.host = PlayerHost.for_player(arena.player)
	if headless_presentation:
		arena.host.set("_presentation_headless_mode", LIVE_PRESENTATION_HEADLESS_MODE)
	for position in enemy_positions(enemy_count(weapon_id, mode)):
		var enemy := EnemyScene.instantiate() as Node2D
		enemy.position = position
		enemy.set("max_health", ENEMY_HEALTH)
		enemy.set("health", ENEMY_HEALTH)
		arena.world.add_child(enemy)
		enemy.set_physics_process(false)
		arena.enemies.append(enemy)
	return arena


## The hero's basic weapon auto-fires from its own _process; it is held for
## the certification cast so the frame shows the ultimate acting on the world,
## not the basic attack (its VFX also expects the game's Main scene as parent).
static func hold_basic_attack(tree: SceneTree, player: Node) -> void:
	for raw_weapon in tree.get_nodes_in_group("player_weapons"):
		var weapon := raw_weapon as Node
		if weapon != null and player.is_ancestor_of(weapon):
			weapon.set_process(false)
			weapon.set_physics_process(false)


static func arena_world_record(arena: Arena) -> Dictionary:
	var enemies: Array = []
	for enemy in arena.enemies:
		if is_instance_valid(enemy):
			enemies.append([snappedf(enemy.global_position.x, 0.01), snappedf(enemy.global_position.y, 0.01)])
	return {
		"player": [snappedf(arena.player.global_position.x, 0.01), snappedf(arena.player.global_position.y, 0.01)],
		"enemies": enemies,
		"hazard_zone": {"center": [hazard_zone_center().x, hazard_zone_center().y], "radius": HAZARD_ZONE_RADIUS},
		"projectile": [projectile_position().x, projectile_position().y],
		"aim_center": [aim_center().x, aim_center().y],
	}


## The shipped Player camera carries a small constant feet-lift offset
## (player.gd), so the shake device is read as the deviation from the offset
## the camera held before the cast began.
static func shake_offset(camera: Camera2D, baseline: Vector2) -> Vector2:
	return camera.offset - baseline if camera != null else Vector2.ZERO


static func camera_record(camera: Camera2D, baseline: Vector2) -> Dictionary:
	if camera == null:
		return {"center": [0.0, 0.0], "offset": [0.0, 0.0], "baseline_offset": [0.0, 0.0], "zoom": 1.0}
	var center := camera.get_screen_center_position()
	var shake := shake_offset(camera, baseline)
	return {
		"center": [snappedf(center.x, 0.001), snappedf(center.y, 0.001)],
		"offset": [snappedf(shake.x, 0.001), snappedf(shake.y, 0.001)],
		"baseline_offset": [snappedf(baseline.x, 0.001), snappedf(baseline.y, 0.001)],
		"zoom": snappedf(camera.zoom.x, 0.0001),
	}


## Headless half of the device claim: the real cast is run for every weapon
## under the normal, reduced-motion and photosensitivity-safe production
## snapshots, the camera offset and the full-screen surface alpha are sampled
## every frame, so the mode effects the manifest records are what the runtime
## does under the shipped policy — not what a caption says.
func _check_live_devices(manifest: Dictionary, errors: Array[String]) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	root.set_meta("combat_feedback", false)
	for weapon_id in weapon_ids():
		var effects := mode_effects(manifest, weapon_id)
		var peaks := {}
		var surface_peaks := {}
		var signatures := {}
		var surfaces := -1
		for mode_id in [MODE_NORMAL, MODE_REDUCED_MOTION, MODE_PHOTOSENSITIVITY_SAFE]:
			var mode := mode_spec(mode_id)
			apply_mode(self, mode)
			var arena := build_arena(self, holder, weapon_id, mode, COMBAT_CAMERA_ZOOM, true)
			await process_frame
			await process_frame
			var baseline := arena.camera.offset if arena.camera != null else Vector2.ZERO
			var status: int = PlayerHost.activate(arena.player)
			_expect(status == PlayerHost.ACTIVATION_STARTED, "%s/%s: the real cast must start headless, got %d (%s)" % [weapon_id, mode_id, status, PlayerHost.activation_failure(arena.player)], errors)
			var peak := 0.0
			var surface_peak := 0.0
			var scene := live_scene(arena.host, arena.world, weapon_id)
			_expect(scene != null and scene.is_inside_tree(), "%s/%s: the authored scene must be live under the effect parent" % [weapon_id, mode_id], errors)
			if scene != null and mode_id == MODE_NORMAL:
				surfaces = fullscreen_nodes(scene).size()
			var duration := timeline_seconds(weapon_id) + 0.3
			# Simulated seconds (the sum of process deltas), so the check reads the
			# same clock whether the engine runs on the fixed clock or real time.
			var elapsed := 0.0
			var trace: Array[Dictionary] = []
			var released_at := -1.0
			while elapsed < duration and status == PlayerHost.ACTIVATION_STARTED:
				await process_frame
				elapsed += root.get_process_delta_time()
				if arena.camera != null:
					peak = maxf(peak, shake_offset(arena.camera, baseline).length())
				var live := scene != null and is_instance_valid(scene) and scene.is_inside_tree()
				if live:
					surface_peak = maxf(surface_peak, fullscreen_alpha(scene))
				if not live and released_at < 0.0:
					released_at = elapsed
				var clock := presentation_elapsed(arena.host)
				trace.append({"elapsed": clock if clock >= 0.0 else elapsed, "signature": formation_signature(scene) if live else "released"})
			peaks[mode_id] = peak
			surface_peaks[mode_id] = surface_peak
			signatures[mode_id] = trace
			_expect(_consistent_release(manifest, weapon_id, released_at), "%s/%s: the live cast released its presentation at %.2f s, which the manifest must record as presentation_released_seconds" % [weapon_id, mode_id, released_at], errors)
			arena.host.controller().cancel()
			arena.world.queue_free()
			await process_frame
		var reduced := effects.get(MODE_REDUCED_MOTION, {}) as Dictionary
		var kind := str(reduced.get("effect", ""))
		if kind == EFFECT_CAMERA_SHAKE:
			_expect(float(peaks[MODE_NORMAL]) > 0.0, "%s: the manifest claims a camera shake device but the live cast never moved the camera" % weapon_id, errors)
		elif kind == EFFECT_NONE_INTRINSIC:
			_expect(float(peaks[MODE_NORMAL]) == 0.0, "%s: the live cast moved the camera by %.3f, so reduced motion is not an intrinsic no-op" % [weapon_id, float(peaks[MODE_NORMAL])], errors)
		_expect(float(peaks[MODE_REDUCED_MOTION]) == 0.0, "%s: the live cast must hold the camera still under ultimate_reduced_motion, moved %.3f" % [weapon_id, float(peaks[MODE_REDUCED_MOTION])], errors)
		var photo := effects.get(MODE_PHOTOSENSITIVITY_SAFE, {}) as Dictionary
		if str(photo.get("effect", "")) == EFFECT_FULLSCREEN_SUPPRESSED:
			_expect(surfaces > 0, "%s: the manifest claims a suppressed full-screen surface but the live scene authors none" % weapon_id, errors)
			_expect(float(surface_peaks[MODE_NORMAL]) > 0.0, "%s: the live scene never lit its full-screen surface in the normal cast" % weapon_id, errors)
		elif str(photo.get("effect", "")) == EFFECT_NONE_INTRINSIC:
			_expect(surfaces == 0, "%s: the live scene authors %d full-screen surfaces" % [weapon_id, surfaces], errors)
		_expect(float(surface_peaks[MODE_PHOTOSENSITIVITY_SAFE]) == 0.0, "%s: the live cast must leave every full-screen surface dark under ultimate_photosensitivity_safe, peaked at %.3f" % [weapon_id, float(surface_peaks[MODE_PHOTOSENSITIVITY_SAFE])], errors)
		_expect(float(peaks[MODE_PHOTOSENSITIVITY_SAFE]) == float(peaks[MODE_NORMAL]) or float(peaks[MODE_NORMAL]) > 0.0, "%s: photosensitivity-safe must not change the camera device" % weapon_id, errors)
		var normal_trace := signatures.get(MODE_NORMAL, []) as Array
		var reduced_trace := signatures.get(MODE_REDUCED_MOTION, []) as Array
		for beat_id in BEAT_IDS:
			var pair := matching_samples(normal_trace, reduced_trace, beat_seconds(weapon_id, beat_id))
			_expect(not pair.is_empty(), "%s: the live cast must reach the %s beat in both modes" % [weapon_id, beat_id], errors)
			if not pair.is_empty():
				_expect(formation_close(str(pair[0]["signature"]), str(pair[1]["signature"])), "%s: reduced motion must preserve the formation and timing at the %s beat (%.3f s %s vs %.3f s %s)" % [weapon_id, beat_id, float(pair[0]["elapsed"]), str(pair[0]["signature"]).left(100), float(pair[1]["elapsed"]), str(pair[1]["signature"]).left(100)], errors)
	reset_mode(self)
	holder.queue_free()
	await process_frame


# --- negatives --------------------------------------------------------------


## Every validator is data-driven so it can be shown to reject: a dropped mode,
## a substituted key, a missing file, an LFS pointer, a wrong size, a wrong
## hash, an understated cap, a missing quality block, a blank frame, a
## fabricated mode frame (a normal frame relabelled as reduced motion), a
## shake claim without device evidence, and an invisible payoff all go red.
func _check_negatives(manifest: Dictionary, class_manifest: Dictionary, profile: Dictionary, images: Dictionary, errors: Array[String]) -> void:
	_expect(coverage_violations(manifest).is_empty(), "the committed coverage must pass before negatives are meaningful", errors)

	var missing_mode := manifest.duplicate(true)
	var trimmed: Array = []
	for raw_capture in missing_mode.get("captures", []) as Array:
		if str((raw_capture as Dictionary).get("mode", "")) != MODE_PHOTOSENSITIVITY_SAFE:
			trimmed.append(raw_capture)
	missing_mode["captures"] = trimmed
	_expect_red(coverage_violations(missing_mode), "a dropped presentation mode", errors)

	var missing_key := manifest.duplicate(true)
	((missing_key["captures"] as Array)[0] as Dictionary)["weapon_id"] = weapon_ids()[0] + "_v2"
	_expect_red(coverage_violations(missing_key), "a substituted weapon key", errors)

	var wrong_keys := manifest.duplicate(true)
	wrong_keys["canonical_keys"] = [key_for(weapon_ids()[0])]
	_expect_red(identity_violations(wrong_keys, profile), "a missing canonical key", errors)

	var wrong_source := manifest.duplicate(true)
	(wrong_source["source"] as Dictionary)["commit_sha"] = "0".repeat(40)
	_expect_red(identity_violations(wrong_source, profile), "an unpinned source commit", errors)
	var wrong_tree := manifest.duplicate(true)
	(wrong_tree["source"] as Dictionary)["tree_sha"] = "0".repeat(40)
	_expect_red(identity_violations(wrong_tree, profile), "a source tree that is not the recorded commit's tree", errors)

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

	var pointer_path := "user://fan3941_%s_pointer_probe.png" % CLASS_ID
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
	_expect_red(class_manifest_link_violations(unlinked, manifest), "a class manifest without the certification link", errors)
	var mispinned := class_manifest.duplicate(true)
	((mispinned["evidence"] as Dictionary)["certification"] as Dictionary)["source_commit_sha"] = "0000000000000000000000000000000000000000"
	_expect_red(class_manifest_link_violations(mispinned, manifest), "a class manifest pinning a source commit the capture did not record", errors)
	var self_referential := manifest.duplicate(true)
	(self_referential["source"] as Dictionary)["worktree_clean"] = false
	_expect_red(identity_violations(self_referential, profile), "a capture from a dirty worktree", errors)
	var shared := manifest.duplicate(true)
	(shared["capture"] as Dictionary)["exclusive_gate"] = false
	_expect_red(identity_violations(shared, profile), "a capture without the exclusive process admission", errors)

	var blank := Image.create_empty(64, 36, false, Image.FORMAT_RGBA8)
	blank.fill(FLOOR_COLOR)
	_expect_red(readability_violations(first, readability_report(blank, first, first)), "a blank frame", errors)

	# A relabelled frame standing in for the reduced-motion frame: for a cast
	# with a shake device the shaken normal frame must be rejected on the device
	# evidence; for a measured no-op (identical frames by design) the crowded
	# frame must be rejected because a no-op may not change the picture.
	var weapon_id := weapon_ids()[0]
	var reduced_kind := str((mode_effects(manifest, weapon_id).get(MODE_REDUCED_MOTION, {}) as Dictionary).get("effect", ""))
	var source_mode := MODE_NORMAL if reduced_kind == EFFECT_CAMERA_SHAKE else MODE_CROWDED
	var source_id := entry_id({"weapon_id": weapon_id, "mode": source_mode, "viewport": BEAT_VIEWPORT, "beat": "impact"})
	var reduced_id := entry_id({"weapon_id": weapon_id, "mode": MODE_REDUCED_MOTION, "viewport": BEAT_VIEWPORT, "beat": "impact"})
	if images.has(source_id) and images.has(reduced_id):
		var fabricated := images.duplicate()
		fabricated[reduced_id] = images[source_id]
		var relabelled := manifest.duplicate(true)
		for raw_capture in relabelled.get("captures", []) as Array:
			var capture := raw_capture as Dictionary
			if entry_id(capture) == reduced_id:
				var source_capture := _capture_by_id(manifest, source_id)
				capture["camera"] = (source_capture.get("camera", {}) as Dictionary).duplicate(true)
		_expect_red(mode_violations(relabelled, fabricated), "a %s frame relabelled as reduced motion" % source_mode, errors)

	# A shake claim whose recorded trace never moved the camera.
	var unproven := manifest.duplicate(true)
	for raw_weapon in unproven.get("weapons", []) as Array:
		((raw_weapon as Dictionary).get("mode_effects", {}) as Dictionary)[MODE_REDUCED_MOTION] = {"effect": EFFECT_CAMERA_SHAKE}
	for raw_run in unproven.get("runs", []) as Array:
		((raw_run as Dictionary).get("camera_trace", {}) as Dictionary)["max_offset"] = 0.0
	_expect_red(mode_violations(unproven, images), "a shake claim without device evidence", errors)

	# An intrinsic no-op that hides a changed frame.
	var hidden := manifest.duplicate(true)
	for raw_weapon in hidden.get("weapons", []) as Array:
		((raw_weapon as Dictionary).get("mode_effects", {}) as Dictionary)[MODE_CROWDED] = {"effect": EFFECT_NONE_INTRINSIC, "production_semantics": "probe"}
	_expect_red(mode_violations(hidden, images), "a crowd frame declared as an intrinsic no-op", errors)


static func _capture_by_id(manifest: Dictionary, id: String) -> Dictionary:
	for raw_capture in manifest.get("captures", []) as Array:
		if raw_capture is Dictionary and entry_id(raw_capture) == id:
			return raw_capture
	return {}


# --- helpers ----------------------------------------------------------------


static func _vector(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return Vector2.ZERO


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
		print("%s certification capture gate: %d real-runtime frames (%d weapons x %d modes x %d viewports) verified with readability probes, device-proven mode effects, coverage measurement, quality declaration, empty adoption shard and negatives." % [
			CLASS_ID.capitalize(), expected_entries().size(), WEAPONS.size(), MODES.size(), VIEWPORTS.size(),
		])
		quit(0)
		return
	for error in errors:
		push_error("%s certification capture gate: %s" % [CLASS_ID.capitalize(), error])
	quit(1)
