extends SceneTree

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/audio_manager.gd")
const EPS_DB := 0.5


func _initialize() -> void:
	if not _require_scratch_user_dir():
		quit(2)
		return
	var errors: Array[String] = []
	_check_defaults_and_roundtrip(errors)
	await _check_audio_runtime(errors)
	if not errors.is_empty():
		for error in errors:
			push_error("SCRUM-974: %s" % error)
		quit(1)
		return
	print("SCRUM-974 Audio Settings persistence/bus/focus/low-HP test passed.")
	quit(0)


func _check_defaults_and_roundtrip(errors: Array[String]) -> void:
	var defaults := GAME_SETTINGS.load_settings()
	if not is_equal_approx(float(defaults.get("ui_volume", -1.0)), 1.0):
		errors.append("ui_volume default must be 1.0")
	if bool(defaults.get("mute_when_unfocused", true)):
		errors.append("mute_when_unfocused default must be false")
	if not bool(defaults.get("low_hp_warning_enabled", false)):
		errors.append("low_hp_warning_enabled default must be true")

	var probe := defaults.duplicate(true)
	probe["ui_volume"] = 0.34
	probe["mute_when_unfocused"] = true
	probe["low_hp_warning_enabled"] = false
	probe["sfx_enabled"] = true
	GAME_SETTINGS.save_settings(probe)
	var loaded := GAME_SETTINGS.load_settings()
	if not is_equal_approx(float(loaded.get("ui_volume", -1.0)), 0.34):
		errors.append("ui_volume did not survive persistence roundtrip")
	if not bool(loaded.get("mute_when_unfocused", false)):
		errors.append("mute_when_unfocused did not survive persistence roundtrip")
	if bool(loaded.get("low_hp_warning_enabled", true)):
		errors.append("low_hp_warning_enabled did not survive persistence roundtrip")

	var raw := ConfigFile.new()
	raw.set_value(GAME_SETTINGS.SECTION, "ui_volume", 4.0)
	raw.set_value(GAME_SETTINGS.SECTION, "mute_when_unfocused", 0)
	raw.set_value(GAME_SETTINGS.SECTION, "low_hp_warning_enabled", 1)
	raw.save(GAME_SETTINGS.SAVE_PATH)
	var normalized := GAME_SETTINGS.load_settings()
	if not is_equal_approx(float(normalized.get("ui_volume", -1.0)), 1.0):
		errors.append("ui_volume was not clamped into 0..1")
	if bool(normalized.get("mute_when_unfocused", true)):
		errors.append("mute_when_unfocused was not normalized to false")
	if not bool(normalized.get("low_hp_warning_enabled", false)):
		errors.append("low_hp_warning_enabled was not normalized to true")


func _check_audio_runtime(errors: Array[String]) -> void:
	var audio := root.get_node_or_null("AudioManager")
	var spawned := false
	if audio == null:
		audio = AUDIO_MANAGER_SCRIPT.new()
		root.add_child(audio)
		spawned = true
		await process_frame
	# --script initialization can run before an autoload's first ready callback.
	audio.call("_ensure_audio_buses")

	for bus_name in ["Master", "Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			errors.append("missing audio bus %s" % bus_name)
	var ui_bus := AudioServer.get_bus_index("UI")
	if ui_bus != -1 and AudioServer.get_bus_send(ui_bus) != "SFX":
		errors.append("UI bus must send to SFX, got %s" % AudioServer.get_bus_send(ui_bus))

	for sfx_id in ["ui_click", "ui_back", "ui_error"]:
		if str(audio.call("sfx_bus_for_id", sfx_id)) != "UI":
			errors.append("%s must route to UI bus" % sfx_id)
	for sfx_id in ["purchase", "artifact_reveal", "level_up", "low_hp_pulse", "hit"]:
		if str(audio.call("sfx_bus_for_id", sfx_id)) != "SFX":
			errors.append("%s must remain on SFX bus" % sfx_id)

	var active_settings := {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 0.8,
		"ui_volume": 0.4,
		"music_enabled": true,
		"sfx_enabled": true,
		"mute_when_unfocused": true,
		"low_hp_warning_enabled": true,
	}
	audio.apply_volume_settings(active_settings)
	if ui_bus != -1 and absf(AudioServer.get_bus_volume_db(ui_bus) - linear_to_db(0.4)) > EPS_DB:
		errors.append("ui_volume=0.4 was not applied to UI bus")

	audio.call("set_application_focused", false)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus != -1 and not AudioServer.is_bus_mute(master_bus):
		errors.append("focus loss did not hard-mute Master")
	audio.call("set_application_focused", true)
	if master_bus != -1 and AudioServer.is_bus_mute(master_bus):
		errors.append("focus restore did not unmute Master")
	active_settings["mute_when_unfocused"] = false
	audio.apply_volume_settings(active_settings)
	audio.call("set_application_focused", false)
	if master_bus != -1 and AudioServer.is_bus_mute(master_bus):
		errors.append("Master muted on focus loss while option disabled")
	audio.call("set_application_focused", true)

	audio.set_sfx_loop("low_hp_pulse", true)
	if not bool((audio.get("_sfx_loop_requested") as Dictionary).get("low_hp_pulse", false)):
		errors.append("low-HP requested loop state was not recorded")
	if not bool((audio.get("_sfx_loop_effective") as Dictionary).get("low_hp_pulse", false)):
		errors.append("enabled low-HP warning did not become effective")
	active_settings["low_hp_warning_enabled"] = false
	audio.apply_volume_settings(active_settings)
	if not bool((audio.get("_sfx_loop_requested") as Dictionary).get("low_hp_pulse", false)):
		errors.append("disabling warning destroyed requested low-HP state")
	if bool((audio.get("_sfx_loop_effective") as Dictionary).get("low_hp_pulse", true)):
		errors.append("disabled low-HP warning remained effective")
	active_settings["low_hp_warning_enabled"] = true
	audio.apply_volume_settings(active_settings)
	if not bool((audio.get("_sfx_loop_effective") as Dictionary).get("low_hp_pulse", false)):
		errors.append("re-enabled warning did not resume the requested loop")
	audio.set_sfx_loop("low_hp_pulse", false)
	if bool((audio.get("_sfx_loop_requested") as Dictionary).get("low_hp_pulse", true)) or bool((audio.get("_sfx_loop_effective") as Dictionary).get("low_hp_pulse", true)):
		errors.append("explicit low-HP loop stop did not clear requested/effective state")

	# Restore shared bus state for the rest of a multi-test process.
	active_settings["mute_when_unfocused"] = false
	active_settings["low_hp_warning_enabled"] = true
	active_settings["ui_volume"] = 1.0
	active_settings["sfx_volume"] = 1.0
	audio.apply_volume_settings(active_settings)
	if spawned:
		audio.queue_free()
		await process_frame


func _require_scratch_user_dir() -> bool:
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--user-data-dir="):
			requested = argument.trim_prefix("--user-data-dir=").simplify_path()
			break
	var actual := OS.get_user_data_dir().simplify_path()
	if requested == "" or requested == "/" or not actual.begins_with(requested.rstrip("/") + "/"):
		push_error("SCRUM-974 test requires isolated HOME/XDG and --user-data-dir matching that scratch root (actual %s, requested %s)." % [actual, requested])
		return false
	return true
