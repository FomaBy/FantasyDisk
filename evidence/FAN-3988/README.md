# FAN-3988 — RELEASE 0.3.1.1: `main` promotion and new protected tag `v0.3.1.1` (done)

Promoter: Claude Dev Fable (`1cba3f6b-908a-4ba0-9baa-a849880b5682`), macOS
development host, clean task worktree `agent/claude-dev-fable/9830eb6a3526`
checked out at S with `git lfs pull` (1538/1538 LFS files hydrated, working
tree clean). Repository `FomaBy/FantasyDisk`. All timestamps UTC.

Authority: second link of the 0.3.1.1 technical-rebuild chain (FAN-3965,
section "Version"; owner kept product version 0.3.1, comment
`01a0edf0-b2f6-7bad-912a-64bbc6ae247e`). PM admission on this card:
comment `01a0f112-3cf2-736b-9a5d-237929014f1a` (2026-09-30T06:48Z), which pinned
`source_sha`/`source_tree_sha` below. Pattern: FAN-3979/FAN-3982, except that no
existing tag is re-pointed — `v0.3.1` is published and stays untouched.

## Approved source (the S used by this run)

| item | value |
|---|---|
| S (approved source commit, = `origin/dev`) | `01ee13687da712342964bcafebdb79c8a38b7d1e` |
| S tree | `039b17c52480bb27c28d723248a8b85d4418bb58` |
| S shape | GitHub merge of PR #370, parents `ee3435a7b78968c248bc6cae86f34421ddf89541` (previous `dev`) + `826109f32f0d2707cc60000c94cd935628875169` (FAN-3987 candidate) |
| FAN-3987 PASSED candidate / tree | `826109f3…` / `039b17c5…` (author `3614291e-8924-4657-a7dc-c73c2e404d2c`) |
| FAN-3987 QA | PASSED, reviewer `8ceb4992-a213-4090-8db0-51eb9c8fdb94`, run `01a0f050-2b92-7809-a35f-d00536bbc117`, comment `01a0f0b1-aaa6-7934-aa7d-177f6bd1c8f7` |
| FAN-3987 certifying gate | `quality_gate.py --profile changed --changed-ref origin/dev` PASSED: 16 static, 564 Godot, 820 Python on `826109f3` |
| FAN-3987 integration | PR #370 → `01ee1368…` on `dev` by `fde18c1d…` (comment `01a0f10e-f607-72c7-8041-535f21af754d`); FAN-3987 `done`, `integration_result_sha` = S |

S's tree is byte-identical to the tree FAN-3987 independently PASSED
(`826109f3^{tree}` = `039b17c5…` = `S^{tree}`), and `dev` carried no commit
beyond S at every readback of this run. Under AC3 the FAN-3987 gate and QA are
reused, not rerun. Details: `00_preflight.txt`.

## Preflight still run here on exact S (all green, `00_preflight.txt`)

- `tools/release_version_mapping.py --version 0.3.1.1 --project project.godot --export-presets export_presets.cfg`
  → `0.3.1	1.3.11	0.3.1.1	0.3.1.1` (macOS short / macOS build / Windows product /
  Windows file), exit 0; `project.godot` `config/version="0.3.1.1"`; macOS preset
  `short_version="0.3.1"`, `version="1.3.11"`; Windows preset `file_version` =
  `product_version` = `"0.3.1.1"`.
- Notes / poster / date: `CHANGELOG.md` `## [0.3.1.1] — 2026-09-30` directly
  under the empty `[Unreleased]`, `[0.3.1] — 2026-09-28` unchanged below it;
  `scripts/patch_notes_data.gd` newest entry `0.3.1.1` / `2026-09-30`, then
  `0.3.1` / `2026-09-28`; poster `assets/marketing/fantasydisk_0311_announcement.png`
  present, SHA-256 `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7`
  = blob `51803688…`, byte-identical to the 0.3.1 poster (as FAN-3987 recorded).
- Release guards: `release_notes_visual_claims_guard.py --version 0.3.1.1` OK,
  `release_scope_guard.py --version 0.3.1.1` OK (0 entries),
  `assemble_changelog.py --check` OK (3 fragments).
- Export-exclusion check: `tests/test_export_presets_exclusions.py` 5 passed;
  both presets (macOS, Windows Desktop) list `docs/*`, `evidence/*`, `skills/*`,
  `tools/*`, `tests/*` in `exclude_filter`, share one exclusion list, and no
  token touches `data/` or `presentation`, so `data/ultimates/presentation/**`
  (17 documents, no `.gdignore`) stays included; `docs/`, `evidence/`, `skills/`
  carry `.gdignore`; `build_ultimate_presentation_runtime_data.py --check`
  reports the 17 runtime documents up to date.
- Whitespace sanity: `git diff --check main...S` exit 0.
- Ancestry: `953f3615` (old `main`) is *not* an ancestor of S — the v0.3.1
  release merge exists only on `main`; merge-base is `f4d05fea…` (= `v0.3.1^{}`
  = second parent of old `main`), whose tree `e659e92a…` equals old `main`'s
  tree. So the correct three-way result is exactly S's tree, and the merge is a
  true non-fast-forward merge. `main..S` = 15 commits (FAN-3986, FAN-3985 fix
  + evidence + recapture, FAN-3987 source + evidence + recapture, PR merges
  #368/#369/#370); diffstat 199 files, +13166 / −1719.

## Before (fresh readback 2026-09-30T06:53:18Z, `01_readback_before_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `953f3615f267d2a5d187eea2dd0ce05ba795377b` (tree `e659e92afdd2dad1a3aec8ca7bce49cfac250ec6`, "release: FantasyDisk v0.3.1 (merge dev)", FAN-3982) |
| `refs/heads/dev` | `01ee13687da712342964bcafebdb79c8a38b7d1e` = S |
| `refs/tags/v0.3.1` | tag object `8c2cbdf89f07f8d63417303fb35387a29250b446` → commit `f4d05fea91a5ce8b3fb858a5035df1fe54236369` |
| `refs/tags/v0.3.0` | `d7e516cd…` → `fd9fd1a4…` |
| `refs/tags/v0.3.2` | `90279733…` → `36340c47…` |
| `refs/tags/archive/v0.3.1-attempt1-448a0cc1`, `…attempt2-165f14aa` | `676c0f6f…` → `448a0cc1…`; `c692d019…` → `165f14aa…` |
| `refs/tags/v0.3.1.1` | none, in `FomaBy/FantasyDisk` and in `FomaBy/FantasyDisk-Releases` |
| `FomaBy/FantasyDisk-Releases` | `main`/`v0.2.4`/`v0.3.1` all `162ac9f8…`; releases v0.3.1, v0.2.4 |
| `FomaBy/FantasyDisk` releases | v0.2.3 only |
| protection | `main` not protected (API 404 "Branch not protected"); only ruleset `dev-protection` (id 21860507, branch, active, include `refs/heads/dev`); no tag ruleset |
| FAN-2787 | `workspace_manual_pause=false`, no administrative hold |

Everything equalled the card's `dispatch_contract` preimage. No stop condition.

## Writes, in order (each preceded by an immediate `ls-remote` of the target ref)

1. `02_main_merge_push.txt` — merge commit built with `git commit-tree`
   (tree = S tree `039b17c5…`, parents = old `main` `953f3615…`, S; message
   `release: FantasyDisk v0.3.1.1 (merge dev)`; author/committer
   `Claude (FantasyDisk agent)`) → `0a8381170731b62e569d88ef34892af1b3a54ba4`,
   verified locally (`git diff --quiet S merge` exit 0, both parents ancestors).
   The first push attempt at 06:54:11Z never reached the remote: the zsh wrapper
   expanded `"$MERGE:refs/heads/main"` with the `:r` history modifier into a
   malformed refspec and git rejected it locally (`src refspec … does not match
   any`); `origin/main` was re-read and still equalled `953f3615…`. Retry at
   06:54:26Z with `${MERGE}:refs/heads/main` after another recheck:
   `git push origin 0a838117…:refs/heads/main` → `953f3615f..0a8381170` (normal
   push, no force).
2. `03_v0311_tag_push.txt` — 06:54:46Z. `git tag -a v0.3.1.1 -m "FantasyDisk
   v0.3.1.1" 01ee1368…` → tag object `a9e08364c0aaa0e588744d1dbc30b68e233da694`
   (tagger `Claude (FantasyDisk agent)`), verified (`^{commit}` = S, `^{tree}` =
   S tree); recheck showed no `v0.3.1.1` in either repository and `dev` still =
   S; `git push origin refs/tags/v0.3.1.1:refs/tags/v0.3.1.1` → `* [new tag]`.

No other ref was written, deleted or force-pushed. No `--force`, no
`--force-with-lease`, no `--tags`, no `dev` write, nothing in
`FomaBy/FantasyDisk-Releases`. Each remote write succeeded on its first
transmitted attempt.

## After (readback 2026-09-30T06:55:13Z via `git ls-remote`, fetch and GitHub API, `04_readback_after_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `0a8381170731b62e569d88ef34892af1b3a54ba4` — tree `039b17c52480bb27c28d723248a8b85d4418bb58` = S tree; parents `953f3615…` (old `main`), `01ee1368…` (S); message `release: FantasyDisk v0.3.1.1 (merge dev)`; `git diff --quiet S origin/main` exit 0; still unprotected |
| `refs/tags/v0.3.1.1` | tag object `a9e08364c0aaa0e588744d1dbc30b68e233da694` → commit `01ee13687da712342964bcafebdb79c8a38b7d1e` = S (tree `039b17c5…`); tag `v0.3.1.1`, message `FantasyDisk v0.3.1.1`, tagger date 2026-09-30T06:54:46Z |
| `refs/tags/v0.3.1` | unchanged: `8c2cbdf8…` → `f4d05fea…` (API: tag object → `f4d05fea…`) |
| `refs/tags/v0.3.0`, `v0.3.2`, both `archive/*`, `v0.1.x`, `v0.2.x` | unchanged (full `ls-remote --tags` in the file) |
| `refs/heads/dev` | unchanged: `01ee1368…` = S |
| rulesets / releases | unchanged: only `dev-protection`; releases v0.2.3 (FantasyDisk), v0.3.1 + v0.2.4 (Releases) |
| `FomaBy/FantasyDisk-Releases` refs | unchanged: `162ac9f8…` for `main`, `v0.2.4`, `v0.3.1`; no `v0.3.1.1` |

## Out of scope / notes

- Package build, Windows verification and publication belong to the next links
  of the FAN-3965 chain. No GitHub release was created in either repository.
- Nothing was pushed to `origin/dev`, so the operator test mirror was not
  touched.
- This directory is the evidence-only candidate for independent review; it
  changes nothing under the game project (`evidence/` is export-excluded and
  `.gdignore`d).
