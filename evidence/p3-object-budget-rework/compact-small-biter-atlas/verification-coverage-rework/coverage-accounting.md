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
| full_frame_registry_integrity_test | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91 section 'Everything else — green' (22 suites exit 0) | product bytes identical ⇒ applicable |
| full_frame_registry_shard_validation_test | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91, same 22-suite matrix | applicable as above |
| full_frame_eight_direction_contract_test | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91, same matrix | applicable as above |
| full_frame_row_scale_invariant_test | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91, same matrix | applicable as above |
| smoke_bootstrap / death_flow / hud_layout / projectile / wave_cap | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91: all five combat suites exit 0, 2/2 runs each | applicable as above |
| smoke_contact_feedback | QA: 68afccda72d7fc31a24cc34238a2e040bb687b14 (report 01a09a91-87da-7946-a72b-01679aa39a71, 2/2 runs); retained log: regression-smoke_contact_feedback.log, source d716cb90c569f027e26b0b1cd4ae5a0e2923ce38 | product bytes identical at the successor ⇒ applicable |
| runtime_smoke_combat | QA: 68afccda72d7fc31a24cc34238a2e040bb687b14 (report 01a09a91-87da-7946-a72b-01679aa39a71); retained log: regression-runtime_combat.log, source 686a78ba625512142fdc21a1c87ca42fc9905ea4 | applicable as above |
| take_damage_contract_routing | QA: 68afccda72d7fc31a24cc34238a2e040bb687b14 (report 01a09a91-87da-7946-a72b-01679aa39a71); retained log: regression-take_damage.log, source 686a78ba625512142fdc21a1c87ca42fc9905ea4 | applicable as above |
| p3_feedback_allocation | QA: 68afccda72d7fc31a24cc34238a2e040bb687b14 (report 01a09a91-87da-7946-a72b-01679aa39a71); retained log: regression-feedback_alloc.log, source 686a78ba625512142fdc21a1c87ca42fc9905ea4 | applicable as above |
| ultimates/presentation_contract + presentation_failure_contract | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91 (both presentation suites exit 0) | applicable as above |
| engineer_accessibility_modes (headless) | 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91 (within the 22-suite matrix) | applicable as above |
| atlas parity headless | 686a78ba (checker-headless.log, retained) — NO retained later headless file exists | limitation recorded honestly: later headless passes were console-only and are not claimed as evidence; the retained windowed run is authoritative |
| atlas parity windowed + export | 33179647c09b9b2c14548bf607764b07256604ec (instrumentation committed BEFORE execution; logged in-file with tree 9832ff6fbb7f3d4a9f7dbc27f238424166d586ff) | checker-windowed-render-exported.log: complete argv, source/tree/base, exit 0 |
| spatial cases | 33179647c09b9b2c14548bf607764b07256604ec (the committed instrumented export execution; artifacts retained verbatim) | exported-windowed-captures/: 120 reference results, 120 case records across 40 animation rows x 3 cases — 120/120 match |
| simultaneous consumers | 33179647c09b9b2c14548bf607764b07256604ec (the committed instrumented export execution; artifacts retained verbatim) | simultaneous-consumers.json: frame/texture/flip/position/scale identities + matched alone-render references for BOTH consumers |
| captured negatives (displacement, mirroring) | 33179647c09b9b2c14548bf607764b07256604ec (the committed instrumented export execution; artifacts retained verbatim) | negative-render-detectors.json: executed on an asymmetric frame, both detected; PNGs retained |
| negatives (duration, shifted region) | 33179647c09b9b2c14548bf607764b07256604ec (the committed instrumented export execution; artifacts retained verbatim) | negative-corrupted-duration.json / negative-shifted-region.json (fixture identities + outcomes) |
| old/new control | producer raw re-executed (old-vs-new-control-raw.log, unedited, exit 1, source in its header); processor runs at c5b5a487114a2c8d2c141736b1b9b280c19bb764: capture-processor-run.log (flip pair) + capture-processor-run-matched.log (matched pair) | EXECUTED old-checker miss = duration mutant ONLY; NO render-level spatial miss claimed (withdrawn — see derived JSON _transformation/_strict_limitation); QA report 01a09a91-87da-7946-a72b-01679aa39a71 is the authority on the histogram's principled blindness |
| decisive P1/P2/two-P3 matrix | author runs at 5b3ff607387c8a5d852f9863f402c15d17c2c454 (product bytes identical to successor); QA re-measure at 68afccda72d7fc31a24cc34238a2e040bb687b14 | QA report 01a09a91-87da-7946-a72b-01679aa39a71 'Everything else — green' section: P3 3,832/3,859 of 4,000; P1 2,246 @ 125.5 MiB; P2 4,028 @ exactly 48 — NOT rerun (no product change; bounded-matrix rule) |
| static gate (clean) | retained clean execution at source c5b5a487114a2c8d2c141736b1b9b280c19bb764, tree 21deb4889a3c27b361320ec6cca3ee8e59b80aa5 (static-gate-final.log: 16 static / 0 Godot, exit 0); prior history at a1a1eb3a and 33179647 preserved at original identities | complete source-to-successor delta (verified vs git, exactly five paths): compact-small-biter-atlas/MANIFEST.md; verification-coverage-rework/capture-processor-run-matched.log; verification-coverage-rework/coverage-accounting.md; verification-coverage-rework/old-vs-new-control-derived.json; verification-coverage-rework/static-gate-final.log — none is an input to the gate's static selection (evidence-tree records and the excluded manifest; REPORT.md UNCHANGED from c5b5a487), so the reused clean result remains applicable to this successor as long as those inputs stay unchanged. No newer static execution is claimed. Static-only PASS is distinct from Godot and protected CI results. |
| workflow/static-guard contracts | a1a1eb3a-era (contracts.log names its date; source not recorded in-file) | limitation honestly recorded: contracts.log lacks an in-file source binding; these contracts were re-run inside every static gate above (including the current certifying run's python-unit check), so current coverage exists via static-gate-final.log's 16/16 |
| range check | retained log: a1a1eb3a (range-check-resolved.log, exit 0) | limitation: later range checks ran at each publication commit with exit 0 (console, not retained as files); the successor's clean state is additionally evidenced by the manifest audit's full-range blob verification at each publication |

## Count corrections (prior table inaccuracies)

- Authoritative inventory at the final successor: **492 files / 248 PNGs / 244 JSONs** (120 case records + 120 reference results across 40 animation rows x 3 cases — 120/120 match; simultaneous-consumer captures incl. matched references; 2 negative renders). Earlier counts (485/144, 490/246) are historical only.

## Limitations (retained)

GPU/VRAM telemetry unavailable; P2 1%-low load sensitivity; elevated-FPS regime
unexplained. The sole retained EXECUTED old-checker miss is the duration mutant;
no render-level or mirror-based spatial miss is claimed (withdrawn; the
spatial-blindness observation is QA report 01a09a91-87da-7946-a72b-01679aa39a71's
inspection finding). Static-only PASS is not a Godot/CI PASS.


## Exact-source anchors and dirty-input accounting (17:29 decision)

- `checker-headless.log` names source 686a78ba; `range-check-resolved.log`
  names a1a1eb3a; `static-gate-clean.log` names a1a1eb3a. None is relabeled
  as a current-successor result. The successor-applicable executed results are:
  `checker-windowed-render-exported.log` and `old-vs-new-control-raw.log`,
  both naming source 33179647c09b9b2c14548bf607764b07256604ec (tree
  9832ff6fbb7f3d4a9f7dbc27f238424166d586ff) in their own headers — applicable
  to every later successor because only evidence/derived files changed since
  (byte-identical product, test-unchanged for the exported behaviors; the
  matched-reference instrumentation added later is covered by the processor
  runs at c5b5a487). The accepted clean static result remains bound to its
  recorded source c5b5a487/tree 21deb488 with its stated delta; no newer
  static rerun is claimed.
- **Dirty-input disclosure (corrected):** the prior round's export log
  recorded 486 dirty files (that round's staged capture copies, untracked);
  the RETAINED path/hash record for those 486 was not preserved and is NOT
  inferred from later directories — recorded as unavailable provenance. The
  following export log then recorded dirty_files_before=1 (one unnamed
  untracked file, identity not retained) — also disclosed as unavailable. The
  current round's certifying static run records dirty_files 0 before AND
  after, with the log itself written outside the checkout and packaged
  immutable afterwards (the exact sequence the PM prescribed).
- Reuse applicability now covers ALL relevant inputs, not only
  assets/scripts/workflows: the decisive probe
  (`evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd`,
  sha256 recorded in each round manifest) and the affected test files are
  unchanged between the QA-reviewed source and the successor except
  `tests/full_frame_atlas_parity_test.gd`, which is not an input to the
  decisive matrix or any product suite; engine binary, renderer
  (gl_compatibility), import settings (atlas manifest) and workload exclusion
  method are identical across original and current runs.
