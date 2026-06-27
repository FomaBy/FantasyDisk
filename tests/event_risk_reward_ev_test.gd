extends SceneTree

# SCRUM-508: инвариант риск-награды random-событий.
#
# Для каждого события из RANDOM_EVENTS, у которого есть И рисковая ветка (бой /
# risk:true / штрафной мод enemy_health), И безопасная ветка, ожидаемая ценность
# (EV) рисковой ветки в золото-эквиваленте должна быть >= EV безопасной ветки.
# Риск (тяжесть боя, штраф к HP врагов) ИНТЕРНАЛИЗОВАН как вычет внутри EV рисковой
# ветки — то есть «>= безопасной» уже означает, что риск окупается (премия за риск
# пропорциональна добавочной сложности боя).
#
# Модель — золото-эквивалент (зеркалит tools/scratchpad ev_model.py из проектирования):
#   money/cost_money   : +/- номинал
#   heal_percent       : min(heal, HEAL_CAP) * HEAL_FULL_GOLD (полный хил частично
#                        пропадает — в среднем к событию приходишь не на 0% HP)
#   health_percent_cost: - frac * HEAL_FULL_GOLD
#   stats              : +/- STAT_GOLD за очко
#   random_artifact    : + ARTIFACT_GOLD
#   mods (%-мультипл.) : (v-1)*100 * MOD_PCT_GOLD; summon_bonus/defense_flat — отдельно;
#                        enemy_health_multiplier как штрафной мод — вычет риска
#   combat             : base money*mult + base xp*mult - (risk_base[type] + (ehm-1)*RISK_DAMAGE_GOLD)
#   random_outcomes    : среднее по исходам (равновероятны)
#   check              : P_SUCCESS*success + (1-P_SUCCESS)*failure

const EventData := preload("res://scripts/event_data.gd")

const HEAL_FULL_GOLD := 30.0
const HEAL_CAP := 0.5
const STAT_GOLD := 14.0
const ARTIFACT_GOLD := 28.0
const MOD_PCT_GOLD := 1.5
const SUMMON_BONUS_GOLD := 14.0
const DEFENSE_FLAT_GOLD := 150.0
const COMBAT_BASE_MONEY := 20.0
const COMBAT_BASE_XP_GOLD := 10.0
const RISK_DAMAGE_GOLD := 40.0
const RISK_BASE := {"battle": 6.0, "elite": 12.0}
const P_SUCCESS := 0.6
const EPSILON := 0.01

const PCT_MODS := [
	"attack_speed_multiplier", "damage_multiplier", "xp_gain_multiplier",
	"healing_multiplier", "max_health_multiplier",
]


func _initialize() -> void:
	# Негативный само-тест ДО основной проверки: доказываем, что гейт реально ловит
	# занижение награды рисковой ветки (синтетическое in-memory событие, данные не трогаем).
	_run_self_test()

	var errors: Array = []
	var checked := 0
	print("SCRUM-508 EV(risk) >= EV(safe) — таблица риск/безопасной веток:")
	for event in EventData.RANDOM_EVENTS:
		var choices: Array = event.get("choices", [])
		var risk_branches: Array = []
		var safe_branches: Array = []
		for choice in choices:
			if _is_risk(choice):
				risk_branches.append(choice)
			else:
				safe_branches.append(choice)
		if risk_branches.is_empty() or safe_branches.is_empty():
			continue
		checked += 1
		var best_risk: Dictionary = _best(risk_branches)
		var best_safe: Dictionary = _best(safe_branches)
		var er := _branch_ev(best_risk)
		var es := _branch_ev(best_safe)
		var flag := ""
		if er < es - EPSILON:
			flag = "  <-- VIOLATION"
			errors.append("%s: EV(risk %s)=%.2f < EV(safe %s)=%.2f" % [
				event.get("id", "?"), best_risk.get("id", "?"), er, best_safe.get("id", "?"), es])
		print("  %-22s risk[%-14s]=%7.2f  safe[%-14s]=%7.2f  diff=%+7.2f%s" % [
			event.get("id", "?"), best_risk.get("id", "?"), er, best_safe.get("id", "?"), es, er - es, flag])

	if checked == 0:
		push_error("Event risk-reward EV test: не найдено ни одного события с парой риск/безопасная ветка.")
		quit(1)
		return
	if not errors.is_empty():
		for e in errors:
			push_error("Event risk-reward EV: %s" % e)
		push_error("Event risk-reward EV test failed: %d нарушений из %d проверенных событий." % [errors.size(), checked])
		quit(1)
		return
	print("Event risk-reward EV test passed (%d событий с парой риск/безопасная, 0 нарушений)." % checked)
	quit(0)


# Доказывает, что инвариант ловит регресс: рисковая ветка с заниженной наградой ОБЯЗАНА
# дать er < es, а щедрая — нет. Если логика сломана — падаем сразу.
func _run_self_test() -> void:
	var rigged_risk := {"id": "rigged_risk", "risk": true, "combat": {"type": "elite", "enemy_health_multiplier": 1.3}, "money": 1}
	var rigged_safe := {"id": "rigged_safe", "stats": {"strength": 2}, "heal_percent": 0.5}
	if not _is_risk(rigged_risk) or _is_risk(rigged_safe):
		push_error("EV self-test: классификатор риск/безопасная сломан.")
		quit(1)
		return
	if _branch_ev(rigged_risk) >= _branch_ev(rigged_safe):
		push_error("EV self-test: заниженная рисковая ветка НЕ распознана как нарушение (гейт сломан).")
		quit(1)
		return
	var fair_risk := {"id": "fair_risk", "risk": true, "combat": {"type": "battle", "money_multiplier": 1.5}, "random_artifact": true}
	var fair_safe := {"id": "fair_safe", "money": 5}
	if _branch_ev(fair_risk) < _branch_ev(fair_safe):
		push_error("EV self-test: ложное срабатывание на щедрой рисковой ветке.")
		quit(1)
		return


func _best(branches: Array) -> Dictionary:
	var best: Dictionary = branches[0]
	var best_ev := _branch_ev(best)
	for b in branches:
		var ev := _branch_ev(b)
		if ev > best_ev:
			best_ev = ev
			best = b
	return best


func _is_risk(choice: Dictionary) -> bool:
	if bool(choice.get("risk", false)):
		return true
	if choice.get("combat") is Dictionary:
		return true
	for o in choice.get("random_outcomes", []):
		if (o as Dictionary).get("combat") is Dictionary:
			return true
	var mods: Dictionary = choice.get("mods", {})
	if float(mods.get("enemy_health_multiplier", 1.0)) > 1.0:
		return true
	return false


func _mods_gold(mods: Dictionary) -> float:
	var g := 0.0
	for k in mods:
		var v := float(mods[k])
		if PCT_MODS.has(k):
			g += (v - 1.0) * 100.0 * MOD_PCT_GOLD
		elif k == "summon_bonus":
			g += v * SUMMON_BONUS_GOLD
		elif k == "defense_flat":
			g += v * DEFENSE_FLAT_GOLD
		elif k == "enemy_health_multiplier":
			g -= (v - 1.0) * RISK_DAMAGE_GOLD
	return g


func _stats_gold(stats: Dictionary) -> float:
	var g := 0.0
	for k in stats:
		g += float(stats[k]) * STAT_GOLD
	return g


func _combat_gold(c: Dictionary) -> float:
	var ctype := str(c.get("type", "battle"))
	var money := COMBAT_BASE_MONEY * float(c.get("money_multiplier", 1.0))
	var xp := COMBAT_BASE_XP_GOLD * float(c.get("xp_multiplier", 1.0))
	var risk: float = float(RISK_BASE.get(ctype, 6.0)) + (float(c.get("enemy_health_multiplier", 1.0)) - 1.0) * RISK_DAMAGE_GOLD
	return money + xp - risk


func _outcome_gold(o: Dictionary) -> float:
	var g := 0.0
	g += float(o.get("money", 0.0))
	g -= float(o.get("cost_money", 0.0))
	g += minf(float(o.get("heal_percent", 0.0)), HEAL_CAP) * HEAL_FULL_GOLD
	g -= float(o.get("health_percent_cost", 0.0)) * HEAL_FULL_GOLD
	g += _stats_gold(o.get("stats", {}))
	g += _mods_gold(o.get("mods", {}))
	if bool(o.get("random_artifact", false)):
		g += ARTIFACT_GOLD
	if o.get("combat") is Dictionary:
		g += _combat_gold(o.get("combat"))
		var post: Dictionary = o.get("post_combat", {})
		g += _stats_gold(post.get("stats", {}))
		g += _mods_gold(post.get("mods", {}))
	return g


func _branch_ev(choice: Dictionary) -> float:
	var g := 0.0
	g -= float(choice.get("cost_money", 0.0))
	g += float(choice.get("money", 0.0))
	g += minf(float(choice.get("heal_percent", 0.0)), HEAL_CAP) * HEAL_FULL_GOLD
	g -= float(choice.get("health_percent_cost", 0.0)) * HEAL_FULL_GOLD
	g += _stats_gold(choice.get("stats", {}))
	g += _mods_gold(choice.get("mods", {}))
	if bool(choice.get("random_artifact", false)):
		g += ARTIFACT_GOLD
	if choice.get("combat") is Dictionary:
		g += _combat_gold(choice.get("combat"))
		var post: Dictionary = choice.get("post_combat", {})
		g += _stats_gold(post.get("stats", {}))
		g += _mods_gold(post.get("mods", {}))
	var ros: Array = choice.get("random_outcomes", [])
	if not ros.is_empty():
		var sum_ev := 0.0
		for o in ros:
			sum_ev += _outcome_gold(o)
		g += sum_ev / float(ros.size())
	if choice.get("check") is Dictionary:
		g += P_SUCCESS * _outcome_gold(choice.get("success", {})) + (1.0 - P_SUCCESS) * _outcome_gold(choice.get("failure", {}))
	return g
