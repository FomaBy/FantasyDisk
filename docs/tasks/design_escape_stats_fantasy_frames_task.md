# Задача Для Design-Агента: Fantasy Frames И Compact Style Для Escape Stats Menu

Статус: done
Дата: 2026-06-10

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: подготовь visual assets/style, обнови документацию и передай handoff Back-end. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

Escape stats menu нужно сделать компактным и красивым в стиле FantasyDisk. Back-end перестраивает layout:

```text
docs/tasks/backend_escape_stats_compact_grouped_layout_task.md
```

Design должен подготовить визуальный стиль: fantasy frames, компактные stat chips/rows, tooltip frame и общий вид, чтобы меню не выглядело как default Godot.

## Главная Цель

Подготовить UI visual kit для Escape stats menu:

- компактный frame для basic stat row;
- frame/section для grouped derived stats;
- tooltip frame;
- button/panel style, если нужно;
- цветовые состояния high/low/effective;
- правила spacing/размеров;
- ассеты/референс, которые Back-end сможет подключить.

## Требования К Стилю

Стиль:

- fantasy cartoon;
- цельный с текущими персонажами и монстрами;
- аккуратные рамки;
- не слишком тяжелый декор;
- компактный;
- читаемый на темном/игровом фоне;
- без default Godot look.

Можно использовать:

- пергамент/темный камень/металл/магические линии;
- небольшие декоративные углы;
- тонкие разделители секций;
- подсветку rarity/effectiveness цветом.

Нельзя:

- огромные карточки на каждый стат;
- визуальный шум;
- слишком толстые фреймы;
- default rectangles;
- emoji;
- элементы не в стиле игры.

## Asset IDs

Подготовить или описать assets:

| ID | Назначение |
| --- | --- |
| `ui_escape_panel_frame` | Общая рамка Escape menu |
| `ui_escape_button_frame` | Кнопки управления |
| `ui_stat_basic_row_frame` | Компактная строка базовой характеристики |
| `ui_stat_group_frame` | Контейнер группы производных параметров |
| `ui_stat_chip_frame` | Маленький chip параметра |
| `ui_stat_tooltip_frame` | Tooltip frame |
| `ui_stat_value_high` | Цвет/стиль высокого значения |
| `ui_stat_value_low` | Цвет/стиль низкого значения |
| `ui_stat_value_neutral` | Нейтральный стиль |

Если часть можно сделать StyleBox/Theme без PNG, описать параметры и передать Back-end.

## Связь С Иконками

Использовать иконки из:

```text
docs/tasks/design_stat_icons_hud_visual_task.md
```

Если иконки еще не готовы, этот task должен определить, как они будут сидеть в compact rows:

- размер иконки;
- padding;
- alignment;
- hover state;
- disabled/missing fallback.

## Handoff Для Back-end

После подготовки visual kit передать Back-end:

- список файлов;
- asset IDs;
- рекомендуемые размеры;
- цвета;
- пример layout;
- что использовать для basic stat rows;
- что использовать для grouped derived stat sections;
- что использовать для tooltip.

## Back-end Status / Интеграционные Хуки

Back-end layout реализован в `scripts/pause_stats_menu.gd` без новых PNG, на текущих `StyleBoxFlat` и `UIIconRegistry`.

Текущие node names / hooks:

| Node / Hook | Назначение |
| --- | --- |
| `EscapeStatsPanelFrame` | общая рамка Escape stats menu |
| `RunControls` | левая колонка |
| `PauseControlButtons` | кнопки управления сверху слева |
| `BaseStatsList` | компактные строки базовых характеристик под кнопками |
| `BaseStatRow_<stat_id>` | строка базовой характеристики |
| `DerivedStatsPanel` | правая/центральная область |
| `DerivedStatsScroll` | вертикальный скролл для групп |
| `DerivedStatsGroups` | GridContainer групп производных параметров |
| `DerivedStatGroup_<group_id>` | секция производных параметров |
| `DerivedStatChips_<group_id>` | chips внутри секции |
| `DerivedStatChip_<stat_id>` | компактный chip производного параметра |

Текущие группы:

- `physical_damage`;
- `magic_damage`;
- `sound_control`;
- `dot_poison`;
- `survival`;
- `summons_support`.

Back-end ожидает от Design визуальный kit, который можно будет подключить без изменения логики:

- PNG/NinePatch или точные Theme/StyleBox параметры для `ui_escape_panel_frame`;
- frame/style для `ui_escape_button_frame`;
- frame/style для `ui_stat_basic_row_frame`;
- frame/style для `ui_stat_group_frame`;
- frame/style для `ui_stat_chip_frame`;
- tooltip frame/style для `ui_stat_tooltip_frame`;
- рекомендации по accent colors для групп выше;
- spacing/padding размеры для 1600x900 и 2560x1440.

Иконки статов уже подключены через `scripts/ui_icon_registry.gd`; новые icon assets не нужны для этой backend-задачи, если Design не хочет заменить существующий icon pack.

## Acceptance Criteria

Задача готова, если:

- есть понятный fantasy style для Escape stats menu;
- basic stat rows выглядят компактно и красиво;
- grouped stat sections выглядят организованно;
- tooltip frame читаемый и в стиле игры;
- Back-end получил понятный список asset IDs/files/styles;
- `content_registry.md` обновлен;
- `current_game_state.md` обновлен.

## Документация

После реализации обновить:

- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`.

Если часть стиля реализуется без PNG через Theme/StyleBox, описать это в документации.

## Design Deliverables / Готово 2026-06-10

Подготовлен compact fantasy visual kit для Escape stats menu в стиле FantasyDisk: темные fantasy-metal панели, золотые/магические bevel-рамки, компактные row/chip frames, tooltip frame, секционный divider и reference swatches для цветовых состояний.

Новые PNG assets:

| Asset ID | File |
| --- | --- |
| `ui_escape_panel_frame` | `assets/sprites/ui/frames/escape/ui_escape_panel_frame.png` |
| `ui_escape_button_frame` | `assets/sprites/ui/frames/escape/ui_escape_button_frame.png` |
| `ui_stat_basic_row_frame` | `assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png` |
| `ui_stat_group_frame` | `assets/sprites/ui/frames/escape/ui_stat_group_frame.png` |
| `ui_stat_chip_frame` | `assets/sprites/ui/frames/escape/ui_stat_chip_frame.png` |
| `ui_stat_tooltip_frame` | `assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png` |
| `ui_stat_section_divider` | `assets/sprites/ui/frames/escape/ui_stat_section_divider.png` |
| `ui_stat_value_state_swatches` | `assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png` |
| `escape_stats_visual_kit_preview` | `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` |

Каноническая спецификация по patch margins, color tokens, group accents, spacing для `1600x900` и `2560x1440`, typography и tooltip rules добавлена в:

```text
docs/design/escape_stats_visual_kit.md
```

Документация обновлена:

- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`;
- `docs/design/escape_stats_visual_kit.md`.

## Back-end Handoff / 2026-06-10

Back-end должен подключить готовые PNG как `StyleBoxTexture`/Theme overrides без изменения gameplay logic и без перестройки уже готового compact layout.

Рекомендуемое соответствие hooks:

| Hook | Design asset |
| --- | --- |
| `EscapeStatsPanelFrame` | `ui_escape_panel_frame` |
| `PauseControlButtons` buttons | `ui_escape_button_frame` |
| `BaseStatRow_<stat_id>` | `ui_stat_basic_row_frame` |
| `DerivedStatGroup_<group_id>` | `ui_stat_group_frame` |
| `DerivedStatChip_<stat_id>` | `ui_stat_chip_frame` |
| custom tooltip panel | `ui_stat_tooltip_frame` |
| optional group/header divider | `ui_stat_section_divider` |

Color/value tokens:

- high: `#70F2A6`;
- low: `#FF6B6B`;
- neutral: `#E9DCA7`;
- effective: `#FFDC5C`;
- primary text: `#EFE2B2`;
- secondary text: `#97A5B8`.

Group accent colors:

- `physical_damage`: `#F26138`;
- `magic_damage`: `#8C6BFF`;
- `sound_control`: `#4DDCFF`;
- `dot_poison`: `#72F06F`;
- `survival`: `#F2C752`;
- `summons_support`: `#E69EFF`.

Detailed margins and layout numbers are in `docs/design/escape_stats_visual_kit.md`.
