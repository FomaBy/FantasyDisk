# FAN-3934 second granted scope — measured result (still NOT a passing candidate)

Branch `agent/mac-zcode-developer-high/0b5c06167c31`, candidate commit for this round:
`236d45bfda8cb72747d6a29d1d7e7606ec42485b` (base `d192be10b`; round-1 fix `071abccfc`).
Author: dev_high agent `11dd50f9-2322-4aa0-a09e-631e1159c1df`.

## Report-value correction (as ordered by PM, 2026-09-09T04:46:02Z)

The round-1 validation raws (`validation/perf_p3_run1.json`, `perf_p3_run2.json`) record
`candidate_sha 6cd99ef7d…` — the diagnostic commit — although the runs executed the
repaired working tree (round-1 fix on disk, committed afterwards as `071abccfc`). The
measured values are from the repaired code but are NOT bound to a committed SHA; they are
preserved unchanged as raw evidence and must not be cited as certified candidate numbers.
All round-2 measurements below are freshly produced with `candidate_sha 236d45bfd…`
recorded inside each raw JSON (probe hash identical to FAN-3877's original
`perf_probe.gd`, byte-for-byte the extracted archive copy).

## Implemented this round (inside the 04:46:02Z grant)

- `scripts/attack_vfx.gd`: one shared immutable additive `CanvasItemMaterial`
  (`AttackVfx.additive_material()`), one shared static `RandomNumberGenerator` for
  cosmetic scatter (previously one fresh material per additive figure and one fresh RNG
  per dust/impact/wave call).
- `scripts/two_handed_axe_weapon.gd` + `scripts/vfx/berserk_axe_cleave_vfx.gd`: bounded
  cleave-VFX reuse — the effect finishes into a hidden idle state (`is_busy()`) and the
  weapon reconfigures the same instance instead of instantiating per swing; a busy
  instance still spawns a one-off so no swing ever loses its visual. Identical timings,
  colors and frames.
- `tests/p3_feedback_allocation_test.gd` extended: gates AttackVfx material sharing and
  cleave reuse/idle semantics. PASS (with the round-1 gates).

## Fresh decisive measurements (unchanged FAN-3877 probe, 12 s + 60 s, gate exclusive
mode, 0 competing Godot processes observed before and after, env snapshots retained)

| Contour | Result | Peak objects | Per-second mean | Avg FPS | 1% low | Peak mem |
|---|---|---:|---:|---:|---:|---:|
| P3 (run recorded) | **FAIL** | 4,557 / 4,000 | 4,147 | 118.7 | 117.0 | 132.7 MiB |
| P1 menu | PASS | 2,718 | — | 119.8 | 116.7 | 123.6 MiB |
| P2 48 enemies | PASS | 4,794 / 5,000 | — | 112.7 | 103.1 | 132.1 MiB |

P3 detail: 55 of 59 per-second samples above 4,000; orphans 0; non-monotonic; boss alive
every second; one accepted ultimate of 18 attempts. A same-SHA attribution run
(`attribution/full.json`, `candidate_sha 236d45bfd`) peaked at 4,365 — the spread
(4,365–4,557) matches the run-to-run variance FAN-3877 itself recorded (4,411–4,610).

## Honest verdict

Both granted repairs are implemented, regression-safe and visually identical, but the
P3 breach is not moved outside noise: per-second mean 4,147 vs pre-fix 4,109–4,166, peak
4,557 vs pre-fix 4,558–4,597. Per-frame trace analysis (round-2 `full.csv`): non-node
objects oscillate 3,450–4,031 around mean 3,665 with a dominant ~0.5 s burst cadence —
the transient mass is periodic feedback/VFX churn, not materials, RNGs or scene
instantiation, which the two grants removed with no measurable effect.

## Quantified remaining gap and the decision required

Even the mean (≈4,005 total incl. ~340 nodes) sits at the cap. Passing ≤4,000 robustly
needs ≈300 mean / ≈400–600 peak object reduction, which the cosmetic-only surface cannot
deliver. The levers that can, in measured order of effect (ablations on the fixed
candidate), all require explicit PM scope because each changes behavior or visuals:

1. Hit-feedback density cap (damage numbers/ticks per second or per swing) — the
   `no_feedback` ablation alone removes ~430 peak; the PM has explicitly reserved this
   decision.
2. Telegraph mid-pulse simplification (single steady pulse instead of looping sine pulse
   + urgent blink) — a visible change to hazard telegraphs; per-telegraph it removes the
   looping pulse tween permanently.
3. Structural floor (~3,500 objects with all combat disabled, vs 2,716 menu): loaded
   full-frame SpriteFrames/materials for entities not present in a standard P3 run —
   lazy per-encounter loading would cut the floor but changes resource ownership.
4. Summon feedback amortisation: per-hit chains scale with the 8-riftling pack; a per-
   enemy feedback throttle is a gameplay-adjacent reduction.

No candidate is published; the card remains in progress pending a scope decision on the
above. All raws, env snapshots and probe scripts are under `evidence/p3-object-budget-rework/`.
