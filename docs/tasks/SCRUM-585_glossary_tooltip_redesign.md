# SCRUM-585 - UI Redesign: Glossary Tooltip

Статус: done
Контур: Codex
Owner: Design / Designer 2
Thread: codex-background-designer-agent
Locked paths: `scripts/ui_screens.gd`, `scripts/ui/ui_theme_paths.gd`, `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png`, `docs/design/mockups/scrum585_glossary_tooltip/`, `docs/design/previews/scrum585_glossary_tooltip_*`
Jira: SCRUM-585

## Scope

Designer 2 owns the isolated glossary tooltip metrics, generated UI frame asset,
mockup/spec, and visual validation evidence. No broad full-screen package,
gameplay, balance, animation, or unrelated UI screen changes are in scope.

## Metrics Plan

- Base resolution: `2560x1440`.
- Runtime panel: fixed width `460`, content-driven height, template `460x140`.
- Viewport clamp: `16` px from each edge.
- Anchor gap: `8` px below the glossary term anchor.
- Frame texture margins: `Vector4(46, 30, 46, 28)`.
- Frame content margins: `Vector4(66, 44, 66, 40)`.
- Runtime text remains inside the content zone; no text is baked into the frame asset.

## Result

- Mockup/spec package: `docs/design/mockups/scrum585_glossary_tooltip/`
- OpenAI mockup: `docs/design/mockups/scrum585_glossary_tooltip/mockup.png`
- Runtime frame: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png`
- Frame source: `docs/design/references/scrum585_glossary_tooltip/scrum585_glossary_tooltip_frame_source.png`
- Alpha-cleaned source: `docs/design/references/scrum585_glossary_tooltip/scrum585_glossary_tooltip_frame_alpha.png`
- Safe-zone preview: `docs/design/previews/scrum585_glossary_tooltip_safe_zone.png`
- Contact/fit preview: `docs/design/previews/scrum585_glossary_tooltip_contact.png`
- Audit report: `docs/design/mockups/scrum585_glossary_tooltip/asset_audit.json`

## Validation

- Asset audit PASS: `460x140` RGBA, `edge_alpha_max=0`, `white_opaque_pixels=0`, `green_opaque_pixels=0`.
- Safe zone: content rect `Rect2(66,44,328,56)` stays inside the empty center; runtime text does not cover rails, corner claws, or ruby pins.
- Runtime constants now use `GT_PANEL_2K`, `GT_PANEL_CONTENT_2K`, `GT_VIEWPORT_MARGIN_2K`, `GT_ANCHOR_GAP_2K`, `GT_TITLE_FONT_SIZE`, `GT_DESC_FONT_SIZE`, and `GT_TEXT_SEPARATION`.
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/display_resolution_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd`
- Broad `runtime_smoke_test.gd` was attempted after the focused checks; direct run exited `137` after the duplicate-artifact guard, and the semaphore rerun crashed in Godot log startup before test output. Treated as an environment/runtime issue, not SCRUM-585 acceptance evidence.
