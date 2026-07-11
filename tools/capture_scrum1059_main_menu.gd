extends SceneTree

# Windowed Metal evidence for SCRUM-1059. Captures only Main Menu at the five
# required responsive targets and records exact authored geometry.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const TARGETS := [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]

var _errors := PackedStringArray()
var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/scrum1059")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var report := PackedStringArray([
		"# SCRUM-1059 Main Menu Metal Matrix", "",
		"- renderer: `%s`" % DisplayServer.get_name(),
		"- expected: one six-action left column, no scrollbar, gratitude icon-only in upper-right authored inner zone", "",
	])
	for viewport_size in TARGETS:
		await _capture(viewport_size, qa_dir, report)
	await _capture_teardown.release_windowed_audio(self)
	var output := FileAccess.open("%s/runtime_visual_matrix.md" % qa_dir, FileAccess.WRITE)
	if output != null:
		output.store_string("\n".join(report))
		output.close()
	if _errors.is_empty():
		print("SCRUM-1059 Main Menu Metal capture completed at five viewports.")
		quit(0)
		return
	for error in _errors:
		push_error(error)
	quit(1)


func _capture(viewport_size: Vector2i, qa_dir: String, report: PackedStringArray) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_main_menu()
	for _frame in range(12):
		await process_frame
	var screen := main.find_child("MainMenuScreen", true, false) as Control
	var logo := main.find_child("MainMenuTitleLabel", true, false) as Control
	var actions := main.find_child("MainMenuActions", true, false) as GridContainer
	var credits := main.find_child("MainMenuCreditsButton", true, false) as Button
	var version := main.find_child("MainMenuVersionLabel", true, false) as Control
	report.append("## %dx%d" % [viewport_size.x, viewport_size.y])
	report.append("- authored inner: `%s`" % str(screen.get_meta("gold_shell_inner_rect", Rect2()) if screen != null else Rect2()))
	report.append("- logo: `%s`" % str(logo.get_global_rect() if logo != null else Rect2()))
	report.append("- actions: `%s`, columns=%d, children=%d" % [str(actions.get_global_rect() if actions != null else Rect2()), actions.columns if actions != null else -1, actions.get_child_count() if actions != null else -1])
	report.append("- gratitude: `%s`" % str(credits.get_global_rect() if credits != null else Rect2()))
	report.append("- version: `%s`" % str(version.get_global_rect() if version != null else Rect2()))
	report.append("")
	if DisplayServer.get_name() == "headless":
		_errors.append("%s: capture requires the windowed Metal renderer." % str(viewport_size))
	else:
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			_errors.append("%s: renderer returned an empty image." % str(viewport_size))
		else:
			image.save_png("%s/main_menu_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	for error in teardown_errors:
		_errors.append("%s: %s" % [str(viewport_size), error])
