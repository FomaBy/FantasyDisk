extends RefCounted

# Персистентная метапрогрессия: meta points и уровни возвышения (1-10)
# на персонажа. Сохранение через ConfigFile в user://.

const DEFAULT_SAVE_PATH := "user://fantasydisk_meta.cfg"
const MAX_ASCENSION_LEVEL := 10
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

const SKILL_BRANCHES := ["wealth", "lore", "might", "endure"]
const SKILL_BRANCH_TITLES := {
	"wealth": "Путь Богатства",
	"lore": "Путь Знаний",
	"might": "Путь Мощи",
	"endure": "Путь Стойкости",
}


static func default_state() -> Dictionary:
	return {
		"meta_points": 0,
		"ascension_levels": {},
		"skill_points": 0,
		"skill_nodes": [],
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
	return state


static func save_state(state: Dictionary, save_path := DEFAULT_SAVE_PATH) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "meta_points", int(state.get("meta_points", 0)))
	config.set_value(SECTION, "ascension_levels", state.get("ascension_levels", {}))
	config.set_value(SECTION, "skill_points", int(state.get("skill_points", 0)))
	config.set_value(SECTION, "skill_nodes", state.get("skill_nodes", []))
	config.save(save_path)


static func ascension_level(state: Dictionary, character_id: String) -> int:
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		return 0
	return clampi(int(levels.get(character_id, 0)), 0, MAX_ASCENSION_LEVEL)


static func record_boss_victory(state: Dictionary, character_id: String, run_level := -1) -> Dictionary:
	state["meta_points"] = int(state.get("meta_points", 0)) + 1
	# Победа над боссом даёт и очко умений древа меты (та же экономика, не вторая валюта).
	state["skill_points"] = int(state.get("skill_points", 0)) + 1
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		levels = {}
	var completed := clampi(int(levels.get(character_id, 0)), 0, MAX_ASCENSION_LEVEL)
	# Разблокировка следующего уровня — только если забег прошёл на текущем максимуме
	# (или выше). run_level < 0 = старое поведение (всегда +1, для совместимости).
	if run_level < 0 or run_level >= completed:
		completed = clampi(completed + 1, 0, MAX_ASCENSION_LEVEL)
	levels[character_id] = completed
	state["ascension_levels"] = levels
	return state


static func selectable_max(state: Dictionary, character_id: String) -> int:
	# Можно выбрать 0..(пройдено+1), но не выше 10.
	return clampi(ascension_level(state, character_id) + 1, 0, MAX_ASCENSION_LEVEL)


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
