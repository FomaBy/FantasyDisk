# Skill Tree 3.0: глубокий анализ и per-class деревья умений с классовой идентичностью

Статус: done
Приоритет: high
Роль: Back-end / Game Design (Claude)
Версия: 0.1.8
Создано: 2026-07-02
Jira: SCRUM-807
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/meta_progression.gd`, `scripts/ui_screens.gd` (экран дерева умений), `scripts/player.gd` (применение мета-модов), `tests/meta_skill_tree_smoke_test.gd`, `tests/skill_tree_per_hero_test.gd`, `docs/design/systems/skill_tree.md`

## QA-Вердикт (2026-07-02, codex-qa-claude-monitor recheck)

Статус: PASSED

Проверено на `origin/dev` @ `9fb1a8e4` после reopen-фикса:
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/skill_tree_per_hero_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/meta_skill_tree_smoke_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/attribute_relevance_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/class_progression_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/meta_points_per_ascension_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/berserk_dps_runaway_gate.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASSED.
- `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASSED.

Предыдущие блокеры закрыты: Biologist больше не получает non-relevant `aoe_radius`
на minor/notable-ветке (`vampiric_amount` secondary), Robot больше не получает
non-relevant `defense` на minor/notable-ветке (`regeneration` secondary), per-hero
тест запрещает optional/non-relevant attrs на minor/notable и исключает keystone,
док/тест/CHANGELOG синхронизированы на 61/100 focused build + near-cap ≈89/100.
Sidecar `019f21c4-8755-7623-9644-169a62a2a9bb` дал PASS-рекомендацию по статике.

## Реопен-фикс (2026-07-02, claude-backend) — блокеры QA закрыты

Ответ на QA-FAILED (codex-qa-claude-monitor). Все 4 блокера устранены; правки в
изолированном worktree от `origin/dev`, гейты зелёные (см. §Result / Evidence):

1. **Biologist × `aoe_radius`** (optional по матрице) → заменён на `vampiric_amount`
   (secondary; фантазия паразита/симбиоза) в attrs и notable «Симбиоз».
   `meta_progression_tree_data.gd`.
2. **Robot × `defense`** (optional по матрице) → заменён на `regeneration`
   (secondary; самопочинка брони) в attrs и notable «Бронеплиты».
   `defense_flat` в keystone «Овердрайв» оставлен намеренно (build-defining узел).
3. **`skill_tree_per_hero_test.gd`**: добавлен запрет чужих optional/non-relevant
   атрибутов на minor/notable-узлах ветви (keystone исключён). Тест теперь ловит
   промах, который раньше проходил зелёным.
4. **Бюджет силы приведён к одному факту**: `_test_realistic_build_power_budget`
   меряет сфокусированный билд **61/100** очков (потолок классовой силы дерева) и
   добавлен near-cap под-инвариант **≈89/100** (добор чужих ветвей affinity-gated,
   силу класса НЕ повышает). Док `skill_tree.md` §4 и §Validation синхронны с тестом.

## Мандат (от продукта, дословно по смыслу)

Продумать систему дерева умений для ВСЕХ персонажей в игре. Сделать глубокий
анализ: как дерево вообще используется в игре, как оно должно выглядеть, какая
у него структура, сколько должно быть нодов. Продумать главную логику дерева:
ноды добавляют атрибуты в понятных количествах, всё написано ясно и понятно.
Количество атрибутов не должно ломать баланс, но должно делать персонажей
сильнее — чтобы на разных возвышениях (ascension 0..5) они показывали себя
лучше. У всех персонажей должны быть плюс-минус РАЗНЫЕ атрибуты на дереве,
чтобы за каждого было по-разному играть и по-разному интересно изучать дерево.
Сначала глубокий анализ — потом реализация. Задача выполняется ПОЛНОСТЬЮ
автономно: никаких вопросов пользователю, все продуктовые развилки решает
исполнитель и фиксирует обоснование в дизайн-доке.

## Контекст / Проблема

Дерево умений v2 уже существует (SCRUM-696 «PoE-like shared graph» +
SCRUM-726 «per-hero skill tree»), но классовая идентичность в нём тонкая:

- `scripts/meta_progression.gd:82` — `SKILL_TREE = _build_skill_tree()`:
  107 узлов, суммарная стоимость 183 очка при `META_POINTS_CAP := 100`
  (строка 15) — «выбираешь путь, а не всё дерево» (это design intent, сохранить).
- Топология (`_build_skill_tree()`, строки 160–237): ядро 7 узлов (хаб, 2 minor,
  4 keystone) + 8 атрибутных «лепестков» по 4 узла (gate → +1 → +1 → notable
  +2) + 17 классовых «хвостов» по 4 узла (entry → minor → notable → keystone).
- Слабое место: у каждого класса всего 3 содержательных классовых нода, и все
  три — ОДИН и тот же вектор эффектов (`CLASS_SKILL_SIGNATURES`, строки 60–78),
  масштабированный ×0.18 / ×0.36 / ×1.0. 90% графа общие для всех классов:
  изучение дерева за разных героев ощущается одинаково, «атрибутные» ноды дают
  голые +1 атрибута без классового вкуса.
- Экономика очков: `META_POINT_REWARDS_BY_ASCENSION = [1,1,2,3,4,5]`
  (строка 16) — очки только за ПЕРВЫЙ клир каждого уровня возвышения каждым
  классом (максимум 16 за класс), общий пул `skill_points`, cap 100
  (`tests/meta_points_per_ascension_test.gd` — гейт экономики, не ломать).

Задача: спроектировать и реализовать «Skill Tree 3.0» — эволюцию этой системы
с настоящей классовой идентичностью, сохранив рабочие инварианты (граф,
экономика возвышений, сейв-миграции, балансовые потолки).

## Текущий код (карта для анализа — прочитать ДО дизайна)

- `scripts/meta_progression.gd` (935 строк) — всё дерево, экономика очков,
  сейв/лоад (`DEFAULT_SAVE_PATH = "user://fantasydisk_meta.cfg"`, ConfigFile,
  `TREE_SCHEMA_VERSION := 3`, миграция старых схем = безопасный полный респек),
  `allocate_node/reset_skill_tree`, `skill_modifiers(state)` (аккаунт-wide) и
  `skill_modifiers_for_class(meta_state, char_id)` (учитывает `class_affinity`
  нодов), `CLASS_PROGRESSION` (строки 99–105), `CLASS_CHALLENGES` (123–127).
- `scripts/progression_data_characters.gd` — 17 классов: `BASE_STATS` (8 базовых
  атрибутов, строки 16–135), `CHARACTER_CONFIGS` (137–268),
  `CLASS_MECHANIC_IDENTITIES` (290–478: main_attribute, mechanic_tags, weapon
  identities — опора для классового вкуса ветвей), `ATTRIBUTE_REGISTRY`
  (708–733: 24 боевых атрибута, flat/percent) и `ATTRIBUTE_RELEVANCE`
  (743–768: инвариант «на атрибут ровно 2 primary + 8 secondary + 7 optional
  классов», гейт `tests/attribute_relevance_test.gd`).
- `scripts/progression_data.gd` — конвейер модификаторов: soft-cap ран-мультипликаторов
  (`_soft_capped_run_multiplier`, 429–434), diminishing-формулы defense/dodge/
  absorb/crit (437–480), веса level-up наград по релевантности (255, 327, 372).
- `scripts/progression_data_ascension.gd` — возвышения: `ASCENSION_MODIFIERS`
  (15–26: чем страшнее A1..A5 — hp/dmg/спавны/элитки/таймер/лечение/босс+фаза/
  −20% HP игрока на A5) и `ASCENSION_LEVELS` (41+: per-class награды ступеней).
- `scripts/progression_data_balance.gd` — балансовые константы: comfort-band
  (`COMFORT_WEIGHTS`, допуски), `CLASS_BUDGET_PROFILES`,
  `BALANCE_BASE_SOLO_DPS`/`BALANCE_BASE_AOE_DPS`.
- `scripts/player.gd:874` — `apply_meta_skill_modifiers(mods)`: как мета-моды
  входят в расчёт статов игрока.
- `scripts/main.gd:498, 903–957` — загрузка меты, `record_boss_victory`,
  `apply_ascension_bonuses` на старте забега.
- `scripts/ui_screens.gd` (~10000 строк) — отрисовка экрана дерева (граф v2 уже
  рисуется), hero select с выбором возвышения.
- Тесты: `tests/meta_skill_tree_smoke_test.gd` (целостность графа, миграция,
  потолок силы `_test_full_tree_power_cap`, применение на старте забега),
  `tests/skill_tree_per_hero_test.gd` (17 keystone, class_affinity),
  `tests/meta_points_per_ascension_test.gd` (экономика очков),
  `tests/berserk_dps_runaway_gate.gd` (анти-runaway),
  `tests/class_progression_test.gd`.
- Дизайн-доки: `docs/design/systems/skill_tree.md` (главный док v2, обновлён
  2026-07-01), `docs/design/systems/progression_balance.md` (балансовые таргеты:
  спред DPS lvl20_ideal_1t ≤ 2.0x без берсерка, EHP-спред ~4x),
  `docs/design/systems/characters_weapons.md` (идентичности классов).

## Фаза 0 — Глубокий анализ (обязательный деливерабл)

Провести и ЗАПИСАТЬ в `docs/design/systems/skill_tree.md` (новая мажорная
редакция дока, v3) анализ:

1. Роль дерева в игровом цикле: когда игрок его открывает, сколько очков у него
   на руках на каждом этапе прогрессии (1 класс / 5 классов / все 17, возвышения
   0..5), что реально можно купить на 3 / 10 / 30 / 100 очков.
2. Аудит v2: полезность каждого типа нодов (голые +1 атрибута vs notable vs
   keystone), где дерево «скучное» и почему все классы изучают его одинаково.
3. Сколько нодов НУЖНО: обосновать целевой размер графа (общая часть + классовые
   ветви), стоимость полного графа vs cap 100, глубину выбора («на 100 очков
   покупается ~N% графа»). Ориентир: суммарно 150–250 узлов, но финальное число
   выводится из анализа, а не постулируется.
4. Вклад дерева в силу: сколько % DPS / EHP / utility даёт полностью прокачанный
   реалистичный билд (100 очков) сейчас и сколько должен давать в v3, чтобы
   помогать на A3–A5 (враги +hp/+dmg, −20% HP игрока на A5), НЕ ломая
   comfort-band (спред ≤2.0x) и runaway-гейты. Зафиксировать явный «бюджет силы
   дерева» числами в доке и защитить его тестом.
5. Классовая дифференциация: для каждого из 17 классов — какие атрибуты его
   (по `ATTRIBUTE_RELEVANCE` primary/secondary и `CLASS_MECHANIC_IDENTITIES`),
   какой фантазии/механике служит его ветвь, чем изучение его дерева отличается
   от соседей.

## Фаза 1 — Дизайн Skill Tree 3.0 (в том же доке)

Требования к дизайну (рамки, внутри них — свобода решений с обоснованием):

- Сохранить: граф-аллокацию (связность от точек входа), принцип «всё дерево не
  купить» (полная стоимость заметно выше cap), экономику очков за возвышения
  (формула 1/1/2/3/4/5 и гейт `meta_points_per_ascension_test.gd` НЕ меняются),
  сейв-миграцию (schema → 4, старые ноды → полный респек без потери очков, по
  образцу существующей миграции 1→3).
- Классовые ветви: у КАЖДОГО из 17 классов ≥8 классовых нодов (сейчас 4) с
  РАЗНООБРАЗНЫМИ эффектами (не один вектор ×скаляр): микс из атрибутных нодов
  его primary/secondary атрибутов, профильных ран-модов (ключи из
  `ATTRIBUTE_REGISTRY` / существующего пайплайна `skill_modifiers`), ≥2 notable
  и ровно 1 keystone с уникальной игровой механикой (build-defining, как
  существующие `death_save`/`guaranteed_rare_shop`-флаги, а не голый +X%).
  Классовые ноды помечаются `class_affinity` (эффект спит у других классов —
  механизм уже есть).
- Разные атрибуты у разных классов: распределение атрибутных нодов по ветвям
  обязано следовать `ATTRIBUTE_RELEVANCE` (primary-атрибуты класса — дешёвые и
  ранние в его ветви, optional — отсутствуют или дорогие). Инвариант матрицы
  2+8+7 не трогать.
- Читаемость (мандат «ясно и понятно»): у каждого нода русский title + desc с
  ЧИСЛАМИ эффекта в тексте (как сейчас «+1 к атрибуту», «+3% урона»); никаких
  «улучшает характеристики». Проверить тестом, что desc непустой и содержит
  число для всех нодов с эффектами.
- Общая часть графа: оставить компактное общее ядро (QoL/экономика/выживание),
  но центр тяжести перенести в классовые ветви. Если анализ покажет, что общие
  атрибутные «лепестки» v2 стоит сократить/переделать — сделать, с миграцией.
- Прогрессия по возвышениям: дизайн должен явно отвечать «что игрок покупает
  перед штурмом A2 / A4 / A5» (например, выживание к −20% HP на A5) — дерево
  делает высокие возвышения достижимыми, но не тривиальными.

## Фаза 2 — Реализация

- Данные дерева вынести в отдельный модуль (например
  `scripts/meta_progression_tree_data.gd` со static-конструктором), чтобы не
  раздувать `meta_progression.gd`; публичный API (`node_list`, `allocate_node`,
  `skill_modifiers*`, `entry_map`) сохранить обратно-совместимым.
- `TREE_SCHEMA_VERSION := 4` + миграция load_state (полный респек, очки
  пересчитываются из `meta_point_awards`/`ascension_levels` — паттерн уже есть).
- Новые ключи эффектов (если вводятся) прокинуть через
  `skill_modifiers_for_class` → `player.gd::apply_meta_skill_modifiers` →
  `ProgressionData.derived_parameters`, с учётом soft-cap конвейера.
- UI (`ui_screens.gd`): экран дерева должен показывать классовую ветвь
  ВЫБРАННОГО героя акцентно (подсветка/фокус его entry и ветви, чужие классовые
  ветви видны, но явно «спящие»), тексты нодов с числами читаемы. Радикальный
  визуальный редизайн НЕ входит в scope — только корректное отображение новой
  структуры и фокус на своём классе. Контент — в safe-area фреймов (правило
  проекта).
- Балансовая валидация: лёгкая Python/GDScript-симуляция вклада дерева
  (без полного CSV-прогона `character_balance_csv.gd` — он флакает SIGABRT под
  нагрузкой); существующие гейты держать зелёными.

## Фаза 3 — Тесты и гейты (все через `python3 tools/godot_gate.py`)

Расширить/добавить и прогнать:

- `tests/meta_skill_tree_smoke_test.gd`: целостность графа v3 (связность всех
  нодов от входов, отсутствие дублей id, cost>0), миграция schema 3→4,
  save/load roundtrip, потолок силы (`_test_full_tree_power_cap` — полное
  дерево дороже cap; новый под-тест: реалистичный 100-очковый билд в пределах
  задокументированного бюджета силы).
- `tests/skill_tree_per_hero_test.gd`: для всех 17 классов — ≥8 классовых нодов,
  ровно 1 keystone, ≥2 notable, эффекты keystone уникальны между классами,
  class_affinity фильтруется, primary-атрибуты класса представлены в его ветви,
  desc всех нодов с эффектами содержит числа.
- `tests/meta_points_per_ascension_test.gd` — без изменений, должен остаться
  зелёным (экономика не тронута).
- `tests/berserk_dps_runaway_gate.gd`, `tests/attribute_relevance_test.gd`,
  `tests/class_progression_test.gd`, `tests/runtime_smoke_test.gd` — зелёные.
- Прогон гейтов СЕРИАЛИЗОВАННО через `tools/godot_gate.py` (параллельные
  headless Godot душат друг друга, exit 137/144; ретраить под нагрузкой).

## Фаза 4 — Доки, синк, сдача

- Обновить: `docs/design/systems/skill_tree.md` (анализ + полный дизайн v3 —
  главный деливерабл «ясно и понятно»), touchpoints в
  `docs/design/systems/progression_balance.md`, `CHANGELOG.md` (Unreleased).
- Git: pull перед стартом; коммитить явным `git add` СВОИХ файлов (не `-A`,
  в репо параллельные воркеры), пушить в `origin/dev` сразу после зелёных
  гейтов; коммиты с ключом задачи.
- Jira live-sync на каждом шаге (взял → «В работе» + комментарий; готово →
  комментарий с evidence). Сдача в QA: в этом .md первым словом статуса ровно
  `Статус: done` + раздел «Result / Evidence» со списком изменённых файлов,
  прогнанных гейтов и ключевых чисел дизайна; Jira → «Контроль качества».
  Блок «## QA-Вердикт» НЕ добавлять (его пишет QA).

## Acceptance Criteria

1. В `docs/design/systems/skill_tree.md` — редакция v3: анализ (Фаза 0) +
   полная спецификация (структура, число нодов и обоснование, стоимости,
   бюджет силы числами, per-class ветви всех 17 классов с конкретными нодами,
   эффектами и числами, план миграции).
2. В коде — дерево v3: у каждого из 17 классов ≥8 классовых нодов
   (≥2 notable + ровно 1 уникальный keystone), атрибутные ноды ветви следуют
   primary/secondary матрице релевантности класса; общая стоимость графа
   заметно превышает cap 100 (выбор пути сохраняется).
3. Все описания нодов на русском, с числами эффектов; на экране дерева ветвь
   выбранного героя в фокусе, чужие классовые ветви «спят».
4. Схема сейва 4 с миграцией без потери очков; save/load roundtrip зелёный.
5. Экономика очков за возвышения НЕ изменена (гейт зелёный); новый тест
   бюджета силы 100-очкового билда зелёный; berserk-runaway, attribute
   relevance, class progression, runtime smoke — зелёные.
6. CHANGELOG + Jira-комментарии с evidence; спека в статусе `done`, тикет в
   «Контроль качества»; всё запушено в `origin/dev` (включая .uid новых .gd).

## Процессные ограничения

- Полная автономия: продуктовые развилки решать самостоятельно, решение +
  обоснование фиксировать в дизайн-доке (раздел «Решения и трейд-оффы»).
- Балансовые скаляры классов (`CLASS_BUDGET_PROFILES`, comfort-веса) без
  крайней нужды не перенормировать — дерево аддитивный слой поверх базы;
  blocked-семейство балансовых тикетов (SCRUM-504/505/506/544) не трогать.
- Не гонять полный `character_balance_csv.gd` (SIGABRT-флаки) и
  `pool_dot_runaway_gate` параллельно с другими Godot-инстансами.
- Если объём UI-работ превышает разумный для одного прогона — допустимо вынести
  ПОЛИРОВКУ экрана (не функциональность) в follow-up .md-задачу в
  `docs/tasks/` с тем же процессом, зафиксировав это в Result.

## Result / Evidence

Реализована Skill Tree 3.0. Граф: **192 узла, стоимость 285** (cap 100 → на 100
очков ~35% графа), **21 keystone** (4 ядро + 17 классовых). У КАЖДОГО из 17
классов **≥8 классовых нодов** (5 профильных атрибутов по `ATTRIBUTE_RELEVANCE`
primary-first + 2 notable + 1 уникальный keystone). Экономика возвышений и
балансовые скаляры не тронуты — дерево аддитивный слой.

**Бюджет силы (числа, один фактический инвариант):** сфокусированный билд одного
класса = **61 очко из 100** (ядро 15 + лепестки 32 + классовая ветвь 14) — потолок
классовой силы дерева: `skill_modifiers_for_class` берсерка `damage_mult` ≈**0.125**
(ветвь 0.115 + общий strength-notable 0.010; коридор теста 0.08..0.40) + low-HP
механика keystone. Near-cap билд **≈89/100** (добор чужих ветвей) силу класса НЕ
повышает — эффекты affinity-gated. Аккаунтная сила почти нейтральна
(`estimated_power_multiplier` <1.30). Anti-runaway/comfort гейты дерево не прокачивают.

**Reopen-фикс (2026-07-02, claude-backend):** biologist `aoe_radius`→`vampiric_amount`,
robot `defense`→`regeneration` (attrs+notables, optional→secondary по матрице);
per-hero тест теперь запрещает optional-атрибуты на minor/notable (keystone исключён);
бюджет-тест приведён к 61/100 + near-cap ≈89/100. Правки в изолированном worktree от
`origin/dev`; гейты перегнаны зелёными (Godot 4.7).

**Изменённые/новые файлы:**
- `scripts/meta_progression_tree_data.gd` (**новый**) — данные + конструктор графа
  (лепестки, реестр атрибутов ветвей `ATTR_EFFECT`, per-class `CLASS_BRANCH_SPECS`,
  авто-генератор описаний с числами). +`.uid` сайдкар.
- `scripts/meta_progression.gd` — `TREE_SCHEMA_VERSION → 4` (авто-миграция 3→4:
  полный респек, очки из возвышений без потери); `SKILL_TREE = TREE_DATA.build_tree
  (CLASS_ENTRY_NODES)`; удалён старый билдер/данные (вынесены).
- `scripts/player.gd` — разведены `pickup_radius_flat`/`projectile_speed_flat`/
  `absorb_flat` в `META_SKILL_FLAT_MAP`.
- `scripts/ui_screens.gd` — фокус ветви выбранного героя; чужие классовые ветви
  «спят» (затемнены); пере-подсветка при смене класса.
- `tests/meta_skill_tree_smoke_test.gd` — коридоры v3 (150–260 нодов, cost>100) +
  новый под-тест бюджета силы `_test_realistic_build_power_budget`.
- `tests/skill_tree_per_hero_test.gd` — контракт v3 (≥8 нодов, ≥2 notable, 1
  уникальный keystone, primary-атрибуты представлены, числа в описаниях).
- `docs/design/systems/skill_tree.md` (**редакция v3**: анализ + полный дизайн +
  per-class таблица + миграция + решения/трейд-оффы), `progression_balance.md`,
  `CHANGELOG.md`.

**Прогнанные гейты (реопен, все через `tools/godot_gate.py`, Godot 4.7, ЗЕЛЁНЫЕ):**
- `meta_skill_tree_smoke_test` PASS (целостность 192/285, миграция→4, roundtrip,
  бюджет силы 61/100 + near-cap ≈89, capstone-флаги, экономика/скидки/attr-опции).
- `skill_tree_per_hero_test` PASS (17 классов, уникальные keystone, primary,
  запрет optional-атрибутов на minor/notable, числа, affinity-фильтр).
- `meta_points_per_ascension_test` PASS · `attribute_relevance_test` PASS
  (24×17, инвариант 2/8/7) · `class_progression_test` PASS · `runtime_smoke_test`
  PASS (14164 файлов) · `berserk_dps_runaway_gate` PASS (20t=2104≤3600, 1t=514≤650
  — дерево не влияет).

**Решения (подробно в дизайн-доке §Решения и трейд-оффы):** ядро+лепестки
сохранены, центр тяжести перенесён укрупнением классовых ветвей; keystone-и =
проверенные уникальные v2-векторы (build-defining, не голый +X%); magic_focus без
отдельного ключа (представлен через `damage_mult`); новые gameplay-флаги не
вводились (риск для одного прогона). UI — функциональный фокус без радикального
редизайна (в scope); визуальная полировка раскладки крупного графа — кандидат в
follow-up при необходимости.
