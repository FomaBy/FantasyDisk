# Code quality and performance

Updated: 2026-09-05. Historical quality audit: FAN-1040 at `1190db1d1de10ab90e21d2cdea32be908efbeada`. This document describes the required evidence; code and test output remain the source of truth.

## Candidate checks

Run `bash tools/install_hooks.sh` once in a new checkout. The static guard covers tracked runtime/resource and credential sources, script sidecars, syntax, policy, validators, Git/shell checks, and security configuration. It must not be bypassed by sparse checkout: absent files are read from `HEAD:<path>`.

Run Godot tests only through `tools/godot_gate.py`. `tools/quality_gate.py --profile changed --changed-ref origin/dev` is the CI-equivalent broad profile and `tools/quality_gate.py --profile full` is the exhaustive local/release profile. For an ordinary small change, run one directly affected suite and a second only for a distinct failure mode. The `changed` and `full` profiles are not a default local matrix. Use a broad profile for release/publish, saves/migrations, networking, payments/secrets/security, or an already-red CI that cannot be isolated.

The pinned candidate CI engine is `4.7.stable.official.5b4e0cb0f`. A `push_error()` signature is fatal even if Godot exits zero; ordinary engine `ERROR:` output is not automatically a failed suite. Empty selection, `Ran 0 tests`, timeouts, `SCRIPT ERROR`, and `FATAL` fail closed. Inspect the JSON report: a filtered, skipped, dirty-worktree, or nonstandard-`--changed-ref` run is `partial_pass`, not certifying evidence.

## Baseline facts and storage policy

The 2026-08-25 local synthetic two-parent PR experiment at `5c0047888b0adc27fe65a1a232dbaa0ca97c9939` measured full clone versus depth-2 sparse candidate checkout: checkout disk fell from 6,554,760 KiB to 3,359,448 KiB (48.7%), packed storage from 3,445,553 KiB to 2,640,164 KiB (23.4%), and wall time from about 28 s to 19.82 s (29.2%). Because the local server ignored the partial-clone filter, packed size is a conservative proxy, not network-byte evidence.

New source/reference binaries belong only in `docs/design/reference-assets-lfs/<issue-or-pack>/<file>` as valid Git LFS pointers. New or changed binary destinations elsewhere under `docs/design/**` or `build/qa/**` are rejected. Runtime `assets/**` remain normal Git content. Release/tag operations require full history and an exact detached source; shallow/sparse candidate checkouts are never release sources. `tools/test_coverage_gate.py`, `tools/release_scope_guard.py`, `tools/build_release.sh`, `tools/release_notes_visual_claims_guard.py`, `tools/check_druid_baseline_isolation.py`, and `tools/release_scope_manifest.json` remain active source/tool routing, not disposable documentation.

## Performance and safety boundaries

- Preserve line-count ratchets; new scripts remain under the configured 1,200-line limit unless a separately accepted rule changes it.
- Prefer deterministic budgets (snapshot generations, node counts, candidate visits, cache bounds) over subjective smoothness claims.
- Do not claim a Windows performance improvement without a native release build, scenario, baseline SHA, p50/p95/p99, stalls over 100 ms, and RSS/VRAM evidence. macOS headless is not a Windows frame-time test.
- Preserve the historical findings: server-only feedback relay removed exposed webhook credentials; status and target-query hot paths avoid per-tick deep copies/introspection; autosave uses recoverable `.tmp`/`.bak` swap; configurable Node2D spawners validate roots.

The final Windows release check remains separately scoped and includes the filled `docs/qa/perf-checklist.md` M1–M5 evidence.
