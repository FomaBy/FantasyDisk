# Progression And Balance

Обновлено: 2026-07-04 (0.2.1 rebalance wave)

Source of truth для чисел: `scripts/progression_data.gd` (фасад) + доменные файлы данных `scripts/progression_data_characters.gd`, `progression_data_weapons.gd`, `progression_data_content.gd`, `progression_data_shop.gd`, `progression_data_ascension.gd`, `progression_data_enemies.gd` (доменный сплит SCRUM-198 — фасад реэкспортит их как const, публичный API сохранён), `scripts/stat_formulas.gd`, `docs/design/mechanics_extract.md`. Балансовый аудит: `docs/design/reviews/mechanics_balance_audit_2026_06.md`.

## SCRUM-504 / SCRUM-506 Balance Batch (2026-06-28)

Combined backend balance pass `backend-codex-balance-504-506` tuned class solo ceilings and summon floor stability in `scripts/progression_data_balance.gd` and balance tests.

Final regenerated `build/character_balance_dps.csv` evidence:
- Best-weapon `lvl20_ideal_1t` spread excluding berserk is **1.980x** (min `dark_mage/dark_wand` 249.78, max `assassin/chakrams` 494.65), satisfying the SCRUM-504 <=2.0x gate.
- Target classes are above the 0.75x median floor and out of the bottom four: `guitarist` 278.69, `priest` 269.21, `robot` 268.68, `druid` 274.22.
- Random-build best spreads are stable: `lvl20_random_1t` 1.620x and `lvl20_random_20t` 2.193x.
- `summon_weapon_crowd_floor_test.gd` now uses deterministic budget estimates for the three summon/deploy floor checks: druid amulet 129.8/621.7, chemist homunculus 194.2/611.6, engineer sentry 139.7/648.5 (lvl1/lvl20 ideal 20t).

### Damage re-eval (SCRUM-782, 2026-06-30)

Дочерний damage-пасс волны пересмотра баланса (по `balance_reeval_2026_06.md`).
Свежий замер подтвердил: **damage-ось всё ещё удовлетворяет всем AC SCRUM-782 на
тюнинге SCRUM-504/506** — дополнительные правки баланс-значений НЕ вносились
(нет out-of-band метрики, и они риск-регрессивны на срезо-зависимом разбросе).

AC-проверка (все выполнены тюнингом 504/506, см. числа выше):
- best-weapon `lvl20_ideal_1t` spread без berserk = **1.980x ≤ 2.0x** (min
  dark_mage/dark_wand 249.78, max assassin/chakrams 494.65). На пределе band, но в нём.
- Целевые классы выше 0.75x пола, вне нижней четвёрки (guitarist 278.69, priest
  269.21, robot 268.68, druid 274.22).
- random-build spreads не ухудшены (`lvl20_random_1t` 1.620x, `lvl20_random_20t` 2.193x).
- summon/deploy floor стабилен — свежий `summon_weapon_crowd_floor_test` дал те же
  числа: druid/summon_amulet 129.8/621.7, chemist/homunculus_vial 194.2/611.6,
  engineer/sentry 139.7/648.5 (lvl1/lvl20 ideal 20t).

Свежие гейты (tools/godot_gate.py, Godot 4.7) — все PASS: global_damage_balance_smoke
(combined ±25%, solo ±20%, worst CCT doctor/restore_potion/20 +22%),
class_damage_table_3variants (lvl20-optimum в коридоре 0.90–1.10 → кросс-классовый
spread ≈1.22x), summon_weapon_crowd_floor, berserk_dps_runaway (20t=2194≤3600,
1t=484≤650). character_balance_csv НЕ гонялся (SIGABRT-флейк; 1.980x — из
committed-evidence 504/506).

**Известная структурная хрупкость (НЕ AC SCRUM-782, отложена):** budget-tuning
форсирует output к таргету, поэтому ~16/51 пар уперты в budget-cap 2.800 (сырьё
слишком слабое, нет запаса вниз), а summon/DoT-over-hitters душатся до mult 0.28–0.62
(druid/summon_amulet raw +2344%, chemist/homunculus +719%). Это **идентичностная**, а
не output-spread проблема — output-ось уже в band. Безопасный путь (для будущего
пасса с рабочим арбитром): output-нейтральный подъём сырья cap-pinned оружия +
смягчение over-hitter-формул тиков/призывов, с проверкой ре-нормировки в Python и
полно-билдового CSV. Текущий CSV-арбитр (`character_balance_csv.gd`) SIGABRT-нестабилен
под нагрузкой и не верифицирует срезо-зависимые выбросы — поэтому форс-ретюн здесь
повторил бы блокер SCRUM-504/505/506/544 (PM-решение). Без верифицируемого арбитра
правки не вносятся.

Tuning notes (наследие 504/506):
- `guitarist` keeps AoE/control identity but uses a fairer solo target. SCRUM-899
  перевёл кит на magic-caster формы (узкий `riff_strip`, большое кайт-кольцо баса,
  амп-турели с правилами Лидерство=число+uptime / summon_amount=темп) — бюджет-зеркало
  `riff_strip` добавлено в `_budget_hit_model` (archetype `aura`, толпа ~2.3 цели из 5
  против ~4 у прежней широкой волны: узость — осознанная цена частых хитов). Trait
  «Разогрев» (SCRUM-1006, до +20% магии при no-hit) в формульный бюджет НЕ зашит —
  условный кайт-бонус, прецедент «Тёмного распада» (SCRUM-1007): формульный гейт
  меряет устойчивую базу, condition-бонусы отражает live-плейтест.
- `priest`, `robot`, and `knight` receive moderate solo/lvl20 growth support without breaching the class-kit 0.90..1.10 corridor.
- `assassin` retains solo-class identity but loses the excessive lvl20 growth tail that was driving the non-berserk solo spread.
- Headless scene-based checks may fall back to deterministic budget estimates when Player/Enemy scripts are unavailable because of resource import/cache noise; formula and registry gates still cover all 51 class/weapon pairs.

## Base Stats

Поддерживаемые базовые характеристики:

- Strength / Сила;
- Agility / Ловкость;
- Intelligence / Интеллект;
- Perception / Восприятие;
- Energy / Энергия;
- Knowledge / Знание;
- Endurance / Выносливость;
- Leadership / Лидерство.

### Survivability re-eval (SCRUM-783, 2026-06-30)

Дочерний survivability-пасс волны пересмотра баланса (по `balance_reeval_2026_06.md`).
Аудит зафиксировал EHP-разброс **5.9x** (floor dark_mage 34.6, ceiling knight 203/
robot 185) — dark_mage умирал почти от одного касания (0.39x медианы ~88).

Правка (только survivability-параметр, `progression_data_characters.gd::BASE_STATS`):
- **dark_mage `endurance` 2.0 → 3.0**: EHP **34.6 → 50.4** (before→after, замер
  `balance_harness`), теперь на уровне aoe-стекла elementalist 50.8 / chemist 51.2.
  Остаётся самым хрупким aoe-классом (по-прежнему «glass cannon», 224 DPS 5T), но не
  one-touch-truп. survival-tier «fragile» и damage-таргеты НЕ затронуты (это отдельный
  hardcoded label в `CLASS_BUDGET_PROFILES`, не производное от endurance).

Итог: EHP-spread **5.9x → 4.03x** (50.4 .. 203.3); dark_mage floor 0.39x → 0.57x медианы.

**Танк-потолок (knight 203 / robot 185) ОСТАВЛЕН без правки — осознанно:** пробный
trim endurance 10→9 нарушал damage-коридор `class_damage_table` (lvl20-optimum
relative_score 1.103/1.105 > 1.10) — survivability-стат связан с damage-метрикой
(срезо-зависимость, тот же класс блокеров 504/505/506/544). Танки при 185–203 EHP не
«бессмертны» (survivability-гейт: TTD ≤ 600с, митигация < 98%), потолок — их роль.
Trim танк-потолка отложен в совместный damage+survivability пасс с ре-деривацией
коридора (нельзя сделать изолированно в этом тикете без поломки соседнего гейта).

Гейты (все PASS): global_survivability_balance_smoke, survivability_scenario (формула
EHP == боевой take_damage), comfort_band_cross_class (spread 1.13x — НЕ ухудшен),
contact_damage_softcap, class_damage_table_3variants (коридор восстановлен),
global_damage_balance_smoke, runtime_smoke_test.

## Derived Parameters

Активные derived parameters:

- Damage;
- Magic Damage;
- Sound Wave Damage;
- Attack Speed;
- Crit Chance;
- Crit Damage Multiplier;
- Move Speed;
- Dodge;
- Defense;
- HealthPoint;
- Attack Range;
- AoE Radius;
- Pickup Radius;
- DoT / projectile / aura / buff / knockback / summon parameters.

Формулы могут быть упрощены относительно исходной таблицы, но направление влияния должно совпадать с `mechanics_extract.md`.

## Universal Attribute Usefulness

С 2026-06-12 старая модель скрытия «нерелевантных» атрибутов отключена. `ProgressionData.is_stat_relevant()` и `is_reward_relevant()` возвращают `true`, поэтому level-up, докачка за золото, артефакты, магазин, кодекс и Escape stats могут показывать любой stat/derived parameter любому классу.

Если эффект тематически «чужой», он применяется через class interpretation:
- Intelligence / Magic Damage: зачарование оружия, магический splash или резонанс;
- Leadership / Summon Amount: эхо-оружие, фантом, сокол, знаменосец, фамильяр или прямые pet-команды;
- Sound Wave Damage / Aura Radius: боевой клич и ближний контроль пространства;
- Knowledge / DoT Damage / DoT Speed: малый bleed/burn/poison след на ударах;
- Energy / Ultimate Power: ускорение уникального class mechanic cooldown/charge;
- Strength / Damage: физическая весомость, knockback и прямой урон.

UI обязан показывать эти интерпретации текстом в level-up cards, attribute-upgrade tooltips, artifact notes, shop/HUD/pause tooltips и кодексе. Старые пометки «Не работает на текущем классе» и «Работает вполсилы» больше не используются.

### Attribute Relevance Matrix (SCRUM-695)

Для прокачиваемых боевых атрибутов level-up введён ПРЯМОЙ источник правды
вместо косвенного расчёта через 8 базовых характеристик:

- `CharacterData.ATTRIBUTE_REGISTRY` — каноничный реестр 24 атрибутов
  (`id`, `name`, `icon`-папка, `value_type`). На него ссылается каждый
  `LEVEL_UP_REWARDS` через поле `attr`; иконки атрибутов лежат в
  `docs/design/references/icons/attributes/<icon>/`.
- `CharacterData.ATTRIBUTE_RELEVANCE` — матрица (атрибут × 17 классов) со
  значениями `primary`/`secondary`/`optional`. **Жёсткий инвариант по каждому
  атрибуту: ровно 2 primary, 8 secondary, 7 optional** (2+8+7=17), проверяется
  `tests/attribute_relevance_test.gd` — любое нарушение валит data-гейт.
  `optional` выводится как «все остальные классы». При 24 атрибутах per-class
  выходит ~2-3 primary / 10-12 secondary / 9-12 optional (идеально ровный
  per-class расклад достижим только при N, кратном 17; здесь сознательно
  сохранён полный набор атрибутов вместо консолидации до 17, чтобы не убирать
  игровые варианты прокачки — per-attribute правило 2/8/7 выполнено при любом N).
- `attribute_relevance(attr, class)` и `attribute_relevance_weight(attr, class)`
  читают матрицу напрямую; `level_up_reward_weight` весит награды от
  релевантности (primary 2.4 > secondary 1.0 >> optional 0.4, optional держится
  выше 0.3, чтобы атрибут не выпадал из пула). `ATTRIBUTE_PRIORITIES` (8 базовых
  характеристик) остаётся для редкого main-stat слота и pause-stats tooltips.
- Правило показа набора (`ProgressionData.weighted_level_up_selection`,
  делегируется из `ui_screens._random_level_up_rewards`): в одном показе из 3
  вариантов **не более 1** `optional`-атрибута и **всегда минимум 1**
  primary/secondary; набор никогда не состоит только из необязательных. Редкий
  main-stat слот (`MAIN_STAT_SLOT_CHANCE`) и capstone «Озарение» считаются
  не-optional и правилу не противоречат.

## XP, Money And Pickups

- Враги могут дропать XP и money pickups.
- Pickup radius — улучшаемый параметр.
- HUD показывает HP/XP/money; детали билда находятся в Escape stats / rewards / tooltips.
- SCRUM-853 растянул XP-кривую без урезания per-monster drops:
  `next_xp_requirement = ceil(current_requirement * 1.09 + 0.8)`. Старый почти
  линейный шаг SCRUM-527 (`1.038 + 0.8`) разгонял 20-fight projection до
  ~42-43 уровня. SCRUM-1058 переводит проекцию на 13 боёв двух актов с финальным
  stage 16: после 6 боёв Act 1 оба контрастных профиля около level 15, в финале
  Act 2 — level 29-30. Guard: `tests/monster_xp_pressure_pacing_test.gd`.

## Act Scaling

- SCRUM-1058 runtime progression uses `current_act` (`1..2`) plus act-local `route_stage`.
- Route navigation keeps `route_stage` local to the current map (`0..8`) so each
  act can generate a fresh route and preserve existing route reachability rules.
- Economy, drops, round duration and enemy/boss scaling read
  `route_scaling_stage() = route_stage + (current_act - 1) * 8`. The offset equals
  `ROUTE_STEPS_TO_BOSS`: Act 2 stage 0 continues from the Act 1 boss budget with
  no drop/jump, while Act 2 stage 8 reaches the former final stage 16. Neither
  route rows nor combat durations are extended to compensate for the removed act.
- SCRUM-853 enemy pressure also reads `route_scaling_stage()` plus wave index and
  elapsed combat time, so Act 2 receives denser waves, tougher enemies and more
  frequent advanced mobs without changing route reachability.
- Autosave persists `current_act`, route nodes, selected route history, shop
  state and player snapshot. Continue restores Act 1/2 checkpoints with the same
  build state. Legacy `current_act=3` is migrated to the equivalent final Act 2
  checkpoint, preserving route position/build/history and persisting the normalized
  `run_act_count=2` state.

## Comfort/Pacing re-eval (SCRUM-781)

Дочерний пасс волны пересмотра баланса по оси **комфорт/pacing**, по выводам
`docs/design/reviews/balance_reeval_2026_06.md`. Итог замера: ось **здорова в
пределах locked paths этой задачи** (волны/спавн/темп, кривая ascension, drop-
экономика) — тюнинг-значения НЕ менялись, чтобы не регрессировать соседние гейты.

Свидетельства (все зелёные):
- `comfort_band_cross_class_gate`: spread **1.13x** на срезах 1/5/20t, 0 нарушений
  ±20% медианы (153 замера) — кросс-классовый комфорт-DPS уже очень узкий.
- `ascension_curve_balance_test`: кривая монотонна до L5 (hp×1.80), mini-elite-«горб»
  пик L3=0.16 → спад L5=0.03 — без провисаний и стен.
- `enemy_damage_spread_gate`: TTD-floor 0.48с, fragile TTD ≥ 1.5× окна реакции на
  стадиях 0/4/8/10, наклон сжат — недизайненных ваншотов нет.
- `live_balance_simulation_test`: 5 архетипов, 0 мягких заметок.

Темп наград/прогресса (level-up + drop-экономика) подтверждён здоровым и НЕ
инфлирован: 24 level-up-карты (data-driven, выбор 1 из 3), START_BOONS в пределах
+10% боевой силы (`start_boons_test`), shop/артефакты с трейд-офф-модами.

Wave-density-комфорт («динамичный бой с первой секунды») доставлен отдельно в
SCRUM-784 (WAVE_SETTINGS/`_choose_wave_spawn_edges` в main.gd/combat_director.gd —
другой контур, вне locked paths этой задачи).

**Отложено в damage-пасс (вне scope комфорта):** 4 crowd-clear-лаггера +20–22% на
20-врагах (doctor/restore_potion, druid/summon_amulet, druid/raven_totem,
chemist/homunculus_vial) — это **per-weapon** свойство (растекание/задержка
призыва), а не pacing/curve/economy; правится в damage-пассе (`class_weapon`/
weapon-числа), а не здесь, чтобы не пересекать damage-числа.

## Level-Up

- При достижении XP открывается выбор 1 из 3 reward cards.
- Бой ставится на паузу до выбора.
- Rewards меняют производные параметры сразу.
- Level-up UI использует icon mapping через `UIIconRegistry`.
- Level-up pool включает прямые карточки для основных derived parameters: crit, dodge, range, DoT, projectile speed, aura, buff, summon, absorb, regeneration, vampirism и ultimate scaling.
- SCRUM-854/SCRUM-862: Doctor is the explicit exception to the universal sustain pool: `ProgressionData.is_reward_relevant()` and boss-completion artifact selection filter Doctor out of external regeneration/vampirism/lifesteal rewards in level-up, artifact reward pool, shop, elite artifact choices, boss completion rewards, and start boons. Doctor sustain remains only on his own weapons (`restore_potion`, `plague_syringe`, `bone_saw`) and their drain caps.
- SCRUM-894 (заменяет kill-growth SCRUM-860): Shadow Momentum удалён из данных — kill-стаки Ассасину больше не положены (гейт `tests/kill_scaling_identity_test.gd`). Темп-наградой стал «Рывок темпа» Теневых кинжалов: `flurry_tempo_*` в конфиге оружия, триггер — серия, задевшая врага; короткий бафф скорости и уворота с внутренним кулдауном (аптайм ≤ duration/cooldown), без лечения, чистится при смене оружия. Sustain-ленты Doctor/Priest/Knight не тронуты.
- SCRUM-894 крит-профиль per-class: `ProgressionData.class_crit_profile` читает `CLASS_TRAITS` — Ассасин («Хладнокровие») имеет кап шанса крита 1.0 (глобальный `CRIT_CHANCE_CAP` 0.55 у остальных), diminishing 0.0 и overflow 0.5 (избыток raw-шанса сверх капа → `crit_damage_flat`; итог всё равно зажат `CRIT_DAMAGE_CAP` 2.75 — runaway исключён). Уворот: «Теневая завеса» добавляет ситуативный dodge-бонус (`buff_power`-скейл, кап `veil_dodge_cap`) только под ближним прессингом, суммарный уворот ≤ `SURVIVABILITY_DODGE_CAP` 0.55 — гейт бессмертия (`global_survivability_balance_smoke`) не ослаблен.
- SCRUM-900 закрепляет это как data-driven trait «Клятва чумного доктора» (`CLASS_TRAITS.doctor.generic_sustain_blocked`) с ЧЕТЫРЬМЯ точками отсечки: (1) пул-фильтр выше; (2) применение — `Player._apply_reward_mods` и `apply_meta_skill_modifiers` молча гасят запрещённые sustain-ключи (`ProgressionData.is_blocked_sustain_mod_key`: `regeneration_flat`, `vampiric_*`, `kill_heal_percent`, `room_clear_heal_percent`, `kill_streak_heal_every`, `lowhp_regen_bonus`, `heal_percent`) — даже принудительно применённая награда/мета-звезда остаётся no-op; (3) формула — `derived_parameters` отрезает БАЗОВЫЙ пассивный реген (константа + knowledge-скейл) через `_class_gated_regeneration`; (4) рантайм-страховка — `_apply_regeneration` не добавляет `lowhp_regen_bonus`. Явная пометка `doctor_friendly: true` на предмете пропускает его и в пул, и в применение (моды ложатся в обычные run-ключи и работают штатными формулами). Route/rest/shop-лечение вне `apply_reward` (аптечки-пикапы, отдых на маршруте) сознательно НЕ блокируется — отсекается именно комбат/билд-сустейн. Гейт: `tests/doctor_kit_test.gd`.
- SCRUM-860: kill-growth is a tempo hook, not generic sustain. `assassin/shadow_daggers` and `assassin/venom_wire` define `kill_growth_role = "shadow_momentum"`; normal non-boss/non-elite kills add/refresh up to 6 stacks for 6 seconds, capped at +12% attack speed and +9% crit damage through `kill_momentum_*` run modifiers. The hook never heals and clears on expiry or weapon swap, while Doctor/Priest/Knight sustain stays on their own drain, prayer/ward, and block/counter lanes.
- SCRUM-683 выводит видимый effect-preview прямо на reward card, а не только в
  tooltip. Для базовых характеристик preview строится от текущего snapshot
  статов и `STAT_DERIVED_PREVIEW` / `ProgressionData.derived_parameters()`;
  для direct modifier rewards runtime применяет модификаторы к копии активных
  modifiers и сравнивает before/after derived parameters активного героя и
  оружия. Поэтому числа в карточке берутся из текущих формул баланса и не
  дублируются hardcoded UI-текстом.

## Artifacts

- SCRUM-960: универсальный пул = **32 семьи с роллом редкости** (`rarity_scaling: true`)
  + 37 сохранённых плоских записей. Полный контракт значений —
  `docs/design/systems/artifact_system_matrix.md` (§1-2), реестр — `content_registry.md`.
- **Тир-канон:** tier 1 = обычный (cost 30), tier 2 = редкий (cost 55),
  tier 3 = эпический (cost 95); `COST_BY_TIER`/`TIER_WEIGHTS` в
  `progression_data_balance.gd`. Отдельного поля `rarity` нет — tier и есть редкость.
- **Модель семьи:** запись несёт `tiers {1,2,3}` (description + stats|mods на тир);
  корень записи = т1-база (tier/cost/description/stats|mods зеркалят `tiers[1]`)
  для legacy-читателей (`artifact_definition`, кодекс, балансовые тулзы).
- **Ролл на выдаче (offer-time):** сэмплер, встретив семью, роллит тир и
  материализует оффер `ProgressionData.materialize_family_offer(family, tier)`
  → плоская запись `{id, title, tier, cost=COST_BY_TIER[tier], description,
  stats|mods, rarity_scaling}`; дальше пайплайн (карточки, магазин, `apply_reward`)
  работает без изменений. Вес самой семьи в пуле = 1.0.
- **Распределение ролла:** `reward_pool`/`shop_items`/события — нормализованные
  `TIER_WEIGHTS` (≈ 0.64/0.29/0.08); элитка/сундук (`elite_artifact_choices`) —
  `TIER_WEIGHTS × depth_weight` (глубже по маршруту — чаще т2/т3);
  босс (`boss_completion_*`) — семьи фиксированно тиром 3.
- **Единое правило скейла семьи (§1.2):** базовый стат +2/+4/+7; процентный
  атрибут ×1.10/×1.18/×1.30; долевой флет +0.10/+0.18/+0.30; плоский флет
  ≈0.75×/1.25×/2.0× значения level-up карточки. Ключ эффекта семьи = ключ
  level-up карточки атрибута. Гейт: `tests/artifact_family_roll_test.gd`.
- `player.artifacts` хранит `{id, title[, tier]}` с совместимостью со старым
  title-only форматом; `tier` пишется из материализованного оффера (SCRUM-960),
  старые записи без tier валидны (читатели берут `.get("tier", 0)`).
- **Классовые артефакты (SCRUM-961):** 85 записей (по 5 на каждый из 17 классов,
  `class_affinity=[класс]`, `requires_ascension: 5`) заперты гейтом
  `is_reward_relevant(reward, character_id, ascension_level, cross_class_ids)`
  (matrix §1.4) во всех сэмплерах: `reward_pool` / `shop_items` /
  `elite_artifact_choices` / `boss_completion_*`. Возвышение — **метовое**
  (макс. достигнутый уровень класса, `main.ascension_level_for`), не выбранное
  на забег: до Возвышения 5 классовые не выпадают вообще; чужому классу — никогда.
  Тиры кита: 3×т2 + 2×т3 (Химик: т1+т2+3×т3), неформальная сумма силы 12 у всех.
  Гейты: `tests/artifact_ascension_gate_test.gd`, `tests/class_artifacts_test.gd`.
- **Cross-class исключение (§5):** единственное — `stolen_crest` (Вор, т3). При
  получении `player.apply_reward` роллит 2 случайных ЧУЖИХ классовых id
  (равновероятно, без дублей) в `run_modifiers["cross_class_artifact_ids"]`
  (Array, напрямую — мимо float-коэрции `_apply_reward_mods`); сэмплеры пропускают
  ровно эти id сквозь гейт до конца забега. Анти-runaway капы классовых механик
  (§8.4): duplicate_hit ≤ 0.65 суммарно, take_hit_pulse клампится ≤ 1.0, спреды
  DoT extend-режимом без рекурсии, взрывы (wand/mirror/twin bell) не порождают
  новых взрывов, стаки капятся (rage 5, acid 5, мины 5, капканы 4, resonance 3).
- HUD показывает artifact icons в `ArtifactHudRow`.
- Pause stats menu имеет отдельный блок «Артефакты».
- Artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png`
  (пак SCRUM-962: 154 боевые иконки — семьи, сохранённые и все 85 классовых).
- `affinity_mods` в данных больше не используются (SCRUM-961: гейт на выдаче, эффекты — обычные stats/mods/триггеры); код-путь в `player.gd` остаётся legacy no-op для старых сейвов.
- SCRUM-606 adds five tier-2/cost55 active artifacts on existing hooks:
  `field_kit` (`room_clear_heal_percent`), `vital_siphon` (`kill_heal_percent`),
  `powder_charge` (`kill_explosion_chance`), `bulwark_echo` (`take_hit_pulse_chance`),
  and `duelist_spur` (`crit_speed_burst`).
- SCRUM-609 adds five tier-2/cost55 passive curse relics with explicit upside/downside:
  `sacrifice_seal`, `hungry_amulet`, `berserk_totem`, `focus_lens`, and `stone_hide`.
  They use only supported runtime mod keys and are available through the normal
  reward/shop artifact paths.
- Route `chest` node (SCRUM-537) использует тот же weighted artifact sampler, что
  elite reward: `ProgressionData.elite_artifact_choices(route_scaling_stage(), 3, selected_character_id)`,
  поэтому class-specific exclusions, включая Doctor external sustain filter,
  применяются и к chest/elite-style выборам.
  Выбор всегда содержит 3 разных artifact IDs, выбранный артефакт применяется к
  run snapshot через общий reward path, затем маршрут продвигается на следующий row.

## Summon Scaling

- `summon_amount = Leadership + Knowledge * 0.18 + Intelligence * 0.12 + Energy * 0.10`.
- Мобильные summons используют `SummonerWeapon._summon_profile()`:
  - damage = base derived damage * `summon_damage_multiplier` * role multiplier * Leadership multiplier `1 + min(Leadership * 0.060, 1.15)` * attribute multiplier `1 + min(summon_amount * 0.016 + Knowledge * 0.004 + Intelligence * 0.004 + Energy * 0.003, 0.40)`;
  - attack interval получает haste `min(summon_amount * 0.014 + Leadership * 0.006, 0.30)`;
  - max HP получает bulk `min(Leadership * 0.045 + summon_amount * 0.010, 0.75)`;
  - move speed/lifetime/splash radius также мягко растут от Leadership/`summon_amount`.
- SCRUM-854: runtime summon cap uses `base_max_summons + floor(Leadership / 4) + summon_bonus`; `summon_amount` continues to scale summon strength, tempo, bulk, lifetime and splash rather than the count cap. Mobile summon weapons start battle with `ceil(max_summons / 2)` owned minions and then continue summoning on their normal interval.
- **Crowd-clear scaling (SCRUM-505):** мобильные summons (`summon_amulet`, `homunculus_vial`)
  на 20-target оси были «мёртвыми слотами»: per-summon урон зажат budget-флором
  (`budget_damage_multiplier` = floor 0.28), поэтому 20t-throughput нельзя поднять через
  per-hit damage. Вместо этого `_summon_profile` множит splash-покрытие роя
  (`aoe_damage_multiplier` и `aoe_radius`) на `summon_crowd_scale = 1 + min((level-1) * 0.275, 5.20)`.
  Драйвер — `(level-1)`, а НЕ Leadership/`summon_amount`: последние равны базовому Лидерству
  на lvl1 (у друида/инженера 9-10), что раздуло бы стартовый баланс; `(level-1)` ровно 0 на
  1-м уровне → lvl1 неприкосновенен, рост идёт только по ходу забега. Покрытие splash —
  чисто рантайм-величина: budget-формула (`_budget_summon_dps`/role/haste) его НЕ моделирует,
  поэтому инвариант «runtime == budget» по per-summon DPS сохраняется.
- `summon_amulet`, `homunculus_vial` и `engineer_sentry_wrench` дополнительно используют
  `upgrade_damage_exponent` как lvl20-only рычаг: при пустых `run_modifiers` множитель урона
  остаётся 1.0, поэтому lvl1 baseline не меняется, а DPS-карты/артефакты сильнее оживляют
  профильную summon-ось к концу забега.
- `engineer_sentry_wrench` — НЕ pure-summon (прямая турель `engineer_sentry_link` в
  `class_weapon.gd`, не `_summon_profile`): его 20t-покрытие поднято данными (больше
  турелей `max_summons`, шотов `projectile_count` по разным ближайшим целям, быстрее пульс,
  мягче `damage_falloff`) плюс `upgrade_damage_exponent`, чтобы рост был lvl20/progression,
  а не flat-buff на старте.
- SCRUM-859 caps ClassWeapon deploy counts after Leadership scaling: `sound_amp` and
  `raven_totem` cap at 3 active devices; `engineer_sentry_wrench` после SCRUM-905 держит
  предел парка `max_summons 2 + floor(summon_amount/4)` с рельсом `max_summons_cap 6`
  (+«Полевой чертеж» поверх рельса), при полном парке деплой пропускается.
  Engineer sentry also gets small `sentry_splash_*` knobs
  (`82px`, x0.24, cap 3) so turret gameplay clears crowds without turning every beam
  into an uncapped AoE.
- **SCRUM-905..908 бюджет-зеркала кита Инженера** (все — статические функции
  `progression_data.gd`, зеркалят рантайм 1:1, покрыты `tests/engineer_kit_test.gd`):
  - `_budget_sentry_ammo_model` — sustain турелей ограничен боезапасом: throughput =
    `min(спрос парка (capacity/pulse), supply (magazine/деплой))`; attack_speed ускоряет и
    пульс, и расход магазина (турели исчезают быстрее, AC SCRUM-905); AoE-срез добирается
    залпом по разным целям (`volley_quality`) и capped-сплэшем.
  - `_budget_orbit_drone_dps` — контактный DPS дронов: `число дронов × урон контакта ×
    min(обороты/с (drone_orbit_speed × attack_speed / TAU), 1/drone_hit_cooldown)`;
    FAN-1075 задаёт базу 2 дрона на общем антиподальном кольце 121 px (+55% к 78),
    рельс 6; спираль начинается с третьего дрона. FAN-1101 укрупняет тело дрона:
    visual scale 0.36 (+50% к 0.24) и контакт 66 px (+50% к 44) — тюнер сам
    компенсирует более широкое кольцо покрытия, суммарный AoE-бюджет держится.
    Покрытие толпы — `clamp(1 + (внешний радиус кольца/спирали + контакт)/58, 1, 5)`.
  - `_budget_network_factor` — фактор trait'а «Сеть мастерской»: ожидаемые стеки в
    устойчивом бою (турели — min(парк, жизнь магазина/деплой); дроны — постоянный парк;
    мины — кап × вес 0.5 × заполненность 0.33), кламп капом сети
    `network_stack_cap_base 3 + floor(Лидерство/6)`, +6% урона устройств за стек; у классов
    без trait'а фактор ровно 1.0 (не течёт).
  - Мины SCRUM-907: урон пары поднят против старой веерной тройки (скаляр 0.96 → 3.60),
    тюнер кита в коридоре без клампов; персистентность не даёт uncapped-силы благодаря
    `mine_active_cap 6` и пониженному весу мин в сети.
- Уровень 0 сохраняет базовый баланс: все множители начинаются с 1.0, caps ограничивают high-stat runaway.
- **Принцип «summon не дед-слот» (SCRUM-505, согласован с comfort-полосой SCRUM-544/546):**
  цель — поднять каждое summon-оружие минимум к **0.5x профильной summon-медианы** на 20t-оси
  и далее в comfort-полосу своего среза (а не к буквальным 0.5x класс-лучшего из исходной
  спеки: у chemist/engineer класс-лучший — экстремальный outlier 17x/5.9x медианы, и 0.5x
  от него сломал бы полосу). Live-арбитр — `tools/character_balance_csv.gd`; когда он
  недоступен (SIGABRT под нагрузкой), регресс-гейт — детерминированный
  `tests/summon_weapon_crowd_floor_test.gd` (lvl20-подъём + lvl1-инвариант на реальном бою).
- Balance facade `ProgressionData.estimate_weapon_budget()` использует ту же damage/haste формулу для summon DPS estimate, чтобы отчеты 0.1.5 не считали старую слабую версию призывателей.

## Shop

- Shop items берутся из `ProgressionData.SHOP_ITEMS` и artifact pool.
- `ProgressionData.shop_items(route_stage, character_id)` optionally filters class-specific forbidden rewards; UI passes `selected_character_id`, so Doctor does not see external sustain items in shop rolls.
- Каждая generated route map содержит ровно два `shop` узла: один в первой
  половине non-boss рядов и один во второй половине. Placement задаёт только
  доступность магазина на маршруте; цены, ассортимент, скидки и EV событий не
  меняются этим правилом.
- Shop screen показывает 4 предложения на parchment wall.
- Покупка проверяет money, купленные items получают unavailable state.
- Сток привязан к конкретному `shop` route node: выход из лавки не очищает
  stock и не двигает маршрут, поэтому магазин можно открыть повторно до выбора
  следующего route node. Следующий route node финализирует прошлый магазин и
  очищает его stock/purchased state.
- Shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`.

## Random Events EV (SCRUM-995)

Стартовый пак — ровно **12 полированных событий × 3 выбора**
(`scripts/event_data.gd`; применение — `ui_screens._apply_event_choice_resolved/`
`_resolve_event_choice_outcome`, reveal-шаг и event-магазин — SCRUM-996,
наградные множители боя — `combat_director._grant_combat_completion_rewards`).
id закреплены (фоны SCRUM-998, UI SCRUM-997); `sudden_fork`/`sacrifice_altar`
дополнительно штампуются узлами hazard/altar (`route_map_screen.gd`). Легаси-пул
из 29 событий удалён и не выбирается.

**Принцип:** у каждого события 3 различимых интента (безопасный / рискованный /
умный-чековый либо моральная альтернатива). EV-инвариант «риск ≥ безопасно» в
золото-эквиваленте держит `tests/event_risk_reward_ev_test.gd`; апсайд-инвариант
«рисковое/платное не слабее бесплатного» — `tests/event_data_smoke_test.gd`.
Рисковые опции платят статами/артефактами/модами (их ценность растёт с
экономикой), безопасные — мелким золотом/хилом.

**Модель (gold-value, GV)** — зеркало `event_risk_reward_ev_test.gd`
(SCRUM-995 расширил её ключами SCRUM-996): 1 стат = 14; артефакт = 28; хил =
30×доля (кап 50%); −HP = −30×доля; `damage_flat` = −0.3/HP; %-мод = 1.5/1%;
`summon_bonus` = 14; `defense_flat` = 150×значение; `enemy_health_multiplier`
как проклятие = −40×(m−1); событийный магазин: `shop_after` = +8,
`shop_discount` = +50×скидка; бой = 20×money_mult + 10×xp_mult − (6 battle /
12 elite + 40×(ehm−1)) + post_combat (только stats/mods/heal/shop — контракт);
чек = 0.6×успех + 0.4×провал; random_outcomes — среднее.

| Событие / выбор | Механика | Цена / риск | Награда | EV (GV) | Риск |
| --- | --- | --- | --- | --- | --- |
| caravan_bandits / defend_caravan | бой 1.15, зол ×1.3 | бой с бандитами | +1 Лид, лавка торговца со скидкой 25% | +58.5 | high |
| caravan_bandits / join_bandits | бой 1.22, зол ×1.75, xp ×1.2 | бой с охраной; дурная слава | +1 Сила; проклятие +6% HP врагов | +43.8 | high |
| caravan_bandits / rob_and_run | чек Лов 7 | провал: 10 урона + бой 1.15 | успех: +45 зол без боя | +34.6 | high |
| sudden_fork / safe_detour | безопасно | — | +12 зол, хил 15% | +16.5 | low |
| sudden_fork / risky_shortcut | бой 1.16, зол ×1.5 | бой в теснине | +1 Сила, +6% урона | +50.6 | high |
| sudden_fork / scout_ahead | чек Воспр 6 | провал: −10% HP | успех: +16 зол, +1 Воспр | +16.8 | mid |
| sacrifice_altar / offer_blood | платно (HP) | −18% макс. HP | навсегда +2 Сила, +8% урона | +34.6 | mid |
| sacrifice_altar / offer_flesh | платно (HP) | −28% макс. HP | навсегда +2 Лов, +12% скор. атаки | +37.6 | mid |
| sacrifice_altar / offer_gold | платно | −26 зол | навсегда +1 Вынос, +1 Энергия, +4% защиты | +8.0 | low |
| night_market / pay_entry | платно → магазин | −20 зол | event-магазин (ценность в GV консервативна) | −12.0 | low |
| night_market / find_gap | чек Воспр 7 | провал: 8 урона | успех: +12 зол, магазин со скидкой 15% | +15.5 | mid |
| night_market / walk_on | безопасно | — | ничего | 0.0 | low |
| cursed_chapel / whisper_prayer | hidden, 2 исхода | урон 6 в плохом исходе | +1 Вынос + хил 20% ИЛИ +8% xp | +15.1 | mid |
| cursed_chapel / break_crypt | чек Сила 8 | провал: проклятие +5% HP врагов + бой 1.2 | успех: артефакт | +24.4 | high |
| cursed_chapel / search_nave | безопасно | — | +14 зол | +14.0 | low |
| gilded_gambler / small_bet | hidden-ставка | −10 зол | 50/50: +30 зол или ничего | +5.0 | mid |
| gilded_gambler / big_bet | hidden-ставка | −25 зол | 50/50: +75 зол или ничего | +12.5 | high |
| gilded_gambler / catch_the_hand | чек Воспр 8 | провал: 6 урона | успех: +30 зол | +17.3 | mid |
| wounded_mercenary / patch_him_up | платно (мораль) | −18 зол | +1 Лид, +1 призыв | +10.0 | low |
| wounded_mercenary / rob_him | мораль | −1 Знание | +26 зол | +12.0 | low |
| wounded_mercenary / pass_by | безопасно | — | ничего | 0.0 | low |
| stone_guardian / hold_the_gate | чек Вынос 7 | провал: бой 1.2 | успех: +1 Вынос, +6% защиты | +22.2 | high |
| stone_guardian / read_the_glyphs | чек Инт 7 | провал: бой 1.2 | успех: +1 Инт, +6% урона | +22.2 | high |
| stone_guardian / test_of_arms | чек Сила 9 | провал: бой 1.25 | успех: артефакт | +24.8 | high |
| heroes_graveyard / dig_the_grave | риск, random | 8 урона + бой 1.2 в плохом исходе | артефакт ИЛИ бой (зол ×1.35, +1 Вынос) | +31.3 | high |
| heroes_graveyard / honor_the_fallen | безопасно | — | +1 Вынос, хил 15% | +18.5 | low |
| heroes_graveyard / read_epitaphs | чек Знание 7 | провал: 6 урона | успех: +1 Знание, +6% xp | +13.1 | mid |
| old_well / toss_a_coin | hidden, 3 исхода | −6 зол | +24 зол / хил 30% / ничего | +5.0 | mid |
| old_well / draw_water | безопасно | — | хил 25% | +7.5 | low |
| old_well / dive_down | чек Лов 8 | провал: 9 урона | успех: артефакт | +15.7 | mid |
| war_drums_camp / storm_the_camp | элита 1.12, зол ×1.6, xp ×1.3 | элитный бой | +1 Сила, +1 Лид, +6% урона | +65.2 | high |
| war_drums_camp / slip_past | безопасно (цена) | −6% HP | ничего | −1.8 | low |
| war_drums_camp / cut_the_drums | чек Лов 8 | провал: 10 урона + бой 1.15 | успех: +22 зол, +6% xp | +26.2 | high |
| fallen_star / grab_the_shard | платно (HP) | −12% HP | +2 Энергия | +24.4 | mid |
| fallen_star / study_the_light | чек Инт 7 | провал: 7 урона | успех: +1 Энергия, +1 Знание | +16.0 | mid |
| fallen_star / pry_it_loose | чек Сила 8 | провал: 8 урона | успех: артефакт | +15.8 | mid |

Риск-уровни: **low** — нет проигрышного исхода (или фиксированная скромная
цена), **mid** — возможна потеря HP/золота либо ставка/чек без боя, **high** —
бой/элита (в т.ч. при провале чека) или крупная ставка.

EV-инвариант `risk ≥ safe` проверяется на 4 событиях с парой риск/безопасно:
caravan_bandits +23.9, sudden_fork +33.8, heroes_graveyard +12.8,
war_drums_camp +39.0 (0 нарушений); апсайд-инвариант smoke — на 6 событиях.
Отрицательный EV `pay_entry` — сознательный: модель ценит сам доступ к
магазину консервативно (+8 GV), фактическая ценность — ассортимент под билд.

Покрытие наград по паку: золото, статы, урон (`damage_flat`)/HP-цена, магазин
(night_market, caravan_bandits post_combat), артефакт (крипта/страж/колодец/
звезда/могила), бои battle и elite с post_combat, «ничего» при провале (ставки
шулера, глухая монета колодца). Скрытые исходы — в 3 событиях (cursed_chapel,
gilded_gambler ×2, old_well), каждый с честным `outcome_text`; difficulty
чеков 6–9; class-reactive ветвление — stone_guardian (Вынос/Инт/Сила) и
fallen_star (Инт/Сила). Гейты: `event_data_contract_check` (12 событий, 3
выбора, tags, гард post_combat), `event_data_smoke_test`,
`event_risk_reward_ev_test`, `event_outcomes_runtime_test`, `runtime_smoke`.

## Gameplay Sandbox Eligibility (SCRUM-976)

Gameplay sandbox values are not new balance data. The configured values are
copied into an immutable run snapshot, and player damage/attack speed are
applied as final exact factors after the canonical release softcaps. A neutral
snapshot (`1.0` on all five axes) remains fully eligible for achievements,
Codex, boss/Ascension/class progression and release balance evidence.

Any non-neutral snapshot is deliberately progression-ineligible. Runtime keeps
run-local XP, money, artifacts and summary metrics, but `Main` blocks the three
persistent write sinks: achievement evaluation, Codex discovery and boss/meta
victory recording. `run_metrics.sandbox` publishes the normalized snapshot and
the explicit `progression_eligible`, `achievements_eligible` and
`release_balance_evidence_eligible` flags so debug/QA reports cannot silently
mix custom runs into canonical balance evidence.

## Meta Progression

### SCRUM-1068 runtime: 3×6 weapon constellations (schema 6)

Production runtime следует contract SCRUM-1067, зафиксированному в
`docs/design/reports/scrum1067_constellation_3x6_balance_spec.md`; все 306
branch nodes, 34 hidden profiles, 51 финал и caps — в
`docs/design/data/scrum1067_weapon_finals_manifest.json`.

- Spendable sigils за first clear A0..A5: `[2,2,3,4,4,5]`, сумма 20;
  challenges раскрывают hidden, но больше не дают spendable currency.
- Полный класс: три пути `6/6` + две hidden cost1 = `20/20`, все три финала
  активны одновременно и weapon-scoped.
- Обычный boon даёт измеримый gain `≥1.08×` заявленной оси; weapon-scoped
  direct flat damage `≥10`; final даёт `≥1.20×` против того же `5/6`.
- Hidden reveal и cost-1 purchase разделены; эффект также weapon-scoped и
  проходит собственный `≥1.08×` fixture.
- Полный путь: `1.60–2.00×` своей оси; средний gain трио `1.60–1.90`.
- Class axes: идеал `±10%`; total ideal `±8%`, hard fail `±15%`; roster
  `max/min ≤1.15`.
- A5 с `20/20` не быстрее A0 baseline более чем на 15% и не создаёт
  immortality/control loop.

Обязательные harness scenarios: `no_meta`, `path_5_of_6`, `path_6_of_6`,
`three_paths_6_of_6`, `full_20_of_20`, `a5_live`. Их детерминированно проверяет
`tools/scrum1068_balance_harness.py`; production parity —
`tools/validate_scrum1068_runtime_manifest.py`. Измеренный schema-6 roster
`max/min = 1.018636`, полный A5 остаётся внутри hard anti-runaway rail.

Runtime source of truth — `data/meta/constellation_schema6.json` и typed loader
`scripts/constellation_schema6_data.gd`. `MetaProgression` выдаёт отдельный
профиль на точный `weapon_id`; `Player` заново строит его из canonical node IDs,
не доверяя сериализованным amounts/mechanics. Save schema 5 мигрирует в schema 6
один раз: Guild-покупки и progression/reveal facts сохраняются, классовые
аллокации возвращаются, excess old currency записывается только в non-combat
`legacy_mastery`, `active_keystones` удаляется.

SCRUM-1091 добавляет только presentation contract, не новую силу. Formatter
читает authoritative `effect_profile.params`, `caps`, `mechanic_id` и
`gain_over_order_5_min`; баланс/боевые потребители не копируются в UI и не
перенастраиваются. Baseline и after-gates идентичны: 51/51 пар PASS, худший
20-target CCT `+20.6%`, все 51 финал сохраняют floor `>=1.20` относительно
узла 5/6. Поэтому numeric tuning намеренно отсутствует.

- Ascension levels: 5 уровней на персонажа (SCRUM-516: лестница сжата 10→5, монстерский пресс заметно усилен — кумулятив enemy_hp_mult на L5 = 1.80, было 1.32 на L10).
- Победа над финальным боссом увеличивает ascension выбранного героя.
- Сохранение: `scripts/meta_progression.gd`, `user://fantasydisk_meta.cfg`.

### Древо умений (мета, SCRUM-726 → SCRUM-807 Skill Tree 3.0)

- Канон: `docs/design/systems/skill_tree.md`. Данные/конструктор графа вынесены в
  `scripts/meta_progression_tree_data.gd` (v3).
- **v3 (schema 4):** 192 узла, суммарная стоимость 285 при неизменном
  `META_POINTS_CAP = 100` (на 100 очков покупается ~35% графа). Ядро 7 + 8 лепестков
  (32) + 17 классовых ветвей по 9 нодов (238). У каждого класса ≥8 классовых нодов
  (5 профильных атрибутов по `ATTRIBUTE_RELEVANCE` + 2 notable + 1 уникальный
  keystone) — настоящая классовая идентичность вместо одного вектора ×скаляр.
- **Бюджет силы дерева:** аддитивный слой поверх базы; anti-runaway/comfort гейты
  НЕ прокачивают дерево, поэтому оно вне их коридоров. Реалистичный 100-очковый
  билд даёт классу ~+12–20% эффективного DPS/EHP (`damage_mult` в коридоре
  0.08..0.40, под-тест `_test_realistic_build_power_budget`); аккаунтная сила
  почти нейтральна (классовые эффекты affinity-gated).
- Миграция schema 3→4: полный респек купленных узлов, очки пересчитываются из
  возвышений (без потери).
- (историческое) Schema 3: 107 узлов, стоимость 183 — тонкая классовая идентичность
  (3 узла/класс одним вектором ×0.18/0.36/1.0).
- Атрибутные узлы (`strength_flat`, `agility_flat`, `intelligence_flat`, `perception_flat`, `energy_flat`, `knowledge_flat`, `endurance_flat`, `leadership_flat`) добавляются к базовым stats героя до `ProgressionData.derived_parameters()`.
- `class_affinity` узлы можно купить в общем графе, но их эффекты применяются только выбранному герою через `MetaProgression.skill_modifiers_for_class(meta_state, selected_character_id)`. `skill_modifiers(state)` оставлен для account-wide UI preview.
- Нейтральные capstone ядра: «Боевой раж», «Вторая жизнь», «Связи в гильдии», «Озарение». У каждого из 17 героев есть ровно один сигнатурный keystone.
- Экран древа доступен в главном меню; данные/состояние — `scripts/meta_progression.gd` (+ `meta_progression_tree_data.gd`). v3: ветвь выбранного героя в фокусе, чужие классовые ветви «спят» (затемнены). Фокусные проверки: `tests/meta_skill_tree_smoke_test.gd`, `tests/skill_tree_per_hero_test.gd`.

### Прогрессия По Классам (SCRUM-360)

- Победа над финальным боссом дополнительно увеличивает `class_boss_wins` для выбранного героя.
- `scripts/meta_progression.gd::CLASS_PROGRESSION` содержит 5 общих накопительных порогов: 1/2/4/6/9 побед этим классом.
- Пороги дают только class-scoped run modifiers (`class_damage_mult`, `class_max_health_mult`, `class_attack_speed_mult`). `Main.apply_ascension_bonuses()` передает `class_modifiers(meta_state, selected_character_id)` только текущему герою, а `Player.apply_meta_skill_modifiers()` сворачивает их в обычные `run_modifiers` поверх аккаунтного древа.
- Бонусы не протекают на другие классы: если победы есть у Берсерка, Солдат получает пустой `class_modifiers`, пока сам не победит боссов.
- Экран «Древо умений» показывает отдельный компактный раздел «Классы» для выбранного героя: число побед, открытые пороги, следующий порог и список активных бонусов.
- Персистентность использует тот же `user://fantasydisk_meta.cfg`; ключ `class_boss_wins` version-compatible и отсутствующие старые сейвы читаются как пустой прогресс.

### Патч-ноуты (SCRUM-159)

- Кнопка «Что нового» + бейдж в меню; данные — `scripts/patch_notes_data.gd`, последняя виденная версия — `last_seen_version` в `game_settings`.

### Контракт codex-открытий (SCRUM-719 аудит)

Кодекс открывается рантаймом при убийстве врага: `Main.record_codex_enemy_discovery`
выводит `content_id` и `category`, далее `MetaProgression.record_codex_discovery`
записывает его в мета-сейв. **Критично:** id, не входящий в канонический набор
(`MetaProgression._canonical_codex_ids` ← `CodexData.monsters()`), молча
отбрасывается — открытие теряется без ошибки. Источники id рантайма:

- обычные враги/элитки → `Main.CODEX_ENEMY_NAME_TO_ID[enemy_type_name]` (категория `monsters`);
- мини-элитки → meta `mini_elite_kind` = `ProgressionData.mini_elite_kinds()[].id` (категория `monsters`);
- боссы → meta `boss_id` (категория `bosses`); одноимённые записи в `CODEX_ENEMY_NAME_TO_ID`
  для боссов **вестигиальны** (босс в группе `bosses` уходит в boss-ветку и до name-map не доходит).

**Аудит-находки 0.2.0:**

- *Исправлено:* 4 мини-элитки Возвышения из SCRUM-607 (`mini_siege_rammer`,
  `mini_swarm_sniper`, `mini_plague_berserker`, `mini_void_phantom`) были добавлены в
  геймплей (`progression_data_enemies.gd::MINI_ELITE_KINDS`, анимации, roster-тест), но
  **не зеркалированы в `codex_data.gd`** — их убийство молча не открывало кодекс.
  Добавлены canonical-записи (player-facing RU title/desc — зеркало `MINI_ELITE_KINDS`).
  Кодекс монстров: 26 → 30.
- *Filed (не исправлено намеренно):* секретный босс `secret_ascension_boss`
  (`MetaProgression.SECRET_BOSS_ID`) выставляет meta `boss_id` и при убийстве зовёт
  `record_codex_discovery('bosses', ...)`, но codex-записи у него нет → открытие теряется.
  Показывать ли секретного босса в кодексе — player-facing/дизайн-решение, поэтому
  оставлено как находка, а не правка. Контракт-тест закрепляет текущую реальность и
  «покраснеет», если разрыв осознанно закроют.
- Регрессия-гейт: `tests/codex_discovery_contract_test.gd` — end-to-end сверяет, что
  каждый рантайм-источник id реально записывается метой, и что нет «мёртвых»
  codex-монстров без рантайм-пути открытия (двусторонняя сверка).

## SCRUM-896/1005 Biologist Budget Mirrors (2026-07-10)

- Dot-ось Биолога в бюджете считается по SUSTAINED-модели (bio-ветка
  `_budget_dot_dps`): биоинфекция — status-based с refresh (1 стак), перекаст
  НЕ мультиплицирует тики, поэтому устоявшийся DPS = тик
  (`dot_damage × curse_tick_multiplier`) × каденция
  (`dot_speed × curse_tick_rate`, интервал ≥0.1с), а не `ticks/каст`, как у
  tween-DoT других классов. Ось скейлится Знанием/Энергией (dot_damage,
  dot_speed), НЕ скоростью атаки; длительность `(dot_ticks+0.99)×интервал`
  перекрывает интервал каста — uptime в затяжном бою ≈1.
- Trait «Разбор образцов» (SCRUM-1005) учтён фактором
  `infected_direct_factor = 1 + (×1.20 − 1) × uptime 0.75` ТОЛЬКО на прямой
  компонент оружия с `dot_ticks>0` (не dot/pool/summon/ульта) — тюнер
  `budget_tuning_for` компенсирует кит автоматически.
- Hit-модели кита зеркалят новые механики: bloom — соло все кольца с falloff
  (0.34-модель) + `dot_targets` по радиусу; dart — линия на всю длину +
  tip-бурст + физ-фактор 1.13 (`INJECTOR_PHYSICAL_SHARE` 0.50 × базовое
  соотношение damage/magic 3/11.2), инфекция только ближайшему
  (`dot_targets` 1); web/seed — стартовый хит `seed_impact_ratio` с falloff по
  области + `dot_targets` по радиусу.
- Тюнеры кита после редизайна: линза 0.852, инъектор 1.623, семя 1.615 — все
  строго внутри коридора клампа (0.28..2.80); до редизайна семя сидело НА
  клампе 2.80 (runtime недобирал модельные цели). Targets класса пиннед:
  solo 47.69 / aoe 191.16. Comfort-гейт (`comfort_band_cross_class_gate`)
  зелёный без изменения весов.

## SCRUM-909..913 Ranger Budget Mirrors (2026-07-10, отчёт трио кита)

- Hit-модели новых режимов в `_budget_hit_model`: `moon_split_shot` — соло
  ровно 1 хит (веткам нужны соседи), толпа = 1 + `split_count` (кап 5 из 5:
  первичная + все ветки, повторных хитов нет); `storm_pierce_cone` — соло 1
  хит (дедуп на весь залп: цель у вершины не собирает несколько стрел), толпа
  = sweep-модель покрытия `1 + (cone/45°) × (range/320)` с капом 5 + пирс
  вглубь. Капкан остался на общей trap-модели (соло 1, толпа по радиусу).
- Отброс trait'а «Сторожевой лук» и паралич/кровотечение капкана в формульный
  бюджет НЕ зашиты как урон-факторы: контроль — identity-ценность (прецедент
  «Разогрева»/«Тёмного распада»: условные и контрольные бонусы меряет
  live-плейтест, формульный гейт — устойчивую базу). Кровотечение капкана
  идёт штатной dot-осью (dot_ticks в конфиге) и в бюджете уже учтено.
- Тюнеры кита после редизайна (`budget_tuning_for`): арбалет 1.416,
  лук 1.480, капкан 0.743 — все строго внутри коридора клампа (0.28..2.80),
  без сатурации (гейт-ассерт в `tests/ranger_kit_test.gd` держит полосу
  0.30..2.75). Targets класса пиннед: solo 71.76 / aoe 120.75; tuned-метрики
  сходятся к таргетам (solo 71.76..71.79, aoe 120.71..120.77 по трио).
  Runtime-ребаланс: арбалет `damage_multiplier` 1.55→1.05 (сплит 1→4 почти
  умножил AoE-выход), лук 0.88→1.55 при интервале 1.05→1.15 (дедуп залпа
  срезал двойные хиты веера), капкан 1.18→1.02 (паралич+кровотечение
  добавили контроль-ценность при том же прямом уроне).

## Balance Validation

- Формульный харнесс: `tools/balance_harness.gd` → `build/balance_report.md` (бюджеты классов `CLASS_BUDGET_PROFILES`).
- Сводная таблица урона классов SCRUM-453:
  `tools/class_damage_table_3variants.gd` → `docs/design/reports/class_damage_table_3variants.md`
  и `build/qa/scrum453/class_damage_table_3variants.csv`. Таблица покрывает
  live roster `ProgressionData.character_ids()` (17 классов / 51 оружие) по
  сценариям 1 цель, 5 целей рядом, 20 целей вокруг и трём вариантам прокачки:
  base lvl1, lvl20 optimum (greedy +19 base-stat points по class kit score) и
  lvl20 random avg (64 seeded samples, seed `45320260617`). После SCRUM-469
  таблица является контрольным гейтом для lvl20 optimum: все 17 классов должны
  держать `relative_score` в коридоре `0.90..1.10`. Аудит использует реальные
  `ProgressionData.weapon()`,
  `estimate_weapon_budget_for_stats()` и `estimate_crowd_clear_budget_for_stats()`
  с live balance values.
- SCRUM-469 нормализует рост optimum-прокачки через
  `CLASS_LEVEL_STAT_GROWTH_SCALARS`: class/stat-specific скаляры применяются
  только к очкам выше базовых статов класса перед расчётом derived-параметров.
  Base lvl1 не меняется, а три оружия класса сохраняют свои разные
  `budget_tuning`, геометрию, target-pattern и темп.
- SCRUM-503/SCRUM-602 срезали live runaway Берсерка с молотом через soft-cap
  забеговых множителей и поздние upgrade-экспоненты (`upgrade_aoe_exponent=1.08`,
  `upgrade_damage_exponent=1.05`).
- SCRUM-852 (2026-07-03) обновил геометрию Берсерка: молот стартует кругом
  150px без старого close-ring cap 115px, Radius scaling честно увеличивает круг,
  а плотные паки ограничены `circle_full_targets=4` и
  `circle_target_diminish=0.62`. Меч стал сектором 100°/350px, топор —
  сектором 180°/250px. Focused live gate
  `tests/berserk_dps_runaway_gate.gd` требует `lvl20_ideal_20t <= 3600` и
  `lvl20_ideal_1t <= 650`; проверка после dense-pack margin fix:
  20t=3427/3456, 1t=504/564 в повторных прогонах.
- Живой DPS/TTK: `tools/live_combat_harness.gd` + гейт `tests/live_balance_simulation_test.gd`.
- Выживаемость профилей: `tools/survivability_harness.gd` + гейт `tests/survivability_scenario_test.gd`.
- Применение бюджет-тюнинга на рантайме: `tests/weapon_tuning_application_test.gd`. Экономика/XP маршрута: `tools/route_economy_xp_model.gd`.
- Финальный 0.1.5 numeric audit: `tools/balance_harness.gd` также пишет `build/balance_final_audit_0_1_5.md`; `tests/global_damage_balance_smoke_test.gd` проверяет solo DPS ±20% и crowd-clear 5/10/20 ±30% для всех 51 class+weapon pairs.
- SCRUM-856 (2026-07-04) добавил class-trio identity audit:
  `docs/design/reports/full_class_rebalance_identity_audit.md`. Это
  pre-implementation baseline для SCRUM-857..860: pair-level числа зелёные, но
  audit фиксирует mechanic-first долги, скрытые `budget_damage_multiplier`
  (`2.800` cap-pinned слабое сырьё и `0.280..0.624` over-hitter clamp у
  summon/DoT/sustain weapons). Следующие class-balance задачи должны сначала
  менять форму механики, target pattern, setup/payoff, deploy ownership,
  sustain window или control value, а не начинать с множителей.
- SCRUM-857 (2026-07-04) выполнил первый projectile/chain/pierce pass:
  `soldier_grenade` damage ждёт fuse, `elementalist_meteor_core` получил
  долгий impact+shards payoff, `sniper_shatter_rounds` использует fan
  trajectories with limited pierce, `priest_chime` выбирает sustain-arc target,
  а `cursed_skull`/`dark_wand` получили damage decay. Recheck:
  `tests/projectile_chain_pierce_identity_test.gd` PASS,
  `tests/global_damage_balance_smoke_test.gd` PASS, худший CCT остался
  `doctor/restore_potion/20` +22% в пределах +/-30%.
- SCRUM-858 (2026-07-04) закрыл первый tank/melee slice class-trio rebalance:
  Knight counter стал incoming-based с radius/arc/target caps. `tower_shield`
  теперь главный guard/counter/front-control вариант, `long_spear` остается
  reach/pierce с легкой узкой ответкой, `holy_flail` держит broad circular
  control. Фокус-тест `tests/melee_unique_mechanics_test.gd` валидирует, что
  5 incoming damage через щит убивает часть 24 HP contact pack, но не бьет
  цель за спиной или вне радиуса.
- **FAN-1031 Stage 3a (2026-07-13) — системные капы (no-silent-retune).** По плану
  FAN-1030 (`docs/design/systems/balance_plan_fan1030.md`) реализованы три системных
  правки, искажавших crowd/выживание ДО пер-классовых чисел. Полный before/after —
  `build/stage3a_after_metrics_fan1031.md`.
  - **S2 boss-hazard cap.** Зоны/сламы/укусы босса были ЕДИНСТВЕННЫМ каналом урона без
    фракционного капа (контакт 20%, элитка 25%): baseline v2 `hazard фазы 4 на A5 ≈164`
    ваншотил ВСЕ 17 классов (typ HP 50–157). Введён `BOSS_HAZARD_MAX_HP_FRACTION := 0.80`
    (`progression_data_balance.gd`) + общий чокпоинт `enemy._hazard_hit(base, player)`;
    все 11 хазард-сайтов `boss.gd` переведены на него. Это НЕ ослабление гейта, а новый
    защитный кап — главный DoD-разблокиратор «каждый герой проходит A5». Гейт:
    `tests/boss_hazard_cap_gate.gd` (CAP=80%, PASSTHROUGH, E2E full-HP выживает, CONST).
  - **S1 data-driven AoE-кап (механизм).** Диминиш «полных» целей прямого AoE-взрыва
    вынесен в per-weapon данные (`ClassWeapon.aoe_full_targets/aoe_target_diminish`,
    сентинел <0 = общий `AOE_PROJECTILE_FULL_TARGETS/DIMINISH`). Нулевое изменение
    поведения для оружий без override — рычаг для среза crowd-runaway периодики ДАННЫМИ
    (не константами кода). Пер-классовая калибровка offender'ов (blast_powder 107×,
    orb_ring 44×, spore_lens 25× медианы и т.д.) — пакет 3c против v3-пересъёма.
  - **S3 restore_potion → сустейн.** Хил-склянка Доктора была #3 AoE-оружием ростера
    (68.9k DPS@20t, 15× медианы) — дефект для лечащего оружия. `aoe_full_targets=1,
    aoe_target_diminish=4.0`: осн. цель полный урон/хил, сплэш круто спадает. Проект:
    20t 68.9k→~19.5k (−72%), 5t 1410→~408, 1t 243 без изменений (solo-хил сохранён;
    сустейн упирается в drain-budget 7/с). Гейт: `doctor_kit_test._test_restore_potion_splash_cap`
    (A/B override vs default). `global_damage_balance_smoke` без изменений (кап рантаймовый,
    ортогонален формульной бюджет-модели).

- **FAN-1031 Stage 3c(a) (2026-07-13) — пул-канал data-driven кап + завершение S3
  restore_potion (no-silent-retune).** Живой v3-пересъём (интерактивная полоса, коммит
  346c0d21) показал: restore_potion 20t упал только `68.9k→52.4k (−24%)`, а не проектных
  −72%. Причина — S1 (3a) сделал per-weapon кап ТОЛЬКО для прямого AoE-взрыва, а главный
  канал crowd-runaway периодики — тик лужи (`_damage_enemies_in_pool`), прямая
  `leaves_pool`-ветка и артефактный vapor restore_potion — оставался на КОНСТАНТАХ кода.
  Полный разбор + handoff — `build/stage3c_pool_caps_fan1031.md`.
  - **Пул-канал (механизм).** Добавлены per-weapon поля
    `ClassWeapon.pool_full_targets/pool_target_diminish` (сентинел <0 → per-channel default:
    тик лужи `POOL_FULL_TARGETS/POOL_TARGET_DIMINISH`=1/1.5; прямая leaves_pool-ветка
    `POOL_PROJECTILE_FULL_TARGETS/POOL_PROJECTILE_TARGET_DIMINISH`=1/3.0). Нулевое изменение
    поведения без override — тот же сентинел-контракт, что и S1. Теперь тик лужи по толпе
    режется ДАННЫМИ, не только 1.5-константой. Гейт: `tests/pool_target_cap_gate.gd`
    (override caps rank1, сентинел-контроль = default, leaves_pool-ветка уважает override,
    CONST-guard, реальные конфиги).
  - **S3 завершение — restore_vapor.** Артефактный vapor «Восстановительного пара» лил
    `(F=2/D=1.5)` и на толпе давал ~2× throughput основного взрыва — весь vapor и был
    некапнутым хвостом −24%. Теперь vapor наследует сустейн-нишевый кап зелья
    (`aoe_full_targets/aoe_target_diminish`=1/4.0). rank0 (solo/дуо-хил) не тронут.
  - **acid_flask пул-тик.** Первичное сужение `pool_target_diminish=3.0` (был default 1.5):
    ядро пака полный тик, хвост душится — колба возвращается к area-denial. Финальная
    величина + numeric per-hit + канал персистентных `acid_charge` (status fan-out, 3c-b) —
    против живого v3-пересъёма (handoff). `global_damage_balance_smoke` без изменений (worst
    CCT +21% — кап рантаймовый).
- **FAN-1031 Stage 3c(b) (2026-07-13) — STATUS fan-out data-driven кап (no-silent-retune).**
  Третий и последний throughput-канал периодики. По живому v3 (интерактивная полоса) верхи
  crowd-runaway жили в крауд-раздаче ПЕРИОДИЧЕСКИХ СТАТУСОВ: DoT кладётся на КАЖДОГО врага в
  зоне полным тиком → на толпе ×N без диминиша. `lvl20_ideal_20t`: cursed_skull `96.9k`
  (≈21× медианы 4574, при 1t=270 — чистый крауд-DoT), spore_lens `114.5k` (≈25×),
  symbiote_seed `69.1k` (≈15×). Полный разбор + handoff — `build/stage3c_b_status_fanout_fan1031.md`.
  - **Механизм.** Добавлены per-weapon поля `ClassWeapon.status_full_targets/status_target_diminish`
    (сентинел <0 → `STATUS_FANOUT_*`, дефолт diminish `0.0` → factor==1 для ВСЕХ рангов →
    нулевое изменение поведения без override; тот же сентинел-контракт, что S1/пул). Helper
    `_status_fanout_factor(rank)` — та же формула диминиша толпы, что `_damage_enemies_in_circle_capped`.
    Проведён в 4 крауд-сайта: `_apply_skull_curse_zone` (skull_curse), `_bio_spore_pulse` и
    `_germinate_symbiote_seed` (bio_infection), `_apply_pool_contact_statuses` (acid_charge).
    Ранг = дистанция от центра каста; ближние `status_full_targets` — полный тик, хвост душится.
  - **Первичные капы (`F=4/D=1.0`).** cursed_skull, biologist_spore_lens, biologist_symbiote_seed.
    Детерминированная дельта DoT-канала: Σfactor(20t) `6.44 vs 20` = **−67.8% (≈×3.1)**;
    5t `−10%`; 1t `0%` (малый пак и identity зоны целы). Для чистого DoT (cursed_skull) это
    тесная проекция 20t (96.9k→~31k, 21×→~7× медианы); для bio-оружий (споры/семя есть и
    прямой ring/seed-урон, кап его НЕ трогает) измеренный 20t-срез будет МЕНЬШЕ −68% —
    честный live 20t за v3'-пересъёмом (как урок restore_potion −24% в 3c-a). Диминиш даёт
    макс ≈×4 БЕЗ трогания per-hit; остаток до коридора (~3× медианы) — numeric per-hit 3c-c.
  - **acid_charge.** Рычаг проведён в `_apply_pool_contact_statuses` (кап силы тика заряда
    по рангу; кап ЧИСЛА зарядов `pool_charge_cap` и детонация по стакам не тронуты), но
    acid_flask НЕ переопределён — сентинел (заряды уже пул-капнуты в 3c-a; величину
    charge-fanout калибрует v3'). Гейт: `tests/status_fanout_cap_gate.gd` (helper override/
    сентинел, интеграция skull_curse override+A/B-контроль, bio_infection factor, реальные
    конфиги, CONST-guard дефолта no-op). `global_damage_balance_smoke` без изменений (worst
    CCT +21% — кап рантаймовый, ортогонален формульной бюджет-модели).

- **FAN-1031 Stage 3c(b2) (2026-07-13) — FALLOFF/ORBIT fan-out data-driven кап (no-silent-retune).**
  Последние два helper'а прямого урона, раздававшие полный урон КАЖДОЙ цели без диминиша по
  ЧИСЛУ целей. По живому v3'' (интерактивная полоса) остаток crowd-runaway верхов (chemist
  `10.96`/crowd `34.96`, elementalist `4.89`/crowd `14.65`) НЕ двигался пул/status-капами —
  runaway жил в этих каналах. Полный разбор + handoff — `build/stage3c_b2_falloff_orbit_fan1031.md`.
  - **Уточнение каналов (важно).** Диагностика координатора «blast_powder → falloff» неточна:
    blast_powder идёт `attack_mode aoe_projectile` → `_damage_aoe_projectile_explosion` →
    `_damage_enemies_in_circle_capped`, т.е. уже НА S1-капнутом пути (щедрый дефолт 5/2.0).
    `_damage_enemies_in_circle_falloff` использует burst черепа Тёмного мага (`_fire_curse`),
    уже де-эскалированного 3c(b). Реальный некапнутый крауд fan-out верхов —
    `_elemental_square_tick` (elementalist_orb_ring): magic+phys+ожог КАЖДОМУ врагу в квадрате.
  - **Механизм.** Добавлены per-weapon поля `falloff_full_targets/falloff_target_diminish` и
    `orbit_full_targets/orbit_target_diminish` (сентинел <0 → `FALLOFF_FANOUT_*`/`ORBIT_FANOUT_*`,
    дефолт diminish `0.0` → factor==1 для ВСЕХ рангов → нулевое изменение без override; тот же
    сентинел-контракт, что S1/пул/status). Helper'ы `_falloff_fanout_factor(rank)` /
    `_orbit_fanout_factor(rank)` — единая формула диминиша толпы. Проведены: крауд-хвост
    поверх радиального спада в `_damage_enemies_in_circle_falloff`; и в тик квадрата
    `_elemental_square_tick` (ранг = дистанция к центру, порядок итерации и phase_target
    constellation НЕ тронуты — zero-collateral; magic/phys/ожог скейлятся одним factor).
  - **Override orb_ring (`orbit F=3/D=1.0`).** Чистый крауд fan-out кастомного executor'а.
    Σfactor(20t) `5.50 vs 20` = **−72.5%**; 5t `−23%`; 1t `0%` (3 ближних — полный тик, identity
    зоны цела). Проекция 20t `197.8k → ~54k` (43×→~12× медианы) — до коридора остаётся per-hit
    numeric (3c-c). Живой v3''' — за валидацией.
  - **Override blast_powder (`aoe F=4/D=3.0`, S1-поля, НЕ falloff).** Правит ГЕОМЕТРИЮ его
    прямого AoE (щедрый дефолт 5/2.0 → 4/3.0): Σfactor(20t) `6.37 vs 4.99` = **−22%**; 5t `−15%`;
    1t `0%` (пара ближних взрывов цела). Диминиш даёт макс ≈×4 — 108× медианы им одним НЕ
    закрыть; главный драйвер blast_powder — раздутый per-hit magnitude (build-стек), это 3c-c
    numeric против v3'''. Здесь только геометрия (direction гарантирован вниз).
  - **falloff-рычаг — готовый knob, НЕ переопределён нигде.** Проведён в
    `_damage_enemies_in_circle_falloff` (сентинел → нулевое изменение), отдан калибровочной
    полосе (burst черепа уже де-эскалирован 3c(b); слепой numeric без пересъёма запрещён issue).
    Аналог оставленного acid_charge-рычага в 3c(b). Гейт: `tests/orbit_falloff_cap_gate.gd`
    (helper override/сентинел обоих каналов, интеграция falloff+orbit override и A/B-контроль,
    ratio-проверка magic+phys+ожог, реальные конфиги, CONST-guard дефолтов no-op).
    `global_damage_balance_smoke` без изменений (worst CCT +21% — капы рантаймовые, ортогональны
    формульной бюджет-модели). Гейтов не ослаблял.
- **FAN-1031 Stage 3c-c (2026-07-13) — numeric down-tune перекормленных верхов + druid kit-rebuild
  (no-silent-retune).** Полный разбор + карта каналов + решение по coverage —
  `build/stage3c_c_numeric_fan1031.md`.
  - **Ключевая поправка рычага (проверено пробой `budget_tuning_for`).** Живой per-hit
    direct-канала = `damage_multiplier × budget_damage_multiplier`, где `budget_damage_multiplier`
    авто-компенсирует `damage_multiplier` до формульной цели (`solo_target·aoe_target·damage_budget`)
    с клампом `[0.28, 2.80]`. Т.е. правка `weapon.damage_multiplier` сама по себе живой DPS почти
    не двигает (кроме уже-клампнутых оружий), поэтому numeric верхов делается СДВИГОМ ЦЕЛИ ПРОФИЛЯ
    (`CLASS_BUDGET_PROFILES`), а не weapon-множителем. Сдвиг цели двигает живой per-hit по ВСЕМ
    каналам И реебейзит формульный smoke-гейт (остаётся зелёным).
  - **dark_mage** `damage_budget 1.15→0.72`, `solo_target 0.84→0.66` (solo 1.33 — сильнее всего над
    профилем 0.84). + `cursed_skull curse_tick_multiplier 0.58→0.36` (curse_only → budget-direct не
    ведёт; единственный per-hit DoT-рычаг; зеркало `_budget_dot_dps` синхронно; int-скейл 0.08 цел).
    Проекция total `1.82 → ~1.39` (solo `1.33→1.05`, aoe `2.58→1.97`, crowd `2.80→1.96`).
  - **elementalist** `damage_budget 1.08→0.88`, `solo_target 1.00→0.92`. Проекция total `3.41 → ~2.71`
    (solo `1.20→0.97`, aoe `2.02→1.58`); crowd `7.68` — orb_ring coverage-остаток (см. ниже).
  - **druid kit-rebuild** (замер суммона самый шумный → калибровать A/B, live=направление): амулет
    вниз `summon_damage_multiplier 1.85→0.85` + `summon_role 1.45→1.15` (pure_summon → bdm на нижнем
    клампе 0.28, budget не ведёт; живой рычаг — summon-множители); briar из мёртвых
    `briar_hit_multiplier 0.34→0.46` + `briar_hit_cap 5→6`; raven из мёртвых
    `raven_damage_multiplier 0.85→1.35` + `amp_pulse_interval 1.10→0.95`. Проекция total `4.91 → ~2.18`
    (crowd `11.22→4.36`; briar/raven перестают быть «мёртвыми» слотами после спада kit-mean амулета).
  - **chemist / biologist — НЕ тронуты numeric'ом (сознательно).** Их crowd-разбег — НЕ per-hit
    magnitude, а UNBUDGETED coverage: `_fire_aoe_projectile` льёт залп-по-цели (blast_powder), а
    инфекция-DoT биолога = его identity («урон приходит со временем» — `biologist_kit_test` это
    защищает; попытка срезать `curse_tick_multiplier` перевернула DoT<impact и провалила гейт →
    откат). Формульно доказано: чтобы crowd chemist/biologist попал в коридор одним numeric, нужно
    гробить solo/aoe оружий (blast solo 1t уже ок; biologist solo 0.75 на полу) → нарушение DoD
    «оружие не игнорируется» / identity. Требуется РЕШЕНИЕ: (а) coverage-кап на залп-по-цели/пирс
    (новый механизм, следующий slice) ЛИБО (б) принять crowd-лид AoE-специалистов как профиль
    (`aoe_target 1.30/1.18` уже это санкционирует). Развёрнуто — в handoff.
  - **Гейтов не ослаблял.** Новый focused A/B: `tests/stage3c_c_numeric_gate.gd` (profile down-tune
    A/B по реальной `budget_tuning_for`, cursed_skull DoT anti-silent-retune замок, druid rebuild
    направление). Регрессия PASS: `dark_mage_kit`, `elementalist_kit`, `druid_kit`, `biologist_kit`
    (после отката), `chemist_kit`, `doctor_kit`, `class_budget_profiles_integrity`,
    `global_damage_balance_smoke` (worst CCT +21% — без изменений), `damage_type_isolation`,
    `content_registry_consistency`, `status_fanout_cap_gate`, `pool_target_cap_gate`,
    `boss_hazard_cap_gate`, `orbit_falloff_cap_gate`, `progression_data_api_surface`,
    `contact_damage_softcap`. Живой пересъём CSV (направление проекций) — за интерактивной полосой.
- **FAN-1031 Stage 3c-final (2026-07-13) — data-driven ЖЁСТКИЙ кап ШИРИНЫ (coverage) крауд-каналов
  + профилировка корня crowd-runaway (no-silent-retune).** Полный разбор + профиль-таблицы + карта
  каналов — `build/stage3c_final_coverage_fan1031.md`. Решение координатора (2026-07-13): «резать
  ШИРИНУ, не выгрызать per-hit» для chemist/biologist coverage.
  - **Профилировка (ground truth, счётчики в `_damage_enemy`/`_fire_aoe_projectile`, 150-кадровое окно).**
    Разложил crowd-runaway blast_powder (chemist) 1→20 целей: hits `6→2547`, per_hit `230→38`
    (диминиш УЖЕ капнул per-hit), а число событий взрыва раздуто ДВУМЯ факторами: (1) coverage —
    каждый взрыв покрывает весь фи-таксис-диск (radius@ideal 226 > диск 171); (2) **cast-inflation:
    casts `6→67` при том же числе кадров.** Оружие фаирит в `_process(delta)` по `_cooldown -= delta`
    с variable delta; тяжёлый кадр (20 целей → много событий/твинов) → больше game-time на
    `await process_frame` → БОЛЬШЕ кастов на фикс-окно харнеса (`_measure_dps` делит на константу
    `WINDOW_SECONDS=8.0`, а не на реальную сумму delta). **Т.е. живой crowd 20t частично —
    measurement-артефакт frame-time-under-load** (объясняет и экстремальные числа, и 12× run-to-run
    шум, ранее списанный на FAN-1039). Свежий single-pair live-пересъём blast: 20t≈483k совпал с
    committed CSV, но 5t качнулся `8.4k→108k` (12.8×) — тот же артефакт. **Рекомендация лидеру:**
    судить crowd по детерминированным per-cast-coverage/формуле ЛИБО починить харнес (нормировать на
    реальную сумму delta / фикс-timestep) — иначе догон живого crowd_norm 1.56 = over-nerf реального
    геймплея. Харнес не трогал (сломал бы всю прежнюю v1–v5 калибровку) — это решение лидера.
  - **Механизм.** Per-weapon поля `aoe_max_targets` / `pool_max_targets` / `status_max_targets` /
    `orbit_max_targets` (сентинел `<0` → без потолка → нулевое изменение поведения, A/B-контроль).
    Ближние N целей (по дистанции от центра) получают урон/статус, дальше — НОЛЬ. Ортогонален
    диминиш-капам (те режут per-hit ДО потолка; композиция проверена гейтом). Проведён в
    `_damage_enemies_in_circle_capped` (aoe), `_damage_enemies_in_pool` (pool-тик), `_status_fanout_factor`
    (spore/symbiote/skull/acid-charge), `_orbit_fanout_factor` (тик квадрата). Режет и реальную crowd-clear,
    и frame-load → де-инфлирует живой замер (двойной выигрыш на артефакт-метрике).
  - **Override (старт, калибровать по live crowd_norm ≤1.56).** blast_powder `aoe_max_targets=6`;
    acid_flask `pool_max_targets=6` (заряды-статус не тронуты — свой кап стаков); biologist_spore_lens
    / biologist_symbiote_seed `status_max_targets=6` (прямой ring-урон не тронут); elementalist_orb_ring
    `orbit_max_targets=6`. After-профиль (детерминированный direct-канал): blast hits/expl `18.9→6.0`
    (−68% событий, damage −10% т.к. хвост был диминиш-мал), acid pool-тик −20%, orb −33%; инфекция-DoT
    spore/symbiote режется по ширине (DoT-тик идёт через StatusEffects, вне direct-профиля). Identity
    «специалист по толпе» цела (профиль санкционирует crowd-лид до 1.2×aoe_target; 1t/малый пак rank<6
    не тронуты).
  - **elementalist** `damage_budget 0.88→0.82` (3c-c residual, item 2): crowd orb_ring теперь режется
    orbit_max (coverage), budget-нудж добивает solo/aoe к total ≤1.5. Калибровать по live (осторожно
    с двойным нерфом crowd-оси — width-кап её уже срезал).
  - **Гейтов не ослаблял.** Новый focused A/B: `tests/coverage_cap_gate.gd` (helper hard-cap + композиция
    с диминишем, сентинел-контроль, интеграция aoe/pool + A/B, реальные конфиги «поверх диминиша»,
    дефолт-guard). Регрессия PASS: `chemist_kit`, `biologist_kit`, `elementalist_kit`, `doctor_kit`,
    `dark_mage_kit`, `druid_kit`, `orbit_falloff_cap_gate`, `status_fanout_cap_gate`, `pool_target_cap_gate`,
    `boss_hazard_cap_gate`, `class_budget_profiles_integrity`, `damage_type_isolation`,
    `content_registry_consistency`, `progression_data_api_surface`, `contact_damage_softcap`,
    `global_damage_balance_smoke` (worst CCT +21% — без изменений: капы рантаймовые, elementalist
    budget-нудж реебейзил формулу зелёно), `runtime_smoke`. **3b дно-киты (guitarist/assassin/raven) —
    сознательно НЕ начаты** (deferred): их «raw ниже сатурации» судится по той же frame-inflated
    crowd-оси; буст к артефакт-инфлированному верху = over-buff. Разумнее после решения по методике.

- **FAN-1031/FAN-1210 Методика live-замера — честное фиксированное DPS-окно.**
  Оружие стреляет в `_process(delta)`, поэтому 480 process frames не являются фиксированными
  восемью секундами под нагрузкой: менялось число кастов и возникали ложные crowd/runaway
  выбросы. `tools/character_balance_csv.gd::_measure_dps` и
  `tests/berserk_dps_runaway_gate.gd` теперь симулируют ровно
  `WINDOW_SECONDS=8.0` по сумме `get_process_delta_time()`; лимит 2400 кадров служит только
  защитой от зависания. Порог Berserk/hammer не ослаблен: после исправления пять подряд
  live-прогонов дали 20t `7337..8545 <= 10000` и 1t `789..1038 <= 1300`.

- **FAN-1031 Stage 3d (2026-07-13) — финальный балансировочный заход по честной времябазе v6
  (no-silent-retune).** Полный разбор + after-метрики + карта рычагов —
  `build/stage3d_final_balance_fan1031.md`. По приёмочному v6 (среднее 2 честных прогонов,
  все капы включены; trio-модель `tools/class_trio_table.py`): верхи вне коридора ±15%
  (chemist 1.76 / elementalist 1.49 / dark_mage 1.41 / soldier 1.39 / priest 1.35 / berserk 1.32),
  дно ниже (guitarist 0.59 / ranger 0.80 / sniper 0.86), raven_totem мёртвый слот (0.14–0.26×),
  assassin crowd-ось 0.38. **Правки (направление подтверждено детерминированным budget-дампом
  budget_tuning_for + одиночными live --pair; финальный v7 double-reshoot — за координатором):**
  - **damage_budget (уникальный per-hit рычаг класса; budget_dm=√(solo_scale·aoe_scale) клампится
    [0.28,2.80]):** chemist `1.15→0.95`, elementalist `0.82→0.70`, dark_mage `0.72→0.58`
    (curse_only `cursed_skull` НЕ затронут — direct-канал=0; live 20t 2688→2689 подтверждает),
    soldier `1.00→0.82`, priest `0.92→0.86`, berserk `1.00→0.82` (hammer вышел из клампа
    2.80→2.636), ranger `1.15→1.26`, sniper `1.00→1.15`. solo/aoe_target профилей НЕ трогал
    (внутриклассовый бюджет + профиль-идентичность).
  - **Width/coverage-капы (режут aoe/crowd ШИРИНОЙ, solo цел):** blast_powder `aoe_full 4→2 / aoe_max 6→3`
    (live 20t 31584→14835 −53%, 5t 20024→9509 −53%, 1t 1703→1504); acid_flask `pool_max 6→4`;
    orb_ring `orbit_max 6→4` (live 20t 17340→4332 −75%); priest_reliquary НОВЫЙ `falloff_full 3 /
    diminish 2.2` (live 20t 25825→20159 −22% — крауд реликвария КАДЕНС-driven, не width, кап трогает
    лишь хвост каждого бурста; остаток — за координатором).
  - **soldier bayonet solo-спайк** (live 1t 3.35× → измерено 1600 vs 2414 −34%): `melee_close_mult
    1.12→1.06`, `bayonet_auto_shot 0.25→0.18` (бюджетированы — сглаживают именно lvl20-ideal live-спайк).
  - **Дно RAW-buff (guitarist клампнут ceil — профиль live НЕ двигает):** electric_guitar `0.66→0.80`
    (live 20t 3117→3783 +21%), bass_guitar `0.26→0.30` (live 8194 +26%), sound_amp `0.85→1.00`.
    ⚠️ electric/bass у ВЕРХНЕЙ границы identity-гейта `guitarist_kit_test` (рифф ≤0.80, бас ≤0.30) —
    гейт НЕ ослаблял; остаточный дефицит клампнутого+identity-ограниченного кита — структурный
    (решение координатора: поднять кламп-ceiling / identity-границу / faster-riff mechanic).
  - **raven_totem revive** (был мёртвый слот 0.14–0.26×): `raven_damage_multiplier 1.35→2.40`
    (модель пинована `RAVEN_BUDGET_REF_MULTIPLIER` → НЕ budget-compensated) + `raven_explosion_radius
    120→150` (крауд). Live 190/623/1149 → 349/1264/2774 (×1.84/2.03/2.41) — слот ОЖИЛ (выше 40%
    средней кита по solo/aoe; crowd ~84% порога).
  - **assassin chakrams — ОТКАТ.** Геометрический widen (aoe_radius/beam_width) НЕ поднял crowd
    (болванки уже в коридоре; beam_width>61 упирает `five_hits` в кламп 3.4 → per-hit ПАДАЕТ);
    измеренный live 20t 5508→4385 ушёл ВНИЗ. Откачено к оригиналу. assassin (0.93, in-corridor) —
    crowd-ось требует ДРУГОЙ механики (крауд-хит возвратной дуги сверх дедупа), deferred.
  - **Гейты обновлены (пинованные значения капов = ДОКУМЕНТИРОВАННАЯ правка, не ослабление):**
    `aoe_target_cap_gate` blast 4/3.0→2/3.0; `coverage_cap_gate` blast aoe_max 6→3, acid pool_max
    6→4, orb orbit_max 6→4; `orbit_falloff_cap_gate` blast pin 4→2 + два диминиш-теста изолированы
    от жёсткого width-капа (`orbit_max_targets=-1`). Все kit/cap/smoke/regression-гейты зелёные
    (worst CCT +20%). FAN-1210 заменил номинальные 480 кадров Berserk live-gate на точное
    simulation-time окно, поэтому результат больше не принимается по случайному «удачному»
    переспросу; пороги и gameplay-настройки молота не менялись.

- **FAN-1031 Stage 3d-final (2026-07-13, v7 приёмка координатора) — доводка коридора + 3
  структурных решения (no-silent-retune).** Полный разбор + budget-дамп + проекции —
  `build/stage3d_final_v7_fan1031.md`. По приёмочному v7 (trio-модель, медианы solo 820 / aoe 2656 /
  crowd 8556 / EHP 85): верхи chemist 1.36 / robot 1.33 / priest 1.22 / soldier 1.19 / dark_mage 1.16 /
  elementalist 1.16; дно guitarist 0.61 / sniper 0.86 / assassin 0.85 (crowd 0.31). Направление КАЖДОЙ
  правки подтверждено детерминированным дампом `budget_tuning_for` (budget_dm/eff per-hit); финальный
  **v8 double-reshoot + точная приёмка коридоров — за координатором** (roster-relative median дрейфует
  от нерфов верхов и буста дна — статикой не учесть; live-полный-пересъём вне лейна исполнителя).
  - **Guitarist — ПРОДУКТОВОЕ РЕШЕНИЕ координатора (DoD FAN-1028), НЕ тихое ослабление гейта.**
    identity-капы кита ПОДНЯТЫ: `guitarist_kit_test` рифф ≤0.80→≤1.30, бас ≤0.30→≤0.50 (+ новый пин
    «бас < рифф» — относительная «ранняя слабость в уроне» сохранена). Обоснование: класс `control`
    несёт бюджет в CC амп-сети, а trio-модель контроль НЕ считает (ось defense=EHP) → кит структурно
    недооценён; поднятый RAW компенсирует НЕсчитаемый контроль (НЕ двойной зачёт). Raw: electric
    `0.80→1.28`, bass `0.30→0.48`, amp `1.00→1.60`; db `1.00→1.50` держит кит клампнутым (budget_dm=2.80
    ceil) → raw лендится 1:1 (budget-дамп: electric eff 2.24→3.58 ×1.60, bass 0.84→1.34 ×1.60). Ramp/
    амп-control identity (warmup 0.02/0.20, амп-сеть) НЕ трогал. Статик-проекция total ≈0.86 + median-
    дрейф → ≥0.85.
  - **Priest — каданс-кап (НЕ width).** crowd 1.89 — каденс-driven (storm-бланкет толпы ×3/каст).
    `_fire_interval_artifact_factor` замедляет БАЗОВЫЙ fire_interval на точке потребления: reliquary
    ×1.30, censer ×1.15 → throughput всех осей ↓ (DPS ∝ 1/cooldown), WIDTH/falloff-identity целы.
    Ideal-крауд-билд НЕ берёт mode-артефакты (reliquary_salvo/censer_vow scored 0 в `_dps_score` —
    только `mods`, без `stats`) → базовый тэ применяется к замеру без offset'а. Направление crowd↓
    детерминированно; остаток к ≤1.25 (chime 1.87× медианы НЕ тронут по указанию — reliquary/censer
    only) — median-дрейф + решение координатора по chime на v8. Пин + A/B-контроль (не-priest =1.0):
    `priest_kit_test._check_cadence_tax`.
  - **Assassin — crowd-ниша через venom_wire «яд-спред по толпе в существующих капах».** Новый
    сентинел-контракт `dot_beam_spread_ratio` (0.0 → no-op, A/B). После пирса струна брызгает ядом
    по врагам ВНЕ пробитой линии (`_venom_crowd_spread`): крауд-канал В СУЩЕСТВУЮЩИХ капах ширины
    (`aoe_max_targets 6 / aoe_full_targets 2 / aoe_target_diminish 1.6` — те же поля прямого AoE, venom
    иначе их не использует), ОРТОГОНАЛЬНЫЙ solo (пробитые исключены → на 1 цели спреда нет → solo-ось
    не раздувается). venom config: `dot_beam_spread_ratio 0.55`. Пирс-лимит контракт целостен (сабтест
    изолирован от спреда). Новый сабтест `assassin_kit_test._test_venom_wire_crowd_spread` (solo A/B-
    ортогональность + крауд-хит + кап ширины). Величину spread_ratio калибрует координатор по v8
    (цель crowd_norm ≥0.45 профиля 0.70). Player-facing: описание venom_wire дополнено «яд брызгает на
    ближнюю толпу за линией».
  - **Numeric-трим верхов (db, budget-дамп-подтверждён):** chemist `0.95→0.85` (blast eff 5.02→4.49),
    robot `0.88→0.80` (magnetic 4.30→3.91; ⚠️ остаток total >1.15 = identity-price ТАНКА def 2.12 —
    survival НЕ режем, решение координатора; калибровать по damage-осям, не total), soldier `0.82→0.76`,
    dark_mage `0.58→0.52`, elementalist `0.70→0.63`. chemist/dark_mage/elementalist остаточный aoe/crowd-
    лид — profile-identity (aoe_target 1.30/1.10, уже width-капнуто) с примечанием, не выгрызаем per-hit.
  - **Sniper — вверх (solo-класс недодаёт по своей оси, solo_norm 0.73 при цели 1.15):** db `1.15→1.35`
    (budget_dm всех трёх, unclamped, лендится: deadeye eff 1.35→1.58) + deadeye-специфично
    `DEADEYE_ENDPOINT_BLAST_RATIO 0.35→0.42` (вне budget-компенсации).
  - **Гейты:** kit (guitarist/priest/assassin/sniper/chemist/robot/soldier/dark_mage/elementalist/
    biologist/doctor/druid) + cap (aoe_target/coverage/orbit_falloff/status_fanout/pool_target/
    boss_hazard) + `class_budget_profiles_integrity` + `global_damage_balance_smoke` (worst CCT +20% —
    без изменений) + `damage_type_isolation`/`content_registry_consistency`/`progression_data_api_surface`/
    `contact_damage_softcap` — ВСЕ зелёные (24/25). **Гейтов НЕ ослаблял.** ⚠️ Известный-красный ДО
    моих правок `comfort_band_cross_class_gate` (v7 baseline: 7 нарушений; после db-сдвигов 18) — это
    Stage-4 перекалибровка comfort-весов (`class_mean_raw/median`), которую координатор явно оставил
    себе ПОСЛЕ фиксации db на v8; премейчур-рекалибровка под ещё-двигающиеся db была бы сразу
    устаревшей. Не в приёмочном наборе «15/15».

- **FAN-1031 Stage 3d v8-микротрим (2026-07-13, v8 приёмка координатора) — последний заход коридора
  ±15% + S4 random-floor (no-silent-retune).** Полный разбор + карта рычагов + measured-направления —
  `build/stage3d_final_v8_microtrim_fan1031.md`. По приёмочному v8 (ростер сошёлся 0.84…1.23, середина
  0.91–1.11). Направление КАЖДОЙ правки — детерминированно (budget-дамп/формула); финальный **v9
  double-reshoot и точная приёмка коридоров — за координатором** (roster-relative median дрейфует от
  нерфов верхов вниз и буста дна вверх — статикой не учесть; полный live-trio вне лейна исполнителя).
  - **Верхи вниз (по одному малому db-шагу; solo/aoe_target профилей НЕ трогаем):** chemist db `0.85→0.80`,
    soldier `0.76→0.72`, dark_mage `0.52→0.48`, robot `0.80→0.75` (⚠️ остаток total >1.15 = identity-price
    ТАНКА def 2.12 — survival НЕ режем, судить по damage-осям; решение координатора v7/v8). druid — aoe 1.64
    амулет-driven ПОСЛЕ ревайва ворона (db призыв НЕ ведёт, bdm на floor 0.28) → рычаг `summon_damage_multiplier
    0.85→0.78`, не db. Ворон/briar остаются живы.
  - **Priest — смягчение каденс-налога + перенос крауд-добора на ШИРИНУ (координаторское решение).**
    Каденс reliquary `1.30→1.18` (`_fire_interval_artifact_factor`): ×1.30 перегибал RANDOM-билд
    (random-A1 0.86), а каденс давит ВСЕ оси, включая solo/random. Крауд-добор перенесён на новый
    width-кап ХВОСТА кадила: `_fire_priest_ward` теперь льёт волну через тот же капнутый direct-AoE
    контракт (`_damage_enemies_in_circle_capped`), что blast/acid; конфиг опт-инится `aoe_full_targets:4`
    / `aoe_target_diminish:1.2`. Ближние 4 цели — полный урон, дальний хвост толпы душится по формуле, но
    **жёсткого max НЕТ** (`aoe_max_targets` -1) → identity «выжигают ВСЁ вокруг» цела (все в радиусе задеты,
    дальние слабее) — поэтому player-facing описание кадила НЕ меняем (в отличие от hard-cap spore/orb/acid).
    Пин + A/B на реальном конфиге: `coverage_cap_gate._test_censer_width_integration` + real-config pin;
    data-контракт + каденс-пин 1.18: `priest_kit_test`.
  - **Дно вверх:** guitarist raw к потолку identity-капа (electric `1.28→1.30`, bass `0.48→0.50`; bass<electric
    цел) + амп (uncapped identity-гейтом) `1.60→1.85` — осн. рычаг лифта 0.84→≥0.85 (плюс median-дрейф);
    guitarist db 1.50 не трогаем (держит кит клампнут). ranger db `1.26→1.38` (raw всех трёх, unclamped).
  - **S4 random-floor (план §2.1-S4, впервые реализовано):** каждый level-up-показ ГАРАНТИРУЕТ ≥1 карту,
    релевантную УРОНУ класса. Рычаг — `ProgressionData.weighted_level_up_selection` + новый
    `reward_is_damage_relevant` (урон-ось И relevance ≠ optional по ATTRIBUTE_RELEVANCE — физ-«damage»
    у мага мёртв, matrix это кодирует). Форс на последнем слоте, только если в regular-пуле есть damage-карта.
    Гарантия damage-релевантна ⟹ non-optional по построению → УСИЛИВАЕТ старый инвариант «≥1 non-optional»,
    не нарушая «≤1 optional». LEVEL_UP_REWARDS не трогали (уже вычищен FAN-1034) — введена только офер-гарантия.
    Гейт: `tests/level_up_damage_floor_gate.gd` (17 классов × 200 seed'ов + prefill capstone + helper A/B +
    satisfiability); `attribute_relevance_test` (старые инварианты) остаётся зелёным.
  - **Гейты (32 зелёных, гейтов НЕ ослаблял — только УСИЛЕНы priest_kit/coverage_cap + новый
    level_up_damage_floor_gate):** kit ×11 (chemist/robot/soldier/dark_mage/druid/ranger/elementalist/
    biologist/doctor/sniper/assassin) + guitarist/priest kit + cap ×6 (aoe_target/coverage/orbit_falloff/
    status_fanout/pool_target/boss_hazard) + `class_budget_profiles_integrity` + `global_damage_balance_smoke`
    (**worst CCT +20% — БЕЗ изменений**, db-сдвиги реебейзят формулу зелёно) + `content_rewards_integrity`/
    `level_up_advisor`/`attribute_relevance`/`damage_type_isolation`/`content_registry_consistency`/
    `progression_data_api_surface`/`contact_damage_softcap` + runtime_smoke (base + weapon_mechanics — живой
    censer-путь). ⚠️ `comfort_band_cross_class_gate` — известный-красный (Stage-4 рекалибровка comfort-весов
    под финальные db, за координатором); мой амп-raw-буст добавляет стейл в `guitarist/sound_amp` CSV-веса —
    туда же. Не в приёмочном наборе.

- **FAN-1031 Stage 3 v9-финал (2026-07-14, v9 приёмка координатора) — 2 финальных пункта + закрытие S3
  исполнителем (no-silent-retune).** Полный разбор + budget-дамп A/B + live-направления —
  `build/stage3_v9_final_fan1031.md`. По приёмочному v9 (ростер 0.87…1.19, сжатие 15×→1.37×, мёртвых
  слотов 0/51; координатор: «дальше гоняться за шумом ±0.1 бессмысленно»). Метод приёмки этого слайса —
  budget-дамп (детерминированный per-hit A/B) + по одному `--pair` live (soldier, priest) + kit-тесты;
  **полный v10-пересъём НЕ гоним** (координатор принимает по дампу/парам — направления детерминированы).
  - **Soldier (per-hit вниз):** db `0.72→0.68` — ещё один малый uniform per-hit шаг всех трёх оружий
    (unclamped, лендится 1:1). Budget-дамп A/B (`budget_tuning_for`): rifle dm 1.405→1.327, grenade
    1.194→1.128, bayonet 0.889→0.839 — все **−5.6%** (= ratio 0.68/0.72), давит solo-спайк 1.50 (bayonet)
    к профилю 1.00. def 1.22 steady не тронут.
  - **Priest — NET-ZERO power-shift крауд→base/solo (координаторское решение).** random-A1 `0.87<1.0` —
    единственный fail ascension-гейта: сила Жреца заперта в крауд-ширине кадила, а RANDOM-билд её не
    добирает надёжно. Переносим силу С крауд-ширины НА base/solo (per-hit + throughput), total 1.14 держим:
    - *base/solo ВВЕРХ (reliquary — соло-бурст Жреца, unclamped):* (1) каденс-налог `_fire_interval_artifact_factor`
      reliquary `1.18→1.08` — throughput ×(1.18/1.08)≈**+9.3%** по всем осям, **НЕ** компенсируется budget-тюнером
      (каденс вне формулы); (2) `solo_target 1.03→1.10` — budget-дамп A/B: reliquary dm `1.755→1.813` (**+3.3%**
      per-hit, unclamped лендит), а **censer/chime clamped на ceil 2.80 → solo_target их НЕ двигает** (лифт
      хирургически reliquary-only). Суммарный reliquary-лифт ≈**+12.9%** (live `--pair` подтверждает: reliquary
      1t/5t/20t rnd/id/l1 все вверх +11…20% — совпадает с проекцией). Это и есть лифт random-floor.
    - *crowd ВНИЗ (censer — крауд-оружие Жреца):* width-кап хвоста `aoe_full_targets 4→3` + `aoe_target_diminish
      1.2→1.7` — крауд-хвост (ranks ≥3) режется **41…63%** (детерминированная формула диминиша, gated
      `coverage_cap_gate`), компенсируя лифт base/solo для net-zero total. Censer per-hit clamped — width НЕ
      трогает solo (1 цель = rank 0 = полный); жёсткого max НЕТ → identity «выжигают ВСЁ вокруг» цела →
      player-facing описание кадила НЕ меняем. reliquary crowd hard-капнут falloff (3/2.2) → лифт reliquary
      крауд обратно почти не разбегает. **⚠️ live censer/soldier single-`--pair` слишком шумны (кадило —
      tween-пульсы, байонет — мили-позиционка; censer 1t качнулся 37.5→72.4 при том, что ширина на 1 цели
      неактивна) — их направление держит ДЕТЕРМИНИРОВАННЫЙ дамп/формула, не live (координаторская доктрина:
      live=направление, шум усредняют 2–4 прогонами).**
  - **Пины обновлены (документированная правка, НЕ ослабление):** `priest_kit_test._check_cadence_tax` reliquary
    1.18→1.08; `coverage_cap_gate` real-config pin кадила 4/1.2→3/1.7 (интеграционный `_test_censer_width_integration`
    читает реальный конфиг → формула диминиша проверяется поведенчески, адаптивно).
  - **Гейты (11 прогнано зелёными, гейтов НЕ ослаблял):** `priest_kit`, `soldier_kit`, `coverage_cap_gate`,
    `class_budget_profiles_integrity` (solo_target 1.10 / soldier db 0.68 в границах (0,2]), `global_damage_balance_smoke`
    (**worst CCT +20% — БЕЗ изменений**, sniper/deadeye/20t; priest-сдвиги worst не двигают), `runtime_smoke`
    (base + weapon_mechanics — живой censer/reliquary путь), `damage_type_isolation`, `priest_sustain_softcap`,
    `content_registry_consistency`, `contact_damage_softcap`.
  - **За координатором:** авторитетный v10-контроль (если решит) + подтверждение random-A1 ≥1.0 по live-полам;
    Stage 4 (FAN-1032): comfort-веса под финальные db, формальный ascension-гейт тестом, сводный before/after v2→v9.

## Known Balance Risks

- Точный паритет clear speed Темного мага/Гитариста с Берсерком требует ручного плейтеста.
- SCRUM-856 зафиксировал identity/playfeel риск поверх зелёных numeric gates:
  delayed AoE, AoE projectile, chain/split/pierce, deploy/summon и sustain
  семейства должны быть разведены механиками. `doctor/restore_potion` возвращён в
  сустейн-нишу капом сплэша (FAN-1031 S3, см. Balance Validation), hard-clamped summons/DoT
  (`druid/summon_amulet`, `chemist/homunculus_vial`, `assassin/venom_wire`) и
  cap-pinned weapons (`hammer`, `elementalist_prism_focus`,
  `elementalist_meteor_core`, `dark_book`, `tower_shield`, `holy_flail` и др.).
  SCRUM-857 уже закрыл первую часть риска для grenade/meteor/ricochet/split/
  prayer/dark pierce families. SCRUM-858 снял первый documented risk для
  Knight shield/flail не множителями, а разнесением block/counter геометрии и
  target caps. SCRUM-859 split stationary deploy/summon loops into stage pulse,
  support totem, turret DPS, repair chain, and mine grid. SCRUM-860 added
  Assassin-only capped kill-growth without adding a new vampirism/sustain loop.
- FAN-1128 повторно откалибровал SCRUM-469 после обновления live-kit'ов, не
  меняя Base lvl1, budget profile или оружейные механики: актуальный `Lvl20
  optimum` `relative_score` держится в диапазоне `0.912..1.067`, Base lvl1 —
  в `0.988..1.005`, а Lvl20 random avg не имеет HIGH/LOW-флагов. Остаточные
  различия остаются предметом ручного feel/playtest, а не блокером формульного
  баланса.
- Performance/code review считает текущие числа пригодными для demo, но баланс должен продолжать уточняться после игровых прогонов.

## SCRUM-541 Secret Boss Progression Gate

The secret boss no longer uses the old low-damage/key-artifact SCRUM-619 gate.
`MetaProgression.secret_encounter_unlocked_for_level(run_level)` unlocks the
post-final-act secret encounter only when the selected run Ascension is the current
maximum (`MAX_ASCENSION_LEVEL`, 5 after SCRUM-516).

Flow:

- Act 2 route boss remains the normal boss id from the route node.
- If that boss is defeated below max Ascension, the run ends with the normal
  victory flow.
- If defeated at max Ascension, `CombatDirector` immediately starts
  `secret_ascension_boss` as a follow-up boss encounter.
- The one-time persistent secret reward still uses
  `record_secret_boss_victory`; repeat wins do not grant the bonus twice.

Historical balance benchmark at final Ascension L5/stage 18: secret boss HP is
about `47.6k`; SCRUM-1058 moves the reachable route finale to stage 16 without
changing boss formulas or extending fight duration.
L20 optimum class kits estimate `121.5s..231.8s` TTK by 1-target DPS range;
L20 random-average kits estimate `347.3s..559.6s`, so the fight is intended as
a brutal capstone for tuned builds rather than a global class rebalance.

## SCRUM-1069 Guild Atlas Economy / Support Caps

Account-wide Guild progression was raised from symbolic `2%/+10` fillers to
measurable role floors without adding global damage. Purchased branch totals
are Treasury `+20% gold/+100 start`, Shop `−20% shop/attribute`, Knowledge
`+15% XP/+1 option/100% ultimate`, Road `+60 pickup/+20% healing/30% death-save`.
Their normalized value-per-stardust scores stay in `0.643..0.667`. Exactly 384
connectivity-valid 50-dust builds score `31..34` (spread `1.097`), so no branch
is a mandatory universal choice.

The full 59-cost Atlas is used as a conservative upper bound over every legal
50-dust build: account power `1.174 < 1.35`, weighted class contribution
`+17.4% ≤18%`, max Guild price reduction `20%`, XP `15%`, and gold `30%` only
after the free Codex hidden node. At A5, enemy HP/damage remain above `1.5×`,
healing stays `0.68×1.20=0.816` of A0, and reward pressure is bounded at
`0.80×1.30=1.04`; the account layer does not erase Ascension difficulty.

Gate: `tests/guild_atlas_scrum1069_balance_test.gd`; exact audit:
`docs/design/reports/scrum1069_guild_atlas_balance_audit.md`.

## FAN-1028 Полный ребаланс классов — финальный итог (Stage 4, 2026-07-14)

Пересмотр баланса всех 17 классов как полных three-weapon китов (FAN-1028,
ветка `agent/claude/53f2a056`). Сводный before/after v2→финал с пер-классовыми
и пер-оружейными таблицами, механизмами капов и валидацией:
**`build/fan1028_rebalance_final_report.md`**.

Итог (roster-relative kit-total; времябаза честная с `8dd7e4fb`, roster-relative
скоры сравнимы через границу времябазы):

- **Разброс китов `0.49 … 7.56` (v2, 15.4×) → `0.87 … 1.21` (финал, 1.39×)**;
  13/17 внутри ±12%, все 17 внутри ±21% (верхние — задокументированный
  identity-price танков robot 1.19 / knight 1.12 + погранзначения priest 1.21 /
  soldier 1.19).
- **Мёртвых слотов `≥4 → 0/51`** (homunculus_vial, briar_staff, raven_totem
  ×1.84–2.41, pressure_mines оживлены).
- **Crowd-runaway капнут data-driven** по 5 каналам (прямой AoE / pool / status
  fan-out / falloff / orbit width-skip) + boss-hazard ≤80% max HP; за-каповый
  хвост толпы ПРОПУСКАЕТСЯ (skip, не «хит нулём»). Пик v2 chemist/blast_powder
  crowd 79.4× медианы → в коридоре.
- **Ascension (DoD A1/A5):** формальный гейт `tests/ascension_viability_gate.gd`
  — все 17 классов проходят A5 (худшая маржа guitarist 6.08 ≥1.5), секретный
  босс ≥1.2, random-A1 ≥0.95 (худшие живые 0.97–0.99), ваншоты исключены капом.
- **Comfort-band:** разброс `3.62× → 1.24×`, `comfort_band_cross_class_gate` зелёный.
- **Валидация (tip `90352a6c`):** все балансные гейты зелёные (6 cap + ascension
  + comfort + damage/survivability smoke + 16 kit + pool_dot_runaway 67549≤80000).
  `weapon_integrity_test` — pre-existing на базе `078833fc` (не относится к
  ребалансу); berserk — живой шум, проходит на 4-прогонном среднем.
- Peer review: 25 агентов, 19 находок (1 опровергнута), 8 actionable зафикшены.

Остаток: QA child issue (lifecycle FAN-1048, оконный визуальный смоук 2–3
классов) → Stage 5 PR `agent/claude/53f2a056` → `dev`.

## FAN-1438 — воспроизводимый A5-срез ростера

`tools/a5_balance_report.gd` собирает единый набор данных для текущих
`ProgressionData.character_ids()` и `WEAPONS_BY_CLASS`, затем из него рендерит
Markdown, CSV и raw JSON в `docs/design/reports/fan1438_a5_balance/`. Команда
регенерации принимает только точный `--source-commit=<SHA>`: tree и committer
timestamp она получает через `git show -s --format=%H%n%T%n%cI <SHA>`, а не из
wall-clock или ручных флагов. Неразрешимый, неполный или расходящийся Git tuple
останавливает генерацию до записи артефактов; integrity gate повторно сверяет
commit/tree/timestamp и содержит отрицательный mismatch-case.

Для class-kit ultimate сборщик всегда берёт контролируемые level stats из
`no_meta` строки и ровно один раз применяет class/Atlas attribute и run
modifiers. Поэтому мета-бонусы не переносятся повторно из weapon rows, а ultimate
остаётся class-level показателем, не привязанным к конкретному оружию.

Контролируемая матрица использует A5 вместе с накопленными наградами A1–A5,
уровни 1 и 20, а также четыре состояния меты: без меты, полное созвездие класса
schema 6, созвездие плюс легальный Atlas 50 и явно неигровой верхний Atlas 59.
Уровень 20 — синтетическая балансная модель: ровно 19 целых неотрицательных
очков базовых характеристик и один общий билд на всю тройку оружия класса. Это
не реконструкция 19 выпавших в реальном забеге reward-карт.

Формульный слой повторно использует `ProgressionData` и принимает A5/meta
`run_modifiers`; опциональный `include_ultimate=false` исключает ульту из
пер-оружейного sustain-DPM. Ульта показывается отдельно на уровне class kit.
Schema-6 flat/cadence/geometry/axis/final профиль берётся из канонического
`MetaProgression.skill_modifiers_for_weapon`. Нелинейный слой проверяется
реальными headless Player/Enemy-пробами всех runtime-пар с фиксированными
сидами, warm-up и фиксированным игровым окном.

Начиная с raw schema `fan1438.a5-balance.v2`, каждая такая проба также содержит
`fan1511.runtime-telemetry.v2`: стабильный ключ
`pair|seed|scenario|fixture|target-cardinality`, trace ID, counters реальных
casts/hits, уникальные target IDs и взаимоисключающие buckets `source×phase`.
Каждый cast получает стабильный `cast_id`, а каждый применённый игроком hit —
единственный `provenance_id`; оба идентификатора только наблюдательные и не
влияют на боевой расчёт. Cast приходит из `Player.weapon_cast_observed`,
применённый урон — после канонического расчёта HP в `Enemy.damage_applied`.

Наблюдаемое final-событие обязано ссылаться на реальный hit через
`related_hit_id`, а hit хранит ровно одну взаимную ссылку в `final_event_ids`;
проверяются цель и причинный порядок. Отложенные или targetless resolver-сигналы
не считаются наблюдённым финальным уроном до его канонического применения.
`final_event_damage` — только дедуплицированное помеченное подмножество тех же
hit buckets и никогда не прибавляется к общему урону второй раз.

Каждая фикстура несёт `hp_ledger`: полный набор целей, сумму канонически
применённого урона и health loss за measurement-окно. Ledger сверяет runtime
hits и DPM с фактическим изменением HP с допуском `0.0001`; overkill учитывается
как оставшийся HP, а не как запрошенный урон. Полный прогон добавляет три
репрезентативные фикстуры: обычную offensive, mortal target с наблюдаемым kill и
детерминированный incoming hit по игроку; короткая проверка только этих
примитивов доступна через `--mode=telemetry_probe`.

FAN-1551 фиксирует boundary live-measurement как число simulation steps и
несокращённую сумму `process_delta_time`: `measurement_duration_seconds` и
`measurement_frame_count` — canonical denominator для DPM. Округлённая до
`0.0001` длительность сохранена только как диагностическое поле вместе с тремя
projection (`legacy HP-delta/raw duration`, `ledger/raw duration`,
`ledger/snapped duration`) и разностью numerator; она никогда не используется
для расчёта report DPM. `tests/a5_balance_report_parity_test.gd` проверяет
упорядоченный manifest 51 оружий и четыре live/variance поля against exact
fresh executable oracle `f09f21ec`; это measurement repair, а не balance/config
tuning.

### FAN-1641 — lineage-aware A5 parity contract

Исторический численный оракул `f09f21ec` и его закоммиченные артефакты
(`raw.json.gz`, `per_weapon.csv`, `report.md`) остаются read-only и неизменными.
После принятых и независимо QA-проверенных summon-фиксов FAN-1585 (`e0c6c8c5`,
druid summon formations) и FAN-1596 (`8376f5c7`, homunculus pair guard) свежая
регенерация из текущего `origin/dev` детерминированно отличается от f09 ровно в
трёх из 204 ячеек 51×4 — только у `druid/summon_amulet`: crowd mean
`361323.76→394715.33`, solo variance `45635023.84→51498851.11`, crowd variance
`36494237500.62→36324029697.05`; solo mean остаётся `68101.14`. Поэтому буквальный
all-zero diff к f09/`ec15444e` больше недостижим без отката принятой геометрии
или подмены baseline.

`tests/fixtures/a5_oracle_lineage.json` (schema `fan1641.a5-oracle-lineage.v1`)
кодирует это lineage fail-closed: неизменные f09 raw/dataset/projection/telemetry
хэши и опубликованную 51×4 матрицу; ровно три принятые дельты
`druid/summon_amulet` с `from/to` и причинными issue FAN-1585/FAN-1596;
инвариантные 201/204 равные ячейки и solo-mean инвариант; выведенный projection
digest непосредственной current integration base `b8909e30`; и точный
сегментированный инвентарь `ec15444e..b8909e30` (8 commits: 6 measurement-contract
+ 2 gameplay), где gameplay-коммиты трогают `scripts/summoner_weapon.gd`.

Верификатор в `tools/a5_balance_report.gd` состоит из трёх слоёв и не допускает
wildcard, tolerance relaxation, snapshot substitution или ручную перезапись
baseline:

- `verify_oracle_lineage` — self-consistency манифеста против живого закоммиченного
  оракула: f09 хэши воспроизводятся, опубликованная матрица равна live-оракулу,
  принятые дельты реконструируют current base ровно с 201 равной и 3 изменёнными
  ячейками, а выведенный digest совпадает с pinned значением и отличается от f09.
- `verify_oracle_lineage_ancestry` — commit-level causality через настоящий Git
  (`git show`/`merge-base`/`rev-list`), без зависимости от runtime ObjectID или
  порядка аллокаций: pinned trees, линейная цепочка `f09 → ec15444e → b8909e30`,
  точный упорядоченный инвентарь и summon-файлы у gameplay-коммитов.
- `verify_candidate_against_current_base` — замена невозможного
  `candidate vs ec15444e all-zero`: кандидат материализации обязан иметь exact
  zero gameplay/event delta к своей immediate current base (оракул + принятые
  дельты) по всем 204 ячейкам и по 309-ключевому telemetry event-множеству.

Негативные мутации (лишняя дельта ячейки, изменённое принятое значение,
пропущенная lineage-запись, подменённый оракул/коммит/tree, ложный current-base
zero, дрейф current digest, подменённый decoded raw) обязаны fail closed;
покрытие — в `tests/a5_balance_report_parity_test.gd` (полный контракт + Git
causality) и `tests/a5_balance_report_integrity_test.gd` (committed oracle ↔
manifest tie).

Lineage-aware замена FAN-1575 AC6/AC7 (применяется после независимого exact-SHA
QA PASS этого дефекта):

- **AC6′.** Две clean executable f09 regeneration детерминированы, а исторический
  f09 51×4 oracle/digest сохранён неизменным. Candidate по 51 keys × четырём
  live/variance полям равен f09 за исключением ровно трёх перечисленных принятых
  `druid/summon_amulet` дельт (crowd mean, solo variance, crowd variance),
  причинно связанных с независимо QA-проверенными FAN-1585/FAN-1596; остальные
  201 ячейки — exact zero diff; solo mean остаётся `68101.14`. Tolerance
  relaxation, wildcard, snapshot substitution или ручная baseline rewrite = FAIL.
- **AC7′.** Candidate имеет exact zero gameplay/event delta (damage, targets/order,
  frame/timing, HP mutation, RNG, feedback, on-kill) к своей immediate current
  integration base (текущий `origin/dev`), а не к `ec15444e`. Исторический
  инвентарь `ec15444e→current` зафиксирован точно и сегментирован на принятые
  measurement-contract и gameplay (FAN-1585/FAN-1596) коммиты. Stage 1 A/B,
  FAN-1539 telemetry, Dark Mage/Homunculus/summon regressions и fail-closed
  mutations остаются зелёными.

FAN-1574 заменяет synthetic no-op на production-equivalent observer A/B:
`--mode=observer_neutrality` запускает 51 оружие × 3 seed × solo/pack, плюс
три representative fixtures, то есть **309 samples в каждой arm**. Обе arm
создают тот же `Player.tscn`/`Enemy.tscn`, применяют тот же A5/meta state и
seed, прогреваются ровно 120 и измеряются ровно 360 process frames при
`--fixed-fps 60`; canonical duration всегда `360 / 60 = 6.0` seconds.
Authoritative measurement witness подключён к production `weapon_cast_observed`,
`constellation_final_resolved`, `damage_applied` и `died` в обеих arm, поэтому
обе используют один applied-HP `ledger_total` numerator и raw fixed duration.
Наблюдатель под тестом — второй реальный subscriber этих же signals: он
подключён только в enabled arm, а disabled arm проверяемо имеет ноль его
subscriptions и callbacks. Гейт требует exact equality witness events/callback
input, damage, target order, HP ledger/snapshots, frames, duration, RNG,
feedback/final events и 51×4 projection; любое drift или отсутствие disabled
baseline — fail-closed. `health_delta` сохраняется исключительно как legacy
diagnostic projection и не является DPM source ни в одной arm.

`tests/a5_balance_report_observer_neutrality_test.gd` покрывает fail-closed
fixtures для missing и identical disabled baseline, canonical numerator, off-by-one
measurement frame count и RNG consumption. Отдельная coherent wrong-window
фикстура сдвигает `measurement_duration_seconds` ровно на один fixed delta
(`(360 + 1) / 60` при канонических 360 frames) и согласованно пересобирает
snapped duration, `ledger/raw` и `legacy HP-delta/raw` DPM-проекции и probe
duration, оставляя frame count, numerator, RNG probe, manifest identity, delivery
и events каноничными. Тест утверждает, что диагностика содержит
`does not preserve the canonical fixed ledger window`, доказывая, что отказ
исходит именно от инварианта фиксированного окна, а не от случайного
рассогласования. Дополнительно покрыты duplicate или substituted 309-sample
manifest и каждая из 51×4 projection cells. Верификатор требует не только count,
но и exact roster/seed/fixture key для каждой arm. Полная команда выполняется
только через gate: `python3 tools/godot_gate.py --headless --fixed-fps 60 --path . --script res://tools/a5_balance_report.gd -- --mode=observer_neutrality`.

Выживаемость привязана к одному явно описанному normal-wave A5 contact-pressure
сценарию. Глобальный множитель обычных врагов не переносится на boss/elite
ветки, у которых в runtime отдельные consumers. Условные control, timed absorb,
one-hit ward и death-save не маскируются под постоянный shield HP.

Class-kit corridor использует один строгий контракт для `solo`, `AoE` и
`defense`: выбросом считается только значение `<0.80×` или `>1.20×` медианы
того же level/scenario; ровно `0.80×` и `1.20×` остаются внутри коридора. Флаг
строки и raw summary получают результат из одного helper, поэтому перечисляют
все сработавшие оси в стабильном порядке `solo`, `AoE`, `defense`.

Гейт: `tests/a5_balance_report_integrity_test.gd`. Он динамически проверяет
полное декартово покрытие ростера, общие 19-точечные билды, расходы и связность
Atlas 50/59, отсутствие ульты в weapon rows, class-kit строки, полное множество
attack modes/final mechanics в live evidence и согласованность CSV/raw/Markdown,
включая fail-closed совпадение corridor-флагов и summary по трём осям. Для
telemetry gate отдельно реконструирует counters из trace и отвергает missing или
duplicated events, неверную cardinality цели, подмену source/phase, а также
рассинхронизацию count/damage final-event.
