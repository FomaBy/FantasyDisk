# FAN-3985 — weapon ultimate presentations in exported builds

Evidence for the exported-build regression fix. Everything below was produced on
the macOS development host with Godot `4.7.stable.official.5b4e0cb0f` and the
official 4.7 export templates, from the candidate code commit
`c16085f7e6c9fe797efee6c6fa1bf091b4055edd` (tree
`b305eae77bbfe2f4cdf886debd0cfb4a7a75aa4f`), based on `dev` =
`f4d05fea91a5ce8b3fb858a5035df1fe54236369`. The evidence commit that carries
this directory changes nothing the export reads (`evidence/*` is excluded from
both presets), so the exported PCK of the review candidate is byte-identical to
the one recorded here (`pck_sha256` in `export_probe_summary.json`).

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

```bash
python3 tools/build_ultimate_presentation_runtime_data.py --check
python3 tools/ultimate_export_probe.py --captures --evidence-dir evidence/FAN-3985
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/export_runtime_paths_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation_runtime_data_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_package_discovery_test.gd
python3 -m unittest tests.test_ultimate_presentation_runtime_data tests.test_export_presets_exclusions
```
