# Задача Для Back-end-Агента: Интеграция SCRUM-331 Progression/Codex UI Kit

Статус: blocked
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Designer 2 handoff from SCRUM-331
Jira: SCRUM-408

## Dispatch
2026-06-14 — Taken by Back-end after SCRUM-407 completed and synced to QA.
Proceeding with progression/skill-tree runtime integration only; Codex texture
kit remains on SCRUM-345/SCRUM-403 unless verification exposes a regression.

2026-06-14 — Parked before implementation due PM feature block for Sprint 0.1.5.
Only bookkeeping/spec read/Jira claim happened; no runtime code was changed for
SCRUM-408. Needs explicit PM/dispatcher exception or post-block redispatch.

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи. Работать
автономно, не ждать дополнительных подтверждений.

## Контекст
Design SCRUM-331 подготовил mockup-first UI pack для progression/codex cluster.
Codex already has accepted SCRUM-345/SCRUM-403 texture integration; SCRUM-331
adds the missing progression/skill-tree frame language and documents how it
coexists with Codex.

## Что Уже Сделано
- Mockup/spec:
  - `docs/design/mockups/scrum331_progression_codex/scrum331_progression_codex_mockup.png`
  - `docs/design/mockups/scrum331_progression_codex/spec.md`
- Generated source sheet:
  `docs/design/references/ui_overhaul_progression_codex/scrum331_progression_frame_asset_sheet.png`
- Runtime-ready progression assets:
  - `assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_branch_panel.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_available.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_locked.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_purchased.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_focus.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_class_panel.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_points_badge.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_tooltip.png`
- Contact preview:
  `docs/design/previews/scrum331_progression_frame_kit_contact.png`.
- Builder:
  `tools/build_scrum331_progression_codex_assets.py`.

## Что Нужно От Back-end
Integrate the progression kit into `_show_skill_tree_screen` without changing
meta progression data, saved state, skill-point economy, node prerequisites,
Codex content data, glossary definitions, focus or escape behavior.

Suggested scope:
- Wrap skill tree content in `progression_main_panel`.
- Use `progression_class_panel` for `SkillTreeClassPanel`.
- Use `progression_branch_panel` for branch columns.
- Use circular node frames for available/locked/purchased/focus states; keep
  long node title/description in adjacent labels or tooltip, not on ornament.
- Keep Codex on SCRUM-345/SCRUM-403 frames unless a bug is found.

## Files / Assets / IDs
- `scripts/ui_screens.gd`
- optional central paths in `scripts/ui/ui_theme_paths.gd`
- `assets/sprites/ui/frames/progression/*.png`
- `docs/design/mockups/scrum331_progression_codex/spec.md`

## Acceptance Criteria
- Skill tree builds at `1280x720`, `1920x1080`, `2560x1440` with no content on
  frame ornaments or circular node rings.
- Meta skill purchase, points display, class progression panel, focus and escape
  behavior stay unchanged.
- Codex SCRUM-345/SCRUM-403 kit remains live and still passes path assertions.
- `ui_no_overlap_matrix_test.gd`, `runtime_smoke_ui_test.gd` and
  `runtime_smoke_test.gd` pass.
- QA screenshots or rect dumps are written under `build/qa/scrum331/`.

## Документация
Update `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`
and `CHANGELOG.md` after live integration.
