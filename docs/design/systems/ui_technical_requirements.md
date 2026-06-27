# UI Technical Requirements

Обновлено: 2026-06-14

Назначение документа: зафиксировать технический контракт для интерфейса FantasyDisk: размеры, отступы, прозрачность, 9-slice-поля, scaling, hit-area, состояния контролов и QA-проверки. Документ не задает арт-дирекшен, визуальный стиль, композиционные решения или новые дизайнерские решения.

## Приоритет Источников

Если документы конфликтуют, использовать такой порядок:

1. Фактические константы и размеры в `scripts/ui_screens.gd`, `scripts/ui/*.gd`, `scripts/route_map_screen.gd`, `scripts/pause_stats_menu.gd`.
2. Этот документ.
3. Последние закрытые task-файлы по UI (`SCRUM-263`, `SCRUM-264`, `SCRUM-223` и связанные).
4. Старые заметки в `docs/design/systems/menus_ui.md`.

Текущий стандарт action-кнопок: высота `104 px`. Старые упоминания `68 px` считать устаревшими, кроме абсолютного smoke-порога: wax-seal-кнопка не должна визуально сжиматься ниже `64 px`.

## Общие Правила

- Все размеры ниже указаны в Godot logical pixels при UI scale `1.0`.
- Интерфейс обязан проходить без пересечений и выхода текста за контейнеры на `1280x720`, `1600x900`, `1920x1080`, `2560x1440`; QA-матрица также должна покрывать нестандартные размеры, которые уже используются тестами.
- Hover, focus, pressed, disabled и animation-состояния не должны менять `custom_minimum_size` и не должны сдвигать соседние элементы.
- Fullscreen-экраны используют `Control.PRESET_FULL_RECT`.
- Фоновые `TextureRect` на экранах используют `EXPAND_IGNORE_SIZE` и `STRETCH_KEEP_ASPECT_COVERED`.
- Иконки и портреты в UI используют `EXPAND_IGNORE_SIZE` и `STRETCH_KEEP_ASPECT_CENTERED`, если экран явно не требует full-cover фон.
- Горизонтальный скролл запрещен для route map, pause stats и основных меню; длинный контент уходит в вертикальный `ScrollContainer`.
- Длинный текст должен иметь `AUTOWRAP_WORD_SMART` или быть вынесен в отдельный info-frame над кнопкой.

## Базовые Прозрачности Экранов

| Элемент | Требование |
| --- | --- |
| Main menu shade | `Color(..., alpha=0.18)` поверх full-cover фона. |
| Generic menu shade | `Color(0, 0, 0, alpha=0.44)` поверх screen backdrop. |
| Route map backdrop shade | `alpha=0.62` для фонового затемнения + `alpha=0.20` для верхнего общего слоя. |
| Attribute/upgrades modal shade | `alpha=0.92`. |
| Pause stats dim | `alpha=0.74`. |
| Level-up/reward dim | стартует с `alpha=0.0`, анимируется до целевого затемнения. |
| Damage flash overlay | пиковый `modulate.a = 0.20`, спад до `0.0` за `0.32s`. |

## Action-Кнопки

| Тип | Размер / ограничение |
| --- | --- |
| Standard action button | `420 x 104`. |
| Maximum visual action width | `560`, высота всегда `104`. |
| Main menu action button | `380 x 104`. |
| Hero select confirm | `320 x 104`. |
| Settings reset audio | `420 x 104`. |
| Settings reset bindings | `440 x 104`. |
| Codex tab action button | `230 x 104`. |
| Back/action variants | ширина `170`, `260`, `380` или screen-specific, высота `104`. |
| Attribute offer button | ширина до `560`, высота `104`. |
| Upgrade FAB | `58 x 58`. |
| Compact utility button | `54 x 62`. |
| Pause menu button | `280 x 60` внутри escape panel. |
| Rebind button | `420 x 62`. |

Технические правила:

- Standard action-кнопки создаются через `_make_button()` и нормализуются через `_set_action_button_size()`.
- Визуальная ширина action-кнопки вычисляется как `min(width, 560)`.
- Button text не должен быть единственным носителем длинного описания. Для длинного текста использовать info-frame над кнопкой + короткую команду на кнопке.
- Compact utility controls не обязаны использовать wax-seal/button-only frame.
- Disabled state обязан сохранять тот же hit-rect и размер, что normal state.

## Button 9-Slice И Состояния

| Компонент | Texture margins | Content margins |
| --- | --- | --- |
| Global action button state | `left=88, top=30, right=38, bottom=32` | `left=76, top=14, right=22, bottom=14` |
| Generic fallback button | `34, 26, 34, 28` | `18, 12, 18, 14` |
| Pause escape button | `28, 24, 28, 28` | `16, 10, 16, 12` |

State alpha для compact fallback controls:

| State | Background alpha | Border alpha |
| --- | ---: | ---: |
| normal | `0.78` | `0.86` |
| hover | `0.92` | `1.00` |
| pressed | `0.96` | сохраняет readable border |
| disabled | `0.58` | `0.72` |

## Panels, Cards, Tooltips

Все UI-frame PNG должны быть `RGBA8`, с ненулевым alpha-каналом, прозрачными углами и без baked checkerboard. Углы frame-ассетов должны оставаться реально прозрачными (`corner alpha = 0.00`), а не имитировать прозрачность цветом.

| Компонент | Texture margins | Content margins |
| --- | --- | --- |
| Global panel | `34, 34, 34, 34` | `28, 26, 28, 26` |
| Level panel | `46, 46, 46, 46` | `34, 30, 34, 30` |
| Level/card frame | `28, 28, 28, 28` | `7, 7, 7, 7` |
| Hero portrait/card frame | `28, 28, 28, 28` | `8, 8, 8, 8` |
| Card hover/card frame | `30, 30, 30, 30` | `16, 14, 16, 14` |
| Tooltip frame | `26, 26, 26, 26` | `14, 12, 14, 12` |
| HUD panel | `28, 22, 28, 24` | `10, 9, 10, 9` |
| HUD card | `22, 18, 22, 20` | `8, 7, 8, 7` |
| Timer panel | `34, 24, 34, 24` | `14, 4, 14, 4` |
| Pause main panel | `40, 40, 40, 40` | `24, 24, 24, 24` |
| Pause stat group | `34, 30, 34, 34` | `14, 12, 14, 14` |
| Pause stat chip/basic row | `20, 12, 20, 14` | `8, 4-6, 8, 4-6` |
| Pause stat tooltip | `34, 30, 34, 34` | `18, 16, 18, 16` |

Fallback texture style, если PNG не найден: background `alpha=0.94`, border `alpha=0.85`, border width `2`, radius `8`.

## Main Menu

- Root: fullscreen.
- Background: `TextureRect`, full-cover.
- Shade: `alpha=0.18`.
- Action column minimum width: `380`.
- Все main actions: `380 x 104`.
- Version label alpha: `0.85`.
- Hover/focus не должен менять ширину колонки.

## Generic Menu Screens

- Header min height: `50`.
- Back/action buttons: высота `104`, ширина по экрану/назначению.
- Screen backdrop: full-cover `TextureRect`; fallback color allowed only if asset absent.
- Shade: `alpha=0.44`.
- Страница должна расширяться по ширине, но контент с длинным списком обязан уходить в vertical scroll.

## Hero Select

| Элемент | Требование |
| --- | --- |
| Large portrait | `320 x 400`, centered aspect. |
| Radar reserve | `408 x 300`. |
| Radar control | `360 x 230`. |
| Thumbnail strip | min height `96`. |
| Hero thumbnail button | `124 x 88`. |
| Ascension +/- | `54 x 62`. |
| Ascension label | `190 x 46`. |
| Ascension modifiers line | min height `34`. |
| Confirm button | `320 x 104`. |

Radar technical parameters:

- Radius: `min(size.x, size.y) * 0.30`.
- Ring alpha: `0.28`.
- Axis alpha: `0.34`.
- Label font size: `12`; label width `56`.
- Label text alpha: `0.96`.
- Fill alpha: `0.30`.
- Outline alpha: `0.95`; outline width `2`.
- Class fill input alpha uses current class color alpha `0.82`.

Layout acceptance:

- Dossier column, portrait, radar, thumbnail strip and confirm action must not overlap at `1280x720`.
- Portrait and radar must remain visible without requiring horizontal scroll.

## Weapon Select And Cards

- Weapon card target size: `300 x 150` in current character card lists.
- Large weapon choose row/button: `860 x 173`.
- Weapon icon preview: `112 x 112` when used in large row.
- Weapon/card controls use card/text-field styling, not standard wax-seal action-button framing unless explicitly acting as a final command.
- Card normal background alpha: `0.82`.
- Card hover background alpha: `0.92`.
- Card pressed background alpha: `0.96`.
- Card disabled background alpha: `0.55`.
- Card normal border alpha: `0.72`; hover `0.96`; disabled `0.65`.

## Attribute, Skill Tree, And Upgrade Controls

| Элемент | Требование |
| --- | --- |
| Attribute overlay shade | `alpha=0.92`. |
| Upgrade FAB | `58 x 58`. |
| Skill tree node row | min height `103`. |
| Attribute offer button | action height `104`, max width `560`. |
| Small progress dots | `3 x 2`. |

Attribute/level text-field styles:

| State | Background alpha | Border alpha |
| --- | ---: | ---: |
| normal common | `0.86` | `0.82` |
| normal rare | `0.88` | `0.98` |
| hover common | `0.94` | `0.94` |
| hover rare | `0.94` | `1.00` |
| disabled | `0.56` | `0.70` |

## Level-Up And Reward Overlay

| Элемент | Требование |
| --- | --- |
| Level-up hero frame | `92 x 92`. |
| Level-up hero portrait | `92 x 92`. |
| Rewards row | min height `260` for compact reward row; `380` for large reward overlay. |
| Large reward panel | `1140 x 560`. |
| Reward card | `245 x 364`. |
| Artifact reward card | `340 x 502`. |
| Continue/later action | standard `420 x 104` unless screen-specific. |

Animations:

- Dim starts at `alpha=0.0`.
- Panel and reward buttons may animate `modulate.a` from `0.0` to `1.0`.
- Animation must not alter final `custom_minimum_size` or cause layout shift.

## Shop

| Элемент | Требование |
| --- | --- |
| Inline slot | `164 x 186`. |
| Inline item icon | `112 x 112`. |
| Price badge | `108 x 30`. |
| Money icon inside price | `18 x 18`. |
| Slot texture margin | `24 x 24`. |
| Unaffordable icon modulate | `alpha=0.82`. |

Shop style alpha:

| Элемент | Normal alpha | Hover/variant alpha |
| --- | ---: | ---: |
| Slot background | `0.58` | `0.72` |
| Slot border | `0.72` | `0.96` |
| Shop wall button bg | `0.00` | `0.08` |
| Shop wall button border | `0.00` | `0.38` |
| Shop wall shadow | `0.00` | `0.18` |
| Item shadow bg | `0.38` | fixed |
| Empty hook bg | `0.22` | fixed |
| Empty hook border | `0.42` | fixed |
| Affordable price bg | `0.78` | fixed |
| Unaffordable price bg | `0.82` | fixed |
| Purchased overlay bg | `0.68` | fixed |
| Purchased overlay border | `0.86` | fixed |

## Codex

- Glossary tooltip minimum width: `360`.
- Artifact codex icon: `96 x 96`.
- Tab action button: `230 x 104`.
- Dotted hover terms use hit-area stable labels; tooltip visibility must not resize surrounding grid.
- Glossary grid columns: `2`; horizontal separation `14`; vertical separation `10`.

## Settings

| Элемент | Требование |
| --- | --- |
| Settings TabContainer | min `1000 x 430`. |
| Settings tab switcher frame | Design-ready asset `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png`, base `1280 x 256`; whole-image proportional scaling only; labels/click zones use safe rects from SCRUM-325/SCRUM-334. |
| OptionButton controls | min `520 x 46`. |
| Settings row label | `180 x 46`. |
| Binding row label | `170 x 38`. |
| Rebind button | `420 x 62`. |
| Volume label | `170 x 42`. |
| Volume slider | `560 x 48`. |
| Volume value label | `58 x 42`. |
| Volume toggle | `108 x 42`. |
| Screen shake label | `220 x 36`. |

Slider:

- Range: `0..100`.
- Step: `2`.
- Track alpha: `0.96`.
- Track border alpha: `0.85`.
- Grabber area alpha: `0.82`.
- Grabber border alpha: `0.90`.
- Highlight grabber area alpha: `0.95`.
- Highlight border alpha: `1.00`.
- Keyboard focus mode: `FOCUS_ALL`.

Checkbox:

- Must use checked/unchecked texture icons when present.
- Hit-area must not shrink below its row height.
- Text state changes (`Вкл.`/`Выкл.`) must not resize the row.

## Pause / Escape Stats Menu

| Элемент | Требование |
| --- | --- |
| Fullscreen dim | `alpha=0.74`. |
| Root margins | left/right `30`, top/bottom `24`. |
| Layout separation | `18`. |
| Left column min width | `330`. |
| Control button | `280 x 60`. |
| Dossier portrait | `58 x 58`. |
| Artifact icon | `56 x 56`. |
| Basic stat row | min height `36`. |
| Value label | min width `48`. |
| Derived group panel | min width `430`. |
| Group accent strip | `5 x 26`. |
| Stat chip | `200 x 44`. |
| Tooltip max width | `430`; text width `390`. |
| Section divider | height `10`, stretch scale. |

Pause control button alpha:

- Normal bg `0.97`, hover `1.00`, pressed `1.00`.
- Normal border `0.92`, hover/pressed `1.00`.
- Disabled bg `0.82`, disabled border `0.95`.
- Focus border alpha `0.60`.

## Combat HUD

| Элемент | Требование |
| --- | --- |
| HUD resource panel default | `650 x 78`. |
| HUD resource panel responsive width | clamp `540..750`, at `<=1280` max `600`, emergency min `480`. |
| HUD resource card | `126 x 54`. |
| HUD money card | `88 x 54`. |
| HUD resource icon | `30 x 30`. |
| HUD progress bar | `62 x 10`. |
| Combat timer panel | `172 x 52`. |
| Ascension badge | `54 x 44`. |
| Artifact HUD row | width clamp `220..402`, height `104`. |
| Artifact HUD icon | `48 x 48`. |
| Top margin | resource panel `18`, timer `14`, artifact row `16`. |
| Inter-panel gap | `14`. |

HUD responsive behavior:

- Resource panel starts at x=`18`, y=`18`.
- Timer tries to stay centered; if it would overlap resource panel, it shifts right within viewport.
- Ascension badge sits next to timer; if it would leave viewport, it moves left of timer.
- Artifact row starts at right edge; if it overlaps occupied HUD space, it moves down to y=`88`.

## Route Map

| Элемент | Требование |
| --- | --- |
| Route steps to boss | `10` rows + final boss row. |
| Branches per row | `2..4`. |
| Node size | `88 x 88`. |
| Map padding | `170 x 72`. |
| Header height | `118`. |
| Screen margin | `28`. |
| Drag threshold | `8`. |
| Row gap | `165`. |
| Header top offset | `18`. |
| Header bottom | `ROUTE_MAP_HEADER_HEIGHT - 12`. |
| Scroll top | `ROUTE_MAP_HEADER_HEIGHT`. |
| Canvas min width | `max(viewport_width - margin*2 - 16, 1000)`. |
| Node icon inset | `10` each side. |
| Completed mark offset | left `42`, top `-6`, font `24`. |
| Connection line width | active `2.25`, inactive `1.25`. |

Route map states:

- Locked node modulate alpha: `0.72`.
- Locked background alpha: `0.78`; locked border alpha `0.85`.
- Completed background alpha: `0.90`; completed border alpha `0.82`.
- Available border alpha: `1.00`.
- Active connection alpha: `0.72`; inactive connection alpha `0.42`.
- Horizontal scroll disabled; pan/drag must not accidentally activate a node once drag distance exceeds `8`.

## Icons, Textures, Cursor

| Asset type | Requirement |
| --- | --- |
| Button primary source texture | `384 x 120`, RGBA8, non-empty alpha. |
| Escape button source texture | `384 x 144`, RGBA8, non-empty alpha. |
| Global button frame fallback | `160 x 88` source class, 9-slice margins from code. |
| Artifact icons | `256 x 256`, transparent background, readable at `40 x 40`; HUD display `48 x 48`; codex display `96 x 96`. |
| Derived stat icons | `64 x 64`. |
| Shop icon sources | `128 x 128`; inline display `112 x 112`. |
| Cursor variants | `48 x 48`, RGBA, transparent background. |
| Cursor hotspot | single declared hotspot across code/tests; current requirement: `(2, 2)`. |

Cursor variants:

- Default/fire cursor.
- Hover cursor.
- Attack cursor.

All cursor variants must import cleanly in Godot and keep the active tip inside the hotspot tolerance used by tests.

## Accessibility And Input

- Interactive controls must set pointing-hand cursor where appropriate.
- Keyboard focus must be visible for settings sliders, rebind controls and action buttons.
- Disabled controls must remain readable and non-clickable.
- Tooltips must not cover the hovered control's essential hit-area.
- Mouse-only hover details in codex/settings must have stable hit-rects.
- Text that changes every frame or on value change must reserve enough width (`value labels`, HUD counters, toggles).

## QA Acceptance

For any implementation change touching UI, run the relevant checks:

- Headless smoke:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --script res://tests/runtime_smoke_test.gd`
- UI no-overlap matrix test for viewport regressions. SCRUM-483 makes it the
  UI render gate for 1920x1080, 2560x1440 and 3840x2160: text controls must fit
  their allocated rect/content parent, peer controls must not overlap, and exact
  frame TextureRect assets must not use raw `STRETCH_SCALE`.
- Dark fantasy UI theme/import validation for RGBA, alpha, missing imports and frame assets.
- Shop/HUD/hero select targeted tests when those screens change.
- Manual screenshot review at `1280x720` and `2560x1440` for any new screen or major layout change.

Acceptance criteria:

- No control overlaps another control.
- No readable text is clipped unless the control explicitly scrolls or wraps.
- No button/card changes size between states.
- No full-screen backdrop is stretched without cover mode.
- No UI PNG has baked checkerboard transparency.
- No cursor, frame or icon import is missing.
- `custom_minimum_size` values match this document or a newer code constant with the task report documenting the reason.
