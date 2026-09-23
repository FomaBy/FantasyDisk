# FAN-3963 early exact-tag package capability preflight — 2026-09-23

Read-only capability preflight for the FantasyDisk 0.3.1 package on the MacBook
host. Nothing was tagged, built, exported, staged, installed, published or
credential-mutated. No identity, team, profile, Apple ID or secret value is
recorded here or in `preflight_manifest.json`; only counts, dates, hashes and
pass/fail results. This stage does not satisfy the package acceptance; the final
build still depends on terminal FAN-3962 and the `v0.3.1` tag.

Summary verdict: the host toolchain, export templates, NSIS, Apple tooling,
Developer ID identity, durable release target and disk budget are all in place.
Two conditions must be resolved before the final signed tag build can succeed:
the release poster file name on the FAN-3961 candidate does not match the
build tooling, and no notarytool keychain profile is discoverable, so the
signed channel's credential gate would currently refuse to build (fail-closed,
no unsigned downgrade). Details follow.

## 1. Source and release-input state (reused accepted evidence)

- `origin/dev` = `e33bded444e301919dc93c8c9b9f0257e640a1ea`, tree
  `9a8401ca1a6dda8a4b446fe45de3fa4f97074426`; FAN-3877 holds an independent
  PASSED holistic certification of this exact commit.
- `tools/release_version_mapping.py --version 0.3.1` FAILS on `origin/dev`
  because `project.godot` / `export_presets.cfg` still carry 0.3.0. This is the
  expected dependency on FAN-3961, not a toolchain defect.
- FAN-3961 release-input candidate `3f82abace4953414a72922f7e99997db6d556b96`
  (tree `f7ed06cea7cc28658fbd77d037ad11ae542c5813`, base is `origin/dev`):
  version mapping PASSES (`0.3.1 / 1.3.10 / 0.3.1 / 0.3.1.0`), `CHANGELOG.md`
  has `## [0.3.1] — 2026-09-23` with an empty `Unreleased`, and
  `scripts/update_manager.gd` labels the macOS channel `signed`. Its independent
  QA verdict is FAILED on the Assassin capture-applicability gate and the card is
  in bounded rework; that verdict is preserved, not re-judged here.
- All 16 build inputs enumerated by `tools/build_release.sh` are present on
  both `dev` and the candidate; 15 are byte-identical, `export_presets.cfg`
  differs only by the version fields. `custom_template/*` is empty in both
  presets, so the default 4.7 templates are used.
- Tags: `origin` has no `v0.3.1` (`git ls-remote` empty). `v0.3.0` peels to
  `fd9fd1a4fa16f3f6ebc8eba063eb03871513cecb`; `origin/main` is
  `02f358149d08b3cbe895ca87847452836d1e3c70` (the 0.3.0 release merge).

## 2. Toolchain

| Component | Result |
| --- | --- |
| Godot | `4.7.stable.official.5b4e0cb0f` at the script default path; 346,722,704 bytes; SHA-256 `445c6f95…3a80f` (full hash in manifest). Project feature `4.7`. |
| Export templates | `4.7.stable` installed; `macos.zip` 123,345,600 bytes (10 entries), `windows_release_x86_64.exe` 109,160,448 bytes; hashes in manifest. Matches the binary version. |
| NSIS | `makensis v3.12` (Homebrew), Unicode, CRC support; `tools/windows_installer.nsi` needs no extra includes, uses `SetCompressor zlib`, `CRCCheck on`. |
| Apple tools | `codesign`, `xcrun` 72, `notarytool 1.1.2 (41)`, `stapler`, `spctl`, `hdiutil`, `ditto`, `sips` present. Developer dir is Command Line Tools (no full Xcode), which was sufficient for the retained 0.3.0 signed release. |
| Host | macOS 26.5.1 (25F80), Python 3.9.6, `en_US.UTF-8` locale available (required by makensis), git-lfs 3.7.1; no build input is LFS-tracked. |

## 3. Signed macOS channel capability (default channel kept)

- Developer ID Application identities installed and valid: **1**. Certificate
  `notAfter` = 2031-08-11 (read from Keychain; identity not recorded).
- `MACOS_SIGN_IDENTITY` and `MACOS_NOTARY_PROFILE`: unset in this runtime.
- notarytool keychain profile items found: login 0, openvpn 0, System 0.
  Authentication with Apple was therefore **not exercised**; the build script's
  gate (`xcrun notarytool history --keychain-profile …`) cannot run without a
  configured profile name and none may be invented.
- Consequence today: `FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh
  0.3.1` would exit 2 at the credential gate before touching any worktree.
  This is the intended fail-closed behavior; unsigned was not selected and the
  client label stays `signed`.
- Prior proof on this host: `/Applications/FantasyDisk.app` 0.3.0 (build 1.3.0)
  passes `codesign --verify --deep --strict`, `stapler validate` and
  `spctl --assess --type execute` (`source=Notarized Developer ID`); the retained
  `releases/v0.3.0/LOCAL_RELEASE.json` records `macos_channel: signed`.

## 4. Durable local target

- `~/.config/fantasydisk/release.json` resolves `local_root =
  /Users/sergeyfomin/FantasyDisk`, `macos_app = /Applications/FantasyDisk.app`,
  and the Godot `projects.cfg` path.
- `releases/` holds retained `v0.3.0` (dmg 432,476,946 B; setup
  408,114,374 B; poster 1,099,252 B; `project/` 2,998,588 KB; `godot-project/`
  3,463,272 KB; total 7,283,872 KB), `current-project -> v0.3.0/godot-project`
  with `favorite=true` in `projects.cfg`, plus three historical
  rejected/quarantine/registration directories. `releases/v0.3.1` does not
  exist, so atomic materialization has no overwrite conflict.

## 5. Disk budget (measured)

All paths involved (durable root, `/tmp` build worktree, HOME, task workdir,
`/Applications`) sit on one volume, `/dev/disk3s5`.

| Item | Bytes |
| --- | ---: |
| Available now | 365,084,274,688 |
| Required estimate (worktree checkout + import cache + staging artifacts + materialized release root + app install) | 15,401,214,880 |
| Required with 2× margin | 30,802,429,760 |
| Headroom ratio | 23.7× |

Basis: task worktree `du` (3,390,296 KB), local-root `.godot` cache
(596,856 KB), and the retained 0.3.0 package/project sizes scaled 1:1.
`local_release.py` performs no disk check of its own. Verdict: sufficient.

## 6. Mandatory package files for 0.3.1

Release dir (only these, no raw Windows exe/zip):
`FantasyDisk-0.3.1-macos.dmg`, `FantasyDisk-0.3.1-windows-setup.exe`,
`SHA256SUMS.txt`, `CHANGELOG-0.3.1.md`, `fantasydisk_031_announcement.png`,
`update-manifest.json` (schema 1, `minimum_supported_version` 0.2.2, asset URLs
`https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.3.1/<asset>`).
Retained root adds `LOCAL_RELEASE.json`, `project/` (exact `git archive` of
`v0.3.1`), `godot-project/`, and repoints `releases/current-project`.
The tag path emits no `CANDIDATE_PROVENANCE.json`.

## 7. Blocking findings for the final build

1. **Poster file name mismatch (must fix before tag).** The FAN-3961 candidate
   ships `assets/marketing/fantasydisk_0.3.1_announcement.png`, but
   `tools/build_release.sh:548`, `local_release.py:324`,
   `github_release_verify.py:152`, `telegram_publish.py:113` and
   `release_publish.py:104` all require `fantasydisk_031_announcement.png`
   (dots stripped, as `fantasydisk_030_announcement.png` for 0.3.0).
   `build_release.sh` checks the poster only after export, signing,
   notarization and NSIS, so the tag build would fail late and waste an Apple
   notarization round-trip. Owner: FAN-3961 rework or a pre-tag source fix
   under FAN-3962.
2. **Notary profile not discoverable.** The operator must provide
   `MACOS_SIGN_IDENTITY` (matching the single installed Developer ID
   Application identity) and `MACOS_NOTARY_PROFILE` (a keychain profile that
   passes `xcrun notarytool history`) at build time. Agents must not create,
   name or print these values.
3. **Release inputs pending (expected).** `origin/dev` is still 0.3.0; FAN-3961
   must land the accepted inputs and FAN-3962 must promote and tag `v0.3.1`.

## 8. Exact-tag build and verification sequence (future stage, not run)

Preconditions: FAN-3962 terminal with `v0.3.1` on `origin`; clean task
worktree on the build checkout; `git fetch origin tag v0.3.1` and confirm
`git rev-parse v0.3.1^{commit}` equals the peeled `git ls-remote origin
refs/tags/v0.3.1` value and FAN-3962's recorded commit/tree (the shared cache
already holds a divergent local `v0.2.4`, so never trust cached tags);
poster name fixed; six core smoke suites and the certifying gate green on the
tag commit; `MACOS_SIGN_IDENTITY` / `MACOS_NOTARY_PROFILE` exported by the
operator; `FANTASYDISK_MACOS_CHANNEL=signed` (default).

Command: `FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh 0.3.1`,
which in order: validates channel and credentials (identity present, notarytool
authenticates) → resolves `v0.3.1` and adds a detached `/tmp` worktree →
checks all 16 build inputs and that the running `build_release.sh` equals the
tag's → assembles `changelog.d` fragments if present → version mapping →
release scope guard → visual-claims guard → client channel label equals
`signed` → headless import → macOS export (universal .app zip) → materialize
.app, add 720×480 Finder background, `xattr -cr` → Developer ID sign (hardened
runtime, timestamp), `codesign --verify --deep --strict` → notarize app
(`Accepted`), staple, validate, `spctl` → `create_macos_dmg.sh` (Applications
alias, `hdiutil verify`, layout check) → sign, notarize, staple, validate,
`spctl` the DMG → Windows export (x86_64, embed_pck) → `makensis` →
exact NSIS CRC check → read-only DMG mount: signature, staple, `spctl`,
Applications link → secret scan of DMG mount, raw exe and setup exe →
copy DMG/setup/`CHANGELOG-0.3.1.md`/poster → `SHA256SUMS.txt` →
`update-manifest.json` → `local_release.py materialize --version 0.3.1
--macos-channel signed` (atomic `releases/v0.3.1/`, `git archive` snapshot,
`LOCAL_RELEASE.json` inventory hashes, `current-project` + Godot
registration, atomic install to `/Applications/FantasyDisk.app`, readback
verification incl. `hdiutil verify`, headless launch smoke, codesign, stapler,
spctl).

Post-build evidence to publish under `evidence/FAN-3963/**`: tag commit/tree,
build command and exit status, package inventory with sizes and SHA-256 (must
equal `SHA256SUMS.txt`, `update-manifest.json` and `LOCAL_RELEASE.json`),
notarization `Accepted` results for app and DMG, NSIS CRC line, secret-scan
result, retained path readback, and `local_release.py verify` output.
Independent QA then verifies the retained package and source identity.
