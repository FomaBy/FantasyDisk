extends SceneTree

# SCRUM-969: разовый приёмочный QA-смоук аудио-цепочки SCRUM-965..968 —
# поведенческие аспекты AC, НЕ покрытые audio_integration_test/audio_manager_smoke_test:
#   1) персистенс настроек музыки/SFX (game_settings save->load roundtrip,
#      реальный user://settings.cfg бэкапится и восстанавливается);
#   2) low-HP цикл на ЖИВОМ Player.tscn: старт ниже 30%, лечение выше 34% -> стоп,
#      мёртвая зона держит состояние, повторные апдейты не стакают луп
#      (edge-trigger), выход из дерева (смерть/конец боя) гасит пульс;
#   3) контракт конца боя (combat_director._play_combat_result_audio):
#      fast-outro 1.2 c + снятие low_hp_pulse + стингер по исходу
#      (обычная победа / epic для элитки и босса / поражение);
#   4) round timing (combat_director._play_combat_start_music): kind и РЕАЛЬНЫЙ
#      game.round_time_left уходят в play_combat_music (battle/elite/boss/final,
#      секретный босс -> final);
#   5) AudioManager: play_combat_music фиксирует _planned_round_duration и
#      _combat_kind (outro-окно 6 c бой / 8 c элитка+боссы), play_music сбрасывает
#      боевое состояние, легаси slot-id combat/boss роутятся в ротацию.
#
# Запуск: Godot --headless --path . --script res://tests/audio_qa_969_test.gd

const AudioManagerScript := preload("res://scripts/audio_manager.gd")
const CombatDirectorScript := preload("res://scripts/combat_director.gd")
const GameSettings := preload("res://scripts/game_settings.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

const SETTINGS_PATH := "user://settings.cfg"


class StubAudio extends Node:
	# Запись вызовов AudioManager-API для поведенческих ассертов.
	var calls: Array = []

	func set_sfx_loop(sfx_id: String, active: bool) -> void:
		calls.append(["set_sfx_loop", sfx_id, active])

	func begin_music_outro(seconds_left: float) -> void:
		calls.append(["begin_music_outro", seconds_left])

	func play_music_stinger(stinger_id: String) -> void:
		calls.append(["play_music_stinger", stinger_id])

	func play_combat_music(kind: String, planned_duration: float) -> void:
		calls.append(["play_combat_music", kind, planned_duration])

	func play_music(music_id: String) -> void:
		calls.append(["play_music", music_id])

	func filtered(method: String) -> Array:
		var out: Array = []
		for c in calls:
			if c[0] == method:
				out.append(c)
		return out


class StubGame extends Node:
	# Минимальный срез полей main.gd, которые читают тестируемые методы директора.
	var boss_combat_active := false
	var secret_boss_active := false
	var current_act := 1
	var ACT_COUNT := 2
	var current_combat_type := "normal"
	var round_time_left := 0.0


func _initialize() -> void:
	await process_frame
	var errors: Array = []

	_check_settings_persistence(errors)
	await _check_low_hp_cycle_on_live_player(errors)
	await _check_combat_audio_contracts(errors)
	_check_audio_manager_round_timing(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Audio QA 969: %s" % e)
		push_error("Audio QA 969 test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Audio QA 969 test passed (персистенс настроек, low-HP цикл на живом игроке, контракт конца боя, round timing, состояние AudioManager).")
	quit(0)


# --- 1) Персистенс настроек музыки/SFX ----------------------------------------

func _check_settings_persistence(errors: Array) -> void:
	# Реальный user://settings.cfg аккуратно сохраняем и восстанавливаем.
	var had_file := FileAccess.file_exists(SETTINGS_PATH)
	var backup := PackedByteArray()
	if had_file:
		backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)

	var probe := GameSettings.load_settings()
	probe["music_volume"] = 0.37
	probe["sfx_volume"] = 0.66
	probe["music_enabled"] = true
	probe["sfx_enabled"] = false
	GameSettings.save_settings(probe)

	var loaded := GameSettings.load_settings()
	if absf(float(loaded.get("music_volume", -1.0)) - 0.37) > 0.001:
		errors.append("персистенс: music_volume %.3f != 0.37" % float(loaded.get("music_volume", -1.0)))
	if absf(float(loaded.get("sfx_volume", -1.0)) - 0.66) > 0.001:
		errors.append("персистенс: sfx_volume %.3f != 0.66" % float(loaded.get("sfx_volume", -1.0)))
	if not bool(loaded.get("music_enabled", false)):
		errors.append("персистенс: music_enabled=true не пережил roundtrip")
	if bool(loaded.get("sfx_enabled", true)):
		errors.append("персистенс: sfx_enabled=false не пережил roundtrip")

	# Восстановление исходного состояния пользователя.
	if had_file:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# --- 2) Low-HP цикл на живом игроке -------------------------------------------

func _loop_calls(stub: StubAudio) -> Array:
	return stub.filtered("set_sfx_loop")


func _check_low_hp_cycle_on_live_player(errors: Array) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var player := PLAYER_SCENE.instantiate()
	holder.add_child(player)
	await process_frame

	# Детерминизм: гасим physics-тик (там живёт _update_low_hp_audio_cue),
	# состояние двигаем явными вызовами.
	player.set_physics_process(false)
	player.set_process(false)
	var stub := StubAudio.new()
	root.add_child(stub)
	player.set("_cached_audio", stub)

	player.set("max_health", 100.0)
	player.set("health", 100.0)
	player.call("_update_low_hp_audio_cue")
	if not _loop_calls(stub).is_empty():
		errors.append("low-HP: при 100%% HP луп не должен включаться (calls=%s)" % str(stub.calls))

	# Падение ниже 30% -> ровно один set_sfx_loop(true).
	player.set("health", 25.0)
	player.call("_update_low_hp_audio_cue")
	var calls := _loop_calls(stub)
	if calls.size() != 1 or calls[0][1] != "low_hp_pulse" or calls[0][2] != true:
		errors.append("low-HP: падение до 25%% дало %s, ожидался один ['low_hp_pulse', true]" % str(calls))

	# Повторные тики на том же уровне HP не стакают луп (edge-trigger).
	for i in range(3):
		player.call("_update_low_hp_audio_cue")
	if _loop_calls(stub).size() != 1:
		errors.append("low-HP: повторные тики застакали луп (calls=%s)" % str(stub.calls))

	# Мёртвая зона 30..34%% держит включённым, без новых вызовов.
	player.set("health", 32.0)
	player.call("_update_low_hp_audio_cue")
	if _loop_calls(stub).size() != 1:
		errors.append("low-HP: мёртвая зона (32%%) не должна менять состояние (calls=%s)" % str(stub.calls))

	# Лечение до >=34%% -> один set_sfx_loop(false).
	player.set("health", 35.0)
	player.call("_update_low_hp_audio_cue")
	calls = _loop_calls(stub)
	if calls.size() != 2 or calls[1][2] != false:
		errors.append("low-HP: лечение до 35%% дало %s, ожидался ['low_hp_pulse', false]" % str(calls))

	# Повторное падение — цикл взводится заново ровно один раз.
	player.set("health", 20.0)
	player.call("_update_low_hp_audio_cue")
	player.call("_update_low_hp_audio_cue")
	calls = _loop_calls(stub)
	if calls.size() != 3 or calls[2][2] != true:
		errors.append("low-HP: повторное падение дало %s, ожидался третий вызов [true]" % str(calls))

	# Смерть/конец боя: игрок покидает дерево -> пульс гаснет (_exit_tree).
	holder.remove_child(player)
	player.free()
	calls = _loop_calls(stub)
	if calls.size() != 4 or calls[3][2] != false:
		errors.append("low-HP: выход игрока из дерева дал %s, ожидался финальный [false]" % str(calls))

	holder.free()
	stub.free()
	await process_frame


# --- 3-4) Контракты боевой музыки combat_director ------------------------------

func _swap_in_stub_audio() -> Array:
	# Подменяем autoload /root/AudioManager записывающим стабом (и возвращаем
	# рецепт отката). В headless реальный менеджер _disabled — вызовы не видны,
	# поэтому контракт проверяется через стаб.
	var real: Node = root.get_node_or_null("/root/AudioManager")
	if real != null:
		real.name = "AudioManagerQaParked"
	var stub := StubAudio.new()
	stub.name = "AudioManager"
	root.add_child(stub)
	return [stub, real]


func _restore_real_audio(stub: StubAudio, real: Node) -> void:
	root.remove_child(stub)
	stub.free()
	if real != null:
		real.name = "AudioManager"


func _check_combat_audio_contracts(errors: Array) -> void:
	var swapped := _swap_in_stub_audio()
	var stub: StubAudio = swapped[0]
	var real: Node = swapped[1]

	var game := StubGame.new()
	root.add_child(game)
	var director = CombatDirectorScript.new(game)

	# --- Kind + реальная длительность раунда уходят в play_combat_music ---
	game.round_time_left = 87.3
	director._play_combat_start_music()
	game.current_combat_type = "elite"
	game.round_time_left = 300.0
	director._play_combat_start_music()
	game.current_combat_type = "normal"
	game.boss_combat_active = true
	game.current_act = 1
	director._play_combat_start_music()
	game.current_act = game.ACT_COUNT
	director._play_combat_start_music()
	game.current_act = 1
	game.secret_boss_active = true
	director._play_combat_start_music()

	var starts := stub.filtered("play_combat_music")
	var want_starts := [
		["play_combat_music", "battle", 87.3],
		["play_combat_music", "elite", 300.0],
		["play_combat_music", "boss", 300.0],
		["play_combat_music", "final", 300.0],
		["play_combat_music", "final", 300.0],
	]
	if starts.size() != want_starts.size():
		errors.append("старт боя: %d вызовов play_combat_music, ожидалось %d (%s)" % [starts.size(), want_starts.size(), str(starts)])
	else:
		for i in range(want_starts.size()):
			if str(starts[i][1]) != str(want_starts[i][1]) or absf(float(starts[i][2]) - float(want_starts[i][2])) > 0.001:
				errors.append("старт боя #%d: %s, ожидалось %s" % [i, str(starts[i]), str(want_starts[i])])

	# --- Конец боя: fast-outro + снятие low-HP лупа + стингер по исходу ---
	stub.calls.clear()
	director._play_combat_result_audio(true, false, false)   # обычная победа
	director._play_combat_result_audio(true, false, true)    # победа над элиткой
	director._play_combat_result_audio(true, true, false)    # победа над боссом
	director._play_combat_result_audio(false, false, false)  # поражение

	var outros := stub.filtered("begin_music_outro")
	if outros.size() != 4:
		errors.append("конец боя: begin_music_outro вызван %d раз, ожидалось 4" % outros.size())
	for c in outros:
		if absf(float(c[1]) - 1.2) > 0.001:
			errors.append("конец боя: fast-outro %.2f c, ожидалось 1.2 c" % float(c[1]))
	var loops := stub.filtered("set_sfx_loop")
	if loops.size() != 4:
		errors.append("конец боя: low_hp_pulse снимался %d раз, ожидалось 4" % loops.size())
	for c in loops:
		if c[1] != "low_hp_pulse" or c[2] != false:
			errors.append("конец боя: ожидалось снятие low_hp_pulse, получено %s" % str(c))
	var stingers := stub.filtered("play_music_stinger")
	var want_stingers := ["music_sting_victory", "music_sting_victory_epic", "music_sting_victory_epic", "music_sting_defeat"]
	if stingers.size() != want_stingers.size():
		errors.append("конец боя: %d стингеров, ожидалось %d (%s)" % [stingers.size(), want_stingers.size(), str(stingers)])
	else:
		for i in range(want_stingers.size()):
			if str(stingers[i][1]) != want_stingers[i]:
				errors.append("стингер #%d: %s, ожидался %s" % [i, str(stingers[i][1]), want_stingers[i]])

	director = null
	root.remove_child(game)
	game.free()
	_restore_real_audio(stub, real)
	await process_frame


# --- 5) AudioManager: планируемая длительность и outro-окно --------------------

func _check_audio_manager_round_timing(errors: Array) -> void:
	# Инстанс вне дерева: _ready не бежит, _disabled=false по умолчанию, плееры
	# null -> _play_music_resolved выходит до плейбека (headless-safe паттерн
	# audio_integration_test).
	var audio = AudioManagerScript.new()

	audio.play_combat_music("battle", 73.5)
	if absf(float(audio.get("_planned_round_duration")) - 73.5) > 0.001:
		errors.append("play_combat_music(battle, 73.5) не сохранил длительность (%.2f)" % float(audio.get("_planned_round_duration")))
	if str(audio.get("_combat_kind")) != "battle":
		errors.append("kind после battle: '%s'" % str(audio.get("_combat_kind")))
	if absf(float(audio.music_outro_window()) - AudioManagerScript.MUSIC_OUTRO_WINDOW_NORMAL) > 0.001:
		errors.append("окно outro battle != 6 c")

	audio.play_combat_music("elite", 300.0)
	if absf(float(audio.get("_planned_round_duration")) - 300.0) > 0.001:
		errors.append("elite: длительность 300 не сохранилась")
	if absf(float(audio.music_outro_window()) - AudioManagerScript.MUSIC_OUTRO_WINDOW_LONG) > 0.001:
		errors.append("окно outro elite != 8 c")
	audio.play_combat_music("boss", 300.0)
	if absf(float(audio.music_outro_window()) - AudioManagerScript.MUSIC_OUTRO_WINDOW_LONG) > 0.001:
		errors.append("окно outro boss != 8 c")
	audio.play_combat_music("final", 300.0)
	if absf(float(audio.music_outro_window()) - AudioManagerScript.MUSIC_OUTRO_WINDOW_LONG) > 0.001:
		errors.append("окно outro final != 8 c")

	# Отрицательная длительность клампится в 0.
	audio.play_combat_music("battle", -5.0)
	if float(audio.get("_planned_round_duration")) != 0.0:
		errors.append("отрицательная длительность не заклампилась (%.2f)" % float(audio.get("_planned_round_duration")))

	# Выход из боя: play_music сбрасывает боевое состояние.
	audio.play_music("menu")
	if str(audio.get("_combat_kind")) != "" or float(audio.get("_planned_round_duration")) != 0.0:
		errors.append("play_music(menu) не сбросил боевое состояние (kind='%s', dur=%.1f)" % [str(audio.get("_combat_kind")), float(audio.get("_planned_round_duration"))])

	# Легаси slot-id: combat -> battle 90 c, boss -> boss 300 c.
	audio.play_music("combat")
	if str(audio.get("_combat_kind")) != "battle" or absf(float(audio.get("_planned_round_duration")) - 90.0) > 0.001:
		errors.append("легаси 'combat' не отроутился в battle/90 (kind='%s', dur=%.1f)" % [str(audio.get("_combat_kind")), float(audio.get("_planned_round_duration"))])
	audio.play_music("boss")
	if str(audio.get("_combat_kind")) != "boss" or absf(float(audio.get("_planned_round_duration")) - 300.0) > 0.001:
		errors.append("легаси 'boss' не отроутился в boss/300 (kind='%s', dur=%.1f)" % [str(audio.get("_combat_kind")), float(audio.get("_planned_round_duration"))])

	audio.free()
