# SCRUM-466 Minimal-Metal No-Seams Frame Spec

Status: Design/source complete, awaiting QA visual acceptance.
Task: SCRUM-466
Date: 2026-06-17

## Goal

Remove internal gold seam/divider pixels from the scalable center of the active
minimal-metal frame kit so Godot 9-slice scaling cannot draw ornament through UI
content. This preserves the global frame rule: content lives only in the empty
inner zone and never overlaps frame ornament.

## Source And Runtime Paths

- Clean source sheet: `docs/design/references/ui_minimal_metal/scrum466_minimal_metal_frame_source_sheet_no_seams.png`
- Metadata/audit: `docs/design/references/ui_minimal_metal/scrum466_minimal_metal_no_seams_metadata.json`
- Clean source candidates: `docs/design/references/ui_minimal_metal/scrum466_no_seams/frames_clean/`
- Runtime PNGs updated in place: `assets/sprites/ui/frames/minimal_metal/`
- Pre-clean backups: `docs/design/backups/scrum466_minimal_metal_preclean/`
- Visual contact: `docs/design/previews/scrum466_minimal_metal_no_seams_visual_contact.png`
- Safe-zone/stretch-core contact: `docs/design/previews/scrum466_minimal_metal_no_seams_contact.png`
- QA copies: `build/qa/scrum466/minimal_metal_before_contact.jpg`, `build/qa/scrum466/minimal_metal_after_contact.jpg`, `build/qa/scrum466/minimal_metal_after_visual_contact.jpg`

## Cleanup Rule

Each frame keeps its outer 9-slice border regions intact. The stretch core inside
`texture_margins_ltrb` is flattened to a quiet dark translucent fill. That means
the scalable center contains no bright brass/gold rail pixels and no pale opaque
wash; any border metal remains outside the stretch core.

Audit result: all six frame types have `gold_or_bright_pixels_in_stretch_core = 0`
and `pale_opaque_pixels_in_content_rect = 0`.

## Margins And Safe Zones

| Frame | Texture margins LTRB | Content margins LTRB | Content rect XYWH |
| --- | --- | --- | --- |
| modal | 46, 62, 46, 58 | 72, 92, 72, 84 | 72, 92, 842, 724 |
| panel | 38, 52, 38, 48 | 58, 72, 58, 66 | 58, 72, 666, 578 |
| card | 32, 42, 32, 40 | 46, 58, 46, 54 | 46, 58, 334, 374 |
| tooltip | 46, 30, 46, 28 | 66, 44, 66, 40 | 66, 44, 628, 158 |
| hud_strip | 76, 42, 76, 40 | 104, 62, 104, 56 | 104, 62, 914, 170 |
| field | 42, 38, 42, 36 | 58, 52, 58, 48 | 58, 52, 500, 186 |

Runtime content must stay inside the listed content rect after proportional
scaling. The strip between texture margins and content margins is reserve space;
it must stay free of labels, icons, controls, portraits, text fields and buttons.

## QA Notes

Headless screenshot recapture with `tests/design_review_screenshot_capture_test.gd`
was attempted from this shell, but Godot used the dummy renderer and returned
`viewport image unavailable`; no new target screen PNGs were generated in that
mode. Asset-level contacts and pixel audits were generated instead, and standard
headless smokes passed:

- `tests/ui_no_overlap_matrix_test.gd` — PASS
- `tests/runtime_smoke_ui_test.gd` — PASS
- `tests/runtime_smoke_test.gd` — PASS

Visual QA should recapture Battle Reward, Upgrade, Attribute Shop, Event and
Feedback with a renderer-capable run before closing SCRUM-466 as QA PASSED.
