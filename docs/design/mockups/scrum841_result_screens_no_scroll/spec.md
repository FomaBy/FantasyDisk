# SCRUM-841 Result Screens No-Scroll Spec

Updated: 2026-07-03

## Goal

Victory and defeat result screens must show the required run outcome text,
run-summary rows, decorative crest, and primary action without a scrollbar at
1152x648, 1280x720, 1920x1080, 2560x1440, and 3840x2160. Content must stay inside
the frame safe-zone and never cover the decorative border.

## Reference

- PixelLab UI reference job: `d53f1789-4586-423d-90e6-8006dc92aacb` failed
  externally with `Generation stalled and was automatically failed`.
- PixelLab retry job: `7ae80417-b175-41c0-bb79-34c87e84dc28`.
- Runtime assets: existing victory minimal-metal modal, death `result_panel`,
  existing `ui_crest_victory.png` / `ui_crest_defeat.png`, existing text-button
  family. No new runtime bitmap asset is required for this backend layout fix.

## Runtime Layout

`_create_menu_box()` still owns pause/economy/menu boxes. Victory and death use
`_create_result_menu_box()` so result content cannot expand the modal through
`VBoxContainer` minimum sizes. For `screen_background_id in ["victory", "death"]`,
the result builder does not create `PauseEndModalScroll_*`. Instead:

- `PauseEndModalPanel_*` exposes `pause_end_display_size`,
  `pause_end_content_margins`, and `pause_end_content_rect` metadata.
- `ResultContent_*` is the direct panel child and fills the scaled safe-zone.
- `MenuTitle_*` and `MenuSubtitle_*` occupy the top safe-zone.
- `ResultBody_*` splits the middle into `ResultCrestSlot_*` and
  `RunSummaryColumn_*`.
- `RunSummaryColumn_*` contains `RunSummaryOutcome`, `RunSummaryStats`, and the
  optional compact artifact-name line.
- `VictoryNewRunButton` / `DeathRetryButton` stay as bottom children of
  `ResultContent_*`, so they remain visible and focusable without scrolling.

## 2K Coordinates

At 2560x1440 the shared result panel is `Rect2(831,310,898,820)` and the safe-zone
is `Rect2(898,396,764,656)`.

| Slot | Rect |
| --- | --- |
| Title | `Rect2(898,396,764,42)` |
| Subtitle | `Rect2(898,448,764,128)` |
| Body | `Rect2(898,586,764,352)` |
| Crest | `Rect2(899,678,168,168)` |
| Summary column | `Rect2(1086,586,576,352)` |
| Primary button | `Rect2(1070,948,420,104)` |

Short-height layouts use the same structure with smaller title/subtitle/run-summary
font sizes, smaller crest, and 72px result button height.

## QA Contract

- `tests/ui_no_overlap_matrix_test.gd` checks victory/death across 1152x648,
  1280x720, 1536x864, 1600x900, 1920x1080, 2560x1440, and 3840x2160.
- The matrix fails if `PauseEndModalScroll_victory` or
  `PauseEndModalScroll_death` exists.
- The matrix and runtime smoke verify result content, summary, and action buttons
  stay inside `pause_end_content_rect`.
- `tests/runtime_smoke_test.gd` keeps the existing victory/death frame assertions
  and adds no-scroll/safe-zone assertions for the result action and summary.
