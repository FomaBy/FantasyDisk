# UI: Убрать глоссарий из игрового Кодекса

Статус: done
- Jira: SCRUM-889
- Контур: Codex
- Owner: Codex Backend/UI
- Thread/Worker: codex-remove-codex-glossary-20260708
- Worktree: `/private/tmp/fsd_wt_remove_codex_glossary`
- Branch: `codex/remove-codex-glossary` -> `dev`
- Locked paths: `scripts/ui_screens.gd`, `tests/*codex*.gd`,
  `tests/glossary_smoke_test.gd`, `tests/runtime_smoke_test.gd`,
  `tests/ui_no_overlap_matrix_test.gd`, `docs/design/systems/menus_ui.md`,
  `docs/design/current_game_state.md`,
  `docs/design/mockups/codex_no_glossary/`,
  `docs/tasks/backend_remove_codex_glossary_task.md`

## Source Request

Прямая директива пользователя, 2026-07-08: «убери глоссарий из кодекса в игре».

## Scope

- Убрать glossary/glossary-tab/glossary-card UI из игрового Codex screen.
- Оставить Codex как экран игровых списков/карточек уже открытого контента:
  персонажи, монстры, боссы, артефакты или текущий существующий набор без
  отдельного раздела глоссария.
- Не менять unlock/save data, боевую механику, прогрессию, визуальные frame
  assets или unrelated UI screens.
- Сохранить keyboard/gamepad focus и back/navigation contract.

## UI Spec / Mockup Note

- Runtime-only removal, no new production art or frames.
- Existing Codex dark fantasy frame/backdrop family is reused; target visual is
  the same Codex screen with glossary controls/cards absent and remaining list
  content occupying the normal safe area.
- Spec/evidence path: `docs/design/mockups/codex_no_glossary/spec.md`.
- PixelLab mockup generation is intentionally not used because this task removes
  an existing section without adding layout art; the spec records this deviation.

## Acceptance Criteria

- [x] No visible glossary tab/button/card/tooltip remains in the in-game Codex.
- [x] Remaining Codex content renders without empty glossary placeholder space.
- [x] Codex navigation/back/focus still works.
- [x] Documentation reflects that Glossary is no longer part of the live Codex.
- [x] Focused Codex/UI tests and runtime smoke pass, or any pre-existing
      unrelated warnings are recorded.
- [x] Result committed and pushed to `origin/dev`; temporary worktree cleaned.

## Result

- Removed the live glossary Codex section from `scripts/ui_screens.gd`:
  no `CodexTab_glossary`, no lazy `CodexSection_glossary` /
  `CodexSectionList_glossary`, and no Codex-created `GlossaryTooltipPanel`.
- Kept `scripts/glossary.gd` as a data/helper source for terminology and future
  reuse; Codex now exposes only the active encyclopedia sections.
- Updated runtime/UI tests to assert the glossary UI is absent while glossary
  data remains valid.
- Updated current state, menu/UI, mechanics, visual style and screen inventory
  docs to remove stale live-Codex glossary claims.
- UI art note: no new PixelLab bitmap/mockup was generated because this is a
  deletion-only UI change that reuses the existing accepted Codex frame/backdrop.

## Verification

- `python3 tools/godot_gate.py --headless --path . --script res://tests/codex_data_smoke_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/glossary_smoke_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — passed with the known dummy-renderer screenshot warning: `Parameter "t" is null` in `_try_capture_weapon_select_screenshot`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — passed with the same known dummy-renderer screenshot warning.

## Cleanup

- Disk cleanup: temporary worktree `/private/tmp/fsd_wt_remove_codex_glossary`
  removed after push; no additional clones were created.

## QA-Вердикт

Статус: PASSED

- QA worker: codex-board-drain-20260708-1718.
- Verified from clean `origin/dev` commit `aa843184`.
- `rg` check found no live glossary UI ids/builders in `scripts/ui_screens.gd`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/codex_data_smoke_test.gd` — PASSED.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/glossary_smoke_test.gd` — PASSED.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` — PASSED with known dummy-renderer screenshot warning: `Parameter "t" is null` in `_try_capture_weapon_select_screenshot`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — PASSED.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASSED with the same known dummy-renderer screenshot warning.
- Disk cleanup: no QA worktree or clone created.
