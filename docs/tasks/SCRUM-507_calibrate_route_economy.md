# SCRUM-507: Откалибровать экономику маршрута: цены магазина vs покупательная способность по актам

Jira: SCRUM-507 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: —
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

## Что и зачем

Цель — выровнять покупательную способность игрока между тремя репрезентативными маршрутами прохождения (Balanced / Combat-Heavy / Shop-Rest), чтобы выбор пути не определял, сколько полезных покупок и докачек атрибутов игрок может себе позволить к боссфайту.

Сейчас модель `build/route_economy_xp_model.md` показывает три проблемы:

1. **Разброс affordable offers 73%.** Balanced даёт 9.0 affordable offers (покупательная способность 'high'), Shop-Rest — 7.9 ('high'), а Combat-Heavy — только 5.2 ('healthy'). Combat-Heavy зарабатывает больше всего золота (956 против 684-768), но его единственный магазин выпадает на поздней стадии (stage 7), где `stage_scaled_cost` раздувает среднюю цену лавки до 183.2 против 76-97 у других маршрутов. Игрок на боевом маршруте «богат, но покупать нечего по карману».

2. **Boss-дроп доминирует в экономике.** `DROP_CLASS_MULTIPLIERS["boss"].money = 92.0`, умноженный на `stage_scale`, даёт 442-594 золота с одного босса — это 64% всего золота маршрута (442/684 на Balanced, 594/956 на Combat-Heavy, 512/768 на Shop-Rest). Награды ранних актов (25-87 золота за бой) обесцениваются: вся экономика сводится к «дожить до босса». Ранние решения о тратах теряют вес.

3. **Падение покупательной способности ниже 'high' на боевом пути** нарушает ощущение, что боевой маршрут — валидная стратегия.

Ожидаемый результат после калибровки и перегенерации отчёта:
- число Affordable Offers по трём маршрутам — в коридоре ±25% друг от друга (вместо 73%);
- покупательная способность всех трёх маршрутов — одного разряда ('high' или 'healthy'), без падения ниже 'healthy';
- доля золота от boss-дропа в доходе маршрута ≤ 50%;
- XP-темп (8-9 level-ups до/включая босса) и зелёный smoke-тест сохранены.

## Текущее состояние в коде

### Балансные константы — `scripts/progression_data_balance.gd`
- Строка 180: `STAGE_SCALE_BASE := 1.18`
- Строка 182: `STAGE_SCALE_LINEAR := 0.075`
- Строка 184: `ECONOMY_PRICE_MULTIPLIER := 1.10`
- Строки 186-188: `XP_CURVE_MULTIPLIER := 1.42`, `XP_CURVE_FLAT := 3.0` (XP-темп — НЕ трогать без необходимости; см. AC4)
- Строки 190-197: `DROP_CLASS_MULTIPLIERS` — ключ `"boss": {"xp": 24.0, "money": 92.0, "money_chance": 1.0}` (строка 196). Именно `money = 92.0` раздувает boss-дроп.
- Строка 199: `COST_BY_TIER := {1: 30, 2: 55, 3: 95}` (цены артефактов по тиру).

Эти константы реэкспортируются в `scripts/progression_data.gd:48-54` через `const ... := BalanceData.<NAME>`. Менять значения нужно В `progression_data_balance.gd` (источник истины); `progression_data.gd` подхватит автоматически.

### Формулы — `scripts/progression_data.gd`
- `stage_scale(route_stage)` (строки 359-361):
  `pow(STAGE_SCALE_BASE, stage) + STAGE_SCALE_LINEAR * stage`, округление до 0.001.
  При stage 7 ≈ `1.18^7 + 0.075*7 ≈ 3.19 + 0.525 ≈ 3.71`; при stage 8 ≈ 4.21; stage 10 ≈ 5.78.
- `stage_scaled_cost(base_cost, route_stage)` (строки 364-365):
  `ceil(base_cost * stage_scale(stage) * ECONOMY_PRICE_MULTIPLIER)`.
  Это причина дорогой лавки Combat-Heavy: магазин на stage 7 → множитель ≈ 3.71 * 1.10 ≈ 4.08 поверх базовой цены.
- `drop_class_rewards(drop_class, route_stage, wave_index)` (строки 376-392):
  Для boss (строки 380-385): `money = round(92.0 * stage_scale(stage))`. При stage 8: round(92 * 4.21) ≈ 442; stage 9: ≈ 512; stage 10: ≈ 594 — точно совпадает с цифрами отчёта.
  Для не-boss (строки 386-392): `base_money = round(1 + max(scale-1,0)*0.25 + wave*0.006)`, затем `* multipliers.money`.
- `shop_items(route_stage)` (строки 979-991): применяет `stage_scaled_cost` к каждому `SHOP_ITEMS` и к артефактам.

### Сырые цены магазина — `scripts/progression_data_shop.gd`
- `SHOP_ITEMS` (строки 5-13): 7 предметов, базовые цены 28-52. `shop_damage` cost = 42 (строка 6) — ЗАХАРКОЖЕНО в тестах (см. подводные камни).

### Модель/отчёт — `tools/route_economy_xp_model.gd`
- `REPORT_PATH := "res://build/route_economy_xp_model.md"` (строка 5).
- Три фикстуры маршрутов в `_route_fixtures()` (строки 88-139): порядок и stage узлов жёстко заданы. Combat-Heavy ставит `shop` на stage 7 и `upgrade` на stage 8 — отсюда дорогая лавка.
- `_simulate_route()` (строки 142-209): считает `affordable_offers = total_gold / avg_shop_cost` (строка 192), `attr_buys`, `rerolls`.
- `_buying_power_label()` (строки 270-275): `high` если offers ≥ 6.0 И attr_buys ≥ 2.0; `healthy` если offers ≥ 3.5 И attr_buys ≥ 1.0; иначе `tight`.
- Отчёт перегенерируется headless-прогоном этого скрипта (см. ниже).

### Smoke-тест — `tests/runtime_smoke_progression_economy_test.gd`
- Тонкая обёртка (35 строк) над `tests/runtime_smoke_test.gd`; вызывает `_test_economy_tiers_and_fab()` и `_test_class_budget_profiles()`. Сами экономические ассерты живут в базовом `runtime_smoke_test.gd` (см. подводные камни).

## Что сделать — по шагам

1. **Снять baseline.** Перегенерировать отчёт текущим кодом (команда в разделе Files), убедиться что цифры совпадают с зафиксированными в `build/route_economy_xp_model.md` (5.2 / 9.0 / 7.9 offers, boss 442/594/512). Это точка отсчёта.

2. **Снизить долю boss-дропа.** Уменьшить `DROP_CLASS_MULTIPLIERS["boss"].money` (строка 196 в `progression_data_balance.gd`) с `92.0`. Ориентир: довести долю boss-золота до ≤ 50% дохода маршрута. Грубо boss-money нужно опустить примерно на четверть-треть (порядок ~60-70), но точное значение подбирать итеративно по отчёту. ВАЖНО: после снижения проверить инвариант теста `boss_drop.money > elite_drop.money` (см. подводные камни) — boss должен оставаться самым жирным денежным дропом.

3. **Компенсировать общий доход ранними наградами (если требуется по AC3/AC4).** Если снижение boss-money просаживает суммарное золото настолько, что покупательная способность падает ниже 'healthy', — слегка поднять не-boss денежный дроп. Варианты (по убыванию предпочтения): поднять коэффициент `0.25` в формуле `base_money` (`progression_data.gd:387`) или поднять `money`-множители средних классов (`complex`/`heavy`) в `DROP_CLASS_MULTIPLIERS`. Цель — сместить золото с босса на ранние/средние бои, не меняя суммарный порядок.

4. **Сгладить цену поздней лавки Combat-Heavy.** Разброс offers вызван тем, что `stage_scaled_cost` на stage 7 даёт avg 183 против 76-97. Два рычага:
   - (а) уменьшить `STAGE_SCALE_LINEAR` (строка 182) и/или `ECONOMY_PRICE_MULTIPLIER` (строка 184), чтобы инфляция поздних цен была мягче — но это глобально удешевляет ВСЕ цены и докачки атрибутов, проверять влияние на все маршруты;
   - (б) если правка только констант не выравнивает offers в ±25%, допустимо подвинуть stage магазина Combat-Heavy в фикстуре (`tools/route_economy_xp_model.gd:117`, `{"type": "shop", "stage": 7}` → более ранний stage) — это меняет только модель/репрезентацию маршрута, а не игровые цены. Решить, что честнее: фикстура должна отражать реальные маршруты, поэтому предпочесть калибровку констант, фикстуру трогать в последнюю очередь и осознанно.

5. **Итеративно перегенерировать отчёт** после каждой правки констант, читать таблицу Route Results, проверять три AC одновременно (offers ±25%, разряд buying_power, доля boss ≤ 50%). Подбор — компромисс: снижение boss-money помогает AC3, но может уронить общий доход и offers; смягчение stage-цен помогает AC1, но удешевляет докачку атрибутов (растит attr_buys, может перебросить разряд в 'high').

6. **Прогнать smoke-тест** `tests/runtime_smoke_progression_economy_test.gd` headless, добиться зелёного. Если упал ассерт на `shop_damage`/`drop ordering` — см. подводные камни.

7. **Проверить, что `ECONOMY_PRICE_MULTIPLIER` правка не сломала** жёсткий ассерт `shop_damage` stage-0 cost = 47 (`runtime_smoke_test.gd:3962`). `47 = ceil(42 * stage_scale(0) * ECONOMY_PRICE_MULTIPLIER)`, где `stage_scale(0) = 1.0`. Если меняешь `ECONOMY_PRICE_MULTIPLIER`, этот ассерт упадёт — либо не трогать множитель, либо синхронно обновить ожидаемое число в тесте (осознанно, с пометкой в коммите).

8. **Обновить дизайн-доки** (если значения констант изменились): `docs/design/current_game_state.md:976` и `docs/design/mechanics_extract.md:565` ссылаются на `ECONOMY_PRICE_MULTIPLIER = 1.10`, boss-множители и цифры покупательной способности. Привести в соответствие.

## Acceptance Criteria

- [ ] **AC1.** После перегенерации `build/route_economy_xp_model.md` число Affordable Offers по трём маршрутам в коридоре ±25% друг от друга (было 5.2 vs 9.0 = разброс 73%).
- [ ] **AC2.** Buying Power всех трёх маршрутов — одного разряда ('high' или 'healthy'), ни один не ниже 'healthy' (по `_buying_power_label`, `route_economy_xp_model.gd:270`).
- [ ] **AC3.** Доля золота от boss-дропа в общем доходе каждого маршрута ≤ 50% (было до 64%: 442/684, 594/956, 512/768). Проверять по колонкам Node Detail: gold boss-узла / Expected Gold маршрута.
- [ ] **AC4.** XP-темп сохранён: 8-9 level-ups до/включая boss reward по всем трём маршрутам (колонка Levels в Route Results, сейчас 8/9/8).
- [ ] **AC5.** `tests/runtime_smoke_progression_economy_test.gd` зелёный headless (включая ассерты на `shop_damage` cost 42/47 и порядок drop-классов ordinary < heavy < mini_elite < elite < boss).
- [ ] **AC6.** Инвариант `boss_drop.money > elite_drop.money` и `heavy ≥ 1.5× ordinary` сохранён (`runtime_smoke_test.gd:3970-3974`).
- [ ] **AC7.** Дизайн-доки (`current_game_state.md`, `mechanics_extract.md`) приведены в соответствие, если константы менялись.

## Files / точки входа

- `scripts/progression_data_balance.gd:196` — `DROP_CLASS_MULTIPLIERS["boss"].money` (снизить с 92.0).
- `scripts/progression_data_balance.gd:182` — `STAGE_SCALE_LINEAR` (рычаг смягчения поздних цен, опц.).
- `scripts/progression_data_balance.gd:184` — `ECONOMY_PRICE_MULTIPLIER` (глобальный рычаг цен; ОСТОРОЖНО — захардкожен в тесте).
- `scripts/progression_data_balance.gd:190-197` — `DROP_CLASS_MULTIPLIERS` (опц. поднять complex/heavy money для компенсации).
- `scripts/progression_data.gd:387` — формула `base_money` (опц. рычаг компенсации не-boss дохода). НЕ трогать сигнатуры функций.
- `scripts/progression_data_shop.gd:5-13` — `SHOP_ITEMS` (сырые цены; `shop_damage` = 42 захардкожен в тестах, НЕ менять без правки теста).
- `tools/route_economy_xp_model.gd:88-139` — фикстуры маршрутов (трогать stage магазина Combat-Heavy в последнюю очередь, опц.).
- `tests/runtime_smoke_progression_economy_test.gd` — запускать для верификации.
- Перегенерация отчёта (headless):
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tools/route_economy_xp_model.gd`
- Прогон smoke-теста (headless):
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_progression_economy_test.gd`

## Замечания / подводные камни

- **Захардкоженные ассерты в `tests/runtime_smoke_test.gd`** (базовый класс smoke-теста) — главная ловушка:
  - строка 5924-5925: сырой `SHOP_ITEMS` `shop_damage.cost` должен быть ровно **42**. Не менять базовую цену shop_damage в `progression_data_shop.gd`.
  - строка 3962-3963: `shop_damage` stage-0 cost должен быть ровно **47** = `ceil(42 * 1.0 * ECONOMY_PRICE_MULTIPLIER)`. Любая правка `ECONOMY_PRICE_MULTIPLIER` ломает этот ассерт — нужно синхронно обновить число 47 в тесте ИЛИ оставить множитель = 1.10 и работать другими рычагами.
  - строки 3970-3974: инварианты дроп-классов — `heavy.xp ≥ 1.5*ordinary.xp`, `heavy.money ≥ 1.5*ordinary.money`, и строгий порядок `ordinary < heavy < mini_elite < elite` по xp + `boss.money > elite.money`. Снижая boss-money, держать его выше elite-money (elite money = 8.5, после stage_scale на stage 3 ≈ round(8.5*... ) — но boss считается отдельной формулой round(money*scale), elite — через base_money*8.5; запас большой, но проверить тестом).
- **Глобальность рычагов.** `STAGE_SCALE_LINEAR`, `STAGE_SCALE_BASE`, `ECONOMY_PRICE_MULTIPLIER` влияют не только на магазин, но и на стоимость докачки атрибутов и reroll (`route_economy_xp_model.gd:262-267` через `stage_scaled_cost`) и на ВСЕ боевые денежные/XP дропы (через `stage_scale` в `drop_class_rewards`). Снижение `stage_scale`-инфляции удешевит докачку → вырастет `attr_buys` → разряд может прыгнуть в 'high' на всех маршрутах (это допустимо по AC2, но следить за коридором AC1).
- **Источник истины констант — `progression_data_balance.gd`.** `progression_data.gd:48-54` лишь реэкспортирует. Менять значения в balance-файле.
- **Anti-collision / locked paths:** `scripts/progression_data.gd` сейчас имеет незакоммиченные правки (`git status: M`) и является крупным общим файлом — менять в нём ТОЛЬКО формулы `drop_class_rewards`/`base_money` при крайней необходимости (шаг 3), предпочитать правку констант в `progression_data_balance.gd`. `scripts/progression_data_balance.gd` тоже `M` — синхронизироваться с актуальным состоянием перед правкой. `scripts/ui_screens.gd` к задаче НЕ относится — не трогать. Файл `build/route_economy_xp_model.md` — генерируемый артефакт, коммитить перегенерированную версию.
- **Boss-money формула отдельная.** В `drop_class_rewards` boss идёт по ветке `round(money * stage_scale)` (строки 381-385), а не через `base_money`. Поэтому снижать boss-долю нужно именно множителем `money` в `DROP_CLASS_MULTIPLIERS["boss"]`, а не общими рычагами.
- **Подбор итеративный, не аналитический.** Три AC связаны (offers/разряд/boss-доля тянут в разные стороны). Закладывай несколько циклов «правка константы → перегенерация отчёта → чтение таблицы». Фиксируй финальные значения и итоговую таблицу в коммите.
- **XP не трогать без причины.** AC4 требует сохранить 8-9 level-ups. `XP_CURVE_MULTIPLIER`/`XP_CURVE_FLAT` и `DROP_CLASS_MULTIPLIERS[*].xp` менять не нужно — задача только про золото/цены. Если boss-money правка случайно затронет xp-ветку — проверить колонку Levels.
- **Связанные тикеты:** SCRUM-188 (исходная route-economy модель), SCRUM-198 (вынос балансных констант в отдельные файлы), SCRUM-503 (недавний balance-кап berserk DPS — не пересекается по файлам экономики).
