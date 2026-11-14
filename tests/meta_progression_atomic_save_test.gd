extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const Main := preload("res://scripts/main.gd")

var errors: Array[String] = []
var test_root := ""
var old_bytes := ""
var new_bytes := ""
var old_state: Dictionary = {}
var new_state: Dictionary = {}


func _initialize() -> void:
	var scratch := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			scratch = argument.trim_prefix("--user-data-dir=").simplify_path()
	if scratch.is_empty() or scratch == "/" or not OS.get_user_data_dir().simplify_path().begins_with(scratch + "/"):
		push_error("Atomic meta tests require an explicit scratch --user-data-dir and isolated HOME/platform data directories.")
		quit(1)
		return
	test_root = OS.get_user_data_dir().path_join("meta_atomic_matrix")
	_check(DirAccess.make_dir_recursive_absolute(test_root) == OK, "create test root")
	_prepare_profiles()
	_test_legacy_profile()
	_test_roundtrip()
	_test_damage()
	_test_unique_quarantine()
	_test_interruptions()
	_test_failures()
	_test_quarantine_failure()
	_test_main_bridge()
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("Meta atomic save passed: roundtrip, backup rotation, damage recovery, unique quarantine, interruption matrix, failures and main memory.")
	quit(0)


func _prepare_profiles() -> void:
	var path := _path("profiles")
	var state := Meta.default_state()
	state["ascension_levels"] = {"berserk": 3, "guitarist": 2}
	state["class_boss_wins"] = {"berserk": 7, "guitarist": 4}
	state["meta_point_awards"] = {"berserk": [0, 1, 2], "guitarist": [0, 1]}
	state["skill_nodes"] = ["atlas_m0"]
	state["achievements"] = ["first_boss_win"]
	state["discovered_monsters"] = ["ash_marksman"]
	_check(Meta.save_state(state, path), "save fixture")
	old_bytes = FileAccess.get_file_as_string(path)
	old_state = Meta.load_state(path)
	state = old_state.duplicate(true)
	state["class_boss_wins"]["berserk"] = 8
	_check(Meta.save_state(state, path), "save newer fixture")
	new_bytes = FileAccess.get_file_as_string(path)
	new_state = Meta.load_state(path)
	_check(old_state != Meta.default_state() and old_state != new_state, "fixtures contain distinct nonempty progress")


func _test_roundtrip() -> void:
	var path := _path("roundtrip")
	_check(Meta.load_state(path) == Meta.default_state(), "missing profile defaults")
	_check(not FileAccess.file_exists(path + ".corrupt"), "missing file is not corruption")
	_check(Meta.save_state(old_state.duplicate(true), path), "first save succeeds")
	_check(Meta.load_state(path) == old_state, "first save roundtrip")
	_check(not FileAccess.file_exists(path + ".bak"), "first save has no previous generation")
	_check(Meta.save_state(new_state.duplicate(true), path), "overwrite succeeds")
	_check(Meta.load_state(path) == new_state, "overwrite roundtrip")
	_check(FileAccess.get_file_as_string(path + ".bak") == old_bytes, "backup retains exact previous bytes")
	_check(not FileAccess.file_exists(path + ".tmp"), "successful swap consumes temporary file")
	_check(Meta.save_state(old_state.duplicate(true), path), "third save succeeds")
	_check(FileAccess.get_file_as_string(path + ".bak") == new_bytes, "backup rotates to last good generation")
	var config := ConfigFile.new()
	_check(config.load(path) == OK, "serialized profile parses")
	_check(config.get_value("meta", "skill_tree_schema") == 6, "schema remains 6")
	_check(config.get_sections() == PackedStringArray(["meta"]), "no new sections")


func _test_legacy_profile() -> void:
	# Generated with the 0.3.1.2 / 9a19870a loader and writer, including its
	# existing purchase ordering and normalization. No owner profile is used.
	var bytes := FileAccess.get_file_as_string("res://tests/fixtures/meta_atomic/legacy_0_3_1_2.cfg")
	var expected: Variant = str_to_var(FileAccess.get_file_as_string("res://tests/fixtures/meta_atomic/legacy_0_3_1_2_expected.txt"))
	_check(expected is Dictionary, "legacy expected state parses")
	var path := _path("legacy")
	_write(path, bytes)
	_check(Meta.load_state(path) == expected, "0.3.1.2 profile loads with identical full state")
	_check(FileAccess.get_file_as_string(path) == bytes, "healthy legacy load leaves bytes intact")


func _test_damage() -> void:
	# Cut inside a value: syntactically valid legacy files may omit keys.
	var truncated := old_bytes.substr(0, old_bytes.find("class_boss_wins={") + "class_boss_wins={".length())
	var damages := ["", truncated, "non-config bytes", "[other]\nkey=1\n"]
	for index in range(damages.size()):
		for has_backup in [true, false]:
			var context := "damage_%d_backup_%s" % [index, has_backup]
			var path := _path(context)
			_write(path, damages[index])
			if has_backup:
				_write(path + ".bak", old_bytes)
			var expected := old_state if has_backup else Meta.default_state()
			var recovered := Meta.load_state(path)
			_check(recovered == expected, context + " recovery/defaults")
			_check(FileAccess.file_exists(path + ".corrupt"), context + " preserves file including zero bytes")
			_check(FileAccess.get_file_as_string(path + ".corrupt") == damages[index], context + " preserves exact bytes")
			_check(Meta.save_state(recovered, path), context + " next save succeeds")
			_check(Meta.load_state(path) == expected, context + " next save retains state")
			_check(FileAccess.get_file_as_string(path + ".corrupt") == damages[index], context + " damage survives next save")
			if has_backup:
				_check(FileAccess.get_file_as_string(path + ".bak") == old_bytes, context + " backup never replaced by damage")


func _test_unique_quarantine() -> void:
	var path := _path("unique")
	_write(path + ".corrupt", "first")
	_write(path + ".corrupt.1", "second")
	_write(path, "third")
	_write(path + ".bak", "bad backup")
	_check(Meta.load_state(path) == Meta.default_state(), "both files damaged defaults")
	_check(FileAccess.get_file_as_string(path + ".corrupt") == "first", "first corrupt copy unchanged")
	_check(FileAccess.get_file_as_string(path + ".corrupt.1") == "second", "second corrupt copy unchanged")
	_check(FileAccess.get_file_as_string(path + ".corrupt.2") == "third", "third corrupt copy distinct")
	_check(FileAccess.get_file_as_string(path + ".bak.corrupt") == "bad backup", "bad backup preserved too")
	_write(path, "fourth")
	_check(Meta.save_state(old_state.duplicate(true), path), "direct save quarantines without load")
	_check(FileAccess.get_file_as_string(path + ".corrupt.3") == "fourth", "direct save preserves damage")
	_check(Meta.load_state(path) == old_state, "direct save writes progress")


func _test_interruptions() -> void:
	# Every boundary of temporary write/verification, stale-backup removal,
	# primary-to-backup and temporary-to-primary, including the initial save.
	var cases := [
		["writing_tmp", old_bytes, new_bytes, "[meta]\nx={", old_state],
		["verified_tmp", old_bytes, new_bytes, new_bytes, old_state],
		["removed_backup", old_bytes, null, new_bytes, old_state],
		["moved_to_backup", null, old_bytes, new_bytes, old_state],
		["placed_primary", new_bytes, old_bytes, null, new_state],
		["backup_only", null, old_bytes, null, old_state],
		["first_save_tmp", null, null, new_bytes, new_state],
		["bad_primary", "", old_bytes, new_bytes, old_state],
		["bad_backup", null, "", new_bytes, new_state],
	]
	for fixture in cases:
		var context := str(fixture[0])
		var path := _path(context)
		var suffixes := ["", ".bak", ".tmp"]
		for index in range(3):
			if fixture[index + 1] != null:
				_write(path + str(suffixes[index]), str(fixture[index + 1]))
		var recovered := Meta.load_state(path)
		_check(recovered == fixture[4], context + " chooses committed state or sole pending initial save")
		_check(Meta.save_state(recovered, path), context + " next save succeeds")
		_check(Meta.load_state(path) == fixture[4], context + " next save preserves progress")
		_check(Meta.load_state(path + ".bak") == fixture[4], context + " retains good backup")


func _test_failures() -> void:
	_check(not Meta.save_state(old_state.duplicate(true), test_root.path_join("missing/profile.cfg")), "missing parent reports failure")
	var path := _path("blocked_tmp")
	_write(path, old_bytes)
	_write(path + ".bak", new_bytes)
	_check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "create temp blocker")
	_check(not Meta.save_state(new_state.duplicate(true), path), "temp write failure observable")
	_check(FileAccess.get_file_as_string(path) == old_bytes, "failed write preserves primary")
	_check(FileAccess.get_file_as_string(path + ".bak") == new_bytes, "failed write preserves backup")
	path = _path("blocked_rotation")
	_write(path, old_bytes)
	_check(DirAccess.make_dir_absolute(path + ".bak") == OK, "create rotation blocker")
	_check(not Meta.save_state(new_state.duplicate(true), path), "rotation failure observable")
	_check(FileAccess.get_file_as_string(path) == old_bytes, "failed rotation preserves primary")
	_check(Meta.load_state(path) == old_state, "failed rotation reloads progress")
	path = _path("blocked_primary")
	_check(DirAccess.make_dir_absolute(path) == OK, "create primary blocker")
	_write(path + ".bak", old_bytes)
	_check(not Meta.save_state(new_state.duplicate(true), path), "restore failure observable")
	_check(FileAccess.get_file_as_string(path + ".bak") == old_bytes, "failed restore preserves backup")


func _test_quarantine_failure() -> void:
	if OS.get_name() == "Windows":
		print("Unix quarantine-permission fixture skipped on Windows; native file-lock verification is separate.")
		return
	var folder := test_root.path_join("locked_parent")
	_check(DirAccess.make_dir_absolute(folder) == OK, "create quarantine permission fixture")
	var path := folder.path_join("profile.cfg")
	_write(path, "damage must survive")
	# Native macOS/Linux permission failure; restore access before asserting.
	var locked := FileAccess.set_unix_permissions(folder, 0x16d) == OK  # 0555
	var saved := Meta.save_state(old_state.duplicate(true), path) if locked else true
	var restored := FileAccess.set_unix_permissions(folder, 0x1ed) == OK  # 0755
	_check(locked and restored, "set and restore quarantine fixture permissions")
	_check(not saved, "failed quarantine refuses replacement")
	_check(FileAccess.get_file_as_string(path) == "damage must survive", "failed quarantine preserves original bytes")
	_check(Meta.save_state(old_state.duplicate(true), path), "save retries after quarantine permissions recover")
	_check(FileAccess.get_file_as_string(path + ".corrupt") == "damage must survive", "retry preserves damaged bytes")


func _test_main_bridge() -> void:
	var main := Main.new()
	main.meta_save_path = test_root.path_join("missing/main.cfg")
	main.meta_state = old_state.duplicate(true)
	_check(not main.save_meta_progression(), "main exposes failure")
	_check(main.meta_state == old_state, "main retains in-memory progress")
	_check(main._meta_save_failure_logged, "main logs once")
	_check(not main.save_meta_progression(), "main repeat failure observable")
	main.meta_save_path = _path("main_recovered")
	_check(main.save_meta_progression(), "main retries after failure")
	_check(Meta.load_state(main.meta_save_path) == old_state, "main retry preserves progress")
	main.ui = null
	main.route = null
	main.combat = null
	main.combat_world_pause.free()
	main.free()


func _path(name: String) -> String:
	return test_root.path_join(name + ".cfg")


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "fixture opens: " + path)
	if file != null:
		file.store_string(content)
		file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
