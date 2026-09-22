# FAN-3934 round 6 — QA-rework candidate (exact body-flash endpoint)

QA verdict 01a0879b found a real defect in `52ee0d77`: `_step_bodies` removed a
completed record without assigning its recorded restore color, so the frame crossing
0.16 s left the last interpolated tint and repeated hits drifted the body tint.

## Repair (bounded, existing paths)

- `scripts/combat_feedback_timeline.gd::_step_bodies`: when a live record completes,
  the exact recorded `restore` value is assigned before removal (invalid-target
  handling, overlap/restart, timing and allocation semantics unchanged).
- `tests/p3_feedback_allocation_test.gd`: strict regression — exact endpoint via
  `is_equal_approx` per channel at a non-aligned lifetime crossing, plus four
  repeated flash/reuse rounds from a non-white base tint; zero tolerance drift.
  Before/after evidence: `round6/regression-before-after.txt` (FAIL on `52ee0d77`,
  PASS on the fix). All prior parity gates retained.

## Fresh source-bound matrix on the final production source (observed driver)

| Run | Peak / limit | FPS avg / 1% | Mem | Foreign overlap | Exit |
|---|---:|---:|---:|---|---:|
| P3 run 1 | 3,856 / 4,000 | 114.2 / 107.5 | 128.9 MiB | NONE | 0 |
| P3 run 2 | 3,840 / 4,000 | 114.2 / 88.4 | 128.8 MiB | NONE | 0 |
| P1 | 2,244 | 117.1 / 94.2 | 119.1 MiB | NONE | 0 |
| P2 (48 held) | 4,004 / 5,000 | 109.7 / 76.8 | 128.3 MiB | NONE | 0 |

Six focused suites exit 0 (feedback, residency, summon, hazard, hazardsmoke, berserk).
Immutable per-run mapping with SHA-256: `round6/MANIFEST.md`. Prior raws, manifests
and history preserved; prior measured-source matrices are historical evidence.

Review pins live in issue metadata (candidate/dispatch/qa SHA, tree, base, author,
readiness flags) — see the publication comment.
