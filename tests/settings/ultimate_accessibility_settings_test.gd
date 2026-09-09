extends SceneTree

## Covers the production persistence boundary. The test saves and restores the
## caller's settings.cfg because Main's real startup and save hooks are used.

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ACCESSIBILITY := preload("res://scripts/settings/ultimate_accessibility_settings.gd")
const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const COMBINATIONS: Array[Dictionary] = [
	{
		ACCESSIBILITY.REDUCED_MOTION_KEY: false,
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: false,
	},
	{
		ACCESSIBILITY.REDUCED_MOTION_KEY: true,
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: false,
	},
	{
		ACCESSIBILITY.REDUCED_MOTION_KEY: false,
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: true,
	},
	{
		ACCESSIBILITY.REDUCED_MOTION_KEY: true,
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: true,
	},
]


func _initialize() -> void:
	var backup := _backup_settings()
	var errors: Array[String] = []
	await _run(errors)
	_restore_settings(backup)
	if not errors.is_empty():
		for error in errors:
			push_error("Ultimate accessibility settings: %s" % error)
		quit(1)
		return
	print("Ultimate accessibility settings persistence/application test passed.")
	quit(0)


func _backup_settings() -> Dictionary:
	var backup := {"exists": FileAccess.file_exists(SAVE_PATH), "bytes": PackedByteArray()}
	if bool(backup["exists"]):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			backup["bytes"] = file.get_buffer(file.get_length())
			file.close()
	return backup


func _restore_settings(backup: Dictionary) -> void:
	if bool(backup.get("exists", false)):
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			var bytes: PackedByteArray = backup.get("bytes", PackedByteArray())
			file.store_buffer(bytes)
			file.close()
	else:
		_clear_settings()


func _clear_settings() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _write_raw(values: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SECTION, key, values[key])
	config.save(SAVE_PATH)


func _run(errors: Array[String]) -> void:
	_test_defaults_and_missing_keys(errors)
	_test_invalid_values(errors)
	for combination in COMBINATIONS:
		await _test_main_application_and_save(combination, errors)


func _test_defaults_and_missing_keys(errors: Array[String]) -> void:
	_clear_settings()
	if root.has_meta(ACCESSIBILITY.ROOT_METADATA_KEY):
		root.remove_meta(ACCESSIBILITY.ROOT_METADATA_KEY)
	_expect_snapshot(errors, GAME_SETTINGS.load_settings(), ACCESSIBILITY.default_snapshot(), "absent settings.cfg")
	_expect_snapshot(errors, ACCESSIBILITY.read_snapshot(root), ACCESSIBILITY.default_snapshot(), "absent root metadata")
	_write_raw({"master_volume": 0.8})
	_expect_snapshot(errors, GAME_SETTINGS.load_settings(), ACCESSIBILITY.default_snapshot(), "missing ultimate keys")


func _test_invalid_values(errors: Array[String]) -> void:
	_clear_settings()
	_write_raw({
		ACCESSIBILITY.REDUCED_MOTION_KEY: 1,
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: 0,
	})
	var loaded := GAME_SETTINGS.load_settings()
	_expect(errors, typeof(loaded.get(ACCESSIBILITY.REDUCED_MOTION_KEY)) == TYPE_BOOL,
		"reduced-motion invalid value was not normalized to bool")
	_expect(errors, typeof(loaded.get(ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY)) == TYPE_BOOL,
		"photosensitivity-safe invalid value was not normalized to bool")
	_expect_snapshot(errors, loaded, {
		ACCESSIBILITY.REDUCED_MOTION_KEY: true,
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: false,
	}, "numeric invalid values")


func _test_main_application_and_save(expected: Dictionary, errors: Array[String]) -> void:
	_clear_settings()
	var stored := GAME_SETTINGS.DEFAULTS.duplicate(true)
	for key in expected:
		stored[key] = expected[key]
	GAME_SETTINGS.save_settings(stored)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_expect_snapshot(errors, ACCESSIBILITY.read_snapshot(root), expected, "Main startup")

	var audio_settings: Dictionary = main.get("audio_settings")
	audio_settings["music_volume"] = 0.34
	main.set("audio_settings", audio_settings)
	main.set("selected_resolution_index", 1)
	main.set("selected_window_mode_index", 1)
	main.set("input_mode", "keyboard")
	main.set("gamepad_vibration", false)
	main.call("save_game_settings")
	var after_unrelated_save := GAME_SETTINGS.load_settings()
	_expect_snapshot(errors, after_unrelated_save, expected, "audio/display/input save")
	_expect(errors, is_equal_approx(float(after_unrelated_save.get("music_volume", -1.0)), 0.34),
		"audio change did not reach the normal Main save boundary")
	_expect(errors, int(after_unrelated_save.get("resolution_index", -1)) == 1,
		"display change did not reach the normal Main save boundary")
	_expect(errors, str(after_unrelated_save.get("input_mode", "")) == "keyboard",
		"input change did not reach the normal Main save boundary")

	var edited := {
		ACCESSIBILITY.REDUCED_MOTION_KEY: not bool(expected[ACCESSIBILITY.REDUCED_MOTION_KEY]),
		ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY: not bool(expected[ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY]),
	}
	_expect_snapshot(errors, ACCESSIBILITY.apply_snapshot(root, edited), edited, "intentional apply return")
	_expect_snapshot(errors, ACCESSIBILITY.read_snapshot(root), edited, "intentional apply read")
	main.call("save_game_settings")
	_expect_snapshot(errors, GAME_SETTINGS.load_settings(), edited, "intentional apply persistence")
	main.queue_free()
	await process_frame


func _expect_snapshot(errors: Array[String], actual: Dictionary, expected: Dictionary, label: String) -> void:
	for key in [ACCESSIBILITY.REDUCED_MOTION_KEY, ACCESSIBILITY.PHOTOSENSITIVITY_SAFE_KEY]:
		if not actual.has(key) or bool(actual[key]) != bool(expected[key]):
			errors.append("%s: %s=%s, expected %s" % [label, key, actual.get(key, "missing"), expected[key]])


func _expect(errors: Array[String], condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
