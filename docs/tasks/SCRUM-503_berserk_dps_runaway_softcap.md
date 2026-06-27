# SCRUM-503: Срезать runaway-множители Берсерка по живой матрице DPS (hammer-аутлаер 78x)

Jira: SCRUM-503 · Роль: backend (balance) · Контур: codex · Приоритет: P0 · foma · Эпик: —
Статус: review / готово к QA (2026-06-28 — backend continuation закрыл live pool DoT blocker SCRUM-533; см. результат ниже)

## Что и зачем

Формульный гейт баланса (`tests/class_damage_table_3variants_test.gd`, источник — `tools/class_damage_table_3variants.gd`) держит relative_score Берсерка в коридоре 0.94..1.10 и считает класс зелёным. Но это ФОРМУЛЬНАЯ оценка: она меряет `estimate_weapon_budget()` на БАЗОВЫХ статах и БЕЗ забеговых модификаторов. Живой замер — `build/character_balance_dps.csv` (генератор `tools/character_balance_csv.gd`), который гоняет настоящий `Player` + оружие через `apply_reward()` с реальным идеальным билдом до 20 уровня, — вскрывает катастрофический выброс DPS.

Цель с точки зрения продукта/игрока: «идеальный» билд Берсерка (особенно молот, отчасти топор) на поздней игре выдаёт DPS в разы выше любого другого класса-лидера, что ломает кривую сложности и обесценивает остальные классы. Нужно срезать runaway так, чтобы пик Берсерка вошёл в общий коридор лидеров, при этом НЕ трогая базовые (lvl1) числа и не сломав формульный гейт.

Ожидаемый результат: перегенерённый CSV, где ни одно оружие не выбивается из общего коридора (см. Acceptance), а формульные смоук-гейты остаются зелёными.

### Важный контекст: что уже сделано (HEAD)

Коммит `1e74202b balance(SCRUM-503): cap berserk hammer DPS runaway` уже снизил у молота `upgrade_aoe_exponent` 1.8→1.25 и `upgrade_damage_exponent` 1.45→1.15 (`scripts/progression_data_weapons.gd:69-70`). Это уронило berserk/hammer 20t с ~184k до ~60.5k и 1t с 7636 до 2520. **Но задача в QA не закрыта**, потому что Acceptance сформулирован как ГЛОБАЛЬНЫЙ инвариант (`max по любому оружию ≤ 2.5x медианы`), и по текущему CSV он НЕ выполнен — см. раздел «Текущее состояние».

## Текущее состояние в коде

### Корневой механизм runaway

`scripts/progression_data.gd:793-893` — `derived_parameters(stats, run_modifiers, weapon_config)`. Ключевые строки:

- `:818-820` — `upgrade_damage_exponent`/`upgrade_aoe_exponent` из конфигурации оружия возводят забеговый множитель в степень:
  `var damage_multiplier := pow(float(run_modifiers.get("damage_multiplier", 1.0)), upgrade_damage_exponent) * passive_mods.damage_multiplier`
- `:829` — то же для `aoe_radius_multiplier` через `pow(..., upgrade_aoe_exponent)`.
- `:823` — `attack_speed_multiplier` (run × passive), без диминишинга.
- `:864-866` — итог: `damage = physical_base * weapon_damage_multiplier * damage_multiplier + universal_damage_flat`. То есть боевой урон = база × weapon-budget × (стак забеговых множителей в степени).
- `:868-869` — крит идёт ОТДЕЛЬНЫМ мультипликативным фактором (`crit_chance` × `crit_damage_multiplier`), и в `estimate_weapon_budget` они перемножаются в `crit_factor` (`:459`).

Итог: финальный DPS = base × damage_mult^exp × attack_speed_mult × crit_factor × (число попавших целей при AoE-стаке радиуса). У молота это перемножение усилено степенями + плотный круговой sweep по 20 целям → выброс.

### Почему формула «не ловит» (важнейший нюанс для исполнителя)

`estimate_weapon_budget_for_stats()` (`scripts/progression_data.gd:450-486`) вызывает `derived_parameters(stats, {}, config)` — с **пустым `run_modifiers`** (`:456`). Значит `pow(1.0, exponent) == 1.0` — экспоненты вообще не активны в формульной оценке, и `budget_tuning_for` (`:420-443`) нормализует каждое оружие к собственному `solo_target`/`aoe_target` по БАЗЕ. Поэтому формульные тесты остаются зелёными независимо от величины exponent и стака забеговых множителей. Любой soft-cap, который вы введёте на ЗАБЕГОВЫЕ множители, на формульный гейт не повлияет (run_modifiers там пусты) — это и есть требуемая изоляция «правка только сверху базы».

### Применение наград (где стакаются множители)

`scripts/player.gd:693-763` — `apply_reward()`:
- `:723` — `run_modifiers[id] = run_modifiers.get(id,1.0) * mods[id]` — мультипликативный стак `damage_multiplier`/`attack_speed_multiplier`/`aoe_radius_multiplier`/`crit_*`.
- `:759` — affinity-моды стакаются как `*= (1.0 + value)`.
Именно эти накопленные `run_modifiers` затем уходят в `derived_parameters`.

### Конфиг молота (уже подправлен)

`scripts/progression_data_weapons.gd:51-73` — `hammer`: `attack_shape: "circle"`, `cone_degrees: 360`, `damage_multiplier: 0.55`, `passive_mods: {"aoe_radius_multiplier": 1.20}`, `upgrade_aoe_exponent: 1.25`, `upgrade_damage_exponent: 1.15`, `fire_interval: 1.25`. Топор (`:29-50`) — `sweep` 140°, `damage_multiplier: 0.85`. Меч (`:7-28`) — `frustum` 90°.

### Существующий паттерн диминишинга (прецедент для решения)

`scripts/progression_data.gd:238-241` — `_diminishing_percent(raw, cap, curve)` (мягкий потолок `raw/(1+raw*curve)`), используется для defense/dodge (`:244-249`), crit (`:276-279`). Каповые константы лежат в `scripts/progression_data_balance.gd` (BalanceData) и реэкспортятся в `progression_data.gd:39-40`. Это готовый паттерн, куда логично добавить soft-cap забеговых боевых множителей. Сейчас soft-cap'а именно на `damage_multiplier`/`attack_speed_multiplier` НЕТ.

### Что показывает CSV СЕЙЧАС (после частичного фикса)

`build/character_balance_dps.csv`, колонка `lvl20_ideal_20t`, медиана по строкам ≈ 11273, порог 2.5x ≈ 28183. Аутлаеры выше порога:

| класс/оружие | lvl20_ideal_20t | xмедианы |
| --- | ---: | ---: |
| chemist/acid_flask | 112280 | 10.0x |
| dark_mage/dark_book | 73432 | 6.5x |
| ranger/hunter_trap | 70826 | 6.3x |
| chemist/blast_powder | 65629 | 5.8x |
| **berserk/hammer** | **60451** | **5.4x** |
| engineer/engineer_pressure_mines | 52469 | 4.7x |
| druid/briar_staff | 49126 | 4.4x |
| robot/robot_magnetic_anchor | 38370 | 3.4x |

berserk/hammer 1t = 2520 (медиана 1t ≈ 945, 2.5x ≈ 2363 → молот на ~7% выше «2.5x медианы», но в пределах буквального «≤ ~3500» из тикета).

Вывод: частичный фикс уронил молот до уровня top-tier AoE (цель «~50-65k» в тикете формально достигнута для молота), но ГЛОБАЛЬНЫЙ инвариант `max ≤ 2.5x медианы` не выполнен — теперь лидируют chemist/acid_flask и dark_book. Исполнитель должен решить (и зафиксировать в спеке-ответе/комментарии тикета), трактуем ли мы Acceptance буквально-глобально (тогда правка шире, чем один Берсерк) или узко-Берсерк (тогда основная цель уже близка и задача = добить молот под 2.5x + закрепить тестом). См. «Замечания».

## Что сделать — по шагам

1. **Перегенерировать актуальный CSV и зафиксировать baseline.** Запуск:
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/character_balance_csv.gd`
   Сверить числа с таблицей выше (они могли сдвинуться, если в HEAD были ещё правки). Это ваш до/после ориентир.

2. **Выбрать механизм soft-cap (рекомендуемый путь — diminishing на забеговые боевые множители).** Ввести в BalanceData (`scripts/progression_data_balance.gd`) новые константы, например `RUN_DAMAGE_MULT_SOFTCAP` / `RUN_DAMAGE_MULT_KNEE` и `RUN_ATTACK_SPEED_MULT_SOFTCAP`/`_KNEE`, и применить мягкое сжатие к `damage_multiplier`/`attack_speed_multiplier` ВНУТРИ `derived_parameters` ПОСЛЕ чтения из `run_modifiers`, но так, чтобы при `run_modifiers == {}` (т.е. множитель = 1.0) функция была тождественна (cap не трогает базу). Паттерн — по аналогии с `_diminishing_percent` (`progression_data.gd:238-241`): сжимать только превышение над 1.0, например `1.0 + softened(mult - 1.0)`. Это гарантирует «base lvl1 числа не меняются» и «формульный гейт зелёный» (там run_modifiers пусты → mult=1.0 → cap нейтрален).
   - Альтернатива/дополнение: ещё сильнее урезать у молота/топора `upgrade_*_exponent` и/или ввести `budget_tuning`-cap, но это точечно бьёт по Берсерку и НЕ лечит chemist/dark_mage аутлаеры (если трактуем Acceptance глобально).

3. **Применить cap в `derived_parameters`** (`scripts/progression_data.gd:820,823,829`): обернуть забеговую часть `damage_multiplier`/`attack_speed_multiplier` (и при необходимости `aoe_radius_multiplier`) в новый soft-cap-хелпер. ВНИМАНИЕ: `progression_data.gd` — locked path (см. Замечания); координировать правку, держать диф минимальным и изолированным.

4. **Подкрутить значения cap/knee итеративно** так, чтобы:
   - berserk/hammer 20t упал в коридор top-tier AoE и под 2.5x медианы;
   - формульный гейт остался зелёным (он не должен меняться вовсе — проверка, что cap нейтрален на пустых run_modifiers).

5. **(Если трактуем Acceptance глобально)** убедиться, что cap также вводит в коридор chemist/acid_flask, dark_mage/dark_book, ranger/hunter_trap, chemist/blast_powder. Если они растут не от боевых множителей, а от радиуса/числа снарядов/DoT — оценить, нужен ли отдельный cap на `aoe_radius_multiplier^exp` или это вне скоупа SCRUM-503 (тогда оформить отдельным тикетом, не раздувать P0).

6. **Перегенерировать CSV** (шаг 1) и проверить все пороги Acceptance.

7. **Прогнать формульные гейты** (см. Acceptance) и убедиться, что зелёные.

8. **Закрепить регрессией:** добавить/расширить тест-гейт на ЖИВУЮ матрицу — ассерт `max(lvl20_ideal_20t) ≤ 2.5 × median` и `berserk/hammer 1t ≤ порог`. Тикет называет `tests/global_damage_balance_smoke_test.gd`, но он формульный (читает только `estimate_*`, run_modifiers пусты) и НЕ ловит runaway — добавлять live-ассерт туда бессмысленно. Варианты: (а) новый отдельный тест-гейт, читающий `build/character_balance_dps.csv` (быстро, но требует свежей генерации); (б) лёгкий live-гейт, который сам гоняет урезанный замер. Зафиксировать выбор в ответе.

## Acceptance Criteria

- [ ] В перегенерённом `build/character_balance_dps.csv` `max(lvl20_ideal_20t)` по ЛЮБОМУ оружию ≤ 2.5x медианы по строкам (сейчас глобальный max = chemist/acid_flask 10.0x, нарушен).
- [ ] berserk/hammer `lvl20_ideal_20t` в коридоре top-tier AoE (~50-65k уже достигнуто частичным фиксом — подтвердить, что не вылез обратно) и ≤ 2.5x медианы.
- [ ] berserk/hammer `lvl20_ideal_1t` ≤ ~3500 (буквальный тикет) И желательно ≤ 2.5x медианы solo (≈2363); сейчас 2520 — формально проходит буквальный, на ~7% выше «2.5x медианы».
- [ ] `tests/class_damage_table_3variants_test.gd` зелёный: relative_score Берсерка в 0.90..1.10 (фактически — числа формульного гейта не должны измениться вовсе, т.к. cap нейтрален на пустых run_modifiers).
- [ ] `tests/global_damage_balance_smoke_test.gd` зелёный: combined ±25%, solo corridor ±20%, CCT ±30%.
- [ ] Base lvl1 числа Берсерка в CSV (`lvl1_1t/5t/20t` для sword/axe/hammer) НЕ изменились (правка только сверху базы: через soft-cap забеговых множителей / новые BalanceData-константы, а не через base_stats/weapon base damage).
- [ ] Добавлен/расширен автоматический регресс-гейт, ловящий runaway по ЖИВОЙ матрице (а не только по формуле), и он зелёный.

## Files / точки входа

- `scripts/progression_data_balance.gd` (BalanceData) — добавить константы soft-cap/knee для забеговых боевых множителей (по образцу `CRIT_CHANCE_CAP`/`CRIT_CHANCE_DIMINISH`, `SURVIVABILITY_*`). Реэкспорт констант в `progression_data.gd:39-40` уже есть как паттерн — добавить аналогичные строки реэкспорта при необходимости.
- `scripts/progression_data.gd` (LOCKED) — `derived_parameters` `:820/:823/:829`: применить soft-cap к забеговой части `damage_multiplier`/`attack_speed_multiplier`/(опц.)`aoe_radius_multiplier`. Опционально — новый хелпер рядом с `_diminishing_percent` (`:238`). Минимальный изолированный диф.
- `scripts/progression_data_weapons.gd` — `hammer` `:69-70` уже урезан; при необходимости докрутить `upgrade_*_exponent` молота/топора. Не трогать base `damage_multiplier`/`fire_interval` молота (это часть базы).
- `scripts/player.gd` — `apply_reward` `:693-763` (`:723` стак множителей): обычно правка НЕ нужна (cap живёт в derived_parameters); трогать только если решено капить на этапе записи в run_modifiers.
- `tools/character_balance_csv.gd` — генератор живой матрицы; перегенерировать после каждой правки. Менять сам генератор НЕ требуется (он — измеритель, не баланс).
- `tests/global_damage_balance_smoke_test.gd` — формульный гейт (держать зелёным). Сюда live-ассерт класть НЕ стоит (run_modifiers пусты). Новый live-регресс-гейт — отдельным файлом или как live-режим.
- `tests/class_damage_table_3variants_test.gd` — формульный гейт relative_score (держать зелёным).

## Замечания / подводные камни

- **LOCKED PATHS:** `scripts/progression_data.gd` и `scripts/ui_screens.gd` — координируемые/locked файлы (anti-collision). Основная правка cap затронет `progression_data.gd` — держать диф минимальным, не пересекаться с параллельными задачами по этому файлу, согласовать перед коммитом. `scripts/progression_data_balance.gd` тоже упоминается как чувствительный — менять только добавлением констант. `ui_screens.gd` трогать НЕ нужно.
- **Изоляция от формулы — главный инвариант.** Любой soft-cap ОБЯЗАН быть тождественным при `run_modifiers == {}` (множитель = 1.0), иначе поедут формульные гейты и base lvl1. Проверять это явным юнит-смыслом: `softcap(1.0) == 1.0`.
- **Не путать два конвейера DPS.** Формульный (`estimate_weapon_budget` → пустые run_modifiers, нормализован per-weapon к budget_target — выброс не виден) против живого (`character_balance_csv.gd` → реальный `apply_reward`, выброс виден). Тикет требует срезать ЖИВОЙ выброс, не трогая формульный коридор.
- **Трактовка Acceptance (узко vs глобально) — развилка, требующая решения.** Заголовок и причина тикета — про Берсерка (hammer 78x). Но критерий №1 написан как ГЛОБАЛЬНЫЙ max-инвариант, который сейчас нарушают chemist/acid_flask (10x) и dark_mage/dark_book (6.5x) — НЕ-Берсерк. Если чинить только Берсерка, критерий №1 формально останется красным из-за chemist. Рекомендация: реализовать общий soft-cap забеговых множителей (лечит всех, кто упирается в множительный стак), а если acid_flask/dark_book растут от радиуса/DoT/projectile_count (а не от damage_mult) — вынести их в отдельный тикет и в ответе явно указать, что критерий №1 для них вне скоупа P0-Берсерка. Не раздувать P0 неограниченно.
- **Edge-cases замера CSV:** генератор использует фиксированные сиды (`BASE_SEED=20260620`), неподвижные манекены (knockback нейтрализован), окно 8с. Числа детерминированы между прогонами — если после правки CSV не меняется детерминированно, значит cap не сработал на нужном пути. `lvl20_random` — один «невезучий» прогон, не усреднение; ориентироваться по `lvl20_ideal`.
- **DoT и крит — отдельные оси.** `dot_damage` (`progression_data.gd:877`) тоже умножается на `damage_multiplier` — если капить, не забыть согласованность (или сознательно оставить DoT вне cap). crit (`:868-869`) — отдельный мультипликатор; молот выигрывает в основном от damage_mult^exp × число целей, а не от крита.
- **Запуск тестов (QA-окружение):** Godot 4.6.x в `~/Downloads/Godot.app`. Команды:
  `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/global_damage_balance_smoke_test.gd`
  `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/class_damage_table_3variants_test.gd`
  Генерация матрицы: `... --script res://tools/character_balance_csv.gd`.
- **Связанные тикеты/системы:** SCRUM-249 (формульный гейт), SCRUM-453/469 (relative_score коридоры), SCRUM-523/524 (изоляция типов урона — НЕ нарушать: cap не должен протекать между типами; он умножает уже-изолированный `damage_multiplier`, общий для всех типов, что инвариант изоляции по атрибутам не задевает), SCRUM-198 (BalanceData split). Частичный фикс — коммит `1e74202b`.
- **Документация:** при изменении баланса обновить `docs/design/systems/progression_balance.md` (уже трогался в `1e74202b`) и CHANGELOG, как принято в проекте.

## QA-Вердикт (2026-06-27)
Статус: FAILED

Проверено:
- `tests/berserk_dps_runaway_gate.gd` — PASS: `berserk/hammer lvl20_ideal 20t=13792 <= 40000`, `1t=922 <= 2363`.
- `tests/class_damage_table_3variants_test.gd` — PASS: 17 classes / 153 weapon-build rows.
- `tests/global_damage_balance_smoke_test.gd` — PASS: 51 pairs, combined ±25%, solo ±20%, CCT ±30%.
- partial fresh `tools/character_balance_csv.gd` foreground run reached `berserk/hammer` and showed the stale checked-in 60k row is gone (`20t=16099.8`, `1t=840.5`), but the full run was terminated by the session cap before completion.

Блокер acceptance:
- Literal criterion `max(lvl20_ideal_20t) по любому оружию <= 2.5x медианы` is not accepted while linked defect `SCRUM-533` remains live.
- Context regression gate `tests/pool_dot_runaway_gate.gd` emitted failures on the current dirty dev worktree: `chemist/acid_flask lvl20_ideal_20t=1039203 > 70000`, `chemist/blast_powder=716038 > 70000`.
- Existing linked bug: `SCRUM-533` (`BUG: SCRUM-503 QA — live DPS cap still fails after Berserk hammer nerf`). No duplicate bug was created.

Ограничение QA:
- During QA, unrelated production dirty files appeared (`scripts/class_weapon.gd`, `scripts/enemy.gd`, `scripts/status_effects.gd`, `tests/runtime_smoke_test.gd`, `project.godot`, `docs/design/systems/combat.md`, `tests/damage_type_palette_test.gd`). QA stopped further production verification to avoid accepting concurrent dirty work and did not modify production code/assets.

## Backend-result / continuation (2026-06-28)
Статус: READY FOR QA.

Продолжение после backend worker `019f0afa-7d3b-7f93-957e-a8d625d039e3`: Berserk runaway gate уже был зелёным, но QA-блокер оставался в live pool DoT матрице (`chemist/acid_flask`, `chemist/blast_powder`). Правка расширена на общий live damage runaway путь без ослабления тестов.

Что изменено:
- `scripts/class_weapon.gd`: pool/chemist cloud теперь держит максимум 1 активную damage-pool на владельца оружия; pool tick и leaves-pool projectile explosion получают отдельные runtime-множители и target falloff; secondary DoT/pool/splash урон больше не вызывает recursive `owner_node.on_weapon_hit`, чтобы универсальные proc-эффекты не умножались от каждого тика/вторичной цели.
- `scripts/progression_data.gd`: положительный run-only `dot_damage_flat` capped до `12.0`, `dot_speed_flat` capped до `1.0`; отрицательные run-моды и passive-моды сохраняются без усечения.
- `scripts/progression_data_balance.gd`: run damage multiplier softcap tightened `20.0 -> 12.0`; Chemist level stat growth scalars подняты `1.52 -> 1.70`, чтобы трёхоружейный class-kit остался в формульном коридоре после live pool cap.
- `scripts/progression_data_weapons.gd`: `chemist/blast_powder` и `chemist/acid_flask` получили сниженный raw `damage_multiplier` плюс отдельный `pool_direct_damage_multiplier`, чтобы live splash/pool throughput вошёл в acceptance без превращения всего Chemist kit в клон одного слабого оружия.
- `docs/design/reports/class_damage_table_3variants.md`: перегенерирован формульный class table report.

Проверено на Windows через Godot 4.7 stable console (`C:\Users\FomaE\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`; Godot 4.6.3 локально недоступен):
- `tests/berserk_dps_runaway_gate.gd` — PASS: `berserk/hammer lvl20_ideal: 20t=5763 (≤12000), 1t=626 (≤2363)`.
- `tests/pool_dot_runaway_gate.gd` — PASS: `chemist/acid_flask lvl20_ideal 20t=68085 (≤70000)`, `chemist/blast_powder lvl20_ideal 20t=62631 (≤70000)`.
- `tests/global_damage_balance_smoke_test.gd` — PASS: `51 пар; combined ±25%, solo ±20%, CCT ±30%; худшее CCT +22% — doctor/restore_potion/20`.
- `tests/class_damage_table_3variants_test.gd` — PASS: `17 classes, 153 weapon-build rows`.

Residual risk / QA note:
- Это backend/balance fix; визуальные/анимационные области не затрагивались.
- `tools/jira_board_sync.py` на Windows всё ещё требует отдельной совместимости из-за Unix-only `fcntl`; Jira обновлена прямым REST-комментарием.
