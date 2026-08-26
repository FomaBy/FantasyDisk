# FantasyDisk Character Animation Style Sheet 0.1.5

Статус: Design standard for SCRUM-298 and per-character redraw tasks.
Обновлено: 2026-06-14.

## Goal

Playable characters must look like polished D&D/tabletop dark fantasy heroes, not
technical dolls or square placeholders. The source art should preserve the
expressive quality of the accepted Berserk/Dark Mage/Guitarist direction while
being production-ready for 5-frame movement and 5-frame attack sheets.

## Visual Canon

- Style: painterly dark fantasy D&D, heroic silhouettes, clean readable contour,
  rich materials, smooth shading, no noisy texture mush.
- Camera: same top-down/isometric game-readable angle as the current roster.
- Proportions: stylized heroic anatomy, readable head/torso/hands/feet at combat
  scale, not chibi and not hyper-real tiny-detail.
- Lighting: upper-left/front key, cooler ambient shadow, class-colored magic or
  material accents only where it supports identity.
- Outline: painterly dark edge, consistent but not thick cartoon sticker line.
- Materials: leather, cloth, metal, bone, wood, gems, glass, alchemy, holy/arcane
  effects as class-appropriate details.
- Grounding: no baked ground tile; transparent background. A soft contact shadow
  may be handled by runtime, not painted into every animation frame unless a
  task explicitly requests a full-frame shadow layer.
- Weapons: base character sheets are unarmed. Hands may pose for grip/cast/throw,
  but actual class weapons remain separate weapon assets/socket visuals.

## Canvas And Sheet Format

Canonical path:

```text
assets/sprites/characters/<class_id>_sheet.png
```

Canonical source/reference path:

```text
docs/design/references/characters/<class_id>/<class_id>_sheet_source.png
```

Default runtime sheet:

| Property | Value |
| --- | --- |
| Cell size | `384x384` |
| Columns | `5` |
| Rows | `3` preferred |
| Sheet size | `1920x1152` |
| Row 0 | `idle` 5 frames, loop, subtle breathing/secondary motion |
| Row 1 | `walk` 5 frames, loop |
| Row 2 | `attack_primary` 5 frames, non-loop |

Minimum acceptable fallback for early production:

| Property | Value |
| --- | --- |
| Cell size | `384x384` |
| Columns | `5` |
| Rows | `2` |
| Sheet size | `1920x768` |
| Row 0 | `walk` 5 frames, loop |
| Row 1 | `attack_primary` 5 frames, non-loop |
| Idle fallback | derive from `walk[0]` until a real idle row lands |

## Pivot And Safe Area

- Pivot: bottom-center foot anchor at `(192, 348)` inside each `384x384` cell.
- Feet baseline: both grounded feet should visually sit around y `338..356`.
- Head/hat safe top: keep at least `20px` transparent padding above the highest
  silhouette point.
- Side padding: keep at least `24px` transparent padding left/right in all
  frames, including attack anticipation and follow-through.
- Bottom padding: keep at least `16px` below feet/robes/tails so flip, shadow and
  scale do not clip.
- Character body occupancy: approximately `250..330px` height inside a cell,
  adjusted by class mass. Heavy classes can occupy more width, but must still
  remain inside side padding.

## Movement Row

Five frames:

1. Contact A: left foot/weight forward, torso settled.
2. Passing A: weight moves through center, opposite arm counter-swings.
3. Contact B: right foot/weight forward, torso lowest/heaviest beat.
4. Passing B: recovery through center.
5. Return/loop bridge: close to frame 1 without a visible pop.

Rules:

- Legged classes need real step changes, not a static vertical bob.
- Robes/coats/belts/hair should lag a little behind the torso.
- Heavy classes move with lower amplitude and slower-feeling weight; agile
  classes can have sharper knee/shoulder movement.
- Feet must not slide wildly across the bottom anchor. Root position stays
  stable; motion reads through limbs/body pose.

## Attack Row

Five frames:

1. Ready/anticipation: body winds up, hands prepare, silhouette compresses.
2. Windup: stronger lean/arm path, class identity visible.
3. Release/active: strike/cast/throw/channel moment; strongest silhouette.
4. Follow-through: body carries momentum, cloak/hair/tool trails settle.
5. Recovery: returns toward idle/walk[0], ready to loop back to movement.

Rules:

- The attack is weaponless in the character sheet. The pose should support the
  current weapon socket or class action without painting the weapon into hands.
- No gameplay hitbox timing is encoded in the PNG. Animator/Back-end decide
  event timing from runtime attack state.
- Class identity should read from pose: Berserk aggressive body drive, Dark Mage
  controlled casting, Guitarist performance stance, Ranger aim brace, Doctor
  clinical throw/drain, Druid ritual summon, etc.

## Class Identity Notes

| Class ID | Silhouette / pose direction |
| --- | --- |
| `berserk` | broad shoulders, forward aggression, empty clenched hands, fur/leather/red cloth |
| `dark_mage` | hood/robe, narrow controlled caster silhouette, hands channeling void magic |
| `guitarist` | performer stance, coat/straps, confident rhythm pose without baked guitar |
| `assassin` | compact agile stance, scarf/hood, quick hands and low center |
| `thief` | lighter rogue silhouette, cloak tricks, coin/smoke gestures without held item |
| `ranger` | stable ranged stance, cloak and light armor, empty bow/crossbow grip pose |
| `sniper` | precise disciplined ranged pose, lower bob, not a Ranger clone |
| `doctor` | plague/field medic silhouette, bottles/bandoliers, careful clinical motion |
| `priest` | holy support caster, censer/reliquary gestures without baked object |
| `chemist` | volatile alchemist, satchel/flasks as costume detail, nervous spark in motion |
| `biologist` | field researcher/organic magic, specimen gear, spore/seed gesture language |
| `knight` | heavy armored stance, open empty hands for shield/spear/flail sockets |
| `robot` | fantasy construct, heavy weight, rune/metal plates, no sci-fi plastics |
| `engineer` | artificer/tinkerer, leather/brass/rune tools, practical deploy gestures |
| `druid` | nature summoner, ritual hands, organic cloak/amulets, soft grounded motion |
| `soldier` | disciplined dark-fantasy soldier, braced ranged/throw stance, not modern military |
| `elementalist` | elemental caster, split fire/ice/stone/arcane accents, broad channel gestures |

## Generation Prompt Template

Use this for each class source sheet and adapt the class identity line:

```text
Create a production-ready 2D game sprite sheet for FantasyDisk, a dark fantasy
D&D/top-down action roguelite. Transparent background, no text, no watermark.
Canvas: 1920x1152, 5 columns x 3 rows, each cell 384x384.
Rows: idle 5 frames loop, walk 5 frames loop, attack_primary 5 frames non-loop.
Character: <class_id>, <one-sentence class identity>.
Base character is unarmed: do not draw weapons in hands. Hands may pose for
grip/cast/throw but actual weapons are separate socket assets.
Style: polished painterly D&D dark fantasy hero, expressive rounded/stylized
forms, smooth shading, readable silhouette, clean contour, no blocky placeholder
look, no flat UI icon style.
Pivot: keep feet centered near bottom of each cell with stable bottom-center
anchor, generous transparent padding, no cropping in any frame.
Motion: real walk cycle with weight shift; attack row has anticipation, windup,
active release, follow-through, recovery. Keep proportions consistent across
all frames.
```

## Handoff Boundaries

Design owns:

- source art direction;
- final sheet visual quality;
- transparent PNG sheet production;
- contact sheet/readability preview;
- class visual identity notes.

Animator owns:

- validating motion quality;
- SpriteFrames/AnimationPlayer/AnimationTree timelines;
- fps/loop/non-loop settings;
- pivot verification in motion;
- attack state naming and preview GIFs;
- `fantasydisk-pixellab-animation-integrator` manifest validation.

Back-end owns:

- `player.gd`/registry runtime loading;
- attack playback triggers;
- fallback behavior;
- gameplay timing/damage/targeting;
- smoke/regression tests for runtime integration.
