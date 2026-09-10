extends SceneTree

## FAN-3938 windowed certification renderer.
##
## Every saved PNG is a native framebuffer readback from a real `Main` run. The
## runner persists the shipped Dark Mage accessibility preferences before Main
## boots, then starts combat with the actual Player, Combat HUD, director-spawned
## Enemy hazards and Player.activate_ultimate() path. It never draws a stand-in
## player, HUD, enemy, hazard, or ultimate scene.
##
## The 144 artifacts are intentionally individual native images rather than a
## contact sheet: each of the 48 weapon/mode/viewport cells has one native
## image for release, active, and recovery. A 1152x648 image therefore contains
## one unscaled gameplay capture and cannot bleed into another cell or phase.
##
## Required invocation (the pre-artifact source is pinned explicitly):
##
##   FSD_GODOT_EXCLUSIVE=1 DARK_MAGE_CERT_SOURCE_REF=<ref> \
##     DARK_MAGE_CERT_SOURCE_SHA=<sha> DARK_MAGE_CERT_SOURCE_TREE=<tree> \
##     python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
##       --script res://tests/ultimates/presentation/dark_mage_certification_live_capture.gd
##
## A headless renderer has no framebuffer and is deliberately a successful
## no-op. The paired integrity test validates saved evidence headlessly.

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const ACCESSIBILITY := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")

const CAPTURE_ID := "FAN-3938"
const CLASS_ID := "dark_mage"
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/manifest.json"
const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/dark_mage/certification_capture_manifest.json"
const OUTPUT_ROOT := "res://docs/design/reference-assets-lfs/ultimate-certification/dark_mage"
const DRIVER_SCRIPT_PATH := "res://scenes/vfx/ultimates/dark_mage/dark_mage_ultimate_v2_driver.gd"
const SETTINGS_PATH := "user://settings.cfg"

const CAPTURE_SEED := 393820260910
const SETTLE_FRAMES := 8
const FRAME_SECONDS := 1.0 / 60.0
const HAZARD_HEALTH := 100000.0
const NORMAL_HAZARDS := 8
const CROWDED_HAZARDS := 39
const HAZARD_RING_RADII := [170.0, 240.0, 310.0, 380.0]
const HAZARD_PARKING := Vector2(6000.0, 6000.0)
const CAPTURE_TIMEOUT_SECONDS := 5.0
## A fixed-FPS SceneTreeTimer advances simulated time, so it cannot bound a
## stalled native frame delivery. This deadline uses monotonic wall-clock time.
const FRAMEBUFFER_WAIT_DEADLINE_SECONDS := 2.0
const LUMINANCE_SAMPLE_STRIDE := 16
const STAGING_ROOT_PREFIX := "user://fan3938_dark_mage_capture_stage"
const RUN_REPORT_ENV := "DARK_MAGE_CERT_RUN_REPORT"
## Test-only seam used together with Godot's `--disable-render-loop` flag to
## prove that the listener returns through the watchdog and cleanup path.
const TEST_SUPPRESS_FORCE_DRAW_ENV := "DARK_MAGE_CERT_TEST_NO_FORCE_DRAW"
const WINDOWED_CAPTURE_COMMAND := "FSD_GODOT_EXCLUSIVE=1 DARK_MAGE_CERT_SOURCE_REF=<ref> DARK_MAGE_CERT_SOURCE_SHA=<sha> DARK_MAGE_CERT_SOURCE_TREE=<tree> python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/dark_mage_certification_live_capture.gd"

const WEAPON_IDS: Array[String] = ["dark_book", "cursed_skull", "dark_wand"]
const PHASE_IDS: Array[String] = ["release", "active", "recovery"]
const VIEWPORTS := [
	{"id": "1152x648", "size": Vector2i(1152, 648)},
	{"id": "1280x720", "size": Vector2i(1280, 720)},
	{"id": "1920x1080", "size": Vector2i(1920, 1080)},
	{"id": "2560x1440", "size": Vector2i(2560, 1440)},
]
## `crowded` is a real pressure layout, not a persisted preference. The other
## two boolean fields are written to user://settings.cfg before Main starts.
const MODES := [
	{
		"id": "normal",
		"reduced_motion": false,
		"photosensitivity_safe": false,
		"crowded": false,
		"intent": "Persisted production defaults with representative hazards.",
	},
	{
		"id": "crowded",
		"reduced_motion": false,
		"photosensitivity_safe": false,
		"crowded": true,
		"intent": "Persisted production defaults with 39 director-spawned Enemy hazards.",
	},
	{
		"id": "reduced_motion",
		"reduced_motion": true,
		"photosensitivity_safe": false,
		"crowded": false,
		"intent": "Persisted ultimate_reduced_motion production setting.",
	},
	{
		"id": "photosensitivity_safe",
		"reduced_motion": false,
		"photosensitivity_safe": true,
		"crowded": false,
		"intent": "Persisted ultimate_photosensitivity_safe production setting.",
	},
]

## Each requirement follows the authored alpha timeline at the declared named
## beat. The crown and wand echoes intentionally enter after release; requiring
## them before their authored reveal would falsely reject the shipped scene.
const REQUIRED_ARTWORK_BY_PHASE := {
	"dark_book": {
		"release": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
		"active": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
		"recovery": ["AbyssMirror", "ReflectionLeft", "ReflectionRight"],
	},
	"cursed_skull": {
		"release": ["CursedCrown"],
		"active": ["CursedCrown", "SoulOrbitLeft", "SoulOrbitRight"],
		"recovery": ["CursedCrown", "SoulOrbitLeft", "SoulOrbitRight"],
	},
	"dark_wand": {
		"release": ["VanishingThread"],
		"active": ["VanishingThread", "ThreadEchoNear"],
		"recovery": ["VanishingThread", "ThreadEchoNear", "ThreadEchoFar"],
	},
}

var _source := {}
var _weapons := {}
var _records: Array[Dictionary] = []
var _failures: Array[String] = []
var _staging_root := ""
var _staging_manifest_path := ""
var _published_root := ""
var _run_started_msec := 0
var _progress_events: Array[Dictionary] = []
var _diagnostics: Array[Dictionary] = []
var _settings_restored := false
var _window_restored := false
var _staging_cleaned := false
var _published := false
var _test_suppress_force_draw := false
var _main_cleanup_count := 0
var _player_reset_count := 0


## This local node mirrors the proven accessibility regression watchdog. The
## listener is armed before a draw is requested, and its process callback stays
## active even under fixed-FPS simulation so a missed native draw fails closed.
class FramePostDrawDeadline extends Node:
	signal settled

	var _settled := false
	var _drew_frame := false
	var _settled_by := ""
	var _deadline_msec := 0
	var _process_ticks := 0

	func await_frame(tree: SceneTree, timeout_seconds: float, request_draw: bool) -> bool:
		_deadline_msec = Time.get_ticks_msec() + ceili(timeout_seconds * 1000.0)
		process_mode = Node.PROCESS_MODE_ALWAYS
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw, CONNECT_ONE_SHOT)
		tree.root.add_child(self)
		set_process(true)
		if request_draw:
			RenderingServer.force_draw(false)
		if not _settled:
			await settled
		if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
			RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)
		queue_free()
		return _drew_frame

	func _on_frame_post_draw() -> void:
		_finish(true)

	func _process(_delta: float) -> void:
		_process_ticks += 1
		if Time.get_ticks_msec() >= _deadline_msec:
			_finish(false)

	func _finish(drew_frame: bool) -> void:
		if _settled:
			return
		_settled = true
		_drew_frame = drew_frame
		_settled_by = "frame_post_draw" if drew_frame else "wall_clock_watchdog"
		set_process(false)
		settled.emit()

	func settled_by() -> String:
		return _settled_by

	func process_ticks() -> int:
		return _process_ticks


func _initialize() -> void:
	_run_started_msec = Time.get_ticks_msec()
	_test_suppress_force_draw = OS.get_environment(TEST_SUPPRESS_FORCE_DRAW_ENV).strip_edges() == "1"
	_progress("run", "", "started", {
		"command": WINDOWED_CAPTURE_COMMAND,
		"framebuffer_wait_deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
		"test_suppress_force_draw": _test_suppress_force_draw,
	})
	if DisplayServer.get_name() == "headless":
		_progress("run", "", "skipped_headless")
		_write_run_report()
		print("FAN-3938 Dark Mage certification capture skipped (headless); windowed evidence is required.")
		quit(0)
		return
	_source = _source_from_environment()
	if _source.is_empty():
		_write_run_report()
		quit(1)
		return
	_weapons = _weapons_from_manifest()
	if _weapons.size() != WEAPON_IDS.size():
		_fail("class manifest must expose the three canonical Dark Mage weapons")
		_write_run_report()
		quit(1)
		return
	var settings_backup := _backup_settings()
	var window_size_backup := root.size
	var succeeded := await _capture_all()
	_restore_settings(settings_backup)
	_settings_restored = true
	await _restore_window_size(window_size_backup)
	_window_restored = true
	if not succeeded:
		_clear_staging()
		_write_run_report()
		_finish_failure()
		return
	_clear_staging()
	_write_run_report()
	print("FAN-3938 Dark Mage certification capture: PASS (%d native live captures)" % _records.size())
	quit(0)


func _capture_all() -> bool:
	var staging_result := _prepare_staging()
	if staging_result != OK:
		_fail("cannot create capture staging root: %s" % error_string(staging_result))
		return false
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		for raw_mode in MODES:
			var mode := raw_mode as Dictionary
			for weapon_id in WEAPON_IDS:
				var phase_records := await _capture_cell(viewport, mode, weapon_id)
				if phase_records.is_empty():
					return false
				_records.append_array(phase_records)
	var expected_captures := WEAPON_IDS.size() * MODES.size() * VIEWPORTS.size() * PHASE_IDS.size()
	if _records.size() != expected_captures:
		_fail("capture count is %d, expected %d" % [_records.size(), expected_captures])
		return false
	var manifest_result := _write_capture_manifest(_staging_manifest_path)
	if manifest_result != OK:
		_fail("could not stage capture manifest: %s" % error_string(manifest_result))
		return false
	var publish_result := _publish_staged_package()
	if publish_result != OK:
		_fail("could not publish staged capture package: %s" % error_string(publish_result))
		return false
	return true


func _capture_cell(viewport: Dictionary, mode: Dictionary, weapon_id: String) -> Array[Dictionary]:
	var viewport_id := str(viewport["id"])
	var mode_id := str(mode["id"])
	var size := viewport["size"] as Vector2i
	var context := "%s/%s/%s" % [weapon_id, mode_id, viewport_id]
	_progress(context, "", "cell_started", {"width": size.x, "height": size.y})
	var weapon := _weapons.get(weapon_id, {}) as Dictionary
	var timing := weapon.get("timing_seconds", {}) as Dictionary
	if timing.is_empty():
		_fail("%s has no timing declaration" % context)
		return []
	_persist_mode(mode)
	seed(_cell_seed(viewport_id, mode_id, weapon_id))
	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	if main == null:
		_fail("%s could not instantiate Main" % context)
		return []
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var published := ACCESSIBILITY.read_snapshot(root)
	if bool(published.get(ACCESSIBILITY.REDUCED_MOTION_KEY, false)) != bool(mode["reduced_motion"]) \
			or bool(published.get(ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY, false)) != bool(mode["photosensitivity_safe"]):
		_fail("%s Main did not publish the persisted accessibility snapshot" % context)
		await _dispose_main(main)
		return []
	var rng := main.get("rng") as RandomNumberGenerator
	if rng != null:
		rng.seed = _cell_seed(viewport_id, mode_id, weapon_id)
	main.set("selected_character_id", CLASS_ID)
	main.set("selected_weapon_id", weapon_id)
	main.call("_start_combat", false, "battle")
	for _frame in SETTLE_FRAMES:
		await process_frame
	await _apply_window_size(size)
	if root.size != size:
		_fail("%s window size is %s, expected %s" % [context, root.size, size])
		await _dispose_main(main)
		return []
	var player := main.get("current_player") as Node2D
	var hud_root := _combat_hud(main)
	if player == null or str(player.get("character_id")) != CLASS_ID or str(player.get("weapon_id")) != weapon_id:
		_fail("%s did not produce the configured live Dark Mage player" % context)
		await _abort_main(main, player)
		return []
	if hud_root == null or not hud_root.visible:
		_fail("%s did not produce the shipped CombatHudRoot" % context)
		await _abort_main(main, player)
		return []
	_freeze_player_attacks(player)
	var wanted_hazards := CROWDED_HAZARDS if bool(mode["crowded"]) else NORMAL_HAZARDS
	var hazards := await _prepare_hazards(main, player, wanted_hazards)
	if hazards.size() != wanted_hazards:
		_fail("%s placed %d of %d director-spawned Enemy hazards" % [context, hazards.size(), wanted_hazards])
		await _abort_main(main, player)
		return []
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	if not bool(player.call("activate_ultimate")):
		_fail("%s Player.activate_ultimate() did not start the production cast" % context)
		await _abort_main(main, player)
		return []
	var host = PlayerHost.for_player(player)
	var controller = host.controller() if host != null else null
	if controller == null or not controller.is_active():
		_fail("%s has no active UltimateController after Player activation" % context)
		await _abort_main(main, player)
		return []
	var observations := {}
	var elapsed := 0.0
	for phase_id in PHASE_IDS:
		var target := float(timing.get(phase_id, -1.0))
		if target <= 0.0:
			_fail("%s has an invalid %s beat" % [context, phase_id])
			await _abort_main(main, player)
			return []
		while elapsed < target and controller.is_active() and elapsed < CAPTURE_TIMEOUT_SECONDS:
			await process_frame
			elapsed += get_root().get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		if not controller.is_active():
			_fail("%s ended before its %s beat" % [context, phase_id])
			await _abort_main(main, player)
			return []
		var driver := _presentation_driver(main)
		if driver == null:
			_fail("%s did not mount the shipped Dark Mage presentation driver" % context)
			await _abort_main(main, player)
			return []
		var visual_state := driver.call("presence_state_for_tests") as Dictionary
		if str(driver.call("visible_phase_name")) != phase_id:
			_fail("%s reported phase %s at requested %s beat" % [context, str(driver.call("visible_phase_name")), phase_id])
			await _abort_main(main, player)
			return []
		if not _driver_mode_matches(visual_state, mode):
			_fail("%s driver state does not match Main's persisted mode snapshot" % context)
			await _abort_main(main, player)
			return []
		var artwork_nodes := _visible_required_artwork(driver, weapon_id, phase_id)
		if artwork_nodes.is_empty():
			_fail("%s lacks visible authored artwork at %s" % [context, phase_id])
			await _abort_main(main, player)
			return []
		if not _hud_and_hazards_visible(hud_root, hazards):
			_fail("%s lacks visible shipped HUD or Enemy hazard state at %s" % [context, phase_id])
			await _abort_main(main, player)
			return []
		var settle_draw := await _await_framebuffer_draw(context, phase_id, "settle_1")
		if not bool(settle_draw.get("drew_frame", false)):
			await _abort_main(main, player)
			return []
		var readback_draw := await _await_framebuffer_draw(context, phase_id, "readback_2")
		if not bool(readback_draw.get("drew_frame", false)):
			await _abort_main(main, player)
			return []
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != size:
			_fail("%s framebuffer at %s is not native %s" % [context, phase_id, size])
			await _abort_main(main, player)
			return []
		image.convert(Image.FORMAT_RGBA8)
		var variation := _luminance_variation(image)
		if variation < 0.04:
			_fail("%s framebuffer at %s is visually empty (variation %.3f)" % [context, phase_id, variation])
			await _abort_main(main, player)
			return []
		var observation := {
			"phase": phase_id,
			"requested_seconds": snappedf(target, 0.001),
			"observed_seconds": snappedf(elapsed, 0.001),
			"driver_phase": str(driver.call("visible_phase_name")),
			"timeline_animation": str(visual_state.get("timeline_animation", "")),
			"driver_reduced_motion": bool(visual_state.get("reduced_motion", false)),
			"driver_photosensitivity_safe": bool(visual_state.get("photosensitivity_safe", false)),
			"hud_visible": true,
			"enemy_hazards_visible": _visible_hazard_count(hazards),
			"artwork_visible": true,
			"visible_authored_nodes": artwork_nodes,
			"rgba_sha256": _image_sha256(image),
			"luminance_variation": snappedf(variation, 0.0001),
		}
		var output_path := _published_capture_path(weapon_id, mode_id, viewport_id, phase_id)
		var staged_path := _staged_capture_path(weapon_id, mode_id, viewport_id, phase_id)
		if image.save_png(ProjectSettings.globalize_path(staged_path)) != OK:
			_fail("%s could not stage %s native PNG" % [context, phase_id])
			await _abort_main(main, player)
			return []
		observation["path"] = output_path.trim_prefix("res://")
		observation["sha256"] = FileAccess.get_sha256(staged_path).to_lower()
		observation["lfs_object_id"] = "sha256:%s" % str(observation["sha256"])
		observations[phase_id] = observation
	if not _has_ultimate_impact(hazards):
		_fail("%s did not record a real ultimate impact on a director-spawned Enemy" % context)
		await _abort_main(main, player)
		return []
	await _abort_main(main, player)
	var records: Array[Dictionary] = []
	for phase_id in PHASE_IDS:
		var phase_observation := observations.get(phase_id, {}) as Dictionary
		if phase_observation.is_empty():
			_fail("%s did not retain its %s observation" % [context, phase_id])
			return []
		records.append({
			"id": "%s/%s/%s/%s" % [weapon_id, mode_id, viewport_id, phase_id],
			"weapon_id": weapon_id,
			"mode": mode_id,
			"viewport_id": viewport_id,
			"phase": phase_id,
			"width": size.x,
			"height": size.y,
			"path": str(phase_observation.get("path", "")),
			"sha256": str(phase_observation.get("sha256", "")),
			"lfs_object_id": str(phase_observation.get("lfs_object_id", "")),
			"scene_path": str(weapon.get("scene_path", "")),
			"representative_enemy_count": wanted_hazards,
			"crowded": bool(mode["crowded"]),
			"persisted_settings": {
				ACCESSIBILITY.REDUCED_MOTION_KEY: bool(mode["reduced_motion"]),
				ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: bool(mode["photosensitivity_safe"]),
			},
			"capture_observation": phase_observation,
			"observed_beats": observations.duplicate(true),
		})
	_progress(context, "", "cell_captured", {"phases": PHASE_IDS.size()})
	return records


func _source_from_environment() -> Dictionary:
	var source := {
		"ref": OS.get_environment("DARK_MAGE_CERT_SOURCE_REF").strip_edges(),
		"commit_sha": OS.get_environment("DARK_MAGE_CERT_SOURCE_SHA").strip_edges().to_lower(),
		"tree_sha": OS.get_environment("DARK_MAGE_CERT_SOURCE_TREE").strip_edges().to_lower(),
		"note": "The live harness was committed before regenerated PNG evidence and manifest hashes; the final evidence commit is therefore not self-referential.",
	}
	for field in ["ref", "commit_sha", "tree_sha"]:
		if str(source[field]).is_empty():
			_fail("DARK_MAGE_CERT_SOURCE_%s is required" % field.to_upper())
			return {}
	return source


func _weapons_from_manifest() -> Dictionary:
	var file := FileAccess.open(CLASS_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var result := {}
	if not parsed is Dictionary:
		return result
	for raw_weapon in (parsed as Dictionary).get("weapons", []) as Array:
		if raw_weapon is Dictionary:
			var weapon := raw_weapon as Dictionary
			result[str(weapon.get("weapon_id", ""))] = weapon.duplicate(true)
	return result


func _persist_mode(mode: Dictionary) -> void:
	var stored := GAME_SETTINGS.DEFAULTS.duplicate(true)
	stored[ACCESSIBILITY.REDUCED_MOTION_KEY] = bool(mode["reduced_motion"])
	stored[ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY] = bool(mode["photosensitivity_safe"])
	GAME_SETTINGS.save_settings(stored)


func _backup_settings() -> Dictionary:
	var backup := {"exists": FileAccess.file_exists(SETTINGS_PATH), "bytes": PackedByteArray()}
	if bool(backup["exists"]):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			backup["bytes"] = file.get_buffer(file.get_length())
			file.close()
	return backup


func _restore_settings(backup: Dictionary) -> void:
	if bool(backup.get("exists", false)):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(backup.get("bytes", PackedByteArray()) as PackedByteArray)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _apply_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for _frame in 30:
		await process_frame
		if root.size == size:
			return


func _restore_window_size(size: Vector2i) -> void:
	if root.size != size:
		await _apply_window_size(size)


func _combat_hud(main: Node) -> Control:
	var layer := main.get("hud_layer") as CanvasLayer
	return layer.find_child("CombatHudRoot", true, false) as Control if layer != null else null


func _freeze_player_attacks(player: Node2D) -> void:
	player.set_process(false)
	player.set_physics_process(false)
	var weapon := player.get("equipped_weapon") as Node
	if weapon != null:
		weapon.process_mode = Node.PROCESS_MODE_DISABLED


func _prepare_hazards(main: Node, player: Node2D, wanted: int) -> Array[Node2D]:
	main.set("spawn_cooldown", 1.0e9)
	var combat: Object = main.get("combat")
	var live := _live_enemies()
	var guard := 0
	while live.size() < wanted and guard < wanted * 3:
		var angle := float(guard) * TAU / 8.0
		var radius := float(HAZARD_RING_RADII[guard % HAZARD_RING_RADII.size()])
		var spot := player.global_position + Vector2(radius, 0.0).rotated(angle)
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
		var radius := float(HAZARD_RING_RADII[ring % HAZARD_RING_RADII.size()]) + 26.0 * float(ring / HAZARD_RING_RADII.size())
		enemy.global_position = player.global_position + Vector2(radius, 0.0).rotated(float(slot) * TAU / 8.0)
		placed.append(enemy)
	await process_frame
	return placed


func _live_enemies() -> Array[Node2D]:
	var live: Array[Node2D] = []
	for raw_enemy in get_nodes_in_group("enemies"):
		if raw_enemy is Node2D and is_instance_valid(raw_enemy):
			live.append(raw_enemy as Node2D)
	return live


func _presentation_driver(main: Node) -> Node2D:
	for raw_child in main.get_children():
		var child := raw_child as Node2D
		if child == null:
			continue
		var script := child.get_script() as Script
		if script != null and script.resource_path == DRIVER_SCRIPT_PATH:
			return child
	return null


func _driver_mode_matches(state: Dictionary, mode: Dictionary) -> bool:
	var reduced := bool(mode["reduced_motion"])
	var photosafe := bool(mode["photosensitivity_safe"])
	var expected_timeline := "ultimate_reduced_motion" if reduced else "ultimate"
	return bool(state.get("reduced_motion", false)) == reduced \
		and bool(state.get("photosensitivity_safe", false)) == photosafe \
		and str(state.get("timeline_animation", "")) == expected_timeline


func _visible_required_artwork(driver: Node2D, weapon_id: String, phase_id: String) -> Array[String]:
	var visible_nodes: Array[String] = []
	var by_phase := REQUIRED_ARTWORK_BY_PHASE.get(weapon_id, {}) as Dictionary
	var required_nodes := by_phase.get(phase_id, []) as Array
	if required_nodes.is_empty():
		return visible_nodes
	for raw_name in required_nodes:
		var node_name := str(raw_name)
		var item := driver.get_node_or_null(str(raw_name)) as CanvasItem
		if item == null or not item.visible or item.modulate.a <= 0.05 or item.self_modulate.a <= 0.05:
			return []
		visible_nodes.append(node_name)
	return visible_nodes


func _hud_and_hazards_visible(hud_root: Control, hazards: Array[Node2D]) -> bool:
	if hud_root == null or not hud_root.visible:
		return false
	return _visible_hazard_count(hazards) > 0


func _visible_hazard_count(hazards: Array[Node2D]) -> int:
	var visible := 0
	for hazard in hazards:
		if is_instance_valid(hazard) and hazard.visible and hazard.global_position.distance_to(HAZARD_PARKING) > 10.0:
			visible += 1
	return visible


func _has_ultimate_impact(hazards: Array[Node2D]) -> bool:
	for hazard in hazards:
		if is_instance_valid(hazard) and float(hazard.get("health")) < HAZARD_HEALTH:
			return true
	return false


func _prepare_staging() -> int:
	var run_id := "%s-%d" % [str(_source.get("commit_sha", "")).substr(0, 12), _run_started_msec]
	_staging_root = "%s/%s" % [STAGING_ROOT_PREFIX, run_id]
	_staging_manifest_path = "%s/certification_capture_manifest.json" % _staging_root
	_published_root = "%s/generation-%s" % [OUTPUT_ROOT, run_id]
	var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_staging_root))
	if result == OK or result == ERR_ALREADY_EXISTS:
		_progress("run", "", "staging_ready", {"publication_pending": true})
		return OK
	return result


func _published_capture_path(weapon_id: String, mode_id: String, viewport_id: String, phase_id: String) -> String:
	return "%s/dark_mage__%s__%s__%s__%s.png" % [_published_root, weapon_id, mode_id, viewport_id, phase_id]


func _staged_capture_path(weapon_id: String, mode_id: String, viewport_id: String, phase_id: String) -> String:
	return "%s/%s" % [_staging_root, _published_capture_path(weapon_id, mode_id, viewport_id, phase_id).get_file()]


func _publish_staged_package() -> int:
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_published_root))
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		return directory_result
	_progress("run", "", "publication_started", {"captures": _records.size()})
	for record in _records:
		var output_path := "res://%s" % str(record.get("path", ""))
		var staged_path := "%s/%s" % [_staging_root, output_path.get_file()]
		var copy_result := _copy_file(staged_path, output_path)
		if copy_result != OK:
			_remove_tree(_published_root)
			return copy_result
	var manifest_result := _replace_capture_manifest_from_staging()
	if manifest_result != OK:
		_remove_tree(_published_root)
		return manifest_result
	_published = true
	_progress("run", "", "manifest_published", {"captures": _records.size()})
	_remove_superseded_capture_artifacts()
	return OK


func _copy_file(source_path: String, destination_path: String) -> int:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ERR_FILE_NOT_FOUND
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return ERR_CANT_CREATE
	destination.store_buffer(bytes)
	destination.close()
	return OK


func _replace_capture_manifest_from_staging() -> int:
	var temporary_path := CAPTURE_MANIFEST_PATH + ".tmp"
	var copy_result := _copy_file(_staging_manifest_path, temporary_path)
	if copy_result != OK:
		return copy_result
	var rename_result := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(CAPTURE_MANIFEST_PATH))
	if rename_result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	return rename_result


## The manifest is the public generation pointer. New frames are first written
## into an unreferenced generation; once the manifest swap succeeds, old
## generation files may be removed without making the active package incoherent.
func _remove_superseded_capture_artifacts() -> void:
	var root_dir := DirAccess.open(OUTPUT_ROOT)
	if root_dir == null:
		_record_cleanup_warning("could not open the capture root after manifest publication")
		return
	for file_name in root_dir.get_files():
		if _is_owned_flat_capture(file_name) and root_dir.remove(file_name) != OK:
			_record_cleanup_warning("could not remove superseded capture %s" % file_name)
	for directory_name in root_dir.get_directories():
		if directory_name == _published_root.get_file() or not directory_name.begins_with("generation-"):
			continue
		var cleanup_result := _remove_tree("%s/%s" % [OUTPUT_ROOT, directory_name])
		if cleanup_result != OK:
			_record_cleanup_warning("could not remove superseded capture generation %s" % directory_name)


func _is_owned_flat_capture(file_name: String) -> bool:
	return file_name.begins_with("dark_mage__") and file_name.ends_with(".png")


func _clear_staging() -> void:
	if _staging_root.is_empty():
		_staging_cleaned = true
		return
	var result := _remove_tree(_staging_root)
	_staging_cleaned = result == OK or result == ERR_DOES_NOT_EXIST
	if not _staging_cleaned:
		_record_cleanup_warning("could not clean the task-owned capture staging directory")


func _remove_tree(path: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		return ERR_DOES_NOT_EXIST
	for file_name in directory.get_files():
		var remove_file_result := directory.remove(file_name)
		if remove_file_result != OK:
			return remove_file_result
	for directory_name in directory.get_directories():
		var remove_directory_result := _remove_tree("%s/%s" % [path, directory_name])
		if remove_directory_result != OK:
			return remove_directory_result
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cell_seed(viewport_id: String, mode_id: String, weapon_id: String) -> int:
	return CAPTURE_SEED + abs(("%s/%s/%s" % [viewport_id, mode_id, weapon_id]).hash()) % 1000000


func _image_sha256(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode().to_lower()


func _luminance_variation(image: Image) -> float:
	var minimum := 1.0
	var maximum := 0.0
	for y in range(0, image.get_height(), LUMINANCE_SAMPLE_STRIDE):
		for x in range(0, image.get_width(), LUMINANCE_SAMPLE_STRIDE):
			var pixel := image.get_pixel(x, y)
			var luminance := 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
			minimum = minf(minimum, luminance)
			maximum = maxf(maximum, luminance)
	return maximum - minimum


func _write_capture_manifest(path: String) -> int:
	var payload := {
		"schema_version": 2,
		"issue": CAPTURE_ID,
		"class_id": CLASS_ID,
		"capture_source": _source,
		"contributors": [
			{"agent_id": "1c7dc221-2a24-402f-8fe2-4a0f60b65e87", "role": "preserved initial Dark Mage certification work and historical candidate"},
			{"agent_id": "66574651-653c-4c38-9f0e-f290cab5362a", "role": "successor production-runtime capture rework"},
		],
		"canonical_weapon_ids": WEAPON_IDS.duplicate(),
		"presentation_modes": _mode_declarations(),
		"viewports": _viewport_declarations(),
		"observed_beats": PHASE_IDS.duplicate(),
		"capture": {
			"method": "windowed real Main scene: persisted settings.cfg -> Main publication -> _start_combat -> current_player.activate_ultimate -> native framebuffer readback at release, active, and recovery",
			"capture_script": "tests/ultimates/presentation/dark_mage_certification_live_capture.gd",
			"focused_test": "tests/ultimates/presentation/dark_mage_certification_capture_test.gd",
			"fixed_fps": 60,
			"deterministic_seed": CAPTURE_SEED,
			"framebuffer_wait_deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
			"publication": "PNG frames are staged outside the published package. A complete new generation is written before the capture manifest atomically switches to it, so a failed capture keeps the prior manifest and frames coherent.",
			"hash_scope": "PNG SHA-256 identifies the hydrated review artifact; per-beat RGBA SHA-256 identifies the in-run raw framebuffer. Fixed FPS and per-cell deterministic seeds constrain replay, but Metal/GPU raster output is not claimed byte-identical across driver versions.",
			"godot_version": str(Engine.get_version_info().get("string", "")),
			"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			"video_adapter": str(RenderingServer.get_video_adapter_name()),
			"platform": OS.get_name(),
			"real_runtime": {
				"main_scene": MAIN_SCENE_PATH,
				"hud": "CombatHudRoot under Main.hud_layer",
				"player_activation": "Player.activate_ultimate()",
				"hazards": "Main.combat._spawn_random_enemy through the shipped director path",
				"crowded_enemy_count": CROWDED_HAZARDS,
			},
		},
		"commands": {
			"live_capture": WINDOWED_CAPTURE_COMMAND,
			"focused_test": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/dark_mage_certification_capture_test.gd",
			"runtime_modes": "FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=180 python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd",
			"class_timelines": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/dark_mage_ultimate_timelines.gd",
			"static_guard": "python3 tools/quality_static_guard.py --changed-ref <declared-base-sha>",
		},
		"captures": _records,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_CREATE
	file.store_string(JSON.stringify(payload, "  ") + "\n")
	file.close()
	return OK


func _mode_declarations() -> Array:
	var declarations: Array = []
	for raw_mode in MODES:
		var mode := raw_mode as Dictionary
		declarations.append({
			"id": str(mode["id"]),
			"configuration": {
				ACCESSIBILITY.REDUCED_MOTION_KEY: bool(mode["reduced_motion"]),
				ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: bool(mode["photosensitivity_safe"]),
				"director_enemy_count": CROWDED_HAZARDS if bool(mode["crowded"]) else NORMAL_HAZARDS,
			},
			"intent": str(mode["intent"]),
		})
	return declarations


func _viewport_declarations() -> Array:
	var declarations: Array = []
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		declarations.append({"id": viewport["id"], "width": size.x, "height": size.y})
	return declarations


func _dispose_main(main: Node) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	_main_cleanup_count += 1
	current_scene = null
	await process_frame
	await process_frame


func _abort_main(main: Node, player: Variant = null) -> void:
	## A timeout can arrive after the normal lifecycle has freed the Player. Keep
	## this boundary Variant-typed so a stale typed reference reaches the validity
	## check instead of failing before ordinary scene disposal can run.
	if player is Node2D and is_instance_valid(player):
		PlayerHost.reset(player as Node2D)
		_player_reset_count += 1
	await _dispose_main(main)


func _await_framebuffer_draw(context: String, phase_id: String, wait_stage: String) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	var request_draw := not _test_suppress_force_draw
	_progress(context, phase_id, "framebuffer_wait_begin", {
		"wait_stage": wait_stage,
		"deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
		"requested_force_draw": request_draw,
	})
	var deadline := FramePostDrawDeadline.new()
	var drew_frame: bool = await deadline.await_frame(self, FRAMEBUFFER_WAIT_DEADLINE_SECONDS, request_draw)
	var result := _runtime_metadata()
	result.merge({
		"context": context,
		"phase": phase_id,
		"stage": "framebuffer_wait",
		"wait_stage": wait_stage,
		"deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
		"waited_wall_msec": Time.get_ticks_msec() - started_msec,
		"drew_frame": drew_frame,
		"settled_by": deadline.settled_by(),
		"watchdog_process_ticks": deadline.process_ticks(),
		"requested_force_draw": request_draw,
		"test_suppress_force_draw": _test_suppress_force_draw,
		"command": WINDOWED_CAPTURE_COMMAND,
	}, true)
	if drew_frame:
		_progress(context, phase_id, "framebuffer_wait_complete", result)
		return result
	result["kind"] = "framebuffer_wait_timeout"
	_diagnostics.append(result.duplicate(true))
	_progress(context, phase_id, "framebuffer_wait_timeout", result)
	_fail("%s phase=%s stage=%s framebuffer wait timed out after %dms (display=%s renderer=%s render_loop_enabled=%s; command: %s)" % [
		context,
		phase_id,
		wait_stage,
		int(result["waited_wall_msec"]),
		str(result["display_server"]),
		str(result["renderer"]),
		str(result["render_loop_enabled"]),
		WINDOWED_CAPTURE_COMMAND,
	])
	return result


func _runtime_metadata() -> Dictionary:
	return {
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"render_loop_enabled": RenderingServer.render_loop_enabled,
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"godot": str(Engine.get_version_info().get("string", "")),
		"wall_elapsed_msec": Time.get_ticks_msec() - _run_started_msec,
	}


func _progress(context: String, phase_id: String, stage: String, details: Dictionary = {}) -> void:
	var event := _runtime_metadata()
	event["context"] = context
	event["phase"] = phase_id
	event["stage"] = stage
	for key in details:
		event[key] = details[key]
	_progress_events.append(event)
	print("FAN-3938 Dark Mage certification capture: progress %s" % JSON.stringify(event))


func _record_cleanup_warning(message: String) -> void:
	var diagnostic := _runtime_metadata()
	diagnostic.merge({"kind": "cleanup_warning", "message": message}, true)
	_diagnostics.append(diagnostic)
	push_warning("FAN-3938 Dark Mage certification capture: %s" % message)


func _write_run_report() -> void:
	var path := OS.get_environment(RUN_REPORT_ENV).strip_edges()
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_record_cleanup_warning("cannot write run report")
		return
	file.store_string(JSON.stringify({
		"issue": CAPTURE_ID,
		"display": "headless" if DisplayServer.get_name() == "headless" else "windowed",
		"command": WINDOWED_CAPTURE_COMMAND,
		"framebuffer_wait_deadline_seconds": FRAMEBUFFER_WAIT_DEADLINE_SECONDS,
		"test_suppress_force_draw": _test_suppress_force_draw,
		"published": _published,
		"published_generation": _published_root.trim_prefix("res://"),
		"cleanup": {
			"settings_restored": _settings_restored,
			"window_restored": _window_restored,
			"staging_cleaned": _staging_cleaned,
			"main_cleanup_count": _main_cleanup_count,
			"player_reset_count": _player_reset_count,
		},
		"progress": _progress_events,
		"diagnostics": _diagnostics,
		"failures": _failures,
	}, "  "))
	file.close()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("FAN-3938 Dark Mage certification capture: %s" % message)


func _finish_failure() -> void:
	for message in _failures:
		push_error("FAN-3938 Dark Mage certification capture failure: %s" % message)
	quit(1)
