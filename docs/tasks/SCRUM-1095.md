# SCRUM-1095 — Main Menu visible Gratitude icon remains more than 20 px from version glyphs

Статус: done
Версия: 0.2.1
Jira: SCRUM-1095
Тип: bug
Контур: Codex
Роль: Back-end / UI
Найдено QA: SCRUM-1093
Owner: `/root/scrum1095_visible_icon_gap`

## Воспроизведение

1. Открыть Main Menu на 1280×720, 1920×1080, 2048×1152 и 2560×1440.
2. Измерить от rightmost non-transparent pixel Gratitude PNG после
   runtime scale до first visible version glyph.
3. Повторить с `application/config/version=0.2.10-beta` и live resize.

## Ожидание / реальность

Ожидание: actual visible alpha-to-glyph gap `0..20 px`.

Реальность: `33.75 / 37.47 / 37.47 / 42.91 px`; existing tests
показывают 18px, потому что меряют transparent Button hitbox.

## Acceptance

- actual alpha-bbox-to-glyph gap `0..20 px` во всей матрице + resize;
- future version полностью visible/dynamic;
- exact 8px frame-safe reserve и ornament safety сохранены;
- callback/focus/tooltip/accessibility/SFX не изменены;
- independent visible-gap oracle и full UI/runtime gates PASS.

QA evidence: `tests/scrum1093_independent_visible_gap_test.gd`.

## Result

- Accepted PixelLab object `c1c1c353-e56e-405b-9adf-f1e6bd993152` and runtime
  PNG bytes remain unchanged. `scripts/ui_screens.gd` now derives the real alpha
  bbox and assigns an `AtlasTexture` region `(41,48,160,160)` with accepted
  source alpha `(55,48,146,160)` shifted to crop alpha `(14,0,146,160)`.
- Glow-to-label rect gap is `2 px`; the unchanged Button hitbox is biased `3 px`
  toward the version but stays bounded by the glow. Gold-shell rail reserve is
  still exactly `8 px`; hitboxes remain disjoint.
- The exact independent QA oracle from `origin/dev d3e1bfd42` passes unchanged:
  `15/17/17/19 px` at 1280/1920/2048/2560 for `v0.2.10-beta`.
- Planning gates: six `ready_for_image`, zero errors/warnings; layout guides
  6/6 `ok=true`. Windowed Metal captures at six tiers and alpha measurements:
  `docs/design/previews/scrum1093_main_menu_version_corner/runtime/`.
- Callback, focus graph, tooltip/accessibility, UI SFX and bounded procedural
  glow are unchanged.

Verification PASS:

- `tests/scrum1093_independent_visible_gap_test.gd` (unchanged QA oracle)
- `tests/scrum1093_main_menu_version_corner_test.gd`
- `tests/scrum1059_main_menu_single_column_test.gd`
- `tests/scrum981_gold_menu_shell_test.gd`
- `tests/scrum1051_ui_button_family_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `tests/gamepad_menu_focus_test.gd`
- `tests/runtime_smoke_ui_test.gd`
- `tests/runtime_smoke_test.gd`
- windowed Metal `tools/capture_scrum1059_main_menu.gd`, six targets

Implementation commit: `fc6b9f48a` (rebased on QA evidence `d3e1bfd42`).

Disk cleanup: removed disposable `.godot`, fresh `build/qa/scrum1093` captures,
QA logs, isolated user-data and generated `.uid`/`.import` sidecars; disposable
worktree is removed after evidence push.

## QA-Вердикт (2026-07-12)

Статус: PASSED

Независимая приёмка на `origin/dev 53a9c547e` подтвердила fix
`fc6b9f48a`: принятый PixelLab PNG не изменён, alpha bbox не
обрезан, неизменённый oracle PASS `15/17/17/19 px`. Future SemVer,
live resize, exact `8 px` rail reserve, glow/button/version hitboxes,
focus/callback/tooltip/accessibility/SFX, focused/UI/gamepad/runtime и обязательные
regression gates PASS. Fresh Metal matrix визуально PASS без
clipping, oversized art и ornament overlap; lifecycle leaks нет.

Баги: нет. Jira: SCRUM-1095 → «Готово».
