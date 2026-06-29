# SCRUM-516: Возвышения: сократить до 5 ступеней и усилить рост монстров

Jira: SCRUM-516 · Роль: backend · Контур: codex · Приоритет: P1 · foma · Эпик: SCRUM-214
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

## QA 2026-06-28

Статус: PASSED -> Jira `Готово`.

Проверено Codex QA в worktree `qa_508_codex190526` на текущем `origin/dev`
после follow-up `c9951fad`:
- `tests/ascension_curve_balance_test.gd` — PASS.
- `tests/meta_progression_smoke_test.gd` — PASS.
- `tests/meta_points_per_ascension_test.gd` — PASS.
- `tests/meta_skill_tree_smoke_test.gd` — PASS.
- `tests/runtime_smoke_progression_economy_test.gd` — PASS.
- `tests/codex_data_smoke_test.gd` — PASS, 5 вознесений.
- `tests/rewards_data_integrity_test.gd` — PASS, 5 вознесений.
- `tests/progression_data_api_surface_test.gd` — PASS.

Принято с уже задокументированным внешним риском: full `runtime_smoke_test.gd`
на текущем `dev` блокируется unrelated autosave continue-prompt regression,
не относящимся к SCRUM-516 ascension scope.

## Что и зачем

Сейчас система возвышений (ascension) — это **дорожка сложности забега** на 10 ступеней (0..10): каждая следующая ступень кумулятивно добавляет усложнения (крепче монстры, дороже цены, плотнее волны, опаснее босс и т.д.). Игрок открывает следующую ступень, добивая финального босса на текущем максимуме.

Проблема (из тикета): дорожка **слишком растянута** (10 шагов — долго и муторно открывать) и **недостаточно опасна** (шаг между уровнями ощущается слабым, монстры растут вяло).

Цель: **сжать лестницу до ровно 5 ступеней** и сделать **рост силы монстров на каждой ступени заметно сильнее**, чтобы 5 ступеней давали ту же (или большую) кривую вызова, что раньше 10, но проходились быстрее и ощущались острее. Игрок видит понятную короткую лестницу «Возв.: N / 5», где каждая ступень — это ощутимый скачок угрозы.

Ожидаемый результат для игрока:
- В выборе героя доступно максимум 5 ступеней возвышения вместо 10.
- На L1 монстры уже заметно злее, чем сейчас; на L5 — суммарный пресс не ниже, а лучше выше прежнего L10.
- Тексты/кодекс/UI нигде не обещают больше 5.
- Старые сейвы с ascension > 5 не крашат игру: значение клампится/мигрирует в [0..5].

## Текущее состояние в коде

Важно: в проекте под словом «ascension» живут **две связанные, но разные** структуры — обе сейчас по 10. Задача затрагивает обе, потому что они синхронизированы по числу ступеней.

### A. Дорожка сложности забега (главный предмет тикета)

`scripts/progression_data_ascension.gd`:
- `ASCENSION_MODIFIERS` (строки 5–26) — массив из **10** записей, по одной на ступень (`"level": 1..10`). Каждая запись содержит `mods` с множителями/флагами:
  - L1 `asc_hardened_foes`: `enemy_hp_mult 1.20`, `enemy_damage_mult 1.14`
  - L2 `asc_greedy_merchants`: `price_mult 1.25`
  - L3 `asc_swift_horde`: `spawn_count_mult 1.26`, `spawn_cooldown_mult 0.80`
  - L4 `asc_fierce_elites`: `elite_hp_mult 1.20`, `elite_instant_phase 1.0`
  - L5 `asc_scarce_spoils`: `reward_mult 0.80`
  - L6 `asc_thinned_flesh`: `healing_mult 0.70`
  - L7 `asc_abyssal_echo`: `mini_elite_chance 0.14`
  - L8 `asc_long_watch`: `round_duration_mult 1.25`, `enemy_hp_mult 1.10`
  - L9 `asc_warden_wrath`: `boss_hp_mult 1.20`, `boss_extra_phase 1.0`, `boss_telegraph_mult 0.75`, `mini_elite_chance -0.06`
  - L10 `asc_edge_of_madness`: `player_max_hp_mult 0.80`, `first_wave_boost 1.0`, `enemy_damage_mult 1.12`, `mini_elite_chance -0.05`
- `ASCENSION_DIFFICULTY_DEFAULTS` (строки 28–39) — нейтральные значения для L0 (всё ×1.0 / 0.0).

`scripts/progression_data.gd` (фасад, реэкспортит и считает кумулятив):
- стр. 83–84: `const ASCENSION_MODIFIERS := AscensionData.ASCENSION_MODIFIERS`, `const ASCENSION_DIFFICULTY_DEFAULTS := ...`.
- `ascension_difficulty_mods(level)` (стр. 320–335): собирает **кумулятивный** dict для уровня N — берёт все записи с `level <= clampi(level, 0, ASCENSION_MODIFIERS.size())`, множители `*_mult` перемножает, флаги (`elite_instant_phase`/`boss_extra_phase`/`first_wave_boost`) берёт по max, остальное (шансы) суммирует. **Клампит по `ASCENSION_MODIFIERS.size()`** — то есть верхняя граница сама подстроится под новый размер массива.
- `ascension_modifier_lines(level)` (стр. 338–345) и `ascension_level_change_line(level)` (стр. 348–356): текст для UI; тоже клампят по `ASCENSION_MODIFIERS.size()`.
- `ascension_modifiers()` (стр. 316–317): геттер массива (используется кодексом).

Потребители множителей сложности (через `game.ascension_difficulty()`):
- `scripts/combat_director.gd`: стр. 399–401 (`enemy_hp_mult`/`enemy_damage_mult` на обычных монстрах), 316 (`asc_spawn` плотность), 360 (`spawn_cooldown_mult`), 601 (`elite_hp_mult`), 625 (`boss_hp_mult`), 935 (`round_duration_mult`). **Эти места читают значения по ключам и НЕ зависят от числа ступеней** — менять их не нужно, они автоматически получат новые числа.
- `scripts/main.gd`: `ascension_difficulty()` (стр. 619–623, кэш на забег), `reset_run_ascension()` (стр. 626–629), `apply_ascension_bonuses()` (стр. 632–664, сворачивает `reward_mult`/`healing_mult`/`player_max_hp_mult` в `run_modifiers` игрока).

Выбор ступени и её клампы:
- `scripts/main.gd`: `selected_ascension_level` (стр. 388), сериализация в сейв (стр. 517, 552), `ascension_selectable_max()` (стр. 615–616).
- `scripts/meta_progression.gd`: **`MAX_ASCENSION_LEVEL := 10`** (стр. 7) — это **единый кап** для обоих смыслов. `ascension_level()` (стр. 131–135) и `selectable_max()` (стр. 167–169) клампят по нему; `record_boss_victory()` (стр. 138–164) поднимает пройденный уровень и выдаёт мета/скилл-очко **только за НОВОЕ возвышение** (до кап-уровня).

### B. Per-class наградная лестница возвышений (связанная структура)

`scripts/progression_data_ascension.gd`:
- `ASCENSION_LEVELS` (строки 41–246) — словарь `character_id -> Array из 10` per-class бонусов (damage/hp/attack_speed/… ), кумулятивных. Открываются теми же `record_boss_victory`, что и дорожка сложности, и капаются тем же `MAX_ASCENSION_LEVEL = 10`. Применяются в `apply_ascension_bonuses()` (main.gd стр. 636–640) через `PROGRESSION_DATA.ascension_mods(character_id, earned)` (progression_data.gd стр. 302–313).

Поскольку `MAX_ASCENSION_LEVEL` — общий кап и для дорожки сложности (A) и для наградной лестницы (B), при урезании до 5 **нужно урезать обе структуры до 5 записей**, иначе:
- если оставить B на 10, а A на 5 — игрок сможет выбрать только до 5 (по A.size через `selectable_max`… нет: `selectable_max` использует `MAX_ASCENSION_LEVEL`, а не размер массива A), и часть наградных уровней станет недостижимой;
- если оставить `MAX_ASCENSION_LEVEL=10`, а A сжать до 5 — UI разрешит выбрать ступени 6..10, но `ascension_difficulty_mods` клампит по `ASCENSION_MODIFIERS.size()`=5, и уровни 6..10 будут давать ту же сложность, что 5 (мёртвые ступени).

Вывод: единственно консистентный вариант — **5 везде**: `ASCENSION_MODIFIERS` → 5 записей, `ASCENSION_LEVELS[*]` → 5 записей на класс, `MAX_ASCENSION_LEVEL` → 5.

### Тесты, жёстко завязанные на «10»

- `tests/ascension_curve_balance_test.gd`: стр. 70–71 — **анти-вакуум `if max_level < 8`** (прямой конфликт с 5 ступенями, надо снизить порог до `< 5` или `<= 0`). Остальное в файле опирается на `PD.ASCENSION_MODIFIERS.size()` и монотонность — переживёт сжатие, если кривая останется монотонной и mini_elite-«горб» сохранится (см. ниже).
- `tests/runtime_smoke_test.gd::_test_ascension_difficulty_ladder` (стр. 5617–~5755, вызывается со стр. 1281):
  - стр. 5619 `ascension_modifiers().size() != 10` → 5;
  - стр. 5628–5651: проверки L3 (`enemy_hp 1.20`, `price 1.25`, `spawn 1.26`, текст «Быстрая орда»), L10 (`boss_extra_phase>0`, `player_max_hp 0.80`, `healing 0.70`) — переписать под новые номера/значения ступеней и новый максимум (L5);
  - стр. 5707 `asc_label "3 / 3"`, 5714/5717 текст «Уровень 3 / Быстрая орда / без Закалённые враги/Жадные торговцы» — переписать под актуальную раскладку 5-ступенчатой лестницы (3 victories → selectable_max 3 всё ещё валидно при кап=5, но текст ступени 3 поменяется).
- `tests/meta_progression_smoke_test.gd`: стр. 55–56 кап через `MAX_ASCENSION_LEVEL` (символьно — ок); стр. 63–82 `_test_ascension_levels_data` — **`levels.size() != 10` → 5** (для berserk/dark_mage/guitarist); стр. 84–104 `_test_cumulative_mods` проверяет `ascension_mods("berserk", 5)` (берёт суммы уровней 1..5 berserk) — при сжатии berserk до 5 уровней значения L1..L5 надо сохранить (или обновить тест под новые числа).
- `tests/runtime_smoke_test.gd`: стр. 4237/4304/4363/4433/4489/4545/4606/4672/4738 — серия `ProgressionData.ascension_levels(<class>).size() != 10` (по классам). **Все → 5.**
- `tests/meta_points_per_ascension_test.gd`: использует `Meta.MAX_ASCENSION_LEVEL` символьно (ок), но комментарии «L10 / 10 на класс» (стр. 52, 66) стоит освежить. Логика «фарм не даёт очко», «максимум не даёт очко» останется валидной.
- `tests/meta_skill_tree_smoke_test.gd`: циклы `record_boss_victory` (стр. 77 `range(9)`, 78, 417) — это набивка очков, **не** привязаны к числу ступеней одного класса (очко даётся за новое возвышение любым классом; см. бюджет ниже). Перепроверить, что нужное число очков по-прежнему набирается; при необходимости поднять число побед/классов.
- `tests/codex_data_smoke_test.gd::_check_ascensions` (стр. 137–150) и `tests/rewards_data_integrity_test.gd::_check_ascension_modifiers` (стр. 125–141), `tests/progression_data_api_surface_test.gd` (стр. 55–56) — **count-agnostic**, менять не нужно.

### Тексты/UI, обещающие >5

- `scripts/ui_screens.gd:3856` — `ascension_label.text = "Возвышение: %d/10"` (карточка героя) — **hardcoded «/10»**, заменить на динамику от `MAX_ASCENSION_LEVEL` (или «/5»). ВНИМАНИЕ: `ui_screens.gd` — locked path (см. подводные камни).
- `scripts/ui_screens.gd:963` — `asc_label.text = "Возв.: %d / %d" % [..., maxl]` использует `ascension_selectable_max` динамически — **менять не нужно**, само станет «/5» после правки `MAX_ASCENSION_LEVEL`.
- `docs/design/systems/progression_balance.md:159` — «Ascension levels: 10 уровней на персонажа» → «5 уровней».
- `scripts/glossary.gd:27` (`ascension`) и `scripts/codex_data.gd` — описания не называют число ступеней (count-agnostic), правки не требуют.
- `scripts/patch_notes_data.gd` — историю патчей не трогаем; новую строку патч-ноута про «возвышения сжаты до 5 / монстры злее» можно добавить отдельно (опционально, по усмотрению; не обязательное условие тикета).

## Что сделать — по шагам

1. **Сжать дорожку сложности до 5 ступеней с усилением монстров.** В `scripts/progression_data_ascension.gd` переработать `ASCENSION_MODIFIERS` в **ровно 5 записей** (`level: 1..5`). Перенести смысловые усложнения старых 10 ступеней в 5 более «толстых» шагов, усилив монстерский пресс:
   - Сохранить ключевые рычаги: `enemy_hp_mult`, `enemy_damage_mult` (основной пресс — должен расти заметнее прежнего), `price_mult`, `spawn_count_mult`/`spawn_cooldown_mult`, `elite_hp_mult`/`elite_instant_phase`, `reward_mult`, `healing_mult`, `round_duration_mult`, `boss_hp_mult`/`boss_extra_phase`/`boss_telegraph_mult`, `player_max_hp_mult`, `first_wave_boost`, `mini_elite_chance`.
   - **Монстры заметно сильнее:** на каждой следующей ступени `enemy_hp_mult`/`enemy_damage_mult` должны давать больший прирост, чем сейчас (текущий L1 hp 1.20/dmg 1.14 — взять как минимум столько же на L1 и круче эскалировать дальше; кумулятивный `enemy_hp_mult` на новом L5 должен быть ≥ прежнего кумулятива на L10). Конкретные числа подобрать так, чтобы прошёл `ascension_curve_balance_test` (монотонный неубывающий пресс) и баланс-смоук.
   - **mini_elite «горб»:** тест требует, чтобы `mini_elite_chance` вводился НЕ на L0, пик был НЕ на максимуме (`peak_level < max_level`), и на максимуме спадал до `<= 0.5 * peak`. На 5 ступенях это значит: ввести мини-элиток на средней ступени (напр. L3), пик на L3, на L4–L5 снизить (отрицательные дельты или меньший вклад), на L5 — заметно меньше пика. Сохранить логику «меньше элиток на высоких, пресс держат обычные монстры + босс».
   - Боссовые/игроцкие усложнения (`boss_extra_phase`, `player_max_hp_mult`, `first_wave_boost`) сдвинуть на верхние ступени (L4–L5).
   - Каждой записи — уникальный `id`, непустой `title`, человеко-читаемый `description` по-русски (его показывает кодекс и кнопка старта). Не оставлять no-op записей (`rewards_data_integrity_test` ругнётся на пустые mods).
2. **Сжать per-class наградную лестницу до 5.** В том же файле в `ASCENSION_LEVELS` для **каждого** класса оставить **ровно 5** записей (сейчас 10). Уникальные id, непустые mods. Рекомендуется сохранить значения первых пяти уровней (особенно berserk: L1 `damage_multiplier 1.05`, L2 `max_health_flat 8.0`, L5 `damage_multiplier 1.07` — на них завязан `meta_progression_smoke_test::_test_cumulative_mods`), либо синхронно обновить ожидания теста. Капстоун-уровень (бывший asc_10) логично перенести на новый L5.
3. **Опустить общий кап.** В `scripts/meta_progression.gd` `MAX_ASCENSION_LEVEL := 10` → `5` (стр. 7). Это автоматически: ограничит `selectable_max` 0..5, клампит загрузку сейвов (`load_state` стр. 102 уже клампит по `MAX_ASCENSION_LEVEL`), `ascension_level()`/`record_boss_victory()`. **Миграция сейвов** обеспечивается существующим `clampi(..., 0, MAX_ASCENSION_LEVEL)` — значение >5 из старого сейва молча станет 5 без краша. Перепроверить, что это так для всех точек чтения.
4. **Поправить hardcoded «/10» в UI.** `scripts/ui_screens.gd:3856` — заменить `"Возвышение: %d/10"` на динамику (например `"Возвышение: %d/%d" % [ascension_level, game.META_PROGRESSION.MAX_ASCENSION_LEVEL]` или прямую константу 5, в стиле соседнего кода). (Locked path — см. подводные камни.)
5. **Обновить тесты под 5 ступеней:**
   - `tests/ascension_curve_balance_test.gd`: порог анти-вакуума стр. 70–71 `if max_level < 8` → `if max_level < 5` (или `<= 0`). Остальное должно пройти, если кривая монотонна и mini_elite-горб сохранён.
   - `tests/runtime_smoke_test.gd::_test_ascension_difficulty_ladder`: `.size() != 10 → != 5`; переписать конкретные проверки уровней/значений/текста (L3, L10→L5) под новую раскладку; поправить ожидания текста ступеней и метку «N / 5».
   - `tests/meta_progression_smoke_test.gd`: `_test_ascension_levels_data` `!= 10 → != 5`; при изменении berserk-чисел — обновить `_test_cumulative_mods`.
   - `tests/runtime_smoke_test.gd`: все per-class `ascension_levels(<class>).size() != 10 → != 5` (стр. 4237, 4304, 4363, 4433, 4489, 4545, 4606, 4672, 4738).
   - `tests/meta_skill_tree_smoke_test.gd`: проверить, что набивка очков (циклы record_boss_victory) по-прежнему даёт достаточно skill_points для тестируемых покупок; при необходимости увеличить число классов/побед. Освежить комментарии «L10».
   - `tests/meta_points_per_ascension_test.gd`: освежить комментарии «L10 / 10 на класс» (логика символьная, останется зелёной).
6. **Обновить документацию.** `docs/design/systems/progression_balance.md:159` «10 уровней» → «5 уровней». Добавить пометку про усиленный монстерский пресс при необходимости.
7. **Прогнать гейты** (см. Acceptance) и убедиться, что баланс-смоук показывает заметно более сильный рост монстров и кумулятив на L5 ≥ прежнего L10 по `enemy_hp_mult`.

## Acceptance Criteria

- [ ] В выборе героя доступно **ровно 5** ступеней возвышения: `PROGRESSION_DATA.ascension_modifiers().size() == 5`, `MetaProgression.MAX_ASCENSION_LEVEL == 5`, `selectable_max` не превышает 5.
- [ ] Monster scaling на каждой следующей ступени **заметно сильнее текущего**: кумулятивный `enemy_hp_mult`/`enemy_damage_mult` растёт монотонно и на новом L5 ≥ прежнего кумулятива на L10; шаг между соседними ступенями ощутимо больше прежнего (проверяется детерминированным `ascension_curve_balance_test` + баланс/economy смоук или отчётом).
- [ ] Per-class наградная лестница `ASCENSION_LEVELS[*]` содержит ровно 5 уровней для каждого класса (все 18 классов), уникальные id, непустые mods.
- [ ] UI/тексты/кодекс/описания **не обещают больше 5**: `ui_screens.gd` метка возвышения показывает `/5` (или динамику), `progression_balance.md` говорит «5 уровней», кодекс перечисляет 5 ступеней сложности.
- [ ] Существующие сейвы со значением ascension > 5 (мета-cfg и autosave) корректно клампятся/мигрируют в [0..5] **без краша** при загрузке.
- [ ] Зелёные гейты: `tests/ascension_curve_balance_test.gd`, `tests/runtime_smoke_test.gd` (включая `_test_ascension_difficulty_ladder` и per-class size-проверки), `tests/meta_progression_smoke_test.gd`, `tests/meta_points_per_ascension_test.gd`, `tests/meta_skill_tree_smoke_test.gd`, `tests/codex_data_smoke_test.gd`, `tests/rewards_data_integrity_test.gd`, `tests/runtime_smoke_progression_economy_test.gd`.
- [ ] Бюджет мета-древа умений по-прежнему достижим: суммарно доступных skill_points (одно очко за новое возвышение каждым из 18 классов × 5 = до 90) покрывает `skill_tree_total_cost()` (=42). (Sanity, не должно сломаться от сжатия.)

## Files / точки входа

- `scripts/progression_data_ascension.gd` — `ASCENSION_MODIFIERS` (строки 5–26): сжать до 5 ступеней, усилить монстров; `ASCENSION_LEVELS` (41–246): по 5 уровней на класс; `ASCENSION_DIFFICULTY_DEFAULTS` (28–39): синхронизировать ключи, если меняется набор рычагов.
- `scripts/meta_progression.gd:7` — `MAX_ASCENSION_LEVEL := 10` → `5` (единый кап для дорожки и наградной лестницы; кламп сейвов уже есть в `load_state`/`ascension_level`/`selectable_max`).
- `scripts/ui_screens.gd:3856` — заменить hardcoded `"Возвышение: %d/10"` на динамику от `MAX_ASCENSION_LEVEL`. (Locked path.)
- `docs/design/systems/progression_balance.md:159` — «10 уровней» → «5 уровней».
- `tests/ascension_curve_balance_test.gd:70` — порог анти-вакуума `< 8` → `< 5`.
- `tests/runtime_smoke_test.gd` — `_test_ascension_difficulty_ladder` (5617+): переписать под 5 ступеней/новые значения; per-class size-проверки (4237/4304/4363/4433/4489/4545/4606/4672/4738) `!= 10 → != 5`.
- `tests/meta_progression_smoke_test.gd` — `_test_ascension_levels_data` (66) `!= 10 → != 5`; при изменении чисел berserk — `_test_cumulative_mods` (84+).
- `tests/meta_skill_tree_smoke_test.gd`, `tests/meta_points_per_ascension_test.gd` — перепроверить набивку очков / освежить комментарии.
- НЕ менять (count-agnostic): `scripts/progression_data.gd` функции `ascension_difficulty_mods/ascension_modifier_lines/ascension_level_change_line` (клампят по `ASCENSION_MODIFIERS.size()`), `scripts/codex_data.gd::ascensions`, `scripts/combat_director.gd` потребители (читают по ключам), `scripts/ui_screens.gd:963` (использует `selectable_max`).

## Замечания / подводные камни

- **Две структуры под одним капом.** `MAX_ASCENSION_LEVEL` управляет И дорожкой сложности (A: `ASCENSION_MODIFIERS`) И наградной лестницей (B: `ASCENSION_LEVELS`). Урезать нужно **синхронно обе до 5 + кап до 5**, иначе появятся мёртвые/недостижимые ступени (см. раздел B). Это главный архитектурный момент задачи.
- **Locked paths (анти-коллизия).** `scripts/ui_screens.gd` и `scripts/progression_data.gd` — locked paths по правилам проекта (особо `ui_screens.gd`). Правка `ui_screens.gd:3856` обязательна (hardcoded «/10»), но мелкая и точечная — координировать, чтобы не пересечься с UI-исполнителем. `progression_data.gd` менять, скорее всего, **не придётся** (логика count-agnostic) — основная масса правок в `progression_data_ascension.gd` (данные) и `meta_progression.gd` (кап).
- **Миграция сейвов.** Кламп уже встроен (`meta_progression.gd::load_state` стр. 102, `ascension_level` стр. 135; `main.gd` грузит `selected_ascension_level` и затем `reset_run_ascension`→`clampi(0, selectable_max)`). Проверить путь autosave (`main.gd:552`): после загрузки старого `selected_ascension_level=7` он должен склампиться в 5 без ошибки. Запустить runtime-смоук на сейв-миграцию (в `runtime_smoke_test.gd` уже есть `selected_ascension_level=2` фикстуры — добавить/проверить кейс >5, если уместно).
- **Баланс-кривая — не ломать инварианты теста.** `ascension_curve_balance_test` требует: L0 нейтрален; `enemy_hp_mult`/`enemy_damage_mult` монотонно неубывают; L1 уже усиливает монстров (>1.0); `hp[max] > hp[1]`; mini_elite вводится, пик НЕ на максимуме, на максимуме `<= 0.5*peak`. На 5 ступенях держать тот же профиль (горб элиток на L3, спад к L5).
- **Не урезать число рычагов так, чтобы потерять покрытие потребителей.** `combat_director`/`main` читают конкретные ключи (`elite_hp_mult`, `boss_hp_mult`, `round_duration_mult`, `reward_mult`, `healing_mult`, `player_max_hp_mult`, и т.д.). Все они должны остаться в `ASCENSION_DIFFICULTY_DEFAULTS` и появляться хотя бы на одной из 5 ступеней (иначе ступени станут беднее по типам угроз). Соберите 5 «толстых» ступеней так, чтобы суммарно покрыть прежние 10 рычагов.
- **Per-class числа и тест cumulative.** `meta_progression_smoke_test::_test_cumulative_mods` жёстко ждёт berserk L1 `damage 1.05`, кумулятив L5 `damage 1.05*1.07` и `max_health_flat 8.0`. Либо сохранить эти значения в новых berserk L1..L5, либо синхронно обновить тест. Аналогично проверить, что у каждого класса 5 уровней дают осмысленный, не слабее-прежнего, суммарный бонус (капстоун-уровень перенесён на L5).
- **Связанные тикеты:** эпик SCRUM-214; кривая возвышений ранее настраивалась в SCRUM-358 (откуда текущие L1 hp1.20/dmg1.14 и логика «горба» mini_elite — её инварианты надо сохранить); экономика мета-очков за возвышение — SCRUM-150 / класс-прогрессия SCRUM-360 (не привязаны к числу ступеней, но проверить, что набивка очков в их тестах не опирается на 10).
- **Не забыть кодекс.** `codex_data.ascensions()` авто-перечисляет ступени из данных — после сжатия кодекс сам покажет 5; убедиться, что у новых 5 записей корректные title/description (их валидирует `codex_data_smoke_test`).
