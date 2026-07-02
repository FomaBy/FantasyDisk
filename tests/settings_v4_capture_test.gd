extends SceneTree

# SCRUM-805 Фаза 7 — runtime-скриншоты меню настроек v4 (evidence для QA).
# Захватывает 3 вкладки (Экран/Звук/Управление) на 1920×1080 и 2560×1440
# в SubViewport → PNG. Требует рендер-бэкенд (не --headless dummy).

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const VIEWPORT_SIZES := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
const TABS := {0: "display", 1: "sound", 2: "controls"}
const OUT_DIR := "res://build/qa/settings_v4"

var _errors: PackedStringArray = []


func _initialize() -> void:
	# Требует рендер-бэкенд: под --headless (dummy renderer) SubViewport-захват пуст.
	# Не валим headless-прогоны (как hero_select_scrum798_capture_test) — грациозный skip.
	if DisplayServer.get_name() == "headless":
		print("SETTINGS V4 CAPTURE SKIPPED: headless dummy renderer (run windowed for evidence)")
		quit(0)
		return
	var absolute_out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_out)
	var manifest := PackedStringArray()
	manifest.append("# SCRUM-805 settings v4 runtime capture manifest")
	manifest.append("")
	for viewport_size in VIEWPORT_SIZES:
		for tab_index in TABS:
			var path := await _capture_tab(viewport_size, tab_index, TABS[tab_index], absolute_out)
			manifest.append("- `%s` `%s`: `%s`" % [TABS[tab_index], str(viewport_size), path])
	var file := FileAccess.open("%s/manifest.md" % absolute_out, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(manifest))
		file.close()
	if not _errors.is_empty():
		for e in _errors:
			push_error(e)
		print("CAPTURE FAILED: %d errors" % _errors.size())
		quit(1)
		return
	print("SETTINGS V4 CAPTURE OK -> %s" % absolute_out)
	quit(0)


func _capture_tab(viewport_size: Vector2i, tab_index: int, tab_name: String, absolute_out: String) -> String:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	var main := MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	main.call("_show_settings_menu")
	await process_frame
	var tabs := main.find_child("SettingsTabs", true, false) as TabContainer
	if tabs != null:
		tabs.current_tab = tab_index
	else:
		_errors.append("%s %s: SettingsTabs not found" % [tab_name, str(viewport_size)])
	for _i in range(50):
		await process_frame
	var image := viewport.get_texture().get_image()
	var path := "%s/settings_%s_%dx%d.png" % [absolute_out, tab_name, viewport_size.x, viewport_size.y]
	if image == null:
		_errors.append("%s %s: viewport image unavailable" % [tab_name, str(viewport_size)])
		viewport.queue_free()
		await process_frame
		return ""
	# Проверка «не пустой кадр»: считаем небазовые пиксели.
	var non_blank := 0
	var step := 37
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var c := image.get_pixel(x, y)
			if c.a > 0.01 and (c.r > 0.03 or c.g > 0.03 or c.b > 0.03):
				non_blank += 1
	image.save_png(path)
	print("  %s %s: non_blank_samples=%d -> %s" % [tab_name, str(viewport_size), non_blank, path])
	if non_blank < 5:
		_errors.append("%s %s: frame appears blank (non_blank=%d) — no render backend?" % [tab_name, str(viewport_size), non_blank])
	viewport.queue_free()
	await process_frame
	return path
