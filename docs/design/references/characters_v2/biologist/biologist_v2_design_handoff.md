# SCRUM-421 Biologist v2 Design Handoff

Status: ready_for_review
Class ID: `biologist`
Anchor: SCRUM-422 bright/epic character v2 source contract

## Accepted Source

| Asset | Path |
| --- | --- |
| Raw OpenAI source | `docs/design/references/characters_v2/biologist/biologist_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/biologist/biologist_v2_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/characters_v2/biologist/biologist_v2_idle_cell_512.png` |
| Source-sheet handoff | `docs/design/references/characters_v2/biologist/biologist_v2_sheet_source_handoff.png` |
| Asset cell copy | `assets/sprites/characters/v2/biologist/biologist_v2_idle_source.png` |
| Asset sheet handoff | `assets/sprites/characters/v2/biologist/biologist_v2_sheet_source_handoff.png` |
| Accepted source sheet copy | `assets/sprites/characters/v2/biologist/biologist_v2_sheet.png` |
| Preview | `docs/design/previews/scrum421_biologist_v2_contact.png` |
| QA report | `build/qa/scrum421_biologist_v2/scrum421_biologist_v2_alpha_size_report.json` |

## Visual Direction

Bright epic emerald bioluminescent scientist-naturalist in protective field suit
with layered cloak and organic light patterns. Hands are empty with only soft
green bio-glow. No syringe, vial, flask, sample jar, tool, orb, staff, weapon or held object is baked into the source.

## Source Format

- Cell: `512x512` RGBA.
- Pivot: bottom-center `[256,470]`.
- Visible bbox: `[137, 90, 375, 470]`.
- Visible size: `238x380 px`.
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
