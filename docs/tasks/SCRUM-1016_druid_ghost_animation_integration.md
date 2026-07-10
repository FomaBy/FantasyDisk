# SCRUM-1016 — Druid Ghost Summon PixelLab Animation Integration

Статус: done (independent re-QA FAILED — blocked by SCRUM-1022)
Контур: Codex
Owner: Animator/Codex
Thread/Worker: `/root/audit_ready`
Jira: SCRUM-1016
Parent: SCRUM-901
Design source: SCRUM-1015 (independent QA PASSED)
Backend roster/gameplay: SCRUM-902
Branch: `codex/scrum-1016-druid-ghost-animations`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1016-druid-ghost-animator-codex`
Locked writes: `assets/sprites/allies/druid_ghost_*/**`,
`assets/sprites/allies/ally_druid_ghost_*_spriteframes.tres`,
`scripts/full_frame_animation_registry.gd`, `scripts/ally_minion.gd`,
`scenes/AllyMinion.tscn` only if technically required,
`tests/animation_smoke_test.gd`, animation/current-state/content-registry docs,
Animator evidence for this task, this mirror and the scoped Jira sync-map entry.
Read-only: `scripts/summoner_weapon.gd`, progression data, Summon Amulet roster,
spawn weighting, damage, aura/balance behavior and all SCRUM-902 paths.

## Goal

Consume the exact accepted SCRUM-1015 PixelLab identities and deliver west/east
movement plus role-readable attack/cast animation packs for the five Druid ghost
summons. Integrate only the visual animation path; roster and gameplay behavior
remain Backend-owned by SCRUM-902.

## Canonical PixelLab Identities

| Runtime ID | Role | PixelLab character ID | Action target |
| --- | --- | --- | --- |
| `druid_ghost_wolf` | physical melee AoE | `8d473df8-9bc2-481c-ad58-b69cfecc5d33` | claw/body sweep |
| `druid_ghost_bear` | physical melee AoE | `6805608a-b64a-471c-a1d9-9601a3062e2f` | heavy ground slam |
| `druid_ghost_panther` | physical melee AoE | `b2d06d20-aabb-48e2-9d8a-5053daa03e8e` | pounce/circular rake |
| `druid_ghost_stag` | magical ranged caster | `f17948e2-8e1d-44f2-93f1-8f8593ae01fe` | spirit-lance cast |
| `druid_ghost_lion` | magical ranged caster | `48d76788-eeba-4a9f-a36f-bd40a8f42e07` | spectral roar projectile |

## Requirements

1. Use PixelLab MCP and the exact accepted character IDs; do not redraw or
   substitute a legacy/manual/OpenAI source.
2. Produce only west/left and east/right movement plus attack/cast animations,
   with at least five frames per direction/action.
3. Keep PixelLab source exports separate from normalized runtime assets.
4. Normalize every runtime frame to transparent `256x256`, centered on X and
   bottom-aligned to a stable common baseline with safe exterior gutters.
5. Build explicit `move_left`, `move_right`, `attack_left`, `attack_right`
   SpriteFrames rows. New ghost summons must not use horizontal flip and must
   not depend on north/south/diagonal assets.
6. Extend `FullFrameAnimationRegistry` and the narrow AllyMinion visual adapter
   so all five IDs resolve and select left/right movement/action animations,
   preserving all existing allies and gameplay logic.
7. Add focused smoke coverage for frame counts, loop flags, absence of extra
   directions, live left/right selection and attack/cast selection.
8. Deliver manifest, contact sheet and alpha/baseline/crop QA evidence including
   PixelLab character/job IDs, role, action names/counts, paths, `256x256`
   canvas and pivot/baseline contract.

## Verification Plan

- PixelLab config smoke: `get_balance`.
- Static PNG/manifest validation and contact-sheet review.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`.
- `git diff --check` and owned-path audit.

## Progress

- 2026-07-10: live Jira preflight confirmed To Do, unassigned, Codex/Animator,
  no blocked label and no competing owner/locks; SCRUM-1015 is independently
  accepted.
- 2026-07-10: claim-first completed through `jira_next_task.py` as
  `/root/audit_ready`; exact branch/worktree/locks/next verification posted to
  Jira before implementation.
- 2026-07-10: PixelLab MCP generated the requested west/east movement and
  action rows from all five exact accepted SCRUM-1015 character UUIDs. Strict
  alpha/crop and animator contact-sheet review rejected the first bear/stag/lion
  candidates where required; selected retakes are recorded in
  `pixellab_requests.json`, `pixellab_jobs.json` and `pixellab_job_ids.json`.
- 2026-07-10: the final pack contains 120 raw PixelLab PNGs plus 120 normalized
  runtime PNGs. Automated pack audit passed: transparent `256x256`, shared
  center X `128`, baseline Y `232`, minimum gutter `20`, no north/south/diagonal
  repository assets and no horizontal flip.
- 2026-07-10: `animation_smoke_test.gd` PASS; `runtime_smoke_test.gd` PASS
  (exit `0`; the existing dummy-renderer screenshot path still logs its known
  non-gating null-texture warning). Static manifest/PNG/JSON audit and
  `git diff --check` PASS.

## Implementation Result (pre-QA)

- Five `SpriteFrames` resources expose `move`, `move_left`, `move_right`,
  `attack`, `attack_left`, and `attack_right`; directional rows contain six
  distinct PixelLab frames, move loops at 10fps and action is a 12fps one-shot.
- `FullFrameAnimationRegistry` owns the five exact visual IDs and marks them as
  explicit-horizontal. `AllyMinion` selects left/right rows, keeps `flip_h`
  disabled for these entries and preserves all existing ally flip behavior.
- Evidence: `docs/design/references/druid_summons_ghost_animation_pack/` and
  `docs/design/previews/druid_summons_ghost_animation_pack_contact.png`.
- Gameplay/balance/roster paths were not changed; SCRUM-902 remains the Backend
  integration owner.
- Independent QA is still required before Jira may move from
  `Контроль качества` to `Готово`.
- Landed to `origin/dev` as commit `af5b5543`; Jira moved to
  `Контроль качества`, not `Готово`.
- Disk cleanup: removed task `.godot` cache (452 MB), Python `__pycache__`,
  temporary PixelLab download and smoke logs. The clean task worktree is removed
  after this final mirror update reaches `origin/dev`.
- Thread cleanup: not a disposable worker thread; this subagent reports back to
  the parent coordinator.

## Independent QA Verdict (2026-07-10)

Status: **FAILED**

Independent reviewer: Animator QA `/root/audit_qa` on fresh
`origin/dev` `1a5c211579d1723b435b84cf6cae0460cf2dc777`. The reviewer did not
implement SCRUM-1016 and did not modify its production assets or runtime code.

### Blocking visual defect

`druid_ghost_bear/move_right` does not preserve one coherent bear identity:
frames `00..02` read as a lean canine/fox-like quadruped, while frames `03..05`
abruptly become a heavy bear. Meaningful-alpha area jumps from `7,372..8,253`
pixels to `13,871..15,403` pixels (`2.09x` max/min), producing a visible
species/scale pop at the configured `10 fps`. The all-frame contact sheet shows
the discontinuity in the bear `move_right` row.

Remediation: Jira **SCRUM-1020**, linked as blocking SCRUM-1016. SCRUM-1016
stays in `Контроль качества` with `blocked` + `qa-failed` labels until the
PixelLab bear movement row is replaced and accepted by a new independent visual
QA pass.

### Checks that passed

- PixelLab MCP config `get_balance` and live `get_character` for all five exact
  character UUIDs.
- All 20 selected live animation job UUIDs and all 120 live frame URLs (`0..5`)
  matched the evidence. This confirms PixelLab v3's reference frame is excluded
  and the six animated frames are retained.
- Live PixelLab downloads matched all 120 committed raw source PNGs by SHA-256;
  every row contains six unique source/runtime hashes.
- Source/runtime separation, `.gdignore`, RGBA `256x256` runtime canvas,
  meaningful alpha, shared center X `128`, shared bbox bottom/baseline `232`,
  and minimum runtime gutter `20 px` passed.
- Five SpriteFrames resources, explicit left/right selection, no horizontal
  flip, texture/canvas/runtime-path assertions, attack/cast aliases, vertical
  last-facing fallback, and the true `6 / 12 = 0.50 s` action window passed.
- The contact sheet includes all six representative frames for all 20 rows; it
  is the evidence that exposed the visual defect rather than an automated PASS.
- `tests/animation_smoke_test.gd`: PASS.
- `tests/runtime_smoke_test.gd`: PASS, exit `0`; only the known dummy-renderer
  `texture_2d_get` screenshot warning was emitted.
- `tests/meta_progression_smoke_test.gd`: PASS.
- `tests/melee_weapon_targeting_test.gd`: PASS.
- `git diff --check`: PASS.

Bugs: SCRUM-1020.

## Independent Re-QA Verdict (2026-07-10)

Status: **FAILED — blocked by SCRUM-1022**

The new independent reviewer `/root/audit_ready` verified that SCRUM-1020 fully
removes the original bear `move_right` identity morph: the exact same accepted
bear UUID and selected live v3 job match all six committed raw-source hashes,
the row is one grounded heavy-bear gait at original/contact-sheet scale, and its
meaningful-alpha ratio is now `1.083628x`. The full five-creature live PixelLab
rebuild byte-matched all `246` deterministic source/runtime/SpriteFrames/contact
artifacts, and all pack geometry/direction/no-flip checks pass.

SCRUM-1016 still cannot be accepted because the broader integration contract is
red: `tests/full_frame_registry_integrity_test.gd` reports five errors, one for
each `druid_ghost_*` registry entry, because `source_faces_left` is not an
explicit bool. Jira Bug **SCRUM-1022** was created and corrected to outwardly
block SCRUM-1020, SCRUM-1016 and parent SCRUM-901. Production was not modified
by QA.

Verification summary:

- PASS live PixelLab UUID/job/frame URLs and six bear SHA-256 matches;
- PASS visual bear continuity, all five ghost contact rows and role readability;
- PASS 120 raw + 120 runtime PNG, `256x256`, center `128`, baseline `232`,
  minimum gutter `20`, row uniqueness and movement ratios `<=1.65x`;
- PASS clean Godot import, `animation_smoke_test.gd`,
  `asset_reference_integrity_test.gd`, `ally_minion_lifecycle_test.gd`,
  `runtime_smoke_test.gd`, `meta_progression_smoke_test.gd` and
  `melee_weapon_targeting_test.gd`;
- **FAIL** `full_frame_registry_integrity_test.gd` (five missing typed fields).

Bugs: SCRUM-1022. Jira remains `Контроль качества` / QA failed.
