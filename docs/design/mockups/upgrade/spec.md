# Mockup-спека — Улучшение (SCRUM-573, эпик SCRUM-481 UI Overhaul 2K)

База **2560×1440**, `stretch=canvas_items`, `aspect=keep`. Редизайн экрана «Улучшение»
(`_show_upgrade_screen`, economy-панель "upgrade"): per-слот @2K-рамка панели вместо
общего `_economy_panel_style()` (minimal_metal panel), который ужимался под слот и мылил
орнамент. Стиль — единый bright-минимал amber dark-fantasy (как event SCRUM-565, меню SCRUM-486).

## ЭТАП 1 — раскладка / метрики @2560×1440

Панель улучшения центрирована, target 1720×730 (из `_economy_menu_panel_half_size("upgrade")`).
Зафиксировано код-константой `UPGRADE_PANEL_2K` в `scripts/ui_screens.gd`.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм) | `UPGRADE_PANEL_2K` | 420 | 355 | 1720 | 730 |
| Safe-area | `UPGRADE_SAFE_2K` | 478 | 427 | 1604 | 592 |
| Карточка выбора (×3) | — (economy-choice) | — | — | ~480 | ~340 |

**Инварианты (проверены `ui_no_overlap_matrix_test`, секция upgrade_economy на 1080p/2K/4K):**
заголовок + подзаголовок + 3 карточки выбора усиления влезают в safe-area без overflow/overlap;
текст в рамке. Карточки в ScrollContainer (как все economy-экраны) — при узком вьюпорте
безопасный скролл вместо обрезки.

## ЭТАП 2 — генерация рамки

Рамка `upgrade_panel` 1720×730 сгенерирована детерминированным `tools/build_ui_2k_frame_kit.py`
(SCRUM-485) — 9-slice-safe, РОВНО в пиксельный размер слота @2K с нативными бордюрами
(panel-профиль 38,52,38,48). Рендер-верификатор (`--verify`) зелёный: размер == ожидаемый,
9-slice валиден, углы стабильны на 1080p/2K/4K, центр чист, нет stray-островов.

Карточки выбора оставлены на общем economy-choice-арте (как остальные economy-экраны,
кроме события, у которого свой evt_card) — единый стиль, без дубля идентичного PNG.

Ассет: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_upgrade_panel.png`.

## Подключение в рантайм

- `ui_theme_paths.gd`: `upgrade_panel` в `OVERHAUL_2K_FRAME_PATHS`/`_SOURCE_SIZE`/`_TEXTURE_MARGINS`/`_CONTENT`.
- `ui_screens.gd`: новый `_upgrade_panel_2k_style()` (как `_event_panel_2k_style`);
  `_show_upgrade_screen` передаёт его override-аргументом в `_create_menu_box(..., "upgrade", _upgrade_panel_2k_style())`.

## Тесты (green-gate)

- `tests/ui_no_overlap_matrix_test.gd` — PASS (upgrade_economy без overflow/overlap @1080p/2K/4K).
- `tests/runtime_smoke_test.gd` — PASS (экран улучшения строится, выбор применяется).
