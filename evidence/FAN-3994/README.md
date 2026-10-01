# FAN-3994 — 0.3.1.2: signed exact-tag package, retained, FAN-3991 fix and new ultimate animations proven in the installed macOS app

Developer evidence (Claude Dev Fable `5c006dd4`, macOS development/signing
host, Apple M4 Pro, macOS 26 / Darwin 25.5, Godot `4.7.stable.official.5b4e0cb0f`
with the official 4.7 export templates). Nothing was published; `main` and
the tags were not changed; the only repository writes are under
`evidence/FAN-3994/**`. All commands below were run from the repository root
of the task worktree unless stated otherwise. Layout and method follow the
FAN-3989 (0.3.1.1) evidence; the long-session check (§7) is new.

## 1. Source pins and release-input consistency (AC1)

- FAN-3993 is `done` (QA PASSED, candidate `27540dcb…`). Remote `v0.3.1.2` =
  annotated tag object `eaf68a1d335e577087e2c570c19e84792bdbb332` → commit S
  `9a19870a15d71bc2b63e622c7895519bd84dafb4`, tree
  `05fc714ce1599d85ee01fc13dc8afbfca449d157` (= the tree FAN-3992/FAN-3993
  certified; the full certifying gate was therefore not rerun). Read with
  `git ls-remote` before and after the build (`package/ls_remote_*.txt`,
  identical; `dev` = S, `main` `7d5117f2…` with the same tree).
- Task worktree: `HEAD` = S, tree `05fc714c…`, `git status` clean before the
  build (the only untracked path afterwards is this directory).
- Release inputs in the tag: `release_version_mapping.py --version 0.3.1.2` →
  macOS short `0.3.1`, macOS build `1.3.12`, Windows `0.3.1.2` / `0.3.1.2`;
  `project.godot` `config/version="0.3.1.2"`; `export_presets.cfg`
  `short_version="0.3.1"`, `version="1.3.12"`, `file_version` /
  `product_version` `0.3.1.2`; `CHANGELOG.md` section `## [0.3.1.2] —
  2026-09-30` (assembled from 3 `changelog.d` fragments inside the build);
  poster `assets/marketing/fantasydisk_0312_announcement.png` present (by PM
  decision the unchanged 0.3.1 image under the new name, `6d0267c7…`);
  client channel label `MACOS_UPDATE_CHANNEL = "signed"`;
  `data/ultimates/presentation/` holds 17 documents. The build's own guards
  (release scope, release-notes visual claims, channel label, required build
  inputs, `build_release.sh` byte-equal to the tag's copy) all passed inside
  the build.

## 2. Build (AC2)

`run_build.sh` is the exact invocation: `FANTASYDISK_MACOS_CHANNEL=signed
MACOS_NOTARY_PROFILE=FantasyDiskRelease MACOS_SIGN_IDENTITY=<resolved locally
from the keychain> tools/build_release.sh 0.3.1.2`. `xcrun notarytool history
--keychain-profile FantasyDiskRelease` exited 0 before the build (14:30:49Z)
and again inside the script. The only environment addition is
`GIT_CONFIG_*` = `core.hooksPath=/dev/null` for the build's own detached
`/tmp` worktree (the FAN-3963/3976/3980/3983/3989 precedent: the Multica
workdir-lifecycle `post-checkout` hook is a daemon-worktree optimisation, not
a build input).

- Started 2026-10-01T14:30:49Z, finished 14:42:01Z, exit 0 on the first
  attempt. Staging: detached worktree of the tag in
  `/tmp/fantasydisk-build-1tyLKY/src`, removed by the script.
- Apple notarization **Accepted** for `FantasyDisk.app` and for the DMG;
  `stapler staple/validate` OK; `spctl` accepted, `source=Notarized Developer
  ID`; `hdiutil verify` VALID; `NSIS CRC OK (firstheader @ 38912, crc @
  438450169)`; `Release secret scan passed (3 artifact root(s))`;
  `local_release.py materialize` → `"status": "verified"`.
- Full sanitized log: `build_release.sanitized.log` (raw log 54,325 lines
  with the export's per-file "Storing File" / checkout progress lines
  collapsed to a count; signing identity, team ID and Apple ID placeholders —
  zero occurrences of the real values in this directory, checked by grep and
  `scan_release_secrets.py evidence/FAN-3994` passed).

## 3. Retained package (AC2, AC4)

`/Users/sergeyfomin/FantasyDisk/releases/v0.3.1.2/` (copies of the small
files under `package/`, full listing `package/retained_inventory.txt`):

| file | size | SHA-256 |
|---|---|---|
| `FantasyDisk-0.3.1.2-macos.dmg` | 462,843,679 | `3a803d9ff79515594a5b89ab9ca4bf3d19e913cc27dd44ef28c75f8e0ae67dd0` |
| `FantasyDisk-0.3.1.2-windows-setup.exe` | 438,450,173 | `162740c47c8b0c32e068d454909d8dd68e9e0871ab427c7b1af7301bfac74bd5` |
| `SHA256SUMS.txt` | 200 | `d7b19b4fc7da2dfa74da7940c3b9d514250ad9aa6e4500ebc87456ab1714d763` |
| `update-manifest.json` | 809 | `e70d0e593e944df0392695ed588326070ce01a0e8770880ae2fed6277350e936` |
| `CHANGELOG-0.3.1.2.md` | 697 | `c9b588f056740fb884a1ee081bd0dc3d45b04b2ae36964f68652b9ea44fe9d45` |
| `fantasydisk_0312_announcement.png` | 95,930 | `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` |
| `LOCAL_RELEASE.json` | 1,965 | `3b5da617cdfaadc2ab26129ae97a84cdb174a45dd60ccf673c315a61c17c04a7` |

- `update-manifest.json`: `version` `0.3.1.2`, `schema_version` 1,
  `minimum_supported_version` `0.2.2`, asset names/sizes/SHA-256 equal to the
  retained files and to the `SHA256SUMS.txt` lines, URLs under
  `…/FantasyDisk-Releases/releases/download/v0.3.1.2/`
  (`package/update_manifest_check.txt`, all checks true).
- `CHANGELOG-0.3.1.2.md` is the build script's extraction of the
  `## [0.3.1.2]` section; the poster equals the tag blob.
- `LOCAL_RELEASE.json`: tag `v0.3.1.2`, `tag_commit` = S, `macos_channel`
  `signed`, `source_tree_sha256` `8c0bb1ba…`, inventory as above.
- `project/` = `git archive v0.3.1.2` (`diff -rq` exit 0, 57,970 files each;
  `package/project_vs_git_archive.txt`); `godot-project/` present with
  `config/version="0.3.1.2"`; `releases/current-project →
  v0.3.1.2/godot-project`, registered in `projects.cfg` with `favorite=true`.
- Readback: `local_release.py verify --version 0.3.1.2 --macos-channel signed
  --launch-smoke` → `"status": "verified"` (`package/local_release_verify.txt`).
- **Every built artifact hash differs from every retained package** (`v0.3.1`,
  `v0.3.1.1`, `archive/v0.3.1-attempt1-448a0cc1`, `archive/v0.3.1-attempt2-165f14aa`,
  `v0.3.2`, `v0.3.0` and the quarantined 0.3.0 directories):
  `package/hash_difference_proof.json`, `all_built_artifacts_differ = true`,
  `installer_collisions = []`. The single equal hash is the poster image,
  which by PM decision is the unchanged 0.3.1 image under the new name
  (`6d0267c7…` in `v0.3.1`, `v0.3.1.1` and `archive/v0.3.1-attempt2-165f14aa`).
- The package was re-hashed at the end of the run and is unchanged since the
  build.

## 4. Preservation of the retained packages

Recursive SHA-256 of every regular file under `releases/` (except
`.DS_Store`; `preservation/README.md`): 706,269 files before the build
(manifest SHA-256 `d6352ac5…`), the same 706,269 files with the same manifest
SHA-256 after the build and again after every measurement
(`preservation/preservation_diff_after_build.txt` and
`preservation_diff_final.txt` are empty). `releases/v0.3.1` (160,112 files),
`releases/v0.3.1.1` (115,769 files), both archives, `v0.3.2`, `v0.3.0` and
the quarantined 0.3.0 directories kept every byte; no file was renamed,
relabeled or overwritten. The new package went only to
`releases/v0.3.1.2/`; the only other change under `releases/` is the
`current-project` pointer (`v0.3.1.1/godot-project` → `v0.3.1.2/godot-project`),
which is the retention tool's contract.

## 5. Installed app and trust (AC3)

`local_release.py materialize` installed `/Applications/FantasyDisk.app`
atomically from the retained DMG (the previous install was 0.3.1.1 / 1.3.11).

- `Info.plist`: `CFBundleShortVersionString` **0.3.1**, `CFBundleVersion`
  **1.3.12** (the mapped 0.3.1.2 build number); universal `x86_64 arm64`;
  hardened runtime; `codesign --verify --deep --strict` valid; stapler `The
  validate action worked!`; `spctl` accepted `source=Notarized Developer ID`
  (`package/trust_checks.txt`, identity redacted).
- DMG root: `FantasyDisk.app`, `Applications → /Applications`; the app in the
  mounted DMG passes the same checks and is file-for-file identical to the
  installed app (9 files, `package/dmg_app.sha256` = `package/installed_app.sha256`;
  PCK `43a02b4b8af894cf7bce21098f78d3542db39c2e66c7b91d8ba37739b6ab7d41`,
  423943232 B).
- **Main menu shows `v0.3.1.2`**: `main_menu/main_menu_v0.3.1.2_installed.png`
  (real `Main.tscn` inside a clone of the installed app, label
  `MainMenuVersionLabel: v0.3.1.2`, `main_menu/main_menu_capture.json`,
  `run_main_menu_capture.py`).

## 6. New animations in the built bytes (AC3)

### PCK contents, both platforms

`list_pck.py` (reuses the FAN-3985 probe's PCK directory reader; the Windows
PCK is carved from `FantasyDisk.exe` extracted read-only from the retained
Setup with `7z`, exe SHA-256 `6dd7631e…`, 532,994,128 B, embedded PCK at
offset 109,050,880, 423,943,236 B, SHA-256 `bed39a3f…`): both tables have
**27,034 entries**, **17 `data/ultimates/presentation/*.json`**, **0**
`docs/`, `evidence/`, `skills/`, `tools/` or `tests/` entries; the tables are
identical by path and size, and 421 sampled entries (all presentation
documents, every `scripts/ultimates/**` entry and 200 `.gdc`) have identical
content MD5 (`pck_tables_macos_vs_windows.json`, `pass: true`).

### FAN-3985 probe against the installed app (`installed_app_probe/`)

`tools/ultimate_export_probe.py --skip-export --captures` with
`<output-dir>/export/FantasyDisk.app` = a clone of `/Applications/FantasyDisk.app`.
macOS 26 kills a Developer ID/notarized app whose bundle is modified (the
probe's `override.cfg`; FAN-2199/FAN-3989 behaviour), so the clone was
re-sealed ad-hoc (`codesign --force --deep --sign -`) before the probe; its
PCK is byte-identical to the installed app's
(`installed_app_probe/pck_hash_installed_vs_probe_input.txt`). The installed
app itself was not touched.

- `export_probe_summary.json`: **`pass: true`**, 151.2 s. Environment inside
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
  pair, the resolved scene and the executable that rendered it). Together
  with the player-path captures and the perf captures (§8) that is at least
  two captures of a new ultimate per class from the installed app.

## 7. FAN-3991 long-session check in ONE process of the installed app (AC3)

`run_session_probe_in_app.py` runs the FAN-3991 probe
(`tools/ultimate_session_lifecycle_probe.gd` from the tag tree — one
`scenes/Main.tscn`, combat after combat through `Main._start_combat()` → real
Player → the `ultimate` InputMap action → executor → host-owned presentation
→ `_end_combat(true)`) INSIDE a clone of the installed app, with the judge of
`tests/ultimates/multi_class_session_lifecycle_test.gd`: a sequence fails on
any `Parent node is busy adding/removing children`, `Parent node is busy
setting up children`, `Condition "data.parent" is true`, `Condition
"!data.tree" is true`, `p_node->data.tree != data.tree`, `Parameter
"canvas_item" is null`, `previously freed`, `Trying to cast a freed object`
or `SCRIPT ERROR` in the engine log (`--log-file`) or stdout, on a non-zero
exit (`--disable-crash-handler`, so a crash is an immediate signal), a
timeout, a missing report, a report that is not `pass` or a pair that did
not activate. Launch: official templates refuse `--script`, and
`application/run/main_loop_type` does not accept a script path in the
exported app (`session/main_loop_type_attempt/NOTE.md`), so the override
main scene is `session_probe_wrapper.gd`, which installs the probe script on
the live SceneTree and calls `_initialize`. Isolated user dir
`FantasyDiskFan3994Session`; the clone is re-sealed ad-hoc with its PCK
byte-identical to the installed app's.

| run | sequence (ending) | pairs | lifecycle errors (engine log / stdout) | exit | peak `OBJECT_COUNT` | time |
|---|---|---|---|---|---|---|
| headless | dark_mage → doctor (`during_cast`) | 6/6 | 0 / 0 | 0 | 3,879 | 22 s |
| headless | chemist → doctor (`during_cast`) | 6/6 | 0 / 0 | 0 | 3,808 | 20 s |
| headless | dark_mage → doctor (`natural`) | 6/6 | 0 / 0 | 0 | 3,913 | 34 s |
| headless | dark_mage → doctor (`force`, the FAN-3990 driver default) | 6/6 | 0 / 0 | 0 | 3,860 | 20 s |
| headless | all 17 classes, registry order, 51 pairs (`during_cast`) | 51/51 | 0 / 0 | 0 | 9,383 | 156 s |
| windowed (real renderer, 1280x720) | dark_mage → doctor (`during_cast`) | 6/6 | 0 / 0 | 0 | 3,506 | 23 s |
| windowed | chemist → doctor (`during_cast`) | 6/6 | 0 / 0 | 0 | 3,591 | 21 s |
| windowed | dark_mage → doctor (`natural`) | 6/6 | 0 / 0 | 0 | 3,588 | 35 s |
| windowed | all 17 classes, 51 pairs (`during_cast`) | 51/51 | 0 / 0 | 0 | 7,665 | 162 s |

Zero occurrences of any pattern in any run, no crash, clean exit 0 for every
process (`session/headless/`, `session/windowed/`: runner summaries,
per-sequence probe reports, engine logs and stdout). In the 17-class order
Doctor (positions 40–42) comes after Berserk, Soldier, Thief, Elementalist,
Sniper, Priest, Biologist, Robot, Engineer, Dark Mage (28–30), Guitarist,
Assassin and Ranger; Chemist (43–45) follows Doctor, and the dedicated
`chemist → doctor` sequences cover that direction. Every pair activated
through the InputMap action with the class-owned presentation scene
instantiated (`instantiated_scene` per pair in the reports). The 9,383 /
7,665 peaks are the one-process maxima over 51 consecutive fights of the
"fight ends mid-cast" scenario, not a P2 reading (§8 has those).

## 8. Performance with the new scenes active (AC3)

`perf_ultimate_driver.gd` + `run_perf_in_app.py` (the FAN-3989 driver,
unchanged except for names): the FAN-3981 P2 window (48 enemies kept alive,
real `_start_combat` battle, FAN-3981 sampler) run INSIDE a clone of the
installed app (isolated user dir `FantasyDiskFan3994Perf`, windowed
2560×1440, GL Compatibility, vsync on), 60 s, the weapon ultimate cast every
8 s (Priest also every 16 s) through the real `Player.activate_ultimate()`
with the ledger's own `begin_encounter()` before each cast. The same driver
was run on the 0.3.1 app taken from the retained `v0.3.1` DMG
(`f391b86f…`, legacy path) for comparison. Tables: `perf/perf_tables.md`;
reports, per-run logs and captures under `perf/<batch>/`.

| build | class/weapon | casts | avg FPS | 1 % low | >50 ms | longest | first-cast frame | later casts max | objects start → peak → end | pickups at end | peak texture MiB |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.3.1.2 installed | berserk/sword | 8/8 | 115 | 24 | 1 | 1042 ms | 1042 ms | 39 ms | 2,971 → 8,499 → 8,316 | 2,305 | 1,404 |
| 0.3.1.2 installed | druid/summon_amulet | 8/8 | 113 | 24 | 1 | 1123 ms | 1123 ms | 38 ms | 3,227 → 10,594 → 10,492 | 3,533 | 1,476 |
| 0.3.1.2 installed | knight/long_spear | 8/8 | 116 | 24 | 1 | 1144 ms | 1144 ms | 24 ms | 2,990 → 3,728 → 3,469 | 132 | 1,395 |
| 0.3.1.2 installed | doctor/restore_potion | 8/8 | 115 | 24 | 1 | 1149 ms | 1149 ms | 30 ms | 3,135 → 7,950 → 7,547 | 1,871 | 1,404 |
| 0.3.1.2 installed, cast every 16 s | priest/priest_reliquary | 4/4 | 114 | 24 | 1 | 1115 ms | 1115 ms | 16 ms | 3,581 → 6,350 → 4,995 | 307 | 1,420 |
| 0.3.1 reference | berserk/sword (legacy) | 8/8 | 116 | 24 | 1 | 1070 ms | 1070 ms | 22 ms | 2,980 → 4,458 → 4,211 | 377 | 1,392 |
| 0.3.1 reference | druid/summon_amulet (legacy) | 8/8 | 111 | 24 | 1 | 1069 ms | 1069 ms | 32 ms | 3,271 → 3,504 → 3,275 | 17 | 1,473 |
| 0.3.1 reference | doctor/restore_potion (legacy) | 8/8 | 116 | 24 | 1 | 1070 ms | 1070 ms | 18 ms | 3,152 → 4,238 → 3,585 | 121 | 1,396 |
| 0.3.1.2 installed, rerun | berserk/sword | 8/8 | 117 | 113 | 0 | 30 ms | 27 ms | 22 ms | 2,991 → 8,790 → 8,501 | 2,361 | 1,404 |
| 0.3.1.2 installed, rerun | doctor/restore_potion | 8/8 | 118 | 112 | 0 | 34 ms | 27 ms | 32 ms | 3,262 → 8,049 → 7,519 | 1,917 | 1,404 |
| 0.3.1.2 installed, rerun, cast every 8 s | priest/priest_reliquary | 4/8 | 133 | 112 | 0 | 47 ms | 27 ms | 23 ms | 3,561 → 5,814 → 4,985 | 296 | 1,419 |

Reading the numbers against the limits:

- **Frame time / 1 % low (M1: 1 % low ≥ 45 target, < 30 red).** With the new
  scenes active the ultimate itself costs 16–39 ms on its cast frame and
  nothing measurable afterwards (average 113–118 FPS; 1 % low 112–113 in the
  rerun batch; 0.3.1 legacy casts: 18–32 ms). **First-batch event, not
  attributable to the new scenes:** every process of the first batch — the
  five 0.3.1.2 runs and all three 0.3.1 reference runs — had exactly one
  1.04–1.15 s frame at the *first* ultimate activation of the process, which
  alone makes their 1 % low 24 (one second of 60 at 24 FPS). It occurred
  identically on 0.3.1's legacy path; the three rerun processes (same clone
  mechanism, same user dir, system otherwise idle) did not reproduce it
  (first cast 27 ms). FAN-3989 recorded the same batch-1 behaviour on
  0.3.1.1 and 0.3.1. The cause was not isolated on this host; it is reported
  for the Windows verification to watch the first activation.
- **`Performance.OBJECT_COUNT` (FAN-3981 hard limit P2 ≤ 6,250; checklist
  target ≤ 5,000).** Knight stays at 3.7k. Priest peaks at 5,814 (rerun) /
  6,350 (first run: a single-frame reading at s58, per-second maximum 5,301,
  back to 4,995 at the window end; the FAN-3989 Priest runs peaked at
  5,765–5,837) with its battle-prayer UI and ~300 uncollected drops. Berserk,
  Doctor and Druid climb to 8.0–10.6k: the end-of-window scene-tree breakdown
  (`phase.tree_breakdown`) shows the growth is **`res://scenes/Pickup.tscn`
  drops** — 2,305 / 1,871 / 3,533 pickup nodes, i.e. loot from the 48 enemies
  the new ultimates kill on every cast (the driver respawns 48) that a
  stationary scripted player never collects; ≈2 engine objects per pickup
  account for the whole rise (Berserk 8,499 − 2 × 2,305 ≈ 3,889; Doctor
  7,950 − 2 × 1,871 ≈ 4,208; Druid 10,594 − 2 × 3,533 ≈ 3,528). The 0.3.1
  legacy ultimates kill far fewer per cast (377 / 121 / 17 pickups). Nothing
  of the ultimate runtime accumulates: back at the main menu with 0 resident
  packs every build sits at 2,272–2,436 objects (0.3.1: 2,321–2,402). So the
  P2 count with the new scenes and normal kill rates is within the hard
  limit; the >6,250 readings are the uncollected loot of this scenario, not a
  leak — the same caveat FAN-3989 recorded for the Windows verification's
  own P2 scenario, where the player moves and collects.
- **Priest 4/8 casts with 8-s spacing** — `ready_runtime_rejected`: the
  Sanctum Judgment presentation is still running 8 s after activation and the
  runtime refuses a second activation while one is active (shipped
  behaviour); with 16-s spacing 4/4 casts activate.
- Texture memory peak (act 1): 1,395–1,476 MiB, the FAN-3977/FAN-3983/FAN-3989
  values (≤ 1.5 GiB); resident full-frame packs 23 (28 with the Druid's
  summons) throughout, released after the run.
- Every 0.3.1.2 run: `resolution_source = weapon_profile` and the class-owned
  scene instantiated on each cast (`instantiated_scenes` in each report);
  one real game frame per first-batch run in `perf/<batch>/captures/`.

### Cold start (M4, `cold_start/`)

`measure_cold_start_app.sh` (FAN-3973/FAN-3983/FAN-3989 method on the app
binary: `--print-fps --verbose --quit-after 600`, wall-clock timestamps,
first `Project FPS` line − 1 s, isolated `HOME`), five launches each of the
installed 0.3.1.2 and of the 0.3.1 reference app:

| build | median first frame (s) | min | max | per run |
|---|---|---|---|---|
| 0.3.1.2 installed | **5.52** | 5.49 | 6.92 | 6.92, 5.51, 5.49, 5.52, 5.53 |
| 0.3.1 (retained DMG app) | 5.57 | 5.57 | 7.63 | 7.63, 6.47, 5.57, 5.57, 5.57 |

Unchanged within the run-to-run spread (FAN-3989 measured 6.09 vs 5.85 on
this host); no error lines in the launch logs (the only "error" matches are
the `sfx_ui_error.ogg` resource loads).

## 9. Saves (AC4)

`~/Library/Application Support/Godot/app_userdata/FantasyDisk` (5,636 files
before the build excluding `logs/`, `shader_cache/`, `vulkan/`; `saves/`).
Probes, session runs, perf runs and the cold-start launches used isolated
user directories (`FantasyDiskFan3985Probe`, `FantasyDiskFan3994Menu`,
`FantasyDiskFan3994Session`, `FantasyDiskFan3994Perf`, isolated `HOME`).

- **Controlled reinstall test** (`saves/reinstall_test.log`,
  `user_data_before_reinstall.sha256` = `user_data_after_reinstall.sha256`):
  manifest → `install_macos_from_dmg(launch_smoke=True)` from the retained
  DMG over the installed app (the exact code path `materialize` uses: DMG
  verify, ditto into a stage, atomic replace, launch smoke with the real
  user dir) → manifest: **5,635 files, byte-identical**; the installed app's
  9 files are identical before and after. The same manifest is unchanged
  after every later measurement (`user_data_after_all_measurements.sha256`).
- **One difference between the pre-build manifest and the post-install
  manifest, reported as found** (`saves/diff_before_build_vs_after_install.txt`):
  `fantasydisk_autosave.cfg` (the run checkpoint, 4,019 B, dated 2026-09-29
  22:06, SHA-256 `42a59844…`) existed before the build and was absent when
  the first post-install manifest was taken (14:45Z). Everything else,
  including `fantasydisk_meta.cfg` and `settings.cfg` (same hash, rewritten
  at 17:42:41 local), is unchanged. What the logs show: the game writes only
  through `RunAutosave` and deletes the checkpoint only from the "New game"
  button of the continue-run dialog, hero select, and the victory/death
  screens (`main_menu.gd:810`, `hero_select.gd:1123`, `victory_death.gd`);
  the install launch smoke (`--headless --quit-after 2`) never reaches
  them. The Godot log rotation in that user dir records three processes
  between the two manifests: the install launch smoke at 17:41:03 local
  (header only, headless), **an unidentified windowed launch of the game at
  17:42:40 local (log carries the `OpenGL API 4.1 Metal` line, i.e. a real
  window, and it rewrote `settings.cfg` at 17:42:41)** that was started by
  none of this task's commands (the build had finished at 17:42:01 and the
  task's next game launch, the verify launch smoke, is the headless process
  at 17:45:06), and that verify launch smoke. The controlled reinstall test
  above shows the install path leaves the user data byte-identical, so the
  deletion is attributed to that interactive windowed session (a user-side
  "New game"/run-end action), not to the package or the reinstall. The
  checkpoint cannot be restored from this task's data (only its hash was
  recorded).

## 10. Early transfer to FAN-3990 (AC5, `transfer/`)

`split -b 50000000 -a 2` → 9 parts (8 × 50,000,000 B + 38,450,173 B),
`PARTS.sha256` (SHA-256 `c720ed83…`); `cat part-* | shasum -a 256` =
`162740c4…` = the retained Setup = the `SHA256SUMS.txt` line. Posted on
FAN-3990 as comment `01a0f7f2-7591-79f4-88b1-e8702bee8672` (14:50:57Z) with
the 9 parts, `PARTS.sha256`, `SHA256SUMS.txt` and `update-manifest.json`,
marked "package review pending" (`transfer/fan3990_transfer_post.json`,
attachment IDs; the first post attempt timed out at the upload stage without
creating a comment and was repeated with a longer HTTP timeout). Read back:
`PARTS.sha256` and `part-ai` downloaded again and byte-equal to the local
files (`transfer/split_and_readback.txt`).

## 11. Files

- `run_build.sh`, `build_release.sanitized.log`, `sanitize_build_log.py`,
  `package/` (LOCAL_RELEASE, SHA256SUMS, update-manifest and its check,
  CHANGELOG, retained inventory, trust checks, verify readback, app file
  hashes, ls-remote before/after, hash-difference proof, Windows exe hash,
  project-vs-git-archive), `hash_difference_proof.py`, `trust_checks.sh`,
  `package_manifest.json` (`build_package_manifest.py`).
- `preservation/` — manifest summary, top-level retained package hashes,
  empty diffs after build and final.
- `installed_app_probe/` — FAN-3985 probe output against the installed app;
  `list_pck.py`, `pck_tables_macos_vs_windows.json`.
- `session/` — `run_session_probe_in_app.py`, `session_probe_wrapper.gd`
  (in the root), headless and windowed runner summaries, probe reports,
  engine logs, stdout; the wrapper test and the failed main-loop-type
  attempt.
- `perf_ultimate_driver.gd`, `run_perf_in_app.py`, `perf_table.py`, `perf/`.
- `measure_cold_start_app.sh`, `analyze_cold_start.py`, `cold_start/`.
- `main_menu_capture.gd`, `run_main_menu_capture.py`, `main_menu/`.
- `saves/`, `transfer/`.

## Reproduce

```bash
# from the repository root of a checkout of v0.3.1.2 (tree 05fc714c…)
bash evidence/FAN-3994/run_build.sh 0.3.1.2 /abs/raw.log
python3 skills/codex/fantasydisk-release-director/scripts/local_release.py verify --version 0.3.1.2 --macos-channel signed --launch-smoke
bash evidence/FAN-3994/trust_checks.sh /Users/sergeyfomin/FantasyDisk/releases/v0.3.1.2/FantasyDisk-0.3.1.2-macos.dmg /Applications/FantasyDisk.app /abs/scratch /abs/out
python3 evidence/FAN-3994/hash_difference_proof.py /Users/sergeyfomin/FantasyDisk/releases v0.3.1.2 /abs/out/hash_difference_proof.json
python3 evidence/FAN-3994/list_pck.py --macos-pck /Applications/FantasyDisk.app/Contents/Resources/FantasyDisk.pck --windows-exe /abs/FantasyDisk.exe --out /abs/out/pck.json
python3 evidence/FAN-3994/run_main_menu_capture.py --app /Applications/FantasyDisk.app --out /abs/menu --label v0.3.1.2_installed
# clone /Applications/FantasyDisk.app to <out>/export/FantasyDisk.app and re-seal it ad-hoc, then:
python3 tools/ultimate_export_probe.py --skip-export --captures --output-dir <out> --evidence-dir evidence/FAN-3994/installed_app_probe
python3 evidence/FAN-3994/run_session_probe_in_app.py --app /Applications/FantasyDisk.app --out /abs/session --label v0.3.1.2_installed_headless --mode wrapper
python3 evidence/FAN-3994/run_session_probe_in_app.py --app /Applications/FantasyDisk.app --out /abs/session_w --label v0.3.1.2_installed_windowed --mode wrapper --windowed --sequences dark_mage_then_doctor chemist_then_doctor dark_mage_then_doctor_natural_end all_17_classes
python3 evidence/FAN-3994/run_perf_in_app.py --app /Applications/FantasyDisk.app --label v0.3.1.2_installed --out /abs/perf --runs berserk/sword druid/summon_amulet knight/long_spear doctor/restore_potion --seconds 60 --cast-every 8 --captures
bash evidence/FAN-3994/measure_cold_start_app.sh v0.3.1.2_installed /Applications/FantasyDisk.app 5 /abs/cold && python3 evidence/FAN-3994/analyze_cold_start.py /abs/cold
```

## Limitations

- Native Windows verification is FAN-3990's (same Setup bytes `162740c4…`).
- The probe, session and perf clones had to be re-sealed ad-hoc to launch on
  macOS 26; the installed app and the retained DMG were verified with their
  Developer ID signature intact and the clones' PCK bytes are identical to
  the installed app's.
- The first-batch first-activation frame (§8) is recorded, not explained.
- The scripted combat keeps the player stationary and resets the charge
  ledger per cast; object counts include the resulting uncollected loot.
- The autosave checkpoint deletion (§9) happened in a windowed game session
  this task did not start; the reinstall path is proven not to touch user
  data, but the deleted checkpoint itself is not recoverable from here.
