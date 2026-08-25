# FAN-3470 Repository Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce candidate checkout cost and enforce future-only Git LFS storage for new design-reference binaries without rewriting history.

**Architecture:** `actions/checkout@v6` sparse checkout supplies the partial `blob:none` fetch while event-specific depth preserves changed-range ancestry. A small Python changed-range guard validates Git blob content and LFS pointers for design-evidence paths.

**Tech Stack:** GitHub Actions YAML, Git sparse checkout, Git LFS pointer format, Python 3.12 standard library, `unittest`.

**Spec:** `docs/superpowers/specs/2026-08-25-fan-3470-repository-storage-design.md`

## Global Constraints

- Published history, release tags, gameplay, and current workdir GC scope are immutable.
- Runtime `assets/**` must remain available without Git LFS or a hidden cache.
- Existing reference blobs are grandfathered unless changed.
- Candidate evidence remains exact-SHA and changed-range verified.

---

### Task 1: Candidate checkout contract

**Files:**
- Modify: `.github/workflows/quality.yml`
- Modify: `tests/test_quality_workflow.py`
- Modify: `tools/quality_static_guard.py`
- Modify: `tests/test_quality_static_guard.py`

**Interfaces:**
- Consumes: GitHub `push`, `pull_request`, and `merge_group` event SHAs.
- Produces: sparse `blob:none` candidate checkout; depth 2 plus an exact event-base ref for merge candidates; full push ancestry; targeted legacy fixture commits; exact-`HEAD` reads for tracked source omitted from the worktree.

- [ ] Add workflow assertions that fail while `static-quality` still uses unconditional `fetch-depth: 0` and has no sparse list.
- [ ] Run `python3 -m unittest tests.test_quality_workflow -v` and confirm the new assertions fail.
- [ ] Add the minimal sparse checkout, event-specific depth, explicit `lfs: false`, and shallow-only pinned legacy fetch.
- [ ] Preserve static resource, architecture, and credential coverage by reading sparse-absent tracked source from exact `HEAD` while keeping materialized and untracked files disk-first.
- [ ] Re-run the focused workflow test and confirm it passes.

### Task 2: Future-only LFS and size policy

**Files:**
- Create: `tools/repository_storage_policy.py`
- Create: `tests/test_repository_storage_policy.py`
- Modify: `.gitattributes`
- Modify: `tools/quality_gate.py`
- Modify: `skills/codex/fantasydisk-asset-generator/SKILL.md`
- Modify: `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`
- Modify: `skills/codex/fantasydisk-item-icon-generator/SKILL.md`
- Modify: `skills/codex/fantasydisk-ui-director/SKILL.md`
- Modify: `skills/codex/fantasydisk-ui-director/references/ui-change-workflow.md`

**Interfaces:**
- Consumes: `--root`, `--changed-ref`, Git changed paths, Git blobs, and `.gitattributes`.
- Produces: exit 0 for unchanged grandfathered content, deletions, text docs,
  runtime assets, and exact bounded LFS pointers; exit 1 for every changed
  design/build-QA binary outside the nested future route or any invalid pointer.

- [ ] Add strict-pointer unit tests plus temporary real-Git tests for small
  add/modify, copy/rename destinations, known and unknown formats, required pack
  nesting, grandfathering, deletion, and ordinary runtime asset acceptance.
- [ ] Run `python3 -m unittest tests.test_repository_storage_policy -v` and confirm failure because the policy tool does not exist.
- [ ] Implement status-aware parsing, size-first Git blob inspection, the
  conservative text allowlist, strict 256-byte LFS pointer validation, and the
  required Git LFS mappings.
- [ ] Add the guard to the static quality command list and update every active
  source/reference/mockup producer without changing runtime `assets/**` routes.
- [ ] Re-run storage-policy and quality-tool tests and confirm they pass.

### Task 3: Verification and benchmark

**Files:**
- Modify: `docs/process/code_quality_and_performance.md`
- Modify: `docs/superpowers/specs/2026-08-25-fan-3470-repository-storage-design.md`
- Modify: `docs/superpowers/plans/2026-08-25-fan-3470-repository-storage.md`
- Create: `.superpowers/sdd/2026-08-25-fan-3470-repository-storage/final-fix-report.md`
- Modify: `.planning/fan-3470/*` (task-local, removed before commit)

**Interfaces:**
- Consumes: final candidate diff and a disposable clean clone.
- Produces: before/after bytes, disk, wall time, clean-checkout/static-gate proof, exact commit/tree SHAs.

- [ ] Document candidate sparse inputs, unconditional future LFS routing, strict
  pointer/size-first behavior, synthetic merge provenance, and release
  full-history rule.
- [ ] Run focused unit tests, `tools/quality_gate.py --static-only`, YAML syntax validation available locally, and a clean sparse-clone check; distinguish candidate regressions from an exact `origin/dev` baseline failure.
- [ ] Record benchmark numbers from identical local upload-pack inputs and note the local filter limitation.
- [ ] Inspect the full diff, remove task-owned planning/benchmark directories, commit, push, and post the exact-SHA handoff.
