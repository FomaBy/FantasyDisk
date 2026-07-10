# BUG SCRUM-1022: Druid Ghost Registry Omits `source_faces_left` Bool

Статус: done
Контур: Codex
Owner: /root/audit_qa
Thread/Worker: collaboration subagent `/root/audit_qa`
Роль: Animator / Back-end animation integration
Jira: SCRUM-1022
Found by independent QA: SCRUM-1020 / SCRUM-1016
Blocks: SCRUM-1020, SCRUM-1016, SCRUM-901
Sprint: live `Спринт 0.2.1`
Fix Version: `0.2.1`
Recommended locked paths: `scripts/full_frame_animation_registry.gd`,
`tests/full_frame_registry_integrity_test.gd` only if intentionally revising the
typed contract, this mirror and scoped `docs/process/jira_sync_map.json`.
Active branch/worktree: `codex/scrum-1022-druid-ghost-registry` at
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1022-druid-ghost-registry`.
Read-only/out of scope: `assets/sprites/allies/druid_ghost_*/**`,
`assets/sprites/allies/ally_druid_ghost_*_spriteframes.tres`,
`scripts/ally_minion.gd`, Summon Amulet roster/spawning/damage/aura/balance and
all SCRUM-902 paths.

## Context / Problem

Independent regression QA on fresh `origin/dev` `c1ddbed6` found that the five
SCRUM-1016 Druid ghost entries in `FullFrameAnimationRegistry` omit the typed
`source_faces_left` boolean required by the repository integrity contract.
Runtime currently defaults the missing value, so the focused animation smoke is
green, but the authoritative registry integrity gate is red.

Affected IDs:

- `ally/druid_ghost_wolf`;
- `ally/druid_ghost_bear`;
- `ally/druid_ghost_panther`;
- `ally/druid_ghost_stag`;
- `ally/druid_ghost_lion`.

## Environment

- Godot `4.7.stable` on macOS;
- clean imported worktree at `origin/dev` `c1ddbed6`;
- SCRUM-1020 remediation commit `4adad78e` plus sync `c1ddbed6`.

## Steps To Reproduce

1. Check out fresh `origin/dev` `c1ddbed6` and perform a clean Godot import.
2. Run `python3 tools/godot_gate.py --headless --path . --script res://tests/full_frame_registry_integrity_test.gd`.
3. Observe five `'source_faces_left' не bool` errors and exit code `1`.

## Expected / Actual

Expected: every registered full-frame entry satisfies the typed configuration
contract, while explicit Druid ghost left/right rows continue to use no flip.

Actual: the five entries rely on a runtime default instead of declaring the
boolean required by `full_frame_registry_integrity_test.gd`.

## Acceptance Criteria

- All five affected IDs expose a valid explicit `source_faces_left` bool, or the
  registry and validator are deliberately revised so the field is optional only
  when `explicit_horizontal_directions == true`; runtime and test contracts must
  agree.
- `tests/full_frame_registry_integrity_test.gd` passes through
  `tools/godot_gate.py`.
- `tests/animation_smoke_test.gd`, `tests/asset_reference_integrity_test.gd` and
  `tests/runtime_smoke_test.gd` remain green.
- Explicit `move_left/right` and `attack_left/right` selection remains no-flip
  for all five ghost allies.
- PixelLab assets, runtime PNGs, SpriteFrames, roster, spawning, damage, aura and
  balance remain unchanged.
- A different independent QA reviewer accepts the narrow remediation before
  SCRUM-1020, SCRUM-1016 or SCRUM-901 may close.

## QA Evidence

- Bear SCRUM-1020 live provenance/SHA/visual continuity: PASS.
- Full five-pack live rebuild and static PNG/SpriteFrames audit: PASS.
- `animation_smoke_test.gd`: PASS.
- `asset_reference_integrity_test.gd`: PASS.
- `ally_minion_lifecycle_test.gd`: PASS.
- `runtime_smoke_test.gd`: PASS.
- `meta_progression_smoke_test.gd`: PASS.
- `melee_weapon_targeting_test.gd`: PASS.
- `full_frame_registry_integrity_test.gd`: **FAILED**, five exact errors above.

Jira link direction was corrected after live-payload audit: SCRUM-1022 now
exposes SCRUM-1020, SCRUM-1016 and SCRUM-901 as `outwardIssue` blocker targets.
No production fix was made by QA.

## Implementation Result (2026-07-10)

- Added explicit `"source_faces_left": true` to all five Druid ghost registry
  entries. `true` records the pack's canonical left-facing source convention;
  `"explicit_horizontal_directions": true` remains authoritative for runtime
  row selection and continues to force `flip_h = false`.
- Preserved every SpriteFrames path, scale, position and explicit-direction flag.
  No PNG, SpriteFrames, `AllyMinion`, roster, spawn, damage, aura or balance file
  was changed.
- Kept `tests/full_frame_registry_integrity_test.gd` unchanged: its strict typed
  contract is correct. Existing `animation_smoke_test.gd` already proves all
  five spirits select left/right move/attack (and caster aliases) without flip.
- Product/system docs were not changed because the documented runtime behavior
  remains exactly the SCRUM-1016 explicit-row/no-flip contract.

Verification through `tools/godot_gate.py`:

- pre-fix `full_frame_registry_integrity_test.gd`: reproduced **FAILED** with the
  five expected `source_faces_left` type errors;
- post-fix `full_frame_registry_integrity_test.gd`: **PASS** (36 entries);
- `animation_smoke_test.gd`: **PASS**;
- `asset_reference_integrity_test.gd`: **PASS** (200 files / 2549 references);
- `ally_minion_lifecycle_test.gd`: **PASS**;
- `melee_weapon_targeting_test.gd`: **PASS**;
- `runtime_smoke_test.gd`: **PASS** (exit 0; duplicate-artifact guard passed).

Next status: independent QA must verify this remediation before SCRUM-1022 or
its blocked source tickets can move to `Готово`.
