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
#   • запись атомарна (пишем в .tmp, затем rename) — не бьётся при крэше середины;
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
	if dir.file_exists(save_path):
		dir.remove(save_path)
	if dir.rename(tmp_path, save_path) != OK:
		# rename не удался — подчистим временный файл, чтобы не копить мусор.
		if dir.file_exists(tmp_path):
			dir.remove(tmp_path)
		return false
	return true


# Загрузить run-состояние. {} если файла нет / повреждён / несовместимая схема.
static func load_run(save_path := DEFAULT_SAVE_PATH) -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(save_path)
	if err != OK:
		return {}
	# Несовместимая/отсутствующая версия схемы — игнорируем сейв целиком.
	if int(config.get_value(META_SECTION, "schema_version", -1)) != SCHEMA_VERSION:
		return {}
	var state := {}
	if config.has_section(RUN_SECTION):
		for key in config.get_section_keys(RUN_SECTION):
			state[key] = config.get_value(RUN_SECTION, key)
	return state


# Есть ли валидный (загружаемый, совместимый) автосейв.
static func has_run(save_path := DEFAULT_SAVE_PATH) -> bool:
	return not load_run(save_path).is_empty()


# Удалить автосейв (завершение забега: смерть/победа), включая возможный .tmp.
static func clear_run(save_path := DEFAULT_SAVE_PATH) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(save_path):
		dir.remove(save_path)
	var tmp_path := save_path + ".tmp"
	if dir.file_exists(tmp_path):
		dir.remove(tmp_path)
