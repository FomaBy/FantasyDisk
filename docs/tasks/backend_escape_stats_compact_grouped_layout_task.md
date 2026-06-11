# Задача Для Back-end-Агента: Компактный Escape Stats Layout С Группами Характеристик

Дата: 2026-06-10

Статус: done 2026-06-10. Результат: Escape stats menu перестроен в компактный layout: кнопки управления слева, базовые характеристики под ними, производные параметры справа в группах; интегрированы Design frame assets через StyleBoxTexture, UIIconRegistry и custom tooltip frame; runtime smoke test проверяет panel/buttons/base rows/groups/chips/tooltips и проходит.

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: перестрой UI, интегрируй иконки/стили, обнови тесты и документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

При нажатии Escape во время игры открывается окно с кнопками меню и характеристиками. Сейчас характеристики занимают слишком много места и расположены не так удобно.

Пользователь хочет:

- переместить базовые характеристики типа Силы, Выносливости и т.д. слева вниз под кнопки управления;
- кнопки управления (`Меню`, `Выход`, `Завершить забег` и т.п.) оставить слева сверху/слева, а характеристики разместить под ними;
- сделать характеристики короткими: иконка, название, значение;
- при наведении показывать tooltip: за что отвечает характеристика и на что влияет;
- сделать layout компактным, чтобы много характеристик помещалось сразу;
- основные характеристики вынести на основной экран Escape menu;
- производные/боевые параметры сгруппировать логически: физический урон, магический урон, дальний урон, яд/DoT, приспешники и т.д.;
- оформить все в едином дизайне игры, желательно с fantasy frames.

## Design Dependency

Связанная design-задача:

```text
docs/tasks/design_escape_stats_fantasy_frames_task.md
```

Если Design уже подготовил frames/icons/styles, интегрировать их. Если еще нет, сделать функциональный layout с clean placeholders/hooks и оставить явные asset IDs для подключения.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/process/agent_role_boundaries_and_handoffs.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/design/mechanics_extract.md`
- `docs/tasks/design_stat_icons_hud_visual_task.md`

## Главная Цель

Сделать Escape stats menu компактным, понятным и красивым:

- слева: блок кнопок управления;
- под кнопками: базовые характеристики;
- справа/в центре: сгруппированные производные параметры;
- каждая строка/плитка: иконка, короткое название, значение;
- hover показывает подробную подсказку с описанием и влияниями;
- экран помещает много характеристик без ощущения огромной таблицы;
- visual style соответствует FantasyDisk.

## Layout Requirements

### Левая Колонка

Слева разместить:

1. Кнопки управления:
   - Продолжить;
   - Настройки / Меню, если есть;
   - Завершить забег;
   - Выход в главное меню.
2. Под кнопками: базовые характеристики.

Базовые характеристики должны быть компактными:

```text
[icon] Сила 10
[icon] Ловкость 5
[icon] Интеллект 2
...
```

Не делать огромные карточки для каждой базовой характеристики.

### Основной Экран / Правая Область

В основной области показать производные параметры, сгруппированные логически.

Пример групп:

- Физический урон:
  - Урон;
  - Скорость атаки;
  - Шанс крита;
  - Множитель крита;
  - Отталкивание.
- Магический урон:
  - Магический урон;
  - Радиус AoE;
  - Скорость снарядов;
  - Дальность атаки.
- Звук / Дальний контроль:
  - Урон звуковой волны;
  - Радиус ауры;
  - Сила баффов;
  - Отталкивание.
- Яд / DoT:
  - Урон DoT;
  - Скорость тиков DoT.
- Выживаемость:
  - Максимальное здоровье;
  - Защита;
  - Уворот;
  - Скорость движения.
- Приспешники / Поддержка:
  - Количество призывов;
  - Радиус ауры;
  - Сила баффов;
  - Радиус подбора.

Можно изменить группы, если получится логичнее, но они должны быть понятными игроку.

## Compactness Requirements

- Использовать компактные строки или маленькие stat chips.
- В одну строку/секцию должно помещаться несколько параметров.
- Не использовать hero-scale text.
- Не делать один параметр на огромную карточку.
- Избегать горизонтального скролла.
- Вертикальный скролл допустим, если параметров слишком много, но основные группы должны быть видны сразу.
- На `1600x900` должно помещаться большинство важной информации.
- На `2560x1440` layout должен выглядеть аккуратно, не растягиваться пусто.

## Tooltip Requirements

При наведении на базовую характеристику или производный параметр:

- показать краткое описание;
- показать, на что влияет;
- для производных параметров показать формулу или источники влияния, если это уже есть в `StatFormulas`;
- tooltip не должен выходить за экран;
- tooltip должен выглядеть в стиле игры.

## Icons

Использовать иконки из design task:

```text
docs/tasks/design_stat_icons_hud_visual_task.md
```

Если иконки еще не готовы:

- создать mapping по ID;
- использовать временный neutral placeholder только как fallback;
- явно пометить в документации, что backend ожидает финальные иконки от Design.

## Visual Style

Интегрировать fantasy visual style:

- аккуратные fantasy frames;
- темные/каменные/пергаментные панели, если подходят текущему стилю;
- читаемый контраст;
- не default Godot controls;
- не перегружать декоративностью;
- не ломать компактность.

## Files To Check

Обязательно проверить:

- `scripts/pause_stats_menu.gd`
- `scenes/PauseStatsMenu.tscn`
- `scripts/stat_formulas.gd`
- `scripts/progression_data.gd`
- `scripts/main.gd`
- `tests/runtime_smoke_test.gd`

Если UI генерируется полностью кодом, аккуратно выделить helper methods для:

- basic stat rows;
- derived stat groups;
- tooltip creation;
- icon lookup;
- value formatting.

## Acceptance Criteria

Задача готова, если:

- Escape открывает обновленное меню;
- кнопки управления слева;
- базовые характеристики слева под кнопками;
- базовые характеристики компактные: иконка, название, значение;
- производные параметры сгруппированы логически;
- много параметров помещается сразу;
- hover tooltip работает для базовых и производных параметров;
- используются иконки или готов mapping под них;
- visual style не выглядит default Godot;
- layout читается на `1600x900` и `2560x1440`;
- pause behavior не сломан;
- тесты обновлены и проходят;
- документация обновлена.

## Проверка

Запустить:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Ручная проверка:

- начать бой;
- нажать Escape;
- проверить левую колонку;
- проверить базовые характеристики под кнопками;
- проверить группы производных параметров;
- навести на каждый тип статов;
- проверить `1600x900`;
- проверить `2560x1440`;
- закрыть меню и убедиться, что игра продолжается.

## Документация

После реализации обновить:

- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`;
- `docs/design/mechanics_extract.md`, если менялись группы/названия параметров;
- `docs/design/content_registry.md`, если добавлены UI asset IDs;
- после domain split: `docs/design/systems/menus_ui.md`.

Не оставлять изменение только в коде.

## Design Visual Kit Ready / Handoff 2026-06-10

Design подготовил fantasy visual kit для уже реализованного compact Escape stats menu layout. Интеграция должна подключить готовые PNG frames/style к существующим hooks в `scripts/pause_stats_menu.gd`, сохранив текущую backend layout/tooltip/stat logic.

Каноническая спецификация:

```text
docs/design/escape_stats_visual_kit.md
```

Готовые assets:

| Asset ID | File | Hook |
| --- | --- | --- |
| `ui_escape_panel_frame` | `assets/sprites/ui/frames/escape/ui_escape_panel_frame.png` | `EscapeStatsPanelFrame` |
| `ui_escape_button_frame` | `assets/sprites/ui/frames/escape/ui_escape_button_frame.png` | buttons inside `PauseControlButtons` |
| `ui_stat_basic_row_frame` | `assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png` | `BaseStatRow_<stat_id>` |
| `ui_stat_group_frame` | `assets/sprites/ui/frames/escape/ui_stat_group_frame.png` | `DerivedStatGroup_<group_id>` |
| `ui_stat_chip_frame` | `assets/sprites/ui/frames/escape/ui_stat_chip_frame.png` | `DerivedStatChip_<stat_id>` |
| `ui_stat_tooltip_frame` | `assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png` | custom stat tooltip panel |
| `ui_stat_section_divider` | `assets/sprites/ui/frames/escape/ui_stat_section_divider.png` | optional group/header divider |
| `ui_stat_value_state_swatches` | `assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png` | design reference only |
| `escape_stats_visual_kit_preview` | `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` | design reference only |

Recommended `StyleBoxTexture` patch margins:

| Asset ID | Left | Top | Right | Bottom |
| --- | ---: | ---: | ---: | ---: |
| `ui_escape_panel_frame` | 40 | 40 | 40 | 40 |
| `ui_escape_button_frame` | 28 | 24 | 28 | 28 |
| `ui_stat_basic_row_frame` | 20 | 12 | 20 | 14 |
| `ui_stat_group_frame` | 34 | 30 | 34 | 34 |
| `ui_stat_chip_frame` | 20 | 12 | 20 | 14 |
| `ui_stat_tooltip_frame` | 34 | 30 | 34 | 34 |
| `ui_stat_section_divider` | 14 | 4 | 14 | 4 |

Color tokens:

- high: `#70F2A6`;
- low: `#FF6B6B`;
- neutral: `#E9DCA7`;
- effective: `#FFDC5C`;
- primary text: `#EFE2B2`;
- secondary text: `#97A5B8`;
- panel bg: `#070A12F2`;
- row bg: `#161926DC`;
- chip bg: `#191E2BDC`;
- gold border: `#E0B046`;
- hover/tooltip cyan: `#50DCE6`;
- derived group violet: `#A076D8`.

Group accent colors:

| Group ID | Accent |
| --- | --- |
| `physical_damage` | `#F26138` |
| `magic_damage` | `#8C6BFF` |
| `sound_control` | `#4DDCFF` |
| `dot_poison` | `#72F06F` |
| `survival` | `#F2C752` |
| `summons_support` | `#E69EFF` |

Back-end acceptance for this integration pass:

- replace clean `StyleBoxFlat` placeholders with the Design PNG frames or matching Theme/StyleBox overrides;
- keep the left controls + base stats and right grouped derived stats layout;
- keep `UIIconRegistry` icon usage;
- clamp tooltips inside viewport and style them with `ui_stat_tooltip_frame`;
- verify readability at `1600x900` and `2560x1440`;
- run the existing runtime smoke test after code integration.

## Back-end Integration Complete 2026-06-10

Интегрировано в `scripts/pause_stats_menu.gd`:

- `ui_escape_panel_frame.png` -> `EscapeStatsPanelFrame` через `StyleBoxTexture`;
- `ui_escape_button_frame.png` -> кнопки `PauseControlButtons` через `StyleBoxTexture`;
- `ui_stat_basic_row_frame.png` -> `BaseStatRow_<stat_id>`;
- `ui_stat_group_frame.png` -> `DerivedStatGroup_<group_id>`;
- `ui_stat_chip_frame.png` -> `DerivedStatChip_<stat_id>`;
- `ui_stat_tooltip_frame.png` -> custom tooltip panel `_make_custom_tooltip()`;
- `ui_stat_section_divider.png` -> `StatSectionDivider`.

Runtime smoke test обновлен и проверяет, что panel/buttons/base rows/groups/chips/custom tooltip используют `StyleBoxTexture`.

Проверка:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Результат: passed.
