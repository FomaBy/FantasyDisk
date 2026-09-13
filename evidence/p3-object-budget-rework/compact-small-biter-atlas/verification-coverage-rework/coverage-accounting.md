# FAN-3934 — affected-check coverage/accounting (16:50 decision, corrected)

Environment for every execution below: this MacBook (Apple M4 Pro), Godot
4.7.stable.official.5b4e0cb0f (pinned, identical binary for all runs original
and current), gl_compatibility renderer, import settings recorded in
assets/sprites/enemies/full_frame/small_biter_atlas_manifest.json (lossless,
mode=0, no mipmaps — unchanged since the QA-reviewed source). Workload
exclusion: windowed render runs and headless suites ran via tools/godot_gate.py
with no foreign Godot process observed in the recorded windows.

## Reuse applicability proof (original vs current)

Product bytes (assets, imports, production scripts, workflows) are byte-identical
between QA-reviewed source `68afccda` and the current successor — verified by
`git diff 68afccda..HEAD -- assets scripts .github` being empty except the test
file. Therefore every product-dependent result obtained at 68afccda (or its
product-identical ancestors 5b3ff607/f400eabd/...) is applicable to the current
successor. Only `tests/full_frame_atlas_parity_test.gd` differs; every
test-dependent result below names its executed source.

## Per-check bindings

| check | executed source | raw record |
|---|---|---|
| full_frame_registry_integrity_test | 68afccda (QA 6th review, 22-suite matrix) | QA report 01a09a91 (product bytes identical now) |
| full_frame_registry_shard_validation_test | same | same |
| full_frame_eight_direction_contract_test | same | same |
| full_frame_row_scale_invariant_test | same | same |
| smoke_bootstrap / death_flow / hud_layout / projectile / wave_cap (tests/combat, 5 suites) | 68afccda | QA report 01a09a91 (5/5 combat suites exit 0, 2/2 runs each) |
| smoke_contact_feedback | 68afccda (QA) + current | QA report + regression-smoke_contact_feedback.log |
| runtime_smoke_combat | 68afccda (QA) + current | QA report + regression-runtime_combat.log |
| take_damage_contract_routing | 68afccda (QA) + current | QA report + regression-take_damage.log |
| p3_feedback_allocation | 68afccda (QA) + current | QA report + regression-feedback_alloc.log |
| ultimates/presentation_contract + presentation_failure_contract | 68afccda | QA report (2 presentation suites, exit 0) |
| engineer_accessibility_modes (headless) | 68afccda | QA report (within 22-suite matrix) |
| atlas parity headless | current successor | checker-headless.log (exit 0) |
| atlas parity windowed + export | current successor (instrumented, committed BEFORE execution) | checker-windowed-render-exported.log: complete argv, source/tree/base, exit 0 |
| spatial cases | current successor | exported-windowed-captures/: 120 reference results, 120 case records across 40 animation rows x 3 cases — 120/120 match |
| simultaneous consumers | current successor | simultaneous-consumers.json: frame/texture/flip/position/scale identities + matched alone-render references for BOTH consumers |
| captured negatives (displacement, mirroring) | current successor | negative-render-detectors.json: executed on an asymmetric frame, both detected; PNGs retained |
| negatives (duration, shifted region) | current successor | negative-corrupted-duration.json / negative-shifted-region.json (fixture identities + outcomes) |
| old/new control | current successor | old-vs-new-control-raw.log (unedited producer output, exit 1 disclosed) + old-vs-new-control-derived.json (transformation disclosed) |
| decisive P1/P2/two-P3 matrix | 5b3ff607 (product bytes identical) + QA re-measure at 68afccda | QA report 01a09a91: P3 3,832/3,859 of 4,000; P1 2,246 @ 125.5 MiB; P2 4,028 @ exactly 48 — NOT rerun (no product change; bounded-matrix rule) |
| static gate (clean) | a1a1eb3a (recorded) | static-gate-clean.log — applicability: only evidence/test files changed since; the gate's changed-ref selection is unaffected by untracked-evidence additions and the test file is not selected by static checks other than the passing unit contracts re-run below |
| workflow/static-guard contracts | current successor | contracts.log (OK) |
| range check | current successor | range-check-resolved.log (exit 0) |

## Count corrections (prior table inaccuracies)

- Actual inventory: **490 files, of which 246 PNGs** (per-case sprite+reference pairs, 4 simultaneous-consumer captures, 2 negative renders), 120 case records and 120 reference results across **40 animation rows x 3 cases — 120/120 match**. The prior handoff's "485 files / 144 captures / 24 rows" was inaccurate; this paragraph and the directory are authoritative.

## Limitations (retained)

GPU/VRAM telemetry unavailable; P2 1%-low load sensitivity; elevated-FPS regime
unexplained; the control's strict in-probe mirror histogram is NOT claimed as
an old-checker miss (only the executed render-level acceptance is). Static-only
PASS is not a Godot/CI PASS.
