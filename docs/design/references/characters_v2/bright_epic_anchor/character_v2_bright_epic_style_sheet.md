# FantasyDisk Character Redraw v2 Bright Epic Style Sheet

Status: Design anchor for SCRUM-422.
Updated: 2026-06-15.

## Goal

Character redraw v2 moves playable heroes away from small, dark, low-readability
combat figures toward bright, epic, class-first fantasy silhouettes. The game can
stay dark fantasy overall, but the playable heroes should read like powerful
player avatars at combat scale: saturated class colors, clear material shapes,
recognizable class fantasy, transparent background and no baked weapons.

This sheet supersedes `docs/design/references/character_animation_style_sheet_0_1_5.md`
for the 0.1.6 v2 redraw initiative only. Existing 0.1.5 runtime sheets remain
valid until Back-end/Animator explicitly wire v2 assets.

## Exemplar

Accepted Design exemplar:

| Purpose | Path |
| --- | --- |
| Raw generated source | `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_source_clean.png` |
| Normalized 512-cell source | `docs/design/references/characters_v2/bright_epic_anchor/berserk_v2_idle_cell_512.png` |
| Design asset handoff copy | `assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png` |
| Dark-background QA preview | `docs/design/references/characters_v2/bright_epic_anchor/character_v2_anchor_dark_bg_preview.png` |
| Alpha/size QA report | `build/qa/scrum422_character_v2_anchor/scrum422_character_v2_anchor_alpha_report.json` |

The Berserk exemplar defines the intended energy level: bold red/gold class
colors, readable anatomy, no held weapon, visible feet, strong magic/class
accent, transparent silhouette and no white matte.

## Visual Rules

- Bright and epic, not grim-muted: every class gets a saturated primary accent
  and one secondary material accent.
- Class identity must read before tiny details: silhouette, pose language and
  color must identify the class at combat size.
- Base character art is unarmed. Do not bake swords, rifles, guitars, staves,
  shields, or tools into hands. Costume details are allowed; handheld gameplay
  objects remain weapon/socket/VFX assets.
- Use painterly D&D fantasy rendering with clean dark contour and rich material
  groups. Avoid flat icon style, sticker outlines, modern sci-fi plastics unless
  the class explicitly needs fantasy-metal construction.
- No text, watermark, frame, UI card, ground tile, baked drop shadow or opaque
  background.
- Transparent alpha is mandatory. If generation produces white or near-white
  matte, clean it with edge-connected flood-fill and de-halo, preserving isolated
  white costume/effect details.

## V2 Source Format

| Property | Value |
| --- | --- |
| Source cell size | `512x512` |
| Source sheet rows | `idle`, `move` / `walk` |
| Source sheet columns | `5` frames per row |
| Source sheet size | `2560x1024` for final per-class v2 sheets |
| Attack row | Not included in v2; attack animation remains disabled by current product request |
| Pivot | Bottom-center foot anchor at `(256, 470)` inside each `512x512` cell |
| Visible source height | Target `360..380px` in the `512x512` cell for average humanoid classes |
| Top padding | At least `28px`, including hair/auras |
| Side padding | At least `32px`, including auras/cloaks |
| Bottom padding | At least `18px` below feet/robe tails |
| Idle FPS | `5 fps`, loop |
| Move FPS | `10 fps`, loop |
| Runtime visual scale target | `0.39..0.40` for v2 512-cell player sheets, subject to Back-end verification |

Size rationale: the current standard full-frame monsters use `384x384` source
cells with average visible source height about `197px` and runtime scale near
`0.36`, giving roughly `71px` visible screen height. A v2 playable hero with
`360..380px` visible source height at scale `0.39..0.40` lands near `140..152px`
screen height, i.e. approximately two times the average standard monster.

## Paths

Per-class Design source references:

```text
docs/design/references/characters_v2/<class_id>/<class_id>_v2_source_raw.png
docs/design/references/characters_v2/<class_id>/<class_id>_v2_source_clean.png
docs/design/references/characters_v2/<class_id>/<class_id>_v2_sheet_source.png
docs/design/previews/scrum4xx_<class_id>_v2_contact.png
build/qa/scrum4xx_<class_id>_v2/
```

Per-class accepted source handoff assets, kept isolated from current runtime
until Animator/Back-end integration:

```text
assets/sprites/characters/v2/<class_id>/<class_id>_v2_sheet.png
assets/sprites/characters/v2/<class_id>/<class_id>_v2_idle_source.png
```

Future runtime integration must not replace `assets/sprites/characters/<class_id>_sheet.png`
or `<class_id>_spriteframes.tres` until Animator/Back-end acceptance and smoke
tests are complete.

## Class Direction

| Class ID | Bright epic direction |
| --- | --- |
| `berserk` | Crimson/gold rage champion, broad chest and clenched empty fists, fire/rage aura, exposed feet or heavy wraps for grounded pivot. |
| `dark_mage` | Violet/blue void caster, readable hood/robe geometry, glowing hands, no staff/book in hands. |
| `guitarist` | Stage-warlock performer silhouette, magenta/gold sonic accents, empty performance hand poses, no baked guitar. |
| `assassin` | Sharp black/violet crimson rogue, compact forward lean, empty fast hands, no chakrams/daggers. |
| `thief` | Lighter amber rogue, cloak and coin/smoke motif as costume/effect, no held coin pouch or bomb. |
| `elementalist` | Split fire/ice/lightning/stone glow around hands and shoulders, bright cloth, no orb/focus/staff. |
| `sniper` | Silver/blue hunter marksman stance, disciplined empty grip silhouette, no rifle/scope in hands. |
| `priest` | White/gold holy support, readable vestments, halo-like light around hands, no reliquary/censer/chime held. |
| `biologist` | Emerald/teal organic scholar, spores and living-vine accents, no sample injector/lens/seed object in hands. |
| `robot` | Bright rune-forged construct, blue/gold core glow, heavy readable plates, fantasy metal over sci-fi plastic. |
| `engineer` | Brass/ruby artificer, workshop harness and rune tools as costume, no wrench/drone/mine in hands. |
| `doctor` | Plague-saint field medic, pale/green/black contrast, clean silhouette with clinical gestures, no syringe/saw. |
| `chemist` | Acid-green/orange alchemist, volatile glow around gloves and satchel details, no flask/powder/vial held. |
| `knight` | Shining red/gold armored guardian, broad stance with empty shield/spear-ready hands, no baked weapon/shield. |
| `druid` | Bright nature summoner, emerald/amber leaves and spirit glow, ritual empty hands, no staff/totem/raven held. |
| `soldier` | Fantasy battlefield captain, disciplined stance, steel/red tabard accents, no modern weapon silhouette. |

## Animator Handoff Contract

Animator receives source art only after Design source QA passes. Animator owns:

- real `idle` and `move` frame motion;
- final v2 sheet assembly if motion frames are authored outside Design;
- SpriteFrames/AnimationPlayer/AnimationTree wiring;
- animation manifest, GIF/contact previews, animation smoke and runtime smoke.

Required v2 motion:

- `idle`: 2-5 frames minimum, preferred 5 frames, subtle breathing/secondary
  motion, loop at `5 fps`.
- `move` / `walk`: 5 frames, real weight transfer or levitation motion, loop at
  `10 fps`.
- `attack`: not part of v2 source sheets unless a later product task re-enables
  attack animation.

## Back-end Handoff Contract

Back-end must verify or implement runtime support before v2 sheets replace the
current live paths:

- support `512x512`, `5x2`, `idle` + `walk/move` sheet parsing;
- preserve proportional scaling on both axes;
- target player visual height around `2x` average standard monster height;
- keep player collision, targeting and balance unchanged unless separately
  tasked;
- keep existing 0.1.5 sheets as fallback until v2 runtime smoke passes.
