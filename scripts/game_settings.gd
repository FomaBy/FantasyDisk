extends RefCounted

# Персистентные настройки игры (дисплей + звук) в user://settings.cfg.

const GAMEPLAY_SANDBOX := preload("res://scripts/gameplay_sandbox.gd")

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const MASTER_ZERO_INTENT_KEY := "master_zero_intent"
const MAX_RESOLUTION_INDEX := 1

const DEFAULTS := {
	"resolution_index": 0,
	"window_mode_index": 0,
	"screen_index": 0,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"ui_volume": 1.0,
	"master_zero_intent": false,
	"music_enabled": false,
	"sfx_enabled": false,
	"mute_when_unfocused": false,
	"low_hp_warning_enabled": true,
	"screen_shake": true,
	"combat_feedback": true,
	"debug_mode": false,
	"aim_mode": "nearest",
	"last_seen_version": "0.0.0",
	"input_bindings": {},
	# SCRUM-811: геймпад. input_mode влияет на active_kind/подсказки, оба
	# устройства физически работают всегда; deadzone/vibration читают SCRUM-814/816.
	"input_mode": "auto",
	"gamepad_bindings": {},
	"gamepad_deadzone": 0.25,
	"gamepad_vibration": true,
	# SCRUM-976: нейтральные значения сохраняют release-баланс и progression.
	"sandbox_monster_hp_multiplier": 1.0,
	"sandbox_monster_damage_multiplier": 1.0,
	"sandbox_player_damage_multiplier": 1.0,
	"sandbox_player_attack_speed_multiplier": 1.0,
	"sandbox_monster_attack_speed_multiplier": 1.0,
}


static func load_settings() -> Dictionary:
	var settings := DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return settings
	var has_master_zero_intent := config.has_section_key(SECTION, MASTER_ZERO_INTENT_KEY)
	for key in DEFAULTS.keys():
		settings[key] = config.get_value(SECTION, key, DEFAULTS[key])
	settings["resolution_index"] = clampi(int(settings["resolution_index"]), 0, MAX_RESOLUTION_INDEX)
	settings["window_mode_index"] = int(settings["window_mode_index"])
	settings["screen_index"] = int(settings["screen_index"])
	settings["master_volume"] = clampf(float(settings["master_volume"]), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings["music_volume"]), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(settings["sfx_volume"]), 0.0, 1.0)
	settings["ui_volume"] = clampf(float(settings["ui_volume"]), 0.0, 1.0)
	settings["master_zero_intent"] = bool(settings["master_zero_intent"])
	settings["music_enabled"] = bool(settings["music_enabled"])
	settings["sfx_enabled"] = bool(settings["sfx_enabled"])
	settings["mute_when_unfocused"] = bool(settings["mute_when_unfocused"])
	settings["low_hp_warning_enabled"] = bool(settings["low_hp_warning_enabled"])
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
	settings["input_mode"] = str(settings["input_mode"])
	if not ["auto", "keyboard", "gamepad"].has(settings["input_mode"]):
		settings["input_mode"] = DEFAULTS["input_mode"]
	if not (settings["gamepad_bindings"] is Dictionary):
		settings["gamepad_bindings"] = {}
	settings["gamepad_deadzone"] = clampf(float(settings["gamepad_deadzone"]), 0.05, 0.5)
	settings["gamepad_vibration"] = bool(settings["gamepad_vibration"])
	GAMEPLAY_SANDBOX.write_snapshot_to_settings(settings, settings)
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
