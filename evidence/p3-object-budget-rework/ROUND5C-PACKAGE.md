# FAN-3934 round-5c — complete review-admission package

Candidate for review: production source `1b548ee4c25458d804c1812697bbf0aa3433615f`,
source tree `fa05f171008f18d552d8e0ead97bfc1e16cadf42`. CORRECTION (16:08 UTC PM
continuation): this commit was the branch tip only at publication time; the pushed
evidence successor `1096a43257c9ec613085f1a2c3be1667da6c1e24` (tree
`3d2c01f71c7a94c6eb24a33848201249e8bc7776`) is the branch tip, and its direct-parent
diff is evidence-only. The round-5d package supersedes this one for admission. Prior
history: `8cb305f6396d…` / tree `c0687f02fffb…` (round-5b candidate), `8fec34fb1…` /
tree `2134aac124a…` (round-5 candidate), base `d192be10b`.

## Production changes in this round (inside the granted `combat_feedback_timeline.gd` path)

1. Rise-direction parity fix carried from round-5b (already in `8cb305f6`).
2. Freed-origin safety in `_step_numbers`/`_step_ticks`/`_step_bodies`: validity is
   checked on the raw reference before casting, so an enemy freed mid-body-flash no
   longer logs "Trying to cast a freed object" script errors. Bounded defect fix found
   by the new owner-deletion parity case; no visual or density change.

## Parity coverage added to `tests/p3_feedback_allocation_test.gd` (all PASS)

- Pause/resume: item frozen while the tree is paused (process_always timer proves the
  window), resumes advancing after unpause.
- Engine.time_scale: item rise follows half-speed time exactly (real-time timer with
  `ignore_time_scale` isolates the wait).
- Production path: three real EnemyBiter instances take real damage; exactly three
  visible numbers appear via the scene's timeline.
- Deterministic seeded RNG parity: with `seed(20260909)`, the first production number's
  x-offset equals the reference `randf_range` sequence computed independently — random
  behavior and call order are unchanged by the timeline.
- Originating-owner deletion: numbers survive `queue_free()` of their enemy; zero
  orphans after teardown.
- In-flight tick curve asserted before expiry (quad-out alpha at 0.08 s).
- Overlapping flash trajectory: continuous restore, restart from the current blend on a
  second flash, convergence to target.

## Uncontaminated unchanged full matrix — complete raw package (`round5c/`)

Probe: FAN-3877 `perf_probe.gd`, SHA-256
`57d817d2effc2627f5d5b115b8094ebdb6bda541e5a3640fab2a9f7f03eaa6f5`, invoked as
`FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3
tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- <SCENARIO>`
(recorded in `package-header.txt` and each `log-*`). Per run: unique `perf_<run>.json`,
`perf_<run>.csv`, `log-<run>.txt` (with exit status) and `env-<run>.txt` (foreign
process counts before and during), plus `env-after.txt`.

| Run | Result | Peak / limit | Mean | FPS avg / 1% | Mem | Foreign before/during | Exit |
|---|---|---:|---:|---:|---:|---|---:|
| P3 run 1 | **PASS** | 3,853 / 4,000 | 3,641 | 118.5 / 103.4 | 128.9 MiB | 0 / 0 | 0 |
| P3 run 2 | **PASS** | 3,863 / 4,000 | 3,647 | 118.0 / 116.4 | 128.9 MiB | 0 / 0 | 0 |
| P1 menu | **PASS** | 2,246 | 2,245 | 119.9 / 118.3 | 119.2 MiB | 0 / 0 | 0 |
| P2 48 enemies | **PASS** | 3,997 / 5,000 | — | 112.7 / 103.8 | 128.5 MiB | 0 / 0 | 0 |

Every in-JSON check true: zero per-second samples above 4,000 in both P3 runs, boss
alive each second, one accepted ultimate of 18 attempts, non-monotonic series, orphans
0→0 with clean post-cleanup, P2 population exactly 48.

## Focused suites on `1b548ee4` (exit 0 each)

`p3_feedback_allocation_test.gd`, `p3_executor_residency_test.gd`,
`boss_summon_cap_test.gd`, `boss_hazard_cap_gate.gd`, `hazard_vfx_smoke_test.gd`,
`ultimates/berserk_balance_test.gd`.

Historical raws (rounds 1–5b) are preserved unchanged. Independent qa_high on exactly
`1b548ee4c254…`, unchanged-content serial dev integration, and FAN-3877's fresh
holistic certification remain required.
