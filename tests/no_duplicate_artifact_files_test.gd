extends SceneTree

# Гигиена-гейт против случайных дублей-артефактов вида «<имя> N.<ext>»
# (Finder «копия 2» / `cp file 'file 2.ext'`). В сессии 0.1.5 такая операция
# продублировала ~275 файлов дерева (SCRUM-267/270) + оставила 110 осиротевших
# сайдкаров с двойным расширением (`« 2.png.import»`, `« 2.gd.uid»`), которые
# regex первой чистки пропустил (SCRUM-269/271). Этот тест ловит ЛЮБОЙ такой
# дубль автоматически, чтобы класс не повторялся молча.
#
# Сигнатура дубля: в БАЗОВОМ имени файла встречается «пробел + цифры + точка +
# буква» (« 2.png», « 3.gd», « 2.png.import», « 2.gd.uid»). Легитимные имена
# таким паттерном не пользуются (версии — через `_`/`.`, не « N.»; даты/скобки —
# цифра не после пробела перед точкой). На момент написания дерево чистое (0).
#
# Отдельный изолированный файл (только ЧИТАЕТ файловую систему).
# Запуск: Godot --headless --path . --script res://tests/no_duplicate_artifact_files_test.gd

# Сгенерированные/скретч-каталоги — не сорсы, не сканируем.
const SKIP_DIRS := [".godot", ".git", "build", "tmp", "node_modules"]

# « пробел + 1+ цифра + точка + буква » — сигнатура « N.ext».
const DUPE_PATTERN := " [0-9]+\\.[a-z]"


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
		push_error("Duplicate-artifact guard: найдено %d дублей-артефактов « N.<ext>» (просканировано %d файлов). Снести через `git ls-files | grep -E ' [0-9]+\\.'`." % [hits.size(), scanned])
		quit(1)
		return
	print("Duplicate-artifact guard passed (просканировано %d файлов, дублей « N.<ext>» нет)." % scanned)
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
			if not SKIP_DIRS.has(name):
				count += _walk(full, regex, hits)
		else:
			count += 1
			if regex.search(name) != null:
				hits.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return count
