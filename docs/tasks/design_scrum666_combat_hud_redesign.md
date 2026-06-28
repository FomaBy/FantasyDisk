# Design Task: SCRUM-666 Combat HUD Redesign

Status: done
Contour: Codex
Owner: QA/Codex
Thread: codex-worker-qa-integrate-scrum666
Locked paths: docs/design/mockups/scrum666_combat_hud_2k/**, docs/design/references/scrum666_combat_hud_2k/**, docs/design/previews/scrum666_combat_hud_2k_*, docs/design/systems/menus_ui.md, docs/design/systems/visual_style_assets.md, docs/design/content_registry.md
Jira: SCRUM-666

## Result

QA-red design revision completed for the essential-only 2K combat HUD source
package. The accepted content zones were moved out of generated rails/ornament
and into the visible empty HUD interiors. The bottom-right level-up plus zone and
pending-count badge zone are now separated with no 2560x1440 overlap. Runtime
wiring files were not touched.

## Evidence

- Spec: `docs/design/mockups/scrum666_combat_hud_2k/spec.md`
- UI plan: `docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json`
- Layout: `docs/design/mockups/scrum666_combat_hud_2k/layout.json`
- Visual frame-zone audit: `docs/design/mockups/scrum666_combat_hud_2k/visual_frame_zone_audit.md`
- OpenAI mockup source: `docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png`
- Safe-zone guide: `docs/design/previews/scrum666_combat_hud_2k_ui_plan_guide.png`
- Layout guide: `docs/design/previews/scrum666_combat_hud_2k_layout_guide.png`
- Debug overlay: `docs/design/previews/scrum666_combat_hud_2k_debug_overlay.png`
- Reports: `ui_plan.report.json`, `layout.guide.report.json`, `composite.report.json`
- Rejected drift evidence kept: `docs/design/previews/scrum666_combat_hud_2k_debug_overlay_rejected_drift.png`, `docs/design/previews/scrum666_combat_hud_2k_composited_preview_rejected_drift.png`, `docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base_rejected_drift.png`

## Checks

- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json`: PASS, `ready_for_image`.
- `render_content_zones.py --layout docs/design/mockups/scrum666_combat_hud_2k/layout.json`: PASS.
- `render_content_zones.py --input docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png --layout ...`: PASS, `ok: true`.
- PNG dimension check: accepted source and preview/debug PNGs are all `2560x1440`.
- Visual QA: regenerated `scrum666_combat_hud_2k_debug_overlay.png` shows HP, XP,
  money, ULT, timer, ascension, level plus and level count zones inside dark
  interiors only; no accepted zone sits on frame rails, gems, crests, rims or
  bottom ornaments.

## Notes

The OpenAI image model enlarged the generated frames relative to the original
requested rectangles. The fix preserves the source art but updates
`ui_plan.json`, `layout.json`, the spec and all accepted preview evidence so
the geometry contract matches the real empty interiors. Future Back-end
integration must use the revised rectangles/guides and avoid the old rejected
rail positions.

Runtime files intentionally untouched: `scripts/ui_screens.gd`,
`scripts/ui/ui_theme_paths.gd`, `tests/runtime_smoke_test.gd`,
`tests/ui_no_overlap_matrix_test.gd`.

Disk cleanup: none created during design revision; no `.godot`, temporary QA
clone, or generated import cache was created.

## QA-Вердикт (2026-06-29)

Статус: PASSED

Проверено:
- `validate_ui_layout_plan.py --plan docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json`: PASS, `decision: ready_for_image`.
- `render_content_zones.py --layout docs/design/mockups/scrum666_combat_hud_2k/layout.json`: PASS, `ok: true`.
- `render_content_zones.py --input docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png --layout ...`: PASS, `ok: true`.
- PNG dimensions for accepted source, checked-in previews, and QA rerenders: PASS, all `2560x1440`.
- `level_button_zone` / `level_badge_zone` overlap: PASS, `(0, 0)` in both `ui_plan.json` and `layout.json`.
- Visual frame-zone QA: PASS; accepted debug overlay places HP, XP, money, ULT, timer, ascension, level plus and pending badge zones inside dark generated interiors, clear of rails, gems, crests, rims and bottom ornaments.
- Runtime scope check: PASS; `scripts/ui_screens.gd`, `scripts/ui/ui_theme_paths.gd`, `tests/runtime_smoke_test.gd`, and `tests/ui_no_overlap_matrix_test.gd` were not changed.
- Integration allowlist check: PASS; only SCRUM-666 task-owned design/doc paths were staged for `dev`.

Баги: нет.

Disk cleanup: QA/integration worktrees and `/tmp/scrum666_qa` are removed after push; no `.godot` cache or runtime import cache is committed.
