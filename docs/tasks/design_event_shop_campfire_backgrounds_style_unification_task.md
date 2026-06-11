# Задача Для Design-Агента: Фоны Event/Shop/Campfire И Единый Стиль Игровых Элементов

Статус: done
Дата: 2026-06-10

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: нарисуй ассеты, замени/подготовь игровые элементы, обнови документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

Пользователь хочет, чтобы все игровые элементы выглядели в едином стиле с персонажами и монстрами. Сейчас часть UI и игровых объектов выглядит разрозненно или слишком placeholder.

Нужно нарисовать красивые фоновые картинки для:

- события / question mark event;
- магазина;
- костра / отдыха.

Также нужно пересмотреть все игровые элементы и привести их к стилистике текущих персонажей и монстров.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/tasks/design_cartoon_character_style_fix_task.md`
- `docs/tasks/design_stat_icons_hud_visual_task.md`

## Главная Цель

Сделать визуальный слой FantasyDisk цельным:

- event/shop/campfire screens должны иметь красивые фоновые картинки;
- UI и игровые элементы должны выглядеть в одном стиле с персонажами и монстрами;
- убрать ощущение default Godot / placeholder;
- сохранить читаемость и удобство gameplay;
- подготовить assets так, чтобы Back-end мог быстро подключить их.

## Фоны Для Небоевых Экранов

### Event Background

Asset ID:

```text
screen_event_background
```

Файл:

```text
assets/sprites/ui/screens/screen_event_background.png
```

Визуальная идея:

- загадочное место/сцена выбора;
- подходит для question mark route node;
- ощущение неизвестного события, риска и награды;
- fantasy cartoon style;
- не слишком темно, чтобы текст был читаемым.

### Shop Background

Asset ID:

```text
screen_shop_background
```

Файл:

```text
assets/sprites/ui/screens/screen_shop_background.png
```

Визуальная идея:

- лавка/торговец/прилавок/магические предметы;
- ощущение безопасного места между боями;
- хорошо работает как фон за карточками предметов;
- стиль игры, не generic fantasy stock.

### Campfire / Rest Background

Asset ID:

```text
screen_campfire_background
```

Файл:

```text
assets/sprites/ui/screens/screen_campfire_background.png
```

Визуальная идея:

- костер, отдых, тепло, передышка;
- должен сразу считываться как rest node;
- уютный, но в мире FantasyDisk;
- персонаж/силуэты/предметы допустимы, если не мешают UI.

## Технические Требования К Фонам

- PNG.
- 16:9.
- Рекомендуемый размер: `2560x1440` или минимум `1920x1080`.
- Должны красиво скейлиться на `1600x900` и `2560x1440`.
- Оставить визуально спокойные зоны под текст и кнопки.
- Не использовать текст внутри картинки.
- Не делать фон слишком шумным.
- Не копировать чужие ассеты.

## Пересмотреть Все Игровые Элементы

Провести визуальный аудит и подготовить замену/улучшение для элементов, которые выбиваются из стиля персонажей и монстров.

Проверить:

- route map icons;
- route map nodes;
- линии между узлами карты;
- event/shop/rest screens;
- reward cards;
- level-up UI;
- pause stats UI;
- HUD HP/XP/money;
- pickup sprites;
- projectile sprites;
- AoE/VFX shapes;
- boss/elite warning zones;
- shop item cards;
- buttons/panels/tooltips;
- death/victory screens;
- any default-looking UI controls.

## Приоритеты

1. Event/shop/campfire backgrounds.
2. UI elements that are visible every run.
3. Route map visual clarity.
4. HUD and stat/reward icons alignment.
5. Pickups/projectiles/VFX style alignment.
6. Victory/death/secondary screens.

## Style Direction

Стиль:

- stylized cartoon fantasy;
- красивый, живой, цельный;
- соответствует персонажам и монстрам;
- не слишком упрощенный;
- не square/blocky;
- не default UI;
- четкие силуэты и понятная функциональность.

Нельзя:

- generic emoji;
- default Godot controls without styling;
- assets that look like they came from a different game;
- overly noisy backgrounds;
- random mixed styles;
- placeholder shapes unless explicitly temporary and documented.

## Asset Registry

Добавить новые assets в `docs/design/content_registry.md`.

Минимально:

| ID | Игровое имя | Asset |
| --- | --- | --- |
| `screen_event_background` | Фон события | `assets/sprites/ui/screens/screen_event_background.png` |
| `screen_shop_background` | Фон магазина | `assets/sprites/ui/screens/screen_shop_background.png` |
| `screen_campfire_background` | Фон костра | `assets/sprites/ui/screens/screen_campfire_background.png` |

Если добавляешь новые иконки, панели, frames, buttons, VFX или pickups, тоже добавить их в registry.

## Deliverables

Сдать:

- 3 фоновых картинки;
- список игровых элементов, которые были пересмотрены;
- новые/обновленные assets для элементов, которые выбивались из стиля;
- обновленную документацию;
- краткий handoff для Back-end: какие файлы подключать и где.

## Acceptance Criteria

Задача готова, если:

- есть красивый фон для event screen;
- есть красивый фон для shop screen;
- есть красивый фон для campfire/rest screen;
- фоны в стиле FantasyDisk и подходят персонажам/монстрам;
- фоны не мешают читаемости UI;
- проведен аудит всех игровых элементов;
- элементы, которые сильно выбивались из стиля, заменены или отмечены как требующие backend integration;
- `content_registry.md` обновлен;
- `current_game_state.md` обновлен;
- Back-end получил понятный список файлов для интеграции.

## Документация

После реализации обновить:

- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`.

Если какой-то элемент пока оставлен старым, явно написать почему и что с ним делать позже.

## Результат (2026-06-11, Design)

- Подготовлены и подключены к документации 3 небоевых фона в 2560x1440: `assets/sprites/ui/screens/screen_event_background.png`, `assets/sprites/ui/screens/screen_shop_background.png`, `assets/sprites/ui/screens/screen_campfire_background.png`. Все три файла проверены `sips`: 2560x1440.
- Визуальный аудит игровых элементов зафиксирован в `docs/design/current_game_state.md` и `docs/design/content_registry.md`: route map icons/nodes, HUD, stat icons, pickups, projectiles, VFX, reward/level-up, pause stats, shop и базовые UI controls приведены к единому FantasyDisk fantasy style или имеют backend hooks для подключения.
- Активные visible placeholder-слои для pickups/projectiles заменены PNG-ассетами: `hud_xp.png`, `hud_money.png`, `player_projectile_spark_64.png`, `enemy_projectile_magic_64.png`.
- Back-end интеграционные пути: `scripts/main.gd::SCREEN_BACKGROUNDS`, `scripts/ui_screens.gd`, `scripts/ui_icon_registry.gd`; отдельного нового Design-handoff не требуется, потому что пути уже задокументированы и подключены.
