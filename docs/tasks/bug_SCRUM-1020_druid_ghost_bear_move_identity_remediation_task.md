# BUG SCRUM-1020: Druid Ghost Bear Move Identity Morph

Статус: new
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
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
