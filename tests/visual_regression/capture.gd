extends SceneTree

## Deterministic capture pass for the FAN-3308 visual regression gate.
##
## `tools/visual_gate.py` owns the comparison; this script only renders the
## manifest cases and writes one PNG per case into the requested output dir.
##
## The dummy rasterizer owns no SubViewport texture, so a headless run can only
## produce empty readbacks (same reason every sibling capture suite in
## `tests/ultimates/presentation/` skips there). This gate fails closed instead
## of writing empty baselines: it refuses to run headless.

const MANIFEST_PATH := "res://tests/visual_regression/manifest.json"
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()
var _errors := PackedStringArray()


func _initialize() -> void:
	var output_dir := _user_arg("--out")
	if output_dir.is_empty():
		push_error("visual capture: --out <dir> is required.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("visual capture: headless renders empty images; run windowed.")
		quit(3)
		return

	var manifest := _load_manifest()
	if manifest.is_empty():
		quit(2)
		return

	var capture: Dictionary = manifest.get("capture", {})
	# Pinned run inputs (FAN-3308 AC3): identical seed, locale and frame budget
	# on every run, so the same checkout always renders the same pixels.
	seed(int(capture.get("seed", 0)))
	TranslationServer.set_locale(str(capture.get("locale", "en")))
	var settle_frames := int(capture.get("settle_frames", 12))
	# Screen shake tweens the current camera to randomised offsets over real
	# frames, so the readback would land on a different sub-pixel offset every
	# run. Production already exposes this opt-out, so the gate pins it instead
	# of touching presentation code.
	root.set_meta("screen_shake", false)
	Engine.time_scale = 1.0

	var selected := _user_arg("--case")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for case_value in manifest.get("cases", []):
		var case: Dictionary = case_value
		var case_id := str(case.get("id", ""))
		if not selected.is_empty() and selected != case_id:
			continue
		var image := await _render_case(case, settle_frames)
		if image == null:
			continue
		var target := "%s/%s.png" % [output_dir, case_id]
		if image.save_png(target) != OK:
			_errors.append("%s: PNG export failed." % case_id)

	await _capture_teardown.release_windowed_audio(self)
	if _errors.is_empty():
		print("Visual capture wrote %d case(s) to %s" % [manifest.get("cases", []).size(), output_dir])
		quit(0)
		return
	for error in _errors:
		push_error("visual capture: %s" % error)
	quit(1)


func _user_arg(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == flag and index + 1 < args.size():
			return args[index + 1]
	return ""


func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("visual capture: cannot read %s" % MANIFEST_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("visual capture: manifest is not a JSON object.")
		return {}
	return parsed


func _render_case(case: Dictionary, settle_frames: int) -> Image:
	var case_id := str(case.get("id", ""))
	var size := _viewport_size(case)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	var kind := str(case.get("kind", ""))
	var populated := false
	match kind:
		"ultimate_v2":
			populated = await _populate_ultimate(viewport, case, size)
		"flipbook":
			populated = _populate_flipbook(viewport, case, size)
		"main_menu":
			populated = await _populate_main_menu(viewport, case)
		"hud_widget":
			populated = _populate_hud_widget(viewport, case, size)
		_:
			_errors.append("%s: unknown case kind '%s'." % [case_id, kind])

	var image: Image = null
	if populated:
		for _frame_index in range(settle_frames):
			await process_frame
		image = viewport.get_texture().get_image()
		if image == null or image.is_empty():
			_errors.append("%s: renderer returned an empty image." % case_id)
			image = null

	for error in await _capture_teardown.release_viewport(self, viewport):
		_errors.append("%s: %s" % [case_id, error])
	return image


func _viewport_size(case: Dictionary) -> Vector2i:
	var raw: Array = case.get("viewport", [])
	if raw.size() != 2:
		return Vector2i(512, 512)
	return Vector2i(int(raw[0]), int(raw[1]))


func _populate_ultimate(viewport: SubViewport, case: Dictionary, size: Vector2i) -> bool:
	var case_id := str(case.get("id", ""))
	var scene_path := str(case.get("scene", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_errors.append("%s: missing scene %s." % [case_id, scene_path])
		return false
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
		_errors.append("%s: ultimate scene did not start." % case_id)
		return false
	# One explicit step to the pinned beat: the timeline is advanced by an exact
	# delta rather than by wall-clock frames, so the captured phase is fixed.
	scene.call("advance", float(case.get("advance_seconds", 0.0)))
	if str(scene.call("visible_phase_name")) != "release":
		_errors.append("%s: ultimate scene is not in its release phase." % case_id)
		return false
	return true


func _populate_flipbook(viewport: SubViewport, case: Dictionary, size: Vector2i) -> bool:
	var case_id := str(case.get("id", ""))
	var pack_path := str(case.get("pack", ""))
	var pack := load(pack_path) as SpriteFrames
	if pack == null:
		_errors.append("%s: missing SpriteFrames pack %s." % [case_id, pack_path])
		return false
	# The animation is pinned by the manifest: a pack may carry several tracks
	# and picking one by index would silently re-point the case when it grows.
	var animation := str(case.get("animation", ""))
	if not pack.has_animation(animation):
		_errors.append("%s: pack has no animation '%s'." % [case_id, animation])
		return false
	var frame := int(case.get("frame", 0))
	if frame < 0 or frame >= pack.get_frame_count(animation):
		_errors.append("%s: frame %d is outside pack animation '%s'." % [case_id, frame, animation])
		return false
	# Never play(): a stopped AnimatedSprite2D holds the pinned frame, so the
	# capture cannot drift with elapsed wall-clock time.
	var flipbook := AnimatedSprite2D.new()
	flipbook.sprite_frames = pack
	flipbook.animation = animation
	flipbook.frame = frame
	flipbook.position = Vector2(size) * 0.5
	viewport.add_child(flipbook)
	return true


func _populate_main_menu(viewport: SubViewport, case: Dictionary) -> bool:
	var case_id := str(case.get("id", ""))
	var packed := load(str(case.get("scene", ""))) as PackedScene
	if packed == null:
		_errors.append("%s: missing scene %s." % [case_id, str(case.get("scene", ""))])
		return false
	var main := packed.instantiate()
	viewport.add_child(main)
	await process_frame
	if main.ui == null:
		_errors.append("%s: Main scene exposes no ui node." % case_id)
		return false
	main.ui._show_main_menu()
	return true


func _populate_hud_widget(viewport: SubViewport, case: Dictionary, size: Vector2i) -> bool:
	var case_id := str(case.get("id", ""))
	var packed := load(str(case.get("scene", ""))) as PackedScene
	if packed == null:
		_errors.append("%s: missing scene %s." % [case_id, str(case.get("scene", ""))])
		return false
	var widget := packed.instantiate() as Control
	if widget == null:
		_errors.append("%s: HUD scene root is not a Control." % case_id)
		return false
	widget.size = Vector2(size)
	viewport.add_child(widget)
	return true
