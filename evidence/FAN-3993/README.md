# FAN-3993 — RELEASE 0.3.1.2: `main` promotion and new protected tag `v0.3.1.2` (done)

Promoter: Claude Dev Fable (`1cba3f6b-908a-4ba0-9baa-a849880b5682`), macOS
development host, clean task worktree `agent/claude-dev-fable/401cac9a6812`
checked out at S with `git lfs pull` (1538/1538 LFS files hydrated, working
tree clean apart from this directory). Repository `FomaBy/FantasyDisk`. All
timestamps UTC.

Authority: second link of the 0.3.1.2 technical-rebuild chain (FAN-3992 →
FAN-3993 → FAN-3994 → FAN-3990 → FAN-3965; owner kept product version 0.3.1).
PM admission on this card: comment `01a0f7be-9cba-7483-83c6-d519d3107315`
(2026-10-01T13:54Z) under `pm_launch_guard`, which pinned
`source_sha`/`source_tree_sha` below. Pattern: FAN-3988 (0.3.1.1 promotion by
the same promoter). No existing tag is re-pointed: `v0.3.1` (published) and
`v0.3.1.1` (unpublished, failed Windows verification on FAN-3990) stay as
they were.

## Approved source (the S used by this run)

| item | value |
|---|---|
| S (approved source commit, = `origin/dev`) | `9a19870a15d71bc2b63e622c7895519bd84dafb4` |
| S tree | `05fc714ce1599d85ee01fc13dc8afbfca449d157` |
| S shape | GitHub merge of PR #372, parents `2b8026387bdb9cb7db3a65ef5c3a877984540b1b` (previous `dev`, PR #371) + `a089406e97b4d510c5296df7529e9270601a7a5c` (FAN-3992 rework-1 candidate) |
| FAN-3992 PASSED candidate / tree | `a089406e…` / `05fc714c…` (author `3614291e-8924-4657-a7dc-c73c2e404d2c`) |
| FAN-3992 QA | PASSED (rework 1), reviewer `8ceb4992-a213-4090-8db0-51eb9c8fdb94`, run `01a0f724-bf95-7a87-9fc6-239168eee899`, comment `01a0f764-b1dd-77bb-a3fe-1c3c0cc02e31` |
| FAN-3992 certifying gate | `quality_gate` PASSED on `a089406e`: 16 static, 566 Godot, certifying, clean worktree; FAN-3991 session gate full ×2 and `natural_end` ×12 clean |
| FAN-3992 integration | PR #372 → `9a19870a…` on `dev` by `fde18c1d-64e2-43ef-9792-9a0af0895002` (CI static-quality PASS, visual-regression PASS); FAN-3992 `done` 2026-10-01T13:53Z, `integration_result_sha` = S |

S's tree is byte-identical to the tree FAN-3992 independently PASSED
(`a089406e^{tree}` = `05fc714c…` = `S^{tree}`), and `dev` carried no commit
beyond S at every readback of this run (before preflight, before each push,
after both pushes). Under AC3 the FAN-3992 gate and QA are reused, not rerun.
Details: `00_preflight.txt`.

## Preflight still run here on exact S (all green, `00_preflight.txt`, 14:03:23–14:03:35Z)

- `tools/release_version_mapping.py --version 0.3.1.2 --project project.godot --export-presets export_presets.cfg`
  → `0.3.1	1.3.12	0.3.1.2	0.3.1.2` (macOS short / macOS build / Windows product /
  Windows file), exit 0; `project.godot` `config/version="0.3.1.2"`; macOS preset
  `short_version="0.3.1"`, `version="1.3.12"`; Windows preset `file_version` =
  `product_version` = `"0.3.1.2"`.
- Notes / poster / date: `CHANGELOG.md` `## [0.3.1.2] — 2026-09-30` directly
  under the empty `[Unreleased]`, `[0.3.1] — 2026-09-28` unchanged below it;
  `scripts/patch_notes_data.gd` newest entry `0.3.1.2` / `2026-09-30` with the
  same three highlights, then `0.3.1` / `2026-09-28`; poster
  `assets/marketing/fantasydisk_0312_announcement.png` present, SHA-256
  `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` = blob
  `51803688…`, byte-identical to the 0.3.1 and 0.3.1.1 posters (as FAN-3992
  recorded). The entry date 2026-09-30 is the date the release inputs were
  prepared on `dev` (FAN-3992 commit `a5dbf5c3`), consistent between the
  changelog and the in-game notes; the promotion itself happened 2026-10-01.
- Release guards: `release_notes_visual_claims_guard.py --version 0.3.1.2` OK,
  `release_scope_guard.py --version 0.3.1.2` OK (0 entries),
  `assemble_changelog.py --check` OK (3 fragments).
- Export-exclusion check: `tests/test_export_presets_exclusions.py` 5 passed;
  both presets (macOS, Windows Desktop) list `docs/*`, `evidence/*`, `skills/*`,
  `tools/*`, `tests/*` in `exclude_filter`, empty `include_filter`, and no
  token touches `data/` or `presentation`, so `data/ultimates/presentation/**`
  (17 documents, no `.gdignore`) stays included; `docs/`, `evidence/`, `skills/`
  carry `.gdignore`; `build_ultimate_presentation_runtime_data.py --check`
  reports the 17 runtime documents up to date.
- Whitespace sanity: `git diff --check main S` exit 0.
- Ancestry: `0a838117` (old `main`) is *not* an ancestor of S — the v0.3.1.1
  release merge exists only on `main`; merge-base is `01ee1368…` (= `v0.3.1.1^{}`
  = second parent of old `main`), whose tree `039b17c5…` equals old `main`'s
  tree. So the correct three-way result is exactly S's tree, and the merge is a
  true non-fast-forward merge. `main..S` = 21 commits (FAN-3991 fix + evidence
  + recapture, PR #371, FAN-3992 release inputs + evidence + recaptures, rework-1
  fix, PR #372); diffstat 143 files, +13905 / −1460.

## Before (fresh readback 2026-10-01T14:04:02–14:04:11Z, `01_readback_before_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `0a8381170731b62e569d88ef34892af1b3a54ba4` (tree `039b17c52480bb27c28d723248a8b85d4418bb58`, "release: FantasyDisk v0.3.1.1 (merge dev)", FAN-3988) |
| `refs/heads/dev` | `9a19870a15d71bc2b63e622c7895519bd84dafb4` = S |
| `refs/tags/v0.3.1` | tag object `8c2cbdf89f07f8d63417303fb35387a29250b446` → commit `f4d05fea91a5ce8b3fb858a5035df1fe54236369` |
| `refs/tags/v0.3.1.1` | tag object `a9e08364c0aaa0e588744d1dbc30b68e233da694` → commit `01ee13687da712342964bcafebdb79c8a38b7d1e` |
| `refs/tags/v0.3.0` | `d7e516cd…` → `fd9fd1a4…` |
| `refs/tags/v0.3.2` | `90279733…` → `36340c47…` |
| `refs/tags/archive/v0.3.1-attempt1-448a0cc1`, `…attempt2-165f14aa` | `676c0f6f…` → `448a0cc1…`; `c692d019…` → `165f14aa…` |
| `refs/tags/v0.3.1.2` | none, in `FomaBy/FantasyDisk` and in `FomaBy/FantasyDisk-Releases` (API 404 both) |
| `FomaBy/FantasyDisk-Releases` | `main`/`v0.2.4`/`v0.3.1` all `162ac9f8…`; releases v0.3.1, v0.2.4 |
| `FomaBy/FantasyDisk` releases | v0.2.3 only |
| protection | `main` not protected (API 404 "Branch not protected", `rules/branches/main` = `[]`); only ruleset `dev-protection` (id 21860507, branch, active, include `refs/heads/dev`); no tag ruleset |
| FAN-2787 | `workspace_manual_pause=false`, no hold/freeze key, no administrative hold |

Everything equalled the card's `dispatch_contract` preimage and the PM admission
readback. No stop condition.

## Writes, in order (each preceded by an immediate `ls-remote` of the target ref)

1. `02_main_merge_push.txt` — 14:04:37Z. Merge commit built with
   `git commit-tree` (tree = S tree `05fc714c…`, parents = old `main`
   `0a838117…`, S; message `release: FantasyDisk v0.3.1.2 (merge dev)`;
   author/committer `Claude (FantasyDisk agent)`) →
   `7d5117f2ed16c67884ae3cd4dab1b73c315b3f42`, verified locally
   (`git diff --quiet S merge` exit 0, both parents ancestors). Recheck:
   `origin/main` still `0a838117…`, `origin/dev` still S. Then
   `git push origin 7d5117f2…:refs/heads/main` → `0a8381170..7d5117f2e`
   (normal push, no force).
2. `03_v0312_tag_push.txt` — 14:04:57Z. `git tag -a v0.3.1.2 -m "FantasyDisk
   v0.3.1.2" 9a19870a…` → tag object `eaf68a1d335e577087e2c570c19e84792bdbb332`
   (tagger `Claude (FantasyDisk agent)`), verified (`^{commit}` = S, `^{tree}` =
   S tree); recheck showed no `v0.3.1.2` in either repository and `dev` still =
   S; `git push origin refs/tags/v0.3.1.2:refs/tags/v0.3.1.2` → `* [new tag]`.

No other ref was written, deleted or force-pushed. No `--force`, no
`--force-with-lease`, no `--tags`, no `dev` write, nothing in
`FomaBy/FantasyDisk-Releases`. Each remote write succeeded on its first and
only attempt. Local guards in the run script would have aborted before a push
on any tree/parent mismatch or remote drift; none fired.

## After (readback 2026-10-01T14:05:19–14:05:28Z via `git ls-remote`, fetch and GitHub API, `04_readback_after_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `7d5117f2ed16c67884ae3cd4dab1b73c315b3f42` — tree `05fc714ce1599d85ee01fc13dc8afbfca449d157` = S tree; parents `0a838117…` (old `main`), `9a19870a…` (S); message `release: FantasyDisk v0.3.1.2 (merge dev)`; `git diff --quiet S origin/main` exit 0; still unprotected |
| `refs/tags/v0.3.1.2` | tag object `eaf68a1d335e577087e2c570c19e84792bdbb332` → commit `9a19870a15d71bc2b63e622c7895519bd84dafb4` = S (tree `05fc714c…`, parents `2b802638…` + `a089406e…` per API); tag `v0.3.1.2`, message `FantasyDisk v0.3.1.2`, tagger date 2026-10-01T14:04:57Z |
| `refs/tags/v0.3.1` | unchanged: `8c2cbdf8…` → `f4d05fea…` (API: tag object → `f4d05fea…`) |
| `refs/tags/v0.3.1.1` | unchanged: `a9e08364…` → `01ee1368…` (API: tag object → `01ee1368…`) |
| `refs/tags/v0.3.0`, `v0.3.2`, both `archive/*`, `v0.1.x`, `v0.2.x` | unchanged (full `ls-remote --tags` in the file) |
| `refs/heads/dev` | unchanged: `9a19870a…` = S |
| rulesets / releases | unchanged: only `dev-protection`; releases v0.2.3 (FantasyDisk), v0.3.1 + v0.2.4 (Releases) |
| `FomaBy/FantasyDisk-Releases` refs | unchanged: `162ac9f8…` for `main`, `v0.2.4`, `v0.3.1`; no `v0.3.1.2` |

## Out of scope / notes

- Package build (FAN-3994), Windows verification (FAN-3990) and publication
  (FAN-3965) belong to the next links of the chain. No GitHub release was
  created in either repository.
- Nothing was pushed to `origin/dev`, so the operator test mirror was not
  touched.
- This directory is the evidence-only candidate for independent review; it
  changes nothing under the game project (`evidence/` is export-excluded and
  `.gdignore`d). No integration step follows QA on this card.
