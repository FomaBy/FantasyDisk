extends SceneTree

# Smoke-тест game_settings.gd (был непокрыт). Гейтит persистентность настроек:
# дефолты, round-trip, коэрцию/клэмп и — главное — восстановление SCRUM-172
# (сохранённый master_volume=0 мьютил весь звук; load_settings возвращает его в
# дефолт, ЕСЛИ нет явного master_zero_intent). Бэкапит/восстанавливает реальный
# user://settings.cfg, чтобы не затереть настройки разработчика.
#
# Запуск: Godot --headless --path . --script res://tests/game_settings_smoke_test.gd

const GameSettings := preload("res://scripts/game_settings.gd")
const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"


func _initialize() -> void:
	# --- Бэкап реального файла ---
	var had_original := FileAccess.file_exists(SAVE_PATH)
	var original_bytes := PackedByteArray()
	if had_original:
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			original_bytes = f.get_buffer(f.get_length())
			f.close()

	var errors: Array = []
	_run(errors)

	# --- Восстановление ---
	if had_original:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(original_bytes)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	if not errors.is_empty():
		for e in errors:
			push_error("Game settings smoke: %s" % e)
		push_error("Game settings smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Game settings smoke test passed (дефолты/round-trip/клэмп/SCRUM-172 recovery).")
	quit(0)


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# Пишет сырой config напрямую (для сценариев миграции, минуя save_settings).
func _write_raw(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SECTION, key, values[key])
	config.save(SAVE_PATH)


func _run(errors: Array) -> void:
	# 1) Нет файла -> дефолты.
	_clear()
	var s: Dictionary = GameSettings.load_settings()
	for key in GameSettings.DEFAULTS:
		if not s.has(key):
			errors.append("дефолт: ключ '%s' отсутствует" % key)
	if not is_equal_approx(float(s.get("master_volume", -1.0)), 1.0):
		errors.append("дефолт master_volume != 1.0 (%s)" % s.get("master_volume"))
	if bool(s.get("music_enabled", false)) != true:
		errors.append("дефолт music_enabled != true")

	# 2) Round-trip нормальных значений.
	_clear()
	GameSettings.save_settings({
		"resolution_index": 1, "window_mode_index": 1, "screen_index": 0,
		"master_volume": 0.7, "music_volume": 0.4, "sfx_volume": 0.9,
		"master_zero_intent": false, "music_enabled": false, "sfx_enabled": true,
		"screen_shake": false, "aim_mode": "cursor", "last_seen_version": "0.1.4", "input_bindings": {"jump": 32},
	})
	s = GameSettings.load_settings()
	if int(s["resolution_index"]) != 1 or int(s["window_mode_index"]) != 1:
		errors.append("round-trip индексов разрешения/режима не сохранился")
	if not is_equal_approx(float(s["master_volume"]), 0.7) or not is_equal_approx(float(s["music_volume"]), 0.4):
		errors.append("round-trip громкостей не сохранился (%s/%s)" % [s["master_volume"], s["music_volume"]])
	if bool(s["music_enabled"]) != false or bool(s["screen_shake"]) != false:
		errors.append("round-trip булевых флагов не сохранился")
	if str(s["aim_mode"]) != "cursor":
		errors.append("round-trip aim_mode не сохранился (%s)" % s["aim_mode"])
	if str(s["last_seen_version"]) != "0.1.4":
		errors.append("round-trip last_seen_version не сохранился (%s)" % s["last_seen_version"])
	if not (s["input_bindings"] is Dictionary) or int(s["input_bindings"].get("jump", -1)) != 32:
		errors.append("round-trip input_bindings не сохранился")

	# 3) Коэрция/клэмп: вне диапазона и неверные типы.
	_clear()
	_write_raw({
		"resolution_index": 3.0, "master_volume": 5.0, "music_volume": -2.0, "sfx_volume": 0.5,
		"music_enabled": true, "last_seen_version": 0.114, "input_bindings": "broken",
		"master_zero_intent": true,
	})
	s = GameSettings.load_settings()
	if typeof(s["resolution_index"]) != TYPE_INT or int(s["resolution_index"]) != 1:
		errors.append("коэрция/clamp resolution_index в allowed range не сработала (%s)" % [s["resolution_index"]])
	if float(s["master_volume"]) > 1.0 or float(s["music_volume"]) < 0.0:
		errors.append("клэмп громкостей в 0..1 не сработал (%s/%s)" % [s["master_volume"], s["music_volume"]])
	if typeof(s["last_seen_version"]) != TYPE_STRING:
		errors.append("коэрция last_seen_version в string не сработала (%s)" % typeof(s["last_seen_version"]))
	if not (s["input_bindings"] is Dictionary):
		errors.append("негодный input_bindings не сброшен в Dictionary")

	# 3b) aim_mode: неизвестное значение возвращается к безопасной автонаводке.
	_clear()
	_write_raw({"aim_mode": "broken"})
	s = GameSettings.load_settings()
	if str(s["aim_mode"]) != "nearest":
		errors.append("негодный aim_mode не сброшен в nearest (%s)" % s["aim_mode"])

	# 4) SCRUM-172 recovery: master_volume=0 без master_zero_intent -> возврат в дефолт.
	_clear()
	_write_raw({"master_volume": 0.0})  # ключа master_zero_intent НЕТ
	s = GameSettings.load_settings()
	if float(s["master_volume"]) <= 0.0:
		errors.append("SCRUM-172: master_volume=0 без intent не восстановлен в дефолт (%s) — звук остался бы замьючен" % s["master_volume"])
	if not is_equal_approx(float(s["master_volume"]), float(GameSettings.DEFAULTS["master_volume"])):
		errors.append("SCRUM-172: восстановленный master_volume != дефолт (%s)" % s["master_volume"])

	# 5) SCRUM-172 intent honored: master_volume=0 + master_zero_intent=true -> остаётся 0.
	_clear()
	_write_raw({"master_volume": 0.0, "master_zero_intent": true})
	s = GameSettings.load_settings()
	if float(s["master_volume"]) > 0.0:
		errors.append("SCRUM-172: явный master_zero_intent не сохранил тишину (master_volume=%s)" % s["master_volume"])

	# 6) save_settings выводит master_zero_intent из громкости, если ключа нет.
	_clear()
	GameSettings.save_settings({"master_volume": 0.0})  # без master_zero_intent
	var raw := ConfigFile.new()
	if raw.load(SAVE_PATH) == OK:
		if bool(raw.get_value(SECTION, "master_zero_intent", false)) != true:
			errors.append("save_settings не вывел master_zero_intent=true при master_volume=0")
	else:
		errors.append("save_settings не записал файл")

	_clear()
