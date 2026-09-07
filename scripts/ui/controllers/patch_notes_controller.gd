extends RefCounted

# FAN-3925 (agent-ready-refactor FD18): контроллер экрана «Что нового».
#
# Экран собирается ЗДЕСЬ, а не в модуле extends-цепочки scripts/ui/screens/**.
# Фасад (scripts/ui_screens.gd через misc_screens.gd) оставляет за собой только
# точку входа `_show_patch_notes_screen()` и передаёт себя контроллеру как
# контекст `ui`. Контроллер не хранит копий разделяемого состояния: сцена,
# ui_layer, масштаб и стили каждый раз читаются через `ui`/`ui.game`, а
# обработчики («Назад», Esc) привязаны к методу фасада, не к контроллеру —
# после `show()` объект можно отбросить, ничего висячего не остаётся.
#
# Явная поверхность зависимостей от фасада (REQUIRED_UI_METHODS) — единственный
# способ достучаться до общего кита. Тест tests/patch_notes_composition_test.gd
# проверяет, что каждый метод существует на фасаде и что контроллер не вызывает
# на `ui` ничего сверх этого списка. Расширять список — осознанное решение.
#
# Содержимое, имена узлов, порядок сборки, тема, фокус и навигация перенесены из
# misc_screens.gd БЕЗ визуальных изменений (SCRUM-159, SCRUM-879, SCRUM-813).

const PatchNotesData := preload("res://scripts/patch_notes_data.gd")

# Методы фасада ui_screens, которые использует контроллер. Всё остальное —
# движок (Control/Label/...), данные (PatchNotesData) и SemanticTypography.
const REQUIRED_UI_METHODS: Array[StringName] = [
	&"_prepare_global_tooltips",
	&"_unified_add_background",
	&"_atlas_ui_scale",
	&"_unified_make_safe_area",
	&"_unified_header_chip",
	&"_make_button",
	&"_set_action_button_size",
	&"_atlas_action_button_height",
	&"_show_main_menu",
	&"_ensure_run_ui_gamepad_bindings",
	&"_atlas_chip_style",
	&"_readable_font_size",
	&"_unified_add_divider",
	&"_unified_add_frame",
]

# Контекст: инстанс фасада ui_screens (единственная ссылка, не копия состояния).
var _ui


func _init(ui) -> void:
	_ui = ui


# Точка входа фасада: `PatchNotesController.new(self).show()`.
func show() -> void:
	var game = _ui.game
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "PatchNotesScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_ui._prepare_global_tooltips(root)
	_ui._unified_add_background(root, "patch_notes")

	var s: float = _ui._atlas_ui_scale()
	var safe: MarginContainer = _ui._unified_make_safe_area(root, "PatchNotes")
	var layout := VBoxContainer.new()
	layout.name = "PatchNotesLayout"
	layout.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	safe.add_child(layout)

	layout.add_child(_build_header(game, s))
	layout.add_child(_build_panel(s))

	# Рама — ПОСЛЕДНЕЙ: полый 9-slice поверх контента (контент в safe-зоне).
	_ui._unified_add_frame(root, "PatchNotes")


# Заголовок: чип «Что нового», распорка, единый «Назад» (плита 260×h).
# Стартовый фокус — «Назад»; A/B/Esc возвращают в меню (SCRUM-813).
func _build_header(game, s: float) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.name = "PatchNotesHeader"
	header.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	header.add_child(_ui._unified_header_chip("PatchNotes", "Что нового", "patch_notes", s))
	var header_spacer := Control.new()
	header_spacer.name = "PatchNotesHeaderSpacer"
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var back_button: Button = _ui._make_button("Назад")
	back_button.name = "PatchNotesBackButton"
	_ui._set_action_button_size(back_button, 260.0, _ui._atlas_action_button_height())
	back_button.pressed.connect(_ui._show_main_menu)
	header.add_child(back_button)
	game.ui_escape_action = _ui._show_main_menu
	# Контент патч-ноутов read-only — прокрутка колесом/перетаскиванием.
	_ui._ensure_run_ui_gamepad_bindings()
	back_button.call_deferred("grab_focus")
	return header


# Кожаная панель со скроллом и списком версий (новейшая первой).
func _build_panel(s: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PatchNotesPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _ui._atlas_chip_style(0.90, roundf(18.0 * s)))

	var scroll := ScrollContainer.new()
	scroll.name = "PatchNotesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "PatchNotesContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	scroll.add_child(content)
	_fill_entries(content, s)
	return panel


func _fill_entries(content: VBoxContainer, s: float) -> void:
	var entries := PatchNotesData.all_entries()
	for i in entries.size():
		var entry_data: Dictionary = entries[i]
		var version := str(entry_data.get("version", ""))
		content.add_child(_make_version_label(version, str(entry_data.get("date", ""))))
		for line in (entry_data.get("highlights", []) as Array):
			content.add_child(_make_highlight_label(str(line)))
		if i < entries.size() - 1:
			_ui._unified_add_divider(content, s, "_" + version)


func _make_version_label(version: String, date: String) -> Label:
	var version_label := Label.new()
	version_label.name = "PatchNotesVersion_%s" % version.replace(".", "_")
	version_label.text = "Версия %s  (%s)" % [version, date]
	version_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(
		SemanticTypography.ROLE_CAPTION,
		_ui._readable_font_size(SemanticTypography.ROLE_CAPTION, 24),
		SemanticTypography.role_min(SemanticTypography.ROLE_CAPTION),
		SemanticTypography.role_max(SemanticTypography.ROLE_CAPTION)
	))
	version_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	return version_label


func _make_highlight_label(line: String) -> Label:
	var bullet := Label.new()
	bullet.text = "•  %s" % line
	bullet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bullet.add_theme_font_size_override("font_size", _ui._readable_font_size(SemanticTypography.ROLE_BODY, 16))
	bullet.add_theme_color_override("font_color", Color(0.86, 0.90, 0.97, 0.96))
	return bullet
