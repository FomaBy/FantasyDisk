extends SceneTree

## Live-capture evidence renderer for the engineer sentry-wrench ultimate.
##
## Every panel instantiates the shipped `EngineerSentryWrenchUltimate.tscn` and
## drives it with the same `begin()`/`step()` the frame loop drives, so the sheet
## is the running scene rather than a redraw of it. The crowd markers and the two
## HUD bands are the readability reference: the formation has to stay legible
## against a crowd and must not reach into either band.
##
## The fifth panel is the cleanup panel. `cancel` is the teardown marker, so the
## scene is driven into the active phase and then cancelled, and the panel
## reports the number of nodes the cancelled scene still owns — which is what
## "leaves no orphan nodes" has to look like.
##
## Run windowed (a SubViewport cannot render under `--headless`):
##   python3 tools/godot_gate.py --path . \
##     --script res://tests/ultimates/presentation/engineer_ultimate_contact_capture.gd

const PD := preload("res://scripts/progression_data.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const Pack := preload("res://scenes/vfx/ultimates/engineer/engineer_ultimate_presentation_pack.gd")
const SCENE := preload("res://scenes/vfx/ultimates/engineer/EngineerSentryWrenchUltimate.tscn")
const Spec := preload("res://tests/ultimates/presentation/engineer_ultimate_capture_spec.gd")

const BACKGROUND := Color(0.043, 0.055, 0.062, 1.0)
const PANEL := Color(0.075, 0.098, 0.105, 0.96)
const HUD_BAND := Color(0.16, 0.20, 0.22, 0.85)
const CROWD := Color(0.42, 0.20, 0.24, 1.0)
const TITLE_COLOR := Color(0.62, 0.94, 0.86)
const LABEL_COLOR := Color(0.74, 1.0, 0.92)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("Engineer ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	for raw_capture in Spec.CAPTURES:
		var capture := raw_capture as Dictionary
		var size := capture["size"] as Vector2i
		var viewport := SubViewport.new()
		viewport.size = size
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		await process_frame
		viewport.add_child(_make_sheet(size))
		await process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(str(capture["path"]))
		)
		viewport.queue_free()
		await process_frame
		if error != OK:
			push_error("Engineer ultimate contact capture failed: %s" % error_string(error))
			quit(1)
			return
		print("Engineer ultimate contact capture saved: %s" % str(capture["path"]))
	quit(0)


func _make_sheet(size: Vector2i) -> Node2D:
	var host := Node2D.new()
	host.add_child(_filled(Rect2(Vector2.ZERO, Vector2(size)), BACKGROUND, -30))
	for band in Spec.hud_bands(size):
		host.add_child(_filled(band as Rect2, HUD_BAND, -25))
	host.add_child(_text(Spec.SHEET_TITLE, Spec.sheet_title_rect(size).position, Spec.sheet_title_font_size(size), TITLE_COLOR))

	var registry = Registry.new(PD.WEAPONS_BY_CLASS)
	for index in Spec.PANELS.size():
		var panel := Spec.PANELS[index] as Dictionary
		var rect := Spec.panel_rect(size, index)
		host.add_child(_filled(rect, PANEL, -20))
		for marker in Spec.crowd_markers(size, index):
			host.add_child(_filled(marker as Rect2, CROWD, -15))

		var scene := SCENE.instantiate() as Node2D
		host.add_child(scene)
		scene.begin(registry, {}, 0)
		scene.step(float(panel["time"]))
		var caption := str(panel["title"])
		if bool(panel.get("cancel", false)):
			scene.finish("cancel")
			caption = "%s — %d NODES" % [caption, _drawn_nodes(scene)]
		Spec.layout_capture_scene(scene, size, index)
		host.add_child(_text(caption, Spec.panel_label_rect(size, index, caption).position, Spec.panel_label_font_size(size), LABEL_COLOR))
	return host


## Sprites the scene still owns and would still draw.
func _drawn_nodes(scene: Node2D) -> int:
	var drawn := 0
	for child in scene.get_children():
		var item := child as CanvasItem
		if item != null and item.visible and not item.is_queued_for_deletion():
			drawn += 1
	return drawn


func _filled(rect: Rect2, color: Color, z_index: int) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	polygon.z_index = z_index
	return polygon


func _text(value: String, position: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
