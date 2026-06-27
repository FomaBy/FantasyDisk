# SCRUM-511: UX-quirk: level-up на узле события возвращает на карту, а не к экрану события

Jira: SCRUM-511 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: SCRUM-213 (через карри-овер SCRUM-477)
Статус: К выполнению

## Что и зачем

Когда игрок стоит на узле-события (не в бою) и в этот момент срабатывает повышение уровня
(`pending_level_ups > 0`), нажатие кнопки «+» открывает экран выбора усиления. После того как
игрок выбрал усиление (или нажал «Позже»/Escape), игра уводит его НА КАРТУ МАРШРУТА
(`game.route._show_battle_map()`), а не обратно к экрану события, на котором он находился.

При этом `current_event_definition` всё ещё активен — событие НЕ отыграно, исход не выбран.
Игрок теряет контекст: он выходил «прокачаться», а вернулся на карту, и неочевидно, что
событие осталось неразрешённым (вернуться к нему можно только снова кликнув по узлу — но узел
ещё текущий, прогресс `route_stage` не двинулся).

Не game-breaking, но ломает поток: «открыл прокачку поверх события → выбрал → вернулся на карту
вместо события». Цель — после level-up, открытого ПОВЕРХ активного события, возвращать игрока
на тот же экран события (EventScreen с тем же `current_event_definition`), а не на карту.

Это карри-овер замечания из SCRUM-477 (отчёт worker-2). Боевой путь и обычный
вне-боевой путь (когда события нет) трогать НЕ нужно — только когда событие активно.

## Текущее состояние в коде

Поток повышения уровня вне боя:

- `scripts/ui_screens.gd:5430` `_on_player_leveled_up()` — по сигналу `player.leveled_up`
  (`scripts/player.gd:1422`, подключён в `scripts/combat_director.gd:46-47`) ставит
  `game.level_up_return_to_map = not game.combat_active` (т.е. `true` вне боя),
  `pending_level_ups += 1`, показывает тост и обновляет кнопку «+».
- `scripts/ui_screens.gd:5438` `_open_pending_level_up()` → `push_pause("level_up")` →
  `_show_level_up_screen(game.level_up_return_to_map)`. Кнопка «+» (`LevelUpPlusButton`)
  создаётся в `_update_level_up_button()` (`scripts/ui_screens.gd:5519+`) и присутствует в т.ч.
  на экране события, потому что `_show_event_screen` вызывает `_create_menu_run_hud()`
  (`scripts/ui_screens.gd:5011`).
- `scripts/ui_screens.gd:4038` `_show_level_up_screen(return_to_map := false)`. Здесь ДВЕ точки
  возврата, обе уводят на карту, когда не в бою:
  - **Путь выбора усиления** — лямбда `button.pressed` (`:4062-4080`). После последнего пика
    (`pending_level_ups == 0`): `pop_pause("level_up")` → `game._clear_ui()` →
    `if combat_active: _create_hud()` **`elif return_to_map or not combat_active:`
    `save_run_autosave("level_up_choice")` → `game.route._show_battle_map()`** (`:4077-4079`).
  - **Путь «Позже»/Escape** — лямбда `defer_choice` (`:4096-4107`), привязана к
    `LevelUpLaterButton` и к `game.ui_escape_action`. Вне боя:
    `save_run_autosave("level_up_deferred")` → **`game.route._show_battle_map()`** (`:4106-4107`).
- `scripts/ui_screens.gd:4996` `_show_event_screen(route_node: Dictionary)` — строит экран события.
  Принимает `route_node` (использует `route_node["event_id"]` и `route_node["name"]`),
  затем `game.current_event_definition = event_definition.duplicate(true)` (`:5005`),
  именует корневой Control `"EventScreen"` (`:5009-5010`) и вызывает `_create_menu_run_hud()`.
  Важно: при отсутствии `event_id` функция КАЖДЫЙ раз заново выбирает случайное событие
  (`pick_event`, `:5001`) — поэтому повторный вход без сохранённого определения перегенерировал бы
  выборы (та же причина, по которой докачка на событии отключена, см. комментарий `:5012`).
- Узел события открывается через `scripts/route_map_screen.gd:600` `_open_route_node()` →
  `match "event": game.ui._show_event_screen(route_node)` (`:618-619`). Это ЕДИНСТВЕННЫЙ вызов
  `_show_event_screen` в проде. `route_node` нигде персистентно не хранится — есть только
  `game.current_route_choice` (имя) и `game.current_node_type` (`scripts/route_map_screen.gd:457-458`).

Состояние в `scripts/main.gd`:
- `current_event_definition := {}` (`:337`), `level_up_return_to_map := false` (`:339`),
  `pending_level_ups := 0` (`:353`), `current_route_choice := ""` (`:331`),
  `combat_active := false` (`:308`). Все три (event_def / pending / route_choice) сохраняются и
  восстанавливаются в автосейве (`:519-569`).

Ключевой факт: на момент возврата из level-up на событии `current_event_definition` НЕ пуст
(он очищается только при выборе исхода события, `:5042`/`:5065`, или старте боя из события `:5282`).
Это и есть надёжный признак «level-up открыт поверх активного события».

Ограничение: `_show_event_screen` требует `route_node`, а не голый `current_event_definition`.
Для случая с `event_id` повторный вызов детерминирован, но для процедурного (без `event_id`)
повторный вызов выбрал бы НОВОЕ событие — нельзя просто переоткрыть экран «как есть».

## Что сделать — по шагам

Подход: сохранять route_node активного события в новое поле main и при возврате из level-up,
если событие активно (`current_event_definition` не пуст), повторно показывать экран события из
сохранённого узла; иначе — прежнее поведение (карта). Чтобы повторный показ не перегенерировал
процедурное событие, `_show_event_screen` должен переиспользовать уже зафиксированный
`current_event_definition`, если он непуст и относится к тому же узлу.

1. **main.gd: новое поле.** Добавить в `scripts/main.gd` рядом с `current_event_definition`
   (`:337`) поле `var current_event_route_node := {}`. Сохранять/восстанавливать его в автосейве
   симметрично `current_event_definition` (блоки `:519-531` и `:554-569`) — иначе после
   load-mid-event возврат сломается. Сбрасывать `current_event_route_node = {}` везде, где
   чистится `current_event_definition` (см. шаг 4), чтобы не утекал stale-узел.

2. **_show_event_screen: запомнить узел и не перегенерировать активное событие.** В
   `scripts/ui_screens.gd:4996`:
   - В начале функции, ПЕРЕД выбором `event_definition`, проверить: если
     `not game.current_event_definition.is_empty()` И сохранённый
     `game.current_event_route_node == route_node` (тот же узел) — переиспользовать
     `event_definition = game.current_event_definition` (не вызывать `event_by_id`/`pick_event`
     заново, не трогать `used_event_ids`). Это гарантирует, что повторный показ того же события
     (в т.ч. процедурного без `event_id`) даёт ТЕ ЖЕ выборы.
   - В конце «свежей» ветки (после `:5005`, где присваивается `current_event_definition`)
     сохранить `game.current_event_route_node = route_node.duplicate(true)`.
   - Не менять контракт сигнатуры (всё ещё `route_node: Dictionary`); единственный продовый
     вызов из `route_map_screen.gd:619` остаётся прежним.

3. **_show_level_up_screen: ветвление возврата на активное событие.** В
   `scripts/ui_screens.gd:4038`, в ОБЕИХ точках возврата для вне-боевого случая:
   - Путь выбора усиления (`:4077-4079`): заменить безусловный `game.route._show_battle_map()`
     на: если `not game.current_event_definition.is_empty()` и
     `not game.current_event_route_node.is_empty()` →
     `_show_event_screen(game.current_event_route_node)`; иначе — прежний `_show_battle_map()`.
     `save_run_autosave("level_up_choice")` оставить перед навигацией.
   - Путь «Позже»/Escape (`defer_choice`, `:4105-4107`): аналогично — если событие активно,
     вернуть на `_show_event_screen(game.current_event_route_node)`; иначе `_show_battle_map()`.
     Автосейв-метку оставить (`"level_up_deferred"`).
   - Вынести проверку в маленький локальный хелпер/переменную, чтобы логика была одинакова в
     обоих местах (не дублировать условие с расхождениями).

4. **Сброс сохранённого узла при завершении события.** Везде, где `current_event_definition`
   очищается по завершении/выходу события, добавить `game.current_event_route_node = {}`:
   - `scripts/ui_screens.gd:5042` (выбор исхода без боя), `:5065` (кнопка «Назад»),
   - `:5282` (исход стартует бой — событие завершено),
   - и в общих сбросах забега `scripts/ui_screens.gd:320`, `:1020`, `:3736/:3754`, `:5111`, `:5135`
     (death/victory/abandon) — там, где рядом уже стоит `current_event_definition.clear()`.
   Цель: после level-up на событии возврат работает; после реального завершения события —
   stale-узел не остаётся и регрессии «вернуло на отыгранное событие» нет.

5. **Регресс-ассерт в smoke-тесте.** В `tests/runtime_smoke_test.gd` добавить проверку (по образцу
   событийного блока `:2274-2297` и level-up блока `:1004-1052`):
   - Поднять `event_main`, `_store_player_snapshot`, показать событие с `event_id`
     (`event_main.ui._show_event_screen({"name": ..., "event_id": "goblin_lottery"})`),
   - выставить `pending_level_ups = 1`, вызвать `_open_pending_level_up()`, выбрать первую
     `LevelUpRewardButton*` (`pressed.emit()`), `await process_frame`,
   - проверить, что после выбора виден `EventScreen` (`find_child("EventScreen", true, false) != null`)
     и НЕ виден корень карты маршрута; `current_event_definition` всё ещё непуст.
   - Повторить для пути «Позже» (`LevelUpLaterButton.pressed.emit()`) — тоже возврат на EventScreen.
   - Контр-проверка регрессии: при пустом `current_event_definition` level-up по-прежнему уводит на
     карту (можно опереться на существующий вне-боевой level-up блок — он не должен сломаться).
   - Если headless не маршрутизирует GUI достаточно для проверки — явно отметить это комментарием
     в тесте и оставить проверку на уровне состояния (`current_event_route_node` сохранён, ветка
     возврата выбрана), как допускает Acceptance.

## Acceptance Criteria

- [ ] Репро: на узле-события с `pending_level_ups > 0` открыть повышение и выбрать усиление —
      после выбора игрок возвращается на экран ТОГО ЖЕ события (`EventScreen`, тот же
      `current_event_definition`), а не на карту маршрута.
- [ ] То же поведение после «Позже»/Escape (`LevelUpLaterButton` / `ui_escape_action`): возврат на
      экран события, пик НЕ потрачен (`pending_level_ups` сохраняется), событие не отыграно.
- [ ] Если событие уже отыграно / `current_event_definition` пуст — поведение прежнее (возврат на
      карту маршрута). Регрессии нет.
- [ ] Боевой путь level-up (`combat_active == true`) не затронут — по-прежнему возвращает в HUD боя
      (`_create_hud()`/`_update_hud()`), карта/событие не подменяются.
- [ ] При нескольких очередях (`pending_level_ups > 1`) промежуточные пики продолжают показывать
      следующий экран level-up; на карту/событие переход только после последнего пика.
- [ ] Повторный показ события через `_show_event_screen` НЕ перегенерирует выборы: для процедурного
      события (без `event_id`) возврат показывает те же опции (через переиспользование
      `current_event_definition`), `used_event_ids` не растёт повторно.
- [ ] `current_event_route_node` сохраняется и восстанавливается в автосейве симметрично
      `current_event_definition`; после завершения/выхода события он сброшен в `{}`.
- [ ] `tests/runtime_smoke_test.gd` зелёный; добавлен регресс-ассерт на возврат к событию после
      level-up (или явно отмечено, что headless не маршрутизирует GUI, и проверка визуальная/на
      уровне состояния).

## Files / точки входа

- `scripts/main.gd` — добавить поле `current_event_route_node := {}` рядом с
  `current_event_definition` (`:337`); сериализация в автосейве (`:519-531`, `:554-569`).
- `scripts/ui_screens.gd:_show_level_up_screen` (`:4038`) — ветвление обеих точек возврата
  (выбор усиления `:4077-4079`, defer/Escape `:4105-4107`): на активном событии →
  `_show_event_screen(current_event_route_node)`, иначе `_show_battle_map()`.
- `scripts/ui_screens.gd:_show_event_screen` (`:4996`) — переиспользовать существующий
  `current_event_definition` для того же узла; сохранять `current_event_route_node` (после `:5005`).
- `scripts/ui_screens.gd` — добавить сброс `current_event_route_node = {}` рядом с каждым
  `current_event_definition.clear()` (`:320`, `:1020`, `:3736`, `:3754`, `:5042`, `:5065`, `:5111`,
  `:5135`, `:5282`).
- `scripts/route_map_screen.gd:_open_route_node` (`:618-619`) — единственный продовый вызов
  `_show_event_screen`; сигнатуру не меняем, правок не требует (только для понимания контекста).
- `tests/runtime_smoke_test.gd` — регресс-ассерт (образцы: событие `:2274-2297`, level-up
  `:1004-1052`, EventScreen-чек `:1925`).

## Замечания / подводные камни

- **Anti-collision / locked paths:** основная правка — `scripts/ui_screens.gd` (LOCKED-путь,
  держать за контуром claude, не параллелить с другими правками ui_screens.gd). Затрагивается
  `scripts/main.gd` (общий — координировать, добавлять только новое поле + сериализацию, не трогать
  чужие хунки). `scripts/progression_data.gd` НЕ трогать. `scripts/route_map_screen.gd` менять не
  нужно.
- **Почему не хватает только `current_event_definition`:** `_show_event_screen` требует `route_node`
  (для `event_id`/`name`), которого в `current_event_definition` нет. Отсюда новое поле
  `current_event_route_node`. Голый `current_event_definition` без guard на тот же узел привёл бы к
  перегенерации процедурного события — это баг, его нужно избежать (шаг 2).
- **Edge-case — load mid-event + pending level-up:** если поле не сериализовать, после загрузки
  сохранения возврат сломается (узел `{}` → уйдёт на карту). Поэтому сериализация обязательна.
- **Edge-case — событие стартует бой** (`_apply_event_choice` вернул `true`, `:5278-5285`):
  `current_event_definition` чистится, `current_event_route_node` тоже должен сброситься, чтобы
  последующий боевой level-up не пытался вернуть на исчезнувшее событие.
- **Edge-case — `level_up_return_to_map`:** оно ставится `true` вне боя в `_on_player_leveled_up`
  (`:5432`) и сбрасывается в `false` в путях возврата (`:4071`, `:4098`). Эту переменную НЕ
  переиспользовать как «есть событие» — она про «не в бою», а не про «поверх события». Признак
  активного события — именно непустой `current_event_definition` (+ непустой
  `current_event_route_node`).
- **Pause-стек:** не нарушать парность `push_pause("level_up")`/`pop_pause("level_up")` — `pop` уже
  стоит в обоих путях до навигации, навигацию вставлять ПОСЛЕ `_clear_ui()`, как сейчас.
- **Связанные тикеты:** карри-овер из SCRUM-477 (метка `SCRUM-477`, эпик SCRUM-213). Не пересекается
  с балансом событий (SCRUM-501/SCRUM-508) — это чисто навигационный UX-фикс.
- **Headless-оговорка:** smoke-тест в headless может не полностью маршрутизировать GUI-переходы;
  Acceptance это допускает — тогда проверять на уровне состояния (выбранная ветка возврата /
  сохранённый `current_event_route_node` / наличие узла `EventScreen` в дереве) и пометить
  комментарием.
