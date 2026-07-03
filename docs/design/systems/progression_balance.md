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
- `guitarist` keeps AoE/control identity but uses a fairer solo target.
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
  ~42-43 уровня; новая кривая держит ориентиры пользователя: после 5-6 боев Act
  1 около 14-15 уровня, после Act 2 около 24, после 20 боев полный забег около
  32 уровня. Guard: `tests/monster_xp_pressure_pacing_test.gd`.

## Act Scaling

- Runtime progression uses `current_act` (`1..3`) plus act-local `route_stage`.
- Route navigation keeps `route_stage` local to the current map (`0..10`) so each
  act can generate a fresh route and preserve existing route reachability rules.
- Economy, drops, round duration and enemy/boss scaling read
  `route_scaling_stage() = route_stage + (current_act - 1) * 4`. This gives Act
  2/3 controlled pressure and reward growth without the runaway curve of treating
  all 33 route rows as one exponential stage chain.
- SCRUM-853 enemy pressure also reads `route_scaling_stage()` plus wave index and
  elapsed combat time, so Act 2/3 receive denser waves, tougher enemies and more
  frequent advanced mobs without changing route reachability.
- Autosave persists `current_act`, route nodes, selected route history, shop
  state and player snapshot. Continue restores Act 2/3 map checkpoints with the
  same build state.

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
- SCRUM-854: Doctor is the explicit exception to the universal sustain pool: `ProgressionData.is_reward_relevant()` filters Doctor out of external regeneration/vampirism/lifesteal rewards in level-up, artifact reward pool, shop, elite artifact choices and start boons. Doctor sustain remains only on his own weapons (`restore_potion`, `plague_syringe`, `bone_saw`) and their drain caps.
- SCRUM-683 выводит видимый effect-preview прямо на reward card, а не только в
  tooltip. Для базовых характеристик preview строится от текущего snapshot
  статов и `STAT_DERIVED_PREVIEW` / `ProgressionData.derived_parameters()`;
  для direct modifier rewards runtime применяет модификаторы к копии активных
  modifiers и сравнивает before/after derived parameters активного героя и
  оружия. Поэтому числа в карточке берутся из текущих формул баланса и не
  дублируются hardcoded UI-текстом.

## Artifacts

- `player.artifacts` хранит `{id, title}` с совместимостью со старым title-only форматом.
- HUD показывает artifact icons в `ArtifactHudRow`.
- Pause stats menu имеет отдельный блок «Артефакты».
- Artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png`.
- `class_affinity` теперь означает тематику/источник артефакта, а не запрет. `affinity_mods` применяются любому классу через интерпретацию текущего героя.
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

## Random Events EV (SCRUM-494)

Случайные события (`scripts/event_data.gd`, применение в
`ui_screens._apply_event_choice/_resolve_event_choice_outcome`,
наградные множители боя — `combat_director._grant_combat_completion_rewards`).
EV-ребаланс свёл каждую опцию к `EV = P(успех) × награда − стоимость/штраф`.

**Принцип:** рискованные/платные опции дают заметно больший апсайд (статы,
артефакты, run-long моды), безопасные — скромную гарантию (мелкое золото/хил).
Награды-статы/артефакты/моды предпочтительны для риск-опций, т.к. их
gold-equivalent растёт вместе с экономикой; плоское `money` со стадией не
масштабируется (а `cost_money` — масштабируется через `stage_scaled_cost`),
поэтому крупное плоское золото на риск-опции не вешаем.

**Шкала ценности (gold-value, GV, ранний забег):** 1 GV = 1 золото; 1 стат ≈
20 GV (цена покупки атрибута stage0 ≈ `ceil(18×1.10)`); random_artifact ≈ 45 GV
(взвешенное среднее `COST_BY_TIER` {1:30,2:55,3:95} по `TIER_WEIGHTS`);
run-long damage/attack_speed ≈ 3 GV/1%; xp_gain ≈ 1.5 GV/1%; heal ≈ 0.35 GV/1%
(контекстно); −HP ≈ 0.45 GV/1%. P(check) ≈ 0.55 при difficulty 7, ≈ 0.45 при 8
(база раннего забега). combat-опции дают полный лут боя + completion-бонус
(`elite`: 10+stage×4 зол / 7+stage×2 xp; `battle`: 4+stage×2 / 3+stage, ×
event-множители) + `post_combat`.

| Событие / опция | Тип | Cost/Risk | Reward (GV) | EV (GV) |
| --- | --- | --- | --- | --- |
| bard / pay_ballad | платная | 18 зол | +12% atk_speed (36) | +16 |
| bard / sing_yourself | проверка kn7 | −1 Знание при провале | +1 Зн/Воспр/Лид (60) | +24 |
| bard / walk_away | безопасная | — | 6 зол +4% xp (12) | +12 |
| altar / blood_price | платная (HP) | −30% HP (−14) | артефакт (45) | +31 |
| altar / defile | риск (elite) | элита 1.12 HP | элит-лут +50% зол/+25% xp +Сила/Вынос (40) | топ-риск |
| altar / quiet_prayer | безопасная | −10% HP (−5) | +1 Выносливость (20) | +15 |
| ambush / stand_ground | риск (battle) | бой 1.18 HP | бой-лут +50% зол +Сила (20) | риск+ |
| ambush / break_through | проверка agi8 | −15% HP при провале | +1 Лов +6% atk_spd (38) | +13 |
| well / throw_coin | платная (рандом) | 8 зол | хил30%/28 зол/бой (avg ~19) | +10 |
| well / listen | проверка per7 | провал +5 зол | +1 Восприятие (20) | +13 |
| mercenary / help | платная | 20 зол | +1 Лид +1 призыв (35) | +13 |
| mercenary / loot | безопасная (жадная) | −1 Знание (−20) | 30 зол | +10 |
| mercenary / bind_wounds | проверка end7 | −6 зол при провале | defense_flat 0.06 (18) | +7 |
| goblin / buy_bag | риск+платная | 12 зол | артефакт/8 зол/мимик (avg ~25) | +13 |
| goblin / haggle | проверка per8 | −10 зол при провале | 30 зол | +7 |
| hot_spring / full_rest | безопасная (трейд) | след. бой 1.25 HP (−15) | полный хил (35) | +20 (контекст) |
| hot_spring / quick_dip | безопасная | — | хил 35% (12) | +12 |
| mirror / duel | риск (elite) | элита 1.05 HP | элит-лут +30% зол +Инт +8% урон (44) | топ-риск |
| mirror / study | проверка int8 | −12% HP при провале | +1 Инт +8% урон (44) | +17 |
| guardian / answer_riddle | проверка kn8 | бой при провале | артефакт (45) | +26 |
| guardian / fight_guardian | риск (battle) | бой 1.25 HP | бой-лут +30% зол +Сила/Вынос (40) | риск+ |
| graveyard / dig | риск (рандом) | бой 1.22 HP | артефакт ИЛИ бой+Вынос (avg ~33) | +33 |
| graveyard / pay_respects | безопасная | — | +1 Вынос +хил15% (24) | +24 |
| star / take_shard | платная (HP) | −12% HP (−5) | +2 Энергия (40) | +35 |
| star / observe | проверка int7 | −8% HP при провале | +1 Энергия +1 Знание (40) | +20 |
| dummies / speed_trial | проверка agi7 | −10% HP при провале | +1 Лов +8% atk_spd (44) | +22 |
| dummies / power_trial | проверка str7 | −10% HP при провале | +1 Сила +8% урон (44) | +22 |

Разнообразие исходов сохранено (статы, артефакты, моды, хил, золото, бои) —
не всё сведено к золоту. Тултипы в `event_data.gd` синхронизированы с
фактическими эффектами; `event_data_smoke_test.gd` + балансные/economy смоуки
зелёные.

## Meta Progression

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

## Known Balance Risks

- Точный паритет clear speed Темного мага/Гитариста с Берсерком требует ручного плейтеста.
- SCRUM-856 зафиксировал identity/playfeel риск поверх зелёных numeric gates:
  delayed AoE, AoE projectile, chain/split/pierce, deploy/summon и sustain
  семейства должны быть разведены механиками. Особенно важны `doctor/restore_potion`
  (текущий худший 20-target CCT +22%, но PASS), hard-clamped summons/DoT
  (`druid/summon_amulet`, `chemist/homunculus_vial`, `assassin/venom_wire`) и
  cap-pinned weapons (`hammer`, `elementalist_prism_focus`,
  `elementalist_meteor_core`, `dark_book`, `tower_shield`, `holy_flail` и др.).
- SCRUM-469 закрыл SCRUM-453 optimum-выбросы: актуальный `Lvl20 optimum`
  `relative_score` держится в диапазоне `0.938..1.097`, Base lvl1 — в
  `0.982..1.010`, Lvl20 random avg не имеет HIGH/LOW-флагов. Остаточные
  различия остаются предметом ручного feel/playtest, а не блокером формульного
  баланса.
- Performance/code review считает текущие числа пригодными для demo, но баланс должен продолжать уточняться после игровых прогонов.

## SCRUM-541 Secret Boss Progression Gate

The secret boss no longer uses the old low-damage/key-artifact SCRUM-619 gate.
`MetaProgression.secret_encounter_unlocked_for_level(run_level)` unlocks the
post-Act-3 secret encounter only when the selected run Ascension is the current
maximum (`MAX_ASCENSION_LEVEL`, 5 after SCRUM-516).

Flow:

- Act 3 route boss remains the normal boss id from the route node.
- If that boss is defeated below max Ascension, the run ends with the normal
  victory flow.
- If defeated at max Ascension, `CombatDirector` immediately starts
  `secret_ascension_boss` as a follow-up boss encounter.
- The one-time persistent secret reward still uses
  `record_secret_boss_victory`; repeat wins do not grant the bonus twice.

Balance benchmark, Act 3 L5/stage 18: secret boss HP is about `47.6k`.
L20 optimum class kits estimate `121.5s..231.8s` TTK by 1-target DPS range;
L20 random-average kits estimate `347.3s..559.6s`, so the fight is intended as
a brutal capstone for tuned builds rather than a global class rebalance.
