# SCRUM-1056 Escape-досье без скроллбаров и с кнопками главного меню

Статус: done
Версия: 0.2.1
Jira: SCRUM-1056
Контур: Codex
Owner: Back-end/root
Thread: /root
Locked paths: `scripts/pause_stats_menu.gd`, `tests/scrum983_escape_dossier_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_test.gd`, pause UI docs/spec/evidence

## Focused scope from user

- Escape-досье использует всю безопасную область рамки и не показывает dossier scrollbars.
- Всё содержимое помещается без скрытого overflow; оружие, ульта и артефакты остаются доступны через видимую build-summary строку и полный tooltip.
- `Продолжить`, `Настройки`, `Завершить забег`, `Главное меню` используют ту же пяти-state family, что кнопки главного меню.
- Frame ornament остаётся полностью свободным от labels/icons/hitboxes/focus.

## Mockup / geometry contract

- PixelLab source reused: `docs/design/references/scrum983_escape_dossier/pixellab_escape_dossier_v1_688x384.png`.
- PixelLab asset ID: `ccc0e262-f062-4eb3-90d5-71c68c7db203`.
- Updated spec: `docs/design/mockups/scrum983_escape_dossier/spec.md`.
- Production outer frame remains `assets/sprites/ui/meta40/frame_border.png`; no new art was generated.
- Responsive matrix: 1152×648, 1280×720, 1600×900, 1920×1080, 2560×1440.

## Acceptance criteria

- Both dossier clip owners have vertical/horizontal scrolling disabled and `content minimum <= viewport` at every target.
- No body/footer or content/frame overlap, including live 2560×1440 → 1280×720 resize.
- Base rows/icons retain 44px minimums; compact derived aliases remain fully readable with complete canonical tooltips.
- All four action buttons resolve `main_menu_380x104` normal/hover/focus/pressed/disabled textures with white tint and stable geometry.
- Focused dossier, no-overlap matrix, UI/theme/gamepad smokes and repository runtime smoke pass.

## Result

Implementation, automated gates and visual evidence are complete; the Jira issue
is ready for the `Контроль качества` handoff after its green commit lands in `dev`.

- Runtime: `scripts/pause_stats_menu.gd`.
- Focused oracle: `tests/scrum983_escape_dossier_test.gd`.
- Matrix/runtime regression: `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_test.gd`.
- Capture helper: `tools/capture_scrum983_escape_dossier.gd`.
- Visual evidence: `build/qa/scrum983/escape_dossier_{1280x720,1920x1080,2560x1440}.png` and `escape_dossier_visual_matrix.md`.
- Verification: `dark_fantasy_ui_theme_test`, `gamepad_inrun_ui_test`,
  `runtime_smoke_ui_test`, `ui_no_overlap_matrix_test`,
  `scrum983_escape_dossier_test`, and full `runtime_smoke_test` — PASS.
- Disk cleanup: generated `.gd.uid` sidecars and the worktree `.godot/` cache removed after the final gates.
- Thread cleanup: not a disposable worker thread.
