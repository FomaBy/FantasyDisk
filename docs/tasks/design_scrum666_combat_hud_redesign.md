# Design Task: SCRUM-666 Combat HUD Redesign

Status: review
Contour: Codex
Owner: Design/Codex
Thread: codex-design-scrum-666
Locked paths: docs/design/mockups/scrum666_combat_hud_2k/**, docs/design/references/scrum666_combat_hud_2k/**, docs/design/previews/scrum666_combat_hud_2k_*, docs/design/systems/menus_ui.md, docs/design/systems/visual_style_assets.md, docs/design/content_registry.md
Jira: SCRUM-666

## Result

Prepared a Design/UI source package for an essential-only 2K combat HUD: HP, XP,
money, ULT charge, timer, ascension/elevation badge, and one bottom-right
level-up plus button. Runtime wiring files were not touched.

## Evidence

- Spec: `docs/design/mockups/scrum666_combat_hud_2k/spec.md`
- UI plan: `docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json`
- Layout: `docs/design/mockups/scrum666_combat_hud_2k/layout.json`
- OpenAI mockup source: `docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png`
- Safe-zone guide: `docs/design/previews/scrum666_combat_hud_2k_ui_plan_guide.png`
- Layout guide: `docs/design/previews/scrum666_combat_hud_2k_layout_guide.png`
- Debug overlay: `docs/design/previews/scrum666_combat_hud_2k_debug_overlay.png`
- Reports: `ui_plan.report.json`, `layout.guide.report.json`, `composite.report.json`

## Checks

- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json`: PASS, `ready_for_image`.
- `render_content_zones.py --layout docs/design/mockups/scrum666_combat_hud_2k/layout.json`: PASS.
- `render_content_zones.py --input docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png --layout ...`: PASS, `ok: true`.

## Notes

The OpenAI image model produced useful dark-fantasy HUD art but did not obey
pixel coordinates exactly. Future Back-end integration must use the validated
rectangles and guides as the authoritative contract, not the generated bitmap as
a direct runtime atlas.
