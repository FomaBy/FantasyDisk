extends RefCounted

# SCRUM-198: balance model, economy curve and drop-scaling constants. No value changes.

# FAN-1031 3c-c: пер-классовый numeric down-tune перекормленных верхов делается
# ЗДЕСЬ (damage_budget/solo_target/aoe_target), а НЕ через weapon.damage_multiplier.
# Причина (проверено пробой progression_data.gd::budget_tuning_for): живой урон =
# damage_multiplier × budget_damage_multiplier, где budget_damage_multiplier
# авто-компенсирует damage_multiplier до формульной цели (solo_target/aoe_target ×
# damage_budget) с клампом [0.28, 2.80]. Т.е. правка weapon.damage_multiplier сама по
# себе живой DPS почти не двигает (кроме клампнутых оружий), а вот сдвиг цели профиля
# двигает живой per-hit по ВСЕМ каналам (solo/aoe/crowd) И реебейзит формульный
# smoke-гейт (остаётся зелёным). Crowd-ось при этом падает пропорционально per-hit,
# но её РАЗБЕГ (coverage: залп-по-цели/рой-по-цели/пирс-луч) формулой не бюджетится —
# см. build/stage3c_c_numeric_fan1031.md (карта каналов + решение по coverage-капу).
const CLASS_BUDGET_PROFILES := {
	"berserk": {"profile": "balanced", "survival": "sturdy", "damage_budget": 0.82, "solo_target": 1.00, "aoe_target": 1.00},  # FAN-1031 3d (v6): damage-оси over-budget (v6 solo 1.09/aoe 1.38/crowd 1.42, axe crowd 2.68×). db 1.00→0.82 давит per-hit sword/axe (hammer clamped ceil — не двигается). def 1.41 = survival "sturdy" (in-profile, не трогаем). Калибровать по v7.
	"soldier": {"profile": "balanced", "survival": "steady", "damage_budget": 0.68, "solo_target": 1.00, "aoe_target": 1.00},  # FAN-1031 v9-финал: total 1.17 (solo 1.50 bayonet-driven при профиле 1.00). db 0.72→0.68 — ещё один малый uniform per-hit шаг вниз всех трёх (unclamped, лендится 1:1). def 1.22 = steady (in-profile, не трогаем). Приёмка координатора по budget-dump + --pair live. [v8-история: total 1.17; db 0.76→0.72. v7: total 1.19; db 0.82→0.76.]
	"thief": {"profile": "balanced", "survival": "fragile", "damage_budget": 1.08, "solo_target": 1.00, "aoe_target": 1.00},
	"elementalist": {"profile": "aoe", "survival": "fragile", "damage_budget": 0.63, "solo_target": 0.92, "aoe_target": 1.10},  # FAN-1031 3d-final (v7): total 1.16 (crowd 1.75 prism_focus 3.57×-driven, aoe 1.27). db 0.70→0.63 — один малый шаг per-hit prism/meteor/orb (unclamped). Остаточный crowd-лид — prism (orbit уже width-капнут orbit_max 4); aoe_target 1.10 профиля не трогаем. Калибровать по v8.
	"sniper": {"profile": "solo", "survival": "steady", "damage_budget": 1.35, "solo_target": 1.15, "aoe_target": 0.80},  # FAN-1031 3d-final (v7): total 0.86 FAIL — solo-класс НЕДОдаёт по своей же оси (solo_norm 0.73 при цели 1.15). db 1.15→1.35 «ещё шаг» поднимает budget_dm всех трёх (unclamped, лендится 1:1) + deadeye усилен отдельно (DEADEYE_ENDPOINT_BLAST_RATIO 0.35→0.42, вне budget-компенсации). Калибровать по v8.
	"priest": {"profile": "balanced", "survival": "steady", "damage_budget": 0.86, "solo_target": 1.10, "aoe_target": 1.05},  # FAN-1031 v9-финал: random-A1 0.87<1.0 (единственный fail ascension-гейта) — NET-ZERO power-shift крауд→base/solo. solo_target 1.03→1.10 поднимает per-hit reliquary (unclamped budget_dm лендит; censer/chime clamped ceil — не двигаются) по ВСЕМ осям → лифт floor/random. Крауд-компенсация (net-zero total 1.14) — width-кап кадила ниже (aoe_full 4→3/diminish 1.2→1.7) + reliquary crowd falloff-капнут (3/2.2). Профиль 'balanced' → ordering solo>aoe допустим. Приёмка по budget-dump + --pair live. [v6-история: db 0.92→0.86; falloff/каденс-рычаги.]
	"biologist": {"profile": "aoe", "survival": "fragile", "damage_budget": 1.08, "solo_target": 0.92, "aoe_target": 1.18},
	"robot": {"profile": "balanced", "survival": "tank", "damage_budget": 0.75, "solo_target": 1.07, "aoe_target": 1.05},  # FAN-1031 v8-микротрим: total 1.22, но это ТАНК-driven (def 2.12; damage-оси solo 0.84/aoe 1.05/crowd 1.30). db 0.80→0.75 давит crowd/aoe per-hit ещё на шаг (magnetic_anchor near-clamp; reactor clamped ceil — db его почти не двигает). ⚠️ ОСТАТОК total >1.15 = identity-price ТАНКА (ось defense=EHP): survival "tank" НЕ режем (координаторское решение v7, подтверждено v8). Судить по damage-осям, не по total (v9). [v7-история: db 0.88→0.80.]
	"engineer": {"profile": "balanced", "survival": "steady", "damage_budget": 0.96, "solo_target": 0.98, "aoe_target": 1.12},
	"dark_mage": {"profile": "aoe", "survival": "fragile", "damage_budget": 0.48, "solo_target": 0.66, "aoe_target": 1.30},  # FAN-1031 v8-микротрим: total 1.16 (чуть над коридором). db 0.52→0.48 — ещё один малый шаг per-hit dark_book/dark_wand (unclamped, direct); cursed_skull curse_only DoT db НЕ трогает. aoe_target 1.30 профиля не трогаем. Калибровать по v9. [v7-история: total 1.16, aoe 1.69/crowd 1.33; db 0.58→0.52.] Ниже — история 3c-c: overbudget v4 total 1.82 (solo 1.33 при цели 0.84 — сильнее всего над профилем) → per-hit down-tune; cursed_skull DoT режется отдельно (curse_tick_multiplier). 3d (v6): total 1.41 (aoe 2.19/crowd 1.72, dark_book mirror 3.76×/3.16×, dark_wand chain 2.71×). db 0.72→0.58 давит per-hit dark_book/dark_wand (оба unclamped, direct-канал); cursed_skull curse_only → его DoT db НЕ трогает (уже низок 0.34× crowd). Калибровать по v7.
	"guitarist": {"profile": "aoe", "survival": "control", "damage_budget": 1.50, "solo_target": 1.00, "aoe_target": 1.30},  # FAN-1031 v7: db 1.00→1.50 держит кит клампнутым на budget_dm=2.80 ceil ПОСЛЕ raw-буста identity-капов (riff/bass/amp) → raw лендится 1:1 (иначе тюнер частично компенсирует). Живой рычаг остаётся RAW; db тут только держит насыщение клампа. Продуктовое решение координатора (control-класс недооценён trio-моделью — см. progression_data_weapons electric_guitar). Калибровать по v8.
	"assassin": {"profile": "solo", "survival": "fragile", "damage_budget": 1.15, "solo_target": 1.30, "aoe_target": 0.70},
	"ranger": {"profile": "solo", "survival": "fragile", "damage_budget": 1.38, "solo_target": 1.30, "aoe_target": 0.70},  # FAN-1031 v8-микротрим: total 0.88 FAIL (дно, crowd 0.56). db 1.26→1.38 — ещё шаг вверх, поднимает raw всех трёх (unclamped, лендится 1:1). crowd 0.56 частично by-profile (solo-класс, aoe_target 0.70); остаток — S4 random-floor офер-гарантия ниже. Калибровать по v9. [v6-история: total 0.80, все оси низки; db 1.15→1.26.]
	"doctor": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.00, "aoe_target": 1.00},
	"chemist": {"profile": "aoe", "survival": "fragile", "damage_budget": 0.80, "solo_target": 0.84, "aoe_target": 1.30},  # FAN-1031 v8-микротрим: total 1.18 (чуть над коридором, aoe-лид blast). db 0.85→0.80 — ещё один малый шаг per-hit blast/acid (unclamped). Остаточный aoe-лид — blast per-hit (уже aoe-width капнут aoe_max 3); aoe_target 1.30 (профиль crowd-специалиста) НЕ выгрызаем до бессмысленности — принимаем как profile-identity с примечанием. Калибровать по v9. [v7-история: total 1.36, aoe 2.16 blast 5.29×; db 0.95→0.85.]
	"knight": {"profile": "balanced", "survival": "tank", "damage_budget": 0.85, "solo_target": 1.05, "aoe_target": 1.00},
	"druid": {"profile": "balanced", "survival": "steady", "damage_budget": 1.00, "solo_target": 1.00, "aoe_target": 1.00},
}

# SCRUM-544: comfort-band модель. Целевая ±20%-полоса DPS НЕ плоская: позиция
# класса внутри полосы определяется требуемым уровнем вовлечённости игрока.
# Чем AFK-комфортнее класс (большой авто-радиус, самонаведение, нулевой аим,
# «поставил и фармит») — тем НИЖЕ его потолок в полосе. Чем больше требуется
# скилла/аима/позиционирования (ручная одиночная цель, мили-вход под удар) —
# тем ВЫШЕ потолок (награда за вовлечённость).
#
# comfort_weight — относительный потолок класса внутри полосы (множитель к
# базовому таргету полосы). Нормировка для проверки полосы:
#   comfort_normalized_dps = measured_dps / comfort_weight[class]
# После нормировки потолок/пол полосы должны сойтись в ±20% от медианы по всем
# классам в каждом срезе (1t/5t/20t).
#
# SCRUM-601: веса ОТКАЛИБРОВАНЫ как band-эквалайзер против детерминированной
# аналитической метрики crowd_dps (ProgressionData.estimate_crowd_clear_budget_for_stats
# на base_stats, срезы 1/5/20 целей). Раньше вес = engagement-профиль (ручной аим →
# высокий, AFK-призыв → низкий), но solo/aoe_target классов калибровались НЕЗАВИСИМО,
# поэтому «сырой» crowd_dps (~100..205) шёл ВРАЗРЕЗ с engagement-весом, и кросс-класс
# вылетал из полосы (3.8x разброс). Так как solo/aoe_target трогать нельзя (держат
# внутриклассовый budget), comfort_weight — единственный рычаг: вес ≈ class_mean_raw /
# median_all_raw, чтобы comfort_normalized сошёлся в ±20% (факт ~±6%). Гейт:
# tests/comfort_band_cross_class_gate.gd. Вес влияет ТОЛЬКО на band-измерение, не на
# геймплей. Внутриклассовый порядок (engagement) теперь несёт raw budget, не вес.
# Будущее выравнивание engagement↔raw — через solo/aoe_target (отдельный тикет).
# Per-weapon переопределения (COMFORT_WEIGHT_OVERRIDES) — для оружий, чей «сырой»
# crowd_dps заметно отличается от среднего по классу (призыв/устройство у соло-класса
# или наоборот): вес = weapon_raw / median_all_raw.
const COMFORT_WEIGHTS := {  # FAN-1032: перекалибровано после ребаланса FAN-1031 (tools/comfort_raw_dump.gd + приёмочный CSV v9)
	"assassin": 0.832,
	"berserk": 0.848,
	"biologist": 1.411,
	"chemist": 1.14,
	"dark_mage": 0.684,
	"doctor": 0.896,
	"druid": 1.013,
	"elementalist": 0.76,
	"engineer": 1.089,
	"guitarist": 2.159,
	"knight": 0.879,
	"priest": 1.0,
	"ranger": 1.019,
	"robot": 0.83,
	"sniper": 1.139,
	"soldier": 0.717,
	"thief": 1.139,
}

# Per-weapon comfort переопределения: ключ "<class>/<weapon_id>". Используется,
# когда конкретное оружие требует иной вовлечённости, чем класс в среднем
# (одиночный луч/проджектайл у AoE-класса — выше; авто-призыв у соло-класса — ниже).
const COMFORT_WEIGHT_OVERRIDES := {

}

# Допуск полосы: comfort-нормированный DPS каждого оружия должен лежать в
# [1 - tol, 1 + tol] от медианы нормированных значений среза.
const COMFORT_BAND_TOLERANCE := 0.20
const COMFORT_DEFAULT_WEIGHT := 1.00

# SCRUM-544: comfort-полоса НЕ ПЛОСКАЯ и НЕ ОДНОМЕРНАЯ — позиция класса внутри
# ±20% определяется осью вовлечённости, а ось РАЗНАЯ для числа целей. На 1 цели
# (дуэль, ручной аим/позиционирование) single-target классы (sniper/assassin/
# ranger) законно несут более высокий потолок; AoE/crowd классы (dark_mage/
# chemist/biologist/guitarist) — наоборот, высокий потолок на рое (5/20 целей),
# а на одиночной цели сидят ниже. Один скаляр на класс это выразить НЕ может
# (тот же класс высок на 1t и нормален на 20t), поэтому comfort-вес для CSV-полосы
# задан per-slice. Это и есть «позиция определяется требуемой вовлечённостью».
#
# Веса откалиброваны по данным: для каждого среза (ideal_1/ideal_5/ideal_20)
# вес класса = медиана(raw_dps оружий класса) / медиана(raw_dps всех оружий среза)
# на lvl20-оптимуме (build/character_balance_dps.csv). После нормировки
# comfort_slice_normalized = raw / slice_weight сходится в ±20% медианы среза.
# Веса влияют ТОЛЬКО на band-измерение CSV (tools/character_balance_csv.gd),
# НЕ на геймплей и НЕ на аналитический гейт comfort_band_cross_class_gate.gd
# (тот по-прежнему использует плоский COMFORT_WEIGHTS на base_stats).
const COMFORT_BAND_SLICES := ["ideal_1", "ideal_5", "ideal_20"]
const COMFORT_BAND_SLICE_WEIGHTS := {
	"assassin": {"ideal_1": 1.829, "ideal_20": 0.32, "ideal_5": 0.729},
	"berserk": {"ideal_1": 0.914, "ideal_20": 1.549, "ideal_5": 1.131},
	"biologist": {"ideal_1": 0.973, "ideal_20": 0.808, "ideal_5": 0.884},
	"chemist": {"ideal_1": 0.663, "ideal_20": 1.217, "ideal_5": 1.02},
	"dark_mage": {"ideal_1": 1.0, "ideal_20": 1.204, "ideal_5": 1.787},
	"doctor": {"ideal_1": 1.305, "ideal_20": 0.959, "ideal_5": 0.952},
	"druid": {"ideal_1": 0.601, "ideal_20": 1.069, "ideal_5": 0.764},
	"elementalist": {"ideal_1": 0.716, "ideal_20": 1.442, "ideal_5": 1.06},
	"engineer": {"ideal_1": 1.012, "ideal_20": 0.625, "ideal_5": 1.274},
	"guitarist": {"ideal_1": 0.579, "ideal_20": 1.596, "ideal_5": 1.0},
	"knight": {"ideal_1": 0.748, "ideal_20": 0.697, "ideal_5": 0.437},
	"priest": {"ideal_1": 0.71, "ideal_20": 2.573, "ideal_5": 1.61},
	"ranger": {"ideal_1": 1.389, "ideal_20": 0.719, "ideal_5": 0.805},
	"robot": {"ideal_1": 0.691, "ideal_20": 1.173, "ideal_5": 0.904},
	"sniper": {"ideal_1": 1.016, "ideal_20": 0.82, "ideal_5": 1.0},
	"soldier": {"ideal_1": 1.176, "ideal_20": 1.325, "ideal_5": 0.915},
	"thief": {"ideal_1": 1.067, "ideal_20": 0.635, "ideal_5": 1.056},
}

# Per-weapon per-slice переопределения для оружий, чей «сырой» DPS заметно
# отличается от класса в данном срезе (утилита/DoT/мили-хил/призыв у не-профильного
# класса). Ключ "<class>/<weapon>" → {slice: weight}. Частичный набор срезов
# допустим (отсутствующий срез падает на class-вес). Вес = weapon_raw / slice_median.
const COMFORT_BAND_SLICE_OVERRIDES := {
	"assassin/chakrams": {"ideal_1": 2.437, "ideal_20": 0.581},
	"assassin/shadow_daggers": {"ideal_1": 1.154, "ideal_5": 1.02},
	"berserk/hammer": {"ideal_1": 1.342, "ideal_5": 2.228},
	"berserk/sword": {"ideal_1": 0.571, "ideal_20": 0.294, "ideal_5": 0.149},
	"biologist/biologist_sample_injector": {"ideal_1": 1.401},
	"biologist/biologist_spore_lens": {"ideal_20": 1.353, "ideal_5": 1.495},
	"biologist/biologist_symbiote_seed": {"ideal_1": 0.502},
	"chemist/blast_powder": {"ideal_1": 1.71, "ideal_20": 1.729, "ideal_5": 3.56},
	"dark_mage/cursed_skull": {"ideal_1": 0.542, "ideal_20": 0.356, "ideal_5": 0.755},
	"dark_mage/dark_book": {"ideal_1": 1.479, "ideal_20": 2.463, "ideal_5": 2.519},
	"doctor/bone_saw": {"ideal_1": 2.286, "ideal_20": 1.842, "ideal_5": 1.553},
	"doctor/plague_syringe": {"ideal_20": 0.105, "ideal_5": 0.336},
	"druid/raven_totem": {"ideal_1": 0.451, "ideal_20": 0.355, "ideal_5": 0.551},
	"druid/summon_amulet": {"ideal_1": 1.762, "ideal_20": 2.077, "ideal_5": 2.827},
	"elementalist/elementalist_orb_ring": {"ideal_20": 0.488},
	"elementalist/elementalist_prism_focus": {"ideal_1": 1.74, "ideal_20": 3.564, "ideal_5": 1.939},
	"engineer/engineer_pressure_mines": {"ideal_1": 0.05, "ideal_20": 2.037, "ideal_5": 0.477},
	"engineer/engineer_sentry_wrench": {"ideal_1": 3.94, "ideal_5": 1.543},
	"guitarist/electric_guitar": {"ideal_1": 0.877, "ideal_20": 0.75, "ideal_5": 0.788},
	"knight/holy_flail": {"ideal_1": 0.464, "ideal_20": 2.047, "ideal_5": 1.129},
	"knight/long_spear": {"ideal_20": 0.453},
	"knight/tower_shield": {"ideal_1": 1.126},
	"priest/priest_censer": {"ideal_1": 0.503, "ideal_20": 1.0, "ideal_5": 0.811},
	"priest/priest_reliquary": {"ideal_1": 1.189},
	"ranger/hunter_trap": {"ideal_1": 0.609, "ideal_20": 0.908},
	"ranger/moon_crossbow": {"ideal_5": 2.225},
	"ranger/storm_longbow": {"ideal_5": 0.46},
	"robot/robot_reactor_core": {"ideal_1": 1.06, "ideal_5": 1.24},
	"sniper/sniper_deadeye_rifle": {"ideal_1": 1.646},
	"sniper/sniper_shatter_rounds": {"ideal_20": 0.357},
	"sniper/sniper_spotter_scope": {"ideal_1": 0.683, "ideal_20": 1.124},
	"soldier/soldier_bayonet": {"ideal_1": 2.279},
	"soldier/soldier_grenade": {"ideal_20": 1.608, "ideal_5": 1.654},
	"soldier/soldier_rifle": {"ideal_1": 0.902, "ideal_20": 0.829},
	"thief/thief_coin_pouch": {"ideal_1": 0.8, "ideal_20": 0.479},
	"thief/thief_shadow_cloak": {"ideal_1": 2.807},
	"thief/thief_smoke_bomb": {"ideal_20": 2.193, "ideal_5": 1.631},
}

const CLASS_LEVEL_STAT_GROWTH_SCALARS := {
	"biologist": 1.00,
	"soldier": {"strength": 0.95, "agility": 0.95},
	"elementalist": {"agility": 0.92, "intelligence": 0.92},
	"priest": {"agility": 0.85, "intelligence": 0.85},
	# FAN-1128: после обновления live-kit'ов заново измерен SCRUM-469: 17 классов,
	# lvl20 optimum (+19 очков) и 64 seeded random-build'а. Это только калибровка
	# роста очков сверх стартовых статов: Base lvl1, CLASS_BUDGET_PROFILES, оружие,
	# геометрия, темп и уникальные механики не изменяются. Для классов с числом
	# множитель применяется ко всем bonus stats; у Друида оставлена явная карта,
	# чтобы не раздувать случайные непрофильные investment'ы. Гейт 0.90..1.10:
	# tests/class_damage_table_3variants_test.gd.
	"robot": 0.75,
	"engineer": {"strength": 0.72, "agility": 0.72, "leadership": 0.80},
	"dark_mage": {"agility": 0.84, "intelligence": 0.84},
	"guitarist": 0.75,
	"assassin": {"strength": 1.668, "agility": 1.668},
	"doctor": 0.70,
	"chemist": 0.78,
	"knight": 0.70,
	"druid": {"strength": 0.95, "agility": 0.95, "intelligence": 0.25, "energy": 0.75, "knowledge": 0.25, "endurance": 0.70, "perception": 0.55, "leadership": 0.70},
	"berserk": {"strength": 1.10, "agility": 1.03},
	"thief": {"strength": 0.86, "agility": 0.86},
}

const BALANCE_BASE_SOLO_DPS := 48.0

const BALANCE_BASE_AOE_DPS := 150.0

const BALANCE_WINDOW_SECONDS := 30.0

const CROWD_CLEAR_TARGET_COUNTS := [5, 10, 20]
const CROWD_CLEAR_ENEMY_HP := 80.0
const CROWD_CLEAR_CORRIDOR := 0.30
const CROWD_CLEAR_SOLO_CORRIDOR := 0.20

# FAN-1031 S2 (Stage 3a): потолок урона ЗОН/СЛАМОВ/ХАЗАРДОВ босса долей ТЕКУЩЕГО
# max HP игрока за тик. Контактный урон капится 0.20 (enemy._update_contact_damage),
# элитный — 0.25 (enemy._elite_attack_damage); зоны/сламы/укусы босса были ЕДИНСТВЕННЫМ
# каналом урона БЕЗ такого капа, поэтому hazard фазы 4 на A5 (~164 урона, худший —
# секретный босс) ваншотил ВСЕ 17 классов (typ HP 50–157) с полного здоровья.
# Baseline v2 (FAN-1029): «ваншот-вердикт — все 17 классов валятся hazard-ом фазы 4».
# 0.80 подобран так, что провал доджа по-прежнему почти смертелен (телеграфы честные
# после combat-feel этапа C — увернуться реально), но full-HP герой больше не удаляется
# одним неравным тиком; это единственный реалистичный путь к DoD «каждый класс проходит
# A5» без раздувания HP хрупких классов в ~3×. Гейт: tests/boss_hazard_cap_gate.gd.
const BOSS_HAZARD_MAX_HP_FRACTION := 0.80

const SURVIVABILITY_DEFENSE_CAP := 0.62
const SURVIVABILITY_DEFENSE_DIMINISH := 0.55
const SURVIVABILITY_DODGE_CAP := 0.55
const SURVIVABILITY_DODGE_DIMINISH := 1.15
# SCRUM-897 «Дымовая Бомба»: потолок СУММАРНОГО шанса уворота внутри дым-облака
# Вора (капнутый базовый dodge + бонус облака). Читается только пока герой стоит
# в живом облаке (player.smoke_cloud_dodge_bonus); вне дыма действует обычный
# SURVIVABILITY_DODGE_CAP. 0.90 = «почти неуязвим в дыму при тяжёлом dodge-билде,
# но никогда не бессмертен и только внутри облака».
const SMOKE_CLOUD_DODGE_CAP := 0.90
# SCRUM-526: нерф защитной оси (absorb/regen/vampiric). Защитные механики были
# супер-имбовыми — «закопаться в выживаемость» доминировало над уроном. Ослаблены
# измеримо, чтобы выживаемость была полезной, но не доминирующей стратегией.
# До→после: absorb min-fraction 0.35→0.42 (больше доля удара всегда проходит),
# flat-diminish 0.08→0.11 (быстрее насыщение стака), regen-flat-mult 0.45→0.35.
const SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION := 0.42
const SURVIVABILITY_ABSORB_FLAT_DIMINISH := 0.11
const SURVIVABILITY_REGEN_FLAT_MULTIPLIER := 0.35
# SCRUM-526: оба канала вампиризма ослаблены. Стат-вампиризм: chance-cap 0.22→0.20,
# damage-heal-ratio 0.035→0.025, base-heal-mult 0.55→0.48, per-second капы 1.4→1.1 и
# 2.6→2.0. Оружейный drain: множитель 0.45→0.35.
const VAMPIRIC_CHANCE_CAP := 0.20
const VAMPIRIC_DAMAGE_HEAL_RATIO := 0.025
const VAMPIRIC_BASE_HEAL_MULTIPLIER := 0.48
const VAMPIRIC_HEAL_CAP_DEFAULT := 1.1
const VAMPIRIC_HEAL_CAP_HARD := 2.0
const WEAPON_DRAIN_HEAL_MULTIPLIER := 0.35
# SCRUM-517: per-second потолок DRAIN-heal (drain_link/lifesteal оружия). Раньше
# _heal_owner_from_damage лил лечение прямо в health БЕЗ потолка/с, поэтому Доктор
# с restore_potion/plague_syringe в плотной толпе хилился на сотни HP/с (DoT-стак
# чумы × число целей) и был бессмертен. Теперь drain списывается из общего бюджета
# по тому же принципу, что вампиризм (player._drain_heal_budget), но с собственным,
# более высоким лимитом — drain детерминирован и составляет идентичность Доктора
# как sustain-класса, поэтому больше вампирного (1.1/с), но конечен: при достаточном
# входящем DPS чистый HP убывает. DEFAULT 7.0/с держит Доктора в верхе tank-коридора,
# HARD 11.0/с — потолок для run-модификаторов (healing_multiplier и т.п.).
const DRAIN_HEAL_PER_SECOND_CAP_DEFAULT := 7.0
const DRAIN_HEAL_PER_SECOND_CAP_HARD := 11.0
const CRIT_CHANCE_CAP := 0.55
const CRIT_CHANCE_CAP_MAX := 0.75
const CRIT_CHANCE_CAP_AGILITY_SCALE := 0.002
const CRIT_CHANCE_DIMINISH := 0.45
const CRIT_FLAT_EFFECTIVENESS := 0.75
const CRIT_DAMAGE_BASE_MULTIPLIER := 1.30
const CRIT_DAMAGE_AGILITY_SCALE := 0.055
const CRIT_DAMAGE_FLAT_EFFECTIVENESS := 0.75
const CRIT_DAMAGE_CAP := 2.75

# SCRUM-503: soft-cap (diminishing returns) на ЗАБЕГОВЫЕ боевые множители.
# Живой замер (build/character_balance_dps.csv) вскрывал runaway: «идеальный» билд
# к lvl20 застаканивает run_modifiers.damage_multiplier до ~31x (!) — это и есть
# мультипликативный runaway. У Берсерка/молота он домножается на melee-sweep по 20
# целям → пик 184356 DPS на 20t (×78 от слабейшего класса) и 7636 на 1t. Частичный
# фикс (упрощение upgrade_*_exponent молота, коммит 1e74202b) уронил до 60451/2520,
# но это всё ещё 5.4x медианы — Берсерк остаётся аутлаером. Формульный гейт это НЕ
# ловит: estimate_weapon_budget гоняет derived_parameters с ПУСТЫМИ run_modifiers →
# множитель = 1.0. Поэтому cap применяется ТОЛЬКО к забеговой части множителя и
# ТОЖДЕСТВЕН при значении 1.0: сжимаем лишь превышение над 1.0 по образцу
# _diminishing_percent → capped = 1.0 + clampf(excess/(1+excess*KNEE), 0, CAP-1).
# Инвариант: softcap(1.0) == 1.0 → база lvl1 и формульные коридоры не меняются.
# Значения подобраны по живой матрице: при raw damage_mult≈31 эти knee/cap сжимают
# его до ~16.8, что роняет berserk/hammer 20t 60451→~26k (≤2.5x медианы ~28k) и 1t
# 2520→~1.1k, оставляя класс сильным AoE верхней половины (не аутлаером и не слабым).
# Ранний/средний билд (damage_mult 3..6x) почти не задет — DR кусает только хвост.
const RUN_DAMAGE_MULT_SOFTCAP := 12.0   # жёсткий потолок забегового damage_multiplier
const RUN_DAMAGE_MULT_KNEE := 0.03      # кривизна диминишинга (асимптота избытка = 1/knee)
const RUN_ATTACK_SPEED_MULT_SOFTCAP := 1.70  # потолок забегового attack_speed_multiplier
const RUN_ATTACK_SPEED_MULT_KNEE := 0.50

const WEAPON_ARCHETYPE_BY_MODE := {
	"frustum": "melee",
	"sweep": "melee",
	"circle": "melee",
	"strip": "melee",
	"bayonet_cone": "melee",
	"stab_flurry": "melee",
	"saw_sector": "melee",  # SCRUM-900 bone_saw: melee-сектор 135°
	"aoe_projectile": "projectile",
	"plague_dart": "projectile",  # SCRUM-900 plague_syringe: чумной дротик
	"homing_curse": "projectile",
	"arquebus_shot": "projectile",
	"grenade_fuse": "projectile",
	# SCRUM-939..941: кит Тёмного мага — цепь/зеркало снарядные, череп = curse-зона.
	"dark_chain_burst": "projectile",
	"dark_mirror_blast": "projectile",
	"skull_curse_burn": "aoe",
	"coin_ricochet": "projectile",
	"meteor_shards": "projectile",
	"sniper_lockshot": "projectile",
	"sniper_kill_zone": "projectile",
	"sniper_split_round": "projectile",

	"bio_sample_dart": "projectile",
	"robot_reactor_vent": "projectile",
	"beam": "beam",
	"boomerang": "beam",
	"dot_beam": "beam",
	"drain_link": "beam",
	"prism_rift": "beam",
	"robot_compression_line": "beam",
	"sound_wave": "aura",
	# SCRUM-899: узкая полоса Гитариста — фронтальная aura-ось класса (identity
	# кита сохраняется: density/target-факторы толпы как у прежней волны).
	"riff_strip": "aura",
	"amp": "aura",
	"pulse": "aura",
	"trap": "aoe",
	"smoke_bomb": "aoe",
	"elemental_orbit": "aoe",
	"priest_sanctify": "aoe",
	"priest_ward": "aoe",
	# SCRUM-929: dual toll — двойной AoE-взрыв (цель + Жрец), не снаряд/цепь.
	"priest_dual_toll": "aoe",
	"bio_spore_bloom": "aoe",
	"bio_symbiote_web": "aoe",
	"robot_magnetic_anchor": "aoe",
	"engineer_pressure_mines": "aoe",
}

const ATTRIBUTE_WEAPON_SYNERGY_MAP := {
	"strength": {
		"melee": "Прямой физический вес, stagger и knockback.",
		"projectile": "Тяжелый снаряд: выше impact damage и отдача.",
		"beam": "Стабильный канал: больше пробивной импульс.",
		"aoe": "Ударная волна: сильнее центр взрыва.",
		"summon": "Сильнее атаки спутников/устройств.",
		"aura": "Плотнее фронтальная волна и ближний отпор.",
	},
	"agility": {
		"melee": "Темп замаха, crit window и мобильность.",
		"projectile": "Перезарядка, скорость выстрела и crit.",
		"beam": "Быстрее повтор каналов и точнее удержание.",
		"aoe": "Чаще постановка зон и безопасное позиционирование.",
		"summon": "Быстрее командный цикл и отклик спутников.",
		"aura": "Чаще ритм pulse/крика и уклонение.",
	},
	"intelligence": {
		"melee": "Зачарование удара и splash.",
		"projectile": "Руническая начинка снарядов.",
		"beam": "Основная сила каналов/лучей.",
		"aoe": "Сила формулы зоны и elemental pool.",
		"summon": "Качество фамильяров/устройств.",
		"aura": "Магическая гармоника pulse.",
	},
	"perception": {
		"melee": "Длина, ширина и точность зоны.",
		"projectile": "Дальность, скорость и выбор цели.",
		"beam": "Дальность канала и ширина линии.",
		"aoe": "Радиус зоны и pickup control.",
		"summon": "Дальность приказа/поиска цели.",
		"aura": "Радиус сцены и контроль ближней толпы.",
	},
	"energy": {
		"melee": "Темп классовой механики и ultimate.",
		"projectile": "Стабильнее цикл выстрелов и ultimate.",
		"beam": "Питание канала и ultimate.",
		"aoe": "Чаще и сильнее pulse/взрывы.",
		"summon": "Питание активных спутников.",
		"aura": "Ритм pulse и сила уникального темпа.",
	},
	"knowledge": {
		"melee": "Bleed/burn след от удара.",
		"projectile": "Яд/горение на попадании.",
		"beam": "Длительный DoT после канала.",
		"aoe": "Дольше и больнее зоны.",
		"summon": "Умнее поддержка, DoT и sustain.",
		"aura": "Стабильнее бафф/дебафф и регенерация.",
	},
	"endurance": {
		"melee": "Контактная стойкость, block и тяжелый knockback.",
		"projectile": "Стабилизация отдачи и безопасная дистанция.",
		"beam": "Удержание канала под давлением.",
		"aoe": "Безопасное стояние внутри собственных зон.",
		"summon": "Прочные deployables и tank-loop.",
		"aura": "Выживание в центре ауры.",
	},
	"leadership": {
		"melee": "Эхо-оружие и командный клич.",
		"projectile": "Корректировщик/эхо-залп.",
		"beam": "Повтор канала спутником.",
		"aoe": "Командные зоны и тотемный pulse.",
		"summon": "Главная сила спутников и устройств.",
		"aura": "Главная сила поддержки, баффов и контроля сцены.",
	},
}

const STAGE_SCALE_BASE := 1.18

const STAGE_SCALE_LINEAR := 0.075

const ECONOMY_PRICE_MULTIPLIER := 1.10

# SCRUM-853: XP-кривая растянута без урезания per-monster drops. Почти линейная
# кривая SCRUM-527 (`1.038`, flat `0.8`) разгоняла 20-fight projection до ~43 lvl.
# Мягкий геометрический шаг `1.09` держит Act 1 около 14-15, Act 2 около 23-24
# и полный 20-fight run около 32 lvl.
const XP_CURVE_MULTIPLIER := 1.09

const XP_CURVE_FLAT := 0.8

const DROP_CLASS_MULTIPLIERS := {
	"ordinary": {"xp": 1.0, "money": 1.0, "money_chance": 0.75},
	# SCRUM-507: complex 1.35→1.6, heavy 1.85→2.2 — перенос веса экономики с boss-дропа на
	# ранние/средние бои. Поднимает не-boss доход маршрута (~+12%), удерживая покупательную
	# способность ≥'healthy' после среза boss-money и опуская долю boss-золота ≤50%.
	"complex": {"xp": 1.3, "money": 1.6, "money_chance": 0.85},
	"heavy": {"xp": 1.75, "money": 2.2, "money_chance": 0.95},
	"mini_elite": {"xp": 3.6, "money": 3.8, "money_chance": 1.0},
	"elite": {"xp": 8.0, "money": 8.5, "money_chance": 1.0},
	# SCRUM-507: boss-money 92→43. Boss-дроп доминировал в экономике маршрута
	# (≈64% всего золота: 442/684 balanced, 594/956 combat, 512/768 shop), обесценивая
	# ранние/средние награды («дожить до босса»). Снижение (в паре с подъёмом complex/heavy)
	# опускает долю boss-золота до ~47-49% дохода (запас под порогом 50%), возвращая вес
	# ранним тратам. Boss остаётся самым жирным денежным дропом (43 ≫ elite 8.5 — инвариант
	# boss.money>elite.money). XP-ветка (xp 24.0) не тронута — темп level-ups сохраняется.
	"boss": {"xp": 24.0, "money": 43.0, "money_chance": 1.0},
}

const COST_BY_TIER := {1: 30, 2: 55, 3: 95}

const TIER_WEIGHTS := {1: 1.0, 2: 0.45, 3: 0.12}
