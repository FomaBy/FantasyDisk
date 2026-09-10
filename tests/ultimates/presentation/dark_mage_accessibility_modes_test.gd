extends SceneTree

## FAN-3946: the Dark Mage trio's production reduced-motion and
## photosensitivity-safe presentation, exercised through the real runtime path.
##
## Every cell persists one option combination to `user://settings.cfg`, boots
## `scenes/Main.tscn` (which loads and publishes the snapshot exactly as a real
## start does), starts the shipped arena with a real Player equipped with the
## weapon and shipped Enemy hazards, casts through `Player.activate_ultimate()`
## and samples every process frame until the cast ends: the mounted authored
## scene, its Timeline, the tracked flipbook transforms, the backdrop alpha
## history, Engine.time_scale, the camera offset and every ordinary enemy hit
## flash that spawns (`combat_feedback_flashes`). Cleanup is asserted after the
## controller releases the cast. The caller's settings.cfg is restored.
##
## Headless (state, timing, victim flashes and scene evidence):
##     python3 tools/godot_gate.py --headless --path . --fixed-fps 60 \
##       --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd
## Windowed (adds real time-scale, camera and framebuffer luminance evidence):
##     FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=180 \
##       python3 tools/godot_gate.py --path . --windowed \
##       --fixed-fps 60 \
##       --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd
## `DARK_MAGE_ACCESSIBILITY_REPORT=<path>` writes every cell's sampled metrics
## as JSON for the class runtime report.
##
## Each windowed `frame_post_draw` wait has an independent, time-scale-proof
## deadline. A missed draw therefore reports its cell/stage/renderer and runs
## ordinary cleanup instead of leaving the test suspended until the gate's
## process watchdog. The documented 180-second gate bound is a second,
## process-level diagnostic only; it is lower than the default and never
## substitutes for the in-test cleanup-capable deadline.
##
## One test-side write exists: headless Godot owns no display, so the shared
## presentation runtime would fall back to its no-scene mode; the host's
## `_presentation_headless_mode` is forced to 0 there so the same authored scene
## a real display mounts is mounted headless. A windowed run makes no such write.

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const ACCESSIBILITY := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const DRIVER_SCRIPT_PATH := "res://scenes/vfx/ultimates/dark_mage/dark_mage_ultimate_v2_driver.gd"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/manifest.json"
const SAVE_PATH := "user://settings.cfg"
const CLASS_ID := "dark_mage"
const WEAPON_IDS := ["dark_book", "cursed_skull", "dark_wand"]
const MODES := [
	{"id": "normal", "reduced_motion": false, "photosensitivity_safe": false},
	{"id": "reduced_motion", "reduced_motion": true, "photosensitivity_safe": false},
	{"id": "photosensitivity_safe", "reduced_motion": false, "photosensitivity_safe": true},
	{"id": "combined", "reduced_motion": true, "photosensitivity_safe": true},
]
const TRACKED_NODES := {
	"dark_book": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
	"cursed_skull": ["CursedCrown", "SoulOrbitLeft", "SoulOrbitRight"],
	"dark_wand": ["VanishingThread", "ThreadEchoNear", "ThreadEchoFar"],
}
const RUN_SEED := 3946
const SETTLE_FRAMES := 8
const HAZARD_COUNT := 8
const HAZARD_HEALTH := 100000.0
const HAZARD_RING_RADII := [170.0, 240.0]
const HAZARD_PARKING := Vector2(6000.0, 6000.0)
const CAST_CAP_SECONDS := 8.0
## Phase boundaries may land one process frame late; two frames of slack at 60 fps.
const PHASE_TOLERANCE := 2.5 / 60.0
const FLASH_GROUP := "combat_feedback_flashes"
const HIT_FLASH_TEXTURE_SIZE := 128.0
## `impact_flash.png` is a soft radial glow drawn at 0.40 alpha; only its inner
## footprint (alpha >= 0.25, measured at 0.30 of the texture box) adds 10% or
## more luminance, which is what WCAG counts as flash area.
const HIT_FLASH_FOOTPRINT_RATIO := 0.30
## WCAG 2.3.1 general flash threshold and the repeating-flash coverage ceiling
## the visual-direction contract enforces on declarations.
const MAX_FLASH_EVENTS_PER_SECOND := 3
const MAX_FLASH_COVERAGE_RATIO := 0.25
## Photosensitivity-safe backdrop bound per process frame (the driver ramps at
## 0.24 alpha/s, so 0.02 leaves headroom for a late frame without admitting a step).
const PHOTOSAFE_MAX_BACKDROP_STEP := 0.02
const PHOTOSAFE_MAX_BACKDROP_ALPHA := 0.125
const PHOTOSAFE_FLIPBOOK_ALPHA := 0.6
const PHOTOSAFE_IMPACT_ALPHA := 0.6
const LUMINANCE_STRIDE := 8
const FRAMEBUFFER_WAIT_DEADLINE_SECONDS := 2.0
const WINDOWED_GATE_COMMAND := "FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=180 python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd"


## `frame_post_draw` can stop arriving while SceneTree keeps processing. Race
## it with a process-always, ignore-time-scale timer so the caller regains
## control, records a diagnostic, and performs ordinary cleanup.
class FramePostDrawDeadline extends RefCounted:
	signal settled(drew_frame: bool)

	var _settled := false
	var _drew_frame := false

	func await_frame(tree: SceneTree, timeout_seconds: float) -> bool:
		var timeout: SceneTreeTimer = tree.create_timer(timeout_seconds, true, false, true)
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw, CONNECT_ONE_SHOT)
		timeout.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
		await settled
		if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
			RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
		if timeout.timeout.is_connected(_on_timeout):
			timeout.timeout.disconnect(_on_timeout)
		return _drew_frame

	func _on_frame_post_draw() -> void:
		_finish(true)

	func _on_timeout() -> void:
		_finish(false)

	func _finish(drew_frame: bool) -> void:
		if _settled:
			return
		_settled = true
		_drew_frame = drew_frame
		settled.emit(drew_frame)

var _errors: Array[String] = []
var _records: Array = []
var _manifest_timing := {}
var _headless := false
var _progress_events: Array[Dictionary] = []
var _diagnostics: Array[Dictionary] = []
var _run_started_msec := 0


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_run_started_msec = Time.get_ticks_msec()
	_progress("run", "started", {"command": WINDOWED_GATE_COMMAND})
	seed(RUN_SEED)
	var manifest := _load_json(MANIFEST_PATH)
	for raw_weapon in manifest.get("weapons", []) as Array:
		var weapon := raw_weapon as Dictionary
		_manifest_timing[str(weapon.get("weapon_id", ""))] = weapon.get("timing_seconds", {})
	var backup := _backup_settings()
	for raw_mode in MODES:
		for weapon_id in WEAPON_IDS:
			await _run_cell(str(weapon_id), raw_mode as Dictionary)
	_restore_settings(backup)
	_progress("run", "settings_restored", {"completed_cells": _records.size(), "errors": _errors.size()})
	_write_report()
	if _errors.is_empty():
		print("dark_mage_accessibility_modes_test: PASS (%d cells, %s)" % [_records.size(), "headless" if _headless else "windowed"])
		quit(0)
		return
	for error in _errors:
		push_error("dark_mage_accessibility_modes_test: %s" % error)
	quit(1)


func _run_cell(weapon_id: String, mode: Dictionary) -> void:
	var context := "%s/%s" % [weapon_id, str(mode["id"])]
	var reduced := bool(mode["reduced_motion"])
	var photosafe := bool(mode["photosensitivity_safe"])
	_progress(context, "cell_started", {"reduced_motion": reduced, "photosensitivity_safe": photosafe})
	_persist(reduced, photosafe)

	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var published := ACCESSIBILITY.read_snapshot(root)
	_progress(context, "main_snapshot_published")
	_check(bool(published[ACCESSIBILITY.REDUCED_MOTION_KEY]) == reduced
		and bool(published[ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY]) == photosafe,
		"%s: Main must publish the persisted settings.cfg snapshot on the root" % context)
	var run_rng := main.get("rng") as RandomNumberGenerator
	if run_rng != null:
		run_rng.seed = RUN_SEED
	main.set("selected_character_id", CLASS_ID)
	main.set("selected_weapon_id", weapon_id)
	main.call("_start_combat", false, "battle")
	var player := main.get("current_player") as Node2D
	if player == null or str(player.get("weapon_id")) != weapon_id:
		_check(false, "%s: the shipped arena must produce a live Player equipped with %s" % [context, weapon_id])
		await _teardown(main)
		return
	_freeze_player_attacks(player)
	for _frame in SETTLE_FRAMES:
		await process_frame
	_freeze_player_attacks(player)
	var hazards := await _prepare_hazards(main, player, HAZARD_COUNT)
	_progress(context, "hazards_prepared", {"hazards": hazards.size()})
	_check(hazards.size() == HAZARD_COUNT, "%s: placed %d of %d shipped Enemy hazards" % [context, hazards.size(), HAZARD_COUNT])
	var host := PlayerHost.for_player(player)
	if _headless:
		host.set("_presentation_headless_mode", 0)
	var camera := player.get_viewport().get_camera_2d()
	var camera_offset_before := camera.offset if camera != null else Vector2.ZERO
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var sfx_before := AudioServer.get_bus_volume_db(sfx_bus) if sfx_bus != -1 else 0.0
	var time_scale_before := Engine.time_scale

	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "%s: Player.activate_ultimate() must start the cast" % context)
	_progress(context, "ultimate_activated")
	var controller = host.controller()
	if not controller.is_active():
		_check(false, "%s: the generic controller must own a live activation" % context)
		await _teardown(main)
		return
	var effect := _spawned_effect(controller)
	var scene := _presentation_scene(main)
	_check(scene != null, "%s: the production host must mount the authored Dark Mage scene" % context)
	if scene == null or effect == null:
		PlayerHost.reset(player)
		await _teardown(main)
		return

	_progress(context, "cast_sampling_started")
	var observed := await _sample_cast(context, main, player, scene, effect, hazards, camera, camera_offset_before, controller)
	observed["weapon_id"] = weapon_id
	observed["mode"] = str(mode["id"])
	observed["reduced_motion"] = reduced
	observed["photosensitivity_safe"] = photosafe
	observed["display"] = "headless" if _headless else "windowed"
	observed["hazards"] = hazards.size()
	_records.append(observed)
	if bool(observed.get("framebuffer_wait_timed_out", false)):
		_progress(context, "cell_failed_closed_after_framebuffer_timeout", observed.get("framebuffer_wait_diagnostic", {}) as Dictionary)
	else:
		_assert_cell(context, weapon_id, reduced, photosafe, hazards.size(), observed)
		_progress(context, "cell_assertions_complete")

	if controller.is_active():
		PlayerHost.reset(player)
	await process_frame
	await process_frame
	_check(_presentation_scene(main) == null, "%s: the authored scene must be released after the cast" % context)
	_check(root.find_child("BackdropTreatment", true, false) == null, "%s: the backdrop must not survive the cast" % context)
	_check(root.find_child("VictimImpact*", true, false) == null, "%s: victim bursts must not survive the cast" % context)
	_check(is_equal_approx(Engine.time_scale, time_scale_before), "%s: Engine.time_scale must be restored (%.3f)" % [context, Engine.time_scale])
	if sfx_bus != -1:
		_check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), sfx_before), "%s: the SFX bus must be restored" % context)
	if camera != null and is_instance_valid(camera):
		_check(camera.offset.is_equal_approx(camera_offset_before), "%s: the camera offset must be restored" % context)
	await _teardown(main)
	_progress(context, "cell_cleanup_complete", {"framebuffer_wait_timed_out": bool(observed.get("framebuffer_wait_timed_out", false))})


func _sample_cast(context: String, main: Node, player: Node2D, scene: Node2D, effect: Node,
		hazards: Array[Node2D], camera: Camera2D, camera_offset_before: Vector2, controller) -> Dictionary:
	var timing: Dictionary = _manifest_timing.get(scene.get("weapon_id"), {})
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	var tracked: Array = TRACKED_NODES.get(str(scene.get("weapon_id")), [])
	var previous_transforms := {}
	var max_position_step := 0.0
	var max_scale_step := 0.0
	var max_rotation_step := 0.0
	var phase_first_seen := {}
	var timeline_at_phase := {}
	var timeline_animation := ""
	var min_time_scale := INF
	var max_camera_delta := 0.0
	var max_flipbook_alpha := 0.0
	var max_backdrop_alpha := 0.0
	var backdrop_max_step := 0.0
	var backdrop_alpha_at_phase := {}
	var final_state := {}
	var victim_state := {}
	var seen_ticks := {}
	var flash_events: Array = []
	var luminance_samples: Array = []
	var previous_luminance := PackedFloat32Array()
	var max_changed_ratio := 0.0
	var scene_released_at := -1.0
	var elapsed := 0.0
	var frame := 0
	var viewport := player.get_viewport()
	var framebuffer_wait_count := 0
	var max_framebuffer_wait_msec := 0
	var framebuffer_wait_diagnostic: Dictionary = {}
	while elapsed < CAST_CAP_SECONDS and controller.is_active():
		await process_frame
		## The process delta is scaled by the hitstop dip; the host feeds the
		## presentation `delta / Engine.time_scale`, so the phase clock here is
		## measured on the same real-time basis.
		elapsed += get_root().get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		frame += 1
		if is_instance_valid(scene):
			var state := scene.call("presence_state_for_tests") as Dictionary
			final_state = state
			timeline_animation = str(state.get("timeline_animation", ""))
			var phase := str(scene.call("visible_phase_name"))
			if not phase.is_empty() and not phase_first_seen.has(phase):
				phase_first_seen[phase] = elapsed
				timeline_at_phase[phase] = timeline.current_animation_position if timeline != null else -1.0
				backdrop_alpha_at_phase[phase] = float(state.get("backdrop_alpha", 0.0))
			max_backdrop_alpha = maxf(max_backdrop_alpha, float(state.get("backdrop_alpha", 0.0)))
			backdrop_max_step = maxf(backdrop_max_step, float(state.get("backdrop_max_alpha_step", 0.0)))
			for node_name in tracked:
				var sprite := scene.get_node_or_null(str(node_name)) as AnimatedSprite2D
				if sprite == null:
					continue
				max_flipbook_alpha = maxf(max_flipbook_alpha, sprite.self_modulate.a * sprite.modulate.a)
				var current := {"position": sprite.position, "scale": sprite.scale, "rotation": sprite.rotation}
				if previous_transforms.has(node_name):
					var before: Dictionary = previous_transforms[node_name]
					max_position_step = maxf(max_position_step, (current["position"] as Vector2).distance_to(before["position"]))
					max_scale_step = maxf(max_scale_step, ((current["scale"] as Vector2) - (before["scale"] as Vector2)).length())
					max_rotation_step = maxf(max_rotation_step, absf(float(current["rotation"]) - float(before["rotation"])))
				previous_transforms[node_name] = current
		elif scene_released_at < 0.0:
			scene_released_at = elapsed
		if is_instance_valid(effect) and effect.has_method("victim_presentation_state_for_tests"):
			var current_victim_state := effect.call("victim_presentation_state_for_tests") as Dictionary
			if not current_victim_state.is_empty():
				victim_state = current_victim_state
		min_time_scale = minf(min_time_scale, Engine.time_scale)
		if camera != null and is_instance_valid(camera):
			max_camera_delta = maxf(max_camera_delta, camera.offset.distance_to(camera_offset_before))
		var event := _new_flash_event(seen_ticks, viewport, camera)
		if int(event["count"]) > 0:
			event["time"] = snappedf(elapsed, 0.001)
			flash_events.append(event)
		if not _headless and frame % 2 == 0:
			var framebuffer_wait := await _await_framebuffer_draw(context, frame, elapsed)
			framebuffer_wait_count += 1
			max_framebuffer_wait_msec = maxi(max_framebuffer_wait_msec, int(framebuffer_wait["waited_wall_msec"]))
			if not bool(framebuffer_wait["drew_frame"]):
				framebuffer_wait_diagnostic = framebuffer_wait
				break
			var luminance := _sample_luminance(viewport)
			var changed := _changed_ratio(previous_luminance, luminance)
			max_changed_ratio = maxf(max_changed_ratio, changed)
			previous_luminance = luminance
			luminance_samples.append({
				"time": snappedf(elapsed, 0.001),
				"luminance": snappedf(_mean(luminance), 0.0001),
				"changed_ratio": snappedf(changed, 0.0001),
			})
	var window := _max_flash_events_per_second(flash_events)
	var coverage := 0.0
	var flashes_total := 0
	for event in flash_events:
		coverage = maxf(coverage, float(event["coverage"]))
		flashes_total += int(event["count"])
	var max_luminance_step := 0.0
	for index in range(1, luminance_samples.size()):
		max_luminance_step = maxf(max_luminance_step, absf(float(luminance_samples[index]["luminance"]) - float(luminance_samples[index - 1]["luminance"])))
	return {
		"cast_seconds": snappedf(elapsed, 0.001),
		"frames": frame,
		"declared_timing": timing,
		"phase_first_seen": _snapped(phase_first_seen),
		"timeline_position_at_phase": _snapped(timeline_at_phase),
		"timeline_animation": timeline_animation,
		"scene_released_at": snappedf(scene_released_at, 0.001),
		"max_position_step_px": snappedf(max_position_step, 0.001),
		"max_scale_step": snappedf(max_scale_step, 0.0001),
		"max_rotation_step": snappedf(max_rotation_step, 0.0001),
		"max_flipbook_alpha": snappedf(max_flipbook_alpha, 0.001),
		"backdrop_alpha_at_phase": _snapped(backdrop_alpha_at_phase),
		"max_backdrop_alpha": snappedf(max_backdrop_alpha, 0.001),
		"backdrop_max_alpha_step": snappedf(backdrop_max_step, 0.001),
		"camera_shake_triggered": bool(final_state.get("camera_shake_triggered", false)),
		"hitstop_ms": float(final_state.get("hitstop_ms", 0.0)),
		"sfx_ducked": bool(final_state.get("sfx_ducked", false)),
		"state_reduced_motion": bool(final_state.get("reduced_motion", false)),
		"state_photosensitivity_safe": bool(final_state.get("photosensitivity_safe", false)),
		"min_time_scale": snappedf(min_time_scale, 0.001),
		"max_camera_offset_px": snappedf(max_camera_delta, 0.001),
		"victim_extra_hit_flash": bool(victim_state.get("extra_hit_flash", true)),
		"victim_impact_alpha": snappedf(float(victim_state.get("impact_alpha", 1.0)), 0.001),
		"victim_bursts": int((victim_state.get("snapshot", {}) as Dictionary).get("victims", 0)),
		"flash_events": flash_events,
		"flash_ticks_total": flashes_total,
		"max_flash_events_per_second": window,
		"max_flash_coverage_ratio": snappedf(coverage, 0.0001),
		"luminance_samples": luminance_samples.size(),
		"max_luminance_step": snappedf(max_luminance_step, 0.0001),
		"max_changed_pixel_ratio": snappedf(max_changed_ratio, 0.0001),
		"luminance_series": luminance_samples,
		"framebuffer_wait_count": framebuffer_wait_count,
		"max_framebuffer_wait_msec": max_framebuffer_wait_msec,
		"framebuffer_wait_timed_out": not framebuffer_wait_diagnostic.is_empty(),
		"framebuffer_wait_diagnostic": framebuffer_wait_diagnostic,
	}


func _await_framebuffer_draw(context: String, frame: int, cast_elapsed: float) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	_progress(context, "framebuffer_wait_begin", {
		"frame": frame,
		"cast_elapsed_seconds": snappedf(cast_elapsed, 0.001),
		"deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
	})
	var deadline := FramePostDrawDeadline.new()
	var drew_frame: bool = await deadline.await_frame(self, FRAMEBUFFER_WAIT_DEADLINE_SECONDS)
	var waited_msec := Time.get_ticks_msec() - started_msec
	var result := _runtime_metadata()
	result.merge({
		"context": context,
		"stage": "framebuffer_wait",
		"frame": frame,
		"cast_elapsed_seconds": snappedf(cast_elapsed, 0.001),
		"deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
		"waited_wall_msec": waited_msec,
		"drew_frame": drew_frame,
		"command": WINDOWED_GATE_COMMAND,
	}, true)
	if drew_frame:
		return result
	result["kind"] = "framebuffer_wait_timeout"
	_diagnostics.append(result.duplicate(true))
	_progress(context, "framebuffer_wait_timeout", result)
	_check(false, "%s: framebuffer wait timed out after %dms at frame %d (display=%s renderer=%s; command: %s)" % [
		context, waited_msec, frame, str(result["display_server"]), str(result["renderer"]), WINDOWED_GATE_COMMAND,
	])
	return result


func _runtime_metadata() -> Dictionary:
	return {
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"wall_elapsed_msec": Time.get_ticks_msec() - _run_started_msec,
	}


func _progress(context: String, stage: String, details: Dictionary = {}) -> void:
	var event := _runtime_metadata()
	event["context"] = context
	event["stage"] = stage
	for key in details:
		event[key] = details[key]
	_progress_events.append(event)
	print("dark_mage_accessibility_modes_test: progress %s" % JSON.stringify(event))


func _assert_cell(context: String, weapon_id: String, reduced: bool, photosafe: bool, hazards: int, observed: Dictionary) -> void:
	var timing: Dictionary = _manifest_timing.get(weapon_id, {})
	var first_seen: Dictionary = observed["phase_first_seen"]
	var at_phase: Dictionary = observed["timeline_position_at_phase"]
	for phase in ["release", "active", "recovery"]:
		var declared := float(timing.get(phase, -1.0))
		var seen := float(first_seen.get(phase, -1.0))
		_check(seen >= 0.0 and absf(seen - declared) <= PHASE_TOLERANCE,
			"%s: %s phase must start at the declared %.2fs (seen %.3f)" % [context, phase, declared, seen])
		## The authored AnimationPlayer runs on scaled time, so after a real
		## hitstop it trails the real-time phase clock by the dip's share of the
		## freeze (60% of 80-150 ms). Reduced motion has no dip and no drift.
		var hitstop_drift := float(observed["hitstop_ms"]) / 1000.0 * 0.6
		var timeline_position := float(at_phase.get(phase, -1.0))
		_check(timeline_position >= 0.0 and absf(timeline_position - declared) <= PHASE_TOLERANCE + hitstop_drift,
			"%s: the Timeline must sit at the declared %s beat in this mode (%.3f)" % [context, phase, timeline_position])
	_check(bool(observed["state_reduced_motion"]) == reduced and bool(observed["state_photosensitivity_safe"]) == photosafe,
		"%s: the driver must report the modes it actually applied" % context)
	_check(bool(observed["sfx_ducked"]), "%s: SFX ducking is not motion and must play in every mode" % context)
	_check(int(observed["victim_bursts"]) >= hazards, "%s: every hazard must receive its victim burst (%d of %d)" % [context, int(observed["victim_bursts"]), hazards])
	_check(int(observed["flash_ticks_total"]) >= hazards,
		"%s: ordinary enemy hit flashes must survive the mode (%d ticks for %d hazards)" % [context, int(observed["flash_ticks_total"]), hazards])
	if reduced:
		_check(str(observed["timeline_animation"]) == "ultimate_reduced_motion", "%s: the authored reduced-motion variant must be bound" % context)
		_check(not bool(observed["camera_shake_triggered"]) and float(observed["hitstop_ms"]) == 0.0,
			"%s: reduced motion must suppress camera shake and the time-scale dip" % context)
		_check(float(observed["min_time_scale"]) >= 0.999, "%s: Engine.time_scale must never dip (%.3f)" % [context, float(observed["min_time_scale"])])
		_check(float(observed["max_camera_offset_px"]) == 0.0, "%s: the camera must never move (%.3f px)" % [context, float(observed["max_camera_offset_px"])])
		_check(float(observed["max_position_step_px"]) == 0.0 and float(observed["max_rotation_step"]) == 0.0,
			"%s: reduced motion must hold every flipbook in place (%.3f px, %.4f rad per frame)" % [context, float(observed["max_position_step_px"]), float(observed["max_rotation_step"])])
		_check(float(observed["max_scale_step"]) <= 0.01,
			"%s: reduced motion allows only the specified slow contraction (%.4f per frame)" % [context, float(observed["max_scale_step"])])
	else:
		_check(str(observed["timeline_animation"]) == "ultimate", "%s: the ordinary timeline must play" % context)
		_check(bool(observed["camera_shake_triggered"]) and float(observed["hitstop_ms"]) >= 80.0 and float(observed["hitstop_ms"]) <= 150.0,
			"%s: ordinary presence must keep shake and the 80-150ms hitstop" % context)
		_check(float(observed["max_position_step_px"]) > 0.0, "%s: the ordinary timeline must actually travel" % context)
		if not _headless:
			_check(float(observed["min_time_scale"]) <= 0.41, "%s: the windowed hitstop must dip Engine.time_scale (%.3f)" % [context, float(observed["min_time_scale"])])
			_check(float(observed["max_camera_offset_px"]) > 0.0, "%s: the windowed shake must move the camera" % context)
	if photosafe:
		_check(float(observed["backdrop_max_alpha_step"]) <= PHOTOSAFE_MAX_BACKDROP_STEP,
			"%s: the backdrop must ramp, never step (%.3f per frame)" % [context, float(observed["backdrop_max_alpha_step"])])
		_check(float(observed["max_backdrop_alpha"]) <= PHOTOSAFE_MAX_BACKDROP_ALPHA,
			"%s: the backdrop must stay at the low veil (%.3f)" % [context, float(observed["max_backdrop_alpha"])])
		_check(float(observed["max_flipbook_alpha"]) <= PHOTOSAFE_FLIPBOOK_ALPHA + 0.001,
			"%s: flipbook luminance must stay capped (%.3f)" % [context, float(observed["max_flipbook_alpha"])])
		_check(not bool(observed["victim_extra_hit_flash"]) and absf(float(observed["victim_impact_alpha"]) - PHOTOSAFE_IMPACT_ALPHA) < 0.001,
			"%s: the victim burst must drop its duplicate flash and play dimmed" % context)
		_check(int(observed["max_flash_events_per_second"]) <= MAX_FLASH_EVENTS_PER_SECOND,
			"%s: aggregate victim flashes must stay within %d events per second (%d)" % [context, MAX_FLASH_EVENTS_PER_SECOND, int(observed["max_flash_events_per_second"])])
		_check(float(observed["max_flash_coverage_ratio"]) <= MAX_FLASH_COVERAGE_RATIO,
			"%s: aggregate victim flash coverage must stay under %.2f (%.4f)" % [context, MAX_FLASH_COVERAGE_RATIO, float(observed["max_flash_coverage_ratio"])])
		if not _headless:
			_check(float(observed["max_changed_pixel_ratio"]) <= MAX_FLASH_COVERAGE_RATIO,
				"%s: no frame pair may change 10%% luminance over more than %.2f of the screen (%.4f)" % [context, MAX_FLASH_COVERAGE_RATIO, float(observed["max_changed_pixel_ratio"])])
	else:
		_check(float(observed["backdrop_max_alpha_step"]) >= 0.14 or reduced, "%s: the ordinary backdrop must keep its authored steps" % context)
		_check(bool(observed["victim_extra_hit_flash"]) and float(observed["victim_impact_alpha"]) == 1.0,
			"%s: the ordinary victim burst must be unchanged" % context)
		_check(float(observed["max_flipbook_alpha"]) > PHOTOSAFE_FLIPBOOK_ALPHA, "%s: ordinary flipbooks must reach full luminance" % context)
	if reduced and not photosafe:
		_check(float(observed["max_backdrop_alpha"]) >= 0.29, "%s: reduced motion keeps the ordinary backdrop levels, only eased" % context)
		_check(float(observed["backdrop_max_alpha_step"]) <= 0.05, "%s: reduced motion must ease every backdrop beat (%.3f)" % [context, float(observed["backdrop_max_alpha_step"])])


## Ticks are the enemy's own `_show_hit_flash` sprites; a new instance is one
## ordinary victim flash. Ticks outside the camera view are not visible and do
## not count toward coverage or the per-second rate.
func _new_flash_event(seen: Dictionary, viewport: Viewport, camera: Camera2D) -> Dictionary:
	var count := 0
	var area := 0.0
	var visible_rect := viewport.get_visible_rect()
	var zoom := camera.zoom if camera != null and is_instance_valid(camera) else Vector2.ONE
	var world_size := visible_rect.size / zoom
	var center := camera.get_screen_center_position() if camera != null and is_instance_valid(camera) else world_size * 0.5
	var world_rect := Rect2(center - world_size * 0.5, world_size)
	for node in get_nodes_in_group(FLASH_GROUP):
		var tick := node as Sprite2D
		if tick == null or seen.has(tick.get_instance_id()):
			continue
		seen[tick.get_instance_id()] = true
		if not world_rect.has_point(tick.global_position):
			continue
		count += 1
		var reach := HIT_FLASH_TEXTURE_SIZE * maxf(tick.scale.x, tick.scale.y)
		area += reach * reach * zoom.x * zoom.y * HIT_FLASH_FOOTPRINT_RATIO
	return {"count": count, "coverage": snappedf(area / (visible_rect.size.x * visible_rect.size.y), 0.0001)}


## Same-frame ticks are one flash event; the rate is the largest number of
## events inside any rolling one-second window.
func _max_flash_events_per_second(events: Array) -> int:
	var best := 0
	for start in events.size():
		var count := 0
		for index in range(start, events.size()):
			if float(events[index]["time"]) - float(events[start]["time"]) <= 1.0:
				count += 1
		best = maxi(best, count)
	return best


## Relative luminance of a strided framebuffer sample, 0..1 per pixel.
func _sample_luminance(viewport: Viewport) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var image := viewport.get_texture().get_image()
	if image == null:
		return result
	image.convert(Image.FORMAT_RGB8)
	var size := image.get_size()
	var bytes := image.get_data()
	for y in range(0, size.y, LUMINANCE_STRIDE):
		for x in range(0, size.x, LUMINANCE_STRIDE):
			var offset := (y * size.x + x) * 3
			result.append((0.2126 * float(bytes[offset]) + 0.7152 * float(bytes[offset + 1]) + 0.0722 * float(bytes[offset + 2])) / 255.0)
	return result


## Fraction of sampled pixels whose luminance moved by 10% or more between two
## consecutive samples: the screen area taking part in a flash-sized change.
func _changed_ratio(before: PackedFloat32Array, after: PackedFloat32Array) -> float:
	if before.size() != after.size() or after.is_empty():
		return 0.0
	var changed := 0
	for index in after.size():
		if absf(after[index] - before[index]) >= 0.1:
			changed += 1
	return float(changed) / float(after.size())


func _mean(values: PackedFloat32Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(maxi(values.size(), 1))


## Shipped enemies become the hazards, spawned through the same director path
## the waves use. Extra wave spawns are parked out of frame, not freed.
func _prepare_hazards(main: Node, player: Node2D, wanted: int) -> Array[Node2D]:
	main.set("spawn_cooldown", 1.0e9)
	var combat: Object = main.get("combat")
	var live := _live_enemies()
	var guard := 0
	while live.size() < wanted and guard < wanted * 3:
		var angle := float(guard) * TAU / 8.0
		var spot := player.global_position + Vector2(float(HAZARD_RING_RADII[guard % HAZARD_RING_RADII.size()]), 0.0).rotated(angle)
		if combat.call("_spawn_random_enemy", main.get("enemy_scene"), spot, true, 0.0) == null:
			break
		guard += 1
		live = _live_enemies()
	await process_frame
	live = _live_enemies()
	var placed: Array[Node2D] = []
	for index in live.size():
		var enemy := live[index]
		enemy.set("health", HAZARD_HEALTH)
		enemy.set("max_health", HAZARD_HEALTH)
		if index >= wanted:
			enemy.global_position = HAZARD_PARKING
			continue
		var ring := index / 8
		var slot := index % 8
		var radius := float(HAZARD_RING_RADII[ring % HAZARD_RING_RADII.size()])
		enemy.global_position = player.global_position + Vector2(radius, 0.0).rotated(float(slot) * TAU / 8.0 + 0.2 * float(ring))
		placed.append(enemy)
	await process_frame
	return placed


## The real Player and its equipped weapon auto-attack the hazards every weapon
## cycle, and the skull weapon leaves a ticking curse behind; those ordinary
## hits flash too and would drown the ultimate's own victim read. The Player's
## loops are frozen (as the mechanics live test does) and the weapon subtree
## is disabled from the first combat frame, while the UltimateHost child, its
## tweens, the camera, the enemies and the HUD keep running.
func _freeze_player_attacks(player: Node2D) -> void:
	player.set_process(false)
	player.set_physics_process(false)
	var weapon := player.get("equipped_weapon") as Node
	if weapon != null:
		weapon.process_mode = Node.PROCESS_MODE_DISABLED


func _live_enemies() -> Array[Node2D]:
	var live: Array[Node2D] = []
	for node in get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node):
			live.append(node as Node2D)
	return live


func _spawned_effect(controller) -> Node:
	var activation = controller.active_activation()
	if activation == null:
		return null
	var spawned: Array[Node] = activation.spawned_for_tests()
	return spawned[0] if not spawned.is_empty() else null


func _presentation_scene(main: Node) -> Node2D:
	for child in main.get_children():
		var script := child.get_script() as Script
		if script != null and script.resource_path == DRIVER_SCRIPT_PATH:
			return child as Node2D
	return null


func _teardown(main: Node) -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _persist(reduced: bool, photosafe: bool) -> void:
	var stored := GAME_SETTINGS.DEFAULTS.duplicate(true)
	stored[ACCESSIBILITY.REDUCED_MOTION_KEY] = reduced
	stored[ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY] = photosafe
	GAME_SETTINGS.save_settings(stored)


func _backup_settings() -> Dictionary:
	var backup := {"exists": FileAccess.file_exists(SAVE_PATH), "bytes": PackedByteArray()}
	if bool(backup["exists"]):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			backup["bytes"] = file.get_buffer(file.get_length())
			file.close()
	return backup


func _restore_settings(backup: Dictionary) -> void:
	if bool(backup.get("exists", false)):
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(backup.get("bytes", PackedByteArray()) as PackedByteArray)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _write_report() -> void:
	var path := OS.get_environment("DARK_MAGE_ACCESSIBILITY_REPORT").strip_edges()
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write report to %s" % path)
		return
	file.store_string(JSON.stringify({
		"seed": RUN_SEED,
		"display": "headless" if _headless else "windowed",
		"godot": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_current_rendering_method(),
		"windowed_gate_command": WINDOWED_GATE_COMMAND,
		"framebuffer_wait_deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
		"hazards": HAZARD_COUNT,
		"progress": _progress_events,
		"diagnostics": _diagnostics,
		"cells": _records,
	}, "  "))
	file.close()


func _snapped(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values:
		result[key] = snappedf(float(values[key]), 0.001)
	return result


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
