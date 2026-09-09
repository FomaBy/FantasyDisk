extends SceneTree

## FAN-3941 — windowed real-runtime certification capture for the Thief trio.
##
## Every frame comes from a real cast: the shipped Player (its own current
## Camera2D at the game's combat zoom for the viewport, real HP and a full
## ultimate charge) stands at the origin of a world holding real Enemy scenes
## on a deterministic spiral, a real hazard telegraph and a real enemy
## projectile; the live ultimate HUD adapter mounts the real widget on that
## Player; the cast is started through UltimatePlayerHost, so the executor,
## the authored presentation scene, the victim impacts and every weight device
## (veil, hitstop, camera shake, SFX duck) run exactly as in the game. The
## engine runs under `--fixed-fps 60`, so a beat is a frame index and the run
## reproduces byte for byte; the camera offset is sampled every frame as the
## reduced-motion device evidence, the live scene's full-screen surfaces are
## counted, and opaque coverage is measured on a scene-only render taken while
## the tree is paused at the beat. The capture manifest records source,
## engine, command, seed, per-frame camera/world state, hashes, probes and the
## per-run traces the gate re-checks.
##
## Run windowed through the process guard with the fixed frame clock:
##   python3 tools/godot_gate.py --path . --fixed-fps 60 --disable-vsync \
##     --script res://tests/ultimates/presentation/thief_certification_live_capture.gd

const SPEC := preload("res://tests/ultimates/presentation/thief_certification_capture_test.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const HazardVfx := preload("res://scripts/hazard_vfx.gd")
const ProjectileScene := preload("res://scenes/EnemyProjectile.tscn")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")

const SETTLE_FRAMES := 3
const HAZARD_WINDUP_SECONDS := 100.0
const FLOOR_HALF_EXTENT := 6000.0
const HUD_LAYER := 10
const CAPTION_LAYER := 11
const FLOOR_Z := -100

var _errors: Array[String] = []
var _captures: Array[Dictionary] = []
var _runs: Array[Dictionary] = []
var _source: Dictionary = {}
var _hud_clear := {}
var _sweeps := {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3941 %s certification capture skipped (headless); run windowed for evidence." % SPEC.CLASS_ID.capitalize())
		quit(0)
		return
	if OS.get_environment("FSD_GODOT_EXCLUSIVE") != "1":
		push_error("%s certification capture: certification captures run under the exclusive process admission only (FSD_GODOT_EXCLUSIVE=1 %s)" % [SPEC.CLASS_ID.capitalize(), SPEC.CAPTURE_COMMAND])
		quit(1)
		return
	_source = _git_source()
	if _source.is_empty():
		quit(1)
		return
	if not await _fixed_fps_active():
		push_error("%s certification capture: run with --fixed-fps %d so beats are frame indices" % [SPEC.CLASS_ID.capitalize(), SPEC.FIXED_FPS])
		quit(1)
		return
	seed(SPEC.CAPTURE_SEED)
	root.set_meta("combat_feedback", true)
	var directory := ProjectSettings.globalize_path("res://" + SPEC.CAPTURE_ROOT)
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK:
		push_error("%s certification capture: cannot create %s (%s)" % [SPEC.CLASS_ID.capitalize(), directory, error_string(made)])
		quit(1)
		return
	for weapon_id in SPEC.weapon_ids():
		_hud_clear[weapon_id] = true
		for mode_id in SPEC.MODE_IDS:
			for viewport_id in SPEC.VIEWPORT_IDS:
				var ok := await _run(weapon_id, mode_id, viewport_id, false)
				if not ok:
					_fail()
					return
		# The envelope sweep renders a coverage frame every frame, which changes
		# how many frames the GPU draws per simulated frame; it therefore runs
		# as its own uncommitted cast so every committed run draws identically.
		var swept := await _run(weapon_id, SPEC.MODE_NORMAL, SPEC.BEAT_VIEWPORT, true)
		if not swept:
			_fail()
			return
	SPEC.reset_mode(self)
	var manifest := _manifest()
	var file := FileAccess.open(SPEC.MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("%s certification capture: cannot write %s" % [SPEC.CLASS_ID.capitalize(), SPEC.MANIFEST_PATH])
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	print("%s certification capture manifest written: %s (%d frames, %d runs)" % [SPEC.CLASS_ID.capitalize(), SPEC.MANIFEST_PATH, _captures.size(), _runs.size()])
	quit(0)


## Provenance read from git at capture time: the commit and tree the clean
## worktree is checked out at. Only the evidence output paths of the three
## certification classes may be dirty (an earlier class's fresh frames); any
## other change refuses the capture, so the recorded commit is the source the
## frames were rendered from.
func _git_source() -> Dictionary:
	var head := _git(["rev-parse", "HEAD"])
	var tree := _git(["rev-parse", "HEAD^{tree}"])
	var branch := _git(["rev-parse", "--abbrev-ref", "HEAD"])
	var dirty := _git(["status", "--porcelain", "--untracked-files=all", "--", ".", ":!docs/design/reference-assets-lfs/ultimate-certification", ":!docs/design/references/weapon_ultimates"])
	if head.length() != 40 or tree.length() != 40:
		push_error("%s certification capture: git provenance unavailable (head '%s', tree '%s')" % [SPEC.CLASS_ID.capitalize(), head, tree])
		return {}
	if not dirty.is_empty():
		push_error("%s certification capture: the worktree has uncommitted source changes; commit the amended source first:\n%s" % [SPEC.CLASS_ID.capitalize(), dirty])
		return {}
	return {
		"ref": SPEC.SOURCE_REF,
		"branch_at_capture": branch,
		"commit_sha": head,
		"tree_sha": tree,
		"worktree_clean": true,
		"recorded_by": SPEC.SOURCE_RECORDER,
		"note": "The commit the clean worktree was checked out at when these frames were rendered: the shipped %s scenes, drivers, executors, Player, Enemy, hazard, HUD, the production accessibility policy and this capture tooling all come from it. The frames and this manifest are committed afterwards in a separate evidence commit, so the recorded source never refers to itself." % SPEC.CLASS_ID.capitalize(),
	}


func _git(args: Array) -> String:
	var output: Array = []
	var packed := PackedStringArray()
	for arg in args:
		packed.append(str(arg))
	var code := OS.execute("git", packed, output, true)
	if code != 0:
		return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""


## The engine consumes its own --fixed-fps option, so the fixed clock is
## verified by measuring it: every process delta must be exactly one frame.
func _fixed_fps_active() -> bool:
	var expected := 1.0 / float(SPEC.FIXED_FPS)
	for _sample in 6:
		await process_frame
		if absf(root.get_process_delta_time() - expected) > 0.000001:
			return false
	return true


func _fail() -> void:
	for error in _errors:
		push_error("%s certification capture: %s" % [SPEC.CLASS_ID.capitalize(), error])
	SPEC.reset_mode(self)
	quit(1)


# --- one real cast ------------------------------------------------------------


## One activation per weapon x mode x viewport. Every beat frame of the run is
## saved and every frame's camera offset is traced; a sweep run commits no
## frame and instead measures the opaque coverage of every frame of the cast.
func _run(weapon_id: String, mode_id: String, viewport_id: String, sweep: bool) -> bool:
	var mode := SPEC.mode_spec(mode_id)
	var size := SPEC.viewport_size(viewport_id)
	var zoom := SPEC.camera_zoom(size)
	# Every cast starts from the same RNG state, so two runs that differ only in
	# a device draw the same random values everywhere else and their frames can
	# be compared pixel for pixel.
	seed(SPEC.CAPTURE_SEED)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	SPEC.apply_mode(self, mode)
	var arena := SPEC.build_arena(self, viewport, weapon_id, mode, zoom, false)
	var bench := _bench_nodes(arena)
	var hud := _hud_layer(size, arena)
	viewport.add_child(hud["layer"])
	var caption := CanvasLayer.new()
	caption.layer = CAPTION_LAYER
	viewport.add_child(caption)
	for _frame in SETTLE_FRAMES:
		await process_frame
	var baseline := arena.camera.offset if arena.camera != null else Vector2.ZERO
	_aim(viewport, arena, size, baseline)
	await process_frame

	print("%s certification cast: %s/%s/%s%s" % [SPEC.CLASS_ID.capitalize(), weapon_id, mode_id, viewport_id, " (sweep)" if sweep else ""])
	var status: int = PlayerHost.activate(arena.player)
	if status != PlayerHost.ACTIVATION_STARTED:
		_errors.append("%s/%s/%s: the real cast did not start (%d, %s)" % [weapon_id, mode_id, viewport_id, status, PlayerHost.activation_failure(arena.player)])
		return false
	var scene := SPEC.live_scene(arena.host, arena.world, weapon_id)
	if scene == null or not scene.is_inside_tree():
		_errors.append("%s/%s/%s: the authored scene is not live under the effect parent" % [weapon_id, mode_id, viewport_id])
		return false
	var surfaces := SPEC.fullscreen_nodes(scene).size()
	var accessibility := SPEC.current_snapshot(self)
	var surface_peak := 0.0
	var activation = arena.host.controller().active_activation()
	var aim_target: Variant = activation.primitive_value("target") if activation != null else null

	var beat_frames := {}
	var last_frame := 0
	for beat_id in SPEC.beat_ids(weapon_id):
		var everywhere: bool = SPEC.FULL_VIEWPORT_BEATS.has(beat_id) or SPEC.is_payoff_beat(weapon_id, beat_id)
		if not everywhere and viewport_id != SPEC.BEAT_VIEWPORT:
			continue
		var frame := SPEC.beat_frame(weapon_id, beat_id)
		if not beat_frames.has(frame):
			beat_frames[frame] = []
		(beat_frames[frame] as Array).append(beat_id)
		last_frame = maxi(last_frame, frame)
	var sweep_peak := 0.0
	var sweep_peak_frame := 0
	var sweep_samples := 0
	var trace_max := 0.0
	var trace_first := -1
	var trace_last := -1
	var released_frame := -1
	var enemies := SPEC.enemy_count(weapon_id, mode)
	var frame := 0
	while frame < last_frame:
		await process_frame
		frame += 1
		if scene != null and is_instance_valid(scene) and scene.is_inside_tree():
			surface_peak = maxf(surface_peak, SPEC.fullscreen_alpha(scene))
		var offset_length := SPEC.shake_offset(arena.camera, baseline).length()
		if offset_length > 0.0:
			trace_max = maxf(trace_max, offset_length)
			trace_first = frame if trace_first < 0 else trace_first
			trace_last = frame
		var live := scene != null and is_instance_valid(scene) and scene.is_inside_tree()
		if not live and released_frame < 0:
			released_frame = frame
		var wants_coverage := sweep or beat_frames.has(frame)
		if not wants_coverage:
			continue
		if sweep and not beat_frames.has(frame) and frame % 2 == 1:
			continue
		await RenderingServer.frame_post_draw
		var image := _read(viewport, "%s/%s/%s frame %d" % [weapon_id, mode_id, viewport_id, frame])
		if image == null:
			return false
		var camera := SPEC.camera_record(arena.camera, baseline)
		var coverage := await _measure_coverage(viewport, scene, bench, hud["layer"], caption, "%s/%s/%s frame %d" % [weapon_id, mode_id, viewport_id, frame])
		if coverage.is_empty():
			return false
		if sweep:
			sweep_samples += 1
			if float(coverage["ratio"]) > sweep_peak:
				sweep_peak = float(coverage["ratio"])
				sweep_peak_frame = frame
			if sweep_samples % 25 == 0:
				print("%s certification sweep %s: %d samples, frame %d, peak %.4f" % [SPEC.CLASS_ID.capitalize(), weapon_id, sweep_samples, frame, sweep_peak])
		if sweep:
			continue
		for raw_beat in beat_frames.get(frame, []) as Array:
			var beat_id := str(raw_beat)
			var entry := {"weapon_id": weapon_id, "mode": mode_id, "viewport": viewport_id, "beat": beat_id}
			var caption_offset := Vector2(float((camera["offset"] as Array)[0]), float((camera["offset"] as Array)[1]))
			_draw_caption(caption, size, entry, SPEC.beat_seconds(weapon_id, beat_id), enemies, mode, caption_offset)
			await RenderingServer.frame_post_draw
			var framed := _read(viewport, SPEC.entry_id(entry))
			if framed == null:
				return false
			# The runtime frees a released scene at the end of the frame it was
			# released in, so the liveness read above is confirmed after the
			# paused coverage render before the frame is recorded.
			live = live and scene != null and is_instance_valid(scene) and scene.is_inside_tree()
			if not live and released_frame < 0:
				released_frame = frame
			var record := _save(entry, framed, camera, arena, scene if live else null, coverage, surfaces, frame, aim_target, mode, live)
			if record.is_empty():
				return false
			_captures.append(record)
			_clear_caption(caption)
			print("%s certification capture saved: %s (%dx%d, frame %d, coverage %.4f, offset %.2f)" % [
				SPEC.CLASS_ID.capitalize(), str(record["path"]), size.x, size.y, frame, float(coverage["ratio"]), caption_offset.length(),
			])
	if arena.host.controller().is_active():
		arena.host.controller().cancel("cancel")
	if sweep:
		_sweeps[weapon_id] = {
			"viewport": viewport_id,
			"mode": mode_id,
			"step_seconds": snappedf(2.0 / float(SPEC.FIXED_FPS), 0.0001),
			"samples": sweep_samples,
			"duration_seconds": snappedf(float(last_frame) / float(SPEC.FIXED_FPS), 0.01),
			"peak_opaque_coverage_ratio": snappedf(sweep_peak, 0.0001),
			"peak_at_seconds": snappedf(float(sweep_peak_frame) / float(SPEC.FIXED_FPS), 0.01),
			"note": "uncommitted sweep cast: every second frame of the normal 648p cast measured, plus every beat frame",
		}
		viewport.queue_free()
		await process_frame
		return true
	_runs.append({
		"weapon_id": weapon_id,
		"key": SPEC.key_for(weapon_id),
		"mode": mode_id,
		"viewport": viewport_id,
		"frames": frame,
		"enemies": enemies,
		"accessibility": accessibility,
		"fullscreen_surfaces": surfaces,
		"fullscreen_alpha_peak": snappedf(surface_peak, 0.001),
		"aim_target": _pair(aim_target) if aim_target is Vector2 else null,
		"presentation_released_frame": released_frame,
		"presentation_released_seconds": snappedf(float(released_frame) / float(SPEC.FIXED_FPS), 0.01) if released_frame >= 0 else -1.0,
		"camera_trace": {
			"samples": frame,
			"max_offset": snappedf(trace_max, 0.001),
			"first_nonzero_frame": trace_first,
			"last_nonzero_frame": trace_last,
			"zoom": snappedf(zoom, 0.0001),
		},
	})
	viewport.queue_free()
	await process_frame
	return true


## Aims the cast at the enemy cluster by feeding the sub-viewport the mouse
## position the game would read, so the executor's target is deterministic.
func _aim(viewport: SubViewport, arena, size: Vector2i, baseline: Vector2) -> void:
	var camera := SPEC.camera_record(arena.camera, baseline)
	var screen := SPEC.project(SPEC.aim_center(), camera, size)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	viewport.push_input(motion, true)
	viewport.warp_mouse(screen)


## Floor, hazard telegraph and enemy projectile: the bench parts of the world,
## hidden for the scene-only coverage render.
func _bench_nodes(arena) -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([
		Vector2(-FLOOR_HALF_EXTENT, -FLOOR_HALF_EXTENT), Vector2(FLOOR_HALF_EXTENT, -FLOOR_HALF_EXTENT),
		Vector2(FLOOR_HALF_EXTENT, FLOOR_HALF_EXTENT), Vector2(-FLOOR_HALF_EXTENT, FLOOR_HALF_EXTENT),
	])
	floor.color = SPEC.FLOOR_COLOR
	floor.z_index = FLOOR_Z
	arena.world.add_child(floor)
	arena.world.move_child(floor, 0)
	nodes.append(floor)
	var hazard := Node2D.new()
	hazard.name = "CertificationHazard"
	hazard.position = SPEC.hazard_zone_center()
	arena.world.add_child(hazard)
	HazardVfx.telegraph(hazard, SPEC.HAZARD_ZONE_RADIUS, SPEC.HAZARD_ZONE_COLOR, HAZARD_WINDUP_SECONDS)
	arena.hazard = hazard
	nodes.append(hazard)
	var projectile := ProjectileScene.instantiate() as Node2D
	arena.world.add_child(projectile)
	if projectile.has_method("setup"):
		projectile.call("setup", SPEC.projectile_position(), arena.player.global_position, 1.0, 0.0)
	projectile.global_position = SPEC.projectile_position()
	projectile.set_physics_process(false)
	projectile.set_process(false)
	arena.projectile = projectile
	nodes.append(projectile)
	for enemy in arena.enemies:
		nodes.append(enemy)
	nodes.append(arena.player)
	return nodes


## The HUD layer at the UI scale of the viewport: the band, the live HP
## readout bound to the real Player, and the real ultimate HUD widget mounted
## by the live adapter exactly where the combat HUD places it.
func _hud_layer(size: Vector2i, arena) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = HUD_LAYER
	var scale := SPEC.ui_scale(size)
	layer.transform = Transform2D(0.0, Vector2.ONE * scale, 0.0, Vector2.ZERO)
	var control := Control.new()
	control.name = "CombatHud"
	control.size = SPEC.LOGICAL_CANVAS
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(control)
	var band := ColorRect.new()
	band.color = SPEC.HUD_BAND_COLOR
	band.size = Vector2(SPEC.LOGICAL_CANVAS.x, SPEC.LOGICAL_CANVAS.y * SPEC.HUD_BAND_HEIGHT_RATIO)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(band)
	var hp := Label.new()
	hp.name = "HpReadout"
	hp.add_theme_font_size_override("font_size", SPEC.HUD_FONT_LOGICAL)
	hp.add_theme_color_override("font_color", SPEC.HUD_TEXT_COLOR)
	hp.position = Vector2(48.0, band.size.y * 0.5 - float(SPEC.HUD_FONT_LOGICAL) * 0.7)
	control.add_child(hp)
	var binder := HpBinder.new()
	binder.player = arena.player
	binder.label = hp
	control.add_child(binder)
	var adapter := HudAdapter.new()
	control.add_child(adapter)
	adapter.set_process(true)
	if not adapter.mount(control, arena.player):
		_errors.append("the live ultimate HUD adapter did not mount on the Player")
	return {"layer": layer, "control": control, "adapter": adapter}


class HpBinder extends Node:
	var player: Node2D = null
	var label: Label = null

	func _process(_delta: float) -> void:
		if player == null or not is_instance_valid(player) or label == null:
			return
		label.text = "HP %d/%d" % [int(floor(float(player.get("health")))), int(floor(float(player.get("max_health"))))]


func _draw_caption(layer: CanvasLayer, size: Vector2i, entry: Dictionary, seconds: float, enemies: int, mode: Dictionary, offset: Vector2) -> void:
	_clear_caption(layer)
	layer.add_child(_rect_node(SPEC.state_band_rect(size), SPEC.STATE_BAND_COLOR))
	layer.add_child(_rect_node(SPEC.mode_swatch_rect(size), mode.get("swatch", Color.WHITE) as Color))
	layer.add_child(_rect_node(SPEC.weapon_swatch_rect(size), SPEC.weapon_spec(str(entry["weapon_id"])).get("swatch", Color.WHITE) as Color))
	var text := SPEC.caption_text(entry, seconds, enemies, mode, offset)
	var label := Label.new()
	label.text = text
	label.position = SPEC.caption_text_rect(size, text).position
	label.add_theme_font_size_override("font_size", SPEC.caption_font_size(size, text))
	label.add_theme_color_override("font_color", SPEC.STATE_TEXT_COLOR)
	layer.add_child(label)


func _clear_caption(layer: CanvasLayer) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.free()


func _rect_node(rect: Rect2, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	return polygon


## Authored-scene-only opaque coverage at the current beat: the tree is paused
## so no clock moves, every CanvasItem in the viewport outside the live scene's
## subtree (and its ancestors) is hidden, the viewport is rendered transparent,
## and the visibility is restored before the tree resumes.
func _measure_coverage(viewport: SubViewport, scene: Variant, _bench: Array[CanvasItem], hud: CanvasLayer, caption: CanvasLayer, label: String) -> Dictionary:
	paused = true
	var hidden: Array[CanvasItem] = []
	var keep := {}
	if scene != null and is_instance_valid(scene):
		var cursor: Node = scene
		while cursor != null and cursor != viewport:
			keep[cursor.get_instance_id()] = true
			cursor = cursor.get_parent()
	var pending: Array[Node] = [viewport]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if scene != null and is_instance_valid(scene) and node == scene:
			continue
		if node != viewport and node is CanvasItem and not keep.has(node.get_instance_id()):
			if (node as CanvasItem).visible:
				(node as CanvasItem).visible = false
				hidden.append(node as CanvasItem)
			continue
		for child in node.get_children():
			pending.append(child)
	var hud_visible := hud.visible
	var caption_visible := caption.visible
	hud.visible = false
	caption.visible = false
	viewport.transparent_bg = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _read(viewport, label + " coverage")
	viewport.transparent_bg = false
	for node in hidden:
		if is_instance_valid(node):
			node.visible = true
	hud.visible = hud_visible
	caption.visible = caption_visible
	await RenderingServer.frame_post_draw
	paused = false
	if image == null:
		return {}
	var coverage := SPEC.opaque_coverage(image)
	var bounds := coverage["bounds"] as Rect2
	coverage["hud_band_clear"] = not bounds.has_area() or not bounds.intersects(SPEC.hud_band_rect(viewport.size))
	coverage["fullscreen_alpha"] = SPEC.fullscreen_alpha(scene) if scene != null and is_instance_valid(scene) else 0.0
	return coverage


func _save(entry: Dictionary, image: Image, camera: Dictionary, arena, scene: Variant, coverage: Dictionary, surfaces: int, frame: int, aim_target: Variant, mode: Dictionary, live: bool) -> Dictionary:
	var path := SPEC.capture_path(entry)
	var saved := image.save_png(ProjectSettings.globalize_path("res://" + path))
	if saved != OK:
		_errors.append("cannot save %s: %s" % [path, error_string(saved)])
		return {}
	var world := SPEC.arena_world_record(arena)
	if aim_target is Vector2:
		world["aim_target"] = _pair(aim_target)
	var capture := {
		"weapon_id": str(entry["weapon_id"]),
		"key": SPEC.key_for(str(entry["weapon_id"])),
		"mode": str(entry["mode"]),
		"viewport": str(entry["viewport"]),
		"beat": str(entry["beat"]),
		"beat_seconds": SPEC.beat_seconds(str(entry["weapon_id"]), str(entry["beat"])),
		"frame": frame,
		"presentation_elapsed": snappedf(_presentation_elapsed(arena.host), 0.001),
		"phase": SPEC.phase_at(str(entry["weapon_id"]), SPEC.beat_seconds(str(entry["weapon_id"]), str(entry["beat"]))),
		"width": image.get_width(),
		"height": image.get_height(),
		"path": path,
		"sha256": FileAccess.get_sha256("res://" + path).to_lower(),
		"bytes": FileAccess.open("res://" + path, FileAccess.READ).get_length(),
		"activation_started": true,
		"presentation_live": live,
		"accessibility": SPEC.current_snapshot(self),
		"enemies": SPEC.enemy_count(str(entry["weapon_id"]), mode),
		"camera": camera,
		"world": world,
		"measured": {
			"opaque_coverage_ratio": snappedf(float(coverage["ratio"]), 0.0001),
			"effect_bounds": _rect(coverage["bounds"] as Rect2),
			"hud_band_clear": bool(coverage["hud_band_clear"]),
			"fullscreen_surfaces": surfaces,
			"fullscreen_alpha": snappedf(float(coverage["fullscreen_alpha"]), 0.001),
			"formation_signature_sha1": SPEC.formation_signature(scene).sha1_text() if live else "released",
		},
	}
	if not bool(coverage["hud_band_clear"]):
		_hud_clear[str(entry["weapon_id"])] = false
	capture["readability"] = SPEC.readability_report(image, entry, capture)
	var violations := SPEC.readability_violations(entry, capture["readability"])
	if not violations.is_empty():
		_errors.append_array(violations)
		return {}
	return capture


func _presentation_elapsed(host: Node) -> float:
	var presentation = host.get("_presentation")
	if presentation == null:
		return -1.0
	var timeline = presentation.get("_timeline")
	if timeline == null or not timeline.has_method("elapsed_seconds"):
		return -1.0
	return float(timeline.elapsed_seconds())


# --- manifest -----------------------------------------------------------------


## Mode effects are derived from what the runs measured, never assumed: a
## camera that moved with the toggle on is a shake device, a live full-screen
## surface is what the photosensitivity-safe variant suppressed, and a device
## that does not exist is recorded as an intrinsic no-op with its production
## semantics.
func _mode_effects(weapon_id: String) -> Dictionary:
	var shook := false
	var surfaces := 0
	var lit := 0.0
	var safe_lit := 0.0
	var released_before_active := -1.0
	var active_edge := float(SPEC.timing_seconds(weapon_id).get("active", 0.0))
	for run in _runs:
		if str(run["weapon_id"]) != weapon_id:
			continue
		if str(run["mode"]) == SPEC.MODE_NORMAL:
			shook = shook or float((run["camera_trace"] as Dictionary)["max_offset"]) > 0.0
			surfaces = maxi(surfaces, int(run["fullscreen_surfaces"]))
			lit = maxf(lit, float(run.get("fullscreen_alpha_peak", 0.0)))
			var released := float(run.get("presentation_released_seconds", -1.0))
			if released >= 0.0 and released < active_edge:
				released_before_active = maxf(released_before_active, released)
		elif str(run["mode"]) == SPEC.MODE_PHOTOSENSITIVITY_SAFE:
			safe_lit = maxf(safe_lit, float(run.get("fullscreen_alpha_peak", 0.0)))
	# A cast whose executor completes before the declared active edge has its
	# presentation released by the host before the first-impact devices fire;
	# that is recorded as what it is, not as a scene without the device.
	var early_release := "" if released_before_active < 0.0 else " The scene's driver owns the device, but the host released the presentation at %.2f s in the normal cast, before the %.2f s active edge where it fires (see the readability report's runtime finding)." % [released_before_active, active_edge]
	var effects := {
		SPEC.MODE_CROWDED: {
			"effect": SPEC.EFFECT_CROWD,
			"production_semantics": "the declared performance.crowd_cap of real Enemy scenes stands in the cast; every victim takes the executor's damage and the weapon's victim-impact flipbook",
		},
	}
	if shook:
		effects[SPEC.MODE_REDUCED_MOTION] = {
			"effect": SPEC.EFFECT_CAMERA_SHAKE,
			"production_semantics": "ultimate_reduced_motion=true in the persisted ultimate_accessibility_settings snapshot on the tree root (scripts/settings/ultimate_accessibility_settings.gd, published as main.gd publishes it; the shipped screen_shake toggle stays on); the live cast's own driver reads it and leaves the Player's Camera2D offset at zero, everything else in the cast is unchanged",
		}
	else:
		effects[SPEC.MODE_REDUCED_MOTION] = {
			"effect": SPEC.EFFECT_NONE_INTRINSIC,
			"production_semantics": "ultimate_reduced_motion=true in the persisted ultimate_accessibility_settings snapshot on the tree root; the live cast never moved the camera, so the Player's Camera2D offset stays at zero with the preference on or off (measured every frame of both runs) and the frame is the normal frame by construction." + early_release,
		}
	if surfaces > 0:
		effects[SPEC.MODE_PHOTOSENSITIVITY_SAFE] = {
			"effect": SPEC.EFFECT_FULLSCREEN_SUPPRESSED,
			"production_semantics": "ultimate_photosensitivity_safe=true in the persisted ultimate_accessibility_settings snapshot on the tree root; the live cast's own driver keeps the %d full-screen surface(s) it flags as fullscreen_layer (the arena-wide veil, the only surface the cast draws over the whole viewport) dark for the whole cast (normal peak alpha %.3f, safe peak alpha %.3f, measured every frame); the camera device is unchanged" % [surfaces, lit, safe_lit],
		}
	else:
		effects[SPEC.MODE_PHOTOSENSITIVITY_SAFE] = {
			"effect": SPEC.EFFECT_NONE_INTRINSIC,
			"production_semantics": "ultimate_photosensitivity_safe=true in the persisted ultimate_accessibility_settings snapshot on the tree root; the live scene authors no full-screen surface (0 fullscreen_layer nodes measured on the live cast), so the preference has nothing to remove and the frame is the normal frame by construction." + early_release,
		}
	return effects


func _manifest() -> Dictionary:
	var keys: Array[String] = []
	for weapon_id in SPEC.weapon_ids():
		keys.append(SPEC.key_for(weapon_id))
	var viewports := {}
	for raw_viewport in SPEC.VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		viewports[str(viewport["id"])] = {"width": size.x, "height": size.y, "camera_zoom": snappedf(SPEC.camera_zoom(size), 0.0001), "ui_scale": snappedf(SPEC.ui_scale(size), 0.0001)}
	var weapons: Array[Dictionary] = []
	for weapon_id in SPEC.weapon_ids():
		var peak := float((_sweeps.get(weapon_id, {}) as Dictionary).get("peak_opaque_coverage_ratio", 0.0))
		var surfaces := 0
		for record in _captures:
			if str(record["weapon_id"]) == weapon_id:
				peak = maxf(peak, float((record["measured"] as Dictionary)["opaque_coverage_ratio"]))
				surfaces = maxi(surfaces, int((record["measured"] as Dictionary)["fullscreen_surfaces"]))
		var beats := {}
		for beat_id in SPEC.beat_ids(weapon_id):
			beats[beat_id] = {"seconds": SPEC.beat_seconds(weapon_id, beat_id), "frame": SPEC.beat_frame(weapon_id, beat_id), "payoff": SPEC.is_payoff_beat(weapon_id, beat_id)}
		weapons.append({
			"weapon_id": weapon_id,
			"key": SPEC.key_for(weapon_id),
			"scene_node": str(SPEC.weapon_spec(weapon_id)["scene_node"]),
			"crowd_cap": SPEC.crowd_cap(weapon_id),
			"timing_seconds": SPEC.timing_seconds(weapon_id),
			"beats": beats,
			"fullscreen_surfaces": surfaces,
			"mode_effects": _mode_effects(weapon_id),
			"envelope_sweep": _sweeps.get(weapon_id, {}),
			"max_opaque_coverage_ratio": snappedf(peak, 0.0001),
			"hud_band_clear_all_frames": bool(_hud_clear.get(weapon_id, false)),
		})
	var version := Engine.get_version_info()
	return {
		"schema_version": SPEC.SCHEMA_VERSION,
		"issue": SPEC.ISSUE,
		"class_id": SPEC.CLASS_ID,
		"canonical_keys": keys,
		"source": _source,
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
			"accessibility_policy": SPEC.POLICY_MODULE,
			"headless_skipped": false,
			"real_runtime": true,
			"fixed_fps": SPEC.FIXED_FPS,
			"seed": SPEC.CAPTURE_SEED,
			"seed_note": "seed() is reset to this value before every cast; the shake device draws randf_range for its offsets, so the seed plus the fixed frame clock make every offset and every frame reproducible, and runs that differ only in a device stay pixel-comparable.",
			"method": "One real cast per weapon x mode x viewport in a SubViewport of the exact viewport size: the shipped Player (configure_character, full ultimate charge, its own Camera2D made current at combat zoom 1.12 x viewport_height/1440, smoothing off) at the origin; real Enemy scenes on a deterministic spiral around the aim centre (frozen in place, real HP, real hit feedback); a real HazardVfx telegraph and a real EnemyProjectile; the live UltimateHudRuntimeAdapter mounting the real UltimateHudWidget plus an HP readout bound to the Player; the cast started with UltimatePlayerHost.activate so the executor, authored scene, victim impacts and weight devices run as in the game. The engine runs under --fixed-fps 60: beat = frame index. Each frame samples the Player camera offset (reduced-motion evidence). The hero's basic weapon is held (its _process is off) so only the ultimate acts. At a beat the composite frame is read, then the tree is paused, every CanvasItem outside the authored scene's subtree is hidden and the viewport rendered transparent for the authored-scene opaque-coverage measurement (alpha >= 0.5, stride 2; bounding box against the HUD band), then restored. reduced_motion and photosensitivity_safe publish the persisted ultimate_accessibility_settings snapshot on the tree root (scripts/settings/ultimate_accessibility_settings.gd apply_snapshot, as main.gd does at startup) and the live cast's own driver honours it; the capture runner never touches the scene. The full-screen surface alpha of the live scene is sampled every frame. crowded stands the declared crowd cap of enemies. Readability probes project the recorded world positions through the recorded camera state.",
			"logical_canvas": "%dx%d" % [int(SPEC.LOGICAL_CANVAS.x), int(SPEC.LOGICAL_CANVAS.y)],
			"stretch_mode": "canvas_items",
			"combat_camera_zoom": SPEC.COMBAT_CAMERA_ZOOM,
			"player_scene": "res://scenes/Player.tscn",
			"enemy_scene": "res://scenes/Enemy.tscn",
			"hazard": "scripts/hazard_vfx.gd telegraph(radius %.0f) at Player offset (%.0f, %.0f) and scenes/EnemyProjectile.tscn at Player offset (%.0f, %.0f)" % [SPEC.HAZARD_ZONE_RADIUS, SPEC.HAZARD_ZONE_OFFSET.x, SPEC.HAZARD_ZONE_OFFSET.y, SPEC.PROJECTILE_OFFSET.x, SPEC.PROJECTILE_OFFSET.y],
			"hud": "scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd mount() on the Player (real UltimateHudWidget, live charge/active state) plus an HP readout bound to Player.health/max_health",
			"representative_enemies": SPEC.REPRESENTATIVE_ENEMIES,
			"coverage_alpha_min": SPEC.COVERAGE_ALPHA_MIN,
			"coverage_stride": SPEC.COVERAGE_STRIDE,
		},
		"world": {
			"player_origin": _pair(SPEC.PLAYER_ORIGIN),
			"aim_center": _pair(SPEC.aim_center()),
			"enemy_spiral": {"base": SPEC.ENEMY_SPIRAL_BASE, "step": SPEC.ENEMY_SPIRAL_STEP, "golden_angle": SPEC.ENEMY_GOLDEN_ANGLE},
			"hazard_zone": {"center": _pair(SPEC.hazard_zone_center()), "radius": SPEC.HAZARD_ZONE_RADIUS},
			"projectile": _pair(SPEC.projectile_position()),
			"enemy_health": SPEC.ENEMY_HEALTH,
		},
		"modes": SPEC.MODE_IDS,
		"beats": SPEC.BEAT_IDS,
		"beat_rule": "release/active/recovery at the midpoint of the declared phase window, impact %.2f s after the active edge; the active beat and every payoff beat are committed at every viewport, the others at %s" % [SPEC.IMPACT_OFFSET_SECONDS, SPEC.BEAT_VIEWPORT],
		"viewports": viewports,
		"weapons": weapons,
		"runs": _runs,
		"coverage": {
			"combinations": SPEC.weapon_ids().size() * SPEC.MODE_IDS.size() * SPEC.VIEWPORT_IDS.size(),
			"expected_frames": SPEC.expected_entries().size(),
			"written_frames": _captures.size(),
		},
		"captures": _captures,
	}


# --- helpers ------------------------------------------------------------------


func _read(viewport: SubViewport, label: String) -> Image:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_errors.append("empty render for %s" % label)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _pair(value: Vector2) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


static func _rect(rect: Rect2) -> Array:
	return [snappedf(rect.position.x, 0.1), snappedf(rect.position.y, 0.1), snappedf(rect.size.x, 0.1), snappedf(rect.size.y, 0.1)]
