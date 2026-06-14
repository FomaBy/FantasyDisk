# Back-end: Settings Menu Unified Restyle Integration

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design handoff from SCRUM-391
Jira: SCRUM-396
QA: in_progress (2026-06-14)

## Context

Design SCRUM-391 prepared a production 3-slot Settings tab switcher candidate:

- `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
- source reference: `docs/design/references/settings_menu_unified/settings_tab_switcher_3slot_reference.png`
- alpha-clean reference: `docs/design/references/settings_menu_unified/settings_tab_switcher_3slot_reference_alpha_clean.png`
- metadata: `docs/design/references/settings_menu_unified/settings_tab_switcher_3slot_metadata.json`
- safe-zone preview: `docs/design/previews/settings_menu_3slot_switcher_safe_zone.png`
- contact: `docs/design/previews/settings_menu_unified_restyle_contact.png`

Design did not replace the live runtime path because current
`SETTINGS_TAB_SWITCHER_SAFE_RECTS` still has four slot rects and would misalign
text/click zones on the new 3-slot art.

## Required Back-end Work

1. Replace Settings tab switcher runtime art with the 3-slot asset, either by:
   - changing `SETTINGS_TAB_SWITCHER_FRAME_PATH` to
     `res://assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`, or
   - copying the candidate over the existing live path after preserving a backup.
2. Keep source/base size `Vector2(1280.0, 256.0)` and display size
   `Vector2(640.0, 128.0)`.
3. Replace `SETTINGS_TAB_SWITCHER_SAFE_RECTS` with exactly these three source
   rects:
   - `Rect2(160.0, 88.0, 270.0, 82.0)` for `Экран`
   - `Rect2(506.0, 88.0, 270.0, 82.0)` for `Звук`
   - `Rect2(852.0, 88.0, 270.0, 82.0)` for `Управление`
4. Remove the obsolete fourth safe rect and any assumptions that the switcher
   has four visual slots.
5. Keep runtime labels/click zones fully inside the Design safe rects; no text
   or hover/focus state may overlap dragon heads, gems, dividers, or metal.
6. Keep hover/focus neutral and non-yellow per SCRUM-318.
7. Confirm all three Settings tabs share consistent margins/layout and that the
   Controls scroll from SCRUM-275 still works.

## Acceptance Criteria

- [x] Settings switcher visually has exactly three slots and no empty fourth slot.
- [x] `Экран`, `Звук`, `Управление` labels/click zones sit inside the safe rects.
- [x] Active/hover/pressed states remain readable and do not add yellow glow.
- [x] Settings tabs keep unified spacing and no-overlap at 1280x720, 1920x1080,
  and 2560x1440.
- [x] `tests/runtime_smoke_ui_test.gd`, `tests/ui_no_overlap_matrix_test.gd`,
  and `tests/runtime_smoke_test.gd` pass.
- [x] Screenshots/dumps are saved under `build/qa/`.

## Result

Done 2026-06-14:

- Runtime Settings screen now uses
  `res://assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`.
- `SETTINGS_TAB_SWITCHER_SAFE_RECTS` contains exactly the three Design source
  rects for `Экран`, `Звук`, `Управление`; `SettingsTabButton_3` is asserted
  absent by smoke.
- Runtime smoke now writes
  `build/qa/scrum396/settings_tab_switcher_3slot_rects.md` with actual vs
  expected scaled safe rects.
- Updated `CHANGELOG.md`, `docs/design/current_game_state.md`, and
  `docs/design/systems/menus_ui.md` to remove obsolete 4-slot guidance.

Verification:

- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

## QA-Вердикт (2026-06-14)
Статус: PASSED — закрывает видимый 3-slot switcher (Design 391 + Back-end 396)

Проверено (фактически):
- **Рантайм переключён на 3-slot**: `SETTINGS_TAB_SWITCHER_FRAME_PATH` (ui_screens.gd:80)
  = `ui_frame_settings_tab_switcher_3slot.png`; `SETTINGS_TAB_SWITCHER_SAFE_RECTS`
  (83) = **ровно 3 Rect2** (Экран/Звук/Управление, старый 4-й убран);
  smoke ассертит отсутствие `SettingsTabButton_3`.
- **Визуал** `build/qa/cap_settings_3slot_396.png`: ровно 3 вкладки в dragon-стиле,
  **пустого 4-го слота НЕТ** (vs cap_settings_391.png), активная вкладка выделена,
  без жёлтого; панель в тонком unified-фрейме (384/392); контент в content-зоне.
- **Тесты**: `runtime_smoke_ui_test` («Runtime UI smoke suite passed»),
  `ui_no_overlap_matrix_test`, `runtime_smoke_test` — все passed; rect-dump
  `build/qa/scrum396/settings_tab_switcher_3slot_rects.md`.

Acceptance:
- [x] Switcher ровно 3 слота, без пустого 4-го (визуал).
- [x] Метки/клик-зоны Экран/Звук/Управление в safe-rect (3 rects, no-overlap).
- [x] Active/hover/pressed читаемы, без жёлтого; вкладки единообразны; no-overlap 3 разрешения.
- [x] runtime_smoke_ui + no-overlap + runtime smoke зелёные; скрин/dump в build/qa/.

Петля настроек закрыта: SCRUM-391 (3-slot ассет) + 396 (рантайм-интеграция). Баги: нет.
