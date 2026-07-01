# BUG: SCRUM-673 main menu logo spec mismatch

Статус: new
Jira: SCRUM-680
Приоритет: high
Роль: Design / Back-end
Найдено QA при тестировании: `docs/tasks/SCRUM-673_main_menu_epic_title_logo.md`

## Воспроизведение

1. Open `scripts/ui_screens.gd` around `_show_main_menu`.
2. Search for `MainMenuTitleLabel`, `MainMenuTitleLogo`, and `main_menu_title`.
3. Compare implementation with SCRUM-673 acceptance.

## Ожидание / Реальность

Expected:
- `TextureRect` keeps node name `MainMenuTitleLabel`.
- Generated asset is committed at `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` with `.import`/`.uid`.
- Generator is `tools/build_main_menu_title_logo.py`.

Actual:
- Runtime node is named `MainMenuTitleLogo`.
- Logo rect is `x=56..616`, `y=48..281` and overlaps main-menu button rects on 1152x648-style layout; existing no-overlap matrix did not catch this title-vs-menu intersection.
- Runtime loads `res://assets/sprites/ui/main_menu_title.png`.
- Generator is `tools/generate_main_menu_title.py`.

## Окружение

`dev`, `origin/dev` up to date, 2026-06-29 09:43 Europe/Vilnius.
Executor commit observed: `13451fb7`.
Targeted gates still pass: `ui_no_overlap_matrix_test.gd`, `runtime_smoke_ui_test.gd`.
Disk cleanup: none created.

## SCRUM-700 Reproduction Evidence — 2026-06-30

Fresh 1080p QA pass confirms the issue still reproduces on the SCRUM-700
workspace capture:

- Screenshot:
  `build/qa/scrum700_1080_ui_scale/screenshots/main_menu_1920x1080.png`
- Rect dump:
  `build/qa/scrum700_1080_ui_scale/priority_rects_1920x1080.md`

Measured rects at 1920x1080:

- `MainMenuTitleLabel`: `[P: (72, 56), S: (640, 267)]`, bottom `y=323`.
- `MainMenuStartButton`: top `y=203`.
- `MainMenuSettingsButton`: top `y=317`.
- Nearest vertical gap: `-120 px`.

SCRUM-700 links this finding to existing Jira `SCRUM-680` instead of creating a
duplicate main-menu bug.
