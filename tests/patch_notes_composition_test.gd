extends SceneTree

# FAN-3925 (agent-ready-refactor FD18): характеризация экрана «Что нового»
# после выноса сборки в scripts/ui/controllers/patch_notes_controller.gd.
#
# 1) Содержимое/тема: через фасад строится тот же PatchNotesScreen — имена и
#    порядок узлов, тексты версий и пунктов, оверрайды шрифтов/цветов/отступов,
#    стайлбокс панели, рама последней. Снимок дерева пишется в файл из
#    FSD_PATCH_NOTES_SNAPSHOT_OUT (сравнение до/после — в отчёте карточки).
# 2) Фокус и навигация: стартовый фокус — PatchNotesBackButton; «Назад» и Esc
#    (game.ui_escape_action) возвращают в MainMenuScreen.
# 3) Повторное открытие/закрытие: экран не накапливает CanvasLayer/узлы, число
#    узлов при открытом экране одинаково на 2-м и 5-м цикле.
# 4) Шов контроллер/контекст: фасадный метод делегирует контроллеру; контроллер
#    вызывает на `ui` только методы из REQUIRED_UI_METHODS, все они существуют
#    на фасаде; контроллер не хранит копий состояния (единственное поле — `_ui`).
# 5) Соседи: титры (_show_credits_screen) строятся как прежде.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const MainCompileGuard := preload("res://tests/main_compile_guard.gd")
const PatchNotes := preload("res://scripts/patch_notes_data.gd")
const PatchNotesController := preload("res://scripts/ui/controllers/patch_notes_controller.gd")
const MISC_SCREENS_PATH := "res://scripts/ui/screens/misc_screens.gd"
const CONTROLLER_PATH := "res://scripts/ui/controllers/patch_notes_controller.gd"
const OPEN_CLOSE_CYCLES := 5

var errors := PackedStringArray()


func _initialize() -> void:
	var gate_problems := MainCompileGuard.blocking_errors()
	if not gate_problems.is_empty():
		for problem in gate_problems:
			push_error("FAN-1087 main-dependency gate: %s" % problem)
		quit(1)
		return
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await _check_content_and_theme(main)
	await _check_focus_and_back_navigation(main)
	await _check_repeated_open_close(main)
	_check_composition_seam(main)
	await _check_credits_unchanged(main)

	main.queue_free()
	await process_frame
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("FAN-3925 patch notes composition test passed.")
	quit(0)


func _open(main: Node) -> Control:
	main.ui._show_patch_notes_screen()
	await process_frame
	await process_frame
	return main.find_child("PatchNotesScreen", true, false) as Control


func _focus_name(main: Node) -> String:
	var owner := main.get_viewport().gui_get_focus_owner()
	return owner.name if owner != null else ""


# --- 1) содержимое и тема -----------------------------------------------------

func _check_content_and_theme(main: Node) -> void:
	var screen := await _open(main)
	if screen == null:
		errors.append("Content: PatchNotesScreen не построился через фасад.")
		return
	if screen.get_parent() != main.ui_layer:
		errors.append("Content: PatchNotesScreen должен лежать прямо в game.ui_layer.")

	var layout := screen.find_child("PatchNotesLayout", true, false) as VBoxContainer
	var header := screen.find_child("PatchNotesHeader", true, false) as HBoxContainer
	var panel := screen.find_child("PatchNotesPanel", true, false) as PanelContainer
	var scroll := screen.find_child("PatchNotesScroll", true, false) as ScrollContainer
	var content := screen.find_child("PatchNotesContent", true, false) as VBoxContainer
	var back_button := screen.find_child("PatchNotesBackButton", true, false) as Button
	if layout == null or header == null or panel == null or scroll == null or content == null or back_button == null:
		errors.append("Content: нет обязательных узлов (layout/header/panel/scroll/content/back).")
		return
	if layout.get_child(0) != header or layout.get_child(1) != panel or layout.get_child_count() != 2:
		errors.append("Content: PatchNotesLayout должен содержать ровно [header, panel] в этом порядке.")
	if header.get_child_count() != 3 or header.get_child(1).name != "PatchNotesHeaderSpacer" or header.get_child(2) != back_button:
		errors.append("Content: заголовок — [чип, распорка, Назад].")
	if back_button.text != "Назад":
		errors.append("Content: кнопка возврата должна называться «Назад», получено '%s'." % back_button.text)
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		errors.append("Content: горизонтальная прокрутка патч-ноутов должна быть выключена.")
	if not panel.has_theme_stylebox_override("panel") or not (panel.get_theme_stylebox("panel") is StyleBoxFlat):
		errors.append("Content: панель должна нести кожаный StyleBoxFlat (_atlas_chip_style).")
	var last_child := screen.get_child(screen.get_child_count() - 1)
	if not str(last_child.name).begins_with("PatchNotes") or not (last_child is Panel):
		errors.append("Content: рама должна добавляться последней поверх контента, последний узел: %s." % str(last_child.name))

	# Порядок и тексты: заголовок версии, затем её пункты, разделитель между версиями.
	var entries := PatchNotes.all_entries()
	var expected: Array[String] = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		expected.append("Версия %s  (%s)" % [str(entry.get("version", "")), str(entry.get("date", ""))])
		for line in (entry.get("highlights", []) as Array):
			expected.append("•  %s" % str(line))
	var actual: Array[String] = []
	var dividers := 0
	for child in content.get_children():
		if child is Label:
			actual.append((child as Label).text)
		else:
			dividers += 1
	if actual != expected:
		errors.append("Content: тексты/порядок патч-ноутов расходятся с patch_notes_data (%d vs %d строк)." % [actual.size(), expected.size()])
	if dividers != entries.size() - 1:
		errors.append("Content: ожидалось %d разделителей между версиями, получено %d." % [entries.size() - 1, dividers])
	var version_labels := screen.find_children("PatchNotesVersion_*", "Label", true, false)
	if version_labels.size() != entries.size():
		errors.append("Content: ожидалось %d заголовков версий, получено %d." % [entries.size(), version_labels.size()])
	for label in version_labels:
		if not (label as Label).has_theme_font_size_override("font_size") or not (label as Label).has_theme_color_override("font_color"):
			errors.append("Content: заголовок версии %s без оверрайда шрифта/цвета." % str(label.name))
			break

	_write_snapshot(screen, main)


# Снимок дерева экрана для сравнения до/после рефакторинга (при заданном пути).
func _write_snapshot(screen: Control, main: Node) -> void:
	var out := OS.get_environment("FSD_PATCH_NOTES_SNAPSHOT_OUT")
	if out == "":
		return
	var snapshot := {
		"focus": _focus_name(main),
		"escape_action_valid": main.ui_escape_action.is_valid(),
		"escape_action_method": str(main.ui_escape_action.get_method()),
		"tree": _snapshot_node(screen),
	}
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		errors.append("Snapshot: не удалось открыть %s для записи." % out)
		return
	file.store_string(JSON.stringify(snapshot, "  "))
	file.close()


func _snapshot_node(node: Node) -> Dictionary:
	var item := {"class": node.get_class(), "name": str(node.name)}
	if node is Control:
		var control := node as Control
		var rect := control.get_global_rect()
		item["rect"] = [roundf(rect.position.x), roundf(rect.position.y), roundf(rect.size.x), roundf(rect.size.y)]
		item["size_flags"] = [control.size_flags_horizontal, control.size_flags_vertical]
		item["mouse_filter"] = control.mouse_filter
		var overrides := {}
		for constant_name in ["separation", "margin_left", "margin_top", "margin_right", "margin_bottom"]:
			if control.has_theme_constant_override(constant_name):
				overrides[constant_name] = control.get_theme_constant(constant_name)
		if control.has_theme_font_size_override("font_size"):
			overrides["font_size"] = control.get_theme_font_size("font_size")
		for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			if control.has_theme_color_override(color_name):
				overrides[color_name] = control.get_theme_color(color_name).to_html()
		for style_name in ["panel", "normal", "hover", "pressed", "focus"]:
			if control.has_theme_stylebox_override(style_name):
				overrides[style_name] = _snapshot_stylebox(control.get_theme_stylebox(style_name))
		if not overrides.is_empty():
			item["theme"] = overrides
	if node is Label:
		item["text"] = (node as Label).text
		item["autowrap"] = (node as Label).autowrap_mode
		item["align"] = (node as Label).horizontal_alignment
	elif node is Button:
		item["text"] = (node as Button).text
		item["focus_mode"] = (node as Button).focus_mode
	elif node is ScrollContainer:
		item["h_scroll"] = (node as ScrollContainer).horizontal_scroll_mode
	elif node is TextureRect:
		var texture := (node as TextureRect).texture
		item["texture"] = texture.resource_path if texture != null else ""
		item["stretch"] = (node as TextureRect).stretch_mode
	elif node is ColorRect:
		item["color"] = (node as ColorRect).color.to_html()
	var children: Array = []
	for child in node.get_children():
		children.append(_snapshot_node(child))
	if not children.is_empty():
		item["children"] = children
	return item


func _snapshot_stylebox(style: StyleBox) -> Dictionary:
	if style == null:
		return {}
	var item := {"class": style.get_class()}
	item["content_margins"] = [style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom]
	if style is StyleBoxFlat:
		var flat := style as StyleBoxFlat
		item["bg"] = flat.bg_color.to_html()
		item["border"] = flat.border_color.to_html()
		item["border_w"] = [flat.border_width_left, flat.border_width_top, flat.border_width_right, flat.border_width_bottom]
		item["corner"] = [flat.corner_radius_top_left, flat.corner_radius_top_right, flat.corner_radius_bottom_right, flat.corner_radius_bottom_left]
	elif style is StyleBoxTexture:
		var tex := (style as StyleBoxTexture).texture
		item["texture"] = tex.resource_path if tex != null else ""
	return item


# --- 2) фокус и навигация ------------------------------------------------------

func _check_focus_and_back_navigation(main: Node) -> void:
	var screen := await _open(main)
	if screen == null:
		errors.append("Navigation: экран не открылся.")
		return
	if _focus_name(main) != "PatchNotesBackButton":
		errors.append("Navigation: стартовый фокус — PatchNotesBackButton, получено '%s'." % _focus_name(main))
	if not main.ui_escape_action.is_valid() or main.ui_escape_action.get_object() != main.ui or str(main.ui_escape_action.get_method()) != "_show_main_menu":
		errors.append("Navigation: game.ui_escape_action должен быть ui._show_main_menu.")
	var back_button := screen.find_child("PatchNotesBackButton", true, false) as Button
	back_button.pressed.emit()
	await process_frame
	await process_frame
	if main.find_child("PatchNotesScreen", true, false) != null:
		errors.append("Navigation: после «Назад» экран патч-ноутов остался в дереве.")
	if main.find_child("MainMenuScreen", true, false) == null:
		errors.append("Navigation: «Назад» не открыл главное меню.")

	# Esc/B: тот же возврат через game.ui_escape_action.
	screen = await _open(main)
	if screen == null:
		errors.append("Navigation: повторное открытие для Esc не построило экран.")
		return
	main.ui_escape_action.call()
	await process_frame
	await process_frame
	if main.find_child("PatchNotesScreen", true, false) != null or main.find_child("MainMenuScreen", true, false) == null:
		errors.append("Navigation: Esc не вернул в главное меню.")


# --- 3) повторное открытие/закрытие --------------------------------------------

func _check_repeated_open_close(main: Node) -> void:
	var node_count_after_second := -1
	var node_count_after_last := -1
	for cycle in OPEN_CLOSE_CYCLES:
		var screen := await _open(main)
		if screen == null:
			errors.append("Lifecycle: цикл %d — экран не открылся." % (cycle + 1))
			return
		var layers := 0
		for child in main.get_children():
			if child is CanvasLayer and child.find_child("PatchNotesScreen", true, false) != null:
				layers += 1
		if layers != 1:
			errors.append("Lifecycle: цикл %d — ожидался один CanvasLayer с экраном, получено %d." % [cycle + 1, layers])
		if main.find_children("PatchNotesScreen", "", true, false).size() != 1:
			errors.append("Lifecycle: цикл %d — экран продублирован." % (cycle + 1))
		if cycle == 1:
			node_count_after_second = _tree_node_count(main)
		elif cycle == OPEN_CLOSE_CYCLES - 1:
			node_count_after_last = _tree_node_count(main)
		(screen.find_child("PatchNotesBackButton", true, false) as Button).pressed.emit()
		await process_frame
		await process_frame
		if main.find_child("PatchNotesScreen", true, false) != null or main.find_child("PatchNotesBackButton", true, false) != null:
			errors.append("Lifecycle: цикл %d — после закрытия остались узлы патч-ноутов." % (cycle + 1))
	if node_count_after_second != node_count_after_last:
		errors.append("Lifecycle: число узлов при открытом экране растёт между циклами (%d -> %d)." % [node_count_after_second, node_count_after_last])


func _tree_node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _tree_node_count(child)
	return count


# --- 4) шов контроллер/контекст ------------------------------------------------

func _check_composition_seam(main: Node) -> void:
	for method_name in PatchNotesController.REQUIRED_UI_METHODS:
		if not main.ui.has_method(method_name):
			errors.append("Seam: фасад не имеет метода %s из REQUIRED_UI_METHODS." % str(method_name))

	# Контроллер обращается к `_ui.` только за объявленной поверхностью и полем game.
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var regex := RegEx.new()
	regex.compile("_ui\\.([A-Za-z_][A-Za-z0-9_]*)")
	var declared := {}
	for method_name in PatchNotesController.REQUIRED_UI_METHODS:
		declared[str(method_name)] = true
	var undeclared := {}
	for match in regex.search_all(controller_source):
		var member := match.get_string(1)
		if member != "game" and not declared.has(member):
			undeclared[member] = true
	if not undeclared.is_empty():
		errors.append("Seam: контроллер использует необъявленные члены фасада: %s." % ", ".join(undeclared.keys()))
	# И наоборот: каждый объявленный метод действительно нужен контроллеру.
	for method_name in declared.keys():
		if not controller_source.contains("_ui.%s(" % method_name) and not controller_source.contains("_ui.%s" % method_name):
			errors.append("Seam: REQUIRED_UI_METHODS содержит неиспользуемый %s." % method_name)

	# Никаких копий разделяемого состояния: единственное поле контроллера — контекст.
	var fields: Array[String] = []
	var controller_script: Script = PatchNotesController
	for property in controller_script.get_script_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(str(property.get("name", "")))
	if fields != ["_ui"]:
		errors.append("Seam: контроллер должен хранить только контекст `_ui`, поля: %s." % str(fields))

	# Фасад делегирует, а не дублирует сборку экрана.
	var misc_source := FileAccess.get_file_as_string(MISC_SCREENS_PATH)
	if not misc_source.contains("patch_notes_controller.gd"):
		errors.append("Seam: misc_screens.gd не ссылается на контроллер патч-ноутов.")
	for marker in ["PatchNotesScroll", "PatchNotesVersion_", "PatchNotesHeaderSpacer"]:
		if misc_source.contains(marker):
			errors.append("Seam: сборка экрана (%s) всё ещё живёт в misc_screens.gd." % marker)


# --- 5) соседний экран титров --------------------------------------------------

func _check_credits_unchanged(main: Node) -> void:
	main.ui._show_credits_screen()
	await process_frame
	await process_frame
	if main.find_child("CreditsScreen", true, false) == null or main.find_child("CreditsBackButton", true, false) == null:
		errors.append("Credits: экран титров перестал строиться.")
	elif _focus_name(main) != "CreditsBackButton":
		errors.append("Credits: стартовый фокус титров — CreditsBackButton, получено '%s'." % _focus_name(main))
	if main.ui_escape_action.is_valid():
		main.ui_escape_action.call()
		await process_frame
		await process_frame
	if main.find_child("MainMenuScreen", true, false) == null:
		errors.append("Credits: Esc из титров не вернул в главное меню.")
