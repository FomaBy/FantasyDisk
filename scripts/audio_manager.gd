extends Node

# Autoload: AudioManager. Central SFX/music playback with a small player pool
# and per-sound throttling so crowd damage does not spam identical sounds.

const SFX_PATHS := {
	"hit": "res://assets/audio/sfx_hit.wav",
	"player_hit": "res://assets/audio/sfx_player_hit.wav",
	"dodge": "res://assets/audio/sfx_dodge.wav",
	"pickup_xp": "res://assets/audio/sfx_pickup_xp.wav",
	"pickup_money": "res://assets/audio/sfx_pickup_money.wav",
	"level_up": "res://assets/audio/sfx_level_up.wav",
}

const MUSIC_PATHS := {
	"menu": "res://assets/audio/music_menu.wav",
	"combat": "res://assets/audio/music_combat.wav",
}

const SFX_POOL_SIZE := 8
const SFX_MIN_REPEAT_INTERVAL := 0.05
const MUSIC_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -4.0

var _sfx_streams := {}
var _music_streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _current_music_id := ""
var _last_played_at := {}
var _disabled := false


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
	for music_id in MUSIC_PATHS.keys():
		var stream := load(MUSIC_PATHS[music_id]) as AudioStream
		if stream != null:
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = int(stream.data.size() / 2.0)
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


func _exit_tree() -> void:
	_release_audio_refs()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_audio_refs()


func _release_audio_refs() -> void:
	# Останавливаем и отвязываем стримы, чтобы тесты/оконный quit не ловили
	# "resources still in use at exit" от AudioServer playback handles.
	_current_music_id = ""
	for player in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	_sfx_streams.clear()
	_music_streams.clear()


func _ensure_audio_buses() -> void:
	# Шины Music/SFX создаются программно (default bus layout содержит только Master).
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var bus_index := AudioServer.bus_count
			AudioServer.add_bus(bus_index)
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, "Master")


func apply_volume_settings(settings: Dictionary) -> void:
	# Мгновенное применение: громкость шин меняется у уже играющих стримов.
	_set_bus_volume("Master", float(settings.get("master_volume", 1.0)), true)
	_set_bus_volume("Music", float(settings.get("music_volume", 1.0)), bool(settings.get("music_enabled", true)))
	_set_bus_volume("SFX", float(settings.get("sfx_volume", 1.0)), bool(settings.get("sfx_enabled", true)))


func _set_bus_volume(bus_name: String, linear_volume: float, enabled: bool) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, not enabled or volume <= 0.0)


func play_sfx(sfx_id: String) -> void:
	if _disabled:
		return
	var stream: AudioStream = _sfx_streams.get(sfx_id)
	if stream == null:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last_played_at.get(sfx_id, -1.0)) < SFX_MIN_REPEAT_INTERVAL:
		return
	for player in _sfx_players:
		if not player.playing:
			_last_played_at[sfx_id] = now
			player.stream = stream
			player.play()
			return


func play_music(music_id: String) -> void:
	if _disabled:
		return
	if _current_music_id == music_id and _music_player.playing:
		return
	var stream: AudioStream = _music_streams.get(music_id)
	if stream == null:
		stop_music()
		return
	_current_music_id = music_id
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_current_music_id = ""
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
