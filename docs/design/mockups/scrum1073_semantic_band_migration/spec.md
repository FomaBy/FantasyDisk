# SCRUM-1073 Semantic Band Geometry Spec

## Decision

`ready_for_image` and runtime migration approved. The authoritative migration
surface is the 139-entry fingerprint manifest in the SCRUM-1061 typography
inventory. This package supplies a PixelLab content-zone anchor for the 35 sites
whose screen families did not already have an accepted PixelLab mockup; the
other 104 sites reuse their accepted screen-specific mockups.

The generated layer is design evidence only. It is not promoted to runtime.
Runtime continues to use the existing screen art and adapts geometry around the
canonical semantic typography bands.

## PixelLab and content zones

The approved PixelLab source is
`6e512c63-5c42-44ee-a6b3-09a3ed69189d`. It contains eight empty framed zones:
economy, combat HUD, event, confirmation, feedback, patch notes, start boon and
victory. The first generation was rejected because pseudo-runes entered the
content surfaces; `manifest.json` preserves that rejection and the clean source
provenance.

`ui_plan.json` and `layout.json` define exact coordinates. All eight compositor
zones report `ok: true`; text bounding boxes stay inside their declared zones.
The feedback zone reserves a 12px scrollbar lane. Decorative rails remain
untouched.

## Runtime geometry rules

- Never reduce a semantic role below its canonical band to preserve an old box.
- First spend unused padding, then grow the empty content lane, then wrap or
  scroll. Text may not cover a frame rail or ornament.
- Preserve complete source copy in tooltip/metadata when a compact visible lane
  uses an ellipsis or abbreviated label.
- Codex transform-aware fonts receive a 60px local title lane ending before the
  preview rail; the visual size remains semantic while `visible_line_count > 0`.
- Compact Event cards use a 176px lower zone that grows upward. It preserves
  16px/18px viewport margins at 1152×648/1280×720 and remains disjoint from the
  dialogue panel.
- Compact Shop uses a 700×148 fixed tooltip with a 650×114 inner zone; it ends
  before the Back action and contains every wrapped line.
- Compact Settings lifts Reset by the measured 3px semantic action-font delta,
  so follow-focus reveals the whole plate without entering the Atlas ornament.

## Responsive acceptance

| viewport | contract |
| --- | --- |
| 1152×648 | compact/worst-height; Event screenshot + exact containment |
| 1280×720 | compact canonical; Event/Shop/Settings focused gates |
| 1600×900 | medium no-overlap matrix |
| 1920×1080 | desktop focused screen gates |
| 2048×1152 | explicit intermediate no-overlap tier |
| 2560×1440 | 2K geometry and live-resize return path |

Windowed evidence for the compact Event reallocation is under
`docs/design/previews/scrum1073_semantic_band_migration/`. The PixelLab
composite is `pixellab_composited_preview_600x448.png`; its debug overlay and
fit report are adjacent.
