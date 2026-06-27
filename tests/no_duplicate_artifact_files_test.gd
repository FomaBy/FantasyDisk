extends SceneTree

# Гигиена-гейт против случайных дублей-артефактов вида «<имя> 2.<ext>»
# (Finder «копия 2» / `cp file 'file 2.ext'`). В сессии 0.1.5 такая операция
# продублировала ~275 файлов дерева (SCRUM-267/270) + оставила 110 осиротевших
# сайдкаров с двойным расширением (`« 2.png.import»`, `« 2.gd.uid»`), которые
# regex первой чистки пропустил (SCRUM-269/271). Этот тест ловит ЛЮБОЙ такой
# дубль автоматически, чтобы класс не повторялся молча.
#
# Сигнатура дубля: в БАЗОВОМ имени файла встречается «пробел + 2 + точка»
# или «пробел + 2» в конце имени (« 2.png», « 2.png.import»,
# «.png 2.import», «.gdignore 2»). Легитимные имена
# таким паттерном не пользуются (версии — через `_`/`.`, не Finder suffix).
# На момент написания дерево чистое (0).
#
# Отдельный изолированный файл (только ЧИТАЕТ файловую систему).
# Запуск: Godot --headless --path . --script res://tests/no_duplicate_artifact_files_test.gd

# Локальный кэш/зависимости не сканируем. `build/` в целом сканируется: старые
# backup-папки уже становились переносчиком ` 2`-дубликатов. Release-staging app
# bundles/symlinks под `build/dmg` пропускаются отдельно, чтобы не обходить
# /Applications через mounted-DMG ссылку.
const SKIP_DIRS := [".godot", ".git", "tmp", "node_modules"]
const SKIP_PATH_PREFIXES := ["res://build/dmg"]

# « пробел + 2 + точка или конец имени » — сигнатура Finder/sync-дубля SCRUM-440.
const DUPE_PATTERN := " 2(\\.|$)"


func _initialize() -> void:
	var regex := RegEx.new()
	regex.compile(DUPE_PATTERN)
	var hits: Array = []
	var scanned := _walk("res://", regex, hits)
	# Анти-вакуум: тест должен реально обойти дерево.
	if scanned < 100:
		push_error("Duplicate-artifact guard: просканировано подозрительно мало файлов (%d) — обход дерева сломан?" % scanned)
		quit(1)
		return
	if not hits.is_empty():
		hits.sort()
		for h in hits:
			push_error("Дубль-артефакт: %s" % h)
		push_error("Duplicate-artifact guard: найдено %d дублей-артефактов « 2»/« 2.<ext>» (просканировано %d файлов). Проверить через `find . -path ./.git -prune -o \\( -name '* 2.*' -o -name '* 2' \\) -print`." % [hits.size(), scanned])
		quit(1)
		return
	print("Duplicate-artifact guard passed (просканировано %d файлов, дублей « 2»/« 2.<ext>» нет)." % scanned)
	quit(0)


# Рекурсивный обход; возвращает число просмотренных файлов, копит совпадения в hits.
func _walk(path: String, regex: RegEx, hits: Array) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			if regex.search(name) != null:
				hits.append(full)
			if _path_is_skipped(full):
				name = dir.get_next()
				continue
			if not SKIP_DIRS.has(name):
				count += _walk(full, regex, hits)
		else:
			count += 1
			if regex.search(name) != null:
				hits.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return count


func _path_is_skipped(path: String) -> bool:
	for prefix in SKIP_PATH_PREFIXES:
		if path == prefix or path.begins_with(prefix + "/"):
			return true
	return false
