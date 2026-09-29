# FAN-3985 — weapon ultimate presentations in exported builds

Evidence for the exported-build regression fix. Everything below was produced on
the macOS development host with Godot `4.7.stable.official.5b4e0cb0f` and the
official 4.7 export templates, from the rework code commit
`5a4f82131` (tree `a85b9c9bda02fb8330f5e0c437fef946430016ec`), the cherry-pick of
the QA-approved candidate `aef466937522f2788b13bf1d67f66ba63c570802` onto
`dev` = `81d384e688e7bc7388b7ae24770565b2df51957e` (the only difference is
FAN-3986's `.github/workflows/quality.yml`). The first-review candidate was
`09d692b5ea687fc870931dd26c616192bc3518ab`. The evidence commit that carries
this directory changes nothing the export reads (`evidence/*` is excluded from
both presets), so the exported PCK of the review candidate has the same
directory and the same `.gdc`/remap/JSON bytes as the one recorded here.
`pck_sha256` in `export_probe_summary.json` is reproducible only with the same
import cache: the first independent review showed that converted binary scenes
(`.godot/exported/**/*.scn`) carry 8 bytes of import-cache-dependent
`node_ids`, so a fresh checkout yields a different PCK hash with an identical
file table and identical script/data entries. Compare file tables and the
script/data entries, not the whole-file hash.

## Rework after the first review (QA FAILED, 10 of 51 pairs crashed)

The first review found that the fix made the new executors reachable in the
release build for the first time, and 10 of 51 pairs then died by SIGSEGV
1–4 s after activation: stored enemy references were cast (`raw as Node2D`,
`victim is Node2D`) or called after the enemy was freed. The editor only
prints `Trying to cast a freed object`; the release template dereferences the
freed object. The rework validates every stored reference with
`is_instance_valid` before any cast, type test or call (executors, leases,
the shared victim impact player, the activation, the Priest censer host
proxy and `scripts/combat_feedback_timeline.gd`), and adds the player-path
gates recorded below.

## Third candidate: rebased on dev 81d384e6, FAN-3942 certification packages re-shot

The required PR check `static-quality` rejected the second candidate because the
runtime change staled the three strict FAN-3942 certification packages
(Assassin, Doctor, Druid): their capture manifests named a source commit that
predates the ultimate runtime fix. This candidate re-shoots those three packages
with the existing live capture scripts on the commit that carries this
directory (the clean source commit recorded in each
`certification_capture_manifest.json`), and commits only their evidence on top.
The exported-build evidence below was regenerated from the rebased code.

## Files

| File | What it proves |
|---|---|
| `baseline_smoke_probe_dev_f4d05fea.txt` | Reproduction on the unfixed `dev` export: no `docs/` manifests in the PCK, `data/ultimates/presentation` absent, discovery lists only `.gd.remap`/`.gdc`, zero executable pairs, `knight/long_spear` resolves to `legacy_class_fallback`, and `FileAccess.file_exists` is false for the scene, silhouette PNG, SFX and executor while `ResourceLoader.exists` is true. |
| `export_probe_summary.json` | Orchestrator verdict for the candidate: export, PCK listing, headless probe, both mutation checks, captures. `pass: true`. |
| `export_probe_probe_report.json` | Headless probe run inside the exported app: for all 51 class/weapon pairs `resolution_source = weapon_profile`, executor admitted through the `.gd.remap`, class-owned `scene_path`, `begin_ok = true`, and the instantiated scene's file/script. `environment.editor_feature = false`, `environment.docs_manifest_present = false`, 17 presentation documents listed from the PCK. |
| `export_probe_pck_listing.json` | PCK directory (format 4, 27,034 entries): the 17 `data/ultimates/presentation/<class>.json` entries with sizes, `scripts/ultimates/classes/**` as 51 `.gd.remap` + 51 `.gdc`, and zero `docs/`, `evidence/`, `tests/`, `tools/`, `skills/` entries. |
| `export_probe_mutation_presentation_document_removed.json` | Mutation check: with `data/ultimates/presentation/knight.json` removed from a copy of the PCK, the probe exits 1 and the three Knight pairs report `record_found = false`, `begin_ok = false`; the other 48 still pass. |
| `export_probe_mutation_executor_remap_removed.json` | Mutation check: with `scripts/ultimates/classes/knight/long_spear.gd.remap` removed, `knight/long_spear` reports `resolution_source = legacy_class_fallback` and no executor; the other 50 still pass. |
| `export_probe_capture_report.json` | Windowed probe run (1280x720, fixed 60 fps) that produced the captures; same 51/51 checks. |
| `exported_app_captures/<class>__<weapon>.png` | One weapon per class, screenshotted inside the exported app at its `active` beat (+ a settle offset). The label burned into each frame names the pair, the resolved scene and the exported executable that rendered it. |
| `export_probe_probe.log` | stdout of the headless probe run. |
| `export_probe_player_path.json` | Player-path stage of the exported app: every one of the 51 pairs played in its own fresh process of the exported release build (isolated user directory `FantasyDiskFan3985Probe`, update check off) through `Main._start_combat()` → real `Player.activate_ultimate()` → executor, enemy deaths, victim impacts, authored presentation, and kept running past the declared cancel (`wait_seconds`). `exit_code` per pair (a signal such as −11 is a crash), `crashes` list, `resolution_source`, instantiated scene, survived game seconds; then one windowed replay per class with a real game frame. |
| `exported_app_player_path_captures/<class>__<weapon>.png` | One real game frame per class from the exported app during the ultimate (HUD, arena, enemies), taken by the windowed player-path replay. |

## How the probe runs inside the exported app

Official export templates are built with `disable_path_overrides`, so
`--script`, `--main-pack` and a scene argument are refused by the exported
binary. `tools/ultimate_export_probe.py` therefore clones the exported
`FantasyDisk.app`, writes an `override.cfg` beside `Contents/MacOS/FantasyDisk`
that points `application/run/main_scene` at a generated scene carrying
`tools/ultimate_export_probe.gd`, and starts the exported binary. The registry,
package discovery, presentation bridge, schema and presentation runtime that run
are the PCK's own remapped `.gdc` scripts and exported data. The original export
is never modified; mutations rename one directory entry in a copy of the PCK.

## Reproduce

Check out the review candidate (the SHA recorded on the card as
`candidate_sha`), then:

```bash
python3 tools/build_ultimate_presentation_runtime_data.py --check
python3 tools/ultimate_export_probe.py --captures --evidence-dir evidence/FAN-3985
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/player_path_release_safety_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/export_runtime_paths_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation_runtime_data_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_package_discovery_test.gd
python3 -m unittest tests.test_ultimate_presentation_runtime_data tests.test_export_presets_exclusions
```
