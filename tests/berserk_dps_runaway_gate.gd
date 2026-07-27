extends SceneTree

# SCRUM-503: регресс-гейт на ЖИВОЙ runaway Берсерка (молот), который формульный
# гейт НЕ ловит. Формульная оценка (tools/class_damage_table_3variants.gd,
# tests/global_damage_balance_smoke_test.gd) гоняет estimate_weapon_budget с
# ПУСТЫМИ run_modifiers → забеговый множитель = 1.0, поэтому мультипликативный
# стак «идеального» билда (damage_multiplier × attack_speed × melee-sweep по 20
# целям) там невидим. Этот гейт инстанцирует РЕАЛЬНОГО Player + молот, прокачивает
# «идеальным» билдом до lvl20 (как tools/character_balance_csv.gd: лучшая по DPS
# карта из 3 предложенных × 19 уровней + топ-артефакты) и меряет фактический DPS
# по 20 и 1 цели.
#
# FAN-1729: в гейте ДВЕ независимые проверки, вердикты у них раздельные и в
# выводе помечены своим тегом.
#
# [ceiling] — живой DPS lvl20-билда против MAX_IDEAL_20T / MAX_IDEAL_1T. Покрывает
#   геометрический и экспоненциальный runaway молота (radius scaling,
#   upgrade_*_exponent, circle_full_targets / circle_target_diminish): такие
#   регрессии дают ×2+ и пробивают потолок с запасом.
#   НЕ покрывает откат soft-cap'а: полное отключение soft-cap'а даёт лишь +14% к
#   20t, а запас потолка над эталоном больше (p50 8267 → 10000, +21%; max 8596 →
#   10000, +16%), поэтому все прогоны с отключённым soft-cap'ом были зелёными
#   (FAN-1713, воспроизведено FAN-1729: 20t 9822/9449/9833 ≤ 10000). Опускать
#   потолок под этот эффект нельзя: он съел бы тот запас на шум, который FAN-1712
#   только что отвоевал у ложных красных.
#
# [soft-cap] — прямая проверка diminishing returns забеговых множителей
#   (progression_data._soft_capped_run_multiplier) через публичную точку
#   агрегации ProgressionData.derived_parameters. Красная и когда сам soft-cap
#   стал тождественным, и когда его перестали вызывать. Не зависит ни от уровня
#   DPS, ни от дрейфа контента: пробы фиксированные, функция чистая, шума нет.
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

# FAN-1729: пробы проверки [soft-cap]. Эффективный забеговый множитель снимается
# как отношение выхода ProgressionData.derived_parameters с множителем к выходу
# без него: при ПУСТОМ weapon_config в отношение не входят ни upgrade_*_exponent,
# ни passive_mods, поэтому оно равно ровно тому, что вернул soft-cap. Атрибуты
# пробы нужны лишь чтобы знаменатель был ненулевым (damage=30.0, attack_speed=5.4).
const SOFTCAP_PROBE_STATS := {"strength": 20.0, "agility": 20.0}
# Масштаб забеговых множителей «идеального» lvl20 билда (замер FAN-1729 на dev
# 82343091: damage_multiplier=6.4766, attack_speed_multiplier=2.0321).
const SOFTCAP_RUNAWAY_DAMAGE_MULT := 6.5
const SOFTCAP_RUNAWAY_ATTACK_SPEED_MULT := 2.0
# На этих точках soft-cap обязан срезать минимум 5% множителя. Действующая кривая
# срезает 12.0% (6.500→5.721) и 16.7% (2.000→1.667) — запас больше двукратного,
# а откат soft-cap'а в no-op срезает ровно 0% и краснеет.
const SOFTCAP_MIN_COMPRESSION := 0.05
# Заведомо runaway-множитель: обязан прийти к объявленному жёсткому потолку
# (BalanceData.RUN_*_SOFTCAP), а не пройти насквозь.
const SOFTCAP_EXTREME_MULT := 100.0
# Множитель <= 1.0 (база забега и штрафы вроде медленного оружия) обязан проходить
# soft-cap тождественно — инвариант из шапки _soft_capped_run_multiplier. Держит
# проверку честной: «починить» сжатие тотальным клампом всего подряд нельзя.
const SOFTCAP_IDENTITY_MULTS := [1.0, 0.8]
const SOFTCAP_EPS := 1.0e-4

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

	# FAN-1712: «идеальный» билд обязан быть ВОСПРОИЗВОДИМЫМ — иначе один и тот же
	# SHA судится по разным билдам. Свой RandomNumberGenerator ниже покрывает только
	# level-up офферы; артефакты приходят из ProgressionData.reward_pool(), а он
	# материализует rarity-семьи через roll_artifact_family_tier() → ГЛОБАЛЬНЫЙ
	# randf() (scripts/progression_data.gd:143). Тиры (веса ≈0.64/0.29/0.08)
	# раскатывались заново в каждом процессе: замеры на 071338e9 дали в одном
	# процессе fox_boots + damage=194.86, в другом captains_coin + damage=239.52,
	# а удачный ролл тиров поднимал 20t до ~14.8k при нормальном 1t (ложный красный
	# FAN-1700). Фиксируем глобальный поток тем же BASE_SEED: набор артефактов и их
	# тиры становятся частью эталона, потолки и чувствительность не меняются.
	seed(BASE_SEED)

	# CSV теперь выводит свои seeds из строковой идентичности пары, чтобы --pair
	# не зависел от порядка обхода реестра. Этот gate сохраняет исторический
	# positional seed для своей калиброванной границы: он больше не является
	# row-for-row seed cross-check для CSV.
	var rng := RandomNumberGenerator.new()
	rng.seed = _ideal_seed_for_pair(CHARACTER_ID, WEAPON_ID)
	var ideal_build: Array = _build_levelups(CHARACTER_ID, archetype, rng) + _build_artifacts(CHARACTER_ID, archetype, rng)

	# FAN-1729: [soft-cap] чистый и от живого замера не зависит — считаем его до
	# окна DPS, чтобы вердикт попал в вывод даже если симуляция упрётся в hang-guard.
	var failures: Array = _check_run_multiplier_softcap()

	var dps_20t: float = await _measure_dps(CHARACTER_ID, WEAPON_ID, 20, ideal_build)
	var dps_1t: float = await _measure_dps(CHARACTER_ID, WEAPON_ID, 1, ideal_build)

	_holder.queue_free()
	await process_frame

	if not (is_finite(dps_20t) and is_finite(dps_1t)):
		failures.append("[ceiling] нечисловой живой DPS (20t=%s 1t=%s)" % [dps_20t, dps_1t])
	if maxf(dps_20t, dps_1t) <= ZERO_EPS:
		failures.append("[ceiling] 0 живого урона за %.0fс (20t=%.3f 1t=%.3f) — режим оружия сломан" % [WINDOW_SECONDS, dps_20t, dps_1t])
	if dps_20t > MAX_IDEAL_20T:
		failures.append("[ceiling] berserk/hammer lvl20_ideal 20t = %.0f > потолка %.0f — геометрический runaway вернулся (проверь upgrade_*_exponent молота и circle_full_targets/circle_target_diminish)" % [dps_20t, MAX_IDEAL_20T])
	if dps_1t > MAX_IDEAL_1T:
		failures.append("[ceiling] berserk/hammer lvl20_ideal 1t = %.0f > потолка %.0f — solo-пик вне коридора" % [dps_1t, MAX_IDEAL_1T])

	print("[runaway-gate][ceiling] berserk/hammer lvl20_ideal: 20t=%.0f (≤%.0f) 1t=%.0f (≤%.0f)" % [dps_20t, MAX_IDEAL_20T, dps_1t, MAX_IDEAL_1T])

	if not failures.is_empty():
		for f in failures:
			push_error("Berserk runaway gate FAIL: %s" % f)
		quit(1)
		return
	print("Berserk DPS runaway gate passed.")
	quit(0)


# --- [soft-cap]: прямая проверка diminishing returns забеговых множителей --------

# Эффективный забеговый множитель ПОСЛЕ soft-cap'а — отношение выхода
# derived_parameters с множителем к выходу без него. Точка съёма публичная и
# боевая, поэтому проверка красная не только на тождественном soft-cap'е, но и
# если множитель перестали через него пропускать.
func _effective_run_multiplier(mod_key: String, output_key: String, raw: float) -> float:
	var base_value: float = float(ProgressionData.derived_parameters(SOFTCAP_PROBE_STATS, {}, {}).get(output_key, 0.0))
	if absf(base_value) <= SOFTCAP_EPS:
		return NAN
	var value: float = float(ProgressionData.derived_parameters(SOFTCAP_PROBE_STATS, {mod_key: raw}, {}).get(output_key, 0.0))
	return value / base_value


func _check_run_multiplier_softcap() -> Array:
	var channels: Array = [
		{
			"mod": "damage_multiplier",
			"out": "damage",
			"runaway": SOFTCAP_RUNAWAY_DAMAGE_MULT,
			"hard_cap": ProgressionData.RUN_DAMAGE_MULT_SOFTCAP,
		},
		{
			"mod": "attack_speed_multiplier",
			"out": "attack_speed",
			"runaway": SOFTCAP_RUNAWAY_ATTACK_SPEED_MULT,
			"hard_cap": ProgressionData.RUN_ATTACK_SPEED_MULT_SOFTCAP,
		},
	]
	var failures: Array = []
	for channel in channels:
		var mod_key: String = str(channel["mod"])
		var output_key: String = str(channel["out"])
		var runaway: float = float(channel["runaway"])
		var hard_cap: float = float(channel["hard_cap"])

		for identity_any in SOFTCAP_IDENTITY_MULTS:
			var identity := float(identity_any)
			var passed := _effective_run_multiplier(mod_key, output_key, identity)
			if not is_finite(passed) or absf(passed - identity) > SOFTCAP_EPS:
				failures.append("[soft-cap] %s: множитель %.3f (≤1.0) вышел как %.4f — soft-cap перестал быть тождественным на базе и штрафах" % [mod_key, identity, passed])

		var compression_limit := runaway * (1.0 - SOFTCAP_MIN_COMPRESSION)
		var compressed := _effective_run_multiplier(mod_key, output_key, runaway)
		if not is_finite(compressed) or compressed > compression_limit:
			failures.append("[soft-cap] %s: забеговый %.3f прошёл как %.4f > %.4f — diminishing returns больше не сжимают стак идеального билда (progression_data._soft_capped_run_multiplier)" % [mod_key, runaway, compressed, compression_limit])

		var extreme := _effective_run_multiplier(mod_key, output_key, SOFTCAP_EXTREME_MULT)
		if not is_finite(extreme) or extreme > hard_cap + SOFTCAP_EPS:
			failures.append("[soft-cap] %s: забеговый %.0f прошёл как %.4f > жёсткого потолка %.3f" % [mod_key, SOFTCAP_EXTREME_MULT, extreme, hard_cap])

		print("[runaway-gate][soft-cap] %s: %.3f→%.4f (≤%.4f) %.0f→%.4f (≤%.3f)" % [mod_key, runaway, compressed, compression_limit, SOFTCAP_EXTREME_MULT, extreme, hard_cap])
	return failures


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
	# FAN-1712: окно замера тоже стартует с фиксированной точки глобального потока.
	# Крит-роллы (scripts/berserk_weapon.gd:824) идут из того же глобального RNG, что
	# и ролл тиров, поэтому иначе длина предыдущего окна сдвигала бы поток следующего.
	seed(BASE_SEED + target_count)
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
