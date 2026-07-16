extends SceneTree

# SCRUM-503: регресс-гейт на ЖИВОЙ runaway Берсерка (молот), который формульный
# гейт НЕ ловит. Формульная оценка (tools/class_damage_table_3variants.gd,
# tests/global_damage_balance_smoke_test.gd) гоняет estimate_weapon_budget с
# ПУСТЫМИ run_modifiers → забеговый множитель = 1.0, поэтому мультипликативный
# стак «идеального» билда (damage_multiplier × attack_speed × melee-sweep по 20
# целям) там невидим. Этот гейт инстанцирует РЕАЛЬНОГО Player + молот, прокачивает
# «идеальным» билдом до lvl20 (как tools/character_balance_csv.gd: лучшая по DPS
# карта из 3 предложенных × 19 уровней + топ-артефакты) и меряет фактический DPS
# по 20 и 1 цели. Падаем, если пик вышел из коридора лидеров — ловит откат
# soft-cap'а забеговых множителей (progression_data._soft_capped_run_multiplier) или
# повторное раздувание upgrade_*_exponent молота.
#
# Запуск: Godot --headless --path . --script res://tests/berserk_dps_runaway_gate.gd
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 8.0
# The live gate measures a time window, not a nominal frame count: a fixed 480
# process frames can represent very different simulation durations under load.
const MAX_MEASUREMENT_FRAMES := 2400
const DUMMY_HP := 1.0e9             # болванки не умирают — чистый DPS
const TARGET_LEVEL := 20
const LEVELUPS := 19                # уровни 2..20
const ARTIFACT_COUNT := 6
const RARE_SLOT_CHANCE := 0.05
const OFFER_SIZE := 3
const BASE_SEED := 20260620         # тот же сид, что в генераторе матрицы

const CHARACTER_ID := "berserk"
const WEAPON_ID := "hammer"

# Потолки коридора лидеров (после SCRUM-503 soft-cap, SCRUM-545 + SCRUM-602).
# Новый профиль молота стартует с кругом 150px и без fixed radius cap, но Radius
# scaling и upgrade-экспоненты всё ещё должны оставлять идеальный lvl20 билд в
# живом коридоре лидеров, без возврата мультипликативного runaway.
# FAN-1034: ревизия атрибутов убрала из level-up пула мёртвые карты (снаряды/
# отталкивание/сектор) — «идеальные» офферы стали плотнее по урону, живой замер
# ideal-билда поднялся 3600 → ~3950 без каких-либо правок множителей молота.
# Потолок рекалиброван с прежним запасом: откат радиуса/экспонент (+~30% к базе,
# т.е. ≥5100 от новой базы) по-прежнему ловится.
# FAN-1039: потолки перекалиброваны под честную времябазу (см. _measure_dps).
# Старые 4400/650 калибровались на сломанном фикс-окне (шум 2×: 3422..7049 на
# одном коде → ложные красные ~40% прогонов). Честный замер: 20t 7299..8505
# (±8%, N=3), 1t 943..1042. Потолок = среднее ×~1.3 (запас на шум + малый рост);
# runaway-регрессии исторического масштаба (×2+, 13792/16k) ловятся с запасом.
const MAX_IDEAL_20T := 10000.0
const MAX_IDEAL_1T := 1300.0
const ZERO_EPS := 0.01

var _holder: Node2D


func _initialize() -> void:
	await process_frame
	_holder = Node2D.new()
	_holder.name = "BerserkRunawayGateHolder"
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	var config: Dictionary = ProgressionData.weapon(CHARACTER_ID, WEAPON_ID)
	if config.is_empty():
		push_error("Berserk runaway gate: оружие %s/%s не найдено в реестре." % [CHARACTER_ID, WEAPON_ID])
		quit(1)
		return
	var archetype: String = ProgressionData.weapon_archetype(config)

	# Тот же сид, что у tools/character_balance_csv.gd для пары berserk/hammer:
	# генератор раздаёт seed_counter инкрементом (+2 на пару: ideal+random) в порядке
	# обхода реестра. Совпадение сидов → число гейта тождественно строке CSV (QA
	# может кросс-сверить lvl20_ideal_20t/1t берсерка с этим гейтом).
	var rng := RandomNumberGenerator.new()
	rng.seed = _ideal_seed_for_pair(CHARACTER_ID, WEAPON_ID)
	var ideal_build: Array = _build_levelups(CHARACTER_ID, archetype, rng) + _build_artifacts(CHARACTER_ID, archetype, rng)

	var dps_20t: float = await _measure_dps(CHARACTER_ID, WEAPON_ID, 20, ideal_build)
	var dps_1t: float = await _measure_dps(CHARACTER_ID, WEAPON_ID, 1, ideal_build)

	_holder.queue_free()
	await process_frame

	var failures: Array = []
	if not (is_finite(dps_20t) and is_finite(dps_1t)):
		failures.append("нечисловой живой DPS (20t=%s 1t=%s)" % [dps_20t, dps_1t])
	if maxf(dps_20t, dps_1t) <= ZERO_EPS:
		failures.append("0 живого урона за %.0fс (20t=%.3f 1t=%.3f) — режим оружия сломан" % [WINDOW_SECONDS, dps_20t, dps_1t])
	if dps_20t > MAX_IDEAL_20T:
		failures.append("berserk/hammer lvl20_ideal 20t = %.0f > потолка %.0f — runaway множителей вернулся (проверь soft-cap забеговых множителей и upgrade_*_exponent молота)" % [dps_20t, MAX_IDEAL_20T])
	if dps_1t > MAX_IDEAL_1T:
		failures.append("berserk/hammer lvl20_ideal 1t = %.0f > потолка %.0f — solo-пик вне коридора" % [dps_1t, MAX_IDEAL_1T])

	print("[runaway-gate] berserk/hammer lvl20_ideal: 20t=%.0f (≤%.0f) 1t=%.0f (≤%.0f)" % [dps_20t, MAX_IDEAL_20T, dps_1t, MAX_IDEAL_1T])

	if not failures.is_empty():
		for f in failures:
			push_error("Berserk runaway gate FAIL: %s" % f)
		quit(1)
		return
	print("Berserk DPS runaway gate passed.")
	quit(0)


# --- Прогрессия: «идеальный» билд (зеркало tools/character_balance_csv.gd) -------

# Воспроизводит раздачу сидов генератором матрицы: seed_counter стартует с
# BASE_SEED и растёт на 2 за пару (ideal + random) в порядке обхода реестра.
# Возвращает сид «ideal»-прогона для нужной пары.
func _ideal_seed_for_pair(character_id: String, weapon_id: String) -> int:
	var seed_counter := BASE_SEED
	for cid_any in ProgressionData.character_ids():
		var cid := str(cid_any)
		for wid_any in ProgressionData.weapon_ids(cid):
			var wid := str(wid_any)
			if cid == character_id and wid == weapon_id:
				return seed_counter
			seed_counter += 2
	return BASE_SEED


func _build_levelups(character_id: String, archetype: String, rng: RandomNumberGenerator) -> Array:
	var chosen: Array = []
	for _level in range(LEVELUPS):
		var offer := _roll_offer(character_id, rng)
		if offer.is_empty():
			continue
		var best_index := 0
		var best_score := -1.0e9
		for index in range(offer.size()):
			var score := _dps_score(offer[index], archetype)
			if score > best_score:
				best_score = score
				best_index = index
		chosen.append(offer[best_index])
	return chosen


func _build_artifacts(character_id: String, archetype: String, rng: RandomNumberGenerator) -> Array:
	var pool: Array = ProgressionData.reward_pool(character_id).filter(func(reward: Dictionary) -> bool:
		return str(reward.get("kind", "")) == "artifact"
	)
	if pool.is_empty():
		return []
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _dps_score(a, archetype) > _dps_score(b, archetype)
	)
	var chosen: Array = []
	for index in range(mini(ARTIFACT_COUNT, pool.size())):
		chosen.append(pool[index])
	return chosen


func _dps_score(reward: Dictionary, archetype: String) -> float:
	var multi := ["aoe", "aura", "summon"].has(archetype)
	var melee := archetype == "melee"
	var score := 0.0
	var stats: Dictionary = reward.get("stats", {})
	for stat_id in stats.keys():
		score += _stat_dps_value(str(stat_id), archetype) * float(stats[stat_id])
	for source_key in ["mods", "affinity_mods"]:
		var mods: Dictionary = reward.get(source_key, {})
		for key in mods.keys():
			var value := float(mods[key])
			match str(key):
				"damage_multiplier":
					score += 100.0 * (value - 1.0)
				"attack_speed_multiplier":
					score += 95.0 * (value - 1.0)
				"crit_chance_flat":
					score += 60.0 * value
				"crit_damage_flat":
					score += 18.0 * value
				"aoe_radius_multiplier":
					score += (42.0 if multi else 10.0) * (value - 1.0)
				"sector_multiplier":
					score += (36.0 if multi else (22.0 if melee else 8.0)) * (value - 1.0)
				"range_multiplier":
					score += (26.0 if multi else 8.0) * (value - 1.0)
				"dot_speed_flat":
					score += 12.0 * value
				"dot_damage_flat":
					score += 6.0 * value
				"summon_bonus":
					score += (30.0 if archetype == "summon" else 3.0) * value
				"vampiric_chance_flat", "vampiric_amount_flat":
					score += 0.5 * value
				"projectile_speed_flat":
					score += 0.02 * value
				_:
					pass
	return score


func _stat_dps_value(stat_id: String, archetype: String) -> float:
	match stat_id:
		"agility":
			return 8.0
		"strength":
			return 8.0 if ["melee", "projectile"].has(archetype) else 5.0
		"perception":
			return 8.0 if ["projectile", "aoe"].has(archetype) else 5.0
		"intelligence":
			return 8.0 if ["beam", "aoe"].has(archetype) else 5.0
		"knowledge":
			return 5.0
		"leadership":
			return 9.0 if archetype == "summon" else 3.0
		"energy":
			return 4.0
		"endurance":
			return 1.0
	return 3.0


func _roll_offer(character_id: String, rng: RandomNumberGenerator) -> Array:
	var regular_pool: Array = ProgressionData.level_up_rewards(character_id)
	var stat_pool: Array = ProgressionData.main_stat_level_up_rewards(character_id)
	var offer: Array = []
	while offer.size() < OFFER_SIZE and (not regular_pool.is_empty() or not stat_pool.is_empty()):
		var want_rare: bool = not stat_pool.is_empty() and rng.randf() < RARE_SLOT_CHANCE
		var source: Array = stat_pool if (want_rare or regular_pool.is_empty()) else regular_pool
		var index := _weighted_index(source, character_id, rng)
		offer.append(source[index])
		source.remove_at(index)
	return offer


func _weighted_index(source: Array, character_id: String, rng: RandomNumberGenerator) -> int:
	if source.size() <= 1:
		return 0
	var total := 0.0
	var weights: Array = []
	for reward in source:
		var weight: float = ProgressionData.level_up_reward_weight(reward, character_id)
		weights.append(weight)
		total += weight
	var roll := rng.randf() * maxf(total, 0.001)
	var cursor := 0.0
	for index in range(weights.size()):
		cursor += float(weights[index])
		if roll <= cursor:
			return index
	return weights.size() - 1


# --- Замер фактического DPS (зеркало tools/character_balance_csv.gd) -------------

func _measure_dps(character_id: String, weapon_id: String, target_count: int, rewards: Array) -> float:
	for child in _holder.get_children():
		child.queue_free()
	await process_frame

	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(1280, 720)
	if player.has_method("configure_character"):
		player.configure_character(character_id, weapon_id)
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	for reward in rewards:
		if player.has_method("apply_reward"):
			player.apply_reward(reward)
	if not rewards.is_empty():
		player.set("level", TARGET_LEVEL)
	await process_frame

	var dummies := _spawn_dummies(player.global_position, target_count)
	var anchor_positions: Array = []
	for enemy in dummies:
		anchor_positions.append((enemy as Node2D).global_position)
	await process_frame

	var hp_before := 0.0
	for enemy in dummies:
		hp_before += float(enemy.get("health"))

	# FAN-1210: sample exactly WINDOW_SECONDS of simulation. Counting a fixed
	# 480 frames while attacks use _process(delta) changed the number of casts
	# under load, even though the denominator used real delta time. The hard
	# frame limit is only a hang guard; it never changes the target window.
	var elapsed_game_time := 0.0
	var sampled_frames := 0
	while elapsed_game_time < WINDOW_SECONDS and sampled_frames < MAX_MEASUREMENT_FRAMES:
		await process_frame
		sampled_frames += 1
		elapsed_game_time += maxf(_holder.get_process_delta_time(), 0.0)
		for i in range(dummies.size()):
			var enemy := dummies[i] as Node2D
			if is_instance_valid(enemy):
				enemy.global_position = anchor_positions[i]
	if elapsed_game_time < WINDOW_SECONDS:
		push_error("Berserk runaway gate did not advance %.1fs of simulation within %d frames." % [WINDOW_SECONDS, MAX_MEASUREMENT_FRAMES])
		return -1.0

	var hp_after := 0.0
	for enemy in dummies:
		if is_instance_valid(enemy):
			hp_after += float(enemy.get("health"))
	return maxf(hp_before - hp_after, 0.0) / maxf(elapsed_game_time, 0.001)


func _spawn_dummies(player_pos: Vector2, target_count: int) -> Array:
	var dummies: Array = []
	for i in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		_holder.add_child(enemy)
		var pos: Vector2
		if target_count == 1:
			pos = player_pos + Vector2(80, 0)
		else:
			var radius := 58.0 + 26.0 * sqrt(float(i))
			var angle := float(i) * 2.3999632             # золотой угол
			pos = player_pos + Vector2.RIGHT.rotated(angle) * radius
		enemy.global_position = pos
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		dummies.append(enemy)
	return dummies
