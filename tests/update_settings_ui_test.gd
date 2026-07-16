extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const QA_CAPTURE_TEARDOWN := preload("res://tools/qa_capture_teardown.gd")
const UI_BUTTON_FAMILY := preload("res://scripts/ui/ui_button_family.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

const EXPECTED_PRIMARY_FAMILY := "text/continue_run_long_420x72"
const EXPECTED_CLOSE_FAMILY := "text/continue_240x72"
const EXPECTED_PRIMARY_FOCUS := "res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_run_long_420x72_focus.png"
const EXPECTED_CLOSE_FOCUS := "res://assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_continue_240x72_focus.png"
const MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE := 1.0
const EXPECTED_MACOS_UNSIGNED_AVAILABLE_GEOMETRY := {
	Vector2i(1280, 720): {
		"panel": Rect2(80, 50, 1120, 620),
		"primary": Rect2(301, 580, 420, 72),
		"close": Rect2(739, 580, 240, 72),
	},
	Vector2i(1920, 1080): {
		"panel": Rect2(400, 230, 1120, 620),
		"primary": Rect2(621, 760, 420, 72),
		"close": Rect2(1059, 760, 240, 72),
	},
	Vector2i(2560, 1440): {
		"panel": Rect2(720, 410, 1120, 620),
		"primary": Rect2(941, 934, 420, 72),
		"close": Rect2(1379, 934, 240, 72),
	},
}

var _capture_teardown := QA_CAPTURE_TEARDOWN.new()


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	for viewport_size in VIEWPORT_SIZES:
		if not await _check_viewport(viewport_size):
			quit(1)
			return
	await _capture_teardown.release_windowed_audio(self)
	print("FAN-1112 Settings updater UI tests passed.")
	quit(0)


func _check_viewport(viewport_size: Vector2i) -> bool:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_settings_menu()
	for _frame_index in range(6):
		await process_frame

	var update_button := main.find_child("SettingsUpdateButton", true, false) as Button
	var footer := main.find_child("SettingsBottomActions", true, false) as HBoxContainer
	if update_button == null or footer == null:
		return _fail("Missing Settings update action at %s." % str(viewport_size))
	if update_button.text != "Обновить игру" or update_button.focus_mode != Control.FOCUS_ALL:
		return _fail("Settings update action lost its label/focus at %s." % str(viewport_size))
	if update_button.pressed.get_connections().is_empty() or main.ui._update_presenter.update_manager != main.update_manager:
		return _fail("Settings update action is not wired to UpdateManager at %s." % str(viewport_size))
	if not footer.get_global_rect().grow(1.0).encloses(update_button.get_global_rect()):
		return _fail("Settings update action escaped its footer at %s." % str(viewport_size))

	main.ui._update_presenter.show_dialog("available", {
		"current_version": "0.2.2",
		"latest_version": "0.2.3",
	}, "Доступна версия 0.2.3.")
	for _frame_index in range(6):
		await process_frame
	var dialog := main.find_child("GameUpdateDialog", true, false) as Control
	var panel := main.find_child("GameUpdatePanel", true, false) as PanelContainer
	var primary := main.find_child("GameUpdatePrimaryButton", true, false) as Button
	var close_button := main.find_child("GameUpdateCloseButton", true, false) as Button
	if dialog == null or panel == null or primary == null or close_button == null:
		return _fail("Update prompt is incomplete at %s." % str(viewport_size))
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	for control in [panel, primary, close_button]:
		if not viewport_rect.grow(1.0).encloses((control as Control).get_global_rect()):
			return _fail("Update prompt control escaped viewport at %s: %s" % [str(viewport_size), str((control as Control).get_global_rect())])
	if primary.text != "Скачать и установить" or primary.disabled:
		return _fail("Update prompt primary action regressed at %s." % str(viewport_size))
	if not _check_update_button_family(primary, EXPECTED_PRIMARY_FAMILY, EXPECTED_PRIMARY_FOCUS, viewport_size):
		return false
	if not _check_update_button_family(close_button, EXPECTED_CLOSE_FAMILY, EXPECTED_CLOSE_FOCUS, viewport_size):
		return false
	if primary.custom_minimum_size != Vector2(420.0, 72.0) \
		or close_button.custom_minimum_size != Vector2(240.0, 72.0):
		return _fail("Updater button geometry changed at %s: %s / %s" % [
			str(viewport_size), str(primary.custom_minimum_size), str(close_button.custom_minimum_size)])
	for neighbor in [
		primary.focus_neighbor_left,
		primary.focus_neighbor_right,
		primary.focus_neighbor_top,
		primary.focus_neighbor_bottom,
	]:
		if neighbor != close_button.get_path():
			return _fail("Updater primary focus cycle regressed at %s." % str(viewport_size))
	for neighbor in [
		close_button.focus_neighbor_left,
		close_button.focus_neighbor_right,
		close_button.focus_neighbor_top,
		close_button.focus_neighbor_bottom,
	]:
		if neighbor != primary.get_path():
			return _fail("Updater close focus cycle regressed at %s." % str(viewport_size))
	var body := main.find_child("GameUpdateBody", true, false) as Label
	if body == null:
		return _fail("Update prompt body is missing at %s." % str(viewport_size))
	if OS.get_name() == "macOS":
		# FAN-1121: перед загрузкой игрок должен видеть, что macOS-сборка не
		# подписана, и получить ручную Gatekeeper-инструкцию.
		if not body.text.contains("без подписи Apple Developer ID") \
			or not body.text.contains("Всё равно открыть"):
			return _fail("Update prompt must disclose the unsigned macOS build and Open Anyway step at %s: %s" % [str(viewport_size), body.text])
		if not panel.get_global_rect().grow(1.0).encloses(body.get_global_rect()):
			return _fail("Unsigned disclosure escaped the update panel at %s." % str(viewport_size))
		if not _check_macos_unsigned_available_geometry(viewport_size, panel, primary, close_button):
			return false
		if not await _check_macos_unsigned_live_resize(viewport, viewport_size, panel, primary, close_button):
			return false
	if DisplayServer.get_name() != "headless":
		await _save_capture_stable(viewport, viewport_size)

	main.ui._update_presenter.close_dialog()
	await process_frame
	if main.find_child("GameUpdateDialog", true, false) != null:
		return _fail("Update prompt did not close at %s." % str(viewport_size))
	var teardown_errors := await _capture_teardown.release_viewport(self, viewport)
	if not teardown_errors.is_empty():
		return _fail("Update UI teardown failed at %s: %s" % [str(viewport_size), "; ".join(teardown_errors)])
	return true


func _check_update_button_family(
	button: Button,
	expected_family: String,
	expected_focus_path: String,
	viewport_size: Vector2i
) -> bool:
	var family := str(button.get_meta(UI_BUTTON_FAMILY.META_FAMILY, ""))
	if family != expected_family or not bool(button.get_meta(UI_BUTTON_FAMILY.META_FAMILY_EXPLICIT, false)):
		return _fail("Updater button lost its explicit text family at %s: %s -> %s" % [
			str(viewport_size), str(button.name), family])
	var descriptor: Dictionary = UI_BUTTON_FAMILY.descriptor(family, "focus")
	var focus_path := str(descriptor.get("path", ""))
	if focus_path != expected_focus_path or focus_path.contains("minimal_metal_buttons"):
		return _fail("Updater button resolved a disallowed focus texture at %s: %s -> %s" % [
			str(viewport_size), str(button.name), focus_path])
	return true


func _check_macos_unsigned_available_geometry(
	viewport_size: Vector2i,
	panel: PanelContainer,
	primary: Button,
	close_button: Button
) -> bool:
	var expected: Dictionary = EXPECTED_MACOS_UNSIGNED_AVAILABLE_GEOMETRY.get(viewport_size, {})
	if expected.is_empty():
		return _fail("Missing macOS unsigned-disclosure geometry contract at %s." % str(viewport_size))
	for entry in [
		["panel", panel],
		["primary", primary],
		["close", close_button],
	]:
		var control := entry[1] as Control
		var expected_rect: Rect2 = expected[entry[0]]
		if not _rect_matches_with_tolerance(control.get_global_rect(), expected_rect, MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE):
			return _fail("macOS unsigned-disclosure %s rect regressed at %s: expected %s, got %s (tolerance %.1f px per edge)." % [
				str(entry[0]), str(viewport_size), str(expected_rect), str(control.get_global_rect()), MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE])
	var primary_rect := primary.get_global_rect()
	var close_rect := close_button.get_global_rect()
	if primary_rect.intersects(close_rect) or absf(close_rect.position.x - primary_rect.end.x - 18.0) > MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE:
		return _fail("macOS unsigned-disclosure action row lost its 18 px non-overlapping gap at %s: %s / %s" % [
			str(viewport_size), str(primary_rect), str(close_rect)])
	return true


func _check_macos_unsigned_live_resize(
	viewport: SubViewport,
	original_size: Vector2i,
	panel: PanelContainer,
	primary: Button,
	close_button: Button
) -> bool:
	var resized_size := Vector2i(1920, 1080) if original_size != Vector2i(1920, 1080) else Vector2i(1280, 720)
	viewport.size = resized_size
	for _frame_index in range(6):
		await process_frame
	if not _check_macos_unsigned_live_resize_safety(resized_size, panel, primary, close_button):
		return false
	viewport.size = original_size
	for _frame_index in range(6):
		await process_frame
	return _check_macos_unsigned_live_resize_safety(original_size, panel, primary, close_button)


func _check_macos_unsigned_live_resize_safety(
	viewport_size: Vector2i,
	panel: PanelContainer,
	primary: Button,
	close_button: Button
) -> bool:
	var expected: Dictionary = EXPECTED_MACOS_UNSIGNED_AVAILABLE_GEOMETRY.get(viewport_size, {})
	if expected.is_empty():
		return _fail("Missing macOS live-resize panel contract at %s." % str(viewport_size))
	var expected_panel: Rect2 = expected["panel"]
	var panel_rect := panel.get_global_rect()
	if not _rect_matches_with_tolerance(panel_rect, expected_panel, MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE):
		return _fail("macOS live-resize panel rect regressed at %s: expected %s, got %s." % [
			str(viewport_size), str(expected_panel), str(panel_rect)])
	var primary_rect := primary.get_global_rect()
	var close_rect := close_button.get_global_rect()
	if not panel_rect.grow(MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE).encloses(primary_rect) \
		or not panel_rect.grow(MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE).encloses(close_rect):
		return _fail("macOS live-resize action escaped its panel at %s: %s / %s." % [
			str(viewport_size), str(primary_rect), str(close_rect)])
	if primary_rect.intersects(close_rect) or absf(close_rect.position.x - primary_rect.end.x - 18.0) > MACOS_UNSIGNED_DISCLOSURE_RECT_TOLERANCE:
		return _fail("macOS live-resize action row lost its 18 px non-overlapping gap at %s: %s / %s." % [
			str(viewport_size), str(primary_rect), str(close_rect)])
	return true


func _rect_matches_with_tolerance(actual: Rect2, expected: Rect2, tolerance: float) -> bool:
	return absf(actual.position.x - expected.position.x) <= tolerance \
		and absf(actual.position.y - expected.position.y) <= tolerance \
		and absf(actual.size.x - expected.size.x) <= tolerance \
		and absf(actual.size.y - expected.size.y) <= tolerance


func _save_capture_stable(viewport: SubViewport, viewport_size: Vector2i) -> void:
	for _frame_index in range(10):
		await process_frame
	var qa_dir := ProjectSettings.globalize_path("res://build/qa/fan1112")
	DirAccess.make_dir_recursive_absolute(qa_dir)
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("%s/update_prompt_%dx%d.png" % [qa_dir, viewport_size.x, viewport_size.y])


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("Refusing to run updater UI test outside explicit scratch user dir: %s / %s" % [requested, actual])
		return false
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
