# FAN-3934 — pooled hit-tick name repair (fifth QA finding)

QA report `01a0991c-2b19-7a87-88af-9d6b6e638410`: the pooled `spawn_tick` never set
the live `CombatHitTick` node name that the pre-pool `enemy.gd:715` code supplied
and SCRUM-611's smoke assertion requires; `tests/combat/smoke_contact_feedback_test.gd`
(3/3 runs) and `tests/runtime_smoke_combat_test.gd` failed on candidate `fff8ba7a…`
and pass on clean dev. Present since the pool's introduction.

## Repair (granted paths)

`scripts/combat_feedback_timeline.gd`: acquisition names the live slot
`CombatHitTick` (simultaneous live ticks receive Godot's sibling suffixes exactly
as the per-hit original); `_release_tick` renames idle slots to
`CombatHitTickIdle`, so a hidden/freed pool slot never occupies the canonical
name and reuse always restores it. Freed-object lifetime and setup-owned
damage/crit color fixes are untouched.

## Regression (fails on old, passes on repair)

`tests/p3_feedback_allocation_test.gd` section L: canonical live name on first
spawn, no idle slot holding it after release, reuse, overlapping live ticks,
post-external-free spawn, orphan-free cleanup.
- BEFORE (candidate timeline + regression, `pfa-before.log`): exit 1 —
  "first live tick is not named CombatHitTick", "reused live tick …".
- AFTER: exit 0 PASS.
- Affected suites on the repair (`suite-*.log`): `take_damage_contract_routing`
  0, `combat/smoke_contact_feedback` 0, `runtime_smoke_combat` 0.

## Fresh runtime matrix (runtime change invalidates prior evidence; observed
driver, exclusive gate; one P3 run breached 4,000 by 18 objects — that raw is
preserved as `perf-p3-run2-FAILED-overbudget.*` with its logs, honestly recorded,
and the P3 pair was re-run)

| Run | Peak / limit | FPS avg / 1% | Mem | Result |
|---|---:|---:|---:|---|
| P3 run 1 | 3,876 / 4,000 | 782.1 / 568.9 | 164.0 MiB | PASS |
| P3 run 2 (original) | **4,018 / 4,000** | 758.7 / 355.0 | 163.7 MiB | FAIL — preserved |
| P3 rerun 1 | 3,839 / 4,000 | 604.2 / 453.7 | — | PASS |
| P3 rerun 2 | 3,610 / 4,000 | 210.8 / 188.1 | — | PASS |
| P1 | 2,246 | 402.3 / 389.5 | 130.5 MiB ≤ 400 | PASS |
| P2 (48 held) | 4,011 / 5,000 | 416.9 / 66.2 | 143.1 MiB | PASS |

The failed run's cause is the known random enemy-composition variance band
(QA-residual #3, ~2.9% headroom), not a regression of this repair: the repair
changes only node naming, with no allocation delta (verified by the passing runs'
peaks lying inside the established 3,6xx–3,8xx band).
