extends RefCounted

# Персистентные настройки игры (дисплей + звук) в user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

const DEFAULTS := {
	"resolution_index": 1,
	"window_mode_index": 0,
	"screen_index": 0,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"music_enabled": true,
	"sfx_enabled": true,
	"input_bindings": {},
}


static func load_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return settings
	for key in DEFAULTS.keys():
		settings[key] = config.get_value(SECTION, key, DEFAULTS[key])
	settings["resolution_index"] = int(settings["resolution_index"])
	settings["window_mode_index"] = int(settings["window_mode_index"])
	settings["screen_index"] = int(settings["screen_index"])
	settings["master_volume"] = clampf(float(settings["master_volume"]), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings["music_volume"]), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings["sfx_volume"]), 0.0, 1.0)
	settings["music_enabled"] = bool(settings["music_enabled"])
	settings["sfx_enabled"] = bool(settings["sfx_enabled"])
	if not (settings["input_bindings"] is Dictionary):
		settings["input_bindings"] = {}
	return settings


static func save_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in DEFAULTS.keys():
		config.set_value(SECTION, key, settings.get(key, DEFAULTS[key]))
	config.save(SAVE_PATH)
