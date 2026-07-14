extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

const TARGETS := [
	{"size": Vector2i(1280, 720), "panel": Vector2(1200, 672), "columns": 1, "scale": 1.0, "scroll": true},
	{"size": Vector2i(1400, 720), "panel": Vector2(1200, 672), "columns": 1, "scale": 1.0, "scroll": true},
	{"size": Vector2i(1401, 720), "panel": Vector2(1200, 672), "columns": 1, "scale": 1.0, "scroll": true},
	{"size": Vector2i(1599, 899), "panel": Vector2(1299.4, 830.1), "columns": 1, "scale": 1.0, "scroll": true},
	{"size": Vector2i(1600, 900), "panel": Vector2(1300, 831), "columns": 2, "scale": 1.0, "scroll": true},
	{"size": Vector2i(1920, 1080), "panel": Vector2(1400, 990), "columns": 2, "scale": 1.0, "scroll": false},
	{"size": Vector2i(2560, 1440), "panel": Vector2(1866.6666, 1320), "columns": 2, "scale": 4.0 / 3.0, "scroll": false},
]

class ReporterSpy:
	extends Node

	var request_active := false
	var submitted_text := ""
	var submitted_screenshot: Image = null
	var submitted_metadata := {}
	var submitted_include_screenshot := true
	var submitted_completion := Callable()

	func submit_report(
			text: String,
			screenshot: Image,
			metadata: Dictionary,
			completion := Callable(),
			include_screenshot := true) -> int:
		submitted_text = text
		submitted_screenshot = screenshot
		submitted_metadata = metadata.duplicate(true)
		submitted_include_screenshot = bool(include_screenshot)
		submitted_completion = completion
		request_active = true
		return 77

	func is_request_active(request_id: int) -> bool:
		return request_active and request_id == 77

	func cancel_active_report(request_id := 0) -> bool:
		if not request_active or (request_id > 0 and request_id != 77):
			return false
		request_active = false
		return true

	func finish() -> void:
		request_active = false
		if submitted_completion.is_valid():
			submitted_completion.call(false, "spy completion", "")


var _errors: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _initialize() -> void:
	for target in TARGETS:
		await _check_target(target as Dictionary)
	await _check_live_resize()
	if _errors.is_empty():
		print("Feedback privacy UI test passed (responsive layout, disclosure, focus, opt-out).")
		quit(0)
	else:
		for error in _errors:
			push_error("Feedback privacy UI: %s" % error)
		quit(1)


func _check_target(target: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = target["size"] as Vector2i
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	var reporter_spy := ReporterSpy.new()
	reporter_spy.name = "FeedbackReporter"
	main.add_child(reporter_spy)
	var screenshot := Image.create(160, 90, false, Image.FORMAT_RGBA8)
	screenshot.fill(Color(0.15, 0.10, 0.08, 1.0))
	main.ui._show_feedback_overlay(screenshot)
	await process_frame
	await process_frame

	var context := str(target["size"])
	var panel := main.find_child("FeedbackPanel", true, false) as Control
	var scroll := main.find_child("FeedbackScroll", true, false) as ScrollContainer
	var body := main.find_child("FeedbackScrollBody", true, false) as Control
	var grid := main.find_child("FeedbackReportGrid", true, false) as GridContainer
	var text_edit := main.find_child("FeedbackTextEdit", true, false) as TextEdit
	var toggle := main.find_child("FeedbackScreenshotToggle", true, false) as CheckBox
	var preview := main.find_child("FeedbackScreenshotPreview", true, false) as TextureRect
	var preview_frame := main.find_child("FeedbackScreenshotFrame", true, false) as Control
	var privacy := main.find_child("FeedbackPrivacyBody", true, false) as Label
	var privacy_frame := main.find_child("FeedbackPrivacyFrame", true, false) as Control
	var operator_label := main.find_child("FeedbackOperatorRetentionLabel", true, false) as Label
	var fallback := main.find_child("FeedbackLocalFallbackLabel", true, false) as Label
	var status := main.find_child("FeedbackStatusLabel", true, false) as Label
	var send := main.find_child("FeedbackSendButton", true, false) as Button
	var cancel := main.find_child("FeedbackCancelButton", true, false) as Button
	for entry in [panel, scroll, body, grid, text_edit, toggle, preview, preview_frame, privacy,
			operator_label, fallback, status, send, cancel]:
		_check(entry != null, "%s missing a required feedback privacy control." % context)
	if panel == null or grid == null or toggle == null or preview == null \
			or privacy == null or operator_label == null or fallback == null \
			or status == null or send == null or cancel == null or text_edit == null:
		main.ui._close_feedback_overlay()
		viewport.queue_free()
		await process_frame
		return

	_check(panel.size.distance_to(target["panel"] as Vector2) <= 2.0,
		"%s panel size %s differs from FAN-1059 target %s." % [
			context, str(panel.size), str(target["panel"])])
	_check(Rect2(Vector2.ZERO, Vector2(target["size"])).grow(1.0).encloses(panel.get_global_rect()),
		"%s feedback panel escapes the viewport: %s." % [context, str(panel.get_global_rect())])
	_check(grid.columns == int(target["columns"]),
		"%s report grid has %d columns, expected %d." % [
			context, grid.columns, int(target["columns"])])
	_check(toggle.button_pressed and bool(preview.get_meta("included_in_feedback", false)),
		"%s screenshot choice does not default to explicit include." % context)
	_check("версия игры" in privacy.text and "UUID" in privacy.text \
		and "IP" in privacy.text and "локальное время" in privacy.text,
		"%s disclosure omits allowlisted metadata, installation UUID or edge IP." % context)
	_check("Оператор" in operator_label.text and "Срок хранения" in operator_label.text \
		and "онлайн-отправка отключена" in operator_label.text,
		"%s missing-policy disclosure is not truthful/fail-closed." % context)
	_check("только на этом устройстве" in fallback.text \
		and "screenshot.png не создаётся" in fallback.text,
		"%s local retention/screenshot omission disclosure is incomplete." % context)
	_check("сохранит локальный отчёт" in status.text,
		"%s pinned status does not explain the disabled online route." % context)
	_check(text_edit.focus_neighbor_bottom == text_edit.get_path_to(toggle),
		"%s TextEdit does not lead to the screenshot choice." % context)
	_check(toggle.focus_neighbor_bottom == toggle.get_path_to(send),
		"%s screenshot choice does not lead to Send." % context)
	_check(send.focus_neighbor_right == send.get_path_to(cancel),
		"%s Send does not lead to Cancel." % context)
	var authored_scale := float(target.get("scale", 1.0))
	if int(target["columns"]) == 2:
		_check(absf(text_edit.custom_minimum_size.y - 330.0 * authored_scale) <= 2.0,
			"%s description height does not follow the authored desktop scale." % context)
		_check(preview_frame != null \
				and preview_frame.custom_minimum_size.distance_to(
					Vector2(500, 281) * authored_scale) <= 2.0,
			"%s screenshot frame does not follow the authored desktop scale." % context)
		_check(send.custom_minimum_size.distance_to(Vector2(260, 64) * authored_scale) <= 2.0 \
				and cancel.custom_minimum_size.distance_to(Vector2(220, 64) * authored_scale) <= 2.0,
			"%s actions do not follow the authored desktop scale." % context)

	toggle.button_pressed = false
	toggle.toggled.emit(false)
	_check(not bool(preview.get_meta("included_in_feedback", true)) \
		and preview.modulate.a < 0.5 \
		and "НЕ будет" in toggle.text,
		"%s screenshot opt-out did not dim and mark the preview." % context)
	send.pressed.emit()
	_check("добавьте описание" in status.text and text_edit.editable,
		"%s empty text-only submission did not fail locally before network work." % context)
	text_edit.text = "controller text-only report"
	send.pressed.emit()
	_check(reporter_spy.request_active \
			and reporter_spy.submitted_text == "controller text-only report" \
			and not reporter_spy.submitted_include_screenshot \
			and reporter_spy.submitted_screenshot == null,
		"%s valid opt-out did not cross UI→reporter as text-only/null image." % context)
	_check(send.disabled and toggle.disabled and not text_edit.editable,
		"%s in-flight report did not lock every mutable submission control." % context)
	reporter_spy.finish()
	_check(not send.disabled and not toggle.disabled and text_edit.editable,
		"%s completion did not restore submission controls." % context)

	if bool(target.get("scroll", false)) and scroll != null and body != null:
		_check(body.custom_minimum_size.y > scroll.size.y,
			"%s constrained privacy body should scroll before shrinking copy." % context)
		var right_stick_down := InputEventJoypadMotion.new()
		right_stick_down.axis = JOY_AXIS_RIGHT_Y
		right_stick_down.axis_value = 1.0
		toggle.gui_input.emit(right_stick_down)
		toggle.gui_input.emit(right_stick_down)
		_check(scroll.scroll_vertical > 0,
			"%s right stick did not scroll the constrained disclosure." % context)
		if privacy_frame != null:
			var privacy_visible_top := privacy_frame.position.y - float(scroll.scroll_vertical)
			var privacy_visible_bottom := privacy_visible_top + privacy_frame.size.y
			_check(privacy_visible_top >= -1.0 \
					and privacy_visible_bottom <= scroll.size.y + 1.0,
				("%s controller scroll did not reveal the complete privacy block " % context) \
				+ "(top=%.1f bottom=%.1f viewport=%.1f value=%d max=%.1f page=%.1f)." % [
					privacy_visible_top, privacy_visible_bottom, scroll.size.y,
					scroll.scroll_vertical, scroll.get_v_scroll_bar().max_value,
					scroll.get_v_scroll_bar().page])
	elif scroll != null:
		_check(not scroll.get_v_scroll_bar().visible,
			("%s desktop privacy disclosure should fit without scrolling " % context) \
			+ ("(body=%s privacy=%s viewport=%s max=%.1f page=%.1f)." % [
				str(body.size if body != null else Vector2.ZERO),
				str(privacy_frame.size if privacy_frame != null else Vector2.ZERO), str(scroll.size),
				scroll.get_v_scroll_bar().max_value, scroll.get_v_scroll_bar().page]))

	main.ui._close_feedback_overlay()
	viewport.queue_free()
	await process_frame


func _check_live_resize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	main.ui._show_feedback_overlay(Image.create(160, 90, false, Image.FORMAT_RGBA8))
	await process_frame
	var text_edit := main.find_child("FeedbackTextEdit", true, false) as TextEdit
	var grid := main.find_child("FeedbackReportGrid", true, false) as GridContainer
	var panel := main.find_child("FeedbackPanel", true, false) as Control
	if text_edit != null:
		text_edit.text = "resize preserves player text"
	viewport.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	_check(grid != null and grid.columns == 1,
		"Live resize did not switch the feedback form to compact single-column mode.")
	_check(panel != null and panel.size.distance_to(Vector2(1200, 672)) <= 2.0,
		"Live resize did not recompute compact feedback panel geometry.")
	_check(text_edit != null and text_edit.text == "resize preserves player text",
		"Live resize rebuilt or lost the player's feedback text.")
	main.ui._close_feedback_overlay()
	viewport.queue_free()
	await process_frame
