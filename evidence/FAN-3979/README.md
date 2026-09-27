# FAN-3979 — RELEASE 0.3.1 (fixed): `main` promotion and lease-bound `v0.3.1` re-point

Promoter: Claude Dev Fable (`1cba3f6b-908a-4ba0-9baa-a849880b5682`), macOS
development host, clean task worktree `agent/claude-dev-fable/0dfdfe0b722c`
checked out at S. Repository `FomaBy/FantasyDisk`. All timestamps UTC.

Authority: Sergey Fomin's direct instruction of 2026-09-27 (FAN-3964 comment
`01a0e4b2-794b-7b49-b1cd-31650d322d95`): all fixes ship as 0.3.1, no new
versions. `v0.3.1` had never been published (no GitHub release in either
repository, no `v0.3.1` tag in `FomaBy/FantasyDisk-Releases`), so the
unpublished source tag is re-pointed once, with its preimage preserved.

## Approved source

| item | value |
|---|---|
| S (approved source commit, = `origin/dev`) | `165f14aa0ce5bcbd884e4dfde137283a8010e863` |
| S tree | `9dd96fa9cec99be330b638cdd04dfd1a42d4840d` |
| FAN-3978 PASSED candidate / tree | `165f14aa0ce5bcbd884e4dfde137283a8010e863` / `9dd96fa9cec99be330b638cdd04dfd1a42d4840d` |
| FAN-3978 QA | PASSED, reviewer `d7bc8435-0d2d-44f8-b77a-bd9723a3880e`, run `01a0e4f9-e6c9-78d7-bf87-ed23f4965689`, comment `01a0e524-3d49-790a-b91e-0cf33c9e6db4` |
| FAN-3978 integration | fast-forward `a8a3b913…` → `165f14aa…` on `dev` by `fde18c1d…` (run `01a0e530-e41e-7bd5-adb3-4dfd2f55fa64`) |

S's tree is byte-identical to the tree FAN-3978 independently PASSED, and
`dev` carries no commit beyond S. Under the refined AC3 the certifying
`quality_gate.py --profile changed` (16 static / 560 Godot / 802 Python,
six core smokes inside the run) and the independent QA of that tree are the
evidence for this promotion and were not rerun. Details: `00_preflight.txt`.

## Preflight still run here on exact S (all green)

- `tools/release_version_mapping.py --version 0.3.1` → `0.3.1 1.3.10 0.3.1 0.3.1.0`,
  matching `project.godot` and both export presets.
- Notes / poster / date: `CHANGELOG.md` `## [0.3.1] — 2026-09-28`,
  `scripts/patch_notes_data.gd` newest entry 0.3.1 / 2026-09-28, poster
  `assets/marketing/fantasydisk_031_announcement.png` SHA-256 `6d0267c7…`
  (blob `51803688…`) dated 28.09.2026 per its provenance README and `layout.json`.
- FAN-3973 static export-exclusion check: `tests/test_export_presets_exclusions.py`
  5 passed; both presets exclude `evidence/*`, `skills/*`,
  `before_berserk_648p.png`, `after_berserk_648p.png`; `.gdignore` files present.

## Before (fresh readback 2026-09-27T23:42:02Z, `01_readback_before_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `67b24d499082c7f15943253c5e857cd4b2e6892d` (tree `1a361d62…`, "release: FantasyDisk v0.3.2 (merge dev)") |
| `refs/heads/dev` | `165f14aa0ce5bcbd884e4dfde137283a8010e863` = S |
| `refs/tags/v0.3.1` | tag object `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → commit `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| `refs/tags/v0.3.2` | tag object `90279733311632aec88a70317e18afc67518e6d2` → commit `36340c473772781edafffb61ff1d8cc7caa42024` |
| `refs/tags/archive/*` | none |
| `FomaBy/FantasyDisk-Releases` | only `refs/tags/v0.2.4`; releases: v0.2.4 only |
| `FomaBy/FantasyDisk` releases | v0.2.3 only |
| rulesets | only `dev-protection` (branch, active); no tag ruleset; `main`/`dev` no classic protection |
| FAN-2787 | no administrative hold |

Everything equalled the card's `tag_preimage`. No stop condition.

## Writes, in order

1. `02_archive_tag_push.txt` — 23:42:13Z
   `git push origin 676c0f6f… :refs/tags/archive/v0.3.1-attempt1-448a0cc1` → new tag.
   Readback: `archive/v0.3.1-attempt1-448a0cc1` = `676c0f6f…` → `448a0cc1…`.
2. `03_main_merge_push.txt` — merge commit built with `git commit-tree`
   (tree = S tree, parents = old `main`, S; message
   `release: FantasyDisk v0.3.1 (merge dev)`; author/committer
   `Claude (FantasyDisk agent)`), verified locally, then
   `git push origin dafb99ea…:refs/heads/main` (normal push, 23:42:43Z).
   A first attempt at 23:42:32Z failed client-side before any transfer
   (zsh expanded `$M:refs` as a modifier; readback proved `main` unchanged).
3. `04_v031_tag_repoint.txt` — 23:43:00Z. Annotated tag object built with
   `git mktag` (object S, tag `v0.3.1`, message `FantasyDisk v0.3.1`, tagger
   `Claude (FantasyDisk agent)`), verified (`^{commit}` = S, `^{tree}` = S tree),
   then `git push origin c692d019…:refs/tags/v0.3.1 --force-with-lease=refs/tags/v0.3.1:676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71`
   → `+ 676c0f6fd...c692d0197 (forced update)`.

Each push was preceded by an immediate `ls-remote` of the target ref that
still equalled the recorded preimage. No other ref was written, deleted or
force-pushed. No `--force`, no `--tags`, no `dev` write.

## After (readback 2026-09-27T23:43:24Z via `git ls-remote` and GitHub API, `05_readback_after_write.txt`)

| ref | value |
|---|---|
| `refs/heads/main` | `dafb99ea70af8ace6c2b866cd1fb57a52bda0a87` — tree `9dd96fa9cec99be330b638cdd04dfd1a42d4840d` = S tree; parents `67b24d49…` (old main), `165f14aa…` (S); message `release: FantasyDisk v0.3.1 (merge dev)` |
| `refs/tags/v0.3.1` | tag object `c692d01973a7e4765807bd5fcae11c6bb74df5e6` → commit `165f14aa0ce5bcbd884e4dfde137283a8010e863` (tree `9dd96fa9…`); tag `v0.3.1`, message `FantasyDisk v0.3.1` |
| `refs/tags/archive/v0.3.1-attempt1-448a0cc1` | tag object `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → commit `448a0cc12f02eb05bc16becc69fde365021a9a17` (the old `v0.3.1`, byte-identical object) |
| `refs/tags/v0.3.2` | unchanged: `90279733…` → `36340c47…` |
| `refs/heads/dev` | unchanged: `165f14aa…` |
| `FomaBy/FantasyDisk-Releases` / GitHub releases | unchanged (no v0.3.x) |

Commits newly reachable from `main`: `a8a3b913…` (FAN-3977), `289699b9…`,
`165f14aa…` (FAN-3978); merge-base of old `main` and S is `36340c47…` = `v0.3.2^{}`.
`v0.3.2` and its commits stay as unpublished history.

## Out of scope / notes

- Package build, Windows verification and publication belong to the package
  card, FAN-3964 and FAN-3965. No release was created.
- The operator test mirror was not touched: nothing was pushed to `origin/dev`.
- Local observation only: the shared bare clone's local `refs/tags/v0.2.4`
  (`71da64d1…`) differs from the remote (`f49f9086…`); untouched, unrelated.
- This directory is the evidence-only candidate for independent review; it
  changes nothing under the game project (`evidence/` is export-excluded and
  `.gdignore`d).
