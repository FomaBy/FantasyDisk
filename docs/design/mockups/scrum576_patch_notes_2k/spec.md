# SCRUM-576 — UI-редизайн «Что нового / патч-ноуты» @2K (2560×1440)

Эпик: SCRUM-481 (UI Overhaul 2K). Экран: **Что нового / патч-ноуты** · нода
`PatchNotesScreen` · вход `_show_patch_notes_screen` (`scripts/ui_screens.gd`).
База 2560×1440, `stretch=canvas_items`, `aspect=keep`. Это последний экран блока
(инвентарь отмечал патч-ноуты как незакрытый).

## ЭТАП 1 — раскладка / метрики (код-константы)

До редизайна экран был «голым»: хедер + скролл буллетов прямо на codex-фоне, без
рамки. Новые `PN_*_2K`-константы закреплены в `scripts/ui_screens.gd` (блок «#17»):

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Панель (фрейм, full-screen) | `PN_PANEL_2K` | 48 | 26 | 2464 | 1388 |
| Safe-area (layout-VBox) | `PN_SAFE_2K` | 136 | 118 | 2288 | 1214 |
| Хедер (title EXPAND + back) | `PN_HEADER_2K` | 136 | 118 | 2288 | 104 |
| Заголовок «Что нового» (38px) | `PN_TITLE_2K` | 136 | 118 | 1900 | 104 |
| Кнопка «Назад в меню» | `PN_BACK_2K` | 2164 | 118 | 260 | 104 |
| Скролл версий/буллетов | `PN_SCROLL_2K` | 136 | 234 | 2288 | 1098 |

Геометрия панели идентична skill-tree main (самый плотный полноэкранный фрейм).
Раскладка: хедер сверху (заголовок EXPAND + «Назад в меню» справа), вертикальный
`ScrollContainer` версий (новейшая первой) с буллетами под хедером. Длинные истории
версий уходят в вертикальный скролл — рамка НЕ растягивается, текст авто-wrap внутри
content-зоны.

**Инварианты (верификатор):** ничего не вылазит за экран; хедер/скролл не наслаиваются;
текст в content-зоне рамки (58/72/58/66 source→display); ассет 9-slice-safe.

## ЭТАП 2 — генерация ассета

Пайплайн эпика `tools/build_ui_2k_frame_kit.py` (детерминированный, дарк-фэнтези
bright-минимал, 9-slice-валидный, верификатор PASS 1080p/2K/4K):

| slug | ассет | размер | 9-slice margins | content inset |
|---|---|---|---|---|
| `pn_panel` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_pn_panel.png` | 2464×1388 | 38/52/38/48 | 58/72/58/66 |

## Интеграция в рантайм

- `scripts/ui/ui_theme_paths.gd`: `pn_panel` добавлен в `OVERHAUL_2K_FRAME_PATHS` /
  `_SOURCE_SIZE` / `_TEXTURE_MARGINS` / `_CONTENT`.
- `scripts/ui_screens.gd` `_show_patch_notes_screen`: контент обёрнут в `PatchNotesPanel`
  (`PanelContainer`, anchored full-rect с offset PN_PANEL_2K), фрейм через
  `_overhaul_2k_frame_style("pn_panel", PN_PANEL_2K.size)`; хедер (title+back) и скролл
  версий — внутри content-зоны панели. Семантика data-driven патч-ноутов сохранена.

## Тесты (green-gate)

- `tests/ui_no_overlap_matrix_test.gd` — PASS (patch_notes: PatchNotesPanel=pn_panel,
  PatchNotesBackButton в рамке; no-overlap/text-containment на всех VIEWPORT_SIZES).
- `tests/runtime_smoke_test.gd` — PASS.
- `tests/display_resolution_test.gd` — PASS.
- `python3 tools/build_ui_2k_frame_kit.py --all` — VERDICT: PASS (pn_panel валиден).
