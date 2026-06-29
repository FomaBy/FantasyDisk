# SCRUM-529: Пройденный магазин помечать галочкой на карте (с возвратом)

Jira: SCRUM-529 · Роль: backend · Контур: codex · Приоритет: P2 · foma · Эпик: SCRUM-522 (Ребаланс боёвки и прогрессии)
Статус: done (QA PASSED -> Готово)

Owner: backend/codex-background-backend-agent
Locked paths: `scripts/main.gd`, `scripts/route_map_screen.gd`, `docs/design/systems/route_map.md`, `docs/tasks/SCRUM-529_shop_node_completed_mark_with_return.md`

## Что и зачем

В роге-лайт забеге карта маршрута (`Карта маршрута`, экран `RouteMapScreen`) — это вертикальный
граф узлов (бой/элитка/магазин/событие/костёр/босс). Пройденные узлы помечаются жёлтой
галочкой «✓» и подсвечиваются как «completed», чтобы игрок видел свой путь.

Магазин — особый узел: его уже можно посетить, выйти и **вернуться обратно** (механика
re-entry уже реализована и покрыта тестом, см. ниже). Но визуально после выхода магазин
показывается как обычный «доступный» узел (золотая рамка, без галочки) — игрок не понимает,
что он там уже был, что купил, и почему этот узел снова «активен». Это путает: выглядит так,
будто магазин не пройден.

Цель (с точки зрения игрока): после выхода из магазина его узел на карте должен **нести
галочку «✓» / отметку «пройдено»** (как у боевых узлов), но при этом **оставаться кликабельным
для возврата** в тот же магазин (тот же сток, те же купленные предметы). То есть нужен новый
визуальный режим узла: «пройдено, но ещё можно вернуться» — combined completed + returnable.

Ожидаемый результат:
- Узел магазина после выхода визуально помечен как пройденный (галочка ✓ + completed-стиль).
- Этот же узел остаётся кликабельным и повторный клик снова открывает тот же магазин (re-entry).
- После выбора следующего узла магазин финализируется и переходит в обычный неактивный
  «completed/locked» режим (как сейчас).
- `runtime_smoke` зелёный (существующий `_test_shop_reentry_until_next_level` не сломан, дополнен
  проверкой галочки).

## Текущее состояние в коде

Вся логика карты и re-entry магазина живёт в **`scripts/route_map_screen.gd`** (класс `RefCounted`,
держит ссылку `game` на `main.gd`). Состояние re-entry — поля в **`scripts/main.gd`**.

### Поля состояния (scripts/main.gd)
- `:349 current_shop_node_key := ""` — ключ узла магазина (стейдж:тип:имя), чтобы сток/покупки
  привязывались к конкретному магазину.
- `:350 shop_reentry_pending := false` — флаг «вышли из магазина, но ещё не пошли дальше».
- `:351 shop_reentry_route_stage := -1` — стейдж (ряд) магазина, в который можно вернуться.
- `:352 shop_reentry_branch_index := -1` — ветка (колонка) этого магазина.
- Все четыре поля сериализуются в автосейв (`save_run_autosave`): `main.gd:533-538`, и
  восстанавливаются: `main.gd:572-577`. Сброс при новой игре: `ui_screens.gd:322-325` (главное меню),
  `ui_screens.gd:1022-1024` (выбор героя).

### Как магазин открывается и закрывается
- `route_map_screen.gd:600 _open_route_node()` — для `node_type == "shop"` строит/чистит сток по
  `shop_node_key` и вызывает `game.ui._show_shop_screen()` (`:613-615`).
- `scripts/ui_screens.gd:4480 _show_shop_screen()` — рисует магазин; кнопка «Назад» (`ShopLeaveButton`,
  `:4562-4578`) и Escape вызывают `leave_shop`, который зовёт
  **`game.route._return_to_map_after_shop_visit()`** (`ui_screens.gd:4574-4577`).
  ВАЖНО: магазин выходит НЕ через `_advance_route_after_noncombat()` (как костёр/событие/апгрейд),
  а через специальный путь, который НЕ инкрементит `route_stage`.

### Механика re-entry (route_map_screen.gd) — УЖЕ РАБОТАЕТ
- `:636 _return_to_map_after_shop_visit()` — выставляет `shop_reentry_pending=true`,
  `shop_reentry_route_stage = route_stage`, `shop_reentry_branch_index = выбранная ветка этого ряда`,
  сохраняет автосейв (`"shop_visit"`) и заново рисует карту `_show_battle_map()`. **`route_stage`
  не меняется.**
- `:453 _activate_route_node()` — при клике по узлу СЛЕДУЮЩЕГО ряда (`step_index ==
  shop_reentry_route_stage + 1`) вызывает `_finalize_pending_shop_reentry()` и `route_stage =
  step_index`, после чего открывает узел.
- `:629 _advance_route_after_noncombat()` — тоже вызывает `_finalize_pending_shop_reentry()` перед
  `route_stage += 1` (общий путь для costра/события/апгрейда).
- `:647 _finalize_pending_shop_reentry()` — чистит сток магазина и сбрасывает все 4 поля re-entry.

### Откуда берётся «available»-режим магазина в pending (КОРЕНЬ ЗАДАЧИ)
- `:530 _route_node_state(step_index, branch_index) -> String` — возвращает одно из
  `"available" | "completed" | "locked"`.
  - Когда `shop_reentry_pending == true` (ветка `:533-549`):
    - узлы рядов `< shop_step` → `"completed"` если это выбранная ветка, иначе `"locked"`;
    - сам магазин (`step == shop_step && branch == shop_branch && type=="shop"`) → **`"available"`**
      (`:540-544`) — вот почему он БЕЗ галочки, с золотой «активной» рамкой;
    - связанные узлы ряда `shop_step+1` → `"available"` (можно идти дальше), остальные `"locked"`.
- `:397 _draw_route_nodes()` рисует узлы:
  - `:411 button.disabled = state != "available"` — кликабельность ЖЁСТКО привязана к
    `state == "available"`. completed/locked = `disabled = true`.
  - `:416-417` если `state == "completed"` → `_add_route_node_completed_mark(button)` (рисует «✓»).
  - `:420-423` обработчик клика (`gui_input`) вешается ТОЛЬКО если `state == "available"`.
- `:491 _add_route_node_completed_mark()` — добавляет `Label` `RouteNodeCompletedMark` с текстом `"✓"`,
  жёлтый, в правом-верхнем углу узла.
- `:658 _style_route_node_button()` — стилизация по `state`: для `"completed"` — приглушённый фон +
  золотая рамка (`:665-667`); для `"available"` — осветлённый фон + яркая жёлтая рамка (`:668-670`).

### Суть проблемы
Сейчас режимы `"completed"` (галочка + не кликабелен) и `"available"` (кликабелен + без галочки)
**взаимоисключающие**. Магазину в pending нужен ГИБРИД: галочка ✓ И completed-стиль И кликабельность
(чтобы вернуться). Сейчас такого режима нет — отсюда отсутствие галочки на пройденном магазине.

### Иконка/тултип магазина (для контекста, менять не нужно)
- `main.gd:135-142 MAP_NODE_DEFINITIONS["shop"]` — name `"Магазин"`, icon_path
  `map_shop_tent.png`, зелёная рамка `Color(0.42,0.86,0.48,1)`, tooltip «Магазин\nПотрать деньги…».

### Существующий тест (acceptance-якорь)
- `tests/runtime_smoke_test.gd:1957 _test_shop_reentry_until_next_level()` — поднимает забег с
  маршрутом `shop(0) -> battle(1) -> boss(2)`, кликает магазин, покупает предмет, жмёт `ShopLeaveButton`,
  проверяет: `route_stage` остался 0, `shop_reentry_pending == true`, и магазин (`RouteNode_shop_0_0`) И
  следующий бой (`RouteNode_battle_1_0`) — **оба кликабельны** (`:2037-2042`); повторный клик по
  магазину снова открывает тот же сток/ключ/покупки (`:2049-2072`); выбор боя ряда 1 финализирует
  re-entry, `route_stage==1`, `shop_reentry_pending==false`, сток очищен (`:2083-2098`).
  Вызывается из основного прогона `:252 await _test_shop_reentry_until_next_level(main_scene)`.

## Что сделать — по шагам

Менять только **`scripts/route_map_screen.gd`** (+ дополнить тест). `main.gd` трогать не нужно — поля
re-entry уже есть. `ui_screens.gd` НЕ трогать (locked path; выход из магазина уже идёт по нужному
пути `_return_to_map_after_shop_visit`).

1. **Ввести гибридный режим «пройдено, но возвращаемо» в `_route_node_state()`**
   (`route_map_screen.gd:540-544`). Для магазина в pending вместо `"available"` возвращать новый
   маркер, напр. `"shop_revisit"` (или `"completed_returnable"`). Семантика: completed-вид + клик.
   - Альтернатива без нового стейта (если так проще ниже по коду): оставить `"available"`, но в
     `_draw_route_nodes` дополнительно проверять `game.shop_reentry_pending && это тот самый магазин`
     и в этом случае дорисовывать галочку + completed-стиль. Выбрать ОДИН подход и провести его
     консистентно через state/draw/style — не плодить рассинхрон.

2. **Кликабельность + галочка в `_draw_route_nodes()`** (`:411-423`):
   - `button.disabled` должен быть `false` для нового режима (узел остаётся кликабельным).
     Рекомендуется завести локальную `var is_clickable := state == "available" or state ==
     "shop_revisit"` и использовать её и для `button.disabled = not is_clickable`, и для навешивания
     `gui_input` обработчика (`:420-423`), и для `z_index` (`:413` — пройденно-возвращаемый можно
     держать на `20`, как активный, чтобы попадал в клик поверх линий).
   - Для нового режима ВЫЗВАТЬ `_add_route_node_completed_mark(button)` (как для `"completed"`,
     `:416-417`), чтобы появилась «✓».

3. **Стиль в `_style_route_node_button()`** (`:658-678`): для нового режима применить completed-вид
   (приглушённый фон + золотая рамка, как `:665-667`), но допускается слегка ярче, чтобы читалось
   «можно вернуться» (например, рамка как у completed, фон чуть светлее). Главное — узел НЕ должен
   выглядеть как «никогда не посещён».

4. **Не сломать обработчик клика и финализацию.** Клик по магазину в режиме `shop_revisit` идёт через
   тот же `_handle_route_node_input` → `_activate_route_node`. Проверить, что повторный клик именно
   по магазину (`step == shop_reentry_route_stage`, НЕ `+1`) НЕ триггерит финализацию (условие
   `:454 step_index == shop_reentry_route_stage + 1` должно остаться истинным только для следующего
   ряда) и просто переоткрывает магазин через `_open_route_node` (сток сохраняется по
   `current_shop_node_key`, см. `:602-608`). Поведение перехода «дальше» (ряд +1 финализирует) НЕ
   менять.

5. **(Опционально, аккуратно) Подпись.** Можно к тултипу/подписи пройденного-возвращаемого магазина
   добавить намёк «(посещено — можно вернуться)». Не обязательно; если делать — только через
   `tooltip_text`, без новых ассетов и без изменения общей логики.

6. **Дополнить тест** `tests/runtime_smoke_test.gd:_test_shop_reentry_until_next_level`: после выхода
   из магазина (после `:2036`, где уже проверяется возврат на карту) и до повторного входа добавить
   ассерт, что у узла `RouteNode_shop_0_0` присутствует дочерний `RouteNodeCompletedMark`
   (`button.find_child("RouteNodeCompletedMark", true, false) != null`) И при этом
   `shop_button.disabled == false`. Это закрепит «галочка + кликабелен». После финализации (ряд 1,
   `:2087`) дополнительный ассерт не обязателен — магазин уходит в обычный completed/locked.

## Acceptance Criteria

- [ ] Узел магазина после выхода из него помечен пройденным — на нём видна галочка «✓»
      (`RouteNodeCompletedMark`) и completed-стиль рамки/фона, а не вид «никогда не посещён».
- [ ] Этот же узел магазина остаётся кликабельным (`disabled == false`) и повторный клик снова
      открывает ТОТ ЖЕ магазин: тот же `current_shop_node_key`, тот же сток `current_shop_items`,
      сохранённые `current_shop_purchased` (купленное не перепокупается).
- [ ] Узлы следующего ряда (`shop_reentry_route_stage + 1`), связанные с магазином, остаются
      доступными — игрок не заперт.
- [ ] При выборе следующего узла re-entry финализируется: `_finalize_pending_shop_reentry()` чистит
      сток и поля, `route_stage` увеличивается, магазин уходит в обычный completed/locked режим
      (галочка остаётся как у любого пройденного узла, но клик-возврат больше недоступен).
- [ ] Изменения изолированы в `scripts/route_map_screen.gd` (+ тест); `main.gd`/`ui_screens.gd` не
      затронуты.
- [ ] `tests/runtime_smoke_test.gd` дополнен ассертом галочки и проходит:
      `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_test.gd` — зелёный.

## Результат

2026-06-27, backend/codex-background-backend-agent:

- В `scripts/route_map_screen.gd` добавлен гибридный state `shop_revisit`: текущий магазин после выхода из shop получает completed-галочку/стиль, но остается кликабельным через существующий route-node input path.
- Re-entry/finalization logic не менялась: повторный вход в тот же shop не финализирует re-entry, а выбор следующего ряда по-прежнему вызывает `_finalize_pending_shop_reentry()`.
- `docs/design/systems/route_map.md` обновлён: visited shop отображается как completed, но остается returnable до выбора следующего route node.
- Проверка: focused Godot check `/tmp/scrum529_route_shop_check.gd` PASS — `RouteNode_shop_0_0` имеет `RouteNodeCompletedMark`, `disabled == false`, tooltip visited-return, следующий узел доступен.
- Umbrella runtime smoke был запущен без правок `tests/runtime_smoke_test.gd`, но остановился на unrelated arena/player-start assertion при наличии чужих dirty gameplay files (`scripts/player.gd` и соседние balance/combat files). SCRUM-529 route-map code скомпилировался до этой проверки.

## Files / точки входа

- `scripts/route_map_screen.gd:530 _route_node_state()` — добавить гибридный режим для магазина в
  pending (новый маркер вместо/в дополнение к `"available"`).
- `scripts/route_map_screen.gd:397 _draw_route_nodes()` — для нового режима: `disabled=false`,
  навесить `gui_input`, вызвать `_add_route_node_completed_mark()` (галочка), корректный `z_index`.
- `scripts/route_map_screen.gd:658 _style_route_node_button()` — completed-стиль для нового режима.
- `scripts/route_map_screen.gd:491 _add_route_node_completed_mark()` — переиспользовать как есть
  (можно не менять).
- `scripts/route_map_screen.gd:453 _activate_route_node()` / `:647 _finalize_pending_shop_reentry()` —
  поведение НЕ менять, только убедиться, что повторный клик по магазину не финализирует.
- `tests/runtime_smoke_test.gd:1957 _test_shop_reentry_until_next_level()` — добавить ассерт
  `RouteNodeCompletedMark` + `disabled==false` на пройденном магазине.

## Замечания / подводные камни

- **Anti-collision / locked paths:** НЕ трогать `scripts/ui_screens.gd` и `scripts/progression_data.gd`
  (locked). Вся правка — в `scripts/route_map_screen.gd` (изолирован, низкий риск коллизий). Выход из
  магазина уже корректно идёт через `_return_to_map_after_shop_visit`, ничего в `ui_screens.gd` менять
  не требуется.
- **Re-entry уже существует и покрыт тестом** — задача в первую очередь ВИЗУАЛЬНАЯ (галочка +
  completed-стиль на возвращаемом магазине). НЕ переписывать механику re-entry с нуля; не ломать
  существующие ассерты `_test_shop_reentry_until_next_level` (оба узла кликабельны, сток/покупки
  персистят, финализация по ряду +1).
- **Жёсткая связка `disabled = state != "available"`** (`:411`) — главный камень: если просто пометить
  магазин как `"completed"`, он перестанет быть кликабельным и сломается возврат (и тест). Поэтому
  нужен именно гибрид (кликабельный + с галочкой), а не переключение на существующий `"completed"`.
- **`z_index` и пан-клик:** клики по узлам идут через `_handle_route_node_input` с детекцией драга
  (пан карты). Возвращаемый магазин должен сохранять `z_index` активного уровня (`20`), иначе линии/
  соседи могут перехватывать клик. Сверить с `:413`.
- **Галочка-маркер на «обычных» completed узлах** уже работает (боевые узлы прошлых рядов в pending
  получают `"completed"` + ✓) — новый режим должен выглядеть консистентно с ними по галочке.
- **Автосейв/перезагрузка:** поля re-entry уже сериализуются (`main.gd:533-538`/`:572-577`), так что
  после reload карта восстановит pending-состояние; галочка отрисуется автоматически, если логика
  состояния опирается на `shop_reentry_*` (а не на эфемерный флаг). Не вводить отдельное несохраняемое
  состояние.
- **Связанные тикеты:** SCRUM-529 — часть эпика SCRUM-522 (пункт «Магазин помечается пройденным»).
  Соседние пункты эпика (типы урона, изоляция атрибутов, XP-кривая, награда элитки, баг выбора на
  эвентах) — отдельные тикеты, не входят в скоуп этой задачи.
