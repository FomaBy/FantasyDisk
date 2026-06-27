# FantasyDisk Animation Standards

## Table Of Contents

- Entity classes
- Pipeline decision rules
- Godot-native rig output
- Hybrid rig-to-sprite-sheet output
- Body parts, bones, pivots, and scene structure
- Sprite-sheet safe gutters and slicing
- Frame semantics
- Full-frame boss and elite rule
- Style and physicality
- Naming and manifest format

## Entity Classes

Use these requirements unless the active task is stricter.

| Entity | Movement | Primary attack | Extra attacks | Production technique |
| --- | ---: | ---: | ---: | --- |
| Playable hero | 5+ frames | 5+ frames | weapon variants if implemented | `Skeleton2D`/`Bone2D` + `AnimationPlayer` source rig by default; hybrid rig export if runtime needs sprites; legacy cutout only for existing maintenance |
| Normal enemy/monster | 5+ frames | 5+ frames | archetype-specific if implemented | `Skeleton2D`/`Bone2D` + `AnimationPlayer` when riggable or reusable; hybrid export if runtime needs sprites; full-frame only for non-riggable shapes |
| Summon/ally | 5+ frames | 5+ frames | summon special if implemented | `Skeleton2D` rig or hybrid export for riggable allies; full-frame/SpriteFrames only for non-riggable silhouettes; keep pivot stable |
| Elite | 5+ frames | 5+ frames | 2+ skill attacks, one per skill | full-frame only; no production cutout slicing |
| Boss | 5+ frames | 5+ frames | 2+ skill attacks, one per phase/skill | full-frame only; no production cutout slicing |

## Pipeline Decision Rules

Prefer a Godot-native production pipeline instead of unrelated frame-by-frame images when the entity has visible limbs, weapon, armor, cloak, tail, wings, horns, accessories, or several repeated animations. For riggable humanoids and reusable-part characters, the `Skeleton2D`/`Bone2D` + `AnimationPlayer` rig is the editable source of truth.

Use `Skeleton2D` / `AnimationPlayer` when:

- the user asks for game-ready reusable character animation;
- the entity has arms, legs, weapon, armor, cloak, or other moving parts;
- the same entity needs idle, walk/run, attack, cast, hit, death, or future equipment swaps.
- the task mentions anticipation, strike/cast/release, recovery, VFX marker,
  hitbox marker, direction-facing, body lean, or reusable weapons/limbs.

Use hybrid rig-to-sprite-sheet when:

- source motion should be rigged for consistency;
- the active game runtime still consumes `AnimatedSprite2D` / `SpriteFrames`;
- exported frames can keep identical canvas, pivot, baseline, and no cropping.
- the rig scene and `AnimationPlayer` clips remain stored as source assets.

Use direct full-frame sprite sheets when:

- each frame must be a coherent whole;
- the entity is an elite or boss runtime asset;
- the current art cannot be safely separated into reusable parts.

Use pure generated frames only for concept previews, rough motion exploration, reference sheets, or early visual direction. Never treat pure generated frames as final game assets without validation.

If accepted separated source parts are missing for a riggable humanoid, create a
Design handoff instead of hand-drawing or slicing parts inside Animator scope.

## Godot-Native Rig Output

Expected riggable character output:

```text
assets/characters/<entity_id>/
  source/<entity_id>_concept.png
  parts/head.png
  parts/torso.png
  parts/pelvis.png
  parts/upper_arm_l.png
  parts/lower_arm_l.png
  parts/hand_l.png
  parts/upper_arm_r.png
  parts/lower_arm_r.png
  parts/hand_r.png
  parts/thigh_l.png
  parts/shin_l.png
  parts/foot_l.png
  parts/thigh_r.png
  parts/shin_r.png
  parts/foot_r.png
  parts/weapon.png
  godot/<entity_id>_rig.tscn
  godot/<entity_id>_animations.tres
  preview/<animation>_preview.gif
```

Use this node shape unless the project already has a stricter scene convention:

```text
CharacterBody2D or Node2D
  VisualRoot
    Skeleton2D
      pelvis
        spine
          chest
            neck
              head
            shoulder_l
              upper_arm_l
                lower_arm_l
                  hand_l
            shoulder_r
              upper_arm_r
                lower_arm_r
                  hand_r
          cloak_root
        thigh_l
          shin_l
            foot_l
        thigh_r
          shin_r
            foot_r
      weapon_bone
  AnimationPlayer
  AnimationTree optional
  Hitboxes
  Hurtboxes
  Markers
    marker_hitbox
    marker_vfx
    marker_sound
    marker_foot_l
    marker_foot_r
```

Rig requirements:

- Every reusable part sprite is attached to, bound to, or explicitly follows a
  named `Bone2D`; do not leave production body parts as unrelated loose sprites.
- Bone names are lowercase snake_case and stable enough for tooling and docs.
- `AnimationPlayer` clips are the authored source for `idle`, `move`/`walk`,
  `attack_primary`, optional `attack_<skill_id>`, `hit`, and `death`.
- `AnimationTree` is optional runtime blending; it must not replace the authored
  `AnimationPlayer` clips.
- Attack clips include anticipation, active/impact, and recovery sections.
- Marker/call tracks document hitbox on/off, VFX release, sound, projectile or
  weapon release, and footstep moments when applicable.

Animate `Bone2D` rotation/position, weapon movement, cloak/tail secondary motion, hitbox enable/disable, VFX markers, sound markers, and footstep markers through `AnimationPlayer`.

## Hybrid Rig-To-Sprite-Sheet Output

When runtime expects `AnimatedSprite2D`, export from the rig into sprite sheets:

```text
assets/sprites/<category>/<entity_id>_idle.png
assets/sprites/<category>/<entity_id>_run.png
assets/sprites/<category>/<entity_id>_attack_01.png
assets/sprites/<category>/<entity_id>_hit.png
assets/sprites/<category>/<entity_id>_death.png
assets/sprites/<category>/<entity_id>_animations.json
assets/sprites/<category>/<entity_id>_preview.gif
```

Each exported sheet must have transparent background, identical frame size for the animation, identical pivot, feet aligned on one baseline, safe discard-only gutters between frames, safe outer padding, no cropped weapons/cloaks/horns/VFX, no baked text/UI/shadow background, and no random props.

The exported sheet is not enough by itself for riggable characters. Keep the
rig scene, source parts, `AnimationPlayer` clips, and export metadata together
so future animation work can continue from the native Godot rig.

## Body Parts, Bones, Pivots, And Scene Structure

Humanoid separated parts should include:

```text
head, torso/chest, pelvis,
upper_arm_l, lower_arm_l, hand_l,
upper_arm_r, lower_arm_r, hand_r,
thigh_l, shin_l, foot_l,
thigh_r, shin_r, foot_r,
weapon
```

Optional parts: `neck`, `shield`, `cloak`, `hair`, `shoulder_armor_l`, `shoulder_armor_r`, `tail`, `wing_l`, `wing_r`, `horn_l`, `horn_r`.

Part rules:

- PNG with alpha transparency and clean edges.
- Add overlap under joints to hide rotation gaps.
- No background and no baked motion blur unless requested.
- Preserve style, lighting, material quality, and proportions across all parts.

Bone names must be lowercase snake_case. Do not use names like `Bone2D3`, `arm copy`, or `node_15`.

Pivot rules:

- Main character pivot: center between feet on the ground baseline, unchanged across animations.
- Floating pivot: stable hover anchor, documented relative to body/shadow.
- Weapon pivot: grip/hand position; tip may move, grip must remain attached.
- Body pivots: arms from shoulder/elbow/wrist, legs from hip/knee/ankle, head from neck, cloak from attachment point.

For exported sprite sheets, every frame must have identical canvas size, stable baseline, and documented pivot JSON.

## Sprite-Sheet Safe Gutters And Slicing

When generating, exporting, or accepting a sprite sheet that will be sliced into runtime frames, protect every frame with empty discard-only gutters. The gutter is not part of the runtime frame; it exists only so crop rectangles cannot catch pixels from neighboring frames.

Minimum source-sheet spacing:

| Runtime cell size | Minimum gutter between cells | Minimum outer padding |
| --- | ---: | ---: |
| `256x256` | `24 px` | `24 px` |
| `384x384` | `32 px` | `32 px` |
| `512x512` | `48 px` | `48 px` |

For cells larger than `512x512`, use at least `8%` of the larger cell dimension, rounded up to the next `8 px`, for both gutter and outer padding.

Generation prompts for full-frame or AI-authored sheets must explicitly request:

- one pose per cell, fully contained inside its own cell;
- large empty transparent spacing between all frames;
- empty transparent padding around the outside of the sheet;
- no overlap between silhouettes, weapons, shadows, projectiles, VFX, cloth, horns, tails, or neighboring cells.

Slicing rules:

- Runtime frame rectangles must crop only the intended cell content area and must exclude gutter pixels.
- Do not slice exactly through visible content, alpha fringe, shadows, weapon trails, or VFX.
- If a source sheet has too little gutter, regenerate it or rebuild it with larger spacing before integration.
- For generated sheets, reject outputs where any foreground or alpha bleed touches a gutter boundary or crop edge unless the active task intentionally documents a full-cell VFX effect.
- Contact sheets for QA may be visually compact, but source sheets used for runtime slicing must keep the safe gutters above.

## Frame Semantics

Movement 5-frame minimum:

1. Contact / low point.
2. Passing / lift.
3. Opposite contact.
4. Passing / lift.
5. Settle / return, compatible with looping.

Attack 5-frame minimum:

1. Anticipation.
2. Windup.
3. Active strike, bite, cast, throw, or release.
4. Follow-through.
5. Recover.

For 7-9 frame boss attacks, add clearer anticipation, impact hold, recoil, and settle frames.

AnimationPlayer attack timelines must identify phases:

```text
0.00s anticipation start
0.12s weapon pullback
0.22s swing/cast start
0.30s hitbox or VFX marker enabled
0.38s impact/release frame
0.44s hitbox disabled
0.65s recovery end
```

Hitboxes should only be active during active/impact frames.

For rig-first characters, record the same phases in `AnimationPlayer` marker or
call tracks, even if exported SpriteFrames are the runtime delivery.

## Full-Frame Boss And Elite Rule

For bosses and elites, do not ship a production animation by slicing one static sprite into limbs. It is acceptable to use a rough cutout prototype only to describe desired motion in a handoff. Final boss/elite runtime art must be a full-frame sprite sheet or equivalent full-frame animation export where each frame is drawn/generated as a coherent whole.

## Style And Physicality

- Keep the same silhouette identity across all frames.
- Keep feet, shadow, and pivot stable; do not let the character slide unless the attack intentionally lunges.
- Preserve weapon/held-object continuity.
- Use secondary motion: cloth, hair, tail, wings, aura, weapon recoil, breathing.
- Do not over-animate combat-scale sprites; readability beats tiny detail.
- Keep transparent backgrounds and no baked labels.

## Naming

Prefer these names:

- `move` for generic movement loops, or `walk` when the runtime already uses `walk`.
- `attack_primary`.
- `attack_<skill_id>` for elite/boss skills.
- `idle`, `hit`, `death` when present.

Suggested runtime paths:

- `assets/characters/<entity_id>/godot/<entity_id>_rig.tscn`
- `assets/characters/<entity_id>/godot/<entity_id>_animations.tres`
- `assets/characters/<entity_id>/parts/<part_name>.png`
- `assets/sprites/characters/<character_id>_anim_sheet.png`
- `assets/sprites/enemies/<enemy_id>_anim_sheet.png`
- `assets/sprites/elites/<elite_id>_anim_sheet.png`
- `assets/sprites/bosses/<boss_id>_anim_sheet.png`
- `assets/sprites/<category>/<entity_id>_spriteframes.tres`

Preserve existing project paths when replacing active assets, and document any migration.

## Manifest Format

Write a manifest under `build/qa/<task>/animation_manifest.json`:

```json
{
  "entities": [
    {
      "id": "boss_rift_warden",
      "kind": "boss",
      "production_pipeline": "full_frame_spritesheet",
      "locomotion": "levitate",
      "sprite_sheet": "assets/sprites/bosses/boss_rift_warden_anim_sheet.png",
      "rig_scene": null,
      "source_parts": [],
      "canvas": {"width": 512, "height": 512},
      "frame_gutter_px": 48,
      "outer_padding_px": 48,
      "pivot": "center_hover_anchor",
      "cutout_used": false,
      "transparent_background_checked": true,
      "no_crop_checked": true,
      "safe_slicing_checked": true,
      "skills": ["rift_zone", "gravity_well", "phase_transition"],
      "animations": [
        {"name": "move", "frames": 6, "fps": 9, "loop": true},
        {"name": "attack_primary", "frames": 7, "fps": 12, "loop": false},
        {"name": "attack_rift_zone", "frames": 8, "fps": 12, "loop": false},
        {"name": "attack_gravity_well", "frames": 8, "fps": 12, "loop": false},
        {"name": "attack_phase_transition", "frames": 9, "fps": 10, "loop": false}
      ]
    }
  ]
}
```

Run the bundled validator before closing a task.

For a rig or hybrid asset, include `production_pipeline`, `rig_scene`,
`source_parts`, `animations`, and exported `sprite_sheet`/`spriteframes` when
present. Use `production_pipeline: "skeleton2d_rig"` for native rig runtime
delivery and `production_pipeline: "hybrid_rig_spritesheet"` when the rig is the
source but SpriteFrames/sprite sheets are exported for runtime.

Minimum rig/hybrid manifest fields:

```json
{
  "id": "hero_berserk",
  "kind": "hero",
  "production_pipeline": "skeleton2d_rig",
  "rig_scene": "assets/characters/hero_berserk/godot/hero_berserk_rig.tscn",
  "source_parts": [
    "assets/characters/hero_berserk/parts/head.png",
    "assets/characters/hero_berserk/parts/torso.png"
  ],
  "animation_player_node": "AnimationPlayer",
  "bone_hierarchy": ["pelvis", "spine", "chest", "head", "upper_arm_l", "lower_arm_l", "hand_l"],
  "animation_player_clips_checked": true,
  "timeline_markers_checked": true,
  "transparent_background_checked": true,
  "no_crop_checked": true
}
```
