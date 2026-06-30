# UI Source Pack Spec - Hero Select Separate Parts

Status: draft
Role owner: Design
Task: direct user request, no Jira issue created
Jira: none
Base resolution: 2560x1440
Generated with: OpenAI Images API via `fantasydisk-asset-generator`, then alpha/resize postprocess

## Source Request

Create the Hero Select screen as separated UI parts instead of one baked page: page background, Back button, title frame, hero preview frame, central hero description module, windrose frame, ascension frame, plus/minus ascension buttons, Choose/Start button, bottom hero carousel frame, left/right carousel buttons, and hero slot frame.

## Preview Outputs

- Contact sheet: `docs/design/previews/hero_select_parts_contact.png`
- Assembled preview: `docs/design/previews/hero_select_parts_assembled_preview.png`
- Raw OpenAI sources: `docs/design/references/hero_select_parts/raw/`
- Transparent processed parts: `docs/design/references/hero_select_parts/processed/`
- Labeled mockup variants: `docs/design/references/hero_select_parts/labeled/`
- Processing report: `docs/design/mockups/hero_select_parts/process_report.json`
- Asset plan: `docs/design/mockups/hero_select_parts/asset_plan.json`

## Processed Asset List

| Asset ID | Processed path | Size | Runtime content/safe zone | Notes |
| --- | --- | ---: | --- | --- |
| background | `docs/design/references/hero_select_parts/processed/background.png` | `2560x1440` | n/a | Full-page backdrop only |
| button_back | `docs/design/references/hero_select_parts/processed/button_back.png` | `460x148` | approx `70,38,320,72` | Textless; labeled variant exists |
| frame_title | `docs/design/references/hero_select_parts/processed/frame_title.png` | `1840x184` | approx `120,42,1600,96` | Textless; labeled variant exists |
| frame_portrait | `docs/design/references/hero_select_parts/processed/frame_portrait.png` | `600x820` | approx `72,94,456,620` | Hero portrait must stay inside interior |
| frame_dossier | `docs/design/references/hero_select_parts/processed/frame_dossier.png` | `980x820` | approx `92,84,796,640` | Description, stats and text only inside interior |
| frame_radar | `docs/design/references/hero_select_parts/processed/frame_radar.png` | `780x520` | approx `98,57,584,406` | Windrose/radar chart zone |
| frame_ascension | `docs/design/references/hero_select_parts/processed/frame_ascension.png` | `780x270` | approx `74,50,632,183` | Ascension title, stepper and description |
| button_asc_minus | `docs/design/references/hero_select_parts/processed/button_asc_minus.png` | `132x92` | approx `32,22,68,48` | Textless body; labeled `-` variant exists |
| button_asc_plus | `docs/design/references/hero_select_parts/processed/button_asc_plus.png` | `132x92` | approx `32,22,68,48` | Textless body; labeled `+` variant exists |
| button_choose | `docs/design/references/hero_select_parts/processed/button_choose.png` | `512x118` | approx `70,34,372,50` | Textless; labeled variant exists |
| frame_carousel | `docs/design/references/hero_select_parts/processed/frame_carousel.png` | `2432x330` | approx `110,61,2212,220` | Wide rail for arrow buttons + hero slots |
| button_carousel_left | `docs/design/references/hero_select_parts/processed/button_carousel_left.png` | `132x176` | approx `36,42,60,92` | Textless body; labeled left-chevron variant exists |
| button_carousel_right | `docs/design/references/hero_select_parts/processed/button_carousel_right.png` | `132x176` | approx `36,42,60,92` | Textless body; labeled right-chevron variant exists |
| frame_hero_slot | `docs/design/references/hero_select_parts/processed/frame_hero_slot.png` | `196x220` | approx `18,18,160,160` | Hero icon + small label zone |

## Labeled Mockup Variants

These are for preview/mockup use. Runtime implementation should normally use the textless processed assets and draw labels/glyphs in Godot.

| Variant | Path |
| --- | --- |
| Back | `docs/design/references/hero_select_parts/labeled/button_back_labeled.png` |
| Title | `docs/design/references/hero_select_parts/labeled/frame_title_labeled.png` |
| Choose | `docs/design/references/hero_select_parts/labeled/button_choose_labeled.png` |
| Ascension minus | `docs/design/references/hero_select_parts/labeled/button_asc_minus_labeled.png` |
| Ascension plus | `docs/design/references/hero_select_parts/labeled/button_asc_plus_labeled.png` |
| Carousel left | `docs/design/references/hero_select_parts/labeled/button_carousel_left_labeled.png` |
| Carousel right | `docs/design/references/hero_select_parts/labeled/button_carousel_right_labeled.png` |

## Frame Rules

- All content must stay inside the safe zones listed above.
- No text, portraits, hero slots, stat bars, windrose chart, plus/minus glyphs, or carousel arrows may overlap metal rails, dragon ornaments, gems, claws, caps or corner decorations.
- The wide carousel is a composed element: use `frame_carousel` as the rail, `button_carousel_left/right` inside the rail ends, and repeated `frame_hero_slot` instances inside the central band.
- The ascension selector is also composed: use `frame_ascension`, then place `button_asc_minus` and `button_asc_plus` inside the ascension content area, with the current level and description between/below them.

## Acceptance Checks

- [x] Separate OpenAI-generated raw PNG sources exist.
- [x] Processed transparent PNG components exist.
- [x] Contact sheet shows the separate components.
- [x] Assembled preview demonstrates the intended Hero Select layout.
- [x] Runtime files were not modified.

## Deviations / Notes

`button_asc_minus`, `button_asc_plus`, `button_carousel_left`, and `button_carousel_right` share generated body art and differ by runtime/labeled glyph. This keeps the button family visually consistent and avoids AI-baked malformed symbols.
