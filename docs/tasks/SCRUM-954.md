# SCRUM-954 — Rebuild Codex navigation, list and dossier layout

Статус: review
Версия: 0.2.1
Jira: SCRUM-954
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-954`
Контур: Codex
Design contract: SCRUM-1017

## Цель

Воспроизвести принятый PixelLab/content-zone макет Кодекса реальными Godot
Controls: шесть читаемых русских разделов, список только с каноническим
изображением и русским именем, крупное досье справа, responsive
720p/1080p/1440p без наложения контента на орнамент.

## Архитектура

- `CodexStage` имеет базу 1920×1080, uniform scale и letterbox.
- Точные frame/content rects берутся из
  `docs/design/mockups/scrum1017_codex_navigation_icons/spec.md`.
- Удалён устаревший полноэкранный `CodexFrame`: windowed QA показала, что его
  rails закрывали header/nav на 720p и 1080p.
- Шесть кнопок используют общую main/back-family без generic category icons.
- Центр остаётся lazy/cached: каждая запись показывает только canonical image
  и centered Russian display-name; summary/raw id/English в строке отсутствуют.
- Responsive font helper compensates the stage transform only at accepted
  bounds: navigation/name/title stay within 15–30 visual px and dossier text
  within 17–32 visual px. Font metadata is reapplied on live resize, so an
  already-open Codex preserves those bounds without rebuilding cached sections.
- Досье имеет один contained preview и один нижний scroll. Связанные параметры
  встроены в тот же scroll без третьей scrollbar lane.
- Возвышение uses the canonical combat-HUD ascension image in both row and
  dossier. Shop-derived Codex artifacts resolve their existing dedicated
  `shop/shop_<id>.png` images before the fail-safe icon.
- Data, unlock/discovery, gameplay и canonical asset paths не меняются.
  Pixel-level crop/zoom and enlarged source-pack integration остаются SCRUM-958.

## Locked scope

- `scripts/ui_screens.gd` — Codex functions only;
- `tests/ui_no_overlap_matrix_test.gd` — Codex assertions plus transform-aware
  generic text measurement;
- `tests/codex_scrum954_layout_test.gd`;
- this task mirror and Codex UI documentation.

`tests/runtime_smoke_test.gd` был исключён до формального release двух Claude
пакетов. Read-only Claude UI подтвердил, что оба background worker завершились
ошибкой session limit, а parent response finished. Dispatcher вернул восемь
stale Jira claims в `К выполнению`, сохранил worktrees/commits и только после
этого мигрировал Codex assertions; Claude production-файлы не затрагивались.

## Реализация и текущая проверка

PASS через `tools/godot_gate.py`:

- `tests/codex_scrum954_layout_test.gd` — точные rects 1280×720, 1920×1080,
  2560×1440; all six lazy/cached sections; every canonical row name/image path;
  locked artifact chip; effective font min/caps; exactly two active scrollbars;
  same-instance 1080p→720p→1440p resize;
- `tests/ui_no_overlap_matrix_test.gd` — полный all-screen matrix;
- `tests/codex_data_smoke_test.gd`;
- `tests/dark_fantasy_ui_theme_test.gd`;
- `tests/asset_reference_integrity_test.gd`;
- `tests/gamepad_menu_focus_test.gd`, `tests/gamepad_full_flow_smoke_test.gd`;
- `tests/display_resolution_test.gd`;
- `tests/runtime_smoke_ui_test.gd`;
- полный `tests/runtime_smoke_test.gd` (sequential, exit 0).

Windowed evidence (committed preview copies):

- `docs/design/previews/scrum954_codex_runtime/codex_1280x720.png`;
- `docs/design/previews/scrum954_codex_runtime/codex_1920x1080.png`;
- `docs/design/previews/scrum954_codex_runtime/codex_2560x1440.png`;
- `build/qa/scrum954/codex_layout_matrix.md`.

Implementation готова к отдельному независимому QA. Jira переводится только в
`Контроль качества`; `Готово` разрешено после независимого PASS.

Disk cleanup: pending final gate; task worktree and `.godot` are active.

Thread cleanup: not a disposable worker thread.
