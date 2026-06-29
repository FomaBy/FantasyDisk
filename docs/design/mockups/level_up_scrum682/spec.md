# SCRUM-682 - Level Up Larger Choice Window UI Spec

Status: ready_for_integration
Role owner: Design
Task: `docs/tasks/SCRUM-682_level_up_ui_design.md`
Jira: SCRUM-682
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440, 3840x2160
Mockup PNG: `docs/design/references/level_up_scrum682/level_up_2k_mockup.png`
Frame kit reference: `docs/design/references/level_up_scrum682/level_up_frame_kit_reference.png`
Preview PNG: `docs/design/previews/level_up_scrum682_safe_zones.png`
Contact sheet: `docs/design/previews/level_up_scrum682_contact.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator/scripts/generate_asset.py`

## Source Request

Create a Design-owned Level Up UI package that makes the reward choice window
larger and more readable: bigger character portrait, larger reward icons,
three effect-focused cards with reserved effect-preview text zones, and a
reachable `Позже` button. Runtime integration remains a Back-end task.

## Planning Gate

Decision: `ready_for_image`.

Evidence files:

- `docs/design/mockups/level_up_scrum682/ui_plan.json`
- `docs/design/mockups/level_up_scrum682/layout.json`
- `docs/design/mockups/level_up_scrum682/ui_plan_report.json`
- `docs/design/mockups/level_up_scrum682/asset_audit.json`
- `docs/design/references/level_up_scrum682/level_up_2k_mockup.png`
- `docs/design/references/level_up_scrum682/level_up_frame_kit_reference.png`
- `docs/design/previews/level_up_scrum682_safe_zones.png`
- `docs/design/previews/level_up_scrum682_contact.png`

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| level_up_overlay | Control | dim/backdrop | x=0, y=0, w=2560, h=1440 | full rect | viewport | 0 | visible | viewport |
| level_up_panel | Panel/frame | modal shell | x=420, y=205, w=1720, h=1040 | center | 860x520 | 10 | default/intro | viewport |
| level_up_content | Content zone | all runtime content | x=512, y=315, w=1536, h=835 | inside panel | 768x417 | 11 | n/a | level_up_panel |
| hero_portrait_frame | Frame | current hero portrait | x=610, y=360, w=320, h=320 | top-left inside panel | 160x160 | 20 | default | level_up_content |
| hero_portrait_content | TextureRect | portrait art | x=654, y=404, w=232, h=232 | inside portrait frame | 116x116 | 21 | default | hero_portrait_frame |
| header_title_zone | Label group | title/level badge | x=980, y=360, w=880, h=82 | top center | 440x41 | 21 | default | level_up_content |
| header_subtitle_zone | Label | instruction copy | x=980, y=456, w=920, h=62 | top center | 460x31 | 21 | default | level_up_content |
| reward_card_0 | Button/card frame | option 1 | x=575, y=575, w=470, h=560 | center row | 235x280 | 30 | default/hover/focus/pressed/disabled | level_up_content |
| reward_card_1 | Button/card frame | option 2 | x=1045, y=575, w=470, h=560 | center row | 235x280 | 30 | default/hover/focus/pressed/disabled | level_up_content |
| reward_card_2 | Button/card frame | option 3 | x=1515, y=575, w=470, h=560 | center row | 235x280 | 30 | default/hover/focus/pressed/disabled | level_up_content |
| reward_card_icon | TextureRect | reward icon | 160x160 inside each card | top center | 80x80 | 31 | default | reward card content |
| reward_card_title | Label | reward title | 330x46 inside each card | below icon | 165x23 | 31 | default/rare | reward card content |
| reward_card_description | Label | short readable description | 330x92 inside each card | middle | 165x46 | 31 | default | reward card content |
| reward_card_effect_preview | Label/field | backend-provided effect preview | 330x64 inside each card | lower field | 165x32 | 31 | default/rare | reward card content |
| later_button | Button frame | defer current pick | x=1130, y=1158, w=300, h=82 | bottom center | 150x41 | 30 | default/hover/pressed/disabled | level_up_content |
| later_button_content | Label | `Позже` | x=1184, y=1186, w=192, h=26 | inside button | 96x13 | 31 | default | later_button |

Card internals are identical for all three cards:

| Zone | Card-local rect | Purpose |
| --- | --- | --- |
| content | x=58, y=70, w=354, h=426 | all runtime child controls |
| icon | x=155, y=91, w=160, h=160 | larger reward icon/medallion |
| title | x=70, y=271, w=330, h=46 | one-line title |
| description | x=70, y=335, w=330, h=92 | short readable copy |
| effect_preview | x=70, y=441, w=330, h=64 | reserved effect-focused backend text |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins L/T/R/B | Content margins L/T/R/B | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| level_up_panel | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_panel.png` | 1720x1040 | 64/84/64/72 | 92/110/92/96 | outer metal rails, corner gems, claw notches | yes |
| reward_card | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_card.png` | 470x560 | 42/54/42/50 | 58/70/58/64 | card border, corner gems, top/bottom rails | yes |
| reward_card_hover | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_card_hover.png` | 470x560 | 42/54/42/50 | 58/70/58/64 | same as card | yes |
| reward_card_selected | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_card_selected.png` | 470x560 | 46/58/46/54 | 62/74/62/68 | cyan rare rim and corner gems | yes |
| portrait_frame | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_portrait.png` | 320x320 | 34/34/34/34 | 44/44/44/44 | circular rim, gems | keep square |
| effect_preview | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_effect_preview.png` | 330x64 | 22/18/22/18 | 32/22/32/22 | thin inset border | yes |
| later_button | `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later.png` | 300x82 | 36/22/36/22 | 54/28/54/28 | side caps, ruby pins | yes |
| later_button_hover | `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later_hover.png` | 300x82 | 36/22/36/22 | 54/28/54/28 | side caps, ruby pins | yes |
| later_button_pressed | `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later_pressed.png` | 300x82 | 36/22/36/22 | 54/28/54/28 | side caps, ruby pins | yes |

All content margins exceed texture margins. Text, icons, portrait art, card
descriptions, effect-preview copy and button labels must stay inside the
declared content rectangles.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Notes |
| --- | --- | --- | --- | --- | --- |
| panel | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_panel.png` | larger modal shell | 1720x1040 | transparent PNG | source aspect matches planned panel |
| card | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_card.png` | reward option default | 470x560 | transparent PNG | full-card clickable Button frame |
| card_hover | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_card_hover.png` | hover/focus | 470x560 | transparent PNG | no layout shift |
| card_selected | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_card_selected.png` | rare/selected accent | 470x560 | transparent PNG | cyan rim outside content zone |
| portrait | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_portrait.png` | larger hero portrait frame | 320x320 | transparent PNG | keep square |
| effect_preview | `assets/sprites/ui/frames/level_up_scrum682/ui_frame_lu682_effect_preview.png` | per-card effect field | 330x64 | transparent PNG | child of card content |
| later_button | `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later.png` | defer action default | 300x82 | transparent PNG | label safe zone 192x26 |
| later_button_hover | `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later_hover.png` | defer hover/focus | 300x82 | transparent PNG | no yellow glow |
| later_button_pressed | `assets/sprites/ui/frames/level_up_scrum682/ui_btn_lu682_later_pressed.png` | defer pressed | 300x82 | transparent PNG | darker interior |

## Responsive Rules

- 1280x720: uniform scale 0.5 from the base plan. Panel becomes 860x520 at
  x=210, y=102. Reward cards are 235x280; use short card copy and tooltip/full
  detail fallback for overflow. Later button remains inside panel at 150x41.
- 1920x1080: uniform scale 0.75. Panel is 1290x780; cards are 352x420; icon
  zone is 120x120; effect-preview field remains separate and readable.
- 2560x1440: use the base rectangles 1:1.
- 3840x2160: uniform scale 1.5. Use 9-slice frame registration so ornaments do
  not stretch; keep content margins proportional to source metadata.

## Interaction States

- Card hover/focus: brighter muted-gold rim, no size change.
- Card pressed: darker interior, same content rect.
- Rare/selected card: restrained cyan rim outside content zone; title and
  effect-preview copy remain inside safe fields.
- Disabled: can reuse default frame with runtime modulation until a disabled
  asset is explicitly requested.
- Later button: default/hover/pressed assets included; label stays in
  `later_button_content`.

## Implementation Notes

- Back-end should integrate this in a separate task. This Design pass does not
  edit `scripts/ui_screens.gd` or `scripts/ui/ui_theme_paths.gd`.
- Preserve node identities when wiring: `LevelUpPanel`,
  `LevelUpHeroHeader`, `LevelUpRewardButton0..2`, `LevelUpLaterButton`.
- Register a new `level_up_scrum682` frame family or replace current
  `level_up_panel`/`level_up_card` only after updating source sizes, texture
  margins, content margins and UI no-overlap assertions.
- The effect-preview field is intentionally reserved for backend-provided
  concise effect copy. If the copy is longer than 2 short lines at 1280x720,
  truncate inside the field and expose full detail in tooltip.
- Do not slice the OpenAI full-screen mockup directly. The exact runtime
  contract is this spec plus `ui_plan.json` and `layout.json`.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] Frame-kit reference generated through OpenAI Images API.
- [x] All visible elements are listed with exact rectangles.
- [x] Every frame has texture margins and content margins.
- [x] Content margins exceed texture margins for every runtime asset.
- [x] Reward cards reserve separate icon/title/description/effect-preview zones.
- [x] Later button is reachable and inside the panel content zone.
- [x] Runtime integration files were not edited in this Design-only pass.

## Deviations

The final transparent PNGs are slot-exact, alpha-cleaned runtime candidates
derived from the generated UI direction and then constrained to the planned
geometry. They intentionally favor exact safe zones over direct pixel slicing
from the full-screen mockup.
