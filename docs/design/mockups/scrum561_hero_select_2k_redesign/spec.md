# SCRUM-561 Hero Select v4 2K Redesign Spec

Status: implemented for runtime integration; mandatory UI-director mockup
evidence added by SCRUM-643.

Source screen: `HeroSelectScreen`, `_build_character_select_v4()` in `scripts/ui_screens.gd`.

Design base: `2560x1440`.

Generation note: SCRUM-561 runtime assets were originally produced through the
existing project-approved SCRUM-485 `tools/build_ui_2k_frame_kit.py` pipeline,
which renders exact 2K slot PNGs from Godot constants and validates 9-slice
margins/content bands with anti-drift checks. SCRUM-643 adds the missing
mandatory UI-director / OpenAI Images mockup evidence package for the same
Hero Select 2K geometry.

OpenAI mockup evidence:
- Source mockup PNG: `docs/design/references/scrum561_hero_select_2k_redesign/hero_select_2k_mockup.png`
- Geometry plan: `docs/design/mockups/scrum561_hero_select_2k_redesign/ui_plan.json`
- Planning report: `docs/design/mockups/scrum561_hero_select_2k_redesign/ui_plan.report.json`
- Render layout: `docs/design/mockups/scrum561_hero_select_2k_redesign/layout.json`
- Layout guide report: `docs/design/mockups/scrum561_hero_select_2k_redesign/layout.guide.report.json`
- Mockup render report: `docs/design/mockups/scrum561_hero_select_2k_redesign/mockup_render.report.json`
- UI plan guide: `docs/design/previews/scrum561_hero_select_2k_ui_plan_guide.png`
- Layout guide: `docs/design/previews/scrum561_hero_select_2k_layout_guide.png`
- Labeled preview: `docs/design/previews/scrum561_hero_select_2k_mockup_labeled_preview.png`
- Debug overlay: `docs/design/previews/scrum561_hero_select_2k_mockup_debug_overlay.png`

Planning gate: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\validate_ui_layout_plan.py --plan docs\design\mockups\scrum561_hero_select_2k_redesign\ui_plan.json --guide-output docs\design\previews\scrum561_hero_select_2k_ui_plan_guide.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\ui_plan.report.json` -> `decision: ready_for_image`, `ok: true`.

Mockup render gate: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\render_content_zones.py --input docs\design\references\scrum561_hero_select_2k_redesign\hero_select_2k_mockup.png --layout docs\design\mockups\scrum561_hero_select_2k_redesign\layout.json --output docs\design\previews\scrum561_hero_select_2k_mockup_labeled_preview.png --debug-output docs\design\previews\scrum561_hero_select_2k_mockup_debug_overlay.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\mockup_render.report.json` -> `ok: true`.

Preview evidence:
- Frame contact sheet: `docs/design/previews/ui_2k_frame_kit_contact.png`
- OpenAI source mockup: `docs/design/references/scrum561_hero_select_2k_redesign/hero_select_2k_mockup.png`
- Safe-zone/debug preview: `docs/design/previews/scrum561_hero_select_2k_mockup_debug_overlay.png`
- Render verifier: `python tools/build_ui_2k_frame_kit.py --all`

## 2K Slots

| Element | Const | Slot | Rect / Size | Frame content margins |
|---|---|---|---:|---:|
| Title band | `HS4_TITLE_2K` | text only | `56,40,2448,122` | n/a |
| Back button | `HS4_BACK_2K` | compact runtime button | `56,74,218,54` | compact button content |
| Portrait frame | `HS4_PORTRAIT_FRAME_2K` | `hs4_portrait_panel` | `56,179,661,959` | `58,72,58,66` |
| Portrait content | `HS4_PORTRAIT_SAFE_2K` | inside portrait frame | `114,251,545,821` | no ornament overlap |
| Dossier frame | `HS4_DOSSIER_2K` | `hs4_dossier_panel` | `753,179,1091,959` | `58,72,58,66` |
| Radar frame | `HS4_RADAR_2K` | `hs4_radar_panel` | `1880,179,624,959` | `58,72,58,66` |
| Carousel frame | `HS4_CAROUSEL_2K` | `hs4_carousel_panel` | `56,1155,2448,245` | `104,62,104,56` |
| Choose button | `HS4_CHOOSE_BTN_2K` | `hs4_choose_btn` | `512x89` | `56,32,56,32` |
| Ascension stepper | `HS4_ASC_BTN_2K` | `hs4_asc_btn` | `102x72` | `15,12,15,12` |
| First carousel slot | `HS4_CAROUSEL_SLOT_2K` | content child | `237,1230,101,101` | square inside carousel safe zone |

## Runtime Rules

- All hero portraits, dossier labels, stat rows, radar drawing, carousel arrows, and thumbnails are placed inside the frame content margins, not the frame bounding box.
- The carousel uses a horizontal `hud_strip` margin profile so the content band stays usable while the ornamental strip remains untouched.
- `OVERHAUL_2K_FRAME_*` entries are the single source for asset path, source size, texture margins, and content margins.
- The runtime scales margins from source slot size to current display size with `_overhaul_2k_content_margins()`.

## Generated Runtime Assets

- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_portrait_panel.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_dossier_panel.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_radar_panel.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_carousel_panel.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_choose_btn.png`
- `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_hs4_asc_btn.png`

## Acceptance

- Slot metrics are fixed as 2K constants in `scripts/ui_screens.gd`.
- Runtime Hero Select panels/buttons are connected through `UIThemePaths.OVERHAUL_2K_FRAME_*`.
- Content is placed only in calculated safe zones.
- Required QA: `tests/ui_no_overlap_matrix_test.gd`, `tests/display_resolution_test.gd`, and a UI/runtime smoke pass.

## QA Evidence

- PASS: OpenAI Images API generated textless Hero Select 2K mockup:
  `docs/design/references/scrum561_hero_select_2k_redesign/hero_select_2k_mockup.png`
- PASS: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\validate_ui_layout_plan.py --plan docs\design\mockups\scrum561_hero_select_2k_redesign\ui_plan.json --guide-output docs\design\previews\scrum561_hero_select_2k_ui_plan_guide.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\ui_plan.report.json`
- PASS: `python C:\Users\FomaE\.codex\skills\content-zone-image-compositor\scripts\render_content_zones.py --input docs\design\references\scrum561_hero_select_2k_redesign\hero_select_2k_mockup.png --layout docs\design\mockups\scrum561_hero_select_2k_redesign\layout.json --output docs\design\previews\scrum561_hero_select_2k_mockup_labeled_preview.png --debug-output docs\design\previews\scrum561_hero_select_2k_mockup_debug_overlay.png --report docs\design\mockups\scrum561_hero_select_2k_redesign\mockup_render.report.json`
- PASS: `python tools\build_ui_2k_frame_kit.py --verify`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/display_resolution_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`

SCRUM-643 result: missing mandatory Hero Select mockup evidence is resolved by
the OpenAI source mockup, validated `ui_plan.json`, `layout.json`, preview guide,
debug overlay and renderer reports listed above. No runtime UI scripts, combat
HUD files, or button wiring were changed.

Jira sync note: `SCRUM-561` was commented and transitioned to QA directly. A repository-wide `jira_board_sync.py` run required Windows compatibility fixes, then hit an unrelated Jira create/fixVersion problem and a long no-create sync timeout; no unrelated Jira statuses were intentionally changed by this task.
