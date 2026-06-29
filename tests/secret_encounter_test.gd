extends SceneTree

# SCRUM-541: the secret boss is a post-Act-3 max-Ascension endcap.
# This test covers pure meta gate logic and the one-time persistent reward.

const Meta := preload("res://scripts/meta_progression.gd")
const TEST_PATH := "user://test_secret_encounter.cfg"


func _state_with_ascension(character_id: String, level: int) -> Dictionary:
	var state := Meta.default_state()
	for _i in range(level):
		state = Meta.record_boss_victory(state, character_id, Meta.ascension_level(state, character_id))
	return state


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	var fresh := Meta.default_state()
	if Meta.secret_boss_defeated(fresh):
		errors.append("fresh state should not have secret_boss_defeated")
	if Meta.secret_encounter_unlocked_for_level(0):
		errors.append("run level 0 must not unlock secret encounter")
	if Meta.secret_encounter_unlocked_for_level(Meta.MAX_ASCENSION_LEVEL - 1):
		errors.append("below max Ascension must not unlock secret encounter")
	if not Meta.secret_encounter_unlocked_for_level(Meta.MAX_ASCENSION_LEVEL):
		errors.append("max selected Ascension must unlock secret encounter")

	var max_state := _state_with_ascension("berserk", Meta.MAX_ASCENSION_LEVEL)
	var lower_state := _state_with_ascension("berserk", Meta.MAX_ASCENSION_LEVEL - 1)
	if not Meta.secret_encounter_unlocked(max_state, {"selected_ascension_level": Meta.MAX_ASCENSION_LEVEL}, "berserk"):
		errors.append("selected max Ascension must unlock through compatibility API")
	if Meta.secret_encounter_unlocked(max_state, {"selected_ascension_level": Meta.MAX_ASCENSION_LEVEL - 1}, "berserk"):
		errors.append("selected lower-than-max Ascension must block even when meta is maxed")
	if Meta.secret_encounter_unlocked(lower_state, {"damage_taken": 0.0}, "berserk"):
		errors.append("old low-damage branch must not unlock below max")
	if Meta.secret_encounter_unlocked(lower_state, {"artifacts": [Meta.SECRET_ENCOUNTER_ARTIFACT_KEY]}, "berserk"):
		errors.append("old key-artifact branch must not unlock below max")
	if not Meta.secret_encounter_unlocked(max_state, {}, "berserk"):
		errors.append("fallback meta max Ascension should unlock when selected level is absent")

	if Meta.SECRET_BOSS_ID != "secret_ascension_boss":
		errors.append("secret boss must use a separate canonical id")
	if Meta.SECRET_ENCOUNTER_MIN_ASCENSION != Meta.MAX_ASCENSION_LEVEL:
		errors.append("secret encounter min Ascension should equal max Ascension")

	var reward: int = Meta.SECRET_ENCOUNTER_REWARD_META_POINTS
	var state := max_state.duplicate(true)
	var points_before := int(state.get("meta_points", 0))
	state = Meta.record_secret_boss_victory(state)
	if not Meta.secret_boss_defeated(state):
		errors.append("secret_boss_defeated should be true after victory")
	if int(state.get("meta_points", 0)) != points_before + reward:
		errors.append("secret reward should add exactly %d meta points" % reward)
	var points_after_first := int(state.get("meta_points", 0))
	state = Meta.record_secret_boss_victory(state)
	if int(state.get("meta_points", 0)) != points_after_first:
		errors.append("secret reward should be one-time")

	Meta.save_state(state, TEST_PATH)
	var loaded := Meta.load_state(TEST_PATH)
	if not Meta.secret_boss_defeated(loaded):
		errors.append("secret_boss_defeated should survive save/load")
	var loaded_points := int(loaded.get("meta_points", 0))
	loaded = Meta.record_secret_boss_victory(loaded)
	if int(loaded.get("meta_points", 0)) != loaded_points:
		errors.append("loaded repeat victory should not grant points again")

	_cleanup()

	if not errors.is_empty():
		for error in errors:
			push_error("Secret encounter: %s" % error)
		quit(1)
		return
	print("Secret encounter test passed (max selected Ascension gate, separate boss id, one-time reward).")
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH):
		dir.remove(TEST_PATH)
