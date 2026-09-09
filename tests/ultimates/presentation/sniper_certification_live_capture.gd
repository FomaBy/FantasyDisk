extends SceneTree

## FAN-3940 windowed certification renderer for the Sniper ultimate class.
##
## Every cell is a native-resolution render of the shipped Sniper ultimate
## presentation scene plus its shipped weapon effect scene and victim-impact
## flipbook, over an arena that keeps a player marker, hazard markers and both
## HUD bands on screen. Nine native frames of one mode/viewport pair (three
## canonical weapons by the release, active and recovery beats) are downscaled
## into one contact sheet, so a committed sheet is a contact sheet of real
## native frames rather than a re-rendered miniature.
##
## The renderer also measures each native frame and writes the class-owned
## capture manifest, so the numbers in the readability report come from the
## same run that produced the PNGs.
##
## Headless runs own no render target and are skipped instead of writing empty
## evidence; sniper_certification_capture_test.gd is the gate that fails closed
## on a missing, pointer-only or wrong-sized capture.

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const ISSUE := "FAN-3940"
const CLASS_ID := "sniper"

## The captures are rendered from this integrated source, never from the commit
## that finally records them, so the pin is verifiable and not self-referential.
const CAPTURE_SOURCE_REF := "origin/dev"
const CAPTURE_SOURCE_SHA := "d192be10bbe52dd89971cab0acc66eb92ccab37f"
const CAPTURE_SOURCE_TREE := "e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf"
const CAPTURE_SEED := 39400

const OUTPUT_ROOT := "res://docs/design/reference-assets-lfs/ultimate-certification/sniper"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/sniper/certification_capture_manifest.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/sniper/manifest.json"
const READABILITY_REPORT_PATH := "docs/design/references/weapon_ultimates/sniper/certification_readability_report.md"
const CAPTURE_TEST_PATH := "tests/ultimates/presentation/sniper_certification_capture_test.gd"
const CAPTURE_SCRIPT_PATH := "tests/ultimates/presentation/sniper_certification_live_capture.gd"

const WEAPON_IDS: Array[String] = [
	"sniper_deadeye_rifle",
	"sniper_spotter_scope",
	"sniper_shatter_rounds",
]
const MODE_IDS: Array[String] = ["normal", "crowded", "reduced_motion", "photosensitivity_safe"]
const BEAT_IDS: Array[String] = ["release", "active", "recovery"]
const VIEWPORT_IDS: Array[String] = ["648p", "720p", "1080p", "2k"]

const VIEWPORT_SIZES := {
	"648p": Vector2i(1152, 648),
	"720p": Vector2i(1280, 720),
	"1080p": Vector2i(1920, 1080),
	"2k": Vector2i(2560, 1440),
}

## Both switches are the ones the shipped game publishes on the tree root from
## GameSettings: `screen_shake` gates the presentation's camera shake and
## `combat_feedback` gates the per-victim hit flash the shipped impact player
## asks each victim for. `hazards` of -1 means the weapon's declared crowd cap.
const MODE_SPECS := {
	"normal": {"label": "NORMAL", "screen_shake": true, "combat_feedback": true, "hazards": 3},
	"crowded": {"label": "CROWDED", "screen_shake": true, "combat_feedback": true, "hazards": -1},
	"reduced_motion": {"label": "REDUCED MOTION", "screen_shake": false, "combat_feedback": true, "hazards": 3},
	"photosensitivity_safe": {"label": "PHOTO-SAFE", "screen_shake": false, "combat_feedback": false, "hazards": 3},
}

const ULTIMATE_SCENES := {
	"sniper_deadeye_rifle": "res://scenes/vfx/ultimates/sniper/sniper_deadeye_rifle_ultimate.tscn",
	"sniper_spotter_scope": "res://scenes/vfx/ultimates/sniper/sniper_spotter_scope_ultimate.tscn",
	"sniper_shatter_rounds": "res://scenes/vfx/ultimates/sniper/sniper_shatter_rounds_ultimate.tscn",
}
const EFFECT_SCENES := {
	"sniper_deadeye_rifle": "res://scripts/ultimates/classes/sniper/sniper_deadeye_rifle.tscn",
	"sniper_spotter_scope": "res://scripts/ultimates/classes/sniper/sniper_spotter_scope.tscn",
	"sniper_shatter_rounds": "res://scripts/ultimates/classes/sniper/sniper_shatter_rounds.tscn",
}

const ARENA_COLOR := Color(0.020, 0.028, 0.044, 1.0)
const HUD_COLOR := Color(0.078, 0.112, 0.162, 1.0)
const PLAYER_COLOR := Color(0.68, 0.92, 1.0, 1.0)
const HAZARD_COLOR := Color(1.0, 0.32, 0.16, 1.0)
const SHEET_COLOR := Color(0.012, 0.016, 0.026, 1.0)
const CAPTION_COLOR := Color(0.90, 0.84, 0.62, 1.0)

const HUD_BAND_HEIGHT_RATIO := 0.09
const HUD_BOTTOM_TOP_RATIO := 0.91
const PLAYER_CENTER_RATIO := Vector2(0.500, 0.630)
const PLAYER_SIZE_RATIO := 0.030
const HAZARD_SIZE_RATIO := 0.022
const HAZARD_RADIUS_RATIO := Vector2(0.340, 0.300)
const HAZARD_INNER_SCALE := 0.62

## An opaque body — not the translucent backdrop treatment — is what would make
## a HUD band or a marker unreadable, so both use a deliberately high threshold
## while `EFFECT_PRESENCE_DELTA` only asks whether the arena is still untouched.
const OPAQUE_DELTA := 0.35
const EFFECT_PRESENCE_DELTA := 0.06
const CONTRAST_MIN := 0.12
const LOCAL_BACKGROUND_SCALE := 2.4
const LOCAL_BACKGROUND_SAMPLES := 8
const HAZARD_DOMINANCE_MARGIN := 0.12
const FLASH_STEP_SECONDS := 0.05

var _class_manifest: Dictionary = {}
var _flash_by_weapon: Dictionary = {}
var _records: Array[Dictionary] = []
var _sheets: Array[Dictionary] = []
var _errors: Array[String] = []


## A hazard that answers the two combat-feedback calls the shipped victim-impact
## player makes, mirroring `enemy.gd`: the same root-meta guard and the same
## additive impact_flash tick. Hard-coding the guard to `true` would have made
## the photosensitivity-safe mode indistinguishable from the others.
class HazardProbe extends Node2D:
	const HIT_FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")

	var health := 100.0
	var flashes := 0
	var reach := 48.0

	func _combat_feedback_enabled() -> bool:
		if not is_inside_tree():
			return false
		return bool(get_tree().root.get_meta("combat_feedback", true))

	func _show_hit_flash() -> void:
		flashes += 1
		var tick := Sprite2D.new()
		tick.name = "CombatHitTick"
		tick.texture = HIT_FLASH_TEXTURE
		var tick_material := CanvasItemMaterial.new()
		tick_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		tick.material = tick_material
		tick.modulate = Color(1.0, 0.46, 0.36, 0.40)
		tick.scale = Vector2.ONE * (maxf(reach * 0.95, 48.0) / 128.0)
		tick.z_index = 2999
		add_child(tick)


class CaptureActivation extends RefCounted:
	var cast_origin := Vector2.ZERO

	func origin() -> Vector2:
		return cast_origin

	func is_finished() -> bool:
		return false

	func param_float(_key: String, fallback: float) -> float:
		return fallback

	func scaled_damage(_key: String, fallback: float) -> float:
		return maxf(fallback, 12.0)

	func apply_control(_target: Node, _impulse: Vector2, _status_id: String, _status: Dictionary) -> Dictionary:
		return {"status_applied": true}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("%s Sniper certification capture skipped (headless); run windowed for PNG evidence." % ISSUE)
		quit(0)
		return
	_class_manifest = _read_json(CLASS_MANIFEST_PATH)
	if _class_manifest.is_empty():
		push_error("%s cannot read the Sniper class manifest" % ISSUE)
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT)) != OK:
		push_error("%s cannot create %s" % [ISSUE, OUTPUT_ROOT])
		quit(1)
		return
	for weapon_id in WEAPON_IDS:
		_flash_by_weapon[weapon_id] = _flash_series(weapon_id)
	for viewport_id in VIEWPORT_IDS:
		for mode_id in MODE_IDS:
			var frames := await _render_mode_frames(mode_id, VIEWPORT_SIZES[viewport_id] as Vector2i, viewport_id)
			if frames.is_empty():
				_finish()
				return
			await _compose_sheet(mode_id, viewport_id, VIEWPORT_SIZES[viewport_id] as Vector2i, frames)
	_write_manifest()
	_finish()


func _render_mode_frames(mode_id: String, size: Vector2i, viewport_id: String) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for weapon_id in WEAPON_IDS:
		for beat_id in BEAT_IDS:
			var frame := await _render_native_frame(weapon_id, mode_id, beat_id, viewport_id, size)
			if frame.is_empty():
				_errors.append("native frame failed: %s/%s/%s/%s" % [weapon_id, mode_id, beat_id, viewport_id])
				return []
			frames.append(frame)
	return frames


## One native-resolution frame: the shipped presentation scene advanced to a
## declared beat, with the shipped weapon effect and victim-impact burst live on
## real hazard nodes. The HUD is a CanvasLayer so the world can be measured
## without it and the delivered frame can still show it.
func _render_native_frame(weapon_id: String, mode_id: String, beat_id: String, viewport_id: String, size: Vector2i) -> Dictionary:
	var mode := MODE_SPECS[mode_id] as Dictionary
	var weapon := _weapon_declaration(weapon_id)
	var beat_seconds := float((weapon.get("timing_seconds", {}) as Dictionary).get(beat_id, 0.0))
	var hazard_count := int(mode.get("hazards", 3))
	if hazard_count < 0:
		hazard_count = int((weapon.get("performance", {}) as Dictionary).get("crowd_cap", 24))
	seed(_panel_seed(weapon_id, mode_id, beat_id, viewport_id))
	root.set_meta("screen_shake", bool(mode.get("screen_shake", true)))
	root.set_meta("combat_feedback", bool(mode.get("combat_feedback", true)))

	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world := Node2D.new()
	viewport.add_child(world)
	_add_color_rect(world, Rect2(Vector2.ZERO, Vector2(size)), ARENA_COLOR, -100)
	var camera := Camera2D.new()
	camera.position = Vector2(size) * 0.5
	world.add_child(camera)

	var cast_origin := Vector2(size) * 0.5
	var player_rect := _player_rect(size)
	_add_color_rect(world, player_rect, PLAYER_COLOR, -5)
	var hazard_rects := _hazard_rects(size, hazard_count)
	var hazards: Array[Node2D] = []
	for hazard_rect in hazard_rects:
		var hazard := HazardProbe.new()
		hazard.position = hazard_rect.get_center()
		hazard.reach = maxf(hazard_rect.size.x, hazard_rect.size.y)
		world.add_child(hazard)
		_add_color_rect(hazard, Rect2(-hazard_rect.size * 0.5, hazard_rect.size), HAZARD_COLOR, -5)
		hazards.append(hazard)

	var ultimate := (load(str(ULTIMATE_SCENES[weapon_id])) as PackedScene).instantiate() as Node2D
	ultimate.position = cast_origin
	world.add_child(ultimate)
	var hud := _build_hud(viewport, size, weapon_id, mode_id, beat_id, hazards.size())
	await process_frame

	var begun := ultimate.call("begin", {}, 0) as Dictionary
	if str(begun.get("state", "")) != "active":
		_errors.append("%s presentation scene did not start" % weapon_id)
		viewport.queue_free()
		await process_frame
		return {}
	ultimate.call("advance", beat_seconds + 0.01)
	var effect := _drive_effect(world, weapon_id, cast_origin, hazards)
	var backdrop := ultimate.get_node_or_null("BackdropTreatment") as CanvasItem

	## Two reads of one frame: the world alone is what the HUD-band and marker
	## numbers are measured on, the framed one is what ships in the sheet. The
	## tree is paused in between so the live shake tween cannot move the frame
	## between the measurement and the delivered pixels.
	hud.visible = false
	await _settle()
	var view_offset := camera.offset
	var world_image := viewport.get_texture().get_image()
	paused = true
	hud.visible = true
	await _settle()
	var framed_image := viewport.get_texture().get_image()
	paused = false

	var record := _measure(world_image, size, player_rect, hazard_rects, view_offset)
	record["weapon_id"] = weapon_id
	record["mode"] = mode_id
	record["beat"] = beat_id
	record["viewport"] = viewport_id
	record["beat_seconds"] = beat_seconds
	record["hazard_count"] = hazards.size()
	record["visible_phase"] = str(ultimate.call("visible_phase_name"))
	record["screen_shake_setting"] = bool(mode.get("screen_shake", true))
	record["combat_feedback_setting"] = bool(mode.get("combat_feedback", true))
	record["camera_shake_applied"] = ultimate.get("_camera") != null
	record["camera_offset_px"] = [snappedf(view_offset.x, 0.001), snappedf(view_offset.y, 0.001)]
	record["backdrop_alpha"] = snappedf(backdrop.modulate.a, 0.0001) if backdrop != null else 0.0
	record["backdrop_treatment"] = str((weapon.get("presence", {}) as Dictionary).get("backdrop", ""))
	var presence := ultimate.call("presence_state_for_tests") as Dictionary
	record["hitstop_ms"] = float(presence.get("hitstop_ms", 0.0))
	record["cast_pose_bound"] = bool(presence.get("cast_pose_bound", false))
	record["silhouette_bound"] = bool(presence.get("silhouette_bound", false))
	record["victim_impacts"] = _impact_snapshot(effect)
	_records.append(record)

	ultimate.call("finish", "capture")
	viewport.queue_free()
	await process_frame
	return {"image": framed_image, "record": record}


## The weapon effect scenes are the shipped ones; each takes the class-local
## configure/trigger pair the runtime uses, so the impact flipbook that lands on
## the hazards is production behaviour, not a stand-in.
func _drive_effect(world: Node2D, weapon_id: String, cast_origin: Vector2, hazards: Array[Node2D]) -> Node2D:
	var effect := (load(str(EFFECT_SCENES[weapon_id])) as PackedScene).instantiate() as Node2D
	world.add_child(effect)
	effect.set("ultimate_damage_sink", Callable(self, "_damage_sink"))
	var activation := CaptureActivation.new()
	activation.cast_origin = cast_origin
	match weapon_id:
		"sniper_deadeye_rifle":
			effect.call("configure", activation, hazards, hazards[0])
			effect.call("fire")
		"sniper_spotter_scope":
			effect.call("configure", activation, cast_origin, hazards)
			effect.call("strike", 0)
		"sniper_shatter_rounds":
			effect.call("configure", activation, hazards)
			effect.call("impact", 0)
	for child in effect.get_children():
		if child.get_script() == ImpactPlayer:
			(child as Node).call("advance", 0.12)
	return effect


func _impact_snapshot(effect: Node2D) -> Dictionary:
	for child in effect.get_children():
		if child.get_script() == ImpactPlayer:
			var snapshot := (child as Node).call("snapshot") as Dictionary
			return {
				"victims": int(snapshot.get("victims", 0)),
				"flashes": int(snapshot.get("flashes", 0)),
				"peak_active": int(snapshot.get("peak_active", 0)),
				"degraded": bool(snapshot.get("degraded", false)),
			}
	return {"victims": 0, "flashes": 0, "peak_active": 0, "degraded": false}


## Measurements are taken on the HUD-free world render: the HUD band numbers
## would be meaningless if the band we are asking about were drawn on top.
##
## `non_arena_coverage_ratio` counts every pixel the presentation touched,
## including the deliberately translucent backdrop treatment, so it saturates
## for the two flash-backdrop weapons. `opaque_coverage_ratio` is the one that
## compares against the declared `max_viewport_coverage_ratio`, because that cap
## is about the effect body, not its tint.
## `view_offset` is the live camera-shake displacement: without it every probe
## would sample the resting position of a frame the shipped shake has moved, and
## report a readable marker as lost.
func _measure(image: Image, size: Vector2i, player_rect: Rect2, hazard_rects: Array[Rect2], view_offset: Vector2) -> Dictionary:
	var player_view := Rect2(player_rect.position - view_offset, player_rect.size)
	var hazard_views: Array[Rect2] = []
	for hazard_rect in hazard_rects:
		hazard_views.append(Rect2(hazard_rect.position - view_offset, hazard_rect.size))
	var bands := _hud_bands(size)
	var band_pixels := 0
	var band_opaque := 0
	var arena_pixels := 0
	var touched_pixels := 0
	var opaque_pixels := 0
	var step := maxi(1, size.y / 216)
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var point := Vector2(float(x), float(y))
			var pixel := image.get_pixel(x, y)
			var delta := _channel_delta(pixel, ARENA_COLOR)
			if bands[0].has_point(point) or bands[1].has_point(point):
				band_pixels += 1
				if delta > OPAQUE_DELTA:
					band_opaque += 1
				continue
			if _in_fixture(point, player_view, hazard_views):
				continue
			arena_pixels += 1
			if delta > EFFECT_PRESENCE_DELTA:
				touched_pixels += 1
			if delta > OPAQUE_DELTA:
				opaque_pixels += 1
	var player_pixel := image.get_pixelv(_clamped(player_view.get_center(), size))
	var player_contrast := absf(_luminance(player_pixel) - _local_background(image, size, player_view))
	var hazard_hue := 0
	var hazard_contrast := 0
	var hazard_min_contrast := 1.0
	for hazard_view in hazard_views:
		var hazard_pixel := image.get_pixelv(_clamped(hazard_view.get_center(), size))
		if _hazard_hue_preserved(hazard_pixel):
			hazard_hue += 1
		var contrast := absf(_luminance(hazard_pixel) - _local_background(image, size, hazard_view))
		hazard_min_contrast = minf(hazard_min_contrast, contrast)
		if contrast >= CONTRAST_MIN:
			hazard_contrast += 1
	return {
		"player_readable": player_contrast >= CONTRAST_MIN,
		"player_hue_preserved": player_pixel.b >= player_pixel.r and player_pixel.b >= player_pixel.g,
		"player_contrast": snappedf(player_contrast, 0.001),
		"player_pixel": _pixel_values(player_pixel),
		"hazards_readable": hazard_contrast,
		"hazards_hue_preserved": hazard_hue,
		"hazard_min_contrast": snappedf(hazard_min_contrast, 0.001),
		"hud_band_opaque_ratio": snappedf(float(band_opaque) / maxf(1.0, float(band_pixels)), 0.0001),
		"non_arena_coverage_ratio": snappedf(float(touched_pixels) / maxf(1.0, float(arena_pixels)), 0.0001),
		"opaque_coverage_ratio": snappedf(float(opaque_pixels) / maxf(1.0, float(arena_pixels)), 0.0001),
		"sampled_pixels": band_pixels + arena_pixels,
	}


func _compose_sheet(mode_id: String, viewport_id: String, size: Vector2i, frames: Array[Dictionary]) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.size = Vector2(size)
	viewport.add_child(host)
	_add_panel(host, Rect2(Vector2.ZERO, Vector2(size)), SHEET_COLOR)
	var cell := Vector2(float(size.x) / float(BEAT_IDS.size()), float(size.y) / float(WEAPON_IDS.size()))
	for index in frames.size():
		var frame := frames[index] as Dictionary
		var record := frame.get("record", {}) as Dictionary
		var cell_origin := Vector2(
			float(BEAT_IDS.find(str(record.get("beat", "")))) * cell.x,
			float(WEAPON_IDS.find(str(record.get("weapon_id", "")))) * cell.y)
		var thumbnail := (frame.get("image") as Image).duplicate() as Image
		thumbnail.resize(int(cell.x), int(cell.y), Image.INTERPOLATE_LANCZOS)
		var texture := TextureRect.new()
		texture.texture = ImageTexture.create_from_image(thumbnail)
		texture.position = cell_origin
		texture.size = cell
		host.add_child(texture)
		_add_caption(host, cell_origin, cell, size, record)
	_add_sheet_heading(host, size, mode_id, viewport_id)
	await _settle()
	var output := "%s/sniper_certification_%s_%s.png" % [OUTPUT_ROOT, mode_id, viewport_id]
	var absolute := ProjectSettings.globalize_path(output)
	var result := viewport.get_texture().get_image().save_png(absolute)
	viewport.queue_free()
	await process_frame
	if result != OK:
		_errors.append("cannot save %s: %s" % [output, error_string(result)])
		return
	_sheets.append({
		"mode": mode_id,
		"viewport": viewport_id,
		"width": size.x,
		"height": size.y,
		"path": output,
		"sha256": FileAccess.get_sha256(output).to_lower(),
	})
	print("%s sheet saved: %s" % [ISSUE, output])


func _add_sheet_heading(host: Control, size: Vector2i, mode_id: String, viewport_id: String) -> void:
	var mode := MODE_SPECS[mode_id] as Dictionary
	var heading := "SNIPER ULTIMATE CERTIFICATION — %s — %dx%d (%s) — rows: weapons, columns: release / active / recovery" % [
		str(mode.get("label", mode_id)), size.x, size.y, viewport_id]
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0, 0.30)
	strip.position = Vector2.ZERO
	strip.size = Vector2(float(size.x), float(size.y) * 0.034)
	host.add_child(strip)
	_add_label(host, heading, Vector2(float(size.x) * 0.006, float(size.y) * 0.004), maxi(11, roundi(float(size.y) * 0.022)), CAPTION_COLOR)


func _add_caption(host: Control, origin: Vector2, cell: Vector2, size: Vector2i, record: Dictionary) -> void:
	var strip := ColorRect.new()
	strip.color = Color(0.0, 0.0, 0.0, 0.58)
	strip.position = origin + Vector2(0.0, cell.y - float(size.y) * 0.052)
	strip.size = Vector2(cell.x, float(size.y) * 0.052)
	host.add_child(strip)
	var font_size := maxi(9, roundi(float(size.y) * 0.017))
	_add_label(host, "%s · %s" % [str(record.get("weapon_id", "")), str(record.get("beat", "")).to_upper()],
		strip.position + Vector2(cell.x * 0.012, 0.0), font_size, CAPTION_COLOR)
	var detail := "t=%.2fs haz %d/%d opq %.3f hud %.3f %s" % [
		float(record.get("beat_seconds", 0.0)),
		int(record.get("hazards_readable", 0)),
		int(record.get("hazard_count", 0)),
		float(record.get("opaque_coverage_ratio", 0.0)),
		float(record.get("hud_band_opaque_ratio", 0.0)),
		_mode_readout(record),
	]
	_add_label(host, detail, strip.position + Vector2(cell.x * 0.012, float(font_size) * 1.15),
		maxi(8, roundi(float(size.y) * 0.014)), Color(0.74, 0.84, 0.96))
	_add_outline(host, Rect2(origin, cell), Color(0.26, 0.33, 0.44))


## What the mode actually changed in this frame, measured rather than asserted.
func _mode_readout(record: Dictionary) -> String:
	var offset := record.get("camera_offset_px", [0.0, 0.0]) as Array
	if str(record.get("mode", "")) == "photosensitivity_safe":
		var flash := _flash_by_weapon.get(str(record.get("weapon_id", "")), {}) as Dictionary
		return "veil %.2fHz/%.2f no shake no flash" % [
			float(flash.get("flash_hz", 0.0)), float(flash.get("peak_veil_alpha", 0.0))]
	if not bool(record.get("camera_shake_applied", false)):
		return "shake off offset 0.0,0.0"
	return "shake on offset %.1f,%.1f" % [float(offset[0]), float(offset[1])]


func _build_hud(viewport: SubViewport, size: Vector2i, weapon_id: String, mode_id: String, beat_id: String, hazards: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var host := Control.new()
	host.size = Vector2(size)
	layer.add_child(host)
	var bands := _hud_bands(size)
	for band in bands:
		_add_panel(host, band, HUD_COLOR)
	var font_size := maxi(10, roundi(float(size.y) * 0.020))
	_add_label(host, "HP 100/100   ULT ACTIVE   WAVE 7   HAZARDS %d" % hazards,
		bands[0].position + Vector2(float(size.x) * 0.012, bands[0].size.y * 0.22), font_size, Color(0.80, 0.90, 1.0))
	_add_label(host, "%s · %s · %s beat" % [weapon_id, str((MODE_SPECS[mode_id] as Dictionary).get("label", mode_id)), beat_id],
		bands[1].position + Vector2(float(size.x) * 0.012, bands[1].size.y * 0.22), font_size, Color(0.78, 0.86, 0.98))
	return layer


func _write_manifest() -> void:
	var modes: Array[Dictionary] = []
	for mode_id in MODE_IDS:
		var mode := MODE_SPECS[mode_id] as Dictionary
		modes.append({
			"id": mode_id,
			"screen_shake_setting": bool(mode.get("screen_shake", true)),
			"combat_feedback_setting": bool(mode.get("combat_feedback", true)),
			"hazard_population": "declared crowd_cap" if int(mode.get("hazards", 3)) < 0 else int(mode.get("hazards", 3)),
			"description": _mode_description(mode_id),
		})
	var manifest := {
		"schema_version": 1,
		"issue": ISSUE,
		"class_id": CLASS_ID,
		"capture_script": CAPTURE_SCRIPT_PATH,
		"focused_test": CAPTURE_TEST_PATH,
		"readability_report": READABILITY_REPORT_PATH,
		"capture_source": {
			"ref": CAPTURE_SOURCE_REF,
			"sha": CAPTURE_SOURCE_SHA,
			"tree": CAPTURE_SOURCE_TREE,
			"note": "Integrated source the captures were rendered from; never the commit that records them.",
		},
		"renderer": {
			"engine": "Godot %s" % str(Engine.get_version_info().get("string", "")),
			"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			"display_driver": DisplayServer.get_name(),
			"video_adapter": RenderingServer.get_video_adapter_name(),
			"capture_method": "SubViewport native render, read back with get_texture().get_image()",
			"seed": CAPTURE_SEED,
			"seed_formula": "seed(CAPTURE_SEED + weapon_index*1000 + mode_index*100 + beat_index*10 + viewport_index)",
			"determinism": "Run with --fixed-fps 60 so the shipped camera-shake tween is sampled at a fixed delta.",
		},
		"canonical_weapon_ids": WEAPON_IDS,
		"presentation_modes": modes,
		"beats": BEAT_IDS,
		"viewports": _viewport_records(),
		"scene_configuration": _scene_configuration(),
		"flash_series": _flash_by_weapon,
		"measurements": {
			"hud_review_bands": "top and bottom %.2f of the frame height; a review convention shared with the Engineer capture spec, not shipped HUD geometry" % HUD_BAND_HEIGHT_RATIO,
			"hud_band_opaque_ratio": "share of review-band pixels an opaque body reaches (channel delta > %.2f from the arena fill)" % OPAQUE_DELTA,
			"non_arena_coverage_ratio": "share of arena pixels the presentation touched at all, translucent backdrop treatment included",
			"opaque_coverage_ratio": "share of arena pixels covered by an opaque body; this is the number to read against the declared max_viewport_coverage_ratio",
			"player_readable / hazards_readable": "marker luminance differs from its own surroundings by at least %.2f" % CONTRAST_MIN,
			"hue_preserved": "the marker still reads in its own colour rather than only as contrast",
		},
		"sheets": _sheets,
		"observations": _records,
		"coverage": {
			"weapons": WEAPON_IDS.size(),
			"modes": MODE_IDS.size(),
			"viewports": VIEWPORT_IDS.size(),
			"beats": BEAT_IDS.size(),
			"sheets": _sheets.size(),
			"native_frames": _records.size(),
		},
		"commands": {
			"capture": "FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --fixed-fps 60 --script res://%s" % CAPTURE_SCRIPT_PATH,
			"gate": "python3 tools/godot_gate.py --headless --path . --script res://%s" % CAPTURE_TEST_PATH,
			"class_timelines": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/sniper_ultimate_timelines.gd",
			"lfs_integrity": "git lfs fsck",
		},
		"scope_boundary": "Reproducible capture evidence only. Sniper production scenes, VFX, gameplay, balance and adoption data are unchanged.",
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write %s" % MANIFEST_PATH)
		return
	file.store_string("%s\n" % JSON.stringify(manifest, "  ", false))
	file.close()
	print("%s capture manifest written: %s" % [ISSUE, MANIFEST_PATH])


func _viewport_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for viewport_id in VIEWPORT_IDS:
		var size := VIEWPORT_SIZES[viewport_id] as Vector2i
		records.append({"id": viewport_id, "width": size.x, "height": size.y})
	return records


func _scene_configuration() -> Dictionary:
	var weapons: Array[Dictionary] = []
	for weapon_id in WEAPON_IDS:
		var weapon := _weapon_declaration(weapon_id)
		weapons.append({
			"weapon_id": weapon_id,
			"presentation_scene": str(ULTIMATE_SCENES[weapon_id]).trim_prefix("res://"),
			"effect_scene": str(EFFECT_SCENES[weapon_id]).trim_prefix("res://"),
			"timeline": str(weapon.get("timeline_path", "")),
			"crowd_cap": int((weapon.get("performance", {}) as Dictionary).get("crowd_cap", 0)),
			"beat_seconds": {
				"release": float((weapon.get("timing_seconds", {}) as Dictionary).get("release", 0.0)),
				"active": float((weapon.get("timing_seconds", {}) as Dictionary).get("active", 0.0)),
				"recovery": float((weapon.get("timing_seconds", {}) as Dictionary).get("recovery", 0.0)),
			},
		})
	return {
		"frame": "native viewport render, presentation scene at scale 1.0 centred on the player cast origin",
		"fixtures": "arena fill, player marker, hazard markers driven as live victims, HUD bands on a CanvasLayer",
		"victim_impact_service": "scripts/ultimates/presentation/victim_impact_player.gd",
		"sheet_layout": "3 rows (canonical weapons) x 3 columns (release, active, recovery); each cell is the native frame downscaled by 1/3",
		"weapons": weapons,
	}


func _mode_description(mode_id: String) -> String:
	match mode_id:
		"normal":
			return "Shipped presentation with the screen_shake accessibility toggle on and three live hazards."
		"crowded":
			return "Same beats with the weapon's declared crowd cap of live hazards, so the shipped victim-impact pool runs at capacity."
		"reduced_motion":
			return "Shipped reduced-motion path: the screen_shake toggle is off, so SniperUltimatePresentationScene never binds a camera and the frame stays centred."
		"photosensitivity_safe":
			return "Both shipped switches off: no camera shake and no per-victim hit flash, because the shipped impact player asks every victim for combat_feedback before flashing it. The recorded veil series shows the remaining backdrop is one monotone step per phase, not a repeating full-screen flash."
	return ""


func _weapon_declaration(weapon_id: String) -> Dictionary:
	for raw_weapon in _class_manifest.get("weapons", []) as Array:
		if raw_weapon is Dictionary and str((raw_weapon as Dictionary).get("weapon_id", "")) == weapon_id:
			return raw_weapon as Dictionary
	return {}


func _player_rect(size: Vector2i) -> Rect2:
	var extent := float(size.y) * PLAYER_SIZE_RATIO
	var center := Vector2(float(size.x) * PLAYER_CENTER_RATIO.x, float(size.y) * PLAYER_CENTER_RATIO.y)
	return Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)


func _hazard_rects(size: Vector2i, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var extent := float(size.y) * HAZARD_SIZE_RATIO
	var center := Vector2(size) * 0.5
	var radius := Vector2(float(size.x) * HAZARD_RADIUS_RATIO.x, float(size.y) * HAZARD_RADIUS_RATIO.y)
	var per_ring := count if count <= 12 else int(ceil(float(count) / 2.0))
	for index in count:
		var ring := index / per_ring
		var slot := index % per_ring
		var angle := TAU * (float(slot) + 0.5 * float(ring)) / float(per_ring)
		var ring_radius := radius * (1.0 if ring == 0 else HAZARD_INNER_SCALE)
		var point := center + Vector2(cos(angle) * ring_radius.x, sin(angle) * ring_radius.y)
		rects.append(Rect2(point - Vector2.ONE * extent * 0.5, Vector2.ONE * extent))
	return rects


func _in_fixture(point: Vector2, player_rect: Rect2, hazard_rects: Array[Rect2]) -> bool:
	if player_rect.grow(2.0).has_point(point):
		return true
	for hazard_rect in hazard_rects:
		if hazard_rect.grow(2.0).has_point(point):
			return true
	return false


func _hud_bands(size: Vector2i) -> Array[Rect2]:
	return [
		Rect2(Vector2.ZERO, Vector2(float(size.x), float(size.y) * HUD_BAND_HEIGHT_RATIO)),
		Rect2(
			Vector2(0.0, float(size.y) * HUD_BOTTOM_TOP_RATIO),
			Vector2(float(size.x), float(size.y) * (1.0 - HUD_BOTTOM_TOP_RATIO))),
	] as Array[Rect2]


func _luminance(pixel: Color) -> float:
	return 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b


## What a marker actually has to stand out from, sampled on a ring just outside
## it. Comparing against the flat arena colour instead would read the shipped
## backdrop tint as if the marker itself had gone dark.
func _local_background(image: Image, size: Vector2i, rect: Rect2) -> float:
	var radius := maxf(rect.size.x, rect.size.y) * LOCAL_BACKGROUND_SCALE
	var total := 0.0
	for index in LOCAL_BACKGROUND_SAMPLES:
		var angle := TAU * float(index) / float(LOCAL_BACKGROUND_SAMPLES)
		var point := rect.get_center() + Vector2(cos(angle), sin(angle)) * radius
		total += _luminance(image.get_pixelv(_clamped(point, size)))
	return total / float(LOCAL_BACKGROUND_SAMPLES)


func _hazard_hue_preserved(pixel: Color) -> bool:
	return pixel.r >= pixel.g + HAZARD_DOMINANCE_MARGIN and pixel.r >= pixel.b + HAZARD_DOMINANCE_MARGIN


## Photosensitivity evidence a still frame cannot carry: the full-screen veil
## alpha the shipped scene drives across the whole cast, sampled in fixed steps
## so the rising-edge rate can be compared with the declared flash ceiling.
func _flash_series(weapon_id: String) -> Dictionary:
	var scene := (load(str(ULTIMATE_SCENES[weapon_id])) as PackedScene).instantiate() as Node2D
	root.add_child(scene)
	scene.call("begin", {}, 0)
	var weapon := _weapon_declaration(weapon_id)
	var cancel := float((weapon.get("timing_seconds", {}) as Dictionary).get("cancel", 3.0))
	var samples: Array[float] = []
	var elapsed := 0.0
	while elapsed <= cancel:
		var backdrop := scene.get_node_or_null("BackdropTreatment") as CanvasItem
		samples.append(snappedf(backdrop.modulate.a if backdrop != null else 0.0, 0.0001))
		scene.call("advance", FLASH_STEP_SECONDS)
		elapsed += FLASH_STEP_SECONDS
	scene.call("finish", "capture")
	scene.queue_free()
	var rises := 0
	var peak := 0.0
	for index in samples.size():
		peak = maxf(peak, samples[index])
		if index > 0 and samples[index] > samples[index - 1] + 0.001:
			rises += 1
	return {
		"step_seconds": FLASH_STEP_SECONDS,
		"duration_seconds": snappedf(elapsed, 0.001),
		"peak_veil_alpha": snappedf(peak, 0.0001),
		"rising_transitions": rises,
		"flash_hz": snappedf(float(rises) / maxf(elapsed, 0.001), 0.001),
		"alpha_samples": samples,
	}


func _channel_delta(pixel: Color, reference: Color) -> float:
	return maxf(absf(pixel.r - reference.r), maxf(absf(pixel.g - reference.g), absf(pixel.b - reference.b)))


func _pixel_values(pixel: Color) -> Array:
	return [snappedf(pixel.r, 0.001), snappedf(pixel.g, 0.001), snappedf(pixel.b, 0.001)]


func _clamped(point: Vector2, size: Vector2i) -> Vector2i:
	return Vector2i(clampi(int(point.x), 0, size.x - 1), clampi(int(point.y), 0, size.y - 1))


func _panel_seed(weapon_id: String, mode_id: String, beat_id: String, viewport_id: String) -> int:
	return CAPTURE_SEED \
		+ WEAPON_IDS.find(weapon_id) * 1000 \
		+ MODE_IDS.find(mode_id) * 100 \
		+ BEAT_IDS.find(beat_id) * 10 \
		+ VIEWPORT_IDS.find(viewport_id)


func _settle() -> void:
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _add_color_rect(host: Node, rect: Rect2, color: Color, z_index: int) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.position = rect.position
	node.size = rect.size
	node.z_index = z_index
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(node)
	return node


func _add_panel(host: Control, rect: Rect2, color: Color) -> void:
	var node := ColorRect.new()
	node.color = color
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(node)


func _add_outline(host: Control, rect: Rect2, color: Color) -> void:
	var node := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(1)
	node.add_theme_stylebox_override("panel", style)
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(node)


func _add_label(host: Control, text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	host.add_child(label)


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _damage_sink(_target: Node, amount: float, _feedback: Dictionary, _event_id: String, _secondary: bool) -> Dictionary:
	return {"applied": amount, "killed": false}


func _finish() -> void:
	if _errors.is_empty():
		print("%s Sniper certification capture: %d sheets, %d native frames." % [ISSUE, _sheets.size(), _records.size()])
		quit(0)
		return
	for error in _errors:
		push_error("%s Sniper certification capture: %s" % [ISSUE, error])
	quit(1)
