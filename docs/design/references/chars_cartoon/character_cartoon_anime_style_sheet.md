# FantasyDisk Character Cartoon/Anime Style Sheet

Status: Design anchor for SCRUM-456.
Updated: 2026-06-17.

## Goal

SCRUM-456 shifts playable character redraws toward a more modern cartoon/anime
read: cel-shaded planes, confident dark contour, clearer silhouettes and much
stronger class separation. FantasyDisk stays D&D dark fantasy, but player heroes
should no longer look like the same realistic miniature with different colors.

This package supersedes the broad cancelled v2 redraw direction for future
playable-character source work. Existing runtime assets remain valid until a
specific Animator/Back-end task accepts and wires a class.

## Research Notes

The useful contemporary pattern is not "cute" or "flat." The target is dark
fantasy with animation-friendly shape language:

- large readable shapes first, material detail second;
- cel-shaded light bands and painterly accents instead of small realistic noise;
- thick outer contour plus controlled inner linework;
- saturated class palettes with one dominant hue, one material hue and one
  magical/accent hue;
- expressive proportions: larger hands/feet/head reads, broad shoulders or
  cloak masses where class identity needs it;
- clean limb separation for frame-by-frame walk/idle animation.

Reference language: Arcane-like painted planes, Hades-like class silhouette
clarity, modern anime-cel contour confidence, adapted into FantasyDisk's D&D
dark-fantasy costumes and monsters.

## Accepted Exemplar

| Purpose | Path |
| --- | --- |
| Corrected transparent source | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_raw.png` |
| Alpha-clean source copy | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_clean.png` |
| Normalized 512 cell | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_idle_cell_512.png` |
| Design-source sheet handoff | `docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png` |
| Contact preview | `docs/design/previews/scrum456_chars_cartoon_anchor_contact.png` |
| Dark-background preview | `docs/design/previews/scrum456_berserk_cartoon_anchor_dark_bg.png` |
| QA report | `build/qa/scrum456_chars_cartoon/scrum456_chars_cartoon_alpha_motion_report.json` |

The OpenAI Images API returned a baked checkerboard RGB source. The source/raw
path above was corrected to transparent RGBA after edge-connected checker/matte
cleanup, matching the task's transparent-PNG-only requirement.

## Visual Rules

- Transparent RGBA only. No white/checker/neutral matte, no ground tile, no
  baked shadow, no UI frame, no text.
- Base hero hands stay empty. Weapons, tools, focus objects, shields, guitars,
  guns and staffs remain weapon/socket/VFX assets.
- Class identity must read from silhouette and palette at combat scale before
  costume details are visible.
- Each class needs a different body mass or outline language: broad, angular,
  cloak-heavy, vertical, compact, mechanical, robe/floating, hunched, elegant,
  etc.
- Preserve visible arms and legs for animation. Long robes/cloaks may move, but
  they must not fully hide the walk cycle unless the class is intentionally
  floating.
- White costume/fur details are allowed only when they are interior character
  pixels, not edge-connected matte.

## Source Format

| Property | Value |
| --- | --- |
| Cell size | `512x512` |
| Pivot | `(256, 470)` bottom-center foot anchor |
| Exemplar visible bbox | `[117, 56, 394, 488]` |
| Exemplar visible height | `432 px` |
| Source sheet rows | row 0 `idle`, row 1 `walk` / `move` |
| Frames per row | `5` |
| Safe source-sheet gutters | `48 px` between cells and around sheet |
| Exemplar sheet size | `2848x1168` |
| Idle FPS | `7 fps`, loop |
| Walk/Move FPS | `9 fps`, loop |
| Attack row | Not included; attack visuals remain weapon-owned |

The SCRUM-456 sheet is a Design-source handoff, not final runtime motion.
Animator must author real limb motion before SpriteFrames integration.

## Class Differentiation Matrix

The user request says 16 classes; the current registry has 17 playable classes,
so this matrix covers all 17 to avoid leaving Soldier ambiguous.

| Class ID | Silhouette | Palette | Identity Direction |
| --- | --- | --- | --- |
| `berserk` | huge bare torso, fur shoulders, wide fists, offset feet | skin/black fur/crimson paint/orange rage | unarmed rage barbarian, readable arms and legs |
| `dark_mage` | tall robe wedge, high collar, floating sleeves | deep violet/void blue/pale cyan | void caster, hands glow but hold no staff/book |
| `guitarist` | performer stance, dramatic hair/coat tails | magenta/black/gold sonic light | stage-warlock, no baked guitar or microphone |
| `assassin` | narrow forward lean, sharp hood points | dark teal/black/cyan edge glow | fast silent killer, empty knife-ready hands |
| `thief` | compact agile cloak, pouch-like costume shapes | amber/brown/smoke gray | nimble trickster, no held bombs/coins |
| `elementalist` | asymmetrical elemental mantle, open stance | fire orange/ice cyan/lightning yellow/stone gray | four-element caster, empty hands with aura only |
| `sniper` | vertical disciplined marksman, long coat angles | steel blue/cold white/red sight accent | precise hunter, no rifle/bow/scope baked in |
| `priest` | soft vestment bell shape, halo/cape arc | white/gold/warm blue | holy sustain support, empty blessing hands |
| `biologist` | scholar silhouette with organic shoulder mass | emerald/teal/toxic yellow | spore scientist, living costume details only |
| `robot` | chunky armored guardian, blocky limbs | dark iron/cyan core/gold rune seams | fantasy construct, no cannon/tool weapon |
| `engineer` | compact artificer with harness and backpack shapes | brass/ruby/charcoal | workshop summoner/support, no held wrench/drone |
| `soldier` | upright commander, tabard and shoulder line | steel/red/cream | battlefield captain, fantasy not modern military |
| `ranger` | light cloak and hunter hood, long stride | forest green/tan/moon silver | mobile tracker, no bow/crossbow in base art |
| `doctor` | plague-mask/medic coat but readable legs | bone white/black/sick green | drain/sustain healer-damager, no syringe/saw |
| `chemist` | potion-satchel outline, volatile gloves | acid green/orange/dark leather | alchemist, no held flask/powder/vial |
| `knight` | broad armored triangle, empty shield-ready arm | red/gold/polished steel | tank guardian, no baked spear/shield |
| `druid` | nature cloak, antler/leaf silhouette | emerald/amber/bark brown | summoner mystic, no staff/totem/raven held |

## Animation Handoff Rules

For SCRUM-456 and downstream class rows:

- `idle`: 5 source frames preferred, loop, breathing/secondary cloth/hair motion.
- `walk` / `move`: 5+ frames, loop, visible leg and arm motion. A robe/fur/cloak
  can add secondary motion but cannot hide that the character is walking.
- `attack_primary`: excluded. Weapon attacks/VFX own attack readability.
- Source sheets keep 48px transparent gutters and outer padding for 512 cells.
- Animator owns final keyframes, SpriteFrames/AnimationPlayer/AnimationTree,
  manifests, animation smoke and runtime smoke.

