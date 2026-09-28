# FAN-3982 — RELEASE 0.3.1 (fixed, M3): `main` promotion and lease-bound `v0.3.1` re-point — STOPPED before any remote write (AC3 red)

Promoter: Claude Dev Fable (`1cba3f6b-908a-4ba0-9baa-a849880b5682`), macOS
development host, clean task worktree `agent/claude-dev-fable/13a5f6ba39b5`
checked out at S. Repository `FomaBy/FantasyDisk`. All timestamps UTC.

**Outcome: no ref was written.** `main`, `v0.3.1`, both archive tags, `v0.3.2`
and `dev` are exactly as the card's `tag_preimage` recorded them
(`01_readback_at_stop.txt`, 06:37:43Z). The stop condition is AC3: the
certifying `quality_gate.py --profile changed` run on exact S is red on five
items (two static checks, three Godot suites), and every red is a property of
S's own tree, not of this host.

## Approved source and preconditions (AC1, AC2 — all satisfied)

| item | value |
|---|---|
| S (approved source commit, = `origin/dev`) | `338fb7bf4d0cfcf9bd9a896fc0afcf0e5c4e816a` |
| S tree | `7a50852f9a1f2a3578fa0355743b2ab15555c791` |
| FAN-3981 PASSED candidate / tree | `338fb7bf…` / `7a50852f…` (QA `d7bc8435…`, run `01a0e60c-6f2c-75ef-a361-15c488ac4895`, verdict `01a0e641-65f9-7838-8417-af81fa8b52ea`); status `done` |
| `refs/heads/main` | `dafb99ea70af8ace6c2b866cd1fb57a52bda0a87` (tree `9dd96fa9…`) |
| `refs/tags/v0.3.1` | tag `c692d01973a7e4765807bd5fcae11c6bb74df5e6` → `165f14aa0ce5bcbd884e4dfde137283a8010e863` |
| `refs/tags/archive/v0.3.1-attempt1-448a0cc1` | `676c0f6f…` → `448a0cc1…` (unchanged) |
| `refs/tags/v0.3.2` | `90279733…` → `36340c47…` (unchanged) |
| `FomaBy/FantasyDisk-Releases` | only `v0.2.4` tag/release; source repo releases: `v0.2.3` only |
| rulesets / protection | only `dev-protection` (branch, active); no tag ruleset; `main`/`dev` no classic protection |
| FAN-2787 | no administrative hold |

No drift, no published 0.3.1, no new protection. Details: `00_preflight.txt`,
`01_readback_at_stop.txt`.

## Preflight on exact S (AC3)

Always-required checks, all green (`00_preflight.txt`):

- `tools/release_version_mapping.py --version 0.3.1` → `0.3.1 1.3.10 0.3.1 0.3.1.0`, matching `project.godot` and both export presets.
- Notes / poster / date: `CHANGELOG.md` `## [0.3.1] — 2026-09-28`, `scripts/patch_notes_data.gd` newest entry 0.3.1 / 2026-09-28, poster `assets/marketing/fantasydisk_031_announcement.png` SHA-256 `6d0267c7…` (blob `51803688…`) dated 28.09.2026 per its README and `layout.json`/`ui_plan.json`.
- FAN-3973 export exclusion: `tests/test_export_presets_exclusions.py` 5 passed; both presets exclude `evidence/*`, `skills/*`, the two berserk PNGs; `.gdignore` present.

Gate reuse: FAN-3981's records (README, `logs/gate_batch_summary.txt`, QA
verdict) contain the static guard, the trim-atlas check and 23 affected Godot
suites via `godot_gate.py`, plus independent QA — but **not** a complete
certifying `quality_gate.py --profile changed` run on tree `7a50852f…`
(FAN-3978's certifying run covered tree `9dd96fa9…`). So that run was executed
here on exact S, with `--changed-ref` = current `main` `dafb99ea…` (a superset of
the `origin/dev` base, which is S itself).

### Certifying gate result: `QUALITY FAILED: 16 static, 560 Godot` (`02_quality_gate_summary.txt`, raw `quality_gate_changed_S.log`, `quality_gate_report.json`; 05:27:33Z → 06:36:36Z)

| area | result |
|---|---|
| static checks | 14/16 passed; **`git-head-check` and `git-range-check` failed (exit 2)**: `git show --check HEAD` reports `evidence/FAN-3981/logs/pck_start_candidate.stdout.log:3` and `evidence/FAN-3981/logs/pck_start_v0.3.1.stdout.log:3: new blank line at EOF` — two log files committed in `338fb7bf…` |
| Godot suites | 557/560 passed; **`assassin_certification_capture_test`, `doctor_certification_capture_test`, `druid_certification_capture_test` failed** (`push_error`, exit 1) |
| Python unit | 795 tests OK (3 skipped) |
| six core smokes | all seven `tests/runtime_smoke_*_test.gd` PASS |

Why the three Godot suites are red: each strict certification capture manifest
(`docs/design/references/weapon_ultimates/{assassin,doctor,druid}/certification_capture_manifest.json`)
records `source.commit_sha = 289699b9…` (the source FAN-3978 re-shot on, commit
`165f14aa…`). The tests' `_source_violations` require every path in
`git diff --name-only 289699b9..HEAD` to be an evidence-only path per
`_is_evidence_only_path`. FAN-3981 changed the live capture path —
`scripts/full_frame_animation_registry.gd`, new `scripts/full_frame_canvas_texture.gd`
and `scripts/full_frame_trim_atlas.gd` (+ `.uid`), `tools/build_full_frame_trim_atlases.py`,
`tools/animation_gallery.gd`, four tests — and added `evidence/FAN-3981/**`
(not allowlisted). 20 non-allowlisted paths ⇒ "source is stale: post-capture
runtime/tooling change". This is the exact condition FAN-3978 fixed after
FAN-3977 by re-shooting the three classes; FAN-3981 changed the same path
without a recapture. Reproduced with plain `git diff` (deterministic, not an
environment flake).

Environment note: a first gate run on the fresh worktree (all 1538 LFS files
still pointers) produced 12 unrelated LFS-hydration reds and was aborted at
301/560; after `git lfs pull` (1538/1538, 9 s, worktree still clean) the run
above was started from scratch. The two `QUALITY NON-CERTIFYING` labels in the
log (diff base ≠ `origin/dev`; untracked `evidence/FAN-3982/00_preflight.txt`)
are procedural and do not create or remove any of the five reds.

## Writes

**None.** Steps 4(a)–(c) were not started. No archive tag, no merge commit, no
tag object was created or pushed. No `--force`, no `--tags`, no `dev` write, no
deletion. `01_readback_at_stop.txt` (06:37:43Z) shows every ref equal to the
card's preimage; `FomaBy/FantasyDisk-Releases` and GitHub releases unchanged.

## Recovery path (for the lifecycle PM; outside this card's write set)

1. A `dev` card on top of S that (a) re-shoots the Assassin, Doctor and Druid
   certification captures on the FAN-3981 source (the FAN-3978 procedure:
   manifests, readability reports and LFS frames re-recorded with
   `source.commit_sha` = the clean source commit) and (b) removes the trailing
   blank line from the two `evidence/FAN-3981/logs/pck_start_*.stdout.log`
   files (or otherwise satisfies `git show --check`). Its own certifying
   `quality_gate.py --profile changed` run must be green on the new tree.
2. After that card is PASSED and integrated, `origin/dev` moves to S′ ≠ S, so
   this card's pinned `approved_source_sha`/`approved_source_tree_sha` must be
   re-pinned to S′ by the PM (AC1: a moving tip is never substituted). The
   promotion procedure itself (archive `archive/v0.3.1-attempt2-165f14aa` →
   `c692d019…`, merge `dafb99ea…` + S′ onto `main`, lease-bound re-point of
   `v0.3.1` with `--force-with-lease=refs/tags/v0.3.1:c692d019…`) is unchanged
   and remains ready to run.

## Out of scope / notes

- Package build, Windows verification and publication belong to the package
  card, FAN-3964 and FAN-3965. No release was created or touched.
- The operator test mirror was not touched: nothing was pushed to `origin/dev`.
- This directory is an evidence-only record pushed on the task branch; it
  changes nothing under the game project (`evidence/` is export-excluded and
  `.gdignore`d). It is **not** a promotion candidate for review.
