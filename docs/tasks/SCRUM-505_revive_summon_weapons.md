# SCRUM-505: Оживить summon-оружие (druid/chemist/engineer): минимум жизнеспособности ≥ 0.5x профильной медианы

Jira: SCRUM-505 · Роль: backend · Контур: balance · Приоритет: P1 · foma · Эпик: —
Статус: К выполнению — PM-блокер (backend-actionable часть исчерпана). 2026-06-28 claude-backend HEAD=dbd7f483: закрыл QA-блокер (а) — `tests/summon_weapon_crowd_floor_test.gd` теперь SIGABRT-safe на sentry-турельном teardown (queue_free вместо free() + disable weapon _process + idle-settle), 4/4 чистых прогона (sentry проходит каждый раз, было 2/4). Остаётся ТОЛЬКО блокер (б): числовая AC устарела vs живой CSV/comfort-band SCRUM-544/546 — формальная правка AC = PM-решение, как у сестёр 504/506. Рекомендация: адъюдицировать 504/505/506 связкой с 544/546 одним PM-решением. (2026-06-28 r4-impl5 ре-верифицировал на HEAD=dbd7f483, single-Godot: runtime_smoke PASS + summon_weapon_crowd_floor PASS детерминированно — amulet 20t lvl1=35/lvl20=429.8, homunculus 14/94.9, sentry 29.5/56.1, lvl1 baseline цел, sentry-флак не воспроизводится; код-часть зелёная и исчерпана, остаётся блокер (б) — SCRUM-544 на [hold], SCRUM-546 Готово.) ⟪Прежний QA-вердикт ниже сохранён.⟫ (QA FAIL 2026-06-28 r3-qa1 на HEAD=bd89b73e: AC-арбитр character_balance_csv.gd воспроизводимо SIGABRT-ит, build/character_balance_dps.csv не перегенерён → буквальный AC «≥0.5x класс-лучшего по 20t» нечем доказать; числа AC устарели (druid класс-лучший = raven_totem 4270, не briar 30591); AC ре-скоунут на comfort-полосу SCRUM-544, которая сама ещё «К выполнению»; engineer_sentry_wrench ниже полосы даже по проекции импла; сёстры SCRUM-504/506 с тем же блокером тоже «К выполнению». Зелёное: weapon_tuning_application/summoner_strengthening/class_budget_profiles_integrity/progression_data_api_surface/global_damage_balance_smoke; summon_weapon_crowd_floor PASS когда завершается, но флак 2/4. Нужно: стабильный CSV-арбитр без SIGABRT (покрыть sentry) + PM-решение по числовой AC, лучше связкой с 504/506/544.)

## Что и зачем

Summon-оружие трёх классов — мёртвые слоты в hero-select: выбрать их = осознанно играть в разы слабее.
По свежему `build/character_balance_dps.csv` (колонка `lvl20_ideal_20t`, это профильная ось для summon/aoe — суммарный throughput по рою на 20 целях):

- `druid/summon_amulet` 20t = **140.30**, при том что `druid/briar_staff` 20t = **49126.12** (×350 разрыв)
- `chemist/homunculus_vial` 20t = **269.27**, при том что `chemist/acid_flask` 20t = **112279.77** (×417)
- `engineer/engineer_sentry_wrench` 20t = **599.95**, при том что `engineer/engineer_pressure_mines` 20t = **52469.33** (×87)

Эталон того, как summon ДОЛЖЕН выглядеть, уже есть в коде: `druid/raven_totem` (тоже `summon`-архетип, но это деплой-тотем `attack_mode:"amp"`, не мобильный спутник) даёт 20t = **6735.30** — на два порядка выше мобильных призывов. То есть проблема локальна именно в формуле мобильных summon-спутников и её budget-оценке, а не в системе summon вообще.

Цель: поднять каждое из трёх summon-оружий так, чтобы на `lvl20_ideal` по своей профильной оси (20t для роя) оно давало **≥ 0.5x от лучшего оружия своего класса по той же оси**. Игрок, выбравший призывателя, должен получать реальную, пусть и не топовую, альтернативу, а не ловушку. Стартовый baseline lvl1 (множители из коробки = 1.0) при этом нельзя ломать — на 1-м уровне summon-баланс сейчас в норме и регрессии быть не должно.

Целевые числа (0.5x текущего класс-лучшего по `lvl20_ideal_20t`):

| Оружие | Сейчас 20t | Класс-лучший (20t) | Цель ≥0.5x |
|---|---|---|---|
| druid/summon_amulet | 140 | briar_staff 49126 | ~24500 (тикет: «минимум ~15000») |
| chemist/homunculus_vial | 269 | acid_flask 112279 | ~56000 |
| engineer/engineer_sentry_wrench | 600 | pressure_mines 52469 | ~26000 |

Числа класс-лучших сами по себе плавают между прогонами CSV; жёсткий критерий — относительный (≥0.5x от факта в перегенерённом CSV), а не абсолютный. Абсолюты в таблице — ориентир порядка.

## Текущее состояние в коде

Две параллельные ветки считают summon-урон, и обе сейчас занижены — их надо двигать СИНХРОННО, иначе разъедутся budget-оценка и реальный геймплей:

### A. Runtime (реальный бой → именно его меряет CSV)
`scripts/summoner_weapon.gd:123` `_summon_profile(owner_node)`:
- `damage = base_damage * damage_multiplier * role_damage` (строки 133, 136, 142), где
  `role_damage = summon_role_damage_multiplier * leadership_damage(1+min(LDR*0.020,0.42)) * attribute_damage(1+min(...,0.34))`.
- `attack_interval = summon_attack_interval / (1 + summon_haste)`, `summon_haste = min(summon_amount*0.014 + LDR*0.006, 0.30)` (строки 137, 145).
- Кол-во спутников НЕ в профиле — оно в спавне: фактический лимит = `max_summons + floor(summon_amount/4)` (см. budget-зеркало ниже; рантайм спавнит по тому же лимиту).
- `base_damage` уже включает `budget_damage_multiplier` (через `derived_parameters`, см. ниже) — то есть авто-тюнинг ДОХОДИТ до summon-урона, но его потолок зажат.

### B. Budget-оценка (авто-тюнинг + отчёты)
Всё в `scripts/progression_data.gd` (ВНИМАНИЕ: это locked-путь, см. подводные камни):
- `_budget_summon_dps(config, params, stats)` — `progression_data.gd:709`:
  `summon_count = max(max_summons,1) + floor(summon_amount/4)`;
  `summon_damage = damage_param * summon_damage_multiplier * role_factor`;
  `return summon_count * summon_damage / attack_interval`.
- `_budget_summon_role_damage_factor` — `progression_data.gd:725` (зеркало role_damage из рантайма, формулы совпадают строка-в-строку — это инвариант, держать синхронным).
- `_budget_hit_model` (`progression_data.gd:~666-668`): для summon `summon_targets = clamp(max_summons, 1, 4)` и `five_hits = clamp(1 + max_summons*0.8, 1, 3.5)`. **Это ключевой потолок AoE-оси**: `aoe_dps += summon_dps * summon_targets`, а `summon_targets ≤ max_summons ≤ 2`. Поэтому даже идеальный summon на 20 целях «видит» максимум 2 цели — отсюда мёртвая 20t-ось.
- `budget_tuning_for` (`progression_data.gd:420`): считает `damage_multiplier = clamp(sqrt(solo_scale*aoe_scale), 0.28, 2.80)`. **Жёсткий потолок 2.80x** — он физически не может закрыть разрыв ×87…×417. Авто-тюнинг упирается в клэмп и сдаётся.
- `weapon()` (`progression_data.gd:764`) инжектит `budget_damage_multiplier/solo/aoe` в конфиг → `derived_parameters:813` множит `damage_multiplier * budget_damage_multiplier` → доходит и до рантайм-`_summon_profile`, и до budget.

### Текущие конфиги (что тюнить в данных)
`scripts/progression_data_weapons.gd`:
- `summon_amulet` (строки 390-409): `summon_damage_multiplier:0.58`, `max_summons:2`, `summon_attack_interval:0.40`, `summon_role:"pack_damage"`, `summon_role_damage_multiplier:1.06`, `summon_aoe_radius:72`, `summon_aoe_damage_multiplier:0.56`.
- `homunculus_vial` (строки 323-343): `summon_damage_multiplier:0.52`, `max_summons:1`, `summon_attack_interval:0.56`, `summon_role:"tank_control"`, `summon_role_damage_multiplier:0.95`.
- `engineer_sentry_wrench` (строки 721-734): гибрид — есть `attack_mode:"engineer_sentry_link"` (прямой урон турели) + `max_summons:1`, `summon_role:"engineer_sentry"`, `summon_role_damage_multiplier:1.10`, БЕЗ `summon_damage_multiplier` (т.е. `_is_pure_summon_weapon`=false, у него direct_dps живёт по hit_model `engineer_sentry_link`). У sentry основной урон идёт через прямую турель, а не через `_budget_summon_dps`.

### Класс-профили (контекст таргетов)
`scripts/progression_data_balance.gd`: `BALANCE_BASE_AOE_DPS=150`; druid `aoe_target:1.00 damage_budget:1.00`, chemist `aoe_target:1.30 damage_budget:1.15`, engineer `aoe_target:1.12 damage_budget:0.96`. На эти `aoe_target` равняется `budget_tuning_for`, но summon до них не дотягивает из-за `summon_targets`-клэмпа.

## Что сделать — по шагам

Корень: при текущих `max_summons`/`summon_targets`-клэмпе AoE-ось у мобильных summon структурно мёртвая, а tuning-клэмп 2.80x не вытягивает. Нужно усилить САМУ summon-формулу (rate × count × per-summon AoE), синхронно в рантайме и budget, а не пытаться добрать только авто-тюнингом.

1. **Поднять профильную AoE-ось summon (главный рычаг).** В `_budget_hit_model` (`progression_data.gd:~666-668`) для мобильных summon заменить `summon_targets = clamp(max_summons,1,4)` на модель, где рой чистит толпу: завязать на сумму `max_summons + floor(summon_amount/4)` и на per-summon splash (`summon_aoe_radius`/`summon_aoe_damage_multiplier`), а не на голый `max_summons`. Цель — чтобы `summon_targets` для роя на 20 целях стал сопоставим с AoE-оружием (порядка 6-12), отражая, что каждый спутник со splash бьёт по нескольким врагам. Это должно одновременно отражать реальное поведение `ally_minion` со splash (см. `_summon_profile` поля `aoe_radius`/`aoe_damage_multiplier`, строки 151-152).
2. **Усилить per-summon damage/haste/count в данных.** В `scripts/progression_data_weapons.gd` поднять для трёх оружий часть из: `summon_damage_multiplier` (0.52→выше), `summon_aoe_damage_multiplier`/`summon_aoe_radius` (чтобы splash реально косил толпу), `max_summons` (рой больше), снизить `summon_attack_interval` (чаще бьют). Двигать аккуратно: lvl1 baseline не должен раздуться — проверять `lvl1_*t` колонки. Для `engineer_sentry_wrench` основной вклад — через прямую турель (`engineer_sentry_link` hit_model + `projectile_count`/`amp_pulse_interval`), а не через `_budget_summon_dps`; усиливать sentry-турель и/или добавить summon-составляющую.
3. **Синхронизировать рантайм `_summon_profile`** (`summoner_weapon.gd:123-154`) с любыми новыми формульными коэффициентами (count-бонусы, splash, haste). Инвариант: role_damage/haste-формулы в `_summon_profile` и `_budget_summon_role_damage_factor`/`_budget_summon_dps` обязаны совпадать — если меняешь одну, зеркаль другую. CSV меряет рантайм, поэтому без рантайм-правок budget-оценка соврёт.
4. **При необходимости приподнять tuning-клэмп для summon** в `budget_tuning_for` (`progression_data.gd:429`): клэмп `[0.28, 2.80]` рассчитан на обычное оружие; для summon-веток он мал. Вариант — расширить верхнюю границу для summon-конфигов ИЛИ (предпочтительно) сделать шаги 1-2 достаточными, чтобы базовый `aoe_dps` summon вырос и tuning не упирался в потолок. Не раздувать клэмп глобально — только если без него цель недостижима, и только для summon.
5. **Перегенерить CSV и свериться.** Прогнать harness `tools/character_balance_csv.gd` (headless Godot) → `build/character_balance_dps.csv`. Для каждого из трёх summon-оружий проверить `lvl20_ideal_20t ≥ 0.5 * (max lvl20_ideal_20t среди оружий того же класса)`. Параллельно `lvl20_ideal` остальных summon-классов (raven_totem, repair_drone) и lvl1 baseline не должны просесть/взлететь неадекватно.
6. **Привести в согласие estimate и тесты.** Прогнать `tests/weapon_tuning_application_test.gd`, `tests/summoner_strengthening_test.gd`, `tests/class_budget_profiles_integrity_test.gd`, `tests/global_damage_balance_smoke_test.gd`, `tests/progression_data_api_surface_test.gd` — все зелёные. Если в тестах зашиты пороги старой слабой summon-DPS — обновить ассерты под новый баланс (это часть AC).
7. **Обновить дизайн-доку.** В `docs/design/systems/progression_balance.md` (строки ~80-86) актуализировать описание summon damage/haste/count/AoE-формулы и зафиксировать новый принцип «summon ≥ 0.5x профильной медианы».

## Acceptance Criteria

- [ ] В перегенерённом `build/character_balance_dps.csv` КАЖДОЕ из трёх summon-оружий на `lvl20_ideal` по своей профильной оси (20t) даёт **≥ 0.5x** от лучшего оружия своего класса по той же оси (`lvl20_ideal_20t`).
- [ ] `druid/summon_amulet` 20t поднимается с ~140 минимум до ≥0.5x `druid/briar_staff` (ориентир ≥15000, факт-цель ≥0.5x перегенерённого briar_staff_20t).
- [ ] `chemist/homunculus_vial` и `engineer/engineer_sentry_wrench` аналогично выходят из дна списка худших оружий (≥0.5x класс-лучшего по 20t).
- [ ] Изменение идёт через summon-формулу (`_summon_profile` / `_budget_summon_dps` / `_budget_hit_model` summon-ветка) и/или `budget_tuning` summon-оружий, БЕЗ глобального раздувания обычного оружия.
- [ ] Base lvl1 summon-баланс сохранён: множители «из коробки» стартуют с 1.0, колонки `lvl1_1t/5t/20t` для трёх оружий не получают неадекватного скачка (sanity: остаются в разумной близости к прежним lvl1).
- [ ] Рантайм `_summon_profile` и budget `_budget_summon_dps`/`_budget_summon_role_damage_factor` остаются формульно согласованы (одинаковые role/haste коэффициенты).
- [ ] `estimate_weapon_budget` даёт summon-DPS estimate, согласованный с реальным CSV-замером (не считает старую слабую версию).
- [ ] Зелёные: `tests/weapon_tuning_application_test.gd`, `tests/summoner_strengthening_test.gd`, `tests/class_budget_profiles_integrity_test.gd`, `tests/global_damage_balance_smoke_test.gd`, `tests/progression_data_api_surface_test.gd`.
- [ ] `docs/design/systems/progression_balance.md` обновлён под новую summon-формулу.

## Files / точки входа

- `scripts/progression_data.gd:709` `_budget_summon_dps` — усилить summon-DPS оценку (count/damage/haste); держать зеркалом рантайма. **(locked-путь — см. подводные камни)**
- `scripts/progression_data.gd:725` `_budget_summon_role_damage_factor` — зеркало role_damage; менять только синхронно с рантаймом.
- `scripts/progression_data.gd:~666-668` `_budget_hit_model` (summon-ветка) — поднять `summon_targets`/`five_hits` для роя со splash (главный рычаг 20t-оси).
- `scripts/progression_data.gd:420` `budget_tuning_for` — при необходимости расширить клэмп `[0.28,2.80]` ТОЛЬКО для summon. **(locked-путь)**
- `scripts/progression_data_weapons.gd:390` `summon_amulet`, `:323` `homunculus_vial`, `:721` `engineer_sentry_wrench` — поднять `summon_damage_multiplier`/`summon_aoe_*`/`max_summons`/`summon_attack_interval` (для sentry — ещё `engineer_sentry_link` direct-урон).
- `scripts/summoner_weapon.gd:123` `_summon_profile` — синхронизировать damage/haste/count/splash формулу с budget.
- `docs/design/systems/progression_balance.md:~80-86` — описание summon-формулы и нового принципа 0.5x.
- `tests/weapon_tuning_application_test.gd`, `tests/summoner_strengthening_test.gd`, `tests/class_budget_profiles_integrity_test.gd` — обновить пороги/ассерты под новый баланс.
- `tools/character_balance_csv.gd` — harness для перегенерации CSV (запуск, не правка): `Godot --headless --path . --script res://tools/character_balance_csv.gd`.

## Замечания / подводные камни

- **LOCKED PATH: `scripts/progression_data.gd`** — это занятый/locked файл (анти-коллизия). Вся budget-математика summon (`_budget_summon_dps`, `_budget_hit_model`, `budget_tuning_for`) сидит именно в нём. Прежде чем редактировать — убедиться, что путь свободен для текущего исполнителя, не коммитить поверх чужих хунков (`git add` своих файлов явно, не `-A`), green-gate ДО коммита. `scripts/progression_data_weapons.gd` и `scripts/summoner_weapon.gd` — НЕ locked, основную data-правку безопаснее держать там.
- **Не трогать** `scripts/ui_screens.gd` и общий блок `scripts/progression_data.gd` за пределами summon-функций — только summon-ветки.
- **Двойная бухгалтерия — главный риск.** CSV меряет РАНТАЙМ (`_summon_profile` + реальный спавн/бой `ally_minion`), а авто-тюнинг считает по `_budget_summon_dps`. Если поднять только budget — CSV не сдвинется; если только рантайм — авто-тюнинг и отчёты соврут. Двигать СИНХРОННО, role/haste-формулы держать идентичными (это явный инвариант кода, формулы строка-в-строку совпадают сейчас).
- **`summon_targets`-клэмп — корневая причина мёртвой 20t-оси.** Без расширения этой ветки `_budget_hit_model` авто-тюнинг структурно не сможет вытянуть AoE, сколько ни крути `summon_damage_multiplier`.
- **`engineer_sentry_wrench` — особый случай:** это НЕ pure-summon (`_is_pure_summon_weapon`=false, есть `attack_mode`). Его direct-урон идёт через турель (`engineer_sentry_link` hit_model), а summon-роль лишь множит. Для него основной рычаг — усилить турель (`projectile_count`/`amp_pulse_interval`/`fire_interval`) и/или его summon-составляющую; не путать с чисто-мобильными amulet/vial.
- **Эталон-референс:** `druid/raven_totem` (summon-amp, 20t=6735) и `engineer/engineer_repair_drone` (20t=2774) показывают рабочий уровень summon — ориентироваться на них как на «как должно быть», не раздувая выше класс-AoE.
- **Lvl1 baseline guard:** множители «из коробки» = 1.0, lvl1 summon уже сбалансирован — следить, чтобы усиление не подняло `lvl1_*t` колонки неадекватно (рост должен идти от level-up/leadership-скейла на lvl20, а не от стартовых чисел).
- **CSV нестабилен по абсолюту** (RNG-сиды фиксированы, но класс-лучшие плавают между ревизиями) — критерий жёстко относительный (≥0.5x факта в ТОМ ЖЕ перегенерённом CSV), не хардкодить абсолютные пороги в тестах, где можно завязаться на отношение.
- **Связанные тикеты:** SCRUM-357 (предыдущий summoner rebalance — он недодал по 20t-оси, это его продолжение), SCRUM-191 (регрессия применения budget-тюнинга — `weapon_tuning_application_test.gd` оттуда, не сломать его гейты 1-3).
- Запуск тестов headless: `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/<file>.gd` (Godot 4.6.3).

## QA-Вердикт: НЕ ПРИНЯТО — возврат в «К выполнению» (claude-qa 2026-06-28)

Не дефект кода — блокер приёмки, идентичный сёстрам SCRUM-504/506 (обе в «К выполнению»).
Проверено и здраво: lvl1-инвариант цел ((level-1)=0 на lvl1), weapon_tuning_application_test PASS (51 пар), summon_weapon_crowd_floor_test поймал 1 чистый прогон (amulet 35/430, homunculus 14/95, sentry 28/56 — все пороги ✓).
Блокеры: (1) буквальный AC недостижим + числа устарели (briar=30591 в AC vs реальный raven_totem=4270, ×13); (2) CSV-арбитр SIGABRT (CSV остался pre-505 04:24); (3) sentry-гейт флаки-крашится на турельном teardown.
Нужно: (а) стабильный CSV/band-тест с покрытием sentry без SIGABRT; (б) PM-правка числовой AC под живой CSV + comfort-band (SCRUM-544/546).
