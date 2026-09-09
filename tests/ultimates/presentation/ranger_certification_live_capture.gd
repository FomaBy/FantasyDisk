extends SceneTree

## FAN-3941 — windowed certification capture for the Ranger ultimate trio.
##
## One native-size frame per canonical weapon x presentation mode x supported
## viewport at the active beat, plus the release and recovery beats at the
## 1152x648 judging viewport: 72 frames. Each frame is a real render of the
## shipped scene driven through `begin()`/`step()` exactly as the runtime
## drives it, at the on-screen scale the game uses (2560x1440 logical canvas,
## canvas_items stretch, combat camera zoom), composed with the hero sprite at
## the Player's combat scale, a crowd at the declared crowd cap, striped
## hazards, the real ultimate HUD widget fed a registry snapshot, and a state
## caption naming the exact configuration. The crowded variant also plays the
## weapon's own victim-impact flipbook on the crowd.
##
## Alongside each frame the script measures the effect's opaque coverage on a
## scene-only transparent render, sweeps the whole cast envelope at 648p for
## the peak coverage behind `quality.max_viewport_coverage_ratio`, records the
## readability probes the gate recomputes, and writes the capture manifest
## with source, engine, command, hash and configuration provenance.
##
## Run windowed through the process guard (a headless display has no render
## target and is reported as skipped, never as evidence):
##   FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . \
##     --script res://tests/ultimates/presentation/ranger_certification_live_capture.gd

const SPEC := preload("res://tests/ultimates/presentation/ranger_certification_capture_test.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Pack := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_presentation_pack.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const HudWidgetScene := preload("res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn")
const HudFixtures := preload("res://tests/ultimates/hud_fixture_library.gd")
const HudViewModel := preload("res://scripts/ui/ultimate_hud/ultimate_hud_view_model.gd")

const IMPACT_ADVANCE_SECONDS := 0.12

var _registry = null
var _hud_fixtures = null
var _errors: Array[String] = []


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3941 Ranger certification capture skipped (headless); run windowed for evidence.")
		quit(0)
		return
	seed(SPEC.CAPTURE_SEED)
	_registry = Registry.new(PD.WEAPONS_BY_CLASS)
	if not _registry.is_valid():
		push_error("Ranger certification capture: weapon registry is invalid")
		quit(1)
		return
	_hud_fixtures = HudFixtures.new()
	var directory := ProjectSettings.globalize_path("res://" + SPEC.CAPTURE_ROOT)
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK:
		push_error("Ranger certification capture: cannot create %s (%s)" % [directory, error_string(made)])
		quit(1)
		return

	var captures: Array[Dictionary] = []
	for entry in SPEC.expected_entries():
		var record := await _capture(entry)
		if record.is_empty():
			_fail()
			return
		captures.append(record)
		print("Ranger certification capture saved: %s (%dx%d, coverage %.4f)" % [
			str(record["path"]), int(record["width"]), int(record["height"]),
			float((record["measured"] as Dictionary)["opaque_coverage_ratio"]),
		])

	var weapons: Array[Dictionary] = []
	for weapon_id in SPEC.weapon_ids():
		var sweep := await _envelope_sweep(weapon_id)
		if sweep.is_empty():
			_fail()
			return
		var peak := float(sweep["peak_opaque_coverage_ratio"])
		for record in captures:
			if str(record["weapon_id"]) == weapon_id:
				peak = maxf(peak, float((record["measured"] as Dictionary)["opaque_coverage_ratio"]))
		weapons.append({
			"weapon_id": weapon_id,
			"key": SPEC.key_for(weapon_id),
			"scene_path": str(SPEC.weapon_spec(weapon_id)["scene_path"]),
			"crowd_cap": SPEC.crowd_cap(weapon_id),
			"timing_seconds": Pack.weapon_config(weapon_id).get("timing", {}),
			"beats_seconds": _beats(weapon_id),
			"backdrop": SPEC.backdrop_report(weapon_id),
			"envelope_sweep": sweep,
			"max_opaque_coverage_ratio": snappedf(peak, 0.0001),
		})
		print("Ranger envelope sweep %s: peak coverage %.4f at %.2fs over %d samples" % [
			weapon_id, float(sweep["peak_opaque_coverage_ratio"]), float(sweep["peak_at_seconds"]), int(sweep["samples"]),
		])

	SPEC.reset_mode(self)
	var manifest := _manifest(captures, weapons)
	var file := FileAccess.open(SPEC.MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Ranger certification capture: cannot write %s" % SPEC.MANIFEST_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	print("Ranger certification capture manifest written: %s (%d frames)" % [SPEC.MANIFEST_PATH, captures.size()])
	quit(0)


func _fail() -> void:
	for error in _errors:
		push_error("Ranger certification capture: %s" % error)
	SPEC.reset_mode(self)
	quit(1)


func _beats(weapon_id: String) -> Dictionary:
	var beats := {}
	for beat_id in SPEC.BEAT_IDS:
		beats[beat_id] = SPEC.beat_seconds(weapon_id, beat_id)
	return beats


# --- one frame ----------------------------------------------------------------


## Renders the composite frame and the scene-only coverage render in the same
## draw, saves the PNG, and returns the manifest record for it.
func _capture(entry: Dictionary) -> Dictionary:
	var weapon_id := str(entry["weapon_id"])
	var mode := SPEC.mode_spec(str(entry["mode"]))
	var size := SPEC.viewport_size(str(entry["viewport"]))
	var seconds := SPEC.beat_seconds(weapon_id, str(entry["beat"]))
	var crowd := SPEC.crowd_count(weapon_id, mode)

	var composite := _viewport(size, false)
	var host := Node2D.new()
	composite.add_child(host)
	host.add_child(_rect_node(Rect2(Vector2.ZERO, Vector2(size)), SPEC.FLOOR_COLOR))
	for hazard in SPEC.hazard_rects(size):
		host.add_child(_hazard_node(hazard))
	var crowd_nodes := _crowd_nodes(size, crowd)
	for node in crowd_nodes:
		host.add_child(node)
	host.add_child(_player_node(size))

	SPEC.apply_mode(self, mode)
	var scene := SPEC.instantiate_scene(weapon_id)
	host.add_child(scene)
	SPEC.seek_scene(scene, _registry, seconds)
	SPEC.apply_veil(scene, mode)
	SPEC.place_scene(scene, size)
	var bounds := SPEC.content_bounds(scene)
	var inside := bounds.has_area() and SPEC.effect_zone(size).grow(0.5).encloses(bounds)

	if not crowd_nodes.is_empty():
		_play_impacts(host, weapon_id, crowd_nodes, SPEC.effect_origin(size), size)

	host.add_child(_hud_node(size, weapon_id))
	host.add_child(_caption_node(size, entry, seconds, crowd, mode))

	var coverage_viewport := _viewport(size, true)
	var coverage_scene := SPEC.instantiate_scene(weapon_id)
	coverage_viewport.add_child(coverage_scene)
	SPEC.seek_scene(coverage_scene, _registry, seconds)
	SPEC.hide_veil(coverage_scene)
	SPEC.place_scene(coverage_scene, size)

	await process_frame
	await RenderingServer.frame_post_draw

	var image := _read(composite, SPEC.entry_id(entry))
	var coverage_image := _read(coverage_viewport, SPEC.entry_id(entry) + " coverage")
	composite.queue_free()
	coverage_viewport.queue_free()
	if image == null or coverage_image == null:
		return {}

	var path := SPEC.capture_path(entry)
	var absolute := ProjectSettings.globalize_path("res://" + path)
	var saved := image.save_png(absolute)
	if saved != OK:
		_errors.append("cannot save %s: %s" % [path, error_string(saved)])
		return {}
	var report := SPEC.readability_report(image, entry)
	var violations := SPEC.readability_violations(entry, report)
	if not violations.is_empty():
		_errors.append_array(violations)
		return {}
	var coverage := SPEC.opaque_coverage_ratio(coverage_image)
	return {
		"weapon_id": weapon_id,
		"key": SPEC.key_for(weapon_id),
		"mode": str(entry["mode"]),
		"viewport": str(entry["viewport"]),
		"beat": str(entry["beat"]),
		"beat_seconds": seconds,
		"phase": str(Pack.phase_at(weapon_id, seconds).get("name", "")),
		"width": size.x,
		"height": size.y,
		"path": path,
		"sha256": FileAccess.get_sha256("res://" + path).to_lower(),
		"bytes": FileAccess.open("res://" + path, FileAccess.READ).get_length(),
		"screen_shake": bool(mode.get("screen_shake", true)),
		"crowd": crowd,
		"victim_impacts": crowd,
		"on_screen_scale": snappedf(SPEC.on_screen_scale(size), 0.0001),
		"measured": {
			"opaque_coverage_ratio": snappedf(coverage, 0.0001),
			"effect_bounds": [snappedf(bounds.position.x, 0.1), snappedf(bounds.position.y, 0.1), snappedf(bounds.size.x, 0.1), snappedf(bounds.size.y, 0.1)],
			"effect_inside_zone": inside,
			"veil_alpha": snappedf(SPEC.veil_alpha(weapon_id, seconds, mode), 0.001),
		},
		"readability": report,
	}


## Peak opaque coverage over the whole cast at the judging viewport, sampled
## from a scene-only render every SWEEP_STEP_SECONDS with the scene stepped
## live between samples, so hitstop and every other weight device run as
## shipped.
func _envelope_sweep(weapon_id: String) -> Dictionary:
	var size := SPEC.viewport_size(SPEC.BEAT_VIEWPORT)
	var duration := Pack.timeline_seconds(weapon_id)
	SPEC.apply_mode(self, SPEC.mode_spec(SPEC.MODE_NORMAL))
	var viewport := _viewport(size, true)
	var scene := SPEC.instantiate_scene(weapon_id)
	viewport.add_child(scene)
	scene.begin(_registry, SPEC.capture_handles(), 0)
	scene.set_process(false)
	SPEC.hide_veil(scene)
	SPEC.place_scene(scene, size)
	var elapsed := 0.0
	var samples := 0
	var peak := 0.0
	var peak_at := 0.0
	while elapsed < duration and scene.is_active():
		SPEC.hide_veil(scene)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := _read(viewport, "%s sweep %.3fs" % [weapon_id, elapsed])
		if image == null:
			viewport.queue_free()
			return {}
		var coverage := SPEC.opaque_coverage_ratio(image)
		samples += 1
		if coverage > peak:
			peak = coverage
			peak_at = elapsed
		scene.step(SPEC.SWEEP_STEP_SECONDS)
		elapsed += SPEC.SWEEP_STEP_SECONDS
	viewport.queue_free()
	if samples == 0:
		_errors.append("%s envelope sweep produced no sample" % weapon_id)
		return {}
	return {
		"viewport": SPEC.BEAT_VIEWPORT,
		"mode": SPEC.MODE_NORMAL,
		"step_seconds": snappedf(SPEC.SWEEP_STEP_SECONDS, 0.0001),
		"samples": samples,
		"duration_seconds": duration,
		"peak_opaque_coverage_ratio": snappedf(peak, 0.0001),
		"peak_at_seconds": snappedf(peak_at, 0.01),
	}


# --- manifest -----------------------------------------------------------------


func _manifest(captures: Array[Dictionary], weapons: Array[Dictionary]) -> Dictionary:
	var keys: Array[String] = []
	for weapon_id in SPEC.weapon_ids():
		keys.append(SPEC.key_for(weapon_id))
	var viewports := {}
	for raw_viewport in SPEC.VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		viewports[str(viewport["id"])] = {"width": size.x, "height": size.y, "on_screen_scale": snappedf(SPEC.on_screen_scale(size), 0.0001), "ui_scale": snappedf(SPEC.ui_scale(size), 0.0001)}
	var modes: Array[Dictionary] = []
	for raw_mode in SPEC.MODES:
		var mode := raw_mode as Dictionary
		modes.append({
			"id": str(mode["id"]),
			"label": str(mode["label"]),
			"crowd": "declared crowd_cap per weapon" if bool(mode["crowd"]) else "none",
			"screen_shake": bool(mode["screen_shake"]),
			"backdrop_veil": bool(mode["veil"]),
			"victim_impacts": bool(mode["crowd"]),
		})
	var version := Engine.get_version_info()
	return {
		"schema_version": SPEC.SCHEMA_VERSION,
		"issue": SPEC.ISSUE,
		"class_id": SPEC.CLASS_ID,
		"canonical_keys": keys,
		"source": {
			"ref": SPEC.SOURCE_REF,
			"commit_sha": SPEC.SOURCE_COMMIT_SHA,
			"tree_sha": SPEC.SOURCE_TREE_SHA,
			"note": "Integrated origin/dev revision whose shipped Ranger scenes, pack and assets were rendered; the capture tooling, frames and this manifest are added by FAN-3941 on top of it and change no production scene.",
		},
		"engine": {
			"godot": str(version.get("string", "")),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"video_adapter": RenderingServer.get_video_adapter_name(),
			"os": "%s %s" % [OS.get_name(), OS.get_version()],
			"display_server": DisplayServer.get_name(),
			"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		},
		"capture": {
			"script": SPEC.CAPTURE_SCRIPT,
			"focused_test": SPEC.FOCUSED_TEST,
			"capture_command": SPEC.CAPTURE_COMMAND,
			"test_command": SPEC.TEST_COMMAND,
			"exclusive_gate": OS.get_environment("FSD_GODOT_EXCLUSIVE") == "1",
			"headless_skipped": false,
			"seed": SPEC.CAPTURE_SEED,
			"seed_note": "seed() is set for completeness; the capture path draws no random value (no camera exists for the shake device, the crowd is a fixed grid and the impact ripple is distance-ordered).",
			"method": "Each frame is a SubViewport at the exact viewport size: floor, two striped hazards, the hero full frame at the Player combat scale, a crowd grid at the declared crowd cap (crowded), the shipped scene instantiated and driven with begin()/step() in fixed 1/120 s steps to the beat and held, the weapon's victim-impact flipbook on the crowd (crowded), the real UltimateHudWidget fed a registry snapshot, and a caption band with mode/weapon swatches. The scene is placed at the game's on-screen scale (viewport_height / 1440 * combat camera zoom 1.12) and never fitted. Opaque coverage is measured on a scene-only transparent render of the same composition with the veil hidden (alpha >= 0.5, stride 2). The photosensitivity-safe variant hides the authored backdrop veil after the beat is drawn; reduced motion applies the shipped screen_shake toggle on the tree root.",
			"logical_canvas": "%dx%d" % [int(SPEC.LOGICAL_CANVAS.x), int(SPEC.LOGICAL_CANVAS.y)],
			"stretch_mode": "canvas_items",
			"combat_camera_zoom": SPEC.COMBAT_CAMERA_ZOOM,
			"player_visual_scale": SPEC.PLAYER_VISUAL_SCALE,
			"player_sprite": SPEC.PLAYER_SPRITE,
			"hud_widget": "res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn",
			"hud_state": "ultimate_hud_view_model.gd build() of tests/ultimates/hud_fixture_library.gd weapon_profile_snapshot(class, weapon) with charge fraction 1.0, active true and keyboard input",
			"seek_step_seconds": snappedf(SPEC.SEEK_STEP, 0.0001),
			"coverage_alpha_min": SPEC.COVERAGE_ALPHA_MIN,
			"coverage_stride": SPEC.COVERAGE_STRIDE,
		},
		"arena": {
			"hud_band_height_ratio": SPEC.HUD_BAND_HEIGHT_RATIO,
			"state_band_height_ratio": SPEC.STATE_BAND_HEIGHT_RATIO,
			"player_column_width_ratio": SPEC.PLAYER_COLUMN_WIDTH_RATIO,
			"hazard_column_width_ratio": SPEC.HAZARD_COLUMN_WIDTH_RATIO,
			"hazard_logical_size": SPEC.HAZARD_LOGICAL_SIZE,
			"crowd_logical_radius": SPEC.CROWD_LOGICAL_RADIUS,
		},
		"modes": SPEC.MODE_IDS,
		"mode_details": modes,
		"beats": SPEC.BEAT_IDS,
		"beat_rule": "midpoint of the declared phase window; the active beat is committed at every viewport, release and recovery at %s" % SPEC.BEAT_VIEWPORT,
		"viewports": viewports,
		"weapons": weapons,
		"coverage": {
			"combinations": SPEC.weapon_ids().size() * SPEC.MODE_IDS.size() * SPEC.VIEWPORT_IDS.size(),
			"expected_frames": SPEC.expected_entries().size(),
			"written_frames": captures.size(),
		},
		"captures": captures,
	}


# --- arena fixtures -----------------------------------------------------------


func _viewport(size: Vector2i, transparent: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _read(viewport: SubViewport, label: String) -> Image:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_errors.append("empty render for %s" % label)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _rect_node(rect: Rect2, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	return polygon


## A hazard reads as a striped warning block, the language the arena uses for
## a telegraphed danger the player must still see through an ultimate.
func _hazard_node(rect: Rect2) -> Node2D:
	var host := Node2D.new()
	host.add_child(_rect_node(rect, SPEC.HAZARD_BASE_COLOR))
	for stripe in SPEC.hazard_stripe_rects(rect):
		host.add_child(_rect_node(stripe, SPEC.HAZARD_COLOR))
	return host


## Crowd members are Node2D discs positioned at their centre, so the victim
## impact ripple can read their global position like a live enemy's.
func _crowd_nodes(size: Vector2i, count: int) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	var radius := SPEC.crowd_radius(size)
	for center in SPEC.crowd_positions(size, count):
		var points := PackedVector2Array()
		for step in 16:
			var angle := TAU * float(step) / 16.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		var disc := Polygon2D.new()
		disc.polygon = points
		disc.color = SPEC.CROWD_COLOR
		disc.position = center
		nodes.append(disc)
	return nodes


## The weapon's own victim-impact flipbook, played on the crowd the way the
## executor plays it on live victims, advanced into its first burst and held.
## The player is added to the tree first so the bursts resolve the crowd's
## real global positions; the bursts are top-level sprites, so they take the
## on-screen scale explicitly.
func _play_impacts(host: Node2D, weapon_id: String, victims: Array[Node2D], cast_position: Vector2, size: Vector2i) -> void:
	var impacts: Node2D = ImpactPlayer.new()
	impacts.extra_hit_flash = false
	impacts.z_index = 50
	host.add_child(impacts)
	impacts.play(SPEC.weapon_spec(weapon_id)["victim_frames"] as SpriteFrames, victims, cast_position)
	impacts.advance(IMPACT_ADVANCE_SECONDS)
	impacts.set_paused(true)
	for child in impacts.get_children():
		var burst := child as AnimatedSprite2D
		if burst != null:
			burst.scale *= SPEC.on_screen_scale(size)


## The hero as a world entity in its column: a dark backing plus the class
## full-frame idle at the Player's combat visual scale.
func _player_node(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var column := SPEC.player_column_rect(size)
	var drawn := SPEC.player_sprite_rect(size)
	host.add_child(_rect_node(Rect2(column.position.x, drawn.position.y, column.size.x, drawn.size.y), SPEC.PLAYER_BACKING_COLOR))
	var texture: Texture2D = load(SPEC.PLAYER_SPRITE)
	if texture == null:
		_errors.append("player sprite missing: %s" % SPEC.PLAYER_SPRITE)
		return host
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = drawn.get_center()
	sprite.scale = Vector2.ONE * (drawn.size.x / float(texture.get_width()))
	host.add_child(sprite)
	return host


## The HUD layer sits above world VFX in the game, so it does here too: the
## band, the HP readout and the real ultimate HUD widget at the UI scale.
func _hud_node(size: Vector2i, weapon_id: String) -> Node2D:
	var band := SPEC.hud_band_rect(size)
	var host := Node2D.new()
	host.z_index = 100
	host.add_child(_rect_node(band, SPEC.HUD_BAND_COLOR))
	var scale := SPEC.ui_scale(size)
	var margin := band.size.y * 0.18
	var widget := HudWidgetScene.instantiate() as PanelContainer
	widget.scale = Vector2.ONE * scale
	host.add_child(widget)
	widget.apply_state(HudViewModel.build(_hud_fixtures.weapon_profile_snapshot(SPEC.CLASS_ID, weapon_id, {
		"charge": {"fraction": 1.0, "active": true},
		"input": _hud_fixtures.keyboard_input(),
	})))
	var widget_size := widget.get_combined_minimum_size() * scale
	widget.position = Vector2(band.position.x + margin, band.get_center().y - widget_size.y * 0.5)
	var label := Label.new()
	label.text = SPEC.HUD_TEXT
	label.add_theme_font_size_override("font_size", SPEC.hud_font_size(size))
	label.add_theme_color_override("font_color", SPEC.HUD_TEXT_COLOR)
	var text_size := ThemeDB.fallback_font.get_string_size(SPEC.HUD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SPEC.hud_font_size(size))
	label.position = Vector2(widget.position.x + widget_size.x + margin * 2.0, band.get_center().y - text_size.y * 0.5)
	host.add_child(label)
	return host


## Capture annotation, not game HUD: the exact configuration the frame was
## rendered under, plus the mode and weapon swatches the gate probes.
func _caption_node(size: Vector2i, entry: Dictionary, seconds: float, crowd: int, mode: Dictionary) -> Node2D:
	var host := Node2D.new()
	host.z_index = 100
	host.add_child(_rect_node(SPEC.state_band_rect(size), SPEC.STATE_BAND_COLOR))
	host.add_child(_rect_node(SPEC.mode_swatch_rect(size), mode.get("swatch", Color.WHITE) as Color))
	host.add_child(_rect_node(SPEC.weapon_swatch_rect(size), SPEC.weapon_spec(str(entry["weapon_id"])).get("swatch", Color.WHITE) as Color))
	var text := SPEC.caption_text(entry, seconds, crowd, mode, SPEC.veil_alpha(str(entry["weapon_id"]), seconds, mode))
	var label := Label.new()
	label.text = text
	label.position = SPEC.caption_text_rect(size, text).position
	label.add_theme_font_size_override("font_size", SPEC.caption_font_size(size, text))
	label.add_theme_color_override("font_color", SPEC.STATE_TEXT_COLOR)
	host.add_child(label)
	return host
