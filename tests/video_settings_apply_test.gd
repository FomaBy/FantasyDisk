extends SceneTree

# SCRUM-557: интеграционный гейт UI-склейки видео-настроек поверх pure-геометрии
# (display_resolution_test.gd) и сырого персиста (game_settings_smoke_test.gd).
# Закрывает пробелы acceptance, не покрытые этими двумя:
#   (3) выбор разрешения/режима окна сохраняется и валиден при следующем запуске —
#       здесь проверяем, что headless-ветка _apply_video_settings() КЛЭМПИТ битый
#       индекс в допустимый диапазон и ПЕРСИСТИТ его (round-trip через settings.cfg);
#   (4) недоступные разрешения помечаются disabled — здесь проверяем, что список
#       UI-энтри (_settings_resolution_entries) ровно соответствует RESOLUTION_OPTIONS
#       и что решение «влезает» (та же DisplayResolution.resolution_fits, что и
#       set_item_disabled на call-site) корректно для маленького/Retina монитора.
# Бэкапит/восстанавливает реальный user://settings.cfg, чтобы не затереть настройки.
#
# Запуск: Godot --headless --path . --script res://tests/video_settings_apply_test.gd

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GameSettings := preload("res://scripts/game_settings.gd")
const DisplayResolution := preload("res://scripts/display_resolution.gd")
const SAVE_PATH := "user://settings.cfg"

# 14" MBP Retina: лог.usable ≈ 1512x982, scale 2.0 → физ 3024x1964 (всё влезает).
const MAC_LOGICAL := Vector2i(1512, 982)
const RETINA_SCALE := 2.0
# Маленький не-Retina монитор: оба разрешения списка больше экрана; runtime fallback всё равно хранит Full HD.
const SMALL_LOGICAL := Vector2i(1280, 720)


func _initialize() -> void:
	var had_original := FileAccess.file_exists(SAVE_PATH)
	var original_bytes := PackedByteArray()
	if had_original:
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			original_bytes = f.get_buffer(f.get_length())
			f.close()

	var errors: Array = []
	await _run(errors)

	if had_original:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(original_bytes)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	if not errors.is_empty():
		for e in errors:
			push_error("Video settings apply: %s" % e)
		push_error("Video settings apply test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Video settings apply test passed (entries/disable-decision/clamp+persist).")
	quit(0)


func _expect(errors: Array, cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func _run(errors: Array) -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui = main.ui
	_expect(errors, ui != null, "main.ui не инициализирован")
	if ui == null:
		main.queue_free()
		return

	_test_entries_match_options(main, ui, errors)
	_test_disable_decision(errors)
	_test_clamp_and_persist(main, ui, errors)

	main.queue_free()
	await process_frame


# (4) Список UI-энтри ровно соответствует RESOLUTION_OPTIONS с корректными подписями.
# Headless uses the same two allowed resolution entries as runtime.
func _test_entries_match_options(main, ui, errors: Array) -> void:
	var entries: Array = ui._settings_resolution_entries(Vector2i(99999, 99999))
	var options: Array = main.RESOLUTION_OPTIONS
	_expect(errors, entries.size() == options.size(),
		"энтри разрешений (%d) != RESOLUTION_OPTIONS (%d) на headless" % [entries.size(), options.size()])
	for i in range(mini(entries.size(), options.size())):
		var res: Vector2i = entries[i]["resolution"]
		var label: String = str(entries[i]["label"])
		_expect(errors, res == options[i],
			"энтри[%d].resolution=%s != RESOLUTION_OPTIONS[%d]=%s" % [i, res, i, options[i]])
		_expect(errors, label == "%dx%d" % [options[i].x, options[i].y],
			"энтри[%d].label='%s' не формата WxH" % [i, label])


# (4) Решение disabled = NOT resolution_fits — та же функция, что на call-site
# (ui_screens.gd:2718 set_item_disabled). Проверяем для маленького и Retina монитора.
func _test_disable_decision(errors: Array) -> void:
	var full_hd := Vector2i(1920, 1080)
	var k2 := Vector2i(2560, 1440)
	# Маленький не-Retina: legacy HD больше не является вариантом; Full HD/2K disabled.
	_expect(errors, not DisplayResolution.resolution_fits(full_hd, SMALL_LOGICAL, 1.0),
		"Full HD должно быть disabled на 1280x720 мониторе")
	_expect(errors, not DisplayResolution.resolution_fits(k2, SMALL_LOGICAL, 1.0),
		"2K должно быть disabled на 1280x720 мониторе")
	# Retina: всё из списка доступно (НЕ disabled).
	for res in [full_hd, k2]:
		_expect(errors, DisplayResolution.resolution_fits(res, MAC_LOGICAL, RETINA_SCALE),
			"%s должно быть доступно (НЕ disabled) на Retina" % res)


# (3) headless _apply_video_settings КЛЭМПИТ битый индекс и ПЕРСИСТИТ выбор;
# load_settings возвращает валидный индекс при следующем запуске.
func _test_clamp_and_persist(main, ui, errors: Array) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var max_res: int = main.RESOLUTION_OPTIONS.size() - 1
	var max_mode: int = main.WINDOW_MODE_OPTIONS.size() - 1

	# Битые (out-of-range) индексы → клэмп в диапазон + персист.
	main.selected_resolution_index = 999
	main.selected_window_mode_index = -5
	ui._apply_video_settings()
	_expect(errors, main.selected_resolution_index == max_res,
		"selected_resolution_index не склэмпан в %d (получено %d)" % [max_res, main.selected_resolution_index])
	_expect(errors, main.selected_window_mode_index == 0,
		"selected_window_mode_index не склэмпан в 0 (получено %d)" % main.selected_window_mode_index)
	var s1: Dictionary = GameSettings.load_settings()
	_expect(errors, int(s1["resolution_index"]) == max_res,
		"персист: resolution_index=%s != %d" % [s1["resolution_index"], max_res])
	_expect(errors, int(s1["window_mode_index"]) == 0,
		"персист: window_mode_index=%s != 0" % s1["window_mode_index"])

	# Валидный выбор (2K-индекс, режим «без рамки») round-trip-ит как есть.
	main.selected_resolution_index = 0
	main.selected_window_mode_index = max_mode
	ui._apply_video_settings()
	var s2: Dictionary = GameSettings.load_settings()
	_expect(errors, int(s2["resolution_index"]) == 0 and int(s2["window_mode_index"]) == max_mode,
		"персист валидного выбора (res=%d/mode=%d) не сохранился (%s/%s)" % [
			0, max_mode, s2["resolution_index"], s2["window_mode_index"]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
