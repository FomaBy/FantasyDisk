# SCRUM-424 Dark Mage V2 Design Source Handoff

Status: ready_for_review
Class ID: `dark_mage`
Base style: SCRUM-422 bright+epic character v2 anchor
Created: 2026-06-15

## Accepted Design Source

| Purpose | Path |
| --- | --- |
| Raw OpenAI source | `docs/design/references/characters_v2/dark_mage/dark_mage_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/dark_mage/dark_mage_v2_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/characters_v2/dark_mage/dark_mage_v2_idle_cell_512.png` |
| Design-source sheet handoff | `docs/design/references/characters_v2/dark_mage/dark_mage_v2_sheet_source_handoff.png` |
| Asset-side idle source copy | `assets/sprites/characters/v2/dark_mage/dark_mage_v2_idle_source.png` |
| Asset-side sheet handoff copy | `assets/sprites/characters/v2/dark_mage/dark_mage_v2_sheet_source_handoff.png` |
| Contact / dark-background preview | `docs/design/previews/scrum424_dark_mage_v2_contact.png` |
| Alpha/size QA report | `build/qa/scrum424_dark_mage_v2/scrum424_dark_mage_v2_alpha_size_report.json` |

## Visual Direction

Dark Mage v2 is a bright, epic, class-readable void caster:

- saturated violet/purple magic, glowing runes, dark-gold robe trim;
- readable hoodless dark sorcerer silhouette with layered robe and shoulder
  armor;
- unarmed source: no staff, wand, book, orb, weapon, tool or held gameplay
  object;
- both hands are empty, with purple hand-glow only;
- visible feet/boots and a stable bottom-center pivot;
- transparent RGBA source, no baked checker/white matte, no UI frame, no text.

## Source Format

| Property | Value |
| --- | --- |
| Cell size | `512x512` |
| Pivot | `(256, 470)` |
| Visible bbox in cell | `[142, 94, 369, 470]` |
| Visible height | `376 px` |
| Target source height from anchor | `360..380 px` |
| Sheet handoff size | `2560x1024` |
| Rows in handoff sheet | row 0 `idle_source_placeholders`, row 1 `move_source_placeholders` |
| Frames per row | `5` |
| Attack row | Not included |

The source handoff sheet intentionally repeats the accepted 512-cell source in
all slots. It is a sizing/pivot/layout handoff, not final animation.

## Animator Handoff

Animator owns the next phase:

- derive or redraw real `idle` loop frames from this source;
- derive or redraw real `move` / `walk` loop frames from this source;
- preserve violet rune/glow identity without adding weapons or held objects;
- assemble the final v2 sheet if needed;
- create SpriteFrames/AnimationPlayer/AnimationTree integration;
- produce GIF/contact previews, manifest validation and Godot runtime smokes.

Do not treat `dark_mage_v2_sheet_source_handoff.png` as final motion. It is a
Design-source placeholder sheet that preserves accepted silhouette, cell, pivot
and alpha contract.

## QA

Pixel report summary:

- raw source was opaque (`raw_alpha_extrema: [255, 255]`);
- alpha-clean source is real RGBA (`clean_alpha_extrema: [0, 255]`);
- normalized cell is real RGBA (`cell_alpha_extrema: [0, 255]`);
- `clean_edge_white_pixels_after: 0`;
- `cell_edge_white_pixels_after: 0`;
- normalized cell visible height is `376 px`, inside the SCRUM-422 target
  `360..380 px`.

Runtime integration, animation manifest, GIF preview and animation/runtime smoke
were not run in this Design-source pass.
