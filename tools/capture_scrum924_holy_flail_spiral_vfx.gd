extends SceneTree

const VFX_SCENE := preload("res://scenes/vfx/HolyFlailSpiralVfx.tscn")
const OUTPUT := "res://docs/design/previews/scrum924_holy_flail_spiral_vfx_runtime.png"
const FULL_RADIUS := 235.0
const START_RATIO := 0.22
const STEP_COUNT := 7


func _initialize() -> void:
	var host := Node2D.new()
	host.name = "Scrum924RuntimeCapture"
	root.add_child(host)
	current_scene = host
	await process_frame
	var viewport_size := Vector2(root.size)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)])
	backdrop.color = Color(0.055, 0.045, 0.075, 1.0)
	backdrop.z_index = -20
	host.add_child(backdrop)

	var steps := [0, 3, 6]
	var centers := [
		Vector2(viewport_size.x * 0.18, viewport_size.y * 0.50),
		Vector2(viewport_size.x * 0.50, viewport_size.y * 0.50),
		Vector2(viewport_size.x * 0.82, viewport_size.y * 0.50),
	]
	for capture_index in range(steps.size()):
		var step_index: int = steps[capture_index]
		var progress := float(step_index + 1) / float(STEP_COUNT)
		var radius := lerpf(FULL_RADIUS * START_RATIO, FULL_RADIUS, progress)
		var effect := VFX_SCENE.instantiate() as HolyFlailSpiralVfx
		host.add_child(effect)
		effect.auto_free_on_finish = false
		effect.scale = Vector2.ONE * minf(viewport_size.y / 960.0, 1.15)
		effect.apply_step(centers[capture_index], 0.2 + TAU * progress, radius, FULL_RADIUS, step_index, Color(1.0, 0.84, 0.32, 0.34))

		var label := Label.new()
		label.text = ["STEP 1  INNER", "STEP 4  MID", "STEP 7  OUTER CLOSURE"][capture_index]
		label.position = centers[capture_index] + Vector2(-110, viewport_size.y * 0.27)
		label.add_theme_color_override("font_color", Color(0.93, 0.82, 0.58))
		label.add_theme_font_size_override("font_size", 18)
		host.add_child(label)

	var title := Label.new()
	title.text = "SCRUM-924  HOLY FLAIL — LIVE CENTER-OUT SPIRAL"
	title.position = Vector2(viewport_size.x * 0.5 - 270, viewport_size.y * 0.06)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.64))
	title.add_theme_font_size_override("font_size", 22)
	host.add_child(title)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(OUTPUT)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("SCRUM-924 capture failed: %s" % error_string(error))
		quit(1)
		return
	print("SCRUM-924 runtime capture saved: %s" % OUTPUT)
	quit(0)
