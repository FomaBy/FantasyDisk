---
name: fantasydisk-animation-director
description: "Use this skill when planning, generating, rigging, integrating, validating, or fixing FantasyDisk character, monster, summon, elite, or boss animations in Godot, especially rig-first Skeleton2D/Bone2D + AnimationPlayer workflows for humanoids and reusable parts, hybrid rig-to-sprite-sheet exports, AnimationTree wiring, attack/cast/hit/death states, timeline markers, SpriteFrames, sprite sheets, manifests, pivots, previews, and animation smoke tests."
---

# FantasyDisk Animation Director

Use this skill to turn accepted FantasyDisk creature art into game-ready animation assets and runtime wiring. Keep Animator ownership: motion, pivots, Skeleton2D/Bone2D rigs, SpriteFrames, AnimationPlayer/AnimationTree, timing readability, and animation smoke belong here; final redraw/source art belongs to Design; gameplay damage, targeting, balance, and lifecycle belong to Back-end.

## Required Reading

In a FantasyDisk repo checkout, read these before changing animation work:

- `AGENTS.md`
- `docs/process/agent_role_boundaries_and_handoffs.md`
- `docs/design/systems/animation.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- the active task file and linked Jira context

For detailed production standards, read `references/fantasydisk-animation-standards.md`.

## Rig-First Animation Pipeline

For new playable humanoids, humanoid enemies, summons/allies with reusable
parts, and any character that needs controlled arms, legs, weapons, cloaks, or
future equipment swaps, use a Godot-native rig as the source of truth:
`Skeleton2D` + named `Bone2D` hierarchy + `AnimationPlayer` timelines.

Author the real motion in `AnimationPlayer` first. Sprite sheets and
`SpriteFrames` are delivery/export artifacts when the live runtime still expects
`AnimatedSprite2D`, not the primary animation source for riggable characters.
Use `AnimationTree` only as optional runtime blending on top of authored
`AnimationPlayer` clips.

Direct full-frame SpriteFrames remain correct for non-riggable creatures,
coherent boss/elite final runtime sheets, historical assets, or tasks that
explicitly require frame-by-frame animation. Legacy cutout is allowed only for
maintaining existing motion; do not choose it for new production character work.

### Skeleton-Friendly Source Art Contract

Do not invent final source parts inside Animator scope. If accepted separated
parts are missing, create a Design handoff with this contract instead of
redrawing the character yourself.

Required humanoid source package:

- Neutral front-facing A- or T-pose; limbs separated enough to define clean
  joints and pivots.
- Transparent RGBA PNGs with no matte, checkerboard, baked shadow, frame, text,
  UI, or background.
- Separate parts: `head`, `torso`, `pelvis`,
  `upper_arm_l`, `lower_arm_l`, `hand_l`,
  `upper_arm_r`, `lower_arm_r`, `hand_r`,
  `thigh_l`, `shin_l`, `foot_l`,
  `thigh_r`, `shin_r`, `foot_r`.
- Optional parts as needed: `neck`, `cloak_*`, `robe_*`, `hair_*`,
  `shoulder_armor_l`, `shoulder_armor_r`, `shield`, `weapon_socket_marker`.
- Each hinged part must include overlap under the joint so rotation does not
  create gaps. Document pivot points in source coordinates.
- Empty hands by default for playable classes unless the task explicitly says
  the body owns a held item; weapon visuals remain socket-owned.
- Preserve the accepted style, palette, silhouette identity, and combat-scale
  readability of the current class.

Skeleton source packages should include a manifest validated with:

```bash
python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py \
  path/to/skeleton_source_manifest.json
```

## Non-Negotiable Output Contract

Every animated playable character, monster, summon, elite, or boss must have at least, unless the active task explicitly sets `attack_required=false` because weapon visuals own attacks:

- `move` or `walk`: minimum 5 frames, looping.
- `attack_primary`: minimum 5 frames, non-looping, using the main weapon, held object, natural body attack, or lore-appropriate cast gesture.

For riggable humanoid or reusable-part entities, these states must exist as
`AnimationPlayer` clips on the rig first. Exported frame counts are still
recorded for QA, but the rig timeline is the editable source.

Movement must be real motion:

- Legged entities: use a readable walk/run cycle with contact, passing, lift, and recovery frames.
- Floating/lore entities: use levitation with tucked legs, robe/limb settling, vertical drift, and secondary motion. Do not ship a static bob as the only movement.

Attack must read as a complete action:

- Anticipation.
- Windup.
- Active strike/cast/release.
- Follow-through.
- Recovery.

Sprite-sheet slicing safety is mandatory:

- Generated/source sprite sheets must include discard-only empty gutters between frames and empty outer padding around the sheet.
- Minimum gutter and outer padding: `24 px` for `256x256` cells, `32 px` for `384x384` cells, `48 px` for `512x512` cells; for larger cells use at least `8%` of the cell size, rounded up to the next `8 px`.
- Runtime frame rectangles must exclude gutter pixels. Never slice through the visual content boundary or include pixels from adjacent frames.
- Reject or regenerate sheets where silhouettes, weapons, VFX, shadows, or alpha bleed touches another frame, the gutter, or the crop edge.

For elites and bosses:

- Produce smooth full-frame sprite-sheet animation. Do not create production boss/elite animation by cutting the static sprite into body parts.
- Add multiple different attack patterns, one per distinct gameplay skill/pattern whenever available.
- Use at least 5 frames per attack pattern; prefer 7-9 frames for boss signature attacks.
- Keep motion realistic, weighted, and readable at combat scale.

## Pipeline Choice

Choose the production pipeline in this order:

- Use `Skeleton2D` + `Bone2D` + `AnimationPlayer` by default for humanoids,
  riggable monsters, allies, summons, and any entity with reusable limbs,
  weapon sockets, armor, cloak, tail, wings, horns, or future state variants.
- Use a hybrid rig-to-sprite-sheet workflow when the source motion should remain
  rigged, but the current runtime expects `AnimatedSprite2D` / `SpriteFrames`.
  The exported sheet must preserve canvas, pivot, baseline, and safe gutters.
- Use direct full-frame sprite sheets when every frame must be a coherent whole,
  especially for elite/boss runtime animation or non-riggable silhouettes.
- Use pure AI-generated frame sequences only for concepts, motion exploration,
  or handoff references unless they pass production validation.

For elites and bosses, a rig may be used only as an internal authoring aid when the parts were intentionally prepared for rigging; never slice one static boss/elite sprite into parts and ship that as production motion.

## Workflow

1. Identify entity IDs and role: `hero`, `enemy`, `summon`, `elite`, or `boss`.
2. Enumerate gameplay attack patterns from docs and code before animating:
   - player weapons/classes: class weapon IDs and animation events;
   - enemies/elites: archetype, elite behavior, `elite_attack_id`, phases;
   - bosses: boss skills, phase attacks, hazards, summons, bites/slams/casts.
3. Choose the animation source:
   - Existing accepted full-frame sheets: integrate and validate.
   - Accepted riggable character art: build separated PNG parts into a
     `Skeleton2D`/`Bone2D` hierarchy and author `AnimationPlayer` timelines.
   - Runtime still expects sprites: author with the rig, then export stable
     sprite sheets and `SpriteFrames` metadata from that rig.
   - Missing source art or separated parts: create a Design handoff with the
     skeleton-friendly source contract and wait for accepted assets.
   - Current static boss/elite art insufficient for full-frame animation: create a Design handoff instead of faking smooth animation with cutout slicing.
4. Use consistent canvas, pivots, and rig anchors:
   - Heroes: default `384x384` cell unless the active task specifies otherwise.
   - Normal enemies/summons: use current native art size or a documented `256x256`/`384x384` cell.
   - Elites and bosses: default `512x512` full-frame cells; use larger only when a task explicitly accepts the VRAM/runtime cost.
   - Sprite sheets: add safe gutters/outer padding before slicing (`24 px` for `256`, `32 px` for `384`, `48 px` for `512`; larger cells use at least `8%` rounded up to `8 px`).
   - Legged pivot: bottom-center foot point. Floating pivot: visual center plus documented shadow/hover anchor.
   - Rigged humanoid pivot: root at center between feet on the ground baseline; weapon grip stays attached to the hand.
   - Rig anchors: root at feet, pelvis/spine/chest/head chain for humanoids,
     left/right limb chains, `weapon_bone` or `weapon_socket`, and marker nodes
     for hitbox, VFX, sound, and footsteps where relevant.
5. Build the Godot rig and timelines:
   - Primary rig path: `Skeleton2D` with named `Bone2D` nodes, body-part sprites
     attached/bound to their bones, and an `AnimationPlayer` next to the visual
     root.
   - Required clips: `move` or `walk` loop true, and `attack_primary` loop false
     unless the active task explicitly sets `attack_required=false`.
   - Recommended clips: `idle`, `hit`, `death`; required when the task asks for
     those states.
   - Elite/boss skill clips: `attack_<skill_id>` loop false for every skill,
     while final runtime delivery still obeys the full-frame boss/elite rule.
   - Attack timelines must contain anticipation, active/impact, recovery, and
     documented marker/call-track moments for hitbox, VFX, sound, and weapon
     release when those events exist.
   - If a SpriteFrames runtime output is needed, export it from the rig after
     the `AnimationPlayer` clips are complete.
6. Generate QA artifacts:
   - contact sheet with frame numbers and animation names;
   - GIF or frame preview for motion;
   - animation manifest JSON with `animation_player_node`, `bone_hierarchy`,
     `animation_player_clips_checked`, and `timeline_markers_checked` for
     rig/hybrid pipelines;
   - rig scene path, body-part list, bone hierarchy, marker table, and export
     metadata when using a rig/hybrid pipeline;
   - smoke-test output.
7. Validate the manifest with:

```bash
python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py \
  build/qa/<task>/animation_manifest.json
```

8. Run project tests after integration:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --path /Users/sergeyfomin/Documents/AI\ Agent \
  --script res://tests/animation_smoke_test.gd
```

Run `runtime_smoke_test.gd` too when animation changes touch shared runtime paths, entity spawning, player/enemy scripts, boss lifecycle, pause, or cleanup.

## Handoff Rules

Create a Design handoff when:

- new/redrawn full-frame art is needed;
- separated body parts with overlap under joints are needed for a clean rig;
- accepted riggable source lacks required humanoid parts, pivots, transparency,
  empty hands, or style anchors;
- current art cannot support a 5-frame movement or attack cycle without ugly warping;
- an elite/boss would otherwise need cutout slicing to fake motion.

Create a Back-end handoff when:

- attack timing events, skill IDs, phase callbacks, state machine hooks, or spawn lifecycle are missing;
- SpriteFrames/AnimationPlayer integration requires runtime API changes outside animation ownership.

Never change damage, balance, targeting, enemy AI, route map, reward flow, or UI art to make an animation fit.

## Documentation

For every completed animation task, update the task file with:

- entity IDs;
- animation names and frame counts;
- source sheet paths and final runtime paths;
- `Skeleton2D` rig scene, bone hierarchy, body-part paths, and exported sheet paths when applicable;
- canvas size, pivot, fps, loop flags;
- sprite-sheet gutter size, outer padding, and safe-slicing check result when any sheet is generated or exported;
- `AnimationPlayer` clip names, timeline phases, call tracks, and
  hitbox/VFX/sound/footstep marker timing when gameplay-facing events exist;
- elite/boss skill-to-animation mapping;
- whether full-frame or cutout was used;
- QA artifact paths and test commands.

Update `docs/design/systems/animation.md`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, and `CHANGELOG.md` when runtime behavior or active asset paths change.
