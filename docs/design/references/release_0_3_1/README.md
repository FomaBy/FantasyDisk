# FantasyDisk 0.3.1 poster source and verification

The publishable 1350 × 1350 RGB poster is
`assets/marketing/fantasydisk_0.3.1_announcement.png` (SHA-256
`d9ac6ea81de2fbdee68eb2ba849287078c32e9fd3cda04332bdcfaee1a03de9e`).
Its five declared content zones contain the only composited text. The central
disk and all frame decoration come from the selected PixelLab source.

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
readability. The content uses the 0.3.1 release date, 23 September 2026.

`ui_plan.report.json` records `decision: ready_for_image`, `ok: true`, no
errors, and no warnings. `fit_report.json` records `ok: true` for all five
zones. Every final zone was checked pixel by pixel on the enlarged empty base:
each was uniformly `#211F2BFF` before text was drawn. The final poster and
decoded debug overlay were visually reviewed at 1350 × 1350.

`debug_overlay.png.base64.txt` decodes to the PNG zone overlay, SHA-256
`4c7b22c404177b61eaa84b00dbe765df8609673a30e94f18d8cce161f7c4a5ba`.
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
