extends RefCounted

# Персистентные настройки игры (дисплей + звук) в user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const MASTER_ZERO_INTENT_KEY := "master_zero_intent"

const DEFAULTS := {
	"resolution_index": 1,
	"window_mode_index": 0,
	"screen_index": 0,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"master_zero_intent": false,
	"music_enabled": true,
	"sfx_enabled": true,
	"screen_shake": true,
	"combat_feedback": true,
	"debug_mode": false,
	"aim_mode": "nearest",
	"last_seen_version": "0.0.0",
	"input_bindings": {},
}


static func load_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return settings
	var has_master_zero_intent := config.has_section_key(SECTION, MASTER_ZERO_INTENT_KEY)
	for key in DEFAULTS.keys():
		settings[key] = config.get_value(SECTION, key, DEFAULTS[key])
	settings["resolution_index"] = int(settings["resolution_index"])
	settings["window_mode_index"] = int(settings["window_mode_index"])
	settings["screen_index"] = int(settings["screen_index"])
	settings["master_volume"] = clampf(float(settings["master_volume"]), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings["music_volume"]), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings["sfx_volume"]), 0.0, 1.0)
	settings["master_zero_intent"] = bool(settings["master_zero_intent"])
	settings["music_enabled"] = bool(settings["music_enabled"])
	settings["sfx_enabled"] = bool(settings["sfx_enabled"])
	settings["screen_shake"] = bool(settings["screen_shake"])
	settings["combat_feedback"] = bool(settings["combat_feedback"])
	settings["debug_mode"] = bool(settings["debug_mode"])
	settings["aim_mode"] = str(settings["aim_mode"])
	if not ["nearest", "cursor"].has(settings["aim_mode"]):
		settings["aim_mode"] = DEFAULTS["aim_mode"]
	# SCRUM-159: версия, патч-ноуты которой игрок уже видел (для бейджа «Что нового»).
	settings["last_seen_version"] = str(settings["last_seen_version"])
	if not (settings["input_bindings"] is Dictionary):
		settings["input_bindings"] = {}
	if float(settings["master_volume"]) <= 0.0 and not has_master_zero_intent:
		settings["master_volume"] = float(DEFAULTS["master_volume"])
		settings["master_zero_intent"] = false
		save_settings(settings)
	return settings


static func save_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	var normalized := settings.duplicate(true)
	if not normalized.has(MASTER_ZERO_INTENT_KEY):
		normalized[MASTER_ZERO_INTENT_KEY] = float(normalized.get("master_volume", DEFAULTS["master_volume"])) <= 0.0
	for key in DEFAULTS.keys():
		config.set_value(SECTION, key, normalized.get(key, DEFAULTS[key]))
	config.save(SAVE_PATH)
