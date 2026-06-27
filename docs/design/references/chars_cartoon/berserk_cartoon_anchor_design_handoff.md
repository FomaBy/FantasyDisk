# Berserk Cartoon/Anime Anchor Design Handoff — SCRUM-456

Status: ready_for_review
Class ID: `berserk`
Base style: SCRUM-456 cartoon/anime character restyle anchor
Created: 2026-06-17

## Accepted Design Source

| Purpose | Path |
| --- | --- |
| Corrected transparent source | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_raw.png` |
| Alpha-clean source | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_idle_cell_512.png` |
| Design-source sheet handoff | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png` |
| Contact preview | `docs/design/previews/scrum456_chars_cartoon_anchor_contact.png` |
| Dark-background preview | `docs/design/previews/scrum456_berserk_cartoon_anchor_dark_bg.png` |
| Idle source-preview GIF | `build/qa/scrum456_chars_cartoon/berserk_cartoon_idle_source_preview.gif` |
| Walk source-preview GIF | `build/qa/scrum456_chars_cartoon/berserk_cartoon_walk_source_preview.gif` |
| QA report | `build/qa/scrum456_chars_cartoon/scrum456_chars_cartoon_alpha_motion_report.json` |
| Source manifest | `build/qa/scrum456_chars_cartoon/animation_manifest.json` |

## Visual Direction

Berserk is the exemplar for the new direction: modern cartoon/anime
cel-shading, thick readable contour, large unarmed fists, offset bare feet,
fur shoulders, battle paint and saturated orange-red rage accents. The pose is
3/4-right and suitable for horizontal flip. Hands are empty: no axe, sword,
shield, hammer, tool or held gameplay object is baked into the character.

## Source Format

| Property | Value |
| --- | --- |
| Cell size | `512x512` |
| Pivot | `(256, 470)` |
| Visible bbox in cell | `[117, 56, 394, 488]` |
| Visible height | `432 px` |
| Source-sheet size | `2848x1168` |
| Source-sheet gutters | `48 px` transparent gutters and outer padding |
| Rows in handoff sheet | row 0 `idle`, row 1 `walk` |
| Frames per row | `5` |
| Attack row | Not included |
| Suggested FPS | `idle` 7 fps loop; `walk/move` 9 fps loop |

The source handoff GIFs/sheet are Design-source motion previews only. They
document scale, pivot, row order, spacing and broad motion intent; they are not
runtime-ready SpriteFrames and should not be sliced directly into production.

## QA Summary

- Transparent RGBA source/cell/sheet, alpha range `[0, 255]`.
- Edge-visible pixels: `0` for source, 512 cell and sheet.
- Semi-transparent neutral checker/matte pixels: `0` after cleanup.
- Source white/fur pixels that remain are interior character detail, not
  edge-connected matte.
- Source cell confirms unarmed pose, visible arms and visible legs.

## Animator Boundary

Animator owns the next phase after SCRUM-456 QA/PM accepts this source package:

- draw or rig-author real `idle` keyframes with breathing/secondary motion;
- draw or rig-author real `walk` / `move` keyframes with visible legs and arms;
- keep `attack_primary` absent unless a later PM task reopens attack animation;
- assemble final runtime sheets or SpriteFrames;
- produce final GIF/contact previews, manifest validation and Godot smoke tests.

