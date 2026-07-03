# SCRUM-839 - Pause Dossier Readability Update

Status: implemented
Role owner: Back-end
Jira: SCRUM-839
Base resolution: 2560x1440, inherited from `docs/design/mockups/scrum580_pause_dossier_2k/spec.md`
Responsive targets: 1152x648, 1280x720, 1536x864, 1600x900, 1920x1080, 2560x1440, 3840x2160
Mockup/source spec: `docs/design/mockups/scrum580_pause_dossier_2k/spec.md`
Generated assets: none

## Source Request

Active-run Escape opens the character board, but base attributes and derived
stats were too small to read comfortably. Increase text, values, and icons while
preserving the accepted SCRUM-580/SCRUM-486 pause dossier frame kit, safe-zone,
scroll behavior, and no-overlap contract.

## Reused Geometry

This task does not redraw frames or bitmap UI art. It reuses the accepted pause
dossier @2K layout:

| Slot | Runtime node | Rect @ 2560x1440 | Notes |
| --- | --- | --- | --- |
| Panel frame | `EscapeStatsPanelFrame` | `Rect2(20, 18, 2520, 1404)` | Existing `pd_panel` StyleBoxTexture |
| Safe area | `PauseStatsSafeScroll` | `Rect2(135, 165, 2290, 1123)` | Content stays inside frame margins |
| Left controls/stats | `RunControls` | `Rect2(135, 165, 330, 1123)` | Runtime min width raised to 320/360 for readability |
| Right stats area | `DerivedStatsPanel` | `Rect2(483, 165, 1942, 1123)` | One column below 1800px viewport, two columns on desktop |

## Runtime Readability Contract

| Element | Minimum runtime sizing |
| --- | --- |
| Base stat row | `44px` minimum height |
| Base stat icon | `44px` rendered minimum via `UIIconRegistry` readable scaling |
| Base stat name/value | `17px` / `18px` minimum font sizes |
| Derived stat chip | `236x54px` minimum |
| Derived stat icon | `46px` rendered minimum via `UIIconRegistry` readable scaling |
| Derived stat name/value | `15px` / `17px` minimum font sizes |
| Derived group panel | `520px` minimum width before viewport scaling |

Long Russian stat names use clipping with ellipsis inside their containers.
Descriptions keep word wrapping. Runtime content remains in existing
StyleBoxTexture content margins and never sits on frame ornaments.

## Acceptance Checks

- `tests/ui_no_overlap_matrix_test.gd` validates PauseStats readability and
  no-overlap across the full UI matrix.
- `tests/runtime_smoke_test.gd` validates the active-combat Escape character
  board, frame kit, tooltips, icons, and SCRUM-839 readable row/chip contract.

## Deviations

No PixelLab generation was run for SCRUM-839 because the dispatcher explicitly
scoped the task to reuse the accepted SCRUM-580/SCRUM-486 mockup/spec and
existing frame/content zones. No new bitmap assets were created or edited.
