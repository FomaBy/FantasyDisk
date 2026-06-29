# SCRUM-579 — UI-редизайн «Пауза в забеге» @2K (2560×1440)

Эпик: SCRUM-481 (UI Overhaul 2K). Экран: **Пауза в забеге** · нода `RunPauseMenuPanel`
· вход `_show_pause_menu` → `_build_run_pause_menu` (`scripts/ui_screens.gd`).
База 2560×1440, `stretch=canvas_items`, `aspect=keep`.

## ЭТАП 1 — раскладка / метрики (код-константы)

Метрики уже закреплены в `scripts/ui_screens.gd` (блок `PM_*`, SCRUM-484):

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `PM_PANEL_2K` | 831 | 310 | 898 | 820 |
| Safe-area | `PM_SAFE_2K` | 898 | 396 | 764 | 656 |
| Заголовок «Пауза» | `PM_TITLE_2K` | 898 | 509 | 764 | 58 |
| Подзаголовок | `PM_SUBTITLE_2K` | 898 | 575 | 764 | 24 |
| Кнопка «Продолжить» | `PM_BTN_CONTINUE_2K` | 1140 | 607 | 280 | 60 |
| Кнопка «Досье персонажа» | `PM_BTN_DOSSIER_2K` | 1140 | 675 | 280 | 60 |
| Кнопка «Настройки» | `PM_BTN_SETTINGS_2K` | 1140 | 743 | 280 | 60 |
| Кнопка «Покинуть забег» | `PM_BTN_ENDRUN_2K` | 1140 | 811 | 280 | 60 |
| Кнопка «Главное меню» | `PM_BTN_MAINMENU_2K` | 1140 | 879 | 280 | 60 |

Раскладка: компактная модалка в верхне-левой игровой зоне (SCRUM-556), заголовок +
подзаголовок + вертикальный стек из 5 кнопок 280×60. Всё помещается в safe-area панели.

## ЭТАП 2 — генерация / интеграция ассетов

Ассеты блока паузы (`pm_panel` 898×820, `pm_btn` 280×60) уже сгенерированы рисующим
пайплайном `tools/build_ui_2k_frame_kit.py` (SCRUM-485/486), 9-slice-safe, верификатор
PASS на 1080p/2K/4K, прозрачный фон, единый дарк-фэнтези bright-минимал:

| slug | ассет | размер | 9-slice margins |
|---|---|---|---|
| `pm_panel` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pm_panel.png` | 898×820 | 38/52/38/48 |
| `pm_btn` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pm_btn.png` | 280×60 | 34/16/34/16 |

Панель `RunPauseMenuPanel` уже использовала `pm_panel` (SCRUM-486). Этот редизайн
завершает экран, **подключая выделенный `pm_btn` @2K-фрейм для всех 5 кнопок паузы**
вместо общего minimal-metal standard-кнопочного фрейма — единый стиль кнопок с панелью.

## Интеграция в рантайм

- `scripts/ui_screens.gd` `_build_run_pause_menu`: после `_set_action_button_size(...,280,60)`
  каждая из 5 кнопок получает `_apply_overhaul_2k_button_theme(button, "pm_btn",
  PM_BTN_*_2K.size)` (normal/hover/focus/pressed/disabled + неон-нейтральные тинты/шрифты,
  как у hs4-кнопок SCRUM-561). Геометрия/safe-zone/anchor паузы не тронуты.

## Тесты (green-gate)

- `tests/runtime_smoke_test.gd` — PASS (добавлена проверка: все 5 кнопок паузы используют
  pm_btn @2K-фрейм; pm_panel-проверка сохранена).
- `tests/ui_no_overlap_matrix_test.gd` — PASS (pause_menu: панель+5 кнопок, no-overlap/fit).
- `tests/display_resolution_test.gd` — PASS.
