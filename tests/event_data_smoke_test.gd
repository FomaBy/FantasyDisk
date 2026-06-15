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


func _initialize() -> void:
	var errors: Array = []
	var valid_stats := {}
	for stat_id in StatFormulas.BASE_STAT_ORDER:
		valid_stats[str(stat_id)] = true

	_check_events(errors, valid_stats)
	_check_accessors(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Event data smoke: %s" % e)
		push_error("Event data smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Event data smoke test passed (%d событий)." % EventData.RANDOM_EVENTS.size())
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


func _check_events(errors: Array, valid_stats: Dictionary) -> void:
	var events := EventData.RANDOM_EVENTS
	if events.size() < 5:
		errors.append("RANDOM_EVENTS подозрительно мал (%d) — гейт прошёл бы вакуумно" % events.size())
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
