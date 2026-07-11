extends Node

# Autoload: AudioManager. Central SFX/music playback with a small player pool
# and per-sound throttling so crowd damage does not spam identical sounds.
#
# SCRUM-968: бардовский аудио-пак (SCRUM-966/967) + round-timed playback.
# Модель боевого трека — intro + бесшовный loop (loop_offset) + scripted outro
# (см. docs/design/systems/audio.md §3), ротация обычных боевых тем — shuffle-bag
# без повторов подряд (§4). Существующие сигнатуры play_sfx/play_music/stop_music/
# apply_volume_settings сохранены; headless (_disabled) полностью глушит и новые API.

# --- SFX ---------------------------------------------------------------------

const SFX_PATHS := {
	"hit": "res://assets/audio/sfx/sfx_hit.ogg",
	"hit_magic": "res://assets/audio/sfx/sfx_hit_magic.ogg",
	"hit_dot": "res://assets/audio/sfx/sfx_hit_dot.ogg",
	"player_hit": "res://assets/audio/sfx/sfx_player_hit.ogg",
	"dodge": "res://assets/audio/sfx/sfx_dodge.ogg",
	"pickup_xp": "res://assets/audio/sfx/sfx_pickup_xp.ogg",
	"pickup_money": "res://assets/audio/sfx/sfx_pickup_money.ogg",
	"level_up": "res://assets/audio/sfx/sfx_level_up.ogg",
	"purchase": "res://assets/audio/sfx/sfx_purchase.ogg",
	"ui_click": "res://assets/audio/sfx/sfx_ui_click.ogg",
	"ui_back": "res://assets/audio/sfx/sfx_ui_back.ogg",
	"ui_error": "res://assets/audio/sfx/sfx_ui_error.ogg",
	"artifact_reveal": "res://assets/audio/sfx/sfx_artifact_reveal.ogg",
	"boss_phase": "res://assets/audio/sfx/sfx_boss_phase.ogg",
	"low_hp_pulse": "res://assets/audio/sfx/sfx_low_hp_pulse.ogg",
}

# Пер-id интервалы троттлинга (спека §5, «throttle-группа»); дефолт — 0.05 c.
const SFX_THROTTLE_OVERRIDES := {
	"hit_dot": 0.12,   # DoT-тики частые — реже дефолта
	"pickup_xp": 0.06,
	"pickup_money": 0.06,
	"ui_error": 0.08,
}

# SCRUM-974: UI is a child mix of SFX. The existing SFX volume/mute remains the
# global parent, while unambiguous navigation sounds get an independent trim.
# Economy, reward and gameplay cues deliberately remain on SFX.
const UI_SFX_IDS := ["ui_click", "ui_back", "ui_error"]

# --- Музыка ------------------------------------------------------------------

# MUSIC_META — источник истины по трекам (замена плоских MUSIC_PATHS/MUSIC_GAIN_DB):
# path, loop, loop_offset (длина нелупящегося интро, сек — из SOURCES.md/мастеринга),
# gain_db (пер-трековый трим; новый пак нормализован к -16 LUFS → 0.0).
const MUSIC_META := {
	"music_menu_tavern_warm": {"path": "res://assets/audio/music/music_menu_tavern_warm.ogg", "loop": true, "loop_offset": 57.73, "gain_db": 0.0},
	"music_route_map_bard_journey": {"path": "res://assets/audio/music/music_route_map_bard_journey.ogg", "loop": true, "loop_offset": 2.76, "gain_db": 0.0},
	"music_shop_campfire_inn": {"path": "res://assets/audio/music/music_shop_campfire_inn.ogg", "loop": true, "loop_offset": 2.15, "gain_db": 0.0},
	"music_combat_bardic_skirmish_a": {"path": "res://assets/audio/music/music_combat_bardic_skirmish_a.ogg", "loop": true, "loop_offset": 0.0, "gain_db": 0.0},
	"music_combat_bardic_skirmish_b": {"path": "res://assets/audio/music/music_combat_bardic_skirmish_b.ogg", "loop": true, "loop_offset": 2.96, "gain_db": 0.0},
	"music_combat_ruined_courtyard": {"path": "res://assets/audio/music/music_combat_ruined_courtyard.ogg", "loop": true, "loop_offset": 2.69, "gain_db": 0.0},
	"music_combat_fey_marsh": {"path": "res://assets/audio/music/music_combat_fey_marsh.ogg", "loop": true, "loop_offset": 2.38, "gain_db": 0.0},
	"music_elite_duel_300": {"path": "res://assets/audio/music/music_elite_duel_300.ogg", "loop": true, "loop_offset": 0.0, "gain_db": 0.0},
	"music_boss_battle_300": {"path": "res://assets/audio/music/music_boss_battle_300.ogg", "loop": true, "loop_offset": 5.31, "gain_db": 0.0},
	"music_final_boss_crescendo_300": {"path": "res://assets/audio/music/music_final_boss_crescendo_300.ogg", "loop": true, "loop_offset": 4.87, "gain_db": 0.0},
	"music_sting_victory": {"path": "res://assets/audio/music/music_sting_victory.ogg", "loop": false, "loop_offset": 0.0, "gain_db": 0.0},
	"music_sting_victory_epic": {"path": "res://assets/audio/music/music_sting_victory_epic.ogg", "loop": false, "loop_offset": 0.0, "gain_db": 0.0},
	"music_sting_defeat": {"path": "res://assets/audio/music/music_sting_defeat.ogg", "loop": false, "loop_offset": 0.0, "gain_db": 0.0},
}

# Обратная совместимость slot-id (существующие вызовы play_music по экранам).
# Легаси "combat"/"boss" роутятся в play_combat_music (см. play_music).
const MUSIC_ALIASES := {
	"menu": "music_menu_tavern_warm",
	"route_map": "music_route_map_bard_journey",
	"shop": "music_shop_campfire_inn",
}

# Ротация обычного боя (shuffle-bag, спека §4) и фиксированные боевые темы.
const COMBAT_ROTATION := [
	"music_combat_bardic_skirmish_a",
	"music_combat_bardic_skirmish_b",
	"music_combat_ruined_courtyard",
	"music_combat_fey_marsh",
]
const COMBAT_KIND_TRACKS := {
	"elite": "music_elite_duel_300",
	"boss": "music_boss_battle_300",
	"final": "music_final_boss_crescendo_300",
}

const MUSIC_CROSSFADE_SEC := 0.9
# Окно scripted outro (спека §3): обычный бой 6 c, элитка/босс/финал 8 c.
const MUSIC_OUTRO_WINDOW_NORMAL := 6.0
const MUSIC_OUTRO_WINDOW_LONG := 8.0
const MUSIC_OUTRO_TARGET_DB := -40.0
# Fade-in/out low-HP лупа зеркалит виньетку (ui_screens: 0.42 / 0.50 c).
const SFX_LOOP_FADE_IN := 0.42
const SFX_LOOP_FADE_OUT := 0.50
const SFX_LOOP_SILENT_DB := -44.0

const SFX_POOL_SIZE := 8
const SFX_MIN_REPEAT_INTERVAL := 0.05
const MUSIC_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0

var _sfx_streams := {}
var _music_streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _music_player_fade: AudioStreamPlayer = null
var _music_stinger_player: AudioStreamPlayer = null
var _music_fade_tween: Tween = null
var _current_music_id := ""
var _last_played_at := {}
var _disabled := false

# Round-timed playback (SCRUM-968).
var _combat_kind := ""              # "" вне боя; battle/elite/boss/final в бою
var _planned_round_duration := 0.0  # телеметрия/предвыбор outro-окна
var _outro_active := false
var _outro_tween: Tween = null
var _outro_anchor: Node = null      # PAUSABLE-якорь: outro-фейд замирает вместе с паузой боя

# Shuffle-bag ротация обычных боевых треков (session-only, спека §4).
var _combat_bag: Array = []
var _last_combat_track := ""

# Лупящиеся SFX-каналы вне пула (low_hp_pulse): id -> AudioStreamPlayer / Tween.
var _sfx_loop_players := {}
var _sfx_loop_tweens := {}
var _sfx_loop_requested := {}
var _sfx_loop_effective := {}
var _low_hp_warning_enabled := true
var _mute_when_unfocused := false
var _application_focused := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	# В headless (smoke tests) звук не микшируется и оставляет висячие
	# AudioStreamPlayback при выходе, поэтому аудио полностью отключается.
	if DisplayServer.get_name() == "headless":
		_disabled = true
		return
	for sfx_id in SFX_PATHS.keys():
		var stream := load(SFX_PATHS[sfx_id]) as AudioStream
		if stream != null:
			_sfx_streams[sfx_id] = stream
	for music_id in MUSIC_META.keys():
		var meta: Dictionary = MUSIC_META[music_id]
		var stream := load(str(meta["path"])) as AudioStream
		if stream == null:
			continue
		if stream is AudioStreamOggVorbis:
			# Луп-регион intro+loop: loop_offset (сек) из мастеринга, .import не правится.
			stream.loop = bool(meta.get("loop", true))
			stream.loop_offset = float(meta.get("loop_offset", 0.0))
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			# SCRUM-646: loop_end измеряется в КАДРАХ, а data — в байтах. Размер кадра =
			# channels * (bits/8); для 16-бит стерео деление на 2 уводило точку лупа
			# вдвое за пределы данных (глитчи лупа).
			var bytes_per_sample := 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channel_count := 2 if stream.stereo else 1
			var frame_bytes := maxi(1, channel_count * bytes_per_sample)
			stream.loop_end = int(stream.data.size() / frame_bytes)
		elif stream is AudioStreamMP3:
			stream.loop = bool(meta.get("loop", true))
		_music_streams[music_id] = stream

	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		_sfx_players.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	# Второй плеер для кроссфейда меню<->бой (играет уходящий трек, пока новый нарастает).
	_music_player_fade = AudioStreamPlayer.new()
	_music_player_fade.bus = "Music"
	_music_player_fade.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player_fade)
	# Стингеры результата — короткие фразы поверх затухающего трека (шина Music).
	_music_stinger_player = AudioStreamPlayer.new()
	_music_stinger_player.bus = "Music"
	_music_stinger_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_stinger_player)
	# Якорь outro-твина: PAUSABLE, чтобы фейд замирал вместе с игровым таймером
	# на паузе (сам трек продолжает играть — AudioManager ALWAYS).
	_outro_anchor = Node.new()
	_outro_anchor.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_outro_anchor)


func _exit_tree() -> void:
	_release_audio_refs()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_application_focused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_application_focused(false)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_audio_refs()


func _release_audio_refs() -> void:
	# Останавливаем и отвязываем стримы, чтобы тесты/оконный quit не ловили
	# "resources still in use at exit" от AudioServer playback handles.
	_current_music_id = ""
	_reset_outro_state()
	for player in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for loop_id in _sfx_loop_players.keys():
		var tween: Tween = _sfx_loop_tweens.get(loop_id)
		if tween != null and tween.is_valid():
			tween.kill()
		var loop_player: AudioStreamPlayer = _sfx_loop_players[loop_id]
		if is_instance_valid(loop_player):
			loop_player.stop()
			loop_player.stream = null
	_sfx_loop_tweens.clear()
	_sfx_loop_requested.clear()
	_sfx_loop_effective.clear()
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	if _music_player_fade != null:
		_music_player_fade.stop()
		_music_player_fade.stream = null
	if _music_stinger_player != null:
		_music_stinger_player.stop()
		_music_stinger_player.stream = null
	_sfx_streams.clear()
	_music_streams.clear()


func _ensure_audio_buses() -> void:
	# Шины создаются программно (default bus layout содержит только Master).
	# UI -> SFX сохраняет SFX как глобальный parent volume/mute.
	var sends := {"Music": "Master", "SFX": "Master", "UI": "SFX"}
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var bus_index := AudioServer.bus_count
			AudioServer.add_bus(bus_index)
			AudioServer.set_bus_name(bus_index, bus_name)
		var resolved_index := AudioServer.get_bus_index(bus_name)
		if resolved_index != -1:
			AudioServer.set_bus_send(resolved_index, str(sends[bus_name]))


func apply_volume_settings(settings: Dictionary) -> void:
	# Мгновенное применение: громкость шин меняется у уже играющих стримов.
	_set_bus_volume("Master", float(settings.get("master_volume", 1.0)), true)
	_set_bus_volume("Music", float(settings.get("music_volume", 1.0)), bool(settings.get("music_enabled", true)))
	_set_bus_volume("SFX", float(settings.get("sfx_volume", 1.0)), bool(settings.get("sfx_enabled", true)))
	_set_bus_volume("UI", float(settings.get("ui_volume", 1.0)), true)
	_mute_when_unfocused = bool(settings.get("mute_when_unfocused", false))
	_low_hp_warning_enabled = bool(settings.get("low_hp_warning_enabled", true))
	_apply_application_focus_mute()
	_refresh_requested_sfx_loop("low_hp_pulse")


func _set_bus_volume(bus_name: String, linear_volume: float, enabled: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, not enabled)


func set_application_focused(focused: bool) -> void:
	_application_focused = focused
	_apply_application_focus_mute()


func _apply_application_focus_mute() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index != -1:
		AudioServer.set_bus_mute(master_index, _mute_when_unfocused and not _application_focused)


func sfx_bus_for_id(sfx_id: String) -> String:
	return "UI" if UI_SFX_IDS.has(sfx_id) else "SFX"


# --- SFX ---------------------------------------------------------------------

func play_sfx(sfx_id: String) -> void:
	if _disabled:
		return
	var stream: AudioStream = _sfx_streams.get(sfx_id)
	if stream == null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var min_interval := float(SFX_THROTTLE_OVERRIDES.get(sfx_id, SFX_MIN_REPEAT_INTERVAL))
	if now - float(_last_played_at.get(sfx_id, -1.0)) < min_interval:
		return
	for player in _sfx_players:
		if not player.playing:
			_last_played_at[sfx_id] = now
			player.bus = sfx_bus_for_id(sfx_id)
			player.stream = stream
			player.play()
			return


func set_sfx_loop(sfx_id: String, active: bool) -> void:
	_sfx_loop_requested[sfx_id] = active
	var effective := active and (sfx_id != "low_hp_pulse" or _low_hp_warning_enabled)
	_sfx_loop_effective[sfx_id] = effective
	_set_sfx_loop_effective(sfx_id, effective)


func _refresh_requested_sfx_loop(sfx_id: String) -> void:
	if _sfx_loop_requested.has(sfx_id):
		set_sfx_loop(sfx_id, bool(_sfx_loop_requested[sfx_id]))


func _set_sfx_loop_effective(sfx_id: String, active: bool) -> void:
	# Лупящийся SFX-канал вне пула (low-HP пульс, спека §5): выделенный плеер на
	# шине SFX, fade-in/out зеркалит виньетку. Повторные вызовы того же состояния —
	# no-op (луп не стакается).
	if _disabled:
		return
	var player: AudioStreamPlayer = _sfx_loop_players.get(sfx_id)
	var tween: Tween = _sfx_loop_tweens.get(sfx_id)
	if active:
		if player != null and is_instance_valid(player) and player.playing:
			# Уже играет: если затухал на выключение — вернуть громкость.
			if tween != null and tween.is_valid():
				tween.kill()
				_sfx_loop_tweens[sfx_id] = _fade_loop_player(player, SFX_VOLUME_DB, SFX_LOOP_FADE_IN, false)
			return
		var stream: AudioStream = _sfx_streams.get(sfx_id)
		if stream == null:
			return
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if player == null or not is_instance_valid(player):
			player = AudioStreamPlayer.new()
			player.bus = "SFX"
			add_child(player)
			_sfx_loop_players[sfx_id] = player
		if tween != null and tween.is_valid():
			tween.kill()
		player.volume_db = SFX_LOOP_SILENT_DB
		player.stream = stream
		player.play()
		_sfx_loop_tweens[sfx_id] = _fade_loop_player(player, SFX_VOLUME_DB, SFX_LOOP_FADE_IN, false)
	else:
		if player == null or not is_instance_valid(player) or not player.playing:
			return
		if tween != null and tween.is_valid():
			tween.kill()
		_sfx_loop_tweens[sfx_id] = _fade_loop_player(player, SFX_LOOP_SILENT_DB, SFX_LOOP_FADE_OUT, true)


func _fade_loop_player(player: AudioStreamPlayer, target_db: float, duration: float, stop_after: bool) -> Tween:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if stop_after:
		# Callable(player,...) умирает вместе с плеером — без freed-lambda (канон SCRUM-551).
		tween.tween_callback(Callable(player, "stop"))
	return tween


# --- Музыка ------------------------------------------------------------------

func play_music(music_id: String) -> void:
	if _disabled:
		return
	# Легаси-роутинг боевых slot-id (вызовы до SCRUM-968 и дев-консоль): бой всегда
	# идёт через ротацию/типовые треки с дефолтной длительностью окна.
	if music_id == "combat":
		play_combat_music("battle", 90.0)
		return
	if music_id == "boss":
		play_combat_music("boss", 300.0)
		return
	_combat_kind = ""
	_planned_round_duration = 0.0
	_play_music_resolved(str(MUSIC_ALIASES.get(music_id, music_id)))


func play_music_timed(music_id: String, planned_duration: float) -> void:
	# Прямой запуск трека с плановой длительностью раунда (телеметрия/outro-окно).
	if _disabled:
		return
	_planned_round_duration = maxf(planned_duration, 0.0)
	_play_music_resolved(str(MUSIC_ALIASES.get(music_id, music_id)))


func play_combat_music(kind: String, planned_duration: float) -> void:
	# kind: "battle" | "elite" | "boss" | "final" (спека §3). battle — shuffle-bag §4.
	if _disabled:
		return
	var track := _select_combat_track(kind)
	_combat_kind = kind if (kind == "battle" or COMBAT_KIND_TRACKS.has(kind)) else "battle"
	_planned_round_duration = maxf(planned_duration, 0.0)
	_play_music_resolved(track)


func reset_combat_rotation() -> void:
	# Старт нового забега: мешок пересыпается заново (session-only, не в autosave).
	# _last_combat_track сохраняем — неповтор подряд действует и через границу забегов.
	if _disabled:
		return
	_combat_bag.clear()


func music_outro_window() -> float:
	# Окно scripted outro для текущего боевого трека (6 c бой / 8 c элитка+боссы).
	if _combat_kind in ["elite", "boss", "final"]:
		return MUSIC_OUTRO_WINDOW_LONG
	return MUSIC_OUTRO_WINDOW_NORMAL


func begin_music_outro(seconds_left: float) -> void:
	# Scripted outro (спека §3): затухание ровно за seconds_left до тишины, куда
	# встают стингер результата и баннер. Идемпотентно в рамках раунда: повторные
	# вызовы игнорируются; play_music*/stop_music сбрасывают состояние.
	if _disabled or _outro_active:
		return
	_outro_active = true
	if _music_player == null or not _music_player.playing:
		return
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
		_music_fade_tween = null
		if _music_player_fade != null:
			_music_player_fade.stop()
	var fade_time := maxf(seconds_left, 0.1)
	# Твин на PAUSABLE-якоре: на паузе фейд замирает синхронно с игровым таймером.
	var host := _outro_anchor if (_outro_anchor != null and is_instance_valid(_outro_anchor)) else self
	_outro_tween = host.create_tween()
	_outro_tween.tween_property(_music_player, "volume_db", MUSIC_OUTRO_TARGET_DB, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_outro_tween.tween_callback(Callable(_music_player, "stop"))


func play_music_stinger(stinger_id: String) -> void:
	# Короткая музыкальная фраза поверх затухающего трека (шина Music, без лупа).
	if _disabled:
		return
	if _music_stinger_player == null:
		return
	var stream: AudioStream = _music_streams.get(stinger_id)
	if stream == null:
		return
	_music_stinger_player.stop()
	_music_stinger_player.volume_db = MUSIC_VOLUME_DB + _music_gain_db(stinger_id)
	_music_stinger_player.stream = stream
	_music_stinger_player.play()


func stop_music() -> void:
	_current_music_id = ""
	_combat_kind = ""
	_planned_round_duration = 0.0
	_reset_outro_state()
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	if _music_player_fade != null:
		_music_player_fade.stop()
		_music_player_fade.stream = null


func _play_music_resolved(music_id: String) -> void:
	# Новый трек всегда сбрасывает outro-состояние (идемпотентность — пер-раунд).
	_reset_outro_state()
	if _music_player == null:
		return
	var target_db := MUSIC_VOLUME_DB + _music_gain_db(music_id)
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
		_music_fade_tween = null
		if _music_player_fade != null:
			_music_player_fade.stop()
	if _current_music_id == music_id and _music_player.playing:
		_music_player.volume_db = target_db
		return
	var stream: AudioStream = _music_streams.get(music_id)
	if stream == null:
		stop_music()
		return
	# Кроссфейд: текущий трек уезжает на fade-плеер и затухает, новый нарастает.
	if _music_player.playing and _current_music_id != "":
		_music_player_fade.stream = _music_player.stream
		_music_player_fade.volume_db = _music_player.volume_db
		_music_player_fade.play(_music_player.get_playback_position())
		_music_player.stop()
		_music_fade_tween = create_tween()
		_music_fade_tween.set_parallel(true)
		_music_fade_tween.tween_property(_music_player_fade, "volume_db", -40.0, MUSIC_CROSSFADE_SEC)
		_music_player.volume_db = -28.0
		_music_fade_tween.tween_property(_music_player, "volume_db", target_db, MUSIC_CROSSFADE_SEC)
		_music_fade_tween.chain().tween_callback(_music_player_fade.stop)
	else:
		_music_player.volume_db = target_db
	_current_music_id = music_id
	_music_player.stream = stream
	_music_player.play()


func _music_gain_db(music_id: String) -> float:
	var meta: Dictionary = MUSIC_META.get(music_id, {})
	return float(meta.get("gain_db", 0.0))


func _reset_outro_state() -> void:
	_outro_active = false
	if _outro_tween != null and _outro_tween.is_valid():
		_outro_tween.kill()
	_outro_tween = null


# --- Ротация боевых треков (shuffle-bag, спека §4) -----------------------------

func _select_combat_track(kind: String) -> String:
	# Чистая логика выбора (без плейбека) — тестируется headless focused-смоуком.
	if kind != "battle" and COMBAT_KIND_TRACKS.has(kind):
		return str(COMBAT_KIND_TRACKS[kind])
	if _combat_bag.is_empty():
		_refill_combat_bag()
	var track := str(_combat_bag.pop_front())
	_last_combat_track = track
	return track


func _refill_combat_bag() -> void:
	# Пересыпка мешка: перемешать 4 трека; первый трек нового мешка не должен
	# совпадать с последним сыгранным (один трек никогда не звучит дважды подряд).
	var bag := COMBAT_ROTATION.duplicate()
	bag.shuffle()
	# Биомный приоритет (SHOULD): акт мягко поднимает свою тему в начало мешка,
	# констрейнт неповтора всегда важнее сортировки.
	var preferred := _act_preferred_track()
	if preferred != "" and preferred != _last_combat_track and bag.has(preferred):
		bag.erase(preferred)
		bag.push_front(preferred)
	elif str(bag[0]) == _last_combat_track:
		var swap_index := 1 + (randi() % (bag.size() - 1))
		var head = bag[0]
		bag[0] = bag[swap_index]
		bag[swap_index] = head
	_combat_bag = bag


func _act_preferred_track() -> String:
	if not is_inside_tree():
		return ""
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var act = scene.get("current_act")
	if act == null:
		return ""
	match clampi(int(act), 1, 3):
		1:
			return "music_combat_bardic_skirmish_a" if (randi() % 2 == 0) else "music_combat_bardic_skirmish_b"
		2:
			return "music_combat_ruined_courtyard"
		_:
			return "music_combat_fey_marsh"
