extends SceneTree

# SCRUM-968: focused-смоук интеграции аудио-пака (headless-safe, без плейбека).
# Покрывает AC тикета:
#   1) новые music/SFX id указывают на существующие и загружаемые ресурсы,
#      loop_offset в пределах длины трека;
#   2) ротация обычного боя: 4 трека, без повтора подряд, полное покрытие мешка;
#   3) elite/boss/final выбирают свои треки;
#   4) begin_music_outro идемпотентен в рамках раунда, окно outro по типу боя;
#   5) low-HP cue: гистерезис ВКЛ<30% / ВЫКЛ>=34% (зеркалит виньетку);
#   6) типизированные хиты physical/magic/dot/true -> валидные SFX id;
#   7) headless: play_* / set_sfx_loop / reset_combat_rotation — no-op без ошибок.
#
# Запуск: Godot --headless --path . --script res://tests/audio_integration_test.gd

const AudioManagerScript := preload("res://scripts/audio_manager.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")


func _initialize() -> void:
	await process_frame
	var errors: Array = []

	var audio: Node = root.get_node_or_null("/root/AudioManager")
	var spawned := false
	if audio == null:
		audio = AudioManagerScript.new()
		root.add_child(audio)
		spawned = true
		await process_frame

	_check_asset_tables(errors)
	_check_headless_noop(errors, audio)
	_check_rotation(errors)
	_check_outro_idempotence(errors)
	_check_low_hp_hysteresis(errors)
	_check_typed_hits(errors)

	if spawned:
		audio.queue_free()
		await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Audio integration: %s" % e)
		push_error("Audio integration test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Audio integration test passed (id-таблицы, ротация, outro, low-HP гистерезис, типизированные хиты, headless no-op).")
	quit(0)


func _check_asset_tables(errors: Array) -> void:
	# Все SFX id из спеки §5 присутствуют и загружаются.
	var required_sfx := [
		"hit", "hit_magic", "hit_dot", "player_hit", "dodge",
		"pickup_xp", "pickup_money", "level_up", "purchase",
		"ui_click", "ui_back", "ui_error", "artifact_reveal",
		"boss_phase", "low_hp_pulse",
	]
	for sfx_id in required_sfx:
		if not AudioManagerScript.SFX_PATHS.has(sfx_id):
			errors.append("SFX_PATHS без id '%s'" % sfx_id)
			continue
		var stream := load(str(AudioManagerScript.SFX_PATHS[sfx_id])) as AudioStream
		if stream == null:
			errors.append("SFX '%s' не загружается" % sfx_id)

	# Музыка: 10 треков + 3 стингера, файлы загружаются, loop_offset < длины.
	if AudioManagerScript.MUSIC_META.size() != 13:
		errors.append("MUSIC_META: ожидалось 13 записей, найдено %d" % AudioManagerScript.MUSIC_META.size())
	for music_id in AudioManagerScript.MUSIC_META:
		var meta: Dictionary = AudioManagerScript.MUSIC_META[music_id]
		var stream := load(str(meta.get("path", ""))) as AudioStream
		if stream == null:
			errors.append("музыка '%s' не загружается (%s)" % [music_id, meta.get("path", "")])
			continue
		var length := stream.get_length()
		var loop_offset := float(meta.get("loop_offset", 0.0))
		if loop_offset < 0.0 or (length > 0.0 and loop_offset >= length):
			errors.append("музыка '%s': loop_offset %.2f вне длины %.2f" % [music_id, loop_offset, length])
	# Стингеры не лупятся.
	for sting_id in ["music_sting_victory", "music_sting_victory_epic", "music_sting_defeat"]:
		if not AudioManagerScript.MUSIC_META.has(sting_id):
			errors.append("MUSIC_META без стингера '%s'" % sting_id)
		elif bool((AudioManagerScript.MUSIC_META[sting_id] as Dictionary).get("loop", false)):
			errors.append("стингер '%s' помечен loop=true" % sting_id)
	# Обратная совместимость slot-id экранов.
	for alias in ["menu", "route_map", "shop"]:
		if not AudioManagerScript.MUSIC_ALIASES.has(alias):
			errors.append("MUSIC_ALIASES без slot-id '%s'" % alias)
	# Ротация — минимум 4 обычных боевых трека (AC тикета).
	if AudioManagerScript.COMBAT_ROTATION.size() < 4:
		errors.append("COMBAT_ROTATION меньше 4 треков")


func _check_headless_noop(errors: Array, audio: Node) -> void:
	# Autoload/инстанс в headless обязан быть _disabled и глотать все новые API.
	if not bool(audio.get("_disabled")):
		errors.append("headless-инстанс не _disabled")
		return
	audio.play_music("menu")
	audio.play_music("combat")
	audio.play_music_timed("music_combat_fey_marsh", 90.0)
	audio.play_combat_music("battle", 75.0)
	audio.play_combat_music("boss", 300.0)
	audio.begin_music_outro(6.0)
	audio.play_music_stinger("music_sting_victory")
	audio.set_sfx_loop("low_hp_pulse", true)
	audio.set_sfx_loop("low_hp_pulse", false)
	audio.reset_combat_rotation()
	audio.stop_music()
	if not (audio.get("_sfx_loop_players") as Dictionary).is_empty():
		errors.append("headless set_sfx_loop создал плееры (ожидался no-op)")
	if bool(audio.get("_outro_active")):
		errors.append("headless begin_music_outro взвёл _outro_active (ожидался no-op)")


func _check_rotation(errors: Array) -> void:
	# Чистая логика shuffle-bag: свежий инстанс вне дерева, без плейбека.
	var audio := AudioManagerScript.new()
	# 16 обычных боёв = 4 полных мешка: без повтора подряд, каждый мешок = все 4 трека.
	var draws: Array = []
	for i in range(16):
		draws.append(audio._select_combat_track("battle"))
	for i in range(1, draws.size()):
		if draws[i] == draws[i - 1]:
			errors.append("ротация повторила трек подряд на шаге %d: %s" % [i, draws[i]])
	for bag_index in range(4):
		var window := {}
		for i in range(4):
			window[draws[bag_index * 4 + i]] = true
		if window.size() != 4:
			errors.append("мешок %d не покрыл все 4 трека: %s" % [bag_index, str(draws.slice(bag_index * 4, bag_index * 4 + 4))])
	for track in draws:
		if not AudioManagerScript.COMBAT_ROTATION.has(track):
			errors.append("ротация выдала не-боевой трек '%s'" % track)

	# Типовые бои — фиксированные темы, ротацию не трогают.
	if audio._select_combat_track("elite") != "music_elite_duel_300":
		errors.append("elite выбрал не music_elite_duel_300")
	if audio._select_combat_track("boss") != "music_boss_battle_300":
		errors.append("boss выбрал не music_boss_battle_300")
	if audio._select_combat_track("final") != "music_final_boss_crescendo_300":
		errors.append("final выбрал не music_final_boss_crescendo_300")

	# reset_combat_rotation пересыпает мешок; неповтор держится и через сброс.
	audio.set("_disabled", false)
	var last := str(draws[draws.size() - 1])
	audio.reset_combat_rotation()
	if not (audio.get("_combat_bag") as Array).is_empty():
		errors.append("reset_combat_rotation не опустошил мешок")
	var after_reset := str(audio._select_combat_track("battle"))
	if after_reset == last:
		errors.append("первый трек после reset повторил последний сыгранный (%s)" % last)
	audio.free()


func _check_outro_idempotence(errors: Array) -> void:
	# Логика флага без плееров (в headless _ready не создаёт их): включаем API
	# через _disabled=false — плеер null, плейбек не затрагивается.
	var audio := AudioManagerScript.new()
	audio.set("_disabled", false)
	if float(audio.music_outro_window()) != AudioManagerScript.MUSIC_OUTRO_WINDOW_NORMAL:
		errors.append("окно outro вне боя должно быть NORMAL (6 c)")
	audio.set("_combat_kind", "elite")
	if float(audio.music_outro_window()) != AudioManagerScript.MUSIC_OUTRO_WINDOW_LONG:
		errors.append("окно outro элитки должно быть LONG (8 c)")
	audio.set("_combat_kind", "battle")
	if float(audio.music_outro_window()) != AudioManagerScript.MUSIC_OUTRO_WINDOW_NORMAL:
		errors.append("окно outro обычного боя должно быть NORMAL (6 c)")

	audio.begin_music_outro(6.0)
	if not bool(audio.get("_outro_active")):
		errors.append("begin_music_outro не взвёл _outro_active")
	# Повторный вызов в том же раунде игнорируется (не падает, состояние стабильно).
	audio.begin_music_outro(1.2)
	if not bool(audio.get("_outro_active")):
		errors.append("повторный begin_music_outro сломал состояние outro")
	# stop_music сбрасывает — следующий раунд снова может затухать.
	audio.stop_music()
	if bool(audio.get("_outro_active")):
		errors.append("stop_music не сбросил _outro_active")
	audio.begin_music_outro(8.0)
	if not bool(audio.get("_outro_active")):
		errors.append("outro не взводится заново после stop_music")
	audio.free()


func _check_low_hp_hysteresis(errors: Array) -> void:
	# Пороги зеркалят виньетку: ВКЛ < 0.30, ВЫКЛ >= 0.34, между — держит состояние.
	var cases := [
		# [активен_сейчас, hp_ratio, ожидание]
		[false, 1.00, false],
		[false, 0.34, false],
		[false, 0.31, false],  # мёртвая зона не включает
		[false, 0.299, true],  # ниже ON — включение
		[true, 0.299, true],
		[true, 0.31, true],    # мёртвая зона держит включённым
		[true, 0.339, true],
		[true, 0.34, false],   # от OFF и выше — выключение
		[true, 0.50, false],
		[false, 0.0, true],
	]
	for case in cases:
		var got: bool = PlayerScript.low_hp_cue_should_be_active(bool(case[0]), float(case[1]))
		if got != bool(case[2]):
			errors.append("low_hp гистерезис (active=%s, ratio=%.3f) -> %s, ожидалось %s" % [case[0], case[1], got, case[2]])


func _check_typed_hits(errors: Array) -> void:
	var cases := {
		"physical": "hit",
		"magic": "hit_magic",
		"dot": "hit_dot",
		"true": "hit",
		"": "hit",
		"unknown_axis": "hit",
	}
	for damage_type in cases:
		var got: String = EnemyScript.hit_sfx_for_damage_type(damage_type)
		if got != str(cases[damage_type]):
			errors.append("hit_sfx_for_damage_type('%s') -> '%s', ожидалось '%s'" % [damage_type, got, cases[damage_type]])
		if not AudioManagerScript.SFX_PATHS.has(got):
			errors.append("типизированный хит '%s' указывает на несуществующий SFX id '%s'" % [damage_type, got])
