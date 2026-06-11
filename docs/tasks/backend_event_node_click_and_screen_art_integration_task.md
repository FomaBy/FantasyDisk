# Задача Для Back-end-Агента: Починить Вход В Event Node И Интегрировать Картинки Экранов

Дата: 2026-06-10

Статус: done 2026-06-11. Результат: event/question node кликается на full-screen route map после scroll/drag, hover tooltip и hit areas работают, event screen открывается и после выбора возвращает маршрут к следующему ряду; event/shop/campfire screens используют полноэкранные background PNG через `SCREEN_BACKGROUND_PATHS`. Runtime smoke test покрывает route event click, backgrounds и non-combat flow, проходит.

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: исправь баг, интегрируй ассеты, обнови тесты и документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Проблема

На маршрутной карте не получается зайти в узел с вопросиком. Это event node, и он должен быть доступен так же, как бой, магазин, костер и босс, если маршрут позволяет выбрать этот узел.

Дополнительно после работы Design-агента нужно интегрировать новые фоновые картинки для:

- события / question mark event;
- магазина;
- костра / отдыха.

## Связанная Design-задача

```text
docs/tasks/design_event_shop_campfire_backgrounds_style_unification_task.md
```

Если дизайн-ассеты уже готовы, подключить их. Если еще не готовы, сначала починить event node click/entry и подготовить понятные placeholder hooks/mapping для будущей интеграции.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/tasks/backend_route_map_start_selection_scroll_task.md`

## Требования К Event Node / Question Mark

Починить поведение question mark узла на маршрутной карте.

Ожидаемое поведение:

1. Игрок видит event node с вопросиком на route map.
2. Если event node находится в доступном ряду/пути, он визуально подсвечен как доступный.
3. Наведение показывает tooltip события.
4. Клик по узлу открывает event screen.
5. После выбора варианта события игра корректно возвращает игрока на маршрутную карту и открывает следующий ряд.

Проверить:

- node type `event`;
- route node availability/locked state;
- генерацию route connections;
- hit area question mark node;
- mouse filter / z-index / overlay interception;
- обработчик клика route node;
- `_open_route_node` или аналогичную функцию;
- переход в event screen;
- возврат из event screen на route map;
- smoke tests для event node.

## Требования К Full-screen Route Map

Учесть текущие требования к карте:

- route map должна быть во весь экран, не в маленькой рамке;
- узлы должны быть кликабельными после scroll/drag;
- drag/pan не должен случайно выбирать узел;
- event node не должен быть перекрыт линиями, tooltip, HUD или scroll layer;
- вопросик должен иметь достаточно большую click area.

## Интеграция Фонов Для Event / Shop / Campfire

Когда Design-агент подготовит ассеты, подключить их в соответствующие экраны:

| Экран | Ожидаемый asset ID | Назначение |
| --- | --- | --- |
| Event | `screen_event_background` | Фон события / вопросика |
| Shop | `screen_shop_background` | Фон магазина |
| Campfire / Rest | `screen_campfire_background` | Фон костра / отдыха |

Требования:

- фоны должны отображаться на соответствующих экранах;
- не растягивать некрасиво, использовать правильный scale/crop;
- текст и кнопки должны оставаться читаемыми;
- фон не должен перекрывать HUD HP/XP/money;
- экраны должны выглядеть в стиле игры, не как default UI;
- не использовать runtime-подгрузку при каждом открытии, если можно preload/scene reference.

## Убрать Визуальный Разнобой

Если в event/shop/rest UI есть старые панели, цвета или элементы, которые выбиваются из нового стиля:

- заменить на новые assets/styles от Design;
- убрать default Godot look там, где он заметен;
- сохранить читаемость и кликабельность;
- не ломать keyboard/mouse input.

## Файлы Для Проверки

Обязательно проверить:

- `scripts/main.gd`
- route map rendering/click code
- event screen code
- shop screen code
- rest/campfire screen code
- `scenes/Main.tscn`
- `tests/runtime_smoke_test.gd`

Если UI вынесен в отдельные сцены/скрипты, проверить и их.

## Acceptance Criteria

Задача готова, если:

- event/question mark node кликается, когда он доступен;
- hover tooltip на event node работает;
- клик по event node открывает event screen;
- выбор event option корректно продолжает маршрут;
- route map остается full-screen и удобной;
- scroll/drag карты не ломает клики event node;
- event, shop и campfire/rest экраны используют новые фоновые картинки, если assets готовы;
- старый default/placeholder вид этих экранов убран или существенно уменьшен;
- runtime smoke test обновлен и проходит;
- документация обновлена.

## Проверка

Запустить:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Ручная проверка:

- начать новый забег;
- открыть route map;
- найти question mark event node;
- проверить hover;
- кликнуть event node;
- выбрать event option;
- вернуться на карту;
- открыть shop node;
- открыть campfire/rest node;
- проверить `1600x900`;
- проверить `2560x1440`.

## Документация

После реализации обновить:

- `docs/design/current_game_state.md` - event node behavior и screen backgrounds;
- `docs/design/fantasydisk_design_brief.md` - если изменился UX route map или non-combat screens;
- `docs/design/content_registry.md` - добавить/обновить IDs фоновых экранов и активные assets.

Не оставлять исправление только в коде.
