extends SceneTree

# Smoke-тест ui_icon_registry.gd (был непокрыт). Реестр иконок UI (статы,
# производные атрибуты, HUD, системные) — пропавший/переименованный PNG молча
# ломает досье статов и HUD; content_registry_consistency_test эти иконки НЕ
# покрывает. Гейтит существование ресурсов, покрытие id, согласованность со
# stat_formulas и контракты аксессоров. Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/ui_icon_registry_smoke_test.gd

const IconRegistry := preload("res://scripts/ui_icon_registry.gd")
const SF := preload("res://scripts/stat_formulas.gd")


func _initialize() -> void:
	var errors: Array = []

	# --- Анти-вакуум ---
	if IconRegistry.ICON_PATHS.size() < 30:
		errors.append("ICON_PATHS подозрительно мал (%d)" % IconRegistry.ICON_PATHS.size())

	# --- Все ресурсы иконок существуют (ядро проверки) ---
	for icon_id in IconRegistry.ICON_PATHS:
		var path := str(IconRegistry.ICON_PATHS[icon_id])
		if path == "" or not ResourceLoader.exists(path):
			errors.append("иконка '%s' -> отсутствует ресурс '%s'" % [icon_id, path])
		elif not IconRegistry.has_texture(icon_id):
			errors.append("has_texture('%s') == false при существующем пути" % icon_id)

	# --- Покрытие: каждый id отображения имеет путь ---
	var groups := {
		"BASE_STAT_IDS": IconRegistry.BASE_STAT_IDS,
		"DERIVED_ATTRIBUTE_IDS": IconRegistry.DERIVED_ATTRIBUTE_IDS,
		"HUD_IDS": IconRegistry.HUD_IDS,
	}
	for group_name in groups:
		var ids: Array = groups[group_name]
		if ids.is_empty():
			errors.append("%s пуст" % group_name)
			continue
		for id in ids:
			if IconRegistry.path_for(str(id)) == "":
				errors.append("%s: id '%s' без записи в ICON_PATHS" % [group_name, id])

	# --- Согласованность со stat_formulas ---
	# Базовые статы реестра == базовые статы формул (тот же набор).
	var base_formula := {}
	for s in SF.BASE_STAT_ORDER:
		base_formula[str(s)] = true
	var base_icons := {}
	for s in IconRegistry.BASE_STAT_IDS:
		base_icons[str(s)] = true
	for s in base_formula:
		if not base_icons.has(s):
			errors.append("базовый стат '%s' формул без иконки в BASE_STAT_IDS" % s)
	for s in base_icons:
		if not base_formula.has(s):
			errors.append("BASE_STAT_IDS содержит '%s', которого нет в BASE_STAT_ORDER" % s)
	# Каждый производный id-иконки описан в STAT_DEFINITIONS (не фантом).
	for id in IconRegistry.DERIVED_ATTRIBUTE_IDS:
		if not SF.STAT_DEFINITIONS.has(str(id)):
			errors.append("производный атрибут '%s' без STAT_DEFINITIONS" % id)

	# --- Аббревиатуры (фоллбэк-текст) покрывают статы/атрибуты ---
	for id in IconRegistry.BASE_STAT_IDS:
		if str(IconRegistry.ICON_ABBREVIATIONS.get(id, "")).strip_edges() == "":
			errors.append("нет аббревиатуры для '%s'" % id)
	for id in IconRegistry.DERIVED_ATTRIBUTE_IDS:
		if str(IconRegistry.ICON_ABBREVIATIONS.get(id, "")).strip_edges() == "":
			errors.append("нет аббревиатуры для производного '%s'" % id)

	# --- Контракты аксессоров для неизвестного id ---
	if IconRegistry.path_for("__unknown_icon__") != "":
		errors.append("path_for неизвестного id вернул не пустую строку")
	if IconRegistry.has_texture("__unknown_icon__"):
		errors.append("has_texture неизвестного id == true")
	if IconRegistry.texture_for("__unknown_icon__") != null:
		errors.append("texture_for неизвестного id != null")

	if not errors.is_empty():
		for e in errors:
			push_error("UI icon registry smoke: %s" % e)
		push_error("UI icon registry smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("UI icon registry smoke test passed (%d иконок, %d базовых + %d производных + %d HUD id)." % [
		IconRegistry.ICON_PATHS.size(), IconRegistry.BASE_STAT_IDS.size(),
		IconRegistry.DERIVED_ATTRIBUTE_IDS.size(), IconRegistry.HUD_IDS.size()])
	quit(0)
