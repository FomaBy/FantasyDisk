# Weapon Select PixelLab Mockup Runtime Apply

Jira: SCRUM-868
Статус: done
Контур: Codex
Owner: codex-ui-runtime-apply-scrum868
Thread: current Codex worker
Worktree: /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum868_weapon_select_runtime_20260704103131
Branch: codex/scrum868-weapon-select-runtime-20260704103131
Locked paths: scripts/ui_screens.gd; tests/runtime_smoke_test.gd; tests/runtime_smoke_ui_test.gd; tests/ui_no_overlap_matrix_test.gd; docs/design/mockups/weapon_select_full_redraw/; docs/design/systems/menus_ui.md; docs/design/ui_screens_inventory.md; docs/design/systems/visual_style_assets.md; docs/design/current_game_state.md

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

- [x] Live Weapon Select uses the accepted PixelLab visual layer or derived runtime-ready UI assets from `docs/design/mockups/weapon_select_full_redraw/`.
- [x] Runtime labels/icons remain editable Godot controls and fit inside the visible empty zones.
- [x] The implementation is visible at 1280x720, 1920x1080, and 2560x1440 without clipping or frame overlap.
- [x] UI smoke/no-overlap and relevant runtime smoke pass.
- [x] Jira/local mirror include changed files, tests, commit/push evidence, and disk cleanup.

## Result

Done 2026-07-04 by `codex-ui-runtime-apply-scrum868`.

- Live Weapon Select now instantiates `WeaponSelectPixelLabRuntimeLayer`, loaded from `res://docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_runtime_layer_2560x1440.png`.
- The runtime layer is derived from the accepted SCRUM-867 textless PixelLab mockup and provides the visible outer panel, title card, weapon card frames, and lower Back ornament in-game.
- Runtime text, weapon icons, Back behavior, focus, hover, pressed, and card selection remain live Godot controls. Card and Back button frames are transparent hit areas with subtle tint overlays so the PixelLab frame art is not double-framed.
- Weapon card content remains inside the SCRUM-867 empty zones and preserves title, `Отличие:`, description, role/scale, stats, and 150x150 weapon icon contract.
- Docs updated with exact runtime asset usage and deviation from the SCRUM-867 preview-only package.

Changed files:

- `scripts/ui_screens.gd`
- `tests/runtime_smoke_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_runtime_layer_2560x1440.png`
- `docs/design/mockups/weapon_select_full_redraw/spec.md`
- `docs/design/mockups/weapon_select_full_redraw/layout.json`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/ui_screens_inventory.md`
- `docs/design/current_game_state.md`

## Verification

Passed:

- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum868_weapon_select_runtime_20260704103131 --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum868_weapon_select_runtime_20260704103131 --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum868_weapon_select_runtime_20260704103131 --script res://tests/runtime_smoke_test.gd`
- `git diff --check`

Screenshot capture: attempted from `tests/runtime_smoke_test.gd`; headless dummy renderer blocked it with `blocked: viewport image unavailable`, recorded in `build/qa/weapon_select_clean_layout.md`. The rect dump confirms `WeaponOption_*` live content at `[P: (443.0, 398.0), S: (1674.0, 240.0)]`, `[P: (443.0, 652.0), S: (1674.0, 240.0)]`, and `[P: (443.0, 906.0), S: (1674.0, 240.0)]` for each character.

Commit/push evidence: SCRUM-868 implementation commit on `codex/scrum868-weapon-select-runtime-20260704103131`, pushed to `origin/dev`; exact commit hash recorded in the Jira final comment.

Disk cleanup: no task-owned caches or sidecars committed; disposable worktree removal and `git worktree prune` are performed after push and recorded in the Jira final comment.

## QA-Вердикт (2026-07-04)

Статус: PASSED

Verified by `codex-qa-scrum868-20260704110240` from clean QA worktree `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum868_20260704110240`.

- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum868_20260704110240 --script res://tests/runtime_smoke_ui_test.gd` - PASS (`Runtime UI smoke suite passed.`)
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum868_20260704110240 --script res://tests/ui_no_overlap_matrix_test.gd` - PASS (`UI no-overlap matrix test passed.`)
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum868_20260704110240 --script res://tests/runtime_smoke_test.gd` - PASS (`Runtime smoke test passed.`)
- `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum868_20260704110240 --script res://tests/gamepad_menu_focus_test.gd` - PASS (`Gamepad menu focus navigation test passed.`)
- Runtime evidence: `scripts/ui_screens.gd` instantiates `WeaponSelectPixelLabRuntimeLayer` from `res://docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_runtime_layer_2560x1440.png`; runtime smoke asserts the layer path, live 150x150 icons, `Отличие:` identity labels, role/stats labels, and Back button.
- Responsive evidence: `build/qa/ui_no_overlap_matrix.md` and `build/qa/scrum489/results_block_no_overlap_matrix.md` cover 1152x648, 1280x720, 1536x864, 1600x900, 1920x1080, 2560x1440, and 3840x2160. Weapon Select reports three live `WeaponOption_*` controls and `text controls checked: 18` per viewport without overlap failures.
- Clean layout evidence: `build/qa/weapon_select_clean_layout.md` covers all playable classes and confirms the three SCRUM-867 card content rects at 2K source-space `[P: (443.0, 398.0), S: (1674.0, 240.0)]`, `[P: (443.0, 652.0), S: (1674.0, 240.0)]`, and `[P: (443.0, 906.0), S: (1674.0, 240.0)]`.
- Mouse/keyboard/gamepad flow and Back behavior remained covered by the runtime UI, runtime, and gamepad focus smokes.

Note: headless dummy renderer still blocks screenshot capture with `viewport image unavailable` / `Parameter "t" is null`; this is non-blocking because rect, layer, content, and focus assertions passed.

Bugs: none.
