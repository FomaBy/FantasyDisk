# SCRUM-584 Rebind Conflict Dialog 2K Spec

Status: implemented
Role owner: Design/UI
Task: docs/tasks/design_scrum584_rebind_conflict_ui_2k_task.md
Jira: SCRUM-584
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 3840x2160
Generated with: OpenAI Images API via fantasydisk-asset-generator

## Source Request

Redesign the settings key-rebind conflict modal as a 2K-first FantasyDisk UI
surface. Runtime labels, hit areas, and focus rings must stay inside the empty
content zone and never overlap dragon/metal/ruby ornament.

## Generated Assets

| Asset ID | Path | Purpose | Size | Notes |
| --- | --- | --- | --- | --- |
| rejected_text_mockup | docs/design/references/scrum584_rebind_conflict_2k/rebind_conflict_2k_mockup_reference.png | First API attempt | 2560x1440 | Rejected for task evidence because the model baked readable English text into the background. |
| rebind_conflict_mockup | docs/design/references/scrum584_rebind_conflict_2k/rebind_conflict_2k_mockup_reference_v2.png | Accepted OpenAI style/mockup reference | 2560x1440 | No readable text/labels; used as visual direction. |
| safe_zone_preview | docs/design/previews/scrum584_rebind_conflict_2k_safe_zones.png | QA overlay | 2560x1440 | Shows exact runtime zones from this spec. |
| ui_frame_2k_rc_panel | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_panel.png | Runtime modal frame | 680x380 | Built by `tools/build_ui_2k_frame_kit.py --all`, 9-slice-safe. |
| ui_frame_2k_rc_btn | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_btn.png | Runtime conflict action buttons | 240x72 | Built by the same slot-exact pipeline. |

## Screen Elements

| ID | Type | Runtime content | Rect @2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RebindConflictDialog | Control | blocking overlay | 0,0,2560,1440 | full rect | viewport | 520 | visible | n/a |
| RebindConflictPanel | PanelContainer | modal shell | 940,530,680,380 | centered | 680x380 | 10 | normal/focus descendants | root |
| RebindConflictTitle | Label | localized title | 998,614,564,44 | panel safe zone | 564x44 | 20 | normal | rc_panel |
| RebindConflictMessage | Label | localized conflict copy | 998,674,564,66 | panel safe zone | 564x66 | 20 | wrapped | rc_panel |
| RebindConflictRetryButton | Button | choose another key | 1031,758,240,72 | panel safe zone | 240x72 | 30 | normal/hover/focus/pressed | rc_panel |
| RebindConflictBackButton | Button | back to settings | 1289,758,240,72 | panel safe zone | 240x72 | 30 | normal/hover/focus/pressed | rc_panel |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| rc_panel | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_panel.png | 680x380 | 38,52,38,48 | 58,72,58,66 | all outer rails, corners, ruby pins, bevel highlights | yes |
| rc_btn | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_btn.png | 240x72 | 50,28,50,28 | 34,8,34,8 | end caps, bevel, corner ticks | yes |

Panel local safe rect: `Rect2(58, 72, 564, 242)`. The title, message, and both
buttons must fit inside this rect after uniform viewport scaling.

## Responsive Rules

- 1280x720: centered panel scales to 340x190; button labels stay in the internal
  safe band and use the existing action-button font behavior.
- 1920x1080: centered panel scales to 510x285; no content may touch frame rails.
- 2560x1440: use the base rectangles above.
- 3840x2160: centered panel scales to 1020x570; 9-slice center stretches while
  corners/ornaments remain crisp.

## Implementation Notes

- Runtime entry: `scripts/ui_screens.gd::_show_rebind_conflict`.
- Theme registration: `scripts/ui/ui_theme_paths.gd` keys `rc_panel` and `rc_btn`.
- Asset builder: `tools/build_ui_2k_frame_kit.py --all`.
- Verifier: `tests/ui_no_overlap_matrix_test.gd` opens the modal and checks
  required nodes, frame paths, metadata, and scaled safe-zone containment.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview/safe-zone evidence exists.
- [x] Runtime has dedicated SCRUM-584 `rc_panel` and `rc_btn` assets.
- [x] Runtime content and hit areas stay inside `Rect2(58,72,564,242)`.
- [x] `tools/build_ui_2k_frame_kit.py --all` passes.
- [x] UI no-overlap and display tests pass on Windows direct Godot console.

## Deviations

OpenAI image generation is used as the visual direction source, but exact pixel
geometry is enforced by the Godot `RC_*_2K` constants and verifier. The accepted
mockup is intentionally textless; runtime labels remain localized Godot text.
