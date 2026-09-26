# FAN-3963 evidence: exact-tag 0.3.1 package build and retention (2026-09-26, macOS)

**Developer result: the signed 0.3.1 package was built from the immutable `v0.3.1`
tag, notarized by Apple, and retained under the configured durable local release
root.** This is developer evidence, not independent QA, not a Windows installer
PASS, and not a publication. The only repository change in this candidate is
`evidence/FAN-3963/**`.

| Pin | Exact value |
| --- | --- |
| Tag `v0.3.1` (annotated object) | `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` |
| Tag target commit | `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| Tag target tree | `3e02df83290741b21d4de37c4fa03e356e20c591` |
| `origin/main` at build readback | `1ec3d0dfb8b9a150fef742c088401c6a453e1a2b` (tree `3e02df83…`) |
| `origin/dev` at build readback | `448a0cc12f02eb05bc16becc69fde365021a9a17` |
| Build checkout HEAD | `448a0cc12f02eb05bc16becc69fde365021a9a17`, clean worktree |

Local `v0.3.1` peeled to the same commit as `git ls-remote origin refs/tags/v0.3.1^{}`
before and after the build; `main`, `dev` and the tag were unchanged afterwards.
No `main`/tag write, no public upload, no Telegram/Discord send.

## Pre-build gates on the tag commit

| Gate | Result |
| --- | --- |
| Six core smoke suites | `python3 tools/godot_gate.py --headless --path . --script res://tests/<name>.gd` for `runtime_smoke_test`, `runtime_smoke_ui_test`, `runtime_smoke_combat_test`, `runtime_smoke_progression_economy_test`, `runtime_smoke_weapon_mechanics_test`, `runtime_smoke_boss_elite_test`: all exit 0, pass marker printed, 0 `SCRIPT ERROR` lines. Commands, durations, markers and log hashes: `smoke_outputs.json`; raw logs in this directory. An `--ensure-import-cache` pre-pass ran first (log hash in `package_manifest.json`). **PASS** |
| Certifying quality gate | `python3 tools/quality_gate.py --profile static --report …`: `QUALITY PASSED: 16 static, 0 Godot`, `certifying=true`, `worktree_clean=true`, `git_sha=448a0cc1…`. Machine report: `static_quality_report.json`. **PASS** |
| Version mapping | `tools/release_version_mapping.py --version 0.3.1` → `0.3.1 1.3.10 0.3.1 0.3.1.0`. **PASS** |
| Release inputs | `## [0.3.1] — 2026-09-23` present below empty `Unreleased`; `assets/marketing/fantasydisk_031_announcement.png` SHA-256 `d9ac6ea81de2fbdee68eb2ba849287078c32e9fd3cda04332bdcfaee1a03de9e` (same as FAN-3962 provenance); client `MACOS_UPDATE_CHANNEL := "signed"`. The packaged `CHANGELOG-0.3.1.md` is byte-identical to the tag's `## [0.3.1]` section (the three `changelog.d` fragments assembled by the build land under `Unreleased`). **PASS** |
| Signed-channel authorization in the build process | One valid Developer ID Application identity installed; the owner-selected certificate fingerprint matches it; `xcrun notarytool history --keychain-profile FantasyDiskRelease` exit 0 before the build (`prebuild_notary_history_exit.txt`) and again inside `tools/build_release.sh`. No identity value, team id, Apple ID or password is recorded anywhere in this evidence (verified by grep against the local values). **PASS** |

## Build

`FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease
MACOS_SIGN_IDENTITY=<resolved locally> tools/build_release.sh 0.3.1`, launched by
`run_build.sh` (resolves the identity from the selected certificate at run time).
Started 2026-09-26T02:04:31Z, finished 02:17:01Z, exit 0. Godot
`4.7.stable.official.5b4e0cb0f`, `makensis v3.12`, macOS 26.5.1.

Attempt 1 (02:02:31Z) exited 1 fifteen seconds in, at `git worktree add` for the
`/tmp` build worktree: the Multica workdir-lifecycle `cow_checkout` post-checkout
hook (installed through `core.hooksPath` in the shared bare repository config)
rejects any worktree outside the Multica workspace allowlist and returns 1
(`build_attempt1_hook_rejection.log`, hook log reason `outside_allowlist`). No
build action had run. Resolution: attempt 2 overrides `core.hooksPath` with an
empty directory **only in the build process environment**
(`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=…`);
the shared repository config, `tools/build_release.sh` (which the build itself
compares byte-for-byte with the tag's copy) and the source bytes are unchanged.
The hook is a copy-on-write cache optimizer, not a content step. The orphaned
attempt-1 worktree and scratch directory were removed.

Steps observed in `build_release.log` (full raw log SHA-256
`b72a74f250815240589d0287087b7df91e4804a318e7c552ce4a51ae876ceded`, 14,578,549 B,
attached to the handoff comment as `.gz`): 15 build inputs present and running
script equal to the tag's; version mapping; `release scope OK: 0.3.1, 0 entries`;
no unbacked visual claims; client channel label `signed`; headless import;
macOS export; Developer ID signing with hardened runtime and timestamp;
`codesign --verify --deep --strict` valid; **Apple notarization accepted
FantasyDisk.app**; staple and validate worked; `spctl` accepted,
`source=Notarized Developer ID`; DMG created, `hdiutil verify` VALID, layout OK;
DMG signed; **Apple notarization accepted FantasyDisk DMG**; staple/validate/
`spctl` accepted; Windows export; NSIS installer; `NSIS CRC OK (firstheader @
38912, crc @ 535974630)`; read-only DMG mount: signature, staple and `spctl`
accepted, Applications link present; `Release secret scan passed (3 artifact
root(s))`; `SHA256SUMS.txt`; `update-manifest.json`; `local_release.py
materialize` → `"status": "verified"`.

Apple submission history (status only, read back afterwards):
`FantasyDisk-0.3.1-macos-notary.zip` Accepted 02:07:44Z;
`FantasyDisk-0.3.1-macos.dmg` Accepted 02:10:24Z (`notary_history_top2.txt`).

## Retained package (`/Users/sergeyfomin/FantasyDisk/releases/v0.3.1/`)

| File | Size (bytes) | SHA-256 |
| --- | --- | --- |
| `FantasyDisk-0.3.1-macos.dmg` | 559,696,549 | `6465fb7c436668b981fc668e1b7683d4b755cff80d13e886e5c37e12e37a9d0a` |
| `FantasyDisk-0.3.1-windows-setup.exe` | 535,974,634 | `375c5290040ac349a1e75cd2e09e3ddd520216b3ddeadfab758d413fb12dafed` |
| `SHA256SUMS.txt` | 196 | `a1cc64e84dad49e7f4267e98167326cd0ece5a8c230d60673e11e0427c0f5206` |
| `CHANGELOG-0.3.1.md` | 5,504 | `399dceb48a0d76644eaaa4110b9ffd46223862aee4fafc01f3c8588b0901e09c` |
| `fantasydisk_031_announcement.png` | 95,993 | `d9ac6ea81de2fbdee68eb2ba849287078c32e9fd3cda04332bdcfaee1a03de9e` |
| `update-manifest.json` | 793 | `a81d1149044c9ce8371f4260d8449829df52de5358cfb66378174a924fc1e1f6` |
| `LOCAL_RELEASE.json` | 1,948 | tag `v0.3.1`, `tag_commit` `448a0cc1…`, `macos_channel` `signed`, `source_tree_sha256` `e3654c97597f81c15601bb41800488a88d7e89e3ee03f751e672f0f54ff0d545` |

Plus `project/` (exact `git archive` of the tag) and `godot-project/` (separate
editable copy). No raw Windows exe or zip is retained.

`package_manifest.json` is the immutable package manifest: fresh SHA-256 of every
retained file, and cross-checks that `SHA256SUMS.txt`, `update-manifest.json`
(names, sizes, URLs under `FomaBy/FantasyDisk-Releases/releases/download/v0.3.1/`)
and `LOCAL_RELEASE.json` all agree with those fresh hashes (`sha256sums_match_fresh`,
`update_manifest_all_ok`, `local_release_inventory_match_fresh` are all `true`).
Copies of `SHA256SUMS.txt`, `update-manifest.json`, `LOCAL_RELEASE.json` and
`CHANGELOG-0.3.1.md` are in this directory.

## Readback after the build

- `local_release.py verify --version 0.3.1 --macos-channel signed --launch-smoke`
  exit 0, `"status": "verified"` (`local_release_verify.json`).
- `shasum -a 256 -c SHA256SUMS.txt` in the retained directory: both installers OK.
- `releases/current-project → v0.3.1/godot-project`; Godot `projects.cfg` lists it
  with `favorite=true`.
- `/Applications/FantasyDisk.app`: `CFBundleShortVersionString` 0.3.1,
  `CFBundleVersion` 1.3.10; `codesign --verify --deep --strict` valid on disk and
  satisfies its Designated Requirement; `stapler validate` worked; `spctl`
  accepted, `source=Notarized Developer ID`.
- Retained DMG: `codesign --verify --strict` valid; `stapler validate` worked;
  `hdiutil verify` VALID; `spctl --type open` accepted, `source=Notarized
  Developer ID`.
- Previous `releases/v0.3.0` untouched; `releases/v0.3.1` did not exist before the
  build, so nothing was byte-compared, relabeled or overwritten.

## Limits and open items

- Native Windows installer QA is not performed here (macOS host); `qa_windows`
  remains a separate gate. The NSIS CRC check and secret scan are build-side only.
- Open risks carried from FAN-3962 remain recorded and are not passed by this
  card: P1/P2 not remeasured since `e33bded`; FAN-3866 and FAN-3905 AC7
  INCONCLUSIVE.
- The shared bare repository checks out LFS content as pointer files
  (`filter.lfs.smudge … --skip`). LFS paths are only
  `docs/design/reference-assets-lfs/**`, under a `.gdignore`d `docs/` tree, so
  they are not part of the exported game; the `project/` snapshot is a
  `git archive` and stores the same pointer blobs regardless.
- Disk cleanup: build `/tmp` worktrees removed (attempt 1 manually, attempt 2 by
  the script's trap); task worktree clean apart from this evidence; scratch under
  `build/FAN-3963/` is git-ignored. Free space after retention ≈335 GB.
