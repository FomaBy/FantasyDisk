# FAN-3934 round-5d — evidence-bearing review package (supersedes round-5c for admission)

Measured production source: `1b548ee4c25458d804c1812697bbf0aa3433615f`, tree
`fa05f171008f18d552d8e0ead97bfc1e16cadf42` (unchanged since round-5c; the PM-accepted
freed-origin validity checks are part of it). This review/evidence branch tip carries
only test and evidence changes on top of that production commit:
`git diff 1b548ee4c254..HEAD -- scripts/` is empty — production bytes identical.

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

Author: dev_high `11dd50f9-2322-4aa0-a09e-631e1159c1df` (sole contributor).
candidate_sha = dispatch_candidate_sha = qa_candidate_sha = `1b548ee4c25458d804c1812697bbf0aa3433615f`;
candidate_tree_sha = `fa05f171008f18d552d8e0ead97bfc1e16cadf42`.
