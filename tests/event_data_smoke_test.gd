extends SceneTree

# Smoke-тест event_data.gd (был непокрыт). Случайные события — ветвящийся
# контент (события -> выборы -> эффекты); поломка всплыла бы только когда игрок
# попадёт на событие в забеге. Валидирует структуру, ссылки на статы/типы боя,
# адекватность чисел и аксессоры event_ids/event_by_id/pick_event.
# Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/event_data_smoke_test.gd

const EventData := preload("res://scripts/event_data.gd")
const StatFormulas := preload("res://scripts/stat_formulas.gd")

const VALID_COMBAT_TYPES := ["battle", "elite", "boss"]

# SCRUM-495: веса «ценности» исхода для EV-инварианта (рискованная/платная опция события
# не должна давать апсайд слабее, чем безопасная опция в том же событии). Это РЕГРЕСС-ГЕЙТ,
# а не ребаланс — данные event_data.gd не трогаем, калибруем только эти веса. Цель — грубый,
# устойчивый порядок «рисковое ≥ безопасного», а не точный EV: веса подобраны так, чтобы на
# текущих (ребалансированных SCRUM-476) данных гейт проходил с запасом, но ловил явное
# занижение награды рисковой опции (см. негативный само-тест). Шкала: 1 золото = 1 очко.
const MONEY_W := 0.6           # 1 золото = 0.6 очка — разовое золото ЦЕНИТСЯ НИЖЕ перманентных
                               # наград (1 стат = 25 = ~42 золота). Калибровка SCRUM-501: новое
                               # событие abandoned_forge (риск etch_sigil +12% урон/+6% AS vs безопасное
                               # salvage_scrap +22 золота) — перманентный боевой бафф НЕ должен считаться
                               # слабее 22 разового золота; при MONEY_W=1.0 гейт ложно краснел. 0.6 даёт
                               # верный порядок «бафф > разовое золото» с запасом (ratio ≥ 1.36 на всех 5 парах).
const STAT_W := 25.0           # +1 базовый стат ≈ 25 (перманентный бафф забега; дороже разового золота)
const MOD_W := 1.0             # мультипликатор m>1 → +(m-1)*100*MOD_W (т.е. +12% = +12 очков)
const MOD_FLAT_W := 50.0       # флэт-мод (defense_flat/summon_bonus) → значение*50 (мелкие, но ценные)
const HEAL_W := 60.0           # лечение 100% HP ≈ 60 очков (situational, дешевле перманента)
const ARTIFACT_W := 50.0       # случайный артефакт ≈ 50 очков (грубая оценка среднего дропа)
const COMBAT_REWARD_W := 1.0   # combat.money/xp_multiplier >1 → +(m-1)*100 (бонус добычи за бой)
const SAFE_MARGIN := 1.0       # рисковая опция обязана быть НЕ СЛАБЕЕ безопасной (>=, без скидки)

# Мультипликатор-моды, которые являются ШТРАФОМ (усложняют бой), а не наградой: их апсайд
# не учитываем, иначе «враги на 25% живучее» посчиталось бы как +25 ценности. Семантика
# как в ui_screens (reward применяет *_multiplier мультипликативно, но enemy_health_multiplier
# в исходе события — это побочный штраф опции отдыха, не баф героя).
const DOWNSIDE_MOD_KEYS := {
	"enemy_health_multiplier": true,
}


func _initialize() -> void:
	var errors: Array = []
	var valid_stats := {}
	for stat_id in StatFormulas.BASE_STAT_ORDER:
		valid_stats[str(stat_id)] = true

	# Негативный само-тест ДО основной проверки: доказываем, что EV-гейт реально ловит
	# регресс (искусственно заниженная награда рисковой опции). Реальные данные не трогаем —
	# событие синтетическое, in-memory. Если гейт НЕ вернул ошибку — это баг гейта.
	_run_ev_gate_self_test()

	var ev_checked := _check_events(errors, valid_stats)
	_check_accessors(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Event data smoke: %s" % e)
		push_error("Event data smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Event data smoke test passed (%d событий, EV-инвариант проверен на %d событиях с парой risky+safe)." % [EventData.RANDOM_EVENTS.size(), ev_checked])
	quit(0)


func _player_text_ok(text: String, id: String) -> bool:
	if text.strip_edges() == "":
		return false
	if text == id:
		return false
	var low := text.to_lower()
	return not (low == "null" or low.begins_with("res://"))


# Проверяет, что ключи stats-эффекта — валидные базовые статы.
func _check_stats_keys(errors: Array, valid_stats: Dictionary, stats: Dictionary, where: String) -> void:
	for key in stats:
		if not valid_stats.has(str(key)):
			errors.append("%s: ссылка на неизвестный стат '%s'" % [where, key])


# Проверяет блок исхода (choice/success/failure): stats, combat, числа.
func _check_outcome(errors: Array, valid_stats: Dictionary, outcome: Dictionary, where: String) -> void:
	if outcome.has("stats"):
		if not (outcome["stats"] is Dictionary):
			errors.append("%s: stats не Dictionary" % where)
		else:
			_check_stats_keys(errors, valid_stats, outcome["stats"], where)
	if outcome.has("combat"):
		var combat: Dictionary = outcome["combat"]
		var ctype := str(combat.get("type", ""))
		if not VALID_COMBAT_TYPES.has(ctype):
			errors.append("%s: combat.type '%s' вне %s" % [where, ctype, str(VALID_COMBAT_TYPES)])
		if combat.has("enemy_health_multiplier") and float(combat["enemy_health_multiplier"]) <= 0.0:
			errors.append("%s: enemy_health_multiplier <= 0" % where)
		if combat.has("money_multiplier") and float(combat["money_multiplier"]) <= 0.0:
			errors.append("%s: money_multiplier <= 0" % where)
	if outcome.has("cost_money") and int(outcome["cost_money"]) < 0:
		errors.append("%s: отрицательный cost_money" % where)
	if outcome.has("money") and int(outcome["money"]) < 0:
		errors.append("%s: отрицательный money" % where)
	if outcome.has("health_percent_cost"):
		var hpc := float(outcome["health_percent_cost"])
		if hpc <= 0.0 or hpc > 1.0:
			errors.append("%s: health_percent_cost вне (0,1] (%.2f)" % [where, hpc])
	if outcome.has("random_outcomes"):
		if not (outcome["random_outcomes"] is Array) or (outcome["random_outcomes"] as Array).is_empty():
			errors.append("%s: random_outcomes пуст/не массив" % where)
	if outcome.has("heal_percent"):
		var heal := float(outcome["heal_percent"])
		if heal <= 0.0 or heal > 1.0:
			errors.append("%s: heal_percent вне (0,1] (%.2f)" % [where, heal])
	# post_combat применяет статы ПОСЛЕ боя — его stats тоже должны быть валидными
	# базовыми статами (раньше не проверялось: опечатка в ключе прошла бы молча).
	if outcome.has("post_combat"):
		if not (outcome["post_combat"] is Dictionary):
			errors.append("%s: post_combat не Dictionary" % where)
		else:
			var post: Dictionary = outcome["post_combat"]
			if post.has("stats"):
				if not (post["stats"] is Dictionary):
					errors.append("%s: post_combat.stats не Dictionary" % where)
				else:
					_check_stats_keys(errors, valid_stats, post["stats"], where + ".post_combat")


func _check_events(errors: Array, valid_stats: Dictionary) -> int:
	var events := EventData.RANDOM_EVENTS
	if events.size() < 5:
		errors.append("RANDOM_EVENTS подозрительно мал (%d) — гейт прошёл бы вакуумно" % events.size())
	var ev_checked := 0
	var seen := {}
	for entry in events:
		var event: Dictionary = entry
		var eid := str(event.get("id", ""))
		if eid == "" or seen.has(eid):
			errors.append("событие с пустым/дублирующимся id '%s'" % eid)
			continue
		seen[eid] = true
		if not _player_text_ok(str(event.get("title", "")), eid):
			errors.append("событие '%s': негодный title" % eid)
		if not _player_text_ok(str(event.get("story", "")), eid):
			errors.append("событие '%s': негодная story" % eid)
		var choices: Array = event.get("choices", [])
		if choices.size() < 2:
			errors.append("событие '%s': < 2 выборов (%d)" % [eid, choices.size()])
		var choice_ids := {}
		for choice_entry in choices:
			var choice: Dictionary = choice_entry
			var cid := str(choice.get("id", ""))
			var where := "%s/%s" % [eid, cid]
			if cid == "" or choice_ids.has(cid):
				errors.append("событие '%s': пустой/дублирующийся выбор '%s'" % [eid, cid])
				continue
			choice_ids[cid] = true
			if not _player_text_ok(str(choice.get("title", "")), cid):
				errors.append("%s: негодный title выбора" % where)
			if not _player_text_ok(str(choice.get("description", "")), cid):
				errors.append("%s: негодное описание выбора" % where)
			# Проверка характеристики -> валидный стат + ветви success/failure.
			if choice.has("check"):
				var check: Dictionary = choice["check"]
				if not valid_stats.has(str(check.get("stat", ""))):
					errors.append("%s: check.stat '%s' не базовый стат" % [where, check.get("stat", "")])
				if int(check.get("difficulty", 0)) <= 0:
					errors.append("%s: check.difficulty <= 0" % where)
				if not choice.has("success") or not choice.has("failure"):
					errors.append("%s: check без ветвей success/failure" % where)
				if choice.has("success"):
					_check_outcome(errors, valid_stats, choice["success"], where + ".success")
				if choice.has("failure"):
					_check_outcome(errors, valid_stats, choice["failure"], where + ".failure")
			# Эффекты на уровне выбора.
			_check_outcome(errors, valid_stats, choice, where)
		# SCRUM-495: EV/ценностный инвариант на уровне события (после структурных проверок опций) —
		# рисковая/платная опция не слабее по апсайду, чем безопасная в этом же событии. Возвращает
		# true, если у события была пара risky+safe (инвариант реально проверялся, а не пропущен).
		if _check_event_ev(errors, event):
			ev_checked += 1
	return ev_checked


# SCRUM-495: опция считается рискованной/платной, если несёт стоимость или вероятность провала.
# Покрывает все формы риска/платы из данных: явный флаг risk, запуск боя (combat), плата золотом
# (cost_money>0), плата HP (health_percent_cost>0), проверка характеристики (check — вероятностный
# исход со штрафом при провале). Иначе опция «безопасная/бесплатная».
func _choice_is_risky_or_paid(choice: Dictionary) -> bool:
	if choice.get("risk", false) == true:
		return true
	if choice.has("combat"):
		return true
	if int(choice.get("cost_money", 0)) > 0:
		return true
	if float(choice.get("health_percent_cost", 0.0)) > 0.0:
		return true
	if choice.has("check"):
		return true
	return false


# SCRUM-495: ценность ОДНОГО блока исхода (без рекурсии в check/random/post_combat) — сумма
# наградных полей по фиксированным весам. Штрафы (отрицательные stats, downside-моды) в апсайд
# НЕ идут. Мульт-vs-флэт моды разделяются по суффиксу `_multiplier` (как ui_screens применяет
# reward): мультипликатор m>1 ценится как (m-1)*100*MOD_W, флэт — как значение*MOD_FLAT_W.
func _outcome_value(outcome: Dictionary) -> float:
	var score := 0.0
	if outcome.has("money"):
		score += maxf(0.0, float(outcome["money"])) * MONEY_W
	if outcome.has("stats") and outcome["stats"] is Dictionary:
		for v in (outcome["stats"] as Dictionary).values():
			score += maxf(0.0, float(v)) * STAT_W  # отрицательные статы = штраф провала, не награда
	if outcome.has("mods") and outcome["mods"] is Dictionary:
		for mod_id in (outcome["mods"] as Dictionary).keys():
			if DOWNSIDE_MOD_KEYS.has(str(mod_id)):
				continue  # штрафной мультипликатор (враги живучее) — не награда
			var mv := float(outcome["mods"][mod_id])
			if str(mod_id).ends_with("_multiplier"):
				if mv > 1.0:
					score += (mv - 1.0) * 100.0 * MOD_W
			else:
				score += mv * MOD_FLAT_W
	if outcome.has("heal_percent"):
		score += float(outcome["heal_percent"]) * HEAL_W
	if outcome.get("random_artifact", false) == true:
		score += ARTIFACT_W
	if outcome.has("combat") and outcome["combat"] is Dictionary:
		var combat: Dictionary = outcome["combat"]
		for reward_key in ["money_multiplier", "xp_multiplier"]:
			if combat.has(reward_key) and float(combat[reward_key]) > 1.0:
				score += (float(combat[reward_key]) - 1.0) * 100.0 * COMBAT_REWARD_W
	return score


# SCRUM-495: потенциальный апсайд опции — ЛУЧШИЙ достижимый исход (за риск платят, нас интересует
# «верх» награды, без вычета стоимости). Суммируем: базовый исход опции + post_combat (награда за
# победу в combat) + success-ветка check (лучший исход проверки) + лучший под-исход random_outcomes.
# Вероятности провала не моделируем (зависят от рантайм-статов героя, в данных их нет) — берём
# достижимый максимум, как формулирует тикет.
func _choice_upside(choice: Dictionary) -> float:
	var best := _outcome_value(choice)
	if choice.has("post_combat") and choice["post_combat"] is Dictionary:
		best += _outcome_value(choice["post_combat"])
	if choice.has("check") and choice.has("success") and choice["success"] is Dictionary:
		best += _outcome_value(choice["success"])
	if choice.has("random_outcomes") and choice["random_outcomes"] is Array:
		var sub_best := 0.0
		for sub_entry in (choice["random_outcomes"] as Array):
			if not (sub_entry is Dictionary):
				continue
			var sub: Dictionary = sub_entry
			var sub_score := _outcome_value(sub)
			if sub.has("post_combat") and sub["post_combat"] is Dictionary:
				sub_score += _outcome_value(sub["post_combat"])
			sub_best = maxf(sub_best, sub_score)
		best += sub_best
	return best


# SCRUM-495: инвариант на уровне события. Если в событии есть И рисковые, И безопасные опции —
# лучший апсайд рисковой не ниже лучшего апсайда безопасной (×SAFE_MARGIN). События без пары
# (все опции одной категории, напр. hot_spring/training_dummies) пропускаются. Возвращает true,
# если инвариант реально проверялся (была пара risky+safe).
func _check_event_ev(errors: Array, event: Dictionary) -> bool:
	var choices: Array = event.get("choices", [])
	var best_risky := -1.0
	var best_risky_id := ""
	var best_safe := -1.0
	var best_safe_id := ""
	for choice_entry in choices:
		if not (choice_entry is Dictionary):
			continue
		var choice: Dictionary = choice_entry
		var upside := _choice_upside(choice)
		if _choice_is_risky_or_paid(choice):
			if upside > best_risky:
				best_risky = upside
				best_risky_id = str(choice.get("id", ""))
		else:
			if upside > best_safe:
				best_safe = upside
				best_safe_id = str(choice.get("id", ""))
	if best_risky < 0.0 or best_safe < 0.0:
		return false  # нет пары risky+safe — нечего сравнивать
	if best_risky < best_safe * SAFE_MARGIN:
		errors.append(
			"событие '%s': рисковая/платная опция '%s' (апсайд %.1f) слабее безопасной '%s' (апсайд %.1f) — игрок теряет смысл рисковать" % [
				str(event.get("id", "")), best_risky_id, best_risky, best_safe_id, best_safe,
			]
		)
	return true


# SCRUM-495: негативный само-тест гейта. Синтетическое событие: рисковая опция (risk+combat) с
# заниженной наградой (money:1) против щедрой безопасной (stats+heal). EV-гейт ОБЯЗАН вернуть
# ошибку. Если не вернул — гейт сломан (ложно пропустил бы регресс) → падаем сразу. Реальные
# данные event_data.gd не трогаются: событие синтетическое, in-memory.
func _run_ev_gate_self_test() -> void:
	var rigged_event := {
		"id": "__ev_gate_self_test__",
		"choices": [
			{"id": "rigged_risky", "risk": true, "combat": {"type": "battle", "enemy_health_multiplier": 1.2}, "money": 1},
			{"id": "rigged_safe", "stats": {"strength": 2}, "heal_percent": 0.5},
		],
	}
	var probe_errors: Array = []
	var checked := _check_event_ev(probe_errors, rigged_event)
	if not checked:
		push_error("Event data smoke: EV self-test — гейт не распознал пару risky+safe (классификатор сломан).")
		quit(1)
		return
	if probe_errors.is_empty():
		push_error("Event data smoke: EV self-test — гейт НЕ поймал заниженную награду рисковой опции (регресс прошёл бы молча).")
		quit(1)
		return
	# Контр-проверка: рисковая опция щедрее безопасной → ложного срабатывания быть НЕ должно.
	var fair_event := {
		"id": "__ev_gate_self_test_fair__",
		"choices": [
			{"id": "fair_risky", "risk": true, "combat": {"type": "battle", "money_multiplier": 1.5}, "random_artifact": true},
			{"id": "fair_safe", "money": 5},
		],
	}
	var fair_errors: Array = []
	_check_event_ev(fair_errors, fair_event)
	if not fair_errors.is_empty():
		push_error("Event data smoke: EV self-test — ложное срабатывание на щедрой рисковой опции: %s" % str(fair_errors))
		quit(1)
		return


func _check_accessors(errors: Array) -> void:
	var ids := EventData.event_ids()
	if ids.size() != EventData.RANDOM_EVENTS.size():
		errors.append("event_ids() (%d) != RANDOM_EVENTS (%d)" % [ids.size(), EventData.RANDOM_EVENTS.size()])
	if ids.is_empty():
		errors.append("event_ids() пуст")
		return
	# event_by_id известного -> непустой и с тем же id; неизвестного -> {}.
	var first_id := str(ids[0])
	var fetched := EventData.event_by_id(first_id)
	if fetched.is_empty() or str(fetched.get("id", "")) != first_id:
		errors.append("event_by_id('%s') не вернул событие" % first_id)
	if not EventData.event_by_id("__nonexistent_event__").is_empty():
		errors.append("event_by_id неизвестного id вернул не-{}")

	# pick_event: с сидированным rng -> валидное событие не из used_ids.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# исключаем все кроме одного — pick_event обязан вернуть именно его.
	var used := ids.duplicate()
	used.erase(first_id)
	var picked := EventData.pick_event(used, rng)
	if str(picked.get("id", "")) != first_id:
		errors.append("pick_event при исключении всех кроме '%s' вернул '%s'" % [first_id, picked.get("id", "")])
	# pick_event с пустым used -> валидное событие из набора.
	var picked2 := EventData.pick_event([], rng)
	if not EventData.event_ids().has(str(picked2.get("id", ""))):
		errors.append("pick_event([]) вернул событие вне набора ('%s')" % picked2.get("id", ""))
