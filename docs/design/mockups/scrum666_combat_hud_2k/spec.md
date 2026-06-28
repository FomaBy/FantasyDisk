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

## Source Request

Design/UI asset package for a clean essential-only 2K combat HUD: HP, XP,
money, ult charge, timer, ascension/elevation, and one bottom-right level-up
plus button. Do not touch runtime wiring files.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| resource_strip_frame | frame | HP/XP/money/ULT group | 32,24,1048,104 | top-left | 760x80 | 20 | normal | n/a |
| hp_zone | text/meter | HP current/max | 92,50,244,52 | top-left | 180x40 | 30 | normal/low | resource_strip_frame |
| xp_zone | text/meter | XP percent | 354,50,212,52 | top-left | 160x40 | 30 | normal | resource_strip_frame |
| gold_zone | text/icon | money | 588,50,144,52 | top-left | 112x40 | 30 | normal | resource_strip_frame |
| ult_zone | text/meter | ult charge | 754,50,254,52 | top-left | 190x40 | 30 | charging/ready | resource_strip_frame |
| timer_frame | frame | combat timer | 1140,22,280,104 | top-center | 220x80 | 20 | normal/boss hidden allowed | n/a |
| timer_zone | text | MM:SS | 1196,50,168,50 | top-center | 128x40 | 30 | normal | timer_frame |
| ascension_frame | badge | ascension/elevation | 1464,38,72,72 | top-center | 56x56 | 20 | hidden if zero | n/a |
| ascension_zone | text | A0..A5 or elevation | 1482,55,36,38 | center | 28x28 | 30 | normal | ascension_frame |
| level_button_frame | button | level-up reopen | 2428,1300,100,116 | bottom-right | 84x96 | 40 | normal/hover/focus/pressed/disabled | n/a |
| level_button_zone | icon/text | plus symbol | 2454,1324,48,54 | center | 40x44 | 50 | normal/hover/focus/pressed | level_button_frame |
| level_badge_frame | badge | pending count | 2490,1302,36,36 | top-right within button | 28x28 | 60 | hidden if zero | level_button_frame |
| level_badge_zone | text | pending count | 2498,1309,20,22 | center | 16x18 | 70 | normal | level_badge_frame |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| resource_strip_frame | future slot asset | 1048x104 | 48,26,48,26 | exact child zones above | metal rail, corner plates, ruby pins | yes, center only |
| timer_frame | future slot asset | 280x104 | 40,28,40,28 | 56,28,56,26 | rails, corner rivets | yes, center only |
| ascension_frame | future badge asset | 72x72 | 16,16,16,16 | 18,17,18,17 | outer ring, spikes, gems | no; whole-image/proportional |
| level_button_frame | future button asset | 100x116 | 18,22,18,22 | 26,24,26,24 | circular ring, spikes, bottom gem | no; whole-image/proportional |
| level_badge_frame | future badge asset | 36x36 | 8,8,8,8 | 8,7,8,7 | rim | no; whole-image/proportional |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| scrum666_combat_hud_2k_mockup_base | docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png | OpenAI visual source/mockup | 2560x1440 | RGB | n/a | use ui_plan.json | Mood/reference only; image model enlarged frames beyond exact coords. |
| scrum666_combat_hud_2k_mockup_base_rejected_drift | docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base_rejected_drift.png | rejected first pass | 2560x1440 | RGB | n/a | n/a | Kept as evidence of coordinate drift. |
| scrum666_combat_hud_2k_ui_plan_guide | docs/design/previews/scrum666_combat_hud_2k_ui_plan_guide.png | authoritative safe-zone guide | 2560x1440 | RGB | n/a | exact rectangles | Use for integration. |
| scrum666_combat_hud_2k_layout_guide | docs/design/previews/scrum666_combat_hud_2k_layout_guide.png | content layout guide | 2560x1440 | RGB | n/a | exact rectangles | Renderer evidence. |
| scrum666_combat_hud_2k_debug_overlay | docs/design/previews/scrum666_combat_hud_2k_debug_overlay.png | compositor debug overlay | 2560x1440 | RGB | n/a | exact rectangles | Text fit report is ok. |

## Responsive Rules

- 1280x720: scale the 2K coordinates by 0.5; keep resource strip top-left, timer/ascension centered top, plus button bottom-right. Minimum gap between timer and ascension remains 18px after scaling if hidden/visible rules match.
- 1920x1080: scale by 0.75; do not introduce artifact row or secondary FAB. Resource strip remains under 43% viewport width.
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
- Do not use the generated full-screen bitmap as a runtime atlas without slicing/slot correction; it is visual direction plus proof that the OpenAI pipeline was used. The validated `ui_plan.json` is the geometry contract.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview/source path recorded.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] UI plan report says `ready_for_image`.
- [x] Composite report says `ok: true`.
- [x] Runtime content zones are explicit and do not overlap each other.
- [x] Runtime wiring files intentionally untouched.
- [ ] Screenshot comparison after runtime integration is Back-end scope.

## Deviations

The OpenAI mockup is not pixel-exact: both generation attempts enlarged
ornamented frames relative to the requested rectangles. The accepted contract is
therefore the validated `ui_plan.json`, `layout.json`, and guide overlays, while
the generated PNG is style reference only. This avoids putting runtime text on
ornament during integration.
