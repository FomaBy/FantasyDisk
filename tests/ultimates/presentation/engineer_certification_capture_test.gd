extends SceneTree

## Headless integrity and live-composition gate for FAN-3939's windowed
## Engineer certification evidence. The paired windowed renderer writes PNGs;
## this script proves the evidence matrix, provenance, fail-closed artifact
## checks, and the actual Player-owned context behind every named mode.

const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemySpitterScene := preload("res://scenes/EnemySpitter.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")

const ISSUE_ID := "FAN-3939"
const CLASS_ID := "engineer"
const PROFILE_PATH := "res://data/ultimates/schema/v1/classes/engineer.json"
const CLASS_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/engineer/manifest.json"
const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/engineer/certification_capture_manifest.json"
const LIVE_CAPTURE_SCRIPT := "tests/ultimates/presentation/engineer_certification_live_capture.gd"
const CAPTURE_ROOT := "res://docs/design/reference-assets-lfs/ultimate-certification/engineer"
const PLAYER_SCENE_PATH := "res://scenes/Player.tscn"
const ENEMY_SCENE_PATH := "res://scenes/EnemySpitter.tscn"
const HUD_ADAPTER_PATH := "res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd"
const LFS_POINTER_PREFIX := "version https://git-lfs.github.com/spec/v1"
const CAPTURE_SEED := 3939
const CAPTURE_STEP := 0.01
## Frames are sampled just inside their named presentation phase. This avoids
## an exact Tween callback boundary while preserving the authored beat label.
const CAPTURE_PHASE_INTERIOR_OFFSET_SECONDS := 0.071
const ENEMY_CAPTURE_HEALTH := 100000.0
const CAPTURE_COUNT := 48
## This is one of Pressure Mines' declared seeded-annulus coordinates. The
## first real target stands on it so every viewport exercises the real smart
## trigger instead of relying on a resolution-dependent distant target.
const PRESSURE_MINE_TRIGGER_OFFSET := Vector2(125.21, 103.19)
## The real poison telegraph begins fully transparent. The capture freezes
## renderer clocks, so it pins the already-spawned production layers to these
## authored post-fade values before readback instead of stepping the hazard's
## unrelated lifetime/detonation tweens.
const HAZARD_TELEGRAPH_INITIAL_SCALE := 0.70
const HAZARD_TELEGRAPH_ZONE_ALPHA := 0.62
const HAZARD_TELEGRAPH_RIM_ALPHA := 0.90
const HAZARD_VISIBILITY_PROBE_METHOD := "frozen visible-vs-hidden native-frame pixel delta"
const HAZARD_DELTA_SAMPLE_STRIDE := 2
const HAZARD_DELTA_CHANNEL_THRESHOLD := 0.10
const HAZARD_MIN_DELTA_SAMPLE_COUNT := 120
const HAZARD_MIN_DELTA_BOUNDS := Vector2i(80, 80)
const HAZARD_CAPTURE_X_RATIO := 0.84
const HAZARD_CAPTURE_Y_RATIO := 0.69
const HAZARD_PROBE_HALF_EXTENT := 110

const WEAPON_IDS: Array[String] = [
	"engineer_sentry_wrench",
	"engineer_repair_drone",
	"engineer_pressure_mines",
]
const MODE_IDS: Array[String] = ["normal", "crowded", "reduced_motion", "photosensitivity_safe"]
const VIEWPORTS: Array[Dictionary] = [
	{"id": "648p", "size": Vector2i(1152, 648)},
	{"id": "720p", "size": Vector2i(1280, 720)},
	{"id": "1080p", "size": Vector2i(1920, 1080)},
	{"id": "2k", "size": Vector2i(2560, 1440)},
]

## `crowded` is deliberately a real-target load condition, not an invented
## persisted presentation key. The other two booleans are the exact persisted
## GameSettings/UltimateAccessibilitySettings options consumed by Engineer.
const MODES: Array[Dictionary] = [
	{
		"id": "normal", "beat": "active", "victims": 3,
		"reduced_motion": false, "photosensitivity_safe": false,
		"crowd": "three real EnemySpitter targets",
	},
	{
		"id": "crowded", "beat": "release", "victims": 39,
		"reduced_motion": false, "photosensitivity_safe": false,
		"crowd": "thirty-nine real EnemySpitter targets",
	},
	{
		"id": "reduced_motion", "beat": "active", "victims": 3,
		"reduced_motion": true, "photosensitivity_safe": false,
		"crowd": "three real EnemySpitter targets",
	},
	{
		"id": "photosensitivity_safe", "beat": "recovery", "victims": 3,
		"reduced_motion": false, "photosensitivity_safe": true,
		"crowd": "three real EnemySpitter targets",
	},
]

const PACKS: Array[Dictionary] = [
	{
		"weapon_id": "engineer_sentry_wrench",
		"scene_path": "scenes/vfx/ultimates/engineer/EngineerSentryWrenchUltimate.tscn",
		"required_node": "SentryNest",
		"beats": {"release": 0.8, "active": 1.15, "recovery": 3.1},
	},
	{
		"weapon_id": "engineer_repair_drone",
		"scene_path": "scenes/vfx/ultimates/engineer/EngineerRepairDroneUltimate.tscn",
		"required_node": "DroneSwarm",
		"beats": {"release": 0.7, "active": 1.2, "recovery": 3.35},
	},
	{
		"weapon_id": "engineer_pressure_mines",
		"scene_path": "scenes/vfx/ultimates/engineer/EngineerPressureMinesUltimate.tscn",
		"required_node": "MineField",
		"beats": {"release": 0.9, "active": 1.7, "recovery": 3.1},
	},
]


func _initialize() -> void:
	var errors: Array[String] = []
	var manifest := _load_json(CAPTURE_MANIFEST_PATH, errors)
	var profile := _load_json(PROFILE_PATH, errors)
	var class_manifest := _load_json(CLASS_MANIFEST_PATH, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	_check_renderer_source(errors)
	for violation in manifest_violations(manifest, profile):
		errors.append(violation)
	_check_class_manifest(class_manifest, errors)
	for violation in capture_file_violations(manifest.get("samples", []) as Array):
		errors.append(violation)
	_check_negative_probes(manifest, profile, errors)
	if not errors.is_empty():
		_finish(errors)
		return
	await _check_live_runtime(errors)
	_finish(errors)


## F1/F2/F3 regressions are rejected by the code contract as well as by the
## rendered assets. This prevents an image-only handoff from silently replacing
## the real mode/Player/HUD/hazard path with a fixture again.
func _check_renderer_source(errors: Array[String]) -> void:
	var source := FileAccess.get_file_as_string("res://" + LIVE_CAPTURE_SCRIPT)
	for required in [
		"const Accessibility",
		"const PlayerScene",
		"const EnemySpitterScene",
		"const HudAdapter",
		"Accessibility.apply_settings",
		"Player.activate_ultimate",
		"_spawn_elite_hazard",
		"UltimateHudRuntimeAdapter",
		"timeline.pause()",
		"AnimatedSprite2D",
		"UPDATE_DISABLED",
		"_has_real_enemy_damage",
		"_has_visible_scene_victim_impact",
		"_hide_queued_pressure_mine_devices",
		"_hold_player_capture_pose",
		"_hide_nonultimate_root_visuals",
		"materialize_hazard_telegraph",
		"_render_hazard_visibility_probe",
		"hazard_visibility_probe_is_readable",
		"hazard_visibility",
		"is_queued_for_deletion()",
		"repeat_sha256",
	]:
		_expect(source.contains(required), "live renderer must retain production/determinism contract: %s" % required, errors)
	_expect(not source.contains("Polygon2D.new()"), "live renderer must not draw a stand-in player or hazard", errors)


func _check_class_manifest(class_manifest: Dictionary, errors: Array[String]) -> void:
	_expect(str(class_manifest.get("class_id", "")) == CLASS_ID, "Engineer manifest must stay class-local", errors)
	var declared_ids := _weapon_ids(class_manifest.get("weapons", []) as Array)
	var expected := WEAPON_IDS.duplicate()
	declared_ids.sort()
	expected.sort()
	_expect(declared_ids == expected, "Engineer manifest must enumerate the canonical weapon trio", errors)
	var live := (class_manifest.get("evidence", {}) as Dictionary).get("live_capture", {}) as Dictionary
	_expect(str(live.get("issue", "")) == ISSUE_ID, "class manifest must identify FAN-3939 evidence", errors)
	_expect(str(live.get("certification_manifest", "")) == CAPTURE_MANIFEST_PATH.trim_prefix("res://"), "class manifest must point to the certification manifest", errors)
	_expect(str(live.get("capture_script", "")) == LIVE_CAPTURE_SCRIPT, "class manifest must name the windowed renderer", errors)
	_expect(int(live.get("mode_count", 0)) == MODE_IDS.size(), "class manifest must record four presentation modes", errors)
	_expect(int(live.get("viewport_count", 0)) == VIEWPORTS.size(), "class manifest must record four native viewport sizes", errors)
	_expect(int(live.get("native_sample_count", 0)) == CAPTURE_COUNT, "class manifest must record all isolated native samples", errors)
	_expect(str(live.get("layout", "")) == "isolated_native_frame", "class manifest must describe non-sheet evidence", errors)


func _check_negative_probes(manifest: Dictionary, profile: Dictionary, errors: Array[String]) -> void:
	_expect(manifest_violations(manifest, profile).is_empty(), "the shipped certification manifest must pass its own schema", errors)
	var missing_mode := manifest.duplicate(true)
	(missing_mode.get("presentation_modes", []) as Array).remove_at(0)
	_expect(not manifest_violations(missing_mode, profile).is_empty(), "a missing presentation mode must fail closed", errors)
	var missing_key := manifest.duplicate(true)
	(missing_key.get("capture_source", {}) as Dictionary).erase("source_tree_sha")
	_expect(not manifest_violations(missing_key, profile).is_empty(), "a missing provenance key must fail closed", errors)
	if (manifest.get("samples", []) as Array).is_empty():
		errors.append("a valid manifest must provide a sample for artifact negative probes")
		return
	var missing_hazard_visibility := manifest.duplicate(true)
	((missing_hazard_visibility.get("samples", []) as Array)[0] as Dictionary).erase("hazard_visibility")
	_expect(not manifest_violations(missing_hazard_visibility, profile).is_empty(), "missing hazard visibility evidence must fail closed", errors)
	var invisible_hazard := manifest.duplicate(true)
	var invisible_probe := ((invisible_hazard.get("samples", []) as Array)[0] as Dictionary).get("hazard_visibility", {}) as Dictionary
	invisible_probe["delta_sample_count"] = 0
	_expect(not manifest_violations(invisible_hazard, profile).is_empty(), "an invisible hazard probe must fail closed", errors)
	var undersized_hazard_delta := manifest.duplicate(true)
	var undersized_probe := ((undersized_hazard_delta.get("samples", []) as Array)[0] as Dictionary).get("hazard_visibility", {}) as Dictionary
	undersized_probe["delta_bounds"] = {"width": HAZARD_MIN_DELTA_BOUNDS.x - 1, "height": HAZARD_MIN_DELTA_BOUNDS.y}
	_expect(not manifest_violations(undersized_hazard_delta, profile).is_empty(), "a hazard probe with insufficient bounds must fail closed", errors)
	var missing_file := manifest.duplicate(true)
	((missing_file.get("samples", []) as Array)[0] as Dictionary)["path"] = CAPTURE_ROOT + "/missing.png"
	_expect(not capture_file_violations(missing_file.get("samples", []) as Array).is_empty(), "a missing PNG must fail closed", errors)
	var first := captures()[0] as Dictionary
	_expect(not png_violations(str(first["path"]), Vector2i(1, 1)).is_empty(), "wrong PNG dimensions must fail closed", errors)
	var pointer_path := "user://fan3939_engineer_lfs_pointer.png"
	var pointer := FileAccess.open(pointer_path, FileAccess.WRITE)
	if pointer == null:
		errors.append("could not write LFS-pointer negative fixture")
		return
	pointer.store_string("%s\noid sha256:%s\nsize 1\n" % [LFS_POINTER_PREFIX, "a".repeat(64)])
	pointer.close()
	var pointer_samples := manifest.get("samples", []) as Array
	var pointer_copy := pointer_samples.duplicate(true)
	(pointer_copy[0] as Dictionary)["path"] = pointer_path
	_expect(not capture_file_violations(pointer_copy).is_empty(), "an unsmudged LFS pointer must fail closed", errors)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pointer_path))


func _check_live_runtime(errors: Array[String]) -> void:
	var registry = Registry.new(ProgressionData.WEAPONS_BY_CLASS)
	_expect(registry.is_valid(), "weapon registry must be valid for the real Player-owned capture path", errors)
	_expect(PlayerScene != null and ResourceLoader.exists(PLAYER_SCENE_PATH), "shipped Player.tscn must load", errors)
	_expect(EnemySpitterScene != null and ResourceLoader.exists(ENEMY_SCENE_PATH), "shipped EnemySpitter.tscn must load", errors)
	_expect(HudAdapter != null and ResourceLoader.exists(HUD_ADAPTER_PATH), "shipped UltimateHudRuntimeAdapter must load", errors)
	if not errors.is_empty():
		return
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		for raw_mode in MODES:
			await _check_real_runtime_cell(pack, raw_mode as Dictionary, errors)
	Accessibility.apply_settings(root, GameSettings.DEFAULTS.duplicate(true))
	root.set_meta("screen_shake", true)
	root.set_meta("combat_feedback", true)


func _check_real_runtime_cell(pack: Dictionary, mode: Dictionary, errors: Array[String]) -> void:
	var context := "%s/%s" % [str(pack["weapon_id"]), str(mode["id"])]
	_apply_persisted_options(mode)
	var world := Node2D.new()
	world.name = "EngineerCertificationRuntimeFixture"
	root.add_child(world)
	current_scene = world
	var player := PlayerScene.instantiate() as Node2D
	_expect(player != null, "%s must instantiate the real Player scene" % context, errors)
	if player == null:
		world.queue_free()
		await process_frame
		return
	player.position = Vector2(240.0, 320.0)
	world.add_child(player)
	await process_frame
	_disable_player_camera(player)
	player.call("configure_character", CLASS_ID, str(pack["weapon_id"]))
	await process_frame
	var enemies := _spawn_real_enemies(world, player.position, int(mode["victims"]))
	_expect(enemies.size() == int(mode["victims"]), "%s must retain every real capture target" % context, errors)
	var hazard := _spawn_real_hazard(world, enemies[0] if not enemies.is_empty() else null, Vector2(520.0, 300.0))
	_expect(hazard != null and hazard.is_in_group("enemy_hazards"), "%s must create a real ElitePoisonZone" % context, errors)
	_expect(hazard != null and hazard.get_node_or_null("HazardTelegraph") != null, "%s must retain the shipped hazard telegraph" % context, errors)
	if enemies.is_empty() or hazard == null:
		PlayerHost.reset(player)
		world.queue_free()
		await process_frame
		return
	_expect(not hazard_telegraph_is_visible(null), "%s must reject a missing hazard telegraph" % context, errors)
	_expect(materialize_hazard_telegraph(hazard), "%s must materialize the real telegraph before freeze" % context, errors)
	_expect(hazard_telegraph_is_visible(hazard), "%s must retain visible real telegraph layers" % context, errors)
	var telegraph := hazard.get_node_or_null("HazardTelegraph") as CanvasItem
	if telegraph != null:
		telegraph.hide()
		_expect(not hazard_telegraph_is_visible(hazard), "%s must reject a hidden real telegraph" % context, errors)
		telegraph.show()
		for layer in hazard_telegraph_layers(hazard):
			var transparent := layer.modulate
			transparent.a = 0.0
			layer.modulate = transparent
		_expect(not hazard_telegraph_is_visible(hazard), "%s must reject zero-alpha real telegraph layers" % context, errors)
		_expect(materialize_hazard_telegraph(hazard), "%s must restore the real telegraph after negative probes" % context, errors)
	for enemy in enemies:
		_freeze_actor(enemy)
	_freeze_hazard(hazard)
	var host := PlayerHost.for_player(player)
	host.set("_presentation_headless_mode", 0)
	host.set_process(false)
	player.set("ultimate_charge", player.get("ultimate_max_charge"))
	_expect(bool(player.call("activate_ultimate")), "%s must activate through Player.activate_ultimate" % context, errors)
	var controller = host.call("controller")
	var activation = controller.call("active_activation") if controller != null else null
	_expect(activation != null, "%s must retain a Player-owned activation" % context, errors)
	if activation != null:
		_pause_activation(activation)
	await process_frame
	var runtime = host.get("_presentation")
	var scene := runtime.get("_scene") as Node2D if runtime != null else null
	_expect(scene != null and scene.get_parent() == world, "%s must mount the shipped Engineer scene through PlayerHost" % context, errors)
	if scene != null:
		var state := scene.call("accessibility_state_for_tests") as Dictionary
		var applied := Accessibility.read_snapshot(root)
		_expect((state.get("modes", {}) as Dictionary) == applied, "%s must consume the persisted settings snapshot" % context, errors)
		_expect(bool(state.get("held_visuals", false)) == (bool(mode["reduced_motion"]) or bool(mode["photosensitivity_safe"])), "%s must choose the production held-mode branch", errors)
		if activation != null:
			_advance_activation(activation, runtime_execution_seconds(pack, str(mode["beat"])))
		if runtime != null:
			runtime.call("advance", float((pack["beats"] as Dictionary)[str(mode["beat"])]))
		_expect(_scene_victim_count(scene) > 0, "%s must route real victims through the shipped Engineer impact player" % context, errors)
		_check_shipped_hud(world, player, str(pack["weapon_id"]), context, errors)
		_freeze_scene_clocks(scene)
		state = scene.call("accessibility_state_for_tests") as Dictionary
		_expect(not bool(state.get("timeline_playing", true)) and not bool(state.get("sprite_playing", true)), "%s frozen evidence must stop authored clocks", errors)
		if bool(mode["reduced_motion"]) or bool(mode["photosensitivity_safe"]):
			_expect(bool(state.get("held_visuals", false)), "%s must retain production accessibility holding", errors)
	if controller != null:
		controller.call("cancel", "cancel")
	PlayerHost.reset(player)
	world.queue_free()
	current_scene = null
	await process_frame


func _apply_persisted_options(mode: Dictionary) -> void:
	var settings := GameSettings.DEFAULTS.duplicate(true)
	settings[Accessibility.REDUCED_MOTION_KEY] = bool(mode["reduced_motion"])
	settings[Accessibility.PHOTOSENSITIVITY_SAFE_KEY] = bool(mode["photosensitivity_safe"])
	Accessibility.apply_settings(root, settings)
	root.set_meta("screen_shake", not bool(mode["reduced_motion"]))
	root.set_meta("combat_feedback", true)
	root.set_meta("aim_mode", "nearest")


func _spawn_real_enemies(world: Node2D, origin: Vector2, count: int) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for index in count:
		var enemy := EnemySpitterScene.instantiate() as Node2D
		if enemy == null:
			continue
		enemy.position = origin + capture_enemy_offset(index, count)
		enemy.set("max_health", ENEMY_CAPTURE_HEALTH)
		enemy.set("health", ENEMY_CAPTURE_HEALTH)
		world.add_child(enemy)
		enemy.set("max_health", ENEMY_CAPTURE_HEALTH)
		enemy.set("health", ENEMY_CAPTURE_HEALTH)
		enemies.append(enemy)
	return enemies


func _scene_victim_count(scene: Node2D) -> int:
	for raw_child in scene.get_children():
		if raw_child is Node:
			var snapshot = raw_child.call("snapshot") if raw_child.has_method("snapshot") else null
			if snapshot is Dictionary and int((snapshot as Dictionary).get("victims", 0)) > 0:
				return int((snapshot as Dictionary).get("victims", 0))
	return 0


func _spawn_real_hazard(world: Node, source_enemy: Node2D, position: Vector2) -> Node2D:
	if source_enemy == null or not source_enemy.has_method("_spawn_elite_hazard"):
		return null
	source_enemy.call("_spawn_elite_hazard", position)
	return world.get_node_or_null("ElitePoisonZone") as Node2D


func _check_shipped_hud(world: Node2D, player: Node2D, weapon_id: String, context: String, errors: Array[String]) -> void:
	var hud_root := Control.new()
	hud_root.size = Vector2(640.0, 360.0)
	world.add_child(hud_root)
	var adapter := HudAdapter.new()
	hud_root.add_child(adapter)
	_expect(adapter.mount(hud_root, player), "%s must mount UltimateHudRuntimeAdapter" % context, errors)
	adapter.refresh()
	var widget := hud_root.get_node_or_null("UltimateHudWidget") as Control
	_expect(widget != null and widget.has_method("state"), "%s must create the shipped stateful UltimateHudWidget" % context, errors)
	if widget != null:
		var state := widget.call("state") as Dictionary
		var selection := state.get("selection", {}) as Dictionary
		_expect(str(selection.get("class_id", "")) == CLASS_ID and str(selection.get("weapon_id", "")) == weapon_id, "%s HUD must read the actual Player selection", errors)
		_expect(bool((state.get("charge", {}) as Dictionary).get("active", false)), "%s HUD must read the actual active charge state", errors)
	adapter.queue_free()


func _pause_activation(activation) -> void:
	for tween in activation.call("tweens_for_tests"):
		if tween != null and tween.is_valid():
			tween.pause()


func _advance_activation(activation, seconds: float) -> void:
	var tweens: Array = activation.call("tweens_for_tests")
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


func _freeze_scene_clocks(scene: Node2D) -> void:
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null:
		timeline.pause()
	for raw_sprite in scene.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite != null:
			sprite.pause()
	scene.set_process(false)


func _freeze_actor(actor: Node) -> void:
	if actor == null:
		return
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.set_process(false)
	actor.set_physics_process(false)
	for raw_timeline in actor.find_children("*", "AnimationPlayer", true, false):
		var timeline := raw_timeline as AnimationPlayer
		if timeline != null:
			timeline.pause()
	for raw_sprite in actor.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite != null:
			sprite.pause()


func _freeze_hazard(hazard: Node2D) -> void:
	if hazard == null:
		return
	for raw_node in hazard.find_children("*", "Node", true, false):
		var node := raw_node as Node
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	hazard.process_mode = Node.PROCESS_MODE_DISABLED


func _disable_player_camera(player: Node2D) -> void:
	for raw_camera in player.find_children("*", "Camera2D", true, false):
		var camera := raw_camera as Camera2D
		if camera != null:
			camera.enabled = false


static func captures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var viewport_id := str(viewport["id"])
		var size := viewport["size"] as Vector2i
		for raw_pack in PACKS:
			var pack := raw_pack as Dictionary
			for raw_mode in MODES:
				var mode := raw_mode as Dictionary
				var weapon_id := str(pack["weapon_id"])
				var mode_id := str(mode["id"])
				var beat := str(mode["beat"])
				var stem := "%s__%s__%s" % [weapon_id, mode_id, beat]
				result.append({
					"id": "%s--%s" % [viewport_id, stem],
					"viewport_id": viewport_id,
					"weapon_id": weapon_id,
					"mode_id": mode_id,
					"beat": beat,
					"size": size,
					"path": "%s/%s/%s.png" % [CAPTURE_ROOT, viewport_id, stem],
				})
	return result


static func manifest_document(samples: Array[Dictionary], source: Dictionary) -> Dictionary:
	var mode_records: Array[Dictionary] = []
	for raw_mode in MODES:
		var mode := raw_mode as Dictionary
		mode_records.append({
			"id": str(mode["id"]),
			"beat": str(mode["beat"]),
			"victims": int(mode["victims"]),
			"persisted_settings": {
				Accessibility.REDUCED_MOTION_KEY: bool(mode["reduced_motion"]),
				Accessibility.PHOTOSENSITIVITY_SAFE_KEY: bool(mode["photosensitivity_safe"]),
			},
			"crowd": str(mode["crowd"]),
		})
	var viewport_records: Array[Dictionary] = []
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		viewport_records.append({"id": str(viewport["id"]), "width": size.x, "height": size.y})
	var scene_paths: Array[String] = []
	for raw_pack in PACKS:
		scene_paths.append(str((raw_pack as Dictionary)["scene_path"]))
	return {
		"schema_version": 2,
		"issue": ISSUE_ID,
		"class_id": CLASS_ID,
		"capture_script": LIVE_CAPTURE_SCRIPT,
		"focused_test": "tests/ultimates/presentation/engineer_certification_capture_test.gd",
		"readability_report": "docs/design/references/weapon_ultimates/engineer/certification_readability_report.md",
		"capture_source": source,
		"canonical_weapon_ids": WEAPON_IDS,
		"presentation_modes": mode_records,
		"viewports": viewport_records,
		"runtime_configuration": {
			"player_scene": PLAYER_SCENE_PATH,
			"enemy_scene": ENEMY_SCENE_PATH,
			"hazard_runtime": "EnemySpitter._spawn_elite_hazard",
			"hud_adapter": HUD_ADAPTER_PATH,
			"scene_paths": scene_paths,
			"mode_application": "GameSettings.DEFAULTS copied into UltimateAccessibilitySettings.apply_settings before Player.activate_ultimate",
		},
		"coverage_matrix": {
			"weapons": WEAPON_IDS,
			"modes": MODE_IDS,
			"viewports": ["648p", "720p", "1080p", "2k"],
			"sample_count": CAPTURE_COUNT,
			"cells_per_viewport": WEAPON_IDS.size() * MODE_IDS.size(),
			"beats": ["release", "active", "recovery"],
			"layout": "isolated_native_frame",
		},
		"samples": samples,
	}


static func manifest_violations(manifest: Dictionary, profile: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	if int(manifest.get("schema_version", 0)) != 2:
		violations.append("schema_version")
	if str(manifest.get("issue", "")) != ISSUE_ID or str(manifest.get("class_id", "")) != CLASS_ID:
		violations.append("identity")
	if str(manifest.get("capture_script", "")) != LIVE_CAPTURE_SCRIPT:
		violations.append("capture_script")
	if str(manifest.get("focused_test", "")) != "tests/ultimates/presentation/engineer_certification_capture_test.gd":
		violations.append("focused_test")
	var source := manifest.get("capture_source", {}) as Dictionary
	for key in ["source_ref", "source_commit_sha", "source_tree_sha", "godot_version", "renderer", "capture_method", "command", "workload_exclusion"]:
		if str(source.get(key, "")).is_empty():
			violations.append("capture_source.%s" % key)
	if not str(source.get("source_ref", "")).begins_with("agent/") or not is_git_sha(str(source.get("source_commit_sha", ""))) or not is_git_sha(str(source.get("source_tree_sha", ""))):
		violations.append("capture_source.pin")
	if int(source.get("controlled_seed", -1)) != CAPTURE_SEED:
		violations.append("capture_source.controlled_seed")
	if not str(source.get("command", "")).contains("--windowed") or not str(source.get("command", "")).contains("FSD_GODOT_EXCLUSIVE=1"):
		violations.append("capture_source.windowed_command")
	if not str(source.get("capture_method", "")).contains("Player.activate_ultimate") or not str(source.get("capture_method", "")).contains("apply_settings"):
		violations.append("capture_source.runtime_path")
	var expected_weapons := WEAPON_IDS.duplicate()
	expected_weapons.sort()
	var declared_weapons := string_array(manifest.get("canonical_weapon_ids", []))
	declared_weapons.sort()
	var profile_weapons := profile_weapon_ids(profile)
	profile_weapons.sort()
	if declared_weapons != expected_weapons or profile_weapons != expected_weapons:
		violations.append("canonical_weapon_ids")
	var declared_modes := mode_ids(manifest.get("presentation_modes", []))
	if declared_modes != MODE_IDS:
		violations.append("presentation_modes")
	else:
		for index in MODES.size():
			var record := (manifest.get("presentation_modes", []) as Array)[index] as Dictionary
			var expected_mode := MODES[index] as Dictionary
			var settings := record.get("persisted_settings", {}) as Dictionary
			if str(record.get("beat", "")) != str(expected_mode["beat"]) \
					or int(record.get("victims", 0)) != int(expected_mode["victims"]) \
					or bool(settings.get(Accessibility.REDUCED_MOTION_KEY, not bool(expected_mode["reduced_motion"]))) != bool(expected_mode["reduced_motion"]) \
					or bool(settings.get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, not bool(expected_mode["photosensitivity_safe"]))) != bool(expected_mode["photosensitivity_safe"]):
				violations.append("presentation_mode:%s" % str(expected_mode["id"]))
	if not viewport_records_match(manifest.get("viewports", []) as Array):
		violations.append("viewports")
	var configuration := manifest.get("runtime_configuration", {}) as Dictionary
	if str(configuration.get("player_scene", "")) != PLAYER_SCENE_PATH \
			or str(configuration.get("enemy_scene", "")) != ENEMY_SCENE_PATH \
			or str(configuration.get("hazard_runtime", "")) != "EnemySpitter._spawn_elite_hazard" \
			or str(configuration.get("hud_adapter", "")) != HUD_ADAPTER_PATH:
		violations.append("runtime_configuration")
	if string_array(configuration.get("scene_paths", [])) != pack_scene_paths():
		violations.append("runtime_configuration.scene_paths")
	var matrix := manifest.get("coverage_matrix", {}) as Dictionary
	if string_array(matrix.get("weapons", [])) != WEAPON_IDS or string_array(matrix.get("modes", [])) != MODE_IDS \
			or int(matrix.get("sample_count", 0)) != CAPTURE_COUNT \
			or int(matrix.get("cells_per_viewport", 0)) != WEAPON_IDS.size() * MODE_IDS.size() \
			or string_array(matrix.get("beats", [])) != ["release", "active", "recovery"] \
			or str(matrix.get("layout", "")) != "isolated_native_frame":
		violations.append("coverage_matrix")
	var records := sample_records(manifest.get("samples", []) as Array)
	if records.size() != CAPTURE_COUNT:
		violations.append("sample_count")
	for raw_capture in captures():
		var capture := raw_capture as Dictionary
		var record := records.get(str(capture["id"]), {}) as Dictionary
		var size := capture["size"] as Vector2i
		var pack := pack_for_weapon(str(capture["weapon_id"]))
		if record.is_empty() \
				or str(record.get("path", "")) != str(capture["path"]) \
				or str(record.get("viewport_id", "")) != str(capture["viewport_id"]) \
				or str(record.get("weapon_id", "")) != str(capture["weapon_id"]) \
				or str(record.get("mode_id", "")) != str(capture["mode_id"]) \
				or str(record.get("beat", "")) != str(capture["beat"]) \
				or not is_equal_approx(float(record.get("sample_time_seconds", -1.0)), capture_sample_seconds(pack, str(capture["beat"]))) \
				or int(record.get("width", 0)) != size.x or int(record.get("height", 0)) != size.y \
				or str(record.get("layout", "")) != "isolated_native_frame" \
				or not is_sha256(str(record.get("sha256", ""))) \
				or str(record.get("repeat_sha256", "")) != str(record.get("sha256", "")) \
				or not hazard_visibility_probe_is_readable(record.get("hazard_visibility", {}) as Dictionary):
			violations.append("sample:%s" % str(capture["id"]))
	return violations


## The renderer preloads this script, keeping the capture-only materialization
## contract and its headless gate in one class-owned place. The two direct
## Sprite2D children are the exact zone/rim order created by HazardVfx.telegraph.
static func materialize_hazard_telegraph(hazard: Node2D) -> bool:
	if hazard == null:
		return false
	var telegraph := hazard.get_node_or_null("HazardTelegraph") as CanvasItem
	var layers := hazard_telegraph_layers(hazard)
	if telegraph == null or layers.size() != 2:
		return false
	var zone := layers[0] as Sprite2D
	var rim := layers[1] as Sprite2D
	if zone == null or rim == null:
		return false
	telegraph.show()
	zone.show()
	rim.show()
	var target_scale := zone.get_meta("fan3939_hazard_telegraph_target_scale", Vector2.ZERO) as Vector2
	if target_scale == Vector2.ZERO:
		target_scale = zone.scale / HAZARD_TELEGRAPH_INITIAL_SCALE
		zone.set_meta("fan3939_hazard_telegraph_target_scale", target_scale)
	zone.scale = target_scale
	var zone_color := zone.modulate
	zone_color.a = HAZARD_TELEGRAPH_ZONE_ALPHA
	zone.modulate = zone_color
	var rim_color := rim.modulate
	rim_color.a = HAZARD_TELEGRAPH_RIM_ALPHA
	rim.modulate = rim_color
	return hazard_telegraph_is_visible(hazard)


static func hazard_telegraph_layers(hazard: Node2D) -> Array[CanvasItem]:
	var layers: Array[CanvasItem] = []
	if hazard == null:
		return layers
	var telegraph := hazard.get_node_or_null("HazardTelegraph") as Node
	if telegraph == null:
		return layers
	for raw_child in telegraph.get_children():
		var layer := raw_child as CanvasItem
		if layer != null:
			layers.append(layer)
	return layers


static func hazard_telegraph_is_visible(hazard: Node2D) -> bool:
	if hazard == null:
		return false
	var telegraph := hazard.get_node_or_null("HazardTelegraph") as CanvasItem
	var layers := hazard_telegraph_layers(hazard)
	if telegraph == null or not telegraph.visible or telegraph.modulate.a <= 0.05 or layers.size() != 2:
		return false
	return layers[0].visible and is_equal_approx(layers[0].modulate.a, HAZARD_TELEGRAPH_ZONE_ALPHA) \
		and layers[1].visible and is_equal_approx(layers[1].modulate.a, HAZARD_TELEGRAPH_RIM_ALPHA)


static func hazard_visibility_metrics(visible_image: Image, hidden_image: Image, size: Vector2i) -> Dictionary:
	if visible_image == null or hidden_image == null or visible_image.is_empty() or hidden_image.is_empty() \
			or visible_image.get_size() != size or hidden_image.get_size() != size:
		return {}
	var anchor := hazard_capture_position(size)
	var min_x := clampi(floori(anchor.x) - HAZARD_PROBE_HALF_EXTENT, 0, size.x - 1)
	var max_x := clampi(ceili(anchor.x) + HAZARD_PROBE_HALF_EXTENT, 0, size.x - 1)
	var min_y := clampi(floori(anchor.y) - HAZARD_PROBE_HALF_EXTENT, 0, size.y - 1)
	var max_y := clampi(ceili(anchor.y) + HAZARD_PROBE_HALF_EXTENT, 0, size.y - 1)
	var changed_samples := 0
	var changed_min_x := size.x
	var changed_min_y := size.y
	var changed_max_x := -1
	var changed_max_y := -1
	for y in range(min_y, max_y + 1, HAZARD_DELTA_SAMPLE_STRIDE):
		for x in range(min_x, max_x + 1, HAZARD_DELTA_SAMPLE_STRIDE):
			var visible_pixel := visible_image.get_pixel(x, y)
			var hidden_pixel := hidden_image.get_pixel(x, y)
			var channel_delta := maxf(
				absf(visible_pixel.r - hidden_pixel.r),
				maxf(absf(visible_pixel.g - hidden_pixel.g), absf(visible_pixel.b - hidden_pixel.b))
			)
			if channel_delta < HAZARD_DELTA_CHANNEL_THRESHOLD:
				continue
			changed_samples += 1
			changed_min_x = mini(changed_min_x, x)
			changed_min_y = mini(changed_min_y, y)
			changed_max_x = maxi(changed_max_x, x)
			changed_max_y = maxi(changed_max_y, y)
	var bounds := {"width": 0, "height": 0}
	if changed_samples > 0:
		bounds = {
			"width": changed_max_x - changed_min_x + HAZARD_DELTA_SAMPLE_STRIDE,
			"height": changed_max_y - changed_min_y + HAZARD_DELTA_SAMPLE_STRIDE,
		}
	return {
		"method": HAZARD_VISIBILITY_PROBE_METHOD,
		"delta_sample_count": changed_samples,
		"delta_bounds": bounds,
		"sample_stride": HAZARD_DELTA_SAMPLE_STRIDE,
		"channel_threshold": HAZARD_DELTA_CHANNEL_THRESHOLD,
	}


static func hazard_visibility_probe_is_readable(probe: Dictionary) -> bool:
	var bounds := probe.get("delta_bounds", {}) as Dictionary
	return str(probe.get("method", "")) == HAZARD_VISIBILITY_PROBE_METHOD \
		and int(probe.get("delta_sample_count", 0)) >= HAZARD_MIN_DELTA_SAMPLE_COUNT \
		and int(bounds.get("width", 0)) >= HAZARD_MIN_DELTA_BOUNDS.x \
		and int(bounds.get("height", 0)) >= HAZARD_MIN_DELTA_BOUNDS.y \
		and int(probe.get("sample_stride", 0)) == HAZARD_DELTA_SAMPLE_STRIDE \
		and is_equal_approx(float(probe.get("channel_threshold", -1.0)), HAZARD_DELTA_CHANNEL_THRESHOLD)


static func hazard_capture_position(size: Vector2i) -> Vector2:
	return Vector2(float(size.x) * HAZARD_CAPTURE_X_RATIO, float(size.y) * HAZARD_CAPTURE_Y_RATIO)


static func capture_file_violations(samples: Array) -> Array[String]:
	var violations: Array[String] = []
	var expected := sample_records(captures())
	for raw_sample in samples:
		if not raw_sample is Dictionary:
			violations.append("sample record is not an object")
			continue
		var sample := raw_sample as Dictionary
		var capture := expected.get(str(sample.get("id", "")), {}) as Dictionary
		if capture.is_empty():
			continue
		var path := str(sample.get("path", ""))
		if not FileAccess.file_exists(path):
			violations.append("capture PNG is missing: %s" % path)
			continue
		if is_lfs_pointer(path):
			violations.append("capture PNG is an unsmudged LFS pointer: %s" % path)
			continue
		var expected_size := capture["size"] as Vector2i
		for violation in png_violations(path, expected_size):
			violations.append("capture PNG invalid: %s (%s)" % [path, violation])
		var image := Image.load_from_file(path)
		if image == null or image.is_empty() or image.get_size() != expected_size:
			violations.append("capture PNG must decode at native dimensions: %s" % path)
		if FileAccess.get_sha256(path).to_lower() != str(sample.get("sha256", "")).to_lower():
			violations.append("capture PNG sha256 must match the manifest: %s" % path)
	return violations


static func runtime_execution_seconds(pack: Dictionary, beat: String) -> float:
	var beats := pack.get("beats", {}) as Dictionary
	var requested := float(beats.get(beat, 0.0))
	return minf(requested, float(beats.get("active", requested))) if beat == "recovery" else requested


static func capture_enemy_offset(index: int, count: int) -> Vector2:
	if index == 0:
		return PRESSURE_MINE_TRIGGER_OFFSET
	var columns := mini(7, maxi(1, count))
	var rows := ceili(float(count) / float(columns))
	var column := index % columns
	var row := index / columns
	return Vector2(
		lerpf(82.0, 258.0, (float(column) + 0.5) / float(columns)),
		lerpf(-118.0, 118.0, (float(row) + 0.5) / float(rows))
	)


static func capture_sample_seconds(pack: Dictionary, beat: String) -> float:
	var beats := pack.get("beats", {}) as Dictionary
	return float(beats.get(beat, 0.0)) + CAPTURE_PHASE_INTERIOR_OFFSET_SECONDS


static func runtime_capture_seconds(pack: Dictionary, beat: String) -> float:
	var requested := capture_sample_seconds(pack, beat)
	return minf(requested, capture_sample_seconds(pack, "active")) if beat == "recovery" else requested


static func pack_for_weapon(weapon_id: String) -> Dictionary:
	for raw_pack in PACKS:
		var pack := raw_pack as Dictionary
		if str(pack.get("weapon_id", "")) == weapon_id:
			return pack
	return {}


static func png_violations(path: String, expected_size: Vector2i) -> Array[String]:
	var violations: Array[String] = []
	if not FileAccess.file_exists(path):
		violations.append("missing")
		return violations
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 24:
		violations.append("truncated")
		return violations
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	if file.get_buffer(8) != signature:
		file.close()
		violations.append("not_png_or_lfs_pointer")
		return violations
	file.big_endian = true
	var ihdr_length := file.get_32()
	var chunk_type := file.get_buffer(4).get_string_from_ascii()
	var width := file.get_32()
	var height := file.get_32()
	file.close()
	if ihdr_length != 13 or chunk_type != "IHDR":
		violations.append("missing_ihdr")
	elif width != expected_size.x or height != expected_size.y:
		violations.append("ihdr_size:%dx%d" % [width, height])
	return violations


static func is_lfs_pointer(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var prefix := LFS_POINTER_PREFIX.to_utf8_buffer()
	var head := file.get_buffer(prefix.size())
	file.close()
	return head == prefix


static func sample_records(records: Array) -> Dictionary:
	var result := {}
	for raw_record in records:
		if raw_record is Dictionary:
			var record := raw_record as Dictionary
			var id := str(record.get("id", ""))
			if not id.is_empty() and not result.has(id):
				result[id] = record
	return result


static func viewport_records_match(records: Array) -> bool:
	if records.size() != VIEWPORTS.size():
		return false
	var expected := {}
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		expected[str(viewport["id"])] = viewport["size"] as Vector2i
	for raw_record in records:
		if not raw_record is Dictionary:
			return false
		var record := raw_record as Dictionary
		var size := expected.get(str(record.get("id", "")), Vector2i.ZERO) as Vector2i
		if size == Vector2i.ZERO or int(record.get("width", 0)) != size.x or int(record.get("height", 0)) != size.y:
			return false
	return true


static func pack_scene_paths() -> Array[String]:
	var paths: Array[String] = []
	for raw_pack in PACKS:
		paths.append(str((raw_pack as Dictionary)["scene_path"]))
	return paths


static func profile_weapon_ids(profile: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw_profile in profile.get("profiles", []) as Array:
		if raw_profile is Dictionary:
			ids.append(str((raw_profile as Dictionary).get("weapon_id", "")))
	return ids


static func _weapon_ids(weapons: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw_weapon in weapons:
		if raw_weapon is Dictionary:
			ids.append(str((raw_weapon as Dictionary).get("weapon_id", "")))
	return ids


static func mode_ids(modes: Variant) -> Array[String]:
	var ids: Array[String] = []
	if modes is Array:
		for raw_mode in modes as Array:
			if raw_mode is Dictionary:
				ids.append(str((raw_mode as Dictionary).get("id", "")))
	return ids


static func string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values as Array:
			result.append(str(value))
	return result


static func is_git_sha(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value.to_lower():
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value.to_lower():
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _load_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("FAN-3939 Engineer certification capture package: PASS")
		quit(0)
		return
	for error in errors:
		push_error("FAN-3939 Engineer certification capture package: %s" % error)
	quit(1)
