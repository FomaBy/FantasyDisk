# SCRUM-580 — UI-редизайн «Пауза — досье» @2K (2560×1440)

Эпик: SCRUM-481 (UI Overhaul 2K). Экран: **Пауза — досье** · нода `EscapeStatsPanelFrame`
· вход `_show_pause_dossier_menu` → `_build_layout` (`scripts/pause_stats_menu.gd`).
База 2560×1440, `stretch=canvas_items`, `aspect=keep`.

## ЭТАП 1 — раскладка / метрики (код-константы)

Метрики закреплены в `scripts/pause_stats_menu.gd` (блок `PD_*`, SCRUM-484):

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм, почти full-screen) | `PD_PANEL_2K` | 20 | 18 | 2520 | 1404 |
| Safe-area | `PD_SAFE_2K` | 135 | 165 | 2290 | 1123 |
| Левая колонка управления | `PD_LEFT_COLUMN_2K` | 135 | 165 | 330 | 1123 |
| Правая область (статы/арты) | `PD_RIGHT_AREA_2K` | 483 | 165 | 1942 | 1123 |
| Кнопка управления (шаблон) | `PD_BTN_2K` | — | — | 280 | 60 |

Раскладка: двухколоночная модалка — слева управление (4 кнопки + досье героя + базовые
статы + артефакты), справа боевые параметры (грид групп). Контент list-driven, в скроллах;
всё в safe-area. Длинный контент уходит в скролл, рамка не растягивается.

## ЭТАП 2 — генерация / интеграция ассетов

Ассеты блока досье-паузы (`pd_panel` 2520×1404, `pd_btn` 280×60) уже сгенерированы
рисующим пайплайном `tools/build_ui_2k_frame_kit.py` (SCRUM-485/486), 9-slice-safe,
верификатор PASS на 1080p/2K/4K, единый дарк-фэнтези стиль:

| slug | ассет | размер | 9-slice margins |
|---|---|---|---|
| `pd_panel` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pd_panel.png` | 2520×1404 | 46/62/46/58 |
| `pd_btn` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pd_btn.png` | 280×60 | 34/16/34/16 |

Панель `EscapeStatsPanelFrame` уже использовала `pd_panel` (SCRUM-486, через
`_pause_end_modal_style` → `ESCAPE_PANEL_FRAME_2K`). Этот редизайн завершает экран,
**подключая выделенный `pd_btn` @2K-фрейм для 4 кнопок управления** (Продолжить/Настройки/
Завершить забег/Главное меню) вместо общего minimal-metal pause-кнопочного фрейма.

## Интеграция в рантайм

- `scripts/pause_stats_menu.gd`:
  - добавлен preload `PD_BTN_FRAME_2K` и `_apply_pd_2k_button_theme(button, variant)`
    (один ассет + state-тинты, margins/content 34/16/34/16 как у общего pause-стиля —
    safe-зона текста сохраняется; `danger`-вариант для «Завершить забег»);
  - `_build_left_controls`: 4 кнопки управления получают `_apply_pd_2k_button_theme`.
  Геометрия/safe-zone/двухколоночная раскладка/list-контент не тронуты.

## Тесты (green-gate)

- `tests/runtime_smoke_test.gd` — PASS (pd_panel-проверка сохранена; добавлена проверка:
  4 кнопки управления используют pd_btn @2K-фрейм; старый minimal-metal-pause-assert
  кнопок заменён на pd_btn-assert).
- `tests/ui_no_overlap_matrix_test.gd` — PASS (pause_stats: панель + control-кнопки + статы,
  no-overlap/text-containment).
- `tests/display_resolution_test.gd` — PASS.
