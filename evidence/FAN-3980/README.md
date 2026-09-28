# FAN-3980 evidence: fixed 0.3.1 exact-tag package build and retention, old 0.3.1 bytes preserved (2026-09-28, macOS)

**Developer result: the new signed 0.3.1 package was built from the re-pointed
immutable `v0.3.1` tag (commit `165f14aa…`, the FAN-3978 PASSED / FAN-3979
verified tree), notarized by Apple (app and DMG), retained under the configured
durable local release root, and both fixes (FAN-3973 startup, FAN-3977 combat
freezes) are verified in the built bytes. The old 0.3.1 package (FAN-3963,
source `448a0cc1…`) and the 0.3.2 package (FAN-3976) keep every byte; the old
0.3.1 directory was relocated intact to `releases/archive/v0.3.1-attempt1-448a0cc1/`
because the maintained retention tool cannot hold two 0.3.1 packages side by
side.** This is developer evidence, not independent QA, not a Windows installer
PASS, and not a publication. The only repository change in this candidate is
`evidence/FAN-3980/**` (`releases/` is git-ignored; the package lives in the
durable root).

Builder: Fable (`5c006dd4-45c3-4dd0-b1bb-d5e4a0d7e1f9`), macOS development host
(Apple M4 Pro, macOS 26.5.1, Godot `4.7.stable.official.5b4e0cb0f`, `makensis v3.12`).
Task worktree `agent/fable/695448bc53e9` at `165f14aa…`, clean before and after
the build. All timestamps UTC. Authority: Sergey Fomin's direct instruction of
2026-09-27 (FAN-3964 comment `01a0e4b2-794b-7b49-b1cd-31650d322d95`): all fixes
ship as 0.3.1, no new versions.

| Pin | Exact value |
| --- | --- |
| Tag `v0.3.1` (annotated object, re-pointed by FAN-3979) | `c692d01973a7e4765807bd5fcae11c6bb74df5e6` |
| Tag target commit S | `165f14aa0ce5bcbd884e4dfde137283a8010e863` |
| Tag target tree | `9dd96fa9cec99be330b638cdd04dfd1a42d4840d` |
| FAN-3978 PASSED candidate / tree | `165f14aa…` / `9dd96fa9…` (reviewer `d7bc8435`, run `01a0e4f9-e6c9-78d7-bf87-ed23f4965689`) — **equal to S**, so the certifying gate and six core smokes are not rerun (refined AC1) |
| FAN-3979 | `done`, independent QA PASSED (reviewer `8ceb4992`, run `01a0e547-7c29-7f3c-8fb0-1ce488e03997`) |
| Old tag object (archive) | `archive/v0.3.1-attempt1-448a0cc1` = `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → `448a0cc12f02eb05bc16becc69fde365021a9a17` (tree `3e02df83…`) |
| `origin/main` / `origin/dev` at build readback | `dafb99ea70af8ace6c2b866cd1fb57a52bda0a87` / `165f14aa…` |
| `v0.3.2` (unchanged) | `90279733…` → `36340c47…` |

A stale clone keeps the old `v0.3.1` because `git fetch` never overwrites a tag;
the task worktree ran `git fetch --force origin '+refs/tags/*:refs/tags/*'` and
then read back `v0.3.1` = `c692d019…`, `v0.3.1^{}` = S, `v0.3.1^{tree}` = S tree
(`00_preflight.txt`). `git ls-remote` for `dev`, `main`, `v0.3.1`, `v0.3.1^{}`,
`v0.3.2`, `v0.3.2^{}` and the archive tag was identical before and after the
build (`pre_build_ls_remote.txt`, `post_build_ls_remote.txt`). No `main`/tag write,
no public upload, no Telegram/Discord send, no channel downgrade.

## Pre-build checks on exact S (AC1, refined)

| Check | Result |
| --- | --- |
| Tree equality S vs FAN-3978 PASSED tree | `tree_equal_S_vs_FAN3978=true` (`00_preflight.txt`). Certifying gate / six smokes reused, not rerun. **PASS** |
| Version mapping | `tools/release_version_mapping.py --version 0.3.1` → `0.3.1 1.3.10 0.3.1 0.3.1.0`, exit 0. **PASS** |
| Release inputs | `CHANGELOG.md` `## [0.3.1] — 2026-09-28` (line 7, below empty `Unreleased`); `scripts/patch_notes_data.gd` newest entry `0.3.1` / `2026-09-28`; poster `assets/marketing/fantasydisk_031_announcement.png` SHA-256 `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` (blob `51803688…`, same as FAN-3979's readback); client `MACOS_UPDATE_CHANNEL := "signed"`; `release_scope_guard` `OK: 0.3.1, 0 entries`; `release_notes_visual_claims_guard` OK; `tests/test_export_presets_exclusions.py` 5 OK. **PASS** |
| Signed-channel authorization | One Developer ID Application identity installed, the owner-selected certificate fingerprint matches it; `xcrun notarytool history --keychain-profile FantasyDiskRelease` exit 0 before the build (`prebuild_notary_history_exit.txt`) and again inside `build_release.sh`. Identity fingerprint, subject, team id and Apple account values are never written (grep of the raw log and of this directory: 0 hits). **PASS** |

## Preservation of the old packages (preservation rules)

`skills/codex/fantasydisk-release-director/scripts/local_release.py
materialize_package()` writes only `releases/v<version>` and, when that directory
already exists, calls `_compare_package()`, which raises `existing local release
differs` for any byte-different package; there is no alternate destination
option. A second 0.3.1 package therefore cannot be retained beside the old one,
and the permitted relocation was used (no tooling change, no rename of any file):

1. Recursive SHA-256 manifest of `releases/v0.3.1` (114,341 files, 7.7 GB) and of
   `releases/v0.3.2` (114,453 files) **before** anything else
   (`preservation/preserve_v0.3.1_before.sha256.gz`, `preserve_v0.3.2_before.sha256.gz`;
   manifest SHA-256 `7632cea6…` and `f6fbd8ef…`).
2. `mv releases/v0.3.1 releases/archive/v0.3.1-attempt1-448a0cc1` (same APFS
   volume, directory rename, 2026-09-28T00:18:39Z; `preservation/preserve_relocation.txt`).
3. Manifest **after** the relocation: identical bytes to the before manifest
   (`cmp` exit 0, manifest SHA-256 `7632cea6…`), directory list identical.
   Repeated after the build, verify and perf runs: still identical
   (`preservation/manifest_equality.txt`).
4. `releases/v0.3.2` manifest after the build: identical (`f6fbd8ef…`).
   `v0.3.0`, `v0.3.2` and the archived 0.3.1 `LOCAL_RELEASE.json` hashes are
   unchanged (`8e938ab4…`, `f5a16d18…`, `a39d705d…`); directory mtimes unchanged
   (Sep 7 06:36, Sep 26 22:50, Sep 26 05:15).

The old package's own hashes (DMG `6465fb7c…`, Setup `375c5290…`) are now at the
archive path only; no old file was relabeled or copied into the new package.

## Build (AC2)

`FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease
MACOS_SIGN_IDENTITY=<resolved locally> tools/build_release.sh 0.3.1`, launched by
`run_build.sh` (resolves the identity from the selected certificate at run time and
overrides `core.hooksPath` only in the build process environment — the
FAN-3963/FAN-3976 workaround for the Multica `cow_checkout` post-checkout hook that
rejects the `/tmp` build worktree; the shared repository config and the script are
unchanged and the build compares the running script byte-for-byte with the tag's
copy). Started 2026-09-28T00:19:32Z, finished 00:30:23Z, exit 0, first attempt.
The build worktree is a detached `/tmp/fantasydisk-build-*/src` checkout of the
exact tag (isolated task-owned staging), removed by the script on exit.

Milestones in `build_release.log` (milestone lines of the sanitized log; the full
sanitized log, 54,278 lines, SHA-256 `802b82e1…`, is attached to the handoff comment
as `.gz`; raw log SHA-256 in `package_manifest.json`): 15 build inputs present and
running script equal to the tag's; canonical notes assembled; version mapping;
`release scope OK: 0.3.1, 0 entries`; no unbacked visual claims; client channel
label `signed`; headless import; macOS export; Developer ID signing with hardened
runtime and timestamp; `codesign --verify --deep --strict` valid; **Apple
notarization accepted FantasyDisk.app**; staple and validate worked; `spctl`
accepted, `source=Notarized Developer ID`; DMG created, `hdiutil verify` VALID,
layout OK; DMG signed; **Apple notarization accepted FantasyDisk DMG**;
staple/validate/`spctl` accepted; Windows export (`embed_pck`); NSIS installer;
`NSIS CRC OK (firstheader @ 38912, crc @ 438509195)`; read-only DMG mount:
signature, staple and `spctl` accepted, `Applications` link present; `Release
secret scan passed (3 artifact root(s))`; `SHA256SUMS.txt`; `update-manifest.json`;
`local_release.py materialize` → `"status": "verified"`.

Apple submission history (status only, `notary_history_top2.txt`):
`FantasyDisk-0.3.1-macos-notary.zip` Accepted 00:22:03Z;
`FantasyDisk-0.3.1-macos.dmg` Accepted 00:24:34Z.

## Retained package (`/Users/sergeyfomin/FantasyDisk/releases/v0.3.1/`, AC4)

| File | Size (bytes) | SHA-256 (new) | FAN-3963 value | Differs |
| --- | --- | --- | --- | --- |
| `FantasyDisk-0.3.1-macos.dmg` | 463,011,379 | `d6fc182c82a37545f36ed203f416d0c1385a24d18fc98e8da42ad21121945872` | `6465fb7c…` (559,696,549 B) | yes |
| `FantasyDisk-0.3.1-windows-setup.exe` | 438,509,199 | `6d11ae1fe8190c45774bc02d8435d7eb34ccd305f13d3372bc58c6ad7e46e29e` | `375c5290…` (535,974,634 B) | yes |
| `SHA256SUMS.txt` | 196 | `7775c739df9112c6dde6d26064cbd871fbf5252fde3bbed3f0270d82e394ea82` | `a1cc64e8…` | yes |
| `update-manifest.json` | 793 | `315821ff4b73ecbfcb17204d8d044bc8d829b6dade1ae380dba07543569e1ad1` | `a81d1149…` | yes |
| `CHANGELOG-0.3.1.md` | 5,901 | `9f3b1c6d0fcfe92c908ec12f74cf74308d8f3f52555fc0b743e7074918c89975` | `399dceb4…` | yes |
| `fantasydisk_031_announcement.png` | 95,930 | `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` | `d9ac6ea8…` | yes |
| `LOCAL_RELEASE.json` | 1,948 | `a264215d6123c86b05dfffc9d3e2e483020fcf6741ca7f1c8b76d29601d0a213`; tag `v0.3.1`, `tag_commit` `165f14aa…`, `macos_channel` `signed`, `source_tree_sha256` `d8311aa2…` | `a39d705d…` | yes |

`package_manifest.json` (`cross_checks.all_new_hashes_differ_from_fan3963=true`) is
the immutable package manifest: fresh SHA-256 of every retained file, and
cross-checks that `SHA256SUMS.txt`, `update-manifest.json` (names, sizes, URLs under
`FomaBy/FantasyDisk-Releases/releases/download/v0.3.1/`) and the `LOCAL_RELEASE.json`
inventory all equal the fresh hashes (`sha256sums_match_fresh`,
`update_manifest_all_ok`, `local_release_inventory_match_fresh` = true).
`CHANGELOG-0.3.1.md` is byte-equal to the `## [0.3.1]` section of the tag's
`CHANGELOG.md`; the poster equals the tag blob. `project/` is the exact `git
archive v0.3.1` (`diff -rq --exclude=.godot` against a fresh extraction: 0
differences; file list equals `git ls-tree -r v0.3.1`, 57,631 files,
`snapshot_files_vs_tag.txt`), plus `godot-project/` (separate editable copy). No raw
Windows exe or zip is retained.

Readback after the build: `local_release.py verify --version 0.3.1 --macos-channel
signed --launch-smoke` exit 0, `"status": "verified"` (`local_release_verify.json`);
`shasum -a 256 -c SHA256SUMS.txt` OK; `releases/current-project →
v0.3.1/godot-project` (was `v0.3.2/godot-project`), registered as a favorite in
Godot `projects.cfg`; `/Applications/FantasyDisk.app` is **0.3.1 / 1.3.10** (was
0.3.2 / 1.3.20 — the recorded operator downgrade), `codesign --verify --deep
--strict` valid, `stapler validate` worked, `spctl --assess --type execute`
accepted (`source=Notarized Developer ID`), and its file tree is identical
(per-file SHA-256, 9 files) to the app inside the retained DMG
(`dmg_app_files.sha256` = `installed_app_files.sha256`).

**Saves untouched by the downgrade:** the five `*.cfg` files of
`~/Library/Application Support/Godot/app_userdata/FantasyDisk` (including
`fantasydisk_meta.cfg` and `settings.cfg`) have the same SHA-256 before the install,
after the install + `verify --launch-smoke`, and after all cold-start/perf runs
(`saves_before.sha256` = `saves_after_install.sha256` = `saves_after_all.sha256`);
the whole user-data tree excluding `logs/`, `shader_cache/` and `vulkan/` shows 0
differences. The launch smokes only added engine log files under `logs/`. Cold
start and perf runs used isolated `HOME` directories.

## Both fixes in the built bytes (AC3)

PCK file tables read from the shipped bytes with `list_pck.py` (FAN-3973 rule set;
the Windows exe extracted read-only from the retained installers with `7z e`):

| Built payload | Files | Payload | Forbidden paths (`evidence/`, `skills/`, `docs/`, `tools/`, `tests/`, stray root `.import`) |
| --- | --- | --- | --- |
| new 0.3.1 macOS `FantasyDisk.pck` (installed app = DMG app; SHA-256 `7767a9d1…`) | 27,013 | 420,853,259 B (401.4 MiB) | **0** |
| new 0.3.1 Windows `FantasyDisk.exe` embedded PCK | 27,013 | 420,853,259 B (401.4 MiB) | **0** |
| old 0.3.1 (FAN-3963) Windows exe PCK, for comparison | 47,137 | 735,045,521 B (701.0 MiB) | 1,237 |

The macOS and Windows file tables are byte-identical (`macos_pck_summary.md`,
`windows_pck_summary.md`, `pck_0.3.1new_*.json`). Top-level content: `.godot`
13,062 files, `assets` 13,020, `scripts` 576, `data` 156, `scenes` 196, root
`icon.svg`, `icon.svg.import`, `project.binary` — the FAN-3977 candidate export
footprint (27,013 files, 401.4 MiB: per-frame sources replaced by trim atlases).
Sizes: Windows exe inside Setup 533,581,104 B vs 850,651,688 B (FAN-3963); Setup
438,509,199 B (418.2 MiB) vs 535,974,634 B; DMG 463,011,379 B vs 559,696,549 B.

**macOS cold start of the built app** (`measure_cold_start_app.sh`: FAN-3973 method
on the app binaries — `--print-fps --verbose --quit-after 600`, first `Project FPS`
line minus 1 s; five back-to-back launches per build; isolated `HOME` per build;
summary via `evidence/FAN-3973/analyze_cold_start.py`; logs in `cold_start/`):

| Build | Runs | Median first frame (s) | Min | Max | Actor SpriteFrames before first frame |
| --- | --- | --- | --- | --- | --- |
| 0.3.0 app (from retained `v0.3.0` DMG) | 5 | 5.47 | 5.46 | 7.84 (first launch, cold file cache) | 1 |
| **new 0.3.1 app (installed from the retained DMG)** | 5 | **5.70** | 5.54 | 6.02 | 1 |

Within 0.23 s of the 0.3.0 reference under the same method (FAN-3976 measured
0.3.2 at 5.70 vs 0.3.0 5.56 with the same method), one scene-dependency pack
before the first frame in both — the FAN-3973 state, not the FAN-3963 regression
(8.09 s editor method, 17.4 s on Windows per FAN-3964). Windows timing stays with
FAN-3964.

**Scripted combat check with the FAN-3977 metrics** on the built PCK: the exported
app binary does not run an external `--script` (a headless probe hung and was
killed), so the unchanged FAN-3977 driver `evidence/FAN-3977/perf_driver.gd`
(SHA-256 `aa25cf38…`) ran under the Godot 4.7.stable editor engine binary with
`--main-pack` on the installed app's PCK (the FAN-3973 `exported_pack_probe`
approach), windowed, GL Compatibility, vsync 120 Hz, 2560x1440, isolated `HOME`
(`run_combat_check.sh`; logs/JSON in `perf/`). Real run path: route map (8 s) →
first battle node → 48 enemies for 60 s with every mini-elite kind rolled → elite
`night_stalker` (20 s) → act-1 boss `rift_warden` (20 s) → act-2 boss
`disk_devourer` (20 s) → main menu.

| Build (class) | Phase | avg FPS | 1% low | frames >50 ms | frames >100 ms | longest frame ms | peak texture MiB |
| --- | --- | --- | --- | --- | --- | --- | --- |
| new 0.3.1 PCK (Berserk) | route_map_first_show | 119 | 114 | 0 | 0 | 18.0 | 1315 |
| new 0.3.1 PCK (Berserk) | p2_48_enemies | 118 | 112 | 1 | 0 | 75.7 | 1407 |
| new 0.3.1 PCK (Berserk) | elite_night_stalker | 118 | 115 | 0 | 0 | 27.0 | 951 |
| new 0.3.1 PCK (Berserk) | boss_act1_rift_warden | 118 | 115 | 0 | 0 | 24.9 | 920 |
| new 0.3.1 PCK (Berserk) | boss_act2_disk_devourer | 116 | 114 | 0 | 0 | 31.1 | 968 |
| new 0.3.1 PCK (Druid) | route_map_first_show | 118 | 113 | 0 | 0 | 18.9 | 1396 |
| new 0.3.1 PCK (Druid) | p2_48_enemies | 115 | 104 | 1 | 0 | 75.2 | 1488 |
| new 0.3.1 PCK (Druid) | elite_night_stalker | 112 | 106 | 0 | 0 | 47.0 | 1032 |
| new 0.3.1 PCK (Druid) | boss_act1_rift_warden | 114 | 107 | 0 | 0 | 33.8 | 1001 |
| new 0.3.1 PCK (Druid) | boss_act2_disk_devourer | 91 | 75 | 1 | 0 | 52.9 | 1049 |

- **No synchronous frame load in combat:** 0 `encounter roster miss` warnings and
  0 warnings of any kind in both runs (`synchronous_combat_load_count` path never
  taken); every P2/elite/boss roster wait was 0/144/195 ms at fight start, before
  spawning, as designed by FAN-3977.
- **Texture memory within the FAN-3977 target:** act-1 peak 1,407 MiB (Berserk) /
  1,488 MiB (Druid) — exactly the FAN-3977 candidate values (target ≤ 1.5 GiB);
  v0.3.2 had 4,710 / 4,497 MiB. Menu 28 MiB → 310 MiB after the run (packs
  released at the main menu, same as every FAN-3977 build).
- P2 48-enemy fight: 0 frames over 100 ms, 1 % low 112 / 104 FPS (target ≥ 60);
  v0.3.2 had 12 frames over 100 ms (longest 497–611 ms). One 75 ms frame per run
  during P2 (no pack load; the FAN-3977 candidate run showed none) and the
  Druid act-2 boss phase's single 52.9 ms frame (Druid summon/VFX cost, as in
  FAN-3977) are recorded for the FAN-3964 Windows review; neither is a stall
  to 1 FPS.

## Same-run transfer to FAN-3964 (Transfer early)

`split_transfer.sh`: the exact retained `FantasyDisk-0.3.1-windows-setup.exe` was
split with `split -b 50000000 -a 2` into 9 parts (8 × 50,000,000 B + 38,509,199 B),
`PARTS.sha256` (990 B, SHA-256 `353479c4…`) written, `SHA256SUMS.txt` and
`update-manifest.json` copied; the binary rejoin of the parts hashes to
`6d11ae1f…` = retained installer = `SHA256SUMS.txt` entry (`transfer_record.txt`).
All 12 files were attached to FAN-3964 marked "package review pending" (FAN-3964
comment `01a0e57d-5e5d-7a20-8782-49d43565c43c`, 12 attachments, sizes read back
equal to the parts). The parts are not a Windows result.

## Candidate checks

- `python3 tools/scan_release_secrets.py evidence/FAN-3980` → see the handoff comment.
- Identity fingerprint / certificate CN / team id / e-mail: 0 occurrences in the raw
  build log and in this directory.
- `python3 tools/quality_static_guard.py --changed-ref origin/dev` → see the handoff comment.
- Task worktree HEAD `165f14aa…` (the tag commit) before and after; only
  `evidence/FAN-3980/**` is added. The `/tmp` build worktree was removed by the
  script; `build/FAN-3980/` (git-ignored scratch: extracted exes, split parts,
  reference app, isolated homes) is task-owned and removed after the handoff.

## Limits and carried risk

- No native Windows check (macOS host); FAN-3964 verifies the same Setup bytes natively.
- The combat check ran the built PCK under the editor engine binary, not the
  exported Windows/macOS executable; the PCK is the same bytes in both platform
  payloads (identical file tables), but per-host GL texture-upload cost and the
  Windows texture baseline remain FAN-3964's measurements.
- Independent QA — not this report — decides acceptance.

## Files

- `package_manifest.json` — immutable package manifest (source pins, build command
  and timing, retained inventory, cross-checks incl. old-vs-new hash table,
  trust-channel lines, preservation record, built-bytes checks).
- `extra_checks.json` — AC3 data (PCK exclusion, sizes vs FAN-3963, cold start,
  FAN-3977 combat metrics with verdicts), snapshot equality, operator app downgrade
  and saves proof, transfer record.
- `build_release.log` — sanitized milestone log; `build_timing.txt`.
- `SHA256SUMS.txt`, `update-manifest.json`, `LOCAL_RELEASE.json`, `CHANGELOG-0.3.1.md` —
  byte copies of the retained files; `local_release_verify.json` — readback.
- `00_preflight.txt`, `pre_build_ls_remote.txt`, `post_build_ls_remote.txt`,
  `prebuild_notary_history_exit.txt`, `notary_history_top2.txt`.
- `preservation/` — relocation record, before-manifests (`.gz`), directory list,
  `manifest_equality.txt` (before/after manifest hashes).
- `macos_pck_summary.md`, `windows_pck_summary.md`, `pck_0.3.1new_macos.json`,
  `pck_0.3.1new_windows.json`, `pck_0.3.1old_windows.json` — PCK tables.
- `cold_start/`, `cold_start_summary.md` — AC3 timing; `perf/` — FAN-3977 driver logs/JSON.
- `saves_before.sha256`, `saves_after_install.sha256`, `saves_after_all.sha256`,
  `dmg_app_files.sha256`, `installed_app_files.sha256`, `snapshot_files_vs_tag.txt`.
- `transfer_record.txt`, `PARTS.sha256` — FAN-3964 transfer.
- `run_build.sh`, `make_evidence.py`, `list_pck.py`, `measure_cold_start_app.sh`,
  `run_combat_check.sh`, `split_transfer.sh` — the exact scripts used.
