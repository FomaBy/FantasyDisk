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
const LUMINANCE_SAMPLE_STRIDE := 16

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


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3938 Dark Mage certification capture skipped (headless); windowed evidence is required.")
		quit(0)
		return
	_source = _source_from_environment()
	if _source.is_empty():
		quit(1)
		return
	_weapons = _weapons_from_manifest()
	if _weapons.size() != WEAPON_IDS.size():
		_fail("class manifest must expose the three canonical Dark Mage weapons")
		quit(1)
		return
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		_fail("cannot create capture directory: %s" % error_string(directory_result))
		quit(1)
		return
	var settings_backup := _backup_settings()
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		for raw_mode in MODES:
			var mode := raw_mode as Dictionary
			for weapon_id in WEAPON_IDS:
				var phase_records := await _capture_cell(viewport, mode, weapon_id)
				if phase_records.is_empty():
					_restore_settings(settings_backup)
					_finish_failure()
					return
				_records.append_array(phase_records)
	_restore_settings(settings_backup)
	var expected_captures := WEAPON_IDS.size() * MODES.size() * VIEWPORTS.size() * PHASE_IDS.size()
	if _records.size() != expected_captures:
		_fail("capture count is %d, expected %d" % [_records.size(), expected_captures])
		_finish_failure()
		return
	var write_result := _write_capture_manifest()
	if write_result != OK:
		_fail("could not write capture manifest: %s" % error_string(write_result))
		_finish_failure()
		return
	print("FAN-3938 Dark Mage certification capture: PASS (%d native live captures)" % _records.size())
	quit(0)


func _capture_cell(viewport: Dictionary, mode: Dictionary, weapon_id: String) -> Array[Dictionary]:
	var viewport_id := str(viewport["id"])
	var mode_id := str(mode["id"])
	var size := viewport["size"] as Vector2i
	var context := "%s/%s/%s" % [weapon_id, mode_id, viewport_id]
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
		await _dispose_main(main)
		return []
	if hud_root == null or not hud_root.visible:
		_fail("%s did not produce the shipped CombatHudRoot" % context)
		await _dispose_main(main)
		return []
	_freeze_player_attacks(player)
	var wanted_hazards := CROWDED_HAZARDS if bool(mode["crowded"]) else NORMAL_HAZARDS
	var hazards := await _prepare_hazards(main, player, wanted_hazards)
	if hazards.size() != wanted_hazards:
		_fail("%s placed %d of %d director-spawned Enemy hazards" % [context, hazards.size(), wanted_hazards])
		await _dispose_main(main)
		return []
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	if not bool(player.call("activate_ultimate")):
		_fail("%s Player.activate_ultimate() did not start the production cast" % context)
		await _dispose_main(main)
		return []
	var host = PlayerHost.for_player(player)
	var controller = host.controller() if host != null else null
	if controller == null or not controller.is_active():
		_fail("%s has no active UltimateController after Player activation" % context)
		await _dispose_main(main)
		return []
	var observations := {}
	var elapsed := 0.0
	for phase_id in PHASE_IDS:
		var target := float(timing.get(phase_id, -1.0))
		if target <= 0.0:
			_fail("%s has an invalid %s beat" % [context, phase_id])
			await _dispose_main(main)
			return []
		while elapsed < target and controller.is_active() and elapsed < CAPTURE_TIMEOUT_SECONDS:
			await process_frame
			elapsed += get_root().get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		if not controller.is_active():
			_fail("%s ended before its %s beat" % [context, phase_id])
			await _dispose_main(main)
			return []
		var driver := _presentation_driver(main)
		if driver == null:
			_fail("%s did not mount the shipped Dark Mage presentation driver" % context)
			await _dispose_main(main)
			return []
		var visual_state := driver.call("presence_state_for_tests") as Dictionary
		if str(driver.call("visible_phase_name")) != phase_id:
			_fail("%s reported phase %s at requested %s beat" % [context, str(driver.call("visible_phase_name")), phase_id])
			await _dispose_main(main)
			return []
		if not _driver_mode_matches(visual_state, mode):
			_fail("%s driver state does not match Main's persisted mode snapshot" % context)
			await _dispose_main(main)
			return []
		var artwork_nodes := _visible_required_artwork(driver, weapon_id, phase_id)
		if artwork_nodes.is_empty():
			_fail("%s lacks visible authored artwork at %s" % [context, phase_id])
			await _dispose_main(main)
			return []
		if not _hud_and_hazards_visible(hud_root, hazards):
			_fail("%s lacks visible shipped HUD or Enemy hazard state at %s" % [context, phase_id])
			await _dispose_main(main)
			return []
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != size:
			_fail("%s framebuffer at %s is not native %s" % [context, phase_id, size])
			await _dispose_main(main)
			return []
		image.convert(Image.FORMAT_RGBA8)
		var variation := _luminance_variation(image)
		if variation < 0.04:
			_fail("%s framebuffer at %s is visually empty (variation %.3f)" % [context, phase_id, variation])
			await _dispose_main(main)
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
		var output_path := _capture_path(weapon_id, mode_id, viewport_id, phase_id)
		if image.save_png(ProjectSettings.globalize_path(output_path)) != OK:
			_fail("%s could not save %s native PNG" % [context, phase_id])
			await _dispose_main(main)
			return []
		observation["path"] = output_path.trim_prefix("res://")
		observation["sha256"] = FileAccess.get_sha256(output_path).to_lower()
		observation["lfs_object_id"] = "sha256:%s" % str(observation["sha256"])
		observations[phase_id] = observation
	if not _has_ultimate_impact(hazards):
		_fail("%s did not record a real ultimate impact on a director-spawned Enemy" % context)
		await _dispose_main(main)
		return []
	PlayerHost.reset(player)
	await _dispose_main(main)
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


func _capture_path(weapon_id: String, mode_id: String, viewport_id: String, phase_id: String) -> String:
	return "%s/dark_mage__%s__%s__%s__%s.png" % [OUTPUT_ROOT, weapon_id, mode_id, viewport_id, phase_id]


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


func _write_capture_manifest() -> int:
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
			"live_capture": "FSD_GODOT_EXCLUSIVE=1 DARK_MAGE_CERT_SOURCE_REF=<ref> DARK_MAGE_CERT_SOURCE_SHA=<sha> DARK_MAGE_CERT_SOURCE_TREE=<tree> python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/dark_mage_certification_live_capture.gd",
			"focused_test": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/dark_mage_certification_capture_test.gd",
			"runtime_modes": "FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=180 python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd",
			"class_timelines": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/dark_mage_ultimate_timelines.gd",
			"static_guard": "python3 tools/quality_static_guard.py --changed-ref <declared-base-sha>",
		},
		"captures": _records,
	}
	var file := FileAccess.open(CAPTURE_MANIFEST_PATH, FileAccess.WRITE)
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
	current_scene = null
	await process_frame
	await process_frame


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("FAN-3938 Dark Mage certification capture: %s" % message)


func _finish_failure() -> void:
	for message in _failures:
		push_error("FAN-3938 Dark Mage certification capture failure: %s" % message)
	quit(1)
