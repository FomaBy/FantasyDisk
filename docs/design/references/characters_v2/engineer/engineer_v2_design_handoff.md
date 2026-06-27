# SCRUM-428 Engineer v2 Design Handoff

Status: ready_for_review
Class ID: `engineer`
Anchor: SCRUM-422 bright/epic character v2 source contract

## Accepted Source

| Asset | Path |
| --- | --- |
| Raw OpenAI source | `docs/design/references/characters_v2/engineer/engineer_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/engineer/engineer_v2_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/characters_v2/engineer/engineer_v2_idle_cell_512.png` |
| Source-sheet handoff | `docs/design/references/characters_v2/engineer/engineer_v2_sheet_source_handoff.png` |
| Asset cell copy | `assets/sprites/characters/v2/engineer/engineer_v2_idle_source.png` |
| Asset sheet handoff | `assets/sprites/characters/v2/engineer/engineer_v2_sheet_source_handoff.png` |
| Accepted source sheet copy | `assets/sprites/characters/v2/engineer/engineer_v2_sheet.png` |
| Contact preview | `docs/design/previews/scrum428_engineer_v2_contact.png` |
| Dark-bg preview | `docs/design/previews/scrum428_engineer_v2_dark_bg.png` |
| QA report | `build/qa/scrum428_engineer_v2/scrum428_engineer_v2_alpha_size_report.json` |

## Visual Direction

Bright epic copper/brass artificer inventor with ruby and amber gadget accents
mounted on the costume, warm spark aura and charismatic empty-hands stance. No
wrench, hammer, drone, mine, gear, gadget, tool, weapon or held object is baked
into the hands.

## Source Format

- Cell: `512x512` RGBA.
- Pivot: bottom-center `[256,470]`.
- Visible bbox: `[141, 90, 372, 470]`.
- Visible size: `231x380 px`.
- Source sheet: `2560x1024`, 5 columns x 2 rows.
- Rows: `idle_placeholder_source`, `move_placeholder_source`.
- The sheet repeats the accepted source cell only; Animator must create real
  idle and move/walk frame motion before SpriteFrames/runtime integration.

## QA

- Source/cell/sheet transparent background: PASS.
- Opaque white pixels after cleanup: `0`.
- Neutral-light matte pixels after cleanup: `0`.
- Pale low-saturation spark pixels after cleanup: `0`.
- Edge-visible pixels after cleanup: `0`.
- Dark-bg preview: PASS for no white halo/pockets; hand sparks are amber/copper.
- No neighboring-frame artifacts: PASS for source-handoff placeholder sheet.
- Runtime wiring: not done in Design scope.
