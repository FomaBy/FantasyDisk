# Animation

Обновлено: 2026-07-04

Animator ownership описан в `docs/process/agent_role_boundaries_and_handoffs.md`. Back-end должен не полировать motion, а предоставлять стабильные states/API.

## Architecture

- Игровые сущности используют polished full-art sprites как видимый слой.
- `scripts/cutout_rig_2d.gd` собирает rig/cutout parts для движения, squash, socket, hit/action timing.
- Source PNG остаются меню/fallback-изображениями.
- `scripts/sliced_rig_manifest.gd` хранит данные нарезки.
- Read-only audit SCRUM-173 (2026-06-13) зафиксировал матрицу покрытия в `docs/design/reviews/animation_rig_audit_2026_06.md`: базовый rig/state слой широкий, но 0.1.4 follow-up нужен для legacy player weapon-action hooks, enemy archetype assertions, hit/death coverage, weapon timing/VFX sync и Design-ready parts для новых боссов/мини-элиток.
- Directive 2026-06-29: future character animation integration must follow
  `fantasydisk-pixellab-animation-integrator`. Use PixelLab-authored idle/move
  packs as the source of truth, import 8 directions, normalize transparent
  full-frame runtime PNGs, rebuild SpriteFrames, wire directional movement/idle,
  and animate playable-character Hero Select previews with clockwise direction
  rotation. Historical full-frame audits remain valid as evidence, but the old
  rig/sprite-sheet animation-director skill is retired.
- SCRUM-869 (2026-07-04) adds the repo importer
  `tools/update_pixellab_character_animations.py` for playable-character PixelLab
  refreshes. It reads `ProgressionData.character_ids()`, downloads the manifest
  `pixellab_character_id` package from PixelLab, requires 8 idle rotations and
  6+ movement frames for every direction before touching a character, normalizes
  runtime PNGs to `512x512`, rebuilds generic and directional `SpriteFrames`,
  updates manifests/alpha-bbox reports, and records blockers under
  `build/qa/pixellab_character_animation_refresh/report.json`. The SCRUM-869
  pass refreshed Assassin, Biologist, Chemist, Dark Mage, Druid, Guitarist,
  Knight, Priest, Ranger, Robot and Thief. Current PixelLab blockers are:
  Berserk missing south movement row completeness, Soldier missing south and
  north-east movement row completeness, Elementalist manifest ID
  `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f` returning 404/not found, Sniper
  missing south and north-west movement row completeness, Engineer missing north
  movement row completeness, and Doctor missing north movement row completeness.
  Those blocked characters stay on their already-valid live runtime packs until
  PixelLab exposes complete data; no legacy/manual fallback was used for refreshed
  source.
- FAN-2606 (2026-08-17) reviewed the live Sniper pack that SCRUM-869 left in
  place (SCRUM-433 source, PixelLab character
  `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`) and rejected it: `south`,
  `south-east`, `east` and `south-west` are clean, but `north-east`, `north`,
  `north-west` and `west` break identity between move frames `02` and `03` —
  the cloak and arm/shoulder gear appear or disappear mid-loop, so a 10 fps
  walk flickers the silhouette ~1.7x per second. The defect is in the PixelLab
  source rows, not in runtime normalization: canvas, `245` px visible height,
  footline `y=479` and pivot `x≈255` are constant across all 56 frames, the
  `.tres` maps every direction to its own textures with no mirror stand-in, and
  Hero Select is unaffected because its preview cycles only the eight (clean)
  idle frames. Fixing it needs regenerated PixelLab rows for those four
  directions, i.e. an `art_assets` pass — not a runtime change. Evidence:
  `tools/build_fan2606_sniper_animation_review.py`,
  `tools/capture_fan2606_sniper_walk.gd`, sheets under
  `docs/design/previews/fan2606_sniper_*` (regenerated per revision; they always
  describe the pack at the commit that contains them).
- FAN-2606 re-review after the FAN-2845 regeneration (`c1fc219e`) — `north` and
  `west` are now clean and accepted; `north-east` and `north-west` still drift
  and stay rejected. `north-east` loses the cloak on move frames `00`–`01` and
  regains it from `02`; `north-west` carries a wide cape plus orange arm/leg
  straps on `00`–`02` and drops both on `03`–`05`. Both breaks are in the new
  PixelLab source rows (`4b1c980c-…`, `98195326-…`), not in normalization —
  `assets/sprites/characters/pixellab/sniper/` shows the same split before the
  512 px pass. Useful calibration from this pack: within a move row the
  alpha-area max/min ratio is `1.05`–`1.18` for every accepted direction and
  `1.24` / `1.38` for the two rejected ones, and the largest single-frame area
  jump is `≤14.3%` accepted vs `20.6%` / `31.4%` rejected. The bands are too
  close to gate on automatically — treat them as review aids, not a threshold.
- FAN-2606 accepted the Sniper pack after FAN-2855 (`c8c4326f`) regenerated
  `north-east` / `north-west` in `mode=v3` with the action description pinning
  cloak and straps. FAN-2855 wrote **source frames only** — the manifest's old
  "runtime integration files intentionally untouched" note meant the game still
  played the rejected FAN-2845 rows — so FAN-2606 normalized those two rows into
  the runtime pack with `tools/normalize_pixellab_rows.py`, which reuses
  `normalize_frame()` from the importer instead of re-deriving the maths.
  Re-normalizing the two untouched idle frames reproduced the committed runtime
  PNGs byte-for-byte, which is the check that the parameters were right. All
  eight rows now sit in the stable band (area max/min `1.05`–`1.18`, largest
  single-frame jump `≤14.3%`) and `animation_roster_audit.py` reports zero sniper
  findings. **Any source-pack regeneration needs this normalization step before
  the art reaches the screen** — that is the gap this card hit twice.
  Residual: `north-west` is the calmest row in the pack (mean per-step diff
  `2.17` vs `2.17`–`4.52` across the pack) and reads closer to a straight-behind
  view than a three-quarter one; consistent and artifact-free, but the weakest
  row if the pack is ever revisited.
- FAN-2596 (2026-08-17) audited the live Dark Mage pack (SCRUM-704 240–250 px
  redraw, PixelLab character `9bb0eca8-5afe-49d4-8e56-7115a45efdcc`,
  `walking-6-frames`) and **accepted it unchanged** — no regeneration pass was
  needed. All 8 idle rotations and all 8 × 6 move rows are explicit: every
  `dark_mage_*_west*` frame is pixel-distinct from its east counterpart flipped
  (mean abs delta `3.55`–`7.57`, zero identical frames, so no mirror
  substitution), and `north` is a true back view. Normalization is exact rather
  than merely stable: every one of the 56 runtime frames is a 512 px canvas with
  visible height `246` and the footline pinned at `y=480` (**0 px** drift), and
  alpha is fully binary (only value `255`, no anti-aliased fringe or stray
  specks). `alpha_bbox_report.json` covers all 56 frames, so PixelLab provenance
  is complete. Attack stays weapon-owned: `dark_mage_spriteframes.tres` holds
  only `idle`/`move`/`walk` × 8 directions (1-frame idle, 6-frame locomotion at
  10 fps, `walk_*` aliasing the `move_*` sources), no `attack`/`cast`/`death`
  row, all 56 textures drawn from `dark_mage_pixellab/`, and the body rig forces
  `flip_h = false` on directional rows (`player.gd::_update_sprite_facing`).
  Evidence: `tools/build_fan2596_dark_mage_animation_review.py`,
  `tools/capture_fan2596_dark_mage_walk.gd`, sheets under
  `docs/design/previews/fan2596_dark_mage_*`, captures under
  `build/qa/fan2596_dark_mage/` (captures are build artifacts, not committed).
  Two findings were investigated and knowingly accepted rather than hidden:
  (1) `animation_roster_audit.py` flags `move_north`/`walk_north` as a loop
  discontinuity (`wrap diff 14 vs mean step 6`), but that is the coarse
  ratio-vs-mean guard misfiring on the calmest row in the pack — the wrap step
  (`3.59`) is *smaller* than the row's own largest inner step (`3.69`, frame
  `02→03`), so the loop is continuous and the ratio only trips because the back
  view has the least visible limb motion; (2) the hand aura is uneven across
  directions — six face/side rows carry the violet aura through the walk cycle,
  `north` legitimately hides both hands behind the cloak, but `south` walks with
  both hands lowered and no aura at all even though its idle has it, and a
  ~16 px cyan eye glow appears in only `south` frames `03..05` and `south-east`
  frames `00..02`. Both are per-direction generation variance in a "subtle
  controlled arcane aura around empty open hands" the manifest prompt defines as
  an effect, not a held prop; both are invisible at the live combat scale
  (`0.7168`) in the 720p/1080p captures. Consistent and artifact-free otherwise,
  but the `south` locomotion row is the weakest row if the pack is ever
  revisited by the art lane.
- FAN-2598 (2026-08-17) audited the live Druid pack (SCRUM-426, PixelLab
  character `4078113b-fece-4087-a035-9ed3714a6514`) and **accepted it
  unchanged** — no regeneration pass was needed. All 8 idle rotations and all
  8 × 6 `walking-6-frames` move rows are explicit: every `druid_*_west*` frame
  is pixel-distinct from its east counterpart flipped (no mirror substitution),
  and `north` is a true back view. Every runtime frame is a 512 px transparent
  canvas with the footline stable at `y≈486-487` (bbox drift ≤1 px) and
  horizontal anchor drift within normal gait sway. `animation_roster_audit.py`
  reports zero druid findings; live 720p/1080p captures show identity-stable,
  artifact-free loops. Attack stays weapon-owned: `druid_spriteframes.tres`
  holds only `idle`/`move`/`walk` × 8 directions (1-frame idle, 6-frame
  locomotion at 10 fps) and the body rig forces `flip_h = false` on directional
  rows. Evidence: `tools/build_fan2598_druid_animation_review.py`,
  `tools/capture_fan2598_druid_walk.gd`, sheets under
  `docs/design/previews/fan2598_druid_*`, captures under
  `build/qa/fan2598_druid/` (captures are build artifacts, not committed).
- FAN-2597 (2026-08-17) audited the live Doctor pack (SCRUM-705 v3 redraw,
  PixelLab character `3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`) and **accepted it
  unchanged** — no regeneration pass was needed. The card's open question was
  `north`: the manifest carries a real PixelLab `north` animation
  (`cc8114ed-774d-4acb-b86e-0a82a7b8fae0`) and the frames confirm it — a true
  back view (hood rear, no beak), pixel-distinct from every other direction,
  not a mirror stand-in: all 16 direction anchors (8 idle + 8 move `00`) hash
  distinct, and no direction equals another flipped. Every runtime frame is
  244 px visible height on a 512 px canvas with the footline pinned at `y=480`.
  `animation_roster_audit.py` reports zero doctor findings (the perceptual
  loop-continuity check passes all eight rows); alpha-area max/min spans
  `1.07`–`1.30` (`east`/`west` widest from profile gait sway — review-aid
  territory per the FAN-2606 calibration note, not a rejection signal), and the
  live 720p/1080p captures show identity-stable, artifact-free loops. Attack
  stays weapon-owned: `doctor_spriteframes.tres` holds only
  `idle`/`move`/`walk` × 8 directions and the body rig forces `flip_h = false`
  on directional rows. Evidence: `tools/build_fan2597_doctor_animation_review.py`,
  `tools/capture_fan2597_doctor_walk.gd`, sheets under
  `docs/design/previews/fan2597_doctor_*`, captures under
  `build/qa/fan2597_doctor/` (captures are build artifacts, not committed).
- FAN-2594 (2026-08-17) audited the live Biologist pack (SCRUM-421 source,
  SCRUM-869 refresh, PixelLab character
  `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`) and **accepted it unchanged** — no
  regeneration pass was needed. All 16 direction anchors (8 idle + 8 move `00`)
  hash distinct and no direction equals another flipped, so every row is real
  art, not a mirror stand-in. Every runtime frame is 245 px visible height on a
  512 px canvas with the footline pinned at `y=496` and pivot `x≈256`; the
  `.tres` maps all 27 rows (`idle`/`move`/`walk` × 8 + 3 south aliases) to that
  direction's own textures at the fleet-standard 1-frame idle / 6-frame 10 fps
  locomotion timing. `animation_roster_audit.py` reports zero biologist
  findings; alpha-area max/min spans `1.07`–`1.23` with the largest single-frame
  jump `19.1%` (`west`, profile gait sway — matches the accepted doctor `west`
  at `1.23` and stays under the FAN-2606 rejection examples). Attack stays
  weapon-owned: the body pack holds no attack rows and the body rig forces
  `flip_h = false` on directional rows. Residuals (review-aid, below the
  FAN-2606 silhouette-flicker bar, colour-level only): the `west` hood-front
  element
  reads as a cream vial on move `00`–`02` and an exposed cheek on `03`–`05`
  (~6×7 px at live scale), and the `north-west` satchel flap flips dark/lit at
  the same stride boundary; both are within-silhouette tone changes an
  `art_assets` pass could clean up if the pack is ever revisited. Evidence:
  `tools/build_fan2594_biologist_animation_review.py`,
  `tools/capture_fan2594_biologist_walk.gd`, sheets under
  `docs/design/previews/fan2594_biologist_*`, captures under
  `build/qa/fan2594_biologist/` (build artifacts, not committed).
- SCRUM-885 (2026-07-08) performs a focused Knight-only run through the same
  importer using PixelLab character `c1a7d633-7353-4861-aea3-8d937b601cba`
  (`FantasyDisk Knight PixelLab SCRUM-430 no-shield 2026-06-30`). It regenerated
  Knight source/runtime frames and reports with 8 idle directions and 6-frame
  directional `move/walk` rows; no legacy/manual fallback was used.
- SCRUM-895 adds scene-specific PixelLab weapon-motion bridges for Berserk Axe
  and Hammer without modifying shared hit logic. Axe uses an 8-frame broad
  cleave pack plus exact `180° / 250px` arc choreography; Hammer uses an
  8-frame overhead pack with authored impact frame 5, exact-radius shock ring
  and optional backend center/scale hooks from SCRUM-1043. Sword remains on its
  existing scene/script and is the unchanged readability reference. Source,
  alpha/gutter report, contact sheet and live Godot capture are under
  `docs/design/references/scrum895_berserk_axe_hammer_vfx/` and
  `docs/design/previews/scrum895_berserk_axe_hammer_*`.
- SCRUM-351 added `scripts/full_frame_animation_registry.gd`: a Back-end
  SpriteFrames lookup/state adapter for `hero`, `enemy`, `ally`, `elite`, and
  `boss` entity IDs. It may create `FullFrameBody` (enemies/bosses) or reuse
  `AnimatedBody` (allies) when registry frames exist, while preserving existing
  cutout/static fallback when frames are missing.
- SCRUM-363 integrated the first SCRUM-352 enemy pilot: `rift_cutter` now has
  padded full-frame SpriteFrames at
  `assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres` with
  `move` 6f loop and `attack_primary`/runtime `attack`, `hit`, `death` 6f
  one-shots. The visual override is registry-only and does not change enemy AI,
  damage, targeting, spawn rules or balance.
- SCRUM-364 extended the same standard-enemy full-frame integration to
  `ash_marksman`, `spark_runner`, `stone_bruiser`, `bone_caller`, and
  `void_mage`. Each uses a padded `384x384` runtime canvas, `move` 6f loop,
  `attack_primary`/runtime `attack`, `hit`, and `death` 6f one-shots, and
  registry-only activation on the existing enemy scenes.
- SCRUM-365 added the next accepted standard-enemy batch: `venom_spitter` and
  `rift_shieldbearer` use the same padded SpriteFrames contract and registry-only
  scene activation.
- SCRUM-366 added `small_biter` to the same full-frame registry path with a
  compact `0.30` scale and the standard 6-frame move/attack/hit/death contract.
- SCRUM-367 added `bone_shaman` and `winged_spark` to standard-enemy full-frame
  registry coverage. `winged_spark` preserves the accepted source `hover_flap`
  row as a looped runtime state and exposes `hit` as a visual alias to keep the
  existing enemy hit-state contract.

## Full-Frame State Registry

- `FullFrameAnimationRegistry.registry_config(entity_kind, entity_id)` is the
  canonical runtime lookup point for full-frame SpriteFrames metadata.
- `configure_entity_visual()` attaches the animated body, applies scale/offset,
  hides the static fallback only after a valid SpriteFrames resource exists, and
  records `entity_kind`, `entity_id`, and `source_faces_left` metadata.
- `play_state(animated_body, state, direction)` accepts direct states
  (`move`, `attack`, `hit`, `death`) and variants such as
  `attack_slam_wave` or `<elite_behavior>:<attack_id>:<phase>`. The helper
  records `last_requested_state` and `last_resolved_state` for smoke tests and
  Animator debugging.
- Missing states resolve through safe aliases (`attack_primary` -> `attack`,
  `walk/run/levitate` -> `move`, skill variants -> `attack`) before falling
  back to idle/move. Missing resources return `null` and leave old visuals
  untouched.
- Damage windows, targeting, cooldowns, spawn rules, VFX spawn and cleanup
  remain owned by gameplay code. The registry is a visual state bridge only.
- SCRUM-379 adds death playback lifecycle ownership for explicit full-frame
  deaths: enemies with `FullFrameBody.death` play that row before delayed
  cleanup while leaving combat groups/collisions immediately after rewards are
  emitted; missing death rows keep the existing death-ghost fallback.
- SCRUM-865 extends the boss full-frame slice: all six live bosses now use
  PixelLab MCP-authored runtime rows in the current boss contract, including
  `bloodthorn_lion`. Bosses with full-frame `death` rows may remain visible for
  up to `2.4s`, and boss victory/act transition waits `2.0s` after the boss
  leaves combat groups so large death animations are not erased by immediate
  world cleanup.
- SCRUM-380 (2026-06-14) provides the complete Design source pack for explicit
  full-frame `death` rows: 19 entities, 114 transparent frames, row sheets,
  manifest `docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`
  and contact/readability previews. SCRUM-370 consumed all 19 rows into the
  existing runtime SpriteFrames paths for 4 allies, 4 route elites, all 6
  mini-elites and all 5 bosses; validation artifacts are under
  `build/qa/animation_integrate_all_move_attack_death_states/`.
- SCRUM-394 (2026-06-14) refreshes canonical source-sheet structure only:
  26 full-frame source sheets are now `1704x1144` RGBA and 19 death-row
  references are now `1704x304` RGBA, both using `256x256` cells with `24 px`
  transparent discard-only gutters and `24 px` outer padding. Runtime
  SpriteFrames, frame counts, states, timings and gameplay behavior were not
  changed.

### Runtime registry/loader audit (SCRUM-721)

Audit of the animation **runtime** loaders only (no art/motion/clip changes):

- **Safe fallback is intentional.** `sprite_frames_for`/`configure_entity_visual`
  guard every load with `ResourceLoader.exists` and a null/`SpriteFrames`-cast check,
  returning `null` so the entity keeps its static body. A registry entry is optional —
  a missing one is a valid no-op, not an error.
- **But a registered path must be valid.** A stale/typo'd `frames` path used to drop
  an entity's visual silently (null fallback, no evidence). Evidence now comes at
  test-time: `tests/full_frame_registry_integrity_test.gd` iterates **every**
  `FULL_FRAME_SPRITEFRAMES` entry (30) and asserts the resource exists, loads via the
  same `sprite_frames_for` path, is a `SpriteFrames` with ≥1 animation, and has
  `Vector2 scale/position` + `bool source_faces_left`. Prior coverage
  (`animation_smoke_test`) only exercised hardcoded entity lists, so a typo on a new
  entry could slip through; the integrity gate closes that.
- Runtime stays log-quiet on purpose (no per-spawn `push_warning` spam) — the CI gate
  is the evidence channel for stale registry paths.
- `sliced_rig_manifest`, `skeleton_player_rig_2d`, `cutout_rig_2d` resource/manifest
  loading reviewed and left as-is (covered by `sliced_rig_manifest_smoke_test` /
  `skeletal_rig_rest_det_smoke_test`; manifests preload part textures, smoke gates the
  string `source` path + `attack_part`/`torso` coverage).

### Eight-direction non-player contract (FAN-2519)

Runtime foundation for explicit eight-direction packs on non-player actors
(monsters, elites, bosses, summons); live 0.3.x packs keep their existing
west-facing/flip or `_left`/`_right` contracts until their 0.3.1 packs land.

- **Direction naming** mirrors the player contract: octant suffixes `east`,
  `south_east`, `south`, `south_west`, `west`, `north_west`, `north`,
  `north_east` (clockwise from east), rows named `<state>_<suffix>`
  (`move_north_east`, `attack_south`, `death_west`, `skill_shard_fan_east`,
  `strike_<suffix>` for `<behavior>:<attack_id>:<phase>` elites). A zero
  vector names `south` exactly like `player.gd`.
- **Contract declaration**: registry config key `explicit_eight_directions:
  true` (or owner meta `full_frame_explicit_eight_directions` for
  scene-driven entities). `configure_entity_visual` lifts the flag onto the
  animated body. A declared state must expose all eight directional rows;
  `has_full_directional_rows(frames, state)` is the audit helper, and
  `tests/full_frame_eight_direction_contract_test.gd` gates every registry
  entry declaring the flag.
- **Fallback policy**: directional rows resolve through the existing state
  candidate ladder first. A missing directional row degrades to the
  undirected row of the same state ladder — never to a horizontally-mirrored
  stand-in (`flip_h` is forbidden on the whole contract) and never to another
  actor's frames. Degradation is observable, not silent: the body carries
  `directional_row_resolved` / `directional_fallback_used` metas alongside
  the existing `last_requested_state` / `last_resolved_state` pair, plus
  `last_resolved_direction_suffix` for QA captures.
- **Last-facing persistence**: every non-zero direction passed to
  `play_state` is normalized into `last_facing_direction` on the body; zero
  directions reuse it (default west, matching west-facing sources). Enemies
  therefore resolve `hit`/`death` (which pass `Vector2.ZERO`) to the last
  movement facing. Horizontal `_left`/`_right` packs keep their stricter
  memory (`last_horizontal_facing_right`): vertical inputs collapse to the
  last horizontal facing.
- **State transitions**: the resolver switches rows only on explicit caller
  requests and never restarts an already-playing row (frame progress is
  preserved), so gameplay timing, collision and AI behavior are untouched —
  the registry remains a visual state bridge with no animation clock of its
  own. Death one-shots and delayed frees stay owned by
  `enemy.gd`/`ally_minion.gd`; both now measure death duration from the
  resolved directional row and detect death availability through the
  registry (`has_state`), which understands directional-only packs.
- **Pause/cleanup**: the registry spawns no timers, tweens or helper nodes,
  and the animated body inherits the actor's process mode — combat-world
  pause freezes eight-direction visuals with their owner, and all resolver
  state lives in body metas that die with the actor on death/despawn.
- FAN-2618 (2026-08-18) delivers the second live FAN-2519 pack and the first
  for `standard_monster`: `enemy/bone_shaman`. PixelLab MCP humanoid character
  `fa5b71b2-0532-404b-b5d9-b640d0bef7c0` (v3 mode, 8 rotations from a text
  description matching the existing skull-masked ram-horned staff shaman, no
  reference-image rotation) plus four v3 custom animation groups — `move`
  (shuffling forward with staff tap, 6f), `attack` (staff-slam curse cast,
  6f), `hit` (pained flinch, 4f), `death` (collapse and scatter, 6f) — each
  generated for all 8 directions (v3 jobs default `keep_first_frame=true`;
  the duplicate reference frame at index 0 of every direction was dropped
  before normalization, keeping the documented frame counts). No `hover`
  state — bone_shaman is ground-based, not flying. Source frames live under
  `assets/sprites/enemies/pixellab/bone_shaman/` with `manifest.json` and
  `alpha_bbox_report.json`; runtime frames are transparent `512x512` canvases
  under `assets/sprites/enemies/full_frame/bone_shaman/` normalized to
  `245px` visible height / `32px` bottom padding (fleet standard).
  `bone_shaman_spriteframes.tres` exposes exactly `idle_<dir>` / `move_<dir>`
  / `attack_<dir>` / `hit_<dir>` / `death_<dir>` for all 8 directions (40
  rows, no undirected fallback rows) and the registry entry sets
  `explicit_eight_directions: true`. bone_shaman has no elite-style skill
  phases; the plain `"attack"`/`"hit"`/`"death"` requests from `enemy.gd`
  resolve directly through the generic `_state_candidates` ladder. Old
  non-directional pack (single west-facing `move`/`attack`/`attack_primary`/
  `hit`/`death`, mirrored via `source_faces_left`) is backed up under
  `docs/design/backups/fan2618_bone_shaman_pre_directional/`. Build tooling:
  `tools/build_fan2618_bone_shaman_pack.py`. Evidence:
  `tests/full_frame_eight_direction_contract_test.gd` audits the live pack,
  `tests/full_frame_registry_integrity_test.gd` passes, and
  `tests/animation_smoke_test.gd::_test_full_frame_animation_registry` now
  branches its standard-enemy assertions on the registry's own
  `explicit_eight_directions` flag (mirroring the FAN-2901 mini-elite
  pattern) instead of a hardcoded ID list. AI, collision, damage and
  encounter timing are unchanged — registry-only visual integration.
- FAN-2628 (2026-08-17) delivers the first live FAN-2519 pack:
  `mini_elite/mini_rot_hound`. PixelLab MCP quadruped character
  `73b7080a-741b-4f80-8699-28b0674149ee` (dog template, standard-mode 8
  rotations) plus five animation groups — `move` (template
  `walk-6-frames`, 6f), `attack` (v3 custom "lunging bite attack", 6f),
  `hit` (v3 custom flinch, 4f), `death` (v3 custom collapse, 6f), and
  `skill_shadow_strike` (v3 custom shadow pounce, 6f) — each generated for
  all 8 directions. Source frames live under
  `assets/sprites/elites/pixellab/mini_rot_hound/` with `manifest.json` and
  `alpha_bbox_report.json`; runtime frames are transparent `512x512`
  canvases under `assets/sprites/elites/full_frame/mini_rot_hound/`
  normalized to `245px` visible height / `32px` bottom padding (fleet
  standard), except the last 2-4 `death_<dir>` frames whose splayed
  four-limb collapse pose is wider than tall and is instead scaled to fit
  the `512px` canvas width, so those frames read shorter than `245px` while
  the footline (`bottom_padding=32`) stays pinned. `mini_rot_hound_spriteframes.tres`
  exposes exactly `idle_<dir>` / `move_<dir>` / `attack_<dir>` / `hit_<dir>` /
  `death_<dir>` / `skill_shadow_strike_<dir>` for all 8 directions (48 rows,
  no undirected fallback rows) and the registry entry sets
  `explicit_eight_directions: true`. `mini_rot_hound` shares the
  `night_stalker` elite behavior (`elite_attack_id=shadow_strike`); the
  generic `attack_<dir>` rows cover the direct `_play_rig_action("attack",
  ...)` calls in `_strike_shadow_strike`, and `skill_shadow_strike_<dir>`
  covers the phased `night_stalker:shadow_strike:<windup|strike|recover>`
  state key from `_play_elite_attack_phase_animation` (the resolver's
  colon-split candidate ladder matches `skill_shadow_strike` for all three
  phases, so one row set covers the whole attack). `hit`/`death` resolve
  through the plain `"hit"`/`"death"` requests in `enemy.gd`. Old
  non-directional pack (`attack_primary`, `move`, `death`, `skill_rot_lunge`,
  `skill_bleed_howl`) is backed up under
  `docs/design/backups/fan2628_mini_rot_hound_pre_directional/` — its
  `skill_rot_lunge`/`skill_bleed_howl` rows were never live (the shared
  night_stalker resolver never requested those names). Build tooling:
  `tools/build_fan2628_mini_rot_hound_pack.py`. Evidence:
  `tests/full_frame_eight_direction_contract_test.gd` audits the live pack
  (`Eight-direction live packs audited: 1`),
  `tests/full_frame_registry_integrity_test.gd` passes, and
  `build/qa/animation_roster_audit/` carries the contact sheet + findings.
  AI, collision, damage and encounter timing are unchanged — registry-only
  visual integration.

- FAN-2619 (2026-08-19) converts the flying `standard_monster`
  `enemy/winged_spark` to the explicit-eight-direction PixelLab contract.
  Its source frames are in `assets/sprites/enemies/pixellab/winged_spark/`;
  normalized runtime frames are in
  `assets/sprites/enemies/full_frame/winged_spark/`, with all frames kept at
  `512x512`, `245px` visible height, and `32px` bottom padding. The SpriteFrames
  resource exposes `idle_<dir>` / `move_<dir>` / `attack_<dir>` / `hit_<dir>` /
  `death_<dir>` for all eight directions (40 rows, no undirected fallback rows)
  and registry `explicit_eight_directions: true`; `idle_<dir>` is the six-frame
  hover-flap loop because the resolver has no distinct hover state. The old
  flip-mirrored pack is retained in
  `docs/design/backups/fan2619_winged_spark_pre_directional/`; build tooling is
  `tools/build_fan2619_winged_spark_pack.py`. AI, collision, damage, and
  encounter timing are unchanged — registry-only visual integration.

## Player Motion

- FAN-1071 (2026-07-14) replaces the live playable footline dependency on
  legacy `sliced_rig_manifest.foot_y` with frame-aware alpha grounding. For all
  17 full-frame player resources, `player_sprite_grounding.gd` derives the
  visible bottom of the active texture and adjusts only
  `Player/VisualRoot/Body.position.y` whenever the animation or frame changes.
  The world/gameplay origin, `GroundCircle`,
  collision and damage geometry do not move. Canonical idle lift still drives
  the stable camera/weapon/feedback bias, while individual locomotion frames
  cannot vertically drift away from the platform. Legacy cutout/skeletal
  fallback keeps the authored manifest footline. Permanent coverage iterates
  every idle/move/walk frame of the full playable roster in
  `tests/feet_anchor_ground_circle_test.gd`.
- SCRUM-456 defines the new cartoon/anime playable-character restyle source
  contract. The Design package lives under
  `docs/design/references/chars_cartoon/` and establishes Berserk as the
  accepted exemplar candidate: `512x512` source cells, bottom-center pivot
  `(256, 470)`, safe source-sheet gutters/outer padding of `48 px`, rows
  `idle` and `walk` / `move`, 5 frames per row, transparent RGBA, empty hands
  and no baked weapon/tool. The exemplar source sheet is
  `docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
  (`2848x1168`). The included GIFs under `build/qa/scrum456_chars_cartoon/`
  are Design-source motion previews only; Animator must author real `idle` and
  `walk`/`move` keyframes with visible arm+leg motion before SpriteFrames or
  runtime integration. `attack_primary` is intentionally out of scope for this
  initiative.
- SCRUM-422 defines the 0.1.6 playable character redraw v2 source contract.
  Design source sheets for the v2 wave are bright/epic per class, transparent
  RGBA, `512x512` cells, bottom-center pivot `(256, 470)`, and only
  `idle` + `move/walk` rows. Attack rows are intentionally out of scope for this
  initiative. The anchor exemplar is the cleaned Berserk source under
  `docs/design/references/characters_v2/bright_epic_anchor/` with the
  asset-side accepted source copy at
  `assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`.
  Animator handoff after source acceptance should build `idle` 4-5f loop and
  `move` 5+f loop SpriteFrames/GIF/contact previews from the per-class sources,
  without changing gameplay, attack states, balance, collision, or weapon logic.
- SCRUM-420 Animator pass promotes Berserk's accepted v2 source into the live
  runtime resource `assets/sprites/characters/berserk_spriteframes.tres`.
  The resource now exposes `idle`, `walk`, and `move` only, each with 5 looping
  `512x512` full-frame frames derived from
  `docs/design/references/characters_v2/berserk/berserk_v2_idle_cell_512.png`.
  Runtime frames live under `assets/sprites/characters/full_frame/berserk/`,
  the safe 48px-gutter export sheet lives at
  `assets/sprites/characters/v2/berserk/berserk_v2_anim_sheet.png`, and the
  previous live SpriteFrames/frames are backed up under
  `docs/design/backups/scrum420_berserk_v2_pre_anim/`. QA artifacts live under
  `build/qa/scrum420_berserk_v2_anim/`; animation and runtime smokes pass.
  The bundled manifest validator was run and records the expected
  `missing attack_primary animation` failure because SCRUM-420 explicitly
  excludes attack animation.
- SCRUM-461 (2026-06-17) promotes the accepted SCRUM-456 cartoon/anime Berserk
  anchor into the same live runtime resource
  `assets/sprites/characters/berserk_spriteframes.tres`. It exposes `idle`
  (5f, 7fps), `walk` (5f, 9fps), and `move` (walk alias, 5f, 9fps) only, with
  transparent `512x512` frames sliced from
  `docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
  using the documented `48 px` gutters and pivot `(256,470)`. Previous live
  Berserk frames are backed up under
  `docs/design/backups/scrum461_berserk_cartoon_pre_anim/`. QA artifacts live
  under `build/qa/scrum461_berserk_cartoon_anim/`; attack animation remains
  intentionally absent by SCRUM-461 scope.
- SCRUM-532 (2026-06-28) produces the Berserk v2 dark-fantasy animation asset
  pack from the accepted SCRUM-531 source without wiring it into live runtime.
  Candidate assets live under `assets/sprites/characters/berserk_v2/`:
  `move`/`walk` has 5 looping `512x512` frames at 9 fps, and
  `attack_primary` has 6 non-looping empty-fist/body-strike frames at 12 fps.
  The safe-gutter sheet is
  `assets/sprites/characters/berserk_v2/berserk_v2_anim_sheet.png` with `48 px`
  outer padding/gutters and pivot `(256,470)`. QA artifacts and manifest live
  under `build/qa/scrum532_berserk_v2_anim/`; the animation manifest validator
  passes. Live `assets/sprites/characters/berserk_spriteframes.tres`,
  `scripts/player.gd`, and `tests/animation_smoke_test.gd` remain unchanged by
  scope, so runtime still uses the SCRUM-461 idle/walk/move-only Berserk until a
  separate wiring task.
- 2026-07-01 SCRUM-703 PixelLab Berserk redraw replaces the previous tiny live
  pack with new unarmed v3 source character
  `8486ce45-f749-4c63-9a6d-f0477d619c2d`. Source downloads are stored under
  `assets/sprites/characters/pixellab/berserk/` (`252x252` source frames plus
  `manifest.json`, `pixellab_metadata.json`, and `alpha_bbox_report.json`),
  while runtime frames are transparent `512x512` canvases under
  `assets/sprites/characters/full_frame/berserk_pixellab/` with every idle/move
  alpha bbox normalized to `245 px` high. The SpriteFrames resource exposes
  `idle_<direction>` one-frame fallbacks and `move_<direction>` /
  `walk_<direction>` 6-frame looping rows for `south`, `south_east`, `east`,
  `north_east`, `north`, `north_west`, `west`, and `south_west`, plus generic
  `idle` / `move` / `walk` fallbacks. `Player` resolves the movement vector into
  the matching 8-way row and disables horizontal `flip_h` for directional rows.
  The final north-west move row uses a PixelLab v3 custom empty-hands replacement
  after QA rejected a first template row with hammer-like props. Body attack rows
  remain absent by current combat-visual scope.
- SCRUM-423 (2026-06-30) applies the PixelLab directional runtime path to
  Chemist. Source downloads and manifest live under
  `assets/sprites/characters/pixellab/chemist/` (`252x252` source frames),
  runtime frames are nearest-neighbor normalized to a transparent `512x512`
  canvas under `assets/sprites/characters/full_frame/chemist_pixellab/`, and
  `assets/sprites/characters/chemist_spriteframes.tres` exposes static
  `idle_<direction>` poses plus 6-frame looping `move_<direction>` /
  `walk_<direction>` rows for all 8 directions. The generic idle/move/walk
  fallbacks use the south row, Hero Select rotates through the same directional
  frames, and body attack rows remain absent by weapon-owned combat scope.
- SCRUM-426 (2026-06-30) applies the PixelLab directional runtime path to
  Druid. Source downloads and manifest live under
  `assets/sprites/characters/pixellab/druid/` (`244x244` source frames), runtime
  frames are nearest-neighbor normalized to a transparent `512x512` canvas under
  `assets/sprites/characters/full_frame/druid_pixellab/`, and
  `assets/sprites/characters/druid_spriteframes.tres` exposes static
  `idle_<direction>` poses plus 6-frame looping `move_<direction>` /
  `walk_<direction>` rows for all 8 directions. The generic idle/move/walk
  fallbacks use the south row, Hero Select rotates through the same directional
  frames, and body attack rows remain absent by weapon-owned combat scope.
- SCRUM-428 (2026-07-01) applies the PixelLab directional runtime path to
  Engineer using existing source character
  `c5bd9766-e7de-4316-ace6-e687c951e621`. Source rotations and
  `walking-6-frames` rows live under
  `assets/sprites/characters/pixellab/engineer/`; normalized runtime frames live
  under `assets/sprites/characters/full_frame/engineer_pixellab/`, and
  `assets/sprites/characters/engineer_spriteframes.tres` exposes static
  `idle_<direction>` poses plus 6-frame `move_<direction>` /
  `walk_<direction>` rows for all 8 directions. The generic idle/move/walk
  fallbacks use the south row, Hero Select rotates through the same directional
  frames, and body attack rows remain absent by weapon-owned combat scope.
- SCRUM-433 (2026-07-01) applies the PixelLab directional runtime path to
  Sniper using existing source character
  `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`. Source rotations and
  `walking-6-frames` rows live under
  `assets/sprites/characters/pixellab/sniper/`; normalized runtime frames live
  under `assets/sprites/characters/full_frame/sniper_pixellab/`, and
  `assets/sprites/characters/sniper_spriteframes.tres` exposes static
  `idle_<direction>` poses plus 6-frame `move_<direction>` /
  `walk_<direction>` rows for all 8 directions. The generic idle/move/walk
  fallbacks use the south row, Hero Select rotates through the same directional
  frames, and body attack rows remain absent by weapon-owned combat scope.
- SCRUM-803 (2026-07-01) applies the PixelLab directional runtime path to
  Assassin using accepted empty-open-hands source character
  `ec73da27-b704-4336-9275-74c8e3e578df`. Source rotations and
  `walking-6-frames` rows live under
  `assets/sprites/characters/pixellab/assassin/`; normalized runtime frames live
  under `assets/sprites/characters/full_frame/assassin_pixellab/`, and
  `assets/sprites/characters/assassin_spriteframes.tres` exposes static
  `idle_<direction>` poses plus 6-frame `move_<direction>` /
  `walk_<direction>` rows for all 8 directions. The generic idle/move/walk
  fallbacks use the south row, Hero Select rotates through the same directional
  frames, and body attack rows remain absent by weapon-owned combat scope.
  PixelLab candidate `cdee7e9a-1d04-430e-8fc9-60fafc2cd4a8` was rejected before
  import because it baked a held blade.
- SCRUM-804 (2026-07-01) applies the PixelLab directional runtime path to
  Ranger using new empty-handed source character
  `1646d83c-f570-4bdd-9065-cb1b46bf13f7`. Source rotations and
  `walking-6-frames` rows live under
  `assets/sprites/characters/pixellab/ranger/`; normalized runtime frames live
  under `assets/sprites/characters/full_frame/ranger_pixellab/`, and
  `assets/sprites/characters/ranger_spriteframes.tres` exposes static
  `idle_<direction>` poses plus 6-frame `move_<direction>` /
  `walk_<direction>` rows for all 8 directions. The generic idle/move/walk
  fallbacks use the south row, Hero Select rotates through the same directional
  frames, and body attack rows remain absent by weapon-owned combat scope.
- 2026-07-01 SCRUM-421 PixelLab Biologist rescue finishes the previously queued
  source character `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4` in a clean worktree.
  Source rotations and movement frames are stored under
  `assets/sprites/characters/pixellab/biologist/`; runtime frames are
  transparent `512x512` canvases under
  `assets/sprites/characters/full_frame/biologist_pixellab/` with every
  visible alpha bbox normalized to `245 px` high. The SpriteFrames resource
  exposes `idle`, `move`, `walk`, plus 8-direction `idle_`, `move_`, and
  `walk_` rows; Hero Select rotates through those directional frames. The
  south movement row uses a PixelLab v3 custom front-facing replacement after
  visual QA rejected the initial downloaded row as wrong-facing.
- SCRUM-540 (2026-06-28) produces the Secret Ascension Boss full-frame animation
  pack from the accepted SCRUM-539 source. Candidate assets live under
  `assets/sprites/bosses/full_frame/secret_ascension_boss/` with a 512x512
  canvas, pivot `(256,480)`, 48px sheet gutters, and stable bottom-center
  framing. The SpriteFrames resource is
  `assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres`
  and exposes 6f looping `idle`/`move`, 6f `attack_primary` plus
  `attack_primary_windup`/`attack_primary_release`, four cast pairs
  (`skill_ring`/`attack_ring`, `skill_cone`/`attack_cone`,
  `skill_beam`/`attack_beam`, `skill_rupture`/`attack_rupture`), `hit`, and
  `death`. QA artifacts and manifest live under
  `build/qa/scrum540_secret_ascension_boss_anim/`; manifest, alpha/slicing,
  Godot import, and focused SpriteFrames smoke pass. Back-end runtime encounter
  wiring remains separate from this Animator pack.
- SCRUM-473 (2026-06-17) replaces the temporary cartoon-trial legacy rig for
  Dark Mage and Knight with real cartoon2 full-frame SpriteFrames. Runtime
  resources `assets/sprites/characters/dark_mage_spriteframes.tres` and
  `assets/sprites/characters/knight_spriteframes.tres` expose `idle` (5f loop),
  `walk` (5f loop), and `move` (walk alias, 5f loop) only, sourced from the
  accepted transparent runtime sprites `assets/sprites/characters/dark_mage.png`
  and `assets/sprites/characters/knight.png` with the 1024 source gate under
  `docs/design/references/chars_cartoon/trial_v2/`. Runtime frames live under
  `assets/sprites/characters/full_frame/{dark_mage,knight}/`; safe-gutter
  cartoon2 sheets live under `assets/sprites/characters/cartoon2/`. QA contact
  sheets, GIFs, alpha stats and manifest live under
  `build/qa/scrum473_cartoon2_dark_mage_knight_anim/`. `scripts/player.gd`
  now leaves `CARTOON_TRIAL_CLASSES` empty, so both classes use the full-frame
  `AnimatedSprite2D` path and hide the legacy rig. Attack animation remains
  absent by SCRUM-473 scope because weapons own attacks (`USE_ATTACK_ANIMATION=false`).
  Animation smoke passes; full runtime smoke is currently blocked by an
  unrelated Hero Select v3 back-button UI assertion. The bundled manifest
  validator still reports the expected missing `attack_primary` rows because it
  predates the SCRUM-473 no-attack scope.
- 2026-06-30 SCRUM-704 supersedes the earlier static Dark Mage PixelLab pass with
  a new readable-scale v3 PixelLab character
  `9bb0eca8-5afe-49d4-8e56-7115a45efdcc` (`248x248` source), empty hands, and no
  baked book/skull/wand/staff/orb/held prop. Source rotations plus
  `walking-6-frames` movement frames live under
  `assets/sprites/characters/pixellab/dark_mage/`; normalized 512x512 runtime
  frames live under `assets/sprites/characters/full_frame/dark_mage_pixellab/`.
  `assets/sprites/characters/dark_mage_spriteframes.tres` now exposes
  one-frame `idle` / `idle_<direction>` and 6-frame `move` / `walk` /
  `move_<direction>` / `walk_<direction>` rows for all 8 directions so combat
  runtime and Hero Select both use the same PixelLab movement pack. Dark Mage is
  routed through the full-frame `AnimatedSprite2D` path; the historical
  Skeleton2D/Bone2D rig remains regression/source history rather than live
  runtime priority.
- SCRUM-430 promotes Knight to a PixelLab no-shield directional pack. Source
  downloads live under `assets/sprites/characters/pixellab/knight/`; normalized
  512x512 runtime frames live under
  `assets/sprites/characters/full_frame/knight_pixellab/`.
  `assets/sprites/characters/knight_spriteframes.tres` exposes one-frame
  `idle_<direction>` rows plus 6-frame `move_<direction>` / `walk_<direction>`
  rows for all 8 directions. Weapons and shield remain separate weapon visuals;
  the base Knight source has empty hands and no baked equipment. SCRUM-885
  refreshed this pack from PixelLab MCP on 2026-07-08 and kept the same
  directional runtime contract.
- SCRUM-475 (2026-06-19) delivers the Design-source blocker for the next
  Skeleton2D/Bone2D source gate: Dark Mage and Knight now have transparent
  skeleton-source packages under
  `docs/design/references/chars_cartoon/skeleton_parts/{dark_mage,knight}/`.
  Each package contains a source copy, 19 separated PNG parts, local pivots,
  a `skeleton_source_manifest.json`, alpha report, contact sheet and dark-bg
  preview. Both manifests pass the animation-director
  `validate_skeleton_source_manifest.py` validator. No runtime rig,
  SpriteFrames or AnimationPlayer clips were changed by this Design handoff.
  SCRUM-474 remains under the explicit USER HOLD after this delivery: runtime
  Skeleton2D/Bone2D rig assembly, `AnimationPlayer` timelines and player
  integration must wait for a newer user/PM go-ahead saying `делай анимацию`.
- SCRUM-424 adds the Dark Mage v2 Design-source handoff under
  `docs/design/references/characters_v2/dark_mage/` with alpha-clean source,
  normalized `512x512` idle cell, `2560x1024` source placeholder sheet and QA
  report. Asset-side handoff copies live in
  `assets/sprites/characters/v2/dark_mage/`. Animator integration now promotes
  the accepted source into the live runtime resource
  `assets/sprites/characters/dark_mage_spriteframes.tres`, exposing `idle`,
  `walk`, and `move` only, each with 5 looping `512x512` full-frame frames
  derived from `dark_mage_v2_idle_cell_512.png`. Runtime frames live under
  `assets/sprites/characters/full_frame/dark_mage/`, the safe 48px-gutter export
  sheet lives at
  `assets/sprites/characters/v2/dark_mage/dark_mage_v2_anim_sheet.png`, and
  previous live SpriteFrames/frames are backed up under
  `docs/design/backups/scrum424_dark_mage_v2_pre_anim/`. QA artifacts live under
  `build/qa/scrum424_dark_mage_v2_anim/`; animation smoke passes. Full runtime
  smoke is currently blocked before gameplay startup by an unrelated
  `scripts/ui_screens.gd` parse failure from the active UI/settings lane. The
  bundled manifest validator was run and records the expected
  `missing attack_primary animation` failure because SCRUM-424 explicitly
  excludes attack animation.
- SCRUM-419 adds the Assassin v2 Design-source handoff under
  `docs/design/references/characters_v2/assassin/` with alpha-clean source,
  normalized `512x512` idle cell, `2560x1024` source placeholder sheet and QA
  report. Animator integration now promotes the accepted source into the live
  runtime resource `assets/sprites/characters/assassin_spriteframes.tres`,
  exposing `idle`, `walk`, and `move` only, each with 5 looping `512x512`
  full-frame frames derived from `assassin_v2_idle_cell_512.png`. Runtime
  frames live under `assets/sprites/characters/full_frame/assassin/`, the safe
  48px-gutter export sheet lives at
  `assets/sprites/characters/v2/assassin/assassin_v2_anim_sheet.png`, and
  previous live SpriteFrames/frames are backed up under
  `docs/design/backups/scrum419_assassin_v2_pre_anim/`. QA artifacts live under
  `build/qa/scrum419_assassin_v2_anim/`; animation and runtime smokes pass. The
  bundled manifest validator was run and records the expected
  `missing attack_primary animation` failure because SCRUM-419 explicitly
  excludes attack animation.
- SCRUM-429 adds the Guitarist v2 Design-source handoff under
  `docs/design/references/characters_v2/guitarist/` with alpha-clean source,
  normalized `512x512` idle cell, `2560x1024` source placeholder sheet,
  accepted source sheet copy and QA report. Animator integration now promotes
  the accepted source into the live runtime resource
  `assets/sprites/characters/guitarist_spriteframes.tres`, exposing `idle`,
  `walk`, and `move` only, each with 5 looping `512x512` full-frame frames
  derived from `guitarist_v2_idle_cell_512.png`. Runtime frames live under
  `assets/sprites/characters/full_frame/guitarist/`, the safe 48px-gutter
  export sheet lives at
  `assets/sprites/characters/v2/guitarist/guitarist_v2_anim_sheet.png`, and
  previous live SpriteFrames/frames are backed up under
  `docs/design/backups/scrum429_guitarist_v2_pre_anim/`. QA artifacts live
  under `build/qa/scrum429_guitarist_v2_anim/`; animation and runtime smokes
  pass. The bundled manifest validator was run and records the expected
  `missing attack_primary animation` failure because SCRUM-429 explicitly
  excludes attack animation.
- SCRUM-706 replaces the live Guitarist placeholder with a new PixelLab-only
  empty-hands source `704fd67b-da81-4804-acd2-07e75fefd9de`. The rejected
  candidates are `f41e1d57-f720-4ae1-a739-8873d935163b`
  (failed/listed `128x128`) and `d278e753-9885-4550-82ff-81ee3bef297d`
  (`240x240` but baked a held instrument). Source rotations and six-frame
  `walking-6-frames` movement live under
  `assets/sprites/characters/pixellab/guitarist/`; normalized transparent
  runtime frames live under
  `assets/sprites/characters/full_frame/guitarist_pixellab/`, centered on a
  `512x512` canvas with every visible alpha bbox at `245 px` height. The live
  `assets/sprites/characters/guitarist_spriteframes.tres` exposes generic
  `idle` / `move` / `walk` fallbacks, `idle_<direction>` one-frame rows, and
  6-frame looping `move_<direction>` / `walk_<direction>` rows for `south`,
  `south_east`, `east`, `north_east`, `north`, `north_west`, `west`, and
  `south_west`; weapon/instrument visuals remain separate weapon effects.
- SCRUM-797 supersedes the SCRUM-706 Guitarist empty-hands live body by direct
  user request. PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d` is now
  accepted for live runtime because its held-guitar silhouette is more readable
  and characterful. The runtime contract is unchanged: 8 idle directions,
  6-frame `walking-6-frames` movement rows, transparent `512x512` runtime PNGs,
  every visible alpha bbox normalized to `245 px`, and the same
  `idle`/`move`/`walk` plus directional rows consumed by player movement and
  Hero Select preview rotation. The previous SCRUM-706 pack is backed up under
  `docs/design/backups/scrum797_guitarist_instrument_pack_pre_swap/`; SCRUM-797
  evidence lives under `docs/design/previews/scrum797_guitarist_instrument_pack_*`.
- SCRUM-435 adds the Thief v2 Design-source handoff under
  `docs/design/references/characters_v2/thief/` and promotes the accepted
  source into the live runtime resource
  `assets/sprites/characters/thief_spriteframes.tres`, exposing `idle`, `walk`,
  and `move` only, each with 5 looping `512x512` full-frame frames derived from
  `thief_v2_idle_cell_512.png`. Runtime frames live under
  `assets/sprites/characters/full_frame/thief/`, the safe 48px-gutter export
  sheet lives at `assets/sprites/characters/v2/thief/thief_v2_anim_sheet.png`,
  and previous live SpriteFrames/frames are backed up under
  `docs/design/backups/scrum435_thief_v2_pre_anim/`. QA artifacts live under
  `build/qa/scrum435_thief_v2_anim/`; animation and runtime smokes pass. The
  bundled manifest validator was run and records the expected
  `missing attack_primary animation` failure because SCRUM-435 explicitly
  excludes attack animation.
- SCRUM-427 adds the Elementalist v2 Design-source handoff under
  `docs/design/references/characters_v2/elementalist/` and promotes the
  accepted source into the live runtime resource
  `assets/sprites/characters/elementalist_spriteframes.tres`, exposing `idle`,
  `walk`, and `move` only, each with 5 looping `512x512` full-frame frames
  derived from `elementalist_v2_idle_cell_512.png`. Runtime frames live under
  `assets/sprites/characters/full_frame/elementalist/`, the safe 48px-gutter
  export sheet lives at
  `assets/sprites/characters/v2/elementalist/elementalist_v2_anim_sheet.png`,
  and previous live SpriteFrames/frames are backed up under
  `docs/design/backups/scrum427_elementalist_v2_pre_anim/`. QA artifacts live
  under `build/qa/scrum427_elementalist_v2_anim/`; animation and runtime smokes
  pass. The bundled manifest validator was run and records the expected
  `missing attack_primary animation` failure because SCRUM-427 explicitly
  excludes attack animation.
- Historical Sniper v2 Design-source handoff: SCRUM-433 originally added source
  assets under
  `docs/design/references/characters_v2/sniper/` with alpha-clean source,
  normalized `512x512` idle cell, `2560x1024` source placeholder sheet,
  accepted source sheet copy and QA report. Asset-side handoff copies live in
  `assets/sprites/characters/v2/sniper/`. The sheet repeats the accepted source
  for idle/move placeholders only; live Sniper runtime has since moved to the
  PixelLab directional pack under `assets/sprites/characters/full_frame/sniper_pixellab/`.
  White/neutral
  matte QA is strict: `0` opaque-white pixels, `0` neutral-light visible pixels
  and `0` edge-visible pixels in source/cell/sheet outputs.
- SCRUM-431 adds the Priest v2 Design-source handoff under
  `docs/design/references/characters_v2/priest/` with alpha-clean source,
  normalized `512x512` idle cell, `2560x1024` source placeholder sheet,
  accepted source sheet copy and QA report. Asset-side handoff copies live in
  `assets/sprites/characters/v2/priest/`. The sheet repeats the accepted source
  for idle/move placeholders only; Animator must create real `idle` and
  `move/walk` frames before SpriteFrames/runtime integration. White/neutral
  matte QA is strict: `0` opaque-white pixels, `0` neutral-light visible pixels
  and `0` edge-visible pixels in source/cell/sheet outputs.
- 2026-06-30 SCRUM-431 PixelLab pass promotes Priest to live directional
  runtime/Hero Select art. PixelLab character
  `ed7db59e-0845-4218-b178-a56f948254b5` provides 8 static idle rotations and
  `walking-6-frames` movement for all 8 directions. Source PNGs and
  `manifest.json` live under `assets/sprites/characters/pixellab/priest/`;
  normalized transparent `512x512` runtime frames live under
  `assets/sprites/characters/full_frame/priest_pixellab/`. The runtime resource
  `assets/sprites/characters/priest_spriteframes.tres` exposes fallback
  `idle`/`move`/`walk`, plus `idle_<direction>`, `move_<direction>` and
  `walk_<direction>` rows. Attack rows remain absent because weapon visuals own
  combat actions.
- SCRUM-421 adds the Biologist v2 Design-source handoff under
  `docs/design/references/characters_v2/biologist/` with alpha-clean source,
  normalized `512x512` idle cell, `2560x1024` source placeholder sheet,
  accepted source sheet copy and QA report. Asset-side handoff copies live in
  `assets/sprites/characters/v2/biologist/`. The sheet repeats the accepted
  source for idle/move placeholders only; Animator must create real `idle` and
  `move/walk` frames before SpriteFrames/runtime integration. White/neutral
  matte QA is strict: `0` opaque-white pixels, `0` neutral-light visible pixels
  and `0` edge-visible pixels in source/cell/sheet outputs.
- SCRUM-298 Design standard: playable character full-frame redraws now use
  `docs/design/references/character_animation_style_sheet_0_1_5.md` as the
  source of truth for art direction, sheet rows, pivots and naming. Canonical
  future sheet path is `assets/sprites/characters/<class_id>_sheet.png`, default
  cell size is `384x384`, preferred sheet is `1920x1152` with rows
  `idle` / `walk` / `attack_primary` (5 frames each). Base character sheets are
  unarmed; weapon visuals stay in socket/weapon assets. Back-end now probes that
  path at character configure time, builds `idle`/`walk`/`attack_primary` and
  runtime `attack` SpriteFrames when a sheet exists, and otherwise falls back to
  the old cutout/static character visuals.
- SCRUM-411 fixed the runtime visibility switch for playable full-frame sheets:
  when `assets/sprites/characters/<class_id>_spriteframes.tres` or
  `<class_id>_sheet.png` exists, `Player/VisualRoot/Body` is visible and plays
  the full-frame `idle`/`walk`/`attack` states, while `RigRoot` is hidden so the
  old cutout body cannot cover the accepted redraw. The hidden rig remains only
  as a compatibility/socket/action-event anchor. Characters without full-frame
  frames keep the previous fallback: hidden `Body`, visible cutout `RigRoot`.
- SCRUM-412 cleaned the playable full-frame runtime PNG set at
  `assets/sprites/characters/full_frame/<class>/`: all 17 classes and all 255
  `idle` / `walk` / `attack_primary` frames now use real transparent alpha
  rather than a white/checkerboard matte inside the `384x384` canvas. The
  `SpriteFrames` resources and animation timings were not changed. Future
  playable sheet builds must run `tools/build_character_sheet.py`, which now
  calls `tools/alpha_clean_full_frame_characters.py` to remove edge-connected
  white/near-white/checkerboard matte from the visible alpha bounds and de-halo
  the silhouette before writing sliced frames. QA proof lives under
  `build/qa/scrum412_character_alpha/`; Godot import and animation smoke pass.
  `tests/animation_smoke_test.gd` now permanently samples one cleaned
  `*_idle_00.png` per playable class and fails if edge-ring white/checkerboard
  pixels or floodable matte regress beyond the SCRUM-412 thresholds.
- SCRUM-283 integrated Berserk's accepted unarmed source sheet
  `assets/sprites/characters/berserk_sheet.png` into runtime SpriteFrames at
  `assets/sprites/characters/berserk_spriteframes.tres`: `walk` 5f loop,
  `attack_primary`/runtime `attack` 5f one-shots, `idle` one-frame fallback,
  `384x384` canvas, bottom-center pivot guide `[192,348]`. Runtime frames are
  extracted to `assets/sprites/characters/full_frame/berserk/` so SpriteFrames
  do not slice neighboring source-sheet pixels; manifest/contact/GIF artifacts
  live under `build/qa/scrum283/`.
- SCRUM-286 integrated the accepted unarmed Dark Mage sheet
  `assets/sprites/characters/dark_mage_sheet.png` into runtime SpriteFrames at
  `assets/sprites/characters/dark_mage_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`. Runtime frames are extracted to
  `assets/sprites/characters/full_frame/dark_mage/`; source references, a
  32px-gutter QA sheet, manifest and GIF previews are under
  `docs/design/references/characters/dark_mage/` and
  `build/qa/scrum286_dark_mage/`.
- SCRUM-291 integrated the accepted unarmed Guitarist sheet
  `assets/sprites/characters/guitarist_sheet.png` into runtime SpriteFrames at
  `assets/sprites/characters/guitarist_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`. Runtime frames are extracted to
  `assets/sprites/characters/full_frame/guitarist/`; Design source references
  remain under `docs/design/references/characters/guitarist/`, while Animator
  manifest/contact/GIF artifacts live under `build/qa/scrum291/`. Manifest
  validation, Godot import, animation smoke and runtime smoke PASS after
  SCRUM-409.
- SCRUM-297 accepted the unarmed Thief sheet
  `assets/sprites/characters/thief_sheet.png`: `idle` 5f loop, `walk` 5f loop,
  `attack_primary` 5f one-shot, `384x384` canvas, bottom-center pivot guide
  `[192,348]`, no weapons/coins/smoke/held props. Design source references,
  alpha-clean sheet, 32px-gutter QA sheet, contact preview, manifest and GIF
  previews are under `docs/design/references/characters/thief/`,
  `docs/design/previews/scrum297_thief_sheet_contact.png` and
  `build/qa/scrum297_thief/`. Parallel Animator output already provides
  `assets/sprites/characters/thief_spriteframes.tres` and per-frame PNGs under
  `assets/sprites/characters/full_frame/thief/`.
- SCRUM-289 accepted the unarmed Elementalist Design source sheet
  `assets/sprites/characters/elementalist_sheet.png`: `idle` 5f loop source,
  `walk` 5f loop source, `attack_primary` 5f one-shot source, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, no staff/wand/orb/focus/held
  object. Source references, alpha-clean sheet, 32px-gutter QA sheet, contact
  preview, manifest and GIF previews are under
  `docs/design/references/characters/elementalist/`,
  `docs/design/previews/scrum289_elementalist_sheet_contact.png` and
  `build/qa/scrum289_elementalist/`. Animator pass integrated runtime
  `assets/sprites/characters/elementalist_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, and per-frame PNGs under
  `assets/sprites/characters/full_frame/elementalist/`. Animator
  manifest/contact/GIF artifacts live under `build/qa/scrum289/`; manifest
  validation, Godot import, animation smoke and runtime smoke PASS.
- SCRUM-284 accepted the unarmed Biologist Design source sheet
  `assets/sprites/characters/biologist_sheet.png`: `idle` 5f loop source,
  `walk` 5f loop source, `attack_primary` 5f one-shot source, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, no tools/syringes/flasks/bags/
  weapons/orbs/held objects. Source references, alpha-clean sheet, 32px-gutter
  QA sheet, contact preview, manifest and GIF previews are under
  `docs/design/references/characters/biologist/`,
  `docs/design/previews/scrum284_biologist_sheet_contact.png` and
  `build/qa/scrum284_biologist/`. Animator pass integrated runtime
  `assets/sprites/characters/biologist_spriteframes.tres`: `idle` 5f loop,
  `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, `384x384`
  canvas, bottom-center pivot guide `[192,348]`, and per-frame PNGs under
  `assets/sprites/characters/full_frame/biologist/`. Animator
  manifest/contact/GIF artifacts live under `build/qa/scrum284/`; manifest
  validation, Godot import, animation smoke and runtime smoke PASS.
- SCRUM-282 and SCRUM-294 integrated accepted unarmed Assassin/Ranger sheets
  into runtime SpriteFrames at
  `assets/sprites/characters/assassin_spriteframes.tres` and
  `assets/sprites/characters/ranger_spriteframes.tres`: each has `idle` 5f
  loop, `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shots, a
  `384x384` canvas, and per-frame PNGs under
  `assets/sprites/characters/full_frame/assassin/` and
  `assets/sprites/characters/full_frame/ranger/`. Manifest validation,
  animation smoke and runtime smoke PASS.
- Movement facing — отдельно от attack targeting.
- Attack direction приходит из weapon targeting и не перетирается velocity.
- `WeaponSocket` используется для attached weapons и должен оставаться совместимым с анимацией.
- SCRUM-705 (2026-07-01) replaces the live Doctor PixelLab pack with a fresh
  v3 plague-doctor redraw (`3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`): source idle
  and 6-frame walk frames live under `assets/sprites/characters/pixellab/doctor/`,
  normalized transparent runtime frames live under
  `assets/sprites/characters/full_frame/doctor_pixellab/`, and every runtime
  alpha bbox is 244 px high inside a `512x512` canvas. `doctor_spriteframes.tres`
  exposes `idle_<direction>`, `move_<direction>`, and `walk_<direction>` for all
  8 directions; Hero Select uses the same clockwise directional rows. The base
  body intentionally has empty hands, leaving restore potion, plague syringe and
  bone saw to weapon visuals rather than baked character art.
- Player cutout rig использует per-character `walk_blend_rate` / `direction_blend_rate`: `berserk` двигается тяжелее, `dark_mage` мягче и с меньшим robe/body lean, `guitarist` быстрее. Pass 2026-06-12 добавил отдельные visual motion profiles для новых классов: `assassin` быстрый/резкий, `ranger` собранный, `doctor` спокойный тяжелый, `chemist` чуть нервный, `knight` тяжелый инертный, `druid` мягкий ритуальный. Pass SCRUM-168 2026-06-13 добавил `soldier`: средневесовый дисциплинированный шаг, меньше arm swing, умеренный body bob. Pass SCRUM-169 2026-06-13 добавил `thief`: легкий осторожный шаг с быстрым direction blend, меньшим bob и сдержанным переносом веса. Pass SCRUM-163 2026-06-13 добавил `elementalist`: плавный энергичный caster-step, легче Dark Mage, с выраженным breath/channel sway. Pass SCRUM-167 2026-06-13 добавил `sniper`: controlled ranged/sniper gait, low bob, low arm swing, steady aim stance without melee lunge feel. Pass SCRUM-165 2026-06-13 добавил `priest`: calm healer/support caster gait, low aggression, restrained arm swing, readable robe bob and support-caster sway. Pass SCRUM-162 2026-06-13 добавил `biologist`: careful field-scientist gait, modest bob, specimen-handling arm posture, distinct from Chemist/Doctor. Pass SCRUM-166 2026-06-13 добавил `robot`: heavy construct gait, slow inertial walk, strong mass bob, low arm swing, slower direction blend. Pass SCRUM-164 2026-06-13 добавил `engineer`: practical tinkerer gait with workshop backpack/tools, moderate bob, measured arm swing, distinct from Druid/Robot.
- Все cutout rigs имеют контактную `GroundShadow`; на новых плоских фонах она остается основным grounding cue и не должна удаляться при будущих visual passes.
- Berserk attack pose получает animation variant из текущего `weapon_id`: `sword` = forward thrust, `axe` = wide arc, `hammer` = overhead slam. SCRUM-880 дополнительно делает runtime VFX для `axe` визуально шире под live 180-degree / 250px sweep и добавляет actual `two_handed_axe.png` weapon overlay в signature layer. Это только motion/VFX layer; damage shape/window остаются в weapon/backend конфигурации.
- FAN-1079 (2026-07-14) унифицирует release-readability всех 51 оружий через существующие weapon-signature PNG: cue появляется у героя, компактно вылетает по aim-направлению и не кодирует размер/форму зоны урона. Exact-zone `Polygon2D` удалён из Berserk/Knight melee path; остаются weapon, projectile, beam, slash, spiral и scene-specific VFX. Storm Longbow продолжает использовать принятые PixelLab SCRUM-912 кадры: runtime shader сжимает только authored bow-region до `0.40` (силуэт более чем вдвое меньше), сдвигает trail без разрыва и пересчитывает uniform scene scale так, чтобы пять стрел по-прежнему визуально проходили live range. Новых raster/source ассетов нет; damage geometry/timing/targeting не менялись.
- Legacy player pass SCRUM-186 (2026-06-13) добавил bespoke 3-weapon silhouettes для старых классов без изменения gameplay: `dark_mage` (book/skull/wand casts), `guitarist` (strum/bass pulse/amp deploy), `assassin` (chakram/dagger/wire), `ranger` (crossbow/longbow/trap), `doctor` (restore/syringe/saw), `chemist` (powder/flask/vial), `knight` (spear/shield/flail), `druid` (summon/briar/totem). Smoke проверяет distinct silhouettes и socket sanity по фактическим `progression_data.gd` weapon IDs.
- Soldier shoot pose получает animation variant из текущего `weapon_id`: `soldier_rifle` = suppression recoil, `soldier_grenade` = cook/throw, `soldier_bayonet` = defensive brace. Это только motion layer; attack modes/timing остаются в `ClassWeapon`.
- Thief shoot pose получает animation variant из текущего `weapon_id`: `thief_coin_pouch` = быстрый щелчок монетой вперед, `thief_shadow_cloak` = сжатие и backstab-рывок, `thief_smoke_bomb` = dodge-back и низкий бросок дымовой бомбы. Это только motion layer; `coin_ricochet`, `shadow_backstab` и `smoke_bomb` gameplay остаются в Back-end.
- Elementalist shoot pose получает animation variant из текущего `weapon_id`: `elementalist_orb_ring` = channel with both arms spread, `elementalist_prism_focus` = forward crystal focus, `elementalist_meteor_core` = overhead meteor summon. Это только motion layer; `elemental_orbit`, `prism_rift` и `meteor_shards` gameplay/timing остаются в Back-end.
- Sniper shoot pose получает animation variant из текущего `weapon_id`: `sniper_deadeye_rifle` = steady lockshot brace, `sniper_spotter_scope` = off-hand kill-zone mark, `sniper_shatter_rounds` = heavier braced recoil. Это только motion layer; `sniper_lockshot`, `sniper_kill_zone` и `sniper_split_round` targeting/damage/timing остаются в Back-end.
- Priest shoot pose получает animation variant из текущего `weapon_id`: `priest_reliquary` = sanctify blessing hand and release, `priest_censer` = outward ward pulse gesture, `priest_chime` = lifted chime/chant pose. Это только motion layer; `priest_sanctify`, `priest_ward` и `priest_prayer_chain` gameplay/timing остаются в Back-end.
- Biologist shoot pose получает animation variant из текущего `weapon_id`: `biologist_spore_lens` = raised inspection/bloom lens stance, `biologist_sample_injector` = precise forward dart pose, `biologist_symbiote_seed` = low planting/web gesture. Это только motion layer; `bio_spore_bloom`, `bio_sample_dart` и `bio_symbiote_web` gameplay/timing остаются в Back-end.
- Robot shoot pose получает animation variant из текущего `weapon_id`: `robot_magnetic_anchor` = heavy plant and low pull, `robot_hydraulic_press` = forward dual-arm compression drive, `robot_reactor_core` = wide reactor vent stance. Это только motion layer; `robot_magnetic_anchor`, `robot_compression_line` и `robot_reactor_vent` gameplay/timing остаются в Back-end.
- SCRUM-917 добавляет для `robot_hydraulic_press` отдельный PixelLab v3
  8-frame VFX `compress`: две стальные губки и бирюзовые pressure-waves сходятся
  с краёв широкого коридора к центральной оси. Кадр 5 играет на `0.20s` и
  совпадает с уже существующим delayed hit SCRUM-916. Animator scene масштабирует
  визуал под live `430x300` и `430x390` (Press Calibrator), сохраняет
  центрированный pivot `(128,128)`, `16px` runtime gutters и нулевой edge-touch;
  gameplay остаётся в `ClassWeapon`, а scene-specific visual bridge не меняет
  damage/targeting/compression/cooldown.
- Engineer shoot pose получает animation variant из текущего `weapon_id`: `engineer_sentry_wrench` = lifted wrench deploy gesture, `engineer_repair_drone` = upward drone launch/guide pose, `engineer_pressure_mines` = crouched mine placement. Это только motion layer; `engineer_sentry_link`, `engineer_repair_drone` и `engineer_pressure_mines` gameplay/timing остаются в Back-end.

## Enemy Motion

- Враги/элитки/боссы используют cutout rig и base facing.
- Мобы не должны двигаться спиной вперед: facing sign учитывает `base_facing`.
- Enemy archetype pass SCRUM-184 (2026-06-13) добавил tailored action readability для partial rigs: marksman weapon recoil, runner coil/burst, bruiser slam, summoner/mage/shaman ritual casts, spitter body-squash shot, shieldbearer brace/shove, biter lunge, winged spark dive, Disk Devourer body chomp. Smoke проверяет movement + action silhouette per archetype.
- Elite active attacks имеют внешние фазы `windup/strike/recover/idle`.
- `enemy.gd` передает elite phases в rig как animation variant `<elite_behavior>:<elite_attack_id>:<phase>` вместе с backend duration. `cutout_rig_2d.gd` держит pose layer для `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`; VFX и damage остаются в backend/effects layer.
- SCRUM-368 (2026-06-14) перевел route elites `iron_bastion`, `night_stalker` и `plague_prophet` на production full-frame SpriteFrames через `FullFrameAnimationRegistry` kind `elite`. У каждой элитки есть `move` 6f loop, `attack`/`attack_primary` 6f one-shot, две 6f `skill_*` строки и `attack_*` validator aliases. Backend phase variants (`<elite_behavior>:<attack_id>:<phase>`) резолвятся в соответствующую accepted skill row без изменения damage/VFX timing.
- SCRUM-371 (2026-06-14) добавил тот же production full-frame contract для `shard_marshal`: `move`, `attack`/`attack_primary`, `skill_shard_fan`, `skill_command_pulse` и matching `attack_*` aliases; backend phase `shard_marshal:shard_fan:*` визуально резолвится в `skill_shard_fan`.
- FAN-2623 заменил для `shard_marshal` прежний недирекционный pack на завершённый PixelLab character export `06de6f32-fca4-43f2-a657-b011a85d7632`: `idle` (1f), `move` (8f loop), `attack` (7f), `hit` (5f), `death` (7f), `skill_shard_fan` (7f) и `skill_command_pulse` (7f) теперь имеют явные строки по всем восьми направлениям. Runtime кадры нормализованы в 512×512 с общим pivot/footline; `explicit_eight_directions: true` запрещает `flip_h`, а `mini_swarm_sniper` остаётся намеренным fallback на базовый `shard_marshal`.
- SCRUM-376 (2026-06-14) подключил full-frame contract для всех mini-elites через SCRUM-372 `mini_elite_kind` visual-id hook: `mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`. У каждого есть `move` 6f loop, `attack`/`attack_primary` 6f one-shot, две 6f `skill_*` строки и matching `attack_*` aliases; missing mini-specific frames fallback'аются на base `elite_behavior`. SCRUM-370 добавил каждому `death` 6f one-shot.
- SCRUM-377 (2026-06-14) подключил full-frame contract для боссов `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`: `move`, `attack`/`attack_primary`, две 6f `skill_*` строки и matching `attack_*` aliases. SCRUM-378 добавил Back-end visual-only hooks: boss callbacks запрашивают matching `skill_*` state через `FullFrameAnimationRegistry`, а damage/VFX timing/targeting/cooldowns остаются прежними. SCRUM-370 добавил `death` 6f one-shot rows для всех 5 boss SpriteFrames.
- SCRUM-793 (2026-07-02) promotes accepted SCRUM-779 PixelLab single-view boss
  candidates into the existing live full-frame rows for `disk_devourer`
  (`81b491db-7240-4513-bad5-263b7f81539d`) and `brood_mother`
  (`99d1c48c-ab86-4025-80b0-5a0ccb3d2edf`). SpriteFrames paths, state names,
  frame counts, speeds and boss gameplay callbacks are unchanged; `rift_warden`,
  `bone_archon`, `ashen_colossus`, `secret_ascension_boss`, `skeletal_dragon`
  and `bloodthorn_lion` candidates remain source-only/revise-needed follow-ups.
  Evidence: `build/qa/scrum793_boss_pixellab_promotion/`.
- SCRUM-865 (2026-07-04) completes the PixelLab-first full boss redraw pass for
  all six live bosses (`rift_warden`, `disk_devourer`, `bone_archon`,
  `brood_mother`, `ashen_colossus`, `bloodthorn_lion`). The initial `256x256`
  PixelLab attempt failed against the current 8-direction max frame size, so
  the accepted pass uses completed `170x170` source objects and imports
  west-facing `512x512` runtime rows into the existing boss SpriteFrames
  contract: `move` loop, `attack`/`attack_primary`, `death`, two `skill_*` rows
  and matching `attack_*` aliases. `bloodthorn_lion` is now registered in
  `FullFrameAnimationRegistry`; gameplay timing, damage, targeting and route
  rotation are unchanged. Manifest:
  `docs/design/references/bosses/boss_pixellab_full_redraw_2026_07/manifest.json`;
  preview:
  `docs/design/previews/boss_pixellab_full_redraw_2026_07_runtime_contact.png`.
- SCRUM-372 (2026-06-14) добавил visual-only hook для мини-элиток: если elite instance имеет meta `mini_elite_kind` и `FullFrameAnimationRegistry.sprite_frames_for("elite", mini_elite_kind)` существует, runtime выбирает именно этот full-frame visual ID. Если SpriteFrames для mini-kind еще нет, сохраняется прежний fallback на `elite_behavior` route-элитки.

## Summon / Ally Motion

- SCRUM-353 (2026-06-14) validated all mobile summon creatures through the
  now-retired legacy full-frame animation validator: `druid_beast`,
  `druid_pack_spirit`, `homunculus`, and `leadership_echo` use full-frame
  SpriteFrames on the existing runtime paths. Each has `move` 8f/12fps loop and
  runtime `attack` 6f/14fps non-loop, recorded as `attack_primary` in the legacy
  manifest.
- SCRUM-370 adds ally `death` rows to those same SpriteFrames paths:
  6 frames at 10fps, non-loop, with static `ally_*.png` fallback unchanged.
- SCRUM-399 (2026-06-14) replaced the visual source and runtime PNG frame
  art for the four mobile summons with an ethereal allied spirit style: blue/
  cyan translucent bodies, soft inner glow and smoky edges. The pass preserved
  existing SpriteFrames resources, frame counts, loop flags, timings and
  registry placement. A follow-up safe-slicing cleanup repacked all 80 animated
  summon frame PNGs into the existing `256x256` cells with 24px transparent
  gutters: 0 edge-touch frames, 0 padding failures. Any new motion staging
  beyond this visual repaint remains Animator scope.
- `FullFrameAnimationRegistry` owns visual-only SpriteFrames lookup/placement for
  allies and keeps static `ally_*.png` sprites as fallback. Gameplay damage,
  targeting, command mode, lifetime, and summon role scaling remain in
  `SummonerWeapon` / `AllyMinion`.
- SCRUM-353 padded the wolf (`druid_beast`) frame PNGs to safe `256x256` canvas
  so transparent alpha no longer touches canvas edges; registry placement is
  `scale Vector2(0.37, 0.37)`, `position Vector2(0, -37)`.
- SCRUM-1016 (2026-07-10) adds a PixelLab-only horizontal animation contract
  for `druid_ghost_wolf`, `druid_ghost_bear`, `druid_ghost_panther`,
  `druid_ghost_stag`, and `druid_ghost_lion`. Each accepted SCRUM-1015
  character UUID supplies exactly two repository/runtime directions: 6-frame
  `move_left`/`move_right` loops at 10fps and 6-frame
  `attack_left`/`attack_right` one-shots at 12fps. Raw PixelLab west/east frames
  live below each `assets/sprites/allies/druid_ghost_*/pixellab_source/` tree;
  normalized runtime frames use transparent `256x256` cells with shared center
  X `128`, baseline Y `232`, one pack-wide scale and safe gutters. The registry
  marks these five entries `explicit_horizontal_directions`, so `AllyMinion`
  chooses the matching row and keeps `flip_h=false`; all older allies retain
  their existing source-facing flip contract. Physical wolf/bear/panther rows
  stage sweep/slam/pounce actions, while stag/lion rows stage spirit-lance/roar
  casts. This is a visual-only hook: Summon Amulet roster, spawn weighting,
  damage, aura and balance remain Backend SCRUM-902 scope.
- SCRUM-1020 (2026-07-10) replaces only the failed
  `druid_ghost_bear/move_right` row with PixelLab job
  `1585ff64-f3e8-4db7-aa8b-fd7631a40bae` from the same accepted bear UUID
  `6805608a-b64a-471c-a1d9-9601a3062e2f`. The six-frame grounded bear loop
  reduces meaningful-alpha max/min discontinuity from `2.089121x` to
  `1.083628x` while preserving `256x256`, center X `128`, baseline Y `232`,
  10fps, explicit `move_right` and no-flip contracts. The pack builder now
  rejects movement rows above `1.65x` as a coarse silhouette-continuity guard;
  contact-sheet review remains mandatory and independent re-QA is pending.

## Hit / Death

- SCRUM-185 (2026-06-13) smoke coverage now asserts representative player, standard enemy, elite, and boss rigs entering `hit` and `death` states. `play_hit()` remains a short tint/shake state; `play_death()` keeps the existing collapse/fade; gameplay health, loot, cleanup, and death ownership remain Back-end.
- SCRUM-379 (2026-06-14) smoke coverage now asserts standard full-frame enemies
  select explicit `death` animation before cleanup and that fallback enemies
  still spawn `DeathGhostRig`. Gameplay rewards/death signals fire before the
  delayed visual cleanup, so loot/score/XP are not delayed or duplicated.

## Timing / VFX Sync

- SCRUM-187 (2026-06-13) implemented Animator-owned timing polish through existing `action_id`, `action_variant`, and normalized action progress in `cutout_rig_2d.gd`. This covers windup/release/body timing where the current action call already has enough data.
- SCRUM-208 (2026-06-13) added a Back-end timing event surface for weapon modes whose gameplay beats happen after the initial action pose. `Player.play_action_animation(action_id, direction, phase := "", duration := 0.0, metadata := {})` remains backward-compatible: calls without `phase` still drive the rig/action kick exactly as before, while calls with a non-empty phase update facing, store `last_weapon_animation_event`, and emit `weapon_animation_event(event)`.
- SCRUM-239 (2026-06-13) connects those phase events back into the cutout rig as
  Animator-owned pose timing: phase calls use variant
  `weapon_id:attack_mode:phase`, so existing class-specific pose hooks can read
  both the canonical weapon and the gameplay mode while keeping damage,
  targeting, VFX spawn, and cleanup in Back-end. Animation smoke covers every
  current playable class weapon variant for phase variant preservation and a
  visible non-idle silhouette.
- Timing event payload keys: `action_id`, `phase`, `duration`, `direction`, `weapon_id`, `character_id`, `metadata`. `ClassWeapon._emit_weapon_animation_event()` adds `metadata.attack_mode`, `metadata.weapon_id`, `metadata.display_name`, and `metadata.phase_source = "class_weapon"`.
- Supported phase names for weapon sync: `windup`, `release`, `pulse`, `burst`, `deploy`, `channel`, `recover`. Durations are derived from existing gameplay timing fields such as `grenade_delay`, `burst_interval`, `amp_lifetime`, `amp_pulse_interval`, `orbit_duration`, `pool_duration`, not Animator constants.
- Covered mode families: delayed area/deploy (`grenade_cook`, `smoke_bomb`, `prism_rift`, `meteor_shards`, `priest_sanctify`, traps/mines), repeated pulse/burst (`suppression_burst`, `amp`, `priest_ward`, `bio_spore_bloom`, `bio_sample_dart`, `elemental_orbit`, `engineer_sentry_link`), and channel/beam/chain (`beam`, `dot_beam`, `drain_link`, `priest_prayer_chain`, `bio_symbiote_web`, `engineer_repair_drone`).
- Animator should consume `weapon_animation_event` or `last_weapon_animation_event` for optional sync; gameplay damage, targeting, VFX spawning, cleanup and balance remain owned by Back-end weapon code.

## Pause Behavior

- Gameplay animations/effects должны уважать паузу.
- UI может работать в `PROCESS_MODE_ALWAYS`, gameplay tweens/effects — node-bound и pause-aware.
- Persistent weapon pool VFX (`poison_pool`, `spark_pool`, `briar_pool`) use Sprite2D textures and node-bound tweens on their owning pool nodes, so their visual pulse/fade follows gameplay pause together with the pool lifetime.

## Handoffs

- Новые sprite redraw / visual style issues -> Design.
- Walk/attack/cast/death motion polish -> Animator.
- Кодовые hooks, lifecycle, cleanup, state signals -> Back-end.

- Оружие в сокете получает собственный action-kick (`cutout_rig_2d.gd::_socket_action_kick`) поверх движения руки: anticipation/выпад на attack, отдача+подброс на shoot, подъём на cast — оживляет дальнобой/каст-оружие. Базовые снаряды (`projectile.gd`) тянут дешёвый мировой `Line2D`-трейл (кэп точек, без аллокаций нод в кадре).
