# FAN-3982 — RELEASE 0.3.1 (fixed, M3): `main` promotion and lease-bound `v0.3.1` re-point (attempt 3, done)

Promoter: Claude Dev Fable (`1cba3f6b-908a-4ba0-9baa-a849880b5682`), macOS
development host, clean task worktree `agent/claude-dev-fable/13a5f6ba39b5`
reset to S with `git lfs pull` (1538/1538). Repository `FomaBy/FantasyDisk`.
All timestamps UTC.

Authority: Sergey Fomin's direct instruction of 2026-09-27 (FAN-3964 comment
`01a0e4b2-794b-7b49-b1cd-31650d322d95`): all fixes ship as 0.3.1, no new
versions; PM path FAN-3964 comment `01a0e5b0-ed2d-7357-88b3-9ae0436e2eb7`.
`v0.3.1` has never been published (no GitHub release in either repository, no
`v0.3.1` tag in `FomaBy/FantasyDisk-Releases`), so the unpublished source tag is
re-pointed once more, with its previous object preserved under a second archive
name. Attempt 2 of this card stopped before any write (record: `attempt2_stop/`);
this report supersedes it and uses the re-pinned source below.

## Approved source (the S used by this run)

| item | value |
|---|---|
| S (approved source commit, = `origin/dev`) | `f4d05fea91a5ce8b3fb858a5035df1fe54236369` |
| S tree | `e659e92afdd2dad1a3aec8ca7bce49cfac250ec6` |
| FAN-3984 PASSED candidate / tree | `f4d05fea…` / `e659e92a…` (author `3614291e`) |
| FAN-3984 QA | PASSED, reviewer `d7bc8435-0d2d-44f8-b77a-bd9723a3880e`, run `01a0e72d-041c-70ed-bc08-0a3a9a418c4d`, comment `01a0e780-760a-748a-9987-dcd06dca3d9c` |
| FAN-3984 integration | fast-forward `338fb7bf…` → `f4d05fea…` on `dev` by `fde18c1d…` (run `01a0e794-0617-7872-b910-1087f51e234e`) |
| FAN-3981 (contained unchanged in S) | `done`; QA PASSED `d7bc8435`, run `01a0e60c-6f2c-75ef-a361-15c488ac4895` |

S's tree is byte-identical to the tree FAN-3984 independently PASSED, and
`dev` carries no commit beyond S. FAN-3984 QA ran on that tree both the
certifying `quality_gate.py --profile changed --changed-ref origin/dev`
(`QUALITY PASSED: 16 static, 560 Godot`, Python 802) and the literal
`--changed-ref dafb99ea…` run (16/16 static incl. `git-head-check`/
`git-range-check`, 560/560 Godot incl. the three certification-capture tests
and the six core `runtime_smoke_*` suites, Python 802). Under AC3 those gates
are reused, not rerun. Details: `00_preflight.txt`.

## Preflight still run here on exact S (all green)

- `tools/release_version_mapping.py --version 0.3.1` → `0.3.1 1.3.10 0.3.1 0.3.1.0`,
  matching `project.godot` and both export presets.
- Notes / poster / date: `CHANGELOG.md` `## [0.3.1] — 2026-09-28`,
  `scripts/patch_notes_data.gd` newest entry 0.3.1 / 2026-09-28, poster
  `assets/marketing/fantasydisk_031_announcement.png` SHA-256 `6d0267c7…`
  (blob `51803688…`) dated 28.09.2026 per its README, `layout.json` and `ui_plan.json`.
- FAN-3973 static export-exclusion check: `tests/test_export_presets_exclusions.py`
  5 passed; both presets exclude `evidence/*`, `skills/*`,
  `before_berserk_648p.png`, `after_berserk_648p.png`; `.gdignore` files present.
- Whitespace sanity (the attempt-2 static reds): `git show --check HEAD` and
  `git diff --check dafb99ea...HEAD` both exit 0.

## Before (fresh readback 2026-09-28T10:51:22Z, `01_readback_before_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `dafb99ea70af8ace6c2b866cd1fb57a52bda0a87` (tree `9dd96fa9…`, "release: FantasyDisk v0.3.1 (merge dev)", FAN-3979) |
| `refs/heads/dev` | `f4d05fea91a5ce8b3fb858a5035df1fe54236369` = S |
| `refs/tags/v0.3.1` | tag object `c692d01973a7e4765807bd5fcae11c6bb74df5e6` → commit `165f14aa0ce5bcbd884e4dfde137283a8010e863` |
| `refs/tags/archive/v0.3.1-attempt1-448a0cc1` | `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| `refs/tags/v0.3.2` | `90279733311632aec88a70317e18afc67518e6d2` → `36340c473772781edafffb61ff1d8cc7caa42024` |
| `refs/tags/archive/v0.3.1-attempt2-*` | none |
| `FomaBy/FantasyDisk-Releases` | only `refs/tags/v0.2.4`; releases: v0.2.4 only |
| `FomaBy/FantasyDisk` releases | v0.2.3 only |
| rulesets | only `dev-protection` (branch, active); no tag ruleset; `main`/`dev` no classic protection |
| FAN-2787 | no administrative hold |

Everything equalled the card's `tag_preimage`. No stop condition.

## Writes, in order (each preceded by an immediate `ls-remote` of the target ref that still equalled the preimage)

1. `02_archive_tag_push.txt` — 10:51:51Z
   `git push origin c692d019… :refs/tags/archive/v0.3.1-attempt2-165f14aa` → new tag.
   Readback: `archive/v0.3.1-attempt2-165f14aa` = `c692d019…` → `165f14aa…` (the old `v0.3.1` object, byte-identical).
2. `03_main_merge_push.txt` — 10:53:01Z. Merge commit built with `git commit-tree`
   (tree = S tree `e659e92a…`, parents = old `main` `dafb99ea…`, S; message
   `release: FantasyDisk v0.3.1 (merge dev)`; author/committer
   `Claude (FantasyDisk agent)`), verified locally (`git diff S..merge` empty), then
   `git push origin 953f3615…:refs/heads/main` (normal push, `dafb99ea7..953f3615f`).
3. `04_v031_tag_repoint.txt` — 10:53:29Z. Annotated tag object built with
   `git mktag` (object S, tag `v0.3.1`, message `FantasyDisk v0.3.1`, tagger
   `Claude (FantasyDisk agent)`), verified (`^{commit}` = S, `^{tree}` = S tree),
   then `git push origin 8c2cbdf8…:refs/tags/v0.3.1 --force-with-lease=refs/tags/v0.3.1:c692d01973a7e4765807bd5fcae11c6bb74df5e6`
   → `+ c692d0197...8c2cbdf89 (forced update)`.

No other ref was written, deleted or force-pushed. No `--force`, no `--tags`,
no `dev` write. Each push succeeded on the first attempt.

## After (readback 2026-09-28T10:54Z via `git ls-remote` and GitHub API, `05_readback_after_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `953f3615f267d2a5d187eea2dd0ce05ba795377b` — tree `e659e92afdd2dad1a3aec8ca7bce49cfac250ec6` = S tree; parents `dafb99ea…` (old main), `f4d05fea…` (S); message `release: FantasyDisk v0.3.1 (merge dev)` |
| `refs/tags/v0.3.1` | tag object `8c2cbdf89f07f8d63417303fb35387a29250b446` → commit `f4d05fea91a5ce8b3fb858a5035df1fe54236369` (tree `e659e92a…`); tag `v0.3.1`, message `FantasyDisk v0.3.1` |
| `refs/tags/archive/v0.3.1-attempt2-165f14aa` | tag object `c692d01973a7e4765807bd5fcae11c6bb74df5e6` → commit `165f14aa0ce5bcbd884e4dfde137283a8010e863` (the previous `v0.3.1`, byte-identical object, tagger date 2026-09-27T23:43:00Z) |
| `refs/tags/archive/v0.3.1-attempt1-448a0cc1` | unchanged: `676c0f6f…` → `448a0cc1…` |
| `refs/tags/v0.3.2` | unchanged: `90279733…` → `36340c47…` |
| `refs/heads/dev` | unchanged: `f4d05fea…` = S |
| `FomaBy/FantasyDisk-Releases` / GitHub releases | unchanged (no v0.3.x) |

Commits newly reachable from `main` (`dafb99ea..S`): `35d3aed2…`, `338fb7bf…`
(FAN-3981), `0ef5daaf…`, `f4d05fea…` (FAN-3984); merge-base of old `main` and S
is `165f14aa…` = the previous `v0.3.1^{}` = second parent of `dafb99ea…`.
`main..S` diffstat: 262 files, +24536 / −59775.

## Out of scope / notes

- Package build, Windows verification and publication belong to the package
  card, FAN-3964 and FAN-3965. No release was created.
- The operator test mirror was not touched: nothing was pushed to `origin/dev`.
- `attempt2_stop/` preserves the four text files of the attempt-2 stop record
  (commit `9bbea63b…`, superseded by this report); its raw gate log/report are
  not carried forward.
- This directory is the evidence-only candidate for independent review; it
  changes nothing under the game project (`evidence/` is export-excluded and
  `.gdignore`d).
