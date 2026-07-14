extends RefCounted

# FAN-1087: fail-fast гейт для фокусных тестов, которые preload'ят Main.tscn.
# PackedScene загружается даже когда его скрипты не компилируются, поэтому без
# явной проверки тест продолжал работу на «пустом» Main, глотал runtime-ошибки
# и завершался exit 0 (false-green). Хелпер — RefCounted, а не SceneTree:
# quality_gate discovery берёт из tests/ только `extends SceneTree`.

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const DEPENDENCY_SCRIPT_PATHS := [
	"res://scripts/main.gd",
	"res://scripts/ui_screens.gd",
]


# Пустой список — Main готов к инстанцированию; иначе список причин для quit(1).
static func blocking_errors() -> PackedStringArray:
	var problems := PackedStringArray()
	for path in DEPENDENCY_SCRIPT_PATHS:
		var script := load(path) as Script
		if script == null:
			problems.append("%s: скрипт не загрузился (parse/compile error)." % path)
		elif not script.can_instantiate():
			problems.append("%s: скрипт не компилируется (failed depended scripts)." % path)
	if not problems.is_empty():
		return problems

	var scene := load(MAIN_SCENE_PATH) as PackedScene
	if scene == null or not scene.can_instantiate():
		problems.append("%s: PackedScene не готов к инстанцированию." % MAIN_SCENE_PATH)
		return problems
	var main := scene.instantiate()
	if main == null:
		problems.append("%s: instantiate() вернул null." % MAIN_SCENE_PATH)
		return problems
	if main.get_script() == null:
		problems.append("Main: у корня нет скрипта — main.gd не скомпилировался.")
	elif main.get("ui") == null or main.get("route") == null or main.get("combat") == null:
		problems.append("Main._init: ui/route/combat == null — зависимость Main не инстанцировалась.")
	main.free()
	return problems
