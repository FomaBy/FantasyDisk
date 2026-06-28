# UI Mockup Spec - SCRUM-571 Ordinary Reward 2K

Status: blocked_generation_credentials
Role owner: Design
Task: docs/tasks/design_scrum571_reward_ui_2k_mockup_task.md
Jira: SCRUM-571
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: blocked - OpenAI Images API key unavailable
Preview PNG: docs/design/previews/scrum571_reward_2k_layout_guide.png
Generated with: planned for OpenAI Images API via skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py

## Source Request

Design-only stage for the ordinary reward screen: create a 2K OpenAI-API-generated mockup/spec/source package for the normal post-battle reward flow without touching `scripts/ui_screens.gd` or shared runtime integration files.

## Current Result

The geometry package is ready for image generation and passed the content-zone planning gate. The actual OpenAI mockup PNG is blocked because `OPENAI_API_KEY` is not set in the shell and was not found in `C:/Users/FomaE/.codex/.env`; the required generator exited before calling the API. Per `fantasydisk-ui-director`, no manual or non-API fallback image was substituted.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| screen_background | Decor | reward hall backdrop | 0,0,2560,1440 | full | 1920x1080 | 0 | static | n/a |
| reward_modal_frame | Panel | ordinary reward modal | 250,120,2060,1180 | center | 1540x880 | 10 | static | screen |
| title_zone | Text | `Награда` | 600,188,1360,92 | top-center | 1020x69 | 20 | static | reward_modal_frame |
| subtitle_zone | Text | instruction line | 560,292,1440,56 | top-center | 1080x42 | 20 | static | reward_modal_frame |
| card_1_frame | Card | reward option 1 | 410,410,500,650 | modal-left | 360x470 | 30 | default/hover/focus/pressed | reward_modal_frame |
| card_1_icon_zone | Icon | reward icon | 560,512,200,200 | card-center | 128x128 | 40 | default/hover/focus | card_1_frame |
| card_1_title_zone | Text | reward title | 492,744,336,58 | card-center | 250x44 | 40 | default/hover/focus | card_1_frame |
| card_1_body_zone | Text | reward effect copy | 486,824,348,124 | card-center | 260x92 | 40 | default/hover/focus | card_1_frame |
| card_1_button_frame | Button | choose action | 530,980,260,76 | card-bottom | 196x58 | 50 | default/hover/focus/pressed | card_1_frame |
| card_2_frame | Card | emphasized reward option 2 | 1030,380,500,690 | modal-center | 360x500 | 30 | default/hover/focus/pressed/selected | reward_modal_frame |
| card_2_icon_zone | Icon | reward icon | 1180,498,200,200 | card-center | 128x128 | 40 | default/hover/focus | card_2_frame |
| card_2_title_zone | Text | reward title | 1112,736,336,58 | card-center | 250x44 | 40 | default/hover/focus | card_2_frame |
| card_2_body_zone | Text | reward effect copy | 1106,818,348,136 | card-center | 260x102 | 40 | default/hover/focus | card_2_frame |
| card_2_button_frame | Button | choose action | 1150,988,260,76 | card-bottom | 196x58 | 50 | default/hover/focus/pressed | card_2_frame |
| card_3_frame | Card | reward option 3 | 1650,410,500,650 | modal-right | 360x470 | 30 | default/hover/focus/pressed | reward_modal_frame |
| card_3_icon_zone | Icon | reward icon | 1800,512,200,200 | card-center | 128x128 | 40 | default/hover/focus | card_3_frame |
| card_3_title_zone | Text | reward title | 1732,744,336,58 | card-center | 250x44 | 40 | default/hover/focus | card_3_frame |
| card_3_body_zone | Text | reward effect copy | 1726,824,348,124 | card-center | 260x92 | 40 | default/hover/focus | card_3_frame |
| card_3_button_frame | Button | choose action | 1770,980,260,76 | card-bottom | 196x58 | 50 | default/hover/focus/pressed | card_3_frame |
| footer_zone | Text | control hint | 700,1152,1160,44 | modal-bottom | 870x33 | 20 | static | reward_modal_frame |

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
| scrum571_base_mockup | docs/design/references/scrum571_reward_2k/reward_ordinary_2k_base.png | OpenAI base layer | 2560x1440 | png | TBD | TBD | Blocked by missing `OPENAI_API_KEY`. |
| scrum571_final_mockup | docs/design/mockups/scrum571_reward_2k/reward_ordinary_2k_mockup.png | composited preview | 2560x1440 | png | n/a | declared zones only | Pending base layer. |

## Responsive Rules

- 1920x1080: scale the 2560x1440 design by `0.75`. Modal becomes `1545x885` at `(188,90)`. Cards become `375x488`; center card `375x518`. Minimum card content still supports `150x150` icons, `252px` title width, and `57px` button height.
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

## Acceptance Checks

- [x] UI plan exists before image generation.
- [x] Planning report: `decision=ready_for_image`, `ok=true`.
- [x] Layout guide/report exists and all zones are valid.
- [ ] Mockup generated through OpenAI Images API. Blocked: API key unavailable.
- [ ] Preview shown in chat when generated. Only geometry guide exists.
- [x] All visible elements are listed in the elements table.
- [x] Every planned frame has texture/content margin estimates.
- [x] No planned UI content overlaps frame border, ornament, gem, metal, or decorative corner.
- [x] Runtime content fits inside safe zones at every responsive target by scale math.
- [x] Hover/focus/pressed/disabled states are specified not to resize or shift layout.
- [ ] Screenshot comparison completed after implementation. Not in Design-only stage.
- [ ] Jira moved to QA. Blocked until OpenAI API generation succeeds.

## Deviations

OpenAI image generation was attempted with the required project generator, but failed before API call because no OpenAI key was available. The task is blocked rather than completed with a substitute mockup.
