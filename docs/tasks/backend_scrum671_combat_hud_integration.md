# Back-end Task: SCRUM-671 Combat HUD Integration

Статус: review
Jira: SCRUM-671
Контур: Codex
Owner: Back-end/UI integration
Thread/Worker: codex-backend-scrum671
Locked paths: `scripts/ui_screens.gd`, `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, scoped UI docs

## Source Package

- Design source: `docs/design/mockups/scrum666_combat_hud_2k/spec.md`
- UI plan: `docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json`
- Layout: `docs/design/mockups/scrum666_combat_hud_2k/layout.json`
- Preview: `docs/design/previews/scrum666_combat_hud_2k_composited_preview.png`

## Result

Runtime combat HUD now follows the SCRUM-666 clean essential-only contract:
HP, XP, money, ULT charge, timer, ascension/elevation, and the bottom-right
level-up plus/count control only.

The previous combat-only `CharacterStatsHud` strip and `ArtifactHudRow` are no
longer created by `_create_hud()`. Existing generated HUD/theme assets remain in
use; no new runtime art was sliced from the full-screen SCRUM-666 RGB mockup.
Instead, runtime controls expose and use SCRUM-666 safe-zone metadata for the
accepted content rectangles, while the generated frame-kit `CHUD_*` constants
remain reserved for actual asset-slot anti-drift verification.

## Changed Files

- `scripts/ui_screens.gd`
- `tests/runtime_smoke_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/current_game_state.md`
- `docs/tasks/backend_scrum671_combat_hud_integration.md`

## Verification

- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` — PASS
- `python3 tools/build_ui_2k_frame_kit.py --verify` — PASS

Known unrelated noise: first Godot import in the disposable worktree reported
pre-existing UID duplicate warnings in character reference assets; the focused
tests above passed after import.

## Disk Cleanup

Pending final closure. Disposable `.godot/` import cache was created by Godot
verification and must be removed before final task report if the worktree is
removed or left clean.
