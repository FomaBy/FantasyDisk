# Задача Для Back-end-Агента: Интегрировать Иконки Статов, Новый HUD И Убрать Ямы/Колонны

Дата: 2026-06-10

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: интегрируй ассеты, обнови UI, убери лишнюю информацию, удали ямы/колонны из игры, обнови тесты и документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Dependency

Эта задача выполняется после или параллельно с design task:

```text
docs/tasks/design_stat_icons_hud_visual_task.md
```

Если дизайн-ассеты уже готовы, использовать их. Если агент начал раньше дизайнера и ассетов еще нет, подготовить интеграционный слой, mapping и UI-структуру, но финальную сдачу сделать после подключения реальных ассетов.

## Контекст

Нужно применить новый UI-дизайн в игре:

- использовать иконки для всех характеристик и атрибутов там, где они появляются;
- обновить Escape stats menu;
- обновить level-up UI;
- сделать боевой HUD красивым и минимальным;
- убрать лишнюю информацию на экране во время боя;
- удалить ямы и колонны из игры и документации, потому что текущая реализация выглядит плохо и пока не нужна.

## Главная Цель

После задачи:

- в игре есть красивый HUD только с HP, XP и деньгами;
- все характеристики и атрибуты в UI имеют иконки;
- Escape menu остается подробным, но становится визуально красивее;
- level-up rewards показывают релевантные stat/attribute icons;
- боевой экран не перегружен текстом;
- ямы и колонны больше не генерируются;
- документация не обещает ямы и колонны как текущую фичу.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/design/mechanics_extract.md`
- `docs/tasks/design_stat_icons_hud_visual_task.md`

## UI Icons Mapping

Создать централизованный mapping для UI icons:

- базовые характеристики:
  - `strength`
  - `agility`
  - `intelligence`
  - `perception`
  - `energy`
  - `knowledge`
  - `endurance`
  - `leadership`
- производные атрибуты:
  - `damage`
  - `magic_damage`
  - `sound_wave_damage`
  - `attack_speed`
  - `crit_chance`
  - `crit_damage_multiplier`
  - `move_speed`
  - `dodge`
  - `defense`
  - `health_point`
  - `attack_range`
  - `aoe_radius`
  - `pickup_radius`
  - `dot_damage`
  - `dot_speed`
  - `projectile_speed`
  - `aura_radius`
  - `buff_power`
  - `knockback_power`
  - `summon_amount`
- HUD:
  - `hp`
  - `xp`
  - `money`

Не размазывать пути по UI-коду. Сделать понятный helper или data dictionary, чтобы новые UI screens могли брать иконку по ID.

## Escape Stats Menu

При нажатии Escape:

- игра ставится на паузу как раньше;
- справа показываются характеристики и атрибуты;
- у каждой строки должна быть иконка;
- hover tooltip с описанием и формулой остается;
- размер текста должен оставаться крупным и читаемым;
- иконки не должны ломать layout;
- цветовая подсветка high/low/effective остается или улучшается.

## Level-up UI

При получении уровня:

- игра полностью ставится на паузу;
- в reward cards/choices показывать иконку соответствующей характеристики, атрибута или артефакта;
- если reward влияет на несколько параметров, выбрать главную иконку или показать компактную группу;
- не использовать emoji/default placeholders;
- level-up UI должен выглядеть в стиле FantasyDisk.

## In-game HUD

Во время активного боя на экране показывать только:

- HP;
- XP;
- деньги.

Убрать лишнюю информацию из боевого HUD:

- не показывать весь список характеристик;
- не показывать debug-like stat text;
- не перегружать экран цифрами;
- route/stage/timer оставить только если это критично для gameplay, но визуально вторично и аккуратно. Если есть сомнение, убрать лишнее и оставить только HP/XP/money по требованию пользователя.

HUD должен:

- использовать новые красивые иконки;
- быть читаемым на `1600x900` и `2560x1440`;
- не перекрывать бой;
- сохраняться на карте/ивентах/магазине, если эти состояния требуют HP/XP/money по текущему дизайну.

## Убрать Ямы И Колонны Из Игры

Текущие ямы и колонны пользователю не нравятся. Нужно убрать их из игры на текущем этапе.

Сделать:

- отключить генерацию колонн;
- отключить генерацию ям;
- убрать collision obstacles, связанные с ними;
- убрать pit collision logic, если она больше нигде не нужна;
- проверить, что flying enemies не ломаются без ям;
- удалить или деактивировать тесты, которые требуют ямы/колонны;
- не оставлять невидимые блокеры на карте;
- убедиться, что спавн и pathing врагов работают без obstacle avoidance.

Не обязательно удалять ассет-файлы физически, если они могут понадобиться позже, но активная игра и документация не должны считать ямы/колонны текущей фичей.

## Убрать Ямы И Колонны Из Документации

Обновить документацию:

- `docs/design/current_game_state.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/content_registry.md`
- `docs/design/mechanics_extract.md`, если там упоминается текущая механика препятствий

Формулировка: ямы и колонны убраны/отключены из текущей версии, могут вернуться позже после редизайна препятствий.

## Файлы Для Проверки

Обязательно проверить:

- `scripts/main.gd`
- `scripts/pause_stats_menu.gd`
- `scripts/stat_formulas.gd`
- `scripts/progression_data.gd`
- `scripts/player.gd`
- `scripts/enemy.gd`
- `scripts/enemy_projectile.gd`
- `scenes/Main.tscn`
- `scenes/PauseStatsMenu.tscn`
- `tests/runtime_smoke_test.gd`
- `tests/animation_smoke_test.gd`, если ожидания связаны с препятствиями или UI assets

## Acceptance Criteria

Задача готова, если:

- все базовые характеристики в Escape UI имеют иконки;
- все производные атрибуты в Escape UI имеют иконки;
- level-up rewards используют релевантные иконки;
- in-game HUD красивый и показывает только HP, XP, деньги;
- лишний stat/debug text убран с боевого экрана;
- ямы и колонны не появляются в игре;
- нет невидимых collision blockers от старых препятствий;
- враги и игрок нормально двигаются без obstacles;
- тесты обновлены и проходят;
- документация обновлена и не описывает ямы/колонны как активную фичу.

## Проверка

Запустить:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Если менялись сцены/визуальные ожидания:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Ручная проверка:

- начать бой;
- проверить HUD HP/XP/money;
- нажать Escape и проверить иконки всех статов;
- получить level-up и проверить reward icons;
- пройти обычный бой;
- проверить карту без ям/колонн;
- проверить бой с элиткой и боссом без obstacle artifacts.

## Документация

После реализации обновить:

- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`;
- `docs/design/content_registry.md`;
- `docs/design/mechanics_extract.md`, если менялись активные параметры UI или механика карты.

Не оставлять UI/obstacle изменения только в коде.
