# UI Mockup Spec - Hero Select v3

Status: ready_for_integration
Role owner: Design complete -> Back-end integration handoff
Task: `docs/tasks/design_hero_select_v3_mockup_zones_frames_pipeline_task.md`
Jira: SCRUM-446
Base resolution: 1536x864
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/references/hero_select_v3/mockup.png`
Annotated PNG: `docs/design/references/hero_select_v3/mockup_zones_annotated.png`
Frame contact preview: `docs/design/previews/hero_select_v3_frames_contact.png`
Generated with: OpenAI Images API via `fantasydisk-asset-generator`; zones via OpenAI Vision API with Designer overlap correction.

## Source Request

Hero Select v3 must be rebuilt from scratch from a new mockup. The mockup defines four production zones: hero preview, dossier plus ascension selection, compass/stat radar, and hero carousel. Production frames are generated independently from the mockup and must protect the hard global frame rule: runtime content only inside the empty content zone, never on ornament/borders.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1536x864 | Anchors | Min size | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `hero_preview` | TextureRect + frame | selected hero portrait | 42, 82, 342, 540 | left/top proportional | 342x540 | selected, locked, unavailable | frame_preview |
| `dossier` | Panel content + frame | name, description, traits, weapons, ascension stepper, select button | 388, 93, 625, 467 | center/top proportional | 625x467 | hover/focus buttons, disabled select | frame_dossier |
| `radar` | Control + frame | HeroStatRadar live graph | 1086, 91, 388, 407 | right/top proportional; square preserve aspect | 388x407 | selected stat hover if added | frame_radar |
| `carousel` | HBox/card rail + frame | hero cards, arrows, tooltips | 26, 626, 1488, 226 | bottom stretch proportional | 1488x226 | hover, selected, locked, disabled | frame_carousel |
| `title` | Label/banner | screen title | 537, 25, 469, 79 | top/center proportional | 469x79 | static | background/title art region |
| `back_button` | Button | Back command | 52, 28, 123, 61 | top/left proportional | 123x61 | default, hover, pressed, focus | button runtime style |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| `frame_preview` | `assets/sprites/ui/frames/hero_select_v3/frame_preview.png` | 1024x1792 | L148 T224 R148 B260 | L210 T332 R210 B367 | border, corners, gems, claws, metal ornaments | yes |
| `frame_dossier` | `assets/sprites/ui/frames/hero_select_v3/frame_dossier.png` | 1536x1152 | L177 T144 R177 B167 | L253 T202 R253 B236 | border, corners, gems, claws, metal ornaments | yes |
| `frame_radar` | `assets/sprites/ui/frames/hero_select_v3/frame_radar.png` | 1024x1024 | L148 T148 R148 B148 | L230 T230 R230 B230 | border, corners, gems, claws, metal ornaments | no |
| `frame_carousel` | `assets/sprites/ui/frames/hero_select_v3/frame_carousel.png` | 2304x768 | L173 T127 R173 B127 | L265 T196 R265 B196 | border, corners, gems, claws, metal ornaments | yes |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `frame_preview` | `assets/sprites/ui/frames/hero_select_v3/frame_preview.png` | hero_preview frame | 1024x1792 | RGBA, white opaque=0 | L148 T224 R148 B260 | L210 T332 R210 B367 | Vertical hero portrait frame; keep portrait body entirely inside content rect. |
| `frame_dossier` | `assets/sprites/ui/frames/hero_select_v3/frame_dossier.png` | dossier frame | 1536x1152 | RGBA, white opaque=0 | L177 T144 R177 B167 | L253 T202 R253 B236 | Text, weapon rows, ascension controls and select button must stay inside content rect. |
| `frame_radar` | `assets/sprites/ui/frames/hero_select_v3/frame_radar.png` | radar frame | 1024x1024 | RGBA, white opaque=0 | L148 T148 R148 B148 | L230 T230 R230 B230 | Square-only compass/radar frame; do not 9-slice or stretch non-uniformly. |
| `frame_carousel` | `assets/sprites/ui/frames/hero_select_v3/frame_carousel.png` | carousel frame | 2304x768 | RGBA, white opaque=0 | L173 T127 R173 B127 | L265 T196 R265 B196 | Carousel cards and arrows stay inside content rect; ornaments/gems are forbidden zones. |
| `background` | `assets/sprites/ui/frames/hero_select_v3/background.png` | optional full-screen background | 1536x864 | RGBA opaque, white opaque=0 | n/a | n/a | Low-contrast background only; no panels/text/icons. |

## Responsive Rules

- 1280x720: `hero_preview` 35, 68, 285, 450; `dossier` 323, 78, 521, 389; `radar` 905, 76, 323, 339; `carousel` 22, 522, 1240, 188; `title` 447, 21, 391, 66; `back_button` 43, 23, 102, 51.
- 1920x1080: `hero_preview` 102, 102, 427, 675; `dossier` 485, 116, 781, 584; `radar` 1357, 114, 485, 509; `carousel` 32, 782, 1860, 282; `title` 671, 31, 586, 99; `back_button` 65, 35, 154, 76.
- 2560x1440: `hero_preview` 70, 137, 570, 900; `dossier` 647, 155, 1042, 778; `radar` 1810, 152, 647, 678; `carousel` 43, 1043, 2480, 377; `title` 895, 42, 782, 132; `back_button` 87, 47, 205, 102.

Scale zones from `zones_normalized.json` against the viewport, then apply each frame's `content_rect_normalized` inside that zone. `frame_radar` must remain square; use the smaller side if the runtime zone is ever non-square. `frame_carousel` can 9-slice horizontally but cards/arrows must stay inside its content rect.

## Interaction States

- Button and slot hover: glow/tint inside the content rect only; do not tint the frame ornament as a content state.
- Button and slot pressed: state art may darken the internal card/button surface; geometry is fixed.
- Disabled/locked: card content greys out inside carousel card safe zones; frame remains unchanged.
- Selected/focus: selected hero card uses an inner highlight ring inside the carousel content rect, not over the rail border.
- Empty/loading: keep placeholders inside the relevant content rect; never place loading text over borders.

## Implementation Notes

- Godot scene: Back-end should rebuild `_show_character_select` from scratch using this spec; old Hero Select v2 layout and frames are superseded.
- Recommended node structure: background `TextureRect`, six top-level proportional zone containers, transparent frame art behind each zone, runtime content containers inset by `content_margins_px` or `content_rect_normalized`.
- `frame_preview`, `frame_dossier`, and `frame_carousel` are 9-slice candidates; use the listed texture margins. `frame_radar` is square art and must not be non-uniformly stretched.
- Preserve existing live gameplay semantics: hero portrait/selection, ascension stepper, select/back actions, carousel selection/tooltip, and existing `HeroStatRadar` logic.

## Acceptance Checks

- [x] Mockup generated through OpenAI Images API.
- [x] Preview assets exist for mockup, annotated zones, and frame contact sheet.
- [x] All visible elements are listed in the elements table.
- [x] Every frame has texture margins and content margins.
- [x] Final frame PNGs are RGBA and have `white_opaque_pixels=0` after cleanup.
- [x] No UI content zone overlaps frame border, ornament, gem, metal, or decorative corner in the spec.
- [ ] Back-end runtime content fits inside safe zones at every responsive target.
- [ ] Hover/focus/pressed/disabled states do not resize or shift layout.
- [ ] Screenshot comparison completed after implementation.
- [ ] Runtime smoke and UI no-overlap matrix completed after implementation.

## Deviations

The first Vision pass over-expanded `hero_preview` into the carousel area and under-fit the radar frame. Raw output is preserved in `zones_vision_raw.json`; final `zones.json` and `zones_normalized.json` include Designer overlap correction after annotated-overlay QA.
