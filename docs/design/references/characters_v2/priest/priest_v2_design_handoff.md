# SCRUM-431 Priest v2 Design Handoff

Status: ready_for_review
Class ID: `priest`
Anchor: SCRUM-422 bright/epic character v2 source contract

## Accepted Source

| Asset | Path |
| --- | --- |
| Raw OpenAI source | `docs/design/references/characters_v2/priest/priest_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/priest/priest_v2_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/characters_v2/priest/priest_v2_idle_cell_512.png` |
| Source-sheet handoff | `docs/design/references/characters_v2/priest/priest_v2_sheet_source_handoff.png` |
| Asset cell copy | `assets/sprites/characters/v2/priest/priest_v2_idle_source.png` |
| Asset sheet handoff | `assets/sprites/characters/v2/priest/priest_v2_sheet_source_handoff.png` |
| Accepted source sheet copy | `assets/sprites/characters/v2/priest/priest_v2_sheet.png` |
| Preview | `docs/design/previews/scrum431_priest_v2_contact.png` |
| QA report | `build/qa/scrum431_priest_v2/scrum431_priest_v2_alpha_size_report.json` |

## Visual Direction

Bright epic white-gold holy Priest with radiant halo, majestic healer robes and
open empty hands. No staff, mace, reliquary, censer, chime, book, weapon, tool
or held object is baked into the source. Hands carry only soft holy glow.

## Source Format

- Cell: `512x512` RGBA.
- Pivot: bottom-center `[256,470]`.
- Visible bbox: `[144, 94, 369, 470]`.
- Visible size: `225x376 px`.
- Source sheet: `2560x1024`, 5 columns x 2 rows.
- Rows: `idle_placeholder_source`, `move_placeholder_source`.
- The sheet repeats the accepted source cell only; Animator must create real
  idle and move/walk frame motion before SpriteFrames/runtime integration.

## QA

- Source/cell/sheet transparent background: PASS.
- Opaque white pixels after cleanup: `0`.
- Neutral-light matte pixels after cleanup: `0`.
- Edge-visible pixels after cleanup: `0`.
- No neighboring-frame artifacts: PASS for source-handoff placeholder sheet.
- Runtime wiring: not done in Design scope.
