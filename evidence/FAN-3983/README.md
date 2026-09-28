# FAN-3983 evidence: fixed 0.3.1 (M3) exact-tag package build and retention, attempt-2 bytes preserved (2026-09-28, macOS)

**Developer result: the new signed 0.3.1 package was built from the re-pointed
immutable `v0.3.1` tag (commit `f4d05fea…`, the FAN-3984 PASSED / FAN-3982
verified tree that carries the FAN-3981 object-count fix), notarized by Apple (app
and DMG), retained under the configured durable local release root, and all three
fixes (FAN-3973 startup, FAN-3977 combat freezes, FAN-3981 M3 object count) are
verified in the built bytes. The previous 0.3.1 package (FAN-3980, attempt 2,
source `165f14aa…`), the attempt-1 archive (FAN-3963) and the 0.3.2 package keep
every byte; the attempt-2 directory was relocated intact to
`releases/archive/v0.3.1-attempt2-165f14aa/` because the maintained retention tool
cannot hold two 0.3.1 packages side by side.** This is developer evidence, not
independent QA, not a Windows installer PASS, and not a publication. The only
repository change in this candidate is `evidence/FAN-3983/**` (`releases/` is
git-ignored; the package lives in the durable root).

Builder: Fable (`5c006dd4-45c3-4dd0-b1bb-d5e4a0d7e1f9`), macOS development host
(Apple M4 Pro, macOS 26.5.1, Godot `4.7.stable.official.5b4e0cb0f`, `makensis v3.12`).
Task worktree `agent/fable/6e007ed21a1b` at `f4d05fea…`, clean before the build
(`00_preflight.txt`). All timestamps UTC. Authority: Sergey Fomin's direct
instruction of 2026-09-27 (FAN-3964 comment `01a0e4b2-794b-7b49-b1cd-31650d322d95`):
all fixes ship as 0.3.1, no new versions.

| Pin | Exact value |
| --- | --- |
| Tag `v0.3.1` (annotated object, re-pointed by FAN-3982) | `8c2cbdf89f07f8d63417303fb35387a29250b446` |
| Tag target commit S | `f4d05fea91a5ce8b3fb858a5035df1fe54236369` |
| Tag target tree | `e659e92afdd2dad1a3aec8ca7bce49cfac250ec6` |
| FAN-3984 PASSED candidate / tree | `f4d05fea…` / `e659e92a…` (reviewer `d7bc8435`, run `01a0e72d-041c-70ed-bc08-0a3a9a418c4d`) — **equal to S**, so the certifying gate and six core smokes are not rerun (AC1) |
| FAN-3982 | `done`, independent QA PASSED (run `01a0e7b2-33d4-7bc3-a0a1-12909a47fc0f`, verdict `01a0e7b8-e94f-7ea7-8085-34a5782a3355`) |
| FAN-3981 fix (in S unchanged) | candidate `338fb7bf…`, QA PASSED `d7bc8435` run `01a0e60c-6f2c-75ef-a361-15c488ac4895` |
| Archive tags | `archive/v0.3.1-attempt2-165f14aa` = `c692d019…` → `165f14aa…` (tree `9dd96fa9…`); `archive/v0.3.1-attempt1-448a0cc1` = `676c0f6f…` → `448a0cc1…` |
| `origin/dev` / `origin/main` at readback | `f4d05fea…` (= S) / `953f3615…` |
| `v0.3.2` (unchanged) | `90279733…` → `36340c47…` |

The task worktree ran `git fetch --force origin '+refs/tags/*:refs/tags/*'` and read
back `v0.3.1` = `8c2cbdf8…`, `v0.3.1^{}` = S, `v0.3.1^{tree}` = S tree
(`00_preflight.txt`, `pins_match=true`). `git ls-remote` for `dev`, `main`,
`v0.3.1`, `v0.3.2` and both archive tags was identical before and after the build
(`pre_build_ls_remote.txt` = `post_build_ls_remote.txt`). No `main`/tag write, no
public upload, no Telegram/Discord send, no channel downgrade.

## Pre-build checks on exact S (AC1)

| Check | Result |
| --- | --- |
| Tree equality S vs FAN-3984 PASSED tree | `tree_equal_S_vs_FAN3984=true`; `origin/dev` = S. Certifying gate / six smokes reused, not rerun. **PASS** |
| Release tooling vs the FAN-3980 tree | `tools/build_release.sh`, `skills/codex/fantasydisk-release-director/**`, `release_version_mapping.py`, `scan_release_secrets.py`, `export_presets.cfg`, `CHANGELOG.md`, `patch_notes_data.gd`, poster: `git diff 165f14aa f4d05fea` empty — the FAN-3980 flow applies unchanged |
| Version mapping | `tools/release_version_mapping.py --version 0.3.1` → `0.3.1 1.3.10 0.3.1 0.3.1.0`, exit 0. **PASS** |
| Release inputs | `CHANGELOG.md` `## [0.3.1] — 2026-09-28` (line 7); `scripts/patch_notes_data.gd` newest entry `0.3.1` / `2026-09-28`; poster `assets/marketing/fantasydisk_031_announcement.png` SHA-256 `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` (blob `51803688…`); client `MACOS_UPDATE_CHANNEL := "signed"`; `release_scope_guard` `OK: 0.3.1, 0 entries`; `release_notes_visual_claims_guard` OK; `tests/test_export_presets_exclusions.py` OK. **PASS** |
| Signed-channel authorization | One Developer ID Application identity installed, the owner-selected certificate fingerprint matches it; `xcrun notarytool history --keychain-profile FantasyDiskRelease` exit 0 before the build (`prebuild_notary_history_exit.txt`) and again inside `build_release.sh`. Identity fingerprint, subject, team id and Apple account values are never written (grep of the raw log and of this directory: 0 hits for each token). **PASS** |

## Preservation of the old packages (preservation rules)

`local_release.py materialize_package()` writes only `releases/v<version>` and,
when that directory already exists, calls `_compare_package()`, which raises
`existing local release differs` for any byte-different package; there is no
alternate destination option (tooling identical to the FAN-3980 tree, where the
same relocation was used). The permitted relocation was used, with no tooling
change and no rename of any file:

1. Recursive SHA-256 manifests **before** anything else: `releases/v0.3.1`
   (FAN-3980 attempt 2: 115,269 files, 7.8 GB; manifest SHA-256 `5880ffad…`),
   `releases/archive/v0.3.1-attempt1-448a0cc1` (114,341 files, `7632cea6…` = the
   FAN-3980 record) and `releases/v0.3.2` (114,453 files, `f6fbd8ef…` = the FAN-3980
   record) — `preservation/*_before.sha256.gz`.
2. `mv releases/v0.3.1 releases/archive/v0.3.1-attempt2-165f14aa` (same APFS
   volume, directory rename, 2026-09-28T11:34:19Z; `preservation/preserve_relocation.txt`).
3. Manifest **after** the relocation: identical bytes (`cmp` exit 0, `5880ffad…`);
   directory list identical. Repeated after the build, verify, cold-start and perf
   runs: still identical (`preservation/manifest_equality.txt`).
4. `attempt1` and `v0.3.2` manifests after the build: identical (`7632cea6…`,
   `f6fbd8ef…`). `LOCAL_RELEASE.json` hashes of `v0.3.0`, attempt 1, attempt 2 and
   `v0.3.2` are recorded in `package_manifest.json` (`preservation`).

The FAN-3980 package's own hashes (DMG `d6fc182c…`, Setup `6d11ae1f…`,
`LOCAL_RELEASE.json` `a264215d…`) are now at the archive path only; no old file was
relabeled or copied into the new package. FAN-3963 (`375c5290…`), FAN-3976 (0.3.2,
`8b7b3e7d…`) and FAN-3980 (`6d11ae1f…`) stay terminal history.

## Build (AC2)

`FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease
MACOS_SIGN_IDENTITY=<resolved locally> tools/build_release.sh 0.3.1`, launched by
`run_build.sh` (resolves the identity from the selected certificate at run time and
overrides `core.hooksPath` only in the build process environment — the
FAN-3963/3976/3980 workaround for the Multica `cow_checkout` post-checkout hook that
rejects the `/tmp` build worktree; the shared repository config and the script are
unchanged and the build compares the running script byte-for-byte with the tag's
copy). Started 2026-09-28T11:35:39Z, finished 11:46:48Z, exit 0, first attempt. The
build worktree is a detached `/tmp/fantasydisk-build-*/src` checkout of the exact
tag (isolated task-owned staging), removed by the script on exit (`git worktree list`
shows no build worktree afterwards; the empty `mktemp` parent directories of this and
earlier builds remain in `/tmp` as before).

Milestones in `build_release.log` (milestone lines of the sanitized log; the full
sanitized log, 54,286 lines, SHA-256 `da8b49a2…`, is attached to the handoff comment
as `.gz`; raw log SHA-256 `68a734e0…` in `package_manifest.json`): 15 build inputs
present and running script equal to the tag's; canonical notes assembled; version
mapping; `release scope OK: 0.3.1, 0 entries`; no unbacked visual claims; client
channel label `signed`; headless import; macOS export; Developer ID signing with
hardened runtime and timestamp; `codesign --verify --deep --strict` valid; **Apple
notarization accepted FantasyDisk.app**; staple and validate worked; `spctl`
accepted, `source=Notarized Developer ID`; DMG created, `hdiutil verify` VALID,
layout OK; DMG signed; **Apple notarization accepted FantasyDisk DMG**;
staple/validate/`spctl` accepted; Windows export (`embed_pck`); NSIS installer;
`NSIS CRC OK (firstheader @ 38912, crc @ 438427859)`; read-only DMG mount:
signature, staple and `spctl` accepted, `Applications` link present; `Release
secret scan passed (3 artifact root(s))`; `SHA256SUMS.txt`; `update-manifest.json`;
`local_release.py materialize` → `"status": "verified"`.

Apple submission history (status only, `notary_history_top2.txt`):
`FantasyDisk-0.3.1-macos-notary.zip` Accepted 11:38:23Z;
`FantasyDisk-0.3.1-macos.dmg` Accepted 11:40:58Z.

## Retained package (`/Users/sergeyfomin/FantasyDisk/releases/v0.3.1/`, AC4)

| File | Size (bytes) | SHA-256 (new) | FAN-3980 value | FAN-3963 value | Differs |
| --- | --- | --- | --- | --- | --- |
| `FantasyDisk-0.3.1-macos.dmg` | 462,967,900 | `f391b86f3bd26494723264ad017f8991aa8fd3cb920d60d08b0506b6ac6760ca` | `d6fc182c…` (463,011,379 B) | `6465fb7c…` (559,696,549 B) | yes / yes |
| `FantasyDisk-0.3.1-windows-setup.exe` | 438,427,863 | `db99a9298a6acbdc545f8545e66b8455c8798351cfc4ba96147af490180c67de` | `6d11ae1f…` (438,509,199 B) | `375c5290…` (535,974,634 B) | yes / yes |
| `SHA256SUMS.txt` | 196 | `ac2e0424ecf26e4de7ba40aef96481a2175387ad0096abb996d702fb7620cbe9` | `7775c739…` | `a1cc64e8…` | yes / yes |
| `update-manifest.json` | 793 | `6fb982a86c1fdbcbbdb6065b5900404e64cdcf2063ec596658ff818a6ca009bf` | `315821ff…` | `a81d1149…` | yes / yes |
| `LOCAL_RELEASE.json` | 1,948 | `1807c88de192297b14fab14d94dbebb183bf05d8d6b28ce91a591bdc418b267d`; tag `v0.3.1`, `tag_commit` `f4d05fea…`, `macos_channel` `signed`, `source_tree_sha256` `d29c9972…` | `a264215d…` | `a39d705d…` | yes / yes |
| `CHANGELOG-0.3.1.md` | 5,901 | `9f3b1c6d0fcfe92c908ec12f74cf74308d8f3f52555fc0b743e7074918c89975` | `9f3b1c6d…` | `399dceb4…` | **no** / yes |
| `fantasydisk_031_announcement.png` | 95,930 | `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` | `6d0267c7…` | `d9ac6ea8…` | **no** / yes |

**Every built artifact differs from both old packages**
(`all_built_artifacts_differ_from_fan3980=true`, `all_new_hashes_differ_from_fan3963=true`).
The two copied release inputs — `CHANGELOG-0.3.1.md` and the poster — are
byte-identical to the FAN-3980 package by construction: the tag tree `f4d05fea…`
carries the same `## [0.3.1]` changelog section and the same poster blob `51803688…`
as the FAN-3980 tag tree `165f14aa…` (the FAN-3981 fix changed no release input), and
"poster equals the tag blob" is itself an acceptance check. Recorded explicitly as
`files_equal_to_fan3980_package` in `package_manifest.json` for the reviewer. The
package as a whole is told apart from FAN-3980 by DMG, Setup, `SHA256SUMS.txt`,
`update-manifest.json`, `LOCAL_RELEASE.json` (`tag_commit`) and the source snapshot.

`package_manifest.json` is the immutable package manifest: fresh SHA-256 of every
retained file, and cross-checks that `SHA256SUMS.txt`, `update-manifest.json` (names,
sizes, URLs under `FomaBy/FantasyDisk-Releases/releases/download/v0.3.1/`) and the
`LOCAL_RELEASE.json` inventory all equal the fresh hashes (`sha256sums_match_fresh`,
`update_manifest_all_ok`, `local_release_inventory_match_fresh` = true).
`CHANGELOG-0.3.1.md` equals the `## [0.3.1]` section of the tag's `CHANGELOG.md`; the
poster equals the tag blob. `project/` is the exact `git archive v0.3.1` (`diff -rq
--exclude=.godot` against a fresh extraction: 0 differences; 57,798 files = `git
ls-tree -r v0.3.1`, `snapshot_files_vs_tag.txt`), plus `godot-project/` (separate
editable copy). No raw Windows exe or zip is retained.

Readback after the build: `local_release.py verify --version 0.3.1 --macos-channel
signed --launch-smoke` exit 0, `"status": "verified"`, `tag_commit` `f4d05fea…`
(`local_release_verify.json`); `releases/current-project → v0.3.1/godot-project`
(the new package; it pointed at the FAN-3980 package before the relocation);
`/Applications/FantasyDisk.app` is **0.3.1 / 1.3.10** installed from the new
retained DMG (same version string as the FAN-3980 app it replaced — a same-version
reinstall with new bytes), `codesign --verify --deep --strict` valid, `stapler
validate` worked, `spctl --assess --type execute` accepted (`source=Notarized
Developer ID`), and its file tree is identical (per-file SHA-256, 9 files) to the app
inside the retained DMG (`dmg_app_files.sha256` = `installed_app_files.sha256`). The
retained DMG itself: `codesign` satisfies its Designated Requirement, `stapler
validate` worked, `spctl --type open` accepted, `hdiutil verify` VALID.

**Saves untouched by the reinstall:** the five `*.cfg` files of
`~/Library/Application Support/Godot/app_userdata/FantasyDisk` (including
`fantasydisk_meta.cfg` and `settings.cfg`) have the same SHA-256 before the install,
after the install + `verify --launch-smoke`, and after all cold-start/perf runs
(`saves_before.sha256` = `saves_after_install.sha256` = `saves_after_all.sha256`); the
whole user-data tree excluding `logs/`, `shader_cache/` and `vulkan/` (5,624 files)
shows 0 differences. Cold start and perf runs used isolated `HOME` directories.

## The fixes in the built bytes (AC3)

PCK file tables read from the shipped bytes with `list_pck.py` (FAN-3973 rule set;
the Windows exe extracted read-only from the retained installer with `7z e`):

| Built payload | Files | Payload | Forbidden paths (`evidence/`, `skills/`, `docs/`, `tools/`, `tests/`, stray root `.import`) |
| --- | --- | --- | --- |
| new 0.3.1 macOS `FantasyDisk.pck` (installed app = DMG app; SHA-256 `85dce876…`) | 27,017 | 420,157,443 B (400.7 MiB) | **0** |
| new 0.3.1 Windows `FantasyDisk.exe` embedded PCK | 27,017 | 420,157,443 B (400.7 MiB) | **0** |
| FAN-3980 0.3.1 Windows exe PCK (for comparison) | 27,013 | 420,853,259 B | 0 |
| FAN-3963 0.3.1 Windows exe PCK (for comparison) | 47,137 | 735,045,521 B | 1,237 |

The macOS and Windows file tables are byte-identical (`macos_pck_summary.md`,
`windows_pck_summary.md`, `pck_0.3.1new_*.json`). Top-level content: `.godot`
13,062 files, `assets` 13,020, `scripts` 580 (+4: the FAN-3981 `full_frame_trim_atlas`
/ `full_frame_canvas_texture` scripts and sidecars), `data` 156, `scenes` 196, root
`icon.svg`, `icon.svg.import`, `project.binary` — the FAN-3981 export footprint
(27,017 files, 400.7 MiB: 42 rebuilt `*_spriteframes` binaries, smaller). Sizes:
Windows exe inside Setup 532,885,616 B vs 533,581,104 B (FAN-3980) vs 850,651,688 B
(FAN-3963); Setup 438,427,863 B vs 438,509,199 B vs 535,974,634 B; DMG 462,967,900 B
vs 463,011,379 B vs 559,696,549 B.

**macOS cold start of the built app** (`measure_cold_start_app.sh`: FAN-3973 method
on the app binaries — `--print-fps --verbose --quit-after 600`, first `Project FPS`
line minus 1 s; five back-to-back launches per build; isolated `HOME` per build;
summary via `evidence/FAN-3973/analyze_cold_start.py`; logs in `cold_start/`):

| Build | Runs | Median first frame (s) | Min | Max | Actor SpriteFrames before first frame |
| --- | --- | --- | --- | --- | --- |
| 0.3.0 app (from retained `v0.3.0` DMG) | 5 | 5.55 | 5.50 | 7.99 (first launch, cold file cache) | 1 |
| **new 0.3.1 app (installed from the retained DMG)** | 5 | **5.65** | 5.59 | 7.20 (first launch) | 1 |

Within 0.10 s of the 0.3.0 reference under the same method (FAN-3980 measured its
package at 5.70 vs 0.3.0 5.47), one scene-dependency pack before the first frame in
both — the FAN-3973 state, not the FAN-3963 regression (17.4 s on Windows per
FAN-3964). Windows timing stays with FAN-3964.

**Scripted combat check with the FAN-3977 metrics and the FAN-3981 M3 object count**
on the built PCK: the exported app binary does not run an external `--script`
(FAN-3980), so the unchanged FAN-3981 driver `evidence/FAN-3981/perf_driver.gd`
(= the FAN-3977 driver plus per-phase `Performance.OBJECT_COUNT`; SHA-256
`2a386cdd…`) ran under the Godot 4.7.stable editor engine binary with `--main-pack`
on the installed app's PCK (the FAN-3973 `exported_pack_probe` approach), windowed,
GL Compatibility, vsync on, 2560x1440, isolated `HOME` (`run_combat_check.sh`;
logs/JSON in `perf/`, tables in `perf_tables.md`). Real run path: route map (8 s) →
first battle node → 48 enemies for 60 s with every mini-elite kind rolled → elite
`night_stalker` (20 s) → act-1 boss `rift_warden` (60 s) → act-2 boss
`disk_devourer` (20 s) → main menu. Two boss modes as in FAN-3981: the FAN-3977
default keeps 48 enemies alive during boss fights (`48-enemy top-up`) and
`boss=natural` (the checklist's plain P3 boss fight).

| Run (class) | Boss mode | P2 peak objects | P3 peak objects | elite / act-2 boss peak | act-1 peak tex MiB | roster-miss warnings | P2 frames >50 / >100 ms (longest) | P3 frames >50 / >100 ms | act-2 boss frames >50 / >100 ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Berserk | 48-enemy top-up | **3,984** | **4,533** | 4,001 / 4,036 | 1,407 | 0 | 1 / 0 (76.1) | 0 / 0 | 0 / 0 |
| Berserk | natural | **4,051** | **3,242** | 3,870 / 3,383 | 1,407 | 0 | 1 / 0 (83.7) | 0 / 0 | 0 / 0 |
| Druid | 48-enemy top-up | **3,614** | **4,184** | 3,716 / 3,797 | 1,488 | 0 | 1 / 0 (70.0) | 13 / 0 | 29 / 0 |
| Druid (rerun) | 48-enemy top-up | **3,624** | **4,293** | 3,660 / 3,787 | 1,488 | 0 | 2 / 0 (86.4) | 7 / 0 | 8 / 0 |

- **M3 within the hard limits in every run:** P2 3,614–4,051 ≤ 6,250 and P3
  3,242–4,533 ≤ 5,000 (`m3_within_hard_limits_all_runs=true`). Beside the FAN-3981
  QA numbers (reviewer `d7bc8435`): candidate top-up P2 4,042 / P3 4,845 (exported
  PCK 4,123 / 4,808), natural P2 4,023 / P3 3,288; the unfixed `v0.3.1` (165f14aa)
  8,993–9,176 / 5,677–7,362; `v0.3.0` 4,251–4,363 / 3,378–5,305; FAN-3964 Windows on the
  FAN-3980 package P2 8,643–8,719, P3 5,680. The checklist target (P2 ≤ 5,000 /
  P3 ≤ 4,000) is met for P2 in every run and for P3 in the plain boss fight
  (3,242); the P3 48-enemy top-up mode stays yellow (4,184–4,533, the pre-existing boss
  population budget FAN-3981 explained, at or below the 0.3.0 scale of 5,305). After
  returning to the main menu the count is 2,496–2,497 with 0 resident packs. The menu
  baseline under `--main-pack` is 1,593–1,595 (the editor project run in FAN-3981
  reported ~2,230 in the same phase; the P2/P3 peaks are what the limits bind).
- **No synchronous frame load in combat:** 0 `encounter roster miss` warnings and 0
  warnings of any kind in all four runs; every P2/elite/boss roster wait was
  0/144–212 ms at fight start, before spawning, as designed by FAN-3977.
- **Texture memory within the FAN-3977 target:** act-1 peak 1,407 MiB (Berserk) /
  1,488 MiB (Druid) — exactly the FAN-3977 / FAN-3980 values (target ≤ 1.5 GiB);
  v0.3.2 had 4,710 / 4,497 MiB. Menu 28 MiB → 310 MiB after the run (packs released
  at the main menu, same as every FAN-3977 build).
- P2 48-enemy fight: 0 frames over 100 ms in all runs, 1 % low 102–137 FPS (target
  ≥ 60); one or two 70–86 ms frames per run (no pack load; FAN-3980 showed the same
  single ~75 ms frame). **Recorded for the FAN-3964 Windows review:** the Druid
  boss phases show more 50–90 ms frames than the FAN-3980 package did (act-1 boss 13
  then 7, act-2 boss 29 then 8 in two runs; FAN-3980 Druid had 0 and 1; longest 82 ms,
  none over 100 ms, 1 % low 83–124 FPS). Berserk boss phases have 0. The spread between
  the two Druid runs is large, so this is host variance and Druid summon/VFX cost
  (as in FAN-3977) rather than a stall; it is not one of the FAN-3977 targets, and no
  frame in any combat phase reached 100 ms.

## Same-run transfer to FAN-3964 (Transfer early)

`split_transfer.sh`: the exact retained `FantasyDisk-0.3.1-windows-setup.exe` was
split with `split -b 50000000 -a 2` into 9 parts (8 × 50,000,000 B + 38,427,863 B),
`PARTS.sha256` (990 B, SHA-256 `5cb0d4db…`) written, `SHA256SUMS.txt` and
`update-manifest.json` copied; the binary rejoin of the parts hashes to
`db99a929…` = retained installer = `SHA256SUMS.txt` entry (`transfer_record.txt`).
All 12 files were attached to FAN-3964 marked "package review pending" (FAN-3964
comment `01a0e7de-878e-78fd-b433-58ff2bb8ed7f`, 12 attachments, sizes read back
equal to the parts; `PARTS.sha256` and `part-ai` downloaded back and byte-equal).
The first upload attempt timed out after three parts and created no comment; the
second attempt (raised HTTP timeout) succeeded. The parts are not a Windows result.

## Candidate checks

- `python3 tools/scan_release_secrets.py evidence/FAN-3983` → passed (1 artifact root).
- `python3 tools/quality_static_guard.py --changed-ref origin/dev` → passed.
- Identity fingerprint / certificate CN / team id / e-mail: 0 occurrences in the raw
  build log and in this directory.
- Task worktree HEAD `f4d05fea…` (the tag commit) before; only `evidence/FAN-3983/**`
  is added. The `/tmp` build worktree was removed by the script; `build/FAN-3983/`
  (git-ignored scratch: extracted exe, split parts, reference app, isolated homes,
  full manifests) is task-owned and removed after the handoff.

## Limits and carried risk

- No native Windows check (macOS host); FAN-3964 verifies the same Setup bytes natively.
- The combat/M3 check ran the built PCK under the editor engine binary, not the
  exported Windows/macOS executable; the PCK is the same bytes in both platform
  payloads (identical file tables), but per-host object baselines, GL texture-upload
  cost and the Windows texture baseline remain FAN-3964's measurements.
- Independent QA — not this report — decides acceptance.

## Files

- `package_manifest.json` — immutable package manifest (source pins, build command
  and timing, retained inventory, cross-checks incl. old-vs-new hash table against
  both old 0.3.1 packages, trust-channel lines, preservation record, built-bytes checks).
- `extra_checks.json` — AC3/AC4 data (PCK exclusion, sizes vs both old packages, cold
  start, FAN-3977 metrics + M3 with verdicts), snapshot equality, operator app
  reinstall and saves proof, transfer record.
- `build_release.log` — sanitized milestone log; `build_log_full.txt` (hash of the
  full sanitized log attached to the handoff); `build_timing.txt`.
- `SHA256SUMS.txt`, `update-manifest.json`, `LOCAL_RELEASE.json`, `CHANGELOG-0.3.1.md` —
  byte copies of the retained files; `local_release_verify.json` — readback.
- `00_preflight.txt`, `preflight.sh`, `pre_build_ls_remote.txt`, `post_build_ls_remote.txt`,
  `prebuild_notary_history_exit.txt`, `notary_history_top2.txt`.
- `preservation/` — relocation record, before-manifests (`.gz`) of attempt 2, attempt 1
  and 0.3.2, directory list, `manifest_equality.txt` (before/after manifest hashes).
- `macos_pck_summary.md`, `windows_pck_summary.md`, `pck_0.3.1new_macos.json`,
  `pck_0.3.1new_windows.json` — PCK tables.
- `cold_start/`, `cold_start_summary.md` — AC3 timing; `perf/`, `perf_tables.md` —
  FAN-3981 driver logs/JSON and tables.
- `saves_before.sha256`, `saves_after_install.sha256`, `saves_after_all.sha256`,
  `dmg_app_files.sha256`, `installed_app_files.sha256`, `snapshot_files_vs_tag.txt`.
- `transfer_record.txt`, `PARTS.sha256` — FAN-3964 transfer.
- `run_build.sh`, `make_evidence.py`, `collect_extra_checks.py`, `list_pck.py`,
  `measure_cold_start_app.sh`, `run_combat_check.sh`, `split_transfer.sh` — the exact
  scripts used.
