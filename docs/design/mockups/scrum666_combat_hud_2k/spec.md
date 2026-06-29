# UI Mockup Spec - SCRUM-666 Combat HUD 2K

Status: ready_for_integration
Role owner: Design
Task: docs/tasks/design_scrum666_combat_hud_redesign.md
Jira: SCRUM-666
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png
Preview PNG: docs/design/previews/scrum666_combat_hud_2k_ui_plan_guide.png
Generated with: OpenAI Images API via fantasydisk-asset-generator
Visual frame-zone audit: docs/design/mockups/scrum666_combat_hud_2k/visual_frame_zone_audit.md

## Source Request

Design/UI asset package for a clean essential-only 2K combat HUD: HP, XP,
money, ult charge, timer, ascension/elevation, and one bottom-right level-up
plus button. Do not touch runtime wiring files.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| resource_strip_frame | frame | HP/XP/money/ULT group | 40,84,1488,212 | top-left | 1080x150 | 20 | normal | n/a |
| hp_zone | text/meter | HP current/max | 150,140,300,58 | top-left | 180x40 | 30 | normal/low | resource_strip_frame |
| xp_zone | text/meter | XP percent | 520,140,260,58 | top-left | 160x40 | 30 | normal | resource_strip_frame |
| gold_zone | text/icon | money | 850,140,235,58 | top-left | 112x40 | 30 | normal | resource_strip_frame |
| ult_zone | text/meter | ult charge | 1138,140,296,58 | top-left | 190x40 | 30 | charging/ready | resource_strip_frame |
| timer_frame | frame | combat timer | 1592,82,424,218 | top-center | 300x150 | 20 | normal/boss hidden allowed | n/a |
| timer_zone | text | MM:SS | 1690,145,232,62 | top-center | 128x40 | 30 | normal | timer_frame |
| ascension_frame | badge | ascension/elevation | 2165,55,330,322 | top-center | 240x240 | 20 | hidden if zero | n/a |
| ascension_zone | text | A0..A5 or elevation | 2265,150,128,94 | center | 28x28 | 30 | normal | ascension_frame |
| level_button_frame | button cluster | level-up reopen plus and count | 2190,1010,366,428 | bottom-right | 260x300 | 40 | normal/hover/focus/pressed/disabled | n/a |
| level_button_zone | icon/text | plus symbol | 2308,1148,124,104 | center | 40x44 | 50 | normal/hover/focus/pressed | level_button_frame |
| level_badge_frame | badge | pending count | 2400,1036,132,132 | top-right within cluster | 92x92 | 60 | hidden if zero | level_button_frame |
| level_badge_zone | text | pending count | 2442,1079,48,40 | center | 16x18 | 70 | normal | level_badge_frame |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| resource_strip_frame | future slot asset | 1488x212 | use measured generated border; keep content in child zones only | exact child zones above | outer rails, center crest, corner plates, ruby pins | likely sliced per metric card, not full-stretch |
| timer_frame | future slot asset | 424x218 | use measured generated border | 98,63,94,93 | rails, corner rivets, ruby gems, bottom crest | likely sliced per timer frame |
| ascension_frame | future badge asset | 330x322 | whole-image badge; no stretch | 100,95,102,78 | outer ring, spikes, gems, compass tips | no; whole-image/proportional |
| level_button_frame | future button cluster asset | 366x428 | whole-image cluster; no stretch | exact child zones above | outer ring, side spikes, lower gem, circular rim | no; whole-image/proportional |
| level_badge_frame | future badge asset | 132x132 | whole-image badge; no stretch | 42,43,42,49 | red rim, gold bevel | no; whole-image/proportional |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| scrum666_combat_hud_2k_mockup_base | docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png | OpenAI visual source/mockup | 2560x1440 | RGB | n/a | use ui_plan.json | QA-red revision moved content zones into the generated empty interiors. |
| scrum666_combat_hud_2k_mockup_base_rejected_drift | docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base_rejected_drift.png | rejected first pass | 2560x1440 | RGB | n/a | n/a | Kept as evidence of coordinate drift. |
| scrum666_combat_hud_2k_ui_plan_guide | docs/design/previews/scrum666_combat_hud_2k_ui_plan_guide.png | authoritative safe-zone guide | 2560x1440 | RGB | n/a | exact rectangles | Use for integration. |
| scrum666_combat_hud_2k_layout_guide | docs/design/previews/scrum666_combat_hud_2k_layout_guide.png | content layout guide | 2560x1440 | RGB | n/a | exact rectangles | Renderer evidence. |
| scrum666_combat_hud_2k_debug_overlay | docs/design/previews/scrum666_combat_hud_2k_debug_overlay.png | compositor debug overlay | 2560x1440 | RGB | n/a | exact rectangles | Visual QA evidence: content zones sit inside dark interiors and avoid rails/ornaments. |
| scrum666_combat_hud_2k_visual_frame_zone_audit | docs/design/mockups/scrum666_combat_hud_2k/visual_frame_zone_audit.md | human visual QA note | n/a | n/a | n/a | exact rectangles | Lists each revised zone and the ornament it avoids. |

## Responsive Rules

- 1280x720: scale the 2K coordinates by 0.5; keep resource strip top-left, timer/ascension centered top, plus/count cluster bottom-right. Do not reduce content margins below the scaled empty interiors.
- 1920x1080: scale by 0.75; do not introduce artifact row or secondary FAB. Resource strip remains in the top-left readable band.
- 2560x1440: use coordinates above.
- Hidden states: ascension badge may hide at level zero; level count badge hides when pending count is zero; timer may hide in boss fights only if current runtime already does so.

## Interaction States

- Resource strip: non-interactive; HP can use low-health red accent inside `hp_zone`, not on rails.
- ULT: ready state may brighten the interior meter/text inside `ult_zone`; no outer glow over ornaments.
- Level button: hover/focus/pressed may brighten inner ring and plus zone without moving size or covering the bottom gem/rim.
- Disabled/hidden: plus button hidden when no level-up entry is available unless runtime needs an inactive state.

## Implementation Notes

- Godot scene: existing combat HUD creation owned by Back-end; this package does not edit runtime scripts.
- Control node structure: top-level HUD layer with `resource_strip`, `timer`, `ascension_badge`, `level_button`.
- Runtime text/icon containers: all labels and icons must use the exact zones above or scaled equivalents.
- Do not place runtime content in the earlier rejected rail positions. The accepted debug overlay shows all labels inside the generated dark interiors; those interiors are the integration contract until a Back-end task slices exact runtime assets.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview/source path recorded.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] UI plan report says `ready_for_image`.
- [x] Composite report says `ok: true`.
- [x] Runtime content zones are explicit and do not overlap each other.
- [x] QA-red frame conflict fixed: the accepted debug overlay no longer places content zones on generated rails, gems, crests, rims or bottom ornaments.
- [x] Runtime wiring files intentionally untouched.
- [ ] Screenshot comparison after runtime integration is Back-end scope.

## Deviations

QA-red revision note: the first accepted package used mechanically valid
rectangles that sat over generated rails/ornaments. This revision keeps the
same OpenAI source image but moves the accepted `ui_plan.json` and
`layout.json` zones into the visibly empty HUD interiors and separates
`level_button_zone` from `level_badge_zone` with no overlap at 2560x1440.
