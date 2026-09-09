extends SceneTree

## FAN-3936 non-headless capture runner.
##
## Each artifact comes from a real Player activation through UltimateHost. The
## arena is deliberately only a deterministic fixture: its background, enemies,
## hazards, HUD, Player, controller and authored ultimate scene are all shipped
## runtime resources. This runner never draws a stand-in ultimate or HUD.

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const UltimateHudRuntimeAdapter := preload("res://scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd")
const HazardVfx := preload("res://scripts/hazard_vfx.gd")

const CAPTURE_ID := "FAN-3936"
const CLASS_ID := "biologist"
const CAPTURE_SEED := 3936
const OUTPUT_ARGUMENT := "--output-dir="
const FRAME_SECONDS := 1.0 / 60.0
const BACKGROUND_PATH := "res://assets/backgrounds/field_misty_marsh.png"
const ARENA_CENTER := Vector2(2048.0, 1152.0)

## The individual images are native viewport renders, not downscaled panels in
## a contact sheet. The ID is intentionally part of the artifact filename and
## capture manifest key.
const VIEWPORTS := [
	{"id": "1152x648", "size": Vector2i(1152, 648)},
	{"id": "1280x720", "size": Vector2i(1280, 720)},
	{"id": "1920x1080", "size": Vector2i(1920, 1080)},
	{"id": "2560x1440", "size": Vector2i(2560, 1440)},
]

## The photosensitivity-safe row intentionally does not hide or alter an
## authored scene. Biologist declares no repeating full-screen flash (0 Hz);
## this row preserves that shipped visual rather than inventing a capture-only
## substitute. The report records this no-override limitation explicitly.
const MODES := [
	{
		"id": "normal",
		"screen_shake": true,
		"crowded": false,
		"photosensitivity_strategy": "native_shipped_visual",
	},
	{
		"id": "crowded",
		"screen_shake": true,
		"crowded": true,
		"photosensitivity_strategy": "native_shipped_visual",
	},
	{
		"id": "reduced_motion",
		"screen_shake": false,
		"crowded": false,
		"photosensitivity_strategy": "native_shipped_visual",
	},
	{
		"id": "photosensitivity_safe",
		"screen_shake": true,
		"crowded": false,
		"photosensitivity_strategy": "native_no_repeating_fullscreen_flash",
	},
]

const WEAPONS := [
	{
		"weapon_id": "biologist_spore_lens",
		"scene_path": "res://scenes/vfx/ultimates/biologist/BiologistSporeLensWorldMycelium.tscn",
		"active_seconds": 1.55,
		"release_seconds": 0.80,
		"recovery_seconds": 2.80,
		"crowd_cap": 18,
	},
	{
		"weapon_id": "biologist_sample_injector",
		"scene_path": "res://scenes/vfx/ultimates/biologist/BiologistSampleInjectorPerfectSample.tscn",
		"active_seconds": 1.45,
		"release_seconds": 0.70,
		"recovery_seconds": 2.50,
		"crowd_cap": 16,
	},
	{
		"weapon_id": "biologist_symbiote_seed",
		"scene_path": "res://scenes/vfx/ultimates/biologist/BiologistSymbioteSeedMatriarch.tscn",
		"active_seconds": 1.85,
		"release_seconds": 0.90,
		"recovery_seconds": 3.20,
		"crowd_cap": 22,
	},
]

var _output_dir := ""
var _viewport: SubViewport = null


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("FAN-3936 requires a non-headless renderer; headless capture is not evidence.")
		return
	_output_dir = _output_directory()
	if _output_dir.is_empty():
		_fail("FAN-3936 requires --output-dir=<absolute-or-res-path>.")
		return
	if DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		_fail("FAN-3936 could not create output directory: %s" % _output_dir)
		return
	seed(CAPTURE_SEED)
	_viewport = SubViewport.new()
	_viewport.name = "BiologistCertificationViewport"
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	# SceneTree only accepts a direct root child here. Keeping the SubViewport as
	# the current scene also lets Player fall back to the arena (a Node2D) as its
	# visual parent, while other transient runtime nodes remain inside the native
	# render target.
	current_scene = _viewport
	for raw_viewport in VIEWPORTS:
		var viewport_spec := raw_viewport as Dictionary
		_viewport.size = viewport_spec["size"] as Vector2i
		await process_frame
		await process_frame
		for raw_mode in MODES:
			var mode := raw_mode as Dictionary
			for raw_weapon in WEAPONS:
				var weapon := raw_weapon as Dictionary
				var result := await _capture_one(viewport_spec, mode, weapon)
				if not result:
					return
	current_scene = null
	_viewport.queue_free()
	await process_frame
	print("%s live capture: PASS (48 native PlayerHost renders)" % CAPTURE_ID)
	quit(0)


func _capture_one(viewport_spec: Dictionary, mode: Dictionary, weapon: Dictionary) -> bool:
	var viewport_size := viewport_spec["size"] as Vector2i
	var weapon_id := str(weapon["weapon_id"])
	var mode_id := str(mode["id"])
	root.set_meta("screen_shake", bool(mode["screen_shake"]))
	root.set_meta("combat_feedback", true)
	root.set_meta("aim_mode", "nearest")

	var arena := Node2D.new()
	arena.name = "BiologistCertificationArena"
	arena.y_sort_enabled = true
	_viewport.add_child(arena)
	_add_shipped_background(arena, viewport_size)
	var player := PlayerScene.instantiate() as Node2D
	if player == null:
		_fail("%s could not instantiate the shipped Player scene" % CAPTURE_ID)
		_cleanup(arena)
		return false
	# The shipped Player camera clamps at the map origin. Place this deterministic
	# fixture at its playable-map center so the live camera frames the player,
	# targets, authored VFX, hazards, and HUD rather than the top-left map edge.
	player.position = ARENA_CENTER
	arena.add_child(player)
	await process_frame
	player.call("configure_character", CLASS_ID, weapon_id)
	await process_frame
	player.set("ultimate_charge", float(player.get("ultimate_max_charge")))
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or not camera.enabled:
		_fail("%s/%s requires the shipped Player Camera2D" % [CAPTURE_ID, weapon_id])
		_cleanup(arena)
		return false
	var hud_root := _mount_shipped_hud(arena, player, viewport_size)
	if hud_root == null:
		_fail("%s/%s could not mount the shipped ultimate HUD" % [CAPTURE_ID, weapon_id])
		_cleanup(arena)
		return false

	var crowd_count := int(weapon["crowd_cap"]) if bool(mode["crowded"]) else 4
	var targets := await _add_live_targets(arena, player, crowd_count)
	if targets.size() != crowd_count:
		_fail("%s/%s/%s did not build its real target state" % [CAPTURE_ID, weapon_id, mode_id])
		_cleanup(arena)
		return false
	var hazards := _add_live_hazards(arena, player, viewport_size, 5 if bool(mode["crowded"]) else 2)
	await process_frame
	await process_frame
	if hazards.is_empty() or not _has_visible_hazard(hazards):
		_fail("%s/%s/%s has no visible shipped HazardVfx telegraph" % [CAPTURE_ID, weapon_id, mode_id])
		_cleanup(arena)
		return false

	var status := PlayerHost.activate(player)
	if status != PlayerHost.ACTIVATION_STARTED:
		_fail("%s/%s/%s real PlayerHost activation failed with status %d" % [CAPTURE_ID, weapon_id, mode_id, status])
		_cleanup(arena)
		return false
	await _advance_seconds(float(weapon["release_seconds"]))
	if not _observe_beat("release", arena, hud_root, hazards, weapon, mode, viewport_spec):
		_cleanup(arena)
		return false
	await _advance_seconds(maxf(float(weapon["active_seconds"]) - float(weapon["release_seconds"]), 0.0))
	if not _observe_beat("active", arena, hud_root, hazards, weapon, mode, viewport_spec):
		_cleanup(arena)
		return false
	var presentation := _find_authored_presentation(arena, weapon_id)
	if presentation == null:
		_fail("%s/%s/%s did not mount its shipped authored presentation scene" % [CAPTURE_ID, weapon_id, mode_id])
		_cleanup(arena)
		return false
	var widget := hud_root.get_node_or_null("UltimateHudWidget") as Control
	if widget == null or not widget.visible:
		_fail("%s/%s/%s did not keep the shipped HUD visible during the active beat" % [CAPTURE_ID, weapon_id, mode_id])
		_cleanup(arena)
		return false

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.get_size() != viewport_size:
		var actual := Vector2i.ZERO if image == null else image.get_size()
		_fail("%s/%s/%s native viewport mismatch: expected %s, got %s" % [CAPTURE_ID, weapon_id, mode_id, viewport_size, actual])
		_cleanup(arena)
		return false
	var filename := "%s__%s__%s.png" % [weapon_id, mode_id, str(viewport_spec["id"])]
	var output_path := _output_dir.path_join(filename)
	if image.save_png(output_path) != OK:
		_fail("%s could not save %s" % [CAPTURE_ID, output_path])
		_cleanup(arena)
		return false
	var impacted_targets := _impacted_target_count(targets)
	if impacted_targets <= 0:
		_fail("%s/%s/%s did not produce a real target impact by the active beat" % [CAPTURE_ID, weapon_id, mode_id])
		_cleanup(arena)
		return false
	print("FAN-3936_CAPTURE_RESULT %s" % JSON.stringify({
		"weapon_id": weapon_id,
		"mode": mode_id,
		"viewport_id": str(viewport_spec["id"]),
		"width": image.get_width(),
		"height": image.get_height(),
		"active_seconds": float(weapon["active_seconds"]),
		"release_seconds": float(weapon["release_seconds"]),
		"recovery_seconds": float(weapon["recovery_seconds"]),
		"crowd_count": crowd_count,
		"screen_shake": bool(mode["screen_shake"]),
		"photosensitivity_strategy": str(mode["photosensitivity_strategy"]),
		"scene_path": str(weapon["scene_path"]),
		"impacted_targets": impacted_targets,
		"file": output_path,
	}))
	await _advance_seconds(maxf(float(weapon["recovery_seconds"]) - float(weapon["active_seconds"]), 0.0))
	if not _observe_beat("recovery", arena, hud_root, hazards, weapon, mode, viewport_spec):
		_cleanup(arena)
		return false
	PlayerHost.reset(player)
	_cleanup(arena)
	return true


func _add_shipped_background(arena: Node2D, viewport_size: Vector2i) -> void:
	var texture := load(BACKGROUND_PATH) as Texture2D
	if texture == null:
		return
	var background := Sprite2D.new()
	background.name = "ShippedArenaBackground"
	background.texture = texture
	background.z_index = -100
	background.position = ARENA_CENTER
	var texture_size := texture.get_size()
	var scale_factor := maxf(
		float(viewport_size.x) / maxf(texture_size.x, 1.0),
		float(viewport_size.y) / maxf(texture_size.y, 1.0)
	) * 1.35
	background.scale = Vector2.ONE * scale_factor
	arena.add_child(background)


func _mount_shipped_hud(arena: Node2D, player: Node2D, viewport_size: Vector2i) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "CertificationHudLayer"
	layer.layer = 20
	arena.add_child(layer)
	var hud_root := Control.new()
	hud_root.name = "CertificationHudRoot"
	hud_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_root.position = Vector2.ZERO
	hud_root.size = Vector2(viewport_size)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_root)
	var adapter := UltimateHudRuntimeAdapter.new()
	adapter.name = "UltimateHudRuntimeAdapter"
	hud_root.add_child(adapter)
	if not adapter.mount(hud_root, player):
		return null
	return hud_root


func _add_live_targets(arena: Node2D, player: Node2D, count: int) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for index in count:
		var enemy := EnemyScene.instantiate() as Node2D
		if enemy == null:
			continue
		var ring := 180.0 + float(index / 6) * 84.0
		var angle := TAU * float(index % 6) / 6.0
		enemy.position = player.position + Vector2.RIGHT.rotated(angle) * ring
		arena.add_child(enemy)
		targets.append(enemy)
	await process_frame
	for enemy in targets:
		enemy.set("health", 100000.0)
		enemy.set("max_health", 100000.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
	return targets


func _add_live_hazards(arena: Node2D, player: Node2D, viewport_size: Vector2i, count: int) -> Array[Node2D]:
	var hazards: Array[Node2D] = []
	for index in count:
		var hazard := Node2D.new()
		hazard.name = "ElitePoisonZone"
		var x_ratio := 0.28 + float(index % 3) * 0.22
		var y_ratio := 0.22 + float(index / 3) * 0.48
		hazard.position = player.position + Vector2(
			(float(viewport_size.x) * x_ratio) - float(viewport_size.x) * 0.5,
			(float(viewport_size.y) * y_ratio) - float(viewport_size.y) * 0.5
		)
		hazard.z_index = -2
		arena.add_child(hazard)
		HazardVfx.telegraph(hazard, 86.0, Color(0.55, 0.95, 0.30, 1.0), 5.0)
		hazards.append(hazard)
	return hazards


func _has_visible_hazard(hazards: Array[Node2D]) -> bool:
	for hazard in hazards:
		var telegraph := hazard.get_node_or_null("HazardTelegraph") as CanvasItem
		if telegraph != null and telegraph.visible:
			return true
	return false


func _observe_beat(
	beat_id: String,
	arena: Node,
	hud_root: Control,
	hazards: Array[Node2D],
	weapon: Dictionary,
	mode: Dictionary,
	viewport_spec: Dictionary,
) -> bool:
	var weapon_id := str(weapon["weapon_id"])
	var mode_id := str(mode["id"])
	var presentation := _find_authored_presentation(arena, weapon_id)
	var widget := hud_root.get_node_or_null("UltimateHudWidget") as Control
	var hud_visible := widget != null and widget.visible
	var hazard_visible := _has_visible_hazard(hazards)
	print("FAN-3936_BEAT_RESULT %s" % JSON.stringify({
		"weapon_id": weapon_id,
		"mode": mode_id,
		"viewport_id": str(viewport_spec["id"]),
		"beat": beat_id,
		"presentation_mounted": presentation != null,
		"hud_visible": hud_visible,
		"hazard_visible": hazard_visible,
	}))
	if presentation == null or not hud_visible or not hazard_visible:
		_fail("%s/%s/%s must retain authored presentation, HUD, and HazardVfx at %s" % [
			CAPTURE_ID,
			weapon_id,
			mode_id,
			beat_id,
		])
		return false
	return true


func _impacted_target_count(targets: Array[Node2D]) -> int:
	var impacted := 0
	for target in targets:
		if is_instance_valid(target) and float(target.get("health")) < 100000.0:
			impacted += 1
	return impacted


func _find_authored_presentation(arena: Node, weapon_id: String) -> Node:
	var expected_id := "%s/%s" % [CLASS_ID, weapon_id]
	var pending: Array[Node] = [arena]
	while not pending.is_empty():
		var current: Node = pending.pop_back() as Node
		if str(current.get_meta("ultimate_id", "")) == expected_id:
			return current
		for child in current.get_children():
			pending.append(child)
	return null


func _advance_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		elapsed += FRAME_SECONDS


func _cleanup(arena: Node) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()


func _output_directory() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_ARGUMENT):
			return ProjectSettings.globalize_path(argument.trim_prefix(OUTPUT_ARGUMENT))
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
