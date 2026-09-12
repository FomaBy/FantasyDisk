# FAN-3934 — protected CI ultimate/Atlas fragment failure: diagnosis

Investigation branch `fan3934-atlas-diagnosis` from approved source
`384f69be11c6490cbcb0804e489e3d3b9a56dcd7` (tree `7662c6d0d1ffff7054514221f544c87f41535b27`).
Write set used: only `evidence/p3-object-budget-rework/ci-atlas-diagnosis/**`.

## Binding

- Failed job: `103613162708`, run `34715975730` (PR #357), 16 static checks + 545
  Godot suites; suite 523 `tests/a5/scenarios/ultimate_atlas_attribution_test.gd`
  FAILED with "committed ultimate/Atlas fragment must exist".
- Synthetic merge `6d454ed7ef6f04cf834e58c31dc16d593533a9e9` (fetched from the PR
  merge ref; parents = target `b0ebba8f3` + source `384f69be`) has tree
  `7662c6d0d1ffff7054514221f544c87f41535b27` — equal to the approved source tree.
- The fragment `docs/design/reports/fan1438_a5_balance/fragments/ultimate_atlas/ultimate_atlas_attribution.json`
  IS tracked in that tree (blob `a9a19376c5bc280fc822185235304a3133f4ec57`; working-tree
  copy SHA-256 prefix `26c0b1074dbbd7cd` after full checkout). No merge-content change.

## Root cause (reproduced deterministically)

`.github/workflows/quality.yml`'s `static-quality` checkout uses a sparse cone that
includes only two explicit files under `fan1438_a5_balance/fragments/` —
`conditional/conditional_final_convergence.json` and
`defensive/defensive_reactive_qol.json` — plus `raw.json.gz`. The `ultimate_atlas/`
(and `offensive/`) fragment subtrees are tracked in git but are NOT in the cone, so
they are never materialized on the runner; the suite's
`FileAccess.file_exists(Pack.FRAGMENT_PATH)` observation is correctly false for a
file that does not exist on disk there.

Reproduction (isolated checkout at the synthetic merge commit, workflow's exact cone
plus root project files):

- Sparse cone applied → fragment ABSENT from the working tree while tracked.
  Suite run: **exit 1**, `ERROR: ultimate_atlas_attribution_test: committed
  ultimate/Atlas fragment must exist` (`sparse-cone-suite-fail.log`) — byte-for-byte
  the CI failure.
- Same commit, sparse disabled → fragment present; suite run: **exit 0,
  PASS** (`full-checkout-suite-pass.log`).

## Why dev's own CI is green while the PR fails

Push events to `dev` run `--static-only` (no Godot suites); candidate events
(pull_request/merge_group) run the changed-profile Godot selection, which selected
545 suites including the atlas suite. The suite was added to `dev` with the fragment
outside the cone — a latent gap that surfaces on the first candidate event that
selects it, not a regression of this candidate's content (whose tree equals the
merge tree and contains the fragment).

## Proposed repair paths (requiring a precise supporting-scope decision; not executed)

1. Add `docs/design/reports/fan1438_a5_balance/fragments` (the whole fragments
   subtree, covering `ultimate_atlas`, `offensive` and future fragments) to the
   sparse-checkout cone in `.github/workflows/quality.yml`. Smallest, static, and
   removes the whole latent class (the `offensive/` subtree has the same gap).
2. Alternatively add the single `ultimate_atlas/…json` path — minimal but leaves the
   `offensive/` latent gap.
3. Alternatively derive the cone for this directory from the suite's declared inputs
   (pattern like the manifest-driven LFS materialization) — larger change, same file.

All three are edits to `.github/workflows/quality.yml` (plus possibly
`tests/test_quality_workflow.py` contract coverage for the new cone entries), outside
this investigation's write set.
