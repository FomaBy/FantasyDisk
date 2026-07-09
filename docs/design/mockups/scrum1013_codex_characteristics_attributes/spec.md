# UI Mockup Spec — Codex: Characteristics / Attributes / Ascension Split

Status: ready_for_backend_handoff; geometry and render reports green  
Role owner: Design Main/Codex  
Task: `docs/tasks/SCRUM-1013_codex_mockup_handoff.md`  
Jira: SCRUM-1013  
Backend dependency: SCRUM-955  
Base resolution: 1920x1080  
Responsive targets: 1280x720, 1920x1080, 2560x1440  
Generated with: PixelLab MCP `create_ui_asset`  
PixelLab source ID/tag: `3ace4827-cfee-439e-8545-4dc145993d2f` / `scrum1013_codex_characteristics_attributes_v3_alpha_clean`

## Source Request

Split the live Codex data presentation into six Russian navigation sections:
`Персонажи`, `Монстры`, `Артефакты`, `Характеристики`, `Атрибуты`, and
`Возвышение`. Keep the current three-column interaction model: category rail,
focusable scroll list, and selected-entry preview/detail. This package is a
Design-only handoff; no runtime/data/test file is modified.

## Content And Control Inventory

| Surface | Fixed content | Dynamic content | Controls | Overflow |
| --- | --- | --- | --- | --- |
| Header | `Кодекс`, `Назад` | none | Back button, Esc/B | none |
| Navigation | all six Russian tab labels | selected section | six mouse/keyboard/gamepad buttons; LB/RB section cycle | none; six fixed rows fit |
| Center list | active section title | focusable entry title + concise summary; 17 characters, 30 monsters, all artifacts/shop items, 8 base characteristics, 27 derived attributes, 5 ascension levels | entry row buttons, focus follow, wheel/stick/Page scroll | `auto`, explicit 20px scrollbar lane |
| Right preview | caption only in sample | selected portrait/icon/diagram, clipped and contained | none | none |
| Right related panel | `Связанные атрибуты` sample | derived links relevant to the selected base stat | scroll/focus | `auto`, explicit 16px scrollbar lane |
| Right detail | selected title, chips, readable body headings | formula, influences, build meaning, unlock/locked text, long descriptions | text scroll/focus | `auto`, explicit 20px scrollbar lane |

The new semantic split is strict: `Характеристики` contains only the eight
base entries from `StatFormulas.BASE_STAT_ORDER`; `Атрибуты` contains only the
27 derived entries from `DERIVED_STAT_ORDER`; `Возвышение` contains the five
player-facing progression levels. Raw IDs and English duplicates are forbidden.

## Exact Elements At 1920x1080

| ID | Type | Rect `x,y,w,h` | Live content rect | Anchors | Min size | Z | States |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `header_title_frame` | panel | `72,44,320,92` | `145,68,210,44` | top-left | `240x72` | 10 | static |
| `back_button_frame` | button | `1588,44,260,92` | `1620,70,180,44` | top-right | `220x72` | 20 | default/hover/pressed/focus/disabled |
| `nav_panel` | panel | `72,164,320,844` | `100,192,264,788` | left/top-bottom | `280x680` | 10 | static |
| `tab_characters_frame` | button | `100,196,264,104` | `140,217,212,62` | nav top | `176x69 @720p` | 20 | default/hover/pressed/focus/selected/disabled |
| `tab_monsters_frame` | button | `100,324,264,104` | `140,345,212,62` | nav stack | `176x69 @720p` | 20 | same |
| `tab_artifacts_frame` | button | `100,452,264,104` | `140,473,212,62` | nav stack | `176x69 @720p` | 20 | same |
| `tab_characteristics_frame` | button | `100,580,264,104` | `140,601,212,62` | nav stack | `176x69 @720p` | 20 | same; selected in sample |
| `tab_attributes_frame` | button | `100,708,264,104` | `140,729,212,62` | nav stack | `176x69 @720p` | 20 | same |
| `tab_ascension_frame` | button | `100,836,264,104` | `140,857,212,62` | nav stack | `176x69 @720p` | 20 | same |
| `center_panel` | panel | `416,164,520,844` | title `500,212,360,50`; scroll `468,270,436,684` | expand between nav/detail | `420x680` | 10 | empty/loading/populated/error |
| `center_list_scroll` | scroll area | `468,270,436,684` | content width `416`; scrollbar `884,270,20,684` | fill center safe zone | `340px` content width | 20 | idle/scrolling/focus-follow |
| `entry_row_selected` | button | `468,286,416,92` | `500,304,360,56` | list width | `277x61 @720p` | 21 | selected/focus |
| `entry_row_default` | button | `468,383,416,92` | `500,401,360,56` | list width | same | 21 | default/pressed/disabled/locked |
| `entry_row_hover` | button | `468,480,416,92` | `500,498,360,56` | list width | same | 21 | hover |
| `detail_panel` | panel | `960,164,888,844` | irregular safe sub-zones below | right/top-bottom | `700x680` | 10 | empty/loading/populated/locked |
| `preview_stage` | media well | `1004,208,286,316` | icon `1046,244,202,202`; caption `1022,454,250,50` | detail top-left | `220x240` | 20 | available/locked silhouette/missing fallback |
| `detail_related_scroll` | scroll area | `1034,594,224,326` | text `1046,610,180,280`; scrollbar `1242,594,16,326` | detail lower-left | `180px` content width | 20 | idle/scrolling/empty |
| `detail_title` | text | `1330,210,280,68` | same | detail top-right | `187x45 @720p` | 20 | default/locked |
| `detail_chips` | text/chips | `1330,294,280,64` | same | below title | `187x43 @720p` | 20 | normal/rarity/class/locked |
| `detail_body_scroll` | scroll area | `1340,420,400,516` | text `1340,420,368,516`; scrollbar `1720,420,20,516` | detail right fill | `340px` content width | 20 | idle/scrolling/focus/locked copy |

Font ranges are machine-checked in `ui_plan.report.json`: screen title 24–36,
Back 20–30, tab labels 16–24, center title 20–29, rows 17–23, detail title
22–36, chips 15–20, related content 14–20, and body 18–25. The longest tab,
`Характеристики`, fits inside the measured 212px empty interior and must never
ellipsize at the base target.

## Frames, Margins And Forbidden Ornament Zones

| Frame | Estimated texture margin L/T/R/B | Required content margin L/T/R/B | 9-slice | Forbidden zones |
| --- | --- | --- | --- | --- |
| header title | `12/10/12/10` | `73/24/37/24` | reference only | gold lip, crest corners |
| Back button | `12/10/12/10` | `32/26/48/22` | reference only | corner caps, outer bevel |
| navigation | `18/18/18/18` | `28/28/28/28` | reference only | dragon corners, metal rails |
| center list | `20/20/20/20` | `32/32/32/44` | reference only | top crest, side rails, bottom points |
| detail | `22/22/22/22` | `44/44/50/44` plus declared irregular sub-zones | reference only | dragon head/corner ornaments, seams, gems |
| tab buttons | `12/12/12/12` | `40/21/12/21` | reference only | selected rim, caps, icon sockets |
| entry rows | `8/8/8/8` | `32/18/24/18` | reference only | leather seam, selected rim |
| preview well | `18/18/18/18` | icon inset `42/36/42/78` | reference only | square rim, corner claws, caption separator |

This full-page PixelLab layer is a visual/layout reference, not a runtime
NinePatch atlas. Backend SCRUM-955 must recreate Controls and may reuse the
existing `codex_pl` component family only where its measured content margins
meet or exceed this contract. Content on any ornament is a QA failure.

## Scroll And Fit Decisions

- Planning gate: `ready_for_image`, `ok=true`, zero errors/warnings.
- Center list: `content_h=2921`, viewport `684`; `scroll=auto`; reserved lane
  `x=884..904`.
- Related attributes: `content_h=520`, viewport `326`; `scroll=auto`; reserved
  lane `x=1242..1258`.
- Detail body: `content_h=1360`, viewport `516`; `scroll=auto`; reserved lane
  `x=1720..1740`.
- Navigation does not scroll: six 104px buttons plus five 24px gaps fit the
  788px safe interior with 16px bottom reserve.

## Responsive Rules

- **1280x720:** uniform geometry scale `0.6667`; main panels become nav
  `48,109,213,563`, center `277,109,347,563`, detail `640,109,592,563`.
  Clamp tab text to 18px minimum, body to 18px, row height to 60px, and frame
  content reserve to at least 16px. Both scrollbars remain 14–16px usable lanes.
- **1920x1080:** use exact rectangles above. Keep 24px inter-column gaps and
  28–50px frame-safe reserves.
- **2560x1440:** uniform geometry scale `1.3333`; main panels become nav
  `96,219,427,1125`, center `555,219,693,1125`, detail `1280,219,1184,1125`.
  Cap body at 34px and tab labels at 32px; do not let borders become thicker
  than their proportional margin or collapse the calm interiors.
- If a viewport is narrower than 1280x720, Backend must switch to a deliberate
  compact layout or reject the viewport; it must not overlap or hide columns.

## Interaction States

- Buttons: default, hover, pressed, keyboard/gamepad focus, disabled; selected
  tab/row changes rim/tint without changing rect or text baseline.
- Locked entries: keep row focusable when an unlock explanation exists; use a
  contained silhouette in `preview_stage`, a `Заперто` chip, and player-facing
  condition text. Never show an internal ID.
- Empty/loading/error: keep all three panels and their geometry stable; render
  a short centered runtime message inside the corresponding safe zone.
- Scroll: mouse wheel, keyboard/gamepad focus-follow, Page controls; scrollbar
  never overlaps text or frame ornament.
- Navigation: first tab receives default focus; LB/RB cycles the six sections;
  Esc/B and `Назад` return to the main menu.

## Files And Handoff

- Geometry: `ui_plan.json`, `ui_plan.report.json`, `ui_plan.guide.png`.
- Content layout: `layout.json`, `layout.guide.png`, render/debug reports.
- PixelLab provenance: `../../references/scrum1013_codex_characteristics_attributes/manifest.json`.
- Backend integration target: SCRUM-955; runtime files remain read-only here.

## Acceptance Checks

- [x] Every content/control/state is inventoried.
- [x] Exact 1920x1080 rects, font ranges, scrollbars and responsive rules exist.
- [x] `ui_plan.report.json` is `ready_for_image` / `ok=true`.
- [x] PixelLab source exported and visually inspected.
- [x] Final renderer report is `ok=true` and debug overlay inspected.
- [x] Preview shown in chat.
- [ ] Independent QA completed (not part of this Design execution).

## Deviations

PixelLab `create_ui_asset` supports a maximum exact 16:9 source of 672x378 for
this job. V1 was rejected because a crystal illustration entered the center
content zone. V2 fixed the geometry but retained a checkerboard. V3 preserved
the clean geometry and exported genuine transparency, so it is the accepted
source. It is upscaled proportionally to 1920x1080 with no geometry/aspect
distortion; no OpenAI/manual fallback or post-generation frame drawing was used.
