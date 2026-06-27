# SCRUM-517: Doctor — ограничить реген, чтобы класс мог погибнуть при плохой игре

Jira: SCRUM-517 · Роль: backend (balance) · Контур: codex · Приоритет: P0 · foma · Эпик: SCRUM-214
Статус: Готово

## Что и зачем

Базовое правило survival-геймплея FantasyDisk: ЛЮБОЙ персонаж должен погибать, если плохо избегает монстров или недостаточно быстро их убивает. Доктор это правило ломает — его sustain через drain-link оружие даёт фактически бесконечный реген: стоя в плотной толпе и просто стреляя, он лечится быстрее, чем получает урон, и становится практически неубиваемым.

Цель с точки зрения игрока/продукта: Доктор остаётся узнаваемым sustain/healing-классом (drain-link, lifesteal, чума), но его «бессмертие» убирается — при плохом dodging или слабом kill-speed он умирает, как и все. EHP/sustain Доктора должен войти в общий коридор выживаемости относительно других классов.

Ожидаемый результат: источник завышенного sustain найден и срезан; добавлен/расширен автоматический регресс-гейт, который ГОНЯЕТ настоящего Доктора в бою и фиксирует, что чистый входящий урон превышает реген (бессмертие недостижимо), при этом healing/vampirism/status других классов и артефактов не сломаны.

## Текущее состояние в коде

### Корень проблемы — drain-heal на КАЖДОМ попадании, БЕЗ per-second cap

`scripts/class_weapon.gd:1954-1964` — центральная `_damage_enemy(enemy, amount, ...)`. На каждом нанесённом уроне она вызывает:
- `:1959` `owner_node.on_weapon_hit(enemy, amount)` — это путь ВАМПИРИЗМА (он капнут, см. ниже);
- `:1960` `_heal_owner_from_damage(owner_node, amount)` — это путь DRAIN-HEAL, и он **НЕ капнут вообще**.

`scripts/class_weapon.gd:776-786` — `_heal_owner_from_damage`:
```
var heal_amount := dealt_damage * heal_percent_of_damage * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER
owner_node.set("health", minf(before + heal_amount, max_health))
```
Единственный потолок здесь — `max_health` (т.е. «не перелить выше полного HP»). НИКАКОГО ограничения «лечения в секунду» нет. Множитель `WEAPON_DRAIN_HEAL_MULTIPLIER = 0.45` (`scripts/progression_data_balance.gd:65`) — единственный общий тормоз.

### Конфиг Доктора усиливает это до бессмертия

`scripts/progression_data_weapons.gd:262-298` — `DOCTOR_WEAPONS`:
- `restore_potion` (`:263-273`): `attack_mode: "drain_link"`, **`heal_percent_of_damage: 0.34`** (самый высокий в игре), `fire_interval: 1.05`, плюс `passive_mods: {"max_health_multiplier": 1.10}`.
  → heal/hit = `dmg × 0.34 × 0.45 = dmg × 0.153`; при fire_interval 1.05с это `≈ dmg × 0.146` heal/с. Для скромных ~120 урона/удар это **≈18 HP/удар, ≈17 HP/с** непрерывного лечения.
- `plague_syringe` (`:274-284`): `drain_link`, `heal_percent_of_damage: 0.26`, **`dot_ticks: 6`**. Критично: КАЖДЫЙ из 6 DoT-тиков проходит через `_damage_enemy` (`class_weapon.gd:2004-2007` в `_damage_enemy_with_dot`), а значит КАЖДЫЙ тик ещё раз дёргает `_heal_owner_from_damage`. То есть один выстрел чумы лечит 1 (direct) + 6 (тики) раз. По нескольким целям одновременно — реген множится.
- `bone_saw` (`:285-297`): ближний `stab_flurry`, `heal_percent_of_damage: 0.18` + `melee_heal_percent_on_hit: 0.002` (последнее идёт через капнутый-ли путь — нет, `heal_percent`, см. ниже).

### Для сравнения: ВАМПИРИЗМ капнут, а DRAIN — нет (вот корень дисбаланса)

`scripts/player.gd:776-793`:
- `_apply_regeneration` (`:776-782`) каждый кадр пополняет `_vampiric_heal_budget` до `effective_vampiric_cap(...)` (дефолт `VAMPIRIC_HEAL_CAP_DEFAULT = 1.4`/с, хард `2.6`/с — `progression_data_balance.gd:63-64`).
- `on_weapon_hit` (`:785-793`) — вампиризм лечит `minf(raw_heal, _vampiric_heal_budget)` и ВЫЧИТАЕТ из бюджета. Комментарий `:787` прямо гласит: «Вампиризм теперь sustain, а не бессмертие: малая доля урона + per-second cap».

То есть проектное намерение — **держать sustain под per-second cap**. Но `_heal_owner_from_damage` (drain-heal) этот бюджет **полностью игнорирует** и льёт лечение напрямую в `health`. При 120 уроне/удар drain даёт ~17 HP/с против капа вампиризма 1.4 HP/с — то есть **в ~12 раз выше** того лимита, который команда сама заложила как «не-бессмертие». Это и есть источник.

### `heal_percent` (мелейный) — отдельный, тоже без cap, но мелкий

`scripts/player.gd:1436-1441` — `heal_percent(percent)`: `health += max_health * percent`. Используется `melee_heal_percent_on_hit` (`class_weapon.gd:1989-1990`) и `heal_percent_on_attack` (`:260-261`, домножается на `WEAPON_DRAIN_HEAL_MULTIPLIER`). У Доктора это только `bone_saw` `0.002` — мизер, в фокус задачи почти не входит, но при правке cap его стоит учесть концептуально (см. Замечания).

### Почему формульные/абстрактные гейты этого НЕ ловят

1. **EHP-формула слепа к реальному регену.** `scripts/progression_data.gd:751-761` — `_budget_ehp`:
   ```
   var lifesteal := (heal_percent_of_damage * 120.0 + heal_percent_on_attack * health * 2.0) * WEAPON_DRAIN_HEAL_MULTIPLIER
   return health/... + absorb*6 + regen*30 + lifesteal
   ```
   Для `restore_potion` это `0.34 × 120 × 0.45 = 18.36` единиц EHP — статическая добавка, которая НЕ учитывает ни `fire_interval`, ни 6-кратный DoT-стак, ни число целей. Реальный sustain на порядок выше этой оценки. И, главное, эта `ehp` нигде НЕ гейтится (см. п.3).
2. **Анти-immortality smoke использует абстрактную модель, а не Доктора.** `tests/global_survivability_balance_smoke_test.gd` и `tests/survivability_scenario_test.gd` гоняют `tools/survivability_harness.gd` — 4 абстрактных профиля (fragile/steady/sturdy/tank) с полем `regeneration`. Этот harness НЕ моделирует `heal_percent_of_damage`/drain-link вообще. `survivability_scenario_test.gd:88` для «якоря» спавнит **berserk**, не Доктора, и проверяет только митигейт урона — путь лечения не трогается. Поэтому текущие гейты зелёные, а Доктор бессмертен.
3. **EHP-коридора нет.** Метрика `ehp` из `estimate_weapon_budget` (`progression_data.gd:482`) выводится только в отчёт (`tools/balance_harness.gd:187,203,219`); НИ ОДИН тест не ассертит EHP в коридоре (`grep ehp tests/*.gd` → только report-строки). Значит автоматической защиты от runaway-sustain сейчас нет в принципе.

### Профиль Доктора (контекст «насколько он должен быть живуч»)

`scripts/progression_data_balance.gd:19` — `"doctor": {"profile":"balanced","survival":"tank","damage_budget":0.85,...}`. То есть Доктор по дизайну — `tank`-survival (наравне с knight/robot), но НЕ «бессмертный». Цель правки — попасть в верх коридора `tank`, а не выбить его.
`scripts/player.gd:110` — базовое `max_health: 64.0` (с `restore_potion` ×1.10 = 70.4). Для сравнения knight 95, robot 98 — то есть «танковость» Доктора должна идти от sustain, но в РАЗУМНЫХ, капнутых пределах, а не от бесконечного drain.

## Что сделать — по шагам

1. **Воспроизвести бессмертие численно (baseline).** Поднять Доктора с `restore_potion`/`plague_syringe` и прогнать его против плотной толпы (через новый/временный сценарный замер — см. шаг 5). Зафиксировать: heal/с заметно превышает входящий митигированный урон → чистый HP не убывает. Это до/после ориентир.

2. **Главная правка — подвести drain-heal под per-second budget (рекомендуемый путь).** Самый чистый фикс: заставить `_heal_owner_from_damage` уважать тот же бюджет, что и вампиризм, вместо того чтобы лить напрямую в `health`.
   - Вариант A (предпочтительный, концептуально «один cap на весь sustain»): в `scripts/class_weapon.gd:776-786` НЕ писать в `health` напрямую, а маршрутизировать лечение через метод игрока, который списывает из `_vampiric_heal_budget` (или нового общего `_drain_heal_budget`). Т.е. добавить в `player.gd` публичный метод вида `apply_drain_heal(amount)` рядом с вампирной логикой (`:785-793`), который делает `minf(amount, budget)` и вычитает из бюджета. Тогда drain автоматически попадает под `effective_vampiric_cap`/новый cap. Это убирает бессмертие у ВСЕХ drain-источников разом и сохраняет идентичность (Доктор всё ещё лечится, просто не бесконечно).
   - Вариант B (точечный): срезать `heal_percent_of_damage` Доктора в `progression_data_weapons.gd:270/281/292` (например 0.34→~0.12-0.16, 0.26→~0.10) и/или общий `WEAPON_DRAIN_HEAL_MULTIPLIER` (`progression_data_balance.gd:65`). Минус: глобальный множитель затронет ВСЕ drain-классы (priest/biologist и т.д., см. `progression_data_weapons.gd:607,619,631,670,744` — у них тоже `heal_percent_of_damage`), а урезание только чисел Доктора не лечит концептуальную дыру «уберём cap-обход». Числа всё равно стоит подкрутить, но как дополнение к A, не вместо.
   - **Решение (A vs B), которое выберет исполнитель, зафиксировать в ответе/комментарии тикета** с числами до/после.

3. **Учесть DoT-стак чумы.** Поскольку каждый из 6 тиков `plague_syringe` повторно дёргает `_heal_owner_from_damage` (`class_weapon.gd:2004-2007`), бюджетный cap из шага 2 автоматически прикроет и эту дыру (тики будут конкурировать за один бюджет). Если выбран Вариант B без бюджета — отдельно решить, лечить ли с DoT-тиков вообще (можно передавать флаг «не лечить с тика» в `_damage_enemy(..., apply_unique_melee_effects=false)`-подобном духе; сейчас тики идут с `false` в 3-м аргументе, но heal в `_damage_enemy` от этого флага НЕ зависит — `:1960` вызывается всегда).

4. **Согласовать с EHP-формулой (чтобы отчёт не врал).** Если меняются числа `heal_percent_of_damage`, `_budget_ehp` (`progression_data.gd:757-760`) автоматически пересчитает свой lifesteal-член — отдельно править не нужно, но проверить, что Доктор в отчёте `tools/balance_harness.gd` больше не выглядит EHP-аутлаером. `progression_data.gd` — LOCKED (см. Замечания); если правка cap живёт в `class_weapon.gd`/`player.gd`, `progression_data.gd` можно не трогать вовсе.

5. **Закрепить РЕГРЕССИЕЙ, гоняющей настоящего Доктора (ключевой критерий тикета).** Существующие survivability-гейты абстрактны и Доктора не видят. Нужен новый тест-гейт (или режим), который:
   - спавнит `Player.configure_character("doctor", "restore_potion")` (и желательно `plague_syringe`), как `survivability_scenario_test.gd:82-88` спавнит berserk;
   - ставит вокруг плотную статичную толпу врагов в радиусе оружия, прогоняет N секунд боя;
   - ассертит, что при достаточном входящем DPS **чистый HP убывает** (т.е. `incoming_mitigated > heal_per_sec`, бессмертие недостижимо) — по аналогии с инвариантом `(mitigated - regen) > NET_DAMAGE_FLOOR` из `global_survivability_balance_smoke_test.gd:45-47`, но на ЖИВОМ Докторе;
   - и/или ассертит, что суммарный heal за окно ≤ (cap/с × окно), т.е. drain больше не обходит per-second budget.
   Это отдельный изолированный файл (по образцу существующих smoke в `tests/`), не нагружать им абстрактный harness.

6. **Прогнать существующие гейты — не сломать чужой sustain.** `tests/status_effects_aura_test.gd`, `tests/summoner_strengthening_test.gd`, `tests/global_survivability_balance_smoke_test.gd`, `tests/survivability_scenario_test.gd`, `tests/weapon_integrity_test.gd`, `tests/weapon_tuning_application_test.gd` — зелёные. Особо проверить priest/biologist (тоже drain/heal) и артефактные `regeneration_flat`/`healing_multiplier` (`progression_data_weapons.gd:609,716,749`).

7. **Обновить документацию и CHANGELOG** (как в прецеденте SCRUM-503, коммит `1e74202b`): `docs/design/systems/progression_balance.md`, `docs/design/mechanics_extract.md` (если фиксируется новый предел регена), CHANGELOG.

## Acceptance Criteria

- [ ] Doctor (`restore_potion` и `plague_syringe`) в контрольном smoke/сценарии больше НЕ может бесконечно танковать плотную толпу без движения/убийств: при достаточном входящем DPS чистый HP убывает и герой умирает (проверяемо числами, как `mitigated - regen > NET_DAMAGE_FLOOR`).
- [ ] Drain-heal (`_heal_owner_from_damage`) больше НЕ обходит per-second sustain-лимит: суммарное лечение от drain за окно ограничено бюджетом (capped), а не равно `Σ dmg × heal_pct × 0.45` без потолка.
- [ ] Doctor остаётся заметно sustain-ориентированным: он всё ещё лечится в бою (drain-link/чума работают), его EHP/sustain в коридоре `tank`-survival относительно других классов, а не выше всех на порядок.
- [ ] Все персонажи потенциально умирают при плохом dodging или недостаточном kill-speed (инвариант не-бессмертия сохраняется глобально — `global_survivability_balance_smoke_test.gd` зелёный).
- [ ] НЕ сломаны healing/vampirism/status-механики других классов и артефактов: priest/biologist drain, `vampiric_*`, `melee_heal_percent_on_hit`, `regeneration_flat`/`healing_multiplier` артефактов работают как раньше (соответствующие тесты зелёные).
- [ ] Добавлен/расширен автоматический регресс-гейт, который ГОНЯЕТ настоящего Доктора (не абстрактный профиль) и фиксирует новый предел регена; он зелёный.
- [ ] Base lvl1-числа НЕ-Доктор классов не изменились (если правили общий `WEAPON_DRAIN_HEAL_MULTIPLIER` — явно подтвердить влияние на priest/biologist и осознанно принять/откатить; предпочтительно правка через бюджет в `player.gd`/`class_weapon.gd`, не глобальный множитель).

## Files / точки входа

- `scripts/class_weapon.gd:776-786` — `_heal_owner_from_damage`: ГЛАВНАЯ точка. Вместо прямой записи в `health` маршрутизировать лечение через capped-метод игрока (Вариант A) ИЛИ оставить, но получать множитель из урезанных конфигов (Вариант B).
- `scripts/class_weapon.gd:1954-1964` — `_damage_enemy`: `:1960` — место вызова drain-heal на каждом попадании (включая DoT-тики через `:2004-2007`). Здесь же `:1959` вампирный путь — НЕ дублировать лечение.
- `scripts/player.gd:776-793` — `_apply_regeneration` / `on_weapon_hit`: эталон per-second budget (`_vampiric_heal_budget`, `effective_vampiric_cap`). Добавить сюда публичный `apply_drain_heal(amount)` (Вариант A), списывающий из бюджета.
- `scripts/player.gd:1436-1441` — `heal_percent`: мелейный heal (Доктор: `bone_saw` `0.002`); решить, подводить ли и его под cap (мелкий, можно оставить, но зафиксировать решение).
- `scripts/progression_data_weapons.gd:262-298` — `DOCTOR_WEAPONS`: `restore_potion` `heal_percent_of_damage:0.34` (`:270`), `plague_syringe` `0.26`+`dot_ticks:6` (`:281,280`), `bone_saw` `0.18` (`:292`). Точечная подкрутка чисел (Вариант B / дополнение).
- `scripts/progression_data_balance.gd` (чувствительный, менять осторожно) — `WEAPON_DRAIN_HEAL_MULTIPLIER:0.45` (`:65`), `VAMPIRIC_HEAL_CAP_DEFAULT/HARD` (`:63-64`). При Варианте A можно ввести отдельную `DRAIN_HEAL_PER_SECOND_CAP`-константу, чтобы не смешивать с вампирным бюджетом.
- `tests/global_survivability_balance_smoke_test.gd` / `tests/survivability_scenario_test.gd` — эталон инварианта не-бессмертия и спавна Player; НЕ класть сюда live-Доктора напрямую (они на абстрактном harness). Новый live-гейт — отдельным файлом.
- `tools/survivability_harness.gd` — абстрактная модель; менять НЕ требуется (она не моделирует weapon-lifesteal; live-проверка идёт мимо неё).
- `scripts/progression_data.gd:751-761` (LOCKED) — `_budget_ehp` lifesteal-член; трогать НЕ нужно, если правка в class_weapon/player (формула сама пересчитается от изменённых конфигов).

## Замечания / подводные камни

- **LOCKED PATHS (anti-collision):** `scripts/progression_data.gd` и `scripts/ui_screens.gd` — координируемые/locked. Рекомендуемый путь (cap в `class_weapon.gd` + `player.gd`) `progression_data.gd` НЕ трогает — придерживаться его, чтобы не пересекаться. `ui_screens.gd` к задаче отношения не имеет — не трогать. Тикет дополнительно перечисляет как suggested-locked: `progression_data_characters.gd`, `progression_data_balance.gd`, `progression_data_weapons.gd`, `player.gd`, `tools/balance_harness.gd` — все они в скоупе правки, держать диф минимальным и согласованным.
- **Главный концептуальный баг:** проектное намерение (комментарий `player.gd:787`) — sustain под per-second cap. Вампиризм его уважает, drain-heal — НЕТ (`class_weapon.gd:783` пишет в health напрямую). Это и есть «нереальный реген». Чинить именно обход cap, а не только величину чисел — иначе при следующем апскейле урона бессмертие вернётся.
- **DoT-стак — скрытый множитель.** Один выстрел `plague_syringe` лечит до 1+6 раз (direct + 6 тиков), т.к. тики идут через `_damage_enemy` (`:2004-2007`). По нескольким целям — ×N. Бюджетный cap прикрывает это автоматически; точечное урезание `heal_percent` — нет (тики продолжат складываться). Это аргумент в пользу Варианта A.
- **Не сломать другие drain/heal-классы.** priest/biologist и часть артефактов используют `heal_percent_of_damage`/`heal_percent_on_attack`/`regeneration_flat` (`progression_data_weapons.gd:607,619,631,670,716,744,749`). Если правите общий `WEAPON_DRAIN_HEAL_MULTIPLIER` или общий бюджет — это затронет их; прогнать `status_effects_aura_test`, `summoner_strengthening_test`, `weapon_integrity_test` и осознанно принять влияние. Предпочтительно, чтобы бюджетный cap бил по «нереальному» sustain равномерно (это и есть фикс «бессмертия в принципе»), но проверить, что priest/biologist не проваливаются НИЖЕ своего коридора.
- **Якорь к боевому коду обязателен.** Текущие survivability-тесты НЕ спавнят Доктора — потому баг и просочился. Новый гейт ДОЛЖЕН гонять `configure_character("doctor", ...)` против реальной толпы, иначе регрессия снова станет невидимой. Образец спавна/якоря — `survivability_scenario_test.gd:78-113`.
- **Vampiric vs drain — два разных пути, не перепутать.** `on_weapon_hit` (вампиризм, capped, рандомный по `vampiric_chance`) и `_heal_owner_from_damage` (drain, детерминированный, uncapped) оба висят на `_damage_enemy`. Не задвоить лечение и не убрать вампиризм заодно — у не-Доктор классов он легитимен и уже сбалансирован (SCRUM-249/255).
- **Edge-cases замера:** реген зависит от `healing_multiplier` run-модификатора (`player.gd:782,793,1438`) и от числа целей в радиусе оружия. Контрольный сценарий держать детерминированным (фикс-сид, статичные враги, нейтрализованный knockback — как `character_balance_csv.gd`), иначе heal/с будет плавать.
- **Мета-сейв в headless.** При гонке live-гейта помнить про известную ловушку: Godot `--user-data-dir` не изолирует реальный dev-мета-сейв (unlocks/death_save) — для чистого замера нейтрализовать мета, иначе ложные числа.
- **Связанные тикеты/системы:** SCRUM-249 (глобальный survivability gate / анти-immortality), SCRUM-255 (снижение regen/vampirism, diminishing defense/dodge/absorb), SCRUM-190 (scenario gate + якорь take_damage), SCRUM-214 (родительский эпик). Прецедент balance-фикса P0 с обновлением доков/CHANGELOG — SCRUM-503 (коммит `1e74202b`).
- **Запуск тестов (QA-окружение):** Godot 4.6.x в `~/Downloads/Godot.app`. Примеры:
  `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd`
  `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/survivability_scenario_test.gd`
  Новый Doctor-гейт запускать аналогично по своему пути.
- **Документация:** обновить `docs/design/systems/progression_balance.md` и CHANGELOG; зафиксировать новый предел регена Доктора (как принято в проекте при balance-правках).

## QA-Вердикт: PASSED

Проверено на committed origin/dev (6a8eaf3e) в изолированном worktree. Godot 4.6.3 headless.

Прогнаны тесты:
- `doctor_drain_softcap_test` — PASSED. Doctor[restore_potion] HP 68.8 → -1.1; Doctor[plague_syringe] HP 65.0 → -4.8 под incoming 84.0/с; capped_heal/окно=7.00 (cap 7.00). Инварианты A (capped per-second), B (MORTAL — гибель под плотной толпой), C (sustain-идентичность: drain-cap 7.0/с = 6.4× вампирного 1.1/с) — зелёные.
- `runtime_smoke_test` — PASSED (изолированный user-data; на общем dev-сейве ложный red «Expected New Game to clear autosave» = известная фрагильность мета-сейва, не связана с задачей).
- `global_survivability_balance_smoke_test` — PASSED (бессмертие недостижимо, митигация<98%).
- `survivability_scenario_test` — PASSED.
- `status_effects_aura_test` — PASSED (healing/vampirism/status других классов целы).
- `weapon_integrity_test` — PASSED (17 classes / 51 weapons).
- `weapon_tuning_application_test` — PASSED (51 пара).

Acceptance 5/5 подтверждены фактическим прогоном: Доктор больше не бессмертен в толпе, остаётся сильнейшим детерминированным sustain-классом, drain списывается из per-second бюджета (`apply_drain_heal`), капы других классов не тронуты, dedicated regression фиксирует новый предел. → Готово.
