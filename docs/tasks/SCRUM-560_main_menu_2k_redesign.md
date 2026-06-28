# SCRUM-560 - UI-редизайн: Главное меню (@2K)

Статус: review
Owner: design-codex-auto-2
Jira: https://fantasydisk.atlassian.net/browse/SCRUM-560
Контур: Codex

## Scope

- Screen: `MainMenuScreen`, `_show_main_menu`.
- Locked paths:
  - `scripts/ui_screens.gd`
  - `assets/backgrounds/main_menu_epic_battle_v3.png`
  - `docs/design/references/scrum560_main_menu_2k/`
  - `docs/design/mockups/scrum560_main_menu_2k/`
  - `docs/design/backups/scrum560_main_menu_2k/`

## Result

- Generated a 2560x1440 full mockup preview for the SCRUM-560 design pass.
- Generated a clean runtime background without baked UI text/buttons/frames and installed it at the existing canonical main-menu background path.
- Preserved the existing minimal-metal runtime button theme and 6-button action stack.
- Added `MM_TITLE_2K` and runtime `MainMenuTitleLabel` so the screen now has a title plus the six action buttons required by the task.
- Documented content zones, exact 2K slots, frame content margins, runtime asset path, and backup path in `docs/design/mockups/scrum560_main_menu_2k/spec.md`.

## Evidence

- Mockup: `docs/design/references/scrum560_main_menu_2k/main_menu_mockup.png`
- Runtime background source: `docs/design/references/scrum560_main_menu_2k/main_menu_runtime_background_v3.png`
- Runtime asset: `assets/backgrounds/main_menu_epic_battle_v3.png`
- Previous runtime backup: `docs/design/backups/scrum560_main_menu_2k/main_menu_epic_battle_v3_pre_scrum560.png`

## QA

- PASS: `tests/ui_no_overlap_matrix_test.gd`
- PASS: `tests/display_resolution_test.gd`
- PASS: `tests/runtime_smoke_ui_test.gd`
- PASS: `tests/runtime_smoke_test.gd`
- Known unrelated failure: `tests/dark_fantasy_ui_theme_test.gd` fails on HUD panel runtime texture mismatch, not on the SCRUM-560 main menu changes.
