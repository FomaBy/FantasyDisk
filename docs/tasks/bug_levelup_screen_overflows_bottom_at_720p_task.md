# BUG/UI: Level Up screen cards overflow below the viewport at 720p

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-17
Автор: QA/Design review SCRUM-458
Jira: SCRUM-465
QA: in_progress (2026-06-17)
Связано: SCRUM-348, SCRUM-402, SCRUM-458

## Контекст
During the final SCRUM-458 design review, the Level Up choice screen does not fit
vertically on smaller/laptop layouts. At 1280x720 the reward cards extend below
the screenshot bottom; at 1920x1080 the lower return button is partly off-screen.
This leaves reward descriptions/actions unreadable or unreachable.

Evidence:
- `build/qa/design_review/level_up_1280x720.png`
- `build/qa/design_review/level_up_1920x1080.png`
- Contact sheets: `build/qa/design_review/contact_1280x720.jpg`,
  `build/qa/design_review/contact_1920x1080.jpg`

## Problem
- 1280x720: the three reward cards are positioned too low and are cut by the
  bottom viewport edge; only the upper/middle content is visible.
- 1920x1080: reward cards are visible, but the bottom "Позже" return button is
  partially cropped below the viewport.
- The issue remains after the SCRUM-458 screenshot harness waits for the Level Up
  intro animation to settle.

## Expected
- Level Up panel, hero portrait, title/subtitle, three reward cards and "Позже"
  control fit fully inside the viewport at 1280x720, 1920x1080 and 2560x1440.
- Reward card text remains inside card safe zones; no content overlaps frame
  ornaments or is clipped by the viewport.
- Existing gameplay semantics are preserved: three choices, one pick per level,
  Escape/"Позже" defers without spending the pick.

## Scope / Ownership
- Back-end UI only: adjust Level Up panel sizing, scaling, vertical spacing and/or
  responsive card heights in `scripts/ui_screens.gd`.
- Do not change reward generation, balance, player stats or progression data.

## Acceptance Criteria
- [x] Level Up screenshot at 1280x720 shows all three cards and the return button
  fully inside the viewport.
- [x] Level Up screenshots at 1920x1080 and 2560x1440 have no bottom cropping.
- [x] Text remains readable and inside safe zones.
- [x] `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd` and
  `tests/runtime_smoke_test.gd` pass.
- [x] QA screenshots added under `build/qa/` and linked in the result.

## Result
Back-end fixed the Level Up overlay as a viewport-aware layout in
`scripts/ui_screens.gd`: panel/card sizes, hero header, card spacing, compact
font/icon sizing and the `Позже` button height now adapt to short 720p-style
viewports while preserving the existing 3-choice/defer/Escape semantics and
text-field card visuals. `tests/ui_no_overlap_matrix_test.gd` now opens Level Up
as a first-class matrix screen and asserts `LevelUpPanel`, `LevelUpHeroHeader`,
all three reward cards and `LevelUpLaterButton` stay inside the viewport.

QA evidence:
- `build/qa/scrum465/level_up_1280x720.png`
- `build/qa/scrum465/level_up_1920x1080.png`
- `build/qa/scrum465/level_up_2560x1440.png`
- `build/qa/scrum465/ui_no_overlap_matrix.md`
- `build/qa/scrum465/manifest.md`

Verification:
- PASS: `tests/ui_no_overlap_matrix_test.gd`
- PASS: `tests/runtime_smoke_ui_test.gd`
- PASS: `tests/runtime_smoke_test.gd`

Note: the full design-review screenshot harness emitted the Level Up PNGs, then
exited non-zero in this headless run on unrelated dummy-renderer viewport image
reads for other screens. The Level Up screenshots were copied to `build/qa/scrum465/`
and the matrix/smoke gates above are the blocking runtime acceptance checks.

## QA-Вердикт (2026-06-17)
Статус: PASSED — Level Up больше НЕ переполняет низ при 720p
Проверено: `ui_no_overlap_matrix` теперь открывает Level Up как matrix-экран и ассертит
LevelUpPanel/HeroHeader/3 карточки/LaterButton внутри вьюпорта — **levelup НЕ в списке
overflow** (2 оставшихся — settings+attribute_shop, другие экраны). Viewport-aware layout в
`ui_screens.gd` адаптирует размеры/шрифты на коротких вьюпортах. Скрины 1280×720/1920×1080. done → Готово.
