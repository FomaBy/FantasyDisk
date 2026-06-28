# UI Mockup Spec - Feedback Form 2K

Status: implemented
Role owner: Design
Task: docs/tasks/SCRUM-583_feedback_form_2k_task.md
Jira: SCRUM-583
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: docs/design/references/scrum583_feedback_form_2k/feedback_form_2k_mockup.png
Preview PNG: docs/design/previews/scrum583_feedback_form_2k_safe_zones.png
Generated with: OpenAI Images API via skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py

## Source Request

Redesign the Feedback overlay for the 2K UI overhaul. The screen uses `FeedbackOverlay` / `FeedbackPanel` from `scripts/ui_screens.gd::_show_feedback_overlay` and must keep the message field, screenshot preview, status line, send button, and cancel button inside the panel safe zone.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| feedback_dim | ColorRect | dimmed gameplay | 0,0,2560,1440 | full rect | viewport | 0 | normal | none |
| feedback_panel | PanelContainer | modal shell | 810,330,940,780 | center | 480x380, max 940x780 | 10 | normal | screen |
| feedback_title | Label | screen title | 868,402,824,42 | panel top | 824x42 | 20 | normal | feedback_panel |
| feedback_scroll | ScrollContainer | middle content | 868,454,824,470 | panel middle | 824x300 | 20 | scroll | feedback_panel |
| feedback_textedit | TextEdit | player report text | 868,508,824,130 | scroll top | 824x130 | 30 | focus | feedback_scroll |
| feedback_screenshot | TextureRect | captured screenshot | 868,648,824,240 | scroll middle | 824x240 | 30 | empty/image | feedback_scroll |
| feedback_status | Label | send status | 868,934,824,36 | panel lower | 824x36 | 20 | idle/sending/success/error | feedback_panel |
| feedback_send | Button | send command | 1031,980,260,64 | bottom center | 260x64 | 30 | normal/hover/focus/pressed/disabled | feedback_panel |
| feedback_cancel | Button | close command | 1309,980,220,64 | bottom center | 220x64 | 30 | normal/hover/focus/pressed/disabled | feedback_panel |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| fb_panel | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_fb_panel.png | 940x780 | 38,52,38,48 | 58,72,58,66 | outer metal rail, brass line, corner pins | yes |
| fb_btn_send | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_fb_btn_send.png | 260x64 | 50,28,50,28 | 50,28,50,28 | caps and bevels | yes |
| fb_btn_cancel | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_fb_btn_cancel.png | 220x64 | 50,28,50,28 | 50,28,50,28 | caps and bevels | yes |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| scrum583_feedback_mockup | docs/design/references/scrum583_feedback_form_2k/feedback_form_2k_mockup.png | OpenAI page mockup/reference | 2560x1440 | opaque reference | n/a | FB_SAFE_2K shown in prompt | Not runtime art |
| scrum583_feedback_safe_zones | docs/design/previews/scrum583_feedback_form_2k_safe_zones.png | annotated QA preview | 2560x1440 | overlay preview | n/a | exact `FB_*` rects | Evidence only |

## Responsive Rules

- 1920x1080: Godot `stretch=canvas_items/keep` scales the 2K canvas uniformly to 0.75. Panel renders as 705x585, centered; content remains within scaled `FB_SAFE_2K`.
- 2560x1440: native 2K rects are exact. Runtime panel max is 940x780 and maps 1:1 to `fb_panel`.
- 3840x2160: uniform 1.5 scale from 2K. No frame uses `TextureRect.STRETCH_SCALE`; panel and buttons are `StyleBoxTexture` 9-slice assets.

## Interaction States

- Button hover/focus: use `BUTTON_NEUTRAL_HOVER_TINT` through `_apply_overhaul_2k_button_theme`.
- Button pressed: uses the same `fb_btn_*` source with pressed tint; size does not change.
- Disabled send state: send button remains 260x64 and uses disabled tint while submission is pending.
- Empty/loading: screenshot preview keeps a 240px content block even when the source screenshot is normalized fallback.

## Implementation Notes

- Godot script: `scripts/ui_screens.gd`.
- Runtime path registry: `scripts/ui/ui_theme_paths.gd::OVERHAUL_2K_FRAME_*`.
- `_show_feedback_overlay` uses `_overhaul_2k_frame_style("fb_panel", Vector2(panel_width, panel_height))` for the panel and `_apply_overhaul_2k_button_theme(..., "fb_btn_send"/"fb_btn_cancel", ...)` for action buttons.
- Runtime labels, text edit, screenshot preview, status, and buttons are children of `FeedbackPanel` and rely on `fb_panel` content margins, not the full frame bounds.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content overlaps frame border, ornament, gem, metal, or decorative corner.
- [x] Runtime content fits inside safe zones at every responsive target.
- [x] Hover/focus/pressed/disabled states do not resize or shift layout.
- [x] `tools/build_ui_2k_frame_kit.py --verify` passes for the 2K frame kit,
      including `fb_panel`, `fb_btn_send`, and `fb_btn_cancel`.
- [x] `tests/display_resolution_test.gd` passes.
- [x] `tests/runtime_smoke_ui_test.gd` exits 0 and reports `Runtime UI smoke suite passed`
      (Godot still logs unrelated missing import/resource warnings in this local tree).
- [ ] Full `tests/ui_no_overlap_matrix_test.gd` is blocked by pre-existing
      non-feedback failures on `PatchNotesPanel` / `AttributeShopPanel` frame
      expectations and missing local `.godot` import cache resources.
- [x] Task/Jira updated when applicable.

## Deviations

The OpenAI mockup is a visual/reference board, not the runtime atlas. Runtime keeps the exact existing 2K frame PNGs from `assets/sprites/ui/frames/overhaul_2k/` because they are deterministic, exact-size, verifier-compatible assets with registered margins.
