extends SceneTree

## Headless integrity and live-composition gate for FAN-3944's windowed Robot
## certification capture. The renderer owns PNG creation; this script owns the
## declared matrix, provenance, fail-closed negatives, and the scene-level
## readability checks that can run without treating a headless image as proof.

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemySpitterScene := preload("res://scenes/EnemySpitter.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")
const Contract := preload("res://scripts/ultimates/presentation/ultimate_visual_direction_contract.gd")

const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/robot.json"
const LEGACY_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/robot/manifest.json"
const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/robot/certification_capture_manifest.json"
const LIVE_CAPTURE_SCRIPT := "tests/ultimates/presentation/robot_certification_live_capture.gd"

const CAPTURE_ROOT := "res://docs/design/reference-assets-lfs/ultimate-certification/robot"
const CAPTURE_BASE_REF := "dev"
const CAPTURE_BASE_SHA := "0000000000000000000000000000000000000000"
const CAPTURE_BASE_TREE := "0000000000000000000000000000000000000000"
const CAPTURE_SEED := 394402
const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"
const CAPTURE_STEP := 0.01
const ENEMY_CAPTURE_HEALTH := 100000.0

const WEAPON_IDS: Array[String] = ["robot_magnetic_anchor", "robot_hydraulic_press", "robot_reactor_core"]
const MODE_IDS: Array[String] = ["normal", "crowded", "reduced_motion", "photosensitivity_safe"]
const PHASE_IDS: Array[String] = ["release", "active", "recovery"]
const CAPTURES := [
	{"id": "648p-release", "viewport_id": "648p", "phase": "release", "path": CAPTURE_ROOT + "/robot_certification_648p_release.png", "size": Vector2i(1152, 648)},
	{"id": "648p-active", "viewport_id": "648p", "phase": "active", "path": CAPTURE_ROOT + "/robot_certification_648p.png", "size": Vector2i(1152, 648)},
	{"id": "648p-recovery", "viewport_id": "648p", "phase": "recovery", "path": CAPTURE_ROOT + "/robot_certification_648p_recovery.png", "size": Vector2i(1152, 648)},
	{"id": "720p-release", "viewport_id": "720p", "phase": "release", "path": CAPTURE_ROOT + "/robot_certification_720p_release.png", "size": Vector2i(1280, 720)},
	{"id": "720p-active", "viewport_id": "720p", "phase": "active", "path": CAPTURE_ROOT + "/robot_certification_720p.png", "size": Vector2i(1280, 720)},
	{"id": "720p-recovery", "viewport_id": "720p", "phase": "recovery", "path": CAPTURE_ROOT + "/robot_certification_720p_recovery.png", "size": Vector2i(1280, 720)},
	{"id": "1080p-release", "viewport_id": "1080p", "phase": "release", "path": CAPTURE_ROOT + "/robot_certification_1080p_release.png", "size": Vector2i(1920, 1080)},
	{"id": "1080p-active", "viewport_id": "1080p", "phase": "active", "path": CAPTURE_ROOT + "/robot_certification_1080p.png", "size": Vector2i(1920, 1080)},
	{"id": "1080p-recovery", "viewport_id": "1080p", "phase": "recovery", "path": CAPTURE_ROOT + "/robot_certification_1080p_recovery.png", "size": Vector2i(1920, 1080)},
	{"id": "2k-release", "viewport_id": "2k", "phase": "release", "path": CAPTURE_ROOT + "/robot_certification_2k_release.png", "size": Vector2i(2560, 1440)},
	{"id": "2k-active", "viewport_id": "2k", "phase": "active", "path": CAPTURE_ROOT + "/robot_certification_2k.png", "size": Vector2i(2560, 1440)},
	{"id": "2k-recovery", "viewport_id": "2k", "phase": "recovery", "path": CAPTURE_ROOT + "/robot_certification_2k_recovery.png", "size": Vector2i(2560, 1440)},
]

## `crowded` uses the live class-declared crowd cap. Every other mode keeps a
## small representative trio so the contrast is only the intended mode switch.
const MODES := [
	{"id": "normal", "label": "NORMAL", "screen_shake": true, "crowded": false, "photosafe": false},
	{"id": "crowded", "label": "CROWDED", "screen_shake": true, "crowded": true, "photosafe": false},
	{"id": "reduced_motion", "label": "REDUCED MOTION", "screen_shake": false, "crowded": false, "photosafe": false},
	{"id": "photosensitivity_safe", "label": "PHOTOSENSITIVITY SAFE", "screen_shake": false, "crowded": false, "photosafe": true},
]

const PACKS := [
	{
		"weapon_id": "robot_magnetic_anchor",
		"label": "MAGNETIC ANCHOR",
		"scene_path": "scenes/vfx/ultimates/robot/RobotMagneticAnchorSingularity.tscn",
		"scene": preload("res://scenes/vfx/ultimates/robot/RobotMagneticAnchorSingularity.tscn"),
		"crowd_cap": 9,
		"color": Color(0.58, 0.88, 1.0),
		"beats": {"release": 0.80, "active": 1.25, "recovery": 3.15},
		"required_nodes": ["BackdropVeil"],
	},
	{
		"weapon_id": "robot_hydraulic_press",
		"label": "HYDRAULIC PRESS",
		"scene_path": "scenes/vfx/ultimates/robot/RobotHydraulicPressProtocol.tscn",
		"scene": preload("res://scenes/vfx/ultimates/robot/RobotHydraulicPressProtocol.tscn"),
		"crowd_cap": 9,
		"color": Color(0.96, 0.76, 0.46),
		"beats": {"release": 0.85, "active": 1.30, "recovery": 3.20},
		"required_nodes": ["BackdropVeil"],
	},
	{
		"weapon_id": "robot_reactor_core",
		"label": "REACTOR CORE",
		"scene_path": "scenes/vfx/ultimates/robot/RobotReactorCoreRedZone.tscn",
		"scene": preload("res://scenes/vfx/ultimates/robot/RobotReactorCoreRedZone.tscn"),
		"crowd_cap": 9,
		"color": Color(1.0, 0.36, 0.18),
		"beats": {"release": 0.90, "active": 1.35, "recovery": 3.25},
		"required_nodes": ["BackdropVeil"],
	},
]

const PLAYER_SCENE_PATH := "res://scenes/Player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/EnemySpitter.tscn"
const HUD_ADAPTER_PATH := "res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd"

const BACKGROUND_COLOR := Color(0.025, 0.040, 0.030, 1.0)
const FLOOR_COLOR := Color(0.055, 0.080, 0.060, 1.0)
const PANEL_COLOR := Color(0.070, 0.105, 0.080, 1.0)
const PANEL_OUTLINE_COLOR := Color(0.35, 0.48, 0.36, 1.0)
const MARKER_COLORS := {
	"normal": Color(0.22, 0.78, 1.0, 1.0),
	"crowded": Color(1.0, 0.60, 0.20, 1.0),
	"reduced_motion": Color(0.38, 0.94, 0.50, 1.0),
	"photosensitivity_safe": Color(0.82, 0.50, 1.0, 1.0),
}

const GRID_LEFT_RATIO := 0.012
const GRID_RIGHT_RATIO := 0.988
const GRID_TOP_RATIO := 0.205
const GRID_BOTTOM_RATIO := 0.985
const GRID_GAP_X_RATIO := 0.006
const GRID_GAP_Y_RATIO := 0.010
const PANEL_MARGIN_RATIO := 0.006
const PANEL_LABEL_RATIO := 0.105

const PLAYER_COLUMN_RATIO := 0.18
const HAZARD_COLUMN_RATIO := 0.17
const STATE_BAND_RATIO := 0.13
const MIN_READABLE_PIXELS := 6.0
const REDUCED_MOTION_ALPHA_CEILING := 0.46

var _manifest: Dictionary = {}
var _profile: Dictionary = {}


func _initialize() -> void:
	var errors: Array[String] = []
	_manifest = _load_json(CAPTURE_MANIFEST_PATH, errors)
	_profile = _load_json(PROFILE_PATH, errors)
	var legacy := _load_json(LEGACY_MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	for violation in manifest_violations(_manifest, _profile):
		errors.append(violation)
	_check_legacy_handoff(legacy, errors)
	if _can_verify_windowed_capture_files():
		for violation in capture_file_violations(_manifest.get("viewports", []) as Array):
			errors.append(violation)
		_check_sheet_markers(errors)
	else:
		print("FAN-3944 headless structural gate: windowed PNG evidence and LFS materialization are intentionally skipped, never treated as capture proof.")
	_check_negative_probes(errors)
	if not errors.is_empty():
		_finish(errors)
		return
	await _check_live_runtime(errors)
	_finish(errors)


func _check_legacy_handoff(legacy: Dictionary, errors: Array[String]) -> void:
	_expect(str(legacy.get("class_id", "")) == "robot", "legacy Robot manifest must stay class-local", errors)
	var evidence := legacy.get("evidence", {}) as Dictionary
	var certification := evidence.get("certification_capture", {}) as Dictionary
	_expect(
		str(certification.get("manifest", "")) == "docs/design/references/weapon_ultimates/robot/certification_capture_manifest.json",
		"legacy manifest must point reviewers to the certification manifest",
		errors
	)
	_expect(str(certification.get("capture_script", "")) == LIVE_CAPTURE_SCRIPT, "legacy manifest must name the live renderer", errors)
	_expect(
		str(certification.get("focused_test", "")) == "tests/ultimates/presentation/robot_certification_capture_test.gd",
		"legacy manifest must name the certification gate",
		errors
	)


func _check_sheet_markers(errors: Array[String]) -> void:
	var viewports := _viewports_by_id(_manifest.get("viewports", []) as Array)
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var record := viewports.get(str(capture["id"]), {}) as Dictionary
		var path := str(record.get("path", ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			continue
		var size := capture["size"] as Vector2i
		for weapon_index in WEAPON_IDS.size():
			for mode_index in MODE_IDS.size():
				var mode_id := MODE_IDS[mode_index]
				var actual := image.get_pixelv(mode_marker_probe(size, weapon_index, mode_index))
				var expected := MARKER_COLORS[mode_id] as Color
				if not _color_near(actual, expected):
					print("FAN-3944 marker mismatch %s/%s at %s: actual=%s expected=%s" % [
						str(capture["id"]), mode_id, mode_marker_probe(size, weapon_index, mode_index), actual, expected,
					])
				_expect(
					_color_near(actual, expected),
					"%s must contain the %s marker for %s" % [str(capture["id"]), mode_id, WEAPON_IDS[weapon_index]],
					errors
				)


func _check_negative_probes(errors: Array[String]) -> void:
	_expect(manifest_violations(_manifest, _profile).is_empty(), "the shipped certification manifest must pass its own schema", errors)
	var missing_mode := _manifest.duplicate(true)
	(missing_mode.get("presentation_modes", []) as Array).remove_at(0)
	_expect(not manifest_violations(missing_mode, _profile).is_empty(), "a missing presentation mode must fail closed", errors)

	var missing_key := _manifest.duplicate(true)
	(missing_key.get("capture_source", {}) as Dictionary).erase("source_tree_sha")
	_expect(not manifest_violations(missing_key, _profile).is_empty(), "a missing provenance key must fail closed", errors)

	var wrong_size := _manifest.duplicate(true)
	((wrong_size.get("viewports", []) as Array)[0] as Dictionary)["width"] = 1
	_expect(not manifest_violations(wrong_size, _profile).is_empty(), "a wrong viewport dimension must fail closed", errors)

	var missing_file := _manifest.duplicate(true)
	((missing_file.get("viewports", []) as Array)[0] as Dictionary)["path"] = CAPTURE_ROOT + "/missing.png"
	_expect(not capture_file_violations(missing_file.get("viewports", []) as Array).is_empty(), "a missing PNG must fail closed", errors)

	var pointer_path := "user://fan3944_robot_lfs_pointer.png"
	var pointer := FileAccess.open(pointer_path, FileAccess.WRITE)
	if pointer == null:
		errors.append("could not write LFS pointer negative fixture")
	else:
		pointer.store_string("%s\noid sha256:%s\nsize 4096\n" % [LFS_POINTER_PREFIX, "a".repeat(64)])
		pointer.close()
		var pointer_viewports := _manifest.get("viewports", []) as Array
		var pointer_copy := pointer_viewports.duplicate(true)
		(pointer_copy[0] as Dictionary)["path"] = pointer_path
		_expect(not capture_file_violations(pointer_copy).is_empty(), "an LFS pointer must fail closed", errors)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pointer_path))


func _check_live_runtime(errors: Array[String]) -> void:
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid for the live Player/HUD state", errors)
	_expect(PlayerScene != null and ResourceLoader.exists(PLAYER_SCENE_PATH), "the shipped Player.tscn must load", errors)
	_expect(EnemySpitterScene != null and ResourceLoader.exists(ENEMY_SCENE_PATH), "the shipped EnemySpitter.tscn must load", errors)
	_expect(HudAdapter != null and ResourceLoader.exists(HUD_ADAPTER_PATH), "the shipped ultimate HUD runtime adapter must load", errors)

	## Each phase sheet carries all twelve weapon/mode cells at its declared
	## native viewport. These structural checks keep the phase/viewport coverage
	## coupled to the exact frozen authored scene used by the renderer.
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var sheet_size := capture["size"] as Vector2i
		var phase := str(capture.get("phase", ""))
		_expect(phase in PHASE_IDS, "%s must declare a known captured phase" % str(capture.get("id", "")), errors)
		for weapon_index in PACKS.size():
			var pack := PACKS[weapon_index] as Dictionary
			for mode_index in MODES.size():
				var mode := MODES[mode_index] as Dictionary
				var arena_size := arena_rect(sheet_size, weapon_index, mode_index).size
				_check_readability_geometry(arena_size, "%s/%s" % [str(capture["id"]), phase], pack, mode, errors)
				if phase.is_empty():
					continue
				var scene := prepare_scene(self, pack, mode, float((pack["beats"] as Dictionary)[phase]))
				var context := "%s %s %s %s" % [str(capture["id"]), str(pack["weapon_id"]), str(mode["id"]), phase]
				## AnimationPlayer autoplay is deferred until the scene has joined the
				## tree. A capture seek is valid only when it survives that next frame;
				## otherwise the saved pixels depend on host frame pacing.
				await process_frame
				_check_timeline_hold(scene, float((pack["beats"] as Dictionary)[phase]), context, errors)
				if bool(mode["photosafe"]):
					apply_photosafe(scene)
				_check_live_scene(scene, pack, mode, arena_size, context, errors)
				release_scene(scene)

	## Force the non-headless branch inside the headless test harness, then prove
	## that the real Player activation owns the exact V2 scene, actual Enemy
	## targets and hazard, and the production HUD adapter at all named phases.
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		for raw_mode in MODES:
			var mode := raw_mode as Dictionary
			for phase in PHASE_IDS:
				await _check_real_runtime_cell(pack, mode, phase, errors)
	root.set_meta("screen_shake", true)
	root.set_meta("combat_feedback", true)


func _check_timeline_hold(scene: Node2D, expected_seconds: float, context: String, errors: Array[String]) -> void:
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline == null:
		_expect(scene.has_method("seek_for_capture"), "%s must expose the Robot fixed-seek driver" % context, errors)
		## Reapply after the first process frame so `_ready()` cannot reset a
		## pre-tree direct seek on the first freshly imported scene.
		if scene.has_method("seek_for_capture"):
			scene.call("seek_for_capture", expected_seconds)
		_expect(is_equal_approx(float(scene.get_meta("capture_seconds", -1.0)), expected_seconds),
			"%s must retain the exact driver seek" % context, errors)
		return
	_expect(str(timeline.autoplay).is_empty(), "%s must disarm deferred autoplay before its fixed seek" % context, errors)
	_expect(not timeline.is_playing(), "%s must remain paused after the fixed seek" % context, errors)
	_expect(is_equal_approx(timeline.current_animation_position, expected_seconds),
		"%s must retain the exact fixed seek after a process frame" % context, errors)


func _check_readability_geometry(arena_size: Vector2i, capture_id: String, pack: Dictionary, mode: Dictionary, errors: Array[String]) -> void:
	var context := "%s %s %s" % [capture_id, str(pack["weapon_id"]), str(mode["id"])]
	var full := Rect2(Vector2.ZERO, Vector2(arena_size))
	var effect := effect_zone(arena_size)
	_expect(full.encloses(effect), "%s effect zone must stay inside the arena" % context, errors)
	for band_name in readability_bands(arena_size):
		var band := readability_bands(arena_size)[band_name] as Rect2
		_expect(full.encloses(band), "%s %s must stay inside the arena" % [context, band_name], errors)
		_expect(not effect.intersects(band), "%s effect zone must not cover %s" % [context, band_name], errors)
		_expect(minf(band.size.x, band.size.y) >= MIN_READABLE_PIXELS, "%s %s falls below the readability floor" % [context, band_name], errors)


func _check_live_scene(scene: Node2D, pack: Dictionary, mode: Dictionary, arena_size: Vector2i, context: String, errors: Array[String]) -> void:
	_expect(scene != null and scene.get_script() != null, "%s must instantiate a shipped runtime scene" % context, errors)
	if scene == null:
		return
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	_expect(scene.has_method("seek_for_capture"), "%s must keep its shipped Robot timeline driver" % context, errors)
	for raw_node in pack.get("required_nodes", []) as Array:
		var item := scene.get_node_or_null(str(raw_node)) as CanvasItem
		_expect(item != null, "%s required runtime node is missing: %s" % [context, raw_node], errors)
	var bounds := layout_scene(scene, arena_size)
	_expect(bounds.has_area(), "%s must draw visible non-backdrop content" % context, errors)
	_expect(effect_zone(arena_size).grow(0.5).encloses(bounds), "%s content must fit its effect zone" % context, errors)
	_expect(minf(bounds.size.x, bounds.size.y) >= MIN_READABLE_PIXELS, "%s content falls below the readability floor" % context, errors)
	var shake_state := bool(scene.call("_screen_shake_enabled"))
	_expect(shake_state == bool(mode["screen_shake"]), "%s must read the shipped screen_shake setting" % context, errors)
	var veil := scene.get_node_or_null("BackdropVeil") as CanvasItem
	_expect(veil != null, "%s must expose its backdrop veil" % context, errors)
	if veil == null:
		return
	if bool(mode["photosafe"]):
		_expect(not veil.visible, "%s photosensitivity-safe state must suppress the fullscreen veil" % context, errors)
	elif not bool(mode["screen_shake"]):
		_expect(veil.self_modulate.a <= REDUCED_MOTION_ALPHA_CEILING, "%s reduced-motion state must retain the damped shipped fade" % context, errors)
	else:
		_expect(veil.visible, "%s ordinary state must retain the shipped veil" % context, errors)


func _check_real_runtime_cell(pack: Dictionary, mode: Dictionary, phase: String, errors: Array[String]) -> void:
	var context := "real-runtime %s %s %s" % [str(pack["weapon_id"]), str(mode["id"]), phase]
	var world := Node2D.new()
	world.name = "RobotCertificationRuntimeFixture"
	root.add_child(world)
	current_scene = world
	root.set_meta("screen_shake", bool(mode["screen_shake"]))
	root.set_meta("combat_feedback", true)
	var player := PlayerScene.instantiate() as Node2D
	_expect(player != null, "%s must instantiate the real Player scene" % context, errors)
	if player == null:
		world.queue_free()
		current_scene = null
		await process_frame
		return
	player.position = Vector2(96.0, 180.0)
	world.add_child(player)
	await process_frame
	_disable_player_camera(player)
	player.call("configure_character", "robot", str(pack["weapon_id"]))
	await process_frame

	var enemies := _spawn_real_enemies(world, victim_count(pack, mode))
	_expect(not enemies.is_empty(), "%s must instantiate real EnemySpitter targets" % context, errors)
	if enemies.is_empty():
		PlayerHost.reset(player)
		world.queue_free()
		current_scene = null
		await process_frame
		return
	var source_enemy := enemies[0]
	source_enemy.call("_spawn_elite_hazard", Vector2(500.0, 180.0))
	var hazard := world.get_node_or_null("ElitePoisonZone") as Node2D
	_expect(hazard != null and hazard.is_in_group("enemy_hazards"), "%s must create a real Enemy elite hazard state" % context, errors)
	_expect(hazard != null and hazard.get_node_or_null("HazardTelegraph") != null, "%s must retain the shipped hazard telegraph" % context, errors)

	var host := PlayerHost.for_player(player)
	host.set("_presentation_headless_mode", 0)
	player.set("ultimate_charge", player.get("ultimate_max_charge"))
	_expect(bool(player.call("activate_ultimate")), "%s must start through Player.activate_ultimate" % context, errors)
	var activation = host.controller().active_activation()
	_expect(activation != null, "%s must retain an active Player-owned ultimate activation" % context, errors)
	if activation != null:
		_pause_activation(activation)
	## Consume the production scene's deferred autoplay once, then drive the
	## exact executor tween without wall-clock timing and seek the V2 scene.
	await process_frame
	var presentation = host.get("_presentation")
	var scene := presentation.get("_scene") as Node2D if presentation != null else null
	_expect(scene != null and scene.get_parent() == world, "%s must parent the shipped scene through the Player host" % context, errors)
	if scene != null:
		if activation != null:
			_advance_activation(activation, runtime_execution_seconds(pack, phase))
		seek_scene(scene, float((pack["beats"] as Dictionary)[phase]))
		if bool(mode["photosafe"]):
			apply_photosafe(scene)
		_check_live_scene(scene, pack, mode, Vector2i(640, 360), context, errors)
		_check_real_hud(world, player, str(pack["weapon_id"]), context, errors)
		if phase != "release":
			_check_real_victim_impact(scene, enemies, context, errors)
	PlayerHost.reset(player)
	world.queue_free()
	current_scene = null
	await process_frame


func _check_real_victim_impact(scene: Node2D, enemies: Array[Node2D], context: String, errors: Array[String]) -> void:
	var impacts: ImpactPlayer = null
	for child in scene.get_children():
		if child is ImpactPlayer:
			impacts = child as ImpactPlayer
			break
	## The Robot executor can finish an impact player before a later capture
	## beat. Validate it when retained; the class presentation gate separately
	## proves every canonical mapping and the certification cell already proves
	## the real activation, targets, hazard, scene, and HUD path.
	if impacts != null:
		impacts.advance(0.12)
		var snapshot := impacts.snapshot()
		_expect(int(snapshot.get("victims", 0)) > 0, "%s must retain at least one actual capture enemy in the live impact channel" % context, errors)
		_expect(int(snapshot.get("created_nodes", 0)) > 0, "%s must create live victim-impact feedback" % context, errors)
		impacts.set_paused(true)


func _check_real_hud(world: Node2D, player: Node2D, weapon_id: String, context: String, errors: Array[String]) -> void:
	var hud_root := Control.new()
	hud_root.name = "RobotCertificationHudFixture"
	hud_root.size = Vector2(640.0, 360.0)
	world.add_child(hud_root)
	var adapter := HudAdapter.new()
	hud_root.add_child(adapter)
	_expect(adapter.mount(hud_root, player), "%s must mount the shipped HUD adapter" % context, errors)
	adapter.refresh()
	var widget := hud_root.get_node_or_null("UltimateHudWidget") as Control
	_expect(widget != null and widget.has_method("state"), "%s must create the shipped UltimateHudWidget" % context, errors)
	if widget == null:
		return
	var state: Dictionary = widget.call("state")
	var selection := state.get("selection", {}) as Dictionary
	_expect(str(selection.get("class_id", "")) == "robot" and str(selection.get("weapon_id", "")) == weapon_id,
		"%s HUD must read the actual Player selection" % context, errors)
	_expect(bool((state.get("charge", {}) as Dictionary).get("active", false)),
		"%s HUD must read the actual Player active state" % context, errors)


func _spawn_real_enemies(world: Node2D, count: int) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for index in count:
		var enemy := EnemySpitterScene.instantiate() as Node2D
		if enemy == null:
			continue
		enemy.position = Vector2(260.0 + float(index % 6) * 52.0, 90.0 + float(index / 6) * 68.0)
		enemy.set("max_health", ENEMY_CAPTURE_HEALTH)
		enemy.set("health", ENEMY_CAPTURE_HEALTH)
		world.add_child(enemy)
		enemy.set("max_health", ENEMY_CAPTURE_HEALTH)
		enemy.set("health", ENEMY_CAPTURE_HEALTH)
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	return enemies


func _pause_activation(activation) -> void:
	for tween in activation.tweens_for_tests():
		if tween != null and tween.is_valid():
			tween.pause()


func _advance_activation(activation, seconds: float) -> void:
	var tweens: Array = activation.tweens_for_tests()
	for tween in tweens:
		if tween != null and tween.is_valid():
			tween.play()
	var elapsed := 0.0
	while elapsed < seconds:
		var step := minf(CAPTURE_STEP, seconds - elapsed)
		for tween in tweens:
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step
	_pause_activation(activation)


func _disable_player_camera(player: Node2D) -> void:
	for raw_camera in player.find_children("*", "Camera2D", true, false):
		var camera := raw_camera as Camera2D
		if camera != null:
			camera.enabled = false


static func manifest_violations(manifest: Dictionary, profile: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("capture manifest is empty")
		return errors
	if int(manifest.get("schema_version", 0)) != 1:
		errors.append("schema_version must be 1")
	if str(manifest.get("issue", "")) != "FAN-3944":
		errors.append("issue must be FAN-3944")
	if str(manifest.get("class_id", "")) != "robot":
		errors.append("class_id must be robot")
	if str(manifest.get("capture_script", "")) != LIVE_CAPTURE_SCRIPT:
		errors.append("capture_script must name the windowed Robot renderer")
	if str(manifest.get("focused_test", "")) != "tests/ultimates/presentation/robot_certification_capture_test.gd":
		errors.append("focused_test must name this certification gate")
	if not FileAccess.file_exists("res://" + str(manifest.get("capture_script", ""))):
		errors.append("capture_script must exist")
	if not FileAccess.file_exists("res://" + str(manifest.get("focused_test", ""))):
		errors.append("focused_test must exist")

	var source := manifest.get("capture_source", {}) as Dictionary
	if str(source.get("source_ref", "")).is_empty():
		errors.append("capture_source.source_ref must identify the capture ref")
	if not _is_git_sha(str(source.get("source_commit_sha", ""))):
		errors.append("capture_source.source_commit_sha must pin a non-self-referential source commit")
	if not _is_git_sha(str(source.get("source_tree_sha", ""))):
		errors.append("capture_source.source_tree_sha must pin the source tree")
	if int(source.get("controlled_seed", -1)) != CAPTURE_SEED:
		errors.append("capture_source.controlled_seed must pin the controlled renderer seed")
	for key in ["godot_version", "renderer", "capture_method", "command", "workload_exclusion"]:
		if str(source.get(key, "")).is_empty():
			errors.append("capture_source.%s must be recorded" % key)
	if not str(source.get("command", "")).contains("--windowed"):
		errors.append("capture_source.command must preserve the windowed capture method")
	if not str(source.get("command", "")).contains("FSD_GODOT_EXCLUSIVE=1"):
		errors.append("capture_source.command must record exclusive Godot admission")
	if not str(source.get("capture_method", "")).contains("Player.activate_ultimate"):
		errors.append("capture_source.capture_method must name the real Player activation path")

	var declared_weapons := _string_array(manifest.get("canonical_weapon_ids"))
	if declared_weapons != WEAPON_IDS:
		errors.append("canonical_weapon_ids must be %s, got %s" % [WEAPON_IDS, declared_weapons])
	var profile_weapons := _profile_weapon_ids(profile)
	if profile_weapons != WEAPON_IDS:
		errors.append("Robot profile must still expose %s, got %s" % [WEAPON_IDS, profile_weapons])

	var modes := manifest.get("presentation_modes", []) as Array
	var declared_modes: Array[String] = []
	for raw_mode in modes:
		if not raw_mode is Dictionary:
			errors.append("presentation_modes entries must be objects")
			continue
		var mode := raw_mode as Dictionary
		var mode_id := str(mode.get("id", ""))
		declared_modes.append(mode_id)
		if not (mode.get("screen_shake") is bool) or not (mode.get("photosafe") is bool):
			errors.append("mode %s must declare screen_shake and photosafe booleans" % mode_id)
		if str(mode.get("crowd", "")).is_empty():
			errors.append("mode %s must name its crowd configuration" % mode_id)
	if declared_modes != MODE_IDS:
		errors.append("presentation_modes must be %s, got %s" % [MODE_IDS, declared_modes])

	var matrix := manifest.get("coverage_matrix", {}) as Dictionary
	if _string_array(matrix.get("rows")) != WEAPON_IDS:
		errors.append("coverage_matrix.rows must enumerate the canonical weapon keys")
	if _string_array(matrix.get("columns")) != MODE_IDS:
		errors.append("coverage_matrix.columns must enumerate the four presentation modes")
	if int(matrix.get("cells_per_viewport", 0)) != WEAPON_IDS.size() * MODE_IDS.size():
		errors.append("coverage_matrix must contain all twelve weapon/mode cells per viewport")
	if _string_array(matrix.get("phases")) != PHASE_IDS:
		errors.append("coverage_matrix.phases must enumerate release, active and recovery")
	if int(matrix.get("captures_per_viewport", 0)) != PHASE_IDS.size():
		errors.append("coverage_matrix must retain one phase sheet per readability beat")
	var beat_observations := matrix.get("readability_beats", {}) as Dictionary
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		var beats := beat_observations.get(str(pack["weapon_id"]), {}) as Dictionary
		for phase in ["release", "active", "recovery"]:
			if not beats.has(phase) or float(beats.get(phase, -1.0)) <= 0.0:
				errors.append("coverage_matrix.readability_beats.%s.%s must be a positive capture second" % [str(pack["weapon_id"]), phase])

	var configuration := manifest.get("runtime_configuration", {}) as Dictionary
	if str(configuration.get("player_scene", "")) != PLAYER_SCENE_PATH:
		errors.append("runtime_configuration.player_scene must use the shipped Player.tscn")
	if str(configuration.get("enemy_scene", "")) != ENEMY_SCENE_PATH:
		errors.append("runtime_configuration.enemy_scene must use the shipped EnemySpitter.tscn")
	if str(configuration.get("hazard_runtime", "")) != "EnemySpitter._spawn_elite_hazard":
		errors.append("runtime_configuration.hazard_runtime must use the shipped Enemy elite hazard")
	if str(configuration.get("hud_adapter", "")) != HUD_ADAPTER_PATH:
		errors.append("runtime_configuration.hud_adapter must use the shipped HUD runtime adapter")
	if _string_array(configuration.get("scene_paths")) != _pack_scene_paths():
		errors.append("runtime_configuration.scene_paths must enumerate the shipped Robot trio")

	var viewports := manifest.get("viewports", []) as Array
	var by_id := _viewports_by_id(viewports)
	if by_id.size() != CAPTURES.size():
		errors.append("viewports must have one unique record per viewport/phase sheet")
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		var capture_id := str(capture["id"])
		var record := by_id.get(capture_id, {}) as Dictionary
		var expected_size := capture["size"] as Vector2i
		if record.is_empty():
			errors.append("viewport %s is missing" % capture_id)
			continue
		if int(record.get("width", 0)) != expected_size.x or int(record.get("height", 0)) != expected_size.y:
			errors.append("viewport %s must be %dx%d" % [capture_id, expected_size.x, expected_size.y])
		if str(record.get("path", "")) != str(capture["path"]):
			errors.append("viewport %s must use the class-owned LFS path" % capture_id)
		if str(record.get("viewport_id", "")) != str(capture["viewport_id"]):
			errors.append("viewport %s must retain its resolution identity" % capture_id)
		if str(record.get("phase", "")) != str(capture["phase"]):
			errors.append("viewport %s must retain its named readability phase" % capture_id)
		if not _is_sha256(str(record.get("sha256", ""))):
			errors.append("viewport %s must record a sha256 hash" % capture_id)
	return errors


static func capture_file_violations(viewports: Array) -> Array[String]:
	var errors: Array[String] = []
	var expected_by_id := {}
	for raw_capture in CAPTURES:
		var capture := raw_capture as Dictionary
		expected_by_id[str(capture["id"])] = capture
	for raw_record in viewports:
		if not raw_record is Dictionary:
			errors.append("viewport record is not an object")
			continue
		var record := raw_record as Dictionary
		var capture := expected_by_id.get(str(record.get("id", "")), {}) as Dictionary
		if capture.is_empty():
			continue
		var path := str(record.get("path", ""))
		if not FileAccess.file_exists(path):
			errors.append("capture PNG is missing: %s" % path)
			continue
		if is_lfs_pointer(path):
			errors.append("capture PNG is an unsmudged LFS pointer: %s" % path)
			continue
		var expected_size := capture["size"] as Vector2i
		for violation in png_ihdr_violations(path, expected_size):
			errors.append("capture PNG invalid: %s (%s)" % [path, violation])
		var image := Image.load_from_file(path)
		if image == null or image.is_empty() or image.get_size() != expected_size:
			errors.append("capture PNG must decode at the declared native size: %s" % path)
		var actual_hash := FileAccess.get_sha256(path).to_lower()
		if actual_hash != str(record.get("sha256", "")).to_lower():
			errors.append("capture PNG sha256 does not match the manifest: %s" % path)
	return errors


static func prepare_scene(tree: SceneTree, pack: Dictionary, mode: Dictionary, seconds: float) -> Node2D:
	tree.root.set_meta("screen_shake", bool(mode.get("screen_shake", true)))
	var scene := instantiate_scene(pack)
	## Every shipped V2 scene declares AnimationPlayer autoplay. Godot schedules
	## that start after `add_child()`, so a pre-tree disarm is required before a
	## fixed certification seek can be stable across renderer frame pacing.
	arm_scene_for_capture(scene)
	tree.root.add_child(scene)
	seek_scene(scene, seconds)
	if scene.has_method("_fit_backdrop_to_viewport"):
		scene.call("_fit_backdrop_to_viewport")
	if bool(mode.get("photosafe", false)):
		apply_photosafe(scene)
	return scene


static func instantiate_scene(pack: Dictionary) -> Node2D:
	return (pack["scene"] as PackedScene).instantiate() as Node2D


static func arm_scene_for_capture(scene: Node2D) -> void:
	if scene == null:
		return
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline == null:
		return
	## Clearing autoplay rather than merely stopping the current animation is
	## intentional: stop/pause alone loses to the deferred autoplay callback.
	timeline.autoplay = &""
	timeline.stop()


static func seek_scene(scene: Node2D, seconds: float) -> void:
	if scene.has_method("seek_for_capture"):
		scene.call("seek_for_capture", seconds)
		return
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline == null:
		return
	## `AnimationPlayer.autoplay` is writable only before the scene enters the
	## tree. Live Player-hosted scenes settle their one deferred start before
	## this method is called; direct capture scenes are disarmed pre-tree by
	## `prepare_scene()` above.
	if not scene.is_inside_tree():
		arm_scene_for_capture(scene)
	timeline.stop()
	timeline.play(&"ultimate")
	timeline.seek(seconds, true)
	timeline.pause()
	## The timeline assigns the authored frame, but the V2 scenes also use
	## AnimatedSprite2D for that frame. Pause those clocks explicitly after the
	## seek: otherwise they continue on real frame time while the parent driver
	## is held, making the saved pixels depend on renderer pacing.
	for raw_sprite in scene.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite != null:
			sprite.pause()
	scene.set_process(false)


static func apply_photosafe(scene: Node2D) -> void:
	var veil := scene.get_node_or_null("BackdropVeil") as CanvasItem
	if veil != null:
		veil.visible = false
		veil.self_modulate = Color(veil.self_modulate.r, veil.self_modulate.g, veil.self_modulate.b, 0.0)


static func release_scene(scene: Node2D) -> void:
	if scene == null:
		return
	if scene.has_method("finish"):
		scene.call("finish", "node_end")
	if scene.get_parent() != null:
		scene.get_parent().remove_child(scene)
	scene.free()


static func victim_count(pack: Dictionary, mode: Dictionary) -> int:
	return int(pack.get("crowd_cap", 0)) if bool(mode.get("crowded", false)) else 3


## The presentation recovery beat can intentionally outlast the gameplay
## executor's cleanup duration (Blast Powder is the concrete case). The capture
## holds a real, still-active Player cast at its latest meaningful execution
## state, then seeks only the authored visual timeline to inspect recovery.
## This prevents controller teardown from deleting the very recovery frame a
## reviewer needs while preserving the real Player/Enemy/HUD composition.
static func runtime_execution_seconds(pack: Dictionary, phase: String) -> float:
	var beats := pack.get("beats", {}) as Dictionary
	var requested := float(beats.get(phase, 0.0))
	if phase == "recovery":
		return minf(requested, float(beats.get("active", requested)))
	return requested


static func grid_rect(size: Vector2i) -> Rect2:
	var left := float(size.x) * GRID_LEFT_RATIO
	var top := float(size.y) * GRID_TOP_RATIO
	return Rect2(
		Vector2(left, top),
		Vector2(float(size.x) * GRID_RIGHT_RATIO - left, float(size.y) * GRID_BOTTOM_RATIO - top)
	)


static func panel_rect(size: Vector2i, weapon_index: int, mode_index: int) -> Rect2:
	var grid := grid_rect(size)
	var gap := Vector2(float(size.x) * GRID_GAP_X_RATIO, float(size.y) * GRID_GAP_Y_RATIO)
	var cell := Vector2(
		(grid.size.x - gap.x * float(MODE_IDS.size() - 1)) / float(MODE_IDS.size()),
		(grid.size.y - gap.y * float(WEAPON_IDS.size() - 1)) / float(WEAPON_IDS.size())
	)
	return Rect2(grid.position + Vector2(float(mode_index) * (cell.x + gap.x), float(weapon_index) * (cell.y + gap.y)), cell)


static func arena_rect(size: Vector2i, weapon_index: int, mode_index: int) -> Rect2i:
	var panel := panel_rect(size, weapon_index, mode_index)
	var margin := maxf(2.0, float(size.y) * PANEL_MARGIN_RATIO)
	var label_height := panel.size.y * PANEL_LABEL_RATIO
	var position := panel.position + Vector2(margin, label_height + margin)
	var arena_size := panel.end - Vector2(margin, margin) - position
	return Rect2i(Vector2i(position.floor()), Vector2i(arena_size.floor()))


static func mode_marker_probe(size: Vector2i, weapon_index: int, mode_index: int) -> Vector2i:
	var panel := panel_rect(size, weapon_index, mode_index)
	var inset := maxf(3.0, float(size.y) * 0.006)
	return Vector2i(roundi(panel.position.x + inset), roundi(panel.position.y + inset))


static func player_rect(arena_size: Vector2i) -> Rect2:
	var body := body_rect(arena_size)
	return Rect2(Vector2.ZERO, Vector2(float(arena_size.x) * PLAYER_COLUMN_RATIO, body.size.y)).grow(-2.0)


static func hazard_rects(arena_size: Vector2i) -> Array[Rect2]:
	var body := body_rect(arena_size)
	var width := float(arena_size.x) * HAZARD_COLUMN_RATIO
	var height := body.size.y * 0.26
	var left := float(arena_size.x) - width
	return [
		Rect2(Vector2(left, body.position.y + body.size.y * 0.10), Vector2(width, height)).grow(-2.0),
		Rect2(Vector2(left, body.position.y + body.size.y * 0.60), Vector2(width, height)).grow(-2.0),
	]


static func state_band_rect(arena_size: Vector2i) -> Rect2:
	var height := float(arena_size.y) * STATE_BAND_RATIO
	return Rect2(Vector2(0.0, float(arena_size.y) - height), Vector2(float(arena_size.x), height))


static func body_rect(arena_size: Vector2i) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(float(arena_size.x), state_band_rect(arena_size).position.y))


static func effect_zone(arena_size: Vector2i) -> Rect2:
	var body := body_rect(arena_size)
	var left := float(arena_size.x) * PLAYER_COLUMN_RATIO
	var right := float(arena_size.x) * (1.0 - HAZARD_COLUMN_RATIO)
	return Rect2(Vector2(left, body.position.y), Vector2(right - left, body.size.y))


static func readability_bands(arena_size: Vector2i) -> Dictionary:
	var bands := {"player column": player_rect(arena_size), "state caption": state_band_rect(arena_size)}
	var hazards := hazard_rects(arena_size)
	for index in hazards.size():
		bands["hazard %d" % index] = hazards[index]
	return bands


## The fullscreen veil is intentionally excluded: it is the subject of the
## photosensitivity mode, not the formation that needs to fit the middle zone.
static func layout_scene(scene: Node2D, arena_size: Vector2i) -> Rect2:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := content_bounds(scene)
	if not bounds.has_area():
		return Rect2()
	var zone := effect_zone(arena_size)
	var scale := minf(zone.size.x / bounds.size.x, zone.size.y / bounds.size.y)
	scene.scale = Vector2.ONE * scale
	scene.position = zone.get_center() - bounds.get_center() * scale
	return Rect2(bounds.position * scale + scene.position, bounds.size * scale)


static func content_bounds(scene: Node2D) -> Rect2:
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			if not child is CanvasItem:
				continue
			var item := child as CanvasItem
			if not is_content_item(item, scene):
				continue
			var item_bounds := item_bounds(scene, item)
			if not item_bounds.has_area():
				continue
			bounds = item_bounds if not found else bounds.merge(item_bounds)
			found = true
	return bounds


static func is_content_item(item: CanvasItem, scene: Node2D) -> bool:
	if item.name == &"BackdropVeil" or bool(item.get_meta("fullscreen_layer", false)):
		return false
	var cursor: Node = item
	while cursor != null and cursor != scene:
		## Victim impacts are real runtime feedback, but their top-level sprites
		## are positioned on live enemies rather than authored V2 scene content.
		## They must remain visible in a capture, not participate in the bounds
		## used to scale and place that authored scene.
		if cursor is ImpactPlayer:
			return false
		if cursor is CanvasItem:
			var canvas_item := cursor as CanvasItem
			if not canvas_item.visible or canvas_item.modulate.a * canvas_item.self_modulate.a <= 0.01:
				return false
		cursor = cursor.get_parent()
	return true


static func item_bounds(scene: Node2D, item: CanvasItem) -> Rect2:
	var local := Rect2()
	if item is Sprite2D:
		local = (item as Sprite2D).get_rect()
	elif item is AnimatedSprite2D:
		var sprite := item as AnimatedSprite2D
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			if texture != null:
				local = Rect2(-Vector2(texture.get_size()) * 0.5, Vector2(texture.get_size()))
	elif item is Polygon2D:
		local = rect_from_points((item as Polygon2D).polygon)
	elif item is Line2D:
		local = rect_from_points((item as Line2D).points).grow((item as Line2D).width * 0.5)
	if not local.has_area():
		return Rect2()
	var transform := Transform2D.IDENTITY
	var cursor: Node = item
	while cursor != null and cursor != scene:
		if cursor is Node2D:
			transform = (cursor as Node2D).transform * transform
		cursor = cursor.get_parent()
	return rect_from_points(PackedVector2Array([
		transform * local.position,
		transform * Vector2(local.end.x, local.position.y),
		transform * local.end,
		transform * Vector2(local.position.x, local.end.y),
	]))


static func rect_from_points(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func png_ihdr_violations(path: String, expected_size: Vector2i) -> Array[String]:
	var errors: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24:
		errors.append("truncated")
		return errors
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if file.get_buffer(8) != signature:
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
		errors.append("ihdr_size:%dx%d" % [width, height])
	return errors


static func is_lfs_pointer(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var prefix := LFS_POINTER_PREFIX.to_utf8_buffer()
	var head := file.get_buffer(prefix.size())
	file.close()
	return head == prefix


static func _viewports_by_id(raw_viewports: Array) -> Dictionary:
	var result := {}
	for raw_record in raw_viewports:
		if raw_record is Dictionary:
			var record := raw_record as Dictionary
			var record_id := str(record.get("id", ""))
			if not record_id.is_empty() and not result.has(record_id):
				result[record_id] = record
	return result


static func _profile_weapon_ids(profile: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_entry in profile.get("profiles", []) as Array:
		if raw_entry is Dictionary:
			ids.append(str((raw_entry as Dictionary).get("weapon_id", "")))
	return ids


static func _pack_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	for raw_pack in PACKS:
		paths.append(str((raw_pack as Dictionary)["scene_path"]))
	return paths


static func _string_array(raw: Variant) -> Array[String]:
	var values: Array[String] = []
	if raw is Array:
		for value in raw as Array:
			values.append(str(value))
	return values


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character.to_lower()):
			return false
	return true


static func _is_git_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character.to_lower()):
			return false
	return true


static func _color_near(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.06 \
		and absf(actual.g - expected.g) <= 0.06 \
		and absf(actual.b - expected.b) <= 0.06 \
		and absf(actual.a - expected.a) <= 0.06


func _can_verify_windowed_capture_files() -> bool:
	## A headless renderer cannot certify a SubViewport image, and CI can retain
	## LFS pointer placeholders. The windowed focused run is the only evidence
	## validator; structural and explicit negative checks still run headlessly.
	return DisplayServer.get_name() != "headless"


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		errors.append("%s must contain an object" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("Robot certification capture gate: 4 viewports x 3 weapons x 4 modes x release/active/recovery verified")
		quit(0)
		return
	for error in errors:
		push_error("Robot certification capture gate: %s" % error)
	quit(1)
