# UI Mockup Spec - Weapon Select @2K

Status: draft
Role owner: Design
Jira: SCRUM-562
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Generated with: OpenAI Images API via fantasydisk-ui-director / fantasydisk-asset-generator

## Source Request

Redesign the Weapon Select screen for the 2K UI overhaul. Stage 1 fixes exact
geometry and proves that three weapon cards fit without content on frame
ornament. Stage 2 generates the dark fantasy frame layer and runtime assets.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ws_panel | Panel frame | screen shell | 420,190,1720,1060 | center | 1280x795 | 1 | static | root |
| ws_safe | Safe zone | all runtime content | 498,286,1564,898 | inside panel | 1040x674 | 2 | static | ws_panel |
| ws_title | Label | title | 498,296,1564,64 | top | 900x48 | 3 | static | ws_safe |
| ws_subtitle | Label | selected hero prompt | 498,376,1564,42 | top | 900x32 | 3 | static | ws_safe |
| ws_card_0..2 | Button/card | weapon icon/title/desc/stats | 498,446/664/882,1564,190 | vertical stack | 1040x160 | 4 | normal/hover/pressed/focus/disabled | ws_safe |
| ws_back | Button | back action | 1140,1120,280,60 | bottom center | 280x60 | 4 | normal/hover/pressed/focus/disabled | ws_safe |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| ws_panel | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ws_panel.png | 1720x1060 | 38,52,38,48 | 78,96,78,66 | outer rails, corner brackets, ruby pins | yes |
| ws_card | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ws_card.png | 1564x190 | 32,42,32,40 | 48,35,48,32 | card border, left/right caps, corner accents | yes |
| ws_btn_back | assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_ws_btn_back.png | 280x60 | 34,16,34,16 | 42,18,42,18 | button caps and bevel | yes |

## Responsive Rules

- 1920x1080: uniform downscale from 2K by 0.75; all content remains inside safe zones.
- 2560x1440: native 1:1 geometry.
- 3840x2160: uniform upscale from 2K by 1.5; no frame ornament is stretched outside 9-slice center.

## Interaction States

- Cards are full clickable buttons with normal/hover/pressed/focus/disabled styles.
- Hover/focus use neutral bright tint, not yellow glow.
- Back button uses the compact pause button profile.

## Acceptance Checks

- [x] UI plan exists before image generation.
- [x] Every content zone is declared before image generation.
- [ ] OpenAI mockup generated.
- [ ] Runtime assets generated and connected.
- [ ] UI no-overlap/display/runtime smoke checks pass.

## Deviations

SCRUM-489's 1120x660 panel used a scroll fallback. SCRUM-562 increases the
Weapon Select-specific panel to 1720x1060 so three weapon cards plus Back fit in
the safe zone without scrolling or ornament overlap. The start-boon screen keeps
the old generic weapon_select economy panel.
