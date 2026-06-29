# SCRUM-560 Main Menu 2K Mockup Spec

Status: implemented
Owner: design-codex-auto-2
Jira: SCRUM-560
Screen: `MainMenuScreen` / `_show_main_menu`
Design base: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160

## Generated Sources

- Mockup preview: `docs/design/references/scrum560_main_menu_2k/main_menu_mockup.png`
- Runtime background source: `docs/design/references/scrum560_main_menu_2k/main_menu_runtime_background_v3.png`
- Runtime asset: `assets/backgrounds/main_menu_epic_battle_v3.png`
- Previous runtime backup: `docs/design/backups/scrum560_main_menu_2k/main_menu_epic_battle_v3_pre_scrum560.png`

Generation was done through the required `fantasydisk-asset-generator` pipeline with `gpt-image-2`, high quality, 2560x1440 PNG output. The runtime background intentionally contains no baked UI text, buttons, frames, or logos; Godot owns all interactive and readable UI.

## Runtime Layout

| Slot | Const / node | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Background | `MainMenuBackground` | 0 | 0 | 2560 | 1440 |
| Title | `MM_TITLE_2K` / `MainMenuTitleLabel` | 640 | 72 | 1280 | 150 |
| Button column safe area | `MM_BUTTON_COLUMN_2K` / `MM_SAFE_2K` | 72 | 383 | 380 | 674 |
| Start | `MM_BTN_START_2K` / `MainMenuStartButton` | 72 | 383 | 380 | 104 |
| Settings | `MM_BTN_SETTINGS_2K` / `MainMenuSettingsButton` | 72 | 497 | 380 | 104 |
| Skill tree | `MM_BTN_SKILLTREE_2K` / `MainMenuSkillTreeButton` | 72 | 611 | 380 | 104 |
| Patch notes | `MM_BTN_PATCHNOTES_2K` / `MainMenuPatchNotesButton` | 72 | 725 | 380 | 104 |
| Codex | `MM_BTN_CODEX_2K` / `MainMenuCodexButton` | 72 | 839 | 380 | 104 |
| Exit | `MM_BTN_EXIT_2K` / `MainMenuExitButton` | 72 | 953 | 380 | 104 |
| Version | `MM_VERSION_LABEL_2K` / `MainMenuVersionLabel` | 2440 | 1406 | 104 | 24 |

## Frame Content Rules

Main menu buttons keep the existing minimal-metal 9-slice button style. Their texture margins remain at least `Vector4(48, 28, 48, 28)`, with content margins at least `Vector4(62, 32, 62, 32)`. Text stays inside the empty button interior; no text or icons are placed on ornate frame pixels.

The generated background leaves the left `MM_SAFE_2K` column calm and empty for the runtime buttons and leaves the title area readable. Decorative battle detail is concentrated center-right/lower-right so runtime UI does not cover key silhouettes.

At runtime the title uses horizontal anchors `0.25..0.75`, which exactly resolves to `MM_TITLE_2K` at 2560x1440 and keeps the label inside narrower verification viewports.

## QA Evidence

Focused checks on Windows Godot 4.7 headless:

- PASS: `tests/ui_no_overlap_matrix_test.gd`
- PASS: `tests/display_resolution_test.gd`
- PASS: `tests/runtime_smoke_ui_test.gd`
- PASS: `tests/runtime_smoke_test.gd`

Additional note: `tests/dark_fantasy_ui_theme_test.gd` currently fails on a pre-existing HUD panel runtime texture mismatch outside SCRUM-560 main-menu scope.
