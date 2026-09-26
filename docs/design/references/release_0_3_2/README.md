# FantasyDisk 0.3.2 poster source and verification

The publishable 1350 × 1350 RGB poster is
`assets/marketing/fantasydisk_032_announcement.png` (SHA-256
`7a890effc71460cda7769902c4adb7f8da217ccf4f7f2a935ed7d30e580c0867`,
Git blob `81732b9d1226c256d0186e180ee205d1effc50f5`). This is the name
`tools/build_release.sh` and the release scripts derive for version 0.3.2
(`fantasydisk_${VERSION//./}_announcement.png`), the same rule the 0.3.1
poster follows.

0.3.1 was not published; 0.3.2 replaces it (FAN-3974). The 0.3.1 poster
`assets/marketing/fantasydisk_031_announcement.png` and its package under
`docs/design/references/release_0_3_1/` are unchanged history.

## Provenance

No new image was generated. The poster reuses the approved 0.3.1 source,
plan and layout unchanged except for two text values:

- Empty frame: the same PixelLab Workbench drawing
  `0d0cbdac-0034-44ca-a495-0d09ee5707b0` (artist
  `cfe79584-cc99-4726-94ed-d8b7e4d37b05`). `source_base.png.base64.txt` is a
  copy of the 0.3.1 file and decodes to the 512 × 512 PNG with SHA-256
  `6283bd9afbc0c14b777a16ffaa9c767f4dd0db50fb14bc144f7d13312e6c1892`.
  Generation history, rejected attempts, prompts and the native zone
  inspection are in `docs/design/references/release_0_3_1/`
  (`generation_manifest.json`, `generation_prompt_attempt_*.md`,
  `empty_frame_prompt.md`, `zone_inspection.md`).
- `ui_plan.json` and `layout.json` equal the 0.3.1 files except
  `version` `0.3.1` → `0.3.2` and `release_date` `23.09.2026` →
  `26.09.2026`. Zones, fonts, colors and the player copy in both lower zones
  are unchanged.

## Render

Renderer: repository `skills/codex/content-zone-image-compositor/scripts/`
(`validate_ui_layout_plan.py`, `render_content_zones.py`), Pillow 11.3.0,
font `/System/Library/Fonts/Supplemental/Arial Unicode.ttf` on macOS.

1. Decode `source_base.png.base64.txt`, enlarge 512 → 1350 with
   nearest-neighbor sampling.
2. Reproducibility check: rendering the 0.3.1 `layout.json` on that base gives
   the published 0.3.1 poster byte for byte (SHA-256
   `d9ac6ea81de2fbdee68eb2ba849287078c32e9fd3cda04332bdcfaee1a03de9e`).
3. `validate_ui_layout_plan.py --plan ui_plan.json` →
   `ui_plan.report.json`: `ok: true`, `decision: ready_for_image`, no errors,
   no warnings.
4. `render_content_zones.py --layout layout.json` → `fit_report.json`:
   `ok: true` for all five zones, same font sizes as 0.3.1 (44/44/32/26/26).
5. A pixel comparison with the 0.3.1 poster finds changes only inside the
   version zone (`514,129,322,117`) and the date zone (`914,129,322,117`);
   no pixel outside those two zones differs.

`debug_overlay.png.base64.txt` decodes to the PNG zone overlay, SHA-256
`e9b107fec683727db1405f17e19243bee438e930499ef30a6b04f269c902fe42`.
Binary design files are stored as base64 text here, as for 0.3.1. Decode
with `base64 -D` on macOS or `base64 --decode` on Linux.

The date 26.09.2026 matches `CHANGELOG.md` (`## [0.3.2] — 2026-09-26`) and
the newest entry in `scripts/patch_notes_data.gd`.
