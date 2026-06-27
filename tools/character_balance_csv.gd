extends SceneTree

## Character Balance DPS Matrix (запрос ревью баланса всех персонажей).
##
## Для КАЖДОЙ пары класс+оружие меряет фактический исходящий DPS реального
## Player+оружие против стационарных болванок в ТРЁХ состояниях прокачки:
##   • lvl1            — базовые статы, без апгрейдов;
##   • lvl20_ideal     — 19 level-up-карт «лучшее из 3 предложенных» (умелый
##                       игрок под RNG оффера) + топ-артефакты по классовому весу;
##   • lvl20_random    — 19 level-up-карт «случайный выбор из 3» (небрежный
##                       игрок) + случайные артефакты.
## …и по ТРЁМ числам целей: 1 (дуэль спереди), 5 и 20 (окружающий рой —
## честная экспозиция для радиальных/конусных/AoE-схем, как в реальном бою).
##
## Источник прогрессии (скоуп ревью): level-up-карты (ProgressionData
## .LEVEL_UP_REWARDS + редкий main-stat) и артефакты (ARTIFACTS). НЕ включены:
## магазин/золото, Возвышение, мета-древо умений, ультимейты (меряется sustain).
##
## Идёт через РЕАЛЬНЫЙ player.apply_reward() — полностью верно отражает stat/mods
## билда (множители урона/скорости/крит/DoT/призывы), а не формулу.
##
## Запуск: Godot --headless --path . --script res://tools/character_balance_csv.gd
## Вывод: build/character_balance_dps.csv (+ _README.md с методикой).

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 8.0
const FRAMES := 480                 # 8с * 60fps
const DUMMY_HP := 1.0e9             # болванки не умирают — чистый DPS
const TARGET_COUNTS := [1, 5, 20]
const TARGET_LEVEL := 20
const LEVELUPS := 19                # уровни 2..20
const ARTIFACT_COUNT := 6           # типовой набор за забег к 20 уровню
const RARE_SLOT_CHANCE := 0.05      # как MAIN_STAT_SLOT_CHANCE в ui_screens
const OFFER_SIZE := 3               # карт в оффере уровня
const BASE_SEED := 20260620
const CSV_PATH := "res://build/character_balance_dps.csv"
const README_PATH := "res://build/character_balance_dps_README.md"
const BAND_REPORT_PATH := "res://build/character_balance_band.md"
# SCRUM-544: срезы, по которым гейтится comfort-нормированная полоса (lvl20-оптимум).
const BAND_SLICES := ["ideal_1", "ideal_5", "ideal_20"]

var _holder: Node2D


func _initialize() -> void:
	await process_frame
	_holder = Node2D.new()
	_holder.name = "BalanceCsvHolder"
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	var rows: Array = []
	var seed_counter := BASE_SEED
	for character_id in ProgressionData.character_ids():
		var cid := str(character_id)
		for weapon_id in ProgressionData.weapon_ids(cid):
			var wid := str(weapon_id)
			var config: Dictionary = ProgressionData.weapon(cid, wid)
			var archetype: String = ProgressionData.weapon_archetype(config)

			# Детерминированные RNG на пару — воспроизводимо между прогонами.
			var rng_ideal := RandomNumberGenerator.new()
			rng_ideal.seed = seed_counter
			seed_counter += 1
			var rng_random := RandomNumberGenerator.new()
			rng_random.seed = seed_counter
			seed_counter += 1

			var builds := {
				"lvl1": [],
				"ideal": _build_levelups(cid, archetype, true, rng_ideal) + _build_artifacts(cid, archetype, true, rng_ideal),
				"random": _build_levelups(cid, archetype, false, rng_random) + _build_artifacts(cid, archetype, false, rng_random),
			}

			var row := {"class": cid, "weapon": wid, "archetype": archetype}
			for state in ["lvl1", "ideal", "random"]:
				for count in TARGET_COUNTS:
					var dps: float = await _measure_dps(cid, wid, count, builds[state])
					row["%s_%d" % [state, count]] = dps
			rows.append(row)
			print("%s/%s [%s] 1t: l1=%.1f id=%.1f rnd=%.1f | 5t: l1=%.1f id=%.1f rnd=%.1f | 20t: l1=%.1f id=%.1f rnd=%.1f" % [
				cid, wid, archetype,
				row["lvl1_1"], row["ideal_1"], row["random_1"],
				row["lvl1_5"], row["ideal_5"], row["random_5"],
				row["lvl1_20"], row["ideal_20"], row["random_20"]])

	_write_csv(rows)
	_write_readme(rows)
	_validate_band(rows)
	_holder.queue_free()
	await process_frame
	quit(0)


# --- Прогрессия: сбор списка наград (level-up + артефакты) ---------------------

func _build_levelups(character_id: String, archetype: String, ideal: bool, rng: RandomNumberGenerator) -> Array:
	var chosen: Array = []
	for _level in range(LEVELUPS):
		var offer := _roll_offer(character_id, rng)
		if offer.is_empty():
			continue
		if ideal:
			var best_index := 0
			var best_score := -1.0e9
			for index in range(offer.size()):
				var score := _dps_score(offer[index], archetype)
				if score > best_score:
					best_score = score
					best_index = index
			chosen.append(offer[best_index])
		else:
			chosen.append(offer[rng.randi_range(0, offer.size() - 1)])
	return chosen


# Эвристический «DPS-вес» награды для выбора умелого игрока: предпочитает
# множители урона/скорости/крит/профильный main-stat и игнорирует
# защитные/утилитарные апгрейды (knockback, dodge, hp, подбор...). Это и есть
# «идеальная прокачка под DPS» — а не классовый attribute-вес (тот может
# застаканить knockback и обнулить одиночный урон).
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
					pass  # защита/утилита — нулевой DPS-вклад
	return score


func _stat_dps_value(stat_id: String, archetype: String) -> float:
	# Профильность main-stat по архетипу (грубо отражает derived_parameters).
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
	# Зеркалит ui_screens._random_level_up_rewards: микс обычных апгрейдов и
	# редкого (~5%/слот) роста основной характеристики, взвешенный отбор.
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


func _build_artifacts(character_id: String, archetype: String, ideal: bool, rng: RandomNumberGenerator) -> Array:
	var pool: Array = ProgressionData.reward_pool(character_id).filter(func(reward: Dictionary) -> bool:
		return str(reward.get("kind", "")) == "artifact"
	)
	if pool.is_empty():
		return []
	var chosen: Array = []
	if ideal:
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _dps_score(a, archetype) > _dps_score(b, archetype)
		)
		for index in range(mini(ARTIFACT_COUNT, pool.size())):
			chosen.append(pool[index])
	else:
		while chosen.size() < ARTIFACT_COUNT and not pool.is_empty():
			var index := rng.randi_range(0, pool.size() - 1)
			chosen.append(pool[index])
			pool.remove_at(index)
	return chosen


# --- Замер фактического DPS ---------------------------------------------------

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
	# Неуязвим/неподвижен — меряем только исходящий урон.
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	# Применяем собранный билд (level-up-карты + артефакты) реальным путём.
	for reward in rewards:
		if player.has_method("apply_reward"):
			player.apply_reward(reward)
	if not rewards.is_empty():
		player.set("level", TARGET_LEVEL)
	await process_frame

	var dummies := _spawn_dummies(player.global_position, target_count)
	# Болванки-«манекены»: фиксируем позиции, нейтрализуя knockback-дрейф —
	# иначе круговые/толчковые схемы выталкивают цель из радиуса и DPS обнуляется
	# (артефакт замера, а не баланс). Меряем чистую пропускную способность.
	var anchor_positions: Array = []
	for enemy in dummies:
		anchor_positions.append((enemy as Node2D).global_position)
	await process_frame

	var hp_before := 0.0
	for enemy in dummies:
		hp_before += float(enemy.get("health"))

	for _frame in range(FRAMES):
		await process_frame
		for i in range(dummies.size()):
			var enemy := dummies[i] as Node2D
			if is_instance_valid(enemy):
				enemy.global_position = anchor_positions[i]

	var hp_after := 0.0
	for enemy in dummies:
		if is_instance_valid(enemy):
			hp_after += float(enemy.get("health"))
	return maxf(hp_before - hp_after, 0.0) / WINDOW_SECONDS


func _spawn_dummies(player_pos: Vector2, target_count: int) -> Array:
	# 1 цель — дуэль спереди (как solo в live_combat_harness).
	# 5/20 — окружающий рой (фи-таксис диск вокруг игрока): честная экспозиция
	# радиальным/конусным/проджектайл-схемам, как в реальном бою.
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


# --- SCRUM-544: детерминированная валидация comfort-нормированной полосы -------

# Для каждого среза (1t/5t/20t на lvl20_ideal) считает comfort-нормированный DPS
# каждого оружия (= measured / comfort_weight), медиану по всем оружиям и проверяет,
# что max/min лежат в [1-tol, 1+tol] от медианы (acceptance ±20%). Печатает сводку
# и пишет build/character_balance_band.md. Детерминировано (те же сиды, что и CSV).
func _validate_band(rows: Array) -> void:
	var tol: float = ProgressionData.COMFORT_BAND_TOLERANCE
	var lines := PackedStringArray()
	lines.append("# Character Balance — comfort-нормированная полоса (SCRUM-544)")
	lines.append("")
	lines.append("Сгенерировано `tools/character_balance_csv.gd`. Допуск полосы: ±%.0f%% от медианы." % (tol * 100.0))
	lines.append("Нормировка: `comfort_normalized = measured_dps / comfort_weight[class]` (см. `progression_data_balance.gd` COMFORT_WEIGHTS).")
	lines.append("")
	var all_pass := true
	for slice in BAND_SLICES:
		var entries: Array = []
		var values: Array = []
		for row in rows:
			var cid: String = str(row["class"])
			var wid: String = str(row["weapon"])
			var raw: float = float(row[slice])
			var norm: float = ProgressionData.comfort_normalized_dps(cid, wid, raw)
			entries.append({"class": cid, "weapon": wid, "raw": raw, "norm": norm})
			values.append(norm)
		values.sort()
		var median: float = _median(values)
		var lo: float = median * (1.0 - tol)
		var hi: float = median * (1.0 + tol)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["norm"]) > float(b["norm"]))
		var min_norm: float = float(entries[entries.size() - 1]["norm"])
		var max_norm: float = float(entries[0]["norm"])
		var spread: float = max_norm / maxf(min_norm, 0.001)
		var slice_pass: bool = min_norm >= lo and max_norm <= hi
		all_pass = all_pass and slice_pass
		var violations: Array = entries.filter(func(e: Dictionary) -> bool:
			return float(e["norm"]) < lo or float(e["norm"]) > hi)
		print("[BAND %s] median=%.1f band=[%.1f..%.1f] min=%.1f max=%.1f spread=%.1fx → %s (нарушений %d/%d)" % [
			slice, median, lo, hi, min_norm, max_norm, spread,
			("PASS" if slice_pass else "FAIL"), violations.size(), entries.size()])
		lines.append("## Срез `%s` — %s" % [slice, ("PASS" if slice_pass else "FAIL")])
		lines.append("")
		lines.append("- медиана нормированного DPS: **%.1f**, полоса [%.1f .. %.1f]" % [median, lo, hi])
		lines.append("- факт: min **%.1f**, max **%.1f**, разброс **%.1fx** (цель ≤ %.2fx)" % [
			min_norm, max_norm, spread, (1.0 + tol) / (1.0 - tol)])
		lines.append("- нарушений полосы: **%d / %d**" % [violations.size(), entries.size()])
		if not violations.is_empty():
			lines.append("")
			lines.append("| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |")
			lines.append("|---|--:|--:|--:|--:|")
			for e in violations:
				var w: float = ProgressionData.comfort_weight(str(e["class"]), str(e["weapon"]))
				lines.append("| %s/%s | %.0f | %.2f | %.0f | %.2fx |" % [
					e["class"], e["weapon"], float(e["raw"]), w, float(e["norm"]),
					float(e["norm"]) / maxf(median, 0.001)])
		lines.append("")
	lines.append("---")
	lines.append("")
	lines.append("**Итог полосы: %s**" % ("ПОЛОСА ВЫДЕРЖАНА (±%.0f%%)" % (tol * 100.0) if all_pass else "ПОЛОСА НЕ ВЫДЕРЖАНА — требуется тюнинг"))
	print("[BAND] Итог: %s" % ("PASS" if all_pass else "FAIL"))
	var file := FileAccess.open(BAND_REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
		print("Band report: %s" % ProjectSettings.globalize_path(BAND_REPORT_PATH))


func _median(sorted_values: Array) -> float:
	if sorted_values.is_empty():
		return 0.0
	var n := sorted_values.size()
	if n % 2 == 1:
		return float(sorted_values[n / 2])
	return (float(sorted_values[n / 2 - 1]) + float(sorted_values[n / 2])) * 0.5


# --- Вывод --------------------------------------------------------------------

func _write_csv(rows: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var lines := PackedStringArray()
	lines.append("class,weapon,archetype," +
		"lvl1_1t,lvl1_5t,lvl1_20t," +
		"lvl20_ideal_1t,lvl20_ideal_5t,lvl20_ideal_20t," +
		"lvl20_random_1t,lvl20_random_5t,lvl20_random_20t")
	for row in rows:
		lines.append("%s,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [
			row["class"], row["weapon"], row["archetype"],
			row["lvl1_1"], row["lvl1_5"], row["lvl1_20"],
			row["ideal_1"], row["ideal_5"], row["ideal_20"],
			row["random_1"], row["random_5"], row["random_20"]])
	var file := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать CSV: %s" % CSV_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Balance CSV: %s (строк %d)" % [ProjectSettings.globalize_path(CSV_PATH), rows.size()])


func _write_readme(rows: Array) -> void:
	var lines := PackedStringArray()
	lines.append("# Character Balance DPS Matrix — методика")
	lines.append("")
	lines.append("Сгенерировано `tools/character_balance_csv.gd`. Данные — `character_balance_dps.csv`.")
	lines.append("")
	lines.append("## Что меряется")
	lines.append("Фактический исходящий DPS реального Player+оружие против стационарных болванок за %.0fс (без ультимейта — sustain). Для каждой пары класс+оружие — 3 состояния прокачки × 3 числа целей." % WINDOW_SECONDS)
	lines.append("")
	lines.append("## Состояния прокачки")
	lines.append("- **lvl1** — базовые статы, без апгрейдов.")
	lines.append("- **lvl20_ideal** — %d level-up-карт по принципу «лучшее из %d предложенных» (умелый игрок под RNG оффера, выбор по классовому весу `level_up_reward_weight`) + топ-%d артефактов по тому же весу." % [LEVELUPS, OFFER_SIZE, ARTIFACT_COUNT])
	lines.append("- **lvl20_random** — %d level-up-карт «случайный выбор из %d» (небрежный игрок) + %d случайных артефактов." % [LEVELUPS, OFFER_SIZE, ARTIFACT_COUNT])
	lines.append("")
	lines.append("Скоуп прогрессии: level-up-карты (`LEVEL_UP_REWARDS` + редкий main-stat ~%.0f%%/слот) и артефакты (`ARTIFACTS`). НЕ включены: магазин/золото, Возвышение, мета-древо умений." % (RARE_SLOT_CHANCE * 100.0))
	lines.append("Применение — через реальный `player.apply_reward()`, поэтому множители урона/скорости/крита/DoT/призывов учтены точно (а не по формуле).")
	lines.append("")
	lines.append("## Числа целей и геометрия")
	lines.append("- **1 цель** — одиночная болванка спереди (дуэль).")
	lines.append("- **5 / 20 целей** — окружающий рой (фи-таксис диск вокруг игрока). Это честная экспозиция для радиальных/конусных/AoE-схем (как в реальном бою), а не односторонний кластер.")
	lines.append("- Болванки — неподвижные **манекены** (позиции зафиксированы, knockback-дрейф нейтрализован): иначе круговые/толчковые схемы выталкивают цель из радиуса и DPS ложно обнуляется.")
	lines.append("")
	lines.append("DPS на 5/20 целях — это СУММАРНАЯ пропускная способность по всем целям за секунду (total throughput), а не на одну цель. Поэтому у настоящих AoE 20t намного выше 1t, а у одиночных схем 20t ≈ 1t — это и показывает «подходящую» ось. Идеал-колонка — синтетический потолок (умелый стак апгрейдов по плотному неподвижному паку, без смертей/движения врагов), читать как ceiling, не как типичный бой.")
	lines.append("")
	lines.append("«Подходящая» ось зависит от архетипа: single-target (melee/projectile/beam/sniper) сильны на 1 цели; aoe/aura/summon — на 5/20. Колонка `archetype` помогает читать, какая ось профильная.")
	lines.append("")
	lines.append("Воспроизводимость: фиксированные сиды (BASE_SEED=%d). lvl20_random — один представительный «невезучий» прогон на пару, не усреднение." % BASE_SEED)
	lines.append("")
	lines.append("Пар измерено: %d. Сетка: 3 состояния × 3 числа целей = 9 DPS-колонок на пару." % rows.size())
	var file := FileAccess.open(README_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать README: %s" % README_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
