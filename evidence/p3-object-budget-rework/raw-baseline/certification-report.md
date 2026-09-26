# FAN-3877 holistic certification report

## Verdict

**FAILED** for candidate `d192be10bbe52dd89971cab0acc66eb92ccab37f`, tree `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`.

The candidate does not satisfy the strict 17-class/51-ultimate acceptance contract. Three independent blockers remain:

1. Quality/accessibility declarations are complete for only 7/17 classes and 23/51 weapons. Ten classes remain incomplete: Assassin, Druid, Elementalist, Guitarist, Knight, Priest, Ranger, Robot, Soldier and Thief. The presentation-v2 migration allowlist still contains 23/51 weapon pairs even though the acceptance target is empty.
2. Four-mode live capture evidence exists for only Ranger and Thief (2/17 classes, 6/51 weapons). The other 15 packages provide four resolution variants, not declared live captures of normal, crowded, reduced-motion and photosensitivity-safe modes.
3. The P3 active-boss contour exceeded its 4,000-object budget on two independent 60-second runs: peaks of 4,411 (+10.3%) and 4,610 (+15.25%). The second run spent 6,037 sampled frames above the limit, from 0.198 s through 60.007 s.

## Exact candidate and independence

- Candidate commit: `d192be10bbe52dd89971cab0acc66eb92ccab37f`
- Candidate tree: `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`
- Comparison base: `51cc690145039f326b4f533c252faf41d6bb8f2c`
- `origin/dev` at final candidate validation: `d192be10bbe52dd89971cab0acc66eb92ccab37f`
- Reviewer: QA Codex Sol, agent `f992a646-a8ea-4935-ba94-212595803052`
- Reviewer task/run: `01a08377-5ff9-7188-9eaa-a1569137e23f`
- Reviewer is absent from the contributor/integrator exclusion set.
- No tracked or staged repository changes were made. All QA output is under `evidence/FAN-3877/**`.

## Acceptance-to-evidence map

| AC | Result | Evidence and reasoning |
|---|---|---|
| 1. Six dependencies terminal and integrated | PASS | FAN-3879, FAN-3886, FAN-3888, FAN-3889, FAN-3890 and FAN-3891 are `done` with independent `PASSED` verdicts. Each approved SHA is an ancestor of the holistic candidate and each recorded tree matches Git. See `dependency-ancestry.tsv`. |
| 2. Exact immutable candidate and tree | PASS | HEAD, all three candidate pins and `origin/dev` resolve to the requested commit; the tree matches. LFS status is clean. See `candidate-identity.txt`. |
| 3. Exactly 17/17 quality/accessibility and victim-impact coverage, fail closed | **FAIL** | Victim impact is 17/17 and telegraph coverage is 17/17, but quality is only 7/17 classes and 23/51 weapons. The gate lists ten pending classes. Presentation v2 still allows 23/51 pairs through its migration allowlist. Acceptance explicitly forbids adoption gaps, migration allowlists, defaults or fallbacks from making missing declarations pass. See `manifest-coverage.json`, `visual-direction-contract.log`, `presentation-contract.log`. |
| 4. Empty contact-sheet beats allowlist; 51 unique valid release/active/recovery keys | PASS | Direct strict run checked 17 classes and 51 weapons; beats migration allowlist is 0 and no key is substituted. Timing coverage also reports 17/17 classes and 51/51 weapons. See `contact-sheet-beats.log`, `timing-distinctness.log`. |
| 5. Hydrated four-mode evidence at four resolutions | **FAIL — missing coverage** | File integrity is good: 68/68 PNGs decode at the required dimensions, including 24 hydrated LFS objects and 44 Git PNGs. However, only 2/17 manifests declare all four live modes. Fifteen classes contain resolution variants of legacy timeline sheets, not four-mode live captures. See `capture-integrity.tsv`, `manifest-coverage.json`, `visual-inspection.md`, `git-lfs-fsck.log`. |
| 6. Passing fresh P1/P2/P3 runtime contours | **FAIL** | P1 and P2 pass all probe checks. P3 fails `objects_within_limit` twice: 4,411 and 4,610 versus 4,000. FPS, memory, population, non-monotonic-growth and orphan checks pass in both repetitions, isolating the failure to the object cap. See `perf_p1.json`, `perf_p2.json`, `perf_p3_run1.json`, `perf_p3.json` and raw CSV/log files. |
| 7. Readable hazards/player/HUD for every ultimate and deterministic focused/static/negative/HUD/certifying gates | **FAIL — missing holistic visual proof** | The focused 42-suite matrix, fail-closed negatives, hazard/HUD tests and clean certifying gate all execute without a test failure. They do not close the missing four-mode evidence for 15 classes or the missing quality declarations for ten classes, so readability during every ultimate cannot be certified. See `holistic-godot-report.json`, `holistic-godot-selection.txt`, `certifying-quality-gate-report.json`, `visual-inspection.md`. |
| 8. Independent qa_high verdict with actual report/raw evidence/limitations; read-only | PASS | This report records the exact run, reviewer, raw data, failures and limitations. QA changed no tracked/product content and performed no integration. |

## Test results

### Repository and contract gates

- Clean certifying changed-profile gate: PASS in 468.624 s.
- Python: 43 test files discovered, 771 tests executed, PASS.
- Static: 16/16 checks PASS.
- Candidate-selected Godot: 5/5 suites PASS.
- Broader targeted Godot matrix: 42/42 suites PASS. Its JSON status is `partial_pass` solely because task-owned evidence was already untracked when this non-certifying matrix ran; there are no failing selected tests.
- Direct numeric contract runs: contact-sheet beats, presentation contract, timing distinctness, visual direction, and presentation budget all exit successfully. Their ratchet summaries expose the coverage gaps above; a ratchet PASS is not a strict acceptance PASS.
- Budget negative paths reject missing/invalid visual and material caps as expected.
- Victim-impact sweep passes at 1, 8, 24, 38 and 48 victims. Pool cap is 24 and degradation activates above 38 victims.

### Runtime contours

Host: macOS 26.5.1 (25F80), Apple M4 Pro, 20-core GPU, 48 GiB RAM, Godot 4.7 stable official `5b4e0cb0f`. The game applied a 2560×1440 logical/effective window, which is stricter than 1920×1080 for this run. No competing Godot workload or thermal/performance warning was observed. Each decisive contour used 12 s warm-up plus a 60 s sample.

| Contour | Result | Avg FPS | 1% low FPS | Frame p95 / p99 / max | Peak memory | Peak objects / limit | Orphans start→end→post-cleanup |
|---|---:|---:|---:|---:|---:|---:|---:|
| P1 menu idle | PASS | 119.892 | 118.383 | 14.515 / 14.963 / 17.800 ms | 123.518 MiB | 2,716 / no cap | 0→0→0 |
| P2 exactly 48 enemies | PASS | 111.700 | 108.377 | 15.131 / 43.428 / 55.144 ms | 132.043 MiB | 4,810 / 5,000 | 0→0→0 |
| P3 boss, repetition 1 | **FAIL** | 117.924 | 109.523 | 14.850 / 16.281 / 71.634 ms | 132.310 MiB | **4,411 / 4,000** | 0→0→0 |
| P3 boss, repetition 2 | **FAIL** | 117.669 | 114.717 | 15.068 / 16.940 / 34.076 ms | 132.718 MiB | **4,610 / 4,000** | 0→0→0 |

P2 retained exactly 48 enemies in every per-second population sample. Both P3 runs retained a live boss in every per-second sample. Object series were non-monotonic and orphan cleanup was clean, so the repeated P3 failure is a steady workload cap breach rather than a demonstrated leak.

## Coverage limitations

- Static contact sheets cannot substitute for a live every-ultimate readability observation. The missing 15-class four-mode declaration is therefore reported as missing evidence rather than visually inferred as acceptable.
- Per-phase allocation counters remain review-gated by the repository design. The runtime probe measured actual objects/nodes/memory, contract caps, pool/degradation behavior and orphan cleanup; it does not invent unavailable per-phase allocation data.
- The initial P2 setup probe briefly observed 45 enemies because three enemies died before reinforcement. The QA-only probe was corrected to reinforce in the same setup frame; that setup-only attempt is retained as `perf_p2_setup-probe-failed.log` and is not attributed to the candidate.
- An initial certifying invocation inherited an exclusive-run environment flag that conflicts with a quality-tool self-test. The clean control and decisive certifying run passed; the contaminated transient report was removed and is not used as candidate evidence.

## Rework boundary

The current candidate must not be approved or promoted as holistically certified. The existing technical surface for the AC3/AC5/AC7 adoption and capture gap is FAN-3910's adoption-shard output together with the class presentation manifests; this identifies the routing surface, not fault attribution. The repeated AC6 P3 breach is candidate-wide and none of the six listed class dependency cards owns the global runtime contour, so it remains a FAN-3877 finding until PM assigns bounded rework. A changed candidate requires fresh exact pins and a new independent review. QA made no product repair or integration change.
