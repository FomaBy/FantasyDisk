extends SceneTree

# SCRUM-621: focused gate for persistent Codex discovery tracking.

const Meta := preload("res://scripts/meta_progression.gd")

const TEST_PATH := "user://test_codex_unlock_tracking.cfg"


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	var state := Meta.default_state()
	state = Meta.record_codex_discovery(state, "monsters", "rift_cutter")
	state = Meta.record_codex_discovery(state, "monsters", "rift_cutter")
	state = Meta.record_codex_discovery(state, "monsters", "bone_caller")
	state = Meta.record_codex_discovery(state, "bosses", "ashen_colossus")
	state = Meta.record_codex_discovery(state, "artifacts", "rift_key")
	state = Meta.record_codex_discovery(state, "artifacts", "")
	state = Meta.record_codex_discovery(state, "monsters", "fake_monster")
	state = Meta.record_codex_discovery(state, "bosses", "fake_boss")
	state = Meta.record_codex_discovery(state, "artifacts", "fake_artifact")
	state = Meta.record_codex_discovery(state, "unknown", "ignored")

	_expect_ids(errors, state, "monsters", ["rift_cutter", "bone_caller"])
	_expect_ids(errors, state, "bosses", ["ashen_colossus"])
	_expect_ids(errors, state, "artifacts", ["rift_key"])
	_expect_unread_ids(errors, state, "monsters", ["rift_cutter", "bone_caller"])
	_expect_unread_ids(errors, state, "bosses", ["ashen_colossus"])
	_expect_unread_ids(errors, state, "artifacts", ["rift_key"])
	if Meta.is_codex_discovered(state, "unknown", "ignored"):
		errors.append("unknown category must not record discovery")
	state = Meta.record_codex_discovery(state, "characters", "berserk")
	state = Meta.record_codex_discovery(state, "weapons", Meta.codex_weapon_id("berserk", "axe"))
	state = Meta.record_codex_discovery(state, "weapons", Meta.codex_weapon_id("berserk", "axe"))
	state = Meta.record_codex_unread(state, "characters", "fake_character")
	state = Meta.record_codex_unread(state, "weapons", "berserk/fake_weapon")
	_expect_unread_ids(errors, state, "characters", ["berserk"])
	_expect_unread_ids(errors, state, "weapons", ["berserk/axe"])
	_expect_ids(errors, state, "characters", ["berserk"])
	_expect_ids(errors, state, "weapons", ["berserk/axe"])
	if not Meta.has_codex_unread(state, ["characters", "weapons"]):
		errors.append("character/weapon unread aggregate lookup failed")

	Meta.save_state(state, TEST_PATH)
	var loaded := Meta.load_state(TEST_PATH)
	_expect_ids(errors, loaded, "monsters", ["rift_cutter", "bone_caller"])
	_expect_ids(errors, loaded, "bosses", ["ashen_colossus"])
	_expect_ids(errors, loaded, "artifacts", ["rift_key"])
	_expect_unread_ids(errors, loaded, "characters", ["berserk"])
	_expect_unread_ids(errors, loaded, "weapons", ["berserk/axe"])
	_expect_ids(errors, loaded, "characters", ["berserk"])
	_expect_ids(errors, loaded, "weapons", ["berserk/axe"])
	if not Meta.is_codex_discovered(loaded, "bosses", "ashen_colossus"):
		errors.append("loaded boss discovery lookup failed")
	loaded = Meta.mark_codex_read(loaded, "characters", "berserk")
	loaded = Meta.mark_codex_read(loaded, "weapons", "berserk/axe")
	loaded = Meta.record_codex_discovery(loaded, "characters", "berserk")
	loaded = Meta.record_codex_discovery(loaded, "weapons", "berserk/axe")
	if Meta.has_codex_unread(loaded, ["characters", "weapons"]):
		errors.append("read character/weapon entries became unread again")
	loaded = Meta.mark_codex_read(loaded, "monsters", "rift_cutter")
	_expect_ids(errors, loaded, "monsters", ["rift_cutter", "bone_caller"])
	_expect_unread_ids(errors, loaded, "monsters", ["bone_caller"])

	var config := ConfigFile.new()
	config.set_value("meta", "discovered_monsters", ["rift_cutter", "rift_cutter", "", "  bone_caller  ", "fake_monster"])
	config.set_value("meta", "discovered_bosses", "not-array")
	config.set_value("meta", "discovered_artifacts", ["rift_key", "fake_artifact"])
	config.set_value("meta", "codex_unread", {
		"characters": ["berserk", "berserk", "fake_character"],
		"weapons": ["berserk/axe", "berserk/fake_weapon"],
		"artifacts": ["rift_key", "fake_artifact"],
		"unknown": ["ignored"],
	})
	config.save(TEST_PATH)
	var normalized := Meta.load_state(TEST_PATH)
	_expect_ids(errors, normalized, "monsters", ["rift_cutter", "bone_caller"])
	_expect_ids(errors, normalized, "bosses", [])
	_expect_ids(errors, normalized, "artifacts", ["rift_key"])
	_expect_unread_ids(errors, normalized, "characters", ["berserk"])
	_expect_unread_ids(errors, normalized, "weapons", ["berserk/axe"])
	_expect_unread_ids(errors, normalized, "artifacts", ["rift_key"])

	_cleanup()
	if not errors.is_empty():
		for error in errors:
			push_error("Codex unlock tracking: %s" % error)
		push_error("Codex unlock tracking test failed with %d errors." % errors.size())
		quit(1)
		return
	print("Codex unlock tracking test passed.")
	quit(0)


func _expect_ids(errors: Array, state: Dictionary, category: String, expected: Array) -> void:
	var actual := Meta.discovered_ids(state, category)
	if actual.size() != expected.size():
		errors.append("%s expected %s ids, got %s: %s" % [category, expected.size(), actual.size(), str(actual)])
		return
	for index in range(expected.size()):
		if str(actual[index]) != str(expected[index]):
			errors.append("%s mismatch at %d: %s != %s" % [category, index, str(actual[index]), str(expected[index])])


func _expect_unread_ids(errors: Array, state: Dictionary, category: String, expected: Array) -> void:
	var actual := Meta.unread_codex_ids(state, category)
	if actual != expected:
		errors.append("%s unread mismatch: %s != %s" % [category, str(actual), str(expected)])


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
