# FAN-3934 round 7 — composition-rework candidate

Composes current `dev` (`6b76adfc0d…`, now `d4e93b442`) exclusion of
`presentation_v2_migration.json` in `RESERVED_DATA_FILES` with the approved lazy
executor-residency behavior in `scripts/ultimates/registry/weapon_ultimate_package_discovery.gd`.
All other approved production behavior and every original acceptance threshold are
retained; the only production delta vs the approved `1a12421ae…` is that composed
constant block (9 insertions / 3 deletions).

## Validation on the composed source (observed driver, exclusive gate, strict
foreign-overlap check: NONE during any live run window; all exits 0)

| Run | Peak / limit | FPS avg / 1% | Mem |
|---|---:|---:|---:|
| P3 run 1 | 3,832 / 4,000 | 115.6 / 92.7 | 128.9 MiB |
| P3 run 2 | 3,828 / 4,000 | 116.6 / 97.8 | 128.9 MiB |
| P1 | 2,244 | 115.6 / 97.7 | 119.1 MiB |
| P2 (48 held) | 4,008 / 5,000 | 111.8 / 100.1 | 128.3 MiB |

Focused suites exit 0: p3_feedback_allocation, p3_executor_residency (gates the
composed exclusion and residency parity), boss_summon_cap, boss_hazard_cap_gate,
hazard_vfx_smoke, ultimates/berserk_balance; `ultimates/presentation_contract_test`
also re-run green on the composition.

Immutable per-run SHA-256 mapping: `round7/MANIFEST.md`. All prior candidates, raws,
verdicts and history preserved; the PASSED verdict and equal SHA pins describe only
`1a12421ae…` and remain historical — fresh independent QA must approve this new exact
content before integration. Review pins for the new candidate are in issue metadata.
