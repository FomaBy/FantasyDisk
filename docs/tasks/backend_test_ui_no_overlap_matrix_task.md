# Back-end Task: UI No-Overlap Test Matrix

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178
Jira: SCRUM-203
Эпик: epic_full_project_quality_pass

## Scope

Extract reusable no-overlap helpers and add screen fixtures beyond HUD/shop.

## Screens

- Main menu.
- Settings.
- Codex.
- Patch notes.
- Hero select.
- Level-up and elite reward.
- Shop.
- Route map.
- Victory/death.

## Verification

- Checks run at 1152x648, 1280x720, 1600x900 and 2560x1440.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Result (2026-06-13)

Done:
- Added `tests/ui_no_overlap_matrix_test.gd` as a focused no-overlap matrix across 1152x648, 1280x720, 1600x900 and 2560x1440.
- Covered stable named controls for main menu, settings, Codex, patch notes, hero select, victory and death screens.
- Existing runtime smoke remains the broad gate for HUD, shop wall, route map, level-up/elite reward centering and hero radar fixtures.
- The matrix writes actual rect dumps to `build/qa/ui_no_overlap_matrix.md`.

Verification:
- `tests/ui_no_overlap_matrix_test.gd`: passed.
- `tests/runtime_smoke_test.gd`: passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-203)

Проверено фактически:
- `tests/ui_no_overlap_matrix_test.gd` проходит headless («UI no-overlap matrix test
  passed»).
- НЕ вакуумный: 4 разрешения (`VIEWPORT_SIZES` 1152×648/1280×720/1600×900/2560×1440) ×
  7 экранов (main_menu/settings/codex/patch_notes/hero_select/victory/death) через
  `_check_screen`; реальные `get_global_rect().intersects` попарно; анти-вакуум гарды:
  `require_two_controls` (падает если <2 контролов), скип невидимых/нулевых (size≤1px).
- Дамп `build/qa/ui_no_overlap_matrix.md`: фактические rect'ы контролов (напр. main_menu
  кнопки последовательно по Y без пересечений). Зазоры подтверждены на всех разрешениях.
- Разделение охвата: runtime_smoke остаётся гейтом для HUD/shop-wall/route-map/level-up/
  elite-reward центровки/hero-radar; эта матрица добавляет menu/settings/codex/patch/
  hero-select/victory/death. Вместе — полный scope задачи.
- runtime smoke зелёный.
Автоматизирует правило «UI не наползает» (qa_protocol), которое QA проверял рендерами
вручную (SCRUM-161/206/211). Багов нет.
