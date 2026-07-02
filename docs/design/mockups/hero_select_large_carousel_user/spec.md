# UI Mockup Spec - Hero Select Large Carousel

Status: draft
Role owner: Design
Task: direct user request, no Jira issue created
Jira: none
Base resolution: 2560x1440
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/previews/hero_select_large_carousel_user_mockup.png`
Debug overlay: `docs/design/previews/hero_select_large_carousel_user_mockup_debug.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator`, then `content-zone-image-compositor`

## Source Request

Create a beautiful standalone mockup image for the Hero Select page, without applying it to Godot. Required visible content: hero carousel with clearly visible large hero icons, selected hero preview, detailed hero description, windrose/stat radar, current ascension selector with ascension description, and a start/choose button.

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| title | Text | `Выбор героя` | `360,48,1840,92` | top center | 20 | normal | title frame interior |
| back_text | Button label | `Назад` | `170,124,270,42` | top left | 20 | normal/hover/focus | back button interior |
| portrait_content | Image | selected hero full-frame portrait | `136,272,456,620` | left/middle | 20 | selected | portrait frame interior |
| hero_name | Text | selected hero name | `780,262,820,62` | center panel | 20 | selected | dossier frame interior |
| hero_role | Text | short role description | `790,342,800,54` | center panel | 20 | selected | dossier frame interior |
| hero_body | Text | detailed hero description | `812,406,756,146` | center panel | 20 | selected | dossier frame interior |
| hero_weapons | Text | starting weapon trio | `812,570,756,60` | center panel | 20 | selected | dossier frame interior |
| stats_content | Image/text bars | 5 current HS4 stat rows | `820,640,740,190` | center panel | 20 | selected | dossier frame interior |
| hero_traits | Text | strengths/weaknesses | `812,838,756,58` | center panel | 20 | selected | dossier frame interior |
| choose_text | Button label | `Выбрать` | `1082,1032,332,44` | bottom center | 20 | normal/hover/focus/pressed | choose button interior |
| radar_content | Image/chart | windrose stat radar | `1814,235,584,406` | right upper | 20 | selected | radar frame interior |
| ascension_title | Text | current ascension level | `1790,778,632,46` | right lower | 20 | selected | ascension frame interior |
| ascension_stepper | Button labels | `- Возвышение +` | `1860,840,500,44` | right lower | 20 | normal/disabled edge cases | ascension frame interior |
| ascension_body | Text | selected ascension description | `1788,895,636,66` | right lower | 20 | selected | ascension frame interior |
| carousel_content | Image strip | 9 visible hero slots + arrows | `174,1106,2212,220` | bottom | 20 | selected/normal/locked | carousel frame interior |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| base mockup layer | `docs/design/references/hero_select_large_carousel_user/hero_select_large_carousel_base.png` | `2560x1440` | n/a | see element rects | all visible metal, dragons, gems, corners, rails | no |
| portrait frame | generated in base | approx `600x820` | estimated `60/80/70/80` | `portrait_content` rect | left/right rails, corner spikes, lower crest | no |
| dossier frame | generated in base | approx `980x820` | estimated `70/80/70/90` | dossier element rects | top crest, side rails, bottom dragon crest | no |
| radar frame | generated in base | approx `780x520` | estimated `85/55/85/65` | `radar_content` rect | compass frame, side rails, corner ornaments | no |
| ascension frame | generated in base | approx `780x270` | estimated `70/50/70/45` | ascension element rects | side rails, gems, bottom lip | no |
| carousel frame | generated in base | approx `2432x330` | estimated `110/60/110/50` | `carousel_content` rect | left/right claws, bottom ornament, center gem | no |

## Generated Assets

| Asset ID | Path | Purpose | Size | Notes |
| --- | --- | --- | --- | --- |
| openai_base | `docs/design/references/hero_select_large_carousel_user/hero_select_large_carousel_base.png` | textless frame/layout layer | `2560x1440` | OpenAI-generated, no runtime integration |
| ui_plan | `docs/design/mockups/hero_select_large_carousel_user/ui_plan.json` | pre-generation geometry | json | planning gate passed |
| layout | `docs/design/mockups/hero_select_large_carousel_user/layout.json` | compositor zones | json | renderer report passed |
| stat_bars | `docs/design/mockups/hero_select_large_carousel_user/content/berserk_stat_bars.png` | current HS4 dossier stat rows | `740x190` | content-only overlay |
| windrose_radar | `docs/design/mockups/hero_select_large_carousel_user/content/berserk_windrose_radar.png` | selected hero radar | `584x406` | content-only overlay |
| carousel_icons | `docs/design/mockups/hero_select_large_carousel_user/content/carousel_large_icons.png` | 9 large hero slots + arrows | `2212x220` | content-only overlay |

## Responsive Rules

- 1280x720: scale the whole layout by `0.5`; preserve carousel slot square aspect and keep minimum slot content around `90x90`.
- 1920x1080: scale by `0.75`; preserve three-column layout and the separate ascension panel.
- 2560x1440: use the documented pixel rects above.
- If implementation follows this direction, use runtime text/icons, not baked text, and keep all content inside the listed interiors.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview PNG produced.
- [x] UI plan validated with `decision: ready_for_image`.
- [x] Content composited only inside declared zones.
- [x] Render report returned `ok: true`.
- [x] No Godot runtime scene/script was changed.

## Deviations

The OpenAI base layer drifted slightly from exact requested coordinates for the back and choose button frames. The final compositor layout uses the visually empty interiors in the generated layer so content remains off ornament.
