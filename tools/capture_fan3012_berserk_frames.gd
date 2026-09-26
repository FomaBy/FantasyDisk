extends SceneTree

## FAN-3012 runtime frame-strip proof: one row per berserk ultimate, one cell
## per sampled beat, each cell its own scene instance seeked to that time —
## the same windowed composition pattern as the class contact sheets. The
## saved strip shows the whirlwind actually spinning, the cast flash reading,
## and the rift quake expanding: motion across beats, not one seeked frame.

const ROWS := [
	{
		"label": "SWORD — SCARLET WHIRLWIND (cancel 3.80s)",
		"scene": preload("res://scenes/vfx/ultimates/berserk/BerserkSwordScarletWhirlwind.tscn"),
	},
	{
		"label": "AXE — EXECUTION LOOP (cancel 3.40s)",
		"scene": preload("res://scenes/vfx/ultimates/berserk/BerserkAxeExecutionLoop.tscn"),
	},
	{
		"label": "HAMMER — FOURFOLD RIFT (cancel 2.95s)",
		"scene": preload("res://scenes/vfx/ultimates/berserk/BerserkHammerFourfoldRift.tscn"),
	},
]
const TIMES := [0.4, 0.9, 1.4, 1.9, 2.4, 2.9, 3.3]
const CELL := Vector2(300.0, 190.0)
const MARGIN := 10.0
const TIME_FONT := 13
const ROW_FONT := 15
const OUTPUT := "res://docs/design/previews/fan3012_berserk_frame_strip.png"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3012 frame strip skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	var width := int(TIMES.size() * CELL.x + (TIMES.size() + 1) * MARGIN)
	var height := int(ROWS.size() * (CELL.y + ROW_FONT + MARGIN) + MARGIN * 2)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var host := _make_sheet(Vector2(width, height))
	viewport.add_child(host)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	viewport.queue_free()
	await process_frame
	if error != OK:
		push_error("FAN-3012 frame strip failed: %s" % error_string(error))
		quit(1)
		return
	print("FAN-3012 frame strip saved: %s" % OUTPUT)
	quit(0)


func _make_sheet(size: Vector2) -> Node2D:
	var host := Node2D.new()
	var background := Sprite2D.new()
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.028, 0.02, 0.04, 1.0))
	background.texture = ImageTexture.create_from_image(image)
	background.centered = false
	background.scale = size / 4.0
	background.z_index = -20
	host.add_child(background)
	for row in ROWS.size():
		var row_top := MARGIN + row * (CELL.y + ROW_FONT + MARGIN)
		var row_label := Label.new()
		row_label.text = str(ROWS[row]["label"])
		row_label.position = Vector2(MARGIN, row_top + CELL.y + 2.0)
		row_label.add_theme_font_size_override("font_size", ROW_FONT)
		row_label.add_theme_color_override("font_color", Color(0.97, 0.6, 0.55))
		host.add_child(row_label)
		for column in TIMES.size():
			var cell_position := Vector2(MARGIN + column * (CELL.x + MARGIN), row_top)
			var time_label := Label.new()
			time_label.text = "t=%.2fs" % float(TIMES[column])
			time_label.position = cell_position + Vector2(0, -TIME_FONT)
			time_label.add_theme_font_size_override("font_size", TIME_FONT)
			time_label.add_theme_color_override("font_color", Color(0.97, 0.86, 0.68))
			host.add_child(time_label)
			var scene := (ROWS[row]["scene"] as PackedScene).instantiate() as Node2D
			host.add_child(scene)
			var timeline := scene.get_node("Timeline") as AnimationPlayer
			timeline.stop()
			timeline.play(&"ultimate")
			timeline.seek(float(TIMES[column]), true)
			_layout_cell(scene, cell_position)
	return host


## Fit the seeked scene's visible flipbooks into one cell, skipping the
## fullscreen backdrop veil — the same bound the class sheet layout uses.
func _layout_cell(scene: Node2D, cell_position: Vector2) -> void:
	scene.position = Vector2.ZERO
	scene.scale = Vector2.ONE
	var bounds := Rect2()
	var found := false
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
			var sprite := child as AnimatedSprite2D
			if sprite == null or bool(sprite.get_meta("fullscreen_layer", false)):
				continue
			if sprite.modulate.a <= 0.01 or sprite.sprite_frames == null:
				continue
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			if texture == null:
				continue
			var rect := Rect2(
				sprite.position - texture.get_size() * sprite.scale * 0.5,
				texture.get_size() * sprite.scale
			)
			bounds = rect if not found else bounds.merge(rect)
			found = true
	if not found:
		return
	var scale := minf(CELL.x / bounds.size.x, CELL.y / bounds.size.y) * 0.9
	scene.scale = Vector2.ONE * scale
	scene.position = cell_position + CELL * 0.5 - bounds.get_center() * scale
