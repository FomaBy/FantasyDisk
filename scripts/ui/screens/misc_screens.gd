extends "res://scripts/ui/screens/atlas_canvas.gd"

# FAN-3824: модуль распределённого UI-класса — патч-ноуты, титры и делегаты лор-экранов.
# Часть линейной extends-цепочки scripts/ui/screens/** (сборка — фасад
# scripts/ui_screens.gd). Код перенесён из ui_screens.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в ui_screens_shared_api.gd.





# FAN-3925 (agent-ready-refactor FD18): экран «Что нового» собирает явный
# контроллер scripts/ui/controllers/patch_notes_controller.gd. Фасад отдаёт ему
# себя как контекст (общий кит стилей/оболочки, навигация) и не хранит ничего
# лишнего: обработчики привязаны к методам фасада, а узлы живут в game.ui_layer.
const PatchNotesController := preload("res://scripts/ui/controllers/patch_notes_controller.gd")


func _show_patch_notes_screen() -> void:
	# SCRUM-159 / SCRUM-879 / SCRUM-813: содержимое, атлас-стиль и фокус —
	# в контроллере, поведение экрана и имена узлов сохранены 1:1.
	PatchNotesController.new(self).show()




# SCRUM-968: player-facing «Благодарности» — обязательный CC BY-блок (Kevin
# MacLeod, CC BY 4.0) + CC0-вклад + инструменты. Канонический источник —
# docs/CREDITS.md; текст транскрибирован в рантайм, чтобы обязательная атрибуция
# уходила в билд без зависимости от экспорта каталога docs/. Экран автономный:
# фон + затемнение + кожаный чип-панель со скроллом + «Назад» в меню.
func _show_credits_screen() -> void:
	game._clear_ui()
	game.ui_layer = CanvasLayer.new()
	game.ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.ui_layer)

	var root := Control.new()
	root.name = "CreditsScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	game.ui_layer.add_child(root)
	_prepare_global_tooltips(root)
	_add_screen_background(root, "settings")

	var s := _atlas_ui_scale()
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.name = "CreditsPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var panel_width := clampf(viewport_size.x - 96.0, 560.0, 900.0)
	var panel_height := clampf(viewport_size.y - 96.0, 360.0, 760.0)
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.add_theme_stylebox_override("panel", _atlas_chip_style(0.95, roundf(20.0 * s)))
	root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.name = "CreditsOuter"
	outer.add_theme_constant_override("separation", int(roundf(12.0 * s)))
	panel.add_child(outer)

	var title := Label.new()
	title.name = "CreditsTitle"
	title.text = "Благодарности"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_TITLE, 32))
	title.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68, 1.0))
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.name = "CreditsContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	scroll.add_child(content)

	# Порядок и текст зеркалят docs/CREDITS.md (источник истины по атрибуциям).
	_add_credits_heading(content, "Музыка (CC BY 4.0 — атрибуция обязательна)")
	_add_credits_body(content, "«Suonatore di Liuto», «Master of the Feast», «Lord of the Land», «Celtic Impulse», «Drums of the Deep», «The Escalation»")
	_add_credits_body(content, "Kevin MacLeod (incompetech.com)")
	_add_credits_body(content, "Licensed under Creative Commons: By Attribution 4.0 License")
	_add_credits_body(content, "http://creativecommons.org/licenses/by/4.0/")

	_add_credits_heading(content, "Музыка и SFX (CC0)")
	for cc0_line in [
		"RandomMind — средневековые треки (opengameart.org)",
		"Kenney — Impact Sounds / RPG Audio (kenney.nl)",
		"artisticdude — RPG Sound Pack (opengameart.org)",
		"bart — Heartbeat sounds (opengameart.org)",
		"qubodup — Ghost breath (opengameart.org)",
		"AntumDeluge — Fire Crackling (opengameart.org)",
	]:
		_add_credits_body(content, "•  %s" % cc0_line)

	_add_credits_heading(content, "Инструменты")
	_add_credits_body(content, "Godot Engine (godotengine.org, MIT)")

	# «Назад» — единый возврат в меню (плита 260×h), ui_back через общий хелпер.
	var back_button := _make_button("Назад")
	back_button.name = "CreditsBackButton"
	_set_action_button_size(back_button, 260.0, _atlas_action_button_height())
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_show_main_menu)
	_connect_ui_sfx(back_button, "back")
	outer.add_child(back_button)

	game.ui_escape_action = _show_main_menu
	_ensure_run_ui_gamepad_bindings()
	back_button.call_deferred("grab_focus")




func _add_credits_heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_SECTION, 20))
	label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.46, 1.0))
	parent.add_child(label)




func _add_credits_body(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _readable_font_size(SemanticTypography.ROLE_BODY, 15))
	label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.97, 0.96))
	parent.add_child(label)




# FAN-1080: вступление истории и остальной лор-UI живут в scripts/ui/lore_screens.gd
# (извлечено под static-quality ратчет); здесь — тонкие точки входа.
func _maybe_show_lore_intro(next_action: Callable) -> void:
	LoreScreens.maybe_show_intro(self, next_action)




func _show_lore_intro(on_finish: Callable, mark_seen := true) -> void:
	LoreScreens.show_intro(self, on_finish, mark_seen)
