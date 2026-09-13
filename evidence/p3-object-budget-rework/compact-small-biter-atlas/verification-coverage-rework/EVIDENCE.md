# FAN-3934 — verification-coverage evidence (2026-09-13, corrected)

## Why the previous windowed log was invalid (diagnosis, item 1)

The prior `checker-windowed-render.log` printed "render-capture stage
UNAVAILABLE" despite the published command requesting `-- render`. Root cause:
the evidence-collection shell loop passed the probe arguments through an
unquoted zsh variable; zsh performs NO word splitting, so the gate received a
single argument "-- render" (one word) instead of the two words `--` and
`render`. The test therefore saw an empty user-arg list and honestly skipped
the stage. The prior handoff's claim of windowed spatial captures was thus
unsupported FOR THAT RECORDED RUN (an earlier live run had executed the stage,
but no record of it was published). The invalid log is preserved verbatim as
`checker-windowed-render-INVALID-argsmangled.log`; nothing was relabeled.

## Corrected executed runs (this directory; command/source/engine/exit in each)

- `checker-windowed-render.log` — re-executed with correctly split arguments,
  windowed OpenGL renderer: **exit 0**, spatial stage EXECUTED (no UNAVAILABLE
  line): all 24 animation rows x 3 cases byte-equal; simultaneous-consumer
  hide/show determinism green.
- `checker-headless.log` — headless re-record: **exit 0**, render stage
  explicitly UNAVAILABLE (honest skip). The prior version is preserved as
  `checker-headless-v1.log` (its recorded hash in the old manifest predates
  the final commit's whitespace correction — the discrepancy the PM found).
- `static-gate.log` — `quality_gate.py --static-only --changed-ref origin/dev`
  exit recorded.
- `range-check.log` — `git diff --check origin/dev...HEAD` exit recorded.
- `contracts.log` — workflow + static-guard unit contracts exit recorded.
- `regression-smoke_contact_feedback.log`, `regression-runtime_combat.log`,
  `regression-take_damage.log`, `regression-feedback_alloc.log` — the four
  affected regressions, commands and exits recorded.
- `negative-outcomes.md` — per-negative outcome table (corrupted duration,
  shifted region, missing-pixel path) with the detector failure lines.

## Missing historical artifacts (inventoried, not recreated)

- The prior handoff's "old-checker control" logs were misnamed duplicates
  (deleted, disclosed) — an actual old-checker control was never executed and
  is NOT recreated here; QA's inspection remains authoritative.
- No PNG capture files were historically produced; the checker compares
  captures in-memory by image SHA. Publishing renderer PNGs would require a
  new test change and is unnecessary for the acceptance: the executed logs
  prove the comparisons ran and passed (failures would exit 1 with named
  FAIL lines). Stated as a limitation, not substituted.

No earlier product/performance sample is relabeled a successor run; product
content is byte-identical to QA-reviewed `68afccda` (test/evidence-only diff).
