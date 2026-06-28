extends RefCounted

# Персистентная метапрогрессия: meta points и уровни возвышения (1-5)
# на персонажа. Сохранение через ConfigFile в user://.

const DEFAULT_SAVE_PATH := "user://fantasydisk_meta.cfg"
# SCRUM-516: лестница возвышений сжата 10→5 (короче и острее). Единый кап и для
# дорожки сложности (ASCENSION_MODIFIERS), и для наградной лестницы
# (ASCENSION_LEVELS). Старые сейвы с ascension>5 молча клампятся в [0..5] через
# load_state/ascension_level/selectable_max — без краша.
const MAX_ASCENSION_LEVEL := 5
const SECTION := "meta"

# Общее древо умений (SCRUM-150), 4 независимые ветви; внутри ветви узлы
# открываются последовательно (tier N+1 требует все узлы tier N этой ветви).
# Бюджет полной прокачки — сумма cost (валидируется тестом, 40-50). Эффекты —
# плоский dict модификаторов, применяемый на старте забега (инкремент 2).
# Описания — по-русски, человеческим языком (урок SCRUM-148), без внутренних ID.
const SKILL_TREE := [
	# --- Путь Богатства (экономика) ---
	{"id": "wealth_gold_1", "branch": "wealth", "tier": 1, "cost": 1, "title": "Звон монет I", "desc": "Враги роняют на 6% больше золота.", "effects": {"money_gain_mult": 0.06}},
	{"id": "wealth_gold_2", "branch": "wealth", "tier": 2, "cost": 1, "title": "Звон монет II", "desc": "Ещё +6% золота с боёв.", "effects": {"money_gain_mult": 0.06}},
	{"id": "wealth_gold_3", "branch": "wealth", "tier": 3, "cost": 1, "title": "Звон монет III", "desc": "Ещё +6% золота с боёв.", "effects": {"money_gain_mult": 0.06}},
	{"id": "wealth_shop_1", "branch": "wealth", "tier": 4, "cost": 1, "title": "Торг I", "desc": "Цены в лавке ниже на 4%.", "effects": {"shop_price_mult": -0.04}},
	{"id": "wealth_shop_2", "branch": "wealth", "tier": 5, "cost": 1, "title": "Торг II", "desc": "Цены в лавке ниже ещё на 4%.", "effects": {"shop_price_mult": -0.04}},
	{"id": "wealth_start_1", "branch": "wealth", "tier": 6, "cost": 1, "title": "Кошель в дорогу I", "desc": "Забег начинается с +30 золота.", "effects": {"start_gold_flat": 30.0}},
	{"id": "wealth_start_2", "branch": "wealth", "tier": 7, "cost": 1, "title": "Кошель в дорогу II", "desc": "Забег начинается ещё с +30 золота.", "effects": {"start_gold_flat": 30.0}},
	{"id": "wealth_attr_1", "branch": "wealth", "tier": 8, "cost": 1, "title": "Скромный наставник I", "desc": "Докачка атрибутов за золото дешевле на 6%.", "effects": {"attr_cost_mult": -0.06}},
	{"id": "wealth_attr_2", "branch": "wealth", "tier": 9, "cost": 1, "title": "Скромный наставник II", "desc": "Докачка атрибутов дешевле ещё на 6%.", "effects": {"attr_cost_mult": -0.06}},
	{"id": "wealth_capstone", "branch": "wealth", "tier": 10, "cost": 2, "title": "Связи в гильдии", "desc": "В каждой лавке гарантированно есть редкий товар.", "effects": {"guaranteed_rare_shop": 1.0}},
	# --- Путь Знаний (опыт и выборы) ---
	{"id": "lore_xp_1", "branch": "lore", "tier": 1, "cost": 1, "title": "Прилежание I", "desc": "Опыт за бои +6%.", "effects": {"xp_gain_mult": 0.06}},
	{"id": "lore_xp_2", "branch": "lore", "tier": 2, "cost": 1, "title": "Прилежание II", "desc": "Опыт за бои ещё +6%.", "effects": {"xp_gain_mult": 0.06}},
	{"id": "lore_xp_3", "branch": "lore", "tier": 3, "cost": 1, "title": "Прилежание III", "desc": "Опыт за бои ещё +6%.", "effects": {"xp_gain_mult": 0.06}},
	{"id": "lore_reroll_1", "branch": "lore", "tier": 4, "cost": 1, "title": "Сомнение", "desc": "Раз за уровень можно пересобрать набор повышения.", "effects": {"levelup_rerolls": 1.0}},
	{"id": "lore_reroll_2", "branch": "lore", "tier": 5, "cost": 1, "title": "Второе сомнение", "desc": "Ещё один пересбор набора повышения за забег.", "effects": {"levelup_rerolls": 1.0}},
	{"id": "lore_attr_1", "branch": "lore", "tier": 6, "cost": 1, "title": "Широкий кругозор", "desc": "В окне докачки атрибутов на 1 вариант больше.", "effects": {"attr_extra_options": 1.0}},
	{"id": "lore_attr_2", "branch": "lore", "tier": 7, "cost": 1, "title": "Эрудиция", "desc": "Ещё +1 вариант в окне докачки атрибутов.", "effects": {"attr_extra_options": 1.0}},
	{"id": "lore_capstone", "branch": "lore", "tier": 8, "cost": 2, "title": "Озарение", "desc": "Первое повышение в забеге гарантированно даёт основную характеристику.", "effects": {"first_levelup_rare": 1.0}},
	# --- Путь Мощи (атака) ---
	{"id": "might_dmg_1", "branch": "might", "tier": 1, "cost": 1, "title": "Точёный край I", "desc": "Урон +2%.", "effects": {"damage_mult": 0.02}},
	{"id": "might_dmg_2", "branch": "might", "tier": 2, "cost": 1, "title": "Точёный край II", "desc": "Урон ещё +2%.", "effects": {"damage_mult": 0.02}},
	{"id": "might_dmg_3", "branch": "might", "tier": 3, "cost": 1, "title": "Точёный край III", "desc": "Урон ещё +2%.", "effects": {"damage_mult": 0.02}},
	{"id": "might_as_1", "branch": "might", "tier": 4, "cost": 1, "title": "Быстрая рука I", "desc": "Скорость атаки +2%.", "effects": {"attack_speed_mult": 0.02}},
	{"id": "might_as_2", "branch": "might", "tier": 5, "cost": 1, "title": "Быстрая рука II", "desc": "Скорость атаки ещё +2%.", "effects": {"attack_speed_mult": 0.02}},
	{"id": "might_ult_1", "branch": "might", "tier": 6, "cost": 1, "title": "Внутренний жар I", "desc": "Ультимейт заряжается на 6% быстрее.", "effects": {"ult_charge_mult": 0.06}},
	{"id": "might_ult_2", "branch": "might", "tier": 7, "cost": 1, "title": "Внутренний жар II", "desc": "Ультимейт заряжается ещё на 6% быстрее.", "effects": {"ult_charge_mult": 0.06}},
	{"id": "might_slayer_1", "branch": "might", "tier": 8, "cost": 1, "title": "Охотник на сильных I", "desc": "Урон по элиткам и боссам +4%.", "effects": {"elite_boss_damage_mult": 0.04}},
	{"id": "might_slayer_2", "branch": "might", "tier": 9, "cost": 1, "title": "Охотник на сильных II", "desc": "Урон по элиткам и боссам ещё +4%.", "effects": {"elite_boss_damage_mult": 0.04}},
	{"id": "might_capstone", "branch": "might", "tier": 10, "cost": 2, "title": "Боевой раж", "desc": "Ультимейт начинает забег заряженным наполовину.", "effects": {"ult_start_charge": 0.5}},
	# --- Путь Стойкости (выживание) ---
	{"id": "endure_hp_1", "branch": "endure", "tier": 1, "cost": 1, "title": "Крепкое тело I", "desc": "Максимум здоровья +2%.", "effects": {"max_health_mult": 0.02}},
	{"id": "endure_hp_2", "branch": "endure", "tier": 2, "cost": 1, "title": "Крепкое тело II", "desc": "Максимум здоровья ещё +2%.", "effects": {"max_health_mult": 0.02}},
	{"id": "endure_hp_3", "branch": "endure", "tier": 3, "cost": 1, "title": "Крепкое тело III", "desc": "Максимум здоровья ещё +2%.", "effects": {"max_health_mult": 0.02}},
	{"id": "endure_regen_1", "branch": "endure", "tier": 4, "cost": 1, "title": "Второе дыхание I", "desc": "Восстановление здоровья +0.4/с.", "effects": {"regeneration_flat": 0.4}},
	{"id": "endure_regen_2", "branch": "endure", "tier": 5, "cost": 1, "title": "Второе дыхание II", "desc": "Восстановление здоровья ещё +0.4/с.", "effects": {"regeneration_flat": 0.4}},
	{"id": "endure_armor_1", "branch": "endure", "tier": 6, "cost": 1, "title": "Закалка I", "desc": "Снижение урона +1.5%.", "effects": {"defense_flat": 0.015}},
	{"id": "endure_armor_2", "branch": "endure", "tier": 7, "cost": 1, "title": "Закалка II", "desc": "Снижение урона ещё +1.5%.", "effects": {"defense_flat": 0.015}},
	{"id": "endure_dodge_1", "branch": "endure", "tier": 8, "cost": 1, "title": "Лёгкость I", "desc": "Шанс уклонения +1%.", "effects": {"dodge_flat": 0.01}},
	{"id": "endure_dodge_2", "branch": "endure", "tier": 9, "cost": 1, "title": "Лёгкость II", "desc": "Шанс уклонения ещё +1%.", "effects": {"dodge_flat": 0.01}},
	{"id": "endure_capstone", "branch": "endure", "tier": 10, "cost": 2, "title": "Вторая жизнь", "desc": "Раз за забег смертельный удар оставляет 1 HP и даёт 2с неуязвимости.", "effects": {"death_save": 1.0}},
]

# Секретный бой конца Акта 3 (SCRUM-619): скрытая цель для мастеров. Чистая ЛОГИКА
# разблокировки и разовой награды — без нового арта (переиспользует апекс-босса из
# codex). Гейт: возвышение >= 3 И (босс повержен с малым полученным уроном ИЛИ в
# забеге есть артефакт-ключ). Награда meta_points начисляется РОВНО один раз
# (secret_boss_defeated в персистентном состоянии).
const SECRET_ENCOUNTER_MIN_ASCENSION := 3
# «low-damage-boss»: суммарно получено <= порога за забег (флоулесс-ишь прохождение).
const SECRET_ENCOUNTER_MAX_DAMAGE_TAKEN := 60.0
const SECRET_ENCOUNTER_ARTIFACT_KEY := "rift_key"
const SECRET_ENCOUNTER_REWARD_META_POINTS := 3
# Апекс-босс из codex (самый тяжёлый профиль + фаза ярости в последней четверти).
const SECRET_BOSS_ID := "ashen_colossus"

const SKILL_BRANCHES := ["wealth", "lore", "might", "endure"]
const SKILL_BRANCH_TITLES := {
	"wealth": "Путь Богатства",
	"lore": "Путь Знаний",
	"might": "Путь Мощи",
	"endure": "Путь Стойкости",
}

# Прогрессия ПО КЛАССАМ (SCRUM-360): стимул отыгрывать каждый класс. Прогресс
# копится за победы над боссами ЭТИМ классом (class_boss_wins per character).
# Пороги накопительные и ОБЩИЕ для всех классов; бонусы применяются run-модами
# ТОЛЬКО выбранному классу (ключи class_* — отдельно от аккаунтных skill_modifiers,
# не пересекаются с ветвями древа). Мелкие, согласованы с балансовым потолком.
const CLASS_PROGRESSION := [
	{"wins": 1, "title": "Знакомство с классом", "desc": "Урон этого класса +3%.", "effects": {"class_damage_mult": 0.03}},
	{"wins": 2, "title": "Уверенная рука", "desc": "Максимум здоровья этого класса +3%.", "effects": {"class_max_health_mult": 0.03}},
	{"wins": 4, "title": "Боевая привычка", "desc": "Урон этого класса ещё +4%.", "effects": {"class_damage_mult": 0.04}},
	{"wins": 6, "title": "Отточенный темп", "desc": "Скорость атаки этого класса +4%.", "effects": {"class_attack_speed_mult": 0.04}},
	{"wins": 9, "title": "Мастерство класса", "desc": "Урон этого класса ещё +5%; +3% HP.", "effects": {"class_damage_mult": 0.05, "class_max_health_mult": 0.03}},
]

# SCRUM-620: челленджи класса за РАЗНООБРАЗИЕ забега. Стимулируют менять оружие/
# тактику внутри класса (а не фармить один билд), расширяя CLASS_PROGRESSION без UI.
# Выполняется один раз на класс (дедуп в class_challenges_done), бонус — те же
# class_*-ключи, что и прогрессия (player.gd мапит их в *_multiplier). Суммарный
# вклад челленджей держим в пределах +5% на ключ (анти-пауэр-крип).
#   condition_metric — какое поле class_challenge_progress оценивать:
#     "weapon_diversity" — число РАЗНЫХ weapon_id побед >= threshold;
#     "best_ascension"   — лучшее возвышение победы >= threshold;
#     "no_shop_wins"     — число побед БЕЗ покупок в магазине >= threshold.
# Жёсткий потолок суммарного вклада челленджей на один class_*-ключ (анти-крип).
const CLASS_CHALLENGE_MAX_BONUS := 0.05
const CLASS_CHALLENGES := [
	{"id": "weapon_master", "title": "Мастер арсенала", "desc": "Победы 3 разными оружиями этого класса: +3% урона.", "condition_metric": "weapon_diversity", "threshold": 3, "effects": {"class_damage_mult": 0.03}},
	{"id": "peak_climber", "title": "Покоритель вершин", "desc": "Победа на возвышении 3+: +3% максимума HP.", "condition_metric": "best_ascension", "threshold": 3, "effects": {"class_max_health_mult": 0.03}},
	{"id": "lone_wolf", "title": "Без посредников", "desc": "Победа без покупок в магазине: +3% скорости атаки.", "condition_metric": "no_shop_wins", "threshold": 1, "effects": {"class_attack_speed_mult": 0.03}},
]


static func default_state() -> Dictionary:
	return {
		"meta_points": 0,
		"ascension_levels": {},
		"skill_points": 0,
		"skill_nodes": [],
		"class_boss_wins": {},
		# SCRUM-619: одноразовый флаг победы над секретным боссом конца Акта 3.
		"secret_boss_defeated": false,
		# SCRUM-617: id разблокированных персистентных ачивок забега.
		"achievements": [],
		# SCRUM-620: накопленные метрики челленджей класса {char:{weapons:[],
		# best_ascension:int, no_shop_wins:int}} и выполненные {char:[challenge_id]}.
		"class_challenge_progress": {},
		"class_challenges_done": {},
	}


static func load_state(save_path := DEFAULT_SAVE_PATH) -> Dictionary:
	var state := default_state()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return state
	state["meta_points"] = int(config.get_value(SECTION, "meta_points", 0))
	var raw_levels = config.get_value(SECTION, "ascension_levels", {})
	var levels := {}
	if raw_levels is Dictionary:
		for character_id in raw_levels.keys():
			levels[str(character_id)] = clampi(int(raw_levels[character_id]), 0, MAX_ASCENSION_LEVEL)
	state["ascension_levels"] = levels
	state["skill_points"] = maxi(int(config.get_value(SECTION, "skill_points", 0)), 0)
	var raw_nodes = config.get_value(SECTION, "skill_nodes", [])
	var nodes := []
	if raw_nodes is Array:
		for node_id in raw_nodes:
			if node_by_id(str(node_id)).size() > 0 and not nodes.has(str(node_id)):
				nodes.append(str(node_id))
	state["skill_nodes"] = nodes
	var raw_class_wins = config.get_value(SECTION, "class_boss_wins", {})
	var class_wins := {}
	if raw_class_wins is Dictionary:
		for character_id in raw_class_wins.keys():
			class_wins[str(character_id)] = maxi(int(raw_class_wins[character_id]), 0)
	state["class_boss_wins"] = class_wins
	state["secret_boss_defeated"] = bool(config.get_value(SECTION, "secret_boss_defeated", false))
	# SCRUM-617: разблокированные ачивки (массив строк-id; нормализуем к строкам и дедупим).
	var raw_achievements = config.get_value(SECTION, "achievements", [])
	var achievements := []
	if raw_achievements is Array:
		for achievement_id in raw_achievements:
			var sid := str(achievement_id)
			if not achievements.has(sid):
				achievements.append(sid)
	state["achievements"] = achievements
	# SCRUM-620: челленджи класса — метрики и выполненные (нормализуем по классам).
	var raw_cc_progress = config.get_value(SECTION, "class_challenge_progress", {})
	var cc_progress := {}
	if raw_cc_progress is Dictionary:
		for char_id in raw_cc_progress.keys():
			var p = raw_cc_progress[char_id]
			if not (p is Dictionary):
				continue
			var weapons := []
			var raw_weapons = p.get("weapons", [])
			if raw_weapons is Array:
				for w in raw_weapons:
					var ws := str(w)
					if ws != "" and not weapons.has(ws):
						weapons.append(ws)
			cc_progress[str(char_id)] = {
				"weapons": weapons,
				"best_ascension": clampi(int(p.get("best_ascension", 0)), 0, MAX_ASCENSION_LEVEL),
				"no_shop_wins": maxi(int(p.get("no_shop_wins", 0)), 0),
			}
	state["class_challenge_progress"] = cc_progress
	var raw_cc_done = config.get_value(SECTION, "class_challenges_done", {})
	var cc_done := {}
	var valid_challenge_ids := {}
	for challenge in CLASS_CHALLENGES:
		valid_challenge_ids[str(challenge.get("id", ""))] = true
	if raw_cc_done is Dictionary:
		for char_id in raw_cc_done.keys():
			var raw_list = raw_cc_done[char_id]
			if not (raw_list is Array):
				continue
			var done := []
			for cid in raw_list:
				var cs := str(cid)
				if valid_challenge_ids.has(cs) and not done.has(cs):
					done.append(cs)
			cc_done[str(char_id)] = done
	state["class_challenges_done"] = cc_done
	return state


static func save_state(state: Dictionary, save_path := DEFAULT_SAVE_PATH) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "meta_points", int(state.get("meta_points", 0)))
	config.set_value(SECTION, "ascension_levels", state.get("ascension_levels", {}))
	config.set_value(SECTION, "skill_points", int(state.get("skill_points", 0)))
	config.set_value(SECTION, "skill_nodes", state.get("skill_nodes", []))
	config.set_value(SECTION, "class_boss_wins", state.get("class_boss_wins", {}))
	config.set_value(SECTION, "secret_boss_defeated", bool(state.get("secret_boss_defeated", false)))
	config.set_value(SECTION, "achievements", state.get("achievements", []))
	# SCRUM-620: метрики и выполненные челленджи класса.
	config.set_value(SECTION, "class_challenge_progress", state.get("class_challenge_progress", {}))
	config.set_value(SECTION, "class_challenges_done", state.get("class_challenges_done", {}))
	config.save(save_path)


static func ascension_level(state: Dictionary, character_id: String) -> int:
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		return 0
	return clampi(int(levels.get(character_id, 0)), 0, MAX_ASCENSION_LEVEL)


static func record_boss_victory(state: Dictionary, character_id: String, run_level := -1, run_context := {}) -> Dictionary:
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		levels = {}
	var completed := clampi(int(levels.get(character_id, 0)), 0, MAX_ASCENSION_LEVEL)
	# Разблокировка следующего уровня — только если забег прошёл на текущем максимуме
	# (или выше). run_level < 0 = старое поведение (для совместимости).
	var unlocked_new_ascension := false
	if run_level < 0 or run_level >= completed:
		if completed < MAX_ASCENSION_LEVEL:
			unlocked_new_ascension = true
		completed = clampi(completed + 1, 0, MAX_ASCENSION_LEVEL)
	levels[character_id] = completed
	state["ascension_levels"] = levels
	# Очки меты/умений — ТОЛЬКО за НОВОЕ возвышение (любым классом), без фарма
	# повторных боссов на уже пройденном уровне. На максимуме (10) повторы не дают
	# очко. class_boss_wins (прогрессия класса) копится отдельно за каждую победу.
	if unlocked_new_ascension:
		state["meta_points"] = int(state.get("meta_points", 0)) + 1
		state["skill_points"] = int(state.get("skill_points", 0)) + 1
	# Прогрессия по классам (SCRUM-360): победа над боссом этим классом копит его прогресс.
	var class_wins = state.get("class_boss_wins", {})
	if not (class_wins is Dictionary):
		class_wins = {}
	class_wins[character_id] = maxi(int(class_wins.get(character_id, 0)), 0) + 1
	state["class_boss_wins"] = class_wins
	# SCRUM-620: челленджи класса за разнообразие — копим метрики из run_context и
	# отмечаем выполненные пороги (одноразово). run_context опционален (старые вызовы
	# с 3 аргументами не трекают — backward-compatible).
	state = _record_class_challenge_progress(state, character_id, run_level, run_context)
	return state


# SCRUM-620: обновить метрики челленджей класса и отметить достигнутые пороги.
# run_context: {"weapon_id": String, "used_shop": bool}. Чистая мутация state.
static func _record_class_challenge_progress(state: Dictionary, character_id: String, run_level: int, run_context: Dictionary) -> Dictionary:
	if character_id == "":
		return state
	var all_progress = state.get("class_challenge_progress", {})
	if not (all_progress is Dictionary):
		all_progress = {}
	var prog = all_progress.get(character_id, {})
	if not (prog is Dictionary):
		prog = {}
	var weapons = prog.get("weapons", [])
	if not (weapons is Array):
		weapons = []
	var weapon_id := str(run_context.get("weapon_id", ""))
	if weapon_id != "" and not weapons.has(weapon_id):
		weapons.append(weapon_id)
	prog["weapons"] = weapons
	# Лучшее возвышение победы (run_level<0 = неизвестно/легаси, не засчитываем).
	var best_ascension := int(prog.get("best_ascension", 0))
	if run_level >= 0:
		best_ascension = maxi(best_ascension, run_level)
	prog["best_ascension"] = best_ascension
	# Победы без покупок в магазине (явный сигнал used_shop=false).
	var no_shop_wins := int(prog.get("no_shop_wins", 0))
	if run_context.has("used_shop") and not bool(run_context.get("used_shop")):
		no_shop_wins += 1
	prog["no_shop_wins"] = no_shop_wins
	all_progress[character_id] = prog
	state["class_challenge_progress"] = all_progress
	# Отметить достигнутые пороги (дедуп).
	var all_done = state.get("class_challenges_done", {})
	if not (all_done is Dictionary):
		all_done = {}
	var done = all_done.get(character_id, [])
	if not (done is Array):
		done = []
	for challenge in CLASS_CHALLENGES:
		var cid := str(challenge.get("id", ""))
		if cid == "" or done.has(cid):
			continue
		if _class_challenge_met(challenge, prog):
			done.append(cid)
	all_done[character_id] = done
	state["class_challenges_done"] = all_done
	return state


# Достигнут ли порог челленджа по накопленным метрикам класса.
static func _class_challenge_met(challenge: Dictionary, prog: Dictionary) -> bool:
	var metric := str(challenge.get("condition_metric", ""))
	var threshold := int(challenge.get("threshold", 0))
	match metric:
		"weapon_diversity":
			var weapons = prog.get("weapons", [])
			return (weapons is Array) and (weapons as Array).size() >= threshold
		"best_ascension":
			return int(prog.get("best_ascension", 0)) >= threshold
		"no_shop_wins":
			return int(prog.get("no_shop_wins", 0)) >= threshold
		_:
			return false


static func selectable_max(state: Dictionary, character_id: String) -> int:
	# Можно выбрать 0..(пройдено+1), но не выше 10.
	return clampi(ascension_level(state, character_id) + 1, 0, MAX_ASCENSION_LEVEL)


# --- Секретный бой конца Акта 3 (SCRUM-619) ---

static func secret_boss_defeated(state: Dictionary) -> bool:
	return bool(state.get("secret_boss_defeated", false))


# Максимальный достигнутый уровень возвышения среди ВСЕХ классов (для гейта, когда
# конкретный класс забега неизвестен/не передан).
static func _max_ascension_any(state: Dictionary) -> int:
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		return 0
	var best := 0
	for character_id in levels.keys():
		best = maxi(best, clampi(int(levels[character_id]), 0, MAX_ASCENSION_LEVEL))
	return best


# Гейт разблокировки секретного боя. Чистая функция (без сайд-эффектов).
# Условие: возвышение >= SECRET_ENCOUNTER_MIN_ASCENSION  И
#   (low-damage-boss: получено урона за забег <= порога  ИЛИ  есть артефакт-ключ).
# character_id опционален: если задан — берём возвышение этого класса; иначе —
# максимум по всем классам (любой класс на нужном возвышении открывает контент).
static func secret_encounter_unlocked(state: Dictionary, run_metrics: Dictionary, character_id := "") -> bool:
	var asc := ascension_level(state, character_id) if character_id != "" else _max_ascension_any(state)
	if asc < SECRET_ENCOUNTER_MIN_ASCENSION:
		return false
	var low_damage: bool = float(run_metrics.get("damage_taken", 0.0)) <= SECRET_ENCOUNTER_MAX_DAMAGE_TAKEN
	var has_key := _artifacts_contain_key(run_metrics.get("artifacts", []), SECRET_ENCOUNTER_ARTIFACT_KEY)
	return low_damage or has_key


# SCRUM-623: live run/player артефакты хранятся как СЛОВАРИ {id, title}
# (player.gd, combat_director.gd, main.gd run_metrics.artifacts), а тесты/контент
# могут передавать просто строки-id. Матчим ключ в ОБОИХ форматах (по dict["id"]
# или по самой строке), иначе artifact-ветка гейта не срабатывает в живой игре.
static func _artifacts_contain_key(raw_artifacts, key: String) -> bool:
	if not (raw_artifacts is Array):
		return false
	for entry in raw_artifacts:
		if entry is Dictionary:
			if str(entry.get("id", "")) == key:
				return true
		elif str(entry) == key:
			return true
	return false


# Разовая фиксация победы над секретным боссом + награда meta_points. Идемпотентна:
# повторный вызов на уже взятом флаге НЕ начисляет очки второй раз. Мутирует state
# (как record_boss_victory) и возвращает его.
static func record_secret_boss_victory(state: Dictionary) -> Dictionary:
	if secret_boss_defeated(state):
		return state
	state["secret_boss_defeated"] = true
	state["meta_points"] = int(state.get("meta_points", 0)) + SECRET_ENCOUNTER_REWARD_META_POINTS
	return state


# --- Древо умений (SCRUM-150) ---

static func node_by_id(node_id: String) -> Dictionary:
	for node in SKILL_TREE:
		if str(node["id"]) == node_id:
			return node
	return {}


static func branch_nodes(branch: String) -> Array:
	# Узлы ветви по возрастанию tier (последовательная разблокировка).
	var nodes := []
	for node in SKILL_TREE:
		if str(node["branch"]) == branch:
			nodes.append(node)
	nodes.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]))
	return nodes


static func skill_tree_total_cost() -> int:
	var total := 0
	for node in SKILL_TREE:
		total += int(node["cost"])
	return total


static func purchased_nodes(state: Dictionary) -> Array:
	var raw = state.get("skill_nodes", [])
	return raw if raw is Array else []


static func is_node_purchased(state: Dictionary, node_id: String) -> bool:
	return purchased_nodes(state).has(node_id)


static func skill_points(state: Dictionary) -> int:
	return maxi(int(state.get("skill_points", 0)), 0)


static func node_status(state: Dictionary, node_id: String) -> String:
	# "purchased" | "available" | "locked". Доступен, если предыдущий tier ветви
	# куплен (tier 1 — всегда) и хватает очков.
	var node := node_by_id(node_id)
	if node.is_empty():
		return "locked"
	if is_node_purchased(state, node_id):
		return "purchased"
	if not _prerequisites_met(state, node):
		return "locked"
	return "available" if skill_points(state) >= int(node["cost"]) else "locked"


static func _prerequisites_met(state: Dictionary, node: Dictionary) -> bool:
	var tier := int(node["tier"])
	if tier <= 1:
		return true
	# Требуются ВСЕ узлы предыдущего tier этой ветви (их по одному на tier здесь).
	for other in SKILL_TREE:
		if str(other["branch"]) == str(node["branch"]) and int(other["tier"]) == tier - 1:
			if not is_node_purchased(state, str(other["id"])):
				return false
	return true


static func can_buy_node(state: Dictionary, node_id: String) -> bool:
	return node_status(state, node_id) == "available"


static func buy_skill_node(state: Dictionary, node_id: String) -> Dictionary:
	# Покупает узел, если доступен и хватает очков. Возвращает обновлённое состояние
	# (мутирует переданный dict — как остальные функции этого модуля).
	if not can_buy_node(state, node_id):
		return state
	var node := node_by_id(node_id)
	var nodes := purchased_nodes(state).duplicate()
	nodes.append(node_id)
	state["skill_nodes"] = nodes
	state["skill_points"] = skill_points(state) - int(node["cost"])
	return state


static func skill_modifiers(state: Dictionary) -> Dictionary:
	# Суммарные эффекты купленных узлов: множители складываются (применяются как
	# 1.0 + sum), флаги (capstone) — как максимум. Применяется на старте забега.
	var mods := {}
	for node_id in purchased_nodes(state):
		var node := node_by_id(str(node_id))
		if node.is_empty():
			continue
		for key in (node.get("effects", {}) as Dictionary).keys():
			var value := float(node["effects"][key])
			if key in ["guaranteed_rare_shop", "first_levelup_rare", "death_save", "ult_start_charge"]:
				mods[key] = maxf(float(mods.get(key, 0.0)), value)
			else:
				mods[key] = float(mods.get(key, 0.0)) + value
	return mods


static func estimated_power_multiplier(state: Dictionary) -> float:
	# Грубая оценка прироста «эффективной силы» от древа для балансового потолка:
	# урон × скорость атаки × выживаемость (HP + защита + уклонение + реген-доля).
	var m := skill_modifiers(state)
	var dmg := 1.0 + float(m.get("damage_mult", 0.0)) + 0.5 * float(m.get("elite_boss_damage_mult", 0.0))
	var atk := 1.0 + float(m.get("attack_speed_mult", 0.0))
	var hp := 1.0 + float(m.get("max_health_mult", 0.0))
	var mitigation := 1.0 + float(m.get("defense_flat", 0.0)) + float(m.get("dodge_flat", 0.0)) + 0.02 * float(m.get("regeneration_flat", 0.0))
	return dmg * atk * hp * mitigation


# --- Прогрессия по классам (SCRUM-360) ---

static func class_boss_wins(state: Dictionary, character_id: String) -> int:
	var wins = state.get("class_boss_wins", {})
	if not (wins is Dictionary):
		return 0
	return maxi(int(wins.get(character_id, 0)), 0)


static func class_progression() -> Array:
	return CLASS_PROGRESSION


static func class_unlocked_tiers(state: Dictionary, character_id: String) -> Array:
	# Достигнутые пороги класса (wins <= накопленных побед), по возрастанию.
	var wins := class_boss_wins(state, character_id)
	var unlocked := []
	for tier in CLASS_PROGRESSION:
		if wins >= int(tier.get("wins", 0)):
			unlocked.append(tier)
	return unlocked


static func class_level(state: Dictionary, character_id: String) -> int:
	# Сколько порогов прогрессии класса достигнуто (0..len).
	return class_unlocked_tiers(state, character_id).size()


static func class_next_threshold(state: Dictionary, character_id: String) -> Dictionary:
	# Следующий ещё не достигнутый порог (для UI прогресса); {} если всё открыто.
	var wins := class_boss_wins(state, character_id)
	for tier in CLASS_PROGRESSION:
		if wins < int(tier.get("wins", 0)):
			return tier
	return {}


static func class_modifiers(state: Dictionary, character_id: String) -> Dictionary:
	# Суммарные классовые бонусы (накопительно по достигнутым порогам). Множители
	# складываются (применяются как 1.0 + sum). Применять run-модами ТОЛЬКО этому
	# классу (selected_character_id); ключи class_* не пересекаются с аккаунтными.
	var mods := {}
	for tier in class_unlocked_tiers(state, character_id):
		for key in (tier.get("effects", {}) as Dictionary).keys():
			mods[key] = float(mods.get(key, 0.0)) + float(tier["effects"][key])
	return mods


# SCRUM-620: id выполненных челленджей класса (для UI/тестов; дедуп гарантирован
# при записи). Всегда массив строк.
static func class_challenges_done(state: Dictionary, character_id: String) -> Array:
	var all_done = state.get("class_challenges_done", {})
	if not (all_done is Dictionary):
		return []
	var done = all_done.get(character_id, [])
	return done if done is Array else []


# SCRUM-620: накопленные метрики челленджей класса (для UI прогресса). Нормализованный
# словарь {weapons:[], best_ascension:int, no_shop_wins:int}.
static func class_challenge_progress_for(state: Dictionary, character_id: String) -> Dictionary:
	var all_progress = state.get("class_challenge_progress", {})
	var prog = all_progress.get(character_id, {}) if all_progress is Dictionary else {}
	if not (prog is Dictionary):
		prog = {}
	var weapons = prog.get("weapons", [])
	return {
		"weapons": weapons if weapons is Array else [],
		"best_ascension": int(prog.get("best_ascension", 0)),
		"no_shop_wins": int(prog.get("no_shop_wins", 0)),
	}


# SCRUM-620: суммарные модификаторы выполненных челленджей класса. Те же class_*-
# ключи, что и прогрессия (мерджатся в apply_ascension_bonuses). Суммарный вклад на
# ключ КЛАМПИТСЯ на +5% — жёсткий потолок против пауэр-крипа.
static func class_challenge_modifiers(state: Dictionary, character_id: String) -> Dictionary:
	var done := class_challenges_done(state, character_id)
	var mods := {}
	for challenge in CLASS_CHALLENGES:
		var cid := str(challenge.get("id", ""))
		if not done.has(cid):
			continue
		for key in (challenge.get("effects", {}) as Dictionary).keys():
			mods[key] = float(mods.get(key, 0.0)) + float(challenge["effects"][key])
	for key in mods.keys():
		mods[key] = minf(float(mods[key]), CLASS_CHALLENGE_MAX_BONUS)
	return mods
