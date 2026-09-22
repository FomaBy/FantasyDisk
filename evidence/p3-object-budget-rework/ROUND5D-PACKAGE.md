# FAN-3934 round-5d — evidence-bearing review package

**Review candidate:** the branch successor of `d65f7cc206e1be86dd3454f7d673b622cdacc721`
(tree `5b63bbb1d9aa52feffacd9ed4d6cfeada596874c`) that contains this report correction.
Its exact SHA/tree/base are recorded in the issue metadata keys `candidate_sha`,
`candidate_tree_sha`, `candidate_base_sha` and in the single final publication comment —
not restated here, so this file cannot drift out of coherence with them.

**Measured production source (label: measured source, not the review pin):**
`1b548ee4c25458d804c1812697bbf0aa3433615f`, tree
`fa05f171008f18d552d8e0ead97bfc1e16cadf42`. Every matrix/suite measurement below was
executed with this source content; `git diff 1b548ee4c254..REVIEW_CANDIDATE -- scripts/`
is empty, and the candidate adds only `tests/p3_feedback_allocation_test.gd` and
`evidence/p3-object-budget-rework/**` changes on top of it. Raw JSON files retain their
recorded `candidate_sha` of the measuring checkout (`f889eeeb…`, test/evidence-only
successor of `1b548ee4`); these are historical measured-source fields, labeled as such
by this manifest, not review pins.

**Sole contributing author / reviewer exclusion ID:** dev_high agent
`11dd50f9-2322-4aa0-a09e-631e1159c1df`.

## What this round added

1. **Observed measurements** (`round5d/`, driven by the evidence-owned foreground
   driver `run_observed.py`): expanded argv, environment, own PID, verbatim
   `ps axo pid,pcpu,time,command` output sampled every 5 s while each run was live,
   plus before/after observations — foreign processes preserved, never cancelled.
   Strict overlap check (in manifest verification): NO foreign Godot process was live
   during any matrix run window. One foreign headless suite appeared in a pre-run
   sample at 18:14:54Z and ended before the first P3 live sample; raw observations
   retain it verbatim.
2. **Immutable manifest** (`round5d/MANIFEST.md`): per run — command, staging raw
   names, published JSON/CSV/log/env names with SHA-256, recorded candidate SHA,
   pass/peak and exit status; six focused-suite command/output/exit records likewise.
3. **Completed parity assertions** in `tests/p3_feedback_allocation_test.gd`:
   pre-pause position captured and asserted byte-frozen across the paused window;
   complete seeded RNG sequence asserted across all three labels (exact x offsets,
   y-jitter differences); the deleted enemy's own label identified by its seeded
   offset, asserted to survive the owner, live its full 0.62 s, release to the pool
   and leave the cap group; overlap restart curve asserted against the closed-form
   expected color per channel plus continuity; all previous gates retained.
4. **ROUND5C-PACKAGE.md source/branch-tip statement corrected** (marked CORRECTION).

## Matrix results (all PASS, exit 0, zero foreign overlap during live windows)

| Run | Peak / limit | FPS avg / 1% | Mem |
|---|---:|---:|---:|
| P3 run 1 | 3,593 / 4,000 | 119.1 / 106.8 | 128.6 MiB |
| P3 run 2 | 3,815 / 4,000 | 118.1 / 102.9 | 128.9 MiB |
| P1 | 2,271 | 119.7 / 111.0 | 119.6 MiB |
| P2 (48 held) | 4,023 / 5,000 | 112.6 / 106.6 | 128.5 MiB |

Six focused suites exit 0: p3_feedback_allocation, p3_executor_residency,
boss_summon_cap, boss_hazard_cap_gate, hazard_vfx_smoke, ultimates/berserk_balance.
