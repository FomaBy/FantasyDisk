extends RefCounted

# Персистентная метапрогрессия: meta points и уровни возвышения (1-5)
# на персонажа. Сохранение через ConfigFile в user://.

const DEFAULT_SAVE_PATH := "user://fantasydisk_meta.cfg"
const CODEX_DATA := preload("res://scripts/codex_data.gd")
# SCRUM-807: данные и конструктор графа умений вынесены в отдельный модуль
# (Skill Tree 3.0 — большие классовые ветви раздували этот файл). Публичный API
# ниже (node_list/allocate_node/skill_modifiers*/entry_map) не изменился.
const TREE_DATA := preload("res://scripts/meta_progression_tree_data.gd")
# SCRUM-516: лестница возвышений сжата 10→5 (короче и острее). Единый кап и для
# дорожки сложности (ASCENSION_MODIFIERS), и для наградной лестницы
# (ASCENSION_LEVELS). Старые сейвы с ascension>5 молча клампятся в [0..5] через
# load_state/ascension_level/selectable_max — без краша.
const MAX_ASCENSION_LEVEL := 5
const SECTION := "meta"
# SCRUM-807: схема 4 (Skill Tree 3.0). load_state автоматически мигрирует старые
# сейвы (schema<4 → полный респек купленных узлов, очки пересчитываются из
# meta_point_awards/ascension_levels — тот же паттерн, что миграция 1→3). Очки НЕ
# теряются: экономика возвышений не тронута.
const TREE_SCHEMA_VERSION := 4
const META_POINTS_CAP := 100
const META_POINT_REWARDS_BY_ASCENSION := [1, 1, 2, 3, 4, 5]
const SKILL_BRANCHES := ["core", "strength", "agility", "intelligence", "perception", "energy", "knowledge", "endurance", "leadership"]
const SKILL_BRANCH_TITLES := {
	"core": "Сердце Диска",
	"strength": "Лепесток Силы",
	"agility": "Лепесток Ловкости",
	"intelligence": "Лепесток Интеллекта",
	"perception": "Лепесток Восприятия",
	"energy": "Лепесток Энергии",
	"knowledge": "Лепесток Знания",
	"endurance": "Лепесток Стойкости",
	"leadership": "Лепесток Лидерства",
}
const CLASS_ENTRY_NODES := {
	"berserk": "entry_berserk",
	"soldier": "entry_soldier",
	"thief": "entry_thief",
	"elementalist": "entry_elementalist",
	"sniper": "entry_sniper",
	"priest": "entry_priest",
	"biologist": "entry_biologist",
	"robot": "entry_robot",
	"engineer": "entry_engineer",
	"dark_mage": "entry_dark_mage",
	"guitarist": "entry_guitarist",
	"assassin": "entry_assassin",
	"ranger": "entry_ranger",
	"doctor": "entry_doctor",
	"chemist": "entry_chemist",
	"knight": "entry_knight",
	"druid": "entry_druid",
}

# SCRUM-696/807: PoE-like shared passive graph. Данные и сборщик — в
# meta_progression_tree_data.gd; узлы хранят branch/tier для UI, аллокация —
# графовая через `adj`. CLASS_ENTRY_NODES передаём сборщику как параметр
# (стабильный интерфейс id точек входа; тесты/UI читают его как Meta.CLASS_ENTRY_NODES).
static var SKILL_TREE: Array = TREE_DATA.build_tree(CLASS_ENTRY_NODES)

# Secret boss endcap (SCRUM-541): after the normal Act 3 boss, only when the run
# was launched at the maximum available Ascension level. Old SCRUM-619 low-damage
# and key-artifact branches are kept as retired constants for save/content
# compatibility, but they no longer unlock the fight.
const SECRET_ENCOUNTER_MIN_ASCENSION := MAX_ASCENSION_LEVEL
const SECRET_ENCOUNTER_MAX_DAMAGE_TAKEN := 60.0
const SECRET_ENCOUNTER_ARTIFACT_KEY := "rift_key"
const SECRET_ENCOUNTER_REWARD_META_POINTS := 3
const SECRET_BOSS_ID := "secret_ascension_boss"

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
const CODEX_DISCOVERY_CATEGORIES := {
	"monsters": "discovered_monsters",
	"bosses": "discovered_bosses",
	"artifacts": "discovered_artifacts",
}
const CLASS_CHALLENGES := [
	{"id": "weapon_master", "title": "Мастер арсенала", "desc": "Победы 3 разными оружиями этого класса: +3% урона.", "condition_metric": "weapon_diversity", "threshold": 3, "effects": {"class_damage_mult": 0.03}},
	{"id": "peak_climber", "title": "Покоритель вершин", "desc": "Победа на возвышении 3+: +3% максимума HP.", "condition_metric": "best_ascension", "threshold": 3, "effects": {"class_max_health_mult": 0.03}},
	{"id": "lone_wolf", "title": "Без посредников", "desc": "Победа без покупок в магазине: +3% скорости атаки.", "condition_metric": "no_shop_wins", "threshold": 1, "effects": {"class_attack_speed_mult": 0.03}},
]


static func default_state() -> Dictionary:
	return {
		"meta_points": 0,
		"meta_point_awards": {},
		"skill_tree_schema": TREE_SCHEMA_VERSION,
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
		# SCRUM-621: persistent Codex unlock/discovery tracking. Monsters include
		# standard, elite and mini-elite Codex entries; bosses and artifacts are
		# tracked separately so future Codex filters can unlock per category.
		"discovered_monsters": [],
		"discovered_bosses": [],
		"discovered_artifacts": [],
	}


static func load_state(save_path := DEFAULT_SAVE_PATH) -> Dictionary:
	var state := default_state()
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return state
	var schema := int(config.get_value(SECTION, "skill_tree_schema", 0))
	var raw_levels = config.get_value(SECTION, "ascension_levels", {})
	var levels := {}
	if raw_levels is Dictionary:
		for character_id in raw_levels.keys():
			levels[str(character_id)] = clampi(int(raw_levels[character_id]), 0, MAX_ASCENSION_LEVEL)
	state["ascension_levels"] = levels
	var raw_awards = config.get_value(SECTION, "meta_point_awards", {})
	var awards := _normalized_meta_point_awards(raw_awards)
	if schema < TREE_SCHEMA_VERSION or awards.is_empty():
		awards = _meta_point_awards_from_ascension_levels(levels)
	state["meta_point_awards"] = awards
	state["skill_tree_schema"] = TREE_SCHEMA_VERSION
	var raw_nodes = config.get_value(SECTION, "skill_nodes", [])
	var nodes := []
	if schema == TREE_SCHEMA_VERSION and raw_nodes is Array:
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
	for category in CODEX_DISCOVERY_CATEGORIES.keys():
		var save_key: String = CODEX_DISCOVERY_CATEGORIES[category]
		state[save_key] = _normalized_id_list(config.get_value(SECTION, save_key, []), category)
	_sync_meta_economy_fields(state)
	return state


static func save_state(state: Dictionary, save_path := DEFAULT_SAVE_PATH) -> void:
	_sync_meta_economy_fields(state)
	var config := ConfigFile.new()
	config.set_value(SECTION, "skill_tree_schema", TREE_SCHEMA_VERSION)
	config.set_value(SECTION, "meta_points", earned_meta_points(state))
	config.set_value(SECTION, "meta_point_awards", _normalized_meta_point_awards(state.get("meta_point_awards", {})))
	config.set_value(SECTION, "ascension_levels", state.get("ascension_levels", {}))
	config.set_value(SECTION, "skill_points", available_meta_points(state))
	config.set_value(SECTION, "skill_nodes", purchased_nodes(state))
	config.set_value(SECTION, "class_boss_wins", state.get("class_boss_wins", {}))
	config.set_value(SECTION, "secret_boss_defeated", bool(state.get("secret_boss_defeated", false)))
	config.set_value(SECTION, "achievements", state.get("achievements", []))
	# SCRUM-620: метрики и выполненные челленджи класса.
	config.set_value(SECTION, "class_challenge_progress", state.get("class_challenge_progress", {}))
	config.set_value(SECTION, "class_challenges_done", state.get("class_challenges_done", {}))
	for category in CODEX_DISCOVERY_CATEGORIES.keys():
		var save_key: String = CODEX_DISCOVERY_CATEGORIES[category]
		config.set_value(SECTION, save_key, _normalized_id_list(state.get(save_key, []), category))
	config.save(save_path)


static func _normalized_meta_point_awards(raw) -> Dictionary:
	var result := {}
	if not (raw is Dictionary):
		return result
	for character_id in raw.keys():
		var levels := []
		var raw_levels = raw[character_id]
		if raw_levels is Array:
			for value in raw_levels:
				var level := clampi(int(value), 0, MAX_ASCENSION_LEVEL)
				if not levels.has(level):
					levels.append(level)
		elif raw_levels is Dictionary:
			for key in raw_levels.keys():
				if bool(raw_levels[key]):
					var level := clampi(int(key), 0, MAX_ASCENSION_LEVEL)
					if not levels.has(level):
						levels.append(level)
		levels.sort()
		if not levels.is_empty():
			result[str(character_id)] = levels
	return result


static func _meta_point_awards_from_ascension_levels(levels: Dictionary) -> Dictionary:
	var awards := {}
	for character_id in levels.keys():
		var completed := clampi(int(levels[character_id]), 0, MAX_ASCENSION_LEVEL)
		var list := []
		for run_level in range(completed):
			list.append(run_level)
		if not list.is_empty():
			awards[str(character_id)] = list
	return awards


static func _meta_point_reward_for_ascension(run_level: int) -> int:
	var level := clampi(run_level, 0, MAX_ASCENSION_LEVEL)
	return int(META_POINT_REWARDS_BY_ASCENSION[level])


static func _sync_meta_economy_fields(state: Dictionary) -> void:
	state["skill_tree_schema"] = TREE_SCHEMA_VERSION
	state["meta_point_awards"] = _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	state["meta_points"] = earned_meta_points(state)
	state["skill_points"] = available_meta_points(state)


static func _normalized_id_list(raw, category := "") -> Array:
	var result := []
	if not (raw is Array):
		return result
	for value in raw:
		var id := str(value).strip_edges()
		if id != "" and (category == "" or _is_valid_codex_discovery_id(category, id)) and not result.has(id):
			result.append(id)
	return result


static func _canonical_codex_ids(category: String) -> Dictionary:
	var ids := {}
	match category:
		"monsters":
			for entry in CODEX_DATA.monsters():
				if str(entry.get("kind", "")) != "boss":
					ids[str(entry.get("id", ""))] = true
		"bosses":
			for entry in CODEX_DATA.monsters():
				if str(entry.get("kind", "")) == "boss":
					ids[str(entry.get("id", ""))] = true
		"artifacts":
			for entry in CODEX_DATA.artifacts():
				ids[str(entry.get("id", ""))] = true
	return ids


static func _is_valid_codex_discovery_id(category: String, content_id: String) -> bool:
	return _canonical_codex_ids(category).has(content_id)


static func _discovery_save_key(category: String) -> String:
	return str(CODEX_DISCOVERY_CATEGORIES.get(category, ""))


static func discovered_ids(state: Dictionary, category: String) -> Array:
	var save_key := _discovery_save_key(category)
	if save_key == "":
		return []
	return _normalized_id_list(state.get(save_key, []), category)


static func is_codex_discovered(state: Dictionary, category: String, content_id: String) -> bool:
	return discovered_ids(state, category).has(content_id)


static func record_codex_discovery(state: Dictionary, category: String, content_id: String) -> Dictionary:
	var save_key := _discovery_save_key(category)
	var id := content_id.strip_edges()
	if save_key == "" or id == "" or not _is_valid_codex_discovery_id(category, id):
		return state
	var ids := _normalized_id_list(state.get(save_key, []), category)
	if not ids.has(id):
		ids.append(id)
	state[save_key] = ids
	return state


static func record_codex_discoveries(state: Dictionary, category: String, content_ids: Array) -> Dictionary:
	for content_id in content_ids:
		state = record_codex_discovery(state, category, str(content_id))
	return state


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
	var cleared_level := clampi(run_level if run_level >= 0 else completed, 0, MAX_ASCENSION_LEVEL)
	var awards := _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	if awards.is_empty():
		awards = _meta_point_awards_from_ascension_levels(levels)
	var class_awards = awards.get(character_id, [])
	if not (class_awards is Array):
		class_awards = []
	if not class_awards.has(cleared_level) and earned_meta_points(state) < META_POINTS_CAP:
		class_awards.append(cleared_level)
		class_awards.sort()
		awards[character_id] = class_awards
		state["meta_point_awards"] = awards
	# Разблокировка следующего уровня — только если забег прошёл на текущем максимуме
	# (или выше). run_level < 0 = старое поведение (для совместимости).
	if run_level < 0 or run_level >= completed:
		completed = clampi(completed + 1, 0, MAX_ASCENSION_LEVEL)
	levels[character_id] = completed
	state["ascension_levels"] = levels
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
	_sync_meta_economy_fields(state)
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
	# Можно выбрать 0..(пройдено+1), но не выше 5 (MAX_ASCENSION_LEVEL).
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
static func secret_encounter_unlocked_for_level(run_level: int) -> bool:
	return clampi(run_level, 0, MAX_ASCENSION_LEVEL) >= MAX_ASCENSION_LEVEL


static func secret_encounter_unlocked(state: Dictionary, run_metrics: Dictionary, character_id := "") -> bool:
	var selected_level := int(run_metrics.get("selected_ascension_level", -1))
	if selected_level >= 0:
		return secret_encounter_unlocked_for_level(selected_level)
	var asc := ascension_level(state, character_id) if character_id != "" else _max_ascension_any(state)
	return secret_encounter_unlocked_for_level(asc)


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
	_sync_meta_economy_fields(state)
	return state


# --- Древо умений v2 (SCRUM-696) ---

static func node_by_id(node_id: String) -> Dictionary:
	for node in SKILL_TREE:
		if str(node["id"]) == node_id:
			return node
	return {}


static func branch_nodes(branch: String) -> Array:
	var nodes := []
	for node in SKILL_TREE:
		if str(node["branch"]) == branch:
			nodes.append(node)
	nodes.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]) if int(a["tier"]) != int(b["tier"]) else str(a["id"]) < str(b["id"]))
	return nodes


static func node_list() -> Array:
	return SKILL_TREE.duplicate(true)


static func entry_map() -> Dictionary:
	return CLASS_ENTRY_NODES.duplicate(true)


static func skill_tree_total_cost() -> int:
	var total := 0
	for node in SKILL_TREE:
		total += int(node["cost"])
	return total


static func skill_tree_total_cost_capped() -> int:
	return min(skill_tree_total_cost(), META_POINTS_CAP)


static func purchased_nodes(state: Dictionary) -> Array:
	var raw = state.get("skill_nodes", [])
	var nodes := []
	if not (raw is Array):
		return nodes
	for node_id in raw:
		var id := str(node_id)
		if node_by_id(id).size() > 0 and not nodes.has(id):
			nodes.append(id)
	return nodes


static func is_node_purchased(state: Dictionary, node_id: String) -> bool:
	return purchased_nodes(state).has(node_id)


static func allocated_meta_points(state: Dictionary) -> int:
	var total := 0
	for node_id in purchased_nodes(state):
		var node := node_by_id(str(node_id))
		if not node.is_empty():
			total += int(node.get("cost", 1))
	return total


static func earned_meta_points(state: Dictionary) -> int:
	var awards := _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	if awards.is_empty():
		var levels = state.get("ascension_levels", {})
		if levels is Dictionary:
			awards = _meta_point_awards_from_ascension_levels(levels)
	var total := 0
	for character_id in awards.keys():
		for run_level in awards[character_id]:
			total += _meta_point_reward_for_ascension(int(run_level))
	if secret_boss_defeated(state):
		total += SECRET_ENCOUNTER_REWARD_META_POINTS
	return clampi(total, 0, META_POINTS_CAP)


static func available_meta_points(state: Dictionary) -> int:
	return maxi(earned_meta_points(state) - allocated_meta_points(state), 0)


static func global_level(state: Dictionary) -> int:
	return purchased_nodes(state).size()


static func skill_points(state: Dictionary) -> int:
	# Backward-compatible facade for the current UI: available meta points.
	return available_meta_points(state)


static func node_status(state: Dictionary, node_id: String) -> String:
	var node := node_by_id(node_id)
	if node.is_empty():
		return "locked"
	if is_node_purchased(state, node_id):
		return "purchased"
	if not _node_connectivity_available(state, node_id):
		return "locked"
	return "available" if available_meta_points(state) >= int(node["cost"]) else "locked"


static func _node_connectivity_available(state: Dictionary, node_id: String) -> bool:
	if CLASS_ENTRY_NODES.values().has(node_id):
		return true
	var node := node_by_id(node_id)
	if node.is_empty():
		return false
	var purchased := purchased_nodes(state)
	for neighbor_id in node.get("adj", []):
		if purchased.has(str(neighbor_id)):
			return true
	return false


static func can_buy_node(state: Dictionary, node_id: String) -> bool:
	return node_status(state, node_id) == "available"


static func allocate_node(state: Dictionary, node_id: String) -> Dictionary:
	if not can_buy_node(state, node_id):
		return state
	var nodes := purchased_nodes(state).duplicate()
	nodes.append(node_id)
	state["skill_nodes"] = nodes
	_sync_meta_economy_fields(state)
	return state


static func buy_skill_node(state: Dictionary, node_id: String) -> Dictionary:
	return allocate_node(state, node_id)


static func reset_skill_tree(state: Dictionary) -> Dictionary:
	state["skill_nodes"] = []
	_sync_meta_economy_fields(state)
	return state


static func skill_modifiers(state: Dictionary) -> Dictionary:
	# Account-wide effects only. Class-affinity nodes stay visible and buyable in
	# the shared graph, but their effects are applied only through
	# skill_modifiers_for_class().
	return _skill_modifiers_for_affinity(state, "")


static func skill_modifiers_for_class(state: Dictionary, character_id: String) -> Dictionary:
	return _skill_modifiers_for_affinity(state, character_id)


static func _skill_modifiers_for_affinity(state: Dictionary, character_id: String) -> Dictionary:
	# Суммарные эффекты купленных узлов: множители складываются (применяются как
	# 1.0 + sum), флаги (capstone) — как максимум.
	var mods := {}
	for node_id in purchased_nodes(state):
		var node := node_by_id(str(node_id))
		if node.is_empty():
			continue
		var affinity := str(node.get("class_affinity", ""))
		if affinity != "" and affinity != character_id:
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
