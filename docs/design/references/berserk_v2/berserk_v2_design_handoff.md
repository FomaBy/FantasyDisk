# Berserk v2 Dark-Fantasy Dragon Design Handoff — SCRUM-531

Status: ready_for_review
Class ID: `berserk`
Base style: SCRUM-531 dark fantasy / D&D / dragon-themed brutal berserker redesign
Created: 2026-06-28
Follow-up animation ticket: SCRUM-532 (Animator owns rig/keyframes — NOT this task)

## PixelLab-style pipeline note

Per the ticket, the PixelLab character workflow was studied
(https://www.pixellab.ai/ and https://www.pixellab.ai/docs/tools/animate-with-skeleton).
Principles taken for this Design stage:

- Build one **stable source character** first with a clean, readable silhouette
  and explicit pivot before any motion is authored.
- Keep proportions, palette and silhouette **consistent and flip-friendly** so a
  skeleton/joint rig can be applied without redrawing the art direction.
- Hand off **pose/direction/pivot notes** so the Animator only authors motion
  (idle/move keyframes), not art identity.

This ticket delivers **stage 1 (source)** only. The Animator does **stage 2**
(skeleton/action-frame animation) in SCRUM-532.

## Accepted Design Source

| Purpose | Path |
| --- | --- |
| Raw OpenAI source (`gpt-image-2`, opaque) | `docs/design/references/berserk_v2/berserk_v2_source_raw.png` |
| Alpha-clean transparent source (RGBA) | `docs/design/references/berserk_v2/berserk_v2_source_clean.png` |
| Normalized 512-cell source (pivot 256,470) | `docs/design/references/berserk_v2/berserk_v2_idle_cell_512.png` |
| Design-source sheet handoff (idle/walk ×5) | `docs/design/references/berserk_v2/berserk_v2_sheet_source_handoff.png` |
| Final candidate export — clean | `assets/sprites/characters/berserk_v2/berserk_v2_source_clean.png` |
| Final candidate export — cell | `assets/sprites/characters/berserk_v2/berserk_v2_idle_cell_512.png` |
| Final candidate export — sheet | `assets/sprites/characters/berserk_v2/berserk_v2_sheet_source_handoff.png` |
| Dark-background preview | `docs/design/previews/scrum531_berserk_v2_dark_bg.png` |
| Contact / game-scale preview (1x/0.5x/0.25x) | `docs/design/previews/scrum531_berserk_v2_contact.png` |
| QA alpha/size/pivot report | `build/qa/scrum531_berserk_v2/scrum531_berserk_v2_alpha_size_report.json` |

## Visual Direction

A brutal **dark-fantasy / D&D dragonslayer** berserker, painterly and grim — a
deliberate departure from the current cartoon/anime cel-shaded anchor
(SCRUM-456/461). Key identity:

- Massive broad shoulders, aggressive forward fighting stance, wide mid-stance
  legs (not standing at attention).
- **Both hands are empty clenched bare fists** — no axe, hammer, sword, shield
  or held object is baked in. Left fist raised, right fist at the side.
- Dragon theme: heavy **dragon-skull + dragon-bone pauldron** over the right
  shoulder, two short curved **horns**, jagged dragon-scale armor plates, bone
  trophies, tattered dark fur cloak, worn leather straps, battle scars.
- Palette: deep oxblood crimson + charcoal-iron with bone-ivory accents; cool
  ambient shadow, upper-left key light.
- Strong heroic silhouette, thick readable painterly contour, rich materials,
  smooth shading — no noisy texture mush, no baked ground, no text/UI.

**Difference from current anchor:** the cartoon-anchor is saturated cel-shaded
cartoon/anime with battle paint and thick sticker outline; this v2 is painterly,
desaturated-grim, dragon-bone armored, and materially heavier. Distinct mood,
material set and palette — verifiably not the same character look.

Readability is confirmed at game scale by the contact preview
(`scrum531_berserk_v2_contact.png`): horns + dragon-skull pauldron + raised fist
+ wide stance remain legible at 0.5x and 0.25x.

## Source Format

| Property | Value |
| --- | --- |
| Cell size | `512x512` |
| Pivot | `(256, 470)` (feet/contact line) |
| Visible bbox in cell | `[72, 62, 441, 470]` |
| Visible height | `408 px` (within canon `360..432` band) |
| Visible width | `369 px` |
| Source-sheet size | `2848x1168` |
| Source-sheet gutters | `48 px` transparent gutters and outer padding |
| Rows in handoff sheet | row 0 `idle`, row 1 `walk` |
| Frames per row | `5` |
| Attack row | Not included |
| Suggested FPS | `idle` 7 fps loop; `walk/move` 9 fps loop |

The handoff sheet repeats the accepted source cell as **pose placeholders** to
document scale, pivot, row order and spacing. It is a Design-source layout, not
runtime-ready SpriteFrames, and must not be sliced directly into production.

### Direction-facing choice

`3/4 facing to the right`, intentionally symmetrical enough for a horizontal
flip to produce the left-facing variant. This matches the accepted roster
convention and the current cartoon-anchor.

### Pivot notes

- Pivot `(256, 470)` is the ground-contact line; the boots rest on it.
- The cell is horizontally centered on pivot x = 256.
- This is the same pivot the live runtime uses
  (`assets/sprites/characters/berserk_spriteframes.tres`, pivot 256/470), so the
  Animator can drop authored frames into the existing load path without changing
  `scripts/player.gd`.

### Palette / silhouette notes

- Palette anchors: oxblood crimson (`~#5a1f1f`-ish), charcoal-iron
  (`~#2a2724`), bone-ivory highlights (`~#d8cbb0`), fur/leather browns.
- Silhouette priorities to preserve under animation: the asymmetric
  **dragon-skull pauldron** (right), the two **horns**, the raised **left fist**,
  the **fur cloak** trailing left, and the wide planted stance. Keep these
  readable when limbs move; do not let the cloak fill the negative space between
  the legs (no closed pockets).

## Attack-ready pose reference

The ticket asks for "idle / move / attack-ready" pose references. The single
accepted source pose already reads as an **attack-ready guard** (raised clenched
fist, forward aggressive lean), so it serves as the attack-ready pose reference.
This is a *pose reference only* — it is **not** an `attack_primary` animation row
and must not be added to the sheet: in-game attack animation is disabled
(`scripts/player.gd` `USE_ATTACK_ANIMATION := false`). idle/walk are the only
authored rows for now.

## QA Summary

From `build/qa/scrum531_berserk_v2/scrum531_berserk_v2_alpha_size_report.json`:

- Transparent RGBA clean source and 512-cell, alpha range `[0, 255]` (true alpha).
- Edge-white opaque pixels touching canvas border: `0` for clean, cell and sheet.
- Background gray matte removed via edge flood-fill keyed on bg-color distance +
  low chroma, plus de-fringe; dark-bg preview confirms no halo and no holes in
  the dark armor.
- Hands empty; arms and legs visible; wide mid-stance confirmed.
- Cell `512x512`, pivot `(256,470)`, visible height `408 px` (in band).
- Sheet `2848x1168`, gutters `48 px`, rows idle/walk × 5, attack row absent.

## Animator Boundary (SCRUM-532)

Animator owns the next phase after Design/PM accepts this source package:

- author real `idle` keyframes with breathing / secondary motion (cloak, fur);
- author real `walk` / `move` keyframes with visible legs and arms;
- keep `attack_primary` absent unless a later PM task reopens attack animation;
- assemble final runtime sheet or `SpriteFrames` for the existing load path;
- produce final GIF/contact previews, manifest validation and Godot smoke tests.

None of the above is done in this Design ticket.

## Pixel fallback

**Not used.** The non-pixel painterly source is clean-silhouette, single-pose,
flip-friendly and has an explicit pivot — i.e. it is animation-viable for a
skeleton/keyframe rig, so no pixel-art fallback was required.

## Runtime untouched

This is a Design/source-only ticket. The live runtime is unchanged: no edits to
`assets/sprites/characters/berserk_spriteframes.tres`,
`assets/sprites/characters/full_frame/berserk/*`, `scripts/player.gd`, or any
test. All new files are isolated under the new `berserk_v2/` reference and asset
folders.
