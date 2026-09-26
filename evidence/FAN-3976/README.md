# FAN-3976 evidence: exact-tag 0.3.2 package build and retention (2026-09-26, macOS)

**Developer result: the signed 0.3.2 package was built from the immutable `v0.3.2`
tag, notarized by Apple (app and DMG), retained under the configured durable local
release root, and the FAN-3973 export fix is verified in the built bytes.** This is
developer evidence, not independent QA, not a Windows installer PASS, and not a
publication. The only repository change in this candidate is `evidence/FAN-3976/**`
(`releases/` is git-ignored; the package lives in the durable root).

| Pin | Exact value |
| --- | --- |
| Tag `v0.3.2` (annotated object) | `90279733311632aec88a70317e18afc67518e6d2` |
| Tag target commit | `36340c473772781edafffb61ff1d8cc7caa42024` |
| Tag target tree | `1a361d628d8a4160a6f44993f2ed954c50593341` |
| `origin/main` at build readback | `67b24d499082c7f15943253c5e857cd4b2e6892d` |
| `origin/dev` at build readback | `36340c473772781edafffb61ff1d8cc7caa42024` |
| Remote `v0.3.1` (unchanged) | `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| Build checkout HEAD | `36340c473772781edafffb61ff1d8cc7caa42024`, clean worktree |
| Dependency | FAN-3975 `done`, independent QA `PASSED` (run `01a0df13-2fb2-71b9-9ae0-2faea2c87abb`) |

`git ls-remote` for `main`, `dev`, `v0.3.1`, `v0.3.1^{}`, `v0.3.2`, `v0.3.2^{}`
was identical before and after the build (`pre_build_ls_remote.txt`,
`post_build_ls_remote.txt`). The local tag object, its target and tree equal the
dispatch contract. No `main`/tag write, no public upload, no Telegram/Discord send,
no channel downgrade.

## Pre-build gates on the tag commit (AC1)

| Gate | Result |
| --- | --- |
| Six core smoke suites | `python3 tools/godot_gate.py --headless --path . --script res://tests/<name>.gd` after an import pre-pass (`run_smokes.py`): `runtime_smoke_test` 120.3 s, `runtime_smoke_ui_test` 6.8 s, `runtime_smoke_combat_test` 4.7 s, `runtime_smoke_progression_economy_test` 6.7 s, `runtime_smoke_weapon_mechanics_test` 92.0 s, `runtime_smoke_boss_elite_test` 9.3 s. All exit 0, pass marker present, 0 `SCRIPT ERROR` (`smoke_outputs.json`, logs). The base and UI logs carry the one known benign `ERROR: Parameter "t" is null.` from the optional headless screenshot helper (accepted on FAN-3962/FAN-3975). **PASS** |
| Certifying quality gate | `python3 tools/quality_gate.py --profile static --report …` on a clean worktree: `QUALITY PASSED: 16 static, 0 Godot`, `certifying=true`, `worktree_clean=true`, `git_sha=36340c47…` (`static_quality_report.json`). The complete `--profile full` gate (16 static, 559 Godot) ran on this exact tree on FAN-3975 and passed independent QA. **PASS** |
| Version mapping | `tools/release_version_mapping.py --version 0.3.2` → `0.3.2 1.3.20 0.3.2 0.3.2.0`. **PASS** |
| Release inputs | `CHANGELOG.md`: `## [0.3.2] — 2026-09-26` below an empty `Unreleased`, `0.3.1` marked `[YANKED]`; `assets/marketing/fantasydisk_032_announcement.png` SHA-256 `7a890effc71460cda7769902c4adb7f8da217ccf4f7f2a935ed7d30e580c0867` (same as the FAN-3974/FAN-3975 provenance); client `MACOS_UPDATE_CHANNEL := "signed"`; `export_presets.cfg` exclusions from FAN-3973 present. **PASS** |
| Signed-channel authorization | One Developer ID Application identity installed; the owner-selected certificate fingerprint matches it; `xcrun notarytool history --keychain-profile FantasyDiskRelease` exit 0 before the build (`prebuild_notary_history_exit.txt`) and again inside `build_release.sh`. Identity, subject, team and Apple account values are never written (grep of the raw log and of this directory: 0 hits). **PASS** |

## Build (AC2)

`FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease
MACOS_SIGN_IDENTITY=<resolved locally> tools/build_release.sh 0.3.2`, launched by
`run_build.sh` (resolves the identity from the selected certificate at run time and
overrides `core.hooksPath` only in the build process environment, the FAN-3963
workaround for the Multica `cow_checkout` post-checkout hook that rejects the
`/tmp` build worktree; the shared repository config and the script are unchanged
and the build compares the running script byte-for-byte with the tag's copy).
Started 2026-09-26T19:41:05Z, finished 19:51:25Z, exit 0, first attempt. Godot
`4.7.stable.official.5b4e0cb0f`, `makensis v3.12`, macOS 26.5.1.

Steps observed in `build_release.log` (milestone lines of the raw log; full raw log
SHA-256 `9b293cb3f13381c1a5a4512c6f65a5314ff11eeebc523828653f3c175abf2346`,
14,081,367 B, attached to the handoff comment as `.gz`): 15 build inputs present
and running script equal to the tag's; canonical notes assembled from 3 fragments;
version mapping; `release scope OK: 0.3.2, 0 entries`; no unbacked visual claims;
client channel label `signed`; headless import; macOS export; Developer ID signing
with hardened runtime and timestamp; `codesign --verify --deep --strict` valid;
**Apple notarization accepted FantasyDisk.app**; staple and validate worked;
`spctl` accepted, `source=Notarized Developer ID`; DMG created, `hdiutil verify`
VALID, layout OK; DMG signed; **Apple notarization accepted FantasyDisk DMG**;
staple/validate/`spctl` accepted; Windows export (`embed_pck`); NSIS installer;
`NSIS CRC OK (firstheader @ 38912, crc @ 439647260)`; read-only DMG mount:
signature, staple and `spctl` accepted, `Applications` link present; `Release
secret scan passed (3 artifact root(s))`; `SHA256SUMS.txt`; `update-manifest.json`;
`local_release.py materialize` → `"status": "verified"`.

Apple submission history (status only, read back afterwards, `notary_history_top2.txt`):
`FantasyDisk-0.3.2-macos-notary.zip` Accepted 19:43:42Z;
`FantasyDisk-0.3.2-macos.dmg` Accepted 19:45:50Z.

## Retained package (`/Users/sergeyfomin/FantasyDisk/releases/v0.3.2/`, AC4)

| File | Size (bytes) | SHA-256 |
| --- | --- | --- |
| `FantasyDisk-0.3.2-macos.dmg` | 464,183,243 | `d981f7f2b8a27f1fd564ca10d36c135d1211f61af8caa96080c67adfe761eab5` |
| `FantasyDisk-0.3.2-windows-setup.exe` | 439,647,264 | `8b7b3e7d1ce3ce6d935e50ff7b16962606772d416e5957e4847eceb305c8131f` |
| `SHA256SUMS.txt` | 196 | `00d198dc8809868aae742d2cab575ff2314cc4e6fb7ff9e04d0bb72d000160e6` |
| `CHANGELOG-0.3.2.md` | 5,776 | `f110592906eacccc625f0ed47518eac3b1b0eccc539ec8f25ab0339397646cb2` |
| `fantasydisk_032_announcement.png` | 95,877 | `7a890effc71460cda7769902c4adb7f8da217ccf4f7f2a935ed7d30e580c0867` |
| `update-manifest.json` | 793 | `1bbb0c9bea4720d338683f4a1099862c97ce52c79266c415ca75d777a74f623f` |
| `LOCAL_RELEASE.json` | 1,948 | `f5a16d18790be9c10e1ca7f6f17b4def5aa1c5e0b35c13127e00b9f01aedf632`; tag `v0.3.2`, `tag_commit` `36340c47…`, `macos_channel` `signed`, `source_tree_sha256` `ad62cf2872bb73db8d38a98c90303b1173ea50fa96a2da44b1e6b1746dd7ce23` |

Plus `project/` (exact `git archive` of the tag: `diff -rq --exclude=.godot` against a
fresh `git archive v0.3.2` extraction gives 0 differences and the file list equals
`git ls-tree -r v0.3.2`) and `godot-project/` (separate editable copy). No raw
Windows exe or zip is retained.

`package_manifest.json` is the immutable package manifest: fresh SHA-256 of every
retained file, and cross-checks that `SHA256SUMS.txt`, `update-manifest.json`
(names, sizes, URLs under `FomaBy/FantasyDisk-Releases/releases/download/v0.3.2/`)
and the `LOCAL_RELEASE.json` inventory all equal the fresh hashes
(`sha256sums_match_fresh`, `update_manifest_all_ok`,
`local_release_inventory_match_fresh` = true). `CHANGELOG-0.3.2.md` is byte-equal to
the `## [0.3.2]` section of the tag's `CHANGELOG.md`; the poster equals the tag blob.

Readback after the build: `local_release.py verify --version 0.3.2 --macos-channel
signed --launch-smoke` exit 0, `"status": "verified"` (`local_release_verify.json`);
`shasum -a 256 -c SHA256SUMS.txt` OK; `releases/current-project →
v0.3.2/godot-project`, registered in Godot `projects.cfg`;
`/Applications/FantasyDisk.app` is 0.3.2 / 1.3.20, `codesign --verify --deep
--strict` valid, `stapler validate` worked, `spctl --assess --type execute`
accepted (`source=Notarized Developer ID`), and its file tree is identical
(per-file SHA-256) to the app inside the retained DMG.

Retained `v0.3.1` and `v0.3.0` were not touched: `v0.3.1/LOCAL_RELEASE.json`
SHA-256 `a39d705dcb1f49e0cd3626b47c7894eeef5b2a9412c86eebc054787d615f060f`,
`v0.3.1` DMG `6465fb7c…` and setup `375c5290…` (the FAN-3963 values),
`v0.3.0/LOCAL_RELEASE.json` `8e938ab43d7f668041d94cf70e69c1a3a0beb9e217108289c820ddea43ce5b0c`;
directory mtimes unchanged (Sep 26 05:15 and Sep 7 06:36).

## FAN-3973 fix in the built bytes (AC3)

PCK file tables were read directly from the shipped bytes with `list_pck.py`
(FAN-3973 rule set; the Windows exe was extracted read-only from the retained
installer with `7z e` and its embedded PCK located through the Godot embed trailer).

| Built payload | Files | Payload | Forbidden paths (`evidence/`, `skills/`, `docs/`, `tools/`, `tests/`, stray root `.import`) |
| --- | --- | --- | --- |
| 0.3.2 macOS `FantasyDisk.pck` (installed app = DMG app) | 45,648 | 425,346,216 B (405.6 MiB) | **0** |
| 0.3.2 Windows `FantasyDisk.exe` embedded PCK | 45,648 | 425,346,216 B (405.6 MiB) | **0** |
| 0.3.1 Windows `FantasyDisk.exe` embedded PCK (baseline) | 47,137 | 735,045,521 B (701.0 MiB) | 1,237 (1,233 under `evidence/`, 2 under `skills/`, 2 root `.import`) |

The macOS and Windows 0.3.2 file tables are identical (`macos_pck_summary.md`,
`windows_pck_summary.md`, `pck_0.3.2_*.json`). Top-level content: `.godot`
22,381 files, `assets` 22,340, `scripts` 572, `data` 156, `scenes` 196, root
`icon.svg`, `icon.svg.import`, `project.binary`.

| Size | 0.3.2 | 0.3.1 | Delta |
| --- | --- | --- | --- |
| Windows `FantasyDisk.exe` inside Setup | 540,725,856 B | 850,651,688 B | −309,925,832 B |
| `FantasyDisk-<v>-windows-setup.exe` | 439,647,264 B (419.3 MiB) | 535,974,634 B (511.1 MiB) | −96,327,370 B |
| `FantasyDisk-<v>-macos.dmg` | 464,183,243 B | 559,696,549 B | −95,513,306 B |

macOS cold start of the **built app** (`measure_cold_start_app.sh`: the FAN-3973
method — `--print-fps --verbose --quit-after 600`, first `Project FPS` line minus
1 s — applied to the app binaries instead of editor + project; five back-to-back
launches per build; both builds run with an isolated `HOME` so the 0.3.0 reference
app never touches the owner's real user data; summary via
`evidence/FAN-3973/analyze_cold_start.py`, logs in `cold_start/`):

| Build | Runs | Median first frame (s) | Min | Max | Actor SpriteFrames before first frame |
| --- | --- | --- | --- | --- | --- |
| 0.3.0 app (from retained `v0.3.0` DMG) | 5 | 5.56 | 5.49 | 5.60 | 1 |
| **0.3.2 app (installed from retained DMG)** | 5 | **5.70** | 5.68 | 5.74 | 1 |

The built 0.3.2 app starts within 0.14 s of the 0.3.0 reference under the same
method, with the same single scene-dependency pack (`ally_druid_wolf`) loaded
before the first frame — the FAN-3973 state, not the 0.3.1 regression (8.09 s in
the editor-method FAN-3973 table, 17.4 s on Windows per FAN-3964). Absolute values
differ from the FAN-3973 editor-method table (3.08 s) because the exported binary
initializes differently from the editor-run project; the comparison here is
app-vs-app. Windows timing stays with FAN-3964.

## Candidate checks

- `python3 tools/scan_release_secrets.py evidence/FAN-3976` → passed.
- Identity fingerprint / certificate CN / team id / e-mail: 0 occurrences in the raw
  build log and in this directory.
- `python3 tools/quality_static_guard.py --changed-ref origin/dev` → see the handoff comment.
- Task worktree HEAD `36340c47…` (the tag commit) before and after; only
  `evidence/FAN-3976/**` is added.

## Limits and carried risk

- No native Windows check (macOS host). The Windows installer, `SHA256SUMS.txt` and
  `update-manifest.json` go to FAN-3964 through a verified split-part transfer only
  after the independent PASS on this card.
- Carried risk to FAN-3964: the M2/M3 texture-memory check and the 17-class /
  51-ultimate gameplay smoke are still unexecuted on Windows.
- Independent QA — not this report — decides acceptance.

## Files

- `package_manifest.json` — immutable package manifest (source pins, build command
  and timing, retained inventory, cross-checks, trust-channel lines, built-bytes checks).
- `extra_checks.json` — AC3 data (PCK exclusion, size deltas, cold start), prior-release
  untouched hashes, snapshot equality.
- `build_release.log` — sanitized milestone log (progress spam removed); `build_timing.txt`.
- `SHA256SUMS.txt`, `update-manifest.json`, `LOCAL_RELEASE.json`, `CHANGELOG-0.3.2.md` —
  byte copies of the retained files; `local_release_verify.json` — readback.
- `pre_build_ls_remote.txt`, `post_build_ls_remote.txt`, `prebuild_notary_history_exit.txt`,
  `notary_history_top2.txt`.
- `smoke_outputs.json`, `runtime_smoke_*.log`, `static_quality_report.json` — AC1 gates.
- `macos_pck_summary.md`, `windows_pck_summary.md`, `pck_0.3.2_macos.json`,
  `pck_0.3.2_windows.json`, `pck_0.3.1_windows_exe.json` — PCK tables.
- `cold_start/`, `cold_start_summary.md` — AC3 timing.
- `run_build.sh`, `run_smokes.py`, `make_evidence.py`, `list_pck.py`,
  `measure_cold_start_app.sh` — the exact scripts used.
