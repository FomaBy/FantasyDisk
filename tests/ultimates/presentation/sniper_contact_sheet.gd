extends SceneTree

## Reproducible class-local captures for the four supported presentation
## viewports. Each column is a real SubViewport render of the authored scene
## at release, including its backdrop, cast pose, silhouette, and phase nodes.
##
## Headless runs skip rendering instead of writing an empty sheet: the dummy
## rasterizer owns no SubViewport texture, so the readback is always empty. The
## release presence this column asserts is certified headlessly by
## sniper_runtime_presentation_test.gd for all three weapons.

const OUTPUT_ROOT := "res://docs/design/references/weapon_ultimates/sniper"
const CAPTURES := {
	"648p": Vector2i(1152, 648),
	"720p": Vector2i(1280, 720),
	"1080p": Vector2i(1920, 1080),
	"2k": Vector2i(2560, 1440),
}
const WEAPONS := [
	{
		"scene": "res://scenes/vfx/ultimates/sniper/sniper_deadeye_rifle_ultimate.tscn",
		"release": 0.75,
	},
	{
		"scene": "res://scenes/vfx/ultimates/sniper/sniper_spotter_scope_ultimate.tscn",
		"release": 0.85,
	},
	{
		"scene": "res://scenes/vfx/ultimates/sniper/sniper_shatter_rounds_ultimate.tscn",
		"release": 0.65,
	},
]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-3391 Sniper ultimate contact capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	for suffix in CAPTURES:
		var exported := await _export_capture(str(suffix), CAPTURES[suffix] as Vector2i)
		if not exported:
			quit(1)
			return
	print("Sniper ultimate contact captures exported at 648p, 720p, 1080p and 2k.")
	quit(0)


func _export_capture(suffix: String, size: Vector2i) -> bool:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var column_width := size.x / WEAPONS.size()
	for index in WEAPONS.size():
		var weapon := WEAPONS[index] as Dictionary
		var rendered := await _render_release(weapon, Vector2i(column_width, size.y))
		if rendered == null or rendered.is_empty():
			push_error("Sniper scene capture is empty: %s" % str(weapon["scene"]))
			return false
		image.blend_rect(rendered, Rect2i(Vector2i.ZERO, rendered.get_size()), Vector2i(index * column_width, 0))
	var output := "%s/sniper_ultimates_%s.png" % [OUTPUT_ROOT, suffix]
	var result := image.save_png(ProjectSettings.globalize_path(output))
	if result != OK:
		push_error("Sniper capture export failed: %s" % error_string(result))
		return false
	return true


func _render_release(weapon: Dictionary, size: Vector2i) -> Image:
	var packed := load(str(weapon["scene"])) as PackedScene
	if packed == null:
		push_error("Missing sniper capture scene: %s" % str(weapon["scene"]))
		return null
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera2D.new()
	camera.position = Vector2(size) * 0.5
	viewport.add_child(camera)
	var scene := packed.instantiate() as Node2D
	scene.position = camera.position
	viewport.add_child(scene)
	await process_frame
	camera.make_current()
	var begun := scene.call("begin", {}, 0) as Dictionary
	if str(begun.get("state", "")) != "active":
		push_error("Sniper capture scene did not start: %s" % str(weapon["scene"]))
		viewport.queue_free()
		return null
	scene.call("advance", float(weapon["release"]) + 0.01)
	var state := scene.call("presence_state_for_tests") as Dictionary
	if str(scene.call("visible_phase_name")) != "release" or not bool(state.get("backdrop_visible", false)) \
		or not bool(state.get("cast_pose_bound", false)) or not bool(state.get("silhouette_bound", false)):
		push_error("Sniper capture scene did not render its V2 release presence: %s" % str(weapon["scene"]))
		viewport.queue_free()
		return null
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	scene.call("finish", "capture")
	viewport.queue_free()
	await process_frame
	return image
