extends SceneTree

## Production accessibility regression for the Engineer ultimate trio.
##
## The state pass runs through Player.activate_ultimate() and the real
## UltimatePlayerHost/WeaponUltimatePresentationRuntime. A windowed invocation
## additionally samples the rendered photosafe envelopes at a fixed cadence:
##
##   FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --headless --path . \
##     --script res://tests/ultimates/presentation/engineer_accessibility_modes_test.gd
##   FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --windowed --fixed-fps 60 \
##     --path . --script res://tests/ultimates/presentation/engineer_accessibility_modes_test.gd

const Accessibility := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")

const CLASS_ID := "engineer"
const VIEWPORT_SIZE := Vector2i(1152, 648)
const TEMPORAL_SEED := 394720260910
const SAMPLE_STEP := 1.0 / 30.0
const PIXEL_STRIDE := 4
const FLASH_LUMINANCE_DELTA := 0.18
const FLASH_EVENT_COVERAGE_FLOOR := 0.01
const FULLSCREEN_COVERAGE_FLOOR := 0.80
const RESTORE_EPSILON := 0.001

const WEAPONS := {
	"engineer_sentry_wrench": {"release": 0.8, "active": 1.15, "recovery": 3.1, "cancel": 3.8, "gameplay": 4.6, "hold_frame": 3, "flash_coverage": 0.06},
	"engineer_repair_drone": {"release": 0.7, "active": 1.2, "recovery": 3.35, "cancel": 4.0, "gameplay": 5.5, "hold_frame": 4, "flash_coverage": 0.0},
	"engineer_pressure_mines": {"release": 0.9, "active": 1.7, "recovery": 3.1, "cancel": 3.6, "gameplay": 4.0, "hold_frame": 4, "flash_coverage": 0.0},
}

const MODES := [
	{"id": "default", "reduced": false, "photosafe": false},
	{"id": "reduced_motion", "reduced": true, "photosafe": false},
	{"id": "photosensitivity_safe", "reduced": false, "photosafe": true},
	{"id": "combined", "reduced": true, "photosafe": true},
]

var _errors: Array[String] = []
var _holder: Node2D = null
var _temporal_results: Array[Dictionary] = []


func _initialize() -> void:
	seed(TEMPORAL_SEED)
	_holder = Node2D.new()
	_holder.name = "EngineerAccessibilityProductionHarness"
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", true)
	root.set_meta("screen_shake", true)
	await process_frame

	for raw_mode in MODES:
		var mode := raw_mode as Dictionary
		for weapon_id in WEAPONS:
			await _check_production_cast(str(weapon_id), mode)

	await _check_crowded_repeated_impacts()
	await _check_natural_completion()
	await _check_death_and_node_removal()
	if DisplayServer.get_name() == "headless":
		# The dummy rasterizer hands an empty readback; the temporal envelope
		# is measured only by the windowed invocation documented above.
		pass
	else:
		await _measure_windowed_temporal_bounds()

	Accessibility.apply_snapshot(root, Accessibility.default_snapshot())
	Engine.time_scale = 1.0
	_holder.queue_free()
	await process_frame
	_report()


func _check_production_cast(weapon_id: String, mode: Dictionary) -> void:
	_apply_mode(mode)
	var player := await _spawn_player(weapon_id)
	var enemy := await _spawn_enemy(Vector2(120.0, 0.0))
	var host := PlayerHost.for_player(player)
	host.set("_presentation_headless_mode", 0)
	host.set_process(false)
	var camera := Camera2D.new()
	camera.offset = Vector2(3.0, -2.0)
	player.add_child(camera)
	camera.make_current()
	await process_frame
	var camera_before := camera.offset
	var sfx_index := AudioServer.get_bus_index("SFX")
	var sfx_before := AudioServer.get_bus_volume_db(sfx_index) if sfx_index >= 0 else 0.0

	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	_check(bool(player.call("activate_ultimate")), "%s/%s must activate through Player" % [weapon_id, mode["id"]])
	var controller = host.call("controller")
	var activation = controller.call("active_activation")
	var runtime = host.get("_presentation")
	var scene := runtime.get("_scene") as Node if runtime != null else null
	_check(activation != null and scene != null, "%s/%s must mount the production activation and scene" % [weapon_id, mode["id"]])
	if activation == null or scene == null:
		await _drop_cast(player, enemy)
		return

	var state := scene.call("accessibility_state_for_tests") as Dictionary
	var persisted := state.get("modes", {}) as Dictionary
	_check(bool(persisted.get(Accessibility.REDUCED_MOTION_KEY, false)) == bool(mode["reduced"])
		and bool(persisted.get(Accessibility.PHOTOSENSITIVITY_SAFE_KEY, false)) == bool(mode["photosafe"]),
		"%s/%s must consume the coherent persisted snapshot" % [weapon_id, mode["id"]])
	var held := bool(mode["reduced"]) or bool(mode["photosafe"])
	_check(bool(state.get("held_visuals", false)) == held, "%s/%s held-mode selection mismatch" % [weapon_id, mode["id"]])
	if held:
		_check(int(state.get("frame", -1)) == int((WEAPONS[weapon_id] as Dictionary)["hold_frame"])
			and not bool(state.get("timeline_playing", true)) and not bool(state.get("sprite_playing", true)),
			"%s/%s must hold its canonical frame with clocks stopped" % [weapon_id, mode["id"]])
	else:
		_check(bool(state.get("timeline_playing", false)), "%s/default must retain the authored timeline" % weapon_id)

	var spawned: Array[Node] = activation.call("spawned_for_tests")
	_check(not spawned.is_empty(), "%s/%s must retain its real temporary devices" % [weapon_id, mode["id"]])
	for device in spawned:
		var device_modes := device.get_meta("ultimate_accessibility_modes", {}) as Dictionary
		_check(device_modes == persisted, "%s/%s device must inherit the same snapshot" % [weapon_id, mode["id"]])
	if weapon_id == "engineer_pressure_mines":
		var mine_state := activation.call("primitive_value", "engineer_mine_state", {}) as Dictionary
		var points := mine_state.get("points", PackedVector2Array()) as PackedVector2Array
		if not points.is_empty():
			enemy.global_position = points[0]
		await _advance_activation(activation, 0.8)

	# The first executor beat is synchronous. With ordinary feedback enabled the
	# photosafe path preserves the number, replaces only its hit tick and restores
	# the enemy body before the renderer observes it.
	if bool(mode["photosafe"]):
		var safe_ticks := 0
		for raw_tick in get_nodes_in_group("combat_feedback_flashes"):
			var tick := raw_tick as CanvasItem
			if tick != null and bool(tick.get_meta("engineer_photosensitivity_safe_feedback", false)):
				safe_ticks += 1
				_check(tick.modulate.a <= 0.10 + RESTORE_EPSILON,
					"%s/%s ordinary hit marker alpha must stay bounded" % [weapon_id, mode["id"]])
		_check(safe_ticks > 0, "%s/%s must adapt actual ordinary enemy feedback (ticks=%d groups=%d health=%.1f)" % [weapon_id, mode["id"], safe_ticks, get_nodes_in_group("combat_feedback_flashes").size(), float(enemy.get("health"))])
		_check(bool(root.get_meta("combat_feedback", false)), "%s/%s must not disable global combat feedback" % [weapon_id, mode["id"]])
		_check(not get_nodes_in_group("combat_feedback_labels").is_empty(), "%s/%s must retain ordinary damage numbers" % [weapon_id, mode["id"]])

	var release := float((WEAPONS[weapon_id] as Dictionary)["release"])
	_advance_runtime(runtime, release + 0.01)
	state = scene.call("accessibility_state_for_tests") as Dictionary
	if bool(mode["reduced"]):
		_check(not bool(state.get("camera_shake_active", true)) and not bool(state.get("hitstop_active", true)),
			"%s/%s must suppress class shake and hitstop" % [weapon_id, mode["id"]])
	else:
		_check(bool(state.get("camera_shake_active", false)) and bool(state.get("hitstop_active", false)),
			"%s/%s must preserve normal release weight (%s)" % [weapon_id, mode["id"], str(state)])

	var elapsed_before_pause := float(state.get("elapsed_seconds", 0.0))
	host.call("ultimate_host_set_presentation_paused", true)
	runtime.call("advance", 0.5)
	state = scene.call("accessibility_state_for_tests") as Dictionary
	_check(is_equal_approx(float(state.get("elapsed_seconds", -1.0)), elapsed_before_pause),
		"%s/%s pause must freeze presentation time" % [weapon_id, mode["id"]])
	host.call("ultimate_host_set_presentation_paused", false)
	runtime.call("advance", 0.1)
	state = scene.call("accessibility_state_for_tests") as Dictionary
	_check(float(state.get("elapsed_seconds", 0.0)) > elapsed_before_pause,
		"%s/%s resume must continue presentation time" % [weapon_id, mode["id"]])

	controller.call("cancel", "cancel")
	await process_frame
	_check(host.get("_presentation") == null and not controller.call("is_active"),
		"%s/%s cancel must clear host and controller state" % [weapon_id, mode["id"]])
	_check(is_equal_approx(Engine.time_scale, 1.0) and camera.offset.distance_to(camera_before) <= RESTORE_EPSILON,
		"%s/%s cancel must restore time scale and camera" % [weapon_id, mode["id"]])
	if sfx_index >= 0:
		_check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), sfx_before),
			"%s/%s cancel must restore SFX bus" % [weapon_id, mode["id"]])
	await _drop_cast(player, enemy)


func _check_crowded_repeated_impacts() -> void:
	_apply_mode({"reduced": false, "photosafe": true})
	for weapon_id in WEAPONS:
		var player := await _spawn_player(str(weapon_id))
		var host := PlayerHost.for_player(player)
		host.set("_presentation_headless_mode", 0)
		host.set_process(false)
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")), "%s crowded photosafe cast must activate" % weapon_id)
		var runtime = host.get("_presentation")
		var scene := runtime.get("_scene") as Node if runtime != null else null
		var victims: Array = []
		for index in 39:
			var victim := Node2D.new()
			victim.position = Vector2(float(index % 13) * 14.0, float(index / 13) * 18.0)
			_holder.add_child(victim)
			victims.append(victim)
		if scene != null:
			scene.call("present", "photosafe.crowd.0", {"victims": victims})
			scene.call("present", "photosafe.crowd.1", {"victims": victims})
			scene.call("advance", 0.0)
			var state := scene.call("accessibility_state_for_tests") as Dictionary
			var impact := state.get("impact_snapshot", {}) as Dictionary
			_check(bool(impact.get("degraded", false)) and int(impact.get("created_nodes", 0)) <= 24,
				"%s repeated 39-target ripple must stay inside the bounded pool" % weapon_id)
			for raw_sprite in scene.find_children("*", "AnimatedSprite2D", true, false):
				var sprite := raw_sprite as AnimatedSprite2D
				if bool(sprite.get_meta("photosensitivity_safe", false)):
					_check(not sprite.is_playing() and sprite.modulate.a <= 0.12 + RESTORE_EPSILON,
						"%s photosafe victim bursts must be steady and low-alpha" % weapon_id)
		host.call("controller").call("cancel", "cancel")
		for victim in victims:
			(victim as Node).queue_free()
		player.queue_free()
		await process_frame


## Natural completion under the FAN-3941 lifetime semantics: the mechanical
## activation ends at its original instant (the executor's own scheduled end),
## the authored presentation enters a finite drain, and the host's own
## advancement releases it exactly at the authored timing.cancel boundary.
## Host frame processing stays off so the sequence is deterministic; the host
## is stepped explicitly through the same `_process` the game runs.
func _check_natural_completion() -> void:
	_apply_mode({"reduced": true, "photosafe": true})
	for weapon_id in WEAPONS:
		var cancel := float((WEAPONS[weapon_id] as Dictionary)["cancel"])
		var player := await _spawn_player(str(weapon_id))
		var host := PlayerHost.for_player(player)
		host.set("_presentation_headless_mode", 0)
		host.set_process(false)
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")), "%s natural-completion cast must activate" % weapon_id)
		var controller = host.call("controller")
		var activation = controller.call("active_activation")
		var runtime = host.get("_presentation")
		var scene := runtime.get("_scene") as Node if runtime != null else null
		await _advance_activation(activation, 7.0)
		_check(not controller.call("is_active") and not bool(player.get("_ultimate_active")),
			"%s natural completion must clear the activation at its original instant" % weapon_id)
		_check(host.get("_presentation") == runtime and bool(host.call("ultimate_host_presentation_draining"))
			and scene != null and is_instance_valid(scene) and scene.is_inside_tree(),
			"%s natural completion must leave the presentation draining, not released" % weapon_id)
		# Just short of the boundary the drain is still live; at the boundary the
		# host's own advancement releases it and frees the authored scene.
		_advance_host(host, cancel - 0.1)
		_check(host.get("_presentation") == runtime and bool(host.call("ultimate_host_presentation_draining")),
			"%s drain must still be live %.2f s before its declared cancel" % [weapon_id, 0.1])
		_advance_host(host, 0.1 + 1.0 / 60.0)
		_check(host.get("_presentation") == null and not controller.call("is_active"),
			"%s natural completion must clear the presentation at its declared cancel %.2f s" % [weapon_id, cancel])
		await process_frame
		_check(scene == null or not is_instance_valid(scene),
			"%s the drained scene must be freed once the drain ends" % weapon_id)
		_check(is_equal_approx(Engine.time_scale, 1.0), "%s natural completion must restore time scale" % weapon_id)
		player.queue_free()
		await process_frame


func _check_death_and_node_removal() -> void:
	for reason in ["death", "node_removal"]:
		_apply_mode({"reduced": false, "photosafe": false})
		var player := await _spawn_player("engineer_sentry_wrench")
		var host := PlayerHost.for_player(player)
		host.set("_presentation_headless_mode", 0)
		host.set_process(false)
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		_check(bool(player.call("activate_ultimate")), "%s lifecycle cast must activate" % reason)
		var runtime = host.get("_presentation")
		if runtime != null:
			runtime.call("advance", 0.81)
		if reason == "death":
			player.emit_signal("died")
			await process_frame
			_check(host.get("_presentation") == null and not host.call("controller").call("is_active"),
				"death must cancel the production presentation")
			player.queue_free()
		else:
			player.queue_free()
			await process_frame
		_check(is_equal_approx(Engine.time_scale, 1.0), "%s must restore global hitstop state" % reason)
		await process_frame


func _measure_windowed_temporal_bounds() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	await process_frame
	await process_frame
	_check(root.size == VIEWPORT_SIZE, "windowed temporal viewport must be exactly %s" % VIEWPORT_SIZE)
	_apply_mode({"reduced": false, "photosafe": true})
	for weapon_id in WEAPONS:
		var player := await _spawn_player(str(weapon_id))
		player.global_position = Vector2(VIEWPORT_SIZE) * 0.5
		var enemies: Array[Node2D] = []
		for offset in [Vector2(110.0, 0.0), Vector2(-90.0, 55.0), Vector2(35.0, -120.0)]:
			var enemy := await _spawn_enemy(player.global_position + offset)
			enemies.append(enemy)
		var host := PlayerHost.for_player(player)
		host.set("_presentation_headless_mode", 0)
		host.set_process(false)
		player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
		var previous := await _capture_frame()
		_check(bool(player.call("activate_ultimate")), "%s temporal cast must activate" % weapon_id)
		var runtime = host.get("_presentation")
		var controller = host.call("controller")
		var activation = controller.call("active_activation")
		if weapon_id == "engineer_pressure_mines" and activation != null:
			var mine_state := activation.call("primitive_value", "engineer_mine_state", {}) as Dictionary
			var points := mine_state.get("points", PackedVector2Array()) as PackedVector2Array
			for index in mini(points.size(), enemies.size()):
				enemies[index].global_position = points[index]
		var elapsed := 0.0
		var flash_events := 0
		var fullscreen_events := 0
		var max_flash_coverage := 0.0
		var duration := float((WEAPONS[weapon_id] as Dictionary)["gameplay"])
		while elapsed < duration and runtime != null:
			var step := minf(SAMPLE_STEP, duration - elapsed)
			runtime.call("advance", step)
			if activation != null and not activation.call("is_finished"):
				for tween in activation.call("tweens_for_tests"):
					if tween != null and tween.is_valid():
						tween.custom_step(step)
			await process_frame
			var current := root.get_texture().get_image()
			var coverage := _luminance_change_coverage(previous, current)
			if coverage >= FLASH_EVENT_COVERAGE_FLOOR:
				flash_events += 1
				max_flash_coverage = maxf(max_flash_coverage, coverage)
			if coverage >= FULLSCREEN_COVERAGE_FLOOR:
				fullscreen_events += 1
			previous = current
			elapsed += step
		var hz := float(fullscreen_events) / duration
		var declared := float((WEAPONS[weapon_id] as Dictionary)["flash_coverage"])
		_temporal_results.append({
			"weapon_id": weapon_id,
			"samples": ceili(duration / SAMPLE_STEP),
			"duration_seconds": duration,
			"flash_events": flash_events,
			"max_flash_coverage_ratio": max_flash_coverage,
			"full_screen_flash_hz": hz,
			"declared_max_flash_coverage_ratio": declared,
		})
		_check(hz <= RESTORE_EPSILON, "%s photosafe full-screen flash frequency must be zero" % weapon_id)
		_check(max_flash_coverage <= declared + RESTORE_EPSILON,
			"%s photosafe flash coverage %.6f exceeds %.6f" % [weapon_id, max_flash_coverage, declared])
		host.call("controller").call("cancel", "cancel")
		player.queue_free()
		for enemy in enemies:
			if is_instance_valid(enemy):
				enemy.queue_free()
		await process_frame
	print("ENGINEER_ACCESSIBILITY_TEMPORAL=" + JSON.stringify({
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"seed": TEMPORAL_SEED,
		"sample_hz": 1.0 / SAMPLE_STEP,
		"pixel_stride": PIXEL_STRIDE,
		"luminance_delta": FLASH_LUMINANCE_DELTA,
		"event_coverage_floor": FLASH_EVENT_COVERAGE_FLOOR,
		"fullscreen_coverage_floor": FULLSCREEN_COVERAGE_FLOOR,
		"results": _temporal_results,
	}))


func _capture_frame() -> Image:
	await process_frame
	return root.get_texture().get_image()


func _luminance_change_coverage(previous: Image, current: Image) -> float:
	if previous == null or current == null or previous.get_size() != current.get_size():
		return 1.0
	var changed := 0
	var sampled := 0
	for y in range(0, current.get_height(), PIXEL_STRIDE):
		for x in range(0, current.get_width(), PIXEL_STRIDE):
			var before := previous.get_pixel(x, y)
			var after := current.get_pixel(x, y)
			var before_luma := before.r * 0.2126 + before.g * 0.7152 + before.b * 0.0722
			var after_luma := after.r * 0.2126 + after.g * 0.7152 + after.b * 0.0722
			if after_luma - before_luma >= FLASH_LUMINANCE_DELTA:
				changed += 1
			sampled += 1
	return float(changed) / float(maxi(sampled, 1))


func _spawn_player(weapon_id: String) -> Node2D:
	var player := PlayerScene.instantiate() as Node2D
	_holder.add_child(player)
	await process_frame
	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _spawn_enemy(offset: Vector2) -> Node2D:
	var enemy := EnemyScene.instantiate() as Node2D
	_holder.add_child(enemy)
	enemy.global_position = offset
	enemy.set("max_health", 1_000_000.0)
	enemy.set("health", 1_000_000.0)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	await process_frame
	return enemy


func _advance_activation(activation, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and activation != null and not activation.call("is_finished"):
		var step := minf(0.01, seconds - elapsed)
		for tween in activation.call("tweens_for_tests"):
			if tween != null and tween.is_valid():
				tween.custom_step(step)
		elapsed += step
	await process_frame


## Steps the host through the same `_process` the game runs, in fixed frames.
func _advance_host(host: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var step := minf(1.0 / 60.0, seconds - elapsed)
		host.call("_process", step)
		elapsed += step


func _advance_runtime(runtime, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var step := minf(1.0 / 60.0, seconds - elapsed)
		runtime.call("advance", step)
		elapsed += step


func _drop_cast(player: Node, enemy: Node) -> void:
	if player != null and is_instance_valid(player):
		player.queue_free()
	if enemy != null and is_instance_valid(enemy):
		enemy.queue_free()
	await process_frame


func _apply_mode(mode: Dictionary) -> void:
	Accessibility.apply_snapshot(root, {
		Accessibility.REDUCED_MOTION_KEY: bool(mode.get("reduced", false)),
		Accessibility.PHOTOSENSITIVITY_SAFE_KEY: bool(mode.get("photosafe", false)),
	})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("engineer_accessibility_modes_test: PASS (12 production mode casts, crowded/repeated feedback, lifecycle restoration%s)" % [", windowed temporal bounds" if not _temporal_results.is_empty() else ""])
		quit(0)
		return
	for error in _errors:
		push_error("engineer_accessibility_modes_test: %s" % error)
	print("engineer_accessibility_modes_test: FAIL (%d)" % _errors.size())
	quit(1)
