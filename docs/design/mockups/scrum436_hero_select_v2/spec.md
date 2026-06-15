# SCRUM-436 Hero Select V2 Mockup / Design Handoff

Status: ready_for_integration_review
Role: Design -> Back-end UI
Base viewport: 1920x1080
Created: 2026-06-15

## Artifacts

| Artifact | Path |
| --- | --- |
| OpenAI raw mockup source | `docs/design/references/hero_select_v2/hero_select_v2_full_window_mockup_1920x1088.png` |
| Technical mockup, cropped/cleaned to 16:9 | `docs/design/mockups/scrum436_hero_select_v2/hero_select_v2_mockup_1920x1080.png` |
| Preview copy | `docs/design/previews/scrum436_hero_select_v2_mockup_preview.png` |
| Safe-zone overlay | `docs/design/mockups/scrum436_hero_select_v2/hero_select_v2_safe_zones_annotated_1920x1080.png` |
| Safe-zone preview copy | `docs/design/previews/scrum436_hero_select_v2_safe_zones.png` |
| Machine-readable layout metadata | `docs/design/mockups/scrum436_hero_select_v2/hero_select_v2_layout_metadata.json` |
| Dark-background QA contact sheet | `build/qa/scrum436_hero_select_v2/hero_select_v2_mockup_dark_background_qa.png` |

The OpenAI raw mockup includes a small generated marker under the radar. The
technical mockup covers that marker; runtime must not bake this text or any
other mockup lettering into the screen.

## Preserved Element

Keep the live SCRUM-322/SCRUM-347 radar exactly:

| Runtime node/asset | Requirement |
| --- | --- |
| `HeroSelectRadarPanel` | Reuse the current floating square windrose frame behavior. |
| `HeroStatRadar` | Reuse current polygon, label and radius behavior. Do not redraw or replace it from this mockup. |
| `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png` | Preserve current asset path/contract unless a separate accepted task changes it. |

Reserved target rect at 1920x1080: `Rect2(1510, 92, 286, 326)`.
Live radar content safe rect: `Rect2(1554, 122, 200, 210)`.

## 1920x1080 Content Zones

All runtime content must stay inside these safe zones. Decorative border art,
dragon head, gems, metal, arrows, corners, crests and seals stay unobstructed.

| Element | Safe rect |
| --- | --- |
| Hero preview portrait | `Rect2(262, 124, 464, 496)` |
| Hero name/title | `Rect2(876, 138, 526, 56)` |
| Description intro | `Rect2(846, 214, 606, 92)` |
| Dossier body text | `Rect2(838, 340, 626, 126)` |
| Traits row | `Rect2(864, 494, 590, 58)` |
| Weapons row | `Rect2(840, 574, 618, 56)` |
| Ascension minus | `Rect2(258, 686, 46, 46)` |
| Ascension label/value | `Rect2(326, 690, 310, 40)` |
| Ascension plus | `Rect2(690, 686, 46, 46)` |
| Select button | `Rect2(986, 692, 372, 54)` |
| Back button | `Rect2(1538, 692, 292, 54)` |
| Large hero carousel row | `Rect2(124, 790, 1672, 150)` |
| Tooltip area | `Rect2(540, 970, 840, 80)` |

Carousel thumbnail safe slots are 10 image-only rects inside the carousel row:
`142x130` each, starting at `x=124`, `y=800`, with `14px` horizontal gaps.
Runtime may virtualize/scroll if the class count exceeds the visible slots; the
selected/hover highlight must draw inside each thumbnail safe slot and not on
the carousel ornament.

## Responsive Rules

Use a single proportional scale factor:

`s = min(viewport_width / 1920, viewport_height / 1080)`

Center the scaled design canvas in the viewport. Do not stretch any decorative
frame independently on one axis.

| Viewport | Hero preview safe | Dossier body safe | Radar reserve | Carousel safe |
| --- | --- | --- | --- | --- |
| 1280x720 | `Rect2(174.67,82.67,309.33,330.67)` | `Rect2(558.67,226.67,417.33,84)` | `Rect2(1006.67,61.33,190.67,217.33)` | `Rect2(82.67,526.67,1114.67,100)` |
| 1920x1080 | `Rect2(262,124,464,496)` | `Rect2(838,340,626,126)` | `Rect2(1510,92,286,326)` | `Rect2(124,790,1672,150)` |
| 2560x1440 | `Rect2(349.33,165.33,618.67,661.33)` | `Rect2(1117.33,453.33,834.67,168)` | `Rect2(2013.33,122.67,381.33,434.67)` | `Rect2(165.33,1053.33,2229.33,200)` |

Full rect data for all controls and thumbnail slots is in
`hero_select_v2_layout_metadata.json`.

## Interaction States

- Hero thumbnails: normal, hover/focus glow, selected rim. All highlights stay
  inside each thumbnail safe rect.
- Tooltip: appears in `tooltip_safe` for hover/focus, with a short class hint
  and no overlap with carousel ornaments.
- Ascension minus/plus: disabled when min/max is reached; glyph is centered in
  the button safe rect.
- Select button: disabled if no valid hero/ascension selection; existing
  keyboard/gamepad activation flow remains unchanged.
- Back button: stays visible at all supported viewports and remains part of the
  existing Escape/back navigation stack.

## Back-end Handoff

Target integration owner: Back-end UI.

Runtime follow-up should rebuild `_show_character_select()` in
`scripts/ui_screens.gd` from this spec, but keep these live behaviors:

- `HeroSelectRadarPanel` / `HeroStatRadar` exact implementation and current
  radar asset.
- `ascension_selectable_max(character_id)` default, manual minus/plus changes,
  selected character state, weapon-select transition and start-run flow.
- Existing keyboard/gamepad focus and Escape/back semantics.
- Current portrait source contract from `ProgressionData.character_config(...).sprite_path`.

Do not implement the mockup as one fullscreen texture. Use it as a layout/style
reference, then build live Controls and source assets with recorded safe zones.

## Acceptance Checks For Integration

- Hero Select builds at 1280x720 / 1920x1080 / 2560x1440 with proportional frame
  scaling and no one-axis decorative stretching.
- Runtime content rects are inside the safe zones from
  `hero_select_v2_layout_metadata.json`.
- The live compass/radar remains visually and functionally unchanged.
- Large carousel thumbnails are image-only, horizontal, hoverable/selectable,
  and tooltip-safe.
- No text, button, portrait, icon, tooltip, highlight or selection zone touches
  decorative border art.
