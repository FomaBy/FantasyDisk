# Weapon Select Redraw From Scratch

Jira: SCRUM-870
Статус: done
Контур: Codex
Owner: codex-ui-redraw-scrum870
Thread: user-facing Codex control thread / local worker codex-ui-redraw-scrum870
Worktree: /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum870_weapon_select_redraw_20260704
Branch: codex/scrum870-weapon-select-redraw-20260704
Locked paths: scripts/ui_screens.gd; tests/runtime_smoke_test.gd; tests/runtime_smoke_ui_test.gd; tests/ui_no_overlap_matrix_test.gd; tests/gamepad_menu_focus_test.gd; docs/design/mockups/weapon_select_redraw_from_scratch/; docs/design/previews/weapon_select_redraw_from_scratch_*; docs/design/systems/menus_ui.md; docs/design/systems/visual_style_assets.md; docs/design/ui_screens_inventory.md; docs/design/current_game_state.md

## Source Request

Пользователь после проверки live screenshot 2026-07-04:

> "перерисуй выбор оружия с нуля. Это плохо думай лучше"

Screenshot evidence: `/var/folders/04/lm6sv2kn41v4xdmj47hvptf00000gn/T/codex-clipboard-95f28f32-94f6-4c8b-845a-fb1a5605424a.png`.

Context: SCRUM-867/SCRUM-868 made the Weapon Select screen larger and applied a PixelLab full-screen layer, but the live result is visually unacceptable: low contrast, text over busy/baked art, wasted stat grid, double-framed cards, weak hierarchy, and visible edge artifacts. This task supersedes the SCRUM-868 runtime approach.

## Scope

- Redraw the Weapon Select screen from scratch in the live game, not as a patch over the current screenshot.
- Remove or disable the bad `WeaponSelectPixelLabRuntimeLayer` full-screen runtime approach from live Weapon Select.
- Create a fresh PixelLab MCP mockup/spec package under `docs/design/mockups/weapon_select_redraw_from_scratch/` before runtime implementation.
- Build the Godot screen as real runtime UI controls: readable text, weapon icons, stat/identity zones, focus/hover states, and Back action must not be baked into the image.
- Preserve the gameplay flow: character select -> weapon select -> start boon / route-map flow, with mouse, keyboard, and gamepad support.
- For every character and every weapon option, always show:
  - weapon name;
  - a short distinct identity line (`Отличие:`) explaining why this option differs;
  - a readable mechanic summary, not a clipped paragraph;
  - compact key stats (range/radius, cooldown, damage/context, archetype/control);
  - a larger, clean weapon picture.
- Make the visual hierarchy clear at a glance: title/subtitle, three selectable weapon cards, current selected/hover state, and Back action.
- Keep all content strictly inside frame safe zones. No text, icons, buttons, or card content may overlap ornament, border, gems, bevels, or decorative corners.
- Update docs with the final live contract and note that SCRUM-868's full-layer result was superseded.

## Acceptance Criteria

- [ ] PixelLab MCP mockup/spec package exists and is documented under `docs/design/mockups/weapon_select_redraw_from_scratch/`.
- [ ] Live Weapon Select no longer renders the bad full-screen `WeaponSelectPixelLabRuntimeLayer` from SCRUM-868.
- [ ] Runtime card layout is readable at 1280x720, 1920x1080, and 2560x1440 without text clipping or content-on-frame overlap.
- [ ] Every weapon option for every playable character shows clear distinguishing identity copy and concise mechanic/stat context.
- [ ] Weapon images are visibly larger than pre-SCRUM-867 legacy cards and remain inside their icon wells.
- [ ] Mouse, keyboard, gamepad focus, select, and Back behavior are preserved.
- [ ] UI no-overlap, UI smoke, gamepad menu focus, and full runtime smoke pass from a clean worktree.
- [ ] Jira/local mirror include changed files, mockup/spec paths, test evidence, commit/push evidence, and disk cleanup.

## Implementation Notes

- Do not reuse the SCRUM-868 full-screen PixelLab layer as the live background.
- Prefer a clean runtime layout with dark interior panels and high-contrast Godot labels, backed by textless PixelLab art/style zones.
- Keep generated art textless unless used only as reference/mockup evidence.
- If the final implementation deviates from the mockup geometry, update the spec first and record why.

## Result

Implemented SCRUM-870 as a from-scratch live Weapon Select redraw:

- Created PixelLab MCP textless reference package:
  `docs/design/mockups/weapon_select_redraw_from_scratch/` and preview
  `docs/design/previews/weapon_select_redraw_from_scratch_pixellab_mockup.png`
  from PixelLab UI asset `ecd9f24e-b8a6-4a54-a824-f0f4d5a59505`.
- Removed the rejected SCRUM-868 `WeaponSelectPixelLabRuntimeLayer` from live
  `_show_weapon_select()`; tests now fail if that node appears again.
- Rebuilt the runtime screen with native opaque Godot UI surfaces: readable dark
  shell, three large `1674x260` `WeaponOption_*` cards, `204x204` icon wells,
  larger `176x176` weapon sprites, concise mechanic summaries, `Отличие:`
  identity copy, role/scaling copy, and right-side stat panels.
- Preserved mouse/keyboard/gamepad flow, card activation, Back behavior, and
  character -> weapon -> next-run-screen navigation.
- Updated UI/current-state/mockup docs so SCRUM-870 is the active live contract
  and SCRUM-867/SCRUM-868 full-layer files are historical evidence only.

Commit/push evidence: recorded in the final Jira comment after Git sync.

Disk cleanup: transient Godot sidecars/import cache cleaned before final report;
disposable implementation worktree removal is recorded in the final Jira comment
after push.

## Verification

Passed:

- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum870_weapon_select_redraw_20260704 --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum870_weapon_select_redraw_20260704 --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum870_weapon_select_redraw_20260704 --script res://tests/gamepad_menu_focus_test.gd`
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum870_weapon_select_redraw_20260704 --script res://tests/runtime_smoke_test.gd`

Note: headless screenshot capture still logs the known dummy-renderer
`texture_2d_get` warning from `_try_capture_weapon_select_screenshot`, but the
UI smoke and full runtime smoke suites pass.

## QA-Вердикт

Статус: PASSED
Проверено: SCRUM-870 live Weapon Select redraw, no-overlap/style assertions,
gamepad focus, and full runtime smoke.
