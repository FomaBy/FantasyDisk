extends RefCounted

# Персистентная метапрогрессия FantasyDisk.
# SCRUM-828 — Мета 4.0 «Созвездия героев» (дизайн: docs/design/systems/
# meta_constellations.md, §2–§6, §8). Две валюты вместо общего пула метаочков:
#   • ЭМБЛЕМЫ КЛАССА (sigils) — per-class: первые клиры возвышений A0..A5 дают
#     2/2/3/4/5/6 (=22) + по 2 за каждый выполненный челлендж класса (3×2=6);
#     тратятся ТОЛЬКО на созвездие этого класса (~28–32 эмблемы за полный выкуп).
#   • ЗВЁЗДНАЯ ПЫЛЬ (stardust) — аккаунт: первая победа каждым классом (17),
#     первый клир A5 каждым классом (17), секретный босс (3), 8 вех кодекса,
#     5 вех достижений; потолок 50. Тратится на «Атлас гильдии» (~58) — всё
#     не купить (осознанный дефицит общего слоя).
# Обе валюты ДЕРИВАТИВНЫ от фактов прогресса (meta_point_awards/челленджи/
# кодекс/ачивки) — анти-фарм повторных побед сохранён 1:1 с v3.
#
# Данные и сборщик графа (17 созвездий + Атлас) — meta_progression_tree_data.gd.
# Публичный API v3 сохранён для старого экрана (node_list/node_by_id/entry_map/
# allocate_node/reset_skill_tree/skill_modifiers/skill_modifiers_for_class);
# meta_points/skill_points остались фасадами «всего заработано/доступно».

const DEFAULT_SAVE_PATH := "user://fantasydisk_meta.cfg"
const CODEX_DATA := preload("res://scripts/codex_data.gd")
const TREE_DATA := preload("res://scripts/meta_progression_tree_data.gd")
const SCHEMA6_DATA := preload("res://scripts/constellation_schema6_data.gd")
# SCRUM-516: лестница возвышений сжата 10→5. Единый кап и для дорожки сложности,
# и для наградной лестницы. Старые сейвы с ascension>5 клампятся в [0..5].
const MAX_ASCENSION_LEVEL := 5
const SECTION := "meta"
# SCRUM-1068: schema 6 is three owning-weapon paths, 20 spend and purchased
# hidden side nodes. Schema-5 class allocations are refunded once; Guild Atlas
# purchases and progression facts survive. Excess old sigils become non-combat
# legacy_mastery before the old reward formula is retired.
const TREE_SCHEMA_VERSION := 6
# Наследный фасадный кап v3: остался только для подписи старого экрана
# (points_label «x / 100»); экономику Меты 4.0 не ограничивает.
const META_POINTS_CAP := 100
# Эмблемы класса за ПЕРВЫЙ клир возвышения A0..A5 (индекс = уровень забега).
const SIGIL_REWARDS_BY_ASCENSION := [2, 2, 3, 4, 4, 5]
const SIGILS_PER_CLASS_CHALLENGE := 0
const SCHEMA5_SIGIL_REWARDS_BY_ASCENSION := [2, 2, 3, 4, 5, 6]
const SCHEMA5_SIGILS_PER_CLASS_CHALLENGE := 2
const SCHEMA6_SPENDABLE_CAP := 20
# Звёздная пыль: источники аккаунта (потолок = 17+17+3+8+5 = 50).
const STARDUST_FIRST_WIN := 1
const STARDUST_FIRST_A5 := 1
const STARDUST_SECRET_BOSS := 3
const STARDUST_CODEX_MILESTONES := 8
const STARDUST_ACHIEVEMENT_MILESTONES := 5
const STARDUST_CAP := 50
# SCRUM-1069 strengthened Guild budget contracts. The full 59-cost Atlas is a
# conservative upper bound for every legal 50-dust build.
const GUILD_ATLAS_ACCOUNT_POWER_CAP := 1.35
const GUILD_ATLAS_CLASS_POWER_DELTA_CAP := 0.18
# Вехи кодекса: доли открытых записей по категориям (4 монстры / 2 боссы /
# 2 артефакты = 8 вех). Доли, а не абсолюты — контент может расти.
const CODEX_MILESTONE_FRACTIONS := {
	"monsters": [0.25, 0.5, 0.75, 1.0],
	"bosses": [0.5, 1.0],
	"artifacts": [0.5, 1.0],
}
# Вехи достижений: пороги числа открытых ачивок (5 вех).
const ACHIEVEMENT_MILESTONE_THRESHOLDS := [1, 2, 4, 6, 8]

# Флаговые ключи эффектов: мержатся через max(), не суммируются.
const FLAG_EFFECT_KEYS := ["guaranteed_rare_shop", "first_levelup_rare", "death_save", "ult_start_charge", "lowhp_guard", "attr_extra_options"]
const SCHEMA6_GENERIC_WEAPON_EFFECT_KEYS := [
	"weapon_damage_flat",
	"weapon_attack_speed_mult",
	"range_or_precision_zone_mult",
	"precision_window_mult",
	"target_pattern_budget_mult",
	"arc_chain_or_zone_geometry_mult",
	"guard_control_zone_mult",
	"control_sustain_value_mult",
	"radius_or_blast_geometry_mult",
	"impact_area_mult",
	"weapon_prefinal_identity_mult",
	"hidden_solo_mastery_mult",
	"hidden_defense_mastery_mult",
	"hidden_crowd_mastery_mult",
	"hidden_aoe_mastery_mult",
]

# Ядра-эмблемы созвездий (id корневых узлов по классу). Имя константы и формат
# сохранены с v3 (entry_map()/тесты/старый экран читают её как точки входа).
const CLASS_ENTRY_NODES := {
	"berserk": "berserk_core",
	"soldier": "soldier_core",
	"thief": "thief_core",
	"elementalist": "elementalist_core",
	"sniper": "sniper_core",
	"priest": "priest_core",
	"biologist": "biologist_core",
	"robot": "robot_core",
	"engineer": "engineer_core",
	"dark_mage": "dark_mage_core",
	"guitarist": "guitarist_core",
	"assassin": "assassin_core",
	"ranger": "ranger_core",
	"doctor": "doctor_core",
	"chemist": "chemist_core",
	"knight": "knight_core",
	"druid": "druid_core",
}

# Мета 4.0: единый граф = Атлас гильдии (branch "atlas") + 17 созвездий
# (branch = class_id). Сборка — в data-модуле.
static var SKILL_TREE: Array = TREE_DATA.build_tree(CLASS_ENTRY_NODES)

# Secret boss endcap (SCRUM-541/1058): после босса финального Act 2, только на максимальном
# доступном возвышении. Награда Меты 4.0 — звёздная пыль (константа сохранила
# имя v3: тесты/UI читают её как «награду секретного босса»).
const SECRET_ENCOUNTER_MIN_ASCENSION := MAX_ASCENSION_LEVEL
const SECRET_ENCOUNTER_MAX_DAMAGE_TAKEN := 60.0
const SECRET_ENCOUNTER_ARTIFACT_KEY := "rift_key"
const SECRET_ENCOUNTER_REWARD_META_POINTS := STARDUST_SECRET_BOSS
const SECRET_BOSS_ID := "secret_ascension_boss"

# Прогрессия ПО КЛАССАМ (SCRUM-360): пассивный фон за победы (не трогаем в
# волне Меты 4.0 — кандидат на слияние в 4.1, см. §8 дизайна).
const CLASS_PROGRESSION := [
	{"wins": 1, "title": "Знакомство с классом", "desc": "Урон этого класса +3%.", "effects": {"class_damage_mult": 0.03}},
	{"wins": 2, "title": "Уверенная рука", "desc": "Максимум здоровья этого класса +3%.", "effects": {"class_max_health_mult": 0.03}},
	{"wins": 4, "title": "Боевая привычка", "desc": "Урон этого класса ещё +4%.", "effects": {"class_damage_mult": 0.04}},
	{"wins": 6, "title": "Отточенный темп", "desc": "Скорость атаки этого класса +4%.", "effects": {"class_attack_speed_mult": 0.04}},
	{"wins": 9, "title": "Мастерство класса", "desc": "Урон этого класса ещё +5%; +3% HP.", "effects": {"class_damage_mult": 0.05, "class_max_health_mult": 0.03}},
]

# Class challenges preserve their progress/facts but schema 6 makes them a
# discovery-only layer: they reveal hidden side nodes and grant no currency or
# combat modifiers.
const CLASS_CHALLENGE_MAX_BONUS := 0.05
const CODEX_DISCOVERY_CATEGORIES := {
	"monsters": "discovered_monsters",
	"bosses": "discovered_bosses",
	"artifacts": "discovered_artifacts",
}
const CLASS_CHALLENGES := [
	{"id": "weapon_master", "title": "Мастер арсенала", "desc": "Победы 3 разными оружиями этого класса открывают тайные звёзды.", "condition_metric": "weapon_diversity", "threshold": 3, "effects": {}},
	{"id": "peak_climber", "title": "Покоритель вершин", "desc": "Победа на возвышении 3+ открывает тайные звёзды.", "condition_metric": "best_ascension", "threshold": 3, "effects": {}},
	{"id": "lone_wolf", "title": "Без посредников", "desc": "Победа без покупок в магазине открывает тайные звёзды.", "condition_metric": "no_shop_wins", "threshold": 1, "effects": {}},
]


static func default_state() -> Dictionary:
	return {
		"meta_points": 0,
		"meta_point_awards": {},
		"skill_tree_schema": TREE_SCHEMA_VERSION,
		"ascension_levels": {},
		"skill_points": 0,
		"skill_nodes": [],
		"legacy_mastery": {},
		"hidden_reveal_facts": {},
		"constellation_schema6_migrated": true,
		"class_boss_wins": {},
		"secret_boss_defeated": false,
		"achievements": [],
		"class_challenge_progress": {},
		"class_challenges_done": {},
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
	# Миграция 4→5 (и старше): факты первых клиров объединяются с выводом из
	# ascension_levels — v3-кап 100 мог блокировать запись награды, объединение
	# возвращает потерянные первые клиры («старые сейвы ничего не теряют», §4).
	var awards := _normalized_meta_point_awards(config.get_value(SECTION, "meta_point_awards", {}))
	if schema < TREE_SCHEMA_VERSION or awards.is_empty():
		awards = _merge_awards(awards, _meta_point_awards_from_ascension_levels(levels))
	state["meta_point_awards"] = awards
	state["skill_tree_schema"] = TREE_SCHEMA_VERSION
	# Native schema 6 preserves validated purchases. Schema 5 refunds only class
	# constellations and preserves the frozen Guild Atlas IDs one-for-one.
	var raw_nodes = config.get_value(SECTION, "skill_nodes", [])
	var nodes := []
	if raw_nodes is Array:
		for node_id in raw_nodes:
			var nid := str(node_id)
			var node := node_by_id(nid)
			var keep_native := schema == TREE_SCHEMA_VERSION and _is_purchasable_id(nid)
			var keep_schema5_guild := schema == 5 and not node.is_empty() and str(node.get("class_affinity", "")) == "" and _is_purchasable_id(nid)
			if (keep_native or keep_schema5_guild) and not nodes.has(nid):
				nodes.append(nid)
	state["skill_nodes"] = nodes
	var raw_class_wins = config.get_value(SECTION, "class_boss_wins", {})
	var class_wins := {}
	if raw_class_wins is Dictionary:
		for character_id in raw_class_wins.keys():
			class_wins[str(character_id)] = maxi(int(raw_class_wins[character_id]), 0)
	state["class_boss_wins"] = class_wins
	state["secret_boss_defeated"] = bool(config.get_value(SECTION, "secret_boss_defeated", false))
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
			var normalized_class_id := str(char_id)
			if SCHEMA6_DATA.class_entry(normalized_class_id).is_empty():
				continue
			var p = raw_cc_progress[char_id]
			if not (p is Dictionary):
				continue
			var weapons := []
			var raw_weapons = p.get("weapons", [])
			if raw_weapons is Array:
				for w in raw_weapons:
					var ws := str(w)
					if _canonical_weapons_for_class(normalized_class_id).has(ws) and not weapons.has(ws):
						weapons.append(ws)
			cc_progress[normalized_class_id] = {
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
	if schema == TREE_SCHEMA_VERSION:
		state["legacy_mastery"] = _normalized_legacy_mastery(config.get_value(SECTION, "legacy_mastery", {}))
		state["hidden_reveal_facts"] = _normalized_hidden_reveal_facts(config.get_value(SECTION, "hidden_reveal_facts", {}))
		state["constellation_schema6_migrated"] = bool(config.get_value(SECTION, "constellation_schema6_migrated", true))
	else:
		state["legacy_mastery"] = _schema5_legacy_mastery(awards, cc_done)
		state["hidden_reveal_facts"] = {}
		state["constellation_schema6_migrated"] = true
	_sync_hidden_reveal_facts(state)
	state["skill_nodes"] = _normalized_schema6_purchases(state, nodes, schema)
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
	config.set_value(SECTION, "skill_nodes", _explicit_purchases(state))
	config.set_value(SECTION, "legacy_mastery", _normalized_legacy_mastery(state.get("legacy_mastery", {})))
	config.set_value(SECTION, "hidden_reveal_facts", _normalized_hidden_reveal_facts(state.get("hidden_reveal_facts", {})))
	config.set_value(SECTION, "constellation_schema6_migrated", true)
	config.set_value(SECTION, "class_boss_wins", state.get("class_boss_wins", {}))
	config.set_value(SECTION, "secret_boss_defeated", bool(state.get("secret_boss_defeated", false)))
	config.set_value(SECTION, "achievements", state.get("achievements", []))
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


# Объединение фактов первых клиров (миграция 4→5): union по классам и уровням.
static func _merge_awards(a: Dictionary, b: Dictionary) -> Dictionary:
	var merged := {}
	for source in [a, b]:
		for character_id in source.keys():
			var list = merged.get(character_id, [])
			for level in source[character_id]:
				if not (list as Array).has(int(level)):
					(list as Array).append(int(level))
			(list as Array).sort()
			merged[character_id] = list
	return merged


static func _sigil_reward_for_ascension(run_level: int) -> int:
	var level := clampi(run_level, 0, MAX_ASCENSION_LEVEL)
	return int(SIGIL_REWARDS_BY_ASCENSION[level])


static func _sync_meta_economy_fields(state: Dictionary) -> void:
	state["skill_tree_schema"] = TREE_SCHEMA_VERSION
	state["meta_point_awards"] = _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	state["legacy_mastery"] = _normalized_legacy_mastery(state.get("legacy_mastery", {}))
	state["constellation_schema6_migrated"] = true
	_sync_hidden_reveal_facts(state)
	state["meta_points"] = earned_meta_points(state)
	state["skill_points"] = available_meta_points(state)


static func _normalized_legacy_mastery(raw) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for class_id in CLASS_ENTRY_NODES.keys():
		var value := maxi(int((raw as Dictionary).get(class_id, 0)), 0)
		if value > 0:
			result[str(class_id)] = value
	return result


static func _schema5_legacy_mastery(awards: Dictionary, challenges_done: Dictionary) -> Dictionary:
	var result := {}
	for raw_class_id in CLASS_ENTRY_NODES.keys():
		var class_id := str(raw_class_id)
		var old_earned := 0
		var class_awards = awards.get(class_id, [])
		if class_awards is Array:
			for raw_level in class_awards:
				var level := clampi(int(raw_level), 0, MAX_ASCENSION_LEVEL)
				old_earned += int(SCHEMA5_SIGIL_REWARDS_BY_ASCENSION[level])
		var done = challenges_done.get(class_id, [])
		if done is Array:
			old_earned += (done as Array).size() * SCHEMA5_SIGILS_PER_CLASS_CHALLENGE
		var legacy := maxi(old_earned - SCHEMA6_SPENDABLE_CAP, 0)
		if legacy > 0:
			result[class_id] = legacy
	return result


static func _normalized_hidden_reveal_facts(raw) -> Dictionary:
	var result := {}
	if not raw is Dictionary:
		return result
	for raw_class_id in CLASS_ENTRY_NODES.keys():
		var class_id := str(raw_class_id)
		var raw_ids = (raw as Dictionary).get(class_id, [])
		if not raw_ids is Array:
			continue
		var ids := []
		for raw_id in raw_ids:
			var hidden_id := str(raw_id)
			var node := node_by_id(hidden_id)
			if (
				not node.is_empty()
				and str(node.get("class_affinity", "")) == class_id
				and str(node.get("role", "")) == "hidden"
				and not ids.has(hidden_id)
			):
				ids.append(hidden_id)
		ids.sort()
		if not ids.is_empty():
			result[class_id] = ids
	return result


static func _sync_hidden_reveal_facts(state: Dictionary) -> void:
	var facts := _normalized_hidden_reveal_facts(state.get("hidden_reveal_facts", {}))
	for raw_class_id in CLASS_ENTRY_NODES.keys():
		var class_id := str(raw_class_id)
		var ids = facts.get(class_id, [])
		if not ids is Array:
			ids = []
		for node in constellation_nodes(class_id):
			var node_data: Dictionary = node
			if str(node_data.get("role", "")) != "hidden":
				continue
			var hidden_id := str(node_data.get("id", ""))
			if _hidden_condition_met(state, node_data) and not (ids as Array).has(hidden_id):
				(ids as Array).append(hidden_id)
		(ids as Array).sort()
		if not (ids as Array).is_empty():
			facts[class_id] = ids
	state["hidden_reveal_facts"] = facts


static func _hidden_condition_met(state: Dictionary, node: Dictionary) -> bool:
	var condition: Dictionary = node.get("condition", {})
	var metric := str(condition.get("metric", ""))
	var threshold := int(condition.get("threshold", 1))
	var class_id := str(node.get("class_affinity", ""))
	match metric:
		"weapon_diversity":
			return (class_challenge_progress_for(state, class_id).get("weapons", []) as Array).size() >= threshold
		"best_ascension":
			return int(class_challenge_progress_for(state, class_id).get("best_ascension", 0)) >= threshold
		"no_shop_wins":
			return int(class_challenge_progress_for(state, class_id).get("no_shop_wins", 0)) >= threshold
		"class_wins":
			return class_boss_wins(state, class_id) >= threshold
		"codex_milestones":
			return codex_milestones_reached(state) >= threshold
		"secret_boss":
			return secret_boss_defeated(state)
		"achievement_milestones":
			return achievement_milestones_reached(state) >= threshold
	return false


static func _normalized_schema6_purchases(state: Dictionary, raw_nodes: Array, source_schema: int) -> Array:
	# Schema-5 migration preserves every valid Guild purchase, even if an old
	# malformed save omitted a prerequisite. Class allocations are fully refunded.
	var accepted := []
	if source_schema != TREE_SCHEMA_VERSION:
		for raw_id in raw_nodes:
			var legacy_id := str(raw_id)
			var legacy_node := node_by_id(legacy_id)
			if (
				not legacy_node.is_empty()
				and str(legacy_node.get("class_affinity", "")) == ""
				and _is_purchasable_id(legacy_id)
				and not accepted.has(legacy_id)
			):
				accepted.append(legacy_id)
		return accepted

	var connected := {}
	for node in SKILL_TREE:
		var node_data: Dictionary = node
		if str(node_data.get("role", "")) == "core":
			connected[str(node_data.get("id", ""))] = true

	var pending := []
	for raw_id in raw_nodes:
		var node_id := str(raw_id)
		var node := node_by_id(node_id)
		if not node.is_empty() and _is_purchasable_id(node_id) and not pending.has(node_id):
			pending.append(node_id)
	var spent_by_scope := {}
	var made_progress := true
	while made_progress and not pending.is_empty():
		made_progress = false
		for pending_index in range(pending.size() - 1, -1, -1):
			var node_id := str(pending[pending_index])
			var node := node_by_id(node_id)
			if str(node.get("role", "")) == "hidden" and not hidden_star_unlocked(state, node_id):
				continue
			var has_connected_neighbor := false
			for neighbor_id in node.get("adj", []):
				if connected.has(str(neighbor_id)):
					has_connected_neighbor = true
					break
			if not has_connected_neighbor:
				continue
			var scope := str(node.get("class_affinity", ""))
			var next_spent := int(spent_by_scope.get(scope, 0)) + int(node.get("cost", 0))
			var spend_cap := stardust_earned(state) if scope == "" else class_sigils_earned(state, scope)
			if next_spent > spend_cap:
				pending.remove_at(pending_index)
				continue
			accepted.append(node_id)
			connected[node_id] = true
			spent_by_scope[scope] = next_spent
			pending.remove_at(pending_index)
			made_progress = true
	return accepted


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
	# Мета 4.0: факт первого клира фиксируется всегда (кап v3 умер вместе с
	# общим пулом) — из него деривативно считаются эмблемы класса и пыль.
	if not class_awards.has(cleared_level):
		class_awards.append(cleared_level)
		class_awards.sort()
		awards[character_id] = class_awards
		state["meta_point_awards"] = awards
	# Разблокировка следующего уровня — только если забег прошёл на текущем
	# максимуме (или выше). run_level < 0 = старое поведение (совместимость).
	if run_level < 0 or run_level >= completed:
		completed = clampi(completed + 1, 0, MAX_ASCENSION_LEVEL)
	levels[character_id] = completed
	state["ascension_levels"] = levels
	# Прогрессия по классам (SCRUM-360): каждая победа копит прогресс класса.
	var class_wins = state.get("class_boss_wins", {})
	if not (class_wins is Dictionary):
		class_wins = {}
	class_wins[character_id] = maxi(int(class_wins.get(character_id, 0)), 0) + 1
	state["class_boss_wins"] = class_wins
	# SCRUM-620: метрики челленджей (в Мете 4.0 также открывают скрытые звезды).
	state = _record_class_challenge_progress(state, character_id, run_level, run_context)
	_sync_meta_economy_fields(state)
	return state


# SCRUM-620: обновить метрики челленджей класса и отметить достигнутые пороги.
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
	if _canonical_weapons_for_class(character_id).has(weapon_id) and not weapons.has(weapon_id):
		weapons.append(weapon_id)
	prog["weapons"] = weapons
	var best_ascension := int(prog.get("best_ascension", 0))
	if run_level >= 0:
		best_ascension = maxi(best_ascension, run_level)
	prog["best_ascension"] = best_ascension
	var no_shop_wins := int(prog.get("no_shop_wins", 0))
	if run_context.has("used_shop") and not bool(run_context.get("used_shop")):
		no_shop_wins += 1
	prog["no_shop_wins"] = no_shop_wins
	all_progress[character_id] = prog
	state["class_challenge_progress"] = all_progress
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


static func _canonical_weapons_for_class(character_id: String) -> Array:
	var result := []
	for raw_branch in SCHEMA6_DATA.class_entry(character_id).get("weapon_branches", []):
		var weapon_id := str((raw_branch as Dictionary).get("weapon_id", ""))
		if weapon_id != "" and not result.has(weapon_id):
			result.append(weapon_id)
	return result


static func selectable_max(state: Dictionary, character_id: String) -> int:
	return clampi(ascension_level(state, character_id) + 1, 0, MAX_ASCENSION_LEVEL)


# --- Секретный бой после финального акта (SCRUM-541/619/1058) ---

static func secret_boss_defeated(state: Dictionary) -> bool:
	return bool(state.get("secret_boss_defeated", false))


static func _max_ascension_any(state: Dictionary) -> int:
	var levels = state.get("ascension_levels", {})
	if not (levels is Dictionary):
		return 0
	var best := 0
	for character_id in levels.keys():
		best = maxi(best, clampi(int(levels[character_id]), 0, MAX_ASCENSION_LEVEL))
	return best


static func secret_encounter_unlocked_for_level(run_level: int) -> bool:
	return clampi(run_level, 0, MAX_ASCENSION_LEVEL) >= MAX_ASCENSION_LEVEL


static func secret_encounter_unlocked(state: Dictionary, run_metrics: Dictionary, character_id := "") -> bool:
	var selected_level := int(run_metrics.get("selected_ascension_level", -1))
	if selected_level >= 0:
		return secret_encounter_unlocked_for_level(selected_level)
	var asc := ascension_level(state, character_id) if character_id != "" else _max_ascension_any(state)
	return secret_encounter_unlocked_for_level(asc)


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


# Разовая фиксация победы над секретным боссом. Идемпотентна; в Мете 4.0 даёт
# +3 звёздной пыли (деривативно от флага) и «зажигает» скрытый узел Атласа.
static func record_secret_boss_victory(state: Dictionary) -> Dictionary:
	if secret_boss_defeated(state):
		return state
	state["secret_boss_defeated"] = true
	_sync_meta_economy_fields(state)
	return state


# --- Валюты Меты 4.0 ---

# Заработанные эмблемы класса: первые клиры возвышений + челленджи класса.
static func class_sigils_earned(state: Dictionary, character_id: String) -> int:
	var awards := _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	if awards.is_empty():
		var levels = state.get("ascension_levels", {})
		if levels is Dictionary:
			awards = _meta_point_awards_from_ascension_levels(levels)
	var total := 0
	var class_awards = awards.get(character_id, [])
	if class_awards is Array:
		for run_level in class_awards:
			total += _sigil_reward_for_ascension(int(run_level))
	total += class_challenges_done(state, character_id).size() * SIGILS_PER_CLASS_CHALLENGE
	return mini(total, SCHEMA6_SPENDABLE_CAP)


# Потраченные эмблемы класса: сумма цен купленных узлов его созвездия.
static func class_sigils_spent(state: Dictionary, character_id: String) -> int:
	var total := 0
	for node_id in _explicit_purchases(state):
		var node := node_by_id(str(node_id))
		if str(node.get("class_affinity", "")) == character_id:
			total += int(node.get("cost", 0))
	return total


static func class_sigils_available(state: Dictionary, character_id: String) -> int:
	return maxi(class_sigils_earned(state, character_id) - class_sigils_spent(state, character_id), 0)


# Открыт ли класс хотя бы одной победой (для пыли «первая победа классом»).
static func _class_has_first_win(state: Dictionary, character_id: String) -> bool:
	if class_boss_wins(state, character_id) > 0:
		return true
	var awards := _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	var class_awards = awards.get(character_id, [])
	if class_awards is Array and not (class_awards as Array).is_empty():
		return true
	# Старые сейвы: пройденное возвышение доказывает победу классом.
	return ascension_level(state, character_id) > 0


# Первый клир A5 классом (для пыли): факт награды уровня 5 или best_ascension.
static func _class_has_a5_clear(state: Dictionary, character_id: String) -> bool:
	var awards := _normalized_meta_point_awards(state.get("meta_point_awards", {}))
	var class_awards = awards.get(character_id, [])
	if class_awards is Array and (class_awards as Array).has(MAX_ASCENSION_LEVEL):
		return true
	return int(class_challenge_progress_for(state, character_id).get("best_ascension", 0)) >= MAX_ASCENSION_LEVEL


# Достигнутые вехи кодекса (0..8): доли открытых записей по категориям.
static func codex_milestones_reached(state: Dictionary) -> int:
	var reached := 0
	for category in CODEX_MILESTONE_FRACTIONS.keys():
		var total := _canonical_codex_ids(str(category)).size()
		if total <= 0:
			continue
		var found := discovered_ids(state, str(category)).size()
		for fraction in CODEX_MILESTONE_FRACTIONS[category]:
			if found >= int(ceilf(float(total) * float(fraction))):
				reached += 1
	return reached


# Достигнутые вехи достижений (0..5): пороги числа открытых ачивок.
static func achievement_milestones_reached(state: Dictionary) -> int:
	var raw = state.get("achievements", [])
	var count := (raw as Array).size() if raw is Array else 0
	var reached := 0
	for threshold in ACHIEVEMENT_MILESTONE_THRESHOLDS:
		if count >= int(threshold):
			reached += 1
	return reached


# Заработанная звёздная пыль (аккаунт, потолок 50).
static func stardust_earned(state: Dictionary) -> int:
	var total := 0
	for class_id in CLASS_ENTRY_NODES.keys():
		if _class_has_first_win(state, str(class_id)):
			total += STARDUST_FIRST_WIN
		if _class_has_a5_clear(state, str(class_id)):
			total += STARDUST_FIRST_A5
	if secret_boss_defeated(state):
		total += STARDUST_SECRET_BOSS
	total += codex_milestones_reached(state)
	total += achievement_milestones_reached(state)
	return clampi(total, 0, STARDUST_CAP)


# Потраченная пыль: сумма цен купленных узлов Атласа.
static func stardust_spent(state: Dictionary) -> int:
	var total := 0
	for node_id in _explicit_purchases(state):
		var node := node_by_id(str(node_id))
		if not node.is_empty() and str(node.get("class_affinity", "")) == "":
			total += int(node.get("cost", 0))
	return total


static func stardust_available(state: Dictionary) -> int:
	return maxi(stardust_earned(state) - stardust_spent(state), 0)


# --- Граф Меты 4.0: доступ к данным ---

static func node_by_id(node_id: String) -> Dictionary:
	for node in SKILL_TREE:
		if str(node["id"]) == node_id:
			return node
	return {}


static func node_list() -> Array:
	return SKILL_TREE.duplicate(true)


static func entry_map() -> Dictionary:
	return CLASS_ENTRY_NODES.duplicate(true)


# Классы созвездий в порядке ленты экрана «Атлас героев».
static func constellation_class_ids() -> Array:
	return (TREE_DATA.CLASS_ORDER as Array).duplicate()


# Узлы созвездия класса (для экрана SCRUM-827: npos/role/condition/lore внутри).
static func constellation_nodes(class_id: String) -> Array:
	var result := []
	for node in SKILL_TREE:
		if str(node.get("class_affinity", "")) == class_id:
			result.append((node as Dictionary).duplicate(true))
	return result


# Узлы Атласа гильдии (account-слой).
static func atlas_nodes() -> Array:
	var result := []
	for node in SKILL_TREE:
		if str(node.get("class_affinity", "")) == "":
			result.append((node as Dictionary).duplicate(true))
	return result


static func branch_nodes(branch: String) -> Array:
	var nodes := []
	for node in SKILL_TREE:
		if str(node["branch"]) == branch:
			nodes.append(node)
	nodes.sort_custom(func(a, b): return int(a["tier"]) < int(b["tier"]) if int(a["tier"]) != int(b["tier"]) else str(a["id"]) < str(b["id"]))
	return nodes


static func skill_tree_total_cost() -> int:
	var total := 0
	for node in SKILL_TREE:
		total += int(node["cost"])
	return total


# Стоимость одного созвездия (12×1 + 4×2 + 3×4 = 32 эмблемы; §3 дизайна).
static func constellation_total_cost(class_id: String) -> int:
	var total := 0
	for node in SKILL_TREE:
		if str(node.get("class_affinity", "")) == class_id:
			total += int(node["cost"])
	return total


# Стоимость Атласа гильдии (~58 пыли при потолке 50).
static func atlas_total_cost() -> int:
	var total := 0
	for node in SKILL_TREE:
		if str(node.get("class_affinity", "")) == "":
			total += int(node["cost"])
	return total


# --- Покупки, статусы, ключевые и скрытые звезды ---

# Schema-6 class hidden stars are explicit cost-1 purchases after reveal. The
# two account-wide Guild hidden nodes retain their frozen auto-active contract.
static func _is_purchasable_id(node_id: String) -> bool:
	var node := node_by_id(node_id)
	if node.is_empty():
		return false
	var role := str(node.get("role", node.get("kind", "")))
	if role == "core":
		return false
	if role == "hidden" and str(node.get("class_affinity", "")) == "":
		return false
	return true


# Явные покупки игрока (без ядер и скрытых; то, что пишется в сейв).
static func _explicit_purchases(state: Dictionary) -> Array:
	var raw = state.get("skill_nodes", [])
	var nodes := []
	if not (raw is Array):
		return nodes
	for node_id in raw:
		var id := str(node_id)
		if _is_purchasable_id(id) and not nodes.has(id):
			nodes.append(id)
	return nodes


# Купленные узлы для UI/эффектов: ядра созвездий и хаб Атласа всегда «куплены».
static func purchased_nodes(state: Dictionary) -> Array:
	var nodes := []
	for node in SKILL_TREE:
		if str((node as Dictionary).get("role", "")) == "core":
			nodes.append(str((node as Dictionary)["id"]))
	nodes.append_array(_explicit_purchases(state))
	return nodes


static func is_node_purchased(state: Dictionary, node_id: String) -> bool:
	return purchased_nodes(state).has(node_id)


# Открыта ли скрытая звезда условием (не покупкой). Условия класса — метрики
# челленджей этого класса; Атласа — аккаунт-метрики (кодекс/секретный босс/ачивки).
static func hidden_star_unlocked(state: Dictionary, node_id: String) -> bool:
	var node := node_by_id(node_id)
	if node.is_empty() or str(node.get("role", "")) != "hidden":
		return false
	var class_id := str(node.get("class_affinity", ""))
	if class_id == "":
		return _hidden_condition_met(state, node)
	var facts = state.get("hidden_reveal_facts", {})
	var revealed = facts.get(class_id, []) if facts is Dictionary else []
	return revealed is Array and (revealed as Array).has(node_id)


# Прогресс условия скрытой звезды (для панели узла экрана 827): {current,
# required, text, unlocked}.
static func hidden_star_progress(state: Dictionary, node_id: String) -> Dictionary:
	var node := node_by_id(node_id)
	if node.is_empty() or str(node.get("role", "")) != "hidden":
		return {}
	var condition: Dictionary = node.get("condition", {})
	var metric := str(condition.get("metric", ""))
	var threshold := int(condition.get("threshold", 1))
	var class_id := str(node.get("class_affinity", ""))
	var current := 0
	match metric:
		"weapon_diversity":
			current = (class_challenge_progress_for(state, class_id).get("weapons", []) as Array).size()
		"best_ascension":
			current = int(class_challenge_progress_for(state, class_id).get("best_ascension", 0))
		"no_shop_wins":
			current = int(class_challenge_progress_for(state, class_id).get("no_shop_wins", 0))
		"class_wins":
			current = class_boss_wins(state, class_id)
		"codex_milestones":
			current = codex_milestones_reached(state)
		"secret_boss":
			current = 1 if secret_boss_defeated(state) else 0
		"achievement_milestones":
			current = achievement_milestones_reached(state)
	return {
		"current": mini(current, threshold),
		"required": threshold,
		"text": str(condition.get("text", "")),
		"unlocked": hidden_star_unlocked(state, node_id),
	}


static func legacy_mastery_for_class(state: Dictionary, class_id: String) -> int:
	var ledger = state.get("legacy_mastery", {})
	return maxi(int(ledger.get(class_id, 0)), 0) if ledger is Dictionary else 0


static func hidden_reveal_facts_for_class(state: Dictionary, class_id: String) -> Array:
	var ledger = state.get("hidden_reveal_facts", {})
	var facts = ledger.get(class_id, []) if ledger is Dictionary else []
	return (facts as Array).duplicate() if facts is Array else []


static func allocated_meta_points(state: Dictionary) -> int:
	var total := 0
	for node_id in _explicit_purchases(state):
		var node := node_by_id(str(node_id))
		if not node.is_empty():
			total += int(node.get("cost", 1))
	return total


# Фасад v3: всего заработано (эмблемы всех классов + пыль). Старый экран и
# смоук-тесты читают его как «общий счёт» — числа Меты 4.0.
static func earned_meta_points(state: Dictionary) -> int:
	var total := stardust_earned(state)
	for class_id in CLASS_ENTRY_NODES.keys():
		total += class_sigils_earned(state, str(class_id))
	return total


# Фасад v3: всего доступно к трате (по всем валютам).
static func available_meta_points(state: Dictionary) -> int:
	var total := stardust_available(state)
	for class_id in CLASS_ENTRY_NODES.keys():
		total += class_sigils_available(state, str(class_id))
	return total


static func global_level(state: Dictionary) -> int:
	return _explicit_purchases(state).size()


static func skill_points(state: Dictionary) -> int:
	# Backward-compatible facade for the old UI: available points across currencies.
	return available_meta_points(state)


# Доступная валюта ДЛЯ узла: эмблемы его класса или пыль для Атласа.
static func currency_available_for_node(state: Dictionary, node_id: String) -> int:
	var node := node_by_id(node_id)
	if node.is_empty():
		return 0
	var class_id := str(node.get("class_affinity", ""))
	if class_id == "":
		return stardust_available(state)
	return class_sigils_available(state, class_id)


static func node_status(state: Dictionary, node_id: String) -> String:
	var node := node_by_id(node_id)
	if node.is_empty():
		return "locked"
	var role := str(node.get("role", ""))
	if role == "hidden":
		if not hidden_star_unlocked(state, node_id):
			return "hidden"
		if str(node.get("class_affinity", "")) == "":
			return "purchased"
		if is_node_purchased(state, node_id):
			return "purchased"
		if not _node_connectivity_available(state, node_id):
			return "locked"
		return "available" if currency_available_for_node(state, node_id) >= int(node["cost"]) else "locked"
	if is_node_purchased(state, node_id):
		return "purchased"
	if not _node_connectivity_available(state, node_id):
		return "locked"
	return "available" if currency_available_for_node(state, node_id) >= int(node["cost"]) else "locked"


static func _node_connectivity_available(state: Dictionary, node_id: String) -> bool:
	var node := node_by_id(node_id)
	if node.is_empty():
		return false
	if str(node.get("role", "")) == "core":
		return true
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
	var nodes := _explicit_purchases(state)
	nodes.append(node_id)
	state["skill_nodes"] = nodes
	_sync_meta_economy_fields(state)
	return state


static func buy_skill_node(state: Dictionary, node_id: String) -> Dictionary:
	return allocate_node(state, node_id)


# Активная ключевая звезда класса ("" — нет). Взаимоисключение: активна ≤1.
static func active_keystone(state: Dictionary, class_id: String) -> String:
	var actives = state.get("active_keystones", {})
	if not (actives is Dictionary):
		return ""
	var node_id := str(actives.get(class_id, ""))
	if node_id == "":
		return ""
	# Валидность: узел существует, куплен, keystone этого класса.
	var node := node_by_id(node_id)
	if node.is_empty() or str(node.get("role", "")) != "keystone" or str(node.get("class_affinity", "")) != class_id:
		return ""
	if not _explicit_purchases(state).has(node_id):
		return ""
	return node_id


static func is_keystone_active(state: Dictionary, node_id: String) -> bool:
	var node := node_by_id(node_id)
	if node.is_empty():
		return false
	return active_keystone(state, str(node.get("class_affinity", ""))) == node_id


# Переключение активной ключевой звезды: бесплатно, только между КУПЛЕННЫМИ
# keystone своего класса; "" — деактивировать.
static func set_active_keystone(state: Dictionary, class_id: String, node_id: String) -> Dictionary:
	var actives = state.get("active_keystones", {})
	if not (actives is Dictionary):
		actives = {}
	if node_id == "":
		actives.erase(class_id)
		state["active_keystones"] = actives
		return state
	var node := node_by_id(node_id)
	if node.is_empty() or str(node.get("role", "")) != "keystone" or str(node.get("class_affinity", "")) != class_id:
		return state
	if not _explicit_purchases(state).has(node_id):
		return state
	actives[class_id] = node_id
	state["active_keystones"] = actives
	return state


static func _normalized_active_keystones(raw, explicit_nodes: Array) -> Dictionary:
	var result := {}
	if not (raw is Dictionary):
		return result
	for class_id in raw.keys():
		var node_id := str(raw[class_id])
		var node := node_by_id(node_id)
		if node.is_empty() or str(node.get("role", "")) != "keystone":
			continue
		if str(node.get("class_affinity", "")) != str(class_id):
			continue
		if not explicit_nodes.has(node_id):
			continue
		result[str(class_id)] = node_id
	return result


# Полный бесплатный респек: все купленные узлы всех валют + активные keystone.
static func reset_skill_tree(state: Dictionary) -> Dictionary:
	state["skill_nodes"] = []
	_sync_meta_economy_fields(state)
	return state


# Респек одного созвездия (для кнопки «Респек» экрана 827).
static func reset_constellation(state: Dictionary, class_id: String) -> Dictionary:
	var kept := []
	for node_id in _explicit_purchases(state):
		var node := node_by_id(str(node_id))
		if str(node.get("class_affinity", "")) != class_id:
			kept.append(str(node_id))
	state["skill_nodes"] = kept
	_sync_meta_economy_fields(state)
	return state


# --- Агрегация эффектов ---

static func skill_modifiers(state: Dictionary) -> Dictionary:
	# Account-wide эффекты: только Атлас гильдии (+ его «зажжённые» скрытые узлы).
	return _skill_modifiers_for_affinity(state, "")


static func skill_modifiers_for_class(state: Dictionary, character_id: String) -> Dictionary:
	# Эффекты забега класса: Атлас + созвездие класса (ядро всегда, купленные
	# звезды, АКТИВНЫЙ keystone, открытые скрытые звезды).
	return _skill_modifiers_for_affinity(state, character_id)


# Typed schema-6 profile for one canonical weapon. Core/class-safe modifiers
# remain in skill_modifiers_for_class; this payload contains only purchased
# nodes owned by the exact weapon ID, so no branch can leak to its two siblings.
static func skill_modifiers_for_weapon(state: Dictionary, character_id: String, weapon_id: String) -> Dictionary:
	var profile := {
		"schema": TREE_SCHEMA_VERSION,
		"class_id": character_id,
		"weapon_id": weapon_id,
		"valid": true,
		"node_ids": [],
		"entries": [],
		"amounts": {},
		"multipliers": {},
		"mechanics": {},
		"errors": [],
	}
	var class_entry := SCHEMA6_DATA.class_entry(character_id)
	if class_entry.is_empty():
		(profile["errors"] as Array).append("unknown class_id")
		profile["valid"] = false
		return profile
	var known_weapon := false
	for raw_branch in class_entry.get("weapon_branches", []):
		var branch: Dictionary = raw_branch
		if str(branch.get("weapon_id", "")) == weapon_id:
			known_weapon = true
			profile["axis"] = str(branch.get("axis", ""))
			profile["identity"] = str(branch.get("identity", ""))
			break
	if not known_weapon:
		(profile["errors"] as Array).append("weapon_id does not belong to class")
		profile["valid"] = false
		return profile

	for raw_node in constellation_nodes(character_id):
		var node: Dictionary = raw_node
		if str(node.get("weapon_id", "")) != weapon_id or not is_node_purchased(state, str(node.get("id", ""))):
			continue
		var effect_profile: Dictionary = node.get("effect_profile", {})
		var effect_key := str(effect_profile.get("effect_key", ""))
		var params: Dictionary = effect_profile.get("params", {})
		var node_id := str(node.get("id", ""))
		if effect_key in SCHEMA6_GENERIC_WEAPON_EFFECT_KEYS:
			_append_schema6_profile_entry(profile, node_id, effect_key, params, node)
			continue
		var mechanic := SCHEMA6_DATA.mechanic(effect_key)
		if mechanic.is_empty() or str(node.get("role", "")) != "weapon_final":
			(profile["errors"] as Array).append("unknown/no-op effect key %s at %s" % [effect_key, node_id])
			profile["valid"] = false
			continue
		(profile["node_ids"] as Array).append(node_id)
		(profile["entries"] as Array).append({
			"node_id": node_id,
			"effect_key": effect_key,
			"params": params.duplicate(true),
			"caps": (node.get("caps", {}) as Dictionary).duplicate(true),
		})
		(profile["mechanics"] as Dictionary)[effect_key] = {
			"node_id": node_id,
			"params": params.duplicate(true),
			"caps": (node.get("caps", {}) as Dictionary).duplicate(true),
			"runtime_consumer": str(node.get("runtime_consumer", "")),
		}
	return profile


static func skill_profiles_for_class(state: Dictionary, character_id: String) -> Dictionary:
	var result := {}
	var class_entry := SCHEMA6_DATA.class_entry(character_id)
	for raw_branch in class_entry.get("weapon_branches", []):
		var weapon_id := str((raw_branch as Dictionary).get("weapon_id", ""))
		if weapon_id != "":
			result[weapon_id] = skill_modifiers_for_weapon(state, character_id, weapon_id)
	return result


static func _append_schema6_profile_entry(profile: Dictionary, node_id: String, effect_key: String, params: Dictionary, node: Dictionary) -> void:
	(profile["node_ids"] as Array).append(node_id)
	(profile["entries"] as Array).append({
		"node_id": node_id,
		"effect_key": effect_key,
		"params": params.duplicate(true),
		"caps": (node.get("caps", {}) as Dictionary).duplicate(true),
	})
	if params.has("amount"):
		var amounts: Dictionary = profile["amounts"]
		amounts[effect_key] = float(amounts.get(effect_key, 0.0)) + float(params["amount"])
	if params.has("multiplier"):
		var multipliers: Dictionary = profile["multipliers"]
		multipliers[effect_key] = float(multipliers.get(effect_key, 1.0)) * float(params["multiplier"])


static func _merge_effect(mods: Dictionary, key: String, value: float) -> void:
	if FLAG_EFFECT_KEYS.has(key):
		mods[key] = maxf(float(mods.get(key, 0.0)), value)
	else:
		mods[key] = float(mods.get(key, 0.0)) + value


static func _skill_modifiers_for_affinity(state: Dictionary, character_id: String) -> Dictionary:
	var mods := {}
	var purchased := purchased_nodes(state)
	for node in SKILL_TREE:
		var node_data: Dictionary = node
		var node_id := str(node_data["id"])
		var affinity := str(node_data.get("class_affinity", ""))
		if affinity != "" and affinity != character_id:
			continue
		var role := str(node_data.get("role", ""))
		var active := false
		match role:
			"hidden":
				active = hidden_star_unlocked(state, node_id) and (affinity == "" or purchased.has(node_id))
			"keystone":
				# Взаимоисключение только в созвездиях; keystone Атласа — обычная покупка.
				if affinity == "":
					active = purchased.has(node_id)
				else:
					active = is_keystone_active(state, node_id)
			_:
				active = purchased.has(node_id)
		if not active:
			continue
		for key in (node_data.get("effects", {}) as Dictionary).keys():
			_merge_effect(mods, str(key), float(node_data["effects"][key]))
	return mods


# Детерминированная оценка account-wide силы Guild Atlas. Экономические ключи
# весят 0, но pickup/healing/charge/death-save учитываются source-aware весами.
# Полный Atlas дороже cap, поэтому этот результат сильнее проверки любой
# легальной 50-point комбинации.
static func estimated_power_multiplier(state: Dictionary) -> float:
	var guild_mods := skill_modifiers(state)
	var total := 0.0
	for key in guild_mods.keys():
		total += float(TREE_DATA.GUILD_ATLAS_POWER_WEIGHTS.get(str(key), 0.0)) \
			* float(guild_mods[key])
	return 1.0 + total


# Бюджет силы Меты 4.0 (§6 дизайна): взвешенная сумма DPS/EHP/utility в
# damage-mult-эквиваленте (веса — TREE_DATA.POWER_WEIGHTS). 1.0 = без меты;
# полный реалистичный билд класса обязан давать 1.18..1.25 (гейт в тестах).
static func estimated_class_power_multiplier(state: Dictionary, character_id: String) -> float:
	var mods := skill_modifiers_for_class(state, character_id)
	var guild_mods := skill_modifiers(state)
	var total := 0.0
	for key in mods.keys():
		var guild_value := float(guild_mods.get(key, 0.0))
		var class_value := float(mods[key]) - guild_value
		total += float(TREE_DATA.POWER_WEIGHTS.get(str(key), 0.0)) * class_value
		total += float(TREE_DATA.GUILD_ATLAS_POWER_WEIGHTS.get(str(key), 0.0)) * guild_value
	return 1.0 + total


# --- Прогрессия по классам (SCRUM-360) ---

static func class_boss_wins(state: Dictionary, character_id: String) -> int:
	var wins = state.get("class_boss_wins", {})
	if not (wins is Dictionary):
		return 0
	return maxi(int(wins.get(character_id, 0)), 0)


static func class_progression() -> Array:
	return CLASS_PROGRESSION


static func class_unlocked_tiers(state: Dictionary, character_id: String) -> Array:
	var wins := class_boss_wins(state, character_id)
	var unlocked := []
	for tier in CLASS_PROGRESSION:
		if wins >= int(tier.get("wins", 0)):
			unlocked.append(tier)
	return unlocked


static func class_level(state: Dictionary, character_id: String) -> int:
	return class_unlocked_tiers(state, character_id).size()


static func class_next_threshold(state: Dictionary, character_id: String) -> Dictionary:
	var wins := class_boss_wins(state, character_id)
	for tier in CLASS_PROGRESSION:
		if wins < int(tier.get("wins", 0)):
			return tier
	return {}


static func class_modifiers(state: Dictionary, character_id: String) -> Dictionary:
	var mods := {}
	for tier in class_unlocked_tiers(state, character_id):
		for key in (tier.get("effects", {}) as Dictionary).keys():
			mods[key] = float(mods.get(key, 0.0)) + float(tier["effects"][key])
	return mods


static func class_challenges_done(state: Dictionary, character_id: String) -> Array:
	var all_done = state.get("class_challenges_done", {})
	if not (all_done is Dictionary):
		return []
	var done = all_done.get(character_id, [])
	return done if done is Array else []


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


static func class_challenge_modifiers(state: Dictionary, character_id: String) -> Dictionary:
	# Schema 6 preserves challenge facts for discovery/reveal only. Combat and
	# spendable rewards were deliberately removed from this progression layer.
	return {}
