# SCRUM-570 - Level-Up Overlay 2K Mockup Spec

Status: ready_for_integration
Role owner: Design
Task: docs/tasks/SCRUM-570_level_up_2k_redesign.md
Jira: SCRUM-570
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: `docs/design/references/scrum570_levelup_2k_redesign/levelup_overlay_2k_mockup_v2.png`
Preview PNG: `docs/design/previews/scrum570_levelup_2k_safe_zones_v2.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator/scripts/generate_asset.py`

## Source Request

Design-only stage for the FantasyDisk level-up overlay: create an OpenAI-API-generated 2K mockup/spec/source package with strict frame safe zones and no runtime integration changes.

## Planning Gate And Mockup Result

Planning gate: `ready_for_image`.

Evidence files:

- `docs/design/mockups/scrum570_levelup_2k_redesign/ui_plan.json`
- `docs/design/mockups/scrum570_levelup_2k_redesign/ui_plan_report.json`
- `docs/design/mockups/scrum570_levelup_2k_redesign/ui_plan_guide.png`
- `docs/design/references/scrum570_levelup_2k_redesign/levelup_overlay_2k_mockup.png` - first generation, rejected for geometry drift.
- `docs/design/references/scrum570_levelup_2k_redesign/levelup_overlay_2k_mockup_v2.png` - accepted style/mockup source.
- `docs/design/previews/scrum570_levelup_2k_safe_zones_v2.png`
- `docs/design/previews/scrum570_levelup_2k_contact.png`

Important integration caveat: the OpenAI mockup is the visual style source, not a slice-ready runtime atlas. The model preserved the intended hierarchy and dark fantasy material language, but it is not pixel-perfect enough to cut directly into runtime frames. The implementation contract is the `ui_plan.json` / element table below. Back-end must generate or wire slot-exact frames around these content rectangles and keep labels/icons/portraits inside the declared safe interiors.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| level_up_overlay | Control | dimmed level-up screen | x=0, y=0, w=2560, h=1440 | full rect | 2560x1440 | 0 | visible | viewport |
| level_up_panel | PanelContainer/frame | modal shell | x=760, y=420, w=1040, h=600 | center | 960x560 | 10 | intro/default | viewport |
| level_up_safe | Content zone | all runtime content | x=818, y=492, w=924, h=462 | inside panel | 820x396 | 11 | n/a | level_up_panel |
| hero_header | HBoxContainer | portrait + level badge/title group | x=940, y=504, w=680, h=118 | top center | 520x88 | 20 | default | level_up_safe |
| hero_portrait | TextureRect | current hero portrait | x=1002, y=512, w=88, h=88 | top center | 64x64 | 21 | default | hero_header |
| level_badge | Label | pending/level context | x=1112, y=506, w=336, h=28 | top center | 260x24 | 21 | default | hero_header |
| level_title | Label | "Level Up" / localized title | x=1112, y=540, w=336, h=54 | top center | 320x42 | 21 | default | hero_header |
| level_subtitle | Label | instruction copy | x=896, y=620, w=768, h=42 | center | 640x34 | 21 | default | level_up_safe |
| reward_card_0 | Button/card frame | upgrade icon/title/body/preview | x=865, y=684, w=238, h=210 | center row | 202x160 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| reward_card_0_content | Content zone | card 0 icon/title/body | x=905, y=728, w=158, h=124 | inside card | 136x104 | 31 | n/a | reward_card_0 |
| reward_card_1 | Button/card frame | upgrade icon/title/body/preview | x=1115, y=684, w=238, h=210 | center row | 202x160 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| reward_card_1_content | Content zone | card 1 icon/title/body | x=1155, y=728, w=158, h=124 | inside card | 136x104 | 31 | n/a | reward_card_1 |
| reward_card_2 | Button/card frame | upgrade icon/title/body/preview | x=1365, y=684, w=238, h=210 | center row | 202x160 | 30 | default/hover/focus/pressed/disabled | level_up_safe |
| reward_card_2_content | Content zone | card 2 icon/title/body | x=1405, y=728, w=158, h=124 | inside card | 136x104 | 31 | n/a | reward_card_2 |
| later_button | Button frame | defer choice | x=1150, y=908, w=260, h=72 | bottom center | 240x56 | 30 | default/hover/focus/pressed/disabled | level_up_safe |

## Frames And Safe Zones

| Frame ID | Intended asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| level_up_panel | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_panel.png` | 1040x600 | L/R/T/B 38/52/38/48 | L/R/T/B 58/72/58/66 | outer rails, claw corners, ruby pins, brass seams | yes |
| reward_card | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_card.png` | 238x210 | L/R/T/B 28/32/28/30 | L/R/T/B 40/44/40/42 | card border, corner notches, rare-state accent | yes, if generated with flat stretch center |
| hero_portrait_frame | small separate frame | 88x88 | estimated 10/10/10/10 | estimated 14/14/14/14 | ring border and gem pins | no, keep proportional |
| later_button | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_level_up_later_btn.png` | 260x72 | L/R/T/B 42/18/42/18 | L/R/T/B 54/22/54/22 | side caps, bevels, pins | yes |

## Responsive Rules

- 1920x1080: uniform scale 0.75 from 2560x1440. Panel becomes 780x450 at x=570, y=315. Content uses the scaled safe rect; cards become about 179x158 with reduced text and short descriptions.
- 2560x1440: use the base rectangles above 1:1. Three cards plus gaps fit inside `level_up_safe` with horizontal breathing room.
- 3840x2160: uniform scale 1.5 from 2560x1440. Slot-exact assets should remain crisp through 9-slice; ornaments stay in margin bands and content containers scale from source content margins.

## Interaction States

- Card hover/focus: neutral brighter metal and a subtle cyan/gold inner rim. No yellow glow and no layout shift.
- Card pressed: darker inner plate, same content rect.
- Disabled/locked: desaturated card, readable but non-emissive; tooltip explains reason if runtime ever disables a choice.
- Rare card: one card may use a restrained cyan/gold accent strip inside the border area, never under runtime text.
- Later button: compact minimal-metal state family, label stays inside the safe band.

## Implementation Notes

- Godot scene/script: Back-end integration must happen in a separate task; this Design stage does not edit `scripts/ui_screens.gd`.
- Control node structure: preserve `LevelUpOverlay`, `LevelUpPanel`, `LevelUpHeroHeader`, `LevelUpRewardButton0..2`, and `LevelUpLaterButton`.
- Runtime text/icon containers: all labels/icons/previews must stay inside the card and panel content margins above.
- Asset registry: register new frame paths/content margins in `scripts/ui/ui_theme_paths.gd` only in a Back-end integration task.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] Planning gate report says `decision: ready_for_image`.
- [x] All planned visible elements are listed in the elements table.
- [x] Every planned frame has texture margins and content margins.
- [x] Spec keeps UI content away from frame borders, ornaments, gems, metal, and decorative corners.
- [x] Runtime integration files were not edited in this Design-only pass.

## Deviations

The accepted v2 mockup is not a direct atlas because the image model's authored card ornaments are slightly looser than the exact planned content interiors. Use the exact rectangles and margins in this spec/UI plan, not visual pixel sampling from the mockup.
