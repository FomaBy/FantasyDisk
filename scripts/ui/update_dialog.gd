extends Control

signal close_requested

const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const UpdateManagerScript := preload("res://scripts/update_manager.gd")

var presenter
var update_manager
var mode := "current"
var payload := {}
var detail_message := ""


func configure(owner_presenter, manager, dialog_mode: String, data: Dictionary, message: String) -> void:
	presenter = owner_presenter
	update_manager = manager
	mode = dialog_mode
	payload = data.duplicate(true)
	detail_message = message


func _ready() -> void:
	name = "GameUpdateDialog"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = presenter.game.get_viewport().get_visible_rect().size
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 520
	_build_dialog()
	presenter.game.get_viewport().size_changed.connect(_fit_to_viewport)


func _exit_tree() -> void:
	if presenter != null and presenter.game != null:
		var viewport: Viewport = presenter.game.get_viewport()
		if viewport != null and viewport.size_changed.is_connected(_fit_to_viewport):
			viewport.size_changed.disconnect(_fit_to_viewport)


func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = presenter.game.get_viewport().get_visible_rect().size
	var panel := get_node_or_null("GameUpdatePanel") as PanelContainer
	if panel == null:
		return
	var panel_size := Vector2(
		minf(1120.0, maxf(560.0, size.x - 80.0)),
		minf(620.0, maxf(500.0, size.y - 72.0)))
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5


func _build_dialog() -> void:
	var dim := ColorRect.new()
	dim.name = "GameUpdateDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var viewport_size: Vector2 = presenter.game.get_viewport().get_visible_rect().size
	var panel_size := Vector2(
		minf(1120.0, maxf(560.0, viewport_size.x - 80.0)),
		minf(620.0, maxf(500.0, viewport_size.y - 72.0)))
	var panel := PanelContainer.new()
	panel.name = "GameUpdatePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		presenter._atlas_chip_style(0.98, maxf(18.0, 24.0 * presenter._atlas_ui_scale())))
	add_child(panel)

	var box := VBoxContainer.new()
	box.name = "GameUpdateContent"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Label.new()
	title.name = "GameUpdateTitle"
	title.text = _title_text()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(
		"font_size", presenter._readable_font_size(SemanticTypography.ROLE_TITLE, 34))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	box.add_child(title)

	var versions := Label.new()
	versions.name = "GameUpdateVersions"
	versions.text = _versions_text()
	versions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versions.add_theme_font_size_override("font_size", 20)
	versions.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90, 1.0))
	versions.visible = not versions.text.is_empty()
	box.add_child(versions)

	var body := Label.new()
	body.name = "GameUpdateBody"
	body.text = _body_text()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0.0, 112.0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78, 1.0))
	box.add_child(body)

	var status := Label.new()
	status.name = "GameUpdateStatus"
	status.text = detail_message
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", _status_color())
	status.visible = not status.text.is_empty()
	box.add_child(status)

	var button_row := HBoxContainer.new()
	button_row.name = "GameUpdateButtons"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.custom_minimum_size = Vector2(0.0, 72.0)
	button_row.add_theme_constant_override("separation", 18)
	box.add_child(button_row)

	var primary := presenter._make_button(_primary_text()) as Button
	primary.name = "GameUpdatePrimaryButton"
	presenter._set_action_button_size(primary, 420.0 if mode == "available" else 280.0, 72.0)
	primary.disabled = mode in ["checking", "downloading"]
	primary.pressed.connect(_on_primary_pressed)
	button_row.add_child(primary)

	var secondary := presenter._make_button("Позже" if mode == "available" else "Закрыть") as Button
	secondary.name = "GameUpdateCloseButton"
	presenter._set_action_button_size(secondary, 240.0, 72.0)
	secondary.pressed.connect(close_requested.emit)
	button_row.add_child(secondary)

	primary.focus_neighbor_left = secondary.get_path()
	primary.focus_neighbor_right = secondary.get_path()
	primary.focus_neighbor_top = secondary.get_path()
	primary.focus_neighbor_bottom = secondary.get_path()
	secondary.focus_neighbor_left = primary.get_path()
	secondary.focus_neighbor_right = primary.get_path()
	secondary.focus_neighbor_top = primary.get_path()
	secondary.focus_neighbor_bottom = primary.get_path()
	if primary.disabled:
		secondary.call_deferred("grab_focus")
	else:
		primary.call_deferred("grab_focus")


func _title_text() -> String:
	match mode:
		"available":
			return "Доступно обновление"
		"checking":
			return "Проверка обновлений"
		"downloading":
			return "Загрузка обновления"
		"error":
			return "Не удалось обновить игру"
		"installer_opened":
			return "Установщик готов"
		_:
			return "Игра обновлена"


func _versions_text() -> String:
	var current := str(payload.get("current_version", ""))
	var latest := str(payload.get("latest_version", ""))
	if latest == "" and typeof(payload.get("manifest", null)) == TYPE_DICTIONARY:
		latest = str((payload["manifest"] as Dictionary).get("version", ""))
	if current == "":
		current = str(update_manager.current_version()) if update_manager != null else ""
	if latest == "":
		return "Версия %s" % current if current != "" else ""
	return "Установлено: %s  →  Новая версия: %s" % [current, latest]


func _body_text() -> String:
	match mode:
		"available":
			var body := "Скачать официальный установщик с GitHub Releases? Файл будет проверен по размеру и SHA-256 перед запуском."
			if _macos_unsigned_disclosure_needed():
				body += "\n" + UpdateManagerScript.MACOS_UNSIGNED_NOTICE
			return body
		"checking":
			return "Ищем последнюю публичную версию FantasyDisk на GitHub Releases."
		"downloading":
			return "Не закрывайте игру до окончания загрузки. После проверки откроется штатный DMG или Windows Setup."
		"error":
			return "Повторите проверку позже или откройте публичную страницу релиза в браузере. Текущая установка не изменена."
		"installer_opened":
			return "Завершите обновление в открывшемся системном установщике, затем перезапустите FantasyDisk."
		_:
			return "У вас уже установлена последняя публичная версия FantasyDisk."


func _macos_unsigned_disclosure_needed() -> bool:
	return OS.get_name() == "macOS" and UpdateManagerScript.macos_update_is_unsigned()


func _primary_text() -> String:
	match mode:
		"available":
			return "Скачать и установить"
		"checking":
			return "Проверяем…"
		"downloading":
			return "Скачиваем…"
		"error":
			return "Открыть GitHub"
		_:
			return "Готово"


func _status_color() -> Color:
	if mode == "error":
		return Color(1.0, 0.66, 0.56, 1.0)
	return Color(0.72, 0.86, 0.72, 1.0)


func _on_primary_pressed() -> void:
	if update_manager == null:
		return
	match mode:
		"available":
			update_manager.download_installer()
		"error":
			update_manager.open_release_page()
			close_requested.emit()
		_:
			close_requested.emit()
