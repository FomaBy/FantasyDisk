# Mockup-спека — Подтверждение выхода (SCRUM-581, эпик SCRUM-481 UI Overhaul 2K)

База **2560×1440**, `stretch=canvas_items`, `aspect=keep`. Свежий @2K-редизайн модалки
«Выйти из игры?» (`_show_quit_confirmation_dialog`): диалог получает СОБСТВЕННУЮ per-слот
рамку `qc_modal` (modal-профиль, более ornate бордюр befitting confirm-диалога) вместо
общего `qc_panel` (panel-профиль), который SCRUM-486 расшарил с блоком Меню/Навигация.
Кнопки остаются на унифицированном 4-state minimal_metal (per-слот button-PNG одностейтовы —
форс убрал бы hover/press). Стиль — единый bright-минимал amber dark-fantasy.

## ЭТАП 1 — раскладка / метрики @2560×1440

Координаты зафиксированы код-константами `QC_*_2K` (SCRUM-484). Редизайн их НЕ меняет.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Затемнение (full-rect, α0.70) | `QC_DIM_2K` | 0 | 0 | 2560 | 1440 |
| Панель (фрейм) | `QC_PANEL_2K` | 980 | 550 | 600 | 340 |
| Safe-area | `QC_SAFE_2K` | 1038 | 622 | 484 | 202 |
| Заголовок «Выйти из игры?» | `QC_TITLE_2K` | 1038 | 627 | 484 | 44 |
| Подзаголовок (autowrap) | `QC_SUBTITLE_2K` | 1038 | 687 | 484 | 44 |
| Кнопка «Выйти» | `QC_BTN_EXIT_2K` | 1051 | 747 | 220 | 72 |
| Кнопка «Отмена» | `QC_BTN_CANCEL_2K` | 1289 | 747 | 220 | 72 |

**Инварианты (проверены `ui_no_overlap_matrix_test` + smoke quit-dump):** модалка по центру,
dim на весь экран, контент (заголовок/подзаголовок/2 кнопки) в safe-area без overflow/overlap;
текст в рамке; модалка блокирует клики ниже (mouse_filter=STOP), фокус по умолчанию на
безопасной «Отмена».

## ЭТАП 2 — генерация рамки

Рамка `qc_modal` 600×340 сгенерирована детерминированным `tools/build_ui_2k_frame_kit.py`
(SCRUM-485) — 9-slice-safe, РОВНО в пиксельный размер слота @2K с нативными бордюрами
(modal-профиль 46,62,46,58 — толще panel-профиля). Рендер-верификатор (`--verify`) зелёный:
размер == ожидаемый, 9-slice валиден, углы стабильны на 1080p/2K/4K, центр чист, нет stray-островов.

Ассет: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_qc_modal.png`.

## Подключение в рантайм

- `ui_theme_paths.gd`: `qc_modal` в `OVERHAUL_2K_FRAME_PATHS`/`_SOURCE_SIZE`/`_TEXTURE_MARGINS`/`_CONTENT`.
- `ui_screens.gd` `_show_quit_confirmation_dialog`: панель переведена с `_overhaul_2k_frame_style("qc_panel")`
  на `_overhaul_2k_frame_style("qc_modal", Vector2(600,340))`. Раскладка/кнопки/фокус не тронуты.

## Тесты (green-gate)

- `tests/runtime_smoke_test.gd` — PASS (модалка строится, modal/focus/button-size инварианты держатся;
  текстура панели не пинится ассертом, так что подмена qc_panel→qc_modal безопасна).
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
