# Versioning and branching policy

Updated: 2026-08-01. FantasyDisk uses SemVer before 1.0 plus technical-hotfix format `X.Y.Z.R` for a changed technical byte between patch releases. `main` is immutable released history; `dev` is the active integration branch. Multica FantasyDisk (`FAN-*`) is the authoritative task/status/owner source; local task files, task board, and legacy Jira/SCRUM are read-only mirrors/history.

The current released line is immutable `v0.3.0` on `main`; active Multica work targets `0.3.1` on `dev`. `0.1.8` and `0.1.9` are cancelled planned versions and must not appear in new issues, mirrors, fixVersions, or release/freeze notes. Sprint cadence is short (about two days), not weekly.

## Branch ownership and protection

| Branch | Purpose | Rule |
| --- | --- | --- |
| `main` | Stable released line | No ordinary feature development. |
| `dev` | Active `0.3.1` integration | Work through Multica task branches; integrate only approved exact content. |

GitHub `dev-protection` for `FomaBy/FantasyDisk` requires a pull request, `static-quality` and `visual-regression` from `.github/workflows/quality.yml`, resolved review threads, no force push, and no deletion. `dev-runtime-health*` scheduled/manual jobs are not required checks. Rename a required job only with the matching ruleset update. Emergency bypass is owner-admin-only and GitHub records it in its ruleset audit trail.

Before work:

```bash
git branch --show-current
git status --short --branch
git fetch origin --prune
git rev-parse origin/dev
```

Use a clean isolated task branch from fresh `origin/dev`. If on `main` or operator `dev`, do not implement there. Dirty WIP, divergent history, overlap, or conflicts are a real Multica blocker. Commit and push only owned locked paths after focused verification; never add `.godot/`, caches, secrets, tokens, or accidental generated sidecars.

## Release boundary and machine-readable gate

`0.3.0` is frozen at `v0.3.0`; all `0.3.1` work goes to `dev`. A `0.3.0.R` technical hotfix is the only exception, branches from `main`, contains no new game content, and follows the release gate.

The version registry is `tools/release_scope_manifest.json` (schema 1). Each entry has one `path` or `project_setting`, an `introduced_in` version, and a canonical `id`. Validate it with:

```bash
python3 tools/release_scope_guard.py --version 0.3.0
```

The guard rejects content introduced after the target version and invalid manifests (bad version, duplicate id, `..` path, or unknown key) with exit 2. `tools/build_release.sh` calls it after version mapping. Its contract is covered by `tests/test_release_scope_guard.py`; an author adding an asset or feature flag registers it in the same commit.

## Content-freeze entry conditions

PM declares `0.3.1` freeze only when all board work is done, the release-scope guard proves the boundary, `CHANGELOG.md` has dated `## [0.3.1]`, config/export presets carry the canonical version, a clean release gate is green, and `0.3.0` publication is complete. After freeze, only proven `0.3.1` release blockers enter `dev`.

## Integration and prohibitions

Developers publish immutable candidates; independent same-card QA verifies the exact SHA; the dedicated integrator serially promotes approved content to `dev`. Never force-push, rewrite protected history, push a probe merge, or reuse a conflict-probe commit as integration. Use GitHub mergeability or `git merge --no-commit --no-ff` followed by `git merge --abort` in a disposable worktree.

## Prohibitions

- Do not commit `.godot/`.
- Do not make ordinary feature changes directly in `main`.
- Do not move work between `main` and `dev` with destructive commands without explicit authority.
- Do not run `git reset --hard`, `git checkout -- <file>`, or an equivalent destructive operation without explicit permission.
- Do not start a new task without a safe fresh GitHub sync.
- Do not leave a completed task unpushed.

After a successful `origin/dev` push, fast-forward `/Users/sergeyfomin/Documents/AI Agent` only if it exists, is clean, and can fast-forward; never overwrite operator WIP. Release publication, final Windows verification, and financially chargeable actions remain separately authorized.
