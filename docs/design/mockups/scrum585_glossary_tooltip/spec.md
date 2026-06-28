# UI Mockup Spec - Glossary Tooltip

Status: implemented
Role owner: Design
Task: docs/tasks/SCRUM-585_glossary_tooltip_redesign.md
Jira: SCRUM-585
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: `docs/design/mockups/scrum585_glossary_tooltip/mockup.png`
Preview PNG: `docs/design/previews/scrum585_glossary_tooltip_safe_zone.png`
Generated with: OpenAI Images API via fantasydisk-ui-director / fantasydisk-asset-generator

## Source Request

Redesign the transient glossary tooltip `GlossaryTooltipPanel` as an isolated
2K UI element. The tooltip has fixed width, content-driven height, and must stay
inside the viewport safe zone. It uses runtime text, so generated art must not
bake labels or copy into the frame.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| glossary_anchor | Existing Control | glossary term button/link | dynamic | source control | source control | existing | hover/Alt-hover | n/a |
| glossary_tooltip | PanelContainer | title + description | dynamic x/y, 460w, auto h; template 460x140 | top-left near anchor, clamped | 460x140 template | 200 | visible/hidden | viewport |
| glossary_title | Label | term display name | inside frame safe zone | top-left | 328x24 | 210 | normal | glossary_tooltip_frame |
| glossary_desc | Label | wrapped description | below title, inside frame safe zone | top-left | 328x56 | 210 | normal | glossary_tooltip_frame |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| glossary_tooltip_frame | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png` | 460x140 | L46 T30 R46 B28 | L66 T44 R66 B40 | outer metal border, corner claws, ruby/gold pins, top/bottom rails | yes |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gt_mockup | `docs/design/mockups/scrum585_glossary_tooltip/mockup.png` | OpenAI mockup/source board for the tooltip | 2560x1440 | opaque mockup | n/a | marked visually | Shows empty internal content zone and border separation |
| gt_frame_source | `docs/design/references/scrum585_glossary_tooltip/scrum585_glossary_tooltip_frame_source.png` | high-res source for cleanup | 1776x592 | RGB source | source-scaled from 46/30/46/28 | source-scaled from 66/44/66/40 | Generated after metrics approval |
| gt_frame_alpha | `docs/design/references/scrum585_glossary_tooltip/scrum585_glossary_tooltip_frame_alpha.png` | alpha-cleaned source | 1776x592 | transparent RGBA | source-scaled from 46/30/46/28 | source-scaled from 66/44/66/40 | Preserves opaque dark center and transparent outside |
| gt_frame_runtime | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png` | runtime 9-slice frame | 460x140 | transparent RGBA | L46 T30 R46 B28 | L66 T44 R66 B40 | Replaces prior GT panel only |

## Responsive Rules

- 1920x1080: UI scale 0.75 from 2K; tooltip display remains `460xauto` logical px in runtime, clamped to viewport with 16px margin.
- 2560x1440: base target; tooltip width is 460px, template height 140px, content area `328x56+` after title/separation.
- 3840x2160: UI scale 1.5 from 2K; verifier checks viewport containment and no `STRETCH_SCALE` on frame texture.
- Positioning: initial position = anchor global position + `(0, anchor_height + 8)`, then clamp x/y to `[16, viewport - tooltip_size - 16]`.
- Text fit: title uses 16px; description uses 13px autowrap. Long glossary descriptions wrap inside `328px` content width; height grows by content, never by stretching ornaments outside the 9-slice center.

## Interaction States

- Visible: hover on normal glossary term or Alt+hover in popup contexts.
- Hidden: mouse exit or explicit `_hide_glossary_tooltip()`.
- Hover/focus/pressed: no separate visual state; tooltip is read-only and ignores mouse input.
- Disabled/loading: not applicable.

## Implementation Notes

- Godot entry point: `scripts/ui_screens.gd::_show_glossary_tooltip`.
- Theme constants: `scripts/ui/ui_theme_paths.gd::OVERHAUL_2K_FRAME_*["gt_panel"]`.
- Use `StyleBoxTexture` via `_overhaul_2k_frame_style("gt_panel", GT_PANEL_2K.size)`; no `TextureRect STRETCH_SCALE`.
- Runtime labels live inside the frame's content margins; no text is baked into generated assets.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content overlaps frame border, ornament, gem, metal, or decorative corner by spec.
- [x] Runtime content fits inside safe zones at every responsive target by fixed width + autowrap + auto height.
- [x] Hover/focus/pressed/disabled states do not resize or shift layout.
- [x] Screenshot/comparison or validator completed after implementation.
- [x] Task/Jira updated when applicable.

## Deviations

The OpenAI mockup depicts the tooltip larger than its runtime 460x140 logical
slot for readability. The runtime asset follows the exact 460x140 slot and
safe-zone metrics above.
