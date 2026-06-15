# Animation Safe Slicing Audit — June 2026

Task: SCRUM-387 / `docs/tasks/animation_sprite_sheet_safe_slicing_audit_task.md`
Date: 2026-06-14
Owner: Animator (Codex)

## Scope

Checked active runtime `SpriteFrames` and source/reference sprite sheets for
neighboring-frame pixel bleed, crop-edge alpha/chroma remnants, edge artifacts,
and the new `fantasydisk-animation-director` source gutter standard.

Duplicate audit:
- SCRUM-350 covered full-frame pipeline readiness and 5+ frame standards.
- SCRUM-353 covered summon/allied creature move/attack frame coverage.
- SCRUM-370 integrated available death rows into runtime `SpriteFrames`.
- SCRUM-380 delivered source/reference death rows for Design.

SCRUM-387 is narrower: pixel safety and safe slicing only.

## Runtime Result

Runtime `SpriteFrames` checked: 30.
Unique runtime PNG frames checked: 794.

Result: PASS for active runtime slicing.

- Neighboring-frame/crop-edge capture: 0 frames.
- Crop-edge green/chroma remnants: 0 frames.
- Edge-touching alpha within the strict edge threshold: 0 frames.
- Green-dominant pixels found anywhere in frame: 122 frames, all interior visual
  content or intended palette/VFX; 0 on crop edges.

145 frames are below the new ideal transparent padding target for their canvas
size, mostly bottom-baseline frames for allies and boss/elite deaths. They do
not show neighbor-frame capture or edge artifacts in the active runtime because
the game consumes individual PNG frames, not a live sliced atlas. Resizing or
shifting these runtime frames just to satisfy ideal padding would risk visual
scale/pivot regressions, so no Animator runtime asset rewrite was made.

## Source Sheet Result

Source/reference sheets checked: 45.

All 45 source/reference sheets are exact 6x4 grids with inferred `256x256`
cells, `0 px` structural gutter, and `0 px` outer padding. The new source-sheet
standard requires `24 px` gutter and `24 px` outer padding for `256x256` cells.
Several cells touch inferred cell boundaries, so these sheets should not remain
canonical slicing sources for future rebuilds without a Design refresh.

Affected source groups:
- `assets/sprites/enemies/full_frame/*_full_frame_sheet.png` — 11 sheets.
- `assets/sprites/elites/full_frame/*_full_frame_sheet.png` — 10 sheets.
- `assets/sprites/bosses/full_frame/*_full_frame_sheet.png` — 5 sheets.
- `docs/design/references/scrum380_death_rows/*_death_row_reference.png` —
  19 sheets.

Design handoff created:
`docs/tasks/design_animation_source_sheets_safe_gutters_task.md`.

This is not a current gameplay/runtime blocker because active runtime frames are
already extracted individual PNGs and passed the edge-bleed audit. It is a
source compliance blocker for future regeneration/re-slicing from those sheets.

SCRUM-394 resolved the source compliance blocker on 2026-06-14: all 26
full-frame source sheets were repacked to `1704x1144` RGBA, and all 19
SCRUM-380 death-row references were rebuilt to `1704x304` RGBA. Both packs now
use `256x256` cells with `24 px` transparent discard-only gutters and `24 px`
outer padding. Runtime SpriteFrames were not changed. Validation report:
`build/qa/design_animation_source_sheets_safe_gutters/source_sheet_safe_gutters_report.json`.

## QA Artifacts

- `build/qa/animation_sprite_sheet_safe_slicing_audit/animation_manifest.json`
- `build/qa/animation_sprite_sheet_safe_slicing_audit/runtime_frame_audit.json`
- `build/qa/animation_sprite_sheet_safe_slicing_audit/source_sheet_audit.json`

The manifest includes the required `frame_gutter_px`, `outer_padding_px`, and
`safe_slicing_checked` fields. For individual runtime PNG frame sets, those
fields record the required source-sheet contract used by the validator, while
`actual_min_runtime_visual_margin_px` and
`below_standard_runtime_padding_frames` record measured runtime padding.

## Verification

Passed:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_sprite_sheet_safe_slicing_audit/animation_manifest.json
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Runtime smoke was not required: SCRUM-387 changed no runtime registry, scenes,
shared scripts, or gameplay resources.
