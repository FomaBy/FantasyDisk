---
name: fantasydisk-code-quality-director
description: Audit and improve FantasyDisk code quality, runtime performance, Windows stutter, architecture, test coverage, validation tooling, and engineering process. Use for full or focused code reviews, performance investigations, bad-practice cleanup, refactors, CI/quality-gate changes, regression prevention, and independent QA of code/tool changes.
---

# FantasyDisk Code Quality Director

Use evidence, small reversible changes, and the repository-owned quality gate to
turn a broad review request into verified improvements. Do not claim a
performance win from static reasoning alone; label it a reduced hot-path cost
until measured on the affected platform.

## 1. Establish ownership and baseline

1. Read the root `AGENTS.md` and the process/architecture documents it requires.
2. Sync the current branch with fresh `origin/dev`; record both SHAs.
3. Create or claim the live Multica issue. Record owner, exact locked paths,
   exclusions, and active neighboring work before editing production files.
4. Keep balance, UI/art, animation, and release work out of scope unless the
   request includes it. If it does, also load the corresponding FantasyDisk
   director skill.
5. Run the current baseline through `tools/godot_gate.py`; never invoke Godot
   directly from automation.

All validation and landing must finish synchronously. Never rely on detached
hooks, background commands, or a future notification in a Multica run.

## 2. Review by evidence class

Separate findings in the report:

- **Confirmed defect/security issue:** reproducible behavior or a direct unsafe
  contract. Fix immediately when the change is bounded; rotate/revoke leaked
  credentials outside Git and record that owner action explicitly.
- **Confirmed hot-path waste:** repeated allocations, reflection, resource I/O,
  group scans, node/material churn, or unbounded caches in frame/tick/spawn/hit
  paths. Preserve gameplay semantics and add an operation/count regression test.
- **Measured regression:** attach platform, build type, scenario, Godot version,
  p50/p95/p99 frame time, stalls over 100 ms, RSS/VRAM, and baseline SHA.
- **Architectural debt:** god-files, dynamic string dispatch, duplicate owners,
  stale process docs. Do not combine a broad extraction with a performance fix;
  create a follow-up with a migration seam and dedicated tests.
- **Hypothesis:** state what evidence is missing. Do not present it as a root
  cause or tune gameplay/import settings speculatively.

For Windows stutter, inspect cold first-spawn resource loads, burst spawning,
texture residency/import modes, combat-feedback/VFX churn, per-frame scene-tree
queries, reflection in hit/DoT paths, animation resolver allocations, and native
Windows coverage. Compare cold and warm runs on representative Intel/AMD/NVIDIA
systems before changing renderer or compression settings.

## 3. Implement the smallest high-confidence fix

- Replace known resource `load()` calls in runtime hot paths with `preload()` or
  an explicit prewarm phase.
- Reuse `CombatTargetQuery` or another single-owner cache instead of rebuilding
  the same group array for every consumer.
- Bound long-lived caches and pools; define teardown ownership and an observable
  cap in tests.
- Cache stable reflection/metadata decisions by Script or state, but invalidate
  deliberately when the contract can change.
- Preserve smooth rendering when lowering model refresh frequency: cache the
  candidate/model set at 5–10 Hz while drawing positions every frame.
- Add a focused regression next to the changed domain. Do not grow
  `tests/runtime_smoke_test.gd` when a leaf suite can own the assertion.
- Avoid unrelated formatting or monolith splits in the same commit.

## 4. Run the repository quality gate

Use one of these profiles from the repository root:

```bash
# Static checks + domain tests selected from the diff + core smoke
python3 tools/quality_gate.py --profile changed --changed-ref origin/dev

# All discovered direct and inherited GDScript suites
python3 tools/quality_gate.py --profile full

# Must run natively on a Windows host; never substitute a macOS cross-export
python tools/quality_gate.py --profile windows
```

The gate must:

- discover inherited suites as well as direct `extends SceneTree` scripts;
- isolate HOME/XDG/AppData and `user://` for every Godot process;
- route Godot through the shared semaphore;
- fail on non-zero exit, `SCRIPT ERROR`, fatal diagnostics, or client secrets;
- refuse certifying status for staged, unstaged, or untracked worktrees;
- write `build/quality_gate_report.json` with SHA, platform, durations and
  per-check results.

Use `--list` to audit discovery and substring filters only for iteration. A
filtered run is not a substitute for the required changed/full profile.

## 5. Independent review and handoff

1. Ask a fresh reviewer/QA agent to inspect only the final diff and evidence.
   QA stays read-only and reports file/line findings; it does not repair them.
2. Re-run affected gates after every review fix and after integrating a moved
   `origin/dev`.
3. Clean `.godot/`, `__pycache__/`, generated `.uid`, scratch reports, and local
   test data before commit.
4. Commit with the live issue ID. Assert no repo-owned background autoland hook
   is active, then push/merge synchronously according to root `AGENTS.md`.
5. Verify the exact tested commit is present in remote `dev`. Post the commands,
   results, report path, remaining risks, and external owner actions to the
   Multica issue. Move to `in_review`; only independent QA may close it.

Never claim “full review complete” without documenting deferred high-risk work.
Security revocation, native Windows profiling, renderer A/B tests, and broad
architecture migrations are explicit follow-ups when this run cannot perform
them safely.
