# FantasyDisk 0.3.1 poster source and verification

The publishable 1350 × 1350 RGB poster is
`assets/marketing/fantasydisk_031_announcement.png` (SHA-256
`6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7`,
Git blob `51803688c0e2aa81a9255f94ca5214c0418d6242`), dated 28.09.2026.
Its five declared content zones contain the only composited text. The central
disk and all frame decoration come from the selected PixelLab source.

This is the name `tools/build_release.sh` derives for version 0.3.1. The
first candidate committed the same image as
`assets/marketing/fantasydisk_0.3.1_announcement.png`; it was renamed without
re-encoding (same Git blob `13a98b431534a1d5e278309f4ce360b464e7b043` and
SHA-256), so the fit report, debug overlay, and provenance below still
describe these exact bytes. The old path is no longer present.

## Provenance

- Player copy and initial plan: FAN-3961 developer
  `0d1f7faf-7aaa-4fc4-91e6-6e9451a5842c`; preserved initial source audit,
  draft, and prompt are linked by the issue's early-draft attachments.
- Empty frame: PixelLab artist `cfe79584-cc99-4726-94ed-d8b7e4d37b05`;
  Workbench drawing `0d0cbdac-0034-44ca-a495-0d09ee5707b0`.
  `source_base.png.base64.txt` decodes to the exact 512 × 512 opaque PNG,
  SHA-256 `6283bd9afbc0c14b777a16ffaa9c767f4dd0db50fb14bc144f7d13312e6c1892`.
- `generation_manifest.json` records the source method, image ID, original
  input hashes, three rejected attempts with their job/asset IDs and hashes,
  and the selected source's zone inspection. `zone_inspection.md` records the
  native pixel check. The three rejected image files remain attached to the
  FAN-3961 art-stage comment; they were not used in the poster.
- `empty_frame_prompt.md` is the developer's original handoff. The two
  `generation_prompt_attempt_*.md` files preserve the attempted AI prompts;
  the selected Workbench image was subsequently drawn to keep every zone flat.

## Final composition

The 512 × 512 source was enlarged to 1350 × 1350 with nearest-neighbor
sampling. The final `ui_plan.json` and `layout.json` inset each original zone
by four pixels at 1350 scale, keeping the source's thin gold borders outside
the text rectangles. Both lower text zones allow up to 26-pixel type for
readability. The content uses the 0.3.1 release date, 28 September 2026.

`ui_plan.report.json` records `decision: ready_for_image`, `ok: true`, no
errors, and no warnings. `fit_report.json` records `ok: true` for all five
zones. Every final zone was checked pixel by pixel on the enlarged empty base:
each was uniformly `#211F2BFF` before text was drawn. The final poster and
decoded debug overlay were visually reviewed at 1350 × 1350.

`debug_overlay.png.base64.txt` decodes to the PNG zone overlay, SHA-256
`f62e3f457b42297e59d1b732da48693b3e7fa455663f6eaa1edfbb3bea1ad8ad`.
The two base64 files preserve exact PNG bytes as UTF-8 text because this
task's allowed reference directory cannot contain new design binaries under
the repository storage policy. Decode with `base64 -D` on macOS or
`base64 --decode` on Linux, then compare the hashes above.

The final source comparison is `v0.3.0` → integrated `dev` commit
`e33bded444e301919dc93c8c9b9f0257e640a1ea`, tree
`9a8401ca1a6dda8a4b446fe45de3fa4f97074426`. FAN-3877 independently
passed the 17-class/51-ultimate Mac certification on that exact source. The
prior provisional audit is retained separately as `early_source_audit.json`
and `early_source_provenance.md`; its pending-QA statements describe the
earlier draft stage only.

## Re-dated render (FAN-3978)

0.3.1 was not published on 23 September 2026. The owner kept the release
number 0.3.1 for the build that also carries the startup and combat-freeze
fixes (0.3.2 was never published either), so the poster was re-rendered with
the new release date. No new image was generated and no player copy changed.

Renderer: `skills/codex/content-zone-image-compositor/scripts/`
(`validate_ui_layout_plan.py`, `render_content_zones.py`), Pillow 11.3.0, font
`/System/Library/Fonts/Supplemental/Arial Unicode.ttf` on macOS.

1. Decode `source_base.png.base64.txt` (SHA-256 `6283bd9afbc0c14b777a16ffaa9c767f4dd0db50fb14bc144f7d13312e6c1892`) and
   enlarge 512 → 1350 with nearest-neighbor sampling.
2. Reproducibility check: rendering the previous `layout.json` on that base
   gives the previous poster byte for byte (SHA-256
   `d9ac6ea81de2fbdee68eb2ba849287078c32e9fd3cda04332bdcfaee1a03de9e`).
3. `ui_plan.json` and `layout.json` changed only `release_date`
   `23.09.2026` → `28.09.2026`.
4. `validate_ui_layout_plan.py --plan ui_plan.json` → `ui_plan.report.json`:
   `ok: true`, `decision: ready_for_image`, no errors, no warnings. The
   planner's `fit_font_size` estimate for `key_changes` now reads 26 instead of
   25; the unchanged previous plan gives the same 26 with the current planner,
   so this is the estimate, not a content change.
5. `render_content_zones.py --layout layout.json` → `fit_report.json`:
   `ok: true` for all five zones, font sizes 44/44/32/26/26 as before.
6. A pixel comparison with the previous poster finds changes only inside the
   date zone (`914,129,322,117`); the changed bounding box is
   `(1010,173)-(1032,202)`, the two differing digits.

The previous poster bytes remain in Git history. The unpublished 0.3.2 poster
(`assets/marketing/fantasydisk_032_announcement.png`,
`docs/design/references/release_0_3_2/`) stays as unused history; it is
excluded from export with the rest of `assets/marketing/`.

The date 28.09.2026 matches `CHANGELOG.md` (`## [0.3.1] — 2026-09-28`) and the
newest entry in `scripts/patch_notes_data.gd`.
