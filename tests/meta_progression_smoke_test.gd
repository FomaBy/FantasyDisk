extends SceneTree

# Smoke test метапрогрессии: save/load roundtrip, кумулятивные ascension-бонусы
# и их применение к игроку при старте забега.

const META_PROGRESSION := preload("res://scripts/meta_progression.gd")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const TEST_SAVE_PATH := "user://test_meta_progression.cfg"


func _initialize() -> void:
	_test_save_load_roundtrip()
	_test_ascension_levels_data()
	_test_cumulative_mods()
	await _test_player_application()
	print("Meta progression smoke test passed.")
	quit(0)


func _test_save_load_roundtrip() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))

	var state := META_PROGRESSION.load_state(TEST_SAVE_PATH)
	if int(state.get("meta_points", -1)) != 0:
		push_error("Fresh meta state must start with 0 meta points.")
		quit(1)
		return

	state = META_PROGRESSION.record_boss_victory(state, "berserk")
	state = META_PROGRESSION.record_boss_victory(state, "berserk")
	state = META_PROGRESSION.record_boss_victory(state, "guitarist")
	META_PROGRESSION.save_state(state, TEST_SAVE_PATH)

	var loaded := META_PROGRESSION.load_state(TEST_SAVE_PATH)
	if int(loaded.get("meta_points", 0)) != 3:
		push_error("Expected 3 meta points after reload, got %s." % str(loaded.get("meta_points")))
		quit(1)
		return
	if META_PROGRESSION.ascension_level(loaded, "berserk") != 2:
		push_error("Expected berserk ascension 2 after reload.")
		quit(1)
		return
	if META_PROGRESSION.ascension_level(loaded, "guitarist") != 1:
		push_error("Expected guitarist ascension 1 after reload.")
		quit(1)
		return
	if META_PROGRESSION.ascension_level(loaded, "dark_mage") != 0:
		push_error("Expected dark mage ascension 0 after reload.")
		quit(1)
		return

	for victory_index in range(20):
		state = META_PROGRESSION.record_boss_victory(state, "berserk")
	if META_PROGRESSION.ascension_level(state, "berserk") != META_PROGRESSION.MAX_ASCENSION_LEVEL:
		push_error("Ascension level must cap at %d." % META_PROGRESSION.MAX_ASCENSION_LEVEL)
		quit(1)
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _test_ascension_levels_data() -> void:
	for character_id in ["berserk", "dark_mage", "guitarist"]:
		var levels: Array = PROGRESSION_DATA.ascension_levels(character_id)
		if levels.size() != 5:
			push_error("Expected 5 ascension levels for %s, got %d." % [character_id, levels.size()])
			quit(1)
			return
		var seen_ids := {}
		for level in levels:
			var level_id := str(level.get("id", ""))
			if level_id == "" or seen_ids.has(level_id):
				push_error("Ascension level of %s must have unique non-empty id." % character_id)
				quit(1)
				return
			seen_ids[level_id] = true
			if (level.get("mods", {}) as Dictionary).is_empty():
				push_error("Ascension level %s must define mods." % level_id)
				quit(1)
				return


func _test_cumulative_mods() -> void:
	var level_one: Dictionary = PROGRESSION_DATA.ascension_mods("berserk", 1)
	if abs(float(level_one.get("damage_multiplier", 0.0)) - 1.05) > 0.001:
		push_error("Berserk ascension 1 must give 1.05 damage multiplier.")
		quit(1)
		return

	var level_five: Dictionary = PROGRESSION_DATA.ascension_mods("berserk", 5)
	var expected_damage := 1.05 * 1.07
	if abs(float(level_five.get("damage_multiplier", 0.0)) - expected_damage) > 0.001:
		push_error("Berserk ascension 5 damage multiplier must stack multiplicatively.")
		quit(1)
		return
	if abs(float(level_five.get("max_health_flat", 0.0)) - 8.0) > 0.001:
		push_error("Berserk ascension 5 must include +8 flat HP from level 2.")
		quit(1)
		return

	if not (PROGRESSION_DATA.ascension_mods("berserk", 0) as Dictionary).is_empty():
		push_error("Ascension level 0 must give no mods.")
		quit(1)
		return


func _test_player_application() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		push_error("Player scene did not load.")
		quit(1)
		return
	var player := player_scene.instantiate()
	root.add_child(player)
	await process_frame

	player.call("configure_character", "berserk", "sword")
	var base_damage := float((player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	var base_health := float(player.get("max_health"))

	player.call("apply_reward", {"mods": PROGRESSION_DATA.ascension_mods("berserk", 5)})
	var boosted_damage := float((player.get("derived_parameters") as Dictionary).get("damage", 0.0))
	var boosted_health := float(player.get("max_health"))

	if boosted_damage <= base_damage:
		push_error("Ascension mods must increase derived damage (%f -> %f)." % [base_damage, boosted_damage])
		quit(1)
		return
	if boosted_health < base_health + 7.9:
		push_error("Ascension mods must add flat max health (%f -> %f)." % [base_health, boosted_health])
		quit(1)
		return
	player.queue_free()
