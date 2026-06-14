extends SceneTree

# Персистентность-гейт автосейва забега (SCRUM-349). Проверяет модуль
# scripts/run_autosave.gd: round-trip произвольного run-состояния, отсутствие
# файла, повреждённый файл, несовместимую схему, очистку и атомарность (нет
# остаточного .tmp после успешной записи). Отдельный изолированный файл, использует
# временный user://-путь и убирает его за собой.
#
# Запуск: Godot --headless --path . --script res://tests/run_autosave_persistence_test.gd

const RunAutosave := preload("res://scripts/run_autosave.gd")

const TEST_PATH := "user://test_run_autosave.cfg"


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	# 1. Отсутствие файла → пусто, has_run false, не крэшит.
	if not RunAutosave.load_run(TEST_PATH).is_empty():
		errors.append("load_run без файла должен быть {}")
	if RunAutosave.has_run(TEST_PATH):
		errors.append("has_run без файла должен быть false")

	# 2. Round-trip произвольного run-состояния (разные типы).
	var state := {
		"character_id": "berserk",
		"weapon_id": "sword",
		"route_stage": 3,
		"route_selected_indices": [0, 2, 1, 4],
		"current_shop_offers": {"slot_0": "artifact_x", "slot_1": "artifact_y"},
		"player_level": 7,
		"gold": 142.5,
	}
	if not RunAutosave.save_run(state, TEST_PATH):
		errors.append("save_run должен вернуть true")
	if not RunAutosave.has_run(TEST_PATH):
		errors.append("has_run после save должен быть true")
	var loaded := RunAutosave.load_run(TEST_PATH)
	for key in state.keys():
		if not loaded.has(key):
			errors.append("после load потерян ключ '%s'" % key)
		elif str(loaded[key]) != str(state[key]):
			errors.append("ключ '%s' не совпал: %s != %s" % [key, str(loaded[key]), str(state[key])])

	# 3. Атомарность: после успешной записи нет остаточного .tmp.
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH + ".tmp"):
		errors.append("остался .tmp после успешного save (не атомарно прибрано)")

	# 4. Перезапись: второй save заменяет состояние.
	if not RunAutosave.save_run({"character_id": "ranger", "route_stage": 1}, TEST_PATH):
		errors.append("повторный save_run должен вернуть true")
	var reloaded := RunAutosave.load_run(TEST_PATH)
	if str(reloaded.get("character_id", "")) != "ranger" or int(reloaded.get("route_stage", -1)) != 1:
		errors.append("перезапись save не применилась")
	if reloaded.has("weapon_id"):
		errors.append("перезапись должна была вытеснить старые ключи")

	# 5. Очистка → пусто.
	RunAutosave.clear_run(TEST_PATH)
	if RunAutosave.has_run(TEST_PATH):
		errors.append("после clear_run has_run должен быть false")

	# 6. Повреждённый файл → {} (как будто нет), не крэшит.
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("not a valid config file {{{ === ]]] garbage\nkey_without_section = broken [[[")
		f.close()
	if not RunAutosave.load_run(TEST_PATH).is_empty():
		errors.append("повреждённый файл должен дать {}")
	RunAutosave.clear_run(TEST_PATH)

	# 7. Несовместимая схема → {} (игнор).
	var bad := ConfigFile.new()
	bad.set_value("meta", "schema_version", RunAutosave.SCHEMA_VERSION + 999)
	bad.set_value("run", "character_id", "berserk")
	bad.save(TEST_PATH)
	if not RunAutosave.load_run(TEST_PATH).is_empty():
		errors.append("несовместимая схема должна дать {}")

	_cleanup()

	if not errors.is_empty():
		for e in errors:
			push_error("Run autosave persistence: %s" % e)
		push_error("Run autosave persistence: %d нарушений." % errors.size())
		quit(1)
		return
	print("Run autosave persistence passed (round-trip/atomic/corrupt/version/clear).")
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	for p in [TEST_PATH, TEST_PATH + ".tmp"]:
		if dir.file_exists(p):
			dir.remove(p)
