extends SceneTree

# SCRUM-533: регресс-гейт на ЖИВОЙ runaway ЛУЖ-DoT (chemist), который формульный
# гейт НЕ ловит. estimate_weapon_budget бюджетит лужу как pool_targets ≤ 4
# (_budget_hit_model, mode aoe_projectile), но живой тик лужи раньше лил полный
# урон ВСЕМ целям в круге → на плотном паке из 20 целей chemist/acid_flask
# lvl20_ideal 20t ≈ 112k (кратно выше budget'а, > 2.5x медианы класс-лидеров).
# SCRUM-533 ввёл диминишинг по числу целей в тике лужи (ClassWeapon
# ._damage_enemies_in_pool), приведя живой throughput к формульному бюджету.
# Этот гейт инстанцирует РЕАЛЬНОГО Player + оружие-лужу, прокачивает «идеальным»
# билдом до lvl20 (как tools/character_balance_csv.gd) и меряет фактический 20t.
# Падаем, если runaway лужи вернулся (откат диминишинга / убран cap pool-целей).
#
# Запуск: Godot --headless --path . --script res://tests/pool_dot_runaway_gate.gd
# Отдельный изолированный файл (анти-коллизия с занятыми runtime_smoke/harness).

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 8.0
const FRAMES := 480
const DUMMY_HP := 1.0e9
const TARGET_LEVEL := 20
const LEVELUPS := 19
const ARTIFACT_COUNT := 6
const RARE_SLOT_CHANCE := 0.05
const OFFER_SIZE := 3
const BASE_SEED := 20260620
const ZERO_EPS := 0.01

# Потолок lvl20_ideal 20t для оружия-лужи после SCRUM-533. До фикса было
# chemist/acid_flask ≈ 112k, blast_powder ≈ 65k; после диминишинга ≈ 44k / 29k.
# FAN-1034: ревизия атрибутов слила dot damage+speed в одну карту — идеальный
# dot-билд больше не сжигает 8 пиков на две оси, освобождённые пики уходят в
# damage_multiplier (который множит и DoT). Живая соло-база поднялась 44k → ~65-70k
# без каких-либо правок диминишинга луж (замер 74.8k при dot_speed_flat 0.2,
# затюнено до 0.15). Потолок рекалиброван с прежним запасом: откат
# pool-диминишинга (паттерн ×2.5, т.е. ≥170k от новой базы) ловится уверенно.
# FAN-1062: потолок перекалиброван под честную времябазу (см. _measure_dps):
# старый 80000 калибровался на раздутом фикс-окне (замер 67549); честные
# значения 6993..7803 (±6%, N=2). Потолок = среднее ×~1.35 (шум + малый рост).
const MAX_POOL_IDEAL_20T := 10000.0

# Оружие-лужи (leaves_pool), которые давали выброс на плотном паке.
# SCRUM-943: blast_powder больше не оставляет лужу (редизайн — быстрый прямой
# физический AoE), из пар исключён; ось луж Химика держит только acid_flask
# (SCRUM-944: длинные лужи + перманентные заряды, trait ×1.5 — гейт ловит
# суммарный live-разгон периодики).
const POOL_PAIRS := [
	["chemist", "acid_flask"],
]

var _holder: Node2D


func _initialize() -> void:
	await process_frame
	_holder = Node2D.new()
	_holder.name = "PoolRunawayGateHolder"
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	var seed_of := _seed_map()
	var failures: Array = []
	for pair in POOL_PAIRS:
		var cid: String = pair[0]
		var wid: String = pair[1]
		var config: Dictionary = ProgressionData.weapon(cid, wid)
		if config.is_empty():
			failures.append("%s/%s не найдено в реестре" % [cid, wid])
			continue
		if not bool(config.get("leaves_pool", false)):
			failures.append("%s/%s больше не leaves_pool — гейт устарел, обновить POOL_PAIRS" % [cid, wid])
			continue
		var arche: String = ProgressionData.weapon_archetype(config)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed_of.get("%s/%s" % [cid, wid], BASE_SEED))
		var build: Array = _build_levelups(cid, arche, rng) + _build_artifacts(cid, arche, rng)
		var dps_20t: float = await _measure_dps(cid, wid, 20, build)
		print("[pool-gate] %s/%s lvl20_ideal 20t=%.0f (≤%.0f)" % [cid, wid, dps_20t, MAX_POOL_IDEAL_20T])
		if not is_finite(dps_20t):
			failures.append("%s/%s: нечисловой живой DPS (20t=%s)" % [cid, wid, dps_20t])
		elif dps_20t <= ZERO_EPS:
			failures.append("%s/%s: 0 живого урона за %.0fс — режим оружия сломан" % [cid, wid, WINDOW_SECONDS])
		elif dps_20t > MAX_POOL_IDEAL_20T:
			failures.append("%s/%s lvl20_ideal 20t = %.0f > потолка %.0f — runaway лужи вернулся (проверь ClassWeapon._damage_enemies_in_pool / диминишинг pool-целей)" % [cid, wid, dps_20t, MAX_POOL_IDEAL_20T])

	_holder.queue_free()
	await process_frame

	if not failures.is_empty():
		for f in failures:
			push_error("Pool DoT runaway gate FAIL: %s" % f)
		quit(1)
		return
	print("Pool DoT runaway gate passed.")
	quit(0)


# --- генератор-совместимая раздача сидов + сборка идеального билда ----------------

func _seed_map() -> Dictionary:
	var seed_counter := BASE_SEED
	var out := {}
	for cid_any in ProgressionData.character_ids():
		var cid := str(cid_any)
		for wid_any in ProgressionData.weapon_ids(cid):
			out["%s/%s" % [cid, str(wid_any)]] = seed_counter
			seed_counter += 2
	return out


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


func _build_artifacts(character_id: String, archetype: String, _rng: RandomNumberGenerator) -> Array:
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
	var score := 0.0
	var stats: Dictionary = reward.get("stats", {})
	for stat_id in stats.keys():
		score += _stat_dps_value(str(stat_id), archetype) * float(stats[stat_id])
	for source_key in ["mods", "affinity_mods"]:
		var mods: Dictionary = reward.get(source_key, {})
		for key in mods.keys():
			var value := float(mods[key])
			match str(key):
				"damage_multiplier": score += 100.0 * (value - 1.0)
				"attack_speed_multiplier": score += 95.0 * (value - 1.0)
				"crit_chance_flat": score += 60.0 * value
				"crit_damage_flat": score += 18.0 * value
				"aoe_radius_multiplier": score += (42.0 if multi else 10.0) * (value - 1.0)
				"range_multiplier": score += (26.0 if multi else 8.0) * (value - 1.0)
				"dot_speed_flat": score += 12.0 * value
				"dot_damage_flat": score += 6.0 * value
				"summon_bonus": score += (30.0 if archetype == "summon" else 3.0) * value
				"vampiric_chance_flat", "vampiric_amount_flat": score += 0.5 * value
				"projectile_speed_flat": score += 0.02 * value
				_: pass
	return score


func _stat_dps_value(stat_id: String, archetype: String) -> float:
	match stat_id:
		"agility": return 8.0
		"strength": return 8.0 if ["melee", "projectile"].has(archetype) else 5.0
		"perception": return 8.0 if ["projectile", "aoe"].has(archetype) else 5.0
		"intelligence": return 8.0 if ["beam", "aoe"].has(archetype) else 5.0
		"knowledge": return 5.0
		"leadership": return 9.0 if archetype == "summon" else 3.0
		"energy": return 4.0
		"endurance": return 1.0
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

	# FAN-1039/FAN-1062: окно по ИГРОВОМУ времени с ранним выходом (зеркало фикса
	# tools/character_balance_csv.gd 8dd7e4fb4). Прежние 480 фикс-кадров под
	# пул-нагрузкой ползли по стене >15 мин (кадры дорожают с числом луж) — гейт
	# зависал; при этом деление на номинал 8с раздувало DPS. Теперь: крутим до
	# 8с игрового времени (или страховочного капа кадров) и делим на факт.
	var elapsed_game_time := 0.0
	var frames := 0
	while elapsed_game_time < WINDOW_SECONDS and frames < FRAMES * 2:
		await process_frame
		elapsed_game_time += _holder.get_process_delta_time()
		frames += 1
		for i in range(dummies.size()):
			var enemy := dummies[i] as Node2D
			if is_instance_valid(enemy):
				enemy.global_position = anchor_positions[i]

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
			var angle := float(i) * 2.3999632
			pos = player_pos + Vector2.RIGHT.rotated(angle) * radius
		enemy.global_position = pos
		enemy.set("max_health", DUMMY_HP)
		enemy.set("health", DUMMY_HP)
		enemy.set("move_speed", 0.0)
		enemy.set("contact_damage", 0.0)
		dummies.append(enemy)
	return dummies
