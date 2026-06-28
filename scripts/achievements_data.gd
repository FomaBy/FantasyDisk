extends RefCounted

# Персистентные ачивки забега (SCRUM-617). Удержание: meta_points раньше капали
# ТОЛЬКО за новое возвышение; ачивки дают цели вне грайнда и поощряют разный
# отыгрыш (быстрые забеги, дальнее продвижение, фарм золота, флоулесс-стиль).
#
# Каждая ачивка — порог по ОДНОЙ метрике забега (run_metrics, см.
# main.reset_run_metrics): достигнут на завершении забега (победа ИЛИ смерть) →
# разблокировка + разовая награда meta_points. Разблокировка персистентна
# (meta_state.achievements — массив id), повторное достижение НЕ начисляет очки
# второй раз. Описания — по-русски, человеческим языком, без внутренних ID.
#
# Метрики (>= threshold):
#   kills               — всего убийств за забег
#   boss_kills          — повержено боссов за забег
#   damage_dealt        — суммарно нанесено урона
#   gold_collected      — собрано золота (накопитель, не остаток кошелька)
#   route_stage_reached — самый дальний достигнутый ряд маршрута
#   final_level         — достигнутый уровень персонажа
#   time_seconds        — длительность забега (для «дожить до …»)
const ACHIEVEMENTS := [
	{"id": "first_blood", "title": "Первая кровь", "desc": "Соверши 50 убийств за один забег.",
	 "metric": "kills", "threshold": 50, "reward_meta_points": 1},
	{"id": "slayer", "title": "Истребитель", "desc": "Соверши 300 убийств за один забег.",
	 "metric": "kills", "threshold": 300, "reward_meta_points": 2},
	{"id": "boss_breaker", "title": "Сокрушитель боссов", "desc": "Повергни 3 боссов за один забег.",
	 "metric": "boss_kills", "threshold": 3, "reward_meta_points": 2},
	{"id": "heavy_hitter", "title": "Тяжёлая рука", "desc": "Нанеси 50 000 урона за один забег.",
	 "metric": "damage_dealt", "threshold": 50000, "reward_meta_points": 2},
	{"id": "treasure_hunter", "title": "Кладоискатель", "desc": "Собери 1 000 золота за один забег.",
	 "metric": "gold_collected", "threshold": 1000, "reward_meta_points": 1},
	{"id": "pathfinder", "title": "Первопроходец", "desc": "Дойди до 12-го ряда маршрута.",
	 "metric": "route_stage_reached", "threshold": 12, "reward_meta_points": 2},
	{"id": "veteran", "title": "Ветеран", "desc": "Достигни 20-го уровня персонажа за забег.",
	 "metric": "final_level", "threshold": 20, "reward_meta_points": 2},
	{"id": "marathoner", "title": "Марафонец", "desc": "Продержись в забеге 10 минут.",
	 "metric": "time_seconds", "threshold": 600, "reward_meta_points": 1},
]


# Все определения ачивок (для UI/тестов).
static func all_achievements() -> Array:
	return ACHIEVEMENTS


static func achievement_by_id(achievement_id: String) -> Dictionary:
	for achievement in ACHIEVEMENTS:
		if str(achievement["id"]) == achievement_id:
			return achievement
	return {}


# Сумма всех наградных очков (для теста-баланса/UI «сколько всего можно получить»).
static func total_reward_points() -> int:
	var total := 0
	for achievement in ACHIEVEMENTS:
		total += int(achievement["reward_meta_points"])
	return total


# Разблокированные id из состояния (нормализованный массив, только валидные id).
static func unlocked_ids(state: Dictionary) -> Array:
	var raw = state.get("achievements", [])
	if not (raw is Array):
		return []
	var out := []
	for achievement_id in raw:
		var sid := str(achievement_id)
		if achievement_by_id(sid).size() > 0 and not out.has(sid):
			out.append(sid)
	return out


static func is_unlocked(state: Dictionary, achievement_id: String) -> bool:
	return unlocked_ids(state).has(achievement_id)


static func unlocked_count(state: Dictionary) -> int:
	return unlocked_ids(state).size()


# Оценивает метрики завершённого забега и разблокирует достигнутые ачивки.
# Мутирует state (как record_boss_victory): дописывает id в achievements и
# начисляет meta_points за КАЖДУЮ впервые открытую ачивку. Идемпотентна — уже
# открытые ачивки не начисляются повторно (даже если порог снова пройден).
# Возвращает сводку {newly_unlocked: Array[String], awarded: int}.
static func evaluate_run(state: Dictionary, run_metrics: Dictionary) -> Dictionary:
	var unlocked := unlocked_ids(state)
	var newly_unlocked: Array = []
	var awarded := 0
	for achievement in ACHIEVEMENTS:
		var sid := str(achievement["id"])
		if unlocked.has(sid):
			continue
		var metric := str(achievement["metric"])
		var value := float(run_metrics.get(metric, 0))
		if value >= float(achievement["threshold"]):
			unlocked.append(sid)
			newly_unlocked.append(sid)
			awarded += int(achievement["reward_meta_points"])
	if not newly_unlocked.is_empty():
		state["achievements"] = unlocked
		state["meta_points"] = int(state.get("meta_points", 0)) + awarded
	return {"newly_unlocked": newly_unlocked, "awarded": awarded}
