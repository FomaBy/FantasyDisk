extends SceneTree

# FAN-1080: лор игры — данные и экраны.
# 1) Целостность lore_data: интро-слайды, лор всех боссов/элиток/классов,
#    записи «Летописи» с существующими иконками, строки исхода забега.
# 2) Интро-экран истории: 4 слайда, «Далее»/«В путь», пропуск, финиш-колбек
#    (mark_seen=false — тест не трогает реальный settings.cfg).
# 3) Вкладка «Летопись» Кодекса: 7-я вкладка, записи, досье, спойлер-гард
#    Истока по secret_boss_defeated (meta_state подменяется в памяти).

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const MainCompileGuard := preload("res://tests/main_compile_guard.gd")
const LoreData := preload("res://scripts/lore_data.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")

var errors := PackedStringArray()


func _initialize() -> void:
	# FAN-1087: компиляция/инстанцирование Main — жёсткий гейт, не false-green.
	var gate_problems := MainCompileGuard.blocking_errors()
	if not gate_problems.is_empty():
		for problem in gate_problems:
			push_error("FAN-1087 main-dependency gate: %s" % problem)
		quit(1)
		return
	_check_data_integrity()
	await _check_intro_screen()
	await _check_codex_chronicle()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("FAN-1080 lore screens test passed.")
	quit(0)


func _check_data_integrity() -> void:
	var slides: Array = LoreData.intro_slides()
	if slides.size() != 4:
		errors.append("Intro: ожидалось 4 слайда, получено %d." % slides.size())
	for slide in slides:
		if str((slide as Dictionary).get("title", "")).strip_edges() == "" or str((slide as Dictionary).get("body", "")).strip_edges() == "":
			errors.append("Intro: слайд %s без заголовка/текста." % str((slide as Dictionary).get("id", "?")))

	# Каждый босс Кодекса обязан иметь doom (Летопись/досье) и intro (баннер).
	for monster in CodexData.monsters():
		var kind := str(monster.get("kind", ""))
		var monster_id := str(monster.get("id", ""))
		if kind == "boss":
			if LoreData.boss_doom_line(monster_id) == "" or LoreData.boss_intro_line(monster_id) == "":
				errors.append("Boss lore: %s без doom/intro строки." % monster_id)
		elif kind == "elite":
			if LoreData.elite_lore(monster_id) == "":
				errors.append("Elite lore: %s без строки офицера прибоя." % monster_id)
	# Секретный босс — отдельно (его нет в Кодексе до встречи).
	if LoreData.boss_doom_line("secret_ascension_boss") == "" or LoreData.boss_intro_line("secret_ascension_boss") == "":
		errors.append("Boss lore: secret_ascension_boss без doom/intro строки.")

	for character_id in ProgressionData.character_ids():
		if LoreData.class_origin(str(character_id)) == "":
			errors.append("Class origin: %s без осколка-мира." % str(character_id))

	var entries: Array = LoreData.chronicle_entries()
	if entries.size() < 6:
		errors.append("Chronicle: ожидалось >= 6 записей, получено %d." % entries.size())
	var seen_ids := {}
	var lords_found := false
	for entry_value in entries:
		var entry := entry_value as Dictionary
		var entry_id := str(entry.get("id", ""))
		if entry_id == "" or seen_ids.has(entry_id):
			errors.append("Chronicle: пустой или дублирующийся id '%s'." % entry_id)
		seen_ids[entry_id] = true
		if str(entry.get("title", "")).strip_edges() == "" or str(entry.get("summary", "")).strip_edges() == "":
			errors.append("Chronicle %s: пустой title/summary." % entry_id)
		var icon := str(entry.get("icon", ""))
		if icon == "" or not ResourceLoader.exists(icon):
			errors.append("Chronicle %s: иконка не найдена: '%s'." % [entry_id, icon])
		var has_lines := not (entry.get("lines", []) as Array).is_empty()
		if not has_lines and str(entry.get("sections", "")) != "intro_slides":
			errors.append("Chronicle %s: нет текста записи." % entry_id)
		if bool(entry.get("lords", false)):
			lords_found = true
	if not lords_found:
		errors.append("Chronicle: нет записи со списком Владык (lords).")

	if LoreData.victory_line(false) == "" or LoreData.victory_line(true) == "" or LoreData.defeat_line() == "":
		errors.append("Outcome lore: пустые строки победы/поражения.")
	if LoreData.victory_line(false) == LoreData.victory_line(true):
		errors.append("Outcome lore: варианты победы не различаются.")


func _check_intro_screen() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var slides: Array = LoreData.intro_slides()
	var finished := [false]
	main.ui._show_lore_intro(func() -> void: finished[0] = true, false)
	await process_frame

	if main.find_child("LoreIntroScreen", true, false) == null:
		errors.append("Intro UI: экран LoreIntroScreen не построился.")
		main.queue_free()
		await process_frame
		return
	var title := main.find_child("LoreIntroTitle", true, false) as Label
	var body := main.find_child("LoreIntroBody", true, false) as Label
	var progress := main.find_child("LoreIntroProgress", true, false) as Label
	var next_button := main.find_child("LoreIntroNextButton", true, false) as Button
	var skip_button := main.find_child("LoreIntroSkipButton", true, false) as Button
	if title == null or body == null or progress == null or next_button == null or skip_button == null:
		errors.append("Intro UI: нет обязательных узлов (title/body/progress/next/skip).")
		main.queue_free()
		await process_frame
		return
	for slide_index in range(slides.size()):
		var slide := slides[slide_index] as Dictionary
		if title.text != str(slide.get("title", "")):
			errors.append("Intro UI: слайд %d заголовок '%s' != '%s'." % [slide_index + 1, title.text, str(slide.get("title", ""))])
		if body.text != str(slide.get("body", "")):
			errors.append("Intro UI: слайд %d текст не совпадает с lore_data." % (slide_index + 1))
		if progress.text != "%d / %d" % [slide_index + 1, slides.size()]:
			errors.append("Intro UI: слайд %d прогресс '%s'." % [slide_index + 1, progress.text])
		var expected_button := "В путь" if slide_index == slides.size() - 1 else "Далее"
		if next_button.text != expected_button:
			errors.append("Intro UI: слайд %d кнопка '%s' != '%s'." % [slide_index + 1, next_button.text, expected_button])
		next_button.pressed.emit()
		await process_frame
	if not finished[0]:
		errors.append("Intro UI: «В путь» на последнем слайде не вызвал финиш-колбек.")

	# Пропуск: заново открыть и сразу пропустить.
	var skipped := [false]
	main.ui._show_lore_intro(func() -> void: skipped[0] = true, false)
	await process_frame
	var reopened_skip := main.find_child("LoreIntroSkipButton", true, false) as Button
	if reopened_skip == null:
		errors.append("Intro UI: повторное открытие не построило экран.")
	else:
		reopened_skip.pressed.emit()
		await process_frame
		if not skipped[0]:
			errors.append("Intro UI: «Пропустить» не вызвал финиш-колбек.")

	# Детерминированный байпас для смоуков: с force_skip интро не строится.
	main.set("force_skip_lore_intro", true)
	var bypassed := [false]
	main.ui._maybe_show_lore_intro(func() -> void: bypassed[0] = true)
	if not bypassed[0]:
		errors.append("Intro UI: force_skip_lore_intro не пропустил интро.")

	main.queue_free()
	await process_frame


func _check_codex_chronicle() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# Спойлер-гард: детерминированное «свежее» мета-состояние в памяти.
	main.set("meta_state", {"secret_boss_defeated": false})
	main.ui._show_codex_screen()
	await process_frame

	var chronicle_tab := main.find_child("CodexTab_chronicle", true, false) as Button
	if chronicle_tab == null:
		errors.append("Chronicle UI: нет вкладки CodexTab_chronicle.")
		main.queue_free()
		await process_frame
		return
	if chronicle_tab.text != "Летопись":
		errors.append("Chronicle UI: подпись вкладки '%s' != 'Летопись'." % chronicle_tab.text)
	chronicle_tab.pressed.emit()
	await process_frame
	await process_frame

	var entries: Array = LoreData.chronicle_entries()
	var list := main.find_child("CodexSectionList_chronicle", true, false) as VBoxContainer
	if list == null:
		errors.append("Chronicle UI: секция не построилась.")
		main.queue_free()
		await process_frame
		return
	if list.get_child_count() != entries.size():
		errors.append("Chronicle UI: %d карточек != %d записей." % [list.get_child_count(), entries.size()])

	# Первая запись — «Вступление» (пересмотр интро) в правом досье.
	var detail_title := main.find_child("CodexDetailTitle", true, false) as Label
	if detail_title == null or detail_title.text != str((entries[0] as Dictionary).get("title", "")):
		errors.append("Chronicle UI: досье по умолчанию не '%s'." % str((entries[0] as Dictionary).get("title", "")))

	# Запись Владык: есть «Вахта у кромки», Исток скрыт без победы.
	var lords_index := -1
	for entry_index in range(entries.size()):
		if bool((entries[entry_index] as Dictionary).get("lords", false)):
			lords_index = entry_index
			break
	if lords_index >= 0 and lords_index < list.get_child_count():
		var lords_card := list.get_child(lords_index) as Button
		lords_card.pressed.emit()
		await process_frame
		var detail_text := _collect_labels(main.find_child("CodexDetailTextBody", true, false))
		if not detail_text.contains("Вахта у кромки"):
			errors.append("Chronicle UI: в досье Владык нет секции «Вахта у кромки».")
		for monster in CodexData.monsters():
			if str(monster.get("kind", "")) == "boss" and not detail_text.contains(str(monster.get("title", ""))):
				errors.append("Chronicle UI: в вахте нет Владыки «%s»." % str(monster.get("title", "")))
		if detail_text.contains("Исток"):
			errors.append("Chronicle UI: спойлер Истока виден без победы над секретным боссом.")
	else:
		errors.append("Chronicle UI: не найдена карточка Владык.")

	# После победы над Истоком строка открывается (пересборка экрана).
	main.set("meta_state", {"secret_boss_defeated": true})
	main.ui._show_codex_screen()
	await process_frame
	var reopened_tab := main.find_child("CodexTab_chronicle", true, false) as Button
	reopened_tab.pressed.emit()
	await process_frame
	await process_frame
	var reopened_list := main.find_child("CodexSectionList_chronicle", true, false) as VBoxContainer
	if reopened_list != null and lords_index >= 0 and lords_index < reopened_list.get_child_count():
		(reopened_list.get_child(lords_index) as Button).pressed.emit()
		await process_frame
		var unlocked_text := _collect_labels(main.find_child("CodexDetailTextBody", true, false))
		if not unlocked_text.contains("Исток"):
			errors.append("Chronicle UI: после победы над секретным боссом строка Истока не открылась.")
	else:
		errors.append("Chronicle UI: пересборка секции Владык не удалась.")

	main.queue_free()
	await process_frame


func _collect_labels(node: Node) -> String:
	if node == null:
		return ""
	var pieces := PackedStringArray()
	if node is Label:
		pieces.append((node as Label).text)
	for child in node.get_children():
		pieces.append(_collect_labels(child))
	return "\n".join(pieces)
