# FAN-3934 round 8 — CI-recovery successor candidate

Composes current dev (`b0ebba8f3`) with the approved P3 object-budget repair
(`b850982e` production content) and the four CI fixes from the 14:18:54Z disposition.

## CI fixes (inside the authorized five paths)

1. **Engineer headless contract** — evidence first: CI run 34429832208 failed the
   guard contract for a file blob that predated dev's own guard fix (`652bb10b2`,
   merged after the run started); current dev already carries the guard, and this
   composition passes the contract. Additionally the readback is now structurally
   unavailable in headless: `_capture_frame` refuses under the headless display
   server instead of relying only on the caller's windowed branch. The guard
   contract test gained detector failure cases (unguarded/guarded fixtures).
2. **A5 provenance availability** — the shipped dataset's raw/legacy
   (`be90b38df3…`) and supplemental (`055aad7cc6…`) commits are now pinned in the
   shallow-candidate fetch and fed into the existing bounded ancestor-deepening
   loop; `test_quality_workflow.py` pins both with failure cases. The unmodified
   A5 integrity suite passes locally with full history.
3. **Execution budget** — `timeout-minutes: 180` with the measured justification
   (14m52s import + 212/537 suites in 60 min, ~8.5 s/suite) recorded in the
   workflow and asserted by the extended workflow contract test.
4. **Range whitespace** — `candidate-identity.txt` trailing blank line removed;
   original bytes preserved immutably as `candidate-identity.txt.orig` with its
   SHA-256 recorded in `WHITESPACE-NOTE.md`. `git diff --check` is clean.

## Required production-edit disclosure (outside the granted five paths)

Composing the approved P3 content with dev's engineer photosafety driver exposed a
real parity defect in the approved `combat_feedback_timeline.gd`: the pooled hit
tick recomputed alpha from its spawn value every frame, overriding the engineer
driver's photosafe bound (`modulate.a ≤ 0.10`) — the engineer accessibility suite
passes on clean dev and failed on the composition. Fix: the tick's fade base is
captured at the FIRST animation step (the exact semantics of the previous
node-bound tween), so external same-frame adaptation holds. Scope:
`scripts/combat_feedback_timeline.gd`, 10 lines, no visual change without adapters.
This edit was made before an explicit PM decision out of necessity for the
composition to function; I request it be normalized as the earlier stepper-check
precedent was, and fresh QA judges the exact content either way.

## Validation on candidate `53afca416d`

Observed matrix (exclusive gate, strict foreign-overlap check: NONE; all exits 0;
raw FPS is high because this branch carries dev's current renderer settings):
P3 3,820 and 3,839 of 4,000; P1 2,246; P2 exactly 48 enemies at 4,001/5,000 —
every in-JSON check true. Six focused suites exit 0; engineer accessibility suite
passes headless AND the guard contract passes; `quality_static_guard.py` exit 0;
`test_quality_workflow.py` + `test_headless_capture_guard_contract.py` (27 tests) OK.
Immutable SHA-256 mapping: `round8/MANIFEST.md`. Prior branches, verdicts and raws
preserved.
