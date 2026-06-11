extends RefCounted

# Персистентная метапрогрессия: meta points и уровни возвышения (1-10)
# на персонажа. Сохранение через ConfigFile в user://.

const DEFAULT_SAVE_PATH := "user://fantasydisk_meta.cfg"
const MAX_ASCENSION_LEVEL := 10
const SECTION := "meta"


static func default_state() -> Dictionary:
	return {
		"meta_points": 0,
		"ascension_levels": {},
	}


static func load_state(save_path := DEFAULT_SAVE_PATH) -> Dictionary:
	var state := default_state()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return state
	state["meta_points"] = int(config.get_value(SECTION, "meta_points", 0))
	var raw_levels = config.get_value(SECTION, "ascension_levels", {})
	var levels := {}
	if raw_levels is Dictionary:
		for character_id in raw_levels.keys():
			levels[str(character_id)] = clampi(int(raw_levels[character_id]), 0, MAX_ASCENSION_LEVEL)
	state["ascension_levels"] = levels
	return state


static func save_state(state: Dictionary, save_path := DEFAULT_SAVE_PATH) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "meta_points", int(state.get("meta_points", 0)))
	config.set_value(SECTION, "ascension_levels", state.get("ascension_levels", {}))
	config.save(save_path)


static func ascension_level(state: Dictionary, character_id: String) -> int:
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		return 0
	return clampi(int(levels.get(character_id, 0)), 0, MAX_ASCENSION_LEVEL)


static func record_boss_victory(state: Dictionary, character_id: String) -> Dictionary:
	state["meta_points"] = int(state.get("meta_points", 0)) + 1
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		levels = {}
	levels[character_id] = clampi(int(levels.get(character_id, 0)) + 1, 0, MAX_ASCENSION_LEVEL)
	state["ascension_levels"] = levels
	return state
