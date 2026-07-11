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
    покрытие толпы — кольцо орбиты `clamp(1 + (внешний радиус спирали + контакт)/58, 1, 5)`.
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

### SCRUM-1067 target: 3×6 weapon constellations

Design/data contract для SCRUM-1068 зафиксирован в
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
`three_paths_6_of_6`, `full_20_of_20`, `a5_live`. Текущие schema-5 числа ниже
остаются историческим baseline до SCRUM-1068.

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

## Known Balance Risks

- Точный паритет clear speed Темного мага/Гитариста с Берсерком требует ручного плейтеста.
- SCRUM-856 зафиксировал identity/playfeel риск поверх зелёных numeric gates:
  delayed AoE, AoE projectile, chain/split/pierce, deploy/summon и sustain
  семейства должны быть разведены механиками. Особенно важны `doctor/restore_potion`
  (текущий худший 20-target CCT +22%, но PASS), hard-clamped summons/DoT
  (`druid/summon_amulet`, `chemist/homunculus_vial`, `assassin/venom_wire`) и
  cap-pinned weapons (`hammer`, `elementalist_prism_focus`,
  `elementalist_meteor_core`, `dark_book`, `tower_shield`, `holy_flail` и др.).
  SCRUM-857 уже закрыл первую часть риска для grenade/meteor/ricochet/split/
  prayer/dark pierce families. SCRUM-858 снял первый documented risk для
  Knight shield/flail не множителями, а разнесением block/counter геометрии и
  target caps. SCRUM-859 split stationary deploy/summon loops into stage pulse,
  support totem, turret DPS, repair chain, and mine grid. SCRUM-860 added
  Assassin-only capped kill-growth without adding a new vampirism/sustain loop.
- SCRUM-469 закрыл SCRUM-453 optimum-выбросы: актуальный `Lvl20 optimum`
  `relative_score` держится в диапазоне `0.938..1.097`, Base lvl1 — в
  `0.982..1.010`, Lvl20 random avg не имеет HIGH/LOW-флагов. Остаточные
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
