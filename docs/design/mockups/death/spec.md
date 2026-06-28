# Mockup-спека — Смерть (SCRUM-578, эпик SCRUM-481 UI Overhaul 2K)

База **2560×1440**, `stretch=canvas_items`, `aspect=keep`. Редизайн экрана «Поражение»
(`_show_death_screen`, end-модалка результата "death"): per-слот @2K-рамка панели вместо
общего `PAUSE_END_MODAL_PATH` (minimal_metal modal), который ужимался под слот и мылил орнамент.
Стиль — единый bright-минимал amber dark-fantasy.

## ЭТАП 1 — раскладка / метрики @2560×1440

Координаты зафиксированы код-константами `RESULT_*_2K` (SCRUM-489) — победа и смерть имеют
**идентичную** геометрию end-модалки (`_pause_end_modal_display_size("death")` → 898×820).
Редизайн их НЕ меняет — только подменяет рамку для пути смерти.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель модалки (фрейм) | `RESULT_PANEL_2K` | 831 | 310 | 898 | 820 |
| Safe-area | `RESULT_SAFE_2K` | 898 | 396 | 764 | 656 |
| Эмблема-кольцо (crest) | `RESULT_CREST_2K` | 1192 | 401 | 176 | 176 |
| Заголовок «Поражение» | `RESULT_TITLE_2K` | 898 | 589 | 764 | 54 |
| Подзаголовок (autowrap) | `RESULT_SUBTITLE_2K` | 898 | 655 | 764 | 220 |
| Кнопка «Начать заново» | `DS_BTN_RETRY_2K` | 1070 | 948 | 420 | 104 |

**Инварианты (проверены `ui_no_overlap_matrix_test`, секция death на 1080p/2K/4K):**
crest → заголовок → подзаголовок → сводка прогона (SCRUM-502) → кнопка — в ScrollContainer
внутри safe-area, длинный текст уходит в скролл, без overflow/overlap, текст в рамке.

## ЭТАП 2 — генерация рамки

Рамка `result_panel` 898×820 сгенерирована детерминированным `tools/build_ui_2k_frame_kit.py`
(SCRUM-485) — 9-slice-safe, РОВНО в пиксельный размер слота @2K с нативными бордюрами
(modal-профиль 46,62,46,58). Рендер-верификатор (`--verify`) зелёный: размер == ожидаемый,
9-slice валиден, углы стабильны на 1080p/2K/4K, центр чист, нет stray-островов.

Ассет: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_result_panel.png`.

## Подключение в рантайм

- `ui_theme_paths.gd`: `result_panel` в `OVERHAUL_2K_FRAME_PATHS`/`_SOURCE_SIZE`/`_TEXTURE_MARGINS`/`_CONTENT`.
- `ui_screens.gd`: `_pause_end_modal_style(display_size, screen_background_id)` — для
  `screen_background_id == "death"` отдаёт `_overhaul_2k_frame_style("result_panel", display_size)`,
  иначе старый `PAUSE_END_MODAL_PATH`. Победа/пауза не тронуты (их таски отдельно — общая
  геометрия позволит переключить их тем же ассетом позже без новой генерации).
- `_create_menu_box` прокидывает `screen_background_id` в стиль end-модалки.

## Тесты (green-gate)

- `tests/runtime_smoke_test.gd` — PASS (death-ассерт текстуры обновлён SCRUM-448→SCRUM-578;
  victory-ассерт НЕ тронут — путь победы по-прежнему MINIMAL_MODAL).
- `tests/ui_no_overlap_matrix_test.gd` — PASS (death без overflow/overlap @1080p/2K/4K).
