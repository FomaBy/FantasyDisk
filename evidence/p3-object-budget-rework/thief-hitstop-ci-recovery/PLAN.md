# FAN-3934 — Thief smoke-bomb CI dip failure: pre-declared diagnostic plan

CI facts (retained): run 34778768959, job 103781792949, suite 514/546
`tests/ultimates/presentation/thief_ultimate_presentation_test.gd`,
`thief_smoke_bomb` dip 93.3 ms vs declared 100 ms under the within-one-frame
rule; merge 54e8a3c4 tree equals approved candidate b8d8fa899 tree.

## Pre-declared hypotheses (before any execution)

H1 (frame-boundary observation error, favored by code reading): the test sums
WHOLE scheduled frames in which `Engine.time_scale < 0.99`. The dip begins
MID-frame (the impact fires during the scene's process) and ends MID-frame
(the wall-clock SceneTreeTimer `create_timer(seconds, ignore_time_scale=true)`
fires and restores the scale inside a frame). Consequences: (a) the first
sampled frame's wall delta is computed as delta/0.4 even though part of that
frame ran at scale 1 (overstates by up to ~1.5 frames); (b) the final partial
frame between the last sampled frame and the timer fire is never counted
(understates by up to 1 frame). On hosts with variable/large frames (CI) the
net error can exceed one observed frame, tripping `<= frame_seconds` although
the PRODUCTION dip is wall-clock-accurate by construction.
H2 (production defect): the scheduled dip genuinely ends early (timer or
countdown bug) — would reproduce as a consistent shortfall beyond frame
quantization on every host.
H3 (environment sensitivity): host-specific frame pacing makes the observation
unstable rather than wrong.

## Bounded matrix (fixed before execution)

1. Instrumentation committed FIRST: an arg-gated per-frame diagnostic dump in
   the test (`--dip-diag <outdir>`) recording frame index, raw
   `root.get_process_delta_time()`, Engine.time_scale, wall delta,
   `_hitstop_remaining`, and the scene's dip-active flag — no assertion or
   threshold changes.
2. Focused baseline: base `b0ebba8f36721842ee2bb5606733979986433a45` worktree,
   same suite, diagnostic on, 3 repetitions retained.
3. Focused candidate: `b8d8fa899…` (this branch), same conditions, 3
   repetitions retained.
4. Analysis distinguishes H1/H2/H3 from the dumped series (quantization
   residuals vs consistent shortfall vs variance). Only then an
   evidence-justified repaired check, with deliberately wrong durations/dip
   (negatives) demonstrated to still fail.

Every run via tools/godot_gate.py; timing observations under exclusive
admission with foreign-process check retained; all results kept.
