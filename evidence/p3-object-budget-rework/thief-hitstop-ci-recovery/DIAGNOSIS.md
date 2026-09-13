# FAN-3934 — Thief smoke-bomb CI dip failure: diagnosis and test repair

## Bound facts

CI run 34778768959 / job 103781792949 / suite 514 of 546: `thief_smoke_bomb`
dip 93.3 ms vs declared 100 ms under the within-one-frame rule; merge tree =
approved candidate tree `217333b1e…`. All diagnostic runs below used
`tools/godot_gate.py` exclusive admission with a retained foreign-process
check (0) per run; the instrumentation (arg-gated per-frame dump, zero
assertion changes) was committed BEFORE any diagnostic execution.

## Executed matrix (pre-declared in PLAN.md; every result retained)

| arm | source | reps | smoke_bomb dip (sampled sum) | dip frames | closing-frame wall |
|---|---|---:|---:|---:|---:|
| baseline | b0ebba8f3 + diag patch (d5aa21e9b) | 3 | 97.0 / 97.2 / 97.3 ms | 14 | 6.7–6.9 ms |
| candidate | b8d8fa899 (6fa6826e7 diag) | 3 | 96.9 / 96.4 / 97.2 ms | 14 | 6.9 ms |

Baseline and candidate are statistically indistinguishable — the P3 repair did
not change the dip behavior. **H2 (production defect) rejected.**

## Causal finding — H1 confirmed (frame-boundary observation error)

The test sums WHOLE scheduled frames in which `Engine.time_scale < 0.99`. The
production dip is a wall-clock `SceneTreeTimer` (`create_timer(seconds, …,
ignore_time_scale=true)`) that fires MID-frame and restores the scale before
the test samples that frame — so the closing partial frame is never counted.
The retained series show the omission directly: every run samples exactly 14
frames (~97 ms) with a first post-dip frame of ~6.7–6.9 ms; the true 100 ms
dip = sampled 97 ms + un-sampled closing partial (~3–7 ms). On CI's frame
pacing the 6.7 ms omission (93.3 ms observed) exceeded the single-frame
tolerance computed from the last sampled frame. **H3 (host flakiness)
rejected** — the shortfall is a deterministic property of the sampling, not
variance (spread ≤0.9 ms across six runs).

## Test-only repair (measured; semantics preserved)

`_declared_matches_sampled(sampled, closing_frame_wall, declared, frame)`:
the true duration lies in `[sampled, sampled + closing_frame_wall]` (the
closing frame's own wall time bounds the un-sampled partial, measured from the
retained events), and the declared value must sit in that interval widened by
at most one frame of scheduling slack — the SAME within-one-frame semantics,
corrected for the boundary omission. Applied to both the dip and the
hold-to-declared comparisons (identical whole-frame quantization). The
100 ms declaration, the 80–150 ms pose-hold envelope, pose freeze/resume,
live dip depth, time-scale restoration and cleanup assertions are untouched.
Deliberately wrong durations (80 ms and 130 ms declarations against a ~97 ms
sample) are REJECTED by the executed negative controls; the true 100 ms
declaration is accepted. Repaired suite: exit 0 (3 thief timelines).

## Scope statement

No production byte changed; the production dip is wall-clock-correct by
construction and measurement. This is entirely a test-observation repair.
