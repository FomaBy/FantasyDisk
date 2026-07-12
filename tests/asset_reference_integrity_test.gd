extends SceneTree

# Сплошной res://-reference-integrity тест: сканирует scripts/, scenes/ и .tres-ресурсы
# в assets/ на ЛИТЕРАЛЬНЫЕ res://-пути с расширением и проверяет, что каждый существует
# (ResourceLoader.exists или FileAccess.file_exists). content_registry_consistency
# покрывает только реестровые ассеты; этот тест ловит ЛЮБУЮ битую ссылку — safety-net
# для дедупа assets/ (SCRUM-418): если удаление снесёт всё ещё используемый ассет, гейт
# упадёт, а не игрок.
# SCRUM-723: добавлено сканирование .tres в assets/ — SpriteFrames/ресурсы ссылаются на
# текстуры-атласы через ext_resource path="res://..."; битая такая ссылка раньше не
# ловилась (тест читал только scripts/+scenes/), теперь ловится.
# Динамически собранные пути ("res://.../" + id) и format-строки (%s) намеренно
# пропускаются — извлекаем только полные пути-литералы. Сам тест assets/ не модифицирует.
#
# Запуск: Godot --headless --path . --script res://tests/asset_reference_integrity_test.gd

const SCAN_DIRS := ["res://scripts", "res://scenes", "res://assets"]
const SCAN_EXTS := ["gd", "tscn", "tres"]
const OPTIONAL_RUNTIME_CONFIGS := {
	"res://feedback_webhook.cfg": true,
}


func _initialize() -> void:
	var errors: Array = []
	var checked := {}
	var files_scanned := 0
	for dir in SCAN_DIRS:
		files_scanned += _scan_dir(dir, errors, checked)

	if not errors.is_empty():
		for e in errors:
			push_error("Asset reference integrity: %s" % e)
		push_error("Asset reference integrity test: %d битых ссылок." % errors.size())
		quit(1)
		return
	print("Asset reference integrity test passed (%d файлов, %d уникальных res://-ссылок)." % [
		files_scanned, checked.size(),
	])
	quit(0)


func _scan_dir(path: String, errors: Array, checked: Dictionary) -> int:
	var count := 0
	var d := DirAccess.open(path)
	if d == null:
		return 0
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name == "." or name == "..":
			name = d.get_next()
			continue
		var full := path.path_join(name)
		if d.current_is_dir():
			count += _scan_dir(full, errors, checked)
		else:
			var ext := name.get_extension()
			if SCAN_EXTS.has(ext):
				count += 1
				_scan_file(full, errors, checked)
		name = d.get_next()
	d.list_dir_end()
	return count


func _scan_file(file_path: String, errors: Array, checked: Dictionary) -> void:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	# Полный res://-путь до расширения: без кавычек/пробелов/скобок/% (исключает
	# динамическую конкатенацию и format-строки).
	var rx := RegEx.new()
	rx.compile("res://[^\"'\\s%(),\\]]+\\.[A-Za-z0-9]+")
	for m in rx.search_all(text):
		var res_path := m.get_string()
		if checked.has(res_path):
			continue
		checked[res_path] = true
		if OPTIONAL_RUNTIME_CONFIGS.has(res_path):
			continue
		# .uid-литералов в коде нет; .import как res:// тоже не грузят — но если кто-то
		# сослался, проверим как файл. Существование: ресурс ИЛИ файл на диске.
		if not (ResourceLoader.exists(res_path) or FileAccess.file_exists(res_path)):
			errors.append("%s: битая ссылка '%s'" % [file_path, res_path])
