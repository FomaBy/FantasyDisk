# FAN-3989 — 0.3.1.1: signed exact-tag package, retained, new ultimate animations proven in the installed macOS app

Developer evidence (Claude Dev Fable `5c006dd4`, macOS development/signing
host, Apple M4 Pro, macOS 26 / Darwin 25.5, Godot `4.7.stable.official.5b4e0cb0f`
with the official 4.7 export templates). Nothing was published; `main` and
the tags were not changed; the only repository writes are under
`evidence/FAN-3989/**`. All commands below were run from the repository root
of the task worktree unless stated otherwise.

## 1. Source pins and release-input consistency (AC1)

- Remote `v0.3.1.1` = annotated tag object `a9e08364c0aaa0e588744d1dbc30b68e233da694`
  → commit S `01ee13687da712342964bcafebdb79c8a38b7d1e`, tree
  `039b17c52480bb27c28d723248a8b85d4418bb58` (= the tree FAN-3987/FAN-3988
  certified; the full certifying gate was therefore not rerun). Read with
  `git ls-remote` before the build, after the build and after the evidence
  push (`package/ls_remote_*.txt`, identical; `dev` = S, `main` `0a838117…`).
- Task worktree: `HEAD` = S, tree `039b17c5…`, `git status` clean before the
  build (the only untracked path afterwards is this directory).
- Release inputs in the tag: `release_version_mapping.py --version 0.3.1.1` →
  macOS short `0.3.1`, macOS build `1.3.11`, Windows `0.3.1.1` / `0.3.1.1`;
  `project.godot` `config/version="0.3.1.1"`; `CHANGELOG.md` section
  `## [0.3.1.1] — 2026-09-30`; `patch_notes_data.gd` entry `0.3.1.1`
  (2026-09-30); poster `assets/marketing/fantasydisk_0311_announcement.png`
  present (blob `51803688…` — by PM decision the same image as the 0.3.1
  poster under the new name); client channel label `MACOS_UPDATE_CHANNEL =
  "signed"`; `data/ultimates/presentation/` holds 17 documents. The build's
  own guards (`release_scope_guard`, `release_notes_visual_claims_guard`,
  channel label, required build inputs, `build_release.sh` byte-equal to the
  tag's copy) all passed inside the build.

## 2. Build (AC2)

`evidence/FAN-3989/run_build.sh` is the exact invocation:
`FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease
MACOS_SIGN_IDENTITY=<resolved locally from the keychain> tools/build_release.sh 0.3.1.1`.
`xcrun notarytool history --keychain-profile FantasyDiskRelease` exited 0
before the build (07:29:29Z) and again inside the script. The only
environment addition is `GIT_CONFIG_*` = `core.hooksPath=/dev/null` for the
build's own detached `/tmp` worktree, so the Multica workdir-lifecycle
`post-checkout` hook (a daemon-worktree clone optimisation, not a build
input) does not run there — the FAN-3963/3976/3980/3983 precedent.

- Started 2026-09-30T07:29:29Z, finished 07:41:02Z, exit 0 on the first
  attempt. Staging: detached worktree of the tag in `/tmp/fantasydisk-build-NhXp45/src`,
  removed by the script.
- Apple notarization **Accepted** for `FantasyDisk.app` and for the DMG;
  `stapler staple/validate` OK; `spctl` accepted, `source=Notarized Developer
  ID`; `hdiutil verify` VALID; `NSIS CRC OK (firstheader @ 38912, crc @
  438457153)`; `Release secret scan passed (3 artifact root(s))`;
  `local_release.py materialize` → `"status": "verified"`.
- Full sanitized log: `build_release.sanitized.log` (raw log 54,322 lines with
  the export's per-file "Storing File" lines collapsed to a count; signing
  identity, team ID and Apple ID placeholders — zero occurrences of the real
  values in this directory, checked by grep; `scan_release_secrets.py
  evidence/FAN-3989` passed).

## 3. Retained package (AC2, AC4)

`/Users/sergeyfomin/FantasyDisk/releases/v0.3.1.1/` (copies of the small
files under `package/`):

| file | size | SHA-256 |
|---|---|---|
| `FantasyDisk-0.3.1.1-macos.dmg` | 462,905,398 | `b57845e7a4f0cf0d78df1cea7b46da3ce92b193d12f228ed5d35241953fd8163` |
| `FantasyDisk-0.3.1.1-windows-setup.exe` | 438,457,157 | `c981cb533ae45de620ee2b760bc19b687add8772689aab7cb78fa805cf6050eb` |
| `SHA256SUMS.txt` | 200 | `622d8f5ccc7fe8fcb072f02a4173fa49d25ec4f169b17786a1d6a9c7cb479ad5` |
| `update-manifest.json` | 809 | `b77d8887a2d5718729e09e5a679423f3d44d99e1de0759da9887cff279b2e6b7` |
| `CHANGELOG-0.3.1.1.md` | 313 | `77539de8c1f16beca308de215a1f7c3f92971185a7deeb0f58ed65eb1c386f4b` |
| `fantasydisk_0311_announcement.png` | 95,930 | `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` |
| `LOCAL_RELEASE.json` | 1,965 | see `package_manifest.json` |

- `update-manifest.json`: `version` `0.3.1.1`, `schema_version` 1, asset
  names/sizes/SHA-256 equal to the retained files, URLs under
  `…/FantasyDisk-Releases/releases/download/v0.3.1.1/`.
- `CHANGELOG-0.3.1.1.md` is byte-identical to the build script's awk
  extraction of the `## [0.3.1.1]` section from the tag's `CHANGELOG.md`; the
  poster equals the tag blob.
- `LOCAL_RELEASE.json`: tag `v0.3.1.1`, `tag_commit` = S, `macos_channel`
  `signed`, `source_tree_sha256` `0613fb78…`, inventory as above.
- `project/` = `git archive v0.3.1.1` (`diff -rq` exit 0, 57,881 files each;
  `package/project_vs_git_archive.txt`); `godot-project/` present;
  `releases/current-project → v0.3.1.1/godot-project`, registered in
  `projects.cfg` with `favorite=true`.
- Readback: `local_release.py verify --version 0.3.1.1 --macos-channel signed
  --launch-smoke` → `"status": "verified"` (`package/local_release_verify.txt`).
- **Every built artifact hash differs from every retained package** (`v0.3.1`
  = FAN-3983 bytes, `archive/v0.3.1-attempt1-448a0cc1`, `archive/v0.3.1-attempt2-165f14aa`,
  `v0.3.2`, `v0.3.0`): `package/hash_difference_proof.json`,
  `all_built_artifacts_differ = true`. The single equal hash is the poster,
  which is by PM decision the unchanged 0.3.1 image under the new name
  (`6d0267c7…` in `v0.3.1` and `archive/v0.3.1-attempt2-165f14aa`).

## 4. Preservation of the retained packages

Recursive SHA-256 of every file under `releases/` (except `.DS_Store`):
590,497 files before the build (manifest SHA-256 `32b326f7…`), the same
590,497 files with the same manifest SHA-256 after the build and again after
every measurement (`preservation/README.md`,
`preservation_diff_after_build.txt` and `preservation_diff_final.txt` are
empty). `releases/v0.3.1` (160,109 files), both archives and `v0.3.2` kept
every byte; no file was renamed, relabeled or overwritten. The new package
went only to `releases/v0.3.1.1/`.

## 5. Installed app and trust (AC3)

`local_release.py materialize` installed `/Applications/FantasyDisk.app`
atomically from the retained DMG (the previous install was 0.3.1 / 1.3.10).

- `Info.plist`: `CFBundleShortVersionString` **0.3.1**, `CFBundleVersion`
  **1.3.11**; universal `x86_64 arm64`; hardened runtime; `codesign --verify
  --deep --strict` valid; stapler `The validate action worked!`; `spctl`
  accepted `source=Notarized Developer ID` (`package/trust_checks.txt`).
- DMG root: `FantasyDisk.app`, `Applications → /Applications`; the app in the
  mounted DMG passes the same checks and is file-for-file identical to the
  installed app (9 files, `package/dmg_app.sha256` = `package/installed_app.sha256`;
  PCK `0e4162544fe36ef62037278f58d9f3efd78a788dc85f54f2259723de47dff917`,
  423,942,800 B).
- **Main menu shows `v0.3.1.1`**: `main_menu/main_menu_v0.3.1.1_installed.png`
  (real `Main.tscn` inside a clone of the installed app, label
  `MainMenuVersionLabel: v0.3.1.1`, `main_menu/main_menu_capture.json`).

## 6. New animations in the built bytes (AC3)

### PCK contents, both platforms

`list_pck.py` (reuses the FAN-3985 probe's PCK directory reader; the Windows
PCK is carved from `FantasyDisk.exe` extracted read-only from the retained
Setup with `7z`, exe SHA-256 `9dba8666…`, 532,993,696 B, embedded PCK at
offset 109,050,880, 423,942,804 B): both tables have **27,034 entries**,
**17 `data/ultimates/presentation/*.json`**, **0** `docs/`, `evidence/`,
`skills/`, `tools/` or `tests/` entries; the tables are identical by path
and size, and 421 sampled entries (all presentation documents, every
`scripts/ultimates/**` entry and 200 `.gdc`) have identical content MD5
(`pck_tables_macos_vs_windows.json`, `pass: true`). Top-level:
`.godot` 13,062, `assets` 13,020, `scripts` 580, `scenes` 196, `data` 173,
`icon.svg`, `icon.svg.import`, `project.binary`; ultimate class packages:
51 `.gd.remap` + 51 `.gdc` + 36 `.tscn.remap`.

### FAN-3985 probe against the installed app (`installed_app_probe/`)

`tools/ultimate_export_probe.py --skip-export --captures` with
`<output-dir>/export/FantasyDisk.app` = a clone of `/Applications/FantasyDisk.app`.
macOS 26 kills and removes a Developer ID/notarized app whose bundle is
modified (the probe's `override.cfg`; the FAN-2199 behaviour — reproduced
here: SIGKILL after ~8 s and the clone directory gone), so the clone was
re-sealed ad-hoc (`codesign --force --deep --sign -`) before the probe; its
PCK is byte-identical to the installed app's
(`installed_app_probe/pck_hash_installed_vs_probe_input.txt`). The installed
app itself was not touched.

- `export_probe_summary.json`: **`pass: true`**, 159.5 s. Environment inside
  the probe: `editor_feature=false`, `template_feature=true`,
  `docs_manifest_present=false`, engine `4.7-stable (official)`.
- Headless probe: **51/51 pairs**, every pair `resolution_source =
  weapon_profile` (0 `legacy_class_fallback`), executor admitted, **`begin_ok
  = true`**, class-owned `scene_path` (`res://scenes/vfx/ultimates/<class>/…`)
  and the instantiated scene recorded (`export_probe_probe_report.json`).
- Mutation checks (non-vacuous): removing `data/ultimates/presentation/knight.json`
  → exit 1, the three Knight pairs `record_found=false`, `begin_ok=false`,
  48 others pass; removing `scripts/ultimates/classes/knight/long_spear.gd.remap`
  → `knight/long_spear` falls to `legacy_class_fallback`, 50 others pass.
- Player path (`export_probe_player_path.json`): all **51 pairs** played in
  their own fresh process of the installed app through
  `Main._start_combat()` → real `Player.activate_ultimate()` → executor,
  enemy deaths, victim impacts, authored presentation, past the declared
  cancel; exit code 0 for every pair, **0 crashes**; 17 real game-frame
  captures, one per class (`exported_app_player_path_captures/`).
- Presentation-runtime captures at the `active` beat, one weapon per class
  (`exported_app_captures/`, 17 PNGs, label burned into each frame with the
  pair, the resolved scene and the executable that rendered it).

## 7. Performance with the new scenes active (AC3)

`perf_ultimate_driver.gd` + `run_perf_in_app.py`: the FAN-3981 P2 window
(48 enemies kept alive, real `_start_combat` battle, FAN-3981 sampler) run
INSIDE a clone of the installed app (same launch mechanism as the probe,
isolated user dir `FantasyDiskFan3989Perf`, windowed 2560×1440, GL
Compatibility, vsync on), 60 s, the weapon ultimate cast every 8 s through
the real `Player.activate_ultimate()`. The shipped charge ledger allows one
activation per encounter (FAN-1460/FAN-2090), so before each cast the driver
calls the ledger's own `begin_encounter()` (what a new battle does) and
records it; the roster is spawned and settled before the window. The same
driver was run on the 0.3.1 app taken from the retained `v0.3.1` DMG
(`f391b86f…`, legacy path) for comparison. Tables: `perf/perf_tables.md`;
reports and per-run logs under `perf/<batch>/`.

| build | class/weapon | casts | avg FPS | 1 % low | >100 ms | longest | first-cast frame | later casts max | objects start → peak → end | pickups at end | peak texture MiB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.3.1.1 installed | berserk/sword | 8/8 | 110 | 24 | 1 | 1048 ms | 1048 ms | 36 ms | 3,056 → 8,213 → 8,008 | n/a (pre-breakdown run) | 1,404 |
| 0.3.1.1 installed | druid/summon_amulet | 8/8 | 109 | 24 | 1 | 1117 ms | 1117 ms | 32 ms | 3,252 → 10,671 → 10,621 | n/a | 1,476 |
| 0.3.1.1 installed | knight/long_spear | 8/8 | 95 | 24 | 1 | 1160 ms | 1160 ms | 35 ms | 2,960 → 3,787 → 3,428 | 125 | 1,395 |
| 0.3.1.1 installed | priest/priest_reliquary | 4/8 | 104 | 24 | 1 | 1142 ms | 1142 ms | 36 ms | 3,892 → 5,837 → 5,531 | 358 | 1,420 |
| 0.3.1 reference | berserk/sword (legacy) | 8/8 | 103 | 24 | 1 | 1074 ms | 1074 ms | 27 ms | 3,052 → 4,348 → 4,176 | 347 | 1,392 |
| 0.3.1 reference | druid/summon_amulet (legacy) | 8/8 | 102 | 24 | 1 | 1079 ms | 1079 ms | 41 ms | 3,237 → 3,563 → 3,558 | 20 | 1,473 |
| 0.3.1.1 installed, rerun | berserk/sword | 8/8 | 112 | 99 | 0 | 54 ms | 27 ms | 51 ms | 3,054 → 8,391 → 8,021 | 2,263 | 1,404 |
| 0.3.1.1 installed, rerun | druid/summon_amulet | 8/8 | 107 | 85 | 0 | 46 ms | 30 ms | 46 ms | 3,256 → 10,710 → 10,708 | 3,583 | 1,476 |
| 0.3.1.1 installed, priest cast every 16 s | priest/priest_reliquary | 4/4 | 106 | 95 | 0 | 37 ms | 34 ms | 26 ms | 3,979 → 5,765 → 4,576 | 336 | 1,419 |
| 0.3.1.1 installed, fresh profile, 30 s | berserk/sword | 4/4 | 102 | 91 | 0 | 43 ms | 37 ms | 37 ms | 3,058 → 6,808 → 6,209 | 1,577 | 1,404 |
| 0.3.1.1 installed, 30 s | berserk/sword | 4/4 | 108 | 99 | 0 | 39 ms | 37 ms | 33 ms | 3,071 → 6,251 → 5,588 | 1,341 | 1,404 |

Reading the numbers against the limits:

- **Frame time / 1 % low (M1: 1 % low ≥ 45 target, < 30 red).** With the
  new scenes active the ultimate itself costs 16–51 ms on its cast frame and
  nothing measurable afterwards (average 95–112 FPS, 1 % low 85–99 in every
  run without the batch-1 event below; 0.3.1 legacy: 27–41 ms per cast).
  **Batch-1 event, not attributable to the new scenes:** the first six
  processes (four 0.3.1.1 and both 0.3.1 reference runs, 07:54–08:01Z) each
  had exactly one 1.05–1.16 s frame at the *first* ultimate activation, which
  alone makes their 1 % low 24 (one second of 60 at 24 FPS). It occurred
  identically on 0.3.1's legacy path, and five later processes (fresh clone,
  the profile's `shader_cache` cleared — the GL renderer had written no cache
  files anyway — and a completely fresh profile) did not reproduce it
  (first cast 27–37 ms). The cause was not isolated on this host; it is
  reported for the Windows verification to watch the first activation.
- **`Performance.OBJECT_COUNT` (FAN-3981 hard limit P2 ≤ 6,250; checklist
  target ≤ 5,000).** Knight and Priest stay at 3,4–5,8k for the whole window
  (peaks 3,787 / 5,837 / 5,765; Priest's higher start is its battle-prayer
  UI). Berserk and Druid climb to 8,0–10,7k: the end-of-window scene-tree
  breakdown (`phase.tree_breakdown` in the rerun reports) shows the growth is
  **`res://scenes/Pickup.tscn` drops** — 2,263 (Berserk) and 3,583 (Druid)
  pickup nodes, i.e. loot from the 48 enemies the new ultimates kill on every
  cast (alive falls to 0 after each Berserk/Druid cast, then the driver
  respawns 48) that a stationary scripted player never collects; ≈2 engine
  objects per pickup account for the whole rise (Berserk 7,713 − 3,054 ≈
  2 × 2,263). The 0.3.1 legacy Berserk kills fewer per cast (alive stays 48)
  and leaves 347 pickups. Nothing of the ultimate runtime accumulates: after
  the run, back at the main menu with 0 resident packs, every build sits at
  2,289–2,436 objects (0.3.1: 2,321–2,324). So the P2 count with the new
  scenes and normal kill rates is within the target (Knight 3,787, Priest
  5,765 ≤ 6,250 hard, Priest above the 5,000 target only with its prayer UI
  and 336 uncollected drops), and the >6,250 readings are the uncollected loot
  of this scenario, not a leak — a caveat for the Windows verification's own
  P2 scenario, where the player moves and collects.
- **Priest 4/8 casts with 8-s spacing** — `ready_runtime_rejected`: the
  Sanctum Judgment presentation is still running 8 s after activation and the
  runtime refuses a second activation while one is active (shipped
  behaviour); with 16-s spacing 4/4 casts activate.
- Texture memory peak (act 1): 1,395–1,476 MiB, the FAN-3977/FAN-3983 values
  (≤ 1.5 GiB); resident full-frame packs 23 (28 with the Druid's summons)
  throughout, released after the run.
- Every 0.3.1.1 run: `resolution_source = weapon_profile` and the class-owned
  scene instantiated on each cast (`instantiated_scenes` in each report);
  one real game frame per run in `perf/<batch>/captures/`.

### Cold start (M4, `cold_start/`)

`measure_cold_start_app.sh` (FAN-3973/FAN-3983 method on the app binary:
`--print-fps --verbose --quit-after 600`, wall-clock timestamps, first
`Project FPS` line − 1 s, isolated `HOME`), five launches each, alternating
installed 0.3.1.1 and the 0.3.1 reference app:

| build | median first frame (s) | min | max |
|---|---|---|---|
| 0.3.1.1 installed | **6.09** | 5.88 | 7.70 |
| 0.3.1 (retained DMG app) | 5.85 | 5.72 | 8.23 |

Unchanged within the run-to-run spread (FAN-3983 measured 5.65 vs 5.55 for
0.3.1 vs 0.3.0 on this host); no errors in the launch logs.

## 8. Saves (AC4)

`~/Library/Application Support/Godot/app_userdata/FantasyDisk` (5,628 files
excluding `logs/`, `shader_cache/`, `vulkan/`): identical SHA-256 manifests
before the build, after the install + launch smoke, and after every probe
and measurement (`saves/*.sha256`); the six `*.cfg` (including
`fantasydisk_meta.cfg`, `fantasydisk_autosave.cfg`, `settings.cfg`) unchanged.
Probes and perf runs used the isolated user directories
`FantasyDiskFan3985Probe` / `FantasyDiskFan3989Perf`.

## 9. Early transfer to FAN-3990 (AC5, `transfer/`)

`split -b 50000000 -a 2` → 9 parts (8 × 50,000,000 B + 38,457,157 B),
`PARTS.sha256` (SHA-256 `56ac0d13…`); `cat part-* | shasum -a 256` =
`c981cb53…` = the retained Setup = the `SHA256SUMS.txt` line. Posted on
FAN-3990 as comment `01a0f146-6947-72b8-bf27-491c999bbd4d` with the 9 parts,
`PARTS.sha256`, `SHA256SUMS.txt` and `update-manifest.json`, marked "package
review pending" (`transfer/fan3990_transfer_post.json`, attachment IDs).
Read back: `PARTS.sha256` and `part-ai` downloaded again and byte-equal to
the local files (`transfer/split_and_readback.txt`).

## 10. Files

- `run_build.sh`, `build_release.sanitized.log`, `package/` (LOCAL_RELEASE,
  SHA256SUMS, update-manifest, CHANGELOG, trust checks, verify readback,
  app file hashes, ls-remote before/after, hash-difference proof, Windows exe
  hash), `package_manifest.json` (`build_package_manifest.py`).
- `preservation/` — manifest summary, top-level retained package hashes,
  empty diffs after build and final.
- `installed_app_probe/` — FAN-3985 probe output against the installed app.
- `list_pck.py`, `pck_tables_macos_vs_windows.json`.
- `perf_ultimate_driver.gd`, `run_perf_in_app.py`, `perf_table.py`, `perf/`.
- `measure_cold_start_app.sh`, `analyze_cold_start.py`, `cold_start/`.
- `main_menu_capture.gd`, `main_menu/`.
- `saves/`, `transfer/`.

## Limitations

- Native Windows verification is FAN-3990's (same Setup bytes `c981cb53…`).
- The probe and perf clones had to be re-sealed ad-hoc to launch on macOS 26;
  the installed app and the retained DMG were verified with their Developer
  ID signature intact and the clones' PCK bytes are identical to the
  installed app's.
- The batch-1 first-activation frame (§7) is recorded, not explained.
- The scripted combat keeps the player stationary and resets the charge
  ledger per cast; object counts include the resulting uncollected loot.
