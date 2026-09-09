extends SceneTree

## Windowed runtime renderer for FAN-3944's Robot certification package.
##
## Each output sheet is evidence, not a replacement scene. Every cell begins
## through the real Player/UltimateHost/Enemy execution path, then advances the
## production activation by fixed tween steps to a named beat before the
## authored V2 timeline is frozen. The only capture-specific work is arranging
## that real runtime state into a reviewable viewport.

const Spec := preload("res://tests/ultimates/presentation/robot_certification_capture_test.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")
const PlayerScene := preload("res://scenes/Player.tscn")
const EnemySpitterScene := preload("res://scenes/EnemySpitter.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const HudAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const STATE_BAND_COLOR := Color(0.045, 0.065, 0.050, 0.96)
const STATE_TEXT_COLOR := Color(0.78, 0.92, 0.78, 1.0)
const CAPTURE_STEP := 0.01
const ENEMY_CAPTURE_HEALTH := 100000.0
const CAPTURE_SETTLE_FRAMES := 3


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		## The changed-profile runner discovers every SceneTree script headlessly.
		## Do not claim or create PNG evidence there: a successful skip is only a
		## structural runner result, while the manifest's windowed method remains
		## the fail-closed proof requirement.
		print("FAN-3944 Robot certification capture skipped: headless runs never create certification PNG evidence.")
		quit(0)
		return
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	if not registry.is_valid():
		push_error("FAN-3944 Robot certification capture cannot start: weapon registry is invalid")
		quit(1)
		return
	if PlayerScene == null or EnemySpitterScene == null:
		push_error("FAN-3944 Robot certification capture cannot load the shipped Player/Enemy runtime scenes")
		quit(1)
		return
	seed(Spec.CAPTURE_SEED)
	for raw_capture in Spec.CAPTURES:
		var capture := raw_capture as Dictionary
		var result := await _capture_sheet(registry, capture)
		if result != OK:
			push_error("FAN-3944 Robot certification capture failed: %s" % error_string(result))
			quit(1)
			return
	root.set_meta("screen_shake", true)
	quit(0)


func _capture_sheet(_registry, capture: Dictionary) -> int:
	var size := capture.get("size", Vector2i.ZERO) as Vector2i
	var output := str(capture.get("path", ""))
	var phase := str(capture.get("phase", ""))
	if size == Vector2i.ZERO or output.is_empty() or phase.is_empty():
		return ERR_INVALID_PARAMETER
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	if directory_result != OK:
		return directory_result
	var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Spec.BACKGROUND_COLOR)
	var capture_index := Spec.CAPTURES.find(capture)
	for weapon_index in Spec.PACKS.size():
		for mode_index in Spec.MODES.size():
			var arena := Spec.arena_rect(size, weapon_index, mode_index)
			## Re-seeding per cell makes the Player/Enemy setup and all fixed tween
			## steps independent of the order in which Godot draws SubViewports.
			seed(Spec.CAPTURE_SEED + capture_index * 100 + weapon_index * 10 + mode_index)
			var viewport := await _arena_viewport(arena.size, weapon_index, mode_index, phase)
			if bool(viewport.get_meta("fan3944_capture_failed", false)):
				var reason := str(viewport.get_meta("fan3944_capture_failure", "unknown live runtime failure"))
				viewport.queue_free()
				await process_frame
				push_error("FAN-3944 Robot certification live cell failed: %s" % reason)
				return ERR_CANT_CREATE
			await _finalize_viewport_for_readback(viewport)
			var image := _read_viewport(viewport, "%s/%s/%s" % [
				Spec.WEAPON_IDS[weapon_index], Spec.MODE_IDS[mode_index], phase,
			])
			_reset_player_host(viewport)
			viewport.queue_free()
			current_scene = null
			await process_frame
			if image == null:
				return ERR_CANT_CREATE
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), arena.position)

	var chrome := _chrome_viewport(size, phase)
	await _finalize_viewport_for_readback(chrome)
	var chrome_image := _read_viewport(chrome, "chrome/%s" % phase)
	chrome.queue_free()
	await process_frame
	if chrome_image == null:
		return ERR_CANT_CREATE
	sheet.blend_rect(chrome_image, Rect2i(Vector2i.ZERO, chrome_image.get_size()), Vector2i.ZERO)
	var result := sheet.save_png(ProjectSettings.globalize_path(output))
	if result == OK:
		print("FAN-3944 Robot certification capture saved: %s (%dx%d, %s)" % [output, size.x, size.y, phase])
	return result


## Every arena is built and read back in isolation. The production target query
## is global to the SceneTree, so this prevents one cell's actual enemies from
## becoming another cell's capture targets.
func _arena_viewport(arena_size: Vector2i, weapon_index: int, mode_index: int, phase: String) -> SubViewport:
	var pack := Spec.PACKS[weapon_index] as Dictionary
	var mode := Spec.MODES[mode_index] as Dictionary
	var viewport := _viewport(arena_size, false)
	var background := ColorRect.new()
	background.color = Spec.FLOOR_COLOR
	background.size = Vector2(arena_size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var world := Node2D.new()
	world.name = "RobotCertificationWorld"
	viewport.add_child(world)
	## SceneTree.current_scene must be a root child. Point it at the SubViewport:
	## Player._vfx_parent then correctly falls back to the real Player's world
	## parent, while Enemy._spawn_elite_hazard adds its production hazard inside
	## this same isolated render target.
	current_scene = viewport
	root.set_meta("screen_shake", bool(mode["screen_shake"]))
	root.set_meta("combat_feedback", true)

	var player := PlayerScene.instantiate() as Node2D
	if player == null:
		return _failed_viewport(viewport, "Player.tscn did not instantiate")
	player.position = Spec.player_rect(arena_size).get_center()
	world.add_child(player)
	await process_frame
	_disable_player_camera(player)
	player.call("configure_character", "robot", str(pack["weapon_id"]))
	await process_frame

	var enemies := _spawn_real_enemies(world, arena_size, Spec.victim_count(pack, mode))
	if enemies.is_empty():
		return _failed_viewport(viewport, "EnemySpitter.tscn did not instantiate")
	for enemy in enemies:
		_freeze_actor(enemy)
	var hazard := _spawn_real_hazard(viewport, enemies[0], arena_size)
	if hazard == null:
		return _failed_viewport(viewport, "real ElitePoisonZone hazard did not spawn")
	_freeze_hazard(hazard)

	player.set("ultimate_charge", player.get("ultimate_max_charge"))
	if not bool(player.call("activate_ultimate")):
		return _failed_viewport(viewport, "%s did not activate through Player.activate_ultimate" % pack["weapon_id"])
	var host := PlayerHost.for_player(player)
	var activation = host.controller().active_activation()
	if activation == null:
		return _failed_viewport(viewport, "%s did not retain a live Player activation" % pack["weapon_id"])
	_pause_activation(activation)
	## Let the just-created production AnimationPlayer consume its one deferred
	## autoplay frame. Fixed seeking before this point was the 648p drift race.
	await process_frame
	var presentation = host.get("_presentation")
	var scene := presentation.get("_scene") as Node2D if presentation != null else null
	if scene == null:
		return _failed_viewport(viewport, "%s did not create its shipped V2 scene" % pack["weapon_id"])
	## Enemy damage labels and hit flashes are short real-time tweens. They are
	## not the ultimate presentation (the shipped V2 impact player is), and
	## leaving them enabled makes a fixed visual seek depend on the frame that
	## happens to follow the executor step. Keep the real damage/impact path,
	## but suppress only those transient capture-time combat-feedback overlays.
	root.set_meta("combat_feedback", false)
	_advance_activation(activation, Spec.runtime_execution_seconds(pack, phase))
	_suppress_standard_weapon_feedback(viewport)
	_suppress_runtime_sibling_effects(world, scene, player, enemies)
	## `take_damage()` can ask an Enemy's visual rig to play a hit state even
	## when ordinary combat-feedback overlays are disabled. Reapply the fixture
	## freeze after the real executor has fired so no actor-side clock advances
	## during the subsequent renderer frame.
	for enemy in enemies:
		_freeze_actor(enemy)
	host.set_process(false)
	Spec.seek_scene(scene, float((pack["beats"] as Dictionary)[phase]))
	if scene.has_method("_fit_backdrop_to_viewport"):
		scene.call("_fit_backdrop_to_viewport")
	if bool(mode["photosafe"]):
		Spec.apply_photosafe(scene)
	Spec.layout_scene(scene, arena_size)
	_hold_victim_impacts(scene)
	_freeze_actor(player)
	## Keep the actual Player.tscn actor readable above the fullscreen V2 veil.
	## This is capture framing only; the Player is still the one that initiated
	## the active production cast and owns this presentation scene.
	player.z_index = 50
	_attach_shipped_hud(viewport, player, arena_size)
	if bool(viewport.get_meta("fan3944_capture_failed", false)):
		return viewport
	## A node-local pause does not catch every Tween owned by a real hazard or
	## actor subtree. Explicitly pause all capture-process tweens immediately
	## before readback; unlike a global SceneTree pause, this keeps the windowed
	## renderer presenting its bounded settle frames on macOS.
	_pause_capture_tweens()
	return viewport


func _reset_player_host(viewport: SubViewport) -> void:
	var player := viewport.find_child("Player", true, false) as Node2D
	if player != null:
		PlayerHost.reset(player)


func _chrome_viewport(size: Vector2i, phase: String) -> SubViewport:
	var viewport := _viewport(size, true)
	var host := Node2D.new()
	viewport.add_child(host)
	var title := Label.new()
	title.text = "CHEMIST ULTIMATES — %s LIVE RUNTIME MATRIX" % phase.to_upper()
	title.position = Vector2(size.x * 0.022, size.y * 0.020)
	title.add_theme_font_size_override("font_size", maxi(16, roundi(size.y * 0.032)))
	title.add_theme_color_override("font_color", Color(0.82, 1.0, 0.56))
	title.z_index = 300
	host.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "REAL PLAYER ACTIVATION · ENEMY SPITTERS · ELITE POISON HAZARD · SHIPPED ULTIMATE HUD · FIXED TWEEN BEAT"
	subtitle.position = Vector2(size.x * 0.022, size.y * 0.072)
	subtitle.add_theme_font_size_override("font_size", maxi(8, roundi(size.y * 0.015)))
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.88, 0.76))
	subtitle.z_index = 300
	host.add_child(subtitle)
	for weapon_index in Spec.PACKS.size():
		for mode_index in Spec.MODES.size():
			var pack := Spec.PACKS[weapon_index] as Dictionary
			var mode := Spec.MODES[mode_index] as Dictionary
			var panel := Spec.panel_rect(size, weapon_index, mode_index)
			host.add_child(_outline_node(panel, Spec.PANEL_OUTLINE_COLOR))
			var marker := Spec.mode_marker_probe(size, weapon_index, mode_index)
			host.add_child(_rect_node(
				Rect2(Vector2(marker) - Vector2.ONE * 2.0, Vector2.ONE * 5.0),
				Spec.MARKER_COLORS[str(mode["id"])] as Color,
				310
			))
			var label := Label.new()
			label.text = "%s · %s" % [str(pack["label"]), str(mode["label"])]
			label.position = panel.position + Vector2(size.x * 0.014, size.y * 0.015)
			label.add_theme_font_size_override("font_size", _panel_font_size(size, pack, mode))
			label.add_theme_color_override("font_color", pack["color"] as Color)
			label.z_index = 310
			host.add_child(label)
			host.add_child(_sheet_state_caption(size, weapon_index, mode_index, pack, mode, phase))
	return viewport


func _attach_shipped_hud(viewport: SubViewport, player: Node2D, arena_size: Vector2i) -> void:
	var hud_root := Control.new()
	hud_root.name = "RobotCertificationHudRoot"
	hud_root.size = Vector2(arena_size)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(hud_root)
	var adapter := HudAdapter.new()
	hud_root.add_child(adapter)
	if not adapter.mount(hud_root, player):
		_mark_failed(viewport, "shipped UltimateHudRuntimeAdapter could not mount")
		return
	var widget := hud_root.get_node_or_null("UltimateHudWidget") as Control
	if widget == null:
		_mark_failed(viewport, "shipped UltimateHudWidget is missing after adapter mount")
		return
	widget.set_anchors_preset(Control.PRESET_TOP_LEFT)
	widget.position = Vector2(2.0, 2.0)
	widget.scale = Vector2.ONE * clampf(float(arena_size.y) / 440.0, 0.27, 0.58)
	widget.z_index = 100
	adapter.refresh()
	## The mounted production adapter normally refreshes every idle frame. Its
	## selected Player state has now been read into the shipped widget, so stop
	## that clock before the frozen viewport readback just as we stop actor and
	## presentation clocks above.
	adapter.set_process(false)


func _spawn_real_enemies(world: Node2D, arena_size: Vector2i, count: int) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var zone := Spec.effect_zone(arena_size)
	var columns := mini(6, maxi(1, count))
	var rows := ceili(float(count) / float(columns))
	for index in count:
		var enemy := EnemySpitterScene.instantiate() as Node2D
		if enemy == null:
			continue
		var column := index % columns
		var row := index / columns
		enemy.position = zone.position + Vector2(
			zone.size.x * (float(column) + 0.5) / float(columns),
			zone.size.y * (float(row) + 0.5) / float(rows)
		)
		enemy.set("max_health", ENEMY_CAPTURE_HEALTH)
		enemy.set("health", ENEMY_CAPTURE_HEALTH)
		world.add_child(enemy)
		## `_ready()` initializes `health` from `max_health`; repeat the explicit
		## value after it enters the real scene so ultimate ticks cannot delete a
		## capture target at any phase.
		enemy.set("max_health", ENEMY_CAPTURE_HEALTH)
		enemy.set("health", ENEMY_CAPTURE_HEALTH)
		enemies.append(enemy)
	return enemies


func _spawn_real_hazard(parent: Node, source_enemy: Node2D, arena_size: Vector2i) -> Node2D:
	if source_enemy == null or not source_enemy.has_method("_spawn_elite_hazard"):
		return null
	var hazard_rects := Spec.hazard_rects(arena_size)
	if hazard_rects.is_empty():
		return null
	source_enemy.call("_spawn_elite_hazard", hazard_rects[0].get_center())
	return parent.get_node_or_null("ElitePoisonZone") as Node2D


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


func _freeze_actor(actor: Node) -> void:
	if actor == null:
		return
	## A disabled process mode propagates through the real actor subtree. This is
	## stronger than stopping the root's callbacks alone: hit-state animation
	## children and their bound tweens must not advance between a fixed seek and
	## the viewport readback.
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.set_process(false)
	actor.set_physics_process(false)
	for raw_child in actor.find_children("*", "AnimationPlayer", true, false):
		var timeline := raw_child as AnimationPlayer
		if timeline != null:
			timeline.pause()
	for raw_child in actor.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := raw_child as AnimatedSprite2D
		if sprite != null:
			sprite.pause()
			## The real Player idle flipbook starts during the readiness frames that
			## precede the live ultimate activation. Pausing alone preserves a
			## renderer-paced in-frame phase, so normalize that capture-only visual
			## clock only after the real execution path has completed.
			sprite.frame = 0
			sprite.frame_progress = 0.0
	if actor.name == "Player":
		var body := actor.get_node_or_null("VisualRoot/Body") as AnimatedSprite2D
		if body != null and body.visible:
			for rig_path in ["VisualRoot/RigRoot", "VisualRoot/SkeletalRigRoot"]:
				var rig := actor.get_node_or_null(rig_path) as CanvasItem
				if rig != null:
					rig.visible = false


func _freeze_hazard(hazard: Node2D) -> void:
	if hazard == null:
		return
	for raw_item in hazard.find_children("*", "CanvasItem", true, false):
		var item := raw_item as CanvasItem
		if item != null:
			item.visible = true
			item.modulate = Color(item.modulate.r, item.modulate.g, item.modulate.b, 0.82)
	for raw_node in hazard.find_children("*", "Node", true, false):
		var node := raw_node as Node
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	hazard.process_mode = Node.PROCESS_MODE_DISABLED


func _suppress_runtime_sibling_effects(world: Node2D, presentation_scene: Node2D, player: Node2D, enemies: Array[Node2D]) -> void:
	## The Player activation has already created and exercised these runtime
	## nodes. Keep the actual Player, EnemySpitter targets, and named shipped V2
	## scene as the review surface, but suppress other world siblings (base-weapon
	## summons, executor avatar echoes, and pulses) whose renderer-paced clocks
	## otherwise overlap that fixed seek.
	var retained_ids := {
		player.get_instance_id(): true,
		presentation_scene.get_instance_id(): true,
	}
	for enemy in enemies:
		if enemy != null:
			retained_ids[enemy.get_instance_id()] = true
	for raw_child in world.get_children():
		var child := raw_child as Node
		if child == null or retained_ids.has(child.get_instance_id()):
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _suppress_standard_weapon_feedback(viewport: SubViewport) -> void:
	## The real Player action and its executor have already run. Its ordinary
	## weapon-release/projectile FX are renderer-clocked and are not part of the
	## shipped ultimate scene; retain the real gameplay outcome while excluding
	## only these short-lived feedback nodes from a fixed certification still.
	for raw_effect in get_nodes_in_group("player_weapon_effects"):
		var effect := raw_effect as Node
		if effect != null and viewport.is_ancestor_of(effect):
			effect.process_mode = Node.PROCESS_MODE_DISABLED
			if effect is CanvasItem:
				(effect as CanvasItem).visible = false
	## AttackVfx can intentionally detach a trail or ring from its holder and
	## place its CanvasItem directly in this isolated SubViewport. At this point
	## the only required direct children are the floor, the real-world subtree,
	## and the real ElitePoisonZone hazard; every other direct child is transient
	## post-executor feedback. Hide and freeze those nodes rather than sampling a
	## variable in-flight frame or destroying a node that the active runtime owns.
	for raw_child in viewport.get_children():
		var child := raw_child as Node
		if child == null or child is ColorRect \
				or child.name == &"RobotCertificationWorld" or child.name == &"ElitePoisonZone":
			continue
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _pause_capture_tweens() -> void:
	## `SceneTree.paused` follows a Tween's bound-node pause policy. Explicitly
	## pause the isolated renderer's processed tweens as well: runtime hazards
	## own pulse tweens beneath helper nodes, and a pixel certification snapshot
	## must not rely on those helpers' next idle tick.
	for tween in get_processed_tweens():
		if tween != null and tween.is_valid():
			tween.pause()


func _failed_viewport(viewport: SubViewport, reason: String) -> SubViewport:
	_mark_failed(viewport, reason)
	return viewport


func _mark_failed(viewport: SubViewport, reason: String) -> void:
	viewport.set_meta("fan3944_capture_failed", true)
	viewport.set_meta("fan3944_capture_failure", reason)


func _hold_victim_impacts(scene: Node2D) -> void:
	for child in scene.get_children():
		if child is ImpactPlayer:
			var impacts := child as Node2D
			impacts.call("advance", 0.12)
			impacts.call("set_paused", true)


## Victim-impact sprites are deliberately top-level in the shipped scene so
## every target receives readable feedback. The capture caption instead lives
## in this final chrome pass, which is blended after every arena viewport, so
## the evidence labels remain readable even at the declared crowd caps.
func _sheet_state_caption(size: Vector2i, weapon_index: int, mode_index: int, pack: Dictionary, mode: Dictionary, phase: String) -> Node2D:
	var arena := Spec.arena_rect(size, weapon_index, mode_index)
	var local_band := Spec.state_band_rect(arena.size)
	var band := Rect2(Vector2(arena.position) + local_band.position, local_band.size)
	var host := Node2D.new()
	host.z_index = 320
	host.add_child(_rect_node(band, STATE_BAND_COLOR))
	var text := "%s %.2fs · SHAKE %s · REAL TARGETS %d · VEIL %s" % [
		phase.to_upper(),
		float((pack["beats"] as Dictionary)[phase]),
		"ON" if bool(mode["screen_shake"]) else "OFF",
		Spec.victim_count(pack, mode),
		"OFF" if bool(mode["photosafe"]) else "SHIPPED",
	]
	var label := Label.new()
	label.text = text
	label.position = Vector2(band.position.x + band.size.x * 0.04, band.position.y + band.size.y * 0.18)
	label.add_theme_font_size_override("font_size", maxi(6, roundi(band.size.y * 0.48)))
	label.add_theme_color_override("font_color", STATE_TEXT_COLOR)
	host.add_child(label)
	return host


func _viewport(size: Vector2i, transparent: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _read_viewport(viewport: SubViewport, label: String) -> Image:
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("FAN-3944 Robot certification capture rendered an empty viewport: %s" % label)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _finalize_viewport_for_readback(viewport: SubViewport) -> void:
	## The runtime clocks are frozen before this point. Render an explicit, fixed
	## number of final frames and then disable the target rather than leaving an
	## UPDATE_ALWAYS SubViewport alive while its texture is read. On macOS that
	## prevents a variable subsequent presentation frame from becoming part of a
	## certification PNG, while preserving the real windowed renderer path.
	for _frame in CAPTURE_SETTLE_FRAMES:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _rect_node(rect: Rect2, color: Color, z_index := 0) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	polygon.z_index = z_index
	return polygon


func _outline_node(rect: Rect2, color: Color) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position,
	])
	line.width = 1.0
	line.default_color = color
	line.z_index = 300
	return line


func _panel_font_size(size: Vector2i, pack: Dictionary, mode: Dictionary) -> int:
	var panel := Spec.panel_rect(size, Spec.WEAPON_IDS.find(str(pack["weapon_id"])), Spec.MODE_IDS.find(str(mode["id"])))
	var text := "%s · %s" % [str(pack["label"]), str(mode["label"])]
	var preferred := maxi(8, roundi(size.y * 0.014))
	while preferred > 6 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, preferred).x > panel.size.x * 0.86:
		preferred -= 1
	return preferred
