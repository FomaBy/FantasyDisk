extends SceneTree

# Smoke-тест аудиоменеджера (был непокрыт). Гейтит то, что РАБОТАЕТ в headless:
# создание шин Music/SFX, целостность ресурс-путей/констант и — главное —
# apply_volume_settings (поверхность регрессии SCRUM-172: master_volume=0
# мьютил весь Master). Воспроизведение в headless отключено (_disabled), его
# не трогаем. Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/audio_manager_smoke_test.gd

const AudioManagerScript := preload("res://scripts/audio_manager.gd")

const EPS_DB := 0.5


func _initialize() -> void:
	await process_frame
	var errors: Array = []

	# Менеджер: autoload или свежий инстанс (на случай отсутствия autoload в --script).
	var audio: Node = root.get_node_or_null("/root/AudioManager")
	var spawned := false
	if audio == null:
		audio = AudioManagerScript.new()
		root.add_child(audio)
		spawned = true
		await process_frame

	# --- Шины Music/SFX созданы и шлются в Master ---
	for bus_name in ["Master", "Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			errors.append("шина '%s' отсутствует" % bus_name)
	for bus_name in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx != -1 and AudioServer.get_bus_send(idx) != "Master":
			errors.append("шина '%s' не шлёт в Master (send=%s)" % [bus_name, AudioServer.get_bus_send(idx)])
	var ui_idx := AudioServer.get_bus_index("UI")
	if ui_idx != -1 and AudioServer.get_bus_send(ui_idx) != "SFX":
		errors.append("шина 'UI' не шлёт в SFX (send=%s)" % AudioServer.get_bus_send(ui_idx))

	# --- Целостность констант/ресурсов (SCRUM-968: MUSIC_META вместо MUSIC_PATHS) ---
	if AudioManagerScript.SFX_PATHS.is_empty():
		errors.append("SFX_PATHS пуст")
	if AudioManagerScript.MUSIC_META.is_empty():
		errors.append("MUSIC_META пуст")
	for sfx_id in AudioManagerScript.SFX_PATHS:
		var path := str(AudioManagerScript.SFX_PATHS[sfx_id])
		if not ResourceLoader.exists(path):
			errors.append("SFX '%s' -> отсутствует ресурс %s" % [sfx_id, path])
	for music_id in AudioManagerScript.MUSIC_META:
		var meta: Dictionary = AudioManagerScript.MUSIC_META[music_id]
		var path := str(meta.get("path", ""))
		if not ResourceLoader.exists(path):
			errors.append("музыка '%s' -> отсутствует ресурс %s" % [music_id, path])
	# Каждый alias и каждый боевой трек должны указывать на запись MUSIC_META.
	for alias in AudioManagerScript.MUSIC_ALIASES:
		if not AudioManagerScript.MUSIC_META.has(AudioManagerScript.MUSIC_ALIASES[alias]):
			errors.append("MUSIC_ALIASES '%s' указывает мимо MUSIC_META" % alias)
	for track_id in AudioManagerScript.COMBAT_ROTATION:
		if not AudioManagerScript.MUSIC_META.has(track_id):
			errors.append("COMBAT_ROTATION '%s' отсутствует в MUSIC_META" % track_id)
	for kind in AudioManagerScript.COMBAT_KIND_TRACKS:
		if not AudioManagerScript.MUSIC_META.has(AudioManagerScript.COMBAT_KIND_TRACKS[kind]):
			errors.append("COMBAT_KIND_TRACKS '%s' указывает мимо MUSIC_META" % kind)

	# --- apply_volume_settings: громкость/мьют шин ---
	if not audio.has_method("apply_volume_settings"):
		errors.append("AudioManager без apply_volume_settings")
	else:
		# Полная громкость, всё включено -> 0 dB, без мьюта.
		audio.apply_volume_settings({
			"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0,
			"music_enabled": true, "sfx_enabled": true,
		})
		_expect_db(errors, "Master", 0.0, "полная громкость")
		_expect_db(errors, "Music", 0.0, "полная громкость")
		_expect_db(errors, "SFX", 0.0, "полная громкость")
		_expect_mute(errors, "Music", false, "music_enabled=true")
		_expect_mute(errors, "SFX", false, "sfx_enabled=true")

		# master_volume=0 -> почти тишина (регрессия SCRUM-172).
		audio.apply_volume_settings({
			"master_volume": 0.0, "music_volume": 1.0, "sfx_volume": 1.0,
			"music_enabled": true, "sfx_enabled": true,
		})
		var master_idx := AudioServer.get_bus_index("Master")
		if master_idx != -1 and AudioServer.get_bus_volume_db(master_idx) > -60.0:
			errors.append("master_volume=0 даёт %.1f dB (ожидалась почти тишина <= -60)" % AudioServer.get_bus_volume_db(master_idx))

		# Полугромкость музыки -> linear_to_db(0.5) ≈ -6.02 dB.
		audio.apply_volume_settings({
			"master_volume": 1.0, "music_volume": 0.5, "sfx_volume": 1.0,
			"music_enabled": true, "sfx_enabled": true,
		})
		_expect_db(errors, "Music", linear_to_db(0.5), "music_volume=0.5")

		# Выключенные категории -> мьют шины (громкость самого слайдера сохраняется).
		audio.apply_volume_settings({
			"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0,
			"music_enabled": false, "sfx_enabled": false,
		})
		_expect_mute(errors, "Music", true, "music_enabled=false")
		_expect_mute(errors, "SFX", true, "sfx_enabled=false")

		# Возврат к норме (не оставляем шины мьютнутыми для других тестов).
		audio.apply_volume_settings({
			"master_volume": 1.0, "music_volume": 1.0, "sfx_volume": 1.0,
			"music_enabled": true, "sfx_enabled": true,
		})

	if spawned:
		audio.queue_free()
		await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Audio manager smoke: %s" % e)
		push_error("Audio manager smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Audio manager smoke test passed (шины Music/SFX/UI, %d sfx + %d музыка ресурсов, apply_volume_settings)." % [
		AudioManagerScript.SFX_PATHS.size(), AudioManagerScript.MUSIC_META.size()])
	quit(0)


func _expect_db(errors: Array, bus_name: String, want_db: float, context: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		errors.append("%s: шина '%s' отсутствует" % [context, bus_name])
		return
	var got := AudioServer.get_bus_volume_db(idx)
	if absf(got - want_db) > EPS_DB:
		errors.append("%s: шина '%s' %.2f dB != ожидаемых %.2f" % [context, bus_name, got, want_db])


func _expect_mute(errors: Array, bus_name: String, want_mute: bool, context: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		errors.append("%s: шина '%s' отсутствует" % [context, bus_name])
		return
	if AudioServer.is_bus_mute(idx) != want_mute:
		errors.append("%s: шина '%s' mute=%s, ожидалось %s" % [context, bus_name, AudioServer.is_bus_mute(idx), want_mute])
