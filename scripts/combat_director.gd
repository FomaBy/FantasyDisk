extends RefCounted

const SCENE_CONTRACTS := preload("res://scripts/scene_contracts.gd")
const LORE_DATA := preload("res://scripts/lore_data.gd")
const CODEX_DATA := preload("res://scripts/codex_data.gd")
# FAN-1447: Encounter Beat Director — вся логика в scripts/encounters/**.
const ENCOUNTER_ADAPTER := preload("res://scripts/encounters/encounter_adapter.gd")
const ENCOUNTER_CONTEXT := preload("res://scripts/encounters/encounter_context.gd")

# Боевой цикл: старт/конец боя, спавн волн, баланс врагов/элиток/боссов,
# арена, pickups и снапшот игрока между узлами.

var game
var _encounters := ENCOUNTER_ADAPTER.new()

const TRANSIENT_RUN_MODIFIER_KEYS := [
	"dodge_rush_active",
	"low_hp_active",
	"crit_speed_burst_active",
	"rush_window_active",
	"hurt_active",
	"stance_active",
	"swarm_fraction",
	"riff_streak_active",
	"reactor_heat_active",
	"ultimate_berserk_active",
	# SCRUM-961: runtime-гейты классовых артефактов (молитва/стаки ярости).
	"prayer_opening_active",
	"rage_hit_damage_bonus",
	"rage_hit_attack_speed_bonus",
]
const TRANSIENT_BERSERK_ULTIMATE_MULTIPLIERS := {
	"attack_speed_multiplier": 1.35,
	"move_speed_multiplier": 1.18,
}
const NORMAL_SPAWN_PRESSURE_BASE := 1.14
const NORMAL_SPAWN_PRESSURE_STAGE_STEP := 0.018
const NORMAL_SPAWN_PRESSURE_WAVE_STEP := 0.014
const NORMAL_SPAWN_PRESSURE_ELAPSED_STEP := 0.16
const NORMAL_SPAWN_PRESSURE_MAX := 1.55
const ENEMY_HP_PRESSURE_BASE := 1.05
const ENEMY_HP_PRESSURE_STAGE_STEP := 0.018
const ENEMY_HP_PRESSURE_WAVE_STEP := 0.006
const ENEMY_HP_PRESSURE_ELAPSED_STEP := 0.06
const ENEMY_HP_PRESSURE_MAX := 1.38
const ENEMY_DAMAGE_PRESSURE_BASE := 1.03
const ENEMY_DAMAGE_PRESSURE_STAGE_STEP := 0.010
const ENEMY_DAMAGE_PRESSURE_WAVE_STEP := 0.004
const ENEMY_DAMAGE_PRESSURE_ELAPSED_STEP := 0.05
const ENEMY_DAMAGE_PRESSURE_MAX := 1.24
const SPAWN_COOLDOWN_ELAPSED_PRESSURE := 0.22
const ADVANCED_MOB_ACT_STAGE := 4
const ADVANCED_SHOOTER_WEIGHT_STEP := 0.10
const ADVANCED_SUMMONER_WEIGHT_STEP := 0.12
const ADVANCED_HEAVY_WEIGHT_STEP := 0.06
const ADVANCED_SHOOTER_WEIGHT_MAX := 2.00
const ADVANCED_SUMMONER_WEIGHT_MAX := 2.20
const ADVANCED_HEAVY_WEIGHT_MAX := 1.66
const BOSS_DEATH_VICTORY_DELAY := 2.0
# Этап B (спавн-защита): pack-члены/свита/given-position спавны — минимум до
# живого игрока (edge-спавны фильтруются шире, SPAWN_PLAYER_SAFE_RADIUS=420).
const GIVEN_SPAWN_MIN_PLAYER_DISTANCE := 320.0
const BOSS_VICTORY_PRESSURE_GROUPS := ["enemies", "summoned_enemies", "projectiles", "enemy_projectiles", "enemy_hazards"]

# SCRUM-528: «элитка реально убита в этом бою». Награда элитного узла (выбор
# артефакта 1 из 3) гейтится этим флагом — победа по таймеру с ЖИВОЙ элиткой
# награду не выдаёт. Сбрасывается в начале каждого боя (_start_combat),
# выставляется в _on_enemy_died по достоверному сигналу `died` (а не по
# наивному подсчёту группы elite_enemies — узел освобождается с задержкой).
# Живёт в боевом состоянии (не в сейве): при load элитного боя элитка
# восстанавливается живой, поэтому флаг честно стартует с false.
var _elite_defeated := false
var _boss_victory_pending := false
var _combat_start_finalized := false
var _combat_start_in_progress := false
var _combat_start_generation := 0


func _init(game_ref) -> void:
	game = game_ref


# SCRUM-785: достоверный сигнал «элитка убита в этом бою» (для win-by-kill в _process).
func is_elite_defeated() -> bool:
	return _elite_defeated


func is_boss_victory_pending() -> bool:
	return _boss_victory_pending


func request_boss_victory_after_death() -> void:
	if _boss_victory_pending or not game.combat_active:
		return
	_boss_victory_pending = true
	_clear_boss_victory_pressure()
	var tree: SceneTree = game.get_tree()
	if tree == null:
		_end_combat(true)
		return
	var timer: SceneTreeTimer = tree.create_timer(BOSS_DEATH_VICTORY_DELAY, false, false, true)
	timer.timeout.connect(func() -> void:
		if not _boss_victory_pending or not game.combat_active:
			return
		_boss_victory_pending = false
		_end_combat(true)
	)


func _clear_boss_victory_pressure() -> void:
	for group_name in BOSS_VICTORY_PRESSURE_GROUPS:
		for node in game.get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node) and not node.is_in_group("bosses"):
				node.queue_free()


static func normal_spawn_pressure_multiplier(route_scaling_stage: int, wave_index: int, elapsed_ratio: float) -> float:
	var stage := maxf(float(route_scaling_stage), 0.0)
	var wave := maxf(float(wave_index), 0.0)
	var elapsed := clampf(elapsed_ratio, 0.0, 1.0)
	var value := NORMAL_SPAWN_PRESSURE_BASE \
		+ stage * NORMAL_SPAWN_PRESSURE_STAGE_STEP \
		+ wave * NORMAL_SPAWN_PRESSURE_WAVE_STEP \
		+ elapsed * NORMAL_SPAWN_PRESSURE_ELAPSED_STEP
	return clampf(value, 1.0, NORMAL_SPAWN_PRESSURE_MAX)


static func enemy_health_pressure_multiplier(route_scaling_stage: int, wave_index: int, elapsed_ratio: float) -> float:
	var stage := maxf(float(route_scaling_stage), 0.0)
	var wave := maxf(float(wave_index), 0.0)
	var elapsed := clampf(elapsed_ratio, 0.0, 1.0)
	var value := ENEMY_HP_PRESSURE_BASE \
		+ stage * ENEMY_HP_PRESSURE_STAGE_STEP \
		+ wave * ENEMY_HP_PRESSURE_WAVE_STEP \
		+ elapsed * ENEMY_HP_PRESSURE_ELAPSED_STEP
	return clampf(value, 1.0, ENEMY_HP_PRESSURE_MAX)


static func enemy_damage_pressure_multiplier(route_scaling_stage: int, wave_index: int, elapsed_ratio: float) -> float:
	var stage := maxf(float(route_scaling_stage), 0.0)
	var wave := maxf(float(wave_index), 0.0)
	var elapsed := clampf(elapsed_ratio, 0.0, 1.0)
	var value := ENEMY_DAMAGE_PRESSURE_BASE \
		+ stage * ENEMY_DAMAGE_PRESSURE_STAGE_STEP \
		+ wave * ENEMY_DAMAGE_PRESSURE_WAVE_STEP \
		+ elapsed * ENEMY_DAMAGE_PRESSURE_ELAPSED_STEP
	return clampf(value, 1.0, ENEMY_DAMAGE_PRESSURE_MAX)


static func mini_elite_pressure_chance(route_scaling_stage: int, wave_index: int, elapsed_ratio: float) -> float:
	var chance := 0.015 \
		+ maxf(float(route_scaling_stage), 0.0) * 0.006 \
		+ maxf(float(wave_index), 0.0) * 0.001 \
		+ clampf(elapsed_ratio, 0.0, 1.0) * 0.025
	return clampf(chance, 0.0, 0.12)


static func advanced_spawn_weight_multiplier(enemy_kind: String, route_scaling_stage: int) -> float:
	var act_pressure_stage := maxf(float(route_scaling_stage - ADVANCED_MOB_ACT_STAGE + 1), 0.0)
	match enemy_kind:
		"shooter":
			return minf(1.0 + act_pressure_stage * ADVANCED_SHOOTER_WEIGHT_STEP, ADVANCED_SHOOTER_WEIGHT_MAX)
		"summoner":
			return minf(1.0 + act_pressure_stage * ADVANCED_SUMMONER_WEIGHT_STEP, ADVANCED_SUMMONER_WEIGHT_MAX)
		"heavy":
			return minf(1.0 + act_pressure_stage * ADVANCED_HEAVY_WEIGHT_STEP, ADVANCED_HEAVY_WEIGHT_MAX)
		_:
			return 1.0


func _start_combat(is_boss_fight := false, combat_type := "battle") -> void:
	# SCRUM-1071: route/event/dev-console signals may converge in the same frame.
	# A currently-building combat always owns the transition. `combat_active`
	# alone is not authoritative: route-map boundary helpers clear Player/HUD/UI
	# directly and legacy/test paths can leave the boolean stale. Only a complete,
	# owned live generation (Player + matching generation + HUD) makes a repeated
	# trigger an idempotent no-op. Otherwise normalize stale flags and start the
	# route-selected combat normally.
	if _combat_start_in_progress:
		return
	if game.combat_active:
		if _has_live_owned_combat_generation():
			return
		game.combat_active = false
		game.boss_combat_active = false
	_combat_start_in_progress = true
	# SCRUM-1000: бой не должен рождаться под чужой паузой (консольные fight/act
	# в обход экранов). Штатные входы (клик узла карты, событие) приходят без
	# pause-причин — для них это no-op. Симметрично гарду в _end_combat.
	game._clear_all_game_pauses()
	_boss_victory_pending = false
	_combat_start_finalized = false
	game.reset_run_ascension()
	game._clear_ui()
	game._clear_world()
	_setup_arena_world(is_boss_fight)

	game.combat_active = true
	game.boss_combat_active = is_boss_fight
	game.current_combat_type = "boss" if is_boss_fight else combat_type
	# SCRUM-785: длительность зависит от типа боя — выставляем после current_combat_type.
	game.round_time_left = _current_round_duration()
	# SCRUM-968: боевой трек по типу узла + реальная длительность раунда (спека §3):
	# ротация обычного боя, элитная дуэль, босс актов 1-2, финальный/секретный босс.
	_play_combat_start_music()
	# SCRUM-784: первая волна выходит почти мгновенно (наполняем экран в первую секунду).
	game.spawn_cooldown = 0.1
	game.spawn_wave_index = 0
	game.active_spawn_edges.clear()
	_elite_defeated = false  # SCRUM-528: чистый старт — без протечки из прошлого узла
	game.ui._create_hud()

	game.current_player = game.player_scene.instantiate() as Node2D
	if game.current_player == null:
		game.combat_active = false
		game.boss_combat_active = false
		_combat_start_in_progress = false
		push_error("SCRUM-1071: combat Player scene could not be instantiated")
		return
	game.add_child(game.current_player)
	game._register_player_lifecycle_node(game.current_player, game.PLAYER_LIFECYCLE_COMBAT)
	_combat_start_generation += 1
	game.current_player.set_meta("combat_start_generation", _combat_start_generation)
	game.current_player.global_position = game.ARENA_CENTER
	_configure_player_camera(game.current_player)

	if game.current_player.has_method("configure_character"):
		if game.run_player_snapshot.is_empty():
			game.current_player.configure_character(game.selected_character_id, game.selected_weapon_id)
			game.apply_ascension_bonuses(game.current_player)
		else:
			_restore_player_snapshot(game.current_player)

	if game.current_player.has_signal("died"):
		game.current_player.died.connect(func() -> void:
			_end_combat(false)
		)
	if game.current_player.has_signal("leveled_up"):
		game.current_player.leveled_up.connect(game.ui._on_player_leveled_up)
	if game.current_player.has_signal("damaged"):
		game.current_player.damaged.connect(game.ui._on_player_damaged)

	# SCRUM-926: a Priest must choose exactly one prayer before battle hooks and
	# objective spawn. Non-Priest classes keep the synchronous path.
	var prayer_choices: Array = []
	if game.current_player.has_method("battle_prayer_choices"):
		prayer_choices = game.current_player.call("battle_prayer_choices")
	if not prayer_choices.is_empty() and str(game.current_player.call("active_battle_prayer_id")) == "":
		if game.ui.has_method("show_battle_prayer_choice") and game.ui.show_battle_prayer_choice(game.current_player, Callable(self, "_finalize_combat_start")):
			return
		_combat_start_in_progress = false
		push_error("SCRUM-926: mandatory battle prayer UI could not be opened")
		return
	_finalize_combat_start()


func _has_live_owned_combat_generation() -> bool:
	if not game.combat_active:
		return false
	var player := game.current_player as Node
	if player == null or not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree():
		return false
	if not player.is_in_group("player"):
		return false
	if int(player.get_meta(game.PLAYER_LIFECYCLE_OWNER_META, 0)) != game.get_instance_id():
		return false
	if StringName(player.get_meta(game.PLAYER_LIFECYCLE_ROLE_META, &"")) != game.PLAYER_LIFECYCLE_COMBAT:
		return false
	if int(player.get_meta("combat_start_generation", -1)) != _combat_start_generation:
		return false
	var hud := game.hud_layer as CanvasLayer
	if hud == null or not is_instance_valid(hud) or hud.is_queued_for_deletion() or not hud.is_inside_tree():
		return false
	return hud.find_child("CombatHudRoot", true, false) != null


func _finalize_combat_start() -> void:
	if _combat_start_finalized or not game.combat_active:
		return
	_combat_start_finalized = true
	_combat_start_in_progress = false
	# SCRUM-961: battle-start artifact hooks run only after the prayer choice.
	if game.current_player != null and is_instance_valid(game.current_player) and game.current_player.has_method("on_battle_start"):
		game.current_player.on_battle_start()
	game.ui._update_hud()
	if game.boss_combat_active:
		_spawn_boss()
	elif game.current_combat_type == "elite":
		_spawn_elite_enemy()
	_encounters.begin(game, self)


func _configure_player_camera(player: Node2D) -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.zoom = game.COMBAT_CAMERA_ZOOM
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(game.ARENA_SIZE.x)
	camera.limit_bottom = int(game.ARENA_SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0


func _shake_camera(intensity: float, duration := 0.22) -> void:
	# Умеренная тряска (тумблер game.screen_shake_enabled): короткие затухающие
	# толчки смещения камеры игрока. Твин привязан к камере — гибнет вместе с ней.
	if not game.screen_shake_enabled:
		return
	if game.current_player == null or not is_instance_valid(game.current_player):
		return
	var camera := game.current_player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var tween := camera.create_tween()
	var steps := 6
	for i in range(steps):
		var falloff: float = 1.0 - float(i) / float(steps)
		var off: Vector2 = Vector2(game.rng.randf_range(-1.0, 1.0), game.rng.randf_range(-1.0, 1.0)) * intensity * falloff
		tween.tween_property(camera, "offset", off, duration / float(steps))
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / float(steps))


func _hit_stop(duration := 0.3, time_scale := 0.32) -> void:
	# Триумф на смерти элитки/босса: кратко замедляем РЕАЛЬНОЕ время, затем
	# восстанавливаем (таймер игнорирует time_scale, переживает паузу).
	if Engine.time_scale < 0.99:
		return
	Engine.time_scale = time_scale
	var timer: SceneTreeTimer = game.get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_restore_time_scale)


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0


func _end_combat(victory: bool) -> void:
	if not game.combat_active:
		return
	_combat_start_in_progress = false

	# FAN-1447: терминальная остановка бита ДО очистки мира/HUD.
	_encounters.shutdown(victory)

	# SCRUM-1000: канонический конец боя снимает ВСЕ внутрибоевые pause-причины.
	# Штатные пути (win/lose из main._process, died-сигнал игрока) недостижимы при
	# активной паузе (main._process гейтится get_tree().paused), поэтому для них
	# это no-op. Обходные пути (дев-консоль win/die при открытом level-up/досье/
	# фидбеке) без этого оставляли get_tree().paused=true навсегда: победный флоу
	# сносит pause-экран через _clear_ui без pop_pause, и следующий бой рождался
	# мёртвым — без спавна волн, тика таймера, инпута и обновления камеры
	# (игроку видна только верхняя-левая четверть арены).
	game._clear_all_game_pauses()
	_boss_victory_pending = false
	var was_boss_fight = game.boss_combat_active
	var was_elite_fight := str(game.current_combat_type) == "elite"
	# SCRUM-528/785: артефакт-награда элитного узла — только если элитка реально убита.
	# С SCRUM-785 элитный бой завершается победой ТОЛЬКО при убийстве элитки
	# (таймаут с живой элиткой = поражение), поэтому victory в элитке всегда влечёт
	# награду. Флаг оставляем как двойную защиту. Снимаем значение здесь (до закрытия
	# баннера), чтобы замыкание не зависело от последующей мутации поля.
	var grant_elite_reward := was_elite_fight and _elite_defeated
	var event_combat: Dictionary = game.pending_event_combat.duplicate(true)
	# SCRUM-968: музыкальный финал раунда — fast-outro при раннем конце (босс/элитка
	# убиты до таймера, смерть игрока; при штатном таймауте outro уже идёт —
	# begin_music_outro идемпотентен) + стингер результата + снятие low-HP лупа.
	_play_combat_result_audio(victory, was_boss_fight, was_elite_fight)
	game.combat_active = false
	game.boss_combat_active = false
	if game.current_player != null and is_instance_valid(game.current_player):
		if victory:
			# SCRUM-500 (on_room_clear): «Передышка» — лечение по завершении боя (до снапшота).
			var room_clear_heal := float((game.current_player.get("run_modifiers") as Dictionary).get("room_clear_heal_percent", 0.0))
			if room_clear_heal > 0.0 and game.current_player.has_method("heal_percent"):
				game.current_player.heal_percent(room_clear_heal)
			if was_boss_fight:
				_grant_boss_completion_rewards()
			else:
				_grant_combat_completion_rewards(event_combat)
		# SCRUM-502: снять актуальные данные игрока (level/money/artifacts) ДО
		# _clear_world/queue_free — иначе run_player_snapshot был бы от прошлого узла
		# (на смерти особенно критично: иначе снапшот остался бы от предыдущего узла).
		_store_player_snapshot(game.current_player)
	game.boss_hud_target = null  # SCRUM-874: узел закончился — боссбар гаснет
	game._clear_world()
	game._clear_hud()
	game.pending_event_combat.clear()

	if victory:
		if was_boss_fight:
			var proceed_after_boss := func() -> void:
				if game.advance_to_next_act():
					game.current_combat_type = "battle"
					game.route._show_battle_map()
				elif game.should_start_secret_boss_after_final_act():
					game.current_combat_type = "boss"
					game.start_secret_boss_encounter()
				else:
					# SCRUM-502: финальный босс повержен — снять метрики-финалы + причину исхода.
					game.capture_run_metrics_finals(game.run_player_snapshot)
					var final_boss_name := str(game.run_metrics.get("last_boss_name", "финальный босс"))
					game.run_metrics["outcome_reason"] = "Повержен финальный босс: %s" % final_boss_name
					game.record_boss_victory()
					game.ui._show_victory_screen()
			# SCRUM-873: выбор 1 из 3 суперредких артефактов за акт-босса — только
			# пока забег продолжается (следующий акт или секретный босс). После
			# финального босса выбор бессмыслен — сразу экран победы.
			if game.current_act < game.ACT_COUNT or game.should_start_secret_boss_after_final_act():
				game.ui._show_boss_artifact_reward(proceed_after_boss)
			else:
				proceed_after_boss.call()
		else:
			game.route_stage += 1
			game.current_combat_type = "battle"
			# Победный флоу: затемнение + «Победа» -> докачка атрибутов -> карта.
			# Новый бой = новое окно докачки: набор и rerolls легально сбрасываются.
			game.attribute_offer = []
			game.attribute_rerolls_left = game.ui.ATTRIBUTE_REROLLS_PER_WINDOW
			var proceed_to_map := _combat_victory_map_continuation(event_combat)
			game.ui._show_victory_banner(func() -> void:
				if grant_elite_reward:
					game.ui._show_elite_artifact_reward(func() -> void:
						game.ui._show_attribute_shop(proceed_to_map)
					)
				else:
					game.ui._show_attribute_shop(proceed_to_map)
			)
	else:
		# SCRUM-502: смерть — снять метрики-финалы из обновлённого снапшота + причину исхода.
		game.capture_run_metrics_finals(game.run_player_snapshot)
		# SCRUM-785: поражение по таймауту (5 минут вышли, элитка/босс ещё живы).
		var timed_out: bool = float(game.round_time_left) <= 0.0
		if str(game.run_metrics.get("outcome_reason", "")) == "":
			if was_boss_fight:
				var killer_boss := str(game.run_metrics.get("last_boss_name", "босс"))
				if timed_out:
					game.run_metrics["outcome_reason"] = "Не успел убить босса за 5 минут: %s" % killer_boss
				else:
					game.run_metrics["outcome_reason"] = "Пал в бою с боссом: %s" % killer_boss
			elif was_elite_fight and timed_out:
				game.run_metrics["outcome_reason"] = "Не успел убить элиту за 5 минут"
			else:
				game.run_metrics["outcome_reason"] = "Пал в бою на этапе маршрута %d" % (game.route_stage + 1)
		game.ui._show_death_screen()


func _play_combat_start_music() -> void:
	# SCRUM-968 (спека §3, «Точки вызова»): kind боевого трека по типу узла.
	# Босс промежуточного акта -> "boss"; босс финального акта и секретный босс -> "final";
	# элитка -> "elite"; всё остальное -> "battle" (shuffle-bag ротация §4).
	# Длительность — реальный round_time_left (учитывает Возвышение и 300с элиток/боссов).
	var audio: Node = game.get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	var kind := "battle"
	if game.boss_combat_active:
		kind = "final" if (game.secret_boss_active or game.current_act >= game.ACT_COUNT) else "boss"
	elif str(game.current_combat_type) == "elite":
		kind = "elite"
	if audio.has_method("play_combat_music"):
		audio.play_combat_music(kind, float(game.round_time_left))
	elif audio.has_method("play_music"):
		# Fallback на легаси-API (не должен срабатывать после SCRUM-968).
		audio.play_music("boss" if game.boss_combat_active else "combat")


func _play_combat_result_audio(victory: bool, was_boss_fight: bool, was_elite_fight: bool) -> void:
	# SCRUM-968 (спека §3, п.4): ранний конец раунда — fast-outro 1.2 c + стингер
	# результата немедленно. При конце по таймеру outro уже отработал (идемпотентный
	# begin_music_outro проигнорирует повтор) — остаётся только стингер.
	var audio: Node = game.get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	if audio.has_method("begin_music_outro"):
		audio.begin_music_outro(1.2)
	if audio.has_method("set_sfx_loop"):
		# Бой кончился — low-HP пульс гаснет всегда (страховка к player._exit_tree).
		audio.set_sfx_loop("low_hp_pulse", false)
	if not audio.has_method("play_music_stinger"):
		return
	if victory:
		audio.play_music_stinger("music_sting_victory_epic" if (was_boss_fight or was_elite_fight) else "music_sting_victory")
	else:
		audio.play_music_stinger("music_sting_defeat")
func _random_enemy_scene() -> PackedScene:
	var scenes := [
		game.enemy_scene,
		game.shooter_enemy_scene,
		game.bruiser_enemy_scene,
		game.runner_enemy_scene,
		game.summoner_enemy_scene,
		game.mage_enemy_scene,
		game.spitter_enemy_scene,
		game.shield_enemy_scene,
		game.biter_enemy_scene,
		game.bone_shaman_enemy_scene,
		game.flying_enemy_scene,
	]
	var available_scenes := []
	for scene in scenes:
		if scene != null:
			available_scenes.append(scene)
	if available_scenes.is_empty():
		return null
	var total_weight := 0.0
	for scene in available_scenes:
		total_weight += _spawn_weight_for_scene(scene)
	var roll = game.rng.randf_range(0.0, total_weight)
	var cursor := 0.0
	for scene in available_scenes:
		cursor += _spawn_weight_for_scene(scene)
		if roll <= cursor:
			return scene as PackedScene
	return available_scenes[0] as PackedScene
func _spawn_weight_for_scene(scene: PackedScene) -> float:
	if scene == null:
		return 0.0
	var base_weight = float(game.ENEMY_SPAWN_WEIGHTS.get(scene.resource_path, 1.0))
	var scaling_stage: int = game.route_scaling_stage()
	if scaling_stage <= 0 and _is_shooter_scene(scene):
		base_weight *= 0.35
	elif scaling_stage >= 2 and _is_shooter_scene(scene):
		base_weight *= 1.25
	base_weight *= advanced_spawn_weight_multiplier(_spawn_pressure_kind_for_scene(scene), scaling_stage)
	if game.boss_combat_active and _is_shooter_scene(scene):
		base_weight *= 0.6
	return base_weight
func _spawn_random_enemy(enemy_scene_override: PackedScene = null, spawn_position := Vector2.ZERO,
		use_given_position := false, min_player_distance := -1.0) -> Node2D:
	var enemy_packed_scene := enemy_scene_override if enemy_scene_override != null else _random_enemy_scene()
	if enemy_packed_scene == null:
		return null
	var enemy := SCENE_CONTRACTS.instantiate_node_2d(enemy_packed_scene, "CombatDirector enemy spawn")
	if enemy == null:
		return null
	game.add_child(enemy)
	var safe_distance := min_player_distance
	if safe_distance < 0.0:
		safe_distance = GIVEN_SPAWN_MIN_PLAYER_DISTANCE if use_given_position else game.SPAWN_PLAYER_SAFE_RADIUS
	enemy.global_position = _push_spawn_from_player(_clamp_spawn_position(spawn_position), safe_distance) \
		if use_given_position else _random_spawn_position(safe_distance)
	_scale_enemy_for_current_wave(enemy)
	game.record_codex_enemy_discovery(enemy)
	_connect_enemy_rewards(enemy)
	return enemy
func _maybe_spawn_mini_elite(asc: Dictionary, remaining_slots: int) -> int:
	# Возвращает число занятых слотов (0 если не спавнили).
	var asc_chance := float(asc.get("mini_elite_chance", 0.0))
	var chance := 1.0 if asc_chance >= 1.0 else clampf(asc_chance + _base_mini_elite_pressure_chance(), 0.0, 0.18)
	if chance <= 0.0 or remaining_slots < 2 or game.rng.randf() >= chance:
		return 0
	# Свита L7: вид мини-элитки выбирается случайно из data-driven ростера (6 видов).
	var kinds: Array = game.PROGRESSION_DATA.mini_elite_kinds()
	var kind: Dictionary = kinds[game.rng.randi_range(0, kinds.size() - 1)] if not kinds.is_empty() else {}
	var elite_scene := _elite_scene_by_key(str(kind.get("scene", "")))
	if elite_scene == null:
		elite_scene = _random_elite_scene()
	if elite_scene == null:
		return 0
	var elite := SCENE_CONTRACTS.instantiate_node_2d(elite_scene, "CombatDirector mini-elite spawn")
	if elite == null:
		return 0
	elite.set_meta("epic_scale_profile", "mini_elite")
	elite.set_meta("drop_class", "mini_elite")
	elite.add_to_group("elite_enemies")
	game.add_child(elite)
	elite.global_position = _random_spawn_position()
	# Мини: масштабируется как волновой враг (elite-баланс), затем профиль вида.
	_scale_enemy_for_current_wave(elite)
	if kind.is_empty():
		# Фолбэк (нет ростера): прежнее поведение — урезанная элитка.
		if elite.get("max_health") != null:
			var mini_hp := float(elite.get("max_health")) * 0.55
			elite.set("max_health", mini_hp)
			elite.set("health", mini_hp)
			_refresh_enemy_health_bar(elite)
		elite.set_meta("drop_class", "mini_elite")
		_apply_drop_rewards(elite, "mini_elite")
	else:
		_apply_mini_elite_kind(elite, kind)
	game.record_codex_enemy_discovery(elite)
	_connect_enemy_rewards(elite)
	var used := 1
	# Свита: 1-2 обычных врага рядом.
	var retinue := mini(game.rng.randi_range(1, 2), remaining_slots - 1)
	for retinue_index in range(retinue):
		var minion_scene := _random_enemy_scene()
		if minion_scene == null:
			break
		var offset: Vector2 = Vector2.RIGHT.rotated(game.rng.randf() * TAU) * game.rng.randf_range(48.0, 96.0)
		var minion := _spawn_random_enemy(minion_scene, elite.global_position + offset, true)
		if minion != null:
			used += 1
	return used
func _elite_scene_by_key(key: String) -> PackedScene:
	match key:
		"armored":
			return game.elite_armored_scene
		"stalker":
			return game.elite_stalker_scene
		"poisoned":
			return game.elite_poisoned_scene
		"commander":
			return game.elite_commander_scene
		_:
			return null
func _apply_mini_elite_kind(elite: Node2D, kind: Dictionary) -> void:
	elite.set_meta("mini_elite_kind", str(kind.get("id", "")))
	elite.set_meta("mini_elite_title", str(kind.get("title", "")))
	elite.set_meta("drop_class", "mini_elite")
	if elite.get("max_health") != null:
		var hp := float(elite.get("max_health")) * float(kind.get("hp_mult", 0.55))
		elite.set("max_health", hp)
		elite.set("health", hp)
		_refresh_enemy_health_bar(elite)
	if elite.get("move_speed") != null:
		elite.set("move_speed", float(elite.get("move_speed")) * float(kind.get("speed_mult", 1.0)))
	if elite.get("contact_damage") != null:
		elite.set("contact_damage", float(elite.get("contact_damage")) * float(kind.get("damage_mult", 1.0)))
	if elite.get("projectile_damage") != null:
		elite.set("projectile_damage", float(elite.get("projectile_damage")) * float(kind.get("damage_mult", 1.0)))
	var tint: Array = kind.get("tint", [1.0, 1.0, 1.0])
	var rig := elite.get_node_or_null("RigRoot") as Node2D
	if rig != null and tint.size() >= 3:
		rig.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), 1.0)
	if elite.has_method("refresh_full_frame_visual"):
		elite.call("refresh_full_frame_visual")
	_apply_drop_rewards(elite, "mini_elite")
func spawn_encounter_plan(plan: Dictionary) -> int:
	if plan.is_empty() or plan != _encounters.spawn_plan_projection() or game.boss_combat_active \
			or game.current_combat_type != "battle" or not game.pending_event_combat.is_empty():
		return 0
	var remaining := mini(_active_enemy_cap(), int(plan.get("active_cap", 0))) \
		- ENCOUNTER_CONTEXT.wave_quota_count(game.get_tree().get_nodes_in_group("enemies"))
	if remaining <= 0:
		return 0
	var spawned_count := 0
	for entry in plan.get("entries", []):
		var scene := _encounters.spawn_scene(plan, str(entry.get("scene", "")))
		for _index in range(mini(int(entry.get("count", 0)), remaining)):
			if _spawn_random_enemy(scene, Vector2.ZERO, false, float(plan.get("safe_radius", game.SPAWN_PLAYER_SAFE_RADIUS))) == null:
				return spawned_count
			spawned_count += 1
			remaining -= 1
			if remaining <= 0:
				return spawned_count
	return spawned_count
func _spawn_enemy_wave() -> void:
	var active_cap := _active_enemy_cap()
	var encounter_plan := _encounters.spawn_plan_projection()
	if not encounter_plan.is_empty():
		spawn_encounter_plan(encounter_plan)
		return
	var remaining_slots = active_cap - ENCOUNTER_CONTEXT.wave_quota_count(
		game.get_tree().get_nodes_in_group("enemies"))
	if remaining_slots <= 0:
		return
	var base_count = int(game.WAVE_SETTINGS["base_spawn_count"])
	var scaling_stage: int = game.route_scaling_stage()
	var elapsed_ratio := _combat_elapsed_ratio()
	var elapsed_bonus := int(floor(elapsed_ratio * 3.0))
	var stage_bonus = scaling_stage * int(game.WAVE_SETTINGS["spawn_count_per_stage"])
	var wave_bonus = int(floor(float(game.spawn_wave_index) / float(game.WAVE_SETTINGS["wave_step_size"]))) * int(game.WAVE_SETTINGS["spawn_count_per_wave_step"])
	var spawn_limit = int(game.WAVE_SETTINGS["normal_spawn_limit"])
	if game.boss_combat_active:
		base_count = 1
		stage_bonus = max(scaling_stage - 2, 0)
		spawn_limit = int(game.WAVE_SETTINGS["boss_spawn_limit"])
	elif game.current_combat_type == "elite":
		base_count = 1
		stage_bonus = int(floor(float(scaling_stage) * 0.5))
		spawn_limit = int(game.WAVE_SETTINGS["elite_spawn_limit"])
	var asc_spawn: Dictionary = game.ascension_difficulty()
	# Возвышение 7 «Эхо бездны»: шанс мини-элитки со свитой в обычной волне.
	if not game.boss_combat_active and game.current_combat_type != "elite":
		remaining_slots -= _maybe_spawn_mini_elite(asc_spawn, remaining_slots)
		if remaining_slots <= 0:
			return
	var density := float(asc_spawn["spawn_count_mult"])
	if float(asc_spawn["first_wave_boost"]) > 0.0 and game.spawn_wave_index <= 1 and not game.boss_combat_active:
		density *= 1.5
	if not game.boss_combat_active and game.current_combat_type != "elite":
		density *= normal_spawn_pressure_multiplier(scaling_stage, game.spawn_wave_index, elapsed_ratio)
	var raw_count := int(round(float(base_count + stage_bonus + wave_bonus + elapsed_bonus) * density))
	var spawn_count: int = mini(mini(raw_count, int(round(float(spawn_limit) * density))), remaining_slots)
	for index in range(spawn_count):
		if remaining_slots <= 0:
			return
		var packed_scene := _random_enemy_scene()
		if packed_scene == null:
			return
		var base_position := _random_spawn_position()
		var pack_count := 1
		if not game.boss_combat_active and _is_small_pack_enemy_scene(packed_scene) and game.rng.randf() < game.SMALL_PACK_CHANCE:
			pack_count = mini(game.rng.randi_range(3, 4), remaining_slots)
		for pack_index in range(pack_count):
			if remaining_slots <= 0:
				return
			var offset := Vector2.ZERO
			if pack_count > 1:
				offset = Vector2.RIGHT.rotated(game.rng.randf() * TAU) * game.rng.randf_range(18.0, 54.0)
			var spawned := _spawn_random_enemy(packed_scene, base_position + offset, true)
			if spawned == null:
				return
			remaining_slots -= 1
func _active_enemy_cap() -> int:
	var scaling_stage: int = game.route_scaling_stage()
	var stage_scale: float = game.PROGRESSION_DATA.stage_scale(scaling_stage)
	if game.boss_combat_active:
		return int(round(float(game.WAVE_SETTINGS["boss_active_cap"]) * (0.85 + stage_scale * 0.18)))
	if game.current_combat_type == "elite":
		return mini(int(round(float(game.WAVE_SETTINGS["elite_active_cap"]) * (0.95 + stage_scale * 0.25))), int(game.WAVE_SETTINGS["max_active_cap"]))
	var wave_cap_bonus = int(floor(float(game.spawn_wave_index) / 2.0)) * int(game.WAVE_SETTINGS["active_cap_per_wave_step"])
	var cap = int(round(float(game.WAVE_SETTINGS["base_active_cap"]) * stage_scale)) + scaling_stage * int(game.WAVE_SETTINGS["active_cap_per_stage"]) + wave_cap_bonus
	return mini(cap, int(game.WAVE_SETTINGS["max_active_cap"]))
func _next_spawn_cooldown() -> float:
	var stage_scale: float = game.PROGRESSION_DATA.stage_scale(game.route_scaling_stage())
	var wave_pressure: float = float(game.spawn_wave_index) * 0.045 + (stage_scale - 1.0) * 0.42 + _combat_elapsed_ratio() * SPAWN_COOLDOWN_ELAPSED_PRESSURE
	var cooldown_mult := float(game.ascension_difficulty()["spawn_cooldown_mult"])
	if game.boss_combat_active:
		return max(1.0, (game.rng.randf_range(float(game.WAVE_SETTINGS["boss_spawn_pause_min"]), float(game.WAVE_SETTINGS["boss_spawn_pause_max"])) - wave_pressure * 0.35) * cooldown_mult)
	return max(0.6, (game.rng.randf_range(float(game.WAVE_SETTINGS["spawn_pause_min"]), float(game.WAVE_SETTINGS["spawn_pause_max"])) - wave_pressure) * cooldown_mult)
func _choose_wave_spawn_edges() -> void:
	game.active_spawn_edges.clear()
	# SCRUM-784: ощущение окружения с первой секунды — минимум 2 края всегда.
	var edge_count := 2
	if game.boss_combat_active:
		# Босс: оставляем как было (давление минионов не раздуваем — отдельный контур).
		edge_count = 2
	elif game.current_combat_type == "elite":
		edge_count = 3 if game.spawn_wave_index >= 3 else 2
	else:
		# Обычный бой: до 3 краёв со 2-й стадии / поздних волн, до 4 на высоких стадиях.
		if game.route_scaling_stage() >= 4 or game.spawn_wave_index >= 8:
			edge_count = 4
		elif game.route_scaling_stage() >= 2 or game.spawn_wave_index >= 4:
			edge_count = 3
	edge_count = mini(edge_count, 4)
	var first_edge = game.rng.randi_range(0, 3)
	game.active_spawn_edges.append(first_edge)
	while game.active_spawn_edges.size() < edge_count:
		var candidate = game.rng.randi_range(0, 3)
		if game.active_spawn_edges.has(candidate):
			continue
		if game.route_scaling_stage() <= 1 and game.spawn_wave_index <= 3 and abs(candidate - first_edge) == 2:
			continue
		game.active_spawn_edges.append(candidate)


func _scale_enemy_for_current_wave(enemy: Node) -> void:
	var stage_scale: float = game.PROGRESSION_DATA.stage_scale(game.route_scaling_stage())
	var wave_scale: float = float(game.spawn_wave_index)
	var elapsed_ratio := _combat_elapsed_ratio()
	var balance := _enemy_balance_for_node(enemy)
	var health_multiplier: float = float(balance.get("hp_multiplier", 2.8)) * stage_scale * (1.0 + wave_scale * 0.065 + elapsed_ratio * 0.22)
	var speed_multiplier: float = float(balance.get("speed_multiplier", 0.84)) * (1.0 + (stage_scale - 1.0) * 0.18 + wave_scale * 0.008 + elapsed_ratio * 0.04)
	var damage_multiplier: float = float(balance.get("damage_multiplier", 1.16)) * (1.0 + (stage_scale - 1.0) * 0.46 + wave_scale * 0.024)
	health_multiplier *= enemy_health_pressure_multiplier(game.route_scaling_stage(), game.spawn_wave_index, elapsed_ratio)
	damage_multiplier *= enemy_damage_pressure_multiplier(game.route_scaling_stage(), game.spawn_wave_index, elapsed_ratio)
	if game.boss_combat_active:
		health_multiplier *= 0.72
		speed_multiplier *= 0.82
		damage_multiplier *= 0.86
	elif game.current_combat_type == "elite":
		health_multiplier *= 0.82
		speed_multiplier *= 0.88
		damage_multiplier *= 0.95

	health_multiplier *= _run_enemy_health_multiplier()
	var asc: Dictionary = game.ascension_difficulty()
	health_multiplier *= float(asc["enemy_hp_mult"])
	damage_multiplier *= float(asc["enemy_damage_mult"])

	if enemy.get("max_health") != null:
		var scaled_health: float = float(enemy.get("max_health")) * health_multiplier
		enemy.set("max_health", scaled_health)
		enemy.set("health", scaled_health)
	if enemy.get("move_speed") != null:
		enemy.set("move_speed", float(enemy.get("move_speed")) * speed_multiplier)
	if enemy.get("contact_damage") != null:
		enemy.set("contact_damage", float(enemy.get("contact_damage")) * damage_multiplier)
	if enemy.get("projectile_damage") != null:
		enemy.set("projectile_damage", float(enemy.get("projectile_damage")) * damage_multiplier)
	_apply_drop_rewards(enemy, _drop_class_for_enemy(enemy))
	_refresh_enemy_health_bar(enemy)


func _drop_class_for_enemy(enemy: Node) -> String:
	if enemy == null:
		return "ordinary"
	if enemy.has_meta("drop_class"):
		return str(enemy.get_meta("drop_class"))
	if enemy.is_in_group("bosses"):
		return "boss"
	if enemy.is_in_group("elite_enemies"):
		return "elite"
	var enemy_name := str(enemy.get("enemy_type_name")).to_lower()
	if enemy_name.contains("bruiser") or enemy_name.contains("shield"):
		return "heavy"
	if enemy_name.contains("summoner") or enemy_name.contains("shaman") or enemy_name.contains("shooter") or enemy_name.contains("mage") or enemy_name.contains("spitter"):
		return "complex"
	return "ordinary"


func _apply_drop_rewards(enemy: Node, drop_class: String) -> void:
	if enemy == null:
		return
	var rewards: Dictionary = game.PROGRESSION_DATA.drop_class_rewards(drop_class, game.route_scaling_stage(), game.spawn_wave_index)
	enemy.set_meta("drop_class", drop_class)
	enemy.set_meta("reward_money_chance", float(rewards.get("money_chance", 0.75)))
	if enemy.get("reward_xp") != null:
		enemy.set("reward_xp", int(rewards.get("xp", 1)))
	if enemy.get("reward_money") != null:
		enemy.set("reward_money", int(rewards.get("money", 1)))


func _enemy_balance_for_node(enemy: Node) -> Dictionary:
	if enemy == null:
		return game.ENEMY_BALANCE["default"]
	if enemy.is_in_group("elite_enemies"):
		return game.ENEMY_BALANCE["elite"]
	var enemy_name := str(enemy.get("enemy_type_name")).to_lower()
	if enemy_name.contains("runner"):
		return game.ENEMY_BALANCE["runner"]
	if enemy_name.contains("biter"):
		return game.ENEMY_BALANCE["biter"]
	if enemy_name.contains("bruiser"):
		return game.ENEMY_BALANCE["bruiser"]
	if enemy_name.contains("shield"):
		return game.ENEMY_BALANCE["shield"]
	if enemy_name.contains("summoner") or enemy_name.contains("shaman"):
		return game.ENEMY_BALANCE["summoner"]
	if enemy_name.contains("shooter") or enemy_name.contains("mage") or enemy_name.contains("spitter"):
		return game.ENEMY_BALANCE["shooter"]
	if bool(enemy.get("is_flying")):
		return game.ENEMY_BALANCE["flying"]
	return game.ENEMY_BALANCE["default"]


func _combat_elapsed_ratio() -> float:
	var duration := maxf(_current_round_duration(), 0.001)
	return clampf((duration - float(game.round_time_left)) / duration, 0.0, 1.0)


func _base_mini_elite_pressure_chance() -> float:
	if game.boss_combat_active or game.current_combat_type == "elite":
		return 0.0
	return mini_elite_pressure_chance(game.route_scaling_stage(), game.spawn_wave_index, _combat_elapsed_ratio())


func _spawn_boss() -> void:
	var selected_boss_scene = _boss_scene_for_id(game.current_boss_id)
	if selected_boss_scene == null:
		return

	var boss := SCENE_CONTRACTS.instantiate_node_2d(selected_boss_scene, "CombatDirector boss spawn")
	if boss == null:
		return
	boss.set_meta("epic_scale_profile", "boss")
	game.add_child(boss)
	game.boss_hud_target = boss  # SCRUM-874: цель HUD-боссбара сверху экрана
	boss.global_position = game.ARENA_CENTER + Vector2(0, -230)
	_scale_boss_for_run(boss)
	game.record_codex_enemy_discovery(boss)
	_connect_enemy_rewards(boss)
	# Появление босса: затемнение+тряска (через камеру) и крупный титул-баннер.
	_shake_camera(18.0, 0.5)
	var boss_name := str(boss.get("boss_display_name"))
	if boss_name == "":
		boss_name = str(boss.get("enemy_type_name"))
	# SCRUM-502: запомнить имя текущего босса для причины исхода на экране итогов
	# (на смерти/победе сам узел уже удалён; имя резолвится здесь, пока он жив).
	if not game.run_metrics.is_empty():
		game.run_metrics["last_boss_name"] = boss_name if boss_name != "" else "БОСС"
	# FAN-1080: под титулом Владыки — короткая лор-подводка (кто он и зачем).
	game.ui._show_combat_title_banner(
		boss_name if boss_name != "" else "БОСС",
		Color(1.0, 0.34, 0.3),
		true,
		LORE_DATA.boss_intro_line(game.current_boss_id)
	)


const BONE_ARCHON_BOSS_SCENE := preload("res://scenes/BossBoneArchon.tscn")
const BROOD_MOTHER_BOSS_SCENE := preload("res://scenes/BossBroodMother.tscn")
const ASHEN_COLOSSUS_BOSS_SCENE := preload("res://scenes/BossAshenColossus.tscn")
const SECRET_ASCENSION_BOSS_SCENE := preload("res://scenes/BossSecretAscension.tscn")
# SCRUM-794: новый босс из design-пакета SCRUM-779. Сцена резолвится здесь и готова
# к спавну; в случайный route-пул (route_map_screen._random_boss_route_node) НЕ добавлен —
# ротация подключается отдельной задачей после QA.
const BLOODTHORN_LION_BOSS_SCENE := preload("res://scenes/BossBloodthornLion.tscn")


func _boss_scene_for_id(boss_id: String) -> PackedScene:
	match boss_id:
		"disk_devourer":
			return game.disk_devourer_boss_scene if game.disk_devourer_boss_scene != null else game.boss_scene
		"bone_archon":
			return BONE_ARCHON_BOSS_SCENE
		"brood_mother":
			return BROOD_MOTHER_BOSS_SCENE
		"ashen_colossus":
			return ASHEN_COLOSSUS_BOSS_SCENE
		"secret_ascension_boss":
			return SECRET_ASCENSION_BOSS_SCENE
		"bloodthorn_lion":
			return BLOODTHORN_LION_BOSS_SCENE
		_:
			return game.boss_scene


func _spawn_elite_enemy() -> void:
	var elite_scene := _random_elite_scene()
	var use_fallback_modifier := false
	if elite_scene == null:
		elite_scene = game.bruiser_enemy_scene if game.bruiser_enemy_scene != null else game.enemy_scene
		use_fallback_modifier = true
	if elite_scene == null:
		return
	var elite := SCENE_CONTRACTS.instantiate_node_2d(elite_scene, "CombatDirector elite spawn")
	if elite == null:
		return
	elite.name = "EliteEnemy"
	elite.set_meta("epic_scale_profile", "elite")
	elite.add_to_group("elite_enemies")
	game.add_child(elite)
	game.boss_hud_target = elite  # SCRUM-874: цель HUD-боссбара сверху экрана
	elite.global_position = game.ARENA_CENTER + Vector2(0, -250)
	if use_fallback_modifier:
		_apply_elite_modifier(elite)
	elif not elite.has_meta("elite_modifier"):
		elite.set_meta("elite_modifier", elite_scene.resource_path.get_file().get_basename())
	if not use_fallback_modifier:
		_scale_elite_enemy(elite)
	game.record_codex_enemy_discovery(elite)
	_connect_enemy_rewards(elite)
	# Появление элитки: краткая вспышка имени над ареной.
	# FAN-1080: русский канонический титул из Кодекса вместо англ.
	# enemy_type_name + строка «офицера прибоя» под именем.
	var elite_name := str(elite.get("enemy_type_name"))
	var elite_codex_id := str(game.CODEX_ENEMY_NAME_TO_ID.get(elite_name, ""))
	var elite_title := _codex_monster_title(elite_codex_id)
	if elite_title == "":
		elite_title = elite_name
	game.ui._show_combat_title_banner(
		elite_title if elite_title != "" else "ЭЛИТА",
		Color(1.0, 0.6, 0.32),
		false,
		LORE_DATA.elite_lore(elite_codex_id)
	)


func _random_elite_scene() -> PackedScene:
	# SCRUM-499: детерминированный выбор типа элитки от seed узла — совпадает с превью.
	return game.node_elite_scene(game.current_node_seed)


func _codex_monster_title(codex_id: String) -> String:
	# FAN-1080: канонический русский титул сущности из Кодекса (для баннеров).
	if codex_id == "":
		return ""
	for monster in CODEX_DATA.monsters():
		if str(monster.get("id", "")) == codex_id:
			return str(monster.get("title", ""))
	return ""


func _apply_elite_modifier(enemy: Node2D) -> void:
	enemy.set_meta("elite_modifier", "armored_commander")
	if enemy.get("max_health") != null:
		var elite_health = float(enemy.get("max_health")) * (8.0 + float(game.route_scaling_stage()) * 0.85)
		enemy.set("max_health", elite_health)
		enemy.set("health", elite_health)
	if enemy.get("move_speed") != null:
		enemy.set("move_speed", float(enemy.get("move_speed")) * 0.82)
	if enemy.get("contact_damage") != null:
		enemy.set("contact_damage", float(enemy.get("contact_damage")) * 2.0)
	if enemy.get("projectile_damage") != null:
		enemy.set("projectile_damage", float(enemy.get("projectile_damage")) * 1.9)
	if enemy.get("reward_xp") != null:
		enemy.set("reward_xp", maxi(4, int(enemy.get("reward_xp")) * 4))
	if enemy.get("reward_money") != null:
		enemy.set("reward_money", maxi(4, int(enemy.get("reward_money")) * 5))
	_apply_drop_rewards(enemy, "elite")

	var body := enemy.get_node_or_null("Body") as Sprite2D
	if body == null:
		body = enemy.get_node_or_null("Sprite2D") as Sprite2D
	if body != null:
		body.modulate = Color(1.0, 0.70, 0.22, 1.0)
		body.scale *= 1.22
	_refresh_enemy_health_bar(enemy)


func _scale_elite_enemy(elite: Node2D) -> void:
	var elite_id := str(elite.get("enemy_type_name")).to_lower().replace(" ", "_")
	elite.set_meta("elite_modifier", elite_id)
	elite.set_meta("elite_behavior", elite_id)
	elite.set_meta("elite_phase_threshold", 0.50)
	elite.set_meta("elite_phase_reward", "artifact_choice_1_of_3")
	if elite.get("elite_behavior") != null:
		elite.set("elite_behavior", elite_id)
	var stage_scale: float = game.PROGRESSION_DATA.stage_scale(game.route_scaling_stage())
	var health_multiplier = float(game.ENEMY_BALANCE["elite"]["hp_multiplier"]) * (25.0 + stage_scale * 4.0) * 1.08
	var speed_multiplier = float(game.ENEMY_BALANCE["elite"]["speed_multiplier"])
	var damage_multiplier = float(game.ENEMY_BALANCE["elite"]["damage_multiplier"]) * (1.0 + (stage_scale - 1.0) * 0.78) * 1.06
	if elite_id.contains("armored"):
		health_multiplier *= 1.35
		speed_multiplier *= 0.74
	elif elite_id.contains("stalker"):
		health_multiplier *= 0.92
		speed_multiplier *= 0.86
	elif elite_id.contains("poison"):
		speed_multiplier *= 0.82
	elif elite_id.contains("commander"):
		health_multiplier *= 1.12
		speed_multiplier *= 0.78

	if elite.get("max_health") != null:
		var asc_elite: Dictionary = game.ascension_difficulty()
		var scaled_health = float(elite.get("max_health")) * health_multiplier * float(asc_elite["elite_hp_mult"])
		elite.set("max_health", scaled_health)
		elite.set("health", scaled_health)
		elite.set_meta("ascension_instant_phase", float(asc_elite["elite_instant_phase"]) > 0.0)
	if elite.get("move_speed") != null:
		elite.set("move_speed", float(elite.get("move_speed")) * speed_multiplier)
	if elite.get("contact_damage") != null:
		elite.set("contact_damage", float(elite.get("contact_damage")) * damage_multiplier)
	if elite.get("projectile_damage") != null:
		elite.set("projectile_damage", float(elite.get("projectile_damage")) * damage_multiplier)
	if elite.get("_elite_attack_cooldown") != null:
		elite.set("_elite_attack_cooldown", 1.15)
	_apply_drop_rewards(elite, "elite")
	_refresh_enemy_health_bar(elite)


func _scale_boss_for_run(boss: Node2D) -> void:
	boss.set_meta("boss_id", game.current_boss_id)
	var stage_scale: float = game.PROGRESSION_DATA.stage_scale(game.route_scaling_stage())
	# SCRUM-600: boss-коэффициент HP поднят 4.20+scale*1.20 → 5.40+scale*1.55, чтобы
	# boss оставался апексом (boss TTK ≥1.35× elite). ENEMY_BALANCE['boss']['hp_multiplier']
	# НЕ трогаем — правка только в run-скейле. Зеркало: tools/balance_harness.gd TTK-секция.
	var health_multiplier = float(game.ENEMY_BALANCE["boss"]["hp_multiplier"]) * (5.40 + stage_scale * 1.55)
	var speed_multiplier = float(game.ENEMY_BALANCE["boss"]["speed_multiplier"])
	var damage_multiplier = float(game.ENEMY_BALANCE["boss"]["damage_multiplier"]) * (1.0 + (stage_scale - 1.0) * 0.70)
	if game.current_boss_id == game.META_PROGRESSION.SECRET_BOSS_ID:
		health_multiplier *= 1.18
		speed_multiplier *= 1.08
		damage_multiplier *= 1.18
	if boss.get("max_health") != null:
		var asc_boss: Dictionary = game.ascension_difficulty()
		var scaled_health = float(boss.get("max_health")) * health_multiplier * float(asc_boss["boss_hp_mult"])
		boss.set("max_health", scaled_health)
		boss.set("health", scaled_health)
		boss.set_meta("ascension_extra_phase", float(asc_boss["boss_extra_phase"]) > 0.0)
		boss.set_meta("ascension_telegraph_mult", float(asc_boss["boss_telegraph_mult"]))
	if boss.get("move_speed") != null:
		boss.set("move_speed", float(boss.get("move_speed")) * speed_multiplier)
	if boss.get("contact_damage") != null:
		boss.set("contact_damage", float(boss.get("contact_damage")) * damage_multiplier)
	if boss.get("projectile_damage") != null:
		boss.set("projectile_damage", float(boss.get("projectile_damage")) * damage_multiplier)
	_apply_drop_rewards(boss, "boss")
	_refresh_enemy_health_bar(boss)


func _grant_boss_completion_rewards() -> void:
	if game.current_player == null or not is_instance_valid(game.current_player):
		return
	# SCRUM-873: артефакт больше НЕ выдаётся молча — игрок выбирает 1 из 3
	# суперредких на экране _show_boss_artifact_reward (см. _end_combat).
	# Здесь остаются только XP/деньги за босса.
	var boss_rewards: Dictionary = game.PROGRESSION_DATA.drop_class_rewards("boss", game.route_scaling_stage(), game.spawn_wave_index)
	game.current_player.gain_xp(int(boss_rewards.get("xp", 1)))
	game.current_player.gain_money(int(boss_rewards.get("money", 1)))


func _refresh_enemy_health_bar(enemy: Node) -> void:
	if enemy != null and enemy.has_method("refresh_health_bar"):
		enemy.refresh_health_bar()


func _connect_enemy_rewards(enemy: Node) -> void:
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Node2D) -> void:
	game.record_codex_enemy_discovery(enemy)
	# SCRUM-502: учёт убийств для экрана итогов (до раннего return для боссов ниже).
	game.record_run_kill(enemy.is_in_group("bosses"))
	# Подача триумфа: hit-stop + тряска на смерти элитки/босса (масштаб по рангу).
	if enemy.is_in_group("bosses"):
		_hit_stop(0.42, 0.26)
		_shake_camera(22.0, 0.42)
	elif enemy.is_in_group("elite_enemies"):
		_hit_stop(0.3, 0.34)
		_shake_camera(11.0, 0.26)
		_elite_defeated = true  # SCRUM-528: достоверная точка «элитка убита» (сигнал died)
	# «Сердце Пиявки» (tier 3): убийство лечит процент max HP.
	if game.current_player != null and is_instance_valid(game.current_player):
		var heal_percent := float((game.current_player.get("run_modifiers") as Dictionary).get("kill_heal_percent", 0.0))
		if heal_percent > 0.0 and game.current_player.has_method("heal_percent"):
			game.current_player.heal_percent(heal_percent)
		# SCRUM-500 (on_kill): триггерные артефакты убийства (взрыв / стак-лечение).
		# Логика на игроке — там доступны derived_parameters/VFX/таргет-квери. Босса
		# исключаем из on-kill-взрыва ниже (return), но стак-лечение от него считаем.
		if game.current_player.has_method("on_enemy_killed"):
			game.current_player.on_enemy_killed(enemy)
	if enemy.is_in_group("bosses"):
		return
	_spawn_pickup("xp", int(enemy.get("reward_xp")), enemy.global_position + Vector2(-10.0, 0.0))
	var money_chance := float(enemy.get_meta("reward_money_chance", 1.0 if enemy.is_in_group("elite_enemies") else 0.75))
	if game.rng.randf() < money_chance:
		_spawn_pickup("money", int(enemy.get("reward_money")), enemy.global_position + Vector2(10.0, 0.0))


func _spawn_pickup(pickup_type: String, amount: int, position: Vector2) -> void:
	if game.pickup_scene == null or amount <= 0:
		return
	var pickup := SCENE_CONTRACTS.instantiate_node_2d(game.pickup_scene, "CombatDirector pickup spawn")
	if pickup == null:
		return
	game.add_child(pickup)
	pickup.global_position = position
	if pickup.has_method("setup"):
		pickup.setup(pickup_type, amount)


func _update_pickups(delta: float) -> void:
	if game.current_player == null or not is_instance_valid(game.current_player):
		return

	var raw_pickup_radius = game.current_player.get("pickup_radius")
	var pickup_radius := 0.0
	if typeof(raw_pickup_radius) == TYPE_INT or typeof(raw_pickup_radius) == TYPE_FLOAT:
		pickup_radius = float(raw_pickup_radius)
	for pickup in game.get_tree().get_nodes_in_group("pickups"):
		var pickup_node := pickup as Node2D
		if pickup_node == null or not is_instance_valid(pickup_node):
			continue

		var distance = pickup_node.global_position.distance_to(game.current_player.global_position)
		if distance <= pickup_radius:
			_collect_pickup(pickup_node)
		elif distance <= pickup_radius * 1.75:
			pickup_node.global_position = pickup_node.global_position.lerp(game.current_player.global_position, 8.0 * delta)


func _collect_pickup(pickup: Node) -> void:
	var pickup_type := str(pickup.get("pickup_type"))
	var amount := int(pickup.get("amount"))
	if pickup_type == "money":
		game.current_player.gain_money(amount)
		game._play_sfx("pickup_money")
	else:
		game.current_player.gain_xp(amount)
		game._play_sfx("pickup_xp")
	pickup.queue_free()


func _setup_arena_world(is_boss_fight: bool) -> void:
	# Combat Feel Rework (этап A): Y-сортировка актёров арены. game (корень Main)
	# — плоский родитель игрока/врагов/пикапов: кто ниже по Y (origin = ноги),
	# тот рисуется поверх. Продублировано в рантайме поверх Main.tscn защитно —
	# на случай динамически созданного/подменённого корня. Фон/границы/снаряды
	# не страдают: у них явный z_index. UI живёт в CanvasLayer и не сортируется.
	game.y_sort_enabled = true
	_spawn_arena_background(is_boss_fight)
	_create_arena_boundaries()


func _spawn_arena_background(is_boss_fight: bool) -> void:
	var background_path := _background_path_for_current_node(is_boss_fight)
	var texture = game._cached_texture(background_path)
	if texture == null:
		return

	var background := Sprite2D.new()
	background.name = "ArenaBackground"
	background.add_to_group("arena_backgrounds")
	background.texture = texture
	background.centered = true
	background.position = game.ARENA_SIZE * 0.5
	background.z_index = -100
	var texture_size = texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		background.scale = Vector2(game.ARENA_SIZE.x / texture_size.x, game.ARENA_SIZE.y / texture_size.y)
	game.add_child(background)


func _background_path_for_current_node(is_boss_fight: bool) -> String:
	# SCRUM-499: детерминированный выбор фона от seed узла — совпадает с превью тултипа.
	return game.node_background_path(str(game.current_node_type), is_boss_fight, game.current_node_seed)


func _create_arena_boundaries() -> void:
	var thickness := 52.0
	var boundaries := [
		{"name": "WallTop", "position": Vector2(game.ARENA_SIZE.x * 0.5, -thickness * 0.5), "size": Vector2(game.ARENA_SIZE.x + thickness * 2.0, thickness)},
		{"name": "WallRight", "position": Vector2(game.ARENA_SIZE.x + thickness * 0.5, game.ARENA_SIZE.y * 0.5), "size": Vector2(thickness, game.ARENA_SIZE.y + thickness * 2.0)},
		{"name": "WallBottom", "position": Vector2(game.ARENA_SIZE.x * 0.5, game.ARENA_SIZE.y + thickness * 0.5), "size": Vector2(game.ARENA_SIZE.x + thickness * 2.0, thickness)},
		{"name": "WallLeft", "position": Vector2(-thickness * 0.5, game.ARENA_SIZE.y * 0.5), "size": Vector2(thickness, game.ARENA_SIZE.y + thickness * 2.0)},
	]

	for boundary in boundaries:
		var wall := StaticBody2D.new()
		wall.name = str(boundary["name"])
		wall.add_to_group("arena_boundaries")
		wall.add_to_group("arena_obstacles")
		wall.collision_layer = game.COLLISION_LAYER_SOLID
		wall.collision_mask = 0
		wall.position = boundary["position"]
		var shape := RectangleShape2D.new()
		shape.size = boundary["size"]
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = shape
		wall.add_child(collision)
		game.add_child(wall)

	_create_arena_border_visual()


func _create_arena_border_visual() -> void:
	var border := Line2D.new()
	border.name = "ArenaVisibleBorder"
	border.add_to_group("arena_border_visuals")
	border.add_to_group("arena_backgrounds")
	border.z_index = -20
	border.width = 8.0
	border.default_color = Color(0.95, 0.78, 0.32, 0.88)
	border.closed = true
	border.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(game.ARENA_SIZE.x, 0.0),
		game.ARENA_SIZE,
		Vector2(0.0, game.ARENA_SIZE.y),
	])
	game.add_child(border)


func _random_spawn_position(min_player_distance := -1.0) -> Vector2:
	var safe_distance: float = game.SPAWN_PLAYER_SAFE_RADIUS if min_player_distance < 0.0 else min_player_distance
	for attempt in range(game.OBSTACLE_MAX_ATTEMPTS):
		var position := _random_edge_spawn_position()
		if _is_spawn_position_clear(position, safe_distance):
			return position
	# Этап B: все попытки провалились (игрок стоит у кромки) — фолбэк не голый
	# clamp случайной точки, а точка кромки, МАКСИМАЛЬНО удалённая от игрока.
	var player_position := _live_player_position()
	var best := _clamp_spawn_position(_random_edge_spawn_position())
	var best_distance := best.distance_to(player_position)
	for attempt in range(8):
		var candidate := _clamp_spawn_position(_random_edge_spawn_position())
		var candidate_distance := candidate.distance_to(player_position)
		if candidate_distance > best_distance:
			best = candidate
			best_distance = candidate_distance
	return best


func _random_edge_spawn_position() -> Vector2:
	var edge := _random_active_spawn_edge()

	match edge:
		0:
			return Vector2(game.rng.randf_range(game.SPAWN_EDGE_PADDING, game.ARENA_SIZE.x - game.SPAWN_EDGE_PADDING), game.SPAWN_EDGE_PADDING)
		1:
			return Vector2(game.ARENA_SIZE.x - game.SPAWN_EDGE_PADDING, game.rng.randf_range(game.SPAWN_EDGE_PADDING, game.ARENA_SIZE.y - game.SPAWN_EDGE_PADDING))
		2:
			return Vector2(game.rng.randf_range(game.SPAWN_EDGE_PADDING, game.ARENA_SIZE.x - game.SPAWN_EDGE_PADDING), game.ARENA_SIZE.y - game.SPAWN_EDGE_PADDING)
		_:
			return Vector2(game.SPAWN_EDGE_PADDING, game.rng.randf_range(game.SPAWN_EDGE_PADDING, game.ARENA_SIZE.y - game.SPAWN_EDGE_PADDING))


func _random_active_spawn_edge() -> int:
	if game.active_spawn_edges.is_empty():
		return game.rng.randi_range(0, 3)
	return int(game.active_spawn_edges[game.rng.randi_range(0, game.active_spawn_edges.size() - 1)])


# Этап B: живая позиция игрока для спавн-защиты. Раньше фильтр мерил дистанцию
# до ФИКСИРОВАННОГО ARENA_CENTER — у краёв арены мобы спавнились вплотную к
# игроку. Фолбэк на центр остаётся только когда игрока нет (меж-боевые экраны).
func _live_player_position() -> Vector2:
	if game.current_player != null and is_instance_valid(game.current_player):
		return game.current_player.global_position
	var player := game.get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		return player.global_position
	return game.ARENA_CENTER


# Этап B: pack/retinue/given-position спавны не садятся на голову игроку —
# точка ближе min_distance выталкивается вдоль направления игрок→точка
# (затем клампится в арену; у самой кромки допускаем частичный возврат).
func _push_spawn_from_player(position: Vector2, min_distance: float) -> Vector2:
	var player_position := _live_player_position()
	var offset := position - player_position
	var distance := offset.length()
	if distance >= min_distance:
		return position
	var away := offset / distance if distance > 0.001 else Vector2.RIGHT.rotated(game.rng.randf() * TAU)
	return _clamp_spawn_position(player_position + away * min_distance)


func _is_spawn_position_clear(position: Vector2, min_player_distance := -1.0) -> bool:
	var safe_distance: float = game.SPAWN_PLAYER_SAFE_RADIUS if min_player_distance < 0.0 else min_player_distance
	if position.distance_to(_live_player_position()) < safe_distance:
		return false
	for obstacle in game.get_tree().get_nodes_in_group("arena_obstacles"):
		var obstacle_node := obstacle as Node2D
		if obstacle_node != null and obstacle_node.is_in_group("arena_boundaries"):
			continue
		if obstacle_node != null and obstacle_node.global_position.distance_to(position) < 86.0:
			return false
	return true


func _clamp_spawn_position(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, game.SPAWN_EDGE_PADDING, game.ARENA_SIZE.x - game.SPAWN_EDGE_PADDING),
		clampf(position.y, game.SPAWN_EDGE_PADDING, game.ARENA_SIZE.y - game.SPAWN_EDGE_PADDING)
	)


func _is_small_pack_enemy_scene(packed_scene: PackedScene) -> bool:
	if packed_scene == null:
		return false
	var path := packed_scene.resource_path
	return path.ends_with("EnemyRunner.tscn") or path.ends_with("EnemyBiter.tscn") or path.ends_with("EnemyFlyingRunner.tscn")


func _is_shooter_scene(packed_scene: PackedScene) -> bool:
	if packed_scene == null:
		return false
	var path := packed_scene.resource_path
	return path.ends_with("EnemyShooter.tscn") or path.ends_with("EnemyMage.tscn") or path.ends_with("EnemySpitter.tscn") or path.ends_with("EnemyBoneShaman.tscn")


func _spawn_pressure_kind_for_scene(packed_scene: PackedScene) -> String:
	if packed_scene == null:
		return "ordinary"
	var path := packed_scene.resource_path
	if _is_shooter_scene(packed_scene):
		return "shooter"
	if path.ends_with("EnemySummoner.tscn"):
		return "summoner"
	if path.ends_with("EnemyBruiser.tscn") or path.ends_with("EnemyShield.tscn"):
		return "heavy"
	return "ordinary"


func _grant_combat_completion_rewards(event_combat := {}) -> void:
	if game.current_player == null or not is_instance_valid(game.current_player):
		return
	var xp_reward: int
	var money_reward: int
	var scaling_stage: int = game.route_scaling_stage()
	if game.current_combat_type == "elite":
		xp_reward = 7 + scaling_stage * 2
		money_reward = 10 + scaling_stage * 4
	else:
		xp_reward = 3 + scaling_stage
		money_reward = 4 + scaling_stage * 2
	# Event-бои (и обычные, и элитные) могут нести множители из event_data —
	# раньше элитная ветка их молча игнорировала, и +50% золота/+25% опыта в
	# тултипе defile/duel были неправдой. Множители честно применяем к обеим веткам.
	if not event_combat.is_empty():
		xp_reward = int(round(float(xp_reward) * float(event_combat.get("xp_multiplier", 1.0))))
		money_reward = int(round(float(money_reward) * float(event_combat.get("money_multiplier", 1.0))))
	game.current_player.gain_xp(xp_reward)
	game.current_player.gain_money(money_reward)
	if not event_combat.is_empty() and event_combat.has("post_combat"):
		game.current_player.apply_reward(event_combat["post_combat"])
		game.record_codex_artifact_discovery(event_combat["post_combat"])


# SCRUM-996: продолжение победного флоу обычного/элитного боя после докачки
# атрибутов. Штатно — автосейв + карта. Если событийный бой нёс
# post_combat.shop_after — сначала событийный магазин (опц. shop_discount),
# выход из которого ведёт к тому же штатному возврату. route_stage уже сдвинут
# в _end_combat, поэтому advance здесь НЕ повторяется.
func _combat_victory_map_continuation(event_combat: Dictionary) -> Callable:
	var return_to_route_map := func() -> void:
		game.save_run_autosave("combat_node")
		game.route._show_battle_map()
	if event_combat.is_empty():
		return return_to_route_map
	var post_combat_raw = event_combat.get("post_combat", {})
	if not (post_combat_raw is Dictionary):
		return return_to_route_map
	var post_combat := post_combat_raw as Dictionary
	if not bool(post_combat.get("shop_after", false)):
		return return_to_route_map
	return func() -> void:
		game.ui._open_event_shop(return_to_route_map, float(post_combat.get("shop_discount", 0.0)))


func _snapshot_player_for_menu() -> Node:
	var temp_player = game.player_scene.instantiate()
	if temp_player == null:
		return null
	game.add_child(temp_player)
	# Full Player is reused only as an in-memory stat model. It must not compete
	# with combat targeting, input, physics or Camera2D while a menu owns it.
	game._register_player_lifecycle_node(temp_player, game.PLAYER_LIFECYCLE_MENU_SNAPSHOT)
	if game.run_player_snapshot.is_empty():
		temp_player.configure_character(game.selected_character_id, game.selected_weapon_id)
	else:
		_restore_player_snapshot(temp_player)
	return temp_player


func _store_player_snapshot(player: Node) -> void:
	# SCRUM-500/SCRUM-844: снапшот тащит run_modifiers целиком между узлами.
	# Runtime-only active/fraction гейты и timed ultimate overlays не должны
	# «застывать» как постоянный бонус после замены player node между боями.
	var run_modifiers_snapshot := (player.get("run_modifiers") as Dictionary).duplicate(true)
	var berserk_ultimate_active := float(run_modifiers_snapshot.get("ultimate_berserk_active", 0.0)) > 0.0
	for transient_flag in TRANSIENT_RUN_MODIFIER_KEYS:
		if run_modifiers_snapshot.has(transient_flag):
			run_modifiers_snapshot[transient_flag] = 0.0
	if berserk_ultimate_active:
		for multiplier_key in TRANSIENT_BERSERK_ULTIMATE_MULTIPLIERS.keys():
			run_modifiers_snapshot[multiplier_key] = float(run_modifiers_snapshot.get(multiplier_key, 1.0)) / float(TRANSIENT_BERSERK_ULTIMATE_MULTIPLIERS[multiplier_key])
	var artifacts_raw = player.get("artifacts")
	var artifacts_snapshot: Array = []
	if artifacts_raw is Array:
		artifacts_snapshot = artifacts_raw as Array
	game.run_player_snapshot = {
		"character_id": player.get("character_id"),
		"weapon_id": player.get("weapon_id"),
		"health": player.get("health"),
		"max_health": player.get("max_health"),
		"stats": (player.get("stats") as Dictionary).duplicate(true),
		"run_modifiers": run_modifiers_snapshot,
		"artifacts": artifacts_snapshot.duplicate(true),
		"xp": player.get("xp"),
		"xp_to_next": player.get("xp_to_next"),
		"level": player.get("level"),
		"money": player.get("money"),
		# SCRUM-872: накопленная шкала ульты переносится между узлами/раундами.
		# Активная ульта (_ultimate_active/timed-overlay) — runtime-only, НЕ переносится.
		"ultimate_charge": player.get("ultimate_charge"),
	}


func _restore_player_snapshot(player: Node) -> void:
	game.selected_character_id = str(game.run_player_snapshot.get("character_id", game.selected_character_id))
	game.selected_weapon_id = str(game.run_player_snapshot.get("weapon_id", game.selected_weapon_id))
	player.configure_character(game.selected_character_id)
	player.set("stats", (game.run_player_snapshot.get("stats", {}) as Dictionary).duplicate(true))
	player.set("run_modifiers", ProgressionData.sanitize_run_modifiers((game.run_player_snapshot.get("run_modifiers", {}) as Dictionary)))
	player.set("artifacts", (game.run_player_snapshot.get("artifacts", []) as Array).duplicate(true))
	player.set("xp", int(game.run_player_snapshot.get("xp", 0)))
	player.set("xp_to_next", int(game.run_player_snapshot.get("xp_to_next", 5)))
	player.set("level", int(game.run_player_snapshot.get("level", 1)))
	player.set("money", int(game.run_player_snapshot.get("money", 0)))
	if game.selected_weapon_id != "" and player.has_method("equip_weapon"):
		player.equip_weapon(game.selected_weapon_id)
	elif player.has_method("_apply_stat_scaling"):
		player.call("_apply_stat_scaling", true)
	player.set("health", min(float(game.run_player_snapshot.get("health", player.get("max_health"))), float(player.get("max_health"))))
	# SCRUM-872: восстановить накопленную ульту ПОСЛЕ configure/equip (перерасчёт
	# деривативов) с clamp по максимуму — заряд не должен превышать шкалу.
	var ultimate_max := maxf(float(player.get("ultimate_max_charge")), 0.0)
	player.set("ultimate_charge", clampf(float(game.run_player_snapshot.get("ultimate_charge", 0.0)), 0.0, ultimate_max))


func _current_round_duration() -> float:
	# SCRUM-785: элитка/босс — фиксированный 5-минутный «убей или проиграл» таймер.
	# round_duration_mult (Возвышение) к нему НЕ применяем: окно убийства должно быть
	# стабильным и предсказуемым (300с), а не сжиматься на высоких Возвышениях.
	if game.boss_combat_active or game.current_combat_type == "elite":
		return game.ELITE_BOSS_ROUND_DURATION
	# Обычный бой: первый = 60с, далее +3/стадию до ROUND_DURATION_MAX, с учётом Возвышения.
	var base: float = minf(game.BASE_ROUND_DURATION + game.route_scaling_stage() * game.ROUND_DURATION_STEP, game.ROUND_DURATION_MAX)
	return base * float(game.ascension_difficulty()["round_duration_mult"])


func _run_enemy_health_multiplier() -> float:
	var event_multiplier := float(game.pending_event_combat.get("enemy_health_multiplier", 1.0))
	if game.current_player != null and is_instance_valid(game.current_player):
		var modifiers: Dictionary = game.current_player.get("run_modifiers")
		return event_multiplier * float(modifiers.get("enemy_health_multiplier", 1.0))
	if not game.run_player_snapshot.is_empty():
		var snapshot_modifiers: Dictionary = game.run_player_snapshot.get("run_modifiers", {})
		return event_multiplier * float(snapshot_modifiers.get("enemy_health_multiplier", 1.0))
	return event_multiplier
