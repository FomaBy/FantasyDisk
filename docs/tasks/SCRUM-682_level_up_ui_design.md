# SCRUM-682 - Level Up UI Design: larger readable choice window

Jira: https://fantasydisk.atlassian.net/browse/SCRUM-682
Статус: done
Owner: codex-design-board-watcher
Lane: Codex
Role: Design

## Locked Paths

- `docs/design/mockups/level_up_scrum682/`
- `docs/design/references/level_up_scrum682/`
- `docs/design/previews/level_up_scrum682_*`
- `assets/sprites/ui/frames/level_up_scrum682/`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/content_registry.md`

## Result

- Created OpenAI-generated Level Up 2K mockup with a larger modal, larger hero
  portrait, three large reward cards, separate description/effect-preview zones
  and a reachable bottom `Позже` button.
- Created a second OpenAI-generated frame-kit reference sheet for the Level Up
  modal/card/button family.
- Produced slot-exact transparent runtime candidate PNGs:
  - `ui_frame_lu682_panel.png` (`1720x1040`)
  - `ui_frame_lu682_card.png`, `_hover.png`, `_selected.png` (`470x560`)
  - `ui_frame_lu682_portrait.png` (`320x320`)
  - `ui_frame_lu682_effect_preview.png` (`330x64`)
  - `ui_btn_lu682_later.png`, `_hover.png`, `_pressed.png` (`300x82`)
- Documented exact rectangles, 9-slice texture margins, content margins,
  responsive rules and backend handoff notes in
  `docs/design/mockups/level_up_scrum682/spec.md`.

## Evidence

- Mockup: `docs/design/references/level_up_scrum682/level_up_2k_mockup.png`
- Frame-kit reference:
  `docs/design/references/level_up_scrum682/level_up_frame_kit_reference.png`
- Safe-zone preview:
  `docs/design/previews/level_up_scrum682_safe_zones.png`
- Contact sheet:
  `docs/design/previews/level_up_scrum682_contact.png`
- Plan/spec:
  `docs/design/mockups/level_up_scrum682/ui_plan.json`,
  `layout.json`, `ui_plan_report.json`, `asset_audit.json`, `spec.md`

## Back-end Handoff Notes

- Runtime code is intentionally untouched in this Design pass.
- Integration should update `scripts/ui/ui_theme_paths.gd`,
  `scripts/ui_screens.gd` Level Up layout constants, and
  `tests/ui_no_overlap_matrix_test.gd` in a separate Back-end task.
- Preserve three whole-card clickable Buttons and existing reward/defer logic.
- Use the SCRUM-682 source sizes and margins from the spec; do not scale the old
  SCRUM-570/SCRUM-670 `1040x600` panel assumptions.
- Keep icon, title, description, effect-preview text and `Позже` label inside
  declared content zones at 1280x720, 1920x1080 and 2560x1440.

## Verification

- `python3 /private/tmp/scrum682_generate_level_up_package.py` - PASS.
- `asset_audit.json` - PASS: PNG dimensions and transparent alpha verified;
  content margins exceed texture margins for every frame.
- `python3 -m json.tool docs/design/mockups/level_up_scrum682/ui_plan.json` - PASS.
- `python3 -m json.tool docs/design/mockups/level_up_scrum682/layout.json` - PASS.
- `python3 -m json.tool docs/design/mockups/level_up_scrum682/ui_plan_report.json` - PASS.
- `python3 -m json.tool docs/design/mockups/level_up_scrum682/asset_audit.json` - PASS.
- `git diff --check` - PASS.
- Godot smoke not run: design/source package only, no runtime files changed.

## Disk Cleanup

- Removed transient generator script: `/private/tmp/scrum682_generate_level_up_package.py`.

## QA-Вердикт

Статус: PASSED

Дата: 2026-06-29
QA: claude-qa-scrum682 (взято на себя после bounce-loop воркера)
Доставка: исходный дизайн-пакет был застрэнджен на ветке codex/design-board-watcher-20260629-0735 (не влит в origin/dev) и без .import-сайдкаров. QA забрал 19 файлов пакета в worktree от origin/dev, сгенерировал 9 .import (Godot --import, валидные uid), и влил в origin/dev.
- 9 PNG (panel 1720x1040, card/_hover/_selected 470x560, portrait 320x320, effect_preview 330x64, later/_hover/_pressed 300x82) + 9 валидных .import (9 уникальных uid).
- Docs-deliverables: mockup 2K, frame-kit reference, safe_zones/contact previews, spec.md/layout.json/ui_plan.json/ui_plan_report.json/asset_audit.json.
- Готово к runtime-интеграции SCRUM-683.
