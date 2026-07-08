extends SceneTree

# SCRUM-501: лёгкая headless-проверка контракта данных событий БЕЗ загрузки сцен/текстур
# (чтобы не зависеть от тяжёлого full-scene smoke под параллельной Godot-нагрузкой).
# Зеркалит ключевые ассерты _test_random_event_data_and_outcomes для пула event_data.gd.

const EventData := preload("res://scripts/event_data.gd")

# Валидные mod-id из player.gd:run_modifiers (несуществующий = мёртвое поле).
const VALID_MODS := [
	"damage_multiplier", "magic_damage_multiplier", "sound_damage_multiplier",
	"attack_speed_multiplier", "range_multiplier", "aoe_radius_multiplier", "sector_multiplier",
	"move_speed_multiplier", "max_health_multiplier", "summon_bonus", "damage_flat",
	"max_health_flat", "pickup_radius_flat", "defense_flat", "crit_chance_flat",
	"crit_damage_flat", "dodge_flat", "xp_gain_multiplier", "money_gain_multiplier",
	"healing_multiplier", "vampiric_heal_per_second_cap", "drain_heal_per_second_cap",
	"enemy_health_multiplier", "knockback_multiplier",
]
const VALID_STATS := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]

# SCRUM-995: post_combat применяется рантаймом через Player.apply_reward +
# отдельный shop-хук (combat_director._grant_combat_completion_rewards /
# _combat_victory_map_continuation) — money/random_artifact там МОЛЧА
# игнорируются. Гард против мёртвых наградных ключей в новом паке.
const POST_COMBAT_ALLOWED_KEYS := ["stats", "mods", "heal_percent", "shop_after", "shop_discount"]

var _failed := false


func _fail(msg: String) -> void:
	push_error("[event_data_contract] FAIL: " + msg)
	_failed = true


func _check_mods(branch: Dictionary, ctx: String) -> void:
	var mods: Dictionary = branch.get("mods", {})
	for mod_id in mods.keys():
		if not VALID_MODS.has(str(mod_id)):
			_fail("dead mod-id '%s' in %s" % [mod_id, ctx])
	var stats: Dictionary = branch.get("stats", {})
	for stat_id in stats.keys():
		if not VALID_STATS.has(str(stat_id)):
			_fail("unknown stat-id '%s' in %s" % [stat_id, ctx])


# SCRUM-996: типы новых опциональных ключей уровня исхода (choice-корень /
# success / failure / элемент random_outcomes / post_combat).
func _check_outcome_extras(branch: Dictionary, ctx: String) -> void:
	if branch.has("outcome_text") and (not (branch["outcome_text"] is String) or str(branch["outcome_text"]).strip_edges() == ""):
		_fail("outcome_text must be a non-empty String in %s" % ctx)
	if branch.has("damage_flat"):
		var dmg = branch["damage_flat"]
		if not ((dmg is int) or (dmg is float)) or float(dmg) <= 0.0:
			_fail("damage_flat must be a positive number in %s" % ctx)
	if branch.has("shop_after") and not (branch["shop_after"] is bool):
		_fail("shop_after must be bool in %s" % ctx)
	if branch.has("shop_discount"):
		var discount = branch["shop_discount"]
		if not ((discount is int) or (discount is float)) or float(discount) <= 0.0 or float(discount) > 0.9:
			_fail("shop_discount must be in (0, 0.9] in %s" % ctx)


func _scan_outcome(branch: Dictionary, ctx: String) -> void:
	_check_mods(branch, ctx)
	_check_outcome_extras(branch, ctx)
	for sub_key in ["success", "failure", "post_combat"]:
		if branch.has(sub_key):
			_check_mods(branch.get(sub_key, {}), "%s.%s" % [ctx, sub_key])
			_check_outcome_extras(branch.get(sub_key, {}), "%s.%s" % [ctx, sub_key])
			if sub_key == "post_combat":
				for post_key in (branch.get(sub_key, {}) as Dictionary).keys():
					if not POST_COMBAT_ALLOWED_KEYS.has(str(post_key)):
						_fail("post_combat key '%s' is dead at runtime (apply_reward ignores it) in %s" % [post_key, ctx])
	for outcome in (branch.get("random_outcomes", []) as Array):
		_scan_outcome(outcome, "%s.random_outcomes" % ctx)


# SCRUM-996: hidden-выбор обязан честно раскрываться ПОСЛЕ выбора — каждый его
# терминальный исход несёт outcome_text (корень выбора или каждая ветка/вариант).
func _hidden_choice_reveals_honestly(choice: Dictionary) -> bool:
	var root_text := str(choice.get("outcome_text", "")).strip_edges()
	if root_text != "":
		return true
	var terminal_branches: Array = []
	if choice.has("check"):
		terminal_branches.append(choice.get("success", {}))
		terminal_branches.append(choice.get("failure", {}))
	elif choice.has("random_outcomes"):
		for outcome in (choice.get("random_outcomes", []) as Array):
			terminal_branches.append(outcome)
	else:
		return false  # без outcome_text в корне и без веток раскрывать нечем
	for branch in terminal_branches:
		# Ветка-бой раскрывается самим боем; остальным нужен текст.
		if (branch as Dictionary).has("combat"):
			continue
		if str((branch as Dictionary).get("outcome_text", "")).strip_edges() == "":
			return false
	return true


func _initialize() -> void:
	var events: Array = EventData.RANDOM_EVENTS
	if events.size() != 12:  # SCRUM-995: полированный стартовый пак — ровно 12 закреплённых событий (легаси-пул из 29 удалён)
		_fail("expected pool size 12, got %d" % events.size())

	var ids := {}
	var combat_outcomes := 0
	var reward_outcomes := 0
	var rest_outcomes := 0
	var check_outcomes := 0
	var class_reactive := 0
	var hidden_events := 0

	for event in events:
		var event_id := str(event.get("id", ""))
		if event_id == "" or ids.has(event_id):
			_fail("non-unique or empty id '%s'" % event_id)
		ids[event_id] = true
		if str(event.get("title", "")) == "" or str(event.get("story", "")).length() < 40:
			_fail("event %s missing title or story>=40" % event_id)
		# SCRUM-996: event-level tags {acts: Array[int 1..3], biomes: Array[String]}.
		# SCRUM-995: структура tags ОБЯЗАТЕЛЬНА у каждого события пака (пустые
		# массивы = любой акт; наполнение придёт с актами).
		if not event.has("tags"):
			_fail("event %s missing mandatory tags structure (SCRUM-995)" % event_id)
		if event.has("tags"):
			var tags_value = event["tags"]
			if not (tags_value is Dictionary):
				_fail("tags must be a Dictionary in %s" % event_id)
			else:
				var acts_value = (tags_value as Dictionary).get("acts", [])
				if not (acts_value is Array):
					_fail("tags.acts must be an Array in %s" % event_id)
				else:
					for act in (acts_value as Array):
						if not (act is int) or int(act) < 1 or int(act) > 3:
							_fail("tags.acts entries must be int 1..3 in %s, got %s" % [event_id, str(act)])
				var biomes_value = (tags_value as Dictionary).get("biomes", [])
				if not (biomes_value is Array):
					_fail("tags.biomes must be an Array in %s" % event_id)
				else:
					for biome in (biomes_value as Array):
						if not (biome is String) or str(biome).strip_edges() == "":
							_fail("tags.biomes entries must be non-empty String in %s" % event_id)
		var choices: Array = event.get("choices", [])
		# SCRUM-995 AC: ровно 3 выбора с различимым интентом у каждого события пака.
		if choices.size() != 3:
			_fail("event %s must have exactly 3 choices (SCRUM-995), got %d" % [event_id, choices.size()])
		var check_stats := {}
		var has_hidden_choice := false
		for choice in choices:
			var ctx := "%s/%s" % [event_id, str(choice.get("id", ""))]
			_scan_outcome(choice, ctx)
			# SCRUM-996: hidden/unknown_hint — типы и честность раскрытия.
			if choice.has("hidden") and not (choice["hidden"] is bool):
				_fail("hidden must be bool in %s" % ctx)
			if choice.has("unknown_hint") and (not (choice["unknown_hint"] is String) or str(choice["unknown_hint"]).strip_edges() == ""):
				_fail("unknown_hint must be a non-empty String in %s" % ctx)
			if bool(choice.get("hidden", false)):
				has_hidden_choice = true
				if not _hidden_choice_reveals_honestly(choice):
					_fail("hidden choice must carry outcome_text on every non-combat terminal outcome in %s" % ctx)
			if choice.has("combat") or _nested_has(choice, "combat"):
				combat_outcomes += 1
			if choice.has("random_artifact") or choice.has("reward") or choice.has("money") or _nested_has(choice, "random_artifact"):
				reward_outcomes += 1
			if choice.has("heal_percent"):
				rest_outcomes += 1
			if choice.has("check"):
				check_outcomes += 1
				var diff := int((choice.get("check", {}) as Dictionary).get("difficulty", 0))
				if diff < 1 or diff > 12:
					_fail("check difficulty out of [1,12] in %s: %d" % [ctx, diff])
				check_stats[str((choice.get("check", {}) as Dictionary).get("stat", ""))] = true
			# risk-text contract
			if bool(choice.get("risk", false)):
				var d := str(choice.get("description", "")).strip_edges().to_lower()
				if d.begins_with("риск: риск:"):
					_fail("duplicate 'Риск:' prefix in %s" % ctx)
		if check_stats.size() >= 2:
			class_reactive += 1
		if has_hidden_choice:
			hidden_events += 1

	if combat_outcomes < 3 or reward_outcomes < 3 or rest_outcomes < 1 or check_outcomes < 2:
		_fail("outcome coverage low: combat=%d reward=%d rest=%d check=%d" % [combat_outcomes, reward_outcomes, rest_outcomes, check_outcomes])
	if class_reactive < 2:
		_fail("class-reactive events <2: %d" % class_reactive)
	# SCRUM-995 AC: скрытые исходы минимум в 3 событиях пака (cursed_chapel /
	# gilded_gambler / old_well), честность раскрытия проверена выше.
	if hidden_events < 3:
		_fail("events with hidden choices <3: %d" % hidden_events)

	# non-repeat picker over full pool
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var used := []
	for _i in range(events.size()):
		var picked: Dictionary = EventData.pick_event(used, rng)
		var pid := str(picked.get("id", ""))
		if used.has(pid):
			_fail("picker repeated id '%s' within pool" % pid)
		used.append(pid)

	if _failed:
		print("[event_data_contract] FAILED")
		quit(1)
	else:
		print("[event_data_contract] PASSED — pool=%d combat=%d reward=%d rest=%d check=%d class_reactive=%d hidden_events=%d" % [events.size(), combat_outcomes, reward_outcomes, rest_outcomes, check_outcomes, class_reactive, hidden_events])
		quit(0)


func _nested_has(choice: Dictionary, key: String) -> bool:
	for outcome in (choice.get("random_outcomes", []) as Array):
		if outcome.has(key):
			return true
	for sub_key in ["success", "failure"]:
		if (choice.get(sub_key, {}) as Dictionary).has(key):
			return true
	return false
