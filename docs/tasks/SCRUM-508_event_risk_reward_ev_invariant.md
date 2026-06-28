# SCRUM-508: Выровнять риск-награду random-событий: ожидаемая ценность опасных веток ≥ безопасных

Jira: SCRUM-508 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: —
Статус: Готово

## QA 2026-06-28

Статус: PASSED -> Jira `Готово`.

Проверено Codex QA в worktree `qa_508_codex190526` на `origin/dev` после commit
`3b131ea9`:
- `tests/event_data_smoke_test.gd` — PASS: 28 событий, EV-инвариант проверен на
  12 событиях с парой risky+safe.
- `tests/event_risk_reward_ev_test.gd` — PASS: 17 событий с парой
  риск/безопасная, 0 нарушений.
- `tools/route_economy_xp_model.gd` — PASS: секция
  `## Event Risk/Reward EV` сгенерирована, строк `VIOLATES` нет.
- `tests/runtime_smoke_progression_economy_test.gd` — PASS после headless
  import: общий `RouteEconomyModel.event_ev_rows()` даёт 17 событий, все
  `EV(risk) >= EV(safe)`.

Примечание: `tools/godot_gate.py` на Windows не запустился из-за отсутствия
`fcntl`, поэтому Godot-проверки выполнены напрямую через Godot 4.7 console.
Оставшиеся UID duplicate warnings после импорта относятся к существующим
reference/assets character parts и не связаны с SCRUM-508.

## Что и зачем

В `scripts/event_data.gd` живёт набор `RANDOM_EVENTS` — ветвящийся контент случайных
событий забега. У многих событий есть «безопасная» ветка (гарантированный мелкий
профит/проверка стата) и «рискованная»/боевая ветка (`"risk": true`, бой с
повышенным `enemy_health_multiplier`, либо `random_outcomes` с шансом мимика).

Проблема геймдизайна: рискованная ветка не окупает добавочный риск. Игрок,
просчитывающий EV (expected value), рационально всегда выбирает безопасную ветку,
и «рискованный» контент становится мёртвым — никто его не берёт. Конкретные
нарушители из тикета:

- **hot_spring / full_rest**: полный хил + (в тултипе обещан endurance, но в коде
  его нет) и при этом ШТРАФ — следующий бой `enemy_health_multiplier 1.25`. Против
  `quick_dip` (35% хила без минуса) это чистый проигрыш по EV: full_rest = больше
  хила, но с отрицательным довеском, без всякой компенсации. Это «risk» без награды.
- **cursed_altar / defile**: требует элитного боя (`enemy_health_multiplier 1.12`)
  за `money×1.5 / xp×1.25` + `strength/endurance +1`. Прибавка к деньгам/опыту от
  множителей мизерная относительно базовой элитной награды и слабее одного
  boss-дропа — добавочный риск элитного боя не окупается.
- **goblin_lottery / buy_bag**: стоит 12 золота, в `random_outcomes` 1/3 шанс
  мимика (`enemy_health_multiplier 1.20`), 1/3 артефакт, 1/3 жалкие 8 золота.
  Против гарантированного `haggle` (проверка Восприятия 8 → +30/−10 золота) EV
  лотереи под вопросом из-за стоимости входа и слабого денежного исхода.

Цель: ввести **табличный инвариант** — для каждого события EV рискованной/боевой
ветки в золото-эквиваленте должна быть ≥ EV безопасной ветки того же события
(желательно с положительной «премией за риск», пропорциональной добавочной
опасности). Подкрутить нарушающие множители/награды в `event_data.gd`, посчитать
EV-таблицу в отчёте route-economy и закрепить инвариант smoke-тестом.

Ожидаемый результат для игрока: рискованные ветки становятся осмысленным выбором —
больший риск даёт пропорционально большую ожидаемую награду, а не скрытый штраф.

## Текущее состояние в коде

### `scripts/event_data.gd` (1–115)
`const RANDOM_EVENTS` — массив из 11 событий. Ветка описывается dict’ом choice с
ключами-эффектами. Релевантные для EV:
- `money` (плоский +золото), `cost_money` (−золото), `heal_percent` (доля хила),
- `stats` / `post_combat.stats` (прибавки атрибутов),
- `mods` (run-модификаторы, напр. `attack_speed_multiplier`, `damage_multiplier`,
  `enemy_health_multiplier` как штраф),
- `health_percent_cost` (−доля HP, «риск-урон»),
- `random_artifact: true` (случайный артефакт),
- `combat` (`type`, `enemy_health_multiplier`, `money_multiplier`, `xp_multiplier`),
- `random_outcomes` (массив равновероятных исходов, среди них бывает `combat`),
- `check` (проверка стата → ветви `success` / `failure`).

Конкретные нарушители (строки):
- `cursed_altar/defile` — строка 20: `combat {type:"elite", enemy_health_multiplier:1.12, money_multiplier:1.5, xp_multiplier:1.25}`, `post_combat.stats {strength:1, endurance:1}`. Безопасная ветка `quiet_prayer` (строка 21): `stats {endurance:1}`, `health_percent_cost:0.10`.
- `goblin_lottery/buy_bag` — строка 57: `cost_money:12`, `random_outcomes [{random_artifact}, {money:8}, {combat enemy_health_multiplier:1.20, money_multiplier:1.4}]`. Безопасная `haggle` (строка 58): check Восприятие 8 → `{money:30}` / `{cost_money:10}`.
- `hot_spring/full_rest` — строка 66: `heal_percent:1.0`, `mods {enemy_health_multiplier:1.25}` (чистый штраф, никакой компенсации; обещанного в Jira endurance в коде НЕТ). Безопасная `quick_dip` (строка 67): `heal_percent:0.35`.

Прочие события с риск/боевыми ветками, которые тоже нужно прогнать через инвариант:
`road_ambush/stand_ground` (29), `old_well/throw_coin` (38, бой в random_outcomes),
`mirror_phantom/duel` (75), `stone_guardian/fight_guardian` (85),
`heroes_graveyard/dig` (93). События без рискованной ветки
(`wandering_bard`, `wounded_mercenary`, `fallen_star`, `training_dummies`) из
инварианта исключаются.

### Как эффекты резолвятся в рантайме (для калибровки EV-весов)
- `scripts/combat_director.gd:866` `_grant_combat_completion_rewards(event_combat)` —
  база награды боя: обычный бой `xp = 3 + route_stage`, `money = 4 + route_stage*2`;
  элитный `xp = 7 + route_stage*2`, `money = 10 + route_stage*4`. Множители события
  применяются ЧЕСТНО к обеим веткам (строки 880–886): `xp_multiplier`,
  `money_multiplier`, затем `post_combat` через `apply_reward`. То есть
  «combat-дроп» ветки = базовая награда боя × множители + post_combat.
- `scripts/combat_director.gd:938` `_run_enemy_health_multiplier()` — `enemy_health_multiplier`
  события множится на run-модификатор; это и есть мера «добавочного риска» боя.
- `scripts/player.gd:693` `apply_reward(reward)` — применяет `stats`, `mods`,
  `heal_percent`, артефакт. `_apply_reward_mods` (720): `*_multiplier` перемножаются,
  плоские суммируются. `enemy_health_multiplier` в `mods` оседает в `run_modifiers`
  как пер-забеговый штраф (full_rest именно так и наказывает следующий бой).

### `tools/route_economy_xp_model.gd` (1–339)
Детерминированная модель маршрута, пишет отчёт в `res://build/route_economy_xp_model.md`
(`REPORT_PATH`, строка 5). Сейчас НЕ моделирует random-события вовсе — только
battle/elite/boss/shop/rest/upgrade ноды (`_simulate_route`, 142). Использует
`ProgressionData.drop_class_rewards()`, `stage_scaled_cost()`, `shop_items()`. Это
правильное место добавить EV-таблицу событий: статический хелпер, который для
каждого события считает EV каждой ветки в золото-эквиваленте и дописывает секцию
в отчёт (`build_report`, 27 → `lines.append(...)` секций).

### `tests/runtime_smoke_progression_economy_test.gd` (1–34)
Главный runtime-смоук экономики/прогрессии. `_initialize()` инстанцирует
`Main.tscn`, гоняет батарею `_test_*`-проверок. Сюда (или в отдельный хелпер,
вызываемый отсюда) встанет ассерт инварианта EV(risk) ≥ EV(safe).

### Дополнительно
- `tests/event_data_smoke_test.gd` — изолированный валидатор структуры событий
  (типы боя, валидные статы, диапазоны чисел). Инвариант EV туда вписывается
  логически, но тикет явно называет `runtime_smoke_progression_economy_test.gd` как
  целевой файл теста — основной ассерт класть туда. event_data_smoke остаётся как
  структурный гейт (можно при желании добавить туда дублирующий лёгкий чек, но не
  обязательно).
- `scripts/progression_data_balance.gd:190` `DROP_CLASS_MULTIPLIERS` и `:184`
  `ECONOMY_PRICE_MULTIPLIER:=1.10` — числовая база для конвертации combat-дропа и
  цен в золото-эквивалент.

## Что сделать — по шагам

1. **Определить формулу EV-в-золото (золото-эквивалент ветки).** Зафиксировать
   набор условных весов как `const`-ы в `route_economy_xp_model.gd` (и продублировать
   в тесте, либо вынести в общий хелпер, чтобы тест и отчёт считали ОДНУ И ТУ ЖЕ
   функцию — anti-drift). Компоненты:
   - `+ money` (плоское золото) и `− cost_money`.
   - `+ heal_percent × HEAL_GOLD_PRICE` — условная цена 1.0 хила в золоте.
     Заземлить на магазинном `shop_heal` (`scripts/progression_data_shop.gd:7`:
     35% хила за 28 золота → ≈ 80 золота за 100% хила).
   - `+ stat_pickup × STAT_GOLD_VALUE` (для `stats` и `post_combat.stats`; суммарно
     по статам, отрицательные статы вычитаются).
   - `+ combat_drop` — ожидаемый дроп боя в золото-эквиваленте: базовая награда
     боя при опорном `route_stage` (взять фиксированный, напр. stage 4) × множители
     события (`money_multiplier`, и xp через `XP_GOLD_VALUE`) + post_combat.
   - `+ random_artifact × ARTIFACT_GOLD_VALUE` — заземлить на средней цене артефакта
     (`COST_BY_TIER` / средний tier из reward_pool).
   - `− risk_damage` — штраф риска: `health_percent_cost × HP_GOLD_PRICE`, а для
     боевых веток ещё «надбавка за опасность» от `enemy_health_multiplier`
     (напр. `(mult − 1.0) × DANGER_GOLD_PER_PCT`). `mods.enemy_health_multiplier`
     (штраф следующего боя у full_rest) учитывается тем же `DANGER_GOLD_PER_PCT`.
   - `random_outcomes`: EV = среднее по исходам (равновероятные), каждый исход
     прогоняется через ту же формулу.
   - `check`-ветки (success/failure): EV = взвешенное по вероятности успеха
     (вероятность прикинуть из `difficulty` против опорного стата; либо упростить до
     50/50 и задокументировать допущение).

2. **Посчитать EV-таблицу и найти нарушителей.** Реализовать в
   `route_economy_xp_model.gd` хелпер `static func event_ev_rows() -> Array` и
   секцию отчёта `## Event Risk/Reward EV` с колонками: Event, Branch, Type
   (safe/risk), EV(gold), Δ vs safe, Verdict (ok/violates). Прогнать руками
   (Godot --headless), убедиться, что hot_spring и cursed_altar помечены как
   нарушители — это валидирует формулу против тикета. Если формула НЕ ловит явных
   нарушителей из тикета — формула неверна, чинить веса до совпадения с дизайн-интуицией.

3. **Скорректировать `event_data.gd` нарушающих веток** (минимальными правками, не
   ломая structure-смоук и тултипы — описания держать в синхроне с числами):
   - `hot_spring/full_rest` (строка 66): либо убрать/смягчить штраф
     `enemy_health_multiplier`, либо добавить компенсирующую награду, чтобы
     EV(full_rest) ≥ EV(quick_dip). Привести описание в соответствие фактическим
     эффектам (сейчас в тултипе нет endurance — и в коде нет; не вводить рассинхрон).
   - `cursed_altar/defile` (строка 20): поднять `money_multiplier` / `xp_multiplier`
     и/или усилить `post_combat.stats`, чтобы EV ≥ EV(quiet_prayer) с премией за
     элитный бой (1.12). Обновить описание-тултип под новые числа.
   - `goblin_lottery/buy_bag` (строка 57): поднять денежный исход
     (`{money:8}` слишком мал) и/или `money_multiplier` боя/снизить `cost_money`,
     чтобы EV(buy_bag) ≥ EV(haggle).
   - Прогнать остальные risk-ветки (road_ambush, old_well, mirror_phantom,
     stone_guardian, heroes_graveyard) через таблицу; если кто-то нарушает —
     подправить аналогично. Не перетягивать: цель — EV(risk) ≥ EV(safe) с разумной
     премией, НЕ сделать риск-ветки гарантированно сильнейшими.

4. **Добавить smoke-тест инварианта** в
   `tests/runtime_smoke_progression_economy_test.gd`: новая проверка
   `_test_event_ev_risk_reward_invariant()`, вызванная из `_initialize()`. Для
   каждого события с парой safe/risk считать EV обеих веток ТЕМ ЖЕ хелпером, что
   и отчёт (импортировать `route_economy_xp_model.gd` или вынести общий калькулятор),
   и ассертить `ev_risk >= ev_safe` (можно с допуском/требуемой премией). `_fail` с
   именем события и обеими EV при нарушении. Зелёный прогон.

5. **Перегенерировать отчёт** route-economy и убедиться, что секция EV показывает
   все Verdict = ok.

## Acceptance Criteria

- [ ] Для каждого события из `RANDOM_EVENTS` с парой ветвей посчитана EV каждой
      ветки в золото-эквиваленте (`money + heal%×цена + stat-pickup + combat-дроп
      + artifact − cost − риск-урон`); таблица выводится в отчёте
      `res://build/route_economy_xp_model.md` (новая секция `## Event Risk/Reward EV`).
- [ ] Для каждого такого события EV risk/combat-ветки ≥ EV безопасной ветки
      (минимум hot_spring и cursed_altar/defile, нарушающие сейчас, — исправлены;
      goblin_lottery/buy_bag проверен и приведён к ≥).
- [ ] Скорректированы `money_multiplier` / `xp_multiplier` /
      `enemy_health_multiplier` и/или stat-награды нарушающих веток в
      `scripts/event_data.gd`; описания-тултипы синхронны новым числам.
- [ ] Добавлен/обновлён smoke-тест в
      `tests/runtime_smoke_progression_economy_test.gd`, проверяющий инвариант
      EV(risk) ≥ EV(safe) для всех событий; прогон зелёный.
- [ ] EV-калькулятор у отчёта и у теста — общий (одна функция), чтобы числа не
      разъезжались.
- [ ] `tests/event_data_smoke_test.gd` (структурный гейт) остаётся зелёным после
      правок (новые/изменённые числа в допустимых диапазонах, описания не пустые).
- [ ] Премия за риск положительная и пропорциональна добавочной опасности, но
      риск-ветки НЕ становятся доминирующими (без раздувания экономики забега).

## Files / точки входа

- `scripts/event_data.gd:20` — `cursed_altar/defile`: поднять
  `money_multiplier`/`xp_multiplier`/`post_combat.stats`; синхронизировать описание.
- `scripts/event_data.gd:57` — `goblin_lottery/buy_bag`: усилить денежный исход /
  снизить `cost_money` / поднять `money_multiplier`; синхронизировать описание.
- `scripts/event_data.gd:66` — `hot_spring/full_rest`: смягчить/убрать штраф
  `enemy_health_multiplier` или добавить компенсацию; синхронизировать описание.
- `scripts/event_data.gd:29,38,75,85,93` — остальные risk-ветки: проверить по
  таблице, править при нарушении.
- `tools/route_economy_xp_model.gd:27` `build_report()` — добавить секцию
  `## Event Risk/Reward EV`; новый хелпер `event_ev_rows()` + общий
  EV-калькулятор `static func _event_branch_ev(branch, stage)` с весами-`const`.
- `tests/runtime_smoke_progression_economy_test.gd:_initialize` — вызвать новый
  `_test_event_ev_risk_reward_invariant()`, использующий тот же EV-калькулятор.
- `scripts/combat_director.gd:866` `_grant_combat_completion_rewards` — справочно:
  базовые числа награды боя и применение множителей события (калибровка combat-дропа).
- `scripts/progression_data_balance.gd:184,190` — `ECONOMY_PRICE_MULTIPLIER`,
  `DROP_CLASS_MULTIPLIERS`: база для золото-эквивалента.
- `scripts/progression_data_shop.gd:7` `shop_heal` — заземление цены хила (35%/28g).

## Замечания / подводные камни

- **Anti-collision / locked paths**: `scripts/ui_screens.gd` и
  `scripts/progression_data.gd` — НЕ трогать (за другой полосой). Эта задача
  ограничена `scripts/event_data.gd`, `tools/route_economy_xp_model.gd`,
  `tests/runtime_smoke_progression_economy_test.gd` (+ возможно лёгкий чек в
  `tests/event_data_smoke_test.gd`). Константы баланса читать из
  `progression_data_balance.gd`, не модифицировать.
- **Тултипы = контракт с игроком.** Jira упоминает, что full_rest «даёт endurance»
  — в КОДЕ его НЕТ (heal_percent + штраф). Не верить тексту тикета слепо: эффекты
  брать из кода. При правке чисел обязательно править `description` ветки, иначе
  structure-смоук/игрок увидит рассинхрон. (Прецедент: combat_director:877–879
  чинил ровно такую ложь в тултипах defile/duel.)
- **Один источник истины для EV.** Если отчёт и тест считают EV двумя копиями
  формулы — они разъедутся при первой же правке весов. Вынести в один static-хелпер
  (в `route_economy_xp_model.gd`), тест импортирует его через `preload`.
- **Веса EV — допущения, документировать.** `HEAL_GOLD_PRICE`, `STAT_GOLD_VALUE`,
  `ARTIFACT_GOLD_VALUE`, `XP_GOLD_VALUE`, `HP_GOLD_PRICE`, `DANGER_GOLD_PER_PCT` —
  условные. Заземлять на реальные числа (shop_heal, COST_BY_TIER, базовая награда
  боя), а не выдумывать. Опорный `route_stage` зафиксировать (напр. 4) и
  откомментировать — EV не должна зависеть от стадии, чтобы инвариант был
  стабильным.
- **`random_outcomes` и `check`** считаются ОЖИДАЕМО (среднее по исходам). Для
  `check` — задокументировать допущение о вероятности успеха (либо вывести из
  difficulty, либо 50/50). buy_bag и throw_coin содержат вложенный `combat` внутри
  random_outcomes — калькулятор должен рекурсивно обрабатывать вложенные исходы.
- **Не раздувать экономику.** Цель — паритет + умеренная премия за риск, НЕ
  сделать риск-ветки строго сильнее. Перетянутые множители обесценят безопасные
  ветки и разгонят золото забега (смежно с инвариантами buying-power в
  route_economy). После правок глянуть, что общий экономический отчёт не уехал.
- **Связанные тикеты/память**: проект во ФРИЗЕ фич — это балансная правка
  существующего контента, в рамки фриза вписывается. Combat reward-множители уже
  правились (commit-история combat_director). Запуск теста headless:
  `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_smoke_progression_economy_test.gd`
  и `.../res://tests/event_data_smoke_test.gd`.
- **Все правки тегаются `foma`/идут под Jira SCRUM-508; держать Jira синхронной с
  фактическим статусом по ходу работы.**
