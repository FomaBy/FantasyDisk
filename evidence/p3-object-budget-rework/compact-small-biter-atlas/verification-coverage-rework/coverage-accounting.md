# FAN-3934 — affected-check coverage/accounting (15:34 decision item 5)

Environment for all new executions below: this MacBook (Apple M4 Pro), Godot
4.7.stable.official.5b4e0cb0f (pinned), gl_compatibility, every Godot command
via tools/godot_gate.py. Reused-result applicability: all product bytes
(atlas, hit-tick repair, timeline, workflows) are byte-identical between the
QA-reviewed source 68afccda and the current successor (test/evidence-only
diffs) — that is the unchanged-input proof; engine/renderer/import environment
identical (same pinned binary, same import settings recorded in the atlas
manifest); no performance sample is reused across a product change.

| check | status | binding |
|---|---|---|
| full_frame_registry_integrity | PASS (this branch lineage, unchanged source) | suite unchanged; product bytes identical to reviewed runs |
| full_frame_registry_shard_validation | PASS | same |
| full_frame_eight_direction_contract | PASS | same |
| full_frame_row_scale_invariant | PASS | same |
| combat smoke (5 suites) | PASS ×5 | QA sixth-review reran all five on 68afccda, 2/2 each |
| runtime_smoke_combat | PASS | regression-runtime_combat.log (this successor) |
| take_damage_contract_routing | PASS | regression-take_damage.log (this successor) |
| p3_feedback_allocation | PASS | regression-feedback_alloc.log (this successor) |
| smoke_contact_feedback | PASS | regression-smoke_contact_feedback.log (this successor) |
| atlas parity (headless + windowed) | PASS ×2 | checker-headless.log, checker-windowed-render-exported.log |
| old/new checker control | control_pass=true | old-vs-new-control.json (executed on exported captures) |
| spatial captures (24 rows × 3 cases) | 120/120 match | exported-windowed-captures/*.json |
| simultaneous consumers | contributed+deterministic | simultaneous-consumers.json |
| negatives (duration, shifted, hide/show) | all rejected/deterministic | negative-*.json |
| static gate | **QUALITY PASSED 16/16, exit 0** | static-gate-clean.log (clean worktree, resolved source/base, prior dirty attempts preserved in static-gate.log with cause analysis) |
| range check | exit 0 | range-check-resolved.log |
| workflow/static-guard contracts | OK | contracts.log |
| decisive P1/P2/two-P3 matrix | PASS (4/4) | measured at 5b3ff607 (product bytes identical); QA independently re-measured on 68afccda: P3 3,832/3,859, P1 2,246@125.5MiB, P2 4,028@48 enemies — binding, not re-run here (no product change since) |
| presentation/accessibility suites | PASS | QA sixth-review: 22 suites exit 0 on 68afccda; product bytes identical ⇒ applicable |

Known limitation retained: GPU/VRAM telemetry unavailable in this environment;
P2 1%-low load sensitivity; elevated-FPS regime unexplained (recorded residuals).
