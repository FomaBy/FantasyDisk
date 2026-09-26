## FAN-3975 exact-source release preflight for 0.3.2 (2026-09-26, macOS)

**Preflight verdict: PASS for the pinned release source.** This is the
promoter's own preflight, not independent QA and not release publication. The
only repository changes in this candidate are under `evidence/FAN-3975/`.
Host: MacBook (Apple M4 Pro), Godot 4.7.stable.official, headless runs through
`tools/godot_gate.py`. Promoter: Claude Dev Fable
`1cba3f6b-908a-4ba0-9baa-a849880b5682` (not a FAN-3974 author).

| Pin | Exact value |
| --- | --- |
| Approved source S and current `origin/dev` | `36340c473772781edafffb61ff1d8cc7caa42024` |
| Approved source tree | `1a361d628d8a4160a6f44993f2ed954c50593341` |
| FAN-3974 candidate (= S, fast-forward integrated) | `36340c473772781edafffb61ff1d8cc7caa42024`, base `ddbfbc385144ca71d83f3ce9afbb23be9b3c3158` |
| FAN-3974 independent QA | reviewer `d7bc8435-0d2d-44f8-b77a-bd9723a3880e`, run `01a0de91-db10-7645-9397-40269decca89`, verdict `PASSED` (full gate 16/16 static, 559/559 Godot on exact S) |
| FAN-3974 integration | run `01a0dec5-a111-76f2-a89f-d8e081a97517`; `integration_result_sha` = S, `integration_result_tree_sha` = S tree; card `done` |
| `origin/main` at preflight readback | `1ec3d0dfb8b9a150fef742c088401c6a453e1a2b` (the v0.3.1 release merge; tree `3e02df83290741b21d4de37c4fa03e356e20c591`) |
| Remote `v0.3.1` | annotated `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → `448a0cc12f02eb05bc16becc69fde365021a9a17`, unchanged |
| Remote `v0.3.2` at preflight readback | absent |
| FAN-2787 administrative hold | `workspace_manual_pause=false`, no administrative/hold/freeze key (read 17:4xZ and again 18:41Z) |

`git ls-remote origin refs/heads/dev refs/heads/main refs/tags/v0.3.1
refs/tags/v0.3.1^{} refs/tags/v0.3.2 refs/tags/v0.3.2^{}` returned those values
at checkout time (17:4xZ), after the full gate (18:40:57Z) and again inside the
push gate (18:43:17Z). `git log --oneline v0.3.1..origin/dev` lists exactly the
three FAN-3973 commits and the four FAN-3974 commits (`7834a30a6`, `cb1162c8b`,
`0c96027b8`, `36340c473`). Source HEAD and tree stayed at the pinned values
through every check (`git status --short` empty before, between and after runs).

### Executed checks on exact S (clean checkout, HEAD = S)

| Check | Command and observed output | Verdict |
| --- | --- | --- |
| Six core smoke suites (FAN-3962 promotion precedent set) | Each ran alone through `python3 tools/godot_gate.py --headless --path . --script res://tests/<name>.gd`: `runtime_smoke_test` (197.9 s), `runtime_smoke_ui_test` (6.5 s), `runtime_smoke_combat_test` (5.0 s), `runtime_smoke_progression_economy_test` (6.6 s), `runtime_smoke_weapon_mechanics_test` (91.9 s), `runtime_smoke_boss_elite_test` (9.4 s). All exit 0 with their suite pass markers (`Runtime smoke test passed.`, `Runtime UI smoke suite passed.`, `Runtime combat smoke suite passed.`, `Runtime progression/economy smoke suite passed.`, `Runtime weapon mechanics smoke suite passed.`, `Runtime boss/elite smoke suite passed.`). Commands, durations, markers, diagnostics and raw-log SHA-256 are in `smoke_outputs.json`; the eight short raw logs are in `smoke_logs/`. The 5,484,753-byte base log (SHA-256 `90f24cfebecb8a1c3c5cabdaf1b07e516eff059cccc18e42c8daf173b969e0a0`) is attached to the issue comment. | **PASS** |
| Supplementary suites named as "core smoke" on FAN-3974 | `combat_target_query_cache_test`, `ultimates/presentation/weapon_ultimate_contact_sheet_beats_test`, `ultimates/presentation/weapon_ultimate_timing_distinctness_test`: exit 0, pass markers present (`smoke_outputs.json`, `smoke_logs/`). | **PASS** |
| Complete certifying quality gate | `python3 tools/quality_gate.py --profile full --report build/FAN-3975/quality_full.json` after materializing all 668 manifest-declared LFS evidence files the way `.github/workflows/quality.yml` does (no pointer left among them). Exit 0, `QUALITY PASSED: 16 static, 559 Godot`. Report: `status=passed`, `certifying=true`, `profile=full`, `worktree_clean=true`, `git_sha` = S, `changed_ref=origin/dev`, no filters/skips/shards, 16/16 static checks passed (802 Python tests executed), 559/559 Godot suites passed, import pre-pass passed, duration 2509.7 s (17:58:44Z → 18:40:42Z). Exact machine report: `quality_full_report.json` (SHA-256 `704e90569c66f091da1e413dfe3f02df9cdd01f0264248a758ded8b8a05bb23a`). | **PASS** |
| Version mapping | `python3 tools/release_version_mapping.py --version 0.3.2` exit 0: `0.3.2  1.3.20  0.3.2  0.3.2.0`. `project.godot` `config/version="0.3.2"`; `export_presets.cfg` macOS `short_version=0.3.2`, `version=1.3.20`; Windows `file_version=0.3.2.0`, `product_version=0.3.2`. | **PASS** |
| Release scope | `python3 tools/release_scope_guard.py --version 0.3.2` exit 0: `release scope OK: 0.3.2, 0 entries`. | **PASS** |
| Notes, poster and date consistency | `CHANGELOG.md`: empty `## [Unreleased]`, then `## [0.3.2] — 2026-09-26`, then `## [0.3.1] — 2026-09-23 [YANKED]`. `scripts/patch_notes_data.gd`: newest entry `version "0.3.2"`, `date "2026-09-26"`, next `0.3.0`. Poster plan `docs/design/references/release_0_3_2/ui_plan.json`: `version 0.3.2`, `release_date 26.09.2026`; `ui_plan.report.json` `ready_for_image`, 0 errors; `fit_report.json` `ok=true`. Guards: `release_notes_visual_claims_guard.py --version 0.3.2` and `--version 0.3.1` OK; `assemble_changelog.py --check` OK (3 fragments). | **PASS** |
| Poster artifact and provenance | `assets/marketing/fantasydisk_032_announcement.png` is 1350×1350 RGB, SHA-256 `7a890effc71460cda7769902c4adb7f8da217ccf4f7f2a935ed7d30e580c0867`, equal to the README and to the FAN-3974 developer and QA reports. Decoded `source_base.png.base64.txt` SHA-256 `6283bd9afbc0c14b777a16ffaa9c767f4dd0db50fb14bc144f7d13312e6c1892` (the approved 0.3.1 PixelLab frame); decoded overlay SHA-256 `e9b107fe…c902fe42` matches the README. The 0.3.1 poster is unchanged (`d9ac6ea8…1a03de9e`). | **PASS** |
| FAN-3973 export-exclusion check | `python3 -m unittest tests.test_export_presets_exclusions -v`: 5 tests OK. Both presets' `exclude_filter` still carry `evidence/*`, `skills/*`, `before_berserk_648p.png`, `after_berserk_648p.png` (plus the pre-existing non-game trees); `evidence/.gdignore` present. | **PASS** |
| Source integrity | `git status --short` empty; `git fsck --connectivity-only --no-reflogs` exit 0; `git lfs fsck` → `Git LFS fsck OK`; `git rev-parse HEAD HEAD^{tree}` = S / S tree after every run. | **PASS** |
| Disposable merge probe | Detached throwaway worktree at `1ec3d0df…`; `git merge --no-commit --no-ff 36340c47…` → `Automatic merge went well`, 0 conflicts; `git write-tree` = `1a361d62…` (exactly S's tree); `git merge --abort`; worktree removed. No probe commit was pushed. | **PASS** |

### Material limits

- The base and UI smoke logs contain one `ERROR: Parameter "t" is null.` from
  the optional weapon-select screenshot helper under the headless dummy
  renderer, the same benign diagnostic recorded and accepted on FAN-3962. No
  script-load or fatal diagnostic appears; every pass marker is present.
- The gate ran with `--profile full` (not the `changed` profile used on
  FAN-3974): with HEAD equal to `origin/dev` the changed selector has no diff,
  so `full` is the unfiltered certifying selection here. It executes the same
  559 suites and 16 static checks.
- The "six core smoke suites" set follows the FAN-3962 promotion precedent
  (six `runtime_smoke_*` suites); FAN-3974 named three other suites in its own
  "six", so those were run additionally. Both sets are green.
- This preflight builds no package, does not certify Windows and publishes no
  asset. Those remain FAN-3976, FAN-3964 and FAN-3965.
