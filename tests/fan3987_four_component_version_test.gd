extends SceneTree

# FAN-3987/FAN-3992: 0.3.1.2 is the four-component (technical hotfix) version
# that reaches players after 0.3.1; 0.3.1.1 was tagged but never published.
# Every place that consumes the version must treat 0.3.1.2 as newer than both
# 0.3.1 and 0.3.1.1: the updater ordering and manifest validation, the «Что
# нового» badge (entries_since/has_new_since) and the main-menu label.
#
# Запуск: Godot --headless --path . --script res://tests/fan3987_four_component_version_test.gd

const UPDATE_MANAGER := preload("res://scripts/update_manager.gd")
const PatchNotes := preload("res://scripts/patch_notes_data.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const HASH_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const HOTFIX := "0.3.1.2"
const UNPUBLISHED_HOTFIX := "0.3.1.1"

var _errors := PackedStringArray()


func _initialize() -> void:
	_check_updater_ordering()
	_check_hotfix_manifest()
	_check_whats_new_badge()
	await _check_main_menu_label()
	if not _errors.is_empty():
		for error in _errors:
			push_error("FAN-3987/FAN-3992: %s" % error)
		quit(1)
		return
	print("FAN-3987/FAN-3992 four-component version test passed (updater, whats-new badge, main-menu label).")
	quit(0)


func _check_updater_ordering() -> void:
	var cases := [
		["0.3.1", HOTFIX, -1],
		[HOTFIX, "0.3.1", 1],
		[UNPUBLISHED_HOTFIX, HOTFIX, -1],
		[HOTFIX, UNPUBLISHED_HOTFIX, 1],
		["0.3.1.0", "0.3.1", 0],
		[HOTFIX, HOTFIX, 0],
		[HOTFIX, "0.3.1.3", -1],
		[HOTFIX, "0.3.2", -1],
		["0.3.0.9", HOTFIX, -1],
	]
	for case in cases:
		var actual: int = UPDATE_MANAGER.compare_versions(case[0], case[1])
		if signi(actual) != int(case[2]):
			_errors.append("compare_versions(%s, %s) = %d, expected %d" % [case[0], case[1], actual, case[2]])


func _check_hotfix_manifest() -> void:
	# Same shape as build_update_manifest.py produces for a hotfix release.
	var release_base := "https://github.com/FomaBy/FantasyDisk-Releases/releases"
	var manifest := {
		"schema_version": UPDATE_MANAGER.MANIFEST_SCHEMA_VERSION,
		"version": HOTFIX,
		"minimum_supported_version": "0.2.2",
		"release_url": "%s/tag/v%s" % [release_base, HOTFIX],
		"assets": {
			"macos": {
				"name": "FantasyDisk-%s-macos.dmg" % HOTFIX,
				"url": "%s/download/v%s/FantasyDisk-%s-macos.dmg" % [release_base, HOTFIX, HOTFIX],
				"sha256": HASH_A,
				"size": 1024,
			},
			"windows": {
				"name": "FantasyDisk-%s-windows-setup.exe" % HOTFIX,
				"url": "%s/download/v%s/FantasyDisk-%s-windows-setup.exe" % [release_base, HOTFIX, HOTFIX],
				"sha256": HASH_A,
				"size": 1024,
			},
		},
	}
	var validation: Dictionary = UPDATE_MANAGER.validate_manifest(manifest)
	if not bool(validation.get("ok", false)):
		_errors.append("%s manifest rejected: %s" % [HOTFIX, str(validation)])
	# A 0.3.1 (or internal 0.3.1.1) install is offered 0.3.1.2; a 0.3.1.2
	# install is not re-offered it.
	for older in ["0.3.1", UNPUBLISHED_HOTFIX]:
		if UPDATE_MANAGER.compare_versions(older, str(manifest["version"])) >= 0:
			_errors.append("%s client would not see the %s update" % [older, HOTFIX])
	if UPDATE_MANAGER.compare_versions(HOTFIX, str(manifest["version"])) < 0:
		_errors.append("%s client would be re-offered its own version" % HOTFIX)


func _check_whats_new_badge() -> void:
	for older in ["0.3.1", UNPUBLISHED_HOTFIX]:
		if not PatchNotes._version_greater(HOTFIX, older):
			_errors.append("_version_greater(%s, %s) must be true" % [HOTFIX, older])
		if PatchNotes._version_greater(older, HOTFIX):
			_errors.append("_version_greater(%s, %s) must be false" % [older, HOTFIX])
	if PatchNotes._version_greater("0.3.1.0", "0.3.1"):
		_errors.append("0.3.1.0 must equal 0.3.1, not be newer")
	if not PatchNotes._version_greater("0.3.2", HOTFIX):
		_errors.append("_version_greater(0.3.2, %s) must be true" % HOTFIX)
	# 0.3.1.1 never reached players, so its note was folded into 0.3.1.2: a
	# player updating from 0.3.1 sees one entry, not two.
	var unpublished_entries := PatchNotes.PATCH_NOTES.filter(
		func(entry: Dictionary) -> bool: return str(entry.get("version", "")) == UNPUBLISHED_HOTFIX)
	if not unpublished_entries.is_empty():
		_errors.append("the unpublished %s patch-notes entry must be replaced by %s" % [UNPUBLISHED_HOTFIX, HOTFIX])
	# The whole path from an updated 0.3.1 install: the badge lights up for the
	# single 0.3.1.2 entry and goes out once that entry is seen.
	var hotfix_entries := PatchNotes.PATCH_NOTES.filter(
		func(entry: Dictionary) -> bool: return str(entry.get("version", "")) == HOTFIX)
	if hotfix_entries.size() != 1:
		_errors.append("expected exactly one %s patch-notes entry, got %d" % [HOTFIX, hotfix_entries.size()])
		return
	if not PatchNotes.has_new_since("0.3.1"):
		_errors.append("a player who saw 0.3.1 must get the new-version badge")
	var since := PatchNotes.entries_since("0.3.1")
	if since.size() != 1 or str((since[0] as Dictionary).get("version", "")) != HOTFIX:
		_errors.append("entries_since(0.3.1) must be exactly [%s], got %s" % [HOTFIX, str(since.map(
			func(entry: Dictionary) -> String: return str(entry.get("version", ""))))])
	if PatchNotes.has_new_since(HOTFIX):
		_errors.append("no badge once %s was seen" % HOTFIX)
	# The shipped build and its newest note must agree, or the badge never clears.
	var configured := str(ProjectSettings.get_setting("application/config/version", ""))
	if PatchNotes.latest_version() != configured:
		_errors.append("latest patch-notes version %s != project version %s" % [PatchNotes.latest_version(), configured])


func _check_main_menu_label() -> void:
	# Inject the four-component version so the label is proven for it regardless
	# of the version this checkout currently carries.
	var original: Variant = ProjectSettings.get_setting("application/config/version", "0.0.0")
	ProjectSettings.set_setting("application/config/version", HOTFIX)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.ui._show_main_menu()
	await process_frame
	var label := main.find_child("MainMenuVersionLabel", true, false) as Label
	if label == null:
		_errors.append("MainMenuVersionLabel not found")
	elif label.text != "v%s" % HOTFIX:
		_errors.append("main-menu label is '%s', expected 'v%s'" % [label.text, HOTFIX])
	main.queue_free()
	await process_frame
	ProjectSettings.set_setting("application/config/version", original)
