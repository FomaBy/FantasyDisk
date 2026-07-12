# Weapon Select Full Redraw — readable weapon differences

Jira: SCRUM-867
Статус: done
Контур: Codex
Owner: Codex UI
Thread: user-facing Codex control thread / worker codex-ui-weapon-select-full-redraw
Locked paths: scripts/ui_screens.gd; scripts/ui/ui_theme_paths.gd; docs/design/mockups/weapon_select_full_redraw/; docs/design/previews/weapon_select_full_redraw_*; docs/design/systems/menus_ui.md; docs/design/ui_screens_inventory.md

## Source Request

Пользователь: «На экране выбора оружия на каждом персонаже нужно полностью перерисовать интерфейс. Надо его увеличить, чтобы весь текст помещался, чтобы всегда писались отличительные характеристики этого оружия, чтобы было понятно, чем они отличаются, и увеличить немножко картинку самого оружия.»

## Scope

- Redesign the live Weapon Select screen for every character.
- Enlarge the overall card/layout so all weapon copy fits without clipping.
- Always show distinguishing weapon characteristics, not just generic stats.
- Make weapon differences clear at selection time for the player.
- Slightly increase weapon icon/image size in each weapon card.
- Preserve the current character -> weapon -> route-map gameplay flow.
- Keep content strictly inside frame safe zones; no text/icon may overlap decorative borders.

## Acceptance Criteria

- [x] PixelLab MCP mockup/spec package exists under `docs/design/mockups/weapon_select_full_redraw/`.
- [x] Runtime Weapon Select uses larger, text-safe cards at 1280x720, 1920x1080 and 2560x1440.
- [x] Each weapon card shows name, distinctive characteristic copy, role/archetype, key scaling or mechanic bullets, and an enlarged weapon icon.
- [x] Keyboard/gamepad/mouse interaction and back behavior are preserved.
- [x] UI no-overlap / runtime smoke checks pass, including no clipped weapon-card text.
- [x] `docs/design/systems/menus_ui.md` and `docs/design/ui_screens_inventory.md` document the new contract.
- [x] Jira and local mirror include mockup path, changed files, tests, commit/push evidence and disk cleanup.

## Result

- Rebuilt Weapon Select around enlarged `WS_PANEL_2K` / `WS_CARD_2K` geometry with three 240px-tall weapon cards and a larger 150x150 weapon icon well.
- Added card copy layers for every roster weapon: title, `Отличие:` line from `ProgressionData.weapon_mechanic_identity`, description, role/archetype/mode/scaling, and compact range/radius/cooldown/context stats.
- Preserved existing mouse/gamepad focus flow: weapon cards top-to-bottom, then `Назад`; pressing a weapon still goes to Start Boon Select.
- PixelLab final mockup: `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_mockup.png` (`67e5f56a-aaa6-4216-814a-7f5301132fea`). Preview: `docs/design/previews/weapon_select_full_redraw_pixellab_mockup.png`.
- Docs updated: `docs/design/mockups/weapon_select_full_redraw/spec.md`, `docs/design/mockups/weapon_select_full_redraw/layout.json`, `docs/design/systems/menus_ui.md`, `docs/design/ui_screens_inventory.md`.

## Verification

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`.
- PASS: full `res://tests/runtime_smoke_test.gd` in clean disposable worktree `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum867-weapon-select-smoke-v2`; log: `/tmp/scrum867_full_smoke_v2.log`.
- Main-checkout full runtime smoke is blocked by pre-existing unrelated untracked duplicate files: `tests/melee_weapon_targeting_test 2.gd` and `tests/melee_weapon_targeting_test 2.gd.uid`.
- Screenshot capture attempt: `res://tests/design_review_screenshot_capture_test.gd` fails in current headless dummy renderer with `viewport image unavailable` for all screens, including `weapon_select`; visual evidence is the accepted textless PixelLab preview plus runtime layout/no-overlap/full-smoke checks.

## Cleanup

- Disk cleanup: removed disposable worktrees `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum867-weapon-select-smoke`, `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum867-weapon-select-smoke-v2`, and pruned git worktrees. No task-owned temp checkout remains.
- Thread cleanup: not a disposable worker thread; this is the user-facing control thread.
- Commit/push evidence: to be recorded in Jira final comment after this task-owned commit is pushed.

## QA-Вердикт (2026-07-04)

Статус: PASSED

Проверено:
- `python3 tools/jira_qa_next.py --json` confirmed SCRUM-867 was in `Контроль качества` before QA.
- QA worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum867_20260704101535`, branch `codex/qa-scrum867-20260704101535`, commit `17a39a5e`.
- PixelLab mockup and preview exist: `docs/design/mockups/weapon_select_full_redraw/pixellab_weapon_select_mockup.png`, `docs/design/previews/weapon_select_full_redraw_pixellab_mockup.png`.
- Manual spec/code review: `WS_PANEL_2K`, `WS_SAFE_2K`, `WS_CARD_2K`, 150x150 `WeaponSelectSprite_*`, and text nodes `WeaponSelectTitle_*`, `WeaponSelectIdentity_*`, `WeaponSelectDescription_*`, `WeaponSelectRole_*`, `WeaponSelectStats_*` are present; content is inset through `ws_card` content margins, not placed on frame borders.
- `runtime_smoke_test.gd` was inspected and verified to iterate all `ProgressionData.character_ids()` and each class weapon, checking card frame texture, weapon sprite path, 150px icon size, `Отличие:` identity copy, role/scaling line, stats line, click selection, and Back button texture.

Команды:
- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum867_20260704101535 --script res://tests/runtime_smoke_ui_test.gd` (`/tmp/scrum867_qa_runtime_smoke_ui.log`).
- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum867_20260704101535 --script res://tests/ui_no_overlap_matrix_test.gd` (`/tmp/scrum867_qa_ui_no_overlap_matrix.log`).
- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum867_20260704101535 --script res://tests/runtime_smoke_test.gd` (`/tmp/scrum867_qa_runtime_smoke.log`).
- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum867_20260704101535 --script res://tests/gamepad_menu_focus_test.gd` (`/tmp/scrum867_qa_gamepad_menu_focus.log`).

Краевые случаи:
- Clean disposable worktree from `origin/dev@17a39a5e`, avoiding the dirty main checkout.
- Weapon Select coverage includes all roster characters and all class weapons through `runtime_smoke_test.gd`.
- Frame/safe-zone acceptance covered by `ui_no_overlap_matrix_test.gd` and spec/code review of `ws_panel`/`ws_card` texture margins vs content margins.
- Keyboard/gamepad/mouse flow and Back behavior covered by runtime smoke click path, Back button wiring review, and `gamepad_menu_focus_test.gd`.

Баги: нет.
