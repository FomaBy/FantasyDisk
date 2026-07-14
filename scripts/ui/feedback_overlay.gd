extends RefCounted

# Focused FAN-1057 feedback overlay controller. UIScreens remains the public
# facade; this stateless module owns construction/responsive behavior so the
# monolithic screen coordinator stays below its static size ratchet without a
# RefCounted host/controller reference cycle.

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const FEEDBACK_REPORTER_SCRIPT := preload("res://scripts/feedback_reporter.gd")

static func show(host, game, screenshot: Image = null) -> void:
	host._close_feedback_overlay()
	# Пауза при открытии формы фидбека — как Escape (оверлей PROCESS_MODE_ALWAYS,
	# поэтому ввод в форму работает на паузе). Снимается в _close_feedback_overlay.
	game.push_pause("feedback")

	game.feedback_overlay_layer = CanvasLayer.new()
	game.feedback_overlay_layer.name = "FeedbackOverlayLayer"
	game.feedback_overlay_layer.layer = 128
	game.feedback_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.feedback_overlay_layer)

	var root := Control.new()
	root.name = "FeedbackOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	game.feedback_overlay_layer.add_child(root)
	host._prepare_global_tooltips(root)

	var dim := ColorRect.new()
	dim.name = "FeedbackDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "FeedbackPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "FeedbackContent"
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Отправить фидбек"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", host._readable_font_size(SemanticTypography.ROLE_TITLE, 32))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	# Середина прокручивается: при любой высоте экрана заголовок сверху, а статус
	# и кнопки «Отправить»/«Отмена» снизу остаются закреплены и видимы.
	var scroll := ScrollContainer.new()
	scroll.name = "FeedbackScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.tooltip_text = "Прокрутка: колесо мыши или правый стик геймпада."
	scroll.follow_focus = true
	box.add_child(scroll)

	var scroll_body := VBoxContainer.new()
	scroll_body.name = "FeedbackScrollBody"
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_body)

	var hint := Label.new()
	hint.name = "FeedbackDescriptionHint"
	hint.text = "Что случилось, где вы были и что ожидали увидеть?"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		host._readable_font_size(SemanticTypography.ROLE_CAPTION, 16),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	hint.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	scroll_body.add_child(hint)

	# FAN-1057/FAN-1059: desktop uses two columns; compact mode switches the same
	# live Controls to a single-column scroll body without duplicating state.
	var report_grid := GridContainer.new()
	report_grid.name = "FeedbackReportGrid"
	report_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_grid.add_theme_constant_override("h_separation", 30)
	report_grid.add_theme_constant_override("v_separation", 16)
	scroll_body.add_child(report_grid)

	var text_edit := TextEdit.new()
	text_edit.name = "FeedbackTextEdit"
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.placeholder_text = "Опишите проблему или впечатление."
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_BODY,
		host._readable_font_size(SemanticTypography.ROLE_BODY, 17),
		SemanticTypography.role_min(SemanticTypography.ROLE_BODY),
		SemanticTypography.role_max(SemanticTypography.ROLE_BODY)
	))
	text_edit.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	text_edit.add_theme_color_override("font_placeholder_color", Color(0.66, 0.64, 0.58, 1.0))
	report_grid.add_child(text_edit)

	var screenshot_column := VBoxContainer.new()
	screenshot_column.name = "FeedbackScreenshotColumn"
	screenshot_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screenshot_column.add_theme_constant_override("separation", 16)
	report_grid.add_child(screenshot_column)

	var preview_center := CenterContainer.new()
	preview_center.name = "FeedbackScreenshotCenter"
	preview_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screenshot_column.add_child(preview_center)

	var preview_frame := PanelContainer.new()
	preview_frame.name = "FeedbackScreenshotFrame"
	preview_frame.add_theme_stylebox_override("panel", host._character_card_style())
	preview_center.add_child(preview_frame)

	var preview := TextureRect.new()
	preview.name = "FeedbackScreenshotPreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var safe_screenshot: Image = FEEDBACK_REPORTER_SCRIPT._normalized_screenshot(screenshot)
	preview.texture = ImageTexture.create_from_image(safe_screenshot)
	preview_frame.add_child(preview)

	var screenshot_toggle := CheckBox.new()
	screenshot_toggle.name = "FeedbackScreenshotToggle"
	screenshot_toggle.button_pressed = true
	screenshot_toggle.focus_mode = Control.FOCUS_ALL
	screenshot_toggle.tooltip_text = "Снимите выбор, чтобы изображение не отправлялось и не сохранялось локально."
	screenshot_column.add_child(screenshot_toggle)

	var apply_screenshot_state := func(included: bool) -> void:
		screenshot_toggle.text = (
			"Скриншот будет отправлен или сохранён локально"
			if included else
			"Скриншот НЕ будет отправлен или сохранён")
		preview.modulate = Color.WHITE if included else Color(0.52, 0.52, 0.52, 0.34)
		preview.set_meta("included_in_feedback", included)
	screenshot_toggle.toggled.connect(apply_screenshot_state)
	apply_screenshot_state.call(true)

	var privacy_frame := PanelContainer.new()
	privacy_frame.name = "FeedbackPrivacyFrame"
	privacy_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The generated FAN-1059 privacy well is shallow and wide. A compact Atlas
	# chip preserves that usable interior; the old minimal-metal field reserves
	# 100 vertical pixels for ornament and forced the disclosure below the fold.
	privacy_frame.add_theme_stylebox_override("panel", host._atlas_chip_style(0.92, 12.0))
	scroll_body.add_child(privacy_frame)

	var privacy_box := VBoxContainer.new()
	privacy_box.name = "FeedbackPrivacyContent"
	privacy_box.add_theme_constant_override("separation", 6)
	privacy_frame.add_child(privacy_box)

	var privacy_heading := Label.new()
	privacy_heading.name = "FeedbackPrivacyHeading"
	privacy_heading.text = "Что попадёт в отчёт"
	privacy_heading.add_theme_font_size_override(
		"font_size", SemanticTypography.role_min(SemanticTypography.ROLE_SECTION))
	privacy_heading.add_theme_color_override("font_color", Color(0.96, 0.86, 0.58, 1.0))
	privacy_box.add_child(privacy_heading)

	var privacy_body := Label.new()
	privacy_body.name = "FeedbackPrivacyBody"
	privacy_body.text = (
		"Текст и выбранный скриншот. Метаданные: версия игры, персонаж, оружие, "
		+ "Возвышение, акт, этап и масштаб маршрута, тип узла, состояние боя и босса, "
		+ "открытый экран, разрешение, ОС и локальное время. Relay обрабатывает "
		+ "постоянный псевдонимный UUID установки, а защищённый edge видит IP "
		+ "соединения для защиты от спама.")
	privacy_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy_body.add_theme_font_size_override(
		"font_size", SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION))
	privacy_body.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
	privacy_box.add_child(privacy_body)

	var privacy_config: Dictionary = host._feedback_privacy_configuration()
	var privacy_ready := bool(privacy_config.get("complete", false))
	var operator_retention := Label.new()
	operator_retention.name = "FeedbackOperatorRetentionLabel"
	if privacy_ready:
		operator_retention.text = (
			"Оператор: %s. Хранение: %s\nКонтакт: %s · Политика: %s" % [
				str(privacy_config.get("operator", "")),
				str(privacy_config.get("retention", "")),
				str(privacy_config.get("contact", "")),
				str(privacy_config.get("policy", "")),
			])
	else:
		operator_retention.text = (
			"Оператор сетевой обработки: не указан. Срок хранения: не утверждён. "
			+ "Поэтому онлайн-отправка отключена.")
	operator_retention.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	operator_retention.add_theme_font_size_override(
		"font_size", SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION))
	operator_retention.add_theme_color_override(
		"font_color", Color(0.76, 0.88, 0.96, 1.0) if privacy_ready else Color(1.0, 0.78, 0.46, 1.0))
	privacy_box.add_child(operator_retention)

	var fallback_label := Label.new()
	fallback_label.name = "FeedbackLocalFallbackLabel"
	fallback_label.text = (
		"Локальная копия хранится только на этом устройстве до удаления вами; "
		+ "при выключенном скриншоте файл screenshot.png не создаётся.")
	fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_label.add_theme_font_size_override(
		"font_size", SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION))
	fallback_label.add_theme_color_override("font_color", Color(0.74, 0.82, 0.88, 1.0))
	privacy_box.add_child(fallback_label)

	var status := Label.new()
	status.name = "FeedbackStatusLabel"
	status.text = (
		"Отправка произойдёт только после нажатия «Отправить»."
		if privacy_ready else
		"Онлайн-отправка отключена; «Отправить» сохранит локальный отчёт.")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", host._readable_font_size(SemanticTypography.ROLE_VALUE, 14))
	status.add_theme_color_override("font_color", Color(0.74, 0.82, 0.88, 1.0))
	box.add_child(status)

	var buttons := HBoxContainer.new()
	buttons.name = "FeedbackButtons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)

	var send_button: Button = host._make_button("Отправить")
	send_button.name = "FeedbackSendButton"
	host._set_action_button_size(send_button, 260.0, 64.0)
	buttons.add_child(send_button)

	var cancel_button: Button = host._make_button("Отмена")
	cancel_button.name = "FeedbackCancelButton"
	host._set_action_button_size(cancel_button, 220.0, 64.0)
	cancel_button.pressed.connect(host._close_feedback_overlay)
	buttons.add_child(cancel_button)

	# Explicit keyboard/gamepad focus path from the authored FAN-1059 contract.
	text_edit.focus_neighbor_bottom = text_edit.get_path_to(screenshot_toggle)
	text_edit.focus_next = text_edit.get_path_to(screenshot_toggle)
	screenshot_toggle.focus_neighbor_top = screenshot_toggle.get_path_to(text_edit)
	screenshot_toggle.focus_neighbor_bottom = screenshot_toggle.get_path_to(send_button)
	screenshot_toggle.focus_next = screenshot_toggle.get_path_to(send_button)
	send_button.focus_neighbor_top = send_button.get_path_to(screenshot_toggle)
	send_button.focus_neighbor_right = send_button.get_path_to(cancel_button)
	send_button.focus_next = send_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(send_button)
	cancel_button.focus_neighbor_top = cancel_button.get_path_to(screenshot_toggle)
	cancel_button.focus_next = cancel_button.get_path_to(text_edit)
	text_edit.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventJoypadButton or event is InputEventJoypadMotion) \
				and event.is_action_pressed("ui_down"):
			screenshot_toggle.grab_focus()
			text_edit.accept_event()
	)
	# The compact disclosure starts below the initial viewport. Keep the authored
	# four-stop focus chain, but make the right stick scroll the middle body from
	# any focused form control so controller-only players can read it before Send.
	var scroll_from_right_stick := func(event: InputEvent) -> bool:
		if not event is InputEventJoypadMotion \
				or int((event as InputEventJoypadMotion).axis) != JOY_AXIS_RIGHT_Y:
			return false
		var strength := float((event as InputEventJoypadMotion).axis_value)
		if absf(strength) < 0.45:
			return false
		var scrollbar := scroll.get_v_scroll_bar()
		var scroll_max := maxi(0, int(ceil(scrollbar.max_value - scrollbar.page)))
		var scroll_step := maxi(24, int(round(scroll.size.y * 0.65)))
		var direction := 1 if strength > 0.0 else -1
		var previous_scroll := scroll.scroll_vertical
		scroll.scroll_vertical = clampi(
			previous_scroll + direction * scroll_step, 0, scroll_max)
		return scroll.scroll_vertical != previous_scroll
	for focus_control in [text_edit, screenshot_toggle, send_button, cancel_button]:
		var scroll_owner := focus_control as Control
		scroll_owner.gui_input.connect(func(event: InputEvent) -> void:
			if bool(scroll_from_right_stick.call(event)):
				scroll_owner.accept_event()
		)

	var apply_feedback_layout := func() -> void:
		if not is_instance_valid(root) or not is_instance_valid(panel):
			return
		var viewport_size := root.get_viewport_rect().size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			viewport_size = Vector2(1280.0, 720.0)
		var compact := viewport_size.x < 1600.0 or viewport_size.y < 900.0
		var viewport_scale := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
		var panel_size: Vector2
		if viewport_scale <= 1.0:
			# Continuous interpolation keeps the exact 1280/1920 authored targets
			# without the old 1400→1401px width discontinuity.
			var compact_to_desktop := clampf(
				(viewport_scale - (2.0 / 3.0)) / (1.0 / 3.0), 0.0, 1.0)
			panel_size = Vector2(
				lerpf(1200.0, 1400.0, compact_to_desktop),
				lerpf(672.0, 990.0, compact_to_desktop))
		else:
			var layout_scale := minf(viewport_scale, 1.3333333)
			panel_size = Vector2(
				1400.0 * layout_scale,
				990.0 * layout_scale)
		panel_size.x = clampf(panel_size.x, 480.0, maxf(480.0, viewport_size.x - 80.0))
		panel_size.y = clampf(panel_size.y, 380.0, maxf(380.0, viewport_size.y - 48.0))
		panel.offset_left = -panel_size.x * 0.5
		panel.offset_top = -panel_size.y * 0.5
		panel.offset_right = panel_size.x * 0.5
		panel.offset_bottom = panel_size.y * 0.5
		panel.add_theme_stylebox_override(
			"panel", host._overhaul_2k_frame_style("fb_panel", panel_size))
		report_grid.columns = 1 if compact else 2
		var authored_scale := clampf(viewport_scale, 1.0, 1.3333333)
		text_edit.custom_minimum_size = Vector2(
			0, 160 if compact else 330.0 * authored_scale)
		var preview_size := (
			Vector2(544, 306) if compact else Vector2(500, 281) * authored_scale)
		preview_center.custom_minimum_size = preview_size
		preview_frame.custom_minimum_size = preview_size
		# PanelContainer already contributes the frame content margins; giving its
		# child another near-full minimum double-counts them and pushes desktop
		# privacy copy below the fold.
		preview.custom_minimum_size = Vector2.ZERO
		screenshot_column.custom_minimum_size = Vector2(
			0 if compact else 500.0 * authored_scale, 0)
		screenshot_toggle.custom_minimum_size = Vector2(
			0, 48 if compact else 64.0 * authored_scale)
		privacy_frame.custom_minimum_size = Vector2(
			0, 190 if compact else 180.0 * authored_scale)
		scroll_body.custom_minimum_size = Vector2(
			0, 824 if compact else 590.0 * authored_scale)
		send_button.custom_minimum_size = Vector2(260.0, 64.0) * authored_scale
		cancel_button.custom_minimum_size = Vector2(220.0, 64.0) * authored_scale
		buttons.add_theme_constant_override(
			"separation", int(round(18.0 * authored_scale)))
		var large_copy := not compact and viewport_size.y >= 1200.0
		privacy_heading.add_theme_font_size_override(
			"font_size", 22 if large_copy else SemanticTypography.role_min(SemanticTypography.ROLE_SECTION))
		privacy_body.add_theme_font_size_override(
			"font_size", 16 if large_copy else SemanticTypography.role_min(SemanticTypography.ROLE_DESCRIPTION))
		operator_retention.add_theme_font_size_override(
			"font_size", 14 if large_copy else SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION))
		fallback_label.add_theme_font_size_override(
			"font_size", 14 if large_copy else SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION))
		if compact:
			screenshot_column.move_child(screenshot_toggle, 0)
			screenshot_column.move_child(preview_center, 1)
		else:
			screenshot_column.move_child(preview_center, 0)
			screenshot_column.move_child(screenshot_toggle, 1)
	root.resized.connect(apply_feedback_layout)
	apply_feedback_layout.call()

	send_button.pressed.connect(func() -> void:
		var include_screenshot := screenshot_toggle.button_pressed
		if not bool(FEEDBACK_REPORTER_SCRIPT._is_submission_content_valid(
				text_edit.text, include_screenshot)):
			status.text = "Для отчёта без скриншота добавьте описание."
			status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.46, 1.0))
			text_edit.grab_focus()
			return
		var submitted_screenshot: Image = safe_screenshot if include_screenshot else null
		send_button.disabled = true
		screenshot_toggle.disabled = true
		text_edit.editable = false
		status.text = "Отправляем..."
		var reporter: Node = host._feedback_reporter()
		var completion := func(success: bool, message: String, local_path: String) -> void:
			host._feedback_request_id = 0
			if not is_instance_valid(status) or not is_instance_valid(send_button) \
					or not is_instance_valid(screenshot_toggle) or not is_instance_valid(text_edit):
				return
			status.text = message if local_path == "" else "%s\n%s" % [message, local_path]
			status.add_theme_color_override("font_color", Color(0.74, 0.96, 0.74, 1.0) if success else Color(1.0, 0.82, 0.50, 1.0))
			send_button.disabled = false
			screenshot_toggle.disabled = false
			text_edit.editable = true
		var request_id := int(reporter.call(
			"submit_report", text_edit.text, submitted_screenshot, host._feedback_metadata(),
			completion, include_screenshot))
		host._feedback_request_id = request_id if bool(reporter.call("is_request_active", request_id)) else 0
	)

	text_edit.grab_focus()
