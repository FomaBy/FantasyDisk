# FAN-3934 round 5 — full-density feedback timeline; COMPLETE MATRIX PASS

Candidate `8fec34fb1241172c272c0d0f0f6aa271447ed28c` (base `d192be10b`; includes
`071abccfc` materials/tweens, `236d45bfd` attack-VFX/cleave reuse, `85405739a` lazy
executor residency). Author: dev_high `11dd50f9-2322-4aa0-a09e-631e1159c1df`.
**Published as candidate ready for review.**

## Round-4 report correction (per the 08:24:28Z grant)

Dynamic measurement (`round5/frames_residency.json`) replaces the static census:

- Registry shard validation does **not** retain frame resources (0 kinds cached after
  `FULL_FRAME_SPRITEFRAMES` initialization; retained delta −1). Round 4's wording that
  the registry loads frames before visual configuration was wrong for residency: that
  load is transient.
- Per-kind marginal cost is **369–449** objects (rift_cutter/winged_spark 449,
  stone_bruiser 433, spark_runner 417, others 369) — higher than the static
  184–224 estimate.
- Frames are **reference-owned, not permanently cached**: after the consumer
  AnimatedSprite2D is freed and references dropped, objects return to baseline and
  `has_cached` is false. Live enemies keep their kinds' sets resident; the round-3/4
  composition-variance mechanism stands, with these corrected magnitudes.

## Implemented (08:24:28Z grant)

`scripts/combat_feedback_timeline.gd` (+uid): one pause-aware pooled node owning all
transient combat feedback. Damage numbers, crit markers and hit ticks are pooled
Labels/Sprites driven per-frame with the exact previous curves (0.62 s cubic /
0.48 s back-ease rises, 0.42 s / 0.28 s alpha fades with 0.20 s delays, 0.16 s
quad-ease tick fade and body-flash restore). `scripts/enemy.gd` routes
`_show_combat_feedback`, `_show_critical_marker` and `_show_hit_flash` through it.
Full density preserved: every event still spawns an item, the pool grows on demand,
and the existing `combat_feedback_labels`/`combat_feedback_flashes` group-count caps
see identical membership. Pause (PAUSABLE, matching the old node-bound tweens),
overlap (independent items; body-flash restart) and cleanup (scene-owned node, no
orphans) semantics preserved.

Baseline → candidate allocation (same probes): round-3 attribution `full` mean 3,715 /
peak 4,196; decisive P3 means 3,423–3,644 / peaks 3,608–3,862. The warm pool
re-spawns with **zero** new objects (gated by the dedicated test).

## Decisive matrix — unchanged FAN-3877 probe, 12 s warm-up + 60 s, gate exclusive

| Contour | Result | Peak objects / limit | Mean | Avg FPS | 1% low | Peak mem | Orphans |
|---|---|---:|---:|---:|---:|---:|---:|
| P3 run 1 | **PASS** | 3,608 / 4,000 | 3,423 | 115.4 | 102.8 | 128.5 MiB | 0→0, cleanup 0 |
| P3 run 2 | **PASS** | 3,862 / 4,000 | 3,644 | 115.4 | 97.6 | 128.9 MiB | 0→0, cleanup 0 |
| P1 menu | **PASS** | 2,246 / — | — | 144.9 | 142.7 | 120.6 MiB | clean |
| P2 48 enemies | **PASS** | 4,001 / 5,000 | — | 112.3 | 106.5 | 128.5 MiB | clean |

Zero per-second samples above 4,000 in either P3 run; boss alive every second; one
accepted ultimate of 18 attempts in each; non-monotonic object series; populations
held (P2 exactly 48). Even the previously unlucky composition band now clears the cap
with 138–392 object margin. Environment: a near-idle foreign headless Godot process
(0.7% CPU, 0:00.30) was present during the window and is recorded in
`round5/env-*-matrix.txt`; all FPS checks pass with ≥2× margin, and object counts are
load-insensitive.

## Focused tests

`p3_feedback_allocation_test.gd` (extended: shared materials, telegraph budget,
AttackVfx sharing, cleave reuse, timeline pool identity/zero warm allocation/group
parity/body-flash restore/orphan-free cleanup) — PASS.
`p3_executor_residency_test.gd` — PASS. `boss_summon_cap_test.gd`,
`boss_hazard_cap_gate.gd`, `hazard_vfx_smoke_test.gd`, `ultimates/berserk_balance_test.gd`
— PASS unchanged.

## Changed paths vs `d192be10b`

- `scripts/hazard_vfx.gd` — shared immutable additive material; telegraph tween consolidation.
- `scripts/enemy.gd` — shared hit-tick material; feedback routed to the pooled timeline.
- `scripts/attack_vfx.gd` — shared additive material + shared static RNG.
- `scripts/two_handed_axe_weapon.gd`, `scripts/vfx/berserk_axe_cleave_vfx.gd` — bounded cleave reuse.
- `scripts/ultimates/registry/weapon_ultimate_registry.gd`,
  `scripts/ultimates/registry/weapon_ultimate_package_discovery.gd` — lazy executor
  residency with same-seam fail-closed admission.
- `scripts/combat_feedback_timeline.gd` (+uid) — new pooled feedback timeline.
- `tests/p3_feedback_allocation_test.gd` (+uid), `tests/p3_executor_residency_test.gd` (+uid).
- `evidence/p3-object-budget-rework/**` — all diagnostics and raw measurement evidence.

Independent qa_high verification of exactly this candidate and same-card serial dev
integration remain required.
