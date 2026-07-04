# Weapon Select PixelLab Mockup Runtime Apply

Jira: SCRUM-868
Статус: new
Контур: Codex
Owner: unassigned
Thread: n/a
Locked paths: scripts/ui_screens.gd; tests/runtime_smoke_test.gd; tests/runtime_smoke_ui_test.gd; tests/ui_no_overlap_matrix_test.gd; docs/design/mockups/weapon_select_full_redraw/; docs/design/systems/menus_ui.md; docs/design/ui_screens_inventory.md

## Source Request

Пользователь: "Так это надо применить, чтобы оно было в игре."

Context: SCRUM-867 created and QA-passed the enlarged Weapon Select runtime layout plus PixelLab textless mockup package. The follow-up asks to ensure the accepted PixelLab visual layer is actually applied in-game, not only stored as preview/spec evidence.

## Scope

- Apply the accepted textless PixelLab Weapon Select mockup/art layer to the live Godot Weapon Select screen so the in-game screen visibly follows the mockup.
- Keep runtime text, weapon icons, focus states, and buttons as live controls, not baked into the image.
- Preserve the SCRUM-867 readable card contract: title, `Отличие:`, description, role/scale line, stats, and enlarged weapon image.
- Preserve mouse/gamepad/keyboard selection flow and Back behavior.
- Maintain the hard frame safe-zone rule: content may not overlap borders, gems, ornaments, bevels, or decorative corners.
- Update mockup/spec docs if runtime bounds or asset usage differ from SCRUM-867.

## Acceptance Criteria

- [ ] Live Weapon Select uses the accepted PixelLab visual layer or derived runtime-ready UI assets from `docs/design/mockups/weapon_select_full_redraw/`.
- [ ] Runtime labels/icons remain editable Godot controls and fit inside the visible empty zones.
- [ ] The implementation is visible at 1280x720, 1920x1080, and 2560x1440 without clipping or frame overlap.
- [ ] UI smoke/no-overlap and relevant runtime smoke pass.
- [ ] Jira/local mirror include changed files, tests, commit/push evidence, and disk cleanup.
