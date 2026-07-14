extends SceneTree

# FAN-1080: оконный визуальный капчер лор-экранов (не headless!).
# Сохраняет PNG в build/qa/fan1080_lore/ для глазной приёмки:
# интро (1-й и 4-й слайды), Летопись (список + досье Владык), баннер босса с
# лор-строкой, экраны победы/поражения с лорными строками.
# Реальный autosave игрока бэкапится и восстанавливается (victory/death его чистят).

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const LoreData := preload("res://scripts/lore_data.gd")
const QA_DIR := "res://build/qa/fan1080_lore"
const AUTOSAVE_PATH := "user://fantasydisk_autosave.cfg"
const CAPTURE_SIZE := Vector2i(2560, 1440)

var autosave_backup := ""
var had_autosave := false


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		# Не headless-тест: quality_gate авто-дискаверит tests/*.gd, поэтому в
		# headless капчер честно скипается зелёным (оконный прогон — вручную).
		print("FAN-1080 lore visual capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QA_DIR))
	_backup_autosave()

	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame

	# 1) Интро истории: слайды 1 и 4.
	var main = MAIN_SCENE.instantiate()
	viewport.add_child(main)
	await _settle(2)
	main.ui._show_lore_intro(func() -> void: pass, false)
	await _settle(3)
	await _capture(viewport, "01_intro_slide_1")
	var next_button := main.find_child("LoreIntroNextButton", true, false) as Button
	for _press in range(3):
		next_button.pressed.emit()
		await process_frame
	await _settle(2)
	await _capture(viewport, "02_intro_slide_4")

	# 2) Кодекс «Летопись»: список + досье по умолчанию, затем досье Владык.
	main.set("meta_state", {"secret_boss_defeated": false})
	main.ui._show_codex_screen()
	await _settle(2)
	var chronicle_tab := main.find_child("CodexTab_chronicle", true, false) as Button
	chronicle_tab.pressed.emit()
	await _settle(3)
	await _capture(viewport, "03_codex_chronicle_intro")
	var list := main.find_child("CodexSectionList_chronicle", true, false) as VBoxContainer
	var lords_index := 3
	var entries: Array = LoreData.chronicle_entries()
	for entry_index in range(entries.size()):
		if bool((entries[entry_index] as Dictionary).get("lords", false)):
			lords_index = entry_index
			break
	(list.get_child(lords_index) as Button).pressed.emit()
	await _settle(3)
	await _capture(viewport, "04_codex_chronicle_lords")

	# 3) Баннер босса с лор-подводкой (титул + строка под ним).
	main.ui._show_main_menu()
	await _settle(2)
	var hud := CanvasLayer.new()
	main.add_child(hud)
	main.set("hud_layer", hud)
	main.ui._show_combat_title_banner("Страж Разлома", Color(1.0, 0.34, 0.3), true, LoreData.boss_intro_line("rift_warden"))
	await _settle(0)
	await create_timer(0.6).timeout
	await _capture(viewport, "05_boss_banner_lore")
	await create_timer(2.6).timeout

	# 4) Победа и поражение с лорными строками.
	main.ui._show_victory_screen()
	await _settle(3)
	await _capture(viewport, "06_victory_seal_line")
	main.ui._show_death_screen()
	await _settle(3)
	await _capture(viewport, "07_defeat_line")

	_restore_autosave()
	print("FAN-1080 lore visual capture done -> %s" % QA_DIR)
	quit(0)


func _settle(frames: int) -> void:
	for _frame in range(maxi(1, frames)):
		await process_frame


func _capture(viewport: SubViewport, name: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("FAN-1080 capture: null image for %s" % name)
		return
	image.save_png("%s/%s.png" % [ProjectSettings.globalize_path(QA_DIR), name])


func _backup_autosave() -> void:
	had_autosave = FileAccess.file_exists(AUTOSAVE_PATH)
	if had_autosave:
		var file := FileAccess.open(AUTOSAVE_PATH, FileAccess.READ)
		if file != null:
			autosave_backup = file.get_as_text()
			file.close()


func _restore_autosave() -> void:
	if had_autosave:
		var file := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(autosave_backup)
			file.close()
