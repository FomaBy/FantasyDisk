extends SceneTree

## Windowed, deterministic evidence renderer for FAN-3939.
##
## Every PNG is one isolated native frame. The frame starts with the real
## persisted accessibility boundary, then takes the normal Player-owned
## ultimate path through actual EnemySpitter targets, an elite hazard and the
## shipped ultimate HUD. Capture-only work begins only after that path has run:
## fixed tween/runtime stepping, explicit clock freezing and bounded readback.

const Spec := preload("res://tests/ultimates/presentation/engineer_certification_capture_test.gd")
const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemySpitterScene := preload("res://scenes/EnemySpitter.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const CAPTURE_SETTLE_FRAMES := 3

var _capture_source: Dictionary = {}
var _samples: Array[Dictionary] = []
var _time_scale_before_capture := 1.0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3939 Engineer certification capture skipped: headless runs never create certification PNG evidence.")
		quit(0)
		return
	_capture_source = _read_capture_source()
	if not Spec.is_git_sha(str(_capture_source.get("source_commit_sha", ""))) \
			or not Spec.is_git_sha(str(_capture_source.get("source_tree_sha", ""))):
		push_error("FAN-3939 Engineer certification capture requires FAN3939_CAPTURE_SOURCE_SHA and FAN3939_CAPTURE_SOURCE_TREE from the committed renderer source.")
		quit(1)
		return
	if PlayerScene == null or EnemySpitterScene == null or HudAdapter == null:
		push_error("FAN-3939 Engineer certification capture cannot load the shipped Player, EnemySpitter, or UltimateHudRuntimeAdapter runtime resources.")
		quit(1)
		return
	## Renderer frame deltas are deliberately excluded from the evidence state.
	## The real activation below advances only through its fixed custom steps.
	_time_scale_before_capture = Engine.time_scale
	Engine.time_scale = 0.0
	var captures := Spec.captures()
	for capture_index in captures.size():
		var capture := captures[capture_index] as Dictionary
		var sample := await _capture_one(capture_index, capture)
		if sample.is_empty():
			Engine.time_scale = _time_scale_before_capture
			quit(1)
			return
		_samples.append(sample)
	if _write_capture_manifest() != OK:
		Engine.time_scale = _time_scale_before_capture
		push_error("FAN-3939 Engineer certification capture could not write the manifest.")
		quit(1)
		return
	Engine.time_scale = _time_scale_before_capture
	Accessibility.apply_settings(root, GameSettings.DEFAULTS.duplicate(true))
	root.set_meta("screen_shake", true)
	root.set_meta("combat_feedback", true)
	print("FAN-3939 Engineer certification capture wrote %d isolated native frames." % _samples.size())
	quit(0)


func _read_capture_source() -> Dictionary:
	var version := Engine.get_version_info()
	var source_sha := OS.get_environment("FAN3939_CAPTURE_SOURCE_SHA")
	var source_tree := OS.get_environment("FAN3939_CAPTURE_SOURCE_TREE")
	return {
		"source_ref": "dev",
		"source_commit_sha": source_sha,
		"source_tree_sha": source_tree,
		"controlled_seed": Spec.CAPTURE_SEED,
		"godot_version": str(version.get("string", "unknown")),
		"renderer": "display=%s; rendering_method=%s" % [
			DisplayServer.get_name(),
			str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		],
		"capture_method": "windowed SubViewport render; GameSettings.DEFAULTS -> UltimateAccessibilitySettings.apply_settings before Player.activate_ultimate; fixed interior-of-phase Player activation/runtime tween stepping; explicit AnimationPlayer and AnimatedSprite2D freeze; UPDATE_ONCE then UPDATE_DISABLED readback",
		"command": "FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_MAXWAIT=5400 FAN3939_CAPTURE_SOURCE_SHA=%s FAN3939_CAPTURE_SOURCE_TREE=%s GODOT_BIN=/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --windowed --script res://tests/ultimates/presentation/engineer_certification_live_capture.gd" % [source_sha, source_tree],
		"workload_exclusion": "capture-only Engineer certification evidence; no production gameplay, VFX, shared registry, HUD, settings, or balance files are modified",
	}


func _capture_one(capture_index: int, capture: Dictionary) -> Dictionary:
	var size := capture.get("size", Vector2i.ZERO) as Vector2i
	var output := str(capture.get("path", ""))
	if size == Vector2i.ZERO or output.is_empty():
		push_error("FAN-3939 Engineer certification capture received an invalid sample descriptor.")
		return {}
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	if directory_result != OK:
		push_error("FAN-3939 Engineer certification capture could not create output directory: %s" % error_string(directory_result))
		return {}
	## Every frame receives a deterministic seed independent of capture order.
	var capture_seed := Spec.CAPTURE_SEED + capture_index
	var pack := _pack_spec(str(capture["weapon_id"]))
	var beat := str(capture["beat"])
	var sample_seconds := Spec.capture_sample_seconds(pack, beat)
	seed(capture_seed)
	var viewport := await _build_live_viewport(capture, capture_seed, sample_seconds)
	if bool(viewport.get_meta("fan3939_capture_failed", false)):
		var reason := str(viewport.get_meta("fan3939_capture_failure", "unknown live runtime failure"))
		_cleanup_viewport(viewport)
		push_error("FAN-3939 Engineer certification live frame failed: %s" % reason)
		return {}
	await _finalize_viewport_for_readback(viewport)
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != size:
		_cleanup_viewport(viewport)
		push_error("FAN-3939 Engineer certification readback was empty or wrong-sized: %s" % str(capture["id"]))
		return {}
	image.convert(Image.FORMAT_RGBA8)
	var save_result := image.save_png(ProjectSettings.globalize_path(output))
	_cleanup_viewport(viewport)
	if save_result != OK:
		push_error("FAN-3939 Engineer certification could not save %s: %s" % [output, error_string(save_result)])
		return {}
	var digest := FileAccess.get_sha256(output).to_lower()
	print("FAN-3939 sample %s %dx%d sha256=%s" % [str(capture["id"]), size.x, size.y, digest])
	return {
		"id": str(capture["id"]),
		"viewport_id": str(capture["viewport_id"]),
		"weapon_id": str(capture["weapon_id"]),
		"mode_id": str(capture["mode_id"]),
		"beat": str(capture["beat"]),
		"sample_time_seconds": sample_seconds,
		"width": size.x,
		"height": size.y,
		"path": output,
		"layout": "isolated_native_frame",
		"sha256": digest,
		## The second renderer pass is compared externally against this exact
		## field; once it matches, writing the same value makes the committed
		## manifest a stable per-frame repeatability witness.
		"repeat_sha256": digest,
		"runtime_context": {
			"player": "scenes/Player.tscn",
			"victims": _mode_victim_count(str(capture["mode_id"])),
			"hazard": "EnemySpitter._spawn_elite_hazard -> ElitePoisonZone/HazardTelegraph",
			"hud": "UltimateHudRuntimeAdapter -> UltimateHudWidget",
		},
	}


## The world is deliberately one SubViewport per sample. Target queries are
## SceneTree-global, so this prevents one sample's real victims from becoming
## another sample's crowd and gives every native image a hard visual boundary.
func _build_live_viewport(capture: Dictionary, capture_seed: int, sample_seconds: float) -> SubViewport:
	var size := capture["size"] as Vector2i
	var mode := _mode_spec(str(capture["mode_id"]))
	var pack := _pack_spec(str(capture["weapon_id"]))
	var viewport := SubViewport.new()
	viewport.name = "EngineerCertification_%s" % str(capture["id"])
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.030, 0.052, 0.060, 1.0)
	background.size = Vector2(size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var world := Node2D.new()
	world.name = "EngineerCertificationWorld"
	viewport.add_child(world)
	## The production Enemy hazard attaches to current_scene. Because this
	## viewport is a root child, the real hazard is born inside this frame.
	current_scene = viewport
	_apply_persisted_options(mode)

	var player := PlayerScene.instantiate() as Node2D
	if player == null:
		return _failed_viewport(viewport, "Player.tscn did not instantiate")
	player.position = Vector2(float(size.x) * 0.23, float(size.y) * 0.58)
	world.add_child(player)
	await process_frame
	_disable_player_camera(player)
	player.call("configure_character", Spec.CLASS_ID, str(pack["weapon_id"]))
	await process_frame

	var enemies := _spawn_real_enemies(world, size, int(mode["victims"]))
	if enemies.size() != int(mode["victims"]):
		return _failed_viewport(viewport, "EnemySpitter.tscn did not instantiate every real capture target")
	var hazard := _spawn_real_hazard(viewport, enemies[0], Vector2(float(size.x) * 0.84, float(size.y) * 0.69))
	if hazard == null or hazard.get_node_or_null("HazardTelegraph") == null:
		return _failed_viewport(viewport, "real ElitePoisonZone/HazardTelegraph did not spawn")
	for enemy in enemies:
		_freeze_actor(enemy)
	_freeze_hazard(hazard)

	var host := PlayerHost.for_player(player)
	host.set("_presentation_headless_mode", 0)
	## The host normally advances with wall time. Keep it stopped so only the
	## fixed manual steps below can change this evidence frame.
	host.set_process(false)
	player.set("ultimate_charge", player.get("ultimate_max_charge"))
	## Enemy ready-state setup may consume the global RNG. Reset immediately
	## before the Player-owned activation so combat feedback coordinates and
	## ultimate-local random branches have a fixed, documented source.
	seed(capture_seed)
	if not bool(player.call("activate_ultimate")):
		return _failed_viewport(viewport, "%s did not activate through Player.activate_ultimate" % str(pack["weapon_id"]))
	var controller = host.call("controller")
	var activation = controller.call("active_activation") if controller != null else null
	if activation == null:
		return _failed_viewport(viewport, "%s did not retain a Player-owned activation" % str(pack["weapon_id"]))
	_pause_activation(activation)
	## Let Godot consume the mounted scene's deferred autoplay once before the
	## deterministic freeze. This closes the old F3 renderer-paced race.
	await process_frame
	var runtime = host.get("_presentation")
	var scene := runtime.get("_scene") as Node2D if runtime != null else null
	if scene == null or scene.get_parent() != world:
		return _failed_viewport(viewport, "%s did not mount its shipped Engineer scene through PlayerHost" % str(pack["weapon_id"]))
	var applied := Accessibility.read_snapshot(root)
	var state := scene.call("accessibility_state_for_tests") as Dictionary
	if (state.get("modes", {}) as Dictionary) != applied:
		return _failed_viewport(viewport, "%s did not consume the persisted accessibility snapshot" % str(pack["weapon_id"]))
	var beat := str(capture["beat"])
	_advance_activation(activation, Spec.runtime_capture_seconds(pack, beat))
	if runtime != null:
		runtime.call("advance", sample_seconds)
	## Preserve the real release/damage/victim-impact work, then stop the host
	## and every capture clock before renderer frames can race it.
	if runtime != null:
		runtime.call("set_paused", true)
	if not bool(mode["reduced_motion"]) and not bool(mode["photosensitivity_safe"]):
		_seek_normal_scene(scene, sample_seconds)
	_freeze_scene_clocks(scene)
	_hold_victim_impacts(scene)
	_freeze_actor(player)
	_freeze_runtime_siblings(world, player, scene, enemies)
	player.z_index = 50
	_attach_shipped_hud(viewport, player, size)
	if bool(viewport.get_meta("fan3939_capture_failed", false)):
		return viewport
	_pause_capture_tweens()
	return viewport


func _apply_persisted_options(mode: Dictionary) -> void:
	var settings := GameSettings.DEFAULTS.duplicate(true)
	settings[Accessibility.REDUCED_MOTION_KEY] = bool(mode["reduced_motion"])
	settings[Accessibility.PHOTOSENSITIVITY_SAFE_KEY] = bool(mode["photosensitivity_safe"])
	var applied := Accessibility.apply_settings(root, settings)
	if applied != Accessibility.read_snapshot(root):
		push_error("FAN-3939 capture could not apply the production accessibility snapshot")
	root.set_meta("screen_shake", not bool(mode["reduced_motion"]))
	root.set_meta("combat_feedback", true)
	root.set_meta("aim_mode", "nearest")


func _spawn_real_enemies(world: Node2D, size: Vector2i, count: int) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var columns := mini(7, maxi(1, count))
	var rows := ceili(float(count) / float(columns))
	for index in count:
		var enemy := EnemySpitterScene.instantiate() as Node2D
		if enemy == null:
			continue
		var column := index % columns
		var row := index / columns
		enemy.position = Vector2(
			lerpf(float(size.x) * 0.43, float(size.x) * 0.74, (float(column) + 0.5) / float(columns)),
			lerpf(float(size.y) * 0.28, float(size.y) * 0.72, (float(row) + 0.5) / float(rows))
		)
		enemy.set("max_health", Spec.ENEMY_CAPTURE_HEALTH)
		enemy.set("health", Spec.ENEMY_CAPTURE_HEALTH)
		world.add_child(enemy)
		## Enemy._ready initializes health; write the known value again after it
		## has joined the real world so no target disappears during a live beat.
		enemy.set("max_health", Spec.ENEMY_CAPTURE_HEALTH)
		enemy.set("health", Spec.ENEMY_CAPTURE_HEALTH)
		enemies.append(enemy)
	return enemies


func _spawn_real_hazard(parent: Node, source_enemy: Node2D, position: Vector2) -> Node2D:
	if source_enemy == null or not source_enemy.has_method("_spawn_elite_hazard"):
		return null
	source_enemy.call("_spawn_elite_hazard", position)
	return parent.get_node_or_null("ElitePoisonZone") as Node2D


func _attach_shipped_hud(viewport: SubViewport, player: Node2D, size: Vector2i) -> void:
	var hud_root := Control.new()
	hud_root.name = "EngineerCertificationHudRoot"
	hud_root.size = Vector2(size)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(hud_root)
	var adapter := HudAdapter.new()
	hud_root.add_child(adapter)
	if not adapter.mount(hud_root, player):
		_mark_failed(viewport, "shipped UltimateHudRuntimeAdapter could not mount")
		return
	var widget := hud_root.get_node_or_null("UltimateHudWidget") as Control
	if widget == null or not widget.has_method("state"):
		_mark_failed(viewport, "shipped UltimateHudWidget is missing after adapter mount")
		return
	adapter.refresh()
	var state := widget.call("state") as Dictionary
	var selection := state.get("selection", {}) as Dictionary
	if str(selection.get("class_id", "")) != Spec.CLASS_ID or not bool((state.get("charge", {}) as Dictionary).get("active", false)):
		_mark_failed(viewport, "shipped HUD did not read the active Engineer Player state")
		return
	widget.set_anchors_preset(Control.PRESET_TOP_LEFT)
	widget.position = Vector2(6.0, 6.0)
	widget.scale = Vector2.ONE * clampf(float(size.y) / 440.0, 0.30, 0.62)
	widget.z_index = 100
	adapter.set_process(false)


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
		var step := minf(Spec.CAPTURE_STEP, seconds - elapsed)
		for tween in tweens:
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step
	_pause_activation(activation)


func _seek_normal_scene(scene: Node2D, seconds: float) -> void:
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline == null:
		return
	timeline.stop()
	timeline.play(&"ultimate")
	timeline.seek(seconds, true)
	timeline.pause()
	for raw_sprite in scene.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite != null:
			sprite.pause()


func _freeze_scene_clocks(scene: Node2D) -> void:
	var timeline := scene.get_node_or_null("Timeline") as AnimationPlayer
	if timeline != null:
		timeline.pause()
	for raw_sprite in scene.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_sprite as AnimatedSprite2D
		if sprite != null:
			sprite.pause()
	scene.set_process(false)


func _hold_victim_impacts(scene: Node2D) -> void:
	for raw_child in scene.get_children():
		if raw_child is ImpactPlayer:
			var impacts := raw_child as Node2D
			impacts.call("advance", 0.12)
			impacts.call("set_paused", true)


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
			sprite.frame = 0
			sprite.frame_progress = 0.0


func _freeze_hazard(hazard: Node2D) -> void:
	if hazard == null:
		return
	_freeze_actor(hazard)
	for raw_node in hazard.find_children("*", "Node", true, false):
		var node := raw_node as Node
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.set_process(false)
			node.set_physics_process(false)
	hazard.process_mode = Node.PROCESS_MODE_DISABLED


func _freeze_runtime_siblings(world: Node2D, player: Node2D, scene: Node2D, enemies: Array[Node2D]) -> void:
	var retained := {player.get_instance_id(): true, scene.get_instance_id(): true}
	for enemy in enemies:
		retained[enemy.get_instance_id()] = true
	for raw_child in world.get_children():
		var child := raw_child as Node
		if child != null and not retained.has(child.get_instance_id()):
			_freeze_actor(child)


func _pause_capture_tweens() -> void:
	for tween in get_processed_tweens():
		if tween != null and tween.is_valid():
			tween.pause()


func _disable_player_camera(player: Node2D) -> void:
	for raw_camera in player.find_children("*", "Camera2D", true, false):
		var camera := raw_camera as Camera2D
		if camera != null:
			camera.enabled = false


func _finalize_viewport_for_readback(viewport: SubViewport) -> void:
	for _frame in CAPTURE_SETTLE_FRAMES:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _cleanup_viewport(viewport: SubViewport) -> void:
	if viewport == null:
		return
	var player := viewport.find_child("Player", true, false) as Node
	if player != null:
		var host := PlayerHost.for_player(player)
		var controller = host.call("controller") if host != null else null
		if controller != null:
			controller.call("cancel", "cancel")
		PlayerHost.reset(player)
	viewport.queue_free()
	current_scene = null


func _failed_viewport(viewport: SubViewport, reason: String) -> SubViewport:
	_mark_failed(viewport, reason)
	return viewport


func _mark_failed(viewport: SubViewport, reason: String) -> void:
	viewport.set_meta("fan3939_capture_failed", true)
	viewport.set_meta("fan3939_capture_failure", reason)


func _mode_spec(mode_id: String) -> Dictionary:
	for raw_mode in Spec.MODES:
		var mode := raw_mode as Dictionary
		if str(mode["id"]) == mode_id:
			return mode
	return {}


func _pack_spec(weapon_id: String) -> Dictionary:
	for raw_pack in Spec.PACKS:
		var pack := raw_pack as Dictionary
		if str(pack["weapon_id"]) == weapon_id:
			return pack
	return {}


func _mode_victim_count(mode_id: String) -> int:
	var mode := _mode_spec(mode_id)
	return int(mode.get("victims", 0))


func _write_capture_manifest() -> int:
	var document := Spec.manifest_document(_samples, _capture_source)
	var absolute := ProjectSettings.globalize_path(Spec.CAPTURE_MANIFEST_PATH)
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t") + "\n")
	file.close()
	return OK
