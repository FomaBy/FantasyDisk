# SCRUM-427 Elementalist V2 Design Source Handoff

Status: ready_for_review
Class ID: `elementalist`
Base style: SCRUM-422 bright+epic character v2 anchor
Created: 2026-06-15

## Accepted Design Source

| Purpose | Path |
| --- | --- |
| Raw OpenAI source | `docs/design/references/characters_v2/elementalist/elementalist_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/elementalist/elementalist_v2_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/characters_v2/elementalist/elementalist_v2_idle_cell_512.png` |
| Design-source sheet handoff | `docs/design/references/characters_v2/elementalist/elementalist_v2_sheet_source_handoff.png` |
| Asset-side idle source copy | `assets/sprites/characters/v2/elementalist/elementalist_v2_idle_source.png` |
| Asset-side sheet handoff copy | `assets/sprites/characters/v2/elementalist/elementalist_v2_sheet_source_handoff.png` |
| Asset-side accepted source sheet copy | `assets/sprites/characters/v2/elementalist/elementalist_v2_sheet.png` |
| Contact / dark-background preview | `docs/design/previews/scrum427_elementalist_v2_contact.png` |
| Alpha/size QA report | `build/qa/scrum427_elementalist_v2/scrum427_elementalist_v2_alpha_size_report.json` |

## Visual Direction

Elementalist v2 is a bright, epic, class-readable multi-element caster:

- saturated fire, ice, lightning and earth/stone streams around the body;
- colorful ornate caster robes with strong combat-scale silhouette;
- unarmed source: no staff, wand, book, orb, focus, weapon, tool or held
  gameplay object;
- both hands are empty, with elemental energy only;
- visible feet and stable bottom-center pivot;
- transparent RGBA source, no baked checker/white matte, no UI frame, no text.

## Source Format

| Property | Value |
| --- | --- |
| Cell size | `512x512` |
| Pivot | `(256, 470)` |
| Visible bbox in cell | `[130, 96, 382, 470]` |
| Visible height | `374 px` |
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
- preserve the four-element identity without adding a baked orb, staff, focus
  or held object to the base body art;
- assemble the final v2 sheet if needed;
- create SpriteFrames/AnimationPlayer/AnimationTree integration;
- produce GIF/contact previews, manifest validation and Godot runtime smokes.

Do not treat `elementalist_v2_sheet_source_handoff.png` or
`elementalist_v2_sheet.png` as final motion. They are Design-source placeholder
sheets that preserve accepted silhouette, cell, pivot and alpha contract.

## QA

Pixel report summary:

- raw source was opaque (`raw_alpha_range: [255, 255]`);
- alpha-clean source is real RGBA (`clean_alpha_range: [0, 255]`);
- normalized cell is real RGBA (`cell_alpha_range: [0, 255]`);
- cleanup revision `global_near_white_removal` removes checker/halo whites
  globally, not only edge-connected background;
- `clean_opaque_white_pixels_after: 0`;
- `clean_neutral_light_pixels_after: 0`;
- `cell_opaque_white_pixels_after: 0`;
- `cell_neutral_light_pixels_after: 0`;
- `edge_visible_pixels_after: 0`;
- normalized cell visible height is `374 px`, inside the SCRUM-422 target
  `360..380 px`.

Runtime integration, animation manifest, GIF preview and animation/runtime smoke
were not run in this Design-source pass.
