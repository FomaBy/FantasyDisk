extends SceneTree

## FAN-3943 live certification capture for the three canonical Guitarist weapon
## ultimates.
##
## Every frame comes from a real run: `scenes/Main.tscn` is instantiated,
## `_start_combat()` builds the shipped arena, the shipped combat HUD and a real
## `Player` configured for `guitarist/<weapon>`, and shipped `Enemy` instances
## stand in the frame as hazards while the ultimate casts. Nothing about the
## presentation is redrawn here — the script only sizes the window, sets the
## shipped accessibility metadata for the mode, and reads the framebuffer back.
##
## The run is repeated for every weapon x mode x viewport combination, and each
## repetition is sampled at the release, active and recovery beats declared by
## the class reference manifest. All 144 samples are measured at their native
## resolution and written to the capture manifest. The four committed sheets — one
## per viewport, twelve weapon x mode cells at the active beat — are the human
## index of that record.
##
## Headless runs skip: Godot's headless display server owns no framebuffer, so a
## headless capture could only write empty images.
##
##     FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed \
##       --fixed-fps 60 \
##       --script res://tests/ultimates/presentation/guitarist_certification_live_capture.gd
##
## `GUITARIST_CERT_SOURCE_REF`, `GUITARIST_CERT_SOURCE_SHA` and
## `GUITARIST_CERT_SOURCE_TREE` pin the checkout the captures were taken from. They
## are required: the manifest must name a source commit that already exists, not
## the commit that will later carry the manifest itself.
##
## `GUITARIST_CERT_FRAME_DIR` optionally names a directory that receives every
## native full-resolution frame of every beat, so a reviewer can reproduce and
## inspect any single combination at full size.

const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
## Loaded on demand: the focused gate reads this script's constants headlessly
## and must not drag the whole game scene in to do it.
const MAIN_SCENE_PATH := "res://scenes/Main.tscn"

const CLASS_ID := "guitarist"
const MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/guitarist/manifest.json"
const CAPTURE_MANIFEST_PATH := "res://docs/design/references/weapon_ultimates/guitarist/certification_capture_manifest.json"
const OUTPUT_DIR := "res://docs/design/reference-assets-lfs/ultimate-certification/guitarist"
const DRIVER_SCRIPT_PATH := "res://scripts/ultimates/presentation/ultimate_v2_presence_driver.gd"
const VICTIM_IMPACT_SCRIPT_PATH := "res://scripts/ultimates/presentation/victim_impact_player.gd"
const BACKDROP_NODE_NAME := "BackdropVeil"

const WEAPON_IDS: Array[String] = ["electric_guitar", "bass_guitar", "sound_amp"]
const BEAT_IDS: Array[String] = ["release", "active", "recovery"]
const REQUIRED_NODES_BY_WEAPON := {
	"electric_guitar": ["LastChord"],
	"bass_guitar": ["Subwoofer"],
	"sound_amp": ["WallOfSound"],
}
## The shared visual-direction contract admits exactly one committed contact
## sheet per supported viewport, so the package commits four native-size sheets
## and carries the per-beat record as measurements instead of more PNGs.
const SHEET_BEAT := "active"

## The four presentation modes are driven only through metadata the shipped game
## already publishes on the scene-tree root: `screen_shake` is the reduced-motion
## switch every Guitarist driver reads in `_ready()`, and `combat_feedback` is the
## flash switch the victim-impact player and the enemy hit flash read. Nothing is
## suppressed or redrawn for the capture.
const MODES := [
	{
		"id": "normal",
		"label": "NORMAL",
		"screen_shake": true,
		"combat_feedback": true,
		"hazards": 6,
		"crowd_cap": false,
	},
	{
		"id": "crowded",
		"label": "CROWDED",
		"screen_shake": true,
		"combat_feedback": true,
		"hazards": 6,
		"crowd_cap": true,
	},
	{
		"id": "reduced_motion",
		"label": "REDUCED MOTION",
		"screen_shake": false,
		"combat_feedback": true,
		"hazards": 6,
		"crowd_cap": false,
	},
	{
		"id": "photosensitivity_safe",
		"label": "PHOTOSENSITIVITY SAFE",
		"screen_shake": false,
		"combat_feedback": false,
		"hazards": 6,
		"crowd_cap": false,
	},
]

const VIEWPORTS := [
	{"id": "648p", "size": Vector2i(1152, 648)},
	{"id": "720p", "size": Vector2i(1280, 720)},
	{"id": "1080p", "size": Vector2i(1920, 1080)},
	{"id": "2k", "size": Vector2i(2560, 1440)},
]

## Fixed hazard geometry. A ring keeps the shipped enemies inside every viewport
## and away from the cast origin, so the same layout reads at 648p and at 2K.
const HAZARD_RING_RADII := [230.0, 300.0, 370.0]
const HAZARD_PARKING := Vector2(6000.0, 6000.0)
const HAZARD_HEALTH := 100000.0
const CAPTURE_SEED := 394320260910

const FIXED_STEP := 1.0 / 60.0
const SETTLE_FRAMES := 8
const CHANGED_PIXEL_EPSILON := 0.08
const FLASH_LUMINANCE := 0.92
const MEASURE_STRIDE := 2

var _weapon_manifest := {}
var _records: Array[Dictionary] = []
var _sheets: Array[Dictionary] = []
var _frame_dir := ""
var _source := {}
var _sheet_panels := {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3943 Guitarist certification capture skipped (headless); run windowed for PNG evidence.")
		quit(0)
		return
	seed(CAPTURE_SEED)
	_source = {
		"ref": OS.get_environment("GUITARIST_CERT_SOURCE_REF").strip_edges(),
		"commit_sha": OS.get_environment("GUITARIST_CERT_SOURCE_SHA").strip_edges().to_lower(),
		"tree_sha": OS.get_environment("GUITARIST_CERT_SOURCE_TREE").strip_edges().to_lower(),
	}
	for field in ["ref", "commit_sha", "tree_sha"]:
		if str(_source[field]).is_empty():
			push_error("FAN-3943 Guitarist certification capture: GUITARIST_CERT_SOURCE_%s must name the checkout the captures come from" % field.to_upper())
			quit(1)
			return
	_frame_dir = OS.get_environment("GUITARIST_CERT_FRAME_DIR").strip_edges()
	if not _frame_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_frame_dir)
	var manifest := _load_json(MANIFEST_PATH)
	if manifest.is_empty():
		push_error("FAN-3943 Guitarist certification capture: %s is missing or invalid" % MANIFEST_PATH)
		quit(1)
		return
	for raw_weapon in manifest.get("weapons", []) as Array:
		var weapon := raw_weapon as Dictionary
		_weapon_manifest[str(weapon.get("weapon_id", ""))] = weapon
	var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if output_error != OK and output_error != ERR_ALREADY_EXISTS:
		push_error("FAN-3943 Guitarist certification capture: cannot create %s (%s)" % [OUTPUT_DIR, error_string(output_error)])
		quit(1)
		return

	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		_sheet_panels.clear()
		for weapon_id in WEAPON_IDS:
			for raw_mode in MODES:
				var mode := raw_mode as Dictionary
				var failure := await _capture_combination(viewport, weapon_id, mode)
				if not failure.is_empty():
					push_error("FAN-3943 Guitarist certification capture: %s" % failure)
					quit(1)
					return
		var matrix_error := await _write_matrix_sheet(viewport)
		if matrix_error != OK:
			push_error("FAN-3943 Guitarist certification capture: matrix sheet %s failed (%s)" % [viewport["id"], error_string(matrix_error)])
			quit(1)
			return

	var write_error := _write_capture_manifest()
	if write_error != OK:
		push_error("FAN-3943 Guitarist certification capture: manifest write failed (%s)" % error_string(write_error))
		quit(1)
		return
	print("FAN-3943 Guitarist certification capture: %d samples, %d sheets written to %s" % [
		_records.size(), _sheets.size(), OUTPUT_DIR,
	])
	quit(0)


## One live run: build the arena, hold the mode's shipped switches, cast the
## ultimate and sample the declared beats.
func _capture_combination(viewport: Dictionary, weapon_id: String, mode: Dictionary) -> String:
	var size := viewport["size"] as Vector2i
	var mode_id := str(mode["id"])
	var beats := _beats_for(weapon_id)
	if beats.is_empty():
		return "%s declares no release/active/recovery beats" % weapon_id

	var main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	## `Main._ready()` randomizes its own generator; the capture pins it so two
	## runs place the same wave.
	var run_rng := main.get("rng") as RandomNumberGenerator
	if run_rng != null:
		run_rng.seed = CAPTURE_SEED
	main.set("selected_character_id", CLASS_ID)
	main.set("selected_weapon_id", weapon_id)
	main.call("_start_combat", false, "battle")
	for _frame in SETTLE_FRAMES:
		await process_frame
	## `Main` restores its own window geometry while it boots, so the capture
	## size is applied to the live run and then confirmed.
	await _apply_window_size(size)
	if root.size != size:
		main.queue_free()
		await process_frame
		return "%s/%s/%s window is %s, expected %s" % [weapon_id, mode_id, viewport["id"], str(root.size), str(size)]

	var player := main.get("current_player") as Node2D
	if player == null:
		main.queue_free()
		await process_frame
		return "%s/%s/%s produced no live player" % [weapon_id, mode_id, viewport["id"]]
	var hud_layer := main.get("hud_layer") as CanvasLayer
	var hud_root: Control = null
	if hud_layer != null:
		hud_root = hud_layer.find_child("CombatHudRoot", true, false) as Control
	if hud_root == null:
		main.queue_free()
		await process_frame
		return "%s/%s/%s produced no live combat HUD" % [weapon_id, mode_id, viewport["id"]]

	## The shipped accessibility switches are set after `Main` has published its
	## own settings, and before the ultimate spawns: the Guitarist driver reads
	## `screen_shake` once in `_ready()`.
	root.set_meta("screen_shake", bool(mode["screen_shake"]))
	root.set_meta("combat_feedback", bool(mode["combat_feedback"]))
	main.set("screen_shake_enabled", bool(mode["screen_shake"]))
	main.set("combat_feedback_enabled", bool(mode["combat_feedback"]))

	var hazard_count := int(mode["hazards"])
	if bool(mode["crowd_cap"]):
		hazard_count = _crowd_cap(weapon_id)
	var hazards := await _prepare_hazards(main, player, hazard_count)
	if hazards.size() < hazard_count:
		main.queue_free()
		await process_frame
		return "%s/%s/%s placed %d of %d hazards" % [weapon_id, mode_id, viewport["id"], hazards.size(), hazard_count]

	for _frame in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var baseline := root.get_texture().get_image()
	if baseline == null or baseline.get_size() != size:
		main.queue_free()
		await process_frame
		return "%s/%s/%s baseline frame is %s, expected %s" % [
			weapon_id, mode_id, viewport["id"],
			"null" if baseline == null else str(baseline.get_size()), str(size),
		]
	baseline.convert(Image.FORMAT_RGB8)

	var status := PlayerHost.activate(player)
	if status != PlayerHost.ACTIVATION_STARTED:
		var failure := PlayerHost.activation_failure(player)
		main.queue_free()
		await process_frame
		return "%s/%s/%s did not start the ultimate (status %d, %s)" % [
			weapon_id, mode_id, viewport["id"], status, failure,
		]

	var elapsed := 0.0
	for beat in beats:
		var target := float(beat["sample_time"])
		while elapsed < target:
			await process_frame
			elapsed += FIXED_STEP
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		if frame == null or frame.get_size() != size:
			main.queue_free()
			await process_frame
			return "%s/%s/%s %s frame is %s, expected %s" % [
				weapon_id, mode_id, viewport["id"], str(beat["phase"]),
				"null" if frame == null else str(frame.get_size()), str(size),
			]
		frame.convert(Image.FORMAT_RGB8)
		var effect_root := _presentation_root(main)
		var record := _measure(frame, baseline, size, effect_root, player, hud_root, hazards)
		record["weapon_id"] = weapon_id
		record["mode"] = mode_id
		record["viewport"] = str(viewport["id"])
		record["width"] = size.x
		record["height"] = size.y
		record["beat"] = str(beat["phase"])
		record["beat_seconds"] = snappedf(target, 0.001)
		record["declared_beat_seconds"] = float(beat["declared_time"])
		record["required_nodes_present"] = _required_nodes_present(effect_root, beat)
		record["presentation_scene"] = str(_weapon_manifest.get(weapon_id, {}).get("scene_path", ""))
		record["hazards_placed"] = hazards.size()
		_records.append(record)
		_store_panel(viewport, weapon_id, mode_id, str(beat["phase"]), frame)
		if not _frame_dir.is_empty():
			frame.save_png("%s/guitarist_%s_%s_%s_%s.png" % [
				_frame_dir, weapon_id, mode_id, str(viewport["id"]), str(beat["phase"]),
			])

	PlayerHost.reset(player)
	main.queue_free()
	await process_frame
	return ""


func _live_hazards() -> Array[Node2D]:
	var live: Array[Node2D] = []
	for node in get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node):
			live.append(node as Node2D)
	return live


func _apply_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for _frame in 30:
		await process_frame
		if root.size == size:
			break


## Shipped enemies become the hazards. Extra spawns are parked far outside the
## frame instead of being freed, so the live wave bookkeeping stays untouched.
func _prepare_hazards(main: Node, player: Node2D, wanted: int) -> Array[Node2D]:
	main.set("spawn_cooldown", 1.0e9)
	var combat: Object = main.get("combat")
	var live := _live_hazards()
	## Wave pressure alone does not reach the declared crowd cap, so the shortfall
	## is spawned through the same shipped spawn path the waves use.
	var guard := 0
	while live.size() < wanted and guard < wanted * 3:
		var angle := float(guard) * TAU / 8.0
		var spot := player.global_position + Vector2(float(HAZARD_RING_RADII[guard % HAZARD_RING_RADII.size()]), 0.0).rotated(angle)
		if combat.call("_spawn_random_enemy", main.get("enemy_scene"), spot, true, 0.0) == null:
			break
		guard += 1
		live = _live_hazards()
	await process_frame
	live = _live_hazards()
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
		var angle := float(slot) * TAU / 8.0 + 0.19625 * float(ring)
		enemy.global_position = player.global_position + Vector2(radius, 0.0).rotated(angle)
		placed.append(enemy)
	await process_frame
	return placed


func _measure(
	frame: Image,
	baseline: Image,
	size: Vector2i,
	effect_root: Node2D,
	player: Node2D,
	hud_root: Control,
	hazards: Array[Node2D]
) -> Dictionary:
	## The arena-wide `BackdropVeil` is the declared `presence.backdrop` darken,
	## not drawn effect area, so it is measured on its own. What remains is the
	## box the class manifest bounds with `quality.max_viewport_coverage_ratio`.
	var effect_box := _effect_screen_box(effect_root, false)
	var backdrop_box := _effect_screen_box(effect_root, true)
	var hud_rects := _hud_band_rects(hud_root)
	var viewport_area := float(size.x) * float(size.y)
	## Raw RGB8 bytes: 144 samples up to 2560x1440 are far too many pixels for
	## per-pixel `Image.get_pixel()` calls.
	var current_bytes := frame.get_data()
	var baseline_bytes := baseline.get_data()
	var delta_limit := int(round(CHANGED_PIXEL_EPSILON * 255.0))
	var flash_limit := FLASH_LUMINANCE * 255.0
	var changed := 0
	var flashed := 0
	var sampled := 0
	for y in range(0, size.y, MEASURE_STRIDE):
		var row := y * size.x
		for x in range(0, size.x, MEASURE_STRIDE):
			var offset := (row + x) * 3
			var red: int = current_bytes[offset]
			var green: int = current_bytes[offset + 1]
			var blue: int = current_bytes[offset + 2]
			var delta: int = maxi(
				maxi(absi(red - baseline_bytes[offset]), absi(green - baseline_bytes[offset + 1])),
				absi(blue - baseline_bytes[offset + 2])
			)
			sampled += 1
			if delta > delta_limit:
				changed += 1
			if 0.2126 * float(red) + 0.7152 * float(green) + 0.0722 * float(blue) > flash_limit:
				flashed += 1
	var visible_hazards := 0
	for hazard in hazards:
		if not is_instance_valid(hazard):
			continue
		var point := _frame_point(hazard.get_global_transform_with_canvas().origin)
		if Rect2(Vector2.ZERO, Vector2(size)).has_point(point):
			visible_hazards += 1
	var hud_overlap := 0.0
	var hud_min_contrast := 1.0
	for rect in hud_rects:
		var overlap := effect_box.intersection(rect)
		if overlap.has_area():
			hud_overlap += overlap.get_area()
		hud_min_contrast = minf(hud_min_contrast, _rect_contrast(current_bytes, size, rect))
	return {
		"effect_box_ratio": snappedf(effect_box.get_area() / viewport_area, 0.0001),
		"backdrop_box_ratio": snappedf(backdrop_box.get_area() / viewport_area, 0.0001),
		"changed_pixel_ratio": snappedf(float(changed) / float(maxi(sampled, 1)), 0.0001),
		"flash_pixel_ratio": snappedf(float(flashed) / float(maxi(sampled, 1)), 0.0001),
		"hud_bands_measured": hud_rects.size(),
		"hud_bands_clear": hud_overlap <= 0.0,
		"hud_band_overlap_px": snappedf(hud_overlap, 0.1),
		"hud_band_min_contrast": snappedf(hud_min_contrast if not hud_rects.is_empty() else 0.0, 0.001),
		"player_contrast": snappedf(_player_contrast(current_bytes, size, player), 0.001),
		"hazards_in_frame": visible_hazards,
		"effect_nodes_drawn": _drawn_node_count(effect_root),
	}


## Luminance range inside a framebuffer rect. A HUD band that still separates
## its text from its panel keeps a wide range; an occluded band collapses.
func _rect_contrast(bytes: PackedByteArray, size: Vector2i, rect: Rect2) -> float:
	var minimum := 1.0
	var maximum := 0.0
	var samples := 0
	for y in range(maxi(0, int(rect.position.y)), mini(size.y, int(rect.end.y)), MEASURE_STRIDE):
		var row := y * size.x
		for x in range(maxi(0, int(rect.position.x)), mini(size.x, int(rect.end.x)), MEASURE_STRIDE):
			var offset := (row + x) * 3
			var value := (
				0.2126 * float(bytes[offset])
				+ 0.7152 * float(bytes[offset + 1])
				+ 0.0722 * float(bytes[offset + 2])
			) / 255.0
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
			samples += 1
	return maximum - minimum if samples > 0 else 0.0


## Union of the on-screen boxes of everything the presentation scene actually
## draws. This is the same measurement the class manifest records as
## `quality.max_viewport_coverage_ratio`.
func _effect_screen_box(effect_root: Node2D, backdrop_only: bool) -> Rect2:
	if effect_root == null:
		return Rect2()
	var box := Rect2()
	var seeded := false
	## Victim-side impact bursts have their own bounded pool contract and are not
	## part of the activation scene's declared footprint or visual-node budget.
	for node in _drawn_nodes(effect_root, false):
		if (node.name == BACKDROP_NODE_NAME) != backdrop_only:
			continue
		var rect := _screen_rect(node)
		if not rect.has_area():
			continue
		if seeded:
			box = box.merge(rect)
		else:
			box = rect
			seeded = true
	return box


func _drawn_nodes(effect_root: Node2D, include_victim_impacts := true) -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	if effect_root == null:
		return found
	var pending: Array[Node] = [effect_root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if not include_victim_impacts and node != effect_root:
			var script := node.get_script() as Script
			if script != null and script.resource_path == VICTIM_IMPACT_SCRIPT_PATH:
				continue
		for child in node.get_children():
			pending.append(child)
		var item := node as CanvasItem
		if item == null or item == effect_root:
			continue
		if item.visible and item.modulate.a > 0.01 and item.self_modulate.a > 0.01:
			found.append(item)
	return found


func _drawn_node_count(effect_root: Node2D) -> int:
	return _drawn_nodes(effect_root).size()


func _screen_rect(item: CanvasItem) -> Rect2:
	var local := Rect2()
	if item is Sprite2D:
		local = (item as Sprite2D).get_rect()
	elif item is AnimatedSprite2D:
		var sprite := item as AnimatedSprite2D
		var frames := sprite.sprite_frames
		if frames == null or not frames.has_animation(sprite.animation):
			return Rect2()
		var count := frames.get_frame_count(sprite.animation)
		if count <= 0:
			return Rect2()
		var texture := frames.get_frame_texture(sprite.animation, clampi(sprite.frame, 0, count - 1))
		if texture == null:
			return Rect2()
		var extent := Vector2(texture.get_size())
		local = Rect2(-extent * 0.5 if sprite.centered else Vector2.ZERO, extent)
		local.position += sprite.offset
	elif item is Polygon2D:
		var polygon := (item as Polygon2D).polygon
		if polygon.is_empty():
			return Rect2()
		local = Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			local = local.expand(point)
	else:
		return Rect2()
	## `get_global_transform_with_canvas()` answers in the project's stretch base
	## (2560x1440); the framebuffer this capture reads back is the window. The
	## root's final transform is exactly that conversion.
	var transform := root.get_final_transform() * item.get_global_transform_with_canvas()
	var box := Rect2(transform * local.position, Vector2.ZERO)
	for corner in [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		box = box.expand(transform * corner)
	return box


## Real HUD geometry, read from the live combat HUD instead of hard-coded bands.
func _hud_band_rects(hud_root: Control) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if hud_root == null:
		return rects
	for child in hud_root.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var canvas_rect := control.get_global_rect()
		## The HUD root also carries full-screen overlays (damage flash, low-HP
		## vignette). They are not readable bands and would swallow the frame.
		if canvas_rect.size.x >= hud_root.size.x * 0.9 and canvas_rect.size.y >= hud_root.size.y * 0.9:
			continue
		var rect := Rect2(_frame_point(canvas_rect.position), _frame_point(canvas_rect.end) - _frame_point(canvas_rect.position))
		if rect.size.x < 12.0 or rect.size.y < 6.0:
			continue
		rects.append(rect)
	return rects


## Canvas space (the project's 2560x1440 stretch base) to framebuffer pixels.
func _frame_point(point: Vector2) -> Vector2:
	return root.get_final_transform() * point


func _player_contrast(bytes: PackedByteArray, size: Vector2i, player: Node2D) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var center := _frame_point(player.get_global_transform_with_canvas().origin)
	var half := maxf(24.0, float(size.y) * 0.045)
	return _rect_contrast(bytes, size, Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0))


func _required_nodes_present(effect_root: Node2D, beat: Dictionary) -> bool:
	if effect_root == null:
		return false
	for raw_name in beat.get("required_nodes", []) as Array:
		var node := effect_root.get_node_or_null(NodePath(str(raw_name))) as CanvasItem
		if node == null or not node.visible:
			return false
	return true


func _presentation_root(main: Node) -> Node2D:
	for child in main.find_children("*", "Node2D", true, false):
		var effect_root := child as Node2D
		var driver := effect_root.get_node_or_null("PresenceDriver")
		var script := driver.get_script() as Script if driver != null else null
		if script != null and script.resource_path == DRIVER_SCRIPT_PATH:
			return effect_root
	return null


## The source-pinned class manifest owns the certified phase boundaries. A live
## cast releases its presentation node at `recovery`, so that sample is pulled
## back to the last frame the live scene still draws. Both times are published.
func _beats_for(weapon_id: String) -> Array:
	var weapon := _weapon_manifest.get(weapon_id, {}) as Dictionary
	var timing := weapon.get("timing_seconds", {}) as Dictionary
	var last_drawn_frame := float(timing.get("recovery", 0.0)) - 2.0 * FIXED_STEP
	var ordered: Array = []
	for beat_id in BEAT_IDS:
		var declared_time := float(timing.get(beat_id, 0.0))
		if declared_time <= 0.0:
			return []
		var sample_time := minf(declared_time, last_drawn_frame) if beat_id == "recovery" else declared_time
		ordered.append({
			"phase": beat_id,
			"required_nodes": REQUIRED_NODES_BY_WEAPON.get(weapon_id, []),
			"declared_time": declared_time,
			"sample_time": sample_time,
		})
	return ordered if ordered.size() == BEAT_IDS.size() else []


func _crowd_cap(weapon_id: String) -> int:
	var weapon := _weapon_manifest.get(weapon_id, {}) as Dictionary
	var performance := weapon.get("performance", {}) as Dictionary
	return maxi(1, int(performance.get("crowd_cap", 12)))


func _store_panel(viewport: Dictionary, weapon_id: String, mode_id: String, beat_id: String, frame: Image) -> void:
	if beat_id != SHEET_BEAT:
		return
	var cell := matrix_cell_rect(viewport["size"] as Vector2i, WEAPON_IDS.find(weapon_id), _mode_index(mode_id))
	_sheet_panels["%s/%s" % [weapon_id, mode_id]] = _panel_image(frame, cell.size)


func _panel_image(frame: Image, target: Vector2) -> Image:
	var panel := frame.duplicate() as Image
	panel.resize(maxi(1, int(target.x)), maxi(1, int(target.y)), Image.INTERPOLATE_LANCZOS)
	return panel


func _mode_index(mode_id: String) -> int:
	for index in MODES.size():
		if str((MODES[index] as Dictionary)["id"]) == mode_id:
			return index
	return 0


func _write_matrix_sheet(viewport: Dictionary) -> int:
	var size := viewport["size"] as Vector2i
	var host := Node2D.new()
	_add_backdrop(host, size)
	_add_heading(host, size, "GUITARIST ULTIMATES — LIVE %s CAPTURE • ACTIVE BEAT • REAL PLAYER, HAZARDS AND HUD" % str(viewport["id"]).to_upper())
	for weapon_index in WEAPON_IDS.size():
		for mode_index in MODES.size():
			var weapon_id := WEAPON_IDS[weapon_index]
			var mode := MODES[mode_index] as Dictionary
			var cell := matrix_cell_rect(size, weapon_index, mode_index)
			var panel := _sheet_panels.get("%s/%s" % [weapon_id, str(mode["id"])], null) as Image
			_add_cell(host, size, cell, panel, "%s — %s" % [weapon_id.to_upper(), str(mode["label"])])
	var path := "%s/guitarist_certification_%s.png" % [OUTPUT_DIR, str(viewport["id"])]
	var result := await _render_sheet(host, size, path)
	if result == OK:
		_sheets.append({
			"sha256": FileAccess.get_sha256(path).to_lower(),
			"kind": "mode_matrix",
			"viewport": str(viewport["id"]),
			"width": size.x,
			"height": size.y,
			"beat": SHEET_BEAT,
			"path": path.trim_prefix("res://"),
			"rows": WEAPON_IDS.duplicate(),
			"columns": _mode_ids(),
		})
	return result


func _render_sheet(host: Node2D, size: Vector2i, path: String) -> int:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(host)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	if image == null:
		return ERR_CANT_CREATE
	image.convert(Image.FORMAT_RGB8)
	var result := image.save_png(ProjectSettings.globalize_path(path))
	if result == OK:
		print("FAN-3943 Guitarist certification capture saved: %s" % path)
	return result


func _add_backdrop(host: Node2D, size: Vector2i) -> void:
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size), Vector2(0, size.y)])
	background.color = Color(0.035, 0.026, 0.030, 1.0)
	background.z_index = -50
	host.add_child(background)


func _add_heading(host: Node2D, size: Vector2i, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.position = Vector2(float(size.x) * 0.012, float(size.y) * 0.016)
	heading.add_theme_font_size_override("font_size", maxi(11, roundi(float(size.y) * 0.026)))
	heading.add_theme_color_override("font_color", Color(0.97, 0.86, 0.68))
	heading.z_index = 60
	host.add_child(heading)


func _add_cell(host: Node2D, size: Vector2i, cell: Rect2, panel: Image, caption: String) -> void:
	var frame_polygon := Polygon2D.new()
	frame_polygon.polygon = PackedVector2Array([
		cell.position,
		Vector2(cell.end.x, cell.position.y),
		cell.end,
		Vector2(cell.position.x, cell.end.y),
	])
	frame_polygon.color = Color(0.10, 0.07, 0.09, 1.0)
	frame_polygon.z_index = -10
	host.add_child(frame_polygon)
	if panel != null and not panel.is_empty():
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(panel)
		sprite.position = cell.position
		host.add_child(sprite)
	var label := Label.new()
	label.text = caption
	label.position = cell.position + Vector2(6.0, cell.size.y + 2.0)
	label.add_theme_font_size_override("font_size", maxi(9, roundi(float(size.y) * 0.017)))
	label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.98))
	label.z_index = 60
	host.add_child(label)


func _write_capture_manifest() -> int:
	var payload := {
		"schema_version": 1,
		"issue": "FAN-3943",
		"class_id": CLASS_ID,
		"source": _source,
		"canonical_weapon_ids": WEAPON_IDS.duplicate(),
		"presentation_modes": _mode_declarations(),
		"beats": BEAT_IDS.duplicate(),
		"viewports": _viewport_declarations(),
		"capture": {
			"method": "windowed live run: scenes/Main.tscn + _start_combat(), shipped combat HUD, shipped Enemy hazards, ultimate cast through UltimatePlayerHost.activate()",
			"capture_script": "tests/ultimates/presentation/guitarist_certification_live_capture.gd",
			"focused_test": "tests/ultimates/presentation/guitarist_certification_capture_test.gd",
			"seed": CAPTURE_SEED,
			"fixed_fps": 60,
			"godot_version": "%s.%s" % [
				str(Engine.get_version_info().get("string", "")),
				str(Engine.get_version_info().get("hash", "")).substr(0, 9),
			],
			"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			"rendering_driver": str(RenderingServer.get_video_adapter_api_version()),
			"video_adapter": str(RenderingServer.get_video_adapter_name()),
			"platform": OS.get_name(),
			"hazard_health": HAZARD_HEALTH,
			"hazard_ring_radii": HAZARD_RING_RADII.duplicate(),
			"beat_source": "docs/design/references/weapon_ultimates/guitarist/manifest.json#weapons[].timing_seconds",
			"captured_at": Time.get_datetime_string_from_system(true, true),
		},
		"commands": {
			"live_capture": "GUITARIST_CERT_SOURCE_REF=<ref> GUITARIST_CERT_SOURCE_SHA=<sha> GUITARIST_CERT_SOURCE_TREE=<tree> python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/guitarist_certification_live_capture.gd",
			"focused_test": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/guitarist_certification_capture_test.gd",
			"class_timelines": "python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/guitarist_ultimate_timelines.gd",
			"static_guard": "python3 tools/quality_static_guard.py --changed-ref <declared-base-sha>",
			"lfs_integrity": "git lfs fsck",
		},
		"sheets": _sheets,
		"samples": _records,
	}
	var file := FileAccess.open(CAPTURE_MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "  ", false) + "\n")
	file.close()
	return OK


func _mode_declarations() -> Array:
	var declared: Array = []
	for raw_mode in MODES:
		var mode := raw_mode as Dictionary
		declared.append({
			"id": str(mode["id"]),
			"label": str(mode["label"]),
			"screen_shake": bool(mode["screen_shake"]),
			"combat_feedback": bool(mode["combat_feedback"]),
			"crowd_cap": bool(mode["crowd_cap"]),
		})
	return declared


func _mode_ids() -> Array:
	var ids: Array = []
	for raw_mode in MODES:
		ids.append(str((raw_mode as Dictionary)["id"]))
	return ids


func _viewport_declarations() -> Array:
	var declared: Array = []
	for raw_viewport in VIEWPORTS:
		var viewport := raw_viewport as Dictionary
		var size := viewport["size"] as Vector2i
		declared.append({"id": str(viewport["id"]), "width": size.x, "height": size.y})
	return declared


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## Sheet geometry is shared with the focused gate so it can probe the committed
## pixels without repeating the layout arithmetic.
static func sheet_body_rect(size: Vector2i) -> Rect2:
	var top := float(size.y) * 0.075
	return Rect2(
		Vector2(float(size.x) * 0.012, top),
		Vector2(float(size.x) * 0.976, float(size.y) - top - float(size.y) * 0.012)
	)


static func matrix_cell_rect(size: Vector2i, row: int, column: int) -> Rect2:
	return _grid_cell(size, row, column, WEAPON_IDS.size(), MODES.size())


static func _grid_cell(size: Vector2i, row: int, column: int, rows: int, columns: int) -> Rect2:
	var body := sheet_body_rect(size)
	var gap := float(size.y) * 0.010
	var caption := float(size.y) * 0.024
	var cell_width := (body.size.x - gap * float(columns - 1)) / float(columns)
	var cell_height := (body.size.y - (gap + caption) * float(rows - 1) - caption) / float(rows)
	return Rect2(
		Vector2(
			body.position.x + float(column) * (cell_width + gap),
			body.position.y + float(row) * (cell_height + gap + caption)
		),
		Vector2(floorf(cell_width), floorf(cell_height))
	)
