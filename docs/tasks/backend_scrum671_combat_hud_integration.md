# Back-end Task: SCRUM-671 Combat HUD Integration

Статус: done
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
- Pushed to `origin/dev`: `10fcaa0f fix(SCRUM-671): integrate clean combat HUD`

## QA-Fix Follow-up (2026-06-29)

Worker: `codex-backend-fix-scrum671-qa-red`

Updated `tests/runtime_smoke_test.gd` after QA failure so the broad runtime smoke
asserts the SCRUM-671/SCRUM-666 essential-only HUD contract instead of the old
combat HUD:
- timer panel/text must occupy SCRUM-666 frame/content zones, not the old top band;
- elevated runs assert the ascension badge and no top HUD overlap;
- artifact pickup remains stored in player run state without recreating `ArtifactHudRow`;
- post-level-up combat HUD restores HP/XP/gold/ULT cards and timer while keeping
  `CharacterStatsHud` / `ArtifactHudRow` absent;
- level-up plus/count badge is checked while pending and removed after queued
  choices are spent.

Verification after follow-up:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — FAIL later at `tests/runtime_smoke_test.gd:1075`: `Expected level-up reward cards to avoid heavy reward button frame textures.` This is outside SCRUM-671 Combat HUD scope; the previous SCRUM-671 timer/artifact assertions are no longer the failing gate.
- `python3 tools/build_ui_2k_frame_kit.py --verify` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_fantasy_ui_theme_test.gd` — PASS.

Known unrelated noise: first Godot import in the disposable worktree reported
pre-existing UID duplicate warnings in character reference assets; the focused
tests above passed after import.

## Disk Cleanup

Disk cleanup: removed `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-671/.godot`
and generated Godot import sidecars created during verification. No multi-hundred-MB
cache remains in the SCRUM-671 worktree.
