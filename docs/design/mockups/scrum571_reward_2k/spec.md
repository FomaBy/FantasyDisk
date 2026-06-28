# UI Mockup Spec - SCRUM-571 Ordinary Reward 2K

Status: ready_for_qa_design_package
Role owner: Design
Task: docs/tasks/design_scrum571_reward_ui_2k_mockup_task.md
Jira: SCRUM-571
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png
Preview PNG: docs/design/previews/scrum571_reward_2k_mockup.png
Generated with: OpenAI Images API via skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py, then content composited with content-zone-image-compositor

## Source Request

Design-only stage for the ordinary reward screen: create a 2K OpenAI-API-generated mockup/spec/source package for the normal post-battle reward flow without touching `scripts/ui_screens.gd` or shared runtime integration files.

## Current Result

The geometry package passed the content-zone planning gate and the OpenAI Images API base layer was generated successfully after loading `OPENAI_API_KEY` from the Windows User environment. Runtime sample text was composited only inside the declared zones. The final render report is `ok=true` for all 15 zones.

## SCRUM-648 QA Defect Fix

QA found that the original final mockup placed subtitle/body/footer text over decorative frame bars even though JSON fit checks passed. This revision keeps the same OpenAI-generated base image and recomposites content only after moving affected zones into visibly empty dark interiors:

- subtitle moved from the upper ornamental rail to the lower empty interior of the subtitle frame;
- reward icons were compacted, card titles moved into the calm top-card interior, and body zones moved below the decorative divider bars;
- footer moved from the card/bottom ornament overlap area to the empty lower modal field.

No new base image, runtime integration, backing panels, or manual frame overlays were introduced.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| screen_background | Decor | reward hall backdrop | 0,0,2560,1440 | full | 1920x1080 | 0 | static | n/a |
| reward_modal_frame | Panel | ordinary reward modal | 250,120,2060,1180 | center | 1540x880 | 10 | static | screen |
| title_zone | Text | `Награда` | 600,188,1360,92 | top-center | 1020x69 | 20 | static | reward_modal_frame |
| subtitle_zone | Text | instruction line | 620,342,1320,44 | top-center | 990x33 | 20 | static | reward_modal_frame |
| card_1_frame | Card | reward option 1 | 410,410,500,650 | modal-left | 360x470 | 30 | default/hover/focus/pressed | reward_modal_frame |
| card_1_icon_zone | Icon | reward icon | 580,500,160,160 | card-center | 128x128 | 40 | default/hover/focus | card_1_frame |
| card_1_title_zone | Text | reward title | 500,680,320,48 | card-center | 240x36 | 40 | default/hover/focus | card_1_frame |
| card_1_body_zone | Text | reward effect copy | 486,882,348,82 | card-center | 260x62 | 40 | default/hover/focus | card_1_frame |
| card_1_button_frame | Button | choose action | 530,980,260,76 | card-bottom | 196x58 | 50 | default/hover/focus/pressed | card_1_frame |
| card_2_frame | Card | emphasized reward option 2 | 1030,380,500,690 | modal-center | 360x500 | 30 | default/hover/focus/pressed/selected | reward_modal_frame |
| card_2_icon_zone | Icon | reward icon | 1200,486,160,160 | card-center | 128x128 | 40 | default/hover/focus | card_2_frame |
| card_2_title_zone | Text | reward title | 1120,672,320,48 | card-center | 240x36 | 40 | default/hover/focus | card_2_frame |
| card_2_body_zone | Text | reward effect copy | 1106,882,348,82 | card-center | 260x62 | 40 | default/hover/focus | card_2_frame |
| card_2_button_frame | Button | choose action | 1150,988,260,76 | card-bottom | 196x58 | 50 | default/hover/focus/pressed | card_2_frame |
| card_3_frame | Card | reward option 3 | 1650,410,500,650 | modal-right | 360x470 | 30 | default/hover/focus/pressed | reward_modal_frame |
| card_3_icon_zone | Icon | reward icon | 1820,500,160,160 | card-center | 128x128 | 40 | default/hover/focus | card_3_frame |
| card_3_title_zone | Text | reward title | 1740,680,320,48 | card-center | 240x36 | 40 | default/hover/focus | card_3_frame |
| card_3_body_zone | Text | reward effect copy | 1726,882,348,82 | card-center | 260x62 | 40 | default/hover/focus | card_3_frame |
| card_3_button_frame | Button | choose action | 1770,980,260,76 | card-bottom | 196x58 | 50 | default/hover/focus/pressed | card_3_frame |
| footer_zone | Text | control hint | 780,1258,1000,38 | modal-bottom | 750x29 | 20 | static | reward_modal_frame |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| reward_modal_frame | future `assets/sprites/ui/frames/overhaul_2k/reward/ui_frame_2k_reward_modal.png` | 2060x1180 target | 96/112/96/104 | 150/170/150/144 | outer rails, corners, crest, ruby pins, bottom ornaments | yes, if only flat center stretches |
| reward_card | future `assets/sprites/ui/frames/overhaul_2k/reward/ui_frame_2k_reward_card.png` | 500x650 target | 54/64/54/70 | 76/92/76/88 | metal cap, corner claws, gem sockets, lower button rail | yes, verified after generation |
| reward_card_emphasis | future `assets/sprites/ui/frames/overhaul_2k/reward/ui_frame_2k_reward_card_emphasis.png` | 500x690 target | 58/70/58/74 | 82/104/82/96 | same as card plus top highlight crest | yes, verified after generation |
| reward_choice_button | future `assets/sprites/ui/frames/overhaul_2k/reward/ui_btn_2k_reward_choice.png` | 260x76 target | 28/22/28/24 | 42/22/42/22 | bevel, side caps, ruby pins | yes |

Content margins are intentionally larger than texture margins. The planned content zones in `ui_plan.json` are the source of truth until final OpenAI art can be inspected and measured.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| scrum571_ui_plan | docs/design/mockups/scrum571_reward_2k/ui_plan.json | pre-generation geometry contract | json | n/a | n/a | exact rects | Planning gate passed. |
| scrum571_ui_plan_guide | docs/design/mockups/scrum571_reward_2k/ui_plan_guide.png | visual zone guide | 2560x1440 | opaque guide | n/a | exact rects | Also copied to previews. |
| scrum571_layout | docs/design/mockups/scrum571_reward_2k/layout.json | final content compositor layout | json | n/a | n/a | exact text zones | Ready for renderer once base exists. |
| scrum571_layout_guide | docs/design/mockups/scrum571_reward_2k/layout_guide.png | pre-generation text-zone guide | 2560x1440 | opaque guide | n/a | exact text zones | Also copied to previews. |
| scrum571_base_mockup | docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png | OpenAI base layer | 2560x1440 | RGB PNG | measured from guide | declared zones | No baked text; dark empty interiors for runtime content. |
| scrum571_final_mockup | docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png | composited preview | 2560x1440 | RGB PNG | n/a | declared zones only | Renderer report `ok=true`. |
| scrum571_final_debug | docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_debug.png | zone debug overlay | 2560x1440 | RGB PNG | n/a | declared zones only | Shows all text/icon zones. |
| scrum571_final_report | docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup_report.json | compositor fit report | json | n/a | n/a | all 15 zones | `ok=true`. |

## Responsive Rules

- 1920x1080: scale the 2560x1440 design by `0.75`. Modal becomes `1545x885` at `(188,90)`. Cards become `375x488`; center card `375x518`. Minimum card content still supports `120x120` icons, `240px` title width, and `57px` button height.
- 2560x1440: use base coordinates from this spec.
- 3840x2160: scale by `1.5` with max modal width `3090` and max card width `750`. Keep cards centered as a group; do not expand text zones beyond 1.5x unless copy length demands it.
- If a 16:10 or narrow viewport is introduced later, keep the three cards as a centered horizontal group until card width would fall below `360`; then switch to a 1+2 stacked layout in a Back-end runtime task.

## Interaction States

- Card hover: neutral bright metal rim and slightly clearer empty center; no yellow glow, no layout shift.
- Card focus/selected: thin worn-gold inner line and modest ember accent outside content zones.
- Pressed: darker center and lower-contrast rim; content rect unchanged.
- Disabled/unavailable: desaturate card art and button, but keep body text readable inside the same zones.
- Empty/loading: icon well may show a small spinner or placeholder inside `*_icon_zone`; no spinner on card ornament.

## Implementation Notes

- Godot scene: future Back-end integration only, likely `_show_reward_screen` in `scripts/ui_screens.gd`; this task did not edit runtime files.
- Runtime content containers must use the content-zone rectangles, scaled uniformly from the 2K base.
- Choice card click/focus hit areas may cover the card frame, but labels/icons/descriptions/focus visuals must stay inside safe zones.
- If final generated frames are irregular, measure alpha/interior and update this spec before implementation.
- The OpenAI base layer is a full-screen mockup/reference, not a sliced runtime asset. If production frames are cut from it later, re-measure exact texture/content margins per resulting PNG before wiring.

## Acceptance Checks

- [x] UI plan exists before image generation.
- [x] Planning report: `decision=ready_for_image`, `ok=true`.
- [x] Layout guide/report exists and all zones are valid.
- [x] Mockup generated through OpenAI Images API.
- [x] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every planned frame has texture/content margin estimates.
- [x] No planned or final composited UI content overlaps frame border, ornament, gem, metal, decorative separator bar, or decorative corner.
- [x] Runtime content fits inside safe zones at every responsive target by scale math.
- [x] Hover/focus/pressed/disabled states are specified not to resize or shift layout.
- [ ] Screenshot comparison completed after implementation. Not in Design-only stage.
- [x] Design package ready for Jira QA.

## Deviations

This is a Design-only mockup/spec/source package. No runtime GDScript integration was performed, and no `.import` sidecars were created. The generated base is RGB because it is a full-screen mockup/reference layer; any future isolated frame assets must be exported as alpha-ready PNGs and rechecked before runtime use.
