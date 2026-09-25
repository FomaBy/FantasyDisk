## FAN-3962 exact-source preflight (2026-09-26, macOS)

**Preflight verdict: PASS for the pinned release source.** This is a developer
preflight, not independent QA, protected-ref promotion, or release publication.
The only repository changes in this candidate are under `evidence/FAN-3962/`.

| Pin | Exact value |
| --- | --- |
| Approved source and current `origin/dev` | `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| Approved source tree | `3e02df83290741b21d4de37c4fa03e356e20c591` |
| Source-preparation candidate FAN-3961 | `776f77613b03645830dfe832be5f5db89893962c`, same tree as the approved source |
| FAN-3970 corrected text candidate | `435827f60cd829995d6eabd3ccb4a1084b449090`, ancestor of approved source |
| FAN-3877 certified source | `e33bded444e301919dc93c8c9b9f0257e640a1ea`, ancestor of approved source; terminal `done`, independent QA `PASSED` |
| Current `origin/main` at preflight readback | `02f358149d08b3cbe895ca87847452836d1e3c70` |
| Remote `v0.3.1` at preflight readback | absent |

`git ls-remote origin refs/heads/dev refs/heads/main refs/tags/v0.3.1
refs/tags/v0.3.1^{}` confirmed those remote refs before and after testing.
`git merge-base --is-ancestor` returned 0 for all three required source
candidates. Source HEAD and tree stayed at the pinned values throughout the
checks. No write to `main` or `v0.3.1` was attempted.

### Executed checks

| Check | Command and observed output | Verdict |
| --- | --- | --- |
| Six core smoke suites | Each ran through `python3 tools/godot_gate.py --headless --path . --script res://tests/<name>.gd`. `runtime_smoke_test`, `runtime_smoke_ui_test`, `runtime_smoke_combat_test`, `runtime_smoke_progression_economy_test`, `runtime_smoke_weapon_mechanics_test`, and `runtime_smoke_boss_elite_test` each returned exit 0 and printed its suite pass marker. Exact commands, durations, markers, diagnostic lines and raw-log hashes are in `smoke_outputs.json`; five short raw logs are in this directory. The 5,558,559-byte base log is attached to the issue comment with SHA-256 `f16d39d53fc5bb6efa202c95db322c1eec6a1b9b55c30b4545dc106ebebc22e6`. | **PASS** for asserted smoke behavior; diagnostic below |
| Certifying quality gate | `python3 tools/quality_gate.py --profile static --report build/FAN-3962-static.json` exited 0: `QUALITY PASSED: 16 static, 0 Godot`. Report says `certifying=true`, `worktree_clean=true`, `git_sha=448a0cc12f02eb05bc16becc69fde365021a9a17`, 797 Python tests executed. Exact machine report is `static_quality_report.json`. | **PASS** |
| Version mapping | `python3 tools/release_version_mapping.py --version 0.3.1` exited 0 and printed `0.3.1  1.3.10  0.3.1  0.3.1.0` for logical, macOS build, Windows product and Windows file versions. | **PASS** |
| Release scope | `python3 tools/release_scope_guard.py --version 0.3.1` exited 0: `release scope OK: 0.3.1, 0 entries`. | **PASS** |
| Player notes | Source comparison `v0.3.0..HEAD` and direct checks of `CHANGELOG.md` and `scripts/patch_notes_data.gd`: 0.3.1 is the newest dated entry below empty `Unreleased`; 17/17 hero lines are present in both, and all 23 changelog bullet lines appear exactly in the in-game notes. Four release highlights cover named ultimate text/presentation, bosses and animation. FAN-3970's corrected Russian game text is an ancestor. | **PASS** for recorded release-note coverage |
| Poster artifact and provenance | `assets/marketing/fantasydisk_031_announcement.png` is 1350×1350 RGB, SHA-256 `d9ac6ea81de2fbdee68eb2ba849287078c32e9fd3cda04332bdcfaee1a03de9e`, matching the README. Decoded source SHA-256 `6283bd9afbc0c14b777a16ffaa9c767f4dd0db50fb14bc144f7d13312e6c1892` matches the generation manifest; decoded overlay SHA-256 `4c7b22c404177b61eaa84b00dbe765df8609673a30e94f18d8cce161f7c4a5ba` matches the README. `ui_plan.report.json` says `ready_for_image`, no errors; `fit_report.json` says `ok=true` for all five zones. Full-size visual inspection found readable text inside the frames. | **PASS** |
| Source integrity | Pre-evidence `git status --short`, `git diff --exit-code`, `git diff --cached --exit-code` were clean; `git fsck --connectivity-only --no-reflogs` exited 0 (shared cache contains dangling objects); `git lfs fsck` printed `Git LFS fsck OK`. Post-smoke HEAD/tree and remote `dev` still matched the pin. | **PASS** |
| Required issue scope | FAN-3877, FAN-3961 and FAN-3970 are terminal `done` with exact accepted candidates. A current program listing had 43 cards: 39 `done`, this card `in_progress`, FAN-3963/3964 blocked as downstream packaging/Windows gates, and FAN-3870 cancelled. FAN-3866 is owner-excluded from 0.3.1 source promotion while remaining `blocked`/`INCONCLUSIVE`. | **PASS** for source promotion applicability; downstream gates remain |
| FAN-3905 AC7 applicability | `git merge-base --is-ancestor 8115041ddadb54511a72ae730800c01b72545c42 HEAD` returned 1. The candidate's `docs/process/crash_logger.md`, `scripts/crash_logger.gd`, `tests/crash_logger_test.gd` and `changelog.d/FAN-3905.md` are absent from the release tree; `project.godot` has no `CrashLogger` autoload. FAN-3905 remains `blocked` and AC7 unmeasured. | **PASS** for exclusion only; AC7 remains **INCONCLUSIVE** on FAN-3905 |

### Material limits and next gate

The base and UI smoke logs contain `ERROR: Parameter "t" is null.` from
`ViewportTexture.get_image()` in an optional weapon-select screenshot path under
the headless dummy renderer (`tests/runtime_smoke_test.gd:7944`). The generated
QA note says `screenshot capture: blocked: viewport image unavailable`. The
suite assertions and pass markers completed, and the logs contain no script
load or fatal diagnostic. This preflight does not claim that optional screenshot.

The changelog and poster print **23 September 2026**, the accepted source's
chosen editorial date. Actual source promotion and publication are later; the
PM should preserve or change that date deliberately at the protected promotion
gate. Any byte-changing correction requires a new source candidate and review.

Before any `main`/tag write, the designated owner must freshly read the exact
`origin/dev` SHA/tree, terminal accepted content, protected refs and
administrative holds, then admit the promotion stage. Independent verification
of remote refs remains required afterward. This report does not build packages,
certify a native Windows installer, or publish release assets.
