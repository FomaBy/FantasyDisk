# UI Mockup Spec - Stat Tooltip 2K

Status: ready_for_integration
Role owner: Design
Task: docs/tasks/design_scrum586_stat_tooltip_2k_redesign_task.md
Jira: SCRUM-586
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: docs/design/mockups/scrum586_stat_tooltip/mockup_2k.png
Preview PNG: docs/design/previews/scrum586_stat_tooltip_contact.png
Generated with: OpenAI Images API via fantasydisk-asset-generator, then deterministic alpha/size cleanup

## Source Request

Redesign the transient stat tooltip (`StatTooltipPanel`) for the 2K UI overhaul.
The tooltip stays compact, follows the stat row/cursor, uses a fixed 430 px
design width, auto height, and keeps all runtime text inside the frame's empty
content zone.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| stat_tooltip_panel | PanelContainer | custom stat tooltip text | dynamic x/y, 430 x auto | cursor/slot, clamped by Godot tooltip flow | 430 x 288 source frame | 100 | default | stat_tooltip_frame |
| stat_tooltip_label | Label | name, value, description, formula, influences | inset 44,42,44,42 inside panel | fill safe rect | 342 px text width | 101 | autowrap | stat_tooltip_panel |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| stat_tooltip_frame | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png | 430x288 | 32,32,32,32 | 44,42,44,42 | outer dragon-scale corners, ruby pins, gold rails, top/bottom center gems | yes, tile/expand flat center only |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| stat_tooltip_source | docs/design/references/scrum586_stat_tooltip/stat_tooltip_frame_source.png | OpenAI source reference | 1536x1024 | RGB source | n/a | n/a | No baked text/icons. |
| stat_tooltip_candidate | docs/design/references/scrum586_stat_tooltip/ui_frame_2k_stat_tooltip_candidate.png | design candidate copy | 430x288 | RGBA, edge alpha 0 | 32,32,32,32 | 44,42,44,42 | Same pixels as runtime candidate. |
| stat_tooltip_runtime_candidate | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png | Back-end integration input | 430x288 | RGBA, edge alpha 0 | 32,32,32,32 | 44,42,44,42 | Back-end must wire path/metadata. |

## Responsive Rules

- 1920x1080: uniform scale 0.75 from 2K canvas; tooltip display width 322.5 px; label safe width 256.5 px.
- 2560x1440: source size; tooltip width 430 px; label safe width 342 px.
- 3840x2160: uniform scale 1.5; tooltip display width 645 px; label safe width 513 px.
- Non-16:9 windows keep the same canvas positions under stretch keep; Godot tooltip clamp keeps panel inside viewport.
- Auto-height must stretch only the flat center. Border ornaments, ruby pins, and corner scale texture must not be stretched over runtime text.

## Interaction States

- Hover/default: this is a passive tooltip; no pressed state.
- Disabled/empty: no special art state; hide tooltip if text is empty.
- Long text: wrap inside the label safe width and grow panel height; do not reduce content margins.

## Implementation Notes

- Godot scene/script: `scripts/pause_stats_menu.gd::_make_custom_tooltip`.
- Theme registration: `scripts/ui/ui_theme_paths.gd`, not hardcoded in the builder.
- Recommended constants/metadata: source size `Vector2(430, 288)`, texture margins `Vector4(32, 32, 32, 32)`, content margins `Vector4(44, 42, 44, 42)`, content rect `Rect2(44, 42, 342, 204)`.
- Replace the old single `ST_LABEL_INSET_2K = 20` behavior with equivalent horizontal/vertical content padding for this asset. A single 44 px inset is acceptable only if vertical padding remains at least 42 px.
- Preserve `TOOLTIP_MAX_WIDTH = 430` unless Back-end confirms a broader tooltip still passes the 1080p/2K/4K matrix.

## Acceptance Checks

- [x] Mockup/source generated through OpenAI Images API.
- [x] Preview generated for chat/reporting.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] No UI content overlaps frame border, ornament, gem, metal, or decorative corner in the spec.
- [x] Runtime content fit estimated for responsive targets.
- [x] Hover/focus/pressed/disabled states do not resize or shift layout.
- [ ] Screenshot comparison completed after Back-end implementation.
- [x] Task/Jira updated; Back-end handoff created as SCRUM-593.

## Deviations

Jira description names `scripts/ui_screens.gd`, but the current inventory and
runtime code place `StatTooltipPanel` / `_make_custom_tooltip` in
`scripts/pause_stats_menu.gd`. The Back-end handoff targets the actual runtime
file.
