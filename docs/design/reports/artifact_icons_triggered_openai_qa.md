# SCRUM-690 Triggered Artifact Icons QA

- Generator: OpenAI Images API through `fantasydisk-asset-generator/scripts/generate_asset.py` (`gpt-image-2`, high), as explicit SCRUM-690 override to the PixelLab-first icon rule.
- Postprocess: removed baked checkerboard/light matte from generated sources, cropped alpha bounds, fit to 256x256 with target padding, exported RGBA runtime PNGs.
- Contact sheet: `docs/design/previews/artifact_icons_triggered_openai_batch.png`
- Gameplay/data changes: none.

## Icons

| ID | Final path | Source notes | Size/mode | Padding L/T/R/B | SHA changed | Small-readability |
| --- | --- | --- | --- | --- | --- | --- |
| `guardian_bulwark` | `assets/sprites/ui/icons/artifacts/artifact_guardian_bulwark.png` | `docs/design/references/icons/artifacts/guardian_bulwark/prompt_notes.md` | 256x256 RGBA | 28/34/28/35 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |
| `chain_spark` | `assets/sprites/ui/icons/artifacts/artifact_chain_spark.png` | `docs/design/references/icons/artifacts/chain_spark/prompt_notes.md` | 256x256 RGBA | 28/28/28/28 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |
| `crit_impulse` | `assets/sprites/ui/icons/artifacts/artifact_crit_impulse.png` | `docs/design/references/icons/artifacts/crit_impulse/prompt_notes.md` | 256x256 RGBA | 36/28/36/28 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |
| `breather_totem` | `assets/sprites/ui/icons/artifacts/artifact_breather_totem.png` | `docs/design/references/icons/artifacts/breather_totem/prompt_notes.md` | 256x256 RGBA | 79/28/80/28 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |
| `counterwave_sigil` | `assets/sprites/ui/icons/artifacts/artifact_counterwave_sigil.png` | `docs/design/references/icons/artifacts/counterwave_sigil/prompt_notes.md` | 256x256 RGBA | 28/30/28/30 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |
| `soul_harvest` | `assets/sprites/ui/icons/artifacts/artifact_soul_harvest.png` | `docs/design/references/icons/artifacts/soul_harvest/prompt_notes.md` | 256x256 RGBA | 59/28/60/28 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |
| `second_wind` | `assets/sprites/ui/icons/artifacts/artifact_second_wind.png` | `docs/design/references/icons/artifacts/second_wind/prompt_notes.md` | 256x256 RGBA | 65/28/66/28 | yes | PASS: silhouette survives 32/40/64 contact-sheet samples |

## Duplicate / Alpha Checks

- Batch internal SHA duplicates: none.
- Full artifact directory SHA duplicate groups after replacement: none.
- Alpha: all seven finals are RGBA, transparent outside subject bounds, no opaque square matte retained.
- Naming: all seven runtime filenames match `artifact_<canonical_id>.png`.
- Forbidden content: no baked text/letters/numbers/frames/panels intentionally included; source contact sheet was visually checked after generation and final contact sheet created for QA.

## Checks

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/content_rewards_integrity_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/artifacts_606_609_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/no_duplicate_artifact_files_test.gd`
- PASS: targeted Python alpha/SHA duplicate check for all seven SCRUM-690 runtime PNGs.
- PASS: `git diff --check`
- PASS with noisy pre-existing import/resource warnings: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_triggered_artifacts_test.gd` printed `[triggered_artifacts] PASSED`.
- Tool note: `python3 tools/validate_artifact_icons.py` failed while saving its global preview sheet with `tile cannot extend outside image`; SCRUM-690 used the dedicated contact sheet and alpha/readability report above instead.

## Locked Paths

- `assets/sprites/ui/icons/artifacts/artifact_{guardian_bulwark,chain_spark,crit_impulse,breather_totem,counterwave_sigil,soul_harvest,second_wind}.png`
- `docs/design/references/icons/artifacts/{guardian_bulwark,chain_spark,crit_impulse,breather_totem,counterwave_sigil,soul_harvest,second_wind}/`
- `docs/design/previews/artifact_icons_triggered_openai_batch.png`
- `docs/design/reports/artifact_icons_triggered_openai_qa.md`
