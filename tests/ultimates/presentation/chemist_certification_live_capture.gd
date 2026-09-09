extends SceneTree

## Windowed runtime renderer for FAN-3937's Chemist certification package.
##
## The four output sheets are evidence, not a replacement scene: every cell
## instantiates a shipped Chemist V2 presentation scene, samples a fixed live
## beat, and freezes it after the actual mode setup has run. The player, enemy,
## hazard, and ultimate-HUD resources are existing project resources arranged
## only to make the readability reviewable in one deterministic frame.

const Spec := preload("res://tests/ultimates/presentation/chemist_certification_capture_test.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const PD := preload("res://scripts/progression_data.gd")
const HudWidgetScene := preload("res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn")
const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const HAZARD_COLOR := Color(1.0, 0.48, 0.18, 0.92)
const ENEMY_COLOR := Color(0.90, 0.54, 0.62, 0.96)
const PLAYER_BACKPLATE := Color(0.07, 0.10, 0.08, 0.88)
const STATE_BAND_COLOR := Color(0.045, 0.065, 0.050, 0.96)
const STATE_TEXT_COLOR := Color(0.78, 0.92, 0.78, 1.0)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FAN-3937 Chemist certification capture requires a windowed renderer; headless output is not evidence.")
		quit(2)
		return
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	if not registry.is_valid():
		push_error("FAN-3937 Chemist certification capture cannot start: weapon registry is invalid")
		quit(1)
		return
	if HudWidgetScene == null:
		push_error("FAN-3937 Chemist certification capture cannot load the shipped ultimate HUD widget")
		quit(1)
		return
	seed(Spec.CAPTURE_SEED)
	for raw_capture in Spec.CAPTURES:
		var capture := raw_capture as Dictionary
		var result := await _capture_sheet(registry, capture)
		if result != OK:
			push_error("FAN-3937 Chemist certification capture failed: %s" % error_string(result))
			quit(1)
			return
	root.set_meta("screen_shake", true)
	quit(0)


func _capture_sheet(registry, capture: Dictionary) -> int:
	var size := capture.get("size", Vector2i.ZERO) as Vector2i
	var output := str(capture.get("path", ""))
	if size == Vector2i.ZERO or output.is_empty():
		return ERR_INVALID_PARAMETER
	var directory_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	if directory_result != OK:
		return directory_result
	var entries := _build_sheet(registry, size)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw

	var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Spec.BACKGROUND_COLOR)
	var failed := false
	for entry in entries:
		var image := _read_viewport(entry["viewport"] as SubViewport, str(entry["label"]))
		if image == null:
			failed = true
			break
		var target := entry["target"] as Vector2i
		if bool(entry["blend"]):
			sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), target)
		else:
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), target)
	for entry in entries:
		(entry["viewport"] as SubViewport).queue_free()
	await process_frame
	if failed:
		return ERR_CANT_CREATE
	var result := sheet.save_png(ProjectSettings.globalize_path(output))
	if result == OK:
		print("FAN-3937 Chemist certification capture saved: %s (%dx%d)" % [output, size.x, size.y])
	return result


## Each ultimate receives its own live arena viewport. Chemist's backdrop veil
## is world-sized, so a single shared viewport would make one effect's veil
## obscure unrelated cells and would no longer be a faithful scene capture.
func _build_sheet(registry, size: Vector2i) -> Array[Dictionary]:
	var viewports: Array[Dictionary] = []
	for weapon_index in Spec.PACKS.size():
		for mode_index in Spec.MODES.size():
			var arena := Spec.arena_rect(size, weapon_index, mode_index)
			viewports.append({
				"viewport": _arena_viewport(registry, arena.size, weapon_index, mode_index),
				"target": arena.position,
				"label": "%s/%s" % [Spec.WEAPON_IDS[weapon_index], Spec.MODE_IDS[mode_index]],
				"blend": false,
			})
	viewports.append({
		"viewport": _chrome_viewport(registry, size),
		"target": Vector2i.ZERO,
		"label": "chrome",
		"blend": true,
	})
	return viewports


func _arena_viewport(registry, arena_size: Vector2i, weapon_index: int, mode_index: int) -> SubViewport:
	var pack := Spec.PACKS[weapon_index] as Dictionary
	var mode := Spec.MODES[mode_index] as Dictionary
	var viewport := _viewport(arena_size, false)
	var host := Node2D.new()
	viewport.add_child(host)
	host.add_child(_rect_node(Rect2(Vector2.ZERO, Vector2(arena_size)), Spec.FLOOR_COLOR))

	var victims := _visual_victims(arena_size, Spec.victim_count(pack, mode))
	for victim in victims:
		host.add_child(victim)
	host.add_child(_player_node(arena_size))
	for hazard in _hazard_nodes(arena_size):
		host.add_child(hazard)

	## The exact setting read by the V2 scene's `_ready()` is published before the
	## scene joins the tree. After a fixed seek it is held, avoiding frame-pacing
	## drift in the saved proof.
	root.set_meta("screen_shake", bool(mode["screen_shake"]))
	var scene := Spec.instantiate_scene(pack)
	host.add_child(scene)
	Spec.seek_scene(scene, float((pack["beats"] as Dictionary)["active"]))
	if scene.has_method("_fit_backdrop_to_viewport"):
		scene.call("_fit_backdrop_to_viewport")
	if bool(mode["photosafe"]):
		Spec.apply_photosafe(scene)
	Spec.layout_scene(scene, arena_size)
	scene.present("fan3937.capture", {"victims": victims})
	_hold_victim_impacts(scene)
	return viewport


func _chrome_viewport(registry, size: Vector2i) -> SubViewport:
	var viewport := _viewport(size, true)
	var host := Node2D.new()
	viewport.add_child(host)
	var title := Label.new()
	title.text = "CHEMIST ULTIMATES — WINDOWED CERTIFICATION MATRIX"
	title.position = Vector2(size.x * 0.022, size.y * 0.020)
	title.add_theme_font_size_override("font_size", maxi(16, roundi(size.y * 0.032)))
	title.add_theme_color_override("font_color", Color(0.82, 1.0, 0.56))
	title.z_index = 300
	host.add_child(title)
	_add_shipped_hud(host, registry, size)
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
			host.add_child(_sheet_state_caption(size, weapon_index, mode_index, pack, mode))
	return viewport


func _add_shipped_hud(host: Node2D, registry, size: Vector2i) -> void:
	## This is the actual reusable ultimate HUD scene, fed by its production view
	## model and registry state. It sits in a CanvasLayer above world VFX just as
	## it does in combat; the nearby caption only identifies the capture purpose.
	var layer := CanvasLayer.new()
	layer.layer = 20
	host.add_child(layer)
	var hud := HudWidgetScene.instantiate() as PanelContainer
	hud.position = Vector2(size.x * 0.022, size.y * 0.072)
	hud.size = Vector2(size.x * 0.52, size.y * 0.105)
	## The widget's allocated size is already proportional to the sheet. Scaling
	## it again at 1080p/2k would spill into the first matrix row and obscure
	## its mode evidence.
	hud.scale = Vector2.ONE
	hud.apply_state(Spec.hud_state(registry, "blast_powder"))
	layer.add_child(hud)
	var caption := Label.new()
	caption.text = "SHIPPED ULTIMATE HUD • ACTIVE CHEMIST STATE • HUD ABOVE WORLD VFX"
	caption.position = Vector2(size.x * 0.585, size.y * 0.105)
	caption.add_theme_font_size_override("font_size", maxi(9, roundi(size.y * 0.016)))
	caption.add_theme_color_override("font_color", Color(0.74, 0.88, 0.76))
	layer.add_child(caption)


func _player_node(arena_size: Vector2i) -> Node2D:
	var host := Node2D.new()
	var rect := Spec.player_rect(arena_size)
	host.add_child(_rect_node(rect, PLAYER_BACKPLATE))
	var texture: Texture2D = load(Spec.PLAYER_VISUAL_PATH)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = rect.get_center()
		var scale := minf(rect.size.x / float(texture.get_width()), rect.size.y / float(texture.get_height()))
		sprite.scale = Vector2.ONE * scale * 0.90
		sprite.z_index = 8
		host.add_child(sprite)
	return host


func _hazard_nodes(arena_size: Vector2i) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	var texture: Texture2D = load(Spec.HAZARD_TEXTURE_PATH)
	for rect in Spec.hazard_rects(arena_size):
		var holder := Node2D.new()
		if texture != null:
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.position = rect.get_center()
			sprite.scale = Vector2.ONE * minf(rect.size.x / float(texture.get_width()), rect.size.y / float(texture.get_height()))
			sprite.modulate = HAZARD_COLOR
			sprite.z_index = 7
			holder.add_child(sprite)
		nodes.append(holder)
	return nodes


func _visual_victims(arena_size: Vector2i, count: int) -> Array:
	var victims := Spec.make_victim_probes(arena_size, count)
	var texture: Texture2D = load(Spec.ENEMY_VISUAL_PATH)
	for victim in victims:
		if texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * maxf(0.045, float(arena_size.y) / 2200.0)
		sprite.modulate = ENEMY_COLOR
		sprite.z_index = 2
		victim.add_child(sprite)
	return victims


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
func _sheet_state_caption(size: Vector2i, weapon_index: int, mode_index: int, pack: Dictionary, mode: Dictionary) -> Node2D:
	var arena := Spec.arena_rect(size, weapon_index, mode_index)
	var local_band := Spec.state_band_rect(arena.size)
	var band := Rect2(Vector2(arena.position) + local_band.position, local_band.size)
	var host := Node2D.new()
	host.z_index = 320
	host.add_child(_rect_node(band, STATE_BAND_COLOR))
	var text := "ACTIVE %.2fs · SHAKE %s · TARGETS %d · VEIL %s" % [
		float((pack["beats"] as Dictionary)["active"]),
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
		push_error("FAN-3937 Chemist certification capture rendered an empty viewport: %s" % label)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


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
