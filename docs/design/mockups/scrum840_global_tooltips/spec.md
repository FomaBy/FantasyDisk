# UI Mockup Spec - Global Tooltips

Status: implemented
Role owner: Back-end
Jira: SCRUM-840
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: reused existing accepted tooltip/frame assets; no new bitmap generated per task instruction.
Generated with: existing FantasyDisk runtime frame kits, no new art.

## Source Request

Global hover tooltips must use an opaque framed dark-fantasy panel, keep readable wrapped text, stay offset from the cursor or anchor, clamp to the viewport, flip away from the anchor when space allows, and ignore mouse input so they do not cause hover flicker.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| global_tooltip | PanelContainer | `tooltip_text` for buttons, chips, HUD controls, shop/reward/level-up/settings/atlas controls | width 460, height content-driven | cursor/anchor side, viewport clamped | 460xcontent | tooltip overlay | hover/focus tooltip | minimal_metal_tooltip |
| glossary_tooltip | PanelContainer | glossary title and description | width 460, height content-driven | term button side, viewport clamped | 460xcontent | tooltip overlay | hover/focus tooltip | gt_panel |
| stat_tooltip | PanelContainer | pause dossier stat details | width 430, height content-driven | Godot tooltip cursor placement with global framed content | 430xcontent | tooltip overlay | hover/focus tooltip | stat_tooltip |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| minimal_metal_tooltip | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png` | 760x242 | 46/30/46/28 | 66/44/66/40 | metal rails, corners, bevels | yes |
| gt_panel | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png` | 460x140 | 46/30/46/28 | 66/44/66/40 | ruby pins, claws, metal rails | yes |
| stat_tooltip | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png` | 430x288 | 32/32/32/32 | 44/42/44/42 | metal edge and corner ornament | yes |

## Responsive Rules

- Tooltip max width is fixed to 460px for global/glossary surfaces and 430px for pause stat details.
- Text uses smart word wrap inside the documented content margins.
- Tooltip panels use at least 16px viewport margin and 18px anchor/cursor gap.
- Placement tries the side away from the anchor first, flips to the opposite side when needed, then below/above, and finally clamps to the viewport.
- Tooltip controls and their labels use `MOUSE_FILTER_IGNORE`.

## Implementation Notes

- `scripts/ui/global_tooltip.gd` builds framed tooltip panels, inherited `TooltipPanel` theme, and shared placement.
- `scripts/ui/global_tooltip_control.gd` supplies `_make_custom_tooltip()` for generic controls that only have `tooltip_text`.
- `scripts/ui_screens.gd` installs the global tooltip skin on major UI roots and keeps glossary tooltip on the accepted 2K `gt_panel`.
- `scripts/pause_stats_menu.gd` keeps stat tooltips on the accepted 2K `stat_tooltip` frame while using the shared builder.

## Acceptance Checks

- [x] Existing accepted frames reused; no new bitmap assets generated.
- [x] All tooltip content stays inside frame safe zones.
- [x] Tooltip panels ignore mouse input.
- [x] Glossary tooltip avoids overlapping its anchor when space exists.
- [x] Generic `tooltip_text` controls receive the global framed skin.
- [x] Runtime smoke covers generic, glossary, and pause stat tooltip paths.

## Deviations

No PixelLab mockup PNG was generated because SCRUM-840 explicitly requests no new bitmap/frame assets and only behavior/style reuse of existing tooltip frame styles.
