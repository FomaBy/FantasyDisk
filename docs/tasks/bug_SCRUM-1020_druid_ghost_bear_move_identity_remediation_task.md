# BUG SCRUM-1020: Druid Ghost Bear Move Identity Morph

Статус: done (independent re-QA FAILED — blocked by SCRUM-1022)
Контур: Codex
Owner: Animator/Codex
Thread/Worker: `/root/audit_qa`
Роль: Animator
Jira: SCRUM-1020
Found by QA: SCRUM-1016
Blocks: SCRUM-1016
Sprint: live `Спринт 0.2.1`
Fix Version: `0.2.1`
Locked paths: `assets/sprites/allies/druid_ghost_bear/pixellab_source/move/**`,
`assets/sprites/allies/druid_ghost_bear/runtime/druid_ghost_bear_move_*.png*`,
`assets/sprites/allies/ally_druid_ghost_bear_spriteframes.tres` only if paths
change, bear-selected job/provenance records under
`docs/design/references/druid_summons_ghost_animation_pack/**`,
`docs/design/previews/druid_summons_ghost_animation_pack_contact.png`, focused
animation evidence/tests if needed, this mirror, scoped Jira sync map.

Branch: `codex/scrum-1020-bear-move-remediation`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1020-bear-move-remediation`
Base: `origin/dev` `5d585d7a788080f1e8e3a44cc0592e6b7c8692a1`

## Context

Independent Animator QA of SCRUM-1016 found a blocking visual defect in the
selected PixelLab movement row for `druid_ghost_bear`. All provenance, hash,
alpha/baseline, SpriteFrames/runtime-hook and Godot regression gates passed; the
failure is the visible identity continuity of the animation itself.

Exact accepted PixelLab character UUID:
`6805608a-b64a-471c-a1d9-9601a3062e2f`.

No manual, OpenAI, legacy or different-character substitution is permitted.

## Reproduction

1. Open
   `docs/design/previews/druid_summons_ghost_animation_pack_contact.png`.
2. Inspect `druid_ghost_bear / move_right`, frames `0..5`.
3. Compare
   `assets/sprites/allies/druid_ghost_bear/runtime/druid_ghost_bear_move_right_00.png`
   with `..._03.png`, or play the row at `10 fps`.

## Expected / Actual

Expected: all six frames preserve the same heavy spectral bear identity,
comparable body mass/proportions/palette, and a coherent grounded quadruped gait
without rearing, crop or scale pop.

Actual: frames `00..02` read as a lean canine/fox-like animal, then frames
`03..05` switch to a large bear. Visible-alpha area changes from
`7,372..8,253` to `13,871..15,403` pixels (`2.09x` max/min).

## Required Animator Remediation

1. Use PixelLab MCP with the exact accepted bear UUID and replace/reselect the
   movement generation. Replace both west/east rows if necessary for mutual
   identity and scale consistency.
2. Preserve six frames per direction, `10 fps`, looped `move_left/right`,
   explicit horizontal rows and `flip_h = false`.
3. Keep raw PixelLab source separate from transparent normalized runtime PNGs:
   `256x256`, center X `128`, bbox bottom/baseline `232`, runtime gutters
   `>= 12 px`.
4. Preserve the accepted attack rows and all existing registry/AllyMinion/gameplay
   behavior unless a narrow path update is technically required.
5. Update exact selected PixelLab job IDs, manifest/provenance, live-source
   hashes, alpha/baseline report and the all-frame contact sheet.
6. Do not touch roster, spawning, damage, aura, balance, SCRUM-902 paths, other
   ghost packs, or unrelated Claude locks.

## Acceptance Criteria

- Live PixelLab UUID/job/frame-URL verification and committed source SHA-256
  comparison pass.
- Both bear movement rows contain six unique, coherent bear frames with no
  species, body-mass, scale, crop or palette morph.
- Source/runtime separation and `256x256` normalization contract pass.
- `animation_smoke_test.gd` and `runtime_smoke_test.gd` pass through
  `tools/godot_gate.py`.
- Contact sheet shows all six frames of both bear movement directions.
- A new independent visual QA reviewer accepts the loop before SCRUM-1016 moves
  to `Готово`.

## QA Evidence

- Base: `origin/dev` `1a5c211579d1723b435b84cf6cae0460cf2dc777`.
- Godot 4.7 on macOS.
- Static/live provenance and automation passed; only visual identity continuity
  failed.
- Original Jira issue remains in `Контроль качества`, labeled `blocked` and
  `qa-failed`.

## Implementation Result (2026-07-10)

Animator remediation is complete and must be accepted by a different
independent QA reviewer.

- PixelLab MCP config `get_balance` passed without printing secrets.
- Exact accepted bear UUID remained
  `6805608a-b64a-471c-a1d9-9601a3062e2f`; no OpenAI/manual/legacy/different-
  character source was used.
- Existing live rows were inspected first. `ghost_move_centered` and
  `ghost_move_quadruped` rear upright, `running` changes mass/crop, and the
  selected `walking` row was the QA-rejected canine-to-bear morph.
- Selected east-only v3 job:
  `1585ff64-f3e8-4db7-aa8b-fd7631a40bae`, folder
  `scrum1020_grounded_bear_walk_right_v1`, anchored with a same-UUID heavy-bear
  frame. A second candidate `127fa29e-bafa-402f-bca2-4960e61644d1` was rejected
  before import because its final frames gradually reared upright.
- Replaced only six raw `pixellab_source/move/right` PNGs and the matching six
  normalized runtime PNGs. SpriteFrames paths, 10fps loop, explicit right
  direction, no-flip runtime hook, attacks and all gameplay data remain intact.
- New runtime row: six unique RGBA `256x256` frames; center X error `<=0.5 px`,
  bbox bottom/baseline `232`, minimum runtime gutter `24 px`, meaningful-alpha
  counts `[15329,14577,14951,14457,14146,14964]` and max/min ratio
  `1.083628x` (before: `2.089121x`).
- All six committed raw sources match the selected live PixelLab job by
  SHA-256. Source/runtime hashes and bboxes are committed in
  `scrum1020_remediation_report.json`.
- The pack builder now records hashes/meaningful alpha and rejects any movement
  row above the coarse `1.65x` silhouette-continuity threshold. This does not
  replace independent visual review.
- The focused Godot smoke adds the same imported-texture alpha-area regression
  assertion for bear `move_right`.
- Full all-frame contact sheet was regenerated and visually self-checked: all
  six right-move frames read as one grounded heavy bear without the rejected
  species/scale jump. Independent re-QA remains mandatory.

### Verification

- `python3 docs/design/references/druid_summons_ghost_animation_pack/build_animation_pack.py`: PASS (`120` source, `120` runtime, `20 px` pack minimum gutter).
- Live PixelLab UUID/job/frame URL + six-source SHA audit: PASS.
- JSON validation and `python3 -m py_compile` for the builder: PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`: PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`: PASS, exit `0`; known dummy-renderer `texture_2d_get` screenshot warning only.
- `git diff --check`: PASS.

### Ownership boundary

No changes were made to `ally_minion.gd`, `FullFrameAnimationRegistry`, roster,
spawn weights, targeting, damage, aura, balance, other ghost assets or
SCRUM-902 paths. Jira must stop at `Контроль качества` after push;
this implementation owner does not self-accept.

## Independent Re-QA Verdict (2026-07-10)

Status: **FAILED — blocked by SCRUM-1022**

Independent reviewer: Animation/Design QA `/root/audit_ready` on fresh
`origin/dev` `c1ddbed6c0134204e853dc5489b1120fd295d845`. The reviewer did not
author SCRUM-1020 and treated production assets, scripts and tests as read-only.

The bear remediation itself passes its visual and provenance criteria:

- PixelLab MCP `get_balance` and live `get_character` passed for exact accepted
  bear UUID `6805608a-b64a-471c-a1d9-9601a3062e2f`.
- Live east-v3 job `1585ff64-f3e8-4db7-aa8b-fd7631a40bae` exposes exactly
  frames `0..5`; all six fresh downloads are byte-identical by SHA-256 to the
  committed immutable raw sources.
- All six `move_right` frames were reviewed at original resolution and in the
  complete contact sheet. They preserve one heavy cyan spectral bear, a
  grounded coherent four-paw gait and stable mass/palette, with no canine/fox,
  rearing, crop or scale morph.
- Independent PNG audit reproduced `256x256`, center X `128`, bbox bottom /
  baseline `232`, minimum gutter `24 px`, six unique frames and meaningful-alpha
  ratio `1.083628x` (below the `1.65x` guard; previous row `2.089121x`).
- A clean isolated builder replay downloaded all five exact live PixelLab packs
  and byte-matched all `120` raw PNGs, `120` runtime PNGs, five SpriteFrames and
  the contact sheet (`246/246` deterministic files).
- Remediation scope is narrow: only six bear east raw frames, six normalized
  runtime frames, evidence/builder/test/docs changed; no gameplay, registry,
  AllyMinion, SpriteFrames path, other ghost asset or SCRUM-902 change.

### Blocking regression

`tests/full_frame_registry_integrity_test.gd` exits `1`: all five new registry
entries `ally/druid_ghost_wolf`, `ally/druid_ghost_bear`,
`ally/druid_ghost_panther`, `ally/druid_ghost_stag` and
`ally/druid_ghost_lion` omit the required boolean `source_faces_left` field.
Runtime currently supplies a default, so the focused animation path works, but
the repository's typed registry integrity contract is red.

New Jira Bug **SCRUM-1022** was created in the active sprint and its corrected
live Jira link payload exposes SCRUM-1020, SCRUM-1016 and SCRUM-901 as
`outwardIssue` blocker targets. No production fix was made by QA.

Other gates:

- clean Godot 4.7 import: PASS (`120/120` ghost runtime `.ctex` resources);
- `tests/animation_smoke_test.gd`: PASS;
- `tests/asset_reference_integrity_test.gd`: PASS (`200` files / `2549` refs);
- `tests/ally_minion_lifecycle_test.gd`: PASS;
- `tests/runtime_smoke_test.gd`: PASS, exit `0` (known non-fatal dummy-renderer
  screenshot warning only);
- `tests/meta_progression_smoke_test.gd`: PASS;
- `tests/melee_weapon_targeting_test.gd`: PASS;
- static manifest/hash/PNG/SpriteFrames audit and `git diff --check`: PASS.

Bugs: SCRUM-1022. SCRUM-1020 must remain in `Контроль качества` until the
registry contract is fixed and independently re-verified.
