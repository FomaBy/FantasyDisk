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
# FAN-1039: этот файл — ДЕТЕРМИНИРОВАННЫЙ ЗАМЕР одного процесса (печатает число,
# не судит потолок). Сам гейт с медианой N изолированных прогонов и потолками —
# tools/berserk_runaway_gate.py (он и стоит в конвейере). Одиночный замер живого
# DPS имеет неустранимый межпроцессный разброс дискретными «полками» (число полных
# слэмов в окне и авто-ульта задаются стартовым джиттером процесса), поэтому
# ОДИН прогон гейтить нельзя — медиана N прогонов отбрасывает редкие «полки».
#
# Запуск замера (обязателен --fixed-fps 60 для детерминизма кадровой дельты):
#   Godot --headless --fixed-fps 60 --path . --script res://tests/berserk_dps_runaway_gate.gd
# Гейт (медиана + потолки):
#   python3 tools/berserk_runaway_gate.py
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 24.0
const FRAMES := 1440                # FAN-1039: длинное окно (24с) — краевой ±слэм-шум
                                    # становится малой долей (~40 слэмов), полки уже.
const DUMMY_HP := 1.0e9             # болванки не умирают — чистый DPS
const TARGET_LEVEL := 20
const LEVELUPS := 19                # уровни 2..20
const ARTIFACT_COUNT := 6
const RARE_SLOT_CHANCE := 0.05
const OFFER_SIZE := 3
const BASE_SEED := 20260620         # тот же сид, что в генераторе матрицы
# FAN-1039: боевой путь тянет ГЛОБАЛЬНЫЙ RNG (randf() — крит берсерка, вампиризм,
# explosion-chance игрока), который сид билд-RNG (локальный объект) не покрывает.
# Сидируем глобальный поток фиксированным зерном перед каждым живым замером,
# чтобы серия боевых бросков была воспроизводимой (см. _measure_dps).
const COMBAT_RNG_SEED := 20260713

const CHARACTER_ID := "berserk"
const WEAPON_ID := "hammer"

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

	# FAN-1039: детерминированный ЗАМЕР одного процесса (см. шапку файла). Один
	# слэм-каденс полностью воспроизводим внутри процесса; вердикт по потолку —
	# медианой N процессов в tools/berserk_runaway_gate.py.
	var dps_20t: float = await _measure_dps(CHARACTER_ID, WEAPON_ID, 20, ideal_build)
	var dps_1t: float = await _measure_dps(CHARACTER_ID, WEAPON_ID, 1, ideal_build)

	_holder.queue_free()
	await process_frame

	# Печатаем машинно-парсимую строку замера для агрегатора. RUNAWAY_SAMPLE-строку
	# читает tools/berserk_runaway_gate.py; человекочитаемая строка — для логов.
	print("RUNAWAY_SAMPLE 20t=%.1f 1t=%.1f" % [dps_20t, dps_1t])
	print("[runaway-gate] berserk/hammer lvl20_ideal: 20t=%.0f 1t=%.0f" % [dps_20t, dps_1t])

	# Единственный хард-фейл на уровне ОДНОГО процесса — сломанный режим оружия
	# (нечисловой / нулевой урон): это не шум полок, а реальная поломка.
	if not (is_finite(dps_20t) and is_finite(dps_1t)) or maxf(dps_20t, dps_1t) <= ZERO_EPS:
		push_error("Berserk runaway gate: сломан живой замер (20t=%s 1t=%s)" % [dps_20t, dps_1t])
		quit(1)
		return
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

# FAN-1039: детерминированный ЗАМЕР одного процесса. Убраны четыре источника
# межпроцессного разброса (был 2×, гейт FAN-1034 4400 пробивался шумом в ~40%):
#   1) ТАЙМИНГ. В headless без --fixed-fps дельта idle-кадра = стенным часам, и
#      480 кадров ≠ 8.0с симуляции: базовый замер копил урон за плавающее подокно,
#      но делил на жёсткие WINDOW_SECONDS. Делим на ФАКТИЧЕСКИ прошедшее сим-время
#      (сумму process-дельт) — DPS оконно-инвариантен. Под --fixed-fps 60 сумма
#      дельт == 8.0 и весь шаг физики/твинов детерминирован (обязательный флаг).
#   2) БОЕВОЙ RNG. Крит берсерка тянет ГЛОБАЛЬНЫЙ поток randf() (сид билд-RNG его
#      не покрывает). Сидируем глобальный поток фиксированным зерном перед окном.
#   3) ДРЕЙФ ИГРОКА. Ближняя дамми (58px) перекрывала тело игрока, move_and_slide
#      сдвигал центр круга → менялись тир-индексы diminish целей (до ±2× по 20t).
#      Пиним игрока (и velocity) к спавну каждый кадр, как и дамми к якорям.
#   4) АВТО-УЛЬТА. Заряд ульты копится от нанесённого урона и авто-кастует в
#      _physics_process; berserk-эхо добавляло ×ultimate_multiplier (~1.2×). Гейт
#      меряет SUSTAIN без ульты (как задумано) — держим заряд на нуле весь замер.
# Остаётся неустранимая дискретная «полка» (число полных слэмов в окне, задаётся
# стартовым сабкадровым джиттером процесса) — её отбрасывает медиана N процессов
# в tools/berserk_runaway_gate.py. Внутри процесса замер полностью воспроизводим.
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
	# источник №4: убираем авто-ульту из sustain-замера — недостижимый потолок заряда
	player.set("ultimate_max_charge", 1.0e18)
	player.set("ultimate_charge", 0.0)
	await process_frame

	var dummies := _spawn_dummies(player.global_position, target_count)
	var anchor_positions: Array = []
	for enemy in dummies:
		anchor_positions.append((enemy as Node2D).global_position)
	await process_frame

	seed(COMBAT_RNG_SEED + target_count)  # источник №2: детерминизм боевого крит-RNG

	var player_spawn: Vector2 = player.global_position
	var hp_before := 0.0
	for enemy in dummies:
		hp_before += float(enemy.get("health"))

	var elapsed := 0.0
	for _frame in range(FRAMES):
		await process_frame
		elapsed += _holder.get_process_delta_time()  # источник №1: реальное сим-время окна
		# источник №3: пиним игрока (иначе дрейфует от контактной дамми)
		player.global_position = player_spawn
		player.set("velocity", Vector2.ZERO)
		# источник №4: гасим заряд ульты, чтобы авто-каст не подмешивал ×ultimate_multiplier
		player.set("ultimate_charge", 0.0)
		for i in range(dummies.size()):
			var enemy := dummies[i] as Node2D
			if is_instance_valid(enemy):
				enemy.global_position = anchor_positions[i]

	var hp_after := 0.0
	for enemy in dummies:
		if is_instance_valid(enemy):
			hp_after += float(enemy.get("health"))

	return maxf(hp_before - hp_after, 0.0) / maxf(elapsed, ZERO_EPS)


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
