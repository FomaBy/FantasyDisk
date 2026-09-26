extends SceneTree

## Live four-viewport capture for the Ranger ultimate trio (FAN-3889).
##
## Each panel is its own SubViewport, because the Ranger backdrop veil is an
## arena-wide surface that fits itself to the viewport it draws in: rendering all
## twelve panels into one viewport would stack twelve full-sheet veils. One
## viewport per panel makes each panel a real arena at its own size, which is
## also what the readability claim needs to mean.
##
## Run windowed; a headless display cannot produce a render target.

const SPEC := preload("res://tests/ultimates/presentation/ranger_ultimate_timelines.gd")
const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Pack := preload("res://scenes/vfx/ultimates/ranger/ranger_ultimate_presentation_pack.gd")

const CROWD_COLUMNS := 4
const CROWD_RADIUS_RATIO := 0.030
const HAZARD_STRIPE_COUNT := 3


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3889 Ranger live capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	if not registry.is_valid():
		push_error("Ranger live capture: weapon registry is invalid")
		quit(1)
		return
	for raw_capture in SPEC.CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture["size"] as Vector2i
		var viewports := _build_sheet(registry, size)

		# One settle frame plus one draw for the whole sheet. Waiting per panel
		# instead makes the run hostage to window frame pacing: an occluded
		# window is throttled by the OS and fifty sequential waits stall.
		await process_frame
		await RenderingServer.frame_post_draw

		var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		sheet.fill(SPEC.BACKGROUND)
		var failed := false
		for entry in viewports:
			var image := _read_viewport(entry["viewport"] as SubViewport, str(entry["label"]))
			if image == null:
				failed = true
				break
			var target := entry["target"] as Vector2i
			if bool(entry["blend"]):
				sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), target)
			else:
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), target)
		for entry in viewports:
			(entry["viewport"] as SubViewport).queue_free()
		if failed:
			quit(1)
			return

		var output := str(capture["path"])
		var error := sheet.save_png(ProjectSettings.globalize_path(output))
		if error != OK:
			push_error("Ranger live capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Ranger live capture saved: %s (%dx%d)" % [output, size.x, size.y])
	SPEC.reset_mode(self)
	quit(0)


## Every viewport one sheet needs: twelve arenas plus the chrome overlay, all
## live before the single draw that resolves them.
func _build_sheet(registry, size: Vector2i) -> Array[Dictionary]:
	var viewports: Array[Dictionary] = []
	for column in SPEC.MODES.size():
		for row in SPEC.PACKS.size():
			var pack := SPEC.PACKS[row] as Dictionary
			var mode := SPEC.MODES[column] as Dictionary
			viewports.append({
				"viewport": _arena_viewport(registry, size, column, row),
				"target": SPEC.arena_rect(size, column, row).position,
				"label": "%s/%s" % [str(pack["weapon_id"]), str(mode["id"])],
				"blend": false,
			})
	viewports.append({
		"viewport": _chrome_viewport(size),
		"target": Vector2i.ZERO,
		"label": "chrome",
		"blend": true,
	})
	return viewports


## One panel: floor, hazards, crowd, the player, the live scene, then the HUD
## strip on top the way the game's HUD layer sits above world VFX.
func _arena_viewport(registry, size: Vector2i, column: int, row: int) -> SubViewport:
	var pack := SPEC.PACKS[row] as Dictionary
	var mode := SPEC.MODES[column] as Dictionary
	var arena_size := SPEC.arena_rect(size, column, row).size
	var viewport := _viewport(arena_size, false)
	var host := Node2D.new()
	viewport.add_child(host)
	host.add_child(_rect_node(Rect2(Vector2.ZERO, Vector2(arena_size)), SPEC.FLOOR_COLOR))
	for hazard in SPEC.hazard_rects(arena_size):
		host.add_child(_hazard_node(hazard))
	for node in _crowd_nodes(arena_size, int(mode["crowd"])):
		host.add_child(node)
	host.add_child(_player_node(arena_size))

	SPEC.apply_mode(self, mode)
	var scene := SPEC.instantiate_scene(pack)
	host.add_child(scene)
	SPEC.seek_scene(scene, registry, float(pack["beat"]))
	SPEC.apply_veil(scene, mode)
	SPEC.layout_scene(scene, arena_size)

	host.add_child(_hud_node(arena_size))
	host.add_child(_state_node(arena_size, pack, mode))
	return viewport


## Sheet chrome over the composited arenas: the title and the twelve panel
## labels, drawn transparent so the arena renders stay untouched underneath.
func _chrome_viewport(size: Vector2i) -> SubViewport:
	var viewport := _viewport(size, true)
	var host := Node2D.new()
	viewport.add_child(host)
	host.add_child(_label_node(
		SPEC.SHEET_TITLE,
		SPEC.sheet_title_rect(size).position,
		SPEC.sheet_title_font_size(size),
		Color(0.90, 0.95, 1.0)
	))
	for column in SPEC.MODES.size():
		for row in SPEC.PACKS.size():
			var pack := SPEC.PACKS[row] as Dictionary
			var mode := SPEC.MODES[column] as Dictionary
			host.add_child(_outline_node(SPEC.panel_rect(size, column, row), SPEC.PANEL_TINT))
			host.add_child(_label_node(
				SPEC.panel_label_text(pack, mode),
				SPEC.panel_label_rect(size, column, row).position,
				SPEC.panel_label_font_size(size, column, row),
				pack["color"] as Color
			))
	return viewport


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
		push_error("Ranger live capture: empty render for %s" % label)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _rect_node(rect: Rect2, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	return polygon


## A hazard reads as a striped warning block, the same language the arena uses
## for a telegraphed danger the player must still see through an ultimate.
func _hazard_node(rect: Rect2) -> Node2D:
	var host := Node2D.new()
	host.add_child(_rect_node(rect, Color(SPEC.HAZARD_COLOR, 0.28)))
	var stripe := rect.size.y / float(HAZARD_STRIPE_COUNT * 2)
	for index in HAZARD_STRIPE_COUNT:
		var top := rect.position.y + float(index * 2) * stripe
		host.add_child(_rect_node(Rect2(rect.position.x, top, rect.size.x, stripe), SPEC.HAZARD_COLOR))
	return host


func _crowd_nodes(arena_size: Vector2i, count: int) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	if count <= 0:
		return nodes
	var zone := SPEC.effect_zone(arena_size)
	var rows := int(ceil(float(count) / float(CROWD_COLUMNS)))
	var radius := maxf(2.0, float(arena_size.y) * CROWD_RADIUS_RATIO)
	for index in count:
		var column := index % CROWD_COLUMNS
		var row := index / CROWD_COLUMNS
		var center := zone.position + Vector2(
			zone.size.x * (float(column) + 0.5) / float(CROWD_COLUMNS),
			zone.size.y * (float(row) + 0.5) / float(rows)
		)
		nodes.append(_disc_node(center, radius, SPEC.CROWD_COLOR))
	return nodes


func _disc_node(center: Vector2, radius: float, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	for step in 12:
		var angle := TAU * float(step) / 12.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	return polygon


## The player character stands in the arena as a world entity. The scene's own
## cast pose is a fading overlay, so it cannot carry the "player stays readable"
## claim on its own.
func _player_node(arena_size: Vector2i) -> Node2D:
	var host := Node2D.new()
	host.add_child(_rect_node(SPEC.player_rect(arena_size), Color(0.08, 0.11, 0.14, 0.85)))
	var texture: Texture2D = load(SPEC.PLAYER_SPRITE)
	if texture != null:
		var drawn := SPEC.player_sprite_rect(arena_size)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		sprite.position = drawn.get_center()
		sprite.scale = Vector2.ONE * (drawn.size.x / float(texture.get_width()))
		host.add_child(sprite)
	return host


## The HUD layer sits above world VFX in the game, so it does here too.
func _hud_node(arena_size: Vector2i) -> Node2D:
	var rect := SPEC.hud_band_rect(arena_size)
	var host := Node2D.new()
	host.z_index = 100
	host.add_child(_rect_node(rect, SPEC.HUD_BAND_COLOR))
	host.add_child(_label_node(
		SPEC.HUD_TEXT,
		SPEC.hud_text_rect(arena_size).position,
		SPEC.band_font_size(SPEC.HUD_TEXT, rect),
		SPEC.HUD_TEXT_COLOR
	))
	return host


func _state_node(arena_size: Vector2i, pack: Dictionary, mode: Dictionary) -> Node2D:
	var rect := SPEC.state_band_rect(arena_size)
	var text := SPEC.state_text(pack, mode)
	var host := Node2D.new()
	host.z_index = 100
	host.add_child(_rect_node(rect, SPEC.STATE_BAND_COLOR))
	host.add_child(_label_node(
		text,
		SPEC.state_text_rect(arena_size, pack, mode).position,
		SPEC.band_font_size(text, rect),
		SPEC.STATE_TEXT_COLOR
	))
	return host


func _outline_node(rect: Rect2, color: Color) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		rect.position,
	])
	line.width = 1.0
	line.default_color = color
	return line


func _label_node(text: String, position: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
