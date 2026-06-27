extends SceneTree

# SCRUM-501: лёгкая headless-проверка контракта данных событий БЕЗ загрузки сцен/текстур
# (чтобы не зависеть от тяжёлого full-scene smoke под параллельной Godot-нагрузкой).
# Зеркалит ключевые ассерты _test_random_event_data_and_outcomes для пула event_data.gd.

const EventData := preload("res://scripts/event_data.gd")

# Валидные mod-id из player.gd:run_modifiers (несуществующий = мёртвое поле).
const VALID_MODS := [
	"damage_multiplier", "attack_speed_multiplier", "range_multiplier", "aoe_radius_multiplier",
	"move_speed_multiplier", "max_health_multiplier", "summon_bonus", "damage_flat",
	"max_health_flat", "pickup_radius_flat", "defense_flat", "crit_chance_flat",
	"crit_damage_flat", "dodge_flat", "xp_gain_multiplier", "money_gain_multiplier",
	"healing_multiplier", "vampiric_heal_per_second_cap", "drain_heal_per_second_cap",
	"enemy_health_multiplier", "knockback_multiplier",
]
const VALID_STATS := ["strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]

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


func _scan_outcome(branch: Dictionary, ctx: String) -> void:
	_check_mods(branch, ctx)
	for sub_key in ["success", "failure", "post_combat"]:
		if branch.has(sub_key):
			_check_mods(branch.get(sub_key, {}), "%s.%s" % [ctx, sub_key])
	for outcome in (branch.get("random_outcomes", []) as Array):
		_scan_outcome(outcome, "%s.random_outcomes" % ctx)


func _initialize() -> void:
	var events: Array = EventData.RANDOM_EVENTS
	if events.size() != 17:
		_fail("expected pool size 17, got %d" % events.size())

	var ids := {}
	var combat_outcomes := 0
	var reward_outcomes := 0
	var rest_outcomes := 0
	var check_outcomes := 0
	var class_reactive := 0

	for event in events:
		var event_id := str(event.get("id", ""))
		if event_id == "" or ids.has(event_id):
			_fail("non-unique or empty id '%s'" % event_id)
		ids[event_id] = true
		if str(event.get("title", "")) == "" or str(event.get("story", "")).length() < 40:
			_fail("event %s missing title or story>=40" % event_id)
		var choices: Array = event.get("choices", [])
		if choices.size() < 2:
			_fail("event %s has <2 choices" % event_id)
		var check_stats := {}
		for choice in choices:
			var ctx := "%s/%s" % [event_id, str(choice.get("id", ""))]
			_scan_outcome(choice, ctx)
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

	if combat_outcomes < 3 or reward_outcomes < 3 or rest_outcomes < 1 or check_outcomes < 2:
		_fail("outcome coverage low: combat=%d reward=%d rest=%d check=%d" % [combat_outcomes, reward_outcomes, rest_outcomes, check_outcomes])
	if class_reactive < 2:
		_fail("class-reactive events <2: %d" % class_reactive)

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
		print("[event_data_contract] PASSED — pool=17 combat=%d reward=%d rest=%d check=%d class_reactive=%d" % [combat_outcomes, reward_outcomes, rest_outcomes, check_outcomes, class_reactive])
		quit(0)


func _nested_has(choice: Dictionary, key: String) -> bool:
	for outcome in (choice.get("random_outcomes", []) as Array):
		if outcome.has(key):
			return true
	for sub_key in ["success", "failure"]:
		if (choice.get(sub_key, {}) as Dictionary).has(key):
			return true
	return false
