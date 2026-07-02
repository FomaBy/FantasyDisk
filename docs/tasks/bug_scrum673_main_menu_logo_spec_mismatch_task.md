# BUG: SCRUM-673 main menu logo spec mismatch

Статус: done
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

## QA-Вердикт (2026-07-02)

Статус: PASSED

Проверено:
- `origin/dev@29dec81f`, disposable QA worktree `/tmp/FantasyDisk-QA-SCRUM-680-gNx1IP`.
- Static spec check: runtime node is `MainMenuTitleLabel`; runtime asset path is `res://assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png`; asset `.png` and `.import` exist; `tools/build_main_menu_title_logo.py` exists; legacy `assets/sprites/ui/main_menu_title.png` and `tools/generate_main_menu_title.py` are absent.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/main_menu_title_no_overlap_test.gd` — PASS.
- Temporary QA rect-dump script via `python3 tools/godot_gate.py --headless --path . --script res://build/qa/scrum680_title_rect_dump.gd` — PASS; script removed after run, committed dump: `build/qa/scrum680/title_rect_dump.md`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS.

Краевые случаи:
- Main-menu title/button `global_rect` gaps checked at 1152x648, 1280x720, 1600x900, 1920x1080, 2560x1440.
- Minimum measured title-to-first-button gap is 60 px; all title-vs-button intersections are `false`.
- Full UI matrix was also probed, but fails on unrelated `upgrade_economy` 1600x900 `UpgradeChoiceButton1Description` safe-rect containment; not attributed to SCRUM-680.

Баги: нет по SCRUM-680.

Disk cleanup: removed disposable worktree `.godot`/QA script before final report; no persistent cache intended.

## Release Refresh / Re-fix (2026-07-02, Codex)

Статус: done → ready for QA re-check

Причина: пользователь попросил перед релизом полностью обновить логотип главного
экрана и снова опустить меню, потому что на 1920x1080 визуальный capture из
SCRUM-700 всё ещё показывал наложение логотипа на кнопки.

Сделано:
- Новый runtime logo asset собран как `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (`960x360`, RGBA transparent).
- PixelLab textless source/art layer: `docs/design/references/main_menu_logo_release_fix/pixellab_logo_art_source.png`, UI asset id `5e9501ff-3c55-45fe-873a-c6d5be4677c6`.
- Generator updated: `tools/build_main_menu_title_logo.py` mirrors the PixelLab crest to place the disk on the left and renders exact text `Fantasy Disk` locally inside the declared content zone.
- Mockup/spec/evidence: `docs/design/mockups/main_menu_logo_release_fix/`; previews: `docs/design/previews/main_menu_logo_release_fix/`.
- Runtime layout: `MainMenuTitleLabel` now displays at `Rect2(56,44,720,270)`; `MainMenuActions` no longer uses full-height center alignment and instead starts below the logo with `80px` minimum source-space gap.
- Focused regression test `tests/main_menu_title_no_overlap_test.gd` now checks `1920x1080`, `2560x1440`, and `1080x1920`.

Verification to run:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/main_menu_title_no_overlap_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`

Disk cleanup: none created outside committed previews/references.

## QA Re-check (2026-07-02, release re-fix) — PASSED

Проверено на `origin/dev@5a5bfa8d`, disposable QA worktree
`/tmp/FantasyDisk-QA-SCRUM-680`.

- Static re-check PASS: node name remains `MainMenuTitleLabel`; runtime asset
  path is `res://assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png`;
  generator `tools/build_main_menu_title_logo.py` exists; legacy
  `assets/sprites/ui/main_menu_title.png` and `tools/generate_main_menu_title.py`
  are absent; committed rect evidence is present.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/main_menu_title_no_overlap_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.

Баги: нет по SCRUM-680.

Disk cleanup: remove `/tmp/FantasyDisk-QA-SCRUM-680` after Jira/mirror sync.
