extends SceneTree

# SCRUM-159 ч.1 (file-изолированный): целостность data-driven патч-ноутов и
# логики бейджа новой версии. Отдельный файл — runtime_smoke занят (анти-коллизия).

const PatchNotes := preload("res://scripts/patch_notes_data.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GameSettings := preload("res://scripts/game_settings.gd")


func _initialize() -> void:
	_test_data_integrity()
	_test_player_facing_text()
	_test_version_since_logic()
	_test_badge_persistence()
	await _test_screen_renders()
	print("Patch notes smoke test passed.")
	quit(0)


func _test_badge_persistence() -> void:
	# SCRUM-159 ч.3: last_seen_version в настройках — основа бейджа «Что нового».
	if not GameSettings.DEFAULTS.has("last_seen_version"):
		_fail("Expected game settings to persist last_seen_version.")
		return
	# Свежая установка (default) видит бейдж: есть записи новее.
	if not PatchNotes.has_new_since(str(GameSettings.DEFAULTS["last_seen_version"])):
		_fail("Expected fresh install (default last_seen_version) to show the new-version badge.")
		return
	# «Просмотрел» актуальную версию -> бейджа нет.
	if PatchNotes.has_new_since(PatchNotes.latest_version()):
		_fail("Expected no badge after seeing the latest version.")
		return


func _test_screen_renders() -> void:
	# Экран «Что нового» строит заголовки версий и буллеты из данных.
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.ui._show_patch_notes_screen()
	await process_frame
	if main.find_child("PatchNotesScreen", true, false) == null:
		_fail("Expected patch notes screen to open.")
		return
	if main.find_child("PatchNotesBackButton", true, false) == null:
		_fail("Expected a back button on patch notes screen.")
		return
	var version_labels: Array = main.find_children("PatchNotesVersion_*", "Label", true, false)
	if version_labels.size() != PatchNotes.all_entries().size():
		_fail("Expected %d version headers, got %d." % [PatchNotes.all_entries().size(), version_labels.size()])
		return
	# Хотя бы один буллет с текстом из данных присутствует.
	var first_line := str((PatchNotes.all_entries()[0]["highlights"] as Array)[0])
	var found := false
	for label in main.find_children("*", "Label", true, false):
		if str((label as Label).text).contains(first_line.substr(0, 12)):
			found = true
			break
	if not found:
		_fail("Expected patch notes screen to render highlight text.")
		return
	main.queue_free()
	await process_frame


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _test_data_integrity() -> void:
	var entries := PatchNotes.all_entries()
	if entries.size() < 5:
		_fail("Expected patch notes for at least 5 versions (0.1.0-0.1.4), got %d." % entries.size())
		return
	var seen := {}
	for entry in entries:
		var version := str((entry as Dictionary).get("version", ""))
		if version == "" or seen.has(version):
			_fail("Expected unique non-empty version per patch note entry.")
			return
		seen[version] = true
		var highlights: Array = (entry as Dictionary).get("highlights", [])
		if highlights.is_empty():
			_fail("Expected version %s to list highlights." % version)
			return
		for line in highlights:
			if str(line).strip_edges() == "":
				_fail("Expected non-empty highlight in %s." % version)
				return
	# Новейшая запись — версия проекта или новее (ретроспектива включает текущую).
	if PatchNotes.latest_version() == "0.0.0":
		_fail("Expected a latest version.")
		return


func _test_player_facing_text() -> void:
	# Только пользовательский русский текст: без внутренних ID/путей/токенов.
	var forbidden := ["res://", "_mult", "_flat", "UpgradeFab", "scripts/", ".gd", "::", "run_modifiers"]
	for entry in PatchNotes.all_entries():
		for line in (entry as Dictionary).get("highlights", []):
			var text := str(line)
			for token in forbidden:
				if text.contains(token):
					_fail("Patch note leaks internal token '%s' in %s." % [token, str((entry as Dictionary).get("version"))])
					return


func _test_version_since_logic() -> void:
	# Бейдж: после обновления записи новее last_seen видны; на актуальной — нет.
	if not PatchNotes.has_new_since("0.1.2"):
		_fail("Expected new entries since 0.1.2.")
		return
	if PatchNotes.entries_since("0.1.2").size() < 2:
		_fail("Expected at least 0.1.3 and 0.1.4 to be newer than 0.1.2.")
		return
	if PatchNotes.has_new_since(PatchNotes.latest_version()):
		_fail("Expected no new entries when already on the latest version.")
		return
	if PatchNotes.has_new_since("99.0.0"):
		_fail("Expected no entries newer than an impossibly high version.")
		return
