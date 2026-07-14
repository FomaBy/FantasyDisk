extends RefCounted
class_name RunAutosave

# Персистентность АКТИВНОГО забега (SCRUM-349): автосейв состояния прохождения в
# user://, чтобы при перезапуске предложить «Продолжить»/«Новая игра». Отдельный
# самодостаточный модуль — не зависит от main.gd/route/ui (интеграция вызывает
# save_run на завершении элемента карты, load_run/has_run на старте, clear_run при
# смерти/победе). Паттерн ConfigFile как у meta_progression.gd/game_settings.gd.
#
# Гарантии:
#   • схема версионируется (SCHEMA_VERSION) — несовместимый сейв игнорируется;
#   • replacement fail-safe: .tmp + .bak swap, backup читается после прерванной
#     замены; старый checkpoint не удаляется до готовности нового;
#   • повреждённый/отсутствующий/несовместимый сейв → load_run() == {} (как будто
#     сейва нет), без крэша;
#   • state — произвольный Dictionary run-состояния (character_id, route_stage,
#     route_selected_indices, current_shop_*, статы и т.д.); модуль к нему агностичен.

const DEFAULT_SAVE_PATH := "user://fantasydisk_autosave.cfg"
const SCHEMA_VERSION := 1
const META_SECTION := "meta"
const RUN_SECTION := "run"


# Атомарно сохранить произвольное run-состояние. Возвращает true при успехе.
static func save_run(state: Dictionary, save_path := DEFAULT_SAVE_PATH) -> bool:
	var config := ConfigFile.new()
	config.set_value(META_SECTION, "schema_version", SCHEMA_VERSION)
	for key in state.keys():
		config.set_value(RUN_SECTION, str(key), state[key])
	# Атомарность: сначала во временный файл, затем переименование поверх цели.
	var tmp_path := save_path + ".tmp"
	var err := config.save(tmp_path)
	if err != OK:
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	var backup_path := save_path + ".bak"
	# Recover an interrupted old→backup swap before attempting another save.
	if not dir.file_exists(save_path) and dir.file_exists(backup_path):
		if dir.rename(backup_path, save_path) != OK:
			_cleanup_file(dir, tmp_path)
			return false
	elif dir.file_exists(save_path) and dir.file_exists(backup_path):
		if dir.remove(backup_path) != OK:
			_cleanup_file(dir, tmp_path)
			return false

	var had_previous := dir.file_exists(save_path)
	if had_previous and dir.rename(save_path, backup_path) != OK:
		_cleanup_file(dir, tmp_path)
		return false
	if dir.rename(tmp_path, save_path) != OK:
		# Roll back the known-good checkpoint if new-file placement fails.
		if had_previous and dir.file_exists(backup_path):
			dir.rename(backup_path, save_path)
		_cleanup_file(dir, tmp_path)
		return false
	if had_previous:
		_cleanup_file(dir, backup_path)
	return true


# Загрузить run-состояние. {} если файла нет / повреждён / несовместимая схема.
static func load_run(save_path := DEFAULT_SAVE_PATH) -> Dictionary:
	var state := _load_run_path(save_path)
	if not state.is_empty():
		return state
	# If the process stopped between old→.bak and .tmp→target, the backup is the
	# last committed checkpoint and remains a valid resume source.
	return _load_run_path(save_path + ".bak")


static func _load_run_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var preview := file.get_as_text().strip_edges()
	file.close()
	if preview == "" or not preview.begins_with("["):
		return {}
	var config := ConfigFile.new()
	var err := config.load(path)
	if err != OK:
		return {}
	# Несовместимая/отсутствующая версия схемы — игнорируем сейв целиком.
	# SCRUM-650: строгий type-check вместо lossy int()-каста. int("001")==1,
	# int("1abc")==1, int("1.5")==1 ошибочно проходили валидацию повреждённого
	# сейва. Принимаем только настоящий int, равный текущей схеме.
	var schema_value: Variant = config.get_value(META_SECTION, "schema_version", null)
	if not (schema_value is int) or schema_value != SCHEMA_VERSION:
		return {}
	var state := {}
	if config.has_section(RUN_SECTION):
		for key in config.get_section_keys(RUN_SECTION):
			state[key] = config.get_value(RUN_SECTION, key)
	return state


# Есть ли валидный (загружаемый, совместимый) автосейв.
static func has_run(save_path := DEFAULT_SAVE_PATH) -> bool:
	return not load_run(save_path).is_empty()


# Удалить автосейв (завершение забега: смерть/победа), включая .tmp/.bak.
# Primary удаляется последним: при crash/error до последнего шага load_run()
# продолжит видеть committed checkpoint, а после него recovery-файлов уже нет.
static func clear_run(save_path := DEFAULT_SAVE_PATH) -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	for path in _clear_paths(save_path):
		if not _cleanup_file(dir, path):
			return false
	return true


static func _clear_paths(save_path: String) -> Array[String]:
	return [save_path + ".tmp", save_path + ".bak", save_path]


static func _cleanup_file(dir: DirAccess, path: String) -> bool:
	if dir.file_exists(path):
		return dir.remove(path) == OK
	return true
