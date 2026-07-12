# Bug SCRUM-1086: Route Map Compact Header Text Fit

Статус: done
Контур: Codex
Owner: Back-end/Codex
Thread: /root/scrum1079_route_backend
Locked paths: `scripts/route_map_screen.gd`; `tests/scrum1086_route_map_header_text_fit_test.gd`; refreshed `docs/design/previews/scrum1079_route_map_horizontal_runtime/**`; focused Route Map docs; this mirror
Jira: SCRUM-1086
Related: SCRUM-1079, SCRUM-1057

## Defect

Independent visual QA found that the 1152×648 `RouteMapStageLabel` rendered the
selected-path warning as `Выбранны...`. Rectangle containment passed, but
the runtime copy did not fit its authored title/progress content zone.

## Acceptance

- 1152×648 and 1280×720 show complete, meaningful progress/route-strength/next-
  battle/permanent-choice status with no ellipsis or clipping.
- 1600×900, 1920×1080 and 2560×1440 retain the full existing copy.
- The title/progress zone geometry from SCRUM-1057 remains unchanged.
- A focused test measures the rendered themed-font width at all five targets and
  fails on overflow or ellipsis.
- Refreshed Metal screenshots and all Route Map/runtime gates pass.

## Результат (2026-07-12)

- Added `_route_map_stage_status_text()` and live-resize refresh in
  `scripts/route_map_screen.gd`.
- 1152/1280 copy is `Шаг N/8 · Сила N · Бой Ns · Выбор пути
  необратим`; 1600/1920/2560 retain the previous full copy.
- `RouteMapStageLabel` now has a stable runtime name and updates between compact
  and large copy without changing the SCRUM-1057 title-zone rectangles.
- `tests/scrum1086_route_map_header_text_fit_test.gd` measures the actual themed-
  font rendered width at all five targets and after 1920→1152 live resize; it
  also requires all meaningful tokens and rejects literal/rendered overflow.
- Refreshed Metal screenshots are committed in
  `docs/design/previews/scrum1079_route_map_horizontal_runtime/`; compact visual
  review shows no ellipsis, clipping or HUD overlap.

Verification PASS: SCRUM-1086 text fit, SCRUM-1079 horizontal geometry,
SCRUM-981 gold shell, UI no-overlap matrix, gamepad in-run UI, runtime UI smoke,
full runtime smoke, `git diff --check`.

Commit/push: exact origin/dev SHA recorded in Jira after push.

Disk cleanup: generated `.uid`/`.import`, isolated HOME and disposable `.godot`
cache/worktree removed after push and Jira sync.

## QA-Вердикт: PASSED

Статус: PASSED
Дата: 2026-07-12
QA: Codex `/root/scrum1068_runtime_review`

Независимая re-QA выполнена в чистом detached worktree на
`origin/dev` `a9d4ff61ac24196bd48e9cb5bdc77f26fdfd3691`; functional fix:
`383c4583f2cfeb8eeae60b287ee23ba320132992`.

- все пять Metal-скриншотов 1152×648, 1280×720, 1600×900,
  1920×1080 и 2560×1440 просмотрены в полном разрешении;
  status copy полная, без ellipsis, clipping и overlap;
- компактная строка 1152/1280 сохраняет progress, route
  strength, next battle и необратимость выбора; большие tiers
  сохраняют полную формулировку;
- code/test review подтвердил переключение compact/full copy без
  изменения SCRUM-1057 geometry и проверку live resize/реальной
  ширины themed font;
- PASS: `scrum1086_route_map_header_text_fit_test`,
  `scrum1079_route_map_horizontal_test`, `scrum981_route_map_gold_shell_test`,
  `ui_no_overlap_matrix_test`, `gamepad_inrun_ui_test`,
  `runtime_smoke_ui_test`, `runtime_smoke_test`;
- известный headless dummy-texture warning остался нефатальным;
  новых defects не найдено.

Disk cleanup: QA `.godot`, generated import/UID sidecars, `/tmp/qa1086_*` and
disposable QA worktree removed after verdict push/Jira sync.
