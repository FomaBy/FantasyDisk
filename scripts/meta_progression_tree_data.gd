extends RefCounted

# SCRUM-807 — Skill Tree 3.0: данные и конструктор графа умений вынесены из
# meta_progression.gd (тот раздувался). Здесь живут: топология общего ядра, восемь
# атрибутных лепестков (8 базовых характеристик), и — главное новшество v3 —
# полноценные КЛАССОВЫЕ ВЕТВИ: у каждого из 17 классов ≥8 классовых нодов
# (5 профильных атрибутных + 2 notable + 1 уникальный keystone), собранных
# по матрице релевантности класса (progression_data_characters.ATTRIBUTE_RELEVANCE).
#
# Публичный API meta_progression.gd (node_list/allocate_node/skill_modifiers*/
# entry_map) остаётся обратно-совместимым: этот модуль только СТРОИТ Array узлов
# в том же формате {id,branch,tier,cost,kind,title,desc,effects,pos,adj,
# class_affinity?}. Значения эффектов используют ТОЛЬКО ключи, разведённые в
# player.gd (META_SKILL_*_MAP) — иначе эффект молча теряется.

# --- Восемь общих атрибутных лепестков (8 базовых характеристик) ---
# Идентично v2: якорят геометрию графа, дают базовые *_flat характеристики и
# служат точками стыковки классовых ветвей. angle — направление лепестка (deg).
const ATTRIBUTE_SKILL_PETALS := [
	{"id": "strength", "title": "Сила", "short": "сила", "angle": 0.0, "effects": {"strength_flat": 1.0}, "notable_effects": {"strength_flat": 2.0, "damage_mult": 0.010}, "classes": ["berserk"]},
	{"id": "agility", "title": "Ловкость", "short": "ловкость", "angle": 45.0, "effects": {"agility_flat": 1.0}, "notable_effects": {"agility_flat": 2.0, "crit_chance_flat": 0.010}, "classes": ["thief", "assassin"]},
	{"id": "intelligence", "title": "Интеллект", "short": "интеллект", "angle": 90.0, "effects": {"intelligence_flat": 1.0}, "notable_effects": {"intelligence_flat": 2.0, "aoe_radius_mult": 0.015}, "classes": ["elementalist", "dark_mage"]},
	{"id": "perception", "title": "Восприятие", "short": "восприятие", "angle": 135.0, "effects": {"perception_flat": 1.0}, "notable_effects": {"perception_flat": 2.0, "range_mult": 0.015}, "classes": ["soldier", "sniper", "ranger"]},
	{"id": "energy", "title": "Энергия", "short": "энергия", "angle": 180.0, "effects": {"energy_flat": 1.0}, "notable_effects": {"energy_flat": 2.0, "ult_charge_mult": 0.030}, "classes": []},
	{"id": "knowledge", "title": "Знание", "short": "знание", "angle": 225.0, "effects": {"knowledge_flat": 1.0}, "notable_effects": {"knowledge_flat": 2.0, "dot_damage_flat": 0.80, "attr_extra_options": 1.0}, "classes": ["chemist", "biologist", "doctor", "priest"]},
	{"id": "endurance", "title": "Стойкость", "short": "стойкость", "angle": 270.0, "effects": {"endurance_flat": 1.0}, "notable_effects": {"endurance_flat": 2.0, "max_health_mult": 0.015}, "classes": ["knight", "robot"]},
	{"id": "leadership", "title": "Лидерство", "short": "лидерство", "angle": 315.0, "effects": {"leadership_flat": 1.0}, "notable_effects": {"leadership_flat": 2.0, "aura_radius_mult": 0.015}, "classes": ["engineer", "druid", "guitarist"]},
]

# --- Реестр боевых атрибутов древа (24 attr → ключ эффекта пайплайна) ---
# Каждый профильный (минорный) узел классовой ветви = один такой атрибут.
# key   — ключ эффекта (разведён в player.gd META_SKILL_*_MAP);
# unit  — значение на минорном узле; note — значение внутри notable;
# short — заголовок узла (RU); ru — хвост описания; pct — показывать как %.
# magic_focus не имеет собственного ключа (магурон масштабируется damage_mult),
# поэтому magic-классы представляют его через "damage" (см. дизайн-док).
const ATTR_EFFECT := {
	"damage": {"key": "damage_mult", "unit": 0.030, "note": 0.045, "short": "Урон", "ru": "к урону", "pct": true},
	"attack_speed": {"key": "attack_speed_mult", "unit": 0.030, "note": 0.045, "short": "Скорость атаки", "ru": "к скорости атаки", "pct": true},
	"max_health": {"key": "max_health_mult", "unit": 0.030, "note": 0.050, "short": "Живучесть", "ru": "к макс. здоровью", "pct": true},
	"move_speed": {"key": "move_speed_mult", "unit": 0.030, "note": 0.045, "short": "Скорость", "ru": "к скорости движения", "pct": true},
	"aoe_radius": {"key": "aoe_radius_mult", "unit": 0.040, "note": 0.060, "short": "Область", "ru": "к радиусу области", "pct": true},
	"pickup_radius": {"key": "pickup_radius_flat", "unit": 12.0, "note": 18.0, "short": "Подбор", "ru": "к радиусу подбора", "pct": false},
	"defense": {"key": "defense_flat", "unit": 0.015, "note": 0.025, "short": "Защита", "ru": "к защите", "pct": true},
	"knockback": {"key": "knockback_mult", "unit": 0.050, "note": 0.075, "short": "Отталкивание", "ru": "к отталкиванию", "pct": true},
	"crit_chance": {"key": "crit_chance_flat", "unit": 0.015, "note": 0.025, "short": "Шанс крита", "ru": "к шансу крита", "pct": true},
	"crit_damage": {"key": "crit_damage_flat", "unit": 0.080, "note": 0.120, "short": "Урон крита", "ru": "к урону крита", "pct": true},
	"dodge": {"key": "dodge_flat", "unit": 0.010, "note": 0.015, "short": "Уклонение", "ru": "к уклонению", "pct": true},
	"range": {"key": "range_mult", "unit": 0.030, "note": 0.050, "short": "Дальность", "ru": "к дальности атаки", "pct": true},
	"dot_damage": {"key": "dot_damage_flat", "unit": 0.80, "note": 1.20, "short": "Периодический урон", "ru": "периодического урона", "pct": false},
	"dot_speed": {"key": "dot_speed_flat", "unit": 0.050, "note": 0.080, "short": "Скорость тиков", "ru": "к скорости тиков", "pct": false},
	"projectile_speed": {"key": "projectile_speed_flat", "unit": 22.0, "note": 34.0, "short": "Снаряды", "ru": "к скорости снарядов", "pct": false},
	"aura_radius": {"key": "aura_radius_flat", "unit": 6.0, "note": 9.0, "short": "Аура", "ru": "к радиусу ауры", "pct": false},
	"buff_power": {"key": "buff_power_flat", "unit": 0.020, "note": 0.030, "short": "Поддержка", "ru": "к силе поддержки", "pct": true},
	"summon_amount": {"key": "summon_bonus", "unit": 0.50, "note": 0.80, "short": "Призыв", "ru": "к силе призыва", "pct": false},
	"absorb": {"key": "absorb_flat", "unit": 2.0, "note": 3.0, "short": "Поглощение", "ru": "к поглощению", "pct": false},
	"regeneration": {"key": "regeneration_flat", "unit": 0.080, "note": 0.120, "short": "Регенерация", "ru": "к регенерации", "pct": false},
	"vampiric_amount": {"key": "vampiric_amount_flat", "unit": 0.350, "note": 0.500, "short": "Вампиризм", "ru": "к лечению вампиризмом", "pct": false},
	"vampiric_chance": {"key": "vampiric_chance_flat", "unit": 0.020, "note": 0.030, "short": "Шанс вампиризма", "ru": "к шансу вампиризма", "pct": true},
	"ultimate_power": {"key": "ultimate_flat", "unit": 0.040, "note": 0.060, "short": "Ультимейт", "ru": "к силе ультимейта", "pct": true},
}

# --- RU-подписи для ЛЮБОГО ключа эффекта (для авто-описаний с числами) ---
# Покрывает атрибутные ключи + «сигнатурные» ключи keystone-ов. pct=true → %.
const EFFECT_LABELS := {
	"damage_mult": {"ru": "к урону", "pct": true},
	"attack_speed_mult": {"ru": "к скорости атаки", "pct": true},
	"max_health_mult": {"ru": "к макс. здоровью", "pct": true},
	"move_speed_mult": {"ru": "к скорости движения", "pct": true},
	"aoe_radius_mult": {"ru": "к радиусу области", "pct": true},
	"aura_radius_mult": {"ru": "к радиусу ауры", "pct": true},
	"range_mult": {"ru": "к дальности атаки", "pct": true},
	"knockback_mult": {"ru": "к отталкиванию", "pct": true},
	"ult_charge_mult": {"ru": "к скорости заряда ультимейта", "pct": true},
	"elite_boss_damage_mult": {"ru": "к урону по элиткам и боссам", "pct": true},
	"money_gain_mult": {"ru": "к добыче золота", "pct": true},
	"defense_flat": {"ru": "к защите", "pct": true},
	"dodge_flat": {"ru": "к уклонению", "pct": true},
	"crit_chance_flat": {"ru": "к шансу крита", "pct": true},
	"crit_damage_flat": {"ru": "к урону крита", "pct": true},
	"vampiric_chance_flat": {"ru": "к шансу вампиризма", "pct": true},
	"buff_power_flat": {"ru": "к силе поддержки", "pct": true},
	"ultimate_flat": {"ru": "к силе ультимейта", "pct": true},
	"low_hp_damage_bonus": {"ru": "к урону при низком здоровье", "pct": true},
	"pickup_radius_flat": {"ru": "к радиусу подбора", "pct": false},
	"projectile_speed_flat": {"ru": "к скорости снарядов", "pct": false},
	"absorb_flat": {"ru": "к поглощению", "pct": false},
	"dot_damage_flat": {"ru": "периодического урона", "pct": false},
	"dot_speed_flat": {"ru": "к скорости тиков", "pct": false},
	"aura_radius_flat": {"ru": "к радиусу ауры", "pct": false},
	"summon_bonus": {"ru": "к силе призыва", "pct": false},
	"regeneration_flat": {"ru": "к регенерации", "pct": false},
	"vampiric_amount_flat": {"ru": "к лечению вампиризмом", "pct": false},
	"lowhp_regen_bonus": {"ru": "к регенерации при низком здоровье", "pct": false},
}

# --- Классовые ветви v3 (17 классов) ---
# attrs   — 5 профильных атрибутов ветви (primary-first по ATTRIBUTE_RELEVANCE);
#           каждый становится минорным узлом (см. ATTR_EFFECT).
# notables — 2 notable-узла: {title, attrs:[a,b]} (сумма двух атрибутов в note-объёме).
# keystone — уникальный build-defining узел {title, effects{}} (эффекты — из
#           профиля/фантазии класса; уникальны между классами; class_affinity).
const CLASS_BRANCH_SPECS := {
	"berserk": {
		"title": "Путь берсерка",
		"attrs": ["damage", "knockback", "vampiric_amount", "max_health", "crit_damage"],
		"notables": [
			{"title": "Кровавый напор", "attrs": ["damage", "vampiric_amount"]},
			{"title": "Сокрушающий вихрь", "attrs": ["knockback", "max_health"]},
		],
		"keystone": {"title": "Кровавая жатва", "effects": {"damage_mult": 0.040, "low_hp_damage_bonus": 0.18, "lowhp_regen_bonus": 0.18}},
	},
	"soldier": {
		"title": "Строй солдата",
		"attrs": ["damage", "attack_speed", "projectile_speed", "range", "crit_chance"],
		"notables": [
			{"title": "Огневой рубеж", "attrs": ["damage", "attack_speed"]},
			{"title": "Пристрелка", "attrs": ["range", "projectile_speed"]},
		],
		"keystone": {"title": "Подавляющий огонь", "effects": {"attack_speed_mult": 0.060, "range_mult": 0.040, "elite_boss_damage_mult": 0.030}},
	},
	"thief": {
		"title": "Тропа вора",
		"attrs": ["move_speed", "crit_chance", "dodge", "damage", "pickup_radius"],
		"notables": [
			{"title": "Лёгкие пальцы", "attrs": ["crit_chance", "move_speed"]},
			{"title": "Дым и тень", "attrs": ["dodge", "damage"]},
		],
		"keystone": {"title": "Большой куш", "effects": {"money_gain_mult": 0.160, "crit_chance_flat": 0.030, "move_speed_mult": 0.040}},
	},
	"elementalist": {
		"title": "Стихийная схема",
		"attrs": ["aoe_radius", "damage", "ultimate_power", "range", "dot_damage"],
		"notables": [
			{"title": "Разогретая формула", "attrs": ["aoe_radius", "damage"]},
			{"title": "Стихийный контур", "attrs": ["ultimate_power", "dot_damage"]},
		],
		"keystone": {"title": "Сверхновая", "effects": {"aoe_radius_mult": 0.140, "damage_mult": 0.050, "ultimate_flat": 0.08}},
	},
	"sniper": {
		"title": "Прицел снайпера",
		"attrs": ["crit_chance", "crit_damage", "range", "damage", "projectile_speed"],
		"notables": [
			{"title": "Спокойный выдох", "attrs": ["crit_chance", "crit_damage"]},
			{"title": "Дальний рубеж", "attrs": ["range", "damage"]},
		],
		"keystone": {"title": "Идеальный выстрел", "effects": {"crit_chance_flat": 0.050, "crit_damage_flat": 0.25, "range_mult": 0.100}},
	},
	"priest": {
		"title": "Священная печать",
		"attrs": ["defense", "aura_radius", "buff_power", "max_health", "regeneration"],
		"notables": [
			{"title": "Мягкий хор", "attrs": ["aura_radius", "buff_power"]},
			{"title": "Освящённый оплот", "attrs": ["defense", "regeneration"]},
		],
		"keystone": {"title": "Хор искупления", "effects": {"vampiric_chance_flat": 0.070, "vampiric_amount_flat": 0.65, "aura_radius_mult": 0.100}},
	},
	"biologist": {
		"title": "Живая гипотеза",
		"attrs": ["dot_damage", "dot_speed", "summon_amount", "aoe_radius", "regeneration"],
		"notables": [
			{"title": "Споровый посев", "attrs": ["dot_damage", "dot_speed"]},
			{"title": "Симбиоз", "attrs": ["summon_amount", "aoe_radius"]},
		],
		"keystone": {"title": "Эпидемия", "effects": {"dot_damage_flat": 1.80, "dot_speed_flat": 0.16, "summon_bonus": 1.0}},
	},
	"robot": {
		"title": "Бронеконтур робота",
		"attrs": ["max_health", "absorb", "pickup_radius", "defense", "ultimate_power"],
		"notables": [
			{"title": "Тёплый реактор", "attrs": ["ultimate_power", "absorb"]},
			{"title": "Бронеплиты", "attrs": ["max_health", "defense"]},
		],
		"keystone": {"title": "Овердрайв", "effects": {"ult_charge_mult": 0.240, "ultimate_flat": 0.16, "defense_flat": 0.035}},
	},
	"engineer": {
		"title": "Мастерская инженера",
		"attrs": ["summon_amount", "buff_power", "pickup_radius", "defense", "aura_radius"],
		"notables": [
			{"title": "Сборочный приказ", "attrs": ["summon_amount", "buff_power"]},
			{"title": "Ремонтная сеть", "attrs": ["defense", "aura_radius"]},
		],
		"keystone": {"title": "Армия машин", "effects": {"summon_bonus": 2.0, "buff_power_flat": 0.060, "defense_flat": 0.020}},
	},
	"dark_mage": {
		"title": "Тёмная формула",
		"attrs": ["damage", "dot_damage", "aoe_radius", "dot_speed", "crit_damage"],
		"notables": [
			{"title": "Тонкая завеса", "attrs": ["damage", "dot_damage"]},
			{"title": "Распад", "attrs": ["aoe_radius", "dot_speed"]},
		],
		"keystone": {"title": "Запретное знание", "effects": {"damage_mult": 0.140, "max_health_mult": -0.080, "dot_damage_flat": 1.20}},
	},
	"guitarist": {
		"title": "Сценический контракт",
		"attrs": ["attack_speed", "knockback", "ultimate_power", "buff_power", "aura_radius"],
		"notables": [
			{"title": "Резонанс зала", "attrs": ["buff_power", "aura_radius"]},
			{"title": "Ритм-секция", "attrs": ["attack_speed", "knockback"]},
		],
		"keystone": {"title": "Крещендо", "effects": {"buff_power_flat": 0.080, "aura_radius_mult": 0.140, "knockback_mult": 0.100}},
	},
	"assassin": {
		"title": "Тень ассасина",
		"attrs": ["crit_damage", "dodge", "vampiric_chance", "move_speed", "crit_chance"],
		"notables": [
			{"title": "Тихий выпад", "attrs": ["crit_damage", "crit_chance"]},
			{"title": "Скользящая тень", "attrs": ["dodge", "move_speed"]},
		],
		"keystone": {"title": "Из тени", "effects": {"crit_damage_flat": 0.32, "crit_chance_flat": 0.035, "move_speed_mult": 0.060}},
	},
	"ranger": {
		"title": "След рейнджера",
		"attrs": ["range", "move_speed", "projectile_speed", "damage", "crit_chance"],
		"notables": [
			{"title": "Натянутая тетива", "attrs": ["range", "damage"]},
			{"title": "Ветер охоты", "attrs": ["move_speed", "projectile_speed"]},
		],
		"keystone": {"title": "Град стрел", "effects": {"attack_speed_mult": 0.060, "range_mult": 0.060, "aoe_radius_mult": 0.050}},
	},
	"doctor": {
		"title": "Полевой трактат",
		"attrs": ["regeneration", "vampiric_amount", "vampiric_chance", "max_health", "buff_power"],
		"notables": [
			{"title": "Срочная перевязка", "attrs": ["regeneration", "max_health"]},
			{"title": "Переливание", "attrs": ["vampiric_amount", "vampiric_chance"]},
		],
		"keystone": {"title": "Триаж", "effects": {"regeneration_flat": 0.22, "max_health_mult": 0.060, "vampiric_chance_flat": 0.040}},
	},
	"chemist": {
		"title": "Алхимический обмен",
		"attrs": ["aoe_radius", "dot_speed", "dot_damage", "damage", "range"],
		"notables": [
			{"title": "Едкий ускоритель", "attrs": ["dot_speed", "dot_damage"]},
			{"title": "Цепная реакция", "attrs": ["aoe_radius", "damage"]},
		],
		"keystone": {"title": "Каталитический распад", "effects": {"dot_damage_flat": 2.20, "dot_speed_flat": 0.20, "aoe_radius_mult": 0.060}},
	},
	"knight": {
		"title": "Клятва рыцаря",
		"attrs": ["max_health", "defense", "absorb", "aura_radius", "buff_power"],
		"notables": [
			{"title": "Щитовая выучка", "attrs": ["defense", "absorb"]},
			{"title": "Несокрушимый оплот", "attrs": ["max_health", "buff_power"]},
		],
		"keystone": {"title": "Несокрушимый", "effects": {"defense_flat": 0.065, "max_health_mult": 0.120, "attack_speed_mult": -0.060}},
	},
	"druid": {
		"title": "Корни друида",
		"attrs": ["aura_radius", "summon_amount", "regeneration", "buff_power", "dot_damage"],
		"notables": [
			{"title": "Голос чащи", "attrs": ["aura_radius", "summon_amount"]},
			{"title": "Корни жизни", "attrs": ["regeneration", "buff_power"]},
		],
		"keystone": {"title": "Зов стаи", "effects": {"summon_bonus": 1.0, "aura_radius_mult": 0.120, "buff_power_flat": 0.050}},
	},
}

# Геометрия классовой ветви (локальные смещения узлов от точки входа, в осях
# лепестка dir/tangent). Держим в пределах мирового холста (radius <= ~1090).
const CLASS_ENTRY_RADIUS := 680.0
const CLASS_NODE_LAYOUT := [
	{"key": "a0", "u": 58.0, "v": -46.0},
	{"key": "a1", "u": 58.0, "v": 46.0},
	{"key": "n0", "u": 128.0, "v": 0.0},
	{"key": "a2", "u": 196.0, "v": -52.0},
	{"key": "a3", "u": 196.0, "v": 52.0},
	{"key": "n1", "u": 268.0, "v": 0.0},
	{"key": "a4", "u": 338.0, "v": 0.0},
	{"key": "key", "u": 408.0, "v": 0.0},
]


static func _fmt(x: float) -> String:
	if is_equal_approx(x, roundf(x)):
		return str(int(roundf(x)))
	if is_equal_approx(x, snappedf(x, 0.1)):
		return "%.1f" % snappedf(x, 0.1)
	return "%.2f" % x


# Один эффект → человекочитаемый фрагмент с числом («+3% к урону», «+0.8 периодического урона»).
static func _effect_fragment(key: String, value: float) -> String:
	var label: Dictionary = EFFECT_LABELS.get(key, {})
	var ru := str(label.get("ru", key))
	var pct := bool(label.get("pct", false))
	var num: float = value * 100.0 if pct else value
	var sign := "+" if value >= 0.0 else ""
	var unit := "%" if pct else ""
	return "%s%s%s %s" % [sign, _fmt(num), unit, ru]


# Все эффекты узла → строка описания с числами (без утечки внутренних токенов).
static func _effects_desc(effects: Dictionary) -> String:
	var parts: Array = []
	for key in effects.keys():
		parts.append(_effect_fragment(str(key), float(effects[key])))
	return ", ".join(parts)


static func _add(nodes: Array, index: Dictionary, id: String, branch: String, tier: int, cost: int, kind: String, title: String, desc: String, effects: Dictionary, pos: Vector2, class_affinity := "") -> void:
	var node := {
		"id": id, "branch": branch, "tier": tier, "cost": cost, "kind": kind,
		"title": title, "desc": desc, "effects": effects, "pos": pos, "adj": [],
	}
	if str(class_affinity) != "":
		node["class_affinity"] = str(class_affinity)
	nodes.append(node)
	index[id] = node


static func _connect(index: Dictionary, a: String, b: String) -> void:
	if not index.has(a) or not index.has(b) or a == b:
		return
	var adj_a: Array = index[a]["adj"]
	var adj_b: Array = index[b]["adj"]
	if not adj_a.has(b):
		adj_a.append(b)
	if not adj_b.has(a):
		adj_b.append(a)


# Единственная точка сборки графа. entry_nodes = meta_progression.CLASS_ENTRY_NODES
# (id точек входа по классу) — берём как параметр, чтобы не плодить круговых preload.
static func build_tree(entry_nodes: Dictionary) -> Array:
	var nodes := []
	var index := {}

	# --- Общее ядро (QoL/экономика/выживание) — идентично v2 ---
	_add(nodes, index, "core_origin", "core", 1, 1, "minor", "Искра Пути", "Центральный хаб общего дерева.", {}, Vector2(0, 0))
	_add(nodes, index, "core_rewards", "core", 2, 1, "minor", "Память дороги", "Опыт и золото за бои немного выше.", {"money_gain_mult": 0.006, "xp_gain_mult": 0.006}, Vector2(0, -92))
	_add(nodes, index, "core_craft", "core", 3, 1, "minor", "Тихий торг", "Лавка и докачка атрибутов немного дешевле.", {"shop_price_mult": -0.010, "attr_cost_mult": -0.010}, Vector2(0, 92))
	_add(nodes, index, "core_battle_cry", "core", 4, 3, "keystone", "Боевой раж", "Ультимейт начинает забег заряженным наполовину.", {"ult_start_charge": 0.5}, Vector2(135, -35))
	_add(nodes, index, "core_second_life", "core", 5, 3, "keystone", "Вторая жизнь", "Раз за забег смертельный удар оставляет героя на ногах.", {"death_save": 1.0}, Vector2(-135, -35))
	_add(nodes, index, "core_guild_ties", "core", 6, 3, "keystone", "Связи в гильдии", "В каждой лавке гарантированно есть редкий товар.", {"guaranteed_rare_shop": 1.0, "start_gold_flat": 15.0}, Vector2(0, 182))
	_add(nodes, index, "core_insight", "core", 7, 3, "keystone", "Озарение", "Первое повышение в забеге гарантированно даёт основную характеристику.", {"first_levelup_rare": 1.0}, Vector2(0, -182))
	_connect(index, "core_origin", "core_rewards")
	_connect(index, "core_origin", "core_craft")
	_connect(index, "core_rewards", "core_battle_cry")
	_connect(index, "core_rewards", "core_second_life")
	_connect(index, "core_rewards", "core_insight")
	_connect(index, "core_craft", "core_guild_ties")

	# --- Восемь атрибутных лепестков (8 базовых характеристик) ---
	var petal_notables := {}
	var petal_gates := []
	var radius_gate := 255.0
	var radius_minor_a := 390.0
	var radius_minor_b := 505.0
	var radius_notable := 625.0
	for petal_index in range(ATTRIBUTE_SKILL_PETALS.size()):
		var spec: Dictionary = ATTRIBUTE_SKILL_PETALS[petal_index]
		var attr := str(spec["id"])
		var angle := deg_to_rad(float(spec["angle"]))
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var gate_id := "%s_gate" % attr
		var minor_a_id := "%s_flow_1" % attr
		var minor_b_id := "%s_flow_2" % attr
		var notable_id := "%s_notable" % attr
		var title := str(spec["title"])
		_add(nodes, index, gate_id, attr, 1, 1, "minor", "%s: вход" % title, "Открывает атрибутный лепесток: %s." % str(spec["short"]), {}, dir * radius_gate)
		_add(nodes, index, minor_a_id, attr, 2, 1, "minor", "%s I" % title, "+1 к атрибуту %s." % str(spec["short"]), (spec["effects"] as Dictionary).duplicate(true), dir * radius_minor_a + tangent * 34.0)
		_add(nodes, index, minor_b_id, attr, 3, 1, "minor", "%s II" % title, "Ещё +1 к атрибуту %s." % str(spec["short"]), (spec["effects"] as Dictionary).duplicate(true), dir * radius_minor_b - tangent * 34.0)
		_add(nodes, index, notable_id, attr, 4, 1, "notable", "%s: мастерство" % title, "Крупный атрибутный узел и малый профильный бонус.", (spec["notable_effects"] as Dictionary).duplicate(true), dir * radius_notable)
		petal_notables[attr] = notable_id
		petal_gates.append(gate_id)
		_connect(index, "core_origin", gate_id)
		_connect(index, gate_id, minor_a_id)
		_connect(index, minor_a_id, minor_b_id)
		_connect(index, minor_b_id, notable_id)
	for i in range(petal_gates.size()):
		_connect(index, str(petal_gates[i]), str(petal_gates[(i + 1) % petal_gates.size()]))

	# --- Классовые ветви v3 (17 классов) ---
	for petal_spec in ATTRIBUTE_SKILL_PETALS:
		var attr := str((petal_spec as Dictionary)["id"])
		var angle := deg_to_rad(float((petal_spec as Dictionary)["angle"]))
		var dir := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-dir.y, dir.x)
		var class_ids: Array = (petal_spec as Dictionary).get("classes", [])
		var count := maxi(class_ids.size(), 1)
		for class_index in range(class_ids.size()):
			var class_id := str(class_ids[class_index])
			_build_class_branch(nodes, index, entry_nodes, class_id, attr, dir, tangent, (float(class_index) - float(count - 1) * 0.5) * 168.0, str(petal_notables[attr]))

	for node in nodes:
		(node["adj"] as Array).sort()
	return nodes


static func _build_class_branch(nodes: Array, index: Dictionary, entry_nodes: Dictionary, class_id: String, attr: String, dir: Vector2, tangent: Vector2, branch_v: float, petal_notable_id: String) -> void:
	var spec: Dictionary = CLASS_BRANCH_SPECS.get(class_id, {})
	if spec.is_empty():
		return
	var attrs: Array = spec.get("attrs", [])
	var notables: Array = spec.get("notables", [])
	var keystone: Dictionary = spec.get("keystone", {})
	var entry_id := str(entry_nodes.get(class_id, "entry_%s" % class_id))
	var entry_pos := dir * CLASS_ENTRY_RADIUS + tangent * branch_v
	_add(nodes, index, entry_id, attr, 10, 1, "entry", str(spec.get("title", class_id)), "Вход в классовую ветвь. Доступен сразу; открывает узлы только этого героя.", {}, entry_pos)
	_connect(index, petal_notable_id, entry_id)

	# Позиции по фиксированной раскладке; порядок цепочки: entry → a0 → a1 → n0 → a2 → a3 → n1 → a4 → key.
	var pos_of := func(u: float, v: float) -> Vector2:
		return dir * (CLASS_ENTRY_RADIUS + u) + tangent * (branch_v + v)
	var minor_attr_slots := ["a0", "a1", "a2", "a3", "a4"]  # соответствуют attrs[0..4]
	var id_by_slot := {}
	# Минорные атрибутные узлы.
	for mi in range(minor_attr_slots.size()):
		var m_slot: String = minor_attr_slots[mi]
		var m_attr_id := str(attrs[mi]) if mi < attrs.size() else str(attrs[attrs.size() - 1])
		var m_ae: Dictionary = ATTR_EFFECT[m_attr_id]
		var m_effects := {str(m_ae["key"]): float(m_ae["unit"])}
		var m_node_id := "%s_%s" % [class_id, m_slot]
		id_by_slot[m_slot] = m_node_id
		var m_layout: Vector2 = _layout_for(m_slot)
		_add(nodes, index, m_node_id, attr, 11, 1, "minor", str(m_ae["short"]), "Профильный атрибут ветви: %s." % _effects_desc(m_effects), m_effects, pos_of.call(m_layout.x, m_layout.y), class_id)
	# Notable-узлы.
	for ni in range(2):
		var n_slot: String = "n%d" % ni
		var n_spec: Dictionary = notables[ni] if ni < notables.size() else {}
		var n_effects := {}
		for na in n_spec.get("attrs", []):
			var n_ae: Dictionary = ATTR_EFFECT[str(na)]
			n_effects[str(n_ae["key"])] = float(n_effects.get(str(n_ae["key"]), 0.0)) + float(n_ae["note"])
		var n_node_id := "%s_%s" % [class_id, n_slot]
		id_by_slot[n_slot] = n_node_id
		var n_layout: Vector2 = _layout_for(n_slot)
		_add(nodes, index, n_node_id, attr, 12 + ni, 2, "notable", str(n_spec.get("title", "Узел ветви")), "Notable ветви: %s." % _effects_desc(n_effects), n_effects, pos_of.call(n_layout.x, n_layout.y), class_id)
	# Keystone.
	var key_effects: Dictionary = (keystone.get("effects", {}) as Dictionary).duplicate(true)
	var key_id := "%s_key" % class_id
	id_by_slot["key"] = key_id
	var key_layout: Vector2 = _layout_for("key")
	_add(nodes, index, key_id, attr, 16, 4, "keystone", str(keystone.get("title", "Легенда класса")), "Легендарный узел «%s»: %s. Эффект работает только у этого героя." % [str(keystone.get("title", "")), _effects_desc(key_effects)], key_effects, pos_of.call(key_layout.x, key_layout.y), class_id)

	# Цепочка связей (единый путь до keystone — «всё дерево не купить»).
	var chain := ["a0", "a1", "n0", "a2", "a3", "n1", "a4", "key"]
	_connect(index, entry_id, str(id_by_slot["a0"]))
	for ci in range(chain.size() - 1):
		_connect(index, str(id_by_slot[chain[ci]]), str(id_by_slot[chain[ci + 1]]))
	# Небольшая перемычка entry↔a1 для читаемого ромба на входе.
	_connect(index, entry_id, str(id_by_slot["a1"]))


static func _layout_for(slot: String) -> Vector2:
	for item in CLASS_NODE_LAYOUT:
		if str((item as Dictionary)["key"]) == slot:
			return Vector2(float((item as Dictionary)["u"]), float((item as Dictionary)["v"]))
	return Vector2.ZERO
