# Задача Для Back-end-Агента: Интеграция SCRUM-331 Progression/Codex UI Kit

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Designer 2 handoff from SCRUM-331
Jira: SCRUM-408
QA: in_progress (2026-06-15)

## Dispatch
2026-06-14 — Taken by Back-end after SCRUM-407 completed and synced to QA.
Proceeding with progression/skill-tree runtime integration only; Codex texture
kit remains on SCRUM-345/SCRUM-403 unless verification exposes a regression.

2026-06-14 — Parked before implementation due PM feature block for Sprint 0.1.5.
Only bookkeeping/spec read/Jira claim happened; no runtime code was changed for
SCRUM-408. Needs explicit PM/dispatcher exception or post-block redispatch.

2026-06-14 — Redispatched to Back-end by Documentation dispatcher after PM
directive "доделываем оставшиеся таски и баги". This is an explicit exception
for an already-listed 0.1.5 board row, not new feature intake. Scope remains
runtime integration of accepted SCRUM-331 progression assets only; no Codex
rework, art generation, balance, economy, release, commit, merge, tag or push.

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

## Result / 2026-06-14
- Integrated the accepted SCRUM-331 progression frame kit into the live skill
  tree screen: `SkillTreeMainPanel`, `SkillTreeClassPanel`,
  `SkillTreePointsBadge`, `SkillTreeBranchPanel_*` and circular `SkillNode_*`
  states now use `assets/sprites/ui/frames/progression/*.png`.
- Moved long skill node title/description copy out of the circular node button
  ring into adjacent labels plus tooltip; the node button keeps only short cost
  text and remains the clickable/focusable purchase control.
- Preserved meta progression data, saved state, skill-point economy, class
  progress, prerequisites, Codex SCRUM-345/SCRUM-403 runtime frames, Escape/back
  behavior and purchase flow.
- Added runtime/UI assertions for SCRUM-331 texture paths, ring-safe node text
  and skill-tree no-overlap matrix coverage. QA dumps:
  `build/qa/scrum331/progression_skill_tree_runtime_dump.md` and
  `build/qa/scrum331/progression_ui_no_overlap_matrix.md`.
- Verification PASS:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd`;
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`;
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`.

## QA-Вердикт (2026-06-15)
Статус: PASSED — live-интеграция SCRUM-331 progression frame kit

Проверено (фактически):
- **Рантайм-привязка** (ui_screens.gd:149-153 `PROGRESSION_*_PATH`): main/branch/class
  панели + points_badge + tooltip фреймы SCRUM-331 подключены через
  `_progression_*_style` / `_progression_node_style` / `_apply_progression_node_button_theme`.
- **No-overlap дамп** `build/qa/scrum331/progression_ui_no_overlap_matrix.md`: skill_tree
  (BackButton/PointsBadge/ClassPanel/Branches) на 5 разрешениях (1152/1280/1600/1920/2560) —
  без наложений (badge x≤912 < back x930; classpanel x≤466 < branches x484); branches
  скроллится (высота > вьюпорта). `progression_skill_tree_runtime_dump.md`.
- **Тесты**: `ui_no_overlap_matrix_test` + `runtime_smoke_ui_test` passed; runtime_smoke
  зелёный (де-флейк ассасин SCRUM-410 сохранён). Codex — baseline 345/403, 408 добавляет
  progression skill-tree слой.

Acceptance:
- [x] Progression/skill-tree экраны на SCRUM-331 фреймах; no-overlap на 1280/1920/2560.
- [x] Навигация/фокус целы; ui_no_overlap + runtime_smoke + runtime_smoke_ui зелёные.
- [x] QA rect-дампы в build/qa/scrum331/.

Статус done. Баги: нет. Закрывает progression-петлю 331+408 (codex — baseline 345/403).
