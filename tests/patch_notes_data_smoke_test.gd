extends SceneTree

# Smoke-тест patch_notes_data.gd (был непокрыт). Патч-ноуты — это и контент
# («Что нового» в меню), и ЛОГИКА сравнения версий (entries_since/has_new_since/
# _version_greater) для бейджа новой версии после обновления. Поломка всплыла бы
# только у игрока после апдейта. Валидирует структуру записей, порядок версий и
# корректность version-логики (в т.ч. числовое 0.2.10 > 0.2.9, нечисловые части).
# Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/patch_notes_data_smoke_test.gd

const PatchNotes := preload("res://scripts/patch_notes_data.gd")


func _initialize() -> void:
	var errors: Array = []
	_check_entries(errors)
	_check_ordering(errors)
	_check_version_logic(errors)
	_check_query_logic(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Patch notes smoke: %s" % e)
		push_error("Patch notes smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Patch notes smoke test passed (%d версий)." % PatchNotes.PATCH_NOTES.size())
	quit(0)


# Игровой текст: непустой, не путь/ID/плейсхолдер (правило «без внутренних ID»).
func _player_text_ok(text: String) -> bool:
	var t := text.strip_edges()
	if t == "":
		return false
	var low := t.to_lower()
	if low == "null" or low.begins_with("res://"):
		return false
	# Внутренние тикеты/идентификаторы не должны утекать игроку.
	if t.contains("SCRUM") or low.contains("todo") or low.contains("placeholder"):
		return false
	return true


func _check_entries(errors: Array) -> void:
	var entries := PatchNotes.PATCH_NOTES
	if entries.size() < 3:
		errors.append("PATCH_NOTES подозрительно мал (%d) — гейт прошёл бы вакуумно" % entries.size())
	var seen_versions := {}
	for entry in entries:
		var e: Dictionary = entry
		var ver := str(e.get("version", ""))
		if ver == "":
			errors.append("запись без version")
			continue
		if seen_versions.has(ver):
			errors.append("дублирующаяся version '%s'" % ver)
		seen_versions[ver] = true
		# Версия должна разбираться в semver-подобные части (хотя бы одна цифра).
		if not ver.split(".")[0].is_valid_int():
			errors.append("version '%s': первая часть не число" % ver)
		if str(e.get("date", "")).strip_edges() == "":
			errors.append("version '%s': пустая date" % ver)
		var highlights: Array = e.get("highlights", [])
		if highlights.is_empty():
			errors.append("version '%s': пустой highlights" % ver)
		for h in highlights:
			if not _player_text_ok(str(h)):
				errors.append("version '%s': негодный пункт highlights: '%s'" % [ver, str(h).left(40)])


# Порядок: новейшая версия первой, строго по убыванию (UX + entries_since).
func _check_ordering(errors: Array) -> void:
	var entries := PatchNotes.PATCH_NOTES
	for i in range(entries.size() - 1):
		var cur := str((entries[i] as Dictionary).get("version", ""))
		var nxt := str((entries[i + 1] as Dictionary).get("version", ""))
		if not PatchNotes._version_greater(cur, nxt):
			errors.append("порядок версий нарушен: '%s' не > '%s' (ожидался убывающий)" % [cur, nxt])


func _check_version_logic(errors: Array) -> void:
	# Числовое, НЕ лексикографическое сравнение (классический баг 0.2.10 vs 0.2.9).
	if not PatchNotes._version_greater("0.2.10", "0.2.9"):
		errors.append("_version_greater('0.2.10','0.2.9') должно быть true (числовое сравнение)")
	if PatchNotes._version_greater("0.2.9", "0.2.10"):
		errors.append("_version_greater('0.2.9','0.2.10') должно быть false")
	# Равные версии — не больше.
	if PatchNotes._version_greater("0.1.4", "0.1.4"):
		errors.append("_version_greater равных версий должно быть false")
	# Старшинство по minor: 0.2.0 является следующим релизом после 0.1.x.
	if not PatchNotes._version_greater("0.2.0", "0.1.7"):
		errors.append("_version_greater('0.2.0','0.1.7') должно быть true (minor старше)")
	# Нечисловые части трактуются как 0.
	if PatchNotes._version_greater("0.0.indev", "0.0.0"):
		errors.append("нечисловая patch-часть должна трактоваться как 0 (не > 0.0.0)")


func _check_query_logic(errors: Array) -> void:
	var entries := PatchNotes.PATCH_NOTES
	var latest := PatchNotes.latest_version()
	if latest != str((entries[0] as Dictionary).get("version", "")):
		errors.append("latest_version() != version первой записи ('%s')" % latest)
	# Всё новее «нулевой» версии — возвращаются все записи.
	if PatchNotes.entries_since("0.0.0").size() != entries.size():
		errors.append("entries_since('0.0.0') должно вернуть все %d записей" % entries.size())
	# Новее latest — пусто; has_new_since(latest) — false.
	if not PatchNotes.entries_since(latest).is_empty():
		errors.append("entries_since(latest) должно быть пусто")
	if PatchNotes.has_new_since(latest):
		errors.append("has_new_since(latest) должно быть false")
	# Игрок на старой версии видит новое.
	var oldest := str((entries[entries.size() - 1] as Dictionary).get("version", ""))
	if not PatchNotes.has_new_since(oldest) and entries.size() > 1:
		errors.append("has_new_since(самой старой) должно быть true при >1 записи")
	# entries_since(вторая запись) — ровно записи новее неё (минимум первая).
	if entries.size() >= 2:
		var second := str((entries[1] as Dictionary).get("version", ""))
		var since := PatchNotes.entries_since(second)
		if since.size() != 1:
			errors.append("entries_since(второй версии '%s') ожидалось 1 запись, получено %d" % [second, since.size()])
