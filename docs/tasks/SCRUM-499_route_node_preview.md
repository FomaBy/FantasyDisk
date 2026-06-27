# SCRUM-499: Превью узлов маршрута: показать награду/угрозу до входа

Jira: SCRUM-499 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: —
Статус: К выполнению (Feature)

## Что и зачем

На маршрутной карте (`RouteMapScreen`) узлы сейчас различимы только по типу (бой/элитка/магазин/событие/костёр/босс) через иконку и общий tooltip. Tooltip полностью статичен: один и тот же текст для всех боёв, для всех элиток, для босса. Игрок не может осмысленно планировать развилку — он не знает, какой биом/арена будет в бою, кто из 5 боссов ждёт в финале акта, и что именно даст элитка.

Цель: превратить выбор развилки в тактическое решение, а не в угадайку. Игрок при наведении на узел должен видеть предсказуемую превью-информацию, сгенерированную **вместе с маршрутом** (детерминированно по тому же seed) и совпадающую с тем, что реально стартует при входе в узел:

- бой/элитка — биом/фон арены + краткий намёк на состав волны («много стрелков» / «крупный бронированный»);
- финальный boss-узел — какой именно из 5 боссов ждёт (имя + иконка), чтобы готовиться под его механики;
- элитка — пометка о гарантированной награде-артефакте + ориентир тира по глубине акта.

Ожидаемый результат: tooltip узла обогащён превью-строками, превью детерминировано (хранится в самом route node, переживает autosave) и реально соответствует контенту боя.

## Текущее состояние в коде

### Генерация маршрута — `scripts/route_map_screen.gd`
- `_generate_route()` (стр. 189–214) строит ряды узлов: на каждый шаг `_node_pool_for_step()` (177–186) даёт пул типов, `game.rng.randi_range(...)` выбирает тип, узел получает поля `{type, name, row, branch}`. Связи проставляет `_assign_route_connections()` (250–278) в `next_branches`.
- Финальный boss-узел: `_random_boss_route_node()` (217–247) — **уже детерминирован**: выбирает один из 5 (`rift_warden / disk_devourer / bone_archon / brood_mother / ashen_colossus`) и **сохраняет `boss_id` и `name` прямо в route node**. Это эталон того, как надо хранить превью для остальных типов.
- Tooltip узла строится в `_draw_route_nodes()` (397–424), стр. 407:
  `button.tooltip_text = "%s\n%s" % [definition["name"], definition["tooltip"]]` — берёт только статический текст из `MAP_NODE_DEFINITIONS`, route node при этом игнорируется. **Это главная точка вставки превью.**

### Боевой контент — `scripts/combat_director.gd`
- `_start_combat(is_boss_fight, combat_type)` (13–56) → `_setup_arena_world()` → `_spawn_arena_background()`.
- **Биом/фон выбирается НЕдетерминированно при входе в бой**: `_background_path_for_current_node()` (751–756) делает `game.rng.randi_range(...)` по `game.ARENA_BACKGROUND_OPTIONS[key]`, где `key = "boss" if is_boss_fight else game.current_node_type`. То есть превью НЕ может прочитать фон — он каждый раз случайный. **Нужно перенести выбор фона в генерацию route node и читать оттуда в обе стороны (превью + бой).**
- **Тип элитки выбирается случайно при входе**: `_spawn_elite_enemy()` (507–531) → `_random_elite_scene()` (533–546) делает `game.rng.randi_range(...)` по 4 сценам (armored/stalker/poisoned/commander). В route node элитка не зафиксирована. **Нужно зафиксировать `elite_kind` в route node при генерации.**
- **Босс детерминирован**: `_spawn_boss()` (469–485) берёт `game.current_boss_id` (он проставляется в `_open_route_node()` из `route_node.boss_id`, стр. 623 route_map_screen). `_boss_scene_for_id()` (493–504) маппит id→сцену.
- Состав волны: `_spawn_enemy_wave()` (299+) использует статические `game.ENEMY_SPAWN_WEIGHTS` (main.gd 204–216) + ascension; **сейчас нет per-node вариации «много стрелков»**. Для namёка о составе достаточно лёгкого детерминированного тега (см. ниже), без переписывания спавна.

### Данные для превью — `scripts/progression_data_enemies.gd`
- `UNIQUE_ENCOUNTER_PATTERNS` (69–119) — каноничный источник для tooltip-текста угрозы. Ключи **точно совпадают** с `boss_id` из `_random_boss_route_node()` и с поведениями элиток (`iron_bastion/night_stalker/plague_prophet/shard_marshal`). Содержит `title` (рус.) и `summary` (рус. краткое описание механик) — идеально для строки превью босса/элитки.
- `MINI_ELITE_KINDS` (12–19) — на случай намёка по мини-элиткам в обычных боях (опционально).
- Маппинг сцена-элитки → ключ паттерна: armored→`iron_bastion`, stalker→`night_stalker`, poisoned→`plague_prophet`, commander→`shard_marshal` (см. `_elite_scene_by_key` combat_director 259–270 и `ELITE_ATTACK_CONFIGS`/`UNIQUE_ENCOUNTER_PATTERNS`).

### Узловые определения — `scripts/main.gd`
- `MAP_NODE_DEFINITIONS` (118–168): name/icon/tooltip/color/border на тип. Boss-узел имеет `icon_path` (rift_warden) и `disk_icon_path` (disk_devourer).
- `ARENA_BACKGROUND_OPTIONS` (41–72): пулы фонов `default/battle/boss`. Имена файлов несут биом (`field_marsh`, `field_dusty_badlands`, `field_ashen_rift`, `field_cursed_grove`, `field_enchanted_meadow`, ...). Из имени файла можно вывести человекочитаемый биом.
- `rng` (363) — **единый** `RandomNumberGenerator`, `randomize()` один раз в `_ready()` (411). Используется и для генерации маршрута, и для спавнов, и для тряски камеры. Поэтому «один и тот же seed» можно гарантировать ТОЛЬКО запекая выбор превью в route node при генерации (как уже сделано для босса), а НЕ повторным вызовом rng в момент боя.
- Autosave: `route_nodes` сериализуется через `route_nodes.duplicate(true)` (main.gd 519) и восстанавливается (554). Любые новые поля в route node переживут сохранение/загрузку автоматически.

### Иконки боссов — пробел в ассетах
- В `assets/sprites/map_icons/` есть только **2** boss-иконки: `map_boss_rift_warden.png`, `map_boss_disk_devourer.png`. Для `bone_archon / brood_mother / ashen_colossus` отдельной map-иконки НЕТ. Превью босса должно показывать имя всегда, а иконку — для двух доступных, с graceful fallback (общая boss-иконка) для остальных. Недостающие иконки — отдельный asset-таск (см. Замечания).

## Что сделать — по шагам

1. **Запечь биом в route node при генерации (`scripts/route_map_screen.gd`)**
   - В `_generate_route()` для узлов боёв и элиток (а также для boss-узла) при создании выбрать фон детерминированно из `game.ARENA_BACKGROUND_OPTIONS` тем же `game.rng` и сохранить в поле `route_node["arena_bg"]` (полный res-путь). Ключ пула: `"boss"` для boss-узла, иначе по типу (`"battle"`/`"battle"` для elite — в `ARENA_BACKGROUND_OPTIONS` нет ключа `elite_battle`, так что elite берёт `default`/`battle`; повторить ту же логику выбора ключа, что в `_background_path_for_current_node`).
   - Добавить хелпер `_biome_label_from_bg(path) -> String`: маппинг basename файла → рус. биом (например `field_dusty_badlands → «Пыльные пустоши»`, `field_ashen_rift → «Пепельный разлом»`, `field_cursed_grove → «Проклятая роща»`, `field_misty_marsh → «Туманное болото»`, `field_enchanted_meadow → «Зачарованный луг»`, `field_stone_garden → «Каменный сад»`, `field_marsh → «Болото»`, `field_dry_road → «Сухая дорога»`, `field_meadow → «Луг»`, `field_ruined_courtyard → «Разрушенный двор»`). Неизвестный путь → «Поле боя».

2. **Запечь тип элитки в route node (`scripts/route_map_screen.gd`)**
   - В `_generate_route()` для узлов `elite_battle` выбрать ключ паттерна детерминированно (`iron_bastion/night_stalker/plague_prophet/shard_marshal`) и сохранить `route_node["elite_kind"]`. Также можно сразу сохранить путь сцены, чтобы бой и превью совпадали 1:1.

3. **Читать запечённые поля в бою, НЕ перевыбирать (`scripts/combat_director.gd`)**
   - `_background_path_for_current_node()`: если у текущего узла есть `arena_bg` — вернуть его; иначе fallback на текущую rng-логику (для старых сейвов без поля). Текущий узел доступен через `game.route_nodes[game.route_stage][selected_branch]`; нужен аккуратный доступ к выбранному узлу (см. `route_selected_indices`). Альтернатива проще: при `_activate_route_node()` класть выбранный route node в `game.current_route_node` и читать `arena_bg`/`elite_kind` из него в combat_director.
   - `_random_elite_scene()` / `_spawn_elite_enemy()`: если у текущего узла есть `elite_kind` — спавнить именно эту сцену через `_elite_scene_by_key`, иначе старый рандом.
   - Цель: детерминизм — превью == реальный бой при том же маршруте.

4. **Обогатить tooltip в `_draw_route_nodes()` (`scripts/route_map_screen.gd`, стр. 407)**
   Заменить статический tooltip на сборку через новый хелпер `_route_node_tooltip(route_node, definition, step_index) -> String`:
   - **battle**: `definition.name` + биом (`«Арена: <биом>»`) + опц. намёк состава волны (см. шаг 5).
   - **elite_battle**: `definition.name` + биом + `«Угроза: <UNIQUE_ENCOUNTER_PATTERNS[elite_kind].title> — <summary>»` + `«Награда: гарантированный артефакт (тир ~<по глубине акта>)»`. Тир по глубине: вывести из `step_index` относительно `ROUTE_STEPS_TO_BOSS` (например ранние ряды → I–II, поздние → III). Сослаться на реальную систему тиров артефактов, если она есть в `progression_data.gd` (НЕ редактировать этот файл — только читать).
   - **boss**: `definition.name` + имя босса (рус. из `UNIQUE_ENCOUNTER_PATTERNS[boss_id].title`) + `summary` механик + биом. Иконку босса в tooltip передаём через имя; визуальную иконку узел уже несёт (`_route_node_icon_path`).
   - **shop/rest/event**: оставить статический текст (превью не требуется по AC), но прогнать через тот же хелпер для единообразия.

5. **(Опционально, в рамках AC «намёк на состав волны») лёгкий детерминированный тег боя**
   - В `_generate_route()` для боёв/элиток запечь `route_node["wave_hint"]` — выбранный детерминированно из небольшого набора (`«много стрелков»`, `«крупный бронированный»`, `«рой быстрых»`, `«смешанная волна»`). Если делать «по-настоящему» (реально влиять на спавн) — сместить веса `ENEMY_SPAWN_WEIGHTS` под тег в `_spawn_enemy_wave`; если по времени дорого — допускается чисто-косметический намёк, но тогда явно держать его согласованным (один и тот же тег и в превью, и при желании учесть в спавне позже). Для P1 минимально достаточно запечённого тега в tooltip; влияние на спавн можно вынести в follow-up.

6. **Safe-зона tooltip**
   - Godot-нативный `tooltip_text` рендерится системным тултипом; убедиться, что многострочный текст не уезжает за экран на 1280x720/1600x900/2560x1440 и не перекрывает соседние узлы. Если проект уже использует кастомный tooltip-фрейм для узлов — выровнять под него; иначе ограничить длину строк превью (перенос/обрезка) и держать в пределах safe-зоны фрейма (правило frame content safe-area из AGENTS.md). Проверить на трёх разрешениях вручную + смоук.

7. **Обновить `docs/design/systems/route_map.md`**
   - В разделе Interaction/Node Types описать, что tooltip боёв/элиток/босса несёт превью (биом, угроза, награда, имя босса) и что превью детерминировано (запечено в route node, переживает autosave).

8. **Тесты**
   - Расширить `tests/runtime_smoke_test.gd` (route/tooltip-секция, см. стр. ~144–158, 237–238, 1261–1262): проверить, что у боёв/элиток tooltip содержит биом-строку, у boss-узла — имя конкретного босса; что `arena_bg`/`elite_kind` присутствуют в сгенерированных узлах; что детерминизм держится — повторная генерация при том же seed даёт тот же `arena_bg`/`elite_kind` (или: значение, запечённое в узле, совпадает с тем, что выберет combat_director при входе).
   - Прогнать route smoke и runtime smoke (Godot 4.6.3 headless из `~/Downloads/Godot.app`).

## Acceptance Criteria
- [ ] Tooltip боя/элитного боя показывает биом/фон арены и краткий намёк на состав волны (например «много стрелков» / «крупный бронированный»)
- [ ] Tooltip финального boss-узла раскрывает, какой из 5 боссов ждёт (имя + иконка), чтобы можно было готовиться
- [ ] Элитный узел в tooltip помечает гарантированную награду-артефакт и ориентир тира по глубине акта
- [ ] Превью детерминировано: совпадает с тем, что реально стартует в узле (один и тот же seed/маршрут) — биом и тип элитки запечены в route node при генерации и читаются combat_director, а не перевыбираются rng
- [ ] Превью переживает save/load (поля сериализуются вместе с `route_nodes`)
- [ ] Tooltip остаётся внутри safe-зоны и не перекрывается на 1280x720 / 1600x900 / 2560x1440
- [ ] route smoke и runtime smoke проходят (включая новые ассерты на превью)
- [ ] Старые сейвы без новых полей не падают: graceful fallback на прежнюю rng-логику биома/элитки

## Files / точки входа
- `scripts/route_map_screen.gd`:
  - `_generate_route` (189) / `_random_boss_route_node` (217) — запекать `arena_bg`, `elite_kind`, опц. `wave_hint` в узлы.
  - `_draw_route_nodes` (397, строка tooltip 407) — обогатить tooltip через новый `_route_node_tooltip(...)`.
  - новые хелперы: `_biome_label_from_bg(path)`, `_route_node_tooltip(node, definition, step)`, `_pick_arena_bg_for_node(node_type, is_boss)`, `_pick_elite_kind()`.
  - `_open_route_node` (600) / `_activate_route_node` (453) — при желании класть выбранный узел в `game.current_route_node` для чтения в бою.
- `scripts/combat_director.gd`:
  - `_background_path_for_current_node` (751) — читать `arena_bg` из узла, fallback на rng.
  - `_spawn_elite_enemy` (507) / `_random_elite_scene` (533) — спавнить по `elite_kind`, fallback на rng.
- `scripts/main.gd`:
  - читать `ARENA_BACKGROUND_OPTIONS` (41), `MAP_NODE_DEFINITIONS` (118); возможно добавить var `current_route_node` рядом с `current_node_type`/`current_boss_id` (307–334). НЕ менять `progression_data.gd`.
- `scripts/progression_data_enemies.gd` — только ЧИТАТЬ `UNIQUE_ENCOUNTER_PATTERNS` (title/summary) для текста превью.
- `docs/design/systems/route_map.md` — описать превью.
- `tests/runtime_smoke_test.gd` — новые ассерты на превью/детерминизм.

## Замечания / подводные камни
- **Anti-collision / locked paths**: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — НЕ трогать (закреплены за другим контуром / read-only). Tooltip собирается в `route_map_screen.gd`, данные тянуть из `progression_data_enemies.gd` (его читать можно). Если потребуется добавить var состояния — класть в `main.gd`, не в progression_data.
- **Единый rng — главный подвох детерминизма**: нельзя «вычислять» превью повторным `rng.randi_range` в момент боя — порядок вызовов rng за время забега уже изменится. Единственно надёжный путь — запекать выбор в route node при генерации (как уже сделано для `boss_id`) и читать оттуда в обе стороны. Это и закрывает AC про «один и тот же seed».
- **Asset-gap по boss-иконкам**: есть map-иконки только для `rift_warden` и `disk_devourer`. Для `bone_archon/brood_mother/ashen_colossus` map-иконки нет — tooltip показывает имя всегда, иконку узла оставить с fallback (общая boss-иконка `map_boss_rift_warden.png`). Недостающие 3 иконки — отдельный asset-таск через fantasydisk-asset-generator (НЕ в рамках этого тикета; завести follow-up).
- **`ARENA_BACKGROUND_OPTIONS` не имеет ключа `elite_battle`** — elite сейчас попадает в `default`/`battle`-пул (через `current_node_type`=="elite_battle" → нет ключа → fallback `default`). Повторить ту же ветку выбора ключа, чтобы превью и бой брали ОДИН пул.
- **Биом-лейблы**: выводить из basename файла, а не хардкодить под индексы массива — пулы фонов могут пополняться. Неизвестный basename → нейтральное «Поле боя».
- **Тир артефакта элитки**: уточнить, есть ли в `progression_data.gd` реальная шкала тиров по глубине; если да — ориентир в tooltip согласовать с ней (только чтение). Если нет — дать грубый ориентир по `step_index`/`ROUTE_STEPS_TO_BOSS` и не выдумывать несуществующую систему.
- **Save-compat**: новые поля переживают autosave автоматически (`route_nodes.duplicate(true)`), но узлы из СТАРОГО сейва их не содержат — обязателен fallback в combat_director (`node.get("arena_bg", "")` пусто → rng-логика).
- **Safe-зона**: системный `tooltip_text` многострочный может выходить за край у узлов в верхнем ряду на больших разрешениях; держать строки короткими / проверить на 3 разрешениях. Соблюсти правило frame content safe-area (AGENTS.md + qa_protocol).
- **Связанные системы**: shop-reentry логика (`shop_reentry_*`) и `route_selected_indices` определяют «текущий выбранный узел» — если читать узел в combat_director через индексы, аккуратно учесть эти состояния; проще прокинуть выбранный узел через `game.current_route_node` в `_activate_route_node`/`_open_route_node`.
